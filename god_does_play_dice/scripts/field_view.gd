class_name FieldView
extends Node3D
## Darstellung eines Felds: Kachel (Farbe je Stufe), Modelle, Hervorhebungen.
## Lokales Koordinatensystem: y = Normale der Seite, Feld liegt in x/z (−0,45 … 0,45).
## Stufen: 0 Erde, 1 Wiese, 2 kleiner Wald, 3 großer Wald, 4 Hütte, 5 Haus, 6 Dorf, 7 Stadt, 8 Großstadt, 9 Metropole.

const TILE := 0.9
const TILE_H := 0.09
const TOP := 0.09
const CONTENT_SCALE := 1.4

const TILE_COLOR = ["#a5805c", "#8fd162", "#6cc25a", "#2b6b35", "#d9c08a", "#ebc97f", "#e6b468", "#d4cdc2", "#bdb6ad", "#9aa0ab"]
const WATER := Color("#36aef0")
const ROOF := Color("#e5574a")

var field_id := -1
var _tile: MeshInstance3D
var _content: Node3D
var _preview_label: Label3D
var _sel: MeshInstance3D
var _glow: MeshInstance3D
var _glow_top: MeshInstance3D
var _danger: MeshInstance3D
var _danger_top: MeshInstance3D
var _hint: MeshInstance3D
var _hint_mat: StandardMaterial3D
var _hint_on := false
var _shown := ""
var _bobbers: Array = []
var _smoke: Array = []
var _time := 0.0
var _labels_on := true
var _badge: Sprite3D             # Abzeichen über dem Feld (z. B. Tropfen: hier lohnt sich Gießen)
var _badge_name := ""


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
	_danger = Models.rbox(self, Vector3(TILE + 0.08, 0.03, TILE + 0.08), 0.05, Color("#e5483c"), Vector3(0, 0.012, 0), Vector3.ZERO,
		Models.mat(Color("#e5483c"), 0.3, 2.0))
	_danger.visible = false
	_danger_top = Models.rbox(self, Vector3(TILE - 0.03, 0.014, TILE - 0.03), 0.03, Color.WHITE, Vector3(0, TOP + 0.008, 0), Vector3.ZERO,
		Models.unshaded(Color(0.9, 0.18, 0.12, 0.42)))
	_danger_top.visible = false
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
	_badge = Sprite3D.new()
	_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_badge.pixel_size = 0.0042
	_badge.position = Vector3(0, 0.55, 0)
	_badge.render_priority = 4
	_badge.no_depth_test = true
	_badge.visible = false
	add_child(_badge)


func world_normal() -> Vector3:
	return global_transform.basis.y.normalized()


func label_world_pos() -> Vector3:
	return global_transform * Vector3(0, 0.45, 0)


func set_selected(on: bool) -> void:
	_sel.visible = on


func set_labels_visible(on: bool) -> void:
	_labels_on = on
	_preview_label.visible = on and _preview_label.text != ""
	_badge.visible = on and _badge_name != "" and _preview_label.text == ""


## Abzeichen über dem Feld: Symbolname (z. B. "rain") oder "" zum Ausblenden. Hüpft leicht.
func set_badge(icon_name: String) -> void:
	if icon_name == _badge_name:
		return
	_badge_name = icon_name
	if icon_name != "":
		_badge.texture = Style.icon(icon_name)
	_badge.visible = _labels_on and icon_name != ""


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


## Das Feld brennt: flackernde Flammen über dem Inhalt.
func _add_flames() -> void:
	for k in 4:
		var pos := Vector3(randf_range(-0.2, 0.2), 0.02, randf_range(-0.2, 0.2))
		var fl := Models.flame(_content, pos, randf_range(1.1, 1.7))
		var tw := fl.create_tween().set_loops()
		var t := randf_range(0.18, 0.3)
		tw.tween_property(fl, "scale", Vector3(0.85, 1.25, 0.85), t).set_trans(Tween.TRANS_SINE)
		tw.tween_property(fl, "scale", Vector3(1.1, 0.8, 1.1), t).set_trans(Tween.TRANS_SINE)


## Rotes Leuchten: hier würde gleich eine Katastrophe zuschlagen.
func set_danger(on: bool) -> void:
	_danger.visible = on
	_danger_top.visible = on


