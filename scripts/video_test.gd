extends Node2D

@onready var file_dialog: FileDialog = $FileDialog
@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer

func _ready() -> void:
	# Check if running on an Apple ecosystem device
	var is_apple_os: bool = (OS.get_name() == "iOS" or OS.get_name() == "macOS")
	
	# Verify the plugin is installed and ready to be used
	if is_apple_os and Engine.has_singleton("AppleFilePicker"):
		print("Apple OS detected. Launching native system file menu...")
		var apple_picker = Engine.get_singleton("AppleFilePicker")
		
		# Connect the native completion signal to our loading function
		apple_picker.connect("file_picked", _on_file_loaded)
		
		# Open native picker using Uniform Type Identifiers for Ogg files
		apple_picker.open_document_picker(["public.ogg", "org.xiph.ogv"])
		
	else:
		print("Running on Windows (or plugin missing). Launching internal FileDialog.")
		# open default file explorer
		file_dialog.popup_centered()

# Receiver function for your scene's built-in FileDialog node
func _on_file_dialog_file_selected(path: String) -> void:
	# Pass the file path straight into our unified playback handler
	_on_file_loaded(path)

# Unified video playback logic used by both Windows and Apple file pickers
func _on_file_loaded(path: String) -> void:
	print("Video path retrieved: ", path)
	
	# Instantiate a clean Ogg Theora video stream container
	var selected_video = VideoStreamTheora.new()
	selected_video.file = path
	
	# Update the stream and kick off playback
	video_player.stream = selected_video
	video_player.play()
