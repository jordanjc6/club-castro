# inspired by club penguin pizza game
# gets orders every x seconds up to a max limit at once
# fulfilling a bbt order clears the order and allows another order to come
# players have a set amount of time to fulfill as many orders as possible
# 4 work spaces for bbt orders to be prepared
# choose cup size, toppings, ice level, drink type, sugar level
# once order is ready (right or wrong) click 'send order', if order matched
# a pending order then clear that order, otherwise no order cleared
# there is no removing a wrong action on an order, just need to send it to remove
# it from work space

extends Node2D

@onready var interaction_area: Area2D = $InteractionArea
@onready var game_prompt_panel: PanelContainer = $MinigameUI/GamePrompt
@onready var join_button: Button = $MinigameUI/GamePrompt/VBoxContainer/HBoxContainer/YesButton
@onready var cancel_button: Button = $MinigameUI/GamePrompt/VBoxContainer/HBoxContainer/NoButton
@onready var game_window: Control = $MinigameUI/GameWindow
@onready var game_result_panel: PanelContainer = $MinigameUI/GameResult
@onready var game_result_label: Label = $MinigameUI/GameResult/VBoxContainer/Label
@onready var close_result_button: Button = $MinigameUI/GameResult/VBoxContainer/HBoxContainer/CloseButton

# --- MATCH VARIABLES (Unique per table instance) ---
# ---------------------------------------------------
var seated_players: Array[int] = []
var board_state: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0] # 0=empty, 1=Player1 (X), 2=Player2 (O)
var current_turn_idx: int = 0 # Index of whose turn it is in seated_players
var am_i_player_one: bool = false
var result_timer: SceneTreeTimer = null # used to show game result for some seconds

