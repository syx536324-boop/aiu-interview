# Composes tribal domains and exposes interaction snapshots/actions to the existing presentation layer.
extends Node
const Encounters := preload("res://features/tribes/encounters.gd")
const Population := preload("res://features/tribes/population.gd")
const Workers := preload("res://features/tribes/workers.gd")
const Routine := preload("res://features/tribes/friendly_routine.gd")
const War := preload("res://features/tribes/war.gd")
const Relics := preload("res://features/tribes/relics.gd")
const Settlements := preload("res://features/tribes/settlements.gd")
const Romance := preload("res://features/romance/romance.gd")
const Careers := preload("res://features/tribes/profession_catalog.gd")
const RelationMemory := preload("res://features/tribes/relation_memory.gd")
var session: Node
var encounters := Encounters.new()
var population := Population.new()
var workers := Workers.new()
var routine := Routine.new()
var war := War.new()
var relics := Relics.new()
var settlements := Settlements.new()
var romance := Romance.new()
var relation := RelationMemory.new()
# 未归附部落成员的日常行为与招式运行域，由组合入口注入。
var guards: Node
var npc_skills: Node
# 部落声誉：未归附部落对玩家村落的长期态度，-100～100。
const START_STANDING := {"forest": 0, "barbarian": -50, "yunye": -50}
const GIFT_STANDING := 1
const GIFT_DAILY_LIMIT := 5
const AID_STANDING := 10
const THEFT_STANDING := -10
const ATTACK_STANDING := -20
const KILL_STANDING := -35
const RELIC_STANDING := -100
const ATTACK_WINDOW := 60.0
const AID_INTERVAL := 300.0
const RELIC_ZONE := 64.0
const ATTITUDE_NAMES := {"trust":"信任", "friendly":"友好", "neutral":"中立", "alert":"警戒", "hostile":"敌对"}
var standing_points: Dictionary = {}
var gift_standing: Dictionary = {}
var gift_day: Dictionary = {}
var aid_cooldown: Dictionary = {}
var conflict_time: Dictionary = {}
var death_settled: Dictionary = {}
var clock := 0.0
var migrated := false
var mine_visited := false
var mine_marked := false
var dialog_kind := ""
var dialog_id := ""
var wedding_partner := ""
const centers := {"home":Vector2(548,310),"forest":Vector2(-1200,790),"barbarian":Vector2(1200,-760),"yunye":Vector2(3300,-820)}
const names := {"home":"赤沙村","forest":"青木村","barbarian":"野蛮部落","yunye":"云野部落"}
const elements := {"home":"earth","forest":"wood","barbarian":"fire","yunye":"earth"}
var defeat_panel: CanvasLayer
func start(controller: Node) -> void:
 session=controller; workers.runtime=self; war.runtime=self; population.runtime=self; settlements.runtime=self; romance.runtime=self; romance.weddings.romance=romance
 routine.runtime=self; workers.movement.runtime=self; encounters.runtime=self
 session.inventory.transfer_commit=complete_storage_transfer
 relation.start(self)
 reset_standing()
 if is_instance_valid(guards): guards.start(self)
 if is_instance_valid(npc_skills): npc_skills.start(self, guards)
 relics.start(self); population.start(self)
 for tribe: String in ["forest","barbarian","yunye"]: settlements.match_population(tribe,population.count(tribe))
 refresh_points()
func advance(delta: float) -> void:
 if relics.failed: return
 clock += maxf(0.0, delta)
 relation.advance(delta); encounters.advance(delta)
 if session.world.active_resident.room_id=="mine": mine_visited=true
 workers.movement.begin_step()
 population.advance(delta); relics.advance(delta); romance.advance(delta)
 if is_instance_valid(session.monsters): session.monsters.respond(delta)
 workers.advance(delta); war.advance(delta)
 if is_instance_valid(guards): guards.advance(delta)
 if is_instance_valid(npc_skills): npc_skills.advance(delta)
 relation.day = current_day()
 refresh_points()

# 游戏日以游戏内昼夜计时为准，暂停与离线都不推进每日赠礼额度。
func current_day() -> int:
 if not is_instance_valid(session.day_night): return relation.day
 return int(session.day_night.snapshot().get("day", relation.day))

