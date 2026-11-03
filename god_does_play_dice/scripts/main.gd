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
	await _wait(0.3)
	var fid := _visible_field(true)
	world.debug_begin_twist(fid, Vector2(1, 0.15), 0.62)
	await _wait(0.6)
	await _shot(dir, "03_wischen")
	world.debug_end_twist()
	await _wait(2.2)
	await _shot(dir, "04_nach_drehung")
	# Eine Gefahr erzwingen, damit man sie sieht
	var target: FieldData = Game.state.fields[_visible_field(true)]
	Game.state.hazards.append({"type": "meteor", "p": target.p, "n": target.n, "timer": 3})
	var other: FieldData = Game.state.fields[_visible_field(false)]
	if other != target:
		Game.state.hazards.append({"type": "storm", "p": other.p, "n": other.n, "timer": 2})
	Game.state_changed.emit()
	await _wait(1.0)
	await _shot(dir, "05_gefahren")
	for i in 3:
		world.wait_turn()
		await _wait(2.0)
	await _shot(dir, "06_nach_einschlag")
	ui.debug_show_field(_visible_field(true))
	await _wait(0.6)
	await _shot(dir, "07_info")
	ui.debug_close_all()
	Game.over = true
	Game.game_over.emit()
	await _wait(0.7)
	await _shot(dir, "08_ende")
	get_tree().quit()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, shot_name])
	print("Screenshot: ", shot_name)


## Ein gut sichtbares Feld (zur Kamera gewandt), wahlweise bewohnt.
func _visible_field(settled: bool) -> int:
	var cam_pos := world.rig.cam.global_position
	var best := 0
	var best_score := -INF
	for f in Game.state.fields:
		var v: FieldView = world.views.get(f.id)
		if v == null:
			continue
		var score := v.world_normal().dot((cam_pos - v.global_position).normalized())
		if settled and f.settled():
			score += 0.5
		if score > best_score:
			best_score = score
			best = f.id
	return best
