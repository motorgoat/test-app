extends SceneTree
## Audit „logic“ (nur Messung, kein CI-Test): Ist die Kampagne logisch aufgebaut?
##   godot --headless --script res://tests/_audit_logic.gd -- mode=night|over|rain|reach|play [from=2 to=60 boards=5]
## night: je Übergang n−1 → n (gleiches Zeitalter): die Welt am Sieg (Pool-Lösung) gegen das Start-Brett von Campaign.carry.
##        need = Felder, die die Mischung mindestens ändern muss; changed = wirklich geändert; strict = dasselbe mit einer
##        Reparatur, die nur echte Verbesserungen annimmt (Kopie von Campaign.repair, nur hier); lost_goal = Ziel-Felder
##        von gestern, die über Nacht eine andere Art haben; unfed = gestern satt, heute nicht mehr.
## over:  Level 6/7: ein Spieler, der weiter Erde macht (Reihen aus Fels, Regen auf Fels – das Ziel von Level 4/5).
## rain:  Level 5–9: ein Spieler, der die ersten W Regen auf Fels gießt (wie in Level 5 gelernt), sonst der Zeile folgt.
## reach: Stände, in denen einer Ziel-Kette die Quelle fehlt: was sagen reach9, dead9, stuck9, die Zeile, das Geschenk?
## play:  Zeile-folgen auf Pool-Brettern gegen übernommene Welten (Schritte bis zum Sieg, Geschenke).

var args := {}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := str(a).split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var mode := str(args.get("mode", "night"))
	if mode == "night":
		_night()
	elif mode == "over":
		_over()
	elif mode == "rain":
		_rain()
	elif mode == "reach":
		_reach()
	elif mode == "play":
		_play()
	elif mode == "shore":
		_shore()
	elif mode == "hud":
		_hud()
	elif mode == "filler":
		_filler()
	elif mode == "rainuse":
		_rainuse()
	elif mode == "whatif":
		_whatif()
	elif mode == "rows1":
		_rows1()
	quit()


func _cnt(kinds: Array) -> Dictionary:
	var c := {}
	for k in kinds:
		c[int(k)] = int(c.get(int(k), 0)) + 1
	return c


func _cnt_gs(gs: GameState) -> Dictionary:
	var c := {}
	for f in gs.fields:
		c[f.kind] = int(c.get(f.kind, 0)) + 1
	return c


func _names(c: Dictionary) -> String:
	var keys: Array = c.keys()
	keys.sort()
	var s := ""
	for k in keys:
		s += "%s %d, " % [FieldData.kind_name(int(k)), int(c[k])]
	return s


## Die Welt am Sieg von Level n auf Pool-Brett i (geprüfte Lösung). Gibt [GameState, Welt (54 Arten nach Plätzen)].
func _won_world(n: int, i: int) -> Array:
	var b := Campaign.board(n, i)
	var gs := Campaign.new_state(n, b)
	for st in (b["solution"] as Array):
		if gs.day_won:
			break
		var ab: Array = Days.solution_step(st)
		gs.play(ab[0], ab[1])
	return [gs, Campaign.decode(gs.slot_board9())]


## Wie Campaign.repair, aber nur echte Verbesserungen (kein Annehmen gleich guter Täusche). [kinds, Rest].
func _repair_strict(n: int, kinds: Array, rng: RandomNumberGenerator, iters: int = 3000) -> Array:
	var k := kinds.duplicate()
	var cur := Campaign.violation(n, k, false, true)
	var by_type := {3: [], 2: [], 1: []}
	var ref := GameState.new()
	ref.setup_level(Campaign.config(n), k, 1)
	for f in ref.fields:
		(by_type[FieldData.sticker_type(f.p)] as Array).append(f.id)
	var pick := [3, 3, 2, 2, 1]
	for it in iters:
		if cur == 0:
			break
		var t: int = pick[rng.randi_range(0, 4)]
		var ids: Array = by_type[t]
		var a: int = ids[rng.randi_range(0, ids.size() - 1)]
		var b: int = ids[rng.randi_range(0, ids.size() - 1)]
		if a == b or int(k[a]) == int(k[b]):
			continue
		var tmp: int = k[a]
		k[a] = k[b]
		k[b] = tmp
		var v := Campaign.violation(n, k, false, true)
		if v < cur:
			cur = v
		else:
			k[b] = k[a]
			k[a] = tmp
	return [k, cur]


