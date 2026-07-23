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
	## Matches your exact custom class_name "MultiPlayer"
	#if body is MultiPlayer and body.is_local_player():
		## Only prompt if there is an open seat
		#if seated_players.size() < 2 and not game_window.visible:
			#prompt_panel.visible = true
	
	if body is MultiPlayer:
		# Check if the player entering is controlled by THIS specific computer
		var input_sync = body.get_node_or_null("InputSynchronizer")
		if input_sync and input_sync.is_multiplayer_authority():
			# Only prompt if there is an open seat
			if seated_players.size() < 2 and not game_window.visible:
				print("game area entered by %s" % body)
				prompt_panel.visible = true

func _on_body_exited(body: Node) -> void:
	#if body is MultiPlayer and body.is_local_player():
		#prompt_panel.visible = false
		#if game_window.visible:
			#_on_cancel_button_pressed()
	
	if body is MultiPlayer:
		var input_sync = body.get_node_or_null("InputSynchronizer")
		if input_sync and input_sync.is_multiplayer_authority():
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
	
	if seated_players.size() == 2:
		print("starting game with players %s and %s" % [seated_players[0], seated_players[1]])
		# Reset internal board on server
		board_state.fill(0)
		current_turn_idx = 0
		
		# Open game windows with explicitly assigned player roles
		client_open_game.rpc_id(seated_players[0], true)  # True = X (First)
		client_open_game.rpc_id(seated_players[1], false) # False = O
		
		# Sync the initial empty state to both players
		sync_match_state.rpc_id(seated_players[0], board_state, current_turn_idx)
		sync_match_state.rpc_id(seated_players[1], board_state, current_turn_idx)

@rpc("any_peer", "call_local", "reliable")
func server_leave_seat(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	if seated_players.has(peer_id):
		for player in seated_players:
			client_close_game.rpc_id(player)
		seated_players.clear()
		print("seated players cleared")

# --- SERVER GAMEPLAY LOGIC ---

@rpc("any_peer", "call_local", "reliable")
func server_submit_move(cell_idx: int) -> void:
	if not multiplayer.is_server(): return
	var moving_peer = multiplayer.get_remote_sender_id()
	
	# Validate: Is it actually this player's turn?
	if seated_players.size() < 2 or moving_peer != seated_players[current_turn_idx]:
		return
	# Validate: Is the cell actually empty?
	if board_state[cell_idx] != 0:
		return
		
	# Process move (Player 1 writes 1, Player 2 writes 2)
	var marker = 1 if current_turn_idx == 0 else 2
	board_state[cell_idx] = marker
	
	# Check for win or draw
	if check_win_condition(marker):
		client_end_game.rpc_id(seated_players[0], "You Win!" if current_turn_idx == 0 else "You Lose!")
		client_end_game.rpc_id(seated_players[1], "You Win!" if current_turn_idx == 1 else "You Lose!")
		seated_players.clear()
		return
	elif not board_state.has(0):
		client_end_game.rpc_id(seated_players[0], "It's a Draw!")
		client_end_game.rpc_id(seated_players[1], "It's a Draw!")
		seated_players.clear()
		return
		
	# Switch turns and push updates
	current_turn_idx = 1 if current_turn_idx == 0 else 0
	sync_match_state.rpc_id(seated_players[0], board_state, current_turn_idx)
	sync_match_state.rpc_id(seated_players[1], board_state, current_turn_idx)

func check_win_condition(m: int) -> bool:
	var b = board_state
	return ((b[0]==m and b[1]==m and b[2]==m) or (b[3]==m and b[4]==m and b[5]==m) or (b[6]==m and b[7]==m and b[8]==m) or
			(b[0]==m and b[3]==m and b[6]==m) or (b[1]==m and b[4]==m and b[7]==m) or (b[2]==m and b[5]==m and b[8]==m) or
			(b[0]==m and b[4]==m and b[8]==m) or (b[2]==m and b[4]==m and b[6]==m))

# --- CLIENT SYNC CLIENT LOGIC ---

@rpc("authority", "call_local", "reliable")
func client_open_game(is_p1: bool) -> void:
	print("opened game for %s" % multiplayer.get_unique_id())
	am_i_player_one = is_p1
	prompt_panel.visible = false
	game_window.visible = true
	# Reset local visual grid clear state
	update_ui_grid()

@rpc("authority", "call_local", "reliable")
func client_close_game() -> void:
	print("closed game for %s" % multiplayer.get_unique_id())
	game_window.visible = false

@rpc("authority", "call_local", "reliable")
func sync_match_state(server_board: Array, server_turn_idx: int) -> void:
	print("sync match state for %s" % multiplayer.get_unique_id())
	board_state = server_board
	current_turn_idx = server_turn_idx
	update_ui_grid()

@rpc("authority", "call_local", "reliable")
func client_end_game(result_text: String) -> void:
	print("Game Over: ", result_text)
	# You can replace this with a temporary UI popup message label
	game_window.visible = false 

func update_ui_grid() -> void:
	# Safely update grid buttons based on current board_state indexes
	# Assuming your Tic-Tac-Toe grid has 9 buttons in a GridContainer
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
			# Disable clicking if it isn't our local turn right now
			var is_my_turn = (current_turn_idx == 0 and am_i_player_one) or (current_turn_idx == 1 and not am_i_player_one)
			btn.disabled = not is_my_turn
