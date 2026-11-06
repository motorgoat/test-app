extends SceneTree
## Look-Dev-Prototyp: baut den Würfel ohne Spiel (FieldView + Models), "before" = heutiger Look,
## "after" = Prototyp der neuen Richtung. Speichert ein Bild und beendet sich.
##   godot --rendering-driver opengl3 --resolution 1080x2340 --script res://lookdev/lookdev.gd -- --mode=after --out=/pfad.png

const Flora = preload("res://lookdev/flora.gd")

var mode := "after"
var out := ""
var zoom := 1.0
var frames := 0
var shot_at := 100
var n_fbm: NoiseTexture2D
var n_cell: NoiseTexture2D

const LAYOUT := {
	"y": [15, 15, 1, 1, 2, 3, 7, 8, 4],
	"z": [3, 3, 5, 1, 0, 0, 2, 6, 10],
	"x": [9, 11, 12, 7, 3, 1, 15, 2, 4],
}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.substr(7)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--zoom="):
			zoom = float(a.substr(7))
		elif a.begins_with("--frames="):
			shot_at = int(a.substr(9))
	var after := mode == "after"
	if after:
		_make_noise()
		Models.look = 1
		Models.detail_tex = _detail_tex()
		Flora.noise_fbm = n_fbm
	var root := Node3D.new()
	get_root().add_child(root)
	var rig := Node3D.new()
	root.add_child(rig)
	rig.basis = CameraRig.start_basis()
	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.near = 0.1
	cam.far = 100.0
	rig.add_child(cam)
	cam.current = true
	var vs := Vector2(get_root().size)
	var half := minf(deg_to_rad(17.0), atan(tan(deg_to_rad(17.0)) * vs.x / vs.y))
	cam.position = Vector3(0, 0, 17.5 * zoom)
	print("LOOKDEV vs ", vs, " half ", half)
	_env(root, after)
	_lights(rig, after)
	if after:
		_backdrop(cam)
	else:
		_old_clouds(rig)
	_cube(root, after)
	_post(root, after)


func _make_noise() -> void:
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.012
	fn.fractal_octaves = 4
	n_fbm = NoiseTexture2D.new()
	n_fbm.width = 256
	n_fbm.height = 256
	n_fbm.seamless = true
	n_fbm.noise = fn
	var cn := FastNoiseLite.new()
	cn.noise_type = FastNoiseLite.TYPE_CELLULAR
	cn.frequency = 0.06
	cn.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	cn.fractal_type = FastNoiseLite.FRACTAL_NONE
	n_cell = NoiseTexture2D.new()
	n_cell.width = 256
	n_cell.height = 256
	n_cell.seamless = true
	n_cell.noise = cn


func _detail_tex() -> NoiseTexture2D:
	var fn := FastNoiseLite.new()
	fn.frequency = 0.05
	fn.fractal_octaves = 3
	var t := NoiseTexture2D.new()
	t.width = 128
	t.height = 128
	t.seamless = true
	t.noise = fn
	var g := Gradient.new()
	g.set_color(0, Color(0.74, 0.74, 0.74))
	g.set_color(1, Color(1, 1, 1))
	t.color_ramp = g
	return t


func _env(root: Node3D, after: bool) -> void:
	var env := Environment.new()
	if after:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("#d9dcd8")
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("#9fb3cc")
		env.ambient_light_energy = 0.8
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = 1.12
		env.tonemap_white = 6.0
		env.glow_enabled = true
		env.glow_intensity = 0.6
		env.glow_bloom = 0.05
		env.glow_hdr_threshold = 1.0
	else:
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color("#9fd3f5")
		sky_mat.sky_horizon_color = Color("#fdeedd")
		sky_mat.ground_horizon_color = Color("#fdeedd")
		sky_mat.ground_bottom_color = Color("#f6dcc0")
		sky_mat.sun_angle_max = 0.0
		sky_mat.sky_curve = 0.12
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("#b9c6dc")
		env.ambient_light_energy = 0.32
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 0.82
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)


func _lights(rig: Node3D, after: bool) -> void:
	var key := DirectionalLight3D.new()
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 16.0 if not after else 24.0
	key.shadow_enabled = true
	if after:
		key.rotation_degrees = Vector3(-36, -48, 0)
		key.light_color = Color("#ffe2b8")
		key.light_energy = 1.45
		key.shadow_blur = 1.2
		key.shadow_bias = 0.03
		key.shadow_normal_bias = 1.2
		key.shadow_opacity = 0.85
	else:
		key.rotation_degrees = Vector3(-42, -35, 0)
		key.light_color = Color("#fff3df")
		key.light_energy = 0.78
		key.shadow_blur = 1.5
		key.shadow_bias = 0.06
		key.shadow_normal_bias = 1.8
	rig.add_child(key)
	var fill := DirectionalLight3D.new()
	if after:
		fill.rotation_degrees = Vector3(-20, 140, 0)
		fill.light_color = Color("#a9c2e8")
		fill.light_energy = 0.42
	else:
		fill.rotation_degrees = Vector3(-15, 150, 0)
		fill.light_color = Color("#cfe0ff")
		fill.light_energy = 0.18
	rig.add_child(fill)


func _backdrop(cam: Camera3D) -> void:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(30, 60)
	q.mesh = qm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://lookdev/backdrop.gdshader")
	sm.set_shader_parameter("n_fbm", n_fbm)
	q.material_override = sm
	q.position = Vector3(0, 0, -60)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(q)


