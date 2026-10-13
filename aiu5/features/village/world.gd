# Assembles the arid settlement, colliders, residents, livestock and following camera.
extends Node2D

const Terrain := preload("res://features/village/terrain.gd")
const Fence := preload("res://features/village/fence.gd")
const WellDetail := preload("res://features/village/well_detail.gd")
const Trough := preload("res://features/village/trough.gd")
const Navigation := preload("res://features/village/navigation.gd")
const Layout := preload("res://features/village/layout.gd")
const Altar := preload("res://features/village/altar.gd")
const Haze := preload("res://features/weather/haze.gd")
const Resident := preload("res://features/actors/resident.gd")
const Pig := preload("res://features/actors/pig.gd")
const DESERT := preload("res://assets/ninja_adventure/Backgrounds/Tilesets/TilesetDesert.png")
const NATURE := preload("res://assets/ninja_adventure/Backgrounds/Tilesets/TilesetNature.png")
const ELEMENT := preload("res://assets/ninja_adventure/Backgrounds/Tilesets/TilesetElement.png")
const HOUSE := preload("res://assets/ninja_adventure/Backgrounds/Tilesets/TilesetHouse.png")
const PINK_PIG := preload("res://assets/ninja_adventure/Actor/Animal/Pig/SpriteSheetPink.png")
const BLACK_PIG := preload("res://assets/ninja_adventure/Actor/Animal/Pig/SpriteSheetBlack.png")
const KitchenDetail := preload("res://features/homestead/kitchen_detail.gd")
const SIZE := Layout.SIZE
const MIN := Layout.MIN
const BOUNDS := Layout.BOUNDS
const POINTS := {
	"well": {"position": Vector2(334, 207), "radius": 24.0, "label": "水井", "action": "取水"},
	"farm": {"position": Vector2(258, 284), "radius": 32.0, "label": "小农田", "action": "浇灌"},
	"gate": {"position": Vector2(432, 281), "radius": 23.0, "label": "猪圈木门", "action": "开 / 关门"},
	"trough": {"position": Vector2(458, 236), "radius": 23.0, "label": "食槽", "action": "喂猪"},
	"altar": {"position": Vector2(548, 332), "radius": 25.0, "label": "祭台", "action": "查看 / 祭礼"}
}
var settlement := "expanded"
var resource_seed := 1
var homes: Array[Dictionary] = []
var terrain: Node2D
var objects: Node2D
var camera: Camera2D
var haze: Node2D
var residents: Array[CharacterBody2D] = []
var controllable: Array[CharacterBody2D] = []
var houses: Array[Node2D] = []
var points: Dictionary = POINTS.duplicate(true)
var pigs: Array[CharacterBody2D] = []
var cows: Array[CharacterBody2D] = []
var extra_homes: Dictionary = {}
var active_resident: CharacterBody2D
var gate_visual: Node2D
var gate_body: StaticBody2D
var overview := false
var navigation := Navigation.new()
var altar: Node2D
var forest_altar: Node2D
var player_input_enabled := true
var streamer: Node
var obstacle_bodies: Dictionary = {}

func _ready() -> void:
	for home: Dictionary in Layout.HOMES:
		if settlement != "starter" or home.get("always", false) or home.id in ["kitchen", "house", "round_house", "herb_house"]: homes.append(home)
	terrain = Terrain.new()
	terrain.name = "SandAndFarmland"
	add_child(terrain)
	objects = Node2D.new()
	objects.name = "VillageObjects"
	objects.y_sort_enabled = true
	add_child(objects)
	_build_boundaries()
	_build_cliff()
	haze = Haze.new()
	add_child(haze)
	haze.start(self)
	_build_landmarks()
	_build_pen()
	_scatter_desert_props()
	_rebuild_navigation(false)
	_spawn_residents()
	_spawn_pigs()
	camera = Camera2D.new()
	camera.name = "FollowingCamera"
	# Closer following view: the 640x400 viewport shows 492x308 world pixels at 1.3x zoom.
	camera.zoom = Vector2(1.3, 1.3)
	camera.limit_left = int(MIN.x)
	camera.limit_top = int(MIN.y)
	camera.limit_right = int(SIZE.x)
	camera.limit_bottom = int(SIZE.y)
	add_child(camera)
	set_active(0)
	# Centred on the character: the viewport then shows 492x308 world pixels, and the shortened
	# 150-pixel bow range still fits in every direction instead of being cut by the screen.
	camera.position = active_resident.position

