# Owns five resident stats; survival clocks advance only for the controlled resident.
extends Node

signal message(text: String)
signal deaths_changed
const Water := preload("res://features/inventory/water_catalog.gd")
const NEED_INTERVAL := 180.0
const DAMAGE_INTERVAL := 10.0
const HEALTH_DEADLINE := 1800.0
const RAW_WINDOW := 600.0
var world: Node2D
var inventory: Node
var states: Dictionary = {}
var online := 0.0
var clock_driven := false
var magic: Node

func start(village: Node2D, belongings: Node) -> void:
	world = village
	inventory = belongings
	for actor in world.controllable:
		ensure(actor.resident_id)

func ensure(id: String) -> Dictionary:
	if not states.has(id):
		states[id] = {"life": 10, "hunger": 10, "thirst": 10, "health": 10, "mana": 10,
			"active_time": 0.0,
			"need_time": 0.0, "hunger_time":0.0, "thirst_time":0.0, "damage_time": 0.0, "low_health": false,
			"low_time": 0.0, "ill": false, "raw_meals": []}
	return states[id]

func _process(delta: float) -> void:
	if is_instance_valid(world) and not clock_driven:
		advance(delta)

func advance(delta: float) -> void:
	# Small deterministic steps preserve threshold order even during a long frame/test jump.
	var remaining := maxf(0, delta)
	var died := false
	var active_ids: Array = [world.active_resident.resident_id] if is_instance_valid(world) else states.keys()
	while remaining > 0.00001:
		var step := minf(remaining, 1.0)
		remaining -= step
		online += step
		for id: String in active_ids:
			var s: Dictionary = states[id]
			if s.life <= 0:
				continue
			s.active_time += step
			var was_low: bool = s.hunger <= 1 or s.thirst <= 1
			if was_low:
				s.damage_time += step
				if s.damage_time >= DAMAGE_INTERVAL:
					s.life = maxf(0, float(s.life) - damage( id,1))
					s.damage_time -= DAMAGE_INTERVAL
			else:
				s.damage_time = 0.0
			s.need_time = fmod(float(s.need_time)+step,NEED_INTERVAL)
			for stat in ["hunger","thirst"]:
				var timer: String=stat+"_time"
				s[timer]=float(s.get(timer,0))+step*(magic.skills.need_rate(id,stat) if is_instance_valid(magic) else 1.0)
				while float(s[timer])+0.000001 >= NEED_INTERVAL:
					s[stat]=maxi(0,int(s[stat])-1)
					s[timer]=maxf(0,float(s[timer])-NEED_INTERVAL)
			var already_low: bool = s.low_health
			_health_band(s, id)
			if already_low and s.low_health:
				s.low_time += step
				if s.low_time >= HEALTH_DEADLINE:
					s.life = 0
			_prune_meals(s)
			if s.life <= 0:
				died = true
	_sync_actors()
	if died:
		deaths_changed.emit()

func _health_band(s: Dictionary, id: String = "") -> void:
	if s.health <= 3:
		if not s.low_health:
			s.low_health = true
			s.low_time = 0.0
			s.life = maxf(0,float(s.life)-damage(id,5))
	else:
		s.low_health = false
		s.low_time = 0.0

func _prune_meals(s: Dictionary) -> void:
	var recent: Array = []
	for time: float in s.raw_meals:
		if float(s.active_time) - time <= RAW_WINDOW:
			recent.append(time)
	s.raw_meals = recent

