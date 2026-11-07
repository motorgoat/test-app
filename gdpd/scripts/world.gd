class_name World
extends Node3D
## Würfel, Felder, Kamera, Eingabe und Effekte (Verschmelzen, Meteorit).
## Wischen auf dem Würfel dreht eine Reihe (wie bei einem echten Zauberwürfel),
## Wischen daneben dreht die Ansicht. Antippen zeigt die Feld-Info.

signal field_tapped(fid: int)
signal preview_changed(info: Dictionary)   # {} = keine Vorschau
signal merged(fid: int, points: int, combo: int, stage: int)
signal disaster_shown(kind: String, fid: int)
signal face_completed(fid: int, points: int, stage: int)
signal miss_shown(fid: int, count: int, why: String)   # why: "", "repeat" (nur zurückgedreht) oder "spent" (zusammen aufgestiegene Reihe wieder gebildet)
signal twist_state(on: bool)               # eine Drehung läuft (oben erscheint der Abbrechen-Streifen)
signal cancel_hover(on: bool)              # Finger ist über dem Abbrechen-Streifen
signal bolt_drawn(fid: int, row: Array)    # Blitz über eine Reihe gezogen
signal tutorial_tap                        # im vorgeführten ersten Zug auf den Würfel getippt
signal deltas_shown(list: Array, gain: int)   # [{"field": id, "change": "up"|"down"|"lost"|"new"}]
# gdpd: was die Welt gerade zeigt (die Oberfläche antwortet mit Pillen, Bannern und Hinweisen)
signal war_shown(fids: Array, faith: int)      # Kirchen im Krieg, Glaube (negativ)
signal smog_shown(w: int, withered: Array)     # Smog in dieser Drehung, verwelkte Felder
signal wish_done_shown(fid: int, faith: int)   # Wunsch erfüllt (Herzen, Glaube fliegt nach oben)
signal wish_made_shown(fid: int)               # neuer Wunsch an diesem Feld
signal income_shown(amount: int)               # Glaube pro Drehung von fertigen Feldern
signal punish_shown(kind: String, fid: int, cost: int)   # Gewitter oder Flut
signal still_shown(info: Dictionary)     # stille Reihe: {"why", "kind", "fields", "diag", "next", "grew", "miss", "visible"} (siehe GameState._still_rows)

const ALL_AXES = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

var rig: CameraRig
var cube_root: Node3D
var cubies: Array = []          # Node3D mit meta "pos" (Vector3i)
var views: Dictionary = {}      # Feld-ID -> FieldView
var selected := -1
var animating := false

# Eingabe
var _mode := ""                 # "", "pending", "pending_tap", "twist", "orbit", "hold_orbit", "blocked"
var _press_pos := Vector2.ZERO
var _press_ms := 0
var _last_move_ms := 0
var _hit_field := -1
var _hit_point := Vector3.ZERO
var _tw_axis := 0
var _tw_layer := 0
var _tw_sign := 1               # Drehsinn um die positive Achse
var _tw_screen_dir := Vector2.RIGHT
var _tw_px_per_quarter := 100.0
var _tw_angle := 0.0
var _tw_display := 0.0
var _tw_quarter := 0
var _tw_row: Array = []         # die drei Felder, über die gewischt wird
var _tw_last_pos := Vector2.ZERO
var cancel_zone: Control = null # Abbrechen-Streifen oben (ganze Breite): Finger dort loslassen = Drehung abbrechen
var _over_cancel := false
var _tw_live := false           # die Drehung kommt vom Finger (nicht vorgeführt / Screenshot)
var _tw_auto := false           # Finger neben dem Würfel gehalten: die Scheibe dreht von selbst weiter
var _tw_out_t := 0.0            # so lange liegt der Finger schon neben dem Würfel / am Rand
var _demo_tw: Tween = null      # Tutorial: die Hand-Vorführung (beim Antippen sofort abbrechen)
var input_locked := false       # Tag 1 „Schau zu!“: Die eine Vorführung läuft, Finger auf dem Würfel zählen nicht
var tour_auto := false          # nur die Screenshot-Tour darf Züge ohne Finger spielen (auto_twist)
var _touched_state: GameState = null   # in diesem Spiel (GameState) hat der Spieler den Würfel schon berührt
var _tw_gift := false           # die laufende Drehung ist die Vorführung von Tag 1 (kostet keine Drehung)
var _still_gen := 0             # Markierungen stiller Reihen: gehören zu dieser Runde
var _still_views: Array = []
var bolt_mode := false          # Blitz gewählt: Wischen zeichnet die Reihe statt zu drehen
var tool_mode := false          # ein Werkzeug ist gewählt: Tippen zielt auf Felder (nicht auf Wunsch-Blasen)
var _bolt_row: Array = []
var _pivot: Node3D
var _touches: Dictionary = {}
var _pinch_dist := 0.0
var _two_center := Vector2.ZERO   # zwei Finger: Mittelpunkt (schwenken) …
var _two_angle := 0.0             # … und Winkel (drehen)
var _postfx: CanvasLayer
var _post_mat: ShaderMaterial    # Tilt-Shift, Farbstimmung, Vignette, Bildblitz
var _env: Environment
var _backdrop_mat: ShaderMaterial
var _tour := false               # Screenshot-Tour: feste Qualität, keine Kamera-Drift, ruhige Umgebung
var _idle := 0.0
var _hinted := false
var _hint_views: Array = []


func _ready() -> void:
	_setup_environment()
	rig = CameraRig.new()
	add_child(rig)
	cube_root = Node3D.new()
	add_child(cube_root)
	Game.new_game_started.connect(rebuild)
	Game.state_changed.connect(_on_state_changed)
	Game.round_resolved.connect(_on_round_resolved)
	Game.tutorial_bloom.connect(bloom)
	Game.day_started.connect(_on_day_mood.unbind(1))
	Game.build_started.connect(_on_day_mood.unbind(1))
	Game.day_won.connect(_on_day_won_mood)
	Game.new_game_started.connect(_on_day_mood)
	Game.new_game_started.connect(_night_clear)
	Game.overnight_growth.connect(_on_overnight)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_tour = true
	_add_backdrop()
	_add_life()
	rebuild()
	set_mood(_day_mood(), 0.0)


## Umgebung (GDPD_GRAFIK.md 4/5): Hintergrund als Farbe plus Himmels-Ebene an der Kamera (ein Sky-Shader mit
## TIME würde jedes Bild die Radiance neu rechnen), Umgebungslicht als Farbe, ACES, Glühen nur für Emissives.
func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#d9dcd8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9fb3cc")
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.12
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = false
	env.fog_light_color = Color("#b9bcbf")
	env.fog_density = 0.0
	env.fog_sky_affect = 0.0
	_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Miniatur-Unschärfe über der 3D-Welt, unter der Oberfläche
	_postfx = CanvasLayer.new()
	_postfx.layer = 0
	add_child(_postfx)
	var layer := _postfx
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/tilt_shift.gdshader")
	rect.material = sm
	_post_mat = sm
	layer.add_child(rect)


# =============================================================================
# Aufbau und Aktualisierung
# =============================================================================

func rebuild() -> void:
	_hint_views.clear()
	_still_views.clear()
	_still_gen += 1
	input_locked = false
	_hinted = false
	_idle = 0.0
	for c in cube_root.get_children():
		c.queue_free()
	cubies.clear()
	views.clear()
	selected = -1
	animating = false
	_mode = ""
	var gs := Game.state
	var by_pos := {}
	var body_mesh := Models.rounded_box_mesh(Vector3(0.98, 0.98, 0.98), 0.05, 2)
	var body_mat := Look.bedrock()
	for x in [-1, 0, 1]:
		for y in [-1, 0, 1]:
			for z in [-1, 0, 1]:
				var p := Vector3i(x, y, z)
				if p == Vector3i.ZERO:
					continue
				var cb := Node3D.new()
				cb.position = Vector3(p)
				cb.set_meta("pos", p)
				cube_root.add_child(cb)
				var mi := MeshInstance3D.new()
				mi.mesh = body_mesh
				mi.material_override = body_mat
				cb.add_child(mi)
				cubies.append(cb)
				by_pos[_cubie_key(p)] = cb
	for f in gs.fields:
		var cb: Node3D = by_pos[_cubie_key(f.p)]
		var v := FieldView.new()
		cb.add_child(v)
		v.transform = Transform3D(_face_basis(f.n), Vector3(f.n) * 0.47)
		v.build(f)
		views[f.id] = v
	refresh_all()


static func _is_center_cubie(p: Vector3i) -> bool:
	var c := 0
	for a in 3:
		if p[a] != 0:
			c += 1
	return c == 1


static func _cubie_key(p: Vector3i) -> int:
	return (p.x + 1) + 3 * (p.y + 1) + 9 * (p.z + 1)


static func _face_basis(n: Vector3i) -> Basis:
	var a := GameState.axis_of(n)
	var y := Vector3(n)
	var x := Vector3(GameState.unit((a + 1) % 3, 1))
	return Basis(x, y, x.cross(y))


func _on_state_changed() -> void:
	if animating or _mode == "twist":
		return
	refresh_all()


func refresh_all(gs: GameState = null, skip: Dictionary = {}) -> void:
	if gs == null:
		gs = Game.state
	var smog_ids := smog_fields(gs)
	# Gefahr (Feuer, Kriegsfront): Tiere und Menschen auf dem Feld und daneben laufen weg (FieldView.set_alarm)
	var danger := {}
	for f in gs.fields:
		if f.burning or gs.front.has(f.id):
			danger[f.id] = true
	for f in gs.fields:
		var v: FieldView = views.get(f.id)
		if v == null or skip.has(f.id):
			continue
		if _night.has(f.id) and gs == Game.state:
			var old_f: FieldData = f.copy()
			old_f.kind = int(_night[f.id])      # „Über Nacht gewachsen“: bis zur Welle noch die Art von gestern
			v.refresh(old_f)
		else:
			v.refresh(f)
		v.set_polluted(smog_ids.has(f.id))
		var alarm: bool = smog_ids.has(f.id) and f.kind != FieldData.INDUSTRY
		for g in gs.neighbors(f):
			if danger.has((g as FieldData).id):
				alarm = true
		v.set_alarm(alarm)
		if gs.v8:
			var st := gs.field_state8(f)
			st["flood_risk"] = gs.flood_warn.has(gs.face_index(f)) and bool(st.get("wet", false)) \
				and [FieldData.EMPTY, FieldData.MEADOW, FieldData.FIELD, FieldData.HUT].has(f.kind)
			v.apply_state8(st)
		else:
			v.apply_state8({})
		v.set_selected(f.id == selected)
		var w := gs.wish_at(f.id)
		if w.is_empty():
			v.set_wish("")
		else:
			v.set_wish(str(GameState.WISH_ICON.get(str(w["type"]), "wish")), int(w["left"]))
	_water_edges()
	_update_mood()


# =============================================================================
# „Über Nacht gewachsen“ (GDPD_BALANCE_2.md 5.6): Unter der Ziel-Karte steht noch die Welt von gestern; nach „Los!“
# wachsen die unteren Felder in einer Welle (von oben nach unten auf dem Bildschirm) in ihre neue Art.
# =============================================================================

var _slice_last := Vector2i(-9, -9)   # Scheibe des letzten Zugs (Achse, Ebene)
var _slice_same := false
var _slice_noted := false
var _night := {}                # Feld → Art von gestern (bis die Welle es wachsen lässt)
var night_waved := 0            # so viele Felder ist die letzte Welle gewachsen (Tour-Prüfung)
var _night_gen := 0


func _night_clear() -> void:
	_night_gen += 1
	_night = {}


func _on_overnight(info: Dictionary) -> void:
	_night_gen += 1
	_night = {}
	night_waved = 0
	for c in info.get("changes", []):
		var cd: Dictionary = c
		_night[int(cd["field"])] = int(cd["from"])
	refresh_all()


func night_pending() -> bool:
	return not _night.is_empty()


## Die Welle abspielen (DayUI nach „Los!“). Blockiert nichts: Eingaben gehen sofort, ein Zug beendet die Welle.
func overnight_wave() -> void:
	if _night.is_empty():
		return
	_night_gen += 1
	var gen := _night_gen
	var order: Array = []
	for fid in _night:
		var sc := field_screen(int(fid))
		var vis := bool(sc["visible"])
		var p: Vector2 = sc["pos"]
		order.append([0 if vis else 1, p.y + p.x * 0.25, int(fid)])
	order.sort()
	var i := 0
	for o in order:
		var oa: Array = o
		var fid := int(oa[2])
		if int(oa[0]) == 1:
			_night_grow(fid, gen, false)        # hinten: ohne Effekt, gleich die neue Art
			continue
		get_tree().create_timer(0.25 + 0.075 * float(i)).timeout.connect(_night_grow.bind(fid, gen, true))
		i += 1
	if i > 0:
		_wind_kick = 2.5


func _night_grow(fid: int, gen: int, fx: bool) -> void:
	if gen != _night_gen or not _night.has(fid) or Game.state == null:
		return
	_night.erase(fid)
	night_waved += 1
	var v: FieldView = views.get(fid)
	if v == null:
		return
	v.refresh(Game.state.fields[fid])
	if fx:
		v.pulse_light(Color("#e6f7b0"), 0.7)
		_sparks(v.global_position + v.world_normal() * 0.12, v.global_position + v.world_normal() * 0.7, Color("#f4f0a8"), 3)


