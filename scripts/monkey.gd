extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var monkey = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# Add the gravity.
	#if not is_on_floor():
		#velocity += get_gravity() * delta

	# Handle jump.
	#if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		#velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	#var direction := Input.get_axis("walk-left", "walk-right")
	#
	#if direction:
		#velocity.x = direction * SPEED
		#
		## ONLY play the walking animation if moving right (positive direction)
		#if direction > 0:
			#if monkey.animation != "walking-side":
				#monkey.play("walking-side")
				#monkey.flip_h = false
		#else:
			## If moving left, you can play a left animation or fall back to idle
			#if monkey.animation != "walking-side":
				#monkey.play("walking-side")
				#monkey.flip_h = true
	#else:
		#velocity.x = move_toward(velocity.x, 0, SPEED)
		## Return to idle animation when no input keys are pressed
		#if monkey.animation != "standing-front":
			#monkey.play("standing-front")
			#monkey.flip_h = false
			
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
	
