extends Area2D

enum CupSize { SMALL, MEDIUM, LARGE }
@export var cup_size: CupSize = CupSize.MEDIUM

@onready var liquid_fill: ColorRect = $MangoFill/ColorRect
@onready var liquid_mask: Polygon2D = $MangoFill

var is_dragging: bool = true  # with mouse
var hovered_coaster: Area2D = null  # check if hovering coaster to place down
var is_placed: bool = false  # on coaster
var is_filled: bool = false  # with drink
var is_filling: bool = false # Prevents double-clicking during animation
var current_coaster: Coaster = null  # Track where this cup is placed
var offset: Vector2 = Vector2.INF

func _ready() -> void:
	match cup_size:
		CupSize.SMALL:
			offset = Vector2(0, 40)
		CupSize.MEDIUM:
			offset = Vector2(0, 52)
		CupSize.LARGE:
			offset = Vector2(0, 49)
	
	# Listen for coaster hover events continuously
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	input_event.connect(_on_input_event)  # click on cup
	
	# Start with the liquid completely squished to the bottom (invisible)
	liquid_fill.scale.y = 0.0
	liquid_mask.visible = false

func _exit_tree() -> void:
	# Automatically frees up the coaster when the cup is deleted or sent
	if current_coaster != null and is_instance_valid(current_coaster):
		current_coaster.remove_cup()

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
	
	if hovered_coaster != null and hovered_coaster.is_empty():
		current_coaster = hovered_coaster
		current_coaster.place_cup(self)
		# Success! Snap cup to coaster center
		var shape_node = hovered_coaster.get_node_or_null("CollisionShape2D")
		global_position = shape_node.global_position - offset
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
	if is_filling:
		return
		
	# Look up the active dispenser in the scene tree
	var dispenser = get_tree().get_first_node_in_group("mango_dispenser")
	
	if dispenser != null and dispenser.is_active:
		is_filling = true
		liquid_mask.visible = true
		
		# Create a smooth bottom-to-top pouring animation over 1.2 seconds
		var tween = create_tween()
		tween.tween_property(liquid_fill, "scale:y", 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		# When animation finishes, mark cup as completely filled
		tween.finished.connect(func():
			is_filled = true
			is_filling = false
			print("Cup fully filled with Mango!")
		)
