extends Node

signal player_disconnected_notif(message: String)
signal player_reconnecting_notif(message: String)
signal player_reconnected_notif(message: String)
signal tag_lobby_updated(joined_peers: Array[int])
signal player_names_updated(names: Dictionary)

# --- EOS Credentials ---
const PRODUCT_ID = "ec9ba98721e9490985c87199b1c2ad6b"
const SANDBOX_ID = "ca6206f7cc3349fe97da5c535648e98f"
const DEPLOYMENT_ID = "07d2bf133dda478a83b8ea36ec114384"
const CLIENT_ID = "xyza7891oE0pO0LevouFscle0WaMgAls"
const CLIENT_SECRET = "1dfP19Ju9/3Y2HlrTWrzLwYmKPW5mz9IMAVbkkjqvD8"

const SERVER_PORT = 8080
const SERVER_IP = "127.0.0.1"
const MAC_IP = "192.168.2.23"
const MAX_LOBBY_SIZE = 6

# Fixed spawn fallback coordinates when returning to single player
const FIXED_SINGLEPLAYER_SPAWN = Vector2(647, 528)
const FIXED_GRID_OFFSET = Vector2.ZERO

# Pool of monkey names to assign
const MONKEY_NAMES: Array[String] = [ "Chonk",
	"Ape", "Baboon", "Blue", "Bonobo", "Capuchin", "Chimpanzee", "Chimp", 
	"Colobus", "Dryas", "Gelada", "Gibbon", "Gorilla", "Green", "Grivet", 
	"Guenon", "Howler", "Langur", "Leaf", "Macaque", "Mandrill", "Mangabey", 
	"Marmoset", "Monkey", "Night", "Orangutan", "Owl", "Proboscis", "Saki", 
	"Spider", "Squirrel", "Talapoin", "Tamarin", "Titi", "Vervet", "Woolly",
]

# Stores mapping of peer_id -> String name (Server-Authoritative)
var player_names: Dictionary = {}

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
var active_lobby_id: String = ""  # actual EOS lobby code
var short_lobby_code: String = ""  # random alias for actual lobby code
var _eos_logged_in: bool = false

# Mobile background settings
var _background_time_msec: int = 0
const MAX_BACKGROUND_SECONDS: float = 21.0

# Heartbeat & Ping Settings
var _heartbeat_timer: Timer
var _last_host_heartbeat_msec: int = 0
const HEARTBEAT_INTERVAL: float = 0.5
const HEARTBEAT_TIMEOUT: float = 6

var _ping_request: HTTPRequest
var _last_ping_msec: int = 0
const PING_INTERVAL_SEC: float = 3.0
var _consecutive_ping_failures: int = 0

# Absorbs temporary Wi-Fi jitter
const MAX_PING_FAILURES: int = 7
var _is_reconnecting: bool = false

# tag minigame ##############################################################
#############################################################################
var joined_tag_peers: Array[int] = []
var tag_it_peer_id: int = -1  # store who is "it" for tag

# Tracks active Tag minigame session state across network
var is_tag_minigame_started: bool = false

# Spawn locations (Adjust Vector2 values to match your game arena layout)
const IT_SPAWN_POS = Vector2(647, 527 + 75)
const PLAYER_SPAWN_POSITIONS = [
	Vector2(647, 527 - 100),
	Vector2(647 - 125, 527 - 100),
	Vector2(647 - 125 - 125, 527 - 100),
	Vector2(647 + 125, 527 - 100),
	Vector2(647 + 125 + 125, 527 - 100)
]

# Server tag cooldown timestamp
var tag_cooldown_until_ms: int = 0
# Tracks if the 5s countdown is active (prevents tagging before movement is enabled)
var is_tag_countdown_active: bool = false

#############################################################################

# fishing #######################
#################################
enum FishingRod {
	RED,
	ORANGE,
	YELLOW,
	GREEN,
	BLUE,
	VIOLET
}
const ROD_COLORS: Dictionary = {
	FishingRod.RED: Color("ff1818"),
	FishingRod.ORANGE: Color("ff5c00"),
	FishingRod.YELLOW: Color("fff01f"),
	FishingRod.GREEN: Color("2cff05"),
	FishingRod.BLUE: Color("2323ff"),
	FishingRod.VIOLET: Color("9f00ff")
}

# Map of peer_id -> FishingRod (enum)
var player_rods: Dictionary = {}

# Stores peer_id -> Dictionary { "start_pos": Vector2, "end_pos": Vector2, "color": Color }
var active_lures: Dictionary = {}

#################################

func _ready():
	_setup_ping_request()
	_setup_heartbeat_timer()
	await _initialize_eos_platform()
	_login_eos_user()

# Assigns a unique name to a joining peer ID
func assign_unique_name_for_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	if player_names.has(peer_id):
		return

	# Collect all names currently taken by connected peers
	var used_names = player_names.values()
	var available_names: Array[String] = []
	
	for n in MONKEY_NAMES:
		if not used_names.has(n):
			available_names.append(n)
			
	# Pick a random name from remaining pool (or fallback if empty)
	var chosen_name: String
	if available_names.size() > 0:
		chosen_name = available_names[randi() % available_names.size()]
	else:
		chosen_name = "Monkey " + str(peer_id)
		
	player_names[peer_id] = chosen_name
	print("Assigned name '%s' to peer %d" % [chosen_name, peer_id])
	
	# Sync full names map to all connected peers
	rpc("sync_player_names", player_names)

# Unregisters a player's name on disconnect
func remove_peer_name(peer_id: int) -> void:
	if multiplayer.is_server():
		player_names.erase(peer_id)
		rpc("sync_player_names", player_names)

# Broadcasts updated names map to all clients
@rpc("authority", "call_local", "reliable")
func sync_player_names(updated_names: Dictionary) -> void:
	player_names = updated_names
	player_names_updated.emit(player_names)

# Helper function to get a player's assigned name locally
func get_player_name(peer_id: int) -> String:
	return player_names.get(peer_id, "Player %d" % peer_id)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			if not multiplayer.is_server() and multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
				rpc_id(1, "notify_server_client_leaving", multiplayer.get_unique_id())

		NOTIFICATION_APPLICATION_PAUSED:
			_background_time_msec = Time.get_ticks_msec()
			print("App paused at timestamp: ", _background_time_msec)
			
		NOTIFICATION_APPLICATION_RESUMED:
			if _background_time_msec > 0:
				var elapsed_seconds = (Time.get_ticks_msec() - _background_time_msec) / 1000.0
				print("App resumed after %.2f seconds." % elapsed_seconds)
				
				if elapsed_seconds > MAX_BACKGROUND_SECONDS:
					print("App backgrounded too long! Returning to single player...")
					if host_mode_enabled:
						host_force_return_to_single_player()
					else:
						force_return_to_single_player()
				
				_background_time_msec = 0

