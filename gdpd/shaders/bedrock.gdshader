// Würfelkörper: dunkler, warmer Fels (triplanar im Objektraum). Außen decken ihn die Felder ganz zu; man sieht ihn nur
// beim Drehen im Inneren des Würfels – dort soll er ruhig und dunkel wirken wie eine Felsspalte.
shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D n_fbm : repeat_enable, filter_linear_mipmap;
uniform vec3 rock_a : source_color = vec3(0.13, 0.11, 0.09);
uniform vec3 rock_b : source_color = vec3(0.25, 0.21, 0.17);
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
