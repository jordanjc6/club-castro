extends Area2D

#@export var target_position: Vector2 = Vector2(500, 500)
@export var target_position: Vector2 = Vector2(2000, 2000)


func _on_body_entered(body: Node2D):
	# 1. Only the server evaluates physical scene changes and collision overrides
	if not multiplayer.is_server():
		return
	
	print("teleporter entered by %s" % body)
	
	# 2. Check if the entering body is a player
	if body is CharacterBody2D:
		# 1. Tell the specific player instance to trigger their local screen fade
		if body.has_method("play_teleport_fade"):
			body.play_teleport_fade.rpc_id(body.player_id)
			
		# 2. Small optional delay (e.g., 0.15s) so the screen is partially dark 
		# before the physical position and camera snap over
		await get_tree().create_timer(0.45).timeout
		
		# 3. Perform the actual physical move
		body.global_position = target_position