func _setup_ping_request():
	if is_instance_valid(_ping_request):
		_ping_request.queue_free()
		
	_ping_request = HTTPRequest.new()
	_ping_request.name = "NetworkPingRequest"
	_ping_request.timeout = 3.0
	_ping_request.request_completed.connect(_on_ping_request_completed)
	add_child(_ping_request)

func _on_ping_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS or response_code == 0:
		_consecutive_ping_failures += 1
		print("Host internet ping failed (%d/%d)" % [_consecutive_ping_failures, MAX_PING_FAILURES])
	else:
		if _is_reconnecting:
			_is_reconnecting = false
			player_reconnected_notif.emit("Connection restored!")
			
		_consecutive_ping_failures = 0

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

func _login_eos_user(force_retry: bool = false) -> bool:
	if not force_retry and _eos_logged_in and is_instance_valid(HAuth) and HAuth.product_user_id != "":
		return true

	print("Attempting anonymous EOS login...")
	_eos_logged_in = false
	
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

	if multiplayer.is_server():
		if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			print("[CRITICAL] Host peer disconnected! Returning to single player...")
			_is_reconnecting = false
			host_force_return_to_single_player()
			return

		if _consecutive_ping_failures >= MAX_PING_FAILURES:
			print("[CRITICAL] Host lost internet connection! Restoring single player...")
			_consecutive_ping_failures = 0
			_is_reconnecting = false
			host_force_return_to_single_player()
			return
		elif _consecutive_ping_failures > 0:
			if not _is_reconnecting:
				_is_reconnecting = true
				player_reconnecting_notif.emit("Internet connection unstable, attempting to reconnect...")

		var current_time = Time.get_ticks_msec()
		if (current_time - _last_ping_msec) / 1000.0 >= PING_INTERVAL_SEC:
			_last_ping_msec = current_time
			if is_instance_valid(_ping_request) and _ping_request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
				_ping_request.request("https://1.1.1.1", [], HTTPClient.METHOD_HEAD)

		rpc("receive_host_heartbeat")

	else:
		if _last_host_heartbeat_msec > 0:
			var time_since_last_ping = (Time.get_ticks_msec() - _last_host_heartbeat_msec) / 1000.0
			if time_since_last_ping > HEARTBEAT_TIMEOUT:
				print("Host ping lost for %.2fs! Force-restoring SinglePlayer." % time_since_last_ping)
				_is_reconnecting = false
				force_return_to_single_player()
			elif time_since_last_ping > 1.5:
				if not _is_reconnecting:
					_is_reconnecting = true
					player_reconnecting_notif.emit("Internet connection unstable, attempting to reconnect...")

@rpc("any_peer", "call_remote", "unreliable")
func receive_host_heartbeat():
	if _is_reconnecting:
		_is_reconnecting = false
		player_reconnected_notif.emit("Reconnected to host!")
		
	_last_host_heartbeat_msec = Time.get_ticks_msec()

func force_return_to_single_player():
	print("[CRITICAL] Host connection dropped or timed out! Forcing SinglePlayer restoration...")
	if is_instance_valid(_heartbeat_timer):
		_heartbeat_timer.stop()
	_last_host_heartbeat_msec = 0
	_on_server_disconnected()

func host_force_return_to_single_player():
	print("[CRITICAL] Host lost network connection! Restoring SinglePlayer...")
	
	# Reset Tag minigame state and UI completely
	cleanup_tag_state_full()
	
	if is_instance_valid(_heartbeat_timer):
		_heartbeat_timer.stop()
		
	_last_host_heartbeat_msec = 0

	var world_scene = get_tree().get_current_scene()
	_players_spawn_node = world_scene.get_node_or_null("Players")

	if active_lobby_id != "":
		destroy_active_lobby_async()

	if eos_peer:
		eos_peer.close()
		eos_peer = null
		
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	if _players_spawn_node:
		for child in _players_spawn_node.get_children():
			_players_spawn_node.remove_child(child)
			child.queue_free()

	host_mode_enabled = false
	num_players_in_theatre = 0
	_stop_video_stream()

	_restore_single_player(FIXED_SINGLEPLAYER_SPAWN, FIXED_GRID_OFFSET)
	
	player_disconnected_notif.emit.call_deferred("Host session ended. Returned to single player!")

func is_network_available(timeout_sec: float = 1.5) -> bool:
	var http = HTTPClient.new()
	var err = http.connect_to_host("1.1.1.1", 80)
	if err != OK:
		return false
	
	var start_time = Time.get_ticks_msec()
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		if (Time.get_ticks_msec() - start_time) > (timeout_sec * 1000):
			http.close()
			return false
		await get_tree().process_frame
		
	var status = http.get_status()
	http.close()
	return status == HTTPClient.STATUS_CONNECTED or status == HTTPClient.STATUS_REQUESTING

func generate_short_code(length: int = 5) -> String:
	var chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code = ""
	for i in range(length):
		code += chars[randi() % chars.length()]
	return code

