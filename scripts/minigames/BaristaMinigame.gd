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

# todo:
#1 clear drinks from coaster on game over
#2 update order popup display, only hide on clicking an order
#3 create timer between game ending and being prompted to click to exit
#4 disable monkey movement on joining game

extends Node2D

const CUP_SCRIPT = preload("res://scripts/minigames/cup.gd")
const CUP_SIZES = CUP_SCRIPT.CupSize

const DISPENSER_SCRIPT = preload("res://scripts/minigames/dispenser.gd")
const FLAVORS = DISPENSER_SCRIPT.DrinkFlavor

const TOPPING_SCRIPT = preload("res://scripts/minigames/topping_spoon.gd")
const TOPPINGS = TOPPING_SCRIPT.Topping

@export var small_cup_scene: PackedScene
@export var medium_cup_scene: PackedScene
@export var large_cup_scene: PackedScene
@export var ice_scene: PackedScene
@export var tapioca_scene: PackedScene
@export var popping_boba_scene: PackedScene
@export var grass_jelly_scene: PackedScene
@export var pudding_scene: PackedScene
@export var correct_drink_tex: Texture2D
@export var incorrect_drink_tex: Texture2D
@export var drink_order_scene = preload("res://scenes/minigames/DrinkOrder.tscn")

@onready var hud: CanvasLayer = $"../../HUD"

# game prompt
@onready var interaction_area: Area2D = $InteractionArea
@onready var game_prompt_panel: PanelContainer = $MinigameUI/GamePrompt
@onready var join_button: Button = $MinigameUI/GamePrompt/VBoxContainer/HBoxContainer/YesButton
@onready var cancel_button: Button = $MinigameUI/GamePrompt/VBoxContainer/HBoxContainer/NoButton

# game window
@onready var game_window: Control = $MinigameUI/GameWindow
@onready var screen_overlay: Control = $MinigameUI/GameWindow/Overlay # doesn't include game result area
@onready var screen: Control = $MinigameUI/GameWindow/Screen
@onready var timer_label: Label = $MinigameUI/GameWindow/Screen/TimerLabel
@onready var score_label: Label = $MinigameUI/GameWindow/Screen/ScoreLabel
@onready var small_cup_spawner: Control = $MinigameUI/GameWindow/Screen/CupSpawners/SmallCupSpawner
@onready var medium_cup_spawner: Control = $MinigameUI/GameWindow/Screen/CupSpawners/MediumCupSpawner
@onready var large_cup_spawner: Control = $MinigameUI/GameWindow/Screen/CupSpawners/LargeCupSpawner
@onready var ice_spawner: Control = $MinigameUI/GameWindow/Screen/IceSpawner
@onready var tapioca_spawner: Control = $MinigameUI/GameWindow/Screen/ToppingSpawners/TapiocaSpawner
@onready var popping_boba_spawner: Control = $MinigameUI/GameWindow/Screen/ToppingSpawners/PoppingBobaSpawner
@onready var grass_jelly_spawner: Control = $MinigameUI/GameWindow/Screen/ToppingSpawners/GrassJellySpawner
@onready var pudding_spawner: Control = $MinigameUI/GameWindow/Screen/ToppingSpawners/PuddingSpawner
@onready var drink_status_icon1: TextureRect = $MinigameUI/GameWindow/Screen/Coasters/Coaster1/DrinkStatusIcon
@onready var drink_status_icon2: TextureRect = $MinigameUI/GameWindow/Screen/Coasters/Coaster2/DrinkStatusIcon
@onready var drink_status_icon3: TextureRect = $MinigameUI/GameWindow/Screen/Coasters/Coaster3/DrinkStatusIcon
@onready var orders_container = $MinigameUI/GameWindow/Screen/Orders

# send drink buttons
@onready var send_drink1_btn: Button = $MinigameUI/GameWindow/Screen/Coasters/Coaster1/SendButton
@onready var send_drink2_btn: Button = $MinigameUI/GameWindow/Screen/Coasters/Coaster2/SendButton
@onready var send_drink3_btn: Button = $MinigameUI/GameWindow/Screen/Coasters/Coaster3/SendButton

