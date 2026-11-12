class_name Campaign
extends RefCounted
## Die Kampagne „Erdgeschichte“ (docs/GDPD_ERDGESCHICHTE.md): Zeitalter der Erdgeschichte mit vielen Leveln, von der
## glühenden Erde über das Kambrium, die Saurier, den Einschlag und die Eiszeit bis zu Feuer, Ackerbau, Glaube, Städten,
## Industrie und Gleichgewicht. Ein neues Level je Spieltag, danach die Welt des Tages. Offen erweiterbar: Zeitalter und
## Level sind Daten. Nur statische Funktionen, keine Nodes.
##
## Die Level-Daten (Zeitalter, Regeln, Ziele, Sterne-Grenzen, Texte, Pools mit je einer Lösung, alte → neue Level) kommen
## aus data/kampagne_erde.json, exportiert aus dem Python-Modell (gdpd_sim/b6/export_gd10.py, Looks: b7/mk_data.py).
## GameState.setup_level(Campaign.config(n), board["kinds"], board["seed"]).
## Die Welt läuft innerhalb eines Zeitalters weiter (carry); ein neues Zeitalter beginnt auf einem frischen Pool-Brett.
## Nie spoilern: Titel, Symbol, Geschichte und „Neu“-Karte eines Levels erst, wenn es offen ist; ein Zeitalter erst,
## wenn sein erstes Level offen ist (tile, era_tile).
## „Akt“ (act) heißt in den Daten und älteren Teilen der Oberfläche die Nummer des Zeitalters (1 …).

const DATA_PATH := "res://data/kampagne_erde.json"
## Veteranen der 7 Tage (13.1): höchster geschaffter alter Tag 1 … 7 → Schnellstart bis zu diesem Level (alte Level
## 4, 8, 12, 19, 24, 26, 28 → neu, OLD_TO_NEW).
const FAST_TRACK = [0, 4, 9, 21, 25, 49, 53, 57]

static var _data: Dictionary = {}
static var _vstate: Dictionary = {}     # Level → GameState zum Prüfen der Startbedingungen (nur Arten wechseln)
static var _vcfg: Dictionary = {}
## Zahl der Level in den Daten (nie eine Konstante im Code: neue Zeitalter kommen als Daten dazu).
static var COUNT: int = _load_count()
## Welt des Tages nach der Kampagne (10): ein starkes Level je Zeitalter (aus den Daten).
static var WDT: Array = _load_wdt()
## Symbol je Zeitalter (Nummer → Symbol-Name).
static var ICON: Dictionary = _load_icons()

const TEXT = {
	"title": "Erdgeschichte",
	"act_caps": "Zeitalter %d",
	"locked": "Morgen wartet etwas Neues",
	"locked_short": "?",
	"tomorrow": "Morgen geht es weiter",
	"fast_track": "Schnellstart: %d heute",
	"thanks": "Danke fürs Mitspielen: +%d Punkte",
	"sealed_first": "Versorgt bleibt versorgt.",
	"overnight": "Neuer Morgen",
	"wdt": "Welt des Tages",
	"wdt_caps": "Welt des Tages · %s",
	"done": "Geschafft",
	"build_on": "Bau weiter",
	"steps": "%d Schritte",
	"star_next": "★★★ bis %d",
	"star_next2": "★★ bis %d",
	"loss": "−1 %s",
	"mercy": "Hilfe von oben",
	"rest": "Gleichgewicht hält",
	"unrest": "Unruhe!",
	"topup": "Über Nacht: +%d %s",
	"overnight_line": "Über Nacht gewachsen",
	"fresh": "Heute eine frische Welt",
	"calmer": "Die Lava hat sich verteilt",
	"calmer_ice": "Das Eis hat sich verteilt",
	"rescue_dead": "Sackgasse! Ich helfe dir.",
	"rescue_few": "Zu wenig %s. Ich helfe.",
	"rescue_stall": "Hängst du fest? Ich helfe dir.",
	"rescue_rows": "Keine Reihe möglich. Ich helfe.",
	"gift_pill": "Geschenk: +%d %s",
	"hold_last": "Hält durch!",
	"night_pair": "Über Nacht: %s → %s",
	"gift": "Geschenk",
	"new_world": "Neue Welt",
	"play_on": "Weiterspielen",
	"catchup": "Nachholen",
	"bigger": "Die Welt ist größer geworden.",
	"new_levels": "Neue Level!",
	"era_new": "Neues Zeitalter",
	"later": "Kommt später",
	"catchup_caps": "Nachholen · Level %d",
	"era_done": "%s geschafft!",
}
## Pillen der Ereignisse (Vertrag 8; höchstens eine je Runde, kurz). Die Jagd nennt ihre Jäger: pill().
const PILL = {
	"volcano_warn": ["Vulkan grollt!", "Teil die Lava"], "erupt": ["Ausbruch!", ""], "volcano_calm": ["Abgewendet", ""],
	"bolt_warn": ["Blitz droht!", "Wasser an den Wald"], "bolt": ["Feuer!", ""], "bolt_cancel": ["Regen schützt", ""],
	"hunger_warn": ["Hunger!", "Bring Futter"], "starve": ["Verhungert", ""], "pack_warn": ["Rudel jagt!", "Trenn die Raubtiere"],
	"pack_hunt": ["Gejagt!", ""], "smog_warn": ["Smog droht!", ""], "polluted": ["Smog!", ""], "spawn": ["Landgang!", ""],
	"steam": ["+1 Regen", ""], "meteor_ready": ["Meteor bereit", ""], "mercy": ["Hilfe von oben", ""],
	"need_sealed": ["Versorgt bleibt versorgt.", ""],
	"glacier_warn": ["Gletscher wächst!", "Teil das Eis"], "freeze": ["Eis!", ""], "glacier_calm": ["Abgewendet", ""],
	"impact_warn": ["Meteor kommt!", ""], "impact": ["Einschlag!", ""],
	"hold_last": ["Hält durch!", ""],
}
## Jagd-Warnung je Jäger (pack_warn mit "hunter").
const PILL_HUNT = {FieldData.PRED: ["Rudel jagt!", "Trenn die Raubtiere"],
	FieldData.REX: ["Raubsaurier jagen!", "Trenn die Raubsaurier"], FieldData.EARLY: ["Die Tiere fliehen!", "Trenn die Jäger"]}
