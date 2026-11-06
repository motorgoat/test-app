class_name FieldView
extends Node3D
## Darstellung eines Felds: Kachel (Farbe je Art), Modelle, Hervorhebungen, Zustände.
## Lokales Koordinatensystem: y = Normale der Seite, Feld liegt in x/z (−0,45 … 0,45).
##
## gdpd: Was gezeigt wird, hängt an der ART (kind, Spec GDPD_REGELN.md §1), nicht mehr an der Stufe.
##   0 Erde, 1 Wiese, 2 Wald, 3 Acker, 4 Großer Wald, 5 Tiere, 6 Hütte, 7 Haus, 8 Dorf, 9 Stadt,
##   10 Kirche★, 11 Großstadt, 12 Industrie★, 13 Metropole★, 14 Paradies★   (★ = fertig)
## Erwartet von FieldData: id, kind (oder ersatzweise das alte stage), fresh, burning.
## Öffentliche Schnittstelle (für World/UI):
##   refresh(f) · set_kind(kind, fresh, burning) · set_polluted(on) · set_wish(icon, left)
##   wish_anchor_world_pos() · wish_visible() · war_fx() · strike_fx() · wither_fx() · wish_fx()
##   plus wie bisher: set_badge, set_preview, set_hint, set_target, set_highlight, set_danger,
##   nudge, quake, flood, burn, vanish, burst.

const TILE := 0.9
const TILE_H := 0.09
const TOP := 0.09
const CONTENT_SCALE := 1.4

enum { K_EMPTY, K_MEADOW, K_FOREST, K_FIELD, K_BIGFOREST, K_ANIMALS, K_HUT, K_HOUSE, K_VILLAGE, K_TOWN,
	K_CHURCH, K_BIGCITY, K_INDUSTRY, K_METROPOLIS, K_PARADISE }
const KIND_COUNT := 15

## Tabelle je Art (Index = kind id). Schlüssel und Symbole wie in der Spec.
const KIND_KEY := ["empty", "meadow", "forest", "field", "bigforest", "animals", "hut", "house", "village", "town",
	"church", "bigcity", "industry", "metropolis", "paradise"]
const KIND_ICON := ["empty", "meadow", "smallforest", "field", "nature", "animals", "hut", "house", "village", "town",
	"church", "bigcity", "industry", "metropolis", "paradise"]
const KIND_TILE := ["#a5805c", "#c3e07a", "#4f9a46", "#e4b850", "#24552d", "#7cc56e", "#d9c08a", "#ebc97f", "#e6b468",
	"#d4cdc2", "#c9b5f0", "#bdb6ad", "#7f7c7a", "#9aa0ab", "#48c49a"]
const FINISHED_KINDS := [K_CHURCH, K_INDUSTRY, K_METROPOLIS, K_PARADISE]
const NATURE_KINDS := [K_MEADOW, K_FOREST, K_BIGFOREST, K_ANIMALS, K_PARADISE]
## Ersatz, solange FieldData noch das alte stage (0..9) hat: Stufe -> Art.
const LEGACY_KIND := [K_EMPTY, K_MEADOW, K_FOREST, K_BIGFOREST, K_HUT, K_HOUSE, K_VILLAGE, K_TOWN, K_BIGCITY, K_METROPOLIS]

const WATER := Color("#36aef0")
const ROOF := Color("#e5574a")
const WITHER_GREENS := [Color("#8a7f5c"), Color("#7b6a4c"), Color("#958a6c")]
const POLLUTED_TILE := Color("#6c6a66")
const SMOKE_C := Color(0.86, 0.86, 0.88, 0.85)
const SMOKE_DARK := Color(0.42, 0.41, 0.42, 0.88)

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
var _target: MeshInstance3D      # Ziel eines Bonus: Ring um das Feld (Regen blau, Blitz gelb)
var _target_top: MeshInstance3D
var _target_mat: StandardMaterial3D
var _target_top_mat: StandardMaterial3D
var _target_on := false
var _kind := -1
var _fresh := 0
var _spin: Array = []            # drehende Teile (Heiligenschein, Funkeln)
var _polluted := false
var _smog: Node3D                # Dunst über dem Feld bei Smog
var _smog_puffs: Array = []
var _star: MeshInstance3D        # kleiner goldener Stern: fertiges Feld
var _wish: Node3D                # Wunsch-Blase (reitet mit dem Feld mit)
var _wish_bubble: Sprite3D
var _wish_icon: Sprite3D
var _wish_left: Label3D
var _wish_shown := false


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


