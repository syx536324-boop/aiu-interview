# Presents inventory slots and furniture controls; all mutations are requested through signals.
extends CanvasLayer

signal use_requested
signal gift_attribute_requested(element: String)
signal sacrifice_requested(target_id: String)
signal slot_requested(side: String, index: int, quick: bool)
signal inventory_close_requested
signal furniture_requested(kind: String)
signal editor_close_requested
signal editor_rotate_requested
signal editor_remove_requested
const Categories := preload("res://features/inventory/categories.gd")
const Gear := preload("res://features/combat/weapon_catalog.gd")
const Wear := preload("res://features/combat/durability.gd")
const Catalog := preload("res://features/inventory/catalog.gd")
const FurnitureCatalog := preload("res://features/interiors/furniture_catalog.gd")
const ItemIcon := preload("res://features/interface/item_icon.gd")
var font := SystemFont.new()
var inventory_root: ColorRect
var inventory_panel: Control
var bag_pane: Control
var storage_pane: Control
var bag_title: Label
var storage_title: Label
var selected_info: Label
var bag_buttons: Array[Button] = []
var storage_buttons: Array[Button] = []
var toolbar: HBoxContainer
var edit_info: Label
var use_button: Button
var close_button: Button
var rotate_button: Button
var remove_button: Button
var inventory_help: Label
var furniture_buttons: Dictionary = {}
var sacrifice_button: Button
var sacrifice_target: OptionButton
var target_ids: Array[String] = []
var category_filter: OptionButton
var filter_ids: Array[String] = []
var filter_id := "all"
var last_state: Dictionary = {}
var attribute_choice: OptionButton
var attribute_button: Button
const GIFT_ELEMENTS := ["wood","water","fire","earth"]

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	_build_inventory(overlay)
	toolbar = HBoxContainer.new()
	toolbar.position = Vector2(8, 62)
	toolbar.add_theme_constant_override("separation", 4)
	toolbar.visible = false
	overlay.add_child(toolbar)
	var select := _button(toolbar, "选取", 42)
	select.pressed.connect(func() -> void: furniture_requested.emit("select"))
	for id: String in FurnitureCatalog.TYPES:
		if id == "stove": continue
		var button := _button(toolbar, FurnitureCatalog.TYPES[id]["name"], 48)
		button.pressed.connect(func() -> void: furniture_requested.emit(id))
		furniture_buttons[id] = button
	rotate_button = _button(toolbar, "旋转 R", 58)
	rotate_button.pressed.connect(func() -> void: editor_rotate_requested.emit())
	remove_button = _button(toolbar, "回收 Del", 65)
	remove_button.pressed.connect(func() -> void: editor_remove_requested.emit())
	var done := _button(toolbar, "完成 F", 58)
	done.pressed.connect(func() -> void: editor_close_requested.emit())
	edit_info = _label(overlay, "", Vector2(24, 346), 11)
	edit_info.add_theme_color_override("font_outline_color", Color("31271d"))
	edit_info.add_theme_constant_override("outline_size", 4)
	edit_info.visible = false

func bind_session(session: Node) -> void:
	session.state_changed.connect(_present)
	_present(session.snapshot())

