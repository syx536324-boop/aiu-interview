# Simulates one nearby hostile from another tribe; defeated state is persistent and never respawns on a timer.
extends CharacterBody2D
var npc_runtime: Node
var npc_level := 1
var resident_id := ""
var gender := "male"
var room_id := ""
var dead := false
var controlled := false
var friendly := false
var navigation := PackedVector2Array()
var facing := 0
var patrol_index := 0
var idle_time := 0.0
var combat: Node
var enemy_id := ""
var hp := 30.0
var max_hp := 30.0
var thirst := 10.0
var cooldown := 0.0
var pursuit := 0.0
var sprite: Sprite2D
# Tribe membership: raider (the three fixed outlanders), forest or barbarian.
var tribe := "raider"
var role := "charger"
var territory := Rect2()
var chief_id := ""
var shot_cooldown := 0.0
var mana := 0
# —— 行为模块（guards.gd）冻结接口用到的附加字段；上面公共字段一个不改 ——
var state := "life"                 # 固定状态名：life/patrol/observe/warn/engage/prepare/attack/search/retreat/return
var destination := Vector2.ZERO
var destination_set := false
var prepare_kind := ""
var prepare_left := 0.0
var home_anchor := Vector2.INF     # 岗位锚点，首次被守卫接管时记录出生/存档位置
var guards_managed := false        # 行为模块接管时置真：_physics_process 执行移动意图与动画/朝向
var _seen_at := Vector2.INF
var _walk_distance := 0.0
var _walk_facing := 0
const ROLE_NAMES := {"farmer":"农民","miner":"矿工","civilian": "平民", "archer": "弓箭手", "charger": "战士", "chief": "村长"}
const TRIBE_NAMES := {"raider": "外部落", "forest": "森林部落", "barbarian": "野蛮部落", "yunye": "云野部落"}

func configure_tribe(tribe_name: String, npc_role: String, area: Rect2, max_hp := 20.0) -> void:
	tribe = tribe_name
	role = npc_role
	territory = area
	self.max_hp=max_hp
	hp = max_hp
func label() -> String:
	return str(TRIBE_NAMES.get(tribe, tribe)) + " · " + str(ROLE_NAMES.get(role, role))
func aggro_range() -> float:
	if role == "civilian": return 60.0
	if tribe == "barbarian" or tribe == "yunye": return 210.0   # hostile: attacks whatever enters its sight
	if tribe == "forest": return 80.0       # unknown: only reacts at close range
	return 110.0
func attack_reach() -> float:
	var reach: float= combat.Gear.attack_range("bow") if role=="archer" else (200.0 if role=="chief" else (30.0 if role=="charger" else 13.0))
	if role in ["archer","chief"] and is_instance_valid(combat):
		var layout = combat.session.world.Layout
		if layout.PLATEAU.has_point(global_position) or layout.MOUNTAINS_EAST.has_point(global_position): reach *= 0.7
	return reach
func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 2 | 8
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5
	shape.shape = circle
	add_child(shape)
	sprite=Sprite2D.new()
	sprite.texture=preload("res://assets/ninja_adventure/Actor/Character/Caveman2/SpriteSheet.png")
	sprite.hframes=maxi(1,int(sprite.texture.get_width()/16.0))
	sprite.vframes=maxi(1,int(sprite.texture.get_height()/16.0))
	sprite.position=Vector2(0,-8)
	sprite.modulate=Color("d4a29d")
	add_child(sprite)
	add_to_group("hostile_targets")
	if not home_anchor.is_finite(): home_anchor = global_position
	_seen_at = global_position
	refresh()
func refresh() -> void:
	dead=hp<=0
	if friendly: remove_from_group("hostile_targets")
	elif not is_in_group("hostile_targets"): add_to_group("hostile_targets")
	visible = hp > 0
	collision_layer = 8 if hp > 0 else 0
	set_physics_process(hp > 0)
	queue_redraw()

# —— 文档 2.4 冻结的公共入口：其他模块只许调用这些 ——

func enter_state(state_name: String) -> void:
	if state == state_name: return
	state = state_name
	if state_name != "prepare": cancel_prepare()

# 允许超出 territory：边界判定由行为模块负责，这里只记录目标并清空旧路径。
func set_destination(at: Vector2) -> void:
	if not at.is_finite(): return
	if destination_set and destination.distance_to(at) <= 8.0: return
	destination = at
	destination_set = true
	navigation = PackedVector2Array()

func stop_moving() -> void:
	if has_meta("tribal_movement"): get_meta("tribal_movement").stop(self)
	velocity = Vector2.ZERO
	destination_set = false
	navigation = PackedVector2Array()

func begin_prepare(kind: String, duration: float) -> void:
	prepare_kind = kind
	prepare_left = maxf(0.05, duration)

func cancel_prepare() -> void:
	prepare_kind = ""
	prepare_left = 0.0

# 统一走 tribes.workers.move 的真实导航；返回是否已到达。
func move_toward_destination(delta: float, speed: float) -> bool:
	if not destination_set: return true
	if not is_instance_valid(combat): return true
	var session: Node = combat.session
	if not is_instance_valid(session) or not is_instance_valid(session.tribes): return true
	var api = session.tribes.workers
	if api == null: return true
	return api.move(self, destination, delta, speed,"guard")

