# Presents session snapshots without implementing movement or interaction rules.
extends CanvasLayer

signal resident_requested(index: int)
signal roster_close_requested
signal founder_names_requested(male: String, female: String)
signal attributes_requested(id: String)
signal weapon_requested
const ItemIcon := preload("res://features/interface/item_icon.gd")
var weapon_button: Button
var weapon_icon: Control
var weapon_label: Label
var weapon_durability: Control
const DurabilityBar := preload("res://features/interface/durability_bar.gd")
const StatusBar := preload("res://features/interface/status_bar.gd")

var status_label: Label
var prompt_label: Label
var prompt_panel: ColorRect
var crop_label: Label
var notice_label: Label
var clock_label: Label
var view_label: Label
var population_label: Label
var help_label: Label
var belongings_hint: Label
var skill_hint: Label
var roster_root: ColorRect
var roster_info: Label
var roster_box: VBoxContainer
var roster_buttons: Array[Button] = []
var attribute_buttons: Array[Button] = []
var names_root: ColorRect
var male_input: LineEdit
var female_input: LineEdit
var names_message: Label
var rename_button: Button
var save_names_button: Button
var latest_names: Dictionary = {}
var stat_bars: Dictionary = {}
var stat_labels: Dictionary = {}
var disease_label: Label
var font := SystemFont.new()

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	var root := Control.new()
	root.name = "Overlay"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel(root, Rect2(0, 0, 640, 28), Color("3e3429"))
	_text(root, "赤沙村", Vector2(14, 5), 14, Color("f6dfa7"))
	population_label = _text(root, "", Vector2(76, 8), 10, Color("baad8e"))
	status_label = _text(root, "", Vector2(282, 7), 11, Color("e9dbb8"))
	status_label.size = Vector2(344, 18)
	status_label.clip_text = true
	_panel(root, Rect2(0, 376, 640, 24), Color("3e3429"))
	help_label = _text(root, "", Vector2(14, 382), 10, Color("e9dbb8"))
	prompt_panel = _panel(root, Rect2(205, 63, 310, 25), Color(0.21, 0.18, 0.14, 0.90))
	prompt_label = _text(root, "", Vector2(245, 68), 11, Color("f6dfa7"))
	prompt_label.size.x = 310
	prompt_label.position.x = 205
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crop_label = _text(root, "", Vector2(239, 91), 10, Color("f6dfa7"))
	crop_label.size.x = 290
	crop_label.position.x = 215
	crop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crop_label.add_theme_color_override("font_outline_color", Color("493c2d"))
	crop_label.add_theme_constant_override("outline_size", 3)
	notice_label = _text(root, "", Vector2(90, 354), 11, Color("fff0ce"))
	notice_label.size.x = 460
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_color_override("font_outline_color", Color("493c2d"))
	notice_label.add_theme_constant_override("outline_size", 3)
	clock_label = _text(root,"",Vector2(516,86),11,Color("fff0ce"))
	clock_label.add_theme_color_override("font_outline_color",Color("31271d"))
	clock_label.add_theme_constant_override("outline_size",3)
	view_label = _text(root, "", Vector2(520, 63), 10, Color("fff0ce"))
	view_label.add_theme_color_override("font_outline_color", Color("493c2d"))
	view_label.add_theme_constant_override("outline_size", 3)
	belongings_hint = _text(root, "B 背包  F 布置  Q 锄地  G 种/收", Vector2(12, 64), 10, Color("f6dfa7"))
	belongings_hint.add_theme_color_override("font_outline_color", Color("493c2d"))
	belongings_hint.add_theme_constant_override("outline_size", 3)
	skill_hint=_text(root,"Z 赋能 · H 三级 · K 四级 · L 五级",Vector2(12,112),10,Color("f6dfa7"))
	skill_hint.add_theme_color_override("font_outline_color",Color("493c2d"))
	skill_hint.add_theme_constant_override("outline_size",3)
	_panel(root, Rect2(0, 28, 640, 27), Color("312c25"))
	var labels := {"life": "生命", "hunger": "饥饿", "thirst": "饥渴", "health": "健康", "mana": "魔力"}
	var colors := [Color("bf6960"), Color("c6a25c"), Color("6caaaf"), Color("82aa72"), Color("9980cc")]
	var index := 0
	for key: String in labels:
		var x := 10 + index * 104
		stat_labels[key] = _text(root, labels[key], Vector2(x, 31), 10, Color("f2dbad"))
		var bar := StatusBar.new()
		bar.position = Vector2(x + 57, 34)
		bar.size = Vector2(42, 12)
		bar.tint = colors[index]
		root.add_child(bar)
		stat_bars[key] = bar
		index += 1
	disease_label = _text(root, "", Vector2(534, 31), 10, Color("f1a97a"))
	weapon_button = Button.new()
	weapon_button.name = "WeaponSlot"
	weapon_button.position = Vector2(402,306)
	weapon_button.size = Vector2(44,44)
	_style_button(weapon_button)
	weapon_button.focus_mode = Control.FOCUS_NONE
	weapon_button.pressed.connect(func() -> void: weapon_requested.emit())
	root.add_child(weapon_button)
	weapon_icon = ItemIcon.new()
	weapon_icon.position = Vector2(10,7)
	weapon_icon.size = Vector2(24,24)
	weapon_button.add_child(weapon_icon)
	weapon_label = _text(weapon_button,"武器",Vector2(9,29),9,Color("f6dfa7"))
	weapon_durability = DurabilityBar.new()
	weapon_durability.position = Vector2(2,40)
	weapon_durability.size = Vector2(40,3)
	weapon_button.add_child(weapon_durability)
	_build_roster(root)

