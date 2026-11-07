class_name FieldView
extends Node3D
## Darstellung eines Felds: Kachel (Boden je Art), Modelle, Leben (Tiere, Menschen), Hervorhebungen, Zustände.
## Lokales Koordinatensystem: y = Normale der Seite, Feld liegt in x/z (−0,45 … 0,45). Inhalt (_content) ist
## um CONTENT_SCALE vergrößert, seine Koordinaten laufen etwa −0,31 … 0,31.
##
## Arten (FieldData.kind): 0 Erde, 1 Wiese, 2 Wald, 3 Acker, 4 Großer Wald, 5 Tiere, 6 Hütte, 7 Haus, 8 Dorf,
##   9 Stadt, 10 Kirche★, 11 Großstadt, 12 Industrie★, 13 Metropole★, 14 Paradies★, 15 Wasser, 16 Stein.
## Teil B (docs/GDPD_GRAFIK.md 9): Modelle aus Models.get_model() (je Variante ein Mesh mit Vertexfarben), je Feld
##   eine Variante und eine Drehung der Anordnung. Jedes Teil (Baum, Haus) wächst einzeln; danach backt der Feld-Baker
##   alle statischen Teile zu einem Mesh je Material (Cache je Art/Variante/Drehung/Zustand).
##   Tiere und Menschen sind Agenten (_agents): grasen, gehen, arbeiten, fliehen vor Feuer, Krieg und Smog
##   (auf dem Feld oder daneben, set_alarm) und kommen zurück, wenn es ruhig ist.
## Öffentliche Schnittstelle (für World/UI):
##   refresh(f) · set_kind(kind, fresh, burning) · set_polluted(on) · set_wish(icon, left) · set_detail(dot)
##   apply_state8(st) (Bedürfnisse, satt, Hunger, Kriegsfront, Blitz-Warnung, Flut-Gefahr) · set_alarm(on)
##   set_crater(on) · wish_anchor_world_pos() · wish_visible() · war_fx() · strike_fx() · wither_fx() · wish_fx()
##   plus: set_badge, set_preview, set_hint, set_target, set_highlight, set_danger, nudge, quake, flood, burn,
##   vanish, burst, pulse_light, set_wet, set_water_edges.

const TILE := 0.9
const TILE_H := 0.09
const TOP := 0.09
const CONTENT_SCALE := 1.4

enum { K_EMPTY, K_MEADOW, K_FOREST, K_FIELD, K_BIGFOREST, K_ANIMALS, K_HUT, K_HOUSE, K_VILLAGE, K_TOWN,
	K_CHURCH, K_BIGCITY, K_INDUSTRY, K_METROPOLIS, K_PARADISE, K_WATER, K_STONE }
const KIND_COUNT := 17

## Tabelle je Art (Index = kind id). Schlüssel und Symbole wie in der Spec.
const KIND_KEY := ["empty", "meadow", "forest", "field", "bigforest", "animals", "hut", "house", "village", "town",
	"church", "bigcity", "industry", "metropolis", "paradise", "water", "stone"]
const KIND_ICON := ["empty", "meadow", "smallforest", "field", "nature", "animals", "hut", "house", "village", "town",
	"church", "bigcity", "industry", "metropolis", "paradise", "water", "stone"]
const KIND_TILE := ["#a5805c", "#c3e07a", "#4f9a46", "#e4b850", "#24552d", "#7cc56e", "#d9c08a", "#ebc97f", "#e6b468",
	"#d4cdc2", "#c9b5f0", "#bdb6ad", "#7f7c7a", "#9aa0ab", "#48c49a", "#5b9fcf", "#8f8a80"]
const FINISHED_KINDS := [K_CHURCH, K_INDUSTRY, K_METROPOLIS, K_PARADISE]
const NATURE_KINDS := [K_MEADOW, K_FOREST, K_BIGFOREST, K_ANIMALS, K_PARADISE]
const PEOPLE_KINDS := [K_HUT, K_HOUSE, K_VILLAGE, K_TOWN, K_BIGCITY, K_METROPOLIS]
## Ersatz, solange FieldData noch das alte stage (0..9) hat: Stufe -> Art.
const LEGACY_KIND := [K_EMPTY, K_MEADOW, K_FOREST, K_BIGFOREST, K_HUT, K_HOUSE, K_VILLAGE, K_TOWN, K_BIGCITY, K_METROPOLIS]
## Arten mit Trampelpfad im Boden-Shader: die Anordnung wird nicht gedreht (der Pfad liegt fest).
const PATH_KINDS := [K_HUT, K_HOUSE, K_VILLAGE]

const WATER := Color("#36aef0")
const POLLUTED_TILE := Color("#6c6a66")
const SMOKE_C := Color(0.86, 0.86, 0.88, 0.85)
const SMOKE_DARK := Color(0.42, 0.41, 0.42, 0.88)
const CHIMNEY_C := Color(0.82, 0.81, 0.8, 0.55)
const EDGE := 0.4                 # Fluchtpunkt außerhalb der Kachel (Inhalts-Koordinaten)
const MAX_UNCACHED_BAKES := 2     # so viele neue Back-Vorgänge je Bild (der Rest wartet ein Bild)
## Agenten: Schlüssel im Zustand und Shader-Parameter (Gehen, Grasen, Bücken).
const AGENT_KEYS := ["w", "g", "b"]
const AGENT_PARAMS := [&"walk", &"graze", &"bend"]
const NEED_BG_PX := 0.0032        # Bedürfnis-Scheiben über Menschen-Feldern (Handy: gut lesbar)
const BAKE_CACHE_MAX := 64        # so viele gebackene Anordnungen bleiben im Speicher (zuletzt benutzt zuerst behalten)

static var _bake_cache: Dictionary = {}
static var _bake_order: Array = []    # Schlüssel, am längsten unbenutzt zuerst (LRU)
static var _bake_frame := -1
static var _bakes_now := 0

var field_id := -1
var _tile: MeshInstance3D
var _content: Node3D
var _preview_label: Label3D
var _sel: MeshInstance3D
var _glow: MeshInstance3D
var _glow_top: MeshInstance3D
var _danger: MeshInstance3D
var _still_rim: MeshInstance3D
var _danger_top: MeshInstance3D
var _hint: MeshInstance3D
var _hint_mat: StandardMaterial3D
var _hint_on := false
var _shown := ""
var _smoke: Array = []
var _time := 0.0
var _labels_on := true
var _badge: Sprite3D             # Abzeichen über dem Feld (z. B. Tropfen: hier lohnt sich Gießen)
var _badge_name := ""
var _target: MeshInstance3D      # Ziel eines Bonus: Ring um das Feld (Regen blau, Blitz gelb)
var _target_top: MeshInstance3D
var _target_mat: ShaderMaterial
var _target_top_mat: ShaderMaterial
var _target_on := false
var _kind := -1
var _fresh := 0
var _burning := false
var _polluted := false
var _smog: Node3D                # Dunst über dem Feld bei Smog
var _smog_puffs: Array = []
var _star: MeshInstance3D        # kleiner goldener Stern: fertiges Feld
var _wish: Node3D                # Wunsch-Blase (reitet mit dem Feld mit)
var _wish_bubble: Sprite3D
var _wish_icon: Sprite3D
var _wish_left: Label3D
var _wish_shown := false
var _ground: ShaderMaterial      # Boden-Material dieses Felds (Look, GDPD_GRAFIK.md 3)
var _water_mat: ShaderMaterial
var _water_mask := Vector4.ONE
var _water_surf: MeshInstance3D
var _pulse_tw: Tween
var _wet_tw: Tween

# Teil B: Anordnung, Baker, Agenten, Sichtbarkeit
var _variant := 0
var _rot := 0
var _wither := false
var _crater := false
var _items: Array = []           # wachsende, später gebackene Teile (Node3D unter _content)
var _obst: Array = []            # Hindernisse Vector3(x, z, r) in Inhalts-Koordinaten
var _free: Array = []            # freie Punkte für Agenten
var _spots: Array = []           # Ziele der Menschen (Türen, Brunnen, Acker)
var _water_pts: Array = []       # Punkte auf dem Wasser (Enten)
var _agents: Array = []
var _bake_at := -1.0
var _detail := 2                 # 2 voll, 1 flach (Agenten ruhen), 0 Rückseite (Inhalt aus)
var _alarm_ext := false          # Gefahr nebenan (World)
var _sad := 0.0                  # Hunger: Menschen grau und langsam
var _flames: Node3D

# Zustände der neuen Tage (apply_state8)
var _st_key := ""
var _needs: Node3D
var _need_icons: Array = []      # [bg Sprite3D, icon Sprite3D, met]
var _need_pulse := false
var _satt_ring: MeshInstance3D
var _front := false
var _front_node: Node3D
var _bolt_node: Node3D
var _bolt_flash: MeshInstance3D
var _flood_node: Node3D
var _supply_mode := 0            # Vorschau beim Drehen: 1 wird satt, -1 verliert die Versorgung, 0 aus
var _supply_ring: MeshInstance3D
var _supply_icon: Sprite3D


func build(f: FieldData) -> void:
	field_id = f.id
	_tile = Models.rbox(self, Vector3(TILE, TILE_H, TILE), 0.012, Color.WHITE, Vector3(0, TILE_H * 0.5, 0))
	_ground = Look.ground_material()
	_tile.material_override = _ground
	_content = Node3D.new()
	_content.position.y = TOP
	_content.scale = Vector3.ONE * CONTENT_SCALE
	add_child(_content)

	# Hinweise als weicher Lichtrand (GDPD_GRAFIK.md 7.3)
	_sel = Models.rbox(self, Vector3(TILE + 0.06, 0.02, TILE + 0.06), 0.04, Color(1, 1, 1, 0.6), Vector3(0, 0.005, 0), Vector3.ZERO,
		Look.rim(Color(1.0, 0.97, 0.9, 0.9), (TILE + 0.06) * 0.5, 0.05, 0.0, 0.3))
	_sel.visible = false
	_glow = Models.rbox(self, Vector3(TILE + 0.08, 0.03, TILE + 0.08), 0.05, Color("#ffd23f"), Vector3(0, 0.01, 0), Vector3.ZERO,
		Look.rim(Color(1.0, 0.78, 0.3, 1.0), (TILE + 0.08) * 0.5, 0.0, 0.0, 0.4))
	_glow.visible = false
	_glow_top = Models.rbox(self, Vector3(TILE - 0.03, 0.014, TILE - 0.03), 0.03, Color.WHITE, Vector3(0, TOP + 0.006, 0), Vector3.ZERO,
		Look.rim(Color(1.0, 0.84, 0.42, 0.9), (TILE - 0.03) * 0.5, 0.14, 0.0, 0.26, true))
	_glow_top.visible = false
	_danger = Models.rbox(self, Vector3(TILE + 0.08, 0.03, TILE + 0.08), 0.05, Color("#e5483c"), Vector3(0, 0.012, 0), Vector3.ZERO,
		Look.rim(Color(1.0, 0.3, 0.2, 1.0), (TILE + 0.08) * 0.5, 0.0, 7.0, 0.4))
	_danger.visible = false
	_danger_top = Models.rbox(self, Vector3(TILE - 0.03, 0.014, TILE - 0.03), 0.03, Color.WHITE, Vector3(0, TOP + 0.008, 0), Vector3.ZERO,
		Look.rim(Color(0.95, 0.3, 0.2, 0.9), (TILE - 0.03) * 0.5, 0.16, 7.0, 0.28, true))
	_danger_top.visible = false
	_hint_mat = Models.unshaded(Color(1.0, 0.85, 0.25, 0.5)).duplicate() as StandardMaterial3D
	_hint = Models.rbox(self, Vector3(TILE - 0.03, 0.012, TILE - 0.03), 0.03, Color.WHITE, Vector3(0, TOP + 0.004, 0), Vector3.ZERO,
		Look.rim(Color(1.0, 0.86, 0.45, 0.9), (TILE - 0.03) * 0.5, 0.1, 3.5, 0.28, true))
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
	if _supply_icon != null:
		_supply_icon.visible = on and _supply_mode != 0
	_update_needs_visible()