## Steht noch etwas von gestern da, wenn gespielt wird: sofort die neue Art (ohne Welle).
func _night_flush() -> void:
	if _night.is_empty():
		return
	_night_gen += 1
	for fid in _night.keys():
		_night.erase(fid)
		var v: FieldView = views.get(int(fid))
		if v != null and Game.state != null:
			v.refresh(Game.state.fields[int(fid)])


## Smog: Industrie und ihre Nachbarn liegen im grauen Dunst (solange die Waage im Smog steht).
func smog_fields(gs: GameState) -> Dictionary:
	var out := {}
	if gs == null or not gs.smog():
		return out
	for f in gs.fields:
		if (f as FieldData).kind != FieldData.INDUSTRY:
			continue
		out[(f as FieldData).id] = true
		for g in gs.neighbors(f):
			out[(g as FieldData).id] = true
	return out


## Wunsch-Blase unter dem Finger? (Bildschirmposition) → Feld-ID oder -1.
func wish_hit(pos: Vector2) -> int:
	var best := -1
	var best_d := 40.0
	for fid in views:
		var v: FieldView = views[fid]
		if not v.wish_visible():
			continue
		var wp := v.wish_anchor_world_pos()
		if rig.cam.is_position_behind(wp):
			continue
		var d := rig.cam.unproject_position(wp).distance_to(pos)
		if d < best_d:
			best_d = d
			best = int(fid)
	return best


## Bildschirmposition der Wunsch-Blase eines Felds. {"pos", "visible"}
func wish_screen(fid: int) -> Dictionary:
	var v: FieldView = views.get(fid)
	if v == null:
		return {"pos": Vector2.ZERO, "visible": false}
	var wp := v.wish_anchor_world_pos()
	return {"pos": rig.cam.unproject_position(wp), "visible": v.wish_visible() and not rig.cam.is_position_behind(wp)}


# =============================================================================
# Wahl („Dein Wille geschehe“): die Reihe leuchtet, über dem neuen Feld steht ein „?“
# =============================================================================

var _choice_views: Array = []
var _choice_badges: Array = []


func show_choice(info: Dictionary) -> void:
	clear_choice()
	var gs := Game.state
	if gs == null or not info.has("action"):
		return
	var k := int(info["kind"])
	var targets := {}
	for i in info.get("fields", []):
		targets[int(i)] = true
	var main := int(info.get("field", -1))
	if main >= 0:
		targets[main] = true
	var lit := targets.duplicate()
	var sim: Dictionary = gs.simulate(info["action"])
	var res: Dictionary = sim["result"]
	for e in res["events"]:
		var t := str(e["type"])
		if int(e.get("from", -1)) != k:
			continue
		if t == "face":
			for i in e["fields"]:
				lit[int(i)] = true
		elif t == "merge":
			lit[int(e["field"])] = true
			for o in e["others"]:
				lit[int(o)] = true
	for fid in lit:
		var v: FieldView = views.get(int(fid))
		if v == null:
			continue
		v.set_highlight(true)
		_choice_views.append(v)
		if not targets.has(fid) and main >= 0 and views.has(main):
			var mv: FieldView = views[main]
			_sparks(v.global_position + v.world_normal() * 0.3, mv.global_position + mv.world_normal() * 0.35, Color("#ffd23f"), 4)
	for fid in targets:
		var v: FieldView = views.get(int(fid))
		if v == null:
			continue
		v.set_badge("help")
		_choice_badges.append(v)
	if main >= 0 and views.has(main):
		(views[main] as FieldView).burst(Color("#ffd23f"))
		if not bool(field_screen(main)["visible"]):
			focus_field(main)
	_buzz(16)


func clear_choice() -> void:
	for v in _choice_views:
		if is_instance_valid(v):
			(v as FieldView).set_highlight(false)
	for v in _choice_badges:
		if is_instance_valid(v):
			(v as FieldView).set_badge("")
	_choice_views.clear()
	_choice_badges.clear()


## Strafe gewählt und ein Ziel angetippt: diese Felder leuchten, bis man noch einmal tippt.
var _pick_ids: Array = []


func set_pick(ids: Array) -> void:
	for i in _pick_ids:
		var v: FieldView = views.get(int(i))
		if v != null:
			v.set_highlight(false)
	_pick_ids = ids.duplicate()
	for i in _pick_ids:
		var v: FieldView = views.get(int(i))
		if v != null:
			v.set_highlight(true)



# =============================================================================
# Himmel, Umgebungsleben und Stimmungen (GDPD_GRAFIK.md 4–6)
# =============================================================================

## Himmel als Ebene an der Kamera: Verlauf, Dunst, ziehende Wolken (ersetzt die Kugel-Wolken).
func _add_backdrop() -> void:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(90, 46)
	q.mesh = qm
	_backdrop_mat = ShaderMaterial.new()
	_backdrop_mat.shader = load("res://shaders/backdrop.gdshader")
	_backdrop_mat.set_shader_parameter("n_fbm", Look.fbm())
	q.material_override = _backdrop_mat
	q.position = Vector3(0, 0, -70)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.cam.add_child(q)
	rig.cam.far = 120.0


var _pollen: CPUParticles3D
var _birds: MultiMeshInstance3D
var _bird_t := 0.0
var _bird_phase: Array = []
var _life_on := true             # Pollen und Vögel (Stimmung und Qualität schalten sie)
var _wind_kick := 0.0            # Nachwippen nach dem Wachsen (klingt ab)


## Pollen im Licht und ein kleiner Vogelschwarm, der ab und zu durchs Bild zieht. Je ein Draw-Call.
func _add_life() -> void:
	_pollen = CPUParticles3D.new()
	_pollen.amount = 36
	_pollen.lifetime = 9.0
	_pollen.preprocess = 9.0
	_pollen.mesh = Look.quad(1.0)
	_pollen.material_override = Look.mote(Color(1.0, 0.93, 0.74, 0.55), true)
	_pollen.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	_pollen.emission_sphere_radius = 2.15
	_pollen.direction = Vector3(0, 1, 0)
	_pollen.spread = 180.0
	_pollen.gravity = Vector3(0.01, 0.012, 0)
	_pollen.initial_velocity_min = 0.02
	_pollen.initial_velocity_max = 0.06
	_pollen.scale_amount_min = 0.012
	_pollen.scale_amount_max = 0.024
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.25, Color(1, 1, 1, 1))
	fade.add_point(0.75, Color(1, 1, 1, 1))
	_pollen.color_ramp = fade
	_pollen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pollen)
	# Vögel: ein V je Vogel, Flügelschlag über die Instanz-Skalierung
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sgn in [-1.0, 1.0]:
		var sx: float = sgn
		st.add_vertex(Vector3(0, 0, 0.05))
		st.add_vertex(Vector3(sx * 0.5, 0.22, -0.08))
		st.add_vertex(Vector3(0, 0, -0.08))
	st.generate_normals()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = st.commit()
	mm.instance_count = 6
	_birds = MultiMeshInstance3D.new()
	_birds.multimesh = mm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.22, 0.22, 0.25, 0.85)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_birds.material_override = bm
	_birds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_birds.visible = false
	rig.cam.add_child(_birds)
	for i in 6:
		_bird_phase.append(Vector3(randf_range(-0.9, 0.9) + float(i % 3) * 0.5, randf_range(-0.5, 0.5) - float(i) * 0.12, randf() * TAU))
	_bird_t = 6.0


