# Presents character equipment, magic progress, elemental skills and altar awakening through signals.
extends CanvasLayer

signal close_requested
signal awaken_open_requested
signal awaken_close_requested
signal awaken_requested(element: String)
signal equip_requested(slot: String, item: String, bag_index: int)
signal unlock_requested(skill: String)
signal claim_gear_requested
signal branch_selected(skill: String)
signal crystals_requested
const ItemIcon := preload("res://features/interface/item_icon.gd")
var font := SystemFont.new()
var attributes_root: ColorRect
var awakening_root: ColorRect
var level_root: Control
var achievement_root: Control
var achievement_tab: Button
var achievement_text: RichTextLabel
var tree_root: Control
var picker_root: ColorRect
var title: Label
var portrait: TextureRect
var protection_label: Label
var level_label: Label
var element_label: Label
var xp_label: Label
var xp_bar: ProgressBar
var feedback: Label
var skill_points: Label
var claim_button: Button
var awaken_button: Button
var level_tab: Button
var tree_tab: Button
var gear_buttons: Dictionary = {}
var skill_buttons: Array[Button] = []
var skill_descriptions: Array[Label] = []
var branches: Array[Button] = []
var wires: Control
var picker_title: Label
var gear_choice: OptionButton
var wear_button: Button
var remove_button: Button
var awakening_title: Label
var selection_label: Label
var awakening_feedback: Label
var confirm_button: Button
var element_buttons: Dictionary = {}
var current: Dictionary = {}
var selected_slot := ""
var selected_element := ""
var page := "level"
var styles: Dictionary = {}
var branch_panel: Control
var branch_title: Label
var branch_cards: Array=[]
var branch_page := ""
var crystal_button: Button

class Wires extends Control:
	var learned := -1
	func _draw() -> void:
		for i in range(4):
			draw_line(Vector2(70,70+i*32),Vector2(70,76+i*32),Color("b9c57a") if learned>i+1 else Color("806f51"),2)
		var color := Color("b9c57a") if learned==5 else Color("806f51")
		draw_line(Vector2(70,198),Vector2(70,202),color,2)
		draw_line(Vector2(70,202),Vector2(400,202),color,2)

func _ready() -> void:
	layer = 3
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	attributes_root = _overlay()
	_panel(attributes_root, Rect2(52, 55, 536, 314))
	title = _label(attributes_root, "角色属性", Vector2(68, 65), 16)
	var back := _button(attributes_root, "返回角色", Rect2(488, 64, 84, 25))
	back.pressed.connect(func() -> void: close_requested.emit())
	level_tab = _button(attributes_root, "魔法等级", Rect2(68, 94, 124, 27))
	tree_tab = _button(attributes_root, "技能树", Rect2(200, 94, 124, 27))
	achievement_tab = _button(attributes_root,"成就",Rect2(332,94,124,27))
	achievement_tab.pressed.connect(func() -> void: _show_page("achievements"))
	level_tab.pressed.connect(func() -> void: _show_page("level"))
	tree_tab.pressed.connect(func() -> void: _show_page("tree"))
	level_root = Control.new()
	level_root.position = Vector2(68, 130)
	attributes_root.add_child(level_root)
	tree_root = Control.new()
	tree_root.position = level_root.position
	attributes_root.add_child(tree_root)
	_build_level()
	_build_tree()
	_build_achievements()
	feedback = _label(attributes_root, "", Vector2(68, 376), 10)
	feedback.size = Vector2(504, 16)
	feedback.clip_text = true
	_build_picker()
	_build_awakening()
	attributes_root.visible = false
	awakening_root.visible = false
	_show_page("level")

func bind_session(session: Node) -> void:
	session.state_changed.connect(_present)
	_present(session.snapshot())

