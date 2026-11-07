extends SceneTree
## Temporär: Weiterbauen in der echten Szene (Welt + Oberfläche), Züge über Game, Hänger erkennen.
## --script res://tests/_dbg_soak.gd -- <day|0=wdt> <board> <actions> <seed>

var g: Node
var world: Node
var last_events: Array = []
var last_action := {}
var rng := RandomNumberGenerator.new()
var game_t := 0.0
var hangs := 0


func _initialize() -> void:
	_drive()


func _frames(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await process_frame
		t += 1.0 / 60.0


func _on_res(result: Dictionary, _before: Dictionary) -> void:
	last_events = []
	for e in result["events"]:
		last_events.append(str(e["type"]))
	if result.has("bonus"):
		last_events.push_front("BONUS:" + str(result["bonus"]["kind"]))


## true = fertig, false = Hänger
func _settle(limit: float, label: String) -> bool:
	var t := 0.0
	var wall0 := Time.get_ticks_msec()
	while t < limit:
		if g.has_choice():
			g.choose(0)
		if not g.busy and not bool(world.get("animating")):
			return true
		var w0 := Time.get_ticks_msec()
		await process_frame
		if Time.get_ticks_msec() - w0 > 3000:
			print("STALL frame %.1fs at %s" % [float(Time.get_ticks_msec() - w0) / 1000.0, label])
		t += 1.0 / 60.0
	hangs += 1
	print("HANG %s busy=%s animating=%s mode=%s choice=%s over=%s wall=%.1fs action=%s events=%s" % [label, str(g.busy),
		str(world.get("animating")), str(world.get("_mode")), str(g.has_choice()), str(g.over),
		float(Time.get_ticks_msec() - wall0) / 1000.0, str(last_action), str(last_events)])
	return false


func _act(a: Dictionary, label: String) -> bool:
	last_action = a
	var t := str(a.get("type", "twist"))
	if t == "twist":
		g.play_turn(int(a["axis"]), int(a["layer"]), int(a["turns"]))
	else:
		if not g.use_bonus(t, int(a["field"]), [], true):
			return true
	return await _settle(40.0, label)


func _rand_action() -> Dictionary:
	var gs: GameState = g.state
	var r := rng.randf()
	if gs.rain > 0 and r < 0.25:
		var ids: Array = []
		for f in gs.fields:
			if gs.rain_ok(f):
				ids.append(f.id)
		if not ids.is_empty():
			return {"type": "rain", "field": ids[rng.randi_range(0, ids.size() - 1)]}
	if bool(gs.day.get("meteor", false)) and gs.faith >= GameState.METEOR_COST and r < 0.5:
		return {"type": "strike", "field": rng.randi_range(0, 53)}
	if r < 0.75:
		var m: Array = GameState.MOVES[rng.randi_range(0, GameState.MOVES.size() - 1)]
		return {"type": "twist", "axis": m[0], "layer": m[1], "turns": m[2]}
	var b: Dictionary = gs.best_action()
	if b.is_empty():
		var m2: Array = GameState.MOVES[0]
		return {"type": "twist", "axis": m2[0], "layer": m2[1], "turns": m2[2]}
	return b


func _drive() -> void:
	await process_frame
	g = root.get_node("Game")
	var args := OS.get_cmdline_user_args()
	var day := int(args[0]) if args.size() > 0 else 1
	var bi := int(args[1]) if args.size() > 1 else 1
	var n_act := int(args[2]) if args.size() > 2 else 80
	rng.seed = int(args[3]) if args.size() > 3 else 5
	g.first_launch = false
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(1.0)
	world = main.get("world")
	g.round_resolved.connect(_on_res)
	var cfg: Dictionary = Days.config(day) if day > 0 else Daily.wdt_config(g.today_key())
	var b: Dictionary = Days.board(day, bi) if day > 0 else Daily.wdt_board(g.today_key())
	if day == 0:
		g.wdt_key = g.today_key()
	g._start_attempt(int(cfg["day"]), cfg, b, 40)
	await _frames(1.5)
	var n := 0
	while not g.state.day_won and n < 80 and not g.over:
		var a: Dictionary = g.state.best_action()
		if a.is_empty() or rng.randf() < 0.05:
			a = _rand_action()
		if not await _act(a, "win%d" % n):
			break
		n += 1
	print("WIN-PHASE day=%d won=%s n=%d over=%s" % [day, str(g.state.day_won), n, str(g.over)])
	if not g.state.day_won:
		g.state.day_won = true
		g.state.day_won_at = g.state.used_twists()
	await _frames(2.0)
	var ok: bool = g.continue_build()
	print("CONTINUE ok=%s free=%s" % [str(ok), str(g.state.day_free_build)])
	await _frames(1.0)
	var ui: Node = main.get("ui")
	var dui: Node = ui.get("day_ui")
	if args.size() > 4 and args[4] == "undo":
		print("UNDO-TEST before: blocked=%s blocking=%s playing=%s" % [str(ui._blocked()), str(dui.blocking()), str(dui.get("_playing"))])
		await _act(_rand_action(), "pre-undo")
		print("UNDO-TEST after move: can_undo=%s blocked=%s blocking=%s" % [str(g.can_undo()), str(ui._blocked()), str(dui.blocking())])
		g.undo()
		await _frames(2.0)
		print("UNDO-TEST after undo: blocked=%s blocking=%s playing=%s busy=%s anim=%s free=%s" % [str(ui._blocked()), str(dui.blocking()),
			str(dui.get("_playing")), str(g.busy), str(world.get("animating")), str(g.state.day_free_build)])
		await _frames(10.0)
		print("UNDO-TEST +10s: blocked=%s blocking=%s" % [str(ui._blocked()), str(dui.blocking())])
	var wall0 := Time.get_ticks_msec()
	for i in n_act:
		var a2 := _rand_action()
		if not await _act(a2, "build%d" % i):
			# weiter versuchen, ob es sich löst
			await _frames(30.0)
			print("AFTER+30s busy=%s animating=%s" % [str(g.busy), str(world.get("animating"))])
			break
		if i % 20 == 0:
			print("build %d twists=%d extra=%d/%d prog=%d faith=%d rain=%d wall=%.0fs" % [i, g.state.twists, g.state.extra_level,
				g.state.extra_max(), g.state.goal_progress(), g.state.faith, g.state.rain, float(Time.get_ticks_msec() - wall0) / 1000.0])
	print("SOAK DONE day=%d hangs=%d" % [day, hangs])
	quit()