func _process(_delta: float) -> void:
	if not overview:
		camera.position = active_resident.position.round()

func set_active(index: int) -> void:
	for resident in residents:
		resident.set_controlled(false)
	active_resident = controllable[clampi(index, 0, controllable.size() - 1)]
	if is_instance_valid(streamer): streamer.ensure_actor(active_resident)
	active_resident.set_controlled(true)
	active_resident.input_enabled = player_input_enabled

func set_player_input_enabled(value: bool) -> void:
	player_input_enabled = value
	active_resident.input_enabled = value

func get_roster() -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	for i in range(controllable.size()):
		var resident := controllable[i]
		var area := "井田区" if resident.position.x < 385 and resident.position.y < 370 else "祭台广场"
		if resident.position.y > 400:
			area = "南侧住区"
		elif resident.position.x > 620:
			area = "东侧住区"
		if resident.position.x < 0: area = "西岸森林"
		if resident.room_id != "":
			area = str(home_data(resident.room_id).get("name", "房屋")) + "内"
		roster.append({"index": i, "id": resident.resident_id, "name": resident.resident_name, "role": resident.role_label, "sheet": resident.sheet, "area": "已阵亡" if resident.dead else area, "dead": resident.dead})
	return roster

func home_data(id: String) -> Dictionary:
	if extra_homes.has(id): return extra_homes[id]
	for home: Dictionary in homes:
		if home["id"] == id:
			return home
	return {}

func founder_names() -> Dictionary:
	return {"male": controllable[0].resident_name, "female": controllable[1].resident_name}

func apply_founder_names(male: String, female: String) -> void:
	controllable[0].resident_name = male
	controllable[1].resident_name = female

func safe_return_position(preferred: Vector2, home_id: String) -> Vector2:
	var home := home_data(home_id)
	var door: Vector2 = home["door"]
	for point: Vector2 in [preferred, door + Vector2(0, 8), door + Vector2(-12, 10), door + Vector2(12, 10), door + Vector2(-20, 14), door + Vector2(20, 14), door + Vector2(0, 22)]:
		var query := PhysicsShapeQueryParameters2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 3.5
		query.shape = shape
		query.transform = Transform2D(0, point + Vector2(0, -3))
		query.collision_mask = 1 | 2
		if get_world_2d().direct_space_state.intersect_shape(query).is_empty():
			return point
	return door + Vector2(0, 22)

func set_overview(value: bool) -> void:
	overview = value
	if is_instance_valid(streamer): streamer.set_overview(value)


func nearest_point(position: Vector2) -> String:
	var nearest := ""
	var distance := INF
	for key: String in points:
		var source: Variant = points[key].get("source")
		var point: Vector2 = source.position if is_instance_valid(source) else points[key]["position"]
		var candidate := position.distance_to(point)
		if candidate < float(points[key]["radius"]) and candidate < distance:
			nearest = key
			distance = candidate
	if nearest == "":
		for resident in residents:
			if resident == active_resident or resident.room_id != "":
				continue
			var candidate := position.distance_to(resident.position)
			if candidate < 18 and candidate < distance:
				nearest = "npc:" + resident.resident_id
				distance = candidate
	return nearest

func point_info(key: String) -> Dictionary:
	if points.has(key):
		if key.begins_with("animal:") and is_instance_valid(streamer):
			var point: Dictionary = points[key].duplicate()
			point.description = streamer.session.livestock.detail(point.source)
			return point
		return points[key]
	for resident in residents:
		if key == "npc:" + resident.resident_id:
			return {"label": resident.resident_name, "action": "交谈", "description": resident.resident_name + "：" + resident.dialogue}
	return {}

func describe_point(key: String) -> String:
	var info := point_info(key)
	if key.begins_with("npc:"):
		for resident in residents:
			if key == "npc:" + resident.resident_id:
				resident.idle_time = 4.0
	return str(info.get("description", ""))

func water_farm() -> void:
	terrain.set_watered(true)

