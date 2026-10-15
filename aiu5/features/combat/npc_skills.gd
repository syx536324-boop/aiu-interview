# Drives NPC profession skills and chief elemental spells through the frozen skill interface.
# All cooldowns, preparation windows, ammunition and chief mana clocks live here; effects reuse
# the existing magic branch/skill registries instead of re-deriving their formulas.
extends Node
const Rules := preload("res://features/magic/skill_catalog.gd")
const Careers := preload("res://features/tribes/profession_catalog.gd")
# Chief mana recovers one point per online minute, matching survival MANA_INTERVAL.
const MANA_INTERVAL := 60.0
const COMMON_GAP := 1.0
const Arrow := preload("res://features/tribes/projectile.gd")
const DASH_DISTANCE := 40.0
const DASH_SPEED := 420.0
const BONUS_WINDOW := 6.0
# 木系村长回春：每3在线秒回1生命，持续30在线秒（与玩家主干四级命名同源）。
const HEAL_TICK := 3.0
const HEAL_DURATION := 30.0
# cooldown is the skill body limit; chief classes are 12s control/attack and 20s recovery/defense.
const SKILLS := {
	"dash_slash": {"role":"charger","rank":3,"prepare":0.6,"cooldown":8.0,"kind":"attack"},
	"parry": {"role":"charger","rank":3,"prepare":0.6,"cooldown":12.0,"kind":"defense"},
	"suppress_shot": {"role":"archer","rank":3,"prepare":0.8,"cooldown":10.0,"kind":"attack"},
	"chief_wood_vine": {"role":"chief","rank":5,"element":"wood","prepare":0.8,"cooldown":12.0,"kind":"control"},
	"chief_wood_heal": {"role":"chief","rank":4,"element":"wood","prepare":0.8,"cooldown":20.0,"kind":"recovery"},
	"chief_water_bubble": {"role":"chief","rank":5,"element":"water","prepare":0.8,"cooldown":12.0,"kind":"control"},
	"chief_water_shield": {"role":"chief","rank":4,"element":"water","prepare":0.8,"cooldown":20.0,"kind":"defense"},
	"chief_fire_ball": {"role":"chief","rank":5,"element":"fire","prepare":0.8,"cooldown":12.0,"kind":"attack"},
	"chief_fire_burn": {"role":"chief","rank":4,"element":"fire","prepare":0.8,"cooldown":12.0,"kind":"attack"},
	"chief_earth_blink": {"role":"chief","rank":5,"element":"earth","prepare":0.8,"cooldown":12.0,"kind":"mobility"},
	"chief_earth_hut": {"role":"chief","rank":4,"element":"earth","prepare":0.8,"cooldown":20.0,"kind":"defense"},
}
const ROLE_SKILLS := {
	"charger": ["dash_slash","parry"],
	"archer": ["suppress_shot"],
	"chief": ["chief_wood_vine","chief_wood_heal","chief_water_bubble","chief_water_shield","chief_fire_ball","chief_fire_burn","chief_earth_blink","chief_earth_hut"],
}
var runtime: Node
var guards: Node
var session: Node
var states: Dictionary = {}
var prepare_marks: Dictionary = {}

func start(owner: Node, guards_node: Node) -> void:
	runtime = owner
	guards = guards_node
	# The owner is tribes; it exposes the shared session used by every domain.
	session = owner.session
	for key: String in session.combat.enemies:
		var enemy: Node = session.combat.enemies[key]
		if not is_instance_valid(enemy) or str(enemy.role) != "chief": continue
		_state(str(enemy.enemy_id))
		# 村长魔力以 vitals 池为准，并把战斗模块已有的 enemy.mana 镜像到同一数值。
		var actor_id := _magic_id(enemy)
		var stats: Dictionary = session.vitals.ensure(actor_id)
		var limit := float(session.magic.max_mana(actor_id))
		stats.mana = clampf(float(enemy.mana),0.0,limit)
		enemy.mana = int(stats.mana)

func advance(delta: float) -> void:
	var left := maxf(0.0,delta)
	while left > 0.00001:
		var step := minf(left,0.5)
		left -= step
		_step(step)

