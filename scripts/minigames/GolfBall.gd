extends RigidBody2D

@onready var ball_area: Area2D = $GolfBallArea

# Local state flag for when the ball is moving
var is_preview: bool = false
var is_dragging: bool = false
var is_moving: bool = false
var is_overlapping_ball: bool = false
const STOP_THRESHOLD: float = 5.0 # Speed below which the ball is considered stopped

func _ready() -> void:
	add_to_group("golf_ball")
	if is_instance_valid(ball_area):
		ball_area.add_to_group("golf_ball_area")
		# Connect overlap signals
		ball_area.area_entered.connect(_on_area_entered)
		ball_area.area_exited.connect(_on_area_exited)
	if is_preview:
		freeze = true

func _on_area_entered(other_area: Area2D) -> void:
	# If preview touches an active ball on Layer 9
	if is_preview and other_area != ball_area and other_area.is_in_group("golf_ball_area"):
		is_overlapping_ball = true

func _on_area_exited(other_area: Area2D) -> void:
	if is_preview and other_area.is_in_group("golf_ball_area"):
		is_overlapping_ball = false

func _process(_delta: float) -> void:
	# Only follow mouse locally if this ball is actively being dragged
	if is_dragging and is_preview:
		# If we don't own the turn, don't override global_position with local mouse!
		if not is_multiplayer_authority():
			return
		global_position = get_global_mouse_position()

func _physics_process(_delta: float) -> void:
	# Ignore preview or frozen/sunk balls
	if freeze or is_preview:
		if is_moving:
			is_moving = false
		return

	var current_speed = linear_velocity.length()

	# 1. Detect if this ball was bumped/knocked by another ball
	if not is_moving and current_speed > STOP_THRESHOLD:
		is_moving = true

	# 2. When the ball slows down below threshold after moving
	if is_moving and current_speed < STOP_THRESHOLD:
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		is_moving = false
		sleeping = true
		
		var controller = get_tree().get_first_node_in_group("minigolf_controller")
		if is_instance_valid(controller) and controller.has_method("on_ball_stopped"):
			controller.on_ball_stopped(self)

func setup_as_preview() -> void:
	is_preview = true
	is_dragging = true
	freeze = true
	
	collision_layer = 0
	collision_mask = 0
	
	if is_instance_valid(ball_area):
		ball_area.monitoring = true
		ball_area.monitorable = false # Preview doesn't block others yet
		ball_area.set_collision_mask_value(9, true) # Detect active balls on Layer 9
	
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
	modulate.a = 1.0

	set_collision_layer_value(7, true)
	set_collision_mask_value(6, true)
	set_collision_mask_value(7, true)

	if is_instance_valid(ball_area):
		ball_area.monitoring = true
		ball_area.monitorable = true
		ball_area.set_collision_layer_value(9, true)
		ball_area.set_collision_mask_value(9, true)

# Call this from your aiming/shooting script on the player's turn
func stroke(force_vector: Vector2) -> void:
	freeze = false
	sleeping = false
	apply_central_impulse(force_vector)
	linear_velocity = force_vector / mass
	is_moving = true
