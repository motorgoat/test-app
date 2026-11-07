// Hintergrund: weicher Himmel mit Dunst, ziehenden Schleierwolken und ein paar weichen Haufenwolken.
// Hängt als Ebene an der Kamera (unshaded, ohne Tiefe). Farben kommen aus der Stimmung (World.set_mood).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform sampler2D n_fbm : repeat_enable, filter_linear_mipmap;
uniform vec3 top_c : source_color = vec3(0.47, 0.57, 0.68);
uniform vec3 mid_c : source_color = vec3(0.78, 0.84, 0.88);
uniform vec3 low_c : source_color = vec3(0.93, 0.88, 0.80);
uniform vec3 cloud_c : source_color = vec3(1.0, 0.98, 0.95);
uniform float clouds = 1.0;
uniform float sun_glow = 0.35;
uniform vec2 sun_uv = vec2(0.22, 0.2);
uniform float flash = 0.0;
void fragment() {
	vec2 uv = UV;
	float y = 1.0 - uv.y;
	vec3 c = mix(low_c, mid_c, smoothstep(0.05, 0.5, y));
	c = mix(c, top_c, smoothstep(0.5, 1.0, y));
	// warmer Lichthof dort, wo die Sonne steht
	float sd = length((uv - sun_uv) * vec2(1.0, 0.6));
	c += low_c * sun_glow * (1.0 - smoothstep(0.0, 0.55, sd)) * 0.5;
	// Schleier und Haufenwolken, ziehen langsam
	float n = texture(n_fbm, vec2(uv.x * 0.9 + TIME * 0.004, uv.y * 1.7)).r;
	float n2 = texture(n_fbm, vec2(uv.x * 2.3 - TIME * 0.006, uv.y * 3.1 + 0.4)).r;
	float cl = smoothstep(0.55, 0.9, n * 0.7 + n2 * 0.4) * (0.35 + 0.65 * smoothstep(0.2, 0.7, y));
	float heap = smoothstep(0.62, 0.78, texture(n_fbm, vec2(uv.x * 0.55 + TIME * 0.003, uv.y * 0.9 + 0.2)).r * 0.8 + n2 * 0.3);
	heap *= smoothstep(0.15, 0.35, y) * (1.0 - smoothstep(0.75, 0.95, y));
	vec3 cc = mix(cloud_c * 0.86, cloud_c, smoothstep(0.3, 0.9, n2));
	c = mix(c, cc, clamp(cl * 0.4 + heap * 0.55, 0.0, 1.0) * clouds);
	c += vec3(0.85, 0.88, 1.0) * flash;
	ALBEDO = c;
}
