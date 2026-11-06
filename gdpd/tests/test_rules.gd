extends SceneTree
## Regeltests für gdpd ohne Grafik (gdpd_spec/GDPD_REGELN.md, Abschnitt 12):
##   godot --headless --import
##   godot --headless --script res://tests/test_rules.gd

const Bot = preload("res://tests/gdpd_bot.gd")
const GameScript = preload("res://scripts/game.gd")

const E := FieldData.EMPTY
const MEADOW := FieldData.MEADOW
const FOREST := FieldData.FOREST
const FIELD := FieldData.FIELD
const BIGFOREST := FieldData.BIGFOREST
const ANIMALS := FieldData.ANIMALS
const HUT := FieldData.HUT
const HOUSE := FieldData.HOUSE
const VILLAGE := FieldData.VILLAGE
const TOWN := FieldData.TOWN
const CHURCH := FieldData.CHURCH
const BIGCITY := FieldData.BIGCITY
const INDUSTRY := FieldData.INDUSTRY
const METROPOLIS := FieldData.METROPOLIS
const PARADISE := FieldData.PARADISE
const UP := Vector3i(0, 1, 0)

var failures := 0
var checks := 0
var _saved := {}


func _init() -> void:
	test_setup()
	test_geometry()
	test_kind_table()
	calm()
	test_merge()
	test_choice()
	test_one_card()
	test_card_deterministic()
	test_cascade()
	test_easy_groups()
	test_easy_repeat()
	test_finished_no_row()
	test_war()
	test_balance_and_smog()
	test_regrow()
	test_income()
	test_wishes()
	test_tools()
	test_win()
	test_preview_matches()
	test_undo()
	test_ages()
	test_hint()
	test_hint_ignores_seen()
	test_start_no_ready_lines()
	test_tutorial_flow()
	test_rain_rules()
	restore()
	test_fire()
	test_modes()
	test_game_flow()
	test_bot()
	print("")
	print("%d Prüfungen, %d Fehler" % [checks, failures])
	quit(1 if failures > 0 else 0)


## Für die reinen Regeltests: kein Feuer, das dazwischenfunkt.
func calm() -> void:
	_saved = {"fire": Balance.FIRE_AFTER}
	Balance.FIRE_AFTER = 999


func restore() -> void:
	Balance.FIRE_AFTER = _saved["fire"]


func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		push_error("FEHLER: " + what)
		print("FEHLER: " + what)


func new_state(seed_value := 12345, lvl := 1) -> GameState:
	var gs := GameState.new()
	gs.setup(seed_value, true, lvl)
	return gs


## Alles leere Erde, damit nichts von selbst passiert.
func empty_state(lvl := 1) -> GameState:
	var gs := new_state(12345, lvl)
	for f in gs.fields:
		f.kind = E
		f.fresh = 0
	return gs


func top(gs: GameState, x: int, z: int) -> FieldData:
	return gs.field_at(Vector3i(x, 1, z), UP)


func at(gs: GameState, p: Vector3i, n: Vector3i) -> FieldData:
	return gs.field_at(p, n)


func ids(fs: Array) -> Array:
	var out: Array = []
	for f in fs:
		out.append((f as FieldData).id)
	return out


func twist(gs: GameState, axis: int, layer: int, turns: int, ans: Dictionary = {}) -> Dictionary:
	return gs.play({"type": "twist", "axis": axis, "layer": layer, "turns": turns}, ans)


func _event(r: Dictionary, kind: String) -> Dictionary:
	for e in r["events"]:
		if str(e["type"]) == kind:
			return e
	return {}


func _has_event(r: Dictionary, kind: String) -> bool:
	return not _event(r, kind).is_empty()


func _count_events(r: Dictionary, kind: String) -> int:
	var n := 0
	for e in r["events"]:
		if str(e["type"]) == kind:
			n += 1
	return n


func _disaster_of(r: Dictionary) -> Dictionary:
	return _event(r, "disaster")


## Fingerabdruck eines Stands (für Rückgängig und Vorschau).
func sig(gs: GameState) -> String:
	var ks: Array = []
	for f in gs.fields:
		var fd: FieldData = f
		ks.append("%d%s%d%s" % [fd.kind, str(fd.p), fd.fresh, "b" if fd.burning else ""])
	return "%s|f%d e%d|r%d b%d m%d|l%d t%d mi%d|w%s|h%s|rng%d|c%s" % [str(ks), gs.faith, gs.faith_earned, gs.rain, gs.bolts,
		gs.monsoons, gs.lives, gs.twists, gs.misses, str(gs.wishes), str(gs.will), gs.rng.state, str(gs.completed)]


# =============================================================================
# Aufbau und Geometrie (wie im Würfelspiel)
# =============================================================================

func test_setup() -> void:
	var gs := new_state()
	check(gs.fields.size() == 54, "54 Felder")
	check(gs.lines().is_empty(), "am Start keine fertigen Dreierreihen")
	var only := true
	for f in gs.fields:
		if f.kind > MEADOW:
			only = false
	check(only, "Start nur mit Erde und Wiesen")
	check(gs.faith == 0 and gs.score == 0, "Start mit 0 Glauben (score ist der alte Name)")
	for sd in [1, 2, 3, 4, 5, 6, 7, 8]:
		var g := new_state(sd)
		var clumps := 0
		for f in g.fields:
			if f.kind != MEADOW:
				continue
			var m := 0
			for h in g.neighbors(f):
				if (h as FieldData).kind == MEADOW:
					m += 1
			if m >= 2:
				clumps += 1
		check(clumps == 0, "Seed %d: am Start nie drei Wiesen beisammen" % sd)
		check(g.nature_share() >= Balance.START_NATURE - 0.02, "Seed %d: genug Natur am Start (%.0f%%)" % [sd, g.nature_share() * 100.0])


func test_geometry() -> void:
	var gs := new_state()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 300:
		gs.apply_rotation(rng.randi_range(0, 2), rng.randi_range(-1, 1), [1, -1, 2][rng.randi_range(0, 2)])
	var keys := {}
	var ok := true
	for f in gs.fields:
		keys[GameState.pos_key(f.p, f.n)] = true
		if gs.neighbors(f).size() != 4:
			ok = false
	check(keys.size() == 54, "jeder Platz genau einmal belegt")
	check(ok, "jedes Feld hat 4 Nachbarn")
	var gs2 := new_state()
	var c := gs2.field_at(Vector3i(0, 1, 0), UP)
	gs2.apply_rotation(0, 0, 1)
	check(c.n != UP, "Mitte dreht mit der Mittelscheibe mit")


# =============================================================================
# 1. Art-Tabelle
# =============================================================================

func test_kind_table() -> void:
	var ok_next := true
	var ok_down := true
	var choice_kinds: Array = []
	for k in FieldData.KIND_COUNT:
		if FieldData.is_choice(k):
			choice_kinds.append(k)
		if not FieldData.finished(k):
			var nx := FieldData.next_kind(k, 0)
			if nx == k or not FieldData.valid(nx):
				ok_next = false
			if FieldData.is_choice(k) and FieldData.next_kind(k, 1) == nx:
				ok_next = false
		var d := FieldData.down(k)
		if d < 0 or d >= FieldData.KIND_COUNT or (k > 0 and FieldData.tier(d) >= FieldData.tier(k)):
			ok_down = false
	check(ok_next, "jede nicht fertige Art hat eine nächste Art (Wahl: zwei verschiedene)")
	check(choice_kinds == [MEADOW, BIGFOREST, VILLAGE, TOWN], "Wahl genau bei Wiese, Großer Wald, Dorf, Stadt (%s)" % str(choice_kinds))
	check(ok_down, "„fällt auf“ bleibt im Bereich und geht eine Stufe nach unten")
	var fin: Array = []
	for k in FieldData.KIND_COUNT:
		if FieldData.finished(k):
			fin.append(k)
			check(not FieldData.can_row(k) and FieldData.next_kind(k) == k, "%s ist fertig: keine Reihe, wächst nicht" % FieldData.kind_name(k))
	check(fin == [CHURCH, INDUSTRY, METROPOLIS, PARADISE], "fertige Arten (%s)" % str(fin))
	check(not FieldData.can_row(E), "Erde bildet keine Reihe")
	check(FieldData.options(MEADOW) == [FOREST, FIELD] and FieldData.options(BIGFOREST) == [ANIMALS, HUT]
		and FieldData.options(VILLAGE) == [TOWN, CHURCH] and FieldData.options(TOWN) == [BIGCITY, INDUSTRY], "Optionen in Tabellen-Reihenfolge")
	check(FieldData.next_kind(FIELD) == HUT and FieldData.next_kind(FOREST) == BIGFOREST and FieldData.next_kind(ANIMALS) == PARADISE
		and FieldData.next_kind(BIGCITY) == METROPOLIS and FieldData.next_kind(HUT) == HOUSE, "Leiter: Acker → Hütte, Wald → Großer Wald, Tiere → Paradies …")
	check(FieldData.down(CHURCH) == VILLAGE and FieldData.down(INDUSTRY) == TOWN and FieldData.down(PARADISE) == ANIMALS and Balance.WAR_DROP == HOUSE, "Fallen: Kirche → Dorf, Industrie → Stadt, Paradies → Tiere")
	var fam_ok := true
	for k in FieldData.KIND_COUNT:
		if FieldData.nature(k) and FieldData.people(k):
			fam_ok = false
	check(fam_ok and FieldData.people(CHURCH) and not FieldData.people(INDUSTRY) and FieldData.civ(FIELD), "Natur / Menschen / Zivilisation sauber getrennt")
	check(FieldData.KIND_ICON.size() == 15 and FieldData.KIND_NAME.size() == 15 and FieldData.KIND_HELP.size() == 15, "Namen, Icons und Erklärungen für alle 15 Arten")
	var inf := FieldData.info(CHURCH)
	check(int(inf["income"]) == 3 and bool(inf["finished"]) and str(inf["icon"]) == "church", "Art-Info für die Oberfläche (%s)" % str(inf))


# =============================================================================
# Wachsen und Wahl
# =============================================================================

