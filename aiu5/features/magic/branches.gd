# Executes branch spells, range facilities, control, protection and saved online effect clocks.
extends Node
const Rules := preload("res://features/magic/branch_catalog.gd")
const Visual := preload("res://features/magic/branch_visual.gd")
var magic: Node
var session: Node
var facilities: Dictionary={}
var bushes: Dictionary={}
var buffs: Dictionary={}
var cooldowns: Dictionary={}
var combat_time: Dictionary={}
var statuses: Dictionary={}
var control_locks: Dictionary={}
var areas: Dictionary={}
var projectiles: Array=[]
var visuals: Dictionary={}
var next_id := 0
func start(owner_magic: Node) -> void:
	magic=owner_magic; session=magic.session
func note_combat(id: String) -> void:
	combat_time[id]=10.0
func fighting(id: String) -> bool:
	return float(combat_time.get(id,0))>0
func pos(record: Dictionary) -> Vector2:
	return Vector2(record.at[0],record.at[1])
func _room(actor: Node) -> String:
	return str(actor.room_id)
func _facility_at(id: String, element := "") -> bool:
	var actor: Node=magic._actor(id)
	if not is_instance_valid(actor) or actor.dead or actor.room_id!="" or fighting(id): return false
	for f: Dictionary in facilities.values():
		if float(f.remaining)>0 and (element=="" or f.element==element) and actor.global_position.distance_to(pos(f))<=80.0: return true
	return false
func furnace_rate(id: String) -> float:
	return 1.4 if _facility_at(id,"fire") else 1.0
func _near(actor: Node, at: Vector2, radius: float) -> bool:
	return magic.skills._visible(actor,at,radius) and magic.skills._line_clear(actor,at)
func _enemies(actor: Node, at: Vector2, radius: float, limit := 100) -> Array:
	var found: Array=[]
	if actor.room_id!="": return found
	for enemy: Node in session.combat.target_enemies():
		if enemy.hp>0 and enemy.get_parent()!=null and enemy.global_position.distance_to(at)<=radius and _near(actor,enemy.global_position,200): found.append(enemy)
	found.sort_custom(func(a: Node,b: Node) -> bool: return a.global_position.distance_squared_to(at)<b.global_position.distance_squared_to(at))
	return found.slice(0,limit)
func _single(actor: Node, at: Vector2) -> Node:
	return magic.skills._enemy(actor,at)
func _direction(actor: Node, at: Vector2) -> Vector2:
	var d: Vector2=actor.global_position.direction_to(at)
	return [Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT][actor.facing] if d==Vector2.ZERO else d
func _land(actor: Node, at: Vector2, size: Vector2) -> String:
	if actor.room_id!="" or not _near(actor,at,120): return "请指向户外120世界像素内可见空地。"
	var bounds := Rect2(at-size/2,size)
	var error: String=session.grounds.land_error(bounds,actor,false)
	if error!="": return error
	for f: Dictionary in facilities.values():
		if bounds.intersects(Rect2(pos(f)-Vector2(12,12),Vector2(24,24))): return "这里已有恢复设施。"
	for b: Dictionary in bushes.values():
		if bounds.intersects(Rect2(pos(b)-Vector2(12,12),Vector2(24,24))): return "这里已有魔力草丛。"
	return ""
