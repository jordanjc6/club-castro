extends LineEdit

var _press_timer: Timer
var _last_touch_pos: Vector2 = Vector2.ZERO
var _paste_popup: Button


func _ready() -> void:
	# 1. Setup the long-press detection timer (0.4 seconds)
	_press_timer = Timer.new()
	_press_timer.one_shot = true
	_press_timer.wait_time = 0.4
	_press_timer.timeout.connect(_on_long_press_detected)
	add_child(_press_timer)

	# 2. Setup the floating "Paste" Callout Button with larger dimensions
	_paste_popup = Button.new()
	_paste_popup.text = "Paste"
	_paste_popup.visible = false
	_paste_popup.top_level = true # Renders above all UI nodes
	
	# Increase size via custom minimum size and larger font size
	_paste_popup.custom_minimum_size = Vector2(100, 60)
	_paste_popup.add_theme_font_size_override("font_size", 30)
	
	_paste_popup.pressed.connect(_on_paste_pressed)
	add_child(_paste_popup)


func _gui_input(event: InputEvent) -> void:
	var is_press := false
	var is_release := false
	var touch_pos := Vector2.ZERO

	if event is InputEventScreenTouch:
		is_press = event.pressed
		is_release = not event.pressed
		touch_pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_press = event.pressed
		is_release = not event.pressed
		touch_pos = event.position

	if is_press:
		_last_touch_pos = touch_pos
		_press_timer.start()
	elif is_release:
		_press_timer.stop()

	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _press_timer.time_left > 0:
		if event.position.distance_to(_last_touch_pos) > 10.0:
			_press_timer.stop()


func _on_long_press_detected() -> void:
	if DisplayServer.clipboard_has():
		var global_touch_pos = global_position + _last_touch_pos
		# Center the wider button above the touch point
		_paste_popup.global_position = global_touch_pos + Vector2(-45, -55)
		_paste_popup.visible = true


func _on_paste_pressed() -> void:
	text = DisplayServer.clipboard_get()
	caret_column = text.length()
	_paste_popup.visible = false
	text_changed.emit(text)


func _input(event: InputEvent) -> void:
	# Catch taps/clicks anywhere on screen BEFORE containers block them
	if _paste_popup.visible:
		var is_click := false
		var click_pos := Vector2.ZERO

		if event is InputEventScreenTouch and event.pressed:
			is_click = true
			click_pos = event.position
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			is_click = true
			click_pos = event.position

		if is_click:
			# Only hide if the click was NOT directly on the paste button itself
			if not _paste_popup.get_global_rect().has_point(click_pos):
				_paste_popup.visible = false
