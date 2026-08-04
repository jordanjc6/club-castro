extends Node

const SERVER_PORT = 8080
const SERVER_IP = "127.0.0.1"
const MAC_IP = "192.168.2.23"

# (x1, y1) = top left theatremap offset
# (x2, y2) = bottom right theatremap based on texturerect size (1280, 720)
const THEATRE_X1 = 0
const THEATRE_X2 = 1280 
const THEATRE_Y1 = -1800
const THEATRE_Y2 = -1800 + 720

var multiplayer_scene = preload("res://scenes/player/monkey_multiplayer.tscn")
var _players_spawn_node
var host_mode_enabled = false

# used to stop movie stream if no players in theatre
var num_players_in_theatre: int = 0

func become_host():
	print("become host")
	host_mode_enabled = true
	
	# set players spawn node
	var world_scene = get_tree().get_current_scene()
	_players_spawn_node = world_scene.get_node("Players")
	
	# create multiplayer server
	var server_peer = ENetMultiplayerPeer.new()
	server_peer.create_server(SERVER_PORT)
	
	# set multiplayer callbacks
	multiplayer.multiplayer_peer = server_peer
	multiplayer.peer_connected.connect(_add_player_to_game)
	multiplayer.peer_disconnected.connect(_delete_player)
	
	# spawn multi player and remove single player
	var single_player = world_scene.get_node_or_null("SinglePlayer")
	var position = single_player.global_position
	var offset = single_player.current_grid_offset
	_add_player_to_game(1, position, offset)
	_remove_single_player()

func join_game():
	print("join game")
	
	var client_peer = ENetMultiplayerPeer.new()
	client_peer.create_client(SERVER_IP, SERVER_PORT)
	#client_peer.create_client(MAC_IP, SERVER_PORT)
	
	multiplayer.multiplayer_peer = client_peer
	
	_remove_single_player()
	
func _add_player_to_game(id: int, position: Vector2 = Vector2.INF, offset: Vector2 = Vector2.INF):
	print("player %s joined the game" % id)
	
	# instantiate player
	var player_to_add = multiplayer_scene.instantiate()
	player_to_add.player_id = id
	player_to_add.name = str(id)
	_players_spawn_node.add_child(player_to_add, true)
	
	# set player spawn position
	if id == 1:
		# for host
		player_to_add.global_position = position
		player_to_add.current_grid_offset = offset
		
		# Tell the client explicitly to update its zone offset
		player_to_add.rpc("update_zone_offset", offset)
		
		# increment count if player spawns in theatre
		var x = position.x
		var y = position.y
		if (x >= THEATRE_X1 and x <= THEATRE_X2 and y >= THEATRE_Y1 and y <= THEATRE_Y2):
			MultiplayerManager.rpc_id(1, "increment_players_in_theatre")
	
	if id != 1:
		# for client
		var host_player = _players_spawn_node.get_node_or_null("1")
		if host_player:
			var target_pos = host_player.global_position
			var target_grid_offset = host_player.current_grid_offset
			
			# Set on server
			player_to_add.global_position = target_pos
			player_to_add.current_grid_offset = target_grid_offset
			
			# Tell the client explicitly to update its zone offset
			player_to_add.rpc("update_zone_offset", target_grid_offset)
			
			# increment count if player spawns in theatre
			var x = target_pos.x
			var y = target_pos.y
			if (x >= THEATRE_X1 and x <= THEATRE_X2 and y >= THEATRE_Y1 and y <= THEATRE_Y2):
				MultiplayerManager.rpc_id(1, "increment_players_in_theatre")

func _delete_player(id: int):
	print("player %s left the game" % id)
	if not (_players_spawn_node.has_node(str(id))):
		return
	var player = _players_spawn_node.get_node(str(id))
	
	# decrement theatre players if removed player was in there
	var player_position = player.global_position
	var x = player_position.x
	var y = player_position.y
	if (x >= THEATRE_X1 and x <= THEATRE_X2 and y >= THEATRE_Y1 and y <= THEATRE_Y2):
		MultiplayerManager.rpc_id(1, "decrement_players_in_theatre")
	
	# remove player
	_players_spawn_node.get_node(str(id)).queue_free()
	
func _remove_single_player():
	print("remove single player")
	var player_to_remove = get_tree().get_current_scene().get_node("SinglePlayer")
	
	# decrement theatre players if removed player was in there
	var player_position = player_to_remove.global_position
	var x = player_position.x
	var y = player_position.y
	if (x >= THEATRE_X1 and x <= THEATRE_X2 and y >= THEATRE_Y1 and y <= THEATRE_Y2):
		MultiplayerManager.rpc_id(1, "decrement_players_in_theatre")
	
	# remove player
	player_to_remove.queue_free()

@rpc("any_peer", "call_local", "reliable")
func increment_players_in_theatre():
	if multiplayer.is_server():
		# server tracks the master count
		num_players_in_theatre += 1
		print("Number of players in theatre: %d" % num_players_in_theatre)
		rpc("sync_player_count", num_players_in_theatre)

@rpc("any_peer", "call_local", "reliable")
func decrement_players_in_theatre():
	if multiplayer.is_server():
		# server tracks the master count
		num_players_in_theatre -= 1
		print("Number of players in theatre: %d" % num_players_in_theatre)
		rpc("sync_player_count", num_players_in_theatre)

# all clients receive the updated count after server updates it
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
	video_player.stop()
	video_player.stream = null
	movie_projector.current_movie_index = -1
	movie_projector.is_movie_selector_open = false
	movie_selector.visible = false
