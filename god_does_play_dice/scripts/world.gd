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
var bolt_mode := false          # Blitz gewählt: Wischen zeichnet die Reihe statt zu drehen
var _bolt_row: Array = []
var _pivot: Node3D
var _touches: Dictionary = {}
var _pinch_dist := 0.0
var _two_center := Vector2.ZERO   # zwei Finger: Mittelpunkt (schwenken) …
var _two_angle := 0.0             # … und Winkel (drehen)
var _postfx: CanvasLayer
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
	_add_clouds()
	rebuild()


func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#9fd3f5")
	sky_mat.sky_horizon_color = Color("#fdeedd")
	sky_mat.ground_horizon_color = Color("#fdeedd")
	sky_mat.ground_bottom_color = Color("#f6dcc0")
	sky_mat.sun_angle_max = 0.0
	sky_mat.sky_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b9c6dc")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.82
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
	layer.add_child(rect)


# =============================================================================
# Aufbau und Aktualisierung
# =============================================================================

func rebuild() -> void:
	_hint_views.clear()
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
	var body_mesh := Models.rounded_box_mesh(Vector3(0.98, 0.98, 0.98), 0.12, 4)
	var body_mat := Models.mat(Color("#3a3d4a"), 0.35)
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
	for f in gs.fields:
		var v: FieldView = views.get(f.id)
		if v == null or skip.has(f.id):
			continue
		v.refresh(f)
		v.set_selected(f.id == selected)



## Ein paar Wolken im Hintergrund: hängen an der Kamera, immer hinter dem Würfel, ohne Schatten.
var _clouds: Node3D
var _cloud_base: Array = []


func _add_clouds() -> void:
	_clouds = Node3D.new()
	rig.add_child(_clouds)
	var cm := Models.unshaded(Color(1, 1, 1, 0.85))
	var spots := [Vector3(-2.9, 2.2, -5.0), Vector3(2.7, 1.2, -6.0), Vector3(-2.2, -2.4, -5.5)]
	for sp in spots:
		var c := Node3D.new()
		c.position = sp
		_clouds.add_child(c)
		_cloud_base.append(sp)
		for k in 3:
			var m := Models.sphere(c, [0.42, 0.55, 0.38][k], Color.WHITE, Vector3([-0.45, 0.0, 0.45][k], [0.0, 0.12, -0.02][k], 0.0), cm)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
	for fid in views:
		var v: FieldView = views[fid]
		var t: String = str(tg.get(int(fid), ""))
		v.set_target(t != "", col)
		v.set_badge("rain" if t == "useful" or t == "fire" else "")


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


func _process(delta: float) -> void:
	if _clouds != null:
		var t := Time.get_ticks_msec() / 1000.0
		for i in _clouds.get_child_count():
			var c: Node3D = _clouds.get_child(i)
			var b: Vector3 = _cloud_base[i]
			c.position = b + Vector3(sin(t * 0.07 + i * 2.0) * 0.6, 0.0, 0.0)
	if _mode == "" and not animating and not Game.busy and not Game.over:
		_idle += delta
		if Game.tutorial() and _idle > 1.2 and not _hinted:
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
		v.set_labels_visible(v.world_normal().dot(to_cam) > 0.2)


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
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		if _touches.size() >= 2:
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
			rig.zoom(0.92)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rig.zoom(1.08)
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _touches.size() < 2:
			_motion(mm.position, mm.relative)
		return
	if event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
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
func show_hint() -> Dictionary:
	_clear_hint()
	return _show_hint()


func _show_hint() -> Dictionary:
	_hinted = true
	var best := Game.state.best_move()
	# Tutorial: genau der vorgezeigte Zug leuchtet (derselbe in beiden Schritten, wie die Hand ihn zeigt)
	if Game.tutorial() and Game.tutorial_step <= 1:
		best = {"axis": 0, "layer": 1, "turns": 1, "points": 0, "steps": 1}
	if best.is_empty():
		return best
	for cb in _slice_cubies(int(best["axis"]), int(best["layer"])):
		for child in (cb as Node3D).get_children():
			if child is FieldView:
				(child as FieldView).set_hint(true)
				_hint_views.append(child)
	return best


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


