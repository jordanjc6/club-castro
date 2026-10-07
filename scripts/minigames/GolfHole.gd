extends Area2D

signal ball_sunk(ball_node: RigidBody2D)

@export var hole_radius: float = 16.0
@export var ball_radius: float = 12.0

# Dynamic speed thresholds based on overlap
@export var min_speed_threshold: float = 80.0   # Speed allowed at ~50% overlap
@export var max_speed_threshold: float = 220.0  # Speed allowed at 100% (dead-center) overlap

# Track active balls rolling over the hole
var balls_in_hole_area: Array[RigidBody2D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("golf_ball") and body is RigidBody2D:
		var ball = body as RigidBody2D
		if not balls_in_hole_area.has(ball):
			balls_in_hole_area.append(ball)

func _on_body_exited(body: Node2D) -> void:
	if body is RigidBody2D and balls_in_hole_area.has(body):
		balls_in_hole_area.erase(body)

func _physics_process(_delta: float) -> void:
	for i in range(balls_in_hole_area.size() - 1, -1, -1):
		var ball = balls_in_hole_area[i]
		
		if not is_instance_valid(ball) or ball.freeze or ball.is_preview:
			balls_in_hole_area.remove_at(i)
			continue

		_check_ball_sink_condition(ball, i)

func _check_ball_sink_condition(ball: RigidBody2D, index: int) -> void:
	var dist = global_position.distance_to(ball.global_position)
	var max_dist = hole_radius + ball_radius
	
	var overlap_pct = clamp(1.0 - (dist / max_dist), 0.0, 1.0)
	var current_speed = ball.linear_velocity.length()
	var allowed_speed = lerp(min_speed_threshold, max_speed_threshold, overlap_pct)

	if overlap_pct >= 0.50:
		if current_speed <= allowed_speed:
			print(">>> BALL SUNK! Overlap: %.1f%% | Speed: %.1f" % [overlap_pct * 100.0, current_speed])
			
			# 1. Immediately freeze physics so it stops rolling away
			ball.linear_velocity = Vector2.ZERO
			ball.angular_velocity = 0.0
			ball.freeze = true
			
			# Remove from active hole array so it doesn't trigger again
			balls_in_hole_area.remove_at(index)

			# 2. Smooth Drop-In Animation
			_animate_ball_sinking(ball)
			
			emit_signal("ball_sunk", ball)
		else:
			print("--- BALL DIDN'T SINK (Too fast): Speed: %.1f > Allowed: %.1f" % [current_speed, allowed_speed])


func _animate_ball_sinking(ball: RigidBody2D) -> void:
	var tween = create_tween().set_parallel(true)
	
	# A) Smoothly pull ball to exact center of hole over 0.25s
	tween.tween_property(ball, "global_position", global_position, 0.25)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
		
	# B) Shrink scale down to 30% to simulate falling into depth
	tween.tween_property(ball, "scale", Vector2(0.3, 0.3), 0.25)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
		
	# C) Fade out modulate opacity
	tween.tween_property(ball, "modulate:a", 0.0, 0.25)

	# D) Hide and reset transforms once animation finishes
	tween.chain().tween_callback(func():
		if is_instance_valid(ball):
			ball.hide()
			# Reset scale & modulate so it's ready for reset/respawn
			ball.scale = Vector2.ONE
			ball.modulate.a = 1.0
	)
