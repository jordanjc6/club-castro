extends Node2D

@export var golf_ball_scene: PackedScene = preload("res://scenes/minigames/minigolf/GolfBall.tscn")

@onready var minigolf_menu: PanelContainer = $"../HUD/MinigamesPopup/MinigolfMenu"
@onready var course_container: MarginContainer = $Screen/UI/HBoxContainer/Course
@onready var aim_overlay: Node2D = $Screen/AimOverlay

# Constants
const BALL_COLORS: Array[Color] = [
	Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE
]

enum BallState { PLACING, PLACED, AIMING, MOVING }

const MAX_POWER_DISTANCE: float = 200.0  # Pixels dragged for max power
const MAX_IMPULSE_FORCE: float = 800.0   # Impulse force applied to RigidBody
const ACCURACY_THRESHOLD: float = 0.5    # Inaccuracy starts above 50% power
const MAX_DEVIATION_ANGLE: float = 0.35  # Max error angle in radians (~20 deg)

# State Variables
var minigolf_turn_order: Array[int] = []
var player_data: Dictionary = {}
var current_turn_id: int
var current_course_number: int = 1
var dragged_ball_preview: Node2D = null
var current_ball_state: BallState = BallState.PLACING

# Aiming & Network Sync Parameters
var drag_start_pos: Vector2 = Vector2.ZERO
var current_drag_pos: Vector2 = Vector2.ZERO
var _last_synced_preview_pos: Vector2 = Vector2.ZERO
var _target_remote_preview_pos: Vector2 = Vector2.ZERO
var _last_synced_aim_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	print("[DEBUG] _ready() called")
	add_to_group("minigolf_controller")
	course_container.get_node("Course1").tee_button_pressed.connect(_on_tee_button_pressed)
	course_container.child_entered_tree.connect(_on_course_child_entered)

func _physics_process(_delta: float) -> void:
	# 1. 60Hz Rate-limited preview position broadcast
	if is_instance_valid(dragged_ball_preview) and dragged_ball_preview.get("is_dragging"):
		if multiplayer.get_unique_id() == current_turn_id:
			var current_pos = dragged_ball_preview.global_position
			if current_pos.distance_squared_to(_last_synced_preview_pos) > 1.0:
				_last_synced_preview_pos = current_pos
				rpc("update_drag_preview_position", current_pos)

	# 2. 60Hz Rate-limited aiming drag position broadcast
	if current_ball_state == BallState.AIMING and multiplayer.get_unique_id() == current_turn_id:
		var raw_mouse = get_viewport().get_mouse_position()
		if raw_mouse.distance_squared_to(_last_synced_aim_pos) > 1.0:
			_last_synced_aim_pos = raw_mouse
			rpc("update_aim_position", raw_mouse)

func _process(delta: float) -> void:
	# Smoothly interpolate remote preview movement
	if is_instance_valid(dragged_ball_preview) and dragged_ball_preview.get("is_dragging"):
		if multiplayer.get_unique_id() != current_turn_id:
			dragged_ball_preview.global_position = dragged_ball_preview.global_position.lerp(
				_target_remote_preview_pos, 
				delta * 25.0
			)

