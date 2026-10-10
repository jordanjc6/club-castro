extends Node2D

@export var golf_ball_scene: PackedScene = preload("res://scenes/minigames/minigolf/GolfBall.tscn")

@onready var course_container: MarginContainer = $Screen/UI/HBoxContainer/Course
@onready var aim_overlay: Node2D = $Screen/AimOverlay
@onready var notif_popup: PanelContainer = $Screen/Notification
@onready var exit_game_button: Button = $Screen/MinigolfSidenav/MultiplayerHUD/VBoxContainer/ExitGameButton

# style constants
const COLOR_BROWN = Color("3d251e")
const COLOR_GOLD = Color("ffd700")  
const COLOR_GREEN = Color("2e7d32")
const DEFAULT_NAMETAG_COLOR = Color("0000003c")
const ROULETTE_BORDER_WIDTH = 8

# Constants
const NUM_COURSES_PER_GAME = 2
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
var player_data: Dictionary = {}
var current_turn_id = 1
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
	print("[DEBUG] _ready() called (SINGLE PLAYER MINIGAME SCRIPT!!!)")
	add_to_group("minigolf_controller")
	exit_game_button.pressed.connect(exit_game_button_pressed)
	enable_minigame_processing(false)

func enable_minigame_processing(active: bool) -> void:
	set_process(active)
	set_physics_process(active)
	set_process_input(active)
	
	if is_instance_valid(aim_overlay):
		aim_overlay.set_process(active)
		aim_overlay.set_process_input(active)

func set_minigolf_ui() -> void:
	var sidenav: Node = $"../HUD/SideNav"
	sidenav.hide()
	var single_minigolf_menu: Node = $"../HUD/SingleplayerMinigamesPopup/MinigolfMenu"
	single_minigolf_menu.hide()
	for player in get_tree().get_nodes_in_group("player"):
		player.hide()

func teleport_player_to_minigolf() -> void:
	var new_zone_offset = Vector2(0, 950)
	var target_position = Vector2(250, 1200)
	for player in get_tree().get_nodes_in_group("player"):
		player.update_zone_offset(new_zone_offset)
		player.global_position = target_position
		player.hide()

func disable_player_movement():
	for player in get_tree().get_nodes_in_group("player"):
		player.set_movement_disabled(true)

func start_singleplayer_game():
	print("start minigolf!")
	set_minigolf_ui()
	
	enable_minigame_processing(true)
	played_courses.clear()
	var first_course_id = AVAILABLE_COURSES.pick_random()
	played_courses.append(first_course_id)
	
	exit_game_button.disabled = false
	current_course_number = 1
	
	player_data.clear()
	player_data[1] = {
		"id": 1,
		"name": "You",
		"color": BALL_COLORS.pick_random(),
		"total_strokes": 0,
		"current_strokes": 0,
		"ball_node": null,
		"finished_hole": false
	}
	
	load_course(first_course_id)
	refresh_minigolf_hud(current_course_number, player_data)
	if is_instance_valid(notif_popup):
		notif_popup.hide()
	
	teleport_player_to_minigolf()
	await get_tree().create_timer(5).timeout
	disable_player_movement()

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

func refresh_minigolf_hud(current_course: int, player_info: Dictionary = {}) -> void:
	update_game_info(current_course)
	update_player_grid(player_info)

func update_game_info(course_num: int):
	var info_node = get_minigolf_game_info_node()
	if not is_instance_valid(info_node):
		return
		
	var courseLabel = info_node.get_node("CourseLabel")
	var turnLabel = info_node.get_node("TurnLabel")
	
	courseLabel.text = "Course %s/3" % course_num
	turnLabel.text = "Your turn!"

func get_minigolf_game_info_node() -> HBoxContainer:
	return get_node_or_null("Screen/UI/HBoxContainer/HUD/RotationWrapper/VBoxContainer/GameInfo")

func update_player_grid(player_data: Dictionary = {}) -> void:
	var grid_node = get_minigolf_player_grid_node()
	if not is_instance_valid(grid_node):
		return

	var label_nodes = grid_node.get_children()
	
	for i in range(label_nodes.size()):
		var label = label_nodes[i] as Label
		if not label:
			continue
			
		if i < 1:
			var peer_id = 1
			var player_name = "You"
			
			var current_strokes = 0
			var total_strokes = 0
			var p_color = Color.WHITE
			
			if player_data.has(peer_id):
				current_strokes = player_data[peer_id].get("current_strokes", 0)
				total_strokes = player_data[peer_id].get("total_strokes", 0)
				p_color = player_data[peer_id].get("color", Color.WHITE)
			
			label.text = "%d. %s: %d (%d)" % [i + 1, player_name, current_strokes, total_strokes]
			label.show()
			
			var is_turn = true
			apply_player_label_style(label, is_turn, p_color)
		else:
			label.hide()

func get_minigolf_player_grid_node() -> GridContainer:
	return get_node_or_null("Screen/UI/HBoxContainer/HUD/RotationWrapper/VBoxContainer/PlayerGrid")

