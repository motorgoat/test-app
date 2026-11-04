class_name FieldView
extends Node3D
## Darstellung eines Felds: Kachel (Farbe je Art und Stufe), Modelle, Volksrand, Symbole.
## Lokales Koordinatensystem: y = Normale der Seite, Feld liegt in x/z (−0,45 … 0,45).

const TILE := 0.9
const TILE_H := 0.09
const TOP := 0.09
const CONTENT_SCALE := 1.4

const TILE_COLOR = {
	"nature": ["", "#8fd162", "#6fc65a", "#3e9a4b"],
	"settlement": ["", "#e9c27c", "#d9c3a0", "#c4bcb0"],
	"industry": ["", "#a49a8c", "#7d828e", "#5f636e"],
	"faith": ["", "#d8c6f7", "#c9b2f3", "#b79bef"],
	"mountain": ["", "#8e8a86", "#8e8a86", "#8e8a86"],
	"crater": ["", "#6e5242", "#6e5242", "#6e5242"],
}
const WATER := Color("#36aef0")

var field_id := -1
var _tile: MeshInstance3D
var _rim: MeshInstance3D
var _content: Node3D
var _preview_label: Label3D
var _alert_label: Label3D
var _icon: Sprite3D
var _sel: MeshInstance3D
var _glow: MeshInstance3D
var _glow_on := false
var _hint: MeshInstance3D
var _hint_mat: StandardMaterial3D
var _hint_on := false
var _shown := ""
var _bobbers: Array = []
var _flames: Array = []
var _smoke: Array = []
var _spinners: Array = []
var _glows: Array = []
var _time := 0.0
var _labels_on := true


func build(f: FieldData) -> void:
	field_id = f.id
	_tile = Models.rbox(self, Vector3(TILE, TILE_H, TILE), 0.035, Color.WHITE, Vector3(0, TILE_H * 0.5, 0))
	_rim = Models.rbox(self, Vector3(TILE + 0.02, TILE_H * 0.6, TILE + 0.02), 0.04, Color.WHITE, Vector3(0, TILE_H * 0.3, 0))
	_rim.visible = false
	_content = Node3D.new()
	_content.position.y = TOP
	_content.scale = Vector3.ONE * CONTENT_SCALE
	add_child(_content)

	_sel = Models.rbox(self, Vector3(TILE + 0.06, 0.02, TILE + 0.06), 0.04, Color(1, 1, 1, 0.6), Vector3(0, 0.005, 0), Vector3.ZERO,
		Models.unshaded(Color(1, 1, 1, 0.6)))
	_sel.visible = false
	_glow = Models.rbox(self, Vector3(TILE + 0.08, 0.03, TILE + 0.08), 0.05, Color("#ffd23f"), Vector3(0, 0.01, 0), Vector3.ZERO,
		Models.mat(Color("#ffd23f"), 0.3, 2.2))
	_glow.visible = false
	_hint_mat = Models.mat(Color(1.0, 0.86, 0.3, 0.6), 0.3, 1.5).duplicate() as StandardMaterial3D
	_hint = Models.rbox(self, Vector3(TILE + 0.06, 0.025, TILE + 0.06), 0.05, Color.WHITE, Vector3(0, 0.008, 0), Vector3.ZERO, _hint_mat)
	_hint.visible = false

	var body := StaticBody3D.new()
	body.set_meta("field_id", f.id)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.0, 0.2, 1.0)
	shape.shape = bs
	body.add_child(shape)
	add_child(body)

	_preview_label = _make_label(64, Vector3(0, 0.72, 0))
	_preview_label.outline_size = 20
	_alert_label = _make_label(64, Vector3(0, 0.82, 0))
	_alert_label.outline_modulate = Color("#e5483c")

	_icon = Sprite3D.new()
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.pixel_size = 0.0034
	_icon.position = Vector3(0, 0.62, 0)
	_icon.render_priority = 2
	_icon.visible = false
	add_child(_icon)


