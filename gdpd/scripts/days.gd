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
## h Haus, D Dorf, S Stadt, K Kirche, G Großstadt, I Industrie, M Metropole, P Paradies, o Wasser, R Stein.
const CODE := FieldData.CODE

const E := FieldData.EMPTY
const W := FieldData.MEADOW
const F := FieldData.FOREST
const A := FieldData.FIELD
const T := FieldData.ANIMALS
const H := FieldData.HUT
const D := FieldData.VILLAGE
const S := FieldData.TOWN
const K := FieldData.CHURCH
const I := FieldData.INDUSTRY
const R := FieldData.STONE

## Was an allen Tagen gilt (GDPD_BALANCE_2.md 5.2; jeder Tag überschreibt davon, was er braucht). Die neuen Regeln
## (Erschaffen + Gedeihen) schaltet "rows" ein: nur diese Arten bilden heute zählende Reihen, next8 sagt, was daraus
## wird, top die höchste Menschen-Stufe, die heute durch Gedeihen entsteht. Keine Herzen, keine Diagonalen, keine
## Wünsche, keine Waage, kein „3 Fehlversuche → Feuer“; „Jede Reihe wächst nur einmal“ (once) gilt immer.
const BASE = {
	"choices": [], "fire": false, "rain_start": 1, "rain_every": 6, "gift": false,
	"wishes": false, "wish_types": [], "wish_from": 2, "wish_every": 3,
	"scale": false, "income": false, "war": false, "no_war": false, "smog": false, "strike": false,
	"goal_kinds": [], "goal_green": false, "rule_line": "", "rule_icon": "swords", "coach": [], "coach_demo": "",
	"onboard_hint": false, "once": true,
	"rows": [], "next8": {E: W, W: F, F: T, T: H}, "consume": true, "top": -1,
	"needs": {H: ["food"], D: ["food", "work"], S: ["food", "work", "faith"]},
	"lightning": 0, "lightning_from": 2, "war8": false, "meteor": false, "smog8": false, "flood8": false,
	"rain_acker": false, "rain_kinds": [W, F], "grow_after": 2, "shrink_after": 4, "flood_at": 5, "overnight": [],
}

