# Samples rendered frame counters and long frames with isolated state, and saves visual verification images.
extends SceneTree

var directory := ""
var game: Node
var world: Node2D
var session: Node
var results: Array = []

func _initialize() -> void:
	directory = OS.get_environment("AIU5_PROBE_DIRECTORY")
	if directory == "": directory = ProjectSettings.globalize_path("res://.runtime/performance")
	directory = directory.trim_suffix("/").trim_suffix("\\") + "/"
	DirAccess.make_dir_recursive_absolute(directory)
	OS.set_environment("AIU5_STATE_PATH", directory + "gpu-save.json")
	OS.set_environment("AIU5_WORLD_PROFILE","starter_v2")
	OS.set_environment("AIU5_PROFILE_PATH", directory + "gpu-names.cfg")
	for suffix in ["", ".altar"]: DirAccess.remove_absolute(directory + "gpu-save.json" + suffix)
	create_timer(90, true).timeout.connect(func() -> void: push_error("PERFORMANCE_PROBE_TIMEOUT"); quit(2))
	call_deferred("run")

func percentile(values: Array, fraction: float) -> float:
	var ordered := values.duplicate()
	ordered.sort()
	return ordered[clampi(ceili(ordered.size() * fraction) - 1, 0, ordered.size() - 1)]

func sample(label: String) -> void:
	for i in range(45): await process_frame
	var times: Array = []
	var calls: Array = []
	var objects: Array = []
	var intervals: Array = []
	var previous := Time.get_ticks_usec()
	for i in range(120):
		await process_frame
		var now := Time.get_ticks_usec()
		intervals.append((now - previous) / 1000.0)
		previous = now
		times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000)
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var row := {"mode": label, "process_median_ms": percentile(times, 0.5), "frame_interval_median_ms": percentile(intervals, 0.5),
		"frame_interval_p95_ms": percentile(intervals, 0.95), "frame_interval_p99_ms": percentile(intervals, 0.99), "frame_interval_max_ms": intervals.max(),
		"draw_calls_median": percentile(calls, 0.5), "render_objects_median": percentile(objects, 0.5), "terrain_chunks": world.terrain.chunks.size()}
	results.append(row)
	row.resource_chunks = game.get_node("WorldResources").descriptors.size()
	row.resource_nodes = game.get_node("WorldResources").loaded.size()
	row.forest_nodes = game.get_node("Forest").loaded.size()
	print(JSON.stringify(row))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory + "optimized-" + label + ".png")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	world = game.get_node("World")
	session = game.get_node("Session")
	game.get_node("Persistence").set_process(false)
	await sample("normal")
	session.overview = true
	world.set_overview(true)
	session.refresh_interface()
	await sample("overview")
	session.overview = false
	world.set_overview(false)
	session.refresh_interface()
	game.get_node("Interiors").enter(world.active_resident, world.home_data("blacksmith"))
	session._sync_view()
	await sample("interior")
	game.get_node("Interiors").leave(world.active_resident, world.objects, Vector2(322, 224))
	session._sync_view()
	world.active_resident.position = Vector2(1900, 1070)
	game.get_node("Streaming").focus(true)
	await sample("east")
	world.active_resident.position = Vector2(-1000, 800)
	game.get_node("Streaming").focus(true)
	await sample("forest")
	for place: Dictionary in [{"name":"north_forest","at":Vector2(-1000,-800)},{"name":"plateau","at":Vector2(1100,-850)},{"name":"mountains","at":Vector2(3300,-800)}]:
		world.active_resident.position = place.at
		session._sync_view()
		game.get_node("Streaming").focus(true)
		await sample(place.name)
	world.active_resident.position=Vector2(-1650,2500)
	session._sync_view()
	await sample("southern_forest")
	var forest_crossing: Array = []
	var forest_previous := Time.get_ticks_usec()
	for i in range(180):
		world.active_resident.position = Vector2(-2200 + i * 10, 900)
		await process_frame
		var forest_now := Time.get_ticks_usec()
		forest_crossing.append((forest_now-forest_previous)/1000.0)
		forest_previous=forest_now
	results.append({"mode":"forest_cross_chunk_sweep","p95_ms":percentile(forest_crossing,0.95),"p99_ms":percentile(forest_crossing,0.99),"max_ms":forest_crossing.max(),"forest_nodes":game.get_node("Forest").loaded.size()})
	var crossing: Array = []
	var previous := Time.get_ticks_usec()
	# Camera follows a controlled sweep across chunk boundaries, with no player save involved.
	for i in range(180):
		world.active_resident.position = Vector2(300 + i * 8, 900)
		await process_frame
		var now := Time.get_ticks_usec()
		crossing.append((now - previous) / 1000.0)
		previous = now
	results.append({"mode": "cross_chunk_sweep", "p95_ms": percentile(crossing, 0.95), "p99_ms": percentile(crossing, 0.99), "max_ms": crossing.max()})
	var file := FileAccess.open(directory + "optimized-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
	print("OPTIMIZED_PERFORMANCE_PROBE_OK")
	quit()