func cast(id: String, at: Vector2) -> bool:
	if is_instance_valid(session.simulation): session.simulation.flush()
	var actor: Node=session.world.active_resident
	var actor_id: String=actor.resident_id
	var rule := Rules.entry(id)
	if not session.combat.ready_for_action() or (is_instance_valid(session.gifts) and session.gifts.opened): return false
	if rule.is_empty() or rule.element!=magic.ensure(actor_id).element or not magic.ensure(actor_id).get("branch_unlocked",[]).has(id): return magic._reject("请先在技能树点亮这个分支技能。")
	if float(cooldowns.get(actor_id+":"+id,0))>0: return magic._reject("技能冷却中，还需%.1f秒。" % float(cooldowns[actor_id+":"+id]))
	var stats: Dictionary=session.vitals.ensure(actor_id)
	if float(stats.mana)<int(rule.mana_cost): return magic._reject("魔力不足，需要%d点。" % int(rule.mana_cost))
	var target: Node
	var targets: Array=[]
	var building := ""
	var direction := _direction(actor,at)
	var destination := at.snapped(Vector2(8,8))
	var error := ""
	if rule.branch=="build":
		if rule.rank==1:
			if fighting(actor_id): return magic._reject("战斗结束10秒后才能生成恢复设施。")
			error=_land(actor,destination,Vector2(24,24))
		elif id=="wood_build_2": error=_land(actor,destination,Vector2(24,24))
		elif id in ["wood_build_3","water_build_3","fire_build_2"]:
			building=session.construction.target_job(actor,at)
			if building=="": error="请指向120像素内已支付材料的在建或升级房屋。"
			elif id=="fire_build_2" and session.construction.records[building].kind=="arrow_tower": error="熔接不能用于箭楼。"
		elif id=="water_build_2":
			if actor.room_id!="" or not _near(actor,destination,120): error="请指向户外120像素内的农田。"
		elif id=="fire_build_3": error=_land(actor,destination,Vector2(96,80))
		elif id=="earth_build_3": error=_land(actor,destination,Vector2(48,48))
		elif id=="earth_build_2" and actor.room_id!="" and actor.room_id!="mine": error="勘测需在户外或矿洞施放。"
	elif rule.branch=="battle":
		if id in ["wood_battle_1","wood_battle_3","water_battle_1","water_battle_3","fire_battle_1","earth_battle_1","earth_battle_3"]:
			target=_single(actor,at)
			if not is_instance_valid(target): error="请指向200世界像素内可见敌人。"
		elif id=="wood_battle_2":
			for enemy: Node in _enemies(actor,actor.global_position,140):
				if direction.dot(actor.global_position.direction_to(enemy.global_position))>=cos(PI/6): targets.append(enemy)
			targets=targets.slice(0,4)
		elif id in ["water_battle_2","fire_battle_2","earth_battle_2"]:
			var radius := 120.0 if id=="water_battle_2" else (110.0 if id=="fire_battle_2" else 100.0)
			targets=_enemies(actor,actor.global_position,radius,5 if id=="water_battle_2" else 100)
		elif id=="fire_battle_3":
			if actor.room_id!="" or not _near(actor,at,200): error="焚风需在户外朝200像素内可见方向施放。"
			for enemy: Node in _enemies(actor,actor.global_position,185):
				var offset: Vector2=enemy.global_position-actor.global_position
				if offset.dot(direction)>=0 and offset.dot(direction)<=180 and absf(offset.cross(direction))<=40: targets.append(enemy)
		if error=="" and not is_instance_valid(target) and targets.is_empty() and id!="fire_battle_3": error="范围内没有可见敌人，魔力未扣除。"
	elif id=="fire_guard_3" and _buff(actor_id,"ember").get("armed",false): error="余烬已准备，无需重复施放。"
	elif id in ["fire_guard_1","earth_guard_2"]:
		destination=actor.global_position+direction*30
		var width := 120.0 if id=="earth_guard_2" else 60.0
		var height := 30.0 if id=="earth_guard_2" else 12.0
		var tangent := direction.rotated(PI/2)
		var bounds_size := Vector2(absf(tangent.x)*width+absf(direction.x)*height,absf(tangent.y)*width+absf(direction.y)*height)
		error=_land(actor,destination,bounds_size)
	if error!="": return magic._reject(error)
	var before: Dictionary=session.inventory.export_data()
	stats.mana-=int(rule.mana_cost)
	cooldowns[actor_id+":"+id]=float(rule.cooldown)
	match id:
		"wood_build_1","water_build_1","fire_build_1","earth_build_1":
			facilities[actor_id]={"actor":actor_id,"element":rule.element,"at":[destination.x,destination.y],"remaining":600.0,"life_tick":0.0,"mana_tick":0.0,"need_tick":0.0}
		"wood_build_2":
			bushes[actor_id]={"actor":actor_id,"element":"wood","at":[destination.x,destination.y],"tick":0.0,"epoch":0,"ready":{}}
		"wood_build_3": session.construction.finish_job(building)
		"water_build_2": _area(actor_id,"canal",destination,30.0,Vector2(60,16),direction)
		"water_build_3": session.construction.boost_job(building,20.0,1.5)
		"fire_build_2": session.construction.progress_job(building,0.3)
		"fire_build_3": _area(actor_id,"pit",destination,30.0,Vector2(96,80),Vector2.RIGHT)
		"earth_build_2": _buff_set(actor_id,"survey",30.0,{"room":actor.room_id})
		"earth_build_3": _area(actor_id,"array",destination,60.0,Vector2(48,48),Vector2.RIGHT)
		"wood_battle_1": _damage(target,2,actor_id); _status(target,actor_id,"root",2.0,{"root":2.0})
		"wood_battle_2":
			for enemy: Node in targets: _damage(enemy,6,actor_id); _status(enemy,actor_id,"thorns",3.0,{"slow":0.3})
		"wood_battle_3": _status(target,actor_id,"strangle",6.0,{"slow":0.5,"dot":3.0})
		"water_battle_1": _damage(target,8,actor_id); _knock(target,direction,20)
		"water_battle_2":
			for enemy: Node in targets: _damage(enemy,5,actor_id); _status(enemy,actor_id,"chill",4.0,{"slow":0.4})
		"water_battle_3": _status(target,actor_id,"freeze",8.0,{"root":3.0,"slow":0.3,"slow_after":3.0})
		"fire_battle_1":
			var origin: Vector2=actor.global_position+Vector2(0,-10)
			var d: Vector2=origin.direction_to(target.global_position)
			projectiles.append({"actor":actor_id,"at":[origin.x,origin.y],"dir":[d.x,d.y],"left":200.0})
		"fire_battle_2":
			for enemy: Node in targets: _damage(enemy,8,actor_id); _status(enemy,actor_id,"burn",4.0,{"dot":2.0})
			session.vitals.hurt(actor_id,2,{"kind":"magic","element":"fire"})
		"fire_battle_3":
			for enemy: Node in targets: _damage(enemy,12,actor_id); _status(enemy,actor_id,"burn",6.0,{"dot":2.0})
			for home_id: String in session.construction.records:
				var record: Dictionary=session.construction.records[home_id]
				var offset: Vector2=Vector2(record.at[0]+48,record.at[1]+40)-actor.global_position
				if offset.dot(direction)>=0 and offset.dot(direction)<=180 and absf(offset.cross(direction))<=40 and magic.skills._line_clear(actor,Vector2(record.at[0]+48,record.at[1]+91)): session.construction.skill_hit(home_id,18,"fire")
			_area(actor_id,"wind",actor.global_position+direction*90,0.5,Vector2(180,80),direction)
		"earth_battle_1": _damage(target,9,actor_id); _knock(target,direction,30)
		"earth_battle_2":
			for enemy: Node in targets: _damage(enemy,10,actor_id); _status(enemy,actor_id,"root",2.0,{"root":2.0})
		"earth_battle_3": _status(target,actor_id,"stone",4.0,{"root":4.0,"break_damage":0.0})
		"wood_guard_1": _buff_set(actor_id,"bark",10.0,{"rate":0.75})
		"wood_guard_2": _buff_set(actor_id,"roots",12.0,{"rate":0.6,"no_knock":true})
		"wood_guard_3":
			session.vitals.heal(actor_id,session.vitals.max_life(actor_id)*0.3)
			for ally: Node in session.world.controllable:
				if ally!=actor and not ally.dead and ally.room_id==actor.room_id and ally.global_position.distance_to(actor.global_position)<=100: session.vitals.heal(ally.resident_id,session.vitals.max_life(ally.resident_id)*0.15)
		"water_guard_1": _buff_set(actor_id,"membrane",15.0,{"shield":20.0})
		"water_guard_2":
			for key: String in ["bleeding","poison","burning"]: _buffs(actor_id).erase(key)
			session.vitals.heal(actor_id,session.vitals.max_life(actor_id)*0.15)
		"water_guard_3": _buff_set(actor_id,"tide",12.0,{"shield":60.0,"ranged_rate":0.7})
		"fire_guard_1": _area(actor_id,"firewall",destination,6.0,Vector2(60,12),direction.rotated(PI/2))
		"fire_guard_2": _buff_set(actor_id,"shell",10.0,{"melee_rate":0.6,"reflect":0.25})
		"fire_guard_3": _buff_set(actor_id,"ember",-1.0,{"armed":true})
		"earth_guard_1": _buff_set(actor_id,"skin",12.0,{"rate":0.8})
		"earth_guard_2": _area(actor_id,"wall",destination,10.0,Vector2(120,30),direction.rotated(PI/2))
		"earth_guard_3": _buff_set(actor_id,"embrace",8.0,{"rate":0.5,"no_control":true,"no_knock":true,"immobile":true})
	var cast_key := _area(actor_id,"cast",actor.global_position,0.8,Vector2(24,24),direction)
	areas[cast_key].merge({"skill":id,"rank":rule.rank,"branch":rule.branch})
	if rule.branch=="battle": note_combat(actor_id)
	_rebuild_visuals()
	session.vitals._sync_actors()
	return session.production.commit(before,"施放%s，消耗%d魔力。" % [rule.name,rule.mana_cost])
