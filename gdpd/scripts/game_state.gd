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
var spent := {}               # Reihen (3 Felder + Art vor dem Wachsen), die schon gewachsen sind: zählen nie wieder
var once := true              # GDPD_BALANCE_2.md 2: „Jede Reihe wächst nur einmal“ (alle Modi). false = altes Verhalten
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

# --- Die 7 Tage nach GDPD_BALANCE_2.md (Erschaffen + Gedeihen; Tag-Konfiguration mit "rows") -------------------
var v8 := false               # dieser Tag läuft nach den neuen Regeln (Days.config hat "rows")
var rows8: Dictionary = {}    # Art → true: bildet heute eine zählende Reihe
var next8: Dictionary = {}    # Art → nächste Art einer Reihe (Erde → Wiese → Wald → Tiere → Hütte)
var later8: Dictionary = {}   # Art → true: bildet an einem späteren Tag Reihen (ruht heute)
var top8 := -1                # höchste Menschen-Art, die heute durch Gedeihen entstehen darf (-1: keine)
var needs8: Dictionary = {}   # Menschen-Art → ["food", "work", "faith"]
var consume8 := true          # 3 Tiere → 1 Hütte, die anderen beiden werden Wiese
var bolt := -1                # gewarntes Blitz-Feld (schlägt am Ende der nächsten Drehung ein), -1 = keins
var war_on := false           # Krieg läuft (Kirche an Kirche)
var front: Dictionary = {}    # Feld-ID → true: Kriegsfront (nie satt, fällt jede Drehung eine Stufe)
var flood_warn: Dictionary = {}   # Seite (Index in FACE_NORMALS) → true: gewarnt (Flut, wenn sie es bleibt)
var extra_level := 0          # Weiterbauen: so viele Extra-Aufgaben sind geschafft
var _satt0: Dictionary = {}   # zu Beginn des Zugs satt (für satt_new / satt_lost)
var rain_kinds8: Array = []   # Arten, die Regen heute machen kann (Wiese aus Erde, Wald aus Wiese)

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
	for f in fields:
		f.maxlvl = FieldData.level8(f.kind)
	# Glaube (7.3): wer am Morgen schon neben einer Kirche steht, zahlt erst für die nächste Stufe
	for f in fields:
		f.flvl = FieldData.level8(f.kind) if people8(f.kind) and _next_to8(f, FieldData.CHURCH) else -1
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
	once = true
	v8 = false
	rows8 = {}
	next8 = {}
	later8 = {}
	top8 = -1
	needs8 = {}
	consume8 = true
	bolt = -1
	war_on = false
	front = {}
	flood_warn = {}
	extra_level = 0
	_satt0 = {}
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
	var gk: Array = []
	for k in cfg.get("goal_kinds", []):
		gk.append(int(k))
	day["goal_kinds"] = gk
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
	once = bool(cfg.get("once", true))
	v8 = cfg.has("rows")
	if v8:
		_apply_rules8(cfg)
	_rebuild_rules()


## Welche Art bildet heute eine Reihe? (Nicht Wasser, nicht fertig, und ihre nächste Art ist freigeschaltet.)
func _rebuild_rules() -> void:
	_row_ok = []
	if v8:
		for k in FieldData.KIND_COUNT:
			_row_ok.append(rows8.has(k) and next8.has(k))
		return
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
	gs.once = once
	gs.v8 = v8
	gs.rows8 = rows8              # nur gelesen
	gs.next8 = next8              # nur gelesen
	gs.later8 = later8            # nur gelesen
	gs.top8 = top8
	gs.needs8 = needs8            # nur gelesen
	gs.consume8 = consume8
	gs.rain_kinds8 = rain_kinds8      # nur gelesen
	gs.bolt = bolt
	gs.war_on = war_on
	gs.front = front.duplicate()
	gs.flood_warn = flood_warn.duplicate()
	gs.extra_level = extra_level
	gs._satt0 = _satt0.duplicate()
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
		if v8:
			# Die 7 Tage: Meteor (Tag 6–7) liegt auf dem Platz des Gewitters
			return (kind == "strike" or kind == "meteor") and bool(day.get("meteor", false))
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
	return ((a * 64 + b) * 64 + c) * 32 + (line[0] as FieldData).kind


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
	if v8:
		_satt0 = {}
		for i in satt_ids():
			_satt0[int(i)] = true


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
			e["next"] = int(NEXT8.get(k, -1)) if v8 else int(FieldData.NEXT[k])
		ev.append(e)


## Warum wächst diese Reihe (Art k, key = line_key) nicht? "" = nichts zu sagen (sie stand schon so da).
func _still_why(k: int, diag: bool, key: int) -> String:
	var diag_ok := not diag or (diagonals and FieldData.tier(k) >= diag_from)
	if _eq0.has(key):
		# Stand schon vor dem Zug genau so da und wurde nur mitgedreht: Hinweis nur, wenn sie sonst wachsen würde
		return "standing" if can_row(k) and diag_ok else ""
	if FieldData.finished(k):
		return "finished"
	if k == FieldData.STONE:
		return "stone"
	if not FieldData.can_row(k):
		return "water"
	if v8 and not can_row(k):
		# Die 7 Tage: ruht bis zu einem späteren Tag, Menschen wachsen durch Nachbarn, sonst heute keine Reihe mehr
		if later8.has(k):
			return "rest"
		return "people" if FieldData.level8(k) >= 0 else "done"
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
	if v8:
		return int(next8.get(k, k)) if can_row(k) else k
	if is_choice(k):
		return FieldData.next_kind(k, option)
	if not FieldData.valid(k):
		return k
	var nx: int = int(FieldData.NEXT[k])
	return nx if nx >= 0 and unlocked.has(nx) else k


## Erklärung für das lange Drücken auf ein Feld dieser Art (heutige Regeln).
func kind_help(k: int) -> String:
	if v8:
		return kind_help8(k)
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
	if v8:
		return next_of(k)
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
		if once:
			_spend_face(face)
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


