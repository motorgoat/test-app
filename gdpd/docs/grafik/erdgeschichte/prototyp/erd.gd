extends Node
## PROTOTYP Erdgeschichte – Look-Dev der neuen Zeitalter (nur im Scratchpad, echtes Projekt als Kopie).
##   godot res://lookdev/erd.tscn -- --mode=saurier --out=/x.png --zoom=1.0 --frames=120 [--view=nah]
## Modi: saurier, asche (nach dem Meteor), erholung, eiszeit, eiszeit_aus (gleiches Brett ohne Schnee/Eis), savanne,
##       sheet (alle neuen Tiere und Pflanzen nebeneinander, mit Hirsch und Mensch als Maßstab)

var mode := "saurier"
var out := ""
var zoom := 1.0
var frames := 120
var view := "weit"
var _n := 0
var world: World

# T Tiere, P Raubtiere, V Vögel, F Farn, W Wald, A Wasser, S Fische, B Erde, G Wiese, R Fels, M Moos, H Hütte, D Dorf
const C2K := {"T": 5, "P": 25, "V": 24, "F": 23, "W": 2, "A": 15, "S": 21, "B": 0, "G": 1, "R": 16, "M": 22, "H": 6, "D": 8}

const BOARDS := {
	"saurier": {"x": "WWF/TTA/FAA", "y": "TTF/TAA/WPF", "z": "AAW/PFW/VVF", "*": "FWTWAAFPF"},
	"asche": {"x": "BWB/RAA/BBA", "y": "BWB/BAA/WRB", "z": "AAB/WBB/BRW", "*": "BWBRAABWB"},
	"erholung": {"x": "FWB/TAA/BFA", "y": "TFB/FAA/WTF", "z": "AAF/TBW/BFW", "*": "FWTBAAFTB"},
	"eiszeit": {"x": "WWG/TTA/GAA", "y": "TTG/GAA/WPG", "z": "AAW/PGW/WGG", "*": "GWTWAAGPG"},
	"savanne": {"x": "GGW/TTA/GAA", "y": "TGW/GAA/HTG", "z": "AAG/HGW/WGG", "*": "GWTGAAGHG"},
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
	if mode == "sheet":
		_sheet()
		return
	var era := mode
	var board := mode
	if mode == "eiszeit_aus":
		era = "tag"
		board = "eiszeit"
	Look.set_era(era)
	Game.new_game(3, 1, 1)
	Game.onboarding = false
	var b: Dictionary = BOARDS[board]
	for f in Game.state.fields:
		f.kind = _kind_for(f, b)
		f.fresh = 0
		f.burning = false
		if mode == "asche" and f.kind == 2:
			f.fresh = 2               # verbrannter Wald: kahle, tote Stämme
	world = World.new()
	add_child(world)
	world.set_era(era, 0.0)
	world.refresh_all()
	if mode == "asche":
		var k := 0
		for f in Game.state.fields:
			if (f as FieldData).kind == 0:
				k += 1
				if k % 3 == 1:
					(world.views[(f as FieldData).id] as FieldView).set_crater(true)
	match view:
		"nah":
			world.debug_view(Vector3(0.35, 1.0, 0.75), Vector3(0, 1, 0), zoom)
		"see":
			world.debug_view(Vector3(0.9, 0.75, 0.9), Vector3(0, 1, 0), zoom)
		_:
			world.debug_view(Vector3(1.0, 1.15, 1.35), Vector3(0, 1, 0), zoom)
	if mode == "eiszeit":
		_fall(Color(0.97, 0.98, 1.0, 0.9), 160, 0.012, 0.022, -0.12)
	elif mode == "asche":
		_fall(Color(0.42, 0.4, 0.4, 0.85), 180, 0.01, 0.02, -0.06)


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
	return int(C2K[s[v * 3 + u]])


## Schnee (Eiszeit) bzw. Asche (nach dem Meteor): Flocken fallen langsam um den Würfel (ein Draw-Call).
func _fall(c: Color, amount: int, s0: float, s1: float, g: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.mesh = Look.quad(1.0)
	p.material_override = Look.mote(c, true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(2.2, 0.3, 2.2)
	p.position = Vector3(0, 2.6, 0)
	p.direction = Vector3(0.3, -1, 0.1)
	p.spread = 20.0
	p.gravity = Vector3(0.02, g, 0.0)
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.3
	p.scale_amount_min = s0
	p.scale_amount_max = s1
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.15, Color(1, 1, 1, 1))
	fade.add_point(0.85, Color(1, 1, 1, 1))
	p.color_ramp = fade
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)


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
	pm.size = Vector2(4, 4)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#6f7a58")
	gm.roughness = 1.0
	ground.material_override = gm
	root.add_child(ground)
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 40.0
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 1.9, 2.3), Vector3(0, 0.0, -0.08))
	# Reihen: [Art, Variante, Maßstab im Spiel (HERD_SCALE usw.), Beschriftung]
	var rows := [
		[["trilobite", 0, 1.6, "Trilobit"], ["jelly", 0, 1.6, "Qualle"], ["fish", 0, 1.6, "Fisch"], ["dragonfly", 0, 1.4, "Libelle"],
			["amph", 0, 1.3, "Amphibie"], ["deer", 0, 1.6, "Hirsch (heute)"]],
		[["sauro", 0, 1.0, "Langhals"], ["trex", 0, 1.0, "Raubsaurier"], ["raptor", 1, 1.3, "Raptor"], ["ptero", 0, 1.2, "Flugsaurier"]],
		[["shrew", 0, 2.0, "Ursäuger"], ["mammoth", 0, 1.25, "Mammut"], ["ape", 0, 1.5, "Affe"], ["hunter", 0, 1.0, "Jäger"],
			["person", 1, 1.0, "Mensch (heute)"], ["wolf", 0, 1.6, "Wolf (heute)"]],
	]
	var zs := [-0.42, 0.0, 0.42]
	for r in rows.size():
		var row: Array = rows[r]
		for i in row.size():
			var it: Array = row[i]
			var x := -0.75 + 1.5 * float(i) / float(maxi(row.size() - 1, 1))
			var mi := MeshInstance3D.new()
			mi.mesh = Models.creature_mesh(String(it[0]), int(it[1]))
			var mat := Models.creature_material(float(i))
			mi.material_override = mat
			var s := float(it[2]) * 1.4 * 1.6          # CONTENT_SCALE · Sheet-Zoom
			mi.scale = Vector3.ONE * s
			mi.position = Vector3(x, 0.08 if String(it[0]) in ["ptero", "dragonfly", "jelly"] else 0.0, float(zs[r]))
			mi.rotation.y = -0.5
			root.add_child(mi)
			var lb := Label3D.new()
			lb.text = String(it[3])
			lb.font_size = 40
			lb.pixel_size = 0.0016
			lb.modulate = Color("#202020")
			lb.outline_size = 0
			lb.position = Vector3(x, 0.005, float(zs[r]) + 0.14)
			lb.rotation_degrees = Vector3(-90, 0, 0)
			root.add_child(lb)
	var plants := [["cycad", 0], ["araucaria", 0], ["acacia", 0], ["campfire", 0], ["snow_spruce", 0], ["tree_fern", 0]]
	for i in plants.size():
		var pl: Array = plants[i]
		var holder := Node3D.new()
		holder.position = Vector3(-0.75 + 0.3 * float(i), 0, -0.78)
		holder.scale = Vector3.ONE * 1.4 * 1.6
		root.add_child(holder)
		for pv in Models.get_model(String(pl[0]), int(pl[1])):
			var part: Array = pv
			var mi2 := MeshInstance3D.new()
			mi2.mesh = part[0]
			mi2.material_override = Models.material(String(part[1]))
			holder.add_child(mi2)
		if String(pl[0]) == "campfire":
			Models.flame(holder, Vector3(0, 0.008, 0), 0.03, 3, 1.0)


func _process(_d: float) -> void:
	_n += 1
	if _n == frames:
		var img := get_viewport().get_texture().get_image()
		img.save_png(out)
		print("LOOKDEV saved ", out, " draw=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			" prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		get_tree().quit()
