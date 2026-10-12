# Defines the fixed eighteen-class v1 model contract and one-object gift rewards.
extends RefCounted
const NAMES := ["cup","knife","bowl","bed","book","scissors","bird","dog","apple","carrot","sword","axe","pickaxe","bow","armor","helmet","leggings","boots"]
const LABELS := ["杯子","刀","碗","床","书本","剪刀","鸟","狗","苹果","胡萝卜","剑","斧","镐子","弓","盔甲","头盔","护腿","靴子"]
const ITEMS := ["wooden_cup","knife","bowl","bed","book","scissors","bird","dog","apple","carrot","wood_sword","stone_axe","pickaxe","bow","leather_armor","leather_helmet","leather_leggings","leather_boots"]
static func reward(class_id: int) -> Dictionary:
	if class_id < 0 or class_id >= NAMES.size(): return {}
	return {"item":ITEMS[class_id],"name":LABELS[class_id],"kind":"animal" if class_id in [6,7] else "inventory"}
