extends GridContainer

func _ready() -> void:
	# Loop through all 9 buttons inside this grid container
	for i in get_child_count():
		var btn = get_child(i) as Button
		
		# Clear any default text and make them square block sizes
		btn.text = ""
		btn.custom_minimum_size = Vector2(80, 80) 
		
		# Connect the click event dynamically
		btn.pressed.connect(func():
			# Path: GridContainer -> VBox/Center -> VBoxContainer -> GameWindow -> MinigameUI -> MinigameArea
			# Adjust the number of parent dots depending on your exact nesting!
			var minigame_root = get_node("../../../../..") 
			
			# Send the clicked index (0 through 8) directly to the server referee
			minigame_root.server_submit_move.rpc_id(1, i)
		)
