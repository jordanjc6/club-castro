extends Control

var table


func _on_yes_button_pressed():
	table.join_game(multiplayer.get_unique_id())
	queue_free()

func _on_no_button_pressed():
	queue_free()
