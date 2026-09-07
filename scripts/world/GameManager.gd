extends Node

@onready var side_nav: HBoxContainer = $"../HUD/SideNav"
@onready var lobby_nav: HBoxContainer = $"../HUD/LobbyNav"
@onready var host_button: Button = $"../HUD/SideNav/MultiplayerHUD/VBoxContainer/HostButton"
@onready var join_button: Button = $"../HUD/SideNav/MultiplayerHUD/VBoxContainer/JoinButton"
@onready var lobby_button: Button = $"../HUD/LobbyNav/MultiplayerHUD/VBoxContainer/LobbyButton"
@onready var exit_button: Button = $"../HUD/LobbyNav/MultiplayerHUD/VBoxContainer/ExitButton"
@onready var game_notif: PanelContainer = $"../HUD/GameNotification"
@onready var loading_spinner: TextureProgressBar = $"../HUD/LoadingSpinner"


func _ready() -> void:
	host_button.pressed.connect(_host_button_pressed)
	join_button.pressed.connect(_join_button_pressed)
	lobby_button.pressed.connect(_lobby_button_pressed)
	exit_button.pressed.connect(_exit_button_pressed)
	game_notif.hide()
	loading_spinner.hide()
	
	# Listen for the disconnect signal directly from your Autoload MultiplayerManager
	MultiplayerManager.player_disconnected_notif.connect(on_player_disconnected)
	MultiplayerManager.player_reconnecting_notif.connect(on_player_reconnecting)

func _host_button_pressed():
	print("host btn")
	loading_spinner.show()
	host_button.disabled = true
	join_button.disabled = true
	if await MultiplayerManager.become_host(): 
		side_nav.hide()
		lobby_nav.show()
		show_temp_notif("Entered lobby as host!")
	else:
		host_button.disabled = false
		join_button.disabled = false
		show_temp_notif("Failed to create lobby. Check internet connection!")
	loading_spinner.hide()

func _join_button_pressed():
	print("join btn")
	var entered_code = "a95c94b8f9834fcc8009d7f53782d681"
	if entered_code != "":
		loading_spinner.show()
		host_button.disabled = true
		join_button.disabled = true
		var result = await MultiplayerManager.join_game(entered_code)
		if result.success: 
			side_nav.hide()
			lobby_nav.show()
			show_temp_notif("Joined lobby!")
		else:
			host_button.disabled = false
			join_button.disabled = false
			var text = result.message if result.message != "" else "Failed to join lobby. Check internet connection!"
			show_temp_notif(text)
		loading_spinner.hide()

func _lobby_button_pressed():
	print("lobby btn")
	# toggle show center popup with copiable lobby code

func _exit_button_pressed():
	print("exit btn")
	lobby_button.disabled = true
	exit_button.disabled = true
	loading_spinner.show()
	await MultiplayerManager._on_leave_lobby_button_pressed()
	lobby_button.disabled = false
	exit_button.disabled = false
	loading_spinner.hide()
	lobby_nav.hide()
	side_nav.show()

func on_player_disconnected(message: String):
	side_nav.show()
	lobby_nav.hide()
	host_button.disabled = false
	join_button.disabled = false
	show_temp_notif(message)

func show_temp_notif(text: String):
	# Set notif text
	var label_node: Label = game_notif.get_node("Label")
	if is_instance_valid(label_node):
		label_node.text = text
	
	# Make everything visible
	game_notif.show()
	
	# Create a clean, auto-managed timer tween
	var tween = create_tween()
	
	# Smooth fade-in or instant display, then delay for 2 seconds
	tween.tween_interval(4.0)
	
	# Safely hide everything when the 2 seconds finish
	tween.tween_callback(func():
		game_notif.hide()
	)

func on_player_reconnecting(message: String):
	show_perm_notif(message)

func show_perm_notif(text: String):
	# Set notif text
	var label_node: Label = game_notif.get_node("Label")
	if is_instance_valid(label_node):
		label_node.text = text
	
	# Make everything visible
	game_notif.show()
