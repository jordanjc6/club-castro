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


func _ready() -> void:
	game_manager.minigames_button_pressed.connect(close_minigolf_menu)
	minigolf_menu.hide()
	minigolf_button.pressed.connect(minigolf_button_pressed)
	#minigolf_invite_button.pressed.connect(_minigolf_invite_pressed)
	#minigolf_menu_close_button.pressed.connect(_minigolf_close_pressed)
	#minigolf_start_button.pressed.connect(_minigolf_start_pressed)
	
	# Listen for network status signals
	#MultiplayerManager.player_disconnected_notif.connect(on_player_disconnected)
	#MultiplayerManager.player_reconnecting_notif.connect(on_player_reconnecting)
	#MultiplayerManager.player_reconnected_notif.connect(on_player_reconnected)
	#MultiplayerManager.tag_lobby_updated.connect(_update_tag_player_grid)

func close_minigolf_menu():
	minigolf_menu.hide()

func minigolf_button_pressed():
	print("minigolf btn")
	if MultiplayerManager.is_minigolf_minigame_started:
		game_manager.show_temp_notif("A Minigolf game is currently in progress!")
		return
	minigames_mainmenu.hide()
	minigolf_menu.show()
	#MultiplayerManager.rpc("register_tag_player", multiplayer.get_unique_id())

#func _tag_invite_pressed():
	#print("invite to play tag")
	#
	## Check if there are any players connected who haven't joined Tag yet
	#if not game_manager.has_unjoined_players_in_lobby():
		#show_temp_notif("All players in the lobby have already joined!")
		#return
	#
	## Register host/sender immediately as player 1 if not already added
	#MultiplayerManager.rpc("register_tag_player", multiplayer.get_unique_id())
	#
	## Trigger server-side filtered invite distribution
	#MultiplayerManager.rpc("send_minigame_invite_notif", "A player", "Tag")
	#show_temp_notif("Sent invites to unjoined players!")

#func _join_tag_pressed():
	#print("join tag minigame!")
	#game_notif.hide()
	#if MultiplayerManager.is_tag_minigame_started:
		#show_temp_notif("A Tag game is currently in progress!")
		#return
	#
	## Register current player and open Tag menu
	#MultiplayerManager.rpc("register_tag_player", multiplayer.get_unique_id())
	#lobby_button.disabled = true
	#exit_button.disabled = true
	#minigames_button.disabled = false
	#minigames_popup.show()
	#minigames_mainmenu.hide()
	#minigames_tagmenu.show()
	#lobby_popup.hide()

#func _update_tag_player_grid(joined_peers: Array[int]):
	#var labels = tag_players_grid.get_children()
	#for i in range(labels.size()):
		#if i < joined_peers.size():
			#var peer_id = joined_peers[i]
			#labels[i].text = MultiplayerManager.get_player_name(peer_id)
			#_style_player_label(labels[i]) # Sets joined player background to Brown
		#else:
			#labels[i].text = "Waiting..."
			## Remove runtime brown/font overrides so it reverts to the Inspector default style
			#labels[i].remove_theme_stylebox_override("normal")
			#labels[i].remove_theme_color_override("font_color")
			#
			#var stylebox = _create_tag_stylebox(DEFAULT_NAMETAG_COLOR)
			#labels[i].add_theme_stylebox_override("normal", stylebox)
			#labels[i].add_theme_color_override("font_color", "FFFFFF")

#func _tag_close_pressed():
	#print("close tag menu")
	#
	## Unregister local player from Tag lobby if currently joined
	#var my_id = multiplayer.get_unique_id()
	#if MultiplayerManager.joined_tag_peers.has(my_id):
		#MultiplayerManager.rpc("unregister_tag_player", my_id)
#
	#lobby_button.disabled = false
	#exit_button.disabled = false
	#minigames_popup.hide()
	#minigames_mainmenu.hide()
	#minigames_tagmenu.hide()
	#
	#reset_tag_player_colors()

#func _tag_start_pressed():
	#print("start tag game!")
	#var my_id = multiplayer.get_unique_id()
	#if not MultiplayerManager.joined_tag_peers.has(my_id):
		#show_temp_notif("You must join the Tag lobby first!")
		#return
		#
	## Allows any joined peer to request starting the game
	#MultiplayerManager.rpc("request_start_tag_game")

#func _leave_tag_pressed() -> void:
	#print("leave tag game!")
	#var local_id = multiplayer.get_unique_id()
	#
	## Request server to handle mid-game exit logic
	#MultiplayerManager.rpc("request_leave_tag_game", local_id)

#func on_player_disconnected(message: String):
	#side_nav.show()
	#lobby_nav.hide()
	#lobby_popup.hide()
	#minigames_popup.hide()
	#minigames_mainmenu.hide()
	#minigames_tagmenu.hide()
	#
	#MultiplayerManager.reset_tag_lobby()
	#
	#host_button.disabled = false
	#join_button.disabled = false
	#lobby_button.disabled = false
	#minigames_button.disabled = false
	#exit_button.disabled = false
	#show_temp_notif(message)

