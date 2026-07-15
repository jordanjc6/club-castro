extends Control


func _on_host_button_pressed():
	print("host btn pressed")
	NetworkManager.host_game()


func _on_join_button_pressed():
	print("join btn pressed")
	NetworkManager.join_game("192.168.1.25")