func apply_player_label_style(label: Label, is_current_turn: bool = false, ball_color: Color = Color.WHITE) -> void:
	var style = StyleBoxFlat.new()
	
	if is_current_turn:
		style.bg_color = COLOR_GREEN
		style.border_color = ball_color
		style.set_border_width_all(3)
	else:
		style.bg_color = Color(0.1, 0.1, 0.1, 0.6)
		style.border_color = Color(0.3, 0.3, 0.3, 0.8)
		style.set_border_width_all(1)
	
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	
	label.add_theme_stylebox_override("normal", style)

#############################################################################################
#############################################################################################
#############################################################################################
#############################################################################################
#############################################################################################
#############################################################################################

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

func exit_game_button_pressed() -> void:
		print("[MINIGAME SERVER] Host clicked exit! Force-closing game for all players...")
		exit_game_button.disabled = true
		show_notification("Closing game...", 2.5)
		await get_tree().create_timer(2.5).timeout
		current_course_number = 999
		#announce_game_result()
		#await get_tree().create_timer(GAME_RESULT_NOTIF_TIME).timeout
		end_minigolf_game()

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

	played_courses.clear()
	player_data.clear()
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
	
	print("return to overworld ui and teleport players back")
	enable_player_movement()
	teleport_player_to_overworld()

func enable_player_movement() -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if player.has_method("set_movement_disabled"):
			player.set_movement_disabled(false)

func teleport_player_to_overworld() -> void:
	var default_zone_offset = Vector2(0, 0)
	var target_position = Vector2(647, 528)
	
	print("[SERVER] Teleporting minigolf participants back to overworld...")
	
	set_overworld_ui()
	
	for player in get_tree().get_nodes_in_group("player"):
		player.update_zone_offset(default_zone_offset)
		player.global_position = target_position
		if player.has_method("set_movement_disabled"):
			player.set_movement_disabled(false)		
		player.show()

func set_overworld_ui() -> void:
	var sidenav: Node = $"../HUD/SideNav"
	sidenav.show()
	var single_minigolf_menu: Node = $"../HUD/SingleplayerMinigamesPopup/MinigolfMenu"
	single_minigolf_menu.show()
	for player in get_tree().get_nodes_in_group("player"):
		player.show()
		
	sidenav.get_node("MultiplayerHUD/VBoxContainer/HostButton").disabled = true
	sidenav.get_node("MultiplayerHUD/VBoxContainer/JoinButton").disabled = true
	sidenav.get_node("MultiplayerHUD/VBoxContainer/MinigamesButton").disabled = false

func _physics_process(_delta: float) -> void:
	if is_instance_valid(dragged_ball_preview) and dragged_ball_preview.get("is_dragging"):
		var current_pos = dragged_ball_preview.global_position
		if current_pos.distance_squared_to(_last_synced_preview_pos) > 1.0:
			_last_synced_preview_pos = current_pos
			update_drag_preview_position(current_pos)

	if current_ball_state == BallState.AIMING:
		var raw_mouse = get_viewport().get_mouse_position()
		if raw_mouse.distance_squared_to(_last_synced_aim_pos) > 1.0:
			_last_synced_aim_pos = raw_mouse
			update_aim_position(raw_mouse)

func _input(event: InputEvent) -> void:
	var my_id = 1
	
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
		var active_course = course_container.get_child(0) if course_container.get_child_count() > 0 else null
		if active_course == null:
			return

		var raw_ball = player_data[my_id].get("ball_node") if player_data.has(my_id) else null
		var my_ball: RigidBody2D = null
		if is_instance_valid(raw_ball) and not raw_ball.is_queued_for_deletion():
			my_ball = raw_ball as RigidBody2D

		if is_instance_valid(my_ball) and current_ball_state == BallState.PLACED:
			sync_aim_start(input_pos)
			return

	# --- 2. MOUSE / TOUCH MOTION ---
	var is_motion = (event is InputEventMouseMotion) or (event is InputEventScreenDrag)
	
	if is_motion:
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
		if is_instance_valid(dragged_ball_preview) and dragged_ball_preview.get("is_dragging"):
			dragged_ball_preview.is_dragging = false
			_check_drop_and_confirm(1)
			return

		var raw_ball = player_data[my_id].get("ball_node") if player_data.has(my_id) else null
		var my_ball: RigidBody2D = null
		if is_instance_valid(raw_ball) and not raw_ball.is_queued_for_deletion():
			my_ball = raw_ball as RigidBody2D

		if current_ball_state == BallState.AIMING and is_instance_valid(my_ball):
			_execute_shot(1)

func _on_tee_button_pressed(touch_pos: Vector2) -> void:
	print("\n--- [DEBUG] TEE BUTTON PRESSED ---")
	var my_id = 1
	if player_data.has(my_id) and player_data[my_id]["current_strokes"] > 0:
		print("  -> REJECTED: Cannot place ball after taking a stroke!")
		return

	var active_course = course_container.get_child(0) if course_container.get_child_count() > 0 else null
	if active_course == null:
		return

	var local_pos = active_course.make_canvas_position_local(touch_pos)

	var raw_ball = player_data[my_id].get("ball_node") if player_data.has(my_id) else null
	if is_instance_valid(raw_ball) and not raw_ball.is_queued_for_deletion():
		remove_player_ball(my_id)

	sync_drag_preview_start(my_id, local_pos)

