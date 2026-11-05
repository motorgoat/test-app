class_name GameState
extends RefCounted
## Reine Spiellogik, getrennt von der Darstellung. Kopierbar (clone) für die Vorschau.
##
## Regeln:
##   1. Start: leere Erde und Wiesen, nie drei Wiesen beisammen und keine fertige Reihe (auch nicht schräg).
##   2. Drei gleiche Felder in einer Reihe (ab dem kleinen Wald auch diagonal) verschmelzen, sobald sich darin etwas verändert hat: Das Feld, das zuletzt dazugekommen ist,
##      steigt auf (Wiese → kleiner Wald → großer Wald → Hütte → Haus → Dorf → Stadt → Großstadt → Metropole),
##      die beiden anderen bleiben, wie sie sind (OTHERS_DROP). Das gibt Punkte.
##      Jede neu gebildete Reihe zählt, auch mit denselben Feldern an anderer Stelle. Nicht zählen nur Reihen, die schon
##      dastanden (auch mitgedreht), und das sofortige Zurückdrehen der Reihe, die die Drehung davor aufgelöst hat.
##   3. Wiese wächst nicht von allein (abschaltbar: REGROW_PER_ROUND).
##   4. Großstädte und Metropolen zerstören Natur daneben.
##   5. Fehlversuch = Drehung, die nichts verschmilzt. Jeder 3. Fehlversuch (der Zähler läuft weiter) setzt
##      die zuletzt gedrehte Reihe in Brand: Im nächsten Zug verliert jedes brennende Feld eine Stufe, dann ist
##      das Feuer aus. Regen vorher rettet ein Feld.
##   7. Boni: Regen lässt ein Feld der niedrigsten Stufe wachsen (oder löscht ein Feuer), Blitz hebt eine Diagonale.
##   8. Jede Welt hat 3 Herzen: Jeder Brand kostet eines, nach dem 3. ist die Welt tot. Nach unten geht es nur durch Brände.
##      Stufen: Einfach (alles, was sich berührt), Mittel (Reihen + Diagonalen), Schwer (nur Reihen).
##      Das Zeitalter folgt der höchsten erreichten Stufe (Hütte = Steinzeit …).
##   9. Ganze Seite aus 9 gleichen Feldern: Die ganze Seite steigt eine Stufe auf (viele Punkte) und bleibt stehen.
##  10. Die drei Stufen laufen offen, bis die Welt verbrennt; die Challenge endet nach 40 Drehungen (Mittel).
##      Ist nichts mehr zu verbinden, gibt es einen Regen geschenkt.

const STAGE_NAME = ["Erde", "Wiese", "Kleiner Wald", "Großer Wald", "Hütte", "Haus", "Dorf", "Stadt", "Großstadt", "Metropole"]
const STAGE_SHORT = ["Erde", "Wiese", "kl. Wald", "gr. Wald", "Hütte", "Haus", "Dorf", "Stadt", "Großstadt", "Metropole"]
const STAGE_ICON = ["empty", "meadow", "smallforest", "nature", "hut", "house", "village", "town", "bigcity", "metropolis"]
const DISASTER_NAME = {"fire": "Feuer"}
const DISASTER_WHY = {"fire": "3 Flammen"}
const FACE_NORMALS = [Vector3i(0, 1, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1), Vector3i(0, -1, 0)]

var fields: Array = []        # FieldData, Index = id
var turn: int = 1
var score: int = 0           # Punkte
var rain: int = 1             # Regen-Boni
var bolts: int = 0            # Blitz-Boni
var monsoons: int = 0         # Monsun-Boni (ganze Seite), ab der Antike
var monsoon_unlocked := false
var next_monsoon: int = 0
var next_rain: int = 0        # ab dieser Punktzahl gibt es den nächsten Regen …
var next_bolt: int = 0        # … und den nächsten Blitz
var misses: int = 0           # Fehlversuche seit dem letzten Brand
var last_row: Array = []      # IDs der zuletzt gedrehten Reihe (brennt beim 3. Fehlversuch)
var _rotated := false         # dieser Zug war eine Drehung
var twists: int = 0           # Drehungen bisher (40-Drehungen-Modus)
var tapped := -1              # angetipptes Feld eines Bonus: steigt beim Verschmelzen bevorzugt auf
var standing := {}            # Reihen (Felder + Stufe), die zu Beginn dieses Zugs schon dastanden: zählen nicht (mitgedreht, unverändert)
var broken := {}              # Reihen, die die letzte Drehung aufgelöst hat: sofort zurückdrehen zählt nicht (kein Hin- und Herschieben)
var _broke_now := {}          # Reihen, die die Drehung dieses Zugs aufgelöst hat (werden am Zugende zu broken)
var spent := {}               # Einfach: Reihen, die als ganze Gruppe zusammen aufgestiegen sind (dieselben Felder, eine Stufe höher).
                              # Sie hat nicht der Spieler gebildet: Auflösen und wieder zusammendrehen zählt nie (kein Hochzüchten)
