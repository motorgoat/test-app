// Wasser: Wellen-Normalen aus zwei laufenden Rauschmustern, Fresnel zum Himmel, Funkeln, Uferschaum
// (Objektraum, kein Tiefenpuffer -> läuft in gl_compatibility). edge_mask (N/O/S/W = -z/+x/+z/-x):
// 1 = Ufer mit Schaum, 0 = dort liegt Nachbarwasser (kein Schaum, flach bis zum Rand).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D n_fbm : repeat_enable, filter_linear_mipmap;
uniform vec3 deep : source_color = vec3(0.13, 0.36, 0.42);
uniform vec3 shallow : source_color = vec3(0.34, 0.6, 0.56);
uniform vec3 sky : source_color = vec3(0.78, 0.84, 0.88);
uniform vec3 foam_c : source_color = vec3(0.86, 0.89, 0.87);
uniform float half_size = 0.3;
uniform float wave = 0.55;
uniform vec4 edge_mask = vec4(1.0);
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
	// Abstand zum Ufer: nur Seiten mit Ufer zählen
	vec2 q = uv / half_size;
	float dn_ = edge_mask.x > 0.5 ? -q.y : -1.0;
	float de_ = edge_mask.y > 0.5 ? q.x : -1.0;
	float ds_ = edge_mask.z > 0.5 ? q.y : -1.0;
	float dw_ = edge_mask.w > 0.5 ? -q.x : -1.0;
	float edge = clamp(max(max(dn_, ds_), max(de_, dw_)), 0.0, 1.0);
	vec3 col = mix(deep, shallow, smoothstep(0.25, 1.0, edge));
	col *= 0.92 + 0.16 * h0 * 0.5;
	float fres = pow(1.0 - clamp(dot(nrm_v, VIEW), 0.0, 1.0), 4.0);
	col = mix(col, sky, 0.12 + fres * 0.55);
	// Uferschaum: schmales, aufgebrochenes, leicht pulsierendes Band
	float fn = texture(n_fbm, uv * 9.0 + vec2(t * 0.05, 0.0)).r;
	float band = smoothstep(0.93 + 0.025 * sin(t * 1.3 + fn * 6.0), 1.0, edge + (fn - 0.5) * 0.1);
	col = mix(col, foam_c, band * 0.55);
	// Funkeln: kleine helle Spitzen, die mitlaufen
	float sp = texture(n_fbm, uv * 13.0 + vec2(t * 0.09, -t * 0.07)).r;
	float sparkle = smoothstep(0.8, 0.85, sp) * (1.0 - band);
	ALBEDO = min(col, vec3(1.0));
	ROUGHNESS = mix(0.07, 0.6, band);
	METALLIC = 0.0;
	SPECULAR = 0.6;
	EMISSION = vec3(1.0, 0.95, 0.85) * sparkle * 0.6;
}
