class BlackHoleExplosionEffect extends Node2D:
	var progress: float = 0.0
	var particles: Array = []
	const NUM_PARTICLES = 26

	func _ready() -> void:
		# Generate supernova confetti / spark particles
		for i in range(NUM_PARTICLES):
			var angle = randf() * TAU
			var speed = randf_range(160.0, 320.0)
			
			# Supernova color palette: Yellow, Orange, Red, Electric Blue, White
			var colors = [
				Color(1.0, 0.95, 0.4), # Bright Yellow
				Color(1.0, 0.5, 0.1),  # Orange
				Color(0.9, 0.2, 0.2),  # Deep Red
				Color(0.3, 0.8, 1.0),  # Electric Blue (Tinge)
				Color(1.0, 1.0, 1.0)   # White hot spark
			]
			
			particles.append({
				"vel": Vector2(cos(angle), sin(angle)) * speed,
				"color": colors.pick_random(),
				"size": randf_range(2.5, 5.5), # Thin, sharp confetti sparks
				"drag": randf_range(2.5, 5.0)
			})
		
		# Animation tween (lasts 0.65 seconds)
		var tween = create_tween()
		tween.tween_property(self, "progress", 1.0, 0.65)\
			.set_ease(Tween.EASE_OUT)\
			.set_trans(Tween.TRANS_QUAD)
			
		tween.finished.connect(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var alpha = 1.0 - progress
		
		# 1. Expanding Shockwave Ring & Dusty Cosmic Smoke
		var shockwave_radius = progress * 70.0
		
		# Dusty smoke cloud with a soft blue-grey tinge fading outward
		var smoke_color = Color(0.25, 0.35, 0.55, alpha * 0.45)
		draw_circle(Vector2.ZERO, shockwave_radius * 0.85, smoke_color)
		
		# Sharp outer shockwave ring (White fading to cyan/blue)
		var ring_color = Color(0.75, 0.9, 1.0, alpha * 0.75)
		draw_arc(Vector2.ZERO, shockwave_radius, 0, TAU, 32, ring_color, 2.5)
		
		# 2. Glowing Central Core Flash (Supernova ignition)
		if progress < 0.4:
			var core_fade = 1.0 - (progress / 0.4)
			draw_circle(Vector2.ZERO, (1.0 - progress) * 30.0, Color(1.0, 1.0, 0.9, core_fade * 0.85))
			draw_circle(Vector2.ZERO, (1.0 - progress) * 12.0, Color(0.4, 0.85, 1.0, core_fade))

		# 3. Supernova Confetti / Sparks Bursting Outwards
		for p in particles:
			var eased_prog = progress * (1.0 - progress * 0.3)
			var current_pos = p["vel"] * eased_prog * (0.5 / p["drag"])
			
			var p_alpha = max(0.0, 1.0 - progress * 1.3)
			var col = p["color"]
			col.a = p_alpha
			
			var sz = p["size"] * (1.0 - progress * 0.4)
			
			if p_alpha > 0.0:
				draw_circle(current_pos, sz, col)
