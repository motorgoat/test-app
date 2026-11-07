class_name Look
extends RefCounted
## Materialbibliothek für den Diorama-Look (docs/GDPD_GRAFIK.md, Teil A).
## Geteilte Rauschtexturen, Boden je Art, Fels, Wasser, Laub mit Wind, Licht-Ränder, Rauch und Funken.
## Alles ohne UV: Muster entstehen im Objektraum der Kachel und drehen mit dem Würfel mit.
##
## Schnittstelle für Teil B (Modelle):
##   foliage(color)  Laub/Gras/Ähren mit Wind. Wind-Gewicht kommt aus der Höhe im Mesh (VERTEX.y),
##                   bei eigenen Meshes zusätzlich aus COLOR.a (1 = voll, 0 = steif), wenn use_vc = true.
##   solid(color)    gedeckte Standard-Oberfläche (Holz, Putz, Stein), schwaches Detail-Rauschen.
##   restyle(node)   rechnet alte Spielzeug-Materialien unter node in den neuen Look um (Übergang).
##   ground_params(kind) / GROUND: Bodenwerte je Art (Lesbarkeits-Regel 2.3).

const NOISE_FBM := "res://textures/noise_fbm.res"
const NOISE_CELL := "res://textures/noise_cell.res"
const NOISE_DETAIL := "res://textures/noise_detail.res"

## Qualitätsstufe: 2 hoch, 1 mittel, 0 niedrig (World misst die ersten Sekunden, die Tour bleibt auf hoch).
static var quality := 2
static var _tex: Dictionary = {}
static var _cache: Dictionary = {}
static var _restyled: Dictionary = {}      # Ausgangs-Material (instance id) -> neues Material
static var _foliage_mats: Array = []       # alle Laub-Materialien (Wind-Böen gemeinsam)
static var _water_mats: Array = []
static var wind := 1.0                     # Böen-Faktor (World setzt ihn jedes Bild)
static var sky_color := Color("#c7d5e0")   # Himmelsspiegelung im Wasser (Stimmung)


# =============================================================================
# Rauschen (einmal erzeugt, als .res gebacken: tools/bake_look.gd)
# =============================================================================

static func fbm() -> Texture2D:
	return _noise("fbm")


static func cell() -> Texture2D:
	return _noise("cell")


static func detail() -> Texture2D:
	return _noise("detail")


static func _noise(which: String) -> Texture2D:
	if _tex.has(which):
		return _tex[which]
	var path: String = {"fbm": NOISE_FBM, "cell": NOISE_CELL, "detail": NOISE_DETAIL}[which]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	if t == null:
		t = ImageTexture.create_from_image(make_noise_image(which))
	_tex[which] = t
	return t


## Erzeugt das Rauschbild (nahtlos, mit Mipmaps). Wird vom Back-Werkzeug und als Rückfall benutzt.
static func make_noise_image(which: String) -> Image:
	var fn := FastNoiseLite.new()
	fn.seed = 7
	var size := 256
	match which:
		"fbm":
			fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			fn.frequency = 0.012
			fn.fractal_octaves = 4
		"cell":
			fn.noise_type = FastNoiseLite.TYPE_CELLULAR
			fn.frequency = 0.06
			fn.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
			fn.fractal_type = FastNoiseLite.FRACTAL_NONE
		_:
			fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			fn.frequency = 0.05
			fn.fractal_octaves = 3
			size = 128
	var img := fn.get_seamless_image(size, size)
	if which == "detail":
		# Graustufen 0,9 … 1,0: nur ein Hauch Struktur auf Gebäuden
		for y in size:
			for x in size:
				var v := img.get_pixel(x, y).r
				img.set_pixel(x, y, Color(0.9 + 0.1 * v, 0.9 + 0.1 * v, 0.9 + 0.1 * v))
	img.generate_mipmaps()
	return img


static func _shader(path: String) -> Shader:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


# =============================================================================
# Boden je Art (Lesbarkeits-Regel 2.3: Helligkeit, Muster, Merkmal)
# =============================================================================

