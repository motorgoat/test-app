class_name Models
extends RefCounted
## Prozedurale Modelle (docs/GDPD_GRAFIK.md, Teil B): natürlich-schlicht statt Spielzeug.
## Jedes Modell ist EIN Mesh mit Vertexfarben je Material (Holz/Putz/Stein „solid“, Laub „leaf“, Gras „grass“,
## Fenster „warm“/„faith“, Glas „glass“), je Variante einmal gebaut und zwischengespeichert.
## Tiere und Menschen haben Animations-Teile im UV (x = Teil, y = Hüfthöhe) und den Drehpunkt im UV2;
## shaders/creature.gdshader bewegt Beine, Kopf, Arme und Oberkörper (keine Skelette).
## Die alten Grundformen (rbox, box, cyl, sphere, mat, …) bleiben für Hinweise und Effekte.

const WHITE := Color("#fffaf2")
const WOOD := Color("#6a4a30")
const DARK := Color("#3a3029")
const GOLD := Color("#ffd75e")
const FAITH := Color("#8b6ee0")

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}
static var _arrays: Dictionary = {}     # Mesh-Arrays eigener Meshes (für batched() und den Feld-Baker, ohne RenderingServer)
static var _models: Dictionary = {}     # "name|variant" -> Array [[Mesh, matkind], …]
static var _ico: Dictionary = {}


# =============================================================================
# Materialien
# =============================================================================

static func mat(color: Color, rough: float = 0.5, emission: float = 0.0, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(true), rough, emission, metallic]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	m.metallic_specular = 0.45
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_mats[key] = m
	return m


static func unshaded(color: Color) -> StandardMaterial3D:
	var key := "u|%s" % color.to_html(true)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


## Material je Teil-Art eines Modells.
static func material(kind: String) -> Material:
	if kind == "leaf" or kind == "grass":
		return Look.foliage(Color.WHITE, true)
	var key := "mk|%s|%d" % [kind, Look.quality]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match kind:
		"warm", "faith":
			m.albedo_color = Color("#ffc27a") if kind == "warm" else Color("#d7a8ff")
			m.emission_enabled = true
			m.emission = Color("#ffb766") if kind == "warm" else Color("#b98aff")
			m.emission_energy_multiplier = 1.25 if kind == "warm" else 1.6
			m.roughness = 0.4
		"glass":
			m.vertex_color_use_as_albedo = true
			m.roughness = 0.2
			m.metallic = 0.25
			m.metallic_specular = 0.8
			m.rim_enabled = true
			m.rim = 0.55
			m.rim_tint = 0.2
		_:
			m.vertex_color_use_as_albedo = true
			m.roughness = 0.86
			m.metallic_specular = 0.3
			if Look.quality >= 1:
				m.albedo_texture = Look.detail()
				m.uv1_triplanar = true
				m.uv1_scale = Vector3(11, 11, 11)
	_mats[key] = m
	return m


