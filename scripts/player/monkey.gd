extends CharacterBody2D

const SPEED = 300.0
const ARRIVAL_DISTANCE = 5.0 # Distance threshold to stop moving

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


func _ready() -> void:
	add_to_group("player")
	
	# Enable the camera
	camera.make_current()
	# Detach camera rotation/position scaling from parent body movement
	camera.top_level = true
	target_position = global_position


func _unhandled_input(event: InputEvent) -> void:
	if is_movement_disabled:
		return
		
	# Handles Mouse Clicks (PC)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		set_move_target(get_global_mouse_position())
	# Handles Screen Touches (iOS/Android)
	elif event is InputEventScreenTouch and event.pressed:
		# CanvasTransform converts screen touch coordinates to world position
		var world_touch_pos = get_canvas_transform().affine_inverse() * event.position
		set_move_target(world_touch_pos)


func set_move_target(pos: Vector2) -> void:
	target_position = pos
	is_moving = true


func play_teleport_fade() -> void:
	animation_player.play("fade_to_black")
	
	# Wait for the fade out to finish before letting the screen clear
	await animation_player.animation_finished
	
	animation_player.play("fade_from_black")


func _physics_process(delta: float) -> void:
	if is_movement_disabled:
		return

	# 1. Check for keyboard / D-pad input first
	var key_direction = Input.get_vector("walk-left", "walk-right", "walk-backward", "walk-forward")

	if key_direction != Vector2.ZERO:
		# Keyboard input cancels any active point-and-click pathing
		is_moving = false
		velocity = key_direction * SPEED
		update_walk_animation(key_direction)
		move_and_slide()
	
	# 2. If no keyboard input, process point-and-click / touch movement
	elif is_moving:
		var direction = global_position.direction_to(target_position)
		var distance = global_position.distance_to(target_position)

		if distance > ARRIVAL_DISTANCE:
			velocity = direction * SPEED
			update_walk_animation(direction)
			move_and_slide()
			
			# Stop if running into a wall or collision barrier
			if get_slide_collision_count() > 0:
				stop_movement()
		else:
			stop_movement()
			
	# 3. If neither, stop movement
	else:
		stop_movement()

	update_camera_grid()


func stop_movement() -> void:
	is_moving = false
	velocity = velocity.move_toward(Vector2.ZERO, SPEED)
	monkey.stop()


func update_camera_grid() -> void:
	# 1. Calculate player position relative to the current zone's top-left corner
	var local_pos = global_position - current_grid_offset
	
	# 2. Find which local grid cell index the player is in
	var current_cell_x = floor(local_pos.x / GRID_SIZE.x)
	var current_cell_y = floor(local_pos.y / GRID_SIZE.y)
	
	# 3. Calculate the global center, adding the offset back at the end
	var target_camera_pos = Vector2(
		(current_cell_x * GRID_SIZE.x) + (GRID_SIZE.x / 2.0),
		(current_cell_y * GRID_SIZE.y) + (GRID_SIZE.y / 2.0)
	) + current_grid_offset
	
	camera.global_position = target_camera_pos


func update_zone_offset(new_offset: Vector2) -> void:
	current_grid_offset = new_offset


func update_walk_animation(dir: Vector2) -> void:
	# Convert direction vector into degrees (-180 to 180)
	# 0° = Right, 90° = Down/Front, -90° = Up/Back, 180°/-180° = Left
	var angle = rad_to_deg(dir.angle())
	
	# Straight Down (Front): 67.5° to 112.5°
	if angle >= 67.5 and angle <= 112.5:
		monkey.play("walking-front")
		monkey.flip_h = false
	# Straight Up (Back): -112.5° to -67.5°
	elif angle >= -112.5 and angle <= -67.5:
		monkey.play("walking-back")
		monkey.flip_h = false
	# Straight Right (Side): -22.5° to 22.5°
	elif angle >= -22.5 and angle <= 22.5:
		monkey.play("walking-side")
		monkey.flip_h = false
	# Straight Left (Side): Angles beyond -157.5° or 157.5°
	elif angle >= 157.5 or angle <= -157.5:
		monkey.play("walking-side")
		monkey.flip_h = true
	# Diagonal Down-Right: 22.5° to 67.5°
	elif angle > 22.5 and angle < 67.5:
		monkey.play("walking-front-diagonal")
		monkey.flip_h = false
	# Diagonal Down-Left: 112.5° to 157.5°
	elif angle > 112.5 and angle < 157.5:
		monkey.play("walking-front-diagonal")
		monkey.flip_h = true
	# Diagonal Up-Right: -67.5° to -22.5°
	elif angle > -67.5 and angle < -22.5:
		monkey.play("walking-back-diagonal")
		monkey.flip_h = false
	# Diagonal Up-Left: -157.5° to -112.5°
	elif angle > -157.5 and angle < -112.5:
		monkey.play("walking-back-diagonal")
		monkey.flip_h = true


func set_movement_disabled(disabled: bool) -> void:
	is_movement_disabled = disabled
	if disabled:
		stop_movement()
