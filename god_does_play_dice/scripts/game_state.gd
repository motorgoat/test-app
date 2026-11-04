class_name GameState
extends RefCounted
## Reine Spiellogik, getrennt von der Darstellung. Kopierbar (clone) für die Vorschau.
##
## Regeln:
##   1. Start: nur leere Erde und Wiesen.
##   2. Drei gleiche Felder in einer Reihe oder Spalte einer Seite verschmelzen sofort zur nächsten Stufe:
##      Wiese → Wald → Dorf → Stadt → Fabrik. Die äußeren zwei werden zu leerer Erde.
##   3. Leere Erde wird wieder Wiese, wenn genug Natur daneben ist.
##   4. Städte und Fabriken bringen jede Runde Glauben. Fabriken verschmutzen die Natur daneben.
##   5. Zu wenig Natur oder zu viel Zivilisation: nach ein paar Runden stirbt die Welt.
##   6. Meteorit (kostet Glauben): Feld und Nachbarn werden zu leerer Erde.

const STAGE_NAME = ["Leere Erde", "Wiese", "Wald", "Dorf", "Stadt", "Fabrik"]
const STAGE_ICON = ["empty", "meadow", "nature", "village", "town", "industry"]
const FACE_NORMALS = [Vector3i(0, 1, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1), Vector3i(0, -1, 0)]

var fields: Array = []        # FieldData, Index = id
var turn: int = 1
var faith: int = 0            # Glaube = Punkte und Währung für Meteoriten
var meteors_used: int = 0
var bad_rounds: int = 0       # Runden in Folge außerhalb des Gleichgewichts
var moved: Dictionary = {}    # IDs der Felder, die die letzte Drehung bewegt hat
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
	meteors_used = 0
	bad_rounds = 0
	moved = {}
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
					f.stage = 1 if rng.randf() < Balance.START_MEADOW else 0
					fields.append(f)
	rebuild_index()
	# Am Start keine fertigen Reihen (sonst gäbe es Punkte geschenkt)
	for guard in 60:
		var found := lines()
		if found.is_empty():
			break
		(found[0][1] as FieldData).stage = 0


func clone() -> GameState:
	var gs := GameState.new()
	gs.turn = turn
	gs.faith = faith
	gs.meteors_used = meteors_used
	gs.bad_rounds = bad_rounds
	gs.moved = moved.duplicate()
	gs.rng.seed = rng.seed
	gs.rng.state = rng.state
	for f in fields:
		gs.fields.append(f.copy())
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


## Wie ein echter Zauberwürfel: alle Felder der Scheibe drehen mit, auch die Mitten.
func apply_rotation(axis: int, layer: int, turns: int) -> void:
	var d := 1 if turns > 0 else -1
	for f in fields:
		if f.p[axis] == layer:
			moved[f.id] = true
	for i in absi(turns):
		for f in fields:
			if f.p[axis] == layer:
				f.p = rv(f.p, axis, d)
				f.n = rv(f.n, axis, d)
		rebuild_index()


# =============================================================================
# Abfragen
# =============================================================================

static func stage_name(stage: int) -> String:
	return STAGE_NAME[clampi(stage, 0, Balance.MAX_STAGE)]


func count(stage: int) -> int:
	var c := 0
	for f in fields:
		if f.stage == stage:
			c += 1
	return c


func nature_share() -> float:
	return float(count(1) + count(2)) / float(fields.size())


func civilisation_share() -> float:
	return float(count(3) + count(4) + count(5)) / float(fields.size())


func in_balance() -> bool:
	return nature_share() >= Balance.NATURE_MIN and civilisation_share() <= Balance.CIVILISATION_MAX


func income() -> int:
	var c := 0
	for f in fields:
		c += int(Balance.INCOME[f.stage])
	return c


func meteor_cost() -> int:
	return Balance.METEOR_COST + Balance.METEOR_COST_STEP * meteors_used


func is_over() -> bool:
	return died() or finished()


func died() -> bool:
	return bad_rounds >= Balance.LOSE_AFTER


func finished() -> bool:
	return Balance.MAX_ROUNDS > 0 and turn > Balance.MAX_ROUNDS


func stars() -> int:
	var s := 0
	for t in Balance.STARS:
		if faith >= int(t):
			s += 1
	return s


