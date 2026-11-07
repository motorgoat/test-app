extends Node
## PROTOTYP „Die Schöpfung“ – Look-Dev der Zeitalter (nur im Scratchpad).
##   godot --path proj res://lookdev/era.tscn -- --mode=glut --out=/x.png --zoom=1.0 --frames=120
## Modi: glut (Akt 1), dunst (Akt 2), blau (Akt 3), nacht (Akt 4), lava (Nahaufnahme), merge0 / merge1 (Wald vorher/nachher)

var mode := "glut"
var out := ""
var zoom := 1.0
var frames := 120
var _n := 0
var world: World

const C2K := {"L": 16, "B": 0, "W": 15, "M": 1, "F": 2, "A": 3, "T": 5, "H": 6, "V": 8, "G": 4, "C": 10, "S": 9}

## Seite (Normale) -> 3x3 (Zeile = zweite Achse, Spalte = erste Achse der Seite)
const BOARDS := {
	"glut": {"x": "LLB/LWW/BWW", "y": "BLL/BBL/WWB", "z": "WWB/WLL/BBL", "*": "BBLBWWBLB"},
	"dunst": {"x": "BBB/LWW/BWW", "y": "BWB/BBW/WWB", "z": "WWB/WWL/BBB", "*": "BBWBWWBWB"},
	"blau": {"x": "MFF/MWW/BWW", "y": "MMF/FFM/WWM", "z": "WWM/WMF/MFF", "*": "MFWMWWFMF"},
	"nacht": {"x": "AVF/AWW/HWW", "y": "MAF/FVM/WWA", "z": "WWH/WMF/AAF", "*": "MFWMWWFMF"},
	"lava": {"x": "LLB/LWW/BWW", "y": "LLL/LLB/WWB", "z": "WWB/WLL/BLL", "*": "BBLBWWBLB"},
	"merge": {"x": "MFF/MFF/MMW", "y": "MMM/FFF/FFM", "z": "MFF/FFF/MFW", "*": "MFMFFMMFM"},
	"herd": {"x": "TTM/TTM/MMW", "y": "MMM/AAF/AAM", "z": "MVV/HVV/MMW", "*": "MFMFFMMFM"},
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
	var board := mode
	var mood := "tag"
	match mode:
		"glut", "lava":
			Look.era = 1
			Look.water_era = 1
			mood = "glut"
		"dunst":
			Look.era = 2
			Look.water_era = 2
			mood = "dunst"
		"blau":
			Look.water_era = 3
		"nacht":
			Look.water_era = 0
			mood = "nacht"
		"merge0", "merge1":
			board = "merge"
			FieldView.merge_on = mode == "merge1"
		"herd":
			pass
	Game.new_game(3, 1, 1)
	Game.onboarding = false
	var b: Dictionary = BOARDS[board]
	for f in Game.state.fields:
		f.kind = _kind_for(f, b)
		f.fresh = 0
		f.burning = false
	world = World.new()
	add_child(world)
	world.hold_mood(mood, 0.0)
	world.refresh_all()
	world.debug_view(Vector3(1.0, 1.15, 1.35), Vector3(0, 1, 0), zoom)
	if mode == "lava" or mode.begins_with("merge"):
		world.debug_view(Vector3(0.25, 1.0, 0.8), Vector3(0, 1, 0), zoom)
	if mood == "glut":
		_embers()
	if OS.get_cmdline_user_args().has("--bg"):
		world.debug_bright_bg(true)


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


## Glut: Funken steigen um den Würfel (ein Draw-Call).
func _embers() -> void:
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.mesh = Look.quad(1.0)
	p.material_override = Look.mote(Color(1.0, 0.55, 0.2, 0.9), true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(1.6, 0.4, 1.6)
	p.position = Vector3(0, 1.2, 0)
	p.direction = Vector3(0, 1, 0)
	p.spread = 25.0
	p.gravity = Vector3(0.02, 0.05, 0)
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.2
	p.scale_amount_min = 0.012
	p.scale_amount_max = 0.03
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	p.color_ramp = fade
	add_child(p)


func _process(_d: float) -> void:
	_n += 1
	if _n == frames:
		var img := get_viewport().get_texture().get_image()
		img.save_png(out)
		print("LOOKDEV saved ", out, " draw=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			" prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		get_tree().quit()
