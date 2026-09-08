extends CharacterBody2D
class_name MultiPlayer

const SPEED = 300.0
const ARRIVAL_DISTANCE = 5.0 # Distance threshold to stop moving

var direction: Vector2 = Vector2.ZERO # Restored for MultiplayerSynchronizer
var target_position: Vector2
var is_moving: bool = false
var is_movement_disabled: bool = false

# Define your grid size based on your game resolution (e.g., 1280x720)
const GRID_SIZE = Vector2(1280, 720)

# Tracks the top-left starting coordinate of the active world section
var current_grid_offset: Vector2 = Vector2.ZERO

@onready var monkey = $AnimatedSprite2D
@onready var camera = $Camera2D
@onready var animation_player = $ScreenFadeLayer/AnimationPlayer

@export var player_id := 1:
	set(id):
		player_id = id
		%InputSynchronizer.set_multiplayer_authority(id)


func _ready() -> void:
	target_position = global_position
	
	# Only enable the camera if this player instance belongs to the local machine
	if %InputSynchronizer.is_multiplayer_authority():
		camera.make_current()
		
		# Detach camera rotation/position scaling from parent body movement
		camera.top_level = true 
		
		# Defer camera snapping to allow global_position and zone offset to replicate
		get_tree().process_frame.connect(_init_camera_on_spawn, CONNECT_ONE_SHOT)
	else:
		camera.enabled = false


func _init_camera_on_spawn() -> void:
	update_camera_grid()


func is_local_player() -> bool:
	return is_multiplayer_authority()


func _unhandled_input(event: InputEvent) -> void:
	if is_movement_disabled or not %InputSynchronizer.is_multiplayer_authority():
		return
		
	# Handles Mouse Clicks (PC)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		request_move_target.rpc(get_global_mouse_position())
	# Handles Screen Touches (iOS/Android)
	elif event is InputEventScreenTouch and event.pressed:
		var world_touch_pos = get_canvas_transform().affine_inverse() * event.position
		request_move_target.rpc(world_touch_pos)


# RPC sends the click destination to the server (and calls it locally)
@rpc("any_peer", "call_local", "reliable")
func request_move_target(pos: Vector2) -> void:
	target_position = pos
	is_moving = true


# This RPC will only execute on the network peer that owns this specific player
@rpc("authority", "call_local", "reliable")
func play_teleport_fade() -> void:
	animation_player.play("fade_to_black")
	
	# Wait for the fade out to finish before letting the screen clear
	await animation_player.animation_finished
	
	animation_player.play("fade_from_black")


func _physics_process(delta: float) -> void:
	if is_movement_disabled:
		if multiplayer.is_server():
			velocity = Vector2.ZERO
		return

	var move_dir := Vector2.ZERO
	direction = %InputSynchronizer.input_direction # Synchronized arrow keys

	# 1. Keyboard Input Priority (Overrides active point-and-click)
	if direction != Vector2.ZERO:
		if is_moving:
			stop_movement_rpc.rpc()
		move_dir = direction
	# 2. Point-and-Click / Touch Movement
	elif is_moving:
		var distance = global_position.distance_to(target_position)
		if distance > ARRIVAL_DISTANCE:
			move_dir = global_position.direction_to(target_position)
		else:
			if multiplayer.is_server():
				stop_movement_rpc.rpc()

	# Server Physics execution
	if multiplayer.is_server():
		if move_dir != Vector2.ZERO:
			velocity = move_dir * SPEED
			move_and_slide()
			
			# If point-and-click ran into a collision barrier, cancel target
			if is_moving and direction == Vector2.ZERO and get_slide_collision_count() > 0:
				stop_movement_rpc.rpc()
		else:
			velocity = velocity.move_toward(Vector2.ZERO, SPEED)
			move_and_slide()

	# Client / Host Animation Rendering
	if not multiplayer.is_server() or MultiplayerManager.host_mode_enabled:
		if move_dir != Vector2.ZERO or velocity.length() > 10.0:
			var anim_dir = move_dir if move_dir != Vector2.ZERO else velocity.normalized()
			update_walk_animation(anim_dir)
		else:
			monkey.stop()
			
	if %InputSynchronizer.is_multiplayer_authority():
		update_camera_grid()


@rpc("any_peer", "call_local", "reliable")
func stop_movement_rpc() -> void:
	is_moving = false
	velocity = Vector2.ZERO
	if is_node_ready() and monkey:
		monkey.stop()


func update_camera_grid() -> void:
	var local_pos = global_position - current_grid_offset
	
	var current_cell_x = floor(local_pos.x / GRID_SIZE.x)
	var current_cell_y = floor(local_pos.y / GRID_SIZE.y)
	
	var target_camera_pos = Vector2(
		(current_cell_x * GRID_SIZE.x) + (GRID_SIZE.x / 2.0),
		(current_cell_y * GRID_SIZE.y) + (GRID_SIZE.y / 2.0)
	) + current_grid_offset
	
	camera.global_position = target_camera_pos


@rpc("authority", "call_local", "reliable")
func update_zone_offset(new_offset: Vector2) -> void:
	current_grid_offset = new_offset
	if %InputSynchronizer.is_multiplayer_authority():
		update_camera_grid()


func update_walk_animation(dir: Vector2) -> void:
	var angle = rad_to_deg(dir.angle())
	
	if angle >= 67.5 and angle <= 112.5:
		monkey.play("walking-front")
		monkey.flip_h = false
	elif angle >= -112.5 and angle <= -67.5:
		monkey.play("walking-back")
		monkey.flip_h = false
	elif angle >= -22.5 and angle <= 22.5:
		monkey.play("walking-side")
		monkey.flip_h = false
	elif angle >= 157.5 or angle <= -157.5:
		monkey.play("walking-side")
		monkey.flip_h = true
	elif angle > 22.5 and angle < 67.5:
		monkey.play("walking-front-diagonal")
		monkey.flip_h = false
	elif angle > 112.5 and angle < 157.5:
		monkey.play("walking-front-diagonal")
		monkey.flip_h = true
	elif angle > -67.5 and angle < -22.5:
		monkey.play("walking-back-diagonal")
		monkey.flip_h = false
	elif angle > -157.5 and angle < -112.5:
		monkey.play("walking-back-diagonal")
		monkey.flip_h = true


@rpc("any_peer", "call_local", "reliable")
func set_movement_disabled(disabled: bool) -> void:
	is_movement_disabled = disabled
	stop_movement_rpc()
