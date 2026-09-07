extends TextureProgressBar

var rotation_tween: Tween

func _ready() -> void:
	# Connect Godot's built-in CanvasItem visibility signal
	visibility_changed.connect(_on_visibility_changed)
	
	# Match tween state to initial node visibility immediately on load
	_on_visibility_changed()

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_start_animating()
	else:
		_stop_animating()

func _start_animating() -> void:
	# Ensure any leftover tween is cleaned up first
	_stop_animating()
	
	# Create and start a looping angle rotation
	rotation_tween = get_tree().create_tween().set_loops()
	rotation_tween.tween_property(self, "radial_initial_angle", 360.0, 1.5).as_relative()

func _stop_animating() -> void:
	if rotation_tween and rotation_tween.is_valid():
		rotation_tween.kill() # Instantly stops processing on hidden
