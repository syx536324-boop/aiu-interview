# Runs complete guard decisions, physical motion and real damage on the actual online clock.
extends "res://tests/npc_attitude_probe.gd"

var trace: Dictionary = {}

func run() -> void:
	for kind: String in ["neutral","hostile","provoked","trespass","civilian","civilian_trapped"]:
		await duel(kind)
	await search_case()
	print("NPC_BEHAVIOR_TRACE ",JSON.stringify(trace))
	if OS.get_environment("AIU5_AUDIT_BASELINE")=="true":
		print("NPC_BEHAVIOR_BASELINE_OK")
	elif failures.is_empty(): print("NPC_BEHAVIOR_LIVE_OK checks=",checks)
	finish()

func fixture(role: String) -> Node:
	await fresh_game()
	var chosen := first_visible_npc("forest",role)
	for id: String in t.population.members:
		var npc: Node=t.population.node(id)
		if id!=chosen: npc.room_id="isolated_probe"; npc.set_physics_process(false)
	var npc: Node=t.population.node(chosen)
	npc.set_physics_process(true)
	return npc

func yard() -> Vector2:
	var circle := CircleShape2D.new(); circle.radius=48
	var query := PhysicsShapeQueryParameters2D.new(); query.shape=circle; query.collision_mask=1|2|4|8|16
	for y in range(-240,241,80):
		for x in range(-240,241,80):
			var point: Vector2=t.centers.forest+Vector2(x,y)
			query.transform=Transform2D(0,point)
			if point.distance_to(t.relics.visuals.forest.position)<110: continue
			if s.world.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(): return point
	return t.centers.forest+Vector2(200,200)

func start_live(npc: Node, at: Vector2, gap: float) -> void:
	npc.position=at; npc.home_anchor=at
	s.world.active_resident.position=at+Vector2(gap,0)
	s._sync_view(); npc.set_physics_process(true)
	await get_tree().physics_frame
	s.simulation.reset(); s.simulation.set_process(true)

func sample(npc: Node, seconds: float) -> Dictionary:
	var before: float=s.vitals.ensure(actor_id()).life
	var states := {}
	var start: Vector2=npc.position
	var max_motion := 0.0
	for i in range(int(seconds*60)):
		await get_tree().physics_frame
		states[str(npc.state)]=int(states.get(str(npc.state),0))+1
		max_motion=maxf(max_motion,npc.position.distance_to(start))
		if s.vitals.ensure(actor_id()).life<=4: break
	s.simulation.set_process(false)
	return {"lost_life":before-float(s.vitals.ensure(actor_id()).life),"states":states,"motion":max_motion,
		"gap":npc.position.distance_to(s.world.active_resident.position),"sees":t.guards._sees(npc,s.world.active_resident.position),"weapon_cooldown":t.war.cooldowns.get(npc.enemy_id,0)}

func duel(kind: String) -> void:
	var npc: Node=await fixture("civilian" if kind.begins_with("civilian") else "charger")
	t.set_standing("forest",-60 if kind=="hostile" else 0)
	var at := yard()
	var gap := 24.0
	if kind=="trespass": at=t.relics.visuals.forest.position+Vector2(28,32); gap=-24
	if kind=="civilian_trapped": gap=10.5
	await start_live(npc,at,gap)
	if kind=="civilian_trapped":
		for spec: Array in [[Vector2(-9,0),Vector2(4,26)],[Vector2(3,-9),Vector2(24,4)],[Vector2(3,9),Vector2(24,4)]]:
			var wall := StaticBody2D.new(); wall.collision_layer=1; wall.position=at+Vector2(spec[0])
			var shape := CollisionShape2D.new(); var box := RectangleShape2D.new(); box.size=Vector2(spec[1])
			shape.shape=box; wall.add_child(shape); s.world.objects.add_child(wall)
		for i in range(3): await get_tree().physics_frame
	if kind in ["provoked","civilian","civilian_trapped"]: s.combat.hit_enemy(npc,1,actor_id())
	trace[kind]=await sample(npc,12.0 if kind=="trespass" else 6.0)
	if DisplayServer.get_name()!="headless" and kind in ["neutral","trespass"]:
		s.world.camera.force_update_scroll()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory+"/forest-"+kind+".png")
	if OS.get_environment("AIU5_AUDIT_BASELINE")=="true": return
	if kind=="neutral": check(trace[kind].lost_life==0,"neutral forest members do not attack normal approaches")
	elif kind=="civilian": check(trace[kind].gap>34,"an attacked civilian flees rather than approaching out of range")
	elif kind=="civilian_trapped": check(trace[kind].lost_life>0,"a trapped civilian counterattacks only within legal range and clear sight")
	else: check(trace[kind].lost_life>0,kind+" guard completes its windup and actually damages the player")

func search_case() -> void:
	var npc: Node=await fixture("charger")
	t.set_standing("forest",-60)
	await start_live(npc,yard(),75)
	for i in range(70): await get_tree().physics_frame
	var last: Vector2=t.guards.npc(npc.enemy_id).last_seen
	var wall := StaticBody2D.new(); wall.collision_layer=1
	wall.position=(npc.position+s.world.active_resident.position)*0.5
	var shape := CollisionShape2D.new(); var box := RectangleShape2D.new(); box.size=Vector2(6,100)
	shape.shape=box; wall.add_child(shape); s.world.objects.add_child(wall)
	await get_tree().physics_frame
	for i in range(40): await get_tree().physics_frame
	var state := str(npc.state)
	var seen: Vector2=t.guards.npc(npc.enemy_id).last_seen
	s.simulation.set_process(false)
	trace.search={"state_after_losing_sight":state,"last_seen_unchanged":seen==last}
	if OS.get_environment("AIU5_AUDIT_BASELINE")!="true":
		check(state=="search","a hostile guard searches after losing visual contact")
		check(seen==last,"an obstructed guard does not track the player's hidden location")
