# Checks actual menu interaction, source-aware icon presentation and saved equipment with isolated player data.
extends Node

const Origin := preload("res://features/gifts/provenance.gd")
const Mapping := preload("res://features/gifts/mapping.gd")
const Icons := preload("res://features/interface/gift_icon_atlas.gd")
const ItemIcon := preload("res://features/interface/item_icon.gd")
var failures: Array[String] = []
var checks := 0
var menu: Node
var directory := ""
var capture := false

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	directory = OS.get_environment("AIU5_PROBE_DIRECTORY")
	assert(directory != "")
	OS.set_environment("AIU5_SAVES_DIR", directory + "/slots")
	OS.set_environment("AIU5_LEGACY_PATH", directory + "/absent.json")
	OS.set_environment("AIU5_LEGACY_PROFILE_PATH", directory + "/absent.cfg")
	capture = OS.get_environment("AIU5_CAPTURE") == "true"
	get_tree().create_timer(55, true).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func frames(n := 5) -> void:
	for i in range(n): await get_tree().process_frame

func button(text: String) -> Button:
	for control in menu.view.root.find_children("*", "Button", true, false):
		if control.text == text: return control
	return null

func click(control: Control) -> void:
	assert(is_instance_valid(control))
	await frames(2)
	var at := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await frames(2)

func screenshot(name: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(directory + "/" + name + ".png") == OK, "capture " + name)

func freeze(s: Node) -> void:
	s.simulation.set_process(false)
	for actor in s.world.residents: actor.set_physics_process(false)

func run() -> void:
	check(ProjectSettings.get_setting("application/config/version") == "0.7.8", "version")
	check(ProjectSettings.get_setting("application/config/name") == "沙盘上的生活", "application name")
	menu = load("res://scenes/start.tscn").instantiate()
	get_tree().root.add_child(menu)
	await frames()
	check(menu.view.screen == "home", "start screen")
	check(button("赐予详情") != null, "gift reference entry")
	check(button("赐予详情").get_global_rect().end.y < 400, "home button fits viewport")
	await screenshot("home")
	await click(button("赐予详情"))
	check(menu.view.screen == "gifts", "open reference by mouse")
	check(not is_instance_valid(menu.game) and menu.library.slots().is_empty(), "browsing does not launch game or create slot")
	var details: ScrollContainer = menu.view.root.find_child("GiftDetails", true, false)
	check(details != null and details.get_node("Cards").get_child_count() == 18, "all eighteen cards")
	for item: String in Mapping.ITEMS:
		check(details.get_node("Cards").has_node(item), "reference card " + item)
		var texture: AtlasTexture = Icons.texture(item)
		check(texture != null and texture.region.end.x <= texture.atlas.get_width() + 0.1 and texture.region.end.y <= texture.atlas.get_height() + 0.1, "atlas boundary " + item)
	check(menu.view.panel.get_global_rect().end.y <= 400, "reference page fits viewport")
	await screenshot("gift-details")
	details.scroll_vertical = 10000
	await frames()
	check(details.scroll_vertical > 0, "scroll reaches lower cards")
	check(details.get_global_rect().intersects(details.get_node("Cards/leather_boots").get_global_rect()), "boots visible after scrolling")
	await screenshot("gift-details-bottom")
	await click(button("返回开始界面  [Esc]"))
	check(menu.view.screen == "home", "return button")
	await click(button("赐予详情"))
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await frames(2)
	check(menu.view.screen == "home", "escape returns to home")
	var icon := ItemIcon.new()
	icon.size = Vector2(24, 24)
	add_child(icon)
	for item: String in Mapping.ITEMS:
		var record := {"item":item, "count":1}
		icon.set_record(record)
		check(not icon.magical and icon.gift_texture == null, "ordinary icon " + item)
		record.merge(Origin.gifted("probe:" + item))
		icon.set_record(record)
		check(icon.magical and icon.gift_texture != null, "gift icon " + item)
	icon.set_record({"item":"knife", "is_magical":true})
	check(not icon.magical, "unverified source does not change art")
	icon.set_record({"item":"water_cup", "is_magical":true, "gift_event_id":"cup:probe"})
	check(icon.gift_texture == Icons.texture("wooden_cup"), "filled cup keeps rune icon")
	icon.queue_free()
	menu.create_game("符文图标验证")
	await frames(25)
	var s: Node = menu.game.get_node("Session")
	freeze(s)
	s.inventory.bags.ali = s.inventory._sanitize_slots([])
	for item: String in ["wood_sword", "leather_armor", "wooden_cup"]:
		var record := {"item":item,"count":1}
		record.merge(Origin.gifted("probe:" + item))
		check(s.inventory.insert_record("ali", record), "insert " + item)
	check(s.inventory.insert_record("ali", {"item":"wood_sword","count":1}), "insert ordinary sword")
	s.inventory.open_bag("ali", "阿砾")
	s.refresh_interface()
	var belongings: Node = menu.game.get_node("Belongings")
	check(belongings.bag_buttons[0].get_node("Icon").magical, "gifted bag icon")
	check(not belongings.bag_buttons[3].get_node("Icon").magical, "ordinary same-item bag icon")
	await screenshot("inventory-runes")
	s.inventory.close()
	check(s.magic.equip_weapon("ali", "wood_sword", 0), "equip gifted weapon")
	check(s.magic.equip("ali", "armor", "leather_armor", 1), "wear gifted armor")
	s.refresh_interface()
	check(menu.game.get_node("HUD").weapon_icon.magical, "weapon hud rune")
	s.show_attributes("ali")
	check(menu.game.get_node("Attributes").gear_buttons.armor.icon.magical, "armor rune")
	s.close_roster()
	s.world.active_resident.position = s.world.point_info("altar").position
	check(s.homestead.fill_bucket(s.world.active_resident), "fill gifted cup")
	s.inventory.open_bag("ali", "阿砾")
	s.refresh_interface()
	check(belongings.bag_buttons[2].get_node("Icon").item == "water_cup" and belongings.bag_buttons[2].get_node("Icon").magical, "filled cup visible with provenance")
	s.inventory.close()
	var gift_view: Node = menu.game.get_node("GiftView")
	gift_view._present({"open":true,"mode":"camera","feedback":"测试候选","frozen":true,"selected":"one","device":"TEST","frame_jpeg":"","candidates":[{"id":"one","item":"book","name":"书本","confidence":0.9}]})
	check(gift_view.choices.get_child(0).icon == Icons.texture("book"), "camera candidate uses approved art")
	gift_view.overlay.visible = false
	check(s.persistence.save_now(), "save provenance")
	var slot: String = menu.active_slot.id
	await menu.return_home()
	menu.continue_game(slot)
	await frames(25)
	s = menu.game.get_node("Session")
	freeze(s)
	check(s.magic.weapon_snapshot("ali").magical, "weapon rune after reload")
	check(s.magic.snapshot("ali").gear.filter(func(g: Dictionary) -> bool: return g.slot == "armor")[0].magical, "armor rune after reload")
	check(Origin.magical(s.inventory.bags.ali[2]) and s.inventory.bags.ali[2].item == "water_cup", "cup rune after reload")
	check(s.magic.equip_weapon("ali", ""), "unequip gifted weapon")
	check(s.magic.equip_weapon("ali", "wood_sword", 3), "equip ordinary sword")
	s.refresh_interface()
	check(not menu.game.get_node("HUD").weapon_icon.magical, "same id switches back to normal art")
	if failures.is_empty(): print("GIFT_DETAILS_AND_RUNES_OK checks=", checks)
	get_tree().quit(0 if failures.is_empty() else 1)
