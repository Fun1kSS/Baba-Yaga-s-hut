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
const HINT_PAD := 120.0
const HINT_TITLE := "ПОДСКАЗКА:"
const RAVEN_TITLE := "Ворон:"
const NOTE_BODY := "Зелья готовятся по просьбе гостя нашего. Рецепт я оставила в книге, ингредиенты ищи в мешке!\n\nКогда свечу используешь — смотри, чтобы ничего не перегорело, а когда в ступке мелешь — перетирай везде, где увидишь слишком крупные крупицы."
const NOTE_SIGN := "- Баба Яга"
const NOTE_PAD := 44.0
const NOTE_GAP := 22.0
const NOTE_BAR_W := 18.0
const NOTE_BAR_EDGE := 14.0
const NOTE_BAR_GAP := 12.0
const NOTE_WHEEL := 64.0
const NOTE_BOOK := "Чтобы посмотреть все рецепты, смотри в книгу рецептов:"
const NOTE_CANDLE := "Когда используешь свечу, появятся две шкалы — красная и зеленая. Доведи зеленую до конца, но следи, чтобы красная шкала не заполнилась:"
const NOTE_MORTAR := "Когда используешь ступку — кликай нужными клавишами на мыши по значкам. Ты поймешь, какую нажимать — она будет отмечена красным цветом:"
const NOTE_BOOK_OPEN := preload("res://art/tutorial/book_open.png")
const NOTE_BOOK_PAGES := preload("res://art/tutorial/book_pages.png")
const NOTE_CANDLE_TEX := preload("res://art/tutorial/candle.png")
const NOTE_MORTAR_TEX := preload("res://art/tutorial/mortar.png")
const NoteBarScript := preload("res://scripts/note_bar.gd")
const DAY_PRAISE: PackedStringArray = [
	"Мне немного КАРжется, что ты сегодня старался.",
	"КАРРРкой же ты молодец.",
	"Ты КАРнечно не Баба Яга, но зелья варишь лучше неё.",
]
const RAVEN_TIPS: PackedStringArray = [
	"Если забыл рецепт — посмотри в книгу.",
	"Постарайся не делать ошибок.",
	"Ингредиенты лежат в мешке, бери сколько нужно.",
	"Сначала подготовь траву и только потом лей её в котёл.",
	"Четыре ошибки — и гость уйдёт ни с чем.",
	"Чем меньше промахов, тем больше монет за зелье.",
	"Следи за целью дня: недобранные монеты обернутся бедой.",
]
const MINI_HINTS := {
	"instr_a": "Вовремя нажимай нужной кнопкой мыши по значкам!",
	"instr_b": "Доведи продукт до готовности, но не допусти перегрева!",
}
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
var _pot_shake: Tween
var _pot_home := Vector2.ZERO
var _pot_shaking := false
var _after_speech: Callable = Callable()
var _cells: Dictionary = {}
var _awaiting_pot := false
var _potion_ready := false
var _mini: Node
var _mini_tool := ""
var _mini_hint := false
var _raven_image: Image
var _last_raven_tip := -1
var _last_praise := -1
var _note_view: Control
var _note_content: Control
var _note_bar
var _note_offset := 0.0
var _note_max := 0.0

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
	_setup_raven()
	_set_tools_enabled(false)
	$Exit.enabled = true
	$Exit.process_mode = Node.PROCESS_MODE_ALWAYS
	_show_title()
	_open_menu()


func _connect_ui() -> void:
	$Props/Quest.clicked.connect(_on_quest)
	help.clicked.connect(_on_help)
	$Note/Catcher.gui_input.connect(_on_note_input)
	$Note/Window.gui_input.connect(_on_note_wheel)
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
	_mini_hint = false
	$Speech/Catcher.mouse_filter = Control.MOUSE_FILTER_STOP
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
	_mini_tool = tool_id
	_show_mini_hint(tool_id)


func _on_mini_finished(tool_id: String) -> void:
	if phase != Phase.MINI:
		return
	phase = Phase.COOK
	_hide_mini_hint()
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
	_show_mini_hint(_mini_tool)


