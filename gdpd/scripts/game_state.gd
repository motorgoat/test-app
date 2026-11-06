class_name GameState
extends RefCounted
## Reine Spiellogik von gdpd, getrennt von der Darstellung. Kopierbar (clone) für Vorschau, Tipp, Bot und Rückgängig.
## Regeln: docs/GDPD_REGELN.md, dazu docs/GDPD_7_TAGE.md (neuer Baum, die 7 Tage). Kurz:
##   1. Start: freies Spiel – Wiesen, Erde und etwas Wasser, nach Sticker-Art verteilt, keine fertige Reihe.
##      Ein Tag (setup_day) – ein fester Start aus dem Pool des Tages.
##   2. Drei gleiche Felder in einer NEUEN Reihe wachsen (ab Stufe 2 auch diagonal, Einfach ab 1, Schwer nie):
##      Das Feld, das zuletzt dazugekommen ist, wird die nächste Art (FieldData.NEXT), die anderen bleiben.
##      Erde → Wiese → Wald → Großer Wald → Tiere → Hütte → Haus → Dorf → … Wasser bildet nie eine Reihe.
##      An vier Stellen wählt der Spieler („Dein Wille geschehe“): Wiese, Dorf, Stadt, Tiere (an einem Tag nur die,
##      die der Tag freischaltet; is_choice). Eine Art, deren nächste Art heute noch nicht freigeschaltet ist, ruht.
##      Pro Zug gibt es höchstens eine Karte (card); jede andere Wahl im selben Zug nimmt die Gewohnheit (will).
##   3. Fertige Felder (Kirche, Industrie, Metropole, Paradies) wachsen nicht und bilden keine Reihe,
##      bringen aber jede Drehung Glauben (nicht bei Smog).
##   4. Glaube ist die Hauptzahl: Wachsen, fertige Felder, erfüllte Wünsche. Krieg, Gewitter und Flut kosten Glauben.
##   5. Krieg: Zwei Kirchen verschiedener Gemeinden, die eine Drehung zusammenbringt, werden Haus.
##   6. Weltwaage W (−100 Natur … +100 Stadt). Ab W ≥ 50 Smog: kein Glaube, Industrie lässt Natur welken, kein Nachwachsen.
##   7. Wünsche der Menschen (Sprechblase an einem Feld), Fehlversuche, Feuer und Herzen wie im Würfelspiel.
##   8. Vollendet: genug fertige Felder und die Waage nicht im Roten (freies Spiel).
##   9. Ein Tag: ein Ziel (goal_progress/goal_target), begrenzte Drehungen (day_limit), 1–3 Sterne. Gewonnen, sobald das
##      Ziel erreicht ist; verloren, wenn die Drehungen aus sind (Tag 6 auch bei Krieg). Keine Herzen an den Tagen.

const STAGE_NAME = FieldData.KIND_NAME      # alte Namen (Oberfläche aus dem Würfelspiel)
const STAGE_SHORT = FieldData.KIND_SHORT
const STAGE_ICON = FieldData.KIND_ICON
const DISASTER_NAME = {"fire": "Feuer"}
const DISASTER_WHY = {"fire": "3 Flammen"}
const FACE_NORMALS = [Vector3i(0, 1, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1), Vector3i(0, -1, 0)]
## Alle 27 Drehungen: [Achse, Scheibe, Vierteldrehungen].
const MOVES = [[0, -1, 1], [0, -1, -1], [0, -1, 2], [0, 0, 1], [0, 0, -1], [0, 0, 2], [0, 1, 1], [0, 1, -1], [0, 1, 2],
	[1, -1, 1], [1, -1, -1], [1, -1, 2], [1, 0, 1], [1, 0, -1], [1, 0, 2], [1, 1, 1], [1, 1, -1], [1, 1, 2],
	[2, -1, 1], [2, -1, -1], [2, -1, 2], [2, 0, 1], [2, 0, -1], [2, 0, 2], [2, 1, 1], [2, 1, -1], [2, 1, 2]]
## Regen: Erde → Wiese → Wald → Großer Wald (nie eine Karte).
const RAIN_NEXT = {FieldData.EMPTY: FieldData.MEADOW, FieldData.MEADOW: FieldData.FOREST, FieldData.FOREST: FieldData.BIGFOREST}
## Wünsche: Typ → Arten, die neben dem Feld stehen müssen (Regen: Regen auf dieselbe Seite).
const WISH_WANT = {"wald": [FieldData.FOREST, FieldData.BIGFOREST], "tiere": [FieldData.ANIMALS, FieldData.PARADISE], "acker": [FieldData.FIELD]}
const WISH_ICON = {"wald": "smallforest", "tiere": "paw", "acker": "field", "regen": "rain"}
const WISH_TEXT = {"wald": "Wald, bitte!", "tiere": "Tiere, bitte!",
	"acker": "Acker, bitte!", "regen": "Regen, bitte!"}
## Zonen der Weltwaage.
const ZONE_NAME = {"wild": "Wildnis", "ok": "Gleichgewicht", "city": "Viel Stadt", "smog": "Smog"}

var fields: Array = []        # FieldData, Index = id
var turn: int = 1
var faith: int = 0            # Glaube: die Hauptzahl (ist auch der Rekord)
var faith_earned: int = 0     # je verdienter Glaube (wird nie weniger): Monsun
var rain: int = 1             # Regen
var bolts: int = 0            # Blitze
var monsoons: int = 0         # Monsune (ganze Seite), ab dem ersten Haus
var monsoon_unlocked := false
var next_monsoon: int = 0     # ab so viel verdientem Glauben der nächste Monsun
var next_rain: int = 0        # bei dieser Drehung kommt der nächste Regen
var misses: int = 0           # Fehlversuche seit dem letzten Brand
var last_row: Array = []      # IDs der zuletzt gedrehten Reihe (brennt beim 3. Fehlversuch)
var _rotated := false         # dieser Zug war eine Drehung
var twists: int = 0           # Drehungen bisher
var tapped := -1              # angetipptes Feld eines Werkzeugs: wächst beim Verschmelzen bevorzugt
var standing := {}            # Reihen, die zu Beginn dieses Zugs schon dastanden: zählen nicht
var broken := {}              # Reihen, die die letzte Drehung aufgelöst hat: sofort zurückdrehen zählt nicht
var _broke_now := {}
var spent := {}               # Einfach: Reihen, die als ganze Gruppe zusammen gewachsen sind (zählen nie wieder)
var lives: int = 3            # Herzen
var max_lives: int = 3
var hearts := true
var no_fire := false          # Tutorial: Fehlversuche zählen nicht, nichts brennt
var calm := false             # Tutorial: kein Glaube pro Drehung, kein Nachwachsen, kein Smog, keine Wünsche
var disasters: int = 0
var last_disaster := ""
var moved: Dictionary = {}    # IDs der Felder, die sich in diesem Zug verändert/bewegt haben
var endless := true           # offen oder 40 Drehungen (Challenge)
var easy := false             # Einfach: ganze Gruppen wachsen mit
var diagonals := true
var gadgets := true
var diag_from := 2            # ab dieser Stufe zählen Diagonalen
var level := 1                # 0 Einfach, 1 Mittel, 2 Schwer
var rng := RandomNumberGenerator.new()
var _index: Dictionary = {}

# --- gdpd ---------------------------------------------------------------------------------
var will: Dictionary = {}     # Gewohnheit: Art mit Wahl → 0/1 (die letzte Antwort). Standard der Karte.
var answers: Dictionary = {}  # Antworten für diesen Zug (Art → 0/1). Gilt nur für die Karten-Art.
var card: int = -1            # Art der Karte dieses Zugs (-1: keine Wahl)
var card_field: int = -1      # Feld, an dem die Karte zuerst gebraucht wurde
var card_fields: Array = []   # alle Felder, die in diesem Zug aus der Karten-Art gewachsen sind
var wishes: Array = []        # {"id", "type", "field", "left"}
var wish_seq: int = 0
var completed := false        # Vollendet!
var ever: Dictionary = {}     # Art → true: je gebaut (Zeitalter, Aufdecken)
var stats: Dictionary = {}    # Zähler (Kriege, Smog, Wünsche …) für Bot und Auswertung
var wild_twists: int = 0      # Drehungen in Folge mit W ≤ −80 und ganz ohne Menschen (Hinweis)
var last_grew: int = 0        # wie oft im letzten Zug etwas gewachsen ist
var _turn_open := false
var _church0: Dictionary = {} # Kirche → Gemeinde (Nummer) zu Beginn des Zugs
var _w0: int = 0              # Weltwaage zu Beginn des Zugs
var _grew: int = 0
var _pre_ev: Array = []       # Ereignisse eines Werkzeugs (vor dem Auswerten)
var _pre_gain: int = 0        # Glaube eines Werkzeugs (erfüllter Regen-Wunsch)

# --- Regeln, die ein Tag ein- und ausschaltet (freies Spiel: alles an) -------------------------
var day: Dictionary = {}      # Konfiguration des Tages (Days.config); {} = freies Spiel
var day_no: int = 0           # 1 … 7 (0 = freies Spiel)
var made: Array = []          # Art → so oft ist ein Feld durch Wachsen zu dieser Art geworden (wird nie weniger)
var day_limit: int = 0        # Drehungen für diesen Versuch (Grenze + Gnade)
var day_won := false
var day_lost := ""            # "" | "twists" | "war" | "fire"
var day_won_at: int = 0       # bei so vielen Drehungen gewonnen
## „Weiterbauen“ nach dem Sieg (GDPD_TAEGLICH_CHARAKTER.md 2.2): keine Drehungs-Grenze, kein Scheitern, die Sterne
## bleiben die des Sieges. build_made0: so viel war bis zum Sieg gewachsen (Wachstums-Zähler, Münzen).
var day_free_build := false
var build_made0: int = 0
var unlocked: Dictionary = {} # Art → true: darf heute entstehen
var choices_on: Dictionary = {}   # Art → true: ihre Wahl-Karte ist aktiv (wenn Option 2 freigeschaltet ist)
var sys_wishes := true
var sys_scale := true         # Weltwaage sichtbar und für die Wunsch-Arten benutzt
var sys_income := true
var sys_war := true
var no_war := false           # Krieg lässt den Tag scheitern
var sys_smog := true
var sys_regrow := true
var sys_strike := true        # Gewitter
var sys_flood := true         # Flut
var sys_bolts := true         # Blitz
var sys_monsoon := true       # Monsun
var sys_gift := false         # an einem Tag: nichts passt mehr zusammen → ein Regen (freies Spiel: Game macht das)
var rain_every: int = 5       # alle so viele Drehungen ein Regen (0 = nie)
var wish_from: int = 3
var wish_every: int = 4
var wish_types: Array = ["wald", "tiere", "acker", "regen"]
var use_lcg := false          # Tage: Wünsche mit dem einfachen Zufall des Python-Modells (genaue Wiederholung)
var lcg: int = 0
var _row_ok: Array = []       # Art → bildet heute eine Reihe
var _goal0: int = 0           # Ziel-Fortschritt zu Beginn des Zugs
var gift_twists: int = 0      # Tag 1: die vorgeführte Drehung („Schau zu!“) kostet keine Drehung und keinen Stern
var _eq0: Dictionary = {}     # vor dem Zug: alle Dreier aus gleichen Feldern (jede Art, auch schräg) → was danach neu ist
var _still_told: Dictionary = {}   # in diesem Zug schon gemeldete stille Reihen
var _still_calm := false      # dieser Zug hat eine ruhende Reihe gebildet: das ist kein Fehlversuch

## Alter Name für faith.
var score: int:
	get:
		return faith
	set(v):
		faith = v
## Alter Name: eine typische Art des erreichten Zeitalters (für Icons). Setzen markiert die Art als gebaut.
var best_stage: int:
	get:
		return int(Balance.AGE_FROM_STAGE[age() - 1])
	set(v):
		ever[v] = true


# =============================================================================
# Aufbau
# =============================================================================

## lvl: 0 Einfach, 1 Mittel, 2 Schwer. with_hearts: Herzen (Standard in allen Modi). Freies Spiel (alle Regeln an).
func setup(seed_value: int = 0, endless_mode: bool = true, lvl: int = 1, with_hearts: bool = true) -> void:
	_reset(seed_value, endless_mode, lvl, with_hearts)
	_apply_free_rules()
	_deal_start_board()


