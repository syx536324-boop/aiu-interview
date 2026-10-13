# Exercises elemental skills through the real session, including migration, timing, targets and save rollback.
extends Node
const Catalog := preload("res://features/magic/catalog.gd")
const Cave := preload("res://features/mining/cave_catalog.gd")
var failures: Array[String]=[]
var checks := 0
var game: Node
var s: Node
var skill: Node
var base: Dictionary
var path := ""
var root: Window:
	get: return get_tree().root
func _enter_tree() -> void:
	var directory := OS.get_environment("AIU5_SKILLS_PROBE_DIR")
	if directory=="": directory="res://.runtime/skills-"+str(Time.get_ticks_usec())
	path=directory+"/state.json"
	OS.set_environment("AIU5_STATE_PATH",path)
	OS.set_environment("AIU5_PROFILE_PATH",path+".names")
	OS.set_environment("AIU5_WORLD_PROFILE","starter")
	get_tree().create_timer(120,true).timeout.connect(func() -> void: push_error("ELEMENTAL_TIMEOUT"); get_tree().quit(2))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func frames(n:=3) -> void:
	for i in range(n): await get_tree().physics_frame
	await get_tree().process_frame
func reset(element: String, ranks:=5) -> void:
	s.inventory.apply_data(base)
	s.persistence.restore_session(base.session)
	s.simulation.set_process(false); s.simulation.reset(); s.persistence.set_process(false)
	s.production.close(); s.editor.close(); s.inventory.close(); s.attributes_id=""; s.roster_open=false; s.awakening_open=false
	for actor in s.world.residents: actor.set_physics_process(false)
	for animal in s.livestock.animals: animal.set_physics_process(false)
	for enemy in s.combat.enemies.values(): enemy.set_physics_process(false)
	var state := Catalog.fresh()
	state.element=element; state.level=11; state.skill_points=50
	s.magic.states.ali=state
	for i in range(ranks): check(s.magic.unlock("ali","trunk_"+str(i+1)),"learn sequential "+element+" "+str(i+1))
	s.vitals.ensure("ali").mana=10
	s.vitals.ensure("ali").life=s.vitals.max_life("ali")
	s.vitals._sync_actors()
func give(items: Dictionary) -> void:
	s.inventory.bags.ali=s.inventory._sanitize_slots([])
	check(s.inventory.exchange("ali",{},items),"prepare test inventory")
func count(item: String) -> int:
	var total:=0
	for record: Dictionary in s.inventory.ensure_bag("ali"):
		if record.get("item","")==item: total+=int(record.count)
	return total
func position(at: Vector2) -> void:
	s.world.active_resident.position=at
	s._sync_view()
func open_area() -> Vector2:
	var actor: CharacterBody2D=s.world.active_resident
	for y in range(600,1400,96):
		for x in range(700,1800,96):
			var at := Vector2(x,y)
			if s.grounds.land_error(Rect2(at-Vector2(20,25),Vector2(160,80)),actor)=="": return at
	return Vector2(1400,600)
func enemy_at(at: Vector2) -> CharacterBody2D:
	var enemy: CharacterBody2D=s.combat.enemies["tribe:1"]
	if enemy.get_parent()==null: s.world.objects.add_child(enemy)
	enemy.position=at; enemy.hp=30; enemy.thirst=10; enemy.refresh(); enemy.set_physics_process(false)
	return enemy
func weapon(item:="wood_sword") -> void:
	give({item:1})
	check(s.magic.equip_weapon("ali",item),"equip weapon "+item)
