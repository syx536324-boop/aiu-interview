# Tracks new-save objectives from committed gameplay events and exposes presentation snapshots.
extends Node
signal changed
var session: Node
var enabled := false
var pickups := {"wood":0,"stone":0}
var crafted := {"stone_axe":false,"pickaxe":false}
var mined := false

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
	if int(pickups.wood)<2 or int(pickups.stone)<4: return 1
	if not crafted.stone_axe or not crafted.pickaxe: return 2
	return 4 if mined else 3

func presentation() -> Dictionary:
	var current := stage()
	var result := {"visible":current>0 and current<4,"stage":current,"title":"新手指引 %d/3" % current,"text":"","target":{},"distance":0}
	if not result.visible: return result
	match current:
		1: result.text="靠近地上木石，按 E 拾取
木头 %d/2 · 石头 %d/4" % [int(pickups.wood),int(pickups.stone)]
		2: result.text="工作台 E/T → 选择 → 确认合成
石斧 %s · 镐子 %s · 各需60秒" % ["✓" if crafted.stone_axe else "待制作","✓" if crafted.pickaxe else "待制作"]
		3: result.text="B 背包选镐子 → 装备
靠近石矿按 E，采完一处矿脉"
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
	var nearest: Dictionary={}
	var distance := INF
	for option: Dictionary in options:
		var candidate: float=actor.position.distance_squared_to(option.at)
		if candidate<distance: nearest=option; distance=candidate
	return nearest

func export_state() -> Dictionary:
	return {"version":1,"enabled":enabled,"pickups":pickups.duplicate(),"crafted":crafted.duplicate(),"mined":mined}

func restore(data: Dictionary) -> void:
	# An absent record belongs to an existing save; do not start a forced tutorial.
	enabled=bool(data.get("enabled",false)) and int(data.get("version",0))==1
	for item: String in pickups: pickups[item]=clampi(int(data.get("pickups",{}).get(item,0)),0,2 if item=="wood" else 4)
	for recipe: String in crafted: crafted[recipe]=bool(data.get("crafted",{}).get(recipe,false))
	mined=bool(data.get("mined",false))
	changed.emit()