func _buffs(id: String) -> Dictionary:
	if not buffs.has(id): buffs[id]={}
	return buffs[id]
func _buff(id: String, key: String) -> Dictionary:
	return buffs.get(id,{}).get(key,{})
func _buff_set(id: String, key: String, duration: float, fields: Dictionary) -> void:
	var value := fields.duplicate(true)
	value.remaining=duration
	value["source"]=str(fields.get("source",{"bark":"wood_guard_1","roots":"wood_guard_2","tide":"water_guard_3","shell":"fire_guard_2","skin":"earth_guard_1","embrace":"earth_guard_3"}.get(key,key)))
	if value.has("shield"):
		for other: String in _buffs(id):
			if other==key or not buffs[id][other].has("shield"): continue
			if float(buffs[id][other].shield)>float(value.shield): value.shield=0.0
			else: buffs[id][other].shield=0.0
	_buffs(id)[key]=value
func ordinary_rate(id: String, context: Dictionary={}) -> float:
	var rate := 1.0
	var sources: Dictionary={}
	for key: String in buffs.get(id,{}):
		var b: Dictionary=buffs[id][key]
		var source: String=str(b.get("source",key))
		var factor := float(b.get("rate",1.0))
		if context.get("kind","")=="ranged": factor*=float(b.get("ranged_rate",1.0))
		if context.get("kind","")=="melee": factor*=float(b.get("melee_rate",1.0))
		sources[source]=minf(float(sources.get(source,1)),factor)
	for factor: float in sources.values(): rate*=factor
	return rate
