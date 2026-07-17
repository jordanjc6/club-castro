extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
var direction

@onready var monkey = $AnimatedSprite2D

@export var player_id := 1:
	set(id):
		player_id = id
		%InputSynchronizer.set_multiplayer_authority(id)

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
