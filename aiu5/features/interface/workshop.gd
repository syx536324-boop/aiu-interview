# Presents recipe requirements and bench management actions through backend snapshots.
extends CanvasLayer
const TouchScroll := preload("res://features/interface/touch_scroll.gd")
const InputHints := preload("res://features/interface/input_hints.gd")
signal close_requested
signal recipe_requested(id: String)
const Categories := preload("res://features/inventory/categories.gd")
var root: ColorRect
var title: Label
var status: Label
var details: Label
var detail_scroll: ScrollContainer
var detail_recipe := ""
var job_label: Label
var list_gesture: Node
var detail_gesture: Node
var job_labels: Array[Label]=[]
var job_bars: Array[ProgressBar]=[]
var progress: ProgressBar
var confirm_button: Button
var move_button: Button
var recover_button: Button
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
	list_gesture=TouchScroll.attach(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",5)
	scroll.add_child(list)
	details = _label(Vector2(286,104),Vector2(322,140),12)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_scroll = ScrollContainer.new()
	detail_scroll.position = Vector2(286,104); detail_scroll.size = Vector2(322,140)
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(detail_scroll); details.reparent(detail_scroll)
	detail_gesture=TouchScroll.attach(detail_scroll)
	details.position = Vector2.ZERO; details.size = Vector2(302,0)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(3):
		var text:=_label(Vector2(286,248+i*24),Vector2(322,17),10)
		text.clip_text=true; job_labels.append(text)
		var bar:=ProgressBar.new()
		var track:=StyleBoxFlat.new();track.bg_color=Color("433828")
		var fill:=StyleBoxFlat.new();fill.bg_color=Color("b9985e")
		bar.add_theme_stylebox_override("background",track);bar.add_theme_stylebox_override("fill",fill)
		bar.show_percentage=false;bar.position=Vector2(286,265+i*24);bar.size=Vector2(322,5)
		bar.show_percentage=false;root.add_child(bar);job_bars.append(bar)
	job_label=job_labels[0];progress=job_bars[0]
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
	move_button = _button(root,"移动",Vector2(110,32))
	move_button.position = Vector2(208,351)
	move_button.pressed.connect(func() -> void: recipe_requested.emit("fixture:move"))
	recover_button = _button(root,"回收",Vector2(110,32))
	recover_button.position = Vector2(326,351)
	recover_button.pressed.connect(func() -> void: recipe_requested.emit("fixture:recover"))
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
			if list_gesture.blocks_click():return
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
	for button: Button in [move_button,recover_button]:
		var selected_action: Dictionary = {}
		var id := "fixture:move" if button == move_button else "fixture:recover"
		for action: Dictionary in current.get("fixture_actions",[]):
			if action.id == id: selected_action = action; break
		button.visible = not selected_action.is_empty()
		if selected_action.is_empty(): continue
		button.text = selected_action.name
		button.disabled = not bool(selected_action.enabled); button.tooltip_text = selected_action.detail
	var visible_recipes: Array = []
	var groups: Array = ["all"]
	for r: Dictionary in current.get("recipes",[]):
		var group := str(r.get("category","all"))
		if group not in groups: groups.append(group)
		if category == "all" or group == category or str(r.id).begins_with("craft:collect") or r.id=="bench:upgrade": visible_recipes.append(r)
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
	confirm_button.text = "确认升级" if selected_id=="bench:upgrade" or current.get("mode","")=="upgrade" else ("领取成品" if selected_id.begins_with("craft:collect") else ("确认合成" if selected.has("duration") else "确认操作"))
	details.text = "选择左侧物品查看材料。"
	if not selected.is_empty():
		details.text = "【%s】%s\n\n" % [Categories.LABELS.get(selected.get("category","all"),"全部"),selected.name]
		if str(selected.get("usage","")) != "": details.text += "用途：" + str(selected.usage) + "\n\n"
		if selected.has("ingredients"):
			details.text += ("升级材料（需要 / 拥有）：\n" if current.get("mode","")=="upgrade" or selected_id=="bench:upgrade" else "合成材料（需要 / 拥有）：\n")
			for item: Dictionary in selected.ingredients:
				details.text += "%s ×%d / %d%s\n" % [item.name,item.need,item.have,"  缺少" if int(item.have)<int(item.need) else ""]
			if bool(selected.get("immediate",false)): details.text+="\n确认后立即升级。"
			else: details.text += "\n%s时间：%.1f秒在线时间" % ["升级" if current.get("mode","")=="upgrade" else "制作",float(selected.get("duration",60))]
			if current.get("mode","")=="upgrade": details.text+="\n材料逐级＋15% · 升级耗时逐级＋30%"
		else: details.text += str(selected.detail)
	details.text = InputHints.text(details.text)
	status.text = InputHints.text(status.text)
	if detail_recipe != selected_id:
		detail_recipe = selected_id; detail_scroll.scroll_vertical = 0
	var jobs: Array=current.get("jobs",[])
	if jobs.is_empty() and not current.get("job",{}).is_empty():jobs=[current.job]
	for i in range(3):
		job_labels[i].visible=i<jobs.size() or i==0
		job_bars[i].visible=i<jobs.size()
		if i>=jobs.size():
			job_labels[i].text=("确认后扣料，立即升级工作台。" if selected_id=="bench:upgrade" else "确认后扣料，完成后交给制作角色。") if i==0 else ""
			continue
		var job: Dictionary=jobs[i]
		var remaining: float=float(job.remaining)
		job_bars[i].max_value=float(job.get("duration",60));job_bars[i].value=job_bars[i].max_value-remaining
		job_labels[i].text="%d. %s · 剩余%.1f秒" % [i+1,job.name,remaining] if remaining>0 else "%d. %s · 成品待领" % [i+1,job.name]
