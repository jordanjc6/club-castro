extends Node2D

@onready var sprite: Sprite2D = $Sprite2D # Or whatever node represents the visual circle
var bob_tween: Tween

func setup_lure(color: Color) -> void:
	if is_instance_valid(sprite):
		sprite.modulate = color

func on_land_in_water() -> void:
	var target_y = global_position.y
	bob_tween = create_tween().set_loops()
	bob_tween.tween_property(self, "global_position:y", target_y - 3.0, 0.8).set_trans(Tween.TRANS_SINE)
	bob_tween.tween_property(self, "global_position:y", target_y + 3.0, 0.8).set_trans(Tween.TRANS_SINE)

func kill_tweens() -> void:
	if is_instance_valid(bob_tween) and bob_tween.is_valid():
		bob_tween.kill()