func _pour_into_cauldron() -> void:
	_awaiting_pot = false
	carry.visible = false
	step_index += 1
	$Props/Cauldron.flash_pressed()
	if step_index >= GameCatalog.step_count(potion_id):
		_set_tools_enabled(false)
		_shake_cauldron()
	else:
		_apply_cook_tools()


func _shake_cauldron() -> void:
	var sprite: Sprite2D = $Props/Cauldron/Sprite2D
	_stop_pot_shake()
	_pot_home = sprite.position
	_pot_shaking = true
	var amp := sprite.texture.get_height() * absf(sprite.scale.y) * 0.05
	_pot_shake = create_tween()
	_pot_shake.tween_method(_pot_offset.bind(sprite, amp), 0.0, 4.5, 4.5)
	_pot_shake.finished.connect(_on_pot_shake_finished)


func _pot_offset(time: float, sprite: Sprite2D, amp: float) -> void:
	if not _pot_shaking or not is_instance_valid(sprite):
		return
	var omega := (1.0 / 0.5) / 0.05
	sprite.position = _pot_home + Vector2(sin(time * omega), cos(time * omega)) * amp


func _on_pot_shake_finished() -> void:
	if not _pot_shaking:
		return
	_stop_pot_shake()
	if phase != Phase.COOK:
		return
	_potion_ready = true
	_set_tools_enabled(false)
	give_potion.visible = true


func _stop_pot_shake() -> void:
	var running := _pot_shake
	var was := _pot_shaking
	_pot_shake = null
	_pot_shaking = false
	if was and is_node_ready():
		($Props/Cauldron/Sprite2D as Sprite2D).position = _pot_home
	if running and is_instance_valid(running):
		running.kill()


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
	_mini_hint = false
	$Speech/Catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	guest.visible = false
	_reset_brew()
	if money >= goal:
		money -= goal
		goal += DAY_GOAL_STEP
		_update_money()
		phase = Phase.CLEAR
		_last_praise = _next_line(DAY_PRAISE, _last_praise)
		$GoodDay/Praise.text = "ВОРОН: %s" % DAY_PRAISE[_last_praise]
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
	_reset_note_scroll()
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
	var hi := 860.0
	var column := 480.0
	for _i in 16:
		column = (lo + hi) * 0.5
		if _note_old_height(body, sign, column) > column:
			lo = column
		else:
			hi = column
	column = hi
	var measured := _note_block(body, sign, column)
	var block := measured.x + NOTE_GAP + measured.y
	var side := maxf(block, column) + NOTE_PAD * 2.0
	var origin := (Vector2(1920, 1080) - Vector2(side, side)) * 0.5
	window.offset_left = origin.x
	window.offset_top = origin.y
	window.offset_right = origin.x + side
	window.offset_bottom = origin.y + side
	_ensure_note_scroll(window)
	var bar_x := side - NOTE_BAR_EDGE - NOTE_BAR_W
	_note_view.position = Vector2(NOTE_PAD, NOTE_PAD)
	_note_view.size = Vector2(column, block)
	_note_bar.position = Vector2(bar_x, NOTE_BAR_EDGE)
	_note_bar.size = Vector2(NOTE_BAR_W, side - NOTE_BAR_EDGE * 2.0)
	if body.get_parent() != _note_content:
		body.reparent(_note_content)
	if sign.get_parent() != _note_content:
		sign.reparent(_note_content)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var y := 0.0
	_place_note_label(body, column, y, measured.x)
	y += measured.x + NOTE_GAP
	_place_note_label(sign, column, y, measured.y)
	var line_h := sign.get_theme_font("font").get_height(sign.get_theme_font_size("font_size"))
	y += measured.y + line_h * 10.0
	_clear_note_extra()
	y = _add_note_text(NOTE_BOOK, column, y)
	var pair := (column - NOTE_GAP) * 0.5
	_add_note_picture(NOTE_BOOK_OPEN, 0.0, y, pair)
	_add_note_picture(NOTE_BOOK_PAGES, pair + NOTE_GAP, y, pair)
	y += pair + NOTE_GAP
	y = _add_note_text(NOTE_CANDLE, column, y)
	_add_note_picture(NOTE_CANDLE_TEX, 0.0, y, column)
	y += column + NOTE_GAP
	y = _add_note_text(NOTE_MORTAR, column, y)
	_add_note_picture(NOTE_MORTAR_TEX, 0.0, y, column)
	y += column
	_note_content.position = Vector2.ZERO
	_note_content.size = Vector2(column, y)
	_note_max = maxf(0.0, y - block)
	_reset_note_scroll()