## Jede Reihe wächst nur einmal: alle Reihen einer Seite, die als Ganzes wächst, sind verbraucht (vor dem Wachsen).
func _spend_face(face: Array) -> void:
	if not _cache_ready:
		_build_cache()
	var on := {}
	for g in face:
		on[(g as FieldData).id] = true
	var i := 0
	var n := _LINES.size()
	while i < n:
		var f0: FieldData = _index[_LINES[i]]
		var f1: FieldData = _index[_LINES[i + 1]]
		var f2: FieldData = _index[_LINES[i + 2]]
		if on.has(f0.id) and on.has(f1.id) and on.has(f2.id):
			spent[line_key([f0, f1, f2])] = true
		i += 4


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
			if pass_i > 0 and once and spent.has(line_key(ln)):
				continue        # auch eine Kettenreaktion bildet eine schon gewachsene Reihe nicht noch einmal
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
				if once:
					spent[line_key(line)] = true
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
			if once:
				spent[line_key(line)] = true      # vor dem Wachsen: der Schlüssel trägt die alte Art
			_grow_to(mid, grown(k0, mid.id))
			mid.burning = false
			focus[mid.id] = true
			touched[mid.id] = true
			changed[mid.id] = true
			var other_ids: Array = []
			for g in rest:
				other_ids.append((g as FieldData).id)
			var eaten: Array = []
			if v8 and FieldData.level8(mid.kind) >= 0:
				# Gedeihen beginnt: Die neue Hütte ist hungrig; 3 Tiere → 1 Hütte, die anderen beiden werden Wiese
				mid.maxlvl = maxi(mid.maxlvl, FieldData.level8(mid.kind))
				mid.fed = 0
				mid.hungry = 0
				if consume8:
					for g in rest:
						var og: FieldData = g
						if og.kind == k0:
							og.kind = FieldData.MEADOW
							og.burning = false
							locked[og.id] = true
							done[og.id] = true
							touched[og.id] = true
							eaten.append(og.id)
				locked[mid.id] = true
			ev.append({"type": "merge", "field": mid.id, "others": other_ids, "points": pts, "combo": combo, "stage": mid.kind, "kind": mid.kind, "from": k0, "late": late, "consume": not eaten.is_empty(), "eaten": eaten})
			if not eaten.is_empty():
				ev.append({"type": "consume", "field": mid.id, "others": eaten, "from": k0, "kind": mid.kind, "left": FieldData.MEADOW})
	# Einfach: Reihen, deren drei Felder alle gerade zusammen gewachsen sind, zählen nie wieder.
	if easy and not done.is_empty():
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
	if v8:
		return _end_round8(ans)
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
				if nat >= Balance.REGROW_NEIGHBORS and not _regrow_closes_row(f):
					grow.append([nat, f.id])
			grow.sort_custom(func(x, y): return int(x[0]) > int(y[0]) or (int(x[0]) == int(y[0]) and int(x[1]) < int(y[1])))
			for item in grow.slice(0, Balance.REGROW_PER_TWIST):
				var rf: FieldData = fields[int(item[1])]
				rf.kind = FieldData.MEADOW
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


## „Nachwachsen schließt keine Reihe“ (GDPD_BALANCE_2.md 3): Würde diese Erde als Wiese eine Reihe aus 3 Wiesen
## vollenden (gerade, oder schräg, wo Schräge zählen), wächst sie nicht nach.
func _regrow_closes_row(f: FieldData) -> bool:
	var was := f.kind
	f.kind = FieldData.MEADOW
	var hit := not lines({f.id: true}).is_empty()
	f.kind = was
	return hit


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
	var got := _progress(0 if v8 else gain + wish_gain, corners)
	_drop_dead_wishes(ev)
	_check_complete(ev)
	if v8:
		_round_tail8(ev)
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
	var res := resolve_now(ans) if (t == "rain" or (v8 and (t == "meteor" or t == "strike"))) else end_round(ans)
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
		if f.burning or (v8 and f.id == bolt):
			out[f.id] = "fire"
		elif useful.has(f.id):
			out[f.id] = "useful"
		elif (rain_to8(f) >= 0) if v8 else rain_grows(f.kind):
			out[f.id] = "grow"
	return out


## Lässt Regen diese Art heute wachsen? (Erde → Wiese → Wald → Großer Wald, nur wenn das Ergebnis freigeschaltet ist.)
func rain_grows(k: int) -> bool:
	if v8:
		var rk: Array = rain_kinds8
		return (k == FieldData.EMPTY and rk.has(FieldData.MEADOW)) or (k == FieldData.MEADOW and (rk.has(FieldData.FOREST) or bool(day.get("rain_acker", false))))
	return RAIN_NEXT.has(k) and unlocked.has(int(RAIN_NEXT[k]))


## Geht Regen auf dieses Feld? (Brennt es, löscht er; sonst muss es wachsen können.)
func rain_ok(f: FieldData) -> bool:
	if v8:
		return f.burning or f.id == bolt or rain_to8(f) >= 0
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
		if f.burning or (v8 and f.id == bolt):
			out[f.id] = "fire"
			continue
		if v8:
			if rain_to8(f) < 0:
				continue
		elif not rain_grows(f.kind):
			continue
		var was: int = f.kind
		f.kind = rain_to8(f) if v8 else int(RAIN_NEXT[was])
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
	if v8:
		return _can_bonus8(kind, f)
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
	if v8:
		_apply_bonus8(kind, f)
		return
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
	if t == "satt":
		var n := 0
		var gk := goal_kinds()
		for f in fields:
			if gk.has(f.kind) and satt(f):
				n += 1
		return n
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
	extra_level = 0
	while extra_level < extra_max() and goal_progress() >= extra_target():
		extra_level += 1          # schon beim Sieg übertroffen: die nächste Extra-Aufgabe liegt darüber


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
		"won_at": day_won_at, "stars": stars(), "no_war": no_war, "free_build": day_free_build, "growth": build_growth(),
		"v8": v8, "extra_level": extra_level, "extra_max": extra_max(), "extra_target": extra_target(),
		"extra_text": Days.extra_line(day, extra_target()) if extra_level < extra_max() else str(Days.TEXT.get("build_on", "Bau weiter")),
		"needs": goal_needs(), "need_icons": goal_need_icons(), "bolt": bolt, "war_on": war_on, "front": front.keys(),
		"flood_warn": flood_warn.keys(), "faith": faith, "rain": rain}


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
	if v8:
		return _best_day_action8(twist_only)
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


# =============================================================================
# Die 7 Tage nach GDPD_BALANCE_2.md: Erschaffen (Reihen) und Gedeihen (Nachbarn)
# „Zuerst schützt du die Menschen vor der Natur, später die Natur vor den Menschen.“
# Port von rules8.gd (gegen das Python-Modell engine8.py geprüft). Ablauf einer Drehung (4.5):
#   1 Reihen (once, 3 Tiere → 1 Hütte)  2 Drehungen +1, Rauch −1  3 Feuer  4 Blitz  5 Smog  6 Flut  7 Krieg
#   9 Gedeihen (satt / wachsen / Hunger / schrumpfen)  10 Glaube  11 Regen  12 Ziel
# =============================================================================