## Material für ein Tier oder einen Menschen (je Figur eines: Gehen, Grasen, Bücken unterscheiden sich).
static func creature_material(phase: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Look._shader("res://shaders/creature.gdshader")
	m.set_shader_parameter("phase", phase)
	return m


## Flamme (Billboard längs der Feld-Normalen, Rauschen im Shader).
static func flame_material(seed: float) -> ShaderMaterial:
	var key := "flame|%.2f" % seed
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = Look._shader("res://shaders/flame.gdshader")
	m.set_shader_parameter("n_fbm", Look.fbm())
	m.set_shader_parameter("seed", seed)
	_mats[key] = m
	return m


static func glow2s(color: Color) -> StandardMaterial3D:
	var key := "g2|%s" % color.to_html(true)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


# =============================================================================
# Alte Grundformen (Hinweise, Effekte, Würfelkörper)
# =============================================================================

static func _samples(h: float, r: float, k: int) -> Array:
	var out: Array = []
	for i in k + 1:
		var t := float(i) / float(k)
		out.append(-h + r - r * cos(t * PI * 0.5))
	for i in range(k, -1, -1):
		var t := float(i) / float(k)
		out.append(h - r + r * cos(t * PI * 0.5))
	return out


static func rounded_box_mesh(size: Vector3, radius: float, steps: int = 3) -> Mesh:
	var key := "rbox|%s|%.3f|%d" % [size, radius, steps]
	if _meshes.has(key):
		return _meshes[key]
	var h := size * 0.5
	var r := minf(radius, minf(h.x, minf(h.y, h.z)) - 0.0005)
	var inner_max := h - Vector3(r, r, r)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		for s in [-1, 1]:
			var ua := (axis + 1) % 3
			var va := (axis + 2) % 3
			var us := _samples(h[ua], r, steps)
			var vs := _samples(h[va], r, steps)
			var out_n := Vector3.ZERO
			out_n[axis] = float(s)
			var pos: Array = []
			var nrm: Array = []
			for i in us.size():
				var prow: Array = []
				var nrow: Array = []
				for j in vs.size():
					var raw := Vector3.ZERO
					raw[axis] = s * h[axis]
					raw[ua] = us[i]
					raw[va] = vs[j]
					var inner := raw.clamp(-inner_max, inner_max)
					var dir := raw - inner
					var nv := out_n
					if dir.length() > 0.00001:
						nv = dir.normalized()
					prow.append(inner + nv * r)
					nrow.append(nv)
				pos.append(prow)
				nrm.append(nrow)
			for i in us.size() - 1:
				for j in vs.size() - 1:
					_quad(st, pos[i][j], pos[i + 1][j], pos[i + 1][j + 1], pos[i][j + 1],
						nrm[i][j], nrm[i + 1][j], nrm[i + 1][j + 1], nrm[i][j + 1], out_n)
	var arrays := st.commit_to_arrays()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[key] = mesh
	_arrays[mesh.get_instance_id()] = arrays
	return mesh


## Feld-Platte (nahtlos): Oberseite reicht an den Fugen genau bis an den Nachbarn (±0,5 plus 0,002 Überlappung),
## an Würfelkanten (outer: 1 = -z, 2 = +x, 4 = +z, 8 = -x) bis 0,56 und biegt dort als Viertel einer abgerundeten
## Würfelkante nach unten (Gehrung auf 45°: die Platte der Nachbarseite schließt lückenlos an).
## Koordinaten wie FieldView: y = 0 liegt 0,47 über der Würfelstein-Mitte, Oberseite bei top.
## UV = flache Lage (x, z) vor dem Biegen (die Nachbarseite sieht an der Kante dieselben Werte), UV2.x = 1 Oberseite.
## Fugen-Wände (Erdschichten) gibt es nur an den Fugen; dort sieht man sie beim Drehen.
const SLAB_TOP := 0.09
const SLAB_BASE := 0.47          # Abstand der Feld-Ebene (y = 0) von der Würfelstein-Mitte
const SLAB_EDGE := 0.56          # Würfelkante (flach)
const SLAB_R := 0.034            # Rundung der Würfelkante
const SLAB_SEAM := 0.502         # Fuge (leicht überlappend: keine Haarrisse)


static func slab_mesh(outer: int) -> Mesh:
	var key := "slab|%d" % outer
	if _meshes.has(key):
		return _meshes[key]
	var on := (outer & 1) != 0
	var oe := (outer & 2) != 0
	var os := (outer & 4) != 0
	var ow := (outer & 8) != 0
	var xs := _slab_samples(ow, oe)
	var zs := _slab_samples(on, os)
	var h := SLAB_EDGE - SLAB_R
	var lo := Vector3(-h if ow else -100.0, -100.0, -h if on else -100.0)
	var hi := Vector3(h if oe else 100.0, SLAB_TOP - SLAB_R, h if os else 100.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pos: Array = []
	var nrm: Array = []
	for i in xs.size():
		var prow: Array = []
		var nrow: Array = []
		for j in zs.size():
			var flat := Vector3(float(xs[i]), SLAB_TOP, float(zs[j]))
			var q := flat.clamp(lo, hi)
			var d := flat - q
			var nv := d.normalized()
			prow.append(q + nv * SLAB_R)
			nrow.append(nv)
		pos.append(prow)
		nrm.append(nrow)
	for i in xs.size() - 1:
		for j in zs.size() - 1:
			var a: Vector3 = pos[i][j]
			var b: Vector3 = pos[i + 1][j]
			var c: Vector3 = pos[i + 1][j + 1]
			var dd: Vector3 = pos[i][j + 1]
			var fa := Vector2(float(xs[i]), float(zs[j]))
			var fb := Vector2(float(xs[i + 1]), float(zs[j]))
			var fc := Vector2(float(xs[i + 1]), float(zs[j + 1]))
			var fd := Vector2(float(xs[i]), float(zs[j + 1]))
			_slab_tri(st, [a, b, c], [nrm[i][j], nrm[i + 1][j], nrm[i + 1][j + 1]], [fa, fb, fc], 1.0, Vector3.UP)
			_slab_tri(st, [a, c, dd], [nrm[i][j], nrm[i + 1][j + 1], nrm[i][j + 1]], [fa, fc, fd], 1.0, Vector3.UP)
	# Fugen-Wände: vom Rand der Oberseite senkrecht hinunter bis in den Würfelstein (an Würfelkanten auf Gehrung)
	var bottom := -0.03
	var miter := bottom + SLAB_BASE
	var last_i := xs.size() - 1
	var last_j := zs.size() - 1
	var sides := [[not on, 0, Vector3(0, 0, -1)], [not oe, 1, Vector3(1, 0, 0)], [not os, 2, Vector3(0, 0, 1)], [not ow, 3, Vector3(-1, 0, 0)]]
	for sd in sides:
		if not bool(sd[0]):
			continue
		var side: int = sd[1]
		var out_n: Vector3 = sd[2]
		var edge_top: Array = []
		var edge_flat: Array = []
		if side == 0 or side == 2:
			var jj := 0 if side == 0 else last_j
			for i in xs.size():
				edge_top.append(pos[i][jj])
				edge_flat.append(Vector2(float(xs[i]), float(zs[jj])))
		else:
			var ii := last_i if side == 1 else 0
			for j in zs.size():
				edge_top.append(pos[ii][j])
				edge_flat.append(Vector2(float(xs[ii]), float(zs[j])))
		for k in edge_top.size() - 1:
			var t0: Vector3 = edge_top[k]
			var t1: Vector3 = edge_top[k + 1]
			var b0 := Vector3(t0.x, bottom, t0.z)
			var b1 := Vector3(t1.x, bottom, t1.z)
			if side == 0 or side == 2:
				b0.x = clampf(b0.x, -miter if ow else -9.0, miter if oe else 9.0)
				b1.x = clampf(b1.x, -miter if ow else -9.0, miter if oe else 9.0)
			else:
				b0.z = clampf(b0.z, -miter if on else -9.0, miter if os else 9.0)
				b1.z = clampf(b1.z, -miter if on else -9.0, miter if os else 9.0)
			var f0: Vector2 = edge_flat[k]
			var f1: Vector2 = edge_flat[k + 1]
			_slab_tri(st, [t0, t1, b1], [out_n, out_n, out_n], [f0, f1, f1], 0.0, out_n)
			_slab_tri(st, [t0, b1, b0], [out_n, out_n, out_n], [f0, f1, f0], 0.0, out_n)
	var arrays := st.commit_to_arrays()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[key] = mesh
	_arrays[mesh.get_instance_id()] = arrays
	return mesh


static func _slab_samples(out_lo: bool, out_hi: bool) -> Array:
	var h := SLAB_EDGE - SLAB_R
	var out: Array = []
	if out_lo:
		for k in range(4, 0, -1):
			out.append(-h - SLAB_R * float(k) / 4.0)
		out.append(-h)
	else:
		out.append(-SLAB_SEAM)
	for v in [-0.3, -0.1, 0.1, 0.3]:
		out.append(v)
	if out_hi:
		out.append(h)
		for k in range(1, 5):
			out.append(h + SLAB_R * float(k) / 4.0)
	else:
		out.append(SLAB_SEAM)
	return out


static func _slab_tri(st: SurfaceTool, p: Array, n: Array, f: Array, top: float, out_n: Vector3) -> void:
	var a: Vector3 = p[0]
	var b: Vector3 = p[1]
	var c: Vector3 = p[2]
	var cross := (b - a).cross(c - a)
	if cross.length_squared() < 1e-14:
		return
	var order := [0, 2, 1] if cross.dot(out_n if top < 0.5 else (n[0] as Vector3) + (n[1] as Vector3) + (n[2] as Vector3)) > 0.0 else [0, 1, 2]
	for k in order:
		st.set_normal(n[k])
		st.set_uv(f[k])
		st.set_uv2(Vector2(top, 0.0))
		st.add_vertex(p[k])


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3, out_n: Vector3) -> void:
	_tri(st, a, b, c, na, nb, nc, out_n)
	_tri(st, a, c, d, na, nc, nd, out_n)


## Godot zeichnet Dreiecke im Uhrzeigersinn (von vorne gesehen) als Vorderseite.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, out_n: Vector3) -> void:
	var cross := (b - a).cross(c - a)
	if cross.length_squared() < 1e-12:
		return
	if cross.dot(out_n) > 0.0:
		st.set_normal(na)
		st.add_vertex(a)
		st.set_normal(nc)
		st.add_vertex(c)
		st.set_normal(nb)
		st.add_vertex(b)
	else:
		st.set_normal(na)
		st.add_vertex(a)
		st.set_normal(nb)
		st.add_vertex(b)
		st.set_normal(nc)
		st.add_vertex(c)


static func _add(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func rbox(parent: Node3D, size: Vector3, radius: float, color: Color, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, material: Material = null) -> MeshInstance3D:
	return _add(parent, rounded_box_mesh(size, radius), material if material != null else mat(color), pos, rot_deg)


static func box(parent: Node3D, size: Vector3, color: Color, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, material: Material = null) -> MeshInstance3D:
	var key := "box|%s" % size
	if not _meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[key] = bm
	return _add(parent, _meshes[key], material if material != null else mat(color), pos, rot_deg)


static func cyl_mesh(r_top: float, r_bot: float, h: float, sides: int = 12) -> Mesh:
	var key := "cyl|%.3f|%.3f|%.3f|%d" % [r_top, r_bot, h, sides]
	if not _meshes.has(key):
		var cm := CylinderMesh.new()
		cm.top_radius = r_top
		cm.bottom_radius = r_bot
		cm.height = h
		cm.radial_segments = sides
		cm.rings = 1
		_meshes[key] = cm
	return _meshes[key]


## Zylinder/Kegel, pos = Mitte der Grundfläche.
static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, color: Color, pos: Vector3, sides: int = 12, rot_deg: Vector3 = Vector3.ZERO, material: Material = null) -> MeshInstance3D:
	var mi := _add(parent, cyl_mesh(r_top, r_bot, h, sides), material if material != null else mat(color), pos, rot_deg)
	mi.position = pos + mi.basis.y * (h * 0.5)
	return mi


static func sphere_mesh(r: float, segments: int = 16, rings: int = 8) -> Mesh:
	var key := "sph|%.3f|%d|%d" % [r, segments, rings]
	if not _meshes.has(key):
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = segments
		sm.rings = rings
		_meshes[key] = sm
	return _meshes[key]


static func sphere(parent: Node3D, r: float, color: Color, pos: Vector3, material: Material = null, squash: float = 1.0) -> MeshInstance3D:
	var mi := _add(parent, sphere_mesh(r), material if material != null else mat(color), pos)
	if squash != 1.0:
		mi.scale = Vector3(1.0, squash, 1.0)
	return mi


static func add_mesh(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _add(parent, mesh, material, pos)


## Viele Kopien einer Grundform als EIN Mesh (ein Draw-Call), unter key zwischengespeichert.
static func batched(key: String, base: Mesh, xforms: Array) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var src := arrays_of(base)
	var bv: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var bn: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var bi: PackedInt32Array = PackedInt32Array()
	if src[Mesh.ARRAY_INDEX] != null:
		bi = src[Mesh.ARRAY_INDEX]
	if bi.is_empty():
		for i in bv.size():
			bi.append(i)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for t in xforms:
		var xf: Transform3D = t
		var nb := xf.basis.inverse().transposed()
		var off := verts.size()
		for v in bv:
			verts.append(xf * v)
		for nv in bn:
			norms.append((nb * nv).normalized())
		for i in bi:
			idx.append(off + i)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[key] = m
	_arrays[m.get_instance_id()] = arrays
	return m


## Mesh-Arrays (auch headless): eigene Meshes aus dem Speicher, Grundformen aus get_mesh_arrays().
static func arrays_of(mesh: Mesh) -> Array:
	if _arrays.has(mesh.get_instance_id()):
		return _arrays[mesh.get_instance_id()]
	if mesh is PrimitiveMesh:
		var a := (mesh as PrimitiveMesh).get_mesh_arrays()
		_arrays[mesh.get_instance_id()] = a
		return a
	return mesh.surface_get_arrays(0)


static func _tri_auto(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out_n: Vector3) -> void:
	var nrm := (b - a).cross(c - a)
	if nrm.dot(out_n) > 0.0:
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)


## Flacher, facettierter Stern (liegt in x/z, Spitze oben), Grundfläche bei y = 0.
static func star_mesh(r: float, h: float) -> Mesh:
	var key := "star|%.3f|%.3f" % [r, h]
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array = []
	for i in 10:
		var a := -PI * 0.5 + TAU * float(i) / 10.0
		var rr := r if i % 2 == 0 else r * 0.45
		ring.append(Vector3(cos(a) * rr, h * 0.35, sin(a) * rr))
	var top := Vector3(0, h, 0)
	for i in 10:
		var p0: Vector3 = ring[i]
		var p1: Vector3 = ring[(i + 1) % 10]
		_tri_auto(st, top, p0, p1, Vector3.UP)
		var mid := (p0 + p1) * 0.5
		var side := Vector3(mid.x, 0, mid.z).normalized()
		var b0 := Vector3(p0.x, 0, p0.z)
		var b1 := Vector3(p1.x, 0, p1.z)
		_tri_auto(st, p0, b0, b1, side)
		_tri_auto(st, p0, b1, p1, side)
	st.generate_normals()
	var m := st.commit()
	_meshes[key] = m
	return m


## Ein Blitzstrahl aus Zickzack-Stücken, von oben (y = h) bis y = 0.
static func bolt(parent: Node3D, h: float) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var m := mat(Color("#fff3a0"), 0.3, 4.0)
	var pts: Array = [Vector3(0, h, 0)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var steps := 6
	for i in range(1, steps):
		var t := float(i) / float(steps)
		pts.append(Vector3(rng.randf_range(-0.12, 0.12), h * (1.0 - t), rng.randf_range(-0.06, 0.06)))
	pts.append(Vector3.ZERO)
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var seg := MeshInstance3D.new()
		seg.mesh = cyl_mesh(0.022, 0.022, 1.0, 5)
		seg.material_override = m
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var d := b - a
		var up := d.normalized()
		var side := up.cross(Vector3(0, 0, 1))
		if side.length() < 0.01:
			side = Vector3(1, 0, 0)
		side = side.normalized()
		var fwd := side.cross(up).normalized()
		seg.transform = Transform3D(Basis(side, up * d.length(), fwd), (a + b) * 0.5)
		n.add_child(seg)
	return n


## Flammen als Billboards (Shader): count Zungen um pos, Größe s. Gibt den Knoten zurück.
static func flame(parent: Node3D, pos: Vector3, s: float, count: int = 3, seed: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	for k in count:
		var mi := MeshInstance3D.new()
		mi.mesh = flame_quad()
		mi.material_override = flame_material(fmod(seed + k * 0.37, 1.0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * float(k) / float(maxi(count, 1)) + seed * 5.0
		var r := 0.0 if k == 0 else 0.022 * s
		mi.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		var sc := s * (1.0 if k == 0 else 0.72)
		mi.scale = Vector3(sc, sc, sc)
		n.add_child(mi)
	return n


## Quad für Flammen: Fuß bei y = 0, Breite 0,07, Höhe 0,14 (wird im Shader zur Kamera gedreht).
static func flame_quad() -> Mesh:
	if _meshes.has("flame_quad"):
		return _meshes["flame_quad"]
	var q := QuadMesh.new()
	q.size = Vector2(0.1, 0.17)
	q.center_offset = Vector3(0, 0.085, 0)
	_meshes["flame_quad"] = q
	return q


# =============================================================================
# Mesh-Bauer mit Vertexfarben (Farben werden linear gespeichert; COLOR.a = Wind-Gewicht)
# =============================================================================

class MB:
	extends RefCounted
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var u := PackedVector2Array()
	var u2 := PackedVector2Array()
	var xf := Transform3D.IDENTITY
	var nb := Basis.IDENTITY
	var part := 0.0           # Animations-Teil (creature.gdshader)
	var hip := 0.0            # Hüfthöhe (Bücken)
	var pivot := Vector2.ZERO # Drehpunkt in x/y (Beine, Kopf, Arme)
	var wind := 0.0           # Wind-Gewicht für Laub/Gras (COLOR.a)
	var _stack: Array = []

	func at(t: Transform3D) -> MB:
		xf = t
		nb = t.basis.inverse().transposed()
		return self

	func push(t: Transform3D) -> void:
		_stack.append(xf)
		at(xf * t)

	func pop() -> void:
		at(_stack.pop_back())

	func vert(p: Vector3, nn: Vector3, col: Color, w: float = -1.0) -> void:
		v.append(xf * p)
		n.append((nb * nn).normalized())
		# sRGB -> linear mit etwas flacherer Kurve: dunkle Töne bleiben im ACES-Licht lesbar (Dächer, Nadelbäume)
		c.append(Color(pow(col.r, 1.75), pow(col.g, 1.75), pow(col.b, 1.75), wind if w < 0.0 else w))
		u.append(Vector2(part, hip))
		u2.append(pivot)

	## Dreieck; out = ungefähre Außenrichtung (die Reihenfolge wird danach gedreht).
	func tri(a: Vector3, b: Vector3, d: Vector3, col: Color, out: Vector3 = Vector3.ZERO) -> void:
		var nn := (b - a).cross(d - a)
		if nn.length_squared() < 1e-16:
			return
		if out != Vector3.ZERO and nn.dot(out) < 0.0:
			var t := b
			b = d
			d = t
			nn = -nn
		nn = nn.normalized()
		vert(a, nn, col)
		vert(d, nn, col)
		vert(b, nn, col)

	## Dreieck mit eigenen Normalen und Farben je Ecke.
	func tri_s(a: Vector3, b: Vector3, d: Vector3, na: Vector3, nbb: Vector3, nd: Vector3, ca: Color, cb: Color, cd: Color, out: Vector3) -> void:
		var nn := (b - a).cross(d - a)
		if nn.length_squared() < 1e-16:
			return
		if nn.dot(out) < 0.0:
			vert(a, na, ca)
			vert(b, nbb, cb)
			vert(d, nd, cd)
		else:
			vert(a, na, ca)
			vert(d, nd, cd)
			vert(b, nbb, cb)

	func quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, col: Color, out: Vector3) -> void:
		tri(a, b, cc, col, out)
		tri(a, cc, d, col, out)

	## Quader (ohne Boden, außer bottom). top: eigene Farbe für die Oberseite (a = 0: wie col).
	func box(ctr: Vector3, size: Vector3, col: Color, top: Color = Color(0, 0, 0, 0), bottom: bool = false) -> void:
		var h := size * 0.5
		var tc := col if top.a == 0.0 else top
		for ax in 3:
			for s_v in [-1.0, 1.0]:
				var s: float = s_v
				if ax == 1 and s < 0.0 and not bottom:
					continue
				var on := Vector3.ZERO
				on[ax] = s
				var ua := (ax + 1) % 3
				var va := (ax + 2) % 3
				var pts: Array = []
				for k in 4:
					var p := Vector3.ZERO
					p[ax] = s * h[ax]
					p[ua] = (-1.0 if k == 0 or k == 3 else 1.0) * h[ua]
					p[va] = (-1.0 if k < 2 else 1.0) * h[va]
					pts.append(ctr + p)
				var fc := col
				if ax == 1 and s > 0.0:
					fc = tc
				elif ax == 0:
					fc = col.darkened(0.04)
				quad(pts[0], pts[1], pts[2], pts[3], fc, on)

	## Zylinder/Kegelstumpf (glatte Seiten) von base nach oben.
	func cyl(base: Vector3, r0: float, r1: float, h: float, sides: int, col0: Color, col1: Color, cap: bool = true, ang0: float = 0.0) -> void:
		var up := Vector3.UP
		var slope := (r0 - r1) / maxf(h, 0.0001)
		for i in sides:
			var a0 := ang0 + TAU * float(i) / float(sides)
			var a1 := ang0 + TAU * float(i + 1) / float(sides)
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var n0 := (d0 + up * slope).normalized()
			var n1 := (d1 + up * slope).normalized()
			var p00 := base + d0 * r0
			var p01 := base + d1 * r0
			var p10 := base + d0 * r1 + up * h
			var p11 := base + d1 * r1 + up * h
			tri_s(p00, p01, p11, n0, n1, n1, col0, col0, col1, d0 + d1)
			tri_s(p00, p11, p10, n0, n1, n0, col0, col1, col1, d0 + d1)
			if cap and r1 > 0.0005:
				tri(base + up * h, p10, p11, col1, up)

	## Zylinder zwischen zwei Punkten (Äste, Rohre, Stangen).
	func rod(a: Vector3, b: Vector3, r0: float, r1: float, sides: int, col0: Color, col1: Color) -> void:
		var d := b - a
		var l := d.length()
		if l < 1e-5:
			return
		var y := d / l
		var x := y.cross(Vector3(0, 0, 1))
		if x.length() < 0.1:
			x = y.cross(Vector3(1, 0, 0))
		x = x.normalized()
		var z := x.cross(y).normalized()
		push(Transform3D(Basis(x, y, z), a))
		cyl(Vector3.ZERO, r0, r1, l, sides, col0, col1, true)
		pop()

	## Verbeulte Kugel (Ikosaeder): Laubkronen (smooth) und Steine (facettiert).
	func blob(ctr: Vector3, rad: Vector3, seed: float, lo: Color, hi: Color, jit: float = 0.22, smooth: bool = true,
			ncenter: Vector3 = Vector3(INF, 0, 0), sub: int = 1, flat_bottom: float = -2.0) -> void:
		var ico: Array = Models.ico(sub)
		var verts: Array = ico[0]
		var faces: PackedInt32Array = ico[1]
		var pos: Array = []
		var nrm: Array = []
		var col: Array = []
		var nc := ctr if ncenter.x == INF else ncenter
		for dv in verts:
			var d: Vector3 = dv
			var k := 1.0 + jit * (Models.hash3(d * 3.1 + Vector3(seed, seed * 0.7, seed * 1.3)) - 0.5) * 2.0
			var dd := d
			if dd.y < flat_bottom:
				dd.y = flat_bottom + (dd.y - flat_bottom) * 0.15
			var p := ctr + Vector3(dd.x * rad.x, dd.y * rad.y, dd.z * rad.z) * k
			pos.append(p)
			var nr := (p - nc).normalized()
			nrm.append((nr * 0.65 + d * 0.35).normalized())
			var t := clampf(0.42 + 0.55 * d.y + 0.35 * (Models.hash3(d * 7.7 + Vector3(seed, 1.0, 0.0)) - 0.5), 0.0, 1.0)
			col.append(lo.lerp(hi, t))
		for i in range(0, faces.size(), 3):
			var ia := faces[i]
			var ib := faces[i + 1]
			var ic := faces[i + 2]
			var pa: Vector3 = pos[ia]
			var pb: Vector3 = pos[ib]
			var pc: Vector3 = pos[ic]
			var out := (pa + pb + pc) / 3.0 - ctr
			if smooth:
				tri_s(pa, pb, pc, nrm[ia], nrm[ib], nrm[ic], col[ia], col[ib], col[ic], out)
			else:
				var cavg: Color = (col[ia] as Color).lerp(col[ib], 0.5).lerp(col[ic], 0.33)
				tri(pa, pb, pc, cavg, out)

	## Gezackter Kegel (eine Etage einer Fichte). Spitzen hängen leicht nach unten.
	func spiky_cone(base: Vector3, r: float, h: float, sides: int, lo: Color, hi: Color, seed: float, jag: float = 0.38) -> void:
		var up := Vector3.UP
		var tip := base + up * h
		var ring: Array = []
		var cnt := sides * 2
		for i in cnt:
			var a := TAU * float(i) / float(cnt) + seed
			var rr := r * (1.0 if i % 2 == 0 else 1.0 - jag) * (0.9 + 0.2 * Models.hash3(Vector3(seed, i, 2.0)))
			var dy := -0.07 * h if i % 2 == 0 else 0.05 * h
			ring.append(base + Vector3(cos(a) * rr, dy, sin(a) * rr))
		var inner := base + up * (h * 0.18)
		for i in cnt:
			var p0: Vector3 = ring[i]
			var p1: Vector3 = ring[(i + 1) % cnt]
			var r0 := Vector3(p0.x - base.x, 0, p0.z - base.z).normalized()
			var r1 := Vector3(p1.x - base.x, 0, p1.z - base.z).normalized()
			var n0 := (r0 * h + up * r * 0.8).normalized()
			var n1 := (r1 * h + up * r * 0.8).normalized()
			var c0 := lo if i % 2 == 1 else lo.lerp(hi, 0.35)
			var c1 := lo if (i + 1) % 2 == 1 else lo.lerp(hi, 0.35)
			tri_s(tip, p0, p1, up, n0, n1, hi, c0, c1, (p0 + p1) * 0.5 - base + up * r)
			tri(inner, p1, p0, lo.darkened(0.45), -up)

	## Grasbüschel: dünne, beidseitige Halme. Fuß ohne Wind, Spitze mit Wind.
	func tuft(p: Vector3, h: float, blades: int, seed: float, lo: Color, hi: Color, spread: float = 0.01, wdt: float = 0.0035) -> void:
		for i in blades:
			var a := seed * 13.0 + float(i) * 2.39996
			var lean := Vector3(cos(a), 0, sin(a))
			var rnd := Models.hash3(Vector3(seed, float(i), 1.0))
			var bh := h * (0.6 + 0.6 * rnd)
			var b0 := p + lean * spread * rnd
			var side := Vector3(-lean.z, 0, lean.x) * wdt
			var tip := b0 + lean * bh * (0.12 + 0.22 * rnd) + Vector3(0, bh, 0)
			var nn := (Vector3.UP * 0.8 + lean * 0.4).normalized()
			var ct := lo.lerp(hi, 0.6 + 0.4 * rnd)
			vert(b0 - side, nn, lo, 0.0)
			vert(tip, nn, ct, 1.0)
			vert(b0 + side, nn, lo, 0.0)
			vert(b0 - side, nn, lo, 0.0)
			vert(b0 + side, nn, lo, 0.0)
			vert(tip, nn, ct, 1.0)

	## Kleines Achteck-Kügelchen (Blüte, Beere, Kiesel).
	func bead(p: Vector3, r: float, col: Color, squash: float = 1.0) -> void:
		var pts := [Vector3(r, 0, 0), Vector3(0, 0, r), Vector3(-r, 0, 0), Vector3(0, 0, -r)]
		var top := p + Vector3(0, r * squash, 0)
		var bot := p - Vector3(0, r * squash * 0.6, 0)
		for i in 4:
			var a: Vector3 = p + (pts[i] as Vector3)
			var b: Vector3 = p + (pts[(i + 1) % 4] as Vector3)
			tri(top, a, b, col, (a + b) * 0.5 - p + Vector3.UP * r)
			tri(bot, b, a, col.darkened(0.25), (a + b) * 0.5 - p - Vector3.UP * r)

	## Satteldach. ctr = Mitte auf Traufhöhe der Wand, First entlang x. w/d = Wandmaße.
	func gable(ctr: Vector3, w: float, d: float, h: float, over: float, col: Color, wall: Color, thick: float = 0.005) -> void:
		var hx := w * 0.5 + over
		var hz := d * 0.5 + over
		var ye := -over * h / (d * 0.5)
		var under := col.darkened(0.45)
		for s_v in [-1.0, 1.0]:
			var s: float = s_v
			var r0 := ctr + Vector3(-hx, h, 0)
			var r1 := ctr + Vector3(hx, h, 0)
			var e0 := ctr + Vector3(-hx, ye, s * hz)
			var e1 := ctr + Vector3(hx, ye, s * hz)
			var on := Vector3(0, d * 0.5, s * h)
			quad(r0, r1, e1, e0, col, on)
			var t := Vector3(0, -thick, 0)
			quad(r0 + t, r1 + t, e1 + t, e0 + t, under, -on)
			quad(e0, e1, e1 + t, e0 + t, col.darkened(0.25), Vector3(0, 0, s))
			for x_v in [-1.0, 1.0]:
				var x: float = x_v
				var ra := ctr + Vector3(x * hx, h, 0)
				var ea := ctr + Vector3(x * hx, ye, s * hz)
				quad(ra, ea, ea + t, ra + t, col.darkened(0.3), Vector3(x, 0, 0))
		# Giebelwände
		for x_v in [-1.0, 1.0]:
			var x: float = x_v
			tri(ctr + Vector3(x * w * 0.5, 0, -d * 0.5), ctr + Vector3(x * w * 0.5, 0, d * 0.5),
				ctr + Vector3(x * w * 0.5, h - thick * 1.5, 0), wall, Vector3(x, 0, 0))
		# First
		box(ctr + Vector3(0, h + 0.001, 0), Vector3(hx * 2.0 + 0.002, 0.004, 0.006), col.darkened(0.35))

	## Zeltdach / Turmhelm (vierseitig). ctr = Mitte auf Traufhöhe.
	func pyramid(ctr: Vector3, w: float, d: float, h: float, col: Color, over: float = 0.0) -> void:
		var hx := w * 0.5 + over
		var hz := d * 0.5 + over
		var apex := ctr + Vector3(0, h, 0)
		var cs := [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]
		for i in 4:
			var a: Vector3 = ctr + (cs[i] as Vector3)
			var b: Vector3 = ctr + (cs[(i + 1) % 4] as Vector3)
			var mid := (a + b) * 0.5 - ctr
			tri(apex, a, b, col.lightened(0.03 * float(i % 2)), mid + Vector3(0, h * 0.3, 0))
			tri(ctr - Vector3(0, 0.003, 0), b, a, col.darkened(0.4), Vector3.DOWN)

	## Fenster in einer Wand mit Normale +z (über push ausrichten). Rahmen hell, Glas dunkel.
	func window(ctr: Vector3, w: float, h: float, frame: Color, glass: Color, sill: bool = true) -> void:
		box(ctr + Vector3(0, 0, 0.0012), Vector3(w + 0.004, h + 0.004, 0.0024), frame, Color(0, 0, 0, 0), true)
		box(ctr + Vector3(0, 0, 0.0018), Vector3(w, h, 0.0024), glass, Color(0, 0, 0, 0), true)
		if sill:
			box(ctr + Vector3(0, -h * 0.5 - 0.002, 0.003), Vector3(w + 0.006, 0.0025, 0.006), frame.darkened(0.15))

	func commit() -> ArrayMesh:
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_TEX_UV] = u
		arr[Mesh.ARRAY_TEX_UV2] = u2
		var m := ArrayMesh.new()
		if v.size() > 0:
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		Models._arrays[m.get_instance_id()] = arr
		return m

	func empty() -> bool:
		return v.is_empty()


static func hash3(p: Vector3) -> float:
	return fposmod(sin(p.dot(Vector3(12.9898, 78.233, 37.719))) * 43758.5453, 1.0)


## Einheits-Ikosaeder, sub-mal unterteilt: [Array[Vector3], PackedInt32Array].
static func ico(sub: int) -> Array:
	if _ico.has(sub):
		return _ico[sub]
	var t := (1.0 + sqrt(5.0)) / 2.0
	var vs: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t),
		Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1),
		Vector3(-t, 0, 1)]
	for i in vs.size():
		vs[i] = (vs[i] as Vector3).normalized()
	var fs := PackedInt32Array([0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
		3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1])
	for _s in sub:
		var mid := {}
		var nf := PackedInt32Array()
		for i in range(0, fs.size(), 3):
			var a := fs[i]
			var b := fs[i + 1]
			var c := fs[i + 2]
			var ab := _ico_mid(vs, mid, a, b)
			var bc := _ico_mid(vs, mid, b, c)
			var ca := _ico_mid(vs, mid, c, a)
			nf.append_array(PackedInt32Array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca]))
		fs = nf
	_ico[sub] = [vs, fs]
	return _ico[sub]


