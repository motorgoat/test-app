// Würfelkörper: warmer, mittelheller Boden/Fels (triplanar im Objektraum). Die Fugen lesen sich als warme Erde, nicht als schwarze Schlitze.
shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D n_fbm : repeat_enable, filter_linear_mipmap;
uniform vec3 rock_a : source_color = vec3(0.30, 0.25, 0.20);
uniform vec3 rock_b : source_color = vec3(0.46, 0.39, 0.31);
varying vec3 lp;
varying vec3 ln;
void vertex() { lp = VERTEX; ln = NORMAL; }
void fragment() {
	vec3 an = abs(ln);
	vec2 uv = an.x > an.y && an.x > an.z ? lp.yz : (an.y > an.z ? lp.xz : lp.xy);
	float n = texture(n_fbm, uv * 2.2).r;
	float f = texture(n_fbm, uv * 9.0 + 0.3).r;
	ALBEDO = mix(rock_a, rock_b, smoothstep(0.35, 0.75, n)) * (0.92 + 0.16 * f);
	ROUGHNESS = 0.88;
	SPECULAR = 0.25;
}