var meteors_used: int = 0
var best_stage: int = 1       # höchste Stufe, die je erreicht wurde
var lives: int = 3            # Herzen: so viele Brände hält die Welt noch aus
var hearts := true            # mit Herzen (alle Modi): nach dem 3. Brand ist die Welt tot
var no_fire := false          # Tutorial: Fehlversuche zählen nicht, nichts brennt
var disasters: int = 0        # Katastrophen bisher
var last_disaster := ""       # die letzte Katastrophe (für das Spielende)
var moved: Dictionary = {}    # IDs der Felder, die die letzte Drehung bewegt hat
var endless := true           # Endlos-Modus oder 40 Runden
var easy := false             # Einfach: Eine Reihe löst aus, dann steigen alle gleichen Felder auf, die damit zusammenhängen
var diagonals := true         # Mittel: auch Diagonalen (ab dem kleinen Wald)
var gadgets := true           # Regen, Blitz, Monsun (in allen Stufen an)
var diag_from := 2            # ab dieser Stufe zählen Diagonalen (Einfach: schon Wiesen)
var rng := RandomNumberGenerator.new()
var _index: Dictionary = {}


# =============================================================================
# Aufbau
# =============================================================================

## level: 0 Einfach, 1 Mittel, 2 Schwer. with_hearts: 3 Herzen, jeder Brand kostet eines (Standard in allen Modi).
func setup(seed_value: int = 0, endless_mode: bool = true, level: int = 1, with_hearts: bool = true) -> void:
	level = clampi(level, 0, 2)
	endless = endless_mode
	hearts = with_hearts
	no_fire = false
	easy = level == 0
	diagonals = level <= 1
	gadgets = true
	diag_from = 1 if easy else Balance.DIAGONAL_FROM
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	turn = 1
	score = 0
	rain = Balance.RAIN_START if gadgets else 0
	bolts = Balance.BOLT_START if gadgets else 0
	next_rain = Balance.RAIN_EVERY
	next_bolt = Balance.BOLT_EVERY
	misses = 0
	twists = 0
	monsoons = 0
	monsoon_unlocked = false
	next_monsoon = 0
	last_row = []
	_rotated = false
	standing = {}
	broken = {}
	_broke_now = {}
	spent = {}
	meteors_used = 0
	best_stage = 1
	lives = Balance.LIVES if hearts else 0
	disasters = 0
	last_disaster = ""
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
	# Am Start liegen nie drei Wiesen beisammen (auch nicht über Eck oder über die Kante):
	# Keine Wiese hat mehr als eine Wiese daneben.
	for guard in 200:
		var worst: FieldData = null
		var worst_n := 1
		for f in fields:
			if f.stage != 1:
				continue
			var n := _count_neighbors(f, "nature")
			if n > worst_n:
				worst_n = n
				worst = f
		if worst == null:
			break
		worst.stage = 0
	# Danach wieder auffüllen, wo das erlaubt ist, damit genug Natur da ist
	var order: Array = fields.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	for g in order:
		var f: FieldData = g
		if nature_share() >= Balance.START_NATURE:
			break
		if f.stage == 0 and _meadow_allowed(f):
			f.stage = 1
			if not lines({f.id: true}).is_empty():
				f.stage = 0          # keine fertige Reihe am Start (auch nicht schräg)
	_break_ready_lines()


## Steht irgendwo schon eine fertige Reihe (z. B. eine schräge aus 3 Wiesen)? Dann ein Feld davon zu Erde.
## Mit only: nur Reihen mit einem dieser Felder (was schon gewachsen ist, bleibt stehen).
func _break_ready_lines(only: Dictionary = {}) -> void:
	for guard in 60:
		var hit: Array = []
		for ln in lines(only):
			hit = ln
			break
		if hit.is_empty():
			return
		var k := 1
		if not only.is_empty() and not only.has((hit[1] as FieldData).id):
			for i in hit.size():
				if only.has((hit[i] as FieldData).id):
					k = i
		(hit[k] as FieldData).stage = 0


## Darf hier am Start eine Wiese hin, ohne dass drei Wiesen beisammen liegen?
func _meadow_allowed(f: FieldData) -> bool:
	var m: Array = []
	for g in neighbors(f):
		if (g as FieldData).stage == 1:
			m.append(g)
	if m.is_empty():
		return true
	if m.size() > 1:
		return false
	return _count_neighbors(m[0], "nature") == 0


func clone() -> GameState:
	var gs := GameState.new()
	gs.turn = turn
	gs.endless = endless
	gs.easy = easy
	gs.diagonals = diagonals
	gs.gadgets = gadgets
	gs.diag_from = diag_from
	gs.score = score
	gs.rain = rain
	gs.bolts = bolts
	gs.next_rain = next_rain
	gs.next_bolt = next_bolt
	gs.misses = misses
	gs.monsoons = monsoons
	gs.monsoon_unlocked = monsoon_unlocked
	gs.next_monsoon = next_monsoon
	gs.last_row = last_row.duplicate()
	gs._rotated = _rotated
	gs.twists = twists
	gs.tapped = tapped
	gs.standing = standing.duplicate()
	gs.broken = broken.duplicate()
	gs._broke_now = _broke_now.duplicate()
	gs.spent = spent.duplicate()
	gs.best_stage = best_stage
	gs.meteors_used = meteors_used
	gs.lives = lives
	gs.hearts = hearts
	gs.no_fire = no_fire
	gs.disasters = disasters
	gs.last_disaster = last_disaster
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
## row: die drei Felder, über die gewischt wurde (brennen beim 3. Fehlversuch). Leer: eine Reihe der Scheibe.
func apply_rotation(axis: int, layer: int, turns: int, row: Array = []) -> void:
	var d := 1 if turns > 0 else -1
	_rotated = true
	var first := moved.is_empty()
	_remember_before()
	var had := standing if first else _line_keys()
	last_row = row.duplicate() if not row.is_empty() else slice_row(axis, layer)
	for f in fields:
		if f.p[axis] == layer:
			moved[f.id] = true
	for i in absi(turns):
		for f in fields:
			if f.p[axis] == layer:
				f.p = rv(f.p, axis, d)
				f.n = rv(f.n, axis, d)
		rebuild_index()
	# Welche Reihen hat diese Drehung aufgelöst? Sofort zurückdrehen bringt sie nicht noch einmal zum Wachsen.
	var now := _line_keys()
	for k in had:
		if not now.has(k):
			_broke_now[k] = true


