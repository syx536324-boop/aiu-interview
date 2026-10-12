# Captures real skill trees and 96-world-pixel campfire light using disposable saves.
extends SceneTree
var game: Node
var s: Node
var directory := ""
func _initialize() -> void:
	directory = OS.get_environment("AIU5_SKILLS_VISUAL_DIR")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("res://.runtime/skills-visual")
	DirAccess.make_dir_recursive_absolute(directory)
	OS.set_environment("AIU5_STATE_PATH",directory+"/state.json")
	OS.set_environment("AIU5_PROFILE_PATH",directory+"/names.cfg")
	OS.set_environment("AIU5_WORLD_PROFILE","starter")
	call_deferred("run")
func capture(name: String) -> void:
	for i in range(8): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(directory+"/"+name+".png")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	s=game.get_node("Session")
	s.simulation.set_process(false); s.simulation.reset(); s.persistence.set_process(false)
	for actor in s.world.residents: actor.set_physics_process(false)
	for enemy in s.combat.enemies.values(): enemy.set_physics_process(false)
	for element in ["wood","water","fire","earth"]:
		s.magic.ensure("ali").element=element
		s.magic.ensure("ali").level=11
		s.magic.ensure("ali").unlocked=["trunk_1","trunk_2","trunk_3","trunk_4","trunk_5"]
		s.show_attributes("ali")
		game.get_node("Attributes")._show_page("tree")
		s.refresh_interface()
		await capture("tree-"+element)
	s.close_roster()
	s.interiors.enter(s.world.active_resident,s.world.home_data("mine"))
	var cave: Node2D=s.interiors.rooms.mine
	s.world.active_resident.position=Vector2(960,860)
	var camp: Node2D=cave.add_fixture({"id":"mine:visual-camp","kind":"campfire","at":[990,843],"size":[24,24],"lit":false})
	s._sync_view(); s.refresh_interface()
	await capture("cave-unlit")
	camp.set_lit(true)
	await capture("cave-lit-96-world")
	print("SKILLS_VISUAL_OK directory=",directory)
	game.queue_free(); await process_frame; quit()
