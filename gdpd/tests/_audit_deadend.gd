extends SceneTree
## Audit „deadend“ (nur Messung, kein CI-Test): Kann ein Level WÄHREND des Spiels unlösbar werden oder festhängen,
## und merkt das Spiel es?
##   godot --headless --script res://tests/_audit_deadend.gd -- --out=<datei.jsonl> [--levels=1-60] [--boards=10]
##       [--burn_boards=2] [--greedy_boards=10] [--part=i/n] [--desc] [--bots=careless,greedy,burn] [--hint=0|1|2]
##       [--ks=5,15,40,100,250] [--mode=main|chain|hud|norain|rainhud] [--pick=Level:Brett:Bot:Art:K;…]
## --mode=main (Standard). Spieler-Modelle (Vorlauf, K Drehungen): careless (zufällige Drehungen, zufällig Regen/Meteor),
## greedy („falsch gierig“: wandelt so viel wie möglich um, aber nie Richtung Ziel), burn:<Art> (treibt eine Art der
## Ziel-Kette gegen 0). Nach K = 5, 15, 40, 100, 250 Drehungen übernimmt der gute Spieler: Er folgt der HUD-Zeile
## (GameState.next_action); nennt sie keine Drehung und kein Werkzeug, nimmt er die beste Drehung nach value8 (ein Zug
## voraus). (a) mit Sicherheitsnetz genau wie Game._rescue_check/take_gift, (b) ohne (bricht nach 3 × Par Schritten
## ohne neuen Höchststand ab: gescheitert). Grenze: 6 × Par Schritte. --hint=1: scheitert (b), spielt zusätzlich der
## echte Tipp (best_action) dieselbe Stellung (höchstens 2 je Level und Bot-Art); --hint=2: immer.
## --pick stellt eine Übergabe nach (gleiche --boards/--burn_boards wie im Lauf) und druckt jeden Schritt der Läufe.
## --mode=chain: Level n aus der Welt von n−1 (Campaign.carry + ensure) nach vier Spielstilen im Vorgänger.
## --mode=hud: nur die HUD-Zeile ab Pool-Brett und ab Pool-Brett + 5 Zufallsdrehungen (ohne Netz); scheitert sie: Tipp, Netz.
## --mode=norain: Pool-Brett ohne den Start-Regen. --mode=rainhud: Regen, wie die Zeile sagt, sonst zufällig drehen.
## Ausgabe: je eine JSON-Zeile ("t": snap | traj | chain | hud | norain | rainhud). Kleine Nachbauten einzelner Stände:
## tests/_audit_deadend_probe.gd.

const WIN_FACTOR := 6
const DANGER_EV = {"volcano": "erupt", "bolt": "bolt", "pack": "pack_hunt", "hunger": "starve", "smog": "polluted",
	"war": "war_hit", "flood": "flood", "glacier": "freeze"}

var _out: FileAccess = null
var _hint_mode := 0
var _ks: Array = [5, 15, 40, 100, 250]
var _n_snap := 0
var _n_run := 0
var _hint_left := {}
var _picks := {}          # "n:b:bot:res" → [K, …]: nur diese Übergaben (Nachstellen eines Falls, mit Tipp-Lauf und Protokoll)
var _trace := false


func _init() -> void:
	var lo := 1
	var hi := Campaign.COUNT
	var boards := 10
	var burn_boards := 3
	var part := 0
	var parts := 1
	var out_path := ""
	var mode := "main"
	var greedy_boards := 999
	var desc := false
	var bots := "careless,greedy,burn"
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--levels="):
			var p := s.substr(9).split("-")
			lo = int(p[0])
			hi = int(p[1]) if p.size() > 1 else lo
		elif s.begins_with("--boards="):
			boards = int(s.substr(9))
		elif s.begins_with("--burn_boards="):
			burn_boards = int(s.substr(14))
		elif s.begins_with("--greedy_boards="):
			greedy_boards = int(s.substr(16))
		elif s == "--desc":
			desc = true
		elif s.begins_with("--part="):
			var q := s.substr(7).split("/")
			part = int(q[0])
			parts = int(q[1])
		elif s.begins_with("--out="):
			out_path = s.substr(6)
		elif s.begins_with("--mode="):
			mode = s.substr(7)
		elif s.begins_with("--bots="):
			bots = s.substr(7)
		elif s.begins_with("--hint="):
			_hint_mode = int(s.substr(7))
		elif s.begins_with("--pick="):
			for item in s.substr(7).split(";"):
				var pp := item.split(":")
				if pp.size() >= 5:
					var pk := "%s:%s:%s:%s" % [pp[0], pp[1], pp[2], pp[3]]
					if not _picks.has(pk):
						_picks[pk] = []
					(_picks[pk] as Array).append(int(pp[4]))
			_trace = true
		elif s.begins_with("--ks="):
			_ks = []
			for x in s.substr(5).split(","):
				_ks.append(int(x))
	if out_path != "":
		_out = FileAccess.open(out_path, FileAccess.WRITE)
	var t0 := Time.get_ticks_msec()
	var order: Array = range(lo, hi + 1)
	if desc:
		order.reverse()
	for n in order:
		if posmod(n, parts) != part:
			continue
		var tl := Time.get_ticks_msec()
		if mode == "chain":
			_chain_level(n, boards)
		elif mode == "norain":
			_norain_level(n, boards)
		elif mode == "hud":
			_hud_level(n, boards)
		elif mode == "rainhud":
			_rainhud_level(n, boards)
		else:
			for bi in range(1, boards + 1):
				_run_board(n, bi, bots if bi <= greedy_boards else bots.replace("greedy", "g-"), bi <= burn_boards)
		print("L%d fertig: %d Übergaben, %d Läufe, %.1f s" % [n, _n_snap, _n_run, (Time.get_ticks_msec() - tl) / 1000.0])
	print("AUDIT-DONE %d Übergaben, %d Läufe, %.0f s" % [_n_snap, _n_run, (Time.get_ticks_msec() - t0) / 1000.0])
	if _out != null:
		_out.close()
	quit()


