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
	camp = false
	level_no = 0
	rows9 = {}
	consume9 = {}
	thrive9 = {}
	rain9 = []
	burn9 = {}
	goal9 = []
	goal_kinds9 = {}
	chain9 = {}
	sys9 = {}
	volc = -1
	pack_warn9 = {}
	hunt9 = []
	glacier9 = {}
	glac9 = -1
	glac_rest9 = []
	impact9 = {}
	impact_done9 = false
	smog_warn9 = {}
	meteors = 0
	held9 = []
	extra_steps = 0
	miracle_bought = {}
	trace9 = []
	paid9 = {}
	build_new9 = 0
	made = []
	lost9 = []
	for k in FieldData.KIND_COUNT:
		made.append(0)
		lost9.append(0)
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
	if camp:
		for k in FieldData.KIND_COUNT:
			_row_ok.append(rows9.has(k))
		return
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
	gs.camp = camp
	gs._act_seq = _act_seq
	if camp:
		gs.level_no = level_no
		gs.rows9 = rows9              # nur gelesen
		gs.consume9 = consume9        # nur gelesen
		gs.thrive9 = thrive9          # nur gelesen
		gs.rain9 = rain9              # nur gelesen
		gs.burn9 = burn9              # nur gelesen
		gs.goal9 = goal9              # nur gelesen
		gs.goal_kinds9 = goal_kinds9  # nur gelesen
		gs.chain9 = chain9            # nur gelesen
		gs.sys9 = sys9                # nur gelesen
		gs.cap9 = cap9
		gs.stars9 = stars9
		gs.par9 = par9
		gs.lost9 = lost9.duplicate()
		gs.volc = volc
		gs.pack_warn9 = pack_warn9.duplicate()
		gs.hunt9 = hunt9              # nur gelesen
		gs.glacier9 = glacier9        # nur gelesen
		gs.impact9 = impact9          # nur gelesen
		gs.glac9 = glac9
		gs.glac_rest9 = glac_rest9.duplicate()
		gs.impact_done9 = impact_done9
		gs.smog_warn9 = smog_warn9.duplicate()
		gs.meteors = meteors
		gs.held9 = held9.duplicate()
		gs.peak9 = peak9
		gs.gain_at9 = gain_at9
		gs.extra_steps = extra_steps
		gs.bolt_guard9 = bolt_guard9
		gs.miracle_bought = miracle_bought.duplicate()
		gs.trace9 = trace9.duplicate()
		gs.st9 = st9.duplicate()
		gs.paid9 = paid9.duplicate()
		gs.build_new9 = build_new9
		gs._won_told = _won_told
		gs._need_told = _need_told
		gs._era_last = _era_last
	for f in fields:
		gs.fields.append(f.copy())
	gs.rebuild_index()
	return gs


func rebuild_index() -> void:
	_nb_ok = false
	_grp_ok = false
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
			# Schöpfung (Build 12): nur eine Reihe, die schon gewachsen ist, gilt als „zurückgedreht“. Eine Reihe, die
			# nie wachsen konnte, gibt es nicht mehr (die späte Runde löst sie auf); niemand wird dafür getadelt.
			if camp and not engine9_mode and not spent.has(k):
				continue
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
	if camp:
		return tool_in_level9(kind)
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
	if v8 or camp:
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
	if camp:
		return _still_why9(k, diag, key)
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


## Was eine Reihe dieser Art ergibt – für Bilder und Texte (Feld-Karte). In der Schöpfung gilt rows9
## (Fels → Erde, Lava → Fels …), sonst next_of. Bildet die Art keine Reihe, bleibt sie, wie sie ist.
func row_result(k: int) -> int:
	if camp:
		return int(rows9.get(k, k))
	return next_of(k)


## Erklärung für das lange Drücken auf ein Feld dieser Art (heutige Regeln).
func kind_help(k: int) -> String:
	if camp:
		return kind_help9(k)
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
	if camp:
		return _end_round9(ans)
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
	var rank := {"": 0, "water": 1, "water_life": 1, "stone": 2, "done": 2, "thrive": 2, "people": 2, "finished": 2,
		"diag": 3, "standing": 4, "spent": 5, "repeat": 6}
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
	_act_seq += 1
	var t := str(action.get("type", "twist"))
	if t == "twist" or t == "wait":
		var turns := int(action.get("turns", 0))
		if turns != 0:
			var row: Array = action.get("row", [])
			apply_rotation(int(action["axis"]), int(action["layer"]), turns, row)
		var rr := end_round(ans)
		if camp:
			_note_recent9()
		return rr
	if camp and t == "gift":
		var rg := _play_gift9()
		_note_recent9()
		return rg
	if camp:
		var rt := _play_tool9(t, int(action["field"]), bool(action.get("bought", false)))
		_note_recent9()
		return rt
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
		if f.burning or ((v8 or camp) and f.id == bolt):
			out[f.id] = "fire"
		elif useful.has(f.id):
			out[f.id] = "useful"
		elif rain_to9(f) >= 0 if camp else ((rain_to8(f) >= 0) if v8 else rain_grows(f.kind)):
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
	if camp:
		return rain_ok9(f)
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
		if f.burning or ((v8 or camp) and f.id == bolt):
			out[f.id] = "fire"
			continue
		if camp:
			if rain_to9(f) < 0:
				continue
		elif v8:
			if rain_to8(f) < 0:
				continue
		elif not rain_grows(f.kind):
			continue
		var was: int = f.kind
		f.kind = rain_to9(f) if camp else (rain_to8(f) if v8 else int(RAIN_NEXT[was]))
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
	if camp:
		return _can_bonus9(kind, f)
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
	if camp:
		return str((goal9[0] as Dictionary)["type"]) if not goal9.is_empty() else ""
	return str(day.get("goal_type", ""))


func goal_target() -> int:
	if camp:
		return target9()
	return int(day.get("goal_target", 0))


func goal_kinds() -> Array:
	if camp:
		var ks: Array = []
		for st in sub_status9():
			if int((st as Dictionary)["kind"]) >= 0 and not ks.has(int((st as Dictionary)["kind"])):
				ks.append(int((st as Dictionary)["kind"]))
		return ks
	return day.get("goal_kinds", [])


func goal_green() -> bool:
	return bool(day.get("goal_green", false))


## Fortschritt zum Ziel: make = so oft ist ein Feld zu der Art gewachsen (Reihe, Seite, Kette, Regen, Wunsch;
## Fallen zählt nicht ab, der Fortschritt geht nie zurück), wishes = erfüllte Wünsche, faith = Glaube.
func goal_progress() -> int:
	if camp:
		return progress9()
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
	if camp:
		for i in goal9.size():
			if not _sub_met9(i):
				return false
		return not goal9.is_empty()
	if not is_day() or goal_target() <= 0:
		return false
	if goal_progress() < goal_target():
		return false
	if goal_green():
		return balance_green()
	return true


## Drehungen, die an diesem Tag noch bleiben (-1 = keine Grenze: Weiterbauen).
func twists_left() -> int:
	if day_free_build or camp:
		return -1
	return maxi(0, day_limit - used_twists())


## Weiterbauen nach dem Sieg beginnen: keine Grenze, kein Scheitern (auch Krieg an Tag 6 ist nur Krieg).
## Die Sterne bleiben die des Sieges (day_won, day_won_at bleiben).
func start_free_build() -> void:
	if not is_day() or not day_won or camp:
		return                    # Schöpfung (Build 12): kein Weiterbauen, die Welt läuft im nächsten Level weiter
	day_free_build = true
	no_war = false
	build_made0 = total_made()
	extra_level = 0
	if camp:
		build_new9 = 0
		while extra_level < extra_max() and _extra_met9(extra_level + 1):
			extra_level += 1
		return
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
	if camp:
		return build_new9
	return maxi(0, total_made() - build_made0)


## Gezählte Drehungen an einem Tag (ohne die vorgeführte Drehung von Tag 1).
func used_twists() -> int:
	return maxi(0, twists - gift_twists)


## Sterne für einen gewonnenen Tag: ★★★ bis stars[0] Drehungen, ★★ bis stars[1], sonst ★ (0 = nicht gewonnen).
## Die Gnade (mehr Drehungen) ändert die Grenzen nicht.
func stars() -> int:
	if not day_won:
		return 0
	if camp:
		return stars_for9(stars9, day_won_at)
	return Days.stars_for(day, day_won_at)


## Zusammenfassung für die Oberfläche (Ziel-Chip, Karten). {} im freien Spiel.
## {"day", "type", "kinds", "target", "progress", "met", "green" (Waage grün), "need_green", "twists", "limit",
##  "left", "won", "lost" ("", "twists", "war", "fire"), "won_at", "stars", "no_war"}
func day_status() -> Dictionary:
	if not is_day():
		return {}
	if camp:
		return level_status9()
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
	if v8 or camp:
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
const NEED_ICON = {"food": "hunger", "work": "work", "faith": "faith", "water": "water"}
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
	if camp:
		var r: Variant = thrive9.get(k)
		return ((r as Dictionary)["needs"] as Dictionary).keys() if r != null else []
	return needs8.get(k, [])


## Was hat ein Menschen-Feld, was fehlt ihm? {"met": [...], "missing": [...]} (Namen: food, work, faith, water).
func need_state(f: FieldData) -> Dictionary:
	if camp:
		return need_state9(f)
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
	if camp:
		return satt9(f.id)
	if not v8 or not people8(f.kind) or not needs8.has(f.kind):
		return false
	if f.burning or front.has(f.id):
		return false
	return (need_state(f)["missing"] as Array).is_empty()


func satt_ids() -> Array:
	if camp:
		return satt_ids9()
	var out: Array = []
	for f in fields:
		if satt(f):
			out.append(f.id)
	return out


## Zustand eines Felds für Anzeige und Felder-Ansicht: {"people", "satt", "met", "missing", "fed", "hungry", "grow_after",
## "shrink_after", "burning", "fresh", "front", "bolt", "wet"}.
func field_state8(f: FieldData) -> Dictionary:
	if camp:
		return field_state9(f)
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
	if camp:
		return extra_max9()
	if not v8:
		return 0
	return int(day.get("extras", 3 if day_no <= 3 else 1))


## Ziel der nächsten Extra-Aufgabe (Aufgabe + 1, + 2, + 3).
func extra_target() -> int:
	if camp:
		var sub: Dictionary = goal9[0] if not goal9.is_empty() else {"type": "make", "target": 0}
		return int(sub["target"]) + _extra_add9(sub, extra_level + 1)
	return goal_target() + extra_level + 1


## Bedürfnisse der Ziel-Art (Gedeihen-Tage), sonst [].
func goal_needs() -> Array:
	if camp:
		for st in sub_status9():
			if str((st as Dictionary)["type"]) == "satt" or str((st as Dictionary)["type"]) == "hold":
				return need_list(int((st as Dictionary)["kind"])).duplicate()
		return []
	if not v8 or goal_type() != "satt" or goal_kinds().is_empty():
		return []
	return need_list(int(goal_kinds()[0])).duplicate()


func goal_need_icons() -> Array:
	var out: Array = []
	for n in goal_needs():
		out.append(str(NEED_ICON9.get(str(n), "info")) if camp else str(NEED_ICON.get(str(n), "info")))
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
	if camp:
		return meteor_ok9(f)
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
	if camp:
		return preview9(axis, layer, turns, post)
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
	if camp:
		return value9()
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


## Die letzten Stellungen (Schöpfung, nur für die Tipp-Suche: festgefahren → keine Stellung wiederholen).
var recent9: Array = []


func _note_recent9() -> void:
	recent9.append(slot_board9())
	if recent9.size() > 12:
		recent9.remove_at(0)


## Sackgasse (ein Level kann man nicht verlieren): Ein satt-Ziel braucht n Felder einer Art K, aber auf dem Brett
## liegen weniger Felder, die je K werden können (K selbst oder eine Stufe darunter, die durch Gedeihen zu K wächst),
## und keine Regel des Levels (Reihe, Regen, Ausbreiten) kann neue solche Felder machen. Beispiel: Krieg hat in
## Level 28/29 so viele Städte bis zur Wiese zerstört, dass keine 3 Städte mehr gehen. Dann bietet das Spiel „Nochmal“.
func dead9() -> bool:
	if not camp or day_won or goal9.is_empty():
		return false
	for sub in goal9:
		var sd: Dictionary = sub
		var subs: Array = sd["subs"] if str(sd["type"]) == "hold" else [sd]
		for x in subs:
			var xd: Dictionary = x
			if str(xd["type"]) != "satt":
				continue
			var reach := {int(xd["kind"]): true}
			var grew := true
			while grew:
				grew = false
				for k in thrive9:
					var up: Variant = (thrive9[k] as Dictionary).get("up")
					if up != null and int(up) >= 0 and reach.has(int(up)) and not reach.has(int(k)):
						reach[int(k)] = true
						grew = true
			for k2 in rows9:
				if int(rows9[k2]) != int(k2) and reach.has(int(rows9[k2])):
					return false            # eine Reihe kann neue machen
			for it in rain9:
				if reach.has(int((it as Array)[2])):
					return false            # Regen kann neue machen
			for k3 in thrive9:
				var sp: Variant = (thrive9[k3] as Dictionary).get("spawn")
				if sp is Array and (sp as Array).size() >= 2 and reach.has(int((sp as Array)[1])):
					return false            # Ausbreiten kann neue machen
			var have := 0
			for f in fields:
				if reach.has(f.kind):
					have += 1
			if have < int(xd["target"]):
				return true
	return false


# --- Sicherheitsnetz (jedes Level bleibt lösbar): Reichweite, Nachschub, Geschenk ---------------------------------

## So viele Schritte ohne neuen Fortschritt: Der Charakter merkt, dass du festhängst, und bietet Hilfe an.
const STALL9 := 6
## Das Geschenk füllt höchstens so viele Felder nach, bis das Ziel wieder erreichbar ist (reach9).
const GIFT_TOPUP9 := 16
## Vulkan-Level: größte Lava-Gruppe einer übernommenen Welt (Campaign.carry, Campaign.ensure). Pool-Bretter: 5 … 12.
const CLUMP_CAP9 := 6
## Sticker-Arten (FieldData.sticker_type): Ecke 3, Kante 2, Mitte 1. Ecken berühren Kanten (und die Ecken desselben
## Steins), Kanten Ecken, Mitten (und die Kante desselben Steins), Mitten nur Kanten. Drehen ändert die Sticker-Art nie.
const TOUCH9 = {3: [2, 3], 2: [3, 1, 2], 1: [2]}


## Arten, aus denen in diesem Level ein Feld einer Art in ks wird. rows: auch über Reihen (sonst nur Gedeihen und Regen,
## die an jeder Sticker-Art gehen).
func _sources9(ks: Dictionary, rows: bool) -> Dictionary:
	var out := {}
	var grew := true
	while grew:
		grew = false
		if impact_pending9():
			# Einschlag (4.3): die Saurier werden sicher zu Asche (Erde), aus der die Wiesen wachsen
			var kill: Dictionary = impact9["kill"]
			for kk in kill:
				var to0 := int(kill[kk])
				if (ks.has(to0) or out.has(to0)) and not out.has(int(kk)) and not ks.has(int(kk)):
					out[int(kk)] = true
					grew = true
		for k in thrive9:
			var up: Variant = (thrive9[k] as Dictionary).get("up")
			if up != null and int(up) >= 0 and (ks.has(int(up)) or out.has(int(up))) and not out.has(int(k)) \
					and not ks.has(int(k)):
				out[int(k)] = true
				grew = true
		for it in rain9:
			var a: Array = it
			var to := int(a[2])
			if (ks.has(to) or out.has(to)) and not out.has(int(a[0])) and not ks.has(int(a[0])):
				out[int(a[0])] = true
				grew = true
		for k4 in thrive9:
			var sp: Variant = (thrive9[k4] as Dictionary).get("spawn")
			if sp is Array and (sp as Array).size() >= 2 and (ks.has(int((sp as Array)[1])) or out.has(int((sp as Array)[1]))) \
					and _spawner_ok9(int(k4)):
				for on in (sp as Array)[0]:
					if not out.has(int(on)) and not ks.has(int(on)):
						out[int(on)] = true      # Landgang: ein Feld dieser Art wird zur neuen Art
						grew = true
		if rows:
			for k2 in rows9:
				var nx := int(rows9[k2])
				if nx != int(k2) and (ks.has(nx) or out.has(nx)) and not out.has(int(k2)) and not ks.has(int(k2)):
					out[int(k2)] = true
					grew = true
	return out


## Landgang braucht einen, der an Land geht (Fische): da oder machbar (Reihe aus 3 da, Regen auf eine vorhandene Art).
func _spawner_ok9(k: int) -> bool:
	if count(k) > 0:
		return true
	for k2 in rows9:
		if int(rows9[k2]) == k and count(int(k2)) >= 3:
			return true
	for it in rain9:
		if int((it as Array)[2]) == k and count(int((it as Array)[0])) > 0 and (rain > 0 or rain_every > 0):
			return true
	return false


## Wie viele Felder der Art s noch durch Reihen weiterwachsen können (optimistisch). Eine Reihe ist Ecke-Kante-Ecke
## oder Kante-Mitte-Kante; zwei Ecken (Kanten) einer Reihe gehören zu zwei verschiedenen Steinen.
func _row_cap9(s: int) -> int:
	var corner_cubes := {}
	var edge_cubes := {}
	var e := 0
	var m := 0
	var n := 0
	for f in fields:
		if f.kind != s:
			continue
		n += 1
		var t := FieldData.sticker_type(f.p)
		if t == 3:
			corner_cubes[f.p] = true
		elif t == 2:
			edge_cubes[f.p] = true
			e += 1
		else:
			m += 1
	var ok := (corner_cubes.size() >= 2 and e >= 1) or (edge_cubes.size() >= 2 and m >= 1)
	return maxi(0, n - 2) if ok else 0


## Was einer Reihen-Quelle fehlt: die Sticker-Art, die als Nächstes hilft (3 Ecke, 2 Kante, 1 Mitte).
func _row_need_type9(s: int) -> int:
	var corner_cubes := {}
	var e := 0
	for f in fields:
		if f.kind == s:
			var t := FieldData.sticker_type(f.p)
			if t == 3:
				corner_cubes[f.p] = true
			elif t == 2:
				e += 1
	if e == 0:
		return 2
	if corner_cubes.size() < 2:
		return 3
	return 2


## Wie viele Felder noch zu einer Art in ks werden können (Gedeihen und Regen an jeder Sticker-Art, Reihen nach
## Sticker-Arten). {"supply", "free_kind" (eine Quelle ohne Reihe, -1), "row_kind" (eine Reihen-Quelle, -1)}.
func _supply9(ks: Dictionary) -> Dictionary:
	var free := _sources9(ks, false)
	var all := _sources9(ks, true)
	var sup := 0
	var row_kinds := {}
	for f in fields:
		if free.has(f.kind):
			sup += 1
		elif all.has(f.kind):
			row_kinds[f.kind] = true
	for s in row_kinds:
		sup += _row_cap9(int(s))
	var fk := -1
	for k in free:
		if fk < 0 or (thrive9.has(int(k)) and not thrive9.has(fk)):
			fk = int(k)
	var rk := -1
	for k2 in rows9:
		if ks.has(int(rows9[k2])) and int(rows9[k2]) != int(k2):
			rk = int(k2)
	if rk < 0:
		for k3 in all:
			if rows9.has(int(k3)):
				rk = int(k3)
	return {"supply": sup, "free_kind": fk, "row_kind": rk}


## Größte Gruppe, die Felder der Art k über ihre Sticker-Arten je bilden können: ohne Kante bleibt eine Ecke bei den
## Ecken ihres Steins (höchstens 3), eine Mitte allein.
func _group_bound9(k: int, extra: int) -> int:
	var n := 0
	var e := 0
	var cube := {}
	var best := 0
	for f in fields:
		if f.kind != k:
			continue
		n += 1
		var t := FieldData.sticker_type(f.p)
		if t == 2:
			e += 1
		elif t == 3:
			cube[f.p] = int(cube.get(f.p, 0)) + 1
			best = maxi(best, int(cube[f.p]))
		else:
			best = maxi(best, 1)
	if e > 0 or extra > 0:
		return n + extra
	return best


## Sticker-Arten anderer Steine, die eine Sticker-Art je berühren kann (Ecke – Kante – Mitte). Sticker desselben Steins
## berühren sich immer (feste Partner) und zählen nur als sie selbst.
const REACH9 = {3: [2], 2: [3, 1], 1: [2]}


## Kann Feld h je neben Feld fid liegen? (anderer Stein: nach Sticker-Art; derselbe Stein: immer Nachbarn)
func _can_touch9(fid: int, h: int) -> bool:
	if h == fid:
		return false
	var a: FieldData = fields[fid]
	var b: FieldData = fields[h]
	if a.p == b.p:
		return true
	return (REACH9[FieldData.sticker_type(a.p)] as Array).has(FieldData.sticker_type(b.p))


## Kann ein Feld (Sticker-Art t; fid ≥ 0: genau dieses Feld) die Bedürfnisse von Art k je erfüllt bekommen? Quellen,
## die es gibt (an einer Sticker-Art, die t berührt) oder die das Level noch machen kann.
func _needs_ok9(k: int, t: int, have_kind: Dictionary, fid: int = -1) -> bool:
	var r: Variant = thrive9.get(k)
	if r == null:
		return true
	for need in ((r as Dictionary)["needs"] as Dictionary):
		var ns := str(need)
		if ns == "sun":
			continue
		if ns == "wet":
			if not have_kind.has(FieldData.WATER):
				return false
			continue
		var src: Array = SOURCES9.get(ns, [])
		var ks := {}
		for x in src:
			ks[int(x)] = true
		# eine Quelle (oder ein Feld, das an Ort und Stelle zur Quelle wird: Gedeihen, Regen) auf einer Sticker-Art,
		# die t berührt; Reihen können eine neue Quelle überall hinlegen (optimistisch). GDPD_ERDGESCHICHTE.md 6:
		# eine Hütte auf einer Mitte, an die nie ein Wald kommt, wird nie ein Dorf (🔨 nach Sticker-Art).
		var free := _sources9(ks, false)
		var found := false
		for f in fields:
			if not (ks.has(f.kind) or free.has(f.kind)):
				continue
			if (fid >= 0 and _can_touch9(fid, f.id)) or (fid < 0 and (TOUCH9[t] as Array).has(FieldData.sticker_type(f.p))):
				found = true
				break
		if not found:
			for s2 in _sources9(ks, true):
				if not free.has(s2) and rows9.has(int(s2)) and _row_cap9(int(s2)) > 0:
					found = true
					break
		if not found:
			return false
	return true


## Ist das Ziel von hier aus noch erreichbar? Eine schnelle Prüfung ohne Suche (Mikrosekunden): genug Material je
## Teilziel, nach Sticker-Arten (Reihen brauchen eine Kante, Ecken und Mitten berühren nur Kanten). Optimistisch:
## „ok“ heißt nicht sicher lösbar (dafür gibt es das Stocken, STALL9), „nicht ok“ heißt sicher festgefahren.
## {"ok", "sub" (Teilziel), "type", "kind" (was fehlt), "stype" (Sticker-Art, 0 = egal), "near" (neben dieser Art,
## -1), "why": "few" | "rows" | "group" | "needs"}.
func reach9() -> Dictionary:
	var okd := {"ok": true}
	if not camp or day_won or goal9.is_empty():
		return okd
	var have_kind := {}
	for f in fields:
		have_kind[f.kind] = true
	for i in goal9.size():
		var sd: Dictionary = goal9[i]
		var subs: Array = sd["subs"] if str(sd["type"]) == "hold" else [sd]
		for x in subs:
			var xd: Dictionary = x
			var t := str(xd["type"])
			var tgt := int(xd["target"])
			var cur := sub_progress9(xd)
			if cur >= tgt:
				continue
			var ks := {}
			for k in xd["kinds"]:
				ks[int(k)] = true
			if t == "make":
				var su := _supply9(ks)
				if int(su["supply"]) < tgt - cur:
					var fk := int(su["free_kind"])
					var rk := int(su["row_kind"])
					if fk >= 0:
						return {"ok": false, "sub": i, "type": t, "kind": fk, "stype": 0, "near": -1, "why": "few",
							"goal": int(xd["kind"])}
					if rk >= 0:
						return {"ok": false, "sub": i, "type": t, "kind": rk, "stype": _row_need_type9(rk), "near": -1,
							"why": "rows", "goal": int(xd["kind"])}
					return {"ok": false, "sub": i, "type": t, "kind": int(xd["kind"]), "stype": 0, "near": -1,
						"why": "few", "goal": int(xd["kind"])}
			elif t == "group":
				var k0 := int(xd["kind"])
				var su2 := _supply9(ks)
				var n := 0
				for f in fields:
					if f.kind == k0:
						n += 1
				var rk2 := int(su2["row_kind"])
				if n + int(su2["supply"]) < tgt or _group_bound9(k0, int(su2["supply"])) < tgt:
					var kind_add := rk2 if rk2 >= 0 else k0
					return {"ok": false, "sub": i, "type": t, "kind": kind_add,
						"stype": _row_need_type9(rk2) if rk2 >= 0 else 2, "near": -1, "why": "group", "goal": k0}
			elif t == "satt":
				var k1 := int(xd["kind"])
				var reach := {k1: true}
				for k5 in _sources9(ks, true):
					reach[int(k5)] = true
				var producible := false
				for k2 in rows9:
					if int(rows9[k2]) != int(k2) and reach.has(int(rows9[k2])):
						producible = true
				for it in rain9:
					if reach.has(int((it as Array)[2])):
						producible = true
				for k3 in thrive9:
					var sp: Variant = (thrive9[k3] as Dictionary).get("spawn")
					if sp is Array and (sp as Array).size() >= 2 and reach.has(int((sp as Array)[1])):
						producible = true
				var have := 0
				var good := 0
				var bad_f := -1
				for f in fields:
					if not reach.has(f.kind):
						continue
					have += 1
					# eine Vorstufe (Hütte für ein Dorf-Ziel) zählt nur, wenn sie die Bedürfnisse der Ziel-Art je bekommt
					if (f.kind == k1 and satt9(f.id)) or _needs_ok9(k1, FieldData.sticker_type(f.p), have_kind, f.id):
						good += 1
					elif bad_f < 0:
						bad_f = f.id
				if not producible and have < tgt:
					return {"ok": false, "sub": i, "type": t, "kind": k1, "stype": 0, "near": -1, "why": "few", "goal": k1}
				if good < tgt and not producible:
					return {"ok": false, "sub": i, "type": t, "kind": _missing_src9(k1, bad_f), "stype": 0,
						"near": bad_f, "why": "needs", "goal": k1}
	return okd


