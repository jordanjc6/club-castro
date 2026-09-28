extends Node2D

@onready var interaction_area: Area2D = $InteractionArea
@onready var popup: CanvasLayer = $Popup
@onready var equip_button: Button = $Popup/PanelContainer/VBoxContainer/HBoxContainer/Equip
@onready var leave_it_button: Button = $Popup/PanelContainer/VBoxContainer/HBoxContainer/LeaveIt

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	popup.hide()
	interaction_area.body_entered.connect(_interaction_area_entered)
	interaction_area.body_exited.connect(_interaction_area_exited)
	equip_button.pressed.connect(_on_equip_button_pressed)
	leave_it_button.pressed.connect(_on_leave_it_button_pressed)

func _interaction_area_entered(body: Node) -> void:
	print("interaction area entered")
	var input_sync = body.get_node_or_null("InputSynchronizer")
	var is_local_player = input_sync.is_multiplayer_authority() if is_instance_valid(input_sync) else true
	if is_local_player:
		popup.show()

func _interaction_area_exited(body: Node) -> void:
	print("interaction area exited")
	if not is_instance_valid(body) or not body.is_inside_tree():
		return
	var input_sync = body.get_node_or_null("InputSynchronizer")
	var is_local_player = input_sync.is_multiplayer_authority() if is_instance_valid(input_sync) else true
	if is_local_player:
		popup.hide()

func _on_equip_button_pressed():
	print("equip btn pressed")
	var world_scene = get_tree().get_current_scene()
	var single_player = world_scene.get_node_or_null("SinglePlayer")
	
	# multiplayer
	if single_player == null and multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		MultiplayerManager.rpc("request_equip_accessory", "jina_bow")
	# singleplayer
	else:
		if is_instance_valid(single_player) and single_player.has_method("equip_jina_bow"):
			single_player.equip_jina_bow()
	popup.hide()

func _on_leave_it_button_pressed():
	print("leave it btn pressed")
	var world_scene = get_tree().get_current_scene()
	var single_player = world_scene.get_node_or_null("SinglePlayer")
	
	# multiplayer
	if single_player == null and multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		MultiplayerManager.rpc("request_equip_accessory", "")
	# singleplayer
	else:
		if is_instance_valid(single_player) and single_player.has_method("equip_jina_bow"):
			single_player.unequip_jina_bow()
	popup.hide()