func _step(delta: float) -> void:
	for enemy_id: String in states.keys():
		var state: Dictionary = states[enemy_id]
		var enemy: Node = session.combat.enemies.get(enemy_id)
		if not is_instance_valid(enemy) or float(enemy.hp) <= 0.0:
			if str(state.prepare.skill) != "": _cancel(enemy_id,enemy,state)
			state.dash.active = false
			continue
		var cooldowns: Dictionary = state.cd
		for skill: String in cooldowns.keys():
			cooldowns[skill] = maxf(0.0,float(cooldowns[skill]) - delta)
			if float(cooldowns[skill]) <= 0.0: cooldowns.erase(skill)
		state.gap = maxf(0.0,float(state.gap) - delta)
		if float(state.bonus_left) > 0.0:
			state.bonus_left = maxf(0.0,float(state.bonus_left) - delta)
			if float(state.bonus_left) <= 0.0: state.dash_bonus = 0.0
		if str(state.prepare.skill) != "" and (session.magic.skills.rooted(enemy_id) or session.magic.branches.immobile(enemy_id) or bool(enemy.friendly)!=bool(state.prepare.get("friendly",enemy.friendly))):
			_cancel(enemy_id,enemy,state)
		if float(state.prepare.left) > 0.0:
			state.prepare.left = maxf(0.0,float(state.prepare.left) - delta)
			_update_mark(enemy_id,state)
			if float(state.prepare.left) <= 0.0: _finish(enemy_id,enemy,state)
		if bool(state.dash.active): _dash_step(enemy,state,delta)
		_recover_mana(enemy,state,delta)

# --- 冻结接口 ---

func cooldown_left(enemy_id: String, skill: String) -> float:
	var enemy: Node = _enemy_of(enemy_id)
	var key := str(enemy.enemy_id) if is_instance_valid(enemy) else enemy_id
	var state: Dictionary = states.get(key,{})
	if state.is_empty(): return 0.0
	return maxf(float(state.cd.get(skill,0.0)),float(state.gap))

func can_use(enemy: Node, skill: String) -> bool:
	var rule: Dictionary = _rule(skill)
	if rule.is_empty() or not is_instance_valid(enemy): return false
	if float(enemy.hp) <= 0.0: return false
	if str(enemy.role) != str(rule.role): return false
	if not _level_ok(enemy,rule): return false
	var state: Dictionary = _state(str(enemy.enemy_id))
	if str(state.prepare.skill) != "" or float(state.gap) > 0.0: return false
	if float(state.cd.get(skill,0.0)) > 0.0: return false
	if rule.has("element") and str(session.magic.ensure(_magic_id(enemy)).element) != str(rule.element): return false
	if rule.role == "chief" and float(_chief_mana(enemy)) < float(Rules.COSTS[int(rule.rank) - 1]): return false
	if skill == "suppress_shot" and not session.inventory.has_item("npc:"+str(enemy.enemy_id),"arrow"): return false
	return _valid_target(enemy,skill,rule)

# 起手准备：至少 0.6 秒可见动作，资源与冷却在起手时结算；效果在窗口结束后落地，
# 玩家可在这段时间内离开范围或借遮挡打断，从而躲开效果。
func use(enemy: Node, skill: String) -> bool:
	if not can_use(enemy,skill): return false
	var rule: Dictionary = _rule(skill)
	var state: Dictionary = _state(str(enemy.enemy_id))
	if not _spend(enemy,skill,rule): return false
	state.cd[skill] = float(rule.cooldown)
	state.gap = COMMON_GAP
	var intended: Node=_hostile(enemy,240.0)
	state.prepare = {"skill":skill,"left":float(rule.prepare),"total":float(rule.prepare),"target":runtime.encounters.key(intended),"friendly":bool(enemy.friendly)}
	_show_prepare(str(enemy.enemy_id),enemy,state)
	if enemy.has_method("begin_prepare"): enemy.begin_prepare(skill,float(rule.prepare))
	return true

