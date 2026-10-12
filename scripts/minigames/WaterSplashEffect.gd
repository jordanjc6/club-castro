# --- Procedural Water Splash Effect Class ---
class WaterSplashEffect extends Node2D:
	var progress: float = 0.0
	var drops: Array = []

	func _ready() -> void:
		# Generate 7 random droplet directions and distances
		for i in range(7):
			var angle = randf() * TAU
			var dist = randf_range(25.0, 55.0)
			drops.append({
				"dir": Vector2(cos(angle), sin(angle)),
				"dist": dist,
				"size": randf_range(3.0, 5.0)
			})
		
		# Animate the splash progress from 0.0 to 1.0 over 0.45 seconds
		var tween = create_tween()
		tween.tween_property(self, "progress", 1.0, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.finished.connect(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		# 1. Draw expanding center ripple ring
		var ring_radius = progress * 28.0
		var ring_alpha = 1.0 - progress
		draw_arc(Vector2.ZERO, ring_radius, 0, TAU, 16, Color(0.3, 0.6, 0.9, ring_alpha * 0.7), 2.0)
		
		# 2. Draw splashing blue droplets
		for d in drops:
			var current_pos = d["dir"] * (d["dist"] * progress)
			# Add a subtle downward arc for gravity effect
			current_pos.y += progress * progress * 15.0 
			var drop_alpha = (1.0 - progress)
			draw_circle(current_pos, d["size"] * (1.0 - progress * 0.3), Color(0.4, 0.7, 1.0, drop_alpha))