func _input(event: InputEvent) -> void:
	var my_id = multiplayer.get_unique_id()
	
	# --- 1. MOUSE / TOUCH PRESS ---
	var is_press = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
				or (event is InputEventScreenTouch and event.pressed)

	if is_press:
		print("\n--- [DEBUG] INPUT PRESS DETECTED ---")
		print("  -> Local Peer ID: ", my_id, " | Current Turn ID: ", current_turn_id)
		print("  -> Is My Turn?: ", my_id == current_turn_id)
		
		if my_id != current_turn_id:
			print("  -> REJECTED: Not my turn!")
			return

		var active_course = course_container.get_child(0) if course_container.get_child_count() > 0 else null
		print("  -> Active Course Found: ", is_instance_valid(active_course))
		if active_course == null:
			return

		print("  -> Player Data Has My ID (", my_id, "): ", player_data.has(my_id))
		var my_ball = player_data[my_id]["ball_node"] as RigidBody2D if player_data.has(my_id) else null
		print("  -> My Ball Node Valid: ", is_instance_valid(my_ball))
		print("  -> Current Ball State: ", current_ball_state, " (0:PLACING, 1:PLACED, 2:AIMING, 3:MOVING)")

		var input_pos = get_viewport().get_mouse_position()

		if is_instance_valid(my_ball) and current_ball_state == BallState.PLACED:
			print("  -> CONDITIONS MET! Triggering sync_aim_start at pos: ", input_pos)
			rpc("sync_aim_start", input_pos)
			return
		else:
			print("  -> PRESS IGNORED FOR AIMING: Ball node is invalid OR state is not PLACED")

	# --- 2. MOUSE / TOUCH MOTION ---
	var is_motion = (event is InputEventMouseMotion) or (event is InputEventScreenDrag)
	
	if is_motion and my_id == current_turn_id:
		var input_pos = get_viewport().get_mouse_position()
		
		# A) DRAGGING PREVIEW BALL ON TEE
		if current_ball_state == BallState.PLACING and is_instance_valid(dragged_ball_preview) and dragged_ball_preview.get("is_dragging"):
			var active_course = course_container.get_child(0) if course_container.get_child_count() > 0 else null
			if is_instance_valid(active_course):
				# Move preview ball directly to local mouse position on the course
				dragged_ball_preview.position = active_course.make_canvas_position_local(input_pos)
		
		# B) AIMING TRAJECTORY CONE
		elif current_ball_state == BallState.AIMING:
			current_drag_pos = input_pos
			print("[DEBUG] Motion Dragging | Start: ", drag_start_pos, " | Curr: ", current_drag_pos, " | Dist: ", (drag_start_pos - current_drag_pos).length())
			_refresh_aim_draw()

	# --- 3. MOUSE / TOUCH RELEASE ---
	var is_release = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
				  or (event is InputEventScreenTouch and not event.pressed)

	if is_release:
		if my_id != current_turn_id:
			return

		print("\n--- [DEBUG] INPUT RELEASE DETECTED ---")
		print("  -> Current Ball State: ", current_ball_state)

		# Drop preview ball onto Tee
		if is_instance_valid(dragged_ball_preview) and dragged_ball_preview.get("is_dragging"):
			print("  -> Dropping Drag Preview Ball...")
			dragged_ball_preview.is_dragging = false
			_check_drop_and_confirm(multiplayer.get_unique_id())
			return

		# Shoot ball if releasing during AIMING state
		var my_ball = player_data[my_id]["ball_node"] as RigidBody2D if player_data.has(my_id) else null
		if current_ball_state == BallState.AIMING and is_instance_valid(my_ball):
			print("  -> Attempting _execute_shot...")
			_execute_shot(multiplayer.get_unique_id())

# --- Triggered by transparent TeeTouchButton in Course scene ---
func _on_tee_button_pressed(touch_pos: Vector2) -> void:
	print("\n--- [DEBUG] TEE BUTTON PRESSED ---")
	print("  -> Touch Pos: ", touch_pos, " | Peer ID: ", multiplayer.get_unique_id())
	if multiplayer.get_unique_id() != current_turn_id:
		print("  -> REJECTED: Not my turn!")
		return

	var my_id = multiplayer.get_unique_id()
	if player_data.has(my_id) and player_data[my_id]["current_strokes"] > 0:
			print("  -> REJECTED: Cannot place ball after first stroke! (Strokes: %d)" % player_data[my_id]["current_strokes"])
			return
	var active_course = course_container.get_child(0) if course_container.get_child_count() > 0 else null
	if active_course == null:
		return

	# Convert screen space position into Course1's local coordinate space
	var local_pos = active_course.make_canvas_position_local(touch_pos)

	# Remove existing ball if replacing
	if player_data.has(my_id) and is_instance_valid(player_data[my_id]["ball_node"]):
		print("  -> Removing existing player ball before spawning new preview...")
		rpc("remove_player_ball", my_id)

	print("  -> Triggering sync_drag_preview_start RPC...")
	rpc("sync_drag_preview_start", my_id, local_pos)

func _check_drop_and_confirm(peer_id: int) -> void:
	print("\n--- [DEBUG] CHECK DROP AND CONFIRM ---")
	if course_container.get_child_count() == 0 or not is_instance_valid(dragged_ball_preview):
		print("  -> CANCELLED: Course missing or dragged_ball_preview invalid")
		rpc("cancel_drag_preview", peer_id)
		return

	var active_course = course_container.get_child(0)
	var ball_area: Area2D = dragged_ball_preview.get_node_or_null("GolfBallArea")
	
	var is_valid_placement = false
	if active_course.has_method("is_area_on_tee") and ball_area != null:
		is_valid_placement = active_course.is_area_on_tee(ball_area)
		print("  -> is_area_on_tee Result: ", is_valid_placement)

	# --- CHECK IF PREVIEW BALL IS TOUCHING ANOTHER BALL ---
	if is_valid_placement and dragged_ball_preview.get("is_overlapping_ball") == true:
		print("  -> Placement REJECTED: Overlapping another ball!")
		is_valid_placement = false

	if is_valid_placement:
		var final_pos = dragged_ball_preview.global_position
		print("  -> Placement VALID! Confirming ball placement at pos: ", final_pos)
		rpc("confirm_ball_placement", peer_id, final_pos)
	else:
		print("  -> Placement INVALID! Cancelling drag preview...")
		rpc("cancel_drag_preview", peer_id)

