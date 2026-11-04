class_name GameState
extends RefCounted
## Reine Spiellogik, getrennt von der Darstellung. Kopierbar (clone) für die Vorschau.
##
## Vier Feldarten mit je 3 Stufen:
##   Natur (Wiese mit See → Fluss → Urwald), Siedlung (Dorf → Stadt → Metropole),
##   Industrie (Werkstatt → Fabrik → Industriegebiet), Glaube (Kapelle → Kirche → Kathedrale).
## Dazu Berge, Krater und die 6 festen Mitten (Wahrzeichen, drehen sich nie).
##
## Eine Runde = eine Drehung (oder Warten). Auswertung:
##   1. Gefahren schlagen ein, Vulkane brechen aus, Feuer brennt
##   2. Gleiche Felder nebeneinander → nach ein paar Runden Stufe höher
##      Fehlt ein Bedürfnis (Siedlung braucht Natur, Industrie und Glaube brauchen Siedlung) → Stufe tiefer
##      Krieg (Kirchen fremder Völker nebeneinander) und Verschmutzung (Fabrik neben Natur) → Stufe tiefer
##   3. Stufe 3 breitet sich aus (Natur verschluckt Dörfer, Städte und Industrie fressen Natur)
##   4. Glaube: Punkte für Paare × Gleichgewicht, Handel zwischen Städten, Verlust durch Katastrophen

const KINDS = ["nature", "settlement", "industry", "faith"]
const KIND_NAME = {"nature": "Natur", "settlement": "Siedlung", "industry": "Industrie", "faith": "Glaube",
	"mountain": "Berg", "crater": "Krater", "center": "Wahrzeichen"}
const LEVEL_NAME = {
	"nature": ["", "Wiese mit See", "Fluss", "Urwald"],
	"settlement": ["", "Dorf", "Stadt", "Metropole"],
	"industry": ["", "Werkstatt", "Fabrik", "Industriegebiet"],
	"faith": ["", "Kapelle", "Kirche", "Kathedrale"],
}
const NATION_NAMES = ["Rote", "Blaue", "Gelbe", "Grüne"]
const NATION_GENITIVE = ["Roten", "Blauen", "Gelben", "Grünen"]
const NATION_COLORS = ["#ec5b4f", "#3f86e8", "#f4b72e", "#46b46c"]
const LANDMARK_NAME = ["Leuchtturm", "Windmühle", "Weltenbaum", "Steinkreis", "Pyramide", "Sternwarte"]
const LANDMARK_COLOR = ["#ff6f61", "#ffb547", "#57c46b", "#8f7cf0", "#f2d15c", "#4fb8e8"]
const HAZARD_NAME = {"meteor": "Meteorit", "storm": "Gewitter", "volcano": "Vulkan"}
const FACE_NORMALS = [Vector3i(0, 1, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1), Vector3i(0, -1, 0)]

var fields: Array = []        # FieldData, Index = id
var hazards: Array = []       # {"type": "meteor"|"storm", "p": Vector3i, "n": Vector3i, "timer": int}
var turn: int = 1
var faith: int = 0            # Glaube = Punktestand
var lightning: int = 0        # Blitze zum Vernichten
var miracles: int = 0         # Wunder zum Neu-Erschaffen
var miracle_progress: int = 0
var bad_rounds: int = 0       # Runden in Folge aus dem Gleichgewicht
var spreads: Array = [0, 0, 0, 0]   # Ausbreitungen pro Volk (für Kapellen)
var rng := RandomNumberGenerator.new()
var _index: Dictionary = {}


# =============================================================================
# Aufbau
# =============================================================================

