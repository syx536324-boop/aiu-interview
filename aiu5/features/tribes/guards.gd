# 未归附部落成员（forest/barbarian/yunye）的日常行为状态机。
# 状态名固定：life/patrol/observe/warn/engage/prepare/attack/search/retreat/return。
# 由 tribes.advance(delta) 在统一在线时钟下调用 advance()，禁止在 _process 另开计时器。
# 只接管 population 注册、friendly==false、没有出征命令、不在室内的单位；raider 与 home 成员不归本模块。
# 室内假设（lead 已批准）：玩家躲进已建成房屋时，门的位置属于公开信息（门口落在建筑轮廓上，
# 射线必然命中建筑本体），因此对室内玩家用“到门口的距离”判定，而不是射线；室外一律走射线遮挡。
# 接口约定见 docs/NPC_ATTITUDE_SKILLS_0.10.0.md 第 2.3/2.4 节，公共入口不得改名。
# tribes.gd 以 `var guards: Node` 持有本域，main.gd 用 add_child 挂载，故继承 Node。
extends Node

const SIGHT_NORMAL := 160.0        # 普通视距（世界像素）
const SIGHT_FOREST := 80.0         # 森林部落视距
const WARN_GRACE := 5.0            # 圣品禁区警告宽限（在线秒）
const CHASE_MARGIN := 240.0        # 允许追出本部落领地外的最大距离
const CHASE_LIMIT := 20.0          # 单次追击最长在线秒
const SEARCH_TIME := 5.0           # 失去视线后原地搜索的在线秒
const LOW_HP := 0.3                # 低血阈值：最大生命的 30%
const PATROL_MIN := 3              # 巡逻点下限
const PATROL_MAX := 5              # 巡逻点上限
const WAIT_MIN := 1.0              # 到点停留下限（在线秒）
const WAIT_MAX := 3.0              # 到点停留上限（在线秒）
const NEAR_DECISION := 0.4         # 玩家 600 像素内的决策间隔
const FAR_DISTANCE := 600.0        # 远处降频的距离阈值
const FAR_DECISION_MIN := 1.0
const FAR_DECISION_MAX := 2.0
const MELEE_SLOTS := 3             # 同一场战斗最多 3 名近战贴身
const STUCK_LIMIT := 1.5           # 卡住判定（在线秒）
const STUCK_GIVE_UP := 3           # 连续重寻路失败次数，超过则返回岗位
const LIFE_RADIUS := 56.0          # 平民日常活动半径
const PREPARE_TIME := 0.4          # 出手前的蓄力
const SKILL_INTERVAL := 6.0        # 本模块对招式的额外节流
const TRIBE_ROLES := ["forest", "barbarian", "yunye"]
const MELEE_STATES := ["engage", "prepare", "attack", "search", "warn", "retreat"]

var runtime: Node                  # owner = tribes
var session: Node
var units: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func start(owner: Node) -> void:
	runtime = owner
	session = owner.session if is_instance_valid(owner) else null
	units.clear()
	_rng.seed = 20261014

# —— 冻结接口 ——

func advance(delta: float) -> void:
	if not is_instance_valid(session) or delta <= 0.0: return
	var player: Node = session.world.active_resident
	var ctx := _player_context(player)
	var all: Dictionary = session.combat.enemies
	for id: String in all.keys():
		var enemy: Node = all.get(id)
		if not is_instance_valid(enemy): continue
		if not manages(enemy):
			_release(enemy)
			continue
		_manage(enemy, delta, ctx)

func npc(enemy_id: String) -> Dictionary:
	return _record(enemy_id)

func snapshot_for(enemy_id: String) -> Dictionary:
	return _record(enemy_id).duplicate(true)

func export_state() -> Dictionary:
	var saved: Dictionary = {}
	for id: String in units:
		var rec: Dictionary = units[id]
		saved[id] = {
			"state": str(rec.state), "wait": float(rec.wait), "pursuit": float(rec.pursuit),
			"last_seen": [float(rec.last_seen.x), float(rec.last_seen.y)], "warned": bool(rec.warned),
			"route": _points_to_arrays(rec.route), "route_index": int(rec.route_index),
			"skill_cd": float(rec.skill_cd), "target_id": str(rec.target_id),
			"grace": float(rec.grace), "search": float(rec.search), "chase": float(rec.chase),
			"seen": bool(rec.seen), "observe": float(rec.observe),
			"home": [float(rec.home.x), float(rec.home.y)], "slot": str(rec.slot)}
	return {"units": saved}