@rpc("any_peer", "call_local", "unreliable")
func sync_drag_preview_start(peer_id: int, pos: Vector2) -> void:
	print("[DEBUG] RPC sync_drag_preview_start for Peer: ", peer_id)
	if is_instance_valid(dragged_ball_preview):
		dragged_ball_preview.queue_free()

	if course_container.get_child_count() == 0:
		return
	var active_course = course_container.get_child(0)

	dragged_ball_preview = golf_ball_scene.instantiate()
	dragged_ball_preview.name = "BallPreview_%d" % peer_id
	
	# Give ownership/authority of the preview node to the player whose turn it is
	dragged_ball_preview.set_multiplayer_authority(peer_id)
	
	active_course.add_child(dragged_ball_preview, true)
	dragged_ball_preview.position = pos
	
	# Enable dragging flag locally for the active player
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
	print("[DEBUG] RPC confirm_ball_placement for Peer: ", peer_id)
	if not is_instance_valid(dragged_ball_preview):
		print("  -> ERROR: dragged_ball_preview is null during confirmation!")
		return

	dragged_ball_preview.is_dragging = false
	dragged_ball_preview.global_position = pos
	
	# Rename to permanent node name
	dragged_ball_preview.name = "GolfBall_%d" % peer_id
	print("  -> Renamed ball node to: ", dragged_ball_preview.name)

	if dragged_ball_preview.has_method("confirm_as_playable"):
		dragged_ball_preview.confirm_as_playable()
	else:
		dragged_ball_preview.freeze = false
		dragged_ball_preview.modulate.a = 1.0

	if player_data.has(peer_id):
		player_data[peer_id]["ball_node"] = dragged_ball_preview
		print("  -> Stored ball_node reference into player_data for peer: ", peer_id)
	else:
		print("  -> WARNING: player_data does NOT contain key for peer: ", peer_id)

	dragged_ball_preview = null
	current_ball_state = BallState.PLACED
	print("  -> current_ball_state updated to PLACED")

@rpc("any_peer", "call_local", "reliable")
func cancel_drag_preview(peer_id: int) -> void:
	print("[DEBUG] RPC cancel_drag_preview for Peer: ", peer_id)
	if is_instance_valid(dragged_ball_preview):
		dragged_ball_preview.queue_free()
		dragged_ball_preview = null
	current_ball_state = BallState.PLACING

@rpc("any_peer", "call_local", "reliable")
func remove_player_ball(peer_id: int) -> void:
	print("[DEBUG] RPC remove_player_ball for Peer: ", peer_id)
	if player_data.has(peer_id) and is_instance_valid(player_data[peer_id]["ball_node"]):
		player_data[peer_id]["ball_node"].queue_free()
		player_data[peer_id]["ball_node"] = null

# --- Aiming Sync & Shot Calculations ---
@rpc("any_peer", "call_local", "reliable")
func sync_aim_start(start_pos: Vector2) -> void:
	print("\n--- [DEBUG] RPC sync_aim_start EXECUTED ---")
	print("  -> Start Pos: ", start_pos)
	current_ball_state = BallState.AIMING
	drag_start_pos = start_pos
	current_drag_pos = start_pos
	_last_synced_aim_pos = start_pos
	print("  -> State set to AIMING. Calling queue_redraw()...")
	_refresh_aim_draw()

@rpc("any_peer", "call_local", "unreliable")
func update_aim_position(pos: Vector2) -> void:
	current_drag_pos = pos
	_refresh_aim_draw()

func _execute_shot(peer_id: int) -> void:
	var drag_vector = drag_start_pos - current_drag_pos
	var distance = clamp(drag_vector.length(), 0.0, MAX_POWER_DISTANCE)
	print("\n--- [DEBUG] EXECUTING SHOT ---")
	print("  -> Drag Start: ", drag_start_pos, " | Drag Current: ", current_drag_pos)
	print("  -> Computed Distance: ", distance, " / ", MAX_POWER_DISTANCE)

	if distance < 10.0:
		print("  -> CANCELLED: Drag distance too small (< 10.0 pixels)!")
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
	print("  -> Computed Impulse Vector: ", final_force_vector)
	print("  -> Triggering sync_ball_stroke RPC...")
	rpc("sync_ball_stroke", peer_id, final_force_vector)

