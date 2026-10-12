# Generates a larger saved-seed cave: stone in every chunk, independent 40% coal and 10% iron rolls.
extends RefCounted
const CHUNK := Vector2(320,240)
const COUNTS := Vector2i(6,4)
const SIZE := Vector2(1920,960)
static func generate(seed: int, legacy: Array = []) -> Array:
	var result: Array=legacy.duplicate(true)
	for y in range(COUNTS.y):
		for x in range(COUNTS.x):
			var rng := RandomNumberGenerator.new()
			rng.seed=(str(seed)+":cave2:"+str(x)+":"+str(y)).hash()
			var coal := rng.randf()<0.4
			var iron := rng.randf()<0.1
			var origin := Vector2(x,y)*CHUNK
			var offsets := [Vector2(64,62),Vector2(116,142)]
			for i in range(2): _append(result,"cave2:%d:%d:stone:%d" % [x,y,i],origin+offsets[i],"stone")
			if coal: _append(result,"cave2:%d:%d:coal" % [x,y],origin+Vector2(222,76),"coal")
			if iron: _append(result,"cave2:%d:%d:iron" % [x,y],origin+Vector2(240,170),"iron_ore")
	return result
static func _append(records: Array, id: String, at: Vector2, kind: String) -> void:
	# Existing legacy veins retain their IDs and progress; expanded veins avoid overlapping them.
	for record: Dictionary in records:
		if record.at.distance_to(at)<30: return
	records.append({"id":id,"at":at,"kind":kind})
