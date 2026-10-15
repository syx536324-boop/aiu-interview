# Owns finite tribal raid squads, chief orders and profession-consistent physical combat.
extends RefCounted
const Careers := preload("res://features/tribes/profession_catalog.gd")
const Arrow := preload("res://features/tribes/projectile.gd")
var runtime: Node
var raid_left := 300.0
var raid_index := 0
var raid_tribe := ""
var orders: Dictionary={}
var commanders: Dictionary={}
var anger := {"forest":false}
var cooldowns: Dictionary={}
func hostile(tribe: String) -> bool:
 # 声誉裁决优先：声望已越过外敌阈值的部落不再被当作敌人；归附流程优先于外部声誉。
 return runtime.relics.owner(tribe)!="player" and runtime.hostile(tribe)
func provoke(tribe: String) -> void:
 if tribe=="forest": anger.forest=true
func fighters(tribe: String) -> Array[String]:
 var result: Array[String]=[]
 for id: String in runtime.population.members:
  var r: Dictionary=runtime.population.members[id]; var actor: Node=runtime.population.node(id)
  if r.tribe==tribe and r.career in ["archer","charger"] and actor.hp>0 and r.child_left<=0: result.append(id)
 return result
func order(target: String) -> bool:
 var s: Node=runtime.session; var leader: Node=s.world.active_resident
 if leader.resident_id!="chief_priest" and not leader.resident_id.begins_with("colony_"): s._set_notice("只有村长可以指挥出征。"); return false
 if target not in ["forest","barbarian","yunye"] or runtime.relics.owner(target)=="player": return false
 var before: Dictionary=s.inventory.export_data()
 for tribe: String in ["home","forest","barbarian","yunye"]:
  if runtime.relics.owner(tribe)=="player":
   for id: String in fighters(tribe):
    orders[id]=target; commanders[id]=leader.resident_id
 return s.production.commit(before,"已命令本方弓箭手和战士进攻"+str(runtime.names[target])+"。")
func recall(tribe := "") -> void:
 for id: String in orders.keys():
  if (tribe=="" and runtime.population.friendly(id)) or (tribe!="" and runtime.population.members.get(id,{}).get("tribe","")==tribe): orders[id]="return"
func advance(delta: float) -> void:
 if runtime.relics.failed: return
 if runtime.population.current_player_level()>=5:
  raid_left-=delta
  var active := false
  for id: String in orders:
   if str(orders[id])!="return" and not runtime.population.friendly(id) and runtime.population.node(id).hp>0: active=true
  if not active and raid_left<=0:
   var options: Array[String]=[]
   for tribe: String in ["barbarian","yunye","forest"]:
    if hostile(tribe) and not fighters(tribe).is_empty(): options.append(tribe)
   if not options.is_empty():
    raid_tribe=options[raid_index%options.size()]; raid_index+=1
    var army := fighters(raid_tribe)
    for i in range(mini(4,army.size())): orders[army[i]]="home"
    runtime.session._set_notice(str(runtime.names[raid_tribe])+"正在组织进犯。")
   raid_left=300.0
 for id: String in runtime.population.members:
  var actor: Node=runtime.population.node(id)
  if not is_instance_valid(actor) or actor.hp<=0 or actor.room_id!="" or runtime.population.members[id].child_left>0: continue
  if runtime.romance.busy(actor.resident_id): continue
  cooldowns[id]=maxf(0,float(cooldowns.get(id,0))-delta)
  if is_instance_valid(runtime.guards) and runtime.guards.manages(actor): continue
  _act(id,actor,delta)