## Die ersten Schritte von Campaign.carry (über Nacht wachsen, zurückziehen, Mischung) ohne Reparatur: [kinds, viol].
func _carry_mix(prev: Array, n: int, seed_value: int) -> Array:
	var c := Campaign.config(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7777 + n
	var k: Array = []
	for x in prev:
		k.append(int(x))
	for pair in c.get("overnight", []):
		var pa: Array = pair
		for i in k.size():
			if int(k[i]) == int(pa[0]):
				k[i] = int(pa[1])
	var comp: Dictionary = c.get("comp", {})
	var want := {}
	var total := 0
	for key in comp:
		want[int(str(key))] = int(comp[key])
		total += int(comp[key])
	want[FieldData.WATER] = 54 - total
	var allowed := want.duplicate()
	for i in k.size():
		k[i] = Campaign.retire(int(k[i]), allowed)
	var ref := GameState.new()
	ref.setup_level(c, k, 1)
	var nbs := ref._nbs9()
	for guard in 54:
		var cnt := _cnt(k)
		var short := -1
		var short_n := 0
		var kinds_sorted: Array = want.keys()
		kinds_sorted.sort()
		kinds_sorted.reverse()
		for d in kinds_sorted:
			var miss := int(want[d]) - int(cnt.get(d, 0))
			if miss > short_n:
				short_n = miss
				short = int(d)
		if short < 0:
			break
		var best_f := -1
		var best_v := -1.0
		for f in k.size():
			var kf := int(k[f])
			if int(cnt.get(kf, 0)) <= int(want.get(kf, 0)):
				continue
			var nn := 0
			for g in nbs[f]:
				if int(k[g]) == short:
					nn += 1
			var v := float(nn) + rng.randf() * 0.5
			if v > best_v:
				best_v = v
				best_f = f
		if best_f < 0:
			break
		k[best_f] = short
	return [k, Campaign.violation(n, k, false, true), rng]


func _diff(a: Array, b: Array) -> int:
	var d := 0
	for j in 54:
		if int(a[j]) != int(b[j]):
			d += 1
	return d


func _night() -> void:
	var from := int(args.get("from", 2))
	var to := int(args.get("to", Campaign.COUNT))
	var boards := int(args.get("boards", 5))
	var t_need := 0
	var t_mix := 0
	var t_ch := 0
	var t_strict := 0
	var t_n := 0
	for n in range(from, to + 1):
		if Campaign.first_of_era(n):
			continue
		var s_need := 0
		var s_mix := 0
		var s_ch := 0
		var s_strict := 0
		var s_strict_fail := 0
		var s_lost := 0
		var s_goal := 0
		var s_unfed := 0
		var s_fed := 0
		var s_viol := 0
		var runs := 0
		var fb := 0
		var gk := -1
		var pg: Array = Campaign.config(n - 1).get("goal", [])
		if not pg.is_empty() and str((pg[0] as Array)[0]) != "hold":
			var g1: Variant = (pg[0] as Array)[1]
			gk = int((g1 as Array)[0]) if g1 is Array else int(g1)
		for i in range(1, boards + 1):
			var ww := _won_world(n - 1, i)
			var gs: GameState = ww[0]
			var world: Array = ww[1]
			var fed_slots := {}
			for f in gs.fields:
				if gs.thrive9.has(f.kind) and gs.satt9(f.id):
					fed_slots[gs.slot9(f)] = f.kind
			var c := Campaign.carry(world, n, 1000 * n + 1, 0)
			if str(c["how"]) != "carry":
				fb += 1
				continue
			runs += 1
			var kinds: Array = c["kinds"]
			var mix := _carry_mix(world, n, 1000 * n + 1)
			var mk: Array = mix[0]
			# Mindest-Änderung allein aus der Mischung: Summe der fehlenden Felder je Art
			var want := _cnt(kinds)
			var have := _cnt(world)
			var need := 0
			for k in want:
				need += maxi(0, int(want[k]) - int(have.get(k, 0)))
			s_need += need
			s_mix += _diff(world, mk)
			s_viol += int(mix[1])
			s_ch += _diff(world, kinds)
			var rs := _repair_strict(n, mk, mix[2])
			if int(rs[1]) == 0:
				s_strict += _diff(world, rs[0])
			else:
				s_strict_fail += 1
				s_strict += _diff(world, kinds)
			if gk >= 0:
				for j in 54:
					if int(world[j]) == gk:
						s_goal += 1
						if int(kinds[j]) != gk:
							s_lost += 1
			# gestern satt → heute (gleicher Platz, gleiche Art) noch satt?
			var g2 := GameState.new()
			g2.setup_level(Campaign.config(n), kinds, 1)
			for f2 in g2.fields:
				var sl := g2.slot9(f2)
				if fed_slots.has(sl):
					s_fed += 1
					if f2.kind != int(fed_slots[sl]) or not g2.thrive9.has(f2.kind) or not g2.satt9(f2.id):
						s_unfed += 1
		if runs == 0:
			print("NIGHT2 %d->%d never carried (fallback %d)" % [n - 1, n, fb])
			continue
		var r := float(runs)
		t_need += s_need
		t_mix += s_mix
		t_ch += s_ch
		t_strict += s_strict
		t_n += runs
		print("NIGHT2 %d->%d need %.1f mix %.1f (viol %.1f) changed %.1f strict %.1f (fail %d) | goal '%s' fields %.1f lost %.1f | fed %.1f unfed %.1f | fallback %d/%d | satt_max %d" % [
			n - 1, n, s_need / r, s_mix / r, s_viol / r, s_ch / r, s_strict / r, s_strict_fail,
			FieldData.kind_name(gk) if gk >= 0 else "-", s_goal / r, s_lost / r, s_fed / r, s_unfed / r, fb, runs + fb,
			int(Campaign.config(n).get("satt_max", 0))])
	print("NIGHT2 total starts %d: need %.1f, after mix %.1f, changed %.1f, strict repair %.1f of 54" % [t_n,
		float(t_need) / maxi(1, t_n), float(t_mix) / maxi(1, t_n), float(t_ch) / maxi(1, t_n), float(t_strict) / maxi(1, t_n)])


## Der Zeile oben folgen (next_action). gift: das Sicherheitsnetz annehmen wie Game._rescue_check (dead sofort, stall alle
## STALL9 Schritte). Gibt {"won", "steps", "gifts", "rand", "lines"} zurück.
func _follow(gs: GameState, rng: RandomNumberGenerator, max_steps: int, gift: bool, log_lines: bool = false) -> Dictionary:
	var gifts := 0
	var rand_moves := 0
	var acts := 0
	var told_at := -99
	var lines := {}
	var s0 := gs.steps9()
	while not gs.day_won and gs.steps9() - s0 < max_steps and acts < max_steps * 4:
		acts += 1
		var a: Dictionary = gs.next_action()
		if log_lines:
			var ln := str(a.get("line", ""))
			lines[ln] = int(lines.get(ln, 0)) + 1
		var why := gs.stuck9()
		if gift and why != "" and not gs.gift_plan9().is_empty() and (why == "dead" or gs.steps9() - told_at >= GameState.STALL9):
			told_at = gs.steps9()
			gs.play({"type": "gift"})
			gifts += 1
			continue
		if str(a.get("tool", "")) == "rain" and int(a.get("field", -1)) >= 0:
			gs.play({"type": "rain", "field": int(a["field"])})
		elif str(a.get("tool", "")) == "meteor" and int(a.get("field", -1)) >= 0:
			gs.play({"type": "meteor", "field": int(a["field"])})
		elif str(a.get("tool", "")) == "gift":
			if gift and not gs.gift_plan9().is_empty():
				gs.play({"type": "gift"})
				gifts += 1
			else:
				var m0: Array = GameState.MOVES[rng.randi_range(0, 26)]
				gs.play({"type": "twist", "axis": int(m0[0]), "layer": int(m0[1]), "turns": int(m0[2])})
				rand_moves += 1
		elif not (a.get("move", {}) as Dictionary).is_empty():
			var mv: Dictionary = a["move"]
			gs.play({"type": "twist", "axis": int(mv["axis"]), "layer": int(mv["layer"]), "turns": int(mv["turns"])})
		else:
			var m: Array = GameState.MOVES[rng.randi_range(0, 26)]
			gs.play({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])})
			rand_moves += 1
	return {"won": gs.day_won, "steps": gs.steps9(), "gifts": gifts, "rand": rand_moves, "lines": lines}


