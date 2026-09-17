extends Node2D

# define nodes for touch highlight/animate
@export var exit_polygon: Polygon2D
@export var exit_button:  Button

@export var theatre_entrance_polygon: Polygon2D
@export var theatre_entrance_button:  Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# press bbt exit mat signal for animation
	exit_button.pressed.connect(_on_exit_pressed)
	theatre_entrance_button.pressed.connect(_on_theatre_entrance_pressed)

func _on_exit_pressed() -> void:
	var touch_pos = get_global_mouse_position()
	
	# Move the player and check what type of character is currently active
	var is_singleplayer = _move_local_player_to_position(touch_pos)
	highlight_exit()

func _on_theatre_entrance_pressed() -> void:
	var touch_pos = get_global_mouse_position()
	
	# Move the player and check what type of character is currently active
	var is_singleplayer = _move_local_player_to_position(touch_pos)
	highlight_theatre_entrance()

func highlight_exit():
	var flash_tween = create_tween()
	exit_polygon.modulate.a = 0.5
	flash_tween.tween_property(exit_polygon, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func highlight_theatre_entrance():
	var flash_tween = create_tween()
	theatre_entrance_polygon.modulate.a = 0.5
	flash_tween.tween_property(theatre_entrance_polygon, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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
