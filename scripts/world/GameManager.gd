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
	
	# Polling briefly until the async lobby creation completes and yields a code
	var attempts = 0
	while attempts < 20:
		await get_tree().create_timer(0.25).timeout
		var code = MultiplayerManager.get_active_lobby_code()
		if code != "":
			print("Lobby Code: %s" % code)
			return
		attempts += 1
		
	print("Failed to fetch lobby code.")


func _join_button_pressed():
	print("join btn")
	%HUD.hide()
	#MultiplayerManager.join_game()
	
	var entered_code = "b6d16cf9149b48b19e60ec7e8bc5b7a4"
	if entered_code != "":
		MultiplayerManager.join_game(entered_code)