func become_host() -> bool:
	if not await is_network_available():
		print("No internet connection.")
		return false
	
	if not _eos_logged_in or not is_instance_valid(HAuth) or HAuth.product_user_id == "":
		print("Not connected to EOS. Retrying login...")
		var success = await _login_eos_user()
		if not success:
			print("Cannot host: Unable to authenticate with EOS (check Wi-Fi connection).")
			return false
	
	if active_lobby_id != "":
		print("Cleaning up old lobby before creating a new one...")
		destroy_active_lobby_async()
	
	print("Creating EOS Lobby...")
	host_mode_enabled = true
	
	var world_scene = get_tree().get_current_scene()
	_players_spawn_node = world_scene.get_node_or_null("Players")
	
	var short_code = generate_short_code(5)
	var opts = EOS.Lobby.CreateLobbyOptions.new()
	opts.max_lobby_members = MAX_LOBBY_SIZE
	opts.permission_level = EOS.Lobby.LobbyPermissionLevel.PublicAdvertised
	opts.bucket_id = "Default"
	
	var lobby = await HLobbies.create_lobby_async(opts)
	
	if not lobby:
		print("Lobby creation failed. Refreshing EOS login and retrying in 1.5s...")
		await _login_eos_user(true)
		await get_tree().create_timer(1.5).timeout
		lobby = await HLobbies.create_lobby_async(opts)
	
	if not lobby:
		print("Failed to create EOS Lobby after retry.")
		host_mode_enabled = false
		return false
	
	lobby.add_attribute("ROOM_CODE", short_code, EOS.Lobby.LobbyAttributeVisibility.Public)
	
	var updated = await lobby.update_async()
	if not updated:
		print("Failed to sync room code attribute to lobby.")
		return false
	
	active_lobby_id = lobby.lobby_id
	short_lobby_code = short_code
	print("EOS Lobby Created! Share this Lobby ID: ", short_lobby_code)
	print("(long code: %s)" % active_lobby_id)
	
	if eos_peer == null:
		eos_peer = EOSGMultiplayerPeer.new()
	
	var error = eos_peer.create_server(SOCKET_NAME)
	if error != OK:
		print("Failed to create EOS server peer: ", error)
		host_mode_enabled = false
		return false
		
	multiplayer.multiplayer_peer = eos_peer
	
	if not multiplayer.peer_connected.is_connected(_add_player_to_game):
		multiplayer.peer_connected.connect(_add_player_to_game)
	if not multiplayer.peer_disconnected.is_connected(_delete_player):
		multiplayer.peer_disconnected.connect(_delete_player)
	
	var single_player = world_scene.get_node_or_null("SinglePlayer")
	var position = single_player.global_position if single_player else Vector2.ZERO
	var offset = single_player.current_grid_offset if single_player and "current_grid_offset" in single_player else Vector2.ZERO
	
	_add_player_to_game(1, position, offset)
	_remove_single_player()
	
	if is_instance_valid(_heartbeat_timer):
		_heartbeat_timer.start()
	
	return true

func join_game(id: String) -> Dictionary:
	var code = id.strip_edges().to_upper()
	
	if not await is_network_available():
		print("No internet connection.")
		return {"success": false, "message": ""}
	
	if not _eos_logged_in or not is_instance_valid(HAuth) or HAuth.product_user_id == "":
		print("Not connected to EOS. Retrying login...")
		var success = await _login_eos_user()
		if not success:
			print("Cannot join: Unable to authenticate with EOS.")
			return {"success": false, "message": ""}
	
	print("Joining EOS Lobby: ", code)
	
	var lobbies = await HLobbies.search_by_attribute_async({
		"key": "ROOM_CODE",
		"value": code,
		"comparison": EOS.ComparisonOp.Equal
	})
	
	if not lobbies or lobbies.size() == 0:
		print("Failed to find EOS Lobby with Code: ", code)
		return {"success": false, "message": "No lobby with the entered ID exists!"}
		
	var target_lobby: HLobby = lobbies[0]
	var joined_lobby: HLobby = await HLobbies.join_async(target_lobby)
	
	if not joined_lobby:
		print("Initial join attempt failed. Refreshing login token and retrying...")
		await _login_eos_user(true)
		
		lobbies = await HLobbies.search_by_attribute_async({
			"key": "ROOM_CODE",
			"value": code,
			"comparison": EOS.ComparisonOp.Equal
		})
		
		if lobbies and lobbies.size() > 0:
			joined_lobby = await HLobbies.join_async(lobbies[0])
	
	if not joined_lobby:
		print("[EOS JOIN ERROR] Failed to join existing lobby. Returning 'Lobby is full!'")
		return {"success": false, "message": "Lobby is full! (Max Size = %d)" % MAX_LOBBY_SIZE}
		
	print("Joined EOS Lobby successfully!")
	
	active_lobby_id = joined_lobby.lobby_id
	short_lobby_code = code
	
	var host_user_id = joined_lobby.owner_product_user_id
	
	if eos_peer == null:
		eos_peer = EOSGMultiplayerPeer.new()
	
	var error = eos_peer.create_client(SOCKET_NAME, host_user_id)
	if error != OK:
		print("Failed to create EOS client peer: ", error)
		return {"success": false, "message": ""}
		
	multiplayer.multiplayer_peer = eos_peer
	
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	_last_host_heartbeat_msec = Time.get_ticks_msec()
	if is_instance_valid(_heartbeat_timer):
		_heartbeat_timer.start()
	
	_remove_single_player()
	return {"success": true, "message": ""}

func _on_leave_lobby_button_pressed() -> void:
	if multiplayer.is_server():
		leave_or_close_host_lobby()
	else:
		leave_game_as_joiner()

func leave_or_close_host_lobby():
	if not host_mode_enabled:
		return
	
	# Reset Tag minigame state and UI completely
	cleanup_tag_state_full()
	
	if is_instance_valid(_heartbeat_timer):
		_heartbeat_timer.stop()
	_last_host_heartbeat_msec = 0

	if active_lobby_id != "":
		destroy_active_lobby_async()

	host_mode_enabled = false
	if eos_peer:
		eos_peer.close()
		eos_peer = null
		
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	var world_scene = get_tree().get_current_scene()
	_players_spawn_node = world_scene.get_node_or_null("Players")
	if _players_spawn_node:
		for child in _players_spawn_node.get_children():
			_players_spawn_node.remove_child(child)
			child.queue_free()

	num_players_in_theatre = 0
	_stop_video_stream()

	_restore_single_player(FIXED_SINGLEPLAYER_SPAWN, FIXED_GRID_OFFSET)
	player_names.clear()

func leave_game_as_joiner():
	print("Leaving game as joiner...")
	
	if is_instance_valid(_heartbeat_timer):
		_heartbeat_timer.stop()
	_last_host_heartbeat_msec = 0

	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		rpc_id(1, "notify_server_client_leaving", multiplayer.get_unique_id())

	if active_lobby_id != "":
		leave_active_lobby_async()

	if eos_peer:
		eos_peer.close()
		eos_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	var world_scene = get_tree().get_current_scene()
	_players_spawn_node = world_scene.get_node_or_null("Players")
	if _players_spawn_node:
		for child in _players_spawn_node.get_children():
			_players_spawn_node.remove_child(child)
			child.queue_free()

	_restore_single_player(FIXED_SINGLEPLAYER_SPAWN, FIXED_GRID_OFFSET)
	player_names.clear()

