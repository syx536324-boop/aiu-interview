# Exercises the two starter NPCs through actual tribal ticks, collision, persistence and priority gates.
extends "res://tests/npc_attitude_probe.gd"

func run() -> void:
	await fresh_game()
	var ids := ["home:initial_male","home:initial_female"]
	var starts := {}
	var furthest := {}
	s.world.active_resident.position=Vector2(640,395); s._sync_view()
	for id: String in ids:
		starts[id]=t.population.node(id).position
		furthest[id]=0.0
	await capture("before")
	for i in range(300):
		t.advance(0.1)
		for id: String in ids:
			furthest[id]=maxf(furthest[id],t.population.node(id).position.distance_to(starts[id]))
		await get_tree().process_frame
	if OS.get_environment("AIU5_REPRO_ONLY")=="true":
		print("FRIENDLY_IDLE_REPRO ",JSON.stringify(furthest))
		check(furthest.values().all(func(n: float)->bool:return n<0.1),"both starter NPCs remain stationary in the unpatched build")
		finish(); return
	for id: String in ids:
		check(furthest[id]>20.0,id+" really walks while idle")
		check(furthest[id]<90.0,id+" stays close to its own village anchor")
		check(t.population.node(id).hp==10.0,id+" is not healed or hurt by routine movement")
	await capture("after")
	var routine: Variant=prop(t,["routine"])
	check(routine!=null,"tribal runtime owns the friendly daily routine")
	if routine==null: finish(); return
	var man: Node=t.population.node(ids[0])
	var at: Vector2=man.position
	t.romance.escorts[man.resident_id]={}
	for i in range(10): t.war._act(ids[0],man,0.5)
	check(man.position==at,"a wedding or escort route takes priority over daily walks")
	t.romance.escorts.erase(man.resident_id)
	t.war.orders[ids[0]]="return"
	var snapshot: Dictionary=routine.export_state()
	routine.advance_actor(ids[0],man,2.0)
	check(routine.export_state()==snapshot,"orders take priority and do not advance idle timers")
	t.war.orders.clear()
	t.population.members[ids[0]].career="farmer"
	routine.advance_actor(ids[0],man,2.0)
	check(man.position==at,"farmer work is not overwritten by idle movement")
	t.population.members[ids[0]].career="civilian"
	t.open("npc",ids[0]); routine.advance_actor(ids[0],man,2.0)
	check(man.position==at,"talking NPC stays in place during interaction")
	s.production.close()
	t.population.members[ids[0]].child_left=100.0
	routine.advance_actor(ids[0],man,2.0)
	check(man.position==at,"children do not inherit adult idle movement")
	t.population.members[ids[0]].child_left=0.0
	# Peaceful wandering runs through the unified online clock, so pause freezes it.
	var paused_state: Dictionary=routine.export_state()
	get_tree().paused=true
	for i in range(5): await get_tree().process_frame
	check(routine.export_state()==paused_state and man.position==at,"pause freezes idle state and position")
	get_tree().paused=false
	check(s.persistence.save_now(),"routine and NPC positions save in the same transaction")
	var saved: Dictionary=routine.export_state()
	var saved_at: Vector2=man.position
	await reload_game()
	routine=prop(t,["routine"]); man=t.population.node(ids[0])
	check(JSON.parse_string(JSON.stringify(routine.export_state()))==JSON.parse_string(JSON.stringify(saved)),"reload preserves exact destinations and remaining waits")
	check(man.position==saved_at,"reload preserves NPC position without a teleport")
	var old: Dictionary=t.export_state(); old.erase("routine")
	t.restore(old)
	check(man.hp==10 and t.population.count("home")==2,"old saves gain routines without new people or healing")
	# Dead villagers remain dead when the optional old-save field is absent.
	man.hp=0; man.refresh(); old=t.export_state(); old.erase("routine"); t.restore(old)
	check(man.hp==0 and not man.visible,"routine migration never revives a dead villager")
	if failures.is_empty(): print("FRIENDLY_ROUTINE_OK checks=",checks," motion=",JSON.stringify(furthest))
	finish()

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	s.world.camera.force_update_scroll()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory+"/friendly-"+label+".png")
