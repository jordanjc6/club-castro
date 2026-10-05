extends Control

@onready var tee_area: Area2D = $TeeArea
@onready var tee_button: Button = $TeeButton

signal tee_button_pressed(global_touch_pos: Vector2)

func _ready() -> void:
	tee_button.button_down.connect(_on_tee_button_down)

func _on_tee_button_down() -> void:
	var touch_pos = get_global_mouse_position()
	tee_button_pressed.emit(touch_pos)

# Evaluates whether the ball's Area2D is overlapping the TeeArea
func is_area_on_tee(check_area: Area2D) -> bool:
	if not is_instance_valid(check_area):
		return false
	return tee_area.overlaps_area(check_area)
