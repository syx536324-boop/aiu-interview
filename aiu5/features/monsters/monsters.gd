# Owns deterministic goblin encounters, physical hits, civilian safety, mine escorts and complete saved monster state.
extends Node
const Rules := preload("res://features/monsters/catalog.gd")
const Goblin := preload("res://features/monsters/goblin.gd")
const Flight := preload("res://features/monsters/flight.gd")
const Navigation := preload("res://features/village/navigation.gd")
const Swing := preload("res://features/combat/swing.gd")
var session: Node
var slots: Dictionary={}
var units: Dictionary={}
var orders: Dictionary={}
var handled: Dictionary={}
var root_locks: Dictionary={}
var flights: Array=[]
var flight_nodes: Dictionary={}
var next_flight := 0
var online := 0.0
var seed := 0
var focus_left := 0.0
func start(controller: Node) -> void:
	session=controller; seed=session.world.resource_seed
	_make_slots()
	session.interiors.room_created.connect(_room_created)
	session.interiors.room_releasing.connect(_room_releasing)
func running() -> bool:
	return is_instance_valid(session) and not session.overview and not session.menu_paused and not get_tree().paused and not session.persistence.restoring and not session.tribes.relics.failed
func actor_key(actor: Node) -> String:
	return str(actor.enemy_id) if "enemy_id" in actor else str(actor.resident_id)
func actor(id: String) -> Node:
	if session.combat.enemies.has(id): return session.combat.enemies[id]
	return session.magic._actor(id)
func alive(node: Node) -> bool: return is_instance_valid(node) and "dead" in node and not node.dead
func same_place(a: Node,b: Node) -> bool:
	return alive(a) and alive(b) and str(a.room_id)==str(b.room_id)
func characters() -> Array[Node]:
	var result: Array[Node]=[]
	if alive(session.world.active_resident): result.append(session.world.active_resident)
	for id: String in session.tribes.population.members:
		var node: Node=session.tribes.population.node(id)
		if alive(node): result.append(node)
	return result
func _make_slots() -> void:
	slots.clear()
	for y in range(-7,19):
		for x in range(-10,0):
			var rng:=RandomNumberGenerator.new(); rng.seed=(str(seed)+":goblin:forest:"+str(x)+":"+str(y)).hash()
			if rng.randf()>=Rules.FOREST_CHANCE: continue
			var at:=Vector2(x*256,y*256)+Vector2(rng.randf_range(32,224),rng.randf_range(32,224))
			if not session.world.BOUNDS.grow(-32).has_point(at): continue
			if at.distance_to(session.tribes.centers.forest)<270 or at.distance_to(Vector2(-228,294))<100: continue
			_add_slot("goblin:forest:%d:%d"%[x,y],"",at)
	for y in range(4):
		for x in range(6):
			var rng:=RandomNumberGenerator.new(); rng.seed=(str(seed)+":goblin:cave:"+str(x)+":"+str(y)).hash()
			if rng.randf()>=Rules.CAVE_CHANCE: continue
			var at:=Vector2(x*320,y*240)+Vector2(rng.randf_range(40,280),rng.randf_range(40,200))
			if at.distance_to(Vector2(960,944))<160: continue
			_add_slot("goblin:mine:%d:%d"%[x,y],"mine",at)
func _add_slot(id: String,room: String,at: Vector2) -> void:
	slots[id]={"room":room,"at":[at.x,at.y],"home":[at.x,at.y],"spawned":false,"dead":false,"ready_at":0.0,"level":1,"hp":0.0}
func _room_created(id: String,room: Node) -> void:
	if id!="mine": return
	for key: String in units:
		if units[key].room_id==id and units[key].get_parent()==null: room.objects.add_child(units[key])
func _room_releasing(id: String,_room: Node) -> void:
	if id!="mine": return
	for key: String in units:
		var unit: Node=units[key]
		if unit.room_id==id: _sync(key); _park(unit)
	for key: int in flight_nodes.keys():
		var node: Node=flight_nodes[key]
		if not flights.any(func(record: Dictionary)->bool:return int(record.id)==key and record.room==id): continue
		if is_instance_valid(node) and node.get_parent()!=null: node.get_parent().remove_child(node)