func test_merge() -> void:
	var gs := empty_state()
	var a := top(gs, 1, -1)
	var b := top(gs, 1, 0)
	var c := top(gs, 1, 1)
	a.kind = FOREST
	b.kind = FOREST
	check(gs.lines().is_empty(), "zwei reichen nicht")
	c.kind = FIELD
	check(gs.lines().is_empty(), "verschiedene Arten verschmelzen nicht (Wald und Acker, gleiche Stufe)")
	c.kind = FOREST
	check(gs.lines().size() == 1, "drei Wälder in einer Reihe")
	gs.moved[c.id] = true
	var r := gs.end_round()
	check(c.kind == BIGFOREST, "das zuletzt dazugekommene Feld wird großer Wald (%d)" % c.kind)
	check(a.kind == FOREST and b.kind == FOREST, "die anderen beiden bleiben Wälder")
	check(int(r["gain"]) == int(Balance.GROW_FAITH[2]) and gs.faith == int(Balance.GROW_FAITH[2]), "Glaube fürs Wachsen (%d)" % int(r["gain"]))
	# Ganze Reihe verändert: die Mitte wächst
	var gw := empty_state()
	for x in [-1, 0, 1]:
		top(gw, x, 1).kind = FIELD
		gw.moved[top(gw, x, 1).id] = true
	gw.end_round()
	check(top(gw, 0, 1).kind == HUT and top(gw, -1, 1).kind == FIELD, "ganze Reihe verändert: die Mitte wächst (Acker → Hütte)")
	# Ganze Seite aus 9 gleichen
	var gf := empty_state()
	for f in gf.face_fields(UP):
		(f as FieldData).kind = FOREST
	gf.moved = {top(gf, 1, 1).id: true}
	var rf := gf.end_round()
	var all_big := true
	for f in gf.face_fields(UP):
		if (f as FieldData).kind != BIGFOREST:
			all_big = false
	check(all_big and int(rf["gain"]) == int(Balance.GROW_FAITH[2]) * Balance.FACE_BONUS, "ganze Seite wächst (+%d)" % int(rf["gain"]))
	var rf2 := gf.end_round()
	check(top(gf, 0, 0).kind == BIGFOREST and int(rf2["gain"]) == 0, "fertige Seite bleibt stehen")
	# Durch eine Drehung: das hineingedrehte Feld wächst
	var gr := empty_state()
	top(gr, -1, 1).kind = HUT
	top(gr, 0, 1).kind = HUT
	var third := gr.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1))
	third.kind = HUT
	gr.apply_rotation(0, 1, 1)
	check(top(gr, 1, 1) == third, "drittes Feld rückt in die Reihe")
	var rr := gr.end_round()
	check(third.kind == HOUSE and int(rr["gain"]) == int(Balance.GROW_FAITH[4]), "hineingedrehtes Feld wächst (Hütte → Haus)")
	# Mitgedreht zählt nicht
	var gn := empty_state()
	for x in [-1, 0, 1]:
		top(gn, x, 1).kind = HOUSE
	gn.apply_rotation(2, 1, 1)
	check(int(gn.end_round()["gain"]) == 0, "nur neu gebildete Reihen wachsen (mitgedreht zählt nicht)")
	# Die Leiter mit Antworten: Wiese -1→ Acker → Hütte → Haus → Dorf -0→ Stadt -1→ Industrie; Großstadt → Metropole
	var gl := empty_state()
	var path: Array = []
	var k := MEADOW
	for step in 7:
		for x in [-1, 0, 1]:
			top(gl, x, -1).kind = k
		gl.moved = {top(gl, 1, -1).id: true}
		var ans := {}
		if FieldData.is_choice(k):
			ans = {k: 1 if k != VILLAGE else 0}
		gl.end_round(ans)
		k = top(gl, 1, -1).kind
		path.append(k)
		if FieldData.finished(k):
			break
	check(path == [FIELD, HUT, HOUSE, VILLAGE, TOWN, INDUSTRY], "Leiter mit Antworten (%s)" % str(path))
	var gb := empty_state()
	for x in [-1, 0, 1]:
		top(gb, x, 0).kind = BIGCITY
	gb.moved = {top(gb, 1, 0).id: true}
	gb.end_round()
	check(top(gb, 1, 0).kind == METROPOLIS, "Großstadt → Metropole")
	# Diagonal: Mittel ab Stufe 2 (Wald), Wiesen nicht
	var gd := empty_state()
	top(gd, -1, -1).kind = MEADOW
	top(gd, 0, 0).kind = MEADOW
	top(gd, 1, 1).kind = MEADOW
	check(gd.lines().is_empty(), "Mittel: Wiesen verbinden sich nicht diagonal")
	for f in [top(gd, -1, -1), top(gd, 0, 0), top(gd, 1, 1)]:
		(f as FieldData).kind = FIELD
	check(gd.lines().size() == 1, "Mittel: Äcker (Stufe 2) verbinden sich auch diagonal")


func test_choice() -> void:
	# Wiesen-Reihe: mit Antwort 1 → Acker am Zielfeld, ohne Antwort die Gewohnheit (am Anfang Wald)
	for opt in [-1, 1, 0]:
		var gs := empty_state()
		top(gs, -1, 1).kind = MEADOW
		top(gs, 0, 1).kind = MEADOW
		var third := gs.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1))
		third.kind = MEADOW
		var ans := {} if opt < 0 else {MEADOW: opt}
		var r := twist(gs, 0, 1, 1, ans)
		var want := FIELD if opt == 1 else FOREST
		check(third.kind == want, "Wahl %d: Zielfeld wird %s (%s)" % [opt, FieldData.kind_name(want), FieldData.kind_name(third.kind)])
		check(top(gs, -1, 1).kind == MEADOW and top(gs, 0, 1).kind == MEADOW, "Wahl %d: die anderen beiden bleiben Wiese" % opt)
		check(gs.card == MEADOW and gs.card_field == third.id and gs.card_fields == [third.id], "Wahl %d: Karte Wiese am Zielfeld" % opt)
		var ce := _event(r, "choice")
		check(int(ce.get("kind", -1)) == MEADOW and int(ce.get("picked", -1)) == maxi(opt, 0) and (ce.get("options", []) as Array) == [FOREST, FIELD], "Wahl %d: Ereignis choice (%s)" % [opt, str(ce)])
		check(gs.habit(MEADOW) == maxi(opt, 0), "Wahl %d: die Antwort wird zur Gewohnheit" % opt)
	# Gewohnheit gilt danach als Standard
	var gh := empty_state()
	gh.will[MEADOW] = 1
	for x in [-1, 0, 1]:
		top(gh, x, 0).kind = MEADOW
	gh.moved = {top(gh, 1, 0).id: true}
	gh.end_round()
	check(top(gh, 1, 0).kind == FIELD, "ohne Antwort gilt die Gewohnheit (Acker)")
	# Keine Wahl: keine Karte
	var gn := empty_state()
	for x in [-1, 0, 1]:
		top(gn, x, 0).kind = FOREST
	gn.moved = {top(gn, 1, 0).id: true}
	var rn := gn.end_round({MEADOW: 1})
	check(gn.card == -1 and not _has_event(rn, "choice"), "Wald → Großer Wald: keine Karte")


## Zwei Wahlen in einem Zug: Die erste in lines()-Reihenfolge bekommt die Karte, die zweite nimmt die Gewohnheit.
func test_one_card() -> void:
	var gs := empty_state()
	for x in [-1, 0, 1]:
		top(gs, x, 1).kind = TOWN
		top(gs, x, -1).kind = MEADOW
	gs.moved = {top(gs, 1, 1).id: true, top(gs, 1, -1).id: true}
	var first: int = (gs.lines(gs.moved)[0][0] as FieldData).kind
	var second := MEADOW if first == TOWN else TOWN
	var probe := gs.clone()
	probe.end_round({})
	check(probe.card == first, "eine Karte pro Zug: die erste Reihe in lines()-Reihenfolge (%s)" % FieldData.kind_name(probe.card))
	var real := gs.clone()
	real.will[second] = 1
	real.end_round({first: 1, second: 0})
	var kf: int = real.field_at(Vector3i(1, 1, 1 if first == TOWN else -1), UP).kind
	var ks: int = real.field_at(Vector3i(1, 1, 1 if second == TOWN else -1), UP).kind
	check(kf == FieldData.next_kind(first, 1), "Karten-Art nimmt die Antwort (%s)" % FieldData.kind_name(kf))
	check(ks == FieldData.next_kind(second, 1), "zweite Wahl im selben Zug nimmt die Gewohnheit, nicht die Antwort (%s)" % FieldData.kind_name(ks))
	check(real.habit(first) == 1 and real.habit(second) == 1, "nur die Karte ändert die Gewohnheit")
	Balance.OTHER_CHOICE_HABIT = false
	var model := gs.clone()
	model.will[second] = 1
	model.end_round({first: 1})
	var km: int = model.field_at(Vector3i(1, 1, 1 if second == TOWN else -1), UP).kind
	Balance.OTHER_CHOICE_HABIT = true
	check(km == FieldData.next_kind(second, 0), "Schalter OTHER_CHOICE_HABIT = false: zweite Wahl nimmt Option 1 (wie das Python-Modell)")