func blocked_path() -> String:
	var blocked := path.get_base_dir()+"/blocked"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked))
	return blocked
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	s=game.get_node("Session"); skill=s.magic.skills
	s.simulation.set_process(false); s.simulation.reset(); s.persistence.set_process(false)
	await frames()
	base=s.inventory.export_data()
	# Six-node version-1 migration retains the first five and refunds exactly ten points.
	var old := Catalog.fresh()
	old.element="wood"; old.level=13; old.skill_points=0; old.unlocked=["trunk_1","trunk_2","trunk_3","trunk_4","trunk_5","trunk_6"]
	var migrated := Catalog.restore_state(old)
	check(migrated.unlocked.size()==5 and migrated.skill_points==10,"six-node save refunds removed node")
	check(Catalog.restore_state(migrated)==migrated,"migration does not refund twice")
	var ui: Node=game.get_node("Attributes")
	check(ui.skill_buttons.size()==5,"actual UI contains five trunk buttons")
	# All passives affect their specific stat only, preserve fractional health and respect inactive freezing.
	reset("wood",0)
	s.vitals.ensure("ali").life=6
	var old_path: String=s.inventory.path
	s.inventory.path=blocked_path()
	check(not s.magic.unlock("ali","trunk_1"),"learning fails on save failure")
	s.inventory.path=old_path
	check(s.vitals.ensure("ali").life==6 and s.magic.ensure("ali").unlocked.is_empty(),"failed learning rolls back passive life bonus")
	check(s.magic.unlock("ali","trunk_1") and s.vitals.ensure("ali").life==7 and s.vitals.max_life("ali")==11,"wood passive raises health and cap once")
	check(not s.magic.unlock("ali","trunk_1") and s.vitals.ensure("ali").life==7,"duplicate passive never adds life")
	reset("water"); s.vitals.advance(180)
	check(s.vitals.ensure("ali").hunger==9 and s.vitals.ensure("ali").thirst==10,"water slows thirst but not hunger")
	s.vitals.advance(20)
	check(s.vitals.ensure("ali").thirst==9,"water 0.9 rate reaches threshold at 200 seconds")
	reset("fire"); s.vitals.advance(180)
	check(s.vitals.ensure("ali").hunger==10 and s.vitals.ensure("ali").thirst==9,"fire slows hunger but not thirst")
	reset("earth"); check(is_equal_approx(s.world.active_resident.run_multiplier,1.1),"earth run bonus is 10 percent")
	s.vitals.ensure("ali").ill=true; s.vitals._sync_actors()
	check(is_equal_approx(s.world.active_resident.run_multiplier,0.77),"running passive composes with illness")
	# Common empower: actual weapon damage, refresh, expiration, origin and mana rollback for every element.
	for element in ["wood","water","fire","earth"]:
		reset(element); weapon()
		check(skill.cast(2,Vector2.ZERO) and s.vitals.ensure("ali").mana==5 and s.magic.weapon_snapshot("ali").attack==3,"empower costs five and adds two "+element)
		skill.advance(60)
		s.vitals.ensure("ali").mana=10
		check(skill.cast(2,Vector2.ZERO) and skill.attack_bonus("ali")==2 and skill.buffs.ali.empower==120,"empower refresh never stacks "+element)
		skill.advance(119.5); check(skill.attack_bonus("ali")==2,"empower lasts full 120 seconds "+element)
		skill.advance(0.5); check(skill.attack_bonus("ali")==0,"empower expires "+element)
	reset("wood"); weapon("bow")
	s.magic.ensure("ali").weapon_wear.merge(s.inventory.Origin.gifted("gift-empower-test"))
	var origin: Dictionary=s.magic.ensure("ali").weapon_wear.duplicate(true)
	check(skill.cast(2,Vector2.ZERO) and s.magic.ensure("ali").weapon_wear==origin,"empower leaves weapon magic provenance untouched")
	var area := open_area(); position(area); var enemy := enemy_at(area+Vector2(55,0)); await frames()
	give({"arrow":1}); s.combat.cooldown=0
	check(s.combat.fire(enemy.global_position),"empowered bow fires actual arrow")
	var arrows := get_tree().get_nodes_in_group("arrows")
	check(not arrows.is_empty() and arrows[-1].damage==3,"empowered projectile records launch damage")
	for arrow in arrows: arrow.queue_free()
	reset("wood"); weapon(); area=open_area(); position(area); enemy=enemy_at(area+Vector2(20,0)); await frames()
	check(skill.cast(2,Vector2.ZERO),"empower actual melee")
	s.combat.cooldown=0
	check(s.combat.fire(enemy.global_position) and enemy.hp==27,"actual empowered melee adds two damage")
	s.vitals.ensure("ali").mana=10
	var prior: Dictionary=skill.export_state()
	s.inventory.path=blocked_path()
	check(not skill.cast(2,Vector2.ZERO),"failed empowerment save is rejected")
	s.inventory.path=old_path
	check(skill.export_state()==prior and s.vitals.ensure("ali").mana==10,"failed empower restores mana and timer")
	# Wood utility matures one crop and rolls back crop/mana together on failure.
	reset("wood"); position(Vector2(230,295)); await frames()
	var target := Vector2(226,238)
	var plot: Dictionary=s.homestead.plots[0]
	plot.crop="wheat"; plot.dry=false; plot.growth=0; plot.age=0; s.homestead.refresh()
	check(skill.cast(3,target) and plot.mature and s.vitals.ensure("ali").mana==5,"wood utility matures a crop instantly")
	s.vitals.ensure("ali").mana=10; plot.growth=0; s.homestead.refresh()
	s.inventory.path=blocked_path()
	check(not skill.cast(3,target),"crop cast fails on save failure")
	s.inventory.path=old_path
	check(s.vitals.ensure("ali").mana==10 and not s.homestead.plots[0].mature,"failed crop cast preserves growth and mana")
	# Water converts only one of each empty vessel in place, preserving origin in a full bag.
	reset("water"); give({"bucket":2,"wooden_cup":2})
	s.inventory.ensure_bag("ali")[0].merge(s.inventory.Origin.gifted("water-gift"))
	check(skill.cast(3,Vector2.ZERO) and count("water_bucket")==1 and count("water_cup")==1 and count("bucket")==1 and count("wooden_cup")==1,"water utility fills one empty bucket and cup")
	check(s.inventory.ensure_bag("ali")[0].gift_event_id=="water-gift","water filling preserves gift record")
	s.vitals.ensure("ali").mana=10; give({"wood":1})
	check(not skill.cast(3,Vector2.ZERO) and s.vitals.ensure("ali").mana==10,"no vessel cast never spends mana")
	# Regeneration: first tick at three seconds, ten ticks over thirty, max eleven, other roles frozen.
	reset("wood"); s.vitals.ensure("ali").life=1
	check(skill.cast(4,Vector2.ZERO) and s.vitals.ensure("ali").mana==0,"wood regen costs ten")
	skill.advance(2.5); check(s.vitals.ensure("ali").life==1,"regen has no early tick")
	skill.advance(0.5); check(s.vitals.ensure("ali").life==2,"regen ticks every three seconds")
	skill.advance(27); check(s.vitals.ensure("ali").life==11 and skill.buffs.ali.regen==0,"regen delivers ten ticks and respects wood cap")
	reset("wood"); s.vitals.ensure("ali").life=2; skill.cast(4,Vector2.ZERO)
	s.select_resident(1); skill.advance(3)
	check(s.vitals.ensure("ali").life==2,"inactive resident vitals remain frozen during regen")
	s.select_resident(0)
	# Shield reduces incoming combat damage by 30%, stores fractions and expires at thirty seconds.
	reset("water"); check(skill.cast(4,Vector2.ZERO),"water shield casts")
	s.vitals.hurt("ali",1)
	check(is_equal_approx(float(s.vitals.ensure("ali").life),9.3),"shield reduces one damage to 0.7")
	check(s.persistence.save_now(),"save fractional shield health")
	var saved: Dictionary=s.inventory.export_data(); s.inventory.apply_data(saved); s.persistence.restore_session(saved.session)
	check(is_equal_approx(float(s.vitals.ensure("ali").life),9.3),"fractional shield health survives reload")
	skill.advance(30); s.vitals.hurt("ali",1)
	check(is_equal_approx(float(s.vitals.ensure("ali").life),8.3),"expired shield no longer reduces damage")
	# Fire DoT: exactly five ticks across fifteen seconds; kill credited only once to caster.
	reset("fire"); area=open_area(); position(area); enemy=enemy_at(area+Vector2(55,0)); await frames()
	check(skill.cast(4,enemy.global_position),"fire fourth tier targets hostile")
	skill.advance(2.5); check(enemy.hp==30,"burn has no premature damage")
	skill.advance(0.5); check(enemy.hp==29,"burn ticks at three seconds")
	skill.advance(12); check(enemy.hp==25,"15-second burn ticks five times")
	skill.advance(30); check(enemy.hp==25,"expired burn does not continue")
	s.vitals.ensure("ali").mana=10; enemy.hp=1
	var xp: int=s.magic.ensure("ali").xp
	check(skill.cast(4,enemy.global_position),"cast lethal burn")
	skill.advance(15); check(enemy.hp==0 and s.magic.ensure("ali").xp==xp+25,"burn kill credits caster once")
	# Roots and life drain: next actual attack, two stolen life, no repeat.
	reset("wood"); area=open_area(); position(area); enemy=enemy_at(area+Vector2(20,0)); await frames()
	s.vitals.ensure("ali").life=5
	check(skill.cast(5,enemy.global_position) and skill.rooted(enemy.enemy_id),"wood root starts for one second")
	skill.advance(1); check(not skill.rooted(enemy.enemy_id),"wood root ends at one second")
	check(s.combat.hit_enemy(enemy,1,"ali") and enemy.hp==27 and s.vitals.ensure("ali").life==7,"next weapon hit steals two life")
	s.combat.hit_enemy(enemy,1,"ali"); check(enemy.hp==26 and s.vitals.ensure("ali").life==7,"life steal consumes once")
	reset("water"); area=open_area(); position(area); enemy=enemy_at(area+Vector2(55,0)); await frames()
	check(skill.cast(5,enemy.global_position) and skill.rooted(enemy.enemy_id),"water bubble roots target")
	skill.advance(1); check(enemy.thirst==10 and not skill.rooted(enemy.enemy_id),"bubble root lasts one second before thirst timer")
	skill.advance(5); check(enemy.thirst==8,"bubble first thirst loss after five seconds")
	skill.advance(5); check(enemy.thirst==6,"bubble second thirst loss after ten seconds")
	skill.advance(5); check(enemy.thirst==6,"bubble thirst stops after ten seconds")
	# Fireball sweeps collision through a distant target and needs no weapon/ammo.
	reset("fire"); area=open_area(); position(area); enemy=enemy_at(area+Vector2(60,-10)); await frames()
	check(skill.cast(5,enemy.global_position) and skill.projectiles.size()==1,"fire fifth tier spawns one fireball")
	skill.advance(0.5); check(enemy.hp==25 and skill.projectiles.is_empty(),"fireball hits for five and disappears")
	# Earth creates at most twenty-five dry independent cells without hoe; blocked land is rejected.
	reset("earth"); area=open_area(); position(area); await frames()
	var plots_before: int=s.homestead.plots.size()
	check(skill.cast(3,area+Vector2(40,0)),"earth tills without a hoe")
	var added: int=s.homestead.plots.size()-plots_before
	check(added>0 and added<=25 and not s.inventory.has_item("ali","hoe"),"earth utility creates at most 5x5 valid cells")
	s.vitals.ensure("ali").mana=10
	check(not skill.cast(3,Vector2(2400,0)) and s.vitals.ensure("ali").mana==10,"invalid terrain does not spend mana")
	# Temporary house: owner-only entry, persists remaining timer, safe evacuation on expiry.
	reset("earth"); area=open_area(); position(area); await frames()
	check(skill.cast(4,area+Vector2(60,0)) and skill.huts.has("ali"),"earth creates a twenty-second house")
	var home: Dictionary=s.world.home_data("skill_hut:ali")
	s.select_resident(1); position(home.door); await frames(); s.interact()
	check(s.world.active_resident.room_id=="","other resident cannot enter earth house")
	s.select_resident(0); position(home.door); await frames(); s.interact()
	check(s.world.active_resident.room_id=="skill_hut:ali","owner enters earth house")
	skill.advance(7); saved=s.inventory.export_data(); s.inventory.apply_data(saved); s.persistence.restore_session(saved.session)
	check(s.world.active_resident.room_id=="skill_hut:ali" and is_equal_approx(float(skill.huts.ali.remaining),13),"inside-house save resumes owner and remaining online time")
	skill.advance(13); check(s.world.active_resident.room_id=="" and not skill.huts.has("ali"),"house expiry safely returns owner outdoors")
	reset("earth"); area=open_area(); position(area); await frames()
	check(skill.cast(5,area+Vector2(80,0)) and is_equal_approx(s.world.active_resident.position.distance_to(area),80),"earth teleport moves exactly eighty world pixels")
	s.vitals.ensure("ali").mana=10
	var prior_position: Vector2=s.world.active_resident.position
	s.inventory.path=blocked_path()
	check(not skill.cast(5,prior_position+Vector2(80,0)),"teleport is rejected on save failure")
	s.inventory.path=old_path
	check(s.world.active_resident.position==prior_position and s.vitals.ensure("ali").mana==10,"failed teleport restores position and mana")
	# Campfire crafting, placement, lighting and persistence use actual deployed records.
	reset("fire"); give({"stone":2,"wood":1,"coal":1})
	var bench: Node2D
	for node in s.grounds.fixtures:
		if node.fixture_id=="outdoors:public:desert": bench=node
	position(bench.position+Vector2(0,15)); await frames(); s.production.open_near()
	check(s.production.perform("campfire") and count("stone")==0 and count("coal")==0,"campfire craft consumes requested materials")
	s.production.elapse(60)
	check(count("campfire")==1,"campfire takes sixty online seconds and produces one")
	s.production.close(); area=open_area(); position(area); await frames()
	check(s.editor.open(),"open campfire furnishing")
	s.editor.choose("campfire"); s.editor.point_at(area+Vector2(45,0))
	check(s.editor.place() and count("campfire")==0,"campfire deployment consumes crafted item")
	s.editor.close()
	var camp: Node2D=s.grounds.fixtures[-1]
	position(camp.position+Vector2(0,17)); await frames()
	check(not camp.lit and skill.cast(3,Vector2.ZERO) and camp.lit,"fire utility lights a deployed campfire")
	check(camp.lamp.enabled and camp.lamp.texture.get_size()==Vector2(96,96) and camp.lamp.texture_scale==1,"campfire light covers 96 by 96 world pixels")
	check(skill.interact_camp() and not camp.lit and not camp.lamp.enabled,"E extinguishes campfire and light")
	check(skill.interact_camp() and camp.lit,"E relights campfire")
	saved=s.inventory.export_data(); s.inventory.apply_data(saved); s.persistence.restore_session(saved.session)
	check(s.grounds.fixtures[-1].lit and s.grounds.fixtures[-1].lamp.enabled,"campfire lit state survives reload")
	camp=s.grounds.fixtures[-1]
	position(camp.position+Vector2(0,17)); await frames()
	s.vitals.ensure("ali").mana=10
	check(not skill.cast(3,Vector2.ZERO) and s.vitals.ensure("ali").mana==10,"already lit campfire does not spend mana")
	# Deterministic chunk generation and independent probability distribution.
	var total_coal:=0; var total_iron:=0
	for seed in range(1,1001):
		var records := Cave.generate(seed)
		var stones: Dictionary={}
		for record: Dictionary in records:
			if record.kind=="coal": total_coal+=1
			elif record.kind=="iron_ore": total_iron+=1
			else: stones[Vector2i(record.at/Cave.CHUNK)]=true
		check(stones.size()==24,"stone exists in every cave chunk seed "+str(seed))
	check(absf(float(total_coal)/24000-0.4)<0.02 and absf(float(total_iron)/24000-0.1)<0.02,"coal 40 and iron 10 percent independent chunk rolls")
	check(Cave.generate(42)==Cave.generate(42) and Cave.generate(42)!=Cave.generate(43),"cave uses stable saved seed")
	s.mining.restore({"progress":{"mine:7":4,"mine:1":1}},42)
	check(s.mining.legacy_cave and s.mining.progress.get("mine:7")==4 and s.mining.underground_records.any(func(r: Dictionary) -> bool: return r.id=="mine:7"),"old cave retains original veins and mining progress")
	var mine_saved: Dictionary=s.mining.export_state()
	s.mining.restore(mine_saved)
	check(s.mining.export_state()==mine_saved,"legacy cave migration is stable across repeated loads")
	check(s.mining.Cave.SIZE==Vector2(1920,960),"cave expanded to 1920x960 world pixels")
	# Actual mine coal, deployed campfire, and saved depletion remain valid after re-entering.
	s.interiors.enter(s.world.active_resident,s.world.home_data("mine")); s._sync_view(); await frames()
	var cave: Node2D=s.interiors.rooms.mine
	check(cave.size==Cave.SIZE and s.editor.open(),"expanded cave allows campfire furnishing")
	s.editor.close()
	give({"campfire":1})
	position(Vector2(960,860)); await frames()
	check(s.editor.open(),"mine deployment opens furnishing")
	s.editor.choose("campfire"); s.editor.point_at(Vector2(1010,860))
	check(s.editor.place() and count("campfire")==0,"campfire deploys inside mine")
	s.editor.close()
	var mine_camp: Node2D=cave.fixtures[-1]
	position(mine_camp.position+Vector2(0,17)); await frames()
	check(skill.interact_camp() and mine_camp.lit,"mine campfire can be lit")
	saved=s.inventory.export_data(); s.inventory.apply_data(saved); s.persistence.restore_session(saved.session)
	cave=s.interiors.rooms.mine
	check(cave.fixtures.size()==1 and cave.fixtures[0].lit,"mine campfire and lit state survive reload")
	weapon("pickaxe")
	var coal: Node2D
	for node in cave.objects.get_children():
		if "kind" in node and node.kind=="coal": coal=node; break
	check(is_instance_valid(coal),"this saved cave seed contains coal")
	if is_instance_valid(coal):
		position(coal.position+Vector2(0,18)); await frames()
		for i in range(3): s.mining.cooldown=0; check(s.mining.strike(s.world.active_resident,coal),"actual coal mining strike "+str(i))
		check(count("coal")==3 and not coal.visible,"coal vein yields three and depletes")
		var coal_id: String=coal.resource_id
		saved=s.inventory.export_data(); s.inventory.apply_data(saved); s.persistence.restore_session(saved.session)
		check(s.mining.progress.get(coal_id,0)==3,"coal depletion survives reload")
	# Wrong context, mana and locked skills cannot mutate state.
	reset("fire",1); check(not skill.cast(5,Vector2.ZERO) and s.vitals.ensure("ali").mana==10,"locked skills never spend mana")
	reset("water"); s.vitals.ensure("ali").mana=4; check(not skill.cast(2,Vector2.ZERO) and s.vitals.ensure("ali").mana==4,"insufficient mana remains unchanged")
	s.menu_paused=true; check(not skill.cast(3,Vector2.ZERO),"paused game blocks skill cast"); s.menu_paused=false
	print("ELEMENTAL_CHECKS=",checks)
	print("ELEMENTAL_FAILURES=",JSON.stringify(failures))
	if failures.is_empty(): print("ELEMENTAL_SKILLS_OK")
	game.queue_free(); await frames()
	get_tree().quit(0 if failures.is_empty() else 1)
