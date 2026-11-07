// Kachel-Boden (GDPD_GRAFIK.md 3): Oberseite je Art, Seiten als Erdschichten, Wolkenschatten, Nässe, Verwelken, Lichtpuls.
// Objektraum-Koordinaten (die Kachel dreht mit dem Würfel), kein UV nötig. Höchstens 6 Textur-Abtastungen.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D n_fbm : repeat_enable, filter_linear_mipmap;
uniform sampler2D n_cell : repeat_enable, filter_linear_mipmap;
uniform vec3 top_a : source_color = vec3(0.42, 0.52, 0.22);
uniform vec3 top_b : source_color = vec3(0.55, 0.60, 0.28);
uniform vec3 accent : source_color = vec3(0.55, 0.52, 0.48);
uniform float accent_amt = 0.0;      // Kiesel / Streu
uniform float cobble = 0.0;          // 1 = Zellen als Pflaster
uniform float cobble_scale = 2.4;
uniform float furrow = 0.0;          // Acker: Furchen in Streifen
uniform float furrow_dir = 0.0;
uniform vec3 speck_a : source_color = vec3(1.0);
uniform vec3 speck_b : source_color = vec3(1.0);
uniform float speck_amt = 0.0;       // Blumentupfer
uniform float path_amt = 0.0;        // Trampelpfad (Hütte, Haus, Dorf)
uniform vec3 path_c : source_color = vec3(0.54, 0.45, 0.31);
uniform vec3 soil_top : source_color = vec3(0.22, 0.16, 0.11);
uniform vec3 soil_bot : source_color = vec3(0.44, 0.34, 0.24);
uniform float half_h = 0.045;
uniform float half_w = 0.45;
uniform float cloud_shadow = 0.2;
uniform float scorch = 0.0;          // 0..1 verwelkt / verbrannt
uniform float polluted = 0.0;        // 0..1 Smog
uniform float wet = 0.0;             // 0..1 Regen
uniform float pulse = 0.0;           // 0..1 Lichtpuls beim Verschmelzen
uniform vec3 pulse_c : source_color = vec3(1.0, 0.82, 0.45);

varying vec3 lp;
varying vec3 ln;
varying vec3 wp;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = lp.xz;
	float big = texture(n_fbm, uv * 1.1 + 0.13).r;
	float fine = texture(n_fbm, uv * 5.3 + 0.71).r;
	float cl = texture(n_cell, uv * cobble_scale).r;
	float sp = texture(n_cell, uv * 7.5 + vec2(0.37, 0.11)).r;

	vec3 top = mix(top_a, top_b, smoothstep(0.32, 0.68, big));
	top *= 0.84 + 0.32 * fine;
	// Acker: Furchen (dunkle Rinne, heller Damm)
	float fu = (furrow_dir > 0.5 ? uv.x : uv.y) * 52.4;
	float ridge = 0.5 + 0.5 * sin(fu);
	top = mix(top, top * mix(0.62, 1.22, ridge), furrow);
	// Trampelpfad: geschwungen, weicher Rand
	float pd = abs(uv.y - 0.06 - 0.07 * sin(uv.x * 7.0 + 1.3)) + (fine - 0.5) * 0.05;
	float path = (1.0 - smoothstep(0.035, 0.065, pd)) * path_amt;
	top = mix(top, path_c * (0.86 + 0.28 * fine), path);
	// Kiesel / Streu: kleine Zellkerne mit dunklem Rand
	float peb = (1.0 - smoothstep(0.05, 0.15, cl)) * accent_amt * (1.0 - cobble);
	top = mix(top * (1.0 - 0.18 * smoothstep(0.15, 0.22, cl) * (1.0 - smoothstep(0.22, 0.3, cl)) * accent_amt), accent * (0.85 + 0.3 * fine), peb);
	// Pflaster: Steine mit dunklen Fugen und etwas Farbstreuung je Stein
	float joint = smoothstep(0.6, 0.88, cl) * cobble;
	top = mix(top, top * (0.92 + 0.16 * big), cobble);
	top = mix(top, top * 0.5, joint);
	// Blumentupfer (Wiese, Garten, Paradies)
	float spk = (1.0 - smoothstep(0.03, 0.07, sp)) * speck_amt * (1.0 - path);
	top = mix(top, mix(speck_a, speck_b, step(0.5, fine)), spk * 0.85);
	// Kontaktschatten zur Fuge
	float edge = max(abs(lp.x), abs(lp.z)) / half_w;
	top *= mix(1.0, 0.72, smoothstep(0.86, 1.0, edge));

	// Seiten: Grasnarbe oben, darunter Erdschichten
	float h = clamp((lp.y + half_h) / (2.0 * half_h), 0.0, 1.0);
	vec2 sv = vec2(lp.x + lp.z, lp.y);
	float strata = texture(n_fbm, vec2(sv.x * 1.5, sv.y * 22.0)).r;
	vec3 side = mix(soil_bot, soil_top, smoothstep(0.1, 0.9, h + (strata - 0.5) * 0.35));
	side *= 0.82 + 0.3 * fine;
	float sod = smoothstep(0.78, 0.86, h + (fine - 0.5) * 0.08);
	side = mix(side, top_a * 0.82, sod);
	float topness = smoothstep(0.5, 0.85, ln.y);
	vec3 col = mix(side, top, topness);

	// Verwelkt / verbrannt: braun-grau, matter
	float lum = dot(col, vec3(0.3, 0.55, 0.15));
	col = mix(col, vec3(lum) * vec3(1.08, 0.96, 0.78), scorch * 0.75);
	// Smog: grau
	col = mix(col, vec3(0.38, 0.37, 0.35) * (0.8 + 0.4 * fine), polluted * 0.5);
	// Nässe: dunkler und glänzender
	col *= mix(1.0, 0.62, wet);
	// Wolkenschatten: wandern in Weltkoordinaten über alle Seiten (drehen nicht mit)
	vec2 cuv = (wp.xz + wp.yy * 0.6) * 0.09 + vec2(TIME * 0.012, TIME * 0.007);
	float cloud = smoothstep(0.48, 0.68, texture(n_fbm, cuv).r);
	col *= 1.0 - cloud_shadow * cloud;

	ALBEDO = col;
	ROUGHNESS = mix(mix(0.95, 0.78, cobble), 0.32, wet);
	SPECULAR = mix(0.3, 0.55, wet);
	EMISSION = pulse_c * pulse * (0.35 + 0.65 * smoothstep(0.55, 1.0, edge)) * 0.9;
}
