extends Node2D

@onready var prompt_area: Area2D = $"prompt-area"
@onready var prompt: PanelContainer = $Prompt
@onready var acceptPromptButton: Button = $Prompt/VBoxContainer/HBoxContainer/YesButton
@onready var rejectPromptButton: Button = $Prompt/VBoxContainer/HBoxContainer/NoButton
@onready var rodSelection: PanelContainer = $RodSelection
@onready var redBtn: Button = $RodSelection/MarginContainer/VBoxContainer/GridContainer/RedButton
@onready var orangeBtn: Button = $RodSelection/MarginContainer/VBoxContainer/GridContainer/OrangeButton
@onready var yellowBtn: Button = $RodSelection/MarginContainer/VBoxContainer/GridContainer/YellowButton
@onready var greenBtn: Button = $RodSelection/MarginContainer/VBoxContainer/GridContainer/GreenButton
@onready var blueBtn: Button = $RodSelection/MarginContainer/VBoxContainer/GridContainer/BlueButton
@onready var violetBtn: Button = $RodSelection/MarginContainer/VBoxContainer/GridContainer/VioletButton

func _ready() -> void:
	prompt_area.body_entered.connect(_prompt_area_entered)
	prompt_area.body_exited.connect(_prompt_area_exited)
	prompt.hide()
	acceptPromptButton.pressed.connect(_prompt_accepted)
	rejectPromptButton.pressed.connect(_prompt_rejected)
	rodSelection.hide()
	redBtn.pressed.connect(_rod_selected.bind(MultiplayerManager.FishingRod.RED))
	orangeBtn.pressed.connect(_rod_selected.bind(MultiplayerManager.FishingRod.ORANGE))
	yellowBtn.pressed.connect(_rod_selected.bind(MultiplayerManager.FishingRod.YELLOW))
	greenBtn.pressed.connect(_rod_selected.bind(MultiplayerManager.FishingRod.GREEN))
	blueBtn.pressed.connect(_rod_selected.bind(MultiplayerManager.FishingRod.BLUE))
	violetBtn.pressed.connect(_rod_selected.bind(MultiplayerManager.FishingRod.VIOLET))

func _prompt_area_entered(body: Node):
	var input_sync = body.get_node_or_null("InputSynchronizer")
	var isSingleplayer = body.name == "SinglePlayer"
	var isMultiplayer = (input_sync and input_sync.is_multiplayer_authority())
	
	# show popup for either game mode
	if isMultiplayer or isSingleplayer:
		print("fishing prompt area entered by %s" % body)
		prompt.show()

func _prompt_area_exited(body: Node):
	if not is_instance_valid(body) or not body.is_inside_tree():
		return
	var input_sync = body.get_node_or_null("InputSynchronizer")
	var isSingleplayer = body.name == "SinglePlayer"
	var isMultiplayer = (input_sync and input_sync.is_multiplayer_authority())
	
	# hide popup for either game mode
	if isMultiplayer or isSingleplayer:
		print("fishing prompt area exited by %s" % body)
		prompt.hide()
		rodSelection.hide()

func _prompt_accepted():
	prompt.hide()
	rodSelection.show()

func _prompt_rejected():
	prompt.hide()

func _rod_selected(rod: MultiplayerManager.FishingRod):
	var world_scene = get_tree().get_current_scene()
	var single_player = world_scene.get_node_or_null("SinglePlayer")
	
	# multiplayer
	if single_player == null and multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		MultiplayerManager.rpc("request_equip_rod", rod)
	# singleplayer
	else:
		if is_instance_valid(single_player) and single_player.has_method("equip_rod_visual"):
			single_player.equip_rod_visual(rod)
	rodSelection.hide()
