# Tests goblin combat, level inheritance, escorts, safe worker behavior, saved clocks and mine lighting in isolated scenes.
extends Node
var game: Node
var s: Node
var directory: String
var failures: Array[String]=[]
var checks:=0
var original_slots: Dictionary={}
var sample_id:=""
var metrics: Dictionary={}
func _ready() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error(label)
func frames(n:=2) -> void:
	for i in range(n): await get_tree().process_frame
func load_game() -> void:
	game=load("res://scenes/main.tscn").instantiate(); get_tree().root.add_child(game)
	s=game.get_node("Session"); s.persistence.set_process(false); s.simulation.set_process(false); s.resources.set_process(false); s.world.streamer.set_process(false)
	for enemy: Node in s.combat.enemies.values(): enemy.set_physics_process(false)
	await frames(5)
func clear_monsters() -> void:
	for id: String in s.monsters.units.keys(): s.monsters._drop(id)
	for flight: Dictionary in s.monsters.flights.duplicate(): s.monsters._erase_flight(flight)
	s.monsters.slots.clear(); s.monsters.handled.clear()
func make_monster(level: int,at: Vector2) -> Node:
	for founder: String in ["ali","heya","chief_priest"]: s.magic.ensure(founder).level=level
	s.monsters._add_slot(sample_id,"mine",at)
	var record: Dictionary=s.monsters.slots[sample_id]; s.monsters._spawn(record,sample_id)
	var unit: Node=s.monsters.units[sample_id]; s.interiors.rooms.mine.objects.add_child(unit); unit.set_physics_process(false)
	return unit
func npc(id: String,career: String,level: int,at: Vector2) -> Node:
	var node: Node=s.tribes.population.node(id)
	if not is_instance_valid(node): node=s.tribes.population.add(id,"home",career,level,Vector2(600,400))
	s.interiors.enter(node,s.world.home_data("mine")); node.position=at; s._sync_view()
	return node
func lane(length:=170.0) -> Vector2:
	for y in range(80,700,16):
		for x in range(160,1500,32):
			var start:=Vector2(x,y); var free:=true
			for i in range(-100,ceili(length)+1,8):
				for dy: int in [-16,-8,0,8,16]:
					if not s.monsters.walkable(start+Vector2(i,dy),"mine"): free=false; break
				if not free: break
			if free: return start
	return Vector2(100,208)
func move_player(at: Vector2) -> void:
	s.world.active_resident.position=at; s._sync_view(); s.refresh_interface()
func count(id: String,item: String) -> int:
	var total:=0
	for record: Dictionary in s.inventory.ensure_bag(id):
		if record.get("item","")==item: total+=int(record.count)
	return total