## Quellen der Bedürfnisse (4.1): ein Nachbar dieser Art erfüllt das Bedürfnis (wird nicht verbraucht).
const SOURCES8 = {"food": [FieldData.ANIMALS, FieldData.FIELD], "work": [FieldData.FOREST, FieldData.STONE, FieldData.INDUSTRY],
	"faith": [FieldData.CHURCH], "water": [FieldData.WATER]}
## Bedürfnisse je Menschen-Art (Hütte 🍞, Dorf 🍞🔨, Stadt 🍞🔨🙏).
const NEEDS8 = {FieldData.HUT: ["food"], FieldData.VILLAGE: ["food", "work"], FieldData.TOWN: ["food", "work", "faith"]}
const PEOPLE8 = [FieldData.HUT, FieldData.VILLAGE, FieldData.TOWN]
## Nächste Art einer Reihe an den Tagen (welche davon heute zählen, sagt "rows").
const NEXT8 = {FieldData.EMPTY: FieldData.MEADOW, FieldData.MEADOW: FieldData.FOREST, FieldData.FOREST: FieldData.ANIMALS,
	FieldData.ANIMALS: FieldData.HUT}
## Was brennen kann → was danach übrig ist.
const FLAMMABLE8 = {FieldData.FOREST: FieldData.MEADOW, FieldData.ANIMALS: FieldData.MEADOW, FieldData.HUT: FieldData.MEADOW,
	FieldData.VILLAGE: FieldData.HUT}
const BOLT_KINDS8 = [FieldData.FOREST, FieldData.ANIMALS]
const WAR_DOWN8 = {FieldData.TOWN: FieldData.VILLAGE, FieldData.VILLAGE: FieldData.HUT, FieldData.HUT: FieldData.MEADOW}
const SMOG_DOWN8 = {FieldData.ANIMALS: FieldData.FOREST, FieldData.FOREST: FieldData.MEADOW, FieldData.MEADOW: FieldData.EMPTY}
const SMOG_RANK8 = {FieldData.ANIMALS: 3, FieldData.FOREST: 2, FieldData.MEADOW: 1}
const LOW8 = [FieldData.EMPTY, FieldData.MEADOW, FieldData.FIELD, FieldData.HUT]
const CITY_W8 = {FieldData.VILLAGE: 1, FieldData.TOWN: 2, FieldData.INDUSTRY: 2}
const FRESH8 := 2                 # verbrannte Felder fangen so viele Feuer-Schritte kein Feuer
const RAIN_MAX8 := 3
const METEOR_COST := 12
## Glaube je neuer Stufe neben einer Kirche (ein gutes Spiel bringt etwa einen Meteor, Hin und her keinen).
const FAITH_STEP := 3
## Bedürfnisse für die Oberfläche: Symbol, Name, Pille, wenn es fehlt.
const NEED_ICON = {"food": "hunger", "work": "trade", "faith": "faith", "water": "water"}
const NEED_NAME = {"food": "Nahrung", "work": "Arbeit", "faith": "Glaube", "water": "Wasser"}
const NEED_PILL = {"food": "Hunger", "work": "Keine Arbeit", "faith": "Zweifel", "water": "Durst"}
## Ereignisse, nach denen eine Drehung nicht „Nichts gewachsen“ heißt (es ist ja etwas passiert).
const _EV8_NOTE = ["thrive", "starve", "satt_new", "satt_lost", "bolt_warn", "bolt", "ignite", "burn", "war_start",
	"war_hit", "war_end", "flood", "flood_warn", "polluted", "goal", "consume"]


func _apply_rules8(cfg: Dictionary) -> void:
	rows8 = {}
	for k in cfg.get("rows", []):
		rows8[int(k)] = true
	next8 = {}
	var nx: Dictionary = cfg.get("next8", NEXT8)
	for key in nx:
		next8[int(str(key))] = int(nx[key])
	later8 = {}
	for k in cfg.get("later_rows", []):
		later8[int(k)] = true
	top8 = int(cfg.get("top", -1))
	needs8 = {}
	var nd: Dictionary = cfg.get("needs", NEEDS8)
	for key in nd:
		needs8[int(str(key))] = (nd[key] as Array).duplicate()
	consume8 = bool(cfg.get("consume", true))
	rain_kinds8 = []
	for k in cfg.get("rain_kinds", []):
		rain_kinds8.append(int(k))
	no_fire = true                # keine „3 Fehlversuche → Feuer“ mehr; Feuer kommt vom Blitz (ab Tag 3)
	sys_wishes = false
	sys_scale = false
	sys_income = false
	sys_war = false
	no_war = false
	sys_smog = false
	sys_strike = false
	sys_gift = false
	choices_on = {}
	bolt = -1
	war_on = false
	front = {}
	flood_warn = {}
	extra_level = 0


func _next_to8(f: FieldData, k: int) -> bool:
	for g in neighbors(f):
		if (g as FieldData).kind == k:
			return true
	return false


func people8(k: int) -> bool:
	return FieldData.level8(k) >= 0


## Bedürfnisse einer Art heute ([] wenn keine Menschen).
func need_list(k: int) -> Array:
	return needs8.get(k, [])


## Was hat ein Menschen-Feld, was fehlt ihm? {"met": [...], "missing": [...]} (Namen: food, work, faith, water).
func need_state(f: FieldData) -> Dictionary:
	var have := {}
	for g in neighbors(f):
		have[(g as FieldData).kind] = true
	var met: Array = []
	var miss: Array = []
	for n in need_list(f.kind):
		var ok := false
		for s in SOURCES8[str(n)]:
			if have.has(int(s)):
				ok = true
		if ok:
			met.append(str(n))
		else:
			miss.append(str(n))
	return {"met": met, "missing": miss}


## Satt: alle Bedürfnisse erfüllt, brennt nicht, steht nicht an der Kriegsfront.
func satt(f: FieldData) -> bool:
	if not v8 or not people8(f.kind) or not needs8.has(f.kind):
		return false
	if f.burning or front.has(f.id):
		return false
	return (need_state(f)["missing"] as Array).is_empty()


func satt_ids() -> Array:
	var out: Array = []
	for f in fields:
		if satt(f):
			out.append(f.id)
	return out


