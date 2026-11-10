extends Node
## Trailer v2 für gdpd („Die Schöpfung“): eine eigene Szene, die die echte Welt (World, FieldView, Models, Look,
## Zeitalter) und echte Level-Bretter der Kampagne nutzt. Nichts im Spiel wird geändert.
##
## Aufnahme (Movie Maker, jedes Bild deterministisch; Hochformat oder quadratisch, das Layout passt sich an):
##   godot --rendering-driver opengl3 --resolution 1080x1920 --write-movie out/f.png --fixed-fps 30 res://trailer/trailer.tscn
##   godot ... --resolution 1080x1080 ... res://trailer/trailer.tscn          (quadratischer Schnitt)
## Optionen nach "--": --cues=<datei.json>  schreibt die Zeitpunkte aller Klang-Ereignisse (für die Tonspur)
##
## Ablauf (34,6 s): Haken „Aus Glut … wird eine Welt.“ · Glut · Dampf wird Regen · Algen, der Himmel wird blau,
## „Du bist Gott.“ mit Miez · Montage: Wälder, Fische, Landgang, Zeit der Riesen, Meteor, Säugetiere, Affen,
## Menschen, Dörfer und Städte · die fertige Welt · Abspann mit Aufruf.

const W := 1080.0
const END_T := 34.6
const MARKS_OFF := ["highlight", "still", "hint", "satt", "select", "target", "supply_up", "supply_down"]
const SNAP := 0.45                    # Dauer einer Drehung (die Hand wischt mit)

var H := 1920.0
var square := false

var world: World
var _t := 0.0
var _shot := {}
var _layer: CanvasLayer
var _grade: ShaderMaterial
var _title: Label
var _title_y := 250.0
var _title_tws: Array = []
var _scrim: TextureRect
var _caps_panel: PanelContainer
var _caps: Label
var _caps_y := 1320.0
var _hand: TextureRect
var _hand_follow := {}
var _cameo: CharacterView
var _end: Control
var _god: CharacterView
var _dinos: Array = []
var _apes: Array = []
var _whips: Array = []                # Schnitte mit Wisch-Schwenk (Zeitpunkte)
var _grow := {}                       # erstes gewachsenes Feld der Einstellung: {"fid", "t"}
var _push := 0.5                      # wie weit die Kamera danach auf das Feld zuschiebt (0 = gar nicht)
var _focus: Node3D = null             # Einstellung folgt diesem Punkt (Riesen, Affen)
var _focus_w := 0.0
var _cues: Array = []
var _cue_path := ""
var _stomp_next := 0.0
var _dino_center: Node3D = null
var _props: Array = []              # Meteor-Spur, Asche, Licht (beim nächsten Schnitt weg)


func _ready() -> void:
	process_priority = 1000          # nach der Welt und dem Kamera-Halter: die Trailer-Kamera hat das letzte Wort
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cues="):
			_cue_path = a.substr(7)
	Game.first_launch = false
	Game.debug_open_all = true
	Game.rescue_on = false
	Game.tutorial_done = true
	Game.always_ask = false
	Balance.TWIST_SNAP_SECONDS = SNAP
	world = World.new()
	world.name = "World"
	add_child(world)
	_hook_world()
	_build_overlay()
	RenderingServer.frame_pre_draw.connect(_pre_draw)
	_director()


func _hook_world() -> void:
	world.tour_auto = true
	world.merged.connect(_on_merged)


# =============================================================================
# Kamera
# =============================================================================

static func _basis(yaw_deg: float, pitch_deg: float) -> Basis:
	var y := deg_to_rad(yaw_deg)
	var p := deg_to_rad(pitch_deg)
	var z := Vector3(cos(p) * sin(y), sin(p), cos(p) * cos(y))
	var yy := (Vector3.UP - z * z.dot(Vector3.UP)).normalized()
	return Basis(yy.cross(z).normalized(), yy, z)


static func cam_dir(yaw_deg: float, pitch_deg: float) -> Vector3:
	return _basis(yaw_deg, pitch_deg).z


## Eine Einstellung: Gier, Neigung, Zoom (1 = ganzer Würfel, < 0 = sehr nah), Verschiebung im Bild; a → b in dur s.
func shot(y0: float, y1: float, p0: float, p1: float, z0: float, z1: float, dur: float,
		pan0: Vector2 = Vector2.ZERO, pan1: Vector2 = Vector2.ZERO, curve: float = -1.6) -> void:
	_shot = {"t0": _t, "dur": dur, "y0": y0, "y1": y1, "p0": p0, "p1": p1, "z0": z0, "z1": z1,
		"pan0": pan0, "pan1": pan1, "curve": curve}
	_grow = {}
	_focus = null
	_focus_w = 0.0
	_apply_cam()


## Wisch-Schwenk um einen Schnitt: vorher schnell nach rechts weg, danach von links herein, mit Bewegungsunschärfe.
func _whip_at(t: float) -> Vector2:
	var yaw := 0.0
	var blur := 0.0
	for c in _whips:
		var d := t - float(c)
		if d > -0.13 and d < 0.0:
			var k := 1.0 + d / 0.13
			yaw += 38.0 * k * k
			blur = maxf(blur, k)
		elif d >= 0.0 and d < 0.2:
			var k2 := 1.0 - d / 0.2
			yaw -= 34.0 * k2 * k2
			blur = maxf(blur, k2)
	return Vector2(yaw, blur)


func _process(delta: float) -> void:
	_t += delta
	# Feste Qualität (Movie Maker liefert 33 ms je Bild: die Welt würde sonst die Qualität senken), keine Hinweise
	world._perf_done = true
	world._hinted = true
	world._idle = 0.0
	Game.onboarding = false
	_apply_cam()
	_update_dinos(delta)
	_update_apes()
	_update_hand()


## Kurz vor dem Zeichnen (nach allen Tweens und Timern dieses Bildes): Markierungen der Spiel-Oberfläche aus,
## Verschmelzungs-Licht warm und gedämpft. So blitzt auch im ersten Bild eines Effekts nichts weiß auf.
func _pre_draw() -> void:
	if not is_instance_valid(world):
		return
	for fid in world.views:
		var fv: FieldView = world.views[fid]
		# Keine Spiel-Plaketten über den Feldern (Bedürfnisse, Zähler, ×2): der Trailer zeigt nur die Welt
		fv.set_labels_visible(false)
		# Der Verschmelzungs-Blitz bleibt warm und gedämpft (sonst strahlt das Feld fast weiß und das Ergebnis geht unter)
		for mk in MARKS_OFF:
			if fv.has_mark(mk):
				fv.set_mark(mk, false)
		if fv._ground != null:
			fv._ground.set_shader_parameter("pulse_c", Color(0.34, 0.25, 0.1))
		for ch in fv.get_children():
			if ch is MeshInstance3D and not ch.has_meta("toned"):
				var sm := (ch as MeshInstance3D).material_override as ShaderMaterial
				if sm != null and sm.shader != null and sm.shader.resource_path.ends_with("ring.gdshader"):
					sm.set_shader_parameter("color", Color(1.0, 0.76, 0.3, 0.5))
					ch.set_meta("toned", true)


