extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var monkey = $AnimatedSprite2D
var current_animation: String = "standing-front"

func _ready():
	if not is_multiplayer_authority():
		set_physics_process(false)

func _physics_process(delta: float) -> void:		
	var direction := Input.get_vector("walk-left", "walk-right", "walk-backward", "walk-forward")
	
	if direction != Vector2.ZERO:
		velocity = direction * SPEED
		update_walk_animation(direction)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)
		monkey.stop()

	move_and_slide()
	
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
	