## Zustand eines Felds für Anzeige und Felder-Ansicht: {"people", "satt", "met", "missing", "fed", "hungry", "grow_after",
## "shrink_after", "burning", "fresh", "front", "bolt", "wet"}.
func field_state8(f: FieldData) -> Dictionary:
	var ns := need_state(f) if people8(f.kind) else {"met": [], "missing": []}
	return {"people": people8(f.kind), "satt": satt(f), "met": ns["met"], "missing": ns["missing"], "fed": f.fed,
		"hungry": f.hungry, "grow_after": int(day.get("grow_after", 2)), "shrink_after": int(day.get("shrink_after", 4)),
		"burning": f.burning, "fresh": f.fresh, "front": front.has(f.id), "bolt": f.id == bolt, "wet": _wet8(f)}


func _wet8(f: FieldData) -> bool:
	for g in neighbors(f):
		if (g as FieldData).kind == FieldData.WATER:
			return true
	return false


func face_index(f: FieldData) -> int:
	return FACE_NORMALS.find(f.n)


## Stadt-Gewicht einer Seite (Dorf 1, Stadt 2, Industrie 2): ab flood_at (5) steigt das Meer.
func city_weight8(fc: int) -> int:
	var w := 0
	for g in face_fields(FACE_NORMALS[fc]):
		w += int(CITY_W8.get((g as FieldData).kind, 0))
	return w


## Kirchen, die eine andere Kirche berühren (Krieg).
func church_touch8() -> Array:
	var out: Array = []
	for f in fields:
		if f.kind != FieldData.CHURCH:
			continue
		for g in neighbors(f):
			if (g as FieldData).kind == FieldData.CHURCH and not out.has(f.id):
				out.append(f.id)
	return out


func _next_people8(k: int) -> int:
	var i := PEOPLE8.find(k)
	if i < 0 or i + 1 >= PEOPLE8.size():
		return -1
	var nk: int = PEOPLE8[i + 1]
	if top8 < 0 or PEOPLE8.find(nk) > PEOPLE8.find(top8):
		return -1
	return nk


## Gedeihen (4.3): satt → nach grow_after Runden die nächste Stufe; hungrig → nach shrink_after Runden eine zurück.
func _thrive8(ev: Array) -> void:
	var G := int(day.get("grow_after", 2))
	var H := int(day.get("shrink_after", 4))
	for f in fields:
		var k: int = f.kind
		if not people8(k):
			f.fed = 0
			f.hungry = 0
			continue
		if satt(f):
			f.hungry = 0
			f.fed += 1
			var nk := _next_people8(k)
			if nk >= 0 and f.fed >= G:
				f.kind = nk
				f.fed = 0
				var first: bool = FieldData.level8(nk) > f.maxlvl
				if first:
					f.maxlvl = FieldData.level8(nk)
					made[nk] = int(made[nk]) + 1
				ev.append({"type": "thrive", "field": f.id, "from": k, "kind": nk, "first": first})
		else:
			f.fed = 0
			f.hungry += 1
			if f.hungry >= H and PEOPLE8.find(k) > 0:
				var lk: int = PEOPLE8[PEOPLE8.find(k) - 1]
				f.kind = lk
				f.hungry = 0
				ev.append({"type": "starve", "field": f.id, "from": k, "kind": lk})


func _fire_step8(ev: Array) -> void:
	var old: Array = []
	for f in fields:
		if f.burning:
			old.append(f)
	var nw := {}
	for f in old:
		for g in neighbors(f):
			var h: FieldData = g
			if FLAMMABLE8.has(h.kind) and not h.burning and h.fresh == 0 and not _wet8(h):
				nw[h.id] = true
	for f in old:
		var fd: FieldData = f
		var k := fd.kind
		fd.kind = int(FLAMMABLE8.get(k, k))
		fd.burning = false
		fd.fresh = FRESH8 + 1
		fd.fed = 0
		fd.hungry = 0
		stats["fires"] = int(stats["fires"]) + 1
		ev.append({"type": "burn", "field": fd.id, "from": k, "kind": fd.kind})
	var ks: Array = nw.keys()
	ks.sort()
	for i in ks:
		(fields[int(i)] as FieldData).burning = true
		ev.append({"type": "ignite", "field": int(i)})


func _lightning_step8(ev: Array) -> void:
	if bolt >= 0:
		var bf: FieldData = fields[bolt]
		bolt = -1
		if BOLT_KINDS8.has(bf.kind) and not bf.burning and bf.fresh == 0:
			bf.burning = true
			stats["bolts"] = int(stats["bolts"]) + 1
			ev.append({"type": "bolt", "field": bf.id})
		else:
			ev.append({"type": "bolt_miss", "field": bf.id})
	var every := int(day.get("lightning", 0))
	var from := int(day.get("lightning_from", 2))
	if every > 0 and twists >= from and (twists - from) % every == 0:
		var best: Array = []
		var top_n := -1
		for f in fields:
			if BOLT_KINDS8.has(f.kind) and not f.burning and f.fresh == 0:
				var n := 0
				for g in neighbors(f):
					if FLAMMABLE8.has((g as FieldData).kind):
						n += 1
				if n > top_n:
					top_n = n
					best = [f.id]
				elif n == top_n:
					best.append(f.id)
		if not best.is_empty():
			bolt = int(best[_rand(best.size())])
			ev.append({"type": "bolt_warn", "field": bolt})


func _smog_step8(ev: Array) -> void:
	var hits: Array = []
	for f in fields:
		if f.kind != FieldData.INDUSTRY:
			continue
		var best: FieldData = null
		var bt := -1
		for g in neighbors(f):
			var h: FieldData = g
			if SMOG_RANK8.has(h.kind) and int(SMOG_RANK8[h.kind]) > bt:
				bt = int(SMOG_RANK8[h.kind])
				best = h
		if best != null:
			var k0 := best.kind
			best.kind = int(SMOG_DOWN8[k0])
			best.burning = false
			hits.append(best.id)
			stats["withered"] = int(stats["withered"]) + 1
			ev.append({"type": "polluted", "field": best.id, "by": f.id, "industry": f.id, "from": k0, "kind": best.kind})
	if not hits.is_empty():
		stats["smog"] = int(stats["smog"]) + 1
		ev.append({"type": "smog", "w": balance(), "fields": hits})


func _flood_step8(ev: Array) -> void:
	var at := int(day.get("flood_at", 5))
	var over := {}
	for fc in 6:
		if city_weight8(fc) >= at:
			over[fc] = true
	for fc in 6:
		if not over.has(fc) or not flood_warn.has(fc):
			continue
		var hit: Array = []
		for g in face_fields(FACE_NORMALS[fc]):
			var h: FieldData = g
			if LOW8.has(h.kind) and _wet8(h):
				hit.append(h)
		for g in hit:
			var h2: FieldData = g
			var k := h2.kind
			h2.kind = FieldData.WATER
			h2.burning = false
			h2.fed = 0
			h2.hungry = 0
			stats["floods"] = int(stats["floods"]) + 1
			ev.append({"type": "flood", "face": fc, "field": h2.id, "from": k, "kind": FieldData.WATER})
	var was := flood_warn
	flood_warn = over
	for fc in 6:
		if over.has(fc):
			ev.append({"type": "flood_warn", "face": fc, "new": not was.has(fc), "weight": city_weight8(fc)})


