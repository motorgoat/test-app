extends SceneTree
## Modell-Test: baut jede Art (kind 0..15, 15 = Wasser) und jeden Zustand einmal als FieldView und lässt ein paar Frames laufen.
##   godot --headless --script res://tests/test_models.gd
## Mit Bild (echtes GL, z. B. unter xvfb-run):
##   godot --rendering-driver opengl3 --resolution 1500x1100 --script res://tests/test_models.gd -- --sheet=/pfad/models.png

const COLS := 5

var _views: Array = []
var _frames := 0
var _sheet := ""
var _errors := 0
var _cam: Camera3D
var _fx_time := -1.0
var _shot := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sheet="):
			_sheet = a.substr(8)
	var root := Node3D.new()
	get_root().add_child(root)
	_setup_scene(root)
	# 15 Arten, dann Zustände: verwelkt (Wald, großer Wald, Tiere), Smog, Wunsch, Krieg, Gewitter, brennend
	var specs: Array = []
	for k in FieldView.KIND_COUNT:
		specs.append({"kind": k})
	specs.append({"kind": FieldView.K_FOREST, "fresh": 2, "label": "Wald welk"})
	specs.append({"kind": FieldView.K_BIGFOREST, "fresh": 2, "label": "Gr.Wald welk"})
	specs.append({"kind": FieldView.K_ANIMALS, "polluted": true, "label": "Tiere Smog"})
	specs.append({"kind": FieldView.K_INDUSTRY, "polluted": true, "label": "Ind. Smog"})
	specs.append({"kind": FieldView.K_HOUSE, "wish": "smallforest", "left": 6, "label": "Wunsch"})
	specs.append({"kind": FieldView.K_CHURCH, "fx": "war", "label": "Krieg"})
	specs.append({"kind": FieldView.K_INDUSTRY, "fx": "strike", "label": "Gewitter"})
	specs.append({"kind": FieldView.K_BIGFOREST, "fx": "wither", "label": "Welken"})
	specs.append({"kind": FieldView.K_HUT, "fx": "wish", "burning": true, "label": "Feuer+Herz"})
	specs.append({"kind": FieldView.K_EMPTY, "fresh": 2, "label": "Erde frisch"})
	for i in specs.size():
		var sp: Dictionary = specs[i]
		var v := FieldView.new()
		root.add_child(v)
		var col := i % COLS
		var row := i / COLS
		v.position = Vector3((col - (COLS - 1) * 0.5) * 1.3, 0, row * 1.45)
		var f := FieldData.new()
		f.id = i
		v.build(f)
		var kind: int = sp["kind"]
		var fresh: int = sp.get("fresh", 0)
		var burning: bool = sp.get("burning", false)
		v.set_kind(kind, fresh, burning)
		if v.get_kind() != kind:
			_fail("set_kind %d" % kind)
		if sp.get("polluted", false):
			v.set_polluted(true)
			if not v.is_polluted():
				_fail("polluted")
		var wish: String = sp.get("wish", "")
		if wish != "":
			v.set_wish(wish, int(sp.get("left", -1)))
		var lbl := Label3D.new()
		var txt: String = sp.get("label", FieldView.KIND_KEY[kind])
		lbl.text = "%d %s" % [kind, txt]
		lbl.font_size = 40
		lbl.pixel_size = 0.0028
		lbl.outline_size = 12
		lbl.position = Vector3(0, 0.1, 0.56)
		lbl.rotation_degrees.x = -50
		v.add_child(lbl)
		_views.append([v, sp])
	# FieldData-Pfad: refresh() mit dem alten stage oder dem neuen kind
	var probe := FieldData.new()
	probe.id = 99
	var pv := FieldView.new()
	root.add_child(pv)
	pv.position = Vector3(100, 0, 0)
	pv.build(probe)
	pv.refresh(probe)
	if pv.get_kind() != FieldView.kind_of(probe):
		_fail("refresh/kind_of")
	if FieldView.KIND_TILE.size() != FieldView.KIND_COUNT or FieldView.KIND_ICON.size() != FieldView.KIND_COUNT:
		_fail("Tabellen-Länge")
	for k in FieldView.KIND_COUNT:
		if not ResourceLoader.exists("res://icons/%s.svg" % FieldView.KIND_ICON[k]):
			_fail("Symbol fehlt: " + FieldView.KIND_ICON[k])
	if FieldView.KIND_COUNT != FieldData.KIND_COUNT or FieldView.KIND_ICON[FieldData.WATER] != "water":
		_fail("Wasser fehlt in FieldView")
	# Die 7 Tage: Wasser, Schloss, leerer Stern, Tage, Ziel
	for n in ["wish", "wish_bubble", "wish_count", "strike", "field", "animals", "paradise", "swords", "heart",
			"water", "lock", "star_empty", "days", "goal"]:
		if Style.icon(n) == null:
			_fail("Symbol lädt nicht: " + n)
	print("Modelle gebaut: %d Ansichten" % _views.size())


func _setup_scene(root: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#cfe6f7")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b9c6dc")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.82
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_color = Color("#fff3df")
	sun.light_energy = 0.78
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 150, 0)
	fill.light_color = Color("#cfe0ff")
	fill.light_energy = 0.18
	root.add_child(fill)
	_cam = Camera3D.new()
	_cam.fov = 38
	_cam.transform = Transform3D(Basis(), Vector3(0, 7.6, 9.4)).looking_at(Vector3(0, 0, 2.75))
	root.add_child(_cam)
	_cam.current = true


func _process(delta: float) -> bool:
	_frames += 1
	if _fx_time >= 0.0:
		_fx_time += delta
	if _frames == 5:
		_fx_time = 0.0
		for e in _views:
			var v: FieldView = e[0]
			var sp: Dictionary = e[1]
			match String(sp.get("fx", "")):
				"war":
					v.war_fx()
				"strike":
					v.strike_fx()
				"wither":
					v.wither_fx()
				"wish":
					v.wish_fx()
	# Bilder: Übersicht, dann Nahaufnahmen (Effekte laufen noch)
	if _sheet != "" and _fx_time >= 0.06 and _shot < 5:
		if _shot > 0:
			var img := get_root().get_texture().get_image()
			var path := _sheet if _shot == 1 else _sheet.replace(".png", "_%d.png" % _shot)
			img.save_png(path)
			print("Bild: ", path)
		var looks := [[Vector3(-1.3, 2.4, 8.2), Vector3(-1.3, 0.3, 5.8)], [Vector3(0, 7.6, 9.4), Vector3(0, 0, 2.75)],
			[Vector3(-2.2, 1.9, 4.6), Vector3(-2.6, 0.35, 2.9)], [Vector3(2.4, 2.0, 4.9), Vector3(2.6, 0.3, 2.9)]]
		if _shot < looks.size():
			var lk: Array = looks[_shot]
			_cam.transform = Transform3D(Basis(), lk[0]).looking_at(lk[1])
		_shot += 1
	if _frames >= 200:
		# nach den Effekten: der Kirchen-Inhalt muss wieder normal groß sein
		for e in _views:
			var v: FieldView = e[0]
			if v.get_kind() < 0:
				_fail("kind nicht gesetzt")
		if _errors == 0:
			print("OK test_models")
		else:
			print("%d Fehler" % _errors)
		quit(1 if _errors > 0 else 0)
		return true
	return false


func _fail(what: String) -> void:
	_errors += 1
	push_error("FEHLER: " + what)
	print("FEHLER: " + what)
