class_name Campaign
extends RefCounted
## Die Kampagne „Die Schöpfung“ (docs/GDPD_SCHOEPFUNG.md v2): 7 Akte (die Genesis-Tage), 30 Level entlang der
## Erdgeschichte, ein neues Level je Spieltag, danach die Welt des Tages. Nur statische Funktionen, keine Nodes.
##
## Die Level-Daten (Regeln, Ziele, Sterne-Grenzen, Texte, Pools mit je einer Lösung) kommen aus
## data/kampagne_schoepfung.json, exportiert aus dem Python-Modell (gdpd_sim/b5/export_gd.py aus b4/levels9.py,
## texts9.py und den geprüften Pools). GameState.setup_level(Campaign.config(n), board["kinds"], board["seed"]).
## Die Welt läuft innerhalb eines Akts weiter (carry, 5); ein neuer Akt beginnt auf einem frischen Pool-Brett.
## Nie spoilern: Titel, Symbol, Geschichte und „Neu“-Karte eines Levels erst, wenn es offen ist (locked_*).

const DATA_PATH := "res://data/kampagne_schoepfung.json"
const COUNT := 30
## Welt des Tages nach dem Ende der Kampagne (8): ein starkes Level je Akt, zwei aus den Akten 2–6, nie ein Tutorial.
const WDT = [3, 6, 8, 10, 12, 13, 15, 17, 19, 22, 23, 26, 27, 29]
## Veteranen (13.1): höchster geschaffter alter Tag 1 … 7 → Schnellstart bis zu diesem Level.
const FAST_TRACK = [0, 4, 8, 12, 19, 24, 26, 28]
const ICON := {1: "lava", 2: "rain", 3: "moss", 4: "sun", 5: "fish", 6: "animals", 7: "faith"}

const TEXT = {
	"title": "Die Schöpfung",
	"act_caps": "Tag %d",                       # Akt = Genesis-Tag
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
	"rest": "Ruhe hält",
	"unrest": "Unruhe!",
	"topup": "Über Nacht: +%d %s",
	"fresh": "Heute eine frische Welt",
	"calmer": "Die Lava hat sich verteilt",
	"rescue_dead": "Sackgasse! Ich helfe dir.",
	"rescue_few": "Zu wenig Lava? Ich helfe dir.",
	"rescue_stall": "Hängst du fest? Ich helfe dir.",
	"rescue_rows": "Keine Reihe? Wasser kühlt Lava.",
	"gift": "Geschenk",
	"new_world": "Neue Welt",
	"play_on": "Weiterspielen",
}
## Pillen der Ereignisse (Vertrag 11; höchstens eine je Runde, kurz).
const PILL = {
	"volcano_warn": ["Vulkan grollt!", "Teil die Lava"], "erupt": ["Ausbruch!", ""], "volcano_calm": ["Ruhe", ""],
	"bolt_warn": ["Blitz droht!", "Wasser an den Wald"], "bolt": ["Feuer!", ""], "bolt_cancel": ["Regen schützt", ""],
	"hunger_warn": ["Hunger!", "Bring Futter"], "starve": ["Verhungert", ""], "pack_warn": ["Rudel jagt!", "Trenn die Raubtiere"],
	"pack_hunt": ["Gejagt!", ""], "smog_warn": ["Smog droht!", ""], "polluted": ["Smog!", ""], "spawn": ["Landgang!", ""],
	"steam": ["+1 Regen", ""], "meteor_ready": ["Meteor bereit", ""], "mercy": ["Hilfe von oben", ""],
	"need_sealed": ["Versorgt bleibt versorgt.", ""],
}
## Wachsen durch Nachbarn (thrive): Pille je Art.
const THRIVE_PILL = {FieldData.LAVA: "Lava wird Fels", FieldData.WATER: "Ursuppe entsteht",
	FieldData.SOUP: "Ursuppe lebt!", FieldData.EMPTY: "Moos wächst", FieldData.MOSS: "Moos wird Farn",
	FieldData.MEADOW: "Wiese wird Wald", FieldData.SEED: "Saat reift", FieldData.FOREST: "Vögel nisten",
	FieldData.HUT: "Hütte wird Dorf", FieldData.VILLAGE: "Dorf wird Stadt"}

static var _data: Dictionary = {}
static var _vstate: Dictionary = {}     # Level → GameState zum Prüfen der Startbedingungen (nur Arten wechseln)
static var _vcfg: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = Days._read_json(DATA_PATH)
		_data = d if d is Dictionary else {"config": {}, "levels": {}}
	return _data


static func count() -> int:
	return COUNT


static func valid(n: int) -> bool:
	return n >= 1 and n <= COUNT and (data()["config"] as Dictionary).has(str(n))


## Regeln und Texte von Level n (die Daten des Modells plus "level"). {} wenn es n nicht gibt.
static func config(n: int) -> Dictionary:
	var cs: Dictionary = data()["config"]
	if not cs.has(str(n)):
		return {}
	var c: Dictionary = (cs[str(n)] as Dictionary).duplicate(true)
	c["level"] = n
	c["act_name"] = act_name(int(c.get("act", 1)))
	c["goal_line"] = goal_line(c)
	return c


static func act_of(n: int) -> int:
	var c: Dictionary = (data()["config"] as Dictionary).get(str(n), {})
	return int(c.get("act", 0))


static func act_name(a: int) -> String:
	return str((data().get("acts", {}) as Dictionary).get(str(a), ""))


