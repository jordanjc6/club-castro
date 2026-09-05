extends Node

# --- EOS Credentials ---
const PRODUCT_ID = "ec9ba98721e9490985c87199b1c2ad6b"
const SANDBOX_ID = "ca6206f7cc3349fe97da5c535648e98f"
const DEPLOYMENT_ID = "07d2bf133dda478a83b8ea36ec114384"
const CLIENT_ID = "xyza7891oE0pO0LevouFscle0WaMgAls"
const CLIENT_SECRET = "1dfP19Ju9/3Y2HlrTWrzLwYmKPW5mz9IMAVbkkjqvD8"

const SERVER_PORT = 8080
const SERVER_IP = "127.0.0.1"
const MAC_IP = "192.168.2.23"

# Fixed spawn fallback coordinates when returning to single player
const FIXED_SINGLEPLAYER_SPAWN = Vector2(500, 550)
const FIXED_GRID_OFFSET = Vector2.ZERO

# (x1, y1) = top left theatremap offset
# (x2, y2) = bottom right theatremap based on texturerect size (1280, 720)
const THEATRE_X1 = 0
const THEATRE_X2 = 1280 
const THEATRE_Y1 = -1800
const THEATRE_Y2 = -1800 + 720

var multiplayer_scene = preload("res://scenes/player/monkey_multiplayer.tscn")
var _players_spawn_node: Node
var host_mode_enabled = false

# Stores original SinglePlayer instance to return to when disconnecting
var stored_single_player: Node = null

# Used to stop movie stream if no players in theatre
var num_players_in_theatre: int = 0

var eos_peer: EOSGMultiplayerPeer
const SOCKET_NAME = "Room"
var active_lobby_id: String = ""
var _eos_logged_in: bool = false

# Mobile background settings
var _background_time_msec: int = 0
const MAX_BACKGROUND_SECONDS: float = 10.0

# Heartbeat & Ping Settings
var _heartbeat_timer: Timer
var _last_host_heartbeat_msec: int = 0
const HEARTBEAT_INTERVAL: float = 0.5
const HEARTBEAT_TIMEOUT: float = 10.0

var _ping_request: HTTPRequest
var _last_ping_msec: int = 0
const PING_INTERVAL_SEC: float = 3.0
var _consecutive_ping_failures: int = 0

# Absorbs temporary Wi-Fi jitter (4 fails * 3s timeout = ~12s grace period)
const MAX_PING_FAILURES: int = 4


func _ready():
	_setup_ping_request()
	_setup_heartbeat_timer()
	# Step 1: Initialize platform binaries once
	await _initialize_eos_platform()
	# Step 2: Attempt background login (won't block game if offline)
	_login_eos_user()

func _notification(what: int) -> void:
	match what:
		# Catch window close or quit request
		NOTIFICATION_WM_CLOSE_REQUEST:
			if not multiplayer.is_server() and multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
				rpc_id(1, "notify_server_client_leaving", multiplayer.get_unique_id())

		# App moves to background (checking notifications, pulling down control center, switching apps)
		NOTIFICATION_APPLICATION_PAUSED:
			_background_time_msec = Time.get_ticks_msec()
			print("App paused at timestamp: ", _background_time_msec)
			
		# App returns to foreground
		NOTIFICATION_APPLICATION_RESUMED:
			if _background_time_msec > 0:
				var elapsed_seconds = (Time.get_ticks_msec() - _background_time_msec) / 1000.0
				print("App resumed after %.2f seconds." % elapsed_seconds)
				
				# If backgrounded too long, drop cleanly back to single player
				if elapsed_seconds > MAX_BACKGROUND_SECONDS:
					print("App backgrounded too long! Returning to single player...")
					if host_mode_enabled:
						host_force_return_to_single_player()
					else:
						force_return_to_single_player()
				
				_background_time_msec = 0

# Active internet verification for Host
func _setup_ping_request():
	if is_instance_valid(_ping_request):
		_ping_request.queue_free()
		
	_ping_request = HTTPRequest.new()
	_ping_request.name = "NetworkPingRequest"
	_ping_request.timeout = 3.0 # Allow up to 3.0 seconds per HTTP attempt
	_ping_request.request_completed.connect(_on_ping_request_completed)
	add_child(_ping_request)

