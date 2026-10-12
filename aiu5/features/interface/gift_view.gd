# Presents altar rituals, in-memory camera previews and candidate selection through backend actions.
extends CanvasLayer
const GiftIcons := preload("res://features/interface/gift_icon_atlas.gd")
var font := SystemFont.new()
var overlay: ColorRect
var altar_panel: Control
var camera_panel: Control
var feedback: Label
var title: Label
var preview: TextureRect
var choices: VBoxContainer
var freeze_button: Button
var confirm_button: Button
var camera_info: Label
var gifts: Node
var cached_jpeg := ""
var cached_choices := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 8
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	overlay = ColorRect.new()
	overlay.color = Color(0.05,0.05,0.04,0.94)
	overlay.size = Vector2(640,400)
	add_child(overlay)
	var panel := Panel.new()
	panel.position = Vector2(16,28)
	panel.size = Vector2(608,350)
	panel.add_theme_stylebox_override("panel",_style(Color("342e27")))
	overlay.add_child(panel)
	title = _label(overlay,"祭台仪式",Rect2(32,40,568,28),18)
	altar_panel = Control.new()
	overlay.add_child(altar_panel)
	_label(altar_panel,"赐予时开启摄像头；选择并确认后获得一件魔法物品。",Rect2(64,86,512,30),13)
	_button(altar_panel,"保存祭台存档",Rect2(160,134,320,38)).pressed.connect(func() -> void: gifts.save_altar())
	_button(altar_panel,"魔法觉醒",Rect2(160,184,320,38)).pressed.connect(func() -> void: gifts.awaken())
	_button(altar_panel,"赐予 · 打开摄像头",Rect2(160,234,320,38)).pressed.connect(func() -> void: gifts.begin_camera())
	_button(altar_panel,"返回游戏  [Esc]",Rect2(160,326,320,32)).pressed.connect(func() -> void: gifts.close())
	camera_panel = Control.new()
	overlay.add_child(camera_panel)
	var background := ColorRect.new()
	background.position = Vector2(32,84)
	background.size = Vector2(328,208)
	background.color = Color("171a18")
	camera_panel.add_child(background)
	preview = TextureRect.new()
	preview.position = background.position
	preview.size = background.size
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	camera_panel.add_child(preview)
	camera_info = _label(camera_panel,"摄像头启动中…",Rect2(32,70,328,14),10)
	_label(camera_panel,"识别候选",Rect2(376,76,220,24),13)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(376,108)
	scroll.size = Vector2(220,184)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	camera_panel.add_child(scroll)
	choices = VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation",5)
	scroll.add_child(choices)
	freeze_button = _button(camera_panel,"定格选择",Rect2(32,334,160,28))
	freeze_button.pressed.connect(func() -> void: gifts.freeze_frame())
	confirm_button = _button(camera_panel,"确认赐予 1 件",Rect2(208,334,208,28))
	confirm_button.pressed.connect(func() -> void: gifts.confirm())
	_button(camera_panel,"关闭  [Esc]",Rect2(432,334,164,28)).pressed.connect(func() -> void: gifts.close())
	feedback = _label(overlay,"",Rect2(32,296,564,32),11)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay.visible = false

func bind_gifts(backend: Node) -> void:
	gifts = backend
	gifts.changed.connect(_present)
	_present(gifts.snapshot())

func _present(state: Dictionary) -> void:
	overlay.visible = bool(state.open)
	if not state.open:
		preview.texture = null
		cached_jpeg = ""
		cached_choices = ""
		return
	var camera: bool = state.mode == "camera"
	altar_panel.visible = not camera
	camera_panel.visible = camera
	title.text = "祭台赐予 · 首版模型" if camera else "祭台仪式"
	feedback.text = str(state.feedback)
	if not camera: return
	camera_info.text = "已定格 · 世界暂停" if state.frozen else "实时预览 · 世界暂停 · " + str(state.device)
	freeze_button.text = "继续识别" if state.frozen else "定格选择"
	confirm_button.disabled = not state.frozen or str(state.selected) == ""
	var jpeg := str(state.frame_jpeg)
	if jpeg != cached_jpeg:
		cached_jpeg = jpeg
		if jpeg == "": preview.texture = null
		else:
			var picture := Image.new()
			if picture.load_jpg_from_buffer(Marshalls.base64_to_raw(jpeg)) == OK: preview.texture = ImageTexture.create_from_image(picture)
	var signature := JSON.stringify([state.candidates,state.frozen,state.selected])
	if signature == cached_choices: return
	cached_choices = signature
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	if state.candidates.is_empty():
		_label(choices,"尚无稳定候选",Rect2(0,0,200,24),11)
	for candidate: Dictionary in state.candidates:
		var button := Button.new()
		button.text = ("✓ " if str(state.selected) == str(candidate.id) else "") + "%s  %d%%" % [candidate.name,roundi(float(candidate.confidence)*100)]
		_style_button(button)
		button.custom_minimum_size = Vector2(204,38)
		button.icon = GiftIcons.texture(str(candidate.item))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 30)
		button.add_theme_constant_override("h_separation", 6)
		button.disabled = not state.frozen
		button.pressed.connect(func() -> void: gifts.select_candidate(str(candidate.id)))
		choices.add_child(button)

func _label(parent: Node, text: String, bounds: Rect2, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = bounds.position
	label.size = bounds.size
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("efdcb3"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, bounds: Rect2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = bounds.position
	button.size = bounds.size
	_style_button(button)
	parent.add_child(button)
	return button

func _style_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font",font)
	button.add_theme_font_size_override("font_size",12)
	button.add_theme_color_override("font_color",Color("efdcb3"))
	button.add_theme_stylebox_override("normal",_style(Color("5c4e37")))
	button.add_theme_stylebox_override("hover",_style(Color("806d47")))
	button.add_theme_stylebox_override("disabled",_style(Color("39362e")))

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("ac9166")
	style.set_border_width_all(1)
	return style