## Die Karte hängt nicht von der Antwort ab: probe.card == card der echten Runde (200 Würfel × 27 Drehungen).
func test_card_deterministic() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var bad := 0
	var cards := 0
	for b in 200:
		var gs := new_state(1000 + b, b % 3)
		for f in gs.fields:
			var r := rng.randf()
			(f as FieldData).kind = rng.randi_range(0, 9) if r < 0.85 else rng.randi_range(0, 14)
		for m in GameState.MOVES:
			var act := {"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])}
			var p: GameState = gs.simulate(act)["state"]
			if p.card < 0:
				continue
			cards += 1
			var real: GameState = gs.simulate(act, {p.card: 1 - gs.habit(p.card)})["state"]
			if real.card != p.card or real.card_field != p.card_field:
				bad += 1
	check(bad == 0 and cards > 500, "Karte ist deterministisch (%d Karten, %d abweichend)" % [cards, bad])


func test_cascade() -> void:
	var gs := empty_state()
	top(gs, 1, -1).kind = FOREST
	top(gs, 1, 0).kind = FOREST
	top(gs, 1, 1).kind = FOREST
	top(gs, 0, 1).kind = BIGFOREST
	top(gs, -1, 1).kind = BIGFOREST
	gs.moved = {top(gs, 1, 1).id: true}
	var ev: Array = []
	var pts := gs.resolve_merges(ev)
	check(ev.size() == 2, "Kettenreaktion: zwei Verschmelzungen (%d)" % ev.size())
	if ev.size() == 2:
		check(int(ev[1]["combo"]) == 2, "zweite zählt als Kombo")
		check(int(ev[1]["field"]) == top(gs, 1, 1).id and top(gs, 1, 1).kind == ANIMALS, "Kombo wächst am selben Feld weiter (Wald → Großer Wald → Tiere)")
	check(pts == int(Balance.GROW_FAITH[2]) + int(Balance.GROW_FAITH[3]) * 2, "Kombo verdoppelt (%d)" % pts)
	check(gs.card == BIGFOREST, "die Kettenreaktion bringt die Karte (Großer Wald)")


# =============================================================================
# Einfach: Gruppen
# =============================================================================

func test_easy_groups() -> void:
	# Wiesen-Gruppe aus 5 + Reihe → alle 5 werden die gewählte Art
	var gs := empty_state(0)
	for x in [-1, 0, 1]:
		top(gs, x, 1).kind = MEADOW
	top(gs, 1, 0).kind = MEADOW
	top(gs, 1, -1).kind = MEADOW     # Gruppe: 5 Wiesen (die Spalte x = 1 ist auch eine Reihe)
	gs.moved = {top(gs, -1, 1).id: true}
	gs.end_round({MEADOW: 1})
	var all_field := true
	for f in [top(gs, -1, 1), top(gs, 0, 1), top(gs, 1, 1), top(gs, 1, 0), top(gs, 1, -1)]:
		if (f as FieldData).kind != FIELD:
			all_field = false
	check(all_field, "Einfach: die ganze Wiesen-Gruppe wird Acker")
	check(gs.card == MEADOW and gs.card_fields.size() == 5, "Einfach: eine Karte für die ganze Gruppe (%d Felder)" % gs.card_fields.size())
	# Dorf-Gruppe aus 5 + Reihe mit Kirche → nur die 3 Felder der Reihe werden Kirche
	var gv := empty_state(0)
	for x in [-1, 0, 1]:
		top(gv, x, 1).kind = VILLAGE
	top(gv, 1, 0).kind = VILLAGE
	top(gv, 0, 0).kind = VILLAGE
	gv.moved = {top(gv, -1, 1).id: true}
	gv.end_round({VILLAGE: 1})
	var row_church := top(gv, -1, 1).kind == CHURCH and top(gv, 0, 1).kind == CHURCH and top(gv, 1, 1).kind == CHURCH
	check(row_church and top(gv, 1, 0).kind == VILLAGE and top(gv, 0, 0).kind == VILLAGE, "Einfach: fertige Art (Kirche) nur in der Reihe, der Rest bleibt Dorf")
	var gt := empty_state(0)
	for x in [-1, 0, 1]:
		top(gt, x, 1).kind = VILLAGE
	top(gt, 1, 0).kind = VILLAGE
	gt.moved = {top(gt, -1, 1).id: true}
	var rt := gt.end_round({VILLAGE: 0})
	check(top(gt, 1, 0).kind == TOWN and top(gt, 0, 1).kind == TOWN, "Einfach: Stadt (nicht fertig) wächst in der ganzen Gruppe")
	check(int(rt["gain"]) == int(Balance.GROW_FAITH[6]) * 4 / 3, "Einfach: Glaube × Gruppengröße / 3 (%d)" % int(rt["gain"]))


## Einfach: hin und her, zusammen gewachsene Reihen (aus dem Würfelspiel).
func test_easy_repeat() -> void:
	var gs := empty_state(0)
	top(gs, 0, 0).kind = FOREST
	top(gs, 1, 0).kind = FOREST
	top(gs, 1, 1).kind = FOREST
	gs.moved = {top(gs, 1, 1).id: true}
	check(int(gs.end_round()["gain"]) == 0, "Einfach: ohne Reihe passiert nichts")
	top(gs, -1, 0).kind = FOREST
	gs.moved = {top(gs, -1, 0).id: true}
	var r := gs.end_round()
	var all3 := top(gs, -1, 0).kind == BIGFOREST and top(gs, 0, 0).kind == BIGFOREST and top(gs, 1, 0).kind == BIGFOREST and top(gs, 1, 1).kind == BIGFOREST
	check(int(r["gain"]) > 0 and all3, "Einfach: Reihe löst aus, alle zusammenhängenden wachsen")
	gs.apply_rotation(0, -1, 1)
	gs.end_round()
	gs.apply_rotation(0, -1, -1)
	var rb := gs.end_round()
	check(int(rb["gain"]) == 0 and top(gs, 0, 0).kind == BIGFOREST, "Einfach: hin und her bringt nichts")
	check(_has_event(rb, "repeat") and str(_event(rb, "miss").get("why", "")) == "repeat", "hin und her: die Oberfläche erfährt, warum nichts wächst")
	gs.misses = 0
	gs.apply_rotation(0, -1, 1)
	gs.end_round()
	gs.apply_rotation(1, -1, 1)
	gs.end_round()
	gs.apply_rotation(0, -1, -1)
	var r3 := gs.end_round()
	check(int(r3["gain"]) == 0 and str(_event(r3, "miss").get("why", "")) == "spent", "Einfach: zusammen gewachsene Reihe zählt nie wieder (%s)" % str(_event(r3, "miss").get("why", "")))


# =============================================================================
# Fertige Felder, Krieg
# =============================================================================

func test_finished_no_row() -> void:
	for k in [PARADISE, INDUSTRY, METROPOLIS, CHURCH]:
		var gs := empty_state()
		top(gs, -1, 1).kind = k
		top(gs, 0, 1).kind = k
		gs.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1)).kind = k
		gs.faith = 100
		var r := twist(gs, 0, 1, 1)
		check(int(r["grew"]) == 0 and int(r["gain"]) == 0 and gs.misses == 1, "3 × %s in einer neuen Reihe: wächst nicht, zählt als Fehlversuch" % FieldData.kind_name(k))
	var gf := empty_state()
	for f in gf.face_fields(UP):
		(f as FieldData).kind = PARADISE
	gf.moved = {top(gf, 0, 0).id: true}
	var rf := gf.end_round()
	check(int(rf["gain"]) == 0 and not _has_event(rf, "face"), "9 × Paradies: kein Seiten-Bonus")
	check(gf.stuck() == false or gf.rain > 0, "fertige Felder zählen nicht als verbindbar")
	var gx := empty_state()
	gx.rain = 0
	for f in gx.face_fields(UP):
		(f as FieldData).kind = METROPOLIS
	check(gx.stuck(), "nur fertige Felder: nichts mehr zu verbinden")


func test_war() -> void:
	# Zwei getrennte Kirchen, die eine Drehung zusammenbringt
	var gs := empty_state()
	var a := top(gs, -1, 0)
	var b := gs.field_at(Vector3i(1, 0, -1), Vector3i(0, 0, -1))   # kommt mit x = 1 nach oben auf (1, 0)
	a.kind = CHURCH
	var c2 := top(gs, 0, 0)
	c2.kind = CHURCH        # a und c2 sind eine Gemeinde
	b.kind = CHURCH
	gs.faith = 200
	check(not gs.neighbors(b).has(c2), "vorher berühren sich die Gemeinden nicht")
	var r := twist(gs, 0, 1, 1)
	check(gs.neighbors(b).has(c2), "die Drehung bringt die Kirchen zusammen")
	var we := _event(r, "war")
	var loss := maxi(Balance.WAR_FAITH_MIN, (200 + int(r["gain"])) * Balance.WAR_FAITH_PCT / 100)
	check(not we.is_empty() and (we["fields"] as Array).has(b.id) and (we["fields"] as Array).has(c2.id), "Krieg: Ereignis mit den Kirchen (%s)" % str(we))
	check(b.kind == HOUSE and c2.kind == HOUSE, "Krieg: beide Kirchen werden Haus")
	check(a.kind == CHURCH, "Krieg: die Kirche, die nicht direkt kämpft, bleibt")
	check(int(r["loss"]) == loss and gs.faith == 200 + int(r["gain"]) - loss + int(r["income"]), "Krieg kostet max(20, 20 %%) Glauben (%d, Glaube %d)" % [int(r["loss"]), gs.faith])
	check(int(gs.stats["wars"]) == 1, "Krieg gezählt")
	# Wenig Glaube: mindestens 20, nie unter 0
	var gp := empty_state()
	gp.field_at(Vector3i(1, 0, -1), Vector3i(0, 0, -1)).kind = CHURCH
	top(gp, 0, 0).kind = CHURCH
	gp.faith = 10
	var rp := twist(gp, 0, 1, 1)
	check(_has_event(rp, "war") and int(rp["loss"]) == Balance.WAR_FAITH_MIN and gp.faith == 0, "Krieg bei wenig Glauben: −20, aber nie unter 0")
	# Zwei benachbarte Kirchen drehen zusammen mit: kein Krieg
	var gn := empty_state()
	top(gn, -1, 0).kind = CHURCH
	top(gn, 0, 0).kind = CHURCH
	var rn := twist(gn, 1, 1, 1)
	check(not _has_event(rn, "war") and gn.count(CHURCH) == 2, "benachbarte Kirchen drehen zusammen mit: kein Krieg (eine Gemeinde)")
	# Eine Kirche wächst neben eine Kirche (in derselben Drehung bewegt): kein Krieg, auch später nicht
	var gb := empty_state()
	top(gb, -1, 1).kind = VILLAGE
	top(gb, 0, 1).kind = VILLAGE
	gb.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1)).kind = VILLAGE
	var old := gb.field_at(Vector3i(1, 0, -1), Vector3i(0, 0, -1))
	old.kind = CHURCH                     # kommt mit derselben Drehung neben das Zielfeld (1, 1)
	var rb := twist(gb, 0, 1, 1, {VILLAGE: 1})
	var born := top(gb, 1, 1)
	check(born.kind == CHURCH and gb.neighbors(born).has(old), "Kirche wächst neben einer Kirche")
	check(not _has_event(rb, "war"), "neu gewachsene Kirche kämpft nicht im selben Zug")
	var rb2 := twist(gb, 1, -1, 1)
	var rb3 := twist(gb, 1, 1, 1)
	check(not _has_event(rb2, "war") and not _has_event(rb3, "war") and born.kind == CHURCH, "später auch nicht: sie sind eine Gemeinde")
	# Werkzeuge lösen nie Krieg aus
	var gt := empty_state()
	for f in gt.face_fields(UP):
		(f as FieldData).kind = VILLAGE
	top(gt, 0, 0).kind = CHURCH
	gt.monsoons = 1
	gt.faith = 500
	var rt := gt.play({"type": "monsoon", "field": top(gt, 1, 1).id}, {VILLAGE: 1})
	check(gt.count(CHURCH) == 9 and not _has_event(rt, "war"), "Monsun macht eine Seite voller Kirchen: kein Krieg")
	gt.bolts = 1
	var rbo := gt.play({"type": "bolt", "field": gt.field_at(Vector3i(1, 1, 1), Vector3i(1, 0, 0)).id})
	gt.rain = 1
	var rra := gt.play({"type": "rain", "field": gt.field_at(Vector3i(0, -1, 0), Vector3i(0, -1, 0)).id})
	var rst := gt.play({"type": "strike", "field": top(gt, 0, 0).id})
	check(not _has_event(rbo, "war") and not _has_event(rra, "war") and not _has_event(rst, "war"), "Blitz, Regen, Gewitter: nie Krieg")
	var rtw := twist(gt, 1, -1, 1)
	check(not _has_event(rtw, "war"), "danach: eine große Gemeinde, kein Krieg")
	# Alle Fälle: Jede neue Berührung zweier einzelner Kirchen durch eine Drehung ist Krieg, sonst keiner
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var contacts := 0
	var wrong := 0
	for i in 300:
		var g := empty_state()
		var i1 := rng.randi_range(0, 53)
		var i2 := rng.randi_range(0, 53)
		if i1 == i2 or g.neighbors(g.fields[i1]).has(g.fields[i2]):
			continue
		(g.fields[i1] as FieldData).kind = CHURCH
		(g.fields[i2] as FieldData).kind = CHURCH
		for m in GameState.MOVES:
			var s := g.clone()
			var rr := twist(s, int(m[0]), int(m[1]), int(m[2]))
			var touching := s.neighbors(s.fields[i1]).has(s.fields[i2])
			var after := g.clone()
			after.apply_rotation(int(m[0]), int(m[1]), int(m[2]))
			touching = after.neighbors(after.fields[i1]).has(after.fields[i2])
			if touching:
				contacts += 1
			if touching != _has_event(rr, "war"):
				wrong += 1
	check(contacts > 40 and wrong == 0, "jede neue Kirchen-Berührung durch eine Drehung ist Krieg (%d Fälle, %d falsch)" % [contacts, wrong])


