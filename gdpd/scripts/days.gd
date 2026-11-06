class_name Days
extends RefCounted
## „Die Schöpfung in 7 Tagen“ (docs/GDPD_7_TAGE.md): die Tag-Tabelle, die Start-Bretter (Pools) und alle Texte.
## Ein Tag = ein Level mit EINEM Ziel, begrenzten Drehungen, 1–3 Sternen und genau EINER neuen Sache.
##
## Ein Paket (Pack) ist Daten: Tag-Tabelle + Pool-Datei. Das erste Paket ist „schoepfung“ (unten fest eingebaut).
## Weitere Pakete (Insel, Wüste, Winter …) kommen als JSON nach res://data/packs/<id>.json (Format wie
## GDPD_7_TAGE.md 3.3: {"id", "title", "days": [{…Tag wie unten…, "boards": [{"board", "seed"}, …]}]}).
## Neue Arten brauchen Code (FieldData), neue Ziele nicht, solange es einer der vier Ziel-Typen ist.
##
## Schnittstelle (alles static):
##   count(pack) · config(n, pack) → Dictionary (für GameState.setup_day) · pool_size(n, pack) · board(n, index, pack)
##   → {"kinds", "seed", "index", "solved_in", "stars", "solution"} · stars_for(cfg, used) · decode(text)
##   goal_line(cfg) („Lass 8 Wiesen wachsen“) · limit_line(twists) · star_line(cfg) · TEXT (alle festen Sätze)

const PACK_ID := "schoepfung"
const PACK_TITLE := "Die Schöpfung in 7 Tagen"
const BOARDS_PATH := "res://data/days_schoepfung.json"
const PACKS_DIR := "res://data/packs"
## Ein Zeichen je Art im Brett-Text (Index = Art): E Erde, w Wiese, W Wald, A Acker, g Großer Wald, T Tiere, H Hütte,
## h Haus, D Dorf, S Stadt, K Kirche, G Großstadt, I Industrie, M Metropole, P Paradies, o Wasser.
const CODE := "EwWAgTHhDSKGIMPo"

const _L1 = [FieldData.EMPTY, FieldData.MEADOW]
const _L2 = [FieldData.EMPTY, FieldData.MEADOW, FieldData.FOREST]
const _L3 = [FieldData.EMPTY, FieldData.MEADOW, FieldData.FOREST, FieldData.BIGFOREST, FieldData.ANIMALS]
const _L4 = [FieldData.EMPTY, FieldData.MEADOW, FieldData.FOREST, FieldData.BIGFOREST, FieldData.ANIMALS,
	FieldData.HUT, FieldData.HOUSE, FieldData.VILLAGE]
const _L5 = [FieldData.EMPTY, FieldData.MEADOW, FieldData.FOREST, FieldData.BIGFOREST, FieldData.ANIMALS,
	FieldData.HUT, FieldData.HOUSE, FieldData.VILLAGE, FieldData.FIELD]
const _L6 = [FieldData.EMPTY, FieldData.MEADOW, FieldData.FOREST, FieldData.BIGFOREST, FieldData.ANIMALS,
	FieldData.HUT, FieldData.HOUSE, FieldData.VILLAGE, FieldData.FIELD, FieldData.TOWN, FieldData.CHURCH]
const _L7 = [FieldData.EMPTY, FieldData.MEADOW, FieldData.FOREST, FieldData.BIGFOREST, FieldData.ANIMALS,
	FieldData.HUT, FieldData.HOUSE, FieldData.VILLAGE, FieldData.FIELD, FieldData.TOWN, FieldData.CHURCH,
	FieldData.BIGCITY, FieldData.INDUSTRY]
const _ALL_WISHES = ["wald", "tiere", "acker", "regen"]

## Was an allen Tagen gilt (jeder Tag überschreibt davon, was er braucht). Immer aus: Herzen, Diagonalen,
## Einfach-Gruppen, Nachwachsen, Blitz, Monsun, Flut, Zeitalter, „Vollendet“.
const BASE = {
	"choices": [], "fire": true, "rain_start": 0, "rain_every": 0, "gift": false,
	"wishes": false, "wish_types": [], "wish_from": 2, "wish_every": 3,
	"scale": false, "income": false, "war": false, "no_war": false, "smog": false, "strike": false,
	"goal_kinds": [], "goal_green": false, "rule_line": "", "rule_icon": "swords", "coach": [], "coach_demo": "",
	"onboard_hint": false,
}

