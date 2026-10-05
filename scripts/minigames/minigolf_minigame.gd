extends Node2D

const BALL_COLORS: Array[Color] = [
	Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE
]

@onready var minigolf_menu: PanelContainer = $"../HUD/MinigamesPopup/MinigolfMenu"
@onready var course_container: MarginContainer = $Screen/UI/HBoxContainer/Course

var minigolf_turn_order: Array[int] = []  # Player IDs in turn order
var player_data: Dictionary = {}
var current_turn_id: int  # Active Player ID
var current_course_number: int = 1  # Course 1, 2, or 3 out of 3

@rpc("authority", "call_local", "reliable")
func start_minigolf(turn_order: Array[int]) -> void:
	if multiplayer.is_server():
		MultiplayerManager.rpc("set_minigolf_started", true)
	current_course_number = 1
	current_turn_id = turn_order[0]
	initialize_game_state(turn_order)
	#refresh_minigolf_hud()
	#load_course(current_course_number)
	
	print("Minigolf Game Successfully Started!")

func initialize_game_state(turn_order: Array[int]) -> void:
	minigolf_turn_order = turn_order
	player_data.clear()
	for i in range(turn_order.size()):
		var peer_id = turn_order[i]
		player_data[peer_id] = {
			"id": peer_id,
			"name": MultiplayerManager.get_player_name(peer_id),
			"color": BALL_COLORS[i % BALL_COLORS.size()],
			"total_strokes": 0,
			"current_strokes": 0,
			"ball_node": null,
			"finished_hole": false
		}

func load_course(course_num: int) -> void:
	# Clear previous course if one exists
	for child in course_container.get_children():
		child.queue_free()
		
	# Dynamically instantiate the new course
	var course_path = "res://scenes/courses/Course%d.tscn" % course_num
	if ResourceLoader.exists(course_path):
		var course_scene = load(course_path) as PackedScene
		var course_instance = course_scene.instantiate()
		course_container.add_child(course_instance)

# Called on the Server to switch turns during active gameplay
func advance_to_next_turn() -> void:
	if not multiplayer.is_server():
		return
		
	var current_index = minigolf_turn_order.find(current_turn_id)
	var next_index = (current_index + 1) % minigolf_turn_order.size()
	current_turn_id = minigolf_turn_order[next_index]
	
	broadcast_minigolf_state(minigolf_turn_order, current_turn_id, current_course_number)

func broadcast_minigolf_state(turn_order: Array[int], active_turn_id: int, current_course_num: int) -> void:
	if multiplayer.is_server():
		rpc("sync_minigolf_state", turn_order, active_turn_id, current_course_num)

@rpc("authority", "call_local", "reliable")
func sync_minigolf_state(turn_order: Array[int], active_turn_id: int, current_course_num: int) -> void:
	minigolf_turn_order = turn_order
	current_turn_id = active_turn_id
	current_course_number = current_course_num
	refresh_minigolf_hud()

@rpc("authority", "call_local", "reliable")
func refresh_minigolf_hud() -> void:
	if is_instance_valid(minigolf_menu):
		minigolf_menu.update_game_info(current_course_number, current_turn_id)
		minigolf_menu.update_player_grid(minigolf_turn_order, current_turn_id)

# Called on the server when all players finish the current hole
func advance_to_next_course() -> void:
	if not multiplayer.is_server():
		return
		
	# Check if all 3 courses have been completed
	if current_course_number >= 3:
		# end_minigolf_game()
		return

	# Increment course count & reset turn to the first player in order
	current_course_number += 1
	minigolf_turn_order.shuffle()
	current_turn_id = minigolf_turn_order[0]
	
	# Reset 'finished_hole' status and current strokes for the new course
	for peer_id in player_data:
		player_data[peer_id]["finished_hole"] = false
		player_data[peer_id]["current_strokes"] = 0
		if is_instance_valid(player_data[peer_id]["ball_node"]):
			player_data[peer_id]["ball_node"].queue_free()
			player_data[peer_id]["ball_node"] = null
	
	# Trigger course scene and HUD updates across all clients
	rpc("refresh_minigolf_course", minigolf_turn_order, current_turn_id, current_course_number)

@rpc("authority", "call_local", "reliable")
func refresh_minigolf_course(turn_order: Array[int], active_turn_id: int, current_course_num: int) -> void:
	minigolf_turn_order = turn_order
	current_turn_id = active_turn_id
	current_course_number = current_course_num
	
	refresh_minigolf_hud()
	#load_course(current_course_number)