func array_rate(id: String) -> float:
	var actor: Node=magic._actor(id)
	if not is_instance_valid(actor) or actor.room_id!="": return 1.0
	for area: Dictionary in areas.values():
		if area.kind=="array" and float(area.hp)>0 and _contains(area,actor.global_position): return 0.9
	return 1.0
func absorb(id: String, damage: float) -> float:
	var best := ""
	var capacity := 0.0
	for key: String in buffs.get(id,{}):
		var value := float(buffs[id][key].get("shield",0))
		if value>capacity: best=key; capacity=value
	if best!="": buffs[id][best].shield=maxf(0,capacity-damage)
	return maxf(0,damage-capacity)
func prevent_death(id: String, life: float, damage: float) -> bool:
	if life<=0 or damage<life or not _buff(id,"ember").get("armed",false): return false
	_buffs(id).erase("ember")
	cooldowns[id+":fire_guard_3"]=300.0
	session.vitals.ensure(id).life=minf(session.vitals.max_life(id),1.0+session.vitals.max_life(id)*0.4)
	return true
func immobile(id: String) -> bool:
	return bool(_buff(id,"embrace").get("immobile",false)) or (not _buff(id,"rooted").is_empty() and not immune_control(id))
func immune_control(id: String) -> bool:
	return bool(_buff(id,"embrace").get("no_control",false))
func knock_player(id: String, displacement: Vector2) -> bool:
	if bool(_buff(id,"roots").get("no_knock",false)) or bool(_buff(id,"embrace").get("no_knock",false)): return false
	var actor: Node=magic._actor(id)
	if not is_instance_valid(actor) or actor.dead: return false
	var destination: Vector2=actor.global_position+displacement
	if not magic.skills._landing(actor,destination) or not magic.skills._line_clear(actor,destination): return false
	actor.global_position=destination; return true
func player_status(id: String, kind: String, duration: float) -> bool:
	if kind=="rooted" and immune_control(id): return false
	_buff_set(id,kind,maxf(0,duration),{"tick":0.0})
	return true
func reflect(id: String, received: float, context: Dictionary) -> void:
	if context.get("kind","")!="melee" or context.get("reflected",false): return
	var enemy: Node=session.combat.enemies.get(str(context.get("enemy","")))
	if is_instance_valid(enemy) and received>0: _damage(enemy,received*float(_buff(id,"shell").get("reflect",0)),id)
func _damage(enemy: Node, raw: float, actor: String) -> void:
	if is_instance_valid(enemy) and enemy.hp>0 and raw>0:
		note_combat(actor); session.combat.apply_skill_damage(enemy,raw,actor)
func _status(enemy: Node, actor: String, kind: String, duration: float, values: Dictionary) -> void:
	if not is_instance_valid(enemy) or enemy.hp<=0: return
	var state := values.duplicate(true)
	state.merge({"enemy":enemy.enemy_id,"actor":actor,"kind":kind,"remaining":duration,"elapsed":0.0,"tick":0.0})
	if float(state.get("root",0))>0:
		if float(control_locks.get(enemy.enemy_id,0))>0: state.root=0.0
		else: control_locks[enemy.enemy_id]=10.0
	statuses[enemy.enemy_id+":"+actor+":"+kind]=state
func rooted(enemy_id: String) -> bool:
	for state: Dictionary in statuses.values():
		if state.enemy==enemy_id and float(state.get("root",0))>0: return true
	return false
