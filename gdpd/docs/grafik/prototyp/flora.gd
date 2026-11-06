extends RefCounted
## Prototyp: realistischere Bäume, Häuser und Menschen aus EINEM Mesh je Modell (ein Draw-Call),
## Vertexfarben tragen Farbe + Innen-Abdunklung, COLOR.a = Windgewicht (0 Stamm .. 1 Kronenspitze).

static var _cache: Dictionary = {}
static var _foliage: ShaderMaterial
static var _solid: StandardMaterial3D
static var noise_fbm: NoiseTexture2D


static func foliage_mat() -> ShaderMaterial:
	if _foliage == null:
		_foliage = ShaderMaterial.new()
		_foliage.shader = load("res://lookdev/foliage.gdshader")
		_foliage.set_shader_parameter("n_fbm", noise_fbm)
	return _foliage


static func solid_mat() -> StandardMaterial3D:
	if _solid == null:
		_solid = StandardMaterial3D.new()
		_solid.vertex_color_use_as_albedo = true
		_solid.roughness = 0.85
		_solid.albedo_texture = noise_fbm
		_solid.uv1_triplanar = true
		_solid.uv1_scale = Vector3(6, 6, 6)
	return _solid


## Dreieck mit Farbe/Gewicht je Ecke, in Godots Vorderseiten-Reihenfolge (im Uhrzeigersinn von außen).
static func _emit(st: SurfaceTool, p: Array, n: Array, c: Array, out: Vector3) -> void:
	var p0: Vector3 = p[0]
	var p1: Vector3 = p[1]
	var p2: Vector3 = p[2]
	var cr := (p1 - p0).cross(p2 - p0)
	var order := [0, 2, 1] if cr.dot(out) > 0.0 else [0, 1, 2]
	for i in order:
		st.set_color(c[i])
		st.set_normal(n[i])
		st.add_vertex(p[i])


static func _blob(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, rng: RandomNumberGenerator, sway: float, rings: int = 5, segs: int = 8) -> void:
	# grob verbeulte Kugel, unten dunkler (Eigenschatten)
	var pts: Array = []
	for i in rings + 1:
		var v := float(i) / float(rings)
		var phi := v * PI
		var row: Array = []
		for j in segs:
			var th := float(j) / float(segs) * TAU
			var d := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var bump := 1.0 + rng.randf_range(-0.16, 0.16) * sin(phi)
			row.append(d * bump)
		pts.append(row)
	for i in rings:
		for j in segs:
			var j2 := (j + 1) % segs
			var quad := [pts[i][j], pts[i][j2], pts[i + 1][j2], pts[i + 1][j]]
			var tris := [[0, 2, 1], [0, 3, 2]]
			for t in tris:
				var a: Vector3 = quad[t[0]]
				var b: Vector3 = quad[t[1]]
				var cc: Vector3 = quad[t[2]]
				var fn := (b - a).cross(cc - a).normalized()
				if fn.dot(a + b + cc) < 0.0:
					fn = -fn
				var ps: Array = []
				var ns: Array = []
				var cs: Array = []
				for p in [a, b, cc]:
					var pv: Vector3 = p
					var shade := 0.62 + 0.38 * clampf(pv.y * 0.5 + 0.5, 0.0, 1.0)
					var k := col * shade
					k.a = sway * clampf(0.6 + pv.y * 0.4, 0.0, 1.0)
					cs.append(k)
					ns.append((fn * 0.5 + pv.normalized() * 0.5).normalized())
					ps.append(c + pv * r)
				_emit(st, ps, ns, cs, fn)


static func _cyl(st: SurfaceTool, base: Vector3, top: Vector3, r0: float, r1: float, col0: Color, col1: Color, segs: int = 6, sway0: float = 0.0, sway1: float = 0.0) -> void:
	var axis := (top - base).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(axis)
	for j in segs:
		var a0 := float(j) / segs * TAU
		var a1 := float(j + 1) / segs * TAU
		var d0 := side * cos(a0) + up * sin(a0)
		var d1 := side * cos(a1) + up * sin(a1)
		var p := [base + d0 * r0, base + d1 * r0, top + d1 * r1, top + d0 * r1]
		var n := [d0, d1, d1, d0]
		var cl := [col0, col0, col1, col1]
		var sw := [sway0, sway0, sway1, sway1]
		for t in [[0, 1, 2], [0, 2, 3]]:
			var ps: Array = []
			var ns: Array = []
			var cs: Array = []
			for idx in t:
				var c: Color = cl[idx]
				c.a = sw[idx]
				cs.append(c)
				ns.append(n[idx])
				ps.append(p[idx])
			_emit(st, ps, ns, cs, d0 + d1)