# drink orders
var orders: Array[Dictionary] = []
var order_timer: Timer

# --- MATCH TIMING & SCORE ---
var match_time_left: float = 120.0 # 2 minutes in seconds
var orders_completed: int = 0
var is_match_running: bool = false

# game result
@onready var game_result_panel: PanelContainer = $MinigameUI/GameResult
@onready var result_overlay: Control = $MinigameUI/GameResult/Overlay # handles clicks inside game result panel
@onready var game_result_label: Label = $MinigameUI/GameResult/VBoxContainer/Label

# --- MATCH VARIABLES (Unique per table instance) ---
# ---------------------------------------------------
var seated_players: Array[int] = []
var board_state: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0] # 0=empty, 1=Player1 (X), 2=Player2 (O)
var current_turn_idx: int = 0 # Index of whose turn it is in seated_players
var am_i_player_one: bool = false
var result_timer: SceneTreeTimer = null # used to show game result for some seconds
var drink_status_toaster_tween1: Tween
var drink_status_toaster_tween2: Tween
var drink_status_toaster_tween3: Tween


func _process(delta: float) -> void:
	if is_match_running:
		match_time_left -= delta
		
		if match_time_left <= 0:
			match_time_left = 0
			_end_match()
			
		_update_timer_display()

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
	
	# game window
	screen_overlay.visible = false
	result_overlay.visible = false
	small_cup_spawner.gui_input.connect(spawn_small_cup)
	medium_cup_spawner.gui_input.connect(spawn_medium_cup)
	large_cup_spawner.gui_input.connect(spawn_large_cup)
	ice_spawner.gui_input.connect(spawn_ice)
	tapioca_spawner.gui_input.connect(spawn_tapioca)
	popping_boba_spawner.gui_input.connect(spawn_popping_boba)
	grass_jelly_spawner.gui_input.connect(spawn_grass_jelly)
	pudding_spawner.gui_input.connect(spawn_pudding)
	drink_status_icon1.visible = false
	drink_status_icon2.visible = false
	drink_status_icon3.visible = false
	
	# send drink buttons
	send_drink1_btn.pressed.connect(send_drink.bind(1))
	send_drink2_btn.pressed.connect(send_drink.bind(2))
	send_drink3_btn.pressed.connect(send_drink.bind(3))
	
	# game result panel buttons
	screen_overlay.gui_input.connect(_on_screen_overlay_gui_input)
	result_overlay.gui_input.connect(_on_screen_overlay_gui_input)

# show local game prompt upon entering game area
#
func _on_body_entered(body: Node) -> void:
	var input_sync = body.get_node_or_null("InputSynchronizer")
		
	# only show popup for the player that entered
	if ( (input_sync and input_sync.is_multiplayer_authority()) or body.name == "SinglePlayer"):
		print("game area entered by %s" % body)
		hud.visible = false
		game_prompt_panel.visible = true
		game_result_panel.visible = false

# close local game prompt / quit game upon leaving game area
#
func _on_body_exited(body: Node) -> void:
	# ignore if it wasn't a player that interacted
	if not is_instance_valid(body) or not body.is_inside_tree():
		return
	
	var input_sync = body.get_node_or_null("InputSynchronizer")
		
	# only hide popup for the player that exited
	if ( (input_sync and input_sync.is_multiplayer_authority()) or body.name == "SinglePlayer"):
		print("game area exited by %s" % body)
		if body.name == "SinglePlayer":
			hud.visible = true
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

# Start game session timer & reset score
func _start_match() -> void:
	orders_completed = 0
	match_time_left = 120.0
	is_match_running = true
	start_orders_timer()
	_update_score_display()

func _update_timer_display() -> void:
	if timer_label:
		var minutes: int = int(match_time_left) / 60
		var seconds: int = int(match_time_left) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]

func _update_score_display() -> void:
	if score_label:
		score_label.text = "Orders: %d" % orders_completed

