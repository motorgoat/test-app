// Kachel-Boden (GDPD_GRAFIK.md 3), nahtlos: Oberseite je Art, Seiten als Erdschichten, Wolkenschatten, Nässe, Verwelken,
// Lichtpuls, Markierungen. Dazu (Nahtlos-Regel): Jede Kachel kennt ihre 8 Nachbarn (auch über die Würfelkante) und geht
// am Rand weich und unregelmäßig in deren Boden über. Rauschen: innen kachel-eigen (mit eigenem Versatz je Feld), am
// Rand in Würfel-Koordinaten (cb_*, triplanar): an jeder Fuge und jeder Würfelkante rechnen beide Seiten mit genau
// demselben Wert – ohne Spiegelung. Muster (Pflaster, Kiesel, Blumen) liegen ganz in Würfel-Koordinaten und laufen
// über Felder gleicher Art durch. Wasser ist ein Abstandsfeld über den Nachbarn (Kerne, Brücken, Füllungen,
// Meerengen über Eck): benachbarte Wasserfelder sind ein See mit runden Außen- und Innenecken; Ufer nur zum Land.
// UV = flache Lage auf der Kachel (−0,5 … 0,5; an Würfelkanten bis 0,56), UV2.x = 1 Oberseite, 0 Fugen-Wand.
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
uniform float half_h = 0.06;
uniform float cloud_shadow = 0.2;
uniform float scorch = 0.0;          // 0..1 verwelkt / verbrannt
uniform float polluted = 0.0;        // 0..1 Smog
uniform float wet = 0.0;             // 0..1 Regen
uniform float pulse = 0.0;           // 0..1 Lichtpuls beim Verschmelzen
uniform vec3 pulse_c : source_color = vec3(1.0, 0.82, 0.45);
// Zustände der Nachbarn (gleich gewichtet wie die Farben): x verwelkt, y Smog, z Nässe, w Markierung (Nummer)
// Markierung (Hinweis, Gefahr, Ziel …) als Lichtrand im Boden: rgb Farbe, a Stärke; Puls je Art; Nummer, damit
// zwei gleich markierte Nachbarn an ihrer Fuge keinen Rand zeigen (eine Reihe leuchtet als Ganzes)
uniform vec4 mark_c = vec4(0.0);
uniform float mark_speed = 0.0;
uniform float mark_id = 0.0;
uniform vec4 nb_fx[8];
// Nahtlos: eigener Mischwert (wer sich am Rand „durchsetzt“) und die 8 Nachbarn
// Reihenfolge: 0 N (−z), 1 O (+x), 2 S (+z), 3 W (−x), 4 NO, 5 SO, 6 SW, 7 NW.
// nb_a: rgb = Bodenton a (linear), a = Mischwert. nb_b: rgb = Bodenton b (linear), a = 1 Wasser.
uniform float mix_c = 0.5;
uniform vec4 nb_a[8];
uniform vec4 nb_b[8];
uniform float nb_on = 0.0;           // 0: Nachbarn unbekannt (Test, Vorschau) – dann zu sich selbst mischen
uniform vec4 cell_ext = vec4(0.502); // Ausdehnung (flach) je Seite N, O, S, W: Fuge 0,502, Würfelkante 0,56
uniform float blend_w = 0.26;        // Breite des Übergangs je Seite
// Wasser
uniform float is_water = 0.0;
// Schöpfung (GDPD_SCHOEPFUNG_GRAFIK.md): Lava (Kruste mit glühenden Rissen, fließt über Fugen weiter) und Leben im
// Wasser (Zustand der Wasserfläche, an Fugen weich gemischt wie Nässe und Smog)
uniform float lava = 0.0;            // 1: dieses Feld ist Lava
uniform vec3 lava_hot : source_color = vec3(1.0, 0.3, 0.04);
uniform vec3 lava_core : source_color = vec3(1.0, 0.6, 0.16);
uniform float lava_e = 1.25;         // Leuchtkraft (über 1: Glühen)
uniform float lava_flow = 1.0;       // 0: kein Fluss (Qualität niedrig)
uniform float lava_warn = 0.0;       // Vulkan grollt: Gruppe glüht heller, Risse pulsieren im Gleichtakt
uniform float w_life = 0.0;          // 0 tot, 0,1 Ursuppe, 0,35 Einzeller, 1 Algen, 1,5 Fische
uniform float nb_life[8];            // Leben der Nachbarn (−1: kein Wasser, zählt wie dieses Feld)
uniform float w_glint = 1.0;         // Glitzern des Zeitalters (Glut: halb)
uniform float life_dots = 1.0;       // Einzeller-Pünktchen (Qualität niedrig: aus)
uniform float moss = 0.0;            // Moos: samtige Polster
uniform float cracks = 0.0;          // Urboden: feine Trockenrisse
// Jahreszeit (Look.set_season) und Sonnenseite (Akt 4: day 1 oben, 0 Seiten, −1 unten)
uniform float spring = 0.0;
uniform float autumn = 0.0;
uniform float winter = 0.0;
uniform float sunface = 0.0;
uniform float day = 1.0;
uniform float shore = 0.355;         // so weit reicht das Wasser zum Land hin (Zellen-Koordinaten)
uniform vec3 w_deep : source_color = vec3(0.07, 0.25, 0.30);
uniform vec3 w_shallow : source_color = vec3(0.24, 0.50, 0.47);
uniform vec3 w_sky : source_color = vec3(0.78, 0.84, 0.88);
uniform vec3 w_foam : source_color = vec3(0.88, 0.9, 0.88);
uniform vec4 w_box[25];              // Wasser-Rechtecke (Look.water_boxes): Mitte xy, halbe Größe zw; [0] = eigener Kern
uniform int w_box_n = 0;
uniform vec4 w_m = vec4(1.0, 0.0, 0.0, 1.0);   // Wellen in Koordinaten der Würfelseite (alle Wasserfelder einer Seite
uniform vec2 w_o = vec2(0.0);                  // teilen dasselbe Wellenmuster): fc = (dot(w_m.xy, uv), dot(w_m.zw, uv)) + w_o
// Mitdrehen (Prototyp): beim Seitenwechsel einer Kachel blendet ihr altes Wellenmuster in 0,45 s ins neue über
uniform vec4 w_m_old = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec2 w_o_old = vec2(0.0);
uniform float w_fade = 0.0;
uniform vec4 w_seg[4];               // Meerengen: Strecke Mitte zu Mitte (Look.water_segs)
uniform int w_seg_n = 0;
uniform vec3 sun_v = vec3(0.45, 0.6, 0.66);    // Richtung zur Sonne (Kamera-Raum, World)
// Würfel-Koordinaten der Kachel (World._update_seams): p_würfel = cb_x * x + cb_y * y + cb_z * z + cb_o
uniform vec3 cb_x = vec3(1.0, 0.0, 0.0);
uniform vec3 cb_y = vec3(0.0, 1.0, 0.0);
uniform vec3 cb_z = vec3(0.0, 0.0, 1.0);
uniform vec3 cb_o = vec3(0.0);
uniform float tile_seed = 0.0;       // Versatz des Innen-Rauschens je Feld (keine zwei Felder gleich)