static func _ico_mid(vs: Array, mid: Dictionary, a: int, b: int) -> int:
	var key := mini(a, b) * 100000 + maxi(a, b)
	if mid.has(key):
		return mid[key]
	vs.append(((vs[a] as Vector3) + (vs[b] as Vector3)).normalized())
	mid[key] = vs.size() - 1
	return vs.size() - 1


# =============================================================================
# Modell-Bibliothek: get(name, variant) -> [[Mesh, matkind], …] (zwischengespeichert)
# =============================================================================

## Farben (sRGB, GDPD_GRAFIK.md 2.1)
const BARK := Color("#5e4a36")
const BARK_D := Color("#45362a")
const PLASTER := [Color("#e4d8c2"), Color("#d8c3a0"), Color("#ece5d8"), Color("#cdb79a")]
const TILE_C := [Color("#7d3e30"), Color("#8a4a36"), Color("#6f3c32")]
const SLATE := Color("#7f7d80")
const STONE_C := Color("#8f8a80")
const STONE_L := Color("#a39d92")
const TIMBER := Color("#4a3426")
const GLASS_C := Color("#47525e")
const LOGS := Color("#b08a5e")
const LIT_C := Color("#f2cf86")          # ein helles (beleuchtetes) Fenster je Haus: Wohnhäuser lesen sich als bewohnt
const BRICK := Color("#9a6450")
const CONCRETE := Color("#8a857c")
const SOOT := Color("#3a3735")

