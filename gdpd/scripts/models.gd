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
static var _arrays: Dictionary = {}     # Mesh-Arrays eigener Meshes (für batched(), ohne RenderingServer)


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
	var arrays := st.commit_to_arrays()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[key] = mesh
	_arrays[mesh.get_instance_id()] = arrays
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

## Laubbaum: brauner Stamm, runde Krone aus drei Kugeln (oben heller).
static func tree(parent: Node3D, pos: Vector3, s: float, color: Color) -> void:
	cyl(parent, 0.014 * s, 0.02 * s, 0.1 * s, WOOD, pos, 7)
	sphere(parent, 0.075 * s, color.darkened(0.08), pos + Vector3(-0.035 * s, 0.12 * s, 0.01 * s), null, 1.0)
	sphere(parent, 0.07 * s, color.darkened(0.04), pos + Vector3(0.04 * s, 0.115 * s, -0.01 * s), null, 1.0)
	sphere(parent, 0.08 * s, color.lightened(0.08), pos + Vector3(0, 0.17 * s, 0), null, 1.05)


## Tanne: Stamm und drei gestufte Kegel.
static func pine(parent: Node3D, pos: Vector3, s: float, color: Color) -> void:
	cyl(parent, 0.013 * s, 0.017 * s, 0.05 * s, WOOD, pos, 7)
	cone(parent, 0.085 * s, 0.12 * s, color.darkened(0.06), pos + Vector3(0, 0.04 * s, 0), 9)
	cone(parent, 0.068 * s, 0.11 * s, color, pos + Vector3(0, 0.1 * s, 0), 9)
	cone(parent, 0.048 * s, 0.1 * s, color.lightened(0.08), pos + Vector3(0, 0.16 * s, 0), 9)


static func rock(parent: Node3D, pos: Vector3, s: float, snow: bool) -> void:
	var h := 0.26 * s
	var r := 0.13 * s
	cone(parent, r, h, Color("#77736f"), pos, 7)
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


# =============================================================================
# Neue Gebäude (Version „Gleichgewicht“)
# =============================================================================

static func tower(parent: Node3D, pos: Vector3, w: float, h: float, accent: Color) -> void:
	rbox(parent, Vector3(w, h, w), 0.012, Color("#f4f1ec"), pos + Vector3(0, h * 0.5, 0))
	var floors := int(h / 0.05)
	for i in floors:
		box(parent, Vector3(w + 0.004, 0.012, w + 0.004), Color("#7fb3d9"), pos + Vector3(0, 0.03 + i * 0.05, 0), Vector3.ZERO,
			mat(Color("#7fb3d9"), 0.15, 0.25))
	rbox(parent, Vector3(w * 1.06, 0.02, w * 1.06), 0.006, accent, pos + Vector3(0, h + 0.01, 0))


static func chapel(parent: Node3D, pos: Vector3, c: Color) -> void:
	rbox(parent, Vector3(0.12, 0.09, 0.1), 0.012, WHITE, pos + Vector3(0, 0.045, 0))
	roof(parent, Vector3(0.14, 0.07, 0.11), c, pos + Vector3(0, 0.09, 0), Vector3(0, 90, 0))
	rbox(parent, Vector3(0.04, 0.05, 0.04), 0.006, WHITE, pos + Vector3(0.0, 0.17, 0))
	cone(parent, 0.032, 0.06, c, pos + Vector3(0, 0.195, 0), 4)
	box(parent, Vector3(0.03, 0.05, 0.006), DARK, pos + Vector3(0, 0.025, 0.052))


static func cathedral(parent: Node3D, pos: Vector3, c: Color) -> void:
	var gold := mat(Color("#ffd75e"), 0.3, 0.5, 0.4)
	rbox(parent, Vector3(0.26, 0.16, 0.18), 0.018, WHITE, pos + Vector3(0, 0.08, -0.02))
	roof(parent, Vector3(0.28, 0.11, 0.2), c, pos + Vector3(0, 0.16, -0.02), Vector3(0, 90, 0))
	for sx in [-0.1, 0.1]:
		rbox(parent, Vector3(0.07, 0.3, 0.07), 0.01, WHITE, pos + Vector3(sx, 0.15, 0.08))
		cone(parent, 0.05, 0.14, c, pos + Vector3(sx, 0.3, 0.08), 4)
		sphere(parent, 0.012, Color.WHITE, pos + Vector3(sx, 0.45, 0.08), gold)
	cyl(parent, 0.035, 0.035, 0.006, Color.WHITE, pos + Vector3(0, 0.1, 0.07), 16, Vector3(90, 0, 0), gold)
	box(parent, Vector3(0.05, 0.07, 0.006), DARK, pos + Vector3(0, 0.035, 0.072))


