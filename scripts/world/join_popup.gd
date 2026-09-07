extends PanelContainer

@onready var join_popup: PanelContainer = self

# Attach this script to your JoinPopup container
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if join_popup.get_node("VBoxContainer/Code").has_focus():
			join_popup.get_node("VBoxContainer/Code").release_focus()