func screenshot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await frames(3); get_viewport().get_texture().get_image().save_png(directory+"/"+name+".png")
func extended_checks(actor: Node,base: Vector2) -> void:
	# Real physics pursuit must move continuously rather than jump on the coarse NPC clock.
	clear_monsters()
	for id: String in ["home:probe_archer","home:probe_civilian","home:probe_miner"]: s.tribes.population.node(id).position=Vector2(1750,850)
	var unit:=make_monster(1,base+Vector2(8,0)); move_player(base+Vector2(168,0)); await frames(3)
	unit.set_physics_process(true)
	var start: Vector2=unit.position; var previous:=start; var max_motion:=0.0; var moving:=0; var samples: Array[float]=[]
	var stamp:=Time.get_ticks_usec()
	for i in range(120):
		await get_tree().physics_frame
		var now:=Time.get_ticks_usec(); samples.append(float(now-stamp)/1000.0); stamp=now
		var motion: float=unit.position.distance_to(previous); max_motion=maxf(max_motion,motion)
		if motion>0.02: moving+=1
		previous=unit.position
	unit.set_physics_process(false); samples.sort()
	metrics={"physics_frame_p95_ms":samples[int(samples.size()*0.95)],"physics_frame_max_ms":samples.back(),"pursuit_world_pixels":start.distance_to(unit.position),"moving_frames":moving,"maximum_motion_per_frame":max_motion}
	check(start.distance_to(unit.position)>35 and moving>100 and max_motion<2,"goblin pursuit moves smoothly in actual physics frames")
	check(float(metrics.physics_frame_p95_ms)<40,"sustained cave pursuit avoids frame stalls")
	# A dead encounter gives one reward, then respawns only after its clock and safety conditions pass.
	var state: Dictionary=s.magic.ensure(actor.resident_id); state.element=""; state.pending_points=0
	check(s.combat.hit_enemy(unit,999,actor.resident_id) and int(state.pending_points)==25,"player goblin kill awards exactly 25 magic points")
	check(not s.combat.hit_enemy(unit,999,actor.resident_id) and int(state.pending_points)==25,"repeated hits on a defeated goblin never award points again")
	var record: Dictionary=s.monsters.slots[sample_id]
	s.monsters.online=float(record.ready_at)+1
	for founder: String in ["ali","heya","chief_priest"]: s.magic.ensure(founder).level=8
	move_player(Vector2(record.home[0],record.home[1])+Vector2(260,0)); s.monsters._focus()
	check(not record.dead and s.monsters.units[sample_id].level==5,"due safe respawn actually uses the current player level capped at five")
	# Parked mines still resolve attacks and arrows while the player is outdoors.
	clear_monsters(); unit=make_monster(4,base+Vector2(120,0)); unit.set_physics_process(false)
	var archer: Node=s.tribes.population.node("home:probe_archer"); archer.position=base
	var miner: Node=s.tribes.population.node("home:probe_miner"); miner.position=base+Vector2(92,0)
	s.interiors.leave(actor,s.world.objects,s.mining.DOOR+Vector2(0,10)); s._sync_view(); await frames(3)
	check(not s.interiors.rooms.mine.is_inside_tree() and not unit.is_inside_tree(),"unobserved occupied cave is safely parked")
	var life: float=miner.hp
	s.monsters.resolve_attack(unit,"basic",miner.position,unit.position.direction_to(miner.position),miner.enemy_id)
	check(miner.hp<life,"goblins can injure miners in an unobserved cave")
	miner.position=Vector2(1750,850); s.tribes.war.cooldowns[archer.enemy_id]=0
	var arrows:=count(archer.resident_id,"arrow"); life=unit.hp
	s.monsters.respond(0.1)
	check(count(archer.resident_id,"arrow")==arrows-1,"parked escort still consumes one arrow per shot")
	for i in range(12): s.monsters._physics_process(0.05)
	check(unit.hp<life,"parked escort's swept arrow still protects miners")
	s.interiors.enter(actor,s.world.home_data("mine")); move_player(base+Vector2(40,0)); s._sync_view(); await frames(3)
	unit.set_physics_process(false)
	check(unit.is_inside_tree(),"returning to guarded cave resumes the same encounter")
	clear_monsters(); unit=make_monster(5,base+Vector2(80,0)); move_player(base+Vector2(200,0)); miner.position=base+Vector2(48,0); archer.position=base+Vector2(112,0); await frames(3)
	life=miner.hp; var behind_life: float=archer.hp
	s.monsters.resolve_attack(unit,"sweep",miner.position,Vector2.LEFT,miner.enemy_id)
	check(is_equal_approx(life-miner.hp,4) and archer.hp==behind_life,"level-five sweep deals four damage only in the forward cone")