## a/b: zwei Bodentöne nach großem Rauschen, acc: Kiesel/Streu, cob: Pflaster, fur: Furchen,
## spk: Tupfer (Blumen, Blüten), path: Trampelpfad, pc: Pfadfarbe
const GROUND := [
	{"a": "#64492f", "b": "#7a5a3d", "acc": "#958d80", "amt": 0.85},                                  # 0 Erde
	{"a": "#5d8a2c", "b": "#7ea33e", "spk": "#ece6d2", "spk2": "#e0c04e", "samt": 0.55},           # 1 Wiese
	{"a": "#3a4b20", "b": "#54482b", "acc": "#6e5a37", "amt": 0.35},                                 # 2 Wald
	{"a": "#5a3e27", "b": "#73543a", "fur": 1.0},                                                     # 3 Acker
	{"a": "#26321a", "b": "#353020", "acc": "#4a3d28", "amt": 0.25},                                 # 4 Großer Wald
	{"a": "#8d9c4c", "b": "#aab06a", "acc": "#b9aa7c", "amt": 0.2},                                  # 5 Tiere (Weide)
	{"a": "#5c7630", "b": "#76683f", "path": 0.8, "pc": "#8a7350"},                                  # 6 Hütte
	{"a": "#678838", "b": "#7f9a45", "path": 0.6, "pc": "#a49a86", "spk": "#e8d9c6", "spk2": "#c98b7a", "samt": 0.25},  # 7 Haus
	{"a": "#6a7d3a", "b": "#867b54", "path": 1.0, "pc": "#9c8a68", "acc": "#a39d92", "amt": 0.2},  # 8 Dorf
	{"a": "#99938a", "b": "#a9a398", "cob": 1.0},                                                     # 9 Stadt
	{"a": "#b3ab9b", "b": "#c2baaa", "acc": "#d8d2c5", "amt": 0.9},                                  # 10 Kirche (heller Kies)
	{"a": "#6f6a63", "b": "#7d786f", "cob": 1.0},                                                     # 11 Großstadt
	{"a": "#44413d", "b": "#524e48", "acc": "#6a665f", "amt": 0.25},                                 # 12 Industrie (Asphalt)
	{"a": "#c4c0b7", "b": "#d0ccc3", "cob": 0.55, "cs": 1.3},                                        # 13 Metropole (Platz)
	{"a": "#4a8c34", "b": "#69a748", "spk": "#f2c6d4", "spk2": "#fbf3e6", "samt": 0.9},            # 14 Paradies
	{"a": "#a39170", "b": "#b8a782", "acc": "#c9bd9e", "amt": 0.4},                                  # 15 Wasser (Sand)
	{"a": "#7a756c", "b": "#8f897e", "acc": "#aaa397", "amt": 1.0},                                  # 16 Stein (Schotter)
]


static func ground_params(kind: int) -> Dictionary:
	return GROUND[clampi(kind, 0, GROUND.size() - 1)]


## Neues Boden-Material (je Feld eines: Puls, Nässe und Verwelken sind je Feld verschieden).
static func ground_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("res://shaders/ground.gdshader")
	m.set_shader_parameter("n_fbm", fbm())
	m.set_shader_parameter("n_cell", cell())
	return m


## Setzt die Werte einer Art auf ein Boden-Material. furrow_dir: 0 = Furchen quer zu z, 1 = quer zu x.
static func apply_ground(m: ShaderMaterial, kind: int, scorch: float, polluted: float, furrow_dir: int = 0) -> void:
	var g: Dictionary = ground_params(kind)
	m.set_shader_parameter("top_a", Color(str(g["a"])))
	m.set_shader_parameter("top_b", Color(str(g["b"])))
	m.set_shader_parameter("accent", Color(str(g.get("acc", "#8c857a"))))
	m.set_shader_parameter("accent_amt", float(g.get("amt", 0.0)))
	m.set_shader_parameter("cobble", float(g.get("cob", 0.0)))
	m.set_shader_parameter("cobble_scale", float(g.get("cs", 2.4)))
	m.set_shader_parameter("furrow", float(g.get("fur", 0.0)))
	m.set_shader_parameter("furrow_dir", float(furrow_dir))
	m.set_shader_parameter("speck_a", Color(str(g.get("spk", "#ffffff"))))
	m.set_shader_parameter("speck_b", Color(str(g.get("spk2", g.get("spk", "#ffffff")))))
	m.set_shader_parameter("speck_amt", float(g.get("samt", 0.0)))
	m.set_shader_parameter("path_amt", float(g.get("path", 0.0)))
	m.set_shader_parameter("path_c", Color(str(g.get("pc", "#8a7350"))))
	m.set_shader_parameter("scorch", scorch)
	m.set_shader_parameter("polluted", polluted)


static func bedrock() -> ShaderMaterial:
	if not _cache.has("bedrock"):
		var m := ShaderMaterial.new()
		m.shader = _shader("res://shaders/bedrock.gdshader")
		m.set_shader_parameter("n_fbm", fbm())
		_cache["bedrock"] = m
	return _cache["bedrock"]


## Wasser (je Feld eines: Ufer-Schaum hängt an den Nachbarn).
static func water() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("res://shaders/water.gdshader")
	m.set_shader_parameter("n_fbm", fbm())
	m.set_shader_parameter("sky", sky_color)
	_water_mats.append(weakref(m))
	return m


