# Isolated acceptance probe for the 0.10.0 NPC attitude, memory, guard, skill and migration rules.
# Real business entries only: tribe interactions, combat damage, relic attacks and disk saves are exercised;
# nothing in features/ is mocked. Run with a fresh AIU5_PROBE_DIRECTORY and never against real player data.
extends Node

const STATES := ["life", "patrol", "observe", "warn", "engage", "prepare", "attack", "search", "retreat", "return"]

var game: Node
var s: Node
var t: Node
var directory := ""
var only := ""
var checks := 0
var failures: Array[String] = []
var pending: Array[String] = []

# Resolved module handles (null until the owning agent lands the module).
var relation: Variant = null
var guards: Variant = null
var npc_skills: Variant = null

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	directory = OS.get_environment("AIU5_PROBE_DIRECTORY")
	only = OS.get_environment("AIU5_PROBE_ONLY")
	if directory == "":
		push_error("AIU5_PROBE_DIRECTORY is required for the isolated probe")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	OS.set_environment("AIU5_STATE_PATH", directory + "/state.json")
	OS.set_environment("AIU5_PROFILE_PATH", directory + "/names.cfg")
	OS.set_environment("AIU5_WORLD_PROFILE", "starter_v2")
	get_tree().create_timer(300, true).timeout.connect(func() -> void:
		push_error("NPC_ATTITUDE_TIMEOUT")
		get_tree().quit(2))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func frames(n := 4) -> void:
	for i in range(n):
		await get_tree().process_frame

func load_game() -> Node:
	game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	await frames()
	s = game.get_node("Session")
	s.simulation.set_process(false)
	s.simulation.reset()
	s.persistence.set_process(false)
	for actor: Node in s.world.residents:
		if is_instance_valid(actor):
			actor.set_physics_process(false)
	for enemy: Node in s.combat.enemies.values():
		if is_instance_valid(enemy):
			enemy.set_physics_process(false)
	t = s.tribes
	_resolve_modules()
	return s

func fresh_game() -> void:
	if is_instance_valid(game):
		game.queue_free()
	await frames(6)
	for suffix: String in ["", ".tmp", ".altar", ".altar.tmp"]:
		var path: String = directory + "/state.json" + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	s = await load_game()

# Restarts the scene while keeping the isolated disk save, to prove persistence.
func reload_game() -> void:
	if is_instance_valid(game):
		game.queue_free()
	await frames(6)
	s = await load_game()

func _resolve_modules() -> void:
	relation = prop(t, ["relation", "memory", "relation_memory"])
	guards = prop(t, ["guards"])
	npc_skills = prop(t, ["npc_skills"])
	if npc_skills == null:
		npc_skills = prop(s.combat, ["npc_skills"])
	if npc_skills == null:
		npc_skills = prop(s, ["npc_skills"])

func prop(holder: Object, names: Array) -> Variant:
	if holder == null:
		return null
	for name: String in names:
		var value: Variant = holder.get(name)
		if value != null:
			return value
	return null

func method_of(holder: Object, names: Array) -> String:
	if holder == null:
		return ""
	for name: String in names:
		if holder.has_method(name):
			return name
	return ""

func callm(holder: Object, names: Array, args: Array) -> Variant:
	var name := method_of(holder, names)
	if name == "":
		return null
	return holder.callv(name, args)

func field(record: Variant, key: String, fallback: Variant = null) -> Variant:
	if record is Dictionary:
		return record.get(key, fallback)
	return fallback

func actor_id() -> String:
	return s.world.active_resident.resident_id

func unit(id: String) -> Node:
	return t.population.node(id)

func count(id: String, item: String) -> int:
	var total := 0
	for slot: Dictionary in s.inventory.ensure_bag(id):
		if slot.get("item", "") == item:
			total += int(slot.count)
	return total

func give(id: String, item: String, amount: int) -> void:
	s.inventory.bags[id] = s.inventory._sanitize_slots([{"item": item, "count": amount}])

# Drives the single online clock in the project's coarse tick size; no real time is consumed.
func drive(seconds: float, step := 0.5) -> void:
	var left := seconds
	while left > 0.0001:
		var slice := minf(step, left)
		t.advance(slice)
		await get_tree().process_frame
		left -= slice

func spawn_wall(at: Vector2, size: Vector2) -> Node2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	body.position = at
	s.world.objects.add_child(body)
	return body

