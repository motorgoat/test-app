// Hintergrund (Prototyp): weicher Himmel mit Dunst und ziehenden Schleierwolken. Hängt an der Kamera.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D n_fbm : repeat_enable, filter_linear_mipmap;
uniform vec3 top_c : source_color = vec3(0.47, 0.63, 0.78);
uniform vec3 mid_c : source_color = vec3(0.78, 0.84, 0.88);
uniform vec3 low_c : source_color = vec3(0.93, 0.88, 0.80);
uniform vec3 cloud_c : source_color = vec3(1.0, 0.98, 0.95);
void fragment() {
	vec2 uv = UV;
	float y = 1.0 - uv.y;
	vec3 c = mix(low_c, mid_c, smoothstep(0.0, 0.5, y));
	c = mix(c, top_c, smoothstep(0.45, 1.0, y));
	float n = texture(n_fbm, vec2(uv.x * 0.9 + TIME * 0.004, uv.y * 1.7)).r;
	float n2 = texture(n_fbm, vec2(uv.x * 2.3 - TIME * 0.006, uv.y * 3.1 + 0.4)).r;
	float cl = smoothstep(0.55, 0.9, n * 0.7 + n2 * 0.4) * (0.35 + 0.65 * smoothstep(0.2, 0.7, y));
	c = mix(c, cloud_c, cl * 0.35);
	ALBEDO = c;
}
