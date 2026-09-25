extends CharacterBody2D
class_name MultiPlayer

const SPEED = 300.0
const ARRIVAL_DISTANCE = 5.0 # Distance threshold to stop moving

var direction: Vector2 = Vector2.ZERO # Restored for MultiplayerSynchronizer
var target_position: Vector2
var is_moving: bool = false
var is_movement_disabled: bool = false

# Define your grid size based on your game resolution (e.g., 1280x720)
const GRID_SIZE = Vector2(1280, 720)

# Tracks the top-left starting coordinate of the active world section
var current_grid_offset: Vector2 = Vector2.ZERO

@onready var monkey = $AnimatedSprite2D
@onready var camera = $Camera2D
@onready var animation_player = $ScreenFadeLayer/AnimationPlayer
@onready var name_label: Label = $Label

# tag minigame ###########################################
##########################################################

# Example indicator Sprite2D or Label child node reference
@onready var tag_indicator: Sprite2D = $TagIndicator # Adjust path to your indicator node
@onready var tag_indicator_outline: Sprite2D = $TagIndicatorOutline # Adjust path to your indicator node
const COLOR_GOLD = Color("ffd700")  
@onready var tag_area: Area2D = $TagArea

##########################################################

# fishing ###################
#############################
@onready var rod_sprite: Sprite2D = $FishingRod
@onready var cast_lure_button: Button = $CastLureButton
@onready var fishing_detector: Area2D = $FishingAreaCollider
var is_rod_equipped: bool = false
var is_at_pond: bool = false

#############################

@export var player_id := 1:
	set(id):
		player_id = id
		%InputSynchronizer.set_multiplayer_authority(id)


func _ready() -> void:
	add_to_group("player")
	target_position = global_position
	tag_indicator.hide()  # ensure indicator for tag minigame hidden
	tag_indicator_outline.hide()
	rod_sprite.hide()
	cast_lure_button.hide()
	cast_lure_button.pressed.connect(_on_cast_pressed)
	fishing_detector.area_entered.connect(_at_pond)
	fishing_detector.area_exited.connect(_left_pond)
	# Connect area_entered so TagArea touching TagArea triggers the tag
	if has_node("TagArea"):
		$TagArea.area_entered.connect(_on_tag_area_area_entered)
	
	# Listen for player name updates from MultiplayerManager
	MultiplayerManager.player_names_updated.connect(_on_player_names_updated)
	# Apply initial name on spawn
	_update_name_label()
	
	# Only enable the camera if this player instance belongs to the local machine
	if %InputSynchronizer.is_multiplayer_authority():
		camera.make_current()
		
		# Detach camera rotation/position scaling from parent body movement
		camera.top_level = true 
		
		# Defer camera snapping to allow global_position and zone offset to replicate
		get_tree().process_frame.connect(_init_camera_on_spawn, CONNECT_ONE_SHOT)
	else:
		camera.enabled = false


func _on_player_names_updated(_names: Dictionary) -> void:
	_update_name_label()


func _update_name_label() -> void:
	if is_instance_valid(name_label):
		# Fetches the assigned monkey name using this player's peer ID
		name_label.text = MultiplayerManager.get_player_name(player_id)


func _init_camera_on_spawn() -> void:
	update_camera_grid()


func is_local_player() -> bool:
	return %InputSynchronizer.is_multiplayer_authority()


func _unhandled_input(event: InputEvent) -> void:
	if is_movement_disabled or not %InputSynchronizer.is_multiplayer_authority():
		return
		
	# Handles Mouse Clicks (PC)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		request_move_target.rpc(get_global_mouse_position())
	# Handles Screen Touches (iOS/Android)
	elif event is InputEventScreenTouch and event.pressed:
		var world_touch_pos = get_canvas_transform().affine_inverse() * event.position
		request_move_target.rpc(world_touch_pos)


