# Owns apple-tree planting, capped fruit yields, online growth and transactional persistence.
extends Node
const AppleTree := preload("res://features/orchard/apple_tree.gd")
const Layout := preload("res://features/village/layout.gd")
const Land := preload("res://features/homestead/land.gd")
const PERIOD := 300.0
const YIELD := 3
var session: Node
var records: Dictionary = {}
var nodes: Dictionary = {}
var next_id := 0
var starter_seeded := false
var forest_seeded := false

func start(controller: Node) -> void:
	session=controller

func _bounds(at: Vector2) -> Rect2:
	return Rect2(at-Vector2(25,62),Vector2(50,66))

func placement_error(at: Vector2) -> String:
	var error: String=session.grounds.land_error(_bounds(at),session.world.active_resident,false)
	if error != "": return error
	if Rect2(at-Vector2(6,8),Vector2(12,12)).grow(8).has_point(session.world.active_resident.position): return "树干不能挡住人物脚下，请换个位置。"
	for plot: Dictionary in session.homestead.plots:
		if _bounds(at).intersects(Land.bounds(plot).grow(2)): return "请不要在农田上种植苹果树。"
	for home: Dictionary in session.world.homes:
		if _bounds(at).intersects(Rect2(home.at,home.region.size).grow(8)): return "请在房屋外的空地种树。"
	for route: Array in Layout.ROADS:
		for index in range(route.size()-1):
			if at.distance_to(Geometry2D.get_closest_point_to_segment(at,route[index],route[index+1])) < 28: return "请把苹果树种在道路旁的空地，保持道路通畅。"
	return ""

func ensure_starter() -> void:
	if starter_seeded and forest_seeded: return
	var before := records.size()
	var candidates: Array[Vector2]=[Vector2(260,370),Vector2(500,190),Vector2(620,400)]
	for y in range(128,705,64):
		for x in range(128,769,64): candidates.append(Vector2(x,y))
	starter_seeded=_seed_group("starter_",3,candidates)
	var forest_candidates: Array[Vector2]=[]
	var area: Rect2=Layout.FOREST_VILLAGE.grow(192)
	for y in range(int(area.position.y)+48,int(area.end.y)-16,64):
		for x in range(int(area.position.x)+48,int(area.end.x)-16,64): forest_candidates.append(Vector2(x,y))
	forest_seeded=_seed_group("forest_",20,forest_candidates)
	if records.size()!=before: session.world.refresh_obstacles()

func _seed_group(prefix: String, count: int, candidates: Array[Vector2]) -> bool:
	for index in range(count):
		var id := prefix+str(index)
		if records.has(id): continue
		for at: Vector2 in candidates:
			if placement_error(at) != "": continue
			records[id]={"at":[at.x,at.y],"growth":0.0,"remaining":0.0,"fruit":YIELD}
			_attach(id);break
		if not records.has(id): return false
	return true

func occupied(bounds: Rect2) -> bool:
	for record: Dictionary in records.values():
		if _bounds(Vector2(float(record.at[0]),float(record.at[1]))).intersects(bounds): return true
	return false

func _attach(id: String) -> void:
	var tree: Node2D=AppleTree.new()
	tree.name="AppleTree_"+id
	tree.record=records[id]
	tree.position=Vector2(float(records[id].at[0]),float(records[id].at[1]))
	session.world.objects.add_child(tree)
	tree.body=session.world._body(tree,Vector2(0,-4),Vector2(10,8))
	nodes[id]=tree
	_sync(id)

func _sync(id: String) -> void:
	var record: Dictionary=records[id]
	var description := "每5在线分钟结3个苹果；未采摘的果实不会累积。"
	var action := "采摘苹果×3"
	if float(record.growth)>0:
		action="幼树 · 还需%d秒长成" % ceili(float(record.growth))
		description="木系种下的幼树，5在线分钟后长成并结出第一批苹果。"
	elif int(record.fruit)==0: action="等待结果 · %d秒" % ceili(float(record.remaining))
	session.world.points["orchard:"+id]={"position":nodes[id].position,"radius":30.0,"label":"苹果树","action":action,"description":description}
	nodes[id].queue_redraw()

