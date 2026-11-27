extends Control

signal ratio_changed(ratio: float)

const TRACK := Color(0.32, 0.32, 0.32, 1)
const HEAD := Color(0.8, 0.8, 0.8, 1)

var ratio := 0.0
var _drag := false
var _grab := 0.0


func set_ratio(value: float) -> void:
	ratio = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), TRACK)
	var diameter := size.x * 0.99
	var travel := maxf(0.0, size.y - diameter)
	var top := travel * ratio
	draw_circle(Vector2(size.x * 0.5, top + diameter * 0.5), diameter * 0.5, HEAD)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _on_head(event.position.y):
			var diameter := size.x * 0.99
			var travel := maxf(1.0, size.y - diameter)
			_drag = true
			_grab = event.position.y - travel * ratio
			accept_event()
		elif not event.pressed:
			_drag = false
	elif event is InputEventMouseMotion and _drag:
		_move(event.position.y)
		accept_event()


func _input(event: InputEvent) -> void:
	if not _drag:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_drag = false
	elif event is InputEventMouseMotion:
		_move(get_local_mouse_position().y)


func _on_head(y: float) -> bool:
	var diameter := size.x * 0.99
	var travel := maxf(0.0, size.y - diameter)
	var top := travel * ratio
	return y >= top and y <= top + diameter


func _move(y: float) -> void:
	var diameter := size.x * 0.99
	var travel := maxf(1.0, size.y - diameter)
	var top := clampf(y - _grab, 0.0, travel)
	var next := top / travel
	if is_equal_approx(next, ratio):
		return
	ratio = next
	queue_redraw()
	ratio_changed.emit(ratio)