## Die 7 Tage (GDPD_BALANCE_2.md 5): eine neue Sache je Tag, höchstens 3 Arten, die heute wachsen, und jeder Tag
## etwas schwerer. goal: ["make", [Arten], n] (so oft wächst etwas zu dieser Art) oder ["satt", Art, n] (so viele
## Felder dieser Art sind am Ende einer Drehung satt). stars = [★★★ bis, ★★ bis] (Drehungen). new: das Neue des Tages
## (Aufdecken). overnight: [[von, zu], …] – „Neuer Morgen“: ein paar Felder der neuen Welt wachsen sichtbar aus der
## niedrigeren Art herauf (nur die Darstellung, 5.6; die Welt jedes Tages ist ein neues Pool-Brett).
## unlocked: was es heute geben kann (Texte „… erst ab Tag n“).
const DAYS = [
	{"title": "Land", "icon": "meadow",
		"intro": "Mach aus Erde Wiesen!",
		"goal": ["make", [W], 8], "goal_icon": "meadow", "goal_text": "Lass 8 Wiesen wachsen", "limit": 15, "stars": [4, 6],
		"rule_line": "Nur gerade Reihen · Wasser wächst nie", "rule_icon": "info",
		"rows": [E], "rain_start": 0, "rain_every": 0, "unlocked": [E, W], "onboard_hint": true,
		"new": {"key": "drehen", "icon": "meadow", "title": "Neu: Drehen", "text": "Bring 3 gleiche in eine Reihe."},
		"tutorial": {"axis": 0, "layer": 1, "turns": 1},
		"coach": ["Bring 3 gleiche in eine Reihe.", "Super! Eine Wiese.",
			"Jetzt du! Wisch die leuchtende Reihe.", "Gut so! Deine Welt."],
		# „Schau zu!“ (Eingabe gesperrt): kein Befehl, sondern was die Hand gleich zeigt
		"coach_demo": "Schau: 3 gleiche in eine Reihe."},
	{"title": "Pflanzen", "icon": "rain",
		"intro": "Heute wachsen Pflanzen.",
		"goal": ["make", [F], 5], "goal_icon": "smallforest", "goal_text": "Lass 5 Wälder wachsen", "limit": 14, "stars": [5, 7],
		"rows": [E, W], "rain_start": 1, "rain_every": 6, "rain_kinds": [W, F], "unlocked": [E, W, F], "onboard_hint": true,
		"overnight": [[E, W]], "overnight_line": "Erde wird Wiese",
		"new": {"key": "regen", "icon": "rain", "title": "Neu: Regen", "text": "Tipp Regen, dann eine Wiese."},
		"coach": ["Heute wächst Wald!", "Regen macht Wald."],
		"coach_tool": "Tipp Regen, dann eine Wiese."},
	{"title": "Tiere", "icon": "animals",
		"intro": "Heute kommen Tiere.",
		"goal": ["make", [T], 4], "goal_icon": "animals", "goal_text": "Erschaffe 4 Tiere", "limit": 10, "stars": [4, 6],
		"rows": [W, F], "rain_start": 1, "rain_every": 4, "rain_kinds": [F], "lightning": 2, "lightning_from": 1,
		"unlocked": [W, F, T], "overnight": [[E, W]], "overnight_line": "Erde wird Wiese",
		"new": {"key": "blitz", "icon": "lightning", "title": "Neu: Blitz", "text": "Regen löscht Feuer."},
		"coach": ["Blitz kommt! Regen schützt."]},
	{"title": "Menschen", "icon": "hut",
		"intro": "Heute kommen Menschen.",
		"goal": ["satt", H, 3], "goal_icon": "hut", "goal_text": "Versorge 3 Hütten", "limit": 14, "stars": [6, 9],
		"rows": [W, F, T], "top": H, "rain_start": 1, "rain_every": 5, "rain_kinds": [F], "lightning": 4, "lightning_from": 3,
		"unlocked": [W, F, T, H], "overnight": [[W, F]], "overnight_line": "Wiesen werden Wald",
		"new": {"key": "menschen", "icon": "hut", "title": "Neu: Menschen", "text": "Menschen brauchen Nahrung."},
		"coach": ["Tiere neben die Hütte."]},
	{"title": "Arbeit", "icon": "village",
		"intro": "Die Menschen wollen arbeiten.",
		"goal": ["satt", D, 3], "goal_icon": "village", "goal_text": "Mach 3 Dörfer satt", "limit": 13, "stars": [4, 7],
		"rows": [F, T], "top": D, "rain_start": 1, "rain_every": 5, "rain_kinds": [F], "rain_acker": true,
		"lightning": 4, "lightning_from": 3, "unlocked": [W, F, A, T, H, D, R],
		"overnight": [[T, H]], "overnight_line": "Tiere werden Hütten",
		"new": {"key": "arbeit", "icon": "village", "title": "Neu: Arbeit", "text": "Dorf braucht Nahrung und Arbeit."},
		"coach": ["Wald oder Stein gibt Arbeit.", "Satt? Dann wächst es.", "Regen neben Hütten: Acker."]},
	{"title": "Glaube", "icon": "church",
		"intro": "Die Menschen beten zu dir.",
		"goal": ["satt", S, 3], "goal_icon": "town", "goal_text": "Mach 3 Städte satt", "limit": 12, "stars": [4, 6],
		"rule_line": "Kirche an Kirche: Krieg!",
		"rows": [T], "top": S, "rain_start": 1, "rain_every": 5, "rain_kinds": [F], "rain_acker": true,
		"war8": true, "meteor": true, "unlocked": [W, F, A, T, H, D, S, K, R],
		"overnight": [[H, D]], "overnight_line": "Hütten werden Dörfer",
		"new": {"key": "glaube", "icon": "church", "title": "Neu: Glaube", "text": "Kirche an Kirche: Krieg!"},
		"coach": ["Stadt braucht eine Kirche.", "Meteor bereit."]},
	{"title": "Gleichgewicht", "icon": "balance",
		"intro": "Schütze jetzt die Natur.",
		"goal": ["satt", S, 3], "goal_icon": "town", "goal_text": "Mach 3 Städte satt", "limit": 11, "stars": [4, 6],
		"rule_line": "Zu viel Stadt: Flut!",
		"rows": [T], "top": S, "rain_start": 1, "rain_every": 5, "rain_kinds": [F], "rain_acker": true,
		"war8": true, "meteor": true, "smog8": true, "flood8": true, "unlocked": [W, F, A, T, H, D, S, K, I, R],
		"overnight": [[D, S]], "overnight_line": "Dörfer werden Städte",
		"new": {"key": "fabrik", "icon": "industry", "title": "Neu: Fabriken", "text": "Zu viel Stadt: Flut!"},
		"coach": ["Fabrik weg vom Wald."]},
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
	"again_stars": "Nochmal · mehr Sterne",
	"to_overview": "Zur Übersicht",
	"streak": "Serie %d · Rekord %d",
	"record": "Rekord %d",
	"streak_one": "Serie beginnt",
	"streak_days": "%d Tage in Folge!",
	"week": "Diese Woche",
	"shield": "Serienschutz",
	"shield_text": "Rettet deine Serie. Du hast %d/2.",
	"shield_buy": "Kaufen · %d Punkte",
	"shield_full": "Du hast genug Serienschutz.",
	"shield_missing": "Dir fehlen %d ✦",
	"shield_won": "+1 Serienschutz",
	"shield_coins": "+%d Punkte",
	"test_next_day": "Nächster Tag (Test)",
	"test_now": "Test: Jetzt ist %s.",
	# GDPD_BALANCE_2.md 5.6, 6, 9
	"overnight": "Neuer Morgen",
	"extra": "Extra: %s",
	"build_on": "Bau weiter",
	"satt": "Satt!",
	"satt_goal": "%s satt",
	"spent_coach": "Diese Reihe ist schon gewachsen.",
	"once_rule": "Jede Reihe wächst nur einmal.",
	"consume": "3 Tiere · 1 Hütte",
	"thrive_hut": "Hütte wird Dorf",
	"thrive_village": "Dorf wird Stadt",
	"starve_village": "Dorf schrumpft",
	"starve_town": "Stadt schrumpft",
	"bolt_warn": "Blitz kommt!",
	"bolt": "Feuer!",
	"bolt_cancel": "Regen schützt",
	"ignite": "Feuer breitet sich aus",
	"rain_out": "Gelöscht!",
	"war_start": "Krieg droht!",
	"war_start_line": "Trenn die Kirchen",
	"war_hit": "Krieg!",
	"war_end": "Frieden",
	"meteor": "Meteor!",
	"smog": "Smog!",
	"flood_warn": "Das Meer steigt!",
	"flood_warn_line": "Zu viel Stadt",
	"flood": "Flut!",
	"people_caps": "Keine Reihe",
	"people_line": "Menschen wachsen durch Nachbarn",
	"done_caps": "Heute keine Reihe",
	"stone_caps": "Stein wächst nie",
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
		elif str(g[0]) == "satt":
			c["goal_kinds"] = [int(g[1])]
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
	if c.has("rows") and not (c["rows"] as Array).is_empty():
		# Neue Regeln: welche Arten bilden an einem späteren Tag Reihen? (Sie ruhen heute: „… erst ab Tag n“.)
		var later: Array = []
		for j in range(n, days.size()):
			for k in (days[j] as Dictionary).get("rows", []):
				if not later.has(int(k)) and not (c["rows"] as Array).has(int(k)):
					later.append(int(k))
		c["later_rows"] = later
	else:
		c.erase("rows")           # ein Paket mit alten Tag-Regeln (ohne rows)
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
	if t == "satt":
		var sk: Array = cfg.get("goal_kinds", [])
		var kk: int = int(sk[0]) if not sk.is_empty() else FieldData.HUT
		return "Mach %d %s satt" % [n, FieldData.kind_plural(kk) if n != 1 else FieldData.kind_name(kk)]
	if bool(cfg.get("goal_green", false)):
		return "%d Glauben, Waage grün" % n
	return "Sammle %d Glauben" % n


## Weiterbauen: die Extra-Aufgabe mit n statt der Zahl der Aufgabe, kurz für den Chip („Extra: 11 Wiesen“,
## „Extra: 4 Hütten satt“).
static func extra_line(cfg: Dictionary, n: int) -> String:
	var t := str(cfg.get("goal_type", ""))
	var ks: Array = cfg.get("goal_kinds", [])
	if (t == "make" or t == "satt") and not ks.is_empty():
		var k := int(ks[0])
		var noun := FieldData.kind_plural(k) if n != 1 else FieldData.kind_name(k)
		return str(TEXT["extra"]) % ("%d %s%s" % [n, noun, " satt" if t == "satt" else ""])
	var txt := goal_line(cfg)
	var rx := RegEx.new()
	rx.compile("\\d+")
	var m := rx.search(txt)
	if m != null:
		txt = txt.substr(0, m.get_start()) + str(n) + txt.substr(m.get_end())
	return str(TEXT["extra"]) % txt


## „Neuer Morgen“ (5.6): höchstens OVERNIGHT_MAX Felder dieses Bretts wachsen sichtbar aus der niedrigeren Art herauf
## (gleichmäßig über die passenden Felder verteilt). [{"field", "from", "kind"}]. Leer an Tag 1 und ohne overnight-Liste.
const OVERNIGHT_MAX := 4
## Höchstens so viele verschiedene Arten (ohne Wasser) liegen am Morgen auf einem Pool-Brett (Tag → Zahl,
## GDPD_BALANCE_2.md 5.1): nicht zu viele verschiedene Felder auf einmal.
const VISIBLE_MAX := {1: 1, 2: 2, 3: 2, 4: 3, 5: 5, 6: 6, 7: 6}


## Verschiedene Arten (ohne Wasser) auf einem Brett.
static func visible_kinds(kinds: Array) -> int:
	var seen := {}
	for k in kinds:
		if int(k) != FieldData.WATER:
			seen[int(k)] = true
	return seen.size()


static func overnight_changes(cfg: Dictionary, kinds: Array) -> Array:
	var all: Array = []
	var pairs: Array = cfg.get("overnight", [])
	for i in kinds.size():
		for pr in pairs:
			if int((pr as Array)[1]) == int(kinds[i]):
				all.append({"field": i, "from": int((pr as Array)[0]), "kind": int(kinds[i])})
				break
	if all.size() <= OVERNIGHT_MAX:
		return all
	var out: Array = []
	for j in OVERNIGHT_MAX:
		out.append(all[int(float(j) * float(all.size()) / float(OVERNIGHT_MAX))])
	return out


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
