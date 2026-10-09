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

# MinigolfMinigame
@onready var minigolf_minigame: Node2D = $"../../../MinigolfMinigame"
@onready var minigolf_minigame_game_info: HBoxContainer = $"../../../MinigolfMinigame/Screen/UI/HBoxContainer/HUD/RotationWrapper/VBoxContainer/GameInfo"
@onready var minigolf_minigame_player_grid: GridContainer = $"../../../MinigolfMinigame/Screen/UI/HBoxContainer/HUD/RotationWrapper/VBoxContainer/PlayerGrid"

# other
@onready var game_notif: PanelContainer = $"../../GameNotification"
var _notif_tween: Tween = null
@onready var join_tag_button: Button = $"../../GameNotification/MarginContainer/VBoxContainer/JoinTagButton"
@onready var join_minigolf_button: Button = $"../../GameNotification/MarginContainer/VBoxContainer/JoinMinigolfButton"
@onready var loading_spinner: TextureProgressBar = $"../../LoadingSpinner"

# style constants
const COLOR_BROWN = Color("3d251e")
const COLOR_GOLD = Color("ffd700")  
const COLOR_GREEN = Color("2e7d32")
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
	if not MultiplayerManager.is_minigolf_minigame_started:
		if minigolf_players.has(by_player_id):
			print("ERASED PLAYER")
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
		print("[SERVER] Removing Minigolf player ID: ", id)
		minigolf_players.erase(id)
		rpc("sync_minigolf_lobby_ui", minigolf_players)

		# IF GAME IS ACTIVE: Tell minigame to handle mid-game departure
		if MultiplayerManager.is_minigolf_minigame_started:
			if is_instance_valid(minigolf_minigame) and minigolf_minigame.has_method("handle_midgame_player_disconnect"):
				minigolf_minigame.handle_midgame_player_disconnect(id)

		check_remaining_players()

func check_remaining_players():
	if minigolf_players.is_empty():
		print("[SERVER] All minigolf players left. Resetting match state...")
		reset_minigolf_state()

func reset_minigolf_state():
	if multiplayer.is_server():
		minigolf_players.clear()
		MultiplayerManager.rpc("set_minigolf_started", false)
		rpc("sync_minigolf_lobby_ui", minigolf_players)
		
		# Force teardown of active minigame entities if room becomes empty
		if is_instance_valid(minigolf_minigame) and minigolf_minigame.has_method("end_minigolf_game"):
			minigolf_minigame.rpc("end_minigolf_game")

func reset_state_for_single_player_return(msg: String):
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
		recipients.append(1)
	
	for peer_id in recipients:
		if peer_id != sender_id and not minigolf_players.has(peer_id):
			if peer_id == 1:
				receive_minigolf_invite(sender_name)
			else:
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
	
	lobby_button.disabled = true
	exit_button.disabled = true
	minigames_button.disabled = false
	minigames_popup.show()
	minigames_mainmenu.hide()
	minigames_tagmenu.hide()
	minigolf_menu.show()
	lobby_popup.hide()
	
	var my_id = multiplayer.get_unique_id()
	if MultiplayerManager.joined_tag_peers.has(my_id):
		MultiplayerManager.rpc("unregister_tag_player", my_id)
		game_manager.reset_tag_player_colors

func minigolf_start_pressed():
	rpc("request_start_minigolf")

@rpc("any_peer", "call_local", "reliable")
func request_start_minigolf() -> void:
	if multiplayer.is_server():
		if minigolf_players.size() < 2:
			rpc("notify_not_enough_players")
			return
		minigolf_players.shuffle()
		minigolf_minigame.rpc("start_minigolf", minigolf_players)
		rpc("set_minigolf_ui")
		teleport_players_to_minigolf()
		await get_tree().create_timer(5).timeout
		disable_player_movement()

@rpc("authority", "call_local", "reliable")
func notify_not_enough_players() -> void:
	if not minigolf_players.has(multiplayer.get_unique_id()):
		return
	game_manager.show_temp_notif("Need at least 2 players!", 2)

