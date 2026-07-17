extends Node2D

const PLAYER_SCENE = preload("res://scenes/player/monkey.tscn")

@onready var spawn_point = $"spawn-point"
@onready var players = $players


func _ready():
	if multiplayer.is_server():
		spawn_player(multiplayer.get_unique_id())


func spawn_player(id):
	var player = PLAYER_SCENE.instantiate()

	player.name = str(id)

	player.position = spawn_point.position

	player.set_multiplayer_authority(id)

	players.add_child(player)

	print("Spawned player: ", id)
	
