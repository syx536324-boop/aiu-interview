# Owns lazy, deterministic terrain patches, with a bounded per-frame preparation budget.
extends Node2D

const Chunk := preload("res://features/streaming/terrain_chunk.gd")
const SIZE := Vector2(320, 200)
const MAP_BOUNDS := preload("res://features/village/layout.gd").BOUNDS
var chunks: Dictionary = {}
var pending: Array[Vector2i] = []
var center := Vector2i(-100, -100)
var watered := false
var built_last_frame := 0

func set_watered(value: bool) -> void:
	watered = value

func cell(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / SIZE.x), floori(at.y / SIZE.y)).clamp(Vector2i(-8, -8), Vector2i(14, 23))

func distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func focus(at: Vector2, immediate := false) -> void:
	var next := cell(at)
	if next == center and not immediate: return
	center = next
	pending.clear()
	# Keep only half a chunk of hysteresis outside the two-chunk preload radius.
	for id: Vector2i in chunks.keys():
		var bounds := Rect2(Vector2(id) * SIZE, SIZE)
		if distance(id, center) > 2 and not bounds.grow(100).intersects(Rect2(Vector2(center - Vector2i(2, 2)) * SIZE, SIZE * 5)):
			chunks[id].free()
			chunks.erase(id)
	for y in range(maxi(-8, center.y - 2), mini(24, center.y + 3)):
		for x in range(maxi(-8, center.x - 2), mini(15, center.x + 3)):
			var id := Vector2i(x, y)
			if not chunks.has(id): pending.append(id)
	pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_squared_to(Vector2(center)) < Vector2(b).distance_squared_to(Vector2(center)))
	if immediate:
		# Only the current viewport needs synchronous geometry after a teleport or character switch.
		for id in pending.duplicate():
			if Rect2(Vector2(id) * SIZE, SIZE).intersects(Rect2(at - SIZE / 2 - Vector2(0, 28), SIZE)):
				_build(id)
				pending.erase(id)

func _build(id: Vector2i) -> void:
	var patch := Chunk.new()
	patch.legacy_pen=get_parent().settlement!="starter_v2"
	patch.configure(Rect2(Vector2(id) * SIZE, SIZE).intersection(MAP_BOUNDS))
	patch.name = "Patch_%d_%d" % [id.x, id.y]
	add_child(patch)
	chunks[id] = patch

func _process(_delta: float) -> void:
	var started := Time.get_ticks_usec()
	built_last_frame = 0
	while not pending.is_empty() and built_last_frame < 2:
		_build(pending.pop_front())
		built_last_frame += 1
		if Time.get_ticks_usec() - started >= 2000: break