func restore(data: Dictionary) -> void:
	units.clear()
	if not (data is Dictionary): return
	var saved: Dictionary = data.get("units", {})
	if not (saved is Dictionary): return
	for id: String in saved:
		var s: Dictionary = saved[id] if saved[id] is Dictionary else {}
		var rec := _record(id)
		rec.state = str(s.get("state", "life"))
		rec.wait = float(s.get("wait", 0.0))
		rec.pursuit = float(s.get("pursuit", 0.0))
		rec.last_seen = _vector_of(s.get("last_seen", [0.0, 0.0]), Vector2.ZERO)
		rec.warned = bool(s.get("warned", false))
		rec.route = _arrays_to_points(s.get("route", []))
		rec.route_index = maxi(0, int(s.get("route_index", 0)))
		rec.skill_cd = maxf(0.0, float(s.get("skill_cd", 0.0)))
		rec.target_id = str(s.get("target_id", ""))
		rec.grace = maxf(0.0, float(s.get("grace", 0.0)))
		rec.search = float(s.get("search", 0.0))
		rec.chase = float(s.get("chase", 0.0))
		rec.seen = bool(s.get("seen", false))
		rec.observe = float(s.get("observe", 0.0))
		rec.home = _vector_of(s.get("home", [0.0, 0.0]), Vector2.ZERO)
		rec.slot = str(s.get("slot", "melee"))

# —— 接管判定 ——

# 只接管未归附、没有出征命令、不在室内的部落成员；归附（friendly）与 raider/home 一律不碰。
func manages(enemy: Node) -> bool:
	if not is_instance_valid(enemy) or not is_instance_valid(runtime): return false
	if float(enemy.hp) <= 0.0 or bool(enemy.dead): return false
	if bool(enemy.friendly): return false
	if str(enemy.tribe) not in TRIBE_ROLES: return false
	if str(enemy.room_id) != "": return false
	if not runtime.population.members.has(str(enemy.enemy_id)): return false
	if runtime.war.orders.has(str(enemy.enemy_id)): return false
	if is_instance_valid(runtime.romance) and runtime.romance.busy(str(enemy.resident_id)): return false
	return true

func _release(enemy: Node) -> void:
	if bool(enemy.guards_managed):
		enemy.guards_managed = false
		enemy.stop_moving()
	# 交回 war.gd 或死亡：不再算作来犯者。
	enemy.set_meta("raiding", false)

# —— 单帧推进 ——

func _manage(enemy: Node, delta: float, ctx: Dictionary) -> void:
	var id := str(enemy.enemy_id)
	var rec := _record(id)
	_ensure_owned(enemy, rec)
	_tick(enemy, rec, delta)
	if _immobile(id):
		enemy.stop_moving()
		return
	var near: bool = bool(ctx.valid) and enemy.global_position.distance_to(ctx.at) <= FAR_DISTANCE
	# 已发生的战斗不降频：战斗状态每帧都重新决策；刚被命中（pursuit>0）也要立刻醒来反击。
	if str(rec.state) in MELEE_STATES or float(enemy.pursuit) > 0.0: rec.think = 0.0
	rec.think = float(rec.think) - delta
	if float(rec.think) <= 0.0:
		rec.think = NEAR_DECISION if near else _rng.randf_range(FAR_DECISION_MIN, FAR_DECISION_MAX)
		_decide(enemy, rec, ctx)
	_act(enemy, rec, delta, ctx)

func _ensure_owned(enemy: Node, rec: Dictionary) -> void:
	enemy.guards_managed = true
	if not enemy.home_anchor.is_finite(): enemy.home_anchor = enemy.global_position
	rec.home = enemy.home_point()
	if rec.route.is_empty() and str(enemy.role) in ["archer", "charger", "chief"]:
		rec.route = _build_route(enemy)