func run() -> void:
	directory=OS.get_environment("AIU5_BENCH_DIR")
	if directory=="": get_tree().quit(2); return
	OS.set_environment("AIU5_STATE_PATH",directory+"/state.json"); OS.set_environment("AIU5_PROFILE_PATH",directory+"/names.cfg"); OS.set_environment("AIU5_WORLD_PROFILE","starter_v2")
	await load_game()
	original_slots=s.monsters.slots.duplicate(true)
	for id: String in original_slots:
		if original_slots[id].room=="mine": sample_id=id; break
	check(sample_id!="","seed creates cave goblin encounter slots")
	if sample_id=="": get_tree().quit(1); return
	clear_monsters()
	var actor: Node=s.world.active_resident; var actor_id: String=actor.resident_id
	if actor.room_id!="": s.interiors.leave(actor,s.world.objects,s.mining.DOOR+Vector2(0,10))
	s.interiors.enter(actor,s.world.home_data("mine")); s._sync_view()
	var base:=lane(); move_player(base+Vector2(24,0)); await frames(3)
	s.magic.branches.buffs.clear(); s.magic.skills.buffs.clear()
	s.magic.ensure(actor_id).torch={}; s.torches.refresh_light(); s.day_night._refresh()
	check(s.day_night.light.color==Color("11141d"),"unlit mine uses the darker ambient color immediately")
	await screenshot("mine-no-torch")
	s.magic.ensure(actor_id).torch={"item":"torch","count":1,"lit":true,"fuel_left":600.0,"burn_left":300.0}
	s.torches.refresh_light(); await frames(4)
	check(s.torches.lamp.enabled and s.torches.lamp.texture.get_width()==80 and s.day_night.light.color==Color("11141d"),"torch restores only its 80-world-pixel local light without brightening the full mine")
	await screenshot("mine-with-torch")
	s.magic.ensure(actor_id).torch={}; s.torches.refresh_light()
	for rank in range(1,7):
		clear_monsters(); var unit:=make_monster(rank,base+Vector2(48,0))
		check(unit.level==mini(rank,5),"new goblin matches player level capped at five: "+str(rank))
		check(unit.max_hp==s.monsters.Rules.LIFE[mini(rank,5)-1],"goblin life matches confirmed level table")
		check(s.monsters.Rules.skills(unit.level).size()==mini(rank,5),"higher goblin retains all lower-level skills")
		s.magic.ensure(actor_id).level=10
		check(unit.level==mini(rank,5),"existing goblin keeps its original spawn level")
	clear_monsters(); var goblin:=make_monster(5,base+Vector2(48,0))
	s.inventory.bags[actor_id]=[]
	for i in range(21): s.inventory.bags[actor_id].append({})
	check(s.inventory.exchange(actor_id,{}, {"iron_sword":1,"bow":1,"arrow":50}),"isolated weapons and arrows fit")
	check(s.magic.equip_weapon(actor_id,"iron_sword"),"player equips a sword inside the mine")
	move_player(base+Vector2(24,0)); await frames(4); s.combat.cooldown=0
	var life: float=goblin.hp
	check(s.combat.attack_clicked(goblin.global_position) and goblin.hp<life,"actual right-click sword combat damages a cave goblin")
	check(s.magic.equip_weapon(actor_id,"bow"),"player equips bow inside mine")
	goblin.position=base+Vector2(120,0); await frames(3); s.combat.cooldown=0
	var arrows:=count(actor_id,"arrow"); life=goblin.hp
	check(s.combat.attack_clicked(goblin.global_position) and count(actor_id,"arrow")==arrows-1,"mine bow attack consumes exactly one arrow")
	await frames(35)
	check(goblin.hp<life,"actual player arrow renders and hits in the mine's coordinate space")
	check(s.magic.equip_weapon(actor_id,"iron_sword"),"player returns to sword")
	clear_monsters(); goblin=make_monster(5,base+Vector2(48,0)); move_player(base+Vector2(24,0)); await frames(3)
	var vitals: Dictionary=s.vitals.ensure(actor_id); vitals.life=s.vitals.max_life(actor_id)
	var before: float=vitals.life
	check(goblin.begin_attack("heavy",actor) and not goblin.begin_attack("roots",actor),"only one attack can be prepared at a time")
	goblin.step(0.49)
	check(vitals.life==before,"heavy attack does not deal damage during its telegraph")
	goblin.step(0.02)
	check(vitals.life<before and goblin.cooldowns.heavy>5 and goblin.cooldowns.get("roots",0)==0,"heavy lands after windup and skills keep independent cooldowns")
	# Let recovery expire with the target outside every attack range, so automatic AI cannot start another skill.
	move_player(base+Vector2(400,0)); goblin.step(0.3); move_player(base+Vector2(24,0)); vitals.life=s.vitals.max_life(actor_id)
	check(goblin.begin_attack("basic",actor),"high-level goblin can use its level-one attack during heavy cooldown")
	move_player(base+Vector2(-40,0)); goblin.step(0.21)
	check(vitals.life==s.vitals.max_life(actor_id),"moving outside melee reach before impact avoids the hit")
	move_player(base+Vector2(108,0)); goblin.position=base+Vector2(48,0); await frames(3)
	s.monsters.resolve_attack(goblin,"roots",actor.position,goblin.position.direction_to(actor.position),actor_id)
	check(s.magic.branches.immobile(actor_id),"roots apply the confirmed immobilization")
	s.magic.branches.advance(0.61); s.monsters.advance(0.61)
	check(not s.magic.branches.immobile(actor_id),"root ends after 0.6 online seconds")
	s.monsters.resolve_attack(goblin,"roots",actor.position,goblin.position.direction_to(actor.position),actor_id)
	check(not s.magic.branches.immobile(actor_id),"same root cannot chain during its two-second immunity")
	s.magic.branches.advance(2.1); s.monsters.advance(2.1)
	move_player(base+Vector2(144,0)); goblin.position=base+Vector2(48,0); vitals.life=s.vitals.max_life(actor_id)
	await frames(3); before=vitals.life
	s.monsters.resolve_attack(goblin,"thorn",actor.position,goblin.position.direction_to(actor.position),actor_id)
	await frames(40)
	check(vitals.life<before,"swept goblin thorn hits the player")
	vitals.life=s.vitals.max_life(actor_id); before=vitals.life
	s.monsters.resolve_attack(goblin,"thorn",actor.position,goblin.position.direction_to(actor.position),actor_id)
	move_player(actor.position+Vector2(0,40)); await frames(40)
	check(vitals.life==before,"goblin thorn can be dodged")
	# Wall occlusion is checked again at impact, including the root skill.
	var wall:=StaticBody2D.new(); wall.collision_layer=1
	var shape:=CollisionShape2D.new(); var rect:=RectangleShape2D.new(); rect.size=Vector2(4,60); shape.shape=rect; wall.add_child(shape)
	s.interiors.rooms.mine.objects.add_child(wall); wall.position=base+Vector2(80,0)
	move_player(base+Vector2(108,0)); await frames(3); before=vitals.life
	s.monsters.resolve_attack(goblin,"roots",actor.position,goblin.position.direction_to(actor.position),actor_id)
	check(vitals.life==before,"root does not pass through cave walls")
	var no_characters: Array[Node]=[]
	check(not s.monsters._safe_spawn({"home":[wall.position.x,wall.position.y],"room":"mine"},no_characters),"spawn checks actual body clearance against a live collider")
	wall.queue_free(); await frames(3)
	# Both combat careers protect miners using their ordinary weapon rules.
	move_player(base+Vector2(0,80)); vitals.life=s.vitals.max_life(actor_id)
	var archer:=npc("home:probe_archer","archer",4,base+Vector2(0,0)); goblin.position=base+Vector2(120,0); goblin.hp=30; goblin.refresh(); goblin.set_physics_process(false)
	arrows=count(archer.resident_id,"arrow"); life=goblin.hp; s.tribes.war.cooldowns[archer.enemy_id]=0
	s.monsters.respond(0.1)
	check(s.monsters.handles(archer) and count(archer.resident_id,"arrow")==arrows-1,"archer proactively sees cave monster and consumes ammunition")
	await frames(35)
	check(goblin.hp<life,"NPC cave arrow uses correct global swept collision")
	archer.position=Vector2(1600,800)
	var fighter:=npc("home:probe_fighter","charger",5,base+Vector2(96,0)); life=goblin.hp; s.tribes.war.cooldowns[fighter.enemy_id]=0
	s.monsters.respond(0.1)
	check(goblin.hp<life and s.monsters.handles(fighter),"warrior proactively strikes the cave monster")
	fighter.position=Vector2(1600,800)
	var civilian:=npc("home:probe_civilian","civilian",1,base+Vector2(24,0)); var gap: float=civilian.position.distance_to(goblin.position)
	s.monsters.respond(0.1)
	check(s.monsters.blocks_work(civilian),"civilian sees monster and enters escape behavior")
	var max_step:=0.0; var previous: Vector2=civilian.position
	for i in range(30):
		await get_tree().physics_frame; max_step=maxf(max_step,civilian.position.distance_to(previous)); previous=civilian.position
	check(civilian.position.distance_to(goblin.position)>gap and max_step<4,"civilian escapes with smooth physical movement")
	civilian.position=Vector2(1600,800)
	# A miner must pause even with a partially elapsed paid work interval.
	var miner:=npc("home:probe_miner","miner",4,base+Vector2(24,0)); s.tribes.mine_marked=true
	var task: Dictionary=s.tribes.workers.job(miner.enemy_id); task.kind="stone"; task.left=8.0
	move_player(base+Vector2(0,250)); goblin.position=miner.position+Vector2(90,0); await frames(3)
	s.monsters.respond(0.1); s.tribes.workers.advance(0.5)
	check(s.monsters.blocks_work(miner) and task.left==8.0 and str(task.status).contains("护卫"),"unprotected miner stops work and seeks cover instead of producing ore")
	move_player(miner.position+Vector2(0,30)); await frames(3)
	s.monsters.respond(0.1); s.tribes.workers.advance(0.5)
	check(s.monsters.is_protected(miner) and task.left<8,"armed player protection allows the miner to resume at a safe distance")
	move_player(base+Vector2(0,250)); fighter.position=miner.position+Vector2(24,12); s.tribes.war.cooldowns[fighter.enemy_id]=1
	s.monsters.respond(0.1)
	check(s.monsters.is_protected(miner) and s.monsters.handles(fighter),"warrior engages the monster while covering the miner")
	# The player can actually dispatch and recall these escorts through the NPC menu.
	goblin.hp=0; goblin.refresh(); fighter.position=s.interiors.rooms.mine.exit_point()+Vector2(0,-8)
	s.tribes.open("npc",fighter.enemy_id)
	check(s.tribes.snapshot().recipes.any(func(r: Dictionary)->bool:return r.id=="guard:mine" and r.enabled),"friendly combat NPC offers the mine escort command")
	check(s.tribes.perform("guard:mine") and s.monsters.orders.get(fighter.enemy_id)=="mine","mine escort order saves atomically")
	s.production.close()
	check(s.monsters.order_guard(fighter.enemy_id,true),"escort recall command is accepted")
	s.monsters.respond(0.1); s.monsters.respond(0.1)
	check(fighter.room_id=="" and not s.monsters.orders.has(fighter.enemy_id),"recalled escort exits the cave via stairs")
	# Defeated goblin waits a full online timer and never respawns beside a character.
	var record: Dictionary=s.monsters.slots[sample_id]
	check(record.dead and float(record.ready_at)-s.monsters.online>299,"death starts a five-minute online respawn timer")
	var saved_clock: float=s.monsters.online; get_tree().paused=true; s.monsters.advance(20)
	check(s.monsters.online==saved_clock,"pause never advances goblin respawn time"); get_tree().paused=false
	move_player(Vector2(record.home[0],record.home[1])); s.monsters.online=float(record.ready_at)+1; s.monsters._focus()
	check(s.monsters.slots[sample_id].dead,"nearby player blocks an otherwise due respawn")
	await extended_checks(actor,base)
	# Persist a living encounter, its independent cooldown and its mine guard order.
	clear_monsters(); goblin=make_monster(4,base+Vector2(80,0)); goblin.hp=15; goblin.cooldowns={"heavy":3.0,"roots":6.0}; goblin.set_physics_process(false)
	s.monsters.orders[fighter.enemy_id]="mine"; s.monsters.online=123.5
	check(s.persistence.save_now(),"goblins and escort orders save with the full game state")
	game.queue_free(); await frames(5); await load_game()
	check(s.monsters.units.has(sample_id) and s.monsters.units[sample_id].level==4 and s.monsters.units[sample_id].hp==15,"actual reload preserves goblin level and health")
	check(absf(float(s.monsters.units[sample_id].cooldowns.heavy)-3.0)<0.2 and s.monsters.orders.get("home:probe_fighter")=="mine","reload preserves cooldown and mine escort order")
	# Goblins do not keep an otherwise empty mine alive or leave freed-body references.
	var actors: Array=s.world.controllable.duplicate()+s.tribes.population.members.keys().map(func(id: String)->Node:return s.tribes.population.node(id))
	for person: Node in actors:
		if is_instance_valid(person) and person.room_id=="mine": s.interiors.leave(person,s.world.objects,s.mining.DOOR+Vector2(0,10))
	s._sync_view(); await frames(3)
	check(not s.interiors.rooms.has("mine") and is_instance_valid(s.monsters.units[sample_id]) and s.monsters.units[sample_id].get_parent()==null,"last character exit releases mine while safely parking its goblins")
	s.interiors.enter(s.world.active_resident,s.world.home_data("mine")); s._sync_view(); await frames(3)
	check(s.monsters.units[sample_id].get_parent()==s.interiors.rooms.mine.objects,"returning to mine reattaches the saved monster safely")
	var visible_goblin: Node=s.monsters.units[sample_id]; visible_goblin.set_physics_process(false)
	move_player(visible_goblin.position+Vector2(22,4)); s.magic.ensure(actor_id).torch={"item":"torch","count":1,"lit":true,"fuel_left":600.0,"burn_left":300.0}; s.torches.refresh_light()
	await screenshot("goblin-mine")
	game.queue_free(); await frames(5)
	var result: Dictionary={"version":ProjectSettings.get_setting("application/config/version"),"display":DisplayServer.get_name(),"checks":checks,"failures":failures,"metrics":metrics}
	var file:=FileAccess.open(directory+"/result.json",FileAccess.WRITE); file.store_string(JSON.stringify(result,"  "))
	print("GOBLINS_OK" if failures.is_empty() else "GOBLINS_FAILED"," checks=",checks," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