func _on_ping_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
	# ANY non-zero response code means a remote server responded back -> Internet is ALIVE!
	if result != HTTPRequest.RESULT_SUCCESS or response_code == 0:
		_consecutive_ping_failures += 1
		print("Host internet ping failed (%d/%d)" % [_consecutive_ping_failures, MAX_PING_FAILURES])
	else:
		_consecutive_ping_failures = 0 # Reset counter on successful connection

# Runs ONCE at app launch to load C++ SDK binaries into memory
func _initialize_eos_platform():
	var credentials = HCredentials.new()
	credentials.product_name = "Club Castro"
	credentials.product_version = "1.0"
	credentials.product_id = PRODUCT_ID
	credentials.sandbox_id = SANDBOX_ID
	credentials.deployment_id = DEPLOYMENT_ID
	credentials.client_id = CLIENT_ID
	credentials.client_secret = CLIENT_SECRET
	
	var setup_success: bool = await HPlatform.setup_eos_async(credentials)
	if setup_success:
		print("EOS Platform binaries initialized successfully!")
	else:
		print("EOS Platform already initialized or setup skipped.")

# Can be safely retried multiple times when internet becomes available
func _login_eos_user() -> bool:
	if _eos_logged_in and is_instance_valid(HAuth) and HAuth.product_user_id != "":
		return true

	print("Attempting anonymous EOS login...")
	var login_success: bool = await HAuth.login_anonymous_async("Player")
	
	if login_success:
		_eos_logged_in = true
		if eos_peer == null:
			eos_peer = EOSGMultiplayerPeer.new()
		print("EOS logged in successfully! Online multiplayer ready.")
		return true
	else:
		print("EOS anonymous login failed (check internet connection).")
		_eos_logged_in = false
		return false

# Setup Heartbeat Timer for host dropouts and network connection monitoring
func _setup_heartbeat_timer():
	if is_instance_valid(_heartbeat_timer):
		_heartbeat_timer.queue_free()
		
	_heartbeat_timer = Timer.new()
	_heartbeat_timer.name = "HeartbeatTimer"
	_heartbeat_timer.wait_time = HEARTBEAT_INTERVAL
	_heartbeat_timer.autostart = false
	_heartbeat_timer.timeout.connect(_on_heartbeat_tick)
	add_child(_heartbeat_timer)

func _on_heartbeat_tick():
	if multiplayer.multiplayer_peer == null:
		return

	# HOST NETWORK CHECK
	if multiplayer.is_server():
		# Check 1: Socket Disconnect
		if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			print("[CRITICAL] Host peer disconnected! Returning to single player...")
			host_force_return_to_single_player()
			return

		# Check 2: Did active pings fail (Wi-Fi/Internet dead)
		if _consecutive_ping_failures >= MAX_PING_FAILURES:
			print("[CRITICAL] Host lost internet connection! Restoring single player...")
			_consecutive_ping_failures = 0
			host_force_return_to_single_player()
			return

		# Trigger lightweight ping to 1.1.1.1 every PING_INTERVAL_SEC
		var current_time = Time.get_ticks_msec()
		if (current_time - _last_ping_msec) / 1000.0 >= PING_INTERVAL_SEC:
			_last_ping_msec = current_time
			if is_instance_valid(_ping_request) and _ping_request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
				_ping_request.request("https://1.1.1.1", [], HTTPClient.METHOD_HEAD)

		# Broadcast heartbeat to joiners
		rpc("receive_host_heartbeat")

	# JOINER NETWORK CHECK
	else:
		if _last_host_heartbeat_msec > 0:
			var time_since_last_ping = (Time.get_ticks_msec() - _last_host_heartbeat_msec) / 1000.0
			if time_since_last_ping > HEARTBEAT_TIMEOUT:
				print("Host ping lost for %.2fs! Force-restoring SinglePlayer." % time_since_last_ping)
				force_return_to_single_player()

@rpc("any_peer", "call_remote", "unreliable")
func receive_host_heartbeat():
	_last_host_heartbeat_msec = Time.get_ticks_msec()

func force_return_to_single_player():
	print("[CRITICAL] Host connection dropped or timed out! Forcing SinglePlayer restoration...")
	if is_instance_valid(_heartbeat_timer):
		_heartbeat_timer.stop()
	_last_host_heartbeat_msec = 0
	_on_server_disconnected()

