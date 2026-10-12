# Exercises mouse editing, inventory limits, storage identity and saved state across fresh scenes.
extends SceneTree

var failures: Array[String] = []
var game: Node
var world: Node2D
var session: Node
var items: Node
var editor: Node
var ui: CanvasLayer
var room: Node2D
const TEST_PATH := "res://.runtime/test-belongings.json"

func _initialize() -> void:
	create_timer(30).timeout.connect(func() -> void: push_error("BELONGINGS_SMOKE_TIMEOUT"); quit(2))
	OS.set_environment("AIU5_STATE_PATH", TEST_PATH)
	OS.set_environment("AIU5_PROFILE_PATH", "res://.runtime/test-unused-names.cfg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
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
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)

func click_screen(point: Vector2, shift := false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		event.shift_pressed = shift
		Input.parse_input_event(event)
		await frames(1)

func click_button(button: Button) -> void:
	await click_screen(button.get_global_rect().get_center())

func load_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	world = game.get_node("World")
	session = game.get_node("Session")
	items = game.get_node("Inventory")
	editor = game.get_node("FurnitureEditor")
	ui = game.get_node("Belongings")
	await frames(3)
	for resident: CharacterBody2D in world.residents:
		if resident != world.active_resident:
			resident.set_physics_process(false)

func enter_house(id: String) -> void:
	if world.active_resident.room_id == id:
		room = game.get_node("Interiors").rooms[id]
		return
	world.active_resident.position = world.home_data(id)["door"] + Vector2(0, 4)
	await frames(2)
	await key(KEY_E)
	room = game.get_node("Interiors").rooms[id]

func run_checks() -> void:
	await load_game()
	# Explicit prepared items keep storage/rearrangement tests independent of starter grants.
	for resident in world.controllable:
		var prepared: Array = []
		for item: String in ["pickaxe", "hoe", "stone_axe", "watering_can", "bread", "book", "pork", "bucket", "workbench", "fence", "seeds", "rice_seeds", "wooden_cup"]:
			prepared.append({"item": item, "count": 5 if item=="bread" else 1})
		items.bags[resident.resident_id]=items._sanitize_slots(prepared)
	await key(KEY_F)
	check(editor.opened and not world.active_resident.input_enabled, "outside furniture mode supports deployment and pauses movement")
	await key(KEY_B)
	check(items.opened and ui.inventory_root.visible and ui.bag_buttons.size() == 21, "B opens real 21-slot bag UI")
	check(items.slots_for("bag").filter(func(slot: Dictionary) -> bool: return not slot.is_empty()).size() == 13, "thirteen explicitly prepared types are visible")
	var before: Vector2 = world.active_resident.position
	Input.action_press("move_right")
	await frames(8)
	Input.action_release("move_right")
	check(world.active_resident.position.distance_to(before) < 0.1, "bag prevents accidental movement")
	await click_button(ui.bag_buttons[0])
	await click_button(ui.bag_buttons[20])
	check(items.slots_for("bag")[0].is_empty() and items.slots_for("bag")[20]["item"] == "pickaxe", "real mouse clicks rearrange bag")
	await key(KEY_ESCAPE)
	await enter_house("house")
	check(room.fixtures.size() == 6, "default five categories furnish old house")
	var kinds: Dictionary = {}
	for fixture in room.fixtures:
		kinds[fixture.kind] = true
	check(kinds.size() == 5 and kinds.has("bed") and kinds.has("chair"), "all five furniture categories present")
	var cabinet: Node2D = room.fixtures[1]
	var cabinet_id: String = cabinet.fixture_id
	world.active_resident.position = Vector2(164, 70)
	await frames(2)
	await key(KEY_E)
	check(items.opened and items.container_id == cabinet_id and ui.storage_buttons.size() == 21, "E at cabinet opens its 21 storage slots")
	await click_button(ui.bag_buttons[4])
	await click_button(ui.storage_buttons[0])
	check(items.ensure_container(cabinet_id)[0] == {"item": "bread", "count": 5}, "real mouse stores bread in cabinet")
	check(items.ensure_bag("ali")[4].is_empty(), "stored bread leaves personal bag")
	var shift_event := InputEventKey.new()
	shift_event.keycode = KEY_SHIFT
	shift_event.physical_keycode = KEY_SHIFT
	shift_event.pressed = true
	Input.parse_input_event(shift_event)
	await click_button(ui.storage_buttons[0])
	shift_event = InputEventKey.new()
	shift_event.keycode = KEY_SHIFT
	shift_event.physical_keycode = KEY_SHIFT
	Input.parse_input_event(shift_event)
	check(items.ensure_container(cabinet_id)[0].is_empty() and items.ensure_bag("ali")[0]["item"] == "bread", "quick take uses first empty bag slot")
	items.slot_clicked("bag", 0, true)
	check(items.ensure_container(cabinet_id)[0]["count"] == 5, "quick deposit restores cabinet stack")
	# A full container accepts only remaining room in a compatible stack.
	var storage: Array = items.ensure_container(cabinet_id)
	for i in range(21):
		storage[i] = {"item": "book", "count": 10}
	storage[0] = {"item": "bread", "count": 98}
	var bag: Array = items.ensure_bag("ali")
	bag[4] = {"item": "bread", "count": 5}
	items.slot_clicked("bag", 4, true)
	check(storage[0]["count"] == 99 and bag[4]["count"] == 4 and storage.size() == 21, "partial merge respects stack and slot capacity without item loss")
	var snapshot: Array = storage.duplicate(true)
	items.slot_clicked("bag", 4, true)
	check(storage == snapshot and bag[4]["count"] == 4, "full storage leaves items unchanged")
	for i in range(21):
		storage[i] = {}
	storage[0] = {"item": "bread", "count": 5}
	check(items.save_state() == OK, "state can replace existing save atomically")
	await key(KEY_ESCAPE)
	world.active_resident.position = room.safe_spawn()
	await frames(1)
	await key(KEY_F)
	check(editor.opened and ui.toolbar.visible and not world.active_resident.input_enabled, "F opens furniture toolbar and pauses movement")
	editor.set_process(false)
	await click_screen(room.get_global_transform_with_canvas() * cabinet.visual_bounds().get_center())
	check(editor.original == cabinet and editor.ghost != null, "real mouse selects existing cabinet")
	var unchanged: Vector2 = cabinet.position
	editor.point_at(Vector2(-20, 10))
	check(not editor.place() and cabinet.position == unchanged, "out-of-room placement is rejected without moving original")
	editor.point_at(room.exit_point())
	check(not editor.place(), "doorway stays unobstructed")
	editor.point_at(room.fixtures[0].visual_bounds().get_center())
	check(not editor.place(), "furniture overlap is rejected")
	check(not editor.remove_selected() and room.fixtures.has(cabinet), "filled cabinet cannot be removed")
	await key(KEY_R)
	check(editor.ghost.orientation == 1, "R rotates furniture preview")
	# Place the cabinet in a free patch of floor, retaining its ID and stored bread.
	var new_at := Vector2(156, 32)
	editor.point_at(new_at + editor.ghost.size / 2)
	check(editor.place(), "cabinet can be moved and rotated")
	check(cabinet.fixture_id == cabinet_id and cabinet.orientation == 1 and items.ensure_container(cabinet_id)[0]["count"] == 5, "moving full cabinet preserves storage identity and contents")
	await frames(2)
	check(cabinet.get_node("FurnitureBody").get_child(0).shape.size.x == cabinet.size.x - 4, "moved cabinet collider uses rotated footprint")
	var bounds: Rect2 = cabinet.collision_bounds()
	check(world.active_resident.test_move(Transform2D(0, room.global_position + Vector2(bounds.get_center().x, bounds.end.y + 8)), Vector2(0, -bounds.size.y - 14)), "moved cabinet blocks actual player physics at new location")
	# Move again using a mouse event; clicking a preview commits it at the clicked location.
	editor.pick(cabinet)
	await click_screen(room.get_global_transform_with_canvas() * (new_at + cabinet.size / 2))
	check(editor.ghost == null and cabinet.position != unchanged, "real mouse commits placement")
	items.exchange("ali", {}, {"chair": 1})
	await click_button(ui.furniture_buttons["chair"])
	check(editor.ghost != null and editor.ghost.kind == "chair", "catalogue button creates furniture preview")
	var count: int = room.fixtures.size()
	editor.point_at(Vector2(72, 116))
	check(editor.place() and room.fixtures.size() == count + 1, "catalogue furniture can be added")
	var added: Node2D = room.fixtures[room.fixtures.size() - 1]
	editor.pick(added)
	check(editor.remove_selected() and room.fixtures.size() == count, "empty furniture can be removed")
	items.exchange("ali", {}, {"bed": 1})
	editor.choose("bed")
	await key(KEY_ESCAPE)
	check(editor.opened and editor.ghost == null, "Escape cancels preview before closing mode")
	await key(KEY_F)
	check(not editor.opened and world.active_resident.input_enabled, "F finishes furniture editing")
	await key(KEY_2)
	check(not items.opened and not editor.opened, "switch closes previous actor's menus")
	await key(KEY_B)
	check(items.slots_for("bag")[4]["count"] == 5 and items.slots_for("bag")[0]["item"] == "pickaxe", "female has an independent prepared bag")
	await key(KEY_ESCAPE)
	world.active_resident.set_physics_process(true)
	await enter_house("house")
	var near: Vector2 = cabinet.visual_bounds().position + Vector2(-8, cabinet.size.y / 2 + 3)
	world.active_resident.position = near
	await frames(2)
	await key(KEY_E)
	check(items.container_id == cabinet_id and items.slots_for("storage")[0]["count"] == 5, "another character accesses moved cabinet contents")
	items.slot_clicked("storage", 0, true)
	check(items.ensure_bag("heya")[4]["count"] == 10, "another character can take and merge shared stored items")
	items.slot_clicked("bag", 4, true)
	var saved_layout: Array = room.export_layout()
	check(items.save_state() == OK, "final inventory and layout saved")
	game.queue_free()
	await frames(2)
	await load_game()
	check(items.ensure_bag("ali")[20]["item"] == "pickaxe", "fresh scene restores rearranged personal bag")
	check(items.ensure_container(cabinet_id)[0]["count"] == 10, "fresh scene restores shared storage")
	await enter_house("house")
	check(room.export_layout() == saved_layout, "fresh scene restores exact furniture IDs, positions, orientations and removals")
	# Cabinet and chest have distinct 21-slot stores, even within the same room.
	var chest: Node2D = room.fixtures[5]
	check(chest.is_storage() and items.ensure_container(chest.fixture_id).size() == 21 and items.container_empty(chest.fixture_id), "chest has independent empty 21-slot storage")
	world.active_resident.position = room.exit_point()
	await key(KEY_E)
	await enter_house("stone_house")
	await key(KEY_F)
	for fixture: Node2D in room.fixtures.duplicate():
		editor.pick(fixture)
		check(editor.remove_selected(), "empty room can remove each initial furniture piece")
	await key(KEY_F)
	game.queue_free()
	await frames(2)
	await load_game()
	await enter_house("stone_house")
	check(room.fixtures.is_empty(), "saved empty room remains empty after restart")
	check(not room.navigation.find_path(room.safe_spawn(), Vector2(28, 60)).is_empty(), "empty room still has working navigation")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	if failures.is_empty():
		print("BELONGINGS_SMOKE_OK: five furniture types, mouse pick/place and catalogue, rotation, safe placement, filled-container protection, seven items, independent bags, 21-slot storage, swaps/merge/full capacity conservation, shared access and durable layout/storage reload")
		quit(0)
	else:
		print("BELONGINGS_SMOKE_FAILED: ", failures)
		quit(1)
