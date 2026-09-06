extends Node

@onready var host_button: Button = $"../HUD/SideNav/MultiplayerHUD/VBoxContainer/HostButton"
@onready var join_button: Button = $"../HUD/SideNav/MultiplayerHUD/VBoxContainer/JoinButton"
@onready var game_notif: PanelContainer = $"../HUD/GameNotification"


func _ready() -> void:
	host_button.pressed.connect(_host_button_pressed)
	join_button.pressed.connect(_join_button_pressed)
	game_notif.hide()
	
	# Listen for the disconnect signal directly from your Autoload MultiplayerManager
	MultiplayerManager.player_disconnected_notif.connect(show_temp_disconnect_notif)

func _host_button_pressed():
	print("host btn")
	host_button.disabled = true
	join_button.disabled = true
	if await MultiplayerManager.become_host(): %HUD.hide()
	else: 
		host_button.disabled = false
		join_button.disabled = false

func _join_button_pressed():
	print("join btn")
	host_button.disabled = true
	join_button.disabled = true
	var entered_code = "090364c5f3254476a2e9f0f4451bb83b"
	if entered_code != "":
		if await MultiplayerManager.join_game(entered_code): %HUD.hide()
		else:
			host_button.disabled = false
			join_button.disabled = false

func show_temp_disconnect_notif():
	%HUD.show()
	host_button.disabled = false
	join_button.disabled = false
	
	# 1. Make everything visible
	game_notif.show()
	
	# 2. Create a clean, auto-managed timer tween
	var tween = create_tween()
	
	# Optional: Smooth fade-in or instant display, then delay for 2 seconds
	tween.tween_interval(3.0)
	
	# 3. Safely hide everything when the 2 seconds finish
	tween.tween_callback(func():
		game_notif.hide()
	)
