# Exercises all branch spells in the real game plus saves, rewards, construction and failure rollback.
extends Node
const Rules := preload("res://features/magic/branch_catalog.gd")
const Houses := preload("res://features/construction/house_rules.gd")
var game: Node
var s: Node
var directory := ""
var failures: Array[String]=[]
var checks := 0
var capture := false
var base := Vector2(1000,848)
func _enter_tree() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	directory=OS.get_environment("AIU5_PROBE_DIRECTORY"); assert(directory!="")
	OS.set_environment("AIU5_STATE_PATH",directory+"/state.json")
	OS.set_environment("AIU5_PROFILE_PATH",directory+"/names.cfg")
	capture=OS.get_environment("AIU5_CAPTURE")=="true"
	get_tree().create_timer(100,true).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func frames(n := 3) -> void:
	for i in range(n): await get_tree().process_frame
func count(item: String) -> int:
	var result := 0
	for slot: Dictionary in s.inventory.ensure_bag("ali"):
		if slot.get("item","")==item: result+=int(slot.count)
	return result
func screenshot(name: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(directory+"/"+name+".png")==OK,"capture "+name)
func load_game() -> void:
	game=load("res://scenes/main.tscn").instantiate(); get_tree().root.add_child(game)
	s=game.get_node("Session")
	s.simulation.set_process(false); s.simulation.reset(); s.persistence.set_process(false)
	s.resources.set_process(false); s.world.streamer.set_process(false); s.forest.set_process(false)
	for actor in s.world.residents: actor.set_physics_process(false)
	for enemy in s.combat.enemies.values(): enemy.set_physics_process(false)
	await frames()
func setup(element: String) -> void:
	s.close_attributes(); s.production.close(); s.inventory.close(); s.roster_open=false
	s.magic.branches.restore({}); s.magic.enchants.restore({}); s.magic.skills.restore({})
	var state: Dictionary=s.magic.Catalog.fresh()
	state.element=element; state.level=100; state.skill_points=205
	state.unlocked=s.magic.Catalog.TRUNK.duplicate()
	for rule: Dictionary in Rules.entries(element): state.branch_unlocked.append(rule.id)
	state.crystal_milestone=20; state.crystal_pending=0
	s.magic.states.ali=state
	s.vitals.ensure("ali").merge({"life":8.0,"mana":505.0,"hunger":5.0,"thirst":5.0},true)
	var actor: Node=s.world.active_resident
	if actor.room_id!="": s.interiors.leave(actor,s.world.objects,base)
	actor.position=base; actor.dead=false
	s._sync_view(); s.refresh_interface()
	s.world.camera.force_update_scroll()
	for enemy: Node in s.combat.enemies.values(): enemy.position=Vector2(1900,1500); enemy.hp=100; enemy.refresh()
func enemy_at(at: Vector2, id := "tribe:1") -> Node:
	var enemy: Node=s.combat.enemies[id]
	if enemy.get_parent()==null: s.world.objects.add_child(enemy)
	enemy.position=at; enemy.hp=100; enemy.territory=Rect2(); enemy.refresh()
	return enemy
func cast(id: String, target: Vector2) -> bool:
	var before: float=s.vitals.ensure("ali").mana
	var ok: bool=s.magic.branches.cast(id,target)
	if not ok: print("REJECT ",id," ",s.notice)
	check(ok,"real cast "+id)
	if ok:
		check(is_equal_approx(before-s.vitals.ensure("ali").mana,float(Rules.entry(id).mana_cost)),"mana cost "+id)
		var visible_cast := false
		for node: Node in s.magic.branches.visuals.values():
			if node.kind=="cast" and node.record.get("skill","")==id and node.record.element==Rules.entry(id).element: visible_cast=true
		check(visible_cast,"actual elemental casting visual "+id)
	return ok
func record_house(kind: String, at: Vector2, initial := true) -> String:
	var id: String="built:"+str(s.construction.next_id); s.construction.next_id+=1
	var level: int=Houses.HOUSE_LEVELS[kind]
	var stats: Dictionary=Houses.stats(level)
	s.construction.records[id]={"id":id,"kind":kind,"at":[at.x,at.y],"level":level,"hp":stats.hp,"max_hp":stats.hp,"defense":stats.defense,"crystals":{},"job":{"level":level,"initial":initial,"duration":30.0,"remaining":30.0,"boost_left":0.0,"boost_rate":1.0}}
	s.construction._attach(id); return id
