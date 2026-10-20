# Animates a wood goblin and executes one telegraphed attack at a time with independent skill cooldowns.
extends "res://features/combat/enemy.gd"
const Rules := preload("res://features/monsters/catalog.gd")
var monsters: Node
var level := 1
var cooldowns: Dictionary={}
var attack := ""
var attack_left := 0.0
var recovery_left := 0.0
var attack_direction := Vector2.DOWN
var aim := Vector2.ZERO
var target_key := ""
var scan_left := 0.0
var route_left := 0.0
var wander_left := 0.0
var wander_at := Vector2.ZERO
var walk_phase := 0.0
var cast_elapsed := 0.0
var target_ref: WeakRef
func _ready() -> void:
	super._ready()
	sprite.visible=false
	set_meta("streaming_exempt",true)
	set_meta("goblin",true)
	add_to_group("monsters")
	var tag:=Label.new(); tag.text="哥布林 Lv.%d"%level; tag.position=Vector2(-24,-38)
	var font:=SystemFont.new(); font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	tag.add_theme_font_override("font",font); tag.add_theme_font_size_override("font_size",8); tag.modulate=Color("c6d6a3"); add_child(tag)
func label() -> String: return "木属性哥布林 · Lv.%d"%level
func refresh() -> void:
	super.refresh()
	if hp<=0:
		attack=""; velocity=Vector2.ZERO
		if is_instance_valid(monsters): monsters.note_death(self)
func _physics_process(delta: float) -> void:
	if is_instance_valid(monsters) and monsters.running(): step(delta)
func step(delta: float) -> void:
	if hp<=0: return
	for id: String in cooldowns: cooldowns[id]=maxf(0,float(cooldowns[id])-delta)
	recovery_left=maxf(0,recovery_left-delta)
	cast_elapsed=maxf(0,cast_elapsed-delta)
	scan_left-=delta; route_left-=delta; wander_left-=delta
	if attack!="":
		attack_left=maxf(0,attack_left-delta)
		if attack_left<=0:
			var chosen:=attack; attack=""
			monsters.resolve_attack(self,chosen,aim,attack_direction,target_key)
			recovery_left=float(Rules.SKILLS[chosen].recovery); cast_elapsed=recovery_left
		queue_redraw(); return
	if recovery_left>0: queue_redraw(); return
	var target: Node=target_ref.get_ref() if target_ref!=null else null
	if scan_left<=0 or not monsters.same_place(self,target) or target.dead:
		target=monsters.choose_target(self); target_ref=weakref(target) if is_instance_valid(target) else null; scan_left=0.2
	if is_instance_valid(target):
		var gap: float=position.distance_to(target.position)
		var chosen := choose_attack(gap)
		if chosen!="" and monsters.line_clear(self,target.position):
			begin_attack(chosen,target); queue_redraw(); return
		monsters.move_body(self,target.position,delta)
	else:
		if wander_left<=0 or position.distance_to(wander_at)<12:
			wander_at=monsters.wander_destination(self); wander_left=2.5
		monsters.move_body(self,wander_at,delta,22.0)
	queue_redraw()
func choose_attack(gap: float) -> String:
	for id: String in ["sweep","heavy","roots","thorn","basic"]:
		if id not in Rules.skills(level) or float(cooldowns.get(id,0))>0 or gap>float(Rules.SKILLS[id].range): continue
		if id in ["roots","thorn"] and gap<=30: continue
		return id
	return ""
func begin_attack(id: String,target: Node) -> bool:
	if attack!="" or recovery_left>0 or id not in Rules.skills(level) or float(cooldowns.get(id,0))>0: return false
	attack=id; attack_left=float(Rules.SKILLS[id].windup)
	cooldowns[id]=float(Rules.SKILLS[id].cooldown)
	aim=target.position; target_key=monsters.actor_key(target)
	attack_direction=position.direction_to(aim); facing=1 if attack_direction.x>=0 else -1
	velocity=Vector2.ZERO
	return true