func _park(unit: Node) -> void:
	if unit.get_parent()!=null: unit.get_parent().remove_child(unit)
func _parent(room: String) -> Node:
	if room=="": return session.world.objects
	var instance: Node=session.interiors.rooms.get(room)
	return instance.objects if is_instance_valid(instance) else null
func _sync(id: String) -> void:
	if not units.has(id) or not slots.has(id): return
	var unit: Node=units[id]
	slots[id].merge(unit.saved(),true)
	if unit.hp<=0 and not slots[id].dead:
		slots[id].dead=true; slots[id].ready_at=online+Rules.RESPAWN
func note_death(unit: Node) -> void:
	if slots.has(unit.enemy_id): _sync(unit.enemy_id)
func _spawn(record: Dictionary,id: String) -> void:
	if units.has(id): _drop(id)
	record.level=Rules.spawn_level(session.tribes.population.current_player_level())
	record.hp=Rules.life(int(record.level)); record.dead=false; record.spawned=true
	record.at=record.home.duplicate(); record.cooldowns={}; record.attack=""; record.attack_left=0.0; record.recovery=0.0
	_ensure(id)
func _ensure(id: String) -> Node:
	if units.has(id): return units[id]
	var record: Dictionary=slots[id]
	var unit:=Goblin.new(); unit.monsters=self; unit.combat=session.combat; unit.enemy_id=id; unit.resident_id=id; unit.tribe="goblin"; unit.role="goblin"; unit.room_id=str(record.room)
	unit.set_meta("streaming_exempt",true); unit.set_meta("goblin",true)
	unit.load_saved(record); units[id]=unit; session.combat.enemies[id]=unit
	var magic: Dictionary=session.magic.ensure(id); magic.element="wood"; magic.level=int(record.level); magic.unlocked=[]
	return unit
func _drop(id: String) -> void:
	if not units.has(id): return
	var unit: Node=units[id]; _park(unit); session.combat.enemies.erase(id); units.erase(id); unit.free()
func _safe_spawn(record: Dictionary,people: Array[Node]) -> bool:
	var at:=Vector2(record.home[0],record.home[1])
	for person: Node in people:
		if person.room_id==record.room and person.position.distance_to(at)<160: return false
	# A free grid centre alone can still put the body's edge inside a live tree or ore collider.
	for offset: Vector2 in [Vector2.ZERO,Vector2(6,0),Vector2(-6,0),Vector2(0,6),Vector2(0,-6)]:
		if not walkable(at+offset,str(record.room)): return false
	var parent:=_parent(str(record.room))
	if is_instance_valid(parent) and parent.is_inside_tree():
		var query:=PhysicsShapeQueryParameters2D.new(); var shape:=CircleShape2D.new(); shape.radius=6
		query.shape=shape; query.transform=Transform2D(0,parent.to_global(at)); query.collision_mask=1|2|4|8|16
		if not parent.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	return true
func _focus() -> void:
	var people:=characters()
	for id: String in slots:
		var record: Dictionary=slots[id]; var at:=Vector2(record.at[0],record.at[1]); var near:=false
		if record.room=="mine" and not session.interiors.rooms.has("mine"): continue
		for person: Node in people:
			if person.room_id==record.room and person.position.distance_to(at)<420: near=true; break
		if not near:
			if units.has(id): _sync(id); units[id].set_meta("monster_active",false); _park(units[id])
			continue
		if (not record.spawned or (record.dead and online>=float(record.ready_at))) and _safe_spawn(record,people): _spawn(record,id)
		if not record.spawned or record.dead: continue
		var unit: Node=_ensure(id); var parent:=_parent(str(record.room))
		unit.set_meta("monster_active",true)
		if is_instance_valid(parent) and unit.get_parent()==null: parent.add_child(unit)
func advance(delta: float) -> void:
	if not running(): return
	online+=maxf(0,delta)
	for id: String in root_locks.keys():
		root_locks[id]=maxf(0,float(root_locks[id])-delta)
		if root_locks[id]<=0: root_locks.erase(id)
	for id: String in units.keys():
		var unit: Node=units[id]
		if unit.hp>0 and not unit.is_inside_tree() and unit.get_meta("monster_active",false) and _parent(unit.room_id)!=null: unit.step(delta)
		_sync(id)
	focus_left-=delta
	if focus_left<=0: focus_left=0.5; _focus()
