# Verifies real leveling, minute boundaries, inactive/pause clocks, migration, UI and saved mana recovery.
extends Node
const Rules := preload("res://features/magic/catalog.gd")
var game: Node
var session: Node
var directory := ""
var failures: Array[String] = []
var checks := 0
var capture := false

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	directory = OS.get_environment("AIU5_PROBE_DIRECTORY")
	assert(directory != "")
	OS.set_environment("AIU5_STATE_PATH", directory + "/state.json")
	OS.set_environment("AIU5_PROFILE_PATH", directory + "/names.cfg")
	OS.set_environment("AIU5_WORLD_PROFILE", "starter")
	capture = OS.get_environment("AIU5_CAPTURE") == "true"
	get_tree().create_timer(45, true).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func frames(n := 5) -> void:
	for i in range(n): await get_tree().process_frame

func load_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(game)
	session = game.get_node("Session")
	session.simulation.set_process(false)
	session.simulation.reset()
	session.persistence.set_process(false)
	for actor in session.world.residents: actor.set_physics_process(false)
	await frames()

func screenshot(name: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(directory + "/" + name + ".png") == OK, "capture " + name)

func run() -> void:
	check(ProjectSettings.get_setting("application/config/version") == "0.7.8", "release version")
	await load_game()
	var magic: Node = session.magic
	var vitals: Node = session.vitals
	var stats: Dictionary = vitals.ensure("ali")
	check(stats.mana == 10 and vitals.max_mana("ali") == 10, "initial ten mana")
	var state: Dictionary = magic.ensure("ali")
	state.element = "wood"
	stats.mana = 4
	stats.mana_recovery_time = 29.5
	check(magic.award_points("ali", 100), "real level up")
	check(state.level == 2 and state.skill_points == 5 and vitals.max_mana("ali") == 15, "level two cap fifteen and five skill points")
	check(stats.mana == 4 and stats.mana_recovery_time == 29.5, "upgrade only changes cap")
	var path: String = session.inventory.path
	var blocked := directory + "/blocked"
	DirAccess.make_dir_recursive_absolute(blocked)
	session.inventory.path = blocked
	check(not magic.award_points("ali", 100), "failed level save rejected")
	session.inventory.path = path
	check(magic.ensure("ali").level == 2 and vitals.max_mana("ali") == 15 and stats.mana == 4 and stats.mana_recovery_time == 29.5, "failed save rolls back level and derived cap")
	for element: String in Rules.ELEMENTS:
		for level: int in [1, 2, 10, 100]:
			state = Rules.fresh()
			state.element = element
			state.level = level
			magic.states.ali = state
			var expected: int = {1:10, 2:15, 10:55, 100:505}[level]
			check(vitals.max_mana("ali") == expected, "mana limit " + element + " " + str(level))
	state.element = "wood"
	state.level = 100
	stats.mana = 1
	stats.mana_recovery_time = 0.0
	var inactive: Dictionary = vitals.ensure("heya")
	inactive.mana = 3
	inactive.mana_recovery_time = 59.5
	var frozen := inactive.duplicate(true)
	vitals.advance(59.5)
	check(stats.mana == 1 and stats.mana_recovery_time == 59.5, "no recovery before sixty seconds")
	vitals.advance(0.5)
	check(stats.mana == 2 and is_zero_approx(stats.mana_recovery_time), "one point at exactly sixty seconds")
	vitals.advance(120.25)
	check(stats.mana == 4 and is_equal_approx(stats.mana_recovery_time, 0.25), "long tick recovers two and preserves fractional progress")
	check(inactive == frozen, "inactive character is fully frozen")
	stats.mana = 504
	stats.mana_recovery_time = 59.5
	vitals.advance(120.5)
	check(stats.mana == 505 and is_zero_approx(stats.mana_recovery_time), "never overfills and full mana banks no recovery time")
	state.unlocked = ["trunk_1", "trunk_2"]
	check(session.inventory.exchange("ali", {}, {"wood_sword":1}), "prepare weapon")
	check(magic.equip_weapon("ali", "wood_sword"), "equip weapon")
	check(magic.skills.cast(2, Vector2.ZERO) and stats.mana == 500, "skill spends mana above former ten-point cap")
	vitals.advance(59.5)
	check(stats.mana == 500, "full-time credit cannot give instant mana after spending")
	vitals.advance(0.5)
	check(stats.mana == 501, "skill-spent mana recovers after one minute")
	var active_frozen := stats.duplicate(true)
	session.select_resident(1)
	vitals.advance(0.4)
	check(inactive.mana == 3, "switch preserves remaining half second")
	vitals.advance(0.1)
	check(inactive.mana == 4 and vitals.ensure("ali") == active_frozen, "switch resumes each independent recovery clock")
	magic.ensure("heya").element = "water"
	magic.ensure("heya").level = 10
	inactive.life = 0
	inactive.mana = 0
	inactive.mana_recovery_time = 59.5
	frozen = inactive.duplicate(true)
	vitals.advance(120)
	check(inactive == frozen, "dead residents cannot regenerate")
	check(vitals.revive("heya") and vitals.ensure("heya").mana == 55 and vitals.ensure("heya").mana_recovery_time == 0, "revival retains full-stat rule with level-derived cap")
	session.select_resident(0)
	stats = vitals.ensure("ali")
	stats.mana = 37
	stats.mana_recovery_time = 59.5
	check(session.persistence.save_now(), "save high mana and fractional minute")
	game.queue_free()
	await frames()
	await load_game()
	magic = session.magic
	vitals = session.vitals
	stats = vitals.ensure("ali")
	check(magic.ensure("ali").level == 100 and vitals.max_mana("ali") == 505 and stats.mana == 37 and stats.mana_recovery_time == 59.5, "reload preserves high mana and fractional progress without offline recovery")
	vitals.advance(0.5)
	check(stats.mana == 38, "reload resumes remaining half second")
	var legacy: Dictionary = vitals.export_state()
	legacy.residents.ali.erase("mana_recovery_time")
	legacy.residents.ali.mana = 400
	vitals.restore(legacy)
	stats = vitals.ensure("ali")
	check(stats.mana == 400 and stats.mana_recovery_time == 0, "legacy high mana stays above ten and absent clock starts zero")
	legacy.residents.ali.mana = 900
	vitals.restore(legacy)
	check(vitals.ensure("ali").mana == 505, "restore clamps at actual level cap")
	legacy.residents.ali.mana = -2
	vitals.restore(legacy)
	check(vitals.ensure("ali").mana == 0, "restore rejects negative mana")
	legacy.residents.ali.erase("mana")
	vitals.restore(legacy)
	check(vitals.ensure("ali").mana == 10 and vitals.max_mana("ali") == 505, "missing legacy mana defaults to initial ten without free refill")
	stats = vitals.ensure("ali")
	stats.mana = 100
	stats.mana_recovery_time = 59.5
	frozen = stats.duplicate(true)
	session.simulation.set_process(true)
	get_tree().paused = true
	await get_tree().create_timer(0.1, true).timeout
	check(vitals.ensure("ali") == frozen, "real paused tree stops mana clock")
	session.simulation.set_process(false)
	get_tree().paused = false
	stats.mana = 505
	session.refresh_interface()
	var hud: Node = game.get_node("HUD")
	check(hud.stat_labels.mana.text == "魔力 505/505" and hud.stat_bars.mana.maximum == 505, "hud shows current and variable cap")
	var label: Label = hud.stat_labels.mana
	var width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
	check(label.position.x + width < hud.stat_bars.mana.position.x, "maximum mana label fits before its bar")
	await screenshot("mana-hud")
	session.roster_open = true
	session.refresh_interface()
	check(hud.roster_buttons[0].text.contains("魔力 505/505"), "character roster shows new cap")
	await screenshot("mana-roster")
	session.show_attributes("ali")
	var attributes: Node = game.get_node("Attributes")
	attributes._show_page("tree")
	check(attributes.skill_points.text.contains("魔力：505/505"), "skill tree shows new cap")
	await screenshot("mana-skills")
	game.queue_free()
	await frames()
	if failures.is_empty(): print("MANA_LEVEL_AND_RECOVERY_OK checks=", checks)
	get_tree().quit(0 if failures.is_empty() else 1)
