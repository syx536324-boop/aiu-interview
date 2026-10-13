# Verifies both tribes: member counts and roles, hostility rules, territory limits and chief magic.
extends SceneTree
var failures: Array[String] = []
var game: Node
var s: Node
var path := ""
func _initialize() -> void:
	path = "res://.runtime/tribes-"+str(Time.get_ticks_usec())+"/state.json"
	OS.set_environment("AIU5_STATE_PATH", path)
	OS.set_environment("AIU5_PROFILE_PATH", path+".names")
	create_timer(60, true).timeout.connect(func() -> void: quit(2))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func frames(n := 3) -> void:
	for i in range(n): await process_frame
func physics(n := 1) -> void:
	for i in range(n): await physics_frame
func pick(list: Array, npc_role: String) -> CharacterBody2D:
	for member: CharacterBody2D in list:
		if member.role == npc_role: return member
	return list[0]
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	s = game.get_node("Session")
	s.simulation.set_process(false)
	s.simulation.reset()
	s.persistence.set_process(false)
	await frames()
	var combat: Node = s.combat
	var forest: Array = combat.tribe_members("forest")
	var barbarian: Array = combat.tribe_members("barbarian")
	check(forest.size() == 20, "forest tribe starts with twenty members")
	var yunye: Array = combat.tribe_members("yunye")
	check(yunye.size() == 20, "yunye tribe starts with twenty members on the mountainside")
	check(combat.TRIBES["yunye"].area == Rect2(2850, -1050, 900, 700), "yunye tribe lives on the mid-slope territory")
	check(s.magic.ensure("yunye_chief").element == "earth" and s.magic.ensure("yunye_chief").level == 9, "yunye chief has level nine earth magic")
	check(barbarian.size() == 20, "barbarian tribe starts with twenty members")
	var roles := {"civilian": 0, "archer": 0, "charger": 0}
	for member: CharacterBody2D in barbarian: roles[member.role] = int(roles[member.role]) + 1
	check(roles.civilian == 12 and roles.archer == 4 and roles.charger == 4, "every village fields twelve civilians, four archers and four chargers")
	var wood: Dictionary = s.magic.ensure("forest_chief")
	check(wood.element == "wood" and wood.level == 9 and wood.unlocked == ["trunk_1","trunk_2","trunk_3","trunk_4"], "forest chief has level nine wood magic with four skills")
	var fire: Dictionary = s.magic.ensure("barbarian_chief")
	check(fire.element == "fire" and fire.level == 9 and fire.unlocked.size() == 4, "barbarian chief has level nine fire magic with four skills")
	check(s.magic.max_mana("forest_chief") == 50 and s.magic.max_mana("barbarian_chief") == 50, "chiefs share the level nine mana cap of fifty")
	check(pick(barbarian, "charger").aggro_range() == 210.0, "barbarian tribe attacks on sight")
	check(pick(forest, "charger").aggro_range() == 80.0, "forest tribe only reacts inside eighty world pixels")
	check(pick(barbarian, "charger").aggro_range() != pick(forest, "charger").aggro_range(), "the two tribes do not share one attitude")
	# Only the active residents take part in combat, so mirror the real controlled character.
	for actor in s.world.residents: actor.set_physics_process(false)
	var actor: CharacterBody2D = s.world.active_resident
	var barb: CharacterBody2D = pick(barbarian, "charger")
	actor.global_position = barb.global_position + Vector2(150, 0)
	var before := barb.global_position.distance_to(actor.global_position)
	await physics(90)
	check(barb.global_position.distance_to(actor.global_position) < before - 2.0, "a hostile member closes in as soon as it sees the player")
	var fore: CharacterBody2D = pick(forest, "charger")
	actor.global_position = fore.global_position + Vector2(150, 0)
	var fore_before := fore.global_position.distance_to(actor.global_position)
	await physics(90)
	check(absf(fore.global_position.distance_to(actor.global_position) - fore_before) < 2.0, "the unknown forest tribe ignores a distant player")
	actor.global_position = fore.global_position + Vector2(60, 0)
	await physics(90)
	check(fore.global_position.distance_to(actor.global_position) < 60.0, "the forest tribe retaliates inside eighty pixels")
	# Members never leave their own territory, so they cannot raid the village.
	var area: Rect2 = combat.TRIBES["barbarian"].area
	barb.global_position = area.get_center()
	actor.global_position = area.position + Vector2(-220, area.size.y / 2.0)
	await physics(150)
	check(area.grow(12).has_point(barb.global_position), "tribe members never leave their territory")
	game.queue_free()
	await frames(2)
	if failures.is_empty(): print("TRIBES_SMOKE_OK")
	else: print(failures)
	quit(0 if failures.is_empty() else 1)