func _emit(d: Dictionary) -> void:
	if _out != null:
		_out.store_line(JSON.stringify(d))
		_out.flush()
	else:
		print(JSON.stringify(d))


func _tw(gs: GameState, m: Array) -> Dictionary:
	return gs.play({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])})


func _counts(gs: GameState) -> Dictionary:
	var c := {}
	for f in gs.fields:
		var key := str(f.kind)
		c[key] = int(c.get(key, 0)) + 1
	return c


## Arten der Ziel-Kette, die ein „Verbrenner“ gegen 0 treiben soll: alles, was das Level braucht (Ziel, Quellen,
## Bedürfnisse, Reihen) und am Start auf dem Brett liegt; dazu Wasser, wenn ein Bedürfnis oder der Regen es braucht.
func _resources(gs: GameState) -> Array:
	var keep := gs._kept_kinds9()
	var wet := false
	for k in gs.thrive9:
		if ((gs.thrive9[k] as Dictionary)["needs"] as Dictionary).has("wet"):
			wet = true
	for it in gs.rain9:
		if str((it as Array)[1]) == "shore":
			wet = true
	if wet:
		keep[FieldData.WATER] = true
	var out: Array = []
	for k2 in keep:
		if gs.count(int(k2)) > 0:
			out.append(int(k2))
	out.sort()
	return out


# --- Vorlauf: die drei Spieler-Modelle ------------------------------------------------------------------

func _tool_fields(gs: GameState, kind: String) -> Array:
	var opts: Array = []
	for f in gs.fields:
		if kind == "rain" and gs.rain_ok9(f):
			opts.append(f.id)
		elif kind == "meteor" and gs.meteor_ok9(f):
			opts.append(f.id)
	return opts


func _careless_step(gs: GameState, rng: RandomNumberGenerator, tools: bool = true) -> GameState:
	if tools and gs.rain > 0 and rng.randf() < 0.5:
		var opts := _tool_fields(gs, "rain")
		if not opts.is_empty():
			gs.play({"type": "rain", "field": int(opts[rng.randi_range(0, opts.size() - 1)])})
	if tools and not gs.day_won and gs.meteors > 0 and rng.randf() < 0.5:
		var opm := _tool_fields(gs, "meteor")
		if not opm.is_empty():
			gs.play({"type": "meteor", "field": int(opm[rng.randi_range(0, opm.size() - 1)])})
	if not gs.day_won:
		_tw(gs, GameState.MOVES[rng.randi_range(0, 26)])
	return gs


func _sample_moves(rng: RandomNumberGenerator, n: int) -> Array:
	var idx: Array = []
	for i in 27:
		idx.append(i)
	for i2 in range(26, 0, -1):
		var j := rng.randi_range(0, i2)
		var tmp: int = idx[i2]
		idx[i2] = idx[j]
		idx[j] = tmp
	return idx.slice(0, mini(n, 27))


## Führt eine Umwandlung von Art a zu Art b Richtung Ziel? (chain9: Schritte bis zur Ziel-Art)
func _goalward(gs: GameState, a: int, b: int) -> bool:
	if not gs.chain9.has(b):
		return false
	return not gs.chain9.has(a) or int(gs.chain9[b]) < int(gs.chain9[a])


func _greedy_step(gs: GameState, rng: RandomNumberGenerator, sample: int) -> GameState:
	# Werkzeuge: Regen/Meteor auf alles, was nicht Richtung Ziel führt
	for guard in 3:
		if gs.rain <= 0 or gs.day_won:
			break
		var opts: Array = []
		for f in gs.fields:
			if gs.rain_ok9(f) and not f.burning and f.id != gs.bolt:
				var nk := gs.rain_to9(f)
				if nk >= 0 and not _goalward(gs, f.kind, nk):
					opts.append(f.id)
		if opts.is_empty():
			break
		gs.play({"type": "rain", "field": int(opts[rng.randi_range(0, opts.size() - 1)])})
	if gs.meteors > 0 and not gs.day_won:
		var opm: Array = []
		for f2 in gs.fields:
			if gs.meteor_ok9(f2) and f2.kind != FieldData.EMPTY and not gs.goal_kinds9.has(f2.kind):
				opm.append(f2.id)
		if not opm.is_empty():
			var c0 := gs.clone()
			c0.play({"type": "meteor", "field": int(opm[rng.randi_range(0, opm.size() - 1)])})
			if not c0.day_won and c0.progress9() <= gs.progress9():
				gs = c0
	var p0 := gs.progress9()
	var best: GameState = null
	var best_v := -INF
	for mi in _sample_moves(rng, sample):
		var c := gs.clone()
		_tw(c, GameState.MOVES[int(mi)])
		var ch := 0
		for i in c.fields.size():
			if (c.fields[i] as FieldData).kind != (gs.fields[i] as FieldData).kind:
				ch += 1
		var v := float(ch) - 100.0 * float(maxi(0, c.progress9() - p0)) - (1000.0 if c.day_won else 0.0) + rng.randf() * 0.01
		if v > best_v:
			best_v = v
			best = c
	return best