## Erdbeben: der Inhalt ruckelt und kippt.
func quake(dur: float = 0.9) -> void:
	var tw := create_tween()
	var base := Vector3(0, TOP, 0)
	var steps := 10
	for i in steps:
		var k := 1.0 - float(i) / float(steps)
		tw.tween_property(_content, "position", base + Vector3(randf_range(-0.07, 0.07) * k, randf_range(0.0, 0.05) * k, randf_range(-0.07, 0.07) * k), dur / float(steps))
		tw.parallel().tween_property(_content, "rotation", Vector3(randf_range(-0.15, 0.15) * k, 0.0, randf_range(-0.15, 0.15) * k), dur / float(steps))
	tw.tween_property(_content, "position", base, 0.08)
	tw.parallel().tween_property(_content, "rotation", Vector3.ZERO, 0.08)


## Überschwemmung: Wasser steigt über das Feld und fließt wieder ab.
func flood(dur: float = 1.3) -> void:
	var m := Models.unshaded(Color(0.24, 0.62, 0.95, 0.78))
	var water := Models.rbox(self, Vector3(TILE, 0.02, TILE), 0.04, Color.WHITE, Vector3(0, TOP, 0), Vector3.ZERO, m)
	var tw := water.create_tween()
	tw.tween_property(water, "scale", Vector3(1.0, 16.0, 1.0), dur * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(water, "position", Vector3(0, TOP + 0.16, 0), dur * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur * 0.25)
	tw.tween_property(water, "scale", Vector3(1.0, 0.5, 1.0), dur * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(water, "position", Vector3(0, TOP, 0), dur * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(water.queue_free)
	var sink := create_tween()
	sink.tween_interval(dur * 0.3)
	sink.tween_property(_content, "scale", Vector3.ONE * 0.05, dur * 0.3).set_ease(Tween.EASE_IN)


## Waldbrand: Flammen lodern auf, der Wald verkohlt.
func burn(dur: float = 1.1) -> void:
	var fire := Node3D.new()
	fire.position = Vector3(0, TOP, 0)
	add_child(fire)
	for i in 5:
		var fl := Models.flame(fire, Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3)), randf_range(1.6, 2.6))
		fl.scale = Vector3.ONE * 0.05
		var tw := fl.create_tween()
		tw.tween_interval(randf_range(0.0, 0.2))
		tw.tween_property(fl, "scale", Vector3.ONE, dur * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(fl, "scale", Vector3(1.2, 1.4, 1.2), dur * 0.2)
		tw.tween_property(fl, "scale", Vector3.ONE * 0.05, dur * 0.3).set_ease(Tween.EASE_IN)
	var dark := create_tween()
	dark.tween_interval(dur * 0.35)
	dark.tween_property(_content, "scale", Vector3(CONTENT_SCALE, 0.05, CONTENT_SCALE), dur * 0.4).set_ease(Tween.EASE_IN)
	var done := create_tween()
	done.tween_interval(dur)
	done.tween_callback(fire.queue_free)


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
	var key := "%d|%d|%d" % [f.stage, mini(f.fresh, 1), 1 if f.burning else 0]
	if key == _shown:
		return
	var first := _shown == ""
	_shown = key
	_tile.material_override = Models.mat(Color(TILE_COLOR[clampi(f.stage, 0, TILE_COLOR.size() - 1)]), 0.7)
	for c in _content.get_children():
		c.queue_free()
	_bobbers.clear()
	_smoke.clear()
	_build_content(f)
	if f.burning:
		_add_flames()
	_content.position = Vector3(0, TOP, 0)
	if first:
		_content.scale = Vector3.ONE * CONTENT_SCALE
	else:
		_content.scale = Vector3(0.6, 0.3, 0.6) * CONTENT_SCALE
		var tw := create_tween()
		tw.tween_property(_content, "scale", Vector3.ONE * CONTENT_SCALE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	if _badge.visible:
		var k := 0.5 + 0.5 * sin(_time * 4.0 + float(field_id))
		_badge.position.y = 0.55 + k * 0.08
		_badge.scale = Vector3.ONE * (0.9 + 0.15 * k)
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
			# Erde: ein paar Steine, ein kleiner Keim, frisch verwüstet raucht es
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
			# Kleiner Wald: ein paar junge Bäume
			Models.tree(_content, Vector3(-0.12, 0, -0.1), 0.75, greens[1])
			Models.pine(_content, Vector3(0.12, 0, -0.06), 0.7, greens[0])
			Models.tree(_content, Vector3(0.0, 0, 0.14), 0.65, greens[2])
			Models.cone(_content, 0.03, 0.06, Color("#79c24f"), Vector3(-0.18, 0, 0.18), 5)
			_animal("meadow", Vector3(0.15, 0, 0.16), rng)
		3:
			# Großer Wald
			var spots := [Vector3(-0.17, 0, -0.15), Vector3(0.16, 0, -0.18), Vector3(-0.02, 0, 0.0),
				Vector3(0.17, 0, 0.14), Vector3(-0.18, 0, 0.17)]
			for k in spots.size():
				var g: Color = (greens[k % greens.size()] as Color).darkened(0.35)
				if k % 2 == 0:
					Models.tree(_content, spots[k], rng.randf_range(1.05, 1.3), g)
				else:
					Models.pine(_content, spots[k], rng.randf_range(1.05, 1.25), g)
			_animal("forest", Vector3(0.08, 0, 0.18), rng)
		4:
			# Hütte am Waldrand
			Models.workshop(_content, Vector3(-0.04, 0, -0.06))
			Models.tree(_content, Vector3(0.17, 0, 0.12), 0.8, greens[0])
			Models.pine(_content, Vector3(-0.18, 0, 0.16), 0.7, greens[2])
			_people(1, Vector3(0.05, 0, 0.16), 0.03)
		5:
			# Haus mit Garten
			Models.house(_content, Vector3(-0.04, 0, -0.06), ROOF, 1.35, 0)
			Models.rbox(_content, Vector3(0.18, 0.014, 0.12), 0.03, Color("#8a5a35"), Vector3(0.12, 0.0, 0.15))
			for k in 3:
				Models.sphere(_content, 0.02, Color("#5cb357"), Vector3(0.06 + k * 0.06, 0.02, 0.15))
			Models.tree(_content, Vector3(-0.18, 0, 0.16), 0.7, greens[1])
			_people(1, Vector3(-0.05, 0, 0.17), 0.03)
		6:
			# Dorf: mehrere Häuser
			Models.house(_content, Vector3(-0.13, 0, -0.12), ROOF, 1.0, rng.randf_range(-15, 15))
			Models.house(_content, Vector3(0.13, 0, -0.1), ROOF, 0.95, rng.randf_range(-15, 15))
			Models.house(_content, Vector3(-0.1, 0, 0.13), ROOF, 0.9, 90)
			Models.tree(_content, Vector3(0.17, 0, 0.16), 0.7, greens[1])
			_people(2, Vector3(0.04, 0, 0.06), 0.05)
		7:
			# Stadt
			Models.rbox(_content, Vector3(0.2, 0.008, 0.2), 0.05, Color("#c9c1b3"), Vector3(0.02, 0.0, 0.08))
			Models.tower(_content, Vector3(-0.14, 0, -0.13), 0.11, 0.26, ROOF)
			Models.house(_content, Vector3(0.02, 0, -0.17), ROOF, 1.15, 0)
			Models.tower(_content, Vector3(0.16, 0, -0.1), 0.1, 0.2, ROOF)
			Models.market(_content, Vector3(0.08, 0, 0.13), ROOF)
			_people(3, Vector3(-0.1, 0, 0.12), 0.06)
		8:
			# Großstadt: viele höhere Häuser
			Models.tower(_content, Vector3(-0.15, 0, -0.14), 0.12, 0.4, ROOF)
			Models.tower(_content, Vector3(0.02, 0, -0.16), 0.11, 0.32, Color("#3f86e8"))
			Models.tower(_content, Vector3(0.17, 0, -0.08), 0.1, 0.28, ROOF)
			Models.tower(_content, Vector3(-0.14, 0, 0.12), 0.1, 0.24, Color("#3f86e8"))
			Models.tower(_content, Vector3(0.12, 0, 0.15), 0.11, 0.34, ROOF)
			_people(2, Vector3(0.0, 0, 0.02), 0.05)
		_:
			# Metropole: Glastürme
			var glass := Models.mat(Color("#8fc9ee"), 0.15, 0.2, 0.3)
			Models.rbox(_content, Vector3(0.12, 0.62, 0.12), 0.015, Color.WHITE, Vector3(-0.02, 0.31, -0.05), Vector3.ZERO, glass)
			Models.cone(_content, 0.03, 0.12, Color("#e5574a"), Vector3(-0.02, 0.62, -0.05), 8)
			Models.tower(_content, Vector3(-0.18, 0, -0.16), 0.1, 0.44, Color("#3f86e8"))
			Models.tower(_content, Vector3(0.16, 0, -0.14), 0.1, 0.5, ROOF)
			Models.rbox(_content, Vector3(0.1, 0.36, 0.1), 0.015, Color.WHITE, Vector3(0.15, 0.18, 0.14), Vector3.ZERO, glass)
			Models.tower(_content, Vector3(-0.16, 0, 0.15), 0.1, 0.3, Color("#3f86e8"))
			_people(2, Vector3(0.0, 0, 0.18), 0.05)
