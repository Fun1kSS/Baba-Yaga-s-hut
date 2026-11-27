extends Node2D

enum Phase { TITLE, GAP, ENTER, TALK, COOK, MINI, LEAVE, CLEAR, OVER }

const WALK_SEC := 1.2
const FIRST_GAP_SEC := 1.5
const NEXT_GAP_SEC := 5.0
const DAY_GOAL := 100
const DAY_GOAL_STEP := 15
const SPEECH_TOP := 802.0
const SPEECH_BOTTOM := 1012.0
const SPEECH_Y0 := 804.0
const SPEECH_LEFT0 := 168.0
const SPEECH_Y1 := 1010.0
const SPEECH_LEFT1 := 42.0
const SPEECH_WIDTH := 1696.0
const SPEECH_PAD := 36.0
const NOTE_BODY := "Зелья готовятся по просьбе гостя нашего. Рецепт я оставила в книге, ингредиенты ищи в мешке!\n\nКогда свечу используешь — смотри, чтобы ничего не перегорело, а когда в ступке мелешь — перетирай везде, где увидишь слишком крупные крупицы."
const NOTE_SIGN := "- Баба Яга"
const NOTE_PAD := 44.0
const NOTE_GAP := 22.0
const DAY_PRAISE: PackedStringArray = [
	"Мне немного КАРжется, что ты сегодня старался.",
	"КАРРРкой же ты молодец.",
	"Ты КАРнечно не Баба Яга, но зелья варишь лучше неё.",
]
const CARRY_TEXTURES := {
	"ingr_a": preload("res://art/ingredients/ingr_a.png"),
	"ingr_b": preload("res://art/ingredients/ingr_b.png"),
	"ingr_c": preload("res://art/ingredients/ingr_c.png"),
	"ingr_d": preload("res://art/ingredients/ingr_d.png"),
	"ingr_f": preload("res://art/ingredients/ingr_f.png"),
}
const CRUMBS_TEXTURE := preload("res://art/crumbs.png")
const ASH_TEXTURE := preload("res://art/ash.png")
const BrewMiniScript := preload("res://scripts/brew_mini.gd")

var phase := Phase.TITLE
var day := 1
var money := 0
var goal := DAY_GOAL
var guests := 0
var bad_number := 0
var step_index := 0
var guest_id := ""
var potion_id := ""
var selected := ""
var guests_pool: Array[String] = []
var potions_pool: Array[String] = []
var _token := 0
var _tween: Tween
var _after_speech: Callable = Callable()
var _cells: Dictionary = {}
var _awaiting_pot := false
var _potion_ready := false
var _mini: Node

signal _leave_done

@onready var guest: Sprite2D = $Guest
@onready var speech: CanvasItem = $Speech
@onready var speech_label: Label = $Speech/Catcher/Text
@onready var speech_name: Label = $Speech/Catcher/Name
@onready var speech_lines: Control = $Speech/Catcher/Lines
@onready var day_title: Label = $DayTitle
@onready var money_label: Label = $Props/Coins/Money
@onready var errors_label: Label = $Props/Coins/Errors
@onready var goal_label: Label = $Goal
@onready var selected_label: Label = $Props/Bag/Sprite2D/Selected
@onready var bag_interior: CanvasItem = $BagInterior
@onready var recipe_book: CanvasItem = $RecipeBook
@onready var good_day: CanvasItem = $GoodDay
@onready var game_over: CanvasItem = $GameOver
@onready var restart: PropButton = $Restart
@onready var carry: Node2D = $Carry
@onready var carry_icon: Sprite2D = $Carry/Icon
@onready var carry_shadow: Sprite2D = $Carry/Shadow
@onready var give_potion: Button = $GivePotion
@onready var help: PropButton = $Props/Help
@onready var note: Control = $Note


func _ready() -> void:
	randomize()
	_mini = BrewMiniScript.new()
	add_child(_mini)
	_mini.missed.connect(_on_mini_missed)
	_mini.finished.connect(_on_mini_finished)
	_connect_ui()
	_build_cells()
	_layout_note()
	_set_tools_enabled(false)
	$Exit.enabled = true
	$Exit.process_mode = Node.PROCESS_MODE_ALWAYS
	_show_title()
	_open_menu()


