extends Node2D

func _draw() -> void:
	var controller = get_node_or_null("/root/World/MinigolfMinigame") # Adjust path if needed
	if not is_instance_valid(controller):
		controller = get_tree().get_first_node_in_group("minigolf_controller")
		
	if controller == null or controller.current_ball_state != controller.BallState.AIMING:
		return

	if not controller.player_data.has(controller.current_turn_id):
		return

	var active_ball = controller.player_data[controller.current_turn_id]["ball_node"] as RigidBody2D
	if not is_instance_valid(active_ball):
		return

	# Convert ball global pos to local overlay space
	var ball_pos = to_local(active_ball.global_position)
	var local_start = to_local(controller.drag_start_pos)
	var local_curr = to_local(controller.current_drag_pos)
	var drag_vector = local_start - local_curr
	
	var distance = clamp(drag_vector.length(), 0.0, controller.MAX_POWER_DISTANCE)
	var power_percent = distance / controller.MAX_POWER_DISTANCE

	if power_percent < 0.05:
		return

	var aim_dir = drag_vector.normalized()
	var line_length = distance * 2.0
	var main_line_end = ball_pos + (aim_dir * line_length)

	var spread_angle = 0.0
	if power_percent > controller.ACCURACY_THRESHOLD:
		var excess_power = (power_percent - controller.ACCURACY_THRESHOLD) / (1.0 - controller.ACCURACY_THRESHOLD)
		spread_angle = excess_power * controller.MAX_DEVIATION_ANGLE

	var line_color = Color.WHITE.lerp(Color.YELLOW, power_percent) if power_percent < controller.ACCURACY_THRESHOLD else Color.YELLOW.lerp(Color.RED, (power_percent - controller.ACCURACY_THRESHOLD) / 0.5)

	if spread_angle <= 0.001:
		draw_line(ball_pos, main_line_end, line_color, 4.0)
		draw_circle(main_line_end, 8.0, line_color)
	else:
		var left_dir = aim_dir.rotated(-spread_angle)
		var right_dir = aim_dir.rotated(spread_angle)

		var left_end = ball_pos + (left_dir * line_length)
		var right_end = ball_pos + (right_dir * line_length)

		draw_line(ball_pos, left_end, line_color, 3.0)
		draw_line(ball_pos, right_end, line_color, 3.0)
		draw_line(left_end, right_end, line_color, 2.0)

		var cone_points = PackedVector2Array([ball_pos, left_end, right_end])
		var fill_color = Color(line_color.r, line_color.g, line_color.b, 0.25)
		draw_polygon(cone_points, PackedColorArray([fill_color, fill_color, fill_color]))
		draw_line(ball_pos, main_line_end, Color(1, 1, 1, 0.4), 1.5)
