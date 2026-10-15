# Tests actual walking slows, safe chief escapes, NPC life pools and uninterrupted combat after gifting.
extends "res://tests/npc_behavior_live_probe.gd"

func run() -> void:
	await walking_slow()
	await effect_targets()
	await gift_case()
	await invasion_case()
	await trust_case()
	if failures.is_empty(): print("NPC_SKILL_AUDIT_OK checks=",checks)
	finish()

func walking_slow() -> void:
	await fresh_game()
	var player: Node=s.world.active_resident
	for enemy: Node in s.combat.enemies.values(): enemy.position=Vector2(3000,3000)
	player.position=Vector2(760,360); s._sync_view()
	player.set_physics_process(true); player.controlled=true; player.input_enabled=true
	await get_tree().physics_frame
	var start: Vector2=player.position
	Input.action_press("move_right")
	for i in range(20): await get_tree().physics_frame
	Input.action_release("move_right")
	var normal: float=player.position.distance_to(start)
	player.position=start
	s.magic.branches.player_status(actor_id(),"slowed",2)
	check(is_equal_approx(s.magic.branches.speed_rate(actor_id()),0.8),"suppression applies one twenty-percent slow source")
	Input.action_press("move_right")
	for i in range(20): await get_tree().physics_frame
	Input.action_release("move_right")
	var slow: float=player.position.distance_to(start)
	check(normal>10 and absf(slow/normal-0.8)<0.08,"suppression slows actual normal walking, not only running")
	s.magic.branches._buff_set(actor_id(),"other",2,{"slow":0.5,"source":"cold"})
	s.magic.branches._buff_set(actor_id(),"same",2,{"slow":0.5,"source":"cold"})
	check(is_equal_approx(s.magic.branches.speed_rate(actor_id()),0.4),"different slow sources cap at sixty percent and the same source never stacks")

func effect_targets() -> void:
	await fresh_game()
	var player: Node=s.world.active_resident
	var chief: Node=unit("yunye:chief")
	chief.position=Vector2(760,400); player.position=Vector2(820,360)
	s._sync_view(); await get_tree().physics_frame
	s.vitals.ensure(chief.chief_id).mana=40; chief.mana=40
	check(not npc_skills.can_use(chief,"chief_earth_blink"),"an unthreatened full-health earth chief does not teleport toward the player")
	chief.hp=chief.max_hp*0.2
	var before: Vector2=chief.position
	var gap: float=chief.position.distance_to(player.position)
	check(npc_skills.use(chief,"chief_earth_blink"),"an injured earth chief begins a legal escape")
	npc_skills.advance(0.8)
	check(is_equal_approx(chief.position.distance_to(before),80) and chief.position.distance_to(player.position)>gap,"earth escape moves eighty pixels away from danger")
	check(s.vitals.ensure(chief.chief_id).mana==30,"the escape spends only the chief's ten mana")
	await fresh_game()
	var man: Node=unit("home:initial_male")
	var archer: Node=unit("forest:12")
	man.position=Vector2(820,360); archer.position=Vector2(760,360)
	s.world.active_resident.position=Vector2(820,420); s._sync_view()
	for i in range(3): await get_tree().physics_frame
	t.guards.npc(archer.enemy_id).target_id=man.resident_id
	var hp: float=man.hp
	var player_life: float=s.vitals.ensure(actor_id()).life
	check(s.combat.apply_npc_damage(archer,man.resident_id,1),"NPC damage resolves a registered NPC target")
	check(man.hp==hp-1 and s.vitals.ensure(actor_id()).life==player_life,"NPC damage changes its target's actual health bar, not another life pool")
	check(npc_skills.use(archer,"suppress_shot"),"suppression can target an actual allied NPC attacker")
	npc_skills.advance(0.8)
	for i in range(20): await get_tree().physics_frame
	check(man.hp==hp-2 and is_equal_approx(s.magic.branches.speed_rate(man.enemy_id),0.8),"the swept arrow damages and slows the actual NPC it hits")

func gift_case() -> void:
	var npc: Node=await fixture("charger")
	t.set_standing("forest",-50)
	await start_live(npc,yard(),24)
	for i in range(35): await get_tree().physics_frame
	give(actor_id(),"bread",1)
	check(t.gift_bread(npc.enemy_id),"a normal bread gift completes during the encounter")
	check(t.standing("forest")==-49,"the gift crosses the hostile standing threshold")
	var result: Dictionary=await sample(npc,5)
	check(result.lost_life>0,"a gift does not cancel an ongoing attack or preparation")

func invasion_case() -> void:
	var defender: Node=await fixture("charger")
	var man: Node=unit("home:initial_male")
	var at := yard()
	await start_live(defender,at,110)
	man.room_id=""; man.position=at+Vector2(24,0)
	t.population.members[man.enemy_id].career="charger"; t.population.members[man.enemy_id].level=3; t.population.apply(man.enemy_id)
	t.war.orders[man.enemy_id]="forest"; t.war.commanders[man.enemy_id]=actor_id()
	s._sync_view(); man.set_physics_process(false); defender.set_physics_process(true)
	await get_tree().physics_frame
	t.war.damage_target(defender,1,"home",man.enemy_id)
	var hp: float=man.hp
	var life: float=s.vitals.ensure(actor_id()).life
	for i in range(300):
		await get_tree().physics_frame
		if man.hp<hp: break
	s.simulation.set_process(false)
	check(man.hp<hp,"a foreign guard actually counterattacks the player-commanded NPC invader")
	check(s.vitals.ensure(actor_id()).life==life,"the counterattack targets the invader rather than an unrelated nearby player")

func trust_case() -> void:
	var guard: Node=await fixture("charger")
	t.set_standing("forest",60)
	var at := yard()
	await start_live(guard,at,40)
	var invader: Node=unit("barbarian:16")
	# Keep a stationary real actor as the incoming attacker; only the defending AI is under test.
	t.population.members.erase(invader.enemy_id)
	invader.room_id=""; invader.position=at+Vector2(28,20)
	s._sync_view(); invader.set_physics_process(false); guard.set_physics_process(true)
	await get_tree().physics_frame
	s.combat.apply_npc_damage(invader,actor_id(),1)
	var hp: float=invader.hp
	for i in range(300):
		await get_tree().physics_frame
		if invader.hp<hp: break
	s.simulation.set_process(false)
	check(invader.hp<hp,"a trusted tribe provides real combat aid to a player under attack")