func _state_line(gs: GameState) -> String:
	var a: Dictionary = gs.next_action()
	return "reach=%s dead9=%s stuck='%s' HUD[%s] '%s' hint '%s' gift=%s" % [str(gs.reach9()), str(gs.dead9()), gs.stuck9(),
		str(a.get("type", "")), str(a.get("line", "")), str(a.get("hint", "")), str(not gs.gift_plan9().is_empty())]


## Level 6/7: weiter Erde machen (was Level 4 und 5 belohnt haben). K Drehungen lang die Drehung mit den meisten neuen
## Erd-Feldern (sonst zufällig), jeder Regen auf einen Fels. Danach folgt der Spieler der Zeile.
func _over() -> void:
	for n in [6, 7]:
		for i in range(1, int(args.get("boards", 5)) + 1):
			for kk in [10, 20, 40]:
				var gs := Campaign.new_state(n, Campaign.board(n, i))
				var rng := RandomNumberGenerator.new()
				rng.seed = n * 100 + i
				var fels0 := gs.count(FieldData.STONE)
				var st := 0
				while st < int(kk) and not gs.day_won:
					if gs.rain > 0:
						for f in gs.fields:
							if f.kind == FieldData.STONE and gs.rain_ok9(f):
								gs.play({"type": "rain", "field": f.id})
								break
					var best_m: Array = []
					var best_g := 0
					var e0 := gs.count(FieldData.EMPTY)
					for m in GameState.MOVES:
						var c := gs.clone()
						c.play({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])})
						if c.day_won:
							continue
						var gain := c.count(FieldData.EMPTY) - e0
						if gain > best_g:
							best_g = gain
							best_m = m
					if best_m.is_empty():
						best_m = GameState.MOVES[rng.randi_range(0, 26)]
					gs.play({"type": "twist", "axis": int(best_m[0]), "layer": int(best_m[1]), "turns": int(best_m[2])})
					st += 1
				var mid := "after %d steps: Fels %d→%d Erde %d Lava %d Wasser %d Ursuppe %d/%d won=%s | %s" % [gs.steps9(), fels0,
					gs.count(FieldData.STONE), gs.count(FieldData.EMPTY), gs.count(FieldData.LAVA), gs.count(FieldData.WATER),
					gs.progress9(), gs.target9(), str(gs.day_won), _state_line(gs)]
				var s1 := gs.steps9()
				var r := _follow(gs, rng, 80, true)
				print("OVER n=%d board=%d K=%d %s || then follow+net: won=%s +%d steps gifts=%d rand=%d" % [n, i, int(kk), mid,
					str(r["won"]), int(r["steps"]) - s1, int(r["gifts"]), int(r["rand"])])