func _make_label(size: int, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font = Style.bold()
	l.font_size = size
	l.pixel_size = 0.0032
	l.outline_size = 16
	l.modulate = Color.WHITE
	l.outline_modulate = Color("#3a3a3a")
	l.position = pos
	l.render_priority = 3
	l.outline_render_priority = 2
	l.visible = false
	add_child(l)
	return l


func world_normal() -> Vector3:
	return global_transform.basis.y.normalized()


func label_world_pos() -> Vector3:
	return global_transform * Vector3(0, 0.45, 0)


func set_selected(on: bool) -> void:
	_sel.visible = on


## Sanftes Pulsieren: Tipp, diese Scheibe zu drehen.
func set_hint(on: bool) -> void:
	_hint_on = on
	_hint.visible = on


## Goldenes Leuchten: dieses Feld würde gleich verschmelzen.
func set_highlight(on: bool) -> void:
	_glow_on = on
	_glow.visible = on


## Inhalt wird ins Nachbarfeld „eingesaugt“ (Verschmelzen). Danach wird neu gebaut.
func vanish(toward: Vector3, dur: float) -> void:
	_shown = "x"
	var local_dir := to_local(toward)
	local_dir.y = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_content, "position", Vector3(local_dir.x * 0.6, TOP + 0.15, local_dir.z * 0.6), dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(_content, "scale", Vector3.ONE * 0.05, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	_content.position = Vector3(0, TOP, 0)


## Ring, der sich ausbreitet, und ein kurzes Hüpfen (Aufstieg).
func burst(color: Color) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.36
	torus.rings = 32
	torus.ring_segments = 6
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	var m := Models.mat(color, 0.3, 3.0).duplicate() as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = m
	ring.position = Vector3(0, TOP + 0.05, 0)
	ring.scale = Vector3(0.5, 0.3, 0.5)
	add_child(ring)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(1.9, 0.3, 1.9), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.6)
	tw.chain().tween_callback(ring.queue_free)
	var hop := create_tween()
	hop.tween_property(self, "position", position + Vector3(0, 0, 0) + basis.y * 0.12, 0.15).set_ease(Tween.EASE_OUT)
	hop.tween_property(self, "position", position, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func set_labels_visible(on: bool) -> void:
	_labels_on = on
	_preview_label.visible = on and _preview_label.text != ""
	_alert_label.visible = on and _alert_label.text != ""
	_icon.visible = on and _icon.texture != null


## Vorschau über dem Feld (+3, ▲, ▼). "" blendet aus.
func set_preview(text: String, color: Color) -> void:
	_preview_label.text = text
	_preview_label.outline_modulate = color
	_preview_label.visible = _labels_on and text != ""
	if text != "":
		_icon.visible = false


## Kleines Symbol über dem Feld. null blendet aus.
func set_icon(tex: Texture2D) -> void:
	_icon.texture = tex
	_icon.visible = _labels_on and tex != null and _preview_label.text == ""


func refresh(f: FieldData, gs: GameState) -> void:
	var key := "%s|%d|%d|%s|%d|%d" % [f.kind, f.level, f.nation, f.burning, f.volcano, mini(f.crater_age, 2)]
	if key != _shown:
		var first := _shown == ""
		_shown = key
		_tile.material_override = Models.mat(_tile_color(f), 0.7)
		if f.has_nation():
			_rim.visible = true
			_rim.material_override = Models.mat(Style.nation_color(f.nation), 0.5)
		elif f.is_center:
			_rim.visible = true
			_rim.material_override = Models.mat(Color.WHITE, 0.4)
		else:
			_rim.visible = false
		for c in _content.get_children():
			c.queue_free()
		_bobbers.clear()
		_flames.clear()
		_smoke.clear()
		_spinners.clear()
		_glows.clear()
		_build_content(f)
		if not first:
			_content.scale = Vector3(0.6, 0.3, 0.6) * CONTENT_SCALE
			var tw := create_tween()
			tw.tween_property(_content, "scale", Vector3.ONE * CONTENT_SCALE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_alert_label.text = str(f.volcano) if f.volcano > 0 else ""
	set_labels_visible(_labels_on)


func _tile_color(f: FieldData) -> Color:
	if f.is_center:
		return Color(GameState.LANDMARK_COLOR[maxi(0, f.landmark)]).lerp(Color.WHITE, 0.25)
	if TILE_COLOR.has(f.kind):
		return Color(TILE_COLOR[f.kind][clampi(f.level, 1, 3)])
	return Color("#8fd162")


func _process(delta: float) -> void:
	_time += delta
	if _hint_on:
		_hint_mat.albedo_color.a = 0.15 + 0.45 * (0.5 + 0.5 * sin(_time * 3.0))
	for i in _bobbers.size():
		var b: Node3D = _bobbers[i]
		if is_instance_valid(b):
			b.position.y = absf(sin(_time * 2.6 + i * 1.7)) * 0.01
	for i in _flames.size():
		var fl: Node3D = _flames[i]
		if is_instance_valid(fl):
			fl.scale = Vector3(1.0, 0.85 + 0.2 * sin(_time * 14.0 + i * 2.1), 1.0)
	for i in _smoke.size():
		var sm: Node3D = _smoke[i]
		if is_instance_valid(sm):
			var t: float = fmod(_time * 0.5 + i * 0.37, 1.0)
			var by: float = sm.get_meta("base_y", 0.0)
			sm.scale = Vector3.ONE * (0.6 + t * 1.2)
			sm.position.y = by + t * 0.12
	for sp in _spinners:
		var s: Node3D = sp
		if is_instance_valid(s):
			s.rotation.z += delta * 1.2
	for gl in _glows:
		var g: Node3D = gl
		if is_instance_valid(g):
			g.scale = Vector3.ONE * (0.9 + 0.2 * sin(_time * 3.0))


# =============================================================================
# Inhalt bauen (Koordinaten im Inhalt: etwa −0,3 … 0,3)
# =============================================================================

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = field_id * 7919 + 17
	return rng


func _people(c: Color, count: int, around: Vector3, radius: float) -> void:
	for k in count:
		var a: float = TAU * float(k) / maxf(1.0, float(count)) + 0.5
		var holder := Node3D.new()
		_content.add_child(holder)
		Models.person(holder, around + Vector3(cos(a) * radius, 0, sin(a) * radius * 0.6), c)
		_bobbers.append(holder)


func _animal(kind: String, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	_content.add_child(holder)
	Models.animal(holder, pos, kind, rng.randf_range(0, 360))
	_bobbers.append(holder)


func _build_content(f: FieldData) -> void:
	var rng := _rng()
	var c := Style.nation_color(f.nation)
	match f.kind:
		"nature":
			_build_nature(f, rng)
		"settlement":
			_build_settlement(f, c, rng)
		"industry":
			_build_industry(f)
		"faith":
			match f.level:
				1:
					Models.chapel(_content, Vector3(0, 0, -0.04), c)
				2:
					Models.church(_content, Vector3(0, 0, -0.06), c)
				_:
					Models.cathedral(_content, Vector3(0, 0, -0.04), c)
			_people(c, f.level, Vector3(0, 0, 0.17), 0.08)
		"mountain":
			if f.volcano > 0:
				Models.cone(_content, 0.2, 0.28, Color("#7e7068"), Vector3.ZERO, 9)
				var lava := Models.cyl(_content, 0.06, 0.06, 0.02, Color("#ff5a1f"), Vector3(0, 0.25, 0), 10, Vector3.ZERO, Models.mat(Color("#ff5a1f"), 0.5, 2.5))
				_glows.append(lava)
				for k in 2:
					var puff := Node3D.new()
					puff.position = Vector3(0.02 * k, 0.32 + k * 0.05, 0)
					_content.add_child(puff)
					Models.sphere(puff, 0.04, Color(0.5, 0.5, 0.53, 0.8), Vector3.ZERO)
					puff.set_meta("base_y", puff.position.y)
					_smoke.append(puff)
			else:
				Models.rock(_content, Vector3(-0.06, 0, -0.04), rng.randf_range(1.0, 1.2), true)
				Models.rock(_content, Vector3(0.14, 0, 0.1), rng.randf_range(0.6, 0.8), true)
				if rng.randf() < 0.5:
					_animal("mountain", Vector3(-0.15, 0.0, 0.16), rng)
		"crater":
			Models.rbox(_content, Vector3(0.42, 0.015, 0.42), 0.15, Color("#3f2e25"), Vector3.ZERO)
			for k in 4:
				var a: float = rng.randf() * TAU
				Models.sphere(_content, 0.03, Color("#5e4a3c"), Vector3(cos(a) * 0.24, 0.015, sin(a) * 0.24), null, 0.6)
			if f.crater_age < 2:
				var puff := Node3D.new()
				puff.position = Vector3(0, 0.06, 0)
				_content.add_child(puff)
				Models.sphere(puff, 0.05, Color(0.45, 0.42, 0.42, 0.7), Vector3.ZERO)
				puff.set_meta("base_y", puff.position.y)
				_smoke.append(puff)
	if f.burning:
		for k in 3:
			var fp := Vector3(-0.14 + k * 0.14, 0.0, rng.randf_range(-0.14, 0.14))
			_flames.append(Models.flame(_content, fp, rng.randf_range(1.2, 1.7)))


func _build_nature(f: FieldData, rng: RandomNumberGenerator) -> void:
	var greens := [Color("#4fa449"), Color("#5cb357"), Color("#3f9443")]
	match f.level:
		1:
			# Wiese mit See
			Models.rbox(_content, Vector3(0.26, 0.016, 0.22), 0.1, WATER, Vector3(0.07, 0.0, 0.06), Vector3.ZERO, Models.mat(WATER, 0.1))
			Models.tree(_content, Vector3(-0.18, 0, -0.16), 0.9, greens[0])
			Models.pine(_content, Vector3(0.18, 0, -0.2), 0.8, greens[1])
			var flowers := [Color("#ffffff"), Color("#ff9ec4"), Color("#ffe066")]
			for k in 5:
				var fp := Vector3(rng.randf_range(-0.26, -0.02), 0.015, rng.randf_range(0.0, 0.26))
				Models.sphere(_content, 0.016, flowers[k % 3], fp)
			_animal("lake", Vector3(0.08, 0.012, 0.06), rng)
		2:
			# Fluss quer über das Feld (verbindet sich optisch mit Nachbarn)
			Models.rbox(_content, Vector3(0.17, 0.016, 0.66), 0.03, WATER, Vector3(0.0, 0.0, 0.0), Vector3.ZERO, Models.mat(WATER, 0.08))
			Models.rbox(_content, Vector3(0.24, 0.02, 0.05), 0.01, Models.WOOD, Vector3(0, 0.03, 0.1))
			for side in [-1, 1]:
				Models.tree(_content, Vector3(0.2 * side, 0, -0.16), rng.randf_range(0.9, 1.1), greens[0])
				Models.pine(_content, Vector3(0.21 * side, 0, 0.2), rng.randf_range(0.8, 1.0), greens[1])
			_animal("lake", Vector3(0.0, 0.012, -0.12), rng)
		_:
			# Urwald
			var spots := [Vector3(-0.18, 0, -0.17), Vector3(0.17, 0, -0.19), Vector3(-0.02, 0, -0.02),
				Vector3(0.19, 0, 0.14), Vector3(-0.19, 0, 0.17), Vector3(0.03, 0, 0.21)]
			for k in spots.size():
				var g: Color = greens[k % greens.size()].darkened(0.1)
				if k % 2 == 0:
					Models.tree(_content, spots[k], rng.randf_range(1.0, 1.2), g)
				else:
					Models.pine(_content, spots[k], rng.randf_range(1.0, 1.15), g)
			Models.sphere(_content, 0.02, Color("#e5483c"), Vector3(0.09, 0.015, 0.06), null, 0.6)
			_animal("forest", Vector3(0.1, 0, -0.06), rng)


func _build_settlement(f: FieldData, c: Color, rng: RandomNumberGenerator) -> void:
	match f.level:
		1:
			Models.house(_content, Vector3(-0.1, 0, -0.08), c, 1.0, rng.randf_range(-20, 20))
			Models.house(_content, Vector3(0.12, 0, -0.04), c, 0.9, rng.randf_range(-20, 20))
			Models.tree(_content, Vector3(0.18, 0, 0.18), 0.7, Color("#5cb357"))
			_people(c, 2, Vector3(-0.05, 0, 0.14), 0.06)
		2:
			Models.rbox(_content, Vector3(0.2, 0.008, 0.2), 0.05, Color("#c9c1b3"), Vector3(0.02, 0.0, 0.08))
			Models.house(_content, Vector3(-0.15, 0, -0.14), c, 1.15, 0)
			Models.house(_content, Vector3(0.0, 0, -0.17), c, 1.0, 0)
			Models.house(_content, Vector3(0.16, 0, -0.12), c, 1.2, 0)
			Models.house(_content, Vector3(-0.17, 0, 0.12), c, 0.95, 90)
			Models.market(_content, Vector3(0.08, 0, 0.12), c)
			_people(c, 3, Vector3(0.0, 0, 0.06), 0.07)
		_:
			Models.tower(_content, Vector3(-0.13, 0, -0.12), 0.11, 0.42, c)
			Models.tower(_content, Vector3(0.1, 0, -0.14), 0.12, 0.3, c)
			Models.tower(_content, Vector3(0.14, 0, 0.12), 0.1, 0.22, c)
			Models.house(_content, Vector3(-0.15, 0, 0.14), c, 1.0, 0)
			Models.tree(_content, Vector3(-0.0, 0, 0.0), 0.7, Color("#5cb357"))
			_people(c, 3, Vector3(0.0, 0, 0.16), 0.08)


func _build_industry(f: FieldData) -> void:
	match f.level:
		1:
			Models.workshop(_content, Vector3(0, 0, -0.04))
			_people(Color("#7c8796"), 1, Vector3(0.0, 0, 0.16), 0.04)
		2:
			_smoke.append_array(Models.factory(_content, Vector3(0, 0, -0.02), false))
		_:
			_smoke.append_array(Models.factory(_content, Vector3(0.02, 0, -0.08), true))
			Models.workshop(_content, Vector3(-0.15, 0, 0.17))
	for s in _smoke:
		var sm: Node3D = s
		sm.set_meta("base_y", sm.position.y)


func _build_landmark(f: FieldData) -> void:
	match f.landmark:
		0:
			_glows.append(Models.lighthouse(_content, Vector3.ZERO))
		1:
			_spinners.append(Models.windmill(_content, Vector3.ZERO))
		2:
			Models.world_tree(_content, Vector3.ZERO)
		3:
			_glows.append(Models.stone_circle(_content, Vector3.ZERO))
		4:
			Models.pyramid(_content, Vector3.ZERO)
		_:
			Models.observatory(_content, Vector3.ZERO)