@rpc("any_peer", "call_remote", "reliable")
func notify_server_client_leaving(client_id: int):
	if multiplayer.is_server():
		print("Server received explicit disconnect notification from peer: ", client_id)
		_delete_player(client_id)

func destroy_active_lobby_async():
	if active_lobby_id == "":
		return

	if not is_instance_valid(EOSGRuntime):
		print("EOSGRuntime invalid. Clearing lobby ID locally.")
		active_lobby_id = ""
		short_lobby_code = ""
		return

	print("Destroying EOS Lobby as host: ", active_lobby_id)

	var opts = EOS.Lobby.DestroyLobbyOptions.new()
	opts.lobby_id = active_lobby_id
	if is_instance_valid(HAuth) and HAuth.product_user_id != "":
		opts.local_user_id = HAuth.product_user_id

	active_lobby_id = ""
	short_lobby_code = ""

	EOS.Lobby.LobbyInterface.destroy_lobby(opts)
	var ret = await IEOS.lobby_interface_destroy_lobby_callback
	if EOS.is_success(ret):
		print("EOS Lobby destroyed successfully on Epic servers!")
	else:
		print("Destroy lobby network call completed with status: ", EOS.result_str(ret))

func leave_active_lobby_async():
	if active_lobby_id == "":
		return
		
	print("Leaving EOS Lobby as joiner: ", active_lobby_id)
	var opts = EOS.Lobby.LeaveLobbyOptions.new()
	opts.lobby_id = active_lobby_id
	if is_instance_valid(HAuth) and HAuth.product_user_id != "":
		opts.local_user_id = HAuth.product_user_id
	
	active_lobby_id = ""
	short_lobby_code = ""

	EOS.Lobby.LobbyInterface.leave_lobby(opts)
	var ret = await IEOS.lobby_interface_leave_lobby_callback
	if EOS.is_success(ret):
		print("Left EOS Lobby successfully!")
	else:
		print("Failed to leave EOS Lobby: ", EOS.result_str(ret))

func get_active_lobby_code() -> String:
	return short_lobby_code

func _add_player_to_game(id: int, position: Vector2 = Vector2.INF, offset: Vector2 = Vector2.INF):
	print("player %s joined the game" % id)
	
	# Assign unique monkey name if host
	if multiplayer.is_server():
		assign_unique_name_for_peer(id)
		
		# Sync all existing players' chosen rods and active lures to the newly connected joiner
		print("sync rods to new player")
		for peer_id in player_rods:
			rpc_id(id, "sync_player_rod", peer_id, player_rods[peer_id])
		
		for peer_id in active_lures:
			var lure_data = active_lures[peer_id]
			rpc_id(id, "sync_existing_lure_to_joiner", peer_id, lure_data.start_pos, lure_data.end_pos, lure_data.color)
	
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
	
	# If player disconnects during an active Tag game, trigger mid-game removal
	if is_tag_minigame_started and joined_tag_peers.has(id):
		request_leave_tag_game(id)
	else:
		unregister_tag_player(id)
	
	player_rods.erase(id)
	active_lures.erase(id)
	
	# Free up the player's assigned name
	if multiplayer.is_server():
		remove_peer_name(id)
	
	if not is_instance_valid(_players_spawn_node):
		var world_scene = get_tree().get_current_scene()
		if world_scene:
			_players_spawn_node = world_scene.get_node_or_null("Players")
			
	if not _players_spawn_node:
		return

	var player_node: Node = _players_spawn_node.get_node_or_null(str(id))
	
	if not player_node:
		for child in _players_spawn_node.get_children():
			if ("player_id" in child and child.player_id == id) or child.get_multiplayer_authority() == id:
				player_node = child
				break

	if player_node:
		var sync_node = player_node.get_node_or_null("MultiplayerSynchronizer")
		if sync_node:
			sync_node.public_visibility = false
			sync_node.queue_free()

		var player_position = player_node.global_position if player_node is Node2D else Vector2.ZERO
		var x = player_position.x
		var y = player_position.y
		if (x >= THEATRE_X1 and x <= THEATRE_X2 and y >= THEATRE_Y1 and y <= THEATRE_Y2):
			if multiplayer.is_server():
				decrement_players_in_theatre()
		
		unregister_tag_player(id)
		
		_players_spawn_node.remove_child(player_node)
		player_node.queue_free()
		print("Successfully removed player node for peer: ", id)

func _remove_single_player():
	print("storing and removing single player from scene")
	var world_scene = get_tree().get_current_scene()
	var player_to_remove = world_scene.get_node_or_null("SinglePlayer")
	
	if player_to_remove:
		if player_to_remove.has_method("cleanup_singleplayer_fishing_state"):
			player_to_remove.cleanup_singleplayer_fishing_state()
		
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
	
	# Reset Tag minigame state and UI completely
	cleanup_tag_state_full()
	
	if is_instance_valid(_heartbeat_timer):
		_heartbeat_timer.stop()
	_last_host_heartbeat_msec = 0

	var world_scene = get_tree().get_current_scene()
	_players_spawn_node = world_scene.get_node_or_null("Players")

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if eos_peer:
		eos_peer.close()
		eos_peer = null

	if _players_spawn_node:
		for child in _players_spawn_node.get_children():
			_players_spawn_node.remove_child(child)
			child.queue_free()

	if active_lobby_id != "":
		leave_active_lobby_async()
		
	host_mode_enabled = false
	num_players_in_theatre = 0
	_stop_video_stream()

	_restore_single_player(FIXED_SINGLEPLAYER_SPAWN, FIXED_GRID_OFFSET)
	player_names.clear()

	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)

func _restore_single_player(pos: Vector2, offset: Vector2):
	print("Attempting to restore SinglePlayer...")
	
	if not is_instance_valid(stored_single_player):
		print("ERROR: stored_single_player was freed or null! Cannot restore.")
		return

	var world_scene = get_tree().get_current_scene()
	
	if stored_single_player.get_parent() == world_scene:
		print("SinglePlayer is already active in scene tree.")
		return
	
	stored_single_player.global_position = pos
	if "current_grid_offset" in stored_single_player:
		stored_single_player.current_grid_offset = offset

	world_scene.add_child(stored_single_player)
	print("SUCCESS: SinglePlayer restored at position: ", pos)

	player_disconnected_notif.emit.call_deferred("Disconnected from lobby. Back to single player!")

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

# --- MINIGAME LOBBY RPCs ---

#@rpc("any_peer", "call_remote", "reliable")
#func send_minigame_invite_notif(sender_name: String, game_name: String = "Tag") -> void:
	#player_reconnected_notif.emit("%s invited you to play %s!" % [sender_name, game_name], true)