func speed_rate(enemy_id: String) -> float:
	var sources: Dictionary={}
	for state: Dictionary in statuses.values():
		if state.enemy==enemy_id and float(state.elapsed)>=float(state.get("slow_after",0)):
			var source: String=str(state.kind)
			sources[source]=maxf(float(sources.get(source,0)),float(state.get("slow",0)))
	for key: String in buffs.get(enemy_id,{}):
		var buff: Dictionary=buffs[enemy_id][key]
		var source: String="suppress" if key=="slowed" else str(buff.get("source",key))
		sources[source]=maxf(float(sources.get(source,0)),float(buff.get("slow",0.2 if key=="slowed" else 0.0)))
	var enemy: Node=session.combat.enemies.get(enemy_id)
	if is_instance_valid(enemy):
		for area: Dictionary in areas.values():
			if area.kind=="firewall" and _contains(area,enemy.global_position): sources["firewall"]=0.2
	if is_instance_valid(magic.enchants): sources["enchant_water"]=1.0-magic.enchants.slow_rate(enemy_id)
	var rate := 1.0
	for reduction: float in sources.values(): rate*=1.0-clampf(reduction,0,0.6)
	return maxf(0.4,rate)
func observe_hit(enemy_id: String, damage: float) -> void:
	for key: String in statuses.keys():
		var state: Dictionary=statuses[key]
		if state.enemy==enemy_id and state.kind=="stone":
			state.break_damage=float(state.get("break_damage",0))+maxf(0,damage)
			if state.break_damage>=20: statuses.erase(key)
func _knock(enemy: Node, direction: Vector2, distance: float) -> void:
	if not is_instance_valid(enemy) or enemy.hp<=0: return
	var query := PhysicsRayQueryParameters2D.create(enemy.global_position,enemy.global_position+direction*distance,1|4,[enemy.get_rid()])
	var hit: Dictionary=enemy.get_world_2d().direct_space_state.intersect_ray(query)
	var end: Vector2=enemy.global_position+direction*distance if hit.is_empty() else hit.position-direction*6
	if not enemy.territory.has_area() or enemy.territory.grow(-5).has_point(end):
		var shape := PhysicsShapeQueryParameters2D.new()
		shape.shape=CircleShape2D.new(); shape.shape.radius=5
		shape.transform=Transform2D(0,end); shape.collision_mask=1|4; shape.exclude=[enemy.get_rid()]
		if enemy.get_world_2d().direct_space_state.intersect_shape(shape).is_empty(): enemy.global_position=end
func _area(actor: String, kind: String, at: Vector2, duration: float, size: Vector2, direction: Vector2) -> String:
	var key := "area:"+str(next_id); next_id+=1
	# Replacing an owner's same construct prevents unlimited wall/trap accumulation.
	for old: String in areas.keys():
		if areas[old].actor==actor and areas[old].kind==kind: areas.erase(old)
	areas[key]={"actor":actor,"element":str(magic.ensure(actor).element),"kind":kind,"at":[at.x,at.y],"remaining":duration,"size":[size.x,size.y],"angle":direction.angle(),"ticks":{},"hp":200.0 if kind=="array" else 40.0}
	return key
func _contains(area: Dictionary, at: Vector2) -> bool:
	var offset := (at-pos(area)).rotated(-float(area.get("angle",0)))
	return Rect2(-Vector2(area.size[0],area.size[1])/2,Vector2(area.size[0],area.size[1])).has_point(offset)
func barrier_blocks(from: Vector2, to: Vector2) -> bool:
	for area: Dictionary in areas.values():
		if area.kind!="wall": continue
		var a := (from-pos(area)).rotated(-float(area.angle))
		var b := (to-pos(area)).rotated(-float(area.angle))
		var half := Vector2(area.size[0],area.size[1])/2
		var box := Rect2(-half,half*2)
		if box.has_point(a) or box.has_point(b): return true
		var corners := [-half,Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)]
		for i in range(4):
			if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4])!=null: return true
	return false
func interact(key: String) -> bool:
	var actor: Node=session.world.active_resident
	if not session.production.allowed(actor) or actor.room_id!="": return false
	if key.begins_with("bush:"):
		var owner := key.trim_prefix("bush:")
		if not bushes.has(owner) or actor.global_position.distance_to(pos(bushes[owner]))>23: return false
		var ready: Dictionary=bushes[owner].ready
		if ready.is_empty(): return magic._reject("暂无草药；每120在线秒三种草药各18%判定。")
		var before: Dictionary=session.inventory.export_data()
		if not session.inventory.exchange(actor.resident_id,{},ready): return magic._reject("背包空间不足，草药保留。")
		bushes[owner].ready={}; _rebuild_visuals()
		return session.production.commit(before,"已采集魔力草丛中的草药。")
	if key.begins_with("facility:"):
		var owner := key.trim_prefix("facility:")
		if not facilities.has(owner): return false
		var f: Dictionary=facilities[owner]
		if actor.global_position.distance_to(pos(f))>23: return false
		if f.element=="fire" and not fighting(actor.resident_id):
			var before: Dictionary=session.inventory.export_data()
			if session.homestead.stove(actor): return session.production.commit(before,"旺炉烹饪操作已保存。")
			return false
		return magic._reject("进入半径80像素范围，脱离战斗后自动恢复；剩余%d秒。" % ceili(float(f.remaining)))
	return false
