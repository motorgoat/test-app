extends SceneTree
## Modell-Test: baut jede Art (kind 0..26: 15 Wasser, 16 Fels, 17–26 Schöpfung) und jeden Zustand einmal als FieldView
## und lässt ein paar Frames laufen. Dazu jedes Zeitalter (Eras) mit seinen Modell-Zweigen, Zusammenwachsen, Wasser dreht
## mit (Wellen-Rahmen), Verlust-Hinweis, Versorgt-Zeichen, Vorzeichen der Gefahren.
## Sheet je Zeitalter: ... -- --sheet=/pfad/models.png --era=glut
##   godot --headless --script res://tests/test_models.gd
## Mit Bild (echtes GL, z. B. unter xvfb-run):
##   godot --rendering-driver opengl3 --resolution 1500x1100 --script res://tests/test_models.gd -- --sheet=/pfad/models.png

const COLS := 5

var _views: Array = []
var _frames := 0
var _sheet := ""
var _era := ""
var _errors := 0
var _cam: Camera3D
var _fx_time := -1.0
var _shot := 0
var _char_done := false            # der Charakter-Test lief bis zum Ende (ein Laufzeitfehler bricht ihn ab)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sheet="):
			_sheet = a.substr(8)
		elif a.begins_with("--era="):
			_era = a.substr(6)
	if _era != "":
		Look.set_era(_era)
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
	# Teil B (GDPD_GRAFIK.md 9): welke Natur, Feuer, Krater, Zustände der neuen Tage, Flucht, Rückseite
	for k in [FieldView.K_MEADOW, FieldView.K_ANIMALS, FieldView.K_FIELD, FieldView.K_PARADISE]:
		specs.append({"kind": k, "fresh": 2, "label": "%s welk" % FieldView.KIND_KEY[k]})
	specs.append({"kind": FieldView.K_FOREST, "burning": true, "label": "Wald brennt"})
	specs.append({"kind": FieldView.K_VILLAGE, "burning": true, "label": "Dorf brennt"})
	specs.append({"kind": FieldView.K_EMPTY, "crater": true, "label": "Krater"})
	specs.append({"kind": FieldView.K_VILLAGE, "st8": {"people": true, "met": ["food", "work"], "missing": [], "satt": true, "fed": 1,
		"hungry": 0, "shrink_after": 4}, "label": "Dorf satt"})
	specs.append({"kind": FieldView.K_HUT, "st8": {"people": true, "met": [], "missing": ["food"], "satt": false, "fed": 0,
		"hungry": 3, "shrink_after": 4}, "label": "Hütte hungrig"})
	specs.append({"kind": FieldView.K_TOWN, "st8": {"people": true, "met": ["food"], "missing": ["work", "faith"], "front": true},
		"label": "Front"})
	specs.append({"kind": FieldView.K_FOREST, "st8": {"bolt": true}, "label": "Blitz droht"})
	specs.append({"kind": FieldView.K_MEADOW, "st8": {"flood_risk": true}, "label": "Flut droht"})
	specs.append({"kind": FieldView.K_ANIMALS, "alarm": true, "label": "Tiere fliehen"})
	specs.append({"kind": FieldView.K_STONE, "detail": -1.0, "label": "Rückseite"})
	# Schöpfung (GDPD_SCHOEPFUNG_GRAFIK.md 4–7): Vorzeichen, Versorgt-Zeichen, Gruppen-Stärke, Zustände der neuen Arten
	specs.append({"kind": FieldView.K_LAVA, "st8": {"thriver": true, "crater": true, "volc": true}, "label": "Vulkan grollt"})
	specs.append({"kind": FieldView.K_LAVA, "st8": {"thriver": true, "met": ["wet"], "missing": [], "fed": 1, "cool": 2}, "label": "Lava kühlt"})
	specs.append({"kind": FieldView.K_HUT, "st8": {"thriver": true, "people": true, "met": ["food"], "sealed": ["food"], "missing": [],
		"satt": true, "fed": 1, "hungry": 0, "shrink_after": 4}, "label": "versorgt"})
	specs.append({"kind": FieldView.K_VILLAGE, "st8": {"thriver": true, "people": true, "met": ["food"], "sealed": ["food"],
		"missing": ["work"], "have": {"work": [1, 2]}, "satt": false, "fed": 0, "hungry": 0, "shrink_after": 4}, "label": "neues Bedürfnis"})
	specs.append({"kind": FieldView.K_ANIMALS, "st8": {"thriver": true, "met": [], "missing": ["plants"], "satt": false, "fed": 0,
		"hungry": 3, "shrink_after": 4}, "label": "Hunger!"})
	specs.append({"kind": FieldView.K_ANIMALS, "st8": {"thriver": true, "pack": true}, "label": "Rudel droht"})
	specs.append({"kind": FieldView.K_PRED, "st8": {"thriver": true, "pack_pred": true}, "label": "Rudel lauert"})
	specs.append({"kind": FieldView.K_MEADOW, "st8": {"thriver": true, "smog": true}, "label": "Smog droht"})
	specs.append({"kind": FieldView.K_FOREST, "st8": {"thriver": true, "dry": true}, "label": "trocken"})
	specs.append({"kind": FieldView.K_STONE, "st8": {"thriver": true, "strength": 3, "badge": true}, "label": "×3"})
	specs.append({"kind": FieldView.K_FERN, "fresh": 2, "label": "Farn welk"})
	specs.append({"kind": FieldView.K_BIRDS, "burning": true, "label": "Vögel brennen"})
	specs.append({"kind": FieldView.K_FIELD, "fx": "loss", "label": "−1"})
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
		if sp.get("crater", false):
			v.set_crater(true)
		if sp.has("st8"):
			v.apply_state8(sp["st8"])
		if sp.get("alarm", false):
			v.set_alarm(true)
		if sp.has("detail"):
			v.set_detail(float(sp["detail"]))
			if v.get_detail() != 0:
				_fail("Rückseite nicht ausgeblendet")
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
		# eigenes Symbol oder (neue Arten, solange das SVG fehlt) das Ersatz-Symbol aus ICON_FALLBACK
		if not ResourceLoader.exists("res://icons/%s.svg" % FieldView.kind_icon(k)):
			_fail("Symbol fehlt: " + FieldView.KIND_ICON[k])
	if FieldView.KIND_ICON[FieldData.WATER] != "water":
		_fail("Wasser fehlt in FieldView")
	if FieldView.KIND_COUNT < FieldData.KIND_COUNT:
		_fail("FieldView kennt weniger Arten als FieldData")
	if FieldView.KIND_ICON[FieldData.STONE] != "stone":
		_fail("Stein fehlt in FieldView")
	# Vorschau beim Drehen (neue Tage): grün = wird satt, rot = verliert die Versorgung
	pv.set_supply(1)
	var sup_ok := pv.supply_mode() == 1
	pv.set_supply(-1)
	sup_ok = sup_ok and pv.supply_mode() == -1
	pv.set_supply(0)
	if not sup_ok or pv.supply_mode() != 0:
		_fail("Versorgungs-Vorschau")
	_test_seamless(root)
	# Die 7 Tage: Wasser, Schloss, leerer Stern, Tage, Ziel
	for n in ["wish", "wish_bubble", "wish_count", "strike", "field", "animals", "paradise", "swords", "heart",
			"water", "lock", "star_empty", "days", "goal", "meteor", "stone", "person", "up", "down", "need_bg"]:
		if Style.icon(n) == null:
			_fail("Symbol lädt nicht: " + n)
	# Alle Modelle und Figuren (Teil B): nicht leer, Vertexfarben und Animations-Teile vorhanden
	for nm in ["oak", "beech", "young", "dead", "birch", "spruce", "pine", "blossom", "bush", "bush_dry", "rock", "boulder", "stump",
			"log", "cabin", "house", "townhouse", "block", "glass_tower", "church", "factory", "well", "stall", "woodpile", "fence",
			"scarecrow", "cart", "trough", "quarry", "crater", "ruin", "tent"]:
		for vr in 4:
			var parts := Models.get_model(String(nm), vr)
			if parts.is_empty():
				_fail("Modell leer: %s/%d" % [nm, vr])
			for part_v in parts:
				var arr := Models.arrays_of((part_v as Array)[0])
				if arr.is_empty() or (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty() or (arr[Mesh.ARRAY_COLOR] as PackedColorArray).size() != (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
					_fail("Modell ohne Daten/Farben: %s/%d" % [nm, vr])
	for nm in ["fern", "tree_fern", "horsetail", "nest", "den", "bones", "sheaf", "volcano", "basalt", "crust", "moss"]:
		for vr in 3:
			var parts := Models.get_model(String(nm), vr)
			if parts.is_empty():
				_fail("Modell leer: %s/%d" % [nm, vr])
			for part_v in parts:
				var arr := Models.arrays_of((part_v as Array)[0])
				if arr.is_empty() or (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
					_fail("Modell ohne Daten: %s/%d" % [nm, vr])
	for cr in ["wolf", "bison", "newt", "fish", "bird"]:
		var arr := Models.arrays_of(Models.creature_mesh(String(cr), 0))
		if arr.is_empty() or (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() < 30:
			_fail("Figur leer: " + String(cr))
	for n2 in ["heat", "mineral", "spark", "sun", "prey", "plants", "fishneed", "shore", "wet", "food", "work"]:
		if Style.icon(FieldView.icon_name(String(n2))) == null:
			_fail("Bedürfnis-Symbol fehlt: " + String(n2))
	_test_eras(root)
	_test_erde(root)
	_test_merge(root)
	_test_wave_frame()
	for cr in ["sheep", "cow", "deer", "hare", "duck", "person"]:
		for vr in 6:
			var arr := Models.arrays_of(Models.creature_mesh(String(cr), vr))
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var parts_seen := {}
			for t in uv:
				parts_seen[int(roundf(t.x))] = true
			if cr != "duck" and not (parts_seen.has(1) and parts_seen.has(2)):
				_fail("Figur ohne Beine: %s/%d" % [cr, vr])
			if cr != "duck" and cr != "person" and not parts_seen.has(3):
				_fail("Tier ohne Kopf: %s/%d" % [cr, vr])
	print("Modelle gebaut: %d Ansichten" % _views.size())
	_test_character()


# --- Schöpfung: Zeitalter, Zusammenwachsen, Wasser dreht mit ------------------------------------------------------

## Jedes Zeitalter: Paletten und Modell-Zweige bauen ohne Fehler; Urzeit hat Urboden, Basalt, keine Enten.
func _test_eras(root: Node3D) -> void:
	var probe := FieldView.new()
	root.add_child(probe)
	probe.position = Vector3(200, 0, 0)
	var fd := FieldData.new()
	fd.id = 5
	probe.build(fd)
	for en in Eras.ORDER:
		Look.set_era(String(en))
		for k in FieldView.KIND_COUNT:
			probe.set_kind(k)
			probe.era_changed()
			if probe.get_kind() != k:
				_fail("Zeitalter %s: Art %d" % [en, k])
		if not Eras.has(String(en)) or String(Eras.get_era(String(en))["mood"]) == "":
			_fail("Zeitalter ohne Stimmung: " + String(en))
	Look.set_era("glut")
	if not Look.era_flag("basalt") or not Look.era_flag("primeval") or Look.era_flag("ducks"):
		_fail("Glut: Basalt/Urboden/keine Enten")
	probe.set_kind(FieldView.K_WATER)
	probe.era_changed()
	if probe.agent_count() != 0:
		_fail("Urozean hat Enten")
	# Dunkler Basalt nur in der Glut-Zeit: Akt 1 → Akt 2 muss den Modell-Schlüssel ändern (sonst bleibt alter Basalt
	# aus dem Back-Cache neben neuen hellen Brocken stehen)
	var mk_glut := Look.model_key()
	if not Look.basalt_dark():
		_fail("Glut: kein dunkler Basalt")
	Look.set_era("glut_kuehl")
	var mk_kuehl := Look.model_key()
	Look.set_era("dunst")
	if Look.basalt_dark() or Look.model_key() == mk_glut or Look.model_key() == mk_kuehl:
		_fail("Dunst: gleicher Modell-Schlüssel wie Glut (Basalt aus dem Cache)")
	Look.set_era("tag")
	probe.era_changed()
	# Level → Zeitalter (Spec 4.1)
	# (nur solange die alte Akt-Zuordnung Eras.act_of besteht; die Erdgeschichte nimmt das Zeitalter aus den Level-Daten)
	var es: Script = load("res://scripts/eras.gd")
	var has_acts := false
	for md in es.get_script_method_list():
		if String((md as Dictionary)["name"]) == "act_of":
			has_acts = true
	var want := {1: "glut", 4: "glut_kuehl", 6: "dunst", 10: "blau", 13: "fruehling", 14: "sommer", 15: "herbst", 17: "tag",
		24: "menschen", 27: "abend", 30: "vollendet"}
	for lv in (want if has_acts else {}):
		var got: Variant = es.call("of", 0, int(lv))
		if str(got) != String(want[lv]):
			_fail("Eras.of Level %d: %s" % [int(lv), str(got)])
	Look.set_era(_era if _era != "" else "tag")
	probe.queue_free()


# --- Erdgeschichte (GDPD_ERDGESCHICHTE_GRAFIK.md): Zeitalter, Decke, Eis, Gletscher, Gestalten, neue Modelle ------

const ERDE_ERAS := ["kambrium", "meer", "landgang", "karbon", "saurier", "asche", "erholung", "saeuger", "eiszeit", "savanne", "feuer",
	"jaeger", "glaube"]
const ERDE_CREATURES := ["sauro", "trex", "raptor", "ptero", "mammoth", "ape", "hunter", "shrew", "trilobite", "jelly", "dragonfly", "amph",
	"lizard", "cave_lion", "antelope", "horse", "armorfish"]
const ERDE_PLANTS := ["cycad", "araucaria", "acacia", "campfire", "lepido", "skeleton", "stone_circle", "fur_tent", "eggs", "drying_rack",
	"ice_block", "ice_rock", "charred"]


## Jedes neue Zeitalter: Stimmung vorhanden, Licht über den Untergrenzen (3.2), totes Wasser nicht zu dunkel; Decke und
## Eis auf alten und neu gebauten Boden-Materialien und auf dem Laub; Mischung Asche → Erholung; Gletscher-Boden;
## Gestalten der Arten je Zeitalter (Agenten, Wassertiere, Flieger); jedes neue Tier und jede Pflanze baut im Budget;
## eine unbekannte Art wird Erde.
func _test_erde(root: Node3D) -> void:
	var moods: Dictionary = (load("res://scripts/world.gd") as Script).get_script_constant_map().get("MOODS", {})
	for en in ERDE_ERAS:
		if not Eras.has(String(en)):
			_fail("Zeitalter fehlt: " + String(en))
			continue
		var ed: Dictionary = Eras.get_era(String(en))
		var mn := String(ed["mood"])
		if not moods.has(mn):
			_fail("Stimmung fehlt: " + mn)
			continue
		var m: Dictionary = moods[mn]
		if float(m["sun_e"]) < 0.8 or float(m["fill_e"]) < 0.6 or float(m["amb_e"]) < 0.85 or float(m["sat"]) < 0.75:
			_fail("Licht unter den Untergrenzen: " + mn)
		var deep := Color(str((ed.get("water", {}) as Dictionary).get("deep", "#12383f")))
		if deep.get_luminance() < Color("#2a3438").get_luminance() - 0.06:
			# nur totes, trübes Wasser muss hell genug sein (klares, tiefes Wasser darf dunkel sein)
			if float((ed.get("water", {}) as Dictionary).get("glint", 1.0)) < 0.5:
				_fail("totes Wasser zu dunkel: " + String(en))
		if float(ed.get("blanket", 0.0)) > 0.45:
			_fail("Decke über 0,45: " + String(en))
	# Decke und Eis: vorhandenes und neu gebautes Boden-Material, Laub (CHECK era_blanket)
	Look.set_era("tag")
	var g_old := Look.ground_material()
	Look.set_era("eiszeit")
	var g_new := Look.ground_material()
	var fol := Look.foliage(Color("#406030"), true)
	for gm in [g_old, g_new]:
		var bc: Color = (gm as ShaderMaterial).get_shader_parameter("blanket")
		if absf(bc.a - 0.4) > 0.001 or absf(float((gm as ShaderMaterial).get_shader_parameter("ice")) - 0.55) > 0.001:
			_fail("Eiszeit: Decke/Eis fehlt auf einem Boden-Material")
	if absf(((fol as ShaderMaterial).get_shader_parameter("blanket") as Color).a - 0.4) > 0.001:
		_fail("Eiszeit: kein Schnee auf dem Laub")
	Look.set_era("asche")
	if absf(Look.blanket.a - 0.42) > 0.001 or Look.blanket_veil < 0.99:
		_fail("Aschewinter: Asche-Schleier")
	Look.set_era_mix("asche", "erholung", 0.5)
	if Look.blanket.a <= 0.06 or Look.blanket.a >= 0.42 or Look.era_name != "erholung":
		_fail("Erholung: Asche nicht gemischt (%.2f)" % Look.blanket.a)
	Look.set_era("tag")
	if Look.blanket.a != 0.0 or Look.ice != 0.0:
		_fail("heute: Decke/Eis bleibt")
	# Modell-Schlüssel: jedes Zeitalter mit eigenen Gestalten hat einen eigenen Schlüssel (Back-Cache)
	var keys := {}
	for en in ["tag", "kambrium", "meer", "karbon", "saurier", "asche", "erholung", "saeuger", "eiszeit", "savanne", "feuer", "jaeger", "glaube"]:
		Look.set_era(String(en))
		var mk := Look.model_key()
		if keys.has(mk) and not (["saeuger", "tag"].has(String(en)) and ["saeuger", "tag"].has(String(keys[mk]))):
			_fail("gleicher Modell-Schlüssel: %s und %s" % [en, keys[mk]])
		keys[mk] = en
	# Gestalten je Zeitalter (CHECK era_models): [Zeitalter, Art, muss haben, darf nicht haben]
	var probe := FieldView.new()
	root.add_child(probe)
	probe.position = Vector3(260, 0, 0)
	var fd := FieldData.new()
	fd.id = 4                       # Variante 0
	probe.build(fd)
	var cases := [["saurier", FieldView.K_SAURO, "sauro", "bison"], ["saurier", FieldView.K_REX, "trex", "wolf"],
		["saurier", FieldView.K_ANIMALS, "shrew", "bison"], ["saurier", FieldView.K_PTERO, "ptero", "bird"],
		["eiszeit", FieldView.K_MAMMOTH, "mammoth", "sauro"], ["eiszeit", FieldView.K_ANIMALS, "bison", "antelope"],
		["eiszeit", FieldView.K_PRED, "cave_lion", "wolf"], ["savanne", FieldView.K_ANIMALS, "antelope", "bison"],
		["savanne", FieldView.K_APES, "ape", "person"], ["savanne", FieldView.K_EARLY, "hunter", "person"],
		["feuer", FieldView.K_CAMP, "hunter", "person"], ["feuer", FieldView.K_HUT, "hunter", "person"],
		["jaeger", FieldView.K_HUT, "hunter", "person"], ["saeuger", FieldView.K_ANIMALS, "horse", "shrew"],
		["erholung", FieldView.K_ANIMALS, "shrew", "bison"], ["asche", FieldView.K_ANIMALS, "shrew", "bison"],
		["karbon", FieldView.K_AMPHIB, "amph", "newt"], ["karbon", FieldView.K_REPTILE, "lizard", "newt"],
		["karbon", FieldView.K_INSECTS, "dragonfly", "bird"], ["karbon", FieldView.K_FOREST, "dragonfly", "deer"],
		["kambrium", FieldView.K_JELLY, "jelly", "fish"], ["kambrium", FieldView.K_TRILO, "trilobite", "fish"],
		["meer", FieldView.K_FISH, "armorfish", "duck"], ["tag", FieldView.K_PRED, "wolf", "cave_lion"],
		["menschen", FieldView.K_ANIMALS, "sheep", "shrew"], ["glaube", FieldView.K_CHURCH, "person", "hunter"]]
	for cv in cases:
		var c: Array = cv
		Look.set_era(String(c[0]))
		probe.set_kind(FieldView.K_EMPTY)
		probe.set_kind(int(c[1]))
		probe.era_changed()
		var seen: Array = probe.agent_kinds() + probe.flyer_kinds()
		if not seen.has(String(c[2])) or seen.has(String(c[3])):
			_fail("Gestalt %s/%s: %s" % [c[0], FieldView.KIND_KEY[int(c[1])], str(seen)])
	# Gletscher (Art Eis): Boden-Shader zeigt die Eisdecke; Lagerfeuer hat seine Glut
	Look.set_era("eiszeit")
	probe.set_kind(FieldView.K_ICE)
	if float(probe._ground.get_shader_parameter("glacier")) != 1.0:
		_fail("Eis ohne Gletscher-Boden")
	Look.set_era("feuer")
	probe.set_kind(FieldView.K_CAMP)
	if probe._glow == null:
		_fail("Feuerstelle ohne Glut")
	# unbekannte (spätere) Art: Erde statt Absturz
	probe.set_kind(77)
	if probe.get_kind() != FieldView.K_EMPTY:
		_fail("unbekannte Art nicht Erde")
	# Einschlag: Tiere kippen um (keine Bewegung mehr)
	Look.set_era("saurier")
	probe.set_kind(FieldView.K_SAURO)
	probe.topple(0.1)
	for st in probe.agent_states():
		if String(st) != "dead":
			_fail("Saurier kippt nicht um")
	Look.set_era("tag")
	probe.queue_free()
	# neue Tiere und Pflanzen: nicht leer, im Dreiecks-Budget (Tiere ≤ 700, Pflanzen ≤ 1200), Tiere mit Teilen
	for cr in ERDE_CREATURES:
		for vr in 3:
			var arr := Models.arrays_of(Models.creature_mesh(String(cr), vr))
			var nv := (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() if not arr.is_empty() else 0
			if nv < 30 or nv / 3 > 700:
				_fail("Figur %s/%d: %d Dreiecke" % [cr, vr, nv / 3])
			if ["sauro", "trex", "mammoth", "ape", "amph", "lizard", "cave_lion", "antelope", "horse", "shrew"].has(String(cr)):
				var parts_seen := {}
				for t in (arr[Mesh.ARRAY_TEX_UV] as PackedVector2Array):
					parts_seen[int(roundf(t.x))] = true
				if not (parts_seen.has(1) and parts_seen.has(3)):
					_fail("Figur ohne Beine/Kopf: %s" % cr)
	for nm in ERDE_PLANTS:
		for vr in 3:
			var tris := 0
			var parts := Models.get_model(String(nm), vr)
			for part_v in parts:
				var arr := Models.arrays_of((part_v as Array)[0])
				tris += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			if parts.is_empty() or tris > 1200:
				_fail("Modell %s/%d: %d Dreiecke" % [nm, vr, tris])
	print("Erdgeschichte geprüft: %d Zeitalter, %d Tiere, %d Pflanzen" % [ERDE_ERAS.size(), ERDE_CREATURES.size(), ERDE_PLANTS.size()])


## Zusammenwachsen (5.1): Besitz-Regel – eine Fuge gehört nur einem Feld (keine doppelten Fugen-Teile); getrennt
## verschwinden die Fugen-Teile; über eine Würfelkante nie.
func _test_merge(root: Node3D) -> void:
	var a := FieldView.new()
	var b := FieldView.new()
	root.add_child(a)
	root.add_child(b)
	a.position = Vector3(220, 0, 0)
	b.position = Vector3(220, 0, -0.9)
	var fa := FieldData.new()
	fa.id = 7
	var fb := FieldData.new()
	fb.id = 8
	a.build(fa)
	b.build(fb)
	a.set_kind(FieldView.K_FOREST)
	b.set_kind(FieldView.K_FOREST)
	var f := FieldView.K_FOREST
	# a liegt südlich von b: a hat b im Norden (Platz 0), b hat a im Süden (Platz 2)
	a.set_neighbors([f, 0, 0, 0, 0, 0, 0, 0], [true, false, false, false, false, false, false, false])
	b.set_neighbors([0, 0, f, 0, 0, 0, 0, 0], [false, false, true, false, false, false, false, false])
	if (a.merge_mask() & 1) == 0 or b.merge_mask() != 0:
		_fail("Fugen-Besitz: a=%d b=%d" % [a.merge_mask(), b.merge_mask()])
	var seam := 0
	for c in a._content.get_children():
		if (c as Node).has_meta("seam"):
			seam += 1
	if seam == 0:
		_fail("keine Fugen-Bäume")
	a.set_neighbors([0, 0, 0, 0, 0, 0, 0, 0], [false, false, false, false, false, false, false, false])
	if a.merge_mask() != 0:
		_fail("getrennt, Fuge bleibt")
	# Würfelkante im Norden: nie ein Fugen-Teil
	var c2 := FieldView.new()
	root.add_child(c2)
	c2.position = Vector3(222, 0, 0)
	var fc := FieldData.new()
	fc.id = 9
	c2.build(fc, 1)
	c2.set_kind(FieldView.K_FOREST)
	c2.set_neighbors([f, 0, 0, 0, 0, 0, 0, 0], [true, false, false, false, false, false, false, false])
	if c2.merge_mask() != 0:
		_fail("Fugen-Teil auf der Würfelkante")
	for v in [a, b, c2]:
		(v as Node).queue_free()
	print("Zusammenwachsen geprüft")


## Wasser dreht mit (Spec 10.1, wave_frame_rot): vier Vierteldrehungen einer Seite = Ausgangslage; eine Vierteldrehung
## dreht das Muster wirklich.
func _test_wave_frame() -> void:
	var t := Transform3D(Basis(Vector3.UP, 0.0), Vector3(1.0, 1.47, -1.0))
	var n := Vector3i(0, 1, 0)
	var f0 := FieldView.wave_frame(t, n, 0)
	var f4 := FieldView.wave_frame(t, n, 4)
	var f1 := FieldView.wave_frame(t, n, 1)
	if not ((f0[0] as Vector4) - (f4[0] as Vector4)).is_zero_approx() or not ((f0[1] as Vector2) - (f4[1] as Vector2)).is_zero_approx():
		_fail("wave_frame_rot: 4 Vierteldrehungen")
	if ((f0[0] as Vector4) - (f1[0] as Vector4)).is_zero_approx():
		_fail("wave_frame_rot: Vierteldrehung ohne Wirkung")
	# Die Deckseite dreht um ihre Normale: Lage der Kachel nach einer Vierteldrehung + q-Ausgleich = Muster vorher
	# (an einem festen Punkt der Kachel – kein Sprung beim Einrasten)
	var rot := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	var t1 := rot * t
	var g1 := FieldView.wave_frame(t1, n, -1)
	for uv in [Vector2(0.2, -0.3), Vector2(-0.4, 0.1)]:
		var u: Vector2 = uv
		var m0: Vector4 = f0[0]
		var m1: Vector4 = g1[0]
		var p0 := Vector2(m0.x * u.x + m0.y * u.y, m0.z * u.x + m0.w * u.y) + (f0[1] as Vector2)
		var p1 := Vector2(m1.x * u.x + m1.y * u.y, m1.z * u.x + m1.w * u.y) + (g1[1] as Vector2)
		if p0.distance_to(p1) > 1e-4:
			_fail("wave_frame_rot: Sprung beim Einrasten %s / %s" % [p0, p1])
	print("Wellen-Rahmen geprüft")


# --- Nahtlos: Platten schließen lückenlos an, Wasser fließt zusammen, Inhalt bleibt auf der Platte -----------------

func _test_seamless(root: Node3D) -> void:
	# Fuge: Oberseite reicht genau bis zum Nachbarn (±0,502); Würfelkante: biegt um, Gehrung auf 45°
	for outer in [0, 2, 6, 15]:
		var arr := Models.arrays_of(Models.slab_mesh(outer))
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
		if verts.is_empty() or uv2.size() != verts.size():
			_fail("Platte ohne Daten: %d" % outer)
			continue
		var max_x := -INF
		var min_x := INF
		for v in verts:
			max_x = maxf(max_x, v.x)
			min_x = minf(min_x, v.x)
			# Gehrung: kein Punkt der Platte liegt jenseits der 45°-Ebene zur Nachbarseite
			if (outer & 2) != 0 and v.x > v.y + Models.SLAB_BASE + 0.001:
				_fail("Platte ragt über die Gehrung: %d %s" % [outer, v])
				break
		var want_max := Models.SLAB_EDGE - Models.SLAB_R * (1.0 - sqrt(0.5)) if (outer & 2) != 0 else Models.SLAB_SEAM
		if absf(max_x - want_max) > 0.003 or absf(min_x + (want_max if outer == 15 else Models.SLAB_SEAM)) > 0.003:
			_fail("Platte falsch breit: %d %.3f %.3f" % [outer, min_x, max_x])
	# Wasser: Rechtecke je Nachbarmaske (allein: nur der Kern; ganz umgeben: Kerne, Brücken, Füllungen)
	if Look.water_boxes([false, false, false, false, false, false, false, false]).size() != 1:
		_fail("Wasser allein")
	if Look.water_boxes([true, true, true, true, true, true, true, true]).size() != 25:
		_fail("Wasser ganz umgeben")
	# Innenecke: N und O Wasser, NO Land -> Kern, 2 Nachbarkerne, 2 Brücken, keine Füllung
	if Look.water_boxes([true, true, false, false, false, false, false, false]).size() != 5:
		_fail("Wasser Innenecke")
	# Meerenge: Wasser nur über Eck (NO) -> ein Kanal zur Ecke; Landfeld zwischen zwei Wasserfeldern über Eck trägt ihn mit
	var F8 := [false, false, false, false, false, false, false, false]
	var wd := F8.duplicate()
	wd[4] = true
	if Look.water_segs(wd, true).size() != 1 or Look.water_segs(F8, true).size() != 0:
		_fail("Meerenge Wasserfeld")
	var wl := F8.duplicate()
	wl[0] = true
	wl[1] = true
	if Look.water_segs(wl, false).size() != 1:
		_fail("Meerenge Landfeld")
	wl[4] = true
	if Look.water_segs(wl, false).size() != 0:
		_fail("Meerenge, obwohl die Diagonale Wasser ist")
	# Ansicht: Nachbarn setzen, Wassermaske lesen, Inhalt bleibt auf der Platte
	var f := FieldData.new()
	f.id = 7
	var v := FieldView.new()
	root.add_child(v)
	v.position = Vector3(200, 0, 0)
	v.build(f, 6)
	v.set_kind(FieldView.K_WATER)
	v.set_neighbors([FieldView.K_WATER, FieldView.K_MEADOW, -1, FieldView.K_WATER, FieldView.K_FOREST, -1, -1, FieldView.K_WATER])
	if v.debug_water_mask() != [1, 0, 0, 1, 0, 0, 0, 1] or v.outer_mask() != 6:
		_fail("Nachbarn/Wassermaske")
	# Markierungen im Boden: höchster Vorrang gewinnt, Nachbarn erfahren die Nummer (kein Rand zwischen gleichen)
	v.set_hint(true)
	v.set_danger(true)
	if int(v.seam_fx().a) != int((FieldView.MARKS["danger"] as Array)[3]):
		_fail("Markierung: Gefahr vor Hinweis")
	v.set_danger(false)
	if int(v.seam_fx().a) != int((FieldView.MARKS["hint"] as Array)[3]):
		_fail("Markierung: Hinweis")
	v.set_hint(false)
	if v.seam_fx().a != 0.0:
		_fail("Markierung aus")
	# Stauchen: der Fuß des Inhalts bleibt auf dem Boden
	v.set_squash(0.0)
	var foot := v._squash.position.y + v._squash.scale.y * FieldView.TOP
	if v._squash.scale.y > 0.5 or absf(foot - FieldView.TOP) > 0.001:
		_fail("Stauchen")
	v.set_squash(1.0)
	for k in [FieldView.K_BIGFOREST, FieldView.K_VILLAGE, FieldView.K_CHURCH, FieldView.K_HUT]:
		v.set_kind(k)
		for it in v._items:
			var n := it as Node3D
			if absf(n.position.x) > FieldView.INSIDE or absf(n.position.z) > FieldView.INSIDE:
				_fail("Teil außerhalb der Platte: %d %s" % [k, n.position])
	print("Nahtlos geprüft")


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
				"loss":
					v.loss_fx("burn", FieldView.K_FIELD)
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
		var agents := 0
		for e in _views:
			var v: FieldView = e[0]
			var sp: Dictionary = e[1]
			if v.get_kind() < 0:
				_fail("kind nicht gesetzt")
			if not v.is_baked():
				_fail("nicht gebacken: %s" % sp.get("label", FieldView.KIND_KEY[v.get_kind()]))
			agents += v.agent_count()
			if sp.get("alarm", false):
				for st in v.agent_states():
					if st != "flee" and st != "gone":
						_fail("Tier flieht nicht: " + String(st))
		for k in [FieldView.K_ANIMALS, FieldView.K_HUT, FieldView.K_VILLAGE, FieldView.K_TOWN, FieldView.K_CHURCH]:
			var found := false
			for e in _views:
				var v: FieldView = e[0]
				if v.get_kind() == k and v.agent_count() > 0:
					found = true
			if not found:
				_fail("keine Tiere/Menschen: " + FieldView.KIND_KEY[k])
		print("Agenten: %d" % agents)
		# Back-Cache begrenzt (alle Arten × Varianten × Drehungen × Zustände würden sonst 300+ Meshes halten)
		if FieldView.bake_cache_size() > FieldView.BAKE_CACHE_MAX:
			_fail("Back-Cache zu groß: %d" % FieldView.bake_cache_size())
		for ci in 300:
			FieldView._cache_store("probe|%d" % ci, [])
		if FieldView.bake_cache_size() != FieldView.BAKE_CACHE_MAX or not FieldView.bake_cache_has("probe|299") or FieldView.bake_cache_has("probe|0"):
			_fail("Back-Cache LRU: %d Einträge" % FieldView.bake_cache_size())
		else:
			print("Back-Cache: höchstens %d Einträge" % FieldView.BAKE_CACHE_MAX)
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
