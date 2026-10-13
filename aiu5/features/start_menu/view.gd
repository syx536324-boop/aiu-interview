# Presents start, save-picker, new-save and pause panels; actions are emitted to the controller.
extends CanvasLayer

signal gift_details_requested
signal continue_requested
signal new_requested
signal create_requested(title: String)
signal load_requested(id: String)
signal back_requested
signal resume_requested
signal return_requested
signal quit_requested
const GiftDetails := preload("res://features/start_menu/gift_details.gd")
const Backdrop := preload("res://features/start_menu/backdrop.gd")
var root: Control
var panel: PanelContainer
var title_label: Label
var message: Label
var list: VBoxContainer
var input: LineEdit
var continue_button: Button
var create_button: Button
var load_button: Button
var save_rows: Array[Button] = []
var selected_id := ""
var screen := "home"
var font := SystemFont.new()

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = Theme.new()
	root.theme.default_font = font
	root.theme.default_font_size = 13
	add_child(root)

func _clear() -> void:
	for node in root.get_children():
		root.remove_child(node)
		node.queue_free()
	save_rows.clear()
	selected_id = ""

func _label(parent: Node, text: String, size := 13, tint := Color("eadab6")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label

func _style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_content_margin_all(8)
	return style

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 37
	button.add_theme_stylebox_override("normal", _style(Color("675039"), Color("a48254")))
	button.add_theme_stylebox_override("hover", _style(Color("806244"), Color("e5c68b")))
	button.add_theme_stylebox_override("pressed", _style(Color("4b3e2f"), Color("d4b47a")))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), Color("eed8a4")))
	button.add_theme_stylebox_override("disabled", _style(Color("443a30"), Color("65533d")))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _page(title: String, bounds: Rect2) -> VBoxContainer:
	_clear()
	var background := Backdrop.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	panel = PanelContainer.new()
	panel.position = bounds.position
	panel.size = bounds.size
	panel.add_theme_stylebox_override("panel", _style(Color("3a3027"), Color("b18d5b")))
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	title_label = _label(column, title, 21, Color("f3d79a"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return column

func show_home(has_saves: bool, warning := "") -> void:
	screen = "home"
	visible = true
	var column := _page("沙盘上的生活", Rect2(184, 58, 272, 290))
	var subtitle := _label(column, "沙海之中，建起自己的村落", 11, Color("c1ad88"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_button = _button(column, "继续游戏", func() -> void: continue_requested.emit())
	continue_button.disabled = not has_saves
	_button(column, "创建新存档", func() -> void: new_requested.emit())
	_button(column, "赐予详情", func() -> void: gift_details_requested.emit())
	message = _label(column, warning, 10, Color("e6b28c"))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.y = 24
	var foot := _label(root, "每一座村落，都有自己的故事。", 11, Color("f1dfb6"))
	foot.position = Vector2(230, 371)
	if has_saves: continue_button.grab_focus()

func show_gift_details(entries: Array[Dictionary]) -> void:
	screen = "gifts"
	visible = true
	var column := _page("赐予详情 · 18类物体", Rect2(28, 12, 584, 376))
	_label(column, "在祭台识别实物，每次赐予1件或1只。向下滚动查看全部。", 11, Color("c1ad88"))
	var details := GiftDetails.new()
	column.add_child(details)
	details.populate(entries)
	_label(column, "符文代表赐予来源；魔法12级后可选木、水、火、土属性。", 10, Color("bfb0d0"))
	_button(column, "返回开始界面  [Esc]", func() -> void: back_requested.emit()).grab_focus()

func show_slots(slots: Array[Dictionary]) -> void:
	screen = "slots"
	var column := _page("选择存档", Rect2(84, 35, 472, 330))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 185
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 7)
	scroll.add_child(list)
	for slot in slots:
		var stamp := "尚未开始" if int(slot.saved_at) == 0 else Time.get_datetime_string_from_unix_time(int(slot.saved_at) + int(Time.get_time_zone_from_system().bias) * 60).replace("T", " ").left(16)
		var description := "%s  ·  %d人 / %d间房屋\n上次保存  %s" % [str(slot.title), int(slot.population), int(slot.homes), stamp]
		if not slot.valid: description = str(slot.title) + " · 存档无法读取"
		var row := _button(list, description, func() -> void: _select(slot.id))
		row.name = slot.id
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 57
		row.add_theme_font_size_override("font_size", 12)
		row.toggle_mode = true
		row.disabled = not slot.valid
		save_rows.append(row)
	message = _label(column, "请选择要继续的村落。" if not slots.is_empty() else "还没有存档，返回后创建一座新村落。", 11)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)
	_button(footer, "返回", func() -> void: back_requested.emit())
	load_button = _button(footer, "进入村落", func() -> void: load_requested.emit(selected_id))
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_button.disabled = true
	for row in save_rows:
		if not row.disabled:
			_select(row.name)
			break

func _select(id: String) -> void:
	selected_id = id
	for row in save_rows: row.button_pressed = row.name == id
	load_button.disabled = id == ""

func show_new(default_title: String) -> void:
	screen = "new"
	var column := _page("创建新存档", Rect2(126, 51, 388, 298))
	_label(column, "存档名称", 12)
	input = LineEdit.new()
	input.max_length = 24
	input.text = default_title
	input.placeholder_text = "给这座村落取个名字"
	input.custom_minimum_size.y = 33
	column.add_child(input)
	var description := _label(column, "一间灶房 · 两间住房 · 一座祭台\n三名可操控角色，携手在沙漠中生存。\n河西有同样大的森林与草药屋，可采药合成汤剂。", 12)
	description.add_theme_constant_override("line_spacing", 6)
	message = _label(column, "新存档独立保存，已有村落会保留。", 11, Color("b9c69c"))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.y = 28
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)
	_button(footer, "返回", func() -> void: back_requested.emit())
	create_button = _button(footer, "创建并开始", func() -> void: create_requested.emit(input.text))
	create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text_submitted.connect(func(text: String) -> void: create_requested.emit(text))
	input.grab_focus()

func show_pause(title: String) -> void:
	screen = "pause"
	visible = true
	var column := _page("休 息 片 刻", Rect2(166, 64, 308, 280))
	_label(column, title, 12).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(column, "继续游玩", func() -> void: resume_requested.emit()).grab_focus()
	_button(column, "保存并返回开始界面", func() -> void: return_requested.emit())
	_button(column, "保存并退出游戏", func() -> void: quit_requested.emit())
	message = _label(column, "游戏已暂停 · Esc 返回", 11, Color("c6b58f"))

func show_error(text: String) -> void:
	message.text = text
	message.add_theme_color_override("font_color", Color("efb596"))
