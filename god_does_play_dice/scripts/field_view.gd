class_name FieldView
extends Node3D
## Darstellung eines Felds: Kachel (Farbe je Stufe), Modelle, Hervorhebungen.
## Lokales Koordinatensystem: y = Normale der Seite, Feld liegt in x/z (−0,45 … 0,45).
## Stufen: 0 Leere Erde, 1 Wiese, 2 Wald, 3 Dorf, 4 Stadt, 5 Fabrik.

const TILE := 0.9
const TILE_H := 0.09
const TOP := 0.09
const CONTENT_SCALE := 1.4

const TILE_COLOR = ["#a5805c", "#8fd162", "#4fae55", "#e9c27c", "#d4cdc2", "#7d828e"]
const WATER := Color("#36aef0")
const ROOF := Color("#e5574a")

var field_id := -1
var _tile: MeshInstance3D
var _content: Node3D
var _preview_label: Label3D
var _sel: MeshInstance3D
var _glow: MeshInstance3D
var _glow_top: MeshInstance3D
var _hint: MeshInstance3D
var _hint_mat: StandardMaterial3D
var _hint_on := false
var _shown := ""
var _bobbers: Array = []
var _smoke: Array = []
var _time := 0.0
var _labels_on := true


func build(f: FieldData) -> void:
	field_id = f.id
	_tile = Models.rbox(self, Vector3(TILE, TILE_H, TILE), 0.035, Color.WHITE, Vector3(0, TILE_H * 0.5, 0))
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
	_glow_top = Models.rbox(self, Vector3(TILE - 0.03, 0.014, TILE - 0.03), 0.03, Color.WHITE, Vector3(0, TOP + 0.006, 0), Vector3.ZERO,
		Models.unshaded(Color(1.0, 0.82, 0.15, 0.55)))
	_glow_top.visible = false
	_hint_mat = Models.unshaded(Color(1.0, 0.85, 0.25, 0.5)).duplicate() as StandardMaterial3D
	_hint = Models.rbox(self, Vector3(TILE - 0.03, 0.012, TILE - 0.03), 0.03, Color.WHITE, Vector3(0, TOP + 0.004, 0), Vector3.ZERO, _hint_mat)
	_hint.visible = false

	var body := StaticBody3D.new()
	body.set_meta("field_id", f.id)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.0, 0.2, 1.0)
	shape.shape = bs
	body.add_child(shape)
	add_child(body)

	_preview_label = Label3D.new()
	_preview_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_preview_label.font = Style.bold()
	_preview_label.font_size = 64
	_preview_label.pixel_size = 0.0032
	_preview_label.outline_size = 20
	_preview_label.modulate = Color.WHITE
	_preview_label.position = Vector3(0, 0.72, 0)
	_preview_label.render_priority = 3
	_preview_label.outline_render_priority = 2
	_preview_label.visible = false
	add_child(_preview_label)


func world_normal() -> Vector3:
	return global_transform.basis.y.normalized()


func label_world_pos() -> Vector3:
	return global_transform * Vector3(0, 0.45, 0)


func set_selected(on: bool) -> void:
	_sel.visible = on


func set_labels_visible(on: bool) -> void:
	_labels_on = on
	_preview_label.visible = on and _preview_label.text != ""


## Vorschau über dem Feld (+5). "" blendet aus.
func set_preview(text: String, color: Color) -> void:
	_preview_label.text = text
	_preview_label.outline_modulate = color
	_preview_label.visible = _labels_on and text != ""


## Sanftes Pulsieren: Tipp, diese Scheibe zu drehen.
func set_hint(on: bool) -> void:
	_hint_on = on
	_hint.visible = on


## Goldenes Leuchten: dieses Feld würde gleich verschmelzen.
func set_highlight(on: bool) -> void:
	_glow.visible = on
	_glow_top.visible = on


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