func bind_session(session: Node) -> void:
	session.state_changed.connect(_present)
	_present(session.snapshot())

func _present(state: Dictionary) -> void:
	var cycle: Dictionary = state.get("day_night",{})
	clock_label.text = "第%d天 %s\n%s" % [int(cycle.get("day",1)),cycle.get("clock","08:00"),cycle.get("phase","白昼")]
	var weapon: Dictionary = state.get("weapon",{})
	weapon_icon.set_item(str(weapon.get("item","")), bool(weapon.get("magical", false)))
	weapon_label.text = str(weapon.get("name","武器")) if weapon.get("item", "") != "" else "武器"
	weapon_button.tooltip_text = "%s · 攻击%d · 点击卸回背包 · J 攻击 / E 采集" % [weapon.get("name",""),weapon.get("attack",0)] if weapon.get("item", "") != "" else "武器位 · 点击打开背包，选择镐子、斧、剑或弓装备"
	weapon_durability.visible = weapon.get("item","") != ""
	weapon_durability.value = int(weapon.get("wear",{}).get("durability",40))
	weapon_durability.queue_redraw()
	if weapon.get("item","") != "" and weapon_durability.value == 0: weapon_label.text = "损坏"
	if weapon.get("item","") != "": weapon_button.tooltip_text += "\n" + str(weapon.get("durability_text",""))
	weapon_button.visible = not state.overview and not state.roster_open and not state.inventory.open and not state.furnishing.open and not state.get("attributes",{}).get("open",false) and not state.get("awakening",{}).get("open",false) and not state.get("workshop",{}).get("open",false) and not state.get("menu_paused",false)
	weapon_button.disabled = not weapon.get("editable",false)
	var values: Dictionary = state.get("vitals", {})
	var names := {"life": "生命", "hunger": "饥饿", "thirst": "饥渴", "health": "健康", "mana": "魔力"}
	for key: String in stat_bars:
		var limit := float(state.get("max_life",10)) if key=="life" else 10.0
		stat_bars[key].maximum=limit
		stat_bars[key].value = values.get(key, 10)
		stat_bars[key].queue_redraw()
		stat_labels[key].text = "%s %s/%d" % [names[key],str(snappedf(float(values.get(key,10)),0.1)),int(limit)]
	disease_label.text = "肠胃炎 跑速-30%" if values.get("ill", false) else "当前角色计时"
	disease_label.tooltip_text = "仅操控者每3分钟消耗1格饥饿和饥渴；其他角色五项状态与生存计时锁定。"
	if values.get("low_health", false): disease_label.text = "低健康 %d秒" % ceili(1800 - float(values.get("low_time", 0)))
	status_label.text = "%s · %s    水：%s  田：%s" % [state["resident"], state["role"], state.get("water_text", "满" if state["water"] else "空"), "已浇" if state["watered"] else "待浇"]
	status_label.tooltip_text = status_label.text
	population_label.text = "%d 人 · %d 间房屋 / %s" % [state["population"], state["homes"], state.get("biome", "干旱地带")]
	help_label.text = "WASD / 方向键  移动   Shift  奔跑   Tab / 1-%d  切换   C  角色   E  互动   M  全景" % mini(9, state["roster"].size())
	prompt_label.text = state["prompt"]
	crop_label.text = state.get("detail", state.get("crop_detail", ""))
	notice_label.text = state["notice"]
	view_label.text = "全图已暂停 · M 返回" if state["overview"] else "村民视角 · M 全景"
	if state["inside"]:
		view_label.text = state["room_name"] + (" · 地下" if state.get("underground", false) else " · 屋内")
		help_label.text = "WASD / 方向键  移动   Shift  奔跑   Tab / 1-%d  切换   C  角色   E  查看 / 出门" % mini(9, state["roster"].size())
	var editing: bool = state["furnishing"]["open"]
	prompt_label.visible = not editing and not state["overview"]
	prompt_panel.visible = prompt_label.visible
	view_label.visible = not editing
	belongings_hint.visible = not editing
	skill_hint.visible=weapon_button.visible
	var effects: Dictionary=state.get("skill_status",{})
	var b: Dictionary=effects.get("buffs",{})
	var parts: PackedStringArray=[]
	for field in ["empower","shield","regen"]:
		if float(b.get(field,0))>0: parts.append("%s %d秒" % [{"empower":"赋能","shield":"水盾","regen":"回春"}[field],ceili(float(b[field]))])
	if float(effects.get("hut_remaining",0))>0: parts.append("土屋 %d秒" % ceili(float(effects.hut_remaining)))
	skill_hint.text="Z赋能 H三级 K四级 L五级"+("\n"+" · ".join(parts) if not parts.is_empty() else "")
	crop_label.visible = not editing and not state["overview"] and not state["inventory"]["open"] and crop_label.text != ""
	if editing:
		help_label.text = "左键 选取 / 放置   R 旋转   右键 / Esc 取消选择   Delete 移除   F 完成布置"
		notice_label.position.y = 322
	else:
		notice_label.position.y = 354
	roster_root.visible = state["roster_open"]
	latest_names = state["founder_names"]
	if not roster_root.visible and names_root.visible:
		_close_name_editor()
	if roster_root.visible: _update_roster(state)