static func workshop(parent: Node3D, pos: Vector3) -> void:
	rbox(parent, Vector3(0.16, 0.09, 0.12), 0.01, Color("#c9a77c"), pos + Vector3(0, 0.045, 0))
	roof(parent, Vector3(0.18, 0.06, 0.14), Color("#7a5a3a"), pos + Vector3(0, 0.09, 0))
	box(parent, Vector3(0.05, 0.06, 0.006), DARK, pos + Vector3(0.0, 0.03, 0.062))
	cyl(parent, 0.012, 0.012, 0.08, WOOD, pos + Vector3(0.12, 0.012, 0.05), 6, Vector3(90, 0, 0))
	cyl(parent, 0.012, 0.012, 0.08, WOOD, pos + Vector3(0.14, 0.012, 0.03), 6, Vector3(90, 0, 0))
	rbox(parent, Vector3(0.04, 0.03, 0.025), 0.005, Color("#55585f"), pos + Vector3(-0.12, 0.015, 0.06))


static func factory(parent: Node3D, pos: Vector3, big: bool) -> Array:
	var smoke: Array = []
	var wall := Color("#b9b2a8") if not big else Color("#a39d95")
	var w := 0.26 if big else 0.2
	rbox(parent, Vector3(w, 0.1, 0.16), 0.01, wall, pos + Vector3(0, 0.05, 0))
	var teeth := 3 if big else 2
	for i in teeth:
		var x: float = -w * 0.5 + w / teeth * (i + 0.5)
		roof(parent, Vector3(w / teeth, 0.05, 0.16), Color("#6f7682"), pos + Vector3(x, 0.1, 0), Vector3(0, 0, 0))
	var stacks := 2 if big else 1
	for i in stacks:
		var sp := pos + Vector3(w * 0.32 - i * 0.09, 0, -0.1)
		cyl(parent, 0.022, 0.026, 0.26 + i * 0.04, Color("#8d6e63"), sp, 10)
		box(parent, Vector3(0.05, 0.012, 0.05), Color("#e5483c"), sp + Vector3(0, 0.2, 0))
		var puff := Node3D.new()
		puff.position = sp + Vector3(0, 0.3 + i * 0.04, 0)
		parent.add_child(puff)
		sphere(puff, 0.035, Color(0.82, 0.82, 0.85, 0.9), Vector3.ZERO)
		smoke.append(puff)
	if big:
		for k in 2:
			cyl(parent, 0.04, 0.04, 0.07, Color("#cfd4da"), pos + Vector3(-0.12 + k * 0.08, 0, 0.14), 14)
	return smoke


static func windmill(parent: Node3D, pos: Vector3) -> Node3D:
	cyl(parent, 0.07, 0.1, 0.3, WHITE, pos, 12)
	cone(parent, 0.085, 0.1, Color("#e5483c"), pos + Vector3(0, 0.3, 0), 12)
	var hub := Node3D.new()
	hub.position = pos + Vector3(0, 0.27, 0.09)
	parent.add_child(hub)
	for i in 4:
		var blade := Node3D.new()
		blade.rotation.z = i * PI * 0.5
		hub.add_child(blade)
		box(blade, Vector3(0.035, 0.2, 0.006), Color("#f7efe1"), Vector3(0, 0.11, 0))
	sphere(hub, 0.02, WOOD, Vector3.ZERO)
	return hub


static func lighthouse(parent: Node3D, pos: Vector3) -> MeshInstance3D:
	for i in 4:
		var col := Color("#e5483c") if i % 2 == 0 else WHITE
		cyl(parent, 0.065 - i * 0.008, 0.075 - i * 0.008, 0.09, col, pos + Vector3(0, i * 0.09, 0), 14)
	var lamp := sphere(parent, 0.05, Color("#fff3a0"), pos + Vector3(0, 0.4, 0), mat(Color("#fff3a0"), 0.2, 3.0))
	cone(parent, 0.06, 0.06, Color("#e5483c"), pos + Vector3(0, 0.44, 0), 14)
	return lamp