## Felder der Art res, die ohne Zutun bald verschwinden (gewarnt, brennend, versorgt und wachsend, hungrig).
func _doomed(gs: GameState, res: int) -> float:
	var d := 0.0
	var rule: Variant = gs.thrive9.get(res)
	var threat := {}
	if gs.glac9 >= 0:
		for g in gs.glacier_threat9(gs.glac9):
			threat[int(g)] = true
	if gs.volc >= 0 and GameState.ERUPTS9.has(res):
		for m in gs.members9(gs.volc):
			for g2 in gs.nb9(int(m)):
				threat[int(g2)] = true
	for f in gs.fields:
		if f.kind != res:
			continue
		if f.burning or gs.pack_warn9.has(f.id) or gs.smog_warn9.has(f.id) or threat.has(f.id):
			d += 1.0
		elif rule != null:
			var rd: Dictionary = rule
			if gs.satt9(f.id):
				if int(rd["up"]) >= 0:
					d += 0.6
			elif int(rd["down"]) >= 0:
				d += 0.1 * float(maxi(0, f.hungry + 4))
	return d


func _burn_step(gs: GameState, rng: RandomNumberGenerator, res: int, sample: int) -> GameState:
	for guard in 3:
		if gs.rain <= 0 or gs.day_won:
			break
		var opts: Array = []
		for f in gs.fields:
			if f.kind == res and gs.rain_ok9(f) and not f.burning and f.id != gs.bolt and gs.rain_to9(f) >= 0:
				opts.append(f.id)
		if opts.is_empty():
			break
		var c0 := gs.clone()
		c0.play({"type": "rain", "field": int(opts[rng.randi_range(0, opts.size() - 1)])})
		if c0.day_won:
			break
		gs = c0
	if gs.meteors > 0 and res != FieldData.EMPTY and not gs.day_won:
		var opm: Array = []
		for f2 in gs.fields:
			if f2.kind == res and gs.meteor_ok9(f2):
				opm.append(f2.id)
		if not opm.is_empty():
			var c1 := gs.clone()
			c1.play({"type": "meteor", "field": int(opm[rng.randi_range(0, opm.size() - 1)])})
			if not c1.day_won:
				gs = c1
	var best: GameState = null
	var best_v := -INF
	for mi in _sample_moves(rng, sample):
		var c := gs.clone()
		_tw(c, GameState.MOVES[int(mi)])
		var v := -10.0 * float(c.count(res)) - 3.0 * _doomed(c, res) - (1000.0 if c.day_won else 0.0) + rng.randf() * 0.01
		if v > best_v:
			best_v = v
			best = c
	return best


func _run_board(n: int, bi: int, bots: String, with_burn: bool) -> void:
	var b := Campaign.board(n, bi)
	var base := Campaign.new_state(n, b)
	var list: Array = []
	if bots.contains("careless"):
		list.append(["careless", -1])
	if bots.contains("greedy"):
		list.append(["greedy", -1])
	if bots.contains("burn") and with_burn:
		for r in _resources(base):
			list.append(["burn", int(r)])
	for bot_i in list.size():
		var bot: Array = list[bot_i]
		if not _picks.is_empty() and not _picks.has("%d:%d:%s:%d" % [n, bi, str(bot[0]), int(bot[1])]):
			continue
		_trajectory(n, bi, base.clone(), str(bot[0]), int(bot[1]), n * 100003 + bi * 1009 + bot_i * 31 + int(bot[1]) + 7,
			{"how": "pool"})