# 每进入新游戏日清空赠礼额度；读取时先同步，避免额度永久为0。
func sync_gift_day() -> void:
 var today := current_day()
 if today != int(relation.day):
  relation.day = today
  for tribe: String in gift_standing.keys(): gift_standing[tribe] = 0


# 首版初始声誉：森林中立0，野蛮与云野敌对-50；旧档缺字段时补同样的默认值。
func reset_standing() -> void:
 for tribe: String in ["forest","barbarian","yunye"]:
  if not standing_points.has(tribe): standing_points[tribe] = int(START_STANDING.get(tribe, 0))
  gift_standing[tribe] = int(gift_standing.get(tribe, 0))
  gift_day[tribe] = int(gift_day.get(tribe, 0))

func now() -> float: return clock

func standing(tribe: String) -> int:
 return clampi(int(standing_points.get(tribe, START_STANDING.get(tribe, 0))), -100, 100)

func attitude(tribe: String) -> String:
 var value := standing(tribe)
 if value >= 60: return "trust"
 if value >= 20: return "friendly"
 if value >= -19: return "neutral"
 if value >= -49: return "alert"
 return "hostile"

func display_attitude(tribe: String) -> String:
 return str(ATTITUDE_NAMES.get(attitude(tribe), "中立"))

# 未归附且声誉落在敌对区间才主动攻击；归附后一律按本方规则。
func hostile(tribe: String) -> bool:
 return relics.owner(tribe) != "player" and attitude(tribe) == "hostile"

func alert(tribe: String) -> bool:
 return relics.owner(tribe) != "player" and attitude(tribe) == "alert"

# 行为裁决：是否允许靠近重要区域（信任、友好或本方）。
func trusted(tribe: String) -> bool:
 return relics.owner(tribe) == "player" or attitude(tribe) in ["trust", "friendly"]

func zone(tribe: String) -> Rect2:
 if tribe == "home": return session.world.Layout.HOME_LIT
 return session.combat.TRIBES.get(tribe, {}).get("area", Rect2())

func relic_zone(tribe: String) -> float:
 return RELIC_ZONE

func relic_distance(tribe: String, at: Vector2) -> float:
 var visual: Variant = relics.visuals.get(tribe, null)
 return at.distance_to(visual.global_position) if is_instance_valid(visual) else INF

func add_standing(tribe: String, amount: int) -> void:
 if not standing_points.has(tribe): standing_points[tribe] = int(START_STANDING.get(tribe, 0))
 standing_points[tribe] = clampi(standing(tribe) + amount, -100, 100)

func set_standing(tribe: String, value: int) -> void:
 if not standing_points.has(tribe): standing_points[tribe] = int(START_STANDING.get(tribe, 0))
 standing_points[tribe] = clampi(value, -100, 100)

# 声望已经越过外敌阈值后不再主动攻击；用于归附/和解后的目标清理。
func reputation_forgives(tribe: String) -> bool:
 var threshold := 20 if tribe in ["barbarian", "yunye"] else -19
 return standing(tribe) >= threshold

func gifting_left(tribe: String) -> int:
 sync_gift_day()
 return maxi(0, GIFT_DAILY_LIMIT - int(gift_standing.get(tribe, 0)))

func population_id(target_id: String) -> String:
 return target_id.trim_prefix("npc:")

# 正常赠送一个面包：个人好感+5，部落声誉+1，每游戏日每部落最多+5。
# 婚礼分面包、合成、开箱搬运与自动补给都不经过本入口，因此不会被当成正常赠礼。
func gift_bread(target_id: String) -> bool:
 var id := population_id(target_id)
 if not population.members.has(id): return false
 var member: Node = population.node(id)
 if not is_instance_valid(member) or member.hp <= 0: return false
 var tribe := str(population.members[id].tribe)
 if relics.owner(tribe) == "player": return false
 if gifting_left(tribe) <= 0: session._set_notice("今天已经送过足够的面包，明日再来。"); return false
 var source: String = session.world.active_resident.resident_id
 var target := "npc:" + id
 var before: Dictionary = session.inventory.export_data()
 if not session.inventory.exchange(source,{"bread":1},{}) or not session.inventory.exchange(target,{},{"bread":1}):
  session.inventory.apply_data(before)
  session._set_notice("背包中没有面包，或对方已经装满。")
  return false
 register_gift(tribe)
 romance.shift_liking(source, target, 5)
 relation.remember(id, "gift_bread", source, 1)
 return session.production.commit(before,"送出面包：个人好感＋5，%s声誉＋1（本日剩%d）。" % [str(names.get(tribe, tribe)), gifting_left(tribe)])