## Eine Quell-Art, die einem Feld der Art k fehlt (für den Nachschub neben diesem Feld).
func _missing_src9(k: int, fid: int) -> int:
	var r: Variant = thrive9.get(k)
	if r == null:
		return k
	var nd: Dictionary = (r as Dictionary)["needs"]
	for need in nd:
		var ns := str(need)
		if ns == "sun":
			continue
		if fid >= 0:
			# fehlt es diesem Feld als Art k? (eine Hütte für ein Dorf-Ziel: 🍞 versiegelt, 🔨 fehlt)
			var have := maxi(supply9(fid, ns), int((fields[fid] as FieldData).best.get(ns, 0)))
			if have >= int(nd[need]):
				continue
		if ns == "wet":
			return FieldData.WATER
		var sk := src_kind9(ns)
		if sk >= 0:
			return sk
	return k


## Woran es hängt (für den Charakter): "" | "dead" (das Ziel geht so nicht mehr) | "stall" (STALL9 Schritte ohne
## neuen Fortschritt). Nie im Weiterbauen und nach dem Sieg.
func stuck9() -> String:
	if not camp or day_won or day_free_build or goal9.is_empty():
		return ""
	if not bool(reach9()["ok"]) or dead9():
		return "dead"
	if steps9() - gain_at9 >= STALL9:
		return "stall"
	return ""


## Arten, die ein Level braucht (Ziel, Quellen, Bedürfnisse): Nachschub und Geschenk überschreiben sie nicht.
func _kept_kinds9() -> Dictionary:
	var keep := {}
	for sd in goal9:
		var subs: Array = (sd as Dictionary)["subs"] if str((sd as Dictionary)["type"]) == "hold" else [sd]
		for x in subs:
			for k in (x as Dictionary)["kinds"]:
				keep[int(k)] = true
	for k2 in _sources9(keep.duplicate(), true):
		keep[int(k2)] = true
	for k3 in thrive9:
		keep[int(k3)] = true
		for need in (((thrive9[k3] as Dictionary)["needs"]) as Dictionary):
			for s in SOURCES9.get(str(need), []):
				keep[int(s)] = true
	for k4 in rows9:
		keep[int(k4)] = true
	return keep


## Ein Feld, das Nachschub aufnehmen darf: Sticker-Art stype (0 = egal), neben near (-1 = egal), nicht neben avoid
## (-1 = egal); bevorzugt Arten, die das Level nicht braucht, dann die häufigste. -1 = keins.
func _filler9(stype: int, near: int, avoid: int, kind_to: int) -> int:
	var keep := _kept_kinds9()
	var cnt := {}
	for f in fields:
		cnt[f.kind] = int(cnt.get(f.kind, 0)) + 1
	var best := -1
	var best_v := -INF
	for f in fields:
		if f.kind == kind_to or goal_kinds9.has(f.kind) or f.burning or satt9(f.id):
			continue
		if stype > 0 and FieldData.sticker_type(f.p) != stype:
			continue
		if near >= 0 and not nb9(near).has(f.id):
			continue
		if avoid >= 0 and _next_to9(f.id, avoid):
			continue
		if rows9.has(kind_to) and _row_closes9(f, kind_to):
			continue                       # sonst wächst die Reihe gleich weiter (späte Runde) und der Nachschub ist weg
		var v := float(cnt[f.kind])
		if not keep.has(f.kind):
			v += 100.0
		if f.kind == FieldData.WATER:
			v += 20.0 if int(cnt[f.kind]) > 12 else -50.0
		for sd in goal9:
			var subs: Array = (sd as Dictionary)["subs"] if str((sd as Dictionary)["type"]) == "hold" else [sd]
			for x in subs:
				for k in (x as Dictionary)["kinds"]:
					if _next_to9(f.id, int(k)) and str((x as Dictionary)["type"]) == "satt":
						v -= 30.0          # Nachbarn eines satt-Ziels bleiben, wie sie sind (sie versorgen es)
		v -= float(f.id) * 0.001
		if v > best_v:
			best_v = v
			best = f.id
	return best


## Schlösse Feld f als Art k eine gerade Reihe, die noch wachsen kann? (Nur gedacht: die Art wird zurückgesetzt.)
func _row_closes9(f: FieldData, k: int) -> bool:
	var old := f.kind
	f.kind = k
	var hit := false
	for ln in lines({f.id: true}):
		if (ln[0] as FieldData).kind == k and not spent.has(line_key(ln)):
			hit = true
			break
	f.kind = old
	return hit


## Nachschub (Neuer Morgen, Geschenk): höchstens max_n Felder bekommen das, was dem Ziel fehlt, bis reach9 wieder
## passt. Ändert diesen Stand. [[Feld, Art], …] (leer, wenn nichts fehlt oder nichts geht).
func top_up9(max_n: int) -> Array:
	var out: Array = []
	for it in max_n:
		var r := reach9()
		if bool(r["ok"]):
			break
		var k := int(r["kind"])
		var avoid := FieldData.LAVA if k == FieldData.LAVA and bool(sys9.get("volcano", false)) else -1
		var fid := _filler9(int(r["stype"]), int(r["near"]), avoid, k)
		if fid < 0 and avoid >= 0:
			fid = _filler9(int(r["stype"]), int(r["near"]), -1, k)
		if fid < 0:
			fid = _filler9(0, int(r["near"]), -1, k)
		if fid < 0:
			break
		_setk9(fields[fid], k)
		_unspend9(fid)
		(fields[fid] as FieldData).mk = false
		out.append([fid, k])
	return out


## Das Geschenk des Charakters: ein Wunder, das sofort +1 Fortschritt bringt (make: ein Feld wird zur Ziel-Art und
## zählt; group: die größte Gruppe wächst um ein Feld; satt: ein Feld bekommt, was ihm fehlt; Ruhe: die Runde
## zählt), und danach Nachschub, bis das Ziel wieder erreichbar ist. {"changes": [[Feld, Art, zählt]], "held": i}
## oder {} (nichts zu schenken).
func gift_plan9() -> Dictionary:
	if not camp or day_won or day_free_build or goal9.is_empty():
		return {}
	for i in goal9.size():
		if _sub_met9(i):
			continue
		var sd: Dictionary = goal9[i]
		var main: Array = []
		var t := str(sd["type"])
		var x: Dictionary = sd
		if t == "hold":
			x = {}
			for s in sd["subs"]:
				if sub_progress9(s) < int((s as Dictionary)["target"]):
					x = s
					break
			if x.is_empty():
				return {"changes": [], "held": i}
			t = str(x["type"])
		if t == "make":
			var fid := _gift_make9(x)
			if fid >= 0:
				main = [[fid, int(x["kind"]), true]]
		elif t == "group":
			var fid2 := _gift_group9(int(x["kind"]))
			if fid2 >= 0:
				main = [[fid2, int(x["kind"]), true]]
		elif t == "satt":
			main = _gift_satt9(x)
		if main.is_empty():
			continue
		var c := clone()
		for ch in main:
			c._setk9(c.fields[int(ch[0])], int(ch[1]))
		for ch2 in c.top_up9(GIFT_TOPUP9):
			main.append([int(ch2[0]), int(ch2[1]), false])
		return {"changes": main, "held": -1}
	return {}


func _gift_make9(x: Dictionary) -> int:
	var ks := {}
	for k in x["kinds"]:
		ks[int(k)] = true
	var src := _sources9(ks, true)
	var best := -1
	var best_v := -INF
	for f in fields:
		if ks.has(f.kind) or f.burning:
			continue
		var v := 0.0
		if src.has(f.kind):
			v += 50.0
			if f.kind == FieldData.LAVA:
				v += float(gsize9(f.id))          # Lava aus dem größten Klumpen: beruhigt auch den Vulkan
			elif rows9.has(f.kind) and _row_cap9(f.kind) <= 0:
				v += 20.0                         # eine Quelle, die keine Reihe mehr bilden kann
		if satt9(f.id):
			v -= 40.0
		if f.kind == FieldData.WATER:
			v -= 5.0
		v -= float(f.id) * 0.001
		if v > best_v:
			best_v = v
			best = f.id
	return best


func _gift_group9(k: int) -> int:
	var big := -1
	var bs := 0
	for f in fields:
		if f.kind == k and gsize9(f.id) > bs:
			bs = gsize9(f.id)
			big = f.id
	var best := -1
	var best_v := -INF
	var members := {}
	if big >= 0:
		for m in members9(big):
			members[int(m)] = true
	for f in fields:
		if f.kind == k or f.burning:
			continue
		var v := 0.0
		if big >= 0:
			var touch := false
			for g in nb9(f.id):
				if members.has(int(g)):
					touch = true
			if not touch:
				continue
		if FieldData.sticker_type(f.p) == 2:
			v += 10.0                             # eine Kante verbindet weiter
		for g2 in nb9(f.id):
			if (fields[int(g2)] as FieldData).kind == k and not members.has(int(g2)):
				v += 5.0                          # verbindet zwei Gruppen
		if satt9(f.id):
			v -= 40.0
		v -= float(f.id) * 0.001
		if v > best_v:
			best_v = v
			best = f.id
	return best


## satt: ein Feld der Ziel-Art bekommt passende Nachbarn; gibt es keins, das nicht satt ist, wird ein Feld zur Ziel-Art
## (bevorzugt neben vorhandenen Quellen) und bekommt, was ihm fehlt. Geprüft mit den echten Regeln. [] = nichts.
func _gift_satt9(x: Dictionary) -> Array:
	var k := int(x["kind"])
	var base := sub_progress9(x)
	var p0 := _subs_sum9()
	var cands: Array = []
	for f in fields:
		if f.kind == k and not satt9(f.id):
			cands.append([f.id, false])
	var others: Array = []
	for f in fields:
		if f.kind == k or f.burning or satt9(f.id) or goal_kinds9.has(f.kind):
			continue
		others.append([_need_hits9(f.id, k), f.id])
	others.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for o in others.slice(0, 16):
		cands.append([int((o as Array)[1]), true])
	for cd in cands:
		var fid := int((cd as Array)[0])
		var c := clone()
		var plan: Array = []
		if bool((cd as Array)[1]):
			c._setk9(c.fields[fid], k)
			plan.append([fid, k, true])
		for step in 4:
			var miss: Array = c.need_state9(c.fields[fid])["missing"]
			if miss.is_empty():
				break
			var to := -1
			for m in miss:
				var ns := str(m)
				if ns == "sun":
					to = -2
					break
				if to == -1:
					to = c.src_kind9(ns)
			if to < 0:
				break
			var g := c._filler9(0, fid, -1, to)
			if g < 0:
				break
			c._setk9(c.fields[g], to)
			plan.append([g, to, false])
		if not plan.is_empty() and c.sub_progress9(x) > base and c._subs_sum9() > p0:
			return plan
	return []


## Summe über alle Teilziele (auch die eines Ruhe-Ziels) von min(Fortschritt, Ziel).
func _subs_sum9() -> int:
	var t := 0
	for sd in goal9:
		var subs: Array = (sd as Dictionary)["subs"] if str((sd as Dictionary)["type"]) == "hold" else [sd]
		for x in subs:
			t += mini(sub_progress9(x), int((x as Dictionary)["target"]))
	return t


## Wie gut ein Feld als neues Feld der Art k läge: Nachbarn, die seine Bedürfnisse schon geben (Sonne: die Sonnenseite).
func _need_hits9(fid: int, k: int) -> float:
	var r: Variant = thrive9.get(k)
	if r == null:
		return 0.0
	var v := 0.0
	for need in ((r as Dictionary)["needs"] as Dictionary):
		var ns := str(need)
		if ns == "sun":
			v += 3.0 if face_index(fields[fid]) == SUN_FACE else -50.0
		elif ns == "wet":
			v += float(supply9(fid, "wet"))
		else:
			v += 2.0 * float(supply9(fid, ns))
	return v - float(fid) * 0.001


## Das Geschenk spielen (Game.take_gift): kein Schritt, kostet nichts. Ergebnis wie ein Werkzeug (die Welt spielt es
## wie einen Regen ab).
func _play_gift9() -> Dictionary:
	var plan := gift_plan9()
	if not engine9_mode:
		_remember_before()
	_open_turn()
	trace9 = []
	var ev: Array = []
	var p0 := sub_values9()
	var ids: Array = []
	var stages := {}
	for ch in plan.get("changes", []):
		var a: Array = ch
		var f: FieldData = fields[int(a[0])]
		var from := f.kind
		if bool(a[2]):
			_rise9(f, int(a[1]))
		else:
			_setk9(f, int(a[1]))
			f.mk = false
		_unspend9(f.id)
		f.burning = false
		if f.id == volc:
			volc = -1
		if f.id == glac9:
			glac9 = -1
		if f.id == bolt:
			bolt = -1
		ids.append(f.id)
		stages[f.id] = f.kind
		_ev9(ev, "gift", {"type": "rescue_gift", "field": f.id, "from": from, "kind": f.kind, "counts": bool(a[2])})
	var hi := int(plan.get("held", -1))
	if hi >= 0:
		held9[hi] = int(held9[hi]) + 1
		# Ruhe: alle Warnungen erlöschen (kein Blitz, kein Ausbruch, kein Rudel, kein Smog, keine Flut, keine Front)
		bolt = -1
		volc = -1
		glac9 = -1
		pack_warn9 = {}
		smog_warn9 = {}
		flood_warn = {}
		front = {}
		war_on = false
		ev.append({"type": "hold", "rounds": int(held9[hi]), "target": int((goal9[hi] as Dictionary)["target"]), "ok": true})
	st9["gifts"] = int(st9.get("gifts", 0)) + 1
	if not engine9_mode and not ids.is_empty():
		# Build 12: eine Reihe, die das Geschenk schließt, wächst sofort (wie beim Regen)
		for i in ids:
			moved[int(i)] = true
		_resolve_merges9(ev)
		moved = {}
	_seal_step9(ev)
	_check_goal9(ev, false)
	_tail9(ev, p0)
	gain_at9 = steps9()               # geholfen: das Stocken zählt neu
	if hi >= 0 and not day_won:
		var all_met := true
		for i in goal9.size():
			if not _sub_met9(i):
				all_met = false
		if all_met:
			day_won = true
			day_won_at = steps9()
			_tail9(ev, sub_values9())
	var res := _close9(ev, {"rain": 0, "bolt": 0, "monsoon": 0}, 0, 0)
	turn -= 1
	res["bonus"] = {"kind": "gift", "field": int(ids[0]) if not ids.is_empty() else -1, "fields": ids, "stages": stages}
	res["gift"] = true
	return res


## Was der Charakter sagt, wenn er hilft (kurz, du-Form).
func rescue_line9(why: String) -> String:
	if why == "dead":
		var r := reach9()
		if not bool(r["ok"]) and int(r.get("goal", -1)) == FieldData.FELS and thrive9.has(FieldData.LAVA):
			return str(Campaign.TEXT["rescue_rows"]) if str(r["why"]) == "rows" else str(Campaign.TEXT["rescue_few"])
		return str(Campaign.TEXT["rescue_dead"])
	return str(Campaign.TEXT["rescue_stall"])


## Tipp-Suche: lohnt Regen auf Feld fid? (ein Nachbar, der etwas braucht und noch nicht satt ist, oder ein Brand)
func _rain_useful9(fid: int) -> bool:
	var f: FieldData = fields[fid]
	if f.burning or fid == bolt or thrive9.has(f.kind):
		return true
	for g in nb9(fid):
		var gf: FieldData = fields[int(g)]
		if thrive9.has(gf.kind) and not satt9(gf.id):
			return true
	return false


## Die Tipp-Suche eines Tages in kleinen Schritten (für die Oberfläche: auf mehrere Bilder verteilt, Game.search_hint).
## null, wenn der Tag nicht nach den neuen Regeln läuft (dann am Stück: best_day_action). Die Suche läuft nie auf
## einem zweiten Thread: Godot 4.3 liest die const-Tabellen (MOVES, FieldData …) nicht threadsicher.
func day_search(twist_only: bool = false) -> DaySearch8:
	if not (v8 or camp) or not is_day() or is_over():
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
	var _width := 6
	var _half2 := true             # im Blick voraus auch halbe Drehungen (Schöpfung: nein, spart ein Drittel)
	var sims := 0                  # Simulationen bisher (Test: die Suche bleibt begrenzt)
	var _stall := false            # Schöpfung: seit 3 Schritten kein Fortschritt
	var _spread := false           # Blick voraus auf die besten 3 und gestreute weitere Drehungen
	const TOOLS_MAX := 10

	func _init(state: GameState, twist_only: bool) -> void:
		gs = state
		_p0 = gs.goal_progress()
		_phase = 1 if twist_only else 0
		if twist_only:
			return
		_base = gs.value8()
		if gs.camp:
			# Schöpfung: eine Simulation kostet hier 1–3 ms – Breite begrenzt, damit der Tipp unter ~0,3 s bleibt
			_width = 4
			_half2 = false
			if not gs.day_free_build and gs.twists - gs.gain_at9 >= 3:
				_stall = true
			if not gs.day_free_build and gs.twists - gs.gain_at9 >= 4:
				_width = 6           # festgefahren: voraus schauen, gestreut (nie im Weiterbauen)
				_spread = true
		if gs.rain > 0:
			var near: Array = []
			var far: Array = []
			for f in gs.fields:
				if gs.rain_ok(f):
					var a := {"type": "rain", "field": f.id}
					if gs.camp and not gs._rain_useful9(f.id):
						far.append(a)
					else:
						near.append(a)
			_tools = near.slice(0, TOOLS_MAX) if gs.camp else near
			for a2 in far:
				if _tools.size() >= TOOLS_MAX:
					break
				_tools.append(a2)
		if gs.camp:
			if gs.meteors > 0:
				for f in gs.fields:
					if GameState.METEOR_T9.has(f.kind):
						_tools.append({"type": "strike", "field": f.id})
		elif bool(gs.day.get("meteor", false)) and gs.faith >= GameState.METEOR_COST:
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
				sims += 1
				var v := st.value8()
				if v > _best_tv:
					_best_tv = v
					_best_t = {"type": str(a["type"]), "field": int(a["field"]), "value": v, "progress": st.goal_progress()}
				return
			var need := 6.0 if (gs.rain + gs.meteors) <= 1 else 3.0
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
				sims += 1
				var v3 := st3.value8()
				if _stall and gs.recent9.has(st3.slot_board9()):
					v3 -= 1000.0         # festgefahren: nie zurück in eine Stellung der letzten Runden (kein Hin und Her)
				_scored.append([v3, m, st3])
				return
			_scored.sort_custom(func(x, y): return float(x[0]) > float(y[0]))
			if _spread and _scored.size() > _width:
				# festgefahren: die besten 3 und dazu Drehungen aus dem ganzen Feld (der Ausweg sieht oft erst schlecht aus)
				var pickd: Array = _scored.slice(0, 3)
				var step := maxi(1, (_scored.size() - 3) / maxi(1, _width - 3))
				var ri := 3 + step / 2
				while pickd.size() < _width and ri < _scored.size():
					pickd.append(_scored[ri])
					ri += step
				_scored = pickd
			_pick = _scored[0]
			var first: GameState = _pick[2]
			if first.day_won and not first.day_free_build:
				_finish()
				return
			_phase = 2
			return
		if _ci >= mini(_width, _scored.size()):
			_finish()
			return
		var c: Array = _scored[_ci]
		var s1: GameState = c[2]
		var v1 := float(c[0])
		if s1.is_over():
			_consider(c, v1 if s1.day_won else v1 - 1e5)
			return
		if not _half2:
			while _m2 < GameState.MOVES.size() and absi(int((GameState.MOVES[_m2] as Array)[2])) == 2:
				_m2 += 1
		if _m2 < GameState.MOVES.size():
			var m2: Array = GameState.MOVES[_m2]
			_m2 += 1
			var s2: GameState = s1.simulate({"type": "twist", "axis": int(m2[0]), "layer": int(m2[1]), "turns": int(m2[2])})["state"]
			sims += 1
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


# =============================================================================
# Die Schöpfung (docs/GDPD_SCHOEPFUNG.md v2): die Kampagne mit 30 Leveln in 7 Akten.
# Port von engine9.py (gegen das Modell geprüft: tests/test_rules.gd test_xcheck9, tests/xcheck9.gd).
# Drei Verben: Erschaffen (3 gleiche in einer neuen Reihe, once), Gedeihen (Bedürfnisse aus den Nachbarn, auch über
# die Würfelkante; einmal versorgt bleibt versorgt), Zusammenwachsen (gleiche Arten, die sich berühren, sind eine
# Gruppe; sie gibt jedem Nachbarn die Stärke min(Größe, 3)). Gefahren nur als Folge, je eine Runde vorher gewarnt.
# Kein Schritt-Limit, kein Verlieren; Sterne nach Schritten.
# Ablauf einer Runde (3.8): 1 Reihen  2 Schritte +1, Rauch −1  3 Feuer  4 Blitz  5 Vulkan  6 Smog  7 Flut  8 Krieg
#   9 Rudel  10 Gedeihen (erst versiegeln)  11 Glaube → Meteor  12 Regen  13 Ziel (Ruhe, Gnade)
# Werkzeuge (Regen, Meteor) sind kein Schritt: Reihen des Werkzeugs, dann das Ziel.
# Ereignisse (Vertrag 11): Dictionaries mit "type" (alte Namen, wo es sie gibt: merge, burn, polluted);
# trace9 hält dieselben Ereignisse mit den Namen des Modells (grow, burnt, smog …) für den Abgleich.
# =============================================================================

const B9 = {"G": 2, "H": 4, "GRACE": 3, "CAP": 3, "VOLC_AT": 5, "ERUPT_MAX": 3, "DRY_AT": 3, "PACK_AT": 3,
	"FLOOD_AT": 5, "FRESH": 2, "CRATER_REST": 2, "RAIN_MAX": 3, "MERCY_EVERY": 3, "METEOR_FAITH": 12, "FAITH_STEP": 3,
	"MAX_CASCADES": 6}
## Menschen-Stufe (Glaube, Krieg, „wächst nur, wenn die nächste Stufe satt wäre“).
const LEVEL9 = {FieldData.HUT: 0, FieldData.VILLAGE: 1, FieldData.TOWN: 2}
const PEOPLE9 = [FieldData.HUT, FieldData.VILLAGE, FieldData.TOWN]
## Die Sonnenseite (☀): Seite 0 (+y, oben in der Start-Ansicht).
const SUN_FACE := 0
const WAR_DOWN9 = {FieldData.TOWN: FieldData.VILLAGE, FieldData.VILLAGE: FieldData.HUT, FieldData.HUT: FieldData.MEADOW}
const SMOG_DOWN9 = {FieldData.ANIMALS: FieldData.FOREST, FieldData.BIRDS: FieldData.FOREST, FieldData.FOREST: FieldData.MEADOW,
	FieldData.FERN: FieldData.MOSS, FieldData.MOSS: FieldData.EMPTY, FieldData.MEADOW: FieldData.EMPTY,
	FieldData.SEED: FieldData.MEADOW, FieldData.FIELD: FieldData.MEADOW, FieldData.PRED: FieldData.FOREST}
## Smog trifft zuerst das wertvollste Natur-Feld neben der Industrie.
const SMOG_T9 = {FieldData.ANIMALS: 4, FieldData.BIRDS: 4, FieldData.PRED: 4, FieldData.FOREST: 3, FieldData.FERN: 3,
	FieldData.FIELD: 2, FieldData.SEED: 2, FieldData.MEADOW: 1, FieldData.MOSS: 1}
const LOW9 = [FieldData.EMPTY, FieldData.MEADOW, FieldData.FIELD, FieldData.SEED, FieldData.HUT, FieldData.MOSS]
## Worüber Lava beim Ausbruch fließt.
const ERUPTS9 = [FieldData.STONE, FieldData.EMPTY, FieldData.MOSS, FieldData.FERN, FieldData.FOREST, FieldData.MEADOW]
const CITY_W9 = {FieldData.VILLAGE: 1, FieldData.TOWN: 2, FieldData.INDUSTRY: 2}
## Schaden (Ruhe-Ziel „hold“: eine Runde ohne diese Ereignisse; Warnungen sind erlaubt). Namen wie im Modell.
const DAMAGE9 = ["starve", "burnt", "erupt", "war_hit", "flood", "smog", "pack_hunt", "goal_loss", "bolt", "ignite",
	"freeze"]
