extends Control

var table


func close_popup():
	print("close prompt")
	table.prompt_open = false
	queue_free()

func _on_yes_button_pressed():
	table.join_game(multiplayer.get_unique_id())
	close_popup()

func _on_no_button_pressed():
	close_popup()