# Disables lobby action buttons during the roulette
#func set_tag_menu_buttons_disabled(disabled: bool) -> void:
	#tag_start_button.disabled = disabled
	#tag_invite_button.disabled = disabled
	#tag_menu_close_button.disabled = disabled
	#leave_tag_button.disabled = disabled

# Creates a StyleBoxFlat with optional colored border
#func _create_tag_stylebox(bg_color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	#var stylebox = StyleBoxFlat.new()
	#stylebox.bg_color = bg_color
	#
	#if border_width > 0:
		#stylebox.border_color = border_color
		#stylebox.set_border_width_all(border_width)
		#
	## Corner rounding and margins matching your UI tags
	#stylebox.corner_radius_top_left = 50
	#stylebox.corner_radius_top_right = 50
	#stylebox.corner_radius_bottom_left = 50
	#stylebox.corner_radius_bottom_right = 50
	#
	#return stylebox

# Apply brown background, optional border, and optional font color to a label
#func _style_player_label(label_node: Label, border_color: Color = Color.TRANSPARENT, border_width: int = 0, font_color: Color = Color.TRANSPARENT) -> void:
	#if is_instance_valid(label_node):
		#var stylebox = _create_tag_stylebox(COLOR_BROWN, border_color, border_width)
		#label_node.add_theme_stylebox_override("normal", stylebox)
		#
		#if font_color != Color.TRANSPARENT:
			#label_node.add_theme_color_override("font_color", font_color)
		#else:
			#label_node.remove_theme_color_override("font_color")

#func reset_tag_player_colors() -> void:
	#var labels = tag_players_grid.get_children()
	#for i in range(labels.size()):
		#if i < MultiplayerManager.joined_tag_peers.size():
			#_style_player_label(labels[i])
		## Unjoined slots are left untouched

#func run_tag_roulette(participating_peers: Array[int], target_it_peer: int, total_steps: int) -> void:
	#var local_id = multiplayer.get_unique_id()
	#var is_participant = participating_peers.has(local_id)
	#
	## Increment match session ID
	#_current_tag_match_id += 1
	#var my_match_id = _current_tag_match_id
	#
	## ONLY disable UI elements for active match participants
	#if is_participant:
		#set_tag_menu_buttons_disabled(true)
		#if is_instance_valid(minigames_button):
			#minigames_button.disabled = true
	#
	#var labels = tag_players_grid.get_children()
	#for i in range(participating_peers.size()):
		#_style_player_label(labels[i])
		#
	#var target_index = participating_peers.find(target_it_peer)
	#var current_index = 0
	#var delay = 0.08
	#
	#for step in range(total_steps):
		## ABORT ROULETTE IF MATCH WAS CANCELLED MID-ANIMATION
		#if my_match_id != _current_tag_match_id or not MultiplayerManager.is_tag_minigame_started:
			#print("Roulette aborted due to match cancellation.")
			#return
			#
		#_style_player_label(labels[current_index], COLOR_GOLD, ROULETTE_BORDER_WIDTH, COLOR_GOLD)
		#await get_tree().create_timer(delay).timeout
		#
		#if step == total_steps - 1:
			#current_index = target_index
			#_style_player_label(labels[current_index], COLOR_GOLD, ROULETTE_BORDER_WIDTH, COLOR_GOLD)
		#else:
			#_style_player_label(labels[current_index])
			#current_index = (current_index + 1) % participating_peers.size()
			#if step > total_steps - 6:
				#delay += 0.06
				#
	## ABORT BEFORE GAME SETUP IF CANCELLED
	#if my_match_id != _current_tag_match_id or not MultiplayerManager.is_tag_minigame_started:
		#return
		#
	#print("Roulette finished! Peer %d is IT." % target_it_peer)
	#
	#await get_tree().create_timer(1.0).timeout
	#
	#if is_participant:
		#set_tag_menu_buttons_disabled(false)
		#if is_instance_valid(minigames_popup):
			#minigames_popup.hide()
		#if is_instance_valid(minigames_tagmenu):
			#minigames_tagmenu.hide()
		#show_tag_nav(participating_peers)
		#
	#reset_tag_player_colors()
	#
	#if multiplayer.is_server():
		#MultiplayerManager.rpc("setup_tag_game_session", participating_peers, target_it_peer)

#func start_tag_countdown(seconds: int) -> void:
	#var local_id = multiplayer.get_unique_id()
	#
	## Do NOT show countdown HUD for lobby spectators / non-participants
	#if not MultiplayerManager.joined_tag_peers.has(local_id):
		#return