func damage_modifier(enemy_id: String) -> float:
	var enemy: Node = _enemy_of(enemy_id)
	return session.magic.damage_rate(_magic_id(enemy)) if is_instance_valid(enemy) else 1.0

func attack_bonus(enemy_id: String) -> float:
	var enemy: Node = _enemy_of(enemy_id)
	var key := str(enemy.enemy_id) if is_instance_valid(enemy) else enemy_id
	var state: Dictionary = states.get(key,{})
	if state.is_empty(): return 0.0
	return float(state.dash_bonus)

func consume_attack_bonus(enemy_id: String) -> float:
	var enemy: Node = _enemy_of(enemy_id)
	var key := str(enemy.enemy_id) if is_instance_valid(enemy) else enemy_id
	var state: Dictionary = _state(key)
	var bonus := float(state.dash_bonus)
	state.dash_bonus = 0.0
	state.bonus_left = 0.0
	# 木藤的汲取挂在同一次命中钩子：只治疗施法者本体的 enemy.hp。
	if is_instance_valid(enemy):
		var target: Node = _hostile(enemy,240.0)
		if is_instance_valid(target):
			bonus+=session.magic.skills.drain_on_hit(target,_magic_id(enemy)) if "enemy_id" in target else session.magic.skills.consume_hostile_drain(target,_magic_id(enemy))
	return bonus

func options_for(enemy: Node) -> Array:
	if not is_instance_valid(enemy): return []
	return ROLE_SKILLS.get(str(enemy.role),[]).duplicate()

func pick(enemy: Node) -> String:
	for skill: String in options_for(enemy):
		if can_use(enemy,skill): return skill
	return ""

func export_state() -> Dictionary:
	var records := {}
	var mana := {}
	for enemy_id: String in states:
		var state: Dictionary = states[enemy_id]
		records[enemy_id] = {"cd":state.cd.duplicate(true),"gap":float(state.gap),"mana_clock":float(state.mana_clock),
			"heal_left":float(state.heal_left),"heal_tick":float(state.heal_tick)}
		var enemy: Node = session.combat.enemies.get(enemy_id)
		if is_instance_valid(enemy) and str(enemy.role) == "chief": mana[_magic_id(enemy)] = float(_chief_mana(enemy))
	return {"cooldowns":records,"mana":mana}

func restore(data: Dictionary) -> void:
	for arrow: Node in session.get_tree().get_nodes_in_group("tribal_arrows"):
		arrow.queue_free()
	for enemy_id: String in prepare_marks.keys():
		var mark: Variant = prepare_marks[enemy_id]
		if is_instance_valid(mark): mark.queue_free()
	prepare_marks.clear()
	states.clear()
	for enemy_id: String in data.get("cooldowns",{}):
		var record: Variant = data.cooldowns[enemy_id]
		if not record is Dictionary: continue
		var state: Dictionary = _state(enemy_id)
		for skill: String in record.get("cd",{}):
			var rule: Dictionary = _rule(skill)
			if rule.is_empty(): continue
			var value := clampf(float(record.cd[skill]),0.0,float(rule.cooldown))
			if value > 0.0: state.cd[skill] = value
		state.gap = clampf(float(record.get("gap",0.0)),0.0,COMMON_GAP)
		state.mana_clock = clampf(float(record.get("mana_clock",0.0)),0.0,MANA_INTERVAL)
		state.heal_left = clampf(float(record.get("heal_left",0.0)),0.0,HEAL_DURATION)
		state.heal_tick = clampf(float(record.get("heal_tick",0.0)),0.0,HEAL_TICK)
		var healer: Node=_enemy_of(enemy_id)
		if is_instance_valid(healer) and state.heal_left>0 and not session.magic.skills.buffs.has(_magic_id(healer)):
			session.magic.skills.buffs[_magic_id(healer)]={"regen":state.heal_left,"regen_tick":HEAL_TICK-state.heal_tick}
		state.heal_left=0.0; state.heal_tick=0.0
	for enemy_id: String in data.get("mana",{}):
		var enemy: Node = session.combat.enemies.get(enemy_id)
		if not is_instance_valid(enemy) or str(enemy.role) != "chief": continue
		var actor_id := _magic_id(enemy)
		var limit := float(session.magic.max_mana(actor_id))
		var value := clampf(float(data.mana[enemy_id]),0.0,limit)
		session.vitals.ensure(actor_id).mana = value
		enemy.mana = int(value)