# RPC sends the click destination to the server (and calls it locally)
@rpc("any_peer", "call_local", "reliable")
func request_move_target(pos: Vector2) -> void:
	target_position = pos
	is_moving = true


# This RPC will only execute on the network peer that owns this specific player
@rpc("authority", "call_local", "reliable")
func play_teleport_fade() -> void:
	animation_player.play("fade_to_black")
	
	# Wait for the fade out to finish before letting the screen clear
	await animation_player.animation_finished
	
	animation_player.play("fade_from_black")


func _physics_process(delta: float) -> void:
	if is_movement_disabled:
		if multiplayer.is_server():
			velocity = Vector2.ZERO
		return

	var move_dir := Vector2.ZERO
	direction = %InputSynchronizer.input_direction # Synchronized arrow keys

	# 1. Keyboard Input Priority (Overrides active point-and-click)
	if direction != Vector2.ZERO:
		if is_moving:
			stop_movement_rpc.rpc()
		move_dir = direction
	# 2. Point-and-Click / Touch Movement
	elif is_moving:
		var distance = global_position.distance_to(target_position)
		if distance > ARRIVAL_DISTANCE:
			move_dir = global_position.direction_to(target_position)
		else:
			if multiplayer.is_server():
				stop_movement_rpc.rpc()

	# Server Physics execution
	if multiplayer.is_server():
		if move_dir != Vector2.ZERO:
			velocity = move_dir * SPEED
			move_and_slide()
			
			# If point-and-click ran into a collision barrier, cancel target
			if is_moving and direction == Vector2.ZERO and get_slide_collision_count() > 0:
				stop_movement_rpc.rpc()
		else:
			velocity = velocity.move_toward(Vector2.ZERO, SPEED)
			move_and_slide()
		
		#if MultiplayerManager.is_tag_minigame_started and player_id == MultiplayerManager.tag_it_peer_id:
			#for body in tag_area.get_overlapping_bodies():
				#if body.is_in_group("player") and body.player_id != player_id:
					#MultiplayerManager.request_player_tag(body.player_id)
					#break
		
		# Check for Tag Minigame collsions
		#if MultiplayerManager.is_tag_minigame_started and player_id == MultiplayerManager.tag_it_peer_id:
			#for i in range(get_slide_collision_count()):
				#var collision = get_slide_collision(i)
				#var collider = collision.get_collider()
				#if is_instance_valid(collider) and collider.is_in_group("player"):
					#var target_peer = collider.player_id
					#if target_peer != player_id:
						#MultiplayerManager.request_player_tag(target_peer)
						#break # Exit the loop so we don't send multiple tag requests in 1 frame

	# Client / Host Animation Rendering
	if not multiplayer.is_server() or MultiplayerManager.host_mode_enabled:
		if move_dir != Vector2.ZERO or velocity.length() > 10.0:
			var anim_dir = move_dir if move_dir != Vector2.ZERO else velocity.normalized()
			update_walk_animation(anim_dir)
		else:
			monkey.stop()
			
	if %InputSynchronizer.is_multiplayer_authority():
		update_camera_grid()


@rpc("any_peer", "call_local", "reliable")
func stop_movement_rpc() -> void:
	is_moving = false
	velocity = Vector2.ZERO
	if is_node_ready() and monkey:
		monkey.stop()


func update_camera_grid() -> void:
	var local_pos = global_position - current_grid_offset
	
	var current_cell_x = floor(local_pos.x / GRID_SIZE.x)
	var current_cell_y = floor(local_pos.y / GRID_SIZE.y)
	
	var target_camera_pos = Vector2(
		(current_cell_x * GRID_SIZE.x) + (GRID_SIZE.x / 2.0),
		(current_cell_y * GRID_SIZE.y) + (GRID_SIZE.y / 2.0)
	) + current_grid_offset
	
	camera.global_position = target_camera_pos


@rpc("authority", "call_local", "reliable")
func update_zone_offset(new_offset: Vector2) -> void:
	current_grid_offset = new_offset
	if %InputSynchronizer.is_multiplayer_authority():
		update_camera_grid()