## Tutorial: ein ruhiger Würfel. Oben liegen zwei Wiesen in einer Reihe, die dritte kommt mit einer
## Drehung der Scheibe x = 1 von hinten dazu (wird im Tutorial vorgezeigt).
func setup_tutorial_board() -> void:
	for f in fields:
		f.stage = 0
		f.fresh = 0
		f.burning = false
	field_at(Vector3i(-1, 1, 1), Vector3i(0, 1, 0)).stage = 1
	field_at(Vector3i(0, 1, 1), Vector3i(0, 1, 0)).stage = 1
	field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1)).stage = 1
	# ein paar einzelne Wiesen, damit die Welt nicht leer aussieht (keine Reihe, nichts beisammen)
	field_at(Vector3i(-1, -1, 1), Vector3i(0, 0, 1)).stage = 1
	field_at(Vector3i(1, -1, 1), Vector3i(0, 0, 1)).stage = 1
	field_at(Vector3i(1, 0, -1), Vector3i(1, 0, 0)).stage = 1
	field_at(Vector3i(-1, -1, -1), Vector3i(-1, 0, 0)).stage = 1
	field_at(Vector3i(0, -1, -1), Vector3i(0, -1, 0)).stage = 1
	# Zweites Paar: Dieselbe Drehung noch einmal (x = 1, eine Vierteldrehung) macht oben eine neue Wiesen-Reihe
	field_at(Vector3i(-1, 1, -1), Vector3i(0, 1, 0)).stage = 1
	field_at(Vector3i(0, 1, -1), Vector3i(0, 1, 0)).stage = 1
	field_at(Vector3i(1, -1, 1), Vector3i(0, -1, 0)).stage = 1    # kommt bei der 2. Drehung nach oben (1, 1, -1)
	moved = {}
	standing = {}
	broken = {}
	_broke_now = {}
	spent = {}


## Nach dem Tutorial: Die leere Erde erblüht zu einem normalen Start (wie in setup()).
## Behält alles, was schon gewachsen ist (und die Punkte). Keine fertige Dreierreihe, aber möglichst
## eine Drehung, die sofort wächst. Gibt die IDs der neuen Wiesen zurück (für die Animation).
func fill_after_tutorial() -> Array:
	# Ein frischer Start: Nichts ist vorgemerkt. Was dasteht, zählt erst wieder, wenn es neu gebildet wird.
	standing = {}
	broken = {}
	_broke_now = {}
	spent = {}
	var picked: Array = []
	for attempt in 12:
		picked = _bloom_once()
		moved = {}
		if has_quick_move():
			break
		if attempt < 11:
			for i in picked:
				(fields[int(i)] as FieldData).stage = 0
	# Eine neue fertige Reihe gibt es nicht (was schon gewachsen ist, bleibt)
	var fresh := {}
	for i in picked:
		fresh[int(i)] = true
	_break_ready_lines(fresh)
	var out: Array = []
	for i in picked:
		if (fields[int(i)] as FieldData).stage > 0:
			out.append(i)
	misses = 0
	last_row = []
	moved = {}
	tapped = -1
	_rotated = false
	return out


func _bloom_once() -> Array:
	var out: Array = []
	var order: Array = []
	for g in fields:
		if (g as FieldData).stage == 0:
			order.append(g)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	for g in order:
		var f: FieldData = g
		if nature_share() >= Balance.START_NATURE:
			break
		if not _meadow_allowed(f):
			continue
		f.stage = 1
		if not lines({f.id: true}).is_empty():
			f.stage = 0
			continue
		out.append(f.id)
	return out


## Die drei Felder der Scheibe auf der ersten Seite, die sie schneidet.
func slice_row(axis: int, layer: int) -> Array:
	for nv in FACE_NORMALS:
		var n: Vector3i = nv
		if n[axis] != 0:
			continue
		var out: Array = []
		for f in fields:
			if f.n == n and f.p[axis] == layer:
				out.append(f.id)
		if out.size() == 3:
			return out
	return []


## Die drei Felder einer Reihe durch f auf seiner Seite; along = Achse, entlang der die Reihe läuft.
func line_through(f: FieldData, along: int) -> Array:
	var out: Array = []
	for t in [-1, 0, 1]:
		var p := f.p
		p[along] = t
		var g := field_at(p, f.n)
		if g != null:
			out.append(g.id)
	return out


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
	var c := 0
	for f in fields:
		if f.is_nature():
			c += 1
	return float(c) / float(fields.size())


