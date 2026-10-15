# Exercises paid feeding, sex-aware pairing, online age/cooldowns and complete herd persistence.
extends SceneTree

const PATH := "res://.runtime/test-livestock.json"
var failures: Array[String] = []
var game: Node
var world: Node2D
var herd: Node
var inventory: Node
var persistence: Node
var session: Node

func _initialize() -> void:
	OS.set_environment("AIU5_WORLD_PROFILE","expanded")
	OS.set_environment("AIU5_STATE_PATH", PATH)
	OS.set_environment("AIU5_PROFILE_PATH", "res://.runtime/test-livestock-names.cfg")
	for suffix in ["", ".altar"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
	create_timer(90).timeout.connect(func() -> void: push_error("LIVESTOCK_TIMEOUT"); quit(2))
	call_deferred("run_checks")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error("CHECK FAILED: " + label)

func frames(count := 2) -> void:
	for i in range(count): await physics_frame
	await process_frame

func key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)

func load_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	world = game.get_node("World")
	herd = game.get_node("Livestock")
	inventory = game.get_node("Inventory")
	persistence = game.get_node("Persistence")
	session = game.get_node("Session")
	for id in ["Livestock", "Vitals", "Homestead", "Persistence"]: game.get_node(id).set_process(false)
	session.simulation.set_process(false)
	session.simulation.reset()
	for x in range(-1,4):
		for y in range(-1,4): session.wildlife.generated[str(x)+":"+str(y)]=true
	for actor in world.residents: actor.set_physics_process(false)
	for animal in herd.animals: animal.set_physics_process(false)
	await frames()

func count_item(item: String) -> int:
	var count := 0
	for slot: Dictionary in inventory.ensure_bag("ali"):
		if slot.get("item", "") == item: count += int(slot.count)
	return count

func feed(id: String, grain := "wheat") -> bool:
	var animal: CharacterBody2D = herd.find_animal(id)
	world.active_resident.position = animal.position + Vector2(0, 13)
	return herd.feed_animal(world.active_resident, id, grain)

