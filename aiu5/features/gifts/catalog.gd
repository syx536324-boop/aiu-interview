# Provides the eighteen gift reference entries without opening a camera or loading a save.
extends RefCounted
const Mapping := preload("res://features/gifts/mapping.gd")
const Inventory := preload("res://features/inventory/catalog.gd")

static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(Mapping.ITEMS.size()):
		var reward := Mapping.reward(i)
		var label := str(Mapping.LABELS[i]) if reward.kind == "animal" else str(Inventory.ITEMS[reward.item].name)
		var note := "1只 · 生成在村庄" if reward.kind == "animal" else "1件 · 当前角色背包"
		if reward.item == "wooden_cup": note += " · 空杯"
		if reward.item == "bow": note += " · 不附赠箭"
		if reward.item == "book": note += " · 只能赐予"
		result.append({"item":str(reward.item), "name":label, "recognizes":str(Mapping.LABELS[i]), "note":note})
	return result