func reset_match_state() -> void:
	is_match_running = false
	order_timer.stop()
	order_timer = null
	orders = []
	match_time_left = 120.0
	orders_completed = 0
	seated_players = []
	result_timer = null
	game_prompt_panel.visible = false
	drink_status_icon1.visible = false
	drink_status_icon2.visible = false
	drink_status_icon3.visible = false
	# Clear all displayed ticket nodes
	for child in orders_container.get_children():
		child.queue_free()

func _end_match() -> void:
	is_match_running = false
	order_timer.stop()
	
	# Display final game results panel
	var result_msg = "Time's Up!\nOrders Completed: %d" % orders_completed
	show_game_result(result_msg)

func start_orders_timer() -> void:
	# generate one order and start order timer
	generate_random_order()
	spawn_drink_order()
	order_timer = Timer.new()
	order_timer.wait_time = 10.0
	order_timer.autostart = true
	order_timer.timeout.connect(_on_order_timer_timeout)
	add_child(order_timer)

func _on_order_timer_timeout() -> void:
	generate_random_order()
	spawn_drink_order()

func generate_random_order() -> void:
	# get random drink order
	var rand_size: CUP_SIZES = [CUP_SIZES.SMALL, CUP_SIZES.MEDIUM, CUP_SIZES.LARGE].pick_random()
	var rand_flavor: FLAVORS = [FLAVORS.MANGO, FLAVORS.MATCHA, FLAVORS.HONEYDEW, FLAVORS.TARO].pick_random() 
	var rand_ice: bool = [true, false].pick_random()
	var rand_tapioca: bool = [true, false].pick_random()
	var rand_boba: bool = [true, false].pick_random()
	var rand_jelly: bool = [true, false].pick_random()
	var rand_pudding: bool = [true, false].pick_random()

	# Save data to tracking array for validation
	var order = {
		"size": rand_size,
		"flavor": rand_flavor,
		"has_ice": rand_ice,
		"has_tapioca": rand_tapioca,
		"has_popping_boba": rand_boba,
		"has_grass_jelly": rand_jelly,
		"has_pudding": rand_pudding
	}
	orders.append(order)

func spawn_drink_order() -> void:
	var current_on_screen = orders_container.get_child_count()
	
	# Fill remaining open rack spots (up to 3 max) with undisplayed orders from queue
	while current_on_screen < 3 and current_on_screen < orders.size():
		var order_data = orders[current_on_screen]
		
		var new_ticket = drink_order_scene.instantiate()
		orders_container.add_child(new_ticket)
		new_ticket.set_order(order_data)
		
		# Set rack X position: Spot 0 = 40px, Spot 1 = 140px, Spot 2 = 240px
		new_ticket.position = Vector2(40 + (current_on_screen * 100), 175)
		
		current_on_screen += 1

func spawn_small_cup(event: InputEvent) -> void:
	# Trigger on initial left mouse click down
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if small_cup_scene == null:
			push_warning("Small cup scene not assigned in Inspector!")
			return
		
		var cup_instance = small_cup_scene.instantiate()
		screen.add_child(cup_instance)
		cup_instance.global_position = get_global_mouse_position()

func spawn_medium_cup(event: InputEvent) -> void:
	# Trigger on initial left mouse click down
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if medium_cup_scene == null:
			push_warning("Medium cup scene not assigned in Inspector!")
			return
		
		var cup_instance = medium_cup_scene.instantiate()
		screen.add_child(cup_instance)
		cup_instance.global_position = get_global_mouse_position()

func spawn_large_cup(event: InputEvent) -> void:
	# Trigger on initial left mouse click down
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if large_cup_scene == null:
			push_warning("Large cup scene not assigned in Inspector!")
			return
		
		var cup_instance = large_cup_scene.instantiate()
		screen.add_child(cup_instance)
		cup_instance.global_position = get_global_mouse_position()

func spawn_ice(event: InputEvent) -> void:
	# Trigger on initial left mouse click down
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if ice_scene == null:
			push_warning("Ice scene not assigned in Inspector!")
			return
		
		var ice_instance = ice_scene.instantiate()
		screen.add_child(ice_instance)
		ice_instance.global_position = get_global_mouse_position()

