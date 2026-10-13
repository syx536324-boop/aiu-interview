# Verifies the cloud ladder opens the plateau cliff, survives a reload and is built at the bench.
extends SceneTree
var failures: Array[String] = []
var game: Node
var s: Node
var path := ""
func _initialize() -> void:
	path = "res://.runtime/ladder-"+str(Time.get_ticks_usec())+"/state.json"
	OS.set_environment("AIU5_STATE_PATH", path)
	OS.set_environment("AIU5_PROFILE_PATH", path+".names")
	create_timer(40, true).timeout.connect(func() -> void: quit(2))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func frames(n := 3) -> void:
	for i in range(n): await process_frame
func load_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	s = game.get_node("Session")
	s.simulation.set_process(false)
	s.simulation.reset()
	s.persistence.set_process(false)
	for actor in s.world.residents: actor.set_physics_process(false)
	await frames()
func run() -> void:
	await load_game()
	var world: Node2D = s.world
	var layout := load("res://features/village/layout.gd")
	# Exploration fog: loaded chunks are lit for thirty seconds, the home village is always lit.
	check(world.streamer.overview.lit.size() > 0, "loaded chunks are recorded as explored")
	check(layout.HOME_LIT.has_point(Vector2(322, 224)), "home village area is always lit")
	check(not world.streamer.overview.lit.has(Vector2i(7, 7)), "distant unvisited chunks stay dark")
	# The plateau occupies the north-east quadrant and its cliff starts solid.
	check(layout.PLATEAU.get_area() == 2400.0 * 1600.0 and world.cliff_bodies.size() > 0, "plateau and segmented cliff exist")
	var mid := int(world.cliff_bodies.size() / 2)
	check(world.cliff_bodies[mid].collision_layer != 0, "cliff blocks the plateau before any ladder")
	# The western roundabout must not reach the highland either.
	var walker: CharacterBody2D = world.active_resident
	walker.global_position = Vector2(-100, 60)
	await frames(2)
	for i in range(260):
		walker.velocity = Vector2(0, -56); walker.move_and_slide(); await physics_frame
	for i in range(400):
		walker.velocity = Vector2(56, 0); walker.move_and_slide(); await physics_frame
	check(not layout.PLATEAU.has_point(walker.global_position), "the plateau is sealed against the western roundabout")
	check(not world.haze.visited and is_equal_approx(world.haze.range_scale(), 1.0), "highlands start hazed without shortening desert reach")
	# A bench plus 100 wood builds the cloud ladder at the character's x.
	var bench: Node2D = s.grounds.add_fixture({"id":"outdoors:ladder-bench","kind":"building_bench","at":[1060,760],"size":[96,80],"variant":0,"orientation":0})
	s.world.active_resident.position = bench.visual_bounds().position + Vector2(48, 60)
	s.inventory.exchange("ali", {}, {"wood":100})
	s.production.open_near()
	check(s.production.opened, "building bench opens")
	check(s.production.perform("cloud_ladder"), "cloud ladder is built from the bench for 100 wood")
	check(not s.inventory.has_item("ali","wood"), "cloud ladder consumes the requested wood")
	check(s.grounds.fixtures.has(bench), "building the ladder keeps the bench")
	check(world.cliff_open.size() >= 1, "ladder opens a gap in the cliff")
	var opened := 0
	for key in world.cliff_open: opened += 1
	check(opened == 3, "ladder opens three cliff segments")
	var gap := 0
	for key in world.cliff_open: gap += int(world.cliff_bodies[key].collision_layer == 0)
	check(gap == opened, "opened segments stop blocking")
	# Only after the ladder exists can the player actually walk up, which clears the haze rule.
	walker.global_position = Vector2(1108, 40)
	await frames(2)
	for i in range(200):
		walker.velocity = Vector2(0, -56); walker.move_and_slide(); await physics_frame
	check(layout.PLATEAU.has_point(walker.global_position), "walked up through a cloud ladder gap onto the plateau")
	check(world.haze.visited and is_equal_approx(world.haze.range_scale(), 0.7), "highland haze shortens ranged reach once reached")
	# The saved building record restores the same gap in a fresh scene.
	s.production.close()
	check(s.persistence.save_now(), "ladder is saved as a building record")
	game.queue_free(); await frames(3)
	await load_game()
	check(s.world.cliff_open.size() == opened, "reload restores the ladder gap")
	check(s.production.opened == false and s.construction.records.size() == 1, "reload keeps exactly one constructed ladder")
	game.queue_free(); await frames(2)
	if failures.is_empty(): print("LADDER_SMOKE_OK checks complete")
	else: print(failures)
	quit(0 if failures.is_empty() else 1)
