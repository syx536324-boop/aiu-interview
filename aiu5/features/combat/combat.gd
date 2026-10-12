# Owns equipped melee/bow attacks, atomic ammunition, cooldowns and persistent tribal enemies.
extends Node
signal message(text: String)
const Enemy := preload("res://features/combat/enemy.gd")
const Arrow := preload("res://features/combat/arrow.gd")
const Gear := preload("res://features/combat/weapon_catalog.gd")
const Swing := preload("res://features/combat/swing.gd")
const SPAWNS := {"tribe:1":Vector2(1200,950),"tribe:2":Vector2(1550,1100),"tribe:3":Vector2(1750,900)}
var session: Node
var enemies: Dictionary = {}
var cooldown := 0.0
var demolition_cooldown := 0.0
func start(controller: Node) -> void:
	session = controller
	for id: String in SPAWNS:
		var enemy := Enemy.new()
		enemy.combat = self
		enemy.enemy_id = id
		enemy.position = SPAWNS[id]
		session.world.objects.add_child(enemy)
		enemies[id] = enemy
func _process(delta: float) -> void:
	cooldown = maxf(0,cooldown-delta)
	demolition_cooldown = maxf(0,demolition_cooldown-delta)
func ready_for_action() -> bool:
	return session.production.allowed(session.world.active_resident) and not session.roster_open and not session.inventory.opened and not session.editor.opened and not session.awakening_open and session.attributes_id=="" and not session.production.opened
func fire(target: Vector2) -> bool:
	if cooldown > 0 or not ready_for_action(): return false
	var actor: CharacterBody2D = session.world.active_resident
	var roof: bool = session.world.home_data(actor.room_id).get("tower",false)
	if actor.room_id != "" and not roof: return false
	var weapon: String = session.magic.ensure(actor.resident_id).equipment.weapon
	if weapon not in Gear.WEAPONS:
		message.emit("请先装备镐子、斧、剑或弓。")
		return false
	if not session.magic.weapon_usable(actor.resident_id): return false
	var canvas := actor.get_canvas_transform()
	var screen := canvas * target
	if not Rect2(Vector2.ZERO,Vector2(640,400)).has_point(screen): return false
	var origin := actor.global_position+Vector2(0,-10)
	if origin.distance_to(target)<2: return false
	if weapon != "bow": return _melee(target,weapon)
	var before: Dictionary = session.inventory.export_data()
	if not session.inventory.exchange(actor.resident_id,{"arrow":1},{}):
		message.emit("背包中没有箭。工作台：木头2＋粗铁1制作10支。")
		return false
	session.magic.consume_weapon(actor.resident_id)
	if not session.production.commit(before,"发射箭×1。"):
		return false
	var arrow := Arrow.new()
	arrow.damage = Gear.damage(weapon)+session.magic.skills.attack_bonus(actor.resident_id)
	arrow.combat = self
	arrow.actor_id = actor.resident_id
	arrow.direction = origin.direction_to(target)
	arrow.distance_left = minf(200,origin.distance_to(target)+12)
	if roof:
		for body in session.interiors.rooms[actor.room_id].find_children("*","StaticBody2D",true,false): arrow.excluded.append(body.get_rid())
		for body in session.construction.nodes[actor.room_id].find_children("*","StaticBody2D",true,false): arrow.excluded.append(body.get_rid())
	session.world.objects.add_child(arrow)
	arrow.global_position = origin
	cooldown = 0.6
	return true
func _melee(target: Vector2, weapon: String) -> bool:
	var actor: CharacterBody2D = session.world.active_resident
	var before: Dictionary = session.inventory.export_data()
	var direction := actor.global_position.direction_to(target)
	var candidate: CharacterBody2D
	var nearest := 29.0
	for enemy: CharacterBody2D in enemies.values()+session.livestock.animals:
		if enemy.hp <= 0 or enemy.get_parent() == null: continue
		var gap := actor.global_position.distance_to(enemy.global_position)
		if gap < nearest and direction.dot(actor.global_position.direction_to(enemy.global_position)) >= 0.3:
			candidate = enemy
			nearest = gap
	if is_instance_valid(candidate):
		var query := PhysicsRayQueryParameters2D.create(actor.global_position,candidate.global_position,1|8|4)
		var hit: Dictionary = actor.get_world_2d().direct_space_state.intersect_ray(query)
		if hit.get("collider") == candidate:
			if candidate.is_in_group("creature_targets"):
				var outcome: Dictionary = session.livestock.damage_animal(candidate,Gear.damage(weapon)+session.magic.skills.attack_bonus(actor.resident_id),actor.resident_id)
				if not outcome.ok: return false
				if outcome.killed:
					session.magic.credit_points(actor.resident_id,25)
					outcome.text += " 获得25魔法点。"
				session.magic.consume_weapon(actor.resident_id)
				if not session.production.commit(before,outcome.text): return false
				_spawn_swing(actor,direction)
				return true
			candidate.hp = maxf(0,float(candidate.hp)-Gear.damage(weapon)-session.magic.skills.attack_bonus(actor.resident_id)-session.magic.skills.drain_on_hit(candidate,actor.resident_id))
			if candidate.hp<=0: session.magic.credit_points(actor.resident_id,25)
			candidate.pursuit = 6.0
			candidate.refresh()
	session.magic.consume_weapon(actor.resident_id)
	if not session.production.commit(before,"挥动武器。" if not is_instance_valid(candidate) else "近战攻击，敌人生命%.0f。" % candidate.hp): return false
	_spawn_swing(actor,direction)
	return true
