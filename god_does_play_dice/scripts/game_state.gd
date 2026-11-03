class_name GameState
extends RefCounted
## Reine Spiellogik, getrennt von der Darstellung. Kopierbar (clone) für die Vorschau.
##
## Eine Runde = eine Drehung (oder Warten). Danach wird die Runde ausgewertet:
##   1. Gefahren an ihrem Platz schlagen ein (Meteor löscht das Feld aus, Gewitter halbiert)
##   2. Vulkane brechen aus (Nachbarn verlieren die Hälfte, Wälder fangen Feuer)
##   3. Feuer brennt (See daneben löscht), springt auf Nachbarwälder über
##   4. Nachbarschaft: Krieg (Kirchen fremder Völker nebeneinander), Handel (Märkte, nur ohne Krieg),
##      Wachstum (Dorf neben freien Wiesen/Seen), Tiere (Lebensraum vs. Jagd)
##   5. Volle Dörfer gründen neue, leere Siedlungen verfallen, Krater werden zu Seen
## Danach können neue Gefahren erscheinen (spawn_hazards), immer mit Vorwarnung.

const NATION_NAMES = ["Rote", "Blaue", "Gelbe", "Grüne"]
const NATION_COLORS = ["#ec5b4f", "#3f86e8", "#f4b72e", "#46b46c"]
const TERRAIN_NAME = {"meadow": "Wiese", "forest": "Wald", "lake": "See", "mountain": "Berg", "crater": "Krater"}
const ANIMAL_NAME = {"meadow": "Hasen", "forest": "Hirsche", "lake": "Enten", "mountain": "Steinböcke", "crater": "Tiere"}
const BUILDING_NAME = {"village": "Dorf", "church": "Kirche", "market": "Markt"}
const HAZARD_NAME = {"meteor": "Meteorit", "storm": "Gewitter", "volcano": "Vulkan"}
const TERRAIN_KEYS = ["meadow", "forest", "lake", "mountain"]

var fields: Array = []        # FieldData, Index = id
var hazards: Array = []       # {"type": "meteor"|"storm", "p": Vector3i, "n": Vector3i, "timer": int}
var turn: int = 1
var peak_people: int = 0
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
	for attempt in 80:
		_roll_world()
		if war_pairs().is_empty():
			break
	peak_people = total_people()


func _roll_world() -> void:
	for f in fields:
		f.terrain = _roll_terrain()
		f.nation = -1
		f.building = ""
		f.people = 0
		f.animals = 0
		f.burning = false
		f.volcano = 0
		f.crater_age = 0
	var spots: Array = []
	for f in fields:
		if f.terrain == "meadow" or f.terrain == "forest":
			spots.append(f)
	_shuffle(spots)
	var i := 0
	for nation in Balance.NATION_COUNT:
		var plan: Array = []
		for v in Balance.START_VILLAGES:
			plan.append("village")
		plan.append("church")
		plan.append("market")
		for b in plan:
			if i >= spots.size():
				break
			var f: FieldData = spots[i]
			i += 1
			f.nation = nation
			f.building = b
			match b:
				"village":
					f.people = Balance.START_VILLAGE_PEOPLE
				"church":
					f.people = Balance.START_CHURCH_PEOPLE
				_:
					f.people = Balance.START_MARKET_PEOPLE
	var wild: Array = []
	for f in fields:
		if not f.settled():
			wild.append(f)
	_shuffle(wild)
	for k in mini(Balance.START_ANIMAL_HERDS, wild.size()):
		var f: FieldData = wild[k]
		f.animals = Balance.START_ANIMALS


func clone() -> GameState:
	var gs := GameState.new()
	gs.turn = turn
	gs.peak_people = peak_people
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


func _roll_terrain() -> String:
	var total := 0
	for k in TERRAIN_KEYS:
		total += int(Balance.TERRAIN_WEIGHTS.get(k, 0))
	var r := rng.randi_range(1, maxi(total, 1))
	for k in TERRAIN_KEYS:
		r -= int(Balance.TERRAIN_WEIGHTS.get(k, 0))
		if r <= 0:
			return k
	return "meadow"


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


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


## Wie ein echter Zauberwürfel: alle Felder der Scheibe drehen mit (auch die Mitten).
func apply_rotation(axis: int, layer: int, turns: int) -> void:
	var d := 1 if turns > 0 else -1
	for i in absi(turns):
		for f in fields:
			if f.p[axis] == layer:
				f.p = rv(f.p, axis, d)
				f.n = rv(f.n, axis, d)
		rebuild_index()


# =============================================================================
# Abfragen
# =============================================================================

static func pair_key(a: int, b: int) -> String:
	return "%d|%d" % [mini(a, b), maxi(a, b)]