## Wachsen durch Nachbarn (thrive): Pille je Art (von).
const THRIVE_PILL = {FieldData.LAVA: "Lava wird Fels", FieldData.WATER: "Ursuppe entsteht",
	FieldData.SOUP: "Ursuppe lebt!", FieldData.EMPTY: "Moos wächst", FieldData.MOSS: "Moos wird Farn",
	FieldData.MEADOW: "Wiese wird Wald", FieldData.SEED: "Saat reift", FieldData.FOREST: "Vögel nisten",
	FieldData.HUT: "Hütte wird Dorf", FieldData.VILLAGE: "Dorf wird Stadt", FieldData.JELLY: "Panzer wächst",
	FieldData.FERN: "Farn wird Wald", FieldData.ICE: "Eis taut", FieldData.ANIMALS: "Affen klettern",
	FieldData.EARLY: "Feuer brennt!"}
## Wachsen durch Nachbarn, wenn eine Art mehrere Wege hat: "von>zu" → Pille (zuerst geprüft, thrive_pill).
const THRIVE_PILL_TO = {"23>29": "Es summt!", "23>2": "Farn wird Wald", "2>34": "Flugsaurier fliegt",
	"2>24": "Vögel nisten", "0>1": "Asche wird Wiese", "0>22": "Moos wächst"}


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = Days._read_json(DATA_PATH)
		_data = d if d is Dictionary and (d as Dictionary).get("config") is Dictionary else {"config": {}, "levels": {}, "eras": []}
		if not (_data.get("levels") is Dictionary):
			_data["levels"] = {}
		if not (_data.get("eras") is Array):
			_data["eras"] = []
	return _data


static func _load_count() -> int:
	var n := 0
	var cs: Dictionary = data()["config"]
	while cs.has(str(n + 1)):
		n += 1
	return n


static func _load_wdt() -> Array:
	var out: Array = []
	var w: Variant = data().get("wdt", [])
	if w is Array:
		for t in w:
			if int(t) >= 1 and int(t) <= COUNT:
				out.append(int(t))
	return out


static func _load_icons() -> Dictionary:
	var out := {}
	for e in data()["eras"]:
		out[int((e as Dictionary).get("index", 0))] = str((e as Dictionary).get("icon", "info"))
	return out


static func count() -> int:
	return COUNT


static func valid(n: int) -> bool:
	return n >= 1 and n <= COUNT and (data()["config"] as Dictionary).has(str(n))


## Regeln und Texte von Level n (die Daten des Modells plus "level", "act_name" = Name des Zeitalters, "goal_line").
## {} wenn es n nicht gibt.
static func config(n: int) -> Dictionary:
	var cs: Dictionary = data()["config"]
	if not cs.has(str(n)):
		return {}
	var c: Dictionary = (cs[str(n)] as Dictionary).duplicate(true)
	c["level"] = n
	c["act_name"] = act_name(int(c.get("act", 1)))
	c["era_title"] = c["act_name"]
	c["goal_line"] = goal_line(c)
	return c


# --- Zeitalter (2) ---------------------------------------------------------------------------------

## Die Zeitalter in ihrer Reihenfolge: [{"id", "title", "line", "levels", "index", "look", "icon"}].
static func eras() -> Array:
	return data()["eras"]


static func era_count() -> int:
	return eras().size()


## Zeitalter i (1 …) als Dictionary ({} = keins).
static func era_info(i: int) -> Dictionary:
	var es := eras()
	if i < 1 or i > es.size():
		return {}
	return es[i - 1]


## Nummer des Zeitalters von Level n (1 …; 0 = keins). In den Daten heißt sie "act".
static func era_index(n: int) -> int:
	var c: Dictionary = (data()["config"] as Dictionary).get(str(n), {})
	return int(c.get("act", 0))


## Schlüssel des Zeitalters von Level n („saurier“, "" = keins).
static func era_of(n: int) -> String:
	var c: Dictionary = (data()["config"] as Dictionary).get(str(n), {})
	return str(c.get("era", ""))


## Die Level eines Zeitalters (aufsteigend).
static func era_levels(i: int) -> Array:
	var out: Array = []
	for n in range(1, COUNT + 1):
		if era_index(n) == i:
			out.append(n)
	return out


## Das erste Level seines Zeitalters? (Dort beginnt die Welt auf einem frischen Pool-Brett, die Zeitalter-Karte kommt.)
static func first_of_era(n: int) -> bool:
	return n <= 1 or era_index(n - 1) != era_index(n)


static func act_of(n: int) -> int:
	return era_index(n)


static func act_name(a: int) -> String:
	return str(era_info(a).get("title", ""))


static func act_levels(a: int) -> Array:
	return era_levels(a)


static func first_of_act(n: int) -> bool:
	return first_of_era(n)


## Aufgaben-Text eines Levels mit Ziel target („Mach 6 Felsen“).
static func chip_text(n: int, target: int) -> String:
	var c: Dictionary = (data()["config"] as Dictionary).get(str(n), {})
	return str(c.get("chip", "")).replace("{n}", str(target))


## Die Aufgaben-Texte aller Teilziele (zwei Chips bei zwei Zielen): [„Lass 6 Quallen entstehen“, „Lass 5 Trilobiten
## entstehen“]. Ein Ruhe-Ziel hat einen Text.
static func chip_texts(c: Dictionary) -> Array:
	var out: Array = []
	var g: Array = c.get("goal", [])
	for i in g.size():
		var t := int((g[i] as Array)[2])
		var key := "chip2" if i == 1 and str(c.get("chip2", "")) != "" else "chip"
		out.append(str(c.get(key, "")).replace("{n}", str(t)))
	return out