func walkable(at: Vector2,room: String) -> bool:
	var nav=session.world.navigation
	if room!="":
		if not session.interiors.rooms.has(room): return false
		nav=session.interiors.rooms[room].navigation
	var cell:=Vector2i(floori(at.x/8),floori(at.y/8))
	return nav.grid.is_in_boundsv(cell) and not nav.grid.is_point_solid(cell)
func path_to(body: Node,to: Vector2) -> PackedVector2Array:
	# Combat routes are local; an unreachable target never triggers a full-map search.
	var origin: Vector2=(body.position.min(to)-Vector2(80,80)).snapped(Vector2(8,8))
	var end: Vector2=(body.position.max(to)+Vector2(80,80)).snapped(Vector2(8,8))
	var obstacles: Array[Rect2]=[]
	if body.room_id=="":
		origin=origin.max(session.world.MIN); end=end.min(session.world.SIZE)
		for rect: Rect2 in session.world.logical_obstacles(session.world.gate_visual.open):
			if rect.intersects(Rect2(origin,end-origin)): obstacles.append(rect)
	else:
		var room: Node=session.interiors.rooms.get(body.room_id)
		if not is_instance_valid(room): return PackedVector2Array()
		origin=origin.max(Vector2.ZERO); end=end.min(room.size)
		obstacles=room.collision_rects.duplicate()
	var nav:=Navigation.new(); nav.rebuild(obstacles,end,origin)
	return nav.find_path(body.position,to)
func line_clear(observer: Node,to: Vector2) -> bool:
	if observer.is_inside_tree():
		var parent:=_parent(observer.room_id)
		var end: Vector2=parent.to_global(to)
		var query:=PhysicsRayQueryParameters2D.create(observer.global_position,end,1|4,[observer.get_rid()])
		return observer.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
	var span: float=observer.position.distance_to(to)
	for i in range(1,maxi(2,ceili(span/4.0))):
		if not walkable(observer.position.lerp(to,float(i)/maxf(2,ceilf(span/4.0))),observer.room_id): return false
	return true
func choose_target(unit: Node) -> Node:
	var nearest:=181.0; var found: Node
	for person: Node in characters():
		if not same_place(unit,person): continue
		var gap: float=unit.position.distance_to(person.position)
		var weight:=0.80 if "role" in person and person.role in ["archer","charger"] else 1.0
		if gap*weight<nearest and gap<=200 and line_clear(unit,person.position): nearest=gap*weight; found=person
	return found
func wander_destination(unit: Node) -> Vector2:
	var rng:=RandomNumberGenerator.new(); rng.seed=(str(seed)+unit.enemy_id+str(floori(online/2.5))).hash()
	var at: Vector2=unit.home_anchor+Vector2(rng.randf_range(-64,64),rng.randf_range(-64,64))
	return at if walkable(at,unit.room_id) else unit.home_anchor
func move_body(body: Node,to: Vector2,delta: float,speed:=32.0) -> void:
	if session.magic.skills.rooted(body.enemy_id) or session.magic.branches.immobile(body.enemy_id): body.velocity=Vector2.ZERO; return
	if body.position.distance_to(to)<9: body.velocity=Vector2.ZERO; return
	if body.route_left<=0: body.navigation=path_to(body,to); body.route_left=0.6+float(absi(body.enemy_id.hash())%15)/100.0
	while not body.navigation.is_empty() and body.position.distance_to(body.navigation[0])<5: body.navigation.remove_at(0)
	if body.navigation.is_empty(): body.velocity=Vector2.ZERO; return
	var wanted: Vector2=body.position.direction_to(body.navigation[0])*speed*session.magic.branches.speed_rate(body.enemy_id)
	body.velocity=body.velocity.move_toward(wanted,speed*8*delta)
	var motion: Vector2=(body.velocity*delta).limit_length(body.position.distance_to(body.navigation[0]))
	var previous: Vector2=body.position
	if body.is_inside_tree():
		var collision: KinematicCollision2D=body.move_and_collide(motion)
		if collision!=null: body.move_and_collide(collision.get_remainder().slide(collision.get_normal()))
	else: body.position+=motion
	body.walk_phase+=body.position.distance_to(previous)*0.7
	if absf(motion.x)>0.1: body.facing=1 if motion.x>=0 else -1
