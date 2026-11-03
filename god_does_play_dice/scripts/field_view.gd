class_name FieldView
extends Node3D
## Darstellung eines Felds: Boden, Rohstoffmodell, Hütten je Stufe, Figuren, Rahmen, Schild.
## Lokales Koordinatensystem: y = Normale der Seite, Feld liegt in x/z (−0,46 … 0,46).

const TILE := 0.92
const GROUND_H := 0.06
const QUARTERS = [Vector2(-0.22, -0.22), Vector2(0.22, 0.22), Vector2(0.22, -0.22), Vector2(-0.22, 0.22)]

const TERRAIN_COLOR = {
	"meadow": "#9fd67a",
	"forest": "#5f9e57",
	"lake": "#e9d9a6",
	"mountain": "#a8a297",
	"gold": "#e2c46e",
}
const HUT_ROOF = {
	"meadow": "#c8553d",
	"forest": "#8a5a2b",
	"lake": "#3f7cc0",
	"mountain": "#6d6a66",
	"gold": "#b5651d",
}
const NEUTRAL_CENTER := "#c9c2b2"

var field_id := -1
var terrain := ""
var is_center := false

var _ground: MeshInstance3D
var _content: Node3D        # Rohstoffmodell + Hütten (wird bei Stufenwechsel neu gebaut)
var _frame: Node3D          # Rahmen in Besitzerfarbe
var _sel: Node3D            # weißer Auswahlrahmen
var _hl: MeshInstance3D     # kurze Markierung beim Drehen
var _label: Label3D
var _mark: Label3D
var _shown := ""            # Schlüssel des zuletzt gebauten Inhalts
var _frame_owner := -2
var _hl_time := 0.0


func build(f: FieldData) -> void:
	field_id = f.id
	terrain = f.terrain
	is_center = f.is_center

	_ground = Models.box(self, Vector3(TILE, GROUND_H, TILE), Color(_ground_color(f, null)), Vector3(0, GROUND_H * 0.5, 0))
	if terrain == "lake" and not is_center:
		# Ganzes Feld ist Wasser, mit schmalem Sandrand
		Models.box(self, Vector3(TILE - 0.08, 0.012, TILE - 0.08), Color("#4d9bd3"), Vector3(0, GROUND_H + 0.004, 0), Vector3.ZERO,
			Models.mat(Color("#4d9bd3"), 0.1, 0.25))

	_content = Node3D.new()
	_content.position.y = GROUND_H
	add_child(_content)

	_frame = _make_frame(0.055, 0.035, TILE, Color.WHITE)
	_frame.position.y = GROUND_H
	_frame.visible = false

	_sel = _make_frame(0.05, 0.05, TILE + 0.06, Color.WHITE)
	_sel.position.y = GROUND_H + 0.03
	_set_frame_color(_sel, Color.WHITE, 0.6)
	_sel.visible = false

	_hl = Models.box(self, Vector3(TILE, 0.02, TILE), Color(1, 1, 1, 0.5), Vector3(0, GROUND_H + 0.06, 0))
	_hl.visible = false

	var body := StaticBody3D.new()
	body.set_meta("field_id", f.id)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.98, 0.3, 0.98)
	shape.shape = bs
	shape.position = Vector3(0, 0.1, 0)
	body.add_child(shape)
	add_child(body)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.pixel_size = 0.0034
	_label.outline_size = 12
	_label.outline_modulate = Color(0.12, 0.1, 0.08, 0.85)
	_label.position = Vector3(0, 0.5, 0)
	_label.render_priority = 1
	_label.outline_render_priority = 0
	add_child(_label)

	_mark = Label3D.new()
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.font_size = 44
	_mark.pixel_size = 0.0034
	_mark.outline_size = 12
	_mark.modulate = Color("#3ee05a")
	_mark.outline_modulate = Color(0.05, 0.2, 0.05, 0.9)
	_mark.position = Vector3(0, 0.5, 0)
	_mark.offset = Vector2(78, 6)
	_mark.render_priority = 1
	add_child(_mark)
	_mark.visible = false


func _ground_color(f: FieldData, gs: GameState) -> String:
	if not f.is_center:
		return TERRAIN_COLOR.get(f.terrain, "#9fd67a")
	if gs != null and f.owner >= 0:
		var c: Color = gs.players[f.owner].color
		return c.lerp(Color.WHITE, 0.55).to_html(false)
	return NEUTRAL_CENTER


