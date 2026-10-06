extends Node2D

@export var golf_ball_scene: PackedScene = preload("res://scenes/minigames/minigolf/GolfBall.tscn")

const BALL_COLORS: Array[Color] = [
	Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE
]

@onready var minigolf_menu: PanelContainer = $"../HUD/MinigamesPopup/MinigolfMenu"
@onready var course_container: MarginContainer = $Screen/UI/HBoxContainer/Course

var minigolf_turn_order: Array[int] = []  # Player IDs in turn order
var player_data: Dictionary = {}
var current_turn_id: int  # Active Player ID
var current_course_number: int = 1  # Course 1, 2, or 3 out of 3
var dragged_ball_preview: Node2D = null

# --- Listen for Mouse/Touch Release Anywhere on Screen ---
func _input(event: InputEvent) -> void:
	if not is_instance_valid(dragged_ball_preview):
		return

	if multiplayer.get_unique_id() != current_turn_id:
		return

	var is_release = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
				  or (event is InputEventScreenTouch and not event.pressed)

	if is_release and dragged_ball_preview.get("is_dragging"):
		dragged_ball_preview.is_dragging = false
		_check_drop_and_confirm(multiplayer.get_unique_id())

# --- Triggered by transparent TeeTouchButton in Course scene ---
func _on_tee_button_pressed(touch_pos: Vector2) -> void:
	if multiplayer.get_unique_id() != current_turn_id:
		return

	var my_id = multiplayer.get_unique_id()

	# Remove existing ball if replacing
	if is_instance_valid(player_data[my_id]["ball_node"]):
		rpc("remove_player_ball", my_id)

	_spawn_local_drag_preview(touch_pos)
	rpc("sync_drag_preview_start", my_id, touch_pos)

# --- Validate Area2D Overlap and Confirm Placement ---
func _check_drop_and_confirm(peer_id: int) -> void:
	if course_container.get_child_count() == 0 or not is_instance_valid(dragged_ball_preview):
		rpc("cancel_drag_preview", peer_id)
		return

	var active_course = course_container.get_child(0)
	var ball_area: Area2D = dragged_ball_preview.get_node_or_null("GolfBallArea")
	
	var is_valid_placement = false
	if active_course.has_method("is_area_on_tee") and ball_area != null:
		is_valid_placement = active_course.is_area_on_tee(ball_area)

	if is_valid_placement:
		var final_pos = dragged_ball_preview.global_position
		rpc("confirm_ball_placement", peer_id, final_pos)
	else:
		rpc("cancel_drag_preview", peer_id)

# --- Drag Preview Spawning & RPCs ---
func _spawn_local_drag_preview(pos: Vector2) -> void:
	if is_instance_valid(dragged_ball_preview):
		dragged_ball_preview.queue_free()

	if course_container.get_child_count() == 0:
		return
	var active_course = course_container.get_child(0)

	dragged_ball_preview = golf_ball_scene.instantiate()
	dragged_ball_preview.name = "BallPreview_%d" % multiplayer.get_unique_id()
	dragged_ball_preview.global_position = pos
	dragged_ball_preview.z_index = 10

	# !!! commenting this out causes problems
	if dragged_ball_preview.has_method("setup_as_preview"):
		dragged_ball_preview.setup_as_preview()

	var my_color = player_data[multiplayer.get_unique_id()]["color"]
	dragged_ball_preview.modulate = Color(my_color.r, my_color.g, my_color.b, 0.6)

	active_course.add_child(dragged_ball_preview, true)