varying vec3 lp;
varying vec3 wp;
varying vec3 cp;
varying vec3 cn;

void vertex() {
	lp = VERTEX;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	cp = cb_x * VERTEX.x + cb_y * VERTEX.y + cb_z * VERTEX.z + cb_o;
	cn = cb_x * NORMAL.x + cb_y * NORMAL.y + cb_z * NORMAL.z;
}

float sd_box(vec2 p, vec2 c, vec2 h) {
	vec2 d = abs(p - c) - h;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float smin(float a, float b, float k) {
	float h = max(k - abs(a - b), 0.0) / k;
	return min(a, b) - h * h * k * 0.25;
}

float sd_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// Triplanar in Würfel-Koordinaten: auf der flachen Seite eine Abtastung, an der gebogenen Würfelkante zwei (beide
// Seiten sehen an der Gehrung denselben Punkt mit derselben Normalen). Kontrast bleibt beim Mischen erhalten.
float tri_fbm(vec3 p, vec3 w, float sc, vec2 off, vec3 dx, vec3 dy) {
	float r = 0.0;
	float q = 0.0;
	if (w.x > 0.002) {
		r += w.x * textureGrad(n_fbm, p.zy * sc + off, dx.zy * sc, dy.zy * sc).r;
		q += w.x * w.x;
	}
	if (w.y > 0.002) {
		r += w.y * textureGrad(n_fbm, p.xz * sc + off, dx.xz * sc, dy.xz * sc).r;
		q += w.y * w.y;
	}
	if (w.z > 0.002) {
		r += w.z * textureGrad(n_fbm, p.xy * sc + off, dx.xy * sc, dy.xy * sc).r;
		q += w.z * w.z;
	}
	return 0.5 + (r - 0.5) * inversesqrt(max(q, 0.0001));
}

float tri_cell(vec3 p, vec3 w, float sc, vec2 off, vec3 dx, vec3 dy) {
	float r = 0.0;
	if (w.x > 0.002) {
		r += w.x * textureGrad(n_cell, p.zy * sc + off, dx.zy * sc, dy.zy * sc).r;
	}
	if (w.y > 0.002) {
		r += w.y * textureGrad(n_cell, p.xz * sc + off, dx.xz * sc, dy.xz * sc).r;
	}
	if (w.z > 0.002) {
		r += w.z * textureGrad(n_cell, p.xy * sc + off, dx.xy * sc, dy.xy * sc).r;
	}
	return r;
}

// zwei unabhängige Rauschwerte mischen, ohne dass der Übergang flau wird
float nmix(float a, float b, float t) {
	return 0.5 + (mix(a, b, t) - 0.5) * inversesqrt(t * t + (1.0 - t) * (1.0 - t));
}

// Wellenhöhe (Wasser) in Koordinaten der Würfelseite: über Fugen hinweg ein Muster
float wave_h(vec2 fc, float t) {
	return texture(n_fbm, fc * 3.6 + vec2(t * 0.035, t * 0.021)).r;
}

vec3 approx(vec3 a, vec3 b, float big, float fine) {
	return mix(a, b, smoothstep(0.32, 0.68, big)) * (0.84 + 0.32 * fine);
}

void fragment() {
	vec2 uv = UV;
	float topness = UV2.x;
	// Zellen-Koordinaten: Fuge und Würfelkante liegen beide bei ±0,5
	vec2 ue;
	ue.x = uv.x >= 0.0 ? uv.x / cell_ext.y : uv.x / cell_ext.w;
	ue.y = uv.y >= 0.0 ? uv.y / cell_ext.z : uv.y / cell_ext.x;
	ue = clamp(ue * 0.5, vec2(-0.5), vec2(0.5));
	float m = max(abs(ue.x), abs(ue.y));
	// Randband: dort Rauschen in Würfel-Koordinaten (an der Fuge auf beiden Seiten gleich), innen kachel-eigen
	float wf = smoothstep(0.34, 0.47, m);

	vec2 gx = dFdx(uv);
	vec2 gy = dFdy(uv);
	vec3 dpx = dFdx(cp);
	vec3 dpy = dFdy(cp);
	vec3 tw = pow(abs(normalize(cn)), vec3(6.0));
	tw /= tw.x + tw.y + tw.z;
	vec2 so = vec2(fract(tile_seed * 0.6180339), fract(tile_seed * 0.7548777)) * 13.0;
	float big = textureGrad(n_fbm, uv * 1.1 + vec2(0.13) + so, gx * 1.1, gy * 1.1).r;
	float fine = textureGrad(n_fbm, uv * 5.3 + vec2(0.71) + so, gx * 5.3, gy * 5.3).r;
	if (wf > 0.0) {
		big = nmix(big, tri_fbm(cp, tw, 1.1, vec2(0.13), dpx, dpy), wf);
		fine = nmix(fine, tri_fbm(cp, tw, 5.3, vec2(0.71), dpx, dpy), wf);
	}
	// Zellrauschen (Würfel-Koordinaten) nur, wo diese Art Kiesel, Pflaster oder Blumen hat
	float cl = 0.5;
	float sp = 0.5;
	if (accent_amt + cobble > 0.0) {
		cl = tri_cell(cp, tw, cobble_scale, vec2(0.0), dpx, dpy);
	}
	if (speck_amt > 0.0) {
		sp = tri_cell(cp, tw, 7.5, vec2(0.37, 0.11), dpx, dpy);
	}

	cl += (fine - 0.5) * 0.1;      // Kiesel unregelmäßig statt runder Stempel
	vec3 base = approx(top_a, top_b, big, fine);
	vec3 top = base;
	// Acker: Furchen (dunkle Rinne, heller Damm); 8 je Feld und gerade (cos): gleich gerichtete Nachbarn laufen durch
	float fu = (furrow_dir > 0.5 ? uv.x : uv.y) * 50.265;
	float ridge = 0.5 + 0.5 * cos(fu);
	top = mix(top, top * mix(0.62, 1.22, ridge), furrow);
	// Trampelpfad: geschwungen, weicher Rand, endet vor dem Feldrand
	float pd = abs(uv.y - 0.06 - 0.07 * sin(uv.x * 7.0 + 1.3)) + (fine - 0.5) * 0.05;
	float path = (1.0 - smoothstep(0.035, 0.065, pd)) * path_amt * (1.0 - smoothstep(0.36, 0.47, m + (fine - 0.5) * 0.06));
	top = mix(top, path_c * (0.86 + 0.28 * fine), path);
	// Kiesel / Streu: kleine Zellkerne mit dunklem Rand
	float peb = (1.0 - smoothstep(0.05, 0.15, cl)) * accent_amt * (1.0 - cobble);
	top = mix(top * (1.0 - 0.1 * smoothstep(0.15, 0.22, cl) * (1.0 - smoothstep(0.22, 0.3, cl)) * accent_amt), accent * (0.85 + 0.3 * fine), peb);
	// Pflaster: Steine mit dunklen Fugen und etwas Farbstreuung je Stein
	float joint = smoothstep(0.6, 0.88, cl) * cobble;
	top = mix(top, top * (0.92 + 0.16 * big), cobble);
	top = mix(top, top * 0.5, joint);
	// Blumentupfer (Wiese, Garten, Paradies)
	float spk = (1.0 - smoothstep(0.03, 0.07, sp)) * speck_amt * (1.0 - path);
	top = mix(top, mix(speck_a, speck_b, step(0.5, fine)), spk * 0.85 * (1.0 + spring * 0.5));
	// Urboden: feine Trockenrisse (Zellränder in Würfel-Koordinaten, laufen über Fugen weiter)
	if (cracks > 0.0) {
		float ck = tri_cell(cp, tw, 3.4, vec2(0.52, 0.17), dpx, dpy) + (fine - 0.5) * 0.08;
		top = mix(top, top * 0.55, smoothstep(0.74, 0.8, ck) * (1.0 - smoothstep(0.86, 0.95, ck)) * cracks * 0.8);
	}
	// Moos: runde, dichte Polster (hell oben, dunkle Fugen dazwischen), keine Blumen
	if (moss > 0.0) {
		float cu = tri_cell(cp, tw, 4.2, vec2(0.33, 0.71), dpx, dpy);
		top = mix(top, top * mix(1.18, 0.62, smoothstep(0.25, 0.75, cu)), moss);
	}
	// Jahreszeit: Frühling frischer, Herbst gelblicher (nur Grün), Winter siehe unten
	float greenish = smoothstep(0.0, 0.08, top.g - max(top.r, top.b) * 0.9);
	top = mix(top, top * vec3(0.92, 1.08, 0.88), spring * greenish * 0.6);
	top = mix(top, vec3(dot(top, vec3(0.5, 0.45, 0.05))) * vec3(1.25, 1.02, 0.55), autumn * greenish * 0.55);

	// Wasser: Abstandsfeld über die Nachbarn (Kerne, Brücken, Füllungen, Meerengen) mit runden Ecken
	bool has_w = is_water > 0.5 || w_seg_n > 0;
	float wd = 1.0;
	vec3 wn = vec3(0.0);
	if (has_w) {
		float s = shore - 0.1;
		float d = is_water > 0.5 ? sd_box(ue, vec2(0.0), vec2(s)) : 10.0;
		for (int i = 1; i < w_box_n; i++) {
			d = smin(d, sd_box(ue, w_box[i].xy, w_box[i].zw), 0.14);
		}
		for (int i = 0; i < w_seg_n; i++) {
			d = smin(d, sd_seg(ue, w_seg[i].xy, w_seg[i].zw) + 0.01, 0.14);
		}
		// Ufer leicht unregelmäßig (Rauschen ist an der Fuge auf beiden Seiten gleich)
		wd = d - 0.1 + (big - 0.5) * 0.05 + (fine - 0.5) * 0.02;
	}

	// Übergang zu den Nachbarn: weiche Gewichte (an der Fuge je 1/2, an der Ecke je 1/4), unregelmäßig durch
	// Höhen-Mischen (beide Seiten rechnen an der Fuge mit demselben Rauschen). Gleiche Art zählt als „selbst“.
	vec3 col_top = top;
	float lav = lava;
	float wl = w_life;
	vec3 fx = vec3(scorch, polluted, wet);
	if (nb_on > 0.5) {
		// unregelmäßiger Innenrand: verschoben um Rauschen, an der Fuge selbst unverschoben (dort je 1/2)
		vec2 uw = ue;
		uw.x += (big - 0.5) * 0.8 * (0.5 - abs(ue.x));
		uw.y += (big - 0.5) * 0.8 * (0.5 - abs(ue.y));
		float wxp = 0.5 * smoothstep(0.5 - blend_w, 0.5, uw.x);
		float wxn = 0.5 * smoothstep(0.5 - blend_w, 0.5, -uw.x);
		float wzp = 0.5 * smoothstep(0.5 - blend_w, 0.5, uw.y);
		float wzn = 0.5 * smoothstep(0.5 - blend_w, 0.5, -uw.y);
		float wx0 = 1.0 - wxp - wxn;
		float wz0 = 1.0 - wzp - wzn;
		// Höhen-Mischen: Gewicht plus Rauschen je Art (Vorzeichen je Art verschieden) – die Grenze schlängelt sich
		// um die Fuge. Beide Seiten rechnen an der Fuge mit denselben Werten.
		float hn = (big * 0.65 + fine * 0.35 - 0.5) * 1.3;
		float depth = 0.09;
		float ws0 = wx0 * wz0;
		float wgt[8] = float[8](wx0 * wzn, wxp * wz0, wx0 * wzp, wxn * wz0, wxp * wzn, wxp * wzp, wxn * wzp, wxn * wzn);
		float sc[8];
		float s_self = ws0 + hn * (2.0 * mix_c - 1.0) * clamp(ws0 * 4.0, 0.0, 1.0);
		float mx = s_self;
		for (int i = 0; i < 8; i++) {
			sc[i] = wgt[i] + hn * (2.0 * nb_a[i].a - 1.0) * clamp(wgt[i] * 4.0, 0.0, 1.0);
			mx = max(mx, sc[i]);
		}
		float bs = max(s_self - mx + depth, 0.0);
		float bself = bs;
		vec3 acc = vec3(0.0);
		vec3 fxa = fx * bs;
		float lva = 0.0;
		float sum = bs;
		// Leben im Wasser: weich (lineare Gewichte über die ganze Übergangsbreite), nicht als scharfe Höhen-Grenze
		float wla = w_life * ws0;
		for (int i = 0; i < 8; i++) {
			float bi = max(sc[i] - mx + depth, 0.0);
			if (bi > 0.0) {
				if (nb_b[i].a > 1.5 && nb_b[i].a < 2.5) {
					bself += bi;
				} else {
					acc += approx(nb_a[i].rgb, nb_b[i].rgb, big, fine) * bi;
				}
				fxa += nb_fx[i].xyz * bi;
				if (nb_b[i].a > 2.5) { lva += bi; }
				sum += bi;
			}
		}
		// eigene Muster (Furchen, Kiesel, Blumen) nur, wo diese Art klar überwiegt (Nachbarn gleicher Art zählen
		// mit): an der Fuge zu einer anderen Art zeigen beide Seiten nur Grundtöne, zu gleicher Art laufen sie durch
		float share = bself / sum;
		vec3 own = mix(base, top, smoothstep(0.55, 0.98, share));
		col_top = (acc + own * bself) / sum;
		fx = fxa / sum;
		lav = (lava * bself + lva) / sum;
		for (int i = 0; i < 8; i++) {
			wla += (nb_life[i] < -0.5 ? w_life : nb_life[i]) * wgt[i];
		}
		// jedes Feld behält sein eigenes Leben; nur im letzten Stück zur Fuge mischt es (an der Fuge beide gleich)
		float life_edge = smoothstep(0.35, 0.5, max(abs(ue.x), abs(ue.y)));
		wl = mix(w_life, wla, life_edge);
	}

	vec3 lava_emi = vec3(0.0);
	if (lav > 0.002) {
		// Kruste in Platten (Zellen in Würfel-Koordinaten: laufen über Fugen weiter), Risse glühen, in der Mitte
		// großer Lava-Flächen fließt flüssiges Gestein (Rauschen wandert langsam)
		float lc = tri_cell(cp, tw, 0.55, vec2(0.21, 0.6), dpx, dpy);
		float lt = TIME * lava_flow;
		float flow = tri_fbm(cp, tw, 0.9, vec2(lt * 0.006, lt * 0.004), dpx, dpy);
		// Regel für Glut: Kern gelb, Rand rot, Fläche dunkel – schmale Risse, Becken nur in der Mitte großer Flächen
		float cx = lc + (flow - 0.5) * 0.22 + (fine - 0.5) * 0.1;
		// Risse als Adern (gefaltetes Rauschen: schmale Linien) zwischen den Krustenplatten
		float vein = 1.0 - abs(tri_fbm(cp, tw, 1.7, vec2(0.37, 0.91), dpx, dpy) * 2.0 - 1.0);
		float crack = max(smoothstep(0.89, 0.96, vein + (fine - 0.5) * 0.08) * (0.6 + 0.4 * smoothstep(0.55, 0.8, cx)),
			smoothstep(0.8, 0.86, cx) * 0.7);
		float pool = smoothstep(0.67, 0.78, flow) * smoothstep(0.9, 1.0, lav);
		float heat = clamp(crack * smoothstep(0.25, 0.85, lav) + pool, 0.0, 1.0);
		float flick = 0.85 + 0.15 * sin(lt * 1.7 + flow * 12.0);
		// Vulkan grollt: heller (+40 %), gemeinsamer Puls (alle Felder der Gruppe im selben Takt)
		flick *= 1.0 + lava_warn * (0.25 + 0.3 * (0.5 + 0.5 * sin(TIME * 3.4)));
		heat = clamp(heat + lava_warn * crack * 0.35, 0.0, 1.0);
		vec3 hot = mix(lava_hot, lava_core, clamp(pool * smoothstep(0.7, 0.82, flow) + crack * smoothstep(0.86, 0.95, cx) * 0.6, 0.0, 1.0));
		// Albedo: verkohlte Kruste, Risse dunkelrot (Licht kommt aus der Emission)
		col_top = mix(col_top, vec3(0.13, 0.1, 0.09) * (0.8 + 0.4 * fine), smoothstep(0.2, 0.7, lav) * 0.7);
		col_top = mix(col_top, vec3(0.35, 0.08, 0.02), heat * 0.8);
		lava_emi = hot * heat * lava_e * flick;
	}

	if (has_w) {
		// Ufer: nasser Sand, dunkle Kante, flaches Wasser mit Grund, tiefes Wasser
		float t = TIME;
		float e = 0.015;
		vec2 fc = vec2(dot(w_m.xy, uv), dot(w_m.zw, uv)) + w_o;
		float h0 = wave_h(fc, t);
		float hx = wave_h(fc + vec2(w_m.x, w_m.z) * e, t);
		float hz = wave_h(fc + vec2(w_m.y, w_m.w) * e, t);
		// zweite, quer laufende Welle nur für die Farbe (kein eigenes Gefälle: spart Abtastungen)
		float h1 = texture(n_fbm, fc * 5.3 + vec2(-t * 0.027, t * 0.031)).r;
		if (w_fade > 0.001) {
			vec2 fo = vec2(dot(w_m_old.xy, uv), dot(w_m_old.zw, uv)) + w_o_old;
			h0 = mix(h0, wave_h(fo, t), w_fade);
			hx = mix(hx, wave_h(fo + vec2(w_m_old.x, w_m_old.z) * e, t), w_fade);
			hz = mix(hz, wave_h(fo + vec2(w_m_old.y, w_m_old.w) * e, t), w_fade);
			h1 = mix(h1, texture(n_fbm, fo * 5.3 + vec2(-t * 0.027, t * 0.031)).r, w_fade);
			fc = mix(fc, fo, step(0.5, w_fade));
		}
		float inw = 1.0 - smoothstep(-0.006, 0.006, wd);
		vec3 dn = vec3(h0 - hx, 0.0, h0 - hz) * (0.55 / e) * 0.04 * inw;
		wn = dn;
		float depth = clamp(-wd / 0.24, 0.0, 1.0);
		// Farbe: Zeitalter (totes Wasser) gemischt mit der Farbe des Lebens darin (an Fugen weich, wl)
		vec3 ld = mix(vec3(0.16, 0.18, 0.13), vec3(0.11, 0.21, 0.19), smoothstep(0.12, 0.35, wl));      // Ursuppe / Einzeller
		vec3 ls = mix(vec3(0.36, 0.37, 0.27), vec3(0.28, 0.42, 0.37), smoothstep(0.12, 0.35, wl));
		ld = mix(ld, vec3(0.08, 0.20, 0.15), smoothstep(0.4, 1.0, wl));                              // Algen: tief olivgrün
		ls = mix(ls, vec3(0.28, 0.45, 0.30), smoothstep(0.4, 1.0, wl));
		ld = mix(ld, vec3(0.05, 0.25, 0.28), smoothstep(1.05, 1.45, wl));                            // Fische: klares Blaugrün
		ls = mix(ls, vec3(0.20, 0.53, 0.50), smoothstep(1.05, 1.45, wl));
		float lw = smoothstep(0.02, 0.09, wl);
		vec3 wc = mix(mix(w_shallow, ls, lw), mix(w_deep, ld, lw), smoothstep(0.0, 1.0, depth));
		// Grund schimmert im ganz flachen Wasser durch
		wc = mix(wc, col_top * vec3(0.62, 0.78, 0.74), (1.0 - smoothstep(0.0, 0.07, -wd)) * 0.55);
		wc *= 0.92 + 0.08 * h0 + 0.08 * h1;
		// Uferschaum: schmal, aufgebrochen, leicht pulsierend
		float fn = texture(n_fbm, fc * 9.0 + vec2(t * 0.05, 0.0)).r;
		float band = (1.0 - smoothstep(0.0, 0.022 + 0.012 * sin(t * 1.3 + fn * 6.0), -wd)) * smoothstep(0.38, 0.6, fn + 0.12);
		wc = mix(wc, w_foam, band * inw * 0.6);
		// Leben (Schöpfung): Ursuppe trüb mit Schaum-Schlieren, Einzeller als feine, langsam treibende, leise leuchtende
		// Pünktchen, Algen als grüne Matten im Flachen (Uferring), Fische als Ringe an der Oberfläche. Tot: nichts.
		float soup = smoothstep(0.03, 0.1, wl) * (1.0 - smoothstep(0.5, 1.0, wl));
		if (soup > 0.0) {
			float sl = texture(n_fbm, fc * vec2(2.2, 7.0) + vec2(t * 0.004, h1 * 0.3)).r;
			wc = mix(wc, vec3(0.52, 0.5, 0.4), smoothstep(0.6, 0.72, sl) * soup * 0.4 * inw);
		}
		float cells = smoothstep(0.2, 0.33, wl) * (1.0 - smoothstep(0.9, 1.2, wl) * 0.7) * life_dots;
		if (cells > 0.0) {
			// das ganze Feld wird trüb-türkis (lebendig), darauf große, hell leuchtende Zellen
			wc = mix(wc, vec3(0.26, 0.55, 0.44), cells * 0.45 * inw);
			float dots = 1.0 - smoothstep(0.05, 0.14, texture(n_cell, fc * 3.5 + vec2(t * 0.006, -t * 0.004)).r);
			wc = mix(wc, vec3(0.62, 0.9, 0.66), dots * cells * 0.85 * inw);
			lava_emi += vec3(0.2, 0.62, 0.45) * dots * cells * 0.4 * inw * (0.65 + 0.35 * sin(t * 0.7 + h1 * 9.0));
		}
		float alg = smoothstep(0.6, 1.0, wl) * (1.0 - smoothstep(1.2, 1.5, wl) * 0.55);
		// Algen-Matten über das ganze Feld (im Flachen dichter), nicht nur im Uferring
		alg *= mix(0.75, 1.0, 1.0 - smoothstep(0.02, 0.2, -wd)) * smoothstep(0.3, 0.55, big + (h1 - 0.5) * 0.3 + (fine - 0.5) * 0.2);
		wc = mix(wc, vec3(0.27, 0.38, 0.14) * (0.85 + 0.3 * fine), alg * 0.85);
		float fishv = smoothstep(1.1, 1.45, wl);
		if (fishv > 0.0) {
			// Ringe: wo ein Fisch die Oberfläche berührt (Zellen in Wellen-Koordinaten, wandern mit dem Wasser)
			vec2 rc = fc * 2.6;
			vec2 ri = floor(rc);
			float rr = fract(sin(dot(ri, vec2(41.3, 17.9))) * 9137.5);
			float age = fract(t * 0.23 + rr);
			float rd = length(fract(rc) - 0.5 - (vec2(rr, fract(rr * 7.1)) - 0.5) * 0.4);
			float ring = (1.0 - smoothstep(0.0, 0.025, abs(rd - age * 0.35))) * (1.0 - age) * step(0.45, rr);
			wc = mix(wc, w_foam, ring * fishv * 0.6 * inw * smoothstep(0.0, 0.04, -wd));   // auch im tiefen Wasser
		}
		// Lava am Ufer: Wasser spiegelt die Glut, kocht am Rand
		lava_emi += lava_hot * smoothstep(0.0, 0.25, lav) * inw * (1.0 - smoothstep(0.0, 0.2, -wd)) * 0.8;
		// nasser Sand und Uferkante
		vec3 land = col_top * mix(0.72, 1.0, smoothstep(0.0, 0.06, wd));
		land *= 1.0 - 0.25 * (1.0 - smoothstep(0.0, 0.012, wd));
		col_top = mix(land, wc, inw);
	}

	// Seiten: Grasnarbe oben, darunter Erdschichten
	float h = clamp((lp.y + 0.03) / 0.12, 0.0, 1.0);
	vec2 sv = vec2(lp.x + lp.z, lp.y);
	vec3 side = col_top;
	if (topness < 0.999) {
		float strata = texture(n_fbm, vec2(sv.x * 1.5, sv.y * 22.0)).r;
		side = mix(soil_bot, soil_top, smoothstep(0.1, 0.9, h + (strata - 0.5) * 0.35));
		side *= 0.82 + 0.3 * fine;
		float sod = smoothstep(0.8, 0.9, h + (fine - 0.5) * 0.08);
		side = mix(side, top_a * 0.82, sod);
	}
	vec3 col = mix(side, col_top, topness);

	// Verwelkt / verbrannt: braun-grau, matter (am Rand mit den Nachbarn gemischt wie die Farben)
	float lum = dot(col, vec3(0.3, 0.55, 0.15));
	col = mix(col, vec3(lum) * vec3(1.08, 0.96, 0.78), fx.x * 0.75);
	// Smog: grau
	col = mix(col, vec3(0.38, 0.37, 0.35) * (0.8 + 0.4 * fine), fx.y * 0.5);
	// Nässe: dunkler und glänzender
	col *= mix(1.0, 0.62, fx.z);
	// Wolkenschatten: wandern in Weltkoordinaten über alle Seiten (drehen nicht mit)
	vec2 cuv = (wp.xz + wp.yy * 0.6) * 0.09 + vec2(TIME * 0.012, TIME * 0.007);
	float cloud = smoothstep(0.48, 0.68, texture(n_fbm, cuv).r);
	col *= 1.0 - cloud_shadow * cloud;
	// Winter (Paket „Winter“): leichte Schneedecke, nur Oberseiten, höchstens 45 %, nie auf Wasser, Lava, Pflaster
	if (winter > 0.0) {
		float sn = smoothstep(0.42, 0.6, big * 0.6 + fine * 0.4) * 0.45 * winter * topness * (1.0 - cobble);
		sn *= (1.0 - smoothstep(0.0, 0.2, lav)) * (has_w ? smoothstep(0.0, 0.05, wd) : 1.0);
		col = mix(col, vec3(0.9, 0.92, 0.96), sn);
	}
	// Sonnenseite (Akt 4): oben warm und hell, Seiten Morgen/Abend, unten Nacht (blau, nie zu dunkel)
	if (sunface > 0.5) {
		float dd = clamp(day, -1.0, 1.0);
		vec3 tint = dd >= 0.0 ? mix(vec3(1.03, 0.93, 0.96), vec3(1.1, 1.05, 0.95), dd) : mix(vec3(1.03, 0.93, 0.96), vec3(0.7, 0.78, 1.0), -dd);
		col *= tint;
	}

	float water = has_w ? (1.0 - smoothstep(-0.006, 0.006, wd)) * topness : 0.0;
	vec3 emi = vec3(0.0);
	// gebogene Würfelkante (nur an Außenseiten liegt |uv| über 0,502)
	float bend = smoothstep(0.5, 0.53, max(abs(uv.x), abs(uv.y)));
	if (water > 0.0) {
		vec3 nrm_v = normalize(NORMAL + (VIEW_MATRIX * MODEL_MATRIX * vec4(wn, 0.0)).xyz);
		NORMAL = normalize(mix(NORMAL, nrm_v, water));
		float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0) * (1.0 - 0.8 * bend);
		// Himmel nur als Hauch (entsättigt): der See behält auch in warmem Licht seinen Ton
		vec3 sky = mix(vec3(dot(w_sky, vec3(0.3, 0.55, 0.15))), w_sky, 0.5);
		col = mix(col, mix(col, sky, 0.02 + fres * 0.35), water);
		// Glitzern nur, wo sich die Sonne spiegelt (nicht als Rausch-Linien), nicht auf der gebogenen Kante
		float spk2 = texture(n_fbm, (vec2(dot(w_m.xy, uv), dot(w_m.zw, uv)) + w_o) * 13.0 + vec2(TIME * 0.09, -TIME * 0.07)).r;
		float glint = pow(max(dot(reflect(-VIEW, NORMAL), normalize(sun_v)), 0.0), 40.0);
		emi += vec3(1.0, 0.95, 0.85) * glint * smoothstep(0.8, 0.9, spk2) * 0.45 * w_glint * water * (1.0 - cloud * 0.7) * (1.0 - bend)
			* (sunface > 0.5 ? smoothstep(0.3, 0.9, day) : 1.0);
		// Eigenton des Wassers (bleibt bei Abend- und Urzeitlicht blau-grün)
		emi += w_deep * 0.08 * water;
	}
	// Markierung: Lichtrand innen am Feldrand (nur zu Nachbarn ohne dieselbe Markierung), leicht getönte Fläche
	if (mark_c.a > 0.0) {
		float pls = mark_speed > 0.0 ? 0.6 + 0.4 * sin(TIME * mark_speed) : 1.0;
		vec4 dd = vec4(0.5 + ue.y, 0.5 - ue.x, 0.5 - ue.y, 0.5 + ue.x);   // Abstand zur Fuge N, O, S, W
		float rim = 0.0;
		for (int i = 0; i < 4; i++) {
			float on = abs(nb_fx[i].w - mark_id) > 0.5 ? 1.0 : 0.0;
			rim = max(rim, on * (1.0 - smoothstep(0.0, 0.11, dd[i])));
		}
		// Ecken: Diagonale ohne Markierung, beide Seiten daneben markiert
		for (int i = 0; i < 4; i++) {
			float on = abs(nb_fx[i + 4].w - mark_id) > 0.5 ? 1.0 : 0.0;
			float r = length(vec2(dd[i], dd[(i + 1) % 4]));
			rim = max(rim, on * (1.0 - smoothstep(0.0, 0.11, r)));
		}
		rim *= rim;
		col = mix(col, mark_c.rgb, mark_c.a * (0.12 + 0.35 * rim) * pls);
		emi += mark_c.rgb * mark_c.a * (0.06 + 0.9 * rim) * pls;
	}
	ALBEDO = min(col, vec3(1.0));
	// auf der gebogenen Würfelkante kein Spiegel-Glanz (sonst eine Perlenschnur aus Lichtpunkten)
	ROUGHNESS = mix(mix(mix(0.95, 0.78, cobble), 0.32, fx.z), 0.13 + 0.27 * bend, water);
	SPECULAR = mix(mix(0.3, 0.55, fx.z), 0.5 - 0.3 * bend, water);
	EMISSION = emi + lava_emi * topness + pulse_c * pulse * (0.35 + 0.65 * smoothstep(0.3, 0.5, m)) * 0.9;
}
