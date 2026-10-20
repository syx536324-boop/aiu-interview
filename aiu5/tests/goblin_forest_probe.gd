# Exercises an ordinary seeded outdoor encounter, streaming and physical pursuit in private state.
extends Node
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func run() -> void:
	var directory:=OS.get_environment("AIU5_BENCH_DIR")
	OS.set_environment("AIU5_STATE_PATH",directory+"/state.json"); OS.set_environment("AIU5_PROFILE_PATH",directory+"/names.cfg"); OS.set_environment("AIU5_WORLD_PROFILE","starter_v2")
	var game: Node=load("res://scenes/main.tscn").instantiate(); get_tree().root.add_child(game)
	for i in range(5): await get_tree().process_frame
	var s: Node=game.get_node("Session"); s.persistence.set_process(false)
	var player: Node=s.world.active_resident
	var chosen:=""
	for id: String in s.monsters.slots:
		var r: Dictionary=s.monsters.slots[id]
		if r.room!="": continue
		var home:=Vector2(r.home[0],r.home[1]); var to:=home+Vector2(184,0)
		if not s.monsters.walkable(home,"") or not s.monsters.walkable(to,""): continue
		player.position=to; s._sync_view()
		for i in range(3): await get_tree().physics_frame
		if not s.monsters.line_clear(player,home): continue
		s.monsters._focus()
		if s.monsters.units.has(id) and s.monsters.units[id].is_inside_tree(): chosen=id; break
	check(chosen!="","ordinary forest generation activates a safe reachable encounter")
	if chosen!="":
		var unit: Node=s.monsters.units[chosen]
		check(unit.level==1 and unit.tribe=="goblin" and s.magic.ensure(chosen).element=="wood","natural encounter has the confirmed level and wood element")
		player.position=unit.position+Vector2(168,0); s._sync_view()
		for i in range(3): await get_tree().physics_frame
		check(s.monsters.choose_target(unit)==player,"visible forest player is selected for proactive attack")
		var start: Vector2=unit.position; var previous:=start; var maximum:=0.0; var moved:=0; var samples: Array[float]=[]; var stamp:=Time.get_ticks_usec()
		for i in range(120):
			await get_tree().physics_frame
			var now:=Time.get_ticks_usec(); samples.append(float(now-stamp)/1000.0); stamp=now
			var motion: float=unit.position.distance_to(previous); maximum=maxf(maximum,motion)
			if motion>0.02: moved+=1
			previous=unit.position
		samples.sort()
		check(start.distance_to(unit.position)>30 and maximum<2 and moved>95,"outdoor goblin pursues continuously with streaming enabled")
		check(unit.position.distance_to(player.position)<start.distance_to(player.position)-30,"forest pursuit closes on the player rather than wandering")
		check(samples[114]<40,"outdoor encounter has no sustained frame stalls")
		var file:=FileAccess.open(directory+"/result.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"version":ProjectSettings.get_setting("application/config/version"),"display":DisplayServer.get_name(),"checks":checks,"failures":failures,"metrics":{"frame_p95_ms":samples[114],"frame_max_ms":samples.back(),"moving_frames":moved,"maximum_motion_per_frame":maximum,"pursuit_world_pixels":start.distance_to(unit.position)}},"  "))
		get_viewport().get_texture().get_image().save_png(directory+"/forest-goblin.png")
	game.queue_free(); await get_tree().process_frame
	print("GOBLIN_FOREST_OK" if failures.is_empty() else "GOBLIN_FOREST_FAILED"," checks=",checks," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
func _ready() -> void: call_deferred("run")
