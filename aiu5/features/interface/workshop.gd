# Presents categorized recipes, ingredient requirements and a separate confirmation action.
extends CanvasLayer
signal close_requested
signal recipe_requested(id: String)
const Categories := preload("res://features/inventory/categories.gd")
var root: ColorRect
var title: Label
var status: Label
var details: Label
var job_label: Label
var progress: ProgressBar
var confirm_button: Button
var tabs: HBoxContainer
var tab_buttons: Dictionary = {}
var buttons: Array[Button] = []
var list: VBoxContainer
var font: SystemFont
var current: Dictionary = {}
var selected_id := ""
var category := "all"
var context_id := ""
func _ready() -> void:
	layer = 4
	root = ColorRect.new()
	root.size = Vector2(640,400)
	root.color = Color(0.12,0.10,0.07,0.97)
	add_child(root)
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	title = _label(Vector2(32,22),Vector2(576,28),18)
	tabs = HBoxContainer.new()
	tabs.position = Vector2(32,62)
	tabs.add_theme_constant_override("separation",6)
	root.add_child(tabs)
	for id: String in Categories.LABELS:
		var b := _button(tabs,Categories.LABELS[id],Vector2(52,28))
		b.pressed.connect(func() -> void: category=id; selected_id=""; _render())
		tab_buttons[id] = b
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(32,104)
	scroll.size = Vector2(230,208)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",5)
	scroll.add_child(list)
	details = _label(Vector2(286,104),Vector2(322,170),12)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	job_label = _label(Vector2(286,277),Vector2(322,31),11)
	progress = ProgressBar.new()
	progress.position = Vector2(286,310)
	progress.size = Vector2(322,10)
	progress.max_value = 60
	progress.show_percentage = false
	root.add_child(progress)
	status = _label(Vector2(32,325),Vector2(576,18),10)
	status.clip_text = true
	var close := _button(root,"返回 [Esc / T]",Vector2(164,32))
	close.position = Vector2(32,351)
	close.pressed.connect(func() -> void: close_requested.emit())
	confirm_button = _button(root,"确认合成",Vector2(168,32))
	confirm_button.position = Vector2(440,351)
	confirm_button.pressed.connect(func() -> void:
		var r := selected_recipe()
		if not r.is_empty() and bool(r.get("enabled",false)): recipe_requested.emit(selected_id))
	root.visible = false
func _label(at: Vector2, dimensions: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("f4e3bd"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return label
func _button(parent: Node, text: String, dimensions: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = dimensions
	b.add_theme_font_override("font",font)
	b.add_theme_font_size_override("font_size",12)
	b.focus_mode = Control.FOCUS_NONE
	_skin(b)
	parent.add_child(b)
	return b
func _ensure_buttons(count: int) -> void:
	for i in range(buttons.size(),count):
		var b := _button(list,"",Vector2(214,34))
		b.pressed.connect(func() -> void:
			selected_id = str(b.get_meta("recipe_id",""))
			_render())
		buttons.append(b)
func _skin(button: Button, active := false) -> void:
	if button.has_meta("skin_active") and bool(button.get_meta("skin_active"))==active: return
	button.set_meta("skin_active",active)
	for key: String in {"normal":"554735","hover":"85704d","pressed":"a18a5b","disabled":"3f372c"}:
		var style := StyleBoxFlat.new()
		style.bg_color = Color({"normal":"776342" if active else "554735","hover":"85704d","pressed":"a18a5b","disabled":"3f372c"}[key])
		style.border_color = Color("e5ca89" if active else "a48b60")
		style.set_border_width_all(1)
		button.add_theme_stylebox_override(key,style)
	button.add_theme_color_override("font_color",Color("f4e3bd"))
	button.add_theme_color_override("font_disabled_color",Color("bfb196"))
func bind_session(session: Node) -> void:
	session.state_changed.connect(_present)
	_present(session.snapshot())
func _present(state: Dictionary) -> void:
	current = state.get("workshop",{"open":false})
	root.visible = current.open
	if not root.visible:
		context_id = ""
		return
	var key := str(current.get("station",""))+":"+str(current.get("mode",""))
	if key != context_id:
		context_id = key
		category = "all"
		selected_id = ""
	title.text = current.title
	status.text = str(state.get("notice",""))
	_render()
func selected_recipe() -> Dictionary:
	for recipe: Dictionary in current.get("recipes",[]):
		if str(recipe.id)==selected_id: return recipe
	return {}
func _render() -> void:
	var visible_recipes: Array = []
	var groups: Array = ["all"]
	for r: Dictionary in current.get("recipes",[]):
		var group := str(r.get("category","all"))
		if group not in groups: groups.append(group)
		if category == "all" or group == category or r.id == "craft:collect": visible_recipes.append(r)
	for id: String in tab_buttons:
		tab_buttons[id].visible = id in groups
		if tab_buttons[id].visible: _skin(tab_buttons[id],id==category)
	var ids := visible_recipes.map(func(r: Dictionary) -> String: return str(r.id))
	if selected_id not in ids: selected_id = str(visible_recipes[0].id) if not visible_recipes.is_empty() else ""
	_ensure_buttons(visible_recipes.size())
	for i in range(buttons.size()):
		var b := buttons[i]
		b.visible = i < visible_recipes.size()
		if not b.visible: continue
		var r: Dictionary = visible_recipes[i]
		b.text = str(r.name)
		b.tooltip_text = str(r.detail)
		b.set_meta("recipe_id",str(r.id))
		b.disabled = false
		_skin(b,str(r.id)==selected_id)
	var selected := selected_recipe()
	confirm_button.disabled = selected.is_empty() or not bool(selected.get("enabled",false))
	confirm_button.text = "确认合成" if selected.has("duration") else ("领取成品" if selected_id=="craft:collect" else "确认操作")
	details.text = "选择左侧物品查看材料。"
	if not selected.is_empty():
		details.text = "【%s】%s\n\n" % [Categories.LABELS.get(selected.get("category","all"),"全部"),selected.name]
		if selected.has("ingredients"):
			details.text += "合成材料（需要 / 拥有）：\n"
			for item: Dictionary in selected.ingredients:
				details.text += "%s ×%d / %d%s\n" % [item.name,item.need,item.have,"  缺少" if int(item.have)<int(item.need) else ""]
			details.text += "\n制作时间：60秒在线时间"
		else: details.text += str(selected.detail)
	var job: Dictionary = current.get("job",{})
	progress.visible = not job.is_empty()
	if job.is_empty(): job_label.text = "确认后扣除材料；完成后放入制作角色背包。"
	else:
		var remaining := float(job.remaining)
		progress.value = 60.0-remaining
		job_label.text = "%s · 剩余%.1f秒" % [job.name,remaining] if remaining>0 else "%s · 成品待领（不再扣材料）" % job.name
