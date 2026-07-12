extends Node2D

func _on_gameseat_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		SceneManager.show_play_popup(self)
		
func join_game(player_id):
	print(player_id, " joined the table")