## Ein Tag der Schöpfung: cfg = Days.config(n), kinds = 54 Arten (Brett aus dem Pool, Reihenfolge wie fields),
## seed_value = Seed des Bretts (Zufall der Wünsche), extra_twists = Gnade (+2 je Fehlversuch).
func setup_day(cfg: Dictionary, kinds: Array, seed_value: int = 1, extra_twists: int = 0) -> void:
	_reset(seed_value if seed_value != 0 else 1, true, 2, false)
	_apply_day_rules(cfg, seed_value, extra_twists)
	for i in mini(kinds.size(), fields.size()):
		(fields[i] as FieldData).kind = int(kinds[i])
	ever = {}
	for f in fields:
		ever[f.kind] = true


## Alles auf Anfang (ohne Regeln und ohne Brett).
func _reset(seed_value: int, endless_mode: bool, lvl: int, with_hearts: bool) -> void:
	level = clampi(lvl, 0, 2)
	endless = endless_mode
	hearts = with_hearts
	no_fire = false
	calm = false
	easy = level == 0
	diagonals = level <= 1
	gadgets = true
	diag_from = Balance.DIAGONAL_FROM_EASY if easy else Balance.DIAGONAL_FROM
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	turn = 1
	faith = 0
	faith_earned = 0
	rain = Balance.RAIN_START if gadgets else 0
	bolts = Balance.BOLT_START if gadgets else 0
	rain_every = Balance.RAIN_EVERY_TWISTS
	next_rain = rain_every
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
	max_lives = (Balance.LIVES_EASY if easy else Balance.LIVES) if hearts else 0
	lives = max_lives
	disasters = 0
	last_disaster = ""
	moved = {}
	will = {}
	answers = {}
	card = -1
	card_field = -1
	card_fields = []
	wishes = []
	wish_seq = 0
	completed = false
	ever = {FieldData.MEADOW: true}
	stats = {"wars": 0, "war_churches": 0, "wished": 0, "wish_ok": 0, "wish_fail": 0, "smog": 0, "withered": 0,
		"fires": 0, "choices": 0, "strikes": 0, "floods": 0, "rains": 0, "bolts": 0, "monsoons": 0, "income": 0, "regrow": 0}
	wild_twists = 0
	last_grew = 0
	_turn_open = false
	_church0 = {}
	_pre_ev = []
	_pre_gain = 0
	day = {}
	day_no = 0
	made = []
	for k in FieldData.KIND_COUNT:
		made.append(0)
	day_limit = 0
	gift_twists = 0
	day_won = false
	day_lost = ""
	day_won_at = 0
	day_free_build = false
	build_made0 = 0
	use_lcg = false
	lcg = 0
	_goal0 = 0
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
					f.kind = FieldData.WATER
					fields.append(f)
	rebuild_index()


## Freies Spiel: alle Arten, alle Wahl-Karten (Wiese, Dorf, Stadt, Tiere), alle Systeme.
func _apply_free_rules() -> void:
	unlocked = {}
	for k in FieldData.KIND_COUNT:
		unlocked[k] = true
	choices_on = {}
	for k in FieldData.CHOICE:
		choices_on[int(k)] = true
	sys_wishes = true
	sys_scale = true
	sys_income = true
	sys_war = true
	no_war = false
	sys_smog = true
	sys_regrow = true
	sys_strike = true
	sys_flood = true
	sys_bolts = true
	sys_monsoon = true
	sys_gift = false
	rain_every = Balance.RAIN_EVERY_TWISTS
	next_rain = rain_every
	wish_from = Balance.WISH_FROM_TWIST
	wish_every = Balance.WISH_EVERY
	wish_types = ["wald", "tiere", "acker", "regen"]
	_rebuild_rules()


## Regeln eines Tages (Days.config): nur gerade Reihen, keine Herzen, keine Diagonalen/Gruppen, kein Nachwachsen,
## kein Blitz/Monsun/Flut, kein „Vollendet“. Alles andere schaltet der Tag.
func _apply_day_rules(cfg: Dictionary, seed_value: int, extra_twists: int) -> void:
	day = cfg.duplicate(true)
	day_no = int(cfg.get("day", 0))
	unlocked = {}
	for k in cfg.get("unlocked", []):
		unlocked[int(k)] = true
	choices_on = {}
	for k in cfg.get("choices", []):
		choices_on[int(k)] = true
	no_fire = not bool(cfg.get("fire", true))
	sys_wishes = bool(cfg.get("wishes", false))
	sys_scale = bool(cfg.get("scale", false))
	sys_income = bool(cfg.get("income", false))
	sys_war = bool(cfg.get("war", false))
	no_war = bool(cfg.get("no_war", false))
	sys_smog = bool(cfg.get("smog", false))
	sys_regrow = false
	sys_strike = bool(cfg.get("strike", false))
	sys_flood = false
	sys_bolts = false
	sys_monsoon = false
	sys_gift = bool(cfg.get("gift", false))
	rain = int(cfg.get("rain_start", 0))
	bolts = 0
	rain_every = int(cfg.get("rain_every", 0))
	next_rain = rain_every
	wish_from = int(cfg.get("wish_from", 2))
	wish_every = maxi(1, int(cfg.get("wish_every", 3)))
	wish_types = (cfg.get("wish_types", []) as Array).duplicate()
	day_limit = int(cfg.get("limit", 15)) + maxi(0, extra_twists)
	use_lcg = true
	lcg = (seed_value * 7919 + 17) & 0x7fffffff
	_rebuild_rules()


## Welche Art bildet heute eine Reihe? (Nicht Wasser, nicht fertig, und ihre nächste Art ist freigeschaltet.)
func _rebuild_rules() -> void:
	_row_ok = []
	for k in FieldData.KIND_COUNT:
		var ok := FieldData.can_row(k)
		if ok:
			var nx: int = int(FieldData.NEXT[k])
			ok = nx >= 0 and unlocked.has(nx)
		_row_ok.append(ok)


## Freies Spiel: der Start (GDPD_7_TAGE.md 3.2). Jede Art etwa zur Hälfte auf Ecken, 40 % auf Kanten, 10 % auf
## Mitten (eine gerade Reihe braucht Ecke–Kante–Ecke oder Kante–Mitte–Kante), dann fertige Reihen auflösen.
func _deal_start_board() -> void:
	for attempt in 50:
		_typed_board(Balance.START_KINDS)
		_break_ready_lines()
		if lines().is_empty():
			return


func _typed_board(comp: Dictionary) -> void:
	var free := {3: [], 2: [], 1: []}
	for f in fields:
		(free[FieldData.sticker_type(f.p)] as Array).append(f)
	for t in [3, 2, 1]:
		_shuffle(free[t])
	var order: Array = []
	for k in comp:
		order.append([int(comp[k]), int(k)])
	order.sort_custom(func(x, y): return int(x[0]) > int(y[0]) or (int(x[0]) == int(y[0]) and int(x[1]) < int(y[1])))
	for f in fields:
		f.kind = FieldData.WATER
	for item in order:
		var n: int = int(item[0])
		var k: int = int(item[1])
		var want := {3: int(n * Balance.START_CORNER_SHARE + 0.5), 1: int(n * Balance.START_CENTER_SHARE + rng.randf())}
		want[2] = n - int(want[3]) - int(want[1])
		for t in [3, 2, 1]:
			for i in int(want[t]):
				var tt: int = t
				if (free[tt] as Array).is_empty():
					for t2 in [3, 2, 1]:
						if not (free[t2] as Array).is_empty():
							tt = t2
							break
				if (free[tt] as Array).is_empty():
					break
				((free[tt] as Array).pop_back() as FieldData).kind = k


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Fertige Reihen auflösen: ein Feld der Reihe tauscht mit einem Feld einer anderen Art und derselben Sticker-Art
## (das hält die Verteilung auf Ecken/Kanten), wenn das die Zahl der Reihen senkt.
func _break_ready_lines() -> void:
	for guard in 400:
		var ls := lines()
		if ls.is_empty():
			return
		var hit: Array = ls[0]
		var f: FieldData = hit[rng.randi_range(0, 2)]
		var t := FieldData.sticker_type(f.p)
		var cands: Array = []
		for g in fields:
			if g.kind != f.kind and FieldData.sticker_type(g.p) == t:
				cands.append(g)
		_shuffle(cands)
		var n0 := ls.size()
		for i in mini(12, cands.size()):
			var g: FieldData = cands[i]
			var k := f.kind
			f.kind = g.kind
			g.kind = k
			if lines().size() < n0:
				break
			g.kind = f.kind
			f.kind = k


func clone() -> GameState:
	var gs := GameState.new()
	gs.turn = turn
	gs.endless = endless
	gs.easy = easy
	gs.diagonals = diagonals
	gs.gadgets = gadgets
	gs.diag_from = diag_from
	gs.level = level
	gs.faith = faith
	gs.faith_earned = faith_earned
	gs.rain = rain
	gs.bolts = bolts
	gs.next_rain = next_rain
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
	gs.lives = lives
	gs.max_lives = max_lives
	gs.hearts = hearts
	gs.no_fire = no_fire
	gs.calm = calm
	gs.disasters = disasters
	gs.last_disaster = last_disaster
	gs.moved = moved.duplicate()
	gs.will = will.duplicate()
	gs.answers = answers.duplicate()
	gs.card = card
	gs.card_field = card_field
	gs.card_fields = card_fields.duplicate()
	gs.wishes = wishes.duplicate(true)
	gs.wish_seq = wish_seq
	gs.completed = completed
	gs.ever = ever.duplicate()
	gs.stats = stats.duplicate()
	gs.wild_twists = wild_twists
	gs.last_grew = last_grew
	gs._turn_open = _turn_open
	gs._church0 = _church0.duplicate()
	gs._w0 = _w0
	gs._grew = _grew
	gs._pre_ev = _pre_ev.duplicate(true)
	gs._pre_gain = _pre_gain
	gs.rng.seed = rng.seed
	gs.rng.state = rng.state
	gs.day = day                  # nur gelesen: gemeinsam benutzen
	gs.day_no = day_no
	gs.made = made.duplicate()
	gs.day_limit = day_limit
	gs.day_won = day_won
	gs.day_lost = day_lost
	gs.day_won_at = day_won_at
	gs.day_free_build = day_free_build
	gs.build_made0 = build_made0
	gs.unlocked = unlocked        # nur gelesen
	gs.choices_on = choices_on    # nur gelesen
	gs._row_ok = _row_ok          # nur gelesen
	gs.sys_wishes = sys_wishes
	gs.sys_scale = sys_scale
	gs.sys_income = sys_income
	gs.sys_war = sys_war
	gs.no_war = no_war
	gs.sys_smog = sys_smog
	gs.sys_regrow = sys_regrow
	gs.sys_strike = sys_strike
	gs.sys_flood = sys_flood
	gs.sys_bolts = sys_bolts
	gs.sys_monsoon = sys_monsoon
	gs.sys_gift = sys_gift
	gs.rain_every = rain_every
	gs.wish_from = wish_from
	gs.wish_every = wish_every
	gs.wish_types = wish_types    # nur gelesen
	gs.use_lcg = use_lcg
	gs.lcg = lcg
	gs._goal0 = _goal0
	gs.gift_twists = gift_twists
	gs._eq0 = _eq0               # nur gelesen (wird bei jedem Zug neu angelegt)
	gs._still_told = _still_told.duplicate()
	gs._still_calm = _still_calm
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
	if not _cache_ready:
		_build_cache()
	var out: Array = []
	for k in _NEI[pos_key(f.p, f.n)]:
		out.append(_index[k])
	return out


# Feste Platz-Schlüssel (pos_key) der Reihen und Nachbarn, einmal berechnet (schnell für Vorschau, Tipp und Bot).
static var _cache_ready := false
static var _LINES := PackedInt32Array()      # je 4 Werte: Schlüssel 0, 1, 2 und 1 = schräg (Reihenfolge wie lines())
static var _NEI := {}                        # pos_key → PackedInt32Array der 4 Nachbar-Plätze


