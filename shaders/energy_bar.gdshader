shader_type canvas_item;

uniform float bar_width_px = 42.0; // actual texture width in pixels, auto-set by script
uniform float energy_pixels = 0.0; // number of filled pixels, equal to current energy
uniform float pixel_shift = 9.0; // shifts the fill calculation to skip past padding
uniform bool reverse_direction = false; // flip which side fills first

uniform float wave_amplitude = 0.5; // how far the surface wobbles, in pixels
uniform float wave_frequency = 14.0; // how many wave cycles fit vertically
uniform float wave_speed = 2.5; // how fast the wave animates

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	float pixel_x = reverse_direction ? (bar_width_px - (UV.x * bar_width_px)) : (UV.x * bar_width_px);
	pixel_x -= pixel_shift;

	// combine a few sine waves at different frequencies/speeds/phases so the
	// ripple looks organic and irregular instead of a single obvious sine
	float wave = sin(UV.y * wave_frequency + TIME * wave_speed) * 0.5;
	wave += sin(UV.y * wave_frequency * 2.3 + TIME * wave_speed * 1.7 + 1.3) * 0.3;
	wave += sin(UV.y * wave_frequency * 0.6 + TIME * wave_speed * 0.8 + 4.1) * 0.2;
	wave *= wave_amplitude;

	float boundary = energy_pixels + wave;

	if (pixel_x > boundary) {
		discard;
	}

	COLOR = tex_color;
}