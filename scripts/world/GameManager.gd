extends Node

# single player sidenav
@onready var side_nav: HBoxContainer = $"../HUD/SideNav"
@onready var host_button: Button = $"../HUD/SideNav/MultiplayerHUD/VBoxContainer/HostButton"
@onready var join_button: Button = $"../HUD/SideNav/MultiplayerHUD/VBoxContainer/JoinButton"
@onready var join_popup: PanelContainer = $"../HUD/JoinPopup"
@onready var find_button: Button = $"../HUD/JoinPopup/VBoxContainer/FindButton"

# multiplayer lobby nav
@onready var lobby_nav: HBoxContainer = $"../HUD/LobbyNav"
@onready var lobby_button: Button = $"../HUD/LobbyNav/MultiplayerHUD/VBoxContainer/LobbyButton"
@onready var minigames_button: Button = $"../HUD/LobbyNav/MultiplayerHUD/VBoxContainer/MinigamesButton"
@onready var exit_button: Button = $"../HUD/LobbyNav/MultiplayerHUD/VBoxContainer/ExitButton"
@onready var lobby_popup: PanelContainer = $"../HUD/LobbyPopup"
@onready var copy_button: Button = $"../HUD/LobbyPopup/VBoxContainer/CopyButton"

# minigames popup
@onready var minigames_popup: Node2D = $"../HUD/MinigamesPopup"
@onready var minigames_mainmenu: PanelContainer = $"../HUD/MinigamesPopup/MainMenu"
@onready var tag_button: Button = $"../HUD/MinigamesPopup/MainMenu/MarginContainer/VBoxContainer/HBoxContainer/TagButton"
@onready var minigames_tagmenu: PanelContainer = $"../HUD/MinigamesPopup/TagMenu"
@onready var tag_invite_button: Button = $"../HUD/MinigamesPopup/TagMenu/MarginContainer/VBoxContainer/Header/HBoxContainer/InviteButton"
@onready var tag_menu_close_button: Button = $"../HUD/MinigamesPopup/TagMenu/MarginContainer/VBoxContainer/Header/HBoxContainer/CloseTagMenuButton"
@onready var tag_start_button: Button = $"../HUD/MinigamesPopup/TagMenu/MarginContainer/VBoxContainer/Footer/StartGameButton"
@onready var tag_players_grid: GridContainer = $"../HUD/MinigamesPopup/TagMenu/MarginContainer/VBoxContainer/Players"

# other
@onready var game_notif: PanelContainer = $"../HUD/GameNotification"
@onready var join_tag_button: Button = $"../HUD/GameNotification/MarginContainer/VBoxContainer/JoinTagButton"
@onready var loading_spinner: TextureProgressBar = $"../HUD/LoadingSpinner"

# tag minigame #
################
# Color Constants for Name Tag States
const COLOR_BROWN = Color("3d251e")        # Joined player background
const COLOR_GOLD = Color("ffd700")  
const ROULETTE_BORDER_WIDTH = 8       # Roulette hop border highlight


func _ready() -> void:
	host_button.pressed.connect(_host_button_pressed)
	join_button.pressed.connect(_join_button_pressed)
	lobby_button.pressed.connect(_lobby_button_pressed)
	minigames_button.pressed.connect(_minigames_button_pressed)
	exit_button.pressed.connect(_exit_button_pressed)
	copy_button.pressed.connect(_copy_button_pressed)
	find_button.pressed.connect(_find_button_pressed)
	
	lobby_popup.hide()
	minigames_popup.hide()
	minigames_mainmenu.hide()
	minigames_tagmenu.hide()
	
	tag_button.pressed.connect(_tag_button_pressed)
	tag_invite_button.pressed.connect(_tag_invite_pressed)
	tag_menu_close_button.pressed.connect(_tag_close_pressed)
	tag_start_button.pressed.connect(_tag_start_pressed)
	
	join_popup.hide()
	game_notif.hide()
	join_tag_button.pressed.connect(_join_tag_pressed)
	loading_spinner.hide()
	
	# Listen for network status signals
	MultiplayerManager.player_disconnected_notif.connect(on_player_disconnected)
	MultiplayerManager.player_reconnecting_notif.connect(on_player_reconnecting)
	MultiplayerManager.player_reconnected_notif.connect(on_player_reconnected)
	MultiplayerManager.tag_lobby_updated.connect(_update_tag_player_grid)
	
	# iOS keyboard listener
	join_popup.get_node("VBoxContainer/Code").text_submitted.connect(_on_code_submitted)

