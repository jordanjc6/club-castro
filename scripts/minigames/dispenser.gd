class_name Dispenser
extends Area2D

enum DrinkFlavor { NONE, MANGO, MATCHA, HONEYDEW, BROWNSUGAR, TARO }

## Configure these in the Godot Inspector for each dispenser!
@export var flavor: DrinkFlavor = DrinkFlavor.MANGO
@export var liquid_color: Color = Color(1.0, 0.6, 0.0) # Mango orange/yellow

var is_active: bool = false
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Add to general dispenser group for mutual exclusion & cup checks
	add_to_group("dispenser")
	
	input_event.connect(_on_input_event)
	_update_modulate()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var is_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var is_touch = event is InputEventScreenTouch and event.pressed
	
	if is_click or is_touch:
		get_viewport().set_input_as_handled()
		
		if not is_active:
			# Deactivate ALL other dispensers before activating this one
			get_tree().call_group("dispenser", "deactivate")
			is_active = true
		else:
			# Clicking the active dispenser toggles it off
			is_active = false
			
		_update_modulate()

## Called automatically on all dispensers via call_group()
func deactivate() -> void:
	is_active = false
	_update_modulate()

func _update_modulate() -> void:
	if sprite:
		# Full opacity when active, semi-transparent when inactive
		sprite.modulate = Color(1, 1, 1, 1) if is_active else Color(1, 1, 1, 0)