## Darstellung an den Logikzustand anpassen. mark: "" / "↑" / "+"
func refresh(f: FieldData, gs: GameState, mark: String, human: int) -> void:
	var owner_color := Color.WHITE
	if f.owner >= 0:
		owner_color = gs.players[f.owner].color
	# Inhalt (nur neu bauen, wenn sich etwas geändert hat)
	var stage := 0
	if f.is_center and f.owner >= 0:
		stage = gs.players[f.owner].stage
	var people := 0
	if f.is_center and f.owner == GameState.HUMAN:
		people = mini(gs.players[f.owner].residents, 6)
	var key := "%d|%d|%d|%d" % [f.level, f.owner, stage, people]
	if key != _shown:
		_shown = key
		for c in _content.get_children():
			c.queue_free()
		if f.is_center:
			_ground.material_override = Models.mat(Color(_ground_color(f, gs)))
			_build_center(f, gs, stage, owner_color)
		else:
			_build_terrain(f, owner_color)

	# Rahmen in Besitzerfarbe
	if f.owner != _frame_owner:
		_frame_owner = f.owner
		_frame.visible = f.owner >= 0 and not f.is_center
		if f.owner >= 0:
			_set_frame_color(_frame, owner_color, 0.0)

	# Feld-Schild: Rohstoff-Symbol + Stufen-Punkte
	if f.is_center:
		_label.text = ""
	else:
		var res: String = GameState.TERRAIN_RES[f.terrain]
		var dots := ""
		for i in Balance.MAX_FIELD_LEVEL:
			dots += "●" if i < f.level else "○"
		_label.text = "%s %s" % [GameState.RES_ICON[res], dots]
	_mark.text = mark
	_mark.visible = mark != ""
	if f.is_center and f.home == human:
		_label.text = ""


func set_selected(on: bool) -> void:
	_sel.visible = on


func set_labels_visible(on: bool) -> void:
	_label.visible = on and _label.text != ""
	_mark.visible = on and _mark.text != ""


## Kurze Markierung in Spielerfarbe (beim Drehen).
func flash(color: Color, seconds: float) -> void:
	_hl.material_override = Models.mat(Color(color.r, color.g, color.b, 0.55), 0.0, 0.6, 0.4)
	_hl.visible = true
	_hl_time = seconds


func _process(delta: float) -> void:
	if _hl_time > 0.0:
		_hl_time -= delta
		if _hl_time <= 0.0:
			_hl.visible = false


func world_normal() -> Vector3:
	return global_transform.basis.y.normalized()


func label_world_pos() -> Vector3:
	return global_transform * Vector3(0, 0.35, 0)


# =============================================================================
# Bauen
# =============================================================================

func _make_frame(width: float, height: float, size: float, color: Color) -> Node3D:
	var fr := Node3D.new()
	add_child(fr)
	var half := size * 0.5 - width * 0.5
	var m := Models.mat(color)
	Models.box(fr, Vector3(width, height, size), color, Vector3(-half, height * 0.5, 0), Vector3.ZERO, m)
	Models.box(fr, Vector3(width, height, size), color, Vector3(half, height * 0.5, 0), Vector3.ZERO, m)
	Models.box(fr, Vector3(size, height, width), color, Vector3(0, height * 0.5, -half), Vector3.ZERO, m)
	Models.box(fr, Vector3(size, height, width), color, Vector3(0, height * 0.5, half), Vector3.ZERO, m)
	return fr


func _set_frame_color(fr: Node3D, color: Color, emission: float) -> void:
	var m := Models.mat(color, 0.0, 0.7, emission)
	for c in fr.get_children():
		(c as MeshInstance3D).material_override = m


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = field_id * 7919 + 13
	return rng


func _build_terrain(f: FieldData, owner_color: Color) -> void:
	var rng := _rng()
	var n_huts := f.level
	for qi in 4:
		var q: Vector2 = QUARTERS[qi]
		var at := Vector3(q.x, 0, q.y)
		if qi < n_huts:
			_build_hut(f.terrain, at, rng)
			if f.owner >= 0:
				Models.figure(_content, at + Vector3(0.1, 0, 0.1), owner_color)
		else:
			_build_deco(f.terrain, at, rng)


