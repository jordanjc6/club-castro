extends Control

const MAC_IP = "192.168.2.23"
const DELL_IP = "192.168.2.10"
const JINA_MAC_IP = "10.0.0.249"
const GAME_SCENE = "res://scenes/jungle_plaza.tscn"

func _on_host_button_pressed():
	print("host btn pressed")
	NetworkManager.host_game()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_join_button_pressed():
	print("join btn pressed")
	NetworkManager.join_game(MAC_IP)
	get_tree().change_scene_to_file(GAME_SCENE)