func spawn_tapioca(event: InputEvent) -> void:
	# Trigger on initial left mouse click down
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if tapioca_scene == null:
			push_warning("tapioca scene not assigned in Inspector!")
			return
		
		var tapioca_instance = tapioca_scene.instantiate()
		screen.add_child(tapioca_instance)
		tapioca_instance.global_position = get_global_mouse_position()

func spawn_popping_boba(event: InputEvent) -> void:
	# Trigger on initial left mouse click down
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if popping_boba_scene == null:
			push_warning("popping boba scene not assigned in Inspector!")
			return
		
		var popping_boba_instance = popping_boba_scene.instantiate()
		screen.add_child(popping_boba_instance)
		popping_boba_instance.global_position = get_global_mouse_position()

func spawn_grass_jelly(event: InputEvent) -> void:
	# Trigger on initial left mouse click down
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if grass_jelly_scene == null:
			push_warning("Ice scene not assigned in Inspector!")
			return
		
		var grass_jelly_instance = grass_jelly_scene.instantiate()
		screen.add_child(grass_jelly_instance)
		grass_jelly_instance.global_position = get_global_mouse_position()

func spawn_pudding(event: InputEvent) -> void:
	# Trigger on initial left mouse click down
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if pudding_scene == null:
			push_warning("Ice scene not assigned in Inspector!")
			return
		
		var pudding_instance = pudding_scene.instantiate()
		screen.add_child(pudding_instance)
		pudding_instance.global_position = get_global_mouse_position()

func send_drink(drink_id: int):
	var coaster_node = get_node_or_null("MinigameUI/GameWindow/Screen/Coasters/Coaster" + str(drink_id))
	if not coaster_node or coaster_node.current_cup == null:
		return
	
	var drink = coaster_node.current_cup
	if drink.is_filling:
		print("Cannot send drink while it is filling!")
		return
	
	var drink_data: Dictionary = drink.get_drink_data()
	var is_valid = check_and_fulfill_order(drink_data)
	
	show_send_drink_status_toaster(drink_id, is_valid)

	drink.queue_free()
	coaster_node.remove_cup()

func check_and_fulfill_order(submitted_drink: Dictionary) -> bool:
	# Only check the top 3 orders that are currently displayed on the rack
	var visible_count: int = min(3, orders.size())
	
	for i in range(visible_count):
		if matches_order(submitted_drink, orders[i]):
			# 1. Remove order from tracking array
			orders.remove_at(i)
			
			# Increment score & update counter text
			orders_completed += 1
			_update_score_display()
			
			# 2. Rebuild ticket UI rack (clears old nodes & pulls next pending order)
			_rebuild_ticket_ui()
			return true
			
	return false

func matches_order(d1: Dictionary, d2: Dictionary) -> bool:
	print("sent: %s\n order: %s\n" % [d1, d2])
	for key in d2.keys():
		if not d1.has(key) or d1[key] != d2[key]:
			return false
	return true

func _rebuild_ticket_ui() -> void:
	# Clear current ticket nodes from screen
	for child in orders_container.get_children():
		orders_container.remove_child(child)
		child.queue_free()
	
	# Render the first 3 orders in queue
	spawn_drink_order()

#func send_drink(drink_id: int):
	## Dynamically get the coaster node (Coaster1, Coaster2, Coaster3)
	#var coaster_node = get_node_or_null("MinigameUI/GameWindow/Screen/Coasters/Coaster" + str(drink_id))
	#
	#if not coaster_node:
		#push_warning("Coaster%d node not found!" % drink_id)
		#return
	#
	## Check if a cup is sitting on this coaster
	#var drink = coaster_node.current_cup
	#if drink != null:
		## Block submission if the cup is actively filling
		#if drink.is_filling:
			#print("Cannot send drink while it is filling!")
			#return
		#
		#var drink_data: Dictionary = drink.get_drink_data()
		#
		#print("Submitted Drink #%d: " % drink_id, drink_data)
		## Returns: {"size": 1, "flavor": "Mango", "has_ice": true, "toppings": [0, 2]}
#
		#var drink_is_valid = validate_drink(drink_data)
		#show_send_drink_status_toaster(drink_id, drink_is_valid)