## Völkerpaare im Krieg: Kirchen zweier Völker liegen nebeneinander.
func war_pairs() -> Dictionary:
	var out := {}
	for f in fields:
		if f.building != "church" or f.nation < 0:
			continue
		for g in neighbors(f):
			if g.building == "church" and g.nation >= 0 and g.nation != f.nation:
				out[pair_key(f.nation, g.nation)] = true
	return out


## Völkerpaare im Handel: Märkte nebeneinander, ohne Krieg.
func trade_pairs() -> Dictionary:
	var wars := war_pairs()
	var out := {}
	for f in fields:
		if f.building != "market" or f.nation < 0:
			continue
		for g in neighbors(f):
			if g.building == "market" and g.nation >= 0 and g.nation != f.nation:
				var k := pair_key(f.nation, g.nation)
				if not wars.has(k):
					out[k] = true
	return out


func total_people() -> int:
	var c := 0
	for f in fields:
		c += f.people
	return c


func total_animals() -> int:
	var c := 0
	for f in fields:
		c += f.animals
	return c


func nation_people(nation: int) -> int:
	var c := 0
	for f in fields:
		if f.nation == nation:
			c += f.people
	return c


func is_over() -> bool:
	if total_people() <= 0:
		return true
	return Balance.MAX_ROUNDS > 0 and turn > Balance.MAX_ROUNDS


func hazard_at(f: FieldData) -> Dictionary:
	for h in hazards:
		if h["p"] == f.p and h["n"] == f.n:
			return h
	return {}


func _food(f: FieldData) -> int:
	var food := 0
	for g in neighbors(f):
		if not g.settled() and not g.burning and (g.terrain == "meadow" or g.terrain == "lake"):
			food += 1
	return food


## Was passiert mit diesem Feld in der nächsten Auswertung (ohne Gefahren)? Für die Info-Karte.
func field_forecast(f: FieldData) -> Dictionary:
	var wars := war_pairs()
	var out := {"war": 0, "trade": 0, "food": _food(f), "church": false, "hunted": false, "habitat": false}
	for g in neighbors(f):
		if f.settled() and g.settled() and g.nation != f.nation:
			if wars.has(pair_key(f.nation, g.nation)):
				out["war"] += 1
			elif f.building == "market" and g.building == "market":
				out["trade"] += 1
		if f.settled() and g.settled() and g.nation == f.nation and g.building == "church":
			out["church"] = true
		if g.settled() and g.building == "village":
			out["hunted"] = true
		if not g.settled() and g.terrain == f.terrain:
			out["habitat"] = true
	return out


# =============================================================================
# Runde auswerten
# =============================================================================