## Bedürfnis → Arten, die es geben (3.4). sun und wet sind besonders (Sonnenseite, Zahl der Wasser-Nachbarn).
## Erdgeschichte (GDPD_ERDGESCHICHTE.md 3.1): 🌲 Holz, 🐞 Insekten, ❄ Kälte; 🔥 auch von der Feuerstelle, 🌾 vom Farn,
## 🍖 vom Saurier, 🦶 vom Moos (kein altes Level hat diese Nachbarn: alle alten Level laufen gleich).
const SOURCES9 = {"heat": [FieldData.LAVA, FieldData.CAMP], "mineral": [FieldData.STONE],
	"spark": [FieldData.LAVA, FieldData.CELLS], "algae": [FieldData.ALGAE], "fish": [FieldData.FISH],
	"shore": [FieldData.MEADOW, FieldData.MOSS], "plants": [FieldData.MEADOW, FieldData.FOREST, FieldData.FERN],
	"prey": [FieldData.ANIMALS, FieldData.SAURO], "food": [FieldData.ANIMALS, FieldData.FIELD],
	"work": [FieldData.FOREST, FieldData.STONE, FieldData.INDUSTRY], "faith": [FieldData.CHURCH],
	"wood": [FieldData.FOREST], "bugs": [FieldData.INSECTS], "cold": [FieldData.ICE]}
## Bedürfnis → Symbol (icons/<name>.svg; fehlt eins, nimmt die Oberfläche ein Ersatz-Symbol).
const NEED_ICON9 = {"heat": "heat", "mineral": "mineral", "spark": "spark", "algae": "algae", "fish": "fishneed",
	"shore": "shore", "plants": "plants", "prey": "prey", "food": "hunger", "work": "work", "faith": "faith",
	"sun": "sun", "wet": "rain", "wood": "wood", "bugs": "bugs", "cold": "cold"}
const NEED_NAME9 = {"heat": "Wärme", "mineral": "Fels", "spark": "Leben", "algae": "Algen", "fish": "Fische",
	"shore": "Ufer", "plants": "Pflanzen", "prey": "Beute", "food": "Nahrung", "work": "Arbeit", "faith": "Glaube",
	"sun": "Sonne", "wet": "Wasser", "wood": "Holz", "bugs": "Insekten", "cold": "Kälte"}
## Gekaufte Wunder (GDPD_PUNKTE_LADEN.md 1, 4): zählen 2 Schritte, je Art höchstens eins je Level.
const MIRACLE_STEPS := 2
## Meteor-Ziele, die der Tipp prüft (wie bot9.METEOR_T).
const METEOR_T9 = [FieldData.CHURCH, FieldData.INDUSTRY, FieldData.PRED, FieldData.LAVA, FieldData.TOWN,
	FieldData.VILLAGE, FieldData.STONE, FieldData.REX, FieldData.ICE]
## Gletscher (GDPD_ERDGESCHICHTE.md 4.2, die Vulkan-Regel mit anderen Zahlen): ab so großer Eis-Gruppe gewarnt, so viele
## Nachbarn frieren ein, so viele Runden ruht die Gruppe danach. Was einfriert, wenn das Level nichts anderes sagt.
const B10 = {"GLAC_AT": 4, "GLAC_MAX": 2, "GLAC_REST": 2}
const FREEZE9 = [FieldData.WATER, FieldData.MEADOW, FieldData.FOREST, FieldData.ANIMALS, FieldData.EMPTY, FieldData.MOSS,
	FieldData.FERN, FieldData.APES, FieldData.EARLY]
## Die alte Rudel-Regel als Jagd (Level „Rudel“ der Schöpfung): Raubtiere ≥ 3 jagen Tiere, die zur Wiese werden.
const PACK_HUNT9 = [FieldData.PRED, [FieldData.ANIMALS], FieldData.MEADOW, 3, 0]
const _LW9 = {0: 8.0, 1: 6.0, 2: 2.5, 3: 1.0, 4: 0.4}

## Genau wie das Python-Modell engine9 (für den Abgleich tests/xcheck9): ohne die Regeln aus Build 12 (späte Runde,
## Geschenk und Meteor lösen Reihen auf, Welt-Ereignisse geben gewachsene Reihen frei, nur Gewachsenes ist
## „zurückgedreht“). Im Spiel immer false.
static var engine9_mode := false
var camp := false               # dieser Versuch ist ein Level der Schöpfung (setup_level)
var level_no := 0               # 1 … 30 (0 = kein Level)
var rows9: Dictionary = {}      # Art → nächste Art einer Reihe (nur Arten, die heute Reihen bilden)
var consume9: Dictionary = {}   # Art → was die 2 anderen Felder einer Reihe werden (3 Tiere → 1 Hütte + 2 Wiesen)
var thrive9: Dictionary = {}    # Art → {"needs": {Bedürfnis: Menge}, "up", "down", "spawn": [] | [on, into, after], "G"}
var rain9: Array = []           # [[Art, Bedingung, Ergebnis]] (Bedingung: "", shore, people, nopeople, sun, meadow)
var burn9: Dictionary = {}      # Art → was nach dem Brand übrig ist (nur diese Arten brennen)
var goal9: Array = []           # Teilziele: {"type": make|satt|group|hold, "kinds", "kind", "target", "subs"}
var sys9: Dictionary = {}       # Schalter des Levels: volcano, bolt, pack, war, smog, flood, faith, steam_rain, lasting, mercy
var cap9 := 3                   # Gruppen-Stärke höchstens so viel
var stars9: Array = [4, 6]      # [★★★ bis, ★★ bis] Schritte
var par9 := 8                   # Punkte: 5 je Schritt unter Par (Par = ★★★ + 4)
var lost9: Array = []           # Art → so viele gemachte Ziel-Felder sind durch eine Gefahr gefallen
var goal_kinds9: Dictionary = {}
var chain9: Dictionary = {}     # Art → Schritte bis zu einer Ziel-Art (für den Tipp; nur gelesen)
var volc := -1                  # gewarnter Krater (bricht aus, wenn die Lava-Gruppe dann noch ≥ 5 ist)
var pack_warn9: Dictionary = {} # Beute-Feld → true: Jäger (Rudel, Raubsaurier, Frühmenschen) jagen es in der nächsten Runde
## Jagd (GDPD_ERDGESCHICHTE.md 4.1): [{"hunter", "prey": [Arten], "to", "at", "herd"}] (das alte Rudel ist eine davon).
var hunt9: Array = []
## Gletscher (4.2): {"at", "max", "rest", "over": {Art: true}, "immune": {Art: true}} oder {} (kein Gletscher).
var glacier9: Dictionary = {}
var glac9 := -1                 # gewarnter Gletscher-Krater (friert ein, wenn die Eis-Gruppe dann noch ≥ at ist)
var glac_rest9: Array = []      # Feld-ID → so viele Runden ruht dieses Eis noch (warnt nicht wieder)
## Einschlag (4.3): {"at": Runde, "kill": {Art: wird zu}} oder {} (nur im Level „Einschlag“).
var impact9: Dictionary = {}
var impact_done9 := false
var smog_warn9: Dictionary = {} # Natur-Feld → Industrie-Feld: welkt in der nächsten Runde
var meteors := 0                # Meteor-Ladungen (Level 23: eine; ab 27 aus Glauben)
var held9: Array = []           # Ruhe-Ziel: so viele Runden in Folge hält alles
var peak9 := 0
var gain_at9 := 0               # Schritt des letzten neuen Fortschritts (Gnade)
var extra_steps := 0            # gekaufte Wunder: je MIRACLE_STEPS Schritte
var bolt_guard9 := 0            # Blitzschutz aus dem Laden: so viele Runden schlägt kein Blitz ein (0 = aus)
var miracle_bought: Dictionary = {}   # Werkzeug → true: in diesem Level schon ein gekauftes benutzt
var trace9: Array = []          # Ereignis-Namen der letzten Aktion wie im Modell (engine9 ev)
var st9: Dictionary = {}        # Zähler (Bot, Auswertung)
var paid9: Dictionary = {}      # Weiterbauen: (Feld, Art) schon bezahlt (erstes Gedeihen zu einer Art)
var build_new9 := 0             # Weiterbauen: neu gewachsen seit dem Sieg (Reihen + erstes Gedeihen)
var _won_told := false
var _need_told := false
var _era_last := ""             # zuletzt gemeldete Ära (Ereignis era, wenn sich Himmel oder Leben ändern)
var _grp_lab := PackedInt32Array()
var _grp_size := PackedInt32Array()
var _grp_ok := false
var _nb_ids: Array = []
var _nb_ok := false

static var _SLOT9 := {}               # pos_key → Platz-Nummer (Reihenfolge wie beim Aufbau, = Modell POS)
static var _FACE_KEYS9: Array = []    # Seite → 9 pos_keys in Platz-Reihenfolge (= Modell FACE_SLOTS)


static func _build_cache9() -> void:
	if not _SLOT9.is_empty():
		return
	var i := 0
	for x in [-1, 0, 1]:
		for y in [-1, 0, 1]:
			for z in [-1, 0, 1]:
				var p := Vector3i(x, y, z)
				for a in 3:
					if p[a] == 0:
						continue
					_SLOT9[pos_key(p, unit(a, p[a]))] = i
					i += 1
	_FACE_KEYS9 = []
	for nv in FACE_NORMALS:
		var keys: Array = []
		for x in [-1, 0, 1]:
			for y in [-1, 0, 1]:
				for z in [-1, 0, 1]:
					var p := Vector3i(x, y, z)
					var nn: Vector3i = nv
					if p[axis_of(nn)] == nn[axis_of(nn)]:
						keys.append(pos_key(p, nn))
		_FACE_KEYS9.append(keys)


## Platz eines Felds (0 … 53, wie die Felder-Reihenfolge beim Aufbau; im Modell pos[f]).
func slot9(f: FieldData) -> int:
	_build_cache9()
	return int(_SLOT9[pos_key(f.p, f.n)])


## Die 9 Feld-IDs einer Seite in Platz-Reihenfolge (die Mitte an Index 4).
func face_ids9(fc: int) -> Array:
	_build_cache9()
	var out: Array = []
	for k in _FACE_KEYS9[fc]:
		out.append((_index[k] as FieldData).id)
	return out


# --- Aufbau --------------------------------------------------------------------------------

## Ein Level der Kampagne: cfg = Campaign.config(n) (die Level-Daten aus data/kampagne_erde.json),
## kinds = 54 Arten (Feld-ID-Reihenfolge), seed_value = Seed des Bretts (Blitz-Zufall wie im Modell).
func setup_level(cfg: Dictionary, kinds: Array, seed_value: int = 1) -> void:
	_reset(seed_value if seed_value != 0 else 1, true, 2, false)
	_apply_level_rules(cfg, seed_value)
	for i in mini(kinds.size(), fields.size()):
		(fields[i] as FieldData).kind = int(kinds[i])
	_grp_ok = false
	_init_fields9()


func _apply_level_rules(cfg: Dictionary, seed_value: int) -> void:
	day = cfg.duplicate(true)
	camp = true
	level_no = int(cfg.get("level", 0))
	day_no = 0
	diagonals = false
	easy = false
	once = true
	no_fire = true
	calm = false
	gadgets = true
	sys_wishes = false
	sys_scale = false
	sys_income = false
	sys_war = false
	no_war = false
	sys_smog = false
	sys_regrow = false
	sys_strike = false
	sys_flood = false
	sys_bolts = false
	sys_monsoon = false
	sys_gift = false
	choices_on = {}
	unlocked = {}
	use_lcg = true
	lcg = (seed_value * 7919 + 17) & 0x7fffffff
	rows9 = {}
	var nx: Dictionary = cfg.get("next", {})
	for k in cfg.get("rows", []):
		if nx.has(str(int(k))):
			rows9[int(k)] = int(nx[str(int(k))])
	consume9 = {}
	var cs: Dictionary = cfg.get("consume", {})
	for key in cs:
		consume9[int(str(key))] = int(cs[key])
	thrive9 = {}
	var th: Dictionary = cfg.get("thrive", {})
	for key in th:
		var r: Dictionary = th[key]
		var needs := {}
		var nd: Dictionary = r.get("needs", {})
		for n in nd:
			needs[str(n)] = int(nd[n])
		var sp: Array = []
		if r.get("spawn") is Array:
			var s0: Array = r["spawn"]
			var on: Array = []
			for k in s0[0]:
				on.append(int(k))
			sp = [on, int(s0[1]), int(s0[2]) if s0[2] != null else -1]
		thrive9[int(str(key))] = {"needs": needs, "up": int(r["up"]) if r.get("up") != null else -1,
			"down": int(r["down"]) if r.get("down") != null else -1, "spawn": sp,
			"G": int(r["G"]) if r.get("G") != null else int(B9["G"])}
	rain9 = []
	for item in cfg.get("rain", []):
		var it: Array = item
		# Bedingung: "" | shore | people | nopeople | sun | meadow, oder eine Art (das Feld muss sie berühren, 4.4)
		var cond: Variant = ""
		if it[1] is float or it[1] is int:
			cond = int(it[1])
		elif it[1] != null:
			cond = str(it[1])
		rain9.append([int(it[0]), cond, int(it[2])])
	burn9 = {}
	var bn: Dictionary = cfg.get("burn", {})
	for key in bn:
		burn9[int(str(key))] = int(bn[key])
	goal9 = []
	goal_kinds9 = {}
	for g in cfg.get("goal", []):
		var sub := _goal_sub9(g)
		goal9.append(sub)
		if str(sub["type"]) == "make":
			for k in sub["kinds"]:
				goal_kinds9[int(k)] = true
	# Jagd (4.1): cfg.hunt = [[Jäger, [Beute], fällt zu, ab, Herde]]; ohne hunt ist das alte Rudel (pack) eine Jagd
	hunt9 = []
	var hl: Array = cfg.get("hunt", []) if cfg.get("hunt") is Array else []
	if hl.is_empty() and bool(cfg.get("pack", false)):
		hl = [PACK_HUNT9]
	for h in hl:
		var ha: Array = h
		var prey: Array = []
		for k in ha[1]:
			prey.append(int(k))
		hunt9.append({"hunter": int(ha[0]), "prey": prey, "to": int(ha[2]), "at": int(ha[3]) if ha.size() > 3 else 3,
			"herd": int(ha[4]) if ha.size() > 4 and ha[4] != null else 0})
	# Gletscher (4.2): die Vulkan-Regel mit anderen Zahlen
	glacier9 = {}
	if cfg.get("glacier") is Dictionary:
		var gl: Dictionary = cfg["glacier"]
		var over := {}
		for k in gl.get("over", FREEZE9):
			over[int(k)] = true
		var imm := {}
		for k in gl.get("immune", []):
			imm[int(k)] = true
		glacier9 = {"at": int(gl.get("at", B10["GLAC_AT"])), "max": int(gl.get("max", B10["GLAC_MAX"])),
			"rest": int(gl.get("rest", B10["GLAC_REST"])), "over": over, "immune": imm}
	# Einschlag (4.3): nach Runde at wird jedes Feld einer kill-Art zu der genannten Art
	impact9 = {}
	if cfg.get("impact") is Dictionary:
		var im: Dictionary = cfg["impact"]
		var kill := {}
		var kd: Dictionary = im.get("kill", {})
		for key in kd:
			kill[int(str(key))] = int(kd[key])
		impact9 = {"at": int(im.get("at", 1)), "kill": kill}
	sys9 = {"volcano": bool(cfg.get("volcano", false)), "bolt": bool(cfg.get("bolt", false)),
		"pack": not hunt9.is_empty(), "glacier": not glacier9.is_empty(), "impact": not impact9.is_empty(),
		"war": bool(cfg.get("war", false)), "smog": bool(cfg.get("smog", false)),
		"flood": bool(cfg.get("flood", false)), "faith": bool(cfg.get("faith", false)),
		"steam_rain": bool(cfg.get("steam_rain", false)), "lasting": bool(cfg.get("lasting", true)),
		"mercy": bool(cfg.get("mercy", true))}
	cap9 = int(cfg.get("cap", B9["CAP"]))
	var sv: Array = cfg.get("stars", [4, 6])
	stars9 = [int(sv[0]), int(sv[1])]
	par9 = int(cfg.get("par", stars9[0] + 4))
	rain = int(cfg.get("rain_start", 0))
	rain_every = int(cfg.get("rain_every", 0))
	next_rain = rain_every
	meteors = int(cfg.get("meteor_start", 0))
	faith = 0
	bolts = 0
	day_limit = 0
	lost9 = []
	for k in FieldData.KIND_COUNT:
		lost9.append(0)
	held9 = []
	for g in goal9:
		held9.append(0)
	volc = -1
	pack_warn9 = {}
	glac9 = -1
	glac_rest9 = []
	for i in maxi(54, fields.size()):
		glac_rest9.append(0)
	impact_done9 = false
	smog_warn9 = {}
	peak9 = 0
	gain_at9 = 0
	extra_steps = 0
	bolt_guard9 = 0
	miracle_bought = {}
	paid9 = {}
	build_new9 = 0
	_won_told = false
	_need_told = false
	st9 = {"rows": 0, "thr": 0, "spawn": 0, "starve": 0, "lost": 0, "burnt": 0, "strikes": 0, "bolt_warns": 0,
		"volc_warns": 0, "eruptions": 0, "cooled": 0, "wars": 0, "war_hits": 0, "smogged": 0, "flooded": 0,
		"floods": 0, "pack_hunts": 0, "rains": 0, "mercy": 0, "meteors": 0, "steam": 0, "consumed": 0,
		"hunger_warns": 0, "gifts": 0, "hunts": 0, "hunt_warns": 0, "glac_warns": 0, "freezes": 0, "frozen": 0,
		"thawed": 0, "impact": 0}
	chain9 = _chain_dist9()
	_rebuild_rules()


static func _goal_sub9(g: Variant) -> Dictionary:
	var a: Array = g
	var t := str(a[0])
	if t == "hold":
		var subs: Array = []
		for x in a[1]:
			subs.append(_goal_sub9(x))
		return {"type": t, "subs": subs, "target": int(a[2]), "kinds": [], "kind": -1}
	if t == "make":
		var ks: Array = []
		for k in a[1]:
			ks.append(int(k))
		return {"type": t, "kinds": ks, "kind": int(ks[0]) if not ks.is_empty() else -1, "target": int(a[2])}
	return {"type": t, "kind": int(a[1]), "kinds": [int(a[1])], "target": int(a[2])}


## Felder am Morgen: Vorrat (wer schon da ist und verhungern kann, hat 3 Runden extra), Glaube-Stufe neben Kirchen.
func _init_fields9() -> void:
	for f in fields:
		f.fed = 0
		f.hungry = 0
		f.burning = false
		f.fresh = 0
		f.best = {}
		f.mk = false
		f.crater_rest = 0
		f.maxlvl = -1
		f.flvl = -1
	if bool(sys9.get("faith", false)):
		for f in fields:
			if LEVEL9.has(f.kind) and _next_to9(f.id, FieldData.CHURCH):
				f.flvl = int(LEVEL9[f.kind])
	for f in fields:
		var r: Variant = thrive9.get(f.kind)
		if r != null and int((r as Dictionary)["down"]) >= 0:
			f.hungry = -int(B9["GRACE"])
	ever = {}
	for f in fields:
		ever[f.kind] = true
	_satt0 = {}
	for i in satt_ids9():
		_satt0[int(i)] = true
	_era_last = _era_key9(era9())


# --- Nachbarn, Gruppen, Angebot ------------------------------------------------------------

## Nachbar-IDs aller Felder (gilt bis zur nächsten Drehung).
func _nbs9() -> Array:
	if not _nb_ok:
		if not _cache_ready:
			_build_cache()
		_nb_ids.resize(fields.size())
		for f in fields:
			var ids := PackedInt32Array()
			for k in _NEI[pos_key(f.p, f.n)]:
				ids.append((_index[k] as FieldData).id)
			_nb_ids[f.id] = ids
		_nb_ok = true
	return _nb_ids


func nb9(fid: int) -> PackedInt32Array:
	return _nbs9()[fid]


func _next_to9(fid: int, k: int) -> bool:
	for g in nb9(fid):
		if (fields[g] as FieldData).kind == k:
			return true
	return false


## Ein Wasser-Nachbar (Wasser-Familie)?
func wet9(fid: int) -> bool:
	for g in nb9(fid):
		if FieldData.water_family((fields[g] as FieldData).kind):
			return true
	return false


func _groups9() -> void:
	if _grp_ok:
		return
	var nbs := _nbs9()
	var n := fields.size()
	_grp_lab.resize(n)
	_grp_lab.fill(-1)
	_grp_size = PackedInt32Array()
	for f in n:
		if _grp_lab[f] >= 0:
			continue
		var k: int = (fields[f] as FieldData).kind
		var lab := _grp_size.size()
		_grp_lab[f] = lab
		var todo: Array = [f]
		var c := 0
		while not todo.is_empty():
			var h: int = todo.pop_back()
			c += 1
			for g in nbs[h]:
				if _grp_lab[g] < 0 and (fields[g] as FieldData).kind == k:
					_grp_lab[g] = lab
					todo.append(g)
		_grp_size.append(c)
	_grp_ok = true


## Gruppe (gleiche Art, über Kanten verbunden): Nummer und Größe.
func group_id9(fid: int) -> int:
	_groups9()
	return _grp_lab[fid]


func gsize9(fid: int) -> int:
	_groups9()
	return _grp_size[_grp_lab[fid]]


## Die Felder der Gruppe von fid (aufsteigende IDs).
func members9(fid: int) -> Array:
	_groups9()
	var lab := _grp_lab[fid]
	var out: Array = []
	for g in fields.size():
		if _grp_lab[g] == lab:
			out.append(g)
	return out


## Größte Gruppe der Art k (0: keine).
func biggest9(k: int) -> int:
	_groups9()
	var best_n := 0
	for f in fields:
		if f.kind == k:
			best_n = maxi(best_n, _grp_size[_grp_lab[f.id]])
	return best_n


## Stärke einer Quell-Gruppe: min(Größe, 3).
func strength9(fid: int) -> int:
	return mini(gsize9(fid), cap9)


## Angebot eines Bedürfnisses an einem Feld: Summe der Stärken der VERSCHIEDENEN Quell-Gruppen daneben
## (sun: 1 auf der Sonnenseite, wet: Zahl der Wasser-Nachbarn).
func supply9(fid: int, need: String) -> int:
	if need == "sun":
		return 1 if face_index(fields[fid]) == SUN_FACE else 0
	if need == "wet":
		var w := 0
		for g in nb9(fid):
			if FieldData.water_family((fields[g] as FieldData).kind):
				w += 1
		return w
	var src: Array = SOURCES9.get(need, [])
	_groups9()
	var seen := {}
	var tot := 0
	for g in nb9(fid):
		if src.has((fields[g] as FieldData).kind):
			var lab := _grp_lab[g]
			if not seen.has(lab):
				seen[lab] = true
				tot += mini(_grp_size[lab], cap9)
	return tot


## Was zählt: das Angebot jetzt oder das beste je an einem Rundenende gesehene (versiegelt, „bleibt versorgt“).
func eff9(fid: int, need: String) -> int:
	var cur := supply9(fid, need)
	var f: FieldData = fields[fid]
	if bool(sys9.get("lasting", true)) and f.best.has(need):
		return maxi(cur, int(f.best[need]))
	return cur


## Ist das Bedürfnis need dieses Felds versiegelt (einmal versorgt, bleibt versorgt)?
func sealed9(fid: int, need: String) -> bool:
	var f: FieldData = fields[fid]
	var r: Variant = thrive9.get(f.kind)
	if r == null or not bool(sys9.get("lasting", true)):
		return false
	var nd: Dictionary = (r as Dictionary)["needs"]
	return nd.has(need) and int(f.best.get(need, 0)) >= int(nd[need])


func satt9(fid: int) -> bool:
	var f: FieldData = fields[fid]
	var r: Variant = thrive9.get(f.kind)
	if r == null:
		return false
	if f.burning or front.has(fid):
		return false
	var nd: Dictionary = (r as Dictionary)["needs"]
	for n in nd:
		if eff9(fid, str(n)) < int(nd[n]):
			return false
	return true


func satt_ids9() -> Array:
	var out: Array = []
	for f in fields:
		if thrive9.has(f.kind) and satt9(f.id):
			out.append(f.id)
	return out


## Jedes Bedürfnis (außer ☀) doppelt erfüllt: wächst doppelt so schnell (Zusammenwachsen lohnt sich).
func _rich9(fid: int, rule: Dictionary) -> bool:
	var nd: Dictionary = rule["needs"]
	for n in nd:
		if str(n) != "sun" and eff9(fid, str(n)) < 2 * int(nd[n]):
			return false
	return true


## Menschen wachsen nur, wo die nächste Stufe satt wäre: gemeinsame (versiegelte) Bedürfnisse zählen, neue müssen
## jetzt da sein.
func up_ok9(fid: int, nk: int) -> bool:
	var r: Variant = thrive9.get(nk)
	if r == null:
		return true
	var f: FieldData = fields[fid]
	var k: int = f.kind
	var b: Dictionary = f.best if bool(sys9.get("lasting", true)) else {}
	f.kind = nk
	_grp_ok = false
	var ok := true
	var nd: Dictionary = (r as Dictionary)["needs"]
	for n in nd:
		if maxi(supply9(fid, str(n)), int(b.get(n, 0))) < int(nd[n]):
			ok = false
			break
	f.kind = k
	_grp_ok = false
	return ok


