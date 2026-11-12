extends SceneTree
## Verifier harness (v_rules). Temporary; deleted after the audit.
##   godot --headless --script res://tests/_verify_v_rules.gd -- mode=<inlevel|walk|extreme|migrate|easy|quick|farm> seed=N levels=a-b

const GameScript = preload("res://scripts/game.gd")
const WATER := FieldData.WATER
const STONE := FieldData.STONE
const E := FieldData.EMPTY
const LAVA := FieldData.LAVA

var args := {}
var finds: Array = []
var nfind := {}
var t_line_max := 0
var t_hint_max := 0
var line_calls := 0
var stats := {}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := str(a).split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var mode := str(args.get("mode", "inlevel"))
	var t0 := Time.get_ticks_msec()
	if mode == "inlevel":
		m_inlevel()
	elif mode == "walk":
		m_walk()
	elif mode == "extreme":
		m_extreme()
	elif mode == "migrate":
		m_migrate()
	elif mode == "easy":
		m_easy()
	elif mode == "quick":
		m_quick()
	elif mode == "farm":
		m_farm()
	elif mode == "probe":
		m_probe()
	print("STATS %s" % JSON.stringify(stats))
	print("TIMES line_max=%d ms hint_max=%d ms line_calls=%d" % [t_line_max, t_hint_max, line_calls])
	print("DONE mode=%s seed=%s finds=%d by=%s ms=%d" % [mode, str(args.get("seed", "1")), finds.size(), JSON.stringify(nfind), Time.get_ticks_msec() - t0])
	quit(0)


func find(tag: String, what: String) -> void:
	nfind[tag] = int(nfind.get(tag, 0)) + 1
	finds.append([tag, what])
	if int(nfind[tag]) <= 40:
		print("FIND %s | %s" % [tag, what])


func stat(key: String, add: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + add


func lv_range() -> Array:
	var s := str(args.get("levels", "1-60")).split("-")
	var a := int(s[0])
	var b := int(s[1]) if s.size() > 1 else a
	var out: Array = []
	for n in range(a, b + 1):
		out.append(n)
	return out


func tw(gs: GameState, m: Array) -> Dictionary:
	return gs.play({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])})


func cnt(gs: GameState, k: int) -> int:
	var n := 0
	for f in gs.fields:
		if f.kind == k:
			n += 1
	return n


func water_of(n: int) -> int:
	var comp: Dictionary = Campaign.config(n)["comp"]
	var t := 0
	for key in comp:
		t += int(comp[key])
	return 54 - t


func kinds_of(gs: GameState) -> Array:
	var out: Array = []
	for f in gs.fields:
		out.append(f.kind)
	return out


func hist(kinds: Array) -> String:
	var c := {}
	for k in kinds:
		c[int(k)] = int(c.get(int(k), 0)) + 1
	var ks: Array = c.keys()
	ks.sort()
	var s := ""
	for k2 in ks:
		s += "%s:%d " % [FieldData.kind_name(int(k2)), int(c[k2])]
	return s.strip_edges()


## Is the HUD line a concrete, possible action? "" = fine, else the reason.
func line_bad(gs: GameState, a: Dictionary) -> String:
	var txt := str(a.get("text", ""))
	if txt == "":
		return "kein Text"
	var wc := txt.split(" ", false).size()
	if wc > 6:
		return "mehr als 6 Wörter"
	var tool := str(a.get("tool", ""))
	var mv: Dictionary = a.get("move", {})
	if str(a.get("type", "")) == "won":
		return "" if gs.day_won else "won ohne Sieg"
	if tool == "" and mv.is_empty():
		return "keine Handlung"
	if tool == "rain":
		var fid := int(a.get("field", -1))
		if fid < 0 or fid >= gs.fields.size():
			return "Regen ohne Feld"
		if gs.rain <= 0:
			return "Regen, aber Vorrat 0"
		if not gs.rain_ok9(gs.fields[fid]):
			return "Regen wirkt dort nicht"
		return ""
	if tool == "meteor" or tool == "strike":
		var fid2 := int(a.get("field", -1))
		if fid2 < 0 or fid2 >= gs.fields.size():
			return "Meteor ohne Feld"
		if gs.meteors <= 0:
			return "Meteor, aber Vorrat 0"
		if not gs.meteor_ok9(gs.fields[fid2]):
			return "Meteor geht dort nicht"
		return ""
	if tool == "gift":
		return "" if not gs.gift_plan9().is_empty() else "Hilfe ohne Geschenk"
	if tool != "":
		return "unbekanntes Werkzeug " + tool
	if not mv.has("axis") or not mv.has("layer") or not mv.has("turns"):
		return "Scheibe unvollständig"
	if int(mv["axis"]) < 0 or int(mv["axis"]) > 2 or absi(int(mv["layer"])) > 1 or not [1, -1, 2, -2].has(int(mv["turns"])):
		return "Scheibe ungültig"
	if txt == "Dreh eine Scheibe" or txt == "Dreh weiter, Regen kommt" or txt == "Hol dir Hilfe":
		return "alte Zeile"
	return ""


func na(gs: GameState) -> Dictionary:
	var t := Time.get_ticks_usec()
	var a := gs.next_action()
	var ms := int((Time.get_ticks_usec() - t) / 1000)
	t_line_max = maxi(t_line_max, ms)
	line_calls += 1
	return a


func ba(gs: GameState) -> Dictionary:
	var t := Time.get_ticks_usec()
	var a := gs.best_action()
	var ms := int((Time.get_ticks_usec() - t) / 1000)
	t_hint_max = maxi(t_hint_max, ms)
	return a


# ---------------------------------------------------------------------------------------------------------------
# Players on a bare GameState, with the net exactly like Game._rescue_check (offer when freshly dead or after STALL9
# steps since the last help). mode: "line" | "hint" | "rand". take: accept gifts.
# Returns {"won","steps","gifts","nogift","flat","blind","most","bad":[...]}.
# ---------------------------------------------------------------------------------------------------------------
func run_player(gs: GameState, mode: String, take: bool, cap_steps: int, rng: RandomNumberGenerator, tag: String) -> Dictionary:
	var gifts := 0
	var nogift := 0
	var flat := 0
	var blind := 0
	var most := 0
	var seen := {}
	var bad: Array = []
	var told_at := -99
	var dead_told := false
	var acts := 0
	var max_acts := (cap_steps - gs.steps9()) * 4 + 40
	var same_line := 0
	var last_txt := ""
	while not gs.day_won and gs.steps9() < cap_steps and acts < max_acts:
		acts += 1
		var did_gift := false
		if mode == "line":
			var a := na(gs)
			var why := line_bad(gs, a)
			if why != "" and bad.size() < 4:
				bad.append("%s L%d s%d „%s“ %s" % [tag, gs.level_no, gs.steps9(), str(a.get("text", "")), why])
			var tool := str(a.get("tool", ""))
			var mv: Dictionary = a.get("move", {})
			if tool == "gift":
				if take and not gs.gift_plan9().is_empty():
					var s0 := gs._subs_sum9() + gs.progress9()
					gs.play({"type": "gift"})
					gifts += 1
					did_gift = true
					told_at = gs.steps9()
					dead_told = false
					if gs._subs_sum9() + gs.progress9() <= s0 and not gs.day_won:
						flat += 1
				else:
					blind += 1
					tw(gs, GameState.MOVES[rng.randi_range(0, 26)])
			elif (tool == "rain" or tool == "meteor" or tool == "strike") and why == "":
				var r := gs.play({"type": tool, "field": int(a["field"])})
				if bool(r.get("refused", false)):
					bad.append("%s L%d s%d „%s“ Werkzeug abgelehnt" % [tag, gs.level_no, gs.steps9(), str(a.get("text", ""))])
					tw(gs, GameState.MOVES[rng.randi_range(0, 26)])
			elif not mv.is_empty() and why == "":
				tw(gs, [int(mv["axis"]), int(mv["layer"]), int(mv["turns"])])
				var key := gs.slot_board9() + "|%d" % gs.rain
				seen[key] = int(seen.get(key, 0)) + 1
				most = maxi(most, int(seen[key]))
			else:
				blind += 1
				tw(gs, GameState.MOVES[rng.randi_range(0, 26)])
		elif mode == "hint":
			var h := ba(gs)
			if h.is_empty():
				blind += 1
				tw(gs, GameState.MOVES[rng.randi_range(0, 26)])
			else:
				var s1 := gs.steps9()
				var b1 := gs.slot_board9()
				var r1 := gs.play(h)
				if bool(r1.get("refused", false)) or (gs.steps9() == s1 and gs.slot_board9() == b1):
					blind += 1
					tw(gs, GameState.MOVES[rng.randi_range(0, 26)])
		else:
			var did := false
			if gs.rain > 0 and rng.randf() < 0.3:
				var cand: Array = []
				for f in gs.fields:
					if gs.rain_ok9(f):
						cand.append(f.id)
				if not cand.is_empty():
					gs.play({"type": "rain", "field": int(cand[rng.randi_range(0, cand.size() - 1)])})
					did = true
			if not did and gs.meteors > 0 and rng.randf() < 0.2:
				var land: Array = []
				for f in gs.fields:
					if gs.meteor_ok9(f):
						land.append(f.id)
				if not land.is_empty():
					gs.play({"type": "strike", "field": int(land[rng.randi_range(0, land.size() - 1)])})
					did = true
			if not did:
				tw(gs, GameState.MOVES[rng.randi_range(0, 26)])
		if gs.day_won:
			break
		if did_gift:
			continue
		var st := gs.stuck9()
		if st != "dead":
			dead_told = false
		if st == "":
			continue
		if (st == "dead" and not dead_told) or gs.steps9() - told_at >= GameState.STALL9:
			dead_told = st == "dead"
			told_at = gs.steps9()
			if gs.gift_plan9().is_empty():
				nogift += 1
			elif take:
				var s2 := gs._subs_sum9() + gs.progress9()
				gs.play({"type": "gift"})
				gifts += 1
				dead_told = false
				if gs._subs_sum9() + gs.progress9() <= s2 and not gs.day_won:
					flat += 1
	return {"won": gs.day_won, "steps": gs.steps9(), "gifts": gifts, "nogift": nogift, "flat": flat, "blind": blind,
		"most": most, "bad": bad, "stars": gs.stars() if gs.day_won else 0}