func use_food(id: String, item: String, selected_index := -1) -> bool:
	if is_instance_valid(world) and id != world.active_resident.resident_id:
		return false
	var s := ensure(id)
	var drinking := Water.drinkable(item)
	if s.life <= 0 or (not drinking and item not in ["bread", "pork", "cooked_pork", "restorative_soup", "qi_soup", "apple", "carrot", "beef", "mutton", "cooked_beef", "cooked_mutton"]):
		return false
	if drinking and s.thirst >= 10:
		message.emit("饥渴已满，水量保持不变。")
		return false
	var rewards: Dictionary = {Water.after_drink(item): 1} if drinking else {}
	var bag: Array = inventory.ensure_bag(id)
	if selected_index < 0:
		for i in range(bag.size()):
			if bag[i].get("item", "") == item: selected_index = i; break
	if selected_index >= 0 and selected_index < bag.size() and bag[selected_index].get("item", "") == item:
		if drinking:
			inventory.transform_record(id,selected_index,Water.after_drink(item))
		else:
			bag[selected_index].count -= 1
			if bag[selected_index].count <= 0: bag[selected_index] = {}
	else:
		if not inventory.exchange(id, {item: 1}, rewards): return false
	if drinking: s.thirst = mini(10, int(s.thirst) + Water.THIRST_PER_DRINK)
	match item:
		"restorative_soup":
			s.life = max_life(id)
			s.health = 10
			s.ill = false
		"qi_soup":
			s.life = minf(max_life(id),float(s.life)+3)
			s.health = mini(10,int(s.health)+5)
			if s.health >= 7: s.ill = false
		"apple", "carrot": s.hunger = mini(10, int(s.hunger) + 2)
		"bread": s.hunger = mini(10, int(s.hunger) + 3)
		"cooked_pork", "cooked_beef", "cooked_mutton":
			s.hunger = mini(10, int(s.hunger) + 4)
			s.health = mini(10, int(s.health) + 1)
			if s.health >= 7: s.ill = false
		"pork", "beef", "mutton":
			s.hunger = mini(10, int(s.hunger) + 2)
			_prune_meals(s)
			s.raw_meals.append(s.active_time)
			if s.raw_meals.size() >= 3 and not s.ill:
				s.ill = true
				s.health = maxi(0, int(s.health) - 3)
	_health_band(s, id)
	if s.hunger > 1 and s.thirst > 1:
		s.damage_time = 0.0
	_sync_actors()
	if drinking:
		message.emit("喝了一杯水，饥渴 +4，留下空木杯。" if item == "water_cup" else "喝了1/4桶水，饥渴 +4；桶内剩余%d/4。" % (Water.units(item) - 1))
	else:
		message.emit("已食用；肠胃炎：奔跑速度 -30%，健康达到 7 后解除。" if s.ill else "已食用，状态已更新。")
	if s.life <= 0:
		deaths_changed.emit()
	return true

func revive(id: String) -> bool:
	if not states.has(id) or int(states[id].life) > 0:
		return false
	# A fresh life has no starvation debt, illness or pending low-health deadline.
	states.erase(id)
	ensure(id)
	states[id].life=max_life(id)
	_sync_actors()
	return true

func _sync_actors() -> void:
	if not is_instance_valid(world):
		return
	for actor in world.controllable:
		var s := ensure(actor.resident_id)
		actor.dead = s.life <= 0
		actor.run_multiplier = (0.7 if s.ill else 1.0)*(magic.skills.run_rate(actor.resident_id) if is_instance_valid(magic) else 1.0)
		actor.modulate = Color(0.5, 0.5, 0.5, 0.55) if actor.dead else Color.WHITE
		actor.collision_layer = 0 if actor.dead else 2

func max_life(id: String) -> float:
	return magic.skills.max_life(id) if is_instance_valid(magic) else 10.0
func damage(id: String, raw: float) -> float:
	return raw*(magic.skills.damage_rate(id) if is_instance_valid(magic) else 1.0)
func hurt(id: String, raw: float) -> void:
	var s := ensure(id)
	s.life=maxf(0,float(s.life)-damage(id,raw))
	_sync_actors()
	deaths_changed.emit()
func heal(id: String, amount: float) -> void:
	var s := ensure(id)
	if s.life<=0: return
	s.life=minf(max_life(id),float(s.life)+maxf(0,amount))
	_sync_actors()
func export_state() -> Dictionary:
	return {"online": online, "residents": states.duplicate(true)}

func restore(data: Dictionary) -> void:
	online = maxf(0, float(data.get("online", 0)))
	states.clear()
	for actor in world.controllable:
		var s := ensure(actor.resident_id)
		var source: Dictionary = data.get("residents", {}).get(actor.resident_id, {})
		for key in ["life", "hunger", "thirst", "health", "mana"]:
			s[key] = clampf(float(source.get(key,10)),0,max_life(actor.resident_id) if key=="life" else 10)
		for key in ["need_time", "damage_time", "low_time", "hunger_time", "thirst_time"]:
			s[key] = maxf(0, float(source.get(key,source.get("need_time",0) if key in ["hunger_time","thirst_time"] else 0)))
		s.low_health = bool(source.get("low_health", false))
		s.ill = bool(source.get("ill", false))
		s.raw_meals = source.get("raw_meals", []).duplicate()
		# Legacy meal timestamps used the global online clock; preserve their current ages.
		s.active_time = maxf(0, float(source.get("active_time", online)))
	_sync_actors()
