class_name Models
extends RefCounted
## Prozedurale Spielzeug-Modelle: runde Kanten, weiche Farben, Plastik-Look.
## Materialien und Meshes werden zwischengespeichert, damit es am Handy flüssig bleibt.

const SKIN := Color("#f6cfa6")
const WHITE := Color("#fffaf2")
const WOOD := Color("#a8743f")
const DARK := Color("#4a3a32")

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}


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
	m.no_depth_test = false
	_mats[key] = m
	return m


# =============================================================================
# Abgerundete Box (das Herzstück des Spielzeug-Looks)
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
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


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
		# gegen den Uhrzeigersinn von außen: Reihenfolge tauschen
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


# =============================================================================
# Grundformen
# =============================================================================

static func _add(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


## Abgerundete Box. pos = Mitte.
static func rbox(parent: Node3D, size: Vector3, radius: float, color: Color, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, material: Material = null) -> MeshInstance3D:
	return _add(parent, rounded_box_mesh(size, radius), material if material != null else mat(color), pos, rot_deg)


static func box(parent: Node3D, size: Vector3, color: Color, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, material: Material = null) -> MeshInstance3D:
	var key := "box|%s" % size
	if not _meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[key] = bm
	return _add(parent, _meshes[key], material if material != null else mat(color), pos, rot_deg)


## Zylinder/Kegel, pos = Mitte der Grundfläche.
static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, color: Color, pos: Vector3, sides: int = 12, rot_deg: Vector3 = Vector3.ZERO, material: Material = null) -> MeshInstance3D:
	var key := "cyl|%.3f|%.3f|%.3f|%d" % [r_top, r_bot, h, sides]
	if not _meshes.has(key):
		var cm := CylinderMesh.new()
		cm.top_radius = r_top
		cm.bottom_radius = r_bot
		cm.height = h
		cm.radial_segments = sides
		cm.rings = 1
		_meshes[key] = cm
	var mi := _add(parent, _meshes[key], material if material != null else mat(color), pos, rot_deg)
	mi.position = pos + mi.basis.y * (h * 0.5)
	return mi


static func cone(parent: Node3D, r: float, h: float, color: Color, pos: Vector3, sides: int = 12) -> MeshInstance3D:
	return cyl(parent, 0.0, r, h, color, pos, sides)


static func sphere(parent: Node3D, r: float, color: Color, pos: Vector3, material: Material = null, squash: float = 1.0) -> MeshInstance3D:
	var key := "sph|%.3f" % r
	if not _meshes.has(key):
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 16
		sm.rings = 8
		_meshes[key] = sm
	var mi := _add(parent, _meshes[key], material if material != null else mat(color), pos)
	if squash != 1.0:
		mi.scale = Vector3(1.0, squash, 1.0)
	return mi


