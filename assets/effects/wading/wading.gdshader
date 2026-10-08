shader_type canvas_item;
// A wading animal's legs where they're in the water or mud (only its own pixels, never a box
// round it): rows from `from_row` down take the ground's colour. Water is see-through (the
// feet still show, with a light line where the water starts); mud hides the feet.

uniform float from_row = 999.0;
uniform vec4 ground_colour : source_color = vec4(0.32, 0.55, 0.58, 1.0);
uniform bool see_through = true;

void fragment() {
	vec4 c = COLOR;  // (the texture times modulate)
	float row = floor(UV.y / TEXTURE_PIXEL_SIZE.y);
	if (c.a > 0.0 && row >= from_row) {
		if (see_through) {
			c.rgb = mix(c.rgb, ground_colour.rgb, 0.82);
			if (row < from_row + 1.0) {
				c.rgb = mix(c.rgb, vec3(0.9, 0.97, 1.0), 0.3);
			}
		} else {
			c.rgb = ground_colour.rgb;
		}
	}
	COLOR = c;
}