## Die 7 Tage (Abschnitt 2.2 und 2.3). goal_type: "make" (goal_kinds wachsen goal_target-mal), "wishes",
## "faith" (+ goal_green: die Waage muss dabei grün sein). stars = [★★★ bis, ★★ bis] (Drehungen).
## new: die neue Sache des Tages (Aufdecken auf der Ziel-Karte). icon: Symbol der Kachel in der Übersicht.
const DAYS = [
	{"title": "Land", "icon": "meadow",
		"intro": "Mach aus Erde Wiesen!",
		"goal_type": "make", "goal_kinds": [FieldData.MEADOW], "goal_target": 8, "goal_icon": "meadow",
		"goal_text": "Lass 8 Wiesen wachsen", "limit": 15, "stars": [5, 8],
		"rule_line": "Nur gerade Reihen · Wasser wächst nie", "rule_icon": "info",
		"unlocked": _L1, "fire": false, "onboard_hint": true,
		"new": {"key": "drehen", "icon": "meadow", "title": "Neu: Drehen", "text": "Bring 3 gleiche in eine Reihe."},
		"tutorial": {"axis": 0, "layer": 1, "turns": 1},
		"coach": ["Bring 3 gleiche in eine Reihe.", "Super! Eine Wiese.",
			"Jetzt du! Wisch die leuchtende Reihe.", "Gut so! Deine Welt."],
		# „Schau zu!“ (Eingabe gesperrt): kein Befehl, sondern was die Hand gleich zeigt
		"coach_demo": "Schau: 3 gleiche in eine Reihe."},
	{"title": "Pflanzen", "icon": "rain",
		"intro": "Heute wachsen Pflanzen.",
		"goal_type": "make", "goal_kinds": [FieldData.FOREST], "goal_target": 5, "goal_icon": "smallforest",
		"goal_text": "Lass 5 Wälder wachsen", "limit": 15, "stars": [5, 9],
		"unlocked": _L2, "rain_start": 1, "rain_every": 6, "gift": true, "onboard_hint": true,
		"new": {"key": "regen", "icon": "rain", "title": "Neu: Regen", "text": "Tipp Regen, dann eine Wiese."},
		"coach": ["Heute wächst Wald!",
			"Wächst nichts, brennt es. Regen löscht."],
		"coach_tool": "Tipp Regen, dann eine Wiese."},
	{"title": "Tiere", "icon": "animals",
		"intro": "Heute kommen Tiere.",
		"goal_type": "make", "goal_kinds": [FieldData.ANIMALS], "goal_target": 3, "goal_icon": "animals",
		"goal_text": "Erschaffe 3 Tiere", "limit": 12, "stars": [7, 10],
		"unlocked": _L3, "rain_start": 1, "rain_every": 6, "gift": true,
		"new": {"key": "leben", "icon": "animals", "title": "Neu: Leben", "text": "Großer Wald bringt Tiere."},
		"coach": ["Großer Wald bringt Tiere."]},
	{"title": "Menschen", "icon": "hut",
		"intro": "Heute kommen Menschen.",
		"goal_type": "make", "goal_kinds": [FieldData.HUT], "goal_target": 4, "goal_icon": "hut",
		"goal_text": "Baue 4 Hütten", "limit": 14, "stars": [8, 11],
		"unlocked": _L4, "rain_start": 1, "rain_every": 6, "gift": true,
		"wishes": true, "wish_types": ["wald", "tiere", "regen"], "wish_from": 2, "wish_every": 3,
		"new": {"key": "menschen", "icon": "hut", "title": "Neu: Menschen", "text": "Aus Tieren werden Hütten."},
		"coach": ["Aus Tieren werden Hütten.", "Erfüll Wünsche, dann wächst ihr Haus."]},
	{"title": "Nahrung", "icon": "field",
		"intro": "Die Menschen haben Hunger.",
		"goal_type": "wishes", "goal_target": 3, "goal_icon": "wish",
		"goal_text": "Erfülle 3 Wünsche", "limit": 18, "stars": [10, 14],
		"unlocked": _L5, "choices": [FieldData.MEADOW], "rain_start": 1, "rain_every": 6, "gift": true,
		"wishes": true, "wish_types": _ALL_WISHES, "wish_from": 1, "wish_every": 3, "scale": true, "scale_visible": false,
		"new": {"key": "wahl", "icon": "field", "title": "Neu: Du entscheidest!", "text": "Wald oder Acker? Du wählst."},
		"coach": ["Wald oder Acker? Du wählst."]},
	{"title": "Glaube", "icon": "church",
		"intro": "Die Menschen beten zu dir.",
		"goal_type": "faith", "goal_target": 150, "goal_icon": "faith",
		"goal_text": "Sammle 150 Glauben", "rule_line": "Kein Krieg!", "limit": 13, "stars": [8, 11],
		"unlocked": _L6, "choices": [FieldData.MEADOW, FieldData.VILLAGE], "rain_start": 1, "rain_every": 6, "gift": true,
		"wishes": true, "wish_types": _ALL_WISHES, "wish_from": 2, "wish_every": 3, "scale": true, "scale_visible": false,
		"income": true, "war": true, "no_war": true,
		"new": {"key": "glaube", "icon": "church", "title": "Neu: Glaube", "text": "Kirchen geben Glauben."},
		"coach": ["Zwei Kirchen nebeneinander: Krieg!"]},
	{"title": "Ruhe", "icon": "balance",
		"intro": "Halte die Welt im Gleichgewicht.",
		"goal_type": "faith", "goal_target": 250, "goal_green": true, "goal_icon": "faith",
		"goal_text": "250 Glauben, Waage grün", "limit": 13, "stars": [9, 11],
		"unlocked": _L7, "choices": [FieldData.MEADOW, FieldData.VILLAGE, FieldData.TOWN], "rain_start": 1, "rain_every": 6,
		"gift": true, "wishes": true, "wish_types": _ALL_WISHES, "wish_from": 2, "wish_every": 3, "scale": true,
		"income": true, "war": true, "smog": true, "strike": true,
		"new": {"key": "industrie", "icon": "industry", "title": "Neu: Industrie", "text": "Gibt Glauben, macht Smog."},
		"coach": ["Halte die Waage im Grünen."]},
]

