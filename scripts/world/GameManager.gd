extends Node

@onready var host_button: Button = $"../HUD/SideNav/MultiplayerHUD/VBoxContainer/HostButton"
@onready var join_button: Button = $"../HUD/SideNav/MultiplayerHUD/VBoxContainer/JoinButton"

var created_joinable_lobby = false  # for host
var joined_lobby = false  # for joiners


func _ready() -> void:
	host_button.pressed.connect(_host_button_pressed)
	join_button.pressed.connect(_join_button_pressed)

func _host_button_pressed():
	print("host btn")
	%HUD.hide()
	
	created_joinable_lobby = await MultiplayerManager.become_host()


func _join_button_pressed():
	print("join btn")
	%HUD.hide()
	
	var entered_code = "f453c9dcb52f4b1a85dcca79a1fb7c48"
	if entered_code != "":
		joined_lobby = await MultiplayerManager.join_game(entered_code)
