# Defines construction footprints, health, percentage armor and material recipes.
extends RefCounted
const FOOTPRINT := Vector2(96, 80)
const BUILDINGS := {
	"herb_house":{"name":"草药屋","hp":50.0,"defense":0,"cost":{"wood":50,"stone":30},"clinic":true},
	"wood_house": {"name": "初级木屋", "hp": 50.0, "defense": 0, "cost": {"wood": 100}},
	"stone_house": {"name": "中级石屋", "hp": 100.0, "defense": 10, "cost": {"stone": 100, "wood": 50}},
	"iron_house": {"name": "高级铁屋", "hp": 200.0, "defense": 20, "cost": {"sand_bucket": 5, "crude_iron": 50, "stone": 50, "wood": 50}},
	"arrow_tower": {"name": "箭楼", "hp": 100.0, "defense": 10, "cost": {"wood": 100, "stone": 100}},
	# A cloud ladder opens a gap in the plateau cliff, connecting the desert floor to the highland.
	"cloud_ladder": {"name": "云梯", "hp": 1.0, "defense": 0, "cost": {"wood": 100}, "ladder": true}}
static func damage(raw: float, defense: int) -> float:
	return maxf(0, raw) * (1.0 - clampf(defense / 100.0, 0, 1))