func _old_clouds(rig: Node3D) -> void:
	var cm := Models.unshaded(Color(1, 1, 1, 0.85))
	for sp in [Vector3(-2.9, 2.2, -5.0), Vector3(2.7, 1.2, -6.0), Vector3(-2.2, -2.4, -5.5)]:
		var c := Node3D.new()
		c.position = sp
		rig.add_child(c)
		for k in 3:
			Models.sphere(c, [0.42, 0.55, 0.38][k], Color.WHITE, Vector3([-0.45, 0.0, 0.45][k], [0.0, 0.12, -0.02][k], 0.0), cm)


func _ground_mat(kind: int) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = load("res://lookdev/ground.gdshader")
	sm.set_shader_parameter("n_fbm", n_fbm)
	sm.set_shader_parameter("n_cell", n_cell)
	var a := Color("#56702c")
	var b := Color("#6f8a3a")
	var acc := Color("#8c857a")
	var acc_amt := 0.0
	var cob := 0.0
	match kind:
		0:
			a = Color("#5b4330"); b = Color("#6e5238"); acc_amt = 0.8
		1, 5, 14:
			a = Color("#5d7a2e"); b = Color("#7d9442")
		2, 4:
			a = Color("#3f4f24"); b = Color("#5a4b2f"); acc = Color("#6b5a3c"); acc_amt = 0.3
		3:
			a = Color("#4e3826"); b = Color("#5c4330")
		6, 7, 8, 10:
			a = Color("#607a30"); b = Color("#8a7d55"); acc_amt = 0.25
		9, 11, 13:
			a = Color("#8f8a80"); b = Color("#a39d92"); acc = Color("#b3ada2"); acc_amt = 0.0; cob = 1.0
		12:
			a = Color("#55524d"); b = Color("#6a665f"); acc = Color("#7a756c"); acc_amt = 0.2
		15:
			a = Color("#a89772"); b = Color("#bba983")
	sm.set_shader_parameter("top_a", a)
	sm.set_shader_parameter("top_b", b)
	sm.set_shader_parameter("accent", acc)
	sm.set_shader_parameter("accent_amt", acc_amt)
	sm.set_shader_parameter("cobble", cob)
	return sm


func _cube(root: Node3D, after: bool) -> void:
	var body_mesh := Models.rounded_box_mesh(Vector3(0.98, 0.98, 0.98), 0.12, 4)
	var body_mat: Material = Models.mat(Color("#3a3d4a"), 0.35)
	if after:
		var bm := ShaderMaterial.new()
		bm.shader = load("res://lookdev/bedrock.gdshader")
		bm.set_shader_parameter("n_fbm", n_fbm)
		body_mat = bm
		body_mesh = Models.rounded_box_mesh(Vector3(0.98, 0.98, 0.98), 0.05, 2)
	var fid := 0
	for x in [-1, 0, 1]:
		for y in [-1, 0, 1]:
			for z in [-1, 0, 1]:
				var p := Vector3i(x, y, z)
				if p == Vector3i.ZERO:
					continue
				var cb := Node3D.new()
				cb.position = Vector3(p)
				root.add_child(cb)
				var mi := MeshInstance3D.new()
				mi.mesh = body_mesh
				mi.material_override = body_mat
				cb.add_child(mi)
				for a in 3:
					if p[a] == 0:
						continue
					var n := Vector3i.ZERO
					n[a] = p[a]
					var v := FieldView.new()
					cb.add_child(v)
					v.transform = Transform3D(_face_basis(a, n), Vector3(n) * 0.47)
					var f := FieldData.new()
					f.id = fid
					f.p = p
					f.n = n
					fid += 1
					v.build(f)
					var u := (a + 1) % 3
					var w := (a + 2) % 3
					var idx := (p[u] + 1) * 3 + (p[w] + 1)
					var key: String = ["x", "y", "z"][a]
					var kind: int = int(LAYOUT[key][idx]) if p[a] > 0 else (fid * 7) % 10
					v.set_kind(kind)
					if after:
						_restyle(v, kind)


func _face_basis(a: int, n: Vector3i) -> Basis:
	var y := Vector3(n)
	var x := Vector3.ZERO
	x[(a + 1) % 3] = 1.0
	return Basis(x, y, x.cross(y))


func _restyle(v: FieldView, kind: int) -> void:
	v._tile.material_override = _ground_mat(kind)
	if kind == 15:
		var surf: MeshInstance3D = null
		for c in v._content.get_children():
			if c is MeshInstance3D and surf == null:
				surf = c
			elif c is Node3D:
				c.visible = false
		if surf != null:
			var wm := ShaderMaterial.new()
			wm.shader = load("res://lookdev/water.gdshader")
			wm.set_shader_parameter("n_fbm", n_fbm)
			surf.material_override = wm
			surf.scale = Vector3(1.04, 1, 1.04)


func _post(root: Node3D, after: bool) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	root.add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://lookdev/post.gdshader" if after else "res://shaders/tilt_shift.gdshader")
	rect.material = sm
	layer.add_child(rect)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == shot_at:
		var img := get_root().get_texture().get_image()
		if out != "":
			img.save_jpg(out, 0.9) if out.ends_with(".jpg") else img.save_png(out)
		print("LOOKDEV saved ", out)
		print("LOOKDEV stats draw=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			" objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			" prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			" vmem=", Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
		quit()
	return false