static func goal_line(c: Dictionary) -> String:
	var g: Array = c.get("goal", [])
	if g.is_empty():
		return ""
	var first: Array = g[0]
	var t := int(first[2])
	return str(c.get("chip", "")).replace("{n}", str(t))


## Sterne-Grenzen [★★★ bis, ★★ bis] und Par (Punkte) eines Levels.
static func stars_of(n: int) -> Array:
	var c: Dictionary = (data()["config"] as Dictionary).get(str(n), {})
	var st: Array = c.get("stars", [4, 6])
	return [int(st[0]), int(st[1])]


static func par_of(n: int) -> int:
	var c: Dictionary = (data()["config"] as Dictionary).get(str(n), {})
	var st: Array = c.get("stars", [4, 6])
	return int(c.get("par", int(st[0]) + Balance.PAR_PLUS))


static func stars_for(n: int, steps: int) -> int:
	return GameState.stars_for9(stars_of(n), steps)


## Punkte für einen Sieg in Level n mit so vielen Schritten (GDPD_PUNKTE_LADEN.md 2.1).
static func points_for(n: int, steps: int) -> int:
	return GameState.points_for9(stars_for(n, steps), steps, par_of(n))


## Pille eines Ereignisses [Titel, Zeile] ([] = keine): die Jagd nennt ihre Jäger, Wachsen seine Art.
static func pill(e: Dictionary) -> Array:
	var t := str(e.get("type", ""))
	if t == "pack_warn" and PILL_HUNT.has(int(e.get("hunter", -1))):
		return (PILL_HUNT[int(e["hunter"])] as Array).duplicate()
	if t == "thrive":
		var tp := thrive_pill(int(e.get("from", -1)), int(e.get("kind", -1)))
		return [tp, ""] if tp != "" else []
	if PILL.has(t):
		return (PILL[t] as Array).duplicate()
	return []


static func thrive_pill(from: int, to: int) -> String:
	var key := "%d>%d" % [from, to]
	if THRIVE_PILL_TO.has(key):
		return str(THRIVE_PILL_TO[key])
	return str(THRIVE_PILL.get(from, ""))


# --- Alte Spielstände („Die Schöpfung“, 30 Level) → Erdgeschichte (9) ---------------------------------

## Altes Level (1 … 30) → das Level der Erdgeschichte, das es fortsetzt (0 = keins).
static func old_to_new(old: int) -> int:
	var m: Dictionary = data().get("old_to_new", {})
	return int(m.get(str(old), 0))


## Höchstes geschafftes altes Level k (1 … 30) → Position P in der Erdgeschichte (9: POS_OF_OLD).
static func pos_of_old(k: int) -> int:
	var p: Array = data().get("pos_of_old", [])
	if k < 1 or p.is_empty():
		return 0
	return int(p[mini(k, p.size()) - 1])


# --- Bretter (Pools) ---------------------------------------------------------------------------

static func pool_size(n: int) -> int:
	return ((data()["levels"] as Dictionary).get(str(n), []) as Array).size()


## Brett index (mit der Pool-Größe umgebrochen) von Level n: {"kinds", "seed", "index", "solved_in", "stars",
## "points", "solution", "board"}. Brett 0 von Level 1 ist das Tutorial-Brett.
static func board(n: int, index: int) -> Dictionary:
	var pool: Array = (data()["levels"] as Dictionary).get(str(n), [])
	if pool.is_empty():
		return {}
	var i := posmod(index, pool.size())
	var e: Dictionary = pool[i]
	return {"kinds": decode(str(e.get("board", ""))), "seed": int(e.get("seed", 1)), "index": i,
		"solved_in": int(e.get("solved_in", 0)), "stars": int(e.get("stars", 0)), "points": int(e.get("points", 0)),
		"solution": e.get("solution", []), "board": str(e.get("board", ""))}


static func decode(text: String) -> Array:
	var out: Array = []
	for i in text.length():
		var k := FieldData.CODE.find(text[i])
		out.append(k if k >= 0 else FieldData.WATER)
	return out


static func encode(kinds: Array) -> String:
	var s := ""
	for k in kinds:
		s += FieldData.code_of(int(k))
	return s


## Ein neuer Versuch von Level n auf einem Brett.
static func new_state(n: int, b: Dictionary) -> GameState:
	var gs := GameState.new()
	gs.setup_level(config(n), b.get("kinds", []), int(b.get("seed", 1)))
	return gs


# --- Die Welt läuft weiter (5): carry --------------------------------------------------------------

## Die Startbedingungen (4.4) eines Bretts in Level n prüfen: keine zählende Reihe, kein Fortschritt, kein satt
## Ziel-Feld, höchstens satt_max Satte, keine Kirche an Kirche, Gruppen-Ziele ohne Gruppe > group_max,
## satt-Ziele über Sticker-Arten erreichbar.
static func start_ok(n: int, kinds: Array) -> bool:
	return violation(n, kinds, false) == 0