@rpc("authority", "call_local", "reliable")
func set_minigolf_ui() -> void:
	if not minigolf_players.has(multiplayer.get_unique_id()):
		return
	lobby_nav.hide()
	minigolf_menu.hide()
	for player in get_tree().get_nodes_in_group("player"):
		player.hide()

func update_game_info(course_num: int, turn_id: int):
	var courseLabel = minigolf_minigame_game_info.get_node("CourseLabel")
	var turnLabel = minigolf_minigame_game_info.get_node("TurnLabel")
	
	courseLabel.text = "Course %s/3" % course_num
	
	var my_id = multiplayer.get_unique_id()
	if turn_id == my_id:
		turnLabel.text = "Your turn!"
	else:
		turnLabel.text = "%s's turn" % MultiplayerManager.get_player_name(turn_id)

func update_player_grid(players: Array, curr_turn_id: int, player_data: Dictionary = {}) -> void:
	var label_nodes = minigolf_minigame_player_grid.get_children()
	
	for i in range(label_nodes.size()):
		var label = label_nodes[i] as Label
		if not label:
			continue
			
		if i < players.size():
			var peer_id = players[i]
			var player_name = MultiplayerManager.get_player_name(peer_id)
			
			var current_strokes = 0
			var total_strokes = 0
			var p_color = Color.WHITE
			
			if player_data.has(peer_id):
				current_strokes = player_data[peer_id].get("current_strokes", 0)
				total_strokes = player_data[peer_id].get("total_strokes", 0)
				p_color = player_data[peer_id].get("color", Color.WHITE)

			label.text = "%d. %s: %d (%d)" % [i + 1, player_name, current_strokes, total_strokes]
			label.show()
			
			var is_turn = (peer_id == curr_turn_id)
			apply_player_label_style(label, is_turn, p_color)
		else:
			label.hide()

func apply_player_label_style(label: Label, is_current_turn: bool = false, ball_color: Color = Color.WHITE) -> void:
	var style = StyleBoxFlat.new()
	
	if is_current_turn:
		style.bg_color = COLOR_GREEN
		style.border_color = ball_color
		style.set_border_width_all(3)
	else:
		style.bg_color = Color(0.1, 0.1, 0.1, 0.6)
		style.border_color = Color(0.3, 0.3, 0.3, 0.8)
		style.set_border_width_all(1)
	
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	
	label.add_theme_stylebox_override("normal", style)

func teleport_players_to_minigolf() -> void:
	if not multiplayer.is_server():
		return
	var new_zone_offset = Vector2(0, 950)
	var target_position = Vector2(250, 1200)
	for player in get_tree().get_nodes_in_group("player"):
		if minigolf_players.has(player.player_id):
			player.update_zone_offset.rpc_id(player.player_id, new_zone_offset)
			player.global_position = target_position
			player.hide()

func disable_player_movement():
	for player in get_tree().get_nodes_in_group("player"):
		if minigolf_players.has(player.player_id):
			player.set_movement_disabled.rpc(true)

func on_minigolf_game_ended(final_players: Array[int]) -> void:
	print("\n=== [DEBUG] ON MINIGOLF GAME ENDED ===")
	print("  -> Passed participants from minigame: ", final_players)

	minigolf_players = final_players.duplicate()
	if multiplayer.is_server():
		rpc("sync_minigolf_lobby_ui", minigolf_players)

	if not multiplayer.is_server():
		return
		
	enable_player_movement()
	teleport_players_to_overworld()

func enable_player_movement() -> void:
	print("[SERVER/LOCAL] Re-enabling movement for minigolf_players: ", minigolf_players)
	for player in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(player) and "player_id" in player:
			var p_id = player.player_id
			if minigolf_players.has(p_id):
				print("  -> Re-enabling movement for Peer: ", p_id)
				
				# 1. Un-freeze locally on host machine
				if player.has_method("set_movement_disabled"):
					player.set_movement_disabled(false)
				
				# 2. Target specific peer across network to un-freeze on their machine
				player.rpc_id(p_id, "set_movement_disabled", false)

