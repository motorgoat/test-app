// Miniatur-Look: oben und unten weich unscharf, leichte Vignette, etwas mehr Farbe.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float focus_y = 0.47;
uniform float focus_half = 0.18;
uniform float blur_px = 3.0;
uniform float vignette = 0.32;
uniform float saturation = 1.08;

void fragment() {
	float d = abs(SCREEN_UV.y - focus_y);
	float k = smoothstep(focus_half, focus_half + 0.3, d);
	vec2 o = SCREEN_PIXEL_SIZE * blur_px * k;
	vec3 c = texture(screen_tex, SCREEN_UV).rgb * 0.2;
	c += texture(screen_tex, SCREEN_UV + vec2(o.x, 0.0)).rgb * 0.1;
	c += texture(screen_tex, SCREEN_UV - vec2(o.x, 0.0)).rgb * 0.1;
	c += texture(screen_tex, SCREEN_UV + vec2(0.0, o.y)).rgb * 0.1;
	c += texture(screen_tex, SCREEN_UV - vec2(0.0, o.y)).rgb * 0.1;
	c += texture(screen_tex, SCREEN_UV + o * 1.6).rgb * 0.1;
	c += texture(screen_tex, SCREEN_UV - o * 1.6).rgb * 0.1;
	c += texture(screen_tex, SCREEN_UV + vec2(o.x, -o.y) * 1.6).rgb * 0.1;
	c += texture(screen_tex, SCREEN_UV + vec2(-o.x, o.y) * 1.6).rgb * 0.1;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	vec2 v = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * dot(v, v) * 1.4;
	COLOR = vec4(c, 1.0);
}