func _update_life(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	# Böen: alle paar Sekunden ein weicher Windstoß, nach dem Wachsen kurzes Nachwippen
	_wind_kick = maxf(0.0, _wind_kick - delta * 1.6)
	var g := maxf(0.0, sin(t * 0.61) * sin(t * 0.23 + 1.0))
	Look.set_wind(1.0 + 0.8 * g * g + _wind_kick)
	if _pollen != null:
		_pollen.emitting = _life_on
		_pollen.visible = _life_on
	# Vögel: alle 30 s ziehen sie in 9 s quer durchs Bild (hinter dem Würfel)
	if _birds == null:
		return
	_bird_t += delta
	var cycle := fmod(_bird_t, 30.0)
	var flying := _life_on and not _tour and cycle < 9.0
	_birds.visible = flying
	if not flying:
		return
	var k := cycle / 9.0
	var base := Vector3(lerpf(-3.8, 3.8, k), 2.3 + sin(k * PI) * 0.7, -14.0)
	for i in 6:
		var ph: Vector3 = _bird_phase[i]
		var flap := cos(t * 9.0 + ph.z)
		var b := Basis.from_scale(Vector3(0.16, 0.16 * (0.3 + 0.7 * flap), 0.16))
		_birds.multimesh.set_instance_transform(i, Transform3D(b, base + Vector3(ph.x * 0.5 - float(i) * 0.18, ph.y * 0.5 + sin(t * 1.3 + ph.z) * 0.05, 0.0)))


## Stimmungen: Sonne, Füll-Licht, Umgebung, Himmel, Nebel und Farbstimmung. set_mood blendet weich hinüber.
const MOODS := {
	"tag": {"sun": Vector3(-36, -48, 0), "sun_c": Color("#ffe2b8"), "sun_e": 1.25, "fill_c": Color("#a9c2e8"), "fill_e": 0.55,
		"amb_c": Color("#9fb3cc"), "amb_e": 0.83, "exp": 1.00, "glow": 0.6,
		"top": Color("#7891ad"), "mid": Color("#c7d5e0"), "low": Color("#ede1cc"), "cloud": Color("#fffaf2"), "clouds": 1.0, "sunglow": 0.35,
		"fog": 0.0, "fog_c": Color("#c9ced2"), "warm": Vector3(1.04, 1.0, 0.93), "cool": Vector3(0.93, 0.98, 1.06), "sat": 1.06, "con": 1.06,
		"vig": 0.3, "life": 1.0},
	"morgen": {"sun": Vector3(-26, -58, 0), "sun_c": Color("#ffd6a3"), "sun_e": 1.20, "fill_c": Color("#9db8e6"), "fill_e": 0.60,
		"amb_c": Color("#a4b4cf"), "amb_e": 0.83, "exp": 1.00, "glow": 0.65,
		"top": Color("#8aa3c0"), "mid": Color("#dcdcd6"), "low": Color("#f3d9b8"), "cloud": Color("#fff1e0"), "clouds": 0.9, "sunglow": 0.6,
		"fog": 0.0, "fog_c": Color("#d8d4cc"), "warm": Vector3(1.06, 1.0, 0.9), "cool": Vector3(0.92, 0.97, 1.08), "sat": 1.03, "con": 1.03,
		"vig": 0.3, "life": 1.0},
	"abend": {"sun": Vector3(-22, -40, 0), "sun_c": Color("#ffc18a"), "sun_e": 1.25, "fill_c": Color("#93a3d8"), "fill_e": 0.55,
		"amb_c": Color("#a8a2bd"), "amb_e": 0.81, "exp": 0.98, "glow": 0.8,
		"top": Color("#6f7fa6"), "mid": Color("#d8c4bc"), "low": Color("#f2c49a"), "cloud": Color("#ffe3c8"), "clouds": 1.0, "sunglow": 0.7,
		"fog": 0.0, "fog_c": Color("#d6c2b4"), "warm": Vector3(1.08, 0.99, 0.88), "cool": Vector3(0.92, 0.95, 1.08), "sat": 1.04, "con": 1.04,
		"vig": 0.32, "life": 1.0},
	"weiter": {"sun": Vector3(-30, -50, 0), "sun_c": Color("#ffd29c"), "sun_e": 1.29, "fill_c": Color("#a0b6e2"), "fill_e": 0.57,
		"amb_c": Color("#a8b0c8"), "amb_e": 0.83, "exp": 1.00, "glow": 0.75,
		"top": Color("#7a8fb0"), "mid": Color("#dcd3c8"), "low": Color("#f4d6b0"), "cloud": Color("#fff2e2"), "clouds": 1.0, "sunglow": 0.55,
		"fog": 0.0, "fog_c": Color("#d8d0c4"), "warm": Vector3(1.06, 1.0, 0.9), "cool": Vector3(0.93, 0.97, 1.07), "sat": 1.05, "con": 1.03,
		"vig": 0.3, "life": 1.0},
	"regen": {"sun": Vector3(-52, -30, 0), "sun_c": Color("#dfe4ea"), "sun_e": 0.65, "fill_c": Color("#a3b4cc"), "fill_e": 0.72,
		"amb_c": Color("#93a0b2"), "amb_e": 1.04, "exp": 0.92, "glow": 0.5,
		"top": Color("#6d7a88"), "mid": Color("#aab3bb"), "low": Color("#c6c9c8"), "cloud": Color("#e3e6e8"), "clouds": 1.6, "sunglow": 0.0,
		"fog": 0.012, "fog_c": Color("#a7afb6"), "warm": Vector3(1.0, 1.0, 0.98), "cool": Vector3(0.94, 0.98, 1.05), "sat": 0.92, "con": 1.02,
		"vig": 0.34, "life": 0.0},
	"smog": {"sun": Vector3(-40, -44, 0), "sun_c": Color("#ead9ad"), "sun_e": 0.90, "fill_c": Color("#aaa99c"), "fill_e": 0.49,
		"amb_c": Color("#a5a191"), "amb_e": 0.85, "exp": 0.94, "glow": 0.5,
		"top": Color("#8b8a7c"), "mid": Color("#bdb8a3"), "low": Color("#cfc4a4"), "cloud": Color("#d9d3bf"), "clouds": 1.3, "sunglow": 0.2,
		"fog": 0.008, "fog_c": Color("#b5ad93"), "warm": Vector3(1.05, 1.0, 0.88), "cool": Vector3(0.97, 0.98, 1.0), "sat": 0.82, "con": 1.02,
		"vig": 0.36, "life": 0.0},
	"krieg": {"sun": Vector3(-24, -30, 0), "sun_c": Color("#ffb282"), "sun_e": 1.16, "fill_c": Color("#9c8aa8"), "fill_e": 0.49,
		"amb_c": Color("#a6928c"), "amb_e": 0.79, "exp": 0.96, "glow": 0.8,
		"top": Color("#7a6f75"), "mid": Color("#c7aa9c"), "low": Color("#e0b58e"), "cloud": Color("#e9d2c2"), "clouds": 1.2, "sunglow": 0.5,
		"fog": 0.008, "fog_c": Color("#b59a8a"), "warm": Vector3(1.08, 0.97, 0.88), "cool": Vector3(0.95, 0.95, 1.04), "sat": 0.94, "con": 1.04,
		"vig": 0.42, "life": 0.0},
	"vollendet": {"sun": Vector3(-26, -52, 0), "sun_c": Color("#ffd08a"), "sun_e": 1.38, "fill_c": Color("#9fb5e6"), "fill_e": 0.60,
		"amb_c": Color("#b0aec4"), "amb_e": 0.87, "exp": 1.02, "glow": 1.0,
		"top": Color("#7f95b8"), "mid": Color("#e6d8c6"), "low": Color("#f6d3a2"), "cloud": Color("#fff0dc"), "clouds": 1.0, "sunglow": 0.8,
		"fog": 0.0, "fog_c": Color("#e0d2c0"), "warm": Vector3(1.08, 1.0, 0.88), "cool": Vector3(0.93, 0.96, 1.07), "sat": 1.08, "con": 1.04,
		"vig": 0.3, "life": 1.0},
}

var mood := ""                   # aktuelle Stimmung (Name)
var _mood_now: Dictionary = {}   # gerade angewandte Werte (Ausgang der nächsten Überblendung)
var _mood_from: Dictionary = {}
var _mood_to: Dictionary = {}
var _mood_tw: Tween
var _mood_hold := ""             # kurze Ereignis-Stimmung (Regen, Krieg) hat Vorrang
var _won_mood := ""              # nach dem Sieg: „weiter“ (Weiterbauen) oder „vollendet“ (Woche geschafft)


func set_mood(name: String, dur: float = 2.0) -> void:
	if not MOODS.has(name):
		return
	if name == mood and dur > 0.0:
		return
	mood = name
	_mood_to = MOODS[name]
	if _mood_tw != null and _mood_tw.is_valid():
		_mood_tw.kill()
	if dur <= 0.0 or _mood_now.is_empty():
		_apply_mood(_mood_to)
		return
	_mood_from = _mood_now.duplicate()
	_mood_tw = create_tween()
	_mood_tw.tween_method(_mood_step, 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _mood_step(k: float) -> void:
	var m := {}
	for key in _mood_to:
		var a: Variant = _mood_from.get(key, _mood_to[key])
		var b: Variant = _mood_to[key]
		if b is Color:
			m[key] = (a as Color).lerp(b as Color, k)
		elif b is Vector3:
			m[key] = (a as Vector3).lerp(b as Vector3, k)
		else:
			m[key] = lerpf(float(a), float(b), k)
	_apply_mood(m)


func _apply_mood(m: Dictionary) -> void:
	_mood_now = m.duplicate()
	if rig != null and rig.key != null:
		rig.key.rotation_degrees = m["sun"]
		rig.key.light_color = m["sun_c"]
		rig.key.light_energy = float(m["sun_e"])
		rig.fill.light_color = m["fill_c"]
		rig.fill.light_energy = float(m["fill_e"])
	_env.ambient_light_color = m["amb_c"]
	_env.ambient_light_energy = float(m["amb_e"])
	_env.tonemap_exposure = float(m["exp"])
	_env.glow_intensity = float(m["glow"])
	_env.background_color = m["mid"]
	var fog := float(m["fog"])
	_env.fog_enabled = fog > 0.001
	_env.fog_density = fog
	_env.fog_light_color = m["fog_c"]
	if _backdrop_mat != null:
		_backdrop_mat.set_shader_parameter("top_c", m["top"])
		_backdrop_mat.set_shader_parameter("mid_c", m["mid"])
		_backdrop_mat.set_shader_parameter("low_c", m["low"])
		_backdrop_mat.set_shader_parameter("cloud_c", m["cloud"])
		_backdrop_mat.set_shader_parameter("clouds", float(m["clouds"]))
		_backdrop_mat.set_shader_parameter("sun_glow", float(m["sunglow"]))
	if _post_mat != null:
		_post_mat.set_shader_parameter("warm", m["warm"])
		_post_mat.set_shader_parameter("cool", m["cool"])
		_post_mat.set_shader_parameter("saturation", float(m["sat"]))
		_post_mat.set_shader_parameter("contrast", float(m["con"]))
		_post_mat.set_shader_parameter("vignette", float(m["vig"]))
	Look.set_sky((m["mid"] as Color).lerp(m["top"] as Color, 0.35))
	_life_on = float(m["life"]) > 0.5 and Look.quality >= 1


## Welche Stimmung gilt gerade? Ereignis > Smog > Sieg > Weiterbauen > Tag der Woche.
func _day_mood() -> String:
	if _mood_hold != "":
		return _mood_hold
	var gs := Game.state
	if gs != null and gs.smog():
		return "smog"
	if _won_mood != "":
		return _won_mood
	if gs != null and gs.day_free_build:
		return "weiter"
	if Game.in_day():
		var d := Game.day_no
		if d <= 2:
			return "morgen"
		if d >= 6:
			return "abend"
	return "tag"


func _update_mood(dur: float = 2.0) -> void:
	set_mood(_day_mood(), dur)


func _on_day_mood() -> void:
	_won_mood = ""
	_update_mood()


func _on_day_won_mood(info: Dictionary) -> void:
	_won_mood = "vollendet" if bool(info.get("world_complete", false)) else "weiter"
	_update_mood(2.5)


## Kurze Ereignis-Stimmung (Regen, Krieg); hold("") kehrt zur normalen Stimmung zurück.
func hold_mood(name: String, dur: float = 0.8) -> void:
	_mood_hold = name
	_update_mood(dur)


## Wasser: Schaum nur dort, wo kein Nachbarwasser auf derselben Seite liegt (Seen statt Pfützen).
func _water_edges() -> void:
	var water: Array = []
	for fid in views:
		var v: FieldView = views[fid]
		if v.get_kind() == FieldView.K_WATER:
			water.append(v)
	for vv in water:
		var v: FieldView = vv
		var mask := Vector4.ONE
		for ww in water:
			if ww == vv:
				continue
			var lp: Vector3 = v.to_local((ww as FieldView).global_position)
			if absf(lp.y) > 0.2 or Vector2(lp.x, lp.z).length() > 1.2:
				continue
			if absf(lp.x) > absf(lp.z):
				if lp.x > 0.0:
					mask.y = 0.0
				else:
					mask.w = 0.0
			elif lp.z > 0.0:
				mask.z = 0.0
			else:
				mask.x = 0.0
		v.set_water_edges(mask)


## Regensymbole auf den Feldern, wo Gießen etwas bringt (nur solange man den Regen gewählt hat).
func show_rain_spots(on: bool) -> void:
	show_targets("rain" if on else "")


## Ziele eines Bonus leuchten: "rain" = jedes Feld, das man gießen kann (blauer Ring; wo es eine Reihe
## fertig macht oder löscht, zusätzlich die Wolke), "bolt" = alle Eckfelder (gelber Ring), "" = aus.
func show_targets(kind: String) -> void:
	var gs := Game.state
	var tg := {}
	var col := Style.WATER
	if gs != null and kind == "rain":
		tg = gs.rain_targets()
	elif gs != null and kind == "bolt":
		col = Style.SUN
		for f in gs.fields:
			if not gs.corner_diagonal(f).is_empty():
				tg[f.id] = "corner"
	elif gs != null and kind == "monsoon":
		col = Style.MONSOON
		for f in gs.fields:
			tg[f.id] = "face"
	elif gs != null and kind == "strike":
		# Gewitter: Vorschläge statt alles einzufärben. Industrie (dort hilft es am meisten) kräftig mit Abzeichen,
		# andere fertige Felder (Platz machen) zart. Antippen geht trotzdem auf jedem Feld mit etwas darauf.
		col = Color("#8a63d2")
		for f in gs.fields:
			var sk: int = (f as FieldData).kind
			if sk == FieldData.INDUSTRY:
				tg[f.id] = "strike_best"
			elif (f as FieldData).is_finished():
				tg[f.id] = "strike_soft"
		if tg.is_empty():
			for f in gs.fields:
				if (f as FieldData).kind != FieldData.EMPTY:
					tg[f.id] = "any"
	elif gs != null and kind == "flood":
		# Flut: alle Felder der Seiten, auf denen es Stadt gibt
		col = Style.WATER_DEEP
		for f in gs.fields:
			if gs.can_bonus("flood", f) == "" or gs.faith < Balance.FLOOD_COST:
				var any := false
				for g in gs.face_fields((f as FieldData).n):
					if (g as FieldData).is_civilisation():
						any = true
				if any:
					tg[f.id] = "face"
	for fid in views:
		var v: FieldView = views[fid]
		var t: String = str(tg.get(int(fid), ""))
		v.set_target(t != "", col.lerp(Color.WHITE, 0.55) if t == "strike_soft" else col)
		if t == "useful" or t == "fire":
			v.set_badge("rain")
		elif t == "strike_best":
			v.set_badge("strike")
		else:
			v.set_badge("")


## Kurz wackeln: Hier geht der gewählte Bonus nicht.
func nudge(fid: int) -> void:
	var v: FieldView = views.get(fid)
	if v != null:
		v.nudge()
	_buzz(20)


## Nach dem Tutorial: Die neuen Wiesen wachsen nacheinander aus der Erde, die nächsten zuerst.
## Währenddessen ist die Eingabe gesperrt (animating); danach geht es sofort weiter.
var _bloom_cam := Vector3.ZERO
var _bloom_gen := 0


func bloom(ids: Array) -> void:
	_bloom_gen += 1
	var gen := _bloom_gen
	animating = true
	_clear_hint()
	select(-1)
	var gs := Game.state
	var order: Array = ids.duplicate()
	_bloom_cam = rig.cam.global_position
	order.sort_custom(_bloom_closer)
	await get_tree().create_timer(0.25).timeout
	for i in order:
		if gen != _bloom_gen or gs != Game.state:
			return
		var v: FieldView = views.get(int(i))
		if v != null:
			v.refresh(gs.fields[int(i)])
			v.burst(Color("#8fd162"))
		await get_tree().create_timer(0.035).timeout
	await get_tree().create_timer(0.45).timeout
	if gen != _bloom_gen or gs != Game.state:
		return
	animating = false
	refresh_all()


func _bloom_closer(a, b) -> bool:
	var va: FieldView = views.get(int(a))
	var vb: FieldView = views.get(int(b))
	if va == null or vb == null:
		return int(a) < int(b)
	return va.global_position.distance_squared_to(_bloom_cam) < vb.global_position.distance_squared_to(_bloom_cam)


func select(fid: int) -> void:
	if selected >= 0 and views.has(selected):
		views[selected].set_selected(false)
	selected = fid
	if fid >= 0 and views.has(fid):
		views[fid].set_selected(true)


var _perf_t := 0.0
var _perf_frames := 0
var _perf_done := false


func _process(delta: float) -> void:
	_update_life(delta)
	_update_post()
	_measure_quality(delta)
	rig.drift_enabled = not _tour and not Game.tutorial() and not input_locked and not animating and _mode == "" and not Game.busy
	if _mode == "" and not animating and not Game.busy and not Game.over:
		_idle += delta
		if (Game.tutorial() or _day_guided()) and _idle > 1.2 and not _hinted:
			_show_hint()
		elif Game.onboarding and not Game.tutorial() and _idle > Balance.ONBOARD_HINT_SECONDS and not _hinted:
			_show_free_hint()      # die ersten Minuten: nach einer Pause leuchtet die passende Reihe (ohne Text)
	else:
		_idle = 0.0
	# Auf dem Würfel halten (ohne Bewegen): danach dreht Ziehen die Ansicht statt einer Reihe
	if not Game.tutorial() and (_mode == "pending" or _mode == "pending_tap") and Time.get_ticks_msec() - _press_ms > int(Balance.HOLD_TO_ORBIT_SECONDS * 1000.0):
		_mode = "hold_orbit"
		_buzz(30)
		var tw := cube_root.create_tween()
		tw.tween_property(cube_root, "scale", Vector3.ONE * 0.96, 0.08)
		tw.tween_property(cube_root, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Finger neben dem Würfel (in Drehrichtung: links/rechts wie oben/unten) oder am Bildschirmrand gehalten:
	# die Scheibe dreht gleichmäßig von selbst weiter, Viertel für Viertel. Zurück auf den Würfel = stopp.
	if _mode == "twist" and _tw_live and _pivot != null:
		var raw := 0 if _over_cancel else _auto_side()
		if raw != 0:
			_tw_out_t += delta
		else:
			_tw_out_t = 0.0
		# erst nach kurzem Halten draußen (kein ungewolltes Extra-Viertel beim Loslassen)
		var side := raw if (_tw_auto or _tw_out_t >= Balance.TWIST_AUTO_DWELL_SECONDS) else 0
		_tw_auto = side != 0
		if _tw_auto:
			_press_pos -= _tw_screen_dir * float(side) * _tw_px_per_quarter / Balance.TWIST_AUTO_SECONDS * delta
			_update_twist(_tw_last_pos)
	if _mode == "twist" and _pivot != null:
		_tw_display = lerpf(_tw_display, _detent(_tw_angle), 1.0 - exp(-delta * Balance.TWIST_FOLLOW))
		var ax := Vector3.ZERO
		ax[_tw_axis] = 1.0
		_pivot.basis = Basis(ax, _tw_display)
	var cam_pos := rig.cam.global_position
	for fid in views:
		var v: FieldView = views[fid]
		var to_cam := (cam_pos - v.global_position).normalized()
		var facing := v.world_normal().dot(to_cam)
		v.set_labels_visible(facing > 0.2)
		v.set_detail(facing)


## Bildschirmposition eines Felds. {"pos": Vector2, "visible": bool}
func field_screen(fid: int) -> Dictionary:
	var v: FieldView = views.get(fid)
	if v == null:
		return {"pos": Vector2.ZERO, "visible": false}
	var wp := v.label_world_pos()
	var cam_pos := rig.cam.global_position
	var vis := not rig.cam.is_position_behind(wp) and v.world_normal().dot((cam_pos - wp).normalized()) > 0.1
	return {"pos": rig.cam.unproject_position(wp), "visible": vis}


func focus_field(fid: int) -> void:
	var v: FieldView = views.get(fid)
	if v != null:
		rig.focus(v.world_normal())


func set_postfx(on: bool) -> void:
	_postfx.visible = on


## Tilt-Shift folgt dem Würfel, die Unschärfe hängt von der Bildgröße ab (GDPD_GRAFIK.md 7.1).
func _update_post() -> void:
	if _post_mat == null or not _postfx.visible:
		return
	var win := get_window().size
	var vs := get_viewport().get_visible_rect().size
	var fy := 0.47
	if not rig.cam.is_position_behind(Vector3.ZERO) and vs.y > 0.0:
		fy = clampf(rig.cam.unproject_position(Vector3.ZERO).y / vs.y, 0.3, 0.7)
	_post_mat.set_shader_parameter("focus_y", fy)
	_post_mat.set_shader_parameter("blur_px", 0.0 if Look.quality == 0 else 0.0065 * float(win.x))


## Qualität: Die ersten Sekunden messen; ist das Handy zu langsam, gehen Pollen, Vögel, Post-Unschärfe und
## Schattenauflösung herunter (GDPD_GRAFIK.md A13). Die Tour bleibt auf „hoch“ (gleiche Bilder in der CI).
func _measure_quality(delta: float) -> void:
	if _perf_done or _tour:
		return
	_perf_t += delta
	if _perf_t < 1.0:
		return
	_perf_frames += 1
	if _perf_t < 4.0:
		return
	_perf_done = true
	var avg := (_perf_t - 1.0) / maxf(1.0, float(_perf_frames))
	if avg > 1.0 / 26.0:
		Look.quality = 0
		RenderingServer.directional_shadow_atlas_set_size(2048, true)
	elif avg > 1.0 / 40.0:
		Look.quality = 1
	if Look.quality < 2:
		_life_on = _life_on and Look.quality >= 1
		print("Grafik: Qualität %d (%.1f ms je Bild)" % [Look.quality, avg * 1000.0])


func focus_place(n: Vector3i) -> void:
	rig.focus(Vector3(n))


# =============================================================================
# Eingabe
# =============================================================================

## Während einer Drehung gehört der Finger dem Würfel: Bewegen und Loslassen kommen hier an, auch über
## Knöpfen der Leiste und über dem Abbrechen-Streifen oben (die Oberfläche würde sie sonst schlucken).
func _input(event: InputEvent) -> void:
	if _mode != "twist" or not _tw_live:
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _touches.size() < 2:
			_motion(mm.position, mm.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_release(mb.position)
			get_viewport().set_input_as_handled()


## App verliert den Fokus (Android: kurz pausiert): Das Loslassen kommt dann nicht mehr an.
## Ein angefangener Druck zählt nicht, eine Drehung unter dem Finger gleitet zurück.
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT:
		return
	_touches.clear()
	if _mode == "twist" and _tw_live:
		_cancel_drag()
	elif _mode in ["pending", "pending_tap", "orbit", "hold_orbit", "bolt"]:
		_set_bolt_row([])
		_mode = ""


func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		# „Schau zu!“: Während der Vorführung gehört der Würfel der Hand. Nichts davon zählt als Eingabe.
		_touches.clear()
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		if _touches.size() >= 2:
			_mark_touched()
			_cancel_drag()
			_pinch_dist = _touch_dist()
			_two_center = _touch_center()
			_two_angle = _touch_angle()
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var d := _touch_dist()
			if _pinch_dist > 1.0 and d > 1.0:
				rig.zoom(_pinch_dist / d)
			_pinch_dist = d
			# Zwei Finger verschieben: Würfel schwenken; zwei Finger drehen: Würfel um die Blickachse drehen
			var c := _touch_center()
			rig.orbit(c - _two_center, 0.0)
			_two_center = c
			var ang := _touch_angle()
			rig.roll(-wrapf(ang - _two_angle, -PI, PI))
			_two_angle = ang
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if _touches.size() < 2:
					_press(mb.position)
			else:
				_release(mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_mark_touched()
			rig.zoom(0.92)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_mark_touched()
			rig.zoom(1.08)
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _touches.size() < 2:
			_motion(mm.position, mm.relative)
		return
	if event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		_mark_touched()
		if mg.factor > 0.0:
			rig.zoom(1.0 / mg.factor)


func _touch_center() -> Vector2:
	var pts := _touches.values()
	if pts.size() < 2:
		return Vector2.ZERO
	return ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5


func _touch_angle() -> float:
	var pts := _touches.values()
	if pts.size() < 2:
		return 0.0
	return ((pts[1] as Vector2) - (pts[0] as Vector2)).angle()


func _touch_dist() -> float:
	var pts := _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


## Pulsiert die Scheibe, deren Drehung am meisten bringt (zwei Züge voraus).
## Gibt den Zug zurück ({} = keine Drehung bringt etwas).
## move: diese Drehung zeigen ({"axis", "layer", …}), sonst die beste (an den Tagen nach dem Ziel bewertet).
func show_hint(move: Dictionary = {}) -> Dictionary:
	_clear_hint()
	return _show_hint(move)


func _show_hint(move: Dictionary = {}) -> Dictionary:
	_hinted = true
	var best := move if not move.is_empty() else Game.state.best_move()
	# Tutorial: genau der vorgezeigte Zug leuchtet (derselbe in beiden Schritten, wie die Hand ihn zeigt)
	if Game.tutorial() and Game.tutorial_step <= 1:
		best = {"axis": 0, "layer": 1, "turns": 1, "points": 0, "steps": 1}
	elif _day_guided():
		var mv := Game.tutorial_move()
		best = {"axis": int(mv["axis"]), "layer": int(mv["layer"]), "turns": int(mv["turns"]), "points": 0, "steps": 1}
	if best.is_empty():
		return best
	for cb in _slice_cubies(int(best["axis"]), int(best["layer"])):
		for child in (cb as Node3D).get_children():
			if child is FieldView:
				(child as FieldView).set_hint(true)
				_hint_views.append(child)
	return best


## Tag 1 auf dem Tutorial-Brett, bis der Spieler seine erste eigene Wiese hat: Eine Scheibe, die eine Wiese wachsen
## lässt, leuchtet (nur Leuchten – sie bewegt sich nicht).
func _day_guided() -> bool:
	return Game.day_tutorial() and not input_locked and Game.state.goal_progress() <= Game.state.gift_twists \
		and not Game.tutorial_move().is_empty()


## Darf sich eine Scheibe ohne den Finger des Spielers bewegen? Nur für die eine Vorführung ganz am Anfang von
## Tag 1 (Tutorial-Brett): noch keine Drehung gezählt und der Spieler hat in diesem Spiel nichts berührt.
## Danach bewegt sich der Würfel nie mehr von selbst (Hilfe ist dann nur Leuchten, Text und der Tipp).
func can_self_move() -> bool:
	return Game.day_tutorial() and Game.state.twists == 0 and _touched_state != Game.state


## Gratis-Tipp in der Eingewöhnung: nur, wenn eine Drehung sofort etwas wachsen lässt.
func _show_free_hint() -> void:
	_hinted = true
	var best := Game.state.best_move()
	if best.is_empty() or int(best["steps"]) != 1:
		return
	for cb in _slice_cubies(int(best["axis"]), int(best["layer"])):
		for child in (cb as Node3D).get_children():
			if child is FieldView:
				(child as FieldView).set_hint(true)
				_hint_views.append(child)


func _clear_hint() -> void:
	_idle = 0.0
	_hinted = false
	for v in _hint_views:
		if is_instance_valid(v):
			(v as FieldView).set_hint(false)
	_hint_views.clear()


## Der Spieler hat den Würfel berührt (Tippen, Wischen, Ansicht drehen, zoomen): Ab jetzt bewegt sich in diesem
## Spiel keine Scheibe mehr ohne ihn (can_self_move).
func _mark_touched() -> void:
	_touched_state = Game.state


func _press(pos: Vector2) -> void:
	rig.poke()
	_mark_touched()
	# Tutorial: der erste Zug spielt sich selbst. Tippen startet ihn sofort.
	if Game.tutorial() and Game.tutorial_step == 0:
		tutorial_tap.emit()
		return
	if _mode == "twist" and not _tw_live:
		_abort_demo()        # die Hand führt gerade vor: sofort weg, derselbe Finger dreht gleich selbst
	if Game.has_choice() and bool(Game.pending_choice.get("mini", false)):
		Game.choose_default()
	_clear_hint()
	_press_pos = pos
	_press_ms = Time.get_ticks_msec()
	_last_move_ms = _press_ms
	rig.stop()
	var hit := _raycast(pos)
	if bolt_mode and not hit.is_empty() and not animating and not Game.busy and not Game.over:
		_mode = "bolt"
		_hit_field = int(hit["field"])
		_hit_point = hit["point"]
		_bolt_row = []
	elif not hit.is_empty() and not animating and not Game.busy and not Game.over:
		_mode = "pending"
		_hit_field = int(hit["field"])
		_hit_point = hit["point"]
	elif not hit.is_empty():
		_mode = "pending_tap"
		_hit_field = int(hit["field"])
	else:
		_mode = "orbit"


func _motion(pos: Vector2, rel: Vector2) -> void:
	var now := Time.get_ticks_msec()
	var dt := maxf(0.001, (now - _last_move_ms) / 1000.0)
	_last_move_ms = now
	match _mode:
		"pending":
			if pos.distance_to(_press_pos) > Balance.DRAG_START_PX:
				_begin_twist(pos - _press_pos)
				if _mode == "twist":
					_tw_live = true
					_update_twist(pos)
		"pending_tap":
			if pos.distance_to(_press_pos) > Balance.DRAG_START_PX:
				_mode = "blocked"
		"twist":
			_update_twist(pos)
		"bolt":
			if pos.distance_to(_press_pos) > Balance.DRAG_START_PX:
				_set_bolt_row(_drag_row(pos - _press_pos))
		"orbit", "hold_orbit":
			rig.orbit(rel, dt)


func _release(pos: Vector2) -> void:
	# Auf eine Wunsch-Blase getippt: zeigt das Feld mit dem Wunsch (die Blase schwebt über dem Feld)
	if not tool_mode and _mode in ["pending", "pending_tap", "orbit"] and pos.distance_to(_press_pos) <= Balance.DRAG_START_PX:
		var wf := wish_hit(pos)
		if wf >= 0:
			_mode = ""
			field_tapped.emit(wf)
			return
	match _mode:
		"pending", "pending_tap":
			if pos.distance_to(_press_pos) <= Balance.DRAG_START_PX:
				field_tapped.emit(_hit_field)
		"twist":
			if _over_cancel or _cancel_hit(pos):
				_tw_quarter = 0      # über dem Streifen losgelassen: die Scheibe gleitet zurück, kein Zug
			_finish_twist()
		"bolt":
			var row := _bolt_row
			_set_bolt_row([])
			if row.size() == 3:
				bolt_drawn.emit(_hit_field, row)
			elif pos.distance_to(_press_pos) <= Balance.DRAG_START_PX:
				field_tapped.emit(_hit_field)
		"orbit", "hold_orbit":
			if Time.get_ticks_msec() - _last_move_ms > 90:
				rig.stop()
	if _mode != "twist":
		_mode = ""


func _cancel_drag() -> void:
	if _mode == "twist":
		_tw_quarter = 0
		_finish_twist()
	_mode = ""


func _raycast(screen_pos: Vector2) -> Dictionary:
	var cam := rig.cam
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 100.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {}
	var col: Object = hit.get("collider")
	if col != null and col.has_meta("field_id"):
		return {"field": int(col.get_meta("field_id")), "point": hit["position"]}
	return {}


# =============================================================================
# Drehen per Wischen
# =============================================================================

func _begin_twist(drag: Vector2) -> void:
	_night_flush()
	_still_clear()
	var f: FieldData = Game.state.fields[_hit_field]
	var cam := rig.cam
	var s0 := cam.unproject_position(_hit_point)
	var best_t := Vector3i.ZERO
	var best_dot := 0.0
	var best_dir := Vector2.RIGHT
	var best_len := 100.0
	for a in 3:
		if f.n[a] != 0:
			continue
		var t := GameState.unit(a, 1)
		var st := cam.unproject_position(_hit_point + Vector3(t) * 0.5) - s0
		if st.length() < 2.0:
			continue
		var dd := drag.normalized().dot(st.normalized())
		if absf(dd) > absf(best_dot):
			best_dot = dd
			best_t = t
			best_dir = st.normalized()
			best_len = st.length() * 2.0
	if best_t == Vector3i.ZERO:
		_mode = "blocked"
		return
	var sgn := 1 if best_dot > 0.0 else -1
	var t_s := Vector3(best_t) * sgn
	var k := Vector3(f.n).cross(t_s)
	var ki := Vector3i(roundi(k.x), roundi(k.y), roundi(k.z))
	_tw_axis = GameState.axis_of(ki)
	_tw_sign = ki[_tw_axis]
	_tw_layer = f.p[_tw_axis]
	_tw_row = []
	for g in Game.state.fields:
		if g.n == f.n and g.p[_tw_axis] == _tw_layer:
			_tw_row.append(g.id)
	_tw_screen_dir = best_dir * sgn
	_tw_px_per_quarter = maxf(40.0, best_len * Balance.TWIST_FINGER_UNITS)
	_tw_angle = 0.0
	_tw_display = 0.0
	_tw_quarter = 0
	_pivot = Node3D.new()
	cube_root.add_child(_pivot)
	for cb in _slice_cubies(_tw_axis, _tw_layer):
		(cb as Node3D).reparent(_pivot, true)
	_mode = "twist"
	_over_cancel = false
	_tw_live = false
	_tw_auto = false
	_tw_out_t = 0.0
	_tw_last_pos = _press_pos
	select(-1)
	twist_state.emit(true)


## Die Reihe durch das angetippte Feld, die am besten zur Wischrichtung passt (für den Blitz).
func _drag_row(drag: Vector2) -> Array:
	var f: FieldData = Game.state.fields[_hit_field]
	var cam := rig.cam
	var s0 := cam.unproject_position(_hit_point)
	var best_axis := -1
	var best_dot := 0.0
	for a in 3:
		if f.n[a] != 0:
			continue
		var t := Vector3.ZERO
		t[a] = 0.5
		var st := cam.unproject_position(_hit_point + cube_root.global_transform.basis * t) - s0
		if st.length() < 2.0:
			continue
		var dd := absf(drag.normalized().dot(st.normalized()))
		if dd > best_dot:
			best_dot = dd
			best_axis = a
	if best_axis < 0:
		return []
	return Game.state.line_through(f, best_axis)


func _set_bolt_row(row: Array) -> void:
	for i in _bolt_row:
		var v: FieldView = views.get(int(i))
		if v != null:
			v.set_highlight(false)
	_bolt_row = row
	for i in _bolt_row:
		var v: FieldView = views.get(int(i))
		if v != null:
			v.set_highlight(true)


## Rastung: Nahe einer Vierteldrehung bleibt die Scheibe kleben, über die Hälfte zieht sie von selbst weiter.
func _detent(a: float) -> float:
	var q := PI * 0.5
	var n := roundf(a / q)
	var frac := (a - n * q) / q
	var y := pow(absf(frac) * 2.0, Balance.TWIST_DETENT)
	return (n + signf(frac) * y * 0.5) * q


func _update_twist(pos: Vector2) -> void:
	_tw_last_pos = pos
	# Finger über dem Abbrechen-Streifen? Dann zeigt die Vorschau nichts, Loslassen bricht ab
	var over := _cancel_hit(pos)
	if over != _over_cancel:
		_over_cancel = over
		cancel_hover.emit(over)
		if over:
			_tw_auto = false
			_buzz(18)
			_clear_preview()
		else:
			_tw_quarter = 99
	if _over_cancel:
		_tw_angle = 0.0      # Scheibe kehrt sichtbar zurück
		return
	var along := (pos - _press_pos).dot(_tw_screen_dir)
	_tw_angle = _tw_sign * along / _tw_px_per_quarter * PI * 0.5
	var q := roundi(_tw_angle / (PI * 0.5))
	if q != _tw_quarter:
		if _tw_auto and _tw_quarter != 99:
			_buzz(10)        # dreht sie von selbst weiter, spürt man jede Rastung
		_tw_quarter = q
		_show_preview(_norm_turns(q))


## Liegt der Finger auf dem Abbrechen-Streifen? Der Streifen geht über die ganze Breite oben,
## darum zählt alles bis zu seiner Unterkante (auch über den Bildschirmrand hinaus gezogen).
func _cancel_hit(pos: Vector2) -> bool:
	if cancel_zone == null or not is_instance_valid(cancel_zone) or not cancel_zone.is_visible_in_tree():
		return false
	var r := cancel_zone.get_global_rect()
	if r.size.y < 1.0:
		return false
	var slack := Balance.CANCEL_LEAVE_PX if _over_cancel else Balance.CANCEL_ENTER_PX
	var vs := get_viewport().get_visible_rect().size
	if r.position.y < vs.y * 0.4:
		return pos.y <= r.end.y + slack
	return r.grow(slack).has_point(pos)


## Läuft die Scheibe gerade von selbst weiter? +1 / -1 = Richtung entlang _tw_screen_dir, 0 = nein.
## Ja, wenn der Finger in Drehrichtung deutlich neben dem Würfel liegt (links/rechts wie oben/unten)
## oder nah am Bildschirmrand gehalten wird.
func _auto_side() -> int:
	var pos := _tw_last_pos
	var center := rig.cam.unproject_position(cube_root.global_transform.origin)
	var ext := _cube_extent(_tw_screen_dir, center)
	var margin := Balance.TWIST_AUTO_MARGIN_PX * (0.5 if _tw_auto else 1.0)   # kleine Hysterese, kein Flackern
	var f := (pos - center).dot(_tw_screen_dir)
	# neben dem Würfel erst, wenn die Hand schon fast ein Viertel gedreht hat
	var far_ok := _tw_auto or absf(_tw_angle) >= PI * 0.5 * Balance.TWIST_AUTO_MIN_QUARTER
	if far_ok and f > ext.y + margin:
		return 1
	if far_ok and f < ext.x - margin:
		return -1
	var along := (pos - _press_pos).dot(_tw_screen_dir)
	if absf(along) <= Balance.DRAG_START_PX:
		return 0
	var s := 1 if along > 0.0 else -1
	var ahead := pos + _tw_screen_dir * float(s) * Balance.TWIST_EDGE_PX
	var vs := get_viewport().get_visible_rect().size
	if ahead.x < 0.0 or ahead.y < 0.0 or ahead.x > vs.x or ahead.y > vs.y:
		return s
	return 0


## Wie weit der Würfel auf dem Bildschirm entlang dir reicht, gemessen vom Mittelpunkt: Vector2(min, max).
## Aus den 8 Würfelecken; die Projektion des Umrisses auf eine Richtung ist genau ihr Min/Max.
func _cube_extent(dir: Vector2, center: Vector2) -> Vector2:
	var cam := rig.cam
	var xf := cube_root.global_transform
	var lo := INF
	var hi := -INF
	for i in 8:
		var c := Vector3(float((i & 1) * 2 - 1), float(((i >> 1) & 1) * 2 - 1), float(((i >> 2) & 1) * 2 - 1)) * Balance.CUBE_HALF
		var wp := xf * c
		if cam.is_position_behind(wp):
			continue
		var d := (cam.unproject_position(wp) - center).dot(dir)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	if lo > hi:
		return Vector2.ZERO
	return Vector2(lo, hi)


## Kurz vibrieren – nur, wenn die Effekte an sind (Effekte aus = Bus „SFX“ stumm = auch keine Vibration).
func _buzz(ms: int) -> void:
	var b := AudioServer.get_bus_index("SFX")
	if b >= 0 and AudioServer.is_bus_mute(b):
		return
	Style.haptic(ms)


## Vierteldrehungen auf -1, 0, 1, 2 zurückführen (3 Viertel = 1 zurück, 4 = gar nichts).
static func _norm_turns(q: int) -> int:
	var m := ((q % 4) + 4) % 4
	return -1 if m == 3 else m


func _show_preview(q: int) -> void:
	if q == 0:
		_clear_preview()
		return
	var pv := Game.preview(_tw_axis, _tw_layer, q, _tw_row)
	var arranged: GameState = pv["arranged"]
	var lit := {}
	var mids := {}
	# Was eine Drehung bringt, zeigt nur das Tutorial. Gefahr zeigt die Vorschau immer.
	var lines: Array = arranged.lines(arranged.moved) if Game.tutorial() else []
	for line in lines:
		if not arranged.counts(line):
			continue      # stand schon da oder gerade zurückgedreht: wächst nicht
		for g in line:
			lit[(g as FieldData).id] = true
		var mid: FieldData = line[GameState.target_index(line, arranged.moved, arranged.tapped)]
		mids[mid.id] = "?" if arranged.is_choice(mid.kind) else FieldData.KIND_SHORT[arranged.next_of(mid.kind)]
	var danger := {}
	for e in pv["events"]:
		if str(e["type"]) == "disaster":
			for i in e["hit"]:
				danger[int(i)] = true
	# Kommt eine Wahl, steht ein „?“ über dem Feld; Kirchen, die sich treffen würden, zeigen gekreuzte Schwerter
	var war := {}
	for i in pv.get("war", []):
		war[int(i)] = true
	var card_field := int(pv.get("card_field", -1)) if int(pv.get("card", -1)) >= 0 else -1
	# Neue Tage (GDPD_BALANCE_2.md 4.6): wer wird satt (grün), wer verliert die Versorgung (rot); Feuer, Krieg, Flut
	var sup: Dictionary = pv.get("supply", {})
	var gain := {}
	var loss := {}
	for i in sup.get("satt_new", []):
		gain[int(i)] = true
	for i in sup.get("satt_lost", []):
		loss[int(i)] = true
	for i in sup.get("fire_risk", []):
		danger[int(i)] = true
	if bool(sup.get("war_risk", false)):
		for i in arranged.church_touch8():
			war[int(i)] = true
	var flood_faces: Array = sup.get("flood_risk", [])
	if not flood_faces.is_empty():
		for g in arranged.fields:
			var fd: FieldData = g
			if flood_faces.has(arranged.face_index(fd)) and [FieldData.EMPTY, FieldData.MEADOW, FieldData.FIELD, FieldData.HUT].has(fd.kind) \
					and bool(arranged.field_state8(fd).get("wet", false)):
				danger[fd.id] = true
	for f in Game.state.fields:
		var v: FieldView = views.get(f.id)
		if v == null:
			continue
		v.set_supply(1 if gain.has(f.id) else (-1 if loss.has(f.id) else 0))
		if mids.has(f.id):
			v.set_preview(str(mids[f.id]), Color("#d99a00"))
		elif danger.has(f.id):
			v.set_preview("!", Color("#e5483c"))
		else:
			v.set_preview("", Color.WHITE)
		v.set_highlight(lit.has(f.id))
		v.set_danger((danger.has(f.id) or war.has(f.id)) and not lit.has(f.id))
		if war.has(f.id):
			v.set_badge("swords")
		elif f.id == card_field and not mids.has(f.id):
			v.set_badge("help")
		else:
			v.set_badge("")
	preview_changed.emit(pv)


func _clear_preview() -> void:
	for fid in views:
		(views[fid] as FieldView).set_preview("", Color.WHITE)
		(views[fid] as FieldView).set_highlight(false)
		(views[fid] as FieldView).set_danger(false)
		(views[fid] as FieldView).set_badge("")
		(views[fid] as FieldView).set_supply(0)
	refresh_all()
	preview_changed.emit({})


func _finish_twist() -> void:
	_mode = ""
	if _over_cancel:
		cancel_hover.emit(false)
	_over_cancel = false
	_tw_live = false
	_tw_auto = false
	twist_state.emit(false)
	# Tutorial: im ersten Zug ist nur die gezeigte Drehung erlaubt
	if Game.tutorial() and Game.tutorial_step == 0 and _tw_quarter != 0:
		if not (_tw_axis == 0 and _tw_layer == 1 and _norm_turns(_tw_quarter) == 1):
			_tw_quarter = 0
			Game.message.emit("Probier die leuchtende Reihe.", "info")
	if Game.busy or Game.over:
		_tw_quarter = 0      # läuft gerade eine Runde (oder ist das Spiel aus), zählt die Drehung nicht: zurückgleiten statt hängen
	animating = true
	var ax := Vector3.ZERO
	ax[_tw_axis] = 1.0
	var target := _tw_quarter * PI * 0.5
	var start := _tw_display
	var piv := _pivot
	var setter := func(a: float) -> void:
		piv.basis = Basis(ax, a)
	var tw := create_tween()
	var dur := Balance.TWIST_SNAP_SECONDS * clampf(absf(target - start) / (PI * 0.5) + 0.35, 0.5, 1.6)
	if Game.tutorial() and Game.tutorial_step == 0:
		dur *= 2.4      # der vorgeführte Zug langsam, damit man sieht, was passiert
	tw.tween_method(setter, start, target, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	piv.basis = Basis(ax, target)
	var turns := _norm_turns(_tw_quarter)
	_unparent_pivot(piv, _tw_axis, turns)
	for fid in views:
		(views[fid] as FieldView).set_preview("", Color.WHITE)
		(views[fid] as FieldView).set_highlight(false)
		(views[fid] as FieldView).set_danger(false)
		(views[fid] as FieldView).set_badge("")
		(views[fid] as FieldView).set_supply(0)
	preview_changed.emit({})
	var gift := _tw_gift
	_tw_gift = false
	if turns != 0:
		if gift and Game.state != null and not Game.busy:
			Game.state.gift_twists += 1      # die Vorführung von Tag 1 kostet keine Drehung
		_slice_same = _slice_last == Vector2i(_tw_axis, _tw_layer)
		_slice_last = Vector2i(_tw_axis, _tw_layer)
		_slice_noted = true
		Game.play_turn(_tw_axis, _tw_layer, turns, _tw_row)
	else:
		animating = false
		refresh_all()


func _slice_cubies(axis: int, layer: int) -> Array:
	var out: Array = []
	for cb in cubies:
		var p: Vector3i = cb.get_meta("pos")
		if p[axis] == layer:
			out.append(cb)
	return out


func _unparent_pivot(piv: Node3D, axis: int, turns: int) -> void:
	var d := 1 if turns > 0 else -1
	for cb in piv.get_children():
		var node := cb as Node3D
		node.reparent(cube_root, true)
		node.position = node.position.round()
		var b := node.basis
		node.basis = Basis(b.x.round(), b.y.round(), b.z.round())
		var p: Vector3i = node.get_meta("pos")
		for i in absi(turns):
			p = GameState.rv(p, axis, d)
		node.set_meta("pos", p)
	piv.queue_free()


## Warten statt Drehen.
func wait_turn() -> void:
	if animating or Game.busy or Game.over:
		return
	_clear_hint()
	animating = true
	select(-1)
	Game.play_turn(0, 0, 0)


## Ein Zug ohne Finger: nur für die Screenshot-Tour (tour_auto) oder die Vorführung vor der ersten Eingabe.
func auto_twist(axis: int, layer: int, turns: int) -> bool:
	if not tour_auto and not can_self_move():
		return false
	if _mode != "" or animating or Game.busy:
		return false
	_clear_hint()
	_tw_axis = axis
	_tw_layer = layer
	_tw_sign = 1
	_tw_row = Game.state.slice_row(axis, layer)
	_pivot = Node3D.new()
	cube_root.add_child(_pivot)
	for cb in _slice_cubies(axis, layer):
		(cb as Node3D).reparent(_pivot, true)
	_tw_display = 0.0
	_tw_angle = 0.0
	_tw_quarter = turns
	_mode = "twist"
	_finish_twist()
	return true


## Tutorial: eine Scheibe ein Stück andrehen und zurück (zeigt, wie man dreht). Kein Zug.
## Gibt die Bildschirm-Richtung zurück, in die der Finger wischen müsste (ZERO = ging nicht).
func demo_twist(fid: int, drag: Vector2, want_axis: int, want_layer: int, sgn: float = 1.0) -> Vector2:
	if not can_self_move() or _mode != "" or animating or Game.busy:
		return Vector2.ZERO
	debug_begin_twist(fid, drag, 0.0)
	if _mode != "twist":
		_mode = ""
		return Vector2.ZERO
	if _tw_axis != want_axis or _tw_layer != want_layer:
		_cancel_drag()
		return Vector2.ZERO
	var dir := _tw_screen_dir * float(_tw_sign) * sgn
	if _demo_tw != null and _demo_tw.is_valid():
		_demo_tw.kill()
	var tw := create_tween()
	_demo_tw = tw
	tw.tween_method(_demo_set_angle, 0.0, PI * 0.5 * 0.42 * sgn, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	tw.tween_method(_demo_set_angle, PI * 0.5 * 0.42 * sgn, 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(_demo_end)
	return dir


## Tag 1 „Schau zu!“: Die Hand spielt den ersten Zug wirklich – die Scheibe dreht ganz herum, die Reihe wächst.
## Nur vor der ersten Eingabe (can_self_move). Der Zug kostet keine Drehung (GameState.gift_twists).
## Gibt die Bildschirm-Richtung des Wischens zurück (ZERO = ging nicht, dann gibt es keine Vorführung).
func demo_move(fid: int, drag: Vector2, want_axis: int, want_layer: int, turns: int) -> Vector2:
	if not can_self_move() or _mode != "" or animating or Game.busy or turns == 0:
		return Vector2.ZERO
	debug_begin_twist(fid, drag, 0.0)
	if _mode != "twist":
		_mode = ""
		return Vector2.ZERO
	if _tw_axis != want_axis or _tw_layer != want_layer:
		_cancel_drag()
		return Vector2.ZERO
	var sgn := -1.0 if turns < 0 else 1.0
	var dir := _tw_screen_dir * float(_tw_sign) * sgn
	if _demo_tw != null and _demo_tw.is_valid():
		_demo_tw.kill()
	var tw := create_tween()
	_demo_tw = tw
	tw.tween_interval(0.2)
	tw.tween_method(_demo_set_angle, 0.0, PI * 0.5 * float(turns) * 0.8, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_demo_commit.bind(turns))
	return dir


func _demo_commit(turns: int) -> void:
	_demo_tw = null
	if _mode != "twist" or _tw_live:
		return
	if not can_self_move():
		_cancel_drag()
		return
	_tw_quarter = turns
	_tw_gift = true
	_finish_twist()


func _demo_set_angle(a: float) -> void:
	if _mode == "twist" and not _tw_live:
		_tw_angle = a


func _demo_end() -> void:
	_demo_tw = null
	if _mode == "twist" and not _tw_live:
		_cancel_drag()


## Die Hand-Vorführung sofort beenden (der Spieler tippt): Scheibe ohne Animation zurück, kein Zug.
func _abort_demo() -> void:
	if _demo_tw != null and _demo_tw.is_valid():
		_demo_tw.kill()
	_demo_tw = null
	if _pivot != null and is_instance_valid(_pivot):
		_pivot.basis = Basis()
		_unparent_pivot(_pivot, _tw_axis, 0)
	_pivot = null
	_mode = ""
	_tw_angle = 0.0
	_tw_display = 0.0
	_tw_quarter = 0
	_over_cancel = false
	_tw_auto = false
	_tw_out_t = 0.0
	preview_changed.emit({})
	twist_state.emit(false)


## Für die automatischen Screenshots: eine Drehung mitten im Ziehen zeigen.
func debug_begin_twist(fid: int, drag: Vector2, amount: float) -> void:
	_hit_field = fid
	var v: FieldView = views[fid]
	_hit_point = v.label_world_pos()
	_press_pos = Vector2(300, 600)
	_begin_twist(drag)
	if _mode == "twist":
		_update_twist(_press_pos + _tw_screen_dir * _tw_px_per_quarter * amount)


func debug_end_twist() -> void:
	if _mode == "twist":
		_finish_twist()


# =============================================================================
# Runde abspielen
# =============================================================================

var round_no := 0               # jede ausgewertete Runde (auch Regen, der kein Zug ist) zählt eins weiter


func _on_round_resolved(result: Dictionary, before: Dictionary) -> void:
	round_no += 1
	animating = true
	# Dieselbe Scheibe wie im Zug davor (hin und her)? Werkzeuge und Warten zählen als anderer Zug.
	var same_slice := _slice_noted and _slice_same
	if not _slice_noted:
		_slice_last = Vector2i(-9, -9)
	_slice_noted = false
	_night_flush()
	_still_clear()
	_clear_hint()
	clear_choice()
	set_pick([])
	select(-1)
	var gs := Game.state
	var events: Array = result["events"]
	var handled := {}           # Felder mit eigenem Effekt (keine Pille „Wiese“/„weg“ am Ende)
	# Werkzeug zuerst: Regen fällt, der Blitz schlägt ein, ein Gewitter straft oder die Flut kommt
	var bonus_ids := {}
	if result.has("bonus"):
		var bd: Dictionary = result["bonus"]
		var kind := str(bd["kind"])
		for i in bd["fields"]:
			bonus_ids[int(i)] = true
		if kind == "bolt":
			await _bolt_fx(bd["fields"])
		elif kind == "monsoon":
			rig.shake(0.5)
			await _rain_fx(bd["fields"])
		elif kind == "strike" or kind == "flood":
			await _punish_fx(kind, bd, events)
		else:
			await _rain_fx(bd["fields"])
		var stages: Dictionary = bd["stages"]
		for i in bonus_ids:
			var v: FieldView = views.get(int(i))
			if v != null:
				var shown: FieldData = (gs.fields[int(i)] as FieldData).copy()
				shown.kind = int(stages.get(int(i), shown.kind))
				shown.burning = false
				v.refresh(shown)
		await get_tree().create_timer(0.35).timeout
	# Ganze Seite geschafft: großes Fest
	var merged_ids := {}
	for e in events:
		if str(e["type"]) != "face":
			continue
		for i in e["fields"]:
			merged_ids[int(i)] = true
		await _face_fx(e)
	var last_combo := 0
	var disaster_ids := {}
	for e in events:
		if str(e["type"]) == "disaster":
			for i in e["hit"]:
				disaster_ids[int(i)] = true
		elif str(e["type"]) == "burn":
			disaster_ids[int(e["field"])] = true
	# Verschmelzen, Kombo für Kombo
	for e in events:
		if str(e["type"]) != "merge" or bool(e.get("late", false)):
			continue
		var combo := int(e["combo"])
		if combo != last_combo and last_combo > 0:
			_show_ids(merged_ids, disaster_ids)
			await get_tree().create_timer(0.55).timeout
		last_combo = combo
		merged_ids[int(e["field"])] = true
		for o in e["others"]:
			merged_ids[int(o)] = true
		await _merge_fx(e)
	if last_combo > 0:
		_show_ids(merged_ids, disaster_ids)
		await get_tree().create_timer(0.3).timeout
	# Krieg: zwei Gemeinden haben sich getroffen
	for e in events:
		if str(e["type"]) == "war":
			await _war_fx(e)
			for i in e["fields"]:
				handled[int(i)] = true
	# Smog: Industrie lässt Natur welken
	var withered: Array = []
	var smog_w := -999
	for e in events:
		if str(e["type"]) == "smog":
			smog_w = int(e["w"])
		elif str(e["type"]) == "polluted":
			withered.append(int(e["field"]))
	if smog_w > -999:
		await _smog_fx(smog_w, withered)
		for i in withered:
			handled[int(i)] = true
	# Nachwachsen: Erde mit viel Natur daneben wird wieder Wiese
	for e in events:
		if str(e["type"]) == "regrow":
			var v: FieldView = views.get(int(e["field"]))
			if v != null:
				v.refresh(gs.fields[int(e["field"])])
				v.burst(Color("#8fd162"))
	# Was brennt, brennt weiter ab
	var burning: Array = []
	for e in events:
		if str(e["type"]) == "burn":
			burning.append(int(e["field"]))
	if not burning.is_empty():
		for i in burning:
			var v: FieldView = views.get(int(i))
			if v != null:
				v.burn(0.8)
				_sparks(v.global_position + v.world_normal() * 0.3, v.global_position + v.world_normal() * 1.0, Color("#6b6e78"), 3)
		await get_tree().create_timer(0.9).timeout
	# Wünsche: erfüllt (Herzen, Glaube), abgelaufen oder weg (leise)
	for e in events:
		var t := str(e["type"])
		if t == "wish_done":
			var fid := int(e["field"])
			var v: FieldView = views.get(fid)
			if v != null:
				v.set_wish("")
				v.wish_fx()
				v.refresh(gs.fields[fid])
			handled[fid] = true
			_buzz(26)
			wish_done_shown.emit(fid, int(e.get("faith", Balance.WISH_FAITH)))
			await get_tree().create_timer(0.55).timeout
		elif t == "wish_expired" or t == "wish_gone":
			var v: FieldView = views.get(int(e["field"]))
			if v != null:
				v.set_wish("")
	# Hat das alles eine neue Reihe ergeben, wächst sie jetzt (erst danach zu sehen)
	var late_any := false
	for e in events:
		if str(e["type"]) != "merge" or not bool(e.get("late", false)):
			continue
		late_any = true
		merged_ids[int(e["field"])] = true
		for o in e["others"]:
			merged_ids[int(o)] = true
		await _merge_fx(e)
	if late_any:
		await get_tree().create_timer(0.25).timeout
	# Stille Reihen: drei gleiche, die nicht wachsen – leuchten kurz mit Abzeichen, die Oberfläche sagt warum
	_still_fx(events, int(result.get("grew", 0)) > 0, same_slice)
	# Glaube pro Drehung von fertigen Feldern
	for e in events:
		if str(e["type"]) == "income":
			income_shown.emit(int(e["faith"]))
	# Fehlversuch zählen
	for e in events:
		if str(e["type"]) == "miss":
			var why := str(e.get("why", ""))
			if same_slice and ["", "water", "other"].has(why):
				why = "slice"       # hin und her: sagen, dass das nichts bringt (statt „Wasser wächst nie“)
			miss_shown.emit(int(e["field"]), int(e["count"]), why)
	# Neue Tage (GDPD_BALANCE_2.md 7): Gedeihen, Hunger, Krieg und Flut am Feld zeigen (die Art wechselt danach)
	var fx8 := false
	for e in events:
		var t8 := str(e["type"])
		if t8 == "war_start":
			await _war_start_fx(e)
		elif t8 == "war_end":
			hold_mood("", 2.0)
			for i in _war_churches:
				var cv: FieldView = views.get(int(i))
				if cv != null:
					cv.pulse_light(Color("#fff3c4"), 0.8)
					_sparks(cv.global_position + cv.world_normal() * 0.3, Vector3.ZERO, Color("#fff3a0"), 6)
			_war_churches = []
	for e in events:
		var fv8: FieldView = views.get(int(e.get("field", -1)))
		if fv8 == null:
			continue
		match str(e["type"]):
			"bolt":
				await _bolt_fx([int(e["field"])])
			"ignite":
				fv8.pulse_light(Color("#ff8a3d"), 0.7)
				_sparks(fv8.global_position + fv8.world_normal() * 0.15, fv8.global_position + fv8.world_normal() * 0.8, Color("#ff9a3d"), 6)
				fx8 = true
			"rain_out", "bolt_cancel":
				fv8.set_wet(1.0, 4.0)
				fv8.pulse_light(Color("#bfe3ff"), 0.6)
				_sparks(fv8.global_position + fv8.world_normal() * 0.2, fv8.global_position + fv8.world_normal() * 0.9, Color("#e8eef2"), 4)
			"satt_lost":
				fv8.pulse_light(Color("#c9a6a0"), 0.6)
			"thrive":
				fv8.burst(Color("#ffd75e"))
				fx8 = true
			"satt_new":
				fv8.pulse_light(Color("#ffe3a0"), 0.7)
			"starve":
				_dust(fv8)
				fx8 = true
			"war_hit":
				fv8.war_fx(1.1)
				fx8 = true
			"flood":
				fv8.flood(1.2)
				fx8 = true
	if fx8:
		await get_tree().create_timer(0.5).timeout
	# Katastrophe
	for e in events:
		if str(e["type"]) == "disaster":
			refresh_all(null, disaster_ids)
			await _disaster_fx(e)
	refresh_all()
	for e in events:
		if str(e["type"]) == "wish":
			wish_made_shown.emit(int(e["field"]))
	var changes: Array = []
	for f in gs.fields:
		if merged_ids.has(f.id) or disaster_ids.has(f.id) or bonus_ids.has(f.id) or handled.has(f.id):
			continue
		var b := int(before.get(f.id, f.kind))
		if f.kind == 0 and b > 0:
			changes.append({"field": f.id, "change": "lost"})
		elif f.kind > 0 and b == 0:
			changes.append({"field": f.id, "change": "new"})
	deltas_shown.emit(changes, int(result["gain"]))
	await get_tree().create_timer(0.35).timeout
	animating = false
	Game.finish_round(result)


## Abzeichen über den Feldern einer stillen Reihe (warum sie nicht wächst).
const STILL_BADGE = {"rest": "lock", "diag": "close", "water": "water", "finished": "check", "standing": "check",
	"spent": "check", "repeat": "undo", "other": "wait", "people": "person", "done": "goal", "stone": "stone", "slice": "undo"}


## Stille Reihen zeigen (GameState._still_rows). Blockiert nicht: Die Felder leuchten kurz mit Abzeichen, dann ist
## es von selbst weg (oder mit dem nächsten Zug). Wasser nur, wenn sonst nichts gewachsen ist und keine andere Reihe
## etwas sagt, und dann nur eine Reihe (sonst stünde es nach fast jeder Drehung überall). Die Oberfläche bekommt jede
## gezeigte Reihe als still_shown.
func _still_fx(events: Array, grew: bool, same_slice: bool = false) -> void:
	var miss := false
	var other := false
	var water: Array = []
	for e in events:
		var t := str(e["type"])
		if t == "miss":
			miss = true
		elif t == "still":
			if str(e["why"]) == "water":
				water.append(e)
			else:
				other = true
	# Wasser nur, wenn sonst nichts zu sehen ist – und nur eine Reihe (am liebsten die gewischte)
	var water_pick: Dictionary = {}
	if not grew and not other and not water.is_empty() and not same_slice:
		water_pick = water[0]
		var swiped := {}
		for i in Game.state.last_row:
			swiped[int(i)] = true
		for e in water:
			for i in (e as Dictionary)["fields"]:
				if swiped.has(int(i)):
					water_pick = e
	var shown := 0
	for e in events:
		if str(e["type"]) != "still":
			continue
		var why := str(e["why"])
		if why == "water" and e != water_pick:
			continue
		var ids: Array = e["fields"]
		for i in ids:
			var v: FieldView = views.get(int(i))
			if v == null:
				continue
			v.refresh(Game.state.fields[int(i)])
			if why != "water":
				v.set_highlight(true)
			v.set_badge(str(STILL_BADGE.get(why, "info")))
			v.nudge()
			_still_views.append(v)
		shown += 1
		var info := (e as Dictionary).duplicate()
		info["grew"] = grew
		info["miss"] = miss
		info["round"] = round_no
		var seen := false
		for i in ids:
			if bool(field_screen(int(i))["visible"]):
				seen = true
		info["visible"] = seen          # liegt die Reihe gerade hinten, sagt die Oberfläche nichts dazu
		still_shown.emit(info)
	if shown > 0:
		_still_gen += 1
		get_tree().create_timer(2.6).timeout.connect(_still_end.bind(_still_gen))


func _still_end(gen: int) -> void:
	if gen == _still_gen:
		_still_clear()


func _still_clear() -> void:
	_still_gen += 1
	var drag := _mode == "twist"      # eine laufende Vorschau gehört dem Finger: dort nichts löschen
	for v in _still_views:
		if is_instance_valid(v) and not drag:
			(v as FieldView).set_highlight(false)
			(v as FieldView).set_badge("")
	_still_views.clear()


## Was schon gewachsen ist, zeigen (außer was gleich brennt).
func _show_ids(ids: Dictionary, skip: Dictionary) -> void:
	for fid in ids:
		if skip.has(fid):
			continue
		var mv: FieldView = views.get(int(fid))
		if mv != null:
			mv.refresh(Game.state.fields[int(fid)])


## Krieg: Schwerter über den Kirchen, rotes Blinken, Beben; die Kirchen stürzen zu Häusern ein.
func _war_fx(e: Dictionary) -> void:
	var ids: Array = e["fields"]
	if ids.is_empty():
		return
	if not bool(field_screen(int(ids[0]))["visible"]):
		focus_field(int(ids[0]))
		await get_tree().create_timer(0.45).timeout
	hold_mood("krieg", 0.6)
	get_tree().create_timer(3.2).timeout.connect(hold_mood.bind("", 2.0))
	for i in ids:
		var v: FieldView = views.get(int(i))
		if v != null:
			v.war_fx(1.4)
			_sparks(v.global_position + v.world_normal() * 0.3, Vector3.ZERO, Color("#e5483c"), 8)
	rig.shake(1.1)
	_buzz(45)
	war_shown.emit(ids, int(e.get("faith", 0)))
	await get_tree().create_timer(0.6).timeout
	for i in ids:
		var v: FieldView = views.get(int(i))
		if v != null:
			v.refresh(Game.state.fields[int(i)])
	await get_tree().create_timer(0.9).timeout


## Krieg beginnt (neue Tage): Kamera zu den Kirchen, rote Stimmung, Schwerter, die Front leuchtet rot.
var _war_churches: Array = []


func _war_start_fx(e: Dictionary) -> void:
	var ch: Array = e.get("churches", [])
	var fr: Array = e.get("front", [])
	_war_churches = ch.duplicate()
	if ch.is_empty():
		return
	if not bool(field_screen(int(ch[0]))["visible"]):
		focus_field(int(ch[0]))
		await get_tree().create_timer(0.45).timeout
	hold_mood("krieg", 0.6)
	for i in ch:
		var v: FieldView = views.get(int(i))
		if v != null:
			v.set_badge("swords")
			v.set_danger(true)
			_sparks(v.global_position + v.world_normal() * 0.3, Vector3.ZERO, Color("#e5483c"), 6)
	for i in fr:
		var fv: FieldView = views.get(int(i))
		if fv != null:
			fv.pulse_light(Color("#ff6a4a"), 0.7)
	rig.shake(0.6)
	_buzz(35)
	await get_tree().create_timer(0.8).timeout
	for i in ch:
		var v: FieldView = views.get(int(i))
		if v != null:
			v.set_badge("")
			v.set_danger(false)


## Smog: graue Wolken über der Industrie, Wälder welken, Tiere fliehen.
func _smog_fx(w: int, withered: Array) -> void:
	var smog_ids := smog_fields(Game.state)
	for fid in smog_ids:
		var v: FieldView = views.get(int(fid))
		if v != null:
			v.set_polluted(true)
	smog_shown.emit(w, withered)
	if withered.is_empty():
		await get_tree().create_timer(0.3).timeout
		return
	for i in withered:
		var v: FieldView = views.get(int(i))
		if v != null:
			v.wither_fx(1.2)
			_sparks(v.global_position + v.world_normal() * 0.3, v.global_position + v.world_normal() * 0.9, Color("#6b6e78"), 4)
	await get_tree().create_timer(0.7).timeout
	for i in withered:
		var v: FieldView = views.get(int(i))
		if v != null:
			v.refresh(Game.state.fields[int(i)])
	await get_tree().create_timer(0.5).timeout


## Strafen: Gewitter (ein Blitz ins Feld) oder Flut (Wasser über die ganze Seite).
func _punish_fx(kind: String, bd: Dictionary, events: Array) -> void:
	var fid := int(bd["field"])
	var cost := 0
	var hit: Array = []
	for e in events:
		if str(e["type"]) == kind:
			cost = int(e.get("cost", 0))
			for h in e["hit"]:
				hit.append(int((h as Dictionary)["field"]))
	if not bool(field_screen(fid)["visible"]):
		focus_field(fid)
		await get_tree().create_timer(0.45).timeout
	punish_shown.emit(kind, fid, cost)
	var meteor := false
	for e in events:
		if str(e["type"]) == "meteor" and int(e.get("field", -1)) == fid:
			meteor = true
	if kind == "strike" and meteor:
		# Meteor (Tag 6–7): glühender Brocken, Einschlag, Krater bleibt
		await _meteor_fx(fid)
		var mv: FieldView = views.get(fid)
		if mv != null:
			mv.set_crater(true)
			_dust(mv)
		_buzz(40)
		await get_tree().create_timer(0.5).timeout
		return
	if kind == "strike":
		var v: FieldView = views.get(fid)
		if v != null:
			v.strike_fx(0.8)
			_sparks(v.global_position + v.world_normal() * 0.2, Vector3.ZERO, Color("#ffe066"), 10)
		var flash := OmniLight3D.new()
		flash.light_color = Color("#d9ccff")
		flash.omni_range = 5.0
		flash.light_energy = 9.0
		cube_root.add_child(flash)
		if v != null:
			flash.global_position = v.global_position + v.world_normal() * 1.4
		flash_screen(0.4)
		var ft := create_tween()
		ft.tween_property(flash, "light_energy", 0.0, 0.5)
		ft.tween_callback(flash.queue_free)
		rig.shake(0.9)
		_buzz(40)
		await get_tree().create_timer(0.7).timeout
		return
	rig.shake(0.6)
	for i in hit:
		var v: FieldView = views.get(int(i))
		if v != null:
			v.flood(1.3)
	await _rain_fx(bd["fields"])
	await get_tree().create_timer(0.5).timeout


func _merge_fx(e: Dictionary) -> void:
	var target: FieldView = views.get(int(e["field"]))
	if target == null:
		return
	var dur := 0.32
	var others: Array = e["others"]
	for o in others:
		var v: FieldView = views.get(int(o))
		if v != null:
			v.set_highlight(true)
			v.pulse_light(Color("#ffd9a0"), 0.5)
			if Balance.OTHERS_DROP > 0 or bool(e.get("consume", false)):
				v.vanish(target.global_position, dur)
				_dust(v)
			_sparks(v.global_position + v.world_normal() * 0.3, target.global_position + target.world_normal() * 0.35, Color("#ffd23f"), 5)
	target.set_highlight(true)
	target.pulse_light(Color("#ffd9a0"), 0.5)
	await get_tree().create_timer(dur).timeout
	for o in others:
		var v: FieldView = views.get(int(o))
		if v != null:
			v.set_highlight(false)
	target.set_highlight(false)
	target.burst(Color("#ffd23f"))
	if bool(e.get("consume", false)) or bool(e.get("all", false)):
		for o in others:
			var ov: FieldView = views.get(int(o))
			if ov != null:
				ov.burst(Color("#ffd23f"))
	_sparks(target.global_position + target.world_normal() * 0.3, Vector3.ZERO, Color("#fff3a0"), 10)
	rig.shake(0.25 + 0.15 * int(e["combo"]))
	rig.punch(0.03 + 0.008 * mini(int(e["combo"]), 4))
	_wind_kick = 2.0
	merged.emit(int(e["field"]), int(e["points"]), int(e["combo"]), int(e.get("stage", 0)))
	await get_tree().create_timer(0.12).timeout


## Erdbeben, Überschwemmung oder Waldbrand abspielen.
func _disaster_fx(e: Dictionary) -> void:
	var kind := str(e["kind"])
	var hit: Array = e["hit"]
	var fid := int(e["field"])
	if fid >= 0:
		focus_field(fid)
		await get_tree().create_timer(0.45).timeout
	disaster_shown.emit(kind, fid)
	var dur := 1.0
	for i in hit:
		var v: FieldView = views.get(int(i))
		if v == null:
			continue
		var p := v.global_position + v.world_normal() * 0.25
		v.set_danger(true)
		if kind == "quake":
			v.quake(dur)
			_sparks(p, Vector3.ZERO, Color("#a5805c"), 6)
		else:
			var lit: FieldData = (Game.state.fields[int(i)] as FieldData).copy()
			v.refresh(lit)
			v.burst(Color("#ff8a3d"))
			_sparks(p, Vector3.ZERO, Color("#ff8a3d"), 9)
	if kind == "quake":
		rig.shake(1.6)
	elif kind == "fire":
		rig.shake(0.4)
	else:
		rig.shake(0.3)
	await get_tree().create_timer(dur * 1.05).timeout
	for i in hit:
		var v: FieldView = views.get(int(i))
		if v != null:
			v.set_danger(false)
			if kind == "fire":
				_sparks(v.global_position + v.world_normal() * 0.3, v.global_position + v.world_normal() * 1.0, Color("#6b6e78"), 4)


## Eine ganze Seite steigt auf: alle neun Felder leuchten nacheinander, dann ein großer Ring.
func _face_fx(e: Dictionary) -> void:
	var fid := int(e["field"])
	if fid >= 0:
		focus_field(fid)
		await get_tree().create_timer(0.45).timeout
	var ids: Array = e["fields"]
	for i in ids:
		var v: FieldView = views.get(int(i))
		if v != null:
			v.set_highlight(true)
			v.burst(Color("#ffd23f"))
			_sparks(v.global_position + v.world_normal() * 0.3, Vector3.ZERO, Color("#fff3a0"), 4)
		await get_tree().create_timer(0.06).timeout
	rig.shake(0.9)
	for i in ids:
		var v: FieldView = views.get(int(i))
		if v != null:
			v.set_highlight(false)
			v.refresh(Game.state.fields[int(i)])
	face_completed.emit(fid, int(e["points"]), int(e["stage"]))
	await get_tree().create_timer(0.9).timeout


## Funken: fliegen von a nach b (oder bei b == ZERO in alle Richtungen nach außen).
func _sparks(a: Vector3, b: Vector3, color: Color, count: int) -> void:
	# helle Farben: leuchtende Funken (additiv); dunkle: kleine Rauchflocken
	var glow := color.get_luminance() > 0.45
	for k in count:
		var spark := MeshInstance3D.new()
		spark.mesh = Look.quad(0.11 if glow else 0.16)
		spark.material_override = Look.mote(color) if glow else Look.smoke(Color(color, 0.7))
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cube_root.add_child(spark)
		spark.global_position = a
		var to := b
		if b == Vector3.ZERO:
			var out := (a - Vector3.ZERO).normalized()
			to = a + (out + Vector3(randf_range(-0.7, 0.7), randf_range(-0.7, 0.7), randf_range(-0.7, 0.7))).normalized() * 0.6
		else:
			to = b + Vector3(randf_range(-0.08, 0.08), randf_range(-0.08, 0.08), randf_range(-0.08, 0.08))
		var tw := spark.create_tween()
		tw.tween_property(spark, "global_position", to, randf_range(0.3, 0.5)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(spark, "scale", Vector3.ZERO, 0.5).set_ease(Tween.EASE_IN)
		tw.tween_callback(spark.queue_free)


## Staub, Blätter oder Erdklumpen steigen aus einem Feld, dessen Inhalt gerade verschmilzt.
func _dust(v: FieldView) -> void:
	var k := v.get_kind()
	var col := Color("#8d7a5e")
	if FieldView.NATURE_KINDS.has(k):
		col = Color("#6d8a3a") if k != FieldView.K_MEADOW else Color("#d8d2b8")
	elif k == FieldView.K_EMPTY or k == FieldView.K_FIELD:
		col = Color("#6e5238")
	elif k >= FieldView.K_HUT and k != FieldView.K_WATER:
		col = Color("#a39d92")
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 16
	p.lifetime = 0.7
	p.explosiveness = 0.85
	p.mesh = Look.quad(1.0)
	p.material_override = Look.dust()
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.28, 0.04, 0.28)
	p.direction = Vector3(0, 1, 0)
	p.spread = 40.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.1
	p.gravity = Vector3(0, -2.2, 0)
	p.damping_min = 0.6
	p.damping_max = 1.2
	p.scale_amount_min = 0.025
	p.scale_amount_max = 0.05
	p.color = col
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.add_child(p)
	p.position = Vector3(0, FieldView.TOP + 0.05, 0)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


## Meteorit: fällt glühend vom Himmel und schlägt ein. Das Feld wird wieder Erde.
func _meteor_fx(fid: int) -> void:
	var v: FieldView = views.get(fid)
	if v == null:
		return
	var n := v.world_normal()
	var target := v.global_position + n * 0.15
	var start := target + n * 5.0 + rig.global_transform.basis.x * 1.2
	var rock := Node3D.new()
	cube_root.add_child(rock)
	rock.global_position = start
	# Felsbrocken (Modell) mit Glut-Hülle und Flammen
	for pv in Models.get_model("boulder", 2):
		var part: Array = pv
		var rm := MeshInstance3D.new()
		rm.mesh = part[0]
		rm.material_override = Models.material(String(part[1]))
		rm.scale = Vector3.ONE * 2.6
		rm.position = Vector3(0, -0.08, 0)
		rock.add_child(rm)
	var glow := MeshInstance3D.new()
	glow.mesh = Look.quad(0.9)
	glow.material_override = Look.mote(Color(1.0, 0.5, 0.15, 0.9))
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rock.add_child(glow)
	Models.flame(rock, Vector3(0, 0.05, 0), 3.0, 3, 0.4)
	var tw := create_tween()
	tw.tween_property(rock, "global_position", target, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var trail_t := 0.0
	while trail_t < 0.6:
		await get_tree().create_timer(0.06).timeout
		trail_t += 0.06
		_sparks(rock.global_position, rock.global_position + (start - target).normalized() * 0.4, Color("#ffb347"), 2)
	if tw.is_running():
		await tw.finished
	rock.queue_free()
	var flash := OmniLight3D.new()
	flash.light_color = Color("#ffb347")
	flash.omni_range = 4.0
	flash.light_energy = 8.0
	cube_root.add_child(flash)
	flash.global_position = target + n * 0.4
	var ft := create_tween()
	ft.tween_property(flash, "light_energy", 0.0, 0.6)
	ft.tween_callback(flash.queue_free)
	rig.shake(1.2)
	v.burst(Color("#ff8a3d"))
	_sparks(target + n * 0.2, Vector3.ZERO, Color("#ff8a3d"), 16)


## Blitz: zuckt vom Himmel in die Reihe, alle drei Felder leuchten auf.
func _bolt_fx(ids: Array) -> void:
	if ids.is_empty():
		return
	var mid: FieldView = views.get(int(ids[ids.size() / 2]))
	if mid == null:
		return
	var n := mid.world_normal()
	var flash := OmniLight3D.new()
	flash.light_color = Color("#fff3a0")
	flash.omni_range = 5.0
	flash.light_energy = 10.0
	cube_root.add_child(flash)
	flash.global_position = mid.global_position + n * 1.2
	for i in ids:
		var v: FieldView = views.get(int(i))
		if v == null:
			continue
		var top := v.global_position + v.world_normal() * 2.2
		var bottom := v.global_position + v.world_normal() * 0.1
		var seg := 6
		for k in seg:
			var a := top.lerp(bottom, float(k) / seg) + Vector3(randf_range(-0.08, 0.08), randf_range(-0.08, 0.08), randf_range(-0.08, 0.08))
			var spark := MeshInstance3D.new()
			spark.mesh = Look.quad(0.22)
			spark.material_override = Look.mote(Color("#fff6c8"))
			spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cube_root.add_child(spark)
			spark.global_position = a
			var tw := spark.create_tween()
			tw.tween_interval(0.25)
			tw.tween_property(spark, "scale", Vector3.ZERO, 0.2)
			tw.tween_callback(spark.queue_free)
		v.burst(Color("#ffd23f"))
		_sparks(bottom, Vector3.ZERO, Color("#ffe066"), 8)
	flash_screen(0.35)
	rig.shake(0.7)
	var ft := create_tween()
	ft.tween_property(flash, "light_energy", 0.0, 0.5)
	ft.tween_callback(flash.queue_free)
	await get_tree().create_timer(0.6).timeout


## Bildblitz (Blitz, Gewitter): kurz heller über der Welt und im Himmel, nie über der Oberfläche.
func flash_screen(amount: float) -> void:
	if _post_mat == null:
		return
	var tw := create_tween()
	tw.tween_method(_set_flash, amount, 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_flash(v: float) -> void:
	_post_mat.set_shader_parameter("flash", v)
	if _backdrop_mat != null:
		_backdrop_mat.set_shader_parameter("flash", v * 0.6)


## Welche Reihe trifft der Blitz? Die durch das Feld, die auf dem Bildschirm am ehesten waagrecht liegt.
func screen_row(fid: int) -> Array:
	var gs := Game.state
	var f: FieldData = gs.fields[fid]
	var v: FieldView = views.get(fid)
	var a := GameState.axis_of(f.n)
	var best: Array = []
	var best_dot := -1.0
	for along in [(a + 1) % 3, (a + 2) % 3]:
		var row := gs.line_through(f, along)
		if v == null or row.size() < 3:
			continue
		var dir := Vector3.ZERO
		dir[along] = 1.0
		var p0 := rig.cam.unproject_position(v.global_position)
		var p1 := rig.cam.unproject_position(v.global_position + cube_root.global_transform.basis * dir * 0.5)
		var d := absf((p1 - p0).normalized().x)
		if d > best_dot:
			best_dot = d
			best = row
	return best


## Regen: eine Wolke zieht über das Feld, Tropfen fallen, alles wird grün.
func _rain_fx(ids: Array) -> void:
	if ids.is_empty():
		return
	var v: FieldView = views.get(int(ids[0]))
	if v == null:
		return
	var n := v.world_normal()
	var above := v.global_position + n * 1.1
	hold_mood("regen", 0.6)
	# Wolke aus weichen Rauschflocken (statt Kugeln), zieht heran
	var cloud := Node3D.new()
	cube_root.add_child(cloud)
	cloud.global_position = above + rig.global_transform.basis.x * 1.5
	for k in 7:
		var off := Vector3(randf_range(-0.38, 0.38), randf_range(-0.06, 0.1), randf_range(-0.38, 0.38))
		var shade := randf_range(0.66, 0.8)
		Look.smoke_puff(cloud, randf_range(0.55, 0.8), Color(shade, shade + 0.02, shade + 0.05, 0.92), off)
	var tw := create_tween()
	tw.tween_property(cloud, "global_position", above, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	# Regenstriche (Partikel, fallen entlang der Normalen), der Boden wird nass, kleine Spritzer
	var drops: Array = []
	for i in ids:
		var w: FieldView = views.get(int(i))
		if w == null:
			continue
		drops.append(_rain_drops(w))
		w.set_wet(1.0, 3.0)
	await get_tree().create_timer(0.8).timeout
	for d in drops:
		(d as CPUParticles3D).emitting = false
	for i in ids:
		var w: FieldView = views.get(int(i))
		if w != null:
			w.burst(Color("#8fd162"))
	var out := create_tween()
	out.tween_property(cloud, "scale", Vector3.ONE * 0.05, 0.45).set_ease(Tween.EASE_IN)
	out.tween_callback(cloud.queue_free)
	for d in drops:
		get_tree().create_timer(0.8).timeout.connect((d as Node).queue_free)
	get_tree().create_timer(0.6).timeout.connect(hold_mood.bind("", 2.0))


## Regenstriche über einem Feld: gestreckte Kreuz-Quads, fallen zur Kachel (lokal: -y).
func _rain_drops(w: FieldView) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.42
	p.mesh = Look.streak_mesh()
	p.material_override = Look.rain_mat()
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.36, 0.02, 0.36)
	p.direction = Vector3(0, -1, 0)
	p.spread = 3.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, -1.0, 0)
	p.local_coords = true
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(p)
	p.position = Vector3(0, 0.95, 0)
	p.emitting = true
	return p


