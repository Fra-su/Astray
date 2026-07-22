shader_type canvas_item;

uniform vec2 player_pos = vec2(0.0, 0.0);
uniform float fade_radius = 100.0;
uniform float fade_softness = 50.0;
uniform float min_alpha = 0.4;

void fragment() {
	float dist = distance(VERTEX, player_pos);
	float alpha = smoothstep(fade_radius, fade_radius + fade_softness, dist);
	alpha = min_alpha + alpha * (1.0 - min_alpha);
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= alpha;
}