static func _build_cache() -> void:
	_LINES = PackedInt32Array()
	for nn in FACE_NORMALS:
		var nv: Vector3i = nn
		var a := axis_of(nv)
		var u := (a + 1) % 3
		var v := (a + 2) % 3
		for fixed in [u, v]:
			var run: int = v if fixed == u else u
			for c in [-1, 0, 1]:
				for t in [-1, 0, 1]:
					var p := Vector3i.ZERO
					p[a] = nv[a]
					p[fixed] = c
					p[run] = t
					_LINES.append(pos_key(p, nv))
				_LINES.append(0)
		for dir in [1, -1]:
			for t in [-1, 0, 1]:
				var p := Vector3i.ZERO
				p[a] = nv[a]
				p[u] = t
				p[v] = t * dir
				_LINES.append(pos_key(p, nv))
			_LINES.append(1)
	_NEI = {}
	for x in [-1, 0, 1]:
		for y in [-1, 0, 1]:
			for z in [-1, 0, 1]:
				var p := Vector3i(x, y, z)
				for a in 3:
					if p[a] == 0:
						continue
					var nv := unit(a, p[a])
					var ks := PackedInt32Array()
					for b in 3:
						if nv[b] != 0:
							continue
						for sg in [-1, 1]:
							var q := p
							q[b] += sg
							if absi(q[b]) <= 1:
								ks.append(pos_key(q, nv))
							else:
								ks.append(pos_key(p, unit(b, sg)))
					_NEI[pos_key(p, nv)] = ks
	_cache_ready = true


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


## Die drei Felder der Scheibe auf der ersten Seite, die sie schneidet.
func slice_row(axis: int, layer: int) -> Array:
	for nv in FACE_NORMALS:
		var nn: Vector3i = nv
		if nn[axis] != 0:
			continue
		var out: Array = []
		for f in fields:
			if f.n == nn and f.p[axis] == layer:
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


## Die 9 Felder der Seite mit dieser Normalen.
func face_fields(nn: Vector3i) -> Array:
	var out: Array = []
	for f in fields:
		if f.n == nn:
			out.append(f)
	return out


# =============================================================================
# Abfragen
# =============================================================================

static func stage_name(k: int) -> String:
	return FieldData.kind_name(k)


static func kind_name(k: int) -> String:
	return FieldData.kind_name(k)


func count(k: int) -> int:
	var c := 0
	for f in fields:
		if f.kind == k:
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


func people_count() -> int:
	var c := 0
	for f in fields:
		if f.is_people():
			c += 1
	return c


## Zeitalter (1 = Urzeit … 7 = Moderne): die fortschrittlichste Zivilisation, die je gebaut wurde.
func age() -> int:
	var a := 0
	for k in ever:
		a = maxi(a, int(FieldData.AGE_OF[clampi(int(k), 0, FieldData.KIND_COUNT - 1)]))
	return a + 1


func age_name() -> String:
	return str(Balance.AGES[age() - 1])


## „Als Nächstes: …“
func next_age_goal() -> String:
	return "Als Nächstes: " + str(Balance.AGE_GOAL[clampi(age() - 1, 0, Balance.AGE_GOAL.size() - 1)])


## Vorbei: Welt verbrannt, 40 Drehungen um (Challenge) oder vollendet. An einem Tag: gewonnen oder gescheitert.
func is_over() -> bool:
	if not day.is_empty():
		if day_free_build:
			return false              # Weiterbauen: nie vorbei
		return day_won or day_lost != ""
	return finished() or died() or completed


## Nichts mehr zu verbinden: keine Art, die eine Reihe bilden kann, hat noch 3 Felder, und es gibt weder Regen noch Blitz.
func stuck() -> bool:
	if rain > 0 or bolts > 0:
		return false
	var cnt := {}
	for f in fields:
		if can_row(f.kind):
			cnt[f.kind] = int(cnt.get(f.kind, 0)) + 1
			if int(cnt[f.kind]) >= 3:
				return false
	return true


func died() -> bool:
	return hearts and lives <= 0


func finished() -> bool:
	return day.is_empty() and not endless and twists >= Balance.MAX_TWISTS


## Weltwaage: −100 (nur Natur) … +100 (nur Stadt). Ohne Gedächtnis, aus dem Brett berechnet.
func balance() -> int:
	var nat := 0
	var civ := 0
	for f in fields:
		nat += int(Balance.NATURE_WEIGHT.get(f.kind, 0))
		civ += int(Balance.CIV_WEIGHT.get(f.kind, 0))
	if nat + civ == 0:
		return 0
	return roundi(100.0 * float(civ - nat) / float(civ + nat))


## Zone der Waage: "wild" (W ≤ −50), "ok", "city" (20 ≤ W < 50), "smog" (W ≥ 50).
static func zone_of(w: int) -> String:
	if w >= Balance.SMOG_AT:
		return "smog"
	if w >= Balance.CITY_AT:
		return "city"
	if w <= Balance.WILD_AT:
		return "wild"
	return "ok"


func zone() -> String:
	return zone_of(balance())


func smog() -> bool:
	return balance() >= Balance.SMOG_AT


## Glaube pro Drehung, den die fertigen Felder gerade bringen würden (0 bei Smog).
func income_rate() -> int:
	if smog():
		return 0
	return income_potential()


func income_potential() -> int:
	var inc := 0
	for f in fields:
		inc += int(Balance.INCOME.get(f.kind, 0))
	return inc


func finished_count() -> int:
	var c := 0
	for f in fields:
		if f.is_finished():
			c += 1
	return c


## So viele fertige Felder braucht die Welt zum Vollenden (0: kein Ziel, Challenge).
func complete_goal() -> int:
	if not endless or not day.is_empty():
		return 0
	return int(Balance.COMPLETE_AT[clampi(level, 0, 2)])


## Werkzeug schon aufgedeckt? Gewitter mit dem ersten fertigen Feld, Flut mit dem ersten Smog.
## An einem Tag: Regen ab Tag 2, Gewitter an Tag 7, Blitz, Monsun und Flut nie.
func tool_unlocked(kind: String) -> bool:
	if not day.is_empty():
		if kind == "rain":
			return int(day.get("rain_start", 0)) > 0 or rain_every > 0
		if kind == "strike":
			return sys_strike
		return false
	if kind == "strike":
		for k in ever:
			if FieldData.finished(int(k)):
				return true
		return false
	if kind == "flood":
		return int(stats.get("smog", 0)) > 0
	return true


## Alle Reihen aus 3 gleichen Feldern, die eine Reihe bilden können (nicht Erde, nicht fertig).
## Mit only: nur Reihen, die mindestens eines dieser Felder enthalten. Das mittlere Feld an Index 1.
func lines(only: Dictionary = {}) -> Array:
	if not _cache_ready:
		_build_cache()
	var out: Array = []
	var any := only.is_empty()
	var i := 0
	var n := _LINES.size()
	while i < n:
		var f0: FieldData = _index[_LINES[i]]
		var k := f0.kind
		if _row_ok[k]:
			var f1: FieldData = _index[_LINES[i + 1]]
			if f1.kind == k:
				var f2: FieldData = _index[_LINES[i + 2]]
				if f2.kind == k and (_LINES[i + 3] == 0 or (diagonals and FieldData.tier(k) >= diag_from)):
					if any or only.has(f0.id) or only.has(f1.id) or only.has(f2.id):
						out.append([f0, f1, f2])
		i += 4
	return out


## Schlüssel einer Reihe: ihre Felder (sortiert) und ihre Art, als Zahl.
static func line_key(line: Array) -> int:
	var a: int = (line[0] as FieldData).id
	var b: int = (line[1] as FieldData).id
	var c: int = (line[2] as FieldData).id
	if a > b:
		var t := a
		a = b
		b = t
	if b > c:
		var t2 := b
		b = c
		c = t2
	if a > b:
		var t3 := a
		a = b
		b = t3
	return ((a * 64 + b) * 64 + c) * 16 + (line[0] as FieldData).kind


## Vor der ersten Änderung eines Zugs: was steht schon da (zählt nicht), welche Kirchen gehören zusammen.
func _remember_before() -> void:
	if not moved.is_empty():
		return
	standing = _line_keys()
	_eq0 = _trio_keys()
	_broke_now = {}
	_open_turn()


## Ein neuer Zug beginnt: Karte leer, Gemeinden der Kirchen merken.
func _open_turn() -> void:
	if _turn_open:
		return
	_turn_open = true
	card = -1
	card_field = -1
	card_fields = []
	_grew = 0
	_pre_ev = []
	_pre_gain = 0
	_church0 = church_groups()
	_w0 = balance()
	_goal0 = goal_progress()
	_still_told = {}
	_still_calm = false


func _line_keys() -> Dictionary:
	var out := {}
	for ln in lines():
		out[line_key(ln)] = true
	return out


## Alle Dreier aus drei gleichen Feldern auf einer Linie einer Seite (gerade und schräg, jede Art, auch Wasser).
func _trio_keys() -> Dictionary:
	if not _cache_ready:
		_build_cache()
	var out := {}
	var i := 0
	var n := _LINES.size()
	while i < n:
		var f0: FieldData = _index[_LINES[i]]
		var f1: FieldData = _index[_LINES[i + 1]]
		if f1.kind == f0.kind:
			var f2: FieldData = _index[_LINES[i + 2]]
			if f2.kind == f0.kind:
				out[line_key([f0, f1, f2])] = true
		i += 4
	return out


## Stille Reihen: Was nach dem Zug als drei gleiche Felder auf einer Linie zu sehen ist, durch ein bewegtes oder
## gewachsenes Feld geht und trotzdem nicht wächst, wird nie verschwiegen. Jede bekommt ein Ereignis
## {"type": "still", "why", "kind", "fields", "diag", "late"} (why: rest, diag, water, finished, repeat, spent,
## standing, other; bei rest dazu "next": die Art, die erst später frei wird). Die Oberfläche markiert die Felder
## und sagt kurz, warum. Eine ruhende Reihe (rest) ist kein Fehlversuch: Der Spieler hat richtig gedreht, die Art
## darf heute nur noch nicht weiter. Alles andere zählt wie bisher (schräg an den Tagen: die Pool-Lösungen bleiben gültig).
## focus: bewegte und gewachsene Felder; changed: Felder, deren Art sich gerade durch Wachsen geändert hat.
func _still_rows(ev: Array, focus: Dictionary, changed: Dictionary, late: bool) -> void:
	if focus.is_empty():
		return
	if not _cache_ready:
		_build_cache()
	var i := 0
	var n := _LINES.size()
	while i < n:
		var f0: FieldData = _index[_LINES[i]]
		var f1: FieldData = _index[_LINES[i + 1]]
		var f2: FieldData = _index[_LINES[i + 2]]
		var diag: bool = _LINES[i + 3] != 0
		i += 4
		var k := f0.kind
		if f1.kind != k or f2.kind != k:
			continue
		if not (focus.has(f0.id) or focus.has(f1.id) or focus.has(f2.id)):
			continue
		if changed.has(f0.id) and changed.has(f1.id) and changed.has(f2.id):
			continue      # ist gerade als Ganzes gewachsen (Einfach, ganze Seite)
		var ln: Array = [f0, f1, f2]
		var key := line_key(ln)
		if _still_told.has(key):
			continue
		var why := _still_why(k, diag, key)
		if why == "":
			continue
		_still_told[key] = true
		if why == "rest":
			_still_calm = true
		var e := {"type": "still", "why": why, "kind": k, "fields": [f0.id, f1.id, f2.id], "diag": diag, "late": late}
		if why == "rest":
			e["next"] = int(FieldData.NEXT[k])
		ev.append(e)


## Warum wächst diese Reihe (Art k, key = line_key) nicht? "" = nichts zu sagen (sie stand schon so da).
func _still_why(k: int, diag: bool, key: int) -> String:
	var diag_ok := not diag or (diagonals and FieldData.tier(k) >= diag_from)
	if _eq0.has(key):
		# Stand schon vor dem Zug genau so da und wurde nur mitgedreht: Hinweis nur, wenn sie sonst wachsen würde
		return "standing" if can_row(k) and diag_ok else ""
	if FieldData.finished(k):
		return "finished"
	if not FieldData.can_row(k):
		return "water"
	if not diag_ok:
		return "diag"
	if not can_row(k):
		return "rest"
	if broken.has(key):
		return "repeat"
	if spent.has(key):
		return "spent"
	if standing.has(key):
		return "standing"
	return "other"


## Zählt diese Reihe? Nur, wenn sie neu gebildet ist (nicht schon da, nicht sofort zurückgedreht, nicht zusammen gewachsen).
func counts(line: Array) -> bool:
	var k := line_key(line)
	return not standing.has(k) and not broken.has(k) and not spent.has(k)


func _still_line(line: Array) -> bool:
	var k := (line[0] as FieldData).kind
	if not can_row(k):
		return false
	for g in line:
		if (g as FieldData).kind != k:
			return false
	return true