## Abzeichen über dem Feld: Symbolname (z. B. "rain") oder "" zum Ausblenden. Hüpft leicht.
func set_badge(icon_name: String) -> void:
	if icon_name == _badge_name:
		return
	_badge_name = icon_name
	if icon_name != "":
		_badge.texture = Style.icon(icon_name)
	_badge.visible = _labels_on and icon_name != ""
	_update_needs_visible()


## Vorschau beim Drehen (neue Tage, GDPD_BALANCE_2.md 4.6): grüner Rand und Pfeil hoch = wird satt,
## roter Rand und Pfeil runter = verliert die Versorgung, 0 = aus.
func set_supply(mode: int) -> void:
	if mode == _supply_mode:
		return
	_supply_mode = mode
	if mode != 0 and _supply_ring == null:
		_supply_ring = Models.rbox(self, Vector3(TILE + 0.1, 0.03, TILE + 0.1), 0.05, Color.WHITE, Vector3(0, 0.016, 0), Vector3.ZERO,
			Look.rim(Color(0.35, 0.9, 0.45, 1.0), (TILE + 0.1) * 0.5, 0.0, 4.0, 0.42))
		_supply_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_supply_icon = _sprite("up", 0.004, 7)
		_supply_icon.position = Vector3(0, 0.98, 0)
		add_child(_supply_icon)
	if _supply_ring == null:
		return
	var c := Color(0.35, 0.92, 0.45, 1.0) if mode > 0 else Color(1.0, 0.32, 0.25, 1.0)
	(_supply_ring.material_override as ShaderMaterial).set_shader_parameter("color", c)
	_supply_icon.texture = Style.icon("up" if mode > 0 else "down")
	_supply_ring.visible = mode != 0
	_supply_icon.visible = mode != 0 and _labels_on
	if mode != 0:
		# kurzer Hüpfer, damit man die Marke beim Drehen sieht
		_supply_icon.scale = Vector3.ONE * 0.4
		var tw := _supply_icon.create_tween()
		tw.tween_property(_supply_icon, "scale", Vector3.ONE * 1.15, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_supply_icon, "scale", Vector3.ONE, 0.1)


func supply_mode() -> int:
	return _supply_mode


## Vorschau über dem Feld (+5). "" blendet aus.
func set_preview(text: String, color: Color) -> void:
	_preview_label.text = text
	_preview_label.outline_modulate = color
	_preview_label.visible = _labels_on and text != ""
	_update_needs_visible()


## Sanftes Pulsieren: Tipp, diese Scheibe zu drehen.
func set_hint(on: bool) -> void:
	_hint_on = on
	_hint.visible = on


## Ziel eines Bonus: weicher, pulsierender Ring in der Bonusfarbe (hier kann man gießen / blitzen).
func set_target(on: bool, color: Color = Color("#3B8EEA")) -> void:
	if on and _target == null:
		_target_mat = Look.rim(Color(color, 1.0), (TILE + 0.1) * 0.5, 0.0, 3.0, 0.4)
		_target = Models.rbox(self, Vector3(TILE + 0.1, 0.026, TILE + 0.1), 0.05, Color.WHITE, Vector3(0, 0.012, 0), Vector3.ZERO, _target_mat)
		_target_top_mat = Look.rim(Color(color, 0.9), (TILE - 0.03) * 0.5, 0.2, 3.0, 0.28, true)
		_target_top = Models.rbox(self, Vector3(TILE - 0.03, 0.012, TILE - 0.03), 0.03, Color.WHITE, Vector3(0, TOP + 0.005, 0), Vector3.ZERO, _target_top_mat)
	_target_on = on
	if _target == null:
		return
	if on:
		var lit := color.lightened(0.15)
		_target_mat.set_shader_parameter("color", Color(lit, 1.0))
		_target_top_mat.set_shader_parameter("color", Color(lit, 0.9))
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


## Neutraler grauer Rand: diese Reihe wächst nicht (still: schon gewachsen, stand schon so, hin und her …).
func set_still(on: bool) -> void:
	if on and _still_rim == null:
		_still_rim = Models.rbox(self, Vector3(TILE - 0.03, 0.014, TILE - 0.03), 0.03, Color.WHITE, Vector3(0, TOP + 0.006, 0), Vector3.ZERO,
			Look.rim(Color(0.82, 0.84, 0.88, 0.7), (TILE - 0.03) * 0.5, 0.1, 0.0, 0.24, true))
		_still_rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _still_rim != null:
		_still_rim.visible = on


func is_still_marked() -> bool:
	return _still_rim != null and _still_rim.visible


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


