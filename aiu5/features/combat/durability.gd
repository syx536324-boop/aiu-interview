# Defines per-instance durability, including the partial fifteen-use counter.
extends RefCounted
const Origin := preload("res://features/gifts/provenance.gd")
const MAX := 40
const PER_CELL := 15
static func normalize(data: Dictionary = {}) -> Dictionary:
	var remaining := clampi(int(data.get("durability",MAX)),0,MAX)
	var result := {"durability":remaining,"uses":clampi(int(data.get("uses",0)),0,PER_CELL-1) if remaining > 0 else 0}
	result.merge(Origin.fields(data))
	return result
static func consume(wear: Dictionary) -> bool:
	if int(wear.durability) <= 0: return false
	wear.uses += 1
	if wear.uses >= PER_CELL:
		wear.uses = 0
		wear.durability -= 1
	return true
static func describe(data: Dictionary) -> String:
	var wear := normalize(data)
	return "耐久 %d/40 · 本格 %d/15次%s" % [wear.durability,wear.uses," · 已损坏" if wear.durability==0 else ""]