# =============================================================================
# Weltwaage, Smog, Nachwachsen, Glaube pro Drehung
# =============================================================================

func test_balance_and_smog() -> void:
	var gs := empty_state()
	check(gs.balance() == 0, "leere Welt: Waage 0")
	top(gs, 0, 0).kind = FOREST
	top(gs, 1, 1).kind = PARADISE
	check(gs.balance() == -100 and gs.zone() == "wild", "nur Natur: −100 (Wildnis)")
	var g2 := empty_state()
	for i in 10:
		(g2.fields[i] as FieldData).kind = INDUSTRY
	(g2.fields[20] as FieldData).kind = BIGFOREST
	check(g2.balance() == 90 and g2.zone() == "smog" and g2.smog(), "10 Industrie + 1 großer Wald: 90 (Smog) (%d)" % g2.balance())
	check(GameState.zone_of(19) == "ok" and GameState.zone_of(20) == "city" and GameState.zone_of(49) == "city" and GameState.zone_of(-49) == "ok" and GameState.zone_of(-50) == "wild", "Zonen-Grenzen")
	# Smog: kein Glaube, jede Industrie lässt den höchsten Natur-Nachbarn welken, kein Nachwachsen
	var gm := empty_state()
	var ind := top(gm, 0, 0)
	ind.kind = INDUSTRY
	top(gm, 1, 0).kind = ANIMALS
	top(gm, -1, 0).kind = MEADOW
	top(gm, 0, 1).kind = INDUSTRY
	top(gm, 0, -1).kind = INDUSTRY
	gm.field_at(Vector3i(0, -1, 0), Vector3i(0, -1, 0)).kind = INDUSTRY
	gm.field_at(Vector3i(1, 1, -1), Vector3i(1, 0, 0)).kind = FOREST
	var empty_spot := top(gm, 1, -1)         # Erde mit 2 Natur-Nachbarn: Tiere (1, 0) und der Wald über der Kante
	check(gm._count_neighbors(empty_spot, "nature") == 2, "Aufbau: Erde mit 2 Natur-Nachbarn")
	gm.faith = 50
	check(gm.balance() >= Balance.SMOG_AT, "Aufbau Smog (%d)" % gm.balance())
	var r := twist(gm, 1, -1, 1)
	check(_has_event(r, "smog") and int(r["income"]) == 0, "Smog: kein Glaube pro Drehung")
	check(top(gm, 1, 0).kind == BIGFOREST, "Smog: Tiere fliehen (Tiere → Großer Wald) – der höchste Nachbar zuerst")
	check(top(gm, -1, 0).kind == MEADOW or top(gm, -1, 0).kind == E, "Smog: Wiese welkt höchstens zu Erde")
	check(_count_events(r, "polluted") >= 1 and top(gm, 1, 0).fresh > 0, "Smog: Ereignis polluted, das Feld raucht")
	check(not _has_event(r, "regrow") and empty_spot.kind == E, "Smog: nichts wächst nach")
	check(int(gm.stats["smog"]) == 1 and gm.tool_unlocked("flood"), "Smog gezählt, Flut ist aufgedeckt")
	var be := _event(r, "balance")
	check(be.is_empty() or str(be["zone"]) == "smog", "Waage: Ereignis nur bei Zonenwechsel")


func test_regrow() -> void:
	var gs := empty_state()
	top(gs, 0, 0).kind = MEADOW
	top(gs, 1, 1).kind = FOREST
	top(gs, -1, -1).kind = FOREST
	top(gs, -1, 1).kind = MEADOW
	# Erde (1,0): Nachbarn (0,0) Wiese, (1,1) Wald → 2. Erde (0,1): (0,0), (1,1), (-1,1) → 3. Erde (-1,0): (0,0), (-1,-1), (-1,1) → 3.
	var r := twist(gs, 1, -1, 1)
	check(_count_events(r, "regrow") == 1, "pro Drehung genau ein Feld wächst nach")
	var e := _event(r, "regrow")
	var f3 := [top(gs, 0, 1).id, top(gs, -1, 0).id]
	f3.sort()
	check(int(e.get("field", -1)) == int(f3[0]) and (gs.fields[int(f3[0])] as FieldData).kind == MEADOW, "die meisten Natur-Nachbarn zuerst, dann die kleinste ID")
	# Nicht auf rauchenden Feldern
	var gf := empty_state()
	top(gf, 0, 0).kind = MEADOW
	top(gf, 1, 1).kind = FOREST
	top(gf, 1, 0).fresh = 2
	var rf := twist(gf, 1, -1, 1)
	check(int(_event(rf, "regrow").get("field", -1)) != top(gf, 1, 0).id and top(gf, 1, 0).kind == E, "nicht auf rauchenden (frisch verwüsteten) Feldern")
	# Nie bei Regen oder Werkzeug-Zügen
	var gt := empty_state()
	top(gt, 0, 0).kind = MEADOW
	top(gt, 1, 1).kind = FOREST
	gt.rain = 1
	var rr := gt.play({"type": "rain", "field": gt.field_at(Vector3i(0, -1, 0), Vector3i(0, -1, 0)).id})
	gt.bolts = 1
	var rb := gt.play({"type": "bolt", "field": gt.field_at(Vector3i(-1, -1, -1), Vector3i(0, -1, 0)).id})
	check(not _has_event(rr, "regrow") and not _has_event(rb, "regrow") and top(gt, 1, 0).kind == E, "kein Nachwachsen bei Regen und Blitz")


func test_income() -> void:
	var gs := empty_state()
	top(gs, -1, -1).kind = CHURCH
	top(gs, 1, -1).kind = INDUSTRY
	top(gs, -1, 1).kind = METROPOLIS
	top(gs, 1, 1).kind = PARADISE
	gs.field_at(Vector3i(0, -1, 0), Vector3i(0, -1, 0)).kind = BIGFOREST
	gs.field_at(Vector3i(0, 0, 1), Vector3i(0, 0, 1)).kind = BIGFOREST
	gs.field_at(Vector3i(0, 0, -1), Vector3i(0, 0, -1)).kind = BIGFOREST
	check(gs.balance() < Balance.SMOG_AT and gs.income_rate() == 11, "Glaube pro Drehung: Kirche 3 + Industrie 5 + Metropole 2 + Paradies 1 (%d, W %d)" % [gs.income_rate(), gs.balance()])
	var r := twist(gs, 0, 0, 2)
	check(int(r["income"]) == 11 and _has_event(r, "income") and int(_event(r, "faith").get("income", 0)) == 11, "Drehung bringt 11 Glauben pro Drehung (%d)" % int(r["income"]))
	var f0 := gs.faith
	gs.moved = {}
	var r2 := gs.end_round()
	check(int(r2["income"]) == 0 and gs.faith == f0, "kein Glaube pro Drehung ohne Drehung")
	gs.rain = 1
	var rr := gs.play({"type": "rain", "field": gs.field_at(Vector3i(-1, -1, 0), Vector3i(0, -1, 0)).id})
	check(int(rr["income"]) == 0, "kein Glaube pro Drehung beim Regen")
	gs.calm = true
	var rn := twist(gs, 0, 0, 2)
	check(int(rn["income"]) == 0, "Tutorial: kein Glaube pro Drehung")
	gs.calm = false
	for i in 12:
		(gs.fields[i] as FieldData).kind = INDUSTRY if (gs.fields[i] as FieldData).kind == E else (gs.fields[i] as FieldData).kind
	var rs := twist(gs, 0, 0, 2)
	check(gs.smog() and int(rs["income"]) == 0, "Smog: 0 Glauben pro Drehung")


