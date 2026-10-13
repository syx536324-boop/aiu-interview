# Owns immutable gift-level attack bonuses, elemental hit effects and actor-shared proc cooldowns.
extends Node
const Origin := preload("res://features/gifts/provenance.gd")
var magic: Node
var session: Node
var burns: Dictionary={}
var slows: Dictionary={}
var cooldowns: Dictionary={}
func start(owner_magic: Node) -> void:
	magic=owner_magic; session=magic.session
static func level(record: Dictionary) -> int:
	return clampi(int(record.get("gift_level",1)),1,100)
static func bonus(record: Dictionary) -> float:
	return minf(level(record)*0.2,10.0) if Origin.magical(record) else 0.0
func _key(target: Node) -> String:
	return "enemy:"+str(target.enemy_id) if "enemy_id" in target else ("animal:"+str(target.animal_id) if "animal_id" in target else "")
func _target(key: String) -> Node:
	return session.combat.enemies.get(key.trim_prefix("enemy:")) if key.begins_with("enemy:") else session.livestock.find_animal(key.trim_prefix("animal:"))
func on_attack(actor: String, record: Dictionary) -> void:
	if not Origin.magical(record) or str(record.get("magic_attribute",""))!="earth": return
	var key := actor+":earth"
	if float(cooldowns.get(key,0))>0: return
	cooldowns[key]=30.0
	magic.branches._buff_set(actor,"gift_earth",10.0,{"shield":10.0+level(record)*0.1,"source":"enchant_earth"})
	var caster: Node=magic._actor(actor)
	if is_instance_valid(caster): _pulse(actor,"earth",caster.global_position)
func on_hit(actor: String, target: Node, record: Dictionary, removed: float) -> void:
	if not Origin.magical(record) or not is_instance_valid(target) or removed<=0: return
	var element := str(record.get("magic_attribute",""))
	var id := _key(target)
	if id=="" or element not in ["wood","water","fire","earth"]: return
	var gift_level := level(record)
	match element:
		"wood":
			var maximum := float(target.get("max_hp")) if "max_hp" in target else 10.0
			var gain := minf(removed,maximum*(0.0002+gift_level*0.001))
			session.vitals.heal(actor,gain)
		"fire":
			if target.hp>0:
				var old: Dictionary=burns.get(id,{})
				var damage := 1.0+gift_level*0.1
				burns[id]={"actor":str(old.get("actor",actor)) if float(old.get("damage",0))>damage else actor,"remaining":5.0,"tick":float(old.get("tick",0)),"damage":maxf(damage,float(old.get("damage",0)))}
		"water":
			var key := actor+":water"
			if target.hp>0 and float(cooldowns.get(key,0))<=0:
				cooldowns[key]=7.0
				var amount := minf(0.6,0.2+gift_level*0.01)
				var old: Dictionary=slows.get(id,{})
				slows[id]={"remaining":2.0,"amount":maxf(amount,float(old.get("amount",0)))}
				if "animal_id" in target: target.set_meta("magic_slow_rate",1.0-float(slows[id].amount))
	_pulse(actor,element,target.global_position)
func slow_rate(enemy_id: String) -> float:
	return 1.0-float(slows.get("enemy:"+enemy_id,{}).get("amount",0))
func _pulse(actor: String, element: String, at: Vector2) -> void:
	var key: String=magic.branches._area(actor,"enchant_rune",at,0.8,Vector2(24,24),Vector2.RIGHT)
	magic.branches.areas[key].element=element
	magic.branches._rebuild_visuals()
func advance(delta: float) -> void:
	var left := maxf(0,delta)
	while left>0.00001:
		var step := minf(left,0.5); left-=step; _step(step)
	if is_instance_valid(magic.branches): magic.branches._update_visuals()
func _step(delta: float) -> void:
	for key: String in cooldowns.keys():
		cooldowns[key]=maxf(0,float(cooldowns[key])-delta)
		if cooldowns[key]<=0.000001: cooldowns.erase(key)
	for id: String in burns.keys():
		var burn: Dictionary=burns[id]
		var target: Node=_target(id)
		if not is_instance_valid(target) or target.hp<=0: burns.erase(id); continue
		var span := minf(delta,float(burn.remaining))
		burn.remaining=maxf(0,float(burn.remaining)-span); burn.tick+=span
		while float(burn.tick)+0.000001>=1 and target.hp>0:
			burn.tick-=1
			magic.branches.note_combat(str(burn.actor))
			session.combat.apply_skill_damage(target,float(burn.damage),str(burn.actor))
		if burn.remaining<=0: burns.erase(id)
	for id: String in slows.keys():
		var slow: Dictionary=slows[id]
		slow.remaining=maxf(0,float(slow.remaining)-delta)
		var target: Node=_target(id)
		if is_instance_valid(target) and "animal_id" in target: target.set_meta("magic_slow_rate",1.0-float(slow.amount) if slow.remaining>0 else 1.0)
		if slow.remaining<=0 or not is_instance_valid(target) or target.hp<=0: slows.erase(id)
func export_state() -> Dictionary:
	return {"burns":burns.duplicate(true),"slows":slows.duplicate(true),"cooldowns":cooldowns.duplicate()}
func restore(data: Dictionary) -> void:
	burns.clear(); slows.clear(); cooldowns.clear()
	for field: String in ["burns","slows","cooldowns"]:
		if data.get(field,{}) is Dictionary: set(field,data.get(field,{}).duplicate(true))
	for animal: Node in session.livestock.animals: animal.set_meta("magic_slow_rate",1.0)
	for key: String in slows:
		var target: Node=_target(key)
		if is_instance_valid(target) and "animal_id" in target: target.set_meta("magic_slow_rate",1.0-float(slows[key].amount))
