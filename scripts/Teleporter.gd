extends Area2D

@export var target_position: Vector2 = Vector2(500, 500)
#@export var target_position: Vector2 = Vector2(2000, 2000)


func _on_body_entered(body: Node2D):
	# 1. Only the server evaluates physical scene changes and collision overrides
	if not multiplayer.is_server():
		return
	
	print("teleporter entered by %s" % body)
	
	# 2. Check if the entering body is a player
	if body is CharacterBody2D:
		# 3. Teleport the specific player node that touched the area
		body.global_position = target_position