## Ein Vorlauf: bis 250 Drehungen (oder Sieg), Übergaben bei K. Nebenbei: wann das Netz im echten Spiel gemeldet hätte
## (der Spieler lehnt ab und spielt weiter).
func _trajectory(n: int, bi: int, gs: GameState, bot: String, res: int, seed_value: int, extra: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var t0 := Time.get_ticks_msec()
	var kmax := 0
	for k in _ks:
		kmax = maxi(kmax, int(k))
	var won_at := -1
	var dead_first := -1
	var dead_steps := 0
	var stall_offers := 0
	var dead_offers := 0
	var net := {"dead_told": false, "told_at": -99}
	var min_res := gs.count(res) if res >= 0 else -1
	var last_dec := 0
	var cur_res := min_res
	for step in range(1, kmax + 1):
		if bot == "careless":
			gs = _careless_step(gs, rng)
		elif bot == "greedy":
			gs = _greedy_step(gs, rng, 12 if step <= 40 else (6 if step <= 100 else 3))
		else:
			if step - last_dec > 25 or cur_res == 0:
				gs = _careless_step(gs, rng, false)        # gesättigt: nur noch zufällig weiterdrehen
			else:
				gs = _burn_step(gs, rng, res, 8)
			var c := gs.count(res)
			if c < cur_res:
				last_dec = step
			cur_res = c
			min_res = mini(min_res, c)
		if gs.day_won:
			won_at = step
			break
		var why := gs.stuck9()
		if why == "dead":
			dead_steps += 1
			if dead_first < 0:
				dead_first = step
			if _trace:
				print("  TOT Schritt %d: reach9 %s, dead9 %s, Geschenk %s, Zeile „%s“, %s, Brett %s" % [step, str(gs.reach9()), str(gs.dead9()),
					str(gs.gift_plan9()), str(gs.next_action().get("text", "")), str(_counts(gs)), gs.slot_board9()])
		var off := _rescue_check(gs, net)
		if not off.is_empty():
			if str(off["why"]) == "dead":
				dead_offers += 1
			else:
				stall_offers += 1
		if _ks.has(step):
			var pkey := "%d:%d:%s:%d" % [n, bi, bot, res]
			if _picks.is_empty() or (_picks.has(pkey) and (_picks[pkey] as Array).has(step)):
				_snapshot(n, bi, gs.clone(), bot, res, step, seed_value, extra)
	var rec := {"t": "traj", "n": n, "b": bi, "bot": bot, "res": res, "seed": seed_value, "won_at": won_at,
		"dead_first": dead_first, "dead_steps": dead_steps, "dead_offers": dead_offers, "stall_offers": stall_offers,
		"min_res": min_res, "end_res": gs.count(res) if res >= 0 else -1, "ms": Time.get_ticks_msec() - t0}
	rec.merge(extra)
	_emit(rec)


# --- Das Sicherheitsnetz, wie Game es auslöst (Game._rescue_check, take_gift) -----------------------------

## {} = kein Angebot; sonst {"why", "gift"} (die Karte des Charakters käme jetzt).
func _rescue_check(gs: GameState, net: Dictionary) -> Dictionary:
	var why := gs.stuck9()
	if why != "dead":
		net["dead_told"] = false
	if why == "":
		return {}
	var s := gs.steps9()
	var fresh_dead := why == "dead" and not bool(net["dead_told"])
	if not fresh_dead and s - int(net["told_at"]) < GameState.STALL9:
		return {}
	if why == "dead":
		net["dead_told"] = true
	net["told_at"] = s
	return {"why": why, "gift": not gs.gift_plan9().is_empty()}


## Game.take_gift: {"changed": n, "desc": "15>16x3 …", "gain": Fortschritt +}
func _take_gift(gs: GameState, net: Dictionary) -> Dictionary:
	var plan := gs.gift_plan9()
	if plan.is_empty():
		return {}
	var p0 := gs.progress9()
	var s0 := gs._subs_sum9()
	var k0: Array = []
	for f in gs.fields:
		k0.append(f.kind)
	net["dead_told"] = false
	net["told_at"] = gs.steps9()
	gs.play({"type": "gift"})
	var agg := {}
	var ch := 0
	for f2 in gs.fields:
		if f2.kind != int(k0[f2.id]):
			ch += 1
			var key := "%d>%d" % [int(k0[f2.id]), f2.kind]
			agg[key] = int(agg.get(key, 0)) + 1
	var parts: Array = []
	for key2 in agg:
		parts.append("%sx%d" % [str(key2), int(agg[key2])])
	return {"changed": ch, "planned": (plan.get("changes", []) as Array).size(), "desc": " ".join(PackedStringArray(parts)),
		"gain": gs.progress9() - p0, "sum_gain": gs._subs_sum9() - s0, "held": int(plan.get("held", -1))}


# --- Der gute Spieler ---------------------------------------------------------------------------------------

## Beste der 27 Drehungen nach value8 (ein Zug voraus): der Ersatz, wenn die HUD-Zeile keine Drehung nennt.
func _lite_move(gs: GameState, rng: RandomNumberGenerator, sample: int = 27) -> Array:
	var best: Array = GameState.MOVES[0]
	var best_v := -INF
	for mi in _sample_moves(rng, sample):
		var m: Array = GameState.MOVES[int(mi)]
		var c := gs.clone()
		_tw(c, m)
		var v := c.value8() + (1e6 if c.day_won else 0.0) + rng.randf() * 0.001
		if gs.recent9.has(c.slot_board9()):
			v -= 1000.0
		if v > best_v:
			best_v = v
			best = m
	return best


## Stimmt, was die Zeile gesagt hat? "" = ja. a = die Zeile vor dem Zug, r = Ergebnis des Zugs, pre = Werte davor.
func _verify(gs: GameState, a: Dictionary, r: Dictionary, pre: Dictionary) -> String:
	var tp := str(a.get("type", ""))
	var types := {}
	for e in r.get("events", []):
		types[str((e as Dictionary)["type"])] = true
	if bool(r.get("refused", false)):
		return "Werkzeug abgelehnt"
	if tp == "row":
		var k0 := int(pre.get("k0", -1))
		for e2 in r.get("events", []):
			var ed: Dictionary = e2
			if (str(ed["type"]) == "merge" or str(ed["type"]) == "face") and int(ed.get("from", -2)) == k0:
				return ""
		return "keine Reihe"
	if tp == "thrive":
		var fid := int(pre.get("f0", -1))
		if fid < 0:
			return ""
		var fc: FieldData = gs.fields[fid]
		if fc.kind != int(pre.get("k0", -1)) or gs.satt9(fid) or fc.fed > 0:
			return ""
		for e3 in r.get("events", []):
			if str((e3 as Dictionary)["type"]) == "need_sealed" and int((e3 as Dictionary)["field"]) == fid:
				return ""
		return "nicht versorgt"
	if tp == "group":
		return "" if gs._subs_sum9() > int(pre["sum"]) or gs.day_won or int(pre.get("big", 0)) < int(pre.get("big_now", 0)) else "Gruppe nicht größer"
	if tp == "grow":
		return "" if gs._subs_sum9() > int(pre["sum"]) or gs.day_won else "kein Fortschritt"
	if tp == "danger":
		var bad := str(DANGER_EV.get(str(a.get("danger", "")), "?"))
		return "Gefahr trat ein" if types.has(bad) else ""
	if tp == "rain":
		var want := int(a.get("result", -1))
		if want >= 0 and not types.has("rain"):
			return "Regen ohne Wirkung"
		return ""
	return ""


## Spielt ab hier bis zum Sieg oder bis WIN_FACTOR × Par Schritte um sind. guide: "hud" (Zeile, sonst beste Drehung)
## oder "hint" (immer best_action). net: mit Sicherheitsnetz wie im Spiel.
func _good_run(gs: GameState, with_net: bool, guide: String, seed_value: int) -> Dictionary:
	_n_run += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var s0 := gs.steps9()
	var limit := WIN_FACTOR * gs.par9
	var net := {"dead_told": false, "told_at": -99}
	var gifts := 0
	var offers := 0
	var nogift := 0
	var first_offer := -1
	var first_why := ""
	var g_max := 0
	var g_sum := 0
	var g_desc := ""
	var g_nogain := 0
	var nomove := 0
	var viol: Array = []
	var n_viol := 0
	var texts := {}
	var idle := 0
	var acts := 0
	var lites := 0
	var peak := gs.progress9() + gs._subs_sum9()
	var peak_at := s0
	var cut := false
	var seen := {gs.slot_board9(): true}     # Stellungen dieses Laufs: kehrt der Spieler in eine zurück (Hin und Her)?
	var revisit := 0
	var revisit_hud := 0                       # … und die Zeile hatte die Drehung dazu selbst genannt
	var t0 := Time.get_ticks_msec()
	if with_net:
		var off0 := _rescue_check(gs, net)
		if not off0.is_empty():
			offers += 1
			first_offer = 0
			first_why = str(off0["why"])
			if bool(off0["gift"]):
				var g0 := _take_gift(gs, net)
				gifts += 1
				g_max = maxi(g_max, int(g0["changed"]))
				g_sum += int(g0["changed"])
				g_desc = str(g0["desc"])
				if int(g0["sum_gain"]) <= 0 and int(g0["held"]) < 0:
					g_nogain += 1
			else:
				nogift += 1
	while not gs.day_won and gs.steps9() - s0 < limit and acts < limit * 6:
		acts += 1
		var a: Dictionary = {}
		var r: Dictionary = {}
		var pre := {"sum": gs._subs_sum9()}
		var step_before := gs.steps9()
		if guide == "hint":
			a = gs.best_action()
			if a.is_empty() or (str(a.get("type", "")) != "twist" and idle >= 4):
				r = _tw(gs, GameState.MOVES[rng.randi_range(0, 26)])
			else:
				r = gs.play(a)
		else:
			a = gs.next_action()
			var tp := str(a.get("type", ""))
			var txt := str(a.get("text", ""))
			var mv: Dictionary = a.get("move", {})
			var fl: Array = a.get("fields", [])
			if not fl.is_empty():
				pre["f0"] = int(fl[0])
				pre["k0"] = (gs.fields[int(fl[0])] as FieldData).kind
			if tp == "group":
				for sd in gs.goal9:
					if str((sd as Dictionary)["type"]) == "group":
						pre["gk"] = int((sd as Dictionary)["kind"])
						pre["big"] = gs.biggest9(int((sd as Dictionary)["kind"]))
			if tp == "help" and with_net and idle < 4:
				var gh := _take_gift(gs, net)
				if gh.is_empty():
					n_viol += 1
					if viol.size() < 3:
						viol.append([gs.steps9() - s0, txt, "Hilfe ohne Geschenk"])
					lites += 1
					r = _tw(gs, _lite_move(gs, rng, 27 if lites <= 4 else 9))
				else:
					gifts += 1
					g_max = maxi(g_max, int(gh["changed"]))
					g_sum += int(gh["changed"])
					if g_desc == "":
						g_desc = str(gh["desc"])
					if int(gh["sum_gain"]) <= 0 and int(gh["held"]) < 0:
						g_nogain += 1
					idle += 1
					continue
			elif not mv.is_empty():
				r = _tw(gs, [int(mv["axis"]), int(mv["layer"]), int(mv["turns"])])
			elif str(a.get("tool", "")) == "rain" and int(a.get("field", -1)) >= 0 and idle < 4:
				r = gs.play({"type": "rain", "field": int(a["field"])})
			elif str(a.get("tool", "")) == "meteor" and int(a.get("field", -1)) >= 0 and idle < 4:
				r = gs.play({"type": "meteor", "field": int(a["field"])})
			else:
				nomove += 1
				texts[txt] = int(texts.get(txt, 0)) + 1
				lites += 1
				r = _tw(gs, _lite_move(gs, rng, 27 if lites <= 4 else 9))
				a = {}
			if pre.has("gk"):
				pre["big_now"] = gs.biggest9(int(pre["gk"]))
			if not a.is_empty():
				var why := _verify(gs, a, r, pre)
				if why != "":
					n_viol += 1
					if viol.size() < 3:
						viol.append([step_before - s0, txt, why])
		idle = idle + 1 if gs.steps9() == step_before else 0
		var pk := gs.progress9() + gs._subs_sum9()
		if pk > peak:
			peak = pk
			peak_at = gs.steps9()
		elif not with_net and gs.steps9() - peak_at >= 3 * gs.par9:
			cut = true          # ohne Netz: 3 × Par Schritte ohne neuen Höchststand – das wird nichts mehr (zählt als gescheitert)
			break
		if gs.steps9() != step_before:
			var bs := gs.slot_board9()
			if seen.has(bs):
				revisit += 1
				if not (a.get("move", {}) as Dictionary).is_empty():
					revisit_hud += 1
			seen[bs] = true
		if _trace:
			var evs: Array = []
			for e in r.get("events", []):
				var et := str((e as Dictionary)["type"])
				if not ["miss", "repeat", "still", "goal", "era", "need_sealed", "satt_new", "satt_lost"].has(et):
					evs.append(et)
			print("    [%s%s] Schritt %d: „%s“ (%s%s) → %d/%d, Regen %d, %s" % [guide, "+Netz" if with_net else "", step_before - s0,
				str(a.get("text", a.get("type", "–"))), str(a.get("type", "ersatz")), ", Scheibe" if not (a.get("move", {}) as Dictionary).is_empty() else "",
				gs.progress9(), gs.target9(), gs.rain, str(evs)])
		if with_net and not gs.day_won:
			var off := _rescue_check(gs, net)
			if not off.is_empty():
				offers += 1
				if first_offer < 0:
					first_offer = gs.steps9() - s0
					first_why = str(off["why"])
				if bool(off["gift"]):
					var g1 := _take_gift(gs, net)
					gifts += 1
					g_max = maxi(g_max, int(g1["changed"]))
					g_sum += int(g1["changed"])
					if g_desc == "":
						g_desc = str(g1["desc"])
					if int(g1["sum_gain"]) <= 0 and int(g1["held"]) < 0:
						g_nogain += 1
				else:
					nogift += 1
	var top: Array = []
	for tx in texts:
		top.append([int(texts[tx]), str(tx)])
	top.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) > int(y[0]))
	return {"won": gs.day_won, "steps": gs.steps9() - s0, "gifts": gifts, "offers": offers, "nogift": nogift,
		"first_offer": first_offer, "first_why": first_why, "g_max": g_max, "g_sum": g_sum, "g_desc": g_desc,
		"g_nogain": g_nogain, "nomove": nomove, "cut": cut, "revisit": revisit, "revisit_hud": revisit_hud, "n_viol": n_viol, "viol": viol, "texts": top.slice(0, 3),
		"prog": gs.progress9(), "reach": bool(gs.reach9()["ok"]), "ms": Time.get_ticks_msec() - t0}


