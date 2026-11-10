extends Node
## Look-Dev der Zeitalter (GDPD_ERDGESCHICHTE_GRAFIK.md 0, 13): baut die echte Welt (World, FieldView, Models, Look,
## Eras) mit einem festen Brett je Zeitalter und speichert ein Bild. Nur zum Ansehen und Messen, nicht Teil des Spiels.
##   xvfb-run -a -s "-screen 0 1100x2400x24" godot --rendering-driver opengl3 --resolution 1080x2340 \
##     res://tests/era_lookdev.tscn -- --mode=saurier --out=/tmp/x.png [--view=weit|nah|see|seite|oben] [--frames=120] [--zoom=1.0]
##     [--at=<Sekunden>] [--t=<Mischung 0..1, nur erholung>] [--debug (druckt Gestalten der neuen Arten)]
## Die Qualität bleibt fest auf „hoch“ (wie in der Tour); Software-Grafik würde sonst auf „niedrig“ schalten.
## Modi: jedes Zeitalter aus BOARDS, dazu impact (Einschlag), impact_warn (Meteor am Himmel), sheet (alle neuen
## Tiere und Pflanzen nebeneinander mit Hirsch und Mensch als Maßstab).
## Gibt „LOOKDEV saved <out> draw=<n> prims=<n>“ aus.

var mode := "saurier"
var out := ""
var zoom := 1.0
var frames := 120
var view := "weit"
var mix_t := -1.0
var at_sec := -1.0               # --at=<s>: Bild nach so vielen Sekunden statt nach frames Bildern (Einschlag)
var _sec := 0.0
var _n := 0
var world: World

## Ein Buchstabe je Art. Heute: B Erde, G Wiese, W Wald, C Acker, T Tiere, H Hütte, D Dorf, K Kirche, A Wasser, R Fels,
## L Lava, U Ursuppe, Z Einzeller, Y Algen, S Fische, M Moos, F Farn, V Vögel, P Raubtiere.
## Erdgeschichte: q Qualle, t Trilobit, i Insekten, b Amphibie, e Reptil, d Saurier, x Raubsaurier, p Flugsaurier,
## c Eis, j Mammut, k Affen, y Frühmenschen, f Feuerstelle.
const C2K := {"B": 0, "G": 1, "W": 2, "C": 3, "T": 5, "H": 6, "D": 8, "K": 10, "A": 15, "R": 16, "L": 17, "U": 18, "Z": 19,
	"Y": 20, "S": 21, "M": 22, "F": 23, "V": 24, "P": 25, "q": 27, "t": 28, "i": 29, "b": 30, "e": 31, "d": 32, "x": 33, "p": 34,
	"c": 35, "j": 36, "k": 37, "y": 38, "f": 39}

