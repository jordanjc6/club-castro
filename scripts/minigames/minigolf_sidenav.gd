extends HBoxContainer

@onready var multiplayer_hud: Control = $MultiplayerHUD
@onready var side_nav: HBoxContainer = self
@onready var toggle_button: Button = $ToggleButton

var icon_open: Texture2D = preload("res://assets/icons/left-arrow.svg")
var icon_closed: Texture2D = preload("res://assets/icons/right-arrow.png")

var is_open: bool = false
var tween: Tween

var open_y: float = 0.0

func _ready() -> void:
	side_nav.visible = true
	toggle_button.pressed.connect(_on_toggle_pressed)
	
	toggle_button.pivot_offset = toggle_button.size / 2.0
	toggle_button.icon = icon_closed
	
	# Wait for layout pass so sizes are calculated
	await get_tree().process_frame
	
	open_y = side_nav.position.y
	
	# Compute closed position
	var hud_height = multiplayer_hud.size.y if multiplayer_hud.size.y > 0 else multiplayer_hud.size.x
	hud_height += 40
	var hide_distance = open_y - (hud_height + toggle_button.position.y)
	
	# Set starting state without triggering animation desyncs
	side_nav.position.y = hide_distance
	multiplayer_hud.modulate.a = 0.0

func _on_toggle_pressed() -> void:
	is_open = !is_open
	
	toggle_button.icon = icon_open if is_open else icon_closed
	
	if tween and tween.is_running():
		tween.kill()
		
	tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if is_open:
		# Slide menu down into view
		tween.tween_property(multiplayer_hud, "visible", true, 0.0)
		tween.tween_property(multiplayer_hud, "modulate:a", 1.0, 0.25)
		tween.tween_property(self, "position:y", open_y, 0.25)
	else:
		# Slide menu up flush with edge
		var hud_height = multiplayer_hud.size.y if multiplayer_hud.size.y > 0 else multiplayer_hud.size.x
		hud_height += 40
		var hide_distance = open_y - (hud_height + toggle_button.position.y)
		tween.tween_property(self, "position:y", hide_distance, 0.25)
		tween.tween_property(multiplayer_hud, "modulate:a", 0.0, 0.25)
