// Flamme (Feuer, Krieg): Billboard in der Bildebene, steigt längs der Feld-Normalen auf. Form und Flackern aus
// Rauschen, Farbe von Glutweiß über Orange zu Rot. Additiv, wirft keinen Schatten.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;
uniform sampler2D n_fbm : repeat_enable, filter_linear_mipmap;
uniform float seed = 0.0;
uniform float strength = 1.0;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 up_w = MODEL_MATRIX[1].xyz;
	float sy = length(up_w);
	float sx = length(MODEL_MATRIX[0].xyz);
	vec3 n = up_w / max(sy, 1e-5);
	vec3 cam_r = INV_VIEW_MATRIX[0].xyz;
	vec3 cam_u = INV_VIEW_MATRIX[1].xyz;
	vec3 fwd = INV_VIEW_MATRIX[2].xyz;
	vec3 up_s = n - fwd * dot(n, fwd);
	float ls = length(up_s);
	vec3 up = normalize(mix(cam_u, up_s / max(ls, 1e-4), smoothstep(0.15, 0.5, ls)));
	vec3 right = normalize(cross(up, fwd));
	vec3 wp = origin + right * VERTEX.x * sx + up * VERTEX.y * sy;
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float h = 1.0 - UV.y;
	float x = (UV.x - 0.5) * 2.0;
	float n = texture(n_fbm, vec2(UV.x * 0.7 + seed, UV.y * 0.6 + TIME * 1.1 + seed * 3.0)).r;
	float n2 = texture(n_fbm, vec2(UV.x * 1.6 - seed, UV.y * 1.3 + TIME * 2.2)).r;
	float flick = 0.85 + 0.3 * texture(n_fbm, vec2(TIME * 0.7 + seed, seed)).r;
	float w = (1.0 - h) * 0.62 + 0.05;
	float xx = x + (n - 0.5) * 0.9 * h;
	float body = 1.0 - smoothstep(w * 0.45, w, abs(xx));
	body *= smoothstep(0.0, 0.1, h) * (1.0 - smoothstep(0.35 + n2 * 0.45, 0.95, h * flick));
	float core = (1.0 - smoothstep(w * 0.1, w * 0.5, abs(xx))) * (1.0 - smoothstep(0.08, 0.5, h));
	vec3 col = mix(vec3(0.85, 0.14, 0.02), vec3(1.0, 0.5, 0.08), body);
	col = mix(col, vec3(1.0, 0.86, 0.5), core * 0.9);
	ALBEDO = col * strength * 1.4;
	ALPHA = clamp(body * (0.7 + 0.5 * n2), 0.0, 1.0);
}