## Feste Sätze für die Oberfläche (einfaches Deutsch, du-Form). %d = Zahl.
const TEXT = {
	"title": "Die Schöpfung in 7 Tagen",
	"day": "Tag %d",
	"day_title": "Tag %d · %s",
	"limit": "in %d Drehungen",
	"stars3": "★★★ in %d Drehungen",
	"go": "Los!",
	"go_demo": "Zeig's mir",
	"demo_caps": "Schau zu!",
	"demo_title": "Erst zuschauen",
	"demo_text": "3 gleiche in eine Reihe.",
	"left": "Noch %d Drehungen.",
	"balance_needed": "Waage ins Grüne",
	"balance_ok": "Glaube · Waage",
	"balance_goal": "Glaube · Waage",
	"won": "Tag %d geschafft!",
	"won_in": "in %d Drehungen",
	"won_more": "in %d Drehungen · ★★★ bis %d",
	"next": "Weiter zu Tag %d · %s",
	"again": "Nochmal",
	"again_more": "für mehr Sterne",
	"lost_twists": "Keine Drehungen mehr",
	"lost_war": "Krieg!",
	"lost_war_body": "Halte Kirchen auseinander.",
	"lost_try": "Diesmal nicht.",
	"lost_close": "Fast geschafft!",
	"lost_body": "Neue Welt, neues Glück.",
	"mercy_next": "Nächstes Mal +%d Drehungen",
	"mercy": "+%d Drehungen geschenkt",
	"complete": "Deine Welt ist vollendet!",
	"stars_total": "%d von %d Sternen",
	"free_open": "Freies Spiel ist offen!",
	"free": "Freies Spiel",
	"free_locked": "Nach Tag 7",
	"locked": "Erst Tag %d schaffen.",
	"banner_new": "Neu: 7 Tage Schöpfung",
	"rest": "Wächst erst später.",
	# Täglich spielen (GDPD_TAEGLICH_CHARAKTER.md 1, 2): neutrale Systemtexte (die Sätze des Charakters macht Voice)
	"today_new": "Heute neu",
	"today_done": "Geschafft!",
	"today": "Heute",
	"tomorrow": "Morgen",
	"locked_on": "Ab %s.",
	"day_tag": "Tag %d: %s",
	"tomorrow_next": "Morgen geht's weiter: Tag %d · %s",
	"wdt": "Welt des Tages",
	"wdt_caps": "Welt des Tages · %s",
	"wdt_intro": "Neue Welt für heute.",
	"wdt_tomorrow": "Morgen gibt es eine neue Welt.",
	"wdt_first_tomorrow": "Morgen: deine erste Welt des Tages",
	"wdt_tag": "die Welt des Tages",
	"countdown": "Neuer Tag in %d Std. %d Min.",
	"countdown_late": "Morgen früh",
	"build": "Weiterbauen",
	"again_stars": "Nochmal · mehr Sterne",
	"build_coin": "+1 Münze",
	"to_overview": "Zur Übersicht",
	"streak": "Serie %d · Rekord %d",
	"record": "Rekord %d",
	"streak_one": "Serie beginnt",
	"streak_days": "%d Tage in Folge!",
	"week": "Diese Woche",
	"shield": "Serienschutz",
	"shield_text": "Rettet deine Serie. Du hast %d/2.",
	"shield_buy": "Kaufen · %d Münzen",
	"shield_full": "Du hast genug Serienschutz.",
	"shield_missing": "Dir fehlen %d Münzen.",
	"shield_won": "+1 Serienschutz",
	"shield_coins": "+%d Münzen",
	"test_next_day": "Nächster Tag (Test)",
	"test_now": "Test: Jetzt ist %s.",
}