static func set_sky(c: Color) -> void:
	sky_color = c
	var keep: Array = []
	for w in _water_mats:
		var m: ShaderMaterial = (w as WeakRef).get_ref()
		if m != null:
			m.set_shader_parameter("sky", c)
			keep.append(w)
	_water_mats = keep


# =============================================================================
# Laub, feste Oberflächen, Umrechnung der alten Materialien
# =============================================================================

static func foliage(color: Color, use_vc: bool = false) -> ShaderMaterial:
	var key := "fol|%s|%s" % [color.to_html(false), use_vc]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = _shader("res://shaders/foliage.gdshader")
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("use_vc", use_vc)
	m.set_shader_parameter("n_fbm", fbm())
	m.set_shader_parameter("gust", wind)
	_cache[key] = m
	_foliage_mats.append(m)
	return m


## Böen: ein gemeinsamer Faktor für alle Laub-Materialien (nur wenn er sich merklich ändert).
static func set_wind(w: float) -> void:
	if absf(w - wind) < 0.01:
		return
	wind = w
	for m in _foliage_mats:
		(m as ShaderMaterial).set_shader_parameter("gust", w)


static func solid(color: Color, rough: float = 0.82) -> StandardMaterial3D:
	var key := "sol|%s|%.2f|%d" % [color.to_html(true), rough, quality]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic_specular = 0.35
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	elif quality >= 1:
		m.albedo_texture = detail()
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(7, 7, 7)
	_cache[key] = m
	return m


## Spielzeugfarbe -> natürlicher Ton: weniger Sättigung, etwas dunkler, Grün Richtung Oliv, nie reines Weiß.
static func natural(c: Color) -> Color:
	var h := c.h
	var s := c.s
	var v := c.v
	if s < 0.3 and v > 0.7:
		# Weiß und Pastell -> Putz: gedämpft, leicht warm, nie reines Weiß
		var warm := Color.from_hsv(h, s * 0.5, minf(v, 0.72), c.a).lerp(Color(0.74, 0.69, 0.6, c.a), 0.4)
		return warm
	if s < 0.12:
		v = minf(v, 0.84)
	elif h > 0.17 and h < 0.45:          # Grün
		h = lerpf(h, 0.25, 0.3)
		s *= 0.8
		v *= 0.8
	elif h > 0.5 and h < 0.7:          # Blau (Glas, Kleidung)
		s *= 0.6
		v *= 0.84
	elif h >= 0.7 and h < 0.9:         # Violett (Kirche): nur noch ein Hauch
		s *= 0.45
		v *= 0.86
	elif (h < 0.05 or h > 0.95) and s > 0.45:   # Signalrot -> Ziegel
		h = 0.025
		s *= 0.72
		v *= 0.8
	else:
		s *= 0.78
		v *= 0.92
	return Color.from_hsv(h, s, v, c.a)


static func is_leafy(c: Color) -> bool:
	return c.h > 0.17 and c.h < 0.45 and c.s > 0.22 and c.v > 0.15


## Rechnet die Materialien eines Inhalts um (alte Spielzeug-Teile -> gedeckt, Grün -> Laub mit Wind).
## Unbeleuchtete, leuchtende und durchsichtige Teile (Hinweise, Funkeln, Glas) bleiben, wie sie sind.
static func restyle(node: Node) -> void:
	for c in node.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			var src := mi.material_override
			if src != null:
				mi.material_override = _restyle_mat(src)
		if c.get_child_count() > 0:
			restyle(c)


static func _restyle_mat(src: Material) -> Material:
	var id := src.get_instance_id()
	if _restyled.has(id):
		return _restyled[id]
	var out: Material = src
	if src is StandardMaterial3D:
		var sm := src as StandardMaterial3D
		var plain := sm.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and not sm.emission_enabled \
			and sm.albedo_color.a > 0.999 and sm.albedo_texture == null and sm.cull_mode == BaseMaterial3D.CULL_BACK
		if plain:
			var c := sm.albedo_color
			if is_leafy(c):
				out = foliage(natural(c))
			else:
				out = solid(natural(c), maxf(sm.roughness, 0.72) if sm.metallic < 0.2 else sm.roughness)
		elif sm.emission_enabled and sm.emission_energy_multiplier <= 0.6 and sm.albedo_color.a > 0.999 \
				and sm.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL:
			# schwach leuchtende Teile (Fensterbänder, Zierrat): gedeckt, ohne Leuchten (Glas glänzt statt zu glühen)
			var e := sm.duplicate() as StandardMaterial3D
			e.albedo_color = natural(sm.albedo_color).darkened(0.12)
			e.emission_enabled = false
			e.roughness = maxf(sm.roughness, 0.25)
			out = e
	_restyled[id] = out
	return out