func setup(seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	turn = 1
	faith = 0
	lightning = Balance.LIGHTNING_START
	miracles = 0
	miracle_progress = 0
	bad_rounds = 0
	spreads = [0, 0, 0, 0]
	hazards.clear()
	fields.clear()
	for x in [-1, 0, 1]:
		for y in [-1, 0, 1]:
			for z in [-1, 0, 1]:
				var p := Vector3i(x, y, z)
				for a in 3:
					if p[a] == 0:
						continue
					var f := FieldData.new()
					f.id = fields.size()
					f.p = p
					f.n = unit(a, p[a])
					fields.append(f)
	rebuild_index()
	for attempt in 100:
		_roll_world()
		_break_lines()
		if war_pairs().is_empty() and _all_needs_met_at_start():
			break


func _roll_world() -> void:
	var free: Array = []
	for f in fields:
		if f.is_center:
			continue
		f.kind = ""
		f.level = 1
		f.nation = -1
		f.bond = 0
		f.need = 0
		f.damage = 0
		f.pollution = 0
		f.burning = false
		f.volcano = 0
		f.crater_age = 0
		free.append(f)
	# Völker als kleine Gruppen: Siedlungen um einen Startpunkt, dazu eine Kapelle
	for nation in Balance.NATION_COUNT:
		var start := _random_free(free)
		if start == null:
			break
		var group: Array = [start]
		var want := Balance.START_SETTLEMENTS + Balance.START_FAITH
		var guard := 0
		while group.size() < want and guard < 40:
			guard += 1
			var base: FieldData = group[rng.randi_range(0, group.size() - 1)]
			var nbs := neighbors(base)
			var g: FieldData = nbs[rng.randi_range(0, nbs.size() - 1)]
			if not g.is_center and g.kind == "" and not group.has(g):
				group.append(g)
		for i in group.size():
			var f: FieldData = group[i]
			f.nation = nation
			f.kind = "faith" if i == group.size() - 1 and group.size() > 1 else "settlement"
	# Industrie neben Siedlungen (braucht Arbeiter)
	for i in Balance.START_INDUSTRY:
		var spots: Array = []
		for s in free:
			if s.kind != "settlement":
				continue
			for g in neighbors(s):
				if not g.is_center and g.kind == "" and not spots.has(g):
					spots.append(g)
		var f: FieldData = spots[rng.randi_range(0, spots.size() - 1)] if not spots.is_empty() else _random_free(free)
		if f != null:
			f.kind = "industry"
	for i in Balance.START_MOUNTAINS:
		var f := _random_free(free)
		if f != null:
			f.kind = "mountain"
	for f in free:
		if f.kind == "":
			f.kind = "nature"


func _random_free(free: Array) -> FieldData:
	var pool: Array = []
	for f in free:
		if f.kind == "":
			pool.append(f)
	if pool.is_empty():
		return null
	return pool[rng.randi_range(0, pool.size() - 1)]


func _all_needs_met_at_start() -> bool:
	for f in fields:
		if (f.kind == "settlement" or f.kind == "industry" or f.kind == "faith") and not _need_met(f):
			return false
	return true


func clone() -> GameState:
	var gs := GameState.new()
	gs.turn = turn
	gs.faith = faith
	gs.lightning = lightning
	gs.miracles = miracles
	gs.miracle_progress = miracle_progress
	gs.bad_rounds = bad_rounds
	gs.spreads = spreads.duplicate()
	gs.rng.seed = rng.seed
	gs.rng.state = rng.state
	for f in fields:
		gs.fields.append(f.copy())
	for h in hazards:
		gs.hazards.append((h as Dictionary).duplicate())
	gs.rebuild_index()
	return gs


func rebuild_index() -> void:
	_index.clear()
	for f in fields:
		_index[pos_key(f.p, f.n)] = f


# =============================================================================
# Geometrie
# =============================================================================

static func pos_key(p: Vector3i, n: Vector3i) -> int:
	return (p.x + 1) + 3 * (p.y + 1) + 9 * (p.z + 1) + 27 * ((n.x + 1) + 3 * (n.y + 1) + 9 * (n.z + 1))


static func unit(a: int, s: int) -> Vector3i:
	var v := Vector3i.ZERO
	v[a] = 1 if s > 0 else -1
	return v


static func axis_of(v: Vector3i) -> int:
	for a in 3:
		if v[a] != 0:
			return a
	return -1


## Dreht einen Vektor um 90° um die Achse a (0=x, 1=y, 2=z). d=+1 ist +90° (rechte Hand).
static func rv(v: Vector3i, a: int, d: int) -> Vector3i:
	if a == 0:
		return Vector3i(v.x, -v.z, v.y) if d > 0 else Vector3i(v.x, v.z, -v.y)
	if a == 1:
		return Vector3i(v.z, v.y, -v.x) if d > 0 else Vector3i(-v.z, v.y, v.x)
	return Vector3i(-v.y, v.x, v.z) if d > 0 else Vector3i(v.y, -v.x, v.z)


func field_at(p: Vector3i, n: Vector3i) -> FieldData:
	return _index.get(pos_key(p, n), null)


func neighbors(f: FieldData) -> Array:
	var out: Array = []
	for a in 3:
		if f.n[a] != 0:
			continue
		for s in [-1, 1]:
			var q := f.p
			q[a] += s
			var g: FieldData
			if absi(q[a]) <= 1:
				g = field_at(q, f.n)
			else:
				g = field_at(f.p, unit(a, s))
			if g != null:
				out.append(g)
	return out


## Die Mitten (Wahrzeichen) drehen sich nie mit, auch nicht bei Mittelscheiben.
func apply_rotation(axis: int, layer: int, turns: int) -> void:
	var d := 1 if turns > 0 else -1
	for i in absi(turns):
		for f in fields:
			if f.p[axis] == layer and not f.is_center:
				f.p = rv(f.p, axis, d)
				f.n = rv(f.n, axis, d)
		rebuild_index()


# =============================================================================
# Abfragen
# =============================================================================

static func pair_key(a: int, b: int) -> String:
	return "%d|%d" % [mini(a, b), maxi(a, b)]


static func level_name(f: FieldData) -> String:
	if LEVEL_NAME.has(f.kind):
		return LEVEL_NAME[f.kind][clampi(f.level, 1, 3)]
	if f.is_center:
		return LANDMARK_NAME[maxi(0, f.landmark)]
	return KIND_NAME.get(f.kind, f.kind)


func age() -> int:
	return 1 + int((turn - 1) / Balance.AGE_LENGTH)


func spread_every() -> int:
	return maxi(Balance.SPREAD_EVERY_MIN, Balance.SPREAD_EVERY - (age() - 1))


## Gleiche Art (bei Siedlung und Glaube: gleiches Volk)?
static func same(f: FieldData, g: FieldData) -> bool:
	if f.kind != g.kind or not f.scored():
		return false
	if f.has_nation():
		return f.nation == g.nation
	return true


func _need_met(f: FieldData) -> bool:
	match f.kind:
		"settlement":
			for g in neighbors(f):
				if g.kind == "nature" and not g.burning:
					return true
			return false
		"industry":
			for g in neighbors(f):
				if g.kind == "settlement":
					return true
			return false
		"faith":
			for g in neighbors(f):
				if g.kind == "settlement" and g.nation == f.nation:
					return true
			return false
	return true


## Völkerpaare im Krieg: Kirchen (Glaube) zweier Völker liegen nebeneinander.
func war_pairs() -> Dictionary:
	var out := {}
	for f in fields:
		if f.kind != "faith" or f.nation < 0:
			continue
		for g in neighbors(f):
			if g.kind == "faith" and g.nation >= 0 and g.nation != f.nation:
				out[pair_key(f.nation, g.nation)] = true
	return out


## Handel: Städte (Siedlung ab Stufe 2) zweier Völker nebeneinander, ohne Krieg.
func trade_links() -> Array:
	var wars := war_pairs()
	var out: Array = []
	for f in fields:
		if f.kind != "settlement" or f.level < 2:
			continue
		for g in neighbors(f):
			if g.id <= f.id or g.kind != "settlement" or g.level < 2 or g.nation == f.nation:
				continue
			if not wars.has(pair_key(f.nation, g.nation)):
				out.append([f.id, g.id])
	return out


func trade_pairs() -> Dictionary:
	var out := {}
	for l in trade_links():
		var a: FieldData = fields[int(l[0])]
		var b: FieldData = fields[int(l[1])]
		out[pair_key(a.nation, b.nation)] = true
	return out


## Anteile der vier Arten an allen beweglichen Feldern und das Gleichgewicht (0–1).
func harmony() -> Dictionary:
	var counts := {"nature": 0, "settlement": 0, "industry": 0, "faith": 0}
	var total := 0
	for f in fields:
		if f.is_center:
			continue
		total += 1
		if counts.has(f.kind):
			counts[f.kind] += 1
	var shares := {}
	var status := {}
	var deviation := 0.0
	for k in KINDS:
		var s := float(counts[k]) / float(maxi(1, total))
		shares[k] = s
		var lo: float = Balance.IDEAL[k][0]
		var hi: float = Balance.IDEAL[k][1]
		if s < lo:
			status[k] = "low"
			deviation += lo - s
		elif s > hi:
			status[k] = "high"
			deviation += s - hi
		else:
			status[k] = "ok"
	var value := clampf(1.0 - deviation * Balance.HARMONY_STRICTNESS, 0.0, 1.0)
	return {"value": value, "shares": shares, "status": status, "counts": counts}


## Punkte für Paare gleicher Felder: [{"a": id, "b": id, "points": int}]
func pairs() -> Array:
	var out: Array = []
	for f in fields:
		if not f.scored():
			continue
		for g in neighbors(f):
			if g.id > f.id and same(f, g):
				out.append({"a": f.id, "b": g.id, "points": f.level + g.level})
	return out


## Punkte, die ein Feld zu Paaren beiträgt.
func field_points(f: FieldData) -> int:
	var pts := 0
	for g in neighbors(f):
		if same(f, g):
			pts += f.level + g.level
	return pts


# =============================================================================
# Drei in einer Reihe
# =============================================================================

## Alle Reihen/Spalten aus 3 gleichen Feldern (gleiche Art, Stufe und Volk) auf einer Seite.
## Jede Reihe ist ein Array aus 3 FieldData, das mittlere Feld an Index 1.
func lines() -> Array:
	var out: Array = []
	for n in FACE_NORMALS:
		var nv: Vector3i = n
		var a := axis_of(nv)
		var u := (a + 1) % 3
		var v := (a + 2) % 3
		for fixed in [u, v]:
			var run: int = v if fixed == u else u
			for c in [-1, 0, 1]:
				var line: Array = []
				for t in [-1, 0, 1]:
					var p := Vector3i.ZERO
					p[a] = nv[a]
					p[fixed] = c
					p[run] = t
					line.append(field_at(p, nv))
				if _line_ok(line):
					out.append(line)
	return out


func _line_ok(line: Array) -> bool:
	var f0: FieldData = line[0]
	if f0 == null or not f0.scored() or f0.burning:
		return false
	for i in [1, 2]:
		var g: FieldData = line[i]
		if g == null or g.burning or not same(f0, g) or g.level != f0.level:
			return false
	return true


## Verschmilzt alle Reihen, auch Kettenreaktionen. Gibt die Punkte zurück (ohne Gleichgewicht).
func resolve_merges(ev: Array) -> int:
	var total := 0
	var combo := 0
	for pass_i in Balance.MAX_CASCADES:
		var found := lines()
		if found.is_empty():
			break
		combo += 1
		var used := {}
		for line in found:
			var skip := false
			for f in line:
				if used.has((f as FieldData).id):
					skip = true
			if skip:
				continue
			for f in line:
				used[(f as FieldData).id] = true
			var mid: FieldData = line[1]
			var a: FieldData = line[0]
			var b: FieldData = line[2]
			var pts: int = int(Balance.MERGE_POINTS[mid.level]) * combo
			total += pts
			if mid.level < Balance.MAX_LEVEL:
				mid.level += 1
			mid.need = 0
			mid.damage = 0
			mid.pollution = 0
			_refill(a)
			_refill(b)
			ev.append({"type": "merge", "field": mid.id, "others": [a.id, b.id], "points": pts, "combo": combo})
	return total


## Ein frei gewordenes Feld bekommt die Art, die gerade am meisten fehlt.
func _refill(f: FieldData) -> void:
	_reset(f)
	var hm := harmony()
	var shares: Dictionary = hm["shares"]
	var best := "nature"
	var best_gap := INF
	for k in KINDS:
		var lo: float = Balance.IDEAL[k][0]
		var hi: float = Balance.IDEAL[k][1]
		var gap := float(shares[k]) - (lo + hi) * 0.5
		if gap < best_gap:
			best_gap = gap
			best = k
	f.kind = best
	f.level = 1
	if best == "settlement" or best == "faith":
		f.nation = _nearest_nation(f)


## Am Start keine fertigen Reihen (sonst gäbe es Punkte geschenkt).
func _break_lines() -> void:
	for guard in 40:
		var found := lines()
		if found.is_empty():
			return
		var mid: FieldData = found[0][1]
		if mid.kind == "nature":
			mid.kind = "mountain"
		else:
			mid.kind = "nature"
			mid.nation = -1


func settlements() -> int:
	var c := 0
	for f in fields:
		if f.kind == "settlement":
			c += 1
	return c


func believers() -> int:
	var c := 0
	for f in fields:
		if f.kind == "settlement":
			c += [0, 2, 5, 10][f.level]
	return c


func is_over() -> bool:
	if settlements() == 0:
		return true
	if bad_rounds >= Balance.LOSE_AFTER_DISHARMONY:
		return true
	return Balance.MAX_ROUNDS > 0 and turn > Balance.MAX_ROUNDS


func hazard_at(f: FieldData) -> Dictionary:
	for h in hazards:
		if h["p"] == f.p and h["n"] == f.n:
			return h
	return {}


## Was passiert mit diesem Feld? Für die Info-Karte.
func field_forecast(f: FieldData) -> Dictionary:
	var wars := war_pairs()
	var out := {"same": 0, "same_level": 0, "need": _need_met(f), "war": false, "polluted": false, "trade": false}
	for g in neighbors(f):
		if same(f, g):
			out["same"] += 1
			if g.level == f.level:
				out["same_level"] += 1
		if f.has_nation() and g.has_nation() and g.nation != f.nation and wars.has(pair_key(f.nation, g.nation)):
			out["war"] = true
		if f.kind == "nature" and g.kind == "industry" and g.level >= Balance.POLLUTION_MIN_LEVEL:
			out["polluted"] = true
		if f.kind == "settlement" and f.level >= 2 and g.kind == "settlement" and g.level >= 2 and g.nation != f.nation \
				and not wars.has(pair_key(f.nation, g.nation)):
			out["trade"] = true
	return out


# =============================================================================
# Werkzeuge
# =============================================================================

func can_lightning(f: FieldData) -> String:
	if lightning <= 0:
		return "Kein Blitz bereit"
	if f.is_center:
		return "Wahrzeichen sind heilig"
	if f.kind == "crater":
		return "Hier ist schon ein Krater"
	return ""


func use_lightning(f: FieldData) -> void:
	lightning -= 1
	_to_crater(f)


func can_miracle(f: FieldData) -> String:
	if miracles <= 0:
		return "Kein Wunder bereit"
	if f.kind != "crater":
		return "Wunder wirken nur auf Kratern"
	return ""


func use_miracle(f: FieldData, kind: String) -> void:
	miracles -= 1
	f.kind = kind
	f.level = 1
	f.bond = 0
	f.need = 0
	f.damage = 0
	f.pollution = 0
	f.crater_age = 0
	f.nation = -1
	if kind == "settlement" or kind == "faith":
		f.nation = _nearest_nation(f)


func _nearest_nation(f: FieldData) -> int:
	var count := {}
	for g in neighbors(f):
		if g.has_nation():
			count[g.nation] = int(count.get(g.nation, 0)) + 1
	var best := 0
	var best_c := -1
	for k in count:
		if int(count[k]) > best_c:
			best_c = int(count[k])
			best = int(k)
	return best


# =============================================================================
# Runde auswerten
# =============================================================================

## Wertet die Runde aus. Deterministisch (kein Zufall), damit die Vorschau stimmt.
## Gibt {"events": Array, "gain": int, "loss": int} zurück.
func end_round() -> Dictionary:
	var ev: Array = []
	var loss := 0
	# 0. Drei in einer Reihe verschmelzen sofort
	var merge_points := resolve_merges(ev)
	var burning_before: Array = []
	for f in fields:
		if f.burning:
			burning_before.append(f)

	# 1. Gefahren an ihrem Platz
	var keep: Array = []
	for h in hazards:
		h["timer"] = int(h["timer"]) - 1
		if int(h["timer"]) > 0:
			keep.append(h)
			continue
		var f := field_at(h["p"], h["n"])
		if f == null or f.is_center:
			continue
		if h["type"] == "meteor":
			ev.append({"type": "meteor", "field": f.id})
			loss += _settled_loss(f, f.level)
			_to_crater(f)
		else:
			ev.append({"type": "storm", "field": f.id})
			if f.kind == "nature" and f.level != 2:
				f.burning = true
			else:
				loss += _settled_loss(f, 1)
				_level_down(f, ev)
	hazards = keep

	# Vulkane
	for f in fields:
		if f.volcano <= 0:
			continue
		f.volcano -= 1
		if f.volcano == 0:
			ev.append({"type": "eruption", "field": f.id})
			for g in neighbors(f):
				if g.is_center:
					continue
				if g.kind == "nature" and g.level != 2:
					g.burning = true
				else:
					loss += _settled_loss(g, 1)
					_level_down(g, ev)

	# Feuer: brennt Natur nieder, springt über; ein Fluss daneben löscht
	var ignite: Array = []
	for f in burning_before:
		if not f.burning:
			continue
		var river := false
		for g in neighbors(f):
			if g.kind == "nature" and g.level == 2:
				river = true
		f.burning = false
		if river:
			ev.append({"type": "extinguish", "field": f.id})
			continue
		ev.append({"type": "fire", "field": f.id})
		for g in neighbors(f):
			if g.kind == "nature" and g.level != 2 and not g.burning and not ignite.has(g):
				ignite.append(g)
		_to_crater(f)
	for g in ignite:
		g.burning = true

	# 2. Zusammenführen, Bedürfnisse, Krieg, Verschmutzung (alle aus demselben Zustand)
	var wars := war_pairs()
	var down: Array = []
	for f in fields:
		if not f.scored():
			continue
		var at_war := false
		var polluted := false
		for g in neighbors(f):
			if f.has_nation() and g.has_nation() and g.nation != f.nation and wars.has(pair_key(f.nation, g.nation)):
				at_war = true
			if f.kind == "nature" and g.kind == "industry" and g.level >= Balance.POLLUTION_MIN_LEVEL:
				polluted = true
		var drop := false
		f.need = 0 if _need_met(f) else f.need + 1
		if f.need >= Balance.NEED_ROUNDS:
			drop = true
		f.damage = f.damage + 1 if at_war else 0
		if f.damage >= Balance.WAR_ROUNDS:
			drop = true
		f.pollution = f.pollution + 1 if polluted else 0
		if f.pollution >= Balance.POLLUTION_ROUNDS:
			drop = true
		if drop:
			down.append(f)
		if at_war:
			ev.append({"type": "war", "field": f.id})
	for f in down:
		f.need = 0
		f.damage = 0
		f.pollution = 0
		f.bond = 0
		_level_down(f, ev)

	# 3. Ausbreiten (Stufe 3)
	if turn % spread_every() == 0:
		var spreaders: Array = []
		for f in fields:
			if f.level >= 3 and (f.kind == "nature" or f.kind == "settlement" or f.kind == "industry"):
				spreaders.append(f)
		for f in spreaders:
			var target: FieldData = null
			for g in neighbors(f):
				if g.is_center or g.burning:
					continue
				var ok := false
				match f.kind:
					"nature":
						ok = g.kind == "crater" or (g.kind == "settlement" and g.level == 1)
					_:
						ok = g.kind == "crater" or (g.kind == "nature" and g.level == 1)
				if ok and (target == null or g.id < target.id):
					target = g
			if target == null:
				continue
			_reset(target)
			if f.kind == "settlement":
				spreads[f.nation] = int(spreads[f.nation]) + 1
				target.kind = "faith" if int(spreads[f.nation]) % Balance.CHAPEL_EVERY == 0 else "settlement"
				target.nation = f.nation
			else:
				target.kind = f.kind
			target.level = 1
			ev.append({"type": "spread", "field": target.id, "from": f.id})

	# Krater wachsen wieder zu
	for f in fields:
		if f.kind != "crater":
			continue
		f.crater_age += 1
		if f.crater_age >= Balance.CRATER_REGROW:
			_reset(f)
			f.kind = "nature"
			f.level = 1
			ev.append({"type": "regrow", "field": f.id})

	# 4. Glaube
	var hm := harmony()
	var factor: float = Balance.MERGE_HARMONY_MIN + (1.0 - Balance.MERGE_HARMONY_MIN) * float(hm["value"])
	var gain := int(round(merge_points * factor)) + trade_links().size() * Balance.TRADE_POINTS
	faith = maxi(0, faith + gain - loss)
	if float(hm["value"]) < Balance.HARMONY_DANGER:
		bad_rounds += 1
	else:
		bad_rounds = 0
	miracle_progress += gain
	while miracle_progress >= Balance.MIRACLE_EVERY_POINTS:
		miracle_progress -= Balance.MIRACLE_EVERY_POINTS
		miracles = mini(Balance.MIRACLE_MAX, miracles + 1)
	if turn % Balance.LIGHTNING_EVERY == 0:
		lightning = mini(Balance.LIGHTNING_MAX, lightning + 1)
	turn += 1
	return {"events": ev, "gain": gain, "loss": loss}


func _settled_loss(f: FieldData, levels: int) -> int:
	if f.kind == "settlement" or f.kind == "faith":
		return levels * Balance.DISASTER_LOSS_PER_LEVEL
	return 0


func _reset(f: FieldData) -> void:
	f.nation = -1
	f.bond = 0
	f.need = 0
	f.damage = 0
	f.pollution = 0
	f.burning = false
	f.volcano = 0
	f.crater_age = 0


func _to_crater(f: FieldData) -> void:
	_reset(f)
	f.kind = "crater"
	f.level = 1


func _level_down(f: FieldData, ev: Array) -> void:
	if not f.scored():
		return
	if f.level > 1:
		f.level -= 1
		ev.append({"type": "downgrade", "field": f.id})
	else:
		ev.append({"type": "lost", "field": f.id})
		_to_crater(f)


## Neue Gefahren (mit Zufall), mit jedem Zeitalter häufiger und knapper angekündigt.
func spawn_hazards() -> Array:
	if turn <= Balance.HAZARD_FREE_ROUNDS + 1:
		return []
	var active := hazards.size()
	for f in fields:
		if f.volcano > 0:
			active += 1
	var max_h := mini(Balance.HAZARD_MAX, Balance.HAZARD_MAX_BASE + age() - 1)
	if active >= max_h:
		return []
	var chance := minf(Balance.HAZARD_CHANCE_MAX, Balance.HAZARD_CHANCE_BASE + Balance.HAZARD_CHANCE_PER_AGE * (age() - 1))
	if rng.randf() > chance:
		return []
	var timer := Balance.HAZARD_TIMER if age() < 3 else maxi(Balance.HAZARD_TIMER_MIN, Balance.HAZARD_TIMER - 1)
	var t := _roll_hazard_type()
	if t == "volcano":
		var mountains: Array = []
		for f in fields:
			if f.kind == "mountain" and f.volcano == 0:
				mountains.append(f)
		if mountains.is_empty():
			t = "storm"
		else:
			var m: FieldData = mountains[rng.randi_range(0, mountains.size() - 1)]
			m.volcano = timer
			return [{"type": "volcano", "field": m.id}]
	var pool: Array = []
	for f in fields:
		if not f.is_center and (f.kind == "settlement" or f.kind == "faith" or f.kind == "industry") and hazard_at(f).is_empty():
			pool.append(f)
	if pool.is_empty() or rng.randf() < 0.3:
		pool.clear()
		for f in fields:
			if not f.is_center and hazard_at(f).is_empty():
				pool.append(f)
	if pool.is_empty():
		return []
	var target: FieldData = pool[rng.randi_range(0, pool.size() - 1)]
	var hz := {"type": t, "p": target.p, "n": target.n, "timer": timer}
	hazards.append(hz)
	return [hz]


func _roll_hazard_type() -> String:
	var total := 0
	for k in Balance.HAZARD_WEIGHTS:
		total += int(Balance.HAZARD_WEIGHTS[k])
	var r := rng.randi_range(1, maxi(total, 1))
	for k in Balance.HAZARD_WEIGHTS:
		r -= int(Balance.HAZARD_WEIGHTS[k])
		if r <= 0:
			return str(k)
	return "storm"