# =============================================================================
# Wünsche
# =============================================================================

func test_wishes() -> void:
	var saved_regrow := Balance.REGROW_PER_TWIST
	Balance.REGROW_PER_TWIST = 0         # damit die Waage im Grünen bleibt
	var saved_rain := Balance.RAIN_EVERY_TWISTS
	Balance.RAIN_EVERY_TWISTS = 0        # kein Regen: Regen-Wünsche gehen nicht
	var gs := empty_state()
	gs.no_fire = true
	gs.rain = 0
	for p in [Vector3i(-1, -1, 1), Vector3i(0, -1, 1), Vector3i(1, -1, 0)]:
		gs.field_at(p, Vector3i(0, -1, 0)).kind = HUT
	top(gs, 0, 0).kind = FOREST          # das Ziel „Wald“ gibt es
	top(gs, 1, 1).kind = MEADOW
	top(gs, -1, -1).kind = MEADOW
	var made_at: Array = []
	for t in 12:
		var r := twist(gs, 0, 0, 2) if t % 2 == 0 else twist(gs, 0, 0, -2)
		if _has_event(r, "wish"):
			made_at.append(gs.twists)
			var w: Dictionary = _event(r, "wish")["wish"]
			check((gs.fields[int(w["field"])] as FieldData).is_people(), "Wunsch nur an Menschen-Feldern")
			check(str(w["type"]) == "wald", "Wunsch nur mit erreichbarem Ziel: hier nur Wald (%s)" % str(w["type"]))
	Balance.REGROW_PER_TWIST = saved_regrow
	Balance.RAIN_EVERY_TWISTS = saved_rain
	var only4 := true
	for t in made_at:
		if int(t) % Balance.WISH_EVERY != 0:
			only4 = false
	check(made_at.size() >= 2 and int(made_at[0]) == 4 and only4, "Wünsche nur bei Drehung 4, 8, … (%s)" % str(made_at))
	check(gs.wishes.size() <= Balance.WISH_MAX, "höchstens 2 Wünsche")
	var gx := gs.clone()
	gx.wishes = [{"id": 90, "type": "wald", "field": 0, "left": 8}, {"id": 91, "type": "wald", "field": 1, "left": 8}]
	gx.twists = 15
	(gx.fields[0] as FieldData).kind = HUT
	(gx.fields[1] as FieldData).kind = HUT
	var rx := twist(gx, 0, 0, 2)
	check(not _has_event(rx, "wish") and gx.wishes.size() <= 2, "bei 2 Wünschen kommt kein neuer")
	var gz := empty_state()
	gz.rain = 0
	gz.no_fire = true
	top(gz, 0, 0).kind = HUT
	var any := false
	for t in 4:
		if _has_event(twist(gz, 1, -1, 1), "wish"):
			any = true
	check(not any, "kein Wunsch, wenn kein Ziel erreichbar ist (kein Wald, Tiere, Acker, Regen)")
	# Erfüllt durch Nachbarschaft nach einer Drehung: +15 und das Feld wächst
	var gf := empty_state()
	var hut := top(gf, 0, 0)
	hut.kind = HUT
	gf.wishes = [{"id": 1, "type": "wald", "field": hut.id, "left": 8}]
	var forest := gf.field_at(Vector3i(1, 0, -1), Vector3i(0, 0, -1))
	forest.kind = FOREST                     # kommt mit x = 1 nach oben auf (1, 0), neben die Hütte?
	var rf := twist(gf, 0, 1, 1)
	var near := gf.neighbors(hut).has(forest)
	var de := _event(rf, "wish_done")
	check(near and not de.is_empty() and hut.kind == HOUSE and gf.wishes.is_empty(), "Wunsch erfüllt: Hütte wird Haus (%s)" % str(de))
	check(int(rf["faith"]) >= Balance.WISH_FAITH and int(_event(rf, "faith").get("wish", 0)) == Balance.WISH_FAITH, "Wunsch erfüllt: +15 Glauben")
	check(int(gf.stats["wish_ok"]) == 1, "erfüllter Wunsch gezählt")
	# Die Hütte, die der Wunsch zum Haus macht, ist eine Wiese? Nein – wächst mit Wahl: Dorf → Karte
	var gc := empty_state()
	var vil := top(gc, 0, 0)
	vil.kind = VILLAGE
	top(gc, 1, 0).kind = FIELD
	gc.wishes = [{"id": 2, "type": "acker", "field": vil.id, "left": 8}]
	twist(gc, 1, -1, 1, {VILLAGE: 1})
	check(vil.kind == CHURCH and gc.card == VILLAGE, "erfüllter Wunsch eines Dorfs: die Wahl gilt (Kirche)")
	# Regen auf derselben Seite erfüllt einen Regen-Wunsch, auf einer anderen nicht
	var gr := empty_state()
	var h2 := top(gr, -1, -1)
	h2.kind = HUT
	gr.rain = 2
	gr.wishes = [{"id": 3, "type": "regen", "field": h2.id, "left": 8}]
	var r_other := gr.play({"type": "rain", "field": gr.field_at(Vector3i(0, -1, 0), Vector3i(0, -1, 0)).id})
	check(not _has_event(r_other, "wish_done") and gr.wishes.size() == 1, "Regen auf einer anderen Seite: Wunsch bleibt")
	var f_before := gr.faith
	var r_same := gr.play({"type": "rain", "field": top(gr, 1, 1).id})
	check(_has_event(r_same, "wish_done") and h2.kind == HOUSE and gr.faith >= f_before + Balance.WISH_FAITH and gr.wishes.is_empty(), "Regen auf derselben Seite erfüllt den Regen-Wunsch")
	# Abgelaufen nach 8 Drehungen
	var ge := empty_state()
	ge.no_fire = true
	var h3 := top(ge, 0, 0)
	h3.kind = HUT
	ge.wishes = [{"id": 4, "type": "tiere", "field": h3.id, "left": Balance.WISH_TWISTS}]
	ge.twists = 1
	var expired_at := -1
	for t in 10:
		var rr := twist(ge, 1, -1, 1)
		if _has_event(rr, "wish_expired"):
			expired_at = t + 1
			break
	check(expired_at == Balance.WISH_TWISTS and h3.kind == HUT, "nicht erfüllt: nach 8 Drehungen weg, sonst passiert nichts (%d)" % expired_at)
	# Der Wunsch fährt mit seinem Feld
	var gm := empty_state()
	var h4 := top(gm, 1, 1)
	h4.kind = HUT
	gm.wishes = [{"id": 5, "type": "tiere", "field": h4.id, "left": 8}]
	var p0 := h4.p
	twist(gm, 0, 1, 1)
	check(int(gm.wishes[0]["field"]) == h4.id and h4.p != p0 and int(gm.wishes[0]["left"]) == 7, "der Wunsch fährt mit seinem Feld (gleiche ID, neuer Platz)")
	# Kopie ist tief
	var cl := gm.clone()
	cl.wishes[0]["left"] = 1
	cl.wishes.append({"id": 6, "type": "wald", "field": 0, "left": 3})
	check(int(gm.wishes[0]["left"]) == 7 and gm.wishes.size() == 1, "clone() kopiert Wünsche tief")
	# Keine Menschen mehr am Feld (Gewitter): der Wunsch verschwindet
	var gg := empty_state()
	var h5 := top(gg, 0, 0)
	h5.kind = HUT
	gg.faith = 100
	gg.wishes = [{"id": 7, "type": "wald", "field": h5.id, "left": 8}]
	var rg := gg.play({"type": "strike", "field": h5.id})
	check(h5.kind == FIELD and gg.wishes.is_empty() and _has_event(rg, "wish_gone"), "Gewitter auf die Hütte: der Wunsch verschwindet")


# =============================================================================
# Werkzeuge
# =============================================================================