@rpc("any_peer", "call_local", "reliable")
func sync_ball_stroke(peer_id: int, impulse: Vector2) -> void:
	print("\n--- [DEBUG] RPC sync_ball_stroke EXECUTED ---")
	print("  -> Peer ID: ", peer_id, " | Impulse Vector: ", impulse)
	current_ball_state = BallState.MOVING
	_refresh_aim_draw()

	if player_data.has(peer_id) and is_instance_valid(player_data[peer_id]["ball_node"]):
		var ball = player_data[peer_id]["ball_node"] as RigidBody2D
		print("  -> Applying force to Ball Node: ", ball.name, " (Freeze was: ", ball.freeze, ")")
		
		# Ensure physics body is awake before impulse
		ball.freeze = false
		ball.sleeping = false
		
		if ball.has_method("stroke"):
			ball.stroke(impulse)
		else:
			ball.apply_central_impulse(impulse)

		player_data[peer_id]["current_strokes"] += 1
		player_data[peer_id]["total_strokes"] += 1
		refresh_minigolf_hud()
	else:
		print("  -> ERROR: Player ball node is missing or invalid in player_data for peer: ", peer_id)

func on_ball_stopped(_ball: RigidBody2D) -> void:
	print("\n--- [DEBUG] A BALL HAS STOPPED ---")
	if not multiplayer.is_server():
		return

	# Only proceed if EVERY ball on the course has come to a stop
	if _are_all_balls_stopped():
		print("  -> All balls on the field have stopped. Advancing turn...")
		current_ball_state = BallState.PLACED
		advance_to_next_turn()
	else:
		print("  -> Other balls are still rolling from collisions. Waiting...")

# Whenever state or drag position updates:
func _refresh_aim_draw() -> void:
	if is_instance_valid(aim_overlay):
		aim_overlay.queue_redraw()

# --- Aiming Visual Cone Renderer ---
func _draw() -> void:
	if current_ball_state != BallState.AIMING or not player_data.has(current_turn_id):
		return

	var active_ball = player_data[current_turn_id]["ball_node"] as RigidBody2D
	if not is_instance_valid(active_ball):
		return

	# Force rendering above background layers and tilemaps
	z_index = 20

	# 1. Convert Ball global position to local node space
	var ball_pos = to_local(active_ball.global_position)
	
	# 2. Convert Drag screen coordinates into local node space
	var local_start = to_local(drag_start_pos)
	var local_curr = to_local(current_drag_pos)
	
	# 3. Vector pointing from drag touch point back towards drag start
	var drag_vector = local_start - local_curr
	var distance = clamp(drag_vector.length(), 0.0, MAX_POWER_DISTANCE)
	var power_percent = distance / MAX_POWER_DISTANCE

	# Require minimum drag distance before drawing to avoid static dots at rest
	if power_percent < 0.05:
		return

	# Direction vector facing opposite of pull/drag direction
	var aim_dir = drag_vector.normalized()
	var line_length = distance * 2.0
	var main_line_end = ball_pos + (aim_dir * line_length)

	# Calculate spread angle based on power threshold
	var spread_angle = 0.0
	if power_percent > ACCURACY_THRESHOLD:
		var excess_power = (power_percent - ACCURACY_THRESHOLD) / (1.0 - ACCURACY_THRESHOLD)
		spread_angle = excess_power * MAX_DEVIATION_ANGLE

	# Color shift: Green/White -> Yellow -> Red
	var line_color = Color.WHITE.lerp(Color.YELLOW, power_percent) if power_percent < ACCURACY_THRESHOLD else Color.YELLOW.lerp(Color.RED, (power_percent - ACCURACY_THRESHOLD) / 0.5)
	
	print("\n=== [DRAW INSPECTION] ===")
	print("  1. Executing Node Name: ", self.name)
	print("  2. Executing Node Path: ", get_path())
	print("  3. Canvas / Layer ID:   ", get_canvas_layer_node())
	print("  4. Node Global Pos:     ", global_position)
	print("  5. Node Local Z-Index:  ", z_index)
	print("  6. Is Canvas Relative:  ", z_as_relative)
	print("  7. Ball Global Pos:     ", active_ball.global_position)
	print("  8. Drawn 'ball_pos' (Local):   ", ball_pos)
	print("  9. Drawn 'main_line_end' (Local): ", main_line_end)
	print("  10. Drawn 'main_line_end' (Global Calculated): ", to_global(main_line_end))
	print("=========================\n")
	
	if spread_angle <= 0.001:
		# --- LOW POWER: Single Guide Line + End Circle ---
		draw_line(ball_pos, main_line_end, line_color, 4.0)
		draw_circle(main_line_end, 8.0, line_color)
	else:
		# --- HIGH POWER: Widening Accuracy Cone ---
		var left_dir = aim_dir.rotated(-spread_angle)
		var right_dir = aim_dir.rotated(spread_angle)

		var left_end = ball_pos + (left_dir * line_length)
		var right_end = ball_pos + (right_dir * line_length)

		# Outline lines
		draw_line(ball_pos, left_end, line_color, 3.0)
		draw_line(ball_pos, right_end, line_color, 3.0)
		draw_line(left_end, right_end, line_color, 2.0)

		# Translucent filled spread cone
		var cone_points = PackedVector2Array([ball_pos, left_end, right_end])
		var fill_color = Color(line_color.r, line_color.g, line_color.b, 0.25)
		draw_polygon(cone_points, PackedColorArray([fill_color, fill_color, fill_color]))
		
		# Center trajectory line
		draw_line(ball_pos, main_line_end, Color(1, 1, 1, 0.4), 1.5)