## Bretter: x/y/z = die drei sichtbaren Seiten (+x, +y oben, +z), * = alle anderen. Zeilen von oben nach unten.
const BOARDS := {
	"kambrium": {"x": "qAR/tqB/AAR", "y": "AqA/qtB/RBR", "z": "RAq/BtA/RBA", "*": "BAqRtABRq"},
	"meer": {"x": "SSA/SAR/BAS", "y": "ASS/SSA/BRB", "z": "SAR/SSB/ARB", "*": "BASRSABRS"},
	"landgang": {"x": "MMA/FMA/BFA", "y": "AAM/FMM/MFB", "z": "MAF/FFA/BMA", "*": "MAFBMAFMB"},
	"karbon": {"x": "WWi/FbA/WiA", "y": "iWW/bAA/eFW", "z": "AbW/eiW/FWW", "*": "WiFbAAeWF"},
	"saurier": {"x": "WWF/ddA/FAA", "y": "ddF/dAA/WxF", "z": "AAW/xFW/ppF", "*": "FWdWAAFxp"},
	"asche": {"x": "BWB/RAA/BBA", "y": "BWB/BAA/WRB", "z": "AAB/WBB/BRW", "*": "BWBRAABWB"},
	"erholung": {"x": "FWB/TAA/BFA", "y": "TFB/FAA/WTF", "z": "AAF/TBW/BFW", "*": "FWTBAAFTB"},
	"saeuger": {"x": "GWW/TTA/GAA", "y": "TTG/GAA/WPV", "z": "AAW/PGR/VWG", "*": "GWTWAAGPV"},
	"eiszeit": {"x": "WWG/jjA/cAA", "y": "jjG/GAA/WPc", "z": "AAW/PGc/ccG", "*": "GWjWAAcPG"},
	"savanne": {"x": "GGW/TTA/GAA", "y": "kGW/GAA/ykG", "z": "AAG/kkW/WGG", "*": "GWTGAAGkG"},
	"feuer": {"x": "GfW/yyA/GAA", "y": "fGW/GAA/kyG", "z": "AAG/fGW/WkG", "*": "GWyGAAGfG"},
	"jaeger": {"x": "GfW/jjA/GAA", "y": "yGW/GAA/TjG", "z": "AAG/yGW/WfG", "*": "GWjGAAGyG"},
	"glaube": {"x": "KGW/DDA/CAA", "y": "DGW/GAA/HKG", "z": "AAC/HGW/WGC", "*": "GWDGAACHG"},
	"tag": {"x": "GWW/TTA/GAA", "y": "TTG/GAA/WPV", "z": "AAW/PGR/VWG", "*": "GWTWAAGPV"},
}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.substr(7)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--zoom="):
			zoom = float(a.substr(7))
		elif a.begins_with("--frames="):
			frames = int(a.substr(9))
		elif a.begins_with("--view="):
			view = a.substr(7)
		elif a.begins_with("--t="):
			mix_t = float(a.substr(4))
		elif a.begins_with("--at="):
			at_sec = float(a.substr(5))
	if mode == "sheet":
		_sheet()
		return
	var era := mode
	var board := mode
	if mode == "impact" or mode == "impact_warn":
		era = "saurier"
		board = "saurier"
	if not BOARDS.has(board):
		board = "tag"
	Look.set_era(era)
	Game.new_game(3, 1, 1)
	Game.onboarding = false
	var b: Dictionary = BOARDS[board]
	for f in Game.state.fields:
		f.kind = _kind_for(f, b)
		f.fresh = 0
		f.burning = false
	world = World.new()
	add_child(world)
	world._tour = true              # feste Qualität (wie die Tour): sonst schaltet Software-Grafik auf „niedrig“
	if mode == "erholung" and mix_t >= 0.0:
		world.set_era({"preset": "erholung", "dust_clear": mix_t}, 0.0)
	else:
		world.set_era(era, 0.0)
	world.refresh_all()
	if mode == "asche":
		var k := 0
		for f in Game.state.fields:
			if (f as FieldData).kind == 0:
				k += 1
				if k % 4 == 1:
					(world.views[(f as FieldData).id] as FieldView).set_crater(true)
	match view:
		"nah":
			world.debug_view(Vector3(0.35, 1.0, 0.75), Vector3(0, 1, 0), zoom)
		"see":
			world.debug_view(Vector3(0.9, 0.75, 0.9), Vector3(0, 1, 0), zoom)
		"seite":
			world.debug_view(Vector3(1.0, 0.45, 0.35), Vector3(0, 1, 0), zoom)
		"oben":
			world.debug_view(Vector3(0.06, 1.0, 0.1), Vector3(0, 0, -1), zoom)
		_:
			world.debug_view(Vector3(1.0, 1.15, 1.35), Vector3(0, 1, 0), zoom)
	if OS.get_cmdline_user_args().has("--debug"):
		for fid in world.views:
			var dv: FieldView = world.views[fid]
			if dv.get_kind() >= 27:
				print("DBG ", fid, " kind ", dv.get_kind(), " swim ", dv.flyer_kinds(), " agents ", dv.agent_kinds(), " q ", Look.quality,
					" fauna ", dv._ground.get_shader_parameter("w_fauna"), " detail ", dv.get_detail())
	if mode == "impact_warn":
		world.set_meteor(true)
	if mode == "impact":
		_impact.call_deferred()


func _impact() -> void:
	await get_tree().create_timer(0.8).timeout
	var dinos: Array = []
	for f in Game.state.fields:
		if [32, 33, 34].has((f as FieldData).kind):
			dinos.append((f as FieldData).id)
	for i in dinos:
		(Game.state.fields[int(i)] as FieldData).kind = 0
	world.meteor_strike(dinos)


func _kind_for(f: FieldData, b: Dictionary) -> int:
	var a := GameState.axis_of(f.n)
	var key := "xyz"[a]
	var pos := [f.p.x, f.p.y, f.p.z]
	var u: int = pos[(a + 1) % 3] + 1
	var v: int = pos[(a + 2) % 3] + 1
	var s: String
	if f.n[a] > 0 and b.has(key):
		s = String(b[key]).replace("/", "")
	else:
		s = String(b["*"])
	return int(C2K.get(s[v * 3 + u], 0))