func _act(id: String, actor: Node, delta: float) -> void:
 var s: Node=runtime.session; var r: Dictionary=runtime.population.members[id]
 if s.magic.skills.rooted(id) or s.magic.branches.immobile(id): return
 var target: Node
 var destination := Vector2.ZERO
 var attacked_village := str(orders.get(id,""))
 if attacked_village=="return":
  if runtime.workers.move(actor,runtime.centers[str(r.tribe)]+Vector2(0,64),delta,32.0*(1.15 if r.career=="charger" and r.level==5 else 1.0)): orders.erase(id)
  return

 var player: Node=s.world.active_resident
 var ally: bool= runtime.population.friendly(id)
 # Members protect their holy ground and any nearby tribe member under attack.
 var occupied: Dictionary=s.world.home_data(player.room_id)
 var in_house: bool=occupied.get("built",false) and not occupied.get("ruined",false) and not occupied.get("building",false)
 if not ally and (player.room_id=="" or in_house) and not player.dead:
  var holy: Vector2=runtime.centers[str(r.tribe)]
  var player_at: Vector2=occupied.door if in_house else player.position
  actor.pursuit=maxf(0,actor.pursuit-delta)
  var defend: bool= (str(r.tribe)!="forest" and player_at.distance_to(holy)<210) or actor.pursuit>0
  if defend or (hostile(str(r.tribe)) and actor.position.distance_to(player_at)<=210):
   if in_house:
    for body: Node in s.construction.nodes[player.room_id].find_children("*","StaticBody2D",true,false):
     if body.has_meta("constructed_home"): target=body; break
   else: target=player
 if ally:
  target=runtime.encounters.direct_threat(actor)
  var nearest: float=actor.position.distance_to(target.position) if is_instance_valid(target) else 160.0
  for other_id: String in runtime.population.members:
   if runtime.population.friendly(other_id): continue
   var other: Node=runtime.population.node(other_id)
   if other.hp>0 and other.room_id=="" and (hostile(str(other.tribe)) or str(other.tribe)==attacked_village) and actor.position.distance_to(other.position)<nearest and runtime.encounters.visible(actor,other):
    target=other; nearest=actor.position.distance_to(other.position)
 if is_instance_valid(target): destination=target.global_position
 elif attacked_village!="" and runtime.relics.states[attacked_village].hp>0:
  target=runtime.relics.visuals[attacked_village].body; destination=runtime.relics.visuals[attacked_village].position
 elif attacked_village!="": orders.erase(id); return
 else:
  if ally: runtime.routine.advance_actor(id,actor,delta)
  return
 if ally and r.career in ["civilian","farmer","miner"]:
  var record: Dictionary=runtime.guards.npc(id)
  runtime.guards._change(actor,record,"retreat")
  runtime.guards._act_retreat(actor,record,delta,32.0*s.magic.branches.speed_rate(id),{"valid":true,"at":target.global_position,"home":"","indoors":false,"actor":target})
  return
 var weapon := Careers.weapon(str(r.career),int(r.level))
 var ranged: bool= weapon=="bow" or r.career=="chief"
 var reach: float= s.combat.Gear.attack_range("bow") if weapon=="bow" else (200.0 if r.career=="chief" else 0.0)
 if not ranged: reach = (30.0 if weapon!="" else 13.0)
 if ranged and (s.world.Layout.PLATEAU.has_point(actor.position) or s.world.Layout.MOUNTAINS_EAST.has_point(actor.position)): reach*=0.7
 var gap: float= actor.position.distance_to(destination)
 if gap>reach:
  # Do not repeatedly search an unreachable full map while the mountain passes remain closed.
  if actor.position.y<0 and destination.y>=0 and s.world.cliff_open.is_empty() and r.tribe=="barbarian": return
  if actor.position.x>2400 and destination.x<2400 and s.world.ridge_open.is_empty(): return
  if ally and r.career not in ["archer","charger","chief"]: return
  var speed: float= 32.0*(1.15 if r.career=="charger" and r.level==5 else 1.0)*s.magic.branches.speed_rate(id)
  runtime.workers.move(actor,destination,delta,speed,"war"); return
 if cooldowns[id]>0: return
 if ally and r.career in ["archer","charger"] and ("enemy_id" in target or "resident_id" in target):
  var record: Dictionary=runtime.guards.npc(id)
  record.target_id=runtime.encounters.key(target)
  record.skill_cd=maxf(0,float(record.skill_cd)-delta)
  if runtime.guards._try_skill(actor,record,{"indoors":false}): return
 strike(id,actor,target)

