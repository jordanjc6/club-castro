extends Node

const PORT = 9999

var peer


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
	