func _apply_cam() -> void:
	var wb := _whip_at(_t)
	_grade.set_shader_parameter("blur", 0.05 * wb.y)
	if _shot.is_empty() or world.rig == null:
		return
	var u := clampf((_t - float(_shot["t0"])) / maxf(float(_shot["dur"]), 0.001), 0.0, 1.0)
	var k := ease(u, float(_shot["curve"]))
	var rig := world.rig
	rig.drift_enabled = false
	rig._anim_t = 1.0
	rig._vel = Vector2.ZERO
	rig._drift = Vector2.ZERO
	rig._drift_w = 0.0
	rig.basis = _basis(lerpf(_shot["y0"], _shot["y1"], k) + wb.x, lerpf(_shot["p0"], _shot["p1"], k))
	var z := 0.6 + 0.45 * lerpf(_shot["z0"], _shot["z1"], k)
	var pan: Vector2 = (_shot["pan0"] as Vector2).lerp(_shot["pan1"], k)
	# einem Punkt folgen (Riesen, Affen): seine Lage im Kamera-Raum in die Bildmitte schieben
	if _focus != null and is_instance_valid(_focus) and _focus_w > 0.0:
		var pl := rig.global_transform.basis.inverse() * _focus.global_position
		pan = pan.lerp(Vector2(pl.x, pl.y), _focus_w)
	# nach dem Wachsen: kurz auf das gewachsene Feld zuschieben und das Ergebnis stehen lassen
	if not _grow.is_empty() and _push > 0.0:
		var v: FieldView = world.views.get(int(_grow["fid"]))
		if v != null:
			var g := smoothstep(0.0, 0.32, _t - float(_grow["t"]))
			var pl2 := rig.global_transform.basis.inverse() * (v.global_position + v.world_normal() * 0.1)
			pan = pan.lerp(Vector2(pl2.x, pl2.y), _push * g)
			z *= 1.0 - 0.3 * _push * g
	rig.zoom_factor = z * (1.2 if square else 1.0)
	rig._apply()
	rig.cam.position += Vector3(pan.x, pan.y, 0.0)


func _on_merged(fid: int, _points: int, _combo: int, _stage: int) -> void:
	_cue("grow")
	if _grow.is_empty():
		_grow = {"fid": fid, "t": _t}


# =============================================================================
# Oberfläche des Trailers (Farbe, Text, Hand, Abspann)
# =============================================================================

func _cue(name: String, v: float = 1.0) -> void:
	_cues.append({"t": snappedf(_t, 0.001), "c": name, "v": v})


func _settings(size: int, weight: int, color: Color = Color.WHITE, shadow: float = 0.5, spacing: int = 0) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = Style.font_w(weight, spacing)
	ls.font_size = size
	ls.font_color = color
	ls.shadow_color = Color(0.02, 0.03, 0.06, shadow)
	ls.shadow_size = maxi(6, size / 7)
	ls.shadow_offset = Vector2(0, maxf(2.0, size / 30.0))
	ls.line_spacing = -size * 0.1
	return ls


func _mk_label(text: String, size: int, weight: int, y: float, h: float, color: Color = Color.WHITE,
		parent: Control = null, shadow: float = 0.35, spacing: int = 0) -> Label:
	var l := Label.new()
	l.label_settings = _settings(size, weight, color, shadow, spacing)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = Vector2(40, y)
	l.size = Vector2(W - 80, h)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(l)
	else:
		_layer.add_child(l)
	return l


func _gradient_rect(c0: Color, c1: Color, pos: Vector2, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 16
	gt.height = 256
	r.texture = gt
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.position = pos
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _build_overlay() -> void:
	# Oberfläche in 1080er-Koordinaten, egal in welcher Auflösung gerendert wird
	var vs := get_viewport().get_visible_rect().size
	get_tree().root.content_scale_factor = vs.x / W
	H = W * vs.y / vs.x
	square = H < 1500.0
	# Sichere Zonen (Hochformat, TikTok/Reels/Shorts): Titel 250–470, Bildunterschrift um 1320
	_title_y = 46.0 if square else 250.0
	_caps_y = H - 150.0 if square else 1320.0
	# Farbkorrektur über der Welt, unter dem Text
	var gl := CanvasLayer.new()
	gl.layer = 10
	add_child(gl)
	var gr := ColorRect.new()
	gr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade = ShaderMaterial.new()
	_grade.shader = load("res://trailer/grade.gdshader")
	gr.material = _grade
	gl.add_child(gr)
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	# weicher dunkler Verlauf oben hinter dem Titel
	_scrim = _gradient_rect(Color(0.03, 0.04, 0.08, 0.5), Color(0.03, 0.04, 0.08, 0.0), Vector2.ZERO,
		Vector2(W, (_title_y + 360.0)))
	_scrim.modulate.a = 0.0
	_layer.add_child(_scrim)
	_title = _mk_label("", 96, 800, _title_y, 230)
	_title.clip_text = false
	_title.pivot_offset = _title.size * 0.5
	_title.modulate.a = 0.0
	# Bildunterschrift als Pille (große Schrift, wenig Sperrung)
	_caps_panel = PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.06, 0.08, 0.13, 0.66)
	csb.set_corner_radius_all(64)
	csb.content_margin_left = 48
	csb.content_margin_right = 48
	csb.content_margin_top = 16
	csb.content_margin_bottom = 20
	_caps_panel.add_theme_stylebox_override("panel", csb)
	_caps = Label.new()
	_caps.label_settings = _settings(80, 800, Color(1, 1, 1, 0.98), 0.0, 1)
	_caps_panel.add_child(_caps)
	_caps_panel.modulate.a = 0.0
	_caps_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_caps_panel)
	# Finger, der den Würfel dreht
	_hand = TextureRect.new()
	_hand.texture = Style.icon("touch")
	_hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hand.size = Vector2(210, 210)
	_hand.pivot_offset = Vector2(92, 26)
	_hand.modulate.a = 0.0
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_hand)
	# Miez als Gastgeber (kurzer Auftritt bei „Du bist Gott.“)
	_cameo = CharacterView.make(Character.default_look("katze"), 320.0, false, "happy")
	_cameo.position = Vector2(30, (H - 330.0) if square else 1080.0)
	_cameo.pivot_offset = Vector2(160, 310)
	_cameo.scale = Vector2.ZERO
	_cameo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_cameo)
	_build_end()


func _build_end() -> void:
	_end = Control.new()
	_end.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end.modulate.a = 0.0
	_layer.add_child(_end)
	var bg := _gradient_rect(Color(0.07, 0.09, 0.16, 0.84), Color(0.16, 0.12, 0.21, 0.94), Vector2.ZERO, Vector2(W, H))
	_end.add_child(bg)
	var y_main := 24.0 if square else 250.0
	var y_sub := 218.0 if square else 500.0
	var god_px := 270.0 if square else 430.0
	var y_god := 280.0 if square else 590.0
	var y_name := 556.0 if square else 1030.0
	var y_cta := 640.0 if square else 1130.0
	var y_badge := 800.0 if square else 1290.0
	_mk_label("Die Welt ist ein Würfel.\nDu bist Gott.", 76 if square else 92, 800, y_main, 190 if square else 220,
		Color("#FBF8F3"), _end, 0.3)
	_mk_label("gdpd · Das Gottspiel auf dem Würfel", 42 if square else 44, 700, y_sub, 60, Color(1, 1, 1, 0.72), _end, 0.2)
	_god = CharacterView.make(Character.default_look("katze"), god_px, false, "happy")
	_god.position = Vector2(W * 0.5 - god_px * 0.5, y_god)
	_god.pivot_offset = Vector2(god_px * 0.5, god_px * 0.95)
	_god.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end.add_child(_god)
	_mk_label("Miez, dein Katzengott", 44, 700, y_name, 64, Color(1, 1, 1, 0.82), _end, 0.2)
	# Aufruf: großer Knopf und zwei Laden-Plaketten (ohne fremde Logos)
	var cta := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Style.SUN
	sb.set_corner_radius_all(60)
	sb.content_margin_left = 64
	sb.content_margin_right = 64
	sb.content_margin_top = 18
	sb.content_margin_bottom = 22
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 20
	sb.shadow_offset = Vector2(0, 8)
	cta.add_theme_stylebox_override("panel", sb)
	var cl := Label.new()
	var cls := LabelSettings.new()
	cls.font = Style.font_w(800)
	cls.font_size = 62
	cls.font_color = Color("#1F2430")
	cl.label_settings = cls
	cl.text = "Jetzt vorregistrieren"
	cta.add_child(cl)
	_end.add_child(cta)
	cta.reset_size()
	var cs := cta.get_combined_minimum_size()
	cta.size = cs
	cta.position = Vector2((W - cs.x) * 0.5, y_cta)
	cta.pivot_offset = cs * 0.5
	_end.set_meta("cta", cta)
	var bw := 400.0
	var gap := 36.0
	var x0 := (W - 2.0 * bw - gap) * 0.5
	_badge("Jetzt bei", "Google Play", Vector2(x0, y_badge), bw)
	_badge("Laden im", "App Store", Vector2(x0 + bw + gap, y_badge), bw)