## Die HUD-Zeile an der Übergabe: konkret? möglich? (auf einer Kopie gespielt)
func _check_action(gs: GameState) -> Dictionary:
	var a := gs.next_action()
	var tp := str(a.get("type", ""))
	var mv: Dictionary = a.get("move", {})
	var tl := str(a.get("tool", ""))
	var concrete := not mv.is_empty() or (tl != "" and (tl == "gift" or int(a.get("field", -1)) >= 0))
	var why := ""
	if tp == "help":
		why = "" if not gs.gift_plan9().is_empty() else "Hilfe ohne Geschenk"
	elif concrete:
		var c := gs.clone()
		var pre := {"sum": gs._subs_sum9()}
		var fl: Array = a.get("fields", [])
		if not fl.is_empty():
			pre["f0"] = int(fl[0])
			pre["k0"] = (gs.fields[int(fl[0])] as FieldData).kind
		if tp == "group":
			for sd in gs.goal9:
				if str((sd as Dictionary)["type"]) == "group":
					pre["gk"] = int((sd as Dictionary)["kind"])
					pre["big"] = gs.biggest9(int((sd as Dictionary)["kind"]))
		var r: Dictionary = {}
		if not mv.is_empty():
			r = _tw(c, [int(mv["axis"]), int(mv["layer"]), int(mv["turns"])])
		else:
			r = c.play({"type": tl, "field": int(a["field"])})
		if pre.has("gk"):
			pre["big_now"] = c.biggest9(int(pre["gk"]))
		why = _verify(c, a, r, pre)
	elif tp == "goal" and str(a.get("text", "")).begins_with("Bring 3 "):
		# „Bring 3 X in eine Reihe“: geht das noch in zwei Drehungen? (sonst ist die Zeile nur ein Wunsch)
		why = "allgemein"
	else:
		why = "allgemein"
	return {"type": tp, "text": str(a.get("text", "")), "concrete": concrete, "why": why}


