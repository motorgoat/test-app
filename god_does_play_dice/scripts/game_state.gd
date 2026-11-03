class_name GameState
extends RefCounted
## Reine Spiellogik, getrennt von der Darstellung (GDD Kap. 16).
## Lässt sich mit clone() kopieren, damit die KI Drehungen simulieren kann.

# Seiten = Spieler. Index = Spieler-ID. Du bist Gelb (oben).
const FACE_NORMALS = [
	Vector3i(0, 1, 0),   # 0 Gelb (du)
	Vector3i(1, 0, 0),   # 1 Rot
	Vector3i(0, 0, 1),   # 2 Blau
	Vector3i(-1, 0, 0),  # 3 Orange
	Vector3i(0, 0, -1),  # 4 Lila
	Vector3i(0, -1, 0),  # 5 Weiß
]
const PLAYER_NAMES = ["Gelb", "Rot", "Blau", "Orange", "Lila", "Weiß"]
const PLAYER_COLORS = ["#f5c518", "#d8352a", "#1f63d6", "#f2711c", "#8b3fd1", "#f7f5ef"]
const HUMAN := 0

const RES_KEYS = ["gold", "wood", "stone", "food"]
const RES_ICON = {"wood": "🪵", "stone": "🪨", "food": "🌾", "gold": "🪙", "residents": "👤"}
const RES_NAME = {"wood": "Holz", "stone": "Stein", "food": "Nahrung", "gold": "Gold"}
const TERRAIN_KEYS = ["meadow", "forest", "lake", "mountain", "gold"]
const TERRAIN_NAME = {"meadow": "Wiese", "forest": "Wald", "lake": "See", "mountain": "Berg", "gold": "Goldmine"}
const TERRAIN_RES = {"meadow": "food", "forest": "wood", "lake": "food", "mountain": "stone", "gold": "gold"}
const TERRAIN_HUT = {"meadow": "Acker", "forest": "Holzfäller", "lake": "Fischer", "mountain": "Steinbruch", "gold": "Mine"}

var fields: Array = []        # Array von FieldData, Index = id
var players: Array = []       # Array von PlayerData, Index = Spieler-ID = Seite
var pos_owner: Dictionary = {}  # Platz-Schlüssel (p|n) -> Besitzer. Besitz hängt am Platz, nicht am Feld.
var tick: int = 0
var _index: Dictionary = {}   # Platz-Schlüssel -> FieldData


# =============================================================================
# Aufbau
# =============================================================================

