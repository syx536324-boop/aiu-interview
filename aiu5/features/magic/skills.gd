# Owns mana-funded elemental actions, timed effects, safe targeting and their saved online clocks.
extends Node
const Rules := preload("res://features/magic/skill_catalog.gd")
const Visual := preload("res://features/magic/skill_visual.gd")
const Room := preload("res://features/interiors/room.gd")
var magic: Node
var session: Node
var buffs: Dictionary = {}
var marks: Dictionary = {}
var huts: Dictionary = {}
var projectiles: Array = []
var hut_nodes: Dictionary = {}
var projectile_nodes: Array[Node2D] = []
var target_nodes: Dictionary = {}
func start(owner_magic: Node) -> void:
	magic = owner_magic
	session = magic.session
func learned(id: String, rank: int) -> bool:
	return magic.ensure(id).unlocked.has("trunk_"+str(rank))
func max_life(id: String) -> float:
	return 11.0 if magic.ensure(id).element=="wood" and learned(id,1) else 10.0
func need_rate(id: String, stat: String) -> float:
	var element: String=magic.ensure(id).element
	return 0.9 if learned(id,1) and ((element=="water" and stat=="thirst") or (element=="fire" and stat=="hunger")) else 1.0
func run_rate(id: String) -> float:
	return 1.1 if magic.ensure(id).element=="earth" and learned(id,1) else 1.0
func attack_bonus(id: String) -> int:
	return 2 if float(buffs.get(id,{}).get("empower",0))>0 else 0
func damage_rate(id: String) -> float:
	return 0.7 if float(buffs.get(id,{}).get("shield",0))>0 else 1.0
func _reject(text: String) -> bool:
	return magic._reject(text)
func _outdoors(actor: CharacterBody2D) -> bool:
	return actor.room_id==""
func _visible(actor: CharacterBody2D, at: Vector2, radius: float) -> bool:
	return actor.global_position.distance_to(at)<=radius and Rect2(Vector2.ZERO,Vector2(640,400)).has_point(actor.get_canvas_transform()*at)