#
		## Remove the cup from the workspace
		#drink.queue_free()
		#coaster_node.remove_cup()
	#else:
		#print("No drink on Coaster #%d to send!" % drink_id)

func validate_drink(drink: Dictionary):
	return drink in orders

func show_send_drink_status_toaster(drinkNum: int, isSuccess: bool):
	if isSuccess:
		print("order complete!")
	else:
		print("bad drink!")
	
	match drinkNum:
		1:
			# 1. Set texture based on status
			drink_status_icon1.texture = correct_drink_tex if isSuccess else incorrect_drink_tex
			
			# 2. Reset visibility/opacity
			drink_status_icon1.modulate.a = 1.0
			drink_status_icon1.show()

			# 3. Cancel running animation if player triggers multiple quickly
			if drink_status_toaster_tween1 and drink_status_toaster_tween1.is_running():
				drink_status_toaster_tween1.kill()

			# 4. Hold full opacity for 0.8s, then fade out over 0.3s
			drink_status_toaster_tween1 = create_tween()
			drink_status_toaster_tween1.tween_interval(0.8)
			drink_status_toaster_tween1.tween_property(drink_status_icon1, "modulate:a", 0.0, 0.3)
			drink_status_toaster_tween1.finished.connect(drink_status_icon1.hide)
		2:
			# 1. Set texture based on status
			drink_status_icon2.texture = correct_drink_tex if isSuccess else incorrect_drink_tex
			
			# 2. Reset visibility/opacity
			drink_status_icon2.modulate.a = 1.0
			drink_status_icon2.show()

			# 3. Cancel running animation if player triggers multiple quickly
			if drink_status_toaster_tween2 and drink_status_toaster_tween2.is_running():
				drink_status_toaster_tween2.kill()

			# 4. Hold full opacity for 0.8s, then fade out over 0.3s
			drink_status_toaster_tween2 = create_tween()
			drink_status_toaster_tween2.tween_interval(0.8)
			drink_status_toaster_tween2.tween_property(drink_status_icon2, "modulate:a", 0.0, 0.3)
			drink_status_toaster_tween2.finished.connect(drink_status_icon2.hide)
		3:
			# 1. Set texture based on status
			drink_status_icon3.texture = correct_drink_tex if isSuccess else incorrect_drink_tex
			
			# 2. Reset visibility/opacity
			drink_status_icon3.modulate.a = 1.0
			drink_status_icon3.show()

			# 3. Cancel running animation if player triggers multiple quickly
			if drink_status_toaster_tween3 and drink_status_toaster_tween3.is_running():
				drink_status_toaster_tween3.kill()

			# 4. Hold full opacity for 0.8s, then fade out over 0.3s
			drink_status_toaster_tween3 = create_tween()
			drink_status_toaster_tween3.tween_interval(0.8)
			drink_status_toaster_tween3.tween_property(drink_status_icon3, "modulate:a", 0.0, 0.3)
			drink_status_toaster_tween3.finished.connect(drink_status_icon3.hide)

# show local game result
#
@rpc("authority", "call_local", "reliable")
func show_game_result(message: String) -> void:
	print("show game result for %d" % multiplayer.get_unique_id())
	game_result_label.text = message + "\n\n Click anywhere to exit..."
	game_result_panel.visible = true
	screen_overlay.visible = true
	result_overlay.visible = true

func _on_screen_overlay_gui_input(event: InputEvent) -> void:
	var is_click = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var is_touch = event is InputEventScreenTouch and event.pressed
	
	if is_click or is_touch:
		get_viewport().set_input_as_handled()
		
		# Close result panel & reset
		game_result_panel.visible = false
		game_window.visible = false
		screen_overlay.visible = false
		result_overlay.visible = false
		reset_match_state()

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
		# 1. Remove ONLY the player who left
		seated_players.erase(peer_id)
		
		# 2. Tell ONLY the leaving player to close their game window
		client_end_game.rpc_id(peer_id, "You left the game")
		
		# 3. Sync updated player list to any remaining players
		for player in seated_players:
			sync_match_state.rpc_id(player, board_state, current_turn_idx, seated_players)

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
	_start_match()

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
