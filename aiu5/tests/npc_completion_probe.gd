# Exercises remaining 0.10.0 acceptance cases with real damage, inventory UI and chief casts.
extends "res://tests/npc_attitude_probe.gd"

func run() -> void:
	await fresh_game()
	await reductions()
	await theft()
	await casts()
	await arrows_and_capture()
	if failures.is_empty(): print("NPC_COMPLETION_OK checks=",checks)
	finish()

func reductions() -> void:
	var victim: Node=t.population.node("barbarian:12")
	var id: String=victim.enemy_id
	var actor := actor_id()
	victim.hp=victim.max_hp; victim.refresh()
	npc_skills._parry(victim)
	var before: float=victim.hp
	check(s.combat.apply_skill_damage(victim,3,actor),"direct skill damage reaches a parrying NPC")
	check(is_equal_approx(before-victim.hp,2.1),"skill parry applies thirty percent exactly once")
	s.magic.skills.marks[actor+":fire:"+id]={"enemy":id,"actor":actor,"kind":"fire","root":0.0,"remaining":15.0,"tick":0.0,"drain":false}
	before=victim.hp
	s.magic.skills.advance(3)
	check(is_equal_approx(before-victim.hp,0.7),"periodic burn shares the same parry damage entry")
	s.magic.skills.buffs[id]={"shield":30.0}
	before=victim.hp
	s.combat.apply_skill_damage(victim,3,actor)
	check(is_equal_approx(before-victim.hp,1.5),"different reductions multiply and cap ordinary reduction at fifty percent")
	npc_skills._parry(victim)
	before=victim.hp
	s.combat.apply_skill_damage(victim,3,actor)
	check(is_equal_approx(before-victim.hp,1.5),"repeating the same parry never stacks")
	await fresh_game()

func theft() -> void:
	var player: Node=s.world.active_resident
	var home: Dictionary=s.world.home_data("forest_wood_house")
	s.interiors.enter(player,home); s._sync_view()
	var room: Node=s.interiors.rooms[player.room_id]
	var cabinet: Node
	for f: Node in room.fixtures:
		if f.kind=="cabinet": cabinet=f; break
	var storage_id: String=cabinet.fixture_id
	check(is_instance_valid(cabinet),"a real other-tribe cabinet is available")
	if not is_instance_valid(cabinet): return
	player.position=cabinet.position+Vector2(0,10)
	# Use the actual room context rather than an unrelated scripted container.
	for at: Vector2 in [cabinet.position+Vector2(0,10),cabinet.position+Vector2(10,10),cabinet.position+Vector2(-10,10)]:
		player.position=at
		if s.interiors.context(player).get("id","")=="storage": break
	s.interact()
	check(s.inventory.container_id==storage_id,"E opens the actual tribal cabinet")
	s.inventory.ensure_container(storage_id)[0]={"item":"wood","count":3}
	var standing_before: int=t.standing("forest")
	s.inventory.slot_clicked("storage",0,true)
	check(t.standing("forest")==standing_before-10,"successful quick withdrawal charges one theft event")
	check(s.inventory.has_item(actor_id(),"wood"),"stolen items are in the operator's bag")
	standing_before=t.standing("forest")
	s.inventory.slot_clicked("storage",0,true)
	check(t.standing("forest")==standing_before,"empty/no-op withdrawal never charges theft")
	s.inventory.ensure_container(storage_id)[0]={"item":"stone","count":2}
	s.persistence.ready_to_save=false
	s.inventory.slot_clicked("storage",0,true)
	s.persistence.ready_to_save=true
	check(t.standing("forest")==standing_before and s.inventory.ensure_container(storage_id)[0].count==2,"failed transfer rolls back inventory and standing together")
	s.inventory.close()
	s.inventory.open_container(actor_id(),player.resident_name,storage_id,"青木木柜")
	for i in range(21): s.inventory.bags[actor_id()][i]={"item":"bread","count":99}
	s.inventory.slot_clicked("storage",0,true)
	check(t.standing("forest")==standing_before,"full bag has no theft event")
	s.inventory.bags[actor_id()][0]={}
	var own_box: Node
	for f: Node in s.interiors.rooms[player.room_id].fixtures:
		if f.fixture_id==storage_id: own_box=f
	own_box.gift_origin={"item":"cabinet","count":1}
	s.inventory.slot_clicked("storage",0,true)
	check(t.standing("forest")==standing_before,"player-placed cabinets remain private property in another tribe room")
	own_box.gift_origin={}
	s.inventory.ensure_container(storage_id)[0]={"item":"wood","count":2}
	s.inventory.bags[actor_id()][0]={}
	t.relics.states.forest.owner="player"
	s.inventory.slot_clicked("storage",0,true)
	check(t.standing("forest")==standing_before,"captured tribal property is legitimate")
	await fresh_game()