func run() -> void:
	await load_game()
	# Real learning and old-save point-budget checks.
	setup("wood")
	var state: Dictionary=s.magic.ensure("ali")
	state.branch_unlocked=[]; state.level=11; state.skill_points=50
	check(not s.magic.unlock("ali","wood_build_1"),"level eleven rejects branch one")
	state.level=12; state.skill_points=5
	check(not s.magic.unlock("ali","wood_build_1"),"not enough skill points preserves state")
	state.skill_points=15
	check(s.magic.unlock("ali","wood_build_1") and s.magic.ensure("ali").skill_points==0,"learn first branch pays fifteen")
	check(not s.magic.unlock("ali","wood_build_1"),"duplicate learning rejected")
	state=s.magic.ensure("ali"); state.level=20; state.skill_points=25
	check(not s.magic.unlock("ali","wood_battle_2"),"second rank requires first in same branch")
	var clean: Dictionary=s.magic.Catalog.restore_state({"element":"wood","level":12,"unlocked":s.magic.Catalog.TRUNK,"branch_unlocked":["wood_build_1","wood_build_2"],"skill_points":999})
	check(clean.branch_unlocked.is_empty() and clean.skill_points==5,"invalid overspent old save cannot mint branch points")
	# Range recovery, lifespan, combat and distinct rates for all elements.
	for element: String in Rules.ELEMENTS:
		setup(element)
		var id := element+"_build_1"
		check(cast(id,base+Vector2(40,0)),"facility cast "+element)
		var f: Dictionary=s.magic.branches.facilities.ali
		check(f.remaining==600,"facility lifespan "+element)
		s.world.active_resident.position=base+Vector2(-41,0)
		var mana: float=s.vitals.ensure("ali").mana
		s.magic.branches.advance(5)
		check(s.vitals.ensure("ali").mana==mana,"81 pixels gives no recovery "+element)
		s.world.active_resident.position=base+Vector2(-40,0)
		s.magic.branches.advance(5)
		check(s.vitals.ensure("ali").mana==mana+1,"80 pixel boundary restores one mana "+element)
		check(is_equal_approx(s.vitals.ensure("ali").life,9 if element=="wood" else 8),"five second life rule "+element)
		s.magic.branches.advance(5)
		if element in ["water","fire"]: check(s.vitals.ensure("ali").life==9,"ten second life rule "+element)
		if element=="water": check(s.vitals.ensure("ali").thirst==7,"water thirst five second ticks")
		if element=="fire": check(s.vitals.ensure("ali").hunger==6 and s.magic.branches.furnace_rate("ali")==1.4,"fire hunger ten seconds and furnace rate")
		s.magic.branches.note_combat("ali"); mana=s.vitals.ensure("ali").mana
		s.magic.branches.advance(9)
		check(s.vitals.ensure("ali").mana==mana,"combat blocks recovery "+element)
		check(not s.magic.branches.cast(id,base+Vector2(60,30)),"combat blocks new facility "+element)
		s.magic.branches.advance(700)
		check(s.magic.branches.facilities.is_empty(),"facility expires after online ten minutes "+element)
	# Permanent grass, reproducible rolls, no accumulation and harvesting.
	setup("wood"); check(cast("wood_build_2",base+Vector2(40,0)),"special herb grass")
	s.magic.branches.advance(120*40)
	check(s.magic.branches.bushes.ali.ready.size()==3,"all three herbs can spawn at eighteen percent")
	for amount in s.magic.branches.bushes.ali.ready.values(): check(amount==1,"unpicked herb does not accumulate")
	s.world.active_resident.position=base+Vector2(40,0)
	check(s.magic.branches.interact("bush:ali"),"real herb gathering transaction")
	check(count("ginseng")>=1 and count("reishi")>=1 and count("goji")>=1,"all herb items transferred")
	# Paid construction and acceleration share one real job.
	setup("wood")
	var house := record_house("wood_house",base+Vector2(-48,-131))
	check(s.world.home_data(house).building,"under construction is recorded as inaccessible")
	s.construction.advance(10)
	check(s.construction.records[house].job.remaining==20,"real online construction progress")
	check(cast("wood_build_3",base+Vector2(0,-60)),"wood instant completion")
	check(s.construction.records[house].job.is_empty() and not s.world.home_data(house).building,"wood completes construction")
	setup("water")
	s.homestead.plots.append({"x":base.x+32,"y":base.y-8,"w":16.0,"h":16.0,"age":100.0,"dry":true,"crop":"","growth":0.0})
	check(cast("water_build_2",base+Vector2(40,0)),"irrigation cast")
	s.magic.branches.advance(0.5)
	check(not s.homestead.plots.back().dry and s.homestead.plots.back().age==0,"irrigation actually waters adjacent field")
	s.homestead.plots.pop_back(); s.homestead.refresh()
	var water_house := record_house("stone_house",base+Vector2(60,-80))
	check(cast("water_build_3",base+Vector2(90,-20)),"water wheel cast")
	s.construction.advance(10)
	check(s.construction.records[water_house].job.remaining==15,"water wheel fifty percent faster")
	s.construction.finish_job(water_house)
	setup("fire")
	var fire_house := record_house("wood_house",base+Vector2(-150,-80))
	check(cast("fire_build_2",base+Vector2(-100,-10)),"welding cast")
	check(s.construction.records[fire_house].job.remaining==21,"welding thirty percent of total progress")
	s.construction.finish_job(fire_house)
	var pit_enemy: Node=enemy_at(base+Vector2(40,80))
	check(cast("fire_build_3",pit_enemy.position),"earth fire cellar cast")
	s.magic.branches.advance(2.5); check(pit_enemy.hp==100,"pit does not damage early")
	s.magic.branches.advance(0.5); check(pit_enemy.hp==96,"pit four damage after three seconds")
	setup("earth"); check(cast("earth_build_2",base),"survey cast")
	check(not s.magic.branches.buffs.ali.get("survey",{}).is_empty(),"survey timer exists")
	check(cast("earth_build_3",base+Vector2(48,40)),"stone array cast")
	s.world.active_resident.position=base+Vector2(48,40)
	check(is_equal_approx(s.magic.damage_rate("ali"),0.9),"stone array extra ten percent")
	# Combat branch actual damage and controls, one reset per spell.
	base=Vector2(1352,648)
	for element: String in Rules.ELEMENTS:
		for rank in range(1,4):
			setup(element)
			var id := "%s_battle_%d" % [element,rank]
			var enemy: Node=enemy_at(base+Vector2(50,0))
			await get_tree().physics_frame
			await get_tree().physics_frame
			check(cast(id,enemy.position),"battle action "+id)
			match id:
				"wood_battle_1": check(enemy.hp==98 and s.magic.branches.rooted(enemy.enemy_id),"vine damage and root")
				"wood_battle_2": check(enemy.hp==94 and is_equal_approx(s.magic.branches.speed_rate(enemy.enemy_id),0.7),"thorn cone and slow")
				"wood_battle_3": s.magic.branches.advance(6); check(enemy.hp==82,"strangle six ticks")
				"water_battle_1": check(enemy.hp==92 and enemy.position.x>base.x+50,"water bolt hit and knockback")
				"water_battle_2": check(enemy.hp==95 and is_equal_approx(s.magic.branches.speed_rate(enemy.enemy_id),0.6),"cold wave hit and slow")
				"water_battle_3":
					check(s.magic.branches.rooted(enemy.enemy_id),"ice freezes initially")
					s.magic.branches.advance(3); check(not s.magic.branches.rooted(enemy.enemy_id) and is_equal_approx(s.magic.branches.speed_rate(enemy.enemy_id),0.7),"ice transitions to slow")
				"fire_battle_1":
					s.magic.branches.advance(1); check(enemy.hp<=90,"projectile hits for ten")
					s.magic.branches.advance(3); check(enemy.hp==84,"fireball burns for six more")
				"fire_battle_2": check(enemy.hp==92 and s.vitals.ensure("ali").life==6,"explosion hit and self recoil")
				"fire_battle_3": check(enemy.hp==88,"wind rectangular hit twelve")
				"earth_battle_1": check(enemy.hp==91 and enemy.position.x>base.x+50,"stone hits and knocks back")
				"earth_battle_2": check(enemy.hp==90 and s.magic.branches.rooted(enemy.enemy_id),"ground smash hit and root")
				"earth_battle_3":
					check(s.magic.branches.rooted(enemy.enemy_id),"petrification holds")
					s.combat.apply_skill_damage(enemy,19,"ali"); check(s.magic.branches.rooted(enemy.enemy_id),"nineteen injury keeps petrification")
					s.combat.apply_skill_damage(enemy,1,"ali"); check(not s.magic.branches.rooted(enemy.enemy_id),"twenty injury breaks petrification")
	# All defense spells, real injury pathways and the stone-array exception.
	for element: String in Rules.ELEMENTS:
		for rank in range(1,4):
			setup(element)
			var id := "%s_guard_%d" % [element,rank]
			var enemy: Node=enemy_at(base+Vector2(60,0))
			check(cast(id,enemy.position),"guard action "+id)
			match id:
				"wood_guard_1": check(is_equal_approx(s.magic.damage_rate("ali"),0.75),"bark twenty five percent")
				"wood_guard_2": check(is_equal_approx(s.magic.damage_rate("ali"),0.6),"roots forty percent")
				"wood_guard_3": check(s.vitals.ensure("ali").life==11,"healing uses passive max life eleven")
				"water_guard_1": s.vitals.hurt("ali",15); check(s.vitals.ensure("ali").life==8,"membrane absorbs actual injury")
				"water_guard_2": check(is_equal_approx(s.vitals.ensure("ali").life,9.5),"clean flow restores fifteen percent")
				"water_guard_3": check(is_equal_approx(s.magic.damage_rate("ali",{"kind":"ranged"}),0.7),"tidal ranged rate only")
				"fire_guard_1":
					enemy.position=base+Vector2(30,0); s.magic.branches.advance(1)
					check(enemy.hp==97 and is_equal_approx(s.magic.branches.speed_rate(enemy.enemy_id),0.8),"fire wall damage and slow")
				"fire_guard_2":
					s.vitals.hurt("ali",2,{"kind":"melee","enemy":enemy.enemy_id})
					check(is_equal_approx(s.vitals.ensure("ali").life,6.8) and is_equal_approx(enemy.hp,99.7),"shell real melee reduction and reflect")
				"fire_guard_3":
					s.vitals.hurt("ali",100)
					check(s.vitals.ensure("ali").life==5 and s.magic.branches.cooldowns["ali:fire_guard_3"]==300,"ember lethal save and five minute lock")
				"earth_guard_1": check(is_equal_approx(s.magic.damage_rate("ali"),0.8),"stone skin twenty percent")
				"earth_guard_2": check(s.magic.branches.barrier_blocks(base,base+Vector2(70,0)),"stone wall intercepts ranged segment")
				"earth_guard_3": check(is_equal_approx(s.magic.damage_rate("ali"),0.5) and s.magic.branches.immobile("ali") and s.magic.branches.immune_control("ali"),"earth embrace protection immobility and immunity")
	setup("wood")
	check(cast("wood_guard_1",base),"stack bark")
	check(cast("wood_guard_2",base),"stack roots")
	check(s.magic.damage_rate("ali")==0.5,"ordinary remaining damage stacking capped fifty")
	s.magic.branches._area("ali","array",base,60,Vector2(48,48),Vector2.RIGHT)
	check(is_equal_approx(s.magic.damage_rate("ali"),0.45),"array highest total fifty five")
	s.magic.branches._area("heya","array",base,60,Vector2(48,48),Vector2.RIGHT)
	check(is_equal_approx(s.magic.damage_rate("ali"),0.45),"multiple arrays count only once")
	var slowed: Node=enemy_at(base+Vector2(60,0))
	s.magic.branches._status(slowed,"ali","thorns",3,{"slow":0.3})
	s.magic.branches._status(slowed,"heya","thorns",3,{"slow":0.3})
	check(is_equal_approx(s.magic.branches.speed_rate(slowed.enemy_id),0.7),"same skill from two casters cannot stack slow")
	s.magic.branches._status(slowed,"ali","strangle",6,{"slow":0.5,"dot":3})
	check(is_equal_approx(s.magic.branches.speed_rate(slowed.enemy_id),0.4),"distinct thirty and fifty percent slows cap sixty")
	s.magic.branches.statuses.clear()
	s.magic.branches._status(slowed,"ali","thorns",3,{"slow":0.3})
	s.magic.branches._status(slowed,"ali","chill",4,{"slow":0.4})
	check(is_equal_approx(s.magic.branches.speed_rate(slowed.enemy_id),0.42),"distinct thirty and forty slows multiply remaining speed to forty two")
	# New shield casts do not leave weaker shields waiting behind the strongest one.
	s.magic.branches._buff_set("ali","membrane",15,{"shield":20.0})
	s.magic.branches._buff_set("ali","tide",12,{"shield":60.0})
	check(s.magic.branches.buffs.ali.membrane.shield==0,"stronger shield replaces weaker reserve")
	check(s.magic.branches.absorb("ali",65)==5,"two shield skills cannot create eighty absorption")
	s.magic.branches._buff_set("ali","bark-from-ally",10,{"rate":0.75,"source":"wood_guard_1"})
	check(is_equal_approx(s.magic.branches.ordinary_rate("ali"),0.45),"same bark source cannot multiply a second time alongside roots")
	# True UI uses signals, shows all nine entries and selects a usable skill.
	s.show_attributes("ali"); s.refresh_interface(); await frames()
	var ui: Node=game.get_node("Attributes")
	ui._show_page("tree"); ui.branches[0].pressed.emit(); await frames()
	check(ui.branch_panel.visible and "生命树" in ui.branch_cards[0].title.text,"real construction branch UI")
	ui.branch_cards[0].select.pressed.emit()
	check(s.magic.ensure("ali").branch_selected=="wood_build_1","real UI selects P skill")
	await screenshot("wood-construction-branch")
	ui.branches[1].pressed.emit(); await frames(); await screenshot("wood-battle-branch")
	s.close_attributes()
	# Low mana, cooldown and failed save reject without losing effects or points.
	setup("water"); s.vitals.ensure("ali").mana=39
	check(not s.magic.branches.cast("water_guard_1",base) and s.vitals.ensure("ali").mana==39,"mana deficiency does not spend")
	s.vitals.ensure("ali").mana=100; check(cast("water_guard_1",base),"funded shield")
	check(not s.magic.branches.cast("water_guard_1",base) and s.vitals.ensure("ali").mana==60,"cooldown no spend")
	s.magic.branches.advance(3)
	var path: String=s.inventory.path
	var blocked := directory+"/blocked"; DirAccess.make_dir_recursive_absolute(blocked); s.inventory.path=blocked
	check(not s.magic.branches.cast("water_guard_1",base),"failed save rolls back cast")
	s.inventory.path=path
	check(s.vitals.ensure("ali").mana==60 and is_equal_approx(s.magic.branches.buffs.ali.membrane.remaining,12),"rollback restores mana and original effect timer")
	# Crystal cross-level rewards, original-character migration and repeat-load idempotence.
	setup("earth")
	s.magic.states.ali=s.magic.Catalog.fresh(); s.magic.ensure("ali").element="earth"
	var crystal_before := count("earth_crystal")
	check(s.magic.award_points("ali",900),"experience jumps several levels in one transaction")
	check(s.magic.ensure("ali").level>=10 and count("earth_crystal")==crystal_before+2,"five and ten milestones each give one crystal")
	check(s.persistence.save_now() and count("earth_crystal")==crystal_before+2,"repeat save cannot duplicate crystals")
	var old: Dictionary=s.magic.Catalog.restore_state({"element":"wood","level":20})
	check(old.crystal_pending==4 and old.crystal_milestone==4,"old level twenty gets four pending crystals")
	var again: Dictionary=s.magic.Catalog.restore_state(old)
	check(again.crystal_pending==4,"repeat restore does not duplicate pending crystals")
	var bag_before: Array=s.inventory.ensure_bag("ali").duplicate(true)
	s.inventory.bags.ali=[]
	for i in range(21): s.inventory.bags.ali.append({"item":"book","count":10})
	s.magic.ensure("ali").crystal_pending=1
	check(not s.magic.claim_crystals("ali") and s.magic.ensure("ali").crystal_pending==1,"full bag retains pending crystal")
	s.inventory.bags.ali=bag_before
	check(s.magic.claim_crystals("ali") and s.magic.ensure("ali").crystal_pending==0,"pending crystal can be claimed after making room")
	var controlled_enemy: Node=enemy_at(base+Vector2(50,0))
	s.magic.branches._status(controlled_enemy,"ali","root",2,{"root":2.0})
	s.magic.branches.advance(2)
	s.magic.branches._status(controlled_enemy,"ali","stone",4,{"root":4.0,"break_damage":0.0})
	check(not s.magic.branches.rooted(controlled_enemy.enemy_id),"ten second target lock blocks chaining different controls")
	s.magic.branches.advance(8)
	s.magic.branches._status(controlled_enemy,"ali","root",2,{"root":2.0})
	check(s.magic.branches.rooted(controlled_enemy.enemy_id),"control available at ten seconds")
	# Real upgrades pay increasing material recipes and reserve the crystal until completion.
	setup("earth")
	s.inventory.bags.ali=[]
	for i in range(21): s.inventory.bags.ali.append({})
	check(s.inventory.exchange("ali",{}, {"wood":500,"stone":500,"iron_ore":100,"earth_crystal":4,"building_bench":1}),"house testing resources fit")
	var at := Vector2(1300,900)
	var bench: Node=s.grounds.add_fixture({"id":"outdoors:branch-test-bench","kind":"building_bench","at":[at.x,at.y],"size":[96,80]})
	s.world.active_resident.position=bench.position+Vector2(0,14); s._sync_view()
	check(s.construction.build(s.world.active_resident,bench,"wood_house"),"real house build pays wood")
	var real_house := "built:"+str(s.construction.next_id-1)
	check(not s.construction.records[real_house].job.is_empty(),"new house has real thirty second job")
	s.construction.advance(30)
	check(s.construction.records[real_house].level==1 and s.construction.records[real_house].job.is_empty(),"house completes at thirty seconds")
	s.world.active_resident.position=s.world.home_data(real_house).door; s._sync_view()
	for level in range(2,5):
		var wood_before := count("wood")
		var expected: Dictionary=Houses.costs(level,"earth")
		check(s.construction.upgrade_near("earth"),"paid upgrade "+str(level))
		check(count("wood")==wood_before-int(expected.wood),"upgrade escalating wood "+str(level))
		check(is_equal_approx(s.construction.records[real_house].job.duration,30.0*pow(1.3,level-2)),"thirty percent construction time growth "+str(level))
		if level==4: check(int(s.construction.records[real_house].crystals.get("earth",0))==0,"reserved crystal not active before completion")
		s.construction.finish_job(real_house)
	check(s.construction.records[real_house].level==4 and s.construction.records[real_house].crystals.earth==1,"completed fourth level crystal armor")
	s.production.open_upgrade(); s.refresh_interface(); await frames()
	check(s.production.opened,"real upgrade menu opens")
	s.production.close()
	var house_before: Dictionary=s.construction.records[real_house].duplicate(true)
	var resources_before: Array=s.inventory.ensure_bag("ali").duplicate(true)
	s.inventory.bags.ali=[]
	for i in range(21): s.inventory.bags.ali.append({})
	check(not s.construction.upgrade_near("earth") and s.construction.records[real_house].job.is_empty(),"insufficient upgrade materials do not start a job")
	s.inventory.bags.ali=resources_before
	var original_path: String=s.inventory.path
	var bad_dir := directory+"/blocked-upgrade"; DirAccess.make_dir_recursive_absolute(bad_dir)
	s.inventory.path=bad_dir
	check(not s.construction.upgrade_near("earth"),"failed upgrade save rejects")
	s.inventory.path=original_path
	check(s.inventory.ensure_bag("ali")==resources_before and s.construction.records[real_house].job.is_empty(),"failed upgrade restores paid materials and job")
	var hp: float=s.construction.records[real_house].hp
	check(s.construction.hit(real_house,10,false,"earth"),"actual elemental building hit")
	check(is_equal_approx(hp-s.construction.records[real_house].hp,7.84),"building twenty percent armor plus two percent earth crystal")
	var chief: Node=s.combat.enemies["yunye:chief"]
	chief.position=s.world.home_data(real_house).door+Vector2(0,8); chief.territory=Rect2(); chief.cooldown=0
	if chief.get_parent()==null: s.world.objects.add_child(chief)
	s.magic.ensure(chief.chief_id).element=""
	s.interiors.enter(s.world.active_resident,s.world.home_data(real_house))
	hp=s.construction.records[real_house].hp
	chief._physics_process(0)
	check(is_equal_approx(hp-s.construction.records[real_house].hp,7.84),"chief element comes from tribe even when player progression restores without NPC state")
	s.interiors.leave(s.world.active_resident,s.world.objects,s.world.home_data(real_house).door)
	s._sync_view()
	s.production.open_upgrade(); s.refresh_interface(); await frames()
	check(s.production.opened and game.get_node("Workshop").confirm_button.text=="确认升级","upgrade UI correct action")
	await screenshot("house-upgrade")
	s.production.close()
	# Durable restart contains learned branches, facilities, permanent grass and house level.
	setup("wood"); check(cast("wood_build_1",base+Vector2(40,0)),"saved facility")
	s.magic.branches.advance(13)
	check(cast("wood_build_2",base+Vector2(80,30)),"saved herb bush")
	check(s.persistence.save_now(),"new systems saved")
	s.production.smelting.remaining=30.0
	s.magic.branches.facilities.ali.element="fire"
	s.world.active_resident.position=s.magic.branches.pos(s.magic.branches.facilities.ali)
	s.production.elapse(10)
	check(is_equal_approx(s.production.smelting.remaining,16),"nearby fire facility accelerates actual smelting forty percent")
	s.magic.branches.facilities.ali.element="wood"
	check(s.persistence.save_now(),"modified validation state saved")
	game.queue_free(); await frames(); await load_game()
	check(s.magic.ensure("ali").branch_unlocked.size()==9,"all learned branches survive actual restart")
	check(s.magic.branches.facilities.has("ali") and is_equal_approx(s.magic.branches.facilities.ali.remaining,587),"facility saved remaining lifetime")
	check(s.magic.branches.bushes.has("ali"),"permanent herb bush survives restart")
	check(s.construction.records.has(real_house) and s.construction.records[real_house].level==4 and s.construction.records[real_house].crystals.earth==1,"house level and crystal survive restart")
	setup("wood")
	check(s.magic.select_branch("ali","wood_build_1"),"select construction skill for actual keyboard input")
	var target := base+Vector2(40,0)
	var motion := InputEventMouseMotion.new(); motion.position=s.world.active_resident.get_canvas_transform()*target
	get_viewport().push_input(motion,true)
	for pressed: bool in [true,false]:
		var key := InputEventKey.new(); key.keycode=KEY_P; key.physical_keycode=KEY_P; key.pressed=pressed
		get_viewport().push_input(key,true); await frames()
	# The native window polls the OS cursor; injected motion cannot replace that read.
	# Verify real key routing and real target validation separately without moving the user's pointer.
	check(s.magic.branches.facilities.has("ali") or (s.notice=="请指向户外120世界像素内可见空地。" and s.vitals.ensure("ali").mana==505),"actual P routes selected skill with real cursor range validation")
	if not s.magic.branches.facilities.has("ali"): check(s.magic.branches.cast(str(s.magic.ensure("ali").branch_selected),target),"valid world target creates selected skill")
	s.production.close()
	s.world.active_resident.position=s.world.home_data(real_house).door; s._sync_view()
	for pressed: bool in [true,false]:
		var key := InputEventKey.new(); key.keycode=KEY_U; key.physical_keycode=KEY_U; key.pressed=pressed
		Input.parse_input_event(key); await frames()
	check(s.production.opened and s.production.mode=="upgrade","actual U keyboard action opens house upgrade")
	s.production.close()
	if s.magic.branches.facilities.has("ali"):
		var life_left: float=s.magic.branches.facilities.ali.remaining
		s.simulation.reset(); s.simulation.set_process(true); get_tree().paused=true
		await get_tree().create_timer(0.65,true).timeout
		check(s.magic.branches.facilities.ali.remaining==life_left,"real tree pause does not advance facility lifespan")
		get_tree().paused=false; s.simulation.set_process(false); s.simulation.reset()
	await screenshot("gameplay-branches")
	print("BRANCHES_SMOKE_OK checks=%d" % checks if failures.is_empty() else "BRANCHES_SMOKE_FAILED "+str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