## How much goal material a state has (lower = more burned): fields of the goal chain, plus progress.
func material(gs: GameState) -> float:
	var v := 0.0
	for f in gs.fields:
		if gs.chain9.has(f.kind):
			v += 1.0
	return v + 3.0 * float(gs.progress9() + gs._subs_sum9())


## Burner: plays up to `steps` steps, never accepts help, never plays the winning action.
##   style 0 careless (random twists, every rain on water first, meteors anywhere)
##   style 1 anti (1-ply: the action after which the least goal material is left; half the twists random)
##   style 2 dead-seeker (1-ply: any action that makes reach9 not ok, else anti)
## Returns {"dead_nogift": n, "dead_steps": n, "bad": [...]} (dead states without a gift plan; HUD checks on samples).
func burn(gs: GameState, rng: RandomNumberGenerator, steps: int, style: int, tag: String) -> Dictionary:
	var s_end := gs.steps9() + steps
	var guard := 0
	var dead_nogift := 0
	var dead_steps := 0
	var bad: Array = []
	var first_dead := -1
	while not gs.day_won and gs.steps9() < s_end and guard < steps * 5:
		guard += 1
		var acted := false
		# tools first
		if gs.rain > 0:
			var cand: Array = []
			var wat: Array = []
			for f in gs.fields:
				if gs.rain_ok9(f):
					cand.append(f.id)
					if f.kind == WATER:
						wat.append(f.id)
			if not cand.is_empty():
				var pick := -1
				if style == 0:
					var pool: Array = wat if not wat.is_empty() else cand
					pick = int(pool[rng.randi_range(0, pool.size() - 1)])
					var c0 := gs.clone()
					c0.play({"type": "rain", "field": pick})
					if c0.day_won:
						pick = -1
				else:
					var best_v := INF
					var seen_kind := {}
					for fid in cand:
						var c := gs.clone()
						c.play({"type": "rain", "field": int(fid)})
						if c.day_won:
							continue
						var v := material(c) + rng.randf() * 0.3
						if style == 2 and not bool(c.reach9()["ok"]):
							v -= 1000.0
						if v < best_v:
							best_v = v
							pick = int(fid)
				if pick >= 0:
					gs.play({"type": "rain", "field": pick})
					acted = true
		if not acted and gs.meteors > 0 and (style > 0 or rng.randf() < 0.5):
			var land: Array = []
			for f in gs.fields:
				if gs.meteor_ok9(f):
					land.append(f.id)
			if not land.is_empty():
				var pick2 := -1
				if style == 0:
					pick2 = int(land[rng.randi_range(0, land.size() - 1)])
					var c1 := gs.clone()
					c1.play({"type": "strike", "field": pick2})
					if c1.day_won:
						pick2 = -1
				else:
					var best_v2 := INF
					for fid2 in land:
						var c2 := gs.clone()
						c2.play({"type": "strike", "field": int(fid2)})
						if c2.day_won:
							continue
						var v2 := material(c2) + rng.randf() * 0.3
						if style == 2 and not bool(c2.reach9()["ok"]):
							v2 -= 1000.0
						if v2 < best_v2:
							best_v2 = v2
							pick2 = int(fid2)
				if pick2 >= 0:
					gs.play({"type": "strike", "field": pick2})
					acted = true
		if not acted:
			var mv: Array = []
			if style == 0 or rng.randf() < 0.5:
				for tries in 12:
					var m: Array = GameState.MOVES[rng.randi_range(0, 26)]
					var c3 := gs.clone()
					tw(c3, m)
					if not c3.day_won:
						mv = m
						break
			else:
				var best_v3 := INF
				for m2 in GameState.MOVES:
					var c4 := gs.clone()
					tw(c4, m2)
					if c4.day_won:
						continue
					var v3 := material(c4) + rng.randf() * 0.3
					if style == 2 and not bool(c4.reach9()["ok"]):
						v3 -= 1000.0
					if v3 < best_v3:
						best_v3 = v3
						mv = m2
			if mv.is_empty():
				break
			tw(gs, mv)
		if gs.day_won:
			break
		var st := gs.stuck9()
		if st == "dead":
			dead_steps += 1
			if first_dead < 0:
				first_dead = gs.steps9()
			if gs.gift_plan9().is_empty():
				dead_nogift += 1
				if dead_nogift <= 2:
					find("dead_nogift", "%s L%d s%d: Sackgasse ohne Geschenk, reach=%s | %s" % [tag, gs.level_no, gs.steps9(), str(gs.reach9()), hist(kinds_of(gs))])
		if guard % 7 == 0:
			var a := na(gs)
			var why := line_bad(gs, a)
			if why != "" and bad.size() < 3:
				bad.append("%s L%d s%d „%s“ %s" % [tag, gs.level_no, gs.steps9(), str(a.get("text", "")), why])
			if st == "dead" and str(a.get("tool", "")) != "gift" and str(a.get("type", "")) != "help":
				stat("dead_line_not_help")
				if int(stats["dead_line_not_help"]) <= 5:
					find("dead_line", "%s L%d s%d: Sackgasse (reach=%s), Zeile sagt „%s“ statt Hilfe" % [tag, gs.level_no, gs.steps9(), str(gs.reach9().get("why", "dead9")), str(a.get("text", ""))])
	return {"dead_nogift": dead_nogift, "dead_steps": dead_steps, "bad": bad, "first_dead": first_dead}


## Needed kinds (goal chain and need sources) that are gone from the board.
func gone_kinds(gs: GameState) -> Array:
	var out: Array = []
	var keep := gs._kept_kinds9()
	var c := {}
	for f in gs.fields:
		c[f.kind] = true
	for k in keep:
		if not c.has(int(k)):
			out.append(FieldData.kind_name(int(k)))
	return out


func report_run(tag: String, n: int, what: String, r: Dictionary, extra: String = "") -> void:
	for b in r["bad"]:
		find("line", str(b))
	if not bool(r["won"]):
		find("notwon", "%s L%d %s: nicht gewonnen %s %s" % [tag, n, what, str(r), extra])
	if int(r["nogift"]) > 0:
		find("nogift", "%s L%d %s: Angebot ohne Geschenk %d× %s" % [tag, n, what, int(r["nogift"]), extra])
	if int(r["flat"]) > 0:
		find("flat", "%s L%d %s: Geschenk ohne Fortschritt %d× %s" % [tag, n, what, int(r["flat"]), extra])
	if int(r["most"]) >= 3:
		find("loop", "%s L%d %s: dieselbe Stellung %d× %s" % [tag, n, what, int(r["most"]), extra])


