# Computes reproducible thirty-percent bonus silk drops for successful mulberry harvests.
extends RefCounted
const CHANCE := 0.3
static func extra(seed_value: int, plant_id: String, harvest: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_value ^ plant_id.hash() ^ (maxi(1,harvest)*83492791)
	return rng.randf()<CHANCE