## Die Level eines Akts (aufsteigend).
static func act_levels(a: int) -> Array:
	var out: Array = []
	for n in range(1, COUNT + 1):
		if act_of(n) == a:
			out.append(n)
	return out


static func first_of_act(n: int) -> bool:
	return n <= 1 or act_of(n - 1) != act_of(n)


## Aufgaben-Text eines Levels mit Ziel target („Mach 6 Felsen“).
static func chip_text(n: int, target: int) -> String:
	var c: Dictionary = (data()["config"] as Dictionary).get(str(n), {})
	return str(c.get("chip", "")).replace("{n}", str(target))


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
	var sa := gs.satt_ids9()
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
static func repair(n: int, kinds: Array, rng: RandomNumberGenerator, iters: int = 3000, cap_clump: bool = false) -> Array:
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
		if v <= cur or rng.randf() < 0.02:
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
	return cur if allowed.has(cur) else FieldData.WATER


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
	var gs := GameState.new()
	gs.setup_level(c, kinds, int(b.get("seed", 1)))
	var own := how != "pool" and how != "fallback"
	if not own:
		return out                  # ein Pool-Brett hat eine geprüfte Lösung (und das Sicherheitsnetz im Spiel hilft)
	var line := ""
	if own and bool(c.get("volcano", false)) and gs.biggest9(FieldData.LAVA) > GameState.CLUMP_CAP9:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(b.get("seed", 1)) * 31 + n
		split_lava(gs, rng)
		line = str(TEXT["calmer"])
	var top := gs.top_up9(TOPUP_MAX)
	if not gs.lines().is_empty():
		# Nie eine fertige Reihe am Start (sie würde nie zählen): Teilen und Nachschub dürfen keine schließen
		gs._break_ready_lines()
		gs._grp_ok = false
	if not bool(gs.reach9()["ok"]) or not gs.lines().is_empty():
		var fb := _fallback(n, pool_index)
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


## Lava-Klumpen teilen: ein Lava-Feld der größten Gruppe tauscht mit einem Feld derselben Sticker-Art, das keine Lava
## berührt, solange die größte Gruppe dadurch kleiner wird (oder gleich bleibt). Die Mischung bleibt gleich.
static func split_lava(gs: GameState, rng: RandomNumberGenerator, iters: int = 400) -> void:
	var by_type := {3: [], 2: [], 1: []}
	for f in gs.fields:
		(by_type[FieldData.sticker_type(f.p)] as Array).append(f.id)
	var cur := gs.biggest9(FieldData.LAVA)
	for it in iters:
		if cur <= GameState.CLUMP_CAP9:
			break
		var big: Array = []
		for f in gs.fields:
			if f.kind == FieldData.LAVA and gs.gsize9(f.id) == cur:
				big.append(f.id)
		if big.is_empty():
			break
		var a: int = big[rng.randi_range(0, big.size() - 1)]
		var fa: FieldData = gs.fields[a]
		var ids: Array = by_type[FieldData.sticker_type(fa.p)]
		var bid: int = ids[rng.randi_range(0, ids.size() - 1)]
		var fb: FieldData = gs.fields[bid]
		if fb.kind == FieldData.LAVA or (it < iters / 2 and gs._next_to9(bid, FieldData.LAVA)):
			continue
		var kb := fb.kind
		gs._setk9(fb, FieldData.LAVA)
		gs._setk9(fa, kb)
		var v := gs.biggest9(FieldData.LAVA)
		if v <= cur:
			cur = v
		else:
			gs._setk9(fa, FieldData.LAVA)
			gs._setk9(fb, kb)


static func _fallback(n: int, pool_index: int) -> Dictionary:
	var b := board(n, pool_index)
	return {"kinds": b.get("kinds", []), "seed": int(b.get("seed", 1)), "how": "fallback", "changed": [],
		"index": int(b.get("index", 0))}


# --- Ära (10): die Welt sieht aus wie ihr Zeitalter ------------------------------------------------

## {"act", "level", "name", "sky" (Schlüssel), "sky_blue" (0 … 1), "life" (0 tot … 3 Fische), "sun_face",
##  "smog" (Grau des Himmels), "night_face"}. GameState.era9 füllt sky_blue und life aus dem Brett.
static func era(n: int) -> Dictionary:
	var a := act_of(n)
	var sky := ["", "glut", "dunst", "blau", "sonne", "klar", "normal", "abend"]
	var e := {"act": a, "level": n, "name": act_name(a), "sky": str(sky[clampi(a, 0, 7)]),
		"sky_blue": 0.0 if a <= 2 else (0.25 if a == 3 else 1.0), "life": 0, "sun_face": a >= 4, "night_face": 5 if a == 4 else -1,
		"smog": 0.0, "icon": str(ICON.get(a, "info"))}
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


## Brett der Vorlage: nie Brett 0; 14 × 19 = 266 Welten, bevor sich eine wiederholt.
static func wdt_board_index(key: int, pool: int = 20, n_templates: int = WDT.size()) -> int:
	if pool <= 1:
		return 0
	return 1 + posmod(floori(float(key) / float(maxi(1, n_templates))), pool - 1)


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
		"story": str(c.get("story", "")), "line": goal_line(c), "act": act_of(n), "new": c.get("new", [])}


## Akt-Kachel: der Name nur für erreichte Akte.
static func act_tile(a: int, reached: bool) -> Dictionary:
	return {"act": a, "caps": str(TEXT["act_caps"]) % a, "name": act_name(a) if reached else str(TEXT["locked_short"]),
		"icon": str(ICON.get(a, "info")) if reached else "lock", "levels": act_levels(a)}


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
	return out
