extends RigidBody2D

@onready var ball_area: Area2D = $GolfBallArea

# constants
const STOP_THRESHOLD: float = 5.0 # Speed below which the ball is considered stopped
const NORMAL_DAMP: float = 1.3
const SAND_DAMP: float = 8.0
const ICE_DAMP: float = 0.2
const ARROW_PUSH_STRENGTH: float = 200

# Local state flag for when the ball is moving
var is_preview: bool = false
var is_dragging: bool = false
var is_moving: bool = false
var is_overlapping_ball: bool = false
var is_blackholed: bool = false
var is_watered: bool = false

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
	
	# --- TILE SURFACE & BLACKHOLE CHECK ---
	var course_node = get_parent()
	if is_instance_valid(course_node):
		var tile_map = course_node.find_child("TileMapLayer", true, false)
		if is_instance_valid(tile_map):
			
			# Check surface type for friction (Sand vs Normal)
			var center_local = tile_map.to_local(global_position)
			var center_map = tile_map.local_to_map(center_local)
			var center_tile_data = tile_map.get_cell_tile_data(center_map)
			
			if center_tile_data:
				var surface = center_tile_data.get_custom_data("surface_type")
				match surface:
					"sand":
						linear_damp = SAND_DAMP
					"ice":
						linear_damp = ICE_DAMP
					"arrow-right":
						linear_damp = NORMAL_DAMP
						apply_central_force(Vector2.RIGHT * ARROW_PUSH_STRENGTH)
					"arrow-left":
						linear_damp = NORMAL_DAMP
						apply_central_force(Vector2.LEFT * ARROW_PUSH_STRENGTH)
					"arrow-up":
						linear_damp = NORMAL_DAMP
						apply_central_force(Vector2.UP * ARROW_PUSH_STRENGTH)
					"arrow-down":
						linear_damp = NORMAL_DAMP
						apply_central_force(Vector2.DOWN * ARROW_PUSH_STRENGTH)
					_:
						linear_damp = NORMAL_DAMP
			else:
				linear_damp = NORMAL_DAMP

			# Check 5 points around the ball to see if >= 50% is on a hazard tile (Water or Blackhole)
			if is_multiplayer_authority():
				var ball_radius = 12.0 # Adjust this to match your ball's actual pixel radius
				var sample_points = [
					global_position,                               # Center
					global_position + Vector2(ball_radius, 0),     # Right
					global_position + Vector2(-ball_radius, 0),    # Left
					global_position + Vector2(0, ball_radius),     # Down
					global_position + Vector2(0, -ball_radius)     # Up
				]
				
				var water_points_hit = 0
				var blackhole_points_hit = 0
				for pt in sample_points:
					var local_pt = tile_map.to_local(pt)
					var map_pt = tile_map.local_to_map(local_pt)
					var tile_data = tile_map.get_cell_tile_data(map_pt)
					if tile_data:
						var surf = tile_data.get_custom_data("surface_type")
						if surf == "water":
							water_points_hit += 1
						elif surf == "blackhole":
							blackhole_points_hit += 1
				
				# If 3 or more points hit (>= 60%, satisfying >= 50% overlap)
				if water_points_hit >= 3:
					is_watered = true
					_trigger_water()
					return
				elif blackhole_points_hit >= 3:
					is_blackholed = true
					_trigger_blackhole()
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

func _trigger_blackhole() -> void:
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	
	var controller = get_tree().get_first_node_in_group("minigolf_controller")
	if is_instance_valid(controller):
		# Find which peer owns this ball and call the server handler
		for p_id in controller.player_data:
			if controller.player_data[p_id].get("ball_node") == self:
				if multiplayer.is_server():
					controller.handle_ball_blackholed(p_id)
				else:
					controller.rpc_id(1, "handle_ball_blackholed", p_id)
				break

func _trigger_water() -> void:
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	
	var controller = get_tree().get_first_node_in_group("minigolf_controller")
	if is_instance_valid(controller):
		# Find which peer owns this ball and call the server handler
		for p_id in controller.player_data:
			if controller.player_data[p_id].get("ball_node") == self:
				if multiplayer.is_server():
					controller.handle_ball_watered(p_id)
				else:
					controller.rpc_id(1, "handle_ball_watered", p_id)
				break