func _build_level() -> void:
	portrait = TextureRect.new()
	portrait.position = Vector2(204, 6)
	portrait.size = Vector2(96, 96)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	level_root.add_child(portrait)
	var positions := {"head": Vector2(108, 8), "armor": Vector2(108, 80), "legs": Vector2(340, 8), "feet": Vector2(340, 80)}
	var names := {"head": "头盔", "armor": "盔甲", "legs": "护腿", "feet": "靴子"}
	for slot: String in positions:
		var at: Vector2 = positions[slot]
		var caption := _label(level_root, names[slot], at - Vector2(0, 14), 10)
		caption.size.x = 56
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var button := _button(level_root, "", Rect2(at, Vector2(56, 52)))
		var icon := ItemIcon.new()
		icon.position = Vector2(16, 4)
		icon.size = Vector2(24, 24)
		button.add_child(icon)
		var hint := _label(button, "空", Vector2(4, 33), 10)
		hint.size.x = 48
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gear_buttons[slot] = {"button": button, "icon": icon, "hint": hint}
		button.pressed.connect(func() -> void: _open_picker(slot))
	protection_label = _label(level_root,"",Vector2(0,80),11)
	protection_label.size=Vector2(100,58)
	protection_label.tooltip_text="每件皮装备减伤5%，四件20%；水盾按剩余伤害减30%，合计44%。普通减伤相乘封顶50%；石阵另减剩余伤害10%，最高55%。"
	element_label = _label(level_root, "未觉醒", Vector2(172, 108), 12)
	element_label.size.x = 160
	element_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label = _label(level_root, "魔法等级 lv.1", Vector2(172, 132), 13)
	level_label.size.x = 160
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_bar = ProgressBar.new()
	xp_bar.position = Vector2(76, 156)
	xp_bar.size = Vector2(352, 20)
	xp_bar.add_theme_font_size_override("font_size", 10)
	xp_bar.show_percentage = false
	xp_bar.add_theme_stylebox_override("background", _style(Color("302c25")))
	level_root.add_child(xp_bar)
	xp_label = _label(level_root, "0 / 100 魔法点", Vector2(76, 183), 10)
	xp_label.size.x = 352
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(level_root,"皮制 / 铁制装备在铁匠铺合成",Vector2(0,207),10)
	awaken_button = _button(level_root,"在祭台觉醒 [R]",Rect2(220,200,136,26))
	awaken_button.pressed.connect(func() -> void: awaken_open_requested.emit())
	crystal_button=_button(level_root,"暂无待领晶石",Rect2(368,200,136,26))
	crystal_button.add_theme_font_size_override("font_size",10)
	crystal_button.pressed.connect(func() -> void: crystals_requested.emit())

func _build_tree() -> void:
	wires = Wires.new()
	wires.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree_root.add_child(wires)
	skill_points = _label(tree_root, "技能点：0", Vector2(0, 4), 13)
	_label(tree_root, "依次点亮，每级10技能点 · 主动技能在游戏中按快捷键施放", Vector2(0, 23), 10)
	for i in range(5):
		var button := _button(tree_root, "一级", Rect2(0, 44+i*32, 140, 26))
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(func() -> void:
			if current.get("skills", []).size() > i: unlock_requested.emit(str(current.skills[i].id)))
		skill_buttons.append(button)
		var detail := _label(tree_root,"",Vector2(151,44+i*32),10)
		detail.size=Vector2(350,31)
		detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		skill_descriptions.append(detail)
	for i in range(3):
		var button := _button(tree_root, ["建设分支", "战斗分支", "防御分支"][i], Rect2(0 + i * 170, 206, 158, 22))
		button.add_theme_font_size_override("font_size", 10)
		button.disabled = true
		branches.append(button)
		button.pressed.connect(func() -> void: _open_branch(["build","battle","guard"][i]))
	_build_branch_panel()

