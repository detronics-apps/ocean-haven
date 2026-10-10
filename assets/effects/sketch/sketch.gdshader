shader_type canvas_item;
// Turns a coloured picture into a pencil sketch on a Clue Board note (ClueMap): brown lines where
// the picture's shapes and colours change (its outline and inner edges), and a light pencil
// shading inside, darker where the picture is darker.

uniform vec4 ink : source_color = vec4(0.33, 0.24, 0.15, 1.0);
uniform float line_width = 1.5;

float tone(sampler2D picture, vec2 uv) {
	vec4 c = texture(picture, uv);
	return dot(c.rgb, vec3(0.299, 0.587, 0.114)) * c.a + (1.0 - c.a);  // (see-through = paper white)
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * line_width;
	float here = tone(TEXTURE, UV);
	float edge = abs(tone(TEXTURE, UV + vec2(px.x, 0.0)) - tone(TEXTURE, UV - vec2(px.x, 0.0)))
		+ abs(tone(TEXTURE, UV + vec2(0.0, px.y)) - tone(TEXTURE, UV - vec2(0.0, px.y)));
	float shade = texture(TEXTURE, UV).a * (1.0 - here) * 0.35;
	COLOR = vec4(ink.rgb, clamp(edge * 2.5 + shade, 0.0, 0.95));
}
