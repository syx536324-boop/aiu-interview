# Owns the independent torch slot, atomic equipment swaps, online burning and 80-world-pixel light.
extends Node
const Record := preload("res://features/lighting/torch_record.gd")
var session: Node
var lamp: PointLight2D
func start(controller: Node) -> void:
	session = controller
	var image := Image.create(80,80,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	lamp = PointLight2D.new()
	lamp.texture = ImageTexture.create_from_image(image)
	lamp.texture_scale = 1.0
	lamp.color = Color("ffe4b0")
	lamp.energy = 0.8
	lamp.enabled = false
	add_child(lamp)
func equipped(id: String) -> Dictionary:
	return session.magic.ensure(id).torch
func can_ignite(id: String) -> bool:
	var record := equipped(id)
	return not record.is_empty() and float(record.fuel_left)>0 and not record.lit
func ignite(id: String) -> bool:
	if not can_ignite(id): return false
	var record := equipped(id)
	record.lit = true
	record.burn_left = Record.BURN_SESSION
	refresh_light()
	return true
func equip(id: String, index := -1) -> bool:
	if id!=session.world.active_resident.resident_id or not session.magic._begin(id): return false
	var before: Dictionary = session.inventory.export_data()
	var outgoing := equipped(id).duplicate(true)
	if not outgoing.is_empty(): outgoing.lit = false
	var swapped: Dictionary = session.inventory.swap_armor(id,"torch" if index>=0 else "",outgoing,index)
	if not swapped.ok: return session.magic._reject("背包已满或缺少火把，原装备和耐久保留。")
	session.magic.ensure(id).torch = swapped.record
	var result: bool = session.production.commit(before,"已装备火把；在点亮的篝火旁按E点燃，或使用火系三级H。" if index>=0 else "火把已熄灭并卸回背包，剩余耐久保留。")
	refresh_light()
	return result
func slot_clicked() -> void:
	if not session.combat.ready_for_action(): return
	if equipped(session.world.active_resident.resident_id).is_empty(): session.toggle_inventory()
	else: equip(session.world.active_resident.resident_id)
	session.refresh_interface()
func advance(delta: float) -> void:
	var actor: CharacterBody2D = session.world.active_resident
	# Every path refreshes the lamp: an idle, dead, paused or non-carrying character must
	# never keep the previous character's light enabled.
	if actor.dead or session.overview or session.menu_paused or session.get_tree().paused:
		refresh_light()
		return
	var record := equipped(actor.resident_id)
	if record.is_empty() or not record.lit:
		refresh_light()
		return
	var burning := minf(maxf(0,delta),minf(float(record.fuel_left),float(record.burn_left)))
	record.fuel_left = maxf(0,float(record.fuel_left)-burning)
	record.burn_left = maxf(0,float(record.burn_left)-burning)
	if record.fuel_left<=0:
		session.magic.ensure(actor.resident_id).torch = {}
		session._set_notice("火把累计燃烧10分钟，已报废。")
	elif record.burn_left<=0:
		record.lit = false
		session._set_notice("火把燃烧5分钟后熄灭；可在点亮的篝火旁E重新点燃。")
	refresh_light()
func _process(_delta: float) -> void:
	refresh_light()
func refresh_light() -> void:
	if not is_instance_valid(session) or not is_instance_valid(lamp): return
	var actor: CharacterBody2D = session.world.active_resident
	if lamp.get_parent()!=actor: lamp.reparent(actor, false)
	lamp.position = Vector2.ZERO
	var record := equipped(actor.resident_id)
	lamp.enabled = not actor.dead and not session.overview and not record.is_empty() and bool(record.get("lit",false))
func snapshot(id: String) -> Dictionary:
	var record := equipped(id)
	return {"item":"torch" if not record.is_empty() else "", "lit":record.get("lit",false), "fuel_left":record.get("fuel_left",0), "durability":ceili(float(record.get("fuel_left",0))/Record.LIFETIME*40), "description":Record.describe(record) if not record.is_empty() else "火把格 · 点击打开背包", "editable":session.magic._error(id)==""}
