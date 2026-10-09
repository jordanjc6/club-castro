extends Node2D

@export var golf_ball_scene: PackedScene = preload("res://scenes/minigames/minigolf/GolfBall.tscn")

@onready var minigolf_menu: PanelContainer = $"../HUD/MinigamesPopup/MinigolfMenu"
@onready var course_container: MarginContainer = $Screen/UI/HBoxContainer/Course
@onready var aim_overlay: Node2D = $Screen/AimOverlay
@onready var notif_popup: PanelContainer = $Screen/Notification
@onready var exit_game_button: Button = $Screen/MinigolfSidenav/MultiplayerHUD/VBoxContainer/ExitGameButton

# Constants
const NUM_COURSES_PER_GAME = 1
const AVAILABLE_COURSES: Array[int] = [1, 2, 3]
const BALL_COLORS: Array[Color] = [
	Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE
]
const HOLE_WINNER_NOTIF_TIME = 4  # display course winner notif for 4s
const GAME_RESULT_NOTIF_TIME = 5.5

enum BallState { PLACING, PLACED, AIMING, MOVING }

const MAX_POWER_DISTANCE: float = 200.0  # Pixels dragged for max power
const MAX_IMPULSE_FORCE: float = 800.0   # Impulse force applied to RigidBody
const ACCURACY_THRESHOLD: float = 0.5    # Inaccuracy starts above 50% power
const MAX_DEVIATION_ANGLE: float = 0.35  # Max error angle in radians (~20 deg)

# State Variables
var minigolf_turn_order: Array[int] = []
var player_data: Dictionary = {}
var current_turn_id: int
var current_course_number: int = 1  # 1, 2, 3 out of 3 courses played each game
var played_courses: Array[int] = []
var dragged_ball_preview: Node2D = null
var current_ball_state: BallState = BallState.PLACING
var notif_tween: Tween = null

# Aiming & Network Sync Parameters
var drag_start_pos: Vector2 = Vector2.ZERO
var current_drag_pos: Vector2 = Vector2.ZERO
var _last_synced_preview_pos: Vector2 = Vector2.ZERO
var _target_remote_preview_pos: Vector2 = Vector2.ZERO
var _last_synced_aim_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	print("[DEBUG] _ready() called")
	add_to_group("minigolf_controller")
	exit_game_button.pressed.connect(exit_game_button_pressed)
	enable_minigame_processing(false)

# --- Voluntary Exit Button Logic ---
func exit_game_button_pressed() -> void:
	var my_id = multiplayer.get_unique_id()
	print("[MINIGAME] Manual Exit button clicked by Peer: ", my_id)
	rpc_id(1, "request_manual_exit", my_id)

