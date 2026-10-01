extends PanelContainer

@onready var game_manager: Node = $"../../../GameManager"

# single player sidenav
@onready var side_nav: HBoxContainer = $"../../SideNav"
@onready var host_button: Button = $"../../SideNav/MultiplayerHUD/VBoxContainer/HostButton"
@onready var join_button: Button = $"../../SideNav/MultiplayerHUD/VBoxContainer/JoinButton"
@onready var join_popup: PanelContainer = $"../../JoinPopup"
@onready var find_button: Button = $"../../JoinPopup/VBoxContainer/FindButton"

# multiplayer lobby nav
@onready var lobby_nav: HBoxContainer = $"../../LobbyNav"
@onready var lobby_button: Button = $"../../LobbyNav/MultiplayerHUD/VBoxContainer/LobbyButton"
@onready var minigames_button: Button = $"../../LobbyNav/MultiplayerHUD/VBoxContainer/MinigamesButton"
@onready var exit_button: Button = $"../../LobbyNav/MultiplayerHUD/VBoxContainer/ExitButton"
@onready var lobby_popup: PanelContainer = $"../../LobbyPopup"
@onready var copy_button: Button = $"../../LobbyPopup/VBoxContainer/CopyButton"

# tag minigame nav
@onready var tag_nav: HBoxContainer = $"../../TagNav"
@onready var leave_tag_button: Button = $"../../TagNav/MultiplayerHUD/VBoxContainer/LeaveGameButton"

# minigames popup
@onready var minigames_popup: Node2D = get_parent()
@onready var minigames_mainmenu: PanelContainer = $"../MainMenu"
@onready var tag_button: Button = $"../MainMenu/MarginContainer/VBoxContainer/HBoxContainer/TagButton"
@onready var minigolf_button: Button = $"../MainMenu/MarginContainer/VBoxContainer/HBoxContainer/MinigolfButton"

# tag menu
@onready var minigames_tagmenu: PanelContainer = $"../TagMenu"
@onready var tag_invite_button: Button = $"../TagMenu/MarginContainer/VBoxContainer/Header/HBoxContainer/InviteButton"
@onready var tag_menu_close_button: Button = $"../TagMenu/MarginContainer/VBoxContainer/Header/HBoxContainer/CloseTagMenuButton"
@onready var tag_start_button: Button = $"../TagMenu/MarginContainer/VBoxContainer/Footer/StartGameButton"
@onready var tag_players_grid: GridContainer = $"../TagMenu/MarginContainer/VBoxContainer/Players"

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
@onready var loading_spinner: TextureProgressBar = $"../../LoadingSpinner"

# tag minigame ##############################################################
#############################################################################
# Color Constants for Name Tag States
const COLOR_BROWN = Color("3d251e")        # Joined player background
const COLOR_GOLD = Color("ffd700")  
const DEFAULT_NAMETAG_COLOR = Color("0000003c")
const ROULETTE_BORDER_WIDTH = 8       # Roulette hop border highlight

# Label Node for visible countdown on screen HUD (e.g., HUD/CountdownLabel)
@onready var countdown_label: Label = $"../../CountdownLabel"
@onready var match_timer_label: Label = $"../../MatchTimerLabel"
const TAG_MINIGAME_TIME_LIMIT: int = 120  # seconds
var _current_tag_match_id: int = 0

##############################################################################

# minigolf minigame #########
#############################
var minigolf_players: Array[int] = []
const PLAYER_TAG_BG_COLOR: Color = COLOR_BROWN

#############################

func _ready() -> void:
	game_manager.minigames_button_pressed.connect(on_minigames_button_pressed)
	minigolf_menu.hide()
	minigolf_button.pressed.connect(minigolf_button_pressed)
	#minigolf_invite_button.pressed.connect(_minigolf_invite_pressed)
	minigolf_menu_close_button.pressed.connect(minigolf_close_pressed)
	#minigolf_start_button.pressed.connect(_minigolf_start_pressed)
	
	# Listen for network status signals (also will need to remove player in delete in multiplayer manager if game closed)
	#MultiplayerManager.player_disconnected_notif.connect(on_player_disconnected)
	#MultiplayerManager.player_reconnecting_notif.connect(on_player_reconnecting)
	#MultiplayerManager.player_reconnected_notif.connect(on_player_reconnected)
	#MultiplayerManager.tag_lobby_updated.connect(_update_tag_player_grid)

func on_minigames_button_pressed(by_player_id: int):
	close_minigolf_menu()
	if minigolf_players.has(by_player_id):
		rpc("remove_minigolf_player", by_player_id)

func close_minigolf_menu():
	minigolf_menu.hide()

@rpc("any_peer", "call_local", "reliable")
func remove_minigolf_player(id: int) -> void:
	if multiplayer.is_server():
		minigolf_players.erase(id)
		rpc("sync_minigolf_lobby_ui", minigolf_players)

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
	rpc("remove_minigolf_player", multiplayer.get_unique_id())
