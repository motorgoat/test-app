class_name Models
extends RefCounted
## Kleine Helfer für prozedurale Low-Poly-Modelle (keine importierten Assets nötig).
## Materialien und Meshes werden zwischengespeichert, damit es auch am Handy flüssig bleibt.

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}


static func mat(color: Color, metallic: float = 0.0, rough: float = 0.85, emission: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(true), metallic, rough, emission]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = rough
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_mats[key] = m
	return m


static func _add(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, color: Color, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, material: Material = null) -> MeshInstance3D:
	var key := "box|%s" % size
	if not _meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[key] = bm
	return _add(parent, _meshes[key], material if material != null else mat(color), pos, rot_deg)


## Zylinder/Kegel. pos ist die Mitte der Grundfläche.
static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, color: Color, pos: Vector3, sides: int = 8, rot_deg: Vector3 = Vector3.ZERO, material: Material = null) -> MeshInstance3D:
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
	# CylinderMesh ist mittig, wir wollen die Grundfläche auf pos
	mi.position = pos + mi.basis.y * (h * 0.5)
	return mi


static func cone(parent: Node3D, r: float, h: float, color: Color, pos: Vector3, sides: int = 6) -> MeshInstance3D:
	return cyl(parent, 0.0, r, h, color, pos, sides)


static func sphere(parent: Node3D, r: float, color: Color, pos: Vector3, material: Material = null) -> MeshInstance3D:
	var key := "sph|%.3f" % r
	if not _meshes.has(key):
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 8
		sm.rings = 4
		_meshes[key] = sm
	return _add(parent, _meshes[key], material if material != null else mat(color), pos)


## Satteldach. pos ist die Mitte der Unterkante, der First läuft entlang z.
static func roof(parent: Node3D, size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var key := "prism|%s" % size
	if not _meshes.has(key):
		var pm := PrismMesh.new()
		pm.size = size
		_meshes[key] = pm
	return _add(parent, _meshes[key], mat(color), pos + Vector3(0, size.y * 0.5, 0))


## Kleines Haus mit Satteldach. pos = Mitte der Grundfläche.
static func hut(parent: Node3D, pos: Vector3, roof_color: Color, scale_f: float = 1.0, wall_color: Color = Color("#f3e3c3")) -> void:
	var w := 0.13 * scale_f
	var h := 0.09 * scale_f
	box(parent, Vector3(w, h, w * 0.9), wall_color, pos + Vector3(0, h * 0.5, 0))
	roof(parent, Vector3(w * 1.25, h * 0.8, w * 1.05), roof_color, pos + Vector3(0, h, 0))
	box(parent, Vector3(w * 0.28, h * 0.55, 0.004), Color("#6b4a2f"), pos + Vector3(0, h * 0.275, w * 0.45 + 0.002))


## Kleine Figur (Bewohner) in Spielerfarbe.
static func figure(parent: Node3D, pos: Vector3, color: Color) -> void:
	cyl(parent, 0.016, 0.022, 0.05, color, pos, 6)
	sphere(parent, 0.017, Color("#f2c9a0"), pos + Vector3(0, 0.066, 0))


static func tree(parent: Node3D, pos: Vector3, s: float = 1.0) -> void:
	cyl(parent, 0.016 * s, 0.022 * s, 0.06 * s, Color("#7a5230"), pos, 5)
	cone(parent, 0.085 * s, 0.17 * s, Color("#2f7d3a"), pos + Vector3(0, 0.05 * s, 0), 6)
	cone(parent, 0.062 * s, 0.13 * s, Color("#3f9a4a"), pos + Vector3(0, 0.13 * s, 0), 6)


static func rock(parent: Node3D, pos: Vector3, s: float = 1.0, snow: bool = true) -> void:
	var h := 0.3 * s
	var r := 0.13 * s
	cone(parent, r, h, Color("#8d877c"), pos, 5)
	if snow:
		cone(parent, r * 0.4, h * 0.4, Color("#ffffff"), pos + Vector3(0, h * 0.6, 0), 5)
