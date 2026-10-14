# Simulates saved outgoing and returning magic-scissors paths with swept, obstructable impacts.
extends RefCounted
const Visual := preload("res://features/combat/scissor_visual.gd")
var combat: Node
var flights: Array=[]
var visuals: Array=[]
func launch(actor: Node, at: Vector2) -> bool:
	var s: Node=combat.session
	var id: String=actor.resident_id
	var before: Dictionary=s.inventory.export_data()
	var origin: Vector2=actor.global_position+Vector2(0,-8)
	var direction: Vector2=origin.direction_to(at)
	var record: Dictionary=s.magic.ensure(id).weapon_wear.duplicate(true)
	if not s.magic.consume_weapon(id): return false
	s.magic.branches.note_combat(id); s.magic.enchants.on_attack(id,record)
	flights.append({"actor":id,"at":[origin.x,origin.y],"direction":[direction.x,direction.y],"remaining":minf(80,origin.distance_to(at)+8),"phase":"out","record":record,"damage":s.magic.attack_damage(id)})
	refresh()
	if not s.production.commit(before,"魔法剪刀飞出，命中后自动飞回。"): return false
	combat.cooldown=1.0
	return true
func advance(delta: float) -> void:
	var s: Node=combat.session
	for i in range(flights.size()-1,-1,-1):
		if i>=flights.size(): continue
		var f: Dictionary=flights[i]
		var actor: Node=s.magic._actor(str(f.actor))
		if not is_instance_valid(actor): flights.remove_at(i); continue
		var from := Vector2(f.at[0],f.at[1])
		if f.phase=="return":
			var destination: Vector2=actor.global_position+Vector2(0,-8) if actor.room_id=="" else s.interiors.outdoor_position(actor)
			var span := 220.0*maxf(0,delta)
			if from.distance_to(destination)<=maxf(5,span): flights.remove_at(i); continue
			var to: Vector2=from.move_toward(destination,span)
			f.at=[to.x,to.y]
		else:
			var direction := Vector2(f.direction[0],f.direction[1])
			var length := minf(float(f.remaining),220.0*maxf(0,delta))
			var to := from+direction*length
			var query := PhysicsRayQueryParameters2D.create(from,to,1|4|8|16)
			var hit: Dictionary=s.world.get_world_2d().direct_space_state.intersect_ray(query)
			if s.magic.branches.barrier_blocks(from,to): f.phase="return"
			elif not hit.is_empty():
				var before: Dictionary=s.inventory.export_data()
				f.phase="return"; f.at=[hit.position.x,hit.position.y]
				if hit.collider.is_in_group("relic_targets") or hit.collider.has_meta("barrier_fixture"): combat.hit_structure(hit.collider,float(f.damage),str(f.actor))
				elif hit.collider.is_in_group("hostile_targets") or hit.collider.is_in_group("creature_targets"):
					if not combat.apply_weapon_hit(hit.collider,float(f.damage),str(f.actor),f.record): continue
					if not s.production.commit(before,"魔法剪刀命中并飞回。"): return
			else:
				f.at=[to.x,to.y]; f.remaining-=length
				if f.remaining<=0: f.phase="return"
	refresh()
func refresh() -> void:
	while visuals.size()>flights.size():
		var visual: Node=visuals.pop_back()
		if is_instance_valid(visual): visual.free()
	while visuals.size()<flights.size():
		var visual := Visual.new()
		combat.session.world.objects.add_child(visual); visuals.append(visual)
	for i in range(flights.size()):
		visuals[i].global_position=Vector2(flights[i].at[0],flights[i].at[1]); visuals[i].record=flights[i].record
func restore(data: Array) -> void:
	flights.clear()
	for f: Variant in data:
		if not f is Dictionary or not f.get("at",[]) is Array or f.at.size()!=2 or not is_instance_valid(combat.session.magic._actor(str(f.get("actor","")))): continue
		flights.append(f.duplicate(true))
	refresh()