## Ziel eines Bonus: weicher, pulsierender Ring in der Bonusfarbe (hier kann man gießen / blitzen).
func set_target(on: bool, color: Color = Color("#3B8EEA")) -> void:
	if on and _target == null:
		_target_mat = Models.unshaded(Color(color, 0.8)).duplicate() as StandardMaterial3D
		_target = Models.rbox(self, Vector3(TILE + 0.1, 0.026, TILE + 0.1), 0.05, Color.WHITE, Vector3(0, 0.012, 0), Vector3.ZERO, _target_mat)
		_target_top_mat = Models.unshaded(Color(color, 0.3)).duplicate() as StandardMaterial3D
		_target_top = Models.rbox(self, Vector3(TILE - 0.03, 0.012, TILE - 0.03), 0.03, Color.WHITE, Vector3(0, TOP + 0.005, 0), Vector3.ZERO, _target_top_mat)
	_target_on = on
	if _target == null:
		return
	if on:
		_target_mat.albedo_color = Color(color, 0.8)
		_target_top_mat.albedo_color = Color(color, 0.45)
	_target.visible = on
	_target_top.visible = on


## Kurz wackeln (z. B. hier geht der gewählte Bonus nicht).
func nudge() -> void:
	var tw := create_tween()
	var base := Vector3(0, TOP, 0)
	var side := Vector3(0.05, 0.0, 0.0)
	tw.tween_property(_content, "position", base + side, 0.05)
	tw.tween_property(_content, "position", base - side, 0.08)
	tw.tween_property(_content, "position", base + side * 0.5, 0.07)
	tw.tween_property(_content, "position", base, 0.06)


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




# =============================================================================
# Art und Aufbau
# =============================================================================

## Art eines Felds. Bevorzugt FieldData.kind; ohne kind gilt das alte stage (über LEGACY_KIND).
static func kind_of(f: FieldData) -> int:
	var k: Variant = f.get("kind")
	if k != null:
		return int(k)
	var s: Variant = f.get("stage")
	if s == null:
		return K_EMPTY
	return int(LEGACY_KIND[clampi(int(s), 0, LEGACY_KIND.size() - 1)])


static func is_finished_kind(kind: int) -> bool:
	return FINISHED_KINDS.has(kind)


static func kind_tile_color(kind: int) -> Color:
	return Color(KIND_TILE[clampi(kind, 0, KIND_COUNT - 1)])


static func kind_icon(kind: int) -> String:
	return KIND_ICON[clampi(kind, 0, KIND_COUNT - 1)]


func refresh(f: FieldData) -> void:
	var pol: Variant = f.get("polluted")
	if pol != null:
		set_polluted(bool(pol))
	set_kind(kind_of(f), f.fresh, f.burning)


