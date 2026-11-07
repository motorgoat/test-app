// Laub, Gras, Ähren: Farbe gedeckt mit leichter Streuung je Pflanze, weiche Lichtumhüllung, Durchscheinen,
// Wind im Vertex-Shader. Gewicht aus der Höhe im Mesh (oben mehr), bei use_vc zusätzlich aus COLOR.a.
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;
uniform vec3 albedo : source_color = vec3(0.3, 0.45, 0.2);
uniform bool use_vc = false;
uniform float sway = 0.0045;
uniform float speed = 1.7;
uniform float gust = 1.0;
uniform float vary = 0.1;
uniform sampler2D n_fbm : repeat_enable, filter_linear_mipmap;
varying vec3 lp;
varying float hue;
varying float ao;
void vertex() {
	// Zufall je Pflanze aus dem Mesh selbst (nie aus NODE_POSITION_WORLD: das wandert beim Drehen einer Scheibe und
	// liesse Farbe und Wind flackern). Gebackene Felder bringen ihn in UV2.x mit, sonst Raster im Objektraum.
	float seed = UV2.x > 0.0 ? UV2.x * 97.0 : dot(floor(VERTEX.xz * 9.0), vec2(3.1, 2.3));
	float ph = seed;
	float w = clamp(0.35 + VERTEX.y * 10.0, 0.0, 1.3);
	if (use_vc) { w *= COLOR.a; }
	float vp = ph + dot(VERTEX.xz, vec2(37.0, 29.0));
	float g = gust * (0.75 + 0.25 * sin(TIME * 0.37 + ph * 0.2));
	VERTEX.x += sin(TIME * speed + vp) * sway * w * g;
	VERTEX.z += cos(TIME * speed * 0.83 + vp * 1.3) * sway * 0.6 * w * g;
	lp = VERTEX;
	hue = fract(sin(seed * 1.37 + 12.9898) * 43758.5453);
	// eigene Meshes (use_vc) bringen ihre Abdunklung in den Vertexfarben mit
	ao = use_vc ? 1.0 : clamp(0.62 + VERTEX.y * 7.0, 0.55, 1.0);
}
void fragment() {
	float n = texture(n_fbm, lp.xz * 14.0 + lp.yy * 9.0).r;
	vec3 c = (use_vc ? COLOR.rgb : albedo) * (0.82 + 0.36 * n);
	c *= mix(vec3(1.0 - vary, 1.0, 1.0 - vary * 0.6), vec3(1.0 + vary * 0.6, 1.0, 1.0 - vary), hue);
	ALBEDO = c * ao;
	ROUGHNESS = 0.85;
	BACKLIGHT = c * 0.45;
}
