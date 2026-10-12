# Exercises exclusive awakening, every level boundary, skill prerequisites, equipment and durable rollback.
extends SceneTree

const Rules := preload("res://features/magic/catalog.gd")
var failures: Array[String] = []
var game: Node
var session: Node
var world: Node2D
var items: Node
var magic: Node
var ui: Node
var path := ""

func _initialize() -> void:
	path = "res://.runtime/magic-" + str(Time.get_ticks_usec()) + "/state.json"
	OS.set_environment("AIU5_STATE_PATH", path)
	OS.set_environment("AIU5_PROFILE_PATH", path + ".names")
	OS.set_environment("AIU5_WORLD_PROFILE", "starter")
	create_timer(60, true).timeout.connect(func() -> void: push_error("MAGIC_TIMEOUT"); quit(2))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error("CHECK FAILED: " + label)

func frames(count := 2) -> void:
	for i in range(count): await process_frame

func key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames()

func click(control: Control) -> void:
	await frames()
	var at := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames()

func load_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	session = game.get_node("Session")
	world = game.get_node("World")
	items = game.get_node("Inventory")
	magic = game.get_node("Magic")
	ui = game.get_node("Attributes")
	session.simulation.set_process(false)
	session.simulation.reset()
	session.persistence.set_process(false)
	for actor in world.residents: actor.set_physics_process(false)
	for animal in session.livestock.animals: animal.set_physics_process(false)
	await frames()