func _ready() -> void:
	# ui popups hidden on startup
	game_prompt_panel.visible = false
	game_window.visible = false
	game_result_panel.visible = false
	
	# interaction area signals
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	
	# game prompt panel buttons
	join_button.pressed.connect(_on_join_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	
	# game result panel buttons
	close_result_button.pressed.connect(_on_close_result_button_pressed)

# show local game prompt upon entering game area
#
func _on_body_entered(body: Node) -> void:
	print("game area entered by %s" % body)
	game_prompt_panel.visible = true
	game_result_panel.visible = false

# close local game prompt / quit game upon leaving game area
#
func _on_body_exited(body: Node) -> void:
	# ignore if it wasn't a player that interacted
	if not is_instance_valid(body) or not body.is_inside_tree():
		return
	
	print("game area exited by %s" % body)
	game_prompt_panel.visible = false
	
	# if game is in progress, quit it
	if game_window.visible:
		_on_cancel_button_pressed()

# close local game prompt and request server to join game
#
func _on_join_button_pressed() -> void:
	print("%d requested to join game" % multiplayer.get_unique_id())
	game_prompt_panel.visible = false
	server_request_seat.rpc_id(1, multiplayer.get_unique_id())

# close local game prompt and game window, tell server to quit game for all players
#
func _on_cancel_button_pressed() -> void:
	print("%d cancelled game" % multiplayer.get_unique_id())
	game_prompt_panel.visible = false
	game_window.visible = false
	server_leave_seat.rpc_id(1, multiplayer.get_unique_id())

# show local game result
#
@rpc("authority", "call_local", "reliable")
func show_game_result(message: String) -> void:
	print("show game result for %d" % multiplayer.get_unique_id())
	game_result_label.text = message
	game_result_panel.visible = true
	
	# show result for a set amount of time..
	
	# Create and store timer
	var this_timer = get_tree().create_timer(5.0)
	result_timer = this_timer
	await this_timer.timeout
	
	# Only hide if this timer is STILL active and hasn't been cancelled/replaced
	if result_timer == this_timer:
		game_result_panel.visible = false
		result_timer = null

# close local game result
#
func _on_close_result_button_pressed() -> void:
	print("%d closed game result" % multiplayer.get_unique_id())
	game_result_panel.visible = false

# --- SERVER LOBBY LOGIC ---
# --------------------------

# add player to game, open local game window and sync state
#
@rpc("any_peer", "call_local", "reliable")
func server_request_seat(peer_id: int) -> void:
	# ignore request if.. 
	# not requested with server authority,
	# requested player is already seated at the game, 
	# or game full
	if not multiplayer.is_server(): return
	if seated_players.has(peer_id) or seated_players.size() >= 2: return 
	
	# add player to game
	seated_players.append(peer_id)
	print("player %d sitting at minigame" % peer_id)
	
	if seated_players.size() == 1:
		# display game board for player 1 and sync game state
		client_open_game.rpc_id(seated_players[0], true)
		sync_match_state.rpc_id(seated_players[0], board_state, current_turn_idx, seated_players)
		
	# there are now enough players to start the game
	if seated_players.size() == 2:
		# reset game state to start
		board_state.fill(0)
		current_turn_idx = 0
		
		# display game board for player 2
		client_open_game.rpc_id(seated_players[1], false)
		
		# sync game state for player 1 and player 2
		sync_match_state.rpc_id(seated_players[0], board_state, current_turn_idx, seated_players)
		sync_match_state.rpc_id(seated_players[1], board_state, current_turn_idx, seated_players)

# clear game state and end game for all players
#
@rpc("any_peer", "call_local", "reliable")
func server_leave_seat(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	
	# ensure only a player in the game can end the match
	if seated_players.has(peer_id):
		var notify_list = seated_players.duplicate()  # store temp list of players in game
		seated_players.clear()
		board_state.fill(0)
		current_turn_idx = 0
		
		# Server pushes cleared state & closes windows for all players in this match
		for player in notify_list:
			sync_match_state.rpc_id(player, board_state, current_turn_idx, seated_players)
			client_end_game.rpc_id(player, "Player %d left the game" % peer_id)

# --- SERVER GAMEPLAY LOGIC ---
# -----------------------------

# callback for when button/space on game board pressed
# register the move and check for win cond'ns
#
@rpc("any_peer", "call_local", "reliable")
func server_submit_move(cell_idx: int) -> void:
	return 
	#if not multiplayer.is_server(): return
	#var moving_peer = multiplayer.get_remote_sender_id()
	#
	## ignore click if space is already fileld, not enough players, or not their turn
	#if seated_players.size() < 2 or moving_peer != seated_players[current_turn_idx]:
		#return
	#if board_state[cell_idx] != 0:
		#return
	#
	## set 1 for player 1 (X), 2 for player 2 (O)
	#var marker = 1 if current_turn_idx == 0 else 2
	#board_state[cell_idx] = marker
	#
	## Check Win / Draw
	#if check_win_condition(marker) or not board_state.has(0):
		#var p1 = seated_players[0]
		#var p2 = seated_players[1]
		#
		#var is_draw = not check_win_condition(marker)
		#var p1_msg = "It's a Draw!" if is_draw else ("You Win!" if current_turn_idx == 0 else "You Lose!")
		#var p2_msg = "It's a Draw!" if is_draw else ("You Win!" if current_turn_idx == 1 else "You Lose!")
#
		## Reset server state first
		#board_state.fill(0)
		#current_turn_idx = 0
		#seated_players.clear()
		#
		## Sync cleared state to both clients before ending game
		#sync_match_state.rpc_id(p1, board_state, current_turn_idx, seated_players)
		#sync_match_state.rpc_id(p2, board_state, current_turn_idx, seated_players)
		#client_end_game.rpc_id(p1, p1_msg)
		#client_end_game.rpc_id(p2, p2_msg)
		#show_game_result.rpc_id(p1, p1_msg)
		#show_game_result.rpc_id(p2, p2_msg)
		#return
	#
	## set next player's turn and sync players' match states
	#current_turn_idx = 1 if current_turn_idx == 0 else 0
	#sync_match_state.rpc_id(seated_players[0], board_state, current_turn_idx, seated_players)
	#sync_match_state.rpc_id(seated_players[1], board_state, current_turn_idx, seated_players)

# check win cond'ns for tic-tac-toe
#
func check_win_condition(m: int) -> bool:
	return true
	#var b = board_state
	#return ((b[0]==m and b[1]==m and b[2]==m) or (b[3]==m and b[4]==m and b[5]==m) or (b[6]==m and b[7]==m and b[8]==m) or
			#(b[0]==m and b[3]==m and b[6]==m) or (b[1]==m and b[4]==m and b[7]==m) or (b[2]==m and b[5]==m and b[8]==m) or
			#(b[0]==m and b[4]==m and b[8]==m) or (b[2]==m and b[4]==m and b[6]==m))

# --- CLIENT SYNC LOGIC ---
# -------------------------

# show local game window
#
@rpc("authority", "call_local", "reliable")
func client_open_game(is_p1: bool) -> void:
	am_i_player_one = is_p1
	game_prompt_panel.visible = false
	game_window.visible = true
	result_timer = null
	print("%d opened game" % multiplayer.get_unique_id())

# set local game state variables to match server's master copies
#
@rpc("authority", "call_local", "reliable")
func sync_match_state(server_board: Array, server_turn_idx: int, server_seated_players: Array) -> void:
	board_state = server_board
	current_turn_idx = server_turn_idx
	seated_players = server_seated_players
	update_ui_grid()
	update_player_labels()
	print("sync match state for %d" % multiplayer.get_unique_id())

# reset game state and close local game window
#
@rpc("authority", "call_local", "reliable")
func client_end_game(result_text: String) -> void:
	print("Game Over (%d): %s" % [multiplayer.get_unique_id(), result_text])
	game_window.visible = false 
	result_timer = null
	board_state.fill(0)
	seated_players.clear()
	update_ui_grid()
	update_player_labels()

# set Xs and Os in UI according to board state
# only enable empty buttons/spaces for player's turn
#
func update_ui_grid() -> void:
	return
	#var grid_container = game_window.get_node_or_null("VBoxContainer/CenterContainer/GridContainer")
	#if not grid_container: return
	#
	#for i in range(9):
		#var btn = grid_container.get_child(i) as Button
		#if board_state[i] == 1:
			#btn.text = "X"
			#btn.disabled = true
		#elif board_state[i] == 2:
			#btn.text = "O"
			#btn.disabled = true
		#else:
			#btn.text = ""
			#var is_my_turn = (current_turn_idx == 0 and am_i_player_one) or (current_turn_idx == 1 and not am_i_player_one)
			#btn.disabled = not is_my_turn

# update player labels, bold whoever's turn it is
#
func update_player_labels() -> void:
	return
	#var player1_label = game_window.get_node_or_null("VBoxContainer/HBoxContainer2/Player1Label") as RichTextLabel
	#var player2_label = game_window.get_node_or_null("VBoxContainer/HBoxContainer2/Player2Label") as RichTextLabel
	#if not player1_label or not player2_label:
		#return
	#
	#var p1 = "Player 1"
	#var p2 = "Player 2" if seated_players.size() == 2 else "Waiting..."
	#
	#if seated_players.size() == 2:
		#if current_turn_idx == 0:
			#player1_label.text = "[center][b]► " + p1 + "[/b][/center]"
			#player2_label.text = "[center]" + p2 + "[/center]"
		#else:
			#player1_label.text = "[center]" + p1 + "[/center]"
			#player2_label.text = "[center][b]► " + p2 + "[/b][/center]"
	#else:
		#player1_label.text = "[center]" + p1 + "[/center]"
		#player2_label.text = "[center]" + p2 + "[/center]"