func _badge(small: String, big: String, pos: Vector2, w: float) -> void:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#0b0d12")
	sb.set_corner_radius_all(22)
	sb.border_color = Color(1, 1, 1, 0.55)
	sb.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = Vector2(w, 118)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end.add_child(p)
	var a := Label.new()
	var als := LabelSettings.new()
	als.font = Style.font_w(600)
	als.font_size = 28
	als.font_color = Color(1, 1, 1, 0.85)
	a.label_settings = als
	a.text = small
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a.position = Vector2(0, 10)
	a.size = Vector2(w, 36)
	p.add_child(a)
	var b := Label.new()
	var bls := LabelSettings.new()
	bls.font = Style.font_w(800)
	bls.font_size = 50
	bls.font_color = Color.WHITE
	b.label_settings = bls
	b.text = big
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.position = Vector2(0, 42)
	b.size = Vector2(w, 64)
	p.add_child(b)


## Titel: schnell und hell einblenden (leicht von unten), stehen lassen, ausblenden.
func say(text: String, hold: float, fade_in: float = 0.25, fade_out: float = 0.3, size: int = 96) -> void:
	_cue("title")
	for old in _title_tws:
		if (old as Tween).is_valid():
			(old as Tween).kill()
	_title.text = text
	_title.label_settings.font_size = size
	_title.label_settings.shadow_size = maxi(6, size / 7)
	var sc := create_tween()
	sc.tween_property(_scrim, "modulate:a", 1.0, fade_in).set_trans(Tween.TRANS_SINE)
	sc.tween_interval(hold)
	sc.tween_property(_scrim, "modulate:a", 0.0, fade_out + 0.15).set_trans(Tween.TRANS_SINE)
	_title.modulate.a = 0.0 if fade_in > 0.0 else 1.0
	_title.position.y = _title_y + (18.0 if fade_in > 0.0 else 0.0)
	_title.scale = Vector2.ONE * 0.97
	var tw := create_tween()
	if fade_in > 0.0:
		tw.tween_property(_title, "modulate:a", 1.0, fade_in).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(_title, "position:y", _title_y, fade_in * 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_interval(0.01)
	tw.tween_interval(hold)
	tw.tween_property(_title, "modulate:a", 0.0, fade_out).set_trans(Tween.TRANS_SINE)
	var st := create_tween()
	st.tween_property(_title, "scale", Vector2.ONE, hold + fade_in).set_trans(Tween.TRANS_SINE)
	_title_tws = [sc, tw, st]


func caps(text: String, hold: float) -> void:
	_caps.text = text
	_caps_panel.reset_size()
	var sz := _caps_panel.get_combined_minimum_size()
	_caps_panel.size = sz
	_caps_panel.position = Vector2((W - sz.x) * 0.5, _caps_y - sz.y * 0.5)
	_caps_panel.pivot_offset = sz * 0.5
	_caps_panel.scale = Vector2.ONE * 0.86
	var tw := create_tween()
	tw.tween_property(_caps_panel, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(_caps_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(_caps_panel, "modulate:a", 0.0, 0.18)


## Farbstimmung des Trailers (über der Welt): Belichtung, Kontrast, Sättigung, Vignette.
func grade(exp: float, con: float, sat: float, vig: float, dur: float = 0.0) -> void:
	var vals := {"exposure": exp, "contrast": con, "saturation": sat, "vignette": vig}
	if dur <= 0.0:
		for key in vals:
			_grade.set_shader_parameter(key, vals[key])
		return
	var tw := create_tween().set_parallel(true)
	for key in vals:
		tw.tween_property(_grade, "shader_parameter/" + key, vals[key], dur).set_trans(Tween.TRANS_SINE)


func tint(c: Color, amt: float, dur: float) -> void:
	_grade.set_shader_parameter("tint", Vector3(c.r, c.g, c.b))
	if dur <= 0.0:
		_grade.set_shader_parameter("tint_amt", amt)
		return
	var tw := create_tween()
	tw.tween_property(_grade, "shader_parameter/tint_amt", amt, dur).set_trans(Tween.TRANS_SINE)


func flash(c: Color, amount: float, dur: float) -> void:
	_grade.set_shader_parameter("flash_c", Vector3(c.r, c.g, c.b))
	_grade.set_shader_parameter("flash", amount)
	var tw := create_tween()
	tw.tween_property(_grade, "shader_parameter/flash", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# --- Hand ---------------------------------------------------------------------

func _screen_of(p: Vector3) -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	return world.rig.cam.unproject_position(p) * (W / vs.x)


## Die Hand drückt auf das Feld fid und wischt mit, solange die Scheibe dreht.
func hand_on(fid: int, dur: float) -> void:
	var v: FieldView = world.views.get(fid)
	if v == null:
		return
	_hand_follow = {"v": v, "t0": _t, "t1": _t + dur}
	_hand.position = _screen_of(v.global_position + v.world_normal() * 0.1) - _hand.pivot_offset
	_hand.scale = Vector2.ONE * 1.12
	var tw := create_tween()
	tw.tween_property(_hand, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(_hand, "scale", Vector2.ONE * 0.92, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(dur - 0.14, 0.05))
	tw.tween_property(_hand, "scale", Vector2.ONE * 1.08, 0.18).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_hand, "modulate:a", 0.0, 0.22)


func _update_hand() -> void:
	if _hand_follow.is_empty():
		return
	var v: Variant = _hand_follow["v"]
	if not is_instance_valid(v) or _t > float(_hand_follow["t1"]):
		_hand_follow = {}
		return
	var fv := v as FieldView
	var target := _screen_of(fv.global_position + fv.world_normal() * 0.1) - _hand.pivot_offset
	_hand.position = _hand.position.lerp(target, 0.75)


# =============================================================================
# Ablauf
# =============================================================================

func _at(sec: float) -> void:
	while _t < sec:
		await get_tree().process_frame


func _settle(max_s: float = 4.0) -> void:
	var t0 := _t
	while (world.animating or Game.busy) and _t - t0 < max_s:
		await get_tree().process_frame


## Ein Level mit einem Pool-Brett laden und das Zeitalter sofort setzen (Schnitt, keine Überblendung).
func level(n: int, board: int = 0) -> void:
	# Harter Schnitt: Läuft in der alten Welt noch eine Runde (Wachsen, Effekte), kommt eine frische Welt.
	if Game.busy or world.animating or world._pivot != null:
		_new_world()
	_clear_props()
	world._mood_hold = ""
	_cue("cut")
	Game.start_level(n, board)
	Game.onboarding = false
	world.set_era(Game.state.era9(), 0.0)
	world._hinted = true


func _new_world() -> void:
	var old := world
	remove_child(old)
	old.queue_free()
	Game.busy = false
	world = World.new()
	world.name = "World"
	add_child(world)
	move_child(world, 0)
	_hook_world()


func _clear_props() -> void:
	for d in _dinos:
		if is_instance_valid((d as Dictionary)["node"]):
			((d as Dictionary)["node"] as Node).queue_free()
	_dinos.clear()
	for a in _apes:
		if is_instance_valid((a as Dictionary)["node"]):
			((a as Dictionary)["node"] as Node).queue_free()
	_apes.clear()
	for p in _props:
		if is_instance_valid(p):
			(p as Node).queue_free()
	_props.clear()
	_dino_center = null
	tint(Color.WHITE, 0.0, 0.0)


## Das tote Wasser der Glut-Zeit etwas heller und blauer (liest sich sonst als schwarzes Loch).
func _lava_water() -> void:
	Look.water_deep = Color("#24485a")
	Look.water_shallow = Color("#4f7686")
	for w in Look._water_mats:
		var m: ShaderMaterial = (w as WeakRef).get_ref()
		if m != null:
			m.set_shader_parameter("w_deep", Look.water_deep)
			m.set_shader_parameter("w_shallow", Look.water_shallow)


## Die beste sichtbare Drehung: viel Fortschritt, viele neue Felder auf den Seiten, die zur Kamera zeigen.
func best_move(dir: Vector3, avoid_bad: bool = true) -> Array:
	var gs: GameState = Game.state
	var best: Array = []
	var best_s := -1.0e9
	for m in GameState.MOVES:
		var r: Dictionary = gs.simulate({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])})
		var st: GameState = r["state"]
		var s := float(st.goal_progress() - gs.goal_progress()) * 4.0
		for i in st.fields.size():
			var a: FieldData = gs.fields[i]
			var b: FieldData = st.fields[i]
			if a.kind != b.kind:
				var d := Vector3(b.n).dot(dir)
				s += 2.5 * d if d > 0.25 else -0.6
		if avoid_bad:
			for e in (r["result"] as Dictionary).get("events", []):
				if str((e as Dictionary).get("type", "")) in ["erupt", "goal_loss", "starve", "bolt", "pack_hunt", "war", "polluted", "flood"]:
					s -= 4.0
		if int(m[2]) == 2:
			s -= 0.3                     # Vierteldrehungen sehen ruhiger aus
		if s > best_s:
			best_s = s
			best = m
	return best


## Beste Drehung spielen; mit Hand: der Finger drückt auf das sichtbarste Feld der Reihe und wischt mit.
func twist_best(dir: Vector3, with_hand: bool = false) -> void:
	await _settle(3.0)
	var m := best_move(dir)
	if m.is_empty():
		return
	if with_hand:
		var row: Array = Game.state.slice_row(int(m[0]), int(m[1]))
		var best_f := -1
		var best_d := -2.0
		for f in row:
			var v: FieldView = world.views.get(int(f))
			if v == null:
				continue
			var d := v.world_normal().dot(dir)
			if d > best_d:
				best_d = d
				best_f = int(f)
		if best_f >= 0:
			hand_on(best_f, SNAP * 0.8)
	world.auto_twist(int(m[0]), int(m[1]), int(m[2]))
	_cue("twist")


## Eine bestimmte Drehung spielen (vorher mit trailer/tools/scout_hut.gd gesucht), optional mit Hand.
func twist_move(m: Array, dir: Vector3, with_hand: bool = false) -> void:
	if with_hand:
		var row: Array = Game.state.slice_row(int(m[0]), int(m[1]))
		var best_f := -1
		var best_d := -2.0
		for f in row:
			var v: FieldView = world.views.get(int(f))
			if v != null and v.world_normal().dot(dir) > best_d:
				best_d = v.world_normal().dot(dir)
				best_f = int(f)
		if best_f >= 0:
			hand_on(best_f, SNAP * 0.8)
	world.auto_twist(int(m[0]), int(m[1]), int(m[2]))
	_cue("twist")


## Ein Feld einer Art auf der Seite, die am meisten zur Kamera zeigt (oder -1).
func field_facing(kinds: Array, dir: Vector3, skip: Array = []) -> int:
	var best := -1
	var best_d := 0.3
	for f in Game.state.fields:
		var fd: FieldData = f
		if fd.kind in kinds and not (fd.id in skip):
			var v: FieldView = world.views.get(fd.id)
			if v == null:
				continue
			var d := v.world_normal().dot(dir) + 0.02 * float(fd.id % 7)
			if d > best_d:
				best_d = d
				best = fd.id
	return best


func _director() -> void:
	# ---------------------------------------------------------------- Haken: aus Glut … wird eine Welt (0 – 1,75 s)
	level(1, 0)
	_lava_water()
	grade(1.04, 1.08, 1.06, 0.3)
	shot(30, 44, 26, 30, 0.58, 0.5, 0.9, Vector2(0, 0.25), Vector2(0, 0.25))
	say("Aus Glut …", 0.55, 0.0, 0.12)
	twist_best(cam_dir(36, 28), true)
	await _at(0.85)
	level(30, 1)
	world.set_era("vollendet", 0.0)
	world.set_rest(3, 3)
	flash(Color("#fff4dc"), 0.55, 0.3)
	_cue("reveal")
	grade(1.0, 1.06, 1.08, 0.25)
	shot(-30, -12, 28, 25, 0.72, 0.6, 0.95, Vector2(0, 0.35), Vector2(0, 0.35), -1.2)
	say("… wird eine Welt.", 0.62, 0.0, 0.14)
	# ---------------------------------------------------------------- Glut (1,75 – 4,3 s)
	_whips.append(1.75)
	await _at(1.75)
	level(2, 1)
	_lava_water()
	grade(1.04, 1.08, 1.06, 0.3)
	shot(-34, -14, 34, 28, 0.6, 0.5, 2.6, Vector2(0, 0.3), Vector2(0, 0.3))
	_push = 0.45
	say("Am Anfang\nwar die Glut.", 1.9, 0.2, 0.3)
	await _at(1.85)
	await twist_best(cam_dir(-22, 32))
	# ---------------------------------------------------------------- Dampf wird Regen (4,3 – 5,8 s)
	_whips.append(4.3)
	await _at(4.3)
	level(5, 1)
	grade(1.03, 1.14, 1.2, 0.38)
	shot(30, 44, 30, 36, 0.66, 0.6, 1.5)
	caps("DAMPF WIRD REGEN", 1.15)
	await _at(4.42)
	var rf := field_facing([FieldData.STONE, FieldData.LAVA], cam_dir(36, 34))
	if rf >= 0 and Game.state.rain <= 0:
		Game.state.rain = 1
	if rf >= 0 and not Game.use_bonus("rain", rf, [], true):
		world._rain_fx([rf])
	_cue("rain")
	# ---------------------------------------------------------------- Algen, der Himmel wird blau, Du bist Gott (5,8 – 8,8 s)
	_whips.append(5.8)
	await _at(5.8)
	level(9, 1)
	world._sky_blue = 0.0
	world.set_era_mix("dunst", "blau", 0.0, 0.0)
	grade(1.03, 1.14, 1.2, 0.36)
	# tief und mit Himmel im Bild: der Würfel sitzt unten, oben ist Platz für den blauen Himmel
	shot(-34, -6, 14, 20, 0.66, 0.74, 3.0, Vector2(0, 0.95), Vector2(0, 1.05))
	_push = 0.3
	await _at(5.86)
	await twist_best(cam_dir(-26, 22), true)
	await _at(6.25)
	_blue_sky(0.8)
	await _at(6.4)
	say("Du bist Gott.", 2.0, 0.2, 0.3)
	await _at(6.95)
	_miez_cameo(1.65)
	# ---------------------------------------------------------------- Montage (8,8 – 26,1 s)
	_push = 0.5
	_whips.append(8.8)
	await _at(8.8)
	level(12, 2)
	_blue_sky(0.0)
	grade(1.02, 1.08, 1.12, 0.3)
	shot(58, 74, 28, 30, 0.6, 0.5, 1.8)
	caps("WÄLDER", 1.3)
	_cue("beat")
	await twist_best(cam_dir(66, 30), true)
	_whips.append(10.6)
	await _at(10.6)
	level(16, 1)
	grade(1.02, 1.08, 1.1, 0.3)
	shot(200, 214, 42, 36, 0.56, 0.48, 1.8)
	caps("FISCHE", 1.3)
	_cue("beat")
	await twist_best(cam_dir(207, 38))
	_whips.append(12.4)
	await _at(12.4)
	level(19, 0)
	grade(1.02, 1.08, 1.1, 0.3)
	shot(124, 138, 30, 32, 0.58, 0.5, 1.8)
	caps("LANDGANG", 1.3)
	_cue("beat")
	await twist_best(cam_dir(131, 31))
	# ---------------------------------------------------------------- Zeit der Riesen (14,2 – 16,8 s)
	_whips.append(14.2)
	await _at(14.2)
	await _riesen()
	# ---------------------------------------------------------------- Meteor (16,8 – 18,7 s)
	await _at(16.8)
	await _meteor_beat()
	# ---------------------------------------------------------------- Danach: Säugetiere (18,7 – 20,6 s)
	await _at(18.7)
	level(21, 5)
	grade(0.3, 1.0, 0.6, 0.6)
	grade(1.02, 1.08, 1.1, 0.3, 0.7)
	shot(30, 46, 34, 32, 0.6, 0.5, 1.9)
	caps("DANACH: SÄUGETIERE", 1.4)
	_cue("dawn")
	await _at(18.8)
	await twist_best(cam_dir(38, 33))
	# ---------------------------------------------------------------- Affen (20,6 – 22,4 s)
	_whips.append(20.6)
	await _at(20.6)
	await _affen()
	# ---------------------------------------------------------------- Menschen (22,4 – 24,2 s)
	_whips.append(22.4)
	await _at(22.4)
	level(24, 0)
	grade(1.02, 1.08, 1.1, 0.3)
	shot(-40, -28, 42, 48, 0.5, 0.44, 1.8)
	_push = 0.8
	caps("MENSCHEN", 1.3)
	_cue("beat")
	twist_move([2, -1, -1], cam_dir(-34, 45))
	# ---------------------------------------------------------------- Dörfer und Städte (24,2 – 26,1 s)
	_whips.append(24.2)
	await _at(24.2)
	level(27, 4)
	grade(1.02, 1.08, 1.1, 0.3)
	shot(150, 164, 44, 48, 0.5, 0.4, 1.9)
	_push = 0.7
	caps("DÖRFER UND STÄDTE", 1.4)
	_cue("beat")
	await twist_best(cam_dir(157, 46))
	# ---------------------------------------------------------------- Die fertige Welt (26,1 – 29,6 s)
	await _at(26.1)
	level(30, 1)
	world.set_era("vollendet", 0.0)
	world.set_rest(3, 3)
	flash(Color("#fff0d0"), 0.45, 0.45)
	_cue("hero")
	grade(1.0, 1.06, 1.08, 0.28)
	_push = 0.0
	shot(-20, 30, 28, 23, 0.5, 0.42, 3.6, Vector2(0, 0.3), Vector2(0, 0.3), -1.2)
	await _at(26.25)
	say("Erschaffe deine Welt –\nTag für Tag.", 2.6, 0.25, 0.35, 84)
	# ---------------------------------------------------------------- Abspann mit Aufruf (29,6 – 34,6 s)
	await _at(29.6)
	_cue("end")
	var tw := create_tween()
	tw.tween_property(_end, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	shot(30, 60, 24, 24, 0.84, 0.95, 5.0)
	_god.scale = Vector2.ONE * 0.6
	var gt := create_tween()
	gt.tween_property(_god, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _at(30.15)
	_cue("meow")
	_god.set_expression("happy")
	_god.react("hop")
	_wave_god(_god)
	await _at(31.2)
	_cue("cta")
	var cta: Control = _end.get_meta("cta")
	var ct := create_tween()
	for i in 2:
		ct.tween_property(cta, "scale", Vector2.ONE * 1.07, 0.18).set_trans(Tween.TRANS_SINE)
		ct.tween_property(cta, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE)
	await _at(32.8)
	_god.react("hop")
	# kein Abblenden: der Abspann steht bis zum letzten Bild (Schleife und Vorschaubild bleiben erkennbar)
	await _at(END_T)
	_write_cues()
	get_tree().quit()


func _write_cues() -> void:
	if _cue_path == "":
		return
	var f := FileAccess.open(_cue_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"end": END_T, "cues": _cues, "whips": _whips}, "  "))
		f.close()


## Der Himmel wird in dur Sekunden blau (Akt 3, wie mit den Algen) und kräftiger als im Spiel (kleiner Bildschirm).
func _blue_sky(dur: float) -> void:
	world.set_era_mix("dunst", "blau", 1.0, dur)
	var m: Dictionary = world._custom_moods.get("era_mix", {})
	if not m.is_empty():
		m["top"] = Color("#2b63bd")
		m["mid"] = Color("#86b6e6")
		m["low"] = Color("#d3e3ee")
		m["sat"] = 1.12
		m["con"] = 1.08
		m["vig"] = 0.34
		if dur <= 0.0:
			world._apply_mood(m)
	grade(1.02, 1.06, 1.08, 0.3, maxf(dur, 0.01))
	_cue("sky")


func _miez_cameo(hold: float) -> void:
	_cue("meow")
	_cameo.set_expression("happy")
	var tw := create_tween()
	tw.tween_property(_cameo, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _cameo.react("hop"))
	tw.tween_interval(0.2)
	for i in 2:
		tw.tween_property(_cameo, "rotation", deg_to_rad(-8.0), 0.2).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_cameo, "rotation", deg_to_rad(8.0), 0.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_cameo, "rotation", 0.0, 0.15)
	tw.tween_interval(maxf(hold - 1.25, 0.05))
	tw.tween_property(_cameo, "scale", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func _wave_god(g: Control) -> void:
	var tw := create_tween()
	for i in 3:
		tw.tween_property(g, "rotation", deg_to_rad(-7.0), 0.22).set_trans(Tween.TRANS_SINE)
		tw.tween_property(g, "rotation", deg_to_rad(7.0), 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(g, "rotation", 0.0, 0.2).set_trans(Tween.TRANS_SINE)


# =============================================================================
# Zeit der Riesen und Meteor (nur im Trailer: Saurier aus einfachen Formen, eigener Meteor)
# =============================================================================

const DINO_LEVEL := 14
const DINO_BOARD := 2

func _riesen() -> void:
	level(DINO_LEVEL, DINO_BOARD)
	_blue_sky(0.0)                   # Urzeit: Urwald-Modelle, blauer Himmel, keine Sonnenscheibe
	grade(1.02, 1.1, 1.14, 0.32)
	_push = 0.0
	_spawn_dinos()
	shot(22, 34, 20, 16, -0.12, -0.26, 2.6)
	if _dino_center != null:
		_focus = _dino_center
		_focus_w = 0.9
	caps("ZEIT DER RIESEN", 1.9)
	_cue("beat")
	_stomp_next = _t + 0.25


func _meteor_beat() -> void:
	# eigene Einstellung: weit, tief, mit viel Himmel; der Stein zieht eine Spur quer über den Himmel
	_cue("cut")
	grade(1.0, 1.1, 1.12, 0.34)
	shot(10, 16, 14, 15, 0.46, 0.42, 1.9, Vector2(0, 0.8), Vector2(0, 0.8))
	_focus = null
	caps("DER METEOR", 0.65)
	var target := Vector3(0, Balance.CUBE_HALF + FieldView.TOP, 0)
	var fid := -1
	if not _dinos.is_empty():
		fid = int(_dinos[0]["fid"])
		var fv: FieldView = world.views.get(fid)
		if fv != null:
			target = fv.global_position + fv.world_normal() * (FieldView.TOP + 0.05)
	# Start oben links im Bild (aus der wirklichen Kamera gerechnet), dann schräg hinunter auf die Riesen
	var b := world.rig.global_transform.basis
	var start := target + b.y * 2.2 - b.x * 1.0 + b.z * 0.4
	var rock := _meteor_rock()
	world.cube_root.add_child(rock)
	_props.append(rock)
	rock.global_position = start
	var dir := (target - start).normalized()
	var ax_y := -dir
	var ax_x := ax_y.cross(Vector3.UP).normalized()
	var streak: MeshInstance3D = rock.get_meta("streak")
	streak.global_transform = Transform3D(Basis(ax_x, ax_y, ax_x.cross(ax_y)), start + ax_y * 1.8)
	_cue("meteor")
	var pre: Dictionary = (World.MOODS["abend"] as Dictionary).duplicate()
	pre["top"] = Color("#24365c")
	pre["mid"] = Color("#8a7a8c")
	pre["low"] = Color("#e09a6a")
	world._custom_moods["pre"] = pre
	world.hold_mood("pre", 0.7)
	grade(0.95, 1.12, 1.1, 0.42, 0.7)
	var fly := 0.8
	var tw := create_tween()
	tw.tween_property(rock, "global_position", target, fly).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _at(16.8 + fly)
	# Einschlag: weißer Blitz, Beben, der Himmel glüht rot, Asche, die Riesen fallen
	_cue("impact")
	var trail: CPUParticles3D = rock.get_meta("trail")
	trail.emitting = false
	trail.reparent(world.cube_root)
	_props.append(trail)
	rock.queue_free()
	flash(Color.WHITE, 1.0, 0.45)
	tint(Color("#ff8a50"), 0.35, 0.25)
	world.rig.shake(1.6)
	var m: Dictionary = (World.MOODS["glut"] as Dictionary).duplicate()
	m["top"] = Color("#2a0e0a")
	m["mid"] = Color("#9c3a1c")
	m["low"] = Color("#ff8a3a")
	m["ash"] = 1.0
	m["haze"] = 0.35
	m["clouds"] = 1.8
	m["sun_c"] = Color("#ff9a5a")
	m["fill_c"] = Color("#c85a3a")
	world._custom_moods["impact"] = m
	world.hold_mood("impact", 0.35)
	var light := OmniLight3D.new()
	light.light_color = Color("#ffb070")
	light.omni_range = 5.0
	light.light_energy = 10.0
	world.cube_root.add_child(light)
	_props.append(light)
	light.global_position = target + Vector3.UP * 0.6
	var lt := create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.9)
	lt.tween_callback(light.queue_free)
	if fid >= 0:
		var fv2: FieldView = world.views.get(fid)
		if fv2 != null:
			fv2.burst(Color("#ff8a3d"))
			world._dust(fv2)
		for f in Game.state.fields:
			var fd: FieldData = f
			if fd.n == Vector3i(0, 1, 0) and fd.id != fid:
				var ov: FieldView = world.views.get(fd.id)
				if ov != null:
					ov.pulse_light(Color("#ff7a3a"), 0.9, 0.8)
	world._sparks(target + Vector3.UP * 0.2, target + Vector3.UP * 1.4, Color("#ff8a3d"), 18)
	var ash := _ash_cloud(target)
	world.cube_root.add_child(ash)
	_props.append(ash)
	_dinos_fall()
	await _at(16.8 + fly + 0.35)
	# der dunkle Moment: alles wird still und grau
	grade(0.62, 1.05, 0.55, 0.62, 0.7)
	tint(Color("#ff8a50"), 0.15, 0.7)
	await _at(18.62)
	tint(Color.WHITE, 0.0, 0.05)


func _meteor_rock() -> Node3D:
	var rock := Node3D.new()
	var core := MeshInstance3D.new()
	core.mesh = Models.sphere_mesh(0.16)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color("#ffd6a0")
	cm.emission_enabled = true
	cm.emission = Color("#ffb060")
	cm.emission_energy_multiplier = 4.0
	core.material_override = cm
	rock.add_child(core)
	var glow := MeshInstance3D.new()
	glow.mesh = Look.quad(2.2)
	glow.material_override = Look.mote(Color(1.0, 0.45, 0.1, 0.95))
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rock.add_child(glow)
	var p := CPUParticles3D.new()
	p.amount = 160
	p.lifetime = 0.55
	p.local_coords = false
	p.mesh = Look.quad(0.42)
	p.material_override = Look.mote(Color(1.0, 0.62, 0.25, 0.9), true)
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.15
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1))
	sc.add_point(Vector2(1, 0))
	p.scale_amount_curve = sc
	var gr := Gradient.new()
	gr.set_color(0, Color(1.0, 0.85, 0.55, 1.0))
	gr.set_color(1, Color(0.6, 0.22, 0.1, 0.0))
	p.color_ramp = gr
	p.emitting = true
	rock.add_child(p)
	rock.set_meta("trail", p)
	# leuchtender Schweif (Kegel nach hinten, zum Ende durchsichtig)
	var streak := MeshInstance3D.new()
	var cm2 := CylinderMesh.new()
	cm2.top_radius = 0.02
	cm2.bottom_radius = 0.2
	cm2.height = 3.6
	cm2.radial_segments = 12
	cm2.rings = 1
	streak.mesh = cm2
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(0.9, 0.25, 0.05, 0.0), Color(1.0, 0.45, 0.1, 0.7), Color(1.0, 0.85, 0.45, 1.0)])
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	sm.albedo_texture = gt
	streak.material_override = sm
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rock.add_child(streak)
	rock.set_meta("streak", streak)
	return rock


