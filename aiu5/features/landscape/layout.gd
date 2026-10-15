# Shares protected geography and exact bridge openings between physics and ground drawing.
extends RefCounted

const BRIDGES := [310.0, 550.0, 900.0, 1300.0]
const MAIN_CHANNELS := [Rect2(12,0,24,600),Rect2(12,600,88,1000)]
const BRIDGE_HALF_WIDTH := 12.0
const MOUNTAINS := Rect2(2150,-1600,250,3200)
const PLAZA := Rect2(474,244,148,104)

static func bridge_bounds(y: float) -> Rect2:
	return Rect2(8,y-BRIDGE_HALF_WIDTH,98 if y>600 else 34,BRIDGE_HALF_WIDTH*2)

static func main_river_obstacles() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for channel: Rect2 in MAIN_CHANNELS:
		var cursor := channel.position.y
		for y: float in BRIDGES:
			var bridge := bridge_bounds(y)
			if bridge.end.y <= channel.position.y or bridge.position.y >= channel.end.y: continue
			var stop := maxf(cursor,bridge.position.y)
			if stop > cursor: result.append(Rect2(channel.position.x,cursor,channel.size.x,stop-cursor))
			cursor = maxf(cursor,bridge.end.y)
		if cursor < channel.end.y: result.append(Rect2(channel.position.x,cursor,channel.size.x,channel.end.y-cursor))
	return result