func _war_step8(ev: Array) -> void:
	var ch := church_touch8()
	if ch.is_empty():
		if war_on:
			ev.append({"type": "war_end"})
		war_on = false
		front = {}
		return
	var base := {}
	for i in ch:
		for g in neighbors(fields[int(i)]):
			if people8((g as FieldData).kind):
				base[(g as FieldData).id] = true
	if not war_on:
		war_on = true
		front = base
		stats["wars"] = int(stats["wars"]) + 1
		var fr: Array = base.keys()
		fr.sort()
		ev.append({"type": "war_start", "churches": ch, "front": fr})
		return
	var hit: Array = []
	for i in front:
		if people8((fields[int(i)] as FieldData).kind):
			hit.append(int(i))
	hit.sort()
	for i in hit:
		var f: FieldData = fields[i]
		var k := f.kind
		f.kind = int(WAR_DOWN8[k])
		f.fed = 0
		f.hungry = 0
		ev.append({"type": "war_hit", "field": f.id, "from": k, "kind": f.kind})
	var grow := base.duplicate()
	for i in front:
		for g in neighbors(fields[int(i)]):
			if people8((g as FieldData).kind):
				grow[(g as FieldData).id] = true
	var nf := {}
	for i in front:
		if people8((fields[int(i)] as FieldData).kind):
			nf[int(i)] = true
	for i in grow:
		if people8((fields[int(i)] as FieldData).kind):
			nf[int(i)] = true
	front = nf


## Eine Runde der neuen Tage (Ablauf 4.5). Glaube gibt es hier nur für Menschen neben einer Kirche (Meteor).
func _end_round8(ans: Dictionary) -> Dictionary:
	_open_turn()
	answers = ans.duplicate()
	var twist := _rotated
	var ev: Array = _pre_ev.duplicate(true)
	_pre_ev = []
	var age_before := age()
	var gain := resolve_merges(ev)
	moved = {}
	tapped = -1
	var got := {"rain": 0, "bolt": 0, "monsoon": 0}
	var faith_before := faith
	var income := 0
	if twist:
		twists += 1
		for f in fields:
			if f.fresh > 0:
				f.fresh -= 1
		_fire_step8(ev)
		if int(day.get("lightning", 0)) > 0:
			_lightning_step8(ev)
		if bool(day.get("smog8", false)):
			_smog_step8(ev)
		if bool(day.get("flood8", false)):
			_flood_step8(ev)
		if bool(day.get("war8", false)):
			_war_step8(ev)
		_thrive8(ev)
		if bool(day.get("meteor", false)):
			# nur eine NEUE Stufe neben einer Kirche bringt Glauben (zum ersten Mal Glaube oder gewachsen), je FAITH_STEP
			for f in fields:
				if not people8(f.kind) or FieldData.level8(f.kind) <= f.flvl or not _next_to8(f, FieldData.CHURCH):
					continue
				f.flvl = FieldData.level8(f.kind)
				income += FAITH_STEP
			if income > 0:
				faith += income
				faith_earned += income
				stats["income"] = int(stats["income"]) + income
				ev.append({"type": "income", "faith": income})
		if rain_every > 0 and twists % rain_every == 0 and rain < RAIN_MAX8:
			rain += 1
			got["rain"] = 1
		if rain_every > 0:
			next_rain = (twists / rain_every + 1) * rain_every
	broken = _broke_now if _rotated else {}
	_broke_now = {}
	_rotated = false
	for f in fields:
		ever[f.kind] = true
	_round_tail8(ev)
	_check_day(ev, false)
	if twist and _grew == 0:
		var note := false
		for e in ev:
			if _EV8_NOTE.has(str(e["type"])):
				note = true
		if not note:
			var mid_id: int = int(last_row[1]) if last_row.size() == 3 else -1
			ev.append({"type": "miss", "count": 0, "field": mid_id, "why": _miss_why(ev), "counted": false})
	return _close_turn(ev, gain, faith - faith_before, income, 0, 0, got, age_before)


## Nach jeder Runde und jedem Werkzeug: wer ist neu satt, wer nicht mehr; Extra-Aufgaben im Weiterbauen.
func _round_tail8(ev: Array) -> void:
	var now := {}
	for i in satt_ids():
		now[int(i)] = true
	for i in now:
		if not _satt0.has(i):
			ev.append({"type": "satt_new", "field": int(i), "kind": (fields[int(i)] as FieldData).kind})
	for i in _satt0:
		if not now.has(i):
			var f: FieldData = fields[int(i)]
			var miss: Array = need_state(f)["missing"] if people8(f.kind) else []
			ev.append({"type": "satt_lost", "field": int(i), "kind": f.kind, "missing": miss,
				"burning": f.burning, "front": front.has(f.id)})
	_satt0 = now
	if day_free_build:
		while extra_level < extra_max() and goal_progress() >= extra_target():
			extra_level += 1
			ev.append({"type": "extra", "level": extra_level, "target": goal_target() + extra_level, "max": extra_max(),
				"done": extra_level >= extra_max(), "text": Days.extra_line(day, goal_target() + extra_level)})


## Weiterbauen: so viele Extra-Aufgaben gibt es (Tage 1–3: drei, Tage 4–7: eine; freies Spiel/alte Tage: keine).
func extra_max() -> int:
	if not v8:
		return 0
	return int(day.get("extras", 3 if day_no <= 3 else 1))


## Ziel der nächsten Extra-Aufgabe (Aufgabe + 1, + 2, + 3).
func extra_target() -> int:
	return goal_target() + extra_level + 1


## Bedürfnisse der Ziel-Art (Gedeihen-Tage), sonst [].
func goal_needs() -> Array:
	if not v8 or goal_type() != "satt" or goal_kinds().is_empty():
		return []
	return need_list(int(goal_kinds()[0])).duplicate()


func goal_need_icons() -> Array:
	var out: Array = []
	for n in goal_needs():
		out.append(str(NEED_ICON.get(str(n), "info")))
	return out


