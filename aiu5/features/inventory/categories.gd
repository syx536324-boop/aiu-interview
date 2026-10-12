# Shares explicit item groups with inventory filters and workshop navigation.
extends RefCounted
const LABELS := {"all":"全部", "food":"食物", "weapon":"武器", "equipment":"装备", "tool":"工具", "furniture":"家具", "material":"材料", "herb":"草药", "seed":"种子", "book":"书籍", "animal":"动物"}
const GROUPS := {
	"food":["bread","pork","cooked_pork","restorative_soup","qi_soup","wheat","rice","apple","carrot","beef","mutton","cooked_beef","cooked_mutton"],
	"weapon":["pickaxe","stone_axe","iron_axe","wood_sword","stone_sword","iron_sword","bow","knife","iron_knife","arrow"],
	"equipment":["leather_armor","leather_leggings","leather_helmet","leather_boots","iron_armor","iron_leggings","iron_helmet","iron_boots"],
	"tool":["hoe","watering_can","bucket","water_bucket","water_bucket_3","water_bucket_2","water_bucket_1","wooden_cup","water_cup","iron_bucket","bowl","scissors"],
	"furniture":["campfire","workbench","fence","building_bench","bed","cabinet","table","chair","chest","stove"],
	"material":["coal","wood","stone","iron_ore","crude_iron","sand_bucket","leather","wool"],
	"herb":["ginseng","reishi","goji","mulberry_leaf"], "seed":["seeds","rice_seeds"], "book":["book"], "animal":["pig","cow","sheep","bird","dog"]}
static func group(item: String) -> String:
	for key: String in GROUPS:
		if item in GROUPS[key]: return key
	return ""
static func label(item: String) -> String:
	return str(LABELS.get(group(item),"未分类"))
static func indices(slots: Array, selected: String) -> Array[int]:
	var result: Array[int] = []
	for i in range(slots.size()):
		if selected == "all" or (not slots[i].is_empty() and group(str(slots[i].item)) == selected): result.append(i)
	if selected != "all":
		for i in range(slots.size()):
			if slots[i].is_empty(): result.append(i)
	return result
