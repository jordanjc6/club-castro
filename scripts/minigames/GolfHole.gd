# Hole.gd
extends Area2D

signal ball_sunk(player_id: int)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("golf_ball"):
		var ball = body as RigidBody2D
		# Only drop in if ball speed is low enough
		if ball.linear_velocity.length() < 180.0:
			ball.linear_velocity = Vector2.ZERO
			ball.hide()
			
			# Trigger turn completion logic
			#emit_signal("ball_sunk", ball.get_meta("player_id", 0))