static func _cone(st: SurfaceTool, base: Vector3, h: float, r: float, col: Color, segs: int, rng: RandomNumberGenerator, sway: float) -> void:
	# Tannen-Etage: gezackter Rand (abwechselnd Radius), unten dunkler
	var ring: Array = []
	for j in segs:
		var a := float(j) / segs * TAU + rng.randf_range(-0.1, 0.1)
		var rr := r * (1.0 if j % 2 == 0 else 0.72) * rng.randf_range(0.9, 1.08)
		ring.append(base + Vector3(cos(a) * rr, rng.randf_range(-0.12, 0.05) * h, sin(a) * rr))
	var tip := base + Vector3(0, h, 0)
	var under := base + Vector3(0, h * 0.18, 0)
	for j in segs:
		var a: Vector3 = ring[j]
		var b: Vector3 = ring[(j + 1) % segs]
		var fn := (b - a).cross(tip - a).normalized()
		if fn.dot((a + b) * 0.5 - base) < 0.0:
			fn = -fn
		var ca: Color = col * 0.75
		var ct: Color = col * 1.15
		ca.a = sway * 0.6
		ct.a = sway
		_emit(st, [a, tip, b], [fn, fn, fn], [ca, ct, ca], fn)
		var cu: Color = col * 0.4
		cu.a = sway * 0.5
		_emit(st, [a, b, under], [Vector3.DOWN, Vector3.DOWN, Vector3.DOWN], [cu, cu, cu], Vector3.DOWN)


static func _finish(key: String, st: SurfaceTool) -> Mesh:
	var m := st.commit()
	_cache[key] = m
	return m


## Laubbaum (Eiche/Linde) – variant 0..3
static func oak_mesh(variant: int) -> Mesh:
	var key := "oak%d" % variant
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + variant * 17
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color("#4d3b2a")
	var h := rng.randf_range(0.1, 0.13)
	_cyl(st, Vector3.ZERO, Vector3(0.004, h, 0), 0.016, 0.009, bark * 0.8, bark, 6, 0.0, 0.25)
	_cyl(st, Vector3(0.002, h * 0.7, 0), Vector3(0.04, h * 1.05, 0.01), 0.006, 0.003, bark, bark, 5, 0.2, 0.4)
	var greens := [Color("#4a6a2a"), Color("#56772f"), Color("#3f5f27"), Color("#62803a")]
	var g: Color = greens[variant % 4]
	var n := 5 + variant % 3
	for k in n:
		var a := float(k) / n * TAU + rng.randf() * 0.6
		var rr := rng.randf_range(0.03, 0.05)
		var c := Vector3(cos(a) * rr, h + 0.03 + rng.randf_range(-0.01, 0.04), sin(a) * rr)
		var s := rng.randf_range(0.045, 0.06)
		_blob(st, c, Vector3(s, s * 0.85, s), g * rng.randf_range(0.88, 1.08), rng, 1.0)
	_blob(st, Vector3(0, h + 0.08, 0), Vector3(0.055, 0.05, 0.055), g * 1.1, rng, 1.0)
	return _finish(key, st)


## Birke: heller Stamm mit dunklen Flecken, lockere, hellgrüne Krone
static func birch_mesh(variant: int) -> Mesh:
	var key := "birch%d" % variant
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 400 + variant * 31
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.2
	for i in 5:
		var y0 := h * i / 5.0
		var y1 := h * (i + 1) / 5.0
		var c := Color("#e6e1d6") if i % 2 == 0 else Color("#b9b3a8")
		_cyl(st, Vector3(0, y0, 0), Vector3(0, y1, 0), 0.009 - i * 0.001, 0.008 - i * 0.001, c, c, 6, y0 / h * 0.6, y1 / h * 0.6)
	var g := Color("#7d9443")
	for k in 4:
		var c := Vector3(rng.randf_range(-0.03, 0.03), 0.13 + k * 0.035, rng.randf_range(-0.03, 0.03))
		var s := 0.045 - k * 0.006
		_blob(st, c, Vector3(s, s * 1.1, s), g * rng.randf_range(0.9, 1.1), rng, 1.0, 4, 7)
	return _finish(key, st)