func _tick(enemy: Node, rec: Dictionary, delta: float) -> void:
	enemy.cooldown = maxf(0.0, enemy.cooldown - delta)
	enemy.shot_cooldown = maxf(0.0, enemy.shot_cooldown - delta)
	# pursuit 由外部命中写入（combat.gd 设 6 秒），这里用统一在线时钟衰减。
	enemy.pursuit = maxf(0.0, enemy.pursuit - delta)
	rec.pursuit = enemy.pursuit
	rec.skill_cd = maxf(0.0, float(rec.skill_cd) - delta)
	rec.grace = maxf(0.0, float(rec.grace) - delta)
	rec.search = float(rec.search) - delta
	rec.observe = float(rec.observe) - delta
	rec.wait = maxf(0.0, float(rec.wait) - delta)
	enemy.idle_time = maxf(0.0, enemy.idle_time - delta)
	if enemy.prepare_left > 0.0: enemy.prepare_left = maxf(0.0, enemy.prepare_left - delta)
	if str(rec.state) in ["engage", "prepare", "attack", "search"]: rec.chase = float(rec.chase) + delta

# —— 感知：必须尊重遮挡，禁止穿墙/隔水知道玩家位置 ——

func _player_context(player: Node) -> Dictionary:
	if not is_instance_valid(player) or bool(player.dead):
		return {"valid": false, "at": Vector2.INF, "home": "", "indoors": false}
	var room_id := str(player.room_id)
	var home: Dictionary = session.world.home_data(room_id)
	var occupied: bool = bool(home.get("built", false)) and not bool(home.get("ruined", false))
	# 与既有规则一致：技能屋与未建成屋内不构成可攻击目标。
	if bool(home.get("skill_hut", false)) or (room_id != "" and not occupied):
		return {"valid": false, "at": Vector2.INF, "home": "", "indoors": false}
	if occupied:
		return {"valid": true, "at": Vector2(home.get("door", player.global_position)), "home": room_id, "indoors": true}
	return {"valid": true, "at": player.global_position, "home": "", "indoors": false}

func _sight_range(tribe: String) -> float:
	return SIGHT_FOREST if tribe == "forest" else SIGHT_NORMAL

# 掩码与冻结约定一致：1(地形)|2(居民)|4(牲畜)|8(部落单位)|16(圣品)，排除自身。
func _sees(enemy: Node, at: Vector2) -> bool:
	if not at.is_finite() or not enemy.is_inside_tree(): return false
	var from: Vector2 = enemy.global_position + Vector2(0, -6)
	var query := PhysicsRayQueryParameters2D.create(from, at, 1|2|4|8|16, [enemy.get_rid()])
	var hit: Dictionary = enemy.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return true
	var collider: Variant = hit.get("collider")
	# 命中玩家本体才算看见；被墙、水、栅栏或同伴挡住就是看不见。
	return is_instance_valid(collider) and collider == session.world.active_resident

func _relic_at(tribe: String) -> Vector2:
	if not is_instance_valid(runtime.relics): return Vector2.INF
	var visual: Variant = runtime.relics.visuals.get(tribe, null)
	return visual.global_position if is_instance_valid(visual) else Vector2.INF

# —— 决策（0.4 在线秒 / 远处 1~2 在线秒一次） ——

func _decide(enemy: Node, rec: Dictionary, ctx: Dictionary) -> void:
	var tribe := str(enemy.tribe)
	var role := str(enemy.role)
	var valid: bool = bool(ctx.valid)
	var at: Vector2 = ctx.at if valid else Vector2.INF
	var gap: float = enemy.global_position.distance_to(at) if valid else INF
	var seen := false
	if valid:
		if bool(ctx.indoors):
			# 玩家躲进建成的房屋：门的位置属于公开信息，不用射线（门口落在建筑轮廓上）。
			seen = gap <= _sight_range(tribe)
		else:
			seen = gap <= _sight_range(tribe) and _sees(enemy, at)
		if seen:
			rec.last_seen = at
			rec.seen = true
	var relic_at := _relic_at(tribe)
	var in_zone: bool = valid and not bool(ctx.indoors) and relic_at.is_finite() and at.distance_to(relic_at) <= runtime.relic_zone(tribe)
	if not in_zone and bool(rec.warned):
		# 离开禁区即解除本次驱赶。
		rec.warned = false
		rec.grace = 0.0
	# 低血：平民/农民/矿工优先逃向本方安全位置，普通战士拖后，弓箭手拉开距离，村长坚持。
	if _health_ratio(enemy) < LOW_HP and role != "chief":
		if str(rec.state) != "retreat": _change(enemy, rec, "retreat")
		return
	# 圣品禁区：仅本方与信任玩家可进；中立/警戒部落闯入先警告，宽限 5 在线秒后驱赶。
	if in_zone and not _trusted(tribe) and not _hostile(tribe):
		if not bool(rec.warned):
			rec.warned = true
			rec.grace = WARN_GRACE
			_notice("%s的守卫喝止了你。" % _tribe_name(tribe))
		if float(rec.grace) > 0.0:
			if str(rec.state) != "warn": _change(enemy, rec, "warn")
			return
		rec.target_id = "player"
		if str(rec.state) != "engage": _change(enemy, rec, "engage")
		return
	if seen:
		# 敌对部落见人就打；中立队列里刚被玩家攻击（pursuit>0）或同伴有战事的成员会立刻支援。
		if _hostile(tribe) or float(enemy.pursuit) > 0.0 or _ally_engaged(tribe, enemy):
			rec.target_id = ("home:" + str(ctx.home)) if bool(ctx.indoors) else "player"
			if str(rec.state) not in ["engage", "prepare", "attack"]: _change(enemy, rec, "engage")
			return
		# 中立/警戒部落不因看见就开战：先观察，靠近或挑衅后才接敌。
		if str(rec.state) != "observe": _change(enemy, rec, "observe")
		return
	if str(rec.state) == "search": return
	if float(enemy.pursuit) > 0.0 and bool(rec.seen):
		if str(rec.state) != "search": _change(enemy, rec, "search")
		return
	if str(rec.state) in ["engage", "prepare", "attack", "observe", "warn"]:
		_change(enemy, rec, "return")
		return
	if str(rec.state) == "retreat": return
	if enemy.global_position.distance_to(enemy.home_point()) > 140.0:
		_change(enemy, rec, "return")
		return
	_choose_life(enemy, rec)