func advance(delta: float) -> void:
	var left := maxf(0,delta)
	while left>0.00001:
		var step := minf(left,0.5); left-=step; _step(step)
func _step(delta: float) -> void:
	for clock: Dictionary in [cooldowns,combat_time,control_locks]:
		for key: String in clock.keys():
			clock[key]=maxf(0,float(clock[key])-delta)
			if clock[key]<=0: clock.erase(key)
	for id: String in buffs:
		for key: String in buffs[id].keys():
			var b: Dictionary=buffs[id][key]
			if float(b.remaining)>=0:
				b.remaining=maxf(0,float(b.remaining)-delta)
				if b.remaining<=0: buffs[id].erase(key); continue
			if key in ["bleeding","poison","burning"] and session.world.active_resident.resident_id==id:
				b.tick=float(b.get("tick",0))+delta
				if b.tick>=1: b.tick-=1; session.vitals.hurt(id,1,{"kind":"status"})
	var actor: Node=session.world.active_resident
	var actor_id: String=actor.resident_id
	var rebuild := false
	for owner: String in facilities.keys():
		var f: Dictionary=facilities[owner]
		var span := minf(delta,float(f.remaining))
		f.remaining=maxf(0,float(f.remaining)-delta)
		if not actor.dead and actor.room_id=="" and not fighting(actor_id) and actor.global_position.distance_to(pos(f))<=80:
			# Per-character clocks prevent swapping residents to transfer partial recovery credit.
			if not f.has("clocks"): f.clocks={}
			if not f.clocks.has(actor_id): f.clocks[actor_id]={"life":0.0,"mana":0.0,"need":0.0}
			var clocks: Dictionary=f.clocks[actor_id]
			var stats: Dictionary=session.vitals.ensure(actor_id)
			for stat: String in ["mana","life","need"]:
				var interval := 5.0 if stat=="mana" or f.element=="wood" or (stat=="need" and f.element=="water") else 10.0
				if f.element=="earth" and stat!="mana": continue
				if stat=="need" and f.element not in ["water","fire"]: continue
				clocks[stat]=float(clocks[stat])+span
				while float(clocks[stat])+0.000001>=interval:
					clocks[stat]-=interval
					if stat=="life": session.vitals.heal(actor_id,1)
					elif stat=="mana": stats.mana=minf(magic.max_mana(actor_id),float(stats.mana)+1)
					else:
						var need := "thirst" if f.element=="water" else "hunger"
						stats[need]=minf(10,float(stats[need])+1)
		if f.remaining<=0: facilities.erase(owner); rebuild=true
	for owner: String in bushes:
		var b: Dictionary=bushes[owner]
		b.tick+=delta
		while float(b.tick)>=120:
			b.tick-=120; b.epoch+=1
			var rng := RandomNumberGenerator.new()
			rng.seed=session.world.resource_seed ^ owner.hash() ^ (int(b.epoch)*83492791)
			for herb: String in ["ginseng","reishi","goji"]:
				if rng.randf()<0.18 and not b.ready.has(herb): b.ready[herb]=1; rebuild=true
	for key: String in statuses.keys():
		var state: Dictionary=statuses[key]
		var enemy: Node=session.combat.enemies.get(str(state.enemy))
		if not is_instance_valid(enemy) or enemy.hp<=0: statuses.erase(key); rebuild=true; continue
		var span := minf(delta,float(state.remaining))
		state.remaining=maxf(0,float(state.remaining)-span); state.elapsed+=span
		state.root=maxf(0,float(state.get("root",0))-span)
		if float(state.get("dot",0))>0:
			state.tick+=span
			while float(state.tick)+0.000001>=1 and enemy.hp>0: state.tick-=1; _damage(enemy,float(state.dot),str(state.actor))
		if state.remaining<=0: statuses.erase(key); rebuild=true
	for key: String in areas.keys():
		var area: Dictionary=areas[key]
		var span := minf(delta,float(area.remaining))
		if area.kind=="canal":
			for p: Dictionary in session.homestead.plots:
				var offset := (Vector2(float(p.x)+8,float(p.y)+8)-pos(area)).rotated(-float(area.angle))
				if Rect2(-Vector2(area.size[0],area.size[1])/2,Vector2(area.size[0],area.size[1])).grow(16).has_point(offset):
					p.dry=false; p.age=0.0
					session.homestead.refresh()
		if area.kind in ["pit","firewall"]:
			var interval := 3.0 if area.kind=="pit" else 1.0
			for enemy: Node in session.combat.target_enemies():
				if enemy.hp<=0 or enemy.get_parent()==null: continue
				if _contains(area,enemy.global_position):
					area.ticks[enemy.enemy_id]=float(area.ticks.get(enemy.enemy_id,0))+span
					while float(area.ticks[enemy.enemy_id])+0.000001>=interval and enemy.hp>0:
						area.ticks[enemy.enemy_id]-=interval; _damage(enemy,4 if area.kind=="pit" else 3,str(area.actor))
				else: area.ticks.erase(enemy.enemy_id)
		if area.kind=="array" and float(area.hp)>0:
			for enemy: Node in session.combat.target_enemies():
				if enemy.hp>0 and enemy.get_parent()!=null and enemy.global_position.distance_to(pos(area))<=32:
					area.ticks[enemy.enemy_id]=float(area.ticks.get(enemy.enemy_id,0))+span
					if area.ticks[enemy.enemy_id]>=2: area.ticks[enemy.enemy_id]-=2; area.hp=maxf(0,float(area.hp)-10*0.8)
		area.remaining=maxf(0,float(area.remaining)-span)
		if area.remaining<=0 or (area.kind=="array" and area.hp<=0): areas.erase(key); rebuild=true
	_advance_projectiles(delta)
	if rebuild: _rebuild_visuals()
	_update_visuals()
