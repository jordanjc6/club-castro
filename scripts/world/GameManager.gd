extends Node

@onready var host_button: Button = $"../HUD/SideNav/MultiplayerHUD/VBoxContainer/HostButton"
@onready var join_button: Button = $"../HUD/SideNav/MultiplayerHUD/VBoxContainer/JoinButton"


func _ready() -> void:
	host_button.pressed.connect(_host_button_pressed)
	join_button.pressed.connect(_join_button_pressed)

func _host_button_pressed():
	print("host btn")
	%HUD.hide()
	MultiplayerManager.become_host()


func _join_button_pressed():
	print("join btn")
	%HUD.hide()
	MultiplayerManager.join_game()
