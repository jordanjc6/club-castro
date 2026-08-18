extends Area2D

enum CupSize { SMALL, MEDIUM, LARGE }

const TOPPING_SCRIPT = preload("res://scripts/minigames/topping_spoon.gd")
const TOPPINGS = TOPPING_SCRIPT.Topping

## Cup Configuration
@export var cup_size: CupSize = CupSize.MEDIUM
## How far down (in pixels) the ice sits when the cup is empty
@export var ice_bottom_offset: float = 65.0 
@export var grass_jelly_bottom_offset: float = 65.0 

# tapioca
@export var tapioca_row1_bottom_offset: float = 25
@export var tapioca_row2_bottom_offset: float = 20
@export var tapioca_row3_bottom_offset: float = 15
@export var tapioca_row4_bottom_offset: float = 5
@export var tapioca_row5_bottom_offset: float = 0
@export var tapioca_row6_bottom_offset: float = 0
@export var tapioca_row7_bottom_offset: float = 28

# mango popping boba
@export var mango_row1_bottom_offset: float = 25
@export var mango_row2_bottom_offset: float = 20
@export var mango_row3_bottom_offset: float = 15
@export var mango_row4_bottom_offset: float = 5
@export var mango_row5_bottom_offset: float = 0
@export var mango_row6_bottom_offset: float = 28

## Fill Animation Settings
const FILL_DURATION: float = 1.2

## Node References
@onready var liquid_fill: ColorRect = $DrinkFill/ColorRect
@onready var liquid_mask: Polygon2D = $DrinkFill
@onready var ice_sprite: Sprite2D = $IceSprite
@onready var grass_jelly: Node2D = $GrassJelly
@onready var pudding_sprite: Sprite2D = $PuddingSprite
@onready var tapioca_bunch: Node2D = $Tapioca
@onready var mango_bunch: Node2D = $PoppingBoba

## State Flags
var is_dragging: bool = true
var hovered_coaster: Area2D = null
var is_placed: bool = false
var is_filled: bool = false
var is_filling: bool = false

## Drink Data
var current_flavor: String = "" 
var current_coaster: Coaster = null
var offset: Vector2 = Vector2.ZERO
var has_ice: bool = false
var toppings_added: Array[TOPPINGS] = []

## Ice Positioning Vectors
var ice_top_pos: Vector2 = Vector2.ZERO
var ice_bottom_pos: Vector2 = Vector2.ZERO

## Grass Jelly Positioning Vectors
var grass_jelly_top_pos: Vector2 = Vector2.ZERO
var grass_jelly_bottom_pos: Vector2 = Vector2.ZERO

## Tapioca Positioning Vectors
var tapioca_row1_top_pos: Vector2 = Vector2.ZERO
var tapioca_row1_bottom_pos: Vector2 = Vector2.ZERO
var tapioca_row2_top_pos: Vector2 = Vector2.ZERO
var tapioca_row2_bottom_pos: Vector2 = Vector2.ZERO
var tapioca_row3_top_pos: Vector2 = Vector2.ZERO
var tapioca_row3_bottom_pos: Vector2 = Vector2.ZERO
var tapioca_row4_top_pos: Vector2 = Vector2.ZERO
var tapioca_row4_bottom_pos: Vector2 = Vector2.ZERO
var tapioca_row5_top_pos: Vector2 = Vector2.ZERO
var tapioca_row5_bottom_pos: Vector2 = Vector2.ZERO
var tapioca_row6_top_pos: Vector2 = Vector2.ZERO
var tapioca_row6_bottom_pos: Vector2 = Vector2.ZERO
var tapioca_row7_top_pos: Vector2 = Vector2.ZERO
var tapioca_row7_bottom_pos: Vector2 = Vector2.ZERO

