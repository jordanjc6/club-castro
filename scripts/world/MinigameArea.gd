extends Node2D

@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt_panel: PanelContainer = $MinigameUI/PromptPanel
@onready var join_button: Button = $MinigameUI/PromptPanel/VBoxContainer/HBoxContainer/YesButton
@onready var cancel_button: Button = $MinigameUI/PromptPanel/VBoxContainer/HBoxContainer/NoButton
@onready var game_window: Control = $MinigameUI/GameWindow

# --- MATCH VARIABLES (Unique per table instance) ---
var seated_players: Array[int] = []
var board_state: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0] # 0=empty, 1=Player1, 2=Player2
var current_turn_idx: int = 0 # Index of whose turn it is in seated_players
var am_i_player_one: bool = false

func _ready() -> void:
	prompt_panel.visible = false
	game_window.visible = false
	
	join_button.pressed.connect(_on_join_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body is MultiPlayer:
		var input_sync = body.get_node_or_null("InputSynchronizer")
		if input_sync and input_sync.is_multiplayer_authority():
			if seated_players.size() < 2 and not game_window.visible:
				print("game area entered by %s" % body)
				prompt_panel.visible = true

func _on_body_exited(body: Node) -> void:
	if not is_instance_valid(body) or not body.is_inside_tree():
		return
	
	if body is MultiPlayer:
		var input_sync = body.get_node_or_null("InputSynchronizer")
		if input_sync and input_sync.is_inside_tree() and input_sync.is_multiplayer_authority():
			print("game area exited by %s" % body)
			prompt_panel.visible = false
			if game_window.visible || seated_players.size() == 1:
				_on_cancel_button_pressed()

func _on_join_button_pressed() -> void:
	print("%d joined" % multiplayer.get_unique_id())
	prompt_panel.visible = false
	server_request_seat.rpc_id(1, multiplayer.get_unique_id())

func _on_cancel_button_pressed() -> void:
	print("%d cancelled" % multiplayer.get_unique_id())
	prompt_panel.visible = false
	game_window.visible = false
	server_leave_seat.rpc_id(1, multiplayer.get_unique_id())

# --- SERVER LOBBY LOGIC ---

@rpc("any_peer", "call_local", "reliable")
func server_request_seat(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	if seated_players.has(peer_id) or seated_players.size() >= 2: return 
		
	seated_players.append(peer_id)
	print("player %d sitting at minigame" % peer_id)
	
	client_open_game.rpc_id(seated_players[0], true)
	sync_match_state.rpc_id(seated_players[0], board_state, current_turn_idx, seated_players)
	
	if seated_players.size() == 2:
		board_state.fill(0)
		current_turn_idx = 0
		
		client_open_game.rpc_id(seated_players[0], true)
		client_open_game.rpc_id(seated_players[1], false)
		
		sync_match_state.rpc_id(seated_players[0], board_state, current_turn_idx, seated_players)
		sync_match_state.rpc_id(seated_players[1], board_state, current_turn_idx, seated_players)

@rpc("any_peer", "call_local", "reliable")
func server_leave_seat(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	if seated_players.has(peer_id):
		var notify_list = seated_players.duplicate()
		seated_players.clear()
		board_state.fill(0)
		current_turn_idx = 0
		
		# Server pushes cleared state & closes windows for all players in this match
		for player in notify_list:
			sync_match_state.rpc_id(player, board_state, current_turn_idx, seated_players)
			client_close_game.rpc_id(player)

# --- SERVER GAMEPLAY LOGIC ---

@rpc("any_peer", "call_local", "reliable")
func server_submit_move(cell_idx: int) -> void:
	if not multiplayer.is_server(): return
	var moving_peer = multiplayer.get_remote_sender_id()
	
	if seated_players.size() < 2 or moving_peer != seated_players[current_turn_idx]:
		return
	if board_state[cell_idx] != 0:
		return
		
	var marker = 1 if current_turn_idx == 0 else 2
	board_state[cell_idx] = marker
	
	# Check Win / Draw
	if check_win_condition(marker) or not board_state.has(0):
		var p1 = seated_players[0]
		var p2 = seated_players[1]
		
		var is_draw = not check_win_condition(marker)
		var p1_msg = "It's a Draw!" if is_draw else ("You Win!" if current_turn_idx == 0 else "You Lose!")
		var p2_msg = "It's a Draw!" if is_draw else ("You Win!" if current_turn_idx == 1 else "You Lose!")

		# Reset server state first
		board_state.fill(0)
		current_turn_idx = 0
		seated_players.clear()
		
		# Sync cleared state to both clients before ending game
		sync_match_state.rpc_id(p1, board_state, current_turn_idx, seated_players)
		sync_match_state.rpc_id(p2, board_state, current_turn_idx, seated_players)
		
		client_end_game.rpc_id(p1, p1_msg)
		client_end_game.rpc_id(p2, p2_msg)
		return
		
	current_turn_idx = 1 if current_turn_idx == 0 else 0
	sync_match_state.rpc_id(seated_players[0], board_state, current_turn_idx, seated_players)
	sync_match_state.rpc_id(seated_players[1], board_state, current_turn_idx, seated_players)

func check_win_condition(m: int) -> bool:
	var b = board_state
	return ((b[0]==m and b[1]==m and b[2]==m) or (b[3]==m and b[4]==m and b[5]==m) or (b[6]==m and b[7]==m and b[8]==m) or
			(b[0]==m and b[3]==m and b[6]==m) or (b[1]==m and b[4]==m and b[7]==m) or (b[2]==m and b[5]==m and b[8]==m) or
			(b[0]==m and b[4]==m and b[8]==m) or (b[2]==m and b[4]==m and b[6]==m))

# --- CLIENT SYNC LOGIC ---

@rpc("authority", "call_local", "reliable")
func client_open_game(is_p1: bool) -> void:
	am_i_player_one = is_p1
	prompt_panel.visible = false
	game_window.visible = true
	update_ui_grid()
	update_player_labels()

@rpc("authority", "call_local", "reliable")
func client_close_game() -> void:
	game_window.visible = false
	board_state.fill(0)
	seated_players.clear()
	update_ui_grid()
	update_player_labels()

@rpc("authority", "call_local", "reliable")
func sync_match_state(server_board: Array, server_turn_idx: int, server_seated_players: Array) -> void:
	board_state = server_board
	current_turn_idx = server_turn_idx
	seated_players = server_seated_players
	update_ui_grid()
	update_player_labels()

@rpc("authority", "call_local", "reliable")
func client_end_game(result_text: String) -> void:
	print("Game Over: ", result_text)
	game_window.visible = false 
	board_state.fill(0)
	seated_players.clear()
	update_ui_grid()
	update_player_labels()

func update_ui_grid() -> void:
	var grid_container = game_window.get_node_or_null("VBoxContainer/CenterContainer/GridContainer")
	if not grid_container: return
	
	for i in range(9):
		var btn = grid_container.get_child(i) as Button
		if board_state[i] == 1:
			btn.text = "X"
			btn.disabled = true
		elif board_state[i] == 2:
			btn.text = "O"
			btn.disabled = true
		else:
			btn.text = ""
			var is_my_turn = (current_turn_idx == 0 and am_i_player_one) or (current_turn_idx == 1 and not am_i_player_one)
			btn.disabled = not is_my_turn

func update_player_labels() -> void:
	var p1 = "Player 1"
	var p2 = "Player 2" if seated_players.size() == 2 else "Waiting..."
	
	var player1_label = game_window.get_node_or_null("VBoxContainer/HBoxContainer2/Player1Label") as RichTextLabel
	var player2_label = game_window.get_node_or_null("VBoxContainer/HBoxContainer2/Player2Label") as RichTextLabel
	
	if not player1_label or not player2_label:
		return
	
	if seated_players.size() == 2:
		if current_turn_idx == 0:
			player1_label.text = "[center][b]► " + p1 + "[/b][/center]"
			player2_label.text = "[center]" + p2 + "[/center]"
		else:
			player1_label.text = "[center]" + p1 + "[/center]"
			player2_label.text = "[center][b]► " + p2 + "[/b][/center]"
	else:
		player1_label.text = "[center]" + p1 + "[/center]"
		player2_label.text = "[center]" + p2 + "[/center]"
