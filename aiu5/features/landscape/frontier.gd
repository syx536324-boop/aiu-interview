# Shares exact woodland river and bridge geometry between drawing, physics and navigation.
extends Node2D

const RIVERS := [
	[Vector2(12,800),Vector2(-700,1300),Vector2(-1200,2100),Vector2(-2100,2800)],
	[Vector2(-700,1300),Vector2(-1400,1100),Vector2(-2200,800)],
	[Vector2(-1200,2100),Vector2(-900,3000),Vector2(-400,4000)],
	[Vector2(-1400,1100),Vector2(-1800,200),Vector2(-2100,-800)]]
const GIANTS := [Vector2(-2100,-1300),Vector2(-1700,-600),Vector2(-1950,500),Vector2(-2200,1900),Vector2(-1650,2500),Vector2(-700,2500),Vector2(-1500,3600),Vector2(-2200,4400),Vector2(-500,4500)]
const WATER_HALF_WIDTH := 9.0
const BANK_HALF_WIDTH := 13.0
const BRIDGE_HALF_WIDTH := 18.0
const BRIDGE_HALF_LENGTH := 19.0
const NAVIGATION_STRIP := 4.0
var world: Node
var render_region := Rect2()

class GiantTree:
	extends Node2D
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(-24,0),Vector2(-10,-35),Vector2(-12,-78),Vector2(10,-85),Vector2(13,-35),Vector2(27,0),Vector2(8,-5),Vector2(-5,-5)]),Color("554334"))
		draw_rect(Rect2(-5,-76,10,66),Color("8d6a48"))
		draw_line(Vector2(0,-60),Vector2(-29,-83),Color("72533a"),8)
		draw_line(Vector2(3,-53),Vector2(29,-76),Color("72533a"),7)
		for level in range(3):
			var y := -55-level*20
			var width := 56-level*9
			draw_colored_polygon(PackedVector2Array([Vector2(-width,y),Vector2(-width+6,y-17),Vector2(-23,y-25),Vector2(13,y-27),Vector2(width-9,y-19),Vector2(width,y-5),Vector2(width-10,y+7),Vector2(19,y+12),Vector2(-19,y+9)]),Color("244c37").lightened(level*0.07))
			for x in [-30,-9,15,29]: draw_rect(Rect2(x,y-13+(x%7),8,3),Color("628550"))

func start(village: Node) -> void:
	world = village
	# Keep channels above terrain but before the y-sorted people and props.
	# A negative Z would hide water beneath the opaque terrain chunks.
	world.move_child(self,world.objects.get_index())
	for section: Dictionary in water_sections():
		var body: StaticBody2D = world._body(self, section.center, section.size)
		body.rotation = section.angle
		body.set_meta("navigation_footprint", section.footprint)
	for at: Vector2 in river_junctions():
		world._body(self, at, Vector2.ONE * WATER_HALF_WIDTH * 2)
	for at: Vector2 in GIANTS:
		var tree := GiantTree.new()
		tree.name = "NativeGiantTree"
		tree.position = at
		world.objects.add_child(tree)
		world._body(tree, Vector2(0,-15), Vector2(28,30))
	set_process(true)

func _process(_delta: float) -> void:
	var area := Rect2(world.active_resident.position-Vector2(650,450),Vector2(1300,900))
	if render_region != area:
		render_region = area
		queue_redraw()

func _draw() -> void:
	# Paint all channels before the crossings, including junctions shared by several branches.
	for segment: Dictionary in river_segments():
		if not segment_bounds(segment).grow(BANK_HALF_WIDTH).intersects(render_region): continue
		draw_colored_polygon(strip_polygon(segment.a, segment.b, BANK_HALF_WIDTH),Color("b5b28a"))
		draw_colored_polygon(strip_polygon(segment.a, segment.b, WATER_HALF_WIDTH),Color("518d96"))
	for at: Vector2 in river_junctions():
		if render_region.grow(BANK_HALF_WIDTH).has_point(at):
			draw_rect(Rect2(at-Vector2.ONE*WATER_HALF_WIDTH,Vector2.ONE*WATER_HALF_WIDTH*2),Color("518d96"))
	for segment: Dictionary in river_segments():
		var mid: Vector2 = segment.mid
		if not render_region.grow(30).has_point(mid): continue
		var tangent: Vector2 = segment.direction
		var normal := tangent.orthogonal()
		var deck := strip_polygon(mid-normal*BRIDGE_HALF_LENGTH,mid+normal*BRIDGE_HALF_LENGTH,BRIDGE_HALF_WIDTH)
		draw_colored_polygon(deck,Color("654c33"))
		for offset in range(-16,18,5):
			draw_line(mid+tangent*offset-normal*(BRIDGE_HALF_LENGTH-1),mid+tangent*offset+normal*(BRIDGE_HALF_LENGTH-1),Color("bc9460"),3)
		for side in [-BRIDGE_HALF_WIDTH+1,BRIDGE_HALF_WIDTH-1]:
			draw_line(mid+tangent*side-normal*BRIDGE_HALF_LENGTH,mid+tangent*side+normal*BRIDGE_HALF_LENGTH,Color("e0ba7a"),2)

