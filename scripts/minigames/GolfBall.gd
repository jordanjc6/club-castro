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
	# Only follow mouse locally if this ball is actively being dragged
	if is_dragging and is_preview:
		# If we don't own the turn, don't override global_position with local mouse!
		if not is_multiplayer_authority():
			return
		global_position = get_global_mouse_position()

func _physics_process(_delta: float) -> void:
	if linear_velocity.length() < STOP_THRESHOLD and is_moving:
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		is_moving = false
		
		var controller = get_tree().get_first_node_in_group("minigolf_controller")
		if is_instance_valid(controller) and controller.has_method("on_ball_stopped"):
			controller.on_ball_stopped(self)

func setup_as_preview() -> void:
	is_preview = true
	is_dragging = true
	freeze = true

	# Disable MultiplayerSynchronizer on previews to prevent network cache errors
	var syncer = get_node_or_null("MultiplayerSynchronizer")
	if is_instance_valid(syncer):
		syncer.public_visibility = false
		syncer.set_process(false)
		syncer.set_physics_process(false)

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
	freeze = false
	sleeping = false
	apply_central_impulse(force_vector)
	linear_velocity = force_vector / mass
	is_moving = true
