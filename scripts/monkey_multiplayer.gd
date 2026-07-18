extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
var direction

@onready var monkey = $AnimatedSprite2D
@onready var camera = $Camera2D

@export var player_id := 1:
	set(id):
		player_id = id
		%InputSynchronizer.set_multiplayer_authority(id)

# Define your grid size based on your game resolution (e.g., 1152x648 or 1920x1080)
const GRID_SIZE = Vector2(1280, 720)
#const GRID_SIZE = Vector2(800, 500)


func _ready() -> void:
	# Only enable the camera if this player instance belongs to the local machine
	if %InputSynchronizer.is_multiplayer_authority():
		camera.make_current()
		# Detach camera rotation/position scaling from parent body movement
		camera.top_level = true 
	else:
		camera.enabled = false

func _physics_process(delta: float) -> void:
	direction = %InputSynchronizer.input_direction
	if (multiplayer.is_server()):
		if direction != Vector2.ZERO:
			velocity = direction * SPEED
			#update_walk_animation(direction)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, SPEED)
			#monkey.stop()

		move_and_slide()
	
	if (not multiplayer.is_server() || MultiplayerManager.host_mode_enabled):
		if direction != Vector2.ZERO:
			update_walk_animation(direction)
		else:
			monkey.stop()
			
	# Update the camera position locally for each client controlling their player
	if %InputSynchronizer.is_multiplayer_authority():
		update_camera_grid()

func update_camera_grid() -> void:
	# 1. Find which grid cell index the player is currently in
	var current_cell_x = floor(global_position.x / GRID_SIZE.x)
	var current_cell_y = floor(global_position.y / GRID_SIZE.y)
	
	# 2. Calculate the global center coordinate of that specific grid cell
	var target_camera_pos = Vector2(
		(current_cell_x * GRID_SIZE.x) + (GRID_SIZE.x / 2.0),
		(current_cell_y * GRID_SIZE.y) + (GRID_SIZE.y / 2.0)
	)
	
	# 3. Position the camera at the center of the active screen cell
	camera.global_position = target_camera_pos

func update_walk_animation(dir: Vector2) -> void:
	# diagonal up-right
	if dir.x > 0 and dir.y > 0:
		monkey.play("walking-front-diagonal")
		monkey.flip_h = false
	# diagonal down-right
	elif dir.x > 0 and dir.y < 0:
		monkey.play("walking-back-diagonal")
		monkey.flip_h = false
	# diagonal up-left
	elif dir.x < 0 and dir.y > 0:
		monkey.play("walking-front-diagonal")
		monkey.flip_h = true
	# diagonal down-left
	elif dir.x < 0 and dir.y < 0:
		monkey.play("walking-back-diagonal")
		monkey.flip_h = true
	# only vertical
	elif dir.y != 0:
		if dir.y > 0:
			monkey.play("walking-front")
		else:
			monkey.play("walking-back")
		monkey.flip_h = false
	# only horizontal
	elif dir.x != 0:
		monkey.play("walking-side")
		monkey.flip_h = (dir.x < 0)