func _check_drop_and_confirm(peer_id: int) -> void:
	if course_container.get_child_count() == 0 or not is_instance_valid(dragged_ball_preview):
		cancel_drag_preview(peer_id)
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
		confirm_ball_placement(peer_id, final_pos)
	else:
		cancel_drag_preview(peer_id)

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
	
	if "is_dragging" in dragged_ball_preview:
		dragged_ball_preview.is_dragging = true

	_target_remote_preview_pos = dragged_ball_preview.global_position
	dragged_ball_preview.z_index = 10

	if dragged_ball_preview.has_method("setup_as_preview"):
		dragged_ball_preview.setup_as_preview()

	var p_color = player_data[peer_id]["color"] if player_data.has(peer_id) else Color.WHITE
	dragged_ball_preview.modulate = Color(p_color.r, p_color.g, p_color.b, 0.6)

	current_ball_state = BallState.PLACING

func update_drag_preview_position(pos: Vector2) -> void:
	_target_remote_preview_pos = pos

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

func cancel_drag_preview(peer_id: int) -> void:
	if is_instance_valid(dragged_ball_preview):
		dragged_ball_preview.queue_free()
		dragged_ball_preview = null
	current_ball_state = BallState.PLACING

func remove_player_ball(peer_id: int) -> void:
	if player_data.has(peer_id):
		var raw_ball = player_data[peer_id].get("ball_node")
		if is_instance_valid(raw_ball) and not raw_ball.is_queued_for_deletion():
			raw_ball.queue_free()
		player_data[peer_id]["ball_node"] = null

func sync_aim_start(start_pos: Vector2) -> void:
	current_ball_state = BallState.AIMING
	drag_start_pos = start_pos
	current_drag_pos = start_pos
	_last_synced_aim_pos = start_pos
	_refresh_aim_draw()

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
	sync_ball_stroke(peer_id, final_force_vector)

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
		refresh_minigolf_hud(current_course_number, player_data)

func _on_ball_sunk(sunk_ball: RigidBody2D) -> void:
	var owner_peer_id = 0
	for p_id in player_data:
		if player_data[p_id].get("ball_node") == sunk_ball:
			owner_peer_id = p_id
			break

	if owner_peer_id != 0:
		print("[SERVER] Ball sunk for Peer: ", owner_peer_id)
		sync_player_finished_hole(owner_peer_id)
		
		if _are_all_balls_stopped():
			print("  -> Sunk ball finished sequence and no other balls moving. Advancing turn...")
			advance_to_next_turn()

func sync_player_finished_hole(peer_id: int) -> void:
	if player_data.has(peer_id):
		player_data[peer_id]["finished_hole"] = true
		print("[DEBUG] Peer %d marked finished_hole = true" % peer_id)
	
	refresh_minigolf_hud(current_course_number, player_data)

func on_ball_stopped(_ball: RigidBody2D) -> void:
	print("\n--- [DEBUG] A BALL HAS STOPPED ---")
	if _are_all_balls_stopped():
		print("  -> All active balls have stopped. Advancing turn...")
		advance_to_next_turn()

func _refresh_aim_draw() -> void:
	if is_instance_valid(aim_overlay):
		aim_overlay.queue_redraw()

func _draw() -> void:
	if current_ball_state != BallState.AIMING:
		return

	var raw_ball = player_data[1].get("ball_node")
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

func _on_course_child_entered(node: Node) -> void:
	if node is RigidBody2D and player_data.has(1):
		player_data[1]["ball_node"] = node

func advance_to_next_turn() -> void:
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
	
	current_ball_state = BallState.PLACED
	refresh_minigolf_hud(current_course_number, player_data)

func announce_course_winner() -> void:
	var strokes = player_data[1].get("current_strokes", 0)
	var msg = "You completed the course in %d strokes!\n\n" % strokes

	if current_course_number < NUM_COURSES_PER_GAME:
		msg += "Advancing to next course.."
	else:
		exit_game_button.disabled = true
		msg += " Game over!"
	
	show_notification(msg, HOLE_WINNER_NOTIF_TIME)

func announce_game_result() -> void:
	var total_strokes = player_data[1].get("total_strokes", 0)
	var msg = "You completed the game in %d total strokes!" % total_strokes
	show_notification(msg, GAME_RESULT_NOTIF_TIME)

func advance_to_next_course() -> void:
	if current_course_number >= NUM_COURSES_PER_GAME:
		print("[SERVER] Minigolf game complete!")
		announce_game_result()
		await get_tree().create_timer(GAME_RESULT_NOTIF_TIME).timeout
		end_minigolf_game()
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
	refresh_minigolf_course(1, current_course_number, next_course_id)

func refresh_minigolf_course(active_turn_id: int, course_round_num: int, course_id_to_load: int) -> void:
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
	refresh_minigolf_hud(current_course_number, player_data)

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