func casts() -> void:
	var player: Node=s.world.active_resident
	var chief: Node=t.population.node("forest:chief")
	# Place only the tested actors in a known clear yard; physics queries remain real.
	chief.position=Vector2(760,360); player.position=Vector2(820,360)
	s._sync_view(); await get_tree().physics_frame
	s.vitals.ensure(chief.chief_id).mana=40; chief.mana=40
	var player_mana: float=s.vitals.ensure(actor_id()).mana
	check(npc_skills.use(chief,"chief_wood_vine"),"chief begins a visible control spell")
	check(not s.magic.branches.immobile(actor_id()),"control effect does not precede preparation window")
	npc_skills.advance(0.4)
	check(not s.magic.branches.immobile(actor_id()),"halfway through preparation the target remains free")
	npc_skills.advance(0.4)
	check(s.magic.branches.immobile(actor_id()),"control spell lands after its full preparation window")
	check(s.vitals.ensure(actor_id()).mana==player_mana,"chief preparation and impact never spend player mana")
	await fresh_game()
	player=s.world.active_resident; chief=t.population.node("forest:chief")
	chief.position=Vector2(760,360); player.position=Vector2(820,360)
	s._sync_view(); await get_tree().physics_frame
	s.vitals.ensure(chief.chief_id).mana=40; chief.mana=40
	check(npc_skills.use(chief,"chief_wood_vine"),"chief starts a spell that can be dodged")
	player.position=Vector2(1080,360)
	npc_skills.advance(0.8)
	check(not s.magic.branches.immobile(actor_id()),"leaving range before impact evades the spell")
	await fresh_game()
	player=s.world.active_resident; chief=t.population.node("forest:chief")
	chief.position=Vector2(760,360); player.position=Vector2(820,360)
	s._sync_view(); await get_tree().physics_frame
	s.vitals.ensure(chief.chief_id).mana=40; chief.mana=40
	check(npc_skills.use(chief,"chief_wood_vine"),"chief starts a spell that can be interrupted")
	s.magic.branches._status(chief,actor_id(),"root",1.0,{"root":true})
	npc_skills.advance(0.8)
	check(not s.magic.branches.immobile(actor_id()),"rooting the caster interrupts its prepared spell")
	check(str(npc_skills._state(chief.enemy_id).prepare.skill)=="","interruption clears the pending effect")
	await fresh_game()

func arrows_and_capture() -> void:
	var player: Node=s.world.active_resident
	var archer: Node=t.population.node("forest:12")
	archer.position=Vector2(760,360); player.position=Vector2(820,360)
	s._sync_view(); await get_tree().physics_frame
	var ammo := count(archer.resident_id,"arrow")
	archer.order_attack(player)
	check(count(archer.resident_id,"arrow")==ammo-1,"ordinary guard bow attack spends its own arrow")
	check(t.war.cooldowns.get(archer.enemy_id,0)==1.0,"ordinary guard weapon interval is one second")
	var before: float=s.vitals.ensure(actor_id()).life
	for i in range(24): await get_tree().physics_frame
	check(is_equal_approx(before-s.vitals.ensure(actor_id()).life,1.0),"level-three archer projectile deals one damage")
	check(is_equal_approx(archer.attack_reach(),s.combat.Gear.attack_range("bow")),"plain-land NPC bow range matches the player catalog")
	archer.position=Vector2(1000,-800)
	check(is_equal_approx(archer.attack_reach(),s.combat.Gear.attack_range("bow")*0.7),"highland haze reduces bow reach to seventy percent")
	await fresh_game()
	player=s.world.active_resident
	var chief: Node=t.population.node("forest:chief")
	chief.position=Vector2(760,360); player.position=Vector2(820,360)
	s._sync_view(); await get_tree().physics_frame
	s.vitals.ensure(chief.chief_id).mana=40; chief.mana=40
	npc_skills.use(chief,"chief_wood_vine")
	npc_skills.advance(0.4)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory+"/chief-preparation.png")