func _build_picker() -> void:
	picker_root = ColorRect.new()
	picker_root.color = Color(0.06, 0.05, 0.04, 0.85)
	picker_root.size = Vector2(640, 400)
	attributes_root.add_child(picker_root)
	_panel(picker_root, Rect2(174, 110, 292, 214))
	picker_title = _label(picker_root, "装备", Vector2(194, 124), 16)
	gear_choice = OptionButton.new()
	gear_choice.position=Vector2(194,156)
	gear_choice.size=Vector2(252,28)
	gear_choice.add_theme_font_override("font",font)
	gear_choice.add_theme_font_size_override("font_size",11)
	gear_choice.item_selected.connect(func(_index: int) -> void: _update_picker())
	picker_root.add_child(gear_choice)
	wear_button = _button(picker_root, "穿戴", Rect2(194, 192, 252, 28))
	remove_button = _button(picker_root, "卸下", Rect2(194, 228, 252, 28))
	var cancel := _button(picker_root, "取消", Rect2(194, 278, 252, 28))
	wear_button.pressed.connect(func() -> void:
		for gear: Dictionary in current.get("gear", []):
			if gear.slot == selected_slot:
				if gear_choice.selected>=0: equip_requested.emit(selected_slot,str(gear_choice.get_item_metadata(gear_choice.selected).item),int(gear_choice.get_item_metadata(gear_choice.selected).bag_index))
				break
		picker_root.visible = false)
	remove_button.pressed.connect(func() -> void:
		equip_requested.emit(selected_slot, "", -1)
		picker_root.visible = false)
	cancel.pressed.connect(func() -> void: picker_root.visible = false)
	picker_root.visible = false

func _build_awakening() -> void:
	awakening_root = _overlay()
	_panel(awakening_root, Rect2(110, 94, 420, 218))
	awakening_title = _label(awakening_root, "在祭台觉醒", Vector2(130, 110), 16)
	_label(awakening_root, "每名角色只能选一种属性，确认后不可更换。", Vector2(130, 145), 12)
	var elements := {"wood": "木", "water": "水", "fire": "火", "earth": "土"}
	var i := 0
	for id: String in elements:
		var button := _button(awakening_root, elements[id], Rect2(130 + i * 96, 176, 88, 42))
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(func() -> void: _select_element(id))
		element_buttons[id] = button
		i += 1
	selection_label = _label(awakening_root, "请选择一种魔法属性", Vector2(130, 230), 12)
	awakening_feedback = _label(awakening_root, "", Vector2(130, 249), 10)
	awakening_feedback.size = Vector2(380, 14)
	awakening_feedback.clip_text = true
	var cancel := _button(awakening_root, "取消", Rect2(130, 268, 160, 28))
	cancel.pressed.connect(func() -> void: awaken_close_requested.emit())
	confirm_button = _button(awakening_root, "确认觉醒", Rect2(310, 268, 200, 28))
	confirm_button.pressed.connect(func() -> void:
		if selected_element != "": awaken_requested.emit(selected_element))
	confirm_button.disabled = true

func _select_element(id: String) -> void:
	selected_element = id
	selection_label.text = "已选择：%s属性 · 再点击确认完成觉醒" % element_buttons[id].text
	confirm_button.text = "确认觉醒%s属性" % element_buttons[id].text
	for element: String in element_buttons:
		element_buttons[element].add_theme_stylebox_override("normal", _style(Color("897047") if element == id else Color("554735")))
	confirm_button.disabled = false

func _show_page(next: String) -> void:
	page = next
	level_root.visible = page == "level"
	tree_root.visible = page == "tree"
	achievement_root.visible=page=="achievements"
	achievement_tab.add_theme_stylebox_override("normal",_style(Color("897047") if page=="achievements" else Color("554735")))
	level_tab.add_theme_stylebox_override("normal", _style(Color("897047") if page == "level" else Color("554735")))
	tree_tab.add_theme_stylebox_override("normal", _style(Color("897047") if page == "tree" else Color("554735")))
	if is_instance_valid(picker_root): picker_root.visible = false

