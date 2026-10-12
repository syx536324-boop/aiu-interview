# Shares equipment categories and initial attack values across combat and resource gathering.
extends RefCounted
const WEAPONS := ["pickaxe","stone_axe","iron_axe","wood_sword","stone_sword","iron_sword","bow","knife","iron_knife"]
const AXES := ["stone_axe","iron_axe"]
const PICKS := ["pickaxe"]
const ATTACK := {"pickaxe":1,"stone_axe":2,"iron_axe":4,"wood_sword":1,"stone_sword":3,"iron_sword":5,"bow":10,"knife":1,"iron_knife":1}
static func damage(item: String) -> int:
	return int(ATTACK.get(item,0))