func _choose_life(enemy: Node, rec: Dictionary) -> void:
	# 士兵/弓箭手/村长走巡逻；平民/幼童留在村庄过日常。
	if str(enemy.role) in ["archer", "charger", "chief"] or not rec.route.is_empty():
		if str(rec.state) != "patrol": _change(enemy, rec, "patrol")
	else:
		if str(rec.state) != "life": _change(enemy, rec, "life")

func _change(enemy: Node, rec: Dictionary, next: String) -> void:
	if str(rec.state) == next: return
	rec.state = next
	enemy.enter_state(next)
	rec.prep = false
	# 供 combat._is_raiding() 区分真正来犯与被挑衅转身的中立 NPC。
	# 只有目标属于玩家一方（玩家本人或其已建成房屋）且处于接敌/备战/出手时才算来犯。
	if next in ["engage", "prepare", "attack"]:
		var tid := str(rec.target_id)
		enemy.set_meta("raiding", tid == "player" or tid.begins_with("home:"))
	else:
		enemy.set_meta("raiding", false)
	match next:
		"search":
			rec.search = SEARCH_TIME
		"return":
			rec.chase = 0.0
			enemy.pursuit = 0.0
			rec.pursuit = 0.0
		"life":
			rec.wait = _rng.randf_range(WAIT_MIN, WAIT_MAX)
			rec.has_target = false
		"observe":
			rec.observe = 1.5

# —— 状态执行 ——

func _act(enemy: Node, rec: Dictionary, delta: float, ctx: Dictionary) -> void:
	var speed := 32.0 * _speed_rate(enemy)
	match str(rec.state):
		"life": _act_life(enemy, rec, delta, speed)
		"patrol": _act_patrol(enemy, rec, delta, speed)
		"observe": _act_observe(enemy, rec, delta, speed, ctx)
		"warn": _act_warn(enemy, rec, delta, ctx)
		"engage": _act_engage(enemy, rec, delta, speed, ctx)
		"prepare": _act_prepare(enemy, rec, delta, ctx)
		"attack": _act_attack(enemy, rec, delta, ctx)
		"search": _act_search(enemy, rec, delta, speed)
		"retreat": _act_retreat(enemy, rec, delta, speed, ctx)
		"return": _act_return(enemy, rec, delta, speed)

func _act_life(enemy: Node, rec: Dictionary, delta: float, speed: float) -> void:
	if float(rec.wait) > 0.0:
		enemy.stop_moving()
		return
	if not bool(rec.has_target):
		rec.target = enemy.home_point() + Vector2(_rng.randf_range(-LIFE_RADIUS, LIFE_RADIUS), _rng.randf_range(-LIFE_RADIUS, LIFE_RADIUS))
		rec.has_target = true
	if _move(enemy, rec, rec.target, delta, speed * 0.7):
		rec.has_target = false
		rec.wait = _rng.randf_range(WAIT_MIN, WAIT_MAX)