## Laub-Paletten [unten/innen, oben/außen]
const LEAF_OAK := [Color("#34501f"), Color("#7c9842")]
const LEAF_BEECH := [Color("#3c5a24"), Color("#8ca64e")]
const LEAF_BIRCH := [Color("#4f6e2c"), Color("#afc262")]
const LEAF_SPRUCE := [Color("#26422a"), Color("#557a4c")]
const LEAF_PINE := [Color("#2e4a2c"), Color("#668850")]
const LEAF_DRY := [Color("#4a3a22"), Color("#93703c")]
const LEAF_BLOSSOM := [Color("#c48da0"), Color("#f4dde2")]


static func get_model(name: String, variant: int = 0) -> Array:
	var key := "%s|%d" % [name, variant]
	if _models.has(key):
		return _models[key]
	var parts := {"solid": MB.new(), "leaf": MB.new(), "grass": MB.new(), "warm": MB.new(), "faith": MB.new(), "glass": MB.new()}
	var seed := float(variant) * 7.31 + float(name.hash() % 1000) * 0.013
	match name:
		"oak":
			_tree_broad(parts, 0.21 + 0.03 * float(variant % 2), seed, LEAF_OAK, 6)
		"beech":
			_tree_broad(parts, 0.24, seed, LEAF_BEECH, 5, 0.85)
		"young":
			_tree_broad(parts, 0.12, seed, LEAF_BEECH, 4)
		"dead":
			_tree_dead(parts, 0.18, seed)
		"birch":
			_tree_birch(parts, 0.22, seed)
		"spruce":
			_tree_spruce(parts, 0.26 + 0.03 * float(variant % 2), seed, LEAF_SPRUCE, 5)
		"pine":
			_tree_spruce(parts, 0.2, seed, LEAF_PINE, 4)
		"blossom":
			_tree_broad(parts, 0.22, seed, LEAF_BLOSSOM, 6)
		"bush":
			_bush(parts, seed, LEAF_BEECH)
		"bush_dry":
			_bush(parts, seed, LEAF_DRY)
		"rock":
			_rock(parts, seed, 0.05)
		"boulder":
			_rock(parts, seed, 0.09)
		"stump":
			_stump(parts, seed)
		"log":
			_log(parts, seed)
		"cabin":
			_cabin(parts, variant)
		"house":
			_house(parts, variant)
		"townhouse":
			_townhouse(parts, variant)
		"block":
			_block(parts, variant)
		"glass_tower":
			_glass_tower(parts, variant)
		"church":
			_church(parts)
		"factory":
			_factory(parts, variant)
		"well":
			_well(parts)
		"stall":
			_stall(parts, variant)
		"woodpile":
			_woodpile(parts)
		"fence":
			_fence(parts, variant)
		"scarecrow":
			_scarecrow(parts)
		"cart":
			_cart(parts)
		"trough":
			_trough(parts)
		"quarry":
			_quarry(parts, variant)
		"crater":
			_crater(parts, seed)
		"ruin":
			_ruin(parts, variant)
		"tent":
			_tent(parts, variant)
	var out: Array = []
	for k in parts:
		var mb: MB = parts[k]
		if not mb.empty():
			out.append([mb.commit(), String(k)])
	_models[key] = out
	return out


# --- Bäume --------------------------------------------------------------------------------------------------

static func _tree_broad(p: Dictionary, h: float, seed: float, pal: Array, blobs: int, slim: float = 1.0) -> void:
	var s: MB = p["solid"]
	var l: MB = p["leaf"]
	var lean := Vector3(hash3(Vector3(seed, 1, 0)) - 0.5, 0, hash3(Vector3(seed, 2, 0)) - 0.5) * 0.02
	var top := Vector3(0, h * 0.5, 0) + lean
	s.cyl(Vector3.ZERO, h * 0.055, h * 0.03, h * 0.12, 7, BARK_D, BARK, false)
	s.rod(Vector3(0, h * 0.11, 0), top, h * 0.03, h * 0.02, 6, BARK, BARK)
	# zwei Astansätze
	for k in 2:
		var a := seed * 3.0 + float(k) * 2.6
		var b0 := Vector3(0, h * (0.3 + 0.08 * float(k)), 0) + lean * 0.5
		s.rod(b0, b0 + Vector3(cos(a) * h * 0.16, h * 0.14, sin(a) * h * 0.16), h * 0.016, h * 0.008, 5, BARK, BARK)
	var cc := Vector3(0, h * 0.66, 0) + lean
	var lo: Color = pal[0]
	var hi: Color = pal[1]
	l.wind = 1.0
	l.blob(cc, Vector3(h * 0.3 * slim, h * 0.26, h * 0.3 * slim), seed, lo, hi, 0.18, true, cc)
	for k in blobs:
		var a := seed * 1.7 + TAU * float(k) / float(blobs) + 0.4 * hash3(Vector3(seed, k, 3))
		var rr := h * (0.19 + 0.05 * hash3(Vector3(seed, k, 4))) * slim
		var cy := h * (0.5 + 0.28 * hash3(Vector3(seed, k, 5)))
		var r := h * (0.15 + 0.06 * hash3(Vector3(seed, k, 6)))
		var pc := Vector3(cos(a) * rr, cy, sin(a) * rr) + lean
		l.blob(pc, Vector3(r, r * 0.82, r), seed + float(k), lo, hi, 0.24, true, cc)
	l.blob(cc + Vector3(0, h * 0.2, 0), Vector3(h * 0.17, h * 0.13, h * 0.17), seed + 9.0, lo, hi.lightened(0.05), 0.2, true, cc)
	l.wind = 0.0


static func _tree_birch(p: Dictionary, h: float, seed: float) -> void:
	var s: MB = p["solid"]
	var l: MB = p["leaf"]
	var bark := Color("#ddd7ca")
	var segs := 6
	for i in segs:
		var y0 := h * 0.62 * float(i) / float(segs)
		var cc := bark if i % 2 == 0 or i == 0 else Color("#cfc8b8")
		s.cyl(Vector3(0, y0, 0), h * (0.028 - 0.003 * float(i)), h * (0.025 - 0.003 * float(i)), h * 0.62 / float(segs), 6, cc, cc, false)
		s.box(Vector3(h * 0.024 * (1.0 if i % 2 == 0 else -1.0), y0 + h * 0.05, 0), Vector3(0.003, 0.004, 0.006), Color("#3b342c"))
	var lo: Color = LEAF_BIRCH[0]
	var hi: Color = LEAF_BIRCH[1]
	l.wind = 1.0
	var cc0 := Vector3(0, h * 0.7, 0)
	for k in 5:
		var a := seed + TAU * float(k) / 5.0
		var pc := Vector3(cos(a) * h * 0.1, h * (0.55 + 0.09 * float(k % 3)), sin(a) * h * 0.1)
		l.blob(pc, Vector3(h * 0.13, h * 0.16, h * 0.13), seed + float(k), lo, hi, 0.28, true, cc0)
	l.blob(Vector3(0, h * 0.9, 0), Vector3(h * 0.1, h * 0.12, h * 0.1), seed + 7.0, lo, hi, 0.25, true, cc0)
	l.wind = 0.0


static func _tree_spruce(p: Dictionary, h: float, seed: float, pal: Array, tiers: int) -> void:
	var s: MB = p["solid"]
	var l: MB = p["leaf"]
	s.cyl(Vector3.ZERO, h * 0.04, h * 0.012, h * 0.55, 6, BARK_D, BARK, false)
	var lo: Color = pal[0]
	var hi: Color = pal[1]
	l.wind = 0.7
	for i in tiers:
		var t := float(i) / float(tiers)
		var y := h * (0.12 + 0.68 * t)
		var r := h * (0.3 - 0.21 * t)
		l.spiky_cone(Vector3(0, y, 0), r, h * (0.34 - 0.08 * t), 7, lo.lerp(hi, t * 0.3), hi.lerp(lo, 0.15 - t * 0.15), seed + float(i) * 0.9)
	l.wind = 0.0


static func _tree_dead(p: Dictionary, h: float, seed: float) -> void:
	var s: MB = p["solid"]
	var ch := Color("#2b2420")
	s.cyl(Vector3.ZERO, h * 0.05, h * 0.025, h * 0.7, 6, ch, Color("#3d332b"), true)
	for k in 3:
		var a := seed + float(k) * 2.1
		var b0 := Vector3(0, h * (0.35 + 0.12 * float(k)), 0)
		s.rod(b0, b0 + Vector3(cos(a) * h * 0.2, h * 0.15, sin(a) * h * 0.2), h * 0.014, h * 0.005, 4, ch, ch)


static func _bush(p: Dictionary, seed: float, pal: Array) -> void:
	var l: MB = p["leaf"]
	l.wind = 0.5
	var cc := Vector3(0, 0.02, 0)
	for k in 3:
		var a := seed + float(k) * 2.2
		var r := 0.024 + 0.008 * hash3(Vector3(seed, k, 1))
		l.blob(Vector3(cos(a) * 0.015, 0.016 + 0.006 * float(k % 2), sin(a) * 0.015), Vector3(r, r * 0.8, r), seed + float(k),
			pal[0], pal[1], 0.25, true, cc, 1, -0.4)
	l.wind = 0.0


static func _rock(p: Dictionary, seed: float, size: float) -> void:
	var s: MB = p["solid"]
	var lo := Color("#6d685f")
	var hi := Color("#a8a297")
	s.blob(Vector3(0, size * 0.3, 0), Vector3(size, size * 0.62, size * 0.8), seed, lo, hi, 0.3, false, Vector3(INF, 0, 0), 1, -0.45)
	s.blob(Vector3(size * 0.7, size * 0.15, size * 0.35), Vector3(size * 0.45, size * 0.35, size * 0.4), seed + 3.0, lo, hi, 0.3, false,
		Vector3(INF, 0, 0), 0, -0.4)
	# Moos oben
	var g: MB = p["grass"]
	g.tuft(Vector3(-size * 0.8, 0, size * 0.5), 0.016, 5, seed, Color("#3d5222"), Color("#7b8f3c"))


static func _stump(p: Dictionary, seed: float) -> void:
	var s: MB = p["solid"]
	s.cyl(Vector3.ZERO, 0.014 + 0.002 * hash3(Vector3(seed, 0, 0)), 0.012, 0.018, 7, BARK_D, BARK, false)
	s.cyl(Vector3(0, 0.018, 0), 0.012, 0.012, 0.0006, 7, Color("#b8986a"), Color("#c9a978"), true)


static func _log(p: Dictionary, seed: float) -> void:
	var s: MB = p["solid"]
	var a := seed
	s.rod(Vector3(-0.045 * cos(a), 0.008, -0.045 * sin(a)), Vector3(0.045 * cos(a), 0.01, 0.045 * sin(a)), 0.009, 0.007, 6, BARK_D, BARK)


# --- Gebäude --------------------------------------------------------------------------------------------------

