extends PanelContainer

@onready var game_manager: Node = $"../../../GameManager"

# multiplayer lobby nav
@onready var lobby_nav: HBoxContainer = $"../../LobbyNav"
@onready var lobby_button: Button = $"../../LobbyNav/MultiplayerHUD/VBoxContainer/LobbyButton"
@onready var minigames_button: Button = $"../../LobbyNav/MultiplayerHUD/VBoxContainer/MinigamesButton"
@onready var exit_button: Button = $"../../LobbyNav/MultiplayerHUD/VBoxContainer/ExitButton"
@onready var lobby_popup: PanelContainer = $"../../LobbyPopup"

# minigames popup
@onready var minigames_popup: Node2D = get_parent()
@onready var minigames_mainmenu: PanelContainer = $"../MainMenu"
@onready var tag_button: Button = $"../MainMenu/MarginContainer/VBoxContainer/HBoxContainer/TagButton"
@onready var minigolf_button: Button = $"../MainMenu/MarginContainer/VBoxContainer/HBoxContainer/MinigolfButton"

# tag menu
@onready var minigames_tagmenu: PanelContainer = $"../TagMenu"

# minigolf menu
@onready var minigolf_menu: PanelContainer = self
@onready var minigolf_invite_button: Button = $"MarginContainer/VBoxContainer/Header/HBoxContainer/InviteButton"
@onready var minigolf_menu_close_button: Button = $"MarginContainer/VBoxContainer/Header/HBoxContainer/CloseMinigolfMenuButton"
@onready var minigolf_start_button: Button = $"MarginContainer/VBoxContainer/Footer/StartGameButton"
@onready var minigolf_players_grid: GridContainer = $"MarginContainer/VBoxContainer/Players"

# other
@onready var game_notif: PanelContainer = $"../../GameNotification"
var _notif_tween: Tween = null
@onready var join_tag_button: Button = $"../../GameNotification/MarginContainer/VBoxContainer/JoinTagButton"
@onready var join_minigolf_button: Button = $"../../GameNotification/MarginContainer/VBoxContainer/JoinMinigolfButton"
@onready var loading_spinner: TextureProgressBar = $"../../LoadingSpinner"

# style constants
const COLOR_BROWN = Color("3d251e")
const COLOR_GOLD = Color("ffd700")  
const DEFAULT_NAMETAG_COLOR = Color("0000003c")
const ROULETTE_BORDER_WIDTH = 8

# minigolf minigame 
var minigolf_players: Array[int] = []  # store participants and turn order
const PLAYER_TAG_BG_COLOR: Color = COLOR_BROWN

func _ready() -> void:
	game_manager.minigames_button_pressed.connect(on_minigames_button_pressed)
	MultiplayerManager.player_left_multiplayer_lobby.connect(remove_minigolf_player)
	MultiplayerManager.player_disconnected_notif.connect(reset_state_for_single_player_return)
	minigolf_menu.hide()
	minigolf_button.pressed.connect(minigolf_button_pressed)
	minigolf_menu_close_button.pressed.connect(minigolf_close_pressed)
	minigolf_invite_button.pressed.connect(minigolf_invite_pressed)
	join_minigolf_button.pressed.connect(accept_minigolf_invite)
	minigolf_start_button.pressed.connect(minigolf_start_pressed)

func on_minigames_button_pressed(by_player_id: int):
	close_minigolf_menu()
	if minigolf_players.has(by_player_id):
		rpc("remove_minigolf_player", by_player_id)

func close_minigolf_menu():
	minigolf_menu.hide()

func enable_lobby_nav_buttons():
	lobby_button.disabled = false
	minigames_button.disabled = false
	exit_button.disabled = false

func hide_minigames_popups():
	minigames_popup.hide()
	minigames_mainmenu.hide()

@rpc("any_peer", "call_local", "reliable")
func remove_minigolf_player(id: int) -> void:
	if multiplayer.is_server():
		minigolf_players.erase(id)
		rpc("sync_minigolf_lobby_ui", minigolf_players)
		check_remaining_players()

func check_remaining_players():
	if minigolf_players.is_empty():
		reset_minigolf_state()

func reset_minigolf_state():
	if multiplayer.is_server():
		minigolf_players.clear()
		MultiplayerManager.rpc("set_minigolf_started", false)
		rpc("sync_minigolf_lobby_ui", minigolf_players)

func reset_state_for_single_player_return():
	minigolf_menu.hide()
	reset_minigolf_state()

func minigolf_button_pressed():
	print("minigolf btn")
	if MultiplayerManager.is_minigolf_minigame_started:
		game_manager.show_temp_notif("A Minigolf game is currently in progress!")
		return
	minigames_mainmenu.hide()
	minigolf_menu.show()
	rpc("add_minigolf_player", multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "reliable")
func add_minigolf_player(peer_id: int) -> void:
	if multiplayer.is_server():
		if not minigolf_players.has(peer_id):
			minigolf_players.append(peer_id)
			rpc("sync_minigolf_lobby_ui", minigolf_players)

