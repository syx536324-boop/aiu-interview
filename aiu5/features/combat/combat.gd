# Owns equipped melee/bow attacks, atomic ammunition, cooldowns and persistent tribal enemies.
extends Node
signal message(text: String)
const Enemy := preload("res://features/combat/enemy.gd")
const Arrow := preload("res://features/combat/arrow.gd")
const Gear := preload("res://features/combat/weapon_catalog.gd")
const Swing := preload("res://features/combat/swing.gd")
const SPAWNS := {"tribe:1":Vector2(1200,950),"tribe:2":Vector2(1550,1100),"tribe:3":Vector2(1750,900)}
# Two tribes of twenty: twelve civilians, four archers and four chargers each. Their territories
# keep them from raiding the player's village on their own.
const TRIBES := {
	"forest": {"area": Rect2(-1400, 640, 400, 340), "hp": 20.0},
	"barbarian": {"area": Rect2(200, -1500, 2000, 1300), "hp": 20.0},
	"yunye": {"area": Rect2(2850, -1050, 900, 700), "hp": 20.0}
}
const TRIBE_ROLES := {"civilian": 12, "archer": 4, "charger": 4}
const CHIEF_ELEMENT := {"forest": "wood", "barbarian": "fire", "yunye": "earth"}
const Layout := preload("res://features/village/layout.gd")
var session: Node
var enemies: Dictionary = {}
var initial_states: Dictionary = {}
var cooldown := 0.0
var demolition_cooldown := 0.0
func reach(weapon: String) -> float:
	# Haze on the highlands shortens ranged reach; melee distance is unaffected.
	return Gear.attack_range(weapon) * session.world.haze.range_scale()
func start(controller: Node) -> void:
	session = controller
	for id: String in SPAWNS:
		var enemy := Enemy.new()
		enemy.combat = self
		enemy.enemy_id = id
		enemy.position = SPAWNS[id]
		session.world.objects.add_child(enemy)
		enemies[id] = enemy
	for name: String in TRIBES: _spawn_tribe(name, TRIBES[name].area, TRIBES[name].hp)
	_spawn_chief("forest", Layout.FOREST_ALTAR + Vector2(36, -24))
	_spawn_chief("barbarian", Vector2(1200, -760))
	_spawn_chief("yunye", Vector2(3300, -820))
	_configure_chief("forest_chief", CHIEF_ELEMENT["forest"])
	for id: String in enemies:
		var enemy: CharacterBody2D = enemies[id]
		initial_states[id] = {"hp":enemy.hp,"at":[enemy.position.x,enemy.position.y]}

func _spawn_tribe(name: String, area: Rect2, hp_value: float) -> void:
	# Twelve civilians, four archers and four chargers, spread deterministically over the territory.
	var index := 0
	for npc_role: String in TRIBE_ROLES:
		for i in range(int(TRIBE_ROLES[npc_role])):
			var member := Enemy.new()
			member.combat = self
			member.enemy_id = "%s:%d" % [name, index]
			member.configure_tribe(name, npc_role, area, hp_value)
			member.position = area.position + Vector2(float(index % 5) + 0.5, float(index / 5) + 0.5) * Vector2(area.size.x / 5.0, area.size.y / 4.0)
			session.world.objects.add_child(member)
			enemies[member.enemy_id] = member
			index += 1

func _spawn_chief(name: String, at: Vector2) -> void:
	var chief := Enemy.new()
	chief.combat = self
	chief.enemy_id = name + ":chief"
	chief.configure_tribe(name, "chief", TRIBES[name].area, 30.0)
	chief.chief_id = name + "_chief"
	chief.position = at
	session.world.objects.add_child(chief)
	enemies[chief.enemy_id] = chief
	_configure_chief(chief.chief_id, CHIEF_ELEMENT[name])
	chief.mana = session.magic.max_mana(chief.chief_id)

func _configure_chief(id: String, element: String) -> void:
	# Chiefs follow the same rules as the player: level nine, the first four trunk skills and capped mana.
	var state: Dictionary = session.magic.ensure(id)
	state.element = element
	state.level = 9
	state.xp = 0
	state.pending_points = 0
	state.skill_points = 0
	state.unlocked = ["trunk_1", "trunk_2", "trunk_3", "trunk_4"]

func tribe_members(name: String) -> Array:
	var result: Array = []
	for id: String in enemies:
		var member: CharacterBody2D = enemies[id]
		if member.tribe == name and member.role != "chief": result.append(member)
	return result
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
	arrow.distance_left = minf(reach(weapon),origin.distance_to(target)+12)
	if roof:
		for body in session.interiors.rooms[actor.room_id].find_children("*","StaticBody2D",true,false): arrow.excluded.append(body.get_rid())
		for body in session.construction.nodes[actor.room_id].find_children("*","StaticBody2D",true,false): arrow.excluded.append(body.get_rid())
	session.world.objects.add_child(arrow)
	arrow.global_position = origin
	cooldown = Gear.interval(weapon)
	return true