func set_gate_open(value: bool) -> void:
	gate_visual.open = value
	gate_visual.queue_redraw()
	gate_body.set_deferred("collision_layer", 0 if value else 1)
	_rebuild_navigation(value)
	for resident in residents:
		resident.navigation = PackedVector2Array()

func logical_obstacles(gate_open := false, excluded: Node = null) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for id in obstacle_bodies.keys():
		var body: StaticBody2D = obstacle_bodies[id].get_ref()
		if not is_instance_valid(body):
			obstacle_bodies.erase(id)
			continue
		if (body.collision_layer == 0 and body != gate_body) or (body == gate_body and gate_open) or body.get_parent() == excluded: continue
		if body.get_parent() != null and body.get_parent().is_queued_for_deletion(): continue
		var collision: CollisionShape2D = body.get_child(0)
		var shape: RectangleShape2D = collision.shape
		result.append(Rect2(body.global_position + collision.position - shape.size / 2, shape.size))
	return result

func _rebuild_navigation(gate_open: bool) -> void:
	# Modules may add their own bodies; register them once before regions are parked.
	for body: StaticBody2D in find_children("*", "StaticBody2D", true, false):
		obstacle_bodies[body.get_instance_id()] = weakref(body)
	navigation.rebuild(logical_obstacles(gate_open), SIZE, MIN)

func refresh_obstacles() -> void:
	_rebuild_navigation(gate_visual.open)
	for resident in residents:
		resident.navigation = PackedVector2Array()

func gate_is_clear() -> bool:
	for resident in residents:
		if resident.room_id != "":
			continue
		if Rect2(411, 266, 42, 17).has_point(resident.position):
			return false
	return true

func feed_pigs() -> void:
	for pig in pigs:
		pig.feed()

