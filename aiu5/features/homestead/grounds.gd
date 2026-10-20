# Adapts outdoor building to the furniture editor and protects paths, facilities and farmland.
extends Node2D

const Furniture := preload("res://features/interiors/furniture.gd")
const Land := preload("res://features/homestead/land.gd")
const Herd := preload("res://features/livestock/herd_catalog.gd")
const Shed := preload("res://features/livestock/shed.gd")
const Geography := preload("res://features/landscape/landscape.gd")
var world: Node2D
var homestead: Node
var fixtures: Array[Node2D] = []
var room_id := "outdoors"
var next_id := 0
# Preplaced benches are seeded once, including when their recovered item is deployed elsewhere.
var retired_fixtures: Dictionary = {}
var navigation: RefCounted:
	get: return world.navigation

func start(village: Node2D, farming: Node, records: Array) -> void:
	world = village
	homestead = farming
	for record: Dictionary in records:
		if record.get("kind", "") in ["workbench", "fence", "fence_gate", "building_bench", "campfire"]:
			add_fixture(record)
	world.refresh_obstacles()

func allocate_id() -> String:
	var id := "outdoors:f" + str(next_id)
	next_id += 1
	while fixtures.any(func(f: Node2D) -> bool: return f.fixture_id == id):
		id = "outdoors:f" + str(next_id)
		next_id += 1
	return id

func add_fixture(record: Dictionary) -> Node2D:
	var fixture := Furniture.new()
	fixture.configure_record(record)
	world.objects.add_child(fixture)
	fixtures.append(fixture)
	_collider(fixture)
	return fixture

func _collider(fixture: Node2D) -> void:
	var old := fixture.get_node_or_null("FurnitureBody")
	if old != null:
		fixture.remove_child(old)
		old.queue_free()
	var rect: Rect2 = fixture.collision_bounds()
	var body: StaticBody2D = world._body(fixture, rect.get_center() - fixture.position, rect.size)
	body.name = "FurnitureBody"
	if fixture.kind in ["fence","fence_gate"]: body.set_meta("barrier_fixture",fixture)
	world.refresh_obstacles()

func relocate(fixture: Node2D, at: Vector2, direction: int) -> void:
	fixture.set_placement(at, direction)
	_collider(fixture)

func remove_fixture(fixture: Node2D) -> void:
	if fixture.public_fixture and fixture.kind == "workbench": retired_fixtures[fixture.fixture_id] = true
	fixtures.erase(fixture)
	if fixture.get_parent() != null: fixture.get_parent().remove_child(fixture)
	fixture.queue_free()
	world.refresh_obstacles()

func export_layout() -> Array:
	var records: Array = []
	for fixture in fixtures: records.append(fixture.record())
	return records

func furniture_at(point: Vector2) -> Node2D:
	for fixture in fixtures:
		if fixture.visual_bounds().has_point(point): return fixture
	return null

func nearby(actor: CharacterBody2D) -> Dictionary:
	var nearest: Dictionary = {}
	var distance := 22.0
	for fixture in fixtures:
		if fixture.kind not in ["workbench","building_bench","campfire","fence_gate"]: continue
		var bounds: Rect2 = fixture.collision_bounds()
		var point: Vector2 = actor.position + Vector2(0, -3)
		var gap := point.distance_to(point.clamp(bounds.position, bounds.end))
		if gap < distance:
			distance = gap
			nearest = {"id": fixture.kind, "fixture": fixture, "label": fixture.display_name(), "action": "开 / 关门" if fixture.kind=="fence_gate" else "点亮 / 熄灭" if fixture.kind=="campfire" else "建造" if fixture.kind=="building_bench" else "分类合成", "description": "E切换点亮/熄灭；照明96×96世界像素，火系三级H可点亮。" if fixture.kind=="campfire" else "E投入材料建造木屋、石屋、铁屋或箭楼" if fixture.kind=="building_bench" else "E打开分类界面，选物品后确认合成；制作需60秒"}
	return nearest

func land_error(bounds: Rect2, actor: Node2D, building := true, original: Node2D = null) -> String:
	if not world.BOUNDS.grow(-16).encloses(bounds): return "请在地图范围内的空地上放置。"
	if Geography.protected(bounds): return "请保留河流、桥梁、高山和祭祀广场的空间。"
	if world.settlement!="starter_v2" and bounds.intersects(Herd.SHEEP_PASTURE.grow(4)): return "请保留羊群的活动与喂食空间。"
	if world.settlement!="starter_v2" and bounds.intersects(Shed.BOUNDS.grow(4)): return "请保留牛棚、食槽和出入口的空间。"
	if bounds.intersects(Land.LAKE.grow(7)): return "湖泊与岸边取水处需要保持畅通。"
	if world.settlement!="starter_v2" and bounds.intersects(Rect2(377, 202, 112, 82)): return "请保留猪圈、食槽和木门的空间。"
	for key: String in world.points:
		if key.begins_with("wood:") or key.begins_with("animal:") or key == "river": continue
		if bounds.grow(16).has_point(world.points[key].position): return "请为房门、设施和取水点留出通路。"
	if building:
		for p: Dictionary in homestead.plots:
			if bounds.intersects(Land.bounds(p).grow(2)): return "农田上不能搭建工作台或围栏。"
	for occupied: Rect2 in world.logical_obstacles(world.gate_visual.open, original):
		if occupied.grow(2).intersects(bounds): return "这里已有建筑、树木或其他障碍。"

	for resident in world.residents:
		if resident.room_id != "" or resident.dead: continue
		if not building and resident == actor: continue
		if bounds.grow(5).has_point(resident.position + Vector2(0, -3)): return "这里有村民，请换一个位置。"
	return ""

func placement_error(ghost: Node2D, original: Node2D = null) -> String:
	if ghost.kind not in ["workbench", "fence", "fence_gate", "building_bench", "campfire"]: return "户外支持部署工作台和围栏。"
	var error := land_error(ghost.visual_bounds(), world.active_resident, true, original)
	if error != "": return error
	if ghost.kind=="fence_gate": return ""
	var obstacles: Array[Rect2] = world.logical_obstacles(world.gate_visual.open, original)
	# An isolated rectangle in open ground cannot close an existing passage.
	if not obstacles.any(func(rect: Rect2) -> bool: return ghost.collision_bounds().grow(12).intersects(rect)): return ""
	# Gates may deliberately enclose livestock; test with those entrances open.
	var removed: Array[Rect2] = []
	if is_instance_valid(original): removed.append(original.collision_bounds())
	for existing in fixtures:
		if existing.kind == "fence_gate": removed.append(existing.collision_bounds())
	var targets: Array[Vector2] = []
	for resident in world.residents:
		if resident.room_id == "" and not resident.dead: targets.append(resident.position)
	for point: Dictionary in world.points.values(): targets.append(point.position)
	# Compare compressed connected regions, never run all-map A* or modify the live grid.
	var accessible: bool = world.navigation.preserves_access(Vector2(326,282), targets, removed, ghost.collision_bounds())
	return "围栏不能封死村民或设施的通路，请留下出入口。" if not accessible else ""

func restore(records: Array, retired: Dictionary = {}) -> void:
	for fixture in fixtures.duplicate(): remove_fixture(fixture)
	retired_fixtures = retired.duplicate(true)
	for record: Dictionary in records: add_fixture(record)
