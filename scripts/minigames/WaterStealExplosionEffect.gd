class WaterStealExplosionEffect extends Node2D:
	var progress: float = 0.0
	var sparks: Array = []
	const NUM_SPARKS = 22

	func _ready() -> void:
		# Generate fiery glowing sparks / embers bursting from the blast
		for i in range(NUM_SPARKS):
			var angle = randf() * TAU
			var speed = randf_range(120.0, 260.0)
			
			var colors = [
				Color(1.0, 1.0, 0.6), # Bright Yellow-White core spark
				Color(1.0, 0.5, 0.1), # Orange
				Color(0.9, 0.15, 0.05) # Deep Fiery Red
			]
			
			sparks.append({
				"vel": Vector2(cos(angle), sin(angle)) * speed,
				"color": colors.pick_random(),
				"size": randf_range(3.0, 6.0),
				"drag": randf_range(2.0, 4.0)
			})
		
		# Animation tween (lasts 1.0 second for full rising mushroom effect)
		var tween = create_tween()
		tween.tween_property(self, "progress", 1.0, 1.0)\
			.set_ease(Tween.EASE_OUT)\
			.set_trans(Tween.TRANS_QUAD)
			
		tween.finished.connect(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		# Overall alpha fades out during the second half of the animation
		var alpha = clamp((1.0 - progress) * 1.5, 0.0, 1.0)
		
		# 1. INITIAL FIERY BLAST / SHOCKWAVE (First 40% of animation)
		if progress < 0.45:
			var blast_prog = progress / 0.45
			var blast_radius = blast_prog * 55.0
			var blast_alpha = (1.0 - blast_prog)
			
			# Outer red/orange fireball ring
			draw_circle(Vector2.ZERO, blast_radius, Color(0.9, 0.3, 0.05, blast_alpha * 0.8))
			# Inner yellow/white intense flash
			draw_circle(Vector2.ZERO, blast_radius * 0.6, Color(1.0, 0.85, 0.3, blast_alpha))
			draw_circle(Vector2.ZERO, blast_radius * 0.25, Color(1.0, 1.0, 1.0, blast_alpha))

		# 2. RISING MUSHROOM CLOUD (Starts scaling up and rising after 20% progress)
		var nuke_prog = clamp((progress - 0.15) / 0.85, 0.0, 1.0)
		if nuke_prog > 0.0:
			# Rising height offset (-y goes upward in 2D)
			var rise_height = nuke_prog * 50.0
			var stem_top = Vector2(0, -rise_height * 0.6)
			var cap_center = Vector2(0, -rise_height)
			
			# Smoke / Fire Colors (Dark grey/brown smoke with fiery orange core tint)
			var smoke_alpha = alpha * 0.85
			var outer_smoke = Color(0.25, 0.22, 0.2, smoke_alpha)
			var inner_fire = Color(0.8, 0.35, 0.1, smoke_alpha * 0.7)
			
			# A. Draw the Rising Stem
			draw_line(Vector2(0, 5), stem_top, outer_smoke, 12.0 * (0.5 + nuke_prog * 0.5), true)
			draw_line(Vector2(0, 5), stem_top, inner_fire, 6.0 * (0.5 + nuke_prog * 0.5), true)
			
			# B. Draw the Billowing Mushroom Cap
			var cap_radius = nuke_prog * 36.0
			# Billow clusters (multiple overlapping circles to form the classic cauliflower nuke top)
			draw_circle(cap_center, cap_radius, outer_smoke)
			draw_circle(cap_center + Vector2(-cap_radius * 0.5, -cap_radius * 0.2), cap_radius * 0.65, outer_smoke)
			draw_circle(cap_center + Vector2(cap_radius * 0.5, -cap_radius * 0.2), cap_radius * 0.65, outer_smoke)
			draw_circle(cap_center + Vector2(0, -cap_radius * 0.4), cap_radius * 0.6, outer_smoke)
			
			# Inner fiery glow inside the mushroom head
			draw_circle(cap_center, cap_radius * 0.6, inner_fire)

		# 3. BURSTING FIERY SPARKS / EMBERS
		for s in sparks:
			var eased_prog = progress * (1.0 - progress * 0.2)
			var current_pos = s["vel"] * eased_prog * (0.45 / s["drag"])
			# Add a slight upward drift to sparks
			current_pos.y -= progress * 20.0 
			
			var spark_alpha = max(0.0, 1.0 - progress * 1.2)
			var col = s["color"]
			col.a = spark_alpha
			
			var sz = s["size"] * (1.0 - progress * 0.5)
			if spark_alpha > 0.0:
				draw_circle(current_pos, sz, col)
