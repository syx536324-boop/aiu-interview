# Composes tribal domains and exposes interaction snapshots/actions to the existing presentation layer.
extends Node
const Population := preload("res://features/tribes/population.gd")
const Workers := preload("res://features/tribes/workers.gd")
const War := preload("res://features/tribes/war.gd")
const Relics := preload("res://features/tribes/relics.gd")
const Settlements := preload("res://features/tribes/settlements.gd")
const Romance := preload("res://features/romance/romance.gd")
const Careers := preload("res://features/tribes/profession_catalog.gd")
var session: Node
var population := Population.new()
var workers := Workers.new()
var war := War.new()
var relics := Relics.new()
var settlements := Settlements.new()
var romance := Romance.new()
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
 relics.start(self); population.start(self)
 for tribe: String in ["forest","barbarian","yunye"]: settlements.match_population(tribe,population.count(tribe))
 refresh_points()
func advance(delta: float) -> void:
 if relics.failed: return
 if session.world.active_resident.room_id=="mine": mine_visited=true
 population.advance(delta); relics.advance(delta); romance.advance(delta); workers.advance(delta); war.advance(delta); refresh_points()
func refresh_points() -> void:
 for id: String in population.members:
  var actor: Node=population.node(id)
  if not is_instance_valid(actor) or actor.hp<=0: session.world.points.erase("npcunit:"+id); continue
  var r: Dictionary=population.members[id]
  var text := "幼童" if float(r.child_left)>0 else str(Careers.LABELS[r.career])
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
  choices.append(choice("talk","交谈","生命%.0f／%.0f · %s\n%s\n配偶：%s\n%s"%[unit.hp,unit.max_hp,"女性" if r.gender=="female" else "男性","尚未归附，不能升级或取背包。" if not population.friendly(dialog_id) else "本方成员 · "+str(workers.job(dialog_id).status),"、".join(partner_names) if not partner_names.is_empty() else "暂无",romance.status(unit.resident_id)]))
  if population.friendly(dialog_id):
   choices.append(choice("bag","打开背包（9格）","可取出工作产物，放入种子、水桶和箭支作为补给。"))
   if float(r.child_left)>0: choices.append(choice("child","幼童成长中","%.1f在线秒后成年，成年才能升级。"%float(r.child_left),false))
   else:
    for option: Dictionary in Careers.upgrades(r): choices.append(choice("upgrade:"+str(option.career),"升级：%d级%s"%[option.level,Careers.LABELS[option.career]],"当前生命上限%.0f，升级后%.0f。"%[unit.max_hp,Careers.life(option.career,option.level)],true,option.cost))
    if r.level==3 and r.career=="civilian":
     for career: String in ["civilian","archer","charger"]: choices.append(choice("career:"+career,"选择职业："+str(Careers.LABELS[career]),"平民可继续晋升为农民或矿工；弓箭手初始附带30支箭。"))
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
func export_state() -> Dictionary: return {"romance":romance.export_state(),"population":population.export_state(),"workers":workers.export_state(),"war":war.export_state(),"relics":relics.export_state(),"settlements":settlements.export_state(),"mine_visited":mine_visited,"mine_marked":mine_marked}
func restore(data: Dictionary) -> void:
 relics.restore(data.get("relics",{})); population.restore(data.get("population",{})); workers.restore(data.get("workers",{})); war.restore(data.get("war",{})); settlements.restore(data.get("settlements",{}))
 romance.restore(data.get("romance",{}))
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