func _snapshot(n: int, bi: int, gs: GameState, bot: String, res: int, k: int, seed_value: int, extra: Dictionary) -> void:
	_n_snap += 1
	var r := gs.reach9()
	var rec := {"t": "snap", "n": n, "b": bi, "bot": bot, "res": res, "K": k, "seed": seed_value, "cnt": _counts(gs),
		"reach": bool(r["ok"]), "rwhy": str(r.get("why", "")), "rkind": int(r.get("kind", -1)), "stuck": gs.stuck9(),
		"dead9": gs.dead9(), "prog": gs.progress9(), "tgt": gs.target9(), "steps": gs.steps9(), "rain": gs.rain,
		"meteors": gs.meteors, "gift": not gs.gift_plan9().is_empty(), "na": _check_action(gs),
		"board": gs.slot_board9()}
	rec.merge(extra)
	var ra := _good_run(gs.clone(), true, "hud", seed_value + k)
	rec["A"] = ra
	var rb: Dictionary = ra
	if int(ra["gifts"]) > 0 or int(ra["offers"]) > 0:
		rb = _good_run(gs.clone(), false, "hud", seed_value + k)
		rec["B"] = rb
	else:
		rec["B"] = "=A"
	var key := "%d|%s" % [n, bot]
	if _trace:
		print("PICK L%d Brett %d %s %d K=%d: %s | reach %s | Zeile „%s“ | Brett %s" % [n, bi, bot, res, k, str(rec["cnt"]), str(r),
			str((rec["na"] as Dictionary)["text"]), str(rec["board"])])
	if _hint_mode == 2 or not _picks.is_empty() or (_hint_mode == 1 and not bool(rb["won"]) and int(_hint_left.get(key, 2)) > 0):
		_hint_left[key] = int(_hint_left.get(key, 2)) - 1
		var rh := _good_run(gs.clone(), false, "hint", seed_value + k)
		rec["H"] = {"won": rh["won"], "steps": rh["steps"], "prog": rh["prog"], "ms": rh["ms"]}
	_emit(rec)


