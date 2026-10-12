# Resolves the approved transparent rune artwork; normal items never use this atlas.
extends RefCounted
const Mapping := preload("res://features/gifts/mapping.gd")
const Sheet := preload("res://assets/gifts/rune-icons.png")
static var textures: Dictionary = {}

static func texture(item: String) -> Texture2D:
	var key := "wooden_cup" if item == "water_cup" else item
	var index := Mapping.ITEMS.find(key)
	if index < 0: return null
	if not textures.has(key):
		var icon := AtlasTexture.new()
		icon.atlas = Sheet
		var cell := Vector2(Sheet.get_width() / 6.0, Sheet.get_height() / 3.0)
		icon.region = Rect2(Vector2(index % 6, index / 6) * cell, cell)
		icon.filter_clip = true
		textures[key] = icon
	return textures[key]
