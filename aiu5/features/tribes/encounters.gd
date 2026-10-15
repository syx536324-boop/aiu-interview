# Records actual local combat, player-command attribution and aid; guards consume explicit visible threats.
extends RefCounted

var runtime: Node
var contacts: Dictionary = {}
var battles: Dictionary = {}
var next_battle := 0

func key(actor: Node) -> String:
	if not is_instance_valid(actor): return ""
	if "enemy_id" in actor: return "npc:"+str(actor.enemy_id)
	if actor.has_meta("tribe"): return "relic:"+str(actor.get_meta("tribe"))
	return str(actor.resident_id) if "resident_id" in actor else ""

func actor(id: String) -> Node:
	if id.begins_with("relic:"):
		var visual: Node=runtime.relics.visuals.get(id.trim_prefix("relic:"))
		return visual.body if is_instance_valid(visual) else null
	if id.begins_with("npc:"): return runtime.session.combat.enemies.get(id.trim_prefix("npc:"))
	if runtime.session.combat.enemies.has(id): return runtime.session.combat.enemies[id]
	return runtime.session.magic._actor(id)

func tribe_of(node: Node) -> String:
	if not is_instance_valid(node): return ""
	if "tribe" in node: return str(node.tribe)
	if node.has_meta("tribe"): return str(node.get_meta("tribe"))
	return "home" if "resident_id" in node else ""

func player_source(id: String) -> String:
	var source: Node=actor(id)
	if not is_instance_valid(source): return ""
	if "enemy_id" in source:
		if not runtime.population.friendly(source.enemy_id): return ""
		return str(runtime.war.commanders.get(source.enemy_id,runtime.session.world.active_resident.resident_id))
	return str(source.resident_id) if "can_control" in source and source.can_control else ""

func record_hit(victim: Node, source: Node, amount: float) -> void:
	if amount<=0 or not is_instance_valid(victim) or not is_instance_valid(source): return
	var defending := tribe_of(victim)
	var attacking := tribe_of(source)
	var battle_key := defending+">"+attacking
	if not battles.has(battle_key):
		next_battle+=1
		battles[battle_key]={"id":next_battle,"left":10.0,"rewarded":false}
	battles[battle_key].left=10.0
	contacts[key(victim)+"|"+key(source)]={"victim":key(victim),"attacker":key(source),"tribe":defending,"left":10.0,"battle":battle_key}

func advance(delta: float) -> void:
	for entries: Dictionary in [contacts,battles]:
		for id: String in entries.keys():
			entries[id].left=maxf(0,float(entries[id].left)-delta)
			if entries[id].left<=0: entries.erase(id)

func in_combat(node: Node) -> bool:
	for contact: Dictionary in contacts.values():
		if contact.victim==key(node) and float(contact.left)>0: return true
	return false

func direct_threat(node: Node) -> Node:
	for contact: Dictionary in contacts.values():
		if contact.victim!=key(node): continue
		var threat: Node=actor(contact.attacker)
		if is_instance_valid(threat) and tribe_of(threat)!=tribe_of(node) and visible(node,threat): return threat
	return null

func witnesses(victim: Node, source: Node) -> Array[String]:
	var result: Array[String]=[]
	for id: String in runtime.population.members:
		var witness: Node=runtime.population.node(id)
		if not is_instance_valid(witness) or witness==victim or witness.hp<=0 or witness.room_id!=victim.room_id: continue
		if witness.tribe!=victim.tribe or witness.global_position.distance_to(victim.global_position)>160: continue
		if visible(witness,source): result.append(id)
	return result