func _connect_ui() -> void:
	$Props/Quest.clicked.connect(_on_quest)
	help.clicked.connect(_on_help)
	$Note/Catcher.gui_input.connect(_on_note_input)
	$Props/Book.clicked.connect(_on_book)
	$Props/Mortar.clicked.connect(func() -> void: _on_tool("instr_a"))
	$Props/Candle.clicked.connect(func() -> void: _on_tool("instr_b"))
	$Props/Cauldron.clicked.connect(func() -> void: _on_tool("instr_c"))
	$Props/Bag.clicked.connect(_on_bag)
	restart.clicked.connect(_on_restart)
	$Exit.clicked.connect(_on_exit)
	$ExitConfirm/Window/Yes.pressed.connect(_on_exit_yes)
	$ExitConfirm/Window/No.pressed.connect(_on_exit_no)
	$Speech/Catcher.gui_input.connect(_on_speech_input)
	$DayTitle.gui_input.connect(_on_title_input)
	$GoodDay/Catcher.gui_input.connect(_on_good_day_input)
	$RecipeBook/Catcher.gui_input.connect(_on_recipe_input)
	$BagInterior/Catcher.gui_input.connect(_on_bag_backdrop)
	give_potion.pressed.connect(_on_give_potion)
	$Menu/Start.pressed.connect(_on_menu_start)
	$Menu/Quit.pressed.connect(_on_menu_quit)


func _build_cells() -> void:
	var host: Sprite2D = $BagInterior/Sprite2D
	for entry in GameCatalog.BAG_CELLS:
		var rect: Rect2 = entry[0]
		var ingredient: String = entry[1]
		var cell := ColorRect.new()
		cell.color = Color(1, 1, 1, 0)
		cell.position = rect.position - GameCatalog.VIEW_CENTER
		cell.size = rect.size
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cell.z_as_relative = false
		cell.z_index = 40
		cell.gui_input.connect(_on_cell_input.bind(ingredient))
		host.add_child(cell)
		_cells[ingredient] = cell


func _show_title() -> void:
	phase = Phase.TITLE
	_close_panels()
	speech.visible = false
	good_day.visible = false
	game_over.visible = false
	restart.visible = false
	restart.enabled = false
	guest.visible = false
	_reset_brew()
	day_title.text = "ДЕНЬ %d" % day
	day_title.visible = true
	_set_tools_enabled(false)
	help.enabled = false
	_update_money()


func _open_menu() -> void:
	day_title.visible = false
	goal_label.visible = false
	money_label.visible = false
	errors_label.visible = false
	$Exit.visible = false
	$Menu.visible = true


func _on_menu_start() -> void:
	$Menu.visible = false
	day_title.visible = true
	goal_label.visible = true
	money_label.visible = true
	errors_label.visible = true
	$Exit.visible = true


func _on_menu_quit() -> void:
	get_tree().quit()


func _on_title_input(event: InputEvent) -> void:
	if phase != Phase.TITLE:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		phase = Phase.GAP
		day_title.visible = false
		help.enabled = true
		_start_day()


func _start_day() -> void:
	_invalidate()
	var token := _token
	_reset_day()
	await _wait(FIRST_GAP_SEC, token)
	if not _current(token):
		return
	await _visit_loop(token)


func _reset_day() -> void:
	guests = 0
	bad_number = 0
	step_index = 0
	guest_id = ""
	potion_id = ""
	_reset_brew()
	guests_pool = GameCatalog.guest_ids()
	potions_pool = GameCatalog.potion_ids()
	guests_pool.shuffle()
	potions_pool.shuffle()
	_update_money()


func _visit_loop(token: int) -> void:
	while guests < 5 and _current(token):
		await _one_visit(token)
		if not _current(token):
			return
		if guests >= 5:
			break
		phase = Phase.GAP
		await _wait(NEXT_GAP_SEC, token)
		if not _current(token):
			return
	if _current(token):
		_finish_day()