func saved() -> Dictionary:
	return {"level":level,"hp":hp,"at":[position.x,position.y],"cooldowns":cooldowns.duplicate(),"attack":attack,"attack_left":attack_left,"recovery":recovery_left,"aim":[aim.x,aim.y],"direction":[attack_direction.x,attack_direction.y],"target":target_key}
func load_saved(record: Dictionary) -> void:
	level=clampi(int(record.get("level",1)),1,5); npc_level=level
	max_hp=Rules.life(level); hp=clampf(float(record.get("hp",max_hp)),0,max_hp)
	position=Vector2(record.at[0],record.at[1]); home_anchor=Vector2(record.home[0],record.home[1])
	cooldowns=record.get("cooldowns",{}).duplicate()
	attack=str(record.get("attack","")); attack_left=maxf(0,float(record.get("attack_left",0))); recovery_left=maxf(0,float(record.get("recovery",0)))
	if attack not in Rules.skills(level): attack=""
	aim=Vector2(record.get("aim",[position.x,position.y])[0],record.get("aim",[position.x,position.y])[1])
	var direction: Array=record.get("direction",[0,1]); attack_direction=Vector2(direction[0],direction[1]); target_key=str(record.get("target",""))
func _draw() -> void:
	if hp<=0: return
	var bob:=0.0
	if velocity.length()>1: bob=sin(walk_phase)*0.6
	var lift:=roundf(bob)
	var skin:=Color("72984d"); var edge:=Color("304b32"); var cloth:=Color("735638")
	draw_ellipse_shadow()
	for side: int in [-1,1]:
		var step:=roundf(sin(walk_phase+side*PI/2)*2) if velocity.length()>1 else 0.0
		draw_rect(Rect2(side*3-2,-4+step,4,4),edge)
	draw_rect(Rect2(-5,-12+lift,10,9),edge); draw_rect(Rect2(-4,-11+lift,8,7),cloth)
	draw_rect(Rect2(-6,-21+lift,12,11),edge); draw_rect(Rect2(-5,-20+lift,10,9),skin)
	for side: int in [-1,1]: draw_colored_polygon(PackedVector2Array([Vector2(side*5,-19+lift),Vector2(side*10,-20+lift),Vector2(side*6,-14+lift)]),skin)
	draw_rect(Rect2(-3,-17+lift,2,2),Color("e4d778")); draw_rect(Rect2(2,-17+lift,2,2),Color("e4d778"))
	draw_rect(Rect2(-3,-13+lift,6,1),edge); draw_rect(Rect2(-2,-13+lift,1,2),Color("ede3bd")); draw_rect(Rect2(2,-13+lift,1,2),Color("ede3bd"))
	if level>1: draw_rect(Rect2(-5,-21+lift,10,2),[Color("9f7254"),Color("9f7254"),Color("66ad8f"),Color("6b91b8"),Color("cbb66c")][level-1])
	var arm:=Vector2(7*facing,-10+lift)
	var swing:=attack_direction if attack!="" or cast_elapsed>0 else Vector2(0,-1)
	var end:=arm+swing.rotated(-0.7 if attack!="" else (0.8 if cast_elapsed>0 else 0))*10
	draw_line(arm,end,Color("3c3427"),4); draw_line(arm,end,Color("9d7b4a"),2)
	if attack!="":
		draw_arc(Vector2.ZERO,float(Rules.SKILLS[attack].range) if attack in ["heavy","sweep","basic"] else 13,attack_direction.angle()-0.7,attack_direction.angle()+0.7,12,Color(0.8,0.65,0.25,0.55),1)
	if hp<max_hp:
		draw_rect(Rect2(-10,-27,20,3),Color("302c27")); draw_rect(Rect2(-10,-27,20*hp/max_hp,3),Color("9aa85c"))
func draw_ellipse_shadow() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-7,-1),Vector2(-5,-3),Vector2(5,-3),Vector2(7,-1),Vector2(4,1),Vector2(-4,1)]),Color(0.08,0.10,0.07,0.35))