## Zustand der Bedürfnisse eines Felds für Anzeige und Vorschau: {"met", "sealed", "missing" (Namen),
## "have": {Bedürfnis: [hat, braucht]}}. met = zählt (jetzt da oder versiegelt); sealed ⊆ met.
func need_state9(f: FieldData) -> Dictionary:
	var met: Array = []
	var sealed: Array = []
	var miss: Array = []
	var have := {}
	var r: Variant = thrive9.get(f.kind)
	if r == null:
		return {"met": met, "sealed": sealed, "missing": miss, "have": have}
	var nd: Dictionary = (r as Dictionary)["needs"]
	for n in nd:
		var ns := str(n)
		var amt := int(nd[n])
		var e := eff9(f.id, ns)
		have[ns] = [mini(e, 99), amt]
		if e >= amt:
			met.append(ns)
			if sealed9(f.id, ns):
				sealed.append(ns)
		else:
			miss.append(ns)
	return {"met": met, "sealed": sealed, "missing": miss, "have": have}


# --- Arten ändern (alles läuft hier durch: Gruppen, Ziel-Buchhaltung, Siegel) -------------------

func _setk9(f: FieldData, nk: int) -> void:
	if f.kind != nk:
		f.kind = nk
		_grp_ok = false
		f.best = {}             # eine neue Art beginnt ohne Siegel (rise9 behält gemeinsame)


## Wachsen (Reihe, Gedeihen, Landgang, Regen): zählt für Ziel-Arten, nie als Verlust. Gemeinsame Bedürfnisse bleiben
## versiegelt („nur die neuen Bedürfnisse“).
func _rise9(f: FieldData, nk: int) -> void:
	var old: Dictionary = f.best
	_setk9(f, nk)
	if not old.is_empty():
		var r: Variant = thrive9.get(nk)
		if r != null:
			var keep := {}
			var nd: Dictionary = (r as Dictionary)["needs"]
			for n in old:
				if nd.has(n):
					keep[n] = old[n]
			f.best = keep
	made[nk] = int(made[nk]) + 1
	f.mk = goal_kinds9.has(nk)
	f.fed = 0
	f.hungry = 0


## Weiterbauen: ein Feld erreicht durch Gedeihen eine Art zum ersten Mal → +1 neu gewachsen (wieder satt zählt nie).
func _pay_thrive9(fid: int, k: int) -> void:
	if not day_free_build:
		return
	var key := fid * 32 + k
	if not paid9.has(key):
		paid9[key] = true
		build_new9 += 1


## Fallen durch eine Gefahr (Feuer, Ausbruch, Hunger, Krieg, Flut, Smog, Rudel, Meteor): ein gemachtes Ziel-Feld
## zählt −1 (goal_loss).
func _fall9(f: FieldData, nk: int, cause: String, ev: Array) -> void:
	var k: int = f.kind
	if f.mk:
		lost9[k] = int(lost9[k]) + 1
		st9["lost"] = int(st9["lost"]) + 1
		f.mk = false
		_ev9(ev, "goal_loss", {"type": "goal_loss", "field": f.id, "kind": k, "cause": cause,
			"progress": progress9(), "cue": "−1 %s" % FieldData.kind_name(k)})
	f.mk = false
	_setk9(f, nk)
	_unspend9(f.id)
	f.fed = 0
	f.hungry = 0
	f.burning = false
	front.erase(f.id)


## Ein Feld verliert seine Art durch die Welt (Gefahr, Landgang, Geschenk, Nachschub): Reihen mit diesem Feld gelten
## nicht mehr als „schon gewachsen“. Bildet sich dieselbe Reihe wieder, wächst sie (sofort, in der späten Runde).
## Hin- und Herdrehen bringt nichts: Ohne Ereignis der Welt bleibt eine gewachsene Reihe verbraucht.
func _unspend9(fid: int) -> void:
	if engine9_mode or spent.is_empty():
		return
	var drop: Array = []
	for key in spent:
		var ids3 := int(key) / 32
		if ids3 % 64 == fid or (ids3 / 64) % 64 == fid or ids3 / 4096 == fid:
			drop.append(key)
	for key in drop:
		spent.erase(key)


func _ev9(ev: Array, model_name: String, e: Dictionary) -> void:
	trace9.append(model_name)
	ev.append(e)


# --- Erschaffen: Reihen, ganze Seiten, Verbrauch ---------------------------------------------

func _resolve_faces9(ev: Array, locked: Dictionary, src: Dictionary, late: bool = false) -> void:
	for fc in 6:
		var ids := face_ids9(fc)
		var k: int = (fields[int(ids[0])] as FieldData).kind
		if not rows9.has(k):
			continue
		var same := true
		var touched := false
		for i in ids:
			if (fields[int(i)] as FieldData).kind != k:
				same = false
			if src.has(int(i)):
				touched = true
		if not same or not touched:
			continue
		var nk: int = int(rows9[k])
		var face: Array = []
		for i in ids:
			face.append(fields[int(i)])
		_spend_face(face)
		for i in ids:
			var h: FieldData = fields[int(i)]
			_rise9(h, nk)
			h.burning = false
			locked[h.id] = true
		_grew += 1
		st9["rows"] = int(st9["rows"]) + 1
		if day_free_build:
			build_new9 += 1
		_ev9(ev, "face", {"type": "face", "field": int(ids[4]), "fields": ids.duplicate(), "points": 0, "stage": nk,
			"kind": nk, "from": k, "late": late})


## Reihen, in denen sich gerade etwas verändert hat, wachsen (once: jede Reihe nur einmal), dann Kettenreaktionen.
## late (Build 12, „Drei gleiche in einer geraden Reihe wachsen immer“): die späte Runde am Rundenende. src = Felder,
## deren Art sich durch die Welt geändert hat (Abkühlen, Ausbruch, Landgang, Hunger …); jede Reihe durch sie, die noch
## nicht gewachsen ist, wächst sofort (Ereignisse mit "late": true). Ohne late: src = die bewegten Felder (moved).
func _resolve_merges9(ev: Array, late: bool = false, src: Dictionary = {}) -> void:
	var base: Dictionary = src if late else moved
	var locked := {}
	_resolve_faces9(ev, locked, base, late)
	var focus := base.duplicate()
	var touched := base.duplicate()
	for fid in locked:
		touched[fid] = true
	var changed := locked.duplicate()
	var done := {}
	var told := {}
	for pass_i in int(B9["MAX_CASCADES"]):
		if focus.is_empty():
			break
		var found: Array = []
		for ln in lines(focus):
			var lk := line_key(ln)
			if pass_i == 0 and not late:
				if not counts(ln):
					if (broken.has(lk) or spent.has(lk)) and not standing.has(lk) and not told.has(lk):
						told[lk] = true
						ev.append({"type": "repeat", "fields": [(ln[0] as FieldData).id, (ln[1] as FieldData).id,
							(ln[2] as FieldData).id], "spent": spent.has(lk) and not broken.has(lk)})
					continue
			elif spent.has(lk):
				continue
			found.append([ln, (ln[0] as FieldData).kind])
		if found.is_empty():
			break
		var last_focus := focus
		focus = {}
		for item in found:
			var line: Array = item[0]
			var k: int = item[1]
			var skip := false
			var free: Array = []
			for i in 3:
				var fd: FieldData = line[i]
				if fd.kind != k or locked.has(fd.id):
					skip = true
				if not done.has(fd.id):
					free.append(i)
			if skip or free.is_empty():
				continue
			var ti := target_index(line, base if pass_i == 0 else last_focus, tapped)
			if not free.has(ti):
				ti = 1 if free.has(1) else int(free[0])
			if _satt_goal_kind9(k) and satt9((line[ti] as FieldData).id):
				# Weiterentwickeln ist kein Verlust: wächst lieber ein Feld, das noch nicht satt ist (engine9 gleich)
				var order: Array = [1]
				for x in free:
					if int(x) != 1:
						order.append(int(x))
				for x in order:
					if free.has(x) and not satt9((line[int(x)] as FieldData).id):
						ti = int(x)
						break
			var mid: FieldData = line[ti]
			var nk: int = int(rows9.get(k, k))
			mid.burning = false
			spent[line_key(line)] = true
			if nk == k:
				continue
			_rise9(mid, nk)
			focus[mid.id] = true
			touched[mid.id] = true
			changed[mid.id] = true
			_grew += 1
			st9["rows"] = int(st9["rows"]) + 1
			if day_free_build:
				build_new9 += 1
			var others: Array = []
			for g in line:
				if (g as FieldData).id != mid.id:
					others.append((g as FieldData).id)
			var eaten: Array = []
			if consume9.has(k):
				for g in line:
					var o: FieldData = g
					if o.id != mid.id and o.kind == k:
						_setk9(o, int(consume9[k]))
						o.mk = false
						o.burning = false
						o.fed = 0
						o.hungry = 0
						locked[o.id] = true
						done[o.id] = true
						eaten.append(o.id)
						st9["consumed"] = int(st9["consumed"]) + 1
				locked[mid.id] = true
			_ev9(ev, "grow", {"type": "merge", "field": mid.id, "others": others, "points": 0, "combo": 1,
				"stage": nk, "kind": nk, "from": k, "late": late, "consume": not eaten.is_empty(), "eaten": eaten})
			if not eaten.is_empty():
				ev.append({"type": "consume", "field": mid.id, "others": eaten, "from": k, "kind": nk,
					"left": int(consume9[k]), "late": late})
	_still_rows(ev, touched, changed, late)


# --- Gedeihen (3.2): versiegeln, satt, wachsen, Landgang, Hunger --------------------------------

## Rundenende: das beste Angebot je Bedürfnis merken (alle Felder auf einem Stand gemessen, dann geschrieben).
func _seal_step9(ev: Array) -> void:
	if not bool(sys9.get("lasting", true)) or thrive9.is_empty():
		return
	var upd: Array = []
	for f in fields:
		var r: Variant = thrive9.get(f.kind)
		if r == null or f.burning or front.has(f.id):
			continue
		var b: Dictionary = f.best
		var nb: Dictionary = {}
		var any := false
		var nd: Dictionary = (r as Dictionary)["needs"]
		for n in nd:
			var cur := supply9(f.id, str(n))
			var was := int(b.get(n, 0))
			if cur > was:
				if not any:
					nb = b.duplicate()
					any = true
				nb[n] = cur
				if was < int(nd[n]) and int(nd[n]) <= cur:
					_ev9(ev, "need_sealed", {"type": "need_sealed", "field": f.id, "kind": f.kind, "need": str(n),
						"icon": str(NEED_ICON9.get(str(n), "info")), "first": not _need_told})
					_need_told = true
		if any:
			upd.append([f, nb])
	for item in upd:
		(item[0] as FieldData).best = item[1]


func _thrive_step9(ev: Array) -> void:
	if thrive9.is_empty():
		return
	var H := int(B9["H"])
	_seal_step9(ev)
	var ok := {}
	for f in fields:
		if thrive9.has(f.kind):
			ok[f.id] = satt9(f.id)
	for f in fields:
		var k: int = f.kind
		if not ok.has(f.id) or not thrive9.has(k):
			if not thrive9.has(k):
				f.fed = 0
				f.hungry = 0
			continue
		var rule: Dictionary = thrive9[k]
		var up := int(rule["up"])
		var sp: Array = rule["spawn"]
		var G := int(rule["G"])
		if bool(ok[f.id]):
			f.hungry = 0
			f.fed += 2 if (up >= 0 or not sp.is_empty()) and _rich9(f.id, rule) else 1
			if f.fed >= G:
				if up >= 0 and LEVEL9.has(k) and not up_ok9(f.id, up):
					pass            # „Wächst bald“: Menschen wachsen erst, wenn die nächste Stufe satt wäre
				elif up >= 0:
					var first := int(made[up]) == 0
					_rise9(f, up)
					_pay_thrive9(f.id, up)
					_grew += 1
					st9["thr"] = int(st9["thr"]) + 1
					_ev9(ev, "thrive", {"type": "thrive", "field": f.id, "from": k, "kind": up, "first": first})
					if k == FieldData.LAVA and bool(sys9.get("steam_rain", false)):
						rain = mini(int(B9["RAIN_MAX"]), rain + 1)
						st9["steam"] = int(st9["steam"]) + 1
						_ev9(ev, "steam", {"type": "steam", "field": f.id, "rain": rain})
					if k == FieldData.LAVA:
						st9["cooled"] = int(st9["cooled"]) + 1
				elif not sp.is_empty():
					var on: Array = sp[0]
					var cand: Array = []
					for g in nb9(f.id):
						if on.has((fields[g] as FieldData).kind):
							cand.append(int(g))
					if not cand.is_empty():
						cand.sort()
						var tg: FieldData = fields[int(cand[0])]
						_rise9(tg, int(sp[1]))
						_pay_thrive9(tg.id, int(sp[1]))
						_grew += 1
						st9["spawn"] = int(st9["spawn"]) + 1
						_ev9(ev, "spawn", {"type": "spawn", "field": f.id, "target": tg.id, "kind": int(sp[1]),
							"after": int(sp[2])})
						if int(sp[2]) >= 0:
							_setk9(f, int(sp[2]))
							_unspend9(f.id)
							f.mk = false
						f.fed = 0
		else:
			f.fed = 0
			if int(rule["down"]) < 0:
				continue
			f.hungry += 1
			if f.hungry == H - 1:
				st9["hunger_warns"] = int(st9["hunger_warns"]) + 1
				_ev9(ev, "hunger_warn", {"type": "hunger_warn", "field": f.id, "kind": k,
					"missing": need_state9(f)["missing"]})
			if f.hungry >= H:
				var dn := int(rule["down"])
				_fall9(f, dn, "hunger", ev)
				st9["starve"] = int(st9["starve"]) + 1
				_ev9(ev, "starve", {"type": "starve", "field": f.id, "from": k, "kind": dn})


# --- Gefahren (3.6): Folgen, je eine Runde vorher gewarnt ----------------------------------------

func flammable9(k: int) -> bool:
	return burn9.has(k)


func _fire_step9(ev: Array) -> void:
	var old: Array = []
	for f in fields:
		if f.burning:
			old.append(f)
	var nw := {}
	for f in old:
		for g in nb9((f as FieldData).id):
			var h: FieldData = fields[g]
			if flammable9(h.kind) and not h.burning and h.fresh == 0 and not wet9(h.id):
				nw[h.id] = true
	for f in old:
		var fd: FieldData = f
		var k: int = fd.kind
		var nk := int(burn9.get(k, k))
		_fall9(fd, nk, "fire", ev)
		fd.fresh = int(B9["FRESH"]) + 1
		st9["burnt"] = int(st9["burnt"]) + 1
		stats["fires"] = int(stats["fires"]) + 1
		_ev9(ev, "burnt", {"type": "burn", "field": fd.id, "from": k, "kind": nk})
	var ids: Array = nw.keys()
	ids.sort()
	for i in ids:
		(fields[int(i)] as FieldData).burning = true
		_ev9(ev, "ignite", {"type": "ignite", "field": int(i)})


## Trockener Wald: ein Wald in einer Wald-Gruppe von mindestens 3, an der kein Feld Wasser berührt.
func dry9(fid: int) -> bool:
	if (fields[fid] as FieldData).kind != FieldData.FOREST:
		return false
	if gsize9(fid) < int(B9["DRY_AT"]):
		return false
	for g in members9(fid):
		if wet9(int(g)):
			return false
	return true


func _bolt_step9(ev: Array) -> void:
	if bolt_guard9 > 0:
		# Blitzschutz (GDPD_PUNKTE_LADEN.md 5.1): keine Warnung, kein Einschlag, solange er hält
		bolt_guard9 -= 1
		if bolt >= 0:
			_ev9(ev, "bolt_miss", {"type": "bolt_miss", "field": bolt, "guard": true})
			bolt = -1
		return
	if bolt >= 0:
		var f: FieldData = fields[bolt]
		bolt = -1
		if dry9(f.id) and not f.burning and f.fresh == 0:
			f.burning = true
			st9["strikes"] = int(st9["strikes"]) + 1
			_ev9(ev, "bolt", {"type": "bolt", "field": f.id})
		else:
			_ev9(ev, "bolt_miss", {"type": "bolt_miss", "field": f.id})
		return
	var top_a := -1
	var top_b := -1
	var best_ids: Array = []
	for f in fields:
		if f.kind == FieldData.FOREST and not f.burning and f.fresh == 0 and dry9(f.id):
			var n := 0
			for g in nb9(f.id):
				if flammable9((fields[g] as FieldData).kind):
					n += 1
			var a := gsize9(f.id)
			if a > top_a or (a == top_a and n > top_b):
				top_a = a
				top_b = n
				best_ids = [f.id]
			elif a == top_a and n == top_b:
				best_ids.append(f.id)
	if not best_ids.is_empty():
		best_ids.sort()
		bolt = int(best_ids[_rand(best_ids.size())])
		st9["bolt_warns"] = int(st9["bolt_warns"]) + 1
		_ev9(ev, "bolt_warn", {"type": "bolt_warn", "field": bolt, "fields": members9(bolt)})


func _volcano_step9(ev: Array) -> void:
	var A := int(B9["VOLC_AT"])
	for f in fields:
		if f.crater_rest > 0:
			f.crater_rest -= 1
	if volc >= 0:
		var c := volc
		volc = -1
		if (fields[c] as FieldData).kind == FieldData.LAVA and gsize9(c) >= A:
			var grp := members9(c)
			var gset := {}
			for g in grp:
				gset[int(g)] = true
			var order: Array = [c]
			for g in grp:
				if int(g) != c:
					order.append(int(g))
			var near: Array = []
			for h in order:
				for g in nb9(int(h)):
					if not gset.has(g) and ERUPTS9.has((fields[g] as FieldData).kind) and not near.has(g):
						near.append(g)
			var hit := near.slice(0, int(B9["ERUPT_MAX"]))
			for g in hit:
				var fd: FieldData = fields[int(g)]
				var k: int = fd.kind
				_fall9(fd, FieldData.LAVA, "volcano", ev)
				_ev9(ev, "erupt", {"type": "erupt", "crater": c, "field": fd.id, "from": k, "kind": FieldData.LAVA})
			st9["eruptions"] = int(st9["eruptions"]) + 1
			for g in members9(c):
				(fields[int(g)] as FieldData).crater_rest = int(B9["CRATER_REST"]) + 1
		else:
			_ev9(ev, "volcano_calm", {"type": "volcano_calm", "crater": c})
		return
	var cand: Array = []
	for f in fields:
		if f.kind == FieldData.LAVA and f.crater_rest == 0 and gsize9(f.id) >= A:
			var n := 0
			for g in nb9(f.id):
				if (fields[g] as FieldData).kind == FieldData.LAVA:
					n += 1
			cand.append([gsize9(f.id), n, f.id])
	if not cand.is_empty():
		cand.sort_custom(func(x, y): return int(x[0]) > int(y[0]) or (int(x[0]) == int(y[0]) and (int(x[1]) > int(y[1]) or (int(x[1]) == int(y[1]) and int(x[2]) < int(y[2])))))
		volc = int(cand[0][2])
		st9["volc_warns"] = int(st9["volc_warns"]) + 1
		_ev9(ev, "volcano_warn", {"type": "volcano_warn", "crater": volc, "field": volc, "fields": members9(volc)})


## Jagd (GDPD_ERDGESCHICHTE.md 4.1, das alte Rudel ist eine davon): Beute-Felder neben einer Jäger-Gruppe ≥ at, außer sie
## stehen in einer Herde (Beute-Gruppe ≥ herd, wenn herd > 0).
func hunt_targets9() -> Dictionary:
	var out := {}
	for h in hunt9:
		var hd: Dictionary = h
		var hk := int(hd["hunter"])
		var prey: Array = hd["prey"]
		var herd := int(hd["herd"])
		for f in fields:
			if f.kind != hk or gsize9(f.id) < int(hd["at"]):
				continue
			for g in nb9(f.id):
				var gk: int = (fields[g] as FieldData).kind
				if prey.has(gk) and not (herd > 0 and gsize9(g) >= herd):
					out[g] = true
	return out


## Die Jagd-Regel, die ein Beute-Feld der Art k trifft ({} = keine).
func _hunt_rule9(k: int) -> Dictionary:
	for h in hunt9:
		if ((h as Dictionary)["prey"] as Array).has(k):
			return h
	return {}


## Wer jagt (für Pille, Zeile und Bild): der Jäger der ersten Regel, die eines der Felder trifft.
func hunter_of9(ids: Array) -> int:
	for i in ids:
		var r := _hunt_rule9((fields[int(i)] as FieldData).kind)
		if not r.is_empty():
			return int(r["hunter"])
	return int((hunt9[0] as Dictionary)["hunter"]) if not hunt9.is_empty() else FieldData.PRED


## Jagd: Gewarnte Beute, die noch Ziel ist, fällt (eine Runde nach der Warnung); dann neu warnen (nicht in der Runde,
## in der gejagt wurde).
func _pack_step9(ev: Array) -> void:
	if not pack_warn9.is_empty():
		var now := hunt_targets9()
		var hunt: Array = []
		for i in pack_warn9:
			if now.has(int(i)):
				hunt.append(int(i))
		hunt.sort()
		for i in hunt:
			var fd: FieldData = fields[int(i)]
			var k: int = fd.kind
			var rule := _hunt_rule9(k)
			var to := int(rule.get("to", FieldData.MEADOW))
			_fall9(fd, to, "pack", ev)
			st9["hunts"] = int(st9["hunts"]) + 1
			st9["pack_hunts"] = int(st9["pack_hunts"]) + 1
			_ev9(ev, "pack_hunt", {"type": "pack_hunt", "field": fd.id, "from": k, "kind": to,
				"hunter": int(rule.get("hunter", FieldData.PRED))})
		pack_warn9 = {}
		if not hunt.is_empty():
			return
	var warn := hunt_targets9()
	if not warn.is_empty():
		pack_warn9 = warn
		st9["hunt_warns"] = int(st9["hunt_warns"]) + 1
		var ws: Array = warn.keys()
		ws.sort()
		_ev9(ev, "pack_warn", {"type": "pack_warn", "fields": ws, "hunter": hunter_of9(ws)})


## Gletscher: darf Feld g einfrieren? (Art in over, nicht immun, nicht neben einer Feuerstelle)
func freezable9(g: int) -> bool:
	if glacier9.is_empty():
		return false
	var k: int = (fields[g] as FieldData).kind
	if not (glacier9["over"] as Dictionary).has(k) or (glacier9["immune"] as Dictionary).has(k):
		return false
	return not _next_to9(g, FieldData.CAMP)


## Die Felder, die ein Gletscher-Krater c einfrieren würde (Krater zuerst, dann nach ID; höchstens max).
func glacier_threat9(c: int) -> Array:
	if c < 0 or glacier9.is_empty():
		return []
	var grp := members9(c)
	var gset := {}
	for g in grp:
		gset[int(g)] = true
	var order: Array = [c]
	for g in grp:
		if int(g) != c:
			order.append(int(g))
	var near: Array = []
	for h in order:
		for g in nb9(int(h)):
			if not gset.has(g) and not near.has(g) and freezable9(g):
				near.append(g)
	return near.slice(0, int(glacier9["max"]))


## Gletscher (4.2): eine Eis-Gruppe ≥ at wird gewarnt; ist sie eine Runde später noch so groß, frieren bis zu max
## Nachbarn ein (Ereignis freeze, ein Verlust auf einem gemachten Ziel-Feld) und die Gruppe ruht rest Runden.
func _glacier_step9(ev: Array) -> void:
	var A := int(glacier9["at"])
	for i in glac_rest9.size():
		if int(glac_rest9[i]) > 0:
			glac_rest9[i] = int(glac_rest9[i]) - 1
	if glac9 >= 0:
		var c := glac9
		glac9 = -1
		if (fields[c] as FieldData).kind == FieldData.ICE and gsize9(c) >= A:
			for g in glacier_threat9(c):
				var fd: FieldData = fields[int(g)]
				var k: int = fd.kind
				_fall9(fd, FieldData.ICE, "ice", ev)
				st9["frozen"] = int(st9["frozen"]) + 1
				_ev9(ev, "freeze", {"type": "freeze", "crater": c, "field": fd.id, "from": k, "kind": FieldData.ICE})
			st9["freezes"] = int(st9["freezes"]) + 1
			for g in members9(c):
				glac_rest9[int(g)] = int(glacier9["rest"]) + 1
		else:
			_ev9(ev, "glacier_calm", {"type": "glacier_calm", "crater": c})
		return
	var best := -1
	var best_s := -1
	var best_n := -1
	for f in fields:
		if f.kind != FieldData.ICE or int(glac_rest9[f.id]) != 0 or gsize9(f.id) < A:
			continue
		var n := 0
		for g in nb9(f.id):
			if (fields[g] as FieldData).kind == FieldData.ICE:
				n += 1
		var sz := gsize9(f.id)
		if sz > best_s or (sz == best_s and (n > best_n or (n == best_n and f.id < best))):
			best = f.id
			best_s = sz
			best_n = n
	if best >= 0:
		glac9 = best
		st9["glac_warns"] = int(st9["glac_warns"]) + 1
		_ev9(ev, "glacier_warn", {"type": "glacier_warn", "crater": glac9, "field": glac9, "fields": members9(glac9),
			"threat": glacier_threat9(glac9)})


