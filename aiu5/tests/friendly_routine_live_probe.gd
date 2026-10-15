# Measures friendly NPC motion under the actual Simulation clock in a rendered main scene.
extends "res://tests/npc_attitude_probe.gd"

func run() -> void:
	await fresh_game()
	s.world.active_resident.position=Vector2(640,395)
	s._sync_view(); s.world.camera.force_update_scroll()
	var initial := {}
	var motion := {}
	for id: String in ["home:initial_male","home:initial_female"]:
		initial[id]=t.population.node(id).position
		motion[id]=0.0
	s.simulation.reset()
	s.simulation.set_process(true)
	for i in range(32):
		await get_tree().create_timer(0.25,true,false,true).timeout
		for id: String in motion:
			motion[id]=maxf(motion[id],t.population.node(id).position.distance_to(initial[id]))
	s.simulation.flush(); s.simulation.set_process(false)
	for id: String in motion:
		check(motion[id]>20.0,id+" walks through the actual online clock")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory+"/friendly-live.png")
	if failures.is_empty(): print("FRIENDLY_LIVE_OK checks=",checks," motion=",JSON.stringify(motion))
	finish()
