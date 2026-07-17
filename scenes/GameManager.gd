extends Node


func _host_button_pressed():
	print("host btn")
	%MultiplayerHUD.hide()
	MultiplayerManager.become_host()


func _join_button_pressed():
	print("join btn")
	%MultiplayerHUD.hide()
	MultiplayerManager.join_game()
