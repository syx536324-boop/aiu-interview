# Owns the saved online day clock and smooth world lighting; one real minute equals one game hour.
extends Node
signal changed(state: Dictionary)
const PERIOD := 1440.0
const START := 480.0
var elapsed := 0.0
var session: Node
var light: CanvasModulate
const HOURS := [0.0,5.0,6.0,7.0,9.0,16.0,18.0,20.0,24.0]
const COLORS := [Color("566080"),Color("566080"),Color("c1a59b"),Color("f4eedc"),Color.WHITE,Color.WHITE,Color("ddae8b"),Color("566080"),Color("566080")]
func start(controller: Node) -> void:
	session = controller
	light = CanvasModulate.new()
	add_child(light)
	_refresh()
func advance(delta: float) -> void:
	elapsed += maxf(0,delta)
	_refresh()
func hour() -> float:
	return fposmod(START+elapsed,PERIOD)/60.0
func tint(h: float) -> Color:
	for i in range(HOURS.size()-1):
		if h >= HOURS[i] and h < HOURS[i+1]:
			var blend := smoothstep(HOURS[i],HOURS[i+1],h)
			return COLORS[i].lerp(COLORS[i+1],blend)
	return COLORS[0]
func snapshot() -> Dictionary:
	var h := hour()
	var minutes := floori(h*60)
	var phase := "夜晚"
	if h >= 5 and h < 7: phase = "黎明"
	elif h >= 7 and h < 17: phase = "白昼"
	elif h >= 17 and h < 20: phase = "黄昏"
	return {"day":floori((START+elapsed)/PERIOD)+1,"hour":h,"phase":phase,"clock":"%02d:%02d" % [minutes/60,minutes%60]}
func _refresh() -> void:
	if is_instance_valid(light):
		var color := tint(hour())
		if is_instance_valid(session) and session.world.active_resident.room_id != "":
			color=Color("11141d") if session.world.active_resident.room_id=="mine" else color.lerp(Color.WHITE,0.4)
		light.color = color
	changed.emit(snapshot())
func export_state() -> Dictionary:
	return {"version":1,"elapsed":elapsed}
func restore(data: Dictionary) -> void:
	var value := float(data.get("elapsed",0))
	elapsed = maxf(0,value) if is_finite(value) else 0.0
	_refresh()