## Was Regen aus diesem Feld macht (-1: nichts): Erde → Wiese (Tag 2), Wiese → Acker neben Menschen (rain_acker),
## sonst Wiese → Wald.
func rain_to8(f: FieldData) -> int:
	var rk: Array = rain_kinds8
	if f.kind == FieldData.EMPTY and rk.has(FieldData.MEADOW):
		return FieldData.MEADOW
	if f.kind == FieldData.MEADOW:
		if bool(day.get("rain_acker", false)):
			for g in neighbors(f):
				if people8((g as FieldData).kind):
					return FieldData.FIELD
		if rk.has(FieldData.FOREST):
			return FieldData.FOREST
	return -1


func meteor_ok(f: FieldData) -> bool:
	return v8 and bool(day.get("meteor", false)) and faith >= METEOR_COST and f.kind != FieldData.WATER


func _can_bonus8(kind: String, f: FieldData) -> String:
	if kind == "rain":
		if rain <= 0:
			return "Nächster Regen in %d Drehungen." % maxi(1, next_rain - twists) if rain_every > 0 else "Kein Regen mehr."
		if not rain_ok(f):
			var on: Array = []
			var rk: Array = rain_kinds8
			if rk.has(FieldData.MEADOW):
				on.append("Erde")
			if rk.has(FieldData.FOREST) or bool(day.get("rain_acker", false)):
				on.append("Wiese")
			if int(day.get("lightning", 0)) > 0:
				on.append("Blitz")
			on.append("Feuer")
			return "Nur auf %s." % (", ".join(PackedStringArray(on.slice(0, on.size() - 1))) + " oder " + str(on[on.size() - 1]))
		return ""
	if kind == "meteor" or kind == "strike":
		if not bool(day.get("meteor", false)):
			return "Heute gibt es keinen Meteor."
		if faith < METEOR_COST:
			return "Dafür brauchst du %d Glauben." % METEOR_COST
		if f.kind == FieldData.WATER:
			return "Nicht auf Wasser."
		return ""
	return "Heute nicht."


## Regen und Meteor an den neuen Tagen (danach resolve_now: Regen kann eine Reihe fertig machen).
func _apply_bonus8(kind: String, f: FieldData) -> void:
	if kind == "rain":
		rain -= 1
		stats["rains"] = int(stats["rains"]) + 1
		if f.id == bolt and not f.burning:
			bolt = -1
			_pre_ev.append({"type": "bolt_cancel", "field": f.id})
		elif f.burning:
			for g in face_fields(f.n):
				var h: FieldData = g
				if h.burning:
					h.burning = false
					_pre_ev.append({"type": "rain_out", "field": h.id})
		else:
			var nk := rain_to8(f)
			if nk >= 0:
				tapped = f.id
				_grow_to(f, nk)
				moved[f.id] = true
				_pre_ev.append({"type": "rain", "field": f.id, "kind": nk})
		return
	if kind == "meteor" or kind == "strike":
		faith -= METEOR_COST
		stats["strikes"] = int(stats["strikes"]) + 1
		var k := f.kind
		f.kind = FieldData.EMPTY
		f.burning = false
		f.fed = 0
		f.hungry = 0
		f.fresh = 0
		front.erase(f.id)
		_pre_ev.append({"type": "meteor", "field": f.id, "from": k, "kind": FieldData.EMPTY, "cost": METEOR_COST})
		if kind == "strike":
			# Für die Werkzeug-Wirkung der Oberfläche (Platz des Gewitters)
			_pre_ev.append({"type": "strike", "field": f.id, "hit": [{"field": f.id, "from": k, "kind": FieldData.EMPTY}],
				"cost": METEOR_COST, "faith": -METEOR_COST, "meteor": true})


## Langes Drücken auf ein Feld an den neuen Tagen: was es heute tut (kurz).
func kind_help8(k: int) -> String:
	var name := FieldData.kind_name(k)
	if can_row(k):
		var txt := "%s. 3 in einer Reihe: %s." % [name, FieldData.kind_name(next_of(k))]
		var gives := _gives8(k)
		return txt + (" " + gives if gives != "" else "")
	if people8(k):
		var ns: Array = []
		for n in need_list(k):
			ns.append(str(NEED_NAME.get(str(n), n)))
		if ns.is_empty():
			return "%s. Hier wohnen Menschen." % name
		var last := str(ns.pop_back())
		var list := last if ns.is_empty() else ", ".join(PackedStringArray(ns)) + " und " + last
		return "%s. Braucht %s." % [name, list]
	var g := _gives8(k)
	if k == FieldData.CHURCH:
		return "Kirche. Gibt Glaube. Nie neben Kirche!"
	if k == FieldData.INDUSTRY:
		return "Fabrik. Gibt Arbeit, macht Smog."
	if k == FieldData.WATER:
		return "Wasser. Schützt vor Feuer."
	if g != "":
		return "%s. %s" % [name, g]
	if later8.has(k):
		return "%s. %s" % [name, FieldData.REST_HELP]
	return "%s." % name


func _gives8(k: int) -> String:
	if top8 < 0:
		return ""
	if SOURCES8["food"].has(k):
		return "Gibt Nahrung." if k == FieldData.FIELD else "Geben Nahrung." if k == FieldData.ANIMALS else ""
	if SOURCES8["work"].has(k) and needs8.has(FieldData.VILLAGE) and top8 >= FieldData.VILLAGE:
		return "Gibt Arbeit."
	return ""


