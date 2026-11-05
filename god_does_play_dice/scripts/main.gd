extends Node
## Hauptszene: baut Welt und Oberfläche auf und skaliert die Oberfläche passend zum Bildschirm.
## Mit „-- --shots=ORDNER“ gestartet, macht das Spiel eine Reihe Screenshots und beendet sich.

const BASE_SHORT_SIDE := 600.0   # logische Pixel an der kurzen Bildschirmseite (Handy zuerst)

var world: World
var ui: GameUI
var _last_miss_why := "-"      # Screenshots: Grund des letzten Fehlversuchs ("", "repeat" oder "spent")


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
	# Tutorial wie über das Menü neu gestartet: der erste Zug muss von selbst laufen
	Game.restart_tutorial()
	await _wait(1.0)
	await _shot(dir, "00a_tutorial_start")
	await _wait(4.5)
	await _shot(dir, "00b_tutorial_nach_auto")
	print("TUTORIAL-CHECK step=%d score=%d" % [Game.tutorial_step, Game.state.score])
	# Schritt 2: der eigene Zug (hier vom Skript gespielt). Danach erblüht die Erde, man spielt gleich weiter.
	for i in 30:
		if not Game.tutorial() or world.auto_twist(0, 1, 1):
			break
		await _wait(0.2)
	await _wait(2.6)
	if Game.tutorial():
		push_warning("Screenshots: Tutorial-Zug lief nicht, beende das Tutorial direkt")
		Game.finish_tutorial()
	await _wait(1.6)
	await _shot(dir, "00c_nach_tutorial")
	print("BLOOM-CHECK tutorial=%s erde=%d natur=%.0f%% punkte=%d" % [str(Game.tutorial()), Game.state.count(0), Game.state.nature_share() * 100.0, Game.state.score])
	# Langes Drücken auf Regen: die Erklärkarte
	ui.debug_show_tooltip("rain")
	await _wait(0.6)
	await _shot(dir, "00d_erklaerung")
	ui.debug_close_all()
	ui.debug_reveal_all()          # ab hier wie ein Spieler, der schon alles kennt
	# Echte Eingabe wie am Handy: Regen und eine Drehung, die eine neue Reihe bildet
	await _rain_check(dir)
	await _merge_check()
	ui.debug_close_all()
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
	var rain_fid := int(_rain_target()["fid"])
	print("REGEN-TOUR gegossen=%s" % str(rain_fid >= 0 and Game.use_bonus("rain", rain_fid)))
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
	await _wait(3.2)
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


# =============================================================================
# Prüfung mit echter Eingabe (Input.parse_input_event, wie Finger am Handy)
# =============================================================================

## Ein Finger tippt auf p (Koordinaten der Oberfläche). Wie am Handy: ScreenTouch, daraus macht Godot
## die Maus (input_devices/pointing/emulate_mouse_from_touch). Geht durch Oberfläche und 3D-Ansicht.
func _touch(p: Vector2, hold: float = 0.08) -> void:
	var wp: Vector2 = get_tree().root.get_final_transform() * p
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = wp
	t.pressed = true
	Input.parse_input_event(t)
	await get_tree().process_frame
	await get_tree().process_frame
	await _wait(hold)
	var r := InputEventScreenTouch.new()
	r.index = 0
	r.position = wp
	r.pressed = false
	Input.parse_input_event(r)
	await get_tree().process_frame
	await get_tree().process_frame


## Liegt dieser Punkt unter der Oberfläche (Leiste, Karte, oben)?
func _under_ui(pos: Vector2) -> bool:
	var rects: Array = [ui.dock.get_global_rect().grow(12.0), ui.top.get_global_rect().grow(12.0)]
	for c in [ui.mode_card, ui.toast, ui.tip_card]:
		var cc: Control = c
		if cc.visible:
			rects.append(cc.get_global_rect().grow(12.0))
	for r in rects:
		var rr: Rect2 = r
		if rr.has_point(pos):
			return true
	return false