## Blockhütte: Balkenwände, Schindeldach, Steinkamin, Tür, kleines Fenster.
static func _cabin(p: Dictionary, variant: int) -> void:
	var s: MB = p["solid"]
	# niedrig und breit (Grundriss ~1,3 : 1, Wand ≤ 0,6 × Tiefe): helles Holz unter dunklem, überstehendem Dach
	var w := 0.125
	var d := 0.096
	var wall_h := 0.05
	s.box(Vector3(0, 0.003, 0), Vector3(w + 0.012, 0.006, d + 0.012), Color("#6f6a62"))
	var logs := 6
	for i in logs:
		var y := 0.006 + wall_h * (float(i) + 0.5) / float(logs)
		var cc := LOGS if i % 2 == 0 else LOGS.darkened(0.1)
		s.box(Vector3(0, y, 0), Vector3(w, wall_h / float(logs) * 0.96, d), cc)
		# Balkenköpfe an den Ecken
		for cx_v in [-1.0, 1.0]:
			var cx: float = cx_v
			for cz_v in [-1.0, 1.0]:
				var cz: float = cz_v
				s.box(Vector3(cx * (w * 0.5 + 0.003), y, cz * (d * 0.5 + 0.003)), Vector3(0.008, wall_h / float(logs) * 0.9, 0.008), cc.lightened(0.08))
	var roof := Color("#5e3a2c") if variant % 2 == 0 else Color("#6b4430")
	s.gable(Vector3(0, 0.006 + wall_h, 0), w, d, 0.042, 0.02, roof, LOGS.darkened(0.06))
	# Tür und Fenster (vorne = +z)
	s.box(Vector3(-0.02, 0.006 + 0.019, d * 0.5 + 0.001), Vector3(0.02, 0.036, 0.003), Color("#3a2a1e"))
	s.push(Transform3D(Basis(), Vector3(0.025, 0.006 + 0.03, d * 0.5)))
	s.window(Vector3.ZERO, 0.02, 0.017, Color("#8a6a48"), LIT_C)
	s.pop()
	# Kamin aus Feldstein
	s.box(Vector3(w * 0.32, 0.006 + wall_h + 0.03, -d * 0.18), Vector3(0.018, 0.075, 0.018), Color("#7d776c"), Color("#4a4540"))
	# Bank vor der Hütte
	s.box(Vector3(0.025, 0.008, d * 0.5 + 0.016), Vector3(0.03, 0.004, 0.008), Color("#6a4c33"))


## Wohnhaus: Putz mit Fachwerk oder schlicht, Ziegeldach, Kamin, Fenster, Tür.
static func _house(p: Dictionary, variant: int) -> void:
	var s: MB = p["solid"]
	# niedrig und breit: von der Seite kein hoher Klotz, sondern ein Haus mit hellem Putz unter dunklem Ziegeldach
	var w := 0.135 + 0.012 * float(variant % 2)
	var d := 0.104
	var wall_h := 0.058
	var plaster: Color = PLASTER[variant % PLASTER.size()]
	var roof: Color = TILE_C[variant % TILE_C.size()]
	s.box(Vector3(0, 0.005, 0), Vector3(w + 0.008, 0.01, d + 0.008), Color("#77726a"))
	s.box(Vector3(0, 0.01 + wall_h * 0.5, 0), Vector3(w, wall_h, d), plaster)
	var half_timber := variant % 3 != 1
	if half_timber:
		# Fachwerk: Schwellen, Ständer, Streben auf den Längsseiten
		for sz_v in [-1.0, 1.0]:
			var sz: float = sz_v
			var zf := sz * (d * 0.5 + 0.0012)
			for y in [0.012, 0.01 + wall_h * 0.5, 0.01 + wall_h - 0.002]:
				var yy: float = y
				s.box(Vector3(0, yy, zf), Vector3(w, 0.004, 0.0025), TIMBER)
			for k in 5:
				var x := -w * 0.5 + w * float(k) / 4.0
				s.box(Vector3(clampf(x, -w * 0.5 + 0.002, w * 0.5 - 0.002), 0.01 + wall_h * 0.5, zf), Vector3(0.004, wall_h, 0.0025), TIMBER)
	s.gable(Vector3(0, 0.01 + wall_h, 0), w, d, 0.05, 0.02, roof, plaster)
	# Fenster (zwei Reihen auf der Vorderseite, eines am Giebel)
	s.push(Transform3D(Basis(), Vector3(0, 0, d * 0.5)))
	for k in 2:
		var x := (-0.032 + 0.064 * float(k))
		s.window(Vector3(x, 0.01 + wall_h * 0.72, 0.0), 0.016, 0.017, Color("#e8e2d6"), GLASS_C)
		if k == 1:
			s.window(Vector3(x, 0.01 + wall_h * 0.27, 0.0), 0.016, 0.017, Color("#e8e2d6"), GLASS_C)
	s.box(Vector3(-0.032, 0.01 + 0.019, 0.0012), Vector3(0.018, 0.034, 0.0026), Color("#5a3d2a"))
	s.pop()
	s.push(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(w * 0.5, 0, 0)))
	s.window(Vector3(0, 0.01 + wall_h + 0.016, 0), 0.012, 0.014, Color("#e8e2d6"), GLASS_C, false)
	s.window(Vector3(0, 0.01 + wall_h * 0.5, 0), 0.016, 0.017, Color("#e8e2d6"), LIT_C)
	s.pop()
	s.box(Vector3(-w * 0.25, 0.01 + wall_h + 0.045, -0.012), Vector3(0.012, 0.04, 0.012), Color("#8a5a46"), Color("#3a2f2a"))


## Stadthaus: 2–3 Geschosse, Gesims, Fensterraster, Laden unten, steiles Dach.
static func _townhouse(p: Dictionary, variant: int) -> void:
	var s: MB = p["solid"]
	var floors := 2 + variant % 2
	var w := 0.08
	var d := 0.09
	var fh := 0.044
	var plaster: Color = PLASTER[(variant + 1) % PLASTER.size()].darkened(0.03 * float(variant % 2))
	if variant == 2:
		plaster = Color("#c9b49a")
	if variant == 3:
		plaster = Color("#b7a38e")
	var roof: Color = TILE_C[(variant + 2) % TILE_C.size()] if variant != 1 else SLATE
	var hgt := fh * float(floors)
	s.box(Vector3(0, 0.004, 0), Vector3(w + 0.004, 0.008, d + 0.004), Color("#6d6860"))
	s.box(Vector3(0, 0.008 + hgt * 0.5, 0), Vector3(w, hgt, d), plaster)
	s.box(Vector3(0, 0.008 + fh * 0.5, 0), Vector3(w + 0.002, fh, d + 0.002), plaster.darkened(0.12))
	for f in floors:
		s.box(Vector3(0, 0.008 + fh * float(f + 1) - 0.002, 0), Vector3(w + 0.005, 0.003, d + 0.005), plaster.lightened(0.12))
	s.gable(Vector3(0, 0.008 + hgt, 0), w, d, 0.06, 0.008, roof, plaster)
	for side_v in [0, 1]:
		var side: int = side_v
		var rot := Basis() if side == 0 else Basis(Vector3.UP, PI * 0.5)
		var off := Vector3(0, 0, d * 0.5) if side == 0 else Vector3(w * 0.5, 0, 0)
		var span := w if side == 0 else d
		s.push(Transform3D(rot, off))
		for f in floors:
			var cols := 2 if span < 0.085 else 3
			for k in cols:
				var x := -span * 0.5 + span * (float(k) + 0.5) / float(cols)
				var y := 0.008 + fh * float(f) + fh * 0.52
				if f == 0 and side == 0 and k == 0:
					s.box(Vector3(x, 0.008 + 0.017, 0.0012), Vector3(0.016, 0.032, 0.0026), Color("#4a3426"))
				elif f == 0 and side == 0:
					s.window(Vector3(x, y - 0.003, 0), 0.02, 0.022, Color("#5a4a3c"), GLASS_C.lightened(0.05), false)
				else:
					s.window(Vector3(x, y, 0), 0.013, 0.02, Color("#ece6da"), GLASS_C)
		s.pop()
	# Gauben-Kamin
	s.box(Vector3(w * 0.25, 0.008 + hgt + 0.05, 0.02), Vector3(0.01, 0.03, 0.01), Color("#7b5444"), Color("#2e2a27"))


## Wohnblock: 4–6 Geschosse, Flachdach mit Attika, Fensterbänder, Balkone.
static func _block(p: Dictionary, variant: int) -> void:
	var s: MB = p["solid"]
	var floors := 4 + variant % 3
	var w := 0.11
	var d := 0.1
	var fh := 0.038
	var walls := [Color("#b9b0a2"), Color("#a69c8c"), Color("#c7bfb1"), Color("#9a9184")]
	var wall: Color = walls[variant % walls.size()]
	var hgt := fh * float(floors)
	s.box(Vector3(0, hgt * 0.5, 0), Vector3(w, hgt, d), wall, Color("#8f8b84"))
	s.box(Vector3(0, hgt + 0.004, 0), Vector3(w + 0.004, 0.008, d + 0.004), wall.darkened(0.1), Color("#85817a"))
	s.box(Vector3(0.02, hgt + 0.014, -0.01), Vector3(0.03, 0.02, 0.025), Color("#7a7670"))
	for side in 4:
		var rot := Basis(Vector3.UP, PI * 0.5 * float(side))
		var span := w if side % 2 == 0 else d
		var off := rot * Vector3(0, 0, (d if side % 2 == 0 else w) * 0.5)
		s.push(Transform3D(rot, off))
		for f in floors:
			var y := fh * float(f) + fh * 0.55
			var cols := 4
			for k in cols:
				var x := -span * 0.5 + span * (float(k) + 0.5) / float(cols)
				if f == 0 and side == 0 and k == 1:
					s.box(Vector3(x, 0.016, 0.0012), Vector3(0.018, 0.03, 0.0026), Color("#3e3a36"))
					continue
				s.window(Vector3(x, y, 0), 0.016, 0.018, Color("#d9d4ca"), GLASS_C, false)
			if side == 0 and f > 0 and variant % 2 == 0:
				s.box(Vector3(span * 0.25, fh * float(f) + 0.004, 0.006), Vector3(0.03, 0.003, 0.012), wall.darkened(0.2))
		s.pop()


## Glasturm: dunkles Glas mit Geschossbändern, Technik auf dem Dach.
static func _glass_tower(p: Dictionary, variant: int) -> void:
	var s: MB = p["solid"]
	var g: MB = p["glass"]
	var floors := 9 + 3 * (variant % 3)
	var w := 0.1 - 0.012 * float(variant % 2)
	var fh := 0.034
	var hgt := fh * float(floors)
	s.box(Vector3(0, 0.012, 0), Vector3(w + 0.012, 0.024, w + 0.012), Color("#6e6b66"))
	var gc := Color("#66727c") if variant % 2 == 0 else Color("#707c80")
	for f in floors:
		var y := 0.024 + fh * float(f)
		g.box(Vector3(0, y + fh * 0.5, 0), Vector3(w, fh * 0.82, w), gc.lightened(0.04 * float(f % 3)), Color("#4b4f52"))
		s.box(Vector3(0, y + fh * 0.95, 0), Vector3(w + 0.002, fh * 0.12, w + 0.002), Color("#8a8f94"))
	for cx_v in [-1.0, 1.0]:
		var cx: float = cx_v
		for cz_v in [-1.0, 1.0]:
			var cz: float = cz_v
			s.box(Vector3(cx * w * 0.5, 0.024 + hgt * 0.5, cz * w * 0.5), Vector3(0.004, hgt, 0.004), Color("#9aa0a6"))
	s.box(Vector3(0, 0.024 + hgt + 0.01, 0), Vector3(w * 0.5, 0.02, w * 0.4), Color("#80827f"))
	if variant % 3 == 0:
		s.cyl(Vector3(0, 0.024 + hgt + 0.02, 0), 0.002, 0.001, 0.07, 4, Color("#9aa0a6"), Color("#c9cdd0"))