## Fichte: schlanke, dunkle Etagen mit gezacktem Rand
static func spruce_mesh(variant: int) -> Mesh:
	var key := "spruce%d" % variant
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + variant * 13
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color("#3f3125")
	_cyl(st, Vector3.ZERO, Vector3(0, 0.06, 0), 0.01, 0.008, bark, bark, 5)
	var g := Color("#2f4a2f") if variant % 2 == 0 else Color("#38543a")
	var tiers := 5
	for i in tiers:
		var t := float(i) / tiers
		var r := lerpf(0.075, 0.022, t)
		_cone(st, Vector3(0, 0.035 + i * 0.045, 0), 0.075 - t * 0.02, r, g * (0.85 + 0.25 * t), 12, rng, 0.35 + 0.65 * t)
	return _finish(key, st)


static func place(parent: Node3D, mesh: Mesh, pos: Vector3, s: float, rot: float, foliage: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = foliage_mat() if foliage else solid_mat()
	mi.position = pos
	mi.rotation.y = rot
	mi.scale = Vector3.ONE * s
	parent.add_child(mi)
	return mi


static func tree(parent: Node3D, pos: Vector3, s: float) -> void:
	var hsh := int(absf(pos.x * 1000.0 + pos.z * 7919.0)) % 8
	var mesh := birch_mesh(hsh % 2) if hsh >= 6 else oak_mesh(hsh % 4)
	place(parent, mesh, pos, s * (0.9 + 0.05 * (hsh % 4)), float(hsh) * 0.8)


static func pine(parent: Node3D, pos: Vector3, s: float) -> void:
	var hsh := int(absf(pos.x * 1000.0 + pos.z * 7919.0)) % 4
	place(parent, spruce_mesh(hsh % 2), pos, s * (0.95 + 0.08 * hsh), float(hsh))


## Haus: Steinsockel, verputzte Wände (warme Töne), steiles Ziegeldach mit Überstand, Fenster, Kamin.
static func house_mesh(variant: int) -> Mesh:
	var key := "house%d" % variant
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var walls := [Color("#e4d8c2"), Color("#d8c3a0"), Color("#ece5d8"), Color("#cdb79a")]
	var roofs := [Color("#8e4430"), Color("#a5573b"), Color("#5b5550"), Color("#7a3e2e")]
	var wall: Color = walls[variant % 4]
	var roofc: Color = roofs[variant % 4]
	var w := 0.12
	var d := 0.09
	var h := 0.085
	_box(st, Vector3(0, 0.006, 0), Vector3(w + 0.008, 0.012, d + 0.008), Color("#6f6a62"))
	_box(st, Vector3(0, 0.012 + h * 0.5, 0), Vector3(w, h, d), wall)
	# Dach: zwei Flächen, Überstand, First entlang x
	var rh := 0.065
	var ov := 0.012
	var y0 := 0.012 + h
	var a := Vector3(-w * 0.5 - ov, y0 - 0.006, -d * 0.5 - ov)
	var b := Vector3(w * 0.5 + ov, y0 - 0.006, -d * 0.5 - ov)
	var c := Vector3(w * 0.5 + ov, y0 + rh, 0)
	var e := Vector3(-w * 0.5 - ov, y0 + rh, 0)
	_quadc(st, a, b, c, e, roofc * 0.85, Vector3(0, 1, -0.8))
	var a2 := Vector3(-w * 0.5 - ov, y0 - 0.006, d * 0.5 + ov)
	var b2 := Vector3(w * 0.5 + ov, y0 - 0.006, d * 0.5 + ov)
	_quadc(st, b2, a2, e, c, roofc, Vector3(0, 1, 0.8))
	# Giebel
	_tric(st, Vector3(-w * 0.5, y0, -d * 0.5), Vector3(-w * 0.5, y0 + rh - 0.004, 0), Vector3(-w * 0.5, y0, d * 0.5), wall * 0.95, Vector3.LEFT)
	_tric(st, Vector3(w * 0.5, y0, d * 0.5), Vector3(w * 0.5, y0 + rh - 0.004, 0), Vector3(w * 0.5, y0, -d * 0.5), wall * 0.95, Vector3.RIGHT)
	# Kamin
	_box(st, Vector3(w * 0.25, y0 + rh * 0.8, -d * 0.18), Vector3(0.014, 0.04, 0.014), Color("#7b4b3a"))
	# Fenster und Tür (vorn +z), Fenster Seite
	var glass := Color("#2b3540")
	for wx in [-0.035, 0.035]:
		_box(st, Vector3(wx, 0.012 + h * 0.62, d * 0.5 + 0.001), Vector3(0.018, 0.022, 0.003), glass)
		_box(st, Vector3(wx, 0.012 + h * 0.62 - 0.013, d * 0.5 + 0.002), Vector3(0.022, 0.003, 0.005), Color("#f2eee6"))
	_box(st, Vector3(0.0, 0.012 + 0.022, d * 0.5 + 0.001), Vector3(0.018, 0.044, 0.003), Color("#5a3d28"))
	_box(st, Vector3(w * 0.5 + 0.001, 0.012 + h * 0.6, 0.0), Vector3(0.003, 0.022, 0.018), glass)
	_box(st, Vector3(-w * 0.5 - 0.001, 0.012 + h * 0.6, 0.0), Vector3(0.003, 0.022, 0.018), glass)
	return _finish(key, st)


static func _tric(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, out: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot(out) < 0.0:
		n = -n
	_emit(st, [a, b, c], [n, n, n], [col, col, col], out)


static func _quadc(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, out: Vector3) -> void:
	_tric(st, a, b, c, col, out)
	_tric(st, a, c, d, col, out)


static func _box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:
	var h := s * 0.5
	var v := [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1),
		Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]
	var faces := [[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5], [3, 7, 6, 2], [0, 1, 5, 4]]
	var shade := [0.85, 0.95, 0.88, 0.9, 1.05, 0.6]
	for fi in faces.size():
		var f: Array = faces[fi]
		var p: Array = []
		for idx in f:
			var vv: Vector3 = v[idx]
			p.append(c + vv * h)
		var ctr: Vector3 = (p[0] + p[1] + p[2] + p[3]) * 0.25
		_quadc(st, p[0], p[1], p[2], p[3], col * float(shade[fi]), ctr - c)


static func house(parent: Node3D, pos: Vector3, s: float, rot: float) -> void:
	var hsh := int(absf(pos.x * 1000.0 + pos.z * 7919.0)) % 4
	var mi := place(parent, house_mesh(hsh), pos, s, deg_to_rad(rot), false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Mensch: schlanker, realistischere Proportionen (etwas größer als maßstäblich, damit lesbar)
static func person_mesh(variant: int) -> Mesh:
	var key := "person%d" % variant
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shirts := [Color("#7a5c43"), Color("#4f5f6f"), Color("#8a3f34"), Color("#6b7146"), Color("#d8d0bd")]
	var legs := Color("#3a3530")
	var skin := Color("#d9a982")
	var sh: Color = shirts[variant % 5]
	_box(st, Vector3(-0.004, 0.012, 0), Vector3(0.006, 0.024, 0.007), legs)
	_box(st, Vector3(0.004, 0.012, 0), Vector3(0.006, 0.024, 0.007), legs)
	_box(st, Vector3(0, 0.035, 0), Vector3(0.016, 0.024, 0.01), sh)
	_box(st, Vector3(0, 0.052, 0), Vector3(0.009, 0.01, 0.009), skin)
	_box(st, Vector3(0, 0.058, -0.0005), Vector3(0.0095, 0.004, 0.0095), Color("#3b2a1f"))
	return _finish(key, st)


static func person(parent: Node3D, pos: Vector3, variant: int) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	place(n, person_mesh(variant), Vector3.ZERO, 1.0, float(variant) * 1.3, false)
	return n
