extends Area2D

@export_file("*.tscn") var target_room: String

func _on_body_entered(body: Node2D) -> void:
	# Ensure the thing touching the door is actually the player
	if body is CharacterBody2D and target_room != "":
		SceneManager.switch_scene(target_room)
