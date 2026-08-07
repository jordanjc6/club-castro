extends Area2D

@onready var mango_fill: ColorRect = $MangoFill

var is_dragging: bool = true  # with mouse
var hovered_coaster: Area2D = null  # check if hovering coaster to place down
var is_placed: bool = false  # on coaster
var is_filled: bool = false  # with drink

func _ready() -> void:
	# Listen for coaster hover events continuously
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	input_event.connect(_on_input_event)  # click on cup

func _process(_delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position()

func _input(event: InputEvent) -> void:
	# Detect mouse release while dragging
	if is_dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_check_drop()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Only allow filling IF the cup is already placed on a coaster and NOT already filled
	if not is_placed or is_filled:
		return
		
	var is_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var is_touch = event is InputEventScreenTouch and event.pressed
	
	if is_click or is_touch:
		_try_fill_mango()

func _check_drop() -> void:
	is_dragging = false
	
	if hovered_coaster != null:
		# Success! Snap cup to coaster center
		var shape_node = hovered_coaster.get_node_or_null("CollisionShape2D")
		global_position = shape_node.global_position - Vector2(0, 40)
		is_placed = true
		print("Placed on ", hovered_coaster.name)
	else:
		# Dropped outside valid area
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("coasters"):
		hovered_coaster = area

func _on_area_exited(area: Area2D) -> void:
	if area == hovered_coaster:
		hovered_coaster = null

func _try_fill_mango() -> void:
	# Look up the active dispenser in the scene tree
	var dispenser = get_tree().get_first_node_in_group("mango_dispenser")
	
	if dispenser != null and dispenser.is_active:
		mango_fill.visible = true
		is_filled = true
		print("Cup filled with Mango!")
		
		# Optional: Automatically deactivate dispenser after filling 1 cup
		# dispenser.is_active = false
		# dispenser._update_modulate()
