extends Node

const SERVER_PORT = 8080
const SERVER_IP = "127.0.0.1"
const MAC_IP = "192.168.2.23"

var multiplayer_scene = preload("res://scenes/player/monkey_multiplayer.tscn")
var _players_spawn_node
var host_mode_enabled = false

# used to stop movie stream if no players in theatre
var num_players_in_theatre: int = 0

func become_host():
	print("become host")
	host_mode_enabled = true
	
	# move multiplayers spawn point to current position of single player
	var world_scene = get_tree().get_current_scene()
	_players_spawn_node = world_scene.get_node("Players")
	var single_player = world_scene.get_node_or_null("SinglePlayer")
	if single_player:
		_players_spawn_node.global_position = single_player.global_position
	
	# create multiplayer server
	var server_peer = ENetMultiplayerPeer.new()
	server_peer.create_server(SERVER_PORT)
	
	# set multiplayer callbacks
	multiplayer.multiplayer_peer = server_peer
	multiplayer.peer_connected.connect(_add_player_to_game)
	multiplayer.peer_disconnected.connect(_delete_player)
	
	# remove single player and spawn multi player
	_remove_single_player()
	_add_player_to_game(1)

func join_game():
	print("join game")
	
	var client_peer = ENetMultiplayerPeer.new()
	client_peer.create_client(SERVER_IP, SERVER_PORT)
	#client_peer.create_client(MAC_IP, SERVER_PORT)
	
	multiplayer.multiplayer_peer = client_peer
	
	_remove_single_player()
	
func _add_player_to_game(id: int):
	print("player %s joined the game" % id)
	
	var player_to_add = multiplayer_scene.instantiate()
	player_to_add.player_id = id
	player_to_add.name = str(id)
	
	# Add child first so multiplayer authority & spawner register it
	_players_spawn_node.add_child(player_to_add, true)
	
	# If a client joined an active host (Host is peer ID 1)
	if id != 1:
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
			# (x1, y1) = top left theatremap offset
			# (x2, y2) = bottom right theatremap based on texturerect size (1280, 720)
			var theatre_x1 = 0
			var theatre_x2 = 1280 
			var theatre_y1 = -1800
			var theatre_y2 = -1800 + 720
			var x = target_pos.x
			var y = target_pos.y
			if (x >= theatre_x1 and x <= theatre_x2 and y >= theatre_y1 and y <= theatre_y2):
				MultiplayerManager.rpc_id(1, "increment_players_in_theatre")
	
func _delete_player(id: int):
	print("player %s left the game" % id)
	if not (_players_spawn_node.has_node(str(id))):
		return
	_players_spawn_node.get_node(str(id)).queue_free()
	
func _remove_single_player():
	print("remove single player")
	var player_to_remove = get_tree().get_current_scene().get_node("SinglePlayer")
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