func _build_deco(t: String, at: Vector3, rng: RandomNumberGenerator) -> void:
	var j := Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.05, 0.05))
	match t:
		"meadow":
			Models.cone(_content, 0.03, 0.07, Color("#6cbf4a"), at + j, 5)
			Models.cone(_content, 0.025, 0.06, Color("#78c955"), at + j + Vector3(0.07, 0, 0.04), 5)
			var flower := [Color("#ffffff"), Color("#ff9ec4"), Color("#ffe066")][rng.randi_range(0, 2)] as Color
			Models.sphere(_content, 0.022, flower, at - j + Vector3(-0.05, 0.03, 0.06))
		"forest":
			Models.tree(_content, at + j + Vector3(-0.06, 0, -0.05), rng.randf_range(0.85, 1.15))
			Models.tree(_content, at - j + Vector3(0.07, 0, 0.06), rng.randf_range(0.7, 1.0))
		"lake":
			Models.cyl(_content, 0.045, 0.045, 0.008, Color("#5fae4f"), at + j + Vector3(0, 0.012, 0), 8)
			if rng.randf() < 0.5:
				Models.sphere(_content, 0.018, Color("#ffffff"), at + j + Vector3(0.02, 0.03, 0.0))
		"mountain":
			Models.rock(_content, at + j * 0.5, rng.randf_range(0.75, 1.1), true)
		"gold":
			var gm := Models.mat(Color("#ffcc33"), 0.9, 0.22, 0.15)
			Models.sphere(_content, 0.04, Color.WHITE, at + j + Vector3(0, 0.025, 0), gm)
			Models.sphere(_content, 0.03, Color.WHITE, at + j + Vector3(0.06, 0.02, 0.03), gm)
			Models.box(_content, Vector3(0.05, 0.04, 0.04), Color.WHITE, at - j + Vector3(-0.05, 0.02, 0.05), Vector3(0, 30, 20), gm)
			Models.cone(_content, 0.05, 0.08, Color("#9b9384"), at + Vector3(-0.08, 0, -0.07), 5)


func _build_hut(t: String, at: Vector3, rng: RandomNumberGenerator) -> void:
	var roof_c := Color(HUT_ROOF.get(t, "#c8553d"))
	match t:
		"meadow":   # Acker
			Models.hut(_content, at + Vector3(-0.06, 0, -0.06), roof_c)
			var wheat := Models.mat(Color("#e8c547"))
			Models.box(_content, Vector3(0.14, 0.025, 0.06), Color.WHITE, at + Vector3(0.06, 0.012, 0.04), Vector3.ZERO, wheat)
			Models.box(_content, Vector3(0.14, 0.025, 0.04), Color("#a8743a"), at + Vector3(0.06, 0.008, 0.1))
		"forest":   # Holzfäller
			Models.hut(_content, at + Vector3(-0.05, 0, -0.05), roof_c)
			Models.cyl(_content, 0.018, 0.018, 0.12, Color("#9c6b3c"), at + Vector3(0.08, 0.018, 0.02), 6, Vector3(90, 0, 0))
			Models.cyl(_content, 0.018, 0.018, 0.12, Color("#8a5d33"), at + Vector3(0.11, 0.018, 0.02), 6, Vector3(90, 0, 0))
			Models.tree(_content, at + Vector3(0.1, 0, -0.1), 0.7)
		"lake":     # Fischer auf Stelzen mit Boot
			for dx in [-0.05, 0.05]:
				for dz in [-0.045, 0.045]:
					Models.cyl(_content, 0.006, 0.006, 0.05, Color("#6b4a2f"), at + Vector3(dx - 0.04, 0, dz - 0.04), 4)
			Models.box(_content, Vector3(0.16, 0.012, 0.14), Color("#a8743a"), at + Vector3(-0.04, 0.05, -0.04))
			Models.hut(_content, at + Vector3(-0.04, 0.056, -0.04), roof_c, 0.9)
			Models.box(_content, Vector3(0.1, 0.025, 0.045), Color("#8a5d33"), at + Vector3(0.09, 0.02, 0.1), Vector3(0, rng.randf_range(-30, 30), 0))
		"mountain": # Steinbruch
			Models.hut(_content, at + Vector3(-0.05, 0, -0.05), roof_c)
			Models.box(_content, Vector3(0.05, 0.04, 0.05), Color("#b9b4aa"), at + Vector3(0.07, 0.02, 0.05))
			Models.box(_content, Vector3(0.045, 0.035, 0.045), Color("#9e998f"), at + Vector3(0.12, 0.018, 0.0), Vector3(0, 25, 0))
			Models.rock(_content, at + Vector3(0.08, 0, -0.1), 0.45, true)
		"gold":     # Mine
			Models.hut(_content, at + Vector3(-0.06, 0, -0.06), roof_c)
			Models.box(_content, Vector3(0.1, 0.09, 0.06), Color("#8d877c"), at + Vector3(0.07, 0.045, 0.06))
			Models.box(_content, Vector3(0.05, 0.06, 0.01), Color("#2e2620"), at + Vector3(0.07, 0.03, 0.093))
			Models.sphere(_content, 0.025, Color.WHITE, at + Vector3(0.0, 0.02, 0.12), Models.mat(Color("#ffcc33"), 0.9, 0.22, 0.15))