## Level 5–9: die ersten W Regen gehen auf einen Fels (in Level 5 gelernt: „Tipp Regen, dann einen Fels“).
func _rain() -> void:
	for n in [6, 7, 8, 9]:
		for w in [0, 1, 2, 3]:
			var steps: Array = []
			var gifts := 0
			var wins := 0
			var waits := 0
			var lines := {}
			for i in range(1, int(args.get("boards", 6)) + 1):
				var gs := Campaign.new_state(n, Campaign.board(n, i))
				var rng := RandomNumberGenerator.new()
				rng.seed = n * 100 + i
				var wasted := 0
				var acts := 0
				var told_at := -99
				while not gs.day_won and gs.steps9() < 80 and acts < 400:
					acts += 1
					if wasted < int(w) and gs.rain > 0:
						var done := false
						for f in gs.fields:
							if f.kind == FieldData.STONE and gs.rain_ok9(f):
								gs.play({"type": "rain", "field": f.id})
								wasted += 1
								done = true
								break
						if done:
							continue
					var a: Dictionary = gs.next_action()
					var ln := "%s|%s" % [str(a.get("type", "")), str(a.get("text", ""))]
					lines[ln] = int(lines.get(ln, 0)) + 1
					if str(a.get("text", "")).begins_with("Dreh weiter, Regen"):
						waits += 1
					var why := gs.stuck9()
					if why != "" and not gs.gift_plan9().is_empty() and (why == "dead" or gs.steps9() - told_at >= GameState.STALL9):
						told_at = gs.steps9()
						gs.play({"type": "gift"})
						gifts += 1
						continue
					if str(a.get("tool", "")) == "rain" and int(a.get("field", -1)) >= 0:
						gs.play({"type": "rain", "field": int(a["field"])})
					elif not (a.get("move", {}) as Dictionary).is_empty():
						var mv: Dictionary = a["move"]
						gs.play({"type": "twist", "axis": int(mv["axis"]), "layer": int(mv["layer"]), "turns": int(mv["turns"])})
					else:
						var m: Array = GameState.MOVES[rng.randi_range(0, 26)]
						gs.play({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])})
				steps.append(gs.steps9())
				if gs.day_won:
					wins += 1
			steps.sort()
			var top: Array = []
			for ln2 in lines:
				top.append([int(lines[ln2]), ln2])
			top.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) > int(y[0]))
			print("RAIN n=%d wasted_first=%d: won %d/%d steps %s (stars %s) gifts %d 'Dreh weiter, Regen kommt' shown %d× | lines %s" % [n, int(w), wins,
				steps.size(), str(steps), str(Campaign.stars_of(n)), gifts, waits, str(top.slice(0, 5))])