func _present(state: Dictionary) -> void:
	var next: Dictionary = state.get("attributes", {"open": false})
	var opening: bool = next.get("open", false) and (not attributes_root.visible or current.get("id", "") != next.get("id", ""))
	attributes_root.visible = next.get("open", false)
	current = next
	if opening:
		_show_page("level")
		branch_page=""
		branch_panel.visible=false
	if not attributes_root.visible: picker_root.visible = false
	if attributes_root.visible:
		title.text = str(current.name) + " · 属性" + ("（已阵亡）" if current.dead else "")
		if opening:
			var texture := AtlasTexture.new()
			texture.atlas = current.sheet
			texture.region = Rect2(0, 0, 16, 16)
			portrait.texture = texture
		element_label.text = "未觉醒" if current.element == "" else str(current.element_name) + "属性"
		element_label.add_theme_color_override("font_color", Color(str(current.color)))
		level_label.text = "魔法等级 lv.%d" % int(current.level)
		xp_bar.max_value = maxi(1, int(current.required))
		xp_bar.value = 1 if current.required == 0 else int(current.xp)
		xp_bar.add_theme_stylebox_override("fill", _style(Color(str(current.color))))
		xp_label.text = "未觉醒 · 已累计%d魔法点，觉醒后结算" % int(current.pending_points) if current.element=="" else ("lv.100 · 已达最高等级" if current.required==0 else "%d / %d 魔法点 · 升级获得5技能点" % [current.xp,current.required])
		var protection: Dictionary=current.get("protection",{})
		protection_label.text="防御 %d\n装备免伤 %d%%" % [int(protection.get("defense",0)),int(protection.get("armor_reduction_percent",0))]
		if protection.get("shield_active",false): protection_label.text+="\n总免伤 %s%%" % str(protection.get("reduction_percent",0)).trim_suffix(".0")
		crystal_button.text="领取晶石×%d" % int(current.get("crystal_pending",0)) if int(current.get("crystal_pending",0))>0 else "晶石：每5级获得"
		crystal_button.disabled=not current.editable or int(current.get("crystal_pending",0))<=0
		crystal_button.tooltip_text="魔法等级5／10／15…奖励已觉醒属性晶石；满包时保留待领。"
		_present_achievements(current.get("achievements",{}))
		awaken_button.disabled = not current.awakening_available
		awaken_button.text = "已觉醒" if current.element != "" else "在祭台觉醒 [R]"
		awaken_button.tooltip_text = str(current.awakening_hint)
		for gear: Dictionary in current.gear:
			var widgets: Dictionary = gear_buttons[gear.slot]
			widgets.icon.set_item(str(gear.item), bool(gear.get("magical", false)),str(gear.get("magic_attribute","")))
			widgets.hint.text = "空" if gear.item == "" else ("防御%d" % int(gear.defense) if int(gear.get("defense",0))>0 else "已穿戴")
			widgets.button.disabled = not current.editable
			widgets.button.tooltip_text = str(gear.equipped_name)+(" · "+str(gear.get("protection_description","")) if gear.item!="" else "")+" · 点击选择材质 / 穿戴 / 卸下"
		skill_points.text = "技能点：%d · 魔力：%d/%d" % [int(current.skill_points),int(current.mana),int(current.get("max_mana",10))]
		for i in range(skill_buttons.size()):
			var skill: Dictionary = current.skills[i]
			skill_buttons[i].text = "%d %s%s" % [i+1,skill.name," ✓" if skill.learned else " · 10点"]
			var prefix := "被动 · " if i==0 else ("[%s] %d魔力 · " % [skill.key,skill.mana_cost])
			skill_descriptions[i].text=prefix+str(skill.description)
			skill_buttons[i].tooltip_text=skill_descriptions[i].text
			skill_buttons[i].disabled = not skill.can_unlock
			skill_buttons[i].add_theme_stylebox_override("disabled", _style(Color("526449") if skill.learned else Color("41392d")))
			branches[mini(i, 2)].tooltip_text = "每分支三阶，等级12／20／30；选中已学习技能后按P施放。" if current.branches_ready else "依次点亮五个主干技能后开放。"
		if wires.learned != current.unlocked.size():
			wires.learned = current.unlocked.size()
			wires.queue_redraw()
		for branch: Button in branches:
			branch.disabled=not current.branches_ready
			branch.add_theme_stylebox_override("disabled", _style(Color("526449") if current.branches_ready else Color("41392d")))
		_present_branch()
		feedback.text = str(state.get("notice", ""))
		if picker_root.visible: _update_picker()
	var awakening: Dictionary = state.get("awakening", {})
	if awakening.get("open", false) and not awakening_root.visible:
		selected_element = ""
		selection_label.text = "请选择一种魔法属性"
		confirm_button.text = "确认觉醒"
		for button: Button in element_buttons.values(): button.add_theme_stylebox_override("normal", _style(Color("554735")))
	awakening_root.visible = awakening.get("open", false)
	if awakening_root.visible:
		awakening_title.text = str(awakening.get("name", "")) + " · 在祭台觉醒"
		awakening_feedback.text = str(state.get("notice", ""))
		confirm_button.disabled = selected_element == "" or not awakening.get("available", false)

