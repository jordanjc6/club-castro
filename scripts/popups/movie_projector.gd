extends Node2D

# define nodes for touch highlight/animate
@export var projector_polygon: Polygon2D
@export var projector_button:  Button

var movies: Array = [
	preload("res://assets/videos/monkey-space.ogv"),
	preload("res://assets/videos/monkey-hero.ogv"),
	preload("res://assets/videos/monkey-soccer.ogv"),
	preload("res://assets/videos/monkey-court.ogv"),
	preload("res://assets/videos/monkey-ghost.ogv"),
	preload("res://assets/videos/monkey-school.ogv")
]

# Global variables (meant to be shared with all clients in multiplayer)
var current_movie_index: int = -1
var is_movie_selector_open: bool = false


func _ready() -> void:
	# press projector for animation
	projector_button.pressed.connect(_on_projector_pressed)
	
	# If this machine is the host, listen for late-joining players
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
	
	# bind movie selector btns
	var buttons = %MovieSelector.find_children("", "Button")
	for i in range(buttons.size()):
		buttons[i].pressed.connect(_on_movie_selected.bind(i))

func _on_projector_pressed() -> void:
	var touch_pos = get_global_mouse_position()
	
	# Move the player and check what type of character is currently active
	var is_singleplayer = _move_local_player_to_position(touch_pos)
	highlight_projector()

func highlight_projector():
	print("highlight")
	var flash_tween = create_tween()
	projector_polygon.modulate.a = 0.5
	flash_tween.tween_property(projector_polygon, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _move_local_player_to_position(target_pos: Vector2) -> bool:
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		# Check for Multiplayer character
		if player is MultiPlayer and player.is_local_player():
			player.request_move_target.rpc(target_pos)
			return false # Is NOT singleplayer
			
		# Check for Singleplayer character (by node name or class)
		elif player.name == "SinglePlayer" or player.has_method("set_move_target"):
			player.set_move_target(target_pos)
			return true # IS singleplayer
			
	return false

func _on_movie_projector_area_entered(body: Node2D) -> void:
	print("Movie projector interacted with by %s" % body)
	%MovieSelector.visible = true
	is_movie_selector_open = true

func _on_movie_projector_area_exited(body: Node2D) -> void:
	print("Movie projector area exited by %s" % body)
	%MovieSelector.visible = false
	is_movie_selector_open = false

func _on_movie_selected(index: int) -> void:
	print("Movie %d selected" % (index + 1))
	rpc("sync_movie_selection", index)

func _on_peer_connected(peer_id: int) -> void:
	# Catch up late joiners: send them the current movie and time
	if current_movie_index != -1:
		rpc_id(peer_id, "sync_movie_selection", current_movie_index)
		rpc_id(peer_id, "sync_time", %VideoStreamPlayer.stream_position)
	
	# match state of movie selector visibility 
	%MovieSelector.visible = is_movie_selector_open

# "any_peer" allows clients to select movies, "call_local" runs it for the host too
@rpc("any_peer", "call_local", "reliable")
func sync_movie_selection(index: int) -> void:
	%MovieSelector.visible = false
	is_movie_selector_open = false
	current_movie_index = index
	%VideoStreamPlayer.stream = movies[index]
	%VideoStreamPlayer.play()

# Direct sync RPC for late-joiner timestamps
@rpc("any_peer", "call_remote", "reliable")
func sync_time(position: float) -> void:
	%VideoStreamPlayer.stream_position = position