func hurt(source: Node,victim: Node,amount: float,kind: String) -> bool:
	if not same_place(source,victim) or amount<=0: return false
	return session.combat.apply_npc_damage(source,victim.resident_id,amount,{"kind":kind,"element":"wood","goblin":true})
func resolve_attack(unit: Node,skill: String,aim: Vector2,direction: Vector2,target_id: String) -> void:
	if skill=="thorn":
		launch(unit.position,direction,unit.room_id,unit.enemy_id,Rules.damage(unit.level,skill),140.0,240.0,"goblin"); return
	for victim: Node in characters():
		if not same_place(unit,victim): continue
		if skill!="sweep" and actor_key(victim)!=target_id: continue
		var gap: float=unit.position.distance_to(victim.position)
		if gap>float(Rules.SKILLS[skill].range) or direction.dot(unit.position.direction_to(victim.position))<0.5 or not line_clear(unit,victim.position): continue
		if skill=="roots" and victim.position.distance_to(aim)>18: continue
		hurt(unit,victim,Rules.damage(unit.level,skill),"magic" if skill=="roots" else "melee")
		if skill=="roots":
			var id:=actor_key(victim)
			if float(root_locks.get(id,0))<=0 and session.magic.branches.player_status(victim.resident_id,"rooted",0.6): root_locks[id]=2.6
func launch(at: Vector2,direction: Vector2,room: String,source: String,damage: float,reach: float,speed: float,kind: String) -> void:
	flights.append({"id":next_flight,"at":[at.x,at.y],"direction":[direction.x,direction.y],"room":room,"source":source,"damage":damage,"left":reach,"speed":speed,"kind":kind}); next_flight+=1
func _physics_process(delta: float) -> void:
	if not running(): return
	for record: Dictionary in flights.duplicate():
		var from:=Vector2(record.at[0],record.at[1]); var direction:=Vector2(record.direction[0],record.direction[1]); var travel:=minf(float(record.left),float(record.speed)*delta); var to:=from+direction*travel
		var source: Node=actor(str(record.source)); var hit: Node; var blocked:=false
		var parent:=_parent(str(record.room))
		if is_instance_valid(parent) and parent.is_inside_tree():
			var excluded: Array[RID]=[]
			if is_instance_valid(source): excluded.append(source.get_rid())
			var query:=PhysicsRayQueryParameters2D.create(parent.to_global(from),parent.to_global(to),1|2|4|8|16,excluded)
			var impact: Dictionary=parent.get_world_2d().direct_space_state.intersect_ray(query)
			if not impact.is_empty(): hit=impact.collider; blocked=true
		else:
			var best:=2.0
			var candidates: Array=characters() if record.kind=="goblin" else units.values()
			for target: Node in candidates:
				if not alive(target) or target.room_id!=record.room or target==source: continue
				var closest:=Geometry2D.get_closest_point_to_segment(target.position,from,to)
				var fraction: float=from.distance_to(closest)/maxf(travel,0.001)
				if closest.distance_to(target.position)<=6 and fraction<best: hit=target; best=fraction
			var distance: float=travel*(best if best<=1 else 1.0)
			for i in range(1,maxi(2,ceili(distance/4))):
				if not walkable(from+direction*minf(distance,i*4.0),str(record.room)): blocked=true; hit=null; break
			blocked=blocked or is_instance_valid(hit)
		if blocked:
			if is_instance_valid(source) and alive(hit) and "room_id" in hit and hit.room_id==record.room:
				if record.kind=="goblin" and not hit.has_meta("goblin") and "resident_id" in hit: hurt(source,hit,float(record.damage),"ranged")
				elif record.kind=="npc" and hit.has_meta("goblin"): session.tribes.war.damage_target(hit,float(record.damage),source.tribe,source.enemy_id)
			_erase_flight(record); continue
		record.at=[to.x,to.y]; record.left=float(record.left)-travel
		if float(record.left)<=0: _erase_flight(record); continue
		if is_instance_valid(parent) and parent.is_inside_tree():
			var visual: Node=flight_nodes.get(int(record.id))
			if not is_instance_valid(visual): visual=Flight.new(); visual.set_meta("streaming_exempt",true); flight_nodes[int(record.id)]=visual
			if visual.get_parent()==null: parent.add_child(visual)
			visual.position=to; visual.direction=direction; visual.queue_redraw()
