extends Area2D

enum CupSize { SMALL, MEDIUM, LARGE }

const TOPPING_SCRIPT = preload("res://scripts/minigames/topping_spoon.gd")
const TOPPINGS = TOPPING_SCRIPT.Topping

## Cup Configuration
@export var cup_size: CupSize = CupSize.MEDIUM
## How far down (in pixels) the ice sits when the cup is empty
@export var ice_bottom_offset: float = 65.0 

## Fill Animation Settings
const FILL_DURATION: float = 1.2

## Node References
@onready var liquid_fill: ColorRect = $DrinkFill/ColorRect
@onready var liquid_mask: Polygon2D = $DrinkFill
@onready var ice_sprite: Sprite2D = $IceSprite

## State Flags
var is_dragging: bool = true
var hovered_coaster: Area2D = null
var is_placed: bool = false
var is_filled: bool = false
var is_filling: bool = false
var has_ice: bool = false
var toppings_added: Array[TOPPINGS] = []

## Drink Data
var current_flavor: String = "" 
var current_coaster: Coaster = null
var offset: Vector2 = Vector2.ZERO

## Ice Positioning Vectors
var ice_top_pos: Vector2 = Vector2.ZERO
var ice_bottom_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Add to group so ice spoon can detect this cup
	add_to_group("cups")
	
	# Set snapping offsets based on cup size
	match cup_size:
		CupSize.SMALL:
			offset = Vector2(0, 40)
		CupSize.MEDIUM:
			offset = Vector2(0, 52)
		CupSize.LARGE:
			offset = Vector2(0, 49)
	
	# Connect signals
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	input_event.connect(_on_input_event)
	
	# Set pivot to bottom so fill scales upward
	liquid_fill.pivot_offset = Vector2(0, liquid_fill.size.y)
	liquid_fill.scale.y = 0.0
	liquid_mask.visible = false
	
	# Setup ice positions based on editor position
	if ice_sprite:
		ice_top_pos = ice_sprite.position
		ice_bottom_pos = ice_top_pos + Vector2(0, ice_bottom_offset)
		ice_sprite.visible = false

func _exit_tree() -> void:
	# Free up coaster space if deleted
	if current_coaster != null and is_instance_valid(current_coaster):
		current_coaster.remove_cup()

func _process(_delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position()

func _input(event: InputEvent) -> void:
	if is_dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_check_drop()

# --- DRAG AND DROP / COASTER LOGIC ---

func _check_drop() -> void:
	is_dragging = false
	
	if hovered_coaster != null and hovered_coaster.is_empty():
		current_coaster = hovered_coaster
		current_coaster.place_cup(self)
		
		var shape_node = hovered_coaster.get_node_or_null("CollisionShape2D")
		global_position = shape_node.global_position - offset
		is_placed = true
		print("Placed on ", hovered_coaster.name)
	else:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("coasters"):
		hovered_coaster = area

func _on_area_exited(area: Area2D) -> void:
	if area == hovered_coaster:
		hovered_coaster = null

# --- DISPENSER / DRINK FILL LOGIC ---

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not is_placed or is_filled or is_filling:
		return
		
	var is_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var is_touch = event is InputEventScreenTouch and event.pressed
	
	if is_click or is_touch:
		get_viewport().set_input_as_handled()
		_try_fill()

func _try_fill() -> void:
	var dispensers = get_tree().get_nodes_in_group("dispenser")
	
	for dispenser in dispensers:
		if dispenser is Dispenser and dispenser.is_active:
			_fill_from_dispenser(dispenser)
			break

func _fill_from_dispenser(dispenser: Dispenser) -> void:
	is_filling = true
	
	current_flavor = dispenser.flavor
	liquid_fill.color = dispenser.liquid_color
	liquid_mask.visible = true
	
	# set_parallel(true) allows juice fill and pre-existing ice to float simultaneously
	var tween = create_tween().set_parallel(true)
	tween.tween_property(liquid_fill, "scale:y", 1.0, FILL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# If ice was added BEFORE pouring started, float it up together with the juice
	if has_ice and ice_sprite:
		tween.tween_property(ice_sprite, "position", ice_top_pos, FILL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	tween.chain().finished.connect(func():
		is_filled = true
		is_filling = false
		print("Cup filled! [Size: %s, Flavor: %s]" % [CupSize.keys()[cup_size], current_flavor])
	)

func add_ice() -> void:
	if not is_placed or has_ice:
		if not is_placed:
			print("Must place cup on a coaster before adding ice!")
		elif has_ice:
			print("Cup already has ice!")
		return
		
	has_ice = true
	print("Added ice to cup!")
	
	if ice_sprite:
		ice_sprite.visible = true
		
		if is_filling:
			# Calculate current surface position using scale.y
			var current_fill_ratio: float = liquid_fill.scale.y
			
			# Snap ice to current liquid level
			ice_sprite.position = ice_bottom_pos.lerp(ice_top_pos, current_fill_ratio)
			
			# Animate ice floating up for the remaining duration of the pour
			var remaining_fill_ratio: float = 1.0 - current_fill_ratio
			var remaining_time: float = FILL_DURATION * remaining_fill_ratio
			
			if remaining_time > 0:
				var ice_tween = create_tween()
				ice_tween.tween_property(ice_sprite, "position", ice_top_pos, remaining_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				
		elif is_filled:
			# Cup is already full -> Place ice at the top surface
			ice_sprite.position = ice_top_pos
		else:
			# Cup is empty -> Place ice at the bottom
			ice_sprite.position = ice_bottom_pos

func add_topping(topping: TOPPINGS) -> void:
	if not is_placed:
		print("Must place cup on a coaster before adding toppings!")
		return
	elif toppings_added.has(topping):
		print("Cup already has %s!" % topping)
		return
	
	# check topping sprite exists and where to place it depending on juice level
	match topping:
		TOPPINGS.TAPIOCA:
			return
		TOPPINGS.POPPING_BOBA:
			return
		TOPPINGS.GRASS_JELLY:
			return
		TOPPINGS.PUDDING:
			return
	
	toppings_added.append(topping)
	print("%s added to cup!" % topping)

# --- ORDER VALIDATION READOUT ---

func get_drink_data() -> Dictionary:
	return {
		"size": cup_size,
		"flavor": current_flavor,
		"has_ice": has_ice,
		"is_filled": is_filled
	}
