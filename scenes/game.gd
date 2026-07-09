extends Node2D

@onready var background: TextureRect = $CanvasLayer/TextureRect

#const BBT_BACKGROUND = preload("res://assets/backgrounds/background-jungle-plaza.png")
const BBT_BACKGROUND = preload("res://assets/monkey-sprites/designs/monkey-sprite-sheet.png")
var fade_tween: Tween # hold fade animation

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_bbt_entrance(body: Node2D) -> void:
	if body is CharacterBody2D:
		trigger_fade_transition(BBT_BACKGROUND)
	
func trigger_fade_transition(new_texture: Texture2D) -> void:
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
		
	fade_tween = create_tween()
	
	# Fade out over 0.4 seconds
	fade_tween.tween_property(background, "modulate:a", 0.0, 0.4)
	
	# Swap texture while invisible
	fade_tween.tween_callback(func(): background.texture = new_texture)
	
	# Fade back in over 0.4 seconds
	fade_tween.tween_property(background, "modulate:a", 1.0, 0.4)