func _press(pos: Vector2) -> void:
	# Tutorial: der erste Zug spielt sich selbst. Tippen startet ihn sofort.
	if Game.tutorial() and Game.tutorial_step == 0:
		tutorial_tap.emit()
		return
	if _mode == "twist" and not _tw_live:
		_abort_demo()        # die Hand führt gerade vor: sofort weg, derselbe Finger dreht gleich selbst
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
		mids[mid.id] = GameState.STAGE_SHORT[mini(mid.stage + 1, Balance.MAX_STAGE)]
	var danger := {}
	for e in pv["events"]:
		if str(e["type"]) == "disaster":
			for i in e["hit"]:
				danger[int(i)] = true
	for f in Game.state.fields:
		var v: FieldView = views.get(f.id)
		if v == null:
			continue
		if mids.has(f.id):
			v.set_preview(str(mids[f.id]), Color("#d99a00"))
		elif danger.has(f.id):
			v.set_preview("!", Color("#e5483c"))
		else:
			v.set_preview("", Color.WHITE)
		v.set_highlight(lit.has(f.id))
		v.set_danger(danger.has(f.id) and not lit.has(f.id))
	preview_changed.emit(pv)


func _clear_preview() -> void:
	for fid in views:
		(views[fid] as FieldView).set_preview("", Color.WHITE)
		(views[fid] as FieldView).set_highlight(false)
		(views[fid] as FieldView).set_danger(false)
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
			Game.message.emit("Probier die leuchtende Reihe – so wie die Hand es zeigt.", "info")
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
	preview_changed.emit({})
	if turns != 0:
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