func bread_choice(target_id: String) -> Dictionary:
 var id := population_id(target_id)
 if not population.members.has(id): return {}
 var tribe := str(population.members[id].tribe)
 if relics.owner(tribe) == "player": return {}
 return {"id":"tribe:bread","name":"送面包（声誉＋1，本日剩%d）" % gifting_left(tribe),
  "detail":"个人好感＋5；本日该部落赠礼声誉上限5。","free":gifting_left(tribe) <= 0}

func register_gift(tribe: String) -> bool:
 sync_gift_day()
 if tribe == "" or not standing_points.has(tribe): return false
 if gifting_left(tribe) <= 0: return false
 gift_standing[tribe] = int(gift_standing.get(tribe, 0)) + 1
 add_standing(tribe, GIFT_STANDING)
 return true

func aid_event(tribe: String) -> bool:
 if not standing_points.has(tribe) or float(aid_cooldown.get(tribe, -AID_INTERVAL)) > clock - AID_INTERVAL: return false
 aid_cooldown[tribe] = clock
 add_standing(tribe, AID_STANDING)
 session._set_notice(str(names.get(tribe, tribe)) + "记住了你的援助。")
 return true

# Called by inventory only after an actual transfer; save failure rolls back both
# the item movement and standing/memory through the ordinary production transaction.
func complete_storage_transfer(before: Dictionary, container: String, removed: bool) -> bool:
 var tribe := ""
 var actor: Node=session.world.active_resident
 if removed and container!="" and not container.begins_with("npc:") and container!="altar:display":
  var room: Node=session.interiors.rooms.get(actor.room_id)
  if is_instance_valid(room):
   for fixture: Node in room.fixtures:
    if fixture.fixture_id==container and not fixture.gift_origin.is_empty(): return session.production.commit(before,"")
  var home: Dictionary=session.world.home_data(actor.room_id)
  tribe=str(home.get("tribe",""))
  if tribe=="":
   for name: String in START_STANDING:
    if str(home.get("id","")).begins_with(name+"_"): tribe=name
 if tribe not in START_STANDING or relics.owner(tribe)=="player":
  return session.production.commit(before,"")
 var witness := ""
 var doorway: Vector2=session.world.home_data(actor.room_id).get("door",actor.global_position)
 for id: String in population.members:
  var npc: Node=population.node(id)
  if str(population.members[id].tribe)==tribe and is_instance_valid(npc) and npc.hp>0 and npc.global_position.distance_to(doorway)<=160:
   witness=id; break
 theft_event(tribe,witness)
 return session.production.commit(before,"取用了未归附部落的箱柜物品：声誉−10。"+("有人发现了这次偷窃。" if witness!="" else ""))

func theft_event(tribe: String, witness_id := "") -> bool:
 if not standing_points.has(tribe): return false
 add_standing(tribe, THEFT_STANDING)
 if witness_id != "":
  relation.remember(witness_id, "saw_theft", session.world.active_resident.resident_id)
  guards.report_theft(tribe,witness_id)
 return true

func relic_attack_event(tribe: String) -> void:
 if not standing_points.has(tribe): return
 set_standing(tribe, RELIC_STANDING)

# 同一冲突中同一受害者60在线秒内只结算一次攻击声誉。
func note_conflict(tribe: String, npc_id: String) -> bool:
 if not standing_points.has(tribe): return false
 var key := tribe + ":" + npc_id
 if float(conflict_time.get(key, -ATTACK_WINDOW)) > clock - ATTACK_WINDOW: return false
 conflict_time[key] = clock
 add_standing(tribe, ATTACK_STANDING)
 return true

