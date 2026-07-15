extends Node

const PORT = 9999

var peer

# set listeners to log connection statuses
func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game():
	peer = ENetMultiplayerPeer.new()

	var error = peer.create_server(PORT)

	if error != OK:
		print("Failed to host")
		return

	multiplayer.multiplayer_peer = peer

	print("Hosting game")

func join_game(ip_address):
	peer = ENetMultiplayerPeer.new()

	var error = peer.create_client(ip_address, PORT)

	if error != OK:
		print("Failed to join")
		return

	multiplayer.multiplayer_peer = peer

	print("Joining game")

func _on_peer_connected(id):
	print("Peer connected: ", id)

func _on_peer_disconnected(id):
	print("Peer disconnected: ", id)

func _on_connected_to_server():
	print("Successfully connected to server!")

func _on_connection_failed():
	print("Connection failed!")

func _on_server_disconnected():
	print("Disconnected from server!")