@rpc("any_peer", "call_local", "reliable")
func send_minigame_invite_notif(sender_name: String, game_name: String = "Tag") -> void:
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		# If host pressed the invite button locally, sender_id is local host ID (1)
		if sender_id == 0:
			sender_id = multiplayer.get_unique_id()
			
		# 1. Check if the Host (Peer ID 1) needs an invite (when sender is a Joiner)
		if sender_id != 1 and not joined_tag_peers.has(1):
			# Deliver notification directly to host locally
			player_reconnected_notif.emit("%s invited you to play %s!" % [sender_name, game_name], true)
			
		# 2. Check all remote client peers
		for peer_id in multiplayer.get_peers():
			if peer_id != sender_id and not joined_tag_peers.has(peer_id):
				rpc_id(peer_id, "receive_invite_notif", sender_name, game_name)

# Executed only on peers who haven't joined yet
@rpc("authority", "call_local", "reliable")
func receive_invite_notif(sender_name: String, game_name: String) -> void:
	player_reconnected_notif.emit("%s invited you to play %s!" % [sender_name, game_name], true)

@rpc("any_peer", "call_local", "reliable")
func register_tag_player(peer_id: int) -> void:
	if multiplayer.is_server():
		# Block new entries if a minigame is actively running
		if is_tag_minigame_started:
			rpc_id(peer_id, "notify_tag_in_progress")
			return
			
		if not joined_tag_peers.has(peer_id):
			joined_tag_peers.append(peer_id)
			print("Registered peer %d for Tag. Current lobby: %s" % [peer_id, str(joined_tag_peers)])
			rpc("sync_tag_lobby_ui", joined_tag_peers)

# Unregisters a player from the Tag lobby on the server and syncs the updated list
@rpc("any_peer", "call_local", "reliable")
func unregister_tag_player(peer_id: int) -> void:
	if multiplayer.is_server():
		if joined_tag_peers.has(peer_id):
			joined_tag_peers.erase(peer_id)
			print("Unregistered peer %d from Tag. Current lobby: %s" % [peer_id, str(joined_tag_peers)])
			rpc("sync_tag_lobby_ui", joined_tag_peers)

@rpc("authority", "call_local", "reliable")
func sync_tag_lobby_ui(peers: Array[int]) -> void:
	joined_tag_peers = peers
	tag_lobby_updated.emit(joined_tag_peers)

func reset_tag_lobby() -> void:
	if multiplayer.is_server():
		joined_tag_peers.clear()
		is_tag_minigame_started = false
		is_tag_countdown_active = false # Reset countdown lock
		tag_it_peer_id = -1
		tag_cooldown_until_ms = 0
		rpc("sync_tag_lobby_ui", joined_tag_peers)

#@rpc("any_peer", "call_local", "reliable")
#func request_start_tag_game() -> void:
	#if multiplayer.is_server():
		#if joined_tag_peers.size() > 0:
			#print("Server launching Tag game for peers: ", joined_tag_peers)
			#rpc("launch_tag_game_session", joined_tag_peers)
		#else:
			#print("Cannot start Tag game: No players registered in tag lobby.")

@rpc("authority", "call_local", "reliable")
func notify_not_enough_players() -> void:
	var world_scene = get_tree().get_current_scene()
	var game_manager = world_scene.get_node_or_null("GameManager")
	if game_manager and game_manager.has_method("show_temp_notif"):
		game_manager.show_temp_notif("At least 2 players are needed to start Tag!")

@rpc("authority", "call_local", "reliable")
func start_tag_roulette_sequence(participating_peers: Array[int], target_it_peer: int, total_steps: int) -> void:
	tag_it_peer_id = target_it_peer
	
	# Call local UI roulette sequence on GameManager
	var world_scene = get_tree().get_current_scene()
	var game_manager = world_scene.get_node_or_null("GameManager")
	if game_manager and game_manager.has_method("run_tag_roulette"):
		game_manager.run_tag_roulette(participating_peers, target_it_peer, total_steps)

@rpc("any_peer", "call_local", "reliable")
func request_start_tag_game() -> void:
	if multiplayer.is_server():
		# Require at least 2 players to start Tag
		if joined_tag_peers.size() >= 2:
			# Lock the Tag lobby so no outside players can join mid-match
			rpc("set_tag_minigame_started", true)
			
			var target_index = randi() % joined_tag_peers.size()
			var chosen_it_peer = joined_tag_peers[target_index]
			
			var full_laps = randi_range(4, 6)
			var steps_count = (full_laps * joined_tag_peers.size()) + target_index + 1
			
			tag_it_peer_id = chosen_it_peer
			print("Server selected peer %d as IT! Launching roulette with %d steps..." % [chosen_it_peer, steps_count])
			
			rpc("start_tag_roulette_sequence", joined_tag_peers, chosen_it_peer, steps_count)
		else:
			print("Cannot start Tag game: At least 2 players are required.")
			# Notify the peer who tried to start
			var sender_id = multiplayer.get_remote_sender_id()
			if sender_id == 0:
				sender_id = multiplayer.get_unique_id()
			
			rpc_id(sender_id, "notify_not_enough_players")

# Call this when the Tag match finishes or is forcibly reset
func end_tag_minigame() -> void:
	if multiplayer.is_server():
		is_tag_countdown_active = false # Reset countdown lock
		restore_all_players_movement()  # Ensure no player is left frozen
		rpc("set_tag_minigame_started", false)

# Server broadcasts minigame start/stop state
@rpc("authority", "call_local", "reliable")
func set_tag_minigame_started(started: bool) -> void:
	is_tag_minigame_started = started
	print("Tag minigame active state set to: ", is_tag_minigame_started)

# Notify a client when they attempt to join an active session
@rpc("authority", "call_local", "reliable")
func notify_tag_in_progress() -> void:
	var world_scene = get_tree().get_current_scene()
	var game_manager = world_scene.get_node_or_null("GameManager")
	if game_manager and game_manager.has_method("show_temp_notif"):
		game_manager.show_temp_notif("Cannot join: A Tag game is currently in progress!")

func _set_local_player_frozen(target_it_peer: int, frozen: bool) -> void:
	if multiplayer.get_unique_id() == target_it_peer:
		var world_scene = get_tree().get_current_scene()
		var players_node = world_scene.get_node_or_null("Players")
		if players_node:
			var local_player = players_node.get_node_or_null(str(target_it_peer))
			if is_instance_valid(local_player) and "is_frozen" in local_player:
				local_player.is_frozen = frozen