func civilisation_share() -> float:
	var c := 0
	for f in fields:
		if f.is_civilisation():
			c += 1
	return float(c) / float(fields.size())


## Zeitalter (1 = Urzeit …): folgt der höchsten erreichten Stufe.
func age() -> int:
	var a := 1
	for i in Balance.AGE_FROM_STAGE.size():
		if best_stage >= int(Balance.AGE_FROM_STAGE[i]):
			a = i + 1
	return a


func age_name() -> String:
	return str(Balance.AGES[age() - 1])


## Vorbei nach dem 3. Brand (alle Modi) oder nach der 40. Drehung (Challenge).
func is_over() -> bool:
	return finished() or died()


## Nichts mehr zu verbinden: keine Stufe hat noch 3 Felder, und es gibt weder Regen noch Blitz.
func stuck() -> bool:
	if rain > 0 or bolts > 0:
		return false
	for st in range(1, Balance.MAX_STAGE + 1):
		if count(st) >= 3:
			return false
	return true


func died() -> bool:
	return hearts and lives <= 0


func finished() -> bool:
	return not endless and twists >= Balance.MAX_TWISTS


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
		# Diagonalen („quer“): ab dem kleinen Wald
		for dir in [1, -1]:
			var dline: Array = []
			for t in [-1, 0, 1]:
				var p := Vector3i.ZERO
				p[a] = nv[a]
				p[u] = t
				p[v] = t * dir
				dline.append(field_at(p, nv))
			var d0: FieldData = dline[0]
			var d1: FieldData = dline[1]
			var d2: FieldData = dline[2]
			if diagonals and d0 != null and d1 != null and d2 != null and d0.stage >= diag_from and d0.stage == d1.stage and d0.stage == d2.stage:
				if only.is_empty() or only.has(d0.id) or only.has(d1.id) or only.has(d2.id):
					out.append(dline)
	return out


## Schlüssel einer Reihe: ihre Felder und ihre Stufe.
static func line_key(line: Array) -> String:
	var ids: Array = []
	for g in line:
		ids.append((g as FieldData).id)
	ids.sort()
	return "%s@%d" % [str(ids), (line[0] as FieldData).stage]


## Vor der ersten Änderung eines Zugs merken, welche Reihen schon dastehen (zählen nicht, auch nicht mitgedreht).
func _remember_before() -> void:
	if not moved.is_empty():
		return
	standing = _line_keys()
	_broke_now = {}


## Schlüssel aller Reihen, die gerade dastehen.
func _line_keys() -> Dictionary:
	var out := {}
	for ln in lines():
		out[line_key(ln)] = true
	return out


## Zählt diese Reihe in diesem Zug? Nur, wenn sie neu gebildet ist: Sie stand zu Beginn des Zugs nicht da,
## ist nicht die Reihe, die die letzte Drehung aufgelöst hat (sofort zurückdrehen bringt nichts), und ist keine
## Reihe, die als ganze Gruppe aufgestiegen ist (Einfach: dieselben drei Felder eine Stufe höher zählen nie neu).
func counts(line: Array) -> bool:
	var k := line_key(line)
	return not standing.has(k) and not broken.has(k) and not spent.has(k)


## Stehen die drei Felder (noch) als Reihe da? (Eine Verschmelzung im selben Durchgang kann eines verändert haben.)
static func _still_line(line: Array) -> bool:
	var st := (line[0] as FieldData).stage
	if st <= 0:
		return false
	for g in line:
		if (g as FieldData).stage != st:
			return false
	return true


## Die aktuell niedrigste Stufe auf dem Würfel (nur die hebt der Regen).
func lowest_stage() -> int:
	var low := Balance.MAX_STAGE
	for f in fields:
		low = mini(low, f.stage)
	return low


## Alle gleichen Felder, die mit f zusammenhängen (über Kanten, auch über die Würfelkante).
func group_of(f: FieldData) -> Array:
	var comp: Array = []
	var seen := {f.id: true}
	var todo: Array = [f]
	while not todo.is_empty():
		var h: FieldData = todo.pop_back()
		comp.append(h)
		for g in neighbors(h):
			var k: FieldData = g
			if k.stage == f.stage and not seen.has(k.id):
				seen[k.id] = true
				todo.append(k)
	return comp


## Welches Feld einer Reihe steigt auf? Das, das zuletzt dazugekommen ist (von der Drehung bewegt
## bzw. bei einer Kettenreaktion gerade verändert). Liegt die ganze Reihe in der gedrehten Scheibe, die Mitte.
static func target_index(line: Array, focus: Dictionary, prefer: int = -1) -> int:
	for i in line.size():
		if (line[i] as FieldData).id == prefer:
			return i
	var hits: Array = []
	for i in line.size():
		if focus.has((line[i] as FieldData).id):
			hits.append(i)
	if hits.size() == 1 or (line.size() > 3 and not hits.is_empty()):
		return int(hits[0])
	return 1 if line.size() == 3 else 0


## Punkte, die die Reihen bringen, die sich gerade verändert haben (ohne Kettenreaktion).
## Reihen, die es so schon gab, zählen nicht (sie wachsen auch nicht).
func merge_value() -> int:
	var pts := 0
	for line in lines(moved):
		if not counts(line):
			continue
		pts += int(Balance.MERGE_POINTS[(line[1] as FieldData).stage])
	return pts