@rpc("any_peer", "call_local", "unreliable")
func sync_drag_preview_start(peer_id: int, pos: Vector2) -> void:
	if peer_id == multiplayer.get_unique_id():
		return

	if is_instance_valid(dragged_ball_preview):
		dragged_ball_preview.queue_free()

	if course_container.get_child_count() == 0:
		return
	var active_course = course_container.get_child(0)

	dragged_ball_preview = golf_ball_scene.instantiate()
	dragged_ball_preview.name = "BallPreview_%d" % peer_id
	dragged_ball_preview.global_position = pos
	dragged_ball_preview.z_index = 10

	if dragged_ball_preview.has_method("setup_as_preview"):
		dragged_ball_preview.setup_as_preview()

	var p_color = player_data[peer_id]["color"]
	dragged_ball_preview.modulate = Color(p_color.r, p_color.g, p_color.b, 0.6)

	active_course.add_child(dragged_ball_preview, true)

@rpc("any_peer", "call_local", "reliable")
func confirm_ball_placement(peer_id: int, pos: Vector2) -> void:
	# !!!
	return
	if is_instance_valid(dragged_ball_preview):
		dragged_ball_preview.queue_free()
		dragged_ball_preview = null

	if multiplayer.is_server():
		confirm_ball_placement_server(peer_id, pos)

func confirm_ball_placement_server(peer_id: int, pos: Vector2) -> void:
	if not multiplayer.is_server() or course_container.get_child_count() == 0:
		return

	var active_course = course_container.get_child(0)

	var ball = golf_ball_scene.instantiate() as RigidBody2D
	ball.name = "GolfBall_%d" % peer_id
	ball.global_position = pos
	ball.modulate = player_data[peer_id]["color"]
	ball.freeze = false
	ball.z_index = 10

	active_course.add_child(ball, true)
	player_data[peer_id]["ball_node"] = ball

@rpc("any_peer", "call_local", "reliable")
func cancel_drag_preview(peer_id: int) -> void:
	if is_instance_valid(dragged_ball_preview):
		dragged_ball_preview.queue_free()
		dragged_ball_preview = null

@rpc("any_peer", "call_local", "reliable")
func remove_player_ball(peer_id: int) -> void:
	if player_data.has(peer_id) and is_instance_valid(player_data[peer_id]["ball_node"]):
		player_data[peer_id]["ball_node"].queue_free()
		player_data[peer_id]["ball_node"] = null

func _ready() -> void:
	course_container.get_node("Course1").tee_button_pressed.connect(_on_tee_button_pressed)
	course_container.child_entered_tree.connect(_on_course_child_entered)

func _on_course_child_entered(node: Node) -> void:
	if node is RigidBody2D and player_data.has(current_turn_id):
		player_data[current_turn_id]["ball_node"] = node

@rpc("authority", "call_local", "reliable")
func start_minigolf(turn_order: Array[int]) -> void:
	if multiplayer.is_server():
		MultiplayerManager.rpc("set_minigolf_started", true)
	current_course_number = 1
	current_turn_id = turn_order[0]
	initialize_game_state(turn_order)

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
	for child in course_container.get_children():
		child.queue_free()
		
	var course_path = "res://scenes/courses/Course%d.tscn" % course_num
	if ResourceLoader.exists(course_path):
		var course_scene = load(course_path) as PackedScene
		var course_instance = course_scene.instantiate()
		course_container.add_child(course_instance)

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

func advance_to_next_course() -> void:
	if not multiplayer.is_server():
		return
		
	if current_course_number >= 3:
		return

	current_course_number += 1
	minigolf_turn_order.shuffle()
	current_turn_id = minigolf_turn_order[0]
	
	for peer_id in player_data:
		player_data[peer_id]["finished_hole"] = false
		player_data[peer_id]["current_strokes"] = 0
		if is_instance_valid(player_data[peer_id]["ball_node"]):
			player_data[peer_id]["ball_node"].queue_free()
			player_data[peer_id]["ball_node"] = null
	
	rpc("refresh_minigolf_course", minigolf_turn_order, current_turn_id, current_course_number)

@rpc("authority", "call_local", "reliable")
func refresh_minigolf_course(turn_order: Array[int], active_turn_id: int, current_course_num: int) -> void:
	minigolf_turn_order = turn_order
	current_turn_id = active_turn_id
	current_course_number = current_course_num
	
	refresh_minigolf_hud()
