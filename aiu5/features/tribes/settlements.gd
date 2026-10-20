# Supplies housing and functional facilities proportional to finite tribe populations.
extends RefCounted
const Room := preload("res://features/interiors/room.gd")
const RoomLayout := preload("res://features/interiors/layout.gd")
var runtime: Node
var counts: Dictionary={}
var nodes: Dictionary={}
func match_population(tribe: String, people: int) -> void:
 var required := ceili(maxi(1,people)/4.0)
 var before := int(counts.get(tribe,0))
 for i in range(before,required):
  var center: Vector2=runtime.centers[tribe]
  var at := center+Vector2(-230+(i%4)*132,-220+floori(i/4.0)*128)
  _home(tribe,"house"+str(i),"wood_house",at,4)
 counts[tribe]=maxi(before,required)
 if before==0:
  var center: Vector2=runtime.centers[tribe]
  _home(tribe,"kitchen","kitchen",center+Vector2(-200,210),0)
  _home(tribe,"smith","blacksmith",center+Vector2(140,210),0)
  _home(tribe,"herbs","herb_house",center+Vector2(-50,210),0)
  var id := "outdoors:tribe:"+tribe+":workbench"
  if not runtime.session.grounds.retired_fixtures.has(id) and not runtime.session.grounds.fixtures.any(func(f: Node)->bool:return f.fixture_id==id): runtime.session.grounds.add_fixture({"id":id,"kind":"workbench","at":[center.x-80,center.y+70],"size":[36,24],"public_fixture":true})
  for y in range(2):
   for x in range(4): runtime.session.homestead.plots.append({"x":center.x+120+x*16,"y":center.y+90+y*16,"w":16,"h":16,"age":0.0,"dry":true,"crop":"","growth":0.0,"tribe":tribe})
  runtime.session.homestead.refresh()
 runtime.session.world.refresh_obstacles()
func _home(tribe: String, suffix: String, template: String, at: Vector2, beds: int) -> void:
 var s: Node=runtime.session; var id := "settlement:"+tribe+":"+suffix
 if s.world.homes.any(func(h: Dictionary)->bool:return h.id==id): return
 var labels := {"wood_house":"住屋","kitchen":"灶房","blacksmith":"铁匠铺","herb_house":"草药屋"}
 var record := {"id":id,"name":str(runtime.names[tribe])+str(labels[template])+suffix.trim_prefix("house"),"atlas":"house","region":Rect2(0,0,64,48),"at":at,"body":Vector2(52,27),"door":at+Vector2(32,54),"description":"部落设施","tribe":tribe,"function":template,"beds":beds,"template":template}
 s.world.homes.append(record)
 s.world.points[id]={"position":record.door,"radius":25.0,"label":record.name,"action":"进屋","description":record.description}
 var node: Node=s.world._prop(s.world.HOUSE,record.region,at,record.body); nodes[id]=node; s.world.houses.append(node)
 s.interiors.special_rooms[id]=_room.bind(id)
func _room(id: String) -> Node:
 var s: Node=runtime.session; var home: Dictionary=s.world.home_data(id)
 var data: Dictionary=RoomLayout.ROOMS.get(str(home.template),RoomLayout.ROOMS.house).duplicate(true)
 if home.template=="wood_house":
  data.size=Vector2(272,192); data.furniture=[]
  for i in range(int(home.beds)): data.furniture.append(["bed",Vector2(20+i*60,38),Vector2(32,48),i%3])
 var room := Room.new(); room.configure(home,data,s.interiors.layout_overrides.get(id,[{"missing":true}])); return room
func export_state() -> Dictionary: return counts.duplicate()
func restore(data: Dictionary) -> void:
 # Structures are deterministic; retain generated footprints when rolling back population to avoid deleting owned furniture.
 for tribe: String in ["forest","barbarian","yunye"]: match_population(tribe,maxi(20,runtime.population.count(tribe)))