## Alle Reihen/Spalten aus 3 gleichen Feldern (nicht leer) auf einer Seite.
## Mit only: nur Reihen, die mindestens eines dieser Felder enthalten.
## Jede Reihe ist ein Array aus 3 FieldData, das mittlere Feld an Index 1.
func lines(only: Dictionary = {}) -> Array:
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
				var f0: FieldData = line[0]
				var f1: FieldData = line[1]
				var f2: FieldData = line[2]
				if f0 != null and f1 != null and f2 != null and f0.stage > 0 and f0.stage == f1.stage and f0.stage == f2.stage:
					if only.is_empty() or only.has(f0.id) or only.has(f1.id) or only.has(f2.id):
						out.append(line)
	return out


## Reihen, die die letzte Drehung vervollständigt hat.
func moved_lines() -> Array:
	if moved.is_empty():
		return []
	return lines(moved)


## Punkte, die die letzte Drehung sofort durch Verschmelzen bringt (ohne Kettenreaktion).
func merge_value() -> int:
	var pts := 0
	for line in moved_lines():
		pts += int(Balance.MERGE_POINTS[(line[1] as FieldData).stage])
	return pts


# =============================================================================
# Runde auswerten
# =============================================================================

## Verschmilzt die Reihen, die die Drehung vervollständigt hat, dann Kettenreaktionen
## (Reihen mit Feldern, die sich gerade verändert haben). Gibt die Punkte zurück.
func resolve_merges(ev: Array) -> int:
	var total := 0
	var combo := 0
	var focus := moved.duplicate()
	for pass_i in Balance.MAX_CASCADES:
		if focus.is_empty():
			break
		var found := lines(focus)
		if found.is_empty():
			break
		focus = {}
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
			var pts: int = int(Balance.MERGE_POINTS[mid.stage]) * combo
			total += pts
			var was := mid.stage
			if mid.stage < Balance.MAX_STAGE:
				mid.stage += 1
			a.stage = was - 1
			b.stage = was - 1
			a.fresh = 0
			b.fresh = 0
			focus[mid.id] = true
			focus[a.id] = true
			focus[b.id] = true
			ev.append({"type": "merge", "field": mid.id, "others": [a.id, b.id], "points": pts, "combo": combo, "stage": mid.stage})
	return total


## Wertet die Runde aus. Deterministisch (kein Zufall), damit die Vorschau stimmt.
## Gibt {"events": Array, "gain": int} zurück.
func end_round() -> Dictionary:
	var ev: Array = []
	# 1. Drei in einer Reihe verschmelzen sofort (nur durch die Drehung vervollständigte)
	var gain := resolve_merges(ev)
	moved = {}

	# 2. Fabriken verschmutzen Natur daneben
	for f in fields:
		if f.stage != 5:
			continue
		var left := Balance.POLLUTION_PER_FACTORY
		for g in neighbors(f):
			if left <= 0:
				break
			if g.is_nature():
				g.stage = 0
				g.fresh = 2
				left -= 1
				ev.append({"type": "polluted", "field": g.id})

	# 3. Leere Erde wird wieder Wiese (alle gleichzeitig)
	var grow: Array = []
	for f in fields:
		if f.stage != 0 or f.fresh > 0:
			continue
		var nat := 0
		for g in neighbors(f):
			if g.is_nature():
				nat += 1
		if nat >= Balance.REGROW_NEIGHBORS:
			grow.append([nat, f.id, f])
	grow.sort_custom(func(x, y): return x[0] > y[0] or (x[0] == y[0] and x[1] < y[1]))
	grow = grow.slice(0, Balance.REGROW_PER_ROUND)
	for item in grow:
		var f: FieldData = item[2]
		f.stage = 1
		ev.append({"type": "regrow", "field": f.id})
	for f in fields:
		if f.fresh > 0:
			f.fresh -= 1

	# 4. Glaube aus Städten und Fabriken
	gain += income()
	faith += gain

	# 5. Gleichgewicht
	if in_balance():
		bad_rounds = 0
	else:
		bad_rounds += 1
	turn += 1
	return {"events": ev, "gain": gain}


# =============================================================================
# Meteorit
# =============================================================================

func can_meteor() -> String:
	if faith < meteor_cost():
		return "Dir fehlen %d Glaube für einen Meteoriten" % (meteor_cost() - faith)
	return ""


## Schlägt ein: das Feld und seine Nachbarn werden zu leerer Erde. Gibt die getroffenen IDs zurück.
func use_meteor(f: FieldData) -> Array:
	faith -= meteor_cost()
	meteors_used += 1
	var hit: Array = [f]
	hit.append_array(neighbors(f))
	var ids: Array = []
	for g in hit:
		var h: FieldData = g
		h.stage = 0
		h.fresh = 2
		ids.append(h.id)
	return ids