func test_tools() -> void:
	var gs := empty_state()
	gs.rain = 3
	var m := top(gs, 0, 0)
	m.kind = MEADOW
	var t0 := gs.turn
	var r := gs.play({"type": "rain", "field": m.id})
	check(m.kind == FOREST and gs.card == -1 and not _has_event(r, "choice"), "Regen: Wiese → Wald ohne Karte")
	check(gs.turn == t0 and gs.twists == 0 and gs.rain == 2, "Regen ist kein Zug")
	var e := top(gs, 1, 1)
	gs.play({"type": "rain", "field": e.id})
	check(e.kind == MEADOW, "Regen: Erde → Wiese")
	gs.play({"type": "rain", "field": m.id})
	check(m.kind == BIGFOREST and gs.rain == 0, "Regen: Wald → Großer Wald")
	gs.rain = 1
	var h := top(gs, -1, -1)
	h.kind = HUT
	check(gs.can_bonus("rain", h) != "", "Regen geht nicht auf eine Hütte")
	h.burning = true
	check(gs.can_bonus("rain", h) == "", "Regen löscht Feuer auf jedem Feld")
	gs.play({"type": "rain", "field": h.id})
	check(not h.burning and h.kind == HUT, "Regen löscht nur")
	gs.rain = 0
	check(gs.can_bonus("rain", e).begins_with("Nächster Regen"), "ohne Regen: Grund")
	# Gewitter
	var gt := empty_state()
	gt.faith = 100
	var ind := top(gt, 0, 0)
	ind.kind = INDUSTRY
	var rt := gt.play({"type": "strike", "field": ind.id})
	check(ind.kind == E and ind.fresh > 0 and gt.faith == 100 - Balance.STRIKE_COST, "Gewitter: Industrie → Erde (raucht), −15 Glauben")
	check(_has_event(rt, "strike") and int(_event(rt, "strike")["cost"]) == Balance.STRIKE_COST, "Gewitter: Ereignis strike")
	var tw := top(gt, 1, 1)
	tw.kind = TOWN
	gt.play({"type": "strike", "field": tw.id})
	check(tw.kind == VILLAGE, "Gewitter: alles andere fällt eine Stufe")
	var mm := top(gt, -1, 1)
	mm.kind = MEADOW
	gt.play({"type": "strike", "field": mm.id})
	check(mm.kind == E, "Gewitter: Wiese → Erde")
	check(gt.can_bonus("strike", top(gt, -1, -1)) != "", "Gewitter: nicht auf leere Erde")
	gt.faith = 10
	check(gt.can_bonus("strike", tw) == "Dafür brauchst du 15 Glauben.", "Gewitter ohne genug Glauben: ausgegraut mit Text")
	check(not gt.tool_unlocked("strike") or gt.ever.has(INDUSTRY), "Gewitter kommt mit dem ersten fertigen Feld")
	# Flut: alle Äcker, Menschen, Kirchen, Industrie der Seite fallen; Natur bleibt; Feuer gehen aus
	var gf := empty_state()
	gf.faith = 100
	top(gf, -1, -1).kind = FIELD
	top(gf, 0, -1).kind = CHURCH
	top(gf, 1, -1).kind = INDUSTRY
	top(gf, -1, 0).kind = BIGCITY
	top(gf, 0, 0).kind = FOREST
	top(gf, 1, 0).kind = ANIMALS
	top(gf, 1, 1).kind = HUT
	top(gf, 0, 0).burning = true
	var outside := gf.field_at(Vector3i(0, 0, 1), Vector3i(0, 0, 1))
	outside.kind = TOWN
	var rf := gf.play({"type": "flood", "field": top(gf, 0, 0).id})
	check(top(gf, -1, -1).kind == MEADOW and top(gf, 0, -1).kind == VILLAGE and top(gf, 1, -1).kind == E and top(gf, -1, 0).kind == TOWN and top(gf, 1, 1).kind == FIELD, "Flut: Stadt und Industrie schrumpfen")
	check(top(gf, 0, 0).kind == FOREST and top(gf, 1, 0).kind == ANIMALS and not top(gf, 0, 0).burning, "Flut: Natur bleibt, Feuer gehen aus")
	check(outside.kind == TOWN and gf.faith == 100 - Balance.FLOOD_COST and _has_event(rf, "flood"), "Flut: nur die eine Seite, −40 Glauben")
	gf.faith = 39
	check(gf.can_bonus("flood", outside) == "Dafür brauchst du 40 Glauben.", "Flut ohne genug Glauben: ausgegraut")
	gf.faith = 100
	check(gf.can_bonus("flood", gf.field_at(Vector3i(0, -1, 0), Vector3i(0, -1, 0))) != "", "Flut: auf einer Seite ohne Stadt nicht nötig")
	# Werkzeug-Züge: kein Fehlversuch, keine Drehung
	check(gf.twists == 0 and gf.misses == 0, "Werkzeuge zählen nicht als Drehung oder Fehlversuch")
	# Regen alle 5 Drehungen, höchstens 3
	var gr := empty_state()
	gr.no_fire = true
	gr.rain = 0
	var got_at: Array = []
	for t in 20:
		var before := gr.rain
		twist(gr, 1, -1, 1)
		if gr.rain > before:
			got_at.append(gr.twists)
	check(got_at == [5, 10, 15] and gr.rain == Balance.RAIN_MAX, "Regen alle 5 Drehungen, höchstens 3 (%s)" % str(got_at))
	# Blitz: die Eck-Diagonale wächst (mit Wahl)
	var gb := empty_state(2)
	gb.bolts = 1
	var corner := top(gb, 1, 1)
	var diag := gb.corner_diagonal(corner)
	for i in diag:
		(gb.fields[int(i)] as FieldData).kind = MEADOW
	var rb := gb.play({"type": "bolt", "field": corner.id}, {MEADOW: 1})
	var all_field := true
	for i in diag:
		if (gb.fields[int(i)] as FieldData).kind != FIELD:
			all_field = false
	check(all_field and gb.bolts == 0 and _has_event(rb, "choice"), "Blitz: die Diagonale wächst, die Karte gilt für alle (Acker)")
	# Monsun: ganze Seite, fertige bleiben
	var gm := empty_state()
	gm.monsoons = 1
	var face_kinds := [[-1, -1, E], [0, -1, FOREST], [1, -1, FIELD], [-1, 0, HOUSE], [0, 0, CHURCH], [1, 0, ANIMALS],
		[-1, 1, BIGCITY], [0, 1, HUT], [1, 1, PARADISE]]
	for fk in face_kinds:
		top(gm, int(fk[0]), int(fk[1])).kind = int(fk[2])
	gm.play({"type": "monsoon", "field": top(gm, 1, 1).id})
	check(top(gm, 0, 0).kind == CHURCH and top(gm, 1, 1).kind == PARADISE and top(gm, 0, -1).kind == BIGFOREST and top(gm, -1, -1).kind == MEADOW
		and top(gm, 1, 0).kind == PARADISE and top(gm, -1, 1).kind == METROPOLIS and int(gm.stats["monsoons"]) == 1, "Monsun: alle 9 wachsen, fertige bleiben")
	# Monsun kommt mit dem ersten Haus
	var gh := empty_state()
	for x in [-1, 0, 1]:
		top(gh, x, 0).kind = HUT
	gh.moved = {top(gh, 1, 0).id: true}
	var rh := gh.end_round()
	check(gh.monsoon_unlocked and gh.monsoons == 1 and int(rh["bonus_gained"]["monsoon"]) == 1, "Monsun ab dem ersten Haus")


# =============================================================================
# Ziel, Vorschau, Rückgängig, Zeitalter, Tipp
# =============================================================================

func test_win() -> void:
	var gs := empty_state()
	var n := 0
	for f in gs.fields:
		if n >= 22:
			break
		(f as FieldData).kind = PARADISE if n % 2 == 0 else METROPOLIS
		n += 1
	gs.faith = 100
	check(gs.finished_count() == 22 and gs.complete_goal() == 22 and absi(gs.balance()) < 50, "Aufbau: 22 fertige Felder, W %d" % gs.balance())
	var r := gs.end_round()
	check(gs.completed and gs.is_over() and _has_event(r, "complete"), "Vollendet: 22 fertige Felder und die Waage im Grünen")
	check(gs.faith == 100 + 100 * Balance.COMPLETE_BONUS_PCT_PER_HEART * Balance.LIVES / 100 and int(_event(r, "complete")["bonus"]) == 30, "Bonus +10 %% Glauben pro Herz (%d)" % gs.faith)
	var gp := empty_state()
	var k := 0
	for f in gp.fields:
		if k >= 30:
			break
		(f as FieldData).kind = PARADISE
		k += 1
	gp.end_round()
	check(not gp.completed and gp.balance() == -100, "nur Paradies (W = −100): nicht vollendet")
	var ge := empty_state(0)
	for f in ge.fields.slice(0, 30):
		(f as FieldData).kind = PARADISE if (f as FieldData).id % 2 == 0 else METROPOLIS
	ge.end_round()
	check(not ge.completed and ge.complete_goal() == 36, "Einfach braucht 36 fertige Felder")
	var gc := GameState.new()
	gc.setup(5, false, 1)
	for f in gc.fields.slice(0, 30):
		(f as FieldData).kind = PARADISE if (f as FieldData).id % 2 == 0 else METROPOLIS
	gc.end_round()
	check(not gc.completed, "Challenge: kein Vollenden")


## Vorschau = echter Zug (gleiche Antwort): Arten, Glaube, Wünsche und Zufall.
func test_preview_matches() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var bad := 0
	var n := 0
	for s in 30:
		var gs := new_state(500 + s, s % 3)
		for f in gs.fields:
			if rng.randf() < 0.6:
				(f as FieldData).kind = rng.randi_range(0, 13)
		gs.twists = 3 + s % 2       # nächste Drehung macht evtl. einen Wunsch
		gs.faith = rng.randi_range(0, 300)
		for t in 6:
			var m: Array = GameState.MOVES[rng.randi_range(0, 26)]
			var act := {"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])}
			var sim := gs.clone()
			sim.apply_rotation(int(m[0]), int(m[1]), int(m[2]))
			sim.end_round()
			var real := gs.clone()
			real.play(act, {} if sim.card < 0 else {sim.card: sim.habit(sim.card)})
			n += 1
			if sig(sim) != sig(real):
				bad += 1
			gs.play(act)
	check(bad == 0 and n == 180, "Vorschau = echter Zug in %d Fällen (%d abweichend)" % [n, bad])


## Rückgängig: der Stand vor dem Zug (Arten, Glaube, Wünsche, Gewohnheit, Regen, Herzen) kommt genau zurück.
func test_undo() -> void:
	var gs := empty_state()
	gs.faith = 120
	gs.twists = 3
	top(gs, -1, 1).kind = VILLAGE
	top(gs, 0, 1).kind = VILLAGE
	gs.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1)).kind = VILLAGE
	top(gs, -1, -1).kind = CHURCH
	gs.field_at(Vector3i(1, 0, -1), Vector3i(0, 0, -1)).kind = CHURCH    # kommt neben … und eine Kirche gegenüber
	top(gs, 0, 0).kind = CHURCH
	top(gs, 0, -1).kind = HUT
	gs.field_at(Vector3i(0, -1, 0), Vector3i(0, -1, 0)).kind = FOREST
	gs.wishes = [{"id": 1, "type": "tiere", "field": top(gs, 0, -1).id, "left": 3}]
	var undo := gs.clone()
	var before := sig(gs)
	var r := twist(gs, 0, 1, 1, {VILLAGE: 1})
	check(_has_event(r, "choice") and _has_event(r, "war") and _has_event(r, "wish"), "Zug mit Karte, Krieg und Wunsch (%s)" % str(r["events"].map(func(e): return e["type"])))
	check(sig(gs) != before and sig(undo) == before, "Rückgängig: der gemerkte Stand ist unverändert")
	var again := undo.clone()
	var r2 := twist(again, 0, 1, 1, {VILLAGE: 1})
	check(sig(again) == sig(gs) and str(r2["events"]) == str(r["events"]), "nach Rückgängig: derselbe Zug gibt genau dasselbe")