@rpc("authority", "call_local", "reliable")
func sync_minigolf_lobby_ui(players: Array[int]) -> void:
	minigolf_players = players
	var labels = minigolf_players_grid.get_children()
	for i in range(labels.size()):
		if i < players.size():
			var peer_id = players[i]
			labels[i].text = MultiplayerManager.get_player_name(peer_id)
			style_player_tag(labels[i])
		else:
			labels[i].text = "Waiting..."
			labels[i].remove_theme_stylebox_override("normal")
			labels[i].remove_theme_color_override("font_color")
			
			var stylebox = create_stylebox(DEFAULT_NAMETAG_COLOR)
			labels[i].add_theme_stylebox_override("normal", stylebox)
			labels[i].add_theme_color_override("font_color", "FFFFFF")

func style_player_tag(label_node: Label, border_color: Color = Color.TRANSPARENT, border_width: int = 0, font_color: Color = Color.TRANSPARENT) -> void:
	if is_instance_valid(label_node):
		var stylebox = create_stylebox(PLAYER_TAG_BG_COLOR, border_color, border_width)
		label_node.add_theme_stylebox_override("normal", stylebox)
		if font_color != Color.TRANSPARENT:
			label_node.add_theme_color_override("font_color", font_color)
		else:
			label_node.remove_theme_color_override("font_color")

func create_stylebox(bg_color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = bg_color
	if border_width > 0:
		stylebox.border_color = border_color
		stylebox.set_border_width_all(border_width)
	stylebox.corner_radius_top_left = 50
	stylebox.corner_radius_top_right = 50
	stylebox.corner_radius_bottom_left = 50
	stylebox.corner_radius_bottom_right = 50
	return stylebox

func minigolf_close_pressed():
	print("minigolf close btn")
	close_minigolf_menu()
	enable_lobby_nav_buttons()
	hide_minigames_popups()
	rpc("remove_minigolf_player", multiplayer.get_unique_id())

func minigolf_invite_pressed():
	print("invite to play")
	if not all_players_in_minigolf():
		rpc("send_minigolf_invite")
		game_manager.show_temp_notif("Sent invites to unjoined players!", 2)
	else:
		game_manager.show_temp_notif("All players in the lobby have already joined!", 2)

func all_players_in_minigolf() -> bool:
	var active_peers: Array[int] = []
	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		active_peers.append(1) # Include Host
		active_peers.append_array(multiplayer.get_peers()) # Include connected clients
	else:
		# Fallback for local/offline testing: local peer ID (usually 1)
		active_peers.append(multiplayer.get_unique_id())

	if active_peers.is_empty():
		return true
	for peer_id in active_peers:
		if not minigolf_players.has(peer_id):
			return false
	return true

@rpc("any_peer", "call_local", "reliable")
func send_minigolf_invite() -> void:
	if not multiplayer.is_server():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	var sender_name = MultiplayerManager.get_player_name(sender_id)
	var recipients = multiplayer.get_peers()
	if sender_id != 1:
		recipients.append(1) # Include host if joiner sent the invite
	
	for peer_id in recipients:
		if peer_id != sender_id and not minigolf_players.has(peer_id):
			if peer_id == 1:
				# Local host execution
				receive_minigolf_invite(sender_name)
			else:
				# Remote client RPC
				rpc_id(peer_id, "receive_minigolf_invite", sender_name)

@rpc("authority", "call_local", "reliable")
func receive_minigolf_invite(sender_name: String) -> void:
	game_manager.show_temp_notif("%s invited you to play Minigolf!" % sender_name, 4, false, true)

func accept_minigolf_invite():
	game_notif.hide()
	if MultiplayerManager.is_minigolf_minigame_started:
		game_manager.show_temp_notif("A Minigolf game is currently in progress!")
		return
	rpc("add_minigolf_player", multiplayer.get_unique_id())
	
	# update ui
	lobby_button.disabled = true
	exit_button.disabled = true
	minigames_button.disabled = false
	minigames_popup.show()
	minigames_mainmenu.hide()
	minigames_tagmenu.hide()
	minigolf_menu.show()
	lobby_popup.hide()
	
	# remove player from tag lobby if they were in it
	var my_id = multiplayer.get_unique_id()
	if MultiplayerManager.joined_tag_peers.has(my_id):
		MultiplayerManager.rpc("unregister_tag_player", my_id)
		game_manager.reset_tag_player_colors

func minigolf_start_pressed():
	rpc("request_start_minigolf")

@rpc("any_peer", "call_local", "reliable")
func request_start_minigolf() -> void:
	if multiplayer.is_server():
		MultiplayerManager.rpc("set_minigolf_started", true)
		randomize_minigolf_turn_order()
		rpc("set_minigolf_ui")
		teleport_players_to_minigolf()
		await get_tree().create_timer(5).timeout
		disable_player_movement()

func randomize_minigolf_turn_order():
	minigolf_players.shuffle()

@rpc("authority", "call_local", "reliable")
func set_minigolf_ui() -> void:
	lobby_nav.hide()
	minigolf_menu.hide()
	for player in get_tree().get_nodes_in_group("player"):
		player.hide()

func teleport_players_to_minigolf() -> void:
	if not multiplayer.is_server():
		return
	var new_zone_offset = Vector2(0, 950)
	var target_position = Vector2(250, 1200)
	for player in get_tree().get_nodes_in_group("player"):
		player.update_zone_offset.rpc_id(player.player_id, new_zone_offset)
		player.global_position = target_position
		player.hide()
		lobby_nav.hide()

func disable_player_movement():
	for player in get_tree().get_nodes_in_group("player"):
		player.set_movement_disabled.rpc(true)