#
	#var my_match_id = _current_tag_match_id
	#
	## Lock leave button during countdown for active participants
	#if is_instance_valid(leave_tag_button):
		#leave_tag_button.disabled = true
	#
	#if is_instance_valid(countdown_label):
		#countdown_label.show()
		#
		#for t in range(seconds, 0, -1):
			## ABORT COUNTDOWN IF MATCH WAS CANCELLED
			#if my_match_id != _current_tag_match_id or not MultiplayerManager.is_tag_minigame_started:
				#countdown_label.hide()
				#if is_instance_valid(leave_tag_button):
					#leave_tag_button.disabled = false
				#return
				#
			#countdown_label.text = str(t)
			#await get_tree().create_timer(1.0).timeout
			#
		#if my_match_id != _current_tag_match_id or not MultiplayerManager.is_tag_minigame_started:
			#countdown_label.hide()
			#if is_instance_valid(leave_tag_button):
				#leave_tag_button.disabled = false
			#MultiplayerManager.restore_all_players_movement()
			#return
		#
		#countdown_label.text = "GO!"
		#await get_tree().create_timer(0.8).timeout
		#countdown_label.hide()
		#
		## Countdown finished! RE-ENABLE LEAVE BUTTON
		#if is_instance_valid(leave_tag_button):
			#leave_tag_button.disabled = false
#
		#if multiplayer.is_server():
			#MultiplayerManager.rpc("unfreeze_it_player", MultiplayerManager.tag_it_peer_id)
		#
		#start_tag_match_timer()

# Format seconds (e.g., 120) into MM:SS string ("02:00")
#func _format_time(total_seconds: int) -> String:
	#var minutes: int = total_seconds / 60
	#var seconds: int = total_seconds % 60
	#return "%d:%02d" % [minutes, seconds]

#func start_tag_match_timer(duration_seconds: int = TAG_MINIGAME_TIME_LIMIT) -> void:
	#var local_id = multiplayer.get_unique_id()
	#
	## Do NOT show match timer HUD for lobby spectators / non-participants
	#if not MultiplayerManager.joined_tag_peers.has(local_id):
		#return
#
	#if not is_instance_valid(match_timer_label):
		#return
		#
	## Increment match ID so any previous running match loops immediately kill themselves
	#_current_tag_match_id += 1
	#var my_match_id = _current_tag_match_id
	#
	#match_timer_label.text = _format_time(duration_seconds)
	#match_timer_label.show()
	#
	#var time_left = duration_seconds
	#while time_left > 0:
		#await get_tree().create_timer(1.0).timeout
		#
		## CANCEL STALE TIMERS: If match was cancelled or a new match started, exit loop
		#if my_match_id != _current_tag_match_id:
			#print("Killed stale tag match timer loop.")
			#return
			#
		#time_left -= 1
		#match_timer_label.text = _format_time(time_left)
		#
	## Verify this is still the active match before handling timeout
	#if my_match_id == _current_tag_match_id:
		#print("Tag match time expired!")
		## Server evaluates the loser ("It") and broadcasts match completion
		#if multiplayer.is_server():
			#MultiplayerManager.request_end_tag_match_naturally()

#func show_tag_nav(participating_peers: Array[int]) -> void:
	#var local_id = multiplayer.get_unique_id()
	#
	## Only swap the navigation UI if this local machine's player is in the tag game
	#if participating_peers.has(local_id):
		#if is_instance_valid(lobby_nav):
			#lobby_nav.hide()
		#if is_instance_valid(tag_nav):
			#tag_nav.show()
		## LOCK LEAVE BUTTON FOR ALL PARTICIPANTS WHEN TAG NAV SHOWS
		#if is_instance_valid(leave_tag_button):
			#leave_tag_button.disabled = true

#func return_participants_to_tag_menu(participants: Array[int], loser_id: int) -> void:
	## 1. Kill active match timer session loop
	#_current_tag_match_id += 1
	#
	## 2. Hide HUD elements and restore navigation bar
	#if is_instance_valid(match_timer_label):
		#match_timer_label.hide()
	#if is_instance_valid(countdown_label):
		#countdown_label.hide()
	#if is_instance_valid(tag_nav):
		#tag_nav.hide()
	#if is_instance_valid(lobby_nav):
		#lobby_nav.show()
		#minigames_button.disabled = false
		#
	## 3. Announce Match Result
	#var local_id = multiplayer.get_unique_id()
	#var loser_name = MultiplayerManager.get_player_name(loser_id)
	#
	#if local_id == loser_id:
		#show_temp_notif("Time's up! You were IT and lost the match!", 5.0)
	#else:
		#show_temp_notif("Time's up! %s was IT and lost!" % loser_name, 5.0)
		#
	## 4. Open Minigames Tag Menu Popup
	#if is_instance_valid(minigames_popup):
		#minigames_popup.show()
	#if is_instance_valid(minigames_mainmenu):
		#minigames_mainmenu.hide()
	#if is_instance_valid(minigames_tagmenu):
		#minigames_tagmenu.show()
		#
	## 5. Enable menu action buttons
	#set_tag_menu_buttons_disabled(false)
	#
	## 6. Re-render player grid so all remaining participants keep their Brown tags
	#_update_tag_player_grid(MultiplayerManager.joined_tag_peers)