# =============================================================================
# Runde auswerten
# =============================================================================

## Seiten aus 9 gleichen Feldern, in denen sich gerade etwas verändert hat: Die ganze Seite steigt auf.
func resolve_faces(ev: Array, locked: Dictionary) -> int:
	var total := 0
	for nv in FACE_NORMALS:
		var n: Vector3i = nv
		var face: Array = []
		for f in fields:
			if f.n == n:
				face.append(f)
		var st: int = (face[0] as FieldData).stage
		if st <= 0:
			continue
		var same := true
		var touched := false
		for g in face:
			var h: FieldData = g
			if h.stage != st:
				same = false
			if moved.has(h.id):
				touched = true
		if not same or not touched:
			continue
		var pts: int = int(Balance.MERGE_POINTS[st]) * Balance.FACE_BONUS
		var ids: Array = []
		var center := -1
		for g in face:
			var h: FieldData = g
			h.stage = mini(Balance.MAX_STAGE, st + 1)
			h.burning = false
			locked[h.id] = true
			ids.append(h.id)
			if h.p == n:
				center = h.id
		total += pts
		ev.append({"type": "face", "field": center, "fields": ids, "points": pts, "stage": mini(Balance.MAX_STAGE, st + 1)})
	return total


## Verschmilzt Reihen aus drei gleichen Feldern, in denen sich gerade etwas verändert hat,
## dann Kettenreaktionen. Ganze Seiten zuerst. Gibt die Punkte zurück.
## Jede Reihe, die neu dasteht, verschmilzt (auch zwei Reihen derselben Drehung, die sich ein Feld teilen).
## late: Ereignisse für Reihen, die erst am Rundenende entstanden sind (z. B. durch Feuer), werden danach gezeigt.
func resolve_merges(ev: Array, late: bool = false) -> int:
	var locked := {}
	var total := resolve_faces(ev, locked)
	var combo := 0
	var focus := moved.duplicate()
	var done := {}      # Einfach: was in diesem Zug schon aufgestiegen ist, steigt nicht gleich nochmal
	var told := {}
	for pass_i in Balance.MAX_CASCADES:
		if focus.is_empty():
			break
		var found: Array = []
		for ln in lines(focus):
			# nur neu gebildete Reihen lösen aus (im ersten Durchgang; danach ist jede gefundene Reihe neu)
			if pass_i == 0 and not counts(ln):
				var k := line_key(ln)
				if (broken.has(k) or spent.has(k)) and not standing.has(k) and not told.has(k):
					told[k] = true
					var rids: Array = []
					for g in ln:
						rids.append((g as FieldData).id)
					# hin und zurück (oder eine zusammen aufgestiegene Reihe wieder zusammengedreht): zählt nicht
					ev.append({"type": "repeat", "fields": rids, "spent": spent.has(k) and not broken.has(k)})
				continue
			found.append(ln)
		if found.is_empty():
			break
		var last_focus := focus
		focus = {}
		for line in found:
			# Hat eine Verschmelzung davor ein Feld dieser Reihe verändert, steht sie nicht mehr
			if not _still_line(line):
				continue
			var skip := false
			var free: Array = []        # Felder, die in diesem Zug noch nicht aufgestiegen sind
			for i in line.size():
				var fd: FieldData = line[i]
				if locked.has(fd.id):
					skip = true
				if not done.has(fd.id):
					free.append(i)
			if skip or free.is_empty():
				continue                # alle drei sind gerade zusammen aufgestiegen: keine neue Reihe
			var ti := target_index(line, moved if pass_i == 0 else last_focus, tapped)
			if not free.has(ti):
				ti = 1 if free.has(1) else int(free[0])
			var mid: FieldData = line[ti]
			if easy:
				# Einfach: Eine neue Reihe löst aus, dann steigen die Reihe und alle gleichen Felder auf, die damit
				# zusammenhängen (außer dem, was in diesem Zug schon aufgestiegen ist). Nichts verschwindet.
				combo += 1
				var st0 := mid.stage
				var grp: Array = []
				var in_grp := {}
				for i in free:
					for g in group_of(line[int(i)] as FieldData):
						var gd: FieldData = g
						if not in_grp.has(gd.id) and not done.has(gd.id):
							in_grp[gd.id] = true
							grp.append(gd)
				var gpts: int = int(Balance.MERGE_POINTS[st0]) * combo * maxi(grp.size(), 3) / 3
				total += gpts
				var gids: Array = []
				for g in grp:
					var h: FieldData = g
					h.burning = false
					done[h.id] = true
					h.stage = mini(Balance.MAX_STAGE, st0 + 1)
					focus[h.id] = true
					if h != mid:
						gids.append(h.id)
				ev.append({"type": "merge", "field": mid.id, "others": gids, "points": gpts, "combo": combo, "stage": mid.stage, "all": true, "late": late})
				continue
			var rest: Array = []
			for i in line.size():
				if i != ti:
					rest.append(line[i])
			combo += 1          # jede weitere Verschmelzung im selben Zug zählt mehr (Kombo)
			var pts: int = int(Balance.MERGE_POINTS[mid.stage]) * combo
			total += pts
			var was := mid.stage
			if mid.stage < Balance.MAX_STAGE:
				mid.stage += 1
			mid.burning = false
			focus[mid.id] = true
			var other_ids: Array = []
			for g in rest:
				var o: FieldData = g
				other_ids.append(o.id)
				if Balance.OTHERS_DROP > 0:
					o.stage = maxi(0, was - Balance.OTHERS_DROP)
					focus[o.id] = true
			ev.append({"type": "merge", "field": mid.id, "others": other_ids, "points": pts, "combo": combo, "stage": mid.stage, "late": late})
	# Einfach: Reihen, deren drei Felder alle gerade zusammen aufgestiegen sind, hat nicht der Spieler gebildet.
	# Sie zählen nie wieder (sonst: auflösen, anderer Zug, zurückdrehen, und die ganze Gruppe steigt erneut).
	if not done.is_empty():
		for ln in lines():
			var all_done := true
			for g in ln:
				if not done.has((g as FieldData).id):
					all_done = false
			if all_done:
				spent[line_key(ln)] = true
	return total