func _open_picker(slot: String) -> void:
	selected_slot = slot
	gear_choice.clear()
	picker_root.visible = true
	_update_picker()

func _update_picker() -> void:
	for gear: Dictionary in current.get("gear", []):
		if gear.slot != selected_slot: continue
		picker_title.text = str(current.name) + " · " + str(gear.name)
		# Periodic snapshots must not rebuild or close a dropdown the player is navigating.
		var signature := JSON.stringify(gear.choices)
		if gear_choice.item_count == 0 or gear_choice.get_meta("choices_signature", "") != signature:
			gear_choice.clear()
			gear_choice.set_meta("choices_signature",signature)
			for option: Dictionary in gear.choices:
				gear_choice.add_item(str(option.name))
				gear_choice.set_item_metadata(gear_choice.item_count-1,option)
			var initial := 0
			for i in range(gear.choices.size()):
				if gear.choices[i].available and gear.choices[i].item!=gear.item: initial=i; break
			gear_choice.select(initial)
		for i in range(gear.choices.size()):
			var entry: Dictionary=gear.choices[i]
			var text := str(entry.name)+( "（背包没有）" if not entry.available else "")
			if gear_choice.get_item_text(i)!=text: gear_choice.set_item_text(i,text)
			if gear_choice.is_item_disabled(i)==bool(entry.available): gear_choice.set_item_disabled(i,not entry.available)
		var chosen := maxi(0,gear_choice.selected)
		var option: Dictionary=gear.choices[chosen]
		wear_button.text = "穿戴"+str(option.name) if option.available else "背包里没有可用的"+str(gear.name)
		wear_button.disabled = not current.editable or not option.available
		remove_button.disabled = not current.editable or gear.item == ""

func _unhandled_key_input(event: InputEvent) -> void:
	if picker_root.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_C]:
		picker_root.visible = false
		get_viewport().set_input_as_handled()

func _overlay() -> ColorRect:
	var overlay := ColorRect.new()
	overlay.size = Vector2(640, 400)
	overlay.color = Color(0.08, 0.07, 0.05, 0.88)
	add_child(overlay)
	return overlay

func _style(color: Color) -> StyleBoxFlat:
	var key := color.to_html()
	if styles.has(key): return styles[key]
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(1)
	style.border_color = Color("a48b60")
	styles[key] = style
	return style

func _panel(parent: Node, bounds: Rect2) -> void:
	var panel := Panel.new()
	panel.position = bounds.position
	panel.size = bounds.size
	panel.add_theme_stylebox_override("panel", _style(Color("3e3529")))
	parent.add_child(panel)