# 杀死村民：按死亡事件额外结算一次；受害者亲属与目击者的好感在记忆中处理。
func register_death(tribe: String, npc_id: String, actor_id: String, witnesses: Array = [], already_hurt := false) -> bool:
 var key := tribe + ":" + npc_id
 if death_settled.has(key): return false
 death_settled[key] = true
 if standing_points.has(tribe): add_standing(tribe, KILL_STANDING)
 relation.remember(npc_id, "killed_villager", actor_id, 2,"",not already_hurt)
 for kin: String in kin_of(npc_id):
  if kin!=actor_id and kin!="npc:"+population_id(actor_id): relation.remember(kin, "killed_kin", actor_id, 2)
 for witness: String in witnesses:
  if witness != npc_id and "npc:"+str(witness) not in kin_of(npc_id): relation.remember(witness,"witness_attack",actor_id,1,"",not already_hurt)
 return true

# 只读取既有的婚恋数据，不临时为无关系NPC编造亲属。
func kin_of(npc_id: String) -> Array:
 var id := population_id(npc_id)
 var result: Array=romance.partners("npc:"+id)
 for parent: String in population.members.get(id,{}).get("parents",[]):
  if is_instance_valid(romance.actor(parent)) and parent not in result: result.append(parent)
 for child: String in population.members:
  if float(population.members[child].child_left)>0: continue
  if "npc:"+id in population.members[child].get("parents",[]) and "npc:"+child not in result: result.append("npc:"+child)
 return result

func clear_conflict(tribe: String, npc_id: String) -> void:
 conflict_time.erase(tribe + ":" + npc_id)
func refresh_points() -> void:
 for id: String in population.members:
  var actor: Node=population.node(id)
  if not is_instance_valid(actor) or actor.hp<=0: session.world.points.erase("npcunit:"+id); continue
  var r: Dictionary=population.members[id]
  var text := "幼童" if float(r.child_left)>0 else str(Careers.LABELS[r.career])
  if not population.friendly(id): text+=" · "+display_attitude(str(r.tribe))
  if actor.is_inside_tree(): actor.queue_redraw()
  session.world.points["npcunit:"+id]={"position":actor.position,"radius":20.0,"label":str(r.name)+" · "+text,"action":"交谈 / 升级 / 背包" if population.friendly(id) else "其他部落成员","source":actor}
func interact() -> bool:
 var actor: Node=session.world.active_resident
 if actor.room_id!="":
  var home: Dictionary=session.world.home_data(actor.room_id)
  if romance.clinic(home) and romance.pregnancies.has(actor.resident_id) and romance.pregnancies[actor.resident_id].remaining<=0: open("delivery",actor.resident_id); return true
  if romance.partners(actor.resident_id).any(func(id: String)->bool:return actor.room_id==str(romance.marriage(actor.resident_id,id).house)):
   for f: Node in session.interiors.rooms[actor.room_id].fixtures:
    if f.kind=="bed" and actor.position.distance_to(f.position)<=38: open("marriage_bed",actor.resident_id); return true
  for id: String in population.members:
   var npc: Node=population.node(id)
   if is_instance_valid(npc) and npc.hp>0 and npc.room_id==actor.room_id and npc.position.distance_to(actor.position)<25: open("npc",id); return true
  for other: Node in session.world.controllable:
   if other!=actor and not other.dead and other.room_id==actor.room_id and other.position.distance_to(actor.position)<25: open("person",other.resident_id); return true
  return false
 for home: Dictionary in session.world.homes+session.world.extra_homes.values():
  if home.get("id","")!="mine" and home.get("door",Vector2.INF).distance_to(actor.position)<8: return false
 var closest := ""; var kind := ""; var gap := 25.0
 for id: String in population.members:
  var other: Node=population.node(id)
  if other.hp>0 and other.room_id=="" and actor.position.distance_to(other.position)<gap:
   closest=id; kind="npc"; gap=actor.position.distance_to(other.position)
 for other: Node in session.world.controllable:
  if other!=actor and not other.dead and other.room_id=="" and actor.position.distance_to(other.position)<gap:
   closest=other.resident_id; kind="person"; gap=actor.position.distance_to(other.position)
 for tribe: String in relics.visuals:
  if actor.position.distance_to(relics.visuals[tribe].position)<gap:
   closest=tribe; kind="relic"; gap=actor.position.distance_to(relics.visuals[tribe].position)
 for f: Node in session.grounds.fixtures:
  if f.kind=="fence_gate" and actor.position.distance_to(f.position)<gap:
   var before: Dictionary=session.inventory.export_data(); f.gate_open=not f.gate_open; f.queue_redraw(); session.grounds._collider(f)
   session.production.commit(before,"栅栏门已打开。" if f.gate_open else "栅栏门已关闭。"); return true
 if kind!="": open(kind,closest); return true
 if actor.position.distance_to(session.mining.DOOR)<26: open("mine",""); return true
 for animal: Node in session.livestock.animals:
  if animal.hp>0 and animal.species in ["pig","cow","sheep"] and actor.position.distance_to(animal.position)<24:
   open("animal",animal.animal_id); return true
 return false