## Wertet den Zug aus. Deterministisch (kein Zufall), damit die Vorschau stimmt.
## Gibt {"events": Array, "gain": int, "bonus_gained": {"rain": n, "bolt": n}} zurück.
func end_round() -> Dictionary:
	var ev: Array = []
	var corners := touched_corners()
	# 1. Drei in einer Reihe verschmelzen sofort
	var gain := resolve_merges(ev)
	moved = {}
	tapped = -1
	var dirty := {}             # was sich nach dem Verschmelzen verändert: bildet es eine Reihe, verschmilzt sie noch in dieser Runde

	# 2. Großstädte und Metropolen zerstören Natur daneben
	for f in fields:
		if f.stage < Balance.POLLUTION_FROM:
			continue
		var left := Balance.POLLUTION_PER_FIELD
		for g in neighbors(f):
			if left <= 0:
				break
			if g.is_nature():
				g.stage = 0
				g.fresh = 2
				g.burning = false
				left -= 1
				dirty[g.id] = true
				ev.append({"type": "polluted", "field": g.id})

	# 3. Leere Erde wird wieder Wiese (nur wenn eingeschaltet)
	if Balance.REGROW_PER_ROUND > 0:
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
		for item in grow.slice(0, Balance.REGROW_PER_ROUND):
			var f: FieldData = item[2]
			f.stage = 1
			dirty[f.id] = true
			ev.append({"type": "regrow", "field": f.id})
	for f in fields:
		if f.fresh > 0:
			f.fresh -= 1

	# 4. Was brennt, verliert eine Stufe, dann ist das Feuer aus
	for f in fields:
		if not f.burning:
			continue
		f.stage = maxi(0, f.stage - 1)
		f.burning = false
		dirty[f.id] = true
		ev.append({"type": "burn", "field": f.id})
	# Hat das eine neue Reihe ergeben (z. B. ein Feld ist abgebrannt und passt jetzt zu den Nachbarn)?
	# Dann verschmilzt sie gleich (wird nach dem Brand gezeigt). Weil man das Wachsen sieht, ist der Zug dann kein Fehlversuch.
	var late_gain := 0
	if not dirty.is_empty():
		moved = dirty
		late_gain = resolve_merges(ev, true)
		moved = {}

	# 5. Punkte, Fortschritt, Boni
	var pr := _progress(gain + late_gain, corners)
	var got: Dictionary = pr["got"]

	# 6. Fehlversuch? Beim dritten brennt die zuletzt gedrehte Reihe
	if _rotated:
		twists += 1
	if _rotated and gain + late_gain == 0 and not no_fire:
		misses += 1
		var mid_id: int = int(last_row[1]) if last_row.size() == 3 else -1
		var why := ""
		for e in ev:
			if str(e["type"]) == "repeat":
				if bool(e.get("spent", false)):
					if why == "":
						why = "spent"   # eine zusammen aufgestiegene Reihe wieder zusammengedreht: zählt nie wieder
				else:
					why = "repeat"      # nur die Reihe zurückgedreht, die die Drehung davor aufgelöst hat
		ev.append({"type": "miss", "count": misses, "field": mid_id, "why": why})
		if misses >= Balance.FIRE_AFTER:
			misses = 0
			disaster("fire", ev)
	# Was diese Drehung aufgelöst hat, zählt im nächsten Zug nicht beim sofortigen Zurückdrehen.
	# Jeder andere Zug dazwischen (auch ein Blitz) hebt das auf; Regen ist kein Zug und lässt es stehen.
	broken = _broke_now if _rotated else {}
	_broke_now = {}
	_rotated = false

	moved = {}
	turn += 1
	return {"events": ev, "gain": gain + late_gain, "bonus_gained": got, "new_age": bool(pr["new_age"])}


