extends CharacterBody2D

const SPEED = 300.0
const ARRIVAL_DISTANCE = 5.0 # Distance threshold to stop moving

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

# fishing ###################
#############################
@onready var rod_sprite: Sprite2D = $FishingRod
@onready var cast_lure_button: Button = $CastLureButton
@onready var fishing_detector: Area2D = $FishingAreaCollider
var is_rod_equipped: bool = false
var is_at_pond: bool = false
var lure_scene = preload("res://scenes/minigames/FishingLure.tscn") # Adjust path to your Lure scene
var equipped_rod_color: Color = Color.WHITE
var active_lure: Node2D = null
var cycle_timer: SceneTreeTimer = null
var miss_timer: SceneTreeTimer = null
var is_fish_on_line: bool = false
var bite_time_stamp: float = 0.0

const CYCLE_DURATION: float = 15.0 # Fixed 15-second cycle limit

#############################

func _ready() -> void:
	add_to_group("player")
	rod_sprite.hide()
	cast_lure_button.hide()
	cast_lure_button.pressed.connect(_on_cast_pressed)
	fishing_detector.area_entered.connect(_at_pond)
	fishing_detector.area_exited.connect(_left_pond)
	
	# Enable the camera
	camera.make_current()
	# Detach camera rotation/position scaling from parent body movement
	camera.top_level = true
	target_position = global_position

#func _input(event: InputEvent) -> void:
	## Check if an active lure exists
	#if not is_instance_valid(active_lure):
		#return
#
	## Intercept Left Mouse Click or Touch anywhere on screen
	#if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
	#or (event is InputEventScreenTouch and event.pressed):
#
		## Clean up singleplayer lure
		#active_lure.queue_free()
		#active_lure = null
		#
		## Absorb click so nothing else sees it
		#get_viewport().set_input_as_handled()

#func _input(event: InputEvent) -> void:
	#if not is_instance_valid(active_lure):
		#return
#
	#if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
	#or (event is InputEventScreenTouch and event.pressed):
		#
		## 1. Store reference to the lure being reeled in and clear active_lure 
		## so subsequent clicks immediately pass through naturally
		#var lure_to_reel = active_lure
		#active_lure = null
		#_update_cast_button()
		#
		## 2. Consume the input click immediately
		#get_viewport().set_input_as_handled()
		#
		## 3. Animate the lure returning to the monkey
		#animate_reel_in(lure_to_reel)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(active_lure):
		return

	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
	or (event is InputEventScreenTouch and event.pressed):
		
		var current_time = Time.get_ticks_msec() / 1000.0
		var reaction_time = current_time - bite_time_stamp
		
		# Reaction must be within 1.0 second of fish appearing
		var world_scene = get_tree().get_current_scene()
		var game_manager = world_scene.get_node_or_null("GameManager")
		if is_fish_on_line and reaction_time <= 1.0:
			var caught_fish = MultiplayerManager.get_random_weighted_item(MultiplayerManager.FISH_DATABASE)
			var caught_size = MultiplayerManager.get_random_weighted_item(MultiplayerManager.FISH_SIZES)
			
			var size_word = MultiplayerManager.FISH_SIZES[caught_size]["folder"]
			var notif_message = "You caught a %s %s!" % [size_word, caught_fish]
			
			game_manager.show_temp_notif(notif_message, 3.5)
			show_caught_fish_display(caught_fish, caught_size)
		#else:
			#game_manager.show_temp_notif("Escaped / Missed!")

		is_fish_on_line = false
		var lure_to_reel = active_lure
		active_lure = null
		_update_cast_button()
		
		get_viewport().set_input_as_handled()
		animate_reel_in(lure_to_reel)