func _set_all(gs: GameState, from: int, to: int, keep: int = 0) -> void:
	var left := keep
	for f in gs.fields:
		if f.kind == from:
			if left > 0:
				left -= 1
			else:
				gs._setk9(f, to)
	gs._grp_ok = false
	gs._act_seq += 1


## Stände, in denen der Ziel-Kette eine Quelle fehlt (nur Arten getauscht, sonst das Pool-Brett 1).
func _reach() -> void:
	# [Level, von, zu, behalten, Text]
	var cases := [
		[6, FieldData.STONE, FieldData.EMPTY, 0, "L6 kein Fels mehr (alle zu Erde gemacht): Wasser bekommt nie 'mineral'"],
		[7, FieldData.STONE, FieldData.EMPTY, 0, "L7 kein Fels mehr"],
		[6, FieldData.LAVA, FieldData.STONE, 1, "L6 nur 1 Lava (heat 2 nie): geht im Spiel nicht, nur als Probe"],
		[8, FieldData.LAVA, FieldData.STONE, 1, "L8 nur 1 Lava (Ursuppe braucht heat 2): Probe"],
		[9, FieldData.SOUP, FieldData.CELLS, 0, "L9 alle Ursuppe schon Einzeller (nicht gezählt), Regen 0"],
		[13, FieldData.STONE, FieldData.EMPTY, 1, "L13 nur 1 Fels (Qualle braucht 2 Fels): Probe"],
		[18, FieldData.ALGAE, FieldData.WATER, 0, "L18 keine Algen (Erde braucht 2 Algen; Reihen und Regen gehen noch)"],
		[24, FieldData.FOREST, FieldData.MOSS, 0, "L24 kein Wald (Farn braucht 2 Wald)"],
		[30, FieldData.FISH, FieldData.WATER, 0, "L30 keine Fische (Wald braucht 2 Fische; Quallen-Reihen gehen noch)"],
		[43, FieldData.FOREST, FieldData.MEADOW, 0, "L43 kein Wald (Tiere brauchen 2 Wald)"],
		[46, FieldData.STONE, FieldData.MEADOW, 0, "L46 kein Fels (Frühmensch braucht Fels + Wald)"],
		[42, FieldData.ICE, FieldData.WATER, 0, "L42 alles Eis getaut (Coach: 'Eis nach oben drehen'); Mammut braucht Kälte"],
		[47, FieldData.CAMP, FieldData.MEADOW, 0, "L47 keine Feuerstelle: Probe"],
		[26, FieldData.INSECTS, FieldData.MOSS, 0, "L26 keine Insekten: Probe"],
	]
	for cs in cases:
		var n := int(cs[0])
		var gs := Campaign.new_state(n, Campaign.board(n, 1))
		_set_all(gs, int(cs[1]), int(cs[2]), int(cs[3]))
		if n == 9:
			gs.rain = 0
		print("REACH %s\n      %s\n      %s" % [str(cs[4]), _names(_cnt_gs(gs)), _state_line(gs)])
		var rng := RandomNumberGenerator.new()
		rng.seed = n
		var r := _follow(gs, rng, 80, true)
		print("      follow+net: won=%s steps=%d gifts=%d rand=%d" % [str(r["won"]), int(r["steps"]), int(r["gifts"]), int(r["rand"])])


## Zeile-folgen: Pool-Bretter gegen übernommene Welten (carry aus der Sieg-Welt des Levels davor).
func _play() -> void:
	var from := int(args.get("from", 2))
	var to := int(args.get("to", Campaign.COUNT))
	var boards := int(args.get("boards", 4))
	for n in range(from, to + 1):
		if Campaign.first_of_era(n):
			continue
		var ps: Array = []
		var cs: Array = []
		var pg := 0
		var cg := 0
		var pw := 0
		var cw := 0
		for i in range(1, boards + 1):
			var rng := RandomNumberGenerator.new()
			rng.seed = n * 100 + i
			var gp := Campaign.new_state(n, Campaign.board(n, i))
			var rp := _follow(gp, rng, 60, true)
			ps.append(int(rp["steps"]))
			pg += int(rp["gifts"])
			pw += 1 if bool(rp["won"]) else 0
			var ww := _won_world(n - 1, i)
			var c := Campaign.carry(ww[1], n, 1000 * n + 1 + i, 0)
			c["board"] = Campaign.encode(c["kinds"])
			c = Campaign.ensure(n, c, 0)
			if str(c["how"]) != "carry":
				continue
			var gc := GameState.new()
			gc.setup_level(Campaign.config(n), c["kinds"], int(c["seed"]))
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = n * 100 + i
			var rc := _follow(gc, rng2, 60, true)
			cs.append(int(rc["steps"]))
			cg += int(rc["gifts"])
			cw += 1 if bool(rc["won"]) else 0
		ps.sort()
		cs.sort()
		print("PLAY n=%d stars %s | pool: won %d/%d steps %s gifts %d | carried: won %d/%d steps %s gifts %d" % [n,
			str(Campaign.stars_of(n)), pw, ps.size(), str(ps), pg, cw, cs.size(), str(cs), cg])


