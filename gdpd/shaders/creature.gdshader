// Tiere und Menschen (GDPD_GRAFIK.md 9.2): Farbe aus den Vertexfarben, Bewegung ohne Skelett.
// UV.x = Teil (0 Rumpf, 1/2 Beine Takt A/B, 3 Kopf, 4 Oberkörper, 5/6 Arme, 7 Schwanz), UV.y = Hüfthöhe,
// UV2 = Drehpunkt in x/y. Blickrichtung +x. walk: Gehen, graze: Kopf runter (Tier), bend: Bücken (Mensch),
// hop: Hüpfen (Regen), rate: Schrittfrequenz.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform float walk = 0.0;
uniform float graze = 0.0;
uniform float bend = 0.0;
uniform float hop = 0.0;
uniform float rate = 11.0;
uniform float phase = 0.0;
uniform float tint = 0.0;     // 0..1 traurig/grau (Hunger)
uniform float stride = 1.0;   // Schrittweite der Beine (große Tiere: Langhals, Mammut schreiten kürzer)

vec2 rot2(vec2 d, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(d.x * c - d.y * s, d.x * s + d.y * c);
}

void vertex() {
	float part = floor(UV.x + 0.5);
	float hip = UV.y;
	vec2 piv = UV2;
	float t = TIME * rate + phase;
	float sw = sin(t);
	if (part == 1.0 || part == 2.0) {
		float a = (part == 1.0 ? 1.0 : -1.0) * sw * 0.6 * walk * stride;
		VERTEX.xy = piv + rot2(VERTEX.xy - piv, a);
	} else if (part == 5.0 || part == 6.0) {
		float sg = part == 5.0 ? -1.0 : 1.0;
		float a = sg * sw * 0.55 * walk + sg * sin(TIME * 6.0 + phase) * 0.45 * bend - 0.5 * bend;
		VERTEX.xy = piv + rot2(VERTEX.xy - piv, a);
	} else if (part == 3.0) {
		float idle = sin(TIME * 0.9 + phase) * 0.08 * (1.0 - graze);
		float chew = sin(TIME * 4.0 + phase) * 0.06 * graze;
		VERTEX.xy = piv + rot2(VERTEX.xy - piv, -graze * 1.05 + idle + chew);
	} else if (part == 7.0) {
		VERTEX.z += sin(TIME * 5.0 + phase) * 0.35 * (piv.y - VERTEX.y);
	} else if (part == 8.0) {
		// waagrechter Schwanz (Saurier, Mammut nicht): Welle läuft zur Spitze, Ausschlag wächst mit dem Abstand
		float dl = max(piv.x - VERTEX.x, 0.0);
		VERTEX.z += sin(TIME * 1.6 + phase - dl * 30.0) * 0.22 * dl * (1.0 + walk);
	}
	if (part >= 4.0 && part <= 6.0) {
		vec2 hp = vec2(0.0, hip);
		VERTEX.xy = hp + rot2(VERTEX.xy - hp, -bend * 0.85 + sin(TIME * 0.7 + phase) * 0.03);
	}
	VERTEX.y += abs(sw) * 0.0025 * walk + abs(sin(TIME * 9.0 + phase)) * 0.018 * hop;
}

void fragment() {
	vec3 c = COLOR.rgb;
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	ALBEDO = mix(c, vec3(l) * vec3(0.95, 0.95, 1.0), tint * 0.6);
	ROUGHNESS = 0.82;
	SPECULAR = 0.3;
}