# --- Ketten: die Welt von gestern (Campaign.carry + ensure) -------------------------------------------------

## Level n aus der Welt von n−1 (wie Game._level_start_board/start_level): Vorgänger auf Pool-Brett mit einem
## Spieler-Stil bis zum Sieg (mit Netz), dann carry + ensure; am Start von n: Zählung, reach9, und der Vorlauf wie oben.
func _chain_level(n: int, chains: int) -> void:
	if n <= 1 or Campaign.first_of_act(n):
		return
	for ch in chains:
		var rng := RandomNumberGenerator.new()
		rng.seed = n * 7919 + ch * 13 + 5
		var style: String = ["good", "careless", "greedy", "burn"][ch % 4]
		var prev := Campaign.new_state(n - 1, Campaign.board(n - 1, 1 + ch))
		# „Verbrenner“: die Art, die Level n am meisten braucht (die erste seiner Ressourcen, die es in n−1 gibt)
		var res := -1
		if style == "burn":
			var nxt := Campaign.new_state(n, Campaign.board(n, 1))
			for rk in _resources(nxt):
				if prev.count(int(rk)) > 0:
					res = int(rk)
					break
			if res < 0:
				style = "greedy"
		var net := {"dead_told": false, "told_at": -99}
		var pre_steps := 0
		var gifts := 0
		while not prev.day_won and pre_steps < 400:
			pre_steps += 1
			if style == "good" or pre_steps > 60:
				var a := prev.next_action()
				var mv: Dictionary = a.get("move", {})
				if str(a.get("type", "")) == "help":
					_take_gift(prev, net)
					gifts += 1
				elif not mv.is_empty():
					_tw(prev, [int(mv["axis"]), int(mv["layer"]), int(mv["turns"])])
				elif str(a.get("tool", "")) == "rain" and int(a.get("field", -1)) >= 0:
					prev.play({"type": "rain", "field": int(a["field"])})
				else:
					_tw(prev, _lite_move(prev, rng))
			elif style == "careless":
				prev = _careless_step(prev, rng)
			elif style == "greedy":
				prev = _greedy_step(prev, rng, 9)
			else:
				prev = _burn_step(prev, rng, res, 8)
			if not prev.day_won:
				var off := _rescue_check(prev, net)
				if not off.is_empty() and bool(off["gift"]) and (style == "good" or pre_steps > 60):
					_take_gift(prev, net)
					gifts += 1
		var world := prev.slot_board9()
		var wc := _counts(prev)
		var b := Campaign.carry(Campaign.decode(world), n, ch + 1000 * n + 1, ch)
		var how0 := str(b.get("how", ""))
		b["kinds"] = Campaign.decode(Campaign.encode(b["kinds"]))
		b = Campaign.ensure(n, b, ch)
		var gs := Campaign.new_state(n, b)
		var r := gs.reach9()
		var rec := {"t": "chain", "n": n, "ch": ch, "style": style, "res": res, "prev_won": prev.day_won, "prev_steps": pre_steps,
			"prev_gifts": gifts, "world": world, "world_cnt": wc, "how0": how0, "how": str(b.get("how", "")),
			"line": str(b.get("line", "")), "fixes": (b.get("fixes", []) as Array).size(),
			"changed": (b.get("changed", []) as Array).size(), "cnt": _counts(gs), "reach": bool(r["ok"]),
			"lines": gs.lines().size(), "board": gs.slot_board9(), "na": _check_action(gs)}
		_emit(rec)
		var extra := {"how": str(b.get("how", "")), "ch": ch}
		_snapshot(n, -1 - ch, gs.clone(), "start", -1, 0, n * 31 + ch, extra)
		_trajectory(n, -1 - ch, gs.clone(), "careless", -1, n * 100003 + ch * 17 + 3, extra)


# --- Regen verbraucht („schon vorausgespielt“): Level, in denen eine Art der Kette nur durch Regen entsteht ----------

## Pool-Brett, aber der Start-Regen ist schon weg (auf etwas anderes getippt). Wie lange braucht der gute Spieler,
## was sagt die Zeile, während er auf Regen wartet? Vergleich: derselbe Lauf mit dem Regen des Levels.
func _norain_level(n: int, boards: int) -> void:
	for bi in range(1, boards + 1):
		var base := Campaign.new_state(n, Campaign.board(n, bi))
		var r0 := _good_run(base.clone(), false, "hud", n * 131 + bi)
		var dry := base.clone()
		dry.rain = 0
		var r1 := _good_run(dry.clone(), false, "hud", n * 131 + bi)
		var r2 := _good_run(dry.clone(), true, "hud", n * 131 + bi)
		_emit({"t": "norain", "n": n, "b": bi, "base": {"won": r0["won"], "steps": r0["steps"], "nomove": r0["nomove"], "texts": r0["texts"]},
			"dry": {"won": r1["won"], "steps": r1["steps"], "nomove": r1["nomove"], "texts": r1["texts"], "revisit": r1["revisit"]},
			"dry_net": {"won": r2["won"], "steps": r2["steps"], "gifts": r2["gifts"], "first_offer": r2["first_offer"], "g_desc": r2["g_desc"]}})


