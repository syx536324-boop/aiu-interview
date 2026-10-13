# Captures current haze, the Yunye tribe and loaded northern forest without changing gameplay rules.
extends SceneTree
var directory := ""
var game: Node
var s: Node
func _initialize() -> void:
	directory=OS.get_environment("AIU5_PROBE_DIRECTORY")
	assert(directory!="")
	OS.set_environment("AIU5_STATE_PATH",directory+"/state.json")
	OS.set_environment("AIU5_PROFILE_PATH",directory+"/names.cfg")
	create_timer(60,true).timeout.connect(func() -> void: quit(2))
	call_deferred("run")
func shot(name: String, at: Vector2) -> void:
	s.world.active_resident.position=at
	s._sync_view(); game.get_node("Streaming").focus(true); s.refresh_interface()
	for i in range(160): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(directory+"/"+name+".png")==OK)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	s=game.get_node("Session")
	s.simulation.set_process(false); s.simulation.reset(); s.persistence.set_process(false)
	for actor in s.world.residents: actor.set_physics_process(false)
	for enemy in s.combat.enemies.values(): enemy.set_physics_process(false)
	s.world.haze.visited=false
	await shot("haze-before",Vector2(1100,24))
	await shot("haze-after",Vector2(1100,-800))
	await shot("yunye-tribe",Vector2(3250,-820))
	await shot("north-forest",Vector2(-1000,-800))
	print("MAINTENANCE_VISUAL_OK")
	game.queue_free(); await process_frame; quit(0)
