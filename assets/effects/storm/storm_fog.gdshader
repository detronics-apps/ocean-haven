shader_type canvas_item;
// A storm's fog over the screen with a clear patch round the ranger (StormWeather): past
// `radius` (plus a soft, rolling edge) only the storm shows.

uniform vec4 fog_colour : source_color = vec4(0.2, 0.24, 0.3, 0.95);
uniform vec2 centre = vec2(0.0);
uniform vec2 rect_size = vec2(1152.0, 648.0);
uniform float radius = 120.0;
uniform float soft = 60.0;
uniform float strength = 0.0;
uniform float time = 0.0;
uniform float flash = 0.0;

void fragment() {
	vec2 p = UV * rect_size;
	float d = length(p - centre);
	float roll = (sin(p.x * 0.021 + time * 1.7) * sin(p.y * 0.019 - time * 1.3)
		+ 0.5 * sin((p.x + p.y) * 0.013 - time * 2.1)) * 0.33 + 0.5;
	float edge = smoothstep(radius, radius + soft, d + (roll - 0.5) * soft * 0.6);
	vec3 colour = fog_colour.rgb * (0.85 + 0.3 * roll);
	colour = mix(colour, vec3(1.0), flash * 0.6);
	COLOR = vec4(colour, fog_colour.a * edge * strength);
}