# --- Nur die HUD-Zeile: führt sie zum Sieg, wenn man ihr genau folgt? (ohne Netz, ohne Vorlauf-Tricks) ---------------

## Pool-Brett (K0 = 0) und dasselbe nach 5 zufälligen Drehungen (K0 = 5): der Spieler tut genau, was oben steht.
## Gemessen: gewonnen in 6 × Par? Rückkehr in eine frühere Stellung durch eine Drehung, die die Zeile selbst genannt
## hat (revisit_hud: Hin und Her)? Scheitert er, spielt der echte Tipp dieselbe Stellung.
func _hud_level(n: int, boards: int) -> void:
	for bi in range(1, boards + 1):
		for k0 in [0, 5]:
			var gs := Campaign.new_state(n, Campaign.board(n, bi))
			var rng := RandomNumberGenerator.new()
			rng.seed = n * 977 + bi * 13 + k0
			for i in k0:
				if not gs.day_won:
					_tw(gs, GameState.MOVES[rng.randi_range(0, 26)])
			if gs.day_won:
				continue
			var r := _good_run(gs.clone(), false, "hud", n * 977 + bi)
			var rec := {"t": "hud", "n": n, "b": bi, "K0": k0, "won": r["won"], "steps": r["steps"], "revisit": r["revisit"],
				"revisit_hud": r["revisit_hud"], "nomove": r["nomove"], "cut": r["cut"], "texts": r["texts"], "n_viol": r["n_viol"],
				"viol": r["viol"], "prog": r["prog"], "tgt": gs.target9(), "board": gs.slot_board9()}
			if not bool(r["won"]):
				var rh := _good_run(gs.clone(), false, "hint", n * 977 + bi)
				rec["H"] = {"won": rh["won"], "steps": rh["steps"]}
				var rn := _good_run(gs.clone(), true, "hud", n * 977 + bi)
				rec["A"] = {"won": rn["won"], "steps": rn["steps"], "gifts": rn["gifts"], "first_offer": rn["first_offer"], "g_desc": rn["g_desc"]}
			_emit(rec)


# --- „Regen, wie die Zeile sagt, sonst irgendwie drehen“: geht das Wasser aus? ------------------------------------

## Der Spieler tippt jeden Regen dorthin, wo die Zeile es sagt („Gieß Wasser mit Regen“), dreht aber zufällig, und nimmt
## kein Geschenk. Bis 200 Drehungen oder Sieg. Gemessen: wie viel Wasser bleibt (kleinster Stand), ab wann es kein
## Wasser mehr gibt, auf das Regen wirkt, und ob der gute Spieler von dort noch gewinnt (mit/ohne Netz).
func _rainhud_level(n: int, boards: int) -> void:
	for bi in range(1, boards + 1):
		var gs := Campaign.new_state(n, Campaign.board(n, bi))
		var rng := RandomNumberGenerator.new()
		rng.seed = n * 733 + bi * 7
		var w0 := gs.count(FieldData.WATER)
		var w_min := w0
		var zero_at := -1
		var noshore_at := -1
		var rains := 0
		var snap_done := false
		var rec := {"t": "rainhud", "n": n, "b": bi, "w0": w0}
		for step in range(1, 201):
			for guard in 4:
				var a := gs.next_action()
				if str(a.get("tool", "")) != "rain" or int(a.get("field", -1)) < 0 or gs.day_won:
					break
				gs.play({"type": "rain", "field": int(a["field"])})
				rains += 1
			if gs.day_won:
				break
			_tw(gs, GameState.MOVES[rng.randi_range(0, 26)])
			if gs.day_won:
				break
			var w := gs.count(FieldData.WATER)
			w_min = mini(w_min, w)
			var shore := 0
			for f in gs.fields:
				if f.kind == FieldData.WATER and gs.rain_to9(f) >= 0:
					shore += 1
			if w == 0 and zero_at < 0:
				zero_at = step
			if shore == 0 and noshore_at < 0:
				noshore_at = step
			if (w == 0 or shore == 0) and not snap_done:
				snap_done = true
				var ra := _good_run(gs.clone(), true, "hud", n + bi)
				var rb := _good_run(gs.clone(), false, "hud", n + bi)
				rec["at"] = {"step": step, "cnt": _counts(gs), "prog": gs.progress9(), "tgt": gs.target9(), "reach": bool(gs.reach9()["ok"]),
					"na": str(gs.next_action().get("text", "")), "A": {"won": ra["won"], "steps": ra["steps"], "gifts": ra["gifts"], "g_desc": ra["g_desc"]},
					"B": {"won": rb["won"], "steps": rb["steps"], "texts": rb["texts"]}, "board": gs.slot_board9()}
		rec.merge({"won": gs.day_won, "steps": gs.steps9(), "rains": rains, "w_min": w_min, "w_end": gs.count(FieldData.WATER),
			"zero_at": zero_at, "noshore_at": noshore_at, "mercy": int(gs.st9.get("mercy", 0))})
		_emit(rec)