func _build_center(f: FieldData, gs: GameState, stage: int, c: Color) -> void:
	if f.owner < 0:
		# Neutrales Zentrum: alte Steinsäule und etwas Gras
		Models.cyl(_content, 0.05, 0.06, 0.22, Color("#bdb6a8"), Vector3(0, 0, 0), 6)
		Models.box(_content, Vector3(0.16, 0.03, 0.16), Color("#a39c8e"), Vector3(0, 0.015, 0))
		Models.cone(_content, 0.03, 0.07, Color("#7fbf5a"), Vector3(0.2, 0, 0.15), 5)
		Models.cone(_content, 0.03, 0.06, Color("#7fbf5a"), Vector3(-0.18, 0, -0.2), 5)
		return
	if stage >= 3:
		Models.box(_content, Vector3(0.8, 0.02, 0.8), Color("#d8d1c4"), Vector3(0, 0.01, 0))
		for i in 4:
			var a: float = i * PI * 0.5 + PI * 0.25
			Models.box(_content, Vector3(0.05, 0.022, 0.05), Color("#bfb7a8"), Vector3(cos(a) * 0.33, 0.012, sin(a) * 0.33))
	var flag_pos := Vector3(0.3, 0, -0.3)
	if stage == 1:
		# Zelt mit Lagerfeuer und Fahne
		Models.cyl(_content, 0.0, 0.17, 0.24, c, Vector3(-0.08, 0, -0.06), 4, Vector3(0, 45, 0))
		Models.box(_content, Vector3(0.06, 0.08, 0.004), Color("#4a3a2a"), Vector3(-0.08, 0.04, 0.06))
		for i in 3:
			var a: float = i * TAU / 3.0
			Models.cyl(_content, 0.01, 0.01, 0.09, Color("#7a5230"), Vector3(0.15 + cos(a) * 0.02, 0.012, 0.15 + sin(a) * 0.02), 5, Vector3(90, rad_to_deg(a), 0))
		Models.sphere(_content, 0.032, Color.WHITE, Vector3(0.15, 0.04, 0.15), Models.mat(Color("#ff8a1f"), 0.0, 0.5, 2.0))
	else:
		# Haus
		Models.box(_content, Vector3(0.24, 0.16, 0.2), Color("#f3e3c3"), Vector3(-0.1, 0.08, -0.08))
		Models.roof(_content, Vector3(0.29, 0.12, 0.24), c, Vector3(-0.1, 0.16, -0.08))
		Models.box(_content, Vector3(0.05, 0.09, 0.004), Color("#6b4a2f"), Vector3(-0.1, 0.045, 0.022))
		Models.box(_content, Vector3(0.04, 0.04, 0.004), Color("#bfe3ff"), Vector3(-0.17, 0.1, 0.022))
	if stage >= 3:
		# Marktstand mit Markise
		var mp := Vector3(0.2, 0, 0.2)
		for dx in [-0.06, 0.06]:
			Models.cyl(_content, 0.006, 0.006, 0.1, Color("#7a5230"), mp + Vector3(dx, 0, 0.04), 4)
		Models.box(_content, Vector3(0.14, 0.04, 0.08), Color("#a8743a"), mp + Vector3(0, 0.02, -0.01))
		Models.box(_content, Vector3(0.16, 0.015, 0.11), c.lerp(Color.WHITE, 0.25), mp + Vector3(0, 0.1, 0.0), Vector3(-12, 0, 0))
		Models.sphere(_content, 0.018, Color("#e04a3a"), mp + Vector3(-0.03, 0.05, -0.01))
		Models.sphere(_content, 0.018, Color("#f2b705"), mp + Vector3(0.02, 0.05, -0.02))
	if stage >= 4:
		# Turm (Kaserne)
		var tp := Vector3(-0.24, 0, 0.22)
		Models.cyl(_content, 0.07, 0.08, 0.3, Color("#b9b2a5"), tp, 8)
		Models.cone(_content, 0.1, 0.14, c, tp + Vector3(0, 0.3, 0), 8)
	if stage >= 5:
		# Glasturm (Werkstatt)
		var glass := Models.mat(Color(0.62, 0.89, 1.0, 0.7), 0.6, 0.1, 0.25)
		Models.box(_content, Vector3(0.11, 0.48, 0.11), Color.WHITE, Vector3(0.18, 0.24, -0.08), Vector3.ZERO, glass)
		Models.box(_content, Vector3(0.13, 0.02, 0.13), Color("#d9e6ec"), Vector3(0.18, 0.49, -0.08))
	# Fahne
	Models.cyl(_content, 0.008, 0.008, 0.36, Color("#e8e2d6"), flag_pos, 5)
	Models.box(_content, Vector3(0.004, 0.07, 0.12), c, flag_pos + Vector3(0, 0.31, 0.06))
	# Bewohner im Zentrum (sichtbar, wie viele frei sind; nur beim eigenen Land, Gegner sieht man nicht)
	if gs != null and f.owner == GameState.HUMAN:
		var free_n := mini(gs.players[f.owner].residents, 6)
		for i in free_n:
			var a: float = i * TAU / 6.0
			Models.figure(_content, Vector3(0.05 + cos(a) * 0.13, 0, 0.2 + sin(a) * 0.06), c)
