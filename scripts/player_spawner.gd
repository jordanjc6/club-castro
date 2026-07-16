extends Node2D

const PLAYER_SCENE = preload("res://scenes/player/monkey.tscn")

@onready var spawn_point = $"spawn-point"
@onready var players = $players

func _ready():
	if multiplayer.is_server():
		spawn_player(multiplayer.get_unique_id())
		
		# set to listen for connections
		multiplayer.peer_connected.connect(_on_peer_connected)

func spawn_player(id):
	var player = PLAYER_SCENE.instantiate()

	# 1. Set the name first (so _enter_tree can read it)
	player.name = str(id)
	player.position = spawn_point.position
	player.set_player_id(id)

	# 2. Add to tree (This triggers _enter_tree() and configures the multiplayer authority)
	# Setting the second argument to true forces readable, synchronized node paths across peers
	players.add_child(player, true) 

	print("Spawned player: ", id)
	
func _on_peer_connected(id):
	print("New player joined:", id)
	spawn_player(id)
