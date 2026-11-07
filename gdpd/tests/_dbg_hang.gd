extends SceneTree
## Temporär: Hang-Jagd im Weiterbauen. Aufruf: --script res://tests/_dbg_hang.gd -- <day> <boards> <steps> <mode>

var worst := {}


func _t(name: String, t0: int) -> void:
	var dt := Time.get_ticks_usec() - t0
	if dt > int(worst.get(name, [0])[0]):
		worst[name] = [dt]
	if dt > 3000000:
		print("SLOW %s %.2fs" % [name, float(dt) / 1e6])


func _rand_twist(rng: RandomNumberGenerator) -> Array:
	return GameState.MOVES[rng.randi_range(0, GameState.MOVES.size() - 1)]


func _win(gs: GameState, rng: RandomNumberGenerator) -> bool:
	var n := 0
	while not gs.day_won and n < 120:
		var t0 := Time.get_ticks_usec()
		var a := gs.best_action()
		_t("best_action_pre", t0)
		if a.is_empty() or rng.randf() < 0.1:
			var m := _rand_twist(rng)
			a = {"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])}
		gs.play(a, {})
		n += 1
		if gs.day_lost != "":
			gs.day_lost = ""
			gs.day_limit += 50
	if not gs.day_won:
		gs.day_won = true
		gs.day_won_at = gs.used_twists()
	return true


func _step(gs: GameState, rng: RandomNumberGenerator, mode: String) -> String:
	var r := rng.randf()
	var t0 := Time.get_ticks_usec()
	var m := _rand_twist(rng)
	# Vorschau wie Game.preview (beim Ziehen)
	if rng.randf() < 0.5:
		var sim := gs.clone()
		sim.apply_rotation(int(m[0]), int(m[1]), int(m[2]))
		var _arr := sim.clone()
		sim.end_round()
		gs.preview8(int(m[0]), int(m[1]), int(m[2]), sim)
		_t("preview", t0)
	t0 = Time.get_ticks_usec()
	gs.day_status()
	gs.rain_targets()
	gs.rain_spots()
	_t("status", t0)
	if mode == "hint" or (mode == "mix" and r < 0.3):
		t0 = Time.get_ticks_usec()
		var a := gs.best_action()
		_t("best_action", t0)
		if not a.is_empty():
			t0 = Time.get_ticks_usec()
			gs.play(a, {})
			_t("play_hint", t0)
			return str(a.get("type", ""))
	if gs.rain > 0 and r < 0.5:
		var ids: Array = []
		for f in gs.fields:
			if gs.rain_ok(f):
				ids.append(f.id)
		if not ids.is_empty():
			var fid: int = ids[rng.randi_range(0, ids.size() - 1)]
			if gs.can_bonus("rain", gs.fields[fid]) == "":
				t0 = Time.get_ticks_usec()
				gs.play({"type": "rain", "field": fid}, {})
				_t("rain", t0)
				return "rain"
	if gs.meteor_ok(gs.fields[0]) or (bool(gs.day.get("meteor", false)) and gs.faith >= GameState.METEOR_COST):
		if r < 0.7:
			var fid2 := rng.randi_range(0, gs.fields.size() - 1)
			if gs.can_bonus("strike", gs.fields[fid2]) == "":
				t0 = Time.get_ticks_usec()
				gs.play({"type": "strike", "field": fid2}, {})
				_t("strike", t0)
				return "strike"
	t0 = Time.get_ticks_usec()
	gs.play({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])}, {})
	_t("twist", t0)
	return "twist"


func _run(cfg: Dictionary, b: Dictionary, label: String, steps: int, mode: String, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var gs := GameState.new()
	gs.setup_day(cfg, b["kinds"], int(b["seed"]), 0)
	_win(gs, rng)
	gs.start_free_build()
	var t_all := Time.get_ticks_usec()
	for i in steps:
		var what := _step(gs, rng, mode)
		if i % 50 == 0:
			print("%s step %d %s twists=%d extra=%d/%d prog=%d faith=%d rain=%d war=%s" % [label, i, what, gs.twists,
				gs.extra_level, gs.extra_max(), gs.goal_progress(), gs.faith, gs.rain, str(gs.war_on)])
		if gs.is_over():
			print("%s OVER?! at %d" % [label, i])
			break
	print("%s done %.1fs" % [label, float(Time.get_ticks_usec() - t_all) / 1e6])


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var day := int(args[0]) if args.size() > 0 else 1
	var boards := int(args[1]) if args.size() > 1 else 2
	var steps := int(args[2]) if args.size() > 2 else 200
	var mode := str(args[3]) if args.size() > 3 else "mix"
	if day == 0:
		# Welt des Tages: einige Spieltage
		var k0 := Daily.day_key(int(Time.get_unix_time_from_system()))
		for j in boards:
			var key := k0 + j
			var cfg := Daily.wdt_config(key)
			_run(cfg, Daily.wdt_board(key), "wdt%d(t%d)" % [key, int(cfg["day"])], steps, mode, 1000 + j)
	else:
		var cfg2 := Days.config(day)
		for bi in boards:
			_run(cfg2, Days.board(day, bi), "d%d/b%d" % [day, bi], steps, mode, 77 + bi * 13)
	for k in worst:
		print("WORST %s %.3fs" % [k, float(worst[k][0]) / 1e6])
	print("ALL DONE")
	quit()
