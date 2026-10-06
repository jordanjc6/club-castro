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
	if not is_instance_valid(check_area) or not is_instance_valid(tee_area):
		return false
		
	var tee_shape: CollisionShape2D = tee_area.get_node_or_null("CollisionShape2D")
	var ball_shape: CollisionShape2D = check_area.get_node_or_null("CollisionShape2D")
	
	if tee_shape == null or ball_shape == null:
		return false
		
	# Simple geometric overlap check between global positions
	var tee_rect = Rect2(
		tee_shape.global_position - (tee_shape.shape.size / 2.0),
		tee_shape.shape.size
	)
	
	return tee_rect.has_point(check_area.global_position)