func _ash_cloud(at: Vector3) -> Node3D:
	var root := Node3D.new()
	var smoke := CPUParticles3D.new()
	smoke.amount = 70
	smoke.lifetime = 1.6
	smoke.one_shot = true
	smoke.explosiveness = 0.85
	smoke.local_coords = false
	smoke.mesh = Look.quad(0.7)
	smoke.material_override = Look.mote(Color(0.25, 0.2, 0.18, 0.75), true)
	smoke.direction = Vector3.UP
	smoke.spread = 70.0
	smoke.gravity = Vector3(0, 0.2, 0)
	smoke.initial_velocity_min = 0.8
	smoke.initial_velocity_max = 2.2
	smoke.damping_min = 1.5
	smoke.damping_max = 2.5
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 2.0
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	gr.colors = PackedColorArray([Color(1.0, 0.6, 0.3, 1.0), Color(0.35, 0.28, 0.25, 0.9), Color(0.2, 0.18, 0.18, 0.0)])
	smoke.color_ramp = gr
	smoke.emitting = true
	root.add_child(smoke)
	var ash := CPUParticles3D.new()
	ash.amount = 90
	ash.lifetime = 2.5
	ash.local_coords = false
	ash.mesh = Look.quad(0.05)
	ash.material_override = Look.mote(Color(0.55, 0.5, 0.48, 0.85), true)
	ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ash.emission_box_extents = Vector3(2.4, 0.2, 2.4)
	ash.position = Vector3(0, 2.6, 0)
	ash.gravity = Vector3(0, -0.5, 0)
	ash.initial_velocity_min = 0.0
	ash.initial_velocity_max = 0.2
	ash.preprocess = 0.6
	ash.emitting = true
	root.add_child(ash)
	root.position = at
	root.top_level = false
	return root


