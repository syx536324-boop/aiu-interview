# Verifies the real window-close notification saves and a second process resumes it.
extends SceneTree

const PATH := "res://.runtime/test-quit-save.json"

func _initialize() -> void:
	OS.set_environment("AIU5_STATE_PATH", PATH)
	OS.set_environment("AIU5_PROFILE_PATH", "res://.runtime/test-quit-names.cfg")
	if not "verify" in OS.get_cmdline_user_args():
		for suffix in ["", ".altar"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
	call_deferred("run_check")

func run_check() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var world: Node2D = game.get_node("World")
	var vitals: Node = game.get_node("Vitals")
	var farm: Node = game.get_node("Homestead")
	var inventory: Node = game.get_node("Inventory")
	var herd: Node = game.get_node("Livestock")
	var mining: Node = game.get_node("Mining")
	herd.set_process(false)
	vitals.set_process(false)
	farm.set_process(false)
	for actor in world.residents: actor.set_physics_process(false)
	if "verify" in OS.get_cmdline_user_args():
		var good: bool = world.active_resident.room_id == "kitchen" and world.active_resident.position == Vector2(95, 109)
		good = good and vitals.ensure("ali").hunger == 6 and vitals.ensure("ali").need_time == 119.25
		good = good and farm.cooking.remaining == 27.5
		good = good and farm.plots[0].crop == "rice" and farm.plots[0].growth == 123.75 and farm.plots[0].stage == 2
		good = good and farm.plots[0].age == 67.5 and farm.seed_for(world.active_resident) == "rice_seeds"
		good = good and inventory.has_item("ali", "water_bucket_2") and inventory.has_item("ali", "water_cup")
		good = good and world.cows.size() == 3 and herd.find_animal("cow:3").growth == 143.25
		good = good and herd.find_animal("cow:1").cooldown == 77.5 and herd.find_animal("cow:1").fed
		good = good and mining.progress.get("surface:1", 0) == 2
		if good: print("QUIT_SAVE_RELOAD_OK")
		else: push_error("QUIT_SAVE_RELOAD_FAILED")
		quit(0 if good else 1)
	else:
		game.get_node("Interiors").enter(world.active_resident, world.home_data("kitchen"))
		world.active_resident.position = Vector2(95, 109)
		vitals.ensure("ali").hunger = 6
		vitals.ensure("ali").need_time = 119.25
		farm.cooking.remaining = 27.5
		farm.plots[0].crop = "rice"
		farm.plots[0].dry = false
		farm.plots[0].growth = 123.75
		farm.plots[0].age = 67.5
		farm.selected_seeds.ali = "rice_seeds"
		farm.refresh()
		inventory.exchange("ali", {"bucket": 1, "wooden_cup": 1}, {"water_bucket_2": 1, "water_cup": 1})
		herd._spawn("cow:3", "cow", "female", 143.25, Vector2(104, 460))
		herd.next_ids.cow = 4
		herd.find_animal("cow:1").cooldown = 77.5
		herd.find_animal("cow:1").fed = true
		mining.restore({"progress": {"surface:1": 2}})
		if "paused" in OS.get_cmdline_user_args():
			game.get_node("Session").overview = true
			world.set_overview(true)
		game.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		if FileAccess.file_exists(PATH): print("QUIT_NOTIFICATION_SAVED_OK")
		else:
			push_error("QUIT_NOTIFICATION_SAVE_FAILED")
			quit(1)
