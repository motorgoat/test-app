// Würfelkörper: dunkler, warmer Fels (triplanar im Objektraum). Die Fugen wirken wie Felsspalten.
shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D n_fbm : repeat_enable, filter_linear_mipmap;
uniform vec3 rock_a : source_color = vec3(0.17, 0.15, 0.13);
uniform vec3 rock_b : source_color = vec3(0.36, 0.32, 0.27);
varying vec3 lp;
varying vec3 ln;
void vertex() { lp = VERTEX; ln = NORMAL; }
void fragment() {
	vec3 an = abs(ln);
	vec2 uv = an.x > an.y && an.x > an.z ? lp.yz : (an.y > an.z ? lp.xz : lp.xy);
	float n = texture(n_fbm, uv * 2.2).r;
	float f = texture(n_fbm, uv * 9.0 + 0.3).r;
	ALBEDO = mix(rock_a, rock_b, smoothstep(0.35, 0.75, n)) * (0.8 + 0.4 * f);
	ROUGHNESS = 0.88;
	SPECULAR = 0.25;
}