## Überschwemmung: Wasser steigt über das Feld (Wasser-Shader) und der Inhalt versinkt.
func flood(dur: float = 1.3) -> void:
	var wm := Look.water()
	wm.set_shader_parameter("half_size", TILE * 0.5)
	var water := Models.rbox(self, Vector3(TILE, 0.02, TILE), 0.01, Color.WHITE, Vector3(0, TOP, 0), Vector3.ZERO, wm)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tw := water.create_tween()
	tw.tween_property(water, "scale", Vector3(1.0, 6.0, 1.0), dur * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(water, "position", Vector3(0, TOP + 0.07, 0), dur * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur * 0.3)
	tw.tween_property(water, "scale", Vector3(1.0, 0.3, 1.0), dur * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(water, "position", Vector3(0, TOP - 0.004, 0), dur * 0.3)
	tw.tween_callback(water.queue_free)
	var sink := create_tween()
	sink.tween_interval(dur * 0.3)
	sink.tween_property(_content, "position", Vector3(0, TOP - 0.25, 0), dur * 0.4).set_ease(Tween.EASE_IN)


## Waldbrand: Flammen lodern auf, Rauch steigt, der Inhalt verkohlt und sinkt zusammen.
func burn(dur: float = 1.1) -> void:
	var fire := Node3D.new()
	fire.position = Vector3(0, TOP, 0)
	add_child(fire)
	for i in 5:
		var fl := Models.flame(fire, Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3)), randf_range(1.6, 2.4), 3, randf())
		fl.scale = Vector3.ONE * 0.05
		var tw := fl.create_tween()
		tw.tween_interval(randf_range(0.0, 0.2))
		tw.tween_property(fl, "scale", Vector3.ONE, dur * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(fl, "scale", Vector3(1.2, 1.4, 1.2), dur * 0.2)
		tw.tween_property(fl, "scale", Vector3.ONE * 0.05, dur * 0.3).set_ease(Tween.EASE_IN)
	for k in 3:
		var p := Node3D.new()
		p.position = Vector3(-0.2 + 0.2 * k, 0.15, 0.05 * k)
		fire.add_child(p)
		Look.smoke_puff(p, 0.3, SMOKE_DARK)
		p.scale = Vector3.ONE * 0.2
		var pt := p.create_tween()
		pt.tween_interval(0.15 * k)
		pt.tween_property(p, "scale", Vector3.ONE * 1.3, dur).set_ease(Tween.EASE_OUT)
		pt.parallel().tween_property(p, "position:y", 0.6, dur)
	var dark := create_tween()
	dark.tween_interval(dur * 0.35)
	dark.tween_property(_content, "scale", Vector3(CONTENT_SCALE, 0.05, CONTENT_SCALE), dur * 0.4).set_ease(Tween.EASE_IN)
	var done := create_tween()
	done.tween_interval(dur + 0.2)
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


## Lichtring, der sich über die Kachel ausbreitet, ein warmer Lichtpuls im Boden und ein kurzes Hüpfen.
func burst(color: Color) -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = Look.quad(1.0)
	var m := Look.ring(Color(color.lightened(0.2), 0.95))
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0, TOP + 0.03, 0)
	ring.rotation_degrees = Vector3(-90, 0, 0)
	ring.scale = Vector3.ONE * 1.25
	add_child(ring)
	var tw := create_tween()
	tw.tween_method(_shader_set.bind(m, "progress"), 0.0, 1.0, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(ring.queue_free)
	pulse_light(color.lerp(Color("#ffd9a0"), 0.5), 0.55)
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
## fresh > 0: frisch verwüstet – Natur sieht verwelkt aus, Erde ist verbrannt.
func set_kind(kind: int, fresh: int = 0, burning: bool = false) -> void:
	kind = clampi(kind, 0, KIND_COUNT - 1)
	if kind != K_EMPTY:
		_crater = false
	var key := "%d|%d|%d|%d" % [kind, mini(fresh, 1), 1 if burning else 0, 1 if _crater else 0]
	if key == _shown:
		return
	var first := _shown == ""
	_shown = key
	_kind = kind
	_fresh = fresh
	_burning = burning
	_wither = fresh > 0 and (NATURE_KINDS.has(kind) or kind == K_FIELD or kind == K_EMPTY)
	_variant = posmod(field_id, 4)
	_rot = 0 if PATH_KINDS.has(kind) else posmod(field_id / 4 + kind, 4)
	_apply_tile_color()
	for c in _content.get_children():
		c.queue_free()
	_smoke.clear()
	_items.clear()
	_obst.clear()
	_free.clear()
	_spots.clear()
	_water_pts.clear()
	_agents.clear()
	_flames = null
	_water_mat = null
	_build_content(kind, fresh)
	_make_free_points()
	if burning:
		_add_flames()
	_ground.set_shader_parameter("pulse_c", Color("#ff7a2a") if burning else Color("#ffd9a0"))
	_ground.set_shader_parameter("pulse", 0.4 if burning else 0.0)
	_set_star(is_finished_kind(kind))
	_content.position = Vector3(0, TOP, 0)
	_content.rotation = Vector3.ZERO
	_content.scale = Vector3.ONE * CONTENT_SCALE
	_content.visible = _detail > 0
	if not first:
		_grow_in()
		_bake_at = _time + 0.95
	else:
		_bake_at = _time
	_st_key = ""


## Wachsen (GDPD_GRAFIK.md 6.3): jedes Teil wächst gestaffelt von der Mitte nach außen, mit Stauchen und Federn.
func _grow_in() -> void:
	var parts: Array = []
	for c in _content.get_children():
		if c is Node3D and not (c as Node3D).is_queued_for_deletion():
			parts.append(c)
	for c in parts:
		var n := c as Node3D
		var s0 := n.scale
		var d := Vector2(n.position.x, n.position.z).length()
		var delay := minf(0.03 * floorf(d / 0.06), 0.24)
		n.scale = Vector3(s0.x * 0.05, s0.y * 0.05, s0.z * 0.05)
		var tw := n.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(n, "scale", Vector3(s0.x * 1.08, s0.y * 1.12, s0.z * 1.08), 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "scale", s0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func get_kind() -> int:
	return _kind


func _apply_tile_color() -> void:
	if _kind < 0:
		return
	var scorch := 0.0
	if _fresh > 0 and NATURE_KINDS.has(_kind):
		scorch = 0.55
	elif _fresh > 0 and _kind == K_EMPTY:
		scorch = 0.35
	if _crater and _kind == K_EMPTY:
		scorch = 0.5
	Look.apply_ground(_ground, _kind, scorch, 1.0 if _polluted else 0.0, _rot % 2 if _kind == K_FIELD else 0)


## Warmer Lichtpuls im Boden (Verschmelzen, Wachsen): über Emission und Glühen, keine Lampe.
func pulse_light(color: Color = Color("#ffd9a0"), dur: float = 0.5) -> void:
	if _pulse_tw != null and _pulse_tw.is_valid():
		_pulse_tw.kill()
	_ground.set_shader_parameter("pulse_c", color)
	_pulse_tw = create_tween()
	var p0 := float(_ground.get_shader_parameter("pulse")) if _ground.get_shader_parameter("pulse") != null else 0.0
	var rest := 0.4 if _burning else 0.0
	_pulse_tw.tween_method(_shader_set.bind(_ground, "pulse"), p0, 1.0, dur * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pulse_tw.tween_method(_shader_set.bind(_ground, "pulse"), 1.0, rest, dur * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if _burning:
		_pulse_tw.tween_callback(_ground.set_shader_parameter.bind("pulse_c", Color("#ff7a2a")))


## Nässe (Regen): der Boden wird dunkler und glänzt, dann trocknet er in dry Sekunden. Tiere und Menschen hüpfen.
func set_wet(amount: float, dry: float = 3.0) -> void:
	if _wet_tw != null and _wet_tw.is_valid():
		_wet_tw.kill()
	var w0 := float(_ground.get_shader_parameter("wet")) if _ground.get_shader_parameter("wet") != null else 0.0
	_wet_tw = create_tween()
	_wet_tw.tween_method(_shader_set.bind(_ground, "wet"), w0, amount, 0.35)
	if dry > 0.0:
		_wet_tw.tween_interval(0.6)
		_wet_tw.tween_method(_shader_set.bind(_ground, "wet"), amount, 0.0, dry).set_trans(Tween.TRANS_SINE)
	if amount >= 0.5:
		for a in _agents:
			(a as Dictionary)["hop"] = 1.8


## Tween-Helfer: Shader-Werte (tween_property kennt sie ohne Grafik-Treiber nicht).
static func _shader_set(v: float, m: ShaderMaterial, param: String) -> void:
	m.set_shader_parameter(param, v)


## Wasser: an welchen Seiten Ufer ist (x = -z, y = +x, z = +z, w = -x; 0 = Nachbarwasser, kein Schaum).
## Zu Nachbarwasser hin reicht die Fläche bis an den Rand des Würfelsteins und deckt Sandrand und Fuge zu:
## so fließen benachbarte Wasserfelder zu einem See zusammen statt wie einzelne Fliesen zu wirken.
func set_water_edges(mask: Vector4) -> void:
	var changed := mask != _water_mask
	_water_mask = mask
	if _water_mat != null:
		_water_mat.set_shader_parameter("edge_mask", mask)
		if changed and _kind == K_WATER:
			_water_surface()


const WATER_SHORE := 0.31                        # Ufer: so weit reicht das Wasser (Inhalts-Koordinaten), dahinter Sand
const WATER_OPEN := 0.5 / CONTENT_SCALE + 0.004  # Nachbarwasser: bis an den Rand des Würfelsteins (deckt die Fuge)


func _water_surface() -> void:
	if _water_surf != null and is_instance_valid(_water_surf):
		_water_surf.queue_free()
	# Ausdehnung je Seite (N = -z, O = +x, S = +z, W = -x)
	var en := WATER_SHORE if _water_mask.x > 0.5 else WATER_OPEN
	var ee := WATER_SHORE if _water_mask.y > 0.5 else WATER_OPEN
	var es := WATER_SHORE if _water_mask.z > 0.5 else WATER_OPEN
	var ew := WATER_SHORE if _water_mask.w > 0.5 else WATER_OPEN
	var center := Vector2((ee - ew) * 0.5, (es - en) * 0.5)
	_water_mat.set_shader_parameter("ext", Vector4(en, ee, es, ew))
	_water_mat.set_shader_parameter("center", center)
	_water_surf = Models.rbox(_content, Vector3(ee + ew, 0.006, en + es), 0.01, Color.WHITE, Vector3(center.x, 0.002, center.y),
		Vector3.ZERO, _water_mat)
	_water_surf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Kleiner goldener Stern in der Kachelecke: dieses Feld ist fertig.
func _set_star(on: bool) -> void:
	if on and _star == null:
		_star = Models.add_mesh(self, Models.star_mesh(0.075, 0.03), Models.mat(Color("#f2a93b"), 0.35, 0.6, 0.2),
			Vector3(0.34, TOP + 0.022, 0.34))
		_star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _star != null:
		_star.visible = on


# =============================================================================
# Feld-Baker (GDPD_GRAFIK.md 9.4): alle statischen Teile zu einem Mesh je Material
# =============================================================================

func _bake_key() -> String:
	return "%d|%d|%d|%d|%d" % [_kind, _variant, _rot, 1 if _wither else 0, 1 if _crater else 0]


func _bake() -> void:
	var key := _bake_key()
	var groups: Array = []
	if _bake_cache.has(key):
		groups = _bake_cache[key]
		_bake_order.erase(key)
		_bake_order.append(key)
	else:
		var frame := Engine.get_process_frames()
		if frame != _bake_frame:
			_bake_frame = frame
			_bakes_now = 0
		if _bakes_now >= MAX_UNCACHED_BAKES:
			return
		_bakes_now += 1
		groups = _merge_items()
		_cache_store(key, groups)
	_bake_at = -1.0
	for it in _items:
		if is_instance_valid(it):
			(it as Node).queue_free()
			(it as Node3D).visible = false
	_items.clear()
	for g in groups:
		var gg: Array = g
		var mi := MeshInstance3D.new()
		mi.mesh = gg[0]
		mi.material_override = Models.material(String(gg[1]))
		if _burning and (String(gg[1]) == "leaf" or String(gg[1]) == "grass"):
			mi.material_override = Look.foliage(Color("#4a3322"))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(gg[2]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("baked", true)
		_content.add_child(mi)


## So viele Anordnungen liegen im Back-Cache (Tests: nie mehr als BAKE_CACHE_MAX).
static func bake_cache_size() -> int:
	return _bake_cache.size()


static func bake_cache_has(key: String) -> bool:
	return _bake_cache.has(key)


## Neu gebackene Anordnung merken. Begrenzt: was am längsten keiner benutzt hat, fällt heraus (Felder, die es gerade
## zeigen, behalten ihr Mesh, es wird nur nicht mehr geteilt).
static func _cache_store(key: String, groups: Array) -> void:
	if _bake_cache.has(key):
		_bake_order.erase(key)
	_bake_cache[key] = groups
	_bake_order.append(key)
	while _bake_order.size() > BAKE_CACHE_MAX:
		_bake_cache.erase(_bake_order.pop_front())


## true, wenn die statischen Teile schon zu wenigen Meshes gebacken sind (Tests).
func is_baked() -> bool:
	return _items.is_empty() and _bake_at < 0.0


func _merge_items() -> Array:
	var acc := {}
	var order: Array = []
	var item_no := 0
	for itv in _items:
		if not is_instance_valid(itv):
			continue
		var it: Node3D = itv
		var base: Transform3D = it.get_meta("xf", it.transform)
		# eigene Zufallszahl je Pflanze/Teil (UV2.x, 0,05 … 1): Laub-Shader streut damit Farbe und Wind-Phase stabil
		item_no += 1
		var iseed := 0.05 + 0.95 * fposmod(sin(float(item_no) * 12.9898 + float(field_id) * 78.233) * 43758.5453, 1.0)
		for ch in it.get_children():
			if not (ch is MeshInstance3D):
				continue
			var mi := ch as MeshInstance3D
			var mk := String(mi.get_meta("mk", "solid"))
			var shadow := mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var gk := "%s|%d" % [mk, 1 if shadow else 0]
			if not acc.has(gk):
				acc[gk] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedVector2Array(), PackedVector2Array(),
					PackedInt32Array()]
				order.append([gk, mk, shadow])
			_append_mesh(acc[gk], mi.mesh, base * mi.transform, iseed)
	var out: Array = []
	for o in order:
		var oo: Array = o
		var a: Array = acc[oo[0]]
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = a[0]
		arr[Mesh.ARRAY_NORMAL] = a[1]
		arr[Mesh.ARRAY_COLOR] = a[2]
		arr[Mesh.ARRAY_TEX_UV] = a[3]
		arr[Mesh.ARRAY_TEX_UV2] = a[4]
		arr[Mesh.ARRAY_INDEX] = a[5]
		if (a[0] as PackedVector3Array).is_empty():
			continue
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.append([m, oo[1], oo[2]])
	return out


static func _append_mesh(a: Array, mesh: Mesh, xf: Transform3D, iseed: float = 0.0) -> void:
	var src := Models.arrays_of(mesh)
	if src.is_empty() or src[Mesh.ARRAY_VERTEX] == null:
		return
	var sv: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var sn: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var sc := PackedColorArray()
	if src[Mesh.ARRAY_COLOR] != null:
		sc = src[Mesh.ARRAY_COLOR]
	var su := PackedVector2Array()
	if src[Mesh.ARRAY_TEX_UV] != null:
		su = src[Mesh.ARRAY_TEX_UV]
	var su2 := PackedVector2Array()
	if src[Mesh.ARRAY_TEX_UV2] != null:
		su2 = src[Mesh.ARRAY_TEX_UV2]
	var si := PackedInt32Array()
	if src[Mesh.ARRAY_INDEX] != null:
		si = src[Mesh.ARRAY_INDEX]
	if si.is_empty():
		si.resize(sv.size())
		for i in sv.size():
			si[i] = i
	var has_c := sc.size() == sv.size()
	var has_u := su.size() == sv.size()
	var has_u2 := su2.size() == sv.size()
	var nb := xf.basis.inverse().transposed()
	var vv: PackedVector3Array = a[0]
	var nn: PackedVector3Array = a[1]
	var cc: PackedColorArray = a[2]
	var uu: PackedVector2Array = a[3]
	var uu2: PackedVector2Array = a[4]
	var ii: PackedInt32Array = a[5]
	var white := Color(1, 1, 1, 0)
	# indiziert: jede Ecke einmal, die Dreiecke als Indizes (+ Versatz der schon gesammelten Ecken)
	var base := vv.size()
	for i in sv.size():
		vv.append(xf * sv[i])
		nn.append((nb * sn[i]).normalized())
		cc.append(sc[i] if has_c else white)
		uu.append(su[i] if has_u else Vector2.ZERO)
		uu2.append(su2[i] if has_u2 else Vector2(iseed, 0.0))
	for i in si:
		ii.append(base + i)
	a[0] = vv
	a[1] = nn
	a[2] = cc
	a[3] = uu
	a[4] = uu2
	a[5] = ii


# =============================================================================
# Sichtbarkeit und LOD (GDPD_GRAFIK.md 9.3)
# =============================================================================

## dot = Feld-Normale · Richtung zur Kamera. Rückseiten: Inhalt aus; flach: Agenten ruhen.
func set_detail(dot: float) -> void:
	var lvl := 2 if dot > 0.3 else (1 if dot > -0.22 else 0)
	if lvl == _detail:
		return
	_detail = lvl
	_content.visible = lvl > 0
	if _smog != null:
		_smog.visible = _polluted and lvl > 0
	if _bolt_node != null:
		_bolt_node.visible = lvl > 0 and _bolt_node.has_meta("on")


func get_detail() -> int:
	return _detail


# =============================================================================
# Zustände der neuen Tage (GDPD_BALANCE_2.md 6.2, 7): Bedürfnisse, satt, Hunger, Front, Blitz, Flut
# =============================================================================

## st = GameState.field_state8(f) (leer: aus), dazu "flood_risk" (World). Baut nur neu, wenn sich etwas ändert.
func apply_state8(st: Dictionary) -> void:
	var people := bool(st.get("people", false))
	var met: Array = st.get("met", [])
	var missing: Array = st.get("missing", [])
	var satt := bool(st.get("satt", false))
	var fed := int(st.get("fed", 0))
	var hungry := int(st.get("hungry", 0))
	var shrink_after := int(st.get("shrink_after", 4))
	var front := bool(st.get("front", false))
	var bolt := bool(st.get("bolt", false))
	var flood_risk := bool(st.get("flood_risk", false))
	var key := "%s|%s|%s|%s|%d|%d|%s|%s|%s" % [people, met, missing, satt, fed, hungry, front, bolt, flood_risk]
	if key == _st_key:
		return
	_st_key = key
	_set_needs(people, met, missing, satt, fed, hungry, shrink_after)
	_set_front(front)
	_set_bolt(bolt)
	_set_flood_risk(flood_risk)
	_sad = clampf(float(hungry - 1) / 2.0, 0.0, 1.0) if people and not satt else 0.0
	for a in _agents:
		var ad: Dictionary = a
		if bool(ad["person"]):
			(ad["m"] as ShaderMaterial).set_shader_parameter("tint", _sad)


func _set_needs(people: bool, met: Array, missing: Array, satt: bool, fed: int, hungry: int, shrink_after: int) -> void:
	if _needs != null:
		_needs.queue_free()
		_needs = null
	_need_icons.clear()
	_need_pulse = false
	if _satt_ring != null:
		_satt_ring.visible = false
	if not people:
		return
	var names: Array = []
	for n in met:
		names.append([String(n), true])
	for n in missing:
		names.append([String(n), false])
	if names.is_empty():
		return
	_needs = Node3D.new()
	_needs.position = Vector3(0, 0.6, 0)
	add_child(_needs)
	var cnt := names.size() + (1 if satt and fed > 0 else 0)
	var gap := 92.0
	var x0 := -gap * float(cnt - 1) * 0.5
	for i in names.size():
		var nm: Array = names[i]
		var ok: bool = nm[1]
		# Was fehlt, ist laut (rote Scheibe, helles Zeichen), was da ist, leise (halb durchsichtig); satt: gold
		var bg := _sprite("need_bg", NEED_BG_PX, 5)
		bg.offset = Vector2(x0 + gap * float(i), 0)
		bg.modulate = Color("#ffd75e") if satt else (Color(1, 1, 1, 0.55) if ok else Color("#e5483c"))
		_needs.add_child(bg)
		var ic := _sprite(String(GameState.NEED_ICON.get(nm[0], "info")), NEED_BG_PX / 1.2838, 6)
		ic.offset = Vector2((x0 + gap * float(i)) * 1.2838, 0)
		ic.modulate = Color(0.45, 0.36, 0.18) if satt else (Color(0.5, 0.5, 0.52, 0.75) if ok else Color(1.22, 1.22, 1.22))
		_needs.add_child(ic)
		_need_icons.append([bg, ic, ok])
	if satt and fed > 0:
		var up := _sprite("up", NEED_BG_PX / 1.1875, 6)
		up.offset = Vector2((x0 + gap * float(names.size())) * 1.1875, 0)
		_needs.add_child(up)
	_need_pulse = not satt and hungry >= shrink_after - 1 and hungry > 0
	if satt:
		if _satt_ring == null:
			_satt_ring = Models.rbox(self, Vector3(TILE - 0.03, 0.012, TILE - 0.03), 0.03, Color.WHITE, Vector3(0, TOP + 0.003, 0), Vector3.ZERO,
				Look.rim(Color(1.0, 0.8, 0.35, 0.85), (TILE - 0.03) * 0.5, 0.0, 0.0, 0.16, true))
			_satt_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_satt_ring.visible = true
	_update_needs_visible()


func _update_needs_visible() -> void:
	if _needs == null:
		return
	_needs.visible = _labels_on and _preview_label.text == "" and not (_badge.visible and _badge_name != "")


## Kriegsfront: roter, pulsierender Rand, Rauchsäulen; die Menschen fliehen.
func _set_front(on: bool) -> void:
	_front = on
	if on and _front_node == null:
		_front_node = Node3D.new()
		add_child(_front_node)
		var rim := Models.rbox(_front_node, Vector3(TILE - 0.03, 0.012, TILE - 0.03), 0.03, Color.WHITE, Vector3(0, TOP + 0.004, 0), Vector3.ZERO,
			Look.rim(Color(0.9, 0.22, 0.14, 0.85), (TILE - 0.03) * 0.5, 0.06, 4.0, 0.22, true))
		rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for k in 2:
			var p := Node3D.new()
			p.position = Vector3(-0.22 + 0.44 * k, TOP + 0.25, 0.2 - 0.4 * k)
			p.set_meta("base", p.position)
			_front_node.add_child(p)
			Look.smoke_puff(p, 0.32, Color(0.3, 0.28, 0.27, 0.6))
			Look.smoke_puff(p, 0.22, Color(0.35, 0.32, 0.3, 0.5), Vector3(0.04, 0.16, 0.0))
	if _front_node != null:
		_front_node.visible = on


## Blitz-Warnung: dunkle Gewitterwolke über dem Feld, in der es ab und zu aufleuchtet.
func _set_bolt(on: bool) -> void:
	if on and _bolt_node == null:
		_bolt_node = Node3D.new()
		_bolt_node.position = Vector3(0, 0.62, 0)
		add_child(_bolt_node)
		for k in 5:
			var a := TAU * float(k) / 5.0
			var p := Node3D.new()
			p.position = Vector3(cos(a) * 0.2, 0.04 * float(k % 2), sin(a) * 0.15)
			p.set_meta("base", p.position)
			_bolt_node.add_child(p)
			Look.smoke_puff(p, 0.5 - 0.05 * float(k % 2), Color(0.22, 0.23, 0.28, 0.9))
		Look.smoke_puff(_bolt_node, 0.62, Color(0.17, 0.18, 0.22, 0.92), Vector3(0, 0.03, 0))
		_bolt_flash = MeshInstance3D.new()
		_bolt_flash.mesh = Look.quad(0.55)
		_bolt_flash.material_override = Look.mote(Color(0.85, 0.88, 1.0, 0.9))
		_bolt_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bolt_flash.visible = false
		_bolt_node.add_child(_bolt_flash)
		var icon := _sprite("lightning", 0.0016, 6)
		icon.position = Vector3(0, 0.1, 0)
		_bolt_node.add_child(icon)
	if _bolt_node != null:
		if on:
			_bolt_node.set_meta("on", true)
		elif _bolt_node.has_meta("on"):
			_bolt_node.remove_meta("on")
		_bolt_node.visible = on and _detail > 0


## Flut-Gefahr: dieselbe Sprache wie die Kriegsfront, nur blau: pulsierender blauer Rand, ein durchscheinender
## Wasserspiegel steigt immer wieder über das Feld, dazu das Flut-Zeichen und nasser Boden.
func _set_flood_risk(on: bool) -> void:
	if on and _flood_node == null:
		_flood_node = Node3D.new()
		add_child(_flood_node)
		var rim := Models.rbox(_flood_node, Vector3(TILE - 0.03, 0.012, TILE - 0.03), 0.03, Color.WHITE, Vector3(0, TOP + 0.004, 0), Vector3.ZERO,
			Look.rim(Color(0.25, 0.55, 0.95, 0.85), (TILE - 0.03) * 0.5, 0.06, 4.0, 0.22, true))
		rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var wm := Look.water()
		wm.set_shader_parameter("half_size", 0.44)
		wm.set_shader_parameter("edge_mask", Vector4.ZERO)
		var slab := Models.rbox(_flood_node, Vector3(0.88, 0.02, 0.88), 0.01, Color.WHITE, Vector3(0, -0.04, 0), Vector3.ZERO, wm)
		slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		slab.transparency = 0.35
		var tw := slab.create_tween().set_loops()
		tw.tween_property(slab, "position:y", TOP + 0.01, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(slab, "position:y", -0.04, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var icon := _sprite("flood", 0.0022, 6)
		icon.position = Vector3(0, 0.62, 0)
		_flood_node.add_child(icon)
	if _flood_node != null:
		_flood_node.visible = on
	if on:
		if _wet_tw != null and _wet_tw.is_valid():
			_wet_tw.kill()
		_ground.set_shader_parameter("wet", 0.75)
	elif _flood_node != null and (_wet_tw == null or not _wet_tw.is_valid()):
		_ground.set_shader_parameter("wet", 0.0)


## Gefahr auf dem Feld oder nebenan (Feuer, Krieg, Smog): Tiere und Menschen laufen weg.
func set_alarm(on: bool) -> void:
	_alarm_ext = on


func _alarmed() -> bool:
	return _alarm_ext or _burning or _front or (_polluted and _kind != K_INDUSTRY)


## Meteorkrater auf diesem Feld (bis es etwas anderes wird).
func set_crater(on: bool) -> void:
	if on == _crater:
		return
	_crater = on
	if _kind == K_EMPTY:
		var k := _kind
		_shown = ""
		set_kind(k, _fresh, _burning)


func agent_count() -> int:
	return _agents.size()


## Zustände der Agenten (Tests): idle, graze, walk, work, flee, gone, return.
func agent_states() -> Array:
	var out: Array = []
	for a in _agents:
		out.append(String((a as Dictionary)["st"]))
	return out


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
		for k in 4:
			var puff := Node3D.new()
			puff.position = Vector3(-0.24 + k * 0.16, 0.16 + 0.07 * (k % 2), -0.14 + 0.1 * k)
			puff.set_meta("base", puff.position)
			_smog.add_child(puff)
			Look.smoke_puff(puff, 0.42 + 0.06 * (k % 2), Color(0.47, 0.45, 0.41, 0.62))
			Look.smoke_puff(puff, 0.3, Color(0.55, 0.53, 0.48, 0.5), Vector3(0.1, 0.06, 0.03))
			_smog_puffs.append(puff)
	if _smog != null:
		_smog.visible = on and _detail > 0
	if _kind == K_INDUSTRY:
		for sm in _smoke:
			var puff: Node3D = sm
			if is_instance_valid(puff) and puff.get_child_count() > 0:
				(puff.get_child(0) as MeshInstance3D).material_override = Look.smoke(SMOKE_DARK if on else SMOKE_C)
	_apply_tile_color()


func is_polluted() -> bool:
	return _polluted


# =============================================================================
# Wunsch-Blase: hängt an diesem Feld und dreht sich mit dem Würfel mit
# =============================================================================

const WISH_SCALE := 1.45      # Wunsch-Blase: gut lesbar auf dem Handy


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
		pop.tween_property(_wish, "scale", Vector3.ONE * WISH_SCALE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
		Look.rim(Color(1.0, 0.25, 0.15, 0.9), (TILE - 0.03) * 0.5, 0.25, 0.0, 0.35))
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
	var ember := Node3D.new()
	ember.position = Vector3(0, TOP, 0)
	fx.add_child(ember)
	for k in 3:
		var p := Node3D.new()
		p.position = Vector3(-0.2 + k * 0.2, 0.08, 0.1 - k * 0.08)
		ember.add_child(p)
		Look.smoke_puff(p, 0.24, SMOKE_DARK)
		p.scale = Vector3.ONE * 0.1
		var pt := p.create_tween()
		pt.tween_interval(dur * 0.35 + k * 0.1)
		pt.tween_property(p, "scale", Vector3.ONE * (1.0 + 0.2 * k), 0.5).set_ease(Tween.EASE_OUT)
		pt.parallel().tween_property(p, "position:y", 0.35 + 0.05 * k, 1.6)
	for k in 2:
		var f := Models.flame(ember, Vector3(-0.12 + k * 0.24, 0.0, -0.05 + k * 0.1), 1.9, 3, 0.3 * k)
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
		Look.smoke_puff(p, 0.21, SMOKE_DARK)
		p.scale = Vector3.ONE * 0.1
		var pt := p.create_tween()
		pt.tween_interval(0.2)
		pt.tween_property(p, "scale", Vector3.ONE * 1.2, 0.4).set_ease(Tween.EASE_OUT)
		pt.parallel().tween_property(p, "position:y", 0.3, dur + 0.6)
	var done := fx.create_tween()
	done.tween_interval(dur + 0.6)
	done.tween_property(fx, "scale", Vector3.ONE * 0.01, 0.4)
	done.tween_callback(fx.queue_free)


## Welken (Smog): braune Blätter fallen.
func wither_fx(dur: float = 1.2) -> void:
	var fx := Node3D.new()
	fx.position = Vector3(0, TOP, 0)
	add_child(fx)
	var rng := RandomNumberGenerator.new()
	rng.seed = field_id * 7919 + 17
	var cols := [Color("#8a6a3a"), Color("#6e5530"), Color("#9a7a45")]
	for k in 7:
		var leaf := Models.box(fx, Vector3(0.03, 0.004, 0.022), cols[k % 3],
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


# =============================================================================
# Bild für Bild
# =============================================================================

func _process(delta: float) -> void:
	_time += delta
	if _bake_at >= 0.0 and _time >= _bake_at:
		_bake()
	if _badge.visible:
		var k := 0.5 + 0.5 * sin(_time * 4.0 + float(field_id))
		_badge.position.y = 0.55 + k * 0.08
		_badge.scale = Vector3.ONE * (0.9 + 0.15 * k)
	if _detail > 0:
		for i in _smoke.size():
			var sm: Node3D = _smoke[i]
			if is_instance_valid(sm):
				var ph: float = sm.get_meta("phase", i * 0.37)
				var spd: float = sm.get_meta("speed", 0.5)
				var t: float = fmod(_time * spd + ph, 1.0)
				var by: float = sm.get_meta("base_y", 0.0)
				var rise: float = sm.get_meta("rise", 0.12)
				var grow: float = 0.5 + t * 1.3
				if t > 0.75:
					grow *= 1.0 - (t - 0.75) * 3.6
				sm.scale = Vector3.ONE * maxf(grow, 0.02)
				sm.position.y = by + t * rise
				var bx: float = sm.get_meta("base_x", 0.0)
				sm.position.x = bx + t * t * 0.05
		if _polluted:
			for i in _smog_puffs.size():
				var pf: Node3D = _smog_puffs[i]
				var base: Vector3 = pf.get_meta("base")
				pf.position = base + Vector3(sin(_time * 0.35 + i * 2.1) * 0.08, sin(_time * 0.6 + i) * 0.02, cos(_time * 0.3 + i) * 0.05)
		if _bolt_node != null and _bolt_node.visible:
			for c in _bolt_node.get_children():
				if c is Node3D and (c as Node3D).has_meta("base"):
					var b0: Vector3 = (c as Node3D).get_meta("base")
					(c as Node3D).position = b0 + Vector3(sin(_time * 0.5 + b0.x * 9.0) * 0.03, 0.0, cos(_time * 0.4 + b0.z * 7.0) * 0.02)
			var fl := fmod(_time * 1.3 + float(field_id) * 0.37, 2.2)
			_bolt_flash.visible = fl < 0.08 or (fl > 0.16 and fl < 0.2)
		if _front_node != null and _front_node.visible:
			for c in _front_node.get_children():
				if c is Node3D and (c as Node3D).has_meta("base"):
					var b1: Vector3 = (c as Node3D).get_meta("base")
					(c as Node3D).position = b1 + Vector3(0.0, fmod(_time * 0.05 + b1.x, 0.12), 0.0)
	if _need_pulse and _needs != null and _needs.visible:
		var pk := 1.0 + 0.18 * maxf(0.0, sin(_time * 6.0))
		for ni in _need_icons:
			var arr: Array = ni
			if not bool(arr[2]):
				(arr[0] as Sprite3D).scale = Vector3.ONE * pk
				(arr[1] as Sprite3D).scale = Vector3.ONE * pk
	if _detail == 2 and not _agents.is_empty():
		_update_agents(delta)
	if _wish_shown and _wish != null:
		var face := _facing_camera()
		_wish.visible = face > 0.15
		_wish.position.y = 0.82 + 0.04 * sin(_time * 2.2 + float(field_id))


# =============================================================================
# Agenten (GDPD_GRAFIK.md 9.2): Tiere grasen und gehen, Menschen gehen zu Zielen, arbeiten, plaudern.
# Bei Gefahr laufen alle zum Kachelrand und verschwinden; ist es ruhig, kommen sie zurück.
# =============================================================================

const AGENT_SPEED := {"sheep": 0.022, "cow": 0.018, "deer": 0.035, "hare": 0.05, "duck": 0.015, "person": 0.028}
const AGENT_RATE := {"sheep": 13.0, "cow": 9.0, "deer": 11.0, "hare": 18.0, "duck": 4.0, "person": 11.0}


func _agent(kind: String, variant: int, pos: Vector3, yaw: float = -100.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Models.creature_mesh(kind, variant)
	var h := Models.hash3(Vector3(field_id, _agents.size(), variant))
	var m := Models.creature_material(h * TAU)
	m.set_shader_parameter("rate", float(AGENT_RATE.get(kind, 11.0)))
	mi.material_override = m
	if Look.quality < 2:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation.y = yaw if yaw > -99.0 else h * TAU
	_content.add_child(mi)
	_agents.append({"n": mi, "m": m, "k": kind, "person": kind == "person", "st": "idle", "t": 0.5 + h * 3.0,
		"to": pos, "spd": float(AGENT_SPEED.get(kind, 0.03)) * (0.85 + 0.3 * h), "w": 0.0, "g": 0.0, "b": 0.0,
		"hop": 0.0, "h": h, "sc": 1.0})


## Freie Punkte für Agenten: Raster ohne Hindernisse.
func _make_free_points() -> void:
	for ix in 7:
		for iz in 7:
			var p := Vector3(-0.27 + 0.09 * float(ix), 0.0, -0.27 + 0.09 * float(iz))
			var ok := true
			for o in _obst:
				var ob: Vector3 = o
				if Vector2(p.x - ob.x, p.z - ob.y).length() < ob.z + 0.02:
					ok = false
					break
			if ok:
				_free.append(p)
	if _free.is_empty():
		_free.append(Vector3(0.0, 0.0, 0.26))


func _pick_free(a: Dictionary) -> Vector3:
	if String(a["k"]) == "duck":
		if _water_pts.is_empty():
			return (a["n"] as Node3D).position
		return _water_pts[randi() % _water_pts.size()]
	if bool(a["person"]) and not _spots.is_empty() and randf() < 0.55:
		var sp: Vector3 = _spots[randi() % _spots.size()]
		return sp + Vector3(randf_range(-0.02, 0.02), 0.0, randf_range(-0.02, 0.02))
	var cur: Vector3 = (a["n"] as Node3D).position
	var best: Vector3 = _free[randi() % _free.size()]
	# Tiere bleiben gern in der Nähe (kurze Wege, ruhige Herde)
	if not bool(a["person"]):
		for _i in 2:
			var c: Vector3 = _free[randi() % _free.size()]
			if c.distance_to(cur) < best.distance_to(cur):
				best = c
	return best + Vector3(randf_range(-0.025, 0.025), 0.0, randf_range(-0.025, 0.025))


func _update_agents(delta: float) -> void:
	var alarm := _alarmed()
	for av in _agents:
		var a: Dictionary = av
		var n: Node3D = a["n"]
		if not is_instance_valid(n):
			continue
		var st := String(a["st"])
		var want_w := 0.0
		var want_g := 0.0
		var want_b := 0.0
		var speed: float = a["spd"] * (1.0 - 0.45 * _sad if bool(a["person"]) else 1.0)
		if alarm and st != "flee" and st != "gone":
			st = "flee"
			var p := n.position
			var to := Vector3(signf(p.x) * EDGE, 0.0, p.z) if absf(p.x) > absf(p.z) else Vector3(p.x, 0.0, signf(p.z) * EDGE)
			if String(a["k"]) == "duck":
				to = p
			a["to"] = to
		match st:
			"idle":
				a["t"] = float(a["t"]) - delta
				if float(a["t"]) <= 0.0:
					var r := randf()
					if bool(a["person"]):
						if r < 0.5:
							st = "walk"
							a["to"] = _pick_free(a)
						elif r < 0.75:
							st = "work"
							a["t"] = randf_range(2.0, 4.5)
						else:
							a["t"] = randf_range(1.0, 3.0)
					elif String(a["k"]) == "duck":
						st = "walk" if r < 0.7 else "graze"
						a["to"] = _pick_free(a)
						a["t"] = randf_range(1.0, 2.5)
					else:
						if r < 0.55:
							st = "graze"
							a["t"] = randf_range(2.0, 5.0)
						else:
							st = "walk"
							a["to"] = _pick_free(a)
			"graze":
				want_g = 1.0
				a["t"] = float(a["t"]) - delta
				if float(a["t"]) <= 0.0:
					st = "idle"
					a["t"] = randf_range(0.6, 2.0)
			"work":
				want_b = 1.0
				a["t"] = float(a["t"]) - delta
				if float(a["t"]) <= 0.0:
					st = "idle"
					a["t"] = randf_range(0.5, 1.5)
			"walk", "return", "flee":
				var to: Vector3 = a["to"]
				var d := to - n.position
				d.y = 0.0
				var dist := d.length()
				var sp := speed * (3.2 if st == "flee" else 1.0)
				if dist < 0.004:
					if st == "flee":
						st = "gone"
						a["t"] = randf_range(1.5, 3.0)
					else:
						st = "idle"
						a["t"] = randf_range(0.8, 3.0)
				else:
					want_w = 1.0 if st != "flee" else 1.6
					var yaw := atan2(-d.z, d.x)
					n.rotation.y = lerp_angle(n.rotation.y, yaw, minf(1.0, delta * 7.0))
					var fwd := Vector3(cos(n.rotation.y), 0.0, -sin(n.rotation.y))
					var step := minf(sp * delta, dist)
					n.position += fwd.lerp(d / dist, 0.5).normalized() * step
					if st == "flee" and n.position.distance_to(to) < 0.08:
						a["sc"] = maxf(0.0, float(a["sc"]) - delta * 2.5)
			"gone":
				a["sc"] = maxf(0.0, float(a["sc"]) - delta * 3.0)
				if not alarm:
					a["t"] = float(a["t"]) - delta
					if float(a["t"]) <= 0.0:
						st = "return"
						a["to"] = _pick_free(a)
						var tp: Vector3 = a["to"]
						n.position = Vector3(signf(tp.x) * EDGE, 0.0, tp.z) if absf(tp.x) > absf(tp.z) else Vector3(tp.x, 0.0, signf(tp.z) * EDGE)
		if st == "return" or (st != "gone" and st != "flee"):
			a["sc"] = minf(1.0, float(a["sc"]) + delta * 2.5)
		a["st"] = st
		var sc: float = a["sc"]
		n.scale = Vector3.ONE * maxf(sc, 0.001)
		n.visible = sc > 0.01
		var m: ShaderMaterial = a["m"]
		var k := minf(1.0, delta * 5.0)
		# Gehen, Grasen, Bücken: nur bei Änderung an den Shader (keine Arrays je Bild)
		for pj in 3:
			var want: float = want_w if pj == 0 else (want_g if pj == 1 else want_b)
			var ak: String = AGENT_KEYS[pj]
			var cur := float(a[ak])
			var nv := lerpf(cur, want, k)
			if absf(nv - cur) > 0.004 or (absf(nv - want) < 0.004 and cur != want):
				if absf(nv - want) < 0.004:
					nv = want
				a[ak] = nv
				m.set_shader_parameter(AGENT_PARAMS[pj], nv)
		var hop := float(a["hop"])
		if hop > 0.0:
			hop = maxf(0.0, hop - delta)
			a["hop"] = hop
			m.set_shader_parameter("hop", 1.0 if hop > 0.2 and not alarm else 0.0)


# =============================================================================
# Inhalt bauen (Koordinaten im Inhalt: etwa −0,31 … 0,31)
# =============================================================================

## Zufall der Anordnung: hängt an Art, Variante und Drehung (nicht am Feld), damit der Baker-Cache greift.
func _lrng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _kind * 7919 + _variant * 131 + _rot * 17 + (3 if _wither else 0) + (5 if _crater else 0)
	return rng


## Drehung der Anordnung um _rot Vierteldrehungen.
func _R(p: Vector3) -> Vector3:
	match _rot:
		1:
			return Vector3(p.z, p.y, -p.x)
		2:
			return Vector3(-p.x, p.y, -p.z)
		3:
			return Vector3(-p.z, p.y, p.x)
	return p


## Ein Teil (Baum, Haus …): eigener Knoten, wächst einzeln, wird danach gebacken.
func _item(model: String, variant: int, pos: Vector3, yaw: float = 0.0, s: float = 1.0, obst_r: float = 0.0,
		abs_pos: bool = false) -> Node3D:
	var it := Node3D.new()
	it.position = pos if abs_pos else _R(pos)
	it.rotation.y = yaw + (0.0 if abs_pos else PI * 0.5 * float(_rot))
	it.scale = Vector3.ONE * s
	_content.add_child(it)
	it.set_meta("xf", it.transform)
	_add_parts(it, Models.get_model(model, variant))
	_items.append(it)
	if obst_r > 0.0:
		_obst.append(Vector3(it.position.x, it.position.z, obst_r * s))
	return it


func _add_parts(it: Node3D, parts: Array) -> void:
	for pv in parts:
		var part: Array = pv
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		var mk := String(part[1])
		mi.material_override = Models.material(mk)
		mi.set_meta("mk", mk)
		if mk == "grass" or mk == "warm" or mk == "faith":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _burning and (mk == "leaf" or mk == "grass"):
			mi.material_override = Look.foliage(Color("#4a3322"))
		it.add_child(mi)


## Gras, Blumen, Kiesel (ein Teil, gebaut nach den Hindernissen; Cache je Anordnung).
func _cover(density: int, flowers: int, dry: bool, pebbles: int = 0, tall: float = 1.0, half: float = 0.31) -> void:
	var rng := _lrng()
	rng.seed = rng.seed + 999
	var key := "%s|%d|%d|%d|%d" % [_bake_key(), density, flowers, pebbles, int(tall * 10.0)]
	var obst: Array = []
	for o in _obst:
		var ob: Vector3 = o
		obst.append(Vector3(ob.x, ob.y, ob.z * 0.8))
	var it := Node3D.new()
	_content.add_child(it)
	it.set_meta("xf", it.transform)
	_add_parts(it, Models.cover(key, rng, obst, density, flowers, dry, pebbles, tall, half))
	_items.append(it)


func _tree(model: String, variant: int, pos: Vector3, rng: RandomNumberGenerator, s: float = 1.0) -> Node3D:
	return _item(model, variant, pos, rng.randf() * TAU, s * rng.randf_range(0.88, 1.12), 0.07)


func _puff(pos: Vector3, r: float, c: Color, rise: float = 0.12, phase: float = -1.0, speed: float = 0.5) -> void:
	var puff := Node3D.new()
	puff.position = pos
	_content.add_child(puff)
	Look.smoke_puff(puff, r * 2.6, c)
	puff.set_meta("base_y", pos.y)
	puff.set_meta("base_x", pos.x)
	puff.set_meta("rise", rise)
	puff.set_meta("speed", speed)
	if phase >= 0.0:
		puff.set_meta("phase", phase)
	_smoke.append(puff)


## Kaminrauch: zwei zarte Flocken über einer Stelle im Teil.
func _chimney(it: Node3D, local: Vector3) -> void:
	var p: Vector3 = (it.get_meta("xf") as Transform3D) * local
	_puff(p, 0.016, CHIMNEY_C, 0.11, Models.hash3(p) * 0.5, 0.3)
	_puff(p, 0.016, CHIMNEY_C, 0.11, Models.hash3(p) * 0.5 + 0.5, 0.3)


func _add_flames() -> void:
	_flames = Node3D.new()
	_content.add_child(_flames)
	var pts: Array = []
	for itv in _items:
		var it: Node3D = itv
		if it.position.length() > 0.001:
			pts.append(it.position)
	if pts.size() < 3:
		for k in 3:
			var a := TAU * float(k) / 3.0 + float(field_id)
			pts.append(Vector3(cos(a) * 0.15, 0.0, sin(a) * 0.15))
	var n := mini(pts.size(), 6)
	for k in n:
		var p: Vector3 = pts[k]
		Models.flame(_flames, p + Vector3(0, 0.005, 0), randf_range(1.6, 2.3), 3, fmod(float(field_id) * 0.13 + k * 0.29, 1.0))
	for k in 3:
		var p2: Vector3 = pts[k % pts.size()]
		_puff(p2 + Vector3(0, 0.2, 0), 0.09, Color(0.2, 0.18, 0.17, 0.72), 0.45, 0.33 * k, 0.35)
	var em := MeshInstance3D.new()
	em.mesh = Look.quad(0.5)
	em.material_override = Look.mote(Color(1.0, 0.45, 0.12, 0.5))
	em.position = Vector3(0, 0.05, 0)
	em.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flames.add_child(em)


func _build_content(kind: int, fresh: int) -> void:
	var rng := _lrng()
	match kind:
		K_EMPTY:
			_b_earth(rng, fresh)
		K_MEADOW:
			_b_meadow(rng)
		K_FOREST:
			_b_forest(rng, false)
		K_BIGFOREST:
			_b_forest(rng, true)
		K_FIELD:
			_b_field(rng)
		K_ANIMALS:
			_b_animals(rng)
		K_HUT:
			_b_hut(rng)
		K_HOUSE:
			_b_house(rng)
		K_VILLAGE:
			_b_village(rng)
		K_TOWN:
			_b_town(rng)
		K_CHURCH:
			_b_church(rng)
		K_BIGCITY:
			_b_bigcity(rng)
		K_INDUSTRY:
			_b_industry(rng)
		K_METROPOLIS:
			_b_metropolis(rng)
		K_PARADISE:
			_b_paradise(rng)
		K_WATER:
			_b_water(rng)
		K_STONE:
			_b_stone(rng)


## Erde: nackter Boden, ein paar Steine und Keime. Frisch verbrannt: Stümpfe, Asche, Rauch. Krater nach Meteor.
func _b_earth(rng: RandomNumberGenerator, fresh: int) -> void:
	if _crater:
		_item("crater", 0, Vector3.ZERO, rng.randf() * TAU, 1.0, 0.27, true)
		for k in 3:
			var em := MeshInstance3D.new()
			em.mesh = Look.quad(0.035 + 0.015 * k)
			em.material_override = Look.mote(Color(1.0, 0.38, 0.08, 0.55))
			em.position = Vector3(-0.04 + 0.04 * k, 0.008, 0.03 - 0.03 * k)
			em.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_content.add_child(em)
		_puff(Vector3(0, 0.03, 0), 0.05, Color(0.35, 0.33, 0.32, 0.6), 0.2)
		_cover(4, 0, true, 10)
		return
	var nrock := 1 + _variant % 3
	for k in nrock:
		_item("rock", k + _variant, Vector3(rng.randf_range(-0.22, 0.22), 0, rng.randf_range(-0.22, 0.22)), rng.randf() * TAU,
			rng.randf_range(0.4, 0.75), 0.04)
	if fresh > 0:
		for k in 2:
			_item("stump", k, Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)), 0.0, 1.0, 0.03)
		_item("log", 1, Vector3(0.1, 0, -0.12), rng.randf() * TAU, 0.9, 0.05)
		_cover(6, 0, true, 14, 0.7)
		_puff(Vector3(0, 0.05, 0), 0.04, Color(0.42, 0.4, 0.4, 0.55), 0.18)
	else:
		_cover(5 + _variant * 2, 0, false, 16, 0.55)


## Wiese: dichtes Gras mit gedeckten Blumen, Büsche am Rand, ein Hase.
func _b_meadow(rng: RandomNumberGenerator) -> void:
	var bushes := 1 + _variant % 2
	for k in bushes:
		var a := rng.randf() * TAU
		_item("bush_dry" if _wither else "bush", k + _variant, Vector3(cos(a) * 0.23, 0, sin(a) * 0.23), rng.randf() * TAU,
			rng.randf_range(0.8, 1.25), 0.05)
	if _variant == 3 and not _wither:
		_item("young", 1, Vector3(0.19, 0, -0.18), rng.randf() * TAU, 1.0, 0.05)
	_cover(130, 4 if _wither else 22, _wither, 3, 1.0)
	if not _wither and _variant % 2 == 0:
		_agent("hare", 0, _R(Vector3(0.05, 0, 0.08)))


## Wald / Großer Wald: gemischte Bäume, Unterholz, Totholz, ein Hirsch.
func _b_forest(rng: RandomNumberGenerator, big: bool) -> void:
	var types := ["oak", "spruce", "beech", "birch", "spruce", "oak", "pine"]
	var spots: Array = []
	if big:
		spots = [Vector3(-0.2, 0, -0.2), Vector3(0.0, 0, -0.22), Vector3(0.2, 0, -0.19), Vector3(-0.21, 0, 0.01),
			Vector3(0.02, 0, -0.01), Vector3(0.21, 0, 0.03), Vector3(-0.18, 0, 0.21), Vector3(0.05, 0, 0.21), Vector3(0.22, 0, 0.22)]
	else:
		spots = [Vector3(-0.16, 0, -0.15), Vector3(0.15, 0, -0.14), Vector3(-0.14, 0, 0.16), Vector3(0.16, 0, 0.15),
			Vector3(0.0, 0, 0.0)]
	for k in spots.size():
		var p: Vector3 = spots[k] + Vector3(rng.randf_range(-0.03, 0.03), 0, rng.randf_range(-0.03, 0.03))
		var model: String = types[(k + _variant) % types.size()]
		if big:
			model = "spruce" if k % 3 != 1 else ("oak" if k % 2 == 0 else "beech")
		if _wither:
			model = "dead" if k % 2 == 0 else "bush_dry"
		var s := rng.randf_range(1.15, 1.4) if big else rng.randf_range(0.85, 1.05)
		if model == "bush_dry":
			s *= 1.4
		_tree(model, k + _variant, p, rng, s)
	if not big:
		_item("log", _variant, Vector3(0.02, 0, 0.2), rng.randf() * TAU, 1.0, 0.04)
		_item("stump", _variant, Vector3(-0.21, 0, 0.0), 0.0, 1.0, 0.025)
		_item("bush_dry" if _wither else "bush", _variant + 1, Vector3(0.22, 0, 0.0), rng.randf() * TAU, 0.9, 0.04)
	_cover(30 if big else 44, 0 if big or _wither else 3, _wither, 5, 0.9)
	if not _wither and (big or _variant % 2 == 0):
		_agent("deer", _variant, _R(Vector3(0.08, 0, 0.07) if big else Vector3(0.06, 0, -0.1)))


## Acker: Dämme mit Pflanzenreihen (Saat, grün oder reif), Zaun, Vogelscheuche oder Karren, ein Bauer.
func _b_field(rng: RandomNumberGenerator) -> void:
	var dir := _rot % 2
	var stage: int = [2, 2, 1, 0][_variant]
	var it := Node3D.new()
	_content.add_child(it)
	it.set_meta("xf", it.transform)
	_add_parts(it, Models.crops("%d|%d|%d" % [stage, dir, 1 if _wither else 0], stage, dir, _wither))
	_items.append(it)
	# Zaun längs der Reihen am Rand
	var side := 1.0 if _rot < 2 else -1.0
	var fp := Vector3(0.12, 0, 0.3 * side) if dir == 0 else Vector3(0.3 * side, 0, 0.12)
	_item("fence", 0, fp, 0.0 if dir == 0 else PI * 0.5, 1.0, 0.0, true)
	if _variant % 2 == 0:
		_item("scarecrow", 0, Vector3(0.1, 0, -0.022) if dir == 0 else Vector3(-0.022, 0, 0.1), rng.randf() * TAU, 1.0, 0.0, true)
	else:
		_item("cart", 0, Vector3(-0.27, 0, -0.3 * side) if dir == 0 else Vector3(-0.3 * side, 0, -0.27), 0.0 if dir == 0 else PI * 0.5,
			1.0, 0.0, true)
	# Bauer zwischen den Reihen
	for z in [-0.107, 0.064, 0.236]:
		var zz: float = z
		_spots.append(Vector3(rng.randf_range(-0.2, 0.2), 0, zz) if dir == 0 else Vector3(zz, 0, rng.randf_range(-0.2, 0.2)))
	if not _wither:
		var p0: Vector3 = _spots[0]
		_agent("person", _variant * 2, p0, 0.0 if dir == 0 else -PI * 0.5)


## Weide: helles Gras, Zaun, Tränke, ein Baum, eine kleine Herde.
func _b_animals(rng: RandomNumberGenerator) -> void:
	_item("fence", 1, Vector3(-0.2, 0, 0.18), 0.0, 1.0, 0.0)
	_item("trough", 0, Vector3(0.14, 0, -0.22), 0.3, 1.0, 0.04)
	_tree("bush_dry" if _wither else "oak", 7 + _variant, Vector3(0.23, 0, 0.21), rng, 0.85)
	_cover(100, 2 if _wither else 8, _wither, 3, 0.75)
	var herds := [["sheep", "sheep", "sheep", "sheep"], ["cow", "cow", "sheep", "sheep"], ["deer", "deer", "hare"], ["sheep", "cow", "sheep", "cow"]]
	var herd: Array = herds[_variant]
	if _wither:
		herd = ["sheep"]
	var pts := [Vector3(-0.08, 0, -0.08), Vector3(0.06, 0, -0.04), Vector3(-0.04, 0, 0.1), Vector3(0.1, 0, 0.1), Vector3(-0.16, 0, 0.02)]
	for k in herd.size():
		var kind: String = herd[k]
		_agent(kind, k + _variant, _R(pts[k]))


## Hütte: Blockhaus am Pfad, Holzstapel, Kaminrauch, Bäume, ein Mensch.
func _b_hut(rng: RandomNumberGenerator) -> void:
	var cab := _item("cabin", _variant, Vector3(-0.06, 0, -0.14), rng.randf_range(-0.12, 0.12), 1.3, 0.1)
	_item("woodpile", 0, Vector3(0.07, 0, -0.16), 0.2, 1.0, 0.03)
	_tree("spruce", _variant, Vector3(0.21, 0, -0.21), rng, 0.85)
	_tree("oak", _variant + 2, Vector3(0.2, 0, 0.21), rng, 0.8)
	_item("bush", _variant, Vector3(-0.22, 0, 0.21), 0.0, 1.0, 0.04)
	_cover(40, 5, false, 4, 0.9)
	_chimney(cab, Vector3(0.0352, 0.112, -0.0153))
	_spots = [Vector3(-0.08, 0, -0.06), Vector3(0.07, 0, -0.11), Vector3(-0.18, 0, 0.05), Vector3(0.15, 0, 0.06)]
	_agent("person", field_id % 6, Vector3(-0.08, 0, -0.05))


## Haus: Fachwerkhaus mit Garten (Beet, Zaun), Baum, zwei Menschen.
func _b_house(rng: RandomNumberGenerator) -> void:
	var h := _item("house", _variant, Vector3(-0.05, 0, -0.15), rng.randf_range(-0.08, 0.08), 1.3, 0.12)
	_item("fence", 0, Vector3(0.14, 0, 0.27), 0.0, 1.0, 0.0)
	_item("bush", _variant + 3, Vector3(0.13, 0, -0.16), 0.0, 1.0, 0.04)
	_tree("oak", _variant + 4, Vector3(-0.21, 0, 0.21), rng, 0.85)
	_tree("young", _variant, Vector3(0.22, 0, -0.2), rng, 1.0)
	_cover(38, 10, false, 3, 0.85)
	var w := 0.12 + 0.015 * float(_variant % 2)
	_chimney(h, Vector3(-w * 0.25, 0.165, -0.012))
	_spots = [Vector3(-0.09, 0, -0.07), Vector3(0.1, 0, 0.18), Vector3(0.18, 0, 0.05), Vector3(-0.15, 0, 0.06)]
	_agent("person", (field_id + 1) % 6, Vector3(-0.09, 0, -0.06))
	_agent("person", (field_id + 4) % 6, Vector3(0.12, 0, 0.17))


## Dorf: drei bis vier Häuser am Weg, Brunnen, Bäume, Menschen unterwegs.
func _b_village(rng: RandomNumberGenerator) -> void:
	var specs := [["house", Vector3(-0.17, 0, -0.17), 0.1], ["house", Vector3(0.14, 0, -0.17), -0.12],
		["house", Vector3(-0.15, 0, 0.21), PI + 0.08], ["cabin", Vector3(0.17, 0, 0.21), PI - 0.1]]
	var chim: Array = []
	for k in specs.size():
		var sp: Array = specs[k]
		var model: String = sp[0]
		if _variant == 2 and k == 3:
			model = "house"
		var it := _item(model, k + _variant, sp[1], float(sp[2]), 0.95, 0.11)
		if k % 2 == 0:
			if model == "house":
				var w := 0.12 + 0.015 * float((k + _variant) % 2)
				chim.append([it, Vector3(-w * 0.25, 0.165, -0.012)])
	_item("well", 0, Vector3(0.02, 0, -0.08), 0.3, 1.0, 0.04)
	_tree("oak", _variant + 5, Vector3(0.01, 0, 0.24), rng, 0.75)
	_cover(30, 6, false, 4, 0.8)
	for c in chim:
		var cc: Array = c
		_chimney(cc[0], cc[1])
	_spots = [Vector3(0.02, 0, -0.04), Vector3(-0.17, 0, -0.11), Vector3(0.14, 0, -0.11), Vector3(-0.15, 0, 0.15),
		Vector3(0.24, 0, 0.05), Vector3(-0.25, 0, 0.04)]
	_agent("person", field_id % 6, Vector3(-0.05, 0, 0.03))
	_agent("person", (field_id + 2) % 6, Vector3(0.05, 0, -0.03))
	_agent("person", (field_id + 3) % 6, Vector3(0.2, 0, 0.06))


## Stadt: Stadthäuser um einen gepflasterten Platz, Marktstände, Brunnen, viele Menschen.
func _b_town(rng: RandomNumberGenerator) -> void:
	var xs := [-0.2, -0.105, -0.01]
	for k in 3:
		_item("townhouse", (k + _variant) % 4, Vector3(xs[k], 0, -0.215), 0.0, 1.0, 0.07)
	_item("townhouse", 3, Vector3(0.2, 0, -0.17), -PI * 0.5, 1.0, 0.07)
	_item("townhouse", (_variant + 1) % 3, Vector3(0.21, 0, -0.06), -PI * 0.5, 1.0, 0.07)
	_item("stall", _variant, Vector3(-0.13, 0, 0.13), 0.2, 1.1, 0.04)
	_item("stall", _variant + 1, Vector3(0.0, 0, 0.19), -0.15, 1.1, 0.04)
	_item("cart", 0, Vector3(0.17, 0, 0.15), 0.6, 1.0, 0.03)
	_item("well", 0, Vector3(-0.04, 0, 0.0), 0.0, 1.1, 0.04)
	_tree("young", _variant + 1, Vector3(-0.25, 0, 0.25), rng, 1.0)
	_spots = [Vector3(-0.13, 0, 0.08), Vector3(0.0, 0, 0.14), Vector3(-0.04, 0, 0.05), Vector3(0.12, 0, -0.02),
		Vector3(-0.18, 0, -0.14), Vector3(0.1, 0, 0.1)]
	for k in 4:
		_agent("person", (field_id + k * 2) % 6, _spots[k])


## Kirche: Steinkirche mit Turm, Kirchhof mit Bäumen und Grabsteinen, Gläubige.
func _b_church(rng: RandomNumberGenerator) -> void:
	_item("church", 0, Vector3(0.0, 0, -0.04), PI if _variant % 2 == 1 else 0.0, 1.05, 0.2)
	_tree("spruce", _variant, Vector3(-0.23, 0, 0.21), rng, 0.85)
	_tree("oak", _variant + 1, Vector3(0.23, 0, 0.22), rng, 0.75)
	for k in 4:
		_item("rock", k, Vector3(-0.12 + 0.05 * float(k), 0, 0.22), 0.0, 0.2, 0.02)
	_cover(26, 3, false, 6, 0.7)
	_spots = [Vector3(0.18, 0, -0.04), Vector3(-0.05, 0, 0.16), Vector3(0.1, 0, 0.15)]
	_agent("person", 5, Vector3(-0.05, 0, 0.15))
	_agent("person", (field_id + 1) % 5, Vector3(0.12, 0, 0.14))


## Großstadt: Wohnblöcke im Raster, Straßenbäume.
func _b_bigcity(rng: RandomNumberGenerator) -> void:
	var cs := [Vector3(-0.14, 0, -0.14), Vector3(0.14, 0, -0.14), Vector3(-0.14, 0, 0.14), Vector3(0.14, 0, 0.14)]
	for k in 4:
		_item("block", (k + _variant) % 4, cs[k], PI * 0.5 * float(k % 2), 0.95, 0.09)
	_tree("young", _variant, Vector3(0.0, 0, -0.27), rng, 0.9)
	_tree("young", _variant + 2, Vector3(0.0, 0, 0.27), rng, 0.9)
	_spots = [Vector3(0.0, 0, 0.0), Vector3(-0.14, 0, 0.0), Vector3(0.14, 0, 0.0), Vector3(0.0, 0, 0.14), Vector3(0.0, 0, -0.14)]
	for k in 3:
		_agent("person", (field_id + k) % 6, _spots[k])


## Industrie: Hallen, Schlote mit Rauchfahnen, Silos, Gleis.
func _b_industry(rng: RandomNumberGenerator) -> void:
	var v := _variant % 2
	var it := _item("factory", v, Vector3.ZERO, 0.0, 1.0, 0.0)
	_obst.append(Vector3(it.position.x, it.position.z, 0.22))
	var tops: Array = [Vector3(0.1, 0.39, -0.12), Vector3(0.17, 0.31, -0.06)] if v == 0 else [Vector3(0.12, 0.41, -0.1)]
	var c := SMOKE_DARK if _polluted else SMOKE_C
	for t in tops.size():
		var tp: Vector3 = (it.get_meta("xf") as Transform3D) * (tops[t] as Vector3)
		for k in 3:
			_puff(tp, 0.04, c, 0.26, fmod(k / 3.0 + t * 0.17, 1.0), 0.45)
	_cover(10, 0, true, 6, 0.6, 0.3)
	_spots = [_R(Vector3(0.12, 0, 0.13)), _R(Vector3(-0.2, 0, 0.18))]
	_agent("person", 1 + field_id % 2, _spots[0])
	var _u := rng


## Metropole: Glastürme, Wohnblock, Platz mit Bäumen.
func _b_metropolis(rng: RandomNumberGenerator) -> void:
	_item("glass_tower", 0 + _variant % 2, Vector3(-0.13, 0, -0.13), 0.0, 1.0, 0.08)
	_item("glass_tower", 1 + _variant % 2, Vector3(0.13, 0, -0.11), PI * 0.5, 1.0, 0.08)
	_item("glass_tower", 2, Vector3(0.13, 0, 0.14), 0.0, 0.85, 0.07)
	_item("block", _variant, Vector3(-0.14, 0, 0.14), 0.0, 0.9, 0.09)
	_tree("young", _variant, Vector3(0.0, 0, 0.02), rng, 0.9)
	_tree("young", _variant + 1, Vector3(0.01, 0, 0.26), rng, 0.8)
	_spots = [Vector3(-0.02, 0, 0.08), Vector3(0.0, 0, -0.08), Vector3(0.06, 0, 0.02)]
	for k in 3:
		_agent("person", (field_id + k * 3) % 6, _spots[k])


## Paradies: Blütenbaum, Teich mit Enten, üppige Wiese, Lichtstrahlen, Hirsch.
func _b_paradise(rng: RandomNumberGenerator) -> void:
	_tree("bush_dry" if _wither else "blossom", _variant, Vector3(-0.13, 0, -0.12), rng, 1.25 if not _wither else 1.5)
	_tree("birch", _variant, Vector3(0.22, 0, -0.22), rng, 0.85)
	var pond := _R(Vector3(0.1, 0, 0.1))
	_obst.append(Vector3(pond.x, pond.z, 0.14))
	_water_mat = Look.water()
	_water_mat.set_shader_parameter("half_size", 0.11)
	var surf := Models.rbox(_content, Vector3(0.22, 0.004, 0.2), 0.008, Color.WHITE, pond + Vector3(0, 0.002, 0), Vector3.ZERO, _water_mat)
	surf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 5:
		var a := TAU * float(k) / 5.0 + 0.3
		_item("rock", k + 3, pond + Vector3(cos(a) * 0.12, 0, sin(a) * 0.11), rng.randf() * TAU, 0.32, 0.0, true)
	_cover(70, 4 if _wither else 30, _wither, 2, 1.1)
	for ix in 3:
		for iz in 3:
			_water_pts.append(pond + Vector3(-0.06 + 0.06 * float(ix), 0.003, -0.05 + 0.05 * float(iz)))
	if _wither:
		return
	_agent("duck", 0, pond + Vector3(0.02, 0.003, 0.0))
	_agent("deer", 1, _R(Vector3(-0.05, 0, 0.14)))
	for k in 2:
		var beam := MeshInstance3D.new()
		beam.mesh = Look.quad(1.0)
		beam.material_override = Look.mote(Color(1.0, 0.93, 0.72, 0.22))
		beam.scale = Vector3(0.09, 0.55, 1.0)
		beam.position = _R(Vector3(-0.13 + 0.08 * k, 0.3, -0.12 + 0.05 * k))
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_content.add_child(beam)


## Wasser: Wasser-Shader (Wellen, Ufer-Schaum), manchmal Enten.
func _b_water(_rng: RandomNumberGenerator) -> void:
	_water_mat = Look.water()
	_water_mat.set_shader_parameter("half_size", 0.31)
	_water_mat.set_shader_parameter("edge_mask", _water_mask)
	_water_surf = null
	_water_surface()
	for ix in 4:
		for iz in 4:
			_water_pts.append(Vector3(-0.18 + 0.12 * float(ix), 0.005, -0.18 + 0.12 * float(iz)))
	if posmod(field_id, 5) == 0:
		_agent("duck", 0, Vector3(-0.06, 0.005, 0.04))
		_agent("duck", 1, Vector3(0.0, 0.005, 0.1))
	elif posmod(field_id, 5) == 3:
		_agent("duck", 1, Vector3(0.08, 0.005, -0.06))


## Stein: Felsen mit Abbaukante, geschnittene Blöcke, Schutt, manchmal ein Steinhauer.
func _b_stone(rng: RandomNumberGenerator) -> void:
	_item("quarry", _variant, Vector3.ZERO, 0.0, 1.0, 0.0)
	var qp := _R(Vector3(-0.1, 0, -0.12))
	_obst.append(Vector3(qp.x, qp.z, 0.17))
	if _variant % 2 == 1:
		_item("cart", 0, Vector3(0.2, 0, 0.21), 0.5, 1.0, 0.03)
	_cover(22, 2, true, 26, 0.7)
	_spots = [_R(Vector3(0.05, 0, 0.0)), _R(Vector3(0.1, 0, 0.12))]
	if _variant % 2 == 0:
		_agent("person", 3 + field_id % 2, _spots[0])
	var _u := rng