func _body(parent: Node2D, center: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 2 | 4
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	obstacle_bodies[body.get_instance_id()] = weakref(body)
	return body

func _build_boundaries() -> void:
	_body(self, Vector2(BOUNDS.get_center().x, MIN.y + 4), Vector2(BOUNDS.size.x, 8))
	_body(self, Vector2(BOUNDS.get_center().x, SIZE.y - 4), Vector2(BOUNDS.size.x, 8))
	_body(self, Vector2(MIN.x + 4, BOUNDS.get_center().y), Vector2(8, BOUNDS.size.y))
	_body(self, Vector2(SIZE.x - 4, BOUNDS.get_center().y), Vector2(8, BOUNDS.size.y))

# The plateau cliff is segmented so a cloud ladder can open a local gap through it.
const CLIFF_SEGMENT := 40.0
var cliff_bodies: Dictionary = {}
var cliff_open: Dictionary = {}
var ridge_bodies: Dictionary = {}
var ridge_open: Dictionary = {}

func _build_cliff() -> void:
	var cliff: Rect2 = Layout.CLIFF
	for i in range(int(ceil(cliff.size.x / CLIFF_SEGMENT))):
		var x: float = cliff.position.x + float(i) * CLIFF_SEGMENT
		cliff_bodies[i] = _body(self, Vector2(x + CLIFF_SEGMENT / 2.0, cliff.get_center().y), Vector2(CLIFF_SEGMENT, cliff.size.y))
	# The plateau's western edge is solid rock, so ladders are the only way onto the highland.
	var wall: Rect2 = Layout.PLATEAU_WALL
	_body(self, wall.get_center(), wall.size)
	# The eastern ridge seals the mountain zone; a second cloud ladder opens a pass through it.
	var ridge: Rect2 = Layout.RIDGE
	for i in range(int(ceil(ridge.size.y / CLIFF_SEGMENT))):
		var y: float = ridge.position.y + float(i) * CLIFF_SEGMENT
		ridge_bodies[i] = _body(self, Vector2(ridge.get_center().x, y + CLIFF_SEGMENT / 2.0), Vector2(ridge.size.x, CLIFF_SEGMENT))

func open_cliff(x: float) -> void:
	_open_line("cliff", x)

func open_ridge(y: float) -> void:
	_open_line("ridge", y)

func _open_line(kind: String, coord: float) -> void:
	# A ladder clears three segments (120 world pixels) of the chosen wall line.
	var line: Rect2 = Layout.RIDGE if kind == "ridge" else Layout.CLIFF
	var bodies: Dictionary = ridge_bodies if kind == "ridge" else cliff_bodies
	var opened: Dictionary = ridge_open if kind == "ridge" else cliff_open
	var along: float = (coord - line.position.y) if kind == "ridge" else (coord - line.position.x)
	var index := int(along / CLIFF_SEGMENT)
	for offset in [-1, 0, 1]:
		var i: int = index + offset
		if not bodies.has(i) or opened.has(i): continue
		opened[i] = true
		bodies[i].collision_layer = 0
	_rebuild_navigation(gate_visual.open)

func _prop(texture: Texture2D, region: Rect2, top_left: Vector2, collision_size := Vector2.ZERO) -> Node2D:
	var prop := Node2D.new()
	var foot := Vector2(region.size.x / 2, region.size.y - 2)
	prop.position = top_left + foot
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.centered = false
	sprite.position = -foot
	prop.add_child(sprite)
	objects.add_child(prop)
	if collision_size != Vector2.ZERO:
		_body(prop, Vector2(0, -collision_size.y / 2), collision_size)
	return prop

func _build_landmarks() -> void:
	for data: Dictionary in homes:
		var house := _prop(DESERT if data["atlas"] == "desert" else HOUSE, data["region"], data["at"], data["body"])
		house.name = "PrimitiveHouse" if data["id"] == "house" else str(data["id"])
		house.add_to_group("village_houses")
		houses.append(house)
		if data["id"] in ["kitchen", "blacksmith"]:
			house.add_child(KitchenDetail.new())
		points[data["id"]] = {"position": data["door"], "radius": 25.0, "label": data["name"], "action": "进屋", "description": data["description"]}
		_label(data["name"], data["at"] + Vector2(10, 0))
	var well := _prop(DESERT, Rect2(0, 48, 32, 32), Vector2(318, 170), Vector2(25, 18))
	well.name = "Well"
	well.add_child(WellDetail.new())
	_prop(ELEMENT, Rect2(80, 16, 16, 16), Vector2(354, 190), Vector2(10, 8))
	_prop(ELEMENT, Rect2(0, 0, 16, 16), Vector2(193, 150), Vector2(11, 9))
	_prop(ELEMENT, Rect2(16, 0, 16, 16), Vector2(274, 145), Vector2(10, 9))
	_prop(ELEMENT, Rect2(192, 80, 16, 16), Vector2(365, 216), Vector2(12, 9))
	_prop(NATURE, Rect2(64, 128, 32, 16), Vector2(182, 178), Vector2(21, 8))
	_label("水井", Vector2(321, 170))
	_label("小农田", Vector2(236, 231))
	_label("猪圈", Vector2(422, 210))
	altar = Altar.new()
	altar.name = "CeremonialAltar"
	altar.position = Vector2(548, 310)
	objects.add_child(altar)
	_body(altar, Vector2(0, -13), Vector2(60, 26))
	_label("祭台", Vector2(539, 354))
	forest_altar = Altar.new()
	forest_altar.name = "ForestAltar"
	forest_altar.position = Layout.FOREST_ALTAR
	objects.add_child(forest_altar)
	_body(forest_altar, Vector2(0,-13), Vector2(60,26))
	points["forest_altar"] = {"position":Layout.FOREST_ALTAR+Vector2(0,22), "radius":25.0, "label":"青木祭台", "action":"存档 / R 觉醒"}
	_label("青木祭台", Layout.FOREST_ALTAR+Vector2(-20,52))
	_label("青木村", Vector2(-1220,650))
	_prop(ELEMENT, Rect2(16, 0, 16, 16), Vector2(744, 131), Vector2(10, 9))
	_prop(ELEMENT, Rect2(0, 0, 16, 16), Vector2(613, 448), Vector2(11, 9))
	_prop(NATURE, Rect2(64, 128, 32, 16), Vector2(823, 362), Vector2(21, 8))

func _label(text: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = at + Vector2(0, -16)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color("fff1ce"))
	label.add_theme_color_override("font_outline_color", Color("684d35"))
	label.add_theme_constant_override("outline_size", 3)
	label.z_index = 6
	add_child(label)

func _fence(at: Vector2, length: float, vertical: bool, gate := false) -> void:
	var visual := Fence.new()
	visual.position = at
	visual.length = length
	visual.vertical = vertical
	visual.is_gate = gate
	objects.add_child(visual)
	var size := Vector2(5, length + 2) if vertical else Vector2(length, 5)
	var center := Vector2(0, length / 2) if vertical else Vector2(length / 2, 0)
	var body := _body(visual, center, size)
	if gate:
		gate_visual = visual
		gate_body = body
		visual.name = "PenGate"

func _build_pen() -> void:
	for x in range(384, 480, 16):
		_fence(Vector2(x, 211), 16, false)
		if x != 416 and x != 432:
			_fence(Vector2(x, 274), 16, false)
	_fence(Vector2(416, 274), 32, false, true)
	_fence(Vector2(384, 211), 63, true)
	_fence(Vector2(480, 211), 63, true)
	var trough := Trough.new()
	trough.name = "FeedingTrough"
	trough.position = Vector2(460, 229)
	objects.add_child(trough)
	_body(trough, Vector2(0, -5), Vector2(20, 8))

func _scatter_desert_props() -> void:
	for p in [Vector2(46, 80), Vector2(78, 263), Vector2(547, 68), Vector2(864, 340), Vector2(680, 540)]:
		_prop(DESERT, Rect2(128, 144, 32, 48), p, Vector2(19, 10))
	for p in [Vector2(134, 45), Vector2(850, 96)]:
		_prop(DESERT, Rect2(160, 64, 64, 48), p, Vector2(15, 12))
	for p in [Vector2(61, 298), Vector2(892, 132), Vector2(347, 51), Vector2(805, 535)]:
		_prop(NATURE, Rect2(64, 0, 32, 32), p, Vector2(13, 10))
	for p in [Vector2(25, 28), Vector2(38, 170), Vector2(113, 131), Vector2(840, 40), Vector2(885, 200), Vector2(844, 463), Vector2(718, 518), Vector2(410, 516), Vector2(110, 500), Vector2(45, 485), Vector2(386, 38)]:
		_prop(NATURE, Rect2(272, 160, 64, 64), p, Vector2(40, 25))
	for p in [Vector2(128, 286), Vector2(178, 92), Vector2(920, 528), Vector2(307, 536), Vector2(45, 350), Vector2(614, 37), Vector2(897, 396)]:
		_prop(NATURE, Rect2(240, 192, 32, 32), p, Vector2(20, 13))
	for p in [Vector2(93, 58), Vector2(160, 214), Vector2(304, 112), Vector2(775, 148), Vector2(368, 519), Vector2(854, 565), Vector2(80, 250)]:
		_prop(NATURE, Rect2(192, 176, 16, 16), p)

func _spawn_residents() -> void:
	for data: Dictionary in Layout.PLAYERS:
		_spawn_resident(data, true)
	if settlement != "starter":
		for data: Dictionary in Layout.NPCS:
			_spawn_resident(data, false)

	for data: Dictionary in Layout.FOREST_NPCS:
		_spawn_resident(data, false)

func _spawn_resident(data: Dictionary, playable: bool) -> void:
	var resident := Resident.new()
	resident.name = str(data["id"])
	var sheet: Texture2D = load("res://assets/ninja_adventure/Actor/Character/" + str(data["sprite"]) + "/SpriteSheet.png")
	var route: Array[Vector2] = []
	for point: Vector2 in data["route"]:
		route.append(point)
	resident.configure(data["name"], sheet, route, navigation.find_path)
	resident.resident_id = data["id"]
	resident.role_label = data["role"]
	resident.dialogue = data["dialogue"]
	resident.can_control = playable
	resident.position = data["at"]
	resident.idle_time = 1.0 + residents.size() * 0.37
	resident.patrol_speed = 14.0 + residents.size() % 4
	objects.add_child(resident)
	residents.append(resident)
	resident.add_to_group("controllable_residents" if playable else "npc_villagers")
	if playable:
		controllable.append(resident)

func _spawn_pigs() -> void:
	for i in range(3):
		var pig := Pig.new()
		pig.name = "Pig" + str(i + 1)
		pig.animal_id = "pig:" + str(i + 1)
		pig.sex = "male" if i == 0 else "female"
		pig.sheet = BLACK_PIG if i == 2 else PINK_PIG
		pig.pig_seed = 80 + i
		pig.position = Vector2(406 + i * 20, 247)
		objects.add_child(pig)
		pigs.append(pig)