## Kirche: Steinschiff mit Schieferdach, Turm mit Spitzhelm, Fenster mit warmem und violettem Licht.
static func _church(p: Dictionary) -> void:
	var s: MB = p["solid"]
	var wm: MB = p["warm"]
	var fm: MB = p["faith"]
	var stone := Color("#c4baa6")
	var stone_d := Color("#aba08e")
	# Schiff (entlang x)
	var nw := 0.2
	var nd := 0.11
	var nh := 0.095
	var nx := -0.04
	s.box(Vector3(nx, 0.004, 0), Vector3(nw + 0.012, 0.008, nd + 0.012), Color("#857f74"))
	s.box(Vector3(nx, 0.008 + nh * 0.5, 0), Vector3(nw, nh, nd), stone)
	for k in 5:
		var x := nx - nw * 0.5 + nw * float(k) / 4.0
		for sz_v in [-1.0, 1.0]:
			var sz: float = sz_v
			s.box(Vector3(x, 0.008 + nh * 0.45, sz * (nd * 0.5 + 0.004)), Vector3(0.008, nh * 0.9, 0.008), stone_d, stone_d.lightened(0.1))
	s.gable(Vector3(nx, 0.008 + nh, 0), nw, nd, 0.075, 0.01, SLATE, stone)
	# Apsis
	s.cyl(Vector3(nx - nw * 0.5, 0.008, 0), nd * 0.42, nd * 0.42, nh * 0.85, 10, stone_d, stone_d, false, PI * 0.5)
	s.cyl(Vector3(nx - nw * 0.5, 0.008 + nh * 0.85, 0), nd * 0.45, 0.0, 0.05, 10, SLATE, SLATE, false, PI * 0.5)
	# Spitzbogenfenster: Licht (warm unten, violett oben)
	for k in 3:
		var x := nx - 0.06 + float(k) * 0.055
		for sz_v in [-1.0, 1.0]:
			var sz: float = sz_v
			var z := sz * (nd * 0.5 + 0.0015)
			wm.box(Vector3(x, 0.008 + nh * 0.48, z), Vector3(0.016, 0.034, 0.003), Color.WHITE)
			fm.box(Vector3(x, 0.008 + nh * 0.48 + 0.022, z), Vector3(0.01, 0.01, 0.003), Color.WHITE)
	# Turm (vorne, +x)
	var tx := 0.1
	var tw := 0.075
	var th := 0.24
	s.box(Vector3(tx, 0.004, 0), Vector3(tw + 0.012, 0.008, tw + 0.012), Color("#857f74"))
	s.box(Vector3(tx, 0.008 + th * 0.5, 0), Vector3(tw, th, tw), stone)
	s.box(Vector3(tx, 0.008 + th * 0.62, 0), Vector3(tw + 0.004, 0.004, tw + 0.004), stone.lightened(0.1))
	s.box(Vector3(tx, 0.008 + th - 0.002, 0), Vector3(tw + 0.006, 0.006, tw + 0.006), stone.lightened(0.1))
	for side in 4:
		var rot := Basis(Vector3.UP, PI * 0.5 * float(side))
		s.push(Transform3D(rot, Vector3(tx, 0, 0) + rot * Vector3(0, 0, tw * 0.5)))
		s.box(Vector3(0, 0.008 + th * 0.82, 0.0012), Vector3(0.018, 0.034, 0.0026), Color("#2a2622"))
		if side == 1:
			s.cyl(Vector3(0, 0.008 + th * 0.68, 0.0), 0.014, 0.014, 0.003, 12, Color("#e8e0cc"), Color("#e8e0cc"), true)
		s.pop()
	s.box(Vector3(tx + tw * 0.5 + 0.0012, 0.008 + 0.024, 0), Vector3(0.0026, 0.045, 0.026), Color("#4a3426"))
	s.pyramid(Vector3(tx, 0.008 + th, 0), tw, tw, 0.17, SLATE, 0.004)
	# Kreuz
	s.box(Vector3(tx, 0.008 + th + 0.185, 0), Vector3(0.003, 0.03, 0.003), Color("#c9a54a"))
	s.box(Vector3(tx, 0.008 + th + 0.19, 0), Vector3(0.003, 0.003, 0.016), Color("#c9a54a"))


## Industrie: Ziegelhallen mit Sheddach, Ziegelschlote mit Ruß, Silos, Gleis.
static func _factory(p: Dictionary, variant: int) -> void:
	var s: MB = p["solid"]
	var wm: MB = p["warm"]
	var g: MB = p["glass"]
	var hall := Vector3(-0.05, 0, 0.06)
	var hw := 0.24
	var hd := 0.15
	var hh := 0.075
	var brick := BRICK if variant % 2 == 0 else BRICK.darkened(0.1)
	s.box(hall + Vector3(0, hh * 0.5, 0), Vector3(hw, hh, hd), brick)
	s.box(hall + Vector3(0, hh - 0.002, 0), Vector3(hw + 0.004, 0.005, hd + 0.004), brick.lightened(0.15))
	var teeth := 4
	for i in teeth:
		var x0 := -hw * 0.5 + hw * float(i) / float(teeth)
		var x1 := x0 + hw / float(teeth)
		var y0 := hh
		var y1 := hh + 0.035
		for sz_v in [-1.0, 1.0]:
			var sz: float = sz_v
			var z := sz * hd * 0.5
			s.tri(hall + Vector3(x0, y0, z), hall + Vector3(x1, y0, z), hall + Vector3(x1, y1, z), brick, Vector3(0, 0, sz))
		s.quad(hall + Vector3(x0, y0, -hd * 0.5), hall + Vector3(x1, y1, -hd * 0.5), hall + Vector3(x1, y1, hd * 0.5),
			hall + Vector3(x0, y0, hd * 0.5), Color("#77726c"), Vector3(-0.035, hw / float(teeth), 0))
		g.quad(hall + Vector3(x1, y0, -hd * 0.5), hall + Vector3(x1, y1, -hd * 0.5), hall + Vector3(x1, y1, hd * 0.5),
			hall + Vector3(x1, y0, hd * 0.5), Color("#6f8590"), Vector3(1, 0, 0))
	# Fensterreihe (Ofenlicht) und Tor
	for k in 4:
		wm.box(hall + Vector3(-0.085 + float(k) * 0.055, hh * 0.45, hd * 0.5 + 0.0015), Vector3(0.026, 0.026, 0.003), Color.WHITE)
	s.box(hall + Vector3(hw * 0.5 + 0.0012, 0.024, 0.0), Vector3(0.0026, 0.046, 0.05), Color("#3f3d3a"))
	# Schlote
	var specs := [[Vector3(0.1, 0, -0.12), 0.36], [Vector3(0.17, 0, -0.06), 0.28]]
	if variant % 2 == 1:
		specs = [[Vector3(0.12, 0, -0.1), 0.38]]
	for sp in specs:
		var base: Vector3 = sp[0]
		var h: float = sp[1]
		s.box(base + Vector3(0, 0.012, 0), Vector3(0.05, 0.024, 0.05), brick.darkened(0.1))
		s.cyl(base + Vector3(0, 0.024, 0), 0.022, 0.015, h, 10, brick, brick.lightened(0.08), false)
		s.cyl(base + Vector3(0, 0.024 + h * 0.8, 0), 0.0175, 0.0165, h * 0.2, 10, SOOT.lightened(0.15), SOOT, false)
		s.cyl(base + Vector3(0, 0.024 + h, 0), 0.019, 0.019, 0.005, 10, SOOT, SOOT, true)
	# Silos
	for k in 2:
		var sp := Vector3(-0.2 + float(k) * 0.065, 0, -0.12)
		s.cyl(sp, 0.028, 0.028, 0.1, 12, CONCRETE, CONCRETE.lightened(0.12), false)
		s.cyl(sp + Vector3(0, 0.1, 0), 0.028, 0.006, 0.02, 12, CONCRETE.lightened(0.1), CONCRETE.lightened(0.2), true)
	s.rod(Vector3(-0.2, 0.1, -0.12), Vector3(-0.07, 0.08, 0.02), 0.004, 0.004, 5, Color("#5a5650"), Color("#5a5650"))
	# Gleis
	for k in 9:
		s.box(Vector3(-0.27 + float(k) * 0.065, 0.002, 0.25), Vector3(0.01, 0.004, 0.05), Color("#4a3a2c"))
	for sz_v in [-1.0, 1.0]:
		var sz: float = sz_v
		s.box(Vector3(0.0, 0.0055, 0.25 + sz * 0.014), Vector3(0.56, 0.003, 0.003), Color("#6d6a68"))
	s.box(Vector3(-0.15, 0.022, 0.25), Vector3(0.09, 0.03, 0.038), Color("#5a3a2c"), Color("#463026"))


# --- Kleinkram (B6) ---------------------------------------------------------------------------------------------

static func _well(p: Dictionary) -> void:
	var s: MB = p["solid"]
	s.cyl(Vector3.ZERO, 0.022, 0.022, 0.02, 10, Color("#8a857c"), Color("#9d978c"), false)
	s.cyl(Vector3(0, 0.018, 0), 0.016, 0.016, 0.0001, 10, Color("#1e2a2e"), Color("#1e2a2e"), true)
	for sx_v in [-1.0, 1.0]:
		var sx: float = sx_v
		s.box(Vector3(sx * 0.019, 0.032, 0), Vector3(0.004, 0.044, 0.004), WOOD)
	s.gable(Vector3(0, 0.054, 0), 0.03, 0.03, 0.014, 0.004, Color("#5a4636"), WOOD, 0.003)


static func _stall(p: Dictionary, variant: int) -> void:
	var s: MB = p["solid"]
	var cloths := [Color("#9a5a46"), Color("#b39a6a"), Color("#6e7a5a"), Color("#8a8070")]
	var cloth: Color = cloths[variant % cloths.size()]
	s.box(Vector3(0, 0.012, 0), Vector3(0.05, 0.016, 0.028), Color("#7a5a3c"))
	for cx_v in [-1.0, 1.0]:
		var cx: float = cx_v
		for cz_v in [-1.0, 1.0]:
			var cz: float = cz_v
			s.box(Vector3(cx * 0.023, 0.02, cz * 0.012), Vector3(0.003, 0.04, 0.003), WOOD)
	for k in 4:
		var c2 := cloth if k % 2 == 0 else cloth.lightened(0.25)
		var x0 := -0.026 + 0.013 * float(k)
		s.quad(Vector3(x0, 0.042, -0.016), Vector3(x0 + 0.013, 0.042, -0.016), Vector3(x0 + 0.013, 0.034, 0.02),
			Vector3(x0, 0.034, 0.02), c2, Vector3(0, 1, 0.3))
	# Waren
	var goods := [Color("#a8743f"), Color("#8a9a4a"), Color("#c49a4a"), Color("#9a4a3a")]
	for k in 4:
		s.bead(Vector3(-0.016 + 0.011 * float(k), 0.022, 0.0), 0.0045, goods[(k + variant) % 4])


static func _woodpile(p: Dictionary) -> void:
	var s: MB = p["solid"]
	for row in 3:
		for k in 4 - row:
			var x := -0.012 + 0.008 * float(k) + 0.004 * float(row)
			s.rod(Vector3(x, 0.004 + 0.0068 * float(row), -0.016), Vector3(x, 0.004 + 0.0068 * float(row), 0.016), 0.0038, 0.0038, 6,
				Color("#8a6a48"), Color("#b8986a"))


## Zaun: variant 0 gerade (0,2 lang, entlang x), 1 Ecke.
static func _fence(p: Dictionary, variant: int) -> void:
	var s: MB = p["solid"]
	var wood := Color("#7a6248")
	var segs := [[Vector3(-0.1, 0, 0), Vector3(0.1, 0, 0)]]
	if variant == 1:
		segs = [[Vector3(-0.1, 0, 0), Vector3(0.0, 0, 0)], [Vector3(0.0, 0, 0), Vector3(0.0, 0, 0.1)]]
	for sg in segs:
		var a: Vector3 = sg[0]
		var b: Vector3 = sg[1]
		var n := int(roundf((b - a).length() / 0.033))
		for k in n + 1:
			var q := a.lerp(b, float(k) / float(maxi(n, 1)))
			s.box(q + Vector3(0, 0.014, 0), Vector3(0.0035, 0.028, 0.0035), wood.darkened(0.1))
		for hy in [0.012, 0.022]:
			var y: float = hy
			s.rod(a + Vector3(0, y, 0), b + Vector3(0, y, 0), 0.0016, 0.0016, 4, wood, wood)


static func _scarecrow(p: Dictionary) -> void:
	var s: MB = p["solid"]
	s.box(Vector3(0, 0.03, 0), Vector3(0.003, 0.06, 0.003), WOOD)
	s.box(Vector3(0, 0.046, 0), Vector3(0.003, 0.003, 0.036), WOOD)
	s.box(Vector3(0, 0.042, 0), Vector3(0.008, 0.018, 0.016), Color("#6e5a44"))
	s.bead(Vector3(0, 0.058, 0), 0.0065, Color("#c9b07a"))
	s.cyl(Vector3(0, 0.062, 0), 0.011, 0.004, 0.006, 8, Color("#5a4a34"), Color("#5a4a34"))


static func _cart(p: Dictionary) -> void:
	var s: MB = p["solid"]
	s.box(Vector3(0, 0.016, 0), Vector3(0.04, 0.012, 0.026), Color("#7a5a3c"))
	for sz_v in [-1.0, 1.0]:
		var sz: float = sz_v
		s.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.011, sz * 0.015)))
		s.cyl(Vector3(0, -0.002, 0), 0.011, 0.011, 0.004, 10, Color("#4a3426"), Color("#4a3426"))
		s.pop()
	s.rod(Vector3(0.02, 0.016, 0), Vector3(0.05, 0.006, 0), 0.0018, 0.0018, 4, WOOD, WOOD)
	for k in 3:
		s.bead(Vector3(-0.01 + 0.01 * float(k), 0.025, 0.0), 0.006, Color("#b3913f"))


static func _trough(p: Dictionary) -> void:
	var s: MB = p["solid"]
	s.box(Vector3(0, 0.007, 0), Vector3(0.05, 0.014, 0.02), Color("#6a5038"))
	s.box(Vector3(0, 0.0142, 0), Vector3(0.044, 0.0005, 0.014), Color("#4c6a72"))