func _spawn_dinos() -> void:
	_dinos.clear()
	# auf der Oberseite: zwei große und ein junger Langhals auf Wiese, Wald oder Erde (keine Weidetiere)
	var top: Array = []
	for f in Game.state.fields:
		var fd: FieldData = f
		if fd.n == Vector3i(0, 1, 0) and fd.kind in [FieldData.MEADOW, FieldData.FOREST, FieldData.EMPTY, FieldData.FERN, FieldData.MOSS]:
			top.append(fd)
	top.sort_custom(func(a: FieldData, b: FieldData) -> bool: return Vector2(a.p.x, a.p.z).length() < Vector2(b.p.x, b.p.z).length())
	# [Größe, Blickrichtung in der Welt (Grad, 28 = im Profil zur Kamera), Lage auf dem Feld]
	var specs := [[1.0, 44.0, Vector3(-0.1, 0, 0.05)], [0.85, 190.0, Vector3(0.08, 0, -0.1)], [0.55, 36.0, Vector3(0.2, 0, 0.22)]]
	for i in specs.size():
		if top.is_empty():
			break
		var fd: FieldData = top[mini(i, top.size() - 1)]
		var v: FieldView = world.views[fd.id]
		var node := _sauropod(i)
		var sp: Array = specs[i]
		node.position = Vector3(0, FieldView.TOP, 0) + (sp[2] as Vector3)
		var pb := v.global_transform.basis.orthonormalized().inverse()
		node.basis = pb * Basis(Vector3.UP, deg_to_rad(float(sp[1]))) * Basis.from_scale(Vector3.ONE * 1.9 * float(sp[0]))
		v.add_child(node)
		var focus := Node3D.new()
		focus.position = Vector3(0, 0.14, 0)
		node.add_child(focus)
		_dinos.append({"node": node, "fid": fd.id, "phase": float(i) * 1.3, "base": node.position, "focus": focus,
			"fallen": false, "size": float(sp[0])})
	_dino_center = Node3D.new()
	world.cube_root.add_child(_dino_center)
	_props.append(_dino_center)
	_place_dino_center()


