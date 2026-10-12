# Verifies real Godot-to-camera transport and clean camera release without granting or touching player saves.
extends SceneTree
var game: Node
var s: Node
func _initialize() -> void:
	var path := "res://.runtime/camera-probe-"+str(Time.get_ticks_usec())+"/state.json"
	OS.set_environment("AIU5_STATE_PATH",path)
	OS.set_environment("AIU5_PROFILE_PATH",path+".names")
	create_timer(55,true).timeout.connect(func() -> void:
		if is_instance_valid(s): s.gifts.close()
		print("CAMERA_PROBE_TIMEOUT")
		quit(2))
	call_deferred("run")
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	s = game.get_node("Session")
	s.world.active_resident.position = s.world.point_info("altar").position
	print("ALTAR_OPEN=",s.gifts.open_menu())
	s.gifts.begin_camera()
	print("BRIDGE_PID=",game.get_node("GiftCamera").pid," FEEDBACK=",s.gifts.feedback)
	var good := false
	for i in range(500):
		await create_timer(.1,true).timeout
		if i % 50 == 0: print("CAMERA_STATUS ",s.gifts.feedback," seq=",s.gifts.sequence," bridge_busy=",game.get_node("GiftCamera").busy)
		if s.gifts.sequence >= 5 and s.gifts.frame_jpeg.length() > 1000:
			print("REAL_CAMERA_READY device=",s.gifts.device," frames=",s.gifts.sequence," jpeg_bytes=",s.gifts.frame_jpeg.length()," stable_candidates=",s.gifts.candidates.size())
			good = true
			break
		if s.gifts.feedback.contains("失败") or s.gifts.feedback.contains("无法") or s.gifts.feedback.contains("超时") or s.gifts.feedback.contains("退出") or s.gifts.feedback.contains("未找到"):
			print("CAMERA_ERROR ",s.gifts.feedback)
			break
	var pid: int = game.get_node("GiftCamera").pid
	s.gifts.close()
	await create_timer(4,true).timeout
	print("CAMERA_PROCESS_STOPPED=",not OS.is_process_running(pid)," WORLD_RESUMED=",not paused)
	game.queue_free()
	await process_frame
	quit(0 if good and not OS.is_process_running(pid) else 1)
