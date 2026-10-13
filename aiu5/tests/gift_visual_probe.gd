# Captures game-only day/night and ritual-menu layouts using isolated saves for visual verification.
extends SceneTree
var game: Node
var s: Node
var directory := ""
func _initialize() -> void:
	directory = OS.get_environment("AIU5_PROBE_DIRECTORY")
	if directory=="": directory = ProjectSettings.globalize_path("res://.runtime/gift-visual-"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(directory)
	OS.set_environment("AIU5_STATE_PATH",directory+"/state.json")
	OS.set_environment("AIU5_PROFILE_PATH",directory+"/names.cfg")
	call_deferred("run")
func capture(name: String) -> void:
	for i in range(10): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(directory+"/"+name+".png")
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	s = game.get_node("Session")
	s.simulation.set_process(false)
	s.persistence.set_process(false)
	s.world.active_resident.position = s.world.point_info("altar").position+Vector2(0,20)
	s._sync_view()
	s.day_night.restore({"elapsed":240.0})
	s.refresh_interface()
	await capture("noon")
	s.day_night.restore({"elapsed":840.0})
	s.refresh_interface()
	await capture("night")
	s.gifts.open_menu()
	await capture("altar")
	# UI-only example; the live camera has a separate real-hardware probe.
	s.gifts.mode = "camera"
	s.gifts.feedback = "界面验证示例 · 选择物品后确认赐予1件。"
	s.gifts.frozen = true
	s.gifts.selected = "visual-example"
	s.gifts.candidates = [{"id":"visual-example","name":"苹果","item":"apple","class_id":8,"kind":"inventory","confidence":.88}]
	s.gifts._emit()
	await capture("camera-layout-example")
	print("VISUAL_DIRECTORY=",directory)
	s.gifts.close()
	game.queue_free()
	await process_frame
	quit()