func _note_old_height(body: Label, sign: Label, column: float) -> float:
	var measured := _note_block(body, sign, column)
	return measured.x + NOTE_GAP + measured.y


func _note_block(body: Label, sign: Label, column: float) -> Vector2:
	body.text = NOTE_BODY
	sign.text = NOTE_SIGN
	body.set_size(Vector2(column, 4))
	sign.set_size(Vector2(column, 4))
	return Vector2(body.get_minimum_size().y, sign.get_minimum_size().y)


func _ensure_note_scroll(window: Control) -> void:
	if _note_view != null:
		return
	_note_view = Control.new()
	_note_view.name = "View"
	_note_view.clip_contents = true
	_note_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_note_view.gui_input.connect(_on_note_wheel)
	window.add_child(_note_view)
	_note_content = Control.new()
	_note_content.name = "Content"
	_note_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_view.add_child(_note_content)
	_note_bar = Control.new()
	_note_bar.name = "Bar"
	_note_bar.set_script(NoteBarScript)
	_note_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_note_bar.gui_input.connect(_on_note_wheel)
	window.add_child(_note_bar)
	_note_bar.ratio_changed.connect(_on_note_bar_ratio)


func _place_note_label(label: Label, column: float, y: float, height: float) -> void:
	label.position = Vector2(0.0, y)
	label.size = Vector2(column, height)
	label.offset_left = 0.0
	label.offset_top = y
	label.offset_right = column
	label.offset_bottom = y + height


func _clear_note_extra() -> void:
	var extras: Array[Node] = []
	for child in _note_content.get_children():
		if child.name != "Body" and child.name != "Sign":
			extras.append(child)
	for child in extras:
		child.free()


func _add_note_text(text: String, column: float, y: float) -> float:
	var source: Label = $Note/Window/View/Content/Body
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", source.get_theme_font("font"))
	label.add_theme_font_size_override("font_size", source.get_theme_font_size("font_size"))
	label.add_theme_color_override("font_color", source.get_theme_color("font_color"))
	label.position = Vector2(0.0, y)
	label.size = Vector2(column, 4.0)
	_note_content.add_child(label)
	var height := label.get_minimum_size().y
	label.size = Vector2(column, height)
	return y + height + 10.0


func _add_note_picture(texture: Texture2D, x: float, y: float, side: float) -> void:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.position = Vector2(x, y)
	rect.size = Vector2(side, side)
	_note_content.add_child(rect)