## Level 6–14 und 41/42: Regen wirkt auf Wasser nur am Ufer. Wie viele Wasser-Felder sind am Start gießbar, und wie
## wenige werden es, wenn man nur dreht (40 zufällige Drehungen auf einer Kopie ohne Regeln: nur die Plätze)?
func _shore() -> void:
	for n in [6, 7, 8, 9, 10, 11, 12, 13, 14, 41, 42]:
		var w_min := 99
		var r_min := 99
		var r_sum := 0
		var walk_min := 99
		var zero := 0
		var cnt := 0
		for i in Campaign.pool_size(n):
			var gs := Campaign.new_state(n, Campaign.board(n, i))
			var r := _rainable(gs)
			w_min = mini(w_min, gs.count(FieldData.WATER))
			r_min = mini(r_min, r)
			r_sum += r
			cnt += 1
			var rng := RandomNumberGenerator.new()
			rng.seed = n * 1000 + i
			for st in 40:
				var m: Array = GameState.MOVES[rng.randi_range(0, 26)]
				gs._rot9(int(m[0]), int(m[1]), int(m[2]))
				var r2 := _rainable(gs)
				walk_min = mini(walk_min, r2)
				if r2 == 0:
					zero += 1
		print("SHORE n=%d: water at start min %d | rainable water at start min %d avg %.1f | min over 40 random twists %d | positions with 0 rainable: %d of %d" % [n,
			w_min, r_min, float(r_sum) / cnt, walk_min, zero, cnt * 40])


func _rainable(gs: GameState) -> int:
	var c := 0
	var r := gs.rain
	gs.rain = 1
	for f in gs.fields:
		if f.kind == FieldData.WATER and gs.rain_ok9(f):
			c += 1
	gs.rain = r
	return c


## Je Level (Pool-Brett 1, Start): Werkzeuge sichtbar (tool_unlocked), Regen-Vorrat, die Zeile oben und das Rezept
## darunter – nennt die Zeile das echte Rezept des Levels?
func _hud() -> void:
	for n in range(1, Campaign.COUNT + 1):
		var gs := Campaign.new_state(n, Campaign.board(n, 1))
		var a: Dictionary = gs.next_action()
		var c := Campaign.config(n)
		print("HUD n=%d '%s' | rain tool shown=%s rain=%d every=%d meteor shown=%s | chip '%s' | line[%s] '%s' | hint '%s' | new %s | coach '%s'" % [n,
			str(c.get("title", "")), str(gs.tool_unlocked("rain")), gs.rain, gs.rain_every, str(gs.tool_unlocked("strike")),
			str(c.get("goal_line", "")), str(a.get("type", "")), str(a.get("line", "")), str(a.get("hint", "")), str(c.get("new", [])),
			str(c.get("coach", ""))])