func _one_visit(token: int) -> void:
	if guests_pool.is_empty() or potions_pool.is_empty():
		return
	guest_id = guests_pool.pop_back()
	potion_id = potions_pool.pop_back()
	guests += 1
	bad_number = 0
	step_index = 0
	_reset_brew()
	_update_money()
	_close_panels()
	var bbox := GameCatalog.bbox_of(guest_id)
	guest.texture = GameCatalog.texture_of(guest_id)
	var stand := _stand_position(bbox)
	guest.position = _off_left(bbox, stand.y)
	guest.visible = true
	phase = Phase.ENTER
	if not await _slide_guest(stand, token):
		return
	_show_speech(GameCatalog.order_line(guest_id, potion_id), _resume_cook)
	if not await _wait_leave(token):
		return


func _resume_cook() -> void:
	if not _current(_token) or phase == Phase.TITLE or phase == Phase.OVER or phase == Phase.CLEAR:
		return
	phase = Phase.COOK
	if _potion_ready:
		_set_tools_enabled(false)
		give_potion.visible = true
		return
	_apply_cook_tools()


func _on_tool(tool_id: String) -> void:
	if phase != Phase.COOK or _potion_ready:
		return
	if tool_id == "instr_c" and _awaiting_pot:
		_pour_into_cauldron()
		return
	if selected == "":
		return
	var expected: Array = GameCatalog.step(potion_id, step_index)
	if selected == expected[0] and tool_id == expected[1]:
		_begin_mini(tool_id)
	else:
		_fail_step()


func _begin_mini(tool_id: String) -> void:
	var tex: Texture2D = CARRY_TEXTURES[selected]
	_prop(tool_id).flash_pressed()
	phase = Phase.MINI
	_set_selected("")
	_set_tools_enabled(false)
	_close_panels()
	_mini.start(tool_id, tex)


func _on_mini_finished(tool_id: String) -> void:
	if phase != Phase.MINI:
		return
	phase = Phase.COOK
	_awaiting_pot = true
	_show_processed(tool_id)
	_apply_cook_tools()


func _on_mini_missed() -> void:
	if phase != Phase.MINI:
		return
	bad_number += 1
	_update_money()
	if bad_number >= 4:
		_mini.abort()
		_resolve_failure()
		return
	_mini.suspend()
	_show_speech(GameCatalog.raven_line(), _resume_mini)


func _resume_mini() -> void:
	if not _current(_token) or phase == Phase.TITLE or phase == Phase.OVER or phase == Phase.CLEAR:
		return
	phase = Phase.MINI
	_mini.resume()


func _pour_into_cauldron() -> void:
	_awaiting_pot = false
	carry.visible = false
	step_index += 1
	$Props/Cauldron.flash_pressed()
	if step_index >= GameCatalog.step_count(potion_id):
		_potion_ready = true
		_set_tools_enabled(false)
		give_potion.visible = true
	else:
		_apply_cook_tools()


func _fail_step() -> void:
	_awaiting_pot = false
	_set_selected("")
	_set_tools_enabled(false)
	bad_number += 1
	_update_money()
	if bad_number >= 4:
		_resolve_failure()
	else:
		_show_speech(GameCatalog.raven_line(), _resume_cook)


func _on_give_potion() -> void:
	if not _potion_ready or phase != Phase.COOK:
		return
	_potion_ready = false
	give_potion.visible = false
	_resolve_success()


func _prop(tool_id: String) -> PropButton:
	match tool_id:
		"instr_a":
			return $Props/Mortar
		"instr_b":
			return $Props/Candle
		_:
			return $Props/Cauldron


func _resolve_success() -> void:
	phase = Phase.TALK
	_close_panels()
	money += GameCatalog.payout(potion_id, bad_number)
	_update_money()
	_show_speech(GameCatalog.success_line(guest_id), _begin_leave)