static var _pools := {}        # Paket → {"days": {"1": [...], …}, "code": "…"}
static var _packs := {}        # weitere Pakete (aus res://data/packs), id → {"id", "title", "days": [...]}


# --- Pakete --------------------------------------------------------------------------------

## Alle Pakete: zuerst die Schöpfung, dann was in res://data/packs liegt.
static func pack_ids() -> Array:
	_load_packs()
	var out: Array = [PACK_ID]
	for k in _packs:
		out.append(str(k))
	return out


static func pack_title(pack: String = PACK_ID) -> String:
	if pack == PACK_ID:
		return PACK_TITLE
	_load_packs()
	return str((_packs.get(pack, {}) as Dictionary).get("title", pack))


static func _load_packs() -> void:
	if not _packs.is_empty() or not DirAccess.dir_exists_absolute(PACKS_DIR):
		return
	for fn in DirAccess.get_files_at(PACKS_DIR):
		if not str(fn).ends_with(".json"):
			continue
		var data = _read_json(PACKS_DIR + "/" + str(fn))
		if data is Dictionary and (data as Dictionary).has("days"):
			_packs[str((data as Dictionary).get("id", str(fn).get_basename()))] = data


static func _days_of(pack: String) -> Array:
	if pack == PACK_ID:
		return DAYS
	_load_packs()
	return (_packs.get(pack, {}) as Dictionary).get("days", [])


## So viele Tage hat das Paket.
static func count(pack: String = PACK_ID) -> int:
	return _days_of(pack).size()


# --- Tage -----------------------------------------------------------------------------------

## Die Regeln von Tag n (1 …) als Dictionary für GameState.setup_day: BASE + Tag, dazu "day" und "pack".
## Ein Ziel im Kurzformat der Spec (["make", [1], 8], ["wishes", 3], ["faith", 150, "green"]) wird umgeschrieben.
static func config(n: int, pack: String = PACK_ID) -> Dictionary:
	var days := _days_of(pack)
	if n < 1 or n > days.size():
		return {}
	var c: Dictionary = BASE.duplicate(true)
	var d: Dictionary = days[n - 1]
	for k in d:
		if str(k) == "boards":
			continue
		c[k] = d[k].duplicate(true) if (d[k] is Array or d[k] is Dictionary) else d[k]
	if c.get("goal") is Array:
		var g: Array = c["goal"]
		c["goal_type"] = str(g[0])
		if str(g[0]) == "make":
			c["goal_kinds"] = g[1]
			c["goal_target"] = int(g[2])
		else:
			c["goal_target"] = int(g[1])
			c["goal_green"] = g.size() > 2 and str(g[2]) == "green"
	if c.get("rain") is Array:
		c["rain_start"] = int((c["rain"] as Array)[0])
		c["rain_every"] = int((c["rain"] as Array)[1])
	# Zahlen aus der Balance in die Texte ({strike} = Preis des Gewitters)
	var nw: Dictionary = c.get("new", {})
	if nw.has("text"):
		nw["text"] = str(nw["text"]).replace("{strike}", str(Balance.STRIKE_COST))
	c["day"] = n
	c["pack"] = pack
	return c