## Alter Name: die niedrigste Art, auf die Regen geht (für Texte).
func lowest_stage() -> int:
	var low := FieldData.KIND_COUNT - 1
	for f in fields:
		if RAIN_NEXT.has(f.kind):
			low = mini(low, f.kind)
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
			if k.kind == f.kind and not seen.has(k.id):
				seen[k.id] = true
				todo.append(k)
	return comp


## Gemeinden: Kirche-ID → Nummer der zusammenhängenden Kirchengruppe.
func church_groups() -> Dictionary:
	var comp := {}
	var nr := 0
	for f in fields:
		if f.kind != FieldData.CHURCH or comp.has(f.id):
			continue
		nr += 1
		for g in group_of(f):
			comp[(g as FieldData).id] = nr
	return comp


## Kirchen, die gerade Krieg führen würden: benachbarte Kirchen verschiedener Gemeinden (laut groups).
func war_fields(groups: Dictionary) -> Array:
	var out := {}
	for f in fields:
		if f.kind != FieldData.CHURCH or not groups.has(f.id):
			continue
		for g in neighbors(f):
			var h: FieldData = g
			if h.kind == FieldData.CHURCH and groups.has(h.id) and int(groups[h.id]) != int(groups[f.id]):
				out[f.id] = true
				out[h.id] = true
	var ids: Array = out.keys()
	ids.sort()
	return ids


## Welches Feld einer Reihe wächst? Das, das zuletzt dazugekommen ist. Liegt die ganze Reihe in der Scheibe, die Mitte.
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


## Glaube, den die Reihen bringen, die sich gerade verändert haben (ohne Kettenreaktion). Für schnelle Suchen.
func merge_value() -> int:
	var pts := 0
	for line in lines(moved):
		if not counts(line):
			continue
		pts += int(Balance.GROW_FAITH[FieldData.tier((line[1] as FieldData).kind)])
	return pts


## Wie merge_value, aber nach Gewichten je Art (Tipp an den Tagen): Summe w[Art] + 0,05 je neuer Reihe.
func weighted_merge_value(w: Array) -> float:
	var pts := 0.0
	for line in lines(moved):
		if counts(line):
			pts += float(w[(line[1] as FieldData).kind]) + 0.05
	return pts


# =============================================================================
# Wachsen mit Wahl
# =============================================================================

## Bildet die Art k heute eine Reihe? Nicht Wasser, nicht fertig, und ihre nächste Art ist freigeschaltet
## (sonst ruht sie: „Morgen wächst hier mehr.“). Freies Spiel: alles außer Wasser und fertigen Arten.
func can_row(k: int) -> bool:
	return k >= 0 and k < _row_ok.size() and bool(_row_ok[k])


## Ruht diese Art heute? (Sie könnte wachsen, aber ihre nächste Art ist an diesem Tag noch nicht freigeschaltet.)
func resting(k: int) -> bool:
	return FieldData.can_row(k) and not can_row(k)


## Hat die Art k gerade eine aktive Wahl-Karte? (Im freien Spiel immer bei Wiese, Dorf, Stadt, Tiere;
## an einem Tag erst, wenn der Tag die Wahl einschaltet und Option 2 freigeschaltet ist.)
func is_choice(k: int) -> bool:
	if not FieldData.CHOICE.has(k) or not choices_on.has(k):
		return false
	var opts: Array = FieldData.CHOICE[k]
	return unlocked.has(int(opts[0])) and unlocked.has(int(opts[1]))


## Die Optionen der Wahl dieser Art ([] wenn sie gerade keine Wahl hat).
func options_of(k: int) -> Array:
	return FieldData.options(k) if is_choice(k) else []


## Nächste Art unter den heutigen Regeln (option: 0/1 bei einer Wahl). Ruht die Art, bleibt sie, wie sie ist.
func next_of(k: int, option: int = 0) -> int:
	if is_choice(k):
		return FieldData.next_kind(k, option)
	if not FieldData.valid(k):
		return k
	var nx: int = int(FieldData.NEXT[k])
	return nx if nx >= 0 and unlocked.has(nx) else k


## Erklärung für das lange Drücken auf ein Feld dieser Art (heutige Regeln).
func kind_help(k: int) -> String:
	var c := clampi(k, 0, FieldData.KIND_COUNT - 1)
	var txt := str(FieldData.KIND_HELP[c])
	if FieldData.KIND_HELP_NO_CHOICE.has(c) and not is_choice(c):
		txt = str(FieldData.KIND_HELP_NO_CHOICE[c])
	if resting(c):
		txt += " " + FieldData.REST_HELP
	return txt


## Ein Feld wächst zu nk (zählt für made, wenn sich die Art ändert).
func _grow_to(f: FieldData, nk: int) -> void:
	if f.kind != nk:
		f.kind = nk
		made[nk] = int(made[nk]) + 1


## Die nächste Art für ein Feld der Art k, das gerade wächst. Bei einer Wahl: Die erste Wahl des Zugs wird
## die Karte (card); für sie gilt answers, sonst (und für jede andere Wahl) die Gewohnheit will.
func grown(k: int, fid: int = -1) -> int:
	if not is_choice(k):
		return next_of(k)
	if card < 0:
		card = k
		card_field = fid
	var opt := int(will.get(k, 0)) if (k == card or Balance.OTHER_CHOICE_HABIT) else 0
	if k == card:
		if fid >= 0:
			card_fields.append(fid)
		if answers.has(k):
			opt = int(answers[k])
	return next_of(k, opt)


## Gewohnheit für eine Art mit Wahl (0/1).
func habit(k: int) -> int:
	return int(will.get(k, 0))


# =============================================================================
# Runde auswerten
# =============================================================================

## Seiten aus 9 gleichen Feldern, in denen sich gerade etwas verändert hat: Die ganze Seite wächst.
func resolve_faces(ev: Array, locked: Dictionary) -> int:
	var total := 0
	for nv in FACE_NORMALS:
		var nn: Vector3i = nv
		var face := face_fields(nn)
		var k: int = (face[0] as FieldData).kind
		if not can_row(k):
			continue
		var same := true
		var touched := false
		for g in face:
			var h: FieldData = g
			if h.kind != k:
				same = false
			if moved.has(h.id):
				touched = true
		if not same or not touched:
			continue
		var pts: int = int(Balance.GROW_FAITH[FieldData.tier(k)]) * Balance.FACE_BONUS
		var center := -1
		for g in face:
			if (g as FieldData).p == nn:
				center = (g as FieldData).id
		var nk := grown(k, center)
		var ids: Array = []
		for g in face:
			var h: FieldData = g
			if k == card and h.id != center:
				card_fields.append(h.id)
			_grow_to(h, nk)
			h.burning = false
			locked[h.id] = true
			ids.append(h.id)
		total += pts
		_grew += 1
		ev.append({"type": "face", "field": center, "fields": ids, "points": pts, "stage": nk, "kind": nk, "from": k})
	return total


## Lässt Reihen aus drei gleichen Feldern wachsen, in denen sich gerade etwas verändert hat, dann Kettenreaktionen.
## Ganze Seiten zuerst. Gibt den Glauben zurück. late: Reihen, die erst am Rundenende entstanden sind.
func resolve_merges(ev: Array, late: bool = false) -> int:
	var locked := {}
	var total := resolve_faces(ev, locked)
	var combo := 0
	var focus := moved.duplicate()
	var touched := moved.duplicate()      # bewegt oder gewachsen (für die stillen Reihen)
	var changed := locked.duplicate()     # Art hat sich durch Wachsen geändert
	for fid in locked:
		touched[fid] = true
	var done := {}      # Einfach: was in diesem Zug schon gewachsen ist, wächst nicht gleich nochmal
	var told := {}
	for pass_i in Balance.MAX_CASCADES:
		if focus.is_empty():
			break
		var found: Array = []
		for ln in lines(focus):
			if pass_i == 0 and not counts(ln):
				var lk: int = line_key(ln)
				if (broken.has(lk) or spent.has(lk)) and not standing.has(lk) and not told.has(lk):
					told[lk] = true
					var rids: Array = []
					for g in ln:
						rids.append((g as FieldData).id)
					ev.append({"type": "repeat", "fields": rids, "spent": spent.has(lk) and not broken.has(lk)})
				continue
			found.append(ln)
		if found.is_empty():
			break
		var last_focus := focus
		focus = {}
		for line in found:
			if not _still_line(line):
				continue
			var skip := false
			var free: Array = []
			for i in line.size():
				var fd: FieldData = line[i]
				if locked.has(fd.id):
					skip = true
				if not done.has(fd.id):
					free.append(i)
			if skip or free.is_empty():
				continue
			var ti := target_index(line, moved if pass_i == 0 else last_focus, tapped)
			if not free.has(ti):
				ti = 1 if free.has(1) else int(free[0])
			var mid: FieldData = line[ti]
			var k0: int = mid.kind
			if easy:
				# Einfach: Die Reihe und alle gleichen Felder, die damit zusammenhängen, wachsen zur selben Art.
				# Ausnahme: Wird daraus eine fertige Art, wachsen nur die Felder der Reihe.
				combo += 1
				var nk := grown(k0, mid.id)
				var grp: Array = []
				var in_grp := {}
				if FieldData.finished(nk):
					for i in free:
						grp.append(line[int(i)])
				else:
					for i in free:
						for g in group_of(line[int(i)] as FieldData):
							var gd: FieldData = g
							if not in_grp.has(gd.id) and not done.has(gd.id):
								in_grp[gd.id] = true
								grp.append(gd)
				var gpts: int = int(Balance.GROW_FAITH[FieldData.tier(k0)]) * combo * maxi(grp.size(), 3) / 3
				total += gpts
				_grew += 1
				var gids: Array = []
				for g in grp:
					var h: FieldData = g
					h.burning = false
					done[h.id] = true
					_grow_to(h, nk)
					focus[h.id] = true
					touched[h.id] = true
					changed[h.id] = true
					if h != mid:
						gids.append(h.id)
						if k0 == card:
							card_fields.append(h.id)
				ev.append({"type": "merge", "field": mid.id, "others": gids, "points": gpts, "combo": combo, "stage": nk, "kind": nk, "from": k0, "all": true, "late": late})
				continue
			var rest: Array = []
			for i in line.size():
				if i != ti:
					rest.append(line[i])
			combo += 1
			var pts: int = int(Balance.GROW_FAITH[FieldData.tier(k0)]) * combo
			total += pts
			_grew += 1
			_grow_to(mid, grown(k0, mid.id))
			mid.burning = false
			focus[mid.id] = true
			touched[mid.id] = true
			changed[mid.id] = true
			var other_ids: Array = []
			for g in rest:
				other_ids.append((g as FieldData).id)
			ev.append({"type": "merge", "field": mid.id, "others": other_ids, "points": pts, "combo": combo, "stage": mid.kind, "kind": mid.kind, "from": k0, "late": late})
	# Einfach: Reihen, deren drei Felder alle gerade zusammen gewachsen sind, zählen nie wieder.
	if not done.is_empty():
		for ln in lines():
			var all_done := true
			for g in ln:
				if not done.has((g as FieldData).id):
					all_done = false
			if all_done:
				spent[line_key(ln)] = true
	_still_rows(ev, touched, changed, late)
	return total


