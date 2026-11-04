class_name World
extends Node3D
## Würfel, Felder, Kamera, Eingabe und Effekte (Verschmelzen, Meteorit).
## Wischen auf dem Würfel dreht eine Reihe (wie bei einem echten Zauberwürfel),
## Wischen daneben dreht die Ansicht. Antippen zeigt die Feld-Info.

signal field_tapped(fid: int)
signal preview_changed(info: Dictionary)   # {} = keine Vorschau
signal merged(fid: int, points: int, combo: int, stage: int)
signal disaster_shown(kind: String, fid: int)
signal deltas_shown(list: Array, gain: int)   # [{"field": id, "change": "up"|"down"|"lost"|"new"}]

const ALL_AXES = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

var rig: CameraRig
var cube_root: Node3D
var cubies: Array = []          # Node3D mit meta "pos" (Vector3i)
var views: Dictionary = {}      # Feld-ID -> FieldView
var selected := -1
var animating := false

# Eingabe
var _mode := ""                 # "", "pending", "twist", "orbit"
var _press_pos := Vector2.ZERO
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
var _pivot: Node3D
var _touches: Dictionary = {}
var _pinch_dist := 0.0
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
	Game.meteor_struck.connect(_on_meteor)
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


func select(fid: int) -> void:
	if selected >= 0 and views.has(selected):
		views[selected].set_selected(false)
	selected = fid
	if fid >= 0 and views.has(fid):
		views[fid].set_selected(true)


func _process(delta: float) -> void:
	if _mode == "" and not animating and not Game.busy and not Game.over:
		_idle += delta
		if Game.tutorial() and _idle > 1.2 and not _hinted:
			_show_hint()
	else:
		_idle = 0.0
	if _mode == "twist" and _pivot != null:
		_tw_display = lerpf(_tw_display, _tw_angle, 1.0 - exp(-delta * Balance.TWIST_FOLLOW))
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
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var d := _touch_dist()
			if _pinch_dist > 1.0 and d > 1.0:
				rig.zoom(_pinch_dist / d)
			_pinch_dist = d
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


func _touch_dist() -> float:
	var pts := _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


func _show_hint() -> void:
	_hinted = true
	var best := []
	var best_pts := 0
	for axis in 3:
		for layer in [-1, 0, 1]:
			for turns in [1, -1, 2]:
				var sim := Game.state.clone()
				sim.apply_rotation(axis, layer, turns)
				var pts := sim.merge_value()
				if pts > best_pts:
					best_pts = pts
					best = [axis, layer]
	if best.is_empty():
		return
	for cb in _slice_cubies(int(best[0]), int(best[1])):
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
	_clear_hint()
	_press_pos = pos
	_last_move_ms = Time.get_ticks_msec()
	rig.stop()
	var hit := _raycast(pos)
	if not hit.is_empty() and not animating and not Game.busy and not Game.over:
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
					_update_twist(pos)
		"pending_tap":
			if pos.distance_to(_press_pos) > Balance.DRAG_START_PX:
				_mode = "orbit"
		"twist":
			_update_twist(pos)
		"orbit":
			rig.orbit(rel, dt)


func _release(pos: Vector2) -> void:
	match _mode:
		"pending", "pending_tap":
			if pos.distance_to(_press_pos) <= Balance.DRAG_START_PX:
				field_tapped.emit(_hit_field)
		"twist":
			_finish_twist()
		"orbit":
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
		_mode = "orbit"
		return
	var sgn := 1 if best_dot > 0.0 else -1
	var t_s := Vector3(best_t) * sgn
	var k := Vector3(f.n).cross(t_s)
	var ki := Vector3i(roundi(k.x), roundi(k.y), roundi(k.z))
	_tw_axis = GameState.axis_of(ki)
	_tw_sign = ki[_tw_axis]
	_tw_layer = f.p[_tw_axis]
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
	select(-1)


