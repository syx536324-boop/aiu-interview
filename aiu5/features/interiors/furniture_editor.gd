# Handles room editing gestures and commits collision-checked furniture placements.
extends Node

signal changed
signal message(text: String)
const Furniture := preload("res://features/interiors/furniture.gd")
const DEPLOYABLE := ["campfire","workbench","fence","building_bench","bed","cabinet","table","chair","chest"]
const Catalog := preload("res://features/interiors/furniture_catalog.gd")
var world: Node2D
var interiors: Node2D
var inventory: Node
var grounds: Node2D
var deploy_commit: Callable
var removal_guard: Callable
var gift_bed_index := -1
var opened := false
var room: Node2D
var original: Node2D
var ghost: Node2D
var preview_at := Vector2.INF
var preview_direction := -1
var preview_revision := -1
var preview_check_left := 0.0
var hint := "点击家具搬动；新放置需背包成品，回收会返还。"

func start(village: Node2D, rooms: Node2D, items: Node) -> void:
	world = village
	interiors = rooms
	inventory = items

func open() -> bool:
	if world.home_data(world.active_resident.room_id).get("tower",false) or world.home_data(world.active_resident.room_id).get("skill_hut",false):
		message.emit("矿洞内先专注采矿，家具可在地表和房屋布置。")
		return false
	var id: String = world.active_resident.room_id
	room = grounds if id == "" else interiors.rooms[id]
	opened = true
	hint = "点击家具搬动；新放置需背包成品，回收会返还。"
	changed.emit()
	return true

func close() -> void:
	cancel_selection()
	opened = false
	changed.emit()

func cancel_selection() -> void:
	if is_instance_valid(original):
		original.modulate = Color.WHITE
	if is_instance_valid(ghost):
		room.remove_child(ghost)
		ghost.queue_free()
	original = null
	ghost = null
	gift_bed_index = -1
	hint = "点击家具搬动；新放置需背包成品，回收会返还。"
	changed.emit()

func choose(kind: String) -> void:
	if not opened:
		return
	cancel_selection()
	if world.active_resident.room_id=="mine" and kind!="campfire": return
	if kind == "building_bench" and room != grounds: return
	if kind == "stove" or (room == grounds and kind not in ["campfire","workbench", "fence", "building_bench"]):
		return
	if kind in DEPLOYABLE and not inventory.has_item(world.active_resident.resident_id, kind):
		message.emit("背包没有该部署物品。")
		return
	if not Catalog.TYPES.has(kind):
		return
	var dimensions: Vector2 = Catalog.TYPES[kind]["size"]
	_create_ghost({"id": "preview", "kind": kind, "at": [0, 0], "size": [dimensions.x, dimensions.y], "orientation": 0, "variant": room.fixtures.size() % 3})
	changed.emit()

func _create_ghost(record: Dictionary) -> void:
	preview_at = Vector2.INF
	preview_check_left = 0
	ghost = Furniture.new()
	ghost.configure_record(record)
	ghost.preview = true
	ghost.modulate.a = 0.75
	ghost.z_index = 50
	room.add_child(ghost)

func pick(fixture: Node2D) -> void:
	if fixture.public_fixture and fixture.kind != "workbench":
		message.emit("该公共设施不能搬动或回收。")
		return
	if fixture.kind == "stove":
		message.emit("灶台固定在灶房内。")
		return
	cancel_selection()
	original = fixture
	original.modulate.a = 0.3
	_create_ghost(fixture.record())
	changed.emit()

func point_at(point: Vector2) -> void:
	if not is_instance_valid(ghost):
		return
	var at: Vector2 = (point - ghost.size / 2).snapped(Vector2(4, 4))
	if at == preview_at and ghost.orientation == preview_direction and room.navigation.revision == preview_revision and preview_check_left > 0: return
	ghost.set_placement(at, ghost.orientation)
	var error: String = room.placement_error(ghost, original)
	preview_at = at
	preview_direction = ghost.orientation
	preview_revision = room.navigation.revision
	preview_check_left = 0.2
	ghost.preview_valid = error == ""
	ghost.queue_redraw()
	hint = error if error != "" else "绿色位置可放置 · 左键确认 · R 旋转 · 右键取消"