static func world_tree(parent: Node3D, pos: Vector3) -> void:
	cyl(parent, 0.05, 0.08, 0.22, Color("#8a5a35"), pos, 10)
	sphere(parent, 0.17, Color("#3f9a4a"), pos + Vector3(0, 0.33, 0), null, 0.85)
	sphere(parent, 0.11, Color("#56b456"), pos + Vector3(0.1, 0.4, 0.05))
	sphere(parent, 0.1, Color("#4aa64f"), pos + Vector3(-0.1, 0.38, -0.04))
	for k in 5:
		var a: float = k * TAU / 5.0
		sphere(parent, 0.018, Color("#ff7aa8"), pos + Vector3(cos(a) * 0.15, 0.3 + (k % 2) * 0.08, sin(a) * 0.15))


static func stone_circle(parent: Node3D, pos: Vector3) -> MeshInstance3D:
	for k in 7:
		var a: float = k * TAU / 7.0
		rbox(parent, Vector3(0.045, 0.14 + (k % 2) * 0.03, 0.03), 0.01, Color("#a49cb8"), pos + Vector3(cos(a) * 0.2, 0.075, sin(a) * 0.2), Vector3(0, -rad_to_deg(a), 0))
	return cyl(parent, 0.08, 0.08, 0.01, Color("#b9a8ff"), pos + Vector3(0, 0.005, 0), 20, Vector3.ZERO, mat(Color("#b9a8ff"), 0.3, 2.0))


static func pyramid(parent: Node3D, pos: Vector3) -> void:
	cyl(parent, 0.0, 0.3, 0.3, Color("#f2d15c"), pos, 4, Vector3(0, 45, 0), mat(Color("#f2d15c"), 0.35, 0.0, 0.2))
	cone(parent, 0.04, 0.04, Color("#fff6c2"), pos + Vector3(0, 0.27, 0), 4).material_override = mat(Color("#fff6c2"), 0.2, 1.5)


static func observatory(parent: Node3D, pos: Vector3) -> Node3D:
	cyl(parent, 0.14, 0.15, 0.14, WHITE, pos, 18)
	var dome := Node3D.new()
	dome.position = pos + Vector3(0, 0.14, 0)
	parent.add_child(dome)
	sphere(dome, 0.135, Color("#4fb8e8"), Vector3.ZERO, mat(Color("#4fb8e8"), 0.25, 0.0, 0.3), 0.75)
	cyl(dome, 0.02, 0.025, 0.16, Color("#44506a"), Vector3(0.0, 0.04, 0.04), 10, Vector3(-40, 0, 0))
	return dome


# =============================================================================
# gdpd: neue Arten (Acker, Tiere, Paradies, Kirche, Industrie) und Zustände
# Alles aus zwischengespeicherten Meshes; viele Kleinteile (Halme, Gras) werden zu EINEM Mesh
# zusammengefasst, damit ein Feld nur wenige Draw-Calls braucht.
# =============================================================================

const GOLD := Color("#ffd75e")
const FAITH := Color("#8b6ee0")
const SOIL := Color("#94603a")
const WHEAT := Color("#f6d25a")
const WATER_C := Color("#3fb4ef")


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


static func sphere_mesh(r: float, segments: int = 16, rings: int = 8) -> Mesh:
	var key := "sph|%.3f" % r if segments == 16 and rings == 8 else "sph|%.3f|%d|%d" % [r, segments, rings]
	if not _meshes.has(key):
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = segments
		sm.rings = rings
		_meshes[key] = sm
	return _meshes[key]


## Viele Kopien einer Grundform als EIN Mesh (ein Draw-Call). Wird unter key zwischengespeichert,
## die Transformationen müssen also für denselben key immer gleich sein.
## Rechnet selbst (statt SurfaceTool.append_from), damit es auch ohne Grafik (headless) Daten hat.
static func batched(key: String, base: Mesh, xforms: Array) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var src: Array = []
	if base is PrimitiveMesh:
		src = (base as PrimitiveMesh).get_mesh_arrays()
	elif _arrays.has(base.get_instance_id()):
		src = _arrays[base.get_instance_id()]
	else:
		src = base.surface_get_arrays(0)
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
	return m