func setup(ai_count: int, seed_value: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	ai_count = clampi(ai_count, 1, 5)
	tick = 0
	pos_owner.clear()

	players.clear()
	for i in 6:
		var pl := PlayerData.new()
		pl.id = i
		pl.name = PLAYER_NAMES[i]
		pl.color = Color(PLAYER_COLORS[i])
		pl.human = i == HUMAN
		pl.active = i <= ai_count
		pl.inv = Balance.START_INV.duplicate()
		pl.residents = Balance.START_RESIDENTS
		pl.rotations = Balance.START_ROTATIONS
		pl.stage = 1
		pl.upgrade_tick = 0
		players.append(pl)

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
					f.is_center = _nonzero_count(p) == 1
					if f.is_center:
						f.home = face_index(f.n)
					fields.append(f)

	# Gelände pro Seite: Garantie-Gelände zuerst, Rest gewichtet zufällig.
	for fi in 6:
		var side: Array = []
		for f in fields:
			if f.n == FACE_NORMALS[fi] and not f.is_center:
				side.append(f)
		_shuffle(side, rng)
		for i in side.size():
			var f: FieldData = side[i]
			if i < Balance.GUARANTEED_TERRAIN.size():
				f.terrain = Balance.GUARANTEED_TERRAIN[i]
			else:
				f.terrain = _roll_terrain(rng)

	# Besitz
	for f in fields:
		if f.is_center:
			f.terrain = "meadow"
			f.owner = f.home if players[f.home].active else -1
			continue
		var fi := face_index(f.n)
		if players[fi].active and Balance.START_OWNS_SIDE:
			f.owner = fi
			pos_owner[pos_key(f.p, f.n)] = fi
	rebuild_index()


func clone() -> GameState:
	var gs := GameState.new()
	gs.tick = tick
	gs.pos_owner = pos_owner.duplicate()
	for f in fields:
		gs.fields.append(f.copy())
	for pl in players:
		gs.players.append(pl.copy())
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


static func face_index(n: Vector3i) -> int:
	return FACE_NORMALS.find(n)


## Dreht einen Vektor um 90° um die Achse a (0=x, 1=y, 2=z). d=+1 ist +90° (rechte Hand).
static func rv(v: Vector3i, a: int, d: int) -> Vector3i:
	if a == 0:
		return Vector3i(v.x, -v.z, v.y) if d > 0 else Vector3i(v.x, v.z, -v.y)
	if a == 1:
		return Vector3i(v.z, v.y, -v.x) if d > 0 else Vector3i(-v.z, v.y, v.x)
	return Vector3i(-v.y, v.x, v.z) if d > 0 else Vector3i(v.y, -v.x, v.z)


static func _nonzero_count(p: Vector3i) -> int:
	var c := 0
	for a in 3:
		if p[a] != 0:
			c += 1
	return c


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


static func _roll_terrain(rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in TERRAIN_KEYS:
		total += int(Balance.TERRAIN_WEIGHTS.get(k, 0))
	var r := rng.randi_range(1, maxi(total, 1))
	for k in TERRAIN_KEYS:
		r -= int(Balance.TERRAIN_WEIGHTS.get(k, 0))
		if r <= 0:
			return k
	return "meadow"


func field_at(p: Vector3i, n: Vector3i) -> FieldData:
	return _index.get(pos_key(p, n), null)


func center_of(pid: int) -> FieldData:
	return field_at(FACE_NORMALS[pid], FACE_NORMALS[pid])


## Nachbarn eines Felds: [{"field": FieldData, "cross": bool}] – cross = über die Würfelkante.
func neighbors(f: FieldData) -> Array:
	var out: Array = []
	for a in 3:
		if f.n[a] != 0:
			continue
		for s in [-1, 1]:
			var q := f.p
			q[a] += s
			var g: FieldData
			var cross := false
			if absi(q[a]) <= 1:
				g = field_at(q, f.n)
			else:
				g = field_at(f.p, unit(a, s))
				cross = true
			if g != null:
				out.append({"field": g, "cross": cross})
	return out


## Richtung von Feld f zum Nachbarn q (für Straßen).
static func direction(f: FieldData, q: FieldData) -> Vector3i:
	if f.n == q.n:
		return q.p - f.p
	return q.n


func road_connected(f: FieldData) -> bool:
	if f.roads.is_empty():
		return false
	for nb in neighbors(f):
		var q: FieldData = nb["field"]
		var d1 := direction(f, q)
		var d2 := direction(q, f)
		var has1 := false
		var has2 := false
		for r in f.roads:
			if r["dir"] == d1:
				has1 = true
		for r in q.roads:
			if r["dir"] == d2:
				has2 = true
		if has1 and has2:
			return true
	return false


# =============================================================================
# Drehen (GDD Kap. 9 und 16)
# =============================================================================

## Felder, die eine Drehung der Scheibe (Achse, Ebene) bewegen würde. Zentren nie.
func slice_fields(axis: int, layer: int) -> Array:
	var out: Array = []
	for f in fields:
		if not f.is_center and f.p[axis] == layer:
			out.append(f)
	return out


func rotate_slice(axis: int, layer: int, d: int) -> void:
	var moved := slice_fields(axis, layer)
	for f in moved:
		f.p = rv(f.p, axis, d)
		f.n = rv(f.n, axis, d)
		for r in f.roads:
			r["dir"] = rv(r["dir"], axis, d)
	rebuild_index()
	# Besitz nach Platz neu setzen (GDD Kap. 7)
	for f in moved:
		var new_owner: int = pos_owner.get(pos_key(f.p, f.n), -1)
		if new_owner != f.owner:
			if f.owner >= 0 and f.troops > 0:
				players[f.owner].warriors += f.troops   # Krieger gehen heim
			f.troops = 0
			f.wall = false                            # Mauern verschwinden
			f.owner = new_owner


## turns: 1 = +90°, -1 = −90°, 2 = 180°
func apply_rotation(axis: int, layer: int, turns: int) -> void:
	var d := 1 if turns > 0 else -1
	for i in absi(turns):
		rotate_slice(axis, layer, d)


# =============================================================================
# Wirtschaft
# =============================================================================

static func empty_res() -> Dictionary:
	return {"gold": 0, "wood": 0, "stone": 0, "food": 0}


## Ertrag eines Felds pro Takt für seinen Besitzer (Gold aus Feld-Stufe ungedeckelt).
func field_yield(f: FieldData) -> Dictionary:
	var out := empty_res()
	if f.is_center or f.owner < 0 or f.level <= 0:
		return out
	var res: String = TERRAIN_RES[f.terrain]
	var mult := Balance.ROAD_YIELD_MULTIPLIER if road_connected(f) else 1
	out[res] += f.level * mult
	out["gold"] += f.level * Balance.GOLD_PER_FIELD_LEVEL
	return out


func income(pid: int) -> Dictionary:
	var out := empty_res()
	var pl: PlayerData = players[pid]
	if not pl.active:
		return out
	var levels := 0
	for f in fields:
		if f.is_center or f.owner != pid or f.level <= 0:
			continue
		levels += f.level
		var res: String = TERRAIN_RES[f.terrain]
		var mult := Balance.ROAD_YIELD_MULTIPLIER if road_connected(f) else 1
		out[res] += f.level * mult
	var field_gold := levels * Balance.GOLD_PER_FIELD_LEVEL
	if Balance.FIELD_GOLD_CAP > 0:
		field_gold = mini(field_gold, Balance.FIELD_GOLD_CAP)
	out["gold"] += pl.stage * Balance.GOLD_PER_CENTER_STAGE + field_gold
	return out


static func res_value(res: Dictionary) -> float:
	var v := 0.0
	for k in res:
		v += float(res[k])
	return v


func income_value(pid: int) -> float:
	return res_value(income(pid))


## Erträge aller Spieler gutschreiben. Gibt {pid: Ertrag} zurück.
func collect_income() -> Dictionary:
	var all := {}
	for pl in players:
		if not pl.active:
			continue
		var inc := income(pl.id)
		for k in inc:
			pl.inv[k] = int(pl.inv.get(k, 0)) + int(inc[k])
		all[pl.id] = inc
	return all


func territory(pid: int) -> int:
	var c := 0
	for f in fields:
		if not f.is_center and f.owner == pid:
			c += 1
	return c


func total_levels(pid: int) -> int:
	var c := 0
	for f in fields:
		if not f.is_center and f.owner == pid:
			c += f.level
	return c


# =============================================================================
# Kosten
# =============================================================================

static func cost_text(cost: Dictionary, residents: int = 0) -> String:
	var parts := PackedStringArray()
	if residents > 0:
		parts.append("%s%d" % [RES_ICON["residents"], residents])
	for k in RES_KEYS:
		if int(cost.get(k, 0)) > 0:
			parts.append("%d%s" % [int(cost[k]), RES_ICON[k]])
	return " ".join(parts)


func can_afford(pid: int, cost: Dictionary) -> bool:
	return missing(pid, cost).is_empty()


func missing(pid: int, cost: Dictionary) -> Dictionary:
	var pl: PlayerData = players[pid]
	var out := {}
	for k in cost:
		var lack: int = int(cost[k]) - int(pl.inv.get(k, 0))
		if lack > 0:
			out[k] = lack
	return out


func pay(pid: int, cost: Dictionary) -> void:
	var pl: PlayerData = players[pid]
	for k in cost:
		pl.inv[k] = int(pl.inv.get(k, 0)) - int(cost[k])


func _lack_text(pid: int, cost: Dictionary) -> String:
	return "Dir fehlen noch " + cost_text(missing(pid, cost))


# =============================================================================
# Aktionen: Fehlertext ("" = möglich) und Ausführung
# =============================================================================

# --- Bewohner kaufen ---------------------------------------------------------

func resident_price(pid: int) -> int:
	var pl: PlayerData = players[pid]
	return Balance.RESIDENT_BASE_PRICE + Balance.RESIDENT_PRICE_STEP * int(pl.residents_bought / maxi(1, Balance.RESIDENT_PRICE_STEP_EVERY))


func buy_resident_error(pid: int) -> String:
	var cost := {"gold": resident_price(pid)}
	if not can_afford(pid, cost):
		return _lack_text(pid, cost)
	return ""


func buy_resident(pid: int) -> void:
	var pl: PlayerData = players[pid]
	pay(pid, {"gold": resident_price(pid)})
	pl.residents_bought += 1
	pl.residents += 1


# --- Feld ausbauen -----------------------------------------------------------

static func upgrade_cost(level: int) -> Dictionary:
	if level < 1 or level >= Balance.FIELD_UPGRADE_COST.size():
		return {}
	return Balance.FIELD_UPGRADE_COST[level]


func max_field_level(pid: int) -> int:
	return mini(players[pid].stage, Balance.MAX_FIELD_LEVEL)


func upgrade_error(pid: int, f: FieldData) -> String:
	if f.is_center:
		return "Das Zentrum baust du mit dem Ausbau-Knopf aus"
	if f.owner != pid:
		return "Nicht dein Feld"
	var target := f.level + 1
	if target > Balance.MAX_FIELD_LEVEL:
		return "Voll ausgebaut"
	if target > max_field_level(pid):
		return "Felder gehen erst bis Stufe %d. Bau zuerst dein Zentrum aus." % max_field_level(pid)
	var pl: PlayerData = players[pid]
	if pl.residents < Balance.FIELD_UPGRADE_RESIDENTS:
		return "Kein freier Bewohner. Tipp dein Zentrum an und kauf einen."
	var cost := upgrade_cost(target)
	if not can_afford(pid, cost):
		return _lack_text(pid, cost)
	return ""


func upgrade_field(pid: int, f: FieldData) -> void:
	var target := f.level + 1
	pay(pid, upgrade_cost(target))
	players[pid].residents -= Balance.FIELD_UPGRADE_RESIDENTS
	f.level = target


# --- Freies Feld kaufen ------------------------------------------------------

func _is_own_side(pid: int, f: FieldData) -> bool:
	return f.n == FACE_NORMALS[pid]


func field_price(pid: int, f: FieldData) -> int:
	if not Balance.START_OWNS_SIDE and _is_own_side(pid, f):
		return Balance.OWN_SIDE_FIELD_PRICE
	return Balance.FIELD_BASE_PRICE + Balance.FIELD_PRICE_STEP * players[pid].fields_bought


func buy_field_error(pid: int, f: FieldData) -> String:
	if f.is_center:
		return "Zentren kann man nicht kaufen"
	if f.owner == pid:
		return "Gehört dir schon"
	if f.owner >= 0:
		return "Gehört %s. Fremde Felder kann man nicht kaufen." % players[f.owner].name
	var touches := false
	var touches_same_side := false
	for nb in neighbors(f):
		var g: FieldData = nb["field"]
		if g.owner == pid:
			touches = true
			if not nb["cross"]:
				touches_same_side = true
	if not touches:
		return "Grenzt nicht an dein Gebiet"
	if not touches_same_side and players[pid].stage < Balance.CROSS_EDGE_MIN_STAGE:
		return "Über die Würfelkante erst ab %s (Stufe %d)" % [Balance.STAGE_NAMES[Balance.CROSS_EDGE_MIN_STAGE], Balance.CROSS_EDGE_MIN_STAGE]
	var cost := {"gold": field_price(pid, f)}
	if not can_afford(pid, cost):
		return _lack_text(pid, cost)
	return ""


func buy_field(pid: int, f: FieldData) -> void:
	var price := field_price(pid, f)
	if Balance.START_OWNS_SIDE or not _is_own_side(pid, f):
		players[pid].fields_bought += 1
	pay(pid, {"gold": price})
	f.owner = pid
	pos_owner[pos_key(f.p, f.n)] = pid


# --- Zentrum ausbauen --------------------------------------------------------

static func stage_cost(stage: int) -> Dictionary:
	if stage < 2 or stage >= Balance.STAGE_COST.size():
		return {}
	return Balance.STAGE_COST[stage]


func stage_wait(pid: int) -> int:
	return maxi(0, Balance.STAGE_COOLDOWN_TICKS - (tick - players[pid].upgrade_tick))


func stage_up_error(pid: int) -> String:
	var pl: PlayerData = players[pid]
	if pl.stage >= Balance.MAX_STAGE:
		return "Höchste Stufe erreicht"
	var wait := stage_wait(pid)
	if wait > 0:
		return "Nächster Ausbau in %d %s möglich" % [wait, "Takt" if wait == 1 else "Takten"]
	var cost := stage_cost(pl.stage + 1)
	if not can_afford(pid, cost):
		return _lack_text(pid, cost)
	return ""


func stage_up(pid: int) -> void:
	var pl: PlayerData = players[pid]
	pay(pid, stage_cost(pl.stage + 1))
	pl.stage += 1
	pl.upgrade_tick = tick
	pl.rotations += Balance.ROTATIONS_PER_STAGE_UP


static func stage_benefits(stage: int) -> String:
	match stage:
		1:
			return "+1🪙 pro Takt, Felder bis Stufe 1"
		2:
			return "+1🪙, Felder bis Stufe 2, Kauf über die Würfelkante, +1 Drehung"
		3:
			return "+1🪙, Felder bis Stufe 3, Tausch 3:1, +1 Drehung"
		4:
			return "+1🪙, Felder bis Stufe 4, +1 Drehung"
		5:
			return "+1🪙, +1 Drehung"
	return ""


# --- Markt -------------------------------------------------------------------

func trade_error(pid: int, give: String, get_res: String) -> String:
	var pl: PlayerData = players[pid]
	if pl.stage < Balance.MARKET_STAGE:
		return "Tauschen geht erst ab %s" % Balance.STAGE_NAMES[Balance.MARKET_STAGE]
	if give == get_res:
		return "Zwei verschiedene Rohstoffe wählen"
	if int(pl.inv.get(give, 0)) < Balance.TRADE_RATE:
		return "Braucht %d %s" % [Balance.TRADE_RATE, RES_NAME[give]]
	return ""


func trade(pid: int, give: String, get_res: String) -> void:
	var pl: PlayerData = players[pid]
	pl.inv[give] = int(pl.inv[give]) - Balance.TRADE_RATE
	pl.inv[get_res] = int(pl.inv.get(get_res, 0)) + 1


# =============================================================================
# Sieg (GDD Kap. 13)
# =============================================================================

## Gibt die Spieler-ID des Siegers zurück oder −1.
func winner() -> int:
	var best := -1
	var best_score := -1.0
	var someone_reached := false
	for pl in players:
		if not pl.active:
			continue
		var t := territory(pl.id)
		if t >= Balance.WIN_FIELDS:
			someone_reached = true
		var score: float = t * 1000.0 + total_levels(pl.id) + pl.stage * 0.01
		if score > best_score:
			best_score = score
			best = pl.id
	if someone_reached:
		return best
	if Balance.TIME_LIMIT_TICKS > 0 and tick >= Balance.TIME_LIMIT_TICKS:
		return best
	return -1