# --- 内部实现 ---

func _state(enemy_id: String) -> Dictionary:
	if not states.has(enemy_id):
		states[enemy_id] = {"cd":{},"gap":0.0,"prepare":{"skill":"","left":0.0,"total":0.0},
			"dash_bonus":0.0,"bonus_left":0.0,"mana_clock":0.0,
			"heal_left":0.0,"heal_tick":0.0,
			"dash":{"active":false,"target":Vector2.ZERO,"start":Vector2.ZERO,"left":0.0}}
	return states[enemy_id]

func _rule(skill: String) -> Dictionary:
	return SKILLS.get(skill,{})

func _magic_id(enemy: Node) -> String:
	if str(enemy.role) == "chief" and str(enemy.chief_id) != "": return str(enemy.chief_id)
	return str(enemy.enemy_id)

func _enemy_of(id: String) -> Node:
	var enemy: Node = session.combat.enemies.get(id)
	if is_instance_valid(enemy): return enemy
	for key: String in session.combat.enemies:
		var other: Node = session.combat.enemies[key]
		if is_instance_valid(other) and _magic_id(other) == id: return other
	return null

func _chief_mana(enemy: Node) -> float:
	return float(session.vitals.ensure(_magic_id(enemy)).mana)

func _level_ok(enemy: Node, rule: Dictionary) -> bool:
	if str(rule.role) == "chief": return str(enemy.chief_id) != ""
	return int(enemy.npc_level) >= int(rule.rank)

func _valid_target(enemy: Node, skill: String, rule: Dictionary) -> bool:
	match skill:
		"suppress_shot":
			return is_instance_valid(_hostile(enemy,enemy.attack_reach()))
		"chief_wood_heal":
			return float(enemy.hp) < float(enemy.max_hp)
		"chief_earth_hut":
			var holy: Node=runtime.relics.visuals.get(enemy.tribe)
			var guarding: bool=is_instance_valid(holy) and enemy.global_position.distance_to(holy.global_position)<=90
			return (enemy.hp<enemy.max_hp*0.7 or guarding) and not session.magic.skills.huts.has(_magic_id(enemy))
		"chief_earth_blink":
			var target: Node=_hostile(enemy,200.0)
			return is_instance_valid(target) and (enemy.hp<enemy.max_hp*0.3 or _surrounded(enemy)) and _escape_point(enemy,target).is_finite()
		"chief_wood_vine","chief_water_bubble","chief_fire_burn":
			return is_instance_valid(_hostile(enemy,200.0))
		"chief_fire_ball":
			var target: Node = _hostile(enemy,200.0)
			return is_instance_valid(target) and enemy.global_position.distance_to(target.global_position) >= 4.0
	return true

func _hostile(enemy: Node, radius: float) -> Node:
	if not is_instance_valid(enemy): return null
	var intent: String=str(enemy.get_meta("npc_cast_target",_state(enemy.enemy_id).prepare.get("target","")))
	if intent=="": intent=str(guards.npc(enemy.enemy_id).get("target_id","")) if is_instance_valid(guards) else ""
	if intent!="" and not intent.begins_with("home:"):
		var intended: Node=session.world.active_resident if intent=="player" else runtime.encounters.actor(intent)
		if is_instance_valid(intended) and enemy.global_position.distance_to(intended.global_position)<=radius and _can_see(enemy,intended): return intended
		return null
	if bool(enemy.friendly):
		var best: Node
		var best_gap := radius
		for other: Node in session.combat.target_enemies():
			if not is_instance_valid(other) or float(other.hp) <= 0.0: continue
			var gap: float = enemy.global_position.distance_to(other.global_position)
			if gap < best_gap and _can_see(enemy,other): best=other; best_gap=gap
		return best
	var best_player: Node
	var player_gap := radius
	for resident: Node in session.world.controllable:
		if not is_instance_valid(resident) or resident.dead: continue
		var gap: float = enemy.global_position.distance_to(resident.global_position)
		if gap < player_gap and _can_see(enemy,resident): best_player=resident; player_gap=gap
	return best_player