func _update_dinos(delta: float) -> void:
	for d in _dinos:
		var dd: Dictionary = d
		var obj: Variant = dd["node"]
		if not is_instance_valid(obj) or bool(dd["fallen"]):
			continue
		var node := obj as Node3D
		dd["phase"] = float(dd["phase"]) + delta
		var ph: float = dd["phase"]
		var step := ph * 5.2
		var fwd := node.basis.x.normalized()
		var bob := absf(sin(step)) * 0.012 * float(dd["size"])
		node.position = (dd["base"] as Vector3) + fwd * (0.06 * ph) + Vector3(0, bob, 0)
		node.rotation.z = 0.03 * sin(step)
		var legs: Array = node.get_meta("legs")
		for i in legs.size():
			var hip := legs[i] as Node3D
			var off := PI if i == 1 or i == 2 else 0.0
			hip.rotation.z = 0.5 * sin(step * 0.5 + off)
		var neck: Node3D = node.get_meta("neck")
		neck.rotation.z = 0.1 * sin(ph * 1.6) + 0.05 * sin(step)
		neck.rotation.y = 0.18 * sin(ph * 0.8)
		var tail: Node3D = node.get_meta("tail")
		tail.rotation.y = 0.25 * sin(ph * 2.1)
	_place_dino_center()
	# Stampfen: die Kamera bebt leicht mit jedem Schritt des großen Sauriers
	if not _dinos.is_empty() and not bool(_dinos[0]["fallen"]) and _t >= _stomp_next and _t < 16.8:
		world.rig.shake(0.32)
		_cue("stomp")
		_stomp_next = _t + PI / 5.2 * 2.0