## Ring, der sich ausbreitet, und ein kurzes Hüpfen.
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
	var base := position
	var hop := create_tween()
	hop.tween_property(self, "position", base + basis.y * 0.12, 0.15).set_ease(Tween.EASE_OUT)
	hop.tween_property(self, "position", base, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func refresh(f: FieldData) -> void:
	var key := "%d|%d" % [f.stage, mini(f.fresh, 1)]
	if key == _shown:
		return
	var first := _shown == ""
	_shown = key
	_tile.material_override = Models.mat(Color(TILE_COLOR[clampi(f.stage, 0, 5)]), 0.7)
	for c in _content.get_children():
		c.queue_free()
	_bobbers.clear()
	_smoke.clear()
	_build_content(f)
	_content.position = Vector3(0, TOP, 0)
	if first:
		_content.scale = Vector3.ONE * CONTENT_SCALE
	else:
		_content.scale = Vector3(0.6, 0.3, 0.6) * CONTENT_SCALE
		var tw := create_tween()
		tw.tween_property(_content, "scale", Vector3.ONE * CONTENT_SCALE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	if _hint_on:
		_hint_mat.albedo_color.a = 0.1 + 0.5 * (0.5 + 0.5 * sin(_time * 3.5))
	for i in _bobbers.size():
		var b: Node3D = _bobbers[i]
		if is_instance_valid(b):
			b.position.y = absf(sin(_time * 2.6 + i * 1.7)) * 0.01
	for i in _smoke.size():
		var sm: Node3D = _smoke[i]
		if is_instance_valid(sm):
			var t: float = fmod(_time * 0.5 + i * 0.37, 1.0)
			var by: float = sm.get_meta("base_y", 0.0)
			sm.scale = Vector3.ONE * (0.6 + t * 1.2)
			sm.position.y = by + t * 0.12


# =============================================================================
# Inhalt bauen (Koordinaten im Inhalt: etwa −0,3 … 0,3)
# =============================================================================

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = field_id * 7919 + 17
	return rng


func _people(count: int, around: Vector3, radius: float) -> void:
	for k in count:
		var a: float = TAU * float(k) / maxf(1.0, float(count)) + 0.5
		var holder := Node3D.new()
		_content.add_child(holder)
		Models.person(holder, around + Vector3(cos(a) * radius, 0, sin(a) * radius * 0.6), Color("#3f86e8"))
		_bobbers.append(holder)


func _animal(kind: String, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	_content.add_child(holder)
	Models.animal(holder, pos, kind, rng.randf_range(0, 360))
	_bobbers.append(holder)


func _puff(pos: Vector3, r: float, c: Color) -> void:
	var puff := Node3D.new()
	puff.position = pos
	_content.add_child(puff)
	Models.sphere(puff, r, c, Vector3.ZERO)
	puff.set_meta("base_y", puff.position.y)
	_smoke.append(puff)


func _build_content(f: FieldData) -> void:
	var rng := _rng()
	var greens := [Color("#4fa449"), Color("#5cb357"), Color("#3f9443")]
	match f.stage:
		0:
			# Leere Erde: ein paar Steine, ein kleiner Keim, frisch verwüstet raucht es
			for k in 3:
				var a: float = rng.randf() * TAU
				Models.sphere(_content, 0.025, Color("#7d6450"), Vector3(cos(a) * 0.2, 0.012, sin(a) * 0.2), null, 0.6)
			if f.fresh > 0:
				Models.rbox(_content, Vector3(0.36, 0.012, 0.36), 0.13, Color("#4b3a2e"), Vector3.ZERO)
				_puff(Vector3(0, 0.06, 0), 0.05, Color(0.45, 0.42, 0.42, 0.7))
			else:
				Models.cone(_content, 0.02, 0.05, Color("#86c95a"), Vector3(0.05, 0, -0.04), 5)
				Models.cone(_content, 0.016, 0.04, Color("#86c95a"), Vector3(0.09, 0, -0.01), 5)
		1:
			# Wiese mit kleinem See
			Models.rbox(_content, Vector3(0.24, 0.016, 0.2), 0.09, WATER, Vector3(0.08, 0.0, 0.07), Vector3.ZERO, Models.mat(WATER, 0.1))
			var flowers := [Color("#ffffff"), Color("#ff9ec4"), Color("#ffe066")]
			for k in 6:
				var fp := Vector3(rng.randf_range(-0.26, -0.02), 0.015, rng.randf_range(-0.26, 0.24))
				Models.sphere(_content, 0.017, flowers[k % 3], fp)
			Models.cone(_content, 0.03, 0.06, Color("#79c24f"), Vector3(0.18, 0, -0.18), 5)
			_animal("lake", Vector3(0.09, 0.012, 0.07), rng)
		2:
			# Wald
			var spots := [Vector3(-0.17, 0, -0.15), Vector3(0.16, 0, -0.18), Vector3(-0.02, 0, 0.0),
				Vector3(0.17, 0, 0.14), Vector3(-0.18, 0, 0.17)]
			for k in spots.size():
				var g: Color = greens[k % greens.size()]
				if k % 2 == 0:
					Models.tree(_content, spots[k], rng.randf_range(1.0, 1.25), g)
				else:
					Models.pine(_content, spots[k], rng.randf_range(1.0, 1.2), g)
			_animal("forest", Vector3(0.08, 0, 0.18), rng)
		3:
			# Dorf
			Models.house(_content, Vector3(-0.1, 0, -0.08), ROOF, 1.0, rng.randf_range(-20, 20))
			Models.house(_content, Vector3(0.12, 0, -0.04), ROOF, 0.9, rng.randf_range(-20, 20))
			Models.tree(_content, Vector3(0.18, 0, 0.18), 0.7, greens[1])
			_people(2, Vector3(-0.05, 0, 0.14), 0.06)
		4:
			# Stadt
			Models.rbox(_content, Vector3(0.2, 0.008, 0.2), 0.05, Color("#c9c1b3"), Vector3(0.02, 0.0, 0.08))
			Models.tower(_content, Vector3(-0.14, 0, -0.13), 0.11, 0.34, ROOF)
			Models.house(_content, Vector3(0.02, 0, -0.17), ROOF, 1.15, 0)
			Models.tower(_content, Vector3(0.16, 0, -0.1), 0.1, 0.24, ROOF)
			Models.market(_content, Vector3(0.08, 0, 0.13), ROOF)
			_people(3, Vector3(-0.1, 0, 0.12), 0.06)
		_:
			# Fabrik
			_smoke.append_array(Models.factory(_content, Vector3(0.02, 0, -0.04), true))
			for s in _smoke:
				var sm: Node3D = s
				sm.set_meta("base_y", sm.position.y)
