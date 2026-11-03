class_name World
extends Node3D
## Würfel, Felder, Kamera und Eingabe auf dem Würfel.
## Die Würfelchen sind eigene Knoten; Felder hängen an ihrem Würfelchen.
## Eine Drehung hängt die Würfelchen der Scheibe in einen Pivot-Knoten, dreht ihn und rastet danach ein.

signal field_tapped(fid: int)
signal field_info(fid: int)
signal preview_changed(preview_state: GameState)

const HUMAN := GameState.HUMAN
const ALL_AXES = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

var rig: CameraRig
var cube_root: Node3D
var cubies: Array = []        # Node3D mit meta "pos" (Vector3i)
var views: Dictionary = {}    # Feld-ID -> FieldView
var selected := -1
var busy := false             # Animation läuft
var preview := {}             # {"axis", "layer", "net"} im Drehmodus

# Eingabe
var _press := false
var _press_pos := Vector2.ZERO
var _press_ms := 0
var _dragging := false
var _long_fired := false
var _middle := false
var _touches: Dictionary = {}
var _pinch_dist := 0.0
var _pinch_mid_y := 0.0


func _ready() -> void:
	_setup_environment()
	rig = CameraRig.new()
	add_child(rig)
	rig.basis = CameraRig.face_basis(Vector3(GameState.FACE_NORMALS[HUMAN]))
	cube_root = Node3D.new()
	add_child(cube_root)
	Game.new_game_started.connect(rebuild)
	Game.state_changed.connect(_on_state_changed)
	Game.rotations_to_play.connect(_play_queue)
	rebuild()


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#bfe3f2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff6e8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# =============================================================================
# Aufbau und Aktualisierung
# =============================================================================

func rebuild() -> void:
	for c in cube_root.get_children():
		c.queue_free()
	cubies.clear()
	views.clear()
	selected = -1
	preview = {}
	busy = false
	var gs := Game.state
	var by_pos := {}
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
				Models.box(cb, Vector3(0.97, 0.97, 0.97), Color("#3b3542"), Vector3.ZERO, Vector3.ZERO, Models.mat(Color("#3b3542"), 0.0, 0.6))
				cubies.append(cb)
				by_pos[GameState.pos_key(p, Vector3i.ZERO)] = cb
	for f in gs.fields:
		var cb: Node3D = by_pos[GameState.pos_key(f.p, Vector3i.ZERO)]
		var v := FieldView.new()
		cb.add_child(v)
		v.transform = Transform3D(_face_basis(f.n), Vector3(f.n) * 0.485)
		v.build(f)
		views[f.id] = v
	refresh_all()
	rig.focus_face(Vector3(GameState.FACE_NORMALS[HUMAN]))


static func _face_basis(n: Vector3i) -> Basis:
	var a := GameState.axis_of(n)
	var y := Vector3(n)
	var x := Vector3(GameState.unit((a + 1) % 3, 1))
	var z := x.cross(y)
	return Basis(x, y, z)


func _on_state_changed() -> void:
	if busy or not preview.is_empty():
		return
	refresh_all()


func refresh_all(gs: GameState = null) -> void:
	if gs == null:
		gs = Game.state
	for f in gs.fields:
		var v: FieldView = views.get(f.id)
		if v == null:
			continue
		var mark := ""
		if not f.is_center and not Game.over:
			if f.owner == HUMAN and gs.upgrade_error(HUMAN, f) == "":
				mark = "↑"
			elif f.owner < 0 and gs.buy_field_error(HUMAN, f) == "":
				mark = "+"
		v.refresh(f, gs, mark, HUMAN)
		v.set_selected(f.id == selected)


func select(fid: int) -> void:
	if selected >= 0 and views.has(selected):
		views[selected].set_selected(false)
	selected = fid
	if fid >= 0 and views.has(fid):
		views[fid].set_selected(true)


func _process(_delta: float) -> void:
	# Schilder nur auf Seiten zeigen, die zur Kamera schauen
	var cam_pos := rig.cam.global_position
	for fid in views:
		var v: FieldView = views[fid]
		var to_cam := (cam_pos - v.global_position).normalized()
		v.set_labels_visible(v.world_normal().dot(to_cam) > 0.25)
	# Langes Drücken = Feldinfo
	if _press and not _dragging and not _long_fired:
		if Time.get_ticks_msec() - _press_ms > int(Balance.LONG_PRESS_SECONDS * 1000.0):
			_long_fired = true
			var fid := pick(_press_pos)
			if fid >= 0:
				field_info.emit(fid)