## Tapioca Positioning Vectors
var mango_row1_top_pos: Vector2 = Vector2.ZERO
var mango_row1_bottom_pos: Vector2 = Vector2.ZERO
var mango_row2_top_pos: Vector2 = Vector2.ZERO
var mango_row2_bottom_pos: Vector2 = Vector2.ZERO
var mango_row3_top_pos: Vector2 = Vector2.ZERO
var mango_row3_bottom_pos: Vector2 = Vector2.ZERO
var mango_row4_top_pos: Vector2 = Vector2.ZERO
var mango_row4_bottom_pos: Vector2 = Vector2.ZERO
var mango_row5_top_pos: Vector2 = Vector2.ZERO
var mango_row5_bottom_pos: Vector2 = Vector2.ZERO
var mango_row6_top_pos: Vector2 = Vector2.ZERO
var mango_row6_bottom_pos: Vector2 = Vector2.ZERO


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
	
	if grass_jelly:
		grass_jelly_top_pos = grass_jelly.position
		grass_jelly_bottom_pos = grass_jelly_top_pos + Vector2(0, grass_jelly_bottom_offset)
		grass_jelly.visible = false
	
	if pudding_sprite:
		pudding_sprite.visible = false
	
	if tapioca_bunch:
		tapioca_row1_top_pos = tapioca_bunch.get_node("row1").position
		tapioca_row1_bottom_pos = tapioca_row1_top_pos + Vector2(0, tapioca_row1_bottom_offset)
		tapioca_bunch.get_node("row1").visible = false
		
		tapioca_row2_top_pos = tapioca_bunch.get_node("row2").position
		tapioca_row2_bottom_pos = tapioca_row2_top_pos + Vector2(0, tapioca_row2_bottom_offset)
		tapioca_bunch.get_node("row2").visible = false
		
		tapioca_row3_top_pos = tapioca_bunch.get_node("row3").position
		tapioca_row3_bottom_pos = tapioca_row3_top_pos + Vector2(0, tapioca_row3_bottom_offset)
		tapioca_bunch.get_node("row3").visible = false
		
		tapioca_row4_top_pos = tapioca_bunch.get_node("row4").position
		tapioca_row4_bottom_pos = tapioca_row4_top_pos + Vector2(0, tapioca_row4_bottom_offset)
		tapioca_bunch.get_node("row4").visible = false
		
		tapioca_row5_top_pos = tapioca_bunch.get_node("row5").position
		tapioca_row5_bottom_pos = tapioca_row5_top_pos + Vector2(0, tapioca_row5_bottom_offset)
		tapioca_bunch.get_node("row5").visible = false
		
		if tapioca_bunch.get_node_or_null("row6"):
			tapioca_row6_top_pos = tapioca_bunch.get_node("row6").position
			tapioca_row6_bottom_pos = tapioca_row6_top_pos + Vector2(0, tapioca_row6_bottom_offset)
			tapioca_bunch.get_node("row6").visible = false
		
		if tapioca_bunch.get_node_or_null("row7"):
			tapioca_row7_top_pos = tapioca_bunch.get_node("row7").position
			tapioca_row7_bottom_pos = tapioca_row7_top_pos + Vector2(0, tapioca_row7_bottom_offset)
			tapioca_bunch.get_node("row7").visible = false
	
	if mango_bunch:
		mango_row1_top_pos = mango_bunch.get_node("row1").position
		mango_row1_bottom_pos = mango_row1_top_pos + Vector2(0, mango_row1_bottom_offset)
		mango_bunch.get_node("row1").visible = false
		
		mango_row2_top_pos = mango_bunch.get_node("row2").position
		mango_row2_bottom_pos = mango_row2_top_pos + Vector2(0, mango_row2_bottom_offset)
		mango_bunch.get_node("row2").visible = false
		
		mango_row3_top_pos = mango_bunch.get_node("row3").position
		mango_row3_bottom_pos = mango_row3_top_pos + Vector2(0, mango_row3_bottom_offset)
		mango_bunch.get_node("row3").visible = false
		
		mango_row4_top_pos = mango_bunch.get_node("row4").position
		mango_row4_bottom_pos = mango_row4_top_pos + Vector2(0, mango_row4_bottom_offset)
		mango_bunch.get_node("row4").visible = false
		
		if mango_bunch.get_node_or_null("row5"):
			mango_row5_top_pos = mango_bunch.get_node("row5").position
			mango_row5_bottom_pos = mango_row5_top_pos + Vector2(0, mango_row5_bottom_offset)
			mango_bunch.get_node("row5").visible = false
		
		if mango_bunch.get_node_or_null("row6"):
			mango_row6_top_pos = mango_bunch.get_node("row6").position
			mango_row6_bottom_pos = mango_row6_top_pos + Vector2(0, mango_row6_bottom_offset)
			mango_bunch.get_node("row6").visible = false

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
	
	if toppings_added.has(TOPPINGS.GRASS_JELLY) and grass_jelly:
		tween.tween_property(grass_jelly, "position", grass_jelly_top_pos, FILL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if toppings_added.has(TOPPINGS.TAPIOCA) and tapioca_bunch:
		tween.tween_property(tapioca_bunch.get_node("row1"), "position", tapioca_row1_top_pos, FILL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(tapioca_bunch.get_node("row2"), "position", tapioca_row2_top_pos, FILL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(tapioca_bunch.get_node("row3"), "position", tapioca_row3_top_pos, FILL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(tapioca_bunch.get_node("row4"), "position", tapioca_row4_top_pos, FILL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(tapioca_bunch.get_node("row5"), "position", tapioca_row5_top_pos, FILL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		if tapioca_bunch.get_node_or_null("row6"):
			tween.tween_property(tapioca_bunch.get_node("row6"), "position", tapioca_row6_top_pos, FILL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		if tapioca_bunch.get_node_or_null("row7"):
			tween.tween_property(tapioca_bunch.get_node("row7"), "position", tapioca_row7_top_pos, FILL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if toppings_added.has(TOPPINGS.POPPING_BOBA) and mango_bunch:
		tween.tween_property(mango_bunch.get_node("row1"), "position", mango_row1_top_pos, FILL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(mango_bunch.get_node("row2"), "position", mango_row2_top_pos, FILL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(mango_bunch.get_node("row3"), "position", mango_row3_top_pos, FILL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(mango_bunch.get_node("row4"), "position", mango_row4_top_pos, FILL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if mango_bunch.get_node_or_null("row5"):
			tween.tween_property(mango_bunch.get_node("row5"), "position", mango_row5_top_pos, FILL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if mango_bunch.get_node_or_null("row6"):
			tween.tween_property(mango_bunch.get_node("row6"), "position", mango_row6_top_pos, FILL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
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
		print("Cup already has %s!" % TOPPINGS.keys()[topping])
		return
	
	# check topping sprite exists and where to place it depending on juice level
	match topping:
		TOPPINGS.TAPIOCA:
			add_tapioca()
		TOPPINGS.POPPING_BOBA:
			add_popping_boba()
		TOPPINGS.GRASS_JELLY:
			add_grass_jelly()
		TOPPINGS.PUDDING:
			pudding_sprite.visible = true
	
	toppings_added.append(topping)
	print("%s added to cup!" % TOPPINGS.keys()[topping])

func add_tapioca() -> void:
	if tapioca_bunch:
		tapioca_bunch.get_node("row1").visible = true
		tapioca_bunch.get_node("row2").visible = true
		tapioca_bunch.get_node("row3").visible = true
		tapioca_bunch.get_node("row4").visible = true
		tapioca_bunch.get_node("row5").visible = true
		if tapioca_bunch.get_node_or_null("row6"):
			tapioca_bunch.get_node("row6").visible = true
		if tapioca_bunch.get_node_or_null("row7"):
			tapioca_bunch.get_node("row7").visible = true
		
		if is_filling:
			# Calculate current surface position using scale.y
			var current_fill_ratio: float = liquid_fill.scale.y
			
			# Snap ice to current liquid level
			tapioca_bunch.get_node("row1").position = tapioca_row1_bottom_pos.lerp(tapioca_row1_top_pos, current_fill_ratio)
			tapioca_bunch.get_node("row2").position = tapioca_row2_bottom_pos.lerp(tapioca_row2_top_pos, current_fill_ratio)
			tapioca_bunch.get_node("row3").position = tapioca_row3_bottom_pos.lerp(tapioca_row3_top_pos, current_fill_ratio)
			tapioca_bunch.get_node("row4").position = tapioca_row4_bottom_pos.lerp(tapioca_row4_top_pos, current_fill_ratio)
			tapioca_bunch.get_node("row5").position = tapioca_row5_bottom_pos.lerp(tapioca_row5_top_pos, current_fill_ratio)
			if tapioca_bunch.get_node_or_null("row6"):
				tapioca_bunch.get_node("row6").position = tapioca_row6_bottom_pos.lerp(tapioca_row6_top_pos, current_fill_ratio)
			if tapioca_bunch.get_node_or_null("row7"):
				tapioca_bunch.get_node("row7").position = tapioca_row7_bottom_pos.lerp(tapioca_row7_top_pos, current_fill_ratio)
			
			# Animate ice floating up for the remaining duration of the pour
			var remaining_fill_ratio: float = 1.0 - current_fill_ratio
			var remaining_time: float = FILL_DURATION * remaining_fill_ratio
			
			if remaining_time > 0:
				var tween = create_tween()
				tween.tween_property(tapioca_bunch.get_node("row1"), "position", tapioca_row1_top_pos, remaining_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tween.tween_property(tapioca_bunch.get_node("row2"), "position", tapioca_row2_top_pos, remaining_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tween.tween_property(tapioca_bunch.get_node("row3"), "position", tapioca_row3_top_pos, remaining_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tween.tween_property(tapioca_bunch.get_node("row4"), "position", tapioca_row4_top_pos, remaining_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tween.tween_property(tapioca_bunch.get_node("row5"), "position", tapioca_row5_top_pos, remaining_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				if tapioca_bunch.get_node_or_null("row6"):
					tween.tween_property(tapioca_bunch.get_node("row6"), "position", tapioca_row6_top_pos, remaining_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				if tapioca_bunch.get_node_or_null("row7"):
					tween.tween_property(tapioca_bunch.get_node("row7"), "position", tapioca_row7_top_pos, remaining_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				
		elif is_filled:
			# Cup is already full -> Place ice at the top surface
			tapioca_bunch.get_node("row1").position = tapioca_row1_top_pos
			tapioca_bunch.get_node("row2").position = tapioca_row2_top_pos
			tapioca_bunch.get_node("row3").position = tapioca_row3_top_pos
			tapioca_bunch.get_node("row4").position = tapioca_row4_top_pos
			tapioca_bunch.get_node("row5").position = tapioca_row5_top_pos
			if tapioca_bunch.get_node_or_null("row6"):
				tapioca_bunch.get_node("row6").position = tapioca_row6_top_pos
			if tapioca_bunch.get_node_or_null("row7"):
				tapioca_bunch.get_node("row7").position = tapioca_row7_top_pos
		else:
			# Cup is empty -> Place ice at the bottom
			tapioca_bunch.get_node("row1").position = tapioca_row1_bottom_pos
			tapioca_bunch.get_node("row2").position = tapioca_row2_bottom_pos
			tapioca_bunch.get_node("row3").position = tapioca_row3_bottom_pos
			tapioca_bunch.get_node("row4").position = tapioca_row4_bottom_pos
			tapioca_bunch.get_node("row5").position = tapioca_row5_bottom_pos
			if tapioca_bunch.get_node_or_null("row6"):
				tapioca_bunch.get_node("row6").position = tapioca_row6_bottom_pos
			if tapioca_bunch.get_node_or_null("row7"):
				tapioca_bunch.get_node("row7").position = tapioca_row7_bottom_pos

func add_popping_boba() -> void:
	if mango_bunch:
		mango_bunch.get_node("row1").visible = true
		mango_bunch.get_node("row2").visible = true
		mango_bunch.get_node("row3").visible = true
		mango_bunch.get_node("row4").visible = true
		if mango_bunch.get_node_or_null("row5"):
			mango_bunch.get_node("row5").visible = true
		if mango_bunch.get_node_or_null("row6"):
			mango_bunch.get_node("row6").visible = true
		
		if is_filling:
			# Calculate current surface position using scale.y
			var current_fill_ratio: float = liquid_fill.scale.y
			
			# Snap ice to current liquid level
			mango_bunch.get_node("row1").position = mango_row1_bottom_pos.lerp(mango_row1_top_pos, current_fill_ratio)
			mango_bunch.get_node("row2").position = mango_row2_bottom_pos.lerp(mango_row2_top_pos, current_fill_ratio)
			mango_bunch.get_node("row3").position = mango_row3_bottom_pos.lerp(mango_row3_top_pos, current_fill_ratio)
			mango_bunch.get_node("row4").position = mango_row4_bottom_pos.lerp(mango_row4_top_pos, current_fill_ratio)
			if mango_bunch.get_node_or_null("row5"):
				mango_bunch.get_node("row5").position = mango_row5_bottom_pos.lerp(mango_row5_top_pos, current_fill_ratio)
			if mango_bunch.get_node_or_null("row6"):
				mango_bunch.get_node("row6").position = mango_row6_bottom_pos.lerp(mango_row6_top_pos, current_fill_ratio)
			
			# Animate ice floating up for the remaining duration of the pour
			var remaining_fill_ratio: float = 1.0 - current_fill_ratio
			var remaining_time: float = FILL_DURATION * remaining_fill_ratio
			
			if remaining_time > 0:
				var tween = create_tween()
				tween.tween_property(mango_bunch.get_node("row1"), "position", mango_row1_top_pos, remaining_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tween.tween_property(mango_bunch.get_node("row2"), "position", mango_row2_top_pos, remaining_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tween.tween_property(mango_bunch.get_node("row3"), "position", mango_row3_top_pos, remaining_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tween.tween_property(mango_bunch.get_node("row4"), "position", mango_row4_top_pos, remaining_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				if mango_bunch.get_node_or_null("row5"):
					tween.tween_property(mango_bunch.get_node("row5"), "position", mango_row5_top_pos, remaining_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				if mango_bunch.get_node_or_null("row6"):
					tween.tween_property(mango_bunch.get_node("row6"), "position", mango_row6_top_pos, remaining_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				
		elif is_filled:
			# Cup is already full -> Place ice at the top surface
			mango_bunch.get_node("row1").position = mango_row1_top_pos
			mango_bunch.get_node("row2").position = mango_row2_top_pos
			mango_bunch.get_node("row3").position = mango_row3_top_pos
			mango_bunch.get_node("row4").position = mango_row4_top_pos
			if mango_bunch.get_node_or_null("row5"):
				mango_bunch.get_node("row5").position = mango_row5_top_pos
			if mango_bunch.get_node_or_null("row6"):
				mango_bunch.get_node("row6").position = mango_row6_top_pos
		else:
			# Cup is empty -> Place ice at the bottom
			mango_bunch.get_node("row1").position = mango_row1_bottom_pos
			mango_bunch.get_node("row2").position = mango_row2_bottom_pos
			mango_bunch.get_node("row3").position = mango_row3_bottom_pos
			mango_bunch.get_node("row4").position = mango_row4_bottom_pos
			if mango_bunch.get_node_or_null("row5"):
				mango_bunch.get_node("row5").position = mango_row5_bottom_pos
			if mango_bunch.get_node_or_null("row6"):
				mango_bunch.get_node("row6").position = mango_row6_bottom_pos

func add_grass_jelly() -> void:
	grass_jelly.visible = true
	
	if is_filling:
			# Calculate current surface position using scale.y
			var current_fill_ratio: float = liquid_fill.scale.y
			
			# Snap ice to current liquid level
			grass_jelly.position = grass_jelly_bottom_pos.lerp(grass_jelly_top_pos, current_fill_ratio)
			
			# Animate ice floating up for the remaining duration of the pour
			var remaining_fill_ratio: float = 1.0 - current_fill_ratio
			var remaining_time: float = FILL_DURATION * remaining_fill_ratio
			
			if remaining_time > 0:
				var tween = create_tween()
				tween.tween_property(grass_jelly, "position", grass_jelly_top_pos, remaining_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	elif is_filled:
		# Cup is already full -> Place ice at the top surface
		grass_jelly.position = grass_jelly_top_pos
	else:
		# Cup is empty -> Place ice at the bottom
		grass_jelly.position = grass_jelly_bottom_pos

# --- ORDER VALIDATION READOUT ---

func get_drink_data() -> Dictionary:
	return {
		"size": cup_size,
		"flavor": current_flavor,
		"has_ice": has_ice,
		"toppings": toppings_added
	}
