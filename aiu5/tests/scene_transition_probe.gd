# Repeats real room/cave transfers with rendering and isolated save data, usable with original exported PCKs.
extends Node

var game: Node
var s: Node
var directory := ""
var transitions := 0
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func check_visuals(actor: Node) -> void:
	var passive: String = "buff:passive:" + str(actor.resident_id)
	if s.magic.ensure(actor.resident_id).unlocked.has("trunk_1"):
		var aura: Variant = s.magic.branches.visuals.get(passive)
		check(is_instance_valid(aura), "passive aura survives transfer")
		if is_instance_valid(aura):
			check(aura.get_parent() == actor, "passive aura follows its actor")
	for visual: Variant in s.magic.branches.visuals.values():
		check(is_instance_valid(visual), "no stale magic visual references")
		if is_instance_valid(visual): check(not s.world.streamer.entries.has(visual.get_instance_id()), "magic visual has one lifecycle owner")
	for record: Dictionary in s.resources.loaded.values():
		check(is_instance_valid(record.node), "resource node survives scene transfer")

func press_e() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_E; event.physical_keycode = KEY_E; event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)

func _ready() -> void:
	call_deferred("run")

func frames(n := 2) -> void:
	for i in range(n): await get_tree().process_frame

func lifecycle_edges() -> void:
	# A cast may still be visible when the last occupant leaves; its room-owned drawing is disposable.
	for room_id: String in ["kitchen", "mine"]:
		var actor: Node = s.world.active_resident
		var home: Dictionary = s.world.home_data(room_id)
		s.interiors.enter(actor, home); s._sync_view(); transitions += 1
		var key: String = s.magic.branches._area(actor.resident_id, "cast", actor.global_position, 0.8, Vector2(24,24), Vector2.DOWN)
		s.magic.branches._rebuild_visuals()
		await frames(2)
		s.interiors.leave(actor, s.world.objects, home.door+Vector2(0,8)); s._sync_view(); transitions += 1
		s.magic.branches._update_visuals()
		check(not s.magic.branches.visuals.has(key) or is_instance_valid(s.magic.branches.visuals[key]), "expired room drawing is never dereferenced")
		check_visuals(actor)
		await frames(2)
	# Keep a second occupant inside while switching control, then release the final empty room.
	var home: Dictionary = s.world.home_data("kitchen")
	var seats: Array[int] = []
	for i in range(s.world.controllable.size()):
		if not s.world.controllable[i].dead: seats.append(i)
	seats = seats.slice(0,2)
	for i: int in seats:
		s.select_resident(i)
		s.interiors.enter(s.world.active_resident,home); s._sync_view(); transitions += 1
		await frames(2)
	for i: int in seats:
		s.select_resident(i)
		check(s.world.active_resident.room_id=="kitchen", "control switches into an occupied room")
		s.interiors.leave(s.world.active_resident,s.world.objects,home.door+Vector2(0,8)); s._sync_view(); transitions += 1
		s.magic.branches._update_visuals(); check_visuals(s.world.active_resident)
		await frames(2)
	check(not s.interiors.rooms.has("kitchen"), "last occupant still releases the empty room")

func run() -> void:
	directory = OS.get_environment("AIU5_TRANSITION_DIR")
	if directory == "": get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	OS.set_environment("AIU5_STATE_PATH", directory+"/state.json")
	OS.set_environment("AIU5_PROFILE_PATH", directory+"/names.cfg")
	OS.set_environment("AIU5_WORLD_PROFILE", "starter_v2")
	game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	await frames(10)
	s = game.get_node("Session")
	s.persistence.set_process(false)
	if OS.get_environment("AIU5_TRANSITION_PASSIVE") == "true":
		for resident: Node in s.world.controllable:
			var record: Dictionary = s.magic.ensure(resident.resident_id)
			if not record.unlocked.has("trunk_1"): record.unlocked.append("trunk_1")
			if str(record.element) == "": record.element = "wood"
	var mode := OS.get_environment("AIU5_TRANSITION_MODE")
	var rounds := 40
	if OS.get_environment("AIU5_TRANSITION_ROUNDS") != "": rounds = int(OS.get_environment("AIU5_TRANSITION_ROUNDS"))
	for round in range(rounds):
		for room_id: String in ["kitchen", "blacksmith", "mine"]:
			var actor: Node = s.world.active_resident
			var home: Dictionary = s.world.home_data(room_id)
			actor.position = home.door + Vector2(0, 8)
			s._sync_view()
			await frames()
			print("TRANSITION_BEGIN round=", round, " room=", room_id, " outside_parent=", actor.get_parent())
			if mode == "input": await press_e()
			elif mode == "interact": s.interact()
			else: s.interiors.enter(actor, home)
			if room_id == "mine" and actor.room_id == "" and s.tribes.dialog_kind == "mine" and s.production.opened:
				s.tribes.perform("enter_mine")
			s._sync_view()
			transitions += 1
			await frames(3)
			if not s.interiors.rooms.has(room_id):
				push_error("Interaction did not enter " + room_id + " nearest=" + str(s.nearest))
				get_tree().quit(2); return
			if actor.room_id != room_id or actor.get_parent() != s.interiors.rooms[room_id].objects:
				failures.append("enter " + room_id)
			var room: Node = s.interiors.rooms[room_id]
			actor.position = room.exit_point()
			print("TRANSITION_EXIT round=", round, " room=", room_id)
			if mode == "input": await press_e()
			elif mode == "interact": s.interact()
			else: s.interiors.leave(actor, s.world.objects, home.door + Vector2(0, 8))
			s._sync_view()
			transitions += 1
			await frames(3)
			if actor.room_id != "" or actor.get_parent() != s.world.objects:
				failures.append("leave " + room_id)
			s.magic.branches._update_visuals()
			check_visuals(actor)
		if round % 4 == 0:
			var chosen: int = floori(round / 4.0) % int(s.world.controllable.size())
			var previous: Node = s.world.active_resident
			s.select_resident(chosen)
			if previous != s.world.active_resident: previous.position = Vector2(322 + chosen * 16, 224)
			await frames()
	await lifecycle_edges()
	var result := {"version": ProjectSettings.get_setting("application/config/version"), "transitions": transitions,
		"rounds": rounds, "checks": checks, "display": DisplayServer.get_name(), "failures": failures}
	var file := FileAccess.open(directory+"/result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  ")); file.close()
	print("SCENE_TRANSITION_RESULT ", JSON.stringify(result))
	if failures.is_empty(): print("SCENE_TRANSITION_OK transitions=", transitions)
	get_tree().quit(0 if failures.is_empty() else 1)