## Einschlag (4.3, nur Level „Einschlag“): am Ende der Runde at wird jedes Feld einer kill-Art zur genannten Art (die
## Saurier werden Asche = Erde). Nie ein Verlust (das Ziel zählt Wiesen), gezeigt und erklärt, von Anfang an gewarnt.
func _impact_step9(ev: Array) -> void:
	if impact_done9 or twists != int(impact9["at"]):
		return
	impact_done9 = true
	var kill: Dictionary = impact9["kill"]
	var hit: Array = []
	var from := {}
	for f in fields:
		if kill.has(f.kind):
			from[f.id] = f.kind
			_fall9(f, int(kill[f.kind]), "impact", ev)
			hit.append(f.id)
	st9["impact"] = hit.size()
	_ev9(ev, "impact", {"type": "impact", "fields": hit, "from": from, "kind": FieldData.EMPTY})


## Steht der Einschlag noch bevor? (Level „Einschlag“ vor der ersten Drehung: Warnung, Zeile „Dreh, der Meteor kommt“)
func impact_pending9() -> bool:
	return camp and not impact9.is_empty() and not impact_done9


func _smog_step9(ev: Array) -> void:
	var old := smog_warn9
	smog_warn9 = {}
	var ks: Array = old.keys()
	ks.sort()
	for i in ks:
		var f: FieldData = fields[int(i)]
		var ind: FieldData = fields[int(old[i])]
		if ind.kind == FieldData.INDUSTRY and SMOG_DOWN9.has(f.kind) and nb9(ind.id).has(f.id):
			var k: int = f.kind
			_fall9(f, int(SMOG_DOWN9[k]), "smog", ev)
			st9["smogged"] = int(st9["smogged"]) + 1
			_ev9(ev, "smog", {"type": "polluted", "industry": ind.id, "field": f.id, "from": k, "kind": f.kind})
	for f in fields:
		if f.kind != FieldData.INDUSTRY:
			continue
		var best_g := -1
		for g in nb9(f.id):
			var k: int = (fields[g] as FieldData).kind
			if SMOG_T9.has(k) and not smog_warn9.has(g):
				if best_g < 0 or int(SMOG_T9[k]) > int(SMOG_T9[(fields[best_g] as FieldData).kind]):
					best_g = g
		if best_g >= 0:
			smog_warn9[best_g] = f.id
			_ev9(ev, "smog_warn", {"type": "smog_warn", "industry": f.id, "field": best_g})


## Stadt-Gewicht einer Seite (Dorf 1, Stadt 2, Industrie 2): ab 5 steigt das Meer.
func city_weight9(fc: int) -> int:
	var w := 0
	for i in face_ids9(fc):
		w += int(CITY_W9.get((fields[int(i)] as FieldData).kind, 0))
	return w


func _flood_step9(ev: Array) -> void:
	var over := {}
	for fc in 6:
		if city_weight9(fc) >= int(B9["FLOOD_AT"]):
			over[fc] = true
	for fc in 6:
		if not (over.has(fc) and flood_warn.has(fc)):
			continue
		var hit: Array = []
		for i in face_ids9(fc):
			var g: FieldData = fields[int(i)]
			if LOW9.has(g.kind) and wet9(g.id):
				hit.append(g)
		for g in hit:
			var fd: FieldData = g
			var k: int = fd.kind
			_fall9(fd, FieldData.WATER, "flood", ev)
			st9["flooded"] = int(st9["flooded"]) + 1
			_ev9(ev, "flood", {"type": "flood", "face": fc, "field": fd.id, "from": k, "kind": FieldData.WATER})
		st9["floods"] = int(st9["floods"]) + 1
	flood_warn = over
	for fc in 6:
		if over.has(fc):
			_ev9(ev, "flood_warn", {"type": "flood_warn", "face": fc, "fields": face_ids9(fc)})


func church_touch9() -> Array:
	var out: Array = []
	for f in fields:
		if f.kind != FieldData.CHURCH:
			continue
		if _next_to9(f.id, FieldData.CHURCH):
			out.append(f.id)
	return out


func _war_step9(ev: Array) -> void:
	var ch := church_touch9()
	if ch.is_empty():
		if war_on:
			_ev9(ev, "war_end", {"type": "war_end"})
		war_on = false
		front = {}
		return
	var base := {}
	for i in ch:
		for g in nb9(int(i)):
			if LEVEL9.has((fields[g] as FieldData).kind):
				base[g] = true
	if not war_on:
		war_on = true
		front = base.duplicate()
		st9["wars"] = int(st9["wars"]) + 1
		var fr: Array = base.keys()
		fr.sort()
		_ev9(ev, "war_start", {"type": "war_start", "churches": ch, "front": fr})
		return
	var hit: Array = []
	for i in front:
		if LEVEL9.has((fields[int(i)] as FieldData).kind):
			hit.append(int(i))
	hit.sort()
	for i in hit:
		var f: FieldData = fields[int(i)]
		var k: int = f.kind
		_fall9(f, int(WAR_DOWN9[k]), "war", ev)
		st9["war_hits"] = int(st9["war_hits"]) + 1
		_ev9(ev, "war_hit", {"type": "war_hit", "field": f.id, "from": k, "kind": f.kind})
	var grow := base.duplicate()
	for i in front:
		for g in nb9(int(i)):
			if LEVEL9.has((fields[g] as FieldData).kind):
				grow[g] = true
	var nf := {}
	for i in front:
		if LEVEL9.has((fields[int(i)] as FieldData).kind):
			nf[int(i)] = true
	for i in grow:
		if LEVEL9.has((fields[int(i)] as FieldData).kind):
			nf[int(i)] = true
	front = nf


# --- Die Runde ------------------------------------------------------------------------------

func _end_round9(ans: Dictionary) -> Dictionary:
	_open_turn()
	answers = ans.duplicate()
	trace9 = []
	var twist := _rotated
	var ev: Array = _pre_ev.duplicate(true)
	_pre_ev = []
	var p0 := sub_values9()
	var faith_before := faith
	_resolve_merges9(ev)
	moved = {}
	tapped = -1
	var got := {"rain": 0, "bolt": 0, "monsoon": 0}
	var income := 0
	var kinds0 := PackedInt32Array()
	if twist and not engine9_mode:
		for f in fields:
			kinds0.append(f.kind)
	if twist:
		twists += 1
		for f in fields:
			if f.fresh > 0:
				f.fresh -= 1
		if bool(sys9["impact"]):
			_impact_step9(ev)
		_fire_step9(ev)
		if bool(sys9["bolt"]):
			_bolt_step9(ev)
		if bool(sys9["volcano"]):
			_volcano_step9(ev)
		if bool(sys9["glacier"]):
			_glacier_step9(ev)
		if bool(sys9["smog"]):
			_smog_step9(ev)
		if bool(sys9["flood"]):
			_flood_step9(ev)
		if bool(sys9["war"]):
			_war_step9(ev)
		if bool(sys9["pack"]):
			_pack_step9(ev)
		_thrive_step9(ev)
		if bool(sys9["faith"]):
			for f in fields:
				if LEVEL9.has(f.kind) and int(LEVEL9[f.kind]) > f.flvl and _next_to9(f.id, FieldData.CHURCH):
					f.flvl = int(LEVEL9[f.kind])
					income += int(B9["FAITH_STEP"])
			faith += income
			if income > 0:
				faith_earned += income
				ev.append({"type": "income", "faith": income})
			while faith >= int(B9["METEOR_FAITH"]):
				faith -= int(B9["METEOR_FAITH"])
				meteors += 1
				_ev9(ev, "meteor_ready", {"type": "meteor_ready", "meteors": meteors})
		# Build 12: Reihen, die die Welt am Rundenende bildet (Abkühlen, Ausbruch, Landgang, Hunger, Smog …), wachsen
		# sofort. So steht nie eine Reihe da, die nicht zählt (früher: „3 Felsen in einer Reihe … nichts passiert“).
		if not engine9_mode:
			var ch := {}
			for f in fields:
				if f.kind != kinds0[f.id]:
					ch[f.id] = true
			if not ch.is_empty():
				_resolve_merges9(ev, true, ch)
		if rain_every > 0 and twists % rain_every == 0:
			var r0 := rain
			rain = mini(int(B9["RAIN_MAX"]), rain + 1)
			if rain > r0:
				got["rain"] = 1
		if rain_every > 0:
			next_rain = (twists / rain_every + 1) * rain_every
	broken = _broke_now if _rotated else {}
	_broke_now = {}
	_rotated = false
	_check_goal9(ev, true)
	_tail9(ev, p0)
	if twist and _grew == 0:
		var note := false
		for e in ev:
			if _EV8_NOTE.has(str(e["type"])) or ["need_sealed", "steam", "spawn", "erupt", "volcano_warn",
					"pack_warn", "pack_hunt", "smog_warn", "hunger_warn", "goal_loss", "level_progress", "mercy",
					"meteor_ready"].has(str(e["type"])):
				note = true
		if not note:
			var mid_id: int = int(last_row[1]) if last_row.size() == 3 else -1
			ev.append({"type": "miss", "count": 0, "field": mid_id, "why": _miss_why(ev), "counted": false})
	return _close9(ev, got, faith - faith_before, income)


## Werkzeug (kein Schritt): Regen auf ein Feld (Regen-Tabelle des Levels, löscht Feuer, hebt die Blitz-Warnung auf)
## oder Meteor (ein Feld wird Erde). bought: ein gekauftes Wunder aus dem Vorrat (zählt MIRACLE_STEPS Schritte).
## Blitzschutz aus dem Laden: die nächsten 5 Runden kein Blitz; eine Warnung erlischt. Zählt im Level 2 Schritte, je
## Level einmal. false, wenn es hier keinen Blitz gibt oder er schon benutzt wurde.
func guard_bolt9() -> bool:
	if not camp or not bool(sys9.get("bolt", false)) or miracle_bought.has("guard"):
		return false
	miracle_bought["guard"] = true
	if not day_won:
		extra_steps += MIRACLE_STEPS
	bolt_guard9 = 5
	bolt = -1
	return true


func _play_tool9(kind: String, fid: int, bought: bool) -> Dictionary:
	var f: FieldData = fields[fid]
	var t := "meteor" if kind == "strike" else kind
	var legal := rain_ok9(f, bought) if t == "rain" else meteor_ok9(f, bought)
	if not legal:
		return {"events": [], "gain": 0, "faith": 0, "income": 0, "loss": 0, "grew": 0, "card": -1, "card_field": -1,
			"bonus_gained": {}, "new_age": false, "w": 0, "zone": "ok", "completed": false, "day": day_status(),
			"trace": [], "refused": true, "bonus": {"kind": kind, "field": fid, "fields": [], "stages": {}}}
	_open_turn()
	trace9 = []
	var ev: Array = []
	var p0 := sub_values9()
	if bought:
		miracle_bought[t] = true
		if not day_won:
			extra_steps += MIRACLE_STEPS
		ev.append({"type": "bought_miracle", "kind": t, "steps": MIRACLE_STEPS if not day_won else 0})
	if t == "rain":
		_remember_before()
		if not bought:
			rain -= 1
		st9["rains"] = int(st9["rains"]) + 1
		stats["rains"] = int(stats["rains"]) + 1
		if f.id == bolt and not f.burning:
			bolt = -1
			_ev9(ev, "bolt_cancel", {"type": "bolt_cancel", "field": f.id})
		elif f.burning:
			for i in face_ids9(face_index(f)):
				var g: FieldData = fields[int(i)]
				if g.burning:
					g.burning = false
					_ev9(ev, "rain_out", {"type": "rain_out", "field": g.id})
		else:
			var nk := rain_to9(f)
			var k: int = f.kind
			tapped = f.id
			_rise9(f, nk)
			if f.id == volc and nk != FieldData.LAVA:
				volc = -1
			moved[f.id] = true
			_ev9(ev, "rain", {"type": "rain", "field": f.id, "from": k, "kind": nk})
		_resolve_merges9(ev)
		moved = {}
		tapped = -1
		_seal_step9(ev)          # versorgt bleibt versorgt: auch was ein Regen versorgt, wird gleich versiegelt
		_check_goal9(ev, false)
	else:
		if not bought:
			meteors -= 1
		st9["meteors"] = int(st9["meteors"]) + 1
		stats["strikes"] = int(stats["strikes"]) + 1
		var k2: int = f.kind
		if not engine9_mode:
			_remember_before()
		if f.id == glac9:
			glac9 = -1
		_fall9(f, FieldData.EMPTY, "meteor", ev)
		f.fresh = 0
		if f.id == bolt:
			bolt = -1
		_ev9(ev, "meteor", {"type": "meteor", "field": f.id, "from": k2, "kind": FieldData.EMPTY, "cost": 0})
		if kind == "strike":
			ev.append({"type": "strike", "field": f.id, "hit": [{"field": f.id, "from": k2, "kind": FieldData.EMPTY}],
				"cost": 0, "faith": 0, "meteor": true})
		if not engine9_mode:
			# Build 12: eine Reihe, die der Meteor schließt (3 Erde), wächst sofort
			moved[f.id] = true
			_resolve_merges9(ev)
			moved = {}
		_seal_step9(ev)
		_check_goal9(ev, false)
	_tail9(ev, p0)
	var res := _close9(ev, {"rain": 0, "bolt": 0, "monsoon": 0}, 0, 0)
	turn -= 1
	res["bonus"] = {"kind": kind, "field": fid, "fields": [fid], "stages": {fid: f.kind}}
	return res


## Nach jeder Aktion: satt neu/verloren, Fortschritt je Teilziel, Ruhe, Sieg, Extra-Aufgaben im Weiterbauen.
func _tail9(ev: Array, p0: Array) -> void:
	var now := {}
	for i in satt_ids9():
		now[int(i)] = true
	for i in now:
		if not _satt0.has(i):
			var fk: int = (fields[int(i)] as FieldData).kind
			ev.append({"type": "satt_new", "field": int(i), "kind": fk, "goal": _satt_goal_kind9(fk)})
	for i in _satt0:
		if not now.has(i):
			var f: FieldData = fields[int(i)]
			ev.append({"type": "satt_lost", "field": int(i), "kind": f.kind, "missing": need_state9(f)["missing"],
				"burning": f.burning, "front": front.has(f.id)})
	_satt0 = now
	if day_free_build:
		for i in goal9.size():
			var sub: Dictionary = goal9[i]
			if str(sub["type"]) == "hold":
				var okh := _hold_ok9(sub)
				held9[i] = int(held9[i]) + 1 if okh else 0
	var p1 := sub_values9()
	for i in p1.size():
		if int(p1[i]) != int(p0[i]):
			var sub2: Dictionary = goal9[i]
			ev.append({"type": "level_progress", "sub": i, "value": int(p1[i]), "target": int(sub2["target"]),
				"delta": int(p1[i]) - int(p0[i]), "kind": int(sub2.get("kind", -1))})
			if str(sub2["type"]) == "hold":
				ev.append({"type": "hold", "rounds": int(p1[i]), "target": int(sub2["target"]), "ok": int(p1[i]) > int(p0[i])})
	var gp := goal_progress()
	if gp != _goal0:
		ev.append({"type": "goal", "progress": gp, "was": _goal0, "target": goal_target(), "met": goal_met()})
		_goal0 = gp
	if day_won and not _won_told:
		_won_told = true
		ev.append({"type": "day_won", "day": level_no, "level": level_no, "twists": used_twists(), "steps": day_won_at,
			"stars": stars(), "points": level_points()})
	if day_free_build:
		while extra_level < extra_max() and _extra_met9(extra_level + 1):
			extra_level += 1
			ev.append({"type": "extra", "level": extra_level, "target": extra_target(), "max": extra_max(),
				"done": extra_level >= extra_max(), "text": extra_text9(extra_level + 1)})
	for f in fields:
		ever[f.kind] = true
	var er := era9()
	var ek := _era_key9(er)
	if ek != _era_last:
		_era_last = ek
		er["type"] = "era"
		ev.append(er)


static func _era_key9(e: Dictionary) -> String:
	return "%d|%.2f|%d|%s|%.2f|%.2f" % [int(e.get("act", 0)), float(e.get("sky_blue", 0.0)), int(e.get("life", 0)),
		str(e.get("era", "")), float(e.get("dust_clear", 0.0)), float(e.get("smog", 0.0))]


func _close9(ev: Array, got: Dictionary, delta: int, income: int) -> Dictionary:
	last_grew = _grew
	_turn_open = false
	_eq0 = {}
	_church0 = {}
	_pre_gain = 0
	moved = {}
	tapped = -1
	turn += 1
	return {"events": ev, "gain": 0, "faith": delta, "income": income, "loss": 0, "grew": _grew, "card": -1,
		"card_field": -1, "bonus_gained": got, "new_age": false, "w": 0, "zone": "ok", "completed": false,
		"day": day_status(), "trace": trace9.duplicate()}


# --- Ziel, Gnade, Sterne, Punkte (3.7, 3.9) ---------------------------------------------------

## Schritte, die für Sterne und Punkte zählen: Drehungen + 2 je gekauftem Wunder.
func steps9() -> int:
	return maxi(0, twists - gift_twists) + extra_steps      # die Vorführung von Level 1 kostet keinen Schritt


func sub_progress9(sub: Dictionary) -> int:
	var t := str(sub["type"])
	if t == "make":
		var c := 0
		for k in sub["kinds"]:
			c += int(made[int(k)]) - int(lost9[int(k)])
		return c
	if t == "satt":
		var n := 0
		var k2 := int(sub["kind"])
		for f in fields:
			if f.kind == k2 and satt9(f.id):
				n += 1
		return n
	if t == "group":
		return biggest9(int(sub["kind"]))
	return 0


## Fortschritt je Teilziel (hold: Runden in Folge).
func sub_values9() -> Array:
	var out: Array = []
	for i in goal9.size():
		var sub: Dictionary = goal9[i]
		out.append(int(held9[i]) if str(sub["type"]) == "hold" else sub_progress9(sub))
	return out


func _sub_met9(i: int) -> bool:
	var sub: Dictionary = goal9[i]
	if str(sub["type"]) == "hold":
		return int(held9[i]) >= int(sub["target"])
	return sub_progress9(sub) >= int(sub["target"])


func _hold_ok9(sub: Dictionary) -> bool:
	for x in sub["subs"]:
		if sub_progress9(x) < int((x as Dictionary)["target"]):
			return false
	for t in trace9:
		if DAMAGE9.has(str(t)):
			return false
	return true


## Summe über die Teilziele von min(Fortschritt, Ziel).
func progress9() -> int:
	var p := 0
	var vals := sub_values9()
	for i in goal9.size():
		p += mini(int(vals[i]), int((goal9[i] as Dictionary)["target"]))
	return p


func target9() -> int:
	var t := 0
	for sub in goal9:
		t += int((sub as Dictionary)["target"])
	return t


func _check_goal9(ev: Array, round_end: bool) -> void:
	if day_won:
		return
	if round_end:
		for i in goal9.size():
			var sub: Dictionary = goal9[i]
			if str(sub["type"]) == "hold":
				held9[i] = int(held9[i]) + 1 if _hold_ok9(sub) else 0
	var p := progress9()
	var s := steps9()
	if p > peak9:
		gain_at9 = s
	peak9 = maxi(peak9, p)
	# Gnade (keine Sackgasse): ab der ★-Zone alle 3 Schritte ohne neuen Fortschritt +1 Regen/Wunder
	var me := int(B9["MERCY_EVERY"])
	if round_end and bool(sys9.get("mercy", true)) and s > int(stars9[1]) and rain < int(B9["RAIN_MAX"]) \
			and s - gain_at9 >= me and (s - gain_at9) % me == 0:
		rain += 1
		st9["mercy"] = int(st9["mercy"]) + 1
		_ev9(ev, "mercy", {"type": "mercy", "rain": rain})
	var all_met := not goal9.is_empty()
	for i in goal9.size():
		if not _sub_met9(i):
			all_met = false
	if all_met:
		day_won = true
		day_won_at = s


## Gnade greift gerade (★-Zone, mindestens 3 Schritte ohne Fortschritt): der Rettungs-Tipp ist gratis.
func rescue() -> bool:
	return camp and not day_won and steps9() > int(stars9[1]) and steps9() - gain_at9 >= int(B9["MERCY_EVERY"])


static func stars_for9(st: Array, steps: int) -> int:
	if steps <= int(st[0]):
		return 3
	if steps <= int(st[1]):
		return 2
	return 1


## Punkte eines Levels (GDPD_PUNKTE_LADEN.md 2.1): 30 + 10 × Sterne + 5 × max(0, Par − Schritte).
static func points_for9(stars_n: int, steps: int, par: int) -> int:
	if stars_n <= 0:
		return 0
	return Balance.LEVEL_DONE + Balance.LEVEL_PER_STAR * stars_n + Balance.LEVEL_FAST * maxi(0, par - steps)


func level_points() -> int:
	if not day_won:
		return 0
	return points_for9(stars(), day_won_at, par9)


## Die nächste Sterne-Grenze für den Ring im HUD: [Sterne, bis Schritt] oder [] (nur noch ★).
func next_star_line() -> Array:
	var s := steps9()
	if s < int(stars9[0]):
		return [3, int(stars9[0])]
	if s < int(stars9[1]):
		return [2, int(stars9[1])]
	return []


func _satt_goal_kind9(k: int) -> bool:
	for sub in goal9:
		var sd: Dictionary = sub
		var subs: Array = sd["subs"] if str(sd["type"]) == "hold" else [sd]
		for x in subs:
			if str((x as Dictionary)["type"]) == "satt" and int((x as Dictionary)["kind"]) == k:
				return true
	return false


## Weiterbauen (7): Extra-Aufgaben. make/group: Ziel + 2, dann + 4; satt: + 1, dann + 2; hold: + 2, dann + 4 Runden.
func extra_max9() -> int:
	return 2


func _extra_add9(sub: Dictionary, n: int) -> int:
	var t := str(sub["type"])
	if t == "satt":
		return n
	return 2 * n


func _extra_met9(n: int) -> bool:
	var vals := sub_values9()
	for i in goal9.size():
		var sub: Dictionary = goal9[i]
		if int(vals[i]) < int(sub["target"]) + _extra_add9(sub, n):
			return false
	return true


func extra_text9(n: int) -> String:
	if n > extra_max9():
		return "Bau weiter"
	var sub: Dictionary = goal9[0] if not goal9.is_empty() else {}
	if sub.is_empty():
		return "Bau weiter"
	return "Extra: %s" % Campaign.chip_text(level_no, int(sub["target"]) + _extra_add9(sub, n))


# --- Werkzeuge -------------------------------------------------------------------------------

## Was Regen aus diesem Feld macht (-1: nichts). Erste passende Zeile der Regen-Tabelle des Levels.
func rain_to9(f: FieldData) -> int:
	for item in rain9:
		var it: Array = item
		if int(it[0]) != f.kind:
			continue
		var cv: Variant = it[1]
		if cv is int:
			if not _next_to9(f.id, int(cv)):
				continue            # „Regen lockt Saurier/Tiere“: nur neben dieser Art (GDPD_ERDGESCHICHTE.md 4.4)
			return int(it[2])
		var cond := str(cv)
		if cond == "shore":
			var any_land := false
			for g in nb9(f.id):
				if not FieldData.water_family((fields[g] as FieldData).kind):
					any_land = true
			if not any_land:
				continue
		elif cond == "people":
			var pe := false
			for g in nb9(f.id):
				if PEOPLE9.has((fields[g] as FieldData).kind):
					pe = true
			if not pe:
				continue
		elif cond == "nopeople":
			var pe2 := false
			for g in nb9(f.id):
				if PEOPLE9.has((fields[g] as FieldData).kind):
					pe2 = true
			if pe2:
				continue
		elif cond == "sun":
			if face_index(f) != SUN_FACE:
				continue
		elif cond == "meadow":
			if not _next_to9(f.id, FieldData.MEADOW):
				continue
		return int(it[2])
	return -1


func rain_ok9(f: FieldData, bought: bool = false) -> bool:
	if not bought and rain <= 0:
		return false
	if bought and miracle_bought.has("rain"):
		return false
	return f.burning or f.id == bolt or rain_to9(f) >= 0


func meteor_ok9(f: FieldData, bought: bool = false) -> bool:
	if not bought and meteors <= 0:
		return false
	if bought and miracle_bought.has("meteor"):
		return false
	return not FieldData.water_family(f.kind)


## Gibt es dieses Werkzeug in diesem Level (Regen ab Level 2 mit Dampf/Wolken, Meteor ab Level 23)?
func tool_in_level9(kind: String) -> bool:
	if kind == "rain":
		return not rain9.is_empty()
	if kind == "meteor" or kind == "strike":
		return int(day.get("meteor_start", 0)) > 0 or bool(sys9.get("faith", false))
	return false


func _can_bonus9(kind: String, f: FieldData) -> String:
	if kind == "rain":
		if rain <= 0:
			return "Noch kein Regen." if rain_every <= 0 else "Regen in %d Drehungen." % maxi(1, next_rain - twists)
		if not rain_ok9(f):
			return "Hier wirkt kein Regen."
		return ""
	if kind == "meteor" or kind == "strike":
		if meteors <= 0:
			return "Kein Meteor bereit."
		if FieldData.water_family(f.kind):
			return "Nicht auf Wasser."
		return ""
	return "Heute nicht."


# --- Anzeige ---------------------------------------------------------------------------------

