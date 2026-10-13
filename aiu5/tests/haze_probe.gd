# Verifies confirmed haze opacities, plateau/mountain ranged reach and unchanged Yunye hostility.
extends SceneTree
const Haze := preload("res://features/weather/haze.gd")
var failures: Array[String] = []
var checks := 0
var game: Node
func _initialize() -> void:
	var directory := OS.get_environment("AIU5_PROBE_DIRECTORY")
	assert(directory!="")
	OS.set_environment("AIU5_STATE_PATH",directory+"/state.json")
	OS.set_environment("AIU5_PROFILE_PATH",directory+"/names.cfg")
	create_timer(45,true).timeout.connect(func() -> void: quit(2))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	var s: Node=game.get_node("Session")
	s.simulation.set_process(false); s.simulation.reset(); s.persistence.set_process(false)
	for actor in s.world.residents: actor.set_physics_process(false)
	check(Haze.PRE_VISIT_ALPHA==0.9,"before climbing ninety percent opacity")
	check(Haze.RING_ALPHAS==[0.9,0.7,0.4],"outermost is densest and centerward bands get lighter")
	check(Haze.BAND==0.3 and Haze.RANGE_SCALE==0.7,"band size and range penalty retained")
	for point: Vector2 in [Vector2(1100,-800),Vector2(3300,-800)]:
		s.world.active_resident.position=point
		check(s.world.haze.on_highland(),"both highland types use haze")
		check(s.combat.reach("bow")==105,"highland bow retains one-hundred-five reach")
		s.world.haze._process(0)
		check(s.world.haze.visited,"standing above enables visited ring")
	s.world.active_resident.position=Vector2(300,900)
	check(not s.world.haze.on_highland() and s.combat.reach("bow")==150,"plains keep full ranged reach")
	for member in s.combat.tribe_members("yunye"):
		if member.role in ["archer","charger"]: check(member.aggro_range()==210,"Yunye soldiers still hostile on sight")
	game.queue_free(); await process_frame
	if failures.is_empty(): print("HAZE_CONFIRMED_OK checks=",checks); quit(0)
	else: print(failures); quit(1)