func _erase_flight(record: Dictionary) -> void:
	flights.erase(record)
	var visual: Node=flight_nodes.get(int(record.id))
	if is_instance_valid(visual): visual.queue_free()
	flight_nodes.erase(int(record.id))
func handles(person: Node) -> bool: return is_instance_valid(person) and handled.has(actor_key(person))
func blocks_work(person: Node) -> bool: return handles(person) and str(handled[actor_key(person)])!="protected"
func is_protected(person: Node) -> bool: return handles(person) and str(handled[actor_key(person)])=="protected"
func threat(person: Node,range_limit:=180.0) -> Node:
	var result: Node; var nearest:=range_limit
	for unit: Node in units.values():
		if same_place(person,unit) and person.position.distance_to(unit.position)<nearest and line_clear(person,unit.position): result=unit; nearest=person.position.distance_to(unit.position)
	return result
func _protected(person: Node,monster: Node) -> bool:
	for guard: Node in characters():
		if guard==person or not same_place(person,guard) or guard.position.distance_to(person.position)>120: continue
		if guard==session.world.active_resident:
			if session.magic.ensure(guard.resident_id).equipment.weapon=="": continue
		elif guard.role not in ["archer","charger"] or (guard.role=="archer" and not session.inventory.has_item(guard.resident_id,"arrow")): continue
		if guard.position.distance_to(monster.position)<=200 and line_clear(guard,monster.position): return true
	return false
func _flee(person: Node,monster: Node,delta: float) -> void:
	var away: Vector2=monster.position.direction_to(person.position)
	if away.length()<0.1: away=Vector2.DOWN
	for angle: float in [0.0,0.6,-0.6,1.2,-1.2]:
		var at: Vector2=person.position+away.rotated(angle)*96
		if walkable(at,person.room_id): session.tribes.workers.move(person,at,delta,36.0,"monster"); return
	session.tribes.workers.movement.stop(person)
func respond(delta: float) -> void:
	for id: String in handled:
		var old: Node=actor(id)
		if is_instance_valid(old): old.set_meta("monster_engaged",false)
	handled.clear()
	for id: String in session.tribes.population.members:
		var person: Node=session.tribes.population.node(id)
		if not alive(person): continue
		var monster:=threat(person,200.0 if person.role=="archer" else 160.0)
		var escort: bool=orders.has(id)
		if not is_instance_valid(monster) and not escort: continue
		handled[id]="escort"; person.set_meta("monster_engaged",true)
		if not is_instance_valid(monster): _escort(id,person,delta); continue
		if person.role in ["charger","archer","chief"]:
			handled[id]="fight"
			var reach: float=person.attack_reach()
			if person.role=="archer" and not session.inventory.has_item(person.resident_id,"arrow"):
				_flee(person,monster,delta); session.tribes.workers.job(id).status="缺少箭支，撤退等待补给"; continue
			if person.position.distance_to(monster.position)>reach or not line_clear(person,monster.position): session.tribes.workers.move(person,monster.position,delta,32.0*(1.15 if person.role=="charger" and person.npc_level==5 else 1.0),"monster")
			else:
				session.tribes.workers.movement.stop(person); person.face_toward(monster.global_position)
				if session.tribes.war.strike(id,person,monster) and person.role=="charger" and person.is_inside_tree():
					var swing:=Swing.new(); swing.weapon=session.tribes.Careers.weapon(person.role,person.npc_level); swing.direction=person.position.direction_to(monster.position); person.get_parent().add_child(swing); swing.global_position=person.global_position+Vector2(0,-8)
		elif person.role=="miner" and person.position.distance_to(monster.position)>60 and _protected(person,monster):
			handled[id]="protected"; session.tribes.workers.job(id).status="护卫掩护下开采"
		else:
			handled[id]="flee"; session.tribes.workers.job(id).status="哥布林来袭，避险等待护卫"; _flee(person,monster,delta)
