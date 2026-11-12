extends SceneTree
## Audit „start“: jeder Weg, auf dem ein Level beginnt – ist der Start immer lösbar und logisch?
## Kein CI-Test. Läuft über die echten Wege (Game.start_level, _level_start_board, Campaign.carry/ensure,
## _finish_level, _migrate_camp, saved_run/resume_run) mit eigenen Game-Knoten (save_path umgeleitet).
##   godot --headless --script res://tests/_audit_start.gd -- mode=inject from=2 to=60
##   godot --headless --script res://tests/_audit_start.gd -- mode=chain style=hint|over|grow seed=1 [to=60]
##   godot --headless --script res://tests/_audit_start.gd -- mode=b12
##   godot --headless --script res://tests/_audit_start.gd -- mode=paths
## Zeilen: ROW (ein Start), OVER (Vorausspielen im Level davor), SUM (je Level), FAIL (ein Fehler mit Brett).

const GameScript = preload("res://scripts/game.gd")
const W := FieldData.WATER

var tag := "x"
var lite := false
var t_now := 0
var fails := 0


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := str(a).split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var mode := str(args.get("mode", "inject"))
	tag = "%s_%s_%s_%s_%s" % [mode, str(args.get("from", "0")), str(args.get("style", "")), str(args.get("seed", "")), str(args.get("levels", "")).replace(",", "-")]
	t_now = Daily.local_unix(2026, 11, 12, 10)
	lite = str(args.get("lite", "0")) == "1"
	if mode == "inject":
		run_inject(int(args.get("from", 2)), int(args.get("to", Campaign.COUNT)))
	elif mode == "chain":
		run_chain(str(args.get("style", "hint")), int(args.get("seed", 1)), int(args.get("to", Campaign.COUNT)))
	elif mode == "b12":
		var lvs: Array = []
		for x in str(args.get("levels", "5,6,7,8,12,20,30")).split(","):
			lvs.append(int(x))
		var vars: Array = []
		for y in str(args.get("variants", "A_start_run,A_plain,B_sol,B_ahead,B_today")).split(","):
			vars.append(str(y))
		run_b12(lvs, vars)
	elif mode == "paths":
		run_paths()
	elif mode == "pool":
		run_pool(int(args.get("from", 1)), int(args.get("to", Campaign.COUNT)), int(args.get("boards", 1)))
	print("DONE mode=%s fails=%d" % [mode, fails])
	quit()


# --- Helfer -------------------------------------------------------------------------------------

func save_file() -> String:
	return "user://audit_start_%s.cfg" % tag


func mk_game(path: String, now: int, fresh: bool) -> Node:
	if fresh:
		for p in [path, path.get_basename() + "_lauf.cfg"]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
	var g: Node = GameScript.new()
	g.save_path = path
	g.reminder_echo = false
	g.clock_override = now
	g._load_best()
	return g