## Tutorial: die Scheibe dreht sich von selbst und spielt den Zug (damit man gleich ein Upgrade sieht).
func auto_twist(axis: int, layer: int, turns: int) -> bool:
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
func demo_twist(fid: int, drag: Vector2, want_axis: int, want_layer: int) -> Vector2:
	if _mode != "" or animating or Game.busy:
		return Vector2.ZERO
	debug_begin_twist(fid, drag, 0.0)
	if _mode != "twist":
		_mode = ""
		return Vector2.ZERO
	if _tw_axis != want_axis or _tw_layer != want_layer:
		_cancel_drag()
		return Vector2.ZERO
	var dir := _tw_screen_dir * float(_tw_sign)
	if _demo_tw != null and _demo_tw.is_valid():
		_demo_tw.kill()
	var tw := create_tween()
	_demo_tw = tw
	tw.tween_method(_demo_set_angle, 0.0, PI * 0.5 * 0.42, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	tw.tween_method(_demo_set_angle, PI * 0.5 * 0.42, 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(_demo_end)
	return dir


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

func _on_round_resolved(result: Dictionary, before: Dictionary) -> void:
	animating = true
	_clear_hint()
	select(-1)
	var gs := Game.state
	var events: Array = result["events"]
	# Bonus zuerst: Regen fällt oder der Blitz schlägt ein
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
		else:
			await _rain_fx(bd["fields"])
		var stages: Dictionary = bd["stages"]
		for i in bonus_ids:
			var v: FieldView = views.get(int(i))
			if v != null:
				var shown: FieldData = (gs.fields[int(i)] as FieldData).copy()
				shown.stage = int(stages.get(int(i), shown.stage))
				shown.burning = false
				v.refresh(shown)
		await get_tree().create_timer(0.35).timeout
	# Verschmelzen, Kombo für Kombo
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
	for e in events:
		if str(e["type"]) != "merge" or bool(e.get("late", false)):
			continue
		var combo := int(e["combo"])
		if combo != last_combo and last_combo > 0:
			# Nur zeigen, was schon verschmolzen ist; der Rest kommt der Reihe nach
			for fid in merged_ids:
				if not disaster_ids.has(fid):
					var mv: FieldView = views.get(int(fid))
					if mv != null:
						mv.refresh(gs.fields[int(fid)])
			await get_tree().create_timer(0.55).timeout
		last_combo = combo
		merged_ids[int(e["field"])] = true
		for o in e["others"]:
			merged_ids[int(o)] = true
		await _merge_fx(e)
	if last_combo > 0:
		await get_tree().create_timer(0.25).timeout
	# Verschmutzung und Nachwachsen
	for e in events:
		if str(e["type"]) == "polluted":
			var v: FieldView = views.get(int(e["field"]))
			if v != null:
				_sparks(v.global_position + v.world_normal() * 0.3, Vector3.ZERO, Color("#6b6e78"), 4)
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
	# Hat das Abbrennen eine neue Reihe ergeben, wächst sie jetzt (erst nach dem Brand zu sehen)
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
	# Fehlversuch zählen
	for e in events:
		if str(e["type"]) == "miss":
			miss_shown.emit(int(e["field"]), int(e["count"]), str(e.get("why", "")))
	# Katastrophe
	for e in events:
		if str(e["type"]) == "disaster":
			refresh_all(null, disaster_ids)
			await _disaster_fx(e)
	refresh_all()
	var changes: Array = []
	for f in gs.fields:
		if merged_ids.has(f.id) or disaster_ids.has(f.id) or bonus_ids.has(f.id):
			continue
		var b := int(before.get(f.id, f.stage))
		if f.stage == 0 and b > 0:
			changes.append({"field": f.id, "change": "lost"})
		elif f.stage > 0 and b == 0:
			changes.append({"field": f.id, "change": "new"})
	deltas_shown.emit(changes, int(result["gain"]))
	await get_tree().create_timer(0.35).timeout
	animating = false
	Game.finish_round(result)


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
			if Balance.OTHERS_DROP > 0 or bool(e.get("consume", false)):
				v.vanish(target.global_position, dur)
			_sparks(v.global_position + v.world_normal() * 0.3, target.global_position + target.world_normal() * 0.35, Color("#ffd23f"), 5)
	target.set_highlight(true)
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
	var m := Models.mat(color, 0.3, 3.0)
	for k in count:
		var spark := Models.sphere(cube_root, 0.025, color, a, m)
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
	Models.sphere(rock, 0.2, Color("#7a6250"), Vector3.ZERO, Models.mat(Color("#7a6250"), 0.8), 0.9)
	Models.sphere(rock, 0.27, Color(1.0, 0.55, 0.15, 0.4), Vector3.ZERO, Models.mat(Color(1.0, 0.55, 0.15, 0.4), 0.5, 2.5))
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
			var spark := Models.sphere(cube_root, 0.045, Color("#fff3a0"), a, Models.mat(Color("#fff3a0"), 0.2, 4.0))
			var tw := spark.create_tween()
			tw.tween_interval(0.25)
			tw.tween_property(spark, "scale", Vector3.ZERO, 0.2)
			tw.tween_callback(spark.queue_free)
		v.burst(Color("#ffd23f"))
		_sparks(bottom, Vector3.ZERO, Color("#ffe066"), 8)
	rig.shake(0.7)
	var ft := create_tween()
	ft.tween_property(flash, "light_energy", 0.0, 0.5)
	ft.tween_callback(flash.queue_free)
	await get_tree().create_timer(0.6).timeout


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
	var cloud := Node3D.new()
	cube_root.add_child(cloud)
	cloud.global_position = above + rig.global_transform.basis.x * 1.5
	var cm := Models.mat(Color("#eef3fa"), 0.9)
	for k in 5:
		Models.sphere(cloud, randf_range(0.16, 0.24), Color("#eef3fa"), Vector3(randf_range(-0.25, 0.25), randf_range(-0.05, 0.08), randf_range(-0.25, 0.25)), cm)
	var tw := create_tween()
	tw.tween_property(cloud, "global_position", above, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	var t := 0.0
	while t < 0.8:
		for i in ids:
			var w: FieldView = views.get(int(i))
			if w == null:
				continue
			var top := w.global_position + w.world_normal() * 0.9
			_sparks(top + Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2)), w.global_position + w.world_normal() * 0.1, Color("#5cb8ff"), 1)
		await get_tree().create_timer(0.08).timeout
		t += 0.08
	for i in ids:
		var w: FieldView = views.get(int(i))
		if w != null:
			w.burst(Color("#8fd162"))
	var out := create_tween()
	out.tween_property(cloud, "scale", Vector3.ONE * 0.05, 0.35).set_ease(Tween.EASE_IN)
	out.tween_callback(cloud.queue_free)