static func add_mesh(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _add(parent, mesh, material, pos)


## Unbeleuchtet und beidseitig (Regenbogen, Heiligenschein, Dunst).
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


## Sheddach-Zahn: Prisma mit senkrechter Seite rechts (+x), First entlang z.
static func saw(parent: Node3D, size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var key := "saw|%s" % size
	if not _meshes.has(key):
		var pm := PrismMesh.new()
		pm.size = size
		pm.left_to_right = 1.0
		_meshes[key] = pm
	return _add(parent, _meshes[key], mat(color, 0.5), pos + Vector3(0, size.y * 0.5, 0))


## Halbkreis-Band in der x/y-Ebene (Regenbogen), Mitte = pos.
static func arc_mesh(r_in: float, r_out: float, segs: int = 18) -> Mesh:
	var key := "arc|%.3f|%.3f|%d" % [r_in, r_out, segs]
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3(0, 0, 1))
	for i in segs:
		var a0 := PI * float(i) / float(segs)
		var a1 := PI * float(i + 1) / float(segs)
		var i0 := Vector3(cos(a0) * r_in, sin(a0) * r_in, 0)
		var o0 := Vector3(cos(a0) * r_out, sin(a0) * r_out, 0)
		var i1 := Vector3(cos(a1) * r_in, sin(a1) * r_in, 0)
		var o1 := Vector3(cos(a1) * r_out, sin(a1) * r_out, 0)
		st.add_vertex(i0)
		st.add_vertex(o0)
		st.add_vertex(o1)
		st.add_vertex(i0)
		st.add_vertex(o1)
		st.add_vertex(i1)
	var m := st.commit()
	_meshes[key] = m
	return m


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


## Grasbüschel als ein Mesh. variant wählt eine von wenigen festen Anordnungen.
static func grass_patch(parent: Node3D, variant: int, count: int, color: Color, spread: float = 0.28) -> MeshInstance3D:
	var key := "grass|%d|%d|%.2f" % [variant, count, spread]
	var mesh: Mesh
	if _meshes.has(key):
		mesh = _meshes[key]
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242 + variant * 131
		var xf: Array = []
		for k in count:
			var gp := Vector3(rng.randf_range(-spread, spread), 0.0, rng.randf_range(-spread, spread))
			var hgt := rng.randf_range(0.7, 1.15)
			xf.append(Transform3D(Basis.from_scale(Vector3(1, hgt, 1)), gp + Vector3(0, 0.03 * hgt, 0)))
			xf.append(Transform3D(Basis(Vector3(0, 0, 1), 0.35).scaled(Vector3(0.8, hgt * 0.8, 0.8)), gp + Vector3(0.016, 0.024 * hgt, 0.008)))
			xf.append(Transform3D(Basis(Vector3(0, 0, 1), -0.35).scaled(Vector3(0.8, hgt * 0.75, 0.8)), gp + Vector3(-0.016, 0.022 * hgt, -0.006)))
		mesh = batched(key, cyl_mesh(0.0, 0.02, 0.06, 4), xf)
	var mi := _add(parent, mesh, mat(color, 0.8), Vector3.ZERO)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Acker: Furchen, drei Reihen Weizen, zwei Reihen Gemüse, eine Vogelscheuche. 5 Draw-Calls für die Reihen.
static func crop_field(parent: Node3D, pos: Vector3, withered: bool = false) -> void:
	var furrow_t: Array = []
	var stalk_t: Array = []
	var ear_t: Array = []
	var veg_t: Array = []
	for i in 5:
		var z := -0.24 + i * 0.12
		furrow_t.append(Transform3D(Basis(), Vector3(0, 0.014, z)))
		for j in 6:
			var x := -0.24 + j * 0.096 + (0.024 if i % 2 == 1 else 0.0)
			if i % 2 == 0:
				for d in [-0.013, 0.013]:
					var dd: float = d
					var tilt := Basis(Vector3(0, 0, 1), dd * 9.0)
					stalk_t.append(Transform3D(tilt, Vector3(x + dd, 0.028 + 0.042, z)))
					ear_t.append(Transform3D(tilt * Basis.from_scale(Vector3(0.75, 2.1, 0.75)), Vector3(x + dd * 1.9, 0.028 + 0.1, z)))
			else:
				veg_t.append(Transform3D(Basis.from_scale(Vector3(1.0, 0.75, 1.0)), Vector3(x, 0.05, z)))
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var furrows := batched("acker_furrow", rounded_box_mesh(Vector3(0.62, 0.03, 0.08), 0.013), furrow_t)
	var stalks := batched("acker_stalk", cyl_mesh(0.005, 0.006, 0.085, 5), stalk_t)
	var ears := batched("acker_ear", sphere_mesh(0.014, 8, 4), ear_t)
	var veg := batched("acker_veg", sphere_mesh(0.03, 8, 5), veg_t)
	var ear_c := Color("#b59a55") if withered else WHEAT
	var veg_c := Color("#9b9a4e") if withered else Color("#56b04f")
	_add(n, furrows, mat(SOIL, 0.85), Vector3.ZERO)
	_add(n, stalks, mat(ear_c.darkened(0.15), 0.7), Vector3.ZERO).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(n, ears, mat(ear_c, 0.6), Vector3.ZERO).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(n, veg, mat(veg_c, 0.7), Vector3.ZERO)
	# Vogelscheuche
	var sc := Vector3(0.2, 0.0, -0.02)
	cyl(n, 0.006, 0.007, 0.19, WOOD, sc, 6)
	box(n, Vector3(0.11, 0.011, 0.011), WOOD, sc + Vector3(0, 0.135, 0))
	rbox(n, Vector3(0.045, 0.055, 0.026), 0.008, Color("#e5574a"), sc + Vector3(0, 0.118, 0))
	sphere(n, 0.022, Color("#f2d48a"), sc + Vector3(0, 0.172, 0))
	cyl(n, 0.034, 0.034, 0.006, Color("#7a4f2e"), sc + Vector3(0, 0.186, 0), 10)
	cyl(n, 0.0, 0.022, 0.03, Color("#7a4f2e"), sc + Vector3(0, 0.19, 0), 10)


## Schaf: Wollknäuel mit dunklem Kopf.
static func sheep(parent: Node3D, pos: Vector3, rot: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot
	parent.add_child(n)
	var wool := Color("#fbf8f1")
	var face := Color("#3d3836")
	for lx in [-0.017, 0.017]:
		for lz in [-0.011, 0.011]:
			box(n, Vector3(0.008, 0.03, 0.008), face, Vector3(lx, 0.015, lz))
	sphere(n, 0.032, wool, Vector3(0, 0.05, 0), null, 0.8)
	sphere(n, 0.02, wool, Vector3(-0.024, 0.056, 0.008))
	sphere(n, 0.02, wool, Vector3(0.006, 0.066, -0.01))
	sphere(n, 0.016, face, Vector3(0.036, 0.058, 0))
	box(n, Vector3(0.012, 0.006, 0.01), face, Vector3(0.03, 0.07, 0.016), Vector3(0, 0, -20))
	box(n, Vector3(0.012, 0.006, 0.01), face, Vector3(0.03, 0.07, -0.016), Vector3(0, 0, -20))
	return n


## Hirsch mit Geweih (größer und deutlicher als das alte Waldtier).
static func deer(parent: Node3D, pos: Vector3, rot: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot
	parent.add_child(n)
	var brown := Color("#c07a45")
	var light := Color("#f2dcc0")
	for lx in [-0.026, 0.026]:
		for lz in [-0.011, 0.011]:
			box(n, Vector3(0.008, 0.045, 0.008), brown.darkened(0.25), Vector3(lx, 0.022, lz))
	rbox(n, Vector3(0.075, 0.038, 0.034), 0.015, brown, Vector3(0, 0.06, 0))
	sphere(n, 0.012, light, Vector3(-0.04, 0.068, 0))
	rbox(n, Vector3(0.02, 0.04, 0.02), 0.008, brown, Vector3(0.036, 0.085, 0), Vector3(0, 0, -25))
	rbox(n, Vector3(0.034, 0.024, 0.024), 0.009, brown, Vector3(0.05, 0.106, 0))
	sphere(n, 0.006, DARK, Vector3(0.068, 0.104, 0))
	for sz in [-1.0, 1.0]:
		var antler := Color("#f0e2c8")
		cyl(n, 0.003, 0.004, 0.04, antler, Vector3(0.046, 0.115, 0.008 * sz), 5, Vector3(sz * 20.0, 0, 10))
		cyl(n, 0.0025, 0.003, 0.02, antler, Vector3(0.048, 0.135, 0.016 * sz), 5, Vector3(sz * 55.0, 0, -20))
	return n


## Kirche mit Turm, goldenem Kreuz und warm leuchtenden Fenstern.
## Gibt den Heiligenschein zurück (Node3D, darf sich drehen und pulsieren).
static func faith_church(parent: Node3D, pos: Vector3) -> Node3D:
	var stone := WHITE
	var roof_c := FAITH
	var glow := mat(Color("#ffa63d"), 0.4, 1.3)
	var gold := mat(GOLD, 0.3, 0.9, 0.4)
	rbox(parent, Vector3(0.44, 0.02, 0.3), 0.01, Color("#e6ded0"), pos + Vector3(0.0, 0.01, -0.01))
	# Schiff
	var nave := pos + Vector3(-0.06, 0.02, -0.03)
	rbox(parent, Vector3(0.24, 0.15, 0.15), 0.014, stone, nave + Vector3(0, 0.075, 0))
	roof(parent, Vector3(0.19, 0.1, 0.27), roof_c, nave + Vector3(0, 0.15, 0), Vector3(0, 90, 0))
	for k in 3:
		var wx := -0.08 + k * 0.07
		box(parent, Vector3(0.03, 0.055, 0.008), Color.WHITE, nave + Vector3(wx, 0.072, 0.076), Vector3.ZERO, glow)
		cyl(parent, 0.015, 0.015, 0.008, Color.WHITE, nave + Vector3(wx, 0.1, 0.072), 10, Vector3(90, 0, 0), glow)
	# Turm
	var tw := pos + Vector3(0.12, 0.02, 0.0)
	rbox(parent, Vector3(0.1, 0.33, 0.1), 0.012, stone, tw + Vector3(0, 0.165, 0))
	rbox(parent, Vector3(0.112, 0.016, 0.112), 0.005, roof_c, tw + Vector3(0, 0.33, 0))
	box(parent, Vector3(0.05, 0.075, 0.006), DARK, tw + Vector3(0, 0.037, 0.051))
	cyl(parent, 0.026, 0.026, 0.006, Color.WHITE, tw + Vector3(0, 0.19, 0.051), 14, Vector3(90, 0, 0), glow)
	box(parent, Vector3(0.022, 0.04, 0.006), DARK, tw + Vector3(0, 0.27, 0.051))
	box(parent, Vector3(0.006, 0.04, 0.022), DARK, tw + Vector3(0.051, 0.27, 0))
	cyl(parent, 0.0, 0.076, 0.17, roof_c, tw + Vector3(0, 0.338, 0), 4, Vector3(0, 45, 0))
	# Kreuz
	box(parent, Vector3(0.012, 0.075, 0.012), Color.WHITE, tw + Vector3(0, 0.545, 0), Vector3.ZERO, gold)
	box(parent, Vector3(0.046, 0.012, 0.012), Color.WHITE, tw + Vector3(0, 0.558, 0), Vector3.ZERO, gold)
	# Heiligenschein: Ring über dem Kreuz und drei kleine Lichter, die um die Spitze kreisen
	var halo := Node3D.new()
	halo.position = tw + Vector3(0, 0.5, 0)
	parent.add_child(halo)
	var torus_key := "halo_torus"
	if not _meshes.has(torus_key):
		var t := TorusMesh.new()
		t.inner_radius = 0.05
		t.outer_radius = 0.062
		t.rings = 24
		t.ring_segments = 6
		_meshes[torus_key] = t
	var ring := _add(halo, _meshes[torus_key], glow2s(Color(1.0, 0.86, 0.4, 0.85)), Vector3(0, 0.1, 0))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 3:
		var a := TAU * float(k) / 3.0
		var spark := sphere(halo, 0.01, Color.WHITE, Vector3(cos(a) * 0.1, 0.02 * k, sin(a) * 0.1), mat(Color("#fff2b0"), 0.3, 3.0))
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return halo


## Industrie: Backsteinhalle mit Sheddach, zwei rot-weiße Schlote, Tank und Rohr.
## Gibt die Schlot-Öffnungen zurück (Array von Vector3), dort steigt Rauch auf.
static func industry_plant(parent: Node3D, pos: Vector3, withered: bool = false) -> Array:
	var tops: Array = []
	rbox(parent, Vector3(0.54, 0.016, 0.46), 0.02, Color("#8b8e94"), pos + Vector3(0, 0.008, 0))
	var brick := Color("#a95a45") if not withered else Color("#7e5b50")
	var hall := pos + Vector3(-0.07, 0.016, 0.07)
	var hw := 0.32
	rbox(parent, Vector3(hw, 0.12, 0.2), 0.01, brick, hall + Vector3(0, 0.06, 0))
	var glass := mat(Color("#a9d8f5"), 0.15, 0.4)
	for i in 3:
		var tw_w := hw / 3.0
		var x := -hw * 0.5 + tw_w * (i + 0.5)
		saw(parent, Vector3(tw_w, 0.065, 0.2), Color("#5d6470"), hall + Vector3(x, 0.12, 0))
		box(parent, Vector3(0.006, 0.05, 0.17), Color.WHITE, hall + Vector3(x + tw_w * 0.5 - 0.004, 0.148, 0), Vector3.ZERO, glass)
	var furnace := mat(Color("#ffab40"), 0.4, 1.8)
	for k in 3:
		box(parent, Vector3(0.045, 0.032, 0.006), Color.WHITE, hall + Vector3(-0.1 + k * 0.08, 0.07, 0.101), Vector3.ZERO, furnace)
	box(parent, Vector3(0.06, 0.06, 0.006), DARK, hall + Vector3(0.13, 0.03, 0.101))
	# Schlote
	var specs := [[Vector3(0.04, 0.016, -0.15), 0.48], [Vector3(0.16, 0.016, -0.12), 0.38]]
	for sp in specs:
		var base: Vector3 = pos + (sp[0] as Vector3)
		var h: float = sp[1]
		cyl(parent, 0.028, 0.036, h, Color("#d5d0c8"), base, 12)
		cyl(parent, 0.031, 0.031, 0.032, Color("#e5483c"), base + Vector3(0, h - 0.085, 0), 12)
		cyl(parent, 0.033, 0.033, 0.032, Color("#e5483c"), base + Vector3(0, h - 0.19, 0), 12)
		cyl(parent, 0.032, 0.032, 0.014, Color("#4a4d55"), base + Vector3(0, h - 0.004, 0), 12)
		tops.append(base + Vector3(0, h + 0.03, 0))
	# Tank und Rohr
	var tank := pos + Vector3(0.2, 0.016, 0.13)
	var steel := mat(Color("#d9dde3"), 0.3, 0.0, 0.35)
	cyl(parent, 0.062, 0.062, 0.1, Color.WHITE, tank, 16, Vector3.ZERO, steel)
	sphere(parent, 0.062, Color.WHITE, tank + Vector3(0, 0.1, 0), steel, 0.45)
	cyl(parent, 0.012, 0.012, 0.1, Color("#8d6e63"), tank + Vector3(-0.055, 0.075, 0), 8, Vector3(0, 0, 90))
	for k in 2:
		cyl(parent, 0.02, 0.02, 0.045, Color("#3f86e8"), pos + Vector3(-0.22 + k * 0.045, 0.016, -0.15), 10)
	return tops


## Krieg: verkohlte Trümmer (einige Steinbrocken und ein umgekippter Balken).
static func rubble(parent: Node3D, pos: Vector3) -> void:
	var stone := Color("#9c958b")
	var soot := Color("#4a4440")
	rbox(parent, Vector3(0.07, 0.04, 0.05), 0.01, stone, pos + Vector3(-0.05, 0.02, 0.02), Vector3(0, 25, 8))
	rbox(parent, Vector3(0.05, 0.035, 0.04), 0.01, soot, pos + Vector3(0.04, 0.017, -0.03), Vector3(0, -30, -10))
	rbox(parent, Vector3(0.04, 0.03, 0.035), 0.01, stone, pos + Vector3(0.02, 0.015, 0.06), Vector3(0, 60, 0))
	box(parent, Vector3(0.13, 0.016, 0.016), Color("#5a3b26"), pos + Vector3(0.0, 0.03, 0.0), Vector3(0, 35, 14))


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