## Wertet den Zug aus (Drehung oder Werkzeug). Deterministisch (Zufall nur aus rng, das mitkopiert wird).
## ans: Antwort auf die Karte dieses Zugs ({Art: 0/1}); ohne Antwort gilt die Gewohnheit.
## Gibt {"events", "gain" (Glaube durchs Wachsen), "faith" (Änderung), "income", "loss", "grew", "card",
##       "bonus_gained", "new_age", "w", "zone", "completed"} zurück.
func end_round(ans: Dictionary = {}) -> Dictionary:
	_open_turn()
	answers = ans.duplicate()
	var twist := _rotated
	var ev: Array = _pre_ev.duplicate(true)
	_pre_ev = []
	var age_before := age()
	var corners := touched_corners() if sys_bolts else 0
	# 1. Seiten, dann Reihen (mit Kettenreaktion und Karte)
	var gain := resolve_merges(ev)
	moved = {}
	tapped = -1
	var dirty := {}             # was sich danach verändert: bildet es eine Reihe, wächst sie noch in dieser Runde
	var loss := 0
	var smog_now := false
	var war_now := false
	if twist:
		# 2. Krieg: zwei Kirchen verschiedener Gemeinden, die diese Drehung zusammengebracht hat
		var war: Array = war_fields(_church0) if sys_war else []
		war_now = not war.is_empty()
		if not war.is_empty():
			loss = maxi(Balance.WAR_FAITH_MIN, (faith + gain) * Balance.WAR_FAITH_PCT / 100)
			for i in war:
				var c: FieldData = fields[int(i)]
				c.kind = Balance.WAR_DROP
				c.burning = false
				dirty[c.id] = true
			stats["wars"] = int(stats["wars"]) + 1
			stats["war_churches"] = int(stats["war_churches"]) + war.size()
			ev.append({"type": "war", "fields": war, "faith": -loss, "kind": Balance.WAR_DROP})
		# 3. Smog: Industrie lässt Natur daneben welken (die höchste Stufe zuerst)
		var w := balance()
		smog_now = sys_smog and w >= Balance.SMOG_AT and not calm
		if smog_now:
			stats["smog"] = int(stats["smog"]) + 1
			ev.append({"type": "smog", "w": w})
			for f in fields:
				if f.kind != FieldData.INDUSTRY:
					continue
				var best: FieldData = null
				var bt := -1
				for g in neighbors(f):
					var h: FieldData = g
					if h.is_nature() and FieldData.tier(h.kind) > bt:
						bt = FieldData.tier(h.kind)
						best = h
				if best != null:
					var was: int = best.kind
					best.kind = FieldData.down(was)
					best.burning = false
					best.fresh = 2
					dirty[best.id] = true
					stats["withered"] = int(stats["withered"]) + 1
					ev.append({"type": "polluted", "field": best.id, "by": f.id, "from": was, "kind": best.kind})
		# 4. Nachwachsen: Erde mit viel Natur daneben wird Wiese (nicht bei Smog)
		if sys_regrow and not smog_now and not calm and Balance.REGROW_PER_TWIST > 0:
			var grow: Array = []
			for f in fields:
				if f.kind != FieldData.EMPTY or f.fresh > 0:
					continue
				var nat := _count_neighbors(f, "nature")
				if nat >= Balance.REGROW_NEIGHBORS:
					grow.append([nat, f.id])
			grow.sort_custom(func(x, y): return int(x[0]) > int(y[0]) or (int(x[0]) == int(y[0]) and int(x[1]) < int(y[1])))
			for item in grow.slice(0, Balance.REGROW_PER_TWIST):
				var rf: FieldData = fields[int(item[1])]
				rf.kind = FieldData.MEADOW
				dirty[rf.id] = true
				stats["regrow"] = int(stats["regrow"]) + 1
				ev.append({"type": "regrow", "field": rf.id})
	# 5. Rauch verzieht sich
	for f in fields:
		if f.fresh > 0:
			f.fresh -= 1
	# 6. Was brennt, fällt eine Stufe, dann ist das Feuer aus
	for f in fields:
		if not f.burning:
			continue
		var was_k: int = f.kind
		f.kind = FieldData.down(f.kind)
		f.burning = false
		dirty[f.id] = true
		ev.append({"type": "burn", "field": f.id, "from": was_k, "kind": f.kind})
	# 7. Wünsche: erfüllt, abgelaufen oder weg
	var wish_gain := 0
	if twist and sys_wishes:
		wish_gain = _check_wishes(dirty, ev)
	# 8. Hat das alles eine neue Reihe ergeben? Dann wächst sie gleich (wird danach gezeigt).
	var late_gain := 0
	if not dirty.is_empty():
		moved = dirty
		late_gain = resolve_merges(ev, true)
		moved = {}
	# 9. Glaube pro Drehung von fertigen Feldern
	var income := 0
	if twist and sys_income and not smog_now and not calm:
		income = income_potential()
		if income > 0:
			stats["income"] = int(stats["income"]) + income
			ev.append({"type": "income", "faith": income})
	# 10. Glaube, Fortschritt, Werkzeuge
	var growth := gain + late_gain
	var earned := growth + wish_gain + income + _pre_gain
	var faith_before := faith
	var got := _progress(earned, corners)
	faith = maxi(0, faith - loss)
	# 11. Drehungen zählen, alle 5 Drehungen ein Regen (an den Tagen: alle rain_every)
	if twist:
		twists += 1
		if rain_every > 0 and twists % rain_every == 0:
			if rain < Balance.RAIN_MAX:
				rain += 1
				got["rain"] = int(got["rain"]) + 1
		if rain_every > 0:
			next_rain = (twists / rain_every + 1) * rain_every
	# 12. Fehlversuch? Beim dritten brennt die zuletzt gedrehte Reihe (ein erfüllter Wunsch zählt als Wachsen)
	# Eine ruhende Reihe ist kein blinder Zug: Sie zählt nicht als Fehlversuch (die Oberfläche sagt, warum sie
	# nicht wächst). Ohne Feuer (Tag 1) zählt nichts, gemeldet wird der Zug trotzdem (counted = false).
	if twist and _grew == 0 and wish_gain == 0 and not _still_calm:
		var mid_id: int = int(last_row[1]) if last_row.size() == 3 else -1
		var why := _miss_why(ev)
		if no_fire:
			ev.append({"type": "miss", "count": misses, "field": mid_id, "why": why, "counted": false})
		else:
			misses += 1
			ev.append({"type": "miss", "count": misses, "field": mid_id, "why": why, "counted": true})
			if misses >= Balance.FIRE_AFTER:
				misses = 0
				stats["fires"] = int(stats["fires"]) + 1
				disaster("fire", ev)
	# 13. Ein neuer Wunsch
	if twist and not calm:
		if sys_wishes:
			_make_wish(ev)
		var w2 := balance()
		if w2 <= -80 and people_count() == 0:
			wild_twists += 1
		else:
			wild_twists = 0
	# 14. Was diese Drehung aufgelöst hat, zählt im nächsten Zug nicht beim sofortigen Zurückdrehen.
	broken = _broke_now if _rotated else {}
	_broke_now = {}
	_rotated = false
	_drop_dead_wishes(ev)
	# 15. Vollendet? Tag geschafft oder gescheitert?
	_check_complete(ev)
	_check_day(ev, war_now)
	# 16. Tag: nichts passt mehr zusammen → ein Regen geschenkt
	if sys_gift and not is_over() and stuck():
		rain += 1
		got["rain"] = int(got["rain"]) + 1
		ev.append({"type": "gift", "tool": "rain"})
	return _close_turn(ev, growth, faith - faith_before, income, loss, wish_gain + _pre_gain, got, age_before)


## Warum ist in diesem Zug nichts gewachsen? repeat (zurückgedreht), spent (schon zusammen gewachsen),
## standing (stand schon da), diag (schräg zählt hier nicht), finished, water oder "" (keine Reihe).
func _miss_why(ev: Array) -> String:
	var why := ""
	var rank := {"": 0, "water": 1, "finished": 2, "diag": 3, "standing": 4, "spent": 5, "repeat": 6}
	for e in ev:
		var t := str(e["type"])
		var w := ""
		if t == "repeat":
			w = "spent" if bool(e.get("spent", false)) else "repeat"
		elif t == "still":
			w = str(e["why"])
		if rank.has(w) and int(rank[w]) > int(rank[why]):
			why = w
	return why


## Ende eines Zugs: Karte merken (Gewohnheit), Ereignisse zusammenfassen.
func _close_turn(ev: Array, growth: int, delta: int, income: int, loss: int, wish_gain: int, got: Dictionary, age_before: int) -> Dictionary:
	if card >= 0:
		stats["choices"] = int(stats["choices"]) + 1
		var picked := int(answers.get(card, will.get(card, 0)))
		will[card] = picked
		ev.push_front({"type": "choice", "kind": card, "field": card_field, "fields": card_fields.duplicate(),
			"options": FieldData.options(card), "picked": picked, "grown": FieldData.next_kind(card, picked)})
	if delta != 0 or loss > 0 or growth > 0:
		ev.append({"type": "faith", "delta": delta, "growth": growth, "wish": wish_gain, "income": income, "loss": loss, "total": faith})
	var w := balance()
	var z := zone_of(w)
	var z0 := zone_of(_w0)
	if z != z0:
		ev.append({"type": "balance", "w": w, "was": _w0, "zone": z, "zone_was": z0})
	last_grew = _grew
	_turn_open = false
	_eq0 = {}
	_church0 = {}
	_pre_gain = 0
	moved = {}
	tapped = -1
	turn += 1
	return {"events": ev, "gain": growth, "faith": delta, "income": income, "loss": loss, "grew": _grew,
		"card": card, "card_field": card_field, "bonus_gained": got, "new_age": age() > age_before,
		"w": w, "zone": z, "completed": completed, "day": day_status()}


## Glauben gutschreiben, Fortschritt merken, Werkzeuge verteilen. corners = neu geschaffte Ecken (Blitz).
func _progress(earned: int, corners: int) -> Dictionary:
	faith += earned
	faith_earned += earned
	for f in fields:
		ever[f.kind] = true
	var got := {"rain": 0, "bolt": 0, "monsoon": 0}
	if not gadgets:
		return got
	if sys_monsoon and not monsoon_unlocked and ever.has(FieldData.HOUSE):
		monsoon_unlocked = true
		next_monsoon = faith_earned + Balance.MONSOON_EVERY_FAITH
		if monsoons < Balance.MONSOON_MAX:
			monsoons += 1
			got["monsoon"] = 1
	while monsoon_unlocked and faith_earned >= next_monsoon:
		next_monsoon += Balance.MONSOON_EVERY_FAITH
		if monsoons < Balance.MONSOON_MAX:
			monsoons += 1
			got["monsoon"] = int(got["monsoon"]) + 1
	for k in corners:
		if bolts < Balance.BOLT_MAX:
			bolts += 1
			got["bolt"] = int(got["bolt"]) + 1
	return got


## Vollendet: genug fertige Felder und die Waage nicht im Roten (nur offene Modi).
func _check_complete(ev: Array) -> void:
	if completed or not endless or died() or not day.is_empty():
		return
	var goal := complete_goal()
	if goal <= 0 or finished_count() < goal:
		return
	var w := balance()
	if w <= Balance.WILD_AT or w >= Balance.SMOG_AT:
		return
	completed = true
	var bonus: int = faith * Balance.COMPLETE_BONUS_PCT_PER_HEART * maxi(0, lives) / 100
	faith += bonus
	faith_earned += bonus
	ev.append({"type": "complete", "bonus": bonus, "finished": finished_count(), "w": w})


## Würfelecken, an denen gerade drei gleiche Felder zusammenkommen (und sich eines davon verändert hat).
func touched_corners() -> int:
	var c := 0
	for x in [-1, 1]:
		for y in [-1, 1]:
			for z in [-1, 1]:
				var p := Vector3i(x, y, z)
				var trio: Array = [field_at(p, Vector3i(x, 0, 0)), field_at(p, Vector3i(0, y, 0)), field_at(p, Vector3i(0, 0, z))]
				var k: int = (trio[0] as FieldData).kind
				if not can_row(k):
					continue
				var same := true
				var touched := false
				for g in trio:
					if (g as FieldData).kind != k:
						same = false
					if moved.has((g as FieldData).id):
						touched = true
				if same and touched:
					c += 1
	return c


## Regen (kein ganzer Zug): sofort wachsen lassen, was sich ergibt. Kein Glaube pro Drehung, kein Fehlversuch.
func resolve_now(ans: Dictionary = {}) -> Dictionary:
	_open_turn()
	if not ans.is_empty():
		answers = ans.duplicate()
	var ev: Array = _pre_ev.duplicate(true)
	_pre_ev = []
	var age_before := age()
	var corners := touched_corners() if sys_bolts else 0
	var gain := resolve_merges(ev)
	moved = {}
	tapped = -1
	var faith_before := faith
	var wish_gain := _pre_gain
	var got := _progress(gain + wish_gain, corners)
	_drop_dead_wishes(ev)
	_check_complete(ev)
	_check_day(ev, false)
	var res := _close_turn(ev, gain, faith - faith_before, 0, 0, wish_gain, got, age_before)
	turn -= 1          # Regen ist kein Zug
	return res


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