## Sterne für einen gewonnenen Tag nach den benutzten Drehungen.
static func stars_for(cfg: Dictionary, used: int) -> int:
	var st: Array = cfg.get("stars", [0, 0])
	if used <= int(st[0]):
		return 3
	if used <= int(st[1]):
		return 2
	return 1


## „Lass 8 Wiesen wachsen“ (die Zeile auf der Ziel-Karte und im Chip).
static func goal_line(cfg: Dictionary) -> String:
	if cfg.has("goal_text"):
		return str(cfg["goal_text"])
	var t := str(cfg.get("goal_type", ""))
	var n := int(cfg.get("goal_target", 0))
	if t == "make":
		var ks: Array = cfg.get("goal_kinds", [])
		var k: int = int(ks[0]) if not ks.is_empty() else FieldData.MEADOW
		return "Lass %d %s wachsen" % [n, FieldData.kind_plural(k) if n != 1 else FieldData.kind_name(k)]
	if t == "wishes":
		return "Erfülle %d Wünsche" % n
	if bool(cfg.get("goal_green", false)):
		return "%d Glauben, Waage grün" % n
	return "Sammle %d Glauben" % n


static func limit_line(twists: int) -> String:
	return str(TEXT["limit"]) % twists


static func star_line(cfg: Dictionary) -> String:
	return str(TEXT["stars3"]) % int((cfg.get("stars", [0, 0]) as Array)[0])


# --- Bretter (Pools) ---------------------------------------------------------------------------

static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


static func _pool(n: int, pack: String) -> Array:
	if pack != PACK_ID:
		var days := _days_of(pack)
		if n < 1 or n > days.size():
			return []
		return (days[n - 1] as Dictionary).get("boards", [])
	if not _pools.has(pack):
		var data = _read_json(BOARDS_PATH)
		_pools[pack] = data if data is Dictionary else {}
	var dd: Dictionary = (_pools[pack] as Dictionary).get("days", {})
	return dd.get(str(n), [])


## So viele Start-Bretter hat Tag n (20 im ersten Paket).
static func pool_size(n: int, pack: String = PACK_ID) -> int:
	return _pool(n, pack).size()


## Brett index (wird mit der Pool-Größe umgebrochen) von Tag n:
## {"kinds": Array (54 Arten), "seed", "index", "solved_in", "stars", "solution": [[typ, arg, {Art: Option}], …]}.
## Kein Pool (Datei fehlt): {}.
static func board(n: int, index: int, pack: String = PACK_ID) -> Dictionary:
	var pool := _pool(n, pack)
	if pool.is_empty():
		return {}
	var i := posmod(index, pool.size())
	var e: Dictionary = pool[i]
	return {"kinds": decode(str(e.get("board", ""))), "seed": int(e.get("seed", 1)), "index": i,
		"solved_in": int(e.get("solved_in", 0)), "stars": int(e.get("stars", 0)), "solution": e.get("solution", [])}


## Brett-Text (ein Zeichen je Feld, siehe CODE) → Arten. Unbekannte Zeichen werden Wasser.
static func decode(text: String) -> Array:
	var out: Array = []
	for i in text.length():
		var k := CODE.find(text[i])
		out.append(k if k >= 0 else FieldData.WATER)
	return out


static func encode(kinds: Array) -> String:
	var s := ""
	for k in kinds:
		s += CODE[clampi(int(k), 0, CODE.length() - 1)]
	return s


## Eine Aktion aus einer Pool-Lösung als Aktion für GameState.play: ["twist", [a, l, t], {"1": 1}] →
## [{"type": "twist", "axis", "layer", "turns"}, {1: 1}]. Regen/Gewitter: {"type": "rain"|"strike", "field"}.
static func solution_step(step: Array) -> Array:
	var t := str(step[0])
	var act := {}
	if t == "twist":
		var m: Array = step[1]
		act = {"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])}
	else:
		act = {"type": t, "field": int(step[1])}
	var ans := {}
	var raw: Dictionary = step[2] if step.size() > 2 and step[2] is Dictionary else {}
	for k in raw:
		ans[int(str(k))] = int(raw[k])
	return [act, ans]