## Bildschirmposition eines Felds für Blasen. {"pos": Vector2, "visible": bool}
func field_screen(fid: int) -> Dictionary:
	var v: FieldView = views.get(fid)
	if v == null:
		return {"pos": Vector2.ZERO, "visible": false}
	var wp := v.label_world_pos()
	var cam_pos := rig.cam.global_position
	var vis := not rig.cam.is_position_behind(wp) and v.world_normal().dot((cam_pos - wp).normalized()) > 0.1
	return {"pos": rig.cam.unproject_position(wp), "visible": vis}


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
			_press = false
			_pinch_dist = _touch_dist()
			_pinch_mid_y = _touch_mid_y()
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var d := _touch_dist()
			var my := _touch_mid_y()
			if _pinch_dist > 1.0 and d > 1.0:
				rig.zoom(_pinch_dist / d)
			rig.pan_height(my - _pinch_mid_y)
			_pinch_dist = d
			_pinch_mid_y = my
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					if _touches.size() >= 2:
						return
					_press = true
					_press_pos = mb.position
					_press_ms = Time.get_ticks_msec()
					_dragging = false
					_long_fired = false
				else:
					if _press and not _dragging and not _long_fired and _touches.size() < 2:
						_tap(mb.position)
					_press = false
			MOUSE_BUTTON_RIGHT:
				if mb.pressed:
					var fid := pick(mb.position)
					if fid >= 0:
						field_info.emit(fid)
			MOUSE_BUTTON_MIDDLE:
				_middle = mb.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					rig.zoom(0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					rig.zoom(1.1)
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _middle:
			rig.pan_height(mm.relative.y)
		elif _press and _touches.size() < 2:
			if not _dragging and mm.position.distance_to(_press_pos) > Balance.TAP_MAX_MOVE_PX:
				_dragging = true
			if _dragging:
				rig.orbit(mm.relative.x, mm.relative.y)
		return
	if event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		if mg.factor > 0.0:
			rig.zoom(1.0 / mg.factor)
		return
	if event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		rig.orbit(-pg.delta.x * 8.0, -pg.delta.y * 8.0)


func _touch_dist() -> float:
	var pts := _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


func _touch_mid_y() -> float:
	var pts := _touches.values()
	if pts.size() < 2:
		return 0.0
	return ((pts[0] as Vector2).y + (pts[1] as Vector2).y) * 0.5


func _tap(pos: Vector2) -> void:
	var fid := pick(pos)
	if fid >= 0:
		field_tapped.emit(fid)
		return
	# Tipp neben den Würfel: Ansicht um eine Seite in diese Richtung drehen
	var c := rig.cam.unproject_position(Vector3.ZERO)
	var d := pos - c
	if d.length() < 40.0:
		return
	if absf(d.x) > absf(d.y):
		rig.turn(Vector3.UP, signf(d.x) * PI * 0.5)
	else:
		rig.turn(Vector3.RIGHT, signf(d.y) * PI * 0.5)


func pick(screen_pos: Vector2) -> int:
	var cam := rig.cam
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 100.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return -1
	var col: Object = hit.get("collider")
	if col != null and col.has_meta("field_id"):
		return int(col.get_meta("field_id"))
	return -1


func focus_player(pid: int) -> void:
	rig.focus_face(Vector3(GameState.FACE_NORMALS[pid]))


# =============================================================================
# Drehen
# =============================================================================

static func _is_center_cubie(p: Vector3i) -> bool:
	var c := 0
	for a in 3:
		if p[a] != 0:
			c += 1
	return c == 1


func _slice_cubies(axis: int, layer: int) -> Array:
	var out: Array = []
	for cb in cubies:
		var p: Vector3i = cb.get_meta("pos")
		if p[axis] == layer and not _is_center_cubie(p):
			out.append(cb)
	return out


## Scheibe animiert drehen und danach einrasten. turns: 1, −1 oder 2 (bzw. −2).
func _animate_slice(axis: int, layer: int, turns: int, duration: float) -> void:
	if turns == 0:
		return
	var moving := _slice_cubies(axis, layer)
	var pivot := Node3D.new()
	cube_root.add_child(pivot)
	for cb in moving:
		(cb as Node3D).reparent(pivot, true)
	var ax := Vector3.ZERO
	ax[axis] = 1.0
	var total := turns * PI * 0.5
	var setter := func(t: float) -> void:
		pivot.basis = Basis(ax, t)
	var tw := create_tween()
	tw.tween_method(setter, 0.0, total, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	pivot.basis = Basis(ax, total)
	var d := 1 if turns > 0 else -1
	for cb in moving:
		var node := cb as Node3D
		node.reparent(cube_root, true)
		node.position = node.position.round()
		var b := node.basis
		node.basis = Basis(b.x.round(), b.y.round(), b.z.round())
		var p: Vector3i = node.get_meta("pos")
		for i in absi(turns):
			p = GameState.rv(p, axis, d)
		node.set_meta("pos", p)
	pivot.queue_free()


func _flash_slice(axis: int, layer: int, color: Color, seconds: float) -> void:
	for cb in _slice_cubies(axis, layer):
		for child in (cb as Node3D).get_children():
			if child is FieldView:
				(child as FieldView).flash(color, seconds)


## Alle vorgemerkten Drehungen nacheinander abspielen (am Takt-Ende).
func _play_queue() -> void:
	if busy:
		return
	busy = true
	select(-1)
	while true:
		var r := Game.pop_rotation()
		if r.is_empty():
			break
		var axis := int(r["axis"])
		var layer := int(r["layer"])
		var turns := int(r["turns"])
		var color: Color = Game.state.players[int(r["pid"])].color
		_flash_slice(axis, layer, color, 0.45 + Balance.ROTATION_ANIM_SECONDS)
		await get_tree().create_timer(0.4).timeout
		await _animate_slice(axis, layer, turns, Balance.ROTATION_ANIM_SECONDS * absi(turns) * 0.75)
		refresh_all()
	busy = false
	refresh_all()
	Game.rotations_done()


## Drehmodus: Vorschau um 90° weiterdrehen. d = +1/−1.
func preview_turn(axis: int, layer: int, d: int) -> void:
	if busy:
		return
	busy = true
	if not preview.is_empty() and (int(preview["axis"]) != axis or int(preview["layer"]) != layer):
		await _undo_preview_anim()
	if preview.is_empty():
		preview = {"axis": axis, "layer": layer, "net": 0}
	var net := ((int(preview["net"]) + d) % 4 + 4) % 4
	if net == 3:
		net = -1
	preview["net"] = net
	await _animate_slice(axis, layer, d, Balance.PREVIEW_ANIM_SECONDS)
	var ps := Game.state.clone()
	if net != 0:
		ps.apply_rotation(axis, layer, net)
	refresh_all(ps)
	busy = false
	preview_changed.emit(ps)


func _undo_preview_anim() -> void:
	if preview.is_empty():
		return
	var net := int(preview["net"])
	var axis := int(preview["axis"])
	var layer := int(preview["layer"])
	preview = {}
	if net != 0:
		await _animate_slice(axis, layer, -net, Balance.PREVIEW_ANIM_SECONDS * absi(net))
	refresh_all()


## Vorschau verwerfen (Ansicht zurückdrehen).
func cancel_preview() -> void:
	if busy:
		return
	busy = true
	await _undo_preview_anim()
	busy = false
	preview_changed.emit(Game.state)


## Vorschau übernehmen: Ansicht zurückdrehen und die Drehung zurückgeben ({} wenn keine).
func take_preview() -> Dictionary:
	if busy or preview.is_empty():
		return {}
	var r := preview.duplicate()
	busy = true
	await _undo_preview_anim()
	busy = false
	if int(r["net"]) == 0:
		return {}
	return r


## Die 12 Pfeile rund um die vordere Seite: [{"pos", "text", "axis", "layer", "d"}]
func rotate_arrows() -> Array:
	var cb := rig.global_transform.basis
	var n := _best_axis(cb.z, [])
	var u := _best_axis(cb.x, [n, -n])
	var v := _best_axis(cb.y, [n, -n, u, -u])
	var out: Array = []
	var cam := rig.cam
	var nf := Vector3(n) * 1.5
	# Reihen: Drehung um die v-Achse
	var av := GameState.axis_of(v)
	var sv := v[av]
	var d_right := 1 if GameState.rv(n, av, 1) == u else -1
	for t in [1, 0, -1]:
		var row_pos := Vector3(v) * float(t)
		out.append({"pos": cam.unproject_position(nf + row_pos - Vector3(u) * 2.15), "text": "←", "axis": av, "layer": t * sv, "d": -d_right})
		out.append({"pos": cam.unproject_position(nf + row_pos + Vector3(u) * 2.15), "text": "→", "axis": av, "layer": t * sv, "d": d_right})
	# Spalten: Drehung um die u-Achse
	var au := GameState.axis_of(u)
	var su := u[au]
	var d_up := 1 if GameState.rv(n, au, 1) == v else -1
	for s in [-1, 0, 1]:
		var col_pos := Vector3(u) * float(s)
		out.append({"pos": cam.unproject_position(nf + col_pos + Vector3(v) * 2.15), "text": "↑", "axis": au, "layer": s * su, "d": d_up})
		out.append({"pos": cam.unproject_position(nf + col_pos - Vector3(v) * 2.15), "text": "↓", "axis": au, "layer": s * su, "d": -d_up})
	return out


static func _best_axis(dir: Vector3, exclude: Array) -> Vector3i:
	var best := Vector3i(0, 0, 1)
	var best_dot := -INF
	for a in ALL_AXES:
		var ai: Vector3i = a
		if exclude.has(ai):
			continue
		var dt := Vector3(ai).dot(dir)
		if dt > best_dot:
			best_dot = dt
			best = ai
	return best