func _on_code_submitted(_new_text: String) -> void:
	join_popup.get_node("VBoxContainer/Code").release_focus()

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
	join_popup.visible = !join_popup.visible
	if join_popup.visible: host_button.disabled = true
	else: host_button.disabled = false

func _find_button_pressed():
	print("find btn")
	var entered_code = join_popup.get_node("VBoxContainer/Code").text.strip_edges()
	if entered_code != "":
		loading_spinner.show()
		join_button.disabled = true
		var result = await MultiplayerManager.join_game(entered_code)
		if result.success: 
			side_nav.hide()
			join_popup.hide()
			lobby_nav.show()
			show_temp_notif("Joined lobby!")
		else:
			join_button.disabled = false
			var text = result.message if result.message != "" else "Failed to join lobby. Check internet connection!"
			show_temp_notif(text)
		loading_spinner.hide()

func _tag_button_pressed():
	print("tag btn")
	minigames_mainmenu.hide()
	minigames_tagmenu.show()
	MultiplayerManager.rpc("register_tag_player", multiplayer.get_unique_id())

func has_other_players_in_lobby() -> bool:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	return multiplayer.get_peers().size() > 0

#func _tag_invite_pressed():
	#print("invite to play tag")
	#if not has_other_players_in_lobby():
		#show_temp_notif("No other players in the lobby!")
		#return
	#
	## Register host/sender immediately as player 1
	#MultiplayerManager.rpc("register_tag_player", multiplayer.get_unique_id())
	#
	## Send invite notification to all other connected peers
	#MultiplayerManager.rpc("send_minigame_invite_notif", "A player", "Tag")
	#show_temp_notif("Sent invites to players in lobby!")

func has_unjoined_players_in_lobby() -> bool:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
		
	for peer_id in multiplayer.get_peers():
		# Return true if we find at least one connected peer who hasn't joined Tag yet
		if not MultiplayerManager.joined_tag_peers.has(peer_id):
			return true
			
	return false

func _tag_invite_pressed():
	print("invite to play tag")
	
	# Check if there are any players connected who haven't joined Tag yet
	if not has_unjoined_players_in_lobby():
		show_temp_notif("All players in the lobby have already joined!")
		return
	
	# Register host/sender immediately as player 1 if not already added
	MultiplayerManager.rpc("register_tag_player", multiplayer.get_unique_id())
	
	# Trigger server-side filtered invite distribution
	MultiplayerManager.rpc("send_minigame_invite_notif", "A player", "Tag")
	show_temp_notif("Sent invites to unjoined players!")

func _join_tag_pressed():
	print("join tag minigame!")
	game_notif.hide()
	
	# Register current player and open Tag menu
	MultiplayerManager.rpc("register_tag_player", multiplayer.get_unique_id())
	lobby_button.disabled = true
	exit_button.disabled = true
	minigames_button.disabled = false
	minigames_popup.show()
	minigames_mainmenu.hide()
	minigames_tagmenu.show()

#func _update_tag_player_grid(joined_peers: Array[int]):
	#var labels = tag_players_grid.get_children()
	#for i in range(labels.size()):
		#if i < joined_peers.size():
			#var peer_id = joined_peers[i]
			#labels[i].text = MultiplayerManager.get_player_name(peer_id)
		#else:
			#labels[i].text = "Awaiting Player..."

func _update_tag_player_grid(joined_peers: Array[int]):
	var labels = tag_players_grid.get_children()
	for i in range(labels.size()):
		if i < joined_peers.size():
			var peer_id = joined_peers[i]
			labels[i].text = MultiplayerManager.get_player_name(peer_id)
			_style_player_label(labels[i]) # Sets joined player background to Brown
		else:
			labels[i].text = "Waiting..."
			# Do not touch or modify the Inspector stylebox for unjoined slots at all

func _tag_close_pressed():
	print("close tag menu")
	
	# Unregister local player from Tag lobby if currently joined
	var my_id = multiplayer.get_unique_id()
	if MultiplayerManager.joined_tag_peers.has(my_id):
		MultiplayerManager.rpc("unregister_tag_player", my_id)

	lobby_button.disabled = false
	exit_button.disabled = false
	minigames_popup.hide()
	minigames_mainmenu.hide()
	minigames_tagmenu.hide()
	
	reset_tag_player_colors()