func _advance_projectiles(delta: float) -> void:
	for i in range(projectiles.size()-1,-1,-1):
		var p: Dictionary=projectiles[i]
		var from := pos(p)
		var direction := Vector2(p.dir[0],p.dir[1])
		var step := minf(float(p.left),180*delta)
		var to := from+direction*step
		var query := PhysicsRayQueryParameters2D.create(from,to,1|4|8)
		var hit: Dictionary=session.world.get_world_2d().direct_space_state.intersect_ray(query)
		if barrier_blocks(from,to): projectiles.remove_at(i)
		elif not hit.is_empty():
			if hit.collider.is_in_group("hostile_targets"):
				_damage(hit.collider,10,str(p.actor)); _status(hit.collider,str(p.actor),"burn",3.0,{"dot":2.0})
			projectiles.remove_at(i)
		else:
			p.at=[to.x,to.y]; p.left-=step
			if p.left<=0: projectiles.remove_at(i)
func _rebuild_visuals() -> void:
	for key: String in visuals:
		if key.begins_with("facility:") or key.begins_with("bush:"): session.world.points.erase("branch:"+key)
		if is_instance_valid(visuals[key]): visuals[key].free()
	visuals.clear()
	for owner: String in facilities: _visual("facility:"+owner,"facility",facilities[owner])
	for owner: String in bushes: _visual("bush:"+owner,"bush",bushes[owner])
	for key: String in areas: _visual(key,str(areas[key].kind),areas[key])
	_update_visuals()
func _visual(key: String, kind: String, record: Dictionary) -> void:
	var node := Visual.new()
	node.kind=kind; node.record=record; node.runtime=self
	node.position=pos(record)
	var parent: Node=session.world.objects
	var room_id: String=session.world.active_resident.room_id
	if kind in ["cast","enchant_rune"] or key.begins_with("buff:"):
		var caster: Node=magic._actor(str(record.get("actor","")))
		if is_instance_valid(caster): room_id=str(caster.room_id)
	if (kind in ["survey","cast","enchant_rune"] or key.begins_with("buff:")) and room_id!="" and session.interiors.rooms.has(room_id): parent=session.interiors.rooms[room_id]
	parent.add_child(node); node.global_position=pos(record); visuals[key]=node
	if kind in ["facility","bush"]:
		var label := "魔力草丛" if kind=="bush" else str(Rules.DATA[record.element].build[0][0])
		session.world.points["branch:"+key]={"position":node.position,"radius":22.0,"label":label,"action":"采集" if kind=="bush" else ("烹饪 / 恢复" if record.element=="fire" else "范围恢复"),"description":label,"source":node}