func _spawn_swing(actor: CharacterBody2D, direction: Vector2) -> void:
	var swing := Swing.new()
	swing.direction = direction
	session.world.objects.add_child(swing)
	swing.global_position = actor.global_position+Vector2(0,-8)
	cooldown = 0.6
func hit_animal(animal: CharacterBody2D, raw: float, actor_id := "") -> bool:
	var attacker: String = session.world.active_resident.resident_id if actor_id=="" else actor_id
	if not is_instance_valid(session.magic._actor(attacker)): return false
	var before: Dictionary = session.inventory.export_data()
	var result: Dictionary = session.livestock.damage_animal(animal,raw,attacker)
	if not result.ok: return false
	if result.killed:
		session.magic.credit_points(attacker,25)
		result.text += " 获得25魔法点。"
	return session.production.commit(before,result.text)
func hit_cow(animal: CharacterBody2D, raw: float, actor_id := "") -> bool:
	return hit_animal(animal,raw,actor_id)
func hit_enemy(enemy: CharacterBody2D, raw: float, actor_id := "") -> bool:
	if not is_instance_valid(enemy) or enemy.hp<=0 or raw<=0: return false
	var attacker: String = session.world.active_resident.resident_id if actor_id=="" else actor_id
	if not is_instance_valid(session.magic._actor(attacker)): return false
	var before: Dictionary = session.inventory.export_data()
	enemy.hp = maxf(0,float(enemy.hp)-raw-session.magic.skills.drain_on_hit(enemy,attacker))
	enemy.pursuit = 6.0
	enemy.refresh()
	if enemy.hp<=0: session.magic.credit_points(attacker,25)
	return session.production.commit(before,"击败敌人，获得25魔法点。" if enemy.hp<=0 else "命中敌人，剩余生命%.0f。" % enemy.hp)

func apply_skill_damage(target: CharacterBody2D, raw: float, actor_id: String) -> bool:
	# Timed attacks advance with the saved online clock; normal autosaves capture their state.
	if not is_instance_valid(target) or target.hp<=0 or not is_instance_valid(session.magic._actor(actor_id)): return false
	if target.is_in_group("creature_targets"):
		var result: Dictionary=session.livestock.damage_animal(target,raw,actor_id)
		if not result.ok: return false
		if result.killed: session.magic.credit_points(actor_id,25)
	else:
		target.hp=maxf(0,target.hp-raw)
		target.pursuit=6.0
		target.refresh()
		if target.hp<=0: session.magic.credit_points(actor_id,25)
	return true
func demolish() -> void:
	if demolition_cooldown > 0 or not ready_for_action(): return
	if session.construction.demolish(session.world.active_resident): demolition_cooldown=0.6
func export_state() -> Dictionary:
	var data: Dictionary = {}
	for id: String in enemies:
		var e: CharacterBody2D = enemies[id]
		data[id] = {"hp":e.hp,"thirst":e.thirst,"at":[e.position.x,e.position.y],"cooldown":e.cooldown,"pursuit":e.pursuit}
	return data
func restore(data: Dictionary) -> void:
	for id: String in enemies:
		var e: CharacterBody2D = enemies[id]
		var saved: Dictionary = data.get(id,{})
		e.hp = clampf(float(saved.get("hp",30)),0,30)
		e.thirst = clampf(float(saved.get("thirst",10)),0,10)
		var at: Array = saved.get("at",[SPAWNS[id].x,SPAWNS[id].y])
		e.position = Vector2(at[0],at[1])
		e.cooldown = clampf(float(saved.get("cooldown",0)),0,2)
		e.pursuit = clampf(float(saved.get("pursuit",0)),0,6)
		e.refresh()
	for arrow in get_tree().get_nodes_in_group("arrows"): arrow.queue_free()
	cooldown=0
	demolition_cooldown=0