func _tag_start_pressed():
	print("start tag game!")
	var my_id = multiplayer.get_unique_id()
	if not MultiplayerManager.joined_tag_peers.has(my_id):
		show_temp_notif("You must join the Tag lobby first!")
		return
		
	# Allows any joined peer to request starting the game
	MultiplayerManager.rpc("request_start_tag_game")

func _lobby_button_pressed():
	print("lobby btn")
	if !lobby_popup.visible:
		lobby_popup.get_node("VBoxContainer/Code").text = MultiplayerManager.get_active_lobby_code()
		minigames_button.disabled = true
		exit_button.disabled = true
	else: 
		minigames_button.disabled = false
		exit_button.disabled = false
	lobby_popup.visible = !lobby_popup.visible

func _minigames_button_pressed():
	print("minigames btn")
	if !minigames_popup.visible:
		lobby_button.disabled = true
		exit_button.disabled = true
		minigames_mainmenu.show()
		minigames_tagmenu.hide()
	else: 
		lobby_button.disabled = false
		exit_button.disabled = false
		minigames_mainmenu.hide()
		minigames_tagmenu.hide()
		# Unregister local player from Tag lobby if currently joined
		var my_id = multiplayer.get_unique_id()
		if MultiplayerManager.joined_tag_peers.has(my_id):
			MultiplayerManager.rpc("unregister_tag_player", my_id)
	minigames_popup.visible = !minigames_popup.visible

func _exit_button_pressed():
	print("exit btn")
	lobby_button.disabled = true
	minigames_button.disabled = true
	exit_button.disabled = true
	loading_spinner.show()
	
	MultiplayerManager.reset_tag_lobby()
	await MultiplayerManager._on_leave_lobby_button_pressed()
	
	lobby_button.disabled = false
	minigames_button.disabled = false
	exit_button.disabled = false
	loading_spinner.hide()
	
	lobby_nav.hide()
	lobby_popup.hide()
	minigames_popup.hide()
	minigames_mainmenu.hide()
	minigames_tagmenu.hide()
	side_nav.show()

func _copy_button_pressed():
	print("copy btn")
	DisplayServer.clipboard_set(MultiplayerManager.get_active_lobby_code())

func on_player_disconnected(message: String):
	side_nav.show()
	lobby_nav.hide()
	lobby_popup.hide()
	minigames_popup.hide()
	minigames_mainmenu.hide()
	minigames_tagmenu.hide()
	
	MultiplayerManager.reset_tag_lobby()
	
	host_button.disabled = false
	join_button.disabled = false
	lobby_button.disabled = false
	minigames_button.disabled = false
	exit_button.disabled = false
	show_temp_notif(message)

func show_temp_notif(text: String, is_tag_invite: bool = false):
	var label_node: Label = game_notif.get_node("MarginContainer/VBoxContainer/Label")
	if is_instance_valid(label_node):
		label_node.text = text
	
	if is_instance_valid(join_tag_button):
		join_tag_button.visible = is_tag_invite
	
	game_notif.show()
	
	var tween = create_tween()
	tween.tween_interval(4.5)
	tween.tween_callback(func():
		if is_instance_valid(join_tag_button) and join_tag_button.visible:
			join_tag_button.hide()
		game_notif.hide()
	)

func on_player_reconnecting(message: String):
	show_perm_notif(message)

func show_perm_notif(text: String):
	var label_node: Label = game_notif.get_node("Label")
	if is_instance_valid(label_node):
		label_node.text = text
	game_notif.show()

func on_player_reconnected(message: String, flag: bool = false):
	show_temp_notif(message, flag)

# Disables lobby action buttons during the roulette
func set_tag_menu_buttons_disabled(disabled: bool) -> void:
	tag_start_button.disabled = disabled
	tag_invite_button.disabled = disabled
	tag_menu_close_button.disabled = disabled

