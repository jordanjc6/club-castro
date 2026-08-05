extends HBoxContainer

@onready var multiplayer_hud: Control = $MultiplayerHUD
@onready var toggle_button: Button = $ToggleButton

var icon_open: Texture2D = preload("res://assets/icons/left-arrow.svg")
var icon_closed: Texture2D = preload("res://assets/icons/right-arrow.png")

var is_open: bool = true
var tween: Tween


func _ready() -> void:
	toggle_button.pressed.connect(_on_toggle_pressed)

func _on_toggle_pressed() -> void:
	is_open = !is_open
	
	# switch arrow icon
	toggle_button.icon = icon_open if is_open else icon_closed
	
	# Stop any running animation to prevent overlaps
	if tween and tween.is_running():
		tween.kill()
		
	tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if is_open:
		# Slide menu back into view
		tween.tween_property(multiplayer_hud, "visible", true, 0.0)
		tween.tween_property(multiplayer_hud, "modulate:a", 1.0, 0.25)
		tween.tween_property(self, "position:x", 0.0, 0.25)
	else:
		# Slide menu to the left out of view
		var hide_distance = -multiplayer_hud.size.x
		tween.tween_property(self, "position:x", hide_distance, 0.25)
		tween.tween_property(multiplayer_hud, "modulate:a", 0.0, 0.25)