func _place_dino_center() -> void:
	if _dino_center == null or not is_instance_valid(_dino_center) or _dinos.is_empty():
		return
	var c := Vector3.ZERO
	var n := 0
	for d in _dinos:
		var f: Variant = (d as Dictionary)["focus"]
		if is_instance_valid(f):
			c += (f as Node3D).global_position
			n += 1
	if n > 0:
		_dino_center.global_position = c / float(n)


func _dinos_fall() -> void:
	for d in _dinos:
		var dd: Dictionary = d
		var node: Variant = dd["node"]
		if not is_instance_valid(node):
			continue
		dd["fallen"] = true
		var n := node as Node3D
		var tw := create_tween()
		tw.tween_interval(0.12 + 0.1 * float(_dinos.find(d)))
		tw.tween_property(n, "rotation:x", 1.45, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(n, "position:y", n.position.y - 0.02, 0.45)
		for mm in n.get_meta("mats"):
			var mat := mm as StandardMaterial3D
			var t2 := create_tween()
			t2.tween_interval(0.2)
			t2.tween_property(mat, "albedo_color", Color(0.22, 0.2, 0.19), 0.9)


func _dino_mat(c: Color, mats: Array) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	mats.append(m)
	return m


## Ein Langhals-Saurier aus Kugeln und Zylindern (grün-braun, dunkler Rücken, heller Bauch, Beine zum Stampfen).
func _sauropod(variant: int) -> Node3D:
	var root := Node3D.new()
	var mats: Array = []
	var skins := [Color("#56622a"), Color("#6e5526"), Color("#4f6a2c")]
	var skin: Color = skins[variant % skins.size()]
	var m_skin := _dino_mat(skin, mats)
	var m_back := _dino_mat(skin.darkened(0.5), mats)
	var m_belly := _dino_mat(skin.lerp(Color("#d8c58a"), 0.55), mats)
	var m_eye := _dino_mat(Color("#141414"), mats)
	var body := Models.sphere(root, 0.075, skin, Vector3(0, 0.13, 0), m_skin)
	body.scale = Vector3(1.6, 0.9, 0.95)
	var ridge := Models.sphere(root, 0.07, skin, Vector3(-0.005, 0.158, 0), m_back)
	ridge.scale = Vector3(1.5, 0.55, 0.62)
	var belly := Models.sphere(root, 0.06, skin, Vector3(0, 0.108, 0), m_belly)
	belly.scale = Vector3(1.45, 0.62, 0.82)
	var legs: Array = []
	for sx in [1.0, -1.0]:
		for sz in [1.0, -1.0]:
			var hip := Node3D.new()
			hip.position = Vector3(0.058 * sx, 0.115, 0.042 * sz)
			root.add_child(hip)
			Models.cyl(hip, 0.02, 0.024, 0.115, skin, Vector3(0, -0.115, 0), 10, Vector3.ZERO, m_skin)
			var foot := Models.sphere(hip, 0.026, skin, Vector3(0.004, -0.112, 0), m_back)
			foot.scale = Vector3(1.2, 0.5, 1.1)
			legs.append(hip)
	root.set_meta("legs", legs)
	var neck := Node3D.new()
	neck.position = Vector3(0.09, 0.15, 0)
	root.add_child(neck)
	root.set_meta("neck", neck)
	var pts := [Vector3(0.0, 0.0, 0), Vector3(0.03, 0.036, 0), Vector3(0.05, 0.078, 0), Vector3(0.064, 0.12, 0),
		Vector3(0.074, 0.158, 0), Vector3(0.084, 0.19, 0)]
	for i in pts.size():
		var r := lerpf(0.036, 0.017, float(i) / float(pts.size() - 1))
		Models.sphere(neck, r, skin, pts[i], m_skin)
		var top := Models.sphere(neck, r * 0.8, skin, (pts[i] as Vector3) + Vector3(-0.006, r * 0.35, 0), m_back)
		top.scale = Vector3(1.0, 0.7, 0.8)
	var head := Models.sphere(neck, 0.024, skin, Vector3(0.102, 0.203, 0), m_skin)
	head.scale = Vector3(1.6, 0.85, 0.9)
	for s in [-1.0, 1.0]:
		Models.sphere(neck, 0.006, skin, Vector3(0.11, 0.212, 0.016 * s), m_eye)
	var tail := Node3D.new()
	tail.position = Vector3(-0.1, 0.125, 0)
	root.add_child(tail)
	root.set_meta("tail", tail)
	var tp := [Vector3(0, 0, 0), Vector3(-0.036, -0.014, 0), Vector3(-0.07, -0.032, 0), Vector3(-0.1, -0.05, 0),
		Vector3(-0.128, -0.066, 0), Vector3(-0.152, -0.078, 0), Vector3(-0.172, -0.086, 0)]
	for i in tp.size():
		var r2 := lerpf(0.042, 0.008, float(i) / float(tp.size() - 1))
		Models.sphere(tail, r2, skin, tp[i], m_skin)
		if i < tp.size() - 2:
			var tt := Models.sphere(tail, r2 * 0.75, skin, (tp[i] as Vector3) + Vector3(0, r2 * 0.4, 0), m_back)
			tt.scale = Vector3(1.0, 0.6, 0.7)
	root.set_meta("mats", mats)
	return root


# =============================================================================
# Affen (nur im Trailer: kleine Primaten aus Kugeln und Zylindern, vor den Menschen)
# =============================================================================

func _affen() -> void:
	level(22, 3)
	grade(1.02, 1.08, 1.12, 0.3)
	_push = 0.0
	_spawn_apes()
	shot(-28, -16, 44, 40, -0.15, -0.3, 1.8)
	if not _apes.is_empty():
		_focus = _apes[0]["node"]
		_focus_w = 0.8
	caps("AFFEN", 1.3)
	_cue("beat")


func _spawn_apes() -> void:
	_apes.clear()
	var top: Array = []
	for f in Game.state.fields:
		var fd: FieldData = f
		if fd.n == Vector3i(0, 1, 0) and fd.kind in [FieldData.FOREST, FieldData.BIGFOREST, FieldData.MEADOW]:
			top.append(fd)
	if top.is_empty():
		return
	top.sort_custom(func(a: FieldData, b: FieldData) -> bool:
		var ka := 0 if a.kind == FieldData.FOREST else 1
		var kb := 0 if b.kind == FieldData.FOREST else 1
		if ka != kb:
			return ka < kb
		return Vector2(a.p.x, a.p.z).length() < Vector2(b.p.x, b.p.z).length())
	# Lage auf dem Feld (Feld-Raum, Rand: zwischen den Bäumen gut sichtbar), Drehung, Größe, Bewegung
	var specs := [[0, Vector3(0.3, 0, 0.32), 0.6, 1.0, "chest"], [0, Vector3(-0.3, 0, 0.34), 1.2, 0.85, "hop"],
		[1, Vector3(0.28, 0, 0.3), 0.3, 0.65, "sit"], [1, Vector3(-0.1, 0, 0.36), 1.6, 0.9, "wave"]]
	for i in specs.size():
		var sp: Array = specs[i]
		var fd: FieldData = top[mini(int(sp[0]), top.size() - 1)]
		var v: FieldView = world.views[fd.id]
		var node := _ape()
		node.position = Vector3(0, FieldView.TOP, 0) + (sp[1] as Vector3)
		node.rotation.y = float(sp[2])
		node.scale = Vector3.ONE * 2.2 * float(sp[3])
		v.add_child(node)
		_apes.append({"node": node, "base": node.position, "mode": sp[4], "ph": float(i) * 0.7})


func _update_apes() -> void:
	for a in _apes:
		var ad: Dictionary = a
		if not is_instance_valid(ad["node"]):
			continue
		var n := ad["node"] as Node3D
		var ph := _t * 7.0 + float(ad["ph"])
		var arms: Array = n.get_meta("arms")
		match str(ad["mode"]):
			"chest":
				for i in arms.size():
					(arms[i] as Node3D).rotation.x = (1.0 if i == 0 else -1.0) * (0.9 + 0.35 * sin(ph * 1.6 + PI * i))
					(arms[i] as Node3D).rotation.z = 1.2
				n.position = (ad["base"] as Vector3) + Vector3(0, 0.004 * absf(sin(ph * 1.6)), 0)
			"hop":
				n.position = (ad["base"] as Vector3) + Vector3(0, 0.03 * absf(sin(ph * 0.8)), 0)
				for i in arms.size():
					(arms[i] as Node3D).rotation.z = 2.4 + 0.3 * sin(ph * 0.8)
			"wave":
				(arms[0] as Node3D).rotation.z = 2.6
				(arms[0] as Node3D).rotation.x = 0.5 * sin(ph * 1.2)
				n.position = (ad["base"] as Vector3) + Vector3(0, 0.003 * absf(sin(ph)), 0)
			_:
				n.rotation.z = 0.08 * sin(ph * 0.5)


func _ape() -> Node3D:
	var root := Node3D.new()
	var fur := Color("#4a3122")
	var face := Color("#dcb68e")
	var m_fur := Models.mat(fur, 0.9)
	var m_dark := Models.mat(fur.darkened(0.3), 0.9)
	var m_face := Models.mat(face, 0.8)
	var m_eye := Models.mat(Color("#121212"), 0.4)
	var body := Models.sphere(root, 0.042, fur, Vector3(0, 0.07, 0), m_fur)
	body.scale = Vector3(0.95, 1.2, 0.9)
	var belly := Models.sphere(root, 0.03, face, Vector3(0.018, 0.062, 0), m_face)
	belly.scale = Vector3(0.7, 1.1, 0.9)
	Models.sphere(root, 0.032, fur, Vector3(0.01, 0.13, 0), m_fur)
	var muzzle := Models.sphere(root, 0.025, face, Vector3(0.03, 0.127, 0), m_face)
	muzzle.scale = Vector3(0.7, 0.95, 1.1)
	for s in [-1.0, 1.0]:
		Models.sphere(root, 0.006, fur, Vector3(0.044, 0.14, 0.011 * s), m_eye)
		Models.sphere(root, 0.01, face, Vector3(0.004, 0.138, 0.031 * s), m_face)
	var arms: Array = []
	for s in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(0.006, 0.1, 0.04 * s)
		root.add_child(sh)
		Models.cyl(sh, 0.011, 0.013, 0.085, fur, Vector3(0, -0.085, 0), 8, Vector3.ZERO, m_fur)
		Models.sphere(sh, 0.013, fur, Vector3(0, -0.088, 0), m_dark)
		sh.rotation.z = 0.25
		arms.append(sh)
		var hip := Node3D.new()
		hip.position = Vector3(-0.004, 0.035, 0.022 * s)
		root.add_child(hip)
		Models.cyl(hip, 0.012, 0.012, 0.035, fur, Vector3(0, -0.035, 0), 8, Vector3.ZERO, m_fur)
		Models.sphere(hip, 0.013, fur, Vector3(0.008, -0.034, 0), m_dark)
	root.set_meta("arms", arms)
	return root