func _act_patrol(enemy: Node, rec: Dictionary, delta: float, speed: float) -> void:
	if rec.route.is_empty():
		_change(enemy, rec, "life")
		return
	if float(rec.wait) > 0.0:
		enemy.stop_moving()
		return
	var index: int = int(rec.route_index) % rec.route.size()
	if _move(enemy, rec, rec.route[index], delta, speed):
		rec.route_index = (index + 1) % rec.route.size()
		rec.wait = _rng.randf_range(WAIT_MIN, WAIT_MAX)

func _act_observe(enemy: Node, rec: Dictionary, delta: float, speed: float, ctx: Dictionary) -> void:
	enemy.stop_moving()
	if not bool(ctx.valid):
		_change(enemy, rec, "return")
		return
	_face(enemy, ctx.at)
	var gap: float = enemy.global_position.distance_to(ctx.at)
	if _hostile(str(enemy.tribe)) and gap <= _sight_range(str(enemy.tribe)):
		rec.target_id = ("home:" + str(ctx.home)) if bool(ctx.indoors) else "player"
		_change(enemy, rec, "engage")
		return
	if float(rec.observe) <= 0.0 or gap > _sight_range(str(enemy.tribe)) * 1.35:
		_change(enemy, rec, "return")

func _act_warn(enemy: Node, rec: Dictionary, delta: float, ctx: Dictionary) -> void:
	enemy.stop_moving()
	if not bool(ctx.valid):
		_change(enemy, rec, "return")
		return
	_face(enemy, ctx.at)

func _act_engage(enemy: Node, rec: Dictionary, delta: float, speed: float, ctx: Dictionary) -> void:
	if not bool(ctx.valid):
		_change(enemy, rec, "return")
		return
	var at: Vector2 = ctx.at
	var tribe := str(enemy.tribe)
	# 追击：不超出本部落领地外 240 世界像素，最长 20 在线秒。
	if not _inside_chase(tribe, at) or float(rec.chase) > CHASE_LIMIT:
		_change(enemy, rec, "return")
		return
	var gap: float = enemy.global_position.distance_to(at)
	var reach: float = enemy.attack_reach()
	if bool(ctx.indoors):
		reach = maxf(reach, 24.0)
		if gap > reach:
			_move(enemy, rec, _chase_point(enemy, at), delta, speed)
			return
		_change(enemy, rec, "prepare")
		return
	if gap > reach:
		var dest := _station_for(enemy, rec, at, at)
		dest = _chase_point(enemy, dest)
		_move(enemy, rec, dest, delta, speed)
		return
	if not _sees(enemy, at):
		rec.last_seen = at
		rec.seen = true
		_change(enemy, rec, "search")
		return
	_change(enemy, rec, "prepare")

func _act_prepare(enemy: Node, rec: Dictionary, delta: float, ctx: Dictionary) -> void:
	enemy.stop_moving()
	if not bool(ctx.valid):
		_change(enemy, rec, "return")
		return
	_face(enemy, ctx.at)
	if not bool(rec.prep):
		enemy.begin_prepare(_prepare_kind(enemy), PREPARE_TIME)
		rec.prep = true
		return
	if enemy.prepare_left > 0.0: return
	rec.prep = false
	_change(enemy, rec, "attack")

func _act_attack(enemy: Node, rec: Dictionary, delta: float, ctx: Dictionary) -> void:
	var target_id := str(rec.target_id)
	if target_id.begins_with("home:"):
		var room_id := target_id.trim_prefix("home:")
		var body := _home_body(room_id)
		if is_instance_valid(body): enemy.order_attack(body)
		else: _bash_home(enemy, room_id)
	elif _try_skill(enemy, rec, ctx):
		pass
	else:
		var target := _target_node(enemy, rec, ctx)
		if is_instance_valid(target): enemy.order_attack(target)
	_change(enemy, rec, "engage")

func _act_search(enemy: Node, rec: Dictionary, delta: float, speed: float) -> void:
	if float(rec.search) <= 0.0:
		_change(enemy, rec, "return")
		return
	# 只记住最后看见的位置，不穿墙追踪。
	var at: Vector2 = rec.last_seen if rec.last_seen.is_finite() else enemy.home_point()
	_move(enemy, rec, at, delta, speed)

