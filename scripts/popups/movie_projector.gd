extends Node2D

var movies: Array = [
	preload("res://assets/videos/monkey-space.ogv"),
	preload("res://assets/videos/monkey-hero.ogv"),
	preload("res://assets/videos/monkey-soccer.ogv"),
	preload("res://assets/videos/monkey-court.ogv"),
	preload("res://assets/videos/monkey-ghost.ogv"),
	preload("res://assets/videos/monkey-ghost.ogv")
]

# Global variables (meant to be shared with all clients in multiplayer)
var current_movie_index: int = -1
var is_movie_selector_open: bool = false


func _ready() -> void:
	# If this machine is the host, listen for late-joining players
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
	
	# bind movie selector btns
	var buttons = %MovieSelector.find_children("", "Button")
	for i in range(buttons.size()):
		buttons[i].pressed.connect(_on_movie_selected.bind(i))

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