@rpc("any_peer", "call_local", "reliable")
func request_manual_exit(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	print("[MINIGAME SERVER] Processing manual exit request for Peer: ", peer_id)

	# ROUTE 1: HOST LEAVES -> Terminate match completely for all players
	if peer_id == 1:
		print("[MINIGAME SERVER] Host clicked exit! Force-closing game for all players...")
		rpc("show_notification", "Host exited the match. Closing game...", 3.0)
		await get_tree().create_timer(1.0).timeout
		rpc("end_minigolf_game")
		return

	# ROUTE 2: JOINER LEAVES -> Teleport joiner back, clear state, and continue match for Host
	var player_name = player_data[peer_id].get("name", "A player") if player_data.has(peer_id) else "A player"
	rpc("show_notification", "%s left the match." % player_name, 3.0)

	rpc_id(peer_id, "confirm_local_exit")

	if is_instance_valid(minigolf_menu) and minigolf_menu.has_method("teleport_single_quitting_joiner_to_overworld"):
		minigolf_menu.teleport_single_quitting_joiner_to_overworld(peer_id)

	process_joiner_manual_exit(peer_id)

@rpc("authority", "call_local", "reliable")
func confirm_local_exit() -> void:
	print("[CLIENT] Local exit confirmed. Cleaning up local minigolf state...")

	if is_instance_valid(dragged_ball_preview):
		dragged_ball_preview.queue_free()
		dragged_ball_preview = null

	for child in course_container.get_children():
		child.queue_free()

	current_ball_state = BallState.PLACING

	if is_instance_valid(notif_popup):
		notif_popup.hide()

# --- DEDICATED JOINER MANUAL EXIT STATE CLEANUP ---
func process_joiner_manual_exit(quitting_peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	print("[MINIGAME SERVER] Executing process_joiner_manual_exit for Peer: ", quitting_peer_id)

	# 1. Clean up joiner's ball on field across network
	rpc("remove_player_ball", quitting_peer_id)
	player_data.erase(quitting_peer_id)

	# 2. Erase joiner from turn rotation
	var was_active_turn = (current_turn_id == quitting_peer_id)
	if minigolf_turn_order.has(quitting_peer_id):
		minigolf_turn_order.erase(quitting_peer_id)

	# 3. IF NO PLAYERS REMAIN: Teardown match completely
	if minigolf_turn_order.is_empty():
		rpc("end_minigolf_game")
		return

	# 4. IF JOINER WAS ACTIVE TURN: Advance turn and un-freeze input on Host/remaining client
	if was_active_turn:
		current_turn_id = minigolf_turn_order[0] # Usually Host (Peer 1)
		print("[MINIGAME SERVER] Exiting joiner was active turn owner. Advancing turn to Peer: ", current_turn_id)
		rpc("force_local_turn_unfreeze", current_turn_id)
		broadcast_minigolf_state(minigolf_turn_order, current_turn_id, current_course_number)
	else:
		broadcast_minigolf_state(minigolf_turn_order, current_turn_id, current_course_number)

@rpc("authority", "call_local", "reliable")
func force_local_turn_unfreeze(target_peer_id: int) -> void:
	var my_id = multiplayer.get_unique_id()
	if my_id == target_peer_id:
		print("[CLIENT %d] Un-freezing turn input for Host after joiner exit..." % my_id)
		current_turn_id = target_peer_id
		
		var raw_ball = player_data[my_id].get("ball_node") if player_data.has(my_id) else null
		if is_instance_valid(raw_ball) and not raw_ball.is_queued_for_deletion() and not player_data[my_id].get("finished_hole", false):
			current_ball_state = BallState.PLACED
		else:
			current_ball_state = BallState.PLACING

	refresh_minigolf_hud()
	_refresh_aim_draw()

func _physics_process(_delta: float) -> void:
	if is_instance_valid(dragged_ball_preview) and dragged_ball_preview.get("is_dragging"):
		if multiplayer.get_unique_id() == current_turn_id:
			var current_pos = dragged_ball_preview.global_position
			if current_pos.distance_squared_to(_last_synced_preview_pos) > 1.0:
				_last_synced_preview_pos = current_pos
				rpc("update_drag_preview_position", current_pos)

	if current_ball_state == BallState.AIMING and multiplayer.get_unique_id() == current_turn_id:
		var raw_mouse = get_viewport().get_mouse_position()
		if raw_mouse.distance_squared_to(_last_synced_aim_pos) > 1.0:
			_last_synced_aim_pos = raw_mouse
			rpc("update_aim_position", raw_mouse)

func _process(delta: float) -> void:
	if is_instance_valid(dragged_ball_preview) and dragged_ball_preview.get("is_dragging"):
		if multiplayer.get_unique_id() != current_turn_id:
			dragged_ball_preview.global_position = dragged_ball_preview.global_position.lerp(
				_target_remote_preview_pos, 
				delta * 25.0
			)

func _input(event: InputEvent) -> void:
	var my_id = multiplayer.get_unique_id()
	
	var input_pos = Vector2.ZERO
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		input_pos = event.position
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		input_pos = event.position
	else:
		input_pos = get_viewport().get_mouse_position()

	# --- 1. MOUSE / TOUCH PRESS ---
	var is_press = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
				or (event is InputEventScreenTouch and event.pressed)

	if is_press:
		if my_id != current_turn_id:
			return

		var active_course = course_container.get_child(0) if course_container.get_child_count() > 0 else null
		if active_course == null:
			return

		var raw_ball = player_data[my_id].get("ball_node") if player_data.has(my_id) else null
		var my_ball: RigidBody2D = null
		if is_instance_valid(raw_ball) and not raw_ball.is_queued_for_deletion():
			my_ball = raw_ball as RigidBody2D

		if is_instance_valid(my_ball) and current_ball_state == BallState.PLACED:
			rpc("sync_aim_start", input_pos)
			return

	# --- 2. MOUSE / TOUCH MOTION ---
	var is_motion = (event is InputEventMouseMotion) or (event is InputEventScreenDrag)
	
	if is_motion and my_id == current_turn_id:
		if current_ball_state == BallState.PLACING and is_instance_valid(dragged_ball_preview) and dragged_ball_preview.get("is_dragging"):
			var active_course = course_container.get_child(0) if course_container.get_child_count() > 0 else null
			if is_instance_valid(active_course):
				dragged_ball_preview.position = active_course.make_canvas_position_local(input_pos)
		
		elif current_ball_state == BallState.AIMING:
			current_drag_pos = input_pos
			_refresh_aim_draw()

	# --- 3. MOUSE / TOUCH RELEASE ---
	var is_release = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
				  or (event is InputEventScreenTouch and not event.pressed)

	if is_release:
		if my_id != current_turn_id:
			return

		if is_instance_valid(dragged_ball_preview) and dragged_ball_preview.get("is_dragging"):
			dragged_ball_preview.is_dragging = false
			_check_drop_and_confirm(multiplayer.get_unique_id())
			return

		var raw_ball = player_data[my_id].get("ball_node") if player_data.has(my_id) else null
		var my_ball: RigidBody2D = null
		if is_instance_valid(raw_ball) and not raw_ball.is_queued_for_deletion():
			my_ball = raw_ball as RigidBody2D

		if current_ball_state == BallState.AIMING and is_instance_valid(my_ball):
			_execute_shot(multiplayer.get_unique_id())

func _on_tee_button_pressed(touch_pos: Vector2) -> void:
	print("\n--- [DEBUG] TEE BUTTON PRESSED ---")
	if multiplayer.get_unique_id() != current_turn_id:
		print("  -> REJECTED: Not my turn!")
		return

	var my_id = multiplayer.get_unique_id()
	if player_data.has(my_id) and player_data[my_id]["current_strokes"] > 0:
		print("  -> REJECTED: Cannot place ball after taking a stroke!")
		return

	var active_course = course_container.get_child(0) if course_container.get_child_count() > 0 else null
	if active_course == null:
		return

	var local_pos = active_course.make_canvas_position_local(touch_pos)

	var raw_ball = player_data[my_id].get("ball_node") if player_data.has(my_id) else null
	if is_instance_valid(raw_ball) and not raw_ball.is_queued_for_deletion():
		rpc("remove_player_ball", my_id)

	rpc("sync_drag_preview_start", my_id, local_pos)

func _check_drop_and_confirm(peer_id: int) -> void:
	if course_container.get_child_count() == 0 or not is_instance_valid(dragged_ball_preview):
		rpc("cancel_drag_preview", peer_id)
		return

	var active_course = course_container.get_child(0)
	var ball_area: Area2D = dragged_ball_preview.get_node_or_null("GolfBallArea")
	
	var is_valid_placement = false
	if active_course.has_method("is_area_on_tee") and ball_area != null:
		is_valid_placement = active_course.is_area_on_tee(ball_area)

	if is_valid_placement and dragged_ball_preview.get("is_overlapping_ball") == true:
		is_valid_placement = false

	if is_valid_placement:
		var final_pos = dragged_ball_preview.global_position
		rpc("confirm_ball_placement", peer_id, final_pos)
	else:
		rpc("cancel_drag_preview", peer_id)

@rpc("any_peer", "call_local", "unreliable")
func sync_drag_preview_start(peer_id: int, pos: Vector2) -> void:
	if is_instance_valid(dragged_ball_preview):
		dragged_ball_preview.queue_free()

	if course_container.get_child_count() == 0:
		return
	var active_course = course_container.get_child(0)

	dragged_ball_preview = golf_ball_scene.instantiate()
	dragged_ball_preview.name = "BallPreview_%d" % peer_id
	dragged_ball_preview.set_multiplayer_authority(peer_id)
	
	active_course.add_child(dragged_ball_preview, true)
	dragged_ball_preview.position = pos
	
	if multiplayer.get_unique_id() == peer_id and "is_dragging" in dragged_ball_preview:
		dragged_ball_preview.is_dragging = true

	_target_remote_preview_pos = dragged_ball_preview.global_position
	dragged_ball_preview.z_index = 10

	if dragged_ball_preview.has_method("setup_as_preview"):
		dragged_ball_preview.setup_as_preview()

	var p_color = player_data[peer_id]["color"] if player_data.has(peer_id) else Color.WHITE
	dragged_ball_preview.modulate = Color(p_color.r, p_color.g, p_color.b, 0.6)

	current_ball_state = BallState.PLACING

@rpc("any_peer", "call_local", "unreliable")
func update_drag_preview_position(pos: Vector2) -> void:
	if multiplayer.get_unique_id() != current_turn_id:
		_target_remote_preview_pos = pos

@rpc("any_peer", "call_local", "reliable")
func confirm_ball_placement(peer_id: int, pos: Vector2) -> void:
	if not is_instance_valid(dragged_ball_preview):
		return

	dragged_ball_preview.is_dragging = false
	dragged_ball_preview.global_position = pos
	dragged_ball_preview.name = "GolfBall_%d" % peer_id

	if dragged_ball_preview.has_method("confirm_as_playable"):
		dragged_ball_preview.confirm_as_playable()
	else:
		dragged_ball_preview.freeze = false
		dragged_ball_preview.modulate.a = 1.0

	if player_data.has(peer_id):
		player_data[peer_id]["ball_node"] = dragged_ball_preview

	dragged_ball_preview = null
	current_ball_state = BallState.PLACED

@rpc("any_peer", "call_local", "reliable")
func cancel_drag_preview(peer_id: int) -> void:
	if is_instance_valid(dragged_ball_preview):
		dragged_ball_preview.queue_free()
		dragged_ball_preview = null
	current_ball_state = BallState.PLACING

@rpc("any_peer", "call_local", "reliable")
func remove_player_ball(peer_id: int) -> void:
	if player_data.has(peer_id):
		var raw_ball = player_data[peer_id].get("ball_node")
		if is_instance_valid(raw_ball) and not raw_ball.is_queued_for_deletion():
			raw_ball.queue_free()
		player_data[peer_id]["ball_node"] = null

# --- Aiming Sync & Shot Calculations ---
@rpc("any_peer", "call_local", "reliable")
func sync_aim_start(start_pos: Vector2) -> void:
	current_ball_state = BallState.AIMING
	drag_start_pos = start_pos
	current_drag_pos = start_pos
	_last_synced_aim_pos = start_pos
	_refresh_aim_draw()

@rpc("any_peer", "call_local", "unreliable")
func update_aim_position(pos: Vector2) -> void:
	current_drag_pos = pos
	_refresh_aim_draw()

func _execute_shot(peer_id: int) -> void:
	var drag_vector = drag_start_pos - current_drag_pos
	var distance = clamp(drag_vector.length(), 0.0, MAX_POWER_DISTANCE)

	if distance < 10.0:
		current_ball_state = BallState.PLACED
		_refresh_aim_draw()
		return

	var power_percent = distance / MAX_POWER_DISTANCE
	var stroke_dir = drag_vector.normalized()

	if power_percent > ACCURACY_THRESHOLD:
		var excess_power = (power_percent - ACCURACY_THRESHOLD) / (1.0 - ACCURACY_THRESHOLD)
		var spread_angle = excess_power * MAX_DEVIATION_ANGLE
		var random_error_angle = randf_range(-spread_angle, spread_angle)
		stroke_dir = stroke_dir.rotated(random_error_angle)

	var final_force_vector = stroke_dir * (power_percent * MAX_IMPULSE_FORCE)
	rpc("sync_ball_stroke", peer_id, final_force_vector)

@rpc("any_peer", "call_local", "reliable")
func sync_ball_stroke(peer_id: int, impulse: Vector2) -> void:
	current_ball_state = BallState.MOVING
	_refresh_aim_draw()

	if player_data.has(peer_id):
		var raw_ball = player_data[peer_id].get("ball_node")
		if is_instance_valid(raw_ball) and not raw_ball.is_queued_for_deletion():
			var ball = raw_ball as RigidBody2D
			if is_instance_valid(ball):
				ball.freeze = false
				ball.sleeping = false
				
				if ball.has_method("stroke"):
					ball.stroke(impulse)
				else:
					ball.apply_central_impulse(impulse)

		player_data[peer_id]["current_strokes"] += 1
		player_data[peer_id]["total_strokes"] += 1
		refresh_minigolf_hud()

# --- Hole Sinking Logic ---
func _on_ball_sunk(sunk_ball: RigidBody2D) -> void:
	if not multiplayer.is_server():
		return

	var owner_peer_id = 0
	for p_id in player_data:
		if player_data[p_id].get("ball_node") == sunk_ball:
			owner_peer_id = p_id
			break

	if owner_peer_id != 0:
		print("[SERVER] Ball sunk for Peer: ", owner_peer_id)
		rpc("sync_player_finished_hole", owner_peer_id)
		
		if _are_all_balls_stopped():
			print("  -> Sunk ball finished sequence and no other balls moving. Advancing turn...")
			advance_to_next_turn()

@rpc("authority", "call_local", "reliable")
func sync_player_finished_hole(peer_id: int) -> void:
	if player_data.has(peer_id):
		player_data[peer_id]["finished_hole"] = true
		print("[DEBUG] Peer %d marked finished_hole = true" % peer_id)
	
	refresh_minigolf_hud()

func on_ball_stopped(_ball: RigidBody2D) -> void:
	print("\n--- [DEBUG] A BALL HAS STOPPED ---")
	if not multiplayer.is_server():
		return

	if _are_all_balls_stopped():
		print("  -> All active balls have stopped. Advancing turn...")
		advance_to_next_turn()

func _refresh_aim_draw() -> void:
	if is_instance_valid(aim_overlay):
		aim_overlay.queue_redraw()

# --- Aiming Visual Cone Renderer ---
func _draw() -> void:
	if current_ball_state != BallState.AIMING or not player_data.has(current_turn_id):
		return

	var raw_ball = player_data[current_turn_id].get("ball_node")
	if not is_instance_valid(raw_ball) or raw_ball.is_queued_for_deletion():
		return

	var active_ball = raw_ball as RigidBody2D
	if not is_instance_valid(active_ball):
		return

	z_index = 20

	var ball_pos = to_local(active_ball.global_position)
	var local_start = to_local(drag_start_pos)
	var local_curr = to_local(current_drag_pos)
	
	var drag_vector = local_start - local_curr
	var distance = clamp(drag_vector.length(), 0.0, MAX_POWER_DISTANCE)
	var power_percent = distance / MAX_POWER_DISTANCE

	if power_percent < 0.05:
		return

	var aim_dir = drag_vector.normalized()
	var line_length = distance * 2.0
	var main_line_end = ball_pos + (aim_dir * line_length)

	var spread_angle = 0.0
	if power_percent > ACCURACY_THRESHOLD:
		var excess_power = (power_percent - ACCURACY_THRESHOLD) / (1.0 - ACCURACY_THRESHOLD)
		spread_angle = excess_power * MAX_DEVIATION_ANGLE

	var line_color = Color.WHITE.lerp(Color.YELLOW, power_percent) if power_percent < ACCURACY_THRESHOLD else Color.YELLOW.lerp(Color.RED, (power_percent - ACCURACY_THRESHOLD) / 0.5)
	
	if spread_angle <= 0.001:
		draw_line(ball_pos, main_line_end, line_color, 4.0)
		draw_circle(main_line_end, 8.0, line_color)
	else:
		var left_dir = aim_dir.rotated(-spread_angle)
		var right_dir = aim_dir.rotated(spread_angle)

		var left_end = ball_pos + (left_dir * line_length)
		var right_end = ball_pos + (right_dir * line_length)

		draw_line(ball_pos, left_end, line_color, 3.0)
		draw_line(ball_pos, right_end, line_color, 3.0)
		draw_line(left_end, right_end, line_color, 2.0)

		var cone_points = PackedVector2Array([ball_pos, left_end, right_end])
		var fill_color = Color(line_color.r, line_color.g, line_color.b, 0.25)
		draw_polygon(cone_points, PackedColorArray([fill_color, fill_color, fill_color]))
		
		draw_line(ball_pos, main_line_end, Color(1, 1, 1, 0.4), 1.5)

# --- Initialization & Course Handling ---
func _on_course_child_entered(node: Node) -> void:
	if node is RigidBody2D and player_data.has(current_turn_id):
		player_data[current_turn_id]["ball_node"] = node

@rpc("authority", "call_local", "reliable")
func start_minigolf(turn_order: Array[int]) -> void:
	if multiplayer.is_server():
		MultiplayerManager.rpc("set_minigolf_started", true)
		
		played_courses.clear()
		var first_course_id = AVAILABLE_COURSES.pick_random()
		played_courses.append(first_course_id)
		
		enable_minigame_processing(true)
		rpc("sync_game_start", turn_order, first_course_id)

@rpc("authority", "call_local", "reliable")
func sync_game_start(turn_order: Array[int], starting_course_id: int) -> void:
	current_course_number = 1
	current_turn_id = turn_order[0]
	initialize_game_state(turn_order)
	load_course(starting_course_id)
	refresh_minigolf_hud()
	if is_instance_valid(notif_popup):
		notif_popup.hide()
	enable_minigame_processing(true)

# Call this in sync_game_start / start_minigolf:
func enable_minigame_processing(active: bool) -> void:
	set_process(active)
	set_physics_process(active)
	set_process_input(active)
	
	if is_instance_valid(aim_overlay):
		aim_overlay.set_process(active)
		aim_overlay.set_process_input(active)

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
		
	var course_path = "res://scenes/minigames/minigolf/courses/Course%d.tscn" % course_num
	if ResourceLoader.exists(course_path):
		var course_scene = load(course_path) as PackedScene
		var course_instance = course_scene.instantiate()
		course_container.add_child(course_instance)
		
		if course_instance.has_signal("tee_button_pressed"):
			course_instance.tee_button_pressed.connect(_on_tee_button_pressed)

		var hole_node = course_instance.find_child("GolfHole", true, false)
		if is_instance_valid(hole_node) and hole_node.has_signal("ball_sunk"):
			hole_node.ball_sunk.connect(_on_ball_sunk)

func advance_to_next_turn() -> void:
	if not multiplayer.is_server():
		return

	if minigolf_turn_order.is_empty():
		print("[SERVER] Turn order is empty. Ending match...")
		rpc("end_minigolf_game")
		return

	# 1. Check if ALL remaining players have finished the hole
	var all_finished = true
	for p_id in player_data:
		if not player_data[p_id].get("finished_hole", false):
			all_finished = false
			break

	if all_finished:
		print("[SERVER] All players finished hole! Advancing course...")
		announce_course_winner()
		await get_tree().create_timer(HOLE_WINNER_NOTIF_TIME).timeout
		advance_to_next_course()
		return

	# 2. Find next player who HAS NOT finished the hole
	var current_index = minigolf_turn_order.find(current_turn_id)
	if current_index == -1:
		current_index = 0

	var next_id = current_turn_id

	for i in range(1, minigolf_turn_order.size() + 1):
		var check_index = (current_index + i) % minigolf_turn_order.size()
		var candidate_id = minigolf_turn_order[check_index]
		
		if not player_data[candidate_id].get("finished_hole", false):
			next_id = candidate_id
			break

	current_turn_id = next_id
	print("[DEBUG] Server advancing turn to Peer: ", current_turn_id)

	broadcast_minigolf_state(minigolf_turn_order, current_turn_id, current_course_number)

	# FOR SINGLE PLAYER SURVIVAL: Force turn un-freeze if only 1 player remains
	if minigolf_turn_order.size() == 1:
		var solo_id = minigolf_turn_order[0]
		rpc_id(solo_id, "force_local_turn_unfreeze", solo_id)

func announce_course_winner() -> void:
	if not multiplayer.is_server():
		return
	
	var lowest_strokes: int = 999
	var winners: Array[String] = []

	for p_id in player_data:
		var strokes = player_data[p_id].get("current_strokes", 0)
		var p_name = player_data[p_id].get("name", "Player")

		if strokes < lowest_strokes:
			lowest_strokes = strokes
			winners.clear()
			winners.append(p_name)
		elif strokes == lowest_strokes:
			winners.append(p_name)

	var winner_msg = ""
	if winners.size() == 1:
		winner_msg = "%s won the hole in %d strokes!" % [winners[0], lowest_strokes]
	else:
		winner_msg = "Tie for the hole! (%s) with %d strokes!" % [", ".join(winners), lowest_strokes]
	
	if current_course_number < NUM_COURSES_PER_GAME:
		winner_msg += " Advancing to next course.."
	else:
		winner_msg += " Game over!"
	
	rpc("show_notification", winner_msg, HOLE_WINNER_NOTIF_TIME)

func announce_game_result() -> void:
	if not multiplayer.is_server():
		return
	
	var sorted_players: Array = []
	for p_id in player_data:
		sorted_players.append(player_data[p_id])

	sorted_players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("total_strokes", 0) < b.get("total_strokes", 0)
	)

	var lowest_strokes: int = sorted_players[0].get("total_strokes", 0) if not sorted_players.is_empty() else 0
	var winners: Array[String] = []

	for player in sorted_players:
		if player.get("total_strokes", 0) == lowest_strokes:
			winners.append(player.get("name", "Player"))
		else:
			break

	var winner_msg = ""
	if winners.size() == 1:
		winner_msg = "%s won the game in %d total strokes!" % [winners[0], lowest_strokes]
	else:
		winner_msg = "The game ends in a tie! (%s) with %d total strokes!" % [", ".join(winners), lowest_strokes]

	var lines: Array[String] = [winner_msg, ""]
	var current_rank: int = 1

	for i in range(sorted_players.size()):
		var player = sorted_players[i]
		
		if i > 0 and player.get("total_strokes", 0) > sorted_players[i - 1].get("total_strokes", 0):
			current_rank = i + 1

		var line = "%d. %s (%d)" % [
			current_rank, 
			player.get("name", "Player"), 
			player.get("total_strokes", 0)
		]
		lines.append(line)

	var final_msg: String = "\n".join(lines)
	rpc("show_notification", final_msg, GAME_RESULT_NOTIF_TIME)

@rpc("authority", "call_local", "reliable")
func show_notification(message: String, time: float) -> void:
	if not is_instance_valid(notif_popup):
		return

	var label = notif_popup.get_node_or_null("MarginContainer/Label")
	if label:
		label.text = message
	notif_popup.show()

	if notif_tween and notif_tween.is_running():
		notif_tween.kill()

	notif_tween = create_tween()
	notif_tween.tween_interval(time)
	notif_tween.tween_callback(notif_popup.hide)

func broadcast_minigolf_state(turn_order: Array[int], active_turn_id: int, current_course_num: int) -> void:
	if multiplayer.is_server():
		rpc("sync_minigolf_state", turn_order, active_turn_id, current_course_num)

@rpc("authority", "call_local", "reliable")
func sync_minigolf_state(turn_order: Array[int], active_turn_id: int, current_course_num: int) -> void:
	minigolf_turn_order = turn_order
	current_turn_id = active_turn_id
	current_course_number = current_course_num
	
	var my_id = multiplayer.get_unique_id()
	
	if current_turn_id == my_id:
		var raw_ball = player_data[my_id].get("ball_node") if player_data.has(my_id) else null
		if is_instance_valid(raw_ball) and not raw_ball.is_queued_for_deletion() and not player_data[my_id].get("finished_hole", false):
			current_ball_state = BallState.PLACED
		else:
			current_ball_state = BallState.PLACING

	refresh_minigolf_hud()
	_refresh_aim_draw()

@rpc("authority", "call_local", "reliable")
func refresh_minigolf_hud() -> void:
	if is_instance_valid(minigolf_menu):
		minigolf_menu.update_game_info(current_course_number, current_turn_id)
		minigolf_menu.update_player_grid(minigolf_turn_order, current_turn_id, player_data)

func advance_to_next_course() -> void:
	if not multiplayer.is_server():
		return
		
	if minigolf_turn_order.is_empty():
		rpc("end_minigolf_game")
		return

	if current_course_number >= NUM_COURSES_PER_GAME:
		print("[SERVER] Minigolf game complete!")
		announce_game_result()
		await get_tree().create_timer(GAME_RESULT_NOTIF_TIME).timeout
		rpc("end_minigolf_game")
		return

	var unplayed_courses: Array[int] = []
	for course_id in AVAILABLE_COURSES:
		if not played_courses.has(course_id):
			unplayed_courses.append(course_id)

	var next_course_id: int = 1
	if not unplayed_courses.is_empty():
		next_course_id = unplayed_courses.pick_random()
	else:
		next_course_id = AVAILABLE_COURSES.pick_random()

	played_courses.append(next_course_id)
	current_course_number += 1
	
	minigolf_turn_order.shuffle()
	if not minigolf_turn_order.is_empty():
		current_turn_id = minigolf_turn_order[0]
	
	rpc("refresh_minigolf_course", minigolf_turn_order, current_turn_id, current_course_number, next_course_id)

@rpc("authority", "call_local", "reliable")
func refresh_minigolf_course(turn_order: Array[int], active_turn_id: int, course_round_num: int, course_id_to_load: int) -> void:
	minigolf_turn_order = turn_order
	current_turn_id = active_turn_id
	current_course_number = course_round_num
	
	for peer_id in player_data:
		player_data[peer_id]["finished_hole"] = false
		player_data[peer_id]["current_strokes"] = 0
		var raw_ball = player_data[peer_id].get("ball_node")
		if is_instance_valid(raw_ball) and not raw_ball.is_queued_for_deletion():
			raw_ball.queue_free()
		player_data[peer_id]["ball_node"] = null
	
	load_course(course_id_to_load)
	current_ball_state = BallState.PLACING
	refresh_minigolf_hud()

func _are_all_balls_stopped() -> bool:
	for peer_id in player_data:
		if player_data[peer_id].get("finished_hole", false):
			continue

		var raw_ball = player_data[peer_id].get("ball_node")
		if is_instance_valid(raw_ball) and not raw_ball.is_queued_for_deletion():
			var ball = raw_ball as RigidBody2D
			if is_instance_valid(ball) and not ball.sleeping and ball.linear_velocity.length_squared() > 1.0:
				return false
	return true

# --- UNTOUCHED NETWORK DISCONNECT HANDLER ---
func handle_midgame_player_disconnect(disconnected_peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	print("[MINIGAME SERVER] Handling network disconnect for Peer: ", disconnected_peer_id)

	if player_data.has(disconnected_peer_id):
		var raw_ball = player_data[disconnected_peer_id].get("ball_node")
		if is_instance_valid(raw_ball) and not raw_ball.is_queued_for_deletion():
			raw_ball.queue_free()
		player_data.erase(disconnected_peer_id)

	if minigolf_turn_order.has(disconnected_peer_id):
		minigolf_turn_order.erase(disconnected_peer_id)

	if minigolf_turn_order.is_empty():
		print("[MINIGAME SERVER] No active players left in minigolf! Force ending match...")
		rpc("end_minigolf_game")
		return

	if current_turn_id == disconnected_peer_id:
		print("[MINIGAME SERVER] Disconnected player was active turn owner. Advancing turn...")
		advance_to_next_turn()
	else:
		broadcast_minigolf_state(minigolf_turn_order, current_turn_id, current_course_number)

@rpc("authority", "call_local", "reliable")
func end_minigolf_game() -> void:
	print("[DEBUG] Teardown: Resetting Minigolf state variables...")
	enable_minigame_processing(false)
	
	if is_instance_valid(dragged_ball_preview):
		dragged_ball_preview.queue_free()
		dragged_ball_preview = null

	for peer_id in player_data:
		var raw_ball = player_data[peer_id].get("ball_node")
		if is_instance_valid(raw_ball) and not raw_ball.is_queued_for_deletion():
			raw_ball.queue_free()

	var active_participants: Array[int] = minigolf_turn_order.duplicate()

	played_courses.clear()
	minigolf_turn_order.clear()
	player_data.clear()
	current_turn_id = 0
	current_course_number = 1
	current_ball_state = BallState.PLACING

	drag_start_pos = Vector2.ZERO
	current_drag_pos = Vector2.ZERO
	_last_synced_preview_pos = Vector2.ZERO
	_target_remote_preview_pos = Vector2.ZERO
	_last_synced_aim_pos = Vector2.ZERO

	for child in course_container.get_children():
		child.queue_free()

	_refresh_aim_draw()

	if multiplayer.is_server():
		MultiplayerManager.rpc("set_minigolf_started", false)
	
	print("return to overworld ui and teleport players back")
	if is_instance_valid(minigolf_menu) and minigolf_menu.has_method("on_minigolf_game_ended"):
		minigolf_menu.on_minigolf_game_ended(active_participants)
