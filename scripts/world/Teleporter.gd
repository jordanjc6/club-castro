extends Area2D

# Note: can set target_position and new_zone_offset in each area2d that Teleporter
# script is attached to in inspector -> Target Position, New Zone Offset.
# Below values is just example calculations.

# The center coordinate of the new CanvasLayer area
# = (x, y) 
# = ( x offset of canvaslayer + (viewport width / 2) , y offset of canvaslayer + (viewport height / 2) )
@export var target_position: Vector2 = Vector2(1500 + (1280 / 2), 720 / 2)

# The exact top-left corner coordinate (Offset) of the new CanvasLayer (BBT shop)
# = (x, y)
# = ( x offset of canvaslayer, y offset of canvaslayer )
@export var new_zone_offset: Vector2 = Vector2(1500, 0)

func _on_body_entered(body: Node2D):
	# Only the server evaluates physical scene changes and collision overrides
	if not multiplayer.is_server() && body.name != "SinglePlayer":
		return
	
	print("teleporter entered by %s" % body)
	
	# Check if the entering body is a player
	if body is CharacterBody2D:
		# Tell the specific player instance to trigger their local screen fade
		if body.has_method("play_teleport_fade"):
			if (body.name == "SinglePlayer"):
				body.play_teleport_fade()
			else:
				body.play_teleport_fade.rpc_id(body.player_id)
			
		# Small optional delay (e.g., 0.15s) so the screen is partially dark 
		# before the physical position and camera snap over
		await get_tree().create_timer(0.45).timeout
		
		# Update the grid offset on the client controlling this player
		if body.has_method("update_zone_offset"):
			if (body.name == "SinglePlayer"):
				body.update_zone_offset(new_zone_offset)
			else:
				body.update_zone_offset.rpc_id(body.player_id, new_zone_offset)
		
		# Perform the actual physical move
		body.global_position = target_position