func teleport_players_to_overworld() -> void:
	if not multiplayer.is_server():
		return
		
	var default_zone_offset = Vector2(0, 0)
	var target_position = Vector2(647, 528)
	
	print("[SERVER] Teleporting minigolf participants back to overworld...")
	
	rpc("set_overworld_ui")
	
	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player) or not ("player_id" in player):
			continue

		var p_id = player.player_id
		
		if minigolf_players.has(p_id):
			print("  -> Teleporting Minigolf Participant Peer: ", p_id)
			player.update_zone_offset.rpc_id(p_id, default_zone_offset)
			player.global_position = target_position
			
			# Re-enable movement on host & RPC to target peer
			if player.has_method("set_movement_disabled"):
				player.set_movement_disabled(false)
				player.rpc_id(p_id, "set_movement_disabled", false)
			
			if player.has_method("set_player_visible"):
				player.rpc("set_player_visible", true)
			else:
				player.show()

			# Notify all client peers to refresh player visibility, velocity, & animation processing
			rpc("teleport_local_client_player", target_position)

@rpc("authority", "call_local", "reliable")
func set_overworld_ui() -> void:
	var my_id = multiplayer.get_unique_id()

	if not minigolf_players.has(my_id):
		return

	print("[DEBUG] Restoring Overworld UI for participant Peer: ", my_id)
	
	if is_instance_valid(minigolf_menu):
		minigolf_menu.show()
		
	if is_instance_valid(minigames_popup):
		minigames_popup.show()
		
	if is_instance_valid(lobby_nav):
		lobby_nav.show()
		
	lobby_button.disabled = true
	minigames_button.disabled = false
	exit_button.disabled = true

# --- NEW: DEDICATED JOINER MANUAL EXIT PIPELINE ---
func teleport_single_quitting_joiner_to_overworld(quitting_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	var default_zone_offset = Vector2(0, 0)
	var target_position = Vector2(647, 528)
	
	print("[SERVER] Teleporting quitting joiner Peer %d back to overworld..." % quitting_peer_id)
	
	# 1. Erase from lobby player tracking array
	minigolf_players.erase(quitting_peer_id)
	rpc("sync_minigolf_lobby_ui", minigolf_players)

	# 2. Restore quitting joiner UI locally
	rpc_id(quitting_peer_id, "set_quitting_joiner_overworld_ui")
	
	# 3. Teleport quitter & un-hide/un-freeze player node safely across the network
	for player in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(player) and "player_id" in player and player.player_id == quitting_peer_id:
			# If your player script has a custom visibility RPC method, call it here:
			if player.has_method("set_player_visible"):
				player.rpc("set_player_visible", true)
			else:
				# Fallback: Call standard built-in method locally on server instance
				player.show()

			if player.has_method("set_movement_disabled"):
				player.set_movement_disabled(false)
				if player.has_signal("movement_changed") or player.has_method("sync_movement"):
					player.rpc("set_movement_disabled", false)

			player.update_zone_offset.rpc_id(quitting_peer_id, default_zone_offset)
			player.global_position = target_position
			rpc_id(quitting_peer_id, "teleport_local_client_player", target_position)

@rpc("authority", "call_local", "reliable")
func set_quitting_joiner_overworld_ui() -> void:
	print("[CLIENT] Restoring Overworld UI for quitting joiner locally...")
	close_minigolf_menu()
	hide_minigames_popups()
	if is_instance_valid(lobby_nav):
		lobby_nav.show()
	enable_lobby_nav_buttons()

@rpc("authority", "call_local", "reliable")
func teleport_local_client_player(target_pos: Vector2) -> void:
	var my_id = multiplayer.get_unique_id()
	
	for player in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(player) and "player_id" in player:
			# Ensure all player nodes in the scene re-enable process & movement
			if player.has_method("set_movement_disabled"):
				player.set_movement_disabled(false)
			
			# Restore physics & process execution if disabled during minigolf
			player.set_physics_process(true)
			player.set_process(true)

			if player.player_id == my_id:
				player.show()
				if "velocity" in player:
					player.velocity = Vector2.ZERO
				player.global_position = target_pos
				print("[CLIENT %d] Successfully restored overworld player state at %s" % [my_id, target_pos])
