# Exercises controlled-only survival, legacy clocks, roster UI and atomic altar resurrection.
extends SceneTree

var failures: Array[String] = []
var game: Node
var session: Node
var world: Node2D
var items: Node
var vitals: Node
var path := ""

func _initialize() -> void:
	path = "res://.runtime/revival-" + str(Time.get_ticks_usec()) + "/state.json"
	OS.set_environment("AIU5_STATE_PATH", path)
	OS.set_environment("AIU5_PROFILE_PATH", path + ".names")
	OS.set_environment("AIU5_WORLD_PROFILE", "starter")
	create_timer(50, true).timeout.connect(func() -> void: push_error("REVIVAL_TIMEOUT"); quit(2))
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
	vitals = game.get_node("Vitals")
	session.simulation.set_process(false)
	session.simulation.reset()
	session.persistence.set_process(false)
	for actor in world.residents: actor.set_physics_process(false)
	for animal in session.livestock.animals: animal.set_physics_process(false)
	await frames()

func run() -> void:
	await load_game()
	var a: Dictionary = vitals.ensure("ali")
	var h: Dictionary = vitals.ensure("heya")
	var chief: Dictionary = vitals.ensure("chief_priest")
	check(a.mana == 10 and h.mana == 10 and chief.mana == 10, "all new residents start at ten mana")
	a.need_time = 179.5
	h.merge({"life": 8, "hunger": 1, "thirst": 1, "health": 3, "mana": 7,
		"need_time": 179.5, "damage_time": 9.5, "low_health": true, "low_time": 1799.5,
		"ill": true, "active_time": 120.0, "raw_meals": [110.0, 115.0]}, true)
	var frozen := h.duplicate(true)
	chief.health = 2
	chief.mana = 7
	var chief_frozen := chief.duplicate(true)
	vitals.advance(180.5)
	check(h == frozen, "inactive five stats, starvation, low-health deadline and meal clock freeze exactly")
	check(chief == chief_frozen, "inactive newly low health cannot apply the five-life entry penalty")
	check(a.hunger == 8 and a.thirst == 8 and a.mana == 10, "only active needs advance and mana has no drain or recovery")
	session.simulation.pending = 0.25
	var before: float = a.active_time
	session.select_resident(1)
	check(is_equal_approx(a.active_time, before + 0.25) and h == frozen, "switch flush charges partial time to the previous operator")
	# Resume from the frozen partial second, with no debt from the time spent inactive.
	h.health = 10
	h.low_health = false
	h.hunger = 10
	h.thirst = 10
	h.damage_time = 0.0
	vitals.advance(0.4)
	check(h.hunger == 10 and h.mana == 7, "switch back resumes the remaining half second without catchup")
	vitals.advance(0.1)
	check(h.hunger == 9 and h.mana == 7, "resumed need clock reaches its original exact threshold")
	check(not vitals.use_food("ali", "bread"), "direct use cannot change an inactive resident's five stats")
	# Migrate pre-mana global meal timestamps without resetting their remaining window.
	var legacy: Dictionary = vitals.export_state()
	legacy.online = 1000.0
	legacy.residents.heya.erase("mana")
	legacy.residents.heya.erase("active_time")
	legacy.residents.heya.raw_meals = [410.0, 420.0]
	legacy.residents.chief_priest.mana = 40
	vitals.restore(legacy)
	h = vitals.ensure("heya")
	check(h.mana == 10 and h.active_time == 1000, "legacy save defaults mana and migrates the meal clock")
	check(vitals.ensure("chief_priest").mana == 10, "loaded mana clamps to the ten-point maximum")
	session.select_resident(0)
	frozen = h.duplicate(true)
	vitals.advance(601)
	check(h == frozen, "legacy raw-meat history does not expire while inactive")
	session.select_resident(1)
	vitals.advance(11)
	check(h.raw_meals == [420.0], "legacy meal window expires only after the correct controlled seconds")
	session.select_resident(0)
	a = vitals.ensure("ali")
	a.mana = 6
	# Two dead targets; the second is indoors and has illness and timer debt.
	var target: CharacterBody2D = world.controllable[1]
	session.interiors.enter(target, world.home_data("house"))
	target.position = Vector2(104, 104)
	h.merge({"life": 0, "health": 2, "hunger": 1, "thirst": 1, "mana": 0,
		"ill": true, "low_health": true, "low_time": 1799.0, "damage_time": 9.0}, true)
	vitals.ensure("chief_priest").life = 0
	vitals._sync_actors()
	world.active_resident.position = Vector2(548, 244)
	session._sync_view()
	await key(KEY_C)
	var hud: Node = game.get_node("HUD")
	check(session.roster_open and hud.stat_bars.size() == 5, "real C opens roster and HUD contains five bars")
	check(hud.roster_buttons[0].text.contains("魔力 6/10") and hud.roster_buttons[1].text.contains("生命 0/10") and hud.roster_buttons[1].disabled, "roster displays independent mana and dead resident values")
	await key(KEY_C)
	# Merely depositing items never revives anyone.
	items.ensure_container("altar:display")[0] = {"item": "bread", "count": 3}
	items.ensure_container("altar:display")[1] = {"item": "book", "count": 1}
	await key(KEY_E)
	var ui: Node = game.get_node("Belongings")
	check(items.opened and items.container_name == "祭坛" and target.dead, "renamed altar opens without automatically sacrificing deposited items")
	await click(ui.storage_buttons[0])
	check(ui.target_ids == ["heya", "chief_priest"] and not ui.sacrifice_button.disabled, "explicit target selector offers only dead playable residents")
	check(not session.offerings.sacrifice("ali").ok and not session.offerings.sacrifice("missing").ok and items.ensure_container("altar:display")[0].count == 3, "living and nonexistent targets never consume offerings")
	items.selection = {"side": "storage", "index": 20}
	check(not session.offerings.sacrifice("heya").ok, "empty altar slot cannot resurrect anyone")
	items.selection = {"side": "bag", "index": 0}
	check(not session.offerings.sacrifice("heya").ok, "bag selection cannot be consumed as an altar offering")
	items.selection = {"side": "storage", "index": 0}
	# Force an actual file-rename failure; the original save bytes must remain intact.
	check(session.persistence.save_now(), "pre-sacrifice autosave succeeds")
	var bytes := FileAccess.get_file_as_bytes(path)
	var blocked_path := path.get_base_dir() + "/blocked-directory"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked_path))
	var before_slot: Dictionary = items.ensure_container("altar:display")[0].duplicate(true)
	frozen = h.duplicate(true)
	var old_outside: Vector2 = session.interiors.outdoor_position(target)
	items.path = blocked_path
	var result: Dictionary = session.offerings.sacrifice("heya")
	items.path = path
	check(not result.ok and items.ensure_container("altar:display")[0] == before_slot and vitals.ensure("heya") == frozen, "real save failure rolls back exactly one item and every resident stat")
	check(target.dead and target.room_id == "house" and target.position == Vector2(104, 104) and session.interiors.outdoor_position(target) == old_outside, "failed indoor resurrection restores room and position")
	check(FileAccess.get_file_as_bytes(path) == bytes, "failed sacrifice does not change the committed save")
	var bag: Array = items.ensure_bag("ali").duplicate(true)
	ui.sacrifice_target.select(1)
	await click(ui.sacrifice_button)
	check(vitals.ensure("chief_priest").life == 10 and target.dead and items.ensure_container("altar:display")[0].count == 2, "real sacrifice click consumes one from stack and revives only the selected second target")
	check(world.controllable[2].position.distance_to(Vector2(548, 360)) < 90 and session.selected == 0 and items.ensure_bag("ali") == bag, "revival occurs by altar without switching operator or changing their bag")
	check(not session.offerings.sacrifice("chief_priest").ok and items.ensure_container("altar:display")[0].count == 2, "stale double-click cannot pay again for an already living target")
	await click(ui.storage_buttons[1])
	await click(ui.sacrifice_button)
	h = vitals.ensure("heya")
	check(not target.dead and target.room_id == "" and items.ensure_container("altar:display")[1].is_empty(), "single book can revive the remaining indoor target and consumes exactly one")
	check(h.life == 10 and h.hunger == 10 and h.thirst == 10 and h.health == 10 and h.mana == 10 and not h.ill and not h.low_health and h.need_time == 0 and h.damage_time == 0 and h.low_time == 0 and h.raw_meals.is_empty(), "revived resident starts with five full stats and no illness or lethal timer debt")
	check(ui.sacrifice_button.disabled and ui.sacrifice_target.disabled and ui.sacrifice_target.get_item_text(0) == "没有阵亡角色", "altar disables sacrifice when nobody remains dead")
	frozen = h.duplicate(true)
	vitals.advance(180)
	check(h == frozen and vitals.ensure("ali").mana == 6, "revived inactive resident stays frozen and active mana does not regenerate")
	# Distance validation remains authoritative even if a UI action is forged.
	vitals.ensure("chief_priest").life = 0
	vitals._sync_actors()
	items.selection = {"side": "storage", "index": 0}
	world.active_resident.position = Vector2(350, 200)
	check(not session.offerings.sacrifice("chief_priest").ok and items.ensure_container("altar:display")[0].count == 2, "sacrifice cannot be invoked from away from altar")
	world.active_resident.position = Vector2(548, 244)
	check(session.persistence.save_now(), "full state including resurrection and mana can be saved")
	var saved: Dictionary = session.persistence.capture_session()
	game.queue_free()
	await frames(4)
	await load_game()
	check(vitals.ensure("ali").mana == 6 and vitals.ensure("heya") == frozen and vitals.ensure("chief_priest").life == 0, "restart preserves mana, revived resident and the other current death")
	check(items.ensure_container("altar:display")[0].count == 2 and items.ensure_container("altar:display")[1].is_empty(), "restart neither refunds nor consumes sacrifice twice")
	check(vitals.online == saved.vitals.online, "restart never adds offline survival time")
	# Existing all-party checkpoint rollback is still authoritative when nobody can sacrifice.
	for actor in world.controllable: vitals.ensure(actor.resident_id).life = 0
	vitals._sync_actors()
	vitals.deaths_changed.emit()
	await frames(4)
	check(world.controllable.all(func(actor: CharacterBody2D) -> bool: return not actor.dead), "all-party wipe still returns to the independent altar checkpoint")
	game.queue_free()
	await frames(4)
	if failures.is_empty(): print("ALTAR_REVIVAL_SMOKE_OK")
	else: print("ALTAR_REVIVAL_FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
