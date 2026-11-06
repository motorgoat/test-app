extends SceneTree
# Probe: Tag 1 (Brett 0) nach "Los!" – bewegt sich der Würfel von selbst?
var main: Node
var t := 0.0
var scen := ""
var last_mode := ""
var last_tw := -1
var menu_opened := false
var g: Node

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scen="):
			scen = a.substr(7)
	var ps: PackedScene = load("res://main.tscn")
	main = ps.instantiate()
	root.add_child(main)
	g = root.get_node("Game")

var started := false
func _process(delta: float) -> bool:
	t += delta
	if not started and t > 0.5:
		started = true
		g.coach_seen = {}
		g.start_day(1, 0)
		print("start day=", g.day_no, " board=", g.day_board.get("index"), " tut=", g.day_tutorial())
		return false
	if not started:
		return false
	var ui = main.ui
	var dui = ui.day_ui
	var w = main.world
	if t > 1.5 and not dui._playing:
		dui._on_go()
		print("%.2f LOS  _tut=%d tut_at=%.2f" % [t, dui._tut, dui._tut_at])
	if scen == "menu" and dui._playing and not menu_opened and t > 4.0:
		menu_opened = true
		ui._open_menu()
		print("%.2f MENU open modal=%s" % [t, str(ui.modal_bg.visible)])
	if scen == "cancel" and dui._playing and t > 3.0 and t < 15.0 and w._mode == "" and not w.animating and int(t * 10) % 30 == 0:
		# Spieler "dreht", lässt aber vor der halben Viertel-Drehung los -> zählt nicht
		var mv: Dictionary = g.tutorial_move()
		var mid := -1
		for fid in w.views:
			mid = fid
			break
	var m: String = w._mode
	var live: bool = w._tw_live
	var key := m + ("/live" if live else ("/demo" if m == "twist" else ""))
	if key != last_mode:
		print("%.2f mode %s -> %s  twists=%d animating=%s modal=%s finger=%.2f" % [t, last_mode, key, g.state.twists, str(w.animating), str(ui.modal_bg.visible), ui.tut_finger.modulate.a])
		last_mode = key
	if g.state.twists != last_tw:
		print("%.2f TWISTS=%d progress=%d _tut=%d" % [t, g.state.twists, g.state.goal_progress(), dui._tut])
		last_tw = g.state.twists
	if t > 24.0:
		print("END twists=", g.state.twists, " modal=", ui.modal_bg.visible)
		quit()
	return false