func _line_clear(actor: CharacterBody2D, at: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(actor.global_position,at,1|4,[actor.get_rid()])
	return actor.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
func _enemy(actor: CharacterBody2D, at: Vector2) -> CharacterBody2D:
	var result: CharacterBody2D
	var distance := 22.0
	if not _outdoors(actor): return null
	for enemy: CharacterBody2D in session.combat.target_enemies():
		if enemy.hp<=0 or enemy.get_parent()==null: continue
		var gap := enemy.global_position.distance_to(at)
		if gap<distance and _visible(actor,enemy.global_position,200) and _line_clear(actor,enemy.global_position):
			result=enemy
			distance=gap
	return result
func _crop(actor: CharacterBody2D, at: Vector2) -> int:
	if not _outdoors(actor) or not _visible(actor,at,120) or not _line_clear(actor,at): return -1
	session.homestead.settle()
	for i in range(session.homestead.plots.size()):
		var p: Dictionary=session.homestead.plots[i]
		if session.homestead.Land.bounds(p).has_point(at) and session.homestead.Crops.CROPS.has(p.crop) and not p.get("mature",false): return i
	return -1
func _cells(actor: CharacterBody2D, at: Vector2) -> Array:
	var cells: Array=[]
	if not _outdoors(actor) or not _visible(actor,at,120): return cells
	var center := (at/16).floor()*16
	for y in range(-2,3):
		for x in range(-2,3):
			var p := center+Vector2(x,y)*16
			var rect := Rect2(p,Vector2(16,16))
			if session.grounds.land_error(rect,actor,false)!="" or not _line_clear(actor,rect.get_center()): continue
			var occupied := false
			for plot: Dictionary in session.homestead.plots:
				if rect.intersects(session.homestead.Land.bounds(plot)): occupied=true; break
			if not occupied: cells.append(p)
	return cells
func _camp(actor: CharacterBody2D) -> Node2D:
	var fixtures: Array=session.grounds.fixtures if actor.room_id=="" else session.interiors.rooms[actor.room_id].fixtures
	for fixture: Node2D in fixtures:
		if fixture.kind=="campfire" and not fixture.lit and fixture.get_parent()!=null and actor.global_position.distance_to(fixture.global_position)<=32 and _line_clear(actor,fixture.global_position+Vector2(0,4)): return fixture
	return null
func _landing(actor: CharacterBody2D, at: Vector2) -> bool:
	if not session.world.BOUNDS.grow(-8).has_point(at): return false
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius=4
	query.shape=shape
	query.transform=Transform2D(0,at+Vector2(0,-3))
	query.collision_mask=1|2|4|8
	query.exclude=[actor.get_rid()]
	return actor.get_world_2d().direct_space_state.intersect_shape(query).is_empty()
func cast(rank: int, at: Vector2) -> bool:
	if is_instance_valid(session.simulation): session.simulation.flush()
	var actor: CharacterBody2D=session.world.active_resident
	var id: String=actor.resident_id
	if not session.combat.ready_for_action() or (is_instance_valid(session.gifts) and session.gifts.opened): return false
	if rank<2 or rank>5 or not learned(id,rank): return _reject("请在 C → 属性 → 技能树依次点亮该技能。")
	var element: String=magic.ensure(id).element
	var cost: int=Rules.COSTS[rank-1]
	var stats: Dictionary=session.vitals.ensure(id)
	if float(stats.mana)<cost: return _reject("魔力不足，该技能需要%d点魔力。" % cost)
	var enemy: CharacterBody2D
	var plot := -1
	var cells: Array=[]
	var camp: Node2D
	var ignite_torch := false
	var destination := Vector2.ZERO
	var vessels: Array[int]=[]
	if rank==2:
		if magic.ensure(id).equipment.weapon=="" or not magic.weapon_usable(id): return _reject("请先装备一把未损坏的武器。")
	elif rank==3:
		match element:
			"wood":
				plot=_crop(actor,at)
				if plot<0: return _reject("鼠标指向120像素内尚未成熟的活作物。")
			"water":
				var bag: Array=session.inventory.ensure_bag(id)
				for item in ["bucket","wooden_cup"]:
					for i in range(bag.size()):
						if bag[i].get("item","")==item: vessels.append(i); break
				if vessels.is_empty(): return _reject("背包中需要空水桶或空木杯；每种最多装满一个。")
			"fire":
				camp=_camp(actor)
				ignite_torch=is_instance_valid(session.torches) and session.torches.can_ignite(id)
				if not is_instance_valid(camp) and not ignite_torch: return _reject("装备熄灭的火把，或靠近未点燃的篝火（32像素内）再施放。")
			"earth":
				cells=_cells(actor,at)
				if cells.is_empty(): return _reject("鼠标指向附近可开垦空地，避开道路、水面、建筑和已有田格。")
	elif rank==4:
		match element:
			"wood":
				if stats.life>=max_life(id): return _reject("生命已满，无需回春。")
			"fire":
				enemy=_enemy(actor,at)
				if not is_instance_valid(enemy): return _reject("鼠标指向200像素内可见的敌人。")
			"earth":
				if not _outdoors(actor) or not _visible(actor,at,100) or huts.has(id): return _reject("在户外鼠标指向100像素内空地；已有土屋时不能重复生成。")
				destination=at.snapped(Vector2(16,16))
				var error: String=session.grounds.land_error(Rect2(destination-Vector2(16,26),Vector2(32,32)),actor)
				if error!="" or not _line_clear(actor,at): return _reject(error if error!="" else "土屋位置被障碍遮挡。")
	elif rank==5:
		if element in ["wood","water"]:
			enemy=_enemy(actor,at)
			if not is_instance_valid(enemy): return _reject("鼠标指向200像素内可见的敌人。")
		elif element=="fire":
			if not _outdoors(actor) or not _visible(actor,at,200) or actor.global_position.distance_to(at)<4: return _reject("在户外朝鼠标方向发射火球，最远200像素。")
		elif element=="earth":
			if not _outdoors(actor): return _reject("瞬移需在户外使用。")
			var direction := actor.global_position.direction_to(at)
			if direction==Vector2.ZERO: direction=[Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT][actor.facing]
			destination=actor.global_position+direction*80
			if not _landing(actor,destination) or not _line_clear(actor,destination): return _reject("80像素处落点或路径有障碍，魔力未扣除。")
	var before: Dictionary=session.inventory.export_data()
	# Vessel conversion keeps gift provenance and is allowed only if all selected conversions fit.
	if rank==3 and element=="water":
		for index: int in vessels:
			var item: String=session.inventory.ensure_bag(id)[index].item
			if not session.inventory.transform_record(id,index,session.homestead.Water.filled(item)):
				session.inventory.apply_data(before)
				return _reject("背包空间不足，容器和魔力保持原样。")
	if (rank==4 and element=="fire") or (rank==5 and element in ["wood","water","fire"]): magic.branches.note_combat(id)
	stats.mana-=cost
	if not buffs.has(id): buffs[id]={"empower":0.0,"shield":0.0,"regen":0.0,"regen_tick":0.0}
	if rank==2: buffs[id].empower=120.0
	elif rank==3:
		match element:
			"wood":
				var p: Dictionary=session.homestead.plots[plot]
				p.growth=session.homestead.Crops.MATURE_AFTER
				p.dry=false
				p.age=0.0
				session.homestead.refresh()
			"fire":
				if is_instance_valid(camp): camp.set_lit(true)
				if ignite_torch: session.torches.ignite(id)
			"earth":
				for p: Vector2 in cells: session.homestead.plots.append({"x":p.x,"y":p.y,"w":16.0,"h":16.0,"age":0.0,"dry":true,"crop":""})
				session.homestead.refresh()
	elif rank==4:
		match element:
			"wood": buffs[id].regen=30.0; buffs[id].regen_tick=0.0
			"water": buffs[id].shield=30.0
			"fire": _mark(enemy,id,"fire",15.0)
			"earth":
				huts[id]={"at":[destination.x,destination.y],"remaining":20.0}
				_attach_hut(id)
	elif rank==5:
		match element:
			"wood": _mark(enemy,id,"wood",1.0)
			"water": _mark(enemy,id,"water",11.0)
			"fire":
				var origin: Vector2=actor.global_position+Vector2(0,-10)
				var dir := origin.direction_to(at)
				projectiles.append({"actor":id,"at":[origin.x,origin.y],"direction":[dir.x,dir.y],"remaining":200.0})
				_refresh_projectiles()
			"earth": actor.global_position=destination; actor.velocity=Vector2.ZERO; session._sync_view()
	magic.branches._area(id,"cast",actor.global_position,0.8,Vector2(24,24),Vector2.RIGHT)
	magic.branches._rebuild_visuals()
	session.vitals._sync_actors()
	var info := Rules.entry(element,rank)
	var text := "施放%s，消耗%d魔力。" % [info.name,cost]
	if rank==3 and element=="earth": text+=" 已开垦%d格。" % cells.size()
	return session.production.commit(before,text)
func _mark(enemy: CharacterBody2D, actor: String, kind: String, duration: float) -> void:
	var root_allowed := kind in ["wood","water"] and float(magic.branches.control_locks.get(enemy.enemy_id,0))<=0
	if root_allowed: magic.branches.control_locks[enemy.enemy_id]=10.0
	# Each caster/effect pair refreshes rather than stacking free repeated damage.
	marks[enemy.enemy_id+":"+actor+":"+kind]={"enemy":enemy.enemy_id,"actor":actor,"kind":kind,"remaining":duration,"tick":0.0,"root":1.0 if root_allowed else 0.0,"drain":kind=="wood"}
	_refresh_targets()
func rooted(enemy_id: String) -> bool:
	if is_instance_valid(magic.branches) and magic.branches.rooted(enemy_id): return true
	for mark: Dictionary in marks.values():
		if mark.enemy==enemy_id and float(mark.root)>0: return true
	return false
func drain_on_hit(enemy: CharacterBody2D, actor_id: String) -> float:
	var key: String=enemy.enemy_id+":"+actor_id+":wood"
	if not marks.has(key) or not marks[key].drain: return 0
	marks[key].drain=false
	var amount := minf(2,enemy.hp)
	session.vitals.heal(actor_id,amount)
	return amount
func advance(delta: float) -> void:
	var left := maxf(0,delta)
	while left>0.00001:
		var step := minf(left,0.5)
		left-=step
		_step(step)
func _step(delta: float) -> void:
	for id: String in buffs.keys():
		var b: Dictionary=buffs[id]
		for field in ["empower","shield"]:
			if b.has(field): b[field]=maxf(0,float(b[field])-delta)
		if float(b.get("regen",0))>0 and session.world.active_resident.resident_id==id and session.vitals.ensure(id).life>0:
			b.regen_tick=float(b.get("regen_tick",0))+minf(delta,float(b.regen))
			b.regen=maxf(0,float(b.regen)-delta)
			while b.regen_tick>=3:
				b.regen_tick-=3
				session.vitals.heal(id,1)
	for key: String in marks.keys():
		var m: Dictionary=marks[key]
		var enemy: Variant=session.combat.enemies.get(m.enemy)
		if not is_instance_valid(enemy) or enemy.hp<=0: marks.erase(key); continue
		var span := minf(delta,float(m.remaining))
		var root_before := float(m.root)
		m.root=maxf(0,root_before-span)
		m.remaining=maxf(0,float(m.remaining)-span)
		m.tick+=span if m.kind=="fire" else maxf(0,span-root_before)
		var interval := 3.0 if m.kind=="fire" else 5.0
		if m.kind in ["fire","water"]:
			while float(m.tick)>=interval and enemy.hp>0:
				m.tick-=interval
				if m.kind=="fire": session.combat.apply_skill_damage(enemy,1,str(m.actor))
				else: enemy.thirst=maxf(0,enemy.thirst-2); enemy.queue_redraw()
		if m.remaining<=0 and (m.kind!="wood" or not m.drain): marks.erase(key)
	for id: String in huts.keys():
		huts[id].remaining=maxf(0,float(huts[id].remaining)-delta)
		if huts[id].remaining<=0: _remove_hut(id)
	_advance_projectiles(delta)
	_refresh_targets()
func _advance_projectiles(delta: float) -> void:
	for i in range(projectiles.size()-1,-1,-1):
		var p: Dictionary=projectiles[i]
		var start := Vector2(p.at[0],p.at[1])
		var direction := Vector2(p.direction[0],p.direction[1])
		var span := minf(float(p.remaining),180*delta)
		var end := start+direction*span
		var query := PhysicsRayQueryParameters2D.create(start,end,1|8|4)
		var hit: Dictionary=session.world.get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			if hit.collider.is_in_group("hostile_targets") or hit.collider.is_in_group("creature_targets"): session.combat.apply_skill_damage(hit.collider,5,str(p.actor))
			projectiles.remove_at(i)
		else:
			p.at=[end.x,end.y]
			p.remaining-=span
			if p.remaining<=0: projectiles.remove_at(i)
	_refresh_projectiles()
func _refresh_projectiles() -> void:
	while projectile_nodes.size()>projectiles.size(): projectile_nodes.pop_back().queue_free()
	while projectile_nodes.size()<projectiles.size():
		var visual := Visual.new()
		visual.kind="fireball"
		session.world.objects.add_child(visual)
		projectile_nodes.append(visual)
	for i in range(projectiles.size()): projectile_nodes[i].position=Vector2(projectiles[i].at[0],projectiles[i].at[1])
func _refresh_targets() -> void:
	var kinds: Dictionary={}
	for m: Dictionary in marks.values():
		if m.remaining>0 or (m.kind=="wood" and m.drain): kinds[m.enemy]=m.kind
	for id: String in target_nodes.keys():
		if not kinds.has(id): target_nodes[id].queue_free(); target_nodes.erase(id)
	for id: String in kinds:
		var enemy: Variant=session.combat.enemies.get(id)
		if not is_instance_valid(enemy) or enemy.hp<=0: continue
		if not target_nodes.has(id):
			var visual := Visual.new()
			enemy.add_child(visual)
			target_nodes[id]=visual
		target_nodes[id].kind=kinds[id]
		target_nodes[id].queue_redraw()
func interact_camp() -> bool:
	var actor: CharacterBody2D=session.world.active_resident
	if not session.production.allowed(actor): return false
	var near: Dictionary=session.grounds.nearby(actor) if actor.room_id=="" else session.interiors.context(actor)
	var fixture: Variant=near.get("fixture")
	if not is_instance_valid(fixture) or fixture.kind!="campfire": return false
	var before: Dictionary=session.inventory.export_data()
	if fixture.lit and session.torches.can_ignite(actor.resident_id):
		session.torches.ignite(actor.resident_id)
		return session.production.commit(before,"火把已点燃，照明80×80世界像素；剩余耐久保留。")
	fixture.set_lit(not fixture.lit)
	return session.production.commit(before,"篝火已点亮，照明96×96世界像素。" if fixture.lit else "篝火已熄灭。")
func _attach_hut(id: String) -> void:
	var data: Dictionary=huts[id]
	var at := Vector2(data.at[0],data.at[1])
	var key := "skill_hut:"+id
	var home := {"id":key,"name":"临时土屋","at":at,"door":at+Vector2(0,10),"skill_hut":true,"owner":id}
	session.world.extra_homes[key]=home
	session.world.points[key]={"position":home.door,"radius":20.0,"label":"临时土屋","action":"仅施法者可进入 · 持续20秒"}
	session.interiors.special_rooms[key]=_make_room.bind(id)
	var node := Visual.new()
	node.kind="hut"
	node.position=at
	session.world.objects.add_child(node)
	session.world._body(node,Vector2(0,-13),Vector2(32,26))
	hut_nodes[id]=node
	session.world.refresh_obstacles()
func _make_room(id: String) -> Node2D:
	var room := Room.new()
	room.configure(session.world.home_data("skill_hut:"+id),{"size":Vector2(96,80),"floor":Color("b4916b"),"mats":[],"furniture":[]},[])
	return room
func _remove_hut(id: String) -> void:
	var key := "skill_hut:"+id
	var actor: CharacterBody2D=magic._actor(id)
	if is_instance_valid(actor) and actor.room_id==key:
		var at: Vector2=session.world.safe_return_position(session.interiors.outdoor_position(actor),key)
		session.interiors.leave(actor,session.world.objects,at)
		if session.world.active_resident==actor: session._sync_view()
	session.world.points.erase(key)
	session.world.extra_homes.erase(key)
	session.interiors.special_rooms.erase(key)
	if hut_nodes.has(id):
		var node: Node2D=hut_nodes[id]
		for body in node.find_children("*","StaticBody2D",true,false): session.world.obstacle_bodies.erase(body.get_instance_id())
		if node.get_parent()!=null: node.get_parent().remove_child(node)
		node.free()
		hut_nodes.erase(id)
	huts.erase(id)
	session.world.refresh_obstacles()
func snapshot(id: String) -> Dictionary:
	return {"buffs":buffs.get(id,{}).duplicate(true),"hut_remaining":huts.get(id,{}).get("remaining",0),"max_life":max_life(id)}
func export_state() -> Dictionary:
	return {"buffs":buffs.duplicate(true),"marks":marks.duplicate(true),"huts":huts.duplicate(true),"projectiles":projectiles.duplicate(true)}
func restore(data: Dictionary) -> void:
	for id: String in huts.keys(): _remove_hut(id)
	buffs.clear()
	marks.clear()
	projectiles.clear()
	for id: String in data.get("buffs",{}):
		if not is_instance_valid(magic._actor(id)): continue
		var source: Dictionary=data.buffs[id]
		buffs[id]={"empower":clampf(float(source.get("empower",0)),0,120),"shield":clampf(float(source.get("shield",0)),0,30),"regen":clampf(float(source.get("regen",0)),0,30),"regen_tick":clampf(float(source.get("regen_tick",0)),0,2.999999)}
	for key: String in data.get("marks",{}):
		var m: Dictionary=data.marks[key]
		if not session.combat.enemies.has(m.get("enemy","")) or not is_instance_valid(magic._actor(str(m.get("actor","")))) or m.get("kind","") not in ["wood","water","fire"]: continue
		marks[key]={"enemy":m.enemy,"actor":m.actor,"kind":m.kind,"remaining":clampf(float(m.get("remaining",0)),0,15),"root":clampf(float(m.get("root",0)),0,1),"tick":clampf(float(m.get("tick",0)),0,4.999999),"drain":bool(m.get("drain",false)) and m.kind=="wood"}
	for id: String in data.get("huts",{}):
		var h: Dictionary=data.huts[id]
		if not is_instance_valid(magic._actor(id)) or not h.get("at") is Array or h.at.size()!=2 or float(h.get("remaining",0))<=0: continue
		huts[id]={"at":h.at.duplicate(),"remaining":clampf(float(h.remaining),0,20)}
		_attach_hut(id)
	for p: Dictionary in data.get("projectiles",[]):
		if not is_instance_valid(magic._actor(str(p.get("actor","")))) or not p.get("at") is Array or p.at.size()!=2 or not p.get("direction") is Array or p.direction.size()!=2: continue
		projectiles.append({"actor":p.actor,"at":p.at.duplicate(),"direction":p.direction.duplicate(),"remaining":clampf(float(p.get("remaining",0)),0,200)})
	_refresh_targets()
	_refresh_projectiles()
