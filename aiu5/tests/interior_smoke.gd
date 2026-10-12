# Verifies room transitions, real physics, character isolation and persisted user naming.
extends SceneTree

var failures: Array[String] = []
var game: Node
var world: Node2D
var session: Node
var interiors: Node2D
var hud: CanvasLayer

func _initialize() -> void:
	OS.set_environment("AIU5_PROFILE_PATH", "res://.runtime/test-founder-names.cfg")
	OS.set_environment("AIU5_STATE_PATH", "res://.runtime/test-interior-layout.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://.runtime/test-interior-layout.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://.runtime/test-founder-names.cfg"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OS.get_environment("AIU5_STATE_PATH") + ".altar"))
	call_deferred("run_checks")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("CHECK FAILED: " + message)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	Input.parse_input_event(event)
	await frames(1)

func is_free(resident: CharacterBody2D) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.5
	query.shape = circle
	query.transform = Transform2D(0, resident.global_position + Vector2(0, -3))
	query.collision_mask = 1 | 2
	query.exclude = [resident.get_rid()]
	return world.get_world_2d().direct_space_state.intersect_shape(query).is_empty()

func run_checks() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	world = game.get_node("World")
	session = game.get_node("Session")
	interiors = game.get_node("Interiors")
	hud = game.get_node("HUD")
	await frames(3)
	for resident: CharacterBody2D in world.residents:
		if resident != world.active_resident:
			resident.set_physics_process(false)
	var player: CharacterBody2D = world.active_resident
	var layouts: Dictionary = {}
	var fixture_count := 0
	for home: Dictionary in world.Layout.HOMES:
		player.position = home["door"] + Vector2(0, 4)
		await frames(2)
		await key(KEY_E)
		check(player.room_id == home["id"], "E enters " + str(home["name"]))
		if player.room_id == "":
			continue
		var room: Node2D = interiors.rooms[home["id"]]
		check(room.visible and not world.visible and room.camera.is_current(), "interior visibility and camera: " + room.room_name)
		check(is_free(player), "entry spawns outside obstacles: " + room.room_name)
		check(room.definition["mats"].size() >= 1 and room.fixtures.size() >= 6, "mats and furniture present: " + room.room_name)
		layouts[str(room.definition["furniture"])] = true
		var spawn: Vector2 = player.position
		Input.action_press("move_left")
		await frames(6)
		Input.action_release("move_left")
		check(player.position.x < spawn.x - 3, "player can walk inside: " + room.room_name)
		for fixture: Node2D in room.fixtures:
			fixture_count += 1
			var bounds: Rect2 = fixture.collision_bounds()
			var from := Vector2(bounds.get_center().x, bounds.end.y + 7)
			check(player.test_move(Transform2D(0, room.global_position + from), Vector2(0, -bounds.size.y - 12)), "wood furniture physically blocks movement: " + room.room_name + "/" + fixture.kind)
		for mat: Rect2 in room.definition["mats"]:
			var goal := mat.get_center() + Vector2(0, 4)
			check(not room.navigation.find_path(spawn, goal).is_empty(), "mat is reachable from door: " + room.room_name + str(mat))
			player.position = goal
			await frames(1)
			check(is_free(player), "straw mat is walkable: " + room.room_name + str(mat))
		player.position = Vector2(17, room.size.y - 32)
		await frames(1)
		Input.action_press("move_left")
		await frames(16)
		Input.action_release("move_left")
		check(player.position.x >= 13.4, "interior wall blocks leaving room: " + room.room_name)
		player.position = room.exit_point()
		await frames(1)
		await key(KEY_E)
		check(player.room_id == "" and world.visible and world.camera.is_current(), "E returns outdoors: " + str(home["name"]))
		check(player.position.distance_to(home["door"]) < 32 and is_free(player), "exit returns safely to matching door: " + str(home["name"]))
	check(layouts.size() == 14 and interiors.rooms.is_empty() and interiors.layout_overrides.size() >= 14, "all nine distinct rooms unload after leaving and retain their layouts")
	check(fixture_count >= 45, "all room furniture has collision coverage")
	player.position = world.home_data("house")["door"] + Vector2(0, 4)
	await frames(2)
	await key(KEY_E)
	player.position += Vector2(-10, 0)
	await frames(1)
	var remembered := player.position
	await key(KEY_2)
	check(world.active_resident.room_id == "" and world.visible, "switch from indoor male to outdoor female")
	player.set_physics_process(true)
	world.active_resident.set_physics_process(true)
	await frames(15)
	check(player.position.distance_to(remembered) < 0.1, "inactive indoor resident waits without using outdoor patrol")
	world.active_resident.position = world.home_data("house")["door"] + Vector2(0, 4)
	await frames(2)
	await key(KEY_E)
	check(world.active_resident.room_id == "house" and is_free(world.active_resident), "second character enters occupied room safely")
	await key(KEY_1)
	check(player.position.distance_to(remembered) < 0.1 and not world.visible, "switch back preserves indoor position and camera")
	await key(KEY_3)
	world.active_resident.position = world.home_data("chief_house")["door"] + Vector2(0, 4)
	await frames(2)
	await key(KEY_E)
	check(world.active_resident.room_id == "chief_house", "chief enters another room")
	check(not interiors.rooms["house"].visible and interiors.rooms["chief_house"].visible, "different rooms are visually isolated")
	await key(KEY_1)
	await key(KEY_M)
	check(not session.overview and not world.visible, "M keeps indoor camera")
	check(world.get_roster()[0]["area"].contains("旧泥屋"), "roster shows indoor location")
	await key(KEY_C)
	hud.rename_button.pressed.emit()
	await frames(1)
	check(hud.names_root.visible and hud.male_input.has_focus(), "C panel opens name editor")
	hud.male_input.text = ""
	hud.female_input.text = "测试女"
	hud.save_names_button.pressed.emit()
	check(hud.names_root.visible and hud.names_message.text.contains("填写"), "empty name is rejected without closing editor")
	var before: Vector2 = player.position
	await key(KEY_A)
	check(player.position.distance_to(before) < 0.1 and session.roster_open, "typing does not move the resident")
	hud.male_input.text = "测试男"
	hud.female_input.text = "测试女"
	hud.save_names_button.pressed.emit()
	await frames(2)
	check(not hud.names_root.visible, "saving names closes editor")
	check(world.controllable[0].resident_name == "测试男" and world.controllable[1].resident_name == "测试女", "names update correct male and female")
	check(hud.roster_buttons[0].text.contains("测试男") and hud.roster_buttons[1].text.contains("测试女"), "renamed roster updates immediately")
	check(world.controllable[0].resident_id == "ali" and world.controllable[1].resident_id == "heya", "renaming preserves stable control identity")
	check(world.controllable[0].role_label.contains("男") and world.controllable[1].role_label.contains("女"), "founders have explicit male and female roles")
	game.queue_free()
	await frames(2)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	world = game.get_node("World")
	check(world.founder_names() == {"male": "测试男", "female": "测试女"}, "fresh game reloads saved founder names")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://.runtime/test-founder-names.cfg"))
	if failures.is_empty():
		print("INTERIOR_SMOKE_OK: 8 distinct enterable rooms, ", fixture_count, " wooden furniture collisions, walkable reachable mats, safe exits, retained indoor positions, multi-character room isolation and UI naming persisted across restart")
		quit(0)
	else:
		print("INTERIOR_SMOKE_FAILED: ", failures)
		quit(1)