## Ein sichtbares Feld, das man antippen kann. want: "target" = ein Regenziel, "other" = keins. {"fid", "pos"}
func _rain_target(want: String = "target", skip: int = -1) -> Dictionary:
	var tg := Game.state.rain_targets()
	var mid := get_viewport().get_visible_rect().size * 0.5
	var best := -1
	var best_pos := Vector2.ZERO
	var best_d := INF
	for f in Game.state.fields:
		var fid: int = (f as FieldData).id
		if fid == skip or tg.has(fid) != (want == "target"):
			continue
		var fs := world.field_screen(fid)
		if not bool(fs["visible"]):
			continue
		var pos: Vector2 = fs["pos"]
		if _under_ui(pos):
			continue
		var hit: Dictionary = world._raycast(pos)
		if int(hit.get("field", -1)) != fid:
			continue
		var d := pos.distance_to(mid)
		if d < best_d:
			best_d = d
			best = fid
			best_pos = pos
	return {"fid": best, "pos": best_pos}


func _rain_check(dir: String) -> void:
	# Auf CI (Software-Grafik, wenige Bilder pro Sekunde) kann zwischen Drücken und Loslassen mehr als
	# eine Sekunde echte Zeit vergehen: Dann hielte world.gd das Antippen für Halten (Ansicht drehen).
	var hold_s := Balance.HOLD_TO_ORBIT_SECONDS
	Balance.HOLD_TO_ORBIT_SECONDS = 30.0
	await _rain_steps(dir)
	Balance.HOLD_TO_ORBIT_SECONDS = hold_s


func _rain_steps(dir: String) -> void:
	Game.new_game(4242, 1, 0)
	ui.debug_close_all()
	await _wait(1.6)
	Game.state.rain = 4
	Game.state_changed.emit()
	await _wait(0.8)
	# 1. Regen in der Leiste antippen: Der Regen ist gewählt, Felder leuchten
	await _touch(ui.rain_btn.get_global_rect().get_center())
	await _wait(0.6)
	var mode_ok := ui.bonus_mode == "rain" and ui.mode_card.visible
	await _shot(dir, "00e_regen_echt")
	# 2. Ein leuchtendes Feld antippen: Es wächst, ein Regen ist verbraucht, Regen bleibt gewählt
	var t := _rain_target()
	var fid := int(t["fid"])
	var before := -1
	var after := -1
	var rain_before := Game.state.rain
	if fid >= 0:
		before = (Game.state.fields[fid] as FieldData).stage
		await _touch(t["pos"])
		await _wait(0.5)
		await _settle(6.0)
		after = (Game.state.fields[fid] as FieldData).stage
	var ok := mode_ok and fid >= 0 and after >= before + 1 and Game.state.rain == rain_before - 1 and not Game.busy and not world.animating and ui.bonus_mode == "rain"
	print("RAIN-CHECK ok=%s before=%d after=%d rain=%d mode=%s fid=%d step=leuchtendes_feld" % [str(ok), before, after, Game.state.rain, ui.bonus_mode, fid])
	# 3. Ein Feld, das nicht leuchtet: Es passiert nichts, aber eine Meldung sagt, wohin der Regen geht
	var w := _rain_target("other")
	var wid := int(w["fid"])
	var rain_w := Game.state.rain
	var told := false
	if wid >= 0:
		var st_w := (Game.state.fields[wid] as FieldData).stage
		await _touch(w["pos"])
		for i in 60:
			await get_tree().process_frame
			if ui.toast.visible and ui.toast_label.text.begins_with("Regen geht"):
				told = true
			for m in ui._toasts:
				if str((m as Dictionary)["text"]).begins_with("Regen geht"):
					told = true
			if told:
				break
		told = told and (Game.state.fields[wid] as FieldData).stage == st_w and Game.state.rain == rain_w
	print("RAIN-CHECK ok=%s fid=%d rain=%d step=falsches_feld" % [str(wid < 0 or told), wid, Game.state.rain])
	await _wait(1.0)
	# 4. Zweimal schnell hintereinander gießen: Das zweite Antippen kommt während der Animation und wird danach eingesetzt
	var a := _rain_target()
	var b := _rain_target("target", int(a["fid"]))
	var ok2 := false
	var a_st := -1
	var b_st := -1
	if int(a["fid"]) >= 0 and int(b["fid"]) >= 0 and Game.state.rain >= 2:
		var a0 := (Game.state.fields[int(a["fid"])] as FieldData).stage
		var b0 := (Game.state.fields[int(b["fid"])] as FieldData).stage
		var r0 := Game.state.rain
		await _touch(a["pos"])
		await _wait(0.25)
		await _touch(b["pos"])
		await _wait(1.0)
		await _settle(8.0)
		a_st = (Game.state.fields[int(a["fid"])] as FieldData).stage
		b_st = (Game.state.fields[int(b["fid"])] as FieldData).stage
		ok2 = a_st > a0 and b_st > b0 and Game.state.rain == r0 - 2
	print("RAIN-CHECK ok=%s a=%d b=%d rain=%d step=schnell_hintereinander" % [str(ok2), a_st, b_st, Game.state.rain])
	# 5. Regen in der Leiste noch einmal: abgewählt
	await _settle(6.0)
	await _touch(ui.rain_btn.get_global_rect().get_center())
	await _wait(0.5)
	print("RAIN-CHECK ok=%s mode=%s step=abwaehlen" % [str(ui.bonus_mode == ""), ui.bonus_mode])