func plant() -> bool:
	if not session.combat.ready_for_action(): return false
	var actor: Node2D=session.world.active_resident
	if actor.room_id != "": return _error("请到户外空地种植苹果树。")
	var magic: Dictionary=session.magic.ensure(actor.resident_id)
	if str(magic.element)!="wood" or int(magic.level)<1: return _error("种植苹果树需要已觉醒木系，魔法等级至少1级。")
	if is_instance_valid(session.simulation): session.simulation.flush()
	var facing: Vector2=[Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT][actor.facing]
	var at: Vector2=(actor.position+facing*48).snapped(Vector2(8,8))
	var error := placement_error(at)
	if error != "": return _error(error)
	var before: Dictionary=session.inventory.export_data()
	if not session.inventory.exchange(actor.resident_id,{"apple":1},{}): return _error("种植一棵苹果树需要背包中的1个苹果。")
	var id := "planted_%d" % next_id
	next_id+=1
	records[id]={"at":[at.x,at.y],"growth":PERIOD,"remaining":0.0,"fruit":0}
	_attach(id);session.world.refresh_obstacles()
	return session.production.commit(before,"在角色前方种下苹果幼树，5在线分钟后长成；已消耗苹果×1。")

func gather(id: String) -> bool:
	if not records.has(id) or not session.combat.ready_for_action(): return false
	var actor: Node2D=session.world.active_resident
	if actor.room_id!="" or actor.position.distance_to(nodes[id].position)>=30: return false
	if is_instance_valid(session.simulation): session.simulation.flush()
	var record: Dictionary=records[id]
	if float(record.growth)>0: return _error("苹果树仍在生长，还需%d在线秒。" % ceili(float(record.growth)))
	if int(record.fruit)<=0: return _error("苹果尚未成熟，还需%d在线秒。" % ceili(float(record.remaining)))
	var before: Dictionary=session.inventory.export_data()
	if not session.inventory.exchange(actor.resident_id,{}, {"apple":YIELD}): return _error("背包放不下3个苹果，果实仍留在树上。")
	record.fruit=0;record.remaining=PERIOD;_sync(id)
	return session.production.commit(before,"采得苹果×3；这棵树将在5在线分钟后再次结果。")

func _error(text: String) -> bool:
	session._set_notice(text)
	return false

func elapse(delta: float) -> void:
	if delta<=0 or session.overview or session.menu_paused or get_tree().paused or not session.vitals.is_processing(): return
	for id: String in records:
		var record: Dictionary=records[id]
		if float(record.growth)>0:
			record.growth=maxf(0,float(record.growth)-delta)
			if float(record.growth)==0: record.fruit=YIELD
		elif int(record.fruit)==0:
			record.remaining=maxf(0,float(record.remaining)-delta)
			if float(record.remaining)==0: record.fruit=YIELD
		_sync(id)

func export_state() -> Dictionary:
	return {"records":records.duplicate(true),"next_id":next_id,"starter_seeded":starter_seeded,"forest_seeded":forest_seeded}

func restore(data: Dictionary) -> void:
	for id: String in nodes:
		session.world.points.erase("orchard:"+id)
		var node: Node=nodes[id]
		if is_instance_valid(node):
			if node.get_parent()!=null: node.get_parent().remove_child(node)
			node.queue_free()
	nodes.clear();records.clear()
	next_id=maxi(0,int(data.get("next_id",0)))
	starter_seeded=bool(data.get("starter_seeded",false))
	forest_seeded=bool(data.get("forest_seeded",false))
	for id: String in data.get("records",{}):
		var entry: Dictionary=data.records[id]
		var at: Array=entry.get("at",[])
		if at.size()!=2: continue
		var position:=Vector2(float(at[0]),float(at[1]))
		if not position.is_finite() or not session.world.BOUNDS.has_point(position): continue
		records[id]={"at":[position.x,position.y],"growth":clampf(float(entry.get("growth",0)),0,PERIOD),"remaining":clampf(float(entry.get("remaining",0)),0,PERIOD),"fruit":clampi(int(entry.get("fruit",0)),0,YIELD)}
		if float(records[id].growth)>0: records[id].fruit=0
		_attach(id)
	if not records.has("starter_0") or not records.has("starter_1") or not records.has("starter_2"): starter_seeded=false
	for index in range(20):
		if not records.has("forest_"+str(index)): forest_seeded=false
	ensure_starter()
	session.world.refresh_obstacles()