## Wie weit ein Brett von den Startbedingungen weg ist (0 = passt). Wie levels9.violation.
## cap_clump: Vulkan-Level aus einer übernommenen Welt – die größte Lava-Gruppe höchstens GameState.CLUMP_CAP9 (ein
## riesiger Klumpen bricht immer wieder aus, und jeder Ausbruch kostet Felsen). Pool-Bretter prüfen das nicht.
static func violation(n: int, kinds: Array, want_clump: bool, cap_clump: bool = false) -> int:
	if not _vstate.has(n):
		var g0 := GameState.new()
		g0.setup_level(config(n), kinds, 1)
		_vstate[n] = g0
		_vcfg[n] = config(n)
	var gs: GameState = _vstate[n]
	var c: Dictionary = _vcfg[n]
	for i in mini(kinds.size(), gs.fields.size()):
		(gs.fields[i] as FieldData).kind = int(kinds[i])
	gs._grp_ok = false
	var v := 3 * gs.lines().size()
	v += 2 * infeasible(gs, c)
	v += 2 * gs.church_touch9().size()
	# satt am Start zählt nach den Level-Daten (wie im Modell): Regeln, die erst der Code dazugibt (Build 14: Wasser →
	# Ursuppe in Level 8/9), machen ein geprüftes Pool-Brett nicht ungültig
	var th: Dictionary = c.get("thrive", {})
	var sa: Array = []
	for i0 in gs.satt_ids9():
		if th.has(str((gs.fields[int(i0)] as FieldData).kind)):
			sa.append(int(i0))
	v += maxi(0, sa.size() - int(c.get("satt_max", 0)))
	var gm: Variant = c.get("group_max")
	if gm is Array:
		v += maxi(0, gs.biggest9(int((gm as Array)[0])) - int((gm as Array)[1]))
	for sub in gs.goal9:
		var sd: Dictionary = sub
		var subs: Array = sd["subs"] if str(sd["type"]) == "hold" else [sd]
		for x in subs:
			var xd: Dictionary = x
			if str(xd["type"]) == "satt":
				for i in sa:
					if (gs.fields[int(i)] as FieldData).kind == int(xd["kind"]):
						v += 2
	for sub in gs.goal9:
		var sd2: Dictionary = sub
		if (str(sd2["type"]) == "make" or str(sd2["type"]) == "satt") and gs.sub_progress9(sd2) > 0:
			v += 5
			break
	if cap_clump and bool(c.get("volcano", false)):
		v += maxi(0, gs.biggest9(FieldData.LAVA) - GameState.CLUMP_CAP9)
	var cl: Variant = c.get("clump")
	if want_clump and cl is Array and gs.biggest9(int((cl as Array)[0])) < int((cl as Array)[1]):
		v += int((cl as Array)[1]) - gs.biggest9(int((cl as Array)[0]))
	return v


## satt-Ziele, die über Sticker-Arten nie satt werden können (Ecken berühren nur Kanten, Kanten Ecken und Mitten,
## Mitten Kanten). 0 = alles erreichbar.
static func infeasible(gs: GameState, c: Dictionary) -> int:
	var reach := {3: [2], 2: [3, 1], 1: [2]}
	var v := 0
	for sub in gs.goal9:
		var sd: Dictionary = sub
		var subs: Array = sd["subs"] if str(sd["type"]) == "hold" else [sd]
		for x in subs:
			var xd: Dictionary = x
			if str(xd["type"]) != "satt":
				continue
			var k := int(xd["kind"])
			var have := 0
			var ok := 0
			for f in gs.fields:
				if f.kind != k:
					continue
				have += 1
				var r: Variant = gs.thrive9.get(k)
				if r == null:
					continue
				var t := FieldData.sticker_type(f.p)
				var good := true
				for need in ((r as Dictionary)["needs"] as Dictionary):
					var ns := str(need)
					if ns == "sun" or ns == "wet":
						continue
					var src: Array = GameState.SOURCES9.get(ns, [])
					var found := false
					for h in gs.fields:
						if src.has(h.kind) and (reach[t] as Array).has(FieldData.sticker_type(h.p)):
							found = true
							break
					if not found:
						good = false
						break
				if good:
					ok += 1
			v += maxi(0, mini(int(xd["target"]), have) - ok)
	return v


## Gewinnt eine einzige Drehung schon?
static func quick_win(n: int, kinds: Array, seed_value: int) -> bool:
	var gs := GameState.new()
	gs.setup_level(config(n), kinds, seed_value)
	for m in GameState.MOVES:
		var s := gs.clone()
		s.play({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])})
		if s.day_won:
			return true
	return false


## Tausch-Bergsteigen (wie levels9.repair): zwei Felder derselben Sticker-Art tauschen, bis die Startbedingungen
## gelten. Gibt [kinds, Rest-Verletzung] zurück.
## Build 14 („die Nacht behält deine Welt“): zuerst nur echte Verbesserungen (höchstens STRICT_ITERS Versuche) – so
## ändert die Reparatur nur, was sie muss. Reicht das nicht, der alte Durchgang (er nimmt auch gleich gute Täusche an
## und mischt dadurch viel mehr um).
const STRICT_ITERS := 1000


static func repair(n: int, kinds: Array, rng: RandomNumberGenerator, iters: int = 3000, cap_clump: bool = false) -> Array:
	var st := _repair_pass(n, kinds, rng, STRICT_ITERS, cap_clump, true)
	if int(st[1]) == 0:
		return st
	return _repair_pass(n, kinds, rng, iters, cap_clump, false)


static func _repair_pass(n: int, kinds: Array, rng: RandomNumberGenerator, iters: int, cap_clump: bool, strict: bool) -> Array:
	var k := kinds.duplicate()
	var cur := violation(n, k, false, cap_clump)
	var by_type := {3: [], 2: [], 1: []}
	var ref := GameState.new()
	ref.setup_level(config(n), k, 1)
	for f in ref.fields:
		(by_type[FieldData.sticker_type(f.p)] as Array).append(f.id)
	var pick := [3, 3, 2, 2, 1]
	for it in iters:
		if cur == 0:
			break
		var t: int = pick[rng.randi_range(0, 4)]
		var ids: Array = by_type[t]
		var a: int = ids[rng.randi_range(0, ids.size() - 1)]
		var b: int = ids[rng.randi_range(0, ids.size() - 1)]
		if a == b or int(k[a]) == int(k[b]):
			continue
		var tmp: int = k[a]
		k[a] = k[b]
		k[b] = tmp
		var v := violation(n, k, false, cap_clump)
		if v < cur or (not strict and (v == cur or rng.randf() < 0.02)):
			cur = v
		else:
			k[b] = k[a]
			k[a] = tmp
	return [k, cur]


## Eine Art, die das Level nicht benutzt, zieht sich zurück (Lava → Fels, Moos → Wiese …, sonst Wasser).
static func retire(k: int, allowed: Dictionary) -> int:
	var rt: Dictionary = data().get("retire", {})
	var seen := {}
	var cur := k
	while not allowed.has(cur) and not seen.has(cur):
		seen[cur] = true
		cur = int(rt.get(str(cur), FieldData.WATER))
	if allowed.has(cur):
		return cur
	# Build 14: Land bleibt Land (eine Land-Art, die das Level hat), bevor es Wasser wird
	if not FieldData.water_family(k):
		for land in [FieldData.EMPTY, FieldData.STONE, FieldData.MEADOW, FieldData.MOSS, FieldData.FERN, FieldData.FOREST]:
			if allowed.has(land):
				return int(land)
	return FieldData.WATER


