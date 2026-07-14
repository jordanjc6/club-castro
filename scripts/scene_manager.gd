extends Node

# A reference to the overlay canvas used for fading
var fade_layer: CanvasLayer
var fade_rect: ColorRect

func _ready() -> void:
	# Programmatically create a persistent black screen overlay for transitions
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 100 # Put it on top of everything else
	
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.modulate.a = 0.0 # Start completely invisible
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE # Don't block clicks
	
	fade_layer.add_child(fade_rect)
	add_child(fade_layer)

func switch_scene(target_scene_path: String) -> void:
	var tween = create_tween()
	
	# 1. Fade the screen to black
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.4)
	
	# 2. Swap the scene behind the black screen
	tween.tween_callback(func(): 
		get_tree().change_scene_to_file(target_scene_path)
	)
	
	# 3. Fade back to transparent
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.4)
	
func show_prompt_popup(table):
	var popup = preload("res://scenes/minigame_prompt_popup.tscn").instantiate()
	popup.table = table
	get_tree().current_scene.add_child(popup)
	
func show_waiting_popup(table):
	var popup = preload("res://scenes/minigame_waiting_popup.tscn").instantiate()
	popup.table = table
	get_tree().current_scene.add_child(popup)
	popup.update_players()
	return popup
