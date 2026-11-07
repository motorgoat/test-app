// Lichtring, der sich über die Kachel ausbreitet (Verschmelzen, Wachsen). progress 0..1 wird getweent.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform float progress = 0.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float rad = mix(0.15, 0.98, progress);
	float band = 1.0 - smoothstep(0.0, 0.13 + 0.1 * progress, abs(r - rad));
	float inner = (1.0 - smoothstep(0.0, rad, r)) * 0.25;
	ALBEDO = color.rgb;
	ALPHA = clamp((band + inner) * color.a * (1.0 - progress * progress), 0.0, 1.0);
}