func open(kind: String, id: String) -> void:
 if kind=="npc" and population.friendly(id) and population.members.has(id) and float(population.members[id].get("child_left",0))<=0 and is_instance_valid(session.onboarding):session.onboarding.record_feature("npc")
 dialog_kind=kind; dialog_id=id; session.production.mode="tribes"; session.production.opened=true; session.production.fixture=null
 session.refresh_interface()
func choice(id: String, title: String, detail: String, enabled := true, cost: Dictionary={}) -> Dictionary:
 var parts: Array[String]=[]
 var actor_id: String=session.world.active_resident.resident_id
 for item: String in cost:
  var have := 0
  for slot: Dictionary in session.inventory.ensure_bag(actor_id):
   if slot.get("item","")==item: have+=int(slot.count)
  parts.append("%s ×%d / %d%s"%[session.inventory.Catalog.ITEMS[item].name,cost[item],have,"（缺少）" if have<int(cost[item]) else ""])
 return {"id":id,"name":title,"detail":detail+("\n\n所需物品（需要 / 拥有）：\n"+"\n".join(parts) if not parts.is_empty() else ""),"category":"all","enabled":enabled and session.inventory.exchange(actor_id,cost,{},false)}
func snapshot() -> Dictionary:
 var choices: Array=[]; var title := "部落互动"
 if dialog_kind=="npc" and population.members.has(dialog_id):
  var r: Dictionary=population.members[dialog_id]; var unit: Node=population.node(dialog_id)
  title=str(r.name)+" · "+str(Careers.LABELS[r.career])+" Lv."+str(r.level)
  var partner_names: Array[String]=[]
  for partner: String in romance.partners(unit.resident_id): partner_names.append(romance.name(partner))
  var tribe := str(r.tribe)
  var attitude_line := "声誉%d／100 · %s" % [standing(tribe), display_attitude(tribe)]
  var memory_line := relation.line_for(dialog_id)
  if memory_line != "": attitude_line += "\n" + memory_line
  choices.append(choice("talk","交谈","生命%.0f／%.0f · %s\n%s\n%s · 个人好感%d／100\n配偶：%s\n%s"%[unit.hp,unit.max_hp,"女性" if r.gender=="female" else "男性",attitude_line,"尚未归附，不能升级或取背包。" if not population.friendly(dialog_id) else "本方成员 · "+str(workers.job(dialog_id).status),relation.liking(session.world.active_resident.resident_id,dialog_id),"、".join(partner_names) if not partner_names.is_empty() else "暂无",romance.status(unit.resident_id)]))
  if not population.friendly(dialog_id):
   choices.append(choice("tribe:bread","送面包（个人好感＋5，声誉＋1）","本日该部落赠礼声誉剩余%d／5。婚宴分面包与合成不会计入此额度。" % gifting_left(tribe),true,{"bread":1}))
  if population.friendly(dialog_id):
   choices.append(choice("bag","打开背包（9格）","可取出工作产物，放入种子、水桶和箭支作为补给。"))
   if float(r.child_left)>0: choices.append(choice("child","幼童成长中","%.1f在线秒后成年，成年才能升级。"%float(r.child_left),false))
   else:
    for option: Dictionary in Careers.upgrades(r): choices.append(choice("upgrade:"+str(option.career),"升级：%d级%s"%[option.level,Careers.LABELS[option.career]],"当前生命上限%.0f，升级后%.0f。"%[unit.max_hp,Careers.life(option.career,option.level)],true,option.cost))
    if r.level==3 and r.career=="civilian":
     for career: String in ["civilian","archer","charger"]: choices.append(choice("career:"+career,"选择职业："+str(Careers.LABELS[career]),"平民可继续晋升为农民或矿工；弓箭手初始附带30支箭。"))
    if r.career in ["archer","charger"] and is_instance_valid(session.monsters):
     choices.append(choice("guard:mine","派往矿洞守卫","自动前往已标记矿洞，迎击哥布林并掩护矿工；弓箭手从自身背包消耗箭。",mine_marked))
     choices.append(choice("guard:return","召回矿洞护卫","沿阶梯返回地面，恢复日常活动。",session.monsters.orders.has(dialog_id)))
    if r.career=="miner":
     for ore: String in ["stone","coal","iron_ore"]: choices.append(choice("mine:"+ore,"分配："+str(session.inventory.Catalog.ITEMS[ore].name)+"工","每%.0f在线秒开采1份，放入自身背包。\n需要已标记的矿洞；满包或采尽暂停。"%Careers.work_interval("miner",r.level,ore),mine_marked))
 if dialog_kind=="person":
  title=romance.name(dialog_id); choices.append_array(romance.options(dialog_id))
 if dialog_kind=="npc" and population.members.has(dialog_id) and population.friendly(dialog_id): choices.append_array(romance.options("npc:"+dialog_id))
 if dialog_kind=="marriage_bed":
  title="婚房 · 一同上床"
  var id: String=session.world.active_resident.resident_id
  for partner: String in romance.partners(id):
   if romance.marriage(id,partner).house==session.world.active_resident.room_id: choices.append(choice("romance:bed:"+partner,"一同上床："+romance.name(partner),"这对夫妻同处婚房；女方未怀孕，村庄有草药屋，分村人口未满。",romance.can_bed(id,partner)))
 if dialog_kind=="npc_wedding_partner":
  title="主持婚礼 · 为"+romance.name("npc:"+dialog_id)+"选对象"
  for partner: String in romance.weddings.candidates("npc:"+dialog_id): choices.append(choice("family:pick:"+partner,romance.name(partner),"本方成年异性，允许多名配偶；免好感门槛。"))
 if dialog_kind=="npc_wedding_house":
  title="婚房 · "+romance.name("npc:"+dialog_id)+"与"+romance.name(wedding_partner)
  for home: Dictionary in romance.homes(): choices.append(choice("family:house:"+str(home.id),str(home.name),"玩家主持：面包16，双方各收到8个；自动入房、怀孕并接生一次。",true,{"bread":16}))
 if dialog_kind=="delivery":
  title="草药屋 · 接生"
  choices.append(choice("romance:deliver","接生",romance.status(dialog_id),true))
 if dialog_kind=="mine":
  title="矿洞入口"
  choices.append(choice("enter_mine","进入矿洞","带镐子进入地下采集。"))
  choices.append(choice("mark_mine","永久标记矿洞","访问过后可标记；全图永久显示，矿工才可以前往。",mine_visited and not mine_marked))
 if dialog_kind=="relic":
  var r: Dictionary=relics.states[dialog_id]; title=str(names[dialog_id])+" · 圣品"
  choices.append(choice("holy_info","查看圣品","生命%.0f／200 · %s\n重建剩余%.1f秒。"%[r.hp,"本方" if r.owner=="player" else "其他部落",r.remaining]))
  choices.append(choice("rebuild","重建圣品（5分钟）","完成后诞生同属性村长，加入可操控角色。",dialog_id!="home" and r.hp<=0 and r.remaining<=0))
 if dialog_kind=="animal":
  var animal: Node=session.livestock.find_animal(dialog_id); title=session.livestock.label(animal)
  choices.append(choice("rope","解开并收回绳子" if session.wildlife.tethers.has(dialog_id) else "绑上绳子","每根对应一只牲畜，总计最多同时两根。"))
  for grain: String in ["wheat","rice"]: choices.append(choice("feed:"+grain,"喂食："+str(session.inventory.Catalog.ITEMS[grain].name),"喂食规则沿用成长与繁殖。",true,{grain:1}))
 if session.world.active_resident.resident_id=="chief_priest" or session.world.active_resident.resident_id.begins_with("colony_"):
  for tribe: String in ["forest","barbarian","yunye"]:
   if relics.owner(tribe)!="player": choices.append(choice("attack:"+tribe,"出征："+str(names[tribe]),"指挥本方弓箭手和战士攻击该部落。"))
  choices.append(choice("recall","召回本方战斗人员","停止出征并返回各自村庄。"))
 return {"open":true,"mode":"tribes","station":dialog_kind+":"+dialog_id,"title":title,"recipes":choices,"job":{}}
