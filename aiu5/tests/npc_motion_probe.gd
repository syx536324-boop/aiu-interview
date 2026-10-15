# Measures actual per-physics-frame NPC movement, animation, stopping and solid collision.
extends "res://tests/npc_attitude_probe.gd"

func run() -> void:
	await fresh_game()
	s.world.active_resident.position=Vector2(640,395)
	s._sync_view()
	var ids := ["home:initial_male","home:initial_female"]
	var metrics := {}
	for id: String in ids:
		var npc: Node=t.population.node(id)
		npc.set_physics_process(true)
		metrics[id]={"last":npc.position,"max_step":0.0,"transit":0,"moving":0,"frames":{},"distance":0.0}
	s.simulation.reset()
	s.simulation.set_process(true)
	for i in range(720):
		await get_tree().physics_frame
		for id: String in ids:
			var npc: Node=t.population.node(id)
			var m: Dictionary=metrics[id]
			var step: float=npc.position.distance_to(m.last)
			m.max_step=maxf(m.max_step,step)
			m.distance=float(m.distance)+step
			m.last=npc.position
			var routine: Dictionary=t.routine.states.get(id,{})
			if bool(routine.get("walking",false)) and npc.position.distance_to(Vector2(routine.target[0],routine.target[1]))>17:
				m.transit=int(m.transit)+1
				if step>0.001: m.moving=int(m.moving)+1
			if step>0.001: m.frames[int(npc.sprite.frame)/npc.sprite.hframes]=true
	s.simulation.set_process(false)
	var result := {}
	for id: String in ids:
		var m: Dictionary=metrics[id]
		result[id]={"max_step":m.max_step,"transit_frames":m.transit,"moving_ratio":float(m.moving)/maxi(1,int(m.transit)),"animation_rows":m.frames.keys(),"distance":m.distance}
	if OS.get_environment("AIU5_MOTION_BASELINE")=="true":
		print("NPC_MOTION_BASELINE_OK ",JSON.stringify(result))
		finish(); return
	for id: String in ids:
		var m: Dictionary=result[id]
		check(float(m.distance)>35,id+" visibly walks under the real clock")
		check(float(m.max_step)<1.25,id+" has no half-second position jumps")
		check(int(m.transit_frames)>60 and float(m.moving_ratio)>0.75,id+" advances continuously between decisions")
		check(m.animation_rows.size()>=3,id+" uses distinct walking poses")
	# Pause must freeze actual collision bodies, not just an animation tween.
	var man: Node=t.population.node(ids[0])
	var at: Vector2=man.position
	get_tree().paused=true
	await get_tree().create_timer(0.3,true,false,true).timeout
	check(man.position==at,"pause freezes the real NPC position")
	get_tree().paused=false
	# An interaction revokes peaceful walking before the next coarse decision.
	t.open("npc",ids[0])
	await frames(4)
	check(man.position==at,"dialogue immediately stops an existing walk command")
	s.production.close()
	# An obstacle unknown to navigation still blocks the swept physical movement.
	man.position=Vector2(750,500)
	man.navigation=PackedVector2Array()
	var wall := StaticBody2D.new()
	wall.collision_layer=1
	wall.position=Vector2(780,500)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new(); rect.size=Vector2(8,80)
	shape.shape=rect; wall.add_child(shape); s.world.objects.add_child(wall)
	await get_tree().physics_frame
	for i in range(120):
		if i%20==0: t.workers.move(man,Vector2(850,500),0.5,32.0)
		await get_tree().physics_frame
	check(man.position.x>754 and man.position.x<772,"continuous movement reaches and stops at a real wall")
	wall.queue_free()
	t.workers.movement.stop(man)
	await frames(4)
	check(man.sprite.frame<man.sprite.hframes,"a stopped NPC returns to its idle pose")
	if DisplayServer.get_name()!="headless":
		s.world.camera.force_update_scroll()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory+"/npc-motion.png")
	if failures.is_empty(): print("NPC_MOTION_OK checks=",checks," motion=",JSON.stringify(result))
	finish()
