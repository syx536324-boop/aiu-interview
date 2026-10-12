# Defines the village's two ordinary ambient animals without livestock breeding rules.
extends RefCounted
const TYPES := {
	"dog":{"name":"村里的狗", "sheet":preload("res://assets/ninja_adventure/Actor/Animal/DogOrange/SpriteSheet.png"), "bounds":Rect2(300,232,60,30), "at":Vector2(342,248)},
	"bird":{"name":"村里的鸟", "sheet":preload("res://assets/ninja_adventure/Actor/Animal/Parrot/SpriteSheetBlue.png"), "bounds":Rect2(356,202,40,38), "at":Vector2(376,218)}}
static func initial_records() -> Array:
	var result: Array = []
	for kind: String in TYPES:
		var at: Vector2 = TYPES[kind].at
		result.append({"id":kind+":1","species":kind,"sex":"female","growth":300.0,"position":[at.x,at.y]})
	return result
