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
var _char_done := false            # der Charakter-Test lief bis zum Ende (ein Laufzeitfehler bricht ihn ab)


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
	_test_character()


# --- Eigener Charakter (GDPD_TAEGLICH_CHARAKTER.md 3, 4) -------------------------------------------------------

func _test_character() -> void:
	var t0 := Time.get_ticks_msec()
	# Alle Teile vorhanden und als Bild ladbar
	for path_v in Character.all_files():
		var path: String = path_v
		if not ResourceLoader.exists(path):
			_fail("Charakter-Teil fehlt: " + path)
		elif not (load(path) is Texture2D):
			_fail("Charakter-Teil kein Bild: " + path)
	# Jede Kombination aus Basis, Augen und Zubehör einmal bauen (Ausdrücke reihum)
	var cv := CharacterView.new()
	cv.size = Vector2(240, 240)
	get_root().add_child(cv)
	var builds := 0
	var exprs: Array = Character.EXPRESSION_ORDER
	for basis_v in Character.BASE_ORDER:
		var basis: String = basis_v
		for stil in Character.EYE_ORDER:
			for kopf in Character.accessory_ids("kopf", basis):
				for ges in Character.accessory_ids("gesicht", basis):
					for hals in Character.accessory_ids("hals", basis):
						var l := Character.default_look(basis)
						l["augen"] = stil
						l["kopf"] = kopf
						l["gesicht"] = ges
						l["hals"] = hals
						cv.set_look(l)
						cv.set_expression(String(exprs[builds % exprs.size()]))
						builds += 1
						if builds % 97 == 0:
							_check_layers(cv, "%s/%s/%s/%s/%s" % [basis, stil, kopf, ges, hals])
		# jede Farbe jedes Platzes, jeder Ausdruck, jeder Ton
		var l2 := Character.default_look(basis)
		for row_v in Character.rows(basis):
			var row: Array = row_v
			for key in Character.palette_keys(String(row[2])):
				l2["farben"][String(row[0])] = key
				var c := Character.color(l2, String(row[0]))
				if c != Character.palette_color(String(row[2]), String(key)):
					_fail("Farbe %s/%s" % [basis, key])
		for ton in Character.TONES:
			l2["ton"] = ton
			cv.set_look(l2)
			for e in exprs:
				cv.set_expression(String(e))
				_check_layers(cv, "%s/%s/%s" % [basis, ton, e])
		if Character.has_neck(basis) != Character.BASES[basis].has("neck"):
			_fail("Hals " + basis)
	for kind in ["hop", "shake", "spin", "nod"]:
		cv.react(kind)
	cv.talking(true)
	cv.look_dir(Vector2(1, 0))
	cv.blink()
	# Kopfbild klein
	var small := CharacterView.make(Character.default_look("nudel"), 40, true, "happy")
	get_root().add_child(small)
	_check_layers(small, "Kopfbild")
	# Datenmodell: Zufall gültig und stabil, Namen, Speichern
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 300:
		var r := Character.random(rng)
		if Character.sanitize(r) != r:
			_fail("random nicht stabil: %s" % str(r))
		if not Character.has_neck(String(r["basis"])) and String(r["hals"]) != "":
			_fail("Halszubehör ohne Hals")
	var names := {"  Zeus\n{x}  ": "Zeus x", "": "Barti", "Abcdefghijklmnopq": "Abcdefghijkl", "   ": "Barti", "Hera": "Hera"}
	for n in names:
		if Character.sanitize_name(String(n), "bart") != String(names[n]):
			_fail("Name '%s' -> '%s'" % [n, Character.sanitize_name(String(n), "bart")])
	var bad := Character.sanitize({"basis": "drache", "farben": {"haupt": "lila!"}, "augen": "x", "kopf": "hut", "ton": "laut"})
	if String(bad["basis"]) != "bart" or String(bad["augen"]) != "rund" or String(bad["kopf"]) != "" or String(bad["ton"]) != "lieb":
		_fail("sanitize kaputter Daten")
	var wb := Character.with_base({"basis": "katze", "hals": "fliege", "name": "Mauz", "augen": "gross"}, "sonne")
	if String(wb["hals"]) != "" or String(wb["name"]) != "Mauz" or String(wb["augen"]) != "gross":
		_fail("with_base")
	if String(Character.with_base(Character.default_look("katze"), "wolke")["name"]) != "Wolki":
		_fail("with_base Standardname")
	var path := "user://test_charakter.cfg"
	var look := Character.random(rng)
	look["name"] = "Testi"
	if Character.save_look(look, path) != OK or Character.load_look(path) != Character.sanitize(look):
		_fail("Speichern/Laden")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not Character.load_look(path).is_empty():
		_fail("load_look ohne Datei")
	# Texte: jeder Schlüssel in jedem Ton, Längen, nie zweimal hintereinander gleich
	for key in CharacterTexts.LINES:
		for ton in CharacterTexts.TONES:
			var vs := CharacterTexts.variants(String(key), String(ton))
			if vs.is_empty():
				_fail("Text fehlt: %s/%s" % [key, ton])
			for v in vs:
				var tx := String(v)
				# Regel (NAECHSTE_SCHRITTE „Texte“): ein kurzer Satz, höchstens 8 Wörter, nie „3 Erden zusammen“
				if tx.split(" ", false).size() > 8 or tx.strip_edges() != tx or tx.begins_with("{tag}") or tx.contains("Erden"):
					_fail("Text %s/%s: %s" % [key, ton, tx])
	var last := ""
	for i in 40:
		var p := CharacterTexts.line("praise", "frech", {}, rng, last)
		if p == last:
			_fail("Lob zweimal hintereinander")
		last = p
	if CharacterTexts.line("streak_n", "lieb", {"streak": 5}) != "5 Tage in Folge!":
		_fail("Platzhalter")
	var ids := {}
	for ton in CharacterTexts.TONES:
		var all: Array = CharacterTexts.NOTIFY[ton]
		if all.size() != 15:
			_fail("Benachrichtigungen %s: %d" % [ton, all.size()])
		for n_v in all:
			var n: Dictionary = n_v
			if String(n["text"]).split(" ", false).size() > 8:
				_fail("Benachrichtigung zu lang: " + String(n["id"]))
			if ids.has(n["id"]):
				_fail("Benachrichtigung doppelt: " + String(n["id"]))
			ids[n["id"]] = true
		for cat in ["A", "B", "C", "F"]:
			if CharacterTexts.notifications(String(ton), String(cat), true).is_empty():
				_fail("keine Vorlage %s/%s" % [ton, cat])
		for n_v in CharacterTexts.notifications(String(ton), "B", true):
			if (n_v as Dictionary).get("streak", false):
				_fail("Serien-Text in B")
	for key in CharacterTexts.FACE:
		if not Character.EXPRESSIONS.has(String(CharacterTexts.FACE[key])):
			_fail("Gesicht unbekannt: " + String(key))
	# Ersteller: alle Schritte, Würfeln, Fertig
	var cc := CharacterCreator.new()
	cc.autosave = false
	cc.size = Vector2(600, 1066)
	get_root().add_child(cc)
	var got: Array = []
	cc.finished.connect(func(l3: Dictionary) -> void: got.append(l3))
	cc.open({}, false)
	for st in 4:
		cc.go_to_step(st)
		cc.randomize_step()
		if cc.step != st:
			_fail("Schritt %d" % st)
	cc.randomize_all()
	cc.go_to_step(3)
	cc._on_next()
	if got.size() != 1 or Character.sanitize(got[0]) != got[0]:
		_fail("Ersteller fertig")
	cc.queue_free()
	print("Charakter: %d Kombinationen gebaut, %d ms" % [builds, Time.get_ticks_msec() - t0])
	_char_done = true


func _check_layers(cv: CharacterView, what: String) -> void:
	var n := 0
	var stack: Array = [cv]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
		if node is TextureRect:
			n += 1
			if (node as TextureRect).texture == null:
				_fail("Ebene ohne Bild: %s (%s)" % [what, node.name])
			if (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
				_fail("Ebene fängt Berührungen: " + what)
	if n < 12:
		_fail("zu wenige Ebenen: %s (%d)" % [what, n])


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
		if not _char_done:
			_fail("Charakter-Test abgebrochen")
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
