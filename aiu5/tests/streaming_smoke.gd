# Verifies independent full-map pause, bounded chunk work, parked state, lazy deadlines and persistence.
extends SceneTree

const PATH := "res://.runtime/test-streaming.json"
const Navigation := preload("res://features/village/navigation.gd")
var game: Node
var world: Node2D
var session: Node
var stream: Node
var farm: Node
var herd: Node
var persistence: Node
var failures: Array[String] = []

func _initialize() -> void:
	OS.set_environment("AIU5_STATE_PATH", PATH)
	OS.set_environment("AIU5_PROFILE_PATH", "res://.runtime/test-streaming-names.cfg")
	for suffix in ["", ".altar"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
	create_timer(50).timeout.connect(func() -> void: push_error("STREAMING_TIMEOUT"); quit(2))
	call_deferred("run_checks")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error("CHECK FAILED: " + label)

func frames(count := 2) -> void:
	for i in range(count): await process_frame

func key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(2)

func load_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	world = game.get_node("World")
	session = game.get_node("Session")
	stream = game.get_node("Streaming")
	farm = game.get_node("Homestead")
	herd = game.get_node("Livestock")
	persistence = game.get_node("Persistence")
	for actor in world.residents: actor.set_physics_process(false)
	for animal in herd.animals: animal.set_physics_process(false)
	await frames(3)

func run_checks() -> void:
	await load_game()
	var actor: CharacterBody2D = world.active_resident
	check(world.terrain.chunks.size() < 64, "startup never prepares the entire world")
	for i in range(20):
		await frames(1)
		check(world.terrain.built_last_frame <= 2, "terrain preparation is limited to two patches per frame")
	var initial_patches: int = world.terrain.chunks.size()
	var outside_ore: Node2D = game.get_node("Mining").surface["surface:10"]
	check(not outside_ore.is_inside_tree(), "distant ore has no active rendering or physics scene")
	var far_at: Vector2 = outside_ore.position
	actor.position = far_at + Vector2(0, 14)
	stream.focus(true)
	check(outside_ore.is_inside_tree() and world.terrain.center == Vector2i(6, 5), "teleport prepares the viewport and activates the new neighborhood")
	outside_ore.hits = 1
	outside_ore.refresh()
	game.get_node("Mining").progress[outside_ore.resource_id] = 1
	var full_rebuilds: int = world.navigation.full_rebuilds
	var bench: Node2D = game.get_node("Grounds").add_fixture({"id": "outdoors:stream-test", "kind": "workbench", "at": [1740, 1050], "size": [30, 24], "variant": 0, "orientation": 0})
	check(world.navigation.full_rebuilds == full_rebuilds and world.navigation.changed_cells < 100, "adding a workbench changes local grid cells without rebuilding sixty thousand cells")
	actor.position = Vector2(322, 224)
	stream.focus(true)
	check(not outside_ore.is_inside_tree() and not bench.is_inside_tree(), "leaving a region removes its ore and furniture from the scene tree")
	check(world.logical_obstacles().has(bench.collision_bounds()), "parked furniture remains an obstacle in the logical world")
	await key(KEY_M)
	check(paused and session.overview and stream.overview.visible and not world.visible, "real M input opens the independent map and pauses gameplay")
	check(world.camera.zoom == Vector2(2, 2) and stream.overview.texture.get_size() == Vector2(432, 288), "full map uses a cached texture without changing the following camera")
	var frozen: String = JSON.stringify(persistence.capture_session())
	var frozen_position: Vector2 = actor.position
	var patch_count: int = world.terrain.chunks.size()
	await create_timer(0.7, true).timeout
	for code in [KEY_E, KEY_Q, KEY_G, KEY_TAB, KEY_B, KEY_3]: await key(code)
	check(JSON.stringify(persistence.capture_session()) == frozen and actor.position == frozen_position, "map freezes actors, all timers and gameplay actions")
	check(world.terrain.chunks.size() == patch_count, "map does not stream distant patches while paused")
	var builds: int = stream.overview.build_count
	await key(KEY_ESCAPE)
	check(not paused and not session.overview and world.visible, "Escape resumes through the always-responsive map controls")
	await key(KEY_M)
	check(stream.overview.build_count == builds, "reopening unchanged full map reuses the static texture")
	await key(KEY_M)
	var online: float = game.get_node("Vitals").online
	await create_timer(0.6).timeout
	session.simulation.flush()
	check(game.get_node("Vitals").online - online < 1.0, "closing map never catches up the time spent paused")
	# Explicit time advancement keeps far growth/cooldown behavior deterministic.
	session.simulation.set_process(false)
	session.simulation.flush()
	farm.plots = [{"x": 218.0, "y": 230.0, "w": 80.0, "h": 48.0, "age": 0.0, "dry": false, "crop": "wheat", "growth": 0.0}]
	farm.plot_stamps.clear()
	farm.refresh()
	var baby: CharacterBody2D = herd._spawn("cow:99", "cow", "female", 0, Vector2(110, 460))
	herd.next_ids.cow = 100
	herd.settle()
	actor.position = far_at + Vector2(0, 14)
	stream.focus(true)
	check(not baby.is_inside_tree(), "far juvenile is parked with no moving animal scene")
	farm.elapse(119.5)
	herd.elapse(119.5)
	check(farm.plots[0].growth == 0 and baby.growth == 0, "far progress is kept lazily between deadlines")
	farm.elapse(0.5)
	check(farm.plots[0].stage == 2 and is_equal_approx(farm.plots[0].growth, 120), "far crop stage deadline settles without loading its region")
	herd.elapse(180.5)
	check(baby.adult() and not baby.is_inside_tree(), "far juvenile matures at 300 seconds without spawning its scene")
	farm.elapse(7360)
	check(farm.plots[0].dry and farm.plots[0].crop == "dead", "far drought still kills crops at the online deadline")
	check(persistence.save_now(), "save records all active and parked state")
	var saved: Dictionary = persistence.capture_session()
	game.queue_free()
	await frames(3)
	await load_game()
	check(game.get_node("Mining").progress.get("surface:10") == 1, "restart retains ore progress from a previously unloaded region")
	check(game.get_node("Grounds").fixtures.any(func(f: Node2D) -> bool: return f.fixture_id == "outdoors:stream-test"), "restart retains parked outdoor furniture")
	check(herd.find_animal("cow:99").adult() and farm.plots[0].dry, "restart retains far animal and crop outcomes")
	check(is_equal_approx(game.get_node("Vitals").online, float(saved.vitals.online)), "restart preserves online time without offline catchup")
	# Reference counts protect overlapping blockers when only one is removed.
	var nav := Navigation.new()
	var first := Rect2(40, 40, 16, 16)
	var second := Rect2(48, 40, 16, 16)
	nav.rebuild([first, second], Vector2(2400, 1600))
	nav.rebuild([second], Vector2(2400, 1600))
	check(nav.full_rebuilds == 1 and nav.grid.is_point_solid(Vector2i(6, 6)), "incremental navigation preserves overlapping obstacle coverage")
	check(initial_patches <= 25, "initial preload is bounded to a five by five neighborhood")
	game.queue_free()
	await frames(3)
	if failures.is_empty(): print("STREAMING_SMOKE_OK")
	else: print("STREAMING_SMOKE_FAILED: ", failures)
	quit(0 if failures.is_empty() else 1)