# =============================================================================
# Hinweise als weicher Lichtrand, Ringe, Funken, Rauch
# =============================================================================

## Lichtrand um eine Kachel (Auswahl, Hinweis, Ziel, Gefahr, Verschmelzen). half: halbe Kantenlänge des Meshes.
## mix = true: gemischt statt additiv (für Flächen auf der Kachel, auch auf hellem Boden gut sichtbar).
static func rim(color: Color, half: float, fill: float = 0.12, pulse: float = 0.0, width: float = 0.22, mix: bool = false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("res://shaders/rim_mix.gdshader" if mix else "res://shaders/rim.gdshader")
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("half_size", half)
	m.set_shader_parameter("fill", fill)
	m.set_shader_parameter("pulse", pulse)
	m.set_shader_parameter("width", width)
	return m


## Ausbreitender Lichtring (flache Scheibe).
static func ring(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("res://shaders/ring.gdshader")
	m.set_shader_parameter("color", color)
	return m


static func _soft_dot() -> Texture2D:
	if not _tex.has("dot"):
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		_tex["dot"] = t
	return _tex["dot"]


## Leuchtender Punkt (Funken, Pollen, Glut): unbeleuchtet, additiv, immer zur Kamera.
static func mote(color: Color, particles: bool = false) -> StandardMaterial3D:
	var key := "mote|%s|%s" % [color.to_html(true), particles]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	m.albedo_texture = _soft_dot()
	m.vertex_color_use_as_albedo = particles
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES if particles else BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = false
	m.disable_receive_shadows = true
	_cache[key] = m
	return m


static func quad(size: float) -> QuadMesh:
	var key := "quad|%.3f" % size
	if not _cache.has(key):
		var q := QuadMesh.new()
		q.size = Vector2(size, size)
		_cache[key] = q
	return _cache[key]


static func _smoke_tex() -> Texture2D:
	if not _tex.has("smoke"):
		var size := 64
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var fn := FastNoiseLite.new()
		fn.seed = 3
		fn.frequency = 0.09
		fn.fractal_octaves = 3
		for y in size:
			for x in size:
				var d := Vector2(x - size * 0.5 + 0.5, y - size * 0.5 + 0.5).length() / (size * 0.5)
				var n := fn.get_noise_2d(x, y) * 0.5 + 0.5
				var a := clampf((1.0 - d) * 1.6, 0.0, 1.0) * clampf(0.35 + n * 0.9, 0.0, 1.0)
				img.set_pixel(x, y, Color(0.92 + 0.08 * n, 0.92 + 0.08 * n, 0.92 + 0.08 * n, a * a))
		img.generate_mipmaps()
		_tex["smoke"] = ImageTexture.create_from_image(img)
	return _tex["smoke"]


## Weiche Rauch-/Wolkenflocke (Billboard, Rausch-Alpha). Farbe gibt Helligkeit und Deckkraft vor.
static func smoke(color: Color) -> StandardMaterial3D:
	var key := "smoke|%s" % color.to_html(true)
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.albedo_texture = _smoke_tex()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.disable_receive_shadows = true
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	_cache[key] = m
	return m


## Eine Rauchflocke als Mesh (Größe = Durchmesser).
static func smoke_puff(parent: Node3D, diameter: float, color: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = quad(1.0)
	mi.material_override = smoke(color)
	mi.position = pos
	mi.scale = Vector3.ONE * diameter
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Staub, Blätter, Erdkrümel (Partikel): nicht leuchtend, weicher Punkt, Farbe aus der Partikelfarbe.
static func dust() -> StandardMaterial3D:
	if _cache.has("dust"):
		return _cache["dust"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _soft_dot()
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	_cache["dust"] = m
	return m


## Regenstrich: zwei gekreuzte, gestreckte Quads entlang y (von der Seite wie von schräg oben sichtbar).
static func streak_mesh() -> Mesh:
	if _cache.has("streak"):
		return _cache["streak"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.004
	var h := 0.07
	for ax in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
		var a: Vector3 = ax * w
		var q := [Vector3(-a.x, -h, -a.z), Vector3(a.x, -h, a.z), Vector3(a.x, h, a.z), Vector3(-a.x, h, -a.z)]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[idx])
			st.add_vertex(q[idx])
	var m := st.commit()
	_cache["streak"] = m
	return m


static func rain_mat() -> StandardMaterial3D:
	if _cache.has("rain"):
		return _cache["rain"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.6, Color(1, 1, 1, 0.9))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 4
	t.height = 32
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.82, 0.88, 0.95, 0.55)
	m.albedo_texture = t
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["rain"] = m
	return m
