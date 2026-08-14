extends Area2D

enum Topping { TAPIOCA, POPPING_BOBA, GRASS_JELLY, PUDDING }

@export var topping_type: Topping = Topping.TAPIOCA

var is_dragging: bool = true
var hovered_cup: Area2D = null


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _process(_delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position()

func _input(event: InputEvent) -> void:
	if is_dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_check_drop()

func _check_drop() -> void:
	is_dragging = false
	
	# Check if dropped onto a valid cup hovering underneath
	if hovered_cup != null and hovered_cup.has_method("add_topping"):
		hovered_cup.add_topping(topping_type)
		#print("Ice added to ", hovered_cup.name)
	else:
		print("%s dropped in empty space" % topping_type)
	
	# Delete the spoon after one drop attempt
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("cups"):
		hovered_cup = area

func _on_area_exited(area: Area2D) -> void:
	if area == hovered_cup:
		hovered_cup = null