## Vorschau beim Ziehen einer Scheibe (Vertrag 4.6): der Stand nach der Drehung, vor der Auswertung.
## {"satt_new", "satt_lost" (IDs), "need_met", "need_lost" ({ID: [Bedürfnisse]}), "rows" ([[a, b, c, Art]] die zählen),
##  "war_risk" (Kirchen würden sich berühren), "flood_risk" (Seiten mit Gewicht ≥ flood_at), "fire_risk" (IDs)}
## satt_new/satt_lost kommen aus dem Stand NACH der Auswertung (post: dieselbe Drehung samt end_round, z. B. aus
## Game.preview; ohne post rechnet preview8 sie selbst): so zählen Verschmelzen (3 Tiere → Hütte), Krieg und Wachsen mit.
## Wer durch Wachsen eine Stufe höher kommt (und dort noch etwas braucht), verliert nichts.
func preview8(axis: int, layer: int, turns: int, post: GameState = null) -> Dictionary:
	var t := clone()
	t.moved = {}
	t._turn_open = true
	t._broke_now = {}
	t.apply_rotation(axis, layer, turns)
	if post == null:
		post = clone()
		post.apply_rotation(axis, layer, turns)
		post.end_round()
	var before := {}
	for i in satt_ids():
		before[int(i)] = true
	var after := {}
	for i in post.satt_ids():
		after[int(i)] = true
	var sn: Array = []
	var sl: Array = []
	for i in after:
		if not before.has(i):
			sn.append(int(i))
	for i in before:
		if not after.has(i) and FieldData.level8((post.fields[int(i)] as FieldData).kind) <= FieldData.level8((fields[int(i)] as FieldData).kind):
			sl.append(int(i))
	sn.sort()
	sl.sort()
	var met := {}
	var lost := {}
	for f in t.fields:
		if not people8(f.kind):
			continue
		var a: Array = t.need_state(f)["met"]
		var b: Array = need_state(fields[f.id])["met"] if (fields[f.id] as FieldData).kind == f.kind else []
		var gained: Array = []
		var gone: Array = []
		for n in a:
			if not b.has(n):
				gained.append(n)
		for n in b:
			if not a.has(n):
				gone.append(n)
		if not gained.is_empty():
			met[f.id] = gained
		if not gone.is_empty():
			lost[f.id] = gone
	var rws: Array = []
	for ln in t.lines(t.moved):
		if t.counts(ln):
			rws.append([(ln[0] as FieldData).id, (ln[1] as FieldData).id, (ln[2] as FieldData).id, (ln[0] as FieldData).kind])
	var fr: Array = []
	if bool(day.get("flood8", false)):
		for fc in 6:
			if t.city_weight8(fc) >= int(day.get("flood_at", 5)):
				fr.append(fc)
	var fire: Array = []
	for f in t.fields:
		if not f.burning:
			continue
		for g in t.neighbors(f):
			var h: FieldData = g
			if FLAMMABLE8.has(h.kind) and not h.burning and h.fresh == 0 and not t._wet8(h) and not fire.has(h.id):
				fire.append(h.id)
	fire.sort()
	return {"satt_new": sn, "satt_lost": sl, "need_met": met, "need_lost": lost, "rows": rws,
		"war_risk": bool(day.get("war8", false)) and not t.church_touch8().is_empty(), "flood_risk": fr, "fire_risk": fire}


# --- Tipp an den neuen Tagen (wie der Bot „good“ des Modells, bot8.py) ---------------------------------------

const _LADDER8 = {1: 6.0, 2: 2.5, 3: 1.0, 4: 0.4}


func _chain_dist8() -> Dictionary:
	var dist := {}
	for k in goal_kinds():
		dist[int(k)] = 0
	var changed := true
	while changed:
		changed = false
		for k in FieldData.KIND_COUNT:
			if not can_row(k):
				continue
			var nx := next_of(k)
			if dist.has(nx) and not goal_kinds().has(k) and (not dist.has(k) or int(dist[k]) > int(dist[nx]) + 1):
				dist[k] = int(dist[nx]) + 1
				changed = true
	return dist


func _row_weights8() -> Array:
	var w: Array = []
	for k in FieldData.KIND_COUNT:
		w.append(0.0)
	if goal_type() == "make":
		var d := _chain_dist8()
		for k in d:
			if int(d[k]) > 0:
				w[int(k)] = float(_LADDER8.get(int(d[k]), 0.1))
	else:
		for k in rows8:
			w[int(k)] = 0.3
		var gk := int(goal_kinds()[0]) if not goal_kinds().is_empty() else FieldData.HUT
		if rows8.has(FieldData.ANIMALS):
			w[FieldData.ANIMALS] = 1.5 if gk == FieldData.HUT else 0.6
		if rows8.has(FieldData.FOREST):
			w[FieldData.FOREST] = 0.6
	return w


func _pairs8(w: Array) -> float:
	if not _cache_ready:
		_build_cache()
	var v := 0.0
	var i := 0
	var n := _LINES.size()
	while i < n:
		if _LINES[i + 3] == 0:
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


func _people_value8() -> float:
	var tk := int(goal_kinds()[0]) if not goal_kinds().is_empty() else FieldData.HUT
	var tl := FieldData.level8(tk)
	var G := int(day.get("grow_after", 2))
	var v := 0.0
	for f in fields:
		var k: int = f.kind
		if not people8(k):
			continue
		var miss: Array = need_state(f)["missing"]
		var lv := FieldData.level8(k)
		var ok: bool = miss.is_empty() and not f.burning and not front.has(f.id)
		if k == tk:
			v += 30.0 if ok else float(8 - 6 * miss.size())
			v -= 3.0 * float(f.hungry)
		elif lv < tl:
			v += 6.0 + 4.0 * float(lv)
			if ok:
				v += 6.0 + 5.0 * float(mini(f.fed, G))
				var nk: int = PEOPLE8[lv + 1]
				var ks := {}
				for g in neighbors(f):
					ks[(g as FieldData).kind] = true
				for nn in need_list(nk):
					for s in SOURCES8[str(nn)]:
						if ks.has(int(s)):
							v += 4.0
							break
			else:
				v -= 3.0 * float(miss.size())
		else:
			v += 10.0
		if f.burning:
			v -= 25.0
		if front.has(f.id):
			v -= 20.0
	return v


func _danger_value8() -> float:
	var v := 0.0
	for f in fields:
		if not f.burning:
			continue
		v -= 6.0
		for g in neighbors(f):
			var h: FieldData = g
			if FLAMMABLE8.has(h.kind) and not h.burning and not _wet8(h) and h.fresh == 0:
				v -= 5.0 + (12.0 if people8(h.kind) else 0.0)
	if bolt >= 0 and BOLT_KINDS8.has((fields[bolt] as FieldData).kind):
		v -= 4.0
		for g in neighbors(fields[bolt]):
			var h2: FieldData = g
			if FLAMMABLE8.has(h2.kind) and not _wet8(h2):
				v -= 3.0 + (6.0 if people8(h2.kind) else 0.0)
	if bool(day.get("war8", false)):
		if war_on:
			v -= 30.0
		v -= 15.0 * float(church_touch8().size())
	if bool(day.get("flood8", false)):
		var fa := int(day.get("flood_at", 5))
		for fc in 6:
			var cw := city_weight8(fc)
			if cw >= fa:
				var low := 0
				for g in face_fields(FACE_NORMALS[fc]):
					if LOW8.has((g as FieldData).kind) and _wet8(g):
						low += 1
				v -= 25.0 + 10.0 * float(low)
			elif cw == fa - 1:
				v -= 3.0
	if bool(day.get("smog8", false)):
		for f in fields:
			if f.kind == FieldData.INDUSTRY:
				for g in neighbors(f):
					if SMOG_RANK8.has((g as FieldData).kind):
						v -= 4.0
	return v


