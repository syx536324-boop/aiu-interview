# Captures the united game's cliff geometry with genuine GPU rendering and an isolated save.
extends Node
var game: Node
var s: Node
var directory := ""
var state_path := ""
var failures: Array[String]=[]
var checks := 0
var records: Array[Dictionary]=[]

func _enter_tree() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	directory=OS.get_environment("AIU5_INTEGRATION_RESULTS")
	assert(directory!="" and directory.is_absolute_path())
	assert(DirAccess.make_dir_recursive_absolute(directory)==OK)
	state_path=directory.path_join("cliff-state-"+str(Time.get_ticks_usec())+".json")
	OS.set_environment("AIU5_STATE_PATH",state_path)
	OS.set_environment("AIU5_PROFILE_PATH",state_path+".names")
	OS.set_environment("AIU5_WORLD_PROFILE","starter_v2")
	OS.set_environment("AIU5_WORLD_SEED","92040")
	get_tree().create_timer(40,true).timeout.connect(func() -> void: push_error("CLIFF_VISUAL_TIMEOUT"); get_tree().quit(2))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)

func frames(n := 5) -> void:
	for i in range(n): await get_tree().process_frame

func set_location(at: Vector2, visited: bool) -> void:
	s.world.active_resident.position=at
	s.world.haze.visited=visited
	s._sync_view()
	s.world.streamer.focus(true)
	s.world.camera.force_update_scroll()
	s.refresh_interface()
	await frames(8)
	check(s.world.active_resident.position==at,"renderer fixture uses requested location "+str(at))

func screenshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image=get_viewport().get_texture().get_image()
	check(image.save_png(directory.path_join(name))==OK,"save "+name)
	records.append({"file":name,"actor":[s.world.active_resident.position.x,s.world.active_resident.position.y],"visited":s.world.haze.visited,"on_highland":s.world.haze.on_highland(),"range_scale":s.world.haze.range_scale(),"cliff_open":s.world.cliff_open.keys(),"ridge_open":s.world.ridge_open.keys(),"viewport":[image.get_width(),image.get_height()]})

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.process_mode=Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(game)
	s=game.get_node("Session")
	check(s.inventory.path==state_path,"visual probe only uses isolated inventory path")
	check(s.world.get_node_or_null("CliffVisual")!=null,"composed game includes exposed-rock renderer")
	s.simulation.set_process(false); s.simulation.reset()
	s.persistence.set_process(false)
	s.onboarding.restore({})
	s.day_night.elapsed=240.0; s.day_night._refresh()
	for actor: Node in s.world.residents: actor.set_physics_process(false)
	for id: String in s.tribes.population.members:
		var npc: Node=s.tribes.population.node(id)
		if is_instance_valid(npc): npc.set_physics_process(false)
	for animal: Node in s.livestock.animals: animal.set_physics_process(false)
	await frames()
	await set_location(Vector2(400,8),false)
	check(not s.world.haze.visited and not s.world.haze.on_highland(),"desert approach keeps pre-ascent haze")
	check(is_equal_approx(s.world.haze.PRE_VISIT_ALPHA,0.9),"pre-ascent haze stays at confirmed ninety percent")
	await screenshot("cliff-01-before-ascent.png")
	await set_location(Vector2(400,-90),true)
	check(s.world.haze.visited and s.world.haze.on_highland() and is_equal_approx(s.world.haze.range_scale(),0.7),"highland view retains confirmed haze and range scaling")
	await screenshot("cliff-02-after-ascent.png")

	# Use the actual paid construction entry point to open the cloud-ladder pass.
	await set_location(Vector2(400,48),true)
	s.inventory.exchange("ali",{}, {"wood":100})
	var bench: Node2D=s.grounds.add_fixture({"id":"outdoors:cliff-visual-bench","kind":"building_bench","at":[384,36],"size":[96,80]})
	s.world.active_resident.position=bench.position+Vector2(0,-20)
	check(s.construction.build(s.world.active_resident,bench,"cloud_ladder"),"actual cloud ladder construction succeeds")
	check(s.world.cliff_open.size()==3,"actual construction opens three collision/render wall segments")
	await set_location(Vector2(432,48),true)
	await frames(8)
	await screenshot("cliff-03-cloud-ladder-pass.png")

	await set_location(Vector2(2370,-300),true)
	await screenshot("cliff-04-eastern-ridge.png")
	await set_location(Vector2(-60,-250),false)
	check(not s.world.haze.on_highland(),"western wall view remains on forest low ground")
	await screenshot("cliff-05-forest-escarpment.png")
	var file:=FileAccess.open(directory.path_join("cliff-visual-record.json"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"checks":checks,"failures":failures,"images":records,"state":state_path},"\t")); file.close()
	print("CLIFF_VISUAL_FAILURES="+JSON.stringify(failures))
	if failures.is_empty(): print("CLIFF_VISUAL_PROBE_OK checks="+str(checks))
	game.queue_free(); await frames(3)
	get_tree().quit(0 if failures.is_empty() else 1)