func _update_visuals() -> void:
	for key: String in visuals: visuals[key].queue_redraw()
	var desired: Dictionary={}
	for i in range(projectiles.size()): desired["projectile:"+str(i)]={"at":projectiles[i].at,"element":"fire"}
	for at: Vector2 in survey_points(str(session.world.active_resident.resident_id)):
		desired["survey:"+str(desired.size())]={"at":[at.x,at.y],"element":"earth"}
	var active: Node=session.world.active_resident
	if not active.dead and magic.ensure(active.resident_id).unlocked.has("trunk_1"):
		desired["buff:passive:"+active.resident_id]={"at":[active.global_position.x,active.global_position.y],"element":magic.ensure(active.resident_id).element,"actor":active.resident_id,"passive":true}
	for category: String in ["burns","slows"]:
		var effects: Dictionary=magic.enchants.get(category)
		for id: String in effects:
			var target: Node=magic.enchants._target(id)
			if is_instance_valid(target) and target.hp>0: desired["enchant:"+category+":"+id]={"at":[target.global_position.x,target.global_position.y-8],"element":"fire" if category=="burns" else "water","enchantment":category}
	for key: String in statuses:
		var enemy: Node=session.combat.enemies.get(str(statuses[key].enemy))
		if is_instance_valid(enemy) and enemy.hp>0: desired["status:"+key]={"at":[enemy.global_position.x,enemy.global_position.y-8],"element":magic.ensure(str(statuses[key].actor)).element,"stone":statuses[key].kind=="stone"}
	for actor_id: String in buffs:
		var actor: Node=magic._actor(actor_id)
		if is_instance_valid(actor) and not buffs[actor_id].is_empty() : desired["buff:"+actor_id]={"at":[actor.global_position.x,actor.global_position.y-8],"element":magic.ensure(actor_id).element,"actor":actor_id,"shield":_buff(actor_id,"tide").get("shield",_buff(actor_id,"membrane").get("shield",0))}
	for key: String in visuals.keys():
		if key.begins_with("status:") or key.begins_with("projectile:") or key.begins_with("buff:") or key.begins_with("survey:") or key.begins_with("enchant:"):
			if not desired.has(key): visuals[key].free(); visuals.erase(key)
	for key: String in desired:
		if not visuals.has(key): _visual(key,"survey" if key.begins_with("survey:") else ("orb" if key.begins_with("projectile:") else "mark"),desired[key])
		if key.begins_with("buff:"):
			var actor: Node=magic._actor(str(desired[key].get("actor",key.trim_prefix("buff:"))))
			var parent: Node=session.world.objects
			if is_instance_valid(actor) and actor.room_id!="" and session.interiors.rooms.has(actor.room_id): parent=session.interiors.rooms[actor.room_id]
			if visuals[key].get_parent()==null: parent.add_child(visuals[key])
			elif visuals[key].get_parent()!=parent: visuals[key].reparent(parent,true)
		visuals[key].global_position=pos(desired[key]); visuals[key].record=desired[key]
func survey_points(actor_id: String) -> Array:
	var result: Array=[]
	if _buff(actor_id,"survey").is_empty(): return result
	var actor: Node=magic._actor(actor_id)
	if not is_instance_valid(actor) or actor.room_id!=str(_buff(actor_id,"survey").get("room","")): return result
	for key: String in session.world.points:
		if not (key.begins_with("herb:") or key.begins_with("wood:") or key.begins_with("ore:") or key.begins_with("forage:")): continue
		var info: Dictionary=session.world.points[key]
		var at: Vector2=info.position
		if actor.room_id=="" and at.distance_to(actor.global_position)<=200: result.append(at)
	if actor.room_id=="mine":
		for ore: Node in session.interiors.rooms["mine"].find_children("*","Node2D",true,false):
				if "resource_id" in ore and ore.global_position.distance_to(actor.global_position)<=200: result.append(ore.global_position)
	return result
func snapshot(actor_id: String) -> Dictionary:
	return {"combat":fighting(actor_id),"cooldowns":cooldowns.duplicate(),"buffs":buffs.get(actor_id,{}).duplicate(true),"facilities":facilities.size(),"bushes":bushes.size()}
func export_state() -> Dictionary:
	return {"facilities":facilities.duplicate(true),"bushes":bushes.duplicate(true),"buffs":buffs.duplicate(true),"cooldowns":cooldowns.duplicate(true),"combat_time":combat_time.duplicate(true),"statuses":statuses.duplicate(true),"control_locks":control_locks.duplicate(true),"areas":areas.duplicate(true),"projectiles":projectiles.duplicate(true),"next_id":next_id}
func restore(data: Dictionary) -> void:
	facilities.clear(); bushes.clear(); buffs.clear(); cooldowns.clear(); combat_time.clear(); statuses.clear(); control_locks.clear(); areas.clear(); projectiles.clear()
	for key: String in ["facilities","bushes","buffs","cooldowns","combat_time","statuses","control_locks","areas"]:
		if data.get(key,{}) is Dictionary: set(key,data.get(key,{}).duplicate(true))
	if data.get("projectiles",[]) is Array: projectiles=data.get("projectiles",[]).duplicate(true)
	next_id=maxi(0,int(data.get("next_id",0)))
	for records: Dictionary in [facilities,bushes,areas]:
		for key: String in records.keys():
			var record: Variant=records[key]
			if not record is Dictionary or not record.get("at",[]) is Array or record.at.size()!=2 or not is_instance_valid(magic._actor(str(record.get("actor","")))): records.erase(key)
	_rebuild_visuals()