func run() -> void:
	# Verify all 99 costs independently, including 9->10 / 10->11 and the level cap.
	var progress := Rules.fresh()
	progress.element = "wood"
	var total := 0
	for level in range(1, 100):
		var expected: int = 100 * (level / 10 + 1)
		check(Rules.required(level) == expected, "ten-level band cost at level %d" % level)
		Rules.add_points(progress, expected - 1)
		check(progress.level == level and progress.xp == expected - 1, "no premature level at %d" % level)
		Rules.add_points(progress, 1)
		total += expected
		check(progress.level == level + 1 and progress.xp == 0 and progress.skill_points == level * 5, "exact threshold awards five points at %d" % level)
	check(total == 54900 and progress.level == 100 and progress.skill_points == 495 and Rules.required(100) == 0, "99 upgrades total 54900 magic and 495 skill points")
	Rules.add_points(progress, 100000)
	check(progress.level == 100 and progress.xp == 0 and progress.skill_points == 495, "overflow at cap never generates more skill points")
	await load_game()
	check(magic.ensure("ali").element == "" and magic.ensure("heya").element == "", "new/legacy residents start unawakened with independent states")
	# First-item discoveries are settled on save as well, so measure the earned delta, not a fixed total.
	var pending_before: int = magic.ensure("ali").pending_points
	check(magic.award_points("ali", 25) and magic.ensure("ali").pending_points==pending_before+25, "unawakened residents retain earned magic points")
	await key(KEY_R)
	check(not session.awakening_open, "R away from altar cannot open awakening")
	world.active_resident.position = Vector2(548, 332)
	session._sync_view()
	await key(KEY_E)
	check(session.gifts.opened and not session.awakening_open, "E opens altar ritual choices")
	session.gifts.save_altar()
	check(not session.persistence.checkpoint.is_empty(), "altar menu saves checkpoint")
	session.gifts.close()
	await key(KEY_R)
	check(session.awakening_open and ui.awakening_root.visible and ui.element_buttons.size() == 4 and ui.confirm_button.disabled, "R at altar opens four-element choice with explicit confirmation")
	await click(ui.element_buttons.wood)
	check(magic.ensure("ali").element == "" and not ui.confirm_button.disabled, "choosing an element alone does not awaken")
	await key(KEY_ESCAPE)
	check(not session.awakening_open and magic.ensure("ali").element == "", "cancel preserves unawakened state")
	await key(KEY_R)
	await click(ui.element_buttons.water)
	var blocked_path := path.get_base_dir() + "/blocked-directory"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked_path))
	items.path = blocked_path
	await click(ui.confirm_button)
	items.path = path
	check(session.awakening_open and magic.ensure("ali").element == "", "failed save rolls back awakening and allows retry")
	var settled: int = magic.ensure("ali").pending_points
	await click(ui.confirm_button)
	check(magic.ensure("ali").element == "water" and magic.ensure("ali").level == 1 and magic.ensure("ali").skill_points == 0 and magic.ensure("ali").xp==settled and magic.ensure("ali").pending_points==0 and ui.attributes_root.visible, "confirmed awakening settles pending points once")
	check(not magic.awaken("ali", "fire") and magic.ensure("ali").element == "water", "element is exclusive and cannot be changed")
	check(not magic.awaken("heya", "earth"), "inactive role cannot awaken through the current operator")
	# Inspect another role without switching control; equipment belongs to its own bag.
	await key(KEY_ESCAPE)
	check(session.roster_open and session.attributes_id == "", "Escape from attributes returns to roster")
	var hud: Node = game.get_node("HUD")
	await click(hud.attribute_buttons[1])
	check(session.attributes_id == "heya" and session.selected == 0 and ui.current.name == world.controllable[1].resident_name and ui.awaken_button.disabled, "per-role attributes button views correct character without switching")
	var ali_bag: Array = items.ensure_bag("ali").duplicate(true)
	var heya_bag: Array = items.ensure_bag("heya").duplicate(true)
	check(not magic.claim_gear("heya") and items.ensure_bag("heya")==heya_bag and not magic.ensure("heya").gear_claimed, "free equipment claim is disabled without changing either role")
	for slot: String in Rules.EQUIPMENT:
		items.exchange("heya", {}, {Rules.EQUIPMENT[slot].item: 1}) # Prepared crafted equipment.
	check(items.ensure_bag("ali")==ali_bag, "prepared equipment belongs only to the selected role")
	var gear_bag: Array = items.ensure_bag("heya").duplicate(true)
	for slot: String in Rules.EQUIPMENT:
		await click(ui.gear_buttons[slot].button)
		await click(ui.wear_button)
		check(magic.ensure("heya").equipment[slot] == Rules.EQUIPMENT[slot].item and not items.has_item("heya", Rules.EQUIPMENT[slot].item), "real equipment UI transfers one item into slot " + slot)
	var equipped: Dictionary = magic.ensure("heya").duplicate(true)
	check(not magic.equip("heya", "head", "leather_armor") and magic.ensure("heya") == equipped, "wrong equipment slot is rejected without mutation")
	gear_bag = items.ensure_bag("heya").duplicate(true)
	for i in range(21): items.bags.heya[i] = {"item": "book", "count": 10}
	check(not magic.equip("heya", "head", "") and magic.ensure("heya").equipment.head == "leather_helmet", "full bag keeps unequippable gear in its slot")
	items.bags.heya = gear_bag
	items.path = blocked_path
	check(not magic.equip("heya", "head", ""), "failed equipment write reports failure")
	items.path = path
	check(magic.ensure("heya") == equipped and items.ensure_bag("heya") == gear_bag, "failed equipment write rolls back slot and bag together")
	await click(ui.gear_buttons.head.button)
	await key(KEY_ESCAPE)
	check(not ui.picker_root.visible and ui.attributes_root.visible, "Escape closes equipment picker before closing attributes")
	await click(ui.gear_buttons.head.button)
	await click(ui.remove_button)
	check(magic.ensure("heya").equipment.head == "" and items.has_item("heya", "leather_helmet"), "actual unequip click returns gear to this role's bag")
	# Skill economy and prerequisites remain separate from the ten-point mana stat.
	session.show_attributes("ali")
	await click(ui.tree_tab)
	check(ui.tree_root.visible and ui.skill_buttons.size() == 5 and ui.branches.size() == 3, "skill tab contains five trunk nodes followed by three pending branches")
	check(magic.award_points("ali", 75) and magic.ensure("ali").level == 2 and magic.ensure("ali").skill_points == 5, "first upgrade awards five skill points")
	check(not magic.unlock("ali", "trunk_1") and magic.ensure("ali").skill_points == 5, "five points cannot pay a ten-point skill")
	check(magic.award_points("ali", 100), "second upgrade supplies ten points")
	check(not magic.unlock("ali", "trunk_2"), "cannot skip the first trunk node")
	await click(ui.skill_buttons[0])
	check(magic.ensure("ali").unlocked == ["trunk_1"] and magic.ensure("ali").skill_points == 0, "real skill click spends exactly ten points")
	check(not magic.unlock("ali", "trunk_1") and not magic.unlock("ali", "branch_1"), "duplicates and undefined branch skills do not spend points")
	check(magic.award_points("ali", 1300) and magic.ensure("ali").level == 13 and magic.ensure("ali").skill_points == 50, "multi-level gain carries magic remainder and awards each upgrade once")
	for i in range(1, 5): await click(ui.skill_buttons[i])
	check(magic.ensure("ali").unlocked.size() == 5 and magic.ensure("ali").skill_points == 10 and ui.current.branches_ready and ui.branches.all(func(b: Button) -> bool: return b.disabled), "five sequential skills use fifty points and expose three undefined branch entrances")
	var before_magic: Dictionary = magic.ensure("ali").duplicate(true)
	items.path = blocked_path
	check(not magic.award_points("ali", 200), "magic award fails if save fails")
	items.path = path
	check(magic.ensure("ali") == before_magic, "failed award preserves experience and skill points")
	var before_vitals: Dictionary = session.vitals.ensure("ali").duplicate(true)
	check(magic.award_points("ali", 100000) and magic.ensure("ali").level == 100 and magic.ensure("ali").xp == 0 and magic.ensure("ali").skill_points == 445, "level cap retains all earned unspent points")
	var at_cap: Dictionary = magic.ensure("ali").duplicate(true)
	check(magic.award_points("ali", 100) and magic.ensure("ali")==at_cap and session.vitals.ensure("ali") == before_vitals, "magic progress never drains or restores survival mana")
	await click(ui.level_tab)
	check(ui.xp_label.text.contains("lv.100") and ui.xp_bar.value == ui.xp_bar.max_value, "max level page displays a full progress bar without a zero denominator")
	# Save, reload, revival and checkpoint rollback all retain the appropriate magic state.
	check(session.persistence.save_checkpoint(false), "checkpoint records magic and equipment")
	var checkpoint_magic: Dictionary = magic.export_state()
	session.close_roster()
	session.select_resident(1)
	world.active_resident.position = Vector2(548, 332)
	check(magic.awaken("heya", "fire"), "a second resident can choose a different exclusive element")
	check(magic.award_points("heya", 130), "second resident experience is independent")
	session.select_resident(0)
	world.active_resident.position = Vector2(548, 244)
	var before_revival: Dictionary = magic.ensure("heya").duplicate(true)
	session.vitals.ensure("heya").life = 0
	session.vitals._sync_actors()
	items.ensure_container("altar:display")[0] = {"item": "bread", "count": 1}
	session._sync_view()
	session.interact()
	items.slot_clicked("storage", 0, false)
	check(session.offerings.sacrifice("heya").ok and magic.ensure("heya") == before_revival, "real altar sacrifice preserves the revived role's element, progress and equipment")
	items.close()
	session.overview = true
	check(not magic.award_points("heya", 100) and not magic.equip("heya", "head", "leather_helmet") and magic.ensure("heya") == before_revival, "overview pause blocks progress and equipment mutations")
	session.overview = false
	var saved: Dictionary = magic.export_state()
	check(session.persistence.save_now(), "autosave includes both roles and gear")
	game.queue_free()
	await frames(4)
	await load_game()
	check(magic.export_state() == saved and items.has_item("heya", "leather_helmet"), "restart keeps elements, levels, experience, spent points and worn gear")
	check(session.persistence.restore_checkpoint() and magic.export_state() == checkpoint_magic, "checkpoint rolls back magic progression and equipment together")
	var legacy: Dictionary = items.export_data()
	legacy.session.erase("magic")
	items.apply_data(legacy)
	session.persistence.restore_session(legacy.session)
	check(magic.ensure("ali") == Rules.fresh() and magic.ensure("heya") == Rules.fresh(), "pre-magic saves default to unawakened with empty slots, without changing old inventory")
	game.queue_free()
	await frames(4)
	if failures.is_empty(): print("MAGIC_SMOKE_OK")
	else: print("MAGIC_FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