# Creates a StyleBoxFlat with optional colored border
func _create_tag_stylebox(bg_color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = bg_color
	
	if border_width > 0:
		stylebox.border_color = border_color
		stylebox.set_border_width_all(border_width)
		
	# Corner rounding and margins matching your UI tags
	stylebox.corner_radius_top_left = 50
	stylebox.corner_radius_top_right = 50
	stylebox.corner_radius_bottom_left = 50
	stylebox.corner_radius_bottom_right = 50
	
	return stylebox

# Apply brown background (and optional border) to a label
#func _style_player_label(label_node: Label, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> void:
	#if is_instance_valid(label_node):
		#var stylebox = _create_tag_stylebox(COLOR_BROWN, border_color, border_width)
		#label_node.add_theme_stylebox_override("normal", stylebox)

# Apply brown background, optional border, and optional font color to a label
func _style_player_label(label_node: Label, border_color: Color = Color.TRANSPARENT, border_width: int = 0, font_color: Color = Color.TRANSPARENT) -> void:
	if is_instance_valid(label_node):
		var stylebox = _create_tag_stylebox(COLOR_BROWN, border_color, border_width)
		label_node.add_theme_stylebox_override("normal", stylebox)
		
		if font_color != Color.TRANSPARENT:
			label_node.add_theme_color_override("font_color", font_color)
		else:
			label_node.remove_theme_color_override("font_color")

#func reset_tag_player_colors() -> void:
	#var labels = tag_players_grid.get_children()
	#for i in range(labels.size()):
		#if i < MultiplayerManager.joined_tag_peers.size():
			#_style_player_label(labels[i])
		## Unjoined slots are left untouched

func reset_tag_player_colors() -> void:
	var labels = tag_players_grid.get_children()
	for i in range(labels.size()):
		if i < MultiplayerManager.joined_tag_peers.size():
			_style_player_label(labels[i])
		# Unjoined slots are left untouched

#func run_tag_roulette(participating_peers: Array[int], target_it_peer: int, total_steps: int) -> void:
	## 1. Lock menu buttons
	#set_tag_menu_buttons_disabled(true)
	#
	## 2. Ensure all participating labels have the base brown background
	#var labels = tag_players_grid.get_children()
	#for i in range(participating_peers.size()):
		#_style_player_label(labels[i])
		#
	## 3. Target slot calculation
	#var target_index = participating_peers.find(target_it_peer)
	#var current_index = 0
	#var delay = 0.08
	#
	## 4. Run Golden Border Roulette animation
	#for step in range(total_steps):
		## Highlight current slot with a 3px Golden Border
		#_style_player_label(labels[current_index], COLOR_GOLD, ROULETTE_BORDER_WIDTH)
		#
		#await get_tree().create_timer(delay).timeout
		#
		#if step == total_steps - 1:
			## Final stop: Lock on target index and keep the Golden Border!
			#current_index = target_index
			#_style_player_label(labels[current_index], COLOR_GOLD, ROULETTE_BORDER_WIDTH)
		#else:
			## Remove border from current slot before hopping to the next
			#_style_player_label(labels[current_index])
			#current_index = (current_index + 1) % participating_peers.size()
			#
			#if step > total_steps - 6:
				#delay += 0.06
				#
	#print("Roulette finished! Peer %d is IT." % target_it_peer)
	#
	## 5. Delay before transitioning out of lobby
	#await get_tree().create_timer(1).timeout
	#
	#tag_start_button.disabled = false
	##set_tag_menu_buttons_disabled(false)
	##reset_tag_player_colors()
	##minigames_popup.hide()
	##minigames_tagmenu.hide()

func run_tag_roulette(participating_peers: Array[int], target_it_peer: int, total_steps: int) -> void:
	# 1. Lock menu buttons
	set_tag_menu_buttons_disabled(true)
	
	# 2. Ensure all participating labels have the base brown background and default font color
	var labels = tag_players_grid.get_children()
	for i in range(participating_peers.size()):
		_style_player_label(labels[i])
		
	# 3. Target slot calculation
	var target_index = participating_peers.find(target_it_peer)
	var current_index = 0
	var delay = 0.08
	
	# 4. Run Golden Border & Font Roulette animation
	for step in range(total_steps):
		# Highlight current slot with Golden Border AND Golden Font
		_style_player_label(labels[current_index], COLOR_GOLD, ROULETTE_BORDER_WIDTH, COLOR_GOLD)
		
		await get_tree().create_timer(delay).timeout
		
		if step == total_steps - 1:
			# Final stop: Lock on target index and keep Golden Border AND Golden Font!
			current_index = target_index
			_style_player_label(labels[current_index], COLOR_GOLD, ROULETTE_BORDER_WIDTH, COLOR_GOLD)
		else:
			# Reset current slot before hopping to the next
			_style_player_label(labels[current_index])
			current_index = (current_index + 1) % participating_peers.size()
			
			if step > total_steps - 6:
				delay += 0.06
				
	print("Roulette finished! Peer %d is IT." % target_it_peer)
	
	# 5. Delay before transitioning out of lobby
	await get_tree().create_timer(1).timeout
	
	tag_start_button.disabled = false
	#set_tag_menu_buttons_disabled(false)
	#reset_tag_player_colors()
	#minigames_popup.hide()
	#minigames_tagmenu.hide()