@rpc("authority", "call_local", "reliable")
func unfreeze_it_player(target_it_peer: int) -> void:
	is_tag_countdown_active = false # UNLOCK TAGS NOW THAT MOVEMENT IS ENABLED
	var world_scene = get_tree().get_current_scene()
	var players_node = world_scene.get_node_or_null("Players")
	if players_node:
		var it_player = players_node.get_node_or_null(str(target_it_peer))
		if is_instance_valid(it_player) and it_player.has_method("set_movement_disabled"):
			it_player.rpc("set_movement_disabled", false)

@rpc("authority", "call_local", "reliable")
func setup_tag_game_session(participating_peers: Array[int], target_it_peer: int) -> void:
	tag_it_peer_id = target_it_peer
	is_tag_minigame_started = true
	tag_cooldown_until_ms = 0 # Reset cooldown lock on game start!
	is_tag_countdown_active = true # LOCK TAGS DURING COUNTDOWN
	
	var world_scene = get_tree().get_current_scene()
	var game_manager = world_scene.get_node_or_null("GameManager")
	var players_node = world_scene.get_node_or_null("Players") # Node containing character instances
	
	if not players_node:
		return

	var non_it_index = 0
	
	for peer_id in participating_peers:
		var player_instance = players_node.get_node_or_null(str(peer_id))
		if is_instance_valid(player_instance):
			var is_it = (peer_id == target_it_peer)
			
			# 1. Position players around "It"
			if is_it:
				player_instance.global_position = IT_SPAWN_POS
				player_instance.update_zone_offset(Vector2.ZERO)
			else:
				var pos_idx = non_it_index % PLAYER_SPAWN_POSITIONS.size()
				player_instance.global_position = PLAYER_SPAWN_POSITIONS[pos_idx]
				player_instance.update_zone_offset(Vector2.ZERO)
				non_it_index += 1
			
			# 2. Update overhead player indicator (red vs blue)
			if player_instance.has_method("set_tag_indicator"):
				player_instance.set_tag_indicator(is_it)

	# 3. Handle local notifications & UI timer setup ONLY for active participants
	var local_id = multiplayer.get_unique_id()
	if game_manager and participating_peers.has(local_id):
		var it_name = get_player_name(target_it_peer)
		if local_id == target_it_peer:
			game_manager.show_temp_notif("You're IT!")
		else:
			game_manager.show_temp_notif("%s is IT, run!!" % it_name)
		
		# Start 5s countdown for active participants
		game_manager.start_tag_countdown(5)
	
	# 4. Disable movement for the "It" player during the countdown
	var it_player = players_node.get_node_or_null(str(target_it_peer))
	if is_instance_valid(it_player) and it_player.has_method("set_movement_disabled"):
		it_player.rpc("set_movement_disabled", true)

# RPC to synchronized spawning and initial state on all clients
#@rpc("authority", "call_local", "reliable")
#func setup_tag_game_session(participating_peers: Array[int], target_it_peer: int) -> void:
	#tag_it_peer_id = target_it_peer
	#is_tag_minigame_started = true
	#tag_cooldown_until_ms = 0 # Reset cooldown lock on game start!
	#is_tag_countdown_active = true # LOCK TAGS DURING COUNTDOWN
	#
	#var world_scene = get_tree().get_current_scene()
	#var game_manager = world_scene.get_node_or_null("GameManager")
	#var players_node = world_scene.get_node_or_null("Players") # Node containing character instances
	#
	#if not players_node:
		#return
#
	#var non_it_index = 0
	#
	#for peer_id in participating_peers:
		#var player_instance = players_node.get_node_or_null(str(peer_id))
		#if is_instance_valid(player_instance):
			#var is_it = (peer_id == target_it_peer)
			#
			## 1. Position players around "It"
			#if is_it:
				#player_instance.global_position = IT_SPAWN_POS
				#player_instance.update_zone_offset(Vector2.ZERO)
			#else:
				#var pos_idx = non_it_index % PLAYER_SPAWN_POSITIONS.size()
				#player_instance.global_position = PLAYER_SPAWN_POSITIONS[pos_idx]
				#player_instance.update_zone_offset(Vector2.ZERO)
				#non_it_index += 1
			#
			## 2. Update overhead player indicator (red vs blue)
			#if player_instance.has_method("set_tag_indicator"):
				#player_instance.set_tag_indicator(is_it)
#
	## 3. Handle local notifications & UI timer setup
	#if game_manager:
		#var local_id = multiplayer.get_unique_id()
		#if participating_peers.has(local_id):
			#var it_name = get_player_name(target_it_peer)
			#if local_id == target_it_peer:
				#game_manager.show_temp_notif("You're IT!")
			#else:
				#game_manager.show_temp_notif("%s is IT, run!!" % it_name)
		#
		## Start 5s countdown
		#game_manager.start_tag_countdown(5)
	#
	## 4. Disable movement for the "It" player during the countdown
	#var it_player = players_node.get_node_or_null(str(target_it_peer))
	#if is_instance_valid(it_player) and it_player.has_method("set_movement_disabled"):
		#it_player.rpc("set_movement_disabled", true)

# Returns true if the specified peer ID is actively participating in an ongoing Tag match
func is_player_in_tag_game(peer_id: int) -> bool:
	return is_tag_minigame_started and joined_tag_peers.has(peer_id)

@rpc("any_peer", "call_local", "reliable")
func request_player_tag(tagged_peer_id: int) -> void:
	print("request player tag")
	# Only the server evaluates tag collisions
	if not multiplayer.is_server():
		return
		
	# Security & Cooldown checks
	if not is_tag_minigame_started or is_tag_countdown_active:
		return
		
	# Check 2-second cooldown timestamp
	if Time.get_ticks_msec() < tag_cooldown_until_ms:
		return
		
	# Ensure the target is actually registered in the match and isn't already "It"
	if not joined_tag_peers.has(tagged_peer_id) or tagged_peer_id == tag_it_peer_id:
		return
		
	# Set 2-second cooldown timestamp on server
	tag_cooldown_until_ms = Time.get_ticks_msec() + 2000
	
	# Cache OLD "It" peer before updating tag_it_peer_id
	var old_it_peer = tag_it_peer_id
	tag_it_peer_id = tagged_peer_id
	
	print("Server validated tag! Swapping 'IT' from peer %d to peer %d" % [old_it_peer, tagged_peer_id])
	
	# Broadcast role swap across all clients
	rpc("sync_player_tagged", old_it_peer, tagged_peer_id)

