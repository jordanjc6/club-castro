extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var monkey = $AnimatedSprite2D

@export var synced_animation: String = "standing-front"
@export var synced_flip: bool = false

# This flag stops the client's physics from overriding the server's spawn point
var has_synced_spawn := false
var player_id := 0

func _enter_tree():
	var id = name.to_int()
	set_multiplayer_authority(id)
	
	# Automatically find and set authority on your synchronizer, no matter its name
	for child in get_children():
		if child is MultiplayerSynchronizer:
			child.set_multiplayer_authority(id)
			
	# If this is the client controlling this monkey, pause its physics briefly
	if is_multiplayer_authority():
		_wait_for_spawn_sync()

func _wait_for_spawn_sync():
	await get_tree().physics_frame
	has_synced_spawn = true

func set_player_id(id):
	player_id = id

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		# 1. Stop processing if we haven't received the spawn coordinates yet
		if not has_synced_spawn:
			return 
			
		var direction := Input.get_vector("walk-left", "walk-right", "walk-backward", "walk-forward")
		
		if direction != Vector2.ZERO:
			velocity = direction * SPEED
			update_walk_animation(direction)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, SPEED)
			set_monkey_animation("standing-front")

		move_and_slide()
	
func set_monkey_animation(anim_name:String):
	synced_animation = anim_name
	if monkey.animation != anim_name:
		monkey.play(anim_name)
	
func update_walk_animation(dir: Vector2) -> void:
	# diagonal up-right
	if dir.x > 0 and dir.y > 0:
		set_monkey_animation("walking-front-diagonal")
		synced_flip = false
		monkey.flip_h = false
	# diagonal down-right
	elif dir.x > 0 and dir.y < 0:
		set_monkey_animation("walking-back-diagonal")
		synced_flip = false
		monkey.flip_h = false
	# diagonal up-left
	elif dir.x < 0 and dir.y > 0:
		set_monkey_animation("walking-front-diagonal")
		synced_flip = true
		monkey.flip_h = true
	# diagonal down-left
	elif dir.x < 0 and dir.y < 0:
		set_monkey_animation("walking-back-diagonal")
		synced_flip = true
		monkey.flip_h = true
	# only vertical
	elif dir.y != 0:
		if dir.y > 0:
			set_monkey_animation("walking-front")
		else:
			set_monkey_animation("walking-back")
		synced_flip = false
		monkey.flip_h = false
	# only horizontal
	elif dir.x != 0:
		set_monkey_animation("walking-side")
		synced_flip = (dir.x < 0)
		monkey.flip_h = (dir.x < 0)
		
func _process(delta):
	if not is_multiplayer_authority():
		if monkey.animation != synced_animation:
			monkey.play(synced_animation)

		monkey.flip_h = synced_flip
