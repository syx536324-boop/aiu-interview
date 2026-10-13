// Recolors the approved atlas's cyan rune ink while retaining the item's original painted material.
shader_type canvas_item;
uniform vec4 rune_color : source_color = vec4(1.0);
varying vec4 vertex_modulate;
void vertex() {
	vertex_modulate = COLOR;
}
void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	if (ink.g > ink.r * 1.25 && ink.b > ink.r * 1.25 && ink.g > 0.3 && ink.b > 0.3) {
		ink.rgb = rune_color.rgb * clamp(max(ink.g, ink.b), 0.5, 1.0);
	}
	COLOR = ink * vertex_modulate;
}