@rpc("authority", "call_local", "reliable")
func sync_player_tagged(old_it_peer: int, new_it_peer: int) -> void:
	# Explicitly update tag_it_peer_id on all receiving clients
	print("sync player tagged")
	tag_it_peer_id = new_it_peer

	var world_scene = get_tree().get_current_scene()
	var game_manager = world_scene.get_node_or_null("GameManager")
	var players_node = world_scene.get_node_or_null("Players")
	
	if players_node:
		# 1. Turn old "It" player indicator back to WHITE
		var old_it_node = players_node.get_node_or_null(str(old_it_peer))
		if is_instance_valid(old_it_node) and old_it_node.has_method("set_tag_indicator"):
			old_it_node.set_tag_indicator(false)
			
		# 2. Turn new "It" player indicator to GOLD
		var new_it_node = players_node.get_node_or_null(str(new_it_peer))
		if is_instance_valid(new_it_node) and new_it_node.has_method("set_tag_indicator"):
			new_it_node.set_tag_indicator(true)
			
	# 3. Handle local notification UI
	var local_peer = multiplayer.get_unique_id()
	if game_manager:
		if local_peer == new_it_peer:
			game_manager.show_temp_notif("You're IT! (2s timer until you can tag others)", 2)
			game_manager.start_tag_cooldown_ui(2.0)
		elif local_peer == old_it_peer:
			var new_it_name = get_player_name(new_it_peer)
			game_manager.show_temp_notif("You tagged %s!" % new_it_name, 2)
		#elif joined_tag_peers.has(local_peer):
			#var new_it_name = get_player_name(new_it_peer)
			#game_manager.show_temp_notif("%s is now it, run!!" % new_it_name)