## Womit bezahlt das Sicherheitsnetz (top_up9, Geschenk)? Stände, in denen der Stoff knapp ist (Arten getauscht):
## welche Arten werden überschrieben, wie viel Wasser bleibt (Level, in denen Wasser kühlt/wässert: „wet“).
func _filler() -> void:
	# [Level, knappe Art, wird zu, behalten]
	var cases := [[2, FieldData.LAVA, FieldData.STONE, 3], [3, FieldData.LAVA, FieldData.STONE, 3],
		[4, FieldData.STONE, FieldData.WATER, 2], [5, FieldData.STONE, FieldData.WATER, 0],
		[20, FieldData.MOSS, FieldData.MEADOW, 0], [22, FieldData.FERN, FieldData.FOREST, 0],
		[50, FieldData.MEADOW, FieldData.FOREST, 0]]
	for cs in cases:
		var n := int(cs[0])
		var gs := Campaign.new_state(n, Campaign.board(n, 1))
		_set_all(gs, int(cs[1]), int(cs[2]), int(cs[3]))
		if n == 5:
			_set_all(gs, FieldData.LAVA, FieldData.WATER, 0)
		if n == 20:
			_set_all(gs, FieldData.EMPTY, FieldData.MEADOW, 0)
		if n == 22:
			_set_all(gs, FieldData.MOSS, FieldData.FOREST, 0)
		if n == 50:
			_set_all(gs, FieldData.EMPTY, FieldData.FOREST, 0)
			_set_all(gs, FieldData.SEED, FieldData.FOREST, 0)
		var w0 := gs.count(FieldData.WATER)
		var before := _names(_cnt_gs(gs))
		var r0 := gs.reach9()
		var c := gs.clone()
		var top := c.top_up9(Campaign.TOPUP_MAX)
		var from := {}
		for t in top:
			var k0: int = (gs.fields[int((t as Array)[0])] as FieldData).kind
			from[FieldData.kind_name(k0)] = int(from.get(FieldData.kind_name(k0), 0)) + 1
		var c2 := gs.clone()
		var gifts := 0
		var gfrom := {}
		while gifts < 6 and not c2.day_won:
			var plan: Dictionary = c2.gift_plan9()
			if plan.is_empty():
				break
			for ch in plan.get("changes", []):
				var k1: int = (c2.fields[int((ch as Array)[0])] as FieldData).kind
				gfrom[FieldData.kind_name(k1)] = int(gfrom.get(FieldData.kind_name(k1), 0)) + 1
			c2.play({"type": "gift"})
			gifts += 1
		print("FILLER n=%d %s | reach %s | top_up9(6) overwrote %s → water %d→%d | %d gifts overwrote %s → water %d→%d (progress %d/%d)" % [n, before,
			str(r0), str(from), w0, c.count(FieldData.WATER), gifts, str(gfrom), w0, c2.count(FieldData.WATER), c2.progress9(), c2.target9()])


## Welche Regen-Zeilen benutzen die geprüften Pool-Lösungen wirklich (von → zu), und wie viele Reihen je Art?
func _rainuse() -> void:
	for n in range(1, Campaign.COUNT + 1):
		var use := {}
		var rows := {}
		var thr := {}
		for i in Campaign.pool_size(n):
			var b := Campaign.board(n, i)
			var gs := Campaign.new_state(n, b)
			for st in (b["solution"] as Array):
				if gs.day_won:
					break
				var ab: Array = Days.solution_step(st)
				var act: Dictionary = ab[0]
				var k0 := -1
				if str(act["type"]) != "twist":
					k0 = (gs.fields[int(act["field"])] as FieldData).kind
				var res: Dictionary = gs.play(act, ab[1])
				if k0 >= 0:
					var key := "%s→%s" % [FieldData.kind_name(k0), FieldData.kind_name((gs.fields[int(act["field"])] as FieldData).kind)]
					use[key] = int(use.get(key, 0)) + 1
				for e in res.get("events", []):
					var ed: Dictionary = e
					if str(ed.get("type", "")) == "merge":
						var rk := "%s→%s" % [FieldData.kind_name(int(ed.get("from", -1))), FieldData.kind_name(int(ed.get("kind", -1)))]
						rows[rk] = int(rows.get(rk, 0)) + 1
					elif str(ed.get("type", "")) == "thrive":
						var tk := "%s→%s" % [FieldData.kind_name(int(ed.get("from", -1))), FieldData.kind_name(int(ed.get("kind", -1)))]
						thr[tk] = int(thr.get(tk, 0)) + 1
		var table: Array = []
		for it in Campaign.config(n).get("rain", []):
			table.append("%s→%s" % [FieldData.kind_name(int((it as Array)[0])), FieldData.kind_name(int((it as Array)[2]))])
		print("USE n=%d rain table %s | used by 20 solutions: rain %s | rows %s | thrive %s" % [n, str(table), str(use), str(rows), str(thr)])


## Was wäre, wenn (nur hier, die Daten bleiben): Varianten der Level 8 und 9 – Zeile-folgen auf 10 Pool-Brettern,
## einmal sauber, einmal mit 2 „voraus“ verbrauchten Regen (auf Fels, wo das geht; sonst verfallen sie).
func _variant(n: int, v: String) -> Dictionary:
	var c := Campaign.config(n)
	if v == "no_fels_rain" or v == "both" or v == "all3":
		var r2: Array = []
		for it in c.get("rain", []):
			if int((it as Array)[0]) != FieldData.STONE:
				r2.append(it)
		c["rain"] = r2
	if v == "rain2" or v == "both" or v == "all3":
		c["rain_start"] = 2
	if v == "water_thrive" or v == "all3":
		var th: Dictionary = c["thrive"]
		th[str(FieldData.WATER)] = {"needs": {"heat": 2, "mineral": 1}, "up": FieldData.SOUP, "down": null, "G": null, "spawn": null}
	return c