func _on_note_wheel(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_note(-NOTE_WHEEL)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_note(NOTE_WHEEL)
			get_viewport().set_input_as_handled()


func _on_note_bar_ratio(ratio: float) -> void:
	_note_offset = ratio * _note_max
	if _note_content != null:
		_note_content.position.y = -_note_offset


func _scroll_note(delta: float) -> void:
	if _note_max <= 0.0:
		return
	_note_offset = clampf(_note_offset + delta, 0.0, _note_max)
	_note_content.position.y = -_note_offset
	_note_bar.set_ratio(_note_offset / _note_max)


func _reset_note_scroll() -> void:
	_note_offset = 0.0
	if _note_content != null:
		_note_content.position.y = 0.0
	if _note_bar != null:
		_note_bar.set_ratio(0.0)


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


func _setup_raven() -> void:
	var raven: Sprite2D = $Props/Raven
	_raven_image = raven.texture.get_image()
	var used := _raven_image.get_used_rect()
	var hit := Control.new()
	hit.name = "Hit"
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.position = Vector2(used.position) - raven.texture.get_size() * 0.5
	hit.size = Vector2(used.size)
	hit.gui_input.connect(_on_raven_input)
	raven.add_child(hit)


func _on_raven_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	var local := (event as InputEventMouseButton).position
	var hit := $Props/Raven/Hit as Control
	var pixel := hit.position + local + ($Props/Raven as Sprite2D).texture.get_size() * 0.5
	var x := int(pixel.x)
	var y := int(pixel.y)
	if x < 0 or y < 0 or x >= _raven_image.get_width() or y >= _raven_image.get_height():
		return
	if _raven_image.get_pixel(x, y).a <= 0.08:
		return
	_speak_raven()


func _speak_raven() -> void:
	if phase == Phase.TITLE or phase == Phase.MINI or phase == Phase.TALK or phase == Phase.OVER or phase == Phase.CLEAR:
		return
	if speech.visible or _pot_shaking or bag_interior.visible or recipe_book.visible:
		return
	_last_raven_tip = _next_line(RAVEN_TIPS, _last_raven_tip)
	_layout_hint(RAVEN_TIPS[_last_raven_tip], true)
	speech.visible = true
	_after_speech = Callable()


func _next_line(lines: PackedStringArray, last: int) -> int:
	var count := lines.size()
	var index := randi() % count
	if count > 1 and index == last:
		index = (index + 1 + randi() % (count - 1)) % count
	return index


func _show_mini_hint(tool_id: String) -> void:
	if not MINI_HINTS.has(tool_id):
		return
	_layout_hint(str(MINI_HINTS[tool_id]), false)
	speech.visible = true
	_mini_hint = true
	_after_speech = Callable()
	$Speech/Catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _hide_mini_hint() -> void:
	if not _mini_hint:
		return
	_mini_hint = false
	speech.visible = false
	$Speech/Catcher.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_speech_input(event: InputEvent) -> void:
	if not speech.visible or _mini_hint:
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


func _layout_hint(body: String, raven: bool) -> void:
	var font := speech_label.get_theme_font("font")
	var body_size := speech_label.get_theme_font_size("font_size")
	var body_color := speech_label.get_theme_color("font_color")
	var title_size := speech_name.get_theme_font_size("font_size")
	var title_color := speech_name.get_theme_color("font_color")
	var max_width := SPEECH_WIDTH - HINT_PAD * 2.0
	speech_name.visible = false
	for child in speech_lines.get_children():
		child.free()
	var line_h := font.get_height(body_size)
	var lines := _wrap_speech(font, body, body_size, max_width)
	var y: float
	if raven:
		var title_h := font.get_height(title_size)
		var block_h := title_h + 8.0 + lines.size() * line_h
		var area_top := SPEECH_TOP + 16.0
		var area_h := (SPEECH_BOTTOM - 20.0) - area_top
		y = area_top + maxf(0.0, (area_h - block_h) * 0.5)
		y = _add_centered_line(RAVEN_TITLE, y, title_size, title_color, font, max_width) + 8.0
	else:
		y = SPEECH_TOP + 14.0
		y = _add_centered_line(HINT_TITLE, y, title_size, title_color, font, max_width) + 6.0
		var room := (SPEECH_BOTTOM - 20.0) - y
		y += maxf(0.0, (room - lines.size() * line_h) * 0.5)
	for line in lines:
		y = _add_centered_line(line, y, body_size, body_color, font, max_width)


func _add_centered_line(text: String, y: float, font_size: int, color: Color, font: Font, max_width: float) -> float:
	var line_h := font.get_height(font_size)
	var x := _speech_left(y + line_h * 0.5) + HINT_PAD
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.position = Vector2(x, y)
	label.size = Vector2(max_width, line_h)
	speech_lines.add_child(label)
	return y + line_h


func _show_speech(text: String, then: Callable) -> void:
	_mini_hint = false
	$Speech/Catcher.mouse_filter = Control.MOUSE_FILTER_STOP
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
	_stop_pot_shake()
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
	_stop_pot_shake()
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