# --- Initialization & Course Handling ---
func _on_course_child_entered(node: Node) -> void:
	print("[DEBUG] Course Child Entered: ", node.name, " | Class: ", node.get_class())
	if node is RigidBody2D and player_data.has(current_turn_id):
		player_data[current_turn_id]["ball_node"] = node
		print("  -> Assigned ball_node reference via child_entered_tree")

@rpc("authority", "call_local", "reliable")
func start_minigolf(turn_order: Array[int]) -> void:
	print("[DEBUG] start_minigolf RPC called. Turn order: ", turn_order)
	if multiplayer.is_server():
		MultiplayerManager.rpc("set_minigolf_started", true)
	current_course_number = 1
	current_turn_id = turn_order[0]
	initialize_game_state(turn_order)
	refresh_minigolf_hud()

func initialize_game_state(turn_order: Array[int]) -> void:
	print("[DEBUG] Initializing Game State for players: ", turn_order)
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
		
		if course_instance.has_signal("tee_button_pressed"):
			course_instance.tee_button_pressed.connect(_on_tee_button_pressed)

func advance_to_next_turn() -> void:
	if not multiplayer.is_server():
		return
		
	var current_index = minigolf_turn_order.find(current_turn_id)
	var next_index = (current_index + 1) % minigolf_turn_order.size()
	current_turn_id = minigolf_turn_order[next_index]
	print("[DEBUG] Server advancing turn to Peer: ", current_turn_id)
	
	broadcast_minigolf_state(minigolf_turn_order, current_turn_id, current_course_number)

func broadcast_minigolf_state(turn_order: Array[int], active_turn_id: int, current_course_num: int) -> void:
	if multiplayer.is_server():
		rpc("sync_minigolf_state", turn_order, active_turn_id, current_course_num)

@rpc("authority", "call_local", "reliable")
func sync_minigolf_state(turn_order: Array[int], active_turn_id: int, current_course_num: int) -> void:
	minigolf_turn_order = turn_order
	current_turn_id = active_turn_id
	current_course_number = current_course_num
	
	# Update local ball state when turn changes
	var my_id = multiplayer.get_unique_id()
	if player_data.has(my_id) and is_instance_valid(player_data[my_id]["ball_node"]):
		current_ball_state = BallState.PLACED
		print("[DEBUG] Turn switched to me! Local ball found -> State set to PLACED")
	else:
		current_ball_state = BallState.PLACING
		print("[DEBUG] Turn switched to me! No ball on field -> State set to PLACING")

	refresh_minigolf_hud()

@rpc("authority", "call_local", "reliable")
func refresh_minigolf_hud() -> void:
	if is_instance_valid(minigolf_menu):
		minigolf_menu.update_game_info(current_course_number, current_turn_id)
		minigolf_menu.update_player_grid(minigolf_turn_order, current_turn_id, player_data)

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

func _are_all_balls_stopped() -> bool:
	for peer_id in player_data:
		var ball = player_data[peer_id].get("ball_node") as RigidBody2D
		if is_instance_valid(ball):
			# Check linear velocity magnitude and sleeping status
			if not ball.sleeping and ball.linear_velocity.length_squared() > 1.0:
				return false
	return true