func attack_clicked(at: Vector2) -> bool:
	if cooldown>0 or not ready_for_action() or (is_instance_valid(session.gifts) and session.gifts.opened): return false
	var actor: CharacterBody2D = session.world.active_resident
	var weapon: String = session.magic.ensure(actor.resident_id).equipment.weapon
	if weapon not in Gear.WEAPONS or not session.magic.weapon_usable(actor.resident_id): return false
	if actor.room_id!="" and not session.world.home_data(actor.room_id).get("tower",false): return false
	var clicked: CharacterBody2D
	# Hit-test the visible body sprite, rather than selecting a different enemy near the pointer.
	for enemy: CharacterBody2D in enemies.values():
		if enemy.hp>0 and enemy.get_parent()!=null and Rect2(enemy.global_position+Vector2(-8,-16),Vector2(16,20)).has_point(at):
			clicked=enemy
			break
	if not is_instance_valid(clicked): return false
	if actor.global_position.distance_to(clicked.global_position)>reach(weapon):
		message.emit("目标超出武器攻击范围。")
		return false
	if not Rect2(Vector2.ZERO,Vector2(640,400)).has_point(actor.get_canvas_transform()*clicked.global_position): return false
	var query := PhysicsRayQueryParameters2D.create(actor.global_position,clicked.global_position,1|8|4,[actor.get_rid()])
	if actor.get_world_2d().direct_space_state.intersect_ray(query).get("collider")!=clicked: return false
	if weapon=="bow": return fire(clicked.global_position)
	return _melee(clicked.global_position,weapon,clicked)

func _melee(target: Vector2, weapon: String, clicked: CharacterBody2D = null) -> bool:
	var actor: CharacterBody2D = session.world.active_resident
	var before: Dictionary = session.inventory.export_data()
	var direction := actor.global_position.direction_to(target)
	var candidate: CharacterBody2D
	var nearest := reach(weapon)+0.0001
	for enemy: CharacterBody2D in enemies.values()+session.livestock.animals:
		if enemy.hp <= 0 or enemy.get_parent() == null: continue
		var gap := actor.global_position.distance_to(enemy.global_position)
		if (not is_instance_valid(clicked) or enemy==clicked) and gap < nearest and direction.dot(actor.global_position.direction_to(enemy.global_position)) >= 0.3:
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
				_spawn_swing(actor,direction,weapon)
				return true
			candidate.hp = maxf(0,float(candidate.hp)-Gear.damage(weapon)-session.magic.skills.attack_bonus(actor.resident_id)-session.magic.skills.drain_on_hit(candidate,actor.resident_id))
			if candidate.hp<=0: session.magic.credit_points(actor.resident_id,25)
			candidate.pursuit = 6.0
			candidate.refresh()
	session.magic.consume_weapon(actor.resident_id)
	if not session.production.commit(before,"挥动武器。" if not is_instance_valid(candidate) else "近战攻击，敌人生命%.0f。" % candidate.hp): return false
	_spawn_swing(actor,direction,weapon)
	return true
func _spawn_swing(actor: CharacterBody2D, direction: Vector2, weapon: String) -> void:
	var swing := Swing.new()
	swing.direction = direction
	session.world.objects.add_child(swing)
	swing.global_position = actor.global_position+Vector2(0,-8)
	cooldown = Gear.interval(weapon)
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
		var record: Variant = data.get(id,{})
		var saved: Dictionary = record if record is Dictionary else {}
		var initial: Dictionary = initial_states[id]
		e.hp = clampf(float(saved.get("hp",initial.hp)),0,float(initial.hp))
		e.thirst = clampf(float(saved.get("thirst",10)),0,10)
		var at: Variant = saved.get("at",initial.at)
		if not at is Array or at.size()!=2 or not (at[0] is int or at[0] is float) or not (at[1] is int or at[1] is float): at=initial.at
		if not is_finite(float(at[0])) or not is_finite(float(at[1])): at=initial.at
		e.position = Vector2(float(at[0]),float(at[1]))
		e.cooldown = clampf(float(saved.get("cooldown",0)),0,2)
		e.pursuit = clampf(float(saved.get("pursuit",0)),0,6)
		e.refresh()
	for arrow in get_tree().get_nodes_in_group("arrows"): arrow.queue_free()
	cooldown=0
	demolition_cooldown=0