static func river_segments() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for route: Array in RIVERS:
		for i in range(route.size()-1):
			var a: Vector2 = route[i]
			var b: Vector2 = route[i+1]
			result.append({"a":a,"b":b,"mid":a.lerp(b,0.5),"direction":a.direction_to(b)})
	return result

static func river_junctions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for route: Array in RIVERS:
		for at: Vector2 in route:
			if not result.has(at): result.append(at)
	return result

static func strip_polygon(a: Vector2, b: Vector2, half_width: float) -> PackedVector2Array:
	var normal := a.direction_to(b).orthogonal() * half_width
	return PackedVector2Array([a-normal,b-normal,b+normal,a+normal])

static func segment_bounds(segment: Dictionary) -> Rect2:
	var a: Vector2 = segment.a
	var b: Vector2 = segment.b
	return Rect2(a.min(b),(b-a).abs())

static func _section(a: Vector2, b: Vector2) -> Dictionary:
	var polygon := strip_polygon(a,b,WATER_HALF_WIDTH)
	return {"a":a,"b":b,"center":a.lerp(b,0.5),"size":Vector2(a.distance_to(b),WATER_HALF_WIDTH*2),"angle":a.angle_to_point(b),"polygon":polygon,"footprint":polygon_footprint(polygon)}

static func water_sections() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for segment: Dictionary in river_segments():
		var half_gap: Vector2 = segment.direction * BRIDGE_HALF_WIDTH
		result.append(_section(segment.a,segment.mid-half_gap))
		result.append(_section(segment.mid+half_gap,segment.b))
	return result

static func polygon_footprint(polygon: PackedVector2Array) -> Array[Rect2]:
	# Conservative horizontal strips preserve the actual rotated water shape for the grid.
	# A segment's large axis-aligned bounding box would incorrectly close its bridge.
	var result: Array[Rect2] = []
	var low := polygon[0].y
	var high := low
	for point: Vector2 in polygon:
		low = minf(low,point.y)
		high = maxf(high,point.y)
	var y := floorf(low/NAVIGATION_STRIP)*NAVIGATION_STRIP
	while y < high:
		var left := INF
		var right := -INF
		for i in range(polygon.size()):
			var a := polygon[i]
			var b := polygon[(i+1)%polygon.size()]
			for point: Vector2 in [a,b]:
				if point.y >= y and point.y <= y+NAVIGATION_STRIP:
					left = minf(left,point.x)
					right = maxf(right,point.x)
			if is_equal_approx(a.y,b.y): continue
			for edge: float in [y,y+NAVIGATION_STRIP]:
				var ratio := (edge-a.y)/(b.y-a.y)
				if ratio < 0 or ratio > 1: continue
				var x := lerpf(a.x,b.x,ratio)
				left = minf(left,x)
				right = maxf(right,x)
		if left < right: result.append(Rect2(left,y,right-left,NAVIGATION_STRIP))
		y += NAVIGATION_STRIP
	return result

static func obstacles() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for section: Dictionary in water_sections(): result.append_array(section.footprint)
	for at: Vector2 in river_junctions(): result.append(Rect2(at-Vector2.ONE*WATER_HALF_WIDTH,Vector2.ONE*WATER_HALF_WIDTH*2))
	for at: Vector2 in GIANTS: result.append(Rect2(at-Vector2(14,30),Vector2(28,30)))
	return result

static func protected(bounds: Rect2) -> bool:
	for at: Vector2 in GIANTS:
		if Rect2(at-Vector2(56,120),Vector2(112,128)).intersects(bounds): return true
	for segment: Dictionary in river_segments():
		if Geometry2D.get_closest_point_to_segment(bounds.get_center(),segment.a,segment.b).distance_to(bounds.get_center()) <= bounds.size.length()/2+BRIDGE_HALF_LENGTH: return true
	return false

static func nearest_water(at: Vector2) -> Vector2:
	var result := Vector2(46,310)
	var distance := INF
	for segment: Dictionary in river_segments():
		var point := Geometry2D.get_closest_point_to_segment(at,segment.a,segment.b)
		if point.distance_squared_to(at) < distance:
			distance = point.distance_squared_to(at)
			result = point
	return result