func animate_reel_in(lure_node: Node2D) -> void:
	if not is_instance_valid(lure_node):
		return
	
	if lure_node.has_method("kill_tweens"):
		lure_node.kill_tweens()
	
	# Tween lure position back to player global position over 0.3 seconds
	var reel_tween = create_tween().set_parallel(true)
	reel_tween.tween_property(lure_node, "global_position", global_position, 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Optional: scale down slightly as it approaches player
	reel_tween.tween_property(lure_node, "scale", Vector2(0.3, 0.3), 0.35)
	
	# Free lure when reel animation completes
	#reel_tween.chain().tween_callback(func():
		#if is_instance_valid(lure_node):
			#lure_node.queue_free()
	#)
	# Clean up lure safely when tween finishes
	reel_tween.finished.connect(func():
		if is_instance_valid(lure_node):
			lure_node.queue_free()
	)

func _unhandled_input(event: InputEvent) -> void:
	if is_movement_disabled:
		return
		
	# Handles Mouse Clicks (PC)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		set_move_target(get_global_mouse_position())
	# Handles Screen Touches (iOS/Android)
	elif event is InputEventScreenTouch and event.pressed:
		# CanvasTransform converts screen touch coordinates to world position
		var world_touch_pos = get_canvas_transform().affine_inverse() * event.position
		set_move_target(world_touch_pos)


func set_move_target(pos: Vector2) -> void:
	target_position = pos
	is_moving = true


func play_teleport_fade() -> void:
	animation_player.play("fade_to_black")
	
	# Wait for the fade out to finish before letting the screen clear
	await animation_player.animation_finished
	
	animation_player.play("fade_from_black")


func _physics_process(delta: float) -> void:
	if is_movement_disabled:
		return

	# 1. Check for keyboard / D-pad input first
	var key_direction = Input.get_vector("walk-left", "walk-right", "walk-backward", "walk-forward")

	if key_direction != Vector2.ZERO:
		# Keyboard input cancels any active point-and-click pathing
		is_moving = false
		velocity = key_direction * SPEED
		update_walk_animation(key_direction)
		move_and_slide()
	
	# 2. If no keyboard input, process point-and-click / touch movement
	elif is_moving:
		var direction = global_position.direction_to(target_position)
		var distance = global_position.distance_to(target_position)

		if distance > ARRIVAL_DISTANCE:
			velocity = direction * SPEED
			update_walk_animation(direction)
			move_and_slide()
			
			# Stop if running into a wall or collision barrier
			if get_slide_collision_count() > 0:
				stop_movement()
		else:
			stop_movement()
			
	# 3. If neither, stop movement
	else:
		stop_movement()

	update_camera_grid()


func stop_movement() -> void:
	is_moving = false
	velocity = velocity.move_toward(Vector2.ZERO, SPEED)
	monkey.stop()


func update_camera_grid() -> void:
	# 1. Calculate player position relative to the current zone's top-left corner
	var local_pos = global_position - current_grid_offset
	
	# 2. Find which local grid cell index the player is in
	var current_cell_x = floor(local_pos.x / GRID_SIZE.x)
	var current_cell_y = floor(local_pos.y / GRID_SIZE.y)
	
	# 3. Calculate the global center, adding the offset back at the end
	var target_camera_pos = Vector2(
		(current_cell_x * GRID_SIZE.x) + (GRID_SIZE.x / 2.0),
		(current_cell_y * GRID_SIZE.y) + (GRID_SIZE.y / 2.0)
	) + current_grid_offset
	
	camera.global_position = target_camera_pos


func update_zone_offset(new_offset: Vector2) -> void:
	current_grid_offset = new_offset


func update_walk_animation(dir: Vector2) -> void:
	# Convert direction vector into degrees (-180 to 180)
	# 0° = Right, 90° = Down/Front, -90° = Up/Back, 180°/-180° = Left
	var angle = rad_to_deg(dir.angle())
	
	# Straight Down (Front): 67.5° to 112.5°
	if angle >= 67.5 and angle <= 112.5:
		monkey.play("walking-front")
		monkey.flip_h = false
	# Straight Up (Back): -112.5° to -67.5°
	elif angle >= -112.5 and angle <= -67.5:
		monkey.play("walking-back")
		monkey.flip_h = false
	# Straight Right (Side): -22.5° to 22.5°
	elif angle >= -22.5 and angle <= 22.5:
		monkey.play("walking-side")
		monkey.flip_h = false
	# Straight Left (Side): Angles beyond -157.5° or 157.5°
	elif angle >= 157.5 or angle <= -157.5:
		monkey.play("walking-side")
		monkey.flip_h = true
	# Diagonal Down-Right: 22.5° to 67.5°
	elif angle > 22.5 and angle < 67.5:
		monkey.play("walking-front-diagonal")
		monkey.flip_h = false
	# Diagonal Down-Left: 112.5° to 157.5°
	elif angle > 112.5 and angle < 157.5:
		monkey.play("walking-front-diagonal")
		monkey.flip_h = true
	# Diagonal Up-Right: -67.5° to -22.5°
	elif angle > -67.5 and angle < -22.5:
		monkey.play("walking-back-diagonal")
		monkey.flip_h = false
	# Diagonal Up-Left: -157.5° to -112.5°
	elif angle > -157.5 and angle < -112.5:
		monkey.play("walking-back-diagonal")
		monkey.flip_h = true


func set_movement_disabled(disabled: bool) -> void:
	is_movement_disabled = disabled
	if disabled:
		stop_movement()

func equip_rod_visual(rod: MultiplayerManager.FishingRod) -> void:
	print("equip_rod_visual: %s" % rod)
	is_rod_equipped = true
	equipped_rod_color = MultiplayerManager.ROD_COLORS.get(rod)
	if is_instance_valid(rod_sprite):
		rod_sprite.show()
		rod_sprite.modulate = MultiplayerManager.ROD_COLORS.get(rod)
	_update_cast_button()

func unequip_rod_visual() -> void:
	print("%s unequipped fishing rod" % name)
	is_rod_equipped = false
	if is_instance_valid(active_lure):
		active_lure.queue_free()
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
	var is_local = %InputSynchronizer.is_multiplayer_authority() if has_node("InputSynchronizer") else true
	
	if is_local and is_rod_equipped and is_at_pond and active_lure == null:
		cast_lure_button.show()
	else:
		cast_lure_button.hide()

func _on_cast_pressed() -> void:
	var world_scene = get_tree().get_current_scene()
	var pond_center = world_scene.get_node_or_null("CampfirePond/PondCenter")
	
	var target_land_pos: Vector2
	
	if is_instance_valid(pond_center):
		# lerp(start, end, weight): 0.55 throws the lure 55% of the total distance to the center point
		target_land_pos = global_position.lerp(pond_center.global_position, 0.55)
	else:
		target_land_pos = global_position + Vector2(0, 150)
	
	perform_lure_cast_visual(global_position, target_land_pos, equipped_rod_color)

func perform_lure_cast_visual(start_pos: Vector2, end_pos: Vector2, color: Color) -> void:
	# Clear previous lure if it's still floating in the water
	if is_instance_valid(active_lure):
		active_lure.queue_free()
	
	var lure_instance = lure_scene.instantiate()
	get_parent().add_child(lure_instance)
	lure_instance.global_position = start_pos
	active_lure = lure_instance # Track active lure reference
	_update_cast_button()
	
	if lure_instance.has_method("setup_lure"):
		lure_instance.setup_lure(color)

	# Calculate high peak for the parabolic arc trajectory
	var peak_height = 80.0
	var mid_point = (start_pos + end_pos) / 2.0
	var arc_peak = Vector2(mid_point.x, min(start_pos.y, end_pos.y) - peak_height)

	# Animate the arc using a Godot Tween
	var tween = create_tween().set_parallel(true)
	
	# Linear horizontal X move
	tween.tween_property(lure_instance, "global_position:x", end_pos.x, 0.8)\
		.set_trans(Tween.TRANS_LINEAR)
		
	# Curved vertical Y arc (up to peak, then down to water)
	var y_tween = create_tween()
	y_tween.tween_property(lure_instance, "global_position:y", arc_peak.y, 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	y_tween.tween_property(lure_instance, "global_position:y", end_pos.y, 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	y_tween.tween_callback(func():
		if is_instance_valid(lure_instance) and lure_instance.has_method("on_land_in_water"):
			lure_instance.on_land_in_water()
			start_fishing_loop()
	)

func cleanup_singleplayer_fishing_state() -> void:
	# 1. Remove active lure floating in water
	if is_instance_valid(active_lure):
		active_lure.queue_free()
		active_lure = null
		
	# 2. Unequip rod and hide rod sprite
	is_rod_equipped = false
	if is_instance_valid(rod_sprite):
		rod_sprite.hide()
		
	# 3. Hide cast button
	if is_instance_valid(cast_lure_button):
		cast_lure_button.hide()

# Call start_fishing_loop() inside perform_lure_cast_visual after on_land_in_water()
func start_fishing_loop() -> void:
	if not is_instance_valid(active_lure):
		return

	is_fish_on_line = false
	var has_bite = randf() <= 0.75 # Exactly one 75% roll per 15s period

	if has_bite:
		# Choose a single bite timestamp between 2.0s and 15.0s
		var bite_delay = randf_range(2.0, CYCLE_DURATION)
		
		cycle_timer = get_tree().create_timer(bite_delay)
		cycle_timer.timeout.connect(func():
			if is_instance_valid(active_lure):
				trigger_fish_hooked(bite_delay)
		)
	else:
		# 25% chance no bite occurs: wait out the full 15s period then start next cycle
		cycle_timer = get_tree().create_timer(CYCLE_DURATION)
		cycle_timer.timeout.connect(func():
			if is_instance_valid(active_lure):
				start_fishing_loop()
		)

func trigger_fish_hooked(bite_delay: float) -> void:
	is_fish_on_line = true
	bite_time_stamp = Time.get_ticks_msec() / 1000.0
	spawn_exclamation_popup()

	# 1-second reaction window
	miss_timer = get_tree().create_timer(1.0)
	miss_timer.timeout.connect(func():
		if is_instance_valid(active_lure) and is_fish_on_line:
			is_fish_on_line = false
			
			# Lock out remaining seconds of this 15s period before allowing next cycle
			var remaining_time = max(0.1, CYCLE_DURATION - bite_delay)
			get_tree().create_timer(remaining_time).timeout.connect(func():
				if is_instance_valid(active_lure):
					start_fishing_loop()
			)
	)

func spawn_exclamation_popup() -> void:
	var popup = Label.new()
	popup.text = "!!"
	popup.add_theme_font_size_override("font_size", 32)
	popup.add_theme_color_override("font_color", Color.YELLOW)
	popup.position = Vector2(-10, -50)
	add_child(popup)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(popup, "position:y", -80.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.finished.connect(func(): popup.queue_free())

func show_caught_fish_display(fish_code: String, size_code: String) -> void:
	# Get folder name from FISH_SIZES dictionary
	var folder_name = MultiplayerManager.FISH_SIZES[size_code]["folder"]
	
	# Dynamically resolves to: res://assets/icons/fishes/small/blueS.png
	var texture_path = "res://assets/icons/fishes/%s/%s%s.png" % [folder_name, fish_code, size_code]
	
	if not ResourceLoader.exists(texture_path):
		print("Error: Missing fish texture at path: ", texture_path)
		return

	var fish_sprite = Sprite2D.new()
	fish_sprite.texture = load(texture_path)
	fish_sprite.position = Vector2(0, -60)
	add_child(fish_sprite)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(fish_sprite, "position:y", -100.0, 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	tween.tween_property(fish_sprite, "modulate:a", 0.0, 0.5).set_delay(3)

	tween.finished.connect(func():
		if is_instance_valid(fish_sprite):
			fish_sprite.queue_free()
	)
