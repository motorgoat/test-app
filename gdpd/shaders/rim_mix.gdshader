// Weicher Farbrand auf einer Kachel (Hinweis, Ziel, Gefahr): gemischt statt additiv, damit er auch auf hellem
// Boden (Wiese, Pflaster) klar zu sehen ist. Gleicher Aufbau wie rim.gdshader.
// pulse > 0: pulsiert im Shader (keine CPU-Arbeit je Bild).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform float half_size = 0.45;
uniform float width = 0.22;
uniform float fill = 0.12;
uniform float pulse = 0.0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float e = max(abs(lp.x), abs(lp.z)) / half_size;
	float rim = smoothstep(1.0 - width, 0.985, e) * (1.0 - smoothstep(0.985, 1.0, e) * 0.6);
	float k = pulse > 0.0 ? 0.72 + 0.28 * sin(TIME * pulse) : 1.0;
	ALBEDO = color.rgb;
	ALPHA = clamp((rim + fill) * color.a * k, 0.0, 1.0);
}
