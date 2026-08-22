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
@onready var exit_button: Button = $MinigameUI/GameWindow/Screen/ExitButton
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

# exit confirmation
@onready var exit_panel: PanelContainer = $MinigameUI/ExitConfirmation
@onready var confirm_exit_btn: Button = $MinigameUI/ExitConfirmation/VBoxContainer/HBoxContainer/YesButton
@onready var cancel_exit_btn: Button = $MinigameUI/ExitConfirmation/VBoxContainer/HBoxContainer/NoButton

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
var order_count: int = 0


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
	exit_panel.visible = false
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
	exit_button.gui_input.connect(_on_exit_button)
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
	
	# exit confirmation
	confirm_exit_btn.gui_input.connect(exit_confirmed)
	cancel_exit_btn.gui_input.connect(exit_cancelled)

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

func _on_body_exited(body: Node) -> void:
	if not is_instance_valid(body) or not body.is_inside_tree():
		return
	
	if body.name == "SinglePlayer":
		hud.visible = true
		game_prompt_panel.visible = false
		if game_window.visible:
			_on_cancel_button_pressed()
		return

	var input_sync = body.get_node_or_null("InputSynchronizer")
	# Check is_inside_tree on input_sync before calling authority
	if input_sync and input_sync.is_inside_tree() and input_sync.is_multiplayer_authority():
		print("game area exited by %s" % body)
		game_prompt_panel.visible = false
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

func _on_exit_button(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("exit btn clicked")
		exit_panel.visible = true
		screen_overlay.visible = true
		order_timer.paused = true
		is_match_running = false

func exit_confirmed(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("exit confirmed")
		exit_panel.visible = false
		_end_match()

func exit_cancelled(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("exit cancelled")
		exit_panel.visible = false
		screen_overlay.visible = false
		order_timer.paused = false
		is_match_running = true

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
	screen_overlay.gui_input.disconnect(_on_screen_overlay_gui_input)
	result_overlay.gui_input.disconnect(_on_screen_overlay_gui_input)
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
	# Clear all spawned cup nodes
	for child in screen.get_children():
		if child.get_script() == CUP_SCRIPT:
			child.queue_free()
	# Clear active dispenser
	for dispenser in get_tree().get_nodes_in_group("dispenser"):
		dispenser.is_active = false
		if dispenser.has_method("_update_modulate"):
			dispenser._update_modulate()
	set_local_player_movement_disabled(false)

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
		"number": order_count + 1,
		"size": rand_size,
		"flavor": rand_flavor,
		"has_ice": rand_ice,
		"has_tapioca": rand_tapioca,
		"has_popping_boba": rand_boba,
		"has_grass_jelly": rand_jelly,
		"has_pudding": rand_pudding
	}
	orders.append(order)
	order_count += order_count

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
		if key == "number":
			continue
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
	game_result_label.text = message
	game_result_panel.visible = true
	screen_overlay.visible = true
	result_overlay.visible = true
	
	await get_tree().create_timer(2).timeout
	game_result_label.text = message + "\n\n Click anywhere to exit..."
	screen_overlay.gui_input.connect(_on_screen_overlay_gui_input)
	result_overlay.gui_input.connect(_on_screen_overlay_gui_input)

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

# --- CLIENT SYNC LOGIC ---
# -------------------------

# show local game window
#
@rpc("authority", "call_local", "reliable")
func client_open_game(is_p1: bool) -> void:
	set_local_player_movement_disabled(true)
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

func get_local_player() -> CharacterBody2D:
	# 1. Singleplayer Check
	var singleplayer = get_tree().root.find_child("SinglePlayer", true, false)
	if is_instance_valid(singleplayer):
		return singleplayer
		
	# 2. Multiplayer Check: Match node name to unique multiplayer peer ID
	var local_id_str = str(multiplayer.get_unique_id())
	var players_container = get_tree().root.find_child("Players", true, false)
	
	if is_instance_valid(players_container):
		# Look for node named after this local machine's peer ID (e.g. "1" or "112267552")
		var local_node = players_container.get_node_or_null(local_id_str)
		if is_instance_valid(local_node):
			return local_node
			
		# Fallback: Find child with multiplayer authority
		for child in players_container.get_children():
			if child is MultiPlayer and child.is_multiplayer_authority():
				return child
				
	return null

func set_local_player_movement_disabled(disabled: bool) -> void:
	var player = get_local_player()
	if player and player.has_method("set_movement_disabled"):
		# Use rpc if it's a MultiPlayer node to ensure the server registers the disable flag
		if player is MultiPlayer:
			player.set_movement_disabled.rpc(disabled)
		else:
			player.set_movement_disabled(disabled)
