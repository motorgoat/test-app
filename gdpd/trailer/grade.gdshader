shader_type canvas_item;
// Trailer-Farbkorrektur über der 3D-Welt (unter dem Text): Belichtung, Kontrast, Sättigung, Vignette,
// farbiger Bildblitz und waagrechte Wisch-Unschärfe für die Schnitte.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float exposure = 1.0;
uniform float contrast = 1.0;
uniform float saturation = 1.0;
uniform float vignette = 0.0;
uniform vec3 tint = vec3(1.0);
uniform float tint_amt = 0.0;
uniform vec3 flash_c = vec3(1.0);
uniform float flash = 0.0;
uniform float blur = 0.0;        // in Bildbreiten

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c;
	if (blur > 0.0008) {
		c = vec3(0.0);
		for (int i = 0; i < 16; i++) {
			float k = float(i) / 15.0 - 0.5;
			c += texture(screen_tex, uv + vec2(k * blur, 0.0)).rgb;
		}
		c /= 16.0;
	} else {
		c = texture(screen_tex, uv).rgb;
	}
	c *= exposure;
	c = (c - 0.5) * contrast + 0.5;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = mix(c, c * tint, tint_amt);
	vec2 d = uv - 0.5;
	d.y *= 0.8;
	float v = smoothstep(0.28, 0.78, length(d));
	c *= 1.0 - vignette * v;
	c = mix(c, flash_c, clamp(flash, 0.0, 1.0));
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