func _resolve_failure() -> void:
	phase = Phase.TALK
	_close_panels()
	_show_speech(GameCatalog.failure_line(guest_id), _begin_leave)


func _begin_leave() -> void:
	_leave(_token)


func _leave(token: int) -> void:
	if not _current(token):
		return
	phase = Phase.LEAVE
	var bbox := GameCatalog.bbox_of(guest_id)
	if not await _slide_guest(_off_right(bbox, guest.position.y), token):
		return
	guest.visible = false
	_leave_done.emit()


func _wait_leave(token: int) -> bool:
	await _leave_done
	return _current(token)


func _finish_day() -> void:
	_set_tools_enabled(false)
	help.enabled = false
	_close_panels()
	speech.visible = false
	guest.visible = false
	_reset_brew()
	if money >= goal:
		money -= goal
		goal += DAY_GOAL_STEP
		_update_money()
		phase = Phase.CLEAR
		$GoodDay/Praise.text = "ВОРОН: %s" % DAY_PRAISE[randi() % DAY_PRAISE.size()]
		good_day.visible = true
	else:
		phase = Phase.OVER
		game_over.visible = true
		restart.visible = true
		restart.enabled = true


func _on_good_day_input(event: InputEvent) -> void:
	if phase != Phase.CLEAR:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		good_day.visible = false
		day += 1
		_show_title()


func _on_exit() -> void:
	if note.visible:
		note.visible = false
	$ExitConfirm.visible = true
	get_tree().paused = true


func _on_exit_yes() -> void:
	get_tree().quit()


func _on_exit_no() -> void:
	$ExitConfirm.visible = false
	get_tree().paused = false


func _on_restart() -> void:
	_invalidate()
	day = 1
	money = 0
	goal = DAY_GOAL
	_show_title()


func _on_help() -> void:
	if phase == Phase.TITLE or phase == Phase.CLEAR or phase == Phase.OVER:
		return
	if $ExitConfirm.visible:
		return
	if note.visible:
		_close_note()
		return
	bag_interior.visible = false
	recipe_book.visible = false
	note.visible = true
	get_tree().paused = true


func _on_note_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var window := $Note/Window as Control
		if window.get_global_rect().has_point(window.get_global_mouse_position()):
			return
		_close_note()


func _close_note() -> void:
	if not note.visible:
		return
	note.visible = false
	if not $ExitConfirm.visible:
		get_tree().paused = false


func _layout_note() -> void:
	var body: Label = $Note/Window/Body
	var sign: Label = $Note/Window/Sign
	var window: Panel = $Note/Window
	var lo := 280.0
	var hi := 760.0
	var body_h := 0.0
	var sign_h := 0.0
	var column := 480.0
	for _i in 14:
		column = (lo + hi) * 0.5
		var measured := _note_block(body, sign, column)
		body_h = measured.x
		sign_h = measured.y
		var height := body_h + NOTE_GAP + sign_h
		if height > column:
			lo = column
		else:
			hi = column
	column = hi
	var measured := _note_block(body, sign, column)
	body_h = measured.x
	sign_h = measured.y
	var block_h := body_h + NOTE_GAP + sign_h
	var block := maxf(column, block_h)
	var side := block + NOTE_PAD * 2.0
	var origin := (Vector2(1920, 1080) - Vector2(side, side)) * 0.5
	window.offset_left = origin.x
	window.offset_top = origin.y
	window.offset_right = origin.x + side
	window.offset_bottom = origin.y + side
	var left := NOTE_PAD + (block - column) * 0.5
	var top := NOTE_PAD + (block - block_h) * 0.5
	body.text = NOTE_BODY
	body.offset_left = left
	body.offset_top = top
	body.offset_right = left + column
	body.offset_bottom = top + body_h
	sign.text = NOTE_SIGN
	sign.offset_left = left
	sign.offset_top = top + body_h + NOTE_GAP
	sign.offset_right = left + column
	sign.offset_bottom = sign.offset_top + sign_h