func _update_twist(pos: Vector2) -> void:
	var along := (pos - _press_pos).dot(_tw_screen_dir)
	_tw_angle = _tw_sign * along / _tw_px_per_quarter * PI * 0.5
	var ax := Vector3.ZERO
	ax[_tw_axis] = 1.0
	var q := clampi(roundi(_tw_angle / (PI * 0.5)), -2, 2)
	if q != _tw_quarter:
		_tw_quarter = q
		_show_preview(q)


func _show_preview(q: int) -> void:
	if q == 0:
		_clear_preview()
		return
	var pv := Game.preview(_tw_axis, _tw_layer, q)
	var arranged: GameState = pv["arranged"]
	var lit := {}
	var mids := {}
	# Was eine Drehung bringt, zeigt nur das Tutorial. Gefahr zeigt die Vorschau immer.
	var lines: Array = arranged.moved_lines() if Game.tutorial() else []
	for line in lines:
		for g in line:
			lit[(g as FieldData).id] = true
		var mid: FieldData = line[1]
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
	tw.tween_method(setter, start, target, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	piv.basis = Basis(ax, target)
	_unparent_pivot(piv, _tw_axis, _tw_quarter)
	for fid in views:
		(views[fid] as FieldView).set_preview("", Color.WHITE)
		(views[fid] as FieldView).set_highlight(false)
		(views[fid] as FieldView).set_danger(false)
	preview_changed.emit({})
	if _tw_quarter != 0:
		Game.play_turn(_tw_axis, _tw_layer, _tw_quarter)
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
	var gs := Game.state
	var events: Array = result["events"]
	# Verschmelzen, Kombo für Kombo
	var last_combo := 0
	var merged_ids := {}
	var disaster_ids := {}
	for e in events:
		if str(e["type"]) == "disaster":
			for i in e["hit"]:
				disaster_ids[int(i)] = true
	for e in events:
		if str(e["type"]) != "merge":
			continue
		merged_ids[int(e["field"])] = true
		for o in e["others"]:
			merged_ids[int(o)] = true
		var combo := int(e["combo"])
		if combo != last_combo and last_combo > 0:
			refresh_all(null, disaster_ids)
			await get_tree().create_timer(0.35).timeout
		last_combo = combo
		await _merge_fx(e)
	if last_combo > 0:
		await get_tree().create_timer(0.25).timeout
	# Verschmutzung und Nachwachsen
	for e in events:
		if str(e["type"]) == "polluted":
			var v: FieldView = views.get(int(e["field"]))
			if v != null:
				_sparks(v.global_position + v.world_normal() * 0.3, Vector3.ZERO, Color("#6b6e78"), 4)
	# Katastrophe
	for e in events:
		if str(e["type"]) == "disaster":
			refresh_all(null, disaster_ids)
			await _disaster_fx(e)
	refresh_all()
	var changes: Array = []
	for f in gs.fields:
		if merged_ids.has(f.id) or disaster_ids.has(f.id):
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
		elif kind == "flood":
			v.flood(dur * 1.2)
			_sparks(p, Vector3.ZERO, Color("#7cc8ff"), 6)
		else:
			v.burn(dur)
			_sparks(p, Vector3.ZERO, Color("#ff8a3d"), 7)
	if kind == "quake":
		rig.shake(1.6)
	elif kind == "fire":
		rig.shake(0.4)
	else:
		rig.shake(0.3)
	await get_tree().create_timer(dur * (1.25 if kind == "flood" else 1.05)).timeout
	for i in hit:
		var v: FieldView = views.get(int(i))
		if v != null:
			v.set_danger(false)
			if kind == "fire":
				_sparks(v.global_position + v.world_normal() * 0.3, v.global_position + v.world_normal() * 1.0, Color("#6b6e78"), 4)


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


## Meteorit: fällt glühend vom Himmel, schlägt ein, Feld und Nachbarn werden zu Erde.
func _on_meteor(fid: int, ids: Array) -> void:
	var v: FieldView = views.get(fid)
	if v == null:
		return
	animating = true
	_clear_hint()
	select(-1)
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
	for i in ids:
		var w: FieldView = views.get(int(i))
		if w != null and w != v:
			w.burst(Color("#c98a5a"))
	refresh_all()
	await get_tree().create_timer(0.5).timeout
	animating = false


