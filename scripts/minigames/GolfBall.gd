extends RigidBody2D

# Local state flag for when the ball is moving
var is_moving: bool = false
const STOP_THRESHOLD: float = 5.0 # Speed below which the ball is considered stopped

func _ready() -> void:
	add_to_group("golf_ball")

func _physics_process(_delta: float) -> void:
	if linear_velocity.length() < STOP_THRESHOLD and is_moving:
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		is_moving = false

# Call this from your aiming/shooting script on the player's turn
func stroke(force_vector: Vector2) -> void:
	apply_central_impulse(force_vector)
	is_moving = true