# ---------------------------------------------------------------------------------------------------------------
# mode=inlevel: burn a level for up to 300 steps (three styles), then the HUD follower, the hint bot and a random
# player must still win with the net; every HUD line must be a possible action.
# ---------------------------------------------------------------------------------------------------------------
func m_inlevel() -> void:
	var seed := int(args.get("seed", "1"))
	var cap := int(args.get("cap", "300"))
	var hint_every := int(args.get("hint", "4"))
	var rng := RandomNumberGenerator.new()
	for n: int in lv_range():
		var t0 := Time.get_ticks_msec()
		var size := Campaign.pool_size(n)
		var bi := 1 + posmod(seed * 7 + n * 3, maxi(1, size - 1))
		var boards: Array = [Campaign.board(n, bi)]
		if not Campaign.first_of_act(n):
			# a carried start: yesterday's level won by its stored solution on another board
			var pb := Campaign.board(n - 1, 1 + posmod(seed * 5 + n, maxi(1, Campaign.pool_size(n - 1) - 1)))
			var prev := Campaign.new_state(n - 1, pb)
			for s in pb.get("solution", []):
				var sa: Array = s
				if str(sa[0]) == "twist":
					tw(prev, sa[1])
				else:
					prev.play({"type": str(sa[0]), "field": int(sa[1])})
			var cb := Campaign.carry(Campaign.decode(prev.slot_board9()), n, seed * 13 + n, bi)
			cb = Campaign.ensure(n, cb, bi)
			boards.append(cb)
		var line := "L%d" % n
		for bx in boards.size():
			var b: Dictionary = boards[bx]
			for style in 3:
				var steps_burn: int = [cap, cap / 2, cap / 3][style]
				if seed % 3 == 1:
					steps_burn = [40, 25, 15][style]            # also short over-play (the common case)
				elif seed % 3 == 2:
					steps_burn = [120, 60, 30][style]
				rng.seed = seed * 100003 + n * 131 + bx * 17 + style
				var gs := Campaign.new_state(n, b)
				var tag := "inlevel seed=%d board=%s style=%d" % [seed, ("pool%d" % bi) if bx == 0 else "carry", style]
				var br := burn(gs, rng, steps_burn, style, tag)
				for bb in br["bad"]:
					find("line", str(bb))
				if gs.day_won:
					stat("burn_won")
					continue
				stat("burned")
				var gone := gone_kinds(gs)
				var reach := gs.reach9()
				var ctx := "nach %d Schritten, weg=%s reach=%s dead_steps=%d regen=%d | %s" % [gs.steps9(), str(gone), str(reach["ok"]), int(br["dead_steps"]), gs.rain, hist(kinds_of(gs))]
				if not gone.is_empty():
					stat("gone_states")
				if not bool(reach["ok"]):
					stat("dead_states")
				# 1 the HUD follower with the net
				var c1 := gs.clone()
				var r1 := run_player(c1, "line", true, gs.steps9() + 150, rng, tag)
				report_run(tag, n, "Zeile+Netz", r1, ctx)
				stat("line_gifts", int(r1["gifts"]))
				stat("line_runs")
				# 2 the HUD follower without the net (info: does the world itself still work?)
				var c2 := gs.clone()
				var r2 := run_player(c2, "line", false, gs.steps9() + 150, rng, tag)
				stat("line_nonet_runs")
				if bool(r2["won"]):
					stat("line_nonet_won")
				elif bool(reach["ok"]):
					stat("line_nonet_lost_reach_ok")
					if not gone.is_empty():
						find("gone_reach_ok", "%s L%d: gebrauchte Art weg, reach9 sagt ok, Zeile ohne Netz gewinnt nicht in 150 (%s) %s" % [tag, n, str(r2), ctx])
				# 3 a random player with the net
				var c3 := gs.clone()
				var r3 := run_player(c3, "rand", true, gs.steps9() + 250, rng, tag)
				report_run(tag, n, "Zufall+Netz", r3, ctx)
				stat("rand_gifts", int(r3["gifts"]))
				# 4 the hint bot with the net (slow: a subset)
				if (n + seed + style + bx) % hint_every == 0:
					var c4 := gs.clone()
					var r4 := run_player(c4, "hint", true, gs.steps9() + 100, rng, tag)
					report_run(tag, n, "Tipp+Netz", r4, ctx)
					stat("hint_runs")
					stat("hint_gifts", int(r4["gifts"]))
					line += " tipp:%d/%dg" % [int(r4["steps"]) - gs.steps9(), int(r4["gifts"])]
				line += " [%s s%d: zeile %d/%dg ohne:%s zufall %d/%dg]" % ["p" if bx == 0 else "c", style, int(r1["steps"]) - gs.steps9(), int(r1["gifts"]), "ja" if bool(r2["won"]) else "NEIN", int(r3["steps"]) - gs.steps9(), int(r3["gifts"])]
		print("%s (%d ms)" % [line, Time.get_ticks_msec() - t0])


# ---------------------------------------------------------------------------------------------------------------
# Game-level helpers
# ---------------------------------------------------------------------------------------------------------------
func lt(y: int, m: int, d: int, h: int = 12, mi: int = 0) -> int:
	return Daily.local_unix(y, m, d, h, mi)


func new_game(path: String, now: int, fresh: bool) -> Node:
	if fresh:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		var rp := path.get_basename() + "_lauf.cfg"
		if FileAccess.file_exists(rp):
			DirAccess.remove_absolute(rp)
	var g: Node = GameScript.new()
	g.save_path = path
	g.reminder_echo = false
	g.clock_override = now
	g._load_best()
	return g


func g_do(g: Node, action: Dictionary) -> void:
	if str(action.get("type", "")) == "gift":
		var r: Dictionary = g.take_gift()
		if not r.is_empty():
			g.finish_round(r)
		return
	g.undo_state = g.state.clone()
	g._last_kind = str(action.get("type", "twist"))
	var res: Dictionary = g.state.play(action)
	g.busy = true
	g.finish_round(res)


## The start of a level in the real Game: every part of the gate, the HUD line, the water of the mix.
func check_start(g: Node, tag: String) -> bool:
	var gs: GameState = g.state
	var n: int = g.level_no
	var how := str(g.level_board.get("how", ""))
	var ok := true
	stat("starts")
	stat("start_" + how)
	var reach := gs.reach9()
	var cfg: Dictionary = gs.day
	var tn := int(cfg.get("level", n))
	if not bool(reach["ok"]):
		find("start_reach", "%s L%d how=%s: reach9 nicht ok %s | %s" % [tag, n, how, str(reach), hist(kinds_of(gs))])
		ok = false
	if not gs.lines().is_empty():
		var unspent := 0
		for ln in gs.lines():
			if not gs.spent.has(GameState.line_key(ln)):
				unspent += 1
		if unspent > 0 and not g.run_resumed:
			find("start_lines", "%s L%d how=%s: %d fertige Reihen am Start" % [tag, n, how, unspent])
			ok = false
	if gs.day_won:
		find("start_won", "%s L%d how=%s: schon gewonnen" % [tag, n, how])
		ok = false
	var known := Campaign.known_kinds(tn)
	for f in gs.fields:
		if not known.has(f.kind):
			find("start_kind", "%s L%d how=%s: fremde Art %s am Start" % [tag, n, how, FieldData.kind_name(f.kind)])
			ok = false
			break
	if not g.run_resumed:
		var w := cnt(gs, WATER)
		var w0 := water_of(tn)
		if w != w0:
			stat("start_water_off")
			if absi(w - w0) > Campaign.TOPUP_MAX or (w0 > 0 and w == 0):
				find("start_water", "%s L%d how=%s: Wasser %d statt %d | %s" % [tag, n, how, w, w0, hist(kinds_of(gs))])
				ok = false
		if gs.progress9() > 0:
			find("start_progress", "%s L%d how=%s: Fortschritt %d am Start" % [tag, n, how, gs.progress9()])
	var a := na(gs)
	var why := line_bad(gs, a)
	if why != "":
		find("start_line", "%s L%d how=%s: Zeile „%s“ %s" % [tag, n, how, str(a.get("text", "")), why])
		ok = false
	var ov: Dictionary = g.overnight
	if how == "fallback" and str(ov.get("line", "")) != str(Campaign.TEXT["fresh"]):
		find("start_silent", "%s L%d: Rückfall aufs Pool-Brett ohne „Heute eine frische Welt“ (Zeile „%s“)" % [tag, n, str(ov.get("line", ""))])
	return ok


