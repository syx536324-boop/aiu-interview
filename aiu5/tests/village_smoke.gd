# Exercises real input, physics collisions and the village interaction loop headlessly.
extends SceneTree

var failures: Array[String] = []
var game: Node
var world: Node2D
var session: Node

func _initialize() -> void:
	OS.set_environment("AIU5_STATE_PATH", "res://.runtime/test-village-state.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://.runtime/test-village-state.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OS.get_environment("AIU5_STATE_PATH") + ".altar"))
	OS.set_environment("AIU5_PROFILE_PATH", "res://.runtime/test-village-names.cfg")
	create_timer(60, true).timeout.connect(func() -> void: push_error("VILLAGE_TIMEOUT"); quit(2))
	call_deferred("run_checks")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("CHECK FAILED: " + message)

func key(code: int, shift := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.shift_pressed = shift
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = false
	event.shift_pressed = shift
	Input.parse_input_event(event)
	await frames(1)

func move(actions: Array[String], count: int) -> void:
	for action in actions:
		Input.action_press(action)
	await frames(count)
	for action in actions:
		Input.action_release(action)
	await frames(1)

func run_checks() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	world = game.get_node("World")
	session = game.get_node("Session")
	await frames(3)
	check(world.residents.size() == 16, "thirteen residents are present")
	check(world.controllable.size() == 3, "three residents can be controlled")
	check(world.residents.filter(func(actor: CharacterBody2D) -> bool: return not actor.can_control).size() == 13, "ten new villagers remain NPCs")
	check(world.houses.size() == 14, "eight original village houses plus herbal house are present")
	check(world.SIZE == Vector2(4800, 1600) and world.BOUNDS.size == Vector2(7200, 3200), "the map is widened east to 4800 by 1600 with the mountain zone")
	check(world.pigs.size() == 3, "three pigs are present")
	check(world.get_node("VillageObjects/PrimitiveHouse") != null, "house is present")
	check(world.get_node("VillageObjects/Well") != null, "well is present")
	var player: CharacterBody2D = world.active_resident
	var styles: Dictionary = {}
	for house: Node2D in world.houses:
		var sprite: Sprite2D = house.get_child(0)
		styles[sprite.texture.resource_path + str(sprite.region_rect)] = true
	check(styles.size() == 7, "all seven houses use distinct source regions")
	for resident: CharacterBody2D in world.residents:
		check(resident.sprite.get_rect().size == Vector2(16, 16), "every resident uses complete 16 by 16 frames: " + resident.resident_name)
		var query := PhysicsShapeQueryParameters2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 3.5
		query.shape = circle
		query.transform = Transform2D(0, resident.position + Vector2(0, -3))
		query.collision_mask = 1
		check(world.get_world_2d().direct_space_state.intersect_shape(query).is_empty(), "resident spawns outside static obstacles: " + resident.resident_name)
		if resident != player:
			resident.set_physics_process(false)
	for data: Dictionary in world.Layout.HOMES:
		var door: Vector2 = data["door"]
		check(not world.navigation.find_path(Vector2(322, 224), door + Vector2(0, 8)).is_empty(), "house entrance can be reached: " + str(data["name"]))
		var at: Vector2 = data["at"]
		var region: Rect2 = data["region"]
		player.position = at + Vector2(region.size.x / 2, region.size.y + 22)
		await frames(2)
		await move(["move_up"], 30)
		check(player.position.y > at.y + region.size.y + 3 and player.position.y < at.y + region.size.y + 11, "house wall blocks entry: " + str(data["name"]))
	player.position = Vector2(340, 310)
	await frames(2)
	var start := player.position
	await move(["move_right"], 30)
	var straight_distance := player.position.distance_to(start)
	check(straight_distance > 26 and straight_distance < 30, "WASD movement uses the intended walking speed")
	player.position = start
	await frames(2)
	await move(["move_right", "move_up"], 30)
	var diagonal_distance := player.position.distance_to(start)
	check(absf(diagonal_distance - straight_distance) < 1.5, "diagonal movement is normalized")
	player.position = start
	await frames(2)
	await move(["move_right", "run"], 30)
	check(player.position.distance_to(start) > straight_distance * 1.4, "Shift increases movement speed")
	player.position = Vector2(200, world.MIN.y + 20)
	await frames(2)
	await move(["move_up"], 60)
	check(player.position.y >= world.MIN.y + 14 and player.position.y < world.MIN.y + 17, "map boundary blocks the player")
	player.position = Vector2(240, 184)
	await frames(2)
	await move(["move_up"], 45)
	check(player.position.y >= 163 and player.position.y < 169, "the house blocks movement through its wall")
	player.position = Vector2(258, 284)
	await frames(2)
	await key(KEY_E)
	check(not session.watered and not session.water_full, "an empty water jug cannot irrigate the field")
	# Water containers are crafted since the survival progression update, so prepare an empty one.
	game.get_node("Inventory").exchange(player.resident_id, {}, {"bucket": 1})
	player.position = Vector2(334, 220)
	await frames(2)
	await move(["move_up"], 30)
	check(player.position.y >= 205 and player.position.y < 209, "the stone well has solid collision")
	await key(KEY_E)
	check(session.water_full, "E at the well fills the water jug")
	player.position = Vector2(258, 284)
	await frames(2)
	await key(KEY_E)
	check(session.watered and not session.water_full, "E at the field irrigates and consumes the water")
	check(not game.get_node("Homestead").plots[0].dry, "irrigation updates the visible ground state")
	player.position = Vector2(432, 292)
	await frames(2)
	await move(["move_up"], 30)
	check(player.position.y > 282, "the closed gate blocks entry")
	await key(KEY_E)
	check(session.gate_open and world.gate_body.collision_layer == 0, "opening the gate clears its collider")
	await move(["move_up"], 25)
	check(player.position.y < 272, "the player can walk through the open gate")
	player.position = Vector2(432, 274)
	await frames(2)
	await key(KEY_E)
	check(session.gate_open, "the gate cannot close onto a resident")
	player.position = Vector2(447, 240)
	game.get_node("Inventory").exchange(player.resident_id, {}, {"wheat": 1})
	await frames(2)
	await key(KEY_E)
	check(world.pigs.any(func(pig: CharacterBody2D) -> bool: return pig.feeding_time > 6), "paid feeding attracts the selected pig or trough herd")
	check(not game.get_node("Inventory").has_item(player.resident_id, "wheat"), "one E feeding consumes exactly one grain")
	player.position = Vector2(432, 292)
	await frames(2)
	await key(KEY_E)
	check(not session.gate_open and world.gate_body.collision_layer == 1, "closing the clear gate restores collision")
	for resident: CharacterBody2D in world.residents:
		resident.set_physics_process(true)
	await key(KEY_TAB)
	check(session.selected == 1 and world.active_resident == world.residents[1], "Tab switches to the second resident")
	check(not world.residents[0].controlled and world.residents[1].controlled, "only one resident accepts player input")
	world.active_resident.position = Vector2(340, 310)
	await frames(2)
	await move(["move_right"], 20)
	check(world.active_resident.position.x > 356, "the newly selected resident can move")
	await key(KEY_1)
	check(session.selected == 0, "number keys select residents")
	await key(KEY_3)
	check(world.active_resident.resident_id == "chief_priest", "3 selects the village chief and priest")
	world.active_resident.position = Vector2(570, 380)
	await frames(2)
	await move(["move_right"], 20)
	check(world.active_resident.position.x > 586, "the chief can be controlled and moved")
	await key(KEY_TAB)
	check(session.selected == 0, "Tab wraps across the dynamic playable roster")
	await key(KEY_TAB, true)
	check(session.selected == 2, "Shift Tab cycles backward")
	await key(KEY_1)
	world.active_resident.position = Vector2(340, 310)
	var hud: CanvasLayer = game.get_node("HUD")
	await key(KEY_C)
	check(session.roster_open and hud.roster_root.visible and hud.roster_buttons.size() == 3, "C opens a three-character panel without NPCs")
	var paused_position: Vector2 = world.active_resident.position
	await move(["move_right"], 10)
	check(world.active_resident.position.distance_to(paused_position) < 0.1, "the roster prevents accidental player movement")
	hud.roster_buttons[0].pressed.emit()
	await frames(2)
	check(session.selected == 0 and not session.roster_open, "the first character row selects its own character")
	await key(KEY_C)
	hud.roster_buttons[2].pressed.emit()
	await frames(2)
	check(session.selected == 2 and not session.roster_open, "clicking the chief's row selects him and closes the panel")
	await key(KEY_C)
	await key(KEY_ESCAPE)
	check(not session.roster_open, "Escape closes the character panel")
	world.active_resident.position = Vector2(548, 332)
	await frames(2)
	await key(KEY_E)
	check(world.altar.ceremony_time > 3, "the chief can perform a ceremony at the altar")
	check(session.gifts.opened, "the altar ritual menu opens over the ceremony")
	session.gifts.close()
	await frames(2)
	check(not session.gifts.opened and not paused, "closing the altar ritual menu resumes the village")
	var hunter: CharacterBody2D = world.get_node("VillageObjects/alie")
	world.active_resident.position = hunter.position + Vector2(0, 16)
	await frames(2)
	await key(KEY_E)
	check(session.notice.contains("阿猎"), "NPC villagers offer proximity dialogue")
	var live_zoom: Vector2 = world.camera.zoom
	await key(KEY_M)
	check(session.overview and paused and world.streamer.overview.visible and not world.visible and world.camera.zoom == live_zoom, "M presents an independent full map and pauses the world without zooming live scenes")
	await key(KEY_M)
	check(not session.overview and world.camera.zoom == live_zoom, "M restores the following camera")
	world.active_resident.position = Vector2(2040, 1580)
	await frames(2)
	await move(["move_right", "move_down"], 60)
	check(world.active_resident.position.y < 1593, "expanded bottom boundary blocks escape")
	await key(KEY_1)
	var npc: CharacterBody2D = world.residents[1]
	world.active_resident.position = Vector2(340, 310)
	npc.position = Vector2(432, 292)
	npc.patrol_index = 0
	npc.idle_time = 0.0
	npc.navigation = PackedVector2Array()
	var npc_starts: Dictionary = {}
	for villager: CharacterBody2D in world.residents.filter(func(r: CharacterBody2D) -> bool: return not r.can_control):
		npc_starts[villager.resident_id] = villager.position
	Engine.time_scale = 4.0
	await frames(200)
	Engine.time_scale = 1.0
	print("NPC navigation result: ", npc.position, " route=", npc.patrol_index, " remaining=", npc.navigation.size(), " slides=", npc.get_slide_collision_count())
	check(npc.position.x < 360 and npc.position.y < 265, "the inactive resident routes around a closed pig pen")
	var moved_npcs := 0
	for villager: CharacterBody2D in world.residents.filter(func(r: CharacterBody2D) -> bool: return not r.can_control):
		check(not villager.controlled and not villager.can_control, "ordinary villagers never become player-controlled")
		if villager.position.distance_to(npc_starts[villager.resident_id]) > 3:
			moved_npcs += 1
	check(moved_npcs >= 8, "new villagers autonomously move through their neighborhoods")
	for pig in world.pigs:
		check(pig.pen_bounds.grow(0.01).has_point(pig.position), "wandering pigs stay inside the pen")
	check(hud.status_label.text.contains(world.active_resident.resident_name), "HUD subscribes to the selected resident")
	if failures.is_empty():
		print("VILLAGE_SMOKE_OK: 8 reachable houses, seven atlas styles and a kitchen chimney, 13 residents / 3 controllable / 10 NPCs, chief ceremony, dynamic roster, panel, dialogue, movement, collisions, farming, pigs, expanded boundaries and NPC navigation")
		quit(0)
	else:
		print("VILLAGE_SMOKE_FAILED ", failures)
		quit(1)
