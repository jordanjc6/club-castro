extends Node2D

@onready var file_dialog: FileDialog = $FileDialog
@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer

func _ready() -> void:
	# open native file explorer
	file_dialog.popup_centered()

func _on_file_dialog_file_selected(path: String) -> void:
	# Create a new blank video stream instance
	var selected_video = VideoStreamTheora.new()
	
	# Set its target file path directly from the explorer
	selected_video.file = path
	
	# Assign and play
	video_player.stream = selected_video
	video_player.play()