func test_ages() -> void:
	var gs := empty_state()
	check(gs.age() == 1 and gs.age_name() == "Urzeit", "Start in der Urzeit")
	check(gs.next_age_goal() == "Als Nächstes: Steinzeit – leg einen Acker an oder bau eine Hütte.", "Ziel-Text Urzeit")
	var names: Array = []
	for k in [FOREST, ANIMALS, PARADISE, FIELD, HOUSE, VILLAGE, CHURCH, INDUSTRY, METROPOLIS]:
		gs.ever[k] = true
		names.append(gs.age_name())
	check(names == ["Urzeit", "Urzeit", "Urzeit", "Steinzeit", "Antike", "Mittelalter", "Neuzeit", "Industriezeitalter", "Moderne"], "Zeitalter folgen der Zivilisation, Natur zählt nicht (%s)" % str(names))
	check(gs.next_age_goal() == "Als Nächstes: Vollende deine Welt!", "Ziel-Text Moderne")
	var ga := empty_state()
	for x in [-1, 0, 1]:
		top(ga, x, 0).kind = FIELD
	ga.moved = {top(ga, 1, 0).id: true}
	var r := ga.end_round()
	check(bool(r["new_age"]) and ga.age_name() == "Steinzeit", "erste Hütte: Steinzeit")


func test_hint() -> void:
	var gs := empty_state()
	check(gs.best_move().is_empty(), "nur Erde: kein Tipp")
	# Eine Wiesen-Reihe, bei der nur Acker eine zweite Reihe macht (zwei Äcker warten daneben)
	top(gs, -1, 1).kind = MEADOW
	top(gs, 0, 1).kind = MEADOW
	gs.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1)).kind = MEADOW
	gs.field_at(Vector3i(1, 0, -1), Vector3i(0, 0, -1)).kind = FIELD      # kommt nach oben auf (1, 0)
	gs.field_at(Vector3i(1, -1, -1), Vector3i(0, 0, -1)).kind = FIELD     # kommt nach oben auf (1, -1)
	var b := gs.best_move()
	check(not b.is_empty() and int(b["steps"]) == 1 and int(b["axis"]) == 0 and int(b["layer"]) == 1 and int(b["turns"]) == 1, "Tipp findet die Drehung (%s)" % str(b))
	check(int(b.get("card", -1)) == MEADOW and int(b.get("choice", -1)) == 1, "Tipp empfiehlt Acker, weil nur Acker eine zweite Reihe macht (%s)" % str(b))
	var g2 := empty_state()
	top(g2, -1, 1).kind = MEADOW
	top(g2, 0, 1).kind = MEADOW
	g2.field_at(Vector3i(1, -1, -1), Vector3i(0, 0, -1)).kind = MEADOW
	var b2 := g2.best_move()
	var direct := 0
	for m in GameState.MOVES:
		var sim := g2.clone()
		sim.moved = {}
		sim.apply_rotation(int(m[0]), int(m[1]), int(m[2]))
		direct += sim.merge_value()
	check(not b2.is_empty() and (int(b2["steps"]) == 1) == (direct > 0), "Tipp schaut zwei Züge voraus, wenn sofort nichts geht (%s)" % str(b2))
	# Tipp vermeidet Krieg: Zwei Drehungen wachsen gleich, eine davon bringt Kirchen zusammen
	var gw := empty_state()
	gw.faith = 500
	top(gw, -1, 1).kind = HUT
	top(gw, 0, 1).kind = HUT
	gw.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1)).kind = HUT
	gw.field_at(Vector3i(1, 0, -1), Vector3i(0, 0, -1)).kind = CHURCH
	top(gw, 0, 0).kind = CHURCH
	# Alternative: zwei Wälder auf +z, der dritte kommt mit y = −1 von −x dazu
	gw.field_at(Vector3i(1, 0, 1), Vector3i(0, 0, 1)).kind = FOREST
	gw.field_at(Vector3i(1, 1, 1), Vector3i(0, 0, 1)).kind = FOREST
	gw.field_at(Vector3i(-1, -1, 1), Vector3i(-1, 0, 0)).kind = FOREST
	var e := gw.evaluate({"type": "twist", "axis": 0, "layer": 1, "turns": 1})
	check(_has_event(e["result"], "war"), "Aufbau: diese Drehung bringt Krieg")
	var bw := gw.best_move()
	check(bw.is_empty() or not (int(bw["axis"]) == 0 and int(bw["layer"]) == 1 and int(bw["turns"]) == 1), "Tipp meidet den Krieg (%s)" % str(bw))


func test_hint_ignores_seen() -> void:
	var gs := empty_state()
	top(gs, -1, 1).kind = FOREST
	top(gs, 0, 1).kind = FOREST
	top(gs, 1, 1).kind = FOREST
	gs.end_round()
	check(gs.best_move().is_empty(), "Tipp ignoriert Reihen, die es schon gab (%s)" % str(gs.best_move()))


func test_start_no_ready_lines() -> void:
	var bad := 0
	for sd in range(1, 61):
		for lv in [0, 1, 2]:
			var g := GameState.new()
			g.setup(sd, true, lv)
			if not g.lines().is_empty():
				bad += 1
	check(bad == 0, "Start: keine fertige Reihe in 180 Würfen (%d mit Reihe)" % bad)


## Tutorial: der vorgeführte Zug bringt die erste Karte, der eigene Zug die zweite, dann erblüht die Erde.
func test_tutorial_flow() -> void:
	var gs := GameState.new()
	gs.setup(4242, true, 0)
	gs.setup_tutorial_board()
	gs.no_fire = true
	gs.calm = true
	check(gs.lines().is_empty(), "Tutorial-Würfel: keine fertige Reihe")
	var act := {"type": "twist", "axis": 0, "layer": 1, "turns": 1}
	var info := gs.choice_for(act)
	check(int(info.get("kind", -1)) == MEADOW and int(info.get("default", -1)) == 0, "Tutorial: der vorgeführte Zug bringt die Wiesen-Karte (%s)" % str(info))
	var r1 := gs.play(act, {MEADOW: 1})
	check(int(r1["gain"]) > 0 and gs.count(FIELD) >= 1 and gs.habit(MEADOW) == 1, "Tutorial: die Antwort gilt (Acker) und wird Gewohnheit")
	var miss := gs.clone()
	for i in Balance.FIRE_AFTER:
		twist(miss, 1, -1, 1)
	check(miss.misses == 0 and miss.disasters == 0 and miss.faith == gs.faith, "Tutorial: Fehlversuche zählen nicht, kein Glaube pro Drehung")
	var info2 := gs.choice_for(act)
	check(int(info2.get("kind", -1)) == MEADOW and int(info2.get("default", -1)) == 1, "Tutorial: der eigene Zug bringt wieder eine Karte (Standard: letzte Wahl)")
	var r2 := gs.play(act, {MEADOW: 0})
	check(int(r2["gain"]) > 0, "Tutorial: dieselbe Drehung noch einmal wächst wieder")
	var faith_before := gs.faith
	var grown := 0
	for f in gs.fields:
		if (f as FieldData).kind >= FOREST:
			grown += 1
	var erde_before := gs.count(E)
	gs.no_fire = false
	var bloomed := gs.fill_after_tutorial()
	check(not bloomed.is_empty() and gs.count(E) < erde_before, "nach dem Tutorial: die Erde erblüht (%d neue Wiesen)" % bloomed.size())
	check(gs.faith == faith_before and not gs.calm, "nach dem Tutorial: der Glaube bleibt, Glaube pro Drehung an")
	var kept := 0
	for f in gs.fields:
		if (f as FieldData).kind >= FOREST:
			kept += 1
	check(kept == grown, "nach dem Tutorial: was gewachsen ist, bleibt")
	var fresh := true
	for ln in gs.lines():
		for g in ln:
			if bloomed.has((g as FieldData).id):
				fresh = false
	check(fresh, "nach dem Tutorial: keine fertige neue Reihe")
	var bm2 := gs.best_move()
	check(not bm2.is_empty() and int(bm2["steps"]) == 1, "nach dem Tutorial: eine Drehung wächst sofort (%s)" % str(bm2))


func test_rain_rules() -> void:
	var gs := GameState.new()
	gs.setup(4242, true, 0)
	gs.rain = 2
	var tg := gs.rain_targets()
	check(not tg.is_empty(), "Regen: es gibt leuchtende Ziele")
	var ok := true
	for fid in tg:
		if gs.can_bonus("rain", gs.fields[int(fid)]) != "":
			ok = false
	check(ok, "Regen: jedes leuchtende Feld kann gegossen werden")
	var other := -1
	for f in gs.fields:
		if not tg.has(f.id):
			other = f.id
			break
	check(other < 0 or gs.can_bonus("rain", gs.fields[other]) != "", "Regen: nicht leuchtende Felder gehen nicht")
	var gl := empty_state(0)
	gl.rain = 1
	top(gl, -1, 0).kind = FOREST
	top(gl, 0, 0).kind = FOREST
	top(gl, 1, 0).kind = MEADOW
	check(str(gl.rain_spots().get(top(gl, 1, 0).id, "")) == "up", "Regen: das Feld, das die Reihe fertig macht, ist lohnend")
	var rr := gl.play({"type": "rain", "field": top(gl, 1, 0).id})
	check(int(rr["gain"]) > 0 and top(gl, 0, 0).kind == BIGFOREST, "Regen macht die Reihe fertig: sie wächst")
	var gz := GameState.new()
	gz.setup(99, true, 1)
	gz.rain = 3
	var spots := gz.rain_spots()
	var lies := 0
	for fid in spots:
		if str(spots[fid]) != "up":
			continue
		if int(gz.simulate({"type": "rain", "field": int(fid)})["result"]["gain"]) <= 0:
			lies += 1
	check(lies == 0, "Regen: jedes lohnende Feld lässt wirklich etwas wachsen (%d falsch)" % lies)


# =============================================================================
# Feuer, Herzen, Modi
# =============================================================================