func perform(id: String) -> bool:
 if not session.production.allowed(session.world.active_resident): return false
 if id=="romance:bed": return romance.bed()
 if id.begins_with("romance:bed:"): return romance.bed(id.trim_prefix("romance:bed:"))
 if id=="romance:deliver": return romance.deliver(session.world.active_resident.resident_id)
 var partner := "npc:"+dialog_id if dialog_kind=="npc" else dialog_id
 if id=="romance:gift": return romance.gift(partner)
 if id=="tribe:bread" and dialog_kind=="npc": return gift_bread(dialog_id)
 if id.begins_with("romance:marry:"): return romance.marry(partner,id.trim_prefix("romance:marry:"))
 if id=="romance:invite": return romance.invite(partner)
 if id=="family:host" and dialog_kind=="npc": open("npc_wedding_partner",dialog_id); return true
 if id.begins_with("family:pick:") and dialog_kind=="npc_wedding_partner":
  wedding_partner=id.trim_prefix("family:pick:")
  if wedding_partner not in romance.weddings.candidates("npc:"+dialog_id): return false
  open("npc_wedding_house",dialog_id); return true
 if id.begins_with("family:house:") and dialog_kind=="npc_wedding_house": return romance.weddings.host("npc:"+dialog_id,wedding_partner,id.trim_prefix("family:house:"))
 if id.begins_with("family:again:") and dialog_kind=="npc": return romance.weddings.again("npc:"+dialog_id,id.trim_prefix("family:again:"))
 if id=="talk" or id=="holy_info": session._set_notice("交谈信息见右侧详情。"); return true
 if id=="bag" and dialog_kind=="npc" and population.friendly(dialog_id):
  session.production.close(); session.inventory.open_container(session.world.active_resident.resident_id,session.world.active_resident.resident_name,"npc:"+dialog_id,str(population.members[dialog_id].name)+" · 9格背包"); session.refresh_interface(); return true
 if id.begins_with("upgrade:"): return population.upgrade(dialog_id,id.trim_prefix("upgrade:"))
 if id.begins_with("career:"): return population.specialize(dialog_id,id.trim_prefix("career:"))
 if id.begins_with("guard:") and dialog_kind=="npc" and is_instance_valid(session.monsters): return session.monsters.order_guard(dialog_id,id=="guard:return")
 if id.begins_with("mine:"): return workers.assign(dialog_id,id.trim_prefix("mine:"))
 if id.begins_with("attack:"): return war.order(id.trim_prefix("attack:"))
 if id=="recall":
  var before: Dictionary=session.inventory.export_data(); war.recall(); return session.production.commit(before,"已召回战斗人员。")
 if id=="rebuild" and dialog_kind=="relic": return relics.rebuild(dialog_id)
 if id=="mark_mine" and mine_visited:
  var before: Dictionary=session.inventory.export_data(); mine_marked=true; return session.production.commit(before,"矿洞已永久标记。")
 if id=="enter_mine":
  session.production.close(); session.interiors.enter(session.world.active_resident,session.world.home_data("mine")); mine_visited=true; session._sync_view(); return session.persistence.save_now()
 if id=="rope" and dialog_kind=="animal": return session.wildlife.tie(session.livestock.find_animal(dialog_id))
 if id.begins_with("feed:") and dialog_kind=="animal":
  var before: Dictionary=session.inventory.export_data()
  if not session.livestock.feed_animal(session.world.active_resident,dialog_id,id.trim_prefix("feed:")): return false
  return session.production.commit(before,"已喂食。")
 return false