func blocked(at: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	query.shape = circle
	query.transform = Transform2D(0, at)
	query.collision_mask = 1
	return not s.world.get_world_2d().direct_space_state.intersect_shape(query).is_empty()

func first_visible_npc(tribe: String, role := "") -> String:
	for id: String in t.population.members:
		var member: Dictionary = t.population.members[id]
		if str(member.tribe) != tribe or float(member.child_left) > 0:
			continue
		if role != "" and str(member.career) != role:
			continue
		if is_instance_valid(unit(id)) and unit(id).hp > 0:
			return id
	return ""

# JSON round-trips ints to floats, so compare memory by normalized event content.
func memory_signature(npc_id: String) -> String:
	var parts: Array[String] = []
	var events: Array = callm(relation, ["memory_of"], [npc_id])
	for entry: Dictionary in events:
		parts.append("%s|%s|%d|%s" % [str(entry.get("event", "")), str(entry.get("actor", "")),
			int(entry.get("severity", 0)), str(entry.get("detail", ""))])
	return ";".join(parts)

func state_of(id: String) -> String:
	return str(field(callm(guards, ["snapshot_for", "npc"], [id]), "state", ""))

# The unified personal-affinity entry lives in relation_memory; older code used romance.liking.
func liking_of(actor: String, npc_id: String) -> int:
	var value: Variant = callm(relation, ["liking"], [actor, npc_id])
	if value != null:
		return int(value)
	return int(t.romance.liking(actor, npc_id))

func in_states(id: String, names: Array) -> bool:
	return state_of(id) in names

# The normal bread gift is only reachable through the NPC dialog; find its real recipe id.
func gift_recipe(id: String) -> String:
	t.open("npc", id)
	var snapshot: Dictionary = t.snapshot()
	var recipes: Array = snapshot.get("recipes", [])
	for recipe: Dictionary in recipes:
		if str(recipe.get("id", "")).contains("bread"):
			return str(recipe.get("id", ""))
	return ""

func do_gift(target_id: String) -> Variant:
	var recipe := gift_recipe(target_id)
	if recipe != "":
		return t.perform(recipe)
	return callm(t, ["gift_event", "gift_bread"], [target_id])

# ---------------------------------------------------------------- run

func run() -> void:
	s = await load_game()
	preflight()

	section_isolation()
	if only == "" or only == "relations":
		if relation != null and t.has_method("standing"):
			await section_relations()
		else:
			pending.append("tribes standing/attitude/gift API and relation memory")
	if only == "" or only == "guards":
		if guards != null:
			await section_guards()
		else:
			pending.append("features/tribes/guards.gd behavior state machine")
	if only == "" or only == "skills":
		if npc_skills != null and s.magic.skills.has_method("cast_for"):
			await section_skills()
		else:
			pending.append("features/combat/npc_skills.gd and magic.skills.cast_for")
	if only == "" or only == "persistence":
		if t.has_method("export_state") and relation != null:
			await section_persistence()
		else:
			pending.append("tribes/relation persistence")
	if only == "" or only == "clock":
		await section_clock()
	finish()

func preflight() -> void:
	for needed in ["standing", "attitude", "set_standing", "add_standing", "hostile", "alert",
			"gifting_left", "note_conflict", "register_death", "relic_attack_event", "aid_event"]:
		if not t.has_method(needed):
			pending.append("tribes." + needed)
	if method_of(t, ["gift_event", "gift_bread"]) == "":
		pending.append("tribes.gift_event/gift_bread")
	if not t.has_method("export_state") or not t.has_method("restore"):
		pending.append("tribes.export_state/restore")
	if not s.magic.skills.has_method("cast_for"):
		pending.append("magic.skills.cast_for")

func finish() -> void:
	if is_instance_valid(game):
		game.queue_free()
	if not failures.is_empty():
		print("NPC_ATTITUDE_PROBE_FAILED checks=", checks, " ", failures)
		get_tree().quit(1)
		return
	if not pending.is_empty():
		print("NPC_ATTITUDE_PROBE_PENDING checks=", checks, " missing=", pending)
		get_tree().quit(3)
		return
	print("NPC_ATTITUDE_PROBE_OK checks=", checks)
	get_tree().quit(0)

# ---------------------------------------------------------------- A. isolation

func section_isolation() -> void:
	print("ISOLATION enemies=", s.combat.enemies.size(), " home=", t.population.count("home"),
		" forest=", t.population.count("forest"), " barbarian=", t.population.count("barbarian"),
		" yunye=", t.population.count("yunye"), " members=", t.population.members.size(),
		" residents=", s.world.residents.size(), " settlement=", s.world.settlement)
	check(s.inventory.path.begins_with(directory), "probe state path stays inside AIU5_PROBE_DIRECTORY")
	check(s.world.settlement == "starter_v2", "probe loads the isolated starter_v2 world profile")
	for tribe: String in ["forest", "barbarian", "yunye"]:
		check(t.population.count(tribe) > 0, "tribe %s has living members" % tribe)
		check(t.relics.owner(tribe) != "player", "%s relic starts unoccupied" % tribe)
	check(unit("forest:0") != null and unit("barbarian:0") != null, "tribal NPC bodies exist for the probe")

# ---------------------------------------------------------------- B. relations, attitude, memory

func section_relations() -> void:
	await fresh_game()
	var actor := actor_id()
	give(actor, "bread", 30)

	check(t.standing("forest") == 0 and t.attitude("forest") == "neutral", "forest starts neutral at standing 0")
	check(t.standing("barbarian") == -50 and t.attitude("barbarian") == "hostile", "barbarian starts hostile at -50")
	check(t.standing("yunye") == -50 and t.attitude("yunye") == "hostile", "yunye starts hostile at -50")
	check(t.display_attitude("forest") == "中立", "display_attitude renders Chinese labels")
	check(not t.hostile("forest") and t.hostile("barbarian"), "hostile() separates neutral from hostile tribes")

	var thresholds := [[60, "trust"], [59, "friendly"], [20, "friendly"], [19, "neutral"],
		[-19, "neutral"], [-20, "alert"], [-49, "alert"], [-50, "hostile"], [-100, "hostile"]]
	var threshold_ok := true
	for pair: Array in thresholds:
		t.set_standing("forest", int(pair[0]))
		if t.attitude("forest") != str(pair[1]):
			threshold_ok = false
	t.set_standing("forest", 0)
	check(threshold_ok, "standing thresholds map to trust/friendly/neutral/alert/hostile exactly")

	# A normal bread gift through the real NPC interaction raises affinity +5 and standing +1.
	var target := first_visible_npc("forest")
	check(target != "", "a forest NPC is available for the gift flow")
	var before_liking: int = liking_of(actor, "npc:" + target)
	var recipe := gift_recipe(target)
	check(recipe != "", "NPC dialog offers the normal bread gift")
	var performed: Variant = t.perform(recipe)
	if performed != true:
		print("GIFT_DIAG recipe=", recipe, " allowed=", s.production.allowed(s.world.active_resident),
			" left=", t.gifting_left("forest"), " bread=", count(actor, "bread"),
			" owner=", t.relics.owner("forest"), " dialog=", t.dialog_kind, ":", t.dialog_id)
	check(performed, "normal bread gift performs through the real tribe interaction")
	check(liking_of(actor, "npc:" + target) == before_liking + 5, "normal bread gift raises personal affinity by five")
	check(t.standing("forest") == 1, "normal bread gift raises tribal standing by one")
	check(t.gifting_left("forest") == 4, "daily gift standing quota drops to four")

	# The same game day never allows more than five standing from gifts.
	var gift_ok := true
	for i in range(4):
		if not t.perform(recipe):
			gift_ok = false
	check(gift_ok, "four more normal bread gifts are accepted")
	check(t.gifting_left("forest") == 0, "daily gift standing quota reaches zero")
	check(t.standing("forest") == 5, "same-day gift standing never exceeds five")
	check(not t.perform(recipe), "a sixth gift is rejected")
	check(t.standing("forest") == 5 and t.gifting_left("forest") == 0, "rejected gift cannot raise standing or quota")
	if t.has_method("register_gift"):
		check(not t.register_gift("forest"), "the low-level quota entry also refuses the sixth gift")
		check(t.standing("forest") == 5, "rejected low-level gift keeps standing capped")
	# A new game day restores the gift allowance without touching standing.
	s.day_night.elapsed += 1440.0
	check(t.gifting_left("forest") == 5, "a new game day restores the daily gift allowance")

	# Attacking a member settles -20 once per victim per 60 online seconds.
	t.set_standing("forest", 0)
	var victim := first_visible_npc("forest")
	if t.has_method("clear_conflict"):
		t.clear_conflict("forest", victim)
	var victim_unit := unit(victim)
	var victim_like: int = liking_of(actor, "npc:" + victim)
	victim_unit.pursuit = 0
	s.combat.hit_enemy(victim_unit, 1.0, actor)
	check(t.standing("forest") == -20, "hitting a villager settles minus twenty standing")
	check(liking_of(actor, "npc:" + victim) == victim_like - 30, "an attacked villager loses thirty affinity")
	victim_unit.pursuit = 0
	s.combat.hit_enemy(victim_unit, 1.0, actor)
	check(t.standing("forest") == -20, "a second hit inside sixty seconds does not deduct again")
	s.combat.apply_skill_damage(victim_unit, 1.0, actor)
	check(t.standing("forest") == -20, "multi-hit skill damage inside the window does not deduct again")
	await drive(61)
	victim_unit.pursuit = 0
	s.combat.hit_enemy(victim_unit, 1.0, actor)
	check(t.standing("forest") == -40, "a new conflict after sixty online seconds settles again")

	# Killing settles -35 exactly once, even when the death callback repeats.
	t.set_standing("forest", 0)
	var doomed := first_visible_npc("forest")
	var doomed_unit := unit(doomed)
	doomed_unit.hp = 1.0
	doomed_unit.pursuit = 0
	s.combat.hit_enemy(doomed_unit, 5.0, actor)
	check(t.standing("forest") == -35, "killing a villager settles minus thirty-five standing")
	check(not t.register_death("forest", doomed, actor), "the same death cannot settle standing twice")
	check(t.standing("forest") == -35, "repeated death callbacks keep standing at minus thirty-five")

	# Memory keeps the victim event and a severe killing record.
	var records: Variant = callm(relation, ["memory_of"], [doomed])
	check(records is Array and (records as Array).any(func(e: Dictionary) -> bool: return str(e.get("event", "")) == "killed_villager"),
		"victim keeps the killing event in memory")
	check(not (callm(relation, ["last_severe"], [doomed]) as Dictionary).is_empty(), "a severe memory survives for the victim")
	var line: Variant = callm(relation, ["line_for"], [doomed])
	check(line is String and not (line as String).is_empty(), "memory produces an in-world line")

	# Kin of a killed villager lose forty affinity; witnesses lose ten.
	await fresh_game()
	actor = actor_id()
	give(actor, "bread", 30)
	var kin_a := "forest:1"
	var kin_b := "forest:2"
	t.romance.marriages[t.romance.pair("npc:" + kin_a, "npc:" + kin_b)] = {"a": "npc:" + kin_a, "b": "npc:" + kin_b, "house": ""}
	var kin_before: int = liking_of(actor, "npc:" + kin_a)
	var witness_before: int = liking_of(actor, "npc:forest:3")
	var killed_before: int = liking_of(actor, "npc:" + kin_b)
	t.register_death("forest", kin_b, actor, ["forest:3"])
	check(liking_of(actor, "npc:" + kin_b) == killed_before - 30, "the killed villager loses thirty affinity")
	check(liking_of(actor, "npc:" + kin_a) == kin_before - 40, "a spouse loses forty affinity after a killing")
	check(liking_of(actor, "npc:forest:3") == witness_before - 10, "a witness loses ten affinity after the killing")

	# Prompt throttling keeps at least ten online seconds between the same notice.
	callm(relation, ["remember"], ["forest:4", "attacked", actor, 1])
	check(not bool(callm(relation, ["can_prompt"], ["forest:4", "attacked"])), "a fresh notice is throttled immediately")
	await drive(11)
	check(bool(callm(relation, ["can_prompt"], ["forest:4", "attacked"])), "the same notice is allowed after ten online seconds")

	# Attacking the relic drives standing to -100 through the real structure attack entry.
	t.set_standing("forest", 20)
	var relic_body: Node = t.relics.visuals["forest"].body
	check(s.combat.hit_structure(relic_body, 10.0, actor), "relic structure attack reaches the real business entry")
	check(t.standing("forest") == -100, "attacking a tribe relic forces standing to minus one hundred")

	# Crossing the hostile threshold switches the next verdict to the new attitude.
	t.set_standing("forest", 25)
	check(t.attitude("forest") == "friendly" and not t.hostile("forest") and not t.alert("forest"),
		"crossing into friendly clears hostile and alert verdicts")
	t.set_standing("forest", -25)
	check(t.attitude("forest") == "alert" and t.alert("forest") and not t.hostile("forest"),
		"crossing into alert switches the verdict to alert without hostility")
	t.set_standing("forest", -60)
	check(t.attitude("forest") == "hostile" and t.hostile("forest"), "crossing into hostile switches the verdict to hostile")

# ---------------------------------------------------------------- C. guard behavior

func section_guards() -> void:
	await fresh_game()
	var actor := actor_id()
	var player: Node = s.world.active_resident
	var npc_id := first_visible_npc("forest")
	check(npc_id != "", "guards drive real forest NPCs")
	if npc_id == "":
		return
	check(callm(guards, ["snapshot_for"], [npc_id]) is Dictionary, "guards expose a snapshot per NPC")
	check(state_of(npc_id) in STATES, "NPC state uses the frozen state-name set")

	# Patrol routes are only built for guards with a patrol role; civilians live in place.
	var patrol_id := first_visible_npc("forest", "charger")
	if patrol_id == "":
		patrol_id = first_visible_npc("forest", "archer")
	check(patrol_id != "", "a patrolling guard role exists")
	await drive(1)
	var route: Array = field(callm(guards, ["npc", "snapshot_for"], [patrol_id]), "route", [])
	check(route.size() >= 3 and route.size() <= 5, "guard patrol uses three to five points")
	var route_ok := true
	for point: Variant in route:
		if not (point is Vector2) or s.world.navigation.find_path(point, point).is_empty():
			route_ok = false
	check(route_ok, "every patrol point is walkable by the real navigation service")

	# Neutral NPCs never attack without provocation while the player stays outside the relic zone.
	t.set_standing("forest", 0)
	player.position = t.centers.forest + Vector2(200, 60)
	s._sync_view()
	var life_before: float = s.vitals.ensure(actor).life
	await drive(3)
	check(is_equal_approx(s.vitals.ensure(actor).life, life_before), "normal approach by a neutral player is not attacked")
	check(not in_states(npc_id, ["engage", "attack", "prepare"]), "normal approach keeps the NPC out of combat states")

	# Use a nearby guard with an unobstructed ray, rather than a remote NPC behind buildings.
	npc_id=patrol_id
	unit(npc_id).position=t.relics.visuals["forest"].position+Vector2(28,32)
	player.position=t.relics.visuals["forest"].position+Vector2(4,32)
	await get_tree().physics_frame
	s._sync_view()
	await drive(1)
	var warned := bool(field(callm(guards, ["snapshot_for"], [npc_id]), "warned", false))
	check(in_states(npc_id, ["warn", "observe"]) or warned, "entering the relic zone produces a warning before combat")

	# After the grace period the guard drives the intruder away.
	await drive(5.5)
	check(in_states(npc_id, ["engage", "prepare", "attack", "search"]), "the guard drives an intruder away after the grace period")

	# Leaving the zone clears the warning.
	await fresh_game()
	actor = actor_id()
	player = s.world.active_resident
	npc_id = first_visible_npc("forest")
	player.position = t.relics.visuals["forest"].position + Vector2(0, 30)
	s._sync_view()
	await drive(1)
	player.position = t.centers.forest + Vector2(320, 120)
	s._sync_view()
	await drive(2)
	check(not bool(field(callm(guards, ["snapshot_for"], [npc_id]), "warned", false)), "leaving the relic zone clears the warning")

	# Trusted players are admitted into the zone.
	t.set_standing("forest", 60)
	player.position = t.relics.visuals["forest"].position + Vector2(0, 24)
	s._sync_view()
	await drive(1.5)
	check(not bool(field(callm(guards, ["snapshot_for"], [npc_id]), "warned", false)), "a trusted player is admitted into the relic zone")

	# A level-one player attack triggers an immediate answer plus nearby support.
	await fresh_game()
	actor = actor_id()
	player = s.world.active_resident
	s.magic.ensure(actor).level = 1
	var victim_id := first_visible_npc("forest")
	var victim := unit(victim_id)
	victim.position=acceptance_yard()
	unit("forest:16").position=victim.position+Vector2(20,20)
	unit("forest:12").position=victim.position+Vector2(0,-30)
	player.position = victim.position + Vector2(40, 0)
	s._sync_view()
	await get_tree().physics_frame
	victim.pursuit = 0
	s.combat.hit_enemy(victim, 1.0, actor)
	# The guard machine decides on its next tick, so give it one coarse tick before reading state.
	await drive(1)
	var answered := in_states(victim_id, ["engage", "prepare", "attack", "retreat"]) \
		or str(field(callm(guards, ["snapshot_for"], [victim_id]), "target_id", "")) != ""
	check(answered, "a level-one player attack triggers an immediate victim answer")
	await drive(2)
	var supported := false
	for id: String in t.population.members:
		if id == victim_id or str(t.population.members[id].tribe) != "forest":
			continue
		if state_of(id) in ["engage", "prepare", "attack"]:
			supported = true
	check(supported, "nearby companions support the attacked villager")

	# Hostile combat NPCs attack a visible player inside their effective range.
	await fresh_game()
	actor = actor_id()
	player = s.world.active_resident
	var hostile_id := first_visible_npc("barbarian", "charger")
	check(hostile_id != "", "a hostile charger exists")
	if hostile_id != "":
		var hostile := unit(hostile_id)
		hostile.position = t.centers.barbarian
		player.position = hostile.position + Vector2(40, 0)
		s._sync_view()
		var life: float = s.vitals.ensure(actor).life
		await drive(3)
		check(s.vitals.ensure(actor).life < life or in_states(hostile_id, ["attack", "prepare", "engage"]),
			"a hostile NPC attacks a visible target inside effective range")

	# A wall blocks line of sight, so no attack is issued through it.
	await fresh_game()
	actor = actor_id()
	player = s.world.active_resident
	hostile_id = first_visible_npc("barbarian", "charger")
	check(hostile_id != "", "a hostile charger exists for the line-of-sight check")
	if hostile_id != "":
		var hostile2 := unit(hostile_id)
		hostile2.position = t.centers.barbarian
		player.position = hostile2.position + Vector2(70, 0)
		s._sync_view()
		spawn_wall(hostile2.position + Vector2(35, 0), Vector2(16, 200))
		await get_tree().physics_frame
		var life2: float = s.vitals.ensure(actor).life
		await drive(2)
		check(is_equal_approx(s.vitals.ensure(actor).life, life2), "a wall blocks the attack through line of sight")

	# Lost sight only searches the last seen position instead of tracking through the wall.
	await fresh_game()
	actor = actor_id()
	player = s.world.active_resident
	npc_id = first_visible_npc("forest")
	var npc := unit(npc_id)
	player.position = npc.position + Vector2(60, 0)
	s._sync_view()
	await drive(2)
	var seen_at: Vector2 = player.position
	spawn_wall(npc.position + Vector2(30, 0), Vector2(16, 200))
	await get_tree().physics_frame
	player.position = npc.position + Vector2(220, 0)
	s._sync_view()
	await drive(1)
	var record: Variant = callm(guards, ["snapshot_for"], [npc_id])
	var lost_state := str(field(record, "state", ""))
	check(lost_state in ["search", "observe", "return", "patrol", "life"],
		"losing line of sight enters a search or disengage state")
	check(lost_state != "search" or field(record, "last_seen", Vector2.ZERO) is Vector2,
		"the search snapshot carries a last-seen position")
	var last: Vector2 = field(record, "last_seen", Vector2.ZERO)
	if lost_state == "search":
		check(last.distance_to(seen_at) < 80.0, "search remembers only the last seen position")
		check(last.distance_to(player.position) > 80.0, "the NPC does not track the hidden player through the wall")

	# Pursuit beyond its limit or timeout returns the NPC to its post.
	await fresh_game()
	actor = actor_id()
	player = s.world.active_resident
	npc_id = first_visible_npc("forest")
	npc = unit(npc_id)
	player.position = npc.position + Vector2(60, 0)
	s._sync_view()
	await drive(2)
	player.position = t.centers.forest + Vector2(900, 700)
	s._sync_view()
	await drive(21)
	check(in_states(npc_id, ["return", "patrol", "life"]), "a guard returns to its post after the pursuit limit")
	check(npc.position.distance_to(Vector2(t.centers.forest)) < 900.0, "the returning guard actually travels back toward its post")

	# Navigation crosses a real bridge and never walks through the river.
	var navigation = s.world.navigation
	var bridge_path: PackedVector2Array = navigation.find_path(Vector2(10, 900), Vector2(90, 900))
	check(not bridge_path.is_empty(), "navigation finds a path over the river bridge gap")
	check(navigation.find_path(Vector2(45, 840), Vector2(90, 840)).is_empty(), "navigation refuses to walk through river water")
	check(not blocked(Vector2(45, 900)), "the bridge gap is physically passable")

	# Low-health civilians retreat instead of holding the line.
	await fresh_game()
	actor = actor_id()
	player = s.world.active_resident
	var civil := first_visible_npc("forest", "civilian")
	if civil != "":
		var civil_unit := unit(civil)
		civil_unit.hp = maxf(1.0, civil_unit.max_hp * 0.2)
		civil_unit.refresh()
		player.position = civil_unit.position + Vector2(50, 0)
		s._sync_view()
		await drive(2)
		check(state_of(civil) in ["retreat", "search", "return", "life", "patrol"], "a low-health civilian disengages instead of brawling")

# ---------------------------------------------------------------- D. skills and chief magic

func section_skills() -> void:
	await fresh_game()
	var actor := actor_id()
	var chief: Node = s.combat.enemies.get("forest:chief")
	var chief_id := "forest_chief"
	check(chief != null, "the forest chief exists as a real unit")

	var warrior_id := first_visible_npc("forest", "charger")
	var archer_id := first_visible_npc("forest", "archer")
	check(warrior_id != "", "a forest charger exists for dash slash")
	check(archer_id != "", "a forest archer exists for suppression shot")

	# Warrior dash slash: preparation, bounded advance, collision-safe landing and cooldown.
	if warrior_id != "":
		var warrior := unit(warrior_id)
		warrior.position = t.centers.forest
		var before_at: Vector2 = warrior.position
		var used: Variant = callm(npc_skills, ["use"], [warrior, "dash_slash"])
		check(used == true, "dash slash can be used by a charger")
		check(float(callm(npc_skills, ["cooldown_left"], [warrior_id, "dash_slash"])) > 0.0, "dash slash starts its cooldown")
		await drive(1.0)
		check(warrior.position.distance_to(before_at) <= 42.0, "dash slash advances no more than forty world pixels")
		check(not blocked(warrior.position), "the dash lands on a collision-safe spot")

	# Archer suppression shot spends the archer's own arrow and only slows on a hit.
	if archer_id != "":
		var archer := unit(archer_id)
		var archer_owner := "npc:" + archer_id
		give(archer_owner, "arrow", 2)
		var player_arrows := count(actor, "arrow")
		archer.position = acceptance_yard()
		s.world.active_resident.position = archer.position + Vector2(30, 0)
		chief.position=archer.position+Vector2(0,-20)
		s._sync_view()
		await get_tree().physics_frame
		callm(npc_skills, ["use"], [archer, "suppress_shot"])
		check(count(archer_owner, "arrow") == 1, "suppression shot spends the archer's own arrow")
		check(count(actor, "arrow") == player_arrows, "suppression shot never spends the player's arrows")
		give(archer_owner, "arrow", 0)
		check(callm(npc_skills, ["can_use"], [archer, "suppress_shot"]) == false, "an archer without arrows cannot shoot")
		check(callm(npc_skills, ["use"], [archer, "suppress_shot"]) == false, "an archer without arrows does not fire")
		check(count(actor, "arrow") == player_arrows, "a refused shot still spends nothing")

	# The chief pays from its own mana pool; the player's mana never moves.
	if chief != null:
		var chief_stats: Dictionary = s.vitals.ensure(chief_id)
		var player_mana: int = int(s.vitals.ensure(actor).mana)
		chief_stats.mana = s.magic.max_mana(chief_id)
		var skill := "chief_wood_vine"
		var chief_used: Variant = callm(npc_skills, ["use"], [chief, skill])
		check(chief_used == true, "the wood chief can cast its first skill")
		check(int(s.vitals.ensure(chief_id).mana) < s.magic.max_mana(chief_id), "chief casting spends its own mana")
		check(int(s.vitals.ensure(actor).mana) == player_mana, "chief casting never spends player mana")
		check(float(callm(npc_skills, ["cooldown_left"], [chief_id, skill])) > 0.0, "chief casting starts its cooldown")
		s.vitals.ensure(chief_id).mana = 0
		check(callm(npc_skills, ["can_use"], [chief, skill]) == false, "a chief without mana cannot cast")
		check(callm(npc_skills, ["use"], [chief, skill]) == false, "a chief without mana does not cast")
		check(int(s.vitals.ensure(actor).mana) == player_mana, "a refused cast spends no player mana")

	# The explicit cast entry uses the actor's own pool and never redirects to the player.
	var player_mana_before: int = int(s.vitals.ensure(actor).mana)
	s.magic.skills.cast_for(chief_id, 5, chief.position)
	check(int(s.vitals.ensure(actor).mana) == player_mana_before, "cast_for never touches the player's mana")
	if s.magic.skills.cast_for("no_such_actor", 5, chief.position):
		check(false, "cast_for rejects an unknown actor instead of falling back to the player")
	else:
		check(int(s.vitals.ensure(actor).mana) == player_mana_before, "a failed cast_for never falls back to the player")

	# Recovery has one clock owner for player and NPC casters, including the last tick.
	await fresh_game()
	actor=actor_id()
	chief=s.combat.enemies.get("forest:chief")
	chief.hp=maxf(1.0,chief.max_hp-10.0); chief.refresh()
	s.vitals.ensure(chief_id).mana=40; chief.mana=40
	s.production.close(); s.inventory.close(); s.close_roster()
	check(s.magic.skills.cast_for(chief_id,4,chief.global_position),"chief casts its own shared recovery effect")
	var life_before: float=chief.hp
	s.magic.skills.advance(3.0)
	npc_skills.advance(3.0)
	check(is_equal_approx(chief.hp,life_before+1),"one recovery tick heals exactly one point, without double healing")
	s.magic.skills.advance(27.0)
	npc_skills.advance(27.0)
	check(is_equal_approx(chief.hp,minf(chief.max_hp,life_before+10)),"thirty seconds includes exactly ten recovery ticks")
	check(float(s.magic.skills.buffs[chief_id].regen)==0,"recovery expires after thirty online seconds")
	chief.hp=chief.max_hp; chief.refresh()

	# Parry reduces real incoming damage by thirty percent through the combat entry.
	if chief != null:
		var victim: Node = t.population.node("barbarian:12")
		var hp_before: float = float(victim.hp)
		s.combat.hit_enemy(victim, 3.0, actor)
		var plain: float = hp_before - float(victim.hp)
		callm(npc_skills, ["_parry"], [victim])
		hp_before = float(victim.hp)
		s.combat.hit_enemy(victim, 3.0, actor)
		var guarded: float = hp_before - float(victim.hp)
		check(plain > 0.0 and absf(guarded - plain * 0.7) < 0.2, "parry reduces real incoming damage by thirty percent")

# ---------------------------------------------------------------- E. persistence and migration

func section_persistence() -> void:
	await fresh_game()
	var actor := actor_id()
	give(actor, "bread", 30)
	var target := first_visible_npc("forest")
	do_gift(target)
	t.set_standing("barbarian", -30)
	var npc_id := first_visible_npc("forest")
	var victim := unit(npc_id)
	victim.pursuit = 0
	s.combat.hit_enemy(victim, 1.0, actor)

	var snapshot: Dictionary = t.export_state()
	var relation_state: Dictionary = field(snapshot, "relation", {})
	check(relation_state.has("standing"), "tribes export includes standing")
	check(relation_state.has("memory"), "tribes export includes memory")
	check(snapshot.has("guards"), "tribes export includes guard state")
	check(snapshot.has("npc_skills"), "tribes export includes skill cooldowns")

	var saved_standing: int = t.standing("forest")
	var saved_barbarian: int = t.standing("barbarian")
	var saved_left: int = t.gifting_left("forest")
	var saved_memory: Variant = callm(relation, ["memory_of"], [npc_id])
	t.restore(snapshot.duplicate(true))
	check(t.standing("forest") == saved_standing and t.standing("barbarian") == saved_barbarian, "restore keeps tribal standing")
	check(t.gifting_left("forest") == saved_left, "restore keeps the daily gift quota")
	check(JSON.stringify(callm(relation, ["memory_of"], [npc_id])) == JSON.stringify(saved_memory), "restore keeps NPC memory")

	# An old save without the new fields receives the documented defaults and nothing else.
	await fresh_game()
	actor = actor_id()
	var legacy_victim := first_visible_npc("forest")
	var legacy_unit := unit(legacy_victim)
	legacy_unit.hp = 3.0
	legacy_unit.refresh()
	var dead_start := first_visible_npc("barbarian")
	var dead_unit := unit(dead_start)
	dead_unit.hp = 0.0
	dead_unit.refresh()
	var archer := first_visible_npc("forest", "archer")
	var archer_arrows := count("npc:" + archer, "arrow")
	var legacy: Dictionary = t.export_state().duplicate(true)
	for key in ["relation", "guards", "npc_skills"]:
		legacy.erase(key)
	t.restore(legacy)
	check(t.standing("forest") == 0, "legacy save defaults forest standing to zero")
	check(t.standing("barbarian") == -50 and t.standing("yunye") == -50, "legacy save defaults barbarian and yunye to minus fifty")
	check((callm(relation, ["memory_of"], [legacy_victim]) as Array).is_empty(), "legacy save starts with empty memory")
	check(is_equal_approx(unit(legacy_victim).hp, 3.0), "legacy migration never heals an existing villager")
	check(unit(dead_start).hp <= 0.0, "legacy migration never revives a dead villager")
	check(count("npc:" + archer, "arrow") == archer_arrows, "legacy migration never refills arrows")

	# A disk save keeps standing, memory, quota and cooldowns across a restart.
	await fresh_game()
	actor = actor_id()
	give(actor, "bread", 30)
	target = first_visible_npc("forest")
	do_gift(target)
	t.set_standing("barbarian", -25)
	var saved_forest: int = t.standing("forest")
	var saved_quota: int = t.gifting_left("forest")
	var saved_lines := memory_signature(target)
	check(s.persistence.save_now(), "full disk state saves through the real persistence service")
	await reload_game()
	var after_lines := memory_signature(target)
	if after_lines != saved_lines:
		print("MEM_DIAG saved=", saved_lines, " after=", after_lines)
	check(t.standing("forest") == saved_forest and t.standing("barbarian") == -25, "restart keeps tribal standing")
	check(t.gifting_left("forest") == saved_quota, "restart keeps the daily gift quota")
	check(after_lines == saved_lines, "restart keeps NPC memory")

	# A failed save rolls the whole transaction back, so no standing or reward can be replayed.
	await fresh_game()
	actor = actor_id()
	give(actor, "bread", 5)
	target = first_visible_npc("forest")
	var standing_before: int = t.standing("forest")
	var quota_before: int = t.gifting_left("forest")
	var bread_before: int = count(actor, "bread")
	s.persistence.ready_to_save = false
	var failed: Variant = do_gift(target)
	s.persistence.ready_to_save = true
	check(failed == false, "a gift fails when the save cannot be written")
	check(t.standing("forest") == standing_before and t.gifting_left("forest") == quota_before, "a failed save rolls standing and quota back")
	check(count(actor, "bread") == bread_before, "a failed save returns the gifted bread")

# ---------------------------------------------------------------- F. pause and offline clock

func section_clock() -> void:
	# The unified Simulation clock is the only time source; drive it with real frames.
	s.simulation.set_process(true)
	s.simulation.process_mode = Node.PROCESS_MODE_PAUSABLE
	s.simulation.pending = 0.0
	get_tree().paused = false
	var start := float(t.now())
	await get_tree().create_timer(0.8).timeout
	var running := float(t.now()) - start
	check(running > 0.2, "the unified clock advances while the game is running")
	# Pausing the tree freezes cooldowns, patrol waits and search timers.
	get_tree().paused = true
	var frozen := float(t.now())
	await get_tree().create_timer(0.8, true).timeout
	check(is_equal_approx(float(t.now()), frozen), "a paused game never advances the tribal clock")
	# Resuming continues from where it stopped without one-shot catch-up.
	get_tree().paused = false
	var resumed := float(t.now())
	await get_tree().create_timer(0.8).timeout
	var after := float(t.now()) - resumed
	check(after > 0.2 and after < 1.6, "resuming continues the clock without replaying paused time")
	s.simulation.set_process(false)
	s.simulation.pending = 0.0

func acceptance_yard() -> Vector2:
	var circle := CircleShape2D.new(); circle.radius=48
	var query := PhysicsShapeQueryParameters2D.new(); query.shape=circle; query.collision_mask=1|2|4|8|16
	for y in range(-240,241,80):
		for x in range(-240,241,80):
			var at: Vector2=t.centers.forest+Vector2(x,y)
			query.transform=Transform2D(0,at)
			if at.distance_to(t.relics.visuals.forest.position)<110: continue
			if s.world.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(): return at
	return t.centers.forest+Vector2(200,200)
