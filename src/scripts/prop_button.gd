class_name PropButton
extends Node2D

signal clicked

@export var hitbox: Rect2
@export var pressed_texture: Texture2D

var enabled := false:
	set(value):
		enabled = value
		if is_node_ready():
			_apply_enabled()

var _holding := false
var _flashing := false
var _normal: Texture2D
var _image: Image

@onready var sprite: Sprite2D = $Sprite2D
@onready var hit: Control = $Sprite2D/Hit


func _ready() -> void:
	_normal = sprite.texture
	if sprite.texture:
		_image = sprite.texture.get_image()
	var tex_size := GameCatalog.VIEW_SIZE
	if sprite.texture:
		tex_size = sprite.texture.get_size()
	hit.position = hitbox.position - tex_size * 0.5
	hit.size = hitbox.size
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.gui_input.connect(_on_hit_input)
	_apply_enabled()


func _visible_pixel(local_on_hit: Vector2) -> bool:
	if _image == null:
		return true
	var pixel := hitbox.position + local_on_hit
	var x := int(pixel.x)
	var y := int(pixel.y)
	if x < 0 or y < 0 or x >= _image.get_width() or y >= _image.get_height():
		return false
	return _image.get_pixel(x, y).a > 0.08


func _apply_enabled() -> void:
	hit.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if not enabled:
		_holding = false
		if not _flashing:
			_restore()


func _restore() -> void:
	if _normal:
		sprite.texture = _normal


func flash_pressed() -> void:
	if pressed_texture == null:
		return
	_flashing = true
	sprite.texture = pressed_texture
	get_tree().create_timer(0.12).timeout.connect(func() -> void:
		_flashing = false
		if not _holding:
			_restore()
	)


func _on_hit_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _visible_pixel(hit.get_local_mouse_position()):
			return
		_holding = true
		if pressed_texture:
			sprite.texture = pressed_texture


func _input(event: InputEvent) -> void:
	if not _holding:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var local := hit.get_local_mouse_position()
		var inside := enabled and Rect2(Vector2.ZERO, hit.size).has_point(local) and _visible_pixel(local)
		_holding = false
		_restore()
		if inside:
			clicked.emit()
