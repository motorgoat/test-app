extends Node
## Hauptszene: baut Welt und Oberfläche auf und skaliert die Oberfläche passend zum Bildschirm.
## Mit „-- --shots=ORDNER“ gestartet, macht das Spiel eine Reihe Screenshots und beendet sich.

const BASE_SHORT_SIDE := 600.0   # logische Pixel an der kurzen Bildschirmseite (Handy zuerst)

var world: World
var ui: GameUI


func _ready() -> void:
	_apply_scale()
	get_tree().root.size_changed.connect(_apply_scale)
	world = World.new()
	world.name = "World"
	add_child(world)
	ui = GameUI.new()
	ui.name = "UI"
	add_child(ui)
	ui.setup(world)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots(a.substr(8))


func _apply_scale() -> void:
	var win := get_tree().root
	var s := win.size
	var f := clampf(minf(float(s.x), float(s.y)) / BASE_SHORT_SIDE, 1.0, 3.0)
	if absf(win.content_scale_factor - f) > 0.01:
		win.content_scale_factor = f


# =============================================================================
# Automatische Screenshots (für die Prüfung in der GitHub-Action)
# =============================================================================

func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Game.new_game(4242)
	ui.debug_close_all()
	await _wait(1.5)
	await _shot(dir, "01_start")
	ui.debug_show_help()
	await _wait(0.7)
	await _shot(dir, "02_hilfe")
	ui.debug_close_all()
	await _wait(2.0)
	await _shot(dir, "03_tipp")
	var fid := _visible_field()
	world.debug_begin_twist(fid, Vector2(1, 0.15), 0.62)
	await _wait(1.0)
	await _shot(dir, "04_wischen")
	world.debug_end_twist()
	await _wait(2.6)
	await _shot(dir, "05_nach_drehung")
	# Eine Dreierreihe Wiesen auf der sichtbaren Seite bauen und verschmelzen lassen
	for f in _visible_row():
		(f as FieldData).stage = 1
		Game.state.moved[(f as FieldData).id] = true
	Game.state_changed.emit()
	await _wait(0.8)
	await _shot(dir, "06_reihe")
	world.wait_turn()
	await _wait(0.3)
	await _shot(dir, "07_verschmelzen")
	await _wait(2.2)
	await _shot(dir, "08_danach")
	# Boni: Regen auf ein Feld, Blitz auf eine Reihe
	Game.state.rain = 2
	Game.state.bolts = 1
	Game.state_changed.emit()
	await _wait(0.5)
	Game.use_bonus("rain", _visible_field(1))
	await _wait(0.9)
	await _shot(dir, "09_regen")
	await _wait(2.4)
	Game.use_bonus("bolt", _visible_corner(), [])
	await _wait(0.35)
	await _shot(dir, "10_blitz")
	await _wait(2.4)
	await _shot(dir, "11_spaeter")
	ui.debug_show_field(_visible_field())
	await _wait(0.6)
	await _shot(dir, "12_info")
	ui.debug_close_all()
	# Brand: 3. Fehlversuch. Alles Erde, nur die sichtbare Seite hat 9 verschiedene Stufen (nichts kann verschmelzen)
	Game.new_game(777)
	await _wait(1.0)
	var face: Vector3i = (Game.state.fields[_visible_field()] as FieldData).n
	var k := 0
	for f in Game.state.fields:
		var fd: FieldData = f
		fd.stage = 0
		if fd.n == face:
			k += 1
			fd.stage = k
	Game.state.misses = Balance.FIRE_AFTER - 1
	Game.state.best_stage = Balance.MAX_STAGE
	Game.state_changed.emit()
	await _wait(0.8)
	world.debug_begin_twist(_visible_field(), Vector2(1, 0.15), 0.62)
	await _wait(1.0)
	await _shot(dir, "13_brand_vorschau")
	world.debug_end_twist()
	await _wait(1.6)
	await _shot(dir, "14_brand")
	await _wait(2.5)
	# Ende des Modus 40 Drehungen
	Game.new_game(4242, 0)
	await _wait(1.0)
	Game.state.twists = Balance.MAX_TWISTS - 1
	Game.state_changed.emit()
	world.debug_begin_twist(_visible_field(), Vector2(1, 0.15), 0.62)
	await _wait(0.6)
	world.debug_end_twist()
	await _wait(3.0)
	await _shot(dir, "16_ende")
	get_tree().quit()


## Alle Felder neu belegen (für die Screenshots).
func _fill(stage_of: Callable) -> void:
	for f in Game.state.fields:
		(f as FieldData).stage = int(stage_of.call(f))
		(f as FieldData).burning = false
	Game.state_changed.emit()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	img.save_jpg("%s/%s.jpg" % [dir, shot_name], 0.85)
	print("Screenshot: ", shot_name)


## Ein gut sichtbares Feld (zur Kamera gewandt). Mit min_stage 1: kein leeres Feld, mit 0: nur leere Erde.
func _visible_field(only: int = -1) -> int:
	var cam_pos := world.rig.cam.global_position
	var best := 0
	var best_score := -INF
	for f in Game.state.fields:
		var v: FieldView = world.views.get(f.id)
		if v == null:
			continue
		if (only == 0 and f.stage != 0) or (only == 1 and f.stage == 0):
			continue
		var score := v.world_normal().dot((cam_pos - v.global_position).normalized())
		if score > best_score:
			best_score = score
			best = f.id
	return best


## Ein gut sichtbares Eckfeld (für den Blitz).
func _visible_corner() -> int:
	var cam_pos := world.rig.cam.global_position
	var best := 0
	var best_score := -INF
	for f in Game.state.fields:
		var v: FieldView = world.views.get(f.id)
		if v == null or Game.state.corner_diagonal(f).is_empty():
			continue
		var score := v.world_normal().dot((cam_pos - v.global_position).normalized())
		if score > best_score:
			best_score = score
			best = f.id
	return best


## Die oberste Reihe der Seite, die am meisten zur Kamera schaut.
func _visible_row() -> Array:
	var cam_dir := world.rig.cam.global_position.normalized()
	var best := Vector3i(0, 1, 0)
	var best_dot := -INF
	for n in GameState.FACE_NORMALS:
		var nv: Vector3i = n
		var d := Vector3(nv).dot(cam_dir)
		if d > best_dot:
			best_dot = d
			best = nv
	var a := GameState.axis_of(best)
	var u := (a + 1) % 3
	var v := (a + 2) % 3
	var out: Array = []
	for t in [-1, 0, 1]:
		var p := Vector3i.ZERO
		p[a] = best[a]
		p[u] = t
		p[v] = 1 if a != 1 else 0
		var f := Game.state.field_at(p, best)
		if f != null:
			out.append(f)
	return out
