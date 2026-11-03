class_name FieldView
extends Node3D
## Darstellung eines Felds: Kachel, Landschaft, Gebäude, Figuren, Tiere, Zahlen-Abzeichen.
## Lokales Koordinatensystem: y = Normale der Seite, Feld liegt in x/z (−0,45 … 0,45).

const TILE := 0.9
const TILE_H := 0.07
const TOP := 0.07

const TERRAIN_COLOR = {
	"meadow": "#a8dd78",
	"forest": "#7cc76c",
	"lake": "#f4e3b5",
	"mountain": "#cfc7ba",
	"crater": "#8c705f",
}
const WATER := Color("#63c6f2")

var field_id := -1
var _tile: MeshInstance3D
var _content: Node3D
var _people_label: Label3D
var _animal_label: Label3D
var _preview_label: Label3D
var _alert_label: Label3D
var _icon: Sprite3D
var _sel: MeshInstance3D
var _shown := ""
var _bobbers: Array = []
var _flames: Array = []
var _time := 0.0
var _labels_on := true


func build(f: FieldData) -> void:
	field_id = f.id
	_tile = Models.rbox(self, Vector3(TILE, TILE_H, TILE), 0.03, Color(TERRAIN_COLOR[f.terrain]), Vector3(0, TILE_H * 0.5, 0))
	_content = Node3D.new()
	_content.position.y = TOP
	add_child(_content)

	_sel = Models.rbox(self, Vector3(TILE + 0.04, 0.02, TILE + 0.04), 0.03, Color(1, 1, 1, 0.55), Vector3(0, 0.005, 0), Vector3.ZERO,
		Models.unshaded(Color(1, 1, 1, 0.55)))
	_sel.visible = false

	var body := StaticBody3D.new()
	body.set_meta("field_id", f.id)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.0, 0.2, 1.0)
	shape.shape = bs
	shape.position = Vector3(0, 0.0, 0)
	body.add_child(shape)
	add_child(body)

	_people_label = _make_label(54, Vector3(0, 0.52, 0))
	_animal_label = _make_label(40, Vector3(0.0, 0.4, 0.0))
	_animal_label.offset = Vector2(56, -20)
	_preview_label = _make_label(64, Vector3(0, 0.7, 0))
	_preview_label.outline_size = 18
	_alert_label = _make_label(60, Vector3(0, 0.8, 0))
	_alert_label.outline_modulate = Color("#e5483c")

	_icon = Sprite3D.new()
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.pixel_size = 0.0035
	_icon.position = Vector3(0, 0.62, 0)
	_icon.offset = Vector2(-56, 0)
	_icon.render_priority = 2
	_icon.visible = false
	add_child(_icon)