## Zeigt eine Art direkt (auch ohne FieldData, z. B. Tests, Vorschau, Tour).
## fresh > 0: frisch verwüstet – Natur sieht verwelkt aus und raucht, Erde ist verbrannt.
func set_kind(kind: int, fresh: int = 0, burning: bool = false) -> void:
	kind = clampi(kind, 0, KIND_COUNT - 1)
	var key := "%d|%d|%d" % [kind, mini(fresh, 1), 1 if burning else 0]
	if key == _shown:
		return
	var first := _shown == ""
	_shown = key
	_kind = kind
	_fresh = fresh
	_apply_tile_color()
	for c in _content.get_children():
		c.queue_free()
	_bobbers.clear()
	_smoke.clear()
	_spin.clear()
	_build_content(kind, fresh)
	if burning:
		_add_flames()
	_set_star(is_finished_kind(kind))
	_content.position = Vector3(0, TOP, 0)
	_content.rotation = Vector3.ZERO
	if first:
		_content.scale = Vector3.ONE * CONTENT_SCALE
	else:
		_content.scale = Vector3(0.6, 0.3, 0.6) * CONTENT_SCALE
		var tw := create_tween()
		tw.tween_property(_content, "scale", Vector3.ONE * CONTENT_SCALE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func get_kind() -> int:
	return _kind


func _apply_tile_color() -> void:
	if _kind < 0:
		return
	var c := kind_tile_color(_kind)
	if _fresh > 0 and NATURE_KINDS.has(_kind):
		c = c.lerp(Color("#9b8a5c"), 0.45)
	if _polluted:
		c = c.lerp(POLLUTED_TILE, 0.45)
	_tile.material_override = Models.mat(c, 0.7)


## Kleiner goldener Stern in der Kachelecke: dieses Feld ist fertig.
func _set_star(on: bool) -> void:
	if on and _star == null:
		_star = Models.add_mesh(self, Models.star_mesh(0.075, 0.03), Models.mat(Color("#f2a93b"), 0.35, 0.6, 0.2),
			Vector3(0.34, TOP + 0.022, 0.34))
		_star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _star != null:
		_star.visible = on


# =============================================================================
# Smog (Verschmutzung): grauer Dunst und graue Kachel, bis es wieder sauber ist
# =============================================================================

func set_polluted(on: bool) -> void:
	if on == _polluted:
		return
	_polluted = on
	if on and _smog == null:
		_smog = Node3D.new()
		_smog.position = Vector3(0, TOP, 0)
		add_child(_smog)
		var haze := Models.rbox(_smog, Vector3(TILE - 0.04, 0.3, TILE - 0.04), 0.08, Color.WHITE, Vector3(0, 0.15, 0), Vector3.ZERO,
			Models.unshaded(Color(0.4, 0.39, 0.37, 0.26)))
		haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for k in 3:
			var puff := Node3D.new()
			puff.position = Vector3(-0.22 + k * 0.22, 0.3 + 0.04 * (k % 2), -0.12 + 0.12 * k)
			puff.set_meta("base", puff.position)
			_smog.add_child(puff)
			var s1 := Models.sphere(puff, 0.09, Color.WHITE, Vector3.ZERO, Models.mat(Color(0.5, 0.49, 0.48, 0.55), 0.9), 0.6)
			var s2 := Models.sphere(puff, 0.065, Color.WHITE, Vector3(0.08, 0.01, 0.02), Models.mat(Color(0.5, 0.49, 0.48, 0.55), 0.9), 0.6)
			s1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			s2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_smog_puffs.append(puff)
	if _smog != null:
		_smog.visible = on
	if _kind == K_INDUSTRY:
		# Schlote qualmen bei Smog dunkel
		for sm in _smoke:
			var puff: Node3D = sm
			if is_instance_valid(puff) and puff.get_child_count() > 0:
				(puff.get_child(0) as MeshInstance3D).material_override = Models.mat(SMOKE_DARK if on else SMOKE_C, 0.9)
	_apply_tile_color()


func is_polluted() -> bool:
	return _polluted


# =============================================================================
# Wunsch-Blase: hängt an diesem Feld und dreht sich mit dem Würfel mit
# =============================================================================

## icon_name: Symbol des Wunschs ("smallforest", "paw", "field", "rain"); "" blendet aus.
## left: verbleibende Drehungen (kleiner Ring rechts oben), < 0 ohne Zahl.
func set_wish(icon_name: String, left: int = -1) -> void:
	if icon_name == "":
		_wish_shown = false
		if _wish != null:
			_wish.visible = false
		return
	if _wish == null:
		_wish = Node3D.new()
		_wish.position = Vector3(0, 0.82, 0)
		add_child(_wish)
		_wish_bubble = _sprite("wish_bubble", 0.0056, 5)
		_wish.add_child(_wish_bubble)
		_wish_icon = _sprite("paw", 0.0031, 6)
		_wish_icon.offset = Vector2(0, 11)
		_wish.add_child(_wish_icon)
		var ring := _sprite("wish_count", 0.0024, 7)
		ring.offset = Vector2(78, 70)
		ring.name = "Ring"
		_wish.add_child(ring)
		_wish_left = Label3D.new()
		_wish_left.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_wish_left.font = Style.bold()
		_wish_left.font_size = 40
		_wish_left.pixel_size = 0.0024
		_wish_left.outline_size = 0
		_wish_left.modulate = Color("#1F2430")
		_wish_left.no_depth_test = true
		_wish_left.render_priority = 8
		_wish_left.offset = Vector2(78, 70)
		_wish.add_child(_wish_left)
		var pop := _wish.create_tween()
		_wish.scale = Vector3.ONE * 0.1
		pop.tween_property(_wish, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_wish_icon.texture = Style.icon(icon_name)
	_wish_left.text = str(left) if left >= 0 else ""
	(_wish.get_node("Ring") as Sprite3D).visible = left >= 0
	_wish_shown = true
	_wish.visible = true


## Weltposition der Blase (für 2D-Overlays, Long-Press, Ziel-Pfeile).
func wish_anchor_world_pos() -> Vector3:
	return global_transform * Vector3(0, 0.82, 0)


## true, wenn das Feld zur Kamera zeigt (die Blase ist dann sichtbar).
func wish_visible() -> bool:
	return _wish_shown and _wish != null and _wish.visible


func _sprite(icon_name: String, px: float, prio: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = Style.icon(icon_name)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.pixel_size = px
	s.no_depth_test = true
	s.render_priority = prio
	return s


func _facing_camera() -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return 1.0
	return world_normal().dot((cam.global_position - global_position).normalized())


# =============================================================================
# Effekte: Krieg, Gewitter (Strafe), Welken, erfüllter Wunsch
# =============================================================================

## Krieg: Schwerter springen auf, rotes Blinken, das Feld bebt und stürzt ein, danach Rauch und Glut.
func war_fx(dur: float = 1.4) -> void:
	var fx := Node3D.new()
	add_child(fx)
	var sw := _sprite("swords", 0.0055, 6)
	sw.position = Vector3(0, 0.78, 0)
	sw.scale = Vector3.ONE * 0.05
	fx.add_child(sw)
	var tw := sw.create_tween()
	tw.tween_property(sw, "scale", Vector3.ONE * 1.25, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sw, "scale", Vector3.ONE, 0.12)
	for i in 4:
		tw.tween_property(sw, "offset", Vector2(7.0 if i % 2 == 0 else -7.0, 0), 0.06)
	tw.tween_property(sw, "offset", Vector2.ZERO, 0.05)
	tw.tween_interval(dur * 0.45)
	tw.tween_property(sw, "modulate:a", 0.0, 0.35)
	var flash := Models.rbox(fx, Vector3(TILE - 0.03, 0.014, TILE - 0.03), 0.03, Color.WHITE, Vector3(0, TOP + 0.01, 0), Vector3.ZERO,
		Models.unshaded(Color(0.92, 0.16, 0.1, 0.5)))
	flash.visible = false
	var fl := flash.create_tween()
	for i in 3:
		fl.tween_callback(flash.set_visible.bind(true))
		fl.tween_interval(0.12)
		fl.tween_callback(flash.set_visible.bind(false))
		fl.tween_interval(0.1)
	quake(dur * 0.45)
	var crumble := create_tween()
	crumble.tween_interval(dur * 0.3)
	crumble.tween_property(_content, "scale", Vector3(CONTENT_SCALE * 1.08, CONTENT_SCALE * 0.3, CONTENT_SCALE * 1.08), 0.25).set_ease(Tween.EASE_IN)
	crumble.tween_interval(dur * 0.25)
	crumble.tween_property(_content, "scale", Vector3.ONE * CONTENT_SCALE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Rauch und Glut bleiben noch kurz
	var ember := Node3D.new()
	ember.position = Vector3(0, TOP, 0)
	fx.add_child(ember)
	for k in 3:
		var p := Node3D.new()
		p.position = Vector3(-0.2 + k * 0.2, 0.08, 0.1 - k * 0.08)
		ember.add_child(p)
		Models.sphere(p, 0.08, Color.WHITE, Vector3.ZERO, Models.mat(SMOKE_DARK, 0.9)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.scale = Vector3.ONE * 0.1
		var pt := p.create_tween()
		pt.tween_interval(dur * 0.35 + k * 0.1)
		pt.tween_property(p, "scale", Vector3.ONE * (1.0 + 0.2 * k), 0.5).set_ease(Tween.EASE_OUT)
		pt.parallel().tween_property(p, "position:y", 0.35 + 0.05 * k, 1.6)
	for k in 2:
		var f := Models.flame(ember, Vector3(-0.12 + k * 0.24, 0.0, -0.05 + k * 0.1), 1.4)
		f.scale = Vector3.ONE * 0.05
		var ft := f.create_tween()
		ft.tween_interval(dur * 0.3)
		ft.tween_property(f, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ft.tween_property(f, "scale", Vector3(0.8, 1.2, 0.8), 0.3)
		ft.tween_property(f, "scale", Vector3.ONE * 0.6, 0.3)
	var done := fx.create_tween()
	done.tween_interval(dur + 1.0)
	done.tween_property(ember, "scale", Vector3.ONE * 0.01, 0.6).set_ease(Tween.EASE_IN)
	done.tween_callback(fx.queue_free)


## Gewitter (Strafe): ein Blitz schlägt ins Feld, es raucht.
func strike_fx(dur: float = 0.8) -> void:
	var fx := Node3D.new()
	fx.position = Vector3(0, TOP, 0)
	add_child(fx)
	var b := Models.bolt(fx, 2.6)
	var tw := b.create_tween()
	for i in 3:
		tw.tween_callback(b.set_visible.bind(true))
		tw.tween_interval(0.07 + 0.03 * i)
		tw.tween_callback(b.set_visible.bind(false))
		tw.tween_interval(0.05)
	tw.tween_callback(b.queue_free)
	burst(Color("#ffe066"))
	for k in 2:
		var p := Node3D.new()
		p.position = Vector3(-0.08 + k * 0.16, 0.06, 0.04 - k * 0.08)
		fx.add_child(p)
		Models.sphere(p, 0.07, Color.WHITE, Vector3.ZERO, Models.mat(SMOKE_DARK, 0.9)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.scale = Vector3.ONE * 0.1
		var pt := p.create_tween()
		pt.tween_interval(0.2)
		pt.tween_property(p, "scale", Vector3.ONE * 1.2, 0.4).set_ease(Tween.EASE_OUT)
		pt.parallel().tween_property(p, "position:y", 0.3, dur + 0.6)
	var done := fx.create_tween()
	done.tween_interval(dur + 0.6)
	done.tween_property(fx, "scale", Vector3.ONE * 0.01, 0.4)
	done.tween_callback(fx.queue_free)


## Welken (Smog): braune Blätter fallen, eine Rauchwolke.
func wither_fx(dur: float = 1.2) -> void:
	var fx := Node3D.new()
	fx.position = Vector3(0, TOP, 0)
	add_child(fx)
	var rng := _rng()
	var cols := [Color("#c98a3b"), Color("#a6752f"), Color("#d9a441")]
	for k in 7:
		var leaf := Models.box(fx, Vector3(0.05, 0.008, 0.035), cols[k % 3],
			Vector3(rng.randf_range(-0.28, 0.28), rng.randf_range(0.35, 0.5), rng.randf_range(-0.28, 0.28)),
			Vector3(rng.randf_range(-40, 40), rng.randf_range(0, 360), rng.randf_range(-40, 40)))
		leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var lt := leaf.create_tween()
		lt.tween_interval(rng.randf_range(0.0, 0.3))
		lt.tween_property(leaf, "position:y", 0.02, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		lt.parallel().tween_property(leaf, "rotation:y", leaf.rotation.y + 3.0, dur)
	var done := fx.create_tween()
	done.tween_interval(dur + 0.7)
	done.tween_property(fx, "scale", Vector3(1, 0.01, 1), 0.3)
	done.tween_callback(fx.queue_free)


## Erfüllter Wunsch: Herzen steigen auf, rosa Ring.
func wish_fx() -> void:
	burst(Color("#ff8fb1"))
	for k in 4:
		var h := _sprite("heart", 0.0028, 6)
		h.position = Vector3(-0.18 + k * 0.12, 0.35, 0)
		h.scale = Vector3.ONE * 0.2
		add_child(h)
		var tw := h.create_tween()
		tw.tween_interval(k * 0.08)
		tw.tween_property(h, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(h, "position:y", 0.95 + 0.06 * (k % 2), 0.9).set_ease(Tween.EASE_OUT)
		tw.tween_property(h, "modulate:a", 0.0, 0.3)
		tw.tween_callback(h.queue_free)


func _process(delta: float) -> void:
	_time += delta
	if _badge.visible:
		var k := 0.5 + 0.5 * sin(_time * 4.0 + float(field_id))
		_badge.position.y = 0.55 + k * 0.08
		_badge.scale = Vector3.ONE * (0.9 + 0.15 * k)
	if _hint_on:
		_hint_mat.albedo_color.a = 0.1 + 0.5 * (0.5 + 0.5 * sin(_time * 3.5))
	if _target_on and _target_mat != null:
		var pk := 0.5 + 0.5 * sin(_time * 3.0)
		_target_mat.albedo_color.a = 0.45 + 0.45 * pk
		_target_top_mat.albedo_color.a = 0.28 + 0.3 * pk      # deutlich: das sind die Felder, die gerade gehen
	for i in _bobbers.size():
		var b: Node3D = _bobbers[i]
		if is_instance_valid(b):
			b.position.y = absf(sin(_time * 2.6 + i * 1.7)) * 0.01
	for i in _smoke.size():
		var sm: Node3D = _smoke[i]
		if is_instance_valid(sm):
			var ph: float = sm.get_meta("phase", i * 0.37)
			var t: float = fmod(_time * 0.5 + ph, 1.0)
			var by: float = sm.get_meta("base_y", 0.0)
			var rise: float = sm.get_meta("rise", 0.12)
			var grow: float = 0.6 + t * 1.2
			if t > 0.8:
				grow *= 1.0 - (t - 0.8) * 4.0      # oben verpufft der Rauch, statt hart zu springen
			sm.scale = Vector3.ONE * maxf(grow, 0.02)
			sm.position.y = by + t * rise
			var bx: float = sm.get_meta("base_x", 0.0)
			sm.position.x = bx + t * 0.04
	for i in _spin.size():
		var sp: Node3D = _spin[i]
		if is_instance_valid(sp):
			sp.rotation.y += delta * 0.9
			sp.scale = Vector3.ONE * (1.0 + 0.08 * sin(_time * 2.4 + i))
	if _polluted:
		for i in _smog_puffs.size():
			var pf: Node3D = _smog_puffs[i]
			var base: Vector3 = pf.get_meta("base")
			pf.position = base + Vector3(sin(_time * 0.35 + i * 2.1) * 0.08, sin(_time * 0.6 + i) * 0.02, cos(_time * 0.3 + i) * 0.05)
	if _wish_shown and _wish != null:
		var face := _facing_camera()
		_wish.visible = face > 0.15
		_wish.position.y = 0.82 + 0.04 * sin(_time * 2.2 + float(field_id))


# =============================================================================
# Inhalt bauen (Koordinaten im Inhalt: etwa −0,3 … 0,3)
# =============================================================================

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = field_id * 7919 + 17
	return rng


func _people(count: int, around: Vector3, radius: float, color: Color = Color("#3f86e8")) -> void:
	for k in count:
		var a: float = TAU * float(k) / maxf(1.0, float(count)) + 0.5
		var holder := Node3D.new()
		_content.add_child(holder)
		Models.person(holder, around + Vector3(cos(a) * radius, 0, sin(a) * radius * 0.6), color)
		_bobbers.append(holder)


func _animal(kind: String, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	_content.add_child(holder)
	match kind:
		"deer":
			Models.deer(holder, pos, rng.randf_range(0, 360))
		"sheep":
			Models.sheep(holder, pos, rng.randf_range(0, 360))
		_:
			Models.animal(holder, pos, kind, rng.randf_range(0, 360))
	_bobbers.append(holder)


func _puff(pos: Vector3, r: float, c: Color, rise: float = 0.12, phase: float = -1.0) -> void:
	var puff := Node3D.new()
	puff.position = pos
	_content.add_child(puff)
	Models.sphere(puff, r, Color.WHITE, Vector3.ZERO, Models.mat(c, 0.9)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puff.set_meta("base_y", pos.y)
	puff.set_meta("base_x", pos.x)
	puff.set_meta("rise", rise)
	if phase >= 0.0:
		puff.set_meta("phase", phase)
	_smoke.append(puff)


## Ein paar braune Blätter am Boden und ein Baumstumpf (verwelkter Wald).
func _fallen_leaves(rng: RandomNumberGenerator) -> void:
	var cols := [Color("#c98a3b"), Color("#a6752f"), Color("#d9a441")]
	for k in 6:
		Models.box(_content, Vector3(0.04, 0.006, 0.028), cols[k % 3],
			Vector3(rng.randf_range(-0.26, 0.26), 0.004, rng.randf_range(-0.26, 0.26)), Vector3(0, rng.randf_range(0, 180), 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Models.cyl(_content, 0.022, 0.026, 0.035, Models.WOOD, Vector3(0.02, 0, 0.02), 8)
	Models.cyl(_content, 0.02, 0.02, 0.004, Color("#e8c99a"), Vector3(0.02, 0.035, 0.02), 8)


func _build_content(kind: int, fresh: int) -> void:
	var rng := _rng()
	var wither := fresh > 0 and NATURE_KINDS.has(kind)
	var greens: Array = WITHER_GREENS if wither else [Color("#4fa449"), Color("#5cb357"), Color("#3f9443")]
	match kind:
		K_EMPTY:
			# Erde: ein paar Steine, ein kleiner Keim, frisch verwüstet raucht es
			for k in 3:
				var a: float = rng.randf() * TAU
				Models.sphere(_content, 0.025, Color("#7d6450"), Vector3(cos(a) * 0.2, 0.012, sin(a) * 0.2), null, 0.6)
			if fresh > 0:
				Models.rbox(_content, Vector3(0.36, 0.012, 0.36), 0.13, Color("#4b3a2e"), Vector3.ZERO)
				_puff(Vector3(0, 0.06, 0), 0.05, Color(0.45, 0.42, 0.42, 0.7))
			else:
				Models.cone(_content, 0.02, 0.05, Color("#86c95a"), Vector3(0.05, 0, -0.04), 5)
				Models.cone(_content, 0.016, 0.04, Color("#86c95a"), Vector3(0.09, 0, -0.01), 5)
		K_MEADOW:
			# Wiese: Grasbüschel und Blumen, keine Bäume
			var grass: Color = WITHER_GREENS[0] if wither else Color("#6fb544")
			Models.grass_patch(_content, field_id % 4, 10, grass)
			Models.grass_patch(_content, 4 + field_id % 3, 6, grass.lightened(0.12))
			var flowers := [Color("#ffffff"), Color("#ff9ec4"), Color("#ffe066"), Color("#b58cff")]
			var n_flowers := 2 if wither else 7
			for k in n_flowers:
				var fp := Vector3(rng.randf_range(-0.26, 0.26), 0.03, rng.randf_range(-0.26, 0.26))
				var fc: Color = Color("#c9a46a") if wither else flowers[k % 4]
				Models.sphere(_content, 0.02, fc, fp).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if wither:
				_puff(Vector3(0.0, 0.08, 0.0), 0.05, Color(0.55, 0.53, 0.5, 0.7))
			else:
				_animal("meadow", Vector3(0.1, 0.0, 0.08), rng)
		K_FOREST:
			# Wald: vier Bäume, deutlich als Wald erkennbar (die Wiese hat keine Bäume)
			Models.tree(_content, Vector3(-0.14, 0, -0.12), 0.95, greens[1])
			Models.pine(_content, Vector3(0.14, 0, -0.1), 0.95, greens[0])
			Models.tree(_content, Vector3(-0.08, 0, 0.15), 0.85, greens[2])
			if wither:
				_fallen_leaves(rng)
				_puff(Vector3(0.1, 0.12, 0.1), 0.05, Color(0.55, 0.53, 0.5, 0.7))
			else:
				Models.pine(_content, Vector3(0.15, 0, 0.13), 0.85, greens[1])
				_animal("meadow", Vector3(0.15, 0, 0.16), rng)
		K_FIELD:
			# Acker: Furchen mit Weizen und Gemüse, Vogelscheuche. Die Reihen liegen je Feld anders herum.
			var holder := Node3D.new()
			holder.rotation.y = PI * 0.5 * float(rng.randi_range(0, 1))
			_content.add_child(holder)
			Models.crop_field(holder, Vector3.ZERO, fresh > 0)
			if fresh > 0:
				_puff(Vector3(0.0, 0.1, 0.0), 0.05, Color(0.55, 0.53, 0.5, 0.7))
		K_BIGFOREST:
			# Großer Wald: dichte, dunkle Bäume, ein Hirsch
			var spots := [Vector3(-0.17, 0, -0.15), Vector3(0.16, 0, -0.18), Vector3(-0.02, 0, 0.0),
				Vector3(0.17, 0, 0.14), Vector3(-0.18, 0, 0.17)]
			for k in spots.size():
				var g: Color = (greens[k % greens.size()] as Color).darkened(0.1 if wither else 0.35)
				if k % 2 == 0:
					Models.tree(_content, spots[k], rng.randf_range(1.05, 1.3), g)
				else:
					Models.pine(_content, spots[k], rng.randf_range(1.05, 1.25), g)
			if wither:
				_fallen_leaves(rng)
				_puff(Vector3(0.05, 0.2, 0.1), 0.06, Color(0.55, 0.53, 0.5, 0.7))
			else:
				_animal("forest", Vector3(0.08, 0, 0.18), rng)
		K_ANIMALS:
			# Tiere: Lichtung mit Hirsch, Schafen und Hase, Bäume am Rand
			Models.grass_patch(_content, field_id % 4, 9, (greens[1] as Color).lightened(0.1))
			Models.tree(_content, Vector3(-0.2, 0, -0.2), 1.0, greens[0])
			Models.pine(_content, Vector3(0.21, 0, -0.2), 1.0, greens[2])
			Models.sphere(_content, 0.05, (greens[2] as Color).darkened(0.1), Vector3(-0.24, 0.03, 0.12), null, 0.75)
			Models.sphere(_content, 0.04, (greens[0] as Color), Vector3(-0.2, 0.025, 0.2), null, 0.75)
			_animal("deer", Vector3(0.02, 0, -0.06), rng)
			_animal("sheep", Vector3(0.14, 0, 0.12), rng)
			_animal("sheep", Vector3(-0.06, 0, 0.16), rng)
			_animal("meadow", Vector3(0.2, 0, -0.02), rng)
			if wither:
				_fallen_leaves(rng)
				_puff(Vector3(0.0, 0.15, 0.0), 0.05, Color(0.55, 0.53, 0.5, 0.7))
		K_HUT:
			# Hütte am Waldrand
			Models.workshop(_content, Vector3(-0.04, 0, -0.06))
			Models.tree(_content, Vector3(0.17, 0, 0.12), 0.8, greens[0])
			Models.pine(_content, Vector3(-0.18, 0, 0.16), 0.7, greens[2])
			_people(1, Vector3(0.05, 0, 0.16), 0.03)
		K_HOUSE:
			# Haus mit Garten
			Models.house(_content, Vector3(-0.04, 0, -0.06), ROOF, 1.35, 0)
			Models.rbox(_content, Vector3(0.18, 0.014, 0.12), 0.03, Color("#8a5a35"), Vector3(0.12, 0.0, 0.15))
			for k in 3:
				Models.sphere(_content, 0.02, Color("#5cb357"), Vector3(0.06 + k * 0.06, 0.02, 0.15))
			Models.tree(_content, Vector3(-0.18, 0, 0.16), 0.7, greens[1])
			_people(1, Vector3(-0.05, 0, 0.17), 0.03)
			if fresh > 0:
				Models.rubble(_content, Vector3(0.14, 0, -0.16))
				_puff(Vector3(0.1, 0.15, -0.1), 0.05, SMOKE_DARK)
		K_VILLAGE:
			# Dorf: mehrere Häuser
			Models.house(_content, Vector3(-0.13, 0, -0.12), ROOF, 1.0, rng.randf_range(-15, 15))
			Models.house(_content, Vector3(0.13, 0, -0.1), ROOF, 0.95, rng.randf_range(-15, 15))
			Models.house(_content, Vector3(-0.1, 0, 0.13), ROOF, 0.9, 90)
			Models.tree(_content, Vector3(0.17, 0, 0.16), 0.7, greens[1])
			_people(2, Vector3(0.04, 0, 0.06), 0.05)
		K_TOWN:
			# Stadt
			Models.rbox(_content, Vector3(0.2, 0.008, 0.2), 0.05, Color("#c9c1b3"), Vector3(0.02, 0.0, 0.08))
			Models.tower(_content, Vector3(-0.14, 0, -0.13), 0.11, 0.26, ROOF)
			Models.house(_content, Vector3(0.02, 0, -0.17), ROOF, 1.15, 0)
			Models.tower(_content, Vector3(0.16, 0, -0.1), 0.1, 0.2, ROOF)
			Models.market(_content, Vector3(0.08, 0, 0.13), ROOF)
			_people(3, Vector3(-0.1, 0, 0.12), 0.06)
		K_CHURCH:
			# Kirche: Turm mit goldenem Kreuz, leuchtende Fenster, Heiligenschein, zwei Gläubige
			var ch := Node3D.new()
			ch.scale = Vector3.ONE * 1.22
			_content.add_child(ch)
			var halo := Models.faith_church(ch, Vector3(0.0, 0, -0.05))
			_spin.append(halo)
			_people(2, Vector3(-0.1, 0, 0.21), 0.06, Models.FAITH)
		K_BIGCITY:
			# Großstadt: viele höhere Häuser
			Models.tower(_content, Vector3(-0.15, 0, -0.14), 0.12, 0.4, ROOF)
			Models.tower(_content, Vector3(0.02, 0, -0.16), 0.11, 0.32, Color("#3f86e8"))
			Models.tower(_content, Vector3(0.17, 0, -0.08), 0.1, 0.28, ROOF)
			Models.tower(_content, Vector3(-0.14, 0, 0.12), 0.1, 0.24, Color("#3f86e8"))
			Models.tower(_content, Vector3(0.12, 0, 0.15), 0.11, 0.34, ROOF)
			_people(2, Vector3(0.0, 0, 0.02), 0.05)
		K_INDUSTRY:
			# Industrie: Halle, zwei Schlote, aus denen ständig Rauch steigt (bei Smog dunkel)
			var tops := Models.industry_plant(_content, Vector3.ZERO, fresh > 0)
			var c := SMOKE_DARK if _polluted else SMOKE_C
			for t in tops.size():
				var tp: Vector3 = tops[t]
				for k in 3:
					_puff(tp, 0.042, c, 0.24, fmod(k / 3.0 + t * 0.17, 1.0))
		K_METROPOLIS:
			# Metropole: Glastürme
			var glass := Models.mat(Color("#8fc9ee"), 0.15, 0.2, 0.3)
			Models.rbox(_content, Vector3(0.12, 0.62, 0.12), 0.015, Color.WHITE, Vector3(-0.02, 0.31, -0.05), Vector3.ZERO, glass)
			Models.cone(_content, 0.03, 0.12, Color("#e5574a"), Vector3(-0.02, 0.62, -0.05), 8)
			Models.tower(_content, Vector3(-0.18, 0, -0.16), 0.1, 0.44, Color("#3f86e8"))
			Models.tower(_content, Vector3(0.16, 0, -0.14), 0.1, 0.5, ROOF)
			Models.rbox(_content, Vector3(0.1, 0.36, 0.1), 0.015, Color.WHITE, Vector3(0.15, 0.18, 0.14), Vector3.ZERO, glass)
			Models.tower(_content, Vector3(-0.16, 0, 0.15), 0.1, 0.3, Color("#3f86e8"))
			_people(2, Vector3(0.0, 0, 0.18), 0.05)
		K_PARADISE:
			_build_paradise(rng, wither)


## Paradies: Blütenbaum, Teich mit Ente, Regenbogen, leuchtende Blumen, Tiere und Funkeln.
func _build_paradise(rng: RandomNumberGenerator, wither: bool) -> void:
	Models.grass_patch(_content, 7, 10, Color("#5fcf6a"), 0.27)
	# Regenbogen hinten
	var bands := [Color("#ff6b6b"), Color("#ffb347"), Color("#ffe066"), Color("#6fd36f"), Color("#5aa9ff")]
	for k in bands.size():
		var r_out := 0.29 - k * 0.022
		var arc := Models.add_mesh(_content, Models.arc_mesh(r_out - 0.022, r_out), Models.glow2s(Color(bands[k], 0.85)), Vector3(0.0, 0.0, -0.25))
		arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Blütenbaum
	var tree := Node3D.new()
	tree.position = Vector3(-0.15, 0, -0.06)
	tree.scale = Vector3.ONE * 0.62
	_content.add_child(tree)
	Models.world_tree(tree, Vector3.ZERO)
	# Teich
	Models.cyl(_content, 0.135, 0.14, 0.012, Color("#e8f6ff"), Vector3(0.11, 0, 0.11), 18)
	Models.cyl(_content, 0.12, 0.12, 0.016, Models.WATER_C, Vector3(0.11, 0, 0.11), 18, Vector3.ZERO, Models.mat(Models.WATER_C, 0.1, 0.35))
	Models.cyl(_content, 0.026, 0.026, 0.004, Color("#4fa449"), Vector3(0.06, 0.016, 0.16), 10)
	_animal("lake", Vector3(0.14, 0.012, 0.09), rng)
	# leuchtende Blumen
	var fc := [Color("#ff8fc7"), Color("#fff07a"), Color("#ffffff"), Color("#c39bff")]
	for k in 6:
		var a := TAU * float(k) / 6.0 + 0.3
		var fp := Vector3(cos(a) * 0.25, 0.02, sin(a) * 0.25)
		if fp.x > 0.0 and fp.z > 0.0:
			fp = Vector3(-fp.z, 0.02, -fp.x * 0.3)
		Models.sphere(_content, 0.018, Color.WHITE, fp, Models.mat(fc[k % 4], 0.4, 1.0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_animal("deer", Vector3(0.12, 0, -0.1), rng)
	_animal("meadow", Vector3(-0.04, 0, 0.18), rng)
	if wither:
		_puff(Vector3(0.0, 0.2, 0.0), 0.05, Color(0.55, 0.53, 0.5, 0.7))
		return
	# Funkeln, das langsam kreist
	var sparkle := Node3D.new()
	sparkle.position = Vector3(0, 0.22, 0)
	_content.add_child(sparkle)
	for k in 4:
		var b := TAU * float(k) / 4.0
		Models.sphere(sparkle, 0.011, Color.WHITE, Vector3(cos(b) * 0.2, 0.04 * float(k % 2), sin(b) * 0.2), Models.mat(Color("#fff6c2"), 0.3, 3.0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin.append(sparkle)