func host_force_return_to_single_player():
	print("[CRITICAL] Host lost network connection! Restoring SinglePlayer...")
	
	if is_instance_valid(_heartbeat_timer):
		_heartbeat_timer.stop()
		
	_last_host_heartbeat_msec = 0

	var world_scene = get_tree().get_current_scene()
	_players_spawn_node = world_scene.get_node_or_null("Players")

	# 1. Clean up EOS Lobby asynchronously
	if active_lobby_id != "":
		destroy_active_lobby_async()
		active_lobby_id = ""

	# 2. Reset network peer
	if eos_peer:
		eos_peer.close()
		eos_peer = null
		
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	# 3. Flush all network player instances from current world tree
	if _players_spawn_node:
		for child in _players_spawn_node.get_children():
			_players_spawn_node.remove_child(child)
			child.queue_free()

	host_mode_enabled = false
	num_players_in_theatre = 0

	# 4. Restore host's single player at fixed spawn
	_restore_single_player(FIXED_SINGLEPLAYER_SPAWN, FIXED_GRID_OFFSET)

# Called when Host presses Host Button
func become_host():
	if not _eos_logged_in or eos_peer == null or not is_instance_valid(HAuth) or HAuth.product_user_id == "":
		print("Not connected to EOS. Retrying login...")
		var success = await _login_eos_user()
		if not success:
			print("Cannot host: Unable to authenticate with EOS (check Wi-Fi connection).")
			return

	print("Creating EOS Lobby...")
	host_mode_enabled = true
	
	var world_scene = get_tree().get_current_scene()
	_players_spawn_node = world_scene.get_node("Players")
	
	var opts = EOS.Lobby.CreateLobbyOptions.new()
	opts.max_lobby_members = 4
	opts.permission_level = EOS.Lobby.LobbyPermissionLevel.PublicAdvertised
	opts.bucket_id = "Default"
	
	var lobby = await HLobbies.create_lobby_async(opts)
	
	if not lobby:
		print("Failed to create EOS Lobby.")
		return
		
	active_lobby_id = lobby.lobby_id
	print("EOS Lobby Created! Share this Lobby ID: ", active_lobby_id)
	
	var error = eos_peer.create_server(SOCKET_NAME)
	if error != OK:
		print("Failed to create EOS server peer: ", error)
		return
		
	multiplayer.multiplayer_peer = eos_peer
	
	multiplayer.peer_connected.connect(_add_player_to_game)
	multiplayer.peer_disconnected.connect(_delete_player)
	
	var single_player = world_scene.get_node_or_null("SinglePlayer")
	var position = single_player.global_position if single_player else Vector2.ZERO
	var offset = single_player.current_grid_offset if single_player and "current_grid_offset" in single_player else Vector2.ZERO
	
	_add_player_to_game(1, position, offset)
	_remove_single_player()
	
	if is_instance_valid(_heartbeat_timer):
		_heartbeat_timer.start()

# Called when Client passes the Lobby Code to Join
func join_game(lobby_id: String):
	if not _eos_logged_in or eos_peer == null or not is_instance_valid(HAuth) or HAuth.product_user_id == "":
		print("Not connected to EOS. Retrying login...")
		var success = await _login_eos_user()
		if not success:
			print("Cannot join: Unable to authenticate with EOS (check Wi-Fi connection).")
			return

	print("Joining EOS Lobby: ", lobby_id)
	
	var lobbies = await HLobbies.search_by_lobby_id_async(lobby_id)
	
	if not lobbies or lobbies.size() == 0:
		print("Failed to find EOS Lobby with ID: ", lobby_id)
		return
		
	var target_lobby: HLobby = lobbies[0]
	var joined_lobby = await HLobbies.join_async(target_lobby)
	
	if not joined_lobby:
		print("Failed to join EOS Lobby.")
		return
		
	print("Joined EOS Lobby successfully!")
	
	var host_user_id = joined_lobby.owner_product_user_id
	
	var error = eos_peer.create_client(SOCKET_NAME, host_user_id)
	if error != OK:
		print("Failed to create EOS client peer: ", error)
		return
		
	multiplayer.multiplayer_peer = eos_peer

	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

	_last_host_heartbeat_msec = Time.get_ticks_msec()
	if is_instance_valid(_heartbeat_timer):
		_heartbeat_timer.start()

	_remove_single_player()

# Call this if Host manually closes or leaves the lobby room
func leave_or_close_host_lobby():
	if host_mode_enabled and active_lobby_id != "":
		await destroy_active_lobby_async()
		
		active_lobby_id = ""
		host_mode_enabled = false
		
		if eos_peer:
			eos_peer.close()
			eos_peer = null
		
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