func _build_inventory(parent: Control) -> void:
	inventory_root = ColorRect.new()
	inventory_root.size = Vector2(640, 400)
	inventory_root.color = Color(0.08, 0.07, 0.05, 0.82)
	inventory_root.visible = false
	parent.add_child(inventory_root)
	inventory_panel = Panel.new()
	inventory_panel.add_theme_stylebox_override("panel", _style(Color("3e3529"), Color("a48b60")))
	inventory_root.add_child(inventory_panel)
	_label(inventory_panel, "物品栏", Vector2(16, 12), 16)
	category_filter = OptionButton.new()
	category_filter.position = Vector2(92,8)
	category_filter.size = Vector2(110,28)
	category_filter.add_theme_font_override("font",font)
	category_filter.add_theme_font_size_override("font_size",11)
	category_filter.get_popup().add_theme_font_override("font",font)
	category_filter.get_popup().add_theme_font_size_override("font_size",11)
	category_filter.focus_mode = Control.FOCUS_NONE
	for id: String in Categories.LABELS:
		if id == "animal": continue
		filter_ids.append(id)
		category_filter.add_item(Categories.LABELS[id])
	category_filter.item_selected.connect(func(index: int) -> void:
		filter_id = filter_ids[index]
		if not last_state.is_empty(): _present(last_state))
	inventory_panel.add_child(category_filter)
	bag_pane = Control.new()
	storage_pane = Control.new()
	inventory_panel.add_child(bag_pane)
	inventory_panel.add_child(storage_pane)
	bag_title = _label(bag_pane, "", Vector2.ZERO, 12)
	storage_title = _label(storage_pane, "", Vector2.ZERO, 12)
	_build_slots(bag_pane, "bag", bag_buttons)
	_build_slots(storage_pane, "storage", storage_buttons)
	inventory_help = _label(inventory_panel, "", Vector2(16, 222), 10)
	selected_info = _label(inventory_panel, "", Vector2(16, 242), 10)
	selected_info.size.x = 480
	selected_info.clip_text = true
	use_button = _button(inventory_panel, "使用 / 食用 / 部署", 160)
	use_button.position = Vector2(16, 264)
	use_button.pressed.connect(func() -> void: use_requested.emit())
	attribute_choice = OptionButton.new()
	attribute_choice.position = Vector2(184,264)
	attribute_choice.size = Vector2(60,28)
	attribute_choice.focus_mode = Control.FOCUS_NONE
	attribute_choice.add_theme_font_override("font",font)
	attribute_choice.add_theme_font_size_override("font_size",11)
	attribute_choice.get_popup().add_theme_font_override("font",font)
	for name in ["木","水","火","土"]: attribute_choice.add_item(name)
	inventory_panel.add_child(attribute_choice)
	attribute_button = _button(inventory_panel,"赋属性",68)
	attribute_button.position = Vector2(248,264)
	attribute_button.pressed.connect(func() -> void: gift_attribute_requested.emit(GIFT_ELEMENTS[attribute_choice.selected]))
	sacrifice_target = OptionButton.new()
	sacrifice_target.position = Vector2(188, 264)
	sacrifice_target.size = Vector2(244, 28)
	sacrifice_target.add_theme_font_override("font", font)
	sacrifice_target.add_theme_font_size_override("font_size", 11)
	sacrifice_target.focus_mode = Control.FOCUS_NONE
	sacrifice_target.add_theme_color_override("font_color", Color("f4e3bd"))
	sacrifice_target.add_theme_stylebox_override("normal", _style(Color("554735"), Color("9a845e")))
	sacrifice_target.add_theme_stylebox_override("hover", _style(Color("85704d"), Color("d1b780")))
	sacrifice_target.get_popup().add_theme_font_override("font", font)
	sacrifice_target.get_popup().add_theme_font_size_override("font_size", 11)
	inventory_panel.add_child(sacrifice_target)
	sacrifice_button = _button(inventory_panel, "献祭 1 个 · 复活", 152)
	sacrifice_button.position = Vector2(448, 264)
	sacrifice_button.pressed.connect(func() -> void:
		var index := sacrifice_target.selected
		if index >= 0 and index < target_ids.size(): sacrifice_requested.emit(target_ids[index]))
	sacrifice_button.tooltip_text = "消耗右侧选中的祭品1个；所选角色在祭台前复活，五项状态恢复10并清除疾病。"
	close_button = _button(inventory_panel, "关闭 B / Esc", 96)
	close_button.pressed.connect(func() -> void: inventory_close_requested.emit())

func _build_slots(parent: Control, side: String, buttons: Array[Button]) -> void:
	for i in range(21):
		var button := _button(parent, "", 38)
		button.position = Vector2((i % 7) * 40, 25 + (i / 7) * 54)
		button.size = Vector2(38, 50)
		button.pressed.connect(func() -> void: slot_requested.emit(side, int(button.get_meta("slot_index",i)), Input.is_key_pressed(KEY_SHIFT)))
		var icon := ItemIcon.new()
		icon.name = "Icon"
		icon.position = Vector2(7, 3)
		icon.size = Vector2(24, 24)
		button.add_child(icon)
		var label := _label(button, "", Vector2(1, 30), 10)
		label.name = "ItemName"
		label.size = Vector2(36, 14)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var count := _label(button, "", Vector2(23, 15), 9)
		count.name = "Count"
		count.size.x = 14
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_color_override("font_outline_color", Color("30251a"))
		count.add_theme_constant_override("outline_size", 2)
		buttons.append(button)

