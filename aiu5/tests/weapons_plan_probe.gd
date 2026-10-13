# Verifies the weapon/equipment plan through real crafting, harvesting, gifts, attacks and restarts.
extends Node
const Origin := preload("res://features/gifts/provenance.gd")
const Gear := preload("res://features/combat/weapon_catalog.gd")
const Silk := preload("res://features/forest/silk_catalog.gd")
const Rune := preload("res://features/magic/rune_art.gd")
const Enchants := preload("res://features/magic/weapon_enchants.gd")
var game: Node
var s: Node
var directory := ""
var checks := 0
var failures: Array[String]=[]
var capture := false
var base := Vector2(1120,640)
func _enter_tree() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	directory=OS.get_environment("AIU5_PROBE_DIRECTORY"); assert(directory!="")
	OS.set_environment("AIU5_STATE_PATH",directory+"/state.json")
	OS.set_environment("AIU5_PROFILE_PATH",directory+"/names.cfg")
	capture=OS.get_environment("AIU5_CAPTURE")=="true"
	get_tree().create_timer(120,true).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func check(ok: bool, name: String) -> void:
	checks+=1
	if not ok: failures.append(name); push_error(name)
func frames(n := 3) -> void:
	for i in range(n): await get_tree().process_frame
func physics() -> void:
	for node in s.combat.enemies.values(): node.set_physics_process(false)
	await get_tree().physics_frame; await get_tree().physics_frame
func screenshot(name: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(directory+"/"+name+".png")==OK,"capture "+name)
func load_game() -> void:
	game=load("res://scenes/main.tscn").instantiate(); get_tree().root.add_child(game)
	s=game.get_node("Session")
	s.simulation.set_process(false); s.simulation.reset(); s.persistence.set_process(false)
	s.combat.set_process(false); s.resources.set_process(false); s.world.streamer.set_process(false); s.forest.set_process(false)
	for actor in s.world.residents: actor.set_physics_process(false)
	for animal in s.livestock.animals: animal.set_physics_process(false)
	for enemy in s.combat.enemies.values(): enemy.set_physics_process(false)
	await frames()
func empty_bag() -> void:
	s.inventory.bags.ali=[]
	for i in range(21): s.inventory.bags.ali.append({})
func count(item: String) -> int:
	var amount := 0
	for record: Dictionary in s.inventory.ensure_bag("ali"):
		if record.get("item","")==item: amount+=int(record.count)
	return amount
func outside(at: Vector2) -> void:
	var actor: Node=s.world.active_resident
	if actor.room_id!="": s.interiors.leave(actor,s.world.objects,at)
	actor.position=at; actor.dead=false
	s._sync_view(); s.refresh_interface(); s.world.camera.force_update_scroll()
func magic(level := 30, element := "wood") -> void:
	s.close_attributes(); s.production.close(); s.inventory.close(); s.roster_open=false
	s.magic.branches.restore({}); s.magic.enchants.restore({}); s.magic.skills.restore({})
	var state: Dictionary=s.magic.Catalog.fresh()
	state.element=element; state.level=level; state.crystal_milestone=floori(float(level)/5)
	state.unlocked=s.magic.Catalog.TRUNK.duplicate() if level>=11 else []
	state.skill_points=maxi(0,(level-1)*5-state.unlocked.size()*10)
	s.magic.states.ali=state
	s.vitals.ensure("ali").merge({"life":5.0,"mana":s.magic.max_mana("ali"),"hunger":10.0,"thirst":10.0},true)
	outside(base)
func enemy(at: Vector2, id := "tribe:1", hp := 100.0) -> Node:
	var node: Node=s.combat.enemies[id]
	if node.get_parent()==null: s.world.objects.add_child(node)
	node.position=at; node.hp=hp; node.max_hp=hp; node.territory=Rect2(); node.refresh(); node.set_physics_process(false)
	return node
func hide_enemies() -> void:
	for node: Node in s.combat.enemies.values(): node.position=Vector2(2000,1500); node.hp=30; node.refresh(); node.set_physics_process(false)
func equip_gift(item: String, level: int, element: String) -> void:
	var record := {"item":item,"count":1}
	record.merge(Origin.gifted("weapons-"+str(Time.get_ticks_usec()),element,level))
	check(s.inventory.insert_record("ali",record),"insert gift "+item)
	var index := -1
	for i in range(21):
		if s.inventory.ensure_bag("ali")[i].get("gift_event_id","")==record.gift_event_id: index=i; break
	check(s.magic.equip_weapon("ali",item,index),"equip gift "+item)
