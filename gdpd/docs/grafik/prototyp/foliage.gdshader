// Laub (Prototyp): Farbe aus Vertexfarben (Grundton + Innen-Abdunklung), Wind über COLOR.a,
// leichte Farbstreuung je Baum aus der Weltposition, weiche Lichtumhüllung wie bei Blättern.
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;
uniform float sway = 0.012;
uniform float speed = 1.6;
uniform float vary = 0.12;
uniform sampler2D n_fbm : repeat_enable, filter_linear_mipmap;
varying vec3 lp;
varying float hue;
void vertex() {
	vec3 o = NODE_POSITION_WORLD;
	float ph = dot(o, vec3(3.1, 1.7, 2.3));
	float w = COLOR.a;
	VERTEX.x += sin(TIME * speed + ph) * sway * w;
	VERTEX.z += cos(TIME * speed * 0.83 + ph * 1.3) * sway * 0.6 * w;
	lp = VERTEX;
	hue = fract(sin(ph) * 43758.5453);
}
void fragment() {
	float n = texture(n_fbm, lp.xz * 14.0 + lp.yy * 9.0).r;
	vec3 c = COLOR.rgb * (0.8 + 0.4 * n);
	c *= mix(vec3(1.0 - vary, 1.0, 1.0 - vary * 0.6), vec3(1.0 + vary * 0.6, 1.0, 1.0 - vary), hue);
	ALBEDO = c;
	ROUGHNESS = 0.85;
	BACKLIGHT = vec3(0.25, 0.3, 0.1);
}
