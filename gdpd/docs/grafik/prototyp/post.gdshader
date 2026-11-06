// Nachbearbeitung (Prototyp): Tilt-Shift wie bisher, dazu weiches Glühen aus hellen Stellen,
// Farbstimmung (warme Lichter, kühle Schatten), leichte S-Kurve, Vignette.
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float focus_y = 0.47;
uniform float focus_half = 0.16;
uniform float blur_px = 7.0;
uniform float vignette = 0.3;
uniform float saturation = 1.04;
uniform float contrast = 1.03;
uniform vec3 warm = vec3(1.04, 1.0, 0.93);
uniform vec3 cool = vec3(0.93, 0.98, 1.06);
uniform float bloom = 0.22;
void fragment() {
	float d = abs(SCREEN_UV.y - focus_y);
	float k = smoothstep(focus_half, focus_half + 0.28, d);
	vec2 o = SCREEN_PIXEL_SIZE * blur_px * k;
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;
	vec3 c = base * 0.2;
	c += texture(screen_tex, SCREEN_UV + vec2(o.x, 0.0)).rgb * 0.1;
	c += texture(screen_tex, SCREEN_UV - vec2(o.x, 0.0)).rgb * 0.1;
	c += texture(screen_tex, SCREEN_UV + vec2(0.0, o.y)).rgb * 0.1;
	c += texture(screen_tex, SCREEN_UV - vec2(0.0, o.y)).rgb * 0.1;
	c += texture(screen_tex, SCREEN_UV + o * 1.6).rgb * 0.1;
	c += texture(screen_tex, SCREEN_UV - o * 1.6).rgb * 0.1;
	c += texture(screen_tex, SCREEN_UV + vec2(o.x, -o.y) * 1.6).rgb * 0.1;
	c += texture(screen_tex, SCREEN_UV + vec2(-o.x, o.y) * 1.6).rgb * 0.1;
	// Glühen: grobe Mip-Stufe des Bildes, nur helle Anteile
	vec3 g = textureLod(screen_tex, SCREEN_UV, 4.0).rgb;
	c += max(g - 0.72, 0.0) * bloom * 3.0;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c * cool, c * warm, smoothstep(0.15, 0.75, l));
	c = (c - 0.5) * contrast + 0.5;
	l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	vec2 v = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * dot(v, v) * 1.4;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