func _act_retreat(enemy: Node, rec: Dictionary, delta: float, speed: float, ctx: Dictionary) -> void:
	var role := str(enemy.role)
	if not bool(ctx.valid):
		_change(enemy, rec, "return")
		return
	if _health_ratio(enemy) >= LOW_HP * 1.5:
		_change(enemy, rec, "return")
		return
	var at: Vector2 = ctx.at
	match role:
		"archer":
			# 弓箭手拉开距离：退到射程外再回身接战。
			if enemy.global_position.distance_to(at) >= maxf(160.0, enemy.attack_reach() * 1.2):
				if _hostile(str(enemy.tribe)) or float(enemy.pursuit) > 0.0: _change(enemy, rec, "engage")
				else: _change(enemy, rec, "return")
				return
			_move(enemy, rec, _back_off_point(enemy, at, 170.0), delta, speed)
		"charger":
			# 普通战士拖后：边退边面向威胁，不溃逃。
			_face(enemy, at)
			_move(enemy, rec, _back_off_point(enemy, at, 130.0), delta, speed * 0.6)
		_:
			# 平民/农民/矿工优先逃向本方安全位置。
			_move(enemy, rec, _safe_point(enemy, at), delta, speed * 1.15)

func _act_return(enemy: Node, rec: Dictionary, delta: float, speed: float) -> void:
	var home: Vector2 = enemy.home_point()
	if enemy.global_position.distance_to(home) <= 20.0 or _move(enemy, rec, home, delta, speed):
		rec.chase = 0.0
		rec.seen = false
		_choose_life(enemy, rec)

# —— 移动、卡住与边界 ——

func _move(enemy: Node, rec: Dictionary, at: Vector2, delta: float, speed: float) -> bool:
	if not at.is_finite(): return false
	enemy.set_destination(at)
	var before: Vector2 = enemy.global_position
	var arrived: bool = enemy.move_toward_destination(delta, speed)
	if arrived:
		rec.stuck = 0.0
		rec.stuck_tries = 0
		return true
	var step: float = enemy.global_position.distance_to(before)
	if step < speed * delta * 0.1:
		rec.stuck = float(rec.stuck) + delta
	else:
		rec.stuck = 0.0
	if float(rec.stuck) >= STUCK_LIMIT:
		# 卡住超过约 1.5 秒：强制重寻路；连续不可达则交回岗位。
		rec.stuck = 0.0
		rec.stuck_tries = int(rec.stuck_tries) + 1
		enemy.navigation = PackedVector2Array()
		enemy.set_meta("work_retry", 0.5)
		if int(rec.stuck_tries) >= STUCK_GIVE_UP:
			rec.stuck_tries = 0
			rec.route = []
			_change(enemy, rec, "return")
			return false
	return false

func _chase_point(enemy: Node, at: Vector2) -> Vector2:
	var area: Rect2 = runtime.zone(str(enemy.tribe))
	if not area.has_area(): return at
	var limit := area.grow(CHASE_MARGIN)
	return at.clamp(limit.position, limit.end)

func _inside_chase(tribe: String, at: Vector2) -> bool:
	var area: Rect2 = runtime.zone(tribe)
	if not area.has_area(): return true
	return area.grow(CHASE_MARGIN).has_point(at)

# —— 名额表：同一场战斗最多 3 名近战贴身，其余走包抄/远程位（只改目的地，不传送） ——

func _station_for(enemy: Node, rec: Dictionary, target_at: Vector2, plain: Vector2) -> Vector2:
	var role := str(enemy.role)
	var reach: float = enemy.attack_reach()
	if role in ["archer", "chief"]:
		rec.slot = "ranged"
		var dir: Vector2 = target_at.direction_to(enemy.global_position)
		if dir.length() < 0.1: dir = Vector2.RIGHT
		return target_at + dir * maxf(reach * 0.75, 40.0)
	var rank := _melee_rank(enemy, rec, target_at)
	if rank < MELEE_SLOTS:
		rec.slot = "melee"
		return plain
	rec.slot = "flank"
	var dir: Vector2 = enemy.global_position.direction_to(target_at)
	if dir.length() < 0.1: dir = Vector2.RIGHT
	var side := Vector2(-dir.y, dir.x)
	var sign_side := -1.0 if absi(str(enemy.enemy_id).hash()) % 2 == 0 else 1.0
	var offset := 34.0 + float(rank - MELEE_SLOTS) * 16.0
	return target_at - dir * maxf(reach * 0.9, 26.0) + side * offset * sign_side

