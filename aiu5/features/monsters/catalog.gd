# Defines inherited goblin attacks, spawn tuning and level-bound statistics in world units.
extends RefCounted
const LIFE := [8.0,12.0,18.0,24.0,30.0]
const BASIC_DAMAGE := [1.0,1.0,2.0,2.0,3.0]
const RESPAWN := 300.0
const FOREST_CHUNK := 256
const FOREST_CHANCE := 0.20
const CAVE_CHANCE := 0.35
const SKILLS := {
	"basic":{"level":1,"range":30.0,"damage":0.0,"cooldown":1.0,"windup":0.20,"recovery":0.18},
	"heavy":{"level":2,"range":30.0,"damage":3.0,"cooldown":6.0,"windup":0.50,"recovery":0.25},
	"roots":{"level":3,"range":70.0,"damage":1.0,"cooldown":10.0,"windup":0.30,"recovery":0.20},
	"thorn":{"level":4,"range":140.0,"damage":3.0,"cooldown":7.0,"windup":0.30,"recovery":0.20},
	"sweep":{"level":5,"range":45.0,"damage":4.0,"cooldown":8.0,"windup":0.50,"recovery":0.30}}
static func spawn_level(player_level: int) -> int: return clampi(player_level,1,5)
static func skills(level: int) -> Array[String]:
	var result: Array[String]=[]
	for id: String in SKILLS:
		if int(SKILLS[id].level)<=level: result.append(id)
	return result
static func life(level: int) -> float: return LIFE[clampi(level,1,5)-1]
static func damage(level: int,skill: String) -> float:
	return BASIC_DAMAGE[clampi(level,1,5)-1] if skill=="basic" else float(SKILLS[skill].damage)