func export_state() -> Dictionary: return {"encounters":encounters.export_state(),"routine":routine.export_state(),"romance":romance.export_state(),"population":population.export_state(),"workers":workers.export_state(),"war":war.export_state(),"relics":relics.export_state(),"settlements":settlements.export_state(),"mine_visited":mine_visited,"mine_marked":mine_marked,
 "relation":{"standing":standing_points.duplicate(),"gift":gift_standing.duplicate(),"gift_day":gift_day.duplicate(),"aid":aid_cooldown.duplicate(),"conflict":conflict_time.duplicate(true),"death":death_settled.duplicate(true),"clock":clock,"migrated":migrated,"memory":relation.export_state()},
 "guards":guards.export_state() if is_instance_valid(guards) else {},
 "npc_skills":npc_skills.export_state() if is_instance_valid(npc_skills) else {}}
func restore(data: Dictionary) -> void:
 relics.restore(data.get("relics",{})); population.restore(data.get("population",{})); workers.restore(data.get("workers",{})); war.restore(data.get("war",{})); settlements.restore(data.get("settlements",{}))
 encounters.restore(data.get("encounters",{}))
 routine.restore(data.get("routine",{}))
 romance.restore(data.get("romance",{}))
 var relation_data: Dictionary = data.get("relation", {}) if data.get("relation", {}) is Dictionary else {}
 standing_points = relation_data.get("standing", {}).duplicate() if relation_data.get("standing", {}) is Dictionary else {}
 gift_standing = relation_data.get("gift", {}).duplicate() if relation_data.get("gift", {}) is Dictionary else {}
 gift_day = relation_data.get("gift_day", {}).duplicate() if relation_data.get("gift_day", {}) is Dictionary else {}
 aid_cooldown = relation_data.get("aid", {}).duplicate() if relation_data.get("aid", {}) is Dictionary else {}
 conflict_time = relation_data.get("conflict", {}).duplicate(true) if relation_data.get("conflict", {}) is Dictionary else {}
 death_settled = relation_data.get("death", {}).duplicate(true) if relation_data.get("death", {}) is Dictionary else {}
 clock = maxf(0.0, float(relation_data.get("clock", 0.0)))
 migrated = bool(relation_data.get("migrated", false))
 relation.restore(relation_data.get("memory", {}))
 reset_standing()
 if is_instance_valid(guards): guards.restore(data.get("guards", {}))
 if is_instance_valid(npc_skills): npc_skills.restore(data.get("npc_skills", {}))
 # 旧档缺少声誉字段时按首版默认值迁移，且不重播任何扣分或奖励。
 migrated = true
 mine_visited=bool(data.get("mine_visited",false)); mine_marked=bool(data.get("mine_marked",false)); refresh_points()
func show_defeat() -> void:
 if is_instance_valid(defeat_panel): return
 defeat_panel=CanvasLayer.new(); defeat_panel.layer=50; defeat_panel.process_mode=Node.PROCESS_MODE_ALWAYS; add_child(defeat_panel)
 var panel := ColorRect.new(); panel.size=Vector2(640,400); panel.color=Color(0.12,0.02,0.02,0.96); defeat_panel.add_child(panel)
 var font := SystemFont.new(); font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
 var label := Label.new(); label.position=Vector2(90,130); label.size=Vector2(460,100); label.text="部落覆灭\n主村圣品已被摧毁，本村存档已清零。\n返回开始界面创建新的村落。"; label.add_theme_font_override("font",font); label.add_theme_font_size_override("font_size",20); panel.add_child(label)
 var button := Button.new(); button.text="返回开始界面"; button.position=Vector2(220,280); button.size=Vector2(200,38); button.add_theme_font_override("font",font); panel.add_child(button)
 button.pressed.connect(func()->void:get_tree().paused=false; get_tree().change_scene_to_file("res://scenes/start.tscn"))

func post_restore() -> void:
 if not romance.ceremony.is_empty(): romance._show_curtain()
