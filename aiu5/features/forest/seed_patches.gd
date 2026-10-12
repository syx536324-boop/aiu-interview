# Samples independent 20% seed refresh periods without iterating over distant grass patches.
extends RefCounted
const INTERVAL := 120.0
const CHANCE := 0.2
const ITEMS := ["seeds","rice_seeds"]
static func schedule(world_seed: int, id: String, now: float) -> Dictionary:
	var epoch := floori(maxf(0,now)/INTERVAL)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed ^ id.hash() ^ (epoch * 83492791) ^ 31657
	var failures := floori(log(maxf(0.0000001,1.0-rng.randf()))/log(1.0-CHANCE))
	return {"next":(epoch+failures+1)*INTERVAL,"item":ITEMS[rng.randi_range(0,1)]}