# Triggered when a player leaves the active minigame mid-match
@rpc("any_peer", "call_local", "reliable")
func request_leave_tag_game(leaving_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	if not is_tag_minigame_started or not joined_tag_peers.has(leaving_peer_id):
		return
		
	print("Server handling mid-game departure for peer: ", leaving_peer_id)
	
	# 1. Snapshot participants BEFORE modifying the list
	var active_participants = joined_tag_peers.duplicate()
	
	# 2. Remove departing player from active participants
	joined_tag_peers.erase(leaving_peer_id)
	
	# 3. Check if departing player was "It"
	var was_it = (leaving_peer_id == tag_it_peer_id)
	var new_it_peer = -1
	
	# 4. Evaluate remaining players
	if joined_tag_peers.size() >= 2:
		rpc("sync_tag_lobby_ui", joined_tag_peers)
		if was_it:
			new_it_peer = joined_tag_peers[randi() % joined_tag_peers.size()]
			tag_it_peer_id = new_it_peer
		rpc("sync_player_left_tag", leaving_peer_id, was_it, new_it_peer)
	else:
		# Match CANNOT continue: Stop game state first
		end_tag_minigame()
		
		# Global broadcast: Cleans indicators for EVERYONE, but filters notif for participants
		rpc("broadcast_tag_match_cancelled", active_participants, "Match cancelled: Not enough players remaining!")
		
		# Reset and wipe Tag lobby state across network
		reset_tag_lobby()

# Executed ONLY on client instances that were in the match (via rpc_id)
@rpc("authority", "call_local", "reliable")
func receive_tag_match_cancelled(reason: String) -> void:
	is_tag_minigame_started = false
	tag_it_peer_id = -1
	
	var world_scene = get_tree().get_current_scene()
	var game_manager = world_scene.get_node_or_null("GameManager")
	var players_node = world_scene.get_node_or_null("Players")
	
	# Hide overhead indicators for remaining players
	if players_node:
		for child in players_node.get_children():
			if child.has_method("hide_tag_indicator"):
				child.hide_tag_indicator()
				
	if game_manager:
		game_manager.cleanup_tag_ui_local()
		game_manager.show_temp_notif(reason)
		
		if game_manager.has_method("_update_tag_player_grid"):
			game_manager._update_tag_player_grid(joined_tag_peers)

@rpc("authority", "call_local", "reliable")
func sync_player_left_tag(leaving_peer_id: int, was_it: bool, new_it_peer: int) -> void:
	var world_scene = get_tree().get_current_scene()
	var game_manager = world_scene.get_node_or_null("GameManager")
	var players_node = world_scene.get_node_or_null("Players")
	
	if players_node:
		# 1. Hide the departing player's tag indicator
		var leaving_node = players_node.get_node_or_null(str(leaving_peer_id))
		if is_instance_valid(leaving_node) and leaving_node.has_method("hide_tag_indicator"):
			leaving_node.hide_tag_indicator()
			
		# 2. If "It" was reassigned, update the new "It" player's indicator
		if was_it and new_it_peer != -1:
			tag_it_peer_id = new_it_peer
			var new_it_node = players_node.get_node_or_null(str(new_it_peer))
			if is_instance_valid(new_it_node) and new_it_node.has_method("set_tag_indicator"):
				new_it_node.set_tag_indicator(true) # Set to Gold

	# 3. UI notifications
	var local_id = multiplayer.get_unique_id()
	if game_manager:
		var leaving_name = get_player_name(leaving_peer_id)
		
		if local_id == leaving_peer_id:
			# Local player is the one who left
			game_manager.cleanup_tag_ui_local()
			game_manager.show_temp_notif("You left the Tag game.")
		elif joined_tag_peers.has(local_id):
			# Remaining participants
			if was_it and new_it_peer != -1:
				var new_it_name = get_player_name(new_it_peer)
				game_manager.show_temp_notif("%s left! %s is now IT!" % [leaving_name, new_it_name])
			else:
				game_manager.show_temp_notif("%s left the Tag game." % leaving_name)
				
		# Refresh grid UI in case the minigame popup is open
		game_manager._update_tag_player_grid(joined_tag_peers)

@rpc("authority", "call_local", "reliable")
func broadcast_tag_match_cancelled(affected_peers: Array[int], reason: String) -> void:
	var local_id = multiplayer.get_unique_id()
	
	is_tag_minigame_started = false
	is_tag_countdown_active = false # Reset countdown lock
	tag_it_peer_id = -1
	
	restore_all_players_movement()
	
	var world_scene = get_tree().get_current_scene()
	var game_manager = world_scene.get_node_or_null("GameManager")
	var players_node = world_scene.get_node_or_null("Players")
	
	# Ensure local player movement is un-disabled if match was cancelled during 5s countdown
	if players_node:
		var local_player = players_node.get_node_or_null(str(local_id))
		if is_instance_valid(local_player) and local_player.has_method("set_movement_disabled"):
			local_player.set_movement_disabled(false)
	
	# 1. WIPE INDICATORS FOR EVERYONE (Fixes lingering arrows for departed players & spectators)
	if players_node:
		for child in players_node.get_children():
			if child.has_method("hide_tag_indicator"):
				child.hide_tag_indicator()
				
	# 2. FILTER NOTIFICATION POPUP (Only show notif to players who were actually in the match)
	if game_manager:
		if affected_peers.has(local_id):
			game_manager.cleanup_tag_ui_local()
			game_manager.show_temp_notif(reason)
			
		if game_manager.has_method("_update_tag_player_grid"):
			game_manager._update_tag_player_grid(joined_tag_peers)

func cleanup_tag_state_full() -> void:
	is_tag_minigame_started = false
	is_tag_countdown_active = false
	tag_it_peer_id = -1
	tag_cooldown_until_ms = 0
	joined_tag_peers.clear()
	restore_all_players_movement()
	
	# Notify GameManager to hide all tag UI locally
	var world_scene = get_tree().get_current_scene()
	if world_scene:
		var game_manager = world_scene.get_node_or_null("GameManager")
		if is_instance_valid(game_manager) and game_manager.has_method("cleanup_tag_ui_local"):
			game_manager.cleanup_tag_ui_local()

# Triggered by host when 2-minute timer reaches 00:00
func request_end_tag_match_naturally() -> void:
	if not multiplayer.is_server() or not is_tag_minigame_started:
		return
		
	var loser_id = tag_it_peer_id
	var participants = joined_tag_peers.duplicate()
	
	# Mark minigame as finished on server
	end_tag_minigame()
	
	# Broadcast completion UI transition to active participants
	rpc("sync_tag_match_ended", participants, loser_id)

@rpc("authority", "call_local", "reliable")
func sync_tag_match_ended(participants: Array[int], loser_id: int) -> void:
	is_tag_minigame_started = false
	is_tag_countdown_active = false
	tag_it_peer_id = -1
	restore_all_players_movement()
	
	var local_id = multiplayer.get_unique_id()
	var world_scene = get_tree().get_current_scene()
	var game_manager = world_scene.get_node_or_null("GameManager")
	var players_node = world_scene.get_node_or_null("Players")
	
	# 1. Clear overhead indicators for all player nodes
	if players_node:
		for child in players_node.get_children():
			if child.has_method("hide_tag_indicator"):
				child.hide_tag_indicator()
				
	# 2. Only process match-end UI transitions for participating players
	if game_manager and participants.has(local_id):
		game_manager.return_participants_to_tag_menu(participants, loser_id)

# Safety helper: Restores movement and clears freeze locks for all spawned character nodes
func restore_all_players_movement() -> void:
	var world_scene = get_tree().get_current_scene()
	if not world_scene:
		return
		
	var players_node = world_scene.get_node_or_null("Players")
	if is_instance_valid(players_node):
		for child in players_node.get_children():
			if is_instance_valid(child) and child.has_method("set_movement_disabled"):
				child.set_movement_disabled(false)

@rpc("any_peer", "call_local", "reliable")
func request_equip_rod(rod: FishingRod) -> void:
	print("request_equip_rod: %s" % rod)
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
		
	if multiplayer.is_server():
		player_rods[sender_id] = rod
		rpc("sync_player_rod", sender_id, rod)

@rpc("any_peer", "call_local", "reliable")
func request_unequip_rod() -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id() # Host local fallback
		
	if multiplayer.is_server():
		player_rods.erase(sender_id)
		# Broadcast unequip to all clients
		rpc("sync_player_unequip_rod", sender_id)

@rpc("authority", "call_local", "reliable")
func sync_player_rod(peer_id: int, rod: FishingRod) -> void:
	print("sync_player_rod: %s" % rod)
	player_rods[peer_id] = rod
	
	var world_scene = get_tree().get_current_scene()
	if not world_scene:
		return
		
	var players_node = world_scene.get_node_or_null("Players")
	if is_instance_valid(players_node):
		var player_node = players_node.get_node_or_null(str(peer_id))
		if is_instance_valid(player_node) and player_node.has_method("equip_rod_visual"):
			player_node.equip_rod_visual(rod)

@rpc("authority", "call_local", "reliable")
func sync_player_unequip_rod(peer_id: int) -> void:
	player_rods.erase(peer_id)
	
	# Find the player node on scene tree and remove/hide their rod visual
	var world_scene = get_tree().get_current_scene()
	if not world_scene:
		return
		
	var players_node = world_scene.get_node_or_null("Players")
	if is_instance_valid(players_node):
		var player_node = players_node.get_node_or_null(str(peer_id))
		if is_instance_valid(player_node) and player_node.has_method("unequip_rod_visual"):
			player_node.unequip_rod_visual()

# Triggered by player when casting
@rpc("any_peer", "call_local", "reliable")
func register_active_lure(start_pos: Vector2, end_pos: Vector2, color: Color) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
		
	if multiplayer.is_server():
		active_lures[sender_id] = {
			"start_pos": start_pos,
			"end_pos": end_pos,
			"color": color
		}

# Triggered when unequipped or re-cast
@rpc("any_peer", "call_local", "reliable")
func unregister_active_lure(peer_id: int = 0) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	var target_id = peer_id if peer_id != 0 else sender_id
	
	if multiplayer.is_server():
		active_lures.erase(target_id)

# Target RPC sent strictly to new joiner
@rpc("authority", "call_local", "reliable")
func sync_existing_lure_to_joiner(peer_id: int, start_pos: Vector2, end_pos: Vector2, color: Color) -> void:
	var world_scene = get_tree().get_current_scene()
	if not world_scene:
		return
		
	var players_node = world_scene.get_node_or_null("Players")
	if is_instance_valid(players_node):
		var player_node = players_node.get_node_or_null(str(peer_id))
		# Tell the joiner's local instance of that monkey to draw the lure floating directly in the water
		if is_instance_valid(player_node) and player_node.has_method("spawn_static_lure_for_joiner"):
			player_node.spawn_static_lure_for_joiner(end_pos, color)
