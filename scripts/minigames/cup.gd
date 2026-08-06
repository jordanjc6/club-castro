extends Area2D

var is_dragging: bool = true
var hovered_coaster: Area2D = null

func _ready() -> void:
	# Listen for coaster hover events continuously
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _process(_delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position()

func _input(event: InputEvent) -> void:
	# Detect mouse release while dragging
	if is_dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_check_drop()

func _check_drop() -> void:
	is_dragging = false
	
	if hovered_coaster != null:
		# Success! Snap cup to coaster center
		var shape_node = hovered_coaster.get_node_or_null("CollisionShape2D")
		global_position = shape_node.global_position - Vector2(0, 40)
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
