# Checks actual workshop recipe descriptions and touch-hint translation in an isolated session.
extends Node
const Hints := preload("res://features/interface/input_hints.gd")
var failures: Array[String] = []
var checks := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _ready() -> void:
	var folder := OS.get_environment("AIU5_BENCH_DIR")
	assert(folder != "")
	DirAccess.make_dir_recursive_absolute(folder)
	for pair: Array in [["AIU5_STATE_PATH","state.json"],["AIU5_PROFILE_PATH","names.cfg"],["AIU5_SAVES_DIR","slots"],["AIU5_LEGACY_PATH","none.json"],["AIU5_LEGACY_PROFILE_PATH","none.cfg"]]: OS.set_environment(pair[0],folder+"/"+pair[1])
	OS.set_environment("AIU5_WORLD_PROFILE","starter_v2")
	OS.set_environment("AIU5_MOBILE_PREVIEW","")
	check(Hints.text("按 E 打开") == "按 E 打开","desktop interaction labels unchanged")
	OS.set_environment("AIU5_MOBILE_PREVIEW","1")
	for sample: String in ["按 E 打开","按e开门","按E采集","E拾取","E  工作台","工作台E/T"]:
		var translated := Hints.text(sample)
		check("交互" in translated and "E" not in translated and "e" not in translated,"touch hint "+sample)
	check(Hints.text("Engine 12E apple") == "Engine 12E apple","English words and identifiers preserved")
	check(Hints.text("请按e开门") == "请按交互开门","button name matches requested caption")
	var game: Node = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	for i in range(12): await get_tree().process_frame
	var s: Node = game.get_node("Session")
	s.simulation.set_process(false)
	var fixture: Node2D
	for candidate: Node2D in s.grounds.fixtures:
		if candidate.kind == "workbench": fixture=candidate;break
	check(is_instance_valid(fixture),"new game contains a real workbench")
	if is_instance_valid(fixture):
		s.production.opened=true;s.production.mode="craft";s.production.fixture=fixture
		var snapshot: Dictionary=s.production.snapshot()
		for id: String in ["hoe","pickaxe","stone_axe","scissors","bucket","watering_can"]:
			var recipe: Dictionary={}
			for candidate: Dictionary in snapshot.recipes:
				if str(candidate.id)==id:recipe=candidate;break
			check(not str(recipe.get("usage","")).is_empty(),"recipe has purpose: "+id)
			var view: Node=game.get_node("Workshop")
			view.current=snapshot;view.selected_id=id;view.category="all";view._render()
			check("用途：" in view.details.text and "合成材料" in view.details.text,"real tool detail includes purpose and cost: "+id)
		check(game.get_node("Workshop").detail_scroll.size.y==140,"long descriptions have bounded scroll area")
	game.queue_free()
	for i in range(5): await get_tree().process_frame
	var result := {"checks":checks,"failures":failures}
	var file:=FileAccess.open(folder+"/result.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print("TOOLS_HINT_OK" if failures.is_empty() else "TOOLS_HINT_FAILED"," ",JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)