func _present(state: Dictionary) -> void:
	last_state = state
	var items: Dictionary = state["inventory"]
	var editing: Dictionary = state["furnishing"]
	inventory_root.visible = items["open"]
	toolbar.visible = editing["open"]
	for id: String in furniture_buttons:
		furniture_buttons[id].visible = id=="campfire" if editing.get("mine",false) else ((id!="building_bench" and not editing.get("outdoors",false)) or (editing.get("outdoors",false) and id in ["campfire","workbench","fence","building_bench"]))
	edit_info.visible = editing["open"]
	edit_info.text = editing["hint"]
	rotate_button.disabled = not editing["holding"]
	remove_button.disabled = not editing["existing"]
	if not items["open"]:
		return
	var storing: bool = items["container_id"] != ""
	var altar: bool = items["container_id"] == "altar:display"
	_present_offering(state.get("offering", {}), altar)
	inventory_panel.position = Vector2(12, 58) if storing else Vector2(156, 58)
	inventory_panel.size = Vector2(616 if storing else 328, 304)
	bag_pane.position = Vector2(16 if storing else 24, 40)
	storage_pane.position = Vector2(322, 40)
	storage_pane.visible = storing
	bag_title.text = items["actor"] + " · 背包（21 格）"
	storage_title.text = items["container_name"] + "（21 格）"
	_update_slots(bag_buttons, items["bag"], "bag", items["selection"])
	if storing:
		_update_slots(storage_buttons, items["storage"], "storage", items["selection"])
	inventory_help.text = "点击选中 → 点击目标格；Shift + 单击快速存取" if storing else "选中物品可食用 / 部署；点击目标格整理。"
	if altar: inventory_help.text = "Shift+单击存取；选中右侧祭品 → 下方选择阵亡角色 → 献祭1个物品复活。"
	close_button.position = Vector2(504 if storing else 216, 8)
	selected_info.size.x = 580 if storing else 296
	selected_info.text = "柜子、箱子中的物品可由所有可操控角色取用。" if storing else "靠近屋内的柜子或箱子按 E 打开储物格。"
	var selected: Dictionary = items["selection"]
	use_button.text = "使用 / 食用 / 部署"
	use_button.disabled = selected.get("side", "") != "bag"
	attribute_choice.visible = false
	attribute_button.visible = false
	if not selected.is_empty():
		var slots: Array = items["bag"] if selected["side"] == "bag" else items["storage"]
		var slot: Dictionary = slots[selected["index"]]
		if not slot.is_empty():
			selected_info.text = Catalog.ITEMS[slot["item"]]["description"]+Wear.Origin.describe(slot)
			use_button.text = Catalog.ITEMS[slot["item"]].get("use_label", "使用 / 食用 / 部署")
			if selected.get("side","")=="bag" and Wear.Origin.magical(slot) and not altar:
				attribute_choice.visible = true
				attribute_button.visible = true
				attribute_choice.disabled = not state.get("gift_attributes_available",false)
				attribute_button.disabled = attribute_choice.disabled
				attribute_button.tooltip_text = "20级后可选择木、水、火、土属性；与武器赋能技能独立。" if attribute_button.disabled else "给选中的赐予物品设置魔法属性。"
	if items["status"] != "":
		selected_info.text = items["status"]

func _present_offering(offering: Dictionary, altar: bool) -> void:
	sacrifice_button.visible = altar
	sacrifice_target.visible = altar
	if not altar: return
	var targets: Array = offering.get("targets", [])
	var ids: Array[String] = []
	for target: Dictionary in targets: ids.append(str(target.id))
	var previous := target_ids[sacrifice_target.selected] if sacrifice_target.selected >= 0 and sacrifice_target.selected < target_ids.size() else ""
	if ids != target_ids:
		target_ids = ids
		sacrifice_target.clear()
		for target: Dictionary in targets: sacrifice_target.add_item("复活：" + str(target.name))
		if target_ids.is_empty(): sacrifice_target.add_item("没有阵亡角色")
		elif target_ids.has(previous): sacrifice_target.select(target_ids.find(previous))
	# Also populate the initial empty state and refresh renamed target labels.
	if sacrifice_target.item_count == 0: sacrifice_target.add_item("没有阵亡角色")
	for i in range(targets.size()): sacrifice_target.set_item_text(i, "复活：" + str(targets[i].name))
	sacrifice_target.disabled = target_ids.is_empty()
	sacrifice_button.disabled = not bool(offering.get("ready", false))

func _update_slots(buttons: Array[Button], slots: Array, side: String, selected: Dictionary) -> void:
	var indices := Categories.indices(slots,filter_id)
	for i in range(buttons.size()):
		var button := buttons[i]
		button.visible = i < indices.size()
		if not button.visible: continue
		var index: int = indices[i]
		button.set_meta("slot_index",index)
		var slot: Dictionary = slots[index]
		var id := str(slot.get("item", ""))
		button.get_node("Icon").set_record(slot)
		button.get_node("ItemName").text = Catalog.ITEMS[id]["name"] if id != "" else ""
		button.get_node("ItemName").add_theme_font_size_override("font_size", 9 if id != "" and str(Catalog.ITEMS[id].name).length() >= 4 else 10)
		button.get_node("Count").text = str(slot["count"]) if id != "" and slot["count"] > 1 else ""
		button.tooltip_text = Catalog.ITEMS[id]["name"] + "\n" + Catalog.ITEMS[id]["description"] if id != "" else "空格 · %d / 21" % (index + 1)
		if id != "": button.tooltip_text += Wear.Origin.describe(slot)
		if Wear.Origin.magical(slot): button.get_node("ItemName").text = "✦" + button.get_node("ItemName").text
		if id != "": button.tooltip_text = "【"+Categories.label(id)+"】"+button.tooltip_text
		if id in Gear.WEAPONS: button.tooltip_text += "\n" + Wear.describe(slot)
		if id=="torch": button.tooltip_text += "\n" + preload("res://features/lighting/torch_record.gd").describe(slot)
		var active: bool = selected.get("side", "") == side and selected.get("index", -1) == index
		button.add_theme_stylebox_override("normal", _style(Color("7d7046") if active else Color("504331"), Color("e2cb82") if active else Color("806b49")))

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

func _button(parent: Node, text: String, width: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(width, 28)
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color("f4e3bd"))
	button.add_theme_stylebox_override("normal", _style(Color("554735"), Color("9a845e")))
	button.add_theme_stylebox_override("hover", _style(Color("85704d"), Color("d1b780")))
	button.add_theme_stylebox_override("pressed", _style(Color("a18a5b"), Color("ead39e")))
	parent.add_child(button)
	return button

func _style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(1)
	style.border_color = border
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style
