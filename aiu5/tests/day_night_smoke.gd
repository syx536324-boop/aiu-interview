# Checks real-time hour ratios, midnight boundaries, persistent fractions and pause behavior.
extends SceneTree
var failures: Array[String] = []
var game: Node
var s: Node
func _initialize() -> void:
	var path := "res://.runtime/day-night-"+str(Time.get_ticks_usec())+"/state.json"
	OS.set_environment("AIU5_STATE_PATH",path)
	OS.set_environment("AIU5_PROFILE_PATH",path+".names")
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	s = game.get_node("Session")
	s.simulation.set_process(false)
	s.simulation.reset()
	s.persistence.set_process(false)
	var cycle: Node = s.day_night
	cycle.restore({})
	check(cycle.snapshot().clock=="08:00" and cycle.snapshot().day==1,"old/new saves start day one at eight")
	cycle.advance(60)
	check(cycle.snapshot().clock=="09:00","one real minute equals one game hour")
	cycle.advance(840)
	check(cycle.snapshot().clock=="23:00" and cycle.snapshot().phase=="夜晚","fifteen minutes advances fifteen hours")
	cycle.advance(60)
	check(cycle.snapshot().clock=="00:00" and cycle.snapshot().day==2,"midnight increments day")
	cycle.advance(480)
	check(cycle.snapshot().clock=="08:00" and cycle.snapshot().day==2,"24 real minutes makes full cycle")
	cycle.advance(.375)
	check(s.persistence.save_now(),"save fractional day progress")
	var data: Dictionary = s.inventory.export_data()
	cycle.restore({})
	s.persistence.restore_session(data.session)
	check(is_equal_approx(cycle.elapsed,1440.375),"restore exact fractional online time")
	check(cycle.tint(12).r > cycle.tint(0).r,"night darker than noon")
	check(absf(cycle.tint(5.999).r-cycle.tint(6.001).r)<.01,"dawn has no light discontinuity")
	check(absf(cycle.tint(23.999).r-cycle.tint(0).r)<.01,"midnight has no light discontinuity")
	s.simulation.set_process(true)
	var before: float = cycle.elapsed
	paused = true
	await create_timer(.7,true).timeout
	check(is_equal_approx(before,cycle.elapsed),"pausing stops day cycle")
	paused = false
	await create_timer(.6,true).timeout
	s.simulation.flush()
	check(cycle.elapsed > before,"unpause resumes without offline catchup")
	game.queue_free()
	await process_frame
	if failures.is_empty(): print("DAY_NIGHT_SMOKE_OK"); quit(0)
	else: print(failures); quit(1)