func _make_label(size: int, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font = Style.font()
	l.font_size = size
	l.pixel_size = 0.0028
	l.outline_size = 14
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


func set_labels_visible(on: bool) -> void:
	_labels_on = on
	_people_label.visible = on and _people_label.text != ""
	_animal_label.visible = on and _animal_label.text != ""
	_preview_label.visible = on and _preview_label.text != ""
	_alert_label.visible = on and _alert_label.text != ""
	_icon.visible = on and _icon.texture != null


## Vorschau-Zahl über dem Feld (+2 / −3). "" blendet aus.
func set_preview(text: String, good: bool) -> void:
	_preview_label.text = text
	_preview_label.outline_modulate = Color("#2f9e4f") if good else Color("#e5483c")
	_preview_label.visible = _labels_on and text != ""


## Kleines Symbol über dem Feld (Krieg, Handel, Hunger, Feuer). null blendet aus.
func set_icon(tex: Texture2D) -> void:
	_icon.texture = tex
	_icon.visible = _labels_on and tex != null


func refresh(f: FieldData, gs: GameState) -> void:
	var key := "%s|%d|%s|%d|%d|%s|%d" % [f.terrain, f.nation, f.building, mini(f.people, 9), mini(f.animals, 3), f.burning, f.volcano]
	var color := Color.WHITE
	if f.nation >= 0:
		color = Color(GameState.NATION_COLORS[f.nation])
	if key != _shown:
		var first := _shown == ""
		_shown = key
		_tile.material_override = Models.mat(Color(TERRAIN_COLOR.get(f.terrain, "#a8dd78")), 0.55)
		for c in _content.get_children():
			c.queue_free()
		_bobbers.clear()
		_flames.clear()
		_build_content(f, color)
		if not first:
			_content.scale = Vector3(0.7, 0.4, 0.7)
			var tw := create_tween()
			tw.tween_property(_content, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Abzeichen
	if f.settled() and f.people > 0:
		_people_label.text = str(f.people)
		_people_label.outline_modulate = color.darkened(0.15)
	else:
		_people_label.text = ""
	if f.animals > 0:
		_animal_label.text = str(f.animals)
		_animal_label.outline_modulate = Color("#5a9e3a")
	else:
		_animal_label.text = ""
	if f.volcano > 0:
		_alert_label.text = str(f.volcano)
	else:
		_alert_label.text = ""
	set_labels_visible(_labels_on)


func _process(delta: float) -> void:
	_time += delta
	for i in _bobbers.size():
		var b: Node3D = _bobbers[i]
		if is_instance_valid(b):
			b.position.y = absf(sin(_time * 3.2 + i * 1.7)) * 0.012
	for i in _flames.size():
		var fl: Node3D = _flames[i]
		if is_instance_valid(fl):
			var s := 0.85 + 0.2 * sin(_time * 14.0 + i * 2.1)
			fl.scale = Vector3(1.0, s, 1.0)


# =============================================================================
# Inhalt bauen
# =============================================================================

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = field_id * 7919 + 17
	return rng


func _build_content(f: FieldData, c: Color) -> void:
	var rng := _rng()
	var corners := [Vector3(-0.24, 0, -0.24), Vector3(0.24, 0, 0.24), Vector3(0.24, 0, -0.24), Vector3(-0.24, 0, 0.24)]
	var free_spots: Array = []

	# Gelände-Grundlage
	match f.terrain:
		"lake":
			Models.rbox(_content, Vector3(0.74, 0.02, 0.74), 0.09, WATER, Vector3(0, 0.0, 0), Vector3.ZERO, Models.mat(WATER, 0.12))
		"crater":
			Models.rbox(_content, Vector3(0.6, 0.015, 0.6), 0.2, Color("#5e4637"), Vector3(0, 0.0, 0))
			for k in 3:
				var a := rng.randf() * TAU
				Models.sphere(_content, 0.03, Color("#6e5a4c"), Vector3(cos(a) * 0.3, 0.015, sin(a) * 0.3), null, 0.6)

	# Gebäude
	if f.settled():
		match f.building:
			"village":
				var houses := clampi(int(ceil(f.people / 3.0)), 1, 3)
				var spots := [Vector3(-0.15, 0, -0.14), Vector3(0.17, 0, -0.1), Vector3(-0.05, 0, 0.17)]
				for k in houses:
					Models.house(_content, spots[k], c, 1.0, rng.randf_range(-25, 25))
				free_spots = [corners[1], corners[3]]
			"church":
				Models.church(_content, Vector3(0, 0, -0.05), c)
				free_spots = [corners[1], corners[3]]
			"market":
				Models.market(_content, Vector3(0, 0, -0.04), c)
				free_spots = [corners[1], corners[3]]
		var n_people := mini(f.people, 4)
		for k in n_people:
			var a := TAU * float(k) / maxf(1.0, float(n_people)) + 0.4
			var pp := Vector3(cos(a) * 0.12, 0, 0.16 + sin(a) * 0.08)
			var holder := Node3D.new()
			_content.add_child(holder)
			Models.person(holder, pp, c)
			_bobbers.append(holder)
	else:
		free_spots = corners.duplicate()

	# Landschaft
	match f.terrain:
		"forest":
			var greens := [Color("#4fa449"), Color("#5cb357"), Color("#3f9443")]
			var tree_spots: Array = free_spots if f.settled() else [Vector3(-0.22, 0, -0.2), Vector3(0.2, 0, -0.24), Vector3(-0.05, 0, 0.0), Vector3(0.22, 0, 0.18), Vector3(-0.24, 0, 0.22)]
			for k in tree_spots.size():
				var sp: Vector3 = tree_spots[k]
				var g: Color = greens[k % greens.size()]
				if k % 2 == 0:
					Models.tree(_content, sp, rng.randf_range(0.9, 1.25), g)
				else:
					Models.pine(_content, sp, rng.randf_range(0.9, 1.2), g)
		"meadow":
			if not f.settled():
				for k in 3:
					var gp := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
					Models.cone(_content, 0.03, 0.06, Color("#86c95a"), gp, 6)
				var flowers := [Color("#ffffff"), Color("#ff9ec4"), Color("#ffe066")]
				for k in 4:
					var fp := Vector3(rng.randf_range(-0.32, 0.32), 0.02, rng.randf_range(-0.32, 0.32))
					Models.sphere(_content, 0.018, flowers[k % 3], fp)
		"mountain":
			if f.volcano > 0:
				Models.cone(_content, 0.22, 0.3, Color("#8c7f74"), Vector3(0, 0, 0), 9)
				Models.cyl(_content, 0.07, 0.07, 0.02, Color("#ff5a1f"), Vector3(0, 0.27, 0), 10, Vector3.ZERO, Models.mat(Color("#ff5a1f"), 0.5, 2.5))
				for k in 3:
					Models.sphere(_content, 0.04 + k * 0.012, Color(0.55, 0.55, 0.58, 0.75), Vector3(0.02 * k, 0.36 + k * 0.07, 0.0))
			elif not f.settled():
				Models.rock(_content, Vector3(-0.08, 0, -0.06), rng.randf_range(1.1, 1.4), true)
				Models.rock(_content, Vector3(0.18, 0, 0.12), rng.randf_range(0.7, 0.9), true)
			else:
				Models.rock(_content, corners[1], 0.6, true)
		"lake":
			Models.cyl(_content, 0.04, 0.04, 0.006, Color("#5fae4f"), Vector3(-0.18, 0.012, 0.16), 12)
			Models.cyl(_content, 0.03, 0.03, 0.006, Color("#6fbd5b"), Vector3(0.2, 0.012, -0.2), 12)

	# Tiere
	var n_animals := mini(f.animals, 3)
	for k in n_animals:
		var ap: Vector3 = free_spots[k % maxi(1, free_spots.size())] if not free_spots.is_empty() else Vector3.ZERO
		ap += Vector3(rng.randf_range(-0.06, 0.06), 0.0, rng.randf_range(-0.06, 0.06)) + Vector3(0.05 * k, 0, -0.04 * k)
		if f.terrain == "lake":
			ap.y = 0.012
		var holder := Node3D.new()
		_content.add_child(holder)
		Models.animal(holder, ap, f.terrain, rng.randf_range(0, 360))
		_bobbers.append(holder)

	# Feuer
	if f.burning:
		for k in 3:
			var fp := Vector3(-0.2 + k * 0.2, 0.0, rng.randf_range(-0.2, 0.2))
			_flames.append(Models.flame(_content, fp, rng.randf_range(1.1, 1.6)))