## Steinbruch (Stein): Felswand mit Abbaukante, geschnittene Blöcke, Schutt.
static func _quarry(p: Dictionary, variant: int) -> void:
	var s: MB = p["solid"]
	var lo := Color("#6d685f")
	var hi := Color("#b2ac9f")
	var sd := float(variant) * 3.7
	s.blob(Vector3(-0.12, 0.045, -0.15), Vector3(0.13, 0.09, 0.08), sd, lo, hi, 0.2, false, Vector3(INF, 0, 0), 2, -0.5)
	s.blob(Vector3(0.0, 0.035, -0.19), Vector3(0.08, 0.07, 0.07), sd + 4.0, lo, hi, 0.24, false, Vector3(INF, 0, 0), 2, -0.5)
	s.blob(Vector3(0.14, 0.028, -0.16), Vector3(0.08, 0.055, 0.07), sd + 1.0, lo, hi, 0.24, false, Vector3(INF, 0, 0), 2, -0.5)
	s.blob(Vector3(-0.22, 0.022, 0.06), Vector3(0.06, 0.045, 0.055), sd + 2.0, lo, hi, 0.24, false, Vector3(INF, 0, 0), 1, -0.5)
	s.blob(Vector3(0.2, 0.018, 0.14), Vector3(0.045, 0.035, 0.04), sd + 5.0, lo, hi, 0.25, false, Vector3(INF, 0, 0), 1, -0.5)
	# Abbaukante: glatte, helle Fläche
	s.box(Vector3(-0.06, 0.03, -0.075), Vector3(0.12, 0.06, 0.03), Color("#bdb6a9"), Color("#a39d92"))
	# geschnittene Blöcke
	for k in 3:
		s.box(Vector3(0.06 + 0.035 * float(k % 2), 0.009 + 0.018 * float(k / 2), 0.07 + 0.012 * float(k)),
			Vector3(0.03, 0.018, 0.022), Color("#aaa396").darkened(0.05 * float(k)))
	for k in 8:
		var a := sd + float(k) * 1.9
		s.blob(Vector3(cos(a) * 0.18, 0.006, 0.12 + sin(a) * 0.08), Vector3(0.012, 0.008, 0.01), sd + float(k), lo, hi, 0.3, false,
			Vector3(INF, 0, 0), 0)


## Meteorkrater: unregelmäßiger Wall aus aufgeworfener Erde und Steinbrocken, dunkler Grund, Auswurf.
static func _crater(p: Dictionary, seed: float) -> void:
	var s: MB = p["solid"]
	var n := 26
	var r_in := 0.11
	var r_out := 0.24
	var rim_lo := Color("#4a3a2c")
	var rim_hi := Color("#7a6248")
	var floor_c := Color("#2a2420")
	var ring_pts: Array = []
	for i in n:
		var a := TAU * float(i) / float(n)
		var j := 0.85 + 0.3 * hash3(Vector3(seed, i, 0))
		ring_pts.append([Vector3(cos(a), 0, sin(a)), 0.026 * j, 0.17 * (0.92 + 0.16 * hash3(Vector3(seed, i, 1)))])
	for i in n:
		var a0: Array = ring_pts[i]
		var a1: Array = ring_pts[(i + 1) % n]
		var d0: Vector3 = a0[0]
		var d1: Vector3 = a1[0]
		var h0: float = a0[1]
		var h1: float = a1[1]
		var c0 := d0 * float(a0[2]) + Vector3(0, h0, 0)
		var c1 := d1 * float(a1[2]) + Vector3(0, h1, 0)
		var o0 := d0 * r_out * (0.9 + 0.2 * hash3(Vector3(seed, i, 2))) + Vector3(0, 0.0015, 0)
		var o1 := d1 * r_out * (0.9 + 0.2 * hash3(Vector3(seed, (i + 1) % n, 2))) + Vector3(0, 0.0015, 0)
		var i0 := d0 * r_in + Vector3(0, 0.004, 0)
		var i1 := d1 * r_in + Vector3(0, 0.004, 0)
		var shade := hash3(Vector3(seed, i, 3))
		s.quad(o0, o1, c1, c0, rim_hi.lerp(rim_lo, shade * 0.6), (d0 + d1) + Vector3(0, 3, 0))
		s.quad(c0, c1, i1, i0, rim_lo.lerp(floor_c, 0.3 + 0.3 * shade), -(d0 + d1) + Vector3(0, 2, 0))
		s.tri(Vector3(0, 0.003, 0), i0, i1, floor_c.lerp(Color("#3a3028"), shade), Vector3.UP)
	for k in 14:
		var a := seed + float(k) * 0.45 + hash3(Vector3(seed, k, 4))
		var rr := 0.15 + 0.13 * hash3(Vector3(seed, k, 3))
		var sz := 0.006 + 0.009 * hash3(Vector3(seed, k, 5))
		s.blob(Vector3(cos(a) * rr, 0.012 + sz * 0.3 + (0.02 if rr < 0.2 else 0.0), sin(a) * rr), Vector3(sz * 1.3, sz, sz * 1.1), seed + float(k),
			Color("#4a443d"), Color("#857c70"), 0.3, false, Vector3(INF, 0, 0), 0)


## Ruine (Krieg, verbrannte Häuser): Mauerreste, verkohlte Balken.
static func _ruin(p: Dictionary, variant: int) -> void:
	var s: MB = p["solid"]
	var wall := Color("#8d8578")
	var ch := Color("#2b2420")
	s.box(Vector3(0, 0.02, -0.03), Vector3(0.1, 0.04 - 0.01 * float(variant % 2), 0.008), wall)
	s.box(Vector3(-0.046, 0.014, 0.0), Vector3(0.008, 0.028, 0.06), wall.darkened(0.1))
	s.box(Vector3(0.03, 0.006, 0.02), Vector3(0.05, 0.012, 0.04), Color("#5a524a"))
	s.rod(Vector3(-0.03, 0.002, 0.03), Vector3(0.04, 0.03, -0.02), 0.004, 0.004, 5, ch, ch)
	s.rod(Vector3(0.0, 0.002, -0.01), Vector3(0.05, 0.016, 0.04), 0.0035, 0.0035, 5, ch, ch)


## Heerlager (Kriegsfront): Zelt mit Fahne.
static func _tent(p: Dictionary, variant: int) -> void:
	var s: MB = p["solid"]
	var cloth := Color("#b3a58a") if variant % 2 == 0 else Color("#9a8e78")
	s.gable(Vector3(0, 0.0, 0), 0.05, 0.04, 0.032, 0.0, cloth, cloth.darkened(0.15), 0.002)
	s.box(Vector3(0.028, 0.035, 0), Vector3(0.002, 0.07, 0.002), WOOD)
	s.box(Vector3(0.028, 0.06, 0.01), Vector3(0.002, 0.014, 0.02), Color("#8a2f28") if variant % 2 == 0 else Color("#2f4a7a"))


# =============================================================================
# Bodendecker (B2): Gras, Blumen, Kiesel, Erdklumpen als je ein Mesh (grass) bzw. (solid)
# =============================================================================

## Zufällige Punkte im Feld, die nicht in den Hindernissen (Vector3(x, z, r)) liegen.
static func scatter(rng: RandomNumberGenerator, count: int, obst: Array, half: float = 0.3) -> Array:
	var out: Array = []
	var tries := 0
	while out.size() < count and tries < count * 6:
		tries += 1
		var p := Vector3(rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))
		var ok := true
		for o in obst:
			var ob: Vector3 = o
			if Vector2(p.x - ob.x, p.z - ob.y).length() < ob.z:
				ok = false
				break
		if ok:
			out.append(p)
	return out


## Gras und Blumen. density: Büschel; flowers: Blüten; lush 0..1 (Paradies); dry: welk.
static func cover(key: String, rng: RandomNumberGenerator, obst: Array, density: int, flowers: int, dry: bool,
		pebbles: int = 0, tall: float = 1.0, half: float = 0.31) -> Array:
	if _models.has("cover|" + key):
		return _models["cover|" + key]
	var g := MB.new()
	var s := MB.new()
	var lo := Color("#507428") if not dry else Color("#76683e")
	var hi := Color("#9fbc58") if not dry else Color("#b8a066")
	for p in scatter(rng, density, obst, half):
		var pp: Vector3 = p
		var sd := rng.randf() * 100.0
		g.tuft(pp, 0.019 * tall * rng.randf_range(0.7, 1.3), rng.randi_range(3, 6), sd, lo, hi.lerp(lo, rng.randf() * 0.3), 0.008, 0.003)
	var fcols := [Color("#e9e4d4"), Color("#d8b84a"), Color("#9c7fb4"), Color("#e9e4d4"), Color("#c76a5a")]
	for p in scatter(rng, flowers, obst, half):
		var pp: Vector3 = p
		var fc: Color = fcols[rng.randi_range(0, fcols.size() - 1)]
		if dry:
			fc = Color("#9a845a")
		var hh := rng.randf_range(0.014, 0.026) * tall
		g.tuft(pp, hh, 2, rng.randf() * 50.0, lo, lo.lerp(hi, 0.5), 0.004, 0.002)
		g.wind = 0.8
		g.bead(pp + Vector3(0, hh, 0), 0.0032, fc, 0.6)
		g.wind = 0.0
	for p in scatter(rng, pebbles, obst, half):
		var pp: Vector3 = p
		var r := rng.randf_range(0.005, 0.012)
		s.blob(pp + Vector3(0, r * 0.25, 0), Vector3(r, r * 0.55, r * 0.8), rng.randf() * 30.0, Color("#6e675d"), Color("#a29a8c"), 0.3,
			false, Vector3(INF, 0, 0), 0)
	var out: Array = []
	if not g.empty():
		out.append([g.commit(), "grass"])
	if not s.empty():
		out.append([s.commit(), "solid"])
	_models["cover|" + key] = out
	return out


## Acker (B3): Pflanzenreihen auf den Dämmen des Boden-Shaders. stage 0 Saat, 1 grün, 2 reif (golden).
## dir: Reihen entlang x (0) oder z (1). Die Reihen liegen genau auf den hellen Furchen-Dämmen (ground.gdshader).
static func crops(key: String, stage: int, dir: int, dry: bool) -> Array:
	if _models.has("crops|" + key):
		return _models["crops|" + key]
	var g := MB.new()
	for k in range(-3, 4):
		var z := (0.125 * float(k)) / 1.4      # Dämme: cos(2π·8·u) im Boden-Shader (u in Feld-Koordinaten)
		var n := 26 if stage == 2 else (15 if stage == 1 else 20)
		for i in n:
			var x := -0.29 + 0.58 * (float(i) + 0.5) / float(n) + 0.004 * sin(float(k * 13 + i * 7))
			var zz := z + 0.004 * sin(float(k * 5 + i * 11))
			var pp := Vector3(x, 0.0, zz) if dir == 0 else Vector3(zz, 0.0, x)
			var sd := float(k * 31 + i)
			var rnd := hash3(Vector3(sd, 1.0, 2.0))
			if stage == 0:
				g.tuft(pp, 0.009, 3, sd, Color("#5a7a30"), Color("#9cbc58"), 0.004, 0.0022)
			elif stage == 1:
				var lo := Color("#46702a") if not dry else Color("#6e6a3a")
				var hi := Color("#93b84e") if not dry else Color("#a69a5a")
				g.tuft(pp, 0.02 + 0.006 * rnd, 8, sd, lo, hi, 0.006, 0.0048)
			else:
				var stalk := Color("#a88a42") if not dry else Color("#7a6a46")
				var ear := Color("#e0c47a") if not dry else Color("#9a8a62")
				var hh := 0.03 + 0.008 * rnd
				g.tuft(pp, hh, 6, sd, stalk.darkened(0.2), stalk.lightened(0.1), 0.007, 0.0024)
				g.wind = 1.0
				for e in 3:
					var a := sd + float(e) * 2.1
					g.bead(pp + Vector3(cos(a) * 0.004, hh * (0.85 + 0.1 * float(e % 2)), sin(a) * 0.004), 0.0032, ear, 1.9)
				g.wind = 0.0
	var out: Array = [[g.commit(), "grass"]]
	_models["crops|" + key] = out
	return out


# =============================================================================
# Tiere und Menschen (B7, B8): Blick nach +x. Teile: 0 Rumpf, 1/2 Beine (Takt A/B), 3 Kopf (Tier),
# 4 Oberkörper und Kopf (Mensch, bückt sich um die Hüfte), 5/6 Arme, 7 Schwanz
# =============================================================================