# Call this when a Joiner explicitly leaves via UI button
func leave_game_as_joiner():
	print("Leaving game as joiner...")
	
	if is_instance_valid(_heartbeat_timer):
		_heartbeat_timer.stop()
	_last_host_heartbeat_msec = 0

	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		rpc_id(1, "notify_server_client_leaving", multiplayer.get_unique_id())

	if active_lobby_id != "":
		leave_active_lobby_async()
		active_lobby_id = ""

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if eos_peer:
		eos_peer.close()
		eos_peer = null

	var world_scene = get_tree().get_current_scene()
	_players_spawn_node = world_scene.get_node_or_null("Players")
	if _players_spawn_node:
		for child in _players_spawn_node.get_children():
			_players_spawn_node.remove_child(child)
			child.queue_free()

	_restore_single_player(FIXED_SINGLEPLAYER_SPAWN, FIXED_GRID_OFFSET)

@rpc("any_peer", "call_remote", "reliable")
func notify_server_client_leaving(client_id: int):
	if multiplayer.is_server():
		print("Server received explicit disconnect notification from peer: ", client_id)
		_delete_player(client_id)

func destroy_active_lobby_async():
	if active_lobby_id == "":
		return

	if not is_instance_valid(EOSGRuntime):
		print("EOSGRuntime is freed or invalid. Skipping lobby destruction.")
		active_lobby_id = ""
		return

	print("Destroying EOS Lobby as host: ", active_lobby_id)

	var opts = EOS.Lobby.DestroyLobbyOptions.new()
	opts.lobby_id = active_lobby_id
	if is_instance_valid(HAuth) and HAuth.product_user_id != "":
		opts.local_user_id = HAuth.product_user_id

	EOS.Lobby.LobbyInterface.destroy_lobby(opts)
	var ret = await IEOS.lobby_interface_destroy_lobby_callback
	if EOS.is_success(ret):
		print("EOS Lobby destroyed successfully on Epic servers!")
	else:
		print("Failed to destroy EOS Lobby: ", EOS.result_str(ret))

func leave_active_lobby_async():
	if active_lobby_id == "":
		return
		
	print("Leaving EOS Lobby as joiner: ", active_lobby_id)
	var opts = EOS.Lobby.LeaveLobbyOptions.new()
	opts.lobby_id = active_lobby_id
	if is_instance_valid(HAuth) and HAuth.product_user_id != "":
		opts.local_user_id = HAuth.product_user_id
	
	EOS.Lobby.LobbyInterface.leave_lobby(opts)
	var ret = await IEOS.lobby_interface_leave_lobby_callback
	if EOS.is_success(ret):
		print("Left EOS Lobby successfully!")
	else:
		print("Failed to leave EOS Lobby: ", EOS.result_str(ret))

func get_active_lobby_code() -> String:
	return active_lobby_id

func _add_player_to_game(id: int, position: Vector2 = Vector2.INF, offset: Vector2 = Vector2.INF):
	print("player %s joined the game" % id)
	
	var player_to_add = multiplayer_scene.instantiate()
	player_to_add.player_id = id
	player_to_add.name = str(id)
	_players_spawn_node.add_child(player_to_add, true)
	
	if id == 1:
		player_to_add.global_position = position
		player_to_add.current_grid_offset = offset
		player_to_add.rpc("update_zone_offset", offset)
		
		var x = position.x
		var y = position.y
		if (x >= THEATRE_X1 and x <= THEATRE_X2 and y >= THEATRE_Y1 and y <= THEATRE_Y2):
			increment_players_in_theatre()
	
	if id != 1:
		var host_player = _players_spawn_node.get_node_or_null("1")
		if host_player:
			var target_pos = host_player.global_position
			var target_grid_offset = host_player.current_grid_offset
			
			player_to_add.global_position = target_pos
			player_to_add.current_grid_offset = target_grid_offset
			player_to_add.rpc("update_zone_offset", target_grid_offset)
			
			var x = target_pos.x
			var y = target_pos.y
			if (x >= THEATRE_X1 and x <= THEATRE_X2 and y >= THEATRE_Y1 and y <= THEATRE_Y2):
				MultiplayerManager.rpc_id(1, "increment_players_in_theatre")