func _build_roster(root: Control) -> void:
	roster_root = ColorRect.new()
	roster_root.name = "CharacterPanel"
	roster_root.size = Vector2(640, 400)
	roster_root.color = Color(0.1, 0.09, 0.07, 0.66)
	roster_root.visible = false
	root.add_child(roster_root)
	var panel := PanelContainer.new()
	panel.position = Vector2(76, 56)
	panel.size = Vector2(488, 312)
	var style := _button_style(Color("3e3529"))
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color("bea271")
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	roster_root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var title := Label.new()
	title.text = "选择可操控角色"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("f6dfa7"))
	column.add_child(title)
	roster_info = Label.new()
	roster_info.add_theme_font_override("font", font)
	roster_info.add_theme_font_size_override("font_size", 10)
	roster_info.add_theme_color_override("font_color", Color("c7b897"))
	column.add_child(roster_info)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 196)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	roster_box = VBoxContainer.new()
	roster_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_box.add_theme_constant_override("separation", 6)
	scroll.add_child(roster_box)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	column.add_child(footer)
	rename_button = Button.new()
	rename_button.text = "给男、女村民取名"
	_style_button(rename_button)
	rename_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rename_button.pressed.connect(_show_name_editor)
	footer.add_child(rename_button)
	var close := Button.new()
	close.text = "关闭  [C / Esc]"
	_style_button(close)
	close.pressed.connect(func() -> void: roster_close_requested.emit())
	footer.add_child(close)
	_build_name_editor()

func _build_name_editor() -> void:
	names_root = ColorRect.new()
	names_root.size = Vector2(640, 400)
	names_root.color = Color(0.08, 0.06, 0.04, 0.82)
	names_root.visible = false
	roster_root.add_child(names_root)
	var panel := PanelContainer.new()
	panel.position = Vector2(145, 82)
	panel.size = Vector2(350, 236)
	var style := _button_style(Color("3e3529"))
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	names_root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "为两名原始村民取名"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("f6dfa7"))
	column.add_child(title)
	male_input = _name_field(column, "男村民")
	female_input = _name_field(column, "女村民")
	names_message = Label.new()
	names_message.add_theme_font_override("font", font)
	names_message.add_theme_font_size_override("font_size", 10)
	names_message.add_theme_color_override("font_color", Color("e9c68d"))
	column.add_child(names_message)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	column.add_child(footer)
	save_names_button = Button.new()
	save_names_button.text = "保存姓名"
	save_names_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(save_names_button)
	save_names_button.pressed.connect(func() -> void: founder_names_requested.emit(male_input.text, female_input.text))
	footer.add_child(save_names_button)
	var cancel := Button.new()
	cancel.text = "取消"
	_style_button(cancel)
	cancel.pressed.connect(_close_name_editor)
	footer.add_child(cancel)