func _melee_rank(enemy: Node, rec: Dictionary, target_at: Vector2) -> int:
	var mine: float = enemy.global_position.distance_squared_to(target_at)
	var rank := 0
	for id: String in units:
		var other: Node = session.combat.enemies.get(id)
		if not is_instance_valid(other) or other == enemy: continue
		if not bool(other.guards_managed): continue
		var other_rec: Dictionary = units[id]
		if str(other_rec.target_id) != str(rec.target_id): continue
		if str(other.role) in ["archer", "chief"]: continue
		if str(other_rec.state) not in ["engage", "prepare", "attack"]: continue
		var gap: float = other.global_position.distance_squared_to(target_at)
		if gap < mine or (is_equal_approx(gap, mine) and id < str(enemy.enemy_id)): rank += 1
	return rank

# —— 巡逻路线与岗位 ——

func _build_route(enemy: Node) -> Array:
	var home: Vector2 = enemy.home_point()
	var area: Rect2 = runtime.zone(str(enemy.tribe))
	if not area.has_area(): area = Rect2(home - Vector2(120, 120), Vector2(240, 240))
	var count := _rng.randi_range(PATROL_MIN, PATROL_MAX)
	var route: Array = []
	for i in count:
		var at := home
		for attempt in range(10):
			var candidate: Vector2 = home + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * Vector2(area.size.x, area.size.y) * 0.3
			candidate = candidate.clamp(area.position + Vector2(8, 8), area.end - Vector2(8, 8))
			if _walkable(candidate): at = candidate; break
		route.append(at)
	return route

func _walkable(at: Vector2) -> bool:
	# navigation 是 RefCounted，不能用 Node 类型标注。
	var nav = session.world.navigation
	if nav == null: return true
	# 直接问真实导航服务：单点可达才算可通行点（避免路线落在水面/障碍里）。
	return not nav.find_path(at, at).is_empty()

# —— 目标与工具 ——

func _target_node(enemy: Node, rec: Dictionary, ctx: Dictionary) -> Node:
	var player: Node = session.world.active_resident
	return player if is_instance_valid(player) and not bool(player.dead) else null

func _home_body(room_id: String) -> Node:
	if room_id == "" or not session.construction.nodes.has(room_id): return null
	for body: Node in session.construction.nodes[room_id].find_children("*", "StaticBody2D", true, false):
		if body.has_meta("constructed_home"): return body
	return null

func _bash_home(enemy: Node, room_id: String) -> void:
	if float(enemy.cooldown) > 0.0: return
	enemy.cooldown = 2.0
	var element := ""
	if str(enemy.role) == "chief": element = str(session.combat.CHIEF_ELEMENT.get(str(enemy.tribe), ""))
	session.magic.branches.note_combat(str(session.world.active_resident.resident_id))
	session.construction.hit(room_id, 10, false, element)

func _prepare_kind(enemy: Node) -> String:
	match str(enemy.role):
		"archer": return "shoot"
		"chief": return "cast"
		"charger": return "slash"
	return "bash"

# 招式优先，失败退回既有 cooldown/伤害规则；招式域缺席时完全静默。
func _try_skill(enemy: Node, rec: Dictionary, ctx: Dictionary) -> bool:
	if bool(ctx.indoors) or float(rec.skill_cd) > 0.0: return false
	if is_instance_valid(runtime.npc_skills) and str(runtime.npc_skills._state(str(enemy.enemy_id)).prepare.skill)!="": return true
	var skills: Variant = runtime.get("npc_skills")
	if not is_instance_valid(skills): return false
	var target: Node = session.world.active_resident
	if not is_instance_valid(target): return false
	for skill: String in _skill_candidates(enemy):
		if skills.has_method("can_use") and not bool(skills.can_use(enemy, skill)): continue
		if skills.has_method("use") and bool(skills.use(enemy, skill)):
			rec.skill_cd = SKILL_INTERVAL
			return true
	return false

func _skill_candidates(enemy: Node) -> Array:
	match str(enemy.role):
		"charger": return ["parry","dash_slash"] if _health_ratio(enemy)<0.7 else ["dash_slash","parry"]
		"archer": return ["suppress_shot"]
		"chief":
			match str(runtime.elements.get(str(enemy.tribe), "")):
				"wood": return ["chief_wood_heal", "chief_wood_vine"] if _health_ratio(enemy)<0.7 else ["chief_wood_vine", "chief_wood_heal"]
				"water": return ["chief_water_shield","chief_water_bubble"]
				"fire": return ["chief_fire_ball", "chief_fire_burn"]
				"earth": return ["chief_earth_blink", "chief_earth_hut"]
	return []