func twist(m: Array) -> Dictionary:
	return {"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])}


## Eine Aktion spielen: im echten Game (finish_round: Netz, Lauf speichern, Sieg) oder nur auf dem Stand.
func act(g: Node, gs: GameState, action: Dictionary) -> void:
	var res: Dictionary = gs.play(action)
	if g != null:
		g.finish_round(res)


func cnt_of(kinds: Array) -> Dictionary:
	var c := {}
	for k in kinds:
		c[int(k)] = int(c.get(int(k), 0)) + 1
	return c


func kinds_of(gs: GameState) -> Array:
	var out: Array = []
	for f in gs.fields:
		out.append(f.kind)
	return out


func subs_flat(gs: GameState) -> Array:
	var out: Array = []
	for sd in gs.goal9:
		var subs: Array = (sd as Dictionary)["subs"] if str((sd as Dictionary)["type"]) == "hold" else [sd]
		for x in subs:
			out.append(x)
	return out


## Braucht die Ziel-Kette dieses Levels Wasser? (Quelle des Ziels, oder ein Bedürfnis „wet“ auf dem Weg dorthin)
func needs_water(gs: GameState) -> bool:
	var ks := {}
	for x in subs_flat(gs):
		for k in (x as Dictionary)["kinds"]:
			ks[int(k)] = true
	var src: Dictionary = gs._sources9(ks, true)
	if src.has(W):
		return true
	for k2 in gs.thrive9:
		if (ks.has(int(k2)) or src.has(int(k2))) and (((gs.thrive9[k2] as Dictionary)["needs"]) as Dictionary).has("wet"):
			return true
	return false


## Vorrat je Teilziel am Start: "make/group Art Ziel Vorrat" (Vorrat = Felder, die noch zur Ziel-Art werden können).
func supply_text(gs: GameState) -> String:
	var s := ""
	for x in subs_flat(gs):
		var xd: Dictionary = x
		var ks := {}
		for k in xd["kinds"]:
			ks[int(k)] = true
		var su: Dictionary = gs._supply9(ks)
		s += "%s:%s:t%d:s%d " % [str(xd["type"]), FieldData.kind_name(int(xd["kind"])), int(xd["target"]), int(su["supply"])]
	return s.strip_edges()


## Die kleinste Reserve über alle make-Teilziele (Vorrat − Ziel); 99 wenn es keins gibt.
func min_slack(gs: GameState) -> int:
	var m := 99
	for x in subs_flat(gs):
		var xd: Dictionary = x
		if str(xd["type"]) != "make":
			continue
		var ks := {}
		for k in xd["kinds"]:
			ks[int(k)] = true
		m = mini(m, int(gs._supply9(ks)["supply"]) - int(xd["target"]) + gs.sub_progress9(xd))
	return m


## Der Tipp-Bot (GameState.best_action) ohne Netz, bis cap Schritte. [gewonnen, Schritte, Aktionen]
func bot_plain(gs0: GameState, cap: int) -> Array:
	var gs := gs0.clone()
	var acts := 0
	while not gs.day_won and gs.steps9() <= cap and acts < cap * 3 + 20:
		acts += 1
		var a: Dictionary = gs.best_action()
		if a.is_empty():
			break
		gs.play(a)
	return [gs.day_won, gs.steps9(), acts]


## Der Tipp-Bot im echten Game mit dem Sicherheitsnetz, wie das Spiel es anbietet (Game._rescue_check → rescue_offer →
## take_gift). [gewonnen, Schritte, Geschenke, Angebote ohne Geschenk, Gründe]
func bot_net(g: Node, cap: int) -> Array:
	var gifts := 0
	var nogift := 0
	var whys := {}
	var acts := 0
	var gs: GameState = g.state
	var s0 := gs.steps9()
	while not gs.day_won and gs.steps9() - s0 <= cap and acts < cap * 3 + 30:
		acts += 1
		if not (g.rescue_offer as Dictionary).is_empty():
			whys[str(g.rescue_offer.get("why", ""))] = true
			if bool(g.rescue_offer.get("gift", false)):
				var r: Dictionary = g.take_gift()
				if not r.is_empty():
					g.finish_round(r)
					gifts += 1
					continue
			else:
				nogift += 1
				g.rescue_offer = {}
		var a: Dictionary = gs.best_action()
		if a.is_empty():
			break
		act(g, gs, a)
		if OS.get_environment("AUDIT_DEBUG") == "1":
			print("DBG act=%s steps=%d twists=%d s0=%d won=%s same_state=%s" % [str(a), gs.steps9(), gs.twists, s0, str(gs.day_won), str(gs == g.state)])
	return [gs.day_won, gs.steps9() - s0, gifts, nogift, str(whys.keys())]


## „Vorausspielen“: T sorglose Drehungen, die den Sieg vermeiden (wer gewinnen würde, dreht anders), Regen und Meteor
## irgendwohin, Gefahren laufen, Angebote des Netzes bleiben liegen. style "rand": zufällig; "grow": die Drehung, bei
## der am meisten wächst (macht von allem mehr, als das Ziel braucht). Merkt sich das wenigste Wasser, ob das Ziel
## unterwegs unerreichbar wurde (reach9) und wie oft das Netz sich meldete.
func careless(g: Node, gs: GameState, rng: RandomNumberGenerator, t_max: int, style: String, stat: Dictionary) -> void:
	var t0 := gs.twists
	var guard := 0
	stat["min_water"] = mini(int(stat.get("min_water", 99)), gs.count(W))
	while gs.twists - t0 < t_max and not gs.day_won and guard < t_max * 5:
		guard += 1
		var action := {}
		if gs.rain > 0 and rng.randf() < 0.5:
			var cand: Array = []
			for f in gs.fields:
				if gs.rain_ok9(f):
					cand.append(f.id)
			if not cand.is_empty():
				action = {"type": "rain", "field": int(cand[rng.randi_range(0, cand.size() - 1)])}
		if action.is_empty() and gs.meteors > 0 and rng.randf() < 0.5:
			var cand2: Array = []
			for f in gs.fields:
				if gs.meteor_ok9(f):
					cand2.append(f.id)
			if not cand2.is_empty():
				action = {"type": "strike", "field": int(cand2[rng.randi_range(0, cand2.size() - 1)])}
		if action.is_empty():
			if style == "grow" and rng.randf() < 0.6:
				var best_g := -1
				for m in GameState.MOVES:
					var s: GameState = gs.clone()
					s.play(twist(m))
					if s.day_won:
						continue
					var gr := s.last_grew * 10 + rng.randi_range(0, 9)
					if gr > best_g:
						best_g = gr
						action = twist(m)
			if action.is_empty():
				action = twist(GameState.MOVES[rng.randi_range(0, 26)])
		var sim: GameState = gs.clone()
		sim.play(action)
		if sim.day_won:
			stat["skipped_wins"] = int(stat.get("skipped_wins", 0)) + 1
			continue
		act(g, gs, action)
		stat["min_water"] = mini(int(stat.get("min_water", 99)), gs.count(W))
		if not bool(gs.reach9()["ok"]):
			stat["dead_rounds"] = int(stat.get("dead_rounds", 0)) + 1
			if not stat.has("dead_first"):
				stat["dead_first"] = "%s@%d" % [str(gs.reach9()), gs.twists]
		if g != null and not (g.rescue_offer as Dictionary).is_empty():
			stat["offers"] = int(stat.get("offers", 0)) + 1
			g.rescue_offer = {}


## Eine Welt von Level n (Pool-Brett idx) am Sieg: how "sol" (die geprüfte Lösung), "hint" (Tipp-Bot), "over"/"grow"
## (T sorglose Drehungen, dann Tipp-Bot, zuletzt das Netz). {"world": Text nach Plätzen, "won", "stat"}.
func make_world(n: int, idx: int, how: String, t_max: int, seed_value: int) -> Dictionary:
	var b := Campaign.board(n, idx)
	var gs := Campaign.new_state(n, b)
	var stat := {}
	if how == "sol":
		for st in (b["solution"] as Array):
			if gs.day_won:
				break
			var ab: Array = Days.solution_step(st)
			gs.play(ab[0], ab[1])
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value * 977 + n * 13 + idx
		if how == "over" or how == "grow":
			careless(null, gs, rng, t_max, "grow" if how == "grow" else "rand", stat)
		finish_pure(gs, Campaign.par_of(n) * 6, stat)
	return {"world": gs.slot_board9(), "won": gs.day_won, "stat": stat, "steps": gs.steps9()}


## Auf dem reinen Stand zu Ende spielen: Tipp-Bot, und das Netz wie Game._rescue_check (Geschenk, wenn es eins gibt).
func finish_pure(gs: GameState, cap: int, stat: Dictionary) -> void:
	var told_at := -99
	var dead_told := false
	var acts := 0
	var s0 := gs.steps9()
	while not gs.day_won and gs.steps9() - s0 <= cap and acts < cap * 3 + 30:
		acts += 1
		var why := gs.stuck9()
		if why != "dead":
			dead_told = false
		if why != "" and ((why == "dead" and not dead_told) or gs.steps9() - told_at >= GameState.STALL9):
			dead_told = why == "dead"
			told_at = gs.steps9()
			if not gs.gift_plan9().is_empty():
				gs.play({"type": "gift"})
				stat["gifts"] = int(stat.get("gifts", 0)) + 1
				continue
			stat["nogift"] = int(stat.get("nogift", 0)) + 1
		var a: Dictionary = gs.best_action()
		if a.is_empty():
			break
		gs.play(a)


## Den Spielstand so stellen, als wären 1 … n−1 geschafft und Level n heute neu offen; die Welt von gestern = world.
func set_progress(g: Node, n: int, world: String) -> void:
	g.camp = GameScript.fresh_camp()
	var k: int = g.today_key()
	for i in n - 1:
		(g.camp["stars"] as Array)[i] = 1
		(g.camp["won_key"] as Array)[i] = k - 1
	g.camp["pos"] = n - 1
	g.camp["last_new_key"] = k - 1
	g.camp["world"] = world
	g.camp["world_level"] = n - 1 if world.length() == 54 else 0
	g._clear_run()


## Einen Start prüfen (g läuft gerade in Level n): (a) Grundstoffe, (b) reach9, (c) Bot ohne und mit Netz (≤ 4 × Par),
## (d) keine fertige Reihe, kein Sieg mit einer Drehung, kein Fortschritt am Start. Gibt die Zeile zurück.
func check_start(g: Node, n: int, src: String, solve: bool = true) -> Dictionary:
	var gs: GameState = g.state
	var kinds := kinds_of(gs)
	var how := str(g.level_board.get("how", ""))
	var c := cnt_of(kinds)
	var water := int(c.get(W, 0))
	var nw := needs_water(gs)
	var reach: Dictionary = gs.reach9()
	var rows := gs.lines().size()
	var quick := Campaign.quick_win(n, kinds, int(g.level_board.get("seed", 1)))
	var prog := gs.progress9()
	var viol := Campaign.violation(n, kinds, false)
	var comp: Dictionary = Campaign.config(n).get("comp", {})
	var exact := GameScript._comp_fits(n, kinds)
	var slack := min_slack(gs)
	var par := Campaign.par_of(n)
	var plain: Array = [true, 0, 0]
	var net: Array = [true, 0, 0, 0, ""]
	var line := str((g.overnight as Dictionary).get("line", ""))
	var fixes: int = (g.level_board.get("fixes", []) as Array).size()
	var board := Campaign.encode(kinds)
	var changed: int = (g.level_board.get("changed", []) as Array).size()
	if solve:
		var gs0: GameState = gs.clone()
		net = bot_net(g, par * 4)
		if int(net[2]) == 0 and int(net[3]) == 0:
			plain = [net[0], net[1], -1]          # kein Angebot angenommen: derselbe Lauf wie ohne Netz
		else:
			plain = bot_plain(gs0, par * 4)
	var bad: Array = []
	if nw and water == 0:
		bad.append("no_water")
	if not bool(reach["ok"]):
		bad.append("reach")
	if rows > 0:
		bad.append("rows")
	if quick:
		bad.append("quick")
	if prog > 0:
		bad.append("progress")
	if solve and not bool(plain[0]):
		bad.append("bot_plain")
	if solve and not bool(net[0]):
		bad.append("bot_net")
	if how == "carry" and viol > 0:
		bad.append("viol%d" % viol)
	print("ROW n=%d src=%s how=%s line='%s' changed=%d fixes=%d water=%d needw=%s slack=%d sup=[%s] reach=%s rows=%d quick=%s prog=%d viol=%d exact=%s plain=%s net=%s bad=%s" % [
		n, src, how, line, changed, fixes, water, str(nw), slack, supply_text(Campaign.new_state(n, {"kinds": kinds, "seed": 1})),
		str(bool(reach["ok"])), rows, str(quick), prog, viol, str(exact), str(plain), str(net), str(bad)])
	if not bad.is_empty():
		fails += 1
		print("FAIL n=%d src=%s how=%s bad=%s board=%s seed=%d reach=%s" % [n, src, how, str(bad), board,
			int(g.level_board.get("seed", 1)), str(reach)])
	return {"n": n, "src": src, "how": how, "bad": bad, "water": water, "plain": plain, "net": net, "line": line,
		"fixes": fixes, "slack": slack, "board": board, "exact": exact, "changed": changed}


# --- mode=inject: je Level viele Welten von gestern durch Game.start_level ------------------------------

func run_inject(from: int, to: int) -> void:
	var path := save_file()
	for n in range(maxi(2, from), mini(to, Campaign.COUNT) + 1):
		var t0 := Time.get_ticks_msec()
		var worlds: Array = []          # [Name, Welt-Text]
		var first := Campaign.first_of_era(n)
		# Welten von gestern (Level n−1)
		for i in ([1] if first or lite else [1, 2, 3]):
			worlds.append(["sol%d" % i, str(make_world(n - 1, i, "sol", 0, 1)["world"])])
		for i2 in ([4] if first or lite else [4, 5]):
			var hw := make_world(n - 1, i2, "hint", 0, 1)
			if not bool(hw["won"]):
				print("OVER n=%d idx=%d how=hint NOT_WON stat=%s" % [n - 1, i2, str(hw["stat"])])
			worlds.append(["hint%d" % i2, str(hw["world"])])
		var plans: Array = [["over", 40, 6], ["over", 150, 7], ["grow", 80, 8], ["grow", 150, 9]]
		if first:
			plans = [["grow", 100, 8]]
		elif lite:
			plans = [["over", 150, 7], ["grow", 150, 9]]
		for p in plans:
			var ow := make_world(n - 1, int(p[2]), str(p[0]), int(p[1]), n)
			var st: Dictionary = ow["stat"]
			print("OVER n=%d idx=%d how=%s T=%d won=%s steps=%d min_water=%d dead_rounds=%d dead_first=%s gifts=%d nogift=%d skipped=%d" % [
				n - 1, int(p[2]), str(p[0]), int(p[1]), str(ow["won"]), int(ow["steps"]), int(st.get("min_water", -1)),
				int(st.get("dead_rounds", 0)), str(st.get("dead_first", "")), int(st.get("gifts", 0)), int(st.get("nogift", 0)),
				int(st.get("skipped_wins", 0))])
			worlds.append(["%s%d" % [str(p[0]), int(p[1])], str(ow["world"])])
		if not first:
			# Extreme: kein Wasser, alles eine Art, nur die neuesten Arten, Welten aus anderen Leveln
			var base: Array = Campaign.decode(str(worlds[0][1]))
			var cb := cnt_of(base)
			var top_k := -1
			for k in cb:
				if int(k) != W and (top_k < 0 or int(cb[k]) > int(cb[top_k])):
					top_k = int(k)
			var nowater := base.duplicate()
			for i3 in nowater.size():
				if int(nowater[i3]) == W:
					nowater[i3] = top_k
			worlds.append(["nowater", Campaign.encode(nowater)])
			var prev_cfg := Campaign.config(n - 1)
			var gk: Array = []
			for gsub in prev_cfg.get("goal", []):
				var ga: Array = gsub
				if str(ga[0]) == "hold":
					for y in ga[1]:
						var kk: Variant = (y as Array)[1]
						gk.append(int((kk as Array)[0]) if kk is Array else int(kk))
				else:
					var kk2: Variant = ga[1]
					gk.append(int((kk2 as Array)[0]) if kk2 is Array else int(kk2))
			var one_kinds: Array = [W] if lite else [W, FieldData.STONE, FieldData.EMPTY, FieldData.LAVA]
			for k3 in gk:
				if not one_kinds.has(int(k3)):
					one_kinds.append(int(k3))
			for k4 in one_kinds:
				var all1: Array = []
				for i4 in 54:
					all1.append(int(k4))
				worlds.append(["all_%s" % FieldData.kind_name(int(k4)), Campaign.encode(all1)])
			var latest: Array = []
			for i5 in 54:
				latest.append(int(gk[i5 % gk.size()]))
			worlds.append(["latest", Campaign.encode(latest)])
			if n - 3 >= 1 and not lite:
				worlds.append(["from_n-3", str(make_world(n - 3, 2, "sol", 0, 1)["world"])])
			if n + 2 <= Campaign.COUNT:
				worlds.append(["from_n+2", str(make_world(n + 2, 2, "sol", 0, 1)["world"])])
		var sum := {"starts": 0, "carry": 0, "fallback": 0, "pool": 0, "stored": 0, "topup": 0, "bad": 0, "no_water": 0,
			"plain_fail": 0, "net_fail": 0, "gifts": 0, "min_water": 99, "min_slack": 99, "max_plain": 0, "changed_sum": 0, "changed_max": 0}
		for wv in worlds:
			var g := mk_game(path, t_now, true)
			set_progress(g, n, str(wv[1]))
			var ok: bool = g.start_level(n)
			if not ok:
				print("FAIL n=%d src=%s start_level false" % [n, str(wv[0])])
				fails += 1
				g.free()
				continue
			var r := check_start(g, n, str(wv[0]))
			sum["starts"] = int(sum["starts"]) + 1
			sum[str(r["how"])] = int(sum.get(str(r["how"]), 0)) + 1
			if int(r["fixes"]) > 0:
				sum["topup"] = int(sum["topup"]) + 1
			if not (r["bad"] as Array).is_empty():
				sum["bad"] = int(sum["bad"]) + 1
			if (r["bad"] as Array).has("no_water"):
				sum["no_water"] = int(sum["no_water"]) + 1
			if not bool((r["plain"] as Array)[0]):
				sum["plain_fail"] = int(sum["plain_fail"]) + 1
			if not bool((r["net"] as Array)[0]):
				sum["net_fail"] = int(sum["net_fail"]) + 1
			sum["gifts"] = int(sum["gifts"]) + int((r["net"] as Array)[2])
			sum["min_water"] = mini(int(sum["min_water"]), int(r["water"]))
			sum["min_slack"] = mini(int(sum["min_slack"]), int(r["slack"]))
			sum["max_plain"] = maxi(int(sum["max_plain"]), int((r["plain"] as Array)[1]))
			if ["sol1", "sol2", "sol3", "hint4", "hint5", "over40", "over150", "grow80", "grow150", "grow100"].has(str(wv[0])):
				sum["changed_sum"] = int(sum["changed_sum"]) + int(r["changed"])
				sum["changed_max"] = maxi(int(sum["changed_max"]), int(r["changed"]))
			g.free()
		print("SUM n=%d first=%s par=%d %s ms=%d" % [n, str(first), Campaign.par_of(n), str(sum), Time.get_ticks_msec() - t0])


# --- mode=chain: die ganze Kampagne Tag für Tag im echten Game ------------------------------------------

func run_chain(style: String, seed_value: int, to: int) -> void:
	var path := save_file()
	var g := mk_game(path, t_now, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + style.hash() % 1000
	var day := 0
	for n in range(1, mini(to, Campaign.COUNT) + 1):
		g.clock_override = t_now + day * Daily.DAY
		day += 1
		var cur: int = g.current_level()
		if cur != n or not g.level_unlocked(n):
			print("FAIL chain n=%d current=%d unlocked=%s" % [n, cur, str(g.level_unlocked(n))])
			fails += 1
			break
		if not g.start_level(n):
			print("FAIL chain n=%d start_level false" % n)
			fails += 1
			break
		var gs: GameState = g.state
		var kinds0 := kinds_of(gs)
		var r := check_start(g, n, "chain_%s" % style, false)
		# App zu und wieder auf, bevor etwas getan ist: derselbe Start (gespeichertes Start-Brett + ensure)?
		g.free()
		g = mk_game(path, t_now + (day - 1) * Daily.DAY, false)
		if not g.resume_run():
			g.start_level(g.current_level())
		var kinds1 := kinds_of(g.state)
		if g.level_no != n or kinds1 != kinds0:
			var diff := 0
			for i in mini(kinds0.size(), kinds1.size()):
				if int(kinds0[i]) != int(kinds1[i]):
					diff += 1
			print("FAIL chain n=%d restart_changes_board level=%d how=%s diff=%d line='%s' first=%s second=%s" % [n, g.level_no,
				str(g.level_board.get("how", "")), diff, str((g.overnight as Dictionary).get("line", "")),
				Campaign.encode(kinds0), Campaign.encode(kinds1)])
			fails += 1
		gs = g.state
		var stat := {}
		if style == "over" or style == "grow":
			careless(g, gs, rng, 40 + rng.randi_range(0, 110), "grow" if style == "grow" else "rand", stat)
			if not gs.day_won and rng.randf() < 0.5:
				# mitten im Level die App zu: der Lauf geht genau so weiter
				var before := gs.slot_board9()
				var p_before := gs.progress9()
				g._save_running()
				g.free()
				g = mk_game(path, t_now + (day - 1) * Daily.DAY, false)
				var resumed: bool = g.resume_run()
				if not resumed or g.level_no != n or (g.state as GameState).slot_board9() != before or (g.state as GameState).progress9() != p_before:
					print("FAIL chain n=%d resume resumed=%s level=%d same_board=%s" % [n, str(resumed), g.level_no,
						str(resumed and (g.state as GameState).slot_board9() == before)])
					fails += 1
					if not resumed:
						g.start_level(n)
				gs = g.state
		print("PRE n=%d won=%s twists=%d steps=%d progress=%d/%d level_no=%d stat=%s" % [n, str(gs.day_won), gs.twists, gs.steps9(), gs.progress9(), gs.target9(), g.level_no, str(stat)])
		var net := bot_net(g, Campaign.par_of(n) * 8)
		print("PLAY n=%d style=%s won=%s steps=%d gifts=%d nogift=%d whys=%s min_water=%d dead_rounds=%d dead_first=%s offers=%d water_end=%d" % [
			n, style, str(net[0]), int(net[1]), int(net[2]), int(net[3]), str(net[4]), int(stat.get("min_water", -1)),
			int(stat.get("dead_rounds", 0)), str(stat.get("dead_first", "")), int(stat.get("offers", 0)), gs.count(W)])
		if not bool(net[0]):
			print("FAIL chain n=%d not won style=%s start=%s now=%s" % [n, style, str(r["board"]), gs.slot_board9()])
			fails += 1
			break
		if g.level_stars(n) <= 0 or int(g.camp["pos"]) != n or int(g.camp["world_level"]) != n:
			print("FAIL chain n=%d win not registered stars=%d pos=%d world_level=%d" % [n, g.level_stars(n), int(g.camp["pos"]), int(g.camp["world_level"])])
			fails += 1
		# Wiederholung des geschafften Levels: Pool-Brett, die Welt bleibt die des Levels
		if n % 7 == 3:
			g.start_level(n)
			var rr := check_start(g, n, "replay", false)
			if str(rr["how"]) != "pool":
				print("FAIL chain n=%d replay how=%s" % [n, str(rr["how"])])
				fails += 1
	g.free()


# --- mode=paths: Neustart, Nochmal, Fortsetzen, Wiederholung, Neue Welt, Welt des Tages ---------------------

func run_paths() -> void:
	var path := save_file()
	for n in [3, 6, 7, 8, 9, 10, 11, 14, 20, 26, 33, 42, 47, 53, 56, 58, 60]:
		var w := str(make_world(n - 1, 2, "grow", 60, n)["world"])
		var g := mk_game(path, t_now, true)
		set_progress(g, n, w)
		g._save_profile()
		g.start_level(n)
		var k0 := kinds_of(g.state)
		var how0 := str(g.level_board.get("how", ""))
		var line0 := str((g.overnight as Dictionary).get("line", ""))
		# 1. Neustart der App ohne Zug: gespeichertes Start-Brett
		g.free()
		g = mk_game(path, t_now, false)
		var resumed0: bool = g.resume_run()
		if not resumed0:
			g.start_level(g.current_level())
		var k1 := kinds_of(g.state)
		var how1 := str(g.level_board.get("how", ""))
		var same1 := k1 == k0
		var line1 := str((g.overnight as Dictionary).get("line", ""))
		# 2. Nochmal
		act(g, g.state, twist(GameState.MOVES[0]))
		g.retry_level()
		var same2 := kinds_of(g.state) == k1
		# 3. zwei Züge, App zu, fortsetzen
		act(g, g.state, twist(GameState.MOVES[3]))
		act(g, g.state, twist(GameState.MOVES[7]))
		var mid := (g.state as GameState).slot_board9()
		var won_mid: bool = (g.state as GameState).day_won
		g.free()
		g = mk_game(path, t_now, false)
		var resumed: bool = g.resume_run()
		var same3 := resumed and (g.state as GameState).slot_board9() == mid
		# 4. ein anderes Level öffnen (Wiederholung von Level 1) und zurück: was ist aus dem Lauf geworden?
		g.start_level(1)
		var run_after: Dictionary = g.saved_run()
		g.start_level(n)
		var k4 := kinds_of(g.state)
		var back_how := str(g.level_board.get("how", ""))
		var same4 := k4 == k1
		# 5. Neue Welt (Sicherheitsnetz)
		g.new_world()
		var r5 := check_start(g, n, "new_world", false)
		# 6. nach dem Sieg: Wiederholung
		bot_net(g, Campaign.par_of(n) * 8)
		var won: bool = (g.state as GameState).day_won
		g.start_level(n)
		var r6 := check_start(g, n, "replay", false)
		print("PATH n=%d how0=%s line0='%s' restart(resumed=%s how=%s same=%s line='%s') retry_same=%s resume(ok=%s same=%s won_mid=%s) other_level(run_left=%s back_how=%s same=%s) new_world(how=%s bad=%s) won=%s replay(how=%s bad=%s)" % [
			n, how0, line0, str(resumed0), how1, str(same1), line1, str(same2), str(resumed), str(same3), str(won_mid),
			str(not run_after.is_empty()), back_how, str(same4), str(r5["how"]), str(r5["bad"]), str(won), str(r6["how"]), str(r6["bad"])])
		if not same1 or not same2 or (not same3 and not won_mid) or not same4:
			fails += 1
			print("FAIL paths n=%d same1=%s same2=%s same3=%s same4=%s first=%s restart=%s back=%s" % [n, str(same1), str(same2),
				str(same3), str(same4), Campaign.encode(k0), Campaign.encode(k1), Campaign.encode(k4)])
		g.free()
	# Welt des Tages: alles geschafft, 12 Spieltage
	var gw := mk_game(path, t_now, true)
	gw.camp = GameScript.fresh_camp()
	var k: int = gw.today_key()
	for i in Campaign.COUNT:
		(gw.camp["stars"] as Array)[i] = 1
		(gw.camp["won_key"] as Array)[i] = k - 2
	gw.camp["pos"] = Campaign.COUNT
	gw.camp["last_new_key"] = k - 2
	for d in 12:
		gw.clock_override = t_now + d * Daily.DAY
		if not gw.start_level_wdt():
			print("FAIL wdt day=%d not available" % d)
			fails += 1
			continue
		var gs: GameState = gw.state
		var reach: Dictionary = gs.reach9()
		var rows := gs.lines().size()
		var plain := bot_plain(gs, gs.par9 * 4)
		var net := bot_net(gw, gs.par9 * 4)
		print("WDT day=%d template=%d board=%d reach=%s rows=%d plain=%s net=%s" % [d, gw.level_no, int(gw.level_board.get("index", -1)),
			str(bool(reach["ok"])), rows, str(plain), str(net)])
		if not bool(reach["ok"]) or rows > 0 or not bool(net[0]):
			fails += 1
	gw.free()


# --- mode=b12: Spielstände aus Build 12 (30 Level, [kampagne] version 1) -------------------------------------

var _old: Dictionary = {}


func old_data() -> Dictionary:
	if _old.is_empty():
		var d: Variant = Days._read_json("res://data/kampagne_schoepfung.json")
		_old = d
	return _old


func old_cfg(k: int) -> Dictionary:
	var c: Dictionary = ((old_data()["config"] as Dictionary)[str(k)] as Dictionary).duplicate(true)
	c["level"] = k
	return c


func old_board(k: int, idx: int) -> Dictionary:
	var pool: Array = (old_data()["levels"] as Dictionary)[str(k)]
	return pool[idx % pool.size()]


## Die Welt eines alten Levels am Sieg (alte Regeln, alter Pool). how: "sol" | "grow" (vorausgespielt).
func old_world(k: int, idx: int, how: String) -> Dictionary:
	var e := old_board(k, idx)
	var gs := GameState.new()
	gs.setup_level(old_cfg(k), Campaign.decode(str(e["board"])), int(e["seed"]))
	var stat := {}
	if how == "sol":
		for st in (e["solution"] as Array):
			if gs.day_won:
				break
			var ab: Array = Days.solution_step(st)
			gs.play(ab[0], ab[1])
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5000 + k * 17 + idx
		careless(null, gs, rng, 120, "grow", stat)
		finish_pure(gs, 60, stat)
	return {"world": gs.slot_board9(), "won": gs.day_won, "stat": stat, "state": gs}


## Ein Spielstand, wie Build 12 ihn schrieb (Game._save_profile/_save_camp von ee97492): won = so viele alte Level
## geschafft; world/world_level; start/start_level; last_new = Spieltag des letzten neuen Levels; run = Lauf-Datei.
func write_b12(path: String, won: int, world: String, world_level: int, start: String, start_level: int, last_new: int,
		run_level: int, run_state: GameState) -> void:
	for p in [path, path.get_basename() + "_lauf.cfg"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	var cfg := ConfigFile.new()
	var st: Array = []
	var sp: Array = []
	var wk: Array = []
	var nb: Array = []
	var lb: Array = []
	var ex: Array = []
	for j in 30:
		st.append(2 if j < won else 0)
		sp.append(7 if j < won else 0)
		wk.append(last_new - (won - 1 - j) if j < won else -1)
		nb.append(2 if j < won else 0)
		lb.append(60 if j < won else 0)
		ex.append(0)
	cfg.set_value("rekorde", "einfach", 0)
	cfg.set_value("tutorial", "fertig", true)
	cfg.set_value("tutorial", "hinweise", ["reveal_v1"])
	cfg.set_value("konto", "punkte", 300)
	cfg.set_value("konto", "version", 2)
	cfg.set_value("konto", "umgestellt", 0)
	cfg.set_value("punkte", "level_best", lb)
	cfg.set_value("punkte", "extras", ex)
	cfg.set_value("kampagne", "version", 1)
	cfg.set_value("kampagne", "level", mini(30, won + 1))
	cfg.set_value("kampagne", "sterne", st)
	cfg.set_value("kampagne", "schritte", sp)
	cfg.set_value("kampagne", "gewonnen_am", wk)
	cfg.set_value("kampagne", "letzter_neuer", last_new)
	cfg.set_value("kampagne", "welt", world)
	cfg.set_value("kampagne", "welt_level", world_level)
	cfg.set_value("kampagne", "start", start)
	cfg.set_value("kampagne", "start_level", start_level)
	cfg.set_value("kampagne", "start_seed", 1001)
	cfg.set_value("kampagne", "schnell_bis", 0)
	cfg.set_value("kampagne", "schnell_tag", [-1, 0])
	cfg.set_value("kampagne", "veteran", false)
	cfg.set_value("kampagne", "brett", nb)
	cfg.set_value("kampagne", "danke", 0)
	cfg.set_value("laden", "besitz", [])
	cfg.set_value("laden", "vorrat", {})
	cfg.set_value("laden", "gesehen", [])
	cfg.set_value("spiel", "modus", "mittel")
	cfg.set_value("schoepfung", "sterne", [0, 0, 0, 0, 0, 0, 0])
	cfg.set_value("schoepfung", "version", 3)
	cfg.save(path)
	if run_level > 0 and run_state != null:
		var d := {"v": 1, "level": run_level, "wdt": -1, "cfg": GameScript._cfg_hash(run_state.day),
			"state": run_state.save9(), "undo": {}, "board": {"kinds": kinds_of(run_state), "seed": 1001, "index": -1, "how": "carry"},
			"hint_free": 1, "undo_free": 1, "rescue_at": -99, "dead_told": false, "offer": {}, "attempt_key": last_new,
			"attempt_start": 0, "steps": run_state.steps9(), "progress": run_state.progress9(), "target": run_state.target9()}
		var rc := ConfigFile.new()
		rc.set_value("lauf", "daten", d)
		rc.save(path.get_basename() + "_lauf.cfg")


## Ein Start-Brett, wie Build 12 es für das alte Level k gespeichert hätte: genau die alte Mischung, Startbedingungen
## nach dem neuen Level m (gleiche Regeln) repariert; "" wenn das nicht geht.
func old_start(k: int, m: int, seed_value: int) -> String:
	var comp: Dictionary = old_cfg(k).get("comp", {})
	var kinds: Array = []
	for key in comp:
		for i in int(comp[key]):
			kinds.append(int(str(key)))
	while kinds.size() < 54:
		kinds.append(W)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i2 in range(53, 0, -1):
		var j := rng.randi_range(0, i2)
		var tmp: int = kinds[i2]
		kinds[i2] = kinds[j]
		kinds[j] = tmp
	if m < 1:
		return Campaign.encode(kinds)
	var rep := Campaign.repair(m, kinds, rng, 3000, true)
	return Campaign.encode(rep[0])


func run_b12(lvs: Array, vars: Array) -> void:
	var path := save_file()
	var today := Daily.day_key(t_now)
	for lv0 in lvs:
		var lv := int(lv0)
		# A: alt 1 … lv−1 geschafft, lv ist das laufende Level; B: alt 1 … lv geschafft
		for variant0 in vars:
			var variant := str(variant0)
			var won: int = lv - 1 if variant.begins_with("A") else lv
			var how := "grow" if variant == "B_ahead" else "sol"
			var ow: Dictionary = old_world(maxi(1, won), 2, how)
			var world := str(ow["world"])
			var wl: int = won
			var start := ""
			var start_level := 0
			var run_level := 0
			var run_state: GameState = null
			if variant == "A_start_run":
				start = old_start(lv, Campaign.old_to_new(lv), 100 + lv)
				start_level = lv
				run_level = lv
				run_state = GameState.new()
				run_state.setup_level(old_cfg(lv), Campaign.decode(start), 1001)
				var rr := RandomNumberGenerator.new()
				rr.seed = lv
				careless(null, run_state, rr, 12, "grow", {})
			var last_new := today if variant == "B_today" else today - 1
			write_b12(path, won, world, wl, start, start_level, last_new, run_level, run_state)
			var had_run := FileAccess.file_exists(path.get_basename() + "_lauf.cfg")
			var g := mk_game(path, t_now, false)
			var c: Dictionary = g.camp
			var kept_world := str(c["world"]).length() == 54
			var kept_start := str(c["start"]).length() == 54
			var run_left: bool = not (g.saved_run() as Dictionary).is_empty()
			var cu: Array = []
			for n in range(1, Campaign.COUNT + 1):
				if Daily.catchup(c, n):
					cu.append(n)
			var ti: Dictionary = g.camp_today_info()
			print("B12 old=%d variant=%s -> pos=%d next_new=%d current=%d today_state=%s today_day=%s world_kept=%s(level %d) start_kept=%s(level %d) run_file_before=%s run_after=%s catchup=%s" % [
				lv, variant, int(c["pos"]), g.next_new_level(), g.current_level(), str(ti["state"]), str(ti.get("day", "")),
				str(kept_world), int(c["world_level"]), str(kept_start), int(c["start_level"]), str(had_run), str(run_left), str(cu)])
			# wie Game._ready: fortsetzen oder das laufende Level starten
			if not g.resume_run():
				g.start_level(g.current_level())
			check_start(g, g.level_no, "b12_%d_%s_ready" % [lv, variant], g.level_stars(g.level_no) == 0)
			# was die Heute-Karte anbietet
			ti = g.camp_today_info()
			var offer := int(ti.get("day", 0))
			if ["new", "catchup"].has(str(ti["state"])) and offer >= 1 and g.level_unlocked(offer):
				if g.start_level(offer):
					check_start(g, offer, "b12_%d_%s_today_%s" % [lv, variant, str(ti["state"])])
			# alle Level zum Nachholen
			for n2 in cu:
				if g.level_stars(int(n2)) > 0:
					continue
				if g.start_level(int(n2)):
					check_start(g, int(n2), "b12_%d_%s_catchup" % [lv, variant])
				else:
					print("FAIL b12 old=%d variant=%s catchup %d does not start" % [lv, variant, int(n2)])
					fails += 1
			# die nächsten Spieltage: das neue Level (hier trägt die alte Welt)
			for d in range(1, 4):
				g.clock_override = t_now + d * Daily.DAY
				var nn: int = g.next_new_level()
				if nn > Campaign.COUNT or not g.level_unlocked(nn):
					print("B12 old=%d variant=%s day+%d: no new level (next_new=%d unlocked=%s today=%s)" % [lv, variant, d, nn,
						str(nn <= Campaign.COUNT and g.level_unlocked(nn)), str(g.camp_today_info()["state"])])
					continue
				var wl_before := int(g.camp["world_level"])
				if g.start_level(nn):
					var r := check_start(g, nn, "b12_%d_%s_day+%d_wl%d" % [lv, variant, d, wl_before])
					if not bool((r["net"] as Array)[0]):
						break
			g.free()


# --- mode=pool: die Pool-Bretter, auf denen ein Level frisch beginnt (neues Zeitalter, Nachholen, Rückfall, Neue Welt) ---

## Brett 1 … boards jedes Levels (Level 1: Brett 0): gewinnt der Tipp-Bot ohne Netz in 4 × Par? Mit Netz?
func run_pool(from: int, to: int, boards: int) -> void:
	for n in range(from, to + 1):
		var par := Campaign.par_of(n)
		for i in range(1, boards + 1):
			var idx := 0 if n == 1 and i == 1 else i
			var b := Campaign.board(n, idx)
			var gs := Campaign.new_state(n, b)
			var reach: Dictionary = gs.reach9()
			var rows := gs.lines().size()
			var plain := bot_plain(gs, par * 4)
			var stat := {}
			var g2 := gs.clone()
			finish_pure(g2, par * 4, stat)
			var bad: Array = []
			if not bool(reach["ok"]):
				bad.append("reach")
			if rows > 0:
				bad.append("rows")
			if not bool(plain[0]):
				bad.append("bot_plain")
			if not g2.day_won:
				bad.append("bot_net")
			print("POOL n=%d idx=%d par=%d solved_in=%d plain=%s net=[%s, %d, gifts %d, nogift %d] bad=%s" % [n, idx, par,
				int(b.get("solved_in", 0)), str(plain), str(g2.day_won), g2.steps9(), int(stat.get("gifts", 0)), int(stat.get("nogift", 0)), str(bad)])
			if not bad.is_empty():
				fails += 1
				print("FAIL pool n=%d idx=%d bad=%s board=%s seed=%d" % [n, idx, str(bad), str(b["board"]), int(b["seed"])])