## Play the running level in the real Game. persona: "line" | "hint" | "rand" (with the net: accepts the offer).
## Returns true when won.
func g_play(g: Node, persona: String, rng: RandomNumberGenerator, cap: int, tag: String) -> bool:
	var acts := 0
	var gs0: GameState = g.state
	var s_cap := gs0.steps9() + cap
	var seen := {}
	while acts < cap * 4:
		var gs: GameState = g.state
		if gs.day_won or gs.steps9() >= s_cap:
			break
		acts += 1
		if not (g.rescue_offer as Dictionary).is_empty():
			if bool(g.rescue_offer.get("gift", false)):
				stat("g_gifts")
				var s0 := gs._subs_sum9() + gs.progress9()
				g_do(g, {"type": "gift"})
				gs = g.state
				if gs._subs_sum9() + gs.progress9() <= s0 and not gs.day_won:
					find("flat", "%s L%d: Geschenk ohne Fortschritt (Game)" % [tag, g.level_no])
				continue
			find("nogift", "%s L%d: Angebot ohne Geschenk (Game) %s" % [tag, g.level_no, str(g.rescue_offer)])
			g.rescue_later()
		if persona == "line":
			var a: Dictionary = g.next_action()
			var why := line_bad(gs, a)
			if why != "":
				find("line", "%s L%d s%d „%s“ %s" % [tag, g.level_no, gs.steps9(), str(a.get("text", "")), why])
			var tool := str(a.get("tool", ""))
			var mv: Dictionary = a.get("move", {})
			if tool == "gift" and why == "":
				stat("g_gifts")
				g_do(g, {"type": "gift"})
			elif (tool == "rain" or tool == "meteor") and why == "":
				g_do(g, {"type": tool, "field": int(a["field"])})
			elif not mv.is_empty() and why == "":
				g_do(g, {"type": "twist", "axis": int(mv["axis"]), "layer": int(mv["layer"]), "turns": int(mv["turns"])})
				var key := (g.state as GameState).slot_board9() + "|%d" % (g.state as GameState).rain
				seen[key] = int(seen.get(key, 0)) + 1
				if int(seen[key]) == 3:
					find("loop", "%s L%d: dieselbe Stellung 3× (Game)" % [tag, g.level_no])
			else:
				var m: Array = GameState.MOVES[rng.randi_range(0, 26)]
				g_do(g, {"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])})
		elif persona == "hint":
			var h := ba(gs)
			if h.is_empty():
				var m2: Array = GameState.MOVES[rng.randi_range(0, 26)]
				g_do(g, {"type": "twist", "axis": int(m2[0]), "layer": int(m2[1]), "turns": int(m2[2])})
			else:
				g_do(g, h)
		else:
			var did := false
			if gs.rain > 0 and rng.randf() < 0.4:
				var cand: Array = []
				for f in gs.fields:
					if gs.rain_ok9(f):
						cand.append(f.id)
				if not cand.is_empty():
					g_do(g, {"type": "rain", "field": int(cand[rng.randi_range(0, cand.size() - 1)])})
					did = true
			if not did and gs.meteors > 0 and rng.randf() < 0.3:
				var land: Array = []
				for f in gs.fields:
					if gs.meteor_ok9(f):
						land.append(f.id)
				if not land.is_empty():
					g_do(g, {"type": "strike", "field": int(land[rng.randi_range(0, land.size() - 1)])})
					did = true
			if not did:
				var m3: Array = GameState.MOVES[rng.randi_range(0, 26)]
				g_do(g, {"type": "twist", "axis": int(m3[0]), "layer": int(m3[1]), "turns": int(m3[2])})
	return (g.state as GameState).day_won


## Over-play inside the Game: `steps` careless steps (rain on water first, meteors anywhere), help declined
## („Weiterspielen“), never the winning action.
func g_overplay(g: Node, rng: RandomNumberGenerator, steps: int) -> void:
	var gs0: GameState = g.state
	var s_end := gs0.steps9() + steps
	var guard := 0
	while guard < steps * 5:
		guard += 1
		var gs: GameState = g.state
		if gs.day_won or gs.steps9() >= s_end:
			break
		if not (g.rescue_offer as Dictionary).is_empty():
			g.rescue_later()
		var act := {}
		if gs.rain > 0:
			var cand: Array = []
			var wat: Array = []
			for f in gs.fields:
				if gs.rain_ok9(f):
					cand.append(f.id)
					if f.kind == WATER:
						wat.append(f.id)
			var pool: Array = wat if not wat.is_empty() else cand
			if not pool.is_empty():
				act = {"type": "rain", "field": int(pool[rng.randi_range(0, pool.size() - 1)])}
		if act.is_empty() and gs.meteors > 0 and rng.randf() < 0.5:
			var land: Array = []
			for f in gs.fields:
				if gs.meteor_ok9(f):
					land.append(f.id)
			if not land.is_empty():
				act = {"type": "strike", "field": int(land[rng.randi_range(0, land.size() - 1)])}
		if act.is_empty():
			var m: Array = GameState.MOVES[rng.randi_range(0, 26)]
			act = {"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])}
		var c := gs.clone()
		c.play(act)
		if c.day_won:
			continue
		g_do(g, act)


## App closed and opened again in the middle of a level: the run must come back exactly.
func g_reopen(g: Node, path: String, tag: String) -> Node:
	var gs: GameState = g.state
	var n: int = g.level_no
	var wdt: bool = g.wdt_key >= 0
	var board0 := gs.slot_board9()
	var steps0 := gs.steps9()
	var rain0 := gs.rain
	var prog0 := gs.progress9()
	var now: int = g.clock_override
	g._save_running()
	g._save_profile()
	var had: bool = not (g.saved_run() as Dictionary).is_empty()
	g.free()
	var g2 := new_game(path, now, false)
	if not had:
		return g2
	var ok: bool = g2.start_level_wdt() if wdt else g2.start_level(n)
	var gs2: GameState = g2.state
	stat("reopens")
	if not ok or not g2.run_resumed or gs2.slot_board9() != board0 or gs2.steps9() != steps0 or gs2.rain != rain0 or gs2.progress9() != prog0:
		find("resume", "%s L%d: Versuch nach Neustart nicht gleich (ok=%s resumed=%s Schritte %d/%d Regen %d/%d Fortschritt %d/%d Brett gleich=%s)" % [tag, n, str(ok), str(g2.run_resumed), gs2.steps9() if gs2 != null else -1, steps0, gs2.rain if gs2 != null else -1, rain0, gs2.progress9() if gs2 != null else -1, prog0, str(gs2 != null and gs2.slot_board9() == board0)])
	return g2


# ---------------------------------------------------------------------------------------------------------------
# mode=walk: a whole campaign in the real Game (saves, days, carry, resume, retry, new world, Welt des Tages)
# ---------------------------------------------------------------------------------------------------------------
func m_walk() -> void:
	var seed := int(args.get("seed", "1"))
	var last := int(args.get("to", "60"))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 5
	var path := "user://v_walk_%d.cfg" % seed
	var t := lt(2026, 11, 12, 10)
	var g := new_game(path, t, true)
	var day := 0
	var changed_sum := 0
	var carries := 0
	var guard := 0
	while guard < 200:
		guard += 1
		var n: int = g.current_level()
		if g.level_stars(n) > 0 and n >= last:
			break
		if g.level_stars(n) > 0 or not g.level_unlocked(n):
			day += 1
			g.clock_override = t + day * Daily.DAY
			continue
		var tag := "walk seed=%d Tag %d" % [seed, day]
		if not g.start_level(n):
			find("walk_start", "%s L%d: start_level false" % [tag, n])
			break
		check_start(g, tag)
		var how := str(g.level_board.get("how", ""))
		if how == "carry":
			carries += 1
			changed_sum += (g.level_board.get("changed", []) as Array).size()
		var persona := posmod(seed + n * 3 + rng.randi_range(0, 3), 4)
		var t0 := Time.get_ticks_msec()
		var gs: GameState = g.state
		var par := gs.par9
		var won := false
		var desc := ""
		if persona == 0:
			desc = "Zeile"
			won = g_play(g, "line", rng, 8 * par + 40, tag)
		elif persona == 1:
			var k := rng.randi_range(10, 60)
			desc = "voraus %d + Zeile" % k
			g_overplay(g, rng, k)
			if rng.randf() < 0.6:
				g = g_reopen(g, path, tag)
			won = g_play(g, "line", rng, 8 * par + 60, tag)
		elif persona == 2:
			desc = "Zufall+Netz"
			won = g_play(g, "rand", rng, 250, tag)
			if not won:
				g = g_reopen(g, path, tag)
				won = g_play(g, "line", rng, 8 * par + 60, tag)
		else:
			var k2 := rng.randi_range(20, 120)
			desc = "voraus %d + Tipp" % k2
			g_overplay(g, rng, k2)
			g = g_reopen(g, path, tag)
			won = g_play(g, "hint", rng, 60, tag)
			if not won:
				stat("hint_gave_up")
				won = g_play(g, "line", rng, 8 * par + 60, tag)
		var gsw: GameState = g.state
		print("  L%d %s how=%s → %s Schritte %d Sterne %d (%d ms)" % [n, desc, how, "gewonnen" if won else "OFFEN", gsw.steps9(), gsw.stars() if won else 0, Time.get_ticks_msec() - t0])
		if not won:
			find("walk_notwon", "%s L%d %s how=%s: nicht gewonnen nach %d Schritten, Fortschritt %d/%d reach=%s | %s" % [tag, n, desc, how, gsw.steps9(), gsw.progress9(), gsw.target9(), str(gsw.reach9()), hist(kinds_of(gsw))])
			# force the win so that the walk goes on: new world
			if not g.new_world():
				break
			check_start(g, tag + " neue Welt")
			if not g_play(g, "line", rng, 300, tag + " neue Welt"):
				find("walk_notwon2", "%s L%d: auch die neue Welt nicht gewonnen" % [tag, n])
				break
		if g.level_stars(n) <= 0:
			find("walk_stars", "%s L%d: gewonnen, aber keine Sterne gespeichert" % [tag, n])
			break
		if not (g.saved_run() as Dictionary).is_empty():
			find("walk_run", "%s L%d: nach dem Sieg bleibt ein laufender Versuch" % [tag, n])
		var world := str(g.camp["world"])
		# after the win, sometimes: again (same board), a replay of the won level, a new world – the world for tomorrow stays
		var r := rng.randi_range(0, 5)
		if r == 0:
			if g.retry_level():
				check_start(g, tag + " Nochmal")
				g_overplay(g, rng, 8)
		elif r == 1:
			if g.start_level(n):
				check_start(g, tag + " Wiederholung")
				g_play(g, "line", rng, 6 * par + 30, tag + " Wiederholung")
		elif r == 2:
			if g.start_level(n) and g.new_world():
				check_start(g, tag + " Neue Welt")
				g_overplay(g, rng, 5)
		elif r == 3 and n > 2:
			var back := rng.randi_range(1, n - 1)
			if g.start_level(back):
				check_start(g, tag + " altes Level %d" % back)
				g_play(g, "line", rng, 6 * (g.state as GameState).par9 + 30, tag + " altes Level")
		if int(g.camp["world_level"]) == n and str(g.camp["world"]) != world and r != 1:
			find("walk_world", "%s L%d: die Welt für morgen hat sich nach dem Sieg geändert (r=%d)" % [tag, n, r])
		g._save_profile()
		g.free()
		g = new_game(path, t + day * Daily.DAY, false)
	print("walk seed=%d: bis Level %d, %d Tage, Welt von gestern %d×, im Schnitt %.1f geänderte Felder" % [seed, g.current_level(), day, carries, float(changed_sum) / maxf(1.0, float(carries))])
	# Welt des Tages (after the campaign, and as a veteran): several days
	g.camp["veteran"] = true
	for d in 6:
		day += 1
		g.clock_override = t + day * Daily.DAY
		if not g.start_level_wdt():
			stat("wdt_closed")
			continue
		var tagw := "walk seed=%d WdT Tag %d (Vorlage L%d)" % [seed, day, g.level_no]
		check_start(g, tagw)
		g_overplay(g, rng, rng.randi_range(0, 30))
		g = g_reopen(g, path, tagw)
		g.camp["veteran"] = true
		var wonw := g_play(g, "line", rng, 8 * (g.state as GameState).par9 + 60, tagw)
		stat("wdt_runs")
		if not wonw:
			find("wdt_notwon", "%s: nicht gewonnen %d/%d" % [tagw, (g.state as GameState).progress9(), (g.state as GameState).target9()])
			if g.new_world():
				check_start(g, tagw + " neue Welt")
	g.free()


# ---------------------------------------------------------------------------------------------------------------
# mode=extreme: extreme worlds of yesterday and extreme stored starts for every level, through the real Game
# ---------------------------------------------------------------------------------------------------------------
func set_progress(g: Node, n: int, t: int) -> void:
	for i in n - 1:
		(g.camp["stars"] as Array)[i] = 2
		(g.camp["won_key"] as Array)[i] = Daily.day_key(t) - n + i
	g.camp["pos"] = n - 1
	g.camp["last_new_key"] = Daily.day_key(t) - 1


func worlds_for(n: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var names: Array = []
	var mk := func(k: int) -> Array:
		var a: Array = []
		for i in 54:
			a.append(k)
		return a
	out.append(mk.call(WATER))
	names.append("nur Wasser")
	out.append(mk.call(STONE))
	names.append("nur Fels")
	out.append(mk.call(E))
	names.append("nur Erde")
	out.append(mk.call(LAVA))
	names.append("nur Lava")
	var alt: Array = []
	for i in 54:
		alt.append(STONE if i % 2 == 0 else E)
	out.append(alt)
	names.append("Fels/Erde")
	# everything became the goal kind of yesterday (over-played to the end)
	var pc := Campaign.config(n - 1)
	var pg: Array = pc.get("goal", [])
	var gk := -1
	if not pg.is_empty():
		var g0: Array = pg[0]
		if str(g0[0]) == "make":
			gk = int((g0[1] as Array)[0])
		elif str(g0[0]) != "hold":
			gk = int(g0[1])
	if gk >= 0:
		out.append(mk.call(gk))
		names.append("nur " + FieldData.kind_name(gk))
		# yesterday's board with all water turned into the goal kind (the sea used up)
		var yb: Array = (Campaign.board(n - 1, 1)["kinds"] as Array).duplicate()
		for i2 in 54:
			if FieldData.water_family(int(yb[i2])):
				yb[i2] = gk
		out.append(yb)
		names.append("gestern, Meer → " + FieldData.kind_name(gk))
	# each kind of yesterday's mix alone
	var kk: Array = (pc.get("comp", {}) as Dictionary).keys()
	if not kk.is_empty():
		var one := int(str(kk[rng.randi_range(0, kk.size() - 1)]))
		out.append(mk.call(one))
		names.append("nur " + FieldData.kind_name(one))
	# random soup of yesterday's known kinds
	var kn: Array = Campaign.known_kinds(n - 1).keys()
	var soup: Array = []
	for i3 in 54:
		soup.append(int(kn[rng.randi_range(0, kn.size() - 1)]))
	out.append(soup)
	names.append("Zufall aus gestern")
	# kinds the level cannot know, and all 40 kinds at random
	out.append(mk.call(FieldData.PARADISE))
	names.append("nur Paradies")
	var any: Array = []
	for i4 in 54:
		any.append(rng.randi_range(0, FieldData.KIND_COUNT - 1))
	out.append(any)
	names.append("Zufall aus allen Arten")
	return [out, names]


func m_extreme() -> void:
	var seed := int(args.get("seed", "1"))
	var rng := RandomNumberGenerator.new()
	var t := lt(2026, 11, 12, 10)
	var path := "user://v_extreme_%d.cfg" % seed
	var play_every := int(args.get("play", "3"))
	var idx := 0
	for n: int in lv_range():
		if n < 2:
			continue
		var t0 := Time.get_ticks_msec()
		rng.seed = seed * 4099 + n
		var wn: Array = worlds_for(n, rng)
		var worlds: Array = wn[0]
		var names: Array = wn[1]
		var line := "L%d" % n
		for wi in worlds.size():
			# (a) as the world of yesterday  (b) as a stored start without fingerprint  (c) with the current fingerprint
			# (d) with a wrong fingerprint
			for variant in 4:
				if variant == 0 and Campaign.first_of_act(n):
					continue
				if variant >= 2 and (wi + seed) % 3 != 0:
					continue
				idx += 1
				var g := new_game(path, t, true)
				set_progress(g, n, t)
				var w: Array = worlds[wi]
				if variant == 0:
					g.camp["world"] = Campaign.encode(w)
					g.camp["world_level"] = n - 1
				else:
					g.camp["start"] = Campaign.encode(w)
					g.camp["start_level"] = n
					g.camp["start_seed"] = 1 + wi
					g.camp["start_cfg"] = ["", "", GameScript._cfg_hash(Campaign.config(n)), "falsch"][variant]
					if rng.randf() < 0.5 and not Campaign.first_of_act(n):
						g.camp["world"] = Campaign.encode(worlds[(wi + 3) % worlds.size()])
						g.camp["world_level"] = n - 1
				var tag := "extreme seed=%d Welt „%s“ Variante %d" % [seed, str(names[wi]), variant]
				if not g.start_level(n):
					find("ext_start", "%s L%d: start_level false" % [tag, n])
					g.free()
					continue
				var ok := check_start(g, tag)
				var how := str(g.level_board.get("how", ""))
				stat("ext_%d_%s" % [variant, how])
				if ok and idx % play_every == 0:
					var gs: GameState = g.state
					var mode := "line" if idx % (2 * play_every) == 0 else "rand"
					var cl := gs.clone()
					var r := run_player(cl, mode, true, 8 * gs.par9 + (60 if mode == "line" else 250), rng, tag)
					report_run(tag, n, mode + "+Netz", r, "how=%s" % how)
					line += " %s:%s%d/%dg" % [how.substr(0, 1), mode.substr(0, 1), int(r["steps"]), int(r["gifts"])]
				g.free()
		# exact mix, shuffled at random (a stored start of an older build with the right mix but any arrangement)
		for sh in 4:
			var comp: Dictionary = Campaign.config(n)["comp"]
			var ks: Array = []
			for key in comp:
				for j in int(comp[key]):
					ks.append(int(str(key)))
			while ks.size() < 54:
				ks.append(WATER)
			for i in range(53, 0, -1):
				var j2 := rng.randi_range(0, i)
				var tmp: int = ks[i]
				ks[i] = ks[j2]
				ks[j2] = tmp
			if sh == 3:
				ks.sort()               # sorted: clumps of every kind
			var g2 := new_game(path, t, true)
			set_progress(g2, n, t)
			g2.camp["start"] = Campaign.encode(ks)
			g2.camp["start_level"] = n
			g2.camp["start_seed"] = 5 + sh
			g2.camp["start_cfg"] = "" if sh % 2 == 0 else GameScript._cfg_hash(Campaign.config(n))
			var tag2 := "extreme seed=%d Mischung gemischt %d" % [seed, sh]
			if g2.start_level(n):
				var ok2 := check_start(g2, tag2)
				var how2 := str(g2.level_board.get("how", ""))
				stat("mix_%s" % how2)
				if ok2 and how2 == "stored":
					var gs2: GameState = g2.state
					var cl2 := gs2.clone()
					var r2 := run_player(cl2, "line", true, 8 * gs2.par9 + 80, rng, tag2)
					report_run(tag2, n, "Zeile+Netz", r2, "how=stored (gemischt)")
					line += " mix:%d/%dg" % [int(r2["steps"]), int(r2["gifts"])]
			else:
				find("ext_start", "%s L%d: start_level false" % [tag2, n])
			g2.free()
		print("%s (%d ms)" % [line, Time.get_ticks_msec() - t0])


# ---------------------------------------------------------------------------------------------------------------
# mode=migrate: saves of Build 12 (old campaign, 30 levels) and Build 13 (no fingerprint), with a stored start and a
# running attempt; then play on for some days (catch-up levels included)
# ---------------------------------------------------------------------------------------------------------------
func m_migrate() -> void:
	var seed := int(args.get("seed", "1"))
	var rng := RandomNumberGenerator.new()
	var t := lt(2026, 11, 12, 10)
	var path := "user://v_migrate_%d.cfg" % seed
	var days := int(args.get("days", "4"))
	for old_top: int in [4, 5, 6, 7, 8, 11, 12, 19, 20, 29, 30]:
		for variant in 4:
			rng.seed = seed * 977 + old_top * 31 + variant
			var cfg := ConfigFile.new()
			var st: Array = []
			var wk: Array = []
			var sp: Array = []
			var nb: Array = []
			for j in 30:
				st.append((1 + (j + seed) % 3) if j < old_top else 0)
				wk.append(20000 + j if j < old_top else -1)
				sp.append(7 if j < old_top else 0)
				nb.append(rng.randi_range(0, 3) if j < old_top else 0)
			var nxt_old := mini(30, old_top + 1)
			var nxt_new := Campaign.old_to_new(nxt_old)
			var startb: Array = []
			if variant == 0:
				for i in 54:
					startb.append(STONE if i % 3 else LAVA)                   # no water at all
			elif variant == 1:
				# exactly the mix of the new level, shuffled
				var comp: Dictionary = Campaign.config(nxt_new)["comp"]
				for key in comp:
					for j2 in int(comp[key]):
						startb.append(int(str(key)))
				while startb.size() < 54:
					startb.append(WATER)
				for i2 in range(53, 0, -1):
					var j3 := rng.randi_range(0, i2)
					var tmp: int = startb[i2]
					startb[i2] = startb[j3]
					startb[j3] = tmp
			elif variant == 2:
				for i3 in 54:
					startb.append(rng.randi_range(0, 26))                      # any old kind
			else:
				for i4 in 54:
					startb.append(WATER)
			var world: Array = []
			for i5 in 54:
				if variant == 0:
					world.append(STONE if i5 % 2 else E)
				elif variant == 1:
					world.append(int((Campaign.board(maxi(1, Campaign.old_to_new(old_top)), 1)["kinds"] as Array)[i5]))
				elif variant == 2:
					world.append(rng.randi_range(0, 26))
				else:
					world.append(FieldData.SOUP)
			cfg.set_value("kampagne", "version", 1)
			cfg.set_value("kampagne", "sterne", st)
			cfg.set_value("kampagne", "schritte", sp)
			cfg.set_value("kampagne", "gewonnen_am", wk)
			cfg.set_value("kampagne", "brett", nb)
			cfg.set_value("kampagne", "letzter_neuer", Daily.day_key(t) - (1 if variant % 2 == 0 else 0))
			cfg.set_value("kampagne", "welt", Campaign.encode(world))
			cfg.set_value("kampagne", "welt_level", old_top)
			cfg.set_value("kampagne", "start", Campaign.encode(startb))
			cfg.set_value("kampagne", "start_level", nxt_old)
			cfg.set_value("kampagne", "start_seed", 2)
			if variant == 3:
				cfg.set_value("kampagne", "schnell_bis", 30)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
			cfg.save(path)
			var run := ConfigFile.new()
			var rs := Campaign.new_state(nxt_new, Campaign.board(nxt_new, 1))
			tw(rs, GameState.MOVES[3])
			for f in rs.fields:
				if f.kind == WATER:
					rs._setk9(f, E)
			var rd := {"v": 1, "level": nxt_old, "wdt": -1, "cfg": "alt", "state": rs.save9(), "undo": {}, "board": {"kinds": startb, "seed": 2, "how": "stored", "index": -1},
				"steps": 1, "progress": 0, "target": 5}
			if variant == 1:
				rd["level"] = nxt_new
			run.set_value("lauf", "daten", rd)
			run.save(path.get_basename() + "_lauf.cfg")
			var g := new_game(path, t, false)
			var tag := "migrate B12 seed=%d alt_oben=%d Variante %d" % [seed, old_top, variant]
			if not (g.saved_run() as Dictionary).is_empty():
				find("mig_run", "%s: der alte laufende Versuch bleibt" % tag)
			var played := 0
			var line := "B12 alt %d v%d:" % [old_top, variant]
			for day in days:
				g.clock_override = t + day * Daily.DAY
				var guard := 0
				while guard < 12:
					guard += 1
					var pick := -1
					for n2 in range(1, Campaign.COUNT + 1):
						if g.level_unlocked(n2) and g.level_stars(n2) == 0:
							pick = n2
							break
					if pick < 0:
						break
					if not g.start_level(pick):
						find("mig_start", "%s Tag %d L%d: start_level false" % [tag, day, pick])
						break
					if g.run_resumed:
						find("mig_resumed", "%s Tag %d L%d: ein alter Versuch wurde fortgesetzt" % [tag, day, pick])
					var ok := check_start(g, tag + " Tag %d" % day)
					var how := str(g.level_board.get("how", ""))
					played += 1
					var persona := "line" if (pick + guard + variant) % 3 != 0 else "rand"
					if (pick + seed) % 4 == 0:
						g_overplay(g, rng, rng.randi_range(5, 40))
						g = g_reopen(g, path, tag)
					var won := g_play(g, persona, rng, 8 * (g.state as GameState).par9 + (60 if persona == "line" else 250), tag + " Tag %d" % day)
					line += " L%d(%s%s%d)" % [pick, how.substr(0, 1), "+" if won else "-", (g.state as GameState).steps9()]
					if not won:
						find("mig_notwon", "%s Tag %d L%d how=%s %s: nicht gewonnen %d/%d reach=%s" % [tag, day, pick, how, persona, (g.state as GameState).progress9(), (g.state as GameState).target9(), str((g.state as GameState).reach9())])
						break
			print("%s  (%d Level)" % [line, played])
			g._save_profile()
			g.free()
	# Build 13: version 2 without fingerprint; the stored start of the running level and a run file of Build 13
	for n: int in [2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 20, 27, 41, 42, 48, 56, 60]:
		for variant in 5:
			rng.seed = seed * 733 + n * 17 + variant
			var g1 := new_game(path, t, true)
			set_progress(g1, n, t)
			var w: Array = []
			var sb: Array = []
			var comp2: Dictionary = Campaign.config(n)["comp"]
			for key2 in comp2:
				for j4 in int(comp2[key2]):
					sb.append(int(str(key2)))
			while sb.size() < 54:
				sb.append(WATER)
			for i6 in range(53, 0, -1):
				var j5 := rng.randi_range(0, i6)
				var tmp2: int = sb[i6]
				sb[i6] = sb[j5]
				sb[j5] = tmp2
			if variant == 1:
				# Build 13 top-up took water: the stored start has the mix except that all water is land
				for i7 in 54:
					if int(sb[i7]) == WATER:
						sb[i7] = E if i7 % 2 else STONE
			elif variant == 2:
				sb = (Campaign.board(n, 2)["kinds"] as Array).duplicate()
			elif variant == 3:
				sb = (Campaign.board(n, 3)["kinds"] as Array).duplicate()
				for i8 in 54:
					if int(sb[i8]) == WATER and i8 % 3 != 0:
						sb[i8] = STONE
			for i9 in 54:
				w.append(E if variant % 2 == 0 else int((Campaign.board(maxi(1, n - 1), 2)["kinds"] as Array)[i9]))
			g1.camp["world"] = Campaign.encode(w)
			g1.camp["world_level"] = n - 1
			g1.camp["start"] = Campaign.encode(sb)
			g1.camp["start_level"] = n
			g1.camp["start_seed"] = 3
			g1.camp["start_cfg"] = ""
			g1._save_profile()
			# the run file as Build 13 wrote it: no "rv", the old hash; the state has no water and no rain
			var rs2 := Campaign.new_state(n, {"kinds": sb, "seed": 3})
			tw(rs2, GameState.MOVES[5])
			for f2 in rs2.fields:
				if f2.kind == WATER:
					rs2._setk9(f2, E)
			rs2.rain = 0
			var rd2 := {"v": 1, "level": n, "wdt": -1, "cfg": (var_to_str(Campaign.config(n))).md5_text(), "state": rs2.save9(), "undo": {},
				"board": {"kinds": sb, "seed": 3, "how": "stored", "index": -1}, "hint_free": 1, "undo_free": 1, "rescue_at": -99,
				"dead_told": false, "offer": {}, "attempt_key": Daily.day_key(t), "attempt_start": t, "steps": 1, "progress": 0, "target": 5}
			if variant == 4:
				rd2["rv"] = GameState.RULES_VERSION       # forged: right version, old hash
			var runf := ConfigFile.new()
			runf.set_value("lauf", "daten", rd2)
			runf.save(path.get_basename() + "_lauf.cfg")
			g1.free()
			var g3 := new_game(path, t, false)
			var tag3 := "migrate B13 seed=%d L%d Variante %d" % [seed, n, variant]
			if not g3.start_level(n):
				find("mig_start", "%s: start_level false" % tag3)
				g3.free()
				continue
			if g3.run_resumed:
				find("mig_resumed", "%s: der Versuch aus Build 13 wurde fortgesetzt (Wasser %d)" % [tag3, cnt(g3.state, WATER)])
			var ok3 := check_start(g3, tag3)
			var how3 := str(g3.level_board.get("how", ""))
			stat("b13_%d_%s" % [variant, how3])
			if ok3:
				var won3 := g_play(g3, "line" if variant % 2 == 0 else "rand", rng, 8 * (g3.state as GameState).par9 + (60 if variant % 2 == 0 else 250), tag3)
				if not won3:
					find("mig_notwon", "%s how=%s: nicht gewonnen %d/%d" % [tag3, how3, (g3.state as GameState).progress9(), (g3.state as GameState).target9()])
			g3.free()
	# Build 14 run saved in a dead state (no water, no rain, goal chain removed): resume offers help at once
	for n3: int in lv_range():
		rng.seed = seed * 389 + n3
		var g4 := new_game(path, t, true)
		set_progress(g4, n3, t)
		if not g4.start_level(n3):
			g4.free()
			continue
		g_overplay(g4, rng, 3)
		var gs4: GameState = g4.state
		if gs4.day_won:
			g4.free()
			continue
		var style := (n3 + seed) % 3
		for f3 in gs4.fields:
			if style == 0 and f3.kind == WATER:
				gs4._setk9(f3, E if gs4.thrive9.has(WATER) or n3 < 15 else STONE)
			elif style == 1 and gs4.chain9.has(f3.kind) and f3.kind != WATER:
				gs4._setk9(f3, WATER)
			elif style == 2 and gs4._kept_kinds9().has(f3.kind):
				gs4._setk9(f3, FieldData.PARADISE)
		gs4.rain = 0
		gs4.meteors = 0
		gs4._grp_ok = false
		g4.rescue_offer = {}
		g4.dead_told = false
		g4._save_run()
		g4._save_profile()
		var dead0 := gs4.stuck9()
		g4.free()
		var g5 := new_game(path, t, false)
		var told: Array = []
		g5.level_dead.connect(func(info): told.append(info))
		var tag5 := "resume dead seed=%d L%d Art %d" % [seed, n3, style]
		if not g5.start_level(n3) or not g5.run_resumed:
			find("resume_dead", "%s: nicht fortgesetzt" % tag5)
			g5.free()
			continue
		var gs5: GameState = g5.state
		stat("resume_dead_runs")
		if dead0 == "dead":
			stat("resume_dead_dead")
			if told.is_empty() or not bool((told[0] as Dictionary).get("gift", false)):
				find("resume_dead", "%s: Sackgasse nach dem Fortsetzen, aber keine Hilfe mit Geschenk (%s) reach=%s | %s" % [tag5, str(told), str(gs5.reach9()), hist(kinds_of(gs5))])
		var a5: Dictionary = g5.next_action()
		var why5 := line_bad(gs5, a5)
		if why5 != "":
			find("line", "%s „%s“ %s" % [tag5, str(a5.get("text", "")), why5])
		var won5 := g_play(g5, "line", rng, 8 * gs5.par9 + 120, tag5)
		if not won5:
			find("resume_dead", "%s: nicht gewonnen %d/%d reach=%s | %s" % [tag5, (g5.state as GameState).progress9(), (g5.state as GameState).target9(), str((g5.state as GameState).reach9()), hist(kinds_of(g5.state))])
		g5.free()


# ---------------------------------------------------------------------------------------------------------------
# mode=easy: the good bots on fresh pool boards: steps, stars, points per level (for the comparison with the model)
# ---------------------------------------------------------------------------------------------------------------
func m_easy() -> void:
	var seed := int(args.get("seed", "1"))
	var nb := int(args.get("boards", "6"))
	var rng := RandomNumberGenerator.new()
	for n: int in lv_range():
		var t0 := Time.get_ticks_msec()
		var size := Campaign.pool_size(n)
		var hs: Array = []
		var ls: Array = []
		var h3 := 0
		var l3 := 0
		var hp := 0
		var lp := 0
		var hw := 0
		var lw := 0
		var sol: Array = []
		for j in nb:
			var bi := 1 + posmod(seed * 3 + j * 5 + n, maxi(1, size - 1))
			var b := Campaign.board(n, bi)
			sol.append(int(b["solved_in"]))
			rng.seed = seed * 31 + n * 7 + j
			var g1 := Campaign.new_state(n, b)
			var r1 := run_player(g1, "hint", false, 40, rng, "easy")
			if bool(r1["won"]):
				hw += 1
				hs.append(int(r1["steps"]))
				hp += g1.level_points()
				if int(r1["stars"]) == 3:
					h3 += 1
			var g2 := Campaign.new_state(n, b)
			var r2 := run_player(g2, "line", false, 60, rng, "easy")
			for bb in r2["bad"]:
				find("line", str(bb))
			if bool(r2["won"]):
				lw += 1
				ls.append(int(r2["steps"]))
				lp += g2.level_points()
				if int(r2["stars"]) == 3:
					l3 += 1
			if int(r2["most"]) >= 3:
				find("loop", "easy L%d Brett %d: Zeile ohne Netz dieselbe Stellung %d×" % [n, bi, int(r2["most"])])
		hs.sort()
		ls.sort()
		sol.sort()
		var stv: Array = Campaign.config(n)["stars"]
		print("EASY L%d sterne<=%d/%d tipp won=%d/%d med=%s min=%s s3=%d pts=%.1f | zeile won=%d/%d med=%s min=%s s3=%d pts=%.1f | loesung med=%d (%d ms)" % [n, int(stv[0]), int(stv[1]),
			hw, nb, str(hs[hs.size() / 2]) if not hs.is_empty() else "-", str(hs[0]) if not hs.is_empty() else "-", h3, float(hp) / maxf(1.0, float(hw)),
			lw, nb, str(ls[ls.size() / 2]) if not ls.is_empty() else "-", str(ls[0]) if not ls.is_empty() else "-", l3, float(lp) / maxf(1.0, float(lw)),
			int(sol[sol.size() / 2]), Time.get_ticks_msec() - t0])


# ---------------------------------------------------------------------------------------------------------------
# mode=quick: is there a win in 1 or 2 actions (twists and rains) on a pool board under the game rules?
# ---------------------------------------------------------------------------------------------------------------
func actions_of(gs: GameState) -> Array:
	var out: Array = []
	for m in GameState.MOVES:
		out.append({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])})
	if gs.rain > 0:
		for f in gs.fields:
			if gs.rain_ok9(f):
				out.append({"type": "rain", "field": f.id})
	if gs.meteors > 0:
		for f in gs.fields:
			if gs.meteor_ok9(f):
				out.append({"type": "strike", "field": f.id})
	return out


func m_quick() -> void:
	var depth := int(args.get("depth", "2"))
	for n: int in lv_range():
		var t0 := Time.get_ticks_msec()
		var size := Campaign.pool_size(n)
		var one := 0
		var two := 0
		var ex := ""
		for bi in size:
			var gs := Campaign.new_state(n, Campaign.board(n, bi))
			var found := 0
			for a in actions_of(gs):
				var c := gs.clone()
				c.play(a)
				if c.day_won:
					found = 1 if c.steps9() <= 1 else found
					if found == 1:
						break
				if depth >= 2 and found == 0:
					for a2 in actions_of(c):
						var c2 := c.clone()
						c2.play(a2)
						if c2.day_won and c2.steps9() <= 2:
							found = 2
							if ex == "":
								ex = "Brett %d: %s dann %s (Schritte %d, Sterne %d)" % [bi, str(a), str(a2), c2.steps9(), c2.stars()]
							break
			if found == 1:
				one += 1
			elif found == 2:
				two += 1
		print("QUICK L%d: %d Bretter, Sieg in 1 Schritt: %d, in 2 Schritten: %d %s (%d ms)" % [n, size, one, two, ex, Time.get_ticks_msec() - t0])
		if one > 0:
			find("quick1", "L%d: %d Pool-Bretter in 1 Schritt gewonnen" % [n, one])
		if two > 0:
			find("quick2", "L%d: %d Pool-Bretter in 2 Schritten gewonnen (%s)" % [n, two, ex])


# ---------------------------------------------------------------------------------------------------------------
# mode=farm: a player who wants the help: makes the level dead on purpose (1-ply), takes every gift. Stars and steps.
# ---------------------------------------------------------------------------------------------------------------
func m_farm() -> void:
	var seed := int(args.get("seed", "1"))
	var nb := int(args.get("boards", "3"))
	var rng := RandomNumberGenerator.new()
	for n: int in lv_range():
		var t0 := Time.get_ticks_msec()
		var size := Campaign.pool_size(n)
		var out := "FARM L%d (★★★ ≤ %d, Lösung im Pool):" % [n, int((Campaign.config(n)["stars"] as Array)[0])]
		for j in nb:
			var bi := 1 + posmod(seed * 3 + j * 5 + n, maxi(1, size - 1))
			var b := Campaign.board(n, bi)
			rng.seed = seed * 53 + n * 11 + j
			var gs := Campaign.new_state(n, b)
			var gifts := 0
			var told_at := -99
			var dead_told := false
			var guard := 0
			var dead_gifts := 0
			while not gs.day_won and gs.steps9() < 40 and guard < 400:
				guard += 1
				# the action that makes the level dead; else the one that leaves the least material; never a normal win
				var best: Dictionary = {}
				var best_v := INF
				for a in actions_of(gs):
					var c := gs.clone()
					c.play(a)
					var v := material(c) * 0.01 + rng.randf() * 0.005
					if c.day_won:
						v = 500.0
					elif not bool(c.reach9()["ok"]) or c.dead9():
						v -= 1000.0
					elif str(a["type"]) != "twist":
						v += 5.0                 # keep the tools for the moment they kill
					if v < best_v:
						best_v = v
						best = a
				if best.is_empty():
					break
				gs.play(best)
				# the net as in the game: take every gift, again and again while the offer stands
				var inner := 0
				while not gs.day_won and inner < 60:
					inner += 1
					var st := gs.stuck9()
					if st != "dead":
						dead_told = false
					if st == "":
						break
					if (st == "dead" and not dead_told) or gs.steps9() - told_at >= GameState.STALL9:
						told_at = gs.steps9()
						if gs.gift_plan9().is_empty():
							break
						gs.play({"type": "gift"})
						gifts += 1
						if st == "dead":
							dead_gifts += 1
						dead_told = false
					else:
						break
			out += " [Brett %d Lösung %d: %s in %d Schritten, %d Sterne, %d Punkte, %d Geschenke (%d aus Sackgasse)]" % [bi, int(b["solved_in"]), "gewonnen" if gs.day_won else "offen", gs.steps9(), gs.stars() if gs.day_won else 0, gs.level_points(), gifts, dead_gifts]
			if gs.day_won and gs.stars() == 3 and gs.steps9() < int(b["solved_in"]) and dead_gifts > 0:
				find("farm", "L%d Brett %d: mit absichtlicher Sackgasse ★★★ in %d Schritten (Pool-Lösung %d), %d Geschenke" % [n, bi, gs.steps9(), int(b["solved_in"]), gifts])
		print("%s (%d ms)" % [out, Time.get_ticks_msec() - t0])


func m_probe() -> void:
	for n: int in [6, 9, 27, 41, 59]:
		var gs := Campaign.new_state(n, Campaign.board(n, 1))
		var t := Time.get_ticks_usec()
		var a := gs.next_action()
		var t1 := Time.get_ticks_usec()
		var h := gs.best_action()
		var t2 := Time.get_ticks_usec()
		var c := gs.clone()
		var t3 := Time.get_ticks_usec()
		tw(c, GameState.MOVES[0])
		var t4 := Time.get_ticks_usec()
		print("L%d next_action %d us („%s“), best_action %d us (%s), clone %d us, round %d us" % [n, t1 - t, str(a.get("text", "")), t2 - t1, str(h.get("type", "")), t3 - t2, t4 - t3])