# =============================================================================
# Sheet: alle neuen Tiere und Pflanzen auf neutralem Boden, mit Hirsch und Mensch als Maßstab
# =============================================================================

func _sheet() -> void:
	var root := Node3D.new()
	add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#d8dcd4")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#a8b4c4")
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -40, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(5, 5)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#6f7a58")
	gm.roughness = 1.0
	ground.material_override = gm
	root.add_child(ground)
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 44.0
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 2.3, 2.6), Vector3(0, 0.0, -0.12))
	# Reihen: [Art, Variante, Maßstab im Spiel, Beschriftung]
	var rows := [
		[["trilobite", 0, 1.6, "Trilobit"], ["jelly", 0, 1.6, "Qualle"], ["armorfish", 0, 1.6, "Panzerfisch"], ["dragonfly", 0, 1.4, "Libelle"],
			["amph", 0, 1.3, "Amphibie"], ["lizard", 0, 1.6, "Reptil"], ["deer", 0, 1.6, "Hirsch (heute)"]],
		[["sauro", 0, 1.3, "Langhals"], ["trex", 0, 1.35, "Raubsaurier"], ["raptor", 1, 1.6, "Raptor"], ["ptero", 0, 1.2, "Flugsaurier"]],
		[["shrew", 0, 2.0, "Ursäuger"], ["horse", 0, 1.6, "Urpferd"], ["mammoth", 0, 1.25, "Mammut"], ["cave_lion", 0, 1.6, "Höhlenlöwe"],
			["antelope", 0, 1.6, "Antilope"], ["wolf", 0, 1.6, "Wolf (heute)"]],
		[["ape", 0, 1.5, "Affe"], ["hunter", 0, 1.0, "Frühmensch"], ["hunter", 2, 1.0, "Frühmensch"], ["person", 1, 1.0, "Mensch (heute)"],
			["bison", 0, 1.6, "Wisent (heute)"]],
	]
	var zs := [-0.5, -0.05, 0.4, 0.85]
	for r in rows.size():
		var row: Array = rows[r]
		for i in row.size():
			var it: Array = row[i]
			var x := -0.95 + 1.9 * float(i) / float(maxi(row.size() - 1, 1))
			var mi := MeshInstance3D.new()
			mi.mesh = Models.creature_mesh(String(it[0]), int(it[1]))
			mi.material_override = Models.creature_material(float(i))
			var sc := float(it[2]) * 1.4 * 1.6          # CONTENT_SCALE · Sheet-Zoom
			mi.scale = Vector3.ONE * sc
			mi.position = Vector3(x, 0.08 if String(it[0]) in ["ptero", "dragonfly", "jelly"] else 0.0, float(zs[r]))
			mi.rotation.y = -0.5
			root.add_child(mi)
			var lb := Label3D.new()
			lb.text = String(it[3])
			lb.font_size = 40
			lb.pixel_size = 0.0016
			lb.modulate = Color("#202020")
			lb.outline_size = 0
			lb.position = Vector3(x, 0.005, float(zs[r]) + 0.16)
			lb.rotation_degrees = Vector3(-90, 0, 0)
			root.add_child(lb)
	var plants := [["cycad", 0], ["araucaria", 0], ["lepido", 0], ["acacia", 0], ["campfire", 0], ["fur_tent", 0], ["stone_circle", 0],
		["skeleton", 0], ["ice_block", 0], ["eggs", 0], ["drying_rack", 0], ["tree_fern", 0]]
	for i in plants.size():
		var pl: Array = plants[i]
		var holder := Node3D.new()
		holder.position = Vector3(-1.0 + 2.0 * float(i) / float(plants.size() - 1), 0, -1.05)
		holder.scale = Vector3.ONE * 1.4 * 1.6
		root.add_child(holder)
		for pv in Models.get_model(String(pl[0]), int(pl[1])):
			var part: Array = pv
			var mi2 := MeshInstance3D.new()
			mi2.mesh = part[0]
			mi2.material_override = Models.material(String(part[1]))
			holder.add_child(mi2)
		if String(pl[0]) == "campfire":
			Models.flame(holder, Vector3(0, 0.008, 0), 0.3, 3, 1.0)


func _process(d: float) -> void:
	_n += 1
	_sec += d
	if (at_sec > 0.0 and _sec >= at_sec and _n > 5) or (at_sec <= 0.0 and _n == frames):
		at_sec = 1e9
		var img := get_viewport().get_texture().get_image()
		img.save_png(out)
		print("LOOKDEV saved ", out, " draw=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			" prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		get_tree().quit()