# 内部仍走既有 cooldown/伤害规则；建筑目标带 constructed_home 元数据。
func order_attack(target: Node) -> void:
	if not is_instance_valid(combat) or not is_instance_valid(combat.session.tribes): return
	if combat.session.tribes.war.strike(enemy_id,self,target):
		cooldown=1.0
		if role in ["archer","chief"]: shot_cooldown=1.0

func retreat_to(at: Vector2) -> void:
	enter_state("retreat")
	set_destination(at)

func home_point() -> Vector2:
	if home_anchor.is_finite(): return home_anchor
	if territory.has_area(): return territory.get_center()
	return global_position

func hit_points() -> float: return hp
func is_alive() -> bool: return hp > 0 and not dead

func _physics_process(delta: float) -> void:
	if guards_managed or is_instance_valid(npc_runtime):
		# Decisions own the intent; only this physical frame moves the actual collision body.
		if has_meta("tribal_movement"): get_meta("tribal_movement").advance_actor(self,delta)
		_visual_tick()
		return
	cooldown = maxf(0,cooldown-delta)
	pursuit = maxf(0,pursuit-delta)
	shot_cooldown = maxf(0,shot_cooldown-delta)
	var session: Node = combat.session
	if session.magic.skills.rooted(enemy_id): velocity=Vector2.ZERO; return
	var actor: CharacterBody2D = session.world.active_resident
	var home: Dictionary = session.world.home_data(actor.room_id)
	var occupied_building: bool = home.get("built",false) and not home.get("ruined",false)
	if actor.dead or home.get("skill_hut",false) or (actor.room_id != "" and not occupied_building): return
	var target: Vector2 = home.door if occupied_building else actor.global_position
	var gap := global_position.distance_to(target)
	if gap > aggro_range() and pursuit <= 0: return
	# 边界判定已移交行为模块；非 population 单位（外部落）不再自行夹回领地。
	var reach := attack_reach()
	if gap > reach:
		var step: Vector2= global_position.direction_to(target) * 32 * session.magic.branches.speed_rate(enemy_id)
		velocity = step
		move_and_slide()
	elif cooldown <= 0:
		cooldown = 2.0
		if occupied_building:
			var element: String=str(combat.CHIEF_ELEMENT.get(tribe,"")) if role=="chief" else ""
			session.magic.branches.note_combat(actor.resident_id)
			session.construction.hit(actor.room_id,10,false,element)
		else:
			if role == "archer" or role == "chief":
				# Ranged tribe members shoot from cover; the chief spends mana like a player would.
				if role == "chief" and chief_id != "":
					if mana < 5:
						mana = mini(session.magic.max_mana(chief_id), mana + 1)
						return
					mana -= 5
				shot_cooldown = 2.0
			var ranged := role in ["archer","chief"]
			if ranged and session.magic.branches.barrier_blocks(global_position,actor.global_position): return
			# 伤害与声誉归属统一走战斗模块，避免多处直接改玩家生命。
			var payload := {"kind":"ranged" if ranged else "melee","element":str(combat.CHIEF_ELEMENT.get(tribe,"")) if role=="chief" else ""}
			if combat.has_method("apply_npc_damage"): combat.apply_npc_damage(self,actor.resident_id,1.0,payload)
			else: session.vitals.hurt(actor.resident_id,1.0,{"kind":payload.kind,"enemy":enemy_id,"element":payload.element})

# 由实际位移驱动朝向与行走帧，不依赖 velocity（workers.move 使用 move_and_collide）。
func _visual_tick() -> void:
	if not is_instance_valid(sprite): return
	if not _seen_at.is_finite(): _seen_at = global_position
	var step := global_position - _seen_at
	_seen_at = global_position
	var row := 0
	if step.length() > 0.001 and step.length()<4.0:
		face_toward(global_position+step)
		_walk_distance+=step.length()
		row=[mini(1,sprite.vframes-1),0,mini(3,sprite.vframes-1),0][int(_walk_distance/2.0)%4]
	else: _walk_distance=0.0
	sprite.flip_h=false
	sprite.frame=row*sprite.hframes+mini(_walk_facing,sprite.hframes-1)

func face_toward(at: Vector2) -> void:
	var direction: Vector2=at-global_position
	if direction.length_squared()<0.000001: return
	facing=1 if direction.x>=0 else -1
	_walk_facing=(3 if direction.x>0 else 2) if absf(direction.x)>absf(direction.y) else (0 if direction.y>0 else 1)
	if is_instance_valid(sprite):
		sprite.flip_h=false
		sprite.frame=mini(_walk_facing,sprite.hframes-1)

func _draw() -> void:
	if is_instance_valid(npc_runtime): draw_rect(Rect2(-2,-34,4,2),Color("dc9aab") if gender=="female" else Color("81b9d3"))
	draw_colored_polygon(PackedVector2Array([Vector2(-3,-28),Vector2(3,-28),Vector2(0,-25)]),relationship_color())
	draw_rect(Rect2(-10,-22,20,3),Color("392d27"))
	draw_rect(Rect2(-10,-22,20*hp/max_hp,3),Color("bf7060"))

	if thirst<10: draw_rect(Rect2(-10,-18,20*thirst/10.0,2),Color("72b8ce"))

func relationship_color() -> Color:
	if friendly: return Color("90d9ae")
	if is_instance_valid(npc_runtime):
		match npc_runtime.attitude(tribe):
			"trust","friendly": return Color("92c6b2")
			"neutral": return Color("d8c27c")
			"alert": return Color("d99666")
	return Color("e37657")
