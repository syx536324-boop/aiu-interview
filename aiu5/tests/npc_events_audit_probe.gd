# Exercises witnessed damage, kin, commanded attacks, legitimate aid and rollback through business entries.
extends "res://tests/npc_attitude_probe.gd"

func run() -> void:
	await relations()
	await command_attribution()
	await assistance()
	await sight_and_save()
	if failures.is_empty(): print("NPC_EVENTS_AUDIT_OK checks=",checks)
	finish()

func yard_people() -> void:
	for id: String in t.population.members:
		var npc: Node=t.population.node(id)
		npc.position=Vector2(3000,3000)
	s.world.active_resident.position=Vector2(820,360)
	unit("forest:0").position=Vector2(760,360)
	unit("forest:1").position=Vector2(790,390)
	unit("forest:2").position=Vector2(790,330)
	unit("forest:3").position=Vector2(760,400)
	s._sync_view()
	await get_tree().physics_frame

func relations() -> void:
	await fresh_game(); await yard_people()
	var victim: Node=unit("forest:0")
	check(s.combat.hit_enemy(victim,1,actor_id()),"a real successful attack records its relationship event")
	check(t.standing("forest")==-20,"an actual attack deducts twenty standing")
	check(liking_of(actor_id(),victim.resident_id)==20,"the victim loses thirty affinity once")
	check(liking_of(actor_id(),"npc:forest:1")==40,"an actual nearby witness loses ten affinity")
	check(s.combat.hit_enemy(victim,1,actor_id()),"a second hit in the same conflict is valid")
	check(t.standing("forest")==-20 and liking_of(actor_id(),"npc:forest:1")==40,"repeat hits do not repeat witness or standing penalties")
	var severe: Dictionary=t.relation.last_severe(victim.enemy_id)
	t.clock+=1001
	t.relation.remember(victim.enemy_id,"gift_bread",actor_id(),1)
	check(t.relation.last_severe(victim.enemy_id)==severe,"elapsed time and an ordinary gift do not erase serious memory")
	await fresh_game(); await yard_people()
	victim=unit("forest:0")
	t.population.members[victim.enemy_id].parents=["npc:forest:2"]
	t.population.members["forest:3"].parents=[victim.resident_id]
	victim.hp=1
	check(s.combat.hit_enemy(victim,5,actor_id()),"a real lethal hit completes")
	check(t.standing("forest")==-55,"one lethal first hit settles attack twenty plus death thirty-five")
	check(liking_of(actor_id(),victim.resident_id)==20,"a lethal hit does not double-count the victim's affinity penalty")
	check(liking_of(actor_id(),"npc:forest:2")==10 and liking_of(actor_id(),"npc:forest:3")==10,"existing parents and adult children each lose forty affinity")
	check(liking_of(actor_id(),"npc:forest:1")==40,"a witnessed lethal hit deducts ten rather than charging the witness twice")
	await fresh_game(); await yard_people()
	victim=unit("forest:0")
	var before: Dictionary=t.export_state()
	var hp: float=victim.hp
	s.persistence.ready_to_save=false
	check(not s.combat.hit_enemy(victim,1,actor_id()),"failed persistence rejects the attack transaction")
	s.persistence.ready_to_save=true
	check(t.standing("forest")==0 and victim.hp==hp and t.encounters.contacts.is_empty(),"failed persistence rolls back damage, relationships and encounter records")

func command_attribution() -> void:
	await fresh_game(); await yard_people()
	var man: Node=unit("home:initial_male")
	man.position=Vector2(790,360)
	t.war.orders[man.enemy_id]="forest"; t.war.commanders[man.enemy_id]="chief_priest"
	t.war.damage_target(unit("forest:0"),1,"home",man.enemy_id)
	check(t.standing("forest")==-20,"an NPC attack ordered by the player affects player-tribe standing")
	check(liking_of("chief_priest","npc:forest:0")==20 and liking_of("ali","npc:forest:0")==50,"the order's original commander receives the personal event")
	await fresh_game(); await yard_people()
	man=unit("home:initial_male"); man.position=Vector2(790,360)
	t.war.damage_target(unit("forest:0"),1,"home",man.enemy_id)
	check(t.standing("forest")==0,"autonomous allied defense is not charged as a player order")
	var before: int=t.standing("forest")
	s.combat.apply_npc_damage(unit("forest:0"),actor_id(),1)
	check(t.standing("forest")==before,"being hit does not falsely count as a new player attack")

func assistance() -> void:
	await fresh_game(); await yard_people()
	var invader: Node=unit("barbarian:16"); invader.position=Vector2(790,360)
	var protected: Node=unit("forest:0")
	t.war.damage_target(protected,1,"barbarian",invader.enemy_id)
	check(s.combat.hit_enemy(invader,1,actor_id()),"the player can damage an actual aggressor attacking another tribe")
	check(t.standing("forest")==10 and t.standing("barbarian")==-70,"aid rewards the defended tribe, not the invading tribe")
	check(liking_of(actor_id(),protected.resident_id)==60,"the actually helped villager gains ten affinity")
	t.clock+=301
	t.war.damage_target(protected,1,"barbarian",invader.enemy_id)
	s.combat.hit_enemy(invader,1,actor_id())
	check(t.standing("forest")==10,"the same continuing battle cannot reward aid again after five minutes")
	await fresh_game(); await yard_people()
	invader=unit("barbarian:16"); invader.position=Vector2(790,360)
	s.combat.apply_npc_damage(invader,actor_id(),1)
	s.combat.hit_enemy(invader,1,actor_id())
	check(t.standing("barbarian")==-70 and t.standing("forest")==0,"defending home does not grant aid standing to the invading tribe")

func sight_and_save() -> void:
	await fresh_game(); await yard_people()
	var chief: Node=unit("forest:chief"); chief.position=Vector2(760,360); s._sync_view()
	var wall := StaticBody2D.new(); wall.position=Vector2(780,360); wall.collision_layer=1
	var shape := CollisionShape2D.new(); var box := RectangleShape2D.new(); box.size=Vector2(6,80)
	shape.shape=box; wall.add_child(shape); s.world.objects.add_child(wall)
	await get_tree().physics_frame
	check(not t.npc_skills._can_see(chief,s.world.active_resident),"a wall within twenty-four pixels still blocks NPC magic")
	wall.queue_free(); await get_tree().physics_frame
	s.combat.hit_enemy(unit("forest:0"),1,actor_id())
	check(s.persistence.save_now(),"new encounter and memory fields save through the normal persistence entry")
	var recorded: Dictionary=t.encounters.export_state()
	await reload_game()
	check(JSON.parse_string(JSON.stringify(t.encounters.export_state()))==JSON.parse_string(JSON.stringify(recorded)),"a restart preserves encounter remaining times without offline advancement")
	var old: Dictionary=t.export_state(); old.erase("encounters")
	var injured: float=unit("forest:0").hp
	t.restore(old)
	check(t.encounters.contacts.is_empty() and unit("forest:0").hp==injured,"old-save migration clears missing encounters without healing or reviving anyone")