## Punkte gutschreiben, Fortschritt merken, Boni verteilen. corners = neu geschaffte Ecken (Blitz).
func _progress(gain: int, corners: int) -> Dictionary:
	score += gain
	var age_before := age()
	for f in fields:
		best_stage = maxi(best_stage, f.stage)
	var got := {"rain": 0, "bolt": 0, "monsoon": 0}
	if not gadgets:
		var na := age() > age_before
		return {"got": got, "new_age": na}
	if not monsoon_unlocked and best_stage >= Balance.MONSOON_FROM_STAGE:
		monsoon_unlocked = true
		next_monsoon = score + Balance.MONSOON_EVERY
		monsoons = mini(Balance.MONSOON_MAX, monsoons + 1)
		got["monsoon"] = 1
	while monsoon_unlocked and score >= next_monsoon:
		next_monsoon += Balance.MONSOON_EVERY
		if monsoons < Balance.MONSOON_MAX:
			monsoons += 1
			got["monsoon"] = int(got["monsoon"]) + 1
	while score >= next_rain:
		next_rain += Balance.RAIN_EVERY
		if rain < Balance.RAIN_MAX:
			rain += 1
			got["rain"] = int(got["rain"]) + 1
	# Blitz: wer an einer Würfelecke drei gleiche Felder zusammenbringt
	for k in corners:
		if bolts < Balance.BOLT_MAX:
			bolts += 1
			got["bolt"] = int(got["bolt"]) + 1
	var new_age := age() > age_before
	return {"got": got, "new_age": new_age}


## Würfelecken, an denen gerade drei gleiche Felder zusammenkommen (und sich eines davon verändert hat).
func touched_corners() -> int:
	var c := 0
	for x in [-1, 1]:
		for y in [-1, 1]:
			for z in [-1, 1]:
				var p := Vector3i(x, y, z)
				var trio: Array = [field_at(p, Vector3i(x, 0, 0)), field_at(p, Vector3i(0, y, 0)), field_at(p, Vector3i(0, 0, z))]
				var st: int = (trio[0] as FieldData).stage
				if st <= 0:
					continue
				var same := true
				var touched := false
				for g in trio:
					if (g as FieldData).stage != st:
						same = false
					if moved.has((g as FieldData).id):
						touched = true
				if same and touched:
					c += 1
	return c


## Regen (kein ganzer Zug): sofort verschmelzen, was sich ergibt, und Punkte gutschreiben.
func resolve_now() -> Dictionary:
	var ev: Array = []
	var corners := touched_corners()
	var gain := resolve_merges(ev)
	moved = {}
	tapped = -1
	var pr := _progress(gain, corners)
	return {"events": ev, "gain": gain, "bonus_gained": pr["got"], "new_age": bool(pr["new_age"])}


## Die Diagonale einer Seite, die an diesem Eckfeld beginnt (für den Blitz). [] wenn kein Eckfeld.
func corner_diagonal(f: FieldData) -> Array:
	var a := axis_of(f.n)
	var u := (a + 1) % 3
	var v := (a + 2) % 3
	if f.p[u] == 0 or f.p[v] == 0:
		return []
	var out: Array = []
	for t in [1, 0, -1]:
		var p := f.p
		p[u] = f.p[u] * t
		p[v] = f.p[v] * t
		out.append(field_at(p, f.n).id)
	return out


## Die Katastrophe trifft (deterministisch, damit die Vorschau stimmt).
## Ereignis: {"type": "disaster", "kind", "field" (Mitte oder -1), "hit": [ids]}
func disaster(kind: String, ev: Array) -> void:
	var hit: Array = []
	if kind == "fire":
		# Die zuletzt gedrehte Reihe fängt Feuer (leere Erde brennt nicht)
		for i in last_row:
			var f: FieldData = fields[int(i)]
			if f.stage > 0:
				f.burning = true
				hit.append(f.id)
	if hearts and Balance.FIRE_COSTS_LIFE:
		lives -= 1
	disasters += 1
	last_disaster = kind
	var center := int(hit[1]) if hit.size() == 3 else (int(hit[0]) if not hit.is_empty() else -1)
	ev.append({"type": "disaster", "kind": kind, "field": center, "hit": hit})


## Alle Reihen und Spalten (je 3 Felder) auf allen Seiten.
func all_rows() -> Array:
	var out: Array = []
	for nv in FACE_NORMALS:
		var n: Vector3i = nv
		var a := axis_of(n)
		for along in [(a + 1) % 3, (a + 2) % 3]:
			var other: int = 3 - a - along
			for c in [-1, 0, 1]:
				var line: Array = []
				for t in [-1, 0, 1]:
					var p := Vector3i.ZERO
					p[a] = n[a]
					p[other] = c
					p[along] = t
					line.append(field_at(p, n))
				out.append(line)
	return out


func _count_neighbors(f: FieldData, what: String) -> int:
	var c := 0
	for g in neighbors(f):
		var h: FieldData = g
		if (what == "civ" and h.is_civilisation()) or (what == "nature" and h.is_nature()):
			c += 1
	return c


# =============================================================================
# Boni: Regen (ein Feld) und Blitz (eine Reihe)
# =============================================================================