## Zustand eines Felds für Felder-Ansicht und HUD (Vertrag 11).
func field_state9(f: FieldData) -> Dictionary:
	var ns := need_state9(f)
	var r: Variant = thrive9.get(f.kind)
	var dn := int((r as Dictionary)["down"]) if r != null else -1
	var up := int((r as Dictionary)["up"]) if r != null else -1
	var wait := false
	if r != null and up >= 0 and LEVEL9.has(f.kind) and f.fed >= int((r as Dictionary)["G"]) and satt9(f.id):
		wait = not up_ok9(f.id, up)
	return {"thriver": r != null, "people": LEVEL9.has(f.kind), "living": FieldData.LIVING.has(f.kind),
		"satt": satt9(f.id), "met": ns["met"], "sealed": ns["sealed"], "missing": ns["missing"], "have": ns["have"],
		"fed": f.fed, "hungry": f.hungry, "grow_after": int(B9["G"]), "shrink_after": int(B9["H"]) if dn >= 0 else -1,
		"up": up, "down": dn, "waits": wait,
		"grows": r != null and ((up >= 0 and not wait) or not ((r as Dictionary).get("spawn", []) as Array).is_empty()),
		"burning": f.burning, "fresh": f.fresh, "front": front.has(f.id),
		"bolt": f.id == bolt, "wet": wet9(f.id), "mk": f.mk, "group": group_id9(f.id), "size": gsize9(f.id),
		"strength": strength9(f.id), "crater": f.id == volc, "crater_rest": f.crater_rest, "dry": dry9(f.id),
		"pack": pack_warn9.has(f.id), "smog": smog_warn9.has(f.id), "sun": face_index(f) == SUN_FACE,
		"glacier": f.id == glac9, "frost": glac9 >= 0 and glacier_threat9(glac9).has(f.id),
		"glac_rest": int(glac_rest9[f.id]) if f.id < glac_rest9.size() else 0,
		"impact": impact_pending9() and (impact9["kill"] as Dictionary).has(f.kind)}


## Teilziele für den Chip: [{"type", "kind", "kinds", "value", "target", "met", "icon"}].
func sub_status9() -> Array:
	var out: Array = []
	var vals := sub_values9()
	for i in goal9.size():
		var sub: Dictionary = goal9[i]
		var k := int(sub.get("kind", -1))
		if str(sub["type"]) == "hold" and not (sub["subs"] as Array).is_empty():
			k = int(((sub["subs"] as Array)[0] as Dictionary)["kind"])
		out.append({"type": str(sub["type"]), "kind": k, "kinds": sub.get("kinds", []), "value": int(vals[i]),
			"target": int(sub["target"]), "met": _sub_met9(i), "icon": FieldData.kind_icon(maxi(0, k))})
	return out


## Das Zeitalter für die Darstellung (World.set_era, Campaign.era): "era" (Look-Schlüssel in Eras), "era_id", "act"
## (Nummer des Zeitalters), Level, sky_blue (Erstes Leben: Algen / 8), dust_clear (nach dem Einschlag: Wiesen / 10),
## life (0 totes Wasser … 3 Fische), smog (Industrie: 0,15 je Feld). Nach dem Einschlag gilt der Look "after" (Asche).
func era9() -> Dictionary:
	var e := Campaign.era(level_no)
	if str(e.get("sky_mix", "")) == "algae":
		# Dunst, bis es Algen gibt (Level 8–10); ab dem Sauerstoff-Level ein Viertel blau als Boden
		var floor_b := 0.25 if level_no >= 11 else 0.0
		e["sky_blue"] = clampf(maxf(floor_b, float(count(FieldData.ALGAE)) / 8.0), 0.0, 1.0)
	if bool(e.get("dust", false)):
		e["dust_clear"] = clampf(float(count(FieldData.MEADOW)) / 10.0, 0.0, 1.0)
		e["sky_blue"] = e["dust_clear"]       # World.set_era mischt mix_from → era mit sky_blue (Asche → Erholung)
	if impact_done9 and str(e.get("after", "")) != "":
		e["era"] = str(e["after"])
		e["look"] = str(e.get("after_look", e["after"]))
		e["impact_done"] = true
	var life := 0
	var ladder := [FieldData.CELLS, FieldData.ALGAE, FieldData.FISH, FieldData.JELLY, FieldData.TRILO]
	for i in ladder.size():
		if count(int(ladder[i])) > 0:
			life = maxi(life, mini(i + 1, 3))
	e["life"] = life
	if bool(sys9.get("smog", false)):
		e["smog"] = minf(0.6, 0.15 * float(count(FieldData.INDUSTRY)))
	return e


# --- Vorschau beim Ziehen (11, erweitert GDPD_BALANCE_2.md 4.6) --------------------------------

## Vorschau einer Drehung: v8-Schlüssel (satt_new, satt_lost, need_met, need_lost, rows, war_risk, flood_risk,
## fire_risk) plus goal_delta (je Teilziel nach der ganzen Runde, Verluste eingerechnet), volcano_risk, bolt_risk,
## pack_risk, smog_risk, hunger, merge ([[Art, Größe vorher, Größe nachher]]), sealed (versiegelte Felder, die
## nie als „satt verloren“ gelten).
func preview9(axis: int, layer: int, turns: int, post: GameState = null) -> Dictionary:
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
	for i in satt_ids9():
		before[int(i)] = true
	var after := {}
	for i in post.satt_ids9():
		after[int(i)] = true
	var sn: Array = []
	var sl: Array = []
	for i in after:
		if not before.has(i):
			sn.append(int(i))
	for i in before:
		if not after.has(i) and (post.fields[int(i)] as FieldData).kind == (fields[int(i)] as FieldData).kind:
			sl.append(int(i))
	sn.sort()
	sl.sort()
	var met := {}
	var lost := {}
	for f in t.fields:
		if not thrive9.has(f.kind):
			continue
		var a: Array = t.need_state9(f)["met"]
		var b: Array = need_state9(fields[f.id])["met"] if (fields[f.id] as FieldData).kind == f.kind else []
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
	var gd: Array = []
	var v0 := sub_values9()
	var v1 := post.sub_values9()
	for i in v0.size():
		gd.append([int(v0[i]), int(v1[i]), int((goal9[i] as Dictionary)["target"])])
	var fire: Array = []
	for f in t.fields:
		if not f.burning:
			continue
		for g in t.nb9(f.id):
			var h: FieldData = t.fields[g]
			if t.flammable9(h.kind) and not h.burning and h.fresh == 0 and not t.wet9(h.id) and not fire.has(h.id):
				fire.append(h.id)
	fire.sort()
	var bolt_risk: Array = []
	if bool(sys9["bolt"]):
		for f in t.fields:
			if f.kind == FieldData.FOREST and t.dry9(f.id) and not dry9(f.id):
				bolt_risk.append(f.id)
	var volcano_risk := -1
	if bool(sys9["volcano"]):
		volcano_risk = post.volc if post.volc >= 0 else -1
		for e in post.trace9:
			if str(e) == "erupt":
				volcano_risk = maxi(volcano_risk, 0)
	var hunger: Array = []
	for f in post.fields:
		var r: Variant = post.thrive9.get(f.kind)
		if r != null and int((r as Dictionary)["down"]) >= 0 and f.hungry >= int(B9["H"]) - 1:
			hunger.append(f.id)
	var fr: Array = []
	if bool(sys9["flood"]):
		for fc in 6:
			if t.city_weight9(fc) >= int(B9["FLOOD_AT"]):
				fr.append(fc)
	var mg: Array = []
	for k in _group_kinds9():
		var b0 := biggest9(int(k))
		var b1 := t.biggest9(int(k))
		if b0 != b1:
			mg.append([int(k), b0, b1])
	var sealed: Array = []
	for f in fields:
		if not f.best.is_empty() and satt9(f.id):
			sealed.append(f.id)
	return {"satt_new": sn, "satt_lost": sl, "need_met": met, "need_lost": lost, "rows": rws,
		"war_risk": bool(sys9["war"]) and not t.church_touch9().is_empty(), "flood_risk": fr, "fire_risk": fire,
		"goal_delta": gd, "volcano_risk": volcano_risk, "bolt_risk": bolt_risk,
		"pack_risk": bool(sys9["pack"]) and not post.pack_warn9.is_empty(),
		"glacier_risk": post.glac9 >= 0 or post.trace9.has("freeze"), "impact": impact_pending9(),
		"smog_risk": post.smog_warn9.keys(), "hunger": hunger, "merge": mg, "sealed": sealed}


## Arten, deren Gruppen für Ziel oder Angebot zählen (für die merge-Vorschau).
func _group_kinds9() -> Array:
	var out := {}
	for sub in goal9:
		var sd: Dictionary = sub
		var subs: Array = sd["subs"] if str(sd["type"]) == "hold" else [sd]
		for x in subs:
			if str((x as Dictionary)["type"]) == "group":
				out[int((x as Dictionary)["kind"])] = true
	for k in thrive9:
		var nd: Dictionary = (thrive9[k] as Dictionary)["needs"]
		for n in nd:
			for src in SOURCES9.get(str(n), []):
				out[int(src)] = true
	return out.keys()


# --- Tipp (wie der Bot „good“ des Modells, bot9.py) -------------------------------------------

func _chain_dist9() -> Dictionary:
	var targets := {}
	var subs: Array = []
	for sub in goal9:
		var sd: Dictionary = sub
		if str(sd["type"]) == "hold":
			subs.append_array(sd["subs"])
		else:
			subs.append(sd)
	for x in subs:
		var xd: Dictionary = x
		if str(xd["type"]) == "make":
			for k in xd["kinds"]:
				targets[int(k)] = true
		else:
			targets[int(xd["kind"])] = true
	var edges: Array = []
	for k in rows9:
		edges.append([int(k), int(rows9[k])])
	for k in thrive9:
		var r: Dictionary = thrive9[k]
		if int(r["up"]) >= 0:
			edges.append([int(k), int(r["up"])])
		var sp: Array = r["spawn"]
		if not sp.is_empty():
			edges.append([int(k), int(sp[1])])
			for o in sp[0]:
				edges.append([int(o), int(sp[1])])
	for item in rain9:
		edges.append([int(item[0]), int(item[2])])
	for x in subs:
		var xd: Dictionary = x
		if str(xd["type"]) != "satt":
			continue
		var r2: Variant = thrive9.get(int(xd["kind"]))
		if r2 == null:
			continue
		for n in (r2 as Dictionary)["needs"]:
			for src in SOURCES9.get(str(n), []):
				if int(src) != int(xd["kind"]):
					edges.append([int(src), int(xd["kind"])])
	var dist := {}
	for k in targets:
		dist[k] = 0
	var changed := true
	while changed:
		changed = false
		for e in edges:
			var a := int(e[0])
			var b := int(e[1])
			if dist.has(b) and not targets.has(a) and (not dist.has(a) or int(dist[a]) > int(dist[b]) + 1):
				dist[a] = int(dist[b]) + 1
				changed = true
	return dist


func _pairs9() -> float:
	var w := {}
	for k in rows9:
		var nk := int(rows9[k])
		if chain9.has(nk):
			w[int(k)] = float(_LW9.get(int(chain9[nk]) + 1, 0.1))
	if w.is_empty():
		return 0.0
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
			var k := -1
			if a == b and c != a:
				k = a
			elif a == c and b != a:
				k = a
			elif b == c and a != b:
				k = b
			if k >= 0:
				v += float(w.get(k, 0.0))
		i += 4
	return v


func _frac_met9(fid: int, rule: Dictionary) -> float:
	var tot := 0
	var got := 0
	var nd: Dictionary = rule["needs"]
	for n in nd:
		tot += int(nd[n])
		got += mini(int(nd[n]), eff9(fid, str(n)))
	return float(got) / float(tot) if tot > 0 else 1.0


func _thrive_value9(satt_kinds: Dictionary) -> float:
	var v := 0.0
	var G := int(B9["G"])
	var H := int(B9["H"])
	for f in fields:
		var k: int = f.kind
		var r: Variant = thrive9.get(k)
		if r == null:
			continue
		var rule: Dictionary = r
		var ok := satt9(f.id)
		if satt_kinds.has(k):
			v += 25.0 if ok else 10.0 * _frac_met9(f.id, rule) - 3.0 * float(f.hungry)
			if not ok and int(rule["down"]) >= 0 and f.hungry >= H - 1:
				v -= 12.0
			continue
		var prod := int(rule["up"])
		var sp: Array = rule["spawn"]
		if prod < 0 and not sp.is_empty():
			prod = int(sp[1])
		var w := 0.0
		if prod >= 0 and chain9.has(prod):
			w = float(_LW9.get(int(chain9[prod]) + 1, 0.1))
		if w > 0.0:
			if ok:
				v += w * (4.0 + 3.0 * float(mini(f.fed, G)))
			else:
				v += w * 2.0 * _frac_met9(f.id, rule)
			if LEVEL9.has(k) and ok and thrive9.has(prod):
				v += w * 3.0 * _frac_met9(f.id, thrive9[prod])
		if int(rule["down"]) >= 0 and not ok:
			v -= 3.0 * float(f.hungry) + (8.0 if f.hungry >= H - 1 else 0.0)
	return v


func _danger_value9() -> float:
	var v := 0.0
	for f in fields:
		if f.burning:
			v -= 6.0
			for x in nb9(f.id):
				var h: FieldData = fields[x]
				if flammable9(h.kind) and not h.burning and not wet9(h.id) and h.fresh == 0:
					v -= 5.0 + (10.0 if FieldData.LIVING.has(h.kind) else 0.0)
	if bolt >= 0:
		v -= 6.0
		for x in nb9(bolt):
			if flammable9((fields[x] as FieldData).kind) and not wet9(x):
				v -= 3.0
	if volc >= 0:
		var grp := {}
		for g in members9(volc):
			grp[int(g)] = true
		var near := {}
		for h in grp:
			for x in nb9(int(h)):
				if not grp.has(x) and ERUPTS9.has((fields[x] as FieldData).kind):
					near[x] = true
		var n := 0
		for x in near:
			if (fields[int(x)] as FieldData).mk or (fields[int(x)] as FieldData).kind == FieldData.STONE:
				n += 1
		v -= 10.0 + 6.0 * float(n)
	if bool(sys9["volcano"]):
		for f in fields:
			if f.kind == FieldData.LAVA and gsize9(f.id) == int(B9["VOLC_AT"]) - 1:
				v -= 0.5
	v -= 8.0 * float(pack_warn9.size())
	if not glacier9.is_empty():
		# Gletscher (wie bot10.danger_value): gewarnte Gruppe kostet, mehr je bedrohtem Ziel-, Lebe- oder satt-Ziel-Feld
		if glac9 >= 0:
			var ggrp := {}
			for g in members9(glac9):
				ggrp[int(g)] = true
			var gnear := {}
			for h in ggrp:
				for x in nb9(int(h)):
					if not ggrp.has(x) and freezable9(x):
						gnear[x] = true
			var gn := 0
			for x in gnear:
				var xf: FieldData = fields[int(x)]
				if xf.mk or FieldData.LIVING.has(xf.kind) or _satt_goal_kind9(xf.kind):
					gn += 1
			v -= 10.0 + 6.0 * float(gn)
		for f in fields:
			if f.kind == FieldData.ICE and gsize9(f.id) == int(glacier9["at"]) - 1:
				v -= 0.5
	v -= 5.0 * float(smog_warn9.size())
	if bool(sys9["war"]):
		if war_on:
			v -= 30.0
		v -= 15.0 * float(church_touch9().size())
	if bool(sys9["flood"]):
		for fc in 6:
			var cw := city_weight9(fc)
			if cw >= int(B9["FLOOD_AT"]):
				var n2 := 0
				for i in face_ids9(fc):
					var g: FieldData = fields[int(i)]
					if LOW9.has(g.kind) and wet9(g.id):
						n2 += 1
				v -= 25.0 + 10.0 * float(n2)
			elif cw == int(B9["FLOOD_AT"]) - 1:
				v -= 3.0
	return v


## Wert eines Stands für den Tipp (bot9.state_value).
func value9() -> float:
	if day_won and not day_free_build:
		return 1e6 - 1000.0 * float(twists)
	var v := 100.0 * float(progress9())
	var satt_kinds := {}
	var subs: Array = []
	for sub in goal9:
		var sd: Dictionary = sub
		if str(sd["type"]) == "hold":
			subs.append_array(sd["subs"])
		else:
			subs.append(sd)
	for x in subs:
		var xd: Dictionary = x
		var t := str(xd["type"])
		if t == "satt":
			satt_kinds[int(xd["kind"])] = true
			v += 12.0 * float(mini(count(int(xd["kind"])), int(xd["target"]) + 1))
		elif t == "group":
			var k := int(xd["kind"])
			_groups9()
			var sizes := {}
			for f in fields:
				if f.kind == k:
					sizes[_grp_lab[f.id]] = _grp_size[_grp_lab[f.id]]
			var ss: Array = sizes.values()
			ss.sort()
			ss.reverse()
			if ss.size() > 1:
				v += 15.0 * float(ss[1])
			v += 3.0 * float(count(k))
	for i in goal9.size():
		if str((goal9[i] as Dictionary)["type"]) == "hold":
			v += 60.0 * float(held9[i])
			for tt in trace9:
				if DAMAGE9.has(str(tt)):
					v -= 20.0
					break
	v += _thrive_value9(satt_kinds)
	v += _danger_value9()
	v += 2.0 * float(mini(rain, 3)) + 4.0 * float(meteors)
	return v + _pairs9()


## Die Rekord-Zeile eines Stands wie xcheck9.py (für den Abgleich mit dem Modell): eine Zeile Text.
func record9() -> String:
	var kinds := PackedStringArray()
	var pos := PackedStringArray()
	var fed := PackedStringArray()
	var hun := PackedStringArray()
	var brn := PackedStringArray()
	var frs := PackedStringArray()
	var mk := PackedStringArray()
	var cr := PackedStringArray()
	var bst := PackedStringArray()
	var grp := PackedStringArray()
	_groups9()
	var canon := {}
	for f in fields:
		if not canon.has(_grp_lab[f.id]):
			canon[_grp_lab[f.id]] = f.id
	for f in fields:
		kinds.append(str(f.kind))
		pos.append(str(slot9(f)))
		fed.append(str(f.fed))
		hun.append(str(f.hungry))
		brn.append("1" if f.burning else "0")
		frs.append(str(f.fresh))
		mk.append("1" if f.mk else "0")
		cr.append(str(f.crater_rest))
		var ks: Array = f.best.keys()
		ks.sort()
		var parts := PackedStringArray()
		for n in ks:
			parts.append("%s=%d" % [str(n), int(f.best[n])])
		bst.append("/".join(parts))
		grp.append(str(canon[_grp_lab[f.id]]))
	var pw: Array = pack_warn9.keys()
	pw.sort()
	var sw_keys: Array = smog_warn9.keys()
	sw_keys.sort()
	var sw := PackedStringArray()
	for i in sw_keys:
		sw.append("%d:%d" % [int(i), int(smog_warn9[i])])
	var fr: Array = front.keys()
	fr.sort()
	var fw: Array = flood_warn.keys()
	fw.sort()
	var md := PackedStringArray()
	var ls := PackedStringArray()
	for k in FieldData.KIND_COUNT:
		md.append(str(int(made[k])))
		ls.append(str(int(lost9[k])))
	var pr := PackedStringArray()
	for v in sub_values9():
		pr.append(str(int(v)))
	var sa := PackedStringArray()
	for i in satt_ids9():
		sa.append(str(int(i)))
	var tr := PackedStringArray()
	for e in trace9:
		tr.append(str(e))
	var out := PackedStringArray([",".join(kinds), ",".join(pos), ",".join(fed), ",".join(hun), ",".join(brn),
		",".join(frs), ",".join(mk), str(bolt), str(volc), ",".join(cr), _ids_str9(pw), ",".join(sw),
		"1" if war_on else "0", _ids_str9(fr), _ids_str9(fw), str(faith), str(meteors), str(rain), str(twists),
		"1" if day_won else "0", ",".join(md), ",".join(ls), ",".join(pr), ",".join(sa), ",".join(bst),
		",".join(grp), ",".join(tr)])
	# Erdgeschichte (xcheck10): Gletscher-Krater, Ruhe je Feld, Einschlag geschehen
	var gr := PackedStringArray()
	for v in glac_rest9:
		gr.append(str(int(v)))
	out.append(str(glac9))
	out.append(",".join(gr))
	out.append("1" if impact_done9 else "0")
	return "|".join(out)


static func _ids_str9(a: Array) -> String:
	var out := PackedStringArray()
	for v in a:
		out.append(str(int(v)))
	return ",".join(out)


## Die Welt als Brett-Text nach Plätzen (für den Spielstand: [kampagne] welt, Campaign.carry).
func slot_board9() -> String:
	_build_cache9()
	var by_slot: Array = []
	by_slot.resize(fields.size())
	for f in fields:
		by_slot[slot9(f)] = f.kind
	var s := ""
	for k in by_slot:
		s += FieldData.code_of(int(k))
	return s


func _still_why9(k: int, diag: bool, key: int) -> String:
	if _eq0.has(key):
		return "standing" if rows9.has(k) and not diag else ""
	if rows9.has(k):
		if diag:
			return "diag"
		if broken.has(key):
			return "repeat"
		if spent.has(key):
			return "spent"
		if standing.has(key):
			return "standing"
		return "other"
	if k == FieldData.WATER:
		return "water"
	if FieldData.water_family(k):
		return "water_life"
	if k == FieldData.CHURCH or k == FieldData.INDUSTRY:
		return "finished"
	if not impact9.is_empty() and (impact9["kill"] as Dictionary).has(k):
		return "dino"                 # Level „Einschlag“: Saurier sind hier keine Reihen-Art
	if k == FieldData.ICE:
		return "ice"
	if k == FieldData.CAMP:
		return "camp"
	if thrive9.has(k):
		return "people" if LEVEL9.has(k) else "thrive"
	if k == FieldData.STONE:
		return "stone"
	return "done"


## Langes Drücken auf ein Feld in einem Level: was es heute tut (kurz).
func kind_help9(k: int) -> String:
	var name := FieldData.kind_name(k)
	if rows9.has(k):
		return "%s. 3 in einer Reihe: %s." % [name, FieldData.kind_name(int(rows9[k]))]
	var r: Variant = thrive9.get(k)
	if r != null:
		var ns: Array = []
		for n in ((r as Dictionary)["needs"] as Dictionary):
			ns.append(str(NEED_NAME9.get(str(n), n)))
		var last := str(ns.pop_back())
		var list := last if ns.is_empty() else ", ".join(PackedStringArray(ns)) + " und " + last
		return "%s. Braucht %s." % [name, list]
	return str(FieldData.KIND_HELP[clampi(k, 0, FieldData.KIND_COUNT - 1)])


## Zusammenfassung für die Oberfläche (Ziel-Chip mit bis zu zwei Teilzielen, Schritte, Sterne-Ring, Gefahren).
func level_status9() -> Dictionary:
	return {"level": level_no, "day": level_no, "camp": true, "type": goal_type(), "kinds": goal_kinds(),
		"target": goal_target(), "progress": goal_progress(), "met": goal_met(), "subs": sub_status9(),
		"twists": twists, "steps": steps9(), "limit": 0, "left": -1, "won": day_won, "lost": "", "won_at": day_won_at,
		"stars": stars(), "stars_at": stars9.duplicate(), "par": par9, "points": level_points(),
		"next_star": next_star_line(), "free_build": day_free_build, "growth": build_growth(), "v8": false,
		"extra_level": extra_level, "extra_max": extra_max(), "extra_target": extra_target(),
		"extra_text": extra_text9(extra_level + 1), "needs": goal_needs(), "need_icons": goal_need_icons(),
		"bolt": bolt, "volc": volc, "pack_warn": pack_warn9.keys(), "smog_warn": smog_warn9.keys(), "war_on": war_on,
		"hunter": hunter_of9(pack_warn9.keys()) if not pack_warn9.is_empty() else -1, "glac": glac9,
		"glac_threat": glacier_threat9(glac9), "impact": impact_pending9(),
		"front": front.keys(), "flood_warn": flood_warn.keys(), "faith": faith, "rain": rain, "meteors": meteors,
		"held": held9.duplicate(), "rescue": rescue(), "no_war": false}


# =============================================================================
# Build 12: „Man soll immer genau wissen, was man tun muss“ – die nächste Handlung für die Zeile oben im HUD
# =============================================================================
# next_action() rechnet aus dem echten Brett, was jetzt zu tun ist (wenige Worte, kleine Symbole), und sagt nie etwas
# Unmögliches: Eine Drehung wird nur genannt, wenn es sie gibt (geprüft auf dem Brett), ein Werkzeug nur, wenn es
# wirkt, ein allgemeines Ziel („Bring 3 Felsen in eine Reihe“) nur, wenn genug Felder der Art auf passenden Plätzen
# liegen. Geht nichts davon, bietet sie das Sicherheitsnetz an (Game.take_gift). Billig genug für jede Runde: eine
# Vierteldrehung wird auf dem Brett selbst gedreht und zurückgedreht (keine Kopie, keine Auswertung).

## Wie ein Bedürfnis in der Zeile heißt: „Lava ans Wasser drehen“, sonst „<Art> neben <Quelle> drehen“.
const ACT_SUN9 := "in die Sonne"
var _act_seq := 0                 # zählt jede Aktion (play): die Zeile wird nur neu gerechnet, wenn sich etwas ändert


## So viele Aktionen (Drehen, Werkzeug, Geschenk) hat dieser Versuch schon (0: noch nichts getan).
func actions9() -> int:
	return _act_seq
