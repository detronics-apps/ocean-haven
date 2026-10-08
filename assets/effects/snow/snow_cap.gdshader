shader_type canvas_item;
// Snow on a tree (Polar Ocean): every pixel with open air within `depth` rows above it turns
// snowy white, so the tops of the branches carry snow: deeper as the freeze goes on, none in
// open water. Only the tree's own pixels change.

uniform float depth = 0.0;

void fragment() {
	vec4 c = COLOR;
	if (c.a > 0.0 && depth > 0.0) {
		float rows = ceil(depth);
		for (float i = 1.0; i <= 3.0; i += 1.0) {
			if (i > rows) {
				break;
			}
			vec2 above = UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * i);
			if (above.y < 0.0 || texture(TEXTURE, above).a < 0.1) {
				float strength = clamp(depth - (i - 1.0), 0.0, 1.0);
				c.rgb = mix(c.rgb, vec3(0.94, 0.97, 1.0), 0.9 * strength);
				break;
			}
		}
	}
	COLOR = c;
}
