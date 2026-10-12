# Exports the authoritative item source descriptions into a reviewable document.
extends SceneTree
const Items := preload("res://features/inventory/catalog.gd")
func _initialize() -> void:
	var rows: PackedStringArray=["# 物品获取路径", "", "本表由游戏物品目录生成，包含当前全部背包物品。来源在背包详情和悬停提示中显示；用途待定不影响已明确的获取路径。", "", "新角色只有小麦、水稻种子各3；旧档已持有的物品保留。", "", "| 物品 | 获取路径与说明 |", "| --- | --- |"]
	var missing: Array=[]
	for id: String in Items.ITEMS:
		var item: Dictionary=Items.ITEMS[id]
		var description := str(item.get("description",""))
		if description.is_empty(): missing.append(id)
		rows.append("| "+str(item.name)+" | "+description.replace("|","／").replace("\n"," ")+" |")
	var file := FileAccess.open("res://docs/ITEM_SOURCES.md",FileAccess.WRITE)
	file.store_string("\n".join(rows)+"\n")
	file.close()
	print("ITEM_SOURCE_COUNT=",Items.ITEMS.size()," MISSING_DESCRIPTIONS=",JSON.stringify(missing))
	quit(0 if missing.is_empty() else 1)
