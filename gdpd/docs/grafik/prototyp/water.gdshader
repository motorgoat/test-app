// Wasser (Prototyp): Wellen-Normalen aus zwei laufenden Rauschmustern, Fresnel zum Himmel,
// Funkeln, Uferschaum am Rand (Objektraum, kein Tiefenpuffer nötig -> läuft in gl_compatibility).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D n_fbm : repeat_enable, filter_linear_mipmap;
uniform vec3 deep : source_color = vec3(0.07, 0.22, 0.27);
uniform vec3 shallow : source_color = vec3(0.26, 0.50, 0.44);
uniform vec3 sky : source_color = vec3(0.70, 0.80, 0.88);
uniform vec3 foam_c : source_color = vec3(0.92, 0.94, 0.92);
uniform float half_size = 0.3;
uniform float wave = 0.55;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec2 uv = lp.xz;
	float t = TIME;
	vec2 u1 = uv * 3.0 + vec2(t * 0.035, t * 0.021);
	vec2 u2 = uv * 4.7 - vec2(t * 0.027, -t * 0.031);
	float e = 0.02;
	float h0 = texture(n_fbm, u1).r + texture(n_fbm, u2).r;
	float hx = texture(n_fbm, u1 + vec2(e, 0.0)).r + texture(n_fbm, u2 + vec2(e, 0.0)).r;
	float hz = texture(n_fbm, u1 + vec2(0.0, e)).r + texture(n_fbm, u2 + vec2(0.0, e)).r;
	vec3 dn = vec3(h0 - hx, 0.0, h0 - hz) * (wave / e) * 0.02;
	vec3 nrm_v = normalize(NORMAL + (VIEW_MATRIX * MODEL_MATRIX * vec4(dn, 0.0)).xyz);
	NORMAL = nrm_v;
	float edge = max(abs(lp.x), abs(lp.z)) / half_size;      // 0 Mitte .. 1 Rand
	vec3 col = mix(deep, shallow, smoothstep(0.55, 1.0, edge));
	float fres = pow(1.0 - clamp(dot(nrm_v, VIEW), 0.0, 1.0), 4.0);
	col = mix(col, sky, fres * 0.65);
	// Uferschaum: schmales Band am Rand, mit Rauschen aufgebrochen und leicht pulsierend
	float fn = texture(n_fbm, uv * 9.0 + vec2(t * 0.05, 0.0)).r;
	float band = smoothstep(0.90 + 0.04 * sin(t * 1.3 + fn * 6.0), 1.0, edge + (fn - 0.5) * 0.12);
	col = mix(col, foam_c, band * 0.7);
	// Funkeln: hohe Spitzen im Rauschen
	float sp = texture(n_fbm, uv * 13.0 + vec2(t * 0.09, -t * 0.07)).r;
	float sparkle = smoothstep(0.78, 0.84, sp) * (1.0 - band);
	ALBEDO = col;
	ROUGHNESS = mix(0.06, 0.6, band);
	METALLIC = 0.0;
	SPECULAR = 0.65;
	EMISSION = vec3(1.0, 0.95, 0.85) * sparkle * 0.9;
}
