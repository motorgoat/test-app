extends Node
## PROTOTYP: Wasser dreht mit der Scheibe mit (nur Scratchpad).
##   godot res://lookdev/wasser.tscn -- --mode=heute|neu --out=/dir
var mode := "heute"
var out := ""
var world: World

# Oberseite (y+): Zeilen z = -1..1, Spalten x = -1..1. W Wasser, M Wiese, F Wald, E Erde
const TOP := "WWM/WFW/MWW"
const SIDE := "WWW/MEM/EME"    # obere Reihe der Seiten: Wasser (wechselt beim Drehen die Seite)
const C2K := {"W": 15, "M": 1, "F": 2, "E": 0}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.substr(7)
		elif a.begins_with("--out="):
			out = a.substr(6)
	World.wave_ride = mode == "neu"
	Game.new_game(3, 1, 1)
	Game.onboarding = false
	for f in Game.state.fields:
		f.kind = _kind_for(f)
		f.fresh = 0
		f.burning = false
	world = World.new()
	add_child(world)
	world.hold_mood("tag", 0.0)
	world.refresh_all()
	world.debug_view(Vector3(0.35, 1.0, 0.75), Vector3(0, 1, 0), 0.8)
	_run()


func _kind_for(f: FieldData) -> int:
	var s := ""
	var u := 0
	var v := 0
	if f.n.y > 0:
		s = TOP.replace("/", "")
		u = f.p.x + 1
		v = f.p.z + 1
	else:
		s = SIDE.replace("/", "")
		u = (f.p.x + f.p.z + 2) % 3
		v = 1 - f.p.y
	return int(C2K[s[v * 3 + u]])


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out + "/" + mode + "_" + name + ".png")
	print("LOOKDEV ", mode, " ", name, " draw=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		" prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	await _frames(90)
	world._tw_axis = 1
	world._tw_layer = 1
	world._tw_sign = 1
	world._pivot = Node3D.new()
	world.cube_root.add_child(world._pivot)
	for cb in world._slice_cubies(1, 1):
		(cb as Node3D).reparent(world._pivot, true)
	world._twist_seams()
	var piv: Node3D = world._pivot
	for deg in [0, 30, 60, 90]:
		piv.basis = Basis(Vector3.UP, deg_to_rad(float(deg)))
		await _frames(2)
		await _shot("a%02d" % deg)
	world._unparent_pivot(piv, 1, 1)
	await _frames(1)
	await _shot("end0")
	await _frames(12)
	await _shot("end_fade")
	await _frames(40)
	await _shot("end1")
	get_tree().quit()
