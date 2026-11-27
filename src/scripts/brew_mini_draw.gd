extends Node2D


func _draw() -> void:
	var mini: Node = get_parent()
	if mini._mode == "mortar":
		if mini._cue_button != 0:
			_mouse(mini._cue_pos, mini._cue_button == 1)
	elif mini._mode == "candle":
		draw_arc(mini.FLAME, mini.FLAME_RADIUS, 0.0, TAU, 40, Color(0.08, 0.08, 0.08, 0.9), 3.0)
		_bar(Vector2(1488, 600), "Перегрев", float(mini._heat), Color(0.72, 0.28, 0.22))
		_bar(Vector2(1488, 662), "Готовность", float(mini._cooked), Color(0.32, 0.52, 0.3))


func _mouse(at: Vector2, left_down: bool) -> void:
	var mini: Node = get_parent()
	var remaining: float = clampf(float(mini._cue_left) / float(mini.CUE_LIFE), 0.0, 1.0)
	var elapsed: float = 1.0 - remaining
	var life: float = 1.0 - elapsed * elapsed
	var radius: float = float(mini._pestle_span()) * 0.625 * life
	if radius < 0.5:
		return
	var body := Color(0.74, 0.74, 0.74)
	var ink := Color(0.28, 0.28, 0.28)
	var pressed := Color(0.72, 0.28, 0.22)
	var stroke := maxf(1.0, radius * 0.11)
	draw_circle(at, radius, body)
	var start := PI if left_down else PI * 1.5
	var end := PI * 1.5 if left_down else TAU
	var wedge := PackedVector2Array()
	wedge.append(at)
	for i in 13:
		var angle := lerpf(start, end, float(i) / 12.0)
		wedge.append(at + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(wedge, pressed)
	draw_arc(at, radius, 0.0, TAU, 48, ink, stroke)
	draw_line(at + Vector2(-radius, 0), at + Vector2(radius, 0), ink, stroke)
	draw_line(at, at + Vector2(0, -radius), ink, stroke)


func _bar(at: Vector2, title: String, amount: float, fill: Color) -> void:
	var font := ThemeDB.fallback_font
	var size := Vector2(250, 24)
	var font_size := 16
	var text_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var ascent := font.get_ascent(font_size)
	var pad := 5.0
	var gap := 4.0
	var plate := Rect2(at + Vector2(-pad, -(text_size.y + pad * 2.0 + gap)), Vector2(text_size.x + pad * 2.0, text_size.y + pad * 2.0))
	_round_rect(plate, 6.0, Color(0.05, 0.05, 0.05, 0.72))
	var baseline := Vector2(plate.position.x + pad, plate.position.y + pad + ascent)
	draw_string(font, baseline, title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1))
	draw_rect(Rect2(at, size), Color(0.1, 0.1, 0.1))
	var inner := Vector2((size.x - 6.0) * clampf(amount, 0.0, 1.0), size.y - 6.0)
	draw_rect(Rect2(at + Vector2(3, 3), inner), fill)


func _round_rect(rect: Rect2, radius: float, color: Color) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	draw_rect(Rect2(rect.position.x + r, rect.position.y, rect.size.x - r * 2.0, rect.size.y), color)
	draw_rect(Rect2(rect.position.x, rect.position.y + r, rect.size.x, rect.size.y - r * 2.0), color)
	draw_circle(rect.position + Vector2(r, r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, r), r, color)
	draw_circle(rect.position + Vector2(r, rect.size.y - r), r, color)
	draw_circle(rect.position + Vector2(rect.size.x - r, rect.size.y - r), r, color)