## Die Katastrophe trifft (deterministisch). Ereignis: {"type": "disaster", "kind", "field", "hit": [ids]}
func disaster(kind: String, ev: Array) -> void:
	var hit: Array = []
	if kind == "fire":
		for i in last_row:
			var f: FieldData = fields[int(i)]
			if f.kind != FieldData.EMPTY and f.kind != FieldData.WATER:
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
		var nn: Vector3i = nv
		var a := axis_of(nn)
		for along in [(a + 1) % 3, (a + 2) % 3]:
			var other: int = 3 - a - along
			for c in [-1, 0, 1]:
				var line: Array = []
				for t in [-1, 0, 1]:
					var p := Vector3i.ZERO
					p[a] = nn[a]
					p[other] = c
					p[along] = t
					line.append(field_at(p, nn))
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
# Wünsche
# =============================================================================

## Wunsch an diesem Feld (oder {}).
func wish_at(fid: int) -> Dictionary:
	for w in wishes:
		if int((w as Dictionary)["field"]) == fid:
			return w
	return {}


## Ist der Wunsch gerade erfüllt? (Regen nur durch Regen auf dieselbe Seite.)
func wish_met(wtype: String, fid: int) -> bool:
	if not WISH_WANT.has(wtype):
		return false
	var want: Array = WISH_WANT[wtype]
	for g in neighbors(fields[fid]):
		if want.has((g as FieldData).kind):
			return true
	return false


func _check_wishes(dirty: Dictionary, ev: Array) -> int:
	var gain := 0
	var keep: Array = []
	for item in wishes:
		var w: Dictionary = item
		var f: FieldData = fields[int(w["field"])]
		if not f.is_people():
			stats["wish_fail"] = int(stats["wish_fail"]) + 1
			ev.append({"type": "wish_gone", "wish": w.duplicate(), "field": f.id})
			continue
		if wish_met(str(w["type"]), f.id):
			gain += _fulfil(w, f, ev)
			dirty[f.id] = true
			continue
		w["left"] = int(w["left"]) - 1
		if int(w["left"]) <= 0:
			stats["wish_fail"] = int(stats["wish_fail"]) + 1
			ev.append({"type": "wish_expired", "wish": w.duplicate(), "field": f.id})
			continue
		keep.append(w)
	wishes = keep
	return gain


## Wunsch erfüllt: +15 Glaube und das Feld wächst eine Stufe (Wahl wie immer).
func _fulfil(w: Dictionary, f: FieldData, ev: Array) -> int:
	stats["wish_ok"] = int(stats["wish_ok"]) + 1
	var was: int = f.kind
	var nk := grown(was, f.id)
	if nk != was:
		_grow_to(f, nk)
		f.burning = false
	ev.append({"type": "wish_done", "wish": w.duplicate(), "field": f.id, "faith": Balance.WISH_FAITH, "from": was, "kind": f.kind})
	return Balance.WISH_FAITH


## Wünsche, deren Feld keine Menschen mehr hat (Krieg, Flut, Gewitter, Feuer), verschwinden.
func _drop_dead_wishes(ev: Array) -> void:
	var keep: Array = []
	for item in wishes:
		var w: Dictionary = item
		if (fields[int(w["field"])] as FieldData).is_people():
			keep.append(w)
		else:
			stats["wish_fail"] = int(stats["wish_fail"]) + 1
			ev.append({"type": "wish_gone", "wish": w.duplicate(), "field": int(w["field"])})
	wishes = keep


## Kommt bei dieser Drehung ein Wunsch? Freies Spiel: ab WISH_FROM_TWIST alle WISH_EVERY Drehungen (4, 8, 12 …).
## An einem Tag: zuerst bei wish_from, dann alle wish_every Drehungen.
func wish_due() -> bool:
	if day.is_empty():
		return twists >= Balance.WISH_FROM_TWIST and twists % Balance.WISH_EVERY == 0
	return twists >= wish_from and (twists - wish_from) % wish_every == 0


## Kann gerade ein Acker entstehen (die Wiese-Karte ist aktiv)? Dann sind Hunger-Wünsche möglich, auch ohne Acker.
func can_make_field() -> bool:
	return is_choice(FieldData.MEADOW) and unlocked.has(FieldData.FIELD)


## Zufall der Regeln: an den Tagen das einfache LCG des Python-Modells (GDPD_7_TAGE.md 6.3), sonst rng. 0 … n−1.
func _rand(n: int) -> int:
	if use_lcg:
		lcg = (lcg * 1103515245 + 12345) & 0x7fffffff
		return (lcg >> 8) % maxi(1, n)
	return rng.randi_range(0, maxi(0, n - 1))


func _make_wish(ev: Array) -> void:
	if wishes.size() >= Balance.WISH_MAX:
		return
	if not wish_due():
		return
	var people: Array = []
	for f in fields:
		if f.is_people() and wish_at(f.id).is_empty():
			people.append(f.id)
	if people.is_empty():
		return
	var w := balance()
	var opts: Array = []
	if not sys_scale:
		opts = [["wald", 2], ["acker", 2], ["tiere", 1], ["regen", 1]]
	elif w >= Balance.CITY_AT:
		opts = [["wald", 3], ["tiere", 2], ["regen", 1]]
	elif w <= Balance.WILD_AT:
		opts = [["acker", 1]]
	else:
		opts = [["wald", 2], ["acker", 2], ["tiere", 1], ["regen", 1]]
	var ok: Array = []
	var tot := 0
	for o in opts:
		var t := str(o[0])
		if not wish_types.has(t):
			continue
		var possible := false
		if t == "regen":
			possible = rain > 0
		elif t == "acker":
			possible = can_make_field() or count(FieldData.FIELD) > 0
		else:
			for k in WISH_WANT[t]:
				if count(int(k)) > 0:
					possible = true
		if possible:
			ok.append(o)
			tot += int(o[1])
	if ok.is_empty():
		return
	var r := _rand(tot)
	var wtype := ""
	for o in ok:
		wtype = str(o[0])
		if r < int(o[1]):
			break
		r -= int(o[1])
	var cand: Array = []
	for fid in people:
		if wtype == "regen" or not wish_met(wtype, int(fid)):
			cand.append(fid)
	if cand.is_empty():
		return
	var pick := int(cand[_rand(cand.size())])
	wish_seq += 1
	var wish := {"id": wish_seq, "type": wtype, "field": pick, "left": Balance.WISH_TWISTS}
	wishes.append(wish)
	stats["wished"] = int(stats["wished"]) + 1
	ev.append({"type": "wish", "wish": wish.duplicate(), "field": pick})


# =============================================================================
# Werkzeuge: Regen, Blitz, Monsun (Segen) und Gewitter, Flut (Strafen)
# =============================================================================

