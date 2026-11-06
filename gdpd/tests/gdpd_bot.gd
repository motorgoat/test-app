extends RefCounted
## Bot für die Regeltests (Port des Validierungs-Bots aus der Spec, gdpd_sim/bot.py).
## Jeder Zug: alle 27 Drehungen (+ Blitz, Monsun, Strafen bei viel Stadt) durchspielen, bei einer Karte je nach
## Strategie antworten. "eval" spielt beide Antworten durch (wie der Tipp), "nature" nimmt immer Option 1,
## "civ" immer Option 2, "random" zufällig. Wächst nichts: Zwei-Zug-Suche, dann Gewitter zum Platzmachen.

const POT := 1.5          # Wert eines Paars (Reihe einen Schritt entfernt)
const WAR_RISK := 4.0
const RAIN_PLANT_AT := 2

static var _lines_cache: Array = []


## Alle Reihen (gerade und schräg) als [Positionen [[p, n], ...], schräg].
static func _line_slots() -> Array:
	if not _lines_cache.is_empty():
		return _lines_cache
	for nv in GameState.FACE_NORMALS:
		var nn: Vector3i = nv
		var a := GameState.axis_of(nn)
		var u := (a + 1) % 3
		var v := (a + 2) % 3
		for fixed in [u, v]:
			var run: int = v if fixed == u else u
			for c in [-1, 0, 1]:
				var ln: Array = []
				for t in [-1, 0, 1]:
					var p := Vector3i.ZERO
					p[a] = nn[a]
					p[fixed] = c
					p[run] = t
					ln.append([p, nn])
				_lines_cache.append([ln, false])
		for dir in [1, -1]:
			var dl: Array = []
			for t in [-1, 0, 1]:
				var p := Vector3i.ZERO
				p[a] = nn[a]
				p[u] = t
				p[v] = t * dir
				dl.append([p, nn])
			_lines_cache.append([dl, true])
	return _lines_cache


## Reihen, denen genau ein Feld fehlt (zwei gleiche, die eine Reihe bilden können, und ein anderes).
static func pairs(g: GameState) -> int:
	var c := 0
	for item in _line_slots():
		if bool(item[1]) and not g.diagonals:
			continue
		var ln: Array = item[0]
		var a: int = g.field_at(ln[0][0], ln[0][1]).kind
		var b: int = g.field_at(ln[1][0], ln[1][1]).kind
		var d: int = g.field_at(ln[2][0], ln[2][1]).kind
		if a == b and g.can_row(a) and d != a:
			c += 1
		elif a == d and g.can_row(a) and b != a:
			c += 1
		elif b == d and g.can_row(b) and a != b:
			c += 1
	return c


static func heuristic(g: GameState) -> float:
	var ip := float(g.income_potential())
	if g.balance() >= Balance.SMOG_AT:
		return -6.0 * float(g.count(FieldData.INDUSTRY)) - 0.5 * ip
	var ch := g.count(FieldData.CHURCH)
	return ip + 0.5 * float(g.people_count()) - WAR_RISK * float(maxi(0, ch - 3))


static func value(before: GameState, after: GameState) -> float:
	var v := float(after.faith - before.faith)
	v -= 60.0 * float(before.lives - after.lives)
	for f in after.fields:
		if (f as FieldData).burning:
			v -= 3.0
	if after.died():
		v -= 10000.0
	return v + heuristic(after) + POT * float(pairs(after))


static func policy(strat: String, card: int, g: GameState, rng: RandomNumberGenerator) -> int:
	if strat == "nature":
		return 0
	if strat == "civ":
		return 1
	if strat == "random":
		return rng.randi_range(0, 1)
	return 0


## Spielt eine Aktion mit der Antwort der Strategie. [Wert, Stand danach]
static func run_option(base: GameState, action: Dictionary, strat: String, rng: RandomNumberGenerator, look: bool = false) -> Array:
	var a := base.simulate(action)
	var sa: GameState = a["state"]
	var card := sa.card
	if card < 0:
		return [value(base, sa), sa]
	if strat == "eval":
		var v1 := value(base, sa) + (0.5 * float(sa.next_gain()) if look else 0.0)
		var h := base.habit(card)
		var sb: GameState = base.simulate(action, {card: 1 - h})["state"]
		var v2 := value(base, sb) + (0.5 * float(sb.next_gain()) if look else 0.0)
		if is_equal_approx(v1, v2):
			return [v2, sb] if rng.randf() < 0.5 else [v1, sa]
		return [v2, sb] if v2 > v1 else [v1, sa]
	var i := policy(strat, card, base, rng)
	if i == base.habit(card):
		return [value(base, sa), sa]
	var s2: GameState = base.simulate(action, {card: i})["state"]
	return [value(base, s2), s2]