# All NPC weapon attacks use the same reach, one-second interval, ammunition and
# swept projectile path, including local guards managed by the new state machine.
func strike(id: String, actor: Node, target: Node) -> bool:
 if not is_instance_valid(actor) or not is_instance_valid(target) or actor.hp<=0: return false
 if float(cooldowns.get(id,0))>0: return false
 var s: Node=runtime.session
 var r: Dictionary=runtime.population.members.get(id,{})
 if r.is_empty(): return false
 var ally: bool=runtime.population.friendly(id)
 var weapon := Careers.weapon(str(r.career),int(r.level))
 var ranged: bool=weapon=="bow" or r.career=="chief"
 var reach: float=actor.attack_reach()
 var destination: Vector2=target.global_position
 if actor.global_position.distance_to(destination)>reach: return false
 if not actor.is_inside_tree(): return false # Parked squads move logically; impacts require active physical collisions.
 if target.is_in_group("relic_targets"):
  if runtime.relics.owner(str(target.get_meta("tribe")))==("player" if ally else str(r.tribe)): return false
 var query := PhysicsRayQueryParameters2D.create(actor.global_position,destination,1|2|8|16,[actor.get_rid()])
 var obstruction: Dictionary=actor.get_world_2d().direct_space_state.intersect_ray(query) if actor.is_inside_tree() else {}
 if actor.is_inside_tree() and not obstruction.is_empty() and obstruction.collider!=target:
  if obstruction.collider.has_meta("barrier_fixture"): target=obstruction.collider; destination=target.global_position
  else: return false
 if target.has_meta("constructed_home") and r.career=="chief":
  damage_target(target,10,str(r.tribe),id); cooldowns[id]=2.0; return true
 if ranged:
  if weapon=="bow" and not s.inventory.exchange(actor.resident_id,{"arrow":1},{}): return false
  var arrow := Arrow.new(); arrow.runtime=runtime; arrow.attacker=id; arrow.tribe=str(r.tribe); arrow.damage=Careers.damage(str(r.career),int(r.level)) if r.career!="chief" else 1.0
  arrow.position=actor.position; arrow.direction=actor.position.direction_to(destination); arrow.left=reach; arrow.excluded=[actor.get_rid()]
  s.world.objects.add_child(arrow)
 else:
  var raw: float=Careers.damage(str(r.career),int(r.level)) if weapon!="" else 1.0
  if is_instance_valid(runtime.npc_skills): raw+=runtime.npc_skills.consume_attack_bonus(id)
  damage_target(target,raw,str(r.tribe),id)
 cooldowns[id]=1.0
 return true
func damage_target(target: Node, raw: float, tribe: String, attacker: String) -> void:
 if not is_instance_valid(target) or raw<=0: return
 if target.has_meta("constructed_home"):
  var element: String=str(runtime.elements.get(tribe,"")) if runtime.population.members.get(attacker,{}).get("career","")=="chief" else ""
  runtime.session.construction.hit(str(target.get_meta("constructed_home")),raw,false,element); return
 if target.has_meta("barrier_fixture"):
  var fixture: Node=target.get_meta("barrier_fixture")
  if fixture.has_method("damage"): fixture.damage(raw); return
  fixture.hp=maxf(0,fixture.hp-raw)
  if fixture.hp<=0: runtime.session.grounds.remove_fixture(fixture)
  else: fixture.queue_redraw()
  return
 if target.is_in_group("relic_targets"):
  var name := str(target.get_meta("tribe"))
  if runtime.relics.owner(name)==runtime.relics.owner(tribe): return
  var source: Node=runtime.encounters.actor(attacker)
  if runtime.encounters.player_source(attacker)!="": runtime.relic_attack_event(name)
  runtime.encounters.record_hit(target,source,raw)
  runtime.relics.hit(name,raw,attacker,runtime.relics.owner(name)=="player"); return
 if "enemy_id" in target:
  if runtime.relics.owner(target.tribe)==runtime.relics.owner(tribe) or target.hp<=0: return
  provoke(str(target.tribe))
  var dealt: float=runtime.session.combat._final_hostile_damage(attacker,target,raw)
  var before: float=target.hp
  target.hp=maxf(0,target.hp-dealt)
  runtime.session.combat._note_hostile_damage(target,attacker,dealt,before)
  target.pursuit=6; target.refresh(); return
 if "resident_id" in target and runtime.relics.owner(tribe)!="player":
  var caster: Node=runtime.population.node(attacker)
  runtime.session.combat.apply_npc_damage(caster,target.resident_id,raw,{"kind":"ranged" if runtime.population.members.get(attacker,{}).get("career","")=="archer" else "melee"})
func export_state() -> Dictionary: return {"raid_left":raid_left,"raid_index":raid_index,"raid_tribe":raid_tribe,"orders":orders.duplicate(),"commanders":commanders.duplicate(),"anger":anger.duplicate(),"cooldowns":cooldowns.duplicate()}
func restore(data: Dictionary) -> void:
 raid_left=clampf(float(data.get("raid_left",300)),0,300); raid_index=maxi(0,int(data.get("raid_index",0))); raid_tribe=str(data.get("raid_tribe","")); orders=data.get("orders",{}).duplicate(); commanders=data.get("commanders",{}).duplicate(); anger=data.get("anger",{"forest":false}).duplicate(); cooldowns=data.get("cooldowns",{}).duplicate()
