# Provides loose starter materials and fixed public crafting benches without granting tools.
extends Node
const REGROW := 120.0
var session: Node
var online := 0.0
var collected: Dictionary = {}
var nodes: Dictionary = {}
class Pickup extends Node2D:
	var item := "wood"
	var available := true
	func _ready() -> void:
		set_meta("procedural_resource",true)
	func _draw() -> void:
		if not available: return
		if item=="wood":
			draw_line(Vector2(-5,2),Vector2(5,-4),Color("76543a"),3)
			draw_line(Vector2(-1,-1),Vector2(-5,-6),Color("b99863"),2)
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(-5,1),Vector2(-4,-4),Vector2(1,-6),Vector2(5,-2),Vector2(4,2)]),Color("999d8d"))
func start(controller: Node) -> void:
	session = controller
	_build()
func _build() -> void:
	# Each village has its own predictable entry point, avoiding any dependence on camera gifts.
	for village in [{"id":"desert","bench":Vector2(300,346),"materials":Vector2(224,306)},
		{"id":"forest","bench":Vector2(-1230,882),"materials":Vector2(-1280,854)}]:
		var bench_id: String = "outdoors:public:"+str(village.id)
		if not session.grounds.fixtures.any(func(f: Node2D) -> bool: return f.fixture_id==bench_id):
			session.grounds.add_fixture({"id":bench_id,"kind":"workbench","at":[village.bench.x,village.bench.y],"size":[36,24],"public_fixture":true})
		for i in range(12):
			var id: String = str(village.id)+":"+str(i)
			if nodes.has(id): continue
			var node := Pickup.new()
			node.item = "wood" if i<7 else "stone"
			node.position = village.materials+Vector2((i%4)*18,floori(i/4.0)*16)
			session.world.objects.add_child(node)
			nodes[id]=node
			_update(id)
func _update(id: String) -> void:
	var node: Node2D = nodes[id]
	node.available = online>=float(collected.get(id,0))
	node.queue_redraw()
	var key := "forage:"+id
	if not node.available:
		session.world.points.erase(key)
	else:
		session.world.points[key]={"position":node.position,"radius":10.0,"label":"散落树枝" if node.item=="wood" else "散落石头","action":"空手拾取","description":"E拾取1份；2分钟在线时间后补充。","source":node}
func gather(id: String) -> bool:
	var actor: CharacterBody2D = session.world.active_resident
	if not session.production.allowed(actor) or actor.room_id!="" or not nodes.has(id): return false
	var node: Node2D=nodes[id]
	if not node.available or actor.position.distance_to(node.position)>16: return false
	var before: Dictionary = session.inventory.export_data()
	if not session.inventory.exchange(actor.resident_id,{}, {node.item:1}):
		session.production.message.emit("背包已满，材料留在地上。")
		return false
	collected[id]=online+REGROW
	_update(id)
	return session.production.commit(before,"拾取"+str(session.inventory.Catalog.ITEMS[node.item].name)+"×1。")
func elapse(delta: float) -> void:
	online+=maxf(0,delta)
	for id: String in nodes:
		if not nodes[id].available and online>=float(collected.get(id,0)): _update(id)
func export_state() -> Dictionary:
	return {"online":online,"collected":collected.duplicate(true)}
func restore(data: Dictionary) -> void:
	online=maxf(0,float(data.get("online",0)))
	collected=data.get("collected",{}).duplicate(true)
	_build()
	for id: String in nodes: _update(id)
