extends Node2D

@onready var interaction_area: Area2D = $InteractionArea
@onready var popup: PanelContainer = $Popup
@onready var equip_button: Button = $Popup/PanelContainer/VBoxContainer/HBoxContainer/Equip
@onready var leave_it_button: Button = $Popup/PanelContainer/VBoxContainer/HBoxContainer/LeaveIt

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	popup.hide()
	interaction_area.body_entered.connect(_interaction_area_entered)
	interaction_area.body_exited.connect(_interaction_area_exited)
	equip_button.pressed.connect(_on_equip_button_pressed)
	leave_it_button.pressed.connect(_on_leave_it_button_pressed)

# show local game prompt upon entering game area
#
func _interaction_area_entered(body: Node) -> void:
	pass
	# show popup
	
	#var input_sync = body.get_node_or_null("InputSynchronizer")
		#
	## only show popup for the player that entered
	#if ( (input_sync and input_sync.is_multiplayer_authority()) or body.name == "SinglePlayer"):
		#print("game area entered by %s" % body)
		#game_prompt_panel.visible = true
		#game_result_panel.visible = false
	#
	#if (input_sync and input_sync.is_multiplayer_authority()):
		## Guard: Skip showing prompt if the local player is currently in a Tag match
		#if MultiplayerManager.is_player_in_tag_game(body.player_id):
			#return
		#hud.get_node("LobbyNav").visible = false
		#hud.get_node("LobbyPopup").visible = false
		#hud.get_node("MinigamesPopup").visible = false
		#hud.get_node("LobbyNav/MultiplayerHUD/VBoxContainer/MinigamesButton").disabled = false
		#hud.get_node("LobbyNav/MultiplayerHUD/VBoxContainer/ExitButton").disabled = false
	#elif body.name == "SinglePlayer":
		#hud.get_node("SideNav").visible = false
		#hud.get_node("JoinPopup").visible = false
		#hud.get_node("SideNav/MultiplayerHUD/VBoxContainer/HostButton").disabled = false

func _interaction_area_exited(body: Node) -> void:
	pass
	# hide popup
	
	#if not is_instance_valid(body) or not body.is_inside_tree():
		#return
	#
	#var input_sync = body.get_node_or_null("InputSynchronizer")
	#
	## Check is_inside_tree on input_sync before accessing multiplayer authority
	#var is_local_mp = input_sync and input_sync.is_inside_tree() and input_sync.is_multiplayer_authority()
	#var is_local_sp = body.name == "SinglePlayer"
	#
	#if is_local_mp or is_local_sp:
		#print("game area exited by %s" % body)
		#game_prompt_panel.visible = false
		#if game_window.visible:
			#_on_cancel_button_pressed()
	#
	#if is_local_mp:
		## Guard: Skip showing prompt if the local player is currently in a Tag match
		#if MultiplayerManager.is_player_in_tag_game(body.player_id):
			#return
		#if hud.has_node("LobbyNav"):
			#hud.get_node("LobbyNav").visible = true
	#elif is_local_sp:
		#if hud.has_node("SideNav"):
			#hud.get_node("SideNav").visible = true

func _on_equip_button_pressed():
	pass
	# equip item...

func _on_leave_it_button_pressed():
	pass
	# hide popup
