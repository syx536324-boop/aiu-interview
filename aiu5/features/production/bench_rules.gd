# Defines workbench levels and commits material-paid upgrades through the existing transaction domain.
extends RefCounted
const COSTS := {1:{"wood":25},2:{"stone":50,"wood":50}}
const TIMES := {1:60.0,2:45.0,3:30.0}

static func level(fixture: Node) -> int:
	return clampi(int(fixture.bench_level),1,3) if is_instance_valid(fixture) and fixture.kind=="workbench" else 1

static func option(production: Node) -> Dictionary:
	if not is_instance_valid(production.fixture) or production.fixture.kind!="workbench":return {}
	var rank:=level(production.fixture)
	if rank>=3:return {}
	var s: Node=production.session
	var ingredients: Array=[]
	for item: String in COSTS[rank]:
		var have:=0
		for slot: Dictionary in s.inventory.ensure_bag(s.world.active_resident.resident_id):
			if slot.get("item","")==item:have+=int(slot.count)
		ingredients.append({"item":item,"name":s.inventory.Catalog.ITEMS[item].name,"need":COSTS[rank][item],"have":have})
	return {"id":"bench:upgrade","name":"工作台升级：%d → %d级" % [rank,rank+1],"category":"all","ingredients":ingredients,"immediate":true,"usage":"升级后同时制作%d件，新任务每件%.0f秒。在制任务保留原进度；移动和回收保留等级。" % [rank+1,TIMES[rank+1]],"detail":"确认后扣除材料并立即升级。","enabled":s.inventory.exchange(s.world.active_resident.resident_id,COSTS[rank],{},false)}

static func upgrade(production: Node) -> bool:
	if production.mode not in ["craft","herbs"] or not production._valid(production.mode) or production.fixture.kind!="workbench":return false
	var rank:=level(production.fixture)
	if rank>=3:return false
	var s: Node=production.session
	var before: Dictionary=s.inventory.export_data()
	if not s.inventory.exchange(s.world.active_resident.resident_id,COSTS[rank],{}):
		production.message.emit("工作台升级材料不足，未扣除物品。")
		return false
	production.fixture.bench_level=rank+1;production.fixture.queue_redraw()
	return production.commit(before,"工作台已升为%d级：%d个制作位，新任务%.0f秒完成。" % [rank+1,rank+1,TIMES[rank+1]])