func _back_off_point(enemy: Node, player_at: Vector2, distance: float) -> Vector2:
	if not player_at.is_finite(): return enemy.home_point()
	var dir := player_at.direction_to(enemy.global_position)
	if dir.length() < 0.1: dir = Vector2.RIGHT
	return player_at + dir * distance

func _safe_point(enemy: Node, player_at: Vector2) -> Vector2:
	var center: Variant = runtime.centers.get(str(enemy.tribe), enemy.home_point())
	return Vector2(center) if center is Vector2 else enemy.home_point()

func _face(enemy: Node, at: Vector2) -> void:
	if not at.is_finite(): return
	var dx: float = at.x - enemy.global_position.x
	enemy.facing = 1 if dx >= 0.0 else -1
	if is_instance_valid(enemy.sprite): enemy.sprite.flip_h = dx < 0.0

func _health_ratio(enemy: Node) -> float:
	return clampf(float(enemy.hp) / maxf(1.0, float(enemy.max_hp)), 0.0, 1.0)

func _speed_rate(enemy: Node) -> float:
	var magic: Node = session.magic
	if is_instance_valid(magic) and is_instance_valid(magic.branches): return maxf(0.2, float(magic.branches.speed_rate(str(enemy.enemy_id))))
	return 1.0

func _immobile(id: String) -> bool:
	var magic: Node = session.magic
	if not is_instance_valid(magic): return false
	if is_instance_valid(magic.skills) and magic.skills.rooted(id): return true
	if is_instance_valid(magic.branches) and magic.branches.immobile(id): return true
	return false

func _hostile(tribe: String) -> bool:
	# 关系服务提供 hostile()；若尚未落地，退回旧规则（野蛮/云野敌对，森林被挑衅后敌对）。
	if runtime.has_method("hostile"): return bool(runtime.hostile(tribe))
	return tribe in ["barbarian", "yunye"] or bool(runtime.war.anger.get(tribe, false))

# 同伴支援：同部落已有成员被玩家击中（pursuit>0）或正在与本方目标交战。
func _ally_engaged(tribe: String, enemy: Node) -> bool:
	for id: String in units:
		var other: Node = session.combat.enemies.get(id)
		if not is_instance_valid(other) or other == enemy or str(other.tribe) != tribe: continue
		if float(other.pursuit) > 0.0: return true
		if str(other.state) in ["engage", "prepare", "attack"] and str(units[id].target_id) != "": return true
	return false

func _trusted(tribe: String) -> bool:
	# 本方与信任/友好态度的玩家获准进入圣品禁区。
	if runtime.has_method("trusted"): return bool(runtime.trusted(tribe))
	if runtime.has_method("attitude"): return str(runtime.attitude(tribe)) in ["trust", "friendly"]
	return runtime.relics.owner(tribe) == "player"

func _tribe_name(tribe: String) -> String:
	var labels: Dictionary = runtime.names if runtime.get("names") is Dictionary else {}
	return str(labels.get(tribe, tribe))

func _notice(text: String) -> void:
	if session.has_method("_set_notice"): session._set_notice(text)

func _points_to_arrays(points: Array) -> Array:
	var out: Array = []
	for p: Vector2 in points: out.append([float(p.x), float(p.y)])
	return out

func _arrays_to_points(saved: Variant) -> Array:
	var out: Array = []
	if not (saved is Array): return out
	for p: Variant in saved:
		if p is Array and p.size() == 2: out.append(Vector2(float(p[0]), float(p[1])))
	return out

func _vector_of(saved: Variant, fallback: Vector2) -> Vector2:
	if saved is Array and saved.size() == 2: return Vector2(float(saved[0]), float(saved[1]))
	return fallback

func _record(enemy_id: String) -> Dictionary:
	if not units.has(enemy_id):
		units[enemy_id] = {
			"state": "life", "wait": 0.0, "pursuit": 0.0, "last_seen": Vector2.ZERO,
			"warned": false, "route": [], "route_index": 0, "skill_cd": 0.0, "target_id": "",
			"think": 0.0, "grace": 0.0, "search": 0.0, "chase": 0.0, "home": Vector2.ZERO,
			"stuck": 0.0, "stuck_tries": 0, "seen": false, "observe": 0.0, "prep": false,
			"target": Vector2.ZERO, "has_target": false, "slot": "melee"}
	return units[enemy_id]