## Satteldach, pos = Mitte der Unterkante, First entlang z.
static func roof(parent: Node3D, size: Vector3, color: Color, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var key := "prism|%s" % size
	if not _meshes.has(key):
		var pm := PrismMesh.new()
		pm.size = size
		_meshes[key] = pm
	return _add(parent, _meshes[key], mat(color, 0.45), pos + Vector3(0, size.y * 0.5, 0), rot_deg)


# =============================================================================
# Landschaft
# =============================================================================

static func tree(parent: Node3D, pos: Vector3, s: float, color: Color) -> void:
	cyl(parent, 0.016 * s, 0.022 * s, 0.07 * s, WOOD, pos, 8)
	sphere(parent, 0.085 * s, color, pos + Vector3(0, 0.12 * s, 0), null, 1.15)


static func pine(parent: Node3D, pos: Vector3, s: float, color: Color) -> void:
	cyl(parent, 0.014 * s, 0.018 * s, 0.05 * s, WOOD, pos, 8)
	cone(parent, 0.08 * s, 0.13 * s, color, pos + Vector3(0, 0.04 * s, 0), 10)
	cone(parent, 0.06 * s, 0.1 * s, color.lightened(0.08), pos + Vector3(0, 0.11 * s, 0), 10)


static func rock(parent: Node3D, pos: Vector3, s: float, snow: bool) -> void:
	var h := 0.26 * s
	var r := 0.13 * s
	cone(parent, r, h, Color("#a9a196"), pos, 7)
	if snow:
		cone(parent, r * 0.42, h * 0.42, WHITE, pos + Vector3(0, h * 0.58, 0), 7)


static func flame(parent: Node3D, pos: Vector3, s: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	cone(n, 0.06 * s, 0.16 * s, Color("#ff7a1a"), Vector3.ZERO, 8).material_override = mat(Color("#ff7a1a"), 0.6, 1.6)
	cone(n, 0.035 * s, 0.11 * s, Color("#ffd23f"), Vector3(0.0, 0.01, 0.0), 8).material_override = mat(Color("#ffd23f"), 0.6, 2.0)
	return n


# =============================================================================
# Gebäude (Farbe = Volk)
# =============================================================================

static func house(parent: Node3D, pos: Vector3, roof_c: Color, s: float = 1.0, rot: float = 0.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot
	parent.add_child(n)
	var w := 0.13 * s
	var h := 0.1 * s
	rbox(n, Vector3(w, h, w * 0.85), 0.012 * s, WHITE, Vector3(0, h * 0.5, 0))
	roof(n, Vector3(w * 1.18, h * 0.75, w * 0.98), roof_c, Vector3(0, h, 0))
	box(n, Vector3(w * 0.26, h * 0.5, 0.006), DARK, Vector3(0, h * 0.25, w * 0.43))


static func church(parent: Node3D, pos: Vector3, c: Color) -> void:
	rbox(parent, Vector3(0.2, 0.14, 0.15), 0.015, WHITE, pos + Vector3(-0.02, 0.07, 0))
	roof(parent, Vector3(0.22, 0.1, 0.17), c, pos + Vector3(-0.02, 0.14, 0), Vector3(0, 90, 0))
	rbox(parent, Vector3(0.085, 0.27, 0.085), 0.012, WHITE, pos + Vector3(0.1, 0.135, 0))
	cone(parent, 0.065, 0.15, c, pos + Vector3(0.1, 0.27, 0), 4)
	sphere(parent, 0.016, Color("#ffd75e"), pos + Vector3(0.1, 0.435, 0), mat(Color("#ffd75e"), 0.3, 0.4, 0.4))
	cyl(parent, 0.022, 0.022, 0.004, DARK, pos + Vector3(0.1, 0.19, 0.043), 12, Vector3(90, 0, 0))
	box(parent, Vector3(0.05, 0.07, 0.006), DARK, pos + Vector3(-0.02, 0.035, 0.077))


static func market(parent: Node3D, pos: Vector3, c: Color) -> void:
	for k in 2:
		var o := pos + Vector3(-0.08 + k * 0.16, 0, -0.03 + k * 0.06)
		for dx in [-0.05, 0.05]:
			cyl(parent, 0.006, 0.006, 0.11, WOOD, o + Vector3(dx, 0, 0.035), 6)
		rbox(parent, Vector3(0.13, 0.045, 0.08), 0.01, WOOD, o + Vector3(0, 0.022, -0.005))
		for i in 4:
			var stripe := c if i % 2 == 0 else WHITE
			box(parent, Vector3(0.036, 0.012, 0.1), stripe, o + Vector3(-0.054 + i * 0.036, 0.115, 0.0), Vector3(-14, 0, 0))
		sphere(parent, 0.018, Color("#ff6b5a"), o + Vector3(-0.03, 0.055, -0.01))
		sphere(parent, 0.018, Color("#ffcf4a"), o + Vector3(0.0, 0.055, -0.015))
		sphere(parent, 0.018, Color("#8bd16a"), o + Vector3(0.03, 0.055, -0.01))


# =============================================================================
# Figuren
# =============================================================================

static func person(parent: Node3D, pos: Vector3, c: Color) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	cyl(n, 0.017, 0.024, 0.05, c, Vector3.ZERO, 10)
	sphere(n, 0.019, SKIN, Vector3(0, 0.068, 0))
	return n


static func animal(parent: Node3D, pos: Vector3, kind: String, rot: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot
	parent.add_child(n)
	match kind:
		"forest":   # Hirsch
			var brown := Color("#b8794a")
			rbox(n, Vector3(0.07, 0.035, 0.032), 0.014, brown, Vector3(0, 0.05, 0))
			for lx in [-0.025, 0.025]:
				for lz in [-0.01, 0.01]:
					box(n, Vector3(0.008, 0.035, 0.008), brown.darkened(0.2), Vector3(lx, 0.017, lz))
			rbox(n, Vector3(0.03, 0.03, 0.026), 0.01, brown, Vector3(0.045, 0.08, 0))
			box(n, Vector3(0.004, 0.03, 0.004), Color("#f2e3c6"), Vector3(0.042, 0.105, 0.009), Vector3(0, 0, 20))
			box(n, Vector3(0.004, 0.03, 0.004), Color("#f2e3c6"), Vector3(0.042, 0.105, -0.009), Vector3(0, 0, 20))
		"lake":     # Ente
			sphere(n, 0.026, Color("#ffd84a"), Vector3(0, 0.018, 0), null, 0.75)
			sphere(n, 0.016, Color("#ffd84a"), Vector3(0.022, 0.04, 0))
			box(n, Vector3(0.016, 0.006, 0.01), Color("#ff9a3c"), Vector3(0.04, 0.038, 0))
		"mountain": # Steinbock
			rbox(n, Vector3(0.06, 0.035, 0.03), 0.013, Color("#f1ece4"), Vector3(0, 0.045, 0))
			for lx in [-0.02, 0.02]:
				box(n, Vector3(0.008, 0.03, 0.02), Color("#cfc7bb"), Vector3(lx, 0.015, 0))
			sphere(n, 0.016, Color("#f1ece4"), Vector3(0.035, 0.07, 0))
			cyl(n, 0.003, 0.006, 0.03, Color("#8a7a68"), Vector3(0.03, 0.08, 0), 6, Vector3(0, 0, -30))
		_:          # Hase
			sphere(n, 0.022, Color("#e9e2d8"), Vector3(0, 0.022, 0), null, 0.85)
			sphere(n, 0.014, Color("#e9e2d8"), Vector3(0.02, 0.042, 0))
			box(n, Vector3(0.006, 0.03, 0.008), Color("#e9e2d8"), Vector3(0.018, 0.068, 0.006))
			box(n, Vector3(0.006, 0.03, 0.008), Color("#e9e2d8"), Vector3(0.018, 0.068, -0.006))
	return n
