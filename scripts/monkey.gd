extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var monkey = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("walk-left", "walk-right")
	
	if direction:
		velocity.x = direction * SPEED
		
		# ONLY play the walking animation if moving right (positive direction)
		if direction > 0:
			if monkey.animation != "walking-side":
				monkey.play("walking-side")
		else:
			# If moving left, you can play a left animation or fall back to idle
			if monkey.animation != "standing-front":
				monkey.play("standing-front")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		# Return to idle animation when no input keys are pressed
		if monkey.animation != "standing-front":
			monkey.play("standing-front")

	move_and_slide()