func visible(observer: Node, target: Node) -> bool:
	if not is_instance_valid(observer) or not is_instance_valid(target) or not observer.is_inside_tree() or not target.is_inside_tree(): return false
	if "room_id" in target and observer.room_id!=target.room_id: return false
	var query := PhysicsRayQueryParameters2D.create(observer.global_position,target.global_position,1|4,[observer.get_rid()])
	return observer.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func observe_damage(victim: Node, source_id: String, amount: float, hp_before: float) -> void:
	var source: Node=actor(source_id)
	record_hit(victim,source,amount)
	var player := player_source(source_id)
	if player=="" or amount<=0: return
	_aid_for_hit(victim,player)
	if victim.tribe in ["raider","home"] or runtime.relics.owner(victim.tribe)=="player": return
	# Autonomous allied defense is not an attack ordered by the player.
	if "enemy_id" in source and str(runtime.war.orders.get(source.enemy_id,""))!=str(victim.tribe): return
	var observed := witnesses(victim,source)
	if victim.hp<=0:
		observed=observed.filter(func(id: String)->bool:return "npc:"+id not in runtime.kin_of(victim.enemy_id))
	if runtime.note_conflict(victim.tribe,victim.enemy_id):
		runtime.relation.remember(victim.enemy_id,"attacked",player,2)
		for id: String in observed: runtime.relation.remember(id,"witness_attack",player,1)
	if hp_before>0 and victim.hp<=0: runtime.register_death(victim.tribe,victim.enemy_id,player,observed,true)

func _aid_for_hit(invader: Node, player: String) -> void:
	for contact: Dictionary in contacts.values():
		if contact.attacker!=key(invader) or contact.tribe not in runtime.START_STANDING: continue
		if runtime.relics.owner(contact.tribe)=="player": continue
		var battle: Dictionary=battles.get(contact.battle,{})
		if battle.is_empty() or battle.rewarded: continue
		if runtime.aid_event(contact.tribe):
			battle.rewarded=true
			var helped: Node=actor(contact.victim)
			if is_instance_valid(helped) and "enemy_id" in helped: runtime.relation.remember(helped.enemy_id,"aided",player,1)

func context_for(guard: Node, fallback: Dictionary) -> Dictionary:
	var best := fallback
	var distance := 161.0
	for contact: Dictionary in contacts.values():
		var victim: Node=actor(contact.victim)
		var threat: Node=actor(contact.attacker)
		if not is_instance_valid(victim) or not is_instance_valid(threat) or threat==guard: continue
		if "hp" in threat and threat.hp<=0: continue
		var own: bool=contact.tribe==guard.tribe
		var aiding: bool=runtime.attitude(guard.tribe)=="trust" and runtime.relics.owner(contact.tribe)=="player"
		if not own and not aiding: continue
		if tribe_of(threat)==guard.tribe: continue
		if guard.global_position.distance_to(victim.global_position)>160 or not _support_slot(guard,victim): continue
		var gap: float=guard.global_position.distance_to(threat.global_position)
		if gap>distance or not visible(guard,threat): continue
		distance=gap
		best={"valid":true,"at":threat.global_position,"home":"","indoors":false,"actor":threat,
			"target_id":key(threat),"forced_hostile":true}
	return best

func _support_slot(guard: Node, victim: Node) -> bool:
	if guard==victim: return true
	var closer := 0
	for id: String in runtime.population.members:
		var other: Node=runtime.population.node(id)
		if not is_instance_valid(other) or other==victim or other.hp<=0 or other.tribe!=guard.tribe or other.role not in ["charger","archer","chief"]: continue
		if other.global_position.distance_to(victim.global_position)>160: continue
		var a: float=other.global_position.distance_squared_to(victim.global_position)
		var b: float=guard.global_position.distance_squared_to(victim.global_position)
		if a<b or (is_equal_approx(a,b) and str(other.enemy_id)<str(guard.enemy_id)): closer+=1
	return closer<3

func export_state() -> Dictionary:
	return {"contacts":contacts.duplicate(true),"battles":battles.duplicate(true),"next_battle":next_battle}

func restore(data: Dictionary) -> void:
	contacts=data.get("contacts",{}).duplicate(true)
	battles=data.get("battles",{}).duplicate(true)
	next_battle=maxi(0,int(data.get("next_battle",0)))
	for id: String in contacts.keys():
		var c: Dictionary=contacts[id]
		if not is_instance_valid(actor(str(c.get("victim","")))) or not is_instance_valid(actor(str(c.get("attacker","")))): contacts.erase(id)
