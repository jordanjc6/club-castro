#extends CharacterBody2D
#
#const SPEED = 300.0
#const JUMP_VELOCITY = -400.0
#
#@onready var monkey = $AnimatedSprite2D
#
#func _physics_process(delta: float) -> void:
	## Add the gravity.
	#if not is_on_floor():
		#velocity += get_gravity() * delta
#
	## Handle jump.
	#if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		#velocity.y = JUMP_VELOCITY
#
	## Get the input direction and handle the movement/deceleration.
	#var direction := Input.get_axis("walk-left", "walk-right")
	#
	#if direction:
		#velocity.x = direction * SPEED
		#
		## ONLY play the walking animation if moving right (positive direction)
		#if direction > 0:
			#if monkey.animation != "walking-side":
				#monkey.play("walking-side")
		#else:
			## If moving left, you can play a left animation or fall back to idle
			#if monkey.animation != "standing-front":
				#monkey.play("standing-front")
	#else:
		#velocity.x = move_toward(velocity.x, 0, SPEED)
		## Return to idle animation when no input keys are pressed
		#if monkey.animation != "standing-front":
			#monkey.play("standing-front")
#
	#move_and_slide()
	
	
	
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
	#if direction != Vector2.ZERO:
		#velocity = direction * SPEED
	#else:
		## Smooth deceleration to a stop
		#velocity = velocity.move_toward(Vector2.ZERO, SPEED)
	#
	#if direction:
		#velocity.x = direction * SPEED
		#
		## ONLY play the walking animation if moving right (positive direction)
		#if direction > 0:
			#if monkey.animation != "walking-side":
				#monkey.flip_h = false
				#monkey.play("walking-side")
		#else:
			## If moving left, you can play a left animation or fall back to idle
			#if monkey.animation != "walking-side":
				#monkey.flip_h = true
				#monkey.play("walking-side")
	#else:
		#velocity.x = move_toward(velocity.x, 0, SPEED)
		## Return to idle animation when no input keys are pressed
		#if monkey.animation != "standing-front":
			#monkey.flip_h = false
			#monkey.play("standing-front")
			
	# Get input vector (-1 to 1 for both axes)
	var direction := Input.get_vector("walk-left", "walk_right", "walk-backward", "walk-forward")
	
	if direction != Vector2.ZERO:
		velocity = direction * SPEED
		#update_walk_animation(direction)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)
		monkey.stop()

	move_and_slide()
	
func update_walk_animation(dir: Vector2) -> void:
	# 1. Diagonal Movement (Both X and Y are active)
	if dir.x != 0 and dir.y != 0:
		monkey.play("walk_diagonal")
		# Flip horizontally depending on left/right diagonal
		monkey.flip_h = (dir.x < 0)
		# Flip vertically if your art has separate up/down diagonal frames
		monkey.flip_v = (dir.y < 0) 

	# 2. Vertical Movement Only (Forwards / Backwards)
	elif dir.y != 0:
		if dir.y > 0:
			monkey.play("walking-front")   # Moving Down
		else:
			monkey.play("walking-back")  # Moving Up
		monkey.flip_h = false             # Reset horizontal flip

	# 3. Horizontal Movement Only (Sideways)
	elif dir.x != 0:
		monkey.play("walking-side")
		# Flip the sprite to face left if moving left
		monkey.flip_h = (dir.x < 0)
