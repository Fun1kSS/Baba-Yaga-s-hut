extends Node2D


func _draw() -> void:
	var mini: Node = get_parent()
	if mini._mode == "mortar":
		if mini._cue_button != 0:
			_mouse(mini._cue_pos, mini._cue_button == 1)
	elif mini._mode == "candle":
		draw_arc(mini.FLAME, mini.FLAME_RADIUS, 0.0, TAU, 40, Color(0.08, 0.08, 0.08, 0.9), 3.0)
		_bar(Vector2(1488, 600), "Перегар", float(mini._heat), Color(0.72, 0.28, 0.22))
		_bar(Vector2(1488, 662), "Готовность", float(mini._cooked), Color(0.32, 0.52, 0.3))


func _mouse(at: Vector2, left_down: bool) -> void:
	var radius := 22.0
	var body := Color(0.74, 0.74, 0.74)
	var ink := Color(0.28, 0.28, 0.28)
	var pressed := Color(0.06, 0.06, 0.06)
	draw_circle(at, radius, body)
	var start := PI if left_down else PI * 1.5
	var end := PI * 1.5 if left_down else TAU
	var wedge := PackedVector2Array()
	wedge.append(at)
	for i in 9:
		var angle := lerpf(start, end, float(i) / 8.0)
		wedge.append(at + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(wedge, pressed)
	draw_arc(at, radius, 0.0, TAU, 32, ink, 2.5)
	draw_line(at + Vector2(-radius, 0), at + Vector2(radius, 0), ink, 2.5)
	draw_line(at, at + Vector2(0, -radius), ink, 2.5)


func _bar(at: Vector2, title: String, amount: float, fill: Color) -> void:
	var font := ThemeDB.fallback_font
	var size := Vector2(250, 24)
	draw_string(font, at + Vector2(0, -6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.08, 0.08, 0.08))
	draw_rect(Rect2(at, size), Color(0.1, 0.1, 0.1))
	var inner := Vector2((size.x - 6.0) * clampf(amount, 0.0, 1.0), size.y - 6.0)
	draw_rect(Rect2(at + Vector2(3, 3), inner), fill)