func parked_strike(person: Node,target: Node,id: String) -> bool:
	if not same_place(person,target) or not target.has_meta("goblin") or not line_clear(person,target.position): return false
	var war=session.tribes.war
	if float(war.cooldowns.get(id,0))>0 or person.position.distance_to(target.position)>person.attack_reach(): return false
	var damage: float=1.0 if person.role=="chief" else session.tribes.Careers.damage(person.role,person.npc_level)
	if person.role=="archer":
		if not session.inventory.exchange(person.resident_id,{"arrow":1},{}): return false
		launch(person.position,person.position.direction_to(target.position),person.room_id,id,damage,person.attack_reach(),360.0,"npc")
	else: war.damage_target(target,damage,person.tribe,id)
	war.cooldowns[id]=1.0; return true
func order_guard(id: String,recall:=false) -> bool:
	var population=session.tribes.population
	if not population.friendly(id) or not population.members.has(id) or population.members[id].career not in ["archer","charger"] or not session.tribes.mine_marked: return false
	var before: Dictionary=session.inventory.export_data()
	orders[id]="return" if recall else "mine"; session.tribes.war.orders.erase(id)
	return session.production.commit(before,"已召回矿洞护卫。" if recall else "已派往矿洞守卫，弓箭手需要自身背包有箭。")
func _escort(id: String,person: Node,delta: float) -> void:
	var workers=session.tribes.workers
	if str(orders[id])=="return":
		if person.room_id=="mine":
			var room: Node=session.interiors.rooms.mine
			if workers.move(person,room.exit_point(),delta,32.0,"monster"): session.interiors.leave(person,session.world.objects,session.mining.DOOR+Vector2(0,10)); session._sync_view()
		else: orders.erase(id)
		return
	if person.room_id=="":
		if workers.move(person,session.mining.DOOR+Vector2(0,10),delta,32.0,"monster"): session.interiors.enter(person,session.world.home_data("mine")); session._sync_view()
	elif person.room_id=="mine":
		var at: Vector2=session.interiors.rooms.mine.exit_point()+Vector2(0,-80)
		var nearest:=INF
		for other_id: String in session.tribes.population.members:
			var other: Node=session.tribes.population.node(other_id)
			if alive(other) and other.room_id=="mine" and other.role=="miner" and person.position.distance_to(other.position)<nearest: at=other.position+Vector2(24,12); nearest=person.position.distance_to(other.position)
		workers.move(person,at,delta,32.0,"monster")
func export_state() -> Dictionary:
	for id: String in units: _sync(id)
	return {"version":1,"seed":seed,"online":online,"slots":slots.duplicate(true),"orders":orders.duplicate(),"root_locks":root_locks.duplicate(),"flights":flights.duplicate(true),"next_flight":next_flight}
func restore(data: Dictionary) -> void:
	for id: String in units.keys(): _drop(id)
	for visual: Node in flight_nodes.values():
		if is_instance_valid(visual): visual.queue_free()
	flight_nodes.clear(); handled.clear(); online=maxf(0,float(data.get("online",0))); seed=int(data.get("seed",session.world.resource_seed))
	_make_slots()
	for id: String in data.get("slots",{}):
		if slots.has(id): slots[id].merge(data.slots[id],true)
	orders=data.get("orders",{}).duplicate(); root_locks=data.get("root_locks",{}).duplicate(); flights=data.get("flights",[]).duplicate(true); next_flight=int(data.get("next_flight",0))
	for id: String in slots:
		if slots[id].spawned and not slots[id].dead: _ensure(id)
	focus_left=0
func _exit_tree() -> void:
	for unit: Node in units.values():
		if is_instance_valid(unit) and unit.get_parent()==null: unit.free()
	for visual: Node in flight_nodes.values():
		if is_instance_valid(visual) and visual.get_parent()==null: visual.free()