func rotate_selected() -> void:
	if is_instance_valid(ghost):
		if ghost.kind == "building_bench":
			message.emit("建筑台按固定朝向预留房屋用地，无需旋转。")
			return
		ghost.set_placement(ghost.visual_bounds().position, ghost.orientation + 1)
		point_at(room.get_global_mouse_position() - room.global_position)
		changed.emit()

func place() -> bool:
	if not opened or not is_instance_valid(ghost):
		return false
	var error: String = room.placement_error(ghost, original)
	if error != "":
		message.emit(error)
		return false
	var before: Dictionary = inventory.export_data()
	if is_instance_valid(original):
		room.relocate(original, ghost.visual_bounds().position, ghost.orientation)
	else:
		var bag: Array = inventory.ensure_bag(world.active_resident.resident_id)
		var index := gift_bed_index
		if index < 0:
			for i in range(bag.size()):
				if bag[i].get("item","")==ghost.kind: index=i; break
		if index < 0 or index >= bag.size() or bag[index].get("item","")!=ghost.kind:
			message.emit("背包没有该部署物品。")
			return false
		var data: Dictionary = ghost.record()
		var record: Dictionary = bag[index].duplicate(true)
		record.count = 1
		data["gift_origin"] = record
		if ghost.kind=="workbench":data["bench_level"]=clampi(int(record.get("bench_level",1)),1,3)
		bag[index].count -= 1
		if bag[index].count <= 0: bag[index] = {}
		data["id"] = room.allocate_id()
		room.add_fixture(data)
	if not before.is_empty() and deploy_commit.is_valid():
		inventory.layouts[room.room_id] = room.export_layout()
	else:
		inventory.store_layout(room.room_id, room.export_layout())
	cancel_selection()
	if not before.is_empty() and deploy_commit.is_valid(): return deploy_commit.call(before,"家具已部署，成品已从背包扣除。")
	message.emit("家具已放置并保存。")
	return true

func remove_selected() -> bool:
	if not opened or not is_instance_valid(original):
		cancel_selection()
		return false
	if removal_guard.is_valid() and not removal_guard.call(original):
		message.emit("工作台正在制作或有成品待领，完成并领取后才能回收。")
		return false
	if original.is_storage() and not inventory.container_empty(original.fixture_id):
		message.emit("请先取空柜子或箱子里的物品，再移除家具。")
		return false
	var before: Dictionary = inventory.export_data()
	var record: Dictionary = original.gift_origin.duplicate(true)
	if record.is_empty(): record={"item":original.kind,"count":1}
	if original.kind=="workbench":record["bench_level"]=original.bench_level
	if not inventory.insert_record(world.active_resident.resident_id,record):
		message.emit("背包已满，家具仍保留在原处。")
		return false
	var fixture := original
	original = null
	cancel_selection()
	room.remove_fixture(fixture)
	if not before.is_empty() and deploy_commit.is_valid():
		inventory.layouts[room.room_id] = room.export_layout()
	else:
		inventory.store_layout(room.room_id, room.export_layout())
	if not before.is_empty() and deploy_commit.is_valid(): return deploy_commit.call(before,"家具已回收，成品已返还背包。")
	message.emit("家具已移除。")
	return true

func _process(delta: float) -> void:
	preview_check_left -= delta
	if opened and is_instance_valid(ghost):
		point_at(room.get_global_mouse_position() - room.global_position)

func _unhandled_input(event: InputEvent) -> void:
	if not opened:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = room.get_global_transform_with_canvas().affine_inverse() * event.position
			if is_instance_valid(ghost):
				point_at(point)
				place()
			else:
				var fixture: Node2D = room.furniture_at(point)
				if fixture != null:
					pick(fixture)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_selection()
		get_viewport().set_input_as_handled()

func snapshot() -> Dictionary:
	return {"mine":world.active_resident.room_id=="mine","outdoors": room == grounds, "open": opened, "hint": hint, "holding": is_instance_valid(ghost), "selected": ghost.display_name() if is_instance_valid(ghost) else "", "existing": is_instance_valid(original)}

func choose_gift_bed(index: int) -> void:
	if not opened or room == grounds: return
	choose("bed")
	if is_instance_valid(ghost): gift_bed_index = index
