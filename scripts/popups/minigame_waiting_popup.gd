extends Control

var table

func update_players():
	print("update players")
	if table.players.size() > 0:
		$Panel/VBoxContainer/Player1.text = str(table.players[0])
	else:
		$Panel/VBoxContainer/Player1.text = "Waiting..."

	if table.players.size() > 1:
		$Panel/VBoxContainer/Player2.text = str(table.players[1])
	else:
		$Panel/VBoxContainer/Player2.text = "Waiting..."

func _on_cancel_button_pressed() -> void:
	print("close waiting popup")
	table.leave_game(multiplayer.get_unique_id())
	table.close_lobby()
	queue_free()