static func _twist(m: Array) -> Dictionary:
	return {"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])}


static func two_step(g: GameState, rng: RandomNumberGenerator) -> Array:
	return g.two_step_move()[0]


static func do_rain(g: GameState, strat: String, rng: RandomNumberGenerator) -> GameState:
	for guard in 4:
		if g.rain <= 0:
			break
		var best_v := -INF
		var best_s: GameState = null
		var spots := g.rain_spots()
		for fid in spots:
			var r := run_option(g, {"type": "rain", "field": int(fid)}, strat, rng)
			var v: float = float(r[0]) - POT * float(pairs(g))
			if (g.fields[int(fid)] as FieldData).burning:
				v += 8.0
			if v > best_v:
				best_v = v
				best_s = r[1]
		if best_s != null and best_v >= 2.0:
			g = best_s
			continue
		if g.rain >= RAIN_PLANT_AT:
			var p0 := pairs(g)
			var bd := -INF
			var bs: GameState = null
			for f in g.fields:
				var fd: FieldData = f
				if not GameState.RAIN_NEXT.has(fd.kind) and not fd.burning:
					continue
				var s: GameState = g.simulate({"type": "rain", "field": fd.id})["state"]
				var d := float(pairs(s) - p0 + (s.faith - g.faith)) + rng.randf() * 0.01
				if d > bd:
					bd = d
					bs = s
			if bs != null and bd > 0.0:
				g = bs
				continue
		break
	return g


## Ein Zug des Bots. Gibt den Stand danach zurück.
static func step(g: GameState, strat: String, rng: RandomNumberGenerator, allow_tools: bool) -> GameState:
	g = do_rain(g, strat, rng)
	var cands: Array = []     # [Wert, Stand, Aktion oder {}]
	var grew := false
	for m in GameState.MOVES:
		var act := _twist(m)
		var r := run_option(g, act, strat, rng)
		if (r[1] as GameState).last_grew > 0:
			grew = true
		cands.append([float(r[0]) + rng.randf() * 0.01, r[1], act])
	if not grew:
		var m2 := two_step(g, rng)
		if not m2.is_empty():
			var act2 := _twist(m2)
			var r2 := run_option(g, act2, strat, rng)
			cands.append([float(r2[0]) + 1000.0, r2[1], act2])
		elif allow_tools and g.faith >= Balance.STRIKE_COST:
			var bn := 0
			var bs: GameState = null
			for f in g.fields:
				var fd: FieldData = f
				if fd.kind == FieldData.EMPTY:
					continue
				var s: GameState = g.simulate({"type": "strike", "field": fd.id})["state"]
				var ng := s.next_gain()
				if ng > bn:
					bn = ng
					bs = s
			if bs != null:
				cands.append([2000.0, bs, {}])
	if allow_tools:
		if g.bolts > 0:
			for f in g.fields:
				if not g.corner_diagonal(f).is_empty():
					var rb := run_option(g, {"type": "bolt", "field": (f as FieldData).id}, strat, rng)
					cands.append([float(rb[0]) - 4.0, rb[1], {}])
		if g.monsoons > 0:
			for nv in GameState.FACE_NORMALS:
				var nn: Vector3i = nv
				var rm := run_option(g, {"type": "monsoon", "field": g.field_at(nn, nn).id}, strat, rng)
				cands.append([float(rm[0]) - 6.0, rm[1], {}])
		if g.count(FieldData.INDUSTRY) > 0 and g.balance() >= Balance.SMOG_AT - 10:
			if g.faith >= Balance.STRIKE_COST:
				for f in g.fields:
					if (f as FieldData).kind == FieldData.INDUSTRY:
						var rs := run_option(g, {"type": "strike", "field": (f as FieldData).id}, strat, rng)
						cands.append([float(rs[0]), rs[1], {}])
			if g.faith >= Balance.FLOOD_COST:
				for nv in GameState.FACE_NORMALS:
					var nn: Vector3i = nv
					var has := false
					for h in g.face_fields(nn):
						if (h as FieldData).kind == FieldData.INDUSTRY:
							has = true
					if has:
						var rf := run_option(g, {"type": "flood", "field": g.field_at(nn, nn).id}, strat, rng)
						cands.append([float(rf[0]), rf[1], {}])
	var best: Array = cands[0]
	for c in cands:
		if float(c[0]) > float(best[0]):
			best = c
	var bact: Dictionary = best[2]
	if strat == "eval" and not bact.is_empty() and (best[1] as GameState).card >= 0:
		return run_option(g, bact, strat, rng, true)[1]
	return best[1]


## Ein ganzes Spiel. level 0..2, endless false = Challenge (40 Drehungen, Mittel).
static func play(seed_value: int, level: int, strat: String, endless: bool = true, cap: int = 300) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + level
	var g := GameState.new()
	g.setup(seed_value, endless, level)
	var tool_turns := 0
	var guard := 0
	while not g.is_over() and g.twists < cap and guard < cap * 4:
		guard += 1
		var t0 := g.twists
		g = step(g, strat, rng, tool_turns < 2)
		if g.twists > t0:
			tool_turns = 0
		else:
			tool_turns += 1
	var reached := {}
	for k in g.ever:
		reached[int(k)] = true
	return {"twists": g.twists, "faith": g.faith, "earned": g.faith_earned, "completed": g.completed, "dead": g.died(),
		"stats": g.stats.duplicate(), "ever": reached, "age": g.age_name(), "finished": g.finished_count()}