func _name_field(parent: Control, label_text: String) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("f4e3bd"))
	row.add_child(label)
	var field := LineEdit.new()
	field.max_length = 12
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.custom_minimum_size.y = 30
	field.add_theme_font_override("font", font)
	field.add_theme_font_size_override("font_size", 13)
	field.placeholder_text = "请输入姓名"
	row.add_child(field)
	return field

func _show_name_editor() -> void:
	male_input.text = latest_names.get("male", "")
	female_input.text = latest_names.get("female", "")
	names_message.text = "每个姓名 1–12 个字，保存后下次启动仍会保留。"
	names_root.visible = true
	male_input.grab_focus()
	male_input.select_all()

func _close_name_editor() -> void:
	male_input.release_focus()
	female_input.release_focus()
	names_root.visible = false

func present_names_result(ok: bool, message: String) -> void:
	if ok:
		_close_name_editor()
	else:
		names_message.text = message

func _update_roster(state: Dictionary) -> void:
	var roster: Array = state["roster"]
	roster_info.text = "%d 人可操控 · 未操控者五项状态与生存计时锁定" % roster.size()
	if roster_buttons.size() != roster.size():
		for row in roster_box.get_children(): row.queue_free()
		roster_buttons.clear()
		attribute_buttons.clear()
		for entry: Dictionary in roster:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			roster_box.add_child(row)
			var button := Button.new()
			button.custom_minimum_size = Vector2(0, 62)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var icon := AtlasTexture.new()
			icon.atlas = entry["sheet"]
			icon.region = Rect2(0, 0, 16, 16)
			button.icon = icon
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 28)
			button.add_theme_constant_override("h_separation", 10)
			_style_button(button)
			button.add_theme_font_size_override("font_size", 10)
			button.add_theme_color_override("font_disabled_color", Color("c7b897"))
			button.pressed.connect(func() -> void: resident_requested.emit(entry["index"]))
			row.add_child(button)
			roster_buttons.append(button)
			var attributes := Button.new()
			attributes.text = "属性"
			attributes.custom_minimum_size.x = 48
			_style_button(attributes)
			attributes.pressed.connect(func() -> void: attributes_requested.emit(str(entry.id)))
			row.add_child(attributes)
			attribute_buttons.append(attributes)
	for i in range(roster.size()):
		var entry: Dictionary = roster[i]
		roster_buttons[i].disabled = entry.get("dead", false)
		var values: Dictionary = entry.get("vitals", {})
		var mode := "已阵亡" if entry.get("dead", false) else ("状态锁定" if entry.get("frozen", false) else "正在操控")
		var location := "已阵亡 · 可在祭坛献祭复活" if entry.get("dead", false) else str(entry["area"]) + " · " + mode
		roster_buttons[i].text = "%d  %s · %s\n     %s\n     生命 %s/%d  饥饿 %d/10  饥渴 %d/10  健康 %d/10  魔力 %d/10" % [i + 1, entry["name"], entry["role"], location, str(snappedf(float(values.get("life",10)),0.1)),int(values.get("max_life",10)), values.get("hunger", 10), values.get("thirst", 10), values.get("health", 10), values.get("mana", 10)]
		roster_buttons[i].add_theme_stylebox_override("normal", _button_style(Color("786343") if i == state["selected"] else Color("554735")))

func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _style_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color("f4e3bd"))
	button.add_theme_stylebox_override("normal", _button_style(Color("554735")))
	button.add_theme_stylebox_override("hover", _button_style(Color("84704d")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("a18a5b")))

func _panel(parent: Control, bounds: Rect2, color: Color) -> ColorRect:
	var panel := ColorRect.new()
	panel.position = bounds.position
	panel.size = bounds.size
	panel.color = color
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel

func _text(parent: Control, text: String, at: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