func _label(parent: Node, text: String, at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("efdcb3"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, bounds: Rect2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = bounds.position
	button.size = bounds.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color("f4e3bd"))
	button.add_theme_color_override("font_disabled_color", Color("bfb196"))
	button.add_theme_stylebox_override("normal", _style(Color("554735")))
	button.add_theme_stylebox_override("hover", _style(Color("85704d")))
	button.add_theme_stylebox_override("pressed", _style(Color("a18a5b")))
	parent.add_child(button)
	return button

func _build_achievements() -> void:
	achievement_root=Control.new()
	achievement_root.position=level_root.position
	attributes_root.add_child(achievement_root)
	_label(achievement_root,"成就 · 每首次获得一种物品奖励25魔法点",Vector2(8,6),13)
	achievement_text=RichTextLabel.new()
	achievement_text.position=Vector2(8,36)
	achievement_text.size=Vector2(480,174)
	achievement_text.add_theme_font_override("normal_font",font)
	achievement_text.add_theme_font_size_override("normal_font_size",12)
	achievement_root.add_child(achievement_text)
func _present_achievements(data: Dictionary) -> void:
	var rows: PackedStringArray=[]
	for entry: Dictionary in data.get("entries",[]):
		rows.append(("已完成 · " if entry.completed else "未完成 · ")+str(entry.name)+" · 25魔法点\n"+str(entry.description))
	var text := "首次获得每种物品即完成成就，奖励25魔法点，每名角色每项只奖励一次。\n击杀生物每只获得25魔法点，未觉醒时先累计。" if rows.is_empty() else "\n\n".join(rows)
	if achievement_text.text!=text: achievement_text.text=text

func _build_branch_panel() -> void:
	branch_panel=Control.new()
	branch_panel.position=Vector2.ZERO
	tree_root.add_child(branch_panel)
	var background := ColorRect.new()
	background.color=Color("3e3529"); background.size=Vector2(504,240)
	branch_panel.add_child(background)
	branch_title=_label(branch_panel,"",Vector2(0,3),12)
	var back := _button(branch_panel,"返回主干",Rect2(416,0,88,24))
	back.pressed.connect(func() -> void: branch_panel.visible=false; branch_page="")
	_label(branch_panel,"先学习，再选择；关闭属性页按P朝鼠标施放。",Vector2(0,24),10)
	for i in range(3):
		var y := 46+i*61
		var title_label := _label(branch_panel,"",Vector2(0,y),11)
		title_label.size=Vector2(360,17)
		var detail := _label(branch_panel,"",Vector2(0,y+18),10)
		detail.size=Vector2(363,42); detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var learn := _button(branch_panel,"学习",Rect2(378,y,60,24))
		var select := _button(branch_panel,"选择",Rect2(444,y,60,24))
		learn.pressed.connect(func() -> void:
			var id: String=str(learn.get_meta("skill",""))
			if id!="": unlock_requested.emit(id))
		select.pressed.connect(func() -> void:
			var id: String=str(select.get_meta("skill",""))
			if id!="": branch_selected.emit(id))
		branch_cards.append({"title":title_label,"detail":detail,"learn":learn,"select":select})
	branch_panel.visible=false
func _open_branch(branch: String) -> void:
	branch_page=branch; branch_panel.visible=true; _present_branch()
func _present_branch() -> void:
	if branch_page=="": return
	var entries: Array=[]
	for entry: Dictionary in current.get("branches",[]):
		if str(entry.branch)==branch_page: entries.append(entry)
	if entries.size()!=3: branch_panel.visible=false; return
	branch_title.text="%s系 · %s分支 · 技能点%d" % [current.element_name,entries[0].branch_name,current.skill_points]
	for i in range(3):
		var skill: Dictionary=entries[i]
		var widgets: Dictionary=branch_cards[i]
		widgets.title.text="%d阶 %s · Lv.%d · %d技能点 · %d魔力" % [skill.rank,skill.name,skill.level,skill.points,skill.mana_cost]
		widgets.detail.text=str(skill.description)
		widgets.learn.set_meta("skill",skill.id); widgets.select.set_meta("skill",skill.id)
		widgets.learn.disabled=not skill.can_unlock
		widgets.learn.text="已学" if skill.learned else "学习"
		widgets.learn.tooltip_text=str(skill.unlock_hint)
		widgets.select.disabled=not skill.can_select
		widgets.select.text="已选" if skill.selected else "选择"
		widgets.select.tooltip_text="冷却 %.1f秒 · [P]施放" % float(skill.cooldown_left)