## Die Welt von gestern als Start von Level n (5): prev = 54 Arten nach Plätzen (GameState.slot_board9 / [kampagne]
## welt). 1 über Nacht wachsen, 2 nicht benutzte Arten ziehen sich zurück, 3 genau auf die Start-Mischung bringen
## (Neues wächst neben Gleichem), 4 reparieren. Klappt das nicht: das Pool-Brett. Deterministisch (gleiche Eingabe,
## gleiches Brett). {"kinds", "seed", "how": "carry"|"fallback", "changed": [Feld-IDs, deren Art sich änderte],
## "index"}.
static func carry(prev: Array, n: int, seed_value: int, pool_index: int = 0) -> Dictionary:
	var c := config(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7777 + n
	var k: Array = []
	for x in prev:
		k.append(int(x))
	if k.size() != 54 or c.is_empty() or first_of_act(n):
		return _fallback(n, pool_index)
	var before := k.duplicate()
	for pair in c.get("overnight", []):
		var pa: Array = pair
		for i in k.size():
			if int(k[i]) == int(pa[0]):
				k[i] = int(pa[1])
	var comp: Dictionary = c.get("comp", {})
	var want := {}
	var total := 0
	for key in comp:
		want[int(str(key))] = int(comp[key])
		total += int(comp[key])
	want[FieldData.WATER] = 54 - total
	var allowed := want.duplicate()
	for i in k.size():
		k[i] = retire(int(k[i]), allowed)
	var ref := GameState.new()
	ref.setup_level(c, k, 1)
	var nbs := ref._nbs9()
	for guard in 54:
		var cnt := {}
		for x in k:
			cnt[int(x)] = int(cnt.get(int(x), 0)) + 1
		var short := -1
		var short_n := 0
		var kinds_sorted: Array = want.keys()
		kinds_sorted.sort()
		kinds_sorted.reverse()
		for d in kinds_sorted:
			var miss := int(want[d]) - int(cnt.get(d, 0))
			if miss > short_n:
				short_n = miss
				short = int(d)
		if short < 0:
			break
		var best_f := -1
		var best_v := -1.0
		for f in k.size():
			var kf := int(k[f])
			if int(cnt.get(kf, 0)) <= int(want.get(kf, 0)):
				continue
			var nn := 0
			for g in nbs[f]:
				if int(k[g]) == short:
					nn += 1
			var v := float(nn) + rng.randf() * 0.5
			if v > best_v:
				best_v = v
				best_f = f
		if best_f < 0:
			break
		k[best_f] = short
	var rep := repair(n, k, rng, 3000, true)
	if int(rep[1]) == 0:
		var kinds: Array = rep[0]
		if start_ok(n, kinds) and not quick_win(n, kinds, seed_value):
			var changed: Array = []
			for i in kinds.size():
				if int(kinds[i]) != int(before[i]):
					changed.append(i)
			return {"kinds": kinds, "seed": seed_value, "how": "carry", "changed": changed, "index": -1}
	return _fallback(n, pool_index)


## Höchstens so viele Felder Nachschub über Nacht (Campaign.ensure).
const TOPUP_MAX := 6


## Vor jedem Level-Start (Game.start_level), egal von welchem Brett (übernommene Welt, gespeichertes Start-Brett,
## Pool): Ist das Ziel von hier aus erreichbar? GameState.reach9 prüft das ohne Suche (unter 1 ms; eine echte Suche
## kostet am Handy je Zug ~10 ms und passt nicht in den Start). Vulkan-Level aus einer übernommenen Welt: Lava-Klumpen
## über GameState.CLUMP_CAP9 werden geteilt (Felder derselben Sticker-Art tauschen, die Mischung bleibt). Fehlt
## Material, bringt die Nacht Nachschub (höchstens TOPUP_MAX Felder, sichtbar in der Welle, kurz erklärt: TEXT topup);
## reicht das nicht, beginnt das Level auf seinem Pool-Brett (TEXT fresh). Deterministisch.
## Gibt b ergänzt zurück: "kinds", "changed" (alle geänderten Felder), "fixes" [{"field", "from", "kind"}] (Nachschub
## und Teilen, zuerst in der Welle), "line" ("" oder der Satz für den Banner), "how" ("fallback" beim Rückfall).
static func ensure(n: int, b: Dictionary, pool_index: int = 0) -> Dictionary:
	var out := b.duplicate()
	out["line"] = ""
	out["fixes"] = []
	var how := str(b.get("how", ""))
	var kinds: Array = (b.get("kinds", []) as Array).duplicate()
	if kinds.size() != 54 or not valid(n):
		return out
	var c := config(n)
	if how == "stored":
		return out                  # Build 14: ein gespeichertes Start-Brett ist schon durch (Game prüft es am Tor, gate)
	if how == "pool" or how == "fallback":
		# ein Pool-Brett hat eine geprüfte Lösung; das Tor prüft es trotzdem (sonst das nächste Pool-Brett)
		if not gate(n, kinds, int(b.get("seed", 1))):
			var gp := _gated_pool(n, pool_index + 1)
			gp["line"] = str(TEXT["fresh"])
			gp["fixes"] = []
			return gp
		if how == "fallback":
			out["line"] = str(TEXT["fresh"])     # die Welt von gestern ging nicht mit: sag es (nie ein stiller Tausch)
		return out
	var gs := GameState.new()
	gs.setup_level(c, kinds, int(b.get("seed", 1)))
	var own := true
	var line := ""
	var rng := RandomNumberGenerator.new()
	rng.seed = int(b.get("seed", 1)) * 31 + n
	if own and bool(c.get("volcano", false)) and gs.biggest9(FieldData.LAVA) > GameState.CLUMP_CAP9:
		split_lava(gs, rng)
		line = str(TEXT["calmer"])
	if own and c.get("glacier") is Dictionary and gs.biggest9(FieldData.ICE) > CLUMP_CAP_ICE:
		# Gletscher-Level aus einer übernommenen Welt: ein riesiger Eis-Klumpen würde immer wieder einfrieren
		split_clump(gs, FieldData.ICE, CLUMP_CAP_ICE, rng)
		line = str(TEXT["calmer_ice"])
	for h in gs.hunt9:
		# Jagd-Level aus einer übernommenen Welt: ein Rudel über 3 wird geteilt (es jagt dann noch, aber kleiner)
		var hk := int((h as Dictionary)["hunter"])
		if own and gs.biggest9(hk) > PACK_CAP:
			split_clump(gs, hk, PACK_CAP, rng)
	var top := gs.top_up9(TOPUP_MAX)
	if not gs.lines().is_empty():
		# Nie eine fertige Reihe am Start (sie würde nie zählen): Teilen und Nachschub dürfen keine schließen
		gs._break_ready_lines()
		gs._grp_ok = false
	if not bool(gs.reach9()["ok"]) or not gs.lines().is_empty() or _all_met(gs):
		var fb := _gated_pool(n, pool_index)
		fb["line"] = str(TEXT["fresh"])
		fb["fixes"] = []
		return fb
	if not top.is_empty():
		var k0 := int((top[0] as Array)[1])
		var same := 0
		for t in top:
			if int((t as Array)[1]) == k0:
				same += 1
		line = str(TEXT["topup"]) % [same, FieldData.kind_name(k0)]
	var nk: Array = []
	for f in gs.fields:
		nk.append(f.kind)
	if nk == kinds:
		return out
	var fixes: Array = []
	var changed: Array = (b.get("changed", []) as Array).duplicate()
	for t2 in top:
		var fid := int((t2 as Array)[0])
		fixes.append({"field": fid, "from": int(kinds[fid]), "kind": int(nk[fid])})
	for i in nk.size():
		if int(nk[i]) != int(kinds[i]):
			if not changed.has(i):
				changed.append(i)
			var seen := false
			for fx in fixes:
				if int((fx as Dictionary)["field"]) == i:
					seen = true
			if not seen:
				fixes.append({"field": i, "from": int(kinds[i]), "kind": int(nk[i])})
	out["kinds"] = nk
	out["changed"] = changed
	out["fixes"] = fixes
	out["line"] = line
	out["board"] = encode(nk)
	return out


## Sind schon alle Teilziele erfüllt (ein Brett, das beim ersten Zug gewonnen wäre)?
static func _all_met(gs: GameState) -> bool:
	if gs.goal9.is_empty():
		return false
	for i in gs.goal9.size():
		if not gs._sub_met9(i):
			return false
	return true


## Arten, die Level n kennt (Start-Mischung, Wasser, Reihen, Gedeihen, Regen, Brand, Gefahren-Folgen).
static func known_kinds(n: int) -> Dictionary:
	var c := config(n)
	var out := {FieldData.WATER: true}
	for key in (c.get("comp", {}) as Dictionary):
		out[int(str(key))] = true
	var gs := GameState.new()
	var kinds: Array = []
	for i in 54:
		kinds.append(FieldData.WATER)
	gs.setup_level(c, kinds, 1)
	for k in gs.rows9:
		out[int(k)] = true
		out[int(gs.rows9[k])] = true
	for k2 in gs.consume9:
		out[int(gs.consume9[k2])] = true
	for k3 in gs.thrive9:
		var r: Dictionary = gs.thrive9[k3]
		out[int(k3)] = true
		if int(r["up"]) >= 0:
			out[int(r["up"])] = true
		if int(r["down"]) >= 0:
			out[int(r["down"])] = true
		var sp: Array = r["spawn"]
		if sp.size() >= 3:
			out[int(sp[1])] = true
			if int(sp[2]) >= 0:
				out[int(sp[2])] = true
	for it in gs.rain9:
		out[int((it as Array)[0])] = true
		out[int((it as Array)[2])] = true
	for k4 in gs.burn9:
		out[int(gs.burn9[k4])] = true
	for h in gs.hunt9:
		out[int((h as Dictionary)["to"])] = true
	if not gs.impact9.is_empty():
		for k5 in (gs.impact9["kill"] as Dictionary):
			out[int((gs.impact9["kill"] as Dictionary)[k5])] = true
	if bool(gs.sys9.get("volcano", false)):
		out[FieldData.LAVA] = true
	if not gs.glacier9.is_empty():
		out[FieldData.ICE] = true
	if bool(gs.sys9.get("war", false)) or bool(gs.sys9.get("smog", false)):
		for k6 in [FieldData.EMPTY, FieldData.MEADOW, FieldData.HUT, FieldData.VILLAGE, FieldData.FOREST, FieldData.MOSS]:
			out[int(k6)] = true
	return out


## Das Tor (Build 14, GDPD_LOGIK.md „Jeder Start wird geprüft“): Auf diesem Brett darf Level n beginnen – 54 Arten, die
## das Level kennt, das Ziel ist erreichbar (GameState.reach9), keine fertige Reihe, nicht schon gewonnen. Gilt für
## jeden Weg (Pool, Welt von gestern, gespeichertes Start-Brett, Welt des Tages).
static func gate(n: int, kinds: Array, seed_value: int = 1, cfg: Dictionary = {}) -> bool:
	if kinds.size() != 54 or not valid(n):
		return false
	var known := known_kinds(n)
	for k in kinds:
		if not known.has(int(k)):
			return false
	var gs := GameState.new()
	gs.setup_level(cfg if not cfg.is_empty() else config(n), kinds, seed_value)
	return bool(gs.reach9()["ok"]) and gs.lines().is_empty() and not _all_met(gs)


## So viele Felder eines Bretts passen nicht zur Start-Mischung von Level n (0 = genau die Mischung).
static func mix_off(n: int, kinds: Array) -> int:
	var comp: Dictionary = config(n).get("comp", {})
	var want := {}
	var total := 0
	for key in comp:
		want[int(str(key))] = int(comp[key])
		total += int(comp[key])
	want[FieldData.WATER] = 54 - total
	var cnt := {}
	for k in kinds:
		cnt[int(k)] = int(cnt.get(int(k), 0)) + 1
	var off := 0
	for k2 in cnt:
		off += maxi(0, int(cnt[k2]) - int(want.get(k2, 0)))
	return off


## Das erste Pool-Brett ab pool_index, das durchs Tor geht (wie _fallback; praktisch immer das erste).
static func _gated_pool(n: int, pool_index: int) -> Dictionary:
	var size := maxi(1, pool_size(n))
	for d in size:
		var fb := _fallback(n, pool_index + d)
		if n > 1 and size > 1 and int(fb.get("index", 0)) == 0:
			continue                    # Brett 0 ist das Lehr-Brett
		if gate(n, fb.get("kinds", []), int(fb.get("seed", 1))):
			return fb
	return _fallback(n, pool_index)


## Die größte Änderung einer Nacht für den Banner: das Paar (von → zu) mit den meisten Feldern. prev und kinds = je 54
## Arten. {"from", "to", "n", "fields"} oder {} (nichts geändert).
static func night_pair(prev: Array, kinds: Array) -> Dictionary:
	var cnt := {}
	for i in mini(prev.size(), kinds.size()):
		var a := int(prev[i])
		var b := int(kinds[i])
		if a == b:
			continue
		var key := a * 64 + b
		if not cnt.has(key):
			cnt[key] = []
		(cnt[key] as Array).append(i)
	var best := -1
	for key2 in cnt:
		if best < 0 or (cnt[key2] as Array).size() > (cnt[best] as Array).size() \
				or ((cnt[key2] as Array).size() == (cnt[best] as Array).size() and int(key2) < best):
			best = int(key2)
	if best < 0:
		return {}
	return {"from": best / 64, "to": best % 64, "n": (cnt[best] as Array).size(), "fields": cnt[best]}


## Eis-Klumpen einer übernommenen Welt höchstens so groß (Gletscher-Level, GDPD_ERDGESCHICHTE.md 6).
const CLUMP_CAP_ICE := 5
## Jäger-Gruppen einer übernommenen Welt höchstens so groß (Jagd-Level).
const PACK_CAP := 3


## Lava-Klumpen teilen: ein Lava-Feld der größten Gruppe tauscht mit einem Feld derselben Sticker-Art, das keine Lava
## berührt, solange die größte Gruppe dadurch kleiner wird (oder gleich bleibt). Die Mischung bleibt gleich.
static func split_lava(gs: GameState, rng: RandomNumberGenerator, iters: int = 400) -> void:
	split_clump(gs, FieldData.LAVA, GameState.CLUMP_CAP9, rng, iters)


## Klumpen der Art k teilen, bis die größte Gruppe höchstens cap ist (Lava, Eis, Rudel). Die Mischung bleibt gleich.
static func split_clump(gs: GameState, k: int, cap: int, rng: RandomNumberGenerator, iters: int = 400) -> void:
	var by_type := {3: [], 2: [], 1: []}
	for f in gs.fields:
		(by_type[FieldData.sticker_type(f.p)] as Array).append(f.id)
	var cur := gs.biggest9(k)
	for it in iters:
		if cur <= cap:
			break
		var big: Array = []
		for f in gs.fields:
			if f.kind == k and gs.gsize9(f.id) == cur:
				big.append(f.id)
		if big.is_empty():
			break
		var a: int = big[rng.randi_range(0, big.size() - 1)]
		var fa: FieldData = gs.fields[a]
		var ids: Array = by_type[FieldData.sticker_type(fa.p)]
		var bid: int = ids[rng.randi_range(0, ids.size() - 1)]
		var fb: FieldData = gs.fields[bid]
		if fb.kind == k or (it < iters / 2 and gs._next_to9(bid, k)):
			continue
		var kb := fb.kind
		gs._setk9(fb, k)
		gs._setk9(fa, kb)
		var v := gs.biggest9(k)
		if v <= cur:
			cur = v
		else:
			gs._setk9(fa, k)
			gs._setk9(fb, kb)


static func _fallback(n: int, pool_index: int) -> Dictionary:
	var b := board(n, pool_index)
	return {"kinds": b.get("kinds", []), "seed": int(b.get("seed", 1)), "how": "fallback", "changed": [],
		"index": int(b.get("index", 0))}


# --- Zeitalter-Look (2): die Welt sieht aus wie ihr Zeitalter ----------------------------------------

## Solange ein Look noch nicht in Eras steht (die Grafik baut ihn), nimmt die Welt diesen.
const LOOK_FALLBACK = {"kambrium": "tag", "meer": "tag", "landgang": "tag", "karbon": "tag", "saurier": "tag",
	"asche": "glut_kuehl", "erholung": "tag", "saeuger": "tag", "eiszeit": "winter", "savanne": "tag", "feuer": "abend",
	"jaeger": "tag", "glaube": "abend"}


## Look-Schlüssel, den die Welt kennt (Eras.has), sonst der Ersatz.
static func look_key(look: String) -> String:
	if look == "" or Eras.has(look):
		return look
	return str(LOOK_FALLBACK.get(look, "tag"))


## Das Zeitalter von Level n für die Welt (World.set_era): {"era" (Look-Schlüssel in Eras), "look" (Look laut Spec),
## "era_id", "act" (Nummer), "level", "name" (Titel), "line", "icon", "sky" (= era), "mix_from" (Look davor, gemischt),
## "after" (Look nach dem Einschlag), "sky_mix" ("algae": sky_blue = Algen / 8), "dust" (dust_clear = Wiesen / 10),
## "sky_blue", "dust_clear", "life", "sun_face" (oben ist Tag: das Level braucht Sonne), "night_face", "smog"}.
## GameState.era9 füllt sky_blue, dust_clear, life, smog aus dem Brett.
static func era(n: int) -> Dictionary:
	var a := era_index(n)
	var ei := era_info(a)
	var c: Dictionary = (data()["config"] as Dictionary).get(str(n), {})
	var look := str(c.get("look", ei.get("look", "tag")))
	var sun := false
	for key in (c.get("thrive", {}) as Dictionary):
		if ((c["thrive"][key] as Dictionary).get("needs", {}) as Dictionary).has("sun"):
			sun = true
	for it in c.get("rain", []):
		if str((it as Array)[1]) == "sun":
			sun = true
	var after := str(c.get("after", ""))
	var e := {"act": a, "era_id": str(ei.get("id", "")), "level": n, "name": str(ei.get("title", "")),
		"line": str(ei.get("line", "")), "icon": str(ei.get("icon", "info")), "look": look, "era": look_key(look),
		"sky": look_key(look), "mix_from": look_key(str(c.get("mix_from", ""))), "after": look_key(after),
		"after_look": after, "sky_mix": str(c.get("sky_mix", "")), "dust": bool(c.get("dust", false)),
		"sky_blue": 0.0 if a <= 2 else 1.0, "dust_clear": 0.0, "life": 0, "sun_face": sun, "night_face": -1,
		"smog": 0.0, "impact": c.get("impact") is Dictionary}
	return e


# --- Welt des Tages nach der Kampagne (8) ---------------------------------------------------------

## Vorlagen, die heute in Frage kommen: stars leer = alle; sonst nur geschaffte Level (nie spoilern, was noch kommt).
static func wdt_pool(stars: Array = []) -> Array:
	if stars.is_empty():
		return WDT.duplicate()
	var out: Array = []
	for t in WDT:
		var i := int(t) - 1
		if i >= 0 and i < stars.size() and int(stars[i]) > 0:
			out.append(int(t))
	return out


## Vorlage des Spieltags key (-1: noch keine geschaffte Vorlage).
static func wdt_template(key: int, stars: Array = []) -> int:
	var pool := wdt_pool(stars)
	if pool.is_empty():
		return -1
	return int(pool[posmod(key, pool.size())])


## Brett der Vorlage: nie Brett 0; 20 × 19 = 380 Welten, bevor sich eine wiederholt (n_templates < 0: alle Vorlagen).
static func wdt_board_index(key: int, pool: int = 20, n_templates: int = -1) -> int:
	if pool <= 1:
		return 0
	var nt := n_templates if n_templates > 0 else WDT.size()
	return 1 + posmod(floori(float(key) / float(maxi(1, nt))), pool - 1)


static func wdt_config(key: int, weekday_name: String = "", stars: Array = []) -> Dictionary:
	var t := wdt_template(key, stars)
	if t < 1:
		return {}
	var c := config(t)
	if c.is_empty():
		return c
	c["template_title"] = str(c.get("title", ""))
	c["title"] = str(TEXT["wdt"])
	c["caps"] = str(TEXT["wdt_caps"]) % weekday_name if weekday_name != "" else str(TEXT["wdt"])
	c["new"] = []
	c["coach"] = ""
	c["tutorial"] = false
	c["wdt"] = true
	c["wdt_key"] = key
	return c


static func wdt_board(key: int, stars: Array = []) -> Dictionary:
	var t := wdt_template(key, stars)
	if t < 1:
		return {}
	return board(t, wdt_board_index(key, pool_size(t), wdt_pool(stars).size()))


# --- Nicht spoilern ---------------------------------------------------------------------------------

## Was die Übersicht zu Level n zeigen darf: offen → Titel, Symbol, Geschichte; gesperrt → nur „?“ und Schloss.
static func tile(n: int, open: bool) -> Dictionary:
	if not open:
		return {"level": n, "open": false, "title": str(TEXT["locked_short"]), "icon": "lock", "story": "",
			"line": str(TEXT["locked"]), "act": act_of(n)}
	var c := config(n)
	return {"level": n, "open": true, "title": str(c.get("title", "")), "icon": str(ICON.get(act_of(n), "info")),
		"story": str(c.get("story", "")), "line": goal_line(c), "act": act_of(n), "new": c.get("new", []),
		"era_id": era_of(n)}


## Zeitalter-Kachel: Name, Zeile und Symbol nur für erreichte Zeitalter (sonst „?“ und Schloss).
static func act_tile(a: int, reached: bool) -> Dictionary:
	return era_tile(a, reached)


static func era_tile(a: int, reached: bool) -> Dictionary:
	var ei := era_info(a)
	return {"act": a, "index": a, "caps": str(TEXT["act_caps"]) % a, "reached": reached,
		"id": str(ei.get("id", "")) if reached else "", "name": str(ei.get("title", "")) if reached else str(TEXT["locked_short"]),
		"line": str(ei.get("line", "")) if reached else str(TEXT["locked"]),
		"icon": str(ICON.get(a, "info")) if reached else "lock", "levels": act_levels(a) if reached else []}


## Alle Spieler-Texte der Kampagne (für die Text-Prüfung: kurz, du-Form).
static func player_texts() -> Array:
	var out: Array = []
	for n in range(1, COUNT + 1):
		var c := config(n)
		out.append(str(c.get("story", "")))
		out.append(chip_text(n, 10))
		for t in c.get("new", []):
			out.append(str(t))
		out.append(str(c.get("coach", "")))
	for k in TEXT:
		out.append(str(TEXT[k]))
	for k in PILL:
		for t in PILL[k]:
			if str(t) != "":
				out.append(str(t))
	for k in THRIVE_PILL:
		out.append(str(THRIVE_PILL[k]))
	for k in THRIVE_PILL_TO:
		out.append(str(THRIVE_PILL_TO[k]))
	for k in PILL_HUNT:
		for t in PILL_HUNT[k]:
			out.append(str(t))
	for e in eras():
		out.append(str((e as Dictionary).get("title", "")))
		out.append(str((e as Dictionary).get("line", "")))
	for n2 in range(1, COUNT + 1):
		var c2 := config(n2)
		out.append(str(c2.get("title", "")))
		if str(c2.get("chip2", "")) != "":
			out.append(str(c2["chip2"]).replace("{n}", "10"))
	return out
