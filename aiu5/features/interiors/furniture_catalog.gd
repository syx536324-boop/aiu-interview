# Defines the five freely placeable wooden furniture types and their default footprints.
extends RefCounted

const TYPES := {
	"campfire":{"name":"篝火","size":Vector2(24,24)},
	"building_bench": {"name":"建筑台","size":Vector2(96,80)},
	"workbench": {"name": "工作台", "size": Vector2(36, 24)},
	"fence": {"name": "围栏", "size": Vector2(24, 12)},
	"stove": {"name": "灶台", "size": Vector2(48, 32)},
	"bed": {"name": "床", "size": Vector2(32, 48)},
	"cabinet": {"name": "柜子", "size": Vector2(40, 28)},
	"table": {"name": "桌子", "size": Vector2(48, 24)},
	"chair": {"name": "椅子", "size": Vector2(14, 18)},
	"chest": {"name": "箱子", "size": Vector2(28, 20)}
}
