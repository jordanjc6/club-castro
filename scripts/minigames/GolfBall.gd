extends RigidBody2D

@onready var ball_area: Area2D = $GolfBallArea

# Local state flag for when the ball is moving
var is_preview: bool = false
var is_dragging: bool = false
var is_moving: bool = false
const STOP_THRESHOLD: float = 5.0 # Speed below which the ball is considered stopped

func _ready() -> void:
	add_to_group("golf_ball")
	if is_preview:
		freeze = true

func _process(_delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position()

func _physics_process(_delta: float) -> void:
	if linear_velocity.length() < STOP_THRESHOLD and is_moving:
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		is_moving = false

func setup_as_preview() -> void:
	is_preview = true
	is_dragging = true
	freeze = true

func confirm_as_playable() -> void:
	is_preview = false
	is_dragging = false
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = false
	sleeping = false
	modulate.a = 1.0 # Restore full opacity (preview was 0.6)

# Call this from your aiming/shooting script on the player's turn
func stroke(force_vector: Vector2) -> void:
	apply_central_impulse(force_vector)
	is_moving = true
