extends Area2D

@onready var sprite: Sprite2D = $Sprite2D

# Tracks whether the dispenser is currently toggled on or off
var is_active: bool = false

func _ready() -> void:
	# Register into group so Cup scripts can find this dispenser easily
	add_to_group("mango_dispenser")
	
	# Connect the Area2D click/touch detection signal
	input_event.connect(_on_input_event)
	
	# Set starting state (e.g., fully visible by default)
	_update_modulate()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Detect left mouse click OR touch screen press
	var is_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var is_touch = event is InputEventScreenTouch and event.pressed
	
	if is_click or is_touch:
		is_active = !is_active
		print("Clicked mango dispenser (active: %s)" % is_active)
		_update_modulate()

func _update_modulate() -> void:
	if is_active:
		# Maximum brightness / full opacity
		sprite.modulate = Color(1, 1, 1, 1)
	else:
		# Modulate to 0 (completely transparent)
		sprite.modulate = Color(1, 1, 1, 0)