func _can_see(actor: Node, target: Node) -> bool:
	if not is_instance_valid(actor) or not is_instance_valid(target): return false
	if not actor.is_inside_tree() or not target.is_inside_tree(): return false
	if "room_id" in actor and "room_id" in target and actor.room_id!=target.room_id: return false
	var query := PhysicsRayQueryParameters2D.create(actor.global_position,target.global_position,1|4,[actor.get_rid()])
	return actor.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _direction(enemy: Node, target: Node) -> Vector2:
	if is_instance_valid(target):
		var heading: Vector2 = enemy.global_position.direction_to(target.global_position)
		if heading != Vector2.ZERO: return heading
	return Vector2.LEFT if int(enemy.facing)<0 else Vector2.RIGHT

# 起手即结算资源：缺魔力/箭支时 can_use 已拦下，因此这里失败绝不会误扣玩家资源。
func _spend(enemy: Node, skill: String, rule: Dictionary) -> bool:
	if str(rule.role) == "chief":
		var stats: Dictionary = session.vitals.ensure(_magic_id(enemy))
		var cost := float(Rules.COSTS[int(rule.rank) - 1])
		if float(stats.mana) < cost: return false
		stats.mana = float(stats.mana) - cost
		enemy.mana = int(clampf(float(stats.mana),0.0,float(session.magic.max_mana(_magic_id(enemy)))))
		return true
	if skill == "suppress_shot":
		return session.inventory.exchange("npc:"+str(enemy.enemy_id),{"arrow":1},{})
	return true

func _show_prepare(enemy_id: String, enemy: Node, state: Dictionary) -> void:
	_clear_prepare(enemy_id,enemy)
	var node := Node2D.new()
	node.name = "NpcSkillPrepare"
	node.z_index = 8
	node.set_meta("progress",0.0)
	node.draw.connect(func() -> void:
		var progress := clampf(float(node.get_meta("progress",0.0)),0.05,1.0)
		node.draw_arc(Vector2.ZERO,13.0,-PI/2,-PI/2+TAU*progress,24,Color("f2d37a"),2.0)
		node.draw_circle(Vector2.ZERO,5.0,Color(0.95,0.83,0.48,0.3))
	)
	enemy.add_child(node)
	prepare_marks[enemy_id] = node
	enemy.set_meta("npc_skill_prepare",true)

func _update_mark(enemy_id: String, state: Dictionary) -> void:
	if not prepare_marks.has(enemy_id): return
	var node: Variant = prepare_marks[enemy_id]
	if not is_instance_valid(node): prepare_marks.erase(enemy_id); return
	var total := maxf(0.0001,float(state.prepare.total))
	node.set_meta("progress",1.0 - float(state.prepare.left)/total)
	node.queue_redraw()

func _clear_prepare(enemy_id: String, enemy: Node) -> void:
	if prepare_marks.has(enemy_id):
		var node: Variant = prepare_marks[enemy_id]
		if is_instance_valid(node): node.queue_free()
		prepare_marks.erase(enemy_id)
	if is_instance_valid(enemy):
		enemy.set_meta("npc_skill_prepare",false)
		enemy.queue_redraw()

func _cancel(enemy_id: String, enemy: Node, state: Dictionary) -> void:
	state.prepare = {"skill":"","left":0.0,"total":0.0}
	_clear_prepare(enemy_id,enemy)
	if is_instance_valid(enemy) and enemy.has_method("cancel_prepare"): enemy.cancel_prepare()