var _act_key := ""
var _act_last: Dictionary = {}


## Die nächste Handlung (nur in einem Level, sonst {}). Schlüssel:
##   "type": "row" (Drehung macht eine Reihe) | "thrive" (Drehung versorgt ein Feld, es wächst bald) | "wait" (versorgte
##     Felder wachsen von selbst: weiterdrehen) | "rain" | "meteor" (Werkzeug auf "field") | "danger" (Drehung wendet
##     eine Gefahr ab) | "goal" (mehrere Züge: das nächste Teilziel) | "help" (Sicherheitsnetz: Game.take_gift) | "won"
##   "text": 2–6 Wörter („Dreh 3 Felsen in eine Reihe“) · "line": text + „ → Art“ (wenn "result" ≥ 0)
##   "icons": Symbol-Namen davor (Arten/Bedürfnisse) · "result": Art, die entsteht (-1: keine) · "result_icon"
##   "move": {"axis", "layer", "turns"} (die Scheibe, die nach einer Pause sanft leuchten darf) oder {}
##   "fields": Feld-IDs, um die es geht (leuchten, wenn es keinen move gibt) · "tool": "rain" | "meteor" | "gift" | ""
##   "field": Ziel-Feld des Werkzeugs (-1) · "danger": "volcano" | "bolt" | "fire" | "pack" | "hunger" | "smog" |
##     "war" | "flood" | "" · "steps": 1 (diese Drehung wirkt sofort) oder 2 (Vorbereitung) · "hint": kurzer
##     Versorgungs-Satz zum Ziel („Tiere brauchen Pflanzen: 2/6 versorgt“) oder "".
func next_action() -> Dictionary:
	if not camp:
		return {}
	var key := "%d|%d|%d|%d|%d|%d|%d" % [_act_seq, rain, meteors, extra_steps, twists, turn, 1 if day_won else 0]
	if key != _act_key:
		_act_last = _next_action9()
		_act_key = key
	return _act_last.duplicate(true)


func _act9(type: String, text: String, icons: Array, result: int) -> Dictionary:
	var line := text
	if result >= 0:
		line += " → " + FieldData.kind_name(result)
	return {"type": type, "text": text, "line": line, "icons": icons, "result": result,
		"result_icon": FieldData.kind_icon(result) if result >= 0 else "", "move": {}, "fields": [], "tool": "",
		"field": -1, "danger": "", "steps": 1, "hint": ""}


## Vierteldrehung nur der Plätze (für next_action): kein Zug, keine Auswertung. turns = -turns dreht zurück.
func _rot9(axis: int, layer: int, turns: int) -> void:
	var d := 1 if turns > 0 else -1
	var n := absi(turns)
	for f in fields:
		if f.p[axis] == layer:
			for i in n:
				f.p = rv(f.p, axis, d)
				f.n = rv(f.n, axis, d)
			_index[pos_key(f.p, f.n)] = f
	_nb_ok = false
	_grp_ok = false


## Lohnt eine Art für das Ziel? Abstand zur Ziel-Art (0 = Ziel-Art), -1 = gehört nicht zur Kette.
func _act_dist9(k: int) -> int:
	return int(chain9[k]) if chain9.has(k) else -1


## Wert einer neuen Art (für die Wahl der Drehung): 10 für die Ziel-Art, weniger, je weiter weg; 0 = hilft nicht.
## Wächst ein Feld in die Art des Teilziels, an dem gerade gearbeitet wird, zählt das voll – auch wenn es selbst eine
## Ziel-Art ist (Level „Frieden“: Dorf → Stadt, obwohl beide Ziel-Arten mit Abstand 0 sind).
func _act_val9(from: int, to: int) -> float:
	if to == _act_gk9 and from != to:
		return 10.0
	var dt := _act_dist9(to)
	if dt < 0:
		return 0.0
	var df := _act_dist9(from)
	if df >= 0 and dt >= df:
		return 0.0
	return maxf(1.0, 10.0 - 2.0 * float(dt))


## Wohin ein versorgtes Feld wächst (Gedeihen: up, Landgang: die neue Art), -1 = nirgendwohin.
func _act_up9(k: int) -> int:
	var r: Variant = thrive9.get(k)
	if r == null:
		return -1
	if int((r as Dictionary)["up"]) >= 0:
		return int((r as Dictionary)["up"])
	var sp: Array = (r as Dictionary)["spawn"]
	return int(sp[1]) if not sp.is_empty() else -1


## Das Teilziel, an dem gerade gearbeitet wird (das erste offene; Ruhe: das erste offene darin). {} = alle erfüllt.
func _act_goal9() -> Dictionary:
	for i in goal9.size():
		if _sub_met9(i):
			continue
		var sd: Dictionary = goal9[i]
		if str(sd["type"]) == "hold":
			for x in sd["subs"]:
				if sub_progress9(x) < int((x as Dictionary)["target"]):
					return x
			return sd
		return sd
	return {}


## Ist dieses satt-Ziel-Feld gemeint (Art eines offenen satt-Ziels)?
func _act_satt_goal9(k: int) -> bool:
	var g := _act_goal9()
	return not g.is_empty() and str(g["type"]) == "satt" and int(g["kind"]) == k


## Laufende Gefahren mit einer Abhilfe durch Drehen: [{"type", "fields"}]. Feuer hilft nur Regen (siehe unten).
func _act_threats9() -> Array:
	var out: Array = []
	if volc >= 0 and (fields[volc] as FieldData).kind == FieldData.LAVA:
		out.append({"type": "volcano", "fields": members9(volc)})
	if bolt >= 0 and bolt_guard9 <= 0:
		out.append({"type": "bolt", "fields": members9(bolt)})
	if not pack_warn9.is_empty():
		out.append({"type": "pack", "fields": pack_warn9.keys()})
	if glac9 >= 0 and (fields[glac9] as FieldData).kind == FieldData.ICE:
		var gf := members9(glac9)
		gf.append_array(glacier_threat9(glac9))
		out.append({"type": "glacier", "fields": gf})
	var hungry: Array = []
	for f in fields:
		var r: Variant = thrive9.get(f.kind)
		if r != null and int((r as Dictionary)["down"]) >= 0 and f.hungry >= int(B9["H"]) - 1:
			hungry.append(f.id)
	if not hungry.is_empty():
		out.append({"type": "hunger", "fields": hungry})
	if not smog_warn9.is_empty():
		out.append({"type": "smog", "fields": smog_warn9.keys()})
	if bool(sys9.get("war", false)) and not church_touch9().is_empty():
		out.append({"type": "war", "fields": church_touch9()})
	if not flood_warn.is_empty():
		var fl: Array = []
		for fc in flood_warn:
			fl.append_array(face_ids9(int(fc)))
		out.append({"type": "flood", "fields": fl})
	var open: Array = []
	for t in out:
		if not _act_fixed9(t):
			open.append(t)          # nur, was ohne Zutun wirklich eintritt
	return open


## Ist diese Gefahr auf dem jetzigen (gedrehten) Brett abgewendet?
func _act_fixed9(t: Dictionary) -> bool:
	var tp := str(t["type"])
	if tp == "volcano":
		return (fields[volc] as FieldData).kind != FieldData.LAVA or gsize9(volc) < int(B9["VOLC_AT"])
	if tp == "bolt":
		return not dry9(bolt)
	if tp == "pack":
		var now := hunt_targets9()
		for i in pack_warn9:
			if now.has(int(i)):
				return false
		return true
	if tp == "glacier":
		return (fields[glac9] as FieldData).kind != FieldData.ICE or gsize9(glac9) < int(glacier9["at"])
	if tp == "hunger":
		for i in t["fields"]:
			if not satt9(int(i)):
				return false
		return true
	if tp == "smog":
		for i in smog_warn9:
			if nb9(int(smog_warn9[i])).has(int(i)):
				return false
		return true
	if tp == "war":
		return church_touch9().is_empty()
	if tp == "flood":
		for fc in flood_warn:
			if city_weight9(int(fc)) >= int(B9["FLOOD_AT"]):
				return false
		return true
	return false


## Was eine Drehung auf dem jetzigen Brett bringt (das Brett ist schon gedreht; ids = die bewegten Felder).
## {"score", "rows": [[Art, [3 IDs], neue Art]], "satt": [[ID, Art, wird]], "group": +n, "fix": [Gefahr-Typen]}
func _act_score9(ids: Dictionary, stand: Dictionary, cands: Array, grp: Array, threats: Array) -> Dictionary:
	var sc := 0.0
	var rws: Array = []
	for ln in lines(ids):
		var lk := line_key(ln)
		if stand.has(lk) or broken.has(lk) or spent.has(lk):
			continue
		var k: int = (ln[0] as FieldData).kind
		var nk := int(rows9.get(k, k))
		var v := _act_val9(k, nk)
		if nk == k or v <= 0.0:
			continue
		sc += v
		rws.append([k, [(ln[0] as FieldData).id, (ln[1] as FieldData).id, (ln[2] as FieldData).id], nk])
	var st: Array = []
	for fid in cands:
		var f: FieldData = fields[int(fid)]
		if not satt9(f.id):
			continue
		var up := _act_up9(f.kind)
		var v2 := 9.0 if _act_satt_goal9(f.kind) else (_act_val9(f.kind, up) * 0.7 if up >= 0 else 0.0)
		if v2 > 0.0:
			sc += v2
			st.append([f.id, f.kind, up])
	var gd := 0
	if not grp.is_empty():
		gd = biggest9(int(grp[0])) - int(grp[1])
		if gd > 0:
			sc += 8.0 * float(gd)
	var fx: Array = []
	var herd := false
	for t in threats:
		if _act_fixed9(t):
			fx.append(str((t as Dictionary)["type"]))
			sc += 15.0
			if str((t as Dictionary)["type"]) == "pack":
				herd = _act_herd_fix9()
	return {"score": sc, "rows": rws, "satt": st, "group": gd, "fix": fx, "herd": herd}


## Wendet das (gedrehte) Brett die Jagd ab, weil die gewarnte Beute jetzt eine Herde ist (noch neben den Jägern)?
func _act_herd_fix9() -> bool:
	for i in pack_warn9:
		var f: FieldData = fields[int(i)]
		var rule := _hunt_rule9(f.kind)
		if rule.is_empty() or int(rule["herd"]) <= 0 or gsize9(f.id) < int(rule["herd"]):
			continue
		for g in nb9(f.id):
			var h: FieldData = fields[g]
			if h.kind == int(rule["hunter"]) and gsize9(g) >= int(rule["at"]):
				return true
	return false


## Text und Symbol der Zeile für eine Gefahr: die Jagd nennt ihre Jäger („Trenn die Raubsaurier!“).
func _act_danger_text9(tp: String, herd: bool = false) -> Array:
	if tp == "pack":
		var hk := hunter_of9(pack_warn9.keys())
		if herd:
			var pk := FieldData.ANIMALS
			for i in pack_warn9:
				pk = (fields[int(i)] as FieldData).kind
				break
			return ["Bilde eine Herde!", FieldData.kind_icon(pk)]
		return [str(ACT_HUNT9.get(hk, "Trenn die Jäger!")), FieldData.kind_icon(hk)]
	return [str(ACT_DANGER9.get(tp, "Achtung!")), str(ACT_DANGER_ICON9.get(tp, "info"))]


## Text für ein Feld, das versorgt wird: „Lava ans Wasser drehen“, „Tiere neben Wiese drehen“.
func _act_need_text9(fid: int, k: int) -> Array:
	var miss: Array = need_state9(fields[fid])["missing"]
	var r: Variant = thrive9.get(k)
	var need := ""
	if not miss.is_empty():
		need = str(miss[0])
	elif r != null:
		for n in ((r as Dictionary)["needs"] as Dictionary):
			need = str(n)
			break
	var icons: Array = [FieldData.kind_icon(k)]
	if need == "wet":
		icons.append(FieldData.kind_icon(FieldData.WATER))
		return ["%s ans Wasser drehen" % FieldData.kind_name(k), icons]
	if need == "sun":
		icons.append("sun")
		return ["%s %s drehen" % [FieldData.kind_name(k), ACT_SUN9], icons]
	var sk := src_kind9(need)
	if sk < 0:
		return ["Versorge %s" % FieldData.kind_name(k), icons]
	icons.append(FieldData.kind_icon(sk))
	if sk == FieldData.CAMP:
		return ["%s ans Feuer drehen" % FieldData.kind_name(k), icons]      # 🔥 von der Feuerstelle: „ans Feuer“
	return ["%s neben %s drehen" % [FieldData.kind_name(k), FieldData.kind_name(sk)], icons]


## Die Quell-Art eines Bedürfnisses in diesem Level: eine, die auf dem Brett liegt, sonst eine, die das Level kennt
## (Startmischung, Reihen, Gedeihen, Regen), sonst die erste der Tabelle. -1: keine Quelle.
func src_kind9(need: String) -> int:
	if need == "wet":
		return FieldData.WATER
	var src: Array = SOURCES9.get(need, [])
	if src.is_empty():
		return -1
	for s in src:
		if count(int(s)) > 0:
			return int(s)
	var known := {}
	var comp: Dictionary = day.get("comp", {})
	for key in comp:
		known[int(str(key))] = true
	for k in rows9:
		known[int(k)] = true
		known[int(rows9[k])] = true
	for k2 in thrive9:
		known[int(k2)] = true
		var up := int((thrive9[k2] as Dictionary)["up"])
		if up >= 0:
			known[up] = true
	for it in rain9:
		known[int((it as Array)[2])] = true
	for s2 in src:
		if known.has(int(s2)):
			return int(s2)
	return int(src[0])


const ACT_DANGER9 = {"volcano": "Teil die Lava!", "bolt": "Wasser an den Wald!", "pack": "Trenn die Raubtiere!",
	"hunger": "Rette die Hungrigen!", "smog": "Weg vom Smog!", "war": "Trenn die Kirchen!", "flood": "Verteil die Städte!",
	"glacier": "Teil das Eis!", "impact": "Dreh, der Meteor kommt"}
const ACT_DANGER_ICON9 = {"volcano": "lava", "bolt": "bolt", "pack": "pred", "hunger": "hunger", "smog": "smog",
	"war": "swords", "flood": "water", "glacier": "ice", "impact": "meteor_fall"}
## Jagd: die Zeile nennt die Jäger (GDPD_ERDGESCHICHTE.md 4.1).
## Zweite Zeile, wenn die Fortschritts-Drehung zugleich eine gewarnte Gefahr abwendet.
const ACT_ALSO9 = {"volcano": "Stoppt auch den Ausbruch", "bolt": "Rettet auch den Wald", "pack": "Rettet auch die Tiere",
	"glacier": "Stoppt auch das Eis", "hunger": "Rettet auch die Hungrigen", "flood": "Stoppt auch die Flut",
	"war": "Stoppt auch den Krieg", "smog": "Rettet auch die Natur"}
const ACT_HUNT9 = {FieldData.PRED: "Trenn die Raubtiere!", FieldData.REX: "Trenn die Raubsaurier!",
	FieldData.EARLY: "Trenn die Jäger!"}


var _act_gk9 := -1                # Art des Teilziels, an dem next_action gerade arbeitet (-1: keins)


func _next_action9() -> Dictionary:
	if day_won:
		return _act9("won", "Geschafft!", ["star"], -1)
	var g := _act_goal9()
	_act_gk9 = int(g.get("kind", -1)) if not g.is_empty() else -1
	var hint := _act_hint9(g)
	if impact_pending9():
		var ai := _act_impact9()
		ai["hint"] = hint
		return ai
	var a := _act_pick9(g)
	var dg := str(a.get("danger", ""))
	if dg != "" and ["row", "thrive", "group"].has(str(a["type"])) and ACT_ALSO9.has(dg):
		# die Drehung bringt Fortschritt UND wendet die Gefahr ab: die zweite Zeile sagt es (nicht das Rezept)
		a["hint"] = str(ACT_ALSO9[dg])
		(a["icons"] as Array).append(str(ACT_DANGER_ICON9.get(dg, "info")))
		return a
	# das Rezept nicht doppelt: zeigt die Zeile schon, was entsteht („→ Fels“), bleibt die zweite Zeile leer
	if int(a.get("result", -1)) >= 0 and hint.ends_with("→ " + FieldData.kind_name(int(a["result"]))):
		hint = ""
	a["hint"] = hint
	return a