func update_walk_animation(dir: Vector2) -> void:
	var angle = rad_to_deg(dir.angle())
	
	if angle >= 67.5 and angle <= 112.5:
		monkey.play("walking-front")
		monkey.flip_h = false
	elif angle >= -112.5 and angle <= -67.5:
		monkey.play("walking-back")
		monkey.flip_h = false
	elif angle >= -22.5 and angle <= 22.5:
		monkey.play("walking-side")
		monkey.flip_h = false
	elif angle >= 157.5 or angle <= -157.5:
		monkey.play("walking-side")
		monkey.flip_h = true
	elif angle > 22.5 and angle < 67.5:
		monkey.play("walking-front-diagonal")
		monkey.flip_h = false
	elif angle > 112.5 and angle < 157.5:
		monkey.play("walking-front-diagonal")
		monkey.flip_h = true
	elif angle > -67.5 and angle < -22.5:
		monkey.play("walking-back-diagonal")
		monkey.flip_h = false
	elif angle > -157.5 and angle < -112.5:
		monkey.play("walking-back-diagonal")
		monkey.flip_h = true

@rpc("any_peer", "call_local", "reliable")
func set_movement_disabled(disabled: bool) -> void:
	is_movement_disabled = disabled
	stop_movement_rpc()

func set_tag_indicator(is_it: bool) -> void:
	if is_instance_valid(tag_indicator):
		tag_indicator.show()
		tag_indicator.modulate = COLOR_GOLD if is_it else Color("ffffff") # Red vs Blue
		tag_indicator_outline.show()

func hide_tag_indicator() -> void:
	if is_instance_valid(tag_indicator):
		tag_indicator.hide()
	if is_instance_valid(tag_indicator_outline):
		tag_indicator_outline.hide()

func _on_tag_area_area_entered(area: Area2D) -> void:
	# Only the server processes tags
	if not multiplayer.is_server():
		return
	
	# Block tagging if game hasn't started or countdown is actively running
	if MultiplayerManager.is_tag_countdown_active or not MultiplayerManager.is_tag_minigame_started:
		return
	
	# Check if minigame is active and THIS player is currently "It"
	if MultiplayerManager.is_tag_minigame_started and player_id == MultiplayerManager.tag_it_peer_id:
		# Get the parent player node of the TagArea we just touched
		var other_player = area.get_parent()
		
		if is_instance_valid(other_player) and other_player.is_in_group("player") and other_player != self:
			if "player_id" in other_player and other_player.player_id != player_id:
				MultiplayerManager.request_player_tag(other_player.player_id)

func equip_rod_visual(rod: MultiplayerManager.FishingRod) -> void:
	print("equip_rod_visual: %s" % rod)
	is_rod_equipped = true
	if is_instance_valid(rod_sprite):
		rod_sprite.show()
		rod_sprite.modulate = MultiplayerManager.ROD_COLORS.get(rod)
	_update_cast_button()

func unequip_rod_visual() -> void:
	print("%s unequipped fishing rod" % name)
	is_rod_equipped = false
	if is_instance_valid(rod_sprite):
		rod_sprite.hide()
	_update_cast_button()

# Detection callbacks
func _at_pond(_area: Area2D) -> void:
	is_at_pond = true
	_update_cast_button()

func _left_pond(_area: Area2D) -> void:
	is_at_pond = false
	_update_cast_button()

func _update_cast_button() -> void:
	if not is_instance_valid(cast_lure_button):
		return

	# Only show CAST for the local player's character
	var is_local = is_multiplayer_authority() if has_node("InputSynchronizer") else true
	
	if is_local and is_rod_equipped and is_at_pond:
		cast_lure_button.show()
	else:
		cast_lure_button.hide()

func _on_cast_pressed() -> void:
	print("Casting fishing line!")
	# TODO
