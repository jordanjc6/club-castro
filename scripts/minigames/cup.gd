extends Area2D

enum CupSize { SMALL, MEDIUM, LARGE }

@export var cup_size: CupSize = CupSize.MEDIUM

@onready var liquid_fill: ColorRect = $DrinkFill/ColorRect
@onready var liquid_mask: Polygon2D = $DrinkFill

var is_dragging: bool = true
var hovered_coaster: Area2D = null
var is_placed: bool = false
var is_filled: bool = false
var is_filling: bool = false

# Stores the flavor of the liquid poured into this cup ("mango", "matcha", etc.)
var current_flavor: String = "" 

var current_coaster: Coaster = null
var offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	match cup_size:
		CupSize.SMALL:
			offset = Vector2(0, 40)
		CupSize.MEDIUM:
			offset = Vector2(0, 52)
		CupSize.LARGE:
			offset = Vector2(0, 49)
	
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	input_event.connect(_on_input_event)
	
	# Set pivot to bottom so fill scales upward
	liquid_fill.pivot_offset = Vector2(0, liquid_fill.size.y)
	liquid_fill.scale.y = 0.0
	liquid_mask.visible = false

func _exit_tree() -> void:
	if current_coaster != null and is_instance_valid(current_coaster):
		current_coaster.remove_cup()

func _process(_delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position()

func _input(event: InputEvent) -> void:
	if is_dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_check_drop()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not is_placed or is_filled or is_filling:
		return
		
	var is_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var is_touch = event is InputEventScreenTouch and event.pressed
	
	if is_click or is_touch:
		get_viewport().set_input_as_handled()
		_try_fill()

func _check_drop() -> void:
	is_dragging = false
	
	if hovered_coaster != null and hovered_coaster.is_empty():
		current_coaster = hovered_coaster
		current_coaster.place_cup(self)
		
		var shape_node = hovered_coaster.get_node_or_null("CollisionShape2D")
		global_position = shape_node.global_position - offset
		is_placed = true
	else:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("coasters"):
		hovered_coaster = area

func _on_area_exited(area: Area2D) -> void:
	if area == hovered_coaster:
		hovered_coaster = null

func _try_fill() -> void:
	# Find any dispenser in the group that is currently active
	var dispensers = get_tree().get_nodes_in_group("dispenser")
	
	for dispenser in dispensers:
		if dispenser is Dispenser and dispenser.is_active:
			_fill_from_dispenser(dispenser)
			break

func _fill_from_dispenser(dispenser: Dispenser) -> void:
	is_filling = true
	
	# Store the flavor from the active dispenser
	current_flavor = dispenser.flavor
	
	# Apply the liquid color defined on the active dispenser
	liquid_fill.color = dispenser.liquid_color
	liquid_mask.visible = true
	
	var tween = create_tween()
	tween.tween_property(liquid_fill, "scale:y", 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	tween.finished.connect(func():
		is_filled = true
		is_filling = false
		print("Cup filled! [Size: %s, Flavor: %s]" % [CupSize.keys()[cup_size], current_flavor])
	)

## Helper function to check cup data when serving an order
func get_drink_data() -> Dictionary:
	return {
		"size": cup_size,
		"flavor": current_flavor,
		"is_filled": is_filled
	}
