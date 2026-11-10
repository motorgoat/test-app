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
// PROTOTYP Schöpfung: Glut von unten (Lava beleuchtet Wolken), Dunst (Uratmosphäre), Sterne (Nacht, Akt 4), Asche
uniform vec3 glow_c : source_color = vec3(1.0, 0.35, 0.08);
uniform float low_glow = 0.0;
uniform float haze = 0.0;
uniform float stars = 0.0;
uniform float ash = 0.0;
// Erdgeschichte: Rauch-Säule (Vulkan am Horizont), Staub-Sonne (nach dem Meteor: matte Scheibe hinter Staub)
uniform float plume = 0.0;
uniform float dust_sun = 0.0;
uniform vec3 dust_sun_c : source_color = vec3(1.0, 0.55, 0.3);
uniform float plume_x = 0.548;          // im Hochformat sieht die Kamera nur uv.x ≈ 0,39 … 0,61 der Himmelsebene
uniform vec2 dust_uv = vec2(0.46, 0.28);
// Meteor am Himmel (Einschlag, Vorzeichen): glühender Kopf mit Schweif, zieht langsam schräg nach unten
uniform float meteor = 0.0;
uniform vec2 meteor_uv = vec2(0.47, 0.22);
uniform vec2 meteor_dir = vec2(0.55, 0.85);
// Sonnen-Lichthof: im Hochformat sieht die Kamera nur uv.x ≈ 0,39 … 0,61 (sun_x < 0: alter Platz sun_uv)
uniform float sun_x = -1.0;
uniform float sun_y = 0.2;
void fragment() {
	vec2 uv = UV;
	float y = 1.0 - uv.y;
	vec3 c = mix(low_c, mid_c, smoothstep(0.05, 0.5, y));
	c = mix(c, top_c, smoothstep(0.5, 1.0, y));
	// warmer Lichthof dort, wo die Sonne steht
	vec2 suv = sun_x >= 0.0 ? vec2(sun_x, sun_y) : sun_uv;
	float sd = length((uv - suv) * vec2(1.0, 0.6));
	c += low_c * sun_glow * (1.0 - smoothstep(0.0, 0.55, sd)) * 0.5;
	// Schleier und Haufenwolken, ziehen langsam
	float n = texture(n_fbm, vec2(uv.x * 0.9 + TIME * 0.004, uv.y * 1.7)).r;
	float n2 = texture(n_fbm, vec2(uv.x * 2.3 - TIME * 0.006, uv.y * 3.1 + 0.4)).r;
	float cl = smoothstep(0.55, 0.9, n * 0.7 + n2 * 0.4) * (0.35 + 0.65 * smoothstep(0.2, 0.7, y));
	float heap = smoothstep(0.62, 0.78, texture(n_fbm, vec2(uv.x * 0.55 + TIME * 0.003, uv.y * 0.9 + 0.2)).r * 0.8 + n2 * 0.3);
	heap *= smoothstep(0.15, 0.35, y) * (1.0 - smoothstep(0.75, 0.95, y));
	vec3 cc = mix(cloud_c * 0.86, cloud_c, smoothstep(0.3, 0.9, n2));
	c = mix(c, cc, clamp(cl * 0.4 + heap * 0.55, 0.0, 1.0) * clouds);
	// Wolken der Urzeit: Unterseiten glühen rot (Lava), Dunst macht alles flach und dicht
	float under = (1.0 - smoothstep(0.0, 0.55, y));
	c = mix(c, mix(c, cloud_c * 0.8, 0.6), haze * (0.5 + 0.5 * n));
	c += glow_c * low_glow * (under * 0.9 + (cl + heap) * under * 0.8) * (0.7 + 0.3 * n2);
	// Sterne: feste Punkte (Gitter-Zufall), nur im oberen Himmel, leises Funkeln
	if (stars > 0.0) {
		vec2 g = uv * vec2(90.0, 46.0);
		vec2 id = floor(g);
		float r = fract(sin(dot(id, vec2(12.9898, 78.233))) * 43758.5453);
		vec2 f = fract(g) - vec2(fract(r * 7.3), fract(r * 3.1)) * 0.6 - 0.2;
		float st = (1.0 - smoothstep(0.02, 0.08, length(f))) * step(0.86, r);
		st *= 0.6 + 0.4 * sin(TIME * (1.0 + r * 3.0) + r * 40.0);
		c += vec3(0.9, 0.93, 1.0) * st * stars * smoothstep(0.25, 0.7, y) * (1.0 - cl * 0.8);
	}
	// Asche: dunkle Schlieren, die langsam steigen
	if (ash > 0.0) {
		float a = texture(n_fbm, vec2(uv.x * 3.0, uv.y * 1.2 + TIME * 0.01)).r;
		c = mix(c, c * 0.55, smoothstep(0.55, 0.8, a) * ash);
	}
	if (plume > 0.0) {
		// Rauchfahne eines fernen Vulkans: dünne Säule am Horizont, oben breit und abgedriftet
		float px = uv.x - plume_x - (y - 0.1) * 0.06 - 0.008 * sin(y * 8.0 + TIME * 0.2);
		float pw = 0.004 + 0.03 * smoothstep(0.08, 0.6, y);
		float pn = texture(n_fbm, vec2(px * 9.0, y * 2.0 - TIME * 0.01)).r;
		float pm = (1.0 - smoothstep(pw * 0.5, pw, abs(px) + (pn - 0.5) * 0.015)) * smoothstep(0.3, 0.42, y) * (1.0 - smoothstep(0.62, 0.85, y));
		c = mix(c, mix(vec3(0.3, 0.28, 0.27), vec3(0.52, 0.5, 0.47), pn), pm * plume * 0.72);
		c += glow_c * (1.0 - smoothstep(0.0, 0.005, abs(uv.x - plume_x))) * smoothstep(0.29, 0.31, y) * (1.0 - smoothstep(0.31, 0.34, y)) * plume * 0.12;
	}
	if (dust_sun > 0.0) {
		// matte Scheibe hinter Staub: klein, weicher Rand, vom ziehenden Staub halb verschluckt (keine Strahlen)
		float sdd = length((uv - dust_uv) * vec2(1.0, 0.5));
		float veil = texture(n_fbm, vec2(uv.x * 6.0 + TIME * 0.006, uv.y * 3.0)).r;
		float disc = (1.0 - smoothstep(0.0042, 0.0062, sdd)) * (0.55 + 0.45 * smoothstep(0.35, 0.7, 1.0 - veil));
		c = mix(c, dust_sun_c * 0.92, disc * dust_sun * 0.8);
		c += dust_sun_c * (1.0 - smoothstep(0.0, 0.05, sdd)) * dust_sun * 0.18;
	}
	if (meteor > 0.0) {
		// Schweif: hinter dem Kopf (gegen die Flugrichtung), wird nach hinten dünn und dunkler; Kopf weiß-gelb
		vec2 dir = normalize(meteor_dir);
		vec2 rel = (uv - meteor_uv) * vec2(1.0, 0.5);
		float along = dot(rel, dir * vec2(1.0, 0.5) / length(dir * vec2(1.0, 0.5)));
		vec2 nd = normalize(dir * vec2(1.0, 0.5));
		float across = abs(rel.x * nd.y - rel.y * nd.x);
		float tl = clamp(-along / 0.09, 0.0, 1.0);
		float tail = (1.0 - smoothstep(0.0012 + 0.004 * tl, 0.0025 + 0.008 * tl, across)) * step(along, 0.0) * (1.0 - tl);
		float flick = 0.85 + 0.15 * sin(TIME * 23.0);
		c = mix(c, vec3(1.0, 0.62, 0.3), tail * meteor * 0.85);
		float hd = length(rel);
		c += vec3(1.0, 0.85, 0.55) * (1.0 - smoothstep(0.0, 0.012, hd)) * meteor * 1.4 * flick;
		c += vec3(1.0, 0.55, 0.25) * (1.0 - smoothstep(0.0, 0.05, hd)) * meteor * 0.35;
	}
	c += vec3(0.85, 0.88, 1.0) * flash;
	ALBEDO = c;
}