func _whatif() -> void:
	for n in [8, 9]:
		for v in ["base", "no_fels_rain", "rain2", "both", "water_thrive", "all3"]:
			for w in [0, 2]:
				var steps: Array = []
				var waits := 0
				var gifts := 0
				var wins := 0
				var sol_ok := 0
				for i in range(1, 11):
					var b := Campaign.board(n, i)
					var cfg := _variant(n, str(v))
					var gs := GameState.new()
					gs.setup_level(cfg, b["kinds"], int(b["seed"]))
					var rng := RandomNumberGenerator.new()
					rng.seed = n * 100 + i
					var wasted := 0
					var acts := 0
					var told_at := -99
					while not gs.day_won and gs.steps9() < 80 and acts < 400:
						acts += 1
						if wasted < int(w) and gs.rain > 0:
							var done := false
							for f in gs.fields:
								if f.kind == FieldData.STONE and gs.rain_ok9(f):
									gs.play({"type": "rain", "field": f.id})
									done = true
									break
							if not done:
								gs.rain -= 1            # kein Fels-Regen in dieser Variante: die Ladung verfällt (schlimmster Fall)
								gs._act_seq += 1
							wasted += 1
							continue
						var a: Dictionary = gs.next_action()
						if str(a.get("text", "")).begins_with("Dreh weiter, Regen"):
							waits += 1
						var why := gs.stuck9()
						if why != "" and not gs.gift_plan9().is_empty() and (why == "dead" or gs.steps9() - told_at >= GameState.STALL9):
							told_at = gs.steps9()
							gs.play({"type": "gift"})
							gifts += 1
							continue
						if str(a.get("tool", "")) == "rain" and int(a.get("field", -1)) >= 0:
							gs.play({"type": "rain", "field": int(a["field"])})
						elif not (a.get("move", {}) as Dictionary).is_empty():
							var mv: Dictionary = a["move"]
							gs.play({"type": "twist", "axis": int(mv["axis"]), "layer": int(mv["layer"]), "turns": int(mv["turns"])})
						else:
							var m: Array = GameState.MOVES[rng.randi_range(0, 26)]
							gs.play({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])})
					steps.append(gs.steps9())
					if gs.day_won:
						wins += 1
					# gilt die gespeicherte Lösung noch?
					var g2 := GameState.new()
					g2.setup_level(_variant(n, str(v)), b["kinds"], int(b["seed"]))
					for st in (b["solution"] as Array):
						if g2.day_won:
							break
						var ab: Array = Days.solution_step(st)
						var act: Dictionary = ab[0]
						if str(act["type"]) != "twist" and not g2.rain_ok9(g2.fields[int(act["field"])]):
							continue
						g2.play(act, ab[1])
					if g2.day_won and g2.steps9() <= int(b["solved_in"]):
						sol_ok += 1
				steps.sort()
				print("WHATIF n=%d %-13s wasted=%d: won %d/10 steps %s gifts %d 'Regen kommt' %d× | stored solutions still win in ≤ solved_in: %d/10" % [n,
					str(v), int(w), wins, str(steps), gifts, waits, sol_ok])


## Level 1/10/12/15: nur noch Felder der Reihen-Art auf Ecken (keine Kante: keine gerade Reihe möglich). Was sagt reach9?
## In Level 1 steht Lava auch in der Regen-Tabelle (Regen kommt dort aber nie): zählt jede Lava als Nachschub?
func _rows1() -> void:
	for n in [1, 4, 10, 12, 15, 27]:
		var gs := Campaign.new_state(n, Campaign.board(n, 1))
		var rk := -1
		var best := 99
		for k in gs.rows9:
			if gs.chain9.has(int(k)) and int(gs.chain9[int(k)]) < best:
				best = int(gs.chain9[int(k)])
				rk = int(k)
		var other := FieldData.WATER if n != 1 else FieldData.STONE
		var kept := 0
		for f in gs.fields:
			if f.kind == rk:
				if FieldData.sticker_type(f.p) == 3 and kept < 6:
					kept += 1
				else:
					gs._setk9(f, other)
		gs._grp_ok = false
		gs._act_seq += 1
		gs.rain = 0
		var rng := RandomNumberGenerator.new()
		rng.seed = n
		var line := _state_line(gs)
		var r := _follow(gs, rng, 60, true)
		print("ROWS1 n=%d: only %d %s left, all on corners (no straight row possible), rain 0 (every %d)\n      %s\n      follow+net: won=%s steps=%d gifts=%d rand=%d" % [n, kept,
			FieldData.kind_name(rk), gs.rain_every, line, str(r["won"]), int(r["steps"]), int(r["gifts"]), int(r["rand"])])
