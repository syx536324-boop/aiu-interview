# Shares equipment categories and initial attack values across combat and resource gathering.
extends RefCounted
const WEAPONS := ["pickaxe","stone_axe","iron_axe","wood_sword","stone_sword","iron_sword","bow","knife","iron_knife"]
const AXES := ["stone_axe","iron_axe"]
const PICKS := ["pickaxe"]
const ATTACK := {"pickaxe":1,"stone_axe":2,"iron_axe":4,"wood_sword":1,"stone_sword":3,"iron_sword":5,"bow":1,"knife":1,"iron_knife":1}
const RANGES := {"pickaxe":30.0,"stone_axe":30.0,"iron_axe":30.0,"wood_sword":30.0,"stone_sword":30.0,"iron_sword":30.0,"bow":150.0,"knife":20.0,"iron_knife":20.0}
const INTERVALS := {"pickaxe":1.0,"stone_axe":1.0,"iron_axe":1.0,"wood_sword":1.0,"stone_sword":1.0,"iron_sword":1.0,"bow":1.0,"knife":0.4,"iron_knife":0.4}
static func attack_range(item: String) -> float:
	return float(RANGES.get(item,0))
static func interval(item: String) -> float:
	return float(INTERVALS.get(item,1))
static func damage(item: String) -> int:
	return int(ATTACK.get(item,0))