func attack(target: Node) -> bool:
	s.combat.cooldown=0
	var ok: bool=s.combat.attack_clicked(target.global_position+Vector2(0,-8))
	check(ok,"real clicked attack")
	return ok
func camera_gift(item: String, class_id: int, element: String) -> bool:
	outside(s.world.point_info("altar").position)
	if not s.gifts.open_menu(): return false
	s.gifts.mode="camera"; s.gifts.session_id="weapon-probe-"+str(Time.get_ticks_usec())
	s.gifts.frozen=true; s.gifts.received=true; s.gifts.received_at=Time.get_ticks_msec()
	s.gifts.candidates=[{"id":"one","item":item,"class_id":class_id,"name":item,"kind":"inventory","confidence":0.99}]
	s.gifts.select_candidate("one"); s.gifts.select_element(element)
	return s.gifts.confirm()
func run() -> void:
	await load_game()
	check(Gear.damage("knife")==2 and Gear.damage("iron_knife")==4,"stone and iron knife two and four")
	check(Gear.attack_range("knife")==20 and Gear.interval("iron_knife")==0.4,"knife distance and interval preserved")
	check(not Gear.WEAPONS.has("scissors") and Gear.damage("magic_scissors")==3,"ordinary scissors not a weapon")
	check(Gear.attack_range("magic_scissors")==80 and Gear.interval("magic_scissors",39.99)==0.5 and Gear.interval("magic_scissors",40)==1,"magic scissors exact forty boundary")
	magic(30,"water"); empty_bag()
	var gear := {"armor":"iron_armor","legs":"iron_leggings","head":"iron_helmet","feet":"iron_boots"}
	var points := 0
	for slot: String in gear:
		check(s.inventory.exchange("ali",{}, {gear[slot]:1}),"iron available "+slot)
		check(s.magic.equip("ali",slot,gear[slot]),"real iron equip "+slot)
		points+=int({"armor":3,"legs":2,"head":2,"feet":1}[slot])
		check(s.magic.defense("ali")==points,"iron defense points "+slot)
	check(s.magic.protection_snapshot("ali").armor_reduction_percent==40 and is_equal_approx(s.vitals.damage("ali",10),6),"full iron forty percent")
	s.vitals.ensure("ali").mana=10
	check(s.magic.skills.cast(4,base) and is_equal_approx(s.vitals.damage("ali",10),5),"iron plus water shield ordinary fifty cap")
	check("防御3" in s.magic.Catalog.Armor.describe("iron_armor") and "免伤15%" in s.magic.Catalog.Armor.describe("iron_armor"),"no garbled armor description")
	s.show_attributes("ali"); s.refresh_interface(); await frames(); await screenshot("iron-protection")
	s.close_attributes()
	# Nonlethal tool actions and new material chain.
	magic(); empty_bag(); check(s.inventory.exchange("ali",{}, {"scissors":1,"cowhide":1}),"tool inputs")
	check(s.production.scissors.perform("scissors:hide"),"real hide cutting")
	check(count("cowhide")==0 and count("leather")==2 and count("scissors")==1,"one hide gives two leather, scissors retained")
	var cow: Node=s.livestock.find_animal("cow:1")
	check(s.combat.hit_cow(cow,10,"ali") and count("cowhide")==1 and count("beef")==1,"real cow drops new hide and beef")
	var sheep: Node=s.livestock.find_animal("sheep:1")
	outside(sheep.position+Vector2(0,10))
	var health: float=sheep.hp
	check(s.production.scissors.perform("scissors:shear:sheep:1") and sheep.hp==health and count("wool")==2,"adult sheep wool two without harm")
	check(not s.production.scissors.perform("scissors:shear:sheep:1"),"repeat shearing rejected")
	s.production.scissors.advance(299.9)
	check(not s.production.scissors.perform("scissors:shear:sheep:1"),"shear waits full five minutes")
	s.production.scissors.advance(0.1)
	check(s.production.scissors.perform("scissors:shear:sheep:1") and count("wool")==4,"shear available at three hundred seconds")
	check(sheep.get_meta("sheared",false),"sheep appearance visibly shorn")
	s.production.open_scissors(); s.refresh_interface(); await frames(); await screenshot("scissors-harvesting")
	s.production.close()
	var observed := 0
	for i in range(1,4001):
		if Silk.extra(40981,"mulberry-statistics",i): observed+=1
	check(observed>1080 and observed<1320,"fixed-seed silk statistics within twenty seven to thirty three percent")
	outside(Vector2(-1780,640)); s.forest.focus(s.world.active_resident.position,false)
	for i in range(100): s.forest._process(0.01)
	var mulberry := ""; var grass := ""
	for id: String in s.forest.loaded:
		if s.forest.loaded[id].record.kind=="mulberry" and mulberry=="": mulberry=id
		if s.forest.loaded[id].record.kind=="grass" and grass=="": grass=id
	check(mulberry!="" and grass!="","real forest has mulberry and grass")
	if mulberry!="":
		outside(s.forest.loaded[mulberry].position)
		var had_silk := count("silk")
		for i in range(30):
			s.forest.collected[mulberry]=0.0
			check(s.forest.gather(mulberry),"real mulberry harvest")
			if count("silk")>had_silk: break
		check(count("silk")>had_silk,"actual mulberry gives bonus silk")
	if grass!="":
		outside(s.forest.loaded[grass].position)
		var seed_before: Dictionary=s.forest.seed_state(grass).duplicate(true)
		check(s.production.scissors.perform("scissors:vine:"+grass),"real grass vine cut")
		check(count("vine")==1 and s.forest.seed_state(grass)==seed_before,"vine harvest independent of seeds")
		check(not s.production.scissors.perform("scissors:vine:"+grass),"vine cooldown prevents duplicate")
		s.production.scissors.advance(120)
		check(s.production.scissors.perform("scissors:vine:"+grass) and count("vine")==2,"vine returns in two minutes")
	empty_bag(); check(s.inventory.exchange("ali",{}, {"silk":25,"wool":4,"wood":4}),"cloth and bed inputs")
	var bench: Node=s.grounds.fixtures.filter(func(f: Node) -> bool: return f.fixture_id=="outdoors:public:desert")[0]
	outside(bench.position+Vector2(0,14)); s.production.open_near()
	for i in range(5):
		check(s.production.perform("cloth"),"real cloth recipe starts")
		s.production.elapse(60)
	check(count("silk")==0 and count("cloth")==5,"five silk produce one cloth per job")
	check(s.production.perform("bed"),"new bed recipe starts")
	s.production.elapse(60)
	check(count("bed")==1 and count("cloth")==0 and count("wool")==0 and count("wood")==0,"bed consumes original inputs plus five cloth")
	s.production.close()
	# Real camera-confirm path stamps immutable gift levels and the twelve-level gate.
	magic(11); empty_bag()
	check(camera_gift("knife",1,"fire"),"below twelve camera grant")
	var record: Dictionary={}
	for slot: Dictionary in s.inventory.ensure_bag("ali"):
		if slot.get("item","")=="knife": record=slot; break
	check(record.get("gift_level",0)==11 and record.get("magic_attribute") == null,"level eleven gift stores level without attribute")
	magic(12); empty_bag()
	check(camera_gift("scissors",5,"water"),"twelve-level camera scissors gift")
	for slot: Dictionary in s.inventory.ensure_bag("ali"):
		if slot.get("item","")=="magic_scissors": record=slot; break
	check(record.get("item","")=="magic_scissors" and record.gift_level==12 and record.magic_attribute=="water","camera scissors becomes magical weapon with selected water")
	check(Origin.fields({"is_magical":true,"gift_event_id":"legacy"}).gift_level==1,"legacy gifts default level one")
	var migrated: Array=s.inventory._sanitize_slots([{"item":"scissors","count":1,"is_magical":true,"gift_event_id":"old-scissors"}])
	check(migrated[0].item=="magic_scissors" and migrated[0].gift_level==1,"legacy magical scissors migrates without inventing levels")
	# Bonus survives element assignment, empowerment and changes to the owner's current level.
	magic(12); empty_bag(); equip_gift("knife",12,"wood")
	check(is_equal_approx(s.magic.attack_damage("ali"),4.4),"gift twelve knife two plus two point four")
	s.magic.ensure("ali").level=80
	check(is_equal_approx(s.magic.attack_damage("ali"),4.4),"owner leveling cannot alter grant-time bonus")
	check(s.magic.skills.cast(2,base) and is_equal_approx(s.magic.attack_damage("ali"),6.4),"trunk empower and gifted elemental bonus coexist")
	for lv in [1,12,20,30,49,50,80,100]:
		var fields: Dictionary=Origin.gifted("math-"+str(lv),"fire",lv)
		check(is_equal_approx(Enchants.bonus(fields),minf(lv*0.2,10)),"gift bonus clamp "+str(lv))
	check(Enchants.bonus({})==0,"ordinary weapon no gift bonus")
	# Actual enchanted melee effects, not only direct helper arithmetic.
	magic(30); empty_bag(); hide_enemies(); equip_gift("knife",12,"wood")
	var target: Node=enemy(base+Vector2(18,0))
	await physics(); attack(target)
	check(is_equal_approx(target.hp,95.6) and is_equal_approx(s.vitals.ensure("ali").life,6.22),"wood heals one point twenty two percent of enemy maximum without extra damage")
	target.hp=0.5; s.vitals.ensure("ali").life=5
	attack(target)
	check(is_equal_approx(s.vitals.ensure("ali").life,5.5),"wood healing capped at actual overkill HP removed")
	magic(30,"fire"); empty_bag(); hide_enemies(); equip_gift("knife",12,"fire")
	target=enemy(base+Vector2(18,0)); await physics(); attack(target)
	s.magic.enchants.advance(1)
	check(is_equal_approx(target.hp,93.4),"fire twelve burn two point two per second")
	attack(target)
	check(s.magic.enchants.burns.size()==1 and s.magic.enchants.burns["enemy:tribe:1"].remaining==5,"same burn refreshes without stacking")
	var hp: float=target.hp; s.magic.enchants.advance(5)
	check(is_equal_approx(hp-target.hp,11.0) and s.magic.enchants.burns.is_empty(),"exact five burn ticks and cleanup")
	magic(30,"water"); empty_bag(); hide_enemies(); equip_gift("knife",12,"water")
	target=enemy(base+Vector2(18,0)); await physics(); attack(target)
	check(is_equal_approx(s.magic.branches.speed_rate(target.enemy_id),0.68),"water twelve slows thirty two percent")
	s.magic.branches._status(target,"ali","thorns",3,{"slow":0.3})
	check(is_equal_approx(s.magic.branches.speed_rate(target.enemy_id),0.476),"water enchant combines with different branch source")
	equip_gift("iron_knife",30,"water")
	var second: Node=enemy(base+Vector2(0,18),"tribe:2")
	await physics(); attack(second)
	check(not s.magic.enchants.slows.has("enemy:tribe:2"),"water cooldown shared after switching weapons")
	s.magic.enchants.advance(6.99); attack(second)
	check(not s.magic.enchants.slows.has("enemy:tribe:2"),"water waits full seven seconds")
	s.magic.enchants.advance(0.01); attack(second)
	check(is_equal_approx(s.magic.branches.speed_rate(second.enemy_id),0.5),"water proc at exact seven seconds")
	s.magic.enchants.advance(2)
	check(s.magic.enchants.slows.is_empty(),"water slow lasts two seconds")
	magic(30,"earth"); empty_bag(); hide_enemies(); equip_gift("knife",12,"earth")
	target=enemy(base+Vector2(18,0)); await physics(); attack(target)
	check(is_equal_approx(s.magic.branches.buffs.ali.gift_earth.shield,11.2),"earth twelve grants eleven point two shield")
	s.vitals.hurt("ali",2)
	check(s.vitals.ensure("ali").life==5 and is_equal_approx(s.magic.branches.buffs.ali.gift_earth.shield,9.2),"earth shield absorbs actual damage")
	equip_gift("iron_knife",30,"earth"); attack(target)
	check(is_equal_approx(s.magic.branches.buffs.ali.gift_earth.shield,9.2),"earth cooldown shared across equipment")
	s.magic.branches.advance(10)
	check(not s.magic.branches.buffs.ali.has("gift_earth"),"earth shield expires after ten seconds")
	s.magic.enchants.advance(29.99); attack(target)
	check(not s.magic.branches.buffs.ali.has("gift_earth"),"earth waits thirty seconds")
	s.magic.enchants.advance(0.01); attack(target)
	check(s.magic.branches.buffs.ali.gift_earth.shield==13,"earth refresh after full thirty second cooldown")
	# Magic scissors has real outbound, impact and recall nodes, exact cooldowns and unobstructed requirement.
	magic(30); empty_bag(); hide_enemies(); equip_gift("magic_scissors",12,"wood")
	target=enemy(base+Vector2(39,0)); await physics(); attack(target)
	check(is_equal_approx(s.combat.cooldown,0.5) and s.combat.scissors.flights.is_empty() and is_equal_approx(target.hp,94.6),"thirty nine pixel scissors melee five point four damage")
	target.position=base+Vector2(40,0); target.hp=100; await physics(); attack(target)
	check(s.combat.cooldown==1 and s.combat.scissors.flights.size()==1 and s.combat.scissors.visuals.size()==1,"forty pixel scissors visibly flies at one second interval")
	if not (s.combat.cooldown==1 and s.combat.scissors.flights.size()==1 and s.combat.scissors.visuals.size()==1): print("SCISSORS40 cd=",s.combat.cooldown," flights=",s.combat.scissors.flights.size()," visuals=",s.combat.scissors.visuals.size())
	s.combat.scissors.advance(0.08)
	await frames(); await screenshot("magic-scissors-outgoing")
	for i in range(10): s.combat.scissors.advance(0.04)
	check(is_equal_approx(target.hp,94.6),"flying scissors hits exactly once")
	for i in range(25): s.combat.scissors.advance(0.04)
	check(s.combat.scissors.flights.is_empty() and s.combat.scissors.visuals.is_empty(),"scissors flies back without leftover nodes")
	target.position=base+Vector2(81,0); await physics(); s.combat.cooldown=0
	check(not s.combat.attack_clicked(target.position+Vector2(0,-8)),"eighty one pixels rejected")
	target.position=base+Vector2(80,0); await physics(); attack(target)
	check(s.combat.scissors.flights.size()==1,"eighty pixel inclusive maximum")
	for i in range(45): s.combat.scissors.advance(0.04)
	var wall := StaticBody2D.new(); wall.collision_layer=1
	var shape := CollisionShape2D.new(); shape.shape=RectangleShape2D.new(); shape.shape.size=Vector2(8,40)
	wall.add_child(shape); s.world.objects.add_child(wall); wall.position=base+Vector2(35,0)
	target.position=base+Vector2(70,0); await physics(); s.combat.cooldown=0
	var wear_before: Dictionary=s.magic.ensure("ali").weapon_wear.duplicate(true)
	check(not s.combat.attack_clicked(target.position+Vector2(0,-8)) and s.magic.ensure("ali").weapon_wear==wear_before,"blocked magic scissors cannot attack or spend durability")
	wall.free(); await physics()
	# Every branch skill has an elemental casting effect even for instantaneous healing/knockback.
	for element: String in ["wood","water","fire","earth"]:
		magic(100,element); empty_bag(); hide_enemies()
		for rule: Dictionary in s.magic.Catalog.Branches.entries(element): s.magic.ensure("ali").branch_unlocked.append(rule.id)
		s.magic.ensure("ali").skill_points=205
		target=enemy(base+Vector2(30,0)); await physics()
		var skill: String=element+"_battle_1"
		check(s.magic.branches.cast(skill,target.position),"elemental first battle spell "+element)
		var found := false
		for node: Node in s.magic.branches.visuals.values():
			if node.kind=="cast" and node.record.element==element: found=true
		check(found and Rune.color(element)==Color(str(s.magic.Catalog.ELEMENTS[element].color)),"distinct exact rune color "+element)
	# Passive marks remain attached after entering a room and after scene detachment.
	var passive_key: String="buff:passive:ali"
	s.magic.branches._update_visuals()
	check(s.magic.branches.visuals.has(passive_key),"first trunk passive has a visible rune")
	var passive: Node=s.magic.branches.visuals[passive_key]
	passive.get_parent().remove_child(passive)
	s.magic.branches._update_visuals()
	check(passive.get_parent()==s.world.objects,"detached passive safely rejoins world")
	var room_key := "probe-room"
	var probe_room := Node2D.new(); game.add_child(probe_room); s.interiors.rooms[room_key]=probe_room
	s.world.active_resident.room_id=room_key
	s.magic.branches._update_visuals()
	check(passive.get_parent()==s.interiors.rooms[room_key],"passive follows actor into room")
	s.world.active_resident.room_id=""
	s.magic.branches._update_visuals()
	check(passive.get_parent()==s.world.objects,"passive returns outdoors")
	s.interiors.rooms.erase(room_key); probe_room.free()
	# Rendering uses the approved atlas while each assigned element has its own exact rune material.
	var preview := CanvasLayer.new(); preview.layer=20; add_child(preview)
	var background := ColorRect.new(); background.size=Vector2(640,400); background.color=Color("332e25"); preview.add_child(background)
	var font := SystemFont.new(); font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	var heading := Label.new(); heading.position=Vector2(48,36); heading.text="赐予武器 · 四系符文"; heading.add_theme_font_override("font",font); heading.add_theme_font_size_override("font_size",22); background.add_child(heading)
	var rune_column := 0
	for element: String in Rune.COLORS:
		var label := Label.new(); label.position=Vector2(64+rune_column*140,110); label.text=Origin.ELEMENTS[element]; label.add_theme_font_override("font",font); label.add_theme_font_size_override("font_size",18); label.modulate=Rune.color(element); background.add_child(label)
		for item: String in ["knife","magic_scissors"]:
			var icon: Control=load("res://features/interface/item_icon.gd").new(); icon.size=Vector2(64,64); icon.position=Vector2(56+rune_column*140,150 if item=="knife" else 240); background.add_child(icon)
			var icon_record := {"item":item,"count":1}; icon_record.merge(Origin.gifted("rune-"+element,element,12)); icon.set_record(icon_record)
			check(icon.magic_attribute==element and icon.material.get_shader_parameter("rune_color")==Rune.color(element),"actual icon rune material "+item+element)
		rune_column+=1
	await frames(); await screenshot("four-element-runes"); preview.free()
	# Saving failures must undo bonus damage, gift effects, projectile state and the durability charge.
	magic(30,"earth"); empty_bag(); hide_enemies(); equip_gift("magic_scissors",12,"earth")
	target=enemy(base+Vector2(70,0),"tribe:1",30); await physics()
	var original_path: String=s.inventory.path
	var blocked := directory+"/blocked"; DirAccess.make_dir_recursive_absolute(blocked); s.inventory.path=blocked
	var original_wear: Dictionary=s.magic.ensure("ali").weapon_wear.duplicate(true)
	s.combat.cooldown=0
	check(not s.combat.attack_clicked(target.position+Vector2(0,-8)),"failed flying attack save rejected")
	s.inventory.path=original_path
	check(s.magic.ensure("ali").weapon_wear==original_wear and s.combat.scissors.flights.is_empty(),"failed launch preserves durability and creates no lingering flight")
	check(not s.magic.branches.buffs.get("ali",{}).has("gift_earth") and s.magic.enchants.cooldowns.is_empty(),"failed launch restores shield and shared proc cooldown")
	s.inventory.path=blocked
	check(not camera_gift("bow",13,"water"),"failed camera grant save rejected")
	s.inventory.path=original_path; s.gifts.close()
	check(count("bow")==0,"failed camera grant leaves no reward")
	# Burn phase and interval survive a real restart without replaying already-paid ticks.
	magic(30,"fire"); empty_bag(); hide_enemies(); equip_gift("knife",12,"fire")
	target=enemy(base+Vector2(18,0),"tribe:1",30); await physics(); attack(target)
	s.magic.enchants.advance(2.5)
	check(s.persistence.save_now(),"partly elapsed weapon burn saved")
	game.queue_free(); await frames(); await load_game()
	check(is_equal_approx(s.magic.enchants.burns["enemy:tribe:1"].remaining,2.5) and is_equal_approx(s.magic.enchants.burns["enemy:tribe:1"].tick,0.5),"restart preserves exact remaining burn and fractional tick")
	s.magic.enchants.advance(2.5)
	check(is_equal_approx(s.combat.enemies["tribe:1"].hp,14.6) and s.magic.enchants.burns.is_empty(),"restarted fire deals only remaining three ticks")
	# Final saved state includes immutable level, effect timers, cooldowns and a flying weapon.
	magic(30,"water"); empty_bag(); hide_enemies(); equip_gift("magic_scissors",12,"water")
	target=enemy(base+Vector2(70,0),"tribe:1",30); await physics(); attack(target)
	check(s.persistence.save_now(),"flight and gift record saved")
	var saved_level: int=s.magic.ensure("ali").weapon_wear.gift_level
	game.queue_free(); await frames(); await load_game()
	check(s.magic.ensure("ali").equipment.weapon=="magic_scissors" and s.magic.ensure("ali").weapon_wear.gift_level==saved_level,"real restart preserves equipped immutable gift level")
	check(s.combat.scissors.flights.size()==1 and s.combat.scissors.visuals.size()==1,"real restart preserves flying scissors visual and flight state")
	check(s.combat.cooldown>0 and s.combat.cooldown<=1,"restart preserves paid weapon attack interval")
	for i in range(50): s.combat.scissors.advance(0.04)
	check(s.combat.scissors.flights.is_empty(),"resumed scissors returns safely")
	check(s.persistence.save_now(),"resumed impact saved")
	print("WEAPONS_PLAN_OK checks=%d" % checks if failures.is_empty() else "WEAPONS_PLAN_FAILED "+str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