func run_checks() -> void:
	await load_game()
	check(world.pigs.size() == 3 and world.cows.size() == 2, "initial herd preserves three pigs and adds one cattle pair")
	check(herd.find_animal("pig:1").sex == "male" and herd.find_animal("pig:2").sex == "female" and herd.find_animal("pig:3").sex == "female", "old pigs receive stable male/female identities")
	check(herd.find_animal("cow:1").sex == "male" and herd.find_animal("cow:2").sex == "female", "cattle pair has opposite sexes")
	check(not world.navigation.find_path(Vector2(322, 224), Vector2(108, 475)).is_empty(), "barn entrance remains reachable")
	check(game.get_node("Grounds").land_error(Rect2(80, 440, 16, 16), world.active_resident) != "", "tilling and deployment protect cattle shelter")
	check(not feed("cow:1") and not herd.find_animal("cow:1").fed, "seeds cannot substitute for harvested grain")
	inventory.exchange("ali", {}, {"wheat": 30, "rice": 20})
	world.active_resident.position = herd.find_animal("cow:1").position + Vector2(0, 12)
	await key(KEY_E)
	check(session.production.opened and session.tribes.dialog_kind=="animal","E opens animal feeding choices")
	check(session.production.perform("feed:wheat"),"feeding choice uses the selected wheat")
	session.production.close()
	check(herd.find_animal("cow:1").fed and count_item("wheat") == 29 and world.cows.size() == 2, "real E feeds exactly one grain without a partner birth")
	check(not feed("cow:1") and count_item("wheat") == 29, "already-fed adult cannot waste food")
	check(feed("pig:2", "rice") and world.cows.size() == 2 and world.pigs.size() == 3, "different species never pair")
	check(feed("pig:3", "rice") and world.pigs.size() == 3, "two females never pair")
	check(feed("cow:2") and world.cows.size() == 3 and count_item("wheat") == 28, "feeding adult cattle pair produces exactly one calf")
	var calf: CharacterBody2D = herd.find_animal("cow:3")
	calf.set_physics_process(false)
	check(calf.growth == 0 and not calf.adult() and calf.sprite.scale.x < 1, "newborn starts at zero with smaller sprite")
	check(herd.find_animal("cow:1").cooldown == 300 and herd.find_animal("cow:2").cooldown == 300, "both parents enter five-minute cooldown")
	check(not herd.find_animal("cow:1").fed and not herd.find_animal("cow:2").fed, "birth consumes both parents' fed flags")
	check(feed("cow:1") and feed("cow:2") and world.cows.size() == 3, "feeding during cooldown cannot immediately reproduce")
	herd.advance(299.9)
	check(not calf.adult() and world.cows.size() == 3, "neither growth nor reproduction happens before five minutes")
	herd.advance(0.1)
	check(calf.adult() and world.cows.size() == 4, "at five minutes calf matures and refed parents breed again")
	var younger: CharacterBody2D = herd.find_animal("cow:4")
	younger.set_physics_process(false)
	check(younger.growth == 0, "second calf does not inherit elapsed time before birth")
	for i in range(4): check(feed("cow:4", "rice"), "juvenile accepts each one-grain growth boost")
	check(younger.growth == 240 and not younger.adult(), "four feedings advance exactly four minutes")
	check(feed("cow:4", "rice") and younger.adult() and not younger.fed, "fifth feed matures calf without counting as adult breeding feed")
	check(count_item("rice") == 13, "five growth feeds plus two female-pig feeds cost seven grains")
	# The bag use action honors the selected grain rather than always preferring wheat.
	world.active_resident.position = herd.find_animal("pig:1").position + Vector2(0, 12)
	await key(KEY_B)
	for i in range(21):
		if inventory.ensure_bag("ali")[i].get("item", "") == "rice":
			inventory.slot_clicked("bag", i)
			break
	game.get_node("Belongings").use_button.pressed.emit()
	await frames()
	check(world.pigs.size() == 4 and count_item("rice") == 12, "real bag use feeds selected rice and produces a piglet")
	check(not inventory.opened, "using grain closes bag for map interaction")
	var piglet: CharacterBody2D = herd.find_animal("pig:4")
	piglet.set_physics_process(false)
	herd.advance(17.25)
	check(piglet.growth == 17.25 and herd.find_animal("pig:1").cooldown == 282.75, "partial growth and cooldown retain fractional online seconds")
	check(persistence.save_now(), "herd autosave succeeds")
	var saved: Dictionary = herd.export_state()
	game.queue_free()
	await frames(3)
	await load_game()
	if herd.export_state()!=saved:
		FileAccess.open(ProjectSettings.globalize_path(PATH)+'.before',FileAccess.WRITE).store_string(JSON.stringify(saved))
		FileAccess.open(ProjectSettings.globalize_path(PATH)+'.after',FileAccess.WRITE).store_string(JSON.stringify(herd.export_state()))
	check(JSON.parse_string(JSON.stringify(herd.export_state())) == JSON.parse_string(JSON.stringify(saved)), "relaunch restores exact herd identities, sex, age, cooldown, feeding and positions without offline progress")
	check(persistence.save_checkpoint(false), "altar saves expanded herd")
	herd.find_animal("cow:1").cooldown = 0
	herd.find_animal("cow:2").cooldown = 0
	feed("cow:1")
	feed("cow:2")
	check(world.cows.size() == 5, "a post-checkpoint birth expands herd")
	check(persistence.restore_checkpoint() and world.cows.size() == 4 and herd.find_animal("cow:5") == null, "checkpoint rollback removes later births and resets stable ID counter")
	herd.restore({}, [{"position": [410, 248], "target": [420, 248], "feeding": 2.5, "pause": 1.2}])
	check(world.pigs.size() == 1 and world.cows.size() == 0 and herd.find_animal("pig:1").position == Vector2(410, 248), "legacy migration preserves actual pigs and never invents missing cattle")
	herd.restore({})
	check(world.pigs.size() == 0 and world.cows.size() == 0, "empty legacy records never regenerate animals")
	game.queue_free()
	await frames(3)
	if failures.is_empty(): print("LIVESTOCK_SMOKE_OK")
	else: print("LIVESTOCK_FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