func _delete_player(id: int):
	print("Player %s left the game" % id)
	
	if not is_instance_valid(_players_spawn_node):
		var world_scene = get_tree().get_current_scene()
		if world_scene:
			_players_spawn_node = world_scene.get_node_or_null("Players")
			
	if not _players_spawn_node:
		return

	# Search by exact node name or custom player_id / multiplayer authority
	var player_node: Node = _players_spawn_node.get_node_or_null(str(id))
	
	if not player_node:
		for child in _players_spawn_node.get_children():
			if ("player_id" in child and child.player_id == id) or child.get_multiplayer_authority() == id:
				player_node = child
				break

	if player_node:
		var player_position = player_node.global_position if player_node is Node2D else Vector2.ZERO
		var x = player_position.x
		var y = player_position.y
		if (x >= THEATRE_X1 and x <= THEATRE_X2 and y >= THEATRE_Y1 and y <= THEATRE_Y2):
			if multiplayer.is_server():
				decrement_players_in_theatre()

		_players_spawn_node.remove_child(player_node)
		player_node.queue_free()
		print("Successfully removed player node for peer: ", id)

func _remove_single_player():
	print("storing and removing single player from scene")
	var world_scene = get_tree().get_current_scene()
	var player_to_remove = world_scene.get_node_or_null("SinglePlayer")
	
	if player_to_remove:
		var player_position = player_to_remove.global_position
		var x = player_position.x
		var y = player_position.y
		if (x >= THEATRE_X1 and x <= THEATRE_X2 and y >= THEATRE_Y1 and y <= THEATRE_Y2):
			if multiplayer.is_server():
				decrement_players_in_theatre()
			else:
				MultiplayerManager.rpc_id(1, "decrement_players_in_theatre")
		
		stored_single_player = player_to_remove
		world_scene.remove_child(player_to_remove)

func _on_server_disconnected():
	print("Host disconnected. Returning joiner to single player mode at default spawn...")
	
	if is_instance_valid(_heartbeat_timer):
		_heartbeat_timer.stop()
	_last_host_heartbeat_msec = 0

	var world_scene = get_tree().get_current_scene()
	_players_spawn_node = world_scene.get_node_or_null("Players")

	# 1. Reset local multiplayer peer
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if eos_peer:
		eos_peer.close()
		eos_peer = null

	# 2. Flush all network player instances from current world tree
	if _players_spawn_node:
		for child in _players_spawn_node.get_children():
			_players_spawn_node.remove_child(child)
			child.queue_free()

	# 3. Clean up EOS lobby state
	if active_lobby_id != "":
		leave_active_lobby_async()
		active_lobby_id = ""
		
	host_mode_enabled = false
	num_players_in_theatre = 0

	# 4. Restore stored single player at fixed position
	_restore_single_player(FIXED_SINGLEPLAYER_SPAWN, FIXED_GRID_OFFSET)

	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)

func _restore_single_player(pos: Vector2, offset: Vector2):
	print("Attempting to restore SinglePlayer...")
	
	if not is_instance_valid(stored_single_player):
		print("ERROR: stored_single_player was freed or null! Cannot restore.")
		return

	var world_scene = get_tree().get_current_scene()
	
	stored_single_player.global_position = pos
	if "current_grid_offset" in stored_single_player:
		stored_single_player.current_grid_offset = offset

	world_scene.add_child(stored_single_player)
	print("SUCCESS: SinglePlayer restored at position: ", pos)

@rpc("any_peer", "call_local", "reliable")
func increment_players_in_theatre():
	if multiplayer.is_server():
		num_players_in_theatre += 1
		print("Number of players in theatre: %d" % num_players_in_theatre)
		rpc("sync_player_count", num_players_in_theatre)

@rpc("any_peer", "call_local", "reliable")
func decrement_players_in_theatre():
	if multiplayer.is_server():
		num_players_in_theatre -= 1
		print("Number of players in theatre: %d" % num_players_in_theatre)
		rpc("sync_player_count", num_players_in_theatre)

@rpc("any_peer", "call_local", "reliable")
func sync_player_count(new_count: int) -> void:
	num_players_in_theatre = new_count
	if num_players_in_theatre == 0:
		_stop_video_stream()

func _stop_video_stream() -> void:
	var world_scene = get_tree().get_current_scene()
	var video_player = world_scene.get_node_or_null("TheCinema/Theatre/MovieScreen/VideoStreamPlayer")
	var movie_projector = world_scene.get_node_or_null("TheCinema/Theatre/MovieProjector")
	var movie_selector = world_scene.get_node_or_null("TheCinema/Theatre/MovieSelector")
	
	if video_player:
		video_player.stop()
		video_player.stream = null
	if movie_projector:
		movie_projector.current_movie_index = -1
		movie_projector.is_movie_selector_open = false
	if movie_selector:
		movie_selector.visible = false
