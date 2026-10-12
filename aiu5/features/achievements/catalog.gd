# Defines once-per-character item discoveries, including gifted animals and shared water fill levels.
extends RefCounted
const Items := preload("res://features/inventory/catalog.gd")
const REWARD := 25
static func item_key(item: String) -> String:
	return "water_bucket" if item in ["water_bucket_1","water_bucket_2","water_bucket_3"] else Items.canonical(item)
static func starting_count(item: String) -> int:
	# Holdings at or below this amount are the starting grant, not a discovery.
	return int(Items.STARTING.get(item_key(item), 0))
static func entries() -> Dictionary:
	var result := {}
	for item: String in Items.ITEMS:
		var key := item_key(item)
		if item=="water_bucket_1" or item=="water_bucket_2" or item=="water_bucket_3": continue
		result["item:"+key] = {"name":"首次获得"+str(Items.ITEMS[item].name), "description":"获得这种物品一次（制作、采集、拾取、取出或赐予均可）。"}
	for item: String in ["bird","dog"]:
		result["item:"+item] = {"name":"首次获赐"+("鸟" if item=="bird" else "狗"), "description":"通过祭台赐予获得这种动物。"}
	return result