## Die beste Drehung für den Tipp. Jede der 27 Drehungen wird ganz durchgespielt, bei einer Karte mit beiden
## Antworten. Wert = Glaube danach + 0,5 × Glaube pro Drehung, −60 je Herz, −10000 wenn die Welt stirbt, −3 je Feuer.
## Gleichstand: die Antwort, bei der die Waage näher an 0 bleibt. Bringt keine Drehung sofort etwas,
## sucht er die Drehung, nach der eine zweite wachsen kann (steps = 2).
## {"axis", "layer", "turns", "points", "steps", "choice" (0/1 oder -1), "card" (Art oder -1), "value"} oder {}.
func best_move() -> Dictionary:
	if is_day():
		return best_day_action(true)
	var best := {}
	var best_v := -INF
	for m in MOVES:
		var act := {"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])}
		var e := evaluate(act)
		if int(e["grew"]) <= 0:
			continue
		var v: float = float(e["value"])
		if v > best_v:
			best_v = v
			best = {"axis": m[0], "layer": m[1], "turns": m[2], "points": int(e["gain"]), "steps": 1,
				"choice": int(e["choice"]), "card": int(e["card"]), "value": v}
	if not best.is_empty():
		if int(best["card"]) >= 0:
			# Für die empfohlene Drehung schaut die Wahl einen Zug weiter
			var act2 := {"type": "twist", "axis": int(best["axis"]), "layer": int(best["layer"]), "turns": int(best["turns"])}
			best["choice"] = int(evaluate(act2, true)["choice"])
		return best
	var ts := two_step_move()
	var tm: Array = ts[0]
	if not tm.is_empty():
		best = {"axis": tm[0], "layer": tm[1], "turns": tm[2], "points": int(ts[1]), "steps": 2, "choice": -1, "card": -1, "value": 0.0}
	return best


## Wert eines Stands nach einem Zug (für Tipp und Bot).
func value_after(before: GameState) -> float:
	var v := float(faith) + 0.5 * float(income_rate())
	v -= 60.0 * float(maxi(0, before.lives - lives))
	if died():
		v -= 10000.0
	for f in fields:
		if f.burning:
			v -= 3.0
	return v


## Bester sofortiger Wachstums-Glaube der nächsten Drehung (Blick einen Zug voraus).
func next_gain() -> int:
	var best := 0
	for g in quick_gains():
		best = maxi(best, int(g))
	return best


## Sofortiger Wachstums-Glaube (merge_value) jeder der 27 Drehungen, ohne die Runde auszuwerten.
## Eine Kopie wird nach jeder Drehung zurückgestellt (schnell). skip: diese Scheibe (Achse, Scheibe) auslassen.
## w: Gewichte je Art (Tage, siehe goal_weights) – dann ist das Ergebnis weighted_merge_value statt Glaube.
func quick_gains(skip_axis: int = -1, skip_layer: int = 99, w: Array = []) -> Array:
	var sim := clone()
	var save_p: Array = []
	var save_n: Array = []
	for f in sim.fields:
		save_p.append((f as FieldData).p)
		save_n.append((f as FieldData).n)
	var out: Array = []
	for m in MOVES:
		if int(m[0]) == skip_axis and int(m[1]) == skip_layer:
			out.append(0)
			continue
		sim.moved = {}
		sim._turn_open = true          # keine Gemeinden/Waage nötig
		sim._broke_now = {}
		sim.apply_rotation(int(m[0]), int(m[1]), int(m[2]))
		if w.is_empty():
			out.append(sim.merge_value())
		else:
			out.append(sim.weighted_merge_value(w))
		for i in sim.fields.size():
			var f: FieldData = sim.fields[i]
			f.p = save_p[i]
			f.n = save_n[i]
		sim.rebuild_index()
	return out


## Zwei-Zug-Suche: die erste Drehung, nach der eine zweite (andere Scheibe) am meisten wachsen lässt.
## [Drehung, Glaube] oder [[], 0].
## w: Gewichte je Art (Tage) – dann zählt weighted_merge_value statt Glaube.
func two_step_move(w: Array = []) -> Array:
	var best: Array = []
	var best_pts = 0
	for m in MOVES:
		var sim := clone()
		sim.moved = {}
		sim._turn_open = true
		sim.apply_rotation(int(m[0]), int(m[1]), int(m[2]))
		sim.broken = sim._broke_now.duplicate()     # gleich zurückdrehen zählt nicht
		var gains := sim.quick_gains(int(m[0]), int(m[1]), w)
		for g in gains:
			if w.is_empty():
				if int(g) > int(best_pts):
					best_pts = int(g)
					best = m
			elif float(g) > float(best_pts):
				best_pts = float(g)
				best = m
	return [best, best_pts]


## Spielt eine Aktion auf einer Kopie durch: {"state": GameState, "result": Dictionary}.
func simulate(action: Dictionary, ans: Dictionary = {}) -> Dictionary:
	var sim := clone()
	var res := sim.play(action, ans)
	return {"state": sim, "result": res}


## Empfohlene Antwort auf die Karte dieser Aktion (0/1, -1 ohne Karte). Tage: nach dem Ziel, sonst nach Glauben.
func recommend_choice(action: Dictionary) -> int:
	if is_day():
		return int(_day_option(action, goal_weights())["choice"])
	return int(evaluate(action, true)["choice"])


## Welche Karte bringt diese Aktion? {} oder {"kind", "field", "fields", "options", "default"}.
func choice_for(action: Dictionary) -> Dictionary:
	var sim: GameState = simulate(action)["state"]
	if sim.card < 0:
		return {}
	return {"kind": sim.card, "field": sim.card_field, "fields": sim.card_fields.duplicate(),
		"options": FieldData.options(sim.card), "default": habit(sim.card)}


## Bewertet eine Aktion mit beiden Antworten ihrer Karte. look: zusätzlich 0,5 × bester Glaube der nächsten Drehung.
## {"value", "choice" (0/1, -1 ohne Karte), "card", "gain", "grew", "state", "result"}
func evaluate(action: Dictionary, look: bool = false) -> Dictionary:
	var a := simulate(action)
	var sa: GameState = a["state"]
	var ra: Dictionary = a["result"]
	var va := sa.value_after(self) + (0.5 * float(sa.next_gain()) if look else 0.0)
	if sa.card < 0:
		return {"value": va, "choice": -1, "card": -1, "gain": int(ra["gain"]), "grew": int(ra["grew"]), "state": sa, "result": ra}
	var h := habit(sa.card)
	var b := simulate(action, {sa.card: 1 - h})
	var sb: GameState = b["state"]
	var rb: Dictionary = b["result"]
	var vb := sb.value_after(self) + (0.5 * float(sb.next_gain()) if look else 0.0)
	var take_b := vb > va
	if is_equal_approx(va, vb):
		take_b = absi(sb.balance()) < absi(sa.balance())
	if take_b:
		return {"value": vb, "choice": 1 - h, "card": sa.card, "gain": int(rb["gain"]), "grew": int(rb["grew"]), "state": sb, "result": rb}
	return {"value": va, "choice": h, "card": sa.card, "gain": int(ra["gain"]), "grew": int(ra["grew"]), "state": sa, "result": ra}


## Eine Aktion spielen (Drehung oder Werkzeug) mit der Antwort auf die Karte.
## action: {"type": "twist", "axis", "layer", "turns", "row"?} oder {"type": "rain"|"bolt"|"monsoon"|"strike"|"flood", "field", "row"?}.
## Bei Werkzeugen steht im Ergebnis "bonus": {"kind", "field", "fields", "stages"} (Stand direkt nach dem Werkzeug).
func play(action: Dictionary, ans: Dictionary = {}) -> Dictionary:
	var t := str(action.get("type", "twist"))
	if t == "twist" or t == "wait":
		var turns := int(action.get("turns", 0))
		if turns != 0:
			var row: Array = action.get("row", [])
			apply_rotation(int(action["axis"]), int(action["layer"]), turns, row)
		return end_round(ans)
	var fid := int(action["field"])
	var f: FieldData = fields[fid]
	var brow: Array = action.get("row", [])
	var hit := bonus_fields(t, f, brow)
	apply_bonus(t, f, brow, ans)
	var stages := {}
	for i in hit:
		stages[int(i)] = (fields[int(i)] as FieldData).kind
	var res := resolve_now(ans) if t == "rain" else end_round(ans)
	res["bonus"] = {"kind": t, "field": fid, "fields": hit, "stages": stages}
	return res


## Felder, die ein Werkzeug trifft (Regen/Gewitter: das Feld, Blitz: die Eck-Diagonale, Monsun/Flut: die Seite).
func bonus_fields(kind: String, f: FieldData, row: Array = []) -> Array:
	if kind == "bolt":
		var d := row.duplicate() if not row.is_empty() else corner_diagonal(f)
		return d if not d.is_empty() else [f.id]
	if kind == "monsoon" or kind == "flood":
		var out: Array = [f.id]
		for g in fields:
			if (g as FieldData).n == f.n and (g as FieldData).id != f.id:
				out.append((g as FieldData).id)
		return out
	return [f.id]


## Alle Felder, auf die Regen gerade geht: id -> "fire" (brennt: löschen), "useful" (macht eine Reihe fertig)
## oder "grow" (Erde, Wiese, Wald).
func rain_targets() -> Dictionary:
	var out := {}
	if rain <= 0:
		return out
	var useful := rain_spots()
	for f in fields:
		if f.burning:
			out[f.id] = "fire"
		elif useful.has(f.id):
			out[f.id] = "useful"
		elif rain_grows(f.kind):
			out[f.id] = "grow"
	return out


## Lässt Regen diese Art heute wachsen? (Erde → Wiese → Wald → Großer Wald, nur wenn das Ergebnis freigeschaltet ist.)
func rain_grows(k: int) -> bool:
	return RAIN_NEXT.has(k) and unlocked.has(int(RAIN_NEXT[k]))


## Geht Regen auf dieses Feld? (Brennt es, löscht er; sonst muss es wachsen können.)
func rain_ok(f: FieldData) -> bool:
	return f.burning or rain_grows(f.kind)


## Gibt es eine Drehung, die sofort etwas wachsen lässt? (Schneller als best_move, nur ein Zug.)
func has_quick_move() -> bool:
	return next_gain() > 0


## Wo lohnt sich Regen? Brennende Felder (löschen) und Felder, deren Wachsen eine Reihe vervollständigt.
func rain_spots() -> Dictionary:
	var out := {}
	if rain <= 0:
		return out
	for f in fields:
		if f.burning:
			out[f.id] = "fire"
			continue
		if not rain_grows(f.kind):
			continue
		var was: int = f.kind
		f.kind = int(RAIN_NEXT[was])
		var hit := false
		for ln in lines({f.id: true}):
			var lk := line_key(ln)
			if not broken.has(lk) and not spent.has(lk):
				hit = true
		f.kind = was
		if hit:
			out[f.id] = "up"
	return out


## "" = geht, sonst der Grund, warum nicht (einfaches Deutsch).
func can_bonus(kind: String, f: FieldData) -> String:
	if kind == "rain":
		if rain <= 0:
			return "Nächster Regen in %d Drehungen." % maxi(1, next_rain - twists)
		if not rain_ok(f):
			var names: Array = []
			for k in [FieldData.EMPTY, FieldData.MEADOW, FieldData.FOREST]:
				if rain_grows(k):
					names.append(FieldData.kind_name(k))
			if names.size() == 3:
				return "Nur auf Erde, Wiese, Wald oder Feuer."
			return "Nur auf %s oder Feuer." % " und ".join(PackedStringArray(names))
	elif kind == "bolt":
		if bolts <= 0:
			return "Blitz: 3 gleiche an einer Ecke."
		if corner_diagonal(f).is_empty():
			return "Tippe auf ein leuchtendes Eckfeld."
	elif kind == "monsoon":
		if monsoons <= 0:
			return "Gerade ist kein Monsun da."
	elif kind == "strike":
		if faith < Balance.STRIKE_COST:
			return "Dafür brauchst du %d Glauben." % Balance.STRIKE_COST
		if f.kind == FieldData.EMPTY or f.kind == FieldData.WATER:
			return "Hier ist nichts zu strafen."
	elif kind == "flood":
		if faith < Balance.FLOOD_COST:
			return "Dafür brauchst du %d Glauben." % Balance.FLOOD_COST
		var any := false
		for g in face_fields(f.n):
			var h: FieldData = g
			if h.is_civilisation() or h.burning:
				any = true
		if not any:
			return "Hier gibt's nichts wegzuspülen."
	else:
		return "Unbekanntes Werkzeug."
	return ""


## Werkzeug geschenkt oder gekauft.
func grant(kind: String) -> void:
	if kind == "rain":
		rain += 1
	elif kind == "bolt":
		bolts += 1
	elif kind == "monsoon":
		monsoons += 1


## Werkzeug anwenden (danach resolve_now für Regen, sonst end_round).
## Regen: brennt es, wird nur gelöscht; sonst Erde → Wiese → Wald → Großer Wald. Erfüllt Regen-Wünsche auf der Seite.
## Blitz: die Eck-Diagonale wächst je eine Stufe (Wahl wie immer). Monsun: die ganze Seite.
## Gewitter: Industrie → Erde (raucht), alles andere fällt eine Stufe. Flut: alle Äcker, Menschen, Kirchen und
## Industrie der Seite fallen eine Stufe (Industrie → Erde), Natur bleibt, Feuer gehen aus.
func apply_bonus(kind: String, f: FieldData, row: Array = [], ans: Dictionary = {}) -> void:
	_remember_before()
	_open_turn()
	answers = ans.duplicate()
	tapped = f.id
	if kind == "rain":
		rain -= 1
		stats["rains"] = int(stats["rains"]) + 1
		# Regen-Wünsche auf dieser Seite gehen in Erfüllung
		var keep: Array = []
		for item in wishes:
			var w: Dictionary = item
			var wf: FieldData = fields[int(w["field"])]
			if str(w["type"]) == "regen" and wf.n == f.n and wf.is_people():
				var wk: int = wf.kind
				_pre_gain += _fulfil(w, wf, _pre_ev)
				if wf.kind != wk:
					moved[wf.id] = true
			else:
				keep.append(w)
		wishes = keep
		if f.burning:
			f.burning = false
			tapped = -1
			return
		if rain_grows(f.kind):
			_grow_to(f, int(RAIN_NEXT[f.kind]))
		f.fresh = 0
		moved[f.id] = true
		return
	if kind == "strike" or kind == "flood":
		var cost := Balance.STRIKE_COST if kind == "strike" else Balance.FLOOD_COST
		faith = maxi(0, faith - cost)
		stats["strikes" if kind == "strike" else "floods"] = int(stats["strikes" if kind == "strike" else "floods"]) + 1
		tapped = -1
		var hit: Array = []
		for i in bonus_fields(kind, f, row):
			var g: FieldData = fields[int(i)]
			var was: int = g.kind
			if kind == "flood":
				g.burning = false
				if not g.is_civilisation():
					continue
			if was == FieldData.EMPTY or was == FieldData.WATER:
				continue
			if was == FieldData.INDUSTRY:
				g.kind = FieldData.EMPTY
				g.fresh = 3        # end_round dieses Werkzeug-Zugs zieht 1 ab: raucht danach noch 2 Drehungen
			else:
				g.kind = FieldData.down(was)
			g.burning = false
			moved[g.id] = true
			hit.append({"field": g.id, "from": was, "kind": g.kind})
		_pre_ev.append({"type": kind, "field": f.id, "hit": hit, "cost": cost, "faith": -cost})
		return
	if kind == "monsoon":
		monsoons -= 1
		stats["monsoons"] = int(stats["monsoons"]) + 1
	else:
		bolts -= 1
		stats["bolts"] = int(stats["bolts"]) + 1
	for i in bonus_fields(kind, f, row):
		var h: FieldData = fields[int(i)]
		h.burning = false
		if h.kind == FieldData.WATER or h.is_finished():
			continue
		_grow_to(h, grown(h.kind, h.id))
		h.fresh = 0
		moved[h.id] = true


# =============================================================================
# Die Schöpfung in 7 Tagen: Ziel, Fortschritt, Sterne (GDPD_7_TAGE.md, Abschnitt 2)
# =============================================================================

## Läuft gerade ein Tag (statt freiem Spiel)?
func is_day() -> bool:
	return not day.is_empty()


## Art des Ziels: "make" (so viele Felder wachsen zu einer Art), "wishes" (Wünsche erfüllen), "faith" (Glauben
## sammeln; mit goal_green() auch die Waage im Grünen). "" im freien Spiel.
func goal_type() -> String:
	return str(day.get("goal_type", ""))


func goal_target() -> int:
	return int(day.get("goal_target", 0))


func goal_kinds() -> Array:
	return day.get("goal_kinds", [])


func goal_green() -> bool:
	return bool(day.get("goal_green", false))


## Fortschritt zum Ziel: make = so oft ist ein Feld zu der Art gewachsen (Reihe, Seite, Kette, Regen, Wunsch;
## Fallen zählt nicht ab, der Fortschritt geht nie zurück), wishes = erfüllte Wünsche, faith = Glaube.
func goal_progress() -> int:
	var t := goal_type()
	if t == "make":
		var c := 0
		for k in goal_kinds():
			c += int(made[int(k)])
		return c
	if t == "wishes":
		return int(stats.get("wish_ok", 0))
	if t == "faith":
		return faith
	return 0


## Steht die Waage im Grünen (Gleichgewicht: WILD_AT < W < CITY_AT)?
func balance_green() -> bool:
	var w := balance()
	return w > Balance.WILD_AT and w < Balance.CITY_AT


## Ist das Ziel des Tages gerade erreicht?
func goal_met() -> bool:
	if not is_day() or goal_target() <= 0:
		return false
	if goal_progress() < goal_target():
		return false
	if goal_green():
		return balance_green()
	return true


## Drehungen, die an diesem Tag noch bleiben (-1 = keine Grenze: Weiterbauen).
func twists_left() -> int:
	if day_free_build:
		return -1
	return maxi(0, day_limit - used_twists())


## Weiterbauen nach dem Sieg beginnen: keine Grenze, kein Scheitern (auch Krieg an Tag 6 ist nur Krieg).
## Die Sterne bleiben die des Sieges (day_won, day_won_at bleiben).
func start_free_build() -> void:
	if not is_day() or not day_won:
		return
	day_free_build = true
	no_war = false
	build_made0 = total_made()


## So oft ist bisher etwas gewachsen (alle Arten zusammen).
func total_made() -> int:
	var t := 0
	for v in made:
		t += int(v)
	return t


## Weiterbauen: so viele Felder sind seit dem Sieg gewachsen (0 sonst).
func build_growth() -> int:
	if not day_free_build:
		return 0
	return maxi(0, total_made() - build_made0)


## Gezählte Drehungen an einem Tag (ohne die vorgeführte Drehung von Tag 1).
func used_twists() -> int:
	return maxi(0, twists - gift_twists)


## Sterne für einen gewonnenen Tag: ★★★ bis stars[0] Drehungen, ★★ bis stars[1], sonst ★ (0 = nicht gewonnen).
## Die Gnade (mehr Drehungen) ändert die Grenzen nicht.
func stars() -> int:
	if not day_won:
		return 0
	return Days.stars_for(day, day_won_at)


## Zusammenfassung für die Oberfläche (Ziel-Chip, Karten). {} im freien Spiel.
## {"day", "type", "kinds", "target", "progress", "met", "green" (Waage grün), "need_green", "twists", "limit",
##  "left", "won", "lost" ("", "twists", "war", "fire"), "won_at", "stars", "no_war"}
func day_status() -> Dictionary:
	if not is_day():
		return {}
	return {"day": day_no, "type": goal_type(), "kinds": goal_kinds(), "target": goal_target(),
		"progress": goal_progress(), "met": goal_met(), "green": balance_green(), "need_green": goal_green(),
		"twists": used_twists(), "limit": day_limit, "left": twists_left(), "won": day_won, "lost": day_lost,
		"won_at": day_won_at, "stars": stars(), "no_war": no_war, "free_build": day_free_build, "growth": build_growth()}


## Nach jedem Zug (end_round) und jedem Regen (resolve_now): Fortschritt melden, gewonnen oder gescheitert?
## Gewonnen, sobald das Ziel erreicht ist (auch bei der letzten Drehung). Gescheitert: Krieg (no_war),
## Welt verbrannt (nur mit Herzen) oder alle Drehungen verbraucht.
func _check_day(ev: Array, war_now: bool) -> void:
	if not is_day():
		return
	var p := goal_progress()
	if p != _goal0:
		ev.append({"type": "goal", "progress": p, "was": _goal0, "target": goal_target(), "met": goal_met()})
		_goal0 = p
	if day_won or day_lost != "" or day_free_build:
		return
	if no_war and war_now:
		day_lost = "war"
	elif goal_met():
		day_won = true
		day_won_at = used_twists()
	elif died():
		day_lost = "fire"
	elif used_twists() >= day_limit:
		day_lost = "twists"
	if day_won:
		ev.append({"type": "day_won", "day": day_no, "twists": used_twists(), "stars": stars()})
	elif day_lost != "":
		ev.append({"type": "day_lost", "day": day_no, "why": day_lost, "progress": p, "target": goal_target()})


# =============================================================================
# Tipp an den Tagen: nach dem Ziel bewertet (GDPD_7_TAGE.md 7.1/7.2, wie der Bot „good“ des Modells)
# =============================================================================

const _LADDER_W = {1: 6.0, 2: 2.5, 3: 1.0, 4: 0.4, 5: 0.15, 6: 0.05}


## Wachstumsschritte von jeder Art bis zur nächsten Ziel-Art (unter den heutigen Regeln, jede Option). Art → Schritte.
func goal_distance() -> Dictionary:
	var dist := {}
	for k in goal_kinds():
		dist[int(k)] = 0
	var changed := true
	while changed:
		changed = false
		for k in FieldData.KIND_COUNT:
			if dist.has(k) and int(dist[k]) == 0:
				continue
			for o in _grow_options(k):
				if dist.has(int(o)) and (not dist.has(k) or int(dist[k]) > int(dist[int(o)]) + 1):
					dist[k] = int(dist[int(o)]) + 1
					changed = true
	return dist


func _grow_options(k: int) -> Array:
	if is_choice(k):
		return FieldData.options(k)
	var nx := next_of(k)
	return [nx] if nx != k else []


## Gewicht je Art: wie viel eine Reihe dieser Art dem Ziel hilft (für Paare und die Zwei-Zug-Suche).
func goal_weights() -> Array:
	var w: Array = []
	for k in FieldData.KIND_COUNT:
		w.append(0.0)
	var t := goal_type()
	if t == "make":
		var d := goal_distance()
		for k in d:
			var v := int(d[k])
			if v > 0:
				w[int(k)] = float(_LADDER_W.get(v, 0.02))
	elif t == "wishes":
		for k in FieldData.KIND_COUNT:
			if can_row(k):
				w[k] = 0.5
		w[FieldData.MEADOW] = 2.0
		for k in FieldData.KIND_COUNT:
			if FieldData.people(k) and can_row(k):
				w[k] = 1.0
	else:
		for k in FieldData.KIND_COUNT:
			if can_row(k):
				w[k] = float(Balance.GROW_FAITH[FieldData.tier(k)]) / 10.0 + 0.2
	return w


## Wert dieses Stands für das Ziel des Tages (before: der Stand vor dem Zug).
func goal_value(before: GameState, w: Array) -> float:
	if day_won and not day_free_build:
		return 1e6 - 1000.0 * float(twists)
	if day_lost != "" and day_lost != "twists":
		return -1e5
	var v := 0.0
	var p := goal_progress()
	var t := goal_type()
	if t == "make":
		v += 100.0 * float(p)
		var d := goal_distance()
		for f in fields:
			var dk := int(d.get(f.kind, -1))
			if dk > 0:
				v += 3.0 * float(_LADDER_W.get(dk, 0.02))
	elif t == "wishes":
		v += 100.0 * float(p)
		var acker := count(FieldData.FIELD)
		for item in wishes:
			v += 6.0
			if str((item as Dictionary)["type"]) == "acker" and acker > 0:
				v += 4.0
		v += 2.0 * float(acker) if acker <= 4 else 8.0
		v += 0.5 * float(people_count())
	else:
		v += float(mini(p, goal_target()))
		var inc := 0 if (sys_smog and smog()) else income_potential()
		var left := 6 if day_free_build else maxi(0, day_limit - used_twists())
		v += float(inc) * float(mini(left, 6)) * 0.8
		if goal_green():
			var bw := balance()
			if bw >= Balance.CITY_AT:
				v -= float(bw - Balance.CITY_AT + 3) * 2.0
			if bw <= Balance.WILD_AT:
				v -= float(Balance.WILD_AT - bw + 3) * 2.0
		if sys_war:
			v -= 4.0 * float(maxi(0, count(FieldData.CHURCH) - 2))
	v -= 60.0 * float(maxi(0, disasters - before.disasters))
	if not no_fire:
		v -= 12.0 * float(misses) * (1.0 if lives > 1 else 3.0)
	for f in fields:
		if f.burning:
			v -= 3.0
	return v + pair_value(w)


## Reihen mit zwei gleichen Feldern und einem anderen: Summe der Gewichte (Reihen-Potenzial).
func pair_value(w: Array) -> float:
	if not _cache_ready:
		_build_cache()
	var v := 0.0
	var i := 0
	var n := _LINES.size()
	while i < n:
		if _LINES[i + 3] == 0 or diagonals:
			var a: int = (_index[_LINES[i]] as FieldData).kind
			var b: int = (_index[_LINES[i + 1]] as FieldData).kind
			var c: int = (_index[_LINES[i + 2]] as FieldData).kind
			if a == b and c != a:
				v += float(w[a])
			elif a == c and b != a:
				v += float(w[a])
			elif b == c and a != b:
				v += float(w[b])
		i += 4
	return v


## Eine Aktion mit beiden Antworten ihrer Karte, bewertet nach dem Ziel des Tages.
## {"value", "choice" (0/1 oder -1), "card", "state", "result"}
func _day_option(action: Dictionary, w: Array) -> Dictionary:
	var a := simulate(action)
	var sa: GameState = a["state"]
	var va := sa.goal_value(self, w)
	if sa.card < 0:
		return {"value": va, "choice": -1, "card": -1, "state": sa, "result": a["result"]}
	var h := habit(sa.card)
	var b := simulate(action, {sa.card: 1 - h})
	var sb: GameState = b["state"]
	var vb := sb.goal_value(self, w)
	if vb > va:
		return {"value": vb, "choice": 1 - h, "card": sa.card, "state": sb, "result": b["result"]}
	return {"value": va, "choice": h, "card": sa.card, "state": sa, "result": a["result"]}


## Der beste nächste Schritt an einem Tag (der Tipp): Regen, wenn er klar hilft, sonst die beste Drehung (alle 27,
## jede mit beiden Antworten), an Tag 7 auch Gewitter auf eine Industrie. Bringt keine Drehung Fortschritt, zählt
## die Zwei-Zug-Suche mit (Reihen, die eine zweite Drehung bilden kann, nach dem Ziel gewichtet).
## {"type": "twist"|"rain"|"strike", "axis", "layer", "turns" (Drehung), "field" (Werkzeug), "choice", "card",
##  "value", "steps" (1, 2 = erst die zweite Drehung bringt etwas), "points", "progress" (Fortschritt danach)} oder {}.
func best_day_action(twist_only: bool = false) -> Dictionary:
	if not is_day() or is_over():
		return {}
	var w := goal_weights()
	var now_v := goal_value(self, w)
	var p0 := goal_progress()
	if not twist_only and rain > 0:
		var best_r := {}
		var best_rv := -INF
		for f in fields:
			if not rain_ok(f):
				continue
			var o := _day_option({"type": "rain", "field": f.id}, w)
			if float(o["value"]) > best_rv:
				best_rv = float(o["value"])
				best_r = {"type": "rain", "field": f.id, "choice": int(o["choice"]), "card": int(o["card"]),
					"value": best_rv, "steps": 1, "points": int((o["result"] as Dictionary).get("gain", 0)),
					"progress": (o["state"] as GameState).goal_progress()}
		var need := 8.0 if rain == 1 and not no_fire else 4.0
		if not best_r.is_empty() and best_rv > now_v + need:
			return best_r
	var best := {}
	var best_v := -INF
	var progressed := false
	for m in MOVES:
		var o := _day_option({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])}, w)
		var st: GameState = o["state"]
		if st.goal_progress() > p0 or (st.day_won and not st.day_free_build):
			progressed = true
		if float(o["value"]) > best_v:
			best_v = float(o["value"])
			best = {"type": "twist", "axis": m[0], "layer": m[1], "turns": m[2], "choice": int(o["choice"]),
				"card": int(o["card"]), "value": best_v, "steps": 1, "points": int((o["result"] as Dictionary)["gain"]),
				"progress": st.goal_progress()}
	if not twist_only and sys_strike and faith >= Balance.STRIKE_COST and balance() >= Balance.CITY_AT - 5:
		for f in fields:
			if f.kind != FieldData.INDUSTRY:
				continue
			var o := _day_option({"type": "strike", "field": f.id}, w)
			var st: GameState = o["state"]
			if st.goal_progress() > p0 or (st.day_won and not st.day_free_build):
				progressed = true
			if float(o["value"]) > best_v:
				best_v = float(o["value"])
				best = {"type": "strike", "field": f.id, "choice": int(o["choice"]), "card": int(o["card"]),
					"value": best_v, "steps": 1, "points": 0, "progress": st.goal_progress()}
	if not progressed:
		var ts := two_step_move(w)
		var tm: Array = ts[0]
		if not tm.is_empty():
			var o := _day_option({"type": "twist", "axis": int(tm[0]), "layer": int(tm[1]), "turns": int(tm[2])}, w)
			var st: GameState = o["state"]
			if st.day_lost == "" or st.day_lost == "twists":
				var v2 := float(o["value"]) + 10.0 * float(ts[1])
				if v2 > best_v:
					best_v = v2
					best = {"type": "twist", "axis": tm[0], "layer": tm[1], "turns": tm[2], "choice": int(o["choice"]),
						"card": int(o["card"]), "value": v2, "steps": 2, "points": 0, "progress": st.goal_progress()}
	return best


## Der Tipp als Aktion für play() (Drehung, Regen oder Gewitter). Freies Spiel: wie best_move().
func best_action() -> Dictionary:
	if is_day():
		return best_day_action()
	var b := best_move()
	if not b.is_empty():
		b["type"] = "twist"
	return b