## Level „Einschlag“ vor der ersten Drehung (4.3): jede Drehung bringt den Meteor; die Zeile nennt die beste: die, nach
## der die meisten geraden Dreier aus Asche (heute Saurier oder Erde) liegen – sie wachsen gleich zu Wiesen (späte
## Runde), Paare danach zählen wenig. Auf dem Brett gedreht und zurückgedreht (billig, wie _act_pick9).
func _act_impact9() -> Dictionary:
	var dt := _act_danger_text9("impact")
	var out := _act9("danger", str(dt[0]), [str(dt[1])], -1)
	out["danger"] = "impact"
	if not _cache_ready:
		_build_cache()
	var kill: Dictionary = impact9["kill"]
	var best_v := -INF
	for m in MOVES:
		_rot9(int(m[0]), int(m[1]), int(m[2]))
		var v := 0.0
		var i := 0
		while i < _LINES.size():
			if _LINES[i + 3] == 0:
				var ash := 0
				for j in 3:
					var k: int = (_index[_LINES[i + j]] as FieldData).kind
					if k == FieldData.EMPTY or kill.has(k):
						ash += 1
				v += 10.0 if ash == 3 else (0.5 if ash == 2 else 0.0)
			i += 4
		_rot9(int(m[0]), int(m[1]), -int(m[2]))
		v -= 0.01 if absi(int(m[2])) == 2 else 0.0
		if v > best_v:
			best_v = v
			out["move"] = {"axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])}
	_nb_ok = false
	_grp_ok = false
	var ids: Array = []
	for f in fields:
		if (impact9["kill"] as Dictionary).has(f.kind):
			ids.append(f.id)
	out["fields"] = ids
	return out


func _act_pick9(g: Dictionary) -> Dictionary:
	if not _cache_ready:
		_build_cache()
	var stand := _line_keys()
	var cands: Array = []          # Felder, die versorgt werden könnten und dem Ziel helfen (nur die werden geprüft)
	for f in fields:
		if not thrive9.has(f.kind) or f.burning or satt9(f.id):
			continue
		if _act_satt_goal9(f.kind) or (_act_up9(f.kind) >= 0 and _act_val9(f.kind, _act_up9(f.kind)) > 0.0):
			cands.append(f.id)
	var grp: Array = []
	if not g.is_empty() and str(g["type"]) == "group":
		grp = [int(g["kind"]), biggest9(int(g["kind"]))]
	var threats := _act_threats9()
	# Feuer: nur Regen hilft (und es breitet sich aus) – zuerst
	if rain > 0:
		for f in fields:
			if f.burning and rain_ok9(f):
				var af := _act9("rain", "Lösch das Feuer!", ["rain", "fire"], -1)
				af["tool"] = "rain"
				af["field"] = f.id
				af["fields"] = [f.id]
				af["danger"] = "fire"
				return af
	# 1. Eine Drehung: Reihe, Versorgung, Gruppe, Gefahr abwenden (auf dem Brett gedreht und zurückgedreht)
	var best: Dictionary = {}
	var best_m: Array = []
	var best_v := 0.0
	var fix_b: Dictionary = {}       # die beste Drehung, die eine Gefahr abwendet (Build 12: Gefahr zuerst)
	var fix_m: Array = []
	var fix_v := 0.0
	for m in MOVES:
		var ax := int(m[0])
		var ly := int(m[1])
		var tn := int(m[2])
		_rot9(ax, ly, tn)
		var ids := {}
		for f in fields:
			if f.p[ax] == ly:
				ids[f.id] = true
		var r := _act_score9(ids, stand, cands, grp, threats)
		_rot9(ax, ly, -tn)
		var v := float(r["score"]) - (0.01 if absi(tn) == 2 else 0.0)
		if v > best_v + 0.001:
			best_v = v
			best = r
			best_m = m
		if not (r["fix"] as Array).is_empty() and v > fix_v + 0.001:
			fix_v = v
			fix_b = r
			fix_m = m
	_nb_ok = false
	_grp_ok = false
	# Droht etwas, sagt die Zeile, wie man es abwendet (wie die Pille „Blitz droht!“), nie einen Zug, der es geschehen
	# lässt: die beste abwendende Drehung, sonst beim Blitz der Regen (unten)
	var danger_first := not threats.is_empty() and not best.is_empty() and (best["fix"] as Array).is_empty()
	if danger_first and not fix_b.is_empty():
		best = fix_b
		best_m = fix_m
		best_v = fix_v
		danger_first = false
	if danger_first and bolt >= 0 and rain > 0 and rain_ok9(fields[bolt]):
		best = {}
	var progress := not best.is_empty() and (not (best["rows"] as Array).is_empty() or not (best["satt"] as Array).is_empty()
		or int(best["group"]) > 0)
	var dangerous := not threats.is_empty()
	if not best.is_empty() and (progress or not (best["fix"] as Array).is_empty()):
		var mv := {"axis": int(best_m[0]), "layer": int(best_m[1]), "turns": int(best_m[2])}
		var fixes: Array = best["fix"]
		var out: Dictionary = {}
		if dangerous and not fixes.is_empty() and (not progress or best_v < 15.0 * float(fixes.size()) + 0.5):
			# die Gefahr zuerst (sie kostet mehr, als die Drehung sonst bringt)
			var tp := str(fixes[0])
			var dt := _act_danger_text9(tp, bool(best.get("herd", false)))
			out = _act9("danger", str(dt[0]), [str(dt[1])], -1)
			out["danger"] = tp
			for t in threats:
				if str((t as Dictionary)["type"]) == tp:
					out["fields"] = (t as Dictionary)["fields"]
		if out.is_empty() and not (best["rows"] as Array).is_empty():
			var rw: Array = (best["rows"] as Array)[0]
			for x in best["rows"]:
				if _act_val9(int(x[0]), int(x[2])) > _act_val9(int(rw[0]), int(rw[2])):
					rw = x
			var k := int(rw[0])
			var ic := FieldData.kind_icon(k)
			out = _act9("row", "Dreh 3 %s in eine Reihe" % FieldData.kind_plural(k), [ic, ic, ic], int(rw[2]))
			out["fields"] = rw[1]
		elif out.is_empty() and not (best["satt"] as Array).is_empty():
			var sa: Array = (best["satt"] as Array)[0]
			var nt := _act_need_text9(int(sa[0]), int(sa[1]))
			out = _act9("thrive", str(nt[0]), nt[1], int(sa[2]) if not _act_satt_goal9(int(sa[1])) else -1)
			out["fields"] = [int(sa[0])]
		elif out.is_empty():
			var gk := int(grp[0])
			out = _act9("row", "Mach die %s größer" % _act_group_name9(gk), [FieldData.kind_icon(gk)], -1)
			out["type"] = "group"
			var bigf := -1
			for f in fields:
				if f.kind == gk and gsize9(f.id) == int(grp[1]):
					bigf = f.id
					break
			out["fields"] = members9(bigf) if bigf >= 0 else []
		out["move"] = mv
		if not fixes.is_empty():
			out["danger"] = str(fixes[0])
		return out
	# Gefahr ohne Abhilfe durch Drehen: Regen hilft beim Blitz
	if bolt >= 0 and rain > 0 and rain_ok9(fields[bolt]):
		var ab := _act9("rain", "Gieß den Wald!", ["rain", FieldData.kind_icon(FieldData.FOREST)], -1)
		ab["tool"] = "rain"
		ab["field"] = bolt
		ab["fields"] = [bolt]
		ab["danger"] = "bolt"
		return ab
	# 2. Regen (kostet keinen Schritt): ein Feld wird zu einer Art näher am Ziel
	var ar := _act_rain9()
	if not ar.is_empty():
		return ar
	# 3. Zwei Drehungen: eine Vorbereitung, nach der eine Reihe geht
	var two := _act_two9(stand)
	if not two.is_empty():
		return two
	# 4. Versorgte Felder wachsen von selbst
	for f in fields:
		var up := _act_up9(f.kind)
		if up >= 0 and satt9(f.id) and _act_val9(f.kind, up) > 0.0 and not (LEVEL9.has(f.kind) and not up_ok9(f.id, up)):
			var aw := _act9("wait", "Dreh weiter, %s wächst" % FieldData.kind_name(f.kind), [FieldData.kind_icon(f.kind)], up)
			aw["fields"] = [f.id]
			return aw
	# 5. Sackgasse: das Sicherheitsnetz
	if (not bool(reach9()["ok"]) or dead9()) and not gift_plan9().is_empty():
		return _act_help9()
	# 6. Das nächste Teilziel über mehrere Züge (nur, wenn es so geht)
	var ag := _act_general9(g)
	if not ag.is_empty():
		return ag
	if stuck9() != "" and not gift_plan9().is_empty():
		return _act_help9()
	# 7. Irgendeine Drehung, nach der ein Teilziel steigt (selten: z. B. ein versorgtes Dorf bekommt, was die Stadt
	# braucht, und wächst) – die Zeile nennt sie, statt „Dreh weiter“ (Review Level 54/58)
	var ay := _act_any9()
	if not ay.is_empty():
		return ay
	if rain_every > 0:
		return _act9("goal", "Dreh weiter, Regen kommt", ["rain"], -1)
	return _act9("goal", "Dreh eine Scheibe", ["twist"], -1)


## Die erste Drehung, nach deren Runde die Summe der Teilziele steigt (echte Regeln auf einer Kopie). Nur im
## seltenen Fall, dass nichts anderes passt: ein versorgtes Feld (Dorf) darf erst nach der Drehung zur Ziel-Art
## (Stadt) wachsen. Vorauswahl nur mit gedrehten Plätzen, Runden nur für die passenden Züge. {} = keine.
func _act_any9() -> Dictionary:
	# Vorauswahl ohne Runde: Felder, die zur Ziel-Art wachsen könnten, deren Bedürfnisse dort aber (noch) fehlen
	var gks := {}
	for sd in goal9:
		var subs: Array = (sd as Dictionary)["subs"] if str((sd as Dictionary)["type"]) == "hold" else [sd]
		for x in subs:
			gks[int((x as Dictionary).get("kind", -1))] = true
	var wait: Array = []
	for f in fields:
		var up := _act_up9(f.kind)
		if up >= 0 and gks.has(up) and not f.burning and not up_ok9(f.id, up):
			wait.append([f.id, up])
	if wait.is_empty():
		return {}
	var s0 := _subs_sum9()
	var tries := 0
	for m in MOVES:
		if tries >= 4:
			break                      # höchstens 4 echte Runden (Kosten je Zug am Handy)
		_rot9(int(m[0]), int(m[1]), int(m[2]))
		var opens := false
		for wv in wait:
			if up_ok9(int(wv[0]), int(wv[1])):
				opens = true
				break
		_rot9(int(m[0]), int(m[1]), -int(m[2]))
		if not opens:
			continue
		tries += 1
		var c := clone()
		var r: Dictionary = c.play({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])})
		if c._subs_sum9() <= s0 and not c.day_won:
			continue
		var a := _act9("grow", "Dreh die leuchtende Scheibe", ["twist"], -1)
		for e in r.get("events", []):
			var ed: Dictionary = e
			if str(ed.get("type", "")) == "thrive" and gks.has(int(ed.get("kind", -1))):
				var fk := int(ed.get("from", -1))
				var tk := int(ed.get("kind", -1))
				a = _act9("grow", "Dreh: %s wird %s" % [FieldData.kind_name(fk), FieldData.kind_name(tk)],
					[FieldData.kind_icon(fk), "->", FieldData.kind_icon(tk)], -1)
				a["fields"] = [int(ed.get("field", -1))]
				break
		a["move"] = {"axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])}
		return a
	return {}


func _act_help9() -> Dictionary:
	var ah := _act9("help", "Hol dir Hilfe", ["gift"], -1)
	ah["tool"] = "gift"
	return ah


func _act_group_name9(k: int) -> String:
	return "%s-Gruppe" % FieldData.kind_name(k) if k != FieldData.FIELD else "Äcker-Gruppe"


## Regen, der ein Feld eine Stufe näher ans Ziel bringt (bevorzugt die Ziel-Art).
func _act_rain9() -> Dictionary:
	if rain <= 0:
		return {}
	var best := -1
	var best_v := 0.0
	for f in fields:
		if f.burning or not rain_ok9(f):
			continue
		var nk := rain_to9(f)
		var v := _act_val9(f.kind, nk)
		if v > best_v:
			best_v = v
			best = f.id
	if best < 0:
		return {}
	var k: int = (fields[best] as FieldData).kind
	var a := _act9("rain", "Gieß %s mit Regen" % FieldData.kind_name(k), ["rain", FieldData.kind_icon(k)], rain_to9(fields[best]))
	a["tool"] = "rain"
	a["field"] = best
	a["fields"] = [best]
	return a


## Für die Vorausschau über zwei Drehungen: je Zug (Index in MOVES) die Platz-Vertauschung (neuer Platz je Platz)
## und die geraden Reihen (Platz-Dreier), die seine Scheibe danach berührt. Einmal berechnet, nur Plätze, kein Brett.
static var _PERM9: Array = []
static var _LSLOT9 := PackedInt32Array()
static var _MLINES9: Array = []


static func _build_moves9() -> void:
	if not _PERM9.is_empty():
		return
	_build_cache9()
	if not _cache_ready:
		_build_cache()
	# Plätze als (p, n): einmal über alle Plätze laufen (Reihenfolge wie _SLOT9)
	var pn: Array = []
	pn.resize(54)
	for x in [-1, 0, 1]:
		for y in [-1, 0, 1]:
			for z in [-1, 0, 1]:
				var p := Vector3i(x, y, z)
				for a in 3:
					if p[a] == 0:
						continue
					var nv := unit(a, p[a])
					pn[int(_SLOT9[pos_key(p, nv)])] = [p, nv]
	var i := 0
	while i < _LINES.size():
		if _LINES[i + 3] == 0:
			_LSLOT9.append(int(_SLOT9[_LINES[i]]))
			_LSLOT9.append(int(_SLOT9[_LINES[i + 1]]))
			_LSLOT9.append(int(_SLOT9[_LINES[i + 2]]))
		i += 4
	for m in MOVES:
		var ax := int(m[0])
		var ly := int(m[1])
		var tn := int(m[2])
		var d := 1 if tn > 0 else -1
		var perm := PackedInt32Array()
		perm.resize(54)
		var inl := {}
		for sl in 54:
			var p2: Vector3i = (pn[sl] as Array)[0]
			var n2: Vector3i = (pn[sl] as Array)[1]
			if p2[ax] == ly:
				for t in absi(tn):
					p2 = rv(p2, ax, d)
					n2 = rv(n2, ax, d)
				perm[sl] = int(_SLOT9[pos_key(p2, n2)])
				inl[perm[sl]] = true
			else:
				perm[sl] = sl
		_PERM9.append(perm)
		var ml := PackedInt32Array()
		for li in _LSLOT9.size() / 3:
			if inl.has(_LSLOT9[3 * li]) or inl.has(_LSLOT9[3 * li + 1]) or inl.has(_LSLOT9[3 * li + 2]):
				ml.append(li)
		_MLINES9.append(ml)


## Zwei Drehungen: Nach der ersten geht mit der zweiten eine Reihe, die dem Ziel hilft. Nur Plätze (schnell: Arten und
## Feld-IDs je Platz werden vertauscht, das Brett bleibt, wie es ist).
func _act_two9(stand: Dictionary) -> Dictionary:
	var useful := {}
	for k in rows9:
		if _act_val9(int(k), int(rows9[k])) > 0.0 and count(int(k)) >= 3:
			useful[int(k)] = _act_val9(int(k), int(rows9[k]))
	if useful.is_empty():
		return {}
	_build_moves9()
	var kd := PackedInt32Array()
	var idd := PackedInt32Array()
	kd.resize(54)
	idd.resize(54)
	for f in fields:
		var sl := slot9(f)
		kd[sl] = f.kind
		idd[sl] = f.id
	var k1 := PackedInt32Array()
	var i1 := PackedInt32Array()
	k1.resize(54)
	i1.resize(54)
	var best_v := 0.0
	var best: Dictionary = {}
	for mi in MOVES.size():
		var m: Array = MOVES[mi]
		if absi(int(m[2])) == 2:
			continue
		var pm: PackedInt32Array = _PERM9[mi]
		for sl in 54:
			k1[pm[sl]] = kd[sl]
			i1[pm[sl]] = idd[sl]
		for mj in MOVES.size():
			var m2: Array = MOVES[mj]
			if int(m2[0]) == int(m[0]) and int(m2[1]) == int(m[1]):
				continue
			var p2: PackedInt32Array = _PERM9[mj]
			# Platz s nach dem zweiten Zug hält, was vorher auf inv[s] lag: über die Reihen der Scheibe prüfen
			for li in _MLINES9[mj]:
				var a := _LSLOT9[3 * li]
				var b := _LSLOT9[3 * li + 1]
				var c := _LSLOT9[3 * li + 2]
				var sa := _inv9(p2, a)
				var kk := k1[sa]
				if not useful.has(kk):
					continue
				var sb := _inv9(p2, b)
				if k1[sb] != kk:
					continue
				var sc := _inv9(p2, c)
				if k1[sc] != kk:
					continue
				var key := _key9(i1[sa], i1[sb], i1[sc], kk)
				if stand.has(key) or spent.has(key):
					continue
				var v: float = useful[kk]
				if v > best_v:
					best_v = v
					best = {"m": m, "k": kk, "ids": [i1[sa], i1[sb], i1[sc]]}
	if best.is_empty():
		return {}
	var k2 := int(best["k"])
	var ic := FieldData.kind_icon(k2)
	var out := _act9("goal", "Bring 3 %s in eine Reihe" % FieldData.kind_plural(k2), [ic, ic, ic], int(rows9[k2]))
	var bm: Array = best["m"]
	out["move"] = {"axis": int(bm[0]), "layer": int(bm[1]), "turns": int(bm[2])}
	out["fields"] = best["ids"]
	out["steps"] = 2
	return out


## Welcher Platz kommt durch die Vertauschung perm auf Platz s? (Vierteldrehungen: höchstens 4 Schritte im Kreis)
static func _inv9(perm: PackedInt32Array, s: int) -> int:
	var x := s
	for i in 4:
		var y := perm[x]
		if y == s:
			return x
		x = y
	return s


## line_key aus drei Feld-IDs und der Art.
static func _key9(a0: int, b0: int, c0: int, k: int) -> int:
	var a := a0
	var b := b0
	var c := c0
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
	return ((a * 64 + b) * 64 + c) * 32 + k


## Das Teilziel über mehrere Züge – nur, was geht: eine Reihen-Art mit genug Feldern auf passenden Plätzen, sonst ein
## Feld, das versorgt werden kann.
func _act_general9(g: Dictionary) -> Dictionary:
	var best_k := -1
	var best_v := 0.0
	for k in rows9:
		var v := _act_val9(int(k), int(rows9[k]))
		if v > best_v and _row_cap9(int(k)) > 0:
			best_v = v
			best_k = int(k)
	if best_k >= 0:
		var ic := FieldData.kind_icon(best_k)
		var a := _act9("goal", "Bring 3 %s in eine Reihe" % FieldData.kind_plural(best_k), [ic, ic, ic], int(rows9[best_k]))
		return a
	var bf := -1
	var bv := 0.0
	for f in fields:
		if not thrive9.has(f.kind) or satt9(f.id) or f.burning:
			continue
		var v2 := 9.0 if _act_satt_goal9(f.kind) else _act_val9(f.kind, _act_up9(f.kind))
		if v2 > bv and _needs_ok9(f.kind, FieldData.sticker_type(f.p), _have_kinds9(), f.id):
			bv = v2
			bf = f.id
	if bf >= 0:
		var k2: int = (fields[bf] as FieldData).kind
		var nt := _act_need_text9(bf, k2)
		var a2 := _act9("goal", str(nt[0]), nt[1], _act_up9(k2) if not _act_satt_goal9(k2) else -1)
		a2["fields"] = [bf]
		return a2
	return {}


func _have_kinds9() -> Dictionary:
	var hk := {}
	for f in fields:
		hk[f.kind] = true
	return hk


## Kurzer Versorgungs-Satz zum Ziel: satt-Ziele „Tiere brauchen Pflanzen: 2/6 versorgt“, sonst die Regel der Art, die
## durch Nachbarn wächst („Lava braucht 2 Wasser“), oder "".
func _act_hint9(g: Dictionary) -> String:
	if g.is_empty():
		return ""
	var t := str(g["type"])
	if t == "satt":
		var k := int(g["kind"])
		var r: Variant = thrive9.get(k)
		if r == null:
			return ""
		var ns: Array = []
		for n in ((r as Dictionary)["needs"] as Dictionary):
			ns.append(str(NEED_NAME9.get(str(n), n)))
		return "%s brauchen %s: %d/%d versorgt" % [FieldData.kind_plural(k), " + ".join(PackedStringArray(ns)),
			sub_progress9(g), int(g["target"])]
	# zuerst das Rezept, das die Ziel-Art selbst macht (Reihe oder Gedeihen), dann die Kette davor
	var gk := int(g.get("kind", -1))
	for k0 in rows9:
		if int(rows9[k0]) == gk and int(k0) != gk:
			return "3 %s → %s" % [FieldData.kind_name(int(k0)), FieldData.kind_name(gk)]
	for k1 in thrive9:
		if _act_up9(int(k1)) == gk and int(k1) != gk:
			return _act_recipe9(int(k1), gk)
	for k2 in thrive9:
		var up := _act_up9(int(k2))
		if up < 0 or _act_val9(int(k2), up) <= 0.0:
			continue
		return _act_recipe9(int(k2), up)
	for k3 in rows9:
		if _act_val9(int(k3), int(rows9[k3])) > 0.0:
			return "3 %s → %s" % [FieldData.kind_name(int(k3)), FieldData.kind_name(int(rows9[k3]))]
	return ""


## „Lava + 2 Wasser → Fels“: das Gedeihen-Rezept einer Art.
func _act_recipe9(k: int, up: int) -> String:
	var parts: Array = []
	var nd: Dictionary = (thrive9[k] as Dictionary)["needs"]
	for n in nd:
		var amt := int(nd[n])
		var nm := str(NEED_NAME9.get(str(n), n))
		parts.append(nm if amt <= 1 else "%d %s" % [amt, nm])
	return "%s + %s → %s" % [FieldData.kind_name(k), " + ".join(PackedStringArray(parts)), FieldData.kind_name(up)]


## Was über einem Feld als kurze Überschrift steht (Feld-Blatt): die Familie in Worten der Schöpfung.
## Fels heißt nie „Essen“ (Build 12).
## Die Pille einer stillen Reihe oder eines Fehlversuchs in einem Level (Ereignis still/miss, why): [Titel, Zeile].
## Nie leer, nie „Sammle 0 Glauben“, nie „Schau auf die Zeichen“ (Build 12: keine Symbole mehr an den Feldern).
## k: Art der Reihe (-1: unbekannt). Die Zeile nennt, was stattdessen geht (die nächste Handlung).
func still_line9(why: String, k: int = -1) -> Array:
	var nxt := str(next_action().get("text", "")) if camp else ""
	if why == "diag":
		return ["Schräg zählt nicht", "Nur gerade Reihen"]
	if why == "repeat":
		return ["Zurückgedreht", "Dreh eine andere Scheibe"]
	if why == "spent" or why == "standing":
		return ["Schon gewachsen", "Bring ein neues Feld rein"]
	if why == "finished":
		return ["Fertig", nxt]
	if why == "dino":
		return ["Saurier wachsen nicht mehr", nxt]
	if why == "ice":
		return ["Eis wächst nicht in Reihen", nxt]
	if why == "camp":
		return ["Feuer wächst nicht", nxt]
	if (why == "stone" or why == "done") and k >= 0 and goal_kinds9.has(k):
		return ["Zählt schon", nxt]
	if why == "thrive" or why == "people" or (why == "water_life" and k >= 0 and thrive9.has(k)):
		var r: Variant = thrive9.get(k)
		if r != null:
			var parts: Array = []
			for n in ((r as Dictionary)["needs"] as Dictionary):
				var amt := int(((r as Dictionary)["needs"] as Dictionary)[n])
				var nm := str(NEED_NAME9.get(str(n), n))
				parts.append(nm if amt <= 1 else "%d %s" % [amt, nm])
			return ["Wächst durch Nachbarn", "Braucht %s daneben" % " + ".join(PackedStringArray(parts))]
	if why == "water" or why == "water_life":
		return ["Wasser wächst nicht", nxt]
	if k >= 0 and why != "" and why != "other":
		return ["%s wächst hier nicht" % FieldData.kind_name(k), nxt]
	return ["Nichts gewachsen", nxt]


static func kind_caps9(k: int) -> String:
	if k == FieldData.LAVA:
		return "Glut"
	if k == FieldData.STONE:
		return "Gestein"
	if k == FieldData.EMPTY:
		return "Land"
	if k == FieldData.WATER:
		return "Wasser"
	if FieldData.water_family(k):
		return "Leben im Wasser"
	if k == FieldData.MOSS or k == FieldData.FERN or k == FieldData.MEADOW or k == FieldData.FOREST:
		return "Pflanzen"
	if k == FieldData.SEED or k == FieldData.FIELD:
		return "Nahrung"
	if k == FieldData.ANIMALS or k == FieldData.BIRDS or k == FieldData.PRED or k == FieldData.INSECTS \
			or k == FieldData.AMPHIB or k == FieldData.REPTILE or k == FieldData.SAURO or k == FieldData.REX \
			or k == FieldData.PTERO or k == FieldData.MAMMOTH or k == FieldData.APES:
		return "Tiere"
	if k == FieldData.ICE:
		return "Eis"
	if k == FieldData.EARLY:
		return "Menschen"
	if k == FieldData.CAMP:
		return "Feuer"
	if k == FieldData.CHURCH:
		return "Glaube"
	if k == FieldData.INDUSTRY:
		return "Industrie"
	if FieldData.people(k):
		return "Menschen"
	return ""


# =============================================================================
# Build 12: Spielstand mitten im Level (Game speichert ihn nach jeder Runde und beim Pausieren, lädt ihn beim Start)
# =============================================================================

## Version des Level-Stands (save9). Ältere oder neuere Stände werden nicht geladen (das Level beginnt neu).
const SAVE9_VERSION := 1


static func _keys9(d: Dictionary) -> Array:
	var out: Array = []
	for k in d:
		out.append(k)
	return out


static func _set9(a: Variant) -> Dictionary:
	var out := {}
	if a is Array:
		for k in a:
			out[int(k)] = true
	return out


## Der laufende Stand eines Levels als reine Daten (Zahlen, Texte, Arrays, Dictionaries; für ConfigFile). Alles, was
## die Regeln weiter brauchen: Brett (Plätze und Feld-Zustände), Schritte, Fortschritt mit Verlusten, Siegel, Gefahren
## und Warnungen, Werkzeuge, Gnade/Sicherheitsnetz, Zufall. Die Regeln selbst kommen beim Laden aus der Level-Konfig.
func save9() -> Dictionary:
	var fl: Array = []
	for f in fields:
		fl.append([f.p.x, f.p.y, f.p.z, f.n.x, f.n.y, f.n.z, f.kind, f.fresh, 1 if f.burning else 0, f.fed, f.hungry,
			f.maxlvl, f.flvl, f.best.duplicate(), 1 if f.mk else 0, f.crater_rest])
	var sw := {}
	for k in smog_warn9:
		sw[int(k)] = int(smog_warn9[k])
	return {"v": SAVE9_VERSION, "level": level_no, "fields": fl, "turn": turn, "twists": twists,
		"gift_twists": gift_twists, "extra_steps": extra_steps, "faith": faith, "faith_earned": faith_earned,
		"rain": rain, "next_rain": next_rain, "meteors": meteors, "bolts": bolts, "bolt": bolt, "volc": volc,
		"bolt_guard": bolt_guard9, "war_on": war_on, "front": _keys9(front), "flood_warn": _keys9(flood_warn),
		"pack_warn": _keys9(pack_warn9), "smog_warn": sw, "standing": _keys9(standing), "broken": _keys9(broken),
		"glac": glac9, "glac_rest": glac_rest9.duplicate(), "impact_done": impact_done9,
		"spent": _keys9(spent), "made": made.duplicate(), "lost": lost9.duplicate(), "held": held9.duplicate(),
		"peak": peak9, "gain_at": gain_at9, "miracle": _keys9(miracle_bought), "won": day_won, "won_at": day_won_at,
		"won_told": _won_told, "need_told": _need_told, "era": _era_last, "st": st9.duplicate(), "stats": stats.duplicate(),
		"ever": _keys9(ever), "recent": recent9.duplicate(), "last_row": last_row.duplicate(), "last_grew": last_grew,
		"satt0": _keys9(_satt0), "trace": trace9.duplicate(), "misses": misses, "acts": _act_seq,
		"rng_seed": rng.seed, "rng_state": rng.state, "lcg": lcg}


## Einen Level-Stand laden (save9): cfg = die Konfiguration des Levels (Campaign.config, Welt des Tages: ihre eigene).
## null, wenn der Stand nicht passt (andere Version, anderes Level, kaputt).
static func load9(d: Dictionary, cfg: Dictionary) -> GameState:
	if int(d.get("v", 0)) != SAVE9_VERSION or int(d.get("level", -1)) != int(cfg.get("level", -2)):
		return null
	var fl: Variant = d.get("fields")
	if not (fl is Array) or (fl as Array).size() != 54:
		return null
	var kinds: Array = []
	for row in fl:
		if not (row is Array) or (row as Array).size() < 16:
			return null
		kinds.append(int((row as Array)[6]))
	var gs := GameState.new()
	gs.setup_level(cfg, kinds, int(d.get("rng_seed", 1)))
	var seen := {}
	for i in 54:
		var r: Array = (fl as Array)[i]
		var f: FieldData = gs.fields[i]
		f.p = Vector3i(int(r[0]), int(r[1]), int(r[2]))
		f.n = Vector3i(int(r[3]), int(r[4]), int(r[5]))
		f.kind = int(r[6])
		f.fresh = int(r[7])
		f.burning = int(r[8]) != 0
		f.fed = int(r[9])
		f.hungry = int(r[10])
		f.maxlvl = int(r[11])
		f.flvl = int(r[12])
		f.best = {}
		if r[13] is Dictionary:
			for k in (r[13] as Dictionary):
				f.best[str(k)] = int((r[13] as Dictionary)[k])
		f.mk = int(r[14]) != 0
		f.crater_rest = int(r[15])
		seen[pos_key(f.p, f.n)] = true
	if seen.size() != 54:
		return null                  # zwei Felder auf einem Platz: kaputt
	gs.rebuild_index()
	gs.turn = int(d.get("turn", 1))
	gs.twists = int(d.get("twists", 0))
	gs.gift_twists = int(d.get("gift_twists", 0))
	gs.extra_steps = int(d.get("extra_steps", 0))
	gs.faith = int(d.get("faith", 0))
	gs.faith_earned = int(d.get("faith_earned", 0))
	gs.rain = int(d.get("rain", 0))
	gs.next_rain = int(d.get("next_rain", gs.next_rain))
	gs.meteors = int(d.get("meteors", 0))
	gs.bolts = int(d.get("bolts", 0))
	gs.bolt = int(d.get("bolt", -1))
	gs.volc = int(d.get("volc", -1))
	gs.bolt_guard9 = int(d.get("bolt_guard", 0))
	gs.war_on = bool(d.get("war_on", false))
	gs.front = _set9(d.get("front", []))
	gs.flood_warn = _set9(d.get("flood_warn", []))
	gs.pack_warn9 = _set9(d.get("pack_warn", []))
	gs.glac9 = int(d.get("glac", -1))
	var gr: Variant = d.get("glac_rest", [])
	if gr is Array and (gr as Array).size() == gs.glac_rest9.size():
		for i in gs.glac_rest9.size():
			gs.glac_rest9[i] = int((gr as Array)[i])
	gs.impact_done9 = bool(d.get("impact_done", false))
	gs.smog_warn9 = {}
	var sw: Variant = d.get("smog_warn", {})
	if sw is Dictionary:
		for k in (sw as Dictionary):
			gs.smog_warn9[int(k)] = int((sw as Dictionary)[k])
	gs.standing = _set9(d.get("standing", []))
	gs.broken = _set9(d.get("broken", []))
	gs.spent = _set9(d.get("spent", []))
	var md: Variant = d.get("made", [])
	var ls: Variant = d.get("lost", [])
	if md is Array and (md as Array).size() == FieldData.KIND_COUNT:
		for k in FieldData.KIND_COUNT:
			gs.made[k] = int((md as Array)[k])
	if ls is Array and (ls as Array).size() == FieldData.KIND_COUNT:
		for k in FieldData.KIND_COUNT:
			gs.lost9[k] = int((ls as Array)[k])
	var hd: Variant = d.get("held", [])
	if hd is Array and (hd as Array).size() == gs.held9.size():
		for i in gs.held9.size():
			gs.held9[i] = int((hd as Array)[i])
	gs.peak9 = int(d.get("peak", 0))
	gs.gain_at9 = int(d.get("gain_at", 0))
	gs.miracle_bought = {}
	for k in d.get("miracle", []):
		gs.miracle_bought[str(k)] = true
	gs.day_won = bool(d.get("won", false))
	gs.day_won_at = int(d.get("won_at", 0))
	gs._won_told = bool(d.get("won_told", false))
	gs._need_told = bool(d.get("need_told", false))
	gs._era_last = str(d.get("era", gs._era_last))
	var st: Variant = d.get("st", {})
	if st is Dictionary:
		for k in (st as Dictionary):
			gs.st9[str(k)] = int((st as Dictionary)[k])
	var sts: Variant = d.get("stats", {})
	if sts is Dictionary:
		for k in (sts as Dictionary):
			gs.stats[str(k)] = int((sts as Dictionary)[k])
	gs.ever = _set9(d.get("ever", []))
	gs.recent9 = []
	for x in d.get("recent", []):
		gs.recent9.append(str(x))
	gs.last_row = []
	for x in d.get("last_row", []):
		gs.last_row.append(int(x))
	gs.last_grew = int(d.get("last_grew", 0))
	gs._satt0 = _set9(d.get("satt0", []))
	gs.trace9 = []
	for x in d.get("trace", []):
		gs.trace9.append(str(x))
	gs.misses = int(d.get("misses", 0))
	gs._act_seq = int(d.get("acts", 0))
	gs.lcg = int(d.get("lcg", gs.lcg))
	gs.rng.seed = int(d.get("rng_seed", 1))
	gs.rng.state = int(d.get("rng_state", gs.rng.state))
	gs._grp_ok = false
	gs._nb_ok = false
	return gs
