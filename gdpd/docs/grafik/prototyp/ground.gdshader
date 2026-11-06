// Kachel-Boden (Prototyp): Oberseite je Art (Erde/Gras/Waldboden/Pflaster), Seiten als Erdschichten.
// Objektraum-Koordinaten (die Kachel dreht mit dem Würfel), kein UV nötig.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D n_fbm : repeat_enable, filter_linear_mipmap;
uniform sampler2D n_cell : repeat_enable, filter_linear_mipmap;
uniform vec3 top_a : source_color = vec3(0.42, 0.52, 0.22);
uniform vec3 top_b : source_color = vec3(0.55, 0.60, 0.28);
uniform vec3 accent : source_color = vec3(0.55, 0.52, 0.48);
uniform float accent_amt = 0.0;     // Kiesel / Pflastersteine
uniform float cobble = 0.0;         // 1 = Zellen als Pflaster
uniform float patch_scale = 1.1;
uniform vec3 soil_top : source_color = vec3(0.24, 0.17, 0.11);
uniform vec3 soil_bot : source_color = vec3(0.47, 0.36, 0.25);
uniform float half_h = 0.045;
uniform float cloud_shadow = 0.22;

varying vec3 lp;
varying vec3 ln;
varying vec3 wp;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float cloud(vec3 w) {
	// Wolkenschatten: wandern langsam über alle Seiten (Weltkoordinaten, nicht Kachel)
	vec2 uv = (w.xz + w.yy * 0.6) * 0.09 + vec2(TIME * 0.012, TIME * 0.007);
	float c = texture(n_fbm, uv).r;
	return smoothstep(0.48, 0.68, c);
}

void fragment() {
	vec2 uv = lp.xz;
	float big = texture(n_fbm, uv * patch_scale + 0.13).r;
	float fine = texture(n_fbm, uv * 5.3 + 0.71).r;
	float cell = texture(n_cell, uv * 2.4).r;
	vec3 top = mix(top_a, top_b, smoothstep(0.3, 0.7, big));
	top *= 0.82 + 0.36 * fine;
	// Kiesel: kleine Zellkerne heller/grauer, mit dunklem Rand (Schattenfuge)
	float peb = (1.0 - smoothstep(0.05, 0.16, cell)) * accent_amt;
	top = mix(top, accent * (0.85 + 0.3 * fine), peb);
	// Pflaster: Fugen dunkel
	float joint = smoothstep(0.62, 0.9, cell) * cobble;
	top = mix(top, top * 0.45, joint);
	// Rand der Kachel leicht dunkler (Kontaktschatten zur Fuge)
	float edge = max(abs(lp.x), abs(lp.z));
	top *= mix(1.0, 0.78, smoothstep(0.38, 0.45, edge));

	// Seiten: Grasnarbe oben, dann Erdschichten
	float h = clamp((lp.y + half_h) / (2.0 * half_h), 0.0, 1.0);
	vec2 sv = vec2(lp.x + lp.z, lp.y);
	float strata = texture(n_fbm, vec2(sv.x * 1.5, sv.y * 22.0)).r;
	vec3 side = mix(soil_bot, soil_top, smoothstep(0.1, 0.9, h + (strata - 0.5) * 0.35));
	side *= 0.8 + 0.35 * texture(n_fbm, sv * 9.0).r;
	float sod = smoothstep(0.8, 0.88, h + (fine - 0.5) * 0.08);
	side = mix(side, top_a * 0.8, sod);
	float topness = smoothstep(0.5, 0.85, ln.y);
	vec3 col = mix(side, top, topness);
	col *= 1.0 - cloud_shadow * cloud(wp);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.75, cobble);
	SPECULAR = 0.3;
}
