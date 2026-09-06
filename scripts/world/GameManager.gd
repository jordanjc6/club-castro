extends Node

@onready var host_button: Button = $"../HUD/SideNav/MultiplayerHUD/VBoxContainer/HostButton"
@onready var join_button: Button = $"../HUD/SideNav/MultiplayerHUD/VBoxContainer/JoinButton"


func _ready() -> void:
	host_button.pressed.connect(_host_button_pressed)
	join_button.pressed.connect(_join_button_pressed)

func _host_button_pressed():
	print("host btn")
	if await MultiplayerManager.become_host(): %HUD.hide()


func _join_button_pressed():
	print("join btn")
	var entered_code = "351938339bd044eebb1bc591d07e30f"
	if entered_code != "":
		if await MultiplayerManager.join_game(entered_code): %HUD.hide()