func test_fire() -> void:
	var gs := empty_state()
	var k := 0
	for f in gs.face_fields(UP):
		k += 1
		(f as FieldData).kind = k     # 9 verschiedene Arten, nichts wächst
	var row := ids([top(gs, -1, -1), top(gs, -1, 0), top(gs, -1, 1)])
	for i in Balance.FIRE_AFTER - 1:
		var r := twist(gs, 1, -1, 1)
		check(_disaster_of(r).is_empty(), "Fehlversuch %d: noch kein Brand" % (i + 1))
	check(gs.misses == Balance.FIRE_AFTER - 1, "Fehlversuche werden gezählt (%d)" % gs.misses)
	var before := top(gs, -1, 0).kind
	var rf := gs.play({"type": "twist", "axis": 1, "layer": -1, "turns": 1, "row": row})
	var e := _disaster_of(rf)
	check(str(e.get("kind", "")) == "fire" and (e["hit"] as Array).size() == 3, "%d. Fehlversuch: die gewischte Reihe brennt" % Balance.FIRE_AFTER)
	check(top(gs, -1, 0).burning and gs.misses == 0, "Felder brennen, Zähler beginnt von vorn")
	check(gs.lives == Balance.LIVES - 1 and not gs.died(), "Brand kostet ein Herz (noch %d)" % gs.lives)
	gs.rain = 1
	var saved_f := top(gs, -1, 1)
	var saved_k := saved_f.kind
	gs.play({"type": "rain", "field": saved_f.id})
	check(not saved_f.burning and top(gs, -1, 0).burning, "Regen löscht genau ein Feld")
	gs.end_round()
	check(top(gs, -1, 0).kind == FieldData.down(before) and not top(gs, -1, 0).burning, "Brand: eine Stufe zurück (%s → %s)" % [FieldData.kind_name(before), FieldData.kind_name(top(gs, -1, 0).kind)])
	check(saved_f.kind == saved_k, "gelöschtes Feld verliert nichts")
	# Ein Erfolg setzt den Zähler nicht zurück
	var gm := empty_state()
	gm.misses = 1
	top(gm, -1, 1).kind = FOREST
	top(gm, 0, 1).kind = FOREST
	gm.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1)).kind = FOREST
	var rm := twist(gm, 0, 1, 1)
	check(int(rm["gain"]) > 0 and gm.misses == 1, "Erfolg setzt Fehlversuche nicht zurück")
	# Glaube pro Drehung, Wünsche und Krieg zählen nicht als Wachsen
	var gi := empty_state()
	top(gi, 0, 0).kind = CHURCH
	top(gi, 1, 1).kind = BIGFOREST
	var ri := twist(gi, 1, -1, 1)
	check(int(ri["income"]) > 0 and gi.misses == 1, "Glaube pro Drehung ist kein Wachsen: Fehlversuch")


func test_modes() -> void:
	for lv in [0, 1, 2]:
		var g := GameState.new()
		g.setup(5, true, lv)
		var hearts := Balance.LIVES_EASY if lv == 0 else Balance.LIVES
		check(g.gadgets and g.rain == Balance.RAIN_START and g.lives == hearts and g.max_lives == hearts, "Stufe %d: %d Herzen" % [lv, hearts])
	check(Balance.LIVES_EASY == 5 and Balance.LIVES == 3, "Einfach 5 Herzen, sonst 3")
	var easy := GameState.new()
	easy.setup(5, true, 0)
	check(easy.easy and easy.diagonals and easy.diag_from == 1, "Einfach: Gruppen, Diagonalen ab Stufe 1")
	var mid := GameState.new()
	mid.setup(5, true, 1)
	check(not mid.easy and mid.diagonals and mid.diag_from == 2, "Mittel: Diagonalen ab Stufe 2")
	var hard := GameState.new()
	hard.setup(5, true, 2)
	check(not hard.diagonals and not hard.easy, "Schwer: nur gerade Reihen")
	var ch := GameState.new()
	ch.setup(5, false)
	check(ch.hearts and ch.lives == Balance.LIVES and ch.diagonals and not ch.easy and ch.complete_goal() == 0, "40 Drehungen: Mittel-Regeln, kein Vollenden")
	ch.no_fire = true
	for i in Balance.MAX_TWISTS:
		twist(ch, 1, -1, 1)
	check(ch.finished() and ch.is_over() and ch.twists == Balance.MAX_TWISTS, "nach 40 Drehungen ist Schluss")
	for endless_mode in [true, false]:
		var sv := GameState.new()
		sv.setup(5, endless_mode, 1)
		for i in Balance.LIVES:
			check(not sv.is_over(), "lebt noch vor Brand %d" % (i + 1))
			sv.last_row = [0, 1, 2]
			sv.disaster("fire", [])
		check(sv.died() and sv.is_over(), "nach dem %d. Brand ist die Welt tot" % Balance.LIVES)
	var gx := empty_state()
	gx.rain = 0
	gx.bolts = 0
	top(gx, 0, 0).kind = MEADOW
	top(gx, 1, 1).kind = MEADOW
	check(gx.stuck() and not gx.is_over(), "nichts mehr zu verbinden: die Welt stirbt trotzdem nicht")
	gx.rain = 1
	check(not gx.stuck(), "mit Regen geht es weiter")


## Ablauf im Autoload Game: Wahl anfragen, beantworten, Rückgängig.
func test_game_flow() -> void:
	var g: Node = GameScript.new()
	g.tutorial_done = true
	g.state = empty_state()
	var gs: GameState = g.state
	top(gs, -1, 1).kind = MEADOW
	top(gs, 0, 1).kind = MEADOW
	gs.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1)).kind = MEADOW
	var asked: Array = []
	var resolved: Array = []
	g.choice_needed.connect(func(info): asked.append(info))
	g.round_resolved.connect(func(result, before): resolved.append(result))
	g.play_turn(0, 1, 1)
	check(asked.size() == 1 and resolved.is_empty() and g.busy and g.has_choice(), "Game: erst die Wahl anfragen, dann auswerten")
	if asked.size() == 1:
		var info: Dictionary = asked[0]
		check(int(info["kind"]) == MEADOW and (info["options"] as Array) == [FOREST, FIELD] and int(info["default"]) == 0 and not bool(info["mini"]) and float(info["timeout"]) == Balance.CHOICE_TIMEOUT, "Game: Karte mit Optionen, Standard und Zeitlimit (%s)" % str(info))
	g.choose(1)
	check(resolved.size() == 1 and not g.has_choice(), "Game: Antwort wertet den Zug aus")
	var third: FieldData = g.state.field_at(Vector3i(1, 1, 1), UP)
	check(third.kind == FIELD and g.state.habit(MEADOW) == 1 and int(g.cards_seen.get(MEADOW, 0)) == 1, "Game: Acker gewählt, Gewohnheit und Karten-Zähler")
	g.busy = false
	check(g.can_undo(), "Game: Rückgängig möglich")
	g.undo()
	check((g.state as GameState).field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1)).kind == MEADOW and (g.state as GameState).habit(MEADOW) == 0, "Game: Rückgängig holt auch die Gewohnheit zurück")
	# Nach 3 großen Karten kommt die kleine Pille
	g.cards_seen[MEADOW] = Balance.CHOICE_FULL_CARDS
	g.play_turn(0, 1, 1)
	check(asked.size() == 2 and bool(asked[1]["mini"]) and float(asked[1]["timeout"]) == Balance.MINI_CARD_SECONDS, "Game: nach 3 Karten die kleine Pille (2 s)")
	g.choose_default()
	check(resolved.size() == 2 and (g.state as GameState).field_at(Vector3i(1, 1, 1), UP).kind == FOREST, "Game: Zeit abgelaufen → Gewohnheit (Wald)")
	# Vorschau zeigt die kommende Karte
	g.busy = false
	g.undo()
	var pv: Dictionary = g.preview(0, 1, 1)
	check(int(pv["card"]) == MEADOW and int(pv["card_field"]) >= 0, "Game: Vorschau kennt die kommende Karte")
	g.free()


# =============================================================================
# Bot
# =============================================================================

func test_bot() -> void:
	var t0 := Time.get_ticks_msec()
	var tw: Array = []
	var stats_ok := true
	for sd in [11, 22, 33]:
		var b := Bot.play(sd, 1, "eval")
		var st: Dictionary = b["stats"]
		var reached: Array = []
		for k in [FIELD, ANIMALS, HUT, VILLAGE, TOWN, CHURCH, BIGCITY, INDUSTRY, METROPOLIS, PARADISE]:
			if (b["ever"] as Dictionary).has(k):
				reached.append(FieldData.KIND_SHORT[k])
		tw.append(int(b["twists"]))
		print("  Bot Mittel Seed %d: %d Drehungen, %d Glaube (%d verdient), %s, %s, Kriege %d, Smog %d, Wünsche %d/%d erfüllt, Feuer %d, Gewitter %d, Flut %d, fertig %d, erreicht: %s" % [
			sd, int(b["twists"]), int(b["faith"]), int(b["earned"]), "vollendet" if bool(b["completed"]) else ("tot" if bool(b["dead"]) else "offen"),
			str(b["age"]), int(st["wars"]), int(st["smog"]), int(st["wish_ok"]), int(st["wish_ok"]) + int(st["wish_fail"]), int(st["fires"]),
			int(st["strikes"]), int(st["floods"]), int(b["finished"]), ", ".join(reached)])
		if int(b["faith"]) < 0 or int(b["twists"]) < 10 or int(st["wars"]) > 15:
			stats_ok = false
	print("  (Bot: %d ms)" % (Time.get_ticks_msec() - t0))
	check(stats_ok, "Bot: Glaube ≥ 0, mindestens 10 Drehungen, nicht ständig Krieg")
	tw.sort()
	check(int(tw[1]) >= 25 and int(tw[1]) <= 300, "Bot Mittel: Median-Drehungen in einem lockeren Rahmen (%s)" % str(tw))
	# Passiv (immer dieselbe Drehung, nie eine Wahl, keine Werkzeuge): kein Glaube
	var gp := new_state(11)
	for f in gp.fields:
		(f as FieldData).kind = E
	for i in 40:
		twist(gp, 1, -1, 1)
		if gp.is_over():
			break
	check(gp.faith == 0, "Nichtstun bringt keinen Glauben")