func _finish(enemy_id: String, enemy: Node, state: Dictionary) -> void:
	var skill := str(state.prepare.skill)
	var rule: Dictionary = _rule(skill)
	if str(rule.kind) in ["attack","control"] and not _valid_target(enemy,skill,rule):
		if skill=="suppress_shot": session.inventory.exchange("npc:"+enemy_id,{},{"arrow":1})
		_cancel(enemy_id,enemy,state)
		return
	var cast_target: String=str(state.prepare.get("target",""))
	state.prepare = {"skill":"","left":0.0,"total":0.0}
	_clear_prepare(enemy_id,enemy)
	enemy.set_meta("npc_cast_target",cast_target)
	match skill:
		"dash_slash": _dash(enemy)
		"parry": _parry(enemy)
		"suppress_shot": _suppress(enemy)
		_: _chief(enemy,skill,rule)
	enemy.remove_meta("npc_cast_target")

func _dash(enemy: Node) -> void:
	var state: Dictionary = _state(str(enemy.enemy_id))
	var target: Node = _hostile(enemy,240.0)
	var heading: Vector2 = _direction(enemy,target)
	state.dash = {"active":true,"target":enemy.global_position+heading*DASH_DISTANCE,"start":enemy.global_position,"left":0.14}
	# 冲刺斩的下一次合法近战命中获得 +2 伤害，由战斗模块经 attack_bonus 取用。
	state.dash_bonus = 2.0
	state.bonus_left = BONUS_WINDOW

func _dash_step(enemy: Node, state: Dictionary, delta: float) -> void:
	var dash: Dictionary = state.dash
	var start: Vector2 = dash.start
	var travelled: float = enemy.global_position.distance_to(start)
	if travelled >= DASH_DISTANCE or float(dash.left) <= 0.0:
		dash.active = false
		return
	var budget := minf(delta,minf(float(dash.left),maxf(0.0,DASH_DISTANCE - travelled)/DASH_SPEED))
	if budget <= 0.0:
		dash.active = false
		return
	dash.left = float(dash.left) - budget
	if is_instance_valid(session.tribes):
		session.tribes.workers.move(enemy,dash.target,budget,DASH_SPEED,"skill")
	else:
		enemy.move_and_collide(enemy.global_position.move_toward(dash.target,DASH_SPEED*budget) - enemy.global_position)
	if enemy.global_position.distance_to(start) >= DASH_DISTANCE or float(dash.left) <= 0.0: dash.active = false

func _parry(enemy: Node) -> void:
	# 与现有减伤来源共用分支登记：来源键唯一，按 ordinary_rate 的乘积规则共存。
	session.magic.branches._buff_set(_magic_id(enemy),"parry",2.0,{"rate":0.7,"source":"parry"})

func _suppress(enemy: Node) -> void:
	var target: Node = _hostile(enemy,enemy.attack_reach())
	if not is_instance_valid(target):
		# 窗口内目标离开/被遮挡：本次不发箭，已扣的一支退回该 NPC 自己的背包。
		session.inventory.exchange("npc:"+str(enemy.enemy_id),{},{"arrow":1})
		return
	var origin: Vector2 = enemy.global_position+Vector2(0,-8)
	var aim: Vector2=target.global_position+(Vector2.ZERO if "enemy_id" in target else Vector2(0,-3))
	var heading: Vector2 = origin.direction_to(aim)
	var arrow := Arrow.new()
	arrow.runtime=runtime; arrow.attacker=enemy.enemy_id; arrow.tribe=enemy.tribe
	arrow.damage=float(Careers.damage("archer",int(enemy.npc_level))); arrow.slow=0.2
	arrow.position=origin; arrow.direction=heading; arrow.left=enemy.attack_reach(); arrow.excluded=[enemy.get_rid()]
	session.world.objects.add_child(arrow)