## Wertet die Runde aus. Deterministisch (kein Zufall), damit die Vorschau stimmt.
## Gibt Ereignisse zurück: [{"type": String, "field": int}]
func end_round() -> Array:
	var ev: Array = []
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
		if f == null:
			continue
		if h["type"] == "meteor":
			ev.append({"type": "meteor", "field": f.id, "lost": f.people})
			_wipe(f)
		else:
			ev.append({"type": "storm", "field": f.id, "lost": ceili(f.people / 2.0)})
			f.people -= ceili(f.people / 2.0)
			f.animals -= ceili(f.animals / 2.0)
			if f.terrain == "forest":
				f.burning = true
	hazards = keep

	# 2. Vulkane
	for f in fields:
		if f.volcano <= 0:
			continue
		f.volcano -= 1
		if f.volcano == 0:
			ev.append({"type": "eruption", "field": f.id})
			for g in neighbors(f):
				g.people -= ceili(g.people / 2.0)
				g.animals = 0
				if g.terrain == "forest":
					g.burning = true

	# 3. Feuer (nur was schon vor dieser Runde brannte)
	var ignite: Array = []
	for f in burning_before:
		if not f.burning:
			continue
		var lake := false
		for g in neighbors(f):
			if g.terrain == "lake":
				lake = true
		if lake:
			f.burning = false
			ev.append({"type": "extinguish", "field": f.id})
			continue
		f.people = maxi(0, f.people - Balance.FIRE_DAMAGE)
		f.animals = 0
		f.burning = false
		f.terrain = "meadow"
		ev.append({"type": "fire", "field": f.id})
		for g in neighbors(f):
			if g.terrain == "forest" and not g.burning and not ignite.has(g):
				ignite.append(g)
	for g in ignite:
		g.burning = true

	# 4. Nachbarschaft (alle gleichzeitig aus demselben Zustand)
	var wars := war_pairs()
	var dp := {}
	var da := {}
	for f in fields:
		var d := 0
		if f.settled():
			var war_loss := 0
			var trade_gain := 0
			var church := false
			for g in neighbors(f):
				if g.settled() and g.nation != f.nation:
					if wars.has(pair_key(f.nation, g.nation)):
						war_loss += Balance.WAR_LOSS
					elif f.building == "market" and g.building == "market":
						trade_gain += Balance.TRADE_GAIN
				if g.settled() and g.nation == f.nation and g.building == "church":
					church = true
			war_loss = mini(war_loss, Balance.WAR_MAX)
			trade_gain = mini(trade_gain, Balance.TRADE_MAX)
			d = trade_gain - war_loss
			if war_loss > 0:
				ev.append({"type": "war", "field": f.id})
			if trade_gain > 0:
				ev.append({"type": "trade", "field": f.id})
			if f.building == "village":
				var food := _food(f)
				if food >= Balance.GROWTH_FOOD_NEEDED:
					d += 1
				elif food == 0:
					d -= 1
					ev.append({"type": "hunger", "field": f.id})
				if church and food >= 1:
					d += Balance.CHURCH_BONUS
		dp[f.id] = d
		var a := 0
		if not f.settled() and f.animals > 0:
			var hunted := false
			var habitat := false
			for g in neighbors(f):
				if g.settled() and g.building == "village":
					hunted = true
				if not g.settled() and g.terrain == f.terrain:
					habitat = true
			if hunted:
				a = -1
			elif habitat:
				a = 1
		da[f.id] = a
	for f in fields:
		f.people = clampi(f.people + int(dp[f.id]), 0, Balance.MAX_PEOPLE)
		f.animals = clampi(f.animals + int(da[f.id]), 0, Balance.MAX_ANIMALS)

	# 5. Ausbreiten, Verfall, Krater
	for f in fields:
		if f.building == "village" and f.people >= Balance.EXPAND_AT:
			var target: FieldData = null
			for g in neighbors(f):
				if g.settled() or g.burning or g.volcano > 0:
					continue
				if g.terrain == "meadow" and (target == null or target.terrain != "meadow"):
					target = g
				elif g.terrain == "forest" and target == null:
					target = g
			if target != null:
				target.nation = f.nation
				target.building = "village"
				target.people = Balance.NEW_VILLAGE_PEOPLE
				target.animals = 0
				f.people -= Balance.EXPAND_COST
				ev.append({"type": "expand", "field": target.id})
		elif not f.settled() and f.animals >= Balance.MAX_ANIMALS:
			for g in neighbors(f):
				if not g.settled() and g.terrain == f.terrain and g.animals == 0:
					g.animals = 2
					f.animals -= 2
					break
	for f in fields:
		if f.settled() and f.people <= 0:
			f.nation = -1
			f.building = ""
			f.people = 0
			ev.append({"type": "ruin", "field": f.id})
		if f.terrain == "crater":
			f.crater_age += 1
			if f.crater_age >= Balance.CRATER_TO_LAKE:
				f.terrain = "lake"
				f.crater_age = 0
				ev.append({"type": "lake", "field": f.id})

	turn += 1
	peak_people = maxi(peak_people, total_people())
	return ev


func _wipe(f: FieldData) -> void:
	f.people = 0
	f.animals = 0
	f.nation = -1
	f.building = ""
	f.terrain = "crater"
	f.crater_age = 0
	f.burning = false
	f.volcano = 0


## Neue Gefahren (mit Zufall). Gibt die neuen zurück: [{"type", "field"(Vulkan) oder "p","n"}]
func spawn_hazards() -> Array:
	if turn <= Balance.HAZARD_FREE_ROUNDS + 1:
		return []
	var active := hazards.size()
	for f in fields:
		if f.volcano > 0:
			active += 1
	var max_h := mini(Balance.HAZARD_MAX, Balance.HAZARD_MAX_BASE + int((turn - 1) / Balance.HAZARD_MAX_EVERY))
	if active >= max_h:
		return []
	var chance := minf(Balance.HAZARD_CHANCE_MAX, Balance.HAZARD_CHANCE_BASE + Balance.HAZARD_CHANCE_STEP * turn)
	if rng.randf() > chance:
		return []
	var t := _roll_hazard_type()
	if t == "volcano":
		var mountains: Array = []
		for f in fields:
			if f.terrain == "mountain" and f.volcano == 0:
				mountains.append(f)
		if mountains.is_empty():
			t = "storm"
		else:
			var m: FieldData = mountains[rng.randi_range(0, mountains.size() - 1)]
			m.volcano = int(Balance.HAZARD_TIMER["volcano"])
			return [{"type": "volcano", "field": m.id}]
	var pool: Array = []
	if rng.randf() < Balance.HAZARD_TARGET_SETTLED:
		for f in fields:
			if f.settled() and hazard_at(f).is_empty():
				pool.append(f)
	if pool.is_empty():
		for f in fields:
			if hazard_at(f).is_empty():
				pool.append(f)
	if pool.is_empty():
		return []
	var target: FieldData = pool[rng.randi_range(0, pool.size() - 1)]
	var h := {"type": t, "p": target.p, "n": target.n, "timer": int(Balance.HAZARD_TIMER[t])}
	hazards.append(h)
	return [h]


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