const CLOTHES := [Color("#7a5c43"), Color("#4f5f6f"), Color("#8a3f34"), Color("#6b7146"), Color("#d8d0bd"), Color("#5a4a6a")]
const SKIN_C := [Color("#d9b08c"), Color("#c19272"), Color("#a7795a"), Color("#e2bf9c")]
const HAIR := [Color("#3a2a1e"), Color("#5a3e26"), Color("#8a6a3e"), Color("#2a2522"), Color("#a69a8a")]


static func creature_mesh(kind: String, variant: int) -> Mesh:
	var key := "cr|%s|%d" % [kind, variant]
	if _meshes.has(key):
		return _meshes[key]
	var m := MB.new()
	match kind:
		"sheep":
			_sheep(m, variant)
		"cow":
			_cow(m, variant)
		"deer":
			_deer(m, variant)
		"hare":
			_hare(m)
		"duck":
			_duck(m, variant)
		_:
			_person(m, variant)
	var mesh := m.commit()
	_meshes[key] = mesh
	return mesh


static func _legs(m: MB, xs: Array, zs: Array, h: float, w: float, col: Color, hoof: Color) -> void:
	for xi in 2:
		for zi in 2:
			var x: float = xs[xi]
			var z: float = zs[zi]
			m.part = 1.0 if (xi == 0) == (zi == 0) else 2.0
			m.pivot = Vector2(x, h)
			m.box(Vector3(x, h * 0.55, z), Vector3(w, h * 0.9, w), col)
			m.box(Vector3(x, h * 0.06, z), Vector3(w * 1.1, h * 0.12, w * 1.1), hoof)
	m.part = 0.0


static func _sheep(m: MB, variant: int) -> void:
	var wool := Color("#e6e0d2") if variant % 3 != 2 else Color("#5a504a")
	var face := Color("#2e2a28") if variant % 2 == 0 else Color("#d8cfc0")
	_legs(m, [0.014, -0.014], [-0.007, 0.007], 0.017, 0.004, Color("#2e2a28"), Color("#1e1a18"))
	m.blob(Vector3(0, 0.028, 0), Vector3(0.024, 0.015, 0.015), float(variant), wool.darkened(0.2), wool, 0.18, true)
	m.blob(Vector3(-0.008, 0.035, 0), Vector3(0.016, 0.01, 0.012), float(variant) + 2.0, wool.darkened(0.1), wool, 0.2, true)
	m.part = 3.0
	m.pivot = Vector2(0.018, 0.032)
	m.blob(Vector3(0.028, 0.034, 0), Vector3(0.009, 0.007, 0.006), 4.0, face.darkened(0.2), face, 0.1, true, Vector3(INF, 0, 0), 0)
	m.box(Vector3(0.024, 0.038, 0.007), Vector3(0.005, 0.0025, 0.006), face)
	m.box(Vector3(0.024, 0.038, -0.007), Vector3(0.005, 0.0025, 0.006), face)
	m.part = 0.0


static func _cow(m: MB, variant: int) -> void:
	var cols := [Color("#6e4b32"), Color("#2a2725"), Color("#a07a52"), Color("#d6cfc2")]
	var base: Color = cols[variant % cols.size()]
	_legs(m, [0.02, -0.02], [-0.009, 0.009], 0.022, 0.0055, base.darkened(0.2), Color("#2a2420"))
	m.blob(Vector3(0, 0.036, 0), Vector3(0.032, 0.016, 0.015), float(variant) * 2.0, base.darkened(0.25), base, 0.08, true)
	if variant % 4 == 1 or variant % 4 == 3:
		var spot := Color("#ece6da") if variant % 4 == 1 else Color("#3a332d")
		m.blob(Vector3(-0.008, 0.044, 0.008), Vector3(0.012, 0.008, 0.009), 9.0, spot, spot, 0.2, true)
		m.blob(Vector3(0.01, 0.04, -0.01), Vector3(0.01, 0.008, 0.008), 11.0, spot, spot, 0.2, true)
	m.part = 3.0
	m.pivot = Vector2(0.026, 0.042)
	m.box(Vector3(0.036, 0.043, 0), Vector3(0.016, 0.013, 0.012), base, base.lightened(0.05))
	m.box(Vector3(0.045, 0.039, 0), Vector3(0.006, 0.009, 0.011), Color("#c9a090"))
	m.box(Vector3(0.032, 0.05, 0.008), Vector3(0.003, 0.006, 0.003), Color("#d8d0c0"))
	m.box(Vector3(0.032, 0.05, -0.008), Vector3(0.003, 0.006, 0.003), Color("#d8d0c0"))
	m.part = 7.0
	m.pivot = Vector2(-0.03, 0.044)
	m.box(Vector3(-0.033, 0.034, 0), Vector3(0.002, 0.02, 0.002), base.darkened(0.2))
	m.part = 0.0


static func _deer(m: MB, variant: int) -> void:
	var fur := Color("#7c5e48") if variant % 2 == 0 else Color("#6e5442")
	var belly := Color("#cdb59a")
	_legs(m, [0.016, -0.015], [-0.006, 0.006], 0.03, 0.0032, fur.darkened(0.15), Color("#2a2420"))
	m.blob(Vector3(0, 0.038, 0), Vector3(0.024, 0.011, 0.01), 3.0 + float(variant), belly, fur, 0.08, true)
	m.box(Vector3(-0.024, 0.042, 0), Vector3(0.004, 0.006, 0.006), Color("#efe6d6"))
	m.part = 3.0
	m.pivot = Vector2(0.016, 0.042)
	m.rod(Vector3(0.016, 0.04, 0), Vector3(0.026, 0.062, 0), 0.006, 0.0045, 6, fur, fur)
	m.blob(Vector3(0.031, 0.064, 0), Vector3(0.009, 0.006, 0.0055), 5.0, fur.darkened(0.1), fur, 0.1, true, Vector3(INF, 0, 0), 0)
	m.box(Vector3(0.026, 0.07, 0.005), Vector3(0.003, 0.006, 0.004), fur)
	m.box(Vector3(0.026, 0.07, -0.005), Vector3(0.003, 0.006, 0.004), fur)
	if variant % 2 == 0:
		var ant := Color("#d8c8a8")
		for sz_v in [-1.0, 1.0]:
			var sz: float = sz_v
			var b0 := Vector3(0.028, 0.068, sz * 0.003)
			var t0 := b0 + Vector3(-0.004, 0.02, sz * 0.008)
			m.rod(b0, t0, 0.0012, 0.0008, 4, ant, ant)
			m.rod(b0 + Vector3(-0.001, 0.008, sz * 0.003), b0 + Vector3(0.006, 0.016, sz * 0.007), 0.0009, 0.0006, 3, ant, ant)
			m.rod(b0 + Vector3(-0.003, 0.014, sz * 0.005), b0 + Vector3(-0.01, 0.02, sz * 0.009), 0.0009, 0.0006, 3, ant, ant)
	m.part = 0.0


static func _hare(m: MB) -> void:
	var fur := Color("#8a7a62")
	_legs(m, [0.006, -0.006], [-0.003, 0.003], 0.005, 0.0025, fur.darkened(0.1), fur.darkened(0.2))
	m.blob(Vector3(-0.002, 0.009, 0), Vector3(0.011, 0.008, 0.007), 2.0, fur.darkened(0.15), fur, 0.1, true)
	m.box(Vector3(-0.013, 0.01, 0), Vector3(0.004, 0.004, 0.004), Color("#e8e2d6"))
	m.part = 3.0
	m.pivot = Vector2(0.006, 0.012)
	m.blob(Vector3(0.01, 0.015, 0), Vector3(0.006, 0.005, 0.0045), 3.0, fur.darkened(0.1), fur, 0.1, true, Vector3(INF, 0, 0), 0)
	m.box(Vector3(0.007, 0.024, 0.002), Vector3(0.002, 0.012, 0.0028), fur.darkened(0.1))
	m.box(Vector3(0.007, 0.024, -0.002), Vector3(0.002, 0.012, 0.0028), fur.darkened(0.1))
	m.part = 0.0


static func _duck(m: MB, variant: int) -> void:
	var body := Color("#6b5a44") if variant % 2 == 0 else Color("#8a8070")
	var head := Color("#2f4a3a") if variant % 2 == 0 else Color("#6b5a44")
	m.blob(Vector3(0, 0.005, 0), Vector3(0.012, 0.006, 0.0075), 1.0, body.darkened(0.2), body, 0.1, true)
	m.box(Vector3(-0.011, 0.008, 0), Vector3(0.005, 0.004, 0.005), body.darkened(0.1))
	m.part = 3.0
	m.pivot = Vector2(0.008, 0.008)
	m.rod(Vector3(0.008, 0.008, 0), Vector3(0.011, 0.016, 0), 0.0028, 0.0025, 5, head, head)
	m.blob(Vector3(0.012, 0.017, 0), Vector3(0.0045, 0.004, 0.0038), 2.0, head, head.lightened(0.1), 0.05, true, Vector3(INF, 0, 0), 0)
	m.box(Vector3(0.018, 0.016, 0), Vector3(0.006, 0.002, 0.003), Color("#c9a040"))
	m.part = 0.0


## Mensch, 0,055 hoch. variant wählt Kleidung, Haut, Haare, Kleid oder Hose, Hut.
static func _person(m: MB, variant: int) -> void:
	var cloth: Color = CLOTHES[variant % CLOTHES.size()]
	var pants: Color = [Color("#4a4038"), Color("#3e4652"), Color("#5a4a3a")][variant % 3]
	var skin: Color = SKIN_C[(variant / 2) % SKIN_C.size()]
	var hair: Color = HAIR[(variant * 3 + 1) % HAIR.size()]
	var dress := variant % 3 == 1
	var hip := 0.024
	m.hip = hip
	# Beine
	for zi in 2:
		var z := -0.0042 if zi == 0 else 0.0042
		m.part = 1.0 if zi == 0 else 2.0
		m.pivot = Vector2(0, hip)
		m.box(Vector3(0, hip * 0.52, z), Vector3(0.0062, hip * 0.96, 0.0058), pants)
		m.box(Vector3(0.0015, 0.0018, z), Vector3(0.009, 0.0036, 0.0062), Color("#2a221c"))
	# Oberkörper (bückt sich)
	m.part = 4.0
	m.pivot = Vector2(0, hip)
	if dress:
		m.cyl(Vector3(0, hip * 0.35, 0), 0.0105, 0.0075, hip * 0.75, 8, cloth.darkened(0.08), cloth, false)
	m.box(Vector3(0, hip + 0.0105, 0), Vector3(0.011, 0.021, 0.0152), cloth, cloth.lightened(0.05))
	m.box(Vector3(0, hip + 0.001, 0), Vector3(0.0115, 0.0028, 0.0156), cloth.darkened(0.3))
	m.box(Vector3(0, hip + 0.0225, 0), Vector3(0.004, 0.003, 0.004), skin)
	m.blob(Vector3(0.0006, hip + 0.0285, 0), Vector3(0.0062, 0.0068, 0.0058), 1.0 + float(variant), skin.darkened(0.12), skin, 0.06, true,
		Vector3(INF, 0, 0), 1)
	if variant % 4 == 3:
		m.cyl(Vector3(0, hip + 0.032, 0), 0.011, 0.011, 0.0012, 10, Color("#8a7350"), Color("#8a7350"))
		m.cyl(Vector3(0, hip + 0.033, 0), 0.0058, 0.0048, 0.005, 8, Color("#7a6346"), Color("#7a6346"))
	else:
		m.blob(Vector3(-0.0012, hip + 0.0315, 0), Vector3(0.0062, 0.0045, 0.006), 3.0, hair.darkened(0.1), hair, 0.08, true,
			Vector3(INF, 0, 0), 1, -0.1)
	if variant % 6 == 5:
		# Gläubige: violettes Tuch
		m.box(Vector3(-0.0005, hip + 0.019, 0), Vector3(0.0118, 0.004, 0.016), Color("#6a4f8a"))
	# Arme
	for zi in 2:
		var z := -0.0098 if zi == 0 else 0.0098
		m.part = 5.0 if zi == 0 else 6.0
		m.pivot = Vector2(0, hip + 0.019)
		m.box(Vector3(0, hip + 0.0105, z), Vector3(0.0045, 0.018, 0.0042), cloth.darkened(0.06))
		m.box(Vector3(0, hip + 0.0005, z), Vector3(0.0042, 0.0035, 0.004), skin)
	m.part = 0.0
	m.hip = 0.0
	m.pivot = Vector2.ZERO
