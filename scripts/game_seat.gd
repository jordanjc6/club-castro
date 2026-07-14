extends Node2D

@export var game_scene: PackedScene

const MAX_PLAYERS = 2

var players = []
var waiting_popup
var prompt_open = false
var waiting_lobby_active = false

func _on_gameseat_entered(body: Node2D) -> void:
	if body is CharacterBody2D and !prompt_open and !waiting_lobby_active:
		prompt_open = true
		print("show game prompt")
		SceneManager.show_prompt_popup(self)
			
func join_game(player_id):
	if players.size() < MAX_PLAYERS and player_id not in players:
		players.append(player_id)
		print(player_id, " joined the table")

		if players.size() == 1:
			print("show waiting popup")
			waiting_lobby_active = true
			waiting_popup = SceneManager.show_waiting_popup(self)

		elif players.size() == MAX_PLAYERS:
			start_game()
			
func leave_game(player_id):
	if player_id in players:
		players.erase(player_id)
		print(player_id, " left the table")
		
		if waiting_popup:
			waiting_popup.update_players()
			
func close_lobby():
	waiting_popup = null
	waiting_lobby_active = false

func start_game():
	print("start game!")
	#SceneManager.start_game(game_scene)