func _chief(enemy: Node, skill: String, rule: Dictionary) -> void:
	var actor_id := _magic_id(enemy)
	var rank := int(rule.rank)
	var stats: Dictionary = session.vitals.ensure(actor_id)
	var limit := float(session.magic.max_mana(actor_id))
	# 起手已预扣，这里把成本还给 cast_for 做同一套校验；失败即等于原样退回。
	stats.mana = minf(limit,float(stats.mana) + float(Rules.COSTS[rank - 1]))
	var ok := _chief_cast(enemy,skill,rank)
	enemy.mana = int(clampf(float(stats.mana),0.0,limit))
	# 木系回春落在部落单位自己的生命上：每3在线秒回1点，持续30在线秒。
	if ok and skill == "chief_wood_heal":
		var state: Dictionary = _state(str(enemy.enemy_id))
		state.heal_left = 0.0
		state.heal_tick = 0.0

func _heal_step(enemy: Node, state: Dictionary, delta: float) -> void:
	if float(state.heal_left) <= 0.0: return
	var next := maxf(0.0,float(state.heal_left) - delta)
	state.heal_left = next
	if next <= 0.0: return
	state.heal_tick = float(state.heal_tick) - delta
	if float(state.heal_tick) > 0.0: return
	state.heal_tick = HEAL_TICK
	enemy.hp = minf(float(enemy.max_hp),float(enemy.hp) + 1.0)
	enemy.refresh()

func _chief_cast(enemy: Node, skill: String, rank: int) -> bool:
	var actor_id := _magic_id(enemy)
	match skill:
		"chief_wood_vine","chief_water_bubble","chief_fire_burn":
			var target: Node = _hostile(enemy,200.0)
			if not is_instance_valid(target): return false
			return session.magic.skills.cast_for(actor_id,rank,target.global_position)
		"chief_fire_ball":
			var target: Node = _hostile(enemy,200.0)
			if not is_instance_valid(target) or enemy.global_position.distance_to(target.global_position) < 4.0: return false
			return session.magic.skills.cast_for(actor_id,rank,target.global_position)
		"chief_wood_heal","chief_water_shield":
			return session.magic.skills.cast_for(actor_id,rank,enemy.global_position)
		"chief_earth_blink":
			var target: Node = _hostile(enemy,200.0)
			return session.magic.skills.cast_for(actor_id,rank,_escape_point(enemy,target))
		"chief_earth_hut":
			for offset: Vector2 in [Vector2(28,0),Vector2(-28,0),Vector2(0,28),Vector2(0,-28),Vector2(20,20),Vector2(-20,20),Vector2(20,-20),Vector2(-20,-20)]:
				if session.magic.skills.cast_for(actor_id,rank,enemy.global_position+offset): return true
			return false
	return false

func _recover_mana(enemy: Node, state: Dictionary, delta: float) -> void:
	if str(enemy.role) != "chief" or str(enemy.chief_id) == "": return
	var actor_id := _magic_id(enemy)
	var stats: Dictionary = session.vitals.ensure(actor_id)
	var limit := float(session.magic.max_mana(actor_id))
	# enemy.gd 的村长射击直接扣 enemy.mana；取两者较低值作为同一池的当前余额。
	if float(enemy.mana) < float(stats.mana): stats.mana = float(enemy.mana)
	if float(stats.mana) >= limit:
		state.mana_clock = 0.0
	else:
		state.mana_clock = float(state.mana_clock) + delta
		while float(state.mana_clock) + 0.000001 >= MANA_INTERVAL and float(stats.mana) < limit:
			stats.mana = minf(limit,float(stats.mana) + 1.0)
			state.mana_clock = maxf(0.0,float(state.mana_clock) - MANA_INTERVAL)
	enemy.mana = int(clampf(float(stats.mana),0.0,limit))

func _surrounded(enemy: Node) -> bool:
	var nearby := 0
	for player: Node in session.world.controllable:
		if is_instance_valid(player) and not player.dead and player.room_id==enemy.room_id and player.global_position.distance_to(enemy.global_position)<50: nearby+=1
	return nearby>=2

func _escape_point(enemy: Node, target: Node) -> Vector2:
	var away: Vector2=-_direction(enemy,target)
	for angle: float in [0.0,0.5,-0.5,1.0,-1.0]:
		var point: Vector2=enemy.global_position+away.rotated(angle)*80.0
		if session.magic.skills._landing(enemy,point) and session.magic.skills._line_clear(enemy,point): return point
	return Vector2.INF
