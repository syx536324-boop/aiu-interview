# Verifies that the northern forest loads real resources and preserves collection across streaming and restart.
extends SceneTree
var game: Node
var s: Node
var directory := ""
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	directory=OS.get_environment("AIU5_PROBE_DIRECTORY")
	assert(directory!="")
	OS.set_environment("AIU5_STATE_PATH",directory+"/state.json")
	OS.set_environment("AIU5_PROFILE_PATH",directory+"/names.cfg")
	OS.set_environment("AIU5_WORLD_SEED","7319")
	create_timer(60,true).timeout.connect(func() -> void: quit(2))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func frames(n := 120) -> void:
	for i in range(n): await process_frame
func load_game() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	s=game.get_node("Session")
	s.simulation.set_process(false); s.simulation.reset(); s.persistence.set_process(false)
	for actor in s.world.residents: actor.set_physics_process(false)
	for enemy in s.combat.enemies.values(): enemy.set_physics_process(false)
	s.world.active_resident.position=Vector2(-1000,-800)
	s._sync_view(); game.get_node("Streaming").focus(true)
	await frames()
func run() -> void:
	await load_game()
	check(s.forest.loaded.size()>50,"north woodland contains streamed resource nodes")
	var kinds := {}
	var chosen := ""
	var seed_before: Array=s.forest.generate(Vector2i(-4,-4))
	for node in s.forest.loaded.values():
		kinds[node.record.kind]=true
		check(node.record.cell.y<0,"northern node comes from a northern chunk")
		if chosen=="" and node.record.kind=="goji": chosen=node.record.id
	for kind in ["tree","mulberry","ginseng","reishi","goji","grass"]: check(kinds.has(kind),"north has same resource mix "+kind)
	check(chosen!="","northern goji available for actual collection")
	if chosen!="":
		s.world.active_resident.position=s.forest.loaded[chosen].record.at
		check(s.forest.gather(chosen),"real northern herb collected")
		check(s.forest.collected.has(chosen) and s.inventory.has_item("ali","goji"),"collection state and inventory committed")
		check(s.persistence.save_now(),"northern collection saved")
		game.queue_free(); await frames(3)
		await load_game()
		check(s.forest.collected.has(chosen),"northern depletion survives real restart")
		check(s.forest.generate(Vector2i(-4,-4))==seed_before,"seeded IDs and positions unchanged")
	game.queue_free(); await frames(3)
	if failures.is_empty(): print("NORTH_FOREST_OK checks=",checks); quit(0)
	else: print(failures); quit(1)