## Wert des Stands für das Ziel des Tages (bot8.state_value).
func value8() -> float:
	if day_won and not day_free_build:
		return 1e6 - 1000.0 * float(twists)
	var v := 0.0
	var p := goal_progress()
	if goal_type() == "make":
		v += 100.0 * float(p)
		var d := _chain_dist8()
		for f in fields:
			var dk := int(d.get(f.kind, -1))
			if dk > 0:
				v += 3.0 * float(_LADDER8.get(dk, 0.1))
	else:
		v += 100.0 * float(p) + _people_value8()
		var gk := int(goal_kinds()[0]) if not goal_kinds().is_empty() else FieldData.HUT
		if gk == FieldData.HUT or rows8.has(FieldData.ANIMALS):
			v += 1.5 * float(count(FieldData.ANIMALS))
	v += _danger_value8()
	if bool(day.get("meteor", false)):
		v += 0.3 * float(mini(faith, METEOR_COST))
	return v + _pairs8(_row_weights8())


## Der Tipp an den neuen Tagen: erst Werkzeuge (Regen, Meteor auf Kirche/Fabrik), wenn sie klar helfen, dann die
## beste Drehung (alle 27, die besten 6 mit einem Blick auf die nächste Drehung).
## Meteor heißt hier "strike" (Platz des Gewitters in der Oberfläche). Am Stück; dieselbe Suche in Schritten: day_search().
func _best_day_action8(twist_only: bool) -> Dictionary:
	var search := DaySearch8.new(self, twist_only)
	search.step(-1)
	return search.result


## Die Tipp-Suche eines Tages in kleinen Schritten (für die Oberfläche: auf mehrere Bilder verteilt, Game.search_hint).
## null, wenn der Tag nicht nach den neuen Regeln läuft (dann am Stück: best_day_action). Die Suche läuft nie auf
## einem zweiten Thread: Godot 4.3 liest die const-Tabellen (MOVES, FieldData …) nicht threadsicher.
func day_search(twist_only: bool = false) -> DaySearch8:
	if not v8 or not is_day() or is_over():
		return null
	return DaySearch8.new(self, twist_only)


## Genau _best_day_action8, aber in Einheiten von je einer Simulation: step(budget) rechnet, bis die Zeit (µs) um ist
## (budget < 0: bis zum Ende), und gibt true zurück, wenn result fertig ist.
class DaySearch8 extends RefCounted:
	var gs: GameState
	var done := false
	var result: Dictionary = {}
	var _phase := 0                # 0 Werkzeuge, 1 alle Drehungen, 2 Blick auf die nächste Drehung
	var _p0 := 0
	var _base := 0.0
	var _tools: Array = []         # Werkzeug-Aktionen (Regen, Meteor), in der Reihenfolge der Felder
	var _ti := 0
	var _best_t: Dictionary = {}
	var _best_tv := -INF
	var _scored: Array = []        # [Wert, Drehung, Zustand danach]
	var _mi := 0
	var _pick: Array = []
	var _best_v := -INF
	var _ci := 0                   # Kandidat für den Blick voraus
	var _m2 := 0
	var _v2b := -INF

	func _init(state: GameState, twist_only: bool) -> void:
		gs = state
		_p0 = gs.goal_progress()
		_phase = 1 if twist_only else 0
		if twist_only:
			return
		_base = gs.value8()
		if gs.rain > 0:
			for f in gs.fields:
				if gs.rain_ok(f):
					_tools.append({"type": "rain", "field": f.id})
		if bool(gs.day.get("meteor", false)) and gs.faith >= GameState.METEOR_COST:
			for f in gs.fields:
				if f.kind == FieldData.CHURCH or f.kind == FieldData.INDUSTRY:
					_tools.append({"type": "strike", "field": f.id})

	func step(budget_usec: int = -1) -> bool:
		var t0 := Time.get_ticks_usec()
		while not done:
			_unit()
			if budget_usec >= 0 and Time.get_ticks_usec() - t0 >= budget_usec:
				break
		return done

	## Höchstens eine Simulation.
	func _unit() -> void:
		if _phase == 0:
			if _ti < _tools.size():
				var a: Dictionary = _tools[_ti]
				_ti += 1
				var st: GameState = gs.simulate(a)["state"]
				var v := st.value8()
				if v > _best_tv:
					_best_tv = v
					_best_t = {"type": str(a["type"]), "field": int(a["field"]), "value": v, "progress": st.goal_progress()}
				return
			var need := 6.0 if gs.rain <= 1 else 3.0
			if not _best_t.is_empty() and _best_tv > _base + need:
				_best_t["choice"] = -1
				_best_t["card"] = -1
				_best_t["steps"] = 1
				_best_t["points"] = 0
				result = _best_t
				done = true
				return
			_phase = 1
			return
		if _phase == 1:
			if _mi < GameState.MOVES.size():
				var m: Array = GameState.MOVES[_mi]
				_mi += 1
				var st3: GameState = gs.simulate({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])})["state"]
				_scored.append([st3.value8(), m, st3])
				return
			_scored.sort_custom(func(x, y): return float(x[0]) > float(y[0]))
			_pick = _scored[0]
			var first: GameState = _pick[2]
			if first.day_won and not first.day_free_build:
				_finish()
				return
			_phase = 2
			return
		if _ci >= mini(6, _scored.size()):
			_finish()
			return
		var c: Array = _scored[_ci]
		var s1: GameState = c[2]
		var v1 := float(c[0])
		if s1.is_over():
			_consider(c, v1 if s1.day_won else v1 - 1e5)
			return
		if _m2 < GameState.MOVES.size():
			var m2: Array = GameState.MOVES[_m2]
			_m2 += 1
			var s2: GameState = s1.simulate({"type": "twist", "axis": int(m2[0]), "layer": int(m2[1]), "turns": int(m2[2])})["state"]
			_v2b = maxf(_v2b, s2.value8())
			return
		_consider(c, 0.4 * v1 + 0.6 * _v2b)

	## Ein Kandidat ist durchgerechnet: der nächste.
	func _consider(c: Array, v: float) -> void:
		if v > _best_v:
			_best_v = v
			_pick = c
		_ci += 1
		_m2 = 0
		_v2b = -INF

	func _finish() -> void:
		var pm: Array = _pick[1]
		var ps: GameState = _pick[2]
		result = {"type": "twist", "axis": int(pm[0]), "layer": int(pm[1]), "turns": int(pm[2]), "choice": -1, "card": -1,
			"value": float(_pick[0]), "steps": 1 if ps.goal_progress() > _p0 or ps.day_won else 2, "points": 0,
			"progress": ps.goal_progress()}
		done = true
