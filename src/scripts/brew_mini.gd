extends Node2D

signal missed
signal finished(tool_id: String)

const PESTLE := preload("res://art/pestle.png")
const LAYER_DRAW := preload("res://scripts/brew_mini_draw.gd")
const BOWL := Vector2(1178, 699)
const FLAME := Vector2(1410, 626)
const FLAME_RADIUS := 46.0
const CUE_LIFE := 2.5
const CUE_GAP := 0.4
const GRIND_TIME := 10.0
const HEAT_RATE := 0.6
const COOL_RATE := 0.9
const READY_RATE := 0.195
const READY_DECAY := 0.04

var _mode := ""
var _tool_id := ""
var _elapsed := 0.0
var _cue_button := 0
var _cue_left := 0.0
var _cue_pos := Vector2.ZERO
var _next_cue := 0.0
var _heat := 0.0
var _cooked := 0.0
var _suspended := false
var _prev_mouse := Vector2.ZERO

var _pestle: Sprite2D
var _herb: Sprite2D
var _cue_label: Label
var _layer: Node2D


func _ready() -> void:
	z_index = 18
	visible = false
	_layer = Node2D.new()
	_layer.z_index = 1
	_layer.set_script(LAYER_DRAW)
	add_child(_layer)
	_herb = Sprite2D.new()
	_herb.scale = Vector2(0.36, 0.36)
	add_child(_herb)
	_pestle = Sprite2D.new()
	_pestle.z_index = 2
	_pestle.texture = PESTLE
	_pestle.scale = Vector2(0.5, 0.5)
	add_child(_pestle)
	_cue_label = _make_label(28)
	set_process(false)
	set_process_unhandled_input(false)


func start(tool_id: String, herb: Texture2D) -> void:
	_tool_id = tool_id
	_herb.texture = herb
	_elapsed = 0.0
	_cue_button = 0
	_suspended = false
	_heat = 0.0
	_cooked = 0.0
	_prev_mouse = get_global_mouse_position()
	visible = true
	if tool_id == "instr_a":
		_mode = "mortar"
		_next_cue = 0.45
		_herb.position = BOWL
		_herb.scale = Vector2(0.36, 0.36)
		_pestle.visible = true
	else:
		_mode = "candle"
		_pestle.visible = false
		_herb.scale = Vector2(0.42, 0.42)
	_cue_label.visible = false
	set_process(true)
	set_process_unhandled_input(true)
	_layer.queue_redraw()


func abort() -> void:
	_mode = ""
	_suspended = false
	visible = false
	_cue_label.visible = false
	set_process(false)
	set_process_unhandled_input(false)


func suspend() -> void:
	_suspended = true
	visible = false
	set_process(false)
	set_process_unhandled_input(false)


func resume() -> void:
	if _mode == "":
		return
	_suspended = false
	visible = true
	set_process(true)
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	_advance(delta, get_global_mouse_position(), Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))


func _advance(delta: float, pointer: Vector2, holding: bool) -> void:
	if _mode == "":
		return
	if _mode == "mortar":
		_move_pestle(pointer, delta)
		_elapsed += delta
		if _elapsed >= GRIND_TIME:
			_complete()
			return
		if _cue_button != 0:
			_cue_left -= delta
			if _cue_left <= 0.0:
				_clear_cue()
				missed.emit()
				if _mode == "" or _suspended:
					return
		else:
			_next_cue -= delta
			if _next_cue <= 0.0:
				_spawn_cue()
	else:
		_herb.global_position = pointer + Vector2(48, 40)
		var over := pointer.distance_to(FLAME) <= FLAME_RADIUS
		if holding and over:
			_heat += HEAT_RATE * delta
			_cooked += READY_RATE * delta
		else:
			_heat = maxf(0.0, _heat - COOL_RATE * delta)
			_cooked = maxf(0.0, _cooked - READY_DECAY * delta)
		if _heat >= 1.0:
			_heat = 0.0
			_cooked = maxf(0.0, _cooked - 0.12)
			missed.emit()
			if _mode == "" or _suspended:
				return
		if _cooked >= 1.0:
			_complete()
			return
	_layer.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _mode != "mortar" or _cue_button == 0:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
			return
		var want := MOUSE_BUTTON_LEFT if _cue_button == 1 else MOUSE_BUTTON_RIGHT
		_try_press(event.button_index, get_global_mouse_position(), want)


func _try_press(button: int, pointer: Vector2, want: int) -> void:
	var near := pointer.distance_to(_cue_pos) <= _pestle_span() * 1.1
	var ok := button == want and near
	_clear_cue()
	_next_cue = CUE_GAP
	if not ok:
		missed.emit()


func _pestle_span() -> float:
	return PESTLE.get_width() * _pestle.scale.x


func _move_pestle(pointer: Vector2, _delta: float) -> void:
	var height := PESTLE.get_height() * _pestle.scale.y
	_pestle.global_position = pointer + Vector2(0, -height * 0.42)
	var slide := pointer.x - _prev_mouse.x
	_pestle.rotation = clampf(slide * 0.03, -0.45, 0.45)
	_prev_mouse = pointer


func _spawn_cue() -> void:
	_cue_button = 1 if randi() % 2 == 0 else 2
	_cue_left = CUE_LIFE
	_cue_pos = BOWL + Vector2(randf_range(-50, 50), randf_range(-34, 30))


func _clear_cue() -> void:
	_cue_button = 0
	_cue_label.visible = false


func _complete() -> void:
	var tool := _tool_id
	abort()
	finished.emit(tool)


func _make_label(size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08))
	label.z_index = 3
	add_child(label)
	return label
