# Verifies missing and legacy tribal saves, invalid position fallback and a real full-session restart.
extends SceneTree
var directory := ""
var game: Node
var session: Node
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	directory=OS.get_environment("AIU5_PROBE_DIRECTORY")
	assert(directory!="")
	DirAccess.make_dir_recursive_absolute(directory)
	OS.set_environment("AIU5_STATE_PATH",directory+"/state.json")
	OS.set_environment("AIU5_PROFILE_PATH",directory+"/names.cfg")
	create_timer(60,true).timeout.connect(func() -> void: quit(2))
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error(label)
func frames(n := 3) -> void:
	for i in range(n): await process_frame
func load_game() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	session=game.get_node("Session")
	session.simulation.set_process(false)
	session.simulation.reset()
	session.persistence.set_process(false)
	for actor in session.world.residents: actor.set_physics_process(false)
	for enemy in session.combat.enemies.values(): enemy.set_physics_process(false)
	await frames()
func run() -> void:
	await load_game()
	var combat: Node=session.combat
	check(combat.enemies.size()==66,"all three tribes, chiefs and original raiders registered")
	combat.restore({})
	for id: String in combat.enemies:
		var enemy: CharacterBody2D=combat.enemies[id]
		var initial: Dictionary=combat.initial_states[id]
		check(enemy.position==Vector2(initial.at[0],initial.at[1]),"empty save initial position "+id)
		check(enemy.hp==initial.hp,"empty save initial health "+id)
	var legacy := {"tribe:1":{"hp":0,"at":[1234,970],"thirst":4,"cooldown":0.5,"pursuit":3}}
	combat.restore(legacy)
	check(combat.enemies["tribe:1"].hp==0 and not combat.enemies["tribe:1"].visible,"legacy dead enemy stays dead")
	check(combat.enemies["tribe:1"].position==Vector2(1234,970),"legacy saved position retained")
	check(combat.enemies["tribe:1"].thirst==4 and combat.enemies["tribe:1"].cooldown==0.5,"legacy combat stats retained")
	for id: String in combat.enemies:
		if combat.SPAWNS.has(id): continue
		check(combat.enemies[id].hp==combat.initial_states[id].hp,"missing tribal entry migrates "+id)
	combat.restore({"forest:0":{"at":"invalid","hp":100},"forest:1":{"at":[1]},"barbarian:0":{"at":[null,3]},"yunye:0":42})
	for id in ["forest:0","forest:1","barbarian:0","yunye:0"]:
		var initial: Dictionary=combat.initial_states[id]
		check(combat.enemies[id].position==Vector2(initial.at[0],initial.at[1]),"invalid position uses correct member spawn "+id)
	check(combat.enemies["forest:0"].hp==20,"ordinary member restored to its own twenty health limit")
	var forest: CharacterBody2D=combat.enemies["forest:0"]
	var chief: CharacterBody2D=combat.enemies["yunye:chief"]
	forest.hp=7; forest.position=Vector2(-1333,707); forest.thirst=6
	chief.hp=0; chief.position=Vector2(3310,-830); chief.refresh()
	check(session.persistence.save_now(),"full village saved")
	game.queue_free(); await frames()
	await load_game()
	check(session.combat.enemies["forest:0"].hp==7 and session.combat.enemies["forest:0"].position==Vector2(-1333,707),"real restart preserves tribal damage and location")
	check(session.combat.enemies["forest:0"].thirst==6,"restart preserves tribal thirst")
	check(session.combat.enemies["yunye:chief"].hp==0 and not session.combat.enemies["yunye:chief"].visible,"real restart preserves defeated chief")
	check(session.combat.enemies["yunye:19"].hp==20,"restart finishes all entries past old forest-zero failure")
	game.queue_free(); await frames()
	if failures.is_empty(): print("TRIBAL_RESTORE_OK checks=",checks); quit(0)
	else: print(failures); quit(1)
