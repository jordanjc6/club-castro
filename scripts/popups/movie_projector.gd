extends Node2D

var movies: Array = [
	preload("res://assets/videos/madeira.ogv"),
	preload("res://assets/videos/paredes.ogv")
]


func _on_movie_projector_area_entered(body: Node2D) -> void:
	print("Movie projector interacted with by %s" % body)
	%MovieSelector.visible = true


func _on_movie_1_pressed() -> void:
	print("Movie 1 selected")
	%MovieSelector.visible = false
	%VideoStreamPlayer.stream = movies[0]
	%VideoStreamPlayer.play()


func _on_movie_2_pressed() -> void:
	print("Movie 2 selected")
	%MovieSelector.visible = false
	%VideoStreamPlayer.stream = movies[1]
	%VideoStreamPlayer.play()
