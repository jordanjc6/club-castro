extends MultiplayerSynchronizer

var input_direction


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		set_process(false)
		set_physics_process(false)
	input_direction = Input.get_vector("walk-left", "walk-right", "walk-backward", "walk-forward")

func _physics_process(delta):
	input_direction = Input.get_vector("walk-left", "walk-right", "walk-backward", "walk-forward")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
