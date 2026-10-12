# Presents the gift reference cards from backend entries; browsing has no gameplay side effects.
extends ScrollContainer
const Icons := preload("res://features/interface/gift_icon_atlas.gd")

func populate(entries: Array[Dictionary]) -> void:
	name = "GiftDetails"
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	custom_minimum_size.y = 234
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.name = "Cards"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	for entry: Dictionary in entries:
		var card := PanelContainer.new()
		card.name = str(entry.item)
		card.custom_minimum_size = Vector2(174, 114)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color("493b30")
		style.border_color = Color("79617e")
		style.set_border_width_all(1)
		style.set_content_margin_all(5)
		card.add_theme_stylebox_override("panel", style)
		grid.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		card.add_child(column)
		var top := HBoxContainer.new()
		column.add_child(top)
		var icon := TextureRect.new()
		icon.texture = Icons.texture(str(entry.item))
		icon.custom_minimum_size = Vector2(56, 56)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		top.add_child(icon)
		var title := Label.new()
		title.text = str(entry.name)
		title.add_theme_font_size_override("font_size", 13)
		title.add_theme_color_override("font_color", Color("f4deba"))
		top.add_child(title)
		var recognition := Label.new()
		recognition.text = "识别：" + str(entry.recognizes)
		recognition.add_theme_font_size_override("font_size", 10)
		recognition.add_theme_color_override("font_color", Color("bdb2cd"))
		column.add_child(recognition)
		var note := Label.new()
		note.text = str(entry.note)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", 10)
		note.add_theme_color_override("font_color", Color("d3c3a5"))
		column.add_child(note)
