# Tracks new-save objectives from committed gameplay events and exposes presentation snapshots.
extends Node
signal changed
var session: Node
var enabled := false
var pickups := {"wood":0,"stone":0}
var crafted := {"stone_axe":false,"pickaxe":false}
var mined := false
var learned := {"magic":false,"gifts":false,"npc":false}
var reviewing := false

func start(controller: Node) -> void:
	session=controller
	enabled=session.world.settlement=="starter_v2" and session.inventory.saved_session.is_empty()

func _player(actor_id: String) -> bool:
	return session.world.controllable.any(func(actor: Node) -> bool: return actor.resident_id==actor_id)

func record_pickup(item: String, actor_id: String) -> void:
	if not enabled or not _player(actor_id) or not pickups.has(item): return
	pickups[item]=mini(2 if item=="wood" else 4,int(pickups[item])+1)
	changed.emit()

func record_craft(recipe: String, actor_id: String) -> void:
	if not enabled or not _player(actor_id) or not crafted.has(recipe): return
	crafted[recipe]=true
	changed.emit()

func record_mining(_ore_id: String, _item: String, actor_id: String) -> void:
	if not enabled or not _player(actor_id): return
	mined=true
	changed.emit()

func stage() -> int:
	if not enabled: return 0
	if not reviewing and (int(pickups.wood)<2 or int(pickups.stone)<4): return 1
	if not reviewing and (not crafted.stone_axe or not crafted.pickaxe): return 2
	if not reviewing and not mined:return 3
	for i in range(3):
		if not learned[["magic","gifts","npc"][i]]:return i+4
	return 7

func presentation() -> Dictionary:
	var current := stage()
	var result := {"visible":current>0 and current<7,"stage":current,"title":"新手指引 %d/6" % current,"text":"","target":{},"distance":0}
	if not result.visible: return result
	match current:
		1: result.text="靠近地上木石，按 E 拾取
木头 %d/2 · 石头 %d/4" % [int(pickups.wood),int(pickups.stone)]
		2: result.text="工作台 E/T → 选择 → 确认合成
石斧 %s · 镐子 %s · 各需60秒" % ["✓" if crafted.stone_axe else "待制作","✓" if crafted.pickaxe else "待制作"]
		3: result.text="B 背包选镐子 → 装备
靠近石矿按 E，采完一处矿脉"
		4: result.text="祭台 → 选择角色 → 觉醒木水火土。\n建议不同人物选择不同属性，互相配合；觉醒后不能更换。"
		5: result.text="祭台 → 赐予 → 允许相机。\n对准实物，定格并选物后确认；手机在本地识别。"
		6: result.text="靠近本方成年NPC → 交互 → 升级。\n先查看材料，从当前角色背包扣除；可培养战士、弓手、农民和矿工。"
	result.target=_target(current)
	if not result.target.is_empty():
		result.distance=roundi(session.world.active_resident.position.distance_to(result.target.at))
	return result

func _target(current: int) -> Dictionary:
	var actor: Node2D=session.world.active_resident
	if actor.room_id!="": return {}
	var options: Array[Dictionary]=[]
	if current==1:
		for node: Node2D in session.foraging.nodes.values():
			if node.available and int(pickups[node.item])<(2 if node.item=="wood" else 4): options.append({"at":node.position,"label":"拾取木头" if node.item=="wood" else "拾取石头"})
	elif current==2:
		for fixture: Node2D in session.grounds.fixtures:
			if fixture.kind=="workbench": options.append({"at":fixture.position+Vector2(0,14),"label":"工作台"})
	elif current==3:
		for ore: Node2D in session.mining.surface.values()+session.mining.procedural.values():
			if ore.hits<ore.strikes: options.append({"at":ore.position+Vector2(0,14),"label":"开采石矿"})
	if current in [4,5] and is_instance_valid(session.world.altar):options.append({"at":session.world.altar.position,"label":"祭台"})
	if current==6:
		for id: String in session.tribes.population.members:
			var person: Node=session.tribes.population.node(id)
			if session.tribes.population.friendly(id) and float(session.tribes.population.members[id].get("child_left",0))<=0 and is_instance_valid(person) and person.room_id=="":options.append({"at":person.position,"label":"NPC升级"})
	var nearest: Dictionary={}
	var distance := INF
	for option: Dictionary in options:
		var candidate: float=actor.position.distance_squared_to(option.at)
		if candidate<distance: nearest=option; distance=candidate
	return nearest

func export_state() -> Dictionary:
	return {"version":2,"learned":learned.duplicate(),"reviewing":reviewing,"enabled":enabled,"pickups":pickups.duplicate(),"crafted":crafted.duplicate(),"mined":mined}

func restore(data: Dictionary) -> void:
	# An absent record belongs to an existing save; do not start a forced tutorial.
	enabled=bool(data.get("enabled",false)) and int(data.get("version",0)) in [1,2]
	for item: String in pickups: pickups[item]=clampi(int(data.get("pickups",{}).get(item,0)),0,2 if item=="wood" else 4)
	for recipe: String in crafted: crafted[recipe]=bool(data.get("crafted",{}).get(recipe,false))
	mined=bool(data.get("mined",false))
	reviewing=bool(data.get("reviewing",false))
	for key: String in learned:learned[key]=bool(data.get("learned",{}).get(key,false))
	changed.emit()

func record_feature(key: String) -> void:
	if not enabled or not learned.has(key) or learned[key]:return
	var before: Dictionary=session.inventory.export_data()
	learned[key]=true
	session.production.commit(before,"已了解："+{"magic":"魔法属性","gifts":"赐予","npc":"NPC升级"}[key])
	changed.emit()

func acknowledge() -> void:
	var current:=stage()
	if current in [4,5,6]:record_feature(["magic","gifts","npc"][current-4])

func review_features() -> void:
	var before: Dictionary=session.inventory.export_data()
	enabled=true;reviewing=true
	learned={"magic":false,"gifts":false,"npc":false}
	session.production.commit(before,"重新查看魔法、赐予和NPC升级教程。")
	changed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F1:
		review_features();get_viewport().set_input_as_handled()
