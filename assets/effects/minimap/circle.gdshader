shader_type canvas_item;
// The round minimap: nothing drawn outside its circle (Minimap).

uniform vec2 centre = vec2(64.0);
uniform float radius = 67.0;
varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	if (length(local - centre) > radius) {
		discard;
	}
}