## Warten, bis keine Runde mehr läuft und nichts mehr animiert (höchstens sec Sekunden).
func _settle(sec: float) -> void:
	var t := 0.0
	while t < sec and (Game.busy or world.animating or ui._queued_tap >= 0):
		await _wait(0.1)
		t += 0.1
	await _wait(0.2)


func _on_tour_miss(_fid: int, _count: int, why: String) -> void:
	_last_miss_why = why


## Eine Drehung bildet oben eine neue Reihe aus 3 Wiesen (Einfach): Sie muss wachsen.
## Danach hin und zurück (zählt nicht), mit einem anderen Zug dazwischen (dieselbe zusammen aufgestiegene
## Reihe zählt trotzdem nicht: kein Hochzüchten) und eine Reihe mit einem anderen Feld (zählt).
func _merge_check() -> void:
	ui.debug_close_all()
	Game.new_game(4243, 1, 0)
	await _wait(1.0)
	var gs := Game.state
	for f in gs.fields:
		(f as FieldData).stage = 0
		(f as FieldData).burning = false
	gs.field_at(Vector3i(-1, 1, 1), Vector3i(0, 1, 0)).stage = 1
	gs.field_at(Vector3i(0, 1, 1), Vector3i(0, 1, 0)).stage = 1
	var third: FieldData = gs.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1))
	third.stage = 1          # kommt mit der Drehung x = 1 nach oben in die Reihe
	Game.state_changed.emit()
	if not world.miss_shown.is_connected(_on_tour_miss):
		world.miss_shown.connect(_on_tour_miss)
	await _wait(0.6)
	var steps := [[0, 1, 1, "neue_reihe", true], [0, 1, -1, "weg", false], [0, 1, 1, "hin_und_zurueck", false],
		[0, 1, -1, "weg", false], [1, -1, 1, "anderer_zug", false], [0, 1, 1, "nach_anderem_zug", false],
		[0, 1, 1, "andere_reihe", true]]
	var grower: FieldData = third
	for st in steps:
		Game.state.misses = 0
		_last_miss_why = "-"
		if str(st[3]) == "andere_reihe":
			# Ein anderes Feld kommt mit der Drehung x = 1 in die Reihe (dieselbe Stufe wie die beiden anderen)
			grower = gs.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1))
			grower.stage = (gs.field_at(Vector3i(0, 1, 1), Vector3i(0, 1, 0)) as FieldData).stage
			grower.burning = false
			Game.state_changed.emit()
			await _wait(0.4)
		var grow0 := grower.stage
		var score0 := Game.state.score
		var started := false
		for i in 30:
			if world.auto_twist(int(st[0]), int(st[1]), int(st[2])):
				started = true
				break
			await _wait(0.2)
		await _wait(0.6)
		await _settle(6.0)
		var gain := Game.state.score - score0
		var want_grow: bool = st[4]
		var step_name: String = st[3]
		var ok := started and not Game.busy and not world.animating
		if want_grow:
			ok = ok and gain > 0 and grower.stage > grow0 and _last_miss_why == "-"
		elif step_name == "hin_und_zurueck":
			ok = ok and gain == 0 and _last_miss_why == "repeat"
		elif step_name == "nach_anderem_zug":
			ok = ok and gain == 0 and _last_miss_why == "spent"
		if want_grow or step_name == "hin_und_zurueck" or step_name == "nach_anderem_zug":
			print("MERGE-CHECK ok=%s gain=%d stage=%d misses=%d why=%s step=%s" % [str(ok), gain, grower.stage, Game.state.misses, _last_miss_why, step_name])
	Game.state.misses = 0


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
