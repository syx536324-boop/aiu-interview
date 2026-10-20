# Regresses deployment responsiveness, access protection, item transactions and persistence in isolated state.
extends Node
var game: Node
var s: Node
var directory := ""
var failures: Array[String] = []
var checks := 0
var measurements: Array = []

func _ready() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func frames(n := 2) -> void:
	for i in range(n): await get_tree().process_frame
func check_reference(nav: RefCounted, obstacles: Array[Rect2], from: Vector2, targets: Array[Vector2], removed: Array[Rect2], added: Rect2, label: String) -> void:
	var reference = load("res://features/village/navigation.gd").new()
	var next: Array[Rect2] = obstacles.duplicate()
	for rect: Rect2 in removed: next.erase(rect)
	next.append(added)
	reference.rebuild(next, Vector2(192,160),Vector2(-64,-32))
	var expected := true
	for target: Vector2 in targets:
		if not nav.find_path(from,target).is_empty() and reference.find_path(from,target).is_empty(): expected = false
	var before_revision: int = nav.revision
	var before_coverage: Dictionary = nav.coverage.duplicate()
	check(nav.preserves_access(from,targets,removed,added)==expected,label+" matches real no-corner-cutting paths")
	check(nav.revision==before_revision and nav.coverage==before_coverage,label+" leaves live navigation intact")
	check(nav.preserves_access(from,targets,removed,added)==expected,label+" cached trial stays correct")

func navigation_cases() -> void:
	var navigation = load("res://features/village/navigation.gd")
	var rng := RandomNumberGenerator.new(); rng.seed=417029
	for round in range(40):
		var nav = navigation.new()
		var obstacles: Array[Rect2] = []
		for i in range(12): obstacles.append(Rect2(rng.randi_range(-64,184),rng.randi_range(-32,152),rng.randi_range(4,32),rng.randi_range(4,32)))
		nav.rebuild(obstacles,Vector2(192,160),Vector2(-64,-32))
		var targets: Array[Vector2] = []
		for i in range(25): targets.append(Vector2(rng.randf_range(-80,208),rng.randf_range(-48,176)))
		var from := Vector2(rng.randf_range(-64,192),rng.randf_range(-32,160))
		var added := Rect2(rng.randi_range(-56,176),rng.randi_range(-24,144),rng.randi_range(4,48),rng.randi_range(4,48))
		var removed: Array[Rect2] = []
		if round%2==0: removed.append(obstacles[0])
		if round%3==0: removed.append(obstacles[1])
		check_reference(nav,obstacles,from,targets,removed,added,"layout "+str(round))
	var walls: Array[Rect2] = [Rect2(40,-32,8,64),Rect2(40,64,8,96)]
	var nav = navigation.new(); nav.rebuild(walls,Vector2(192,160),Vector2(-64,-32))
	var targets: Array[Vector2] = [Vector2(120,48)]
	var none: Array[Rect2] = []
	var opened: Array[Rect2] = [walls[0]]
	check(not nav.preserves_access(Vector2(0,48),targets,none,Rect2(40,32,8,32)),"closing the sole entrance is refused")
	check(nav.preserves_access(Vector2(0,48),targets,opened,Rect2(40,32,8,32)),"moving a wall or opening a gate preserves alternate access")
	check_reference(nav,walls,Vector2(0,48),targets,none,Rect2(40,32,8,32),"narrow entrance")
	# Overlay counts may change while the set of solid cells stays identical.
	var added := Rect2(40,32,8,32)
	check(nav.preserves_access(Vector2(0,48),targets,opened,added),"open-gate trial is cached")
	walls.append(Rect2(40,-32,8,56)); nav.rebuild(walls,Vector2(192,160),Vector2(-64,-32))
	check_reference(nav,walls,Vector2(0,48),targets,opened,added,"overlapping obstacle update")

func load_game() -> void:
	game=load("res://scenes/main.tscn").instantiate(); get_tree().root.add_child(game)
	await frames(5)
	s=game.get_node("Session")
	s.persistence.set_process(false); s.simulation.set_process(false)
	s.resources.set_process(false); s.world.streamer.set_process(false); s.editor.set_process(false)
	for actor: Node in s.world.residents: actor.set_physics_process(false)
	for enemy: Node in s.combat.enemies.values(): enemy.set_physics_process(false)
	var actor: Node=s.world.active_resident
	if actor.room_id!="": s.interiors.leave(actor,s.world.objects,Vector2(300,250))
	actor.position=Vector2(300,250); s._sync_view()

func bench_count() -> int:
	var count := 0
	for slot: Dictionary in s.inventory.ensure_bag(s.world.active_resident.resident_id):
		if slot.get("item","")=="building_bench": count += int(slot.count)
	return count

func find_sites() -> Array[Vector2]:
	var sites: Array[Vector2] = []
	var obstacles: Array[Rect2] = s.world.logical_obstacles(s.world.gate_visual.open)
	for y in range(220,450,4):
		for x in range(220,440,4):
			var at := Vector2(x,y)
			s.editor.ghost.set_placement(at,0)
			if s.grounds.land_error(s.editor.ghost.visual_bounds(),s.world.active_resident)!="": continue
			if not obstacles.any(func(rect: Rect2) -> bool: return s.editor.ghost.collision_bounds().grow(12).intersects(rect)): continue
			sites.append(at)
			if sites.size()>=20: return sites
	return sites