func _note_block(body: Label, sign: Label, column: float) -> Vector2:
	body.set_size(Vector2(column, 4))
	sign.set_size(Vector2(column, 4))
	return Vector2(body.get_minimum_size().y, sign.get_minimum_size().y)


func _on_quest() -> void:
	if phase != Phase.COOK:
		return
	_close_panels()
	_show_speech(GameCatalog.order_line(guest_id, potion_id), _resume_cook)


func _on_book() -> void:
	if phase != Phase.COOK:
		return
	bag_interior.visible = false
	recipe_book.visible = true


func _on_recipe_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		recipe_book.visible = false


func _on_bag() -> void:
	if phase != Phase.COOK or recipe_book.visible:
		return
	_refresh_cells()
	bag_interior.visible = true


func _on_bag_backdrop(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		bag_interior.visible = false


func _on_cell_input(event: InputEvent, ingredient: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_set_selected(ingredient)
		bag_interior.visible = false


func _on_speech_input(event: InputEvent) -> void:
	if not speech.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		speech.visible = false
		var then := _after_speech
		_after_speech = Callable()
		if then.is_valid():
			then.call()


func _speech_left(y: float) -> float:
	var t := (y - SPEECH_Y0) / (SPEECH_Y1 - SPEECH_Y0)
	return lerpf(SPEECH_LEFT0, SPEECH_LEFT1, t)


func _wrap_speech(font: Font, text: String, font_size: int, max_width: float) -> PackedStringArray:
	var lines: PackedStringArray = []
	var current := ""
	for word in text.split(" ", false):
		var trial := word if current.is_empty() else current + " " + word
		var width := font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if width <= max_width or current.is_empty():
			current = trial
		else:
			lines.append(current)
			current = word
	if not current.is_empty():
		lines.append(current)
	return lines


func _show_speech(text: String, then: Callable) -> void:
	phase = Phase.TALK
	_set_tools_enabled(false)
	_close_panels()
	var speaker := ""
	var body := text
	var break_at := text.find("\n")
	if break_at >= 0:
		speaker = text.substr(0, break_at)
		body = text.substr(break_at + 1)
	_layout_speech(speaker, body)
	speech.visible = true
	_after_speech = then


func _layout_speech(speaker: String, body: String) -> void:
	var font := speech_label.get_theme_font("font")
	var body_size := speech_label.get_theme_font_size("font_size")
	var body_color := speech_label.get_theme_color("font_color")
	var max_width := SPEECH_WIDTH - SPEECH_PAD * 2.0
	var line_h := font.get_height(body_size)
	var lines := _wrap_speech(font, body, body_size, max_width)
	var body_top: float
	if speaker != "":
		var name_size := speech_name.get_theme_font_size("font_size")
		var name_h := font.get_height(name_size)
		var name_top := SPEECH_TOP + 18.0
		var name_mid := name_top + name_h * 0.5
		var name_left := _speech_left(name_mid) + SPEECH_PAD
		speech_name.text = speaker
		speech_name.visible = true
		speech_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		speech_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		speech_name.offset_left = name_left
		speech_name.offset_right = name_left + max_width
		speech_name.offset_top = name_top
		speech_name.offset_bottom = name_top + name_h
		body_top = name_top + name_h + 6.0
	else:
		speech_name.visible = false
		var block_h := lines.size() * line_h
		var area_top := SPEECH_TOP + 16.0
		var area_h := (SPEECH_BOTTOM - 16.0) - area_top
		body_top = area_top + maxf(0.0, (area_h - block_h) * 0.5)
	for child in speech_lines.get_children():
		child.free()
	for i in lines.size():
		var y := body_top + i * line_h
		var x := _speech_left(y + line_h * 0.5) + SPEECH_PAD
		var label := Label.new()
		label.text = lines[i]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL if i < lines.size() - 1 else HORIZONTAL_ALIGNMENT_LEFT
		label.add_theme_font_size_override("font_size", body_size)
		label.add_theme_color_override("font_color", body_color)
		label.position = Vector2(x, y)
		label.size = Vector2(max_width, line_h)
		speech_lines.add_child(label)


func _process(_delta: float) -> void:
	if carry.visible:
		carry.global_position = get_global_mouse_position() + Vector2(56, 48)


func _set_selected(ingredient: String) -> void:
	selected = ingredient
	selected_label.text = GameCatalog.ingredient_name(ingredient) if ingredient != "" else ""
	if ingredient != "" and CARRY_TEXTURES.has(ingredient):
		var tex: Texture2D = CARRY_TEXTURES[ingredient]
		carry_icon.texture = tex
		carry_shadow.texture = tex
		carry.visible = true
		carry.global_position = get_global_mouse_position() + Vector2(56, 48)
	else:
		carry.visible = false
	_refresh_cells()
	if phase == Phase.COOK and not _potion_ready:
		_apply_cook_tools()


func _show_processed(tool_id: String) -> void:
	var tex := CRUMBS_TEXTURE if tool_id == "instr_a" else ASH_TEXTURE
	carry_icon.texture = tex
	carry_shadow.texture = tex
	carry.visible = true
	carry.global_position = get_global_mouse_position() + Vector2(56, 48)


func _apply_cook_tools() -> void:
	var brewing := phase == Phase.COOK and not _potion_ready
	var holding := selected != "" and not _awaiting_pot
	$Props/Quest.enabled = brewing
	$Props/Book.enabled = brewing
	$Props/Bag.enabled = brewing and not _awaiting_pot
	$Props/Mortar.enabled = brewing and holding
	$Props/Candle.enabled = brewing and holding
	$Props/Cauldron.enabled = brewing and (_awaiting_pot or holding)


func _reset_brew() -> void:
	_awaiting_pot = false
	_potion_ready = false
	if _mini:
		_mini.abort()
	if is_node_ready():
		give_potion.visible = false
		_set_selected("")


func _refresh_cells() -> void:
	for ingredient in _cells:
		var cell: ColorRect = _cells[ingredient]
		var lit: bool = ingredient == selected
		cell.color = Color(1, 1, 1, 0.28 if lit else 0.0)


func _set_tools_enabled(on: bool) -> void:
	for child in $Props.get_children():
		if child is PropButton and child.name != "Help":
			child.enabled = on


func _close_panels() -> void:
	bag_interior.visible = false
	recipe_book.visible = false


func _update_money() -> void:
	money_label.text = str(money)
	errors_label.text = "Ошибок: %d" % bad_number
	goal_label.text = "Цель: %d" % goal


func _invalidate() -> void:
	_token += 1
	_after_speech = Callable()
	if _mini:
		_mini.abort()
	if _tween and is_instance_valid(_tween):
		_tween.kill()
	guest.visible = false
	_leave_done.emit()


func _current(token: int) -> bool:
	return is_inside_tree() and token == _token


func _wait(seconds: float, token: int) -> bool:
	await get_tree().create_timer(seconds).timeout
	return _current(token)


func _slide_guest(to: Vector2, token: int) -> bool:
	if not _current(token):
		return false
	if _tween and is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(guest, "position", to, WALK_SEC).set_trans(Tween.TRANS_LINEAR)
	await _tween.finished
	return _current(token)


func _stand_position(bbox: Rect2) -> Vector2:
	var center := Vector2(bbox.position.x + bbox.size.x * 0.5, bbox.end.y)
	return _pixel_to_sprite(center, Vector2(960, GameCatalog.COUNTER_Y))


func _off_left(bbox: Rect2, stand_y: float) -> Vector2:
	var x := _pixel_to_sprite(Vector2(bbox.end.x, 0), Vector2(-40, 0)).x
	return Vector2(x, stand_y)


func _off_right(bbox: Rect2, stand_y: float) -> Vector2:
	var x := _pixel_to_sprite(Vector2(bbox.position.x, 0), Vector2(1960, 0)).x
	return Vector2(x, stand_y)


func _pixel_to_sprite(pixel: Vector2, screen: Vector2) -> Vector2:
	return screen - (pixel - GameCatalog.VIEW_CENTER)