## Die beste Drehung für den Tipp. Schaut zwei Züge voraus: Bringt keine Drehung sofort etwas,
## sucht er die Drehung, nach der eine zweite verschmelzen kann.
## {"axis", "layer", "turns", "points", "steps"} oder {} wenn nichts geht.
func best_move() -> Dictionary:
	var moves: Array = []
	for axis in 3:
		for layer in [-1, 0, 1]:
			for turns in [1, -1, 2]:
				moves.append([axis, layer, turns])
	var best := {}
	var best_pts := 0
	for m in moves:
		var sim := clone()
		sim.moved = {}
		sim.apply_rotation(int(m[0]), int(m[1]), int(m[2]))
		var pts := sim.merge_value()
		if pts > best_pts:
			best_pts = pts
			best = {"axis": m[0], "layer": m[1], "turns": m[2], "points": pts, "steps": 1}
	if not best.is_empty():
		return best
	for m in moves:
		var sim := clone()
		sim.moved = {}
		sim.apply_rotation(int(m[0]), int(m[1]), int(m[2]))
		for m2 in moves:
			if int(m2[0]) == int(m[0]) and int(m2[1]) == int(m[1]):
				continue
			var sim2 := sim.clone()
			sim2.moved = {}
			sim2.broken = sim._broke_now.duplicate()      # gleich zurückdrehen zählt nicht
			sim2.apply_rotation(int(m2[0]), int(m2[1]), int(m2[2]))
			var pts := sim2.merge_value()
			if pts > best_pts:
				best_pts = pts
				best = {"axis": m[0], "layer": m[1], "turns": m[2], "points": pts, "steps": 2}
	return best


## Alle Felder, auf die Regen gerade geht: id -> "fire" (brennt: löschen), "useful" (Wachsen macht eine Reihe
## fertig) oder "grow" (kann wachsen). Damit leuchten die Ziele, ohne dass man „Stufe“ verstehen muss.
func rain_targets() -> Dictionary:
	var out := {}
	if rain <= 0:
		return out
	var useful := rain_spots()
	var low := lowest_stage()
	for f in fields:
		if f.burning:
			out[f.id] = "fire"
		elif useful.has(f.id):
			out[f.id] = "useful"
		elif f.stage == low and f.stage < Balance.MAX_STAGE:
			out[f.id] = "grow"
	return out


## Gibt es eine Drehung, die sofort etwas wachsen lässt? (Schneller als best_move, nur ein Zug.)
func has_quick_move() -> bool:
	for axis in 3:
		for layer in [-1, 0, 1]:
			for turns in [1, -1, 2]:
				var sim := clone()
				sim.moved = {}
				sim.apply_rotation(axis, layer, turns)
				if sim.merge_value() > 0:
					return true
	return false


## Wo lohnt sich Regen gerade? Brennende Felder (löschen) und Felder, deren Aufstieg eine Reihe vervollständigt.
func rain_spots() -> Dictionary:
	var out := {}
	if rain <= 0:
		return out
	var low := lowest_stage()
	for f in fields:
		if f.burning:
			out[f.id] = "fire"
			continue
		if f.stage != low or f.stage >= Balance.MAX_STAGE:
			continue
		f.stage += 1
		var hit := false
		for ln in lines({f.id: true}):
			# nur Reihen, die dann auch wirklich verschmelzen (mit der neuen Stufe stand sie noch nicht da;
			# das sofortige Zurückholen einer gerade aufgelösten Reihe und zusammen aufgestiegene Reihen zählen nicht)
			var lk := line_key(ln)
			if not broken.has(lk) and not spent.has(lk):
				hit = true
		f.stage -= 1
		if hit:
			out[f.id] = "up"
	return out


## "" = geht, sonst der Grund, warum nicht.
func can_bonus(kind: String, f: FieldData) -> String:
	if kind == "rain":
		if rain <= 0:
			return "Nächster Regen bei %d Punkten." % next_rain
		if not f.burning and (f.stage != lowest_stage() or f.stage >= Balance.MAX_STAGE):
			return "Hier geht kein Regen. Tippe auf ein leuchtendes Feld."
	elif kind == "bolt":
		if bolts <= 0:
			return "Einen Blitz gibt es, wenn sich an einer Ecke 3 gleiche treffen."
		if corner_diagonal(f).is_empty():
			return "Tippe auf ein leuchtendes Eckfeld."
	elif kind == "monsoon":
		if monsoons <= 0:
			return "Gerade ist kein Monsun da."
	return ""


## Bonus geschenkt oder gekauft.
func grant(kind: String) -> void:
	if kind == "rain":
		rain += 1
	elif kind == "bolt":
		bolts += 1
	elif kind == "monsoon":
		monsoons += 1


## Regen: Ein brennendes Feld wird gelöscht (nur dieses), sonst steigt ein Feld der aktuell niedrigsten Stufe eine Stufe.
## Blitz: Die ganze Reihe (row, 3 IDs) steigt eine Stufe auf und hört auf zu brennen.
## Was aufsteigt, zählt als zuletzt dazugekommen und kann verschmelzen. Danach wird der Zug normal ausgewertet.
func apply_bonus(kind: String, f: FieldData, row: Array = []) -> void:
	_remember_before()
	tapped = f.id
	var targets: Array = [f]
	if kind == "rain":
		rain -= 1
		if f.burning:
			f.burning = false
			return
	elif kind == "monsoon":
		# Monsun: die ganze Seite des Felds steigt eine Stufe
		monsoons -= 1
		targets = []
		for g in fields:
			if g.n == f.n:
				targets.append(g)
	else:
		bolts -= 1
		targets = []
		var diag := row if not row.is_empty() else corner_diagonal(f)
		for i in diag:
			targets.append(fields[int(i)])
		if targets.is_empty():
			targets = [f]
	for g in targets:
		var h: FieldData = g
		h.burning = false
		if h.stage < Balance.MAX_STAGE:
			h.stage += 1
		h.fresh = 0
		moved[h.id] = true