func actual_deployment() -> void:
	await load_game()
	var actor: Node = s.world.active_resident
	s.inventory.bags[actor.resident_id]=[]
	for i in range(21): s.inventory.bags[actor.resident_id].append({})
	check(s.inventory.exchange(actor.resident_id,{}, {"building_bench":3}),"isolated deployment supplies added")
	s.editor.open(); s.editor.choose("building_bench")
	var sites := find_sites()
	check(sites.size()>=10,"obstacle-adjacent building bench positions found beside starter kitchen")
	if sites.is_empty(): return
	var revision: int = s.world.navigation.revision
	var coverage: Dictionary = s.world.navigation.coverage.duplicate()
	for at: Vector2 in sites:
		var started := Time.get_ticks_usec()
		s.editor.point_at(at+Vector2(48,40))
		var ms := (Time.get_ticks_usec()-started)/1000.0
		measurements.append({"action":"preview","at":[at.x,at.y],"ms":ms})
		check(ms<100,"adjacent preview returns within 100ms at "+str(at))
		check(s.editor.ghost.preview_valid,"empty adjacent ground remains usable")
	check(s.world.navigation.revision==revision and s.world.navigation.coverage==coverage,"moving previews never rebuilds or mutates shared navigation")
	var at: Vector2=sites[0]
	s.editor.point_at(at+Vector2(48,40))
	if DisplayServer.get_name()!="headless":
		s.refresh_interface(); await frames(4)
		get_viewport().get_texture().get_image().save_png(directory+"/bench-preview.png")
	var count := bench_count()
	var fixture_count: int=s.grounds.fixtures.size()
	var started:=Time.get_ticks_usec()
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=get_viewport().get_final_transform()*s.grounds.get_global_transform_with_canvas()*(at+Vector2(48,40))
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		Input.parse_input_event(event)
		await frames(2)
	check(not is_instance_valid(s.editor.ghost),"real mouse click confirms building bench deployment")
	if is_instance_valid(s.editor.ghost): game.queue_free(); await frames(5); return
	measurements.append({"action":"place_and_save","ms":(Time.get_ticks_usec()-started)/1000.0})
	check(bench_count()==count-1 and s.grounds.fixtures.size()==fixture_count+1,"one bench deploys and consumes exactly one item")
	var fixture: Node2D=s.grounds.fixtures.back()
	var id: String=fixture.fixture_id
	check(s.world.navigation.obstacle_cells.has(fixture.collision_bounds()),"deployed building bench blocks movement")
	s.editor.close(); actor.position=fixture.position+Vector2(0,14); s._sync_view()
	for offset: Vector2 in [Vector2(60,0),Vector2(-60,0),Vector2(0,-52)]:
		if s.production.context().get("fixture")==fixture: break
		actor.position=fixture.visual_bounds().get_center()+offset
	s._sync_view()
	s.production.open_near()
	check(s.production.opened and s.production.mode=="build","deployed bench opens the building menu")
	s.production.close(); actor.position=Vector2(300,250); s._sync_view(); s.editor.open()
	s.editor.choose("building_bench"); s.editor.point_at(at+Vector2(48,40))
	check(not s.editor.ghost.preview_valid and not s.editor.place(),"overlapping bench is rejected")
	check(bench_count()==count-1 and s.grounds.fixtures.size()==fixture_count+1,"invalid placement consumes nothing")
	s.editor.cancel_selection(); s.editor.pick(fixture)
	s.editor.point_at(at+Vector2(52,40))
	check(s.editor.place() and bench_count()==count-1,"moving an existing bench consumes no item")
	fixture=s.grounds.fixtures.filter(func(f: Node2D) -> bool: return f.fixture_id==id)[0]
	s.editor.pick(fixture)
	check(s.editor.remove_selected() and bench_count()==count,"bench recovery returns exactly one item")
	s.editor.choose("building_bench"); s.editor.point_at(at+Vector2(48,40))
	var blocked:=directory+"/blocked-directory"
	DirAccess.make_dir_recursive_absolute(blocked)
	var path: String=s.inventory.path
	s.inventory.path=blocked
	check(not s.editor.place(),"failed save rejects deployment")
	s.inventory.path=path
	check(bench_count()==count and s.grounds.fixtures.size()==fixture_count,"failed save restores inventory and outdoor layout")
	s.editor.close(); await frames(3)
	s.editor.open(); s.editor.choose("building_bench"); s.editor.point_at(at+Vector2(48,40))
	check(s.editor.place(),"successful deployment still works after rollback")
	id=s.grounds.fixtures.back().fixture_id
	s.editor.close()
	check(s.persistence.save_now(),"deployed layout saves")
	game.queue_free(); await frames(5)
	await load_game()
	check(s.grounds.fixtures.any(func(f: Node2D) -> bool: return f.fixture_id==id and f.kind=="building_bench"),"deployed bench survives a scene reload")
	check(bench_count()==count-1,"spent item remains spent after reload")
	game.queue_free(); await frames(5)

func run() -> void:
	directory=OS.get_environment("AIU5_BENCH_DIR")
	if directory=="": get_tree().quit(2); return
	OS.set_environment("AIU5_STATE_PATH",directory+"/state.json")
	OS.set_environment("AIU5_PROFILE_PATH",directory+"/names.cfg")
	OS.set_environment("AIU5_WORLD_PROFILE","starter_v2")
	navigation_cases()
	await actual_deployment()
	var result: Dictionary={"version":ProjectSettings.get_setting("application/config/version"),"display":DisplayServer.get_name(),"checks":checks,"failures":failures,"measurements":measurements}
	var file:=FileAccess.open(directory+"/result.json",FileAccess.WRITE); file.store_string(JSON.stringify(result,"  "))
	print("BUILDING_DEPLOYMENT_OK" if failures.is_empty() else "BUILDING_DEPLOYMENT_FAILED", " checks=",checks," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
