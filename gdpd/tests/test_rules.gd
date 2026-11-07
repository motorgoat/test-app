extends SceneTree
## Regeltests für gdpd ohne Grafik (docs/GDPD_REGELN.md Abschnitt 12, docs/GDPD_7_TAGE.md Abschnitt 9):
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
const WATER := FieldData.WATER
const STONE := FieldData.STONE
const UP := Vector3i(0, 1, 0)

var failures := 0
var checks := 0
var _saved := {}


func _init() -> void:
	if OS.get_cmdline_user_args().has("--daily"):       # schneller Lauf: nur „Täglich spielen“
		_daily_tests()
		test_day_save()
		print("")
		print("%d Prüfungen, %d Fehler" % [checks, failures])
		quit(1 if failures > 0 else 0)
		return
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
	test_erde_rows()
	test_rests_today()
	test_still_rows()
	test_once()
	test_day_choices()
	test_made_counting()
	test_rain_rules()
	restore()
	test_fire()
	test_modes()
	test_game_flow()
	# Die Schöpfung in 7 Tagen
	test_day_table()
	test_day_boards()
	test_day_replay()
	test_xcheck8()
	test_consume()
	test_needs()
	test_thrive_timing()
	test_bolt()
	test_war8()
	test_flood_smog()
	test_preview8()
	test_extras()
	test_overnight()
	test_farm_pools()
	test_free_farm()
	test_day_goals()
	test_day_stars_mercy()
	test_day_no_hearts()
	test_day_lcg()
	test_day_toggles()
	test_day_tutorial()
	test_day_save()
	_daily_tests()
	test_day_hint()
	test_day_bots()
	test_bot()
	test_still_fuzz()
	await process_frame          # das Autoload Game ist jetzt im Baum
	test_self_move_guard()
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


## Alles Wasser, damit nichts von selbst passiert (Erde bildet jetzt Reihen: drei Erden werden eine Wiese).
func empty_state(lvl := 1) -> GameState:
	var gs := new_state(12345, lvl)
	for f in gs.fields:
		f.kind = WATER
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
	return "%s|f%d e%d|r%d b%d m%d|l%d t%d mi%d|w%s|h%s|rng%d|c%s|lcg%d|made%s|d%s%s%d" % [str(ks), gs.faith, gs.faith_earned, gs.rain, gs.bolts,
		gs.monsoons, gs.lives, gs.twists, gs.misses, str(gs.wishes), str(gs.will), gs.rng.state, str(gs.completed), gs.lcg,
		str(gs.made), str(gs.day_won), gs.day_lost, gs.day_won_at]


# =============================================================================
# Aufbau und Geometrie (wie im Würfelspiel)
# =============================================================================

func test_setup() -> void:
	var gs := new_state()
	check(gs.fields.size() == 54, "54 Felder")
	check(gs.lines().is_empty(), "am Start keine fertigen Dreierreihen")
	check(gs.faith == 0 and gs.score == 0, "Start mit 0 Glauben (score ist der alte Name)")
	for sd in [1, 2, 3, 4, 5, 6, 7, 8]:
		var g := new_state(sd)
		var cnt := {}
		var corner := {}
		for f in g.fields:
			cnt[f.kind] = int(cnt.get(f.kind, 0)) + 1
			if FieldData.sticker_type(f.p) == 3:
				corner[f.kind] = int(corner.get(f.kind, 0)) + 1
		var want: Dictionary = Balance.START_KINDS
		var same := cnt.size() == want.size()
		for k in want:
			if int(cnt.get(k, 0)) != int(want[k]):
				same = false
		check(same, "Seed %d: Start Wiese 26, Erde 24, Wasser 4 (%s)" % [sd, str(cnt)])
		check(int(corner.get(MEADOW, 0)) >= 10 and int(corner.get(E, 0)) >= 9, "Seed %d: etwa die Hälfte jeder Art auf Ecken (%s)" % [sd, str(corner)])
		check(g.lines().is_empty(), "Seed %d: keine fertige Reihe" % sd)


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
	check(FieldData.KIND_COUNT == 17 and WATER == 15 and STONE == 16, "17 Arten, Wasser ist 15, Stein 16")
	check(FieldData.NEXT == [MEADOW, FOREST, BIGFOREST, HUT, ANIMALS, HUT, HOUSE, VILLAGE, TOWN, BIGCITY, -1, METROPOLIS, -1, -1, -1, -1, -1], "NEXT wie in der Spec")
	check(FieldData.DOWN == [E, E, MEADOW, MEADOW, FOREST, BIGFOREST, ANIMALS, HUT, HOUSE, VILLAGE, VILLAGE, TOWN, TOWN, BIGCITY, ANIMALS, WATER, STONE], "DOWN wie in der Spec")
	check(FieldData.TIER == [0, 1, 2, 2, 3, 4, 5, 6, 7, 8, 8, 9, 9, 10, 5, 0, 0] and Balance.GROW_FAITH.size() == 11, "TIER wie in der Spec, GROW_FAITH mit 11 Einträgen")
	check(not FieldData.can_row(STONE) and not FieldData.nature(STONE) and not FieldData.people(STONE) and FieldData.kind_name(STONE) == "Stein"
		and Days.CODE[STONE] == "R", "Stein: Hintergrund wie Wasser, keine Reihe, Brett-Zeichen R")
	var choice_kinds: Array = FieldData.CHOICE.keys()
	choice_kinds.sort()
	check(choice_kinds == [MEADOW, ANIMALS, VILLAGE, TOWN], "Wahl bei Wiese, Tiere, Dorf, Stadt (%s)" % str(choice_kinds))
	check(FieldData.options(MEADOW) == [FOREST, FIELD] and FieldData.options(ANIMALS) == [HUT, PARADISE]
		and FieldData.options(VILLAGE) == [TOWN, CHURCH] and FieldData.options(TOWN) == [BIGCITY, INDUSTRY], "Optionen in Tabellen-Reihenfolge")
	var ok_down := true
	for k in FieldData.KIND_COUNT:
		var d := FieldData.down(k)
		if d < 0 or d >= FieldData.KIND_COUNT or (FieldData.tier(k) > 0 and FieldData.tier(d) >= FieldData.tier(k)):
			ok_down = false
	check(ok_down, "„fällt auf“ bleibt im Bereich und geht eine Stufe nach unten")
	var fin: Array = []
	for k in FieldData.KIND_COUNT:
		if FieldData.finished(k):
			fin.append(k)
			check(not FieldData.can_row(k) and FieldData.next_kind(k) == k, "%s ist fertig: keine Reihe, wächst nicht" % FieldData.kind_name(k))
	check(fin == [CHURCH, INDUSTRY, METROPOLIS, PARADISE], "fertige Arten (%s)" % str(fin))
	check(FieldData.can_row(E) and not FieldData.can_row(WATER) and FieldData.next_kind(WATER) == WATER, "Erde bildet Reihen, Wasser nie")
	check(FieldData.next_kind(E) == MEADOW and FieldData.next_kind(BIGFOREST) == ANIMALS and FieldData.next_kind(ANIMALS) == HUT
		and FieldData.next_kind(FIELD) == HUT and FieldData.next_kind(HUT) == HOUSE and FieldData.next_kind(BIGCITY) == METROPOLIS,
		"Leiter: Erde → Wiese, Großer Wald → Tiere → Hütte, Acker → Hütte …")
	check(FieldData.down(CHURCH) == VILLAGE and FieldData.down(INDUSTRY) == TOWN and FieldData.down(PARADISE) == ANIMALS
		and FieldData.down(HUT) == ANIMALS and Balance.WAR_DROP == HOUSE, "Fallen: Kirche → Dorf, Industrie → Stadt, Hütte → Tiere")
	var fam_ok := true
	for k in FieldData.KIND_COUNT:
		if FieldData.nature(k) and FieldData.people(k):
			fam_ok = false
	check(fam_ok and FieldData.people(CHURCH) and not FieldData.people(INDUSTRY) and FieldData.civ(FIELD)
		and not FieldData.civ(WATER) and not FieldData.nature(WATER) and not FieldData.civ(E), "Natur / Menschen / Zivilisation sauber getrennt, Wasser und Erde weder noch")
	var nk := FieldData.KIND_COUNT
	check(FieldData.KIND_ICON.size() == nk and FieldData.KIND_NAME.size() == nk and FieldData.KIND_HELP.size() == nk
		and FieldData.KIND_PLURAL.size() == nk and FieldData.AGE_OF.size() == nk and FieldData.FAMILY.size() == nk
		and FieldData.KIND_SHORT.size() == nk and FieldData.KIND_ARTICLE.size() == nk and FieldData.KIND_KEY.size() == nk,
		"Namen, Icons und Erklärungen für alle %d Arten" % nk)
	var inf := FieldData.info(CHURCH)
	check(int(inf["income"]) == 3 and bool(inf["finished"]) and str(inf["icon"]) == "church", "Art-Info für die Oberfläche (%s)" % str(inf))
	# Wasser: nie eine Reihe, brennt nicht, ändert sich nicht durch Regen, Gewitter oder Flut
	var gw := empty_state()
	var w0 := top(gw, 0, 0)
	gw.rain = 1
	gw.faith = 200
	check(gw.lines().is_empty() and gw.can_bonus("rain", w0) != "" and gw.can_bonus("strike", w0) != "", "Wasser: keine Reihe, kein Regen, kein Gewitter")
	gw.play({"type": "strike", "field": w0.id})
	gw.play({"type": "flood", "field": w0.id})
	gw.play({"type": "rain", "field": w0.id})
	gw.last_row = [w0.id, top(gw, 1, 0).id, top(gw, -1, 0).id]
	gw.disaster("fire", [])
	check(w0.kind == WATER and not w0.burning and gw.count(WATER) == 54, "Wasser bleibt Wasser (Gewitter, Flut, Regen, Feuer)")
	# Paradies nur über die Tiere-Karte (freies Spiel)
	var gp := empty_state()
	for x in [-1, 0, 1]:
		top(gp, x, 0).kind = ANIMALS
	gp.moved = {top(gp, 1, 0).id: true}
	gp.end_round({ANIMALS: 1})
	check(top(gp, 1, 0).kind == PARADISE and gp.card == ANIMALS, "freies Spiel: Tiere-Karte, Option 2 = Paradies")
	var gq := empty_state()
	for x in [-1, 0, 1]:
		top(gq, x, 0).kind = ANIMALS
	gq.moved = {top(gq, 1, 0).id: true}
	gq.end_round({})
	check(top(gq, 1, 0).kind == HUT, "Tiere ohne Antwort: Menschen ziehen ein (Hütte)")


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
	check(third.kind == HOUSE and int(rr["gain"]) == int(Balance.GROW_FAITH[FieldData.tier(HUT)]), "hineingedrehtes Feld wächst (Hütte → Haus)")
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
		if gl.is_choice(k):
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
	check(bad == 0 and cards > 250, "Karte ist deterministisch (%d Karten, %d abweichend)" % [cards, bad])


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
	check(gs.card == -1, "Großer Wald → Tiere: keine Karte (auch nicht in der Kette)")


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
	check(int(rt["gain"]) == int(Balance.GROW_FAITH[FieldData.tier(VILLAGE)]) * 4 / 3, "Einfach: Glaube × Gruppengröße / 3 (%d)" % int(rt["gain"]))


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
	empty_spot.kind = E
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
	for xz in [Vector2i(1, -1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		top(gs, xz.x, xz.y).kind = E
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
	top(gf, 1, 0).kind = E
	top(gf, 1, 0).fresh = 2
	var rf := twist(gf, 1, -1, 1)
	check(int(_event(rf, "regrow").get("field", -1)) != top(gf, 1, 0).id and top(gf, 1, 0).kind == E, "nicht auf rauchenden (frisch verwüsteten) Feldern")
	# Nie bei Regen oder Werkzeug-Zügen
	var gt := empty_state()
	top(gt, 0, 0).kind = MEADOW
	top(gt, 1, 1).kind = FOREST
	top(gt, 1, 0).kind = E
	gt.field_at(Vector3i(0, -1, 0), Vector3i(0, -1, 0)).kind = E
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
		(gs.fields[i] as FieldData).kind = INDUSTRY if (gs.fields[i] as FieldData).kind == WATER else (gs.fields[i] as FieldData).kind
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
			check(str(w["type"]) == "wald" or str(w["type"]) == "acker", "Wunsch nur mit erreichbarem Ziel: hier Wald oder Acker (Acker kann entstehen) (%s)" % str(w["type"]))
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
	gz.choices_on = {}                   # keine Wiese-Karte: Acker kann nicht entstehen
	top(gz, 0, 0).kind = HUT
	var any := false
	for t in 4:
		if _has_event(twist(gz, 1, -1, 1), "wish"):
			any = true
	check(not any, "kein Wunsch, wenn kein Ziel erreichbar ist (kein Wald, Tiere, Acker, Regen)")
	var gy := empty_state()
	gy.rain = 0
	gy.no_fire = true
	top(gy, 0, 0).kind = HUT
	for xz in [Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
		top(gy, xz.x, xz.y).kind = BIGFOREST     # Wildnis: Menschen wünschen sich einen Acker
	var hunger := ""
	for t in 4:
		var ry := twist(gy, 1, -1, 1)
		if _has_event(ry, "wish"):
			hunger = str(_event(ry, "wish")["wish"]["type"])
	check(hunger == "acker", "Hunger-Wunsch auch ohne Acker, wenn die Wiese-Karte aktiv ist (%s)" % hunger)
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
	check(gf.misses == 0 and not _has_event(rf, "miss"), "erfüllter Wunsch zählt als Wachsen: kein Fehlversuch")
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
	top(gr, 1, 1).kind = E
	gr.field_at(Vector3i(0, -1, 0), Vector3i(0, -1, 0)).kind = E
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
	check(h5.kind == ANIMALS and gg.wishes.is_empty() and _has_event(rg, "wish_gone"), "Gewitter auf die Hütte (→ Tiere): der Wunsch verschwindet")


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
	e.kind = E
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
	# Die getroffene Industrie raucht noch 2 Drehungen (wächst so lange nicht nach), erst danach wird sie Wiese
	var gsm := empty_state()
	gsm.faith = 100
	var ind2 := top(gsm, 0, 0)
	ind2.kind = INDUSTRY
	for xz in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		top(gsm, xz.x, xz.y).kind = FOREST
	gsm.play({"type": "strike", "field": ind2.id})
	var smoke0 := ind2.fresh
	twist(gsm, 1, -1, 1)
	var after1 := ind2.kind
	twist(gsm, 1, -1, 1)
	var after2 := ind2.kind
	twist(gsm, 1, -1, 1)
	check(smoke0 == 2 and after1 == E and after2 == E and ind2.kind == MEADOW, "Gewitter auf Industrie: 2 Drehungen kein Nachwachsen, dann Wiese (%d %d %d %d)" % [smoke0, after1, after2, ind2.kind])
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
	check(top(gf, -1, -1).kind == MEADOW and top(gf, 0, -1).kind == VILLAGE and top(gf, 1, -1).kind == E and top(gf, -1, 0).kind == TOWN and top(gf, 1, 1).kind == ANIMALS, "Flut: Stadt und Industrie schrumpfen (Hütte → Tiere)")
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
		and top(gm, 1, 0).kind == HUT and top(gm, -1, 1).kind == METROPOLIS and int(gm.stats["monsoons"]) == 1, "Monsun: alle 9 wachsen (Tiere → Hütte), fertige bleiben")
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
	check(gs.finished_count() == 22 and gs.complete_goal() == int(Balance.COMPLETE_AT[1]) and absi(gs.balance()) < 50, "Aufbau: 22 fertige Felder, W %d" % gs.balance())
	var r := gs.end_round()
	check(gs.completed and gs.is_over() and _has_event(r, "complete"), "Vollendet: genug fertige Felder und die Waage im Grünen")
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
	check(not ge.completed and ge.complete_goal() == 36 and Balance.COMPLETE_AT == [36, 18, 16], "Einfach braucht 36 fertige Felder (Mittel 18, Schwer 16)")
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
	check(gs.next_age_goal() == "Als Nächstes: Steinzeit – Acker oder Hütte.", "Ziel-Text Urzeit")
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
	check(gs.best_move().is_empty(), "nur Wasser: kein Tipp")
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
	g.save_path = "user://test_rekord.cfg"
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
# Neuer Baum: Erde-Reihen, „ruht heute“, Wahl je Tag, made (GDPD_7_TAGE.md 9.1, Punkte 2–5)
# =============================================================================

## Ein Tag mit leerem Brett (alles Wasser), um Regeln einzeln zu prüfen.
func day_state(n: int, extra := 0) -> GameState:
	var gs := GameState.new()
	var kinds: Array = []
	for i in 54:
		kinds.append(WATER)
	gs.setup_day(Days.config(n), kinds, 1, extra)
	return gs


## Eine Reihe von drei gleichen Arten oben (z = 1), die die Drehung x = 1 (eine Vierteldrehung) neu bildet.
func ready_row(gs: GameState, k: int) -> FieldData:
	top(gs, -1, 1).kind = k
	top(gs, 0, 1).kind = k
	var third := gs.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1))
	third.kind = k
	return third


func test_erde_rows() -> void:
	for mode in ["frei", "tag1"]:
		var gs := empty_state() if mode == "frei" else day_state(1)
		var third := ready_row(gs, E)
		var r := twist(gs, 0, 1, 1)
		check(third.kind == MEADOW and top(gs, -1, 1).kind == E and top(gs, 0, 1).kind == E, "%s: drei Erden in einer neuen Reihe → das Zielfeld wird Wiese, die anderen bleiben Erde" % mode)
		check(int(gs.made[MEADOW]) == 1 and int(r["grew"]) == 1 and gs.card == -1, "%s: zählt als gewachsene Wiese, keine Karte" % mode)
		var gn := empty_state() if mode == "frei" else day_state(1)
		for x in [-1, 0, 1]:
			top(gn, x, 1).kind = E
		twist(gn, 2, 1, 1)
		check(gn.count(MEADOW) == 0, "%s: eine stehende Erde-Reihe (mitgedreht) wächst nicht" % mode)


func test_rests_today() -> void:
	var gs := day_state(1)
	var third := ready_row(gs, MEADOW)
	check(not gs.can_row(MEADOW) and gs.resting(MEADOW) and gs.can_row(E), "Tag 1: Wiese ruht (Wald erst morgen), Erde nicht")
	check(gs.kind_help(MEADOW).ends_with(FieldData.REST_HELP), "ruhende Art: „Wächst erst später.“ (%s)" % gs.kind_help(MEADOW))
	var r := twist(gs, 0, 1, 1)
	var st := _still_of(r, "rest")
	check(third.kind == MEADOW and int(r["grew"]) == 0 and gs.misses == 0 and _disaster_of(r).is_empty(),
		"Tag 1: eine neue Wiesen-Reihe wächst nicht, kein Fehlversuch, nichts brennt")
	check(not st.is_empty() and int(st["kind"]) == MEADOW and int(st["next"]) == FOREST and (st["fields"] as Array).has(third.id),
		"Tag 1: die ruhende Reihe meldet sich (still/rest, nächste Art Wald, ihre drei Felder) %s" % str(st))
	var g2 := day_state(2)
	var t2 := ready_row(g2, MEADOW)
	twist(g2, 0, 1, 1)
	check(t2.kind == FOREST and g2.card == -1, "Tag 2: die Wiesen-Reihe wird Wald, ohne Karte")
	check(g2.kind_help(MEADOW) == "Wiese. 3 in einer Reihe: Wald.", "Tag 2: Erklärung (%s)" % g2.kind_help(MEADOW))
	var g3 := day_state(3)
	var faces_ok := true
	for f in g3.face_fields(UP):
		(f as FieldData).kind = ANIMALS
	g3.moved = {top(g3, 0, 0).id: true}
	g3.end_round()
	for f in g3.face_fields(UP):
		if (f as FieldData).kind != ANIMALS:
			faces_ok = false
	check(faces_ok, "Tag 3: 9 Tiere wachsen nicht (Tiere-Reihen erst ab Tag 4)")
	var g5 := day_state(5)
	check(g5.kind_help(HUT) == "Hütte. Braucht Nahrung." and g5.kind_help(VILLAGE) == "Dorf. Braucht Nahrung und Arbeit."
		and g5.kind_help(STONE) == "Stein. Gibt Arbeit.", "Tag 5: Erklärungen der Menschen (%s / %s / %s)" % [g5.kind_help(HUT), g5.kind_help(VILLAGE), g5.kind_help(STONE)])


## Das erste still-Ereignis mit diesem Grund ({} = keins).
func _still_of(r: Dictionary, why: String) -> Dictionary:
	for e in r["events"]:
		if str(e["type"]) == "still" and str(e["why"]) == why:
			return e
	return {}


## Stille Reihen (GameState._still_rows): Jede neue Reihe aus drei gleichen Feldern, die nicht wächst, meldet sich mit
## einem Grund. An den neuen Tagen: rest (wächst an einem späteren Tag), people (Menschen wachsen durch Nachbarn),
## done (heute keine Reihe mehr), stone (Stein). Nie ein Fehlversuch, nie Feuer.
func test_still_rows() -> void:
	var want := {1: [MEADOW, "rest"], 2: [FOREST, "rest"], 3: [ANIMALS, "rest"], 4: [HUT, "people"], 5: [MEADOW, "done"],
		6: [FOREST, "done"], 7: [VILLAGE, "people"]}
	for n in range(1, 8):
		var gs := day_state(n)
		var k := int((want[n] as Array)[0])
		var why := str((want[n] as Array)[1])
		var third := ready_row(gs, k)
		var r := twist(gs, 0, 1, 1)
		var st := _still_of(r, why)
		check(int(r["grew"]) == 0 and third.kind == k and gs.misses == 0 and _disaster_of(r).is_empty() and not st.is_empty()
			and int(st["kind"]) == k, "Tag %d: neue Reihe aus %s wächst nicht: still/%s, kein Fehlversuch (%s)" % [n, FieldData.kind_name(k), why, str(st)])
	var gst := day_state(5)
	ready_row(gst, STONE)
	check(not _still_of(twist(gst, 0, 1, 1), "stone").is_empty(), "Tag 5: drei Steine in einer Reihe → still/stone")
	# Tag 1: ein Zug ohne jede Reihe wird gemeldet (kein Feuer: zählt nicht)
	var g1 := day_state(1)
	top(g1, 0, 0).kind = E
	var r1 := twist(g1, 0, 1, 1)
	var m1 := _event(r1, "miss")
	check(int(r1["grew"]) == 0 and not m1.is_empty() and not bool(m1.get("counted", true)) and g1.misses == 0,
		"Tag 1: Zug ohne Wachsen → miss-Ereignis für die Oberfläche (zählt nicht) %s" % str(m1))
	# Schräg zählt an den Tagen nicht: die Reihe meldet sich (still/diag), der Zug sagt warum
	var g2 := day_state(2)
	top(g2, -1, -1).kind = E
	top(g2, 0, 0).kind = E
	var t2 := g2.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1))
	t2.kind = E                          # kommt mit x = 1 nach oben auf (1, 1): die Schräge (-1,-1) (0,0) (1,1)
	var r2 := twist(g2, 0, 1, 1)
	var sd := _still_of(r2, "diag")
	check(int(r2["grew"]) == 0 and not sd.is_empty() and bool(sd["diag"]) and str(_event(r2, "miss").get("why", "")) == "diag"
		and g2.misses == 0, "Tag 2: schräge Erde-Reihe → still/diag, Zug mit Grund „diag“ (%s)" % str(_event(r2, "miss")))
	# Wasser: drei blaue in einer neuen Reihe → still/water; nichts gewachsen → Grund „water“
	var gw := day_state(2)
	top(gw, -1, 1).kind = E
	top(gw, 0, 1).kind = FOREST
	var rw := twist(gw, 0, 1, 1)
	check(not _still_of(rw, "water").is_empty() and str(_event(rw, "miss").get("why", "")) == "water",
		"Wasser-Reihe → still/water, Grund „water“ (%s)" % str(_event(rw, "miss")))
	# Freies Spiel (Mittel): eine schräge Erde-Reihe zählt erst ab Wald → still/diag
	var gm := empty_state(1)
	top(gm, -1, -1).kind = E
	top(gm, 0, 0).kind = E
	gm.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1)).kind = E
	var rm := twist(gm, 0, 1, 1)
	check(not _still_of(rm, "diag").is_empty() and int(rm["grew"]) == 0, "Mittel: schräge Erde-Reihe → still/diag")
	# Hin und zurück: still/repeat (zusätzlich zum alten repeat-Ereignis)
	var gr := empty_state(1)
	var tr := ready_row(gr, FOREST)
	twist(gr, 0, 1, 1)
	tr.kind = FOREST
	twist(gr, 0, 1, -1)
	var rr := twist(gr, 0, 1, 1)
	check(not _still_of(rr, "repeat").is_empty() and str(_event(rr, "miss").get("why", "")) == "repeat", "hin und zurück → still/repeat")


## Fuzz: Auf allen Pool-Brettern jedes Tages und im freien Spiel (Einfach, Mittel, Schwer) zufällige Drehungen (auch
## sofort zurück). Nach jeder Drehung: Jede neu sichtbare Linie aus drei gleichen Feldern (gerade oder schräg, jede Art)
## durch ein bewegtes Feld wächst (ein Feld ändert sich) oder steht in einem still-/repeat-Ereignis. Keine stille Reihe
## ohne Rückmeldung. Dazu: Jede Drehung ohne Wachsen meldet sich (miss oder still); eine ruhende Reihe ist nie ein
## Fehlversuch.
func test_still_fuzz() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var twists := 0
	var trios := 0
	var silent := 0
	var quiet := 0
	var rest_miss := 0
	var others := 0
	var example := ""
	var games: Array = []
	for n in range(1, 8):
		for i in Days.pool_size(n):
			games.append([n, i])
	for lvl in [0, 1, 2]:
		for sd in 4:
			games.append([0, lvl * 10 + sd])
	for gi in games.size():
		var spec: Array = games[gi]
		var gs := GameState.new()
		var steps := 12
		if int(spec[0]) > 0:
			var b := Days.board(int(spec[0]), int(spec[1]))
			gs.setup_day(Days.config(int(spec[0])), b["kinds"], int(b["seed"]), 0)
		else:
			gs.setup(900 + int(spec[1]), true, int(spec[1]) / 10)
			steps = 30
		var last: Array = []
		for step in steps:
			if gs.is_over():
				break
			var mv: Array = GameState.MOVES[rng.randi() % GameState.MOVES.size()]
			if not last.is_empty() and rng.randf() < 0.25:
				mv = [int(last[0]), int(last[1]), -int(last[2]) if absi(int(last[2])) == 1 else 2]
			last = mv
			var arr := gs.clone()
			var pre: Dictionary = arr._trio_keys()
			arr.apply_rotation(int(mv[0]), int(mv[1]), int(mv[2]))
			var new_trios: Array = []
			for key in arr._trio_keys():
				if pre.has(key):
					continue
				var c := (int(key) >> 5) & 63
				var b2 := (int(key) >> 11) & 63
				var a := (int(key) >> 17) & 63
				if arr.moved.has(a) or arr.moved.has(b2) or arr.moved.has(c):
					new_trios.append([a, b2, c])
			var kinds0: Array = []
			for f in arr.fields:
				kinds0.append((f as FieldData).kind)
			var m0 := gs.misses
			var r := gs.play({"type": "twist", "axis": int(mv[0]), "layer": int(mv[1]), "turns": int(mv[2])})
			twists += 1
			var told := {}
			var has_rest := false
			var has_miss := false
			var has_still := false
			for e in r["events"]:
				var t := str(e["type"])
				if t == "still" or t == "repeat":
					var fs: Array = (e["fields"] as Array).duplicate()
					fs.sort()
					told[str(fs)] = true
				if t == "still":
					has_still = true
					if str(e["why"]) == "rest":
						has_rest = true
					elif str(e["why"]) == "other":
						others += 1
				if t == "miss" or GameState._EV8_NOTE.has(t):
					has_miss = true       # neue Tage: satt, Hunger, Blitz, Krieg … sind auch eine Rückmeldung
			for tri in new_trios:
				trios += 1
				var grew := false
				for fid in tri:
					if (gs.fields[int(fid)] as FieldData).kind != int(kinds0[int(fid)]):
						grew = true
				var key_s := str((tri as Array).duplicate())
				if not grew and not told.has(key_s):
					silent += 1
					if example == "":
						example = "Spiel %s, Zug %d %s: Reihe %s (%s) ohne Rückmeldung" % [str(spec), step, str(mv), key_s, FieldData.kind_name(int(kinds0[int(tri[0])]))]
			if int(r["grew"]) == 0 and not has_miss and not has_still and not _has_event(r, "wish_done"):
				quiet += 1
			if has_rest and int(r["grew"]) == 0 and gs.misses != m0 and not _has_event(r, "wish_done"):
				rest_miss += 1
	print("  Fuzz stille Reihen: %d Drehungen, %d neue Dreier, %d ohne Rückmeldung, %d stille Züge, %d „other“" % [twists, trios, silent, quiet, others])
	check(twists > 1500 and trios > 1000, "Fuzz: genug Drehungen und neue Reihen (%d, %d)" % [twists, trios])
	check(silent == 0, "Fuzz: jede neue Reihe aus drei gleichen wächst oder meldet sich (%d ohne Rückmeldung) %s" % [silent, example])
	check(quiet == 0, "Fuzz: jeder Zug ohne Wachsen meldet sich (miss oder still): %d stumm" % quiet)
	check(rest_miss == 0, "Fuzz: eine ruhende Reihe zählt nie als Fehlversuch (%d)" % rest_miss)


## Der Würfel bewegt sich nur ganz am Anfang von Tag 1 von selbst (die eine Vorführung), nie nach der ersten Eingabe.
## World.can_self_move() bewacht auto_twist, demo_move und demo_twist (World ohne Szene: nur die Wächter).
## Läuft als Letztes, nach einem Bild: Dann ist das Autoload Game im Baum.
func test_self_move_guard() -> void:
	var g: Node = root.get_node_or_null("Game")
	if g == null:
		check(false, "Autoload Game fehlt")
		return
	var path := "user://test_guard.cfg"
	var old_path: String = g.save_path
	g.save_path = path
	g.start_day(1, 0)
	# Erst jetzt laden: world.gd braucht das Autoload Game (beim Übersetzen dieser Datei gibt es das noch nicht)
	var world_script: GDScript = load("res://scripts/world.gd")
	var w: Node = world_script.new()
	check(g.day_tutorial() and w.can_self_move(), "Tag 1, Tutorial-Brett, vor jeder Eingabe: die eine Vorführung darf laufen")
	var t0 := InputEventScreenTouch.new()
	t0.index = 0
	t0.pressed = true
	t0.position = Vector2(100, 100)
	var t1 := InputEventScreenTouch.new()
	t1.index = 1
	t1.pressed = true
	t1.position = Vector2(200, 160)
	w.input_locked = true
	w._unhandled_input(t0)
	w._unhandled_input(t1)
	check(w.can_self_move() and w._touches.is_empty(), "„Schau zu!“ (gesperrt): Finger zählen nicht, die Vorführung läuft weiter")
	w.input_locked = false
	w._unhandled_input(t0)
	w._unhandled_input(t1)
	check(not w.can_self_move() and not w.auto_twist(0, 1, 1) and w.demo_move(0, Vector2.RIGHT, 0, 1, 1) == Vector2.ZERO
		and w.demo_twist(0, Vector2.RIGHT, 0, 1) == Vector2.ZERO and g.state.twists == 0,
		"nach der ersten Eingabe (zwei Finger): kein Zug, keine Vorführung ohne den Spieler")
	g.start_day(1, 0)
	check(w.can_self_move(), "„Tutorial nochmal“: ganz am Anfang wieder genau eine Vorführung")
	g.state.twists = 1
	check(not w.can_self_move() and not w.auto_twist(0, 1, 1), "nach dem ersten gezählten Zug (auch der Vorführung) nie mehr")
	g.start_day(1, 1)
	check(not g.day_tutorial() and not w.can_self_move(), "Nochmal / anderes Brett: keine Vorführung")
	g.start_mode("mittel")
	check(not w.can_self_move() and not w.auto_twist(0, 1, 1), "freies Spiel: nie")
	w.free()
	g.save_path = old_path
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_day_choices() -> void:
	var nocard := true
	for n in range(1, 8):
		for k in [MEADOW, VILLAGE, TOWN, ANIMALS]:
			if day_state(n).is_choice(k):
				nocard = false
	check(nocard, "neue Tage: nie eine Wahl-Karte")
	var g4 := day_state(4)
	var t4 := ready_row(g4, MEADOW)
	twist(g4, 0, 1, 1, {MEADOW: 1})
	check(t4.kind == FOREST and g4.card == -1, "Tag 4: Wiese → Wald, keine Karte (auch mit Antwort)")
	var g5 := day_state(5)
	var t5 := ready_row(g5, FOREST)
	twist(g5, 0, 1, 1)
	check(t5.kind == ANIMALS and g5.card == -1, "Tag 5: Wald → Tiere")
	var g6 := day_state(6)
	var t6 := ready_row(g6, ANIMALS)
	twist(g6, 0, 1, 1)
	check(t6.kind == HUT and top(g6, 0, 1).kind == MEADOW, "Tag 6: Tiere → Hütte (die anderen werden Wiese)")
	check(empty_state().is_choice(ANIMALS) and empty_state().is_choice(MEADOW), "freies Spiel: Karten wie bisher")


func test_made_counting() -> void:
	var gs := empty_state()
	gs.no_fire = true
	# Reihe
	var third := ready_row(gs, FIELD)
	twist(gs, 0, 1, 1)
	check(int(gs.made[HUT]) == 1 and third.kind == HUT, "made: eine Reihe zählt (Acker → Hütte)")
	# Kette: beide Arten
	var gc := empty_state()
	top(gc, 1, -1).kind = FOREST
	top(gc, 1, 0).kind = FOREST
	top(gc, 1, 1).kind = FOREST
	top(gc, 0, 1).kind = BIGFOREST
	top(gc, -1, 1).kind = BIGFOREST
	gc.moved = {top(gc, 1, 1).id: true}
	gc.end_round()
	check(int(gc.made[BIGFOREST]) == 1 and int(gc.made[ANIMALS]) == 1, "made: Kettenreaktion zählt beide Arten (%s)" % str(gc.made))
	# Seite
	var gf := empty_state()
	for f in gf.face_fields(UP):
		(f as FieldData).kind = FOREST
	gf.moved = {top(gf, 1, 1).id: true}
	gf.end_round()
	check(int(gf.made[BIGFOREST]) == 9, "made: eine ganze Seite zählt 9-mal")
	# Regen
	var gr := empty_state()
	gr.rain = 1
	top(gr, 0, 0).kind = MEADOW
	gr.play({"type": "rain", "field": top(gr, 0, 0).id})
	check(int(gr.made[FOREST]) == 1, "made: Regen zählt (Wiese → Wald)")
	# erfüllter Wunsch
	var gw := empty_state()
	var hut := top(gw, 0, 0)
	hut.kind = HUT
	gw.wishes = [{"id": 1, "type": "wald", "field": hut.id, "left": 8}]
	gw.field_at(Vector3i(1, 0, -1), Vector3i(0, 0, -1)).kind = FOREST
	twist(gw, 0, 1, 1)
	check(hut.kind == HOUSE and int(gw.made[HOUSE]) == 1, "made: ein erfüllter Wunsch zählt (Hütte → Haus)")
	# Fallen zählt nicht: Feuer, Krieg, Gewitter, Smog, Nachwachsen
	var gd := empty_state()
	gd.faith = 500
	top(gd, -1, -1).kind = FOREST
	top(gd, -1, -1).burning = true
	gd.field_at(Vector3i(1, 0, -1), Vector3i(0, 0, -1)).kind = CHURCH
	top(gd, 0, 0).kind = CHURCH
	var tw := top(gd, 1, 1)
	tw.kind = TOWN
	gd.play({"type": "strike", "field": tw.id})
	var rd := twist(gd, 0, 1, 1)
	check(_has_event(rd, "war") and top(gd, -1, -1).kind == MEADOW and tw.kind == VILLAGE, "Aufbau: Brand, Krieg und Gewitter passiert")
	var sum := 0
	for v in gd.made:
		sum += int(v)
	check(sum == 0, "made: Feuer, Krieg und Gewitter zählen nicht (%s)" % str(gd.made))
	var gg := empty_state()
	for xz in [Vector2i(1, 0), Vector2i(0, 1)]:
		top(gg, xz.x, xz.y).kind = E
	top(gg, 0, 0).kind = MEADOW
	top(gg, 1, 1).kind = FOREST
	var rg := twist(gg, 1, -1, 1)
	check(_has_event(rg, "regrow") and int(gg.made[MEADOW]) == 0, "made: Nachwachsen zählt nicht")
	# clone() und Rückgängig
	var cl := gs.clone()
	cl.made[HUT] = 99
	check(int(gs.made[HUT]) == 1, "made: clone() kopiert (unabhängig)")
	var undo := gs.clone()
	gs.moved = {}
	ready_row(gs, FIELD)
	top(gs, 1, 1).kind = WATER
	twist(gs, 0, 1, 1)
	check(int(gs.made[HUT]) == 2 and int(undo.made[HUT]) == 1, "made: der Rückgängig-Stand bleibt, wie er war (%d / %d)" % [int(gs.made[HUT]), int(undo.made[HUT])])


## „Jede Reihe wächst nur einmal“ (GDPD_BALANCE_2.md 2.1): freies Spiel und Tage.
func test_once() -> void:
	# once_basic: dieselbe Reihe (3 Felder, alte Art) wächst nie wieder, auch nach einem Fall und einem anderen Zug dazwischen
	for mode in ["frei", "tag2"]:
		var gs := empty_state(1) if mode == "frei" else day_state(2)
		var k1 := FOREST if mode == "frei" else MEADOW
		var third := ready_row(gs, k1)
		var r0 := twist(gs, 0, 1, 1)
		check(int(r0["grew"]) == 1 and third.kind != k1, "%s: die Reihe wächst einmal" % mode)
		third.kind = k1                     # fällt zurück (Feuer, Smog …)
		twist(gs, 0, 1, -1)
		twist(gs, 1, -1, 1)                 # ein anderer Zug dazwischen: nicht nur „zurückgedreht“
		var r1 := twist(gs, 0, 1, 1)
		var sp := _still_of(r1, "spent")
		check(int(r1["grew"]) == 0 and third.kind == k1 and not sp.is_empty(), "%s: wieder gebildet → wächst nicht, still/spent (%s)" % [mode, str(sp)])
		# once_new_trio: dieselben Felder mit einer anderen Art sind eine neue Reihe
		for f in [top(gs, -1, 1), top(gs, 0, 1), third]:
			(f as FieldData).kind = MEADOW if mode == "frei" else E
		twist(gs, 0, 1, -1)
		twist(gs, 1, -1, 1)
		var r2 := twist(gs, 0, 1, 1)
		check(int(r2["grew"]) == 1, "%s: dieselben Felder als Wiesen-Reihe wachsen (neue Reihe)" % mode)
	# once_face: eine ganze Seite wächst, alle ihre Reihen sind verbraucht
	var gf := empty_state(1)
	for f in gf.face_fields(UP):
		(f as FieldData).kind = FOREST
	var before := gf.spent.size()
	gf.moved = {top(gf, 1, 1).id: true}
	gf.end_round()
	check(gf.spent.size() - before == 8, "ganze Seite: 8 Reihen (6 gerade, 2 schräg) sind verbraucht (%d)" % (gf.spent.size() - before))
	# clone kopiert spent
	var cl := gf.clone()
	cl.spent[1] = true
	check(not gf.spent.has(1) and cl.once, "clone() kopiert spent unabhängig")
	# Nachwachsen schließt keine Reihe (freies Spiel)
	var gn := empty_state(1)
	top(gn, -1, 1).kind = MEADOW
	top(gn, 0, 1).kind = MEADOW
	top(gn, 1, 0).kind = MEADOW
	top(gn, 1, 1).kind = E
	var rn := twist(gn, 1, -1, 1)
	var regrew := false
	for e in rn["events"]:
		if str(e["type"]) == "regrow" and int(e["field"]) == top(gn, 1, 1).id:
			regrew = true
	check(not regrew and top(gn, 1, 1).kind == E, "Nachwachsen: eine Erde, die eine Wiesen-Reihe schließen würde, wächst nicht nach")


## Abgleich mit dem Python-Modell (GDPD_BALANCE_2.md 11.2): 187 Fälle (zufällig, Farmen, guter Bot, viele Werkzeuge) auf
## allen 7 Tagen; jeder Schritt (Arten, Plätze, satt/hungrig, Feuer, Blitz, Krieg, Flut, Glaube, Regen, Ziel) als md5.
func test_xcheck8() -> void:
	var f := FileAccess.open("res://tests/data/xcheck8_cases.json", FileAccess.READ)
	check(f != null, "Abgleich: tests/data/xcheck8_cases.json da")
	if f == null:
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var ref := GameState.new()
	ref.setup_day(Days.config(1), [], 1, 0)
	var slot := {}
	for fd in ref.fields:
		slot[GameState.pos_key(fd.p, fd.n)] = fd.id
	var bad := 0
	var steps := 0
	var cases: Array = data["cases"]
	for c in cases:
		var cd: Dictionary = c
		var cfg := Days.config(int(cd["day"]))
		if int(cd["limit"]) > 0:
			cfg["limit"] = int(cd["limit"])
		var gs := GameState.new()
		gs.setup_day(cfg, Days.decode(str(cd["board"])), int(cd["seed"]), 0)
		var recs: Array = []
		for a in cd["actions"]:
			var ad: Array = a
			if str(ad[0]) == "twist":
				var m: Array = ad[1]
				gs.play({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])})
			else:
				gs.play({"type": str(ad[0]), "field": int(ad[1])})
			recs.append(_rec8(gs, slot))
			steps += 1
			if gs.day_won or gs.day_lost != "":
				break
		var s := ";".join(PackedStringArray(recs))
		if recs.size() != int(cd["steps"]) or s.md5_text() != str(cd["md5"]):
			bad += 1
			if bad <= 3:
				print("  Abgleich: Tag %d Seed %d weicht ab (Schritte %d/%d)\n    gd %s\n    py %s" % [int(cd["day"]), int(cd["seed"]),
					recs.size(), int(cd["steps"]), str(recs[recs.size() - 1]) if not recs.is_empty() else "", str(cd["last"])])
	check(cases.size() >= 150 and steps > 3000 and bad == 0, "Abgleich mit engine8.py: %d Fälle, %d Schritte, %d abweichend" % [cases.size(), steps, bad])


func _join8(a: Array) -> String:
	var out := PackedStringArray()
	for v in a:
		out.append(str(int(v)))
	return ",".join(out)


func _rec8(gs: GameState, slot: Dictionary) -> String:
	var kinds: Array = []
	var pos: Array = []
	var fed: Array = []
	var hun: Array = []
	var burn: Array = []
	var fresh: Array = []
	for fd in gs.fields:
		kinds.append(fd.kind)
		pos.append(int(slot[GameState.pos_key(fd.p, fd.n)]))
		fed.append(fd.fed)
		hun.append(fd.hungry)
		burn.append(1 if fd.burning else 0)
		fresh.append(fd.fresh)
	var front: Array = gs.front.keys()
	front.sort()
	var fw: Array = gs.flood_warn.keys()
	fw.sort()
	var made_sum := 0
	for v in gs.made:
		made_sum += int(v)
	var parts := PackedStringArray([_join8(kinds), _join8(pos), _join8(fed), _join8(hun), _join8(burn), _join8(fresh), str(gs.bolt),
		"1" if gs.war_on else "0", _join8(front), _join8(fw), str(gs.faith), str(gs.rain), str(gs.twists), "1" if gs.day_won else "0",
		gs.day_lost, str(made_sum), str(gs.goal_progress()), _join8(gs.satt_ids())])
	return "|".join(parts)


## 3 Tiere → 1 Hütte, die anderen beiden werden Wiese (4.2).
func test_consume() -> void:
	var gs := day_state(4)
	var third := ready_row(gs, ANIMALS)
	var r := twist(gs, 0, 1, 1)
	var ce := _event(r, "consume")
	check(third.kind == HUT and top(gs, -1, 1).kind == MEADOW and top(gs, 0, 1).kind == MEADOW and int(gs.made[HUT]) == 1
		and not ce.is_empty() and int(ce["field"]) == third.id and (ce["others"] as Array).size() == 2,
		"Tiere-Reihe: Ziel wird Hütte, die anderen beiden Wiese, made[Hütte] +1 (%s)" % str(ce))
	check(third.maxlvl == 0 and third.fed == 0 and not gs.satt(third), "die neue Hütte ist hungrig (keine Tiere mehr daneben)")


## Bedürfnisse (4.3): Hütte 🍞, Dorf 🍞🔨, Stadt 🍞🔨🙏; brennend oder an der Front nie satt.
func test_needs() -> void:
	var g5 := day_state(5)
	var c := top(g5, 0, 0)
	c.kind = HUT
	top(g5, 1, 0).kind = FIELD
	check(g5.satt(c), "Hütte neben Acker ist satt")
	c.kind = VILLAGE
	check(not g5.satt(c) and (g5.need_state(c)["missing"] as Array) == ["work"], "Dorf neben Acker allein: Arbeit fehlt")
	top(g5, -1, 0).kind = STONE
	check(g5.satt(c), "Dorf neben Acker und Stein: satt")
	c.burning = true
	check(not g5.satt(c), "brennendes Dorf ist nie satt")
	c.burning = false
	var g6 := day_state(6)
	var t := top(g6, 0, 0)
	t.kind = TOWN
	top(g6, 1, 0).kind = ANIMALS
	top(g6, -1, 0).kind = FOREST
	check(not g6.satt(t) and (g6.need_state(t)["missing"] as Array) == ["faith"], "Stadt ohne Kirche: Glaube fehlt")
	top(g6, 0, 1).kind = CHURCH
	check(g6.satt(t), "Stadt mit Nahrung, Arbeit und Kirche: satt")
	g6.front = {t.id: true}
	check(not g6.satt(t), "an der Kriegsfront nie satt")
	var g4 := day_state(4)
	var h := top(g4, 0, 0)
	h.kind = HUT
	h.fed = 0
	check(not g4.satt(h) and not day_state(3).satt(h), "ohne Nahrung nicht satt; Tag 3 kennt keine Menschen")
	var st := g5.field_state8(c)
	check(bool(st["people"]) and bool(st["satt"]) and int(st["grow_after"]) == 2, "field_state8 für die Felder-Ansicht (%s)" % str(st))


## Gedeihen (4.3): satt 2 Runden → nächste Stufe (wenn heute erlaubt), 4 Runden Hunger → eine Stufe zurück,
## eine Hütte schrumpft nie, made zählt eine Stufe je Feld nur beim ersten Mal.
func test_thrive_timing() -> void:
	var g5 := day_state(5)
	var c := top(g5, 0, 1)
	c.kind = HUT
	var acker := g5.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1))
	acker.kind = FIELD                  # kommt mit x = 1 neben die Hütte (oben rechts)
	var r1 := twist(g5, 0, 1, 1)
	check(c.kind == HUT and c.fed == 1 and _has_event(r1, "satt_new") and int(_event(r1, "satt_new")["field"]) == c.id,
		"Tag 5: die Drehung bringt den Acker neben die Hütte: satt_new, fed 1")
	var r2 := twist(g5, 1, -1, 1)
	check(c.kind == VILLAGE and int(g5.made[VILLAGE]) == 1 and _has_event(r2, "thrive") and c.fed == 0, "Tag 5: 2 Runden satt → Dorf (thrive, made +1)")
	acker.kind = WATER
	for i in 3:
		twist(g5, 1, -1, 1)
	check(c.kind == VILLAGE and c.hungry == 3, "3 Runden hungrig: noch Dorf (hungry 3)")
	var r3 := twist(g5, 1, -1, 1)
	check(c.kind == HUT and _has_event(r3, "starve"), "4 Runden hungrig → Hütte (starve)")
	acker.kind = FIELD
	top(g5, -1, 1).kind = STONE
	twist(g5, 1, -1, 1)
	twist(g5, 1, -1, 1)
	check(c.kind == VILLAGE and int(g5.made[VILLAGE]) == 1, "wieder satt → wieder Dorf, made zählt nicht doppelt (%d)" % int(g5.made[VILLAGE]))
	var g4 := day_state(4)
	var h := top(g4, 0, 0)
	h.kind = HUT
	top(g4, 1, 0).kind = ANIMALS
	for i in 3:
		twist(g4, 1, -1, 1)
	check(h.kind == HUT and h.fed == 3, "Tag 4: Hütte bleibt Hütte (heute höchstens Hütte)")
	var g4h := day_state(4)
	var h2 := top(g4h, 0, 0)
	h2.kind = HUT
	for i in 6:
		twist(g4h, 1, -1, 1)
	check(h2.kind == HUT and h2.hungry == 6, "eine Hütte schrumpft nie (hungry %d)" % h2.hungry)


## Blitz und Feuer (4.4): Warnung, Einschlag eine Drehung später, Regen hebt auf; Feuer springt nicht auf nasse Felder;
## verbrannte Felder fangen 2 Schritte lang kein Feuer.
func test_bolt() -> void:
	var b := Days.board(3, 0)
	var gs := GameState.new()
	gs.setup_day(Days.config(3), b["kinds"], int(b["seed"]), 0)
	var r1 := twist(gs, 0, 1, 1)
	check(gs.bolt == 47 and (gs.fields[47] as FieldData).kind == FOREST and _has_event(r1, "bolt_warn"), "Tag 3 Brett 0: nach [0, 1, 1] Blitz-Warnung auf Feld 47 (Wald) (%d)" % gs.bolt)
	var gr := gs.clone()
	check(gr.can_bonus("rain", gr.fields[47]) == "", "Regen geht auf das gewarnte Feld")
	var rr: Dictionary = gr.play({"type": "rain", "field": 47})
	check(gr.bolt == -1 and _has_event(rr, "bolt_cancel"), "Regen auf das gewarnte Feld: bolt_cancel")
	var r2 := twist(gs, 1, -1, 1)
	check(_has_event(r2, "bolt") and (gs.fields[47] as FieldData).burning, "nach der nächsten Drehung brennt Feld 47")
	var gf := day_state(3)
	for f in gf.fields:
		(f as FieldData).kind = ANIMALS
	gf.field_at(Vector3i(0, -1, 0), Vector3i(0, -1, 0)).kind = WATER
	var c := top(gf, 0, 0)
	c.kind = VILLAGE
	c.burning = true
	gf.field_at(Vector3i(1, 1, 0), Vector3i(1, 0, 0)).kind = WATER     # macht top(1, 0) nass
	var rf := twist(gf, 1, -1, 1)
	check(c.kind == HUT and c.fresh == 3 and _has_event(rf, "burn") and top(gf, -1, 0).burning and top(gf, 0, 1).burning
		and top(gf, 0, -1).burning and not top(gf, 1, 0).burning, "Feuer: Dorf → Hütte, springt auf trockene Nachbarn, nicht auf nasse")
	twist(gf, 1, -1, 1)
	check(not c.burning and c.kind == HUT, "verbrannte Felder fangen gleich danach kein Feuer (fresh)")


## Krieg (4.4): Kirche an Kirche → Warnung, dann fällt die Front jede Drehung eine Stufe und wächst; getrennt → Frieden.
func test_war8() -> void:
	var gs := day_state(6)
	top(gs, 0, 0).kind = CHURCH
	top(gs, 1, 0).kind = CHURCH
	var d := top(gs, 0, 1)
	d.kind = VILLAGE
	var h := top(gs, -1, 1)
	h.kind = HUT
	var r1 := twist(gs, 1, -1, 1)
	check(gs.war_on and _has_event(r1, "war_start") and gs.front.has(d.id) and d.kind == VILLAGE and not gs.front.has(h.id), "Kirche an Kirche: war_start, Front = Dorf daneben, noch kein Schaden")
	var r2 := twist(gs, 1, -1, 1)
	check(d.kind == HUT and _has_event(r2, "war_hit") and gs.front.has(h.id), "nächste Drehung: Front fällt eine Stufe und wächst")
	gs.faith = GameState.METEOR_COST
	check(gs.tool_unlocked("strike") and gs.can_bonus("strike", top(gs, 1, 0)) == "", "Meteor bereit (12 Glaube, Platz des Gewitters)")
	var rm: Dictionary = gs.play({"type": "strike", "field": top(gs, 1, 0).id})
	check(top(gs, 1, 0).kind == E and gs.faith == 0 and _has_event(rm, "meteor"), "Meteor auf eine Kirche: Krater (Erde), kostet 12 Glauben")
	var r3 := twist(gs, 1, -1, 1)
	check(not gs.war_on and gs.front.is_empty() and _has_event(r3, "war_end"), "Kirchen getrennt: Frieden")
	check(not day_state(5).tool_unlocked("strike") and not day_state(5).tool_unlocked("meteor"), "Tag 5: noch kein Meteor")


## Flut und Smog (Tag 7): Stadt-Gewicht ≥ 5 → Warnung, eine Drehung später werden niedrige nasse Felder Wasser;
## Industrie lässt jede Drehung ihren besten Natur-Nachbarn fallen.
func test_flood_smog() -> void:
	var gs := day_state(7)
	top(gs, -1, -1).kind = TOWN
	top(gs, 1, -1).kind = TOWN
	top(gs, -1, 1).kind = VILLAGE
	var low := top(gs, 1, 1)
	low.kind = MEADOW
	var r1 := twist(gs, 1, -1, 1)
	check(gs.flood_warn.has(0) and _has_event(r1, "flood_warn") and low.kind == MEADOW, "Gewicht 5 auf einer Seite: flood_warn, noch keine Flut")
	var r2 := twist(gs, 1, -1, 1)
	check(low.kind == WATER and _has_event(r2, "flood"), "nächste Drehung: niedriges nasses Feld wird Wasser")
	var gi := day_state(7)
	top(gi, 0, 0).kind = INDUSTRY
	top(gi, 1, 0).kind = ANIMALS
	top(gi, -1, 0).kind = FOREST
	top(gi, 0, 1).kind = MEADOW
	var rs := twist(gi, 1, -1, 1)
	check(top(gi, 1, 0).kind == FOREST and top(gi, -1, 0).kind == FOREST and _has_event(rs, "polluted") and _has_event(rs, "smog"), "Smog: Tiere neben der Fabrik werden Wald")
	twist(gi, 1, -1, 1)
	check(top(gi, 1, 0).kind == MEADOW or top(gi, -1, 0).kind == MEADOW, "Smog wirkt jede Drehung")
	check(not _has_event(twist(day_state(6), 1, -1, 1), "smog"), "Tag 6: kein Smog")


## Vorschau beim Ziehen (4.6): Tag 5 Brett 0, [1, 0, −1] macht Feld 10 satt.
func test_preview8() -> void:
	var b := Days.board(5, 0)
	var gs := GameState.new()
	gs.setup_day(Days.config(5), b["kinds"], int(b["seed"]), 0)
	var s0 := sig(gs)
	# eine Drehung, die jemanden satt macht: die Vorschau zeigt genau, wer nach der Auswertung neu satt ist
	var found: Array = []
	for m in GameState.MOVES:
		var p := gs.preview8(int(m[0]), int(m[1]), int(m[2]))
		if not (p["satt_new"] as Array).is_empty():
			found = [m, p]
			break
	check(not found.is_empty() and sig(gs) == s0, "Tag 5 Brett 0: eine Drehung macht jemanden satt (Vorschau), der Stand bleibt")
	# Vorschau = Ergebnis (auch nach 3 Tiere → Hütte, Krieg, Wachsen): über alle Drehungen der ersten Bretter der Tage 4–7
	var miss_new := 0
	var miss_lost := 0
	var n_moves := 0
	for n in range(4, 8):
		for i in 3:
			var bb := Days.board(n, i)
			var g := GameState.new()
			g.setup_day(Days.config(n), bb["kinds"], int(bb["seed"]), 0)
			for m in GameState.MOVES:
				var p := g.preview8(int(m[0]), int(m[1]), int(m[2]))
				var sim := g.clone()
				var r := twist(sim, int(m[0]), int(m[1]), int(m[2]))
				var got_new: Array = []
				var got_lost: Array = []
				for e in r["events"]:
					if str(e["type"]) == "satt_new":
						got_new.append(int(e["field"]))
					elif str(e["type"]) == "satt_lost" and FieldData.level8((sim.fields[int(e["field"])] as FieldData).kind) <= FieldData.level8((g.fields[int(e["field"])] as FieldData).kind):
						got_lost.append(int(e["field"]))
				got_new.sort()
				got_lost.sort()
				n_moves += 1
				if got_new != (p["satt_new"] as Array):
					miss_new += 1
				if got_lost != (p["satt_lost"] as Array):
					miss_lost += 1
	check(miss_new == 0 and miss_lost == 0, "Vorschau satt/verliert = was die Drehung wirklich macht (%d Drehungen, %d/%d abweichend)" % [n_moves, miss_new, miss_lost])
	var b6 := Days.board(6, 0)
	var g6 := GameState.new()
	g6.setup_day(Days.config(6), b6["kinds"], int(b6["seed"]), 0)
	var war_moves := 0
	for m in GameState.MOVES:
		if bool(g6.preview8(int(m[0]), int(m[1]), int(m[2]))["war_risk"]):
			war_moves += 1
	check(war_moves >= 1, "Tag 6 Brett 0: mindestens eine Drehung würde Krieg bringen (%d)" % war_moves)
	var b7 := Days.board(7, 0)
	var g7 := GameState.new()
	g7.setup_day(Days.config(7), b7["kinds"], int(b7["seed"]), 0)
	var flood_moves := 0
	for m in GameState.MOVES:
		if not (g7.preview8(int(m[0]), int(m[1]), int(m[2]))["flood_risk"] as Array).is_empty():
			flood_moves += 1
	check(flood_moves >= 1, "Tag 7 Brett 0: mindestens eine Drehung bringt eine Seite mit zu viel Stadt (%d)" % flood_moves)


## Weiterbauen nach dem Sieg: die Extra-Aufgabe (Aufgabe + 1 …), Tage 1–3 drei, Tage 4–7 eine.
func test_extras() -> void:
	var gs := day_state(4)
	gs.day_won = true
	gs.day_won_at = 6
	gs.start_free_build()
	var st := gs.day_status()
	check(str(st["extra_text"]) == "Extra: 4 Hütten satt" and int(st["extra_max"]) == 1 and int(st["extra_target"]) == 4,
		"Tag 4 im Weiterbauen: „Extra: 4 Hütten satt“ (%s)" % str(st["extra_text"]))
	var spots := [[-1, -1], [1, -1], [-1, 1], [1, 1]]
	for sp in spots:
		top(gs, int(sp[0]), int(sp[1])).kind = HUT
	top(gs, 0, -1).kind = ANIMALS
	top(gs, 0, 1).kind = ANIMALS
	var r := twist(gs, 1, -1, 1)
	check(gs.goal_progress() == 4 and _has_event(r, "extra") and gs.extra_level == 1 and str(gs.day_status()["extra_text"]) == "Bau weiter",
		"vier Hütten satt: Extra geschafft, dann „Bau weiter“")
	check(day_state(2).extra_max() == 3 and empty_state().extra_max() == 0, "Tage 1–3: drei Extras; freies Spiel keine")
	check(Days.extra_line(Days.config(1), 9) == "Extra: 9 Wiesen", "Extra-Text Tag 1 (kurz für den Chip)")


## Neuer Morgen (5.6): ein paar Felder des Bretts (höchstens Days.OVERNIGHT_MAX) wachsen aus der niedrigeren Art herauf.
func test_overnight() -> void:
	check(Days.overnight_changes(Days.config(1), Days.board(1, 0)["kinds"]).is_empty(), "Tag 1: nichts über Nacht")
	for n in range(2, 8):
		var cfg := Days.config(n)
		var ks: Array = Days.board(n, 0)["kinds"]
		var ch := Days.overnight_changes(cfg, ks)
		var pair: Array = (cfg["overnight"] as Array)[0]
		var want := 0
		for k in ks:
			if int(k) == int(pair[1]):
				want += 1
		var ok := ch.size() == mini(want, Days.OVERNIGHT_MAX) and want > 0
		for c in ch:
			if int((c as Dictionary)["from"]) != int(pair[0]) or int(ks[int((c as Dictionary)["field"])]) != int(pair[1]):
				ok = false
		check(ok and str(cfg.get("overnight_line", "")) != "", "Tag %d: %d Felder wachsen am neuen Morgen (%s)" % [n, ch.size(), str(cfg.get("overnight_line", ""))])


## Arten, die auf diesem Brett heute wachsen können: Reihen-Arten mit ≥ 3 Feldern und Menschen unter der heutigen Stufe.
func growable_kinds(gs: GameState) -> Array:
	var out: Array = []
	var cnt := {}
	for f in gs.fields:
		cnt[f.kind] = int(cnt.get(f.kind, 0)) + 1
	for k in gs.rows8:
		if int(cnt.get(int(k), 0)) >= 3:
			out.append(int(k))
	if gs.top8 >= 0:
		for k in GameState.PEOPLE8:
			if cnt.has(int(k)) and FieldData.level8(int(k)) < FieldData.level8(gs.top8):
				out.append(int(k))
	return out


## Farmen bringt nichts (GDPD_BALANCE_2.md 2, 12 no_farming): Auf jedem Pool-Brett gewinnt weder „eine Scheibe hin und
## her“ noch „immer dieselbe Drehung“ (alle 27 Drehungen); in 6 Drehungen hin und her wächst nach der 2. Drehung fast
## nichts mehr (Tag 3 mit Blitz ≤ 2, Tage 4 und 7 ≤ 1, sonst 0), insgesamt ≤ 4.
func test_farm_pools() -> void:
	var t0 := Time.get_ticks_msec()
	var wins := 0
	var late_bad := 0
	var total_bad := 0
	var best_late := [0, 0, 0, 0, 0, 0, 0, 0]
	var allow := {1: 0, 2: 0, 3: 2, 4: 1, 5: 0, 6: 0, 7: 1}
	var ex := ""
	for n in range(1, 8):
		var cfg := Days.config(n)
		for i in Days.pool_size(n):
			var b := Days.board(n, i)
			for m in GameState.MOVES:
				var inv: Array = [int(m[0]), int(m[1]), -int(m[2]) if absi(int(m[2])) == 1 else 2]
				for style in ["pp", "rot"]:
					if style == "rot" and absi(int(m[2])) == 2:
						continue          # immer dieselbe halbe Drehung ist hin und her
					var gs := GameState.new()
					gs.setup_day(cfg, b["kinds"], int(b["seed"]), 0)
					var late := 0
					var grown := 0
					for t in gs.day_limit:
						var mv: Array = m if (style == "rot" or t % 2 == 0) else inv
						var r := twist(gs, int(mv[0]), int(mv[1]), int(mv[2]))
						var g := _count_events(r, "merge") + _count_events(r, "face")
						if t < 6:
							grown += g
							if t >= 2:
								late += g
						if gs.is_over():
							break
					if gs.day_won:
						wins += 1
						if ex == "":
							ex = "Tag %d Brett %d %s %s" % [n, i, style, str(m)]
					if style == "pp":
						best_late[n] = maxi(int(best_late[n]), late)
						if late > int(allow[n]):
							late_bad += 1
						if grown > 4:
							total_bad += 1
	print("  Farmen auf den Pools: Hin-und-her nach Drehung 2 höchstens %s (Tage 1–7), %d ms" % [str(best_late.slice(1)), Time.get_ticks_msec() - t0])
	check(wins == 0, "kein Farmer gewinnt ein Pool-Brett (%d, z. B. %s)" % [wins, ex])
	check(late_bad == 0 and total_bad == 0, "hin und her: nach Drehung 2 wächst kaum noch etwas (%d zu viel, %d über 4 in 6 Drehungen)" % [late_bad, total_bad])


## Freies Spiel Mittel (3.1): eine Scheibe hin und her (Median der 9 Scheiben) wächst auf höchstens 40 % der Drehungen.
func test_free_farm() -> void:
	var rates: Array = []
	for sd in 12:
		var per: Array = []
		for a in 3:
			for l in [-1, 0, 1]:
				var gs := new_state(500 + sd, 1)
				var grew := 0
				var n := 0
				for t in 30:
					if gs.is_over():
						break
					var r := twist(gs, a, l, 1 if t % 2 == 0 else -1)
					n += 1
					if int(r["grew"]) > 0:
						grew += 1
				per.append(float(grew) / float(maxi(1, n)))
		per.sort()
		rates.append(float(per[4]))
	var avg := 0.0
	for v in rates:
		avg += float(v)
	avg /= float(rates.size())
	print("  Freies Spiel Mittel, Median-Scheibe hin und her: wächst auf %.0f %% der Drehungen" % (avg * 100.0))
	check(avg <= 0.40, "freies Spiel Mittel: eine Scheibe hin und her wächst auf ≤ 40 %% der Drehungen (%.0f %%)" % (avg * 100.0))


# =============================================================================
# Die Schöpfung in 7 Tagen (GDPD_7_TAGE.md 9.1, Punkte 6–15)
# =============================================================================

## Die Tag-Tabelle (GDPD_BALANCE_2.md 5.2).
func test_day_table() -> void:
	check(Days.count() == 7 and Days.config(0).is_empty() and Days.config(8).is_empty(), "7 Tage")
	var limits: Array = []
	var stars: Array = []
	var goals: Array = []
	var lines: Array = []
	var rows: Array = []
	var tops: Array = []
	for n in range(1, 8):
		var c := Days.config(n)
		limits.append(int(c["limit"]))
		stars.append(c["stars"])
		goals.append([str(c["goal_type"]), c["goal_kinds"], int(c["goal_target"])])
		lines.append(Days.goal_line(c))
		var r: Array = (c["rows"] as Array).duplicate()
		r.sort()
		rows.append(r)
		tops.append(int(c["top"]))
	check(limits == [15, 14, 10, 14, 13, 12, 11], "Drehungen je Tag (%s)" % str(limits))
	check(stars == [[4, 6], [5, 7], [4, 6], [6, 9], [4, 7], [4, 6], [4, 6]], "Sterne je Tag (%s)" % str(stars))
	check(goals == [["make", [MEADOW], 8], ["make", [FOREST], 5], ["make", [ANIMALS], 4], ["satt", [HUT], 3], ["satt", [VILLAGE], 3],
		["satt", [TOWN], 3], ["satt", [TOWN], 3]], "Ziele je Tag (%s)" % str(goals))
	check(lines == ["Lass 8 Wiesen wachsen", "Lass 5 Wälder wachsen", "Erschaffe 4 Tiere", "Versorge 3 Hütten", "Mach 3 Dörfer satt",
		"Mach 3 Städte satt", "Mach 3 Städte satt"], "Ziel-Texte (%s)" % str(lines))
	check(rows == [[E], [E, MEADOW], [MEADOW, FOREST], [MEADOW, FOREST, ANIMALS], [FOREST, ANIMALS], [ANIMALS], [ANIMALS]]
		and tops == [-1, -1, -1, HUT, VILLAGE, TOWN, TOWN], "Reihen-Arten und höchste Menschen-Stufe je Tag (%s %s)" % [str(rows), str(tops)])
	var no_erde := true
	var no_wiese := true
	for n in range(3, 8):
		if (Days.config(n)["rows"] as Array).has(E):
			no_erde = false
		if n >= 5 and (Days.config(n)["rows"] as Array).has(MEADOW):
			no_wiese = false
	check(no_erde and no_wiese, "ab Tag 3 keine Erde-Reihen, ab Tag 5 keine Wiesen-Reihen")
	# Systeme je Tag: Regen, Blitz, Krieg, Meteor, Smog, Flut, Regen-Acker, Feuer nach Fehlversuchen
	var sysrow: Array = []
	for n in range(1, 8):
		var g := day_state(n)
		var c2 := g.day
		sysrow.append("%d%d%d%d%d%d%d%d" % [int(g.rain > 0), int(int(c2["lightning"]) > 0), int(bool(c2["war8"])), int(bool(c2["meteor"])),
			int(bool(c2["smog8"])), int(bool(c2["flood8"])), int(bool(c2["rain_acker"])), int(not g.no_fire)])
	check(sysrow == ["00000000", "10000000", "11000000", "11000000", "11000010", "10110010", "10111110"], "Systeme je Tag (%s)" % str(sysrow))
	var g1 := day_state(1)
	check(g1.v8 and g1.once and not g1.hearts and not g1.diagonals and not g1.easy and not g1.sys_wishes and not g1.sys_scale
		and not g1.sys_war and not g1.sys_smog and not g1.sys_strike, "neue Tage: keine Herzen, Diagonalen, Wünsche, Waage, altes Krieg/Smog/Gewitter")


## Pools (5.5): 20 Bretter je Tag, Zusammensetzung wie 5.1, keine fertige Reihe, keine sich berührenden Kirchen, nichts
## satt, kein Ziel bei Drehung 0, keine einzelne Drehung gewinnt, höchstens 3 Arten, die heute wachsen können.
func test_day_boards() -> void:
	var comp := {
		1: {E: 22}, 2: {MEADOW: 10, E: 16}, 3: {MEADOW: 18, FOREST: 7}, 4: {FOREST: 10, ANIMALS: 13, MEADOW: 2},
		5: {HUT: 5, FOREST: 7, ANIMALS: 5, STONE: 3, MEADOW: 7},
		6: {VILLAGE: 8, CHURCH: 3, FOREST: 7, ANIMALS: 5, FIELD: 4, STONE: 3},
		7: {TOWN: 5, CHURCH: 3, INDUSTRY: 2, FOREST: 9, ANIMALS: 5, FIELD: 4},
	}
	var bad_len := 0
	var bad_comp := 0
	var bad_ready := 0
	var bad_church := 0
	var bad_satt := 0
	var pre_solved := 0
	var one_twist := 0
	var max_kinds: Array = []
	var bad_kinds := 0
	var max_vis: Array = []
	var bad_vis := 0
	for n in range(1, 8):
		var cfg := Days.config(n)
		check(Days.pool_size(n) == 20, "Tag %d: 20 Bretter im Pool" % n)
		var mk := 0
		var mv := 0
		for i in Days.pool_size(n):
			var b := Days.board(n, i)
			var ks: Array = b["kinds"]
			if ks.size() != 54:
				bad_len += 1
				continue
			var cnt := {}
			for k in ks:
				cnt[int(k)] = int(cnt.get(int(k), 0)) + 1
			var want: Dictionary = (comp[n] as Dictionary).duplicate()
			var water := 54
			for k in want:
				water -= int(want[k])
			want[WATER] = water
			if cnt != want:
				bad_comp += 1
			var gs := GameState.new()
			gs.setup_day(cfg, ks, int(b["seed"]), 0)
			if not gs.lines().is_empty():
				bad_ready += 1
			if not gs.church_touch8().is_empty():
				bad_church += 1
			if not gs.satt_ids().is_empty():
				bad_satt += 1
			if gs.goal_progress() > 0:
				pre_solved += 1
			for m in GameState.MOVES:
				var sim := gs.clone()
				sim.play({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])}, {})
				if sim.day_won:
					one_twist += 1
			var gk := growable_kinds(gs)
			mk = maxi(mk, gk.size())
			if gk.size() > 3:
				bad_kinds += 1
			# sichtbare Arten (ohne Wasser): nicht zu viele verschiedene Felder auf einmal (GDPD_BALANCE_2.md 5.1)
			var vis := Days.visible_kinds(ks)
			mv = maxi(mv, vis)
			if vis > int(Days.VISIBLE_MAX[n]):
				bad_vis += 1
		max_kinds.append(mk)
		max_vis.append(mv)
	check(bad_len == 0, "Bretter: 54 Zeichen")
	check(bad_comp == 0, "Bretter: Zusammensetzung wie in der Spec (%d falsch)" % bad_comp)
	check(bad_ready == 0, "Bretter: keine fertige Reihe einer Art, die heute wächst (%d)" % bad_ready)
	check(bad_church == 0, "Bretter: Kirchen berühren sich nie")
	check(bad_satt == 0, "Bretter: am Morgen ist niemand satt (%d)" % bad_satt)
	check(pre_solved == 0, "Bretter: kein Fortschritt bei Drehung 0")
	check(one_twist == 0, "Bretter: keine einzelne Drehung gewinnt (%d)" % one_twist)
	check(bad_kinds == 0 and max_kinds == [1, 2, 2, 2, 3, 2, 1], "höchstens 3 Arten wachsen heute (je Tag höchstens %s)" % str(max_kinds))
	check(bad_vis == 0, "sichtbare Arten je Brett (ohne Wasser) höchstens %s (je Tag höchstens %s)" % [str(Days.VISIBLE_MAX.values()), str(max_vis)])


## Die Lösungen aus dem Python-Modell spielen sich hier genauso (der Abgleich Modell ↔ GDScript).
func test_day_replay() -> void:
	var total := 0
	var bad := 0
	var bad_stars := 0
	for n in range(1, 8):
		var cfg := Days.config(n)
		for i in Days.pool_size(n):
			var b := Days.board(n, i)
			var gs := GameState.new()
			gs.setup_day(cfg, b["kinds"], int(b["seed"]), 0)
			for step in b["solution"]:
				gs.will = {}           # wie im Modell: ohne Antwort gilt Option 1
				var sa := Days.solution_step(step)
				gs.play(sa[0], sa[1])
				if gs.is_over():
					break
			total += 1
			if not (gs.day_won and gs.day_won_at == int(b["solved_in"])):
				bad += 1
				print("  Abweichung: Tag %d Brett %d: gewonnen %s bei %d (Modell %d), %s" % [n, i, str(gs.day_won), gs.day_won_at, int(b["solved_in"]), gs.day_lost])
			elif gs.stars() != int(b["stars"]):
				bad_stars += 1
	check(total == 140 and bad == 0, "Pool-Lösungen gewinnen genau bei solved_in (%d Bretter, %d abweichend)" % [total, bad])
	check(bad_stars == 0, "Sterne wie im Modell")


func test_day_goals() -> void:
	# make: Fortschritt, Gewinn beim Erreichen (auch bei der letzten Drehung)
	var g1 := day_state(1)
	g1.made[MEADOW] = 7
	g1.twists = g1.day_limit - 1
	ready_row(g1, E)
	var r1 := twist(g1, 0, 1, 1)
	check(g1.day_won and not g1.day_lost and g1.day_won_at == g1.day_limit and g1.is_over(), "Ziel bei der letzten erlaubten Drehung erreicht: gewonnen")
	check(_has_event(r1, "goal") and int(_event(r1, "goal")["progress"]) == 8 and _has_event(r1, "day_won"), "Ereignisse goal und day_won")
	check(not (r1["day"] as Dictionary).is_empty() and bool(r1["day"]["won"]) and int(r1["day"]["stars"]) == 1, "Ergebnis trägt den Tag-Stand (%s)" % str(r1["day"]))
	var g1l := day_state(1)
	g1l.twists = g1l.day_limit - 1
	var r1l := twist(g1l, 1, -1, 1)
	check(g1l.day_lost == "twists" and not g1l.day_won and g1l.is_over() and _has_event(r1l, "day_lost"), "keine Drehungen mehr: gescheitert")
	# satt: ein Zustand am Ende der Drehung
	var g4 := day_state(4)
	for sp in [[-1, -1], [1, -1], [-1, 1]]:
		top(g4, int(sp[0]), int(sp[1])).kind = HUT
	top(g4, 0, -1).kind = ANIMALS
	check(g4.goal_progress() == 2 and not g4.goal_met(), "Tag 4: 2 Hütten neben Tieren: 2/3")
	top(g4, 0, 1).kind = ANIMALS
	var r4 := twist(g4, 1, -1, 1)
	check(g4.day_won and g4.goal_progress() == 3 and _has_event(r4, "day_won"), "Tag 4: 3 Hütten satt → gewonnen")
	var st := g4.day_status()
	check(str(st["type"]) == "satt" and (st["needs"] as Array) == ["food"] and (st["need_icons"] as Array) == ["hunger"], "Chip: Bedürfnisse der Ziel-Art (%s)" % str(st["needs"]))
	check((day_state(6).day_status()["needs"] as Array) == ["food", "work", "faith"], "Tag 6: Stadt braucht Nahrung, Arbeit, Glaube")
	# der make-Fortschritt geht nie zurück (Feuer)
	var gb := day_state(3)
	gb.made[ANIMALS] = 2
	var fo := top(gb, 0, 0)
	fo.kind = ANIMALS
	fo.burning = true
	twist(gb, 1, -1, 1)
	check(fo.kind == MEADOW and gb.goal_progress() == 2, "Fallen zieht nichts ab: der Chip geht nie zurück")


func test_day_stars_mercy() -> void:
	var ok := true
	for n in range(1, 8):
		var c := Days.config(n)
		var st: Array = c["stars"]
		if Days.stars_for(c, 3) != 3 or Days.stars_for(c, int(st[0])) != 3 or Days.stars_for(c, int(st[0]) + 1) != 2 \
				or Days.stars_for(c, int(st[1])) != 2 or Days.stars_for(c, int(st[1]) + 1) != 1:
			ok = false
	check(ok, "Sterne aus [a, b]: ★★★ bis a, ★★ bis b, sonst ★")
	var gm := day_state(1, 6)
	check(gm.day_limit == 21 and gm.twists_left() == 21, "Gnade: +6 Drehungen")
	gm.made[MEADOW] = 7
	gm.twists = 17
	ready_row(gm, E)
	twist(gm, 0, 1, 1)
	check(gm.day_won and gm.stars() == 1, "Gnade gibt keine Sterne geschenkt (gewonnen bei 18 von 21: ★)")
	var g: Node = GameScript.new()
	g.save_path = "user://test_rekord.cfg"
	g._load_campaign(null)
	var mercy: Array = []
	for i in 5:
		g.day_fails[2] = i
		mercy.append(g.day_mercy(3))
	check(mercy == [0, 2, 4, 6, 6], "Gnade: +2 je Fehlversuch, höchstens +6 (%s)" % str(mercy))
	g.free()


func test_day_no_hearts() -> void:
	for n in range(1, 8):
		var gs := day_state(n)
		gs.rain = 0
		var fired := false
		for i in 4:
			var r := twist(gs, 1, -1, 1)
			if not _disaster_of(r).is_empty():
				fired = true
		check(not fired and gs.misses == 0 and not gs.hearts and gs.max_lives == 0 and not gs.died() and gs.day_lost == "",
			"Tag %d: kein „3 Fehlversuche → Feuer“, keine Herzen" % n)





func test_day_lcg() -> void:
	var gs := day_state(5)
	check(gs.use_lcg and gs.lcg == 7936, "Tages-Zufall startet mit (seed · 7919 + 17) & 0x7fffffff")
	var seq: Array = [gs._rand(6), gs._rand(5), gs._rand(4)]
	check(seq == [1, 1, 2] and gs.lcg == 1625166559, "Tages-Zufall wie im Python-Modell (%s, %d)" % [str(seq), gs.lcg])
	var b := Days.board(3, 3)
	var a := GameState.new()
	a.setup_day(Days.config(3), b["kinds"], int(b["seed"]), 0)
	var c := a.clone()
	check(c.lcg == a.lcg and c.use_lcg, "clone() kopiert den Tages-Zufall")
	var same := true
	var warns := 0
	for step in (b["solution"] as Array):
		var sa := Days.solution_step(step)
		var ra := a.play(sa[0], sa[1])
		c.play(sa[0], sa[1])
		warns += _count_events(ra, "bolt_warn")
		if a.bolt != c.bolt or a.lcg != c.lcg or sig(a) != sig(c):
			same = false
	check(same and warns > 0, "gleicher Seed und gleiche Züge: gleiche Blitze (%d Warnungen)" % warns)
	var fp := empty_state()
	check(not fp.use_lcg, "freies Spiel: normaler Zufall (rng)")


func test_day_toggles() -> void:
	var g1 := day_state(1)
	check(not g1.hearts and not g1.diagonals and not g1.easy and not g1.sys_regrow and not g1.sys_bolts and not g1.sys_monsoon
		and not g1.sys_flood and g1.complete_goal() == 0, "Tage: keine Herzen, Diagonalen, Gruppen, Nachwachsen, Blitz-Werkzeug, Monsun, Flut-Werkzeug, Vollendet")
	check(not g1.tool_unlocked("rain") and not g1.tool_unlocked("strike") and not g1.tool_unlocked("bolt") and not g1.tool_unlocked("flood"), "Tag 1: keine Werkzeuge")
	var g2 := day_state(2)
	check(g2.tool_unlocked("rain") and g2.rain == 1 and g2.rain_every == 6, "Tag 2: Regen (1 am Start, +1 alle 6 Drehungen)")
	check(g2.can_bonus("rain", top(g2, 0, 0)) != "", "Tag 2: Regen nicht auf Wasser")
	top(g2, 0, 0).kind = FOREST
	check(g2.can_bonus("rain", top(g2, 0, 0)) != "" and g2.rain_grows(E) and g2.rain_grows(MEADOW), "Tag 2: Regen nicht auf Wald, aber auf Erde und Wiese")
	top(g2, 0, 0).kind = E
	g2.play({"type": "rain", "field": top(g2, 0, 0).id})
	check(top(g2, 0, 0).kind == MEADOW and g2.rain == 0 and int(g2.made[MEADOW]) == 1, "Tag 2: Regen auf Erde → Wiese")
	top(g2, 0, 0).kind = WATER
	var got: Array = []
	for t in 12:
		var rb := g2.rain
		twist(g2, 1, -1, 1)
		if g2.rain > rb:
			got.append(g2.twists)
	check(got == [6, 12], "Tag 2: Regen bei Drehung 6 und 12 (%s)" % str(got))
	var g3 := day_state(3)
	g3.rain = 0
	top(g3, 0, 0).kind = MEADOW
	var rg := twist(g3, 1, -1, 1)
	check(not _has_event(rg, "gift") and g3.rain == 0, "neue Tage: kein Regen-Geschenk")
	var g3r := day_state(3)
	top(g3r, 0, 0).kind = E
	top(g3r, 1, 0).kind = MEADOW
	check(g3r.can_bonus("rain", top(g3r, 0, 0)) != "" and g3r.can_bonus("rain", top(g3r, 1, 0)) == "", "Tag 3: Regen auf Wiese (Wald), nicht auf Erde")
	var g5 := day_state(5)
	top(g5, 0, 0).kind = HUT
	var wz := top(g5, 1, 0)
	wz.kind = MEADOW
	g5.play({"type": "rain", "field": wz.id})
	check(wz.kind == FIELD and int(g5.made[FIELD]) == 1, "Tag 5: Regen auf eine Wiese neben Menschen → Acker")
	var g6 := day_state(6)
	check(g6.tool_unlocked("strike") and g6.can_bonus("strike", top(g6, 0, 0)) != "", "Tag 6: Meteor da, aber erst mit 12 Glauben")
	top(g6, 0, 0).kind = CHURCH
	top(g6, 1, 0).kind = HUT
	top(g6, -1, 0).kind = VILLAGE
	var r6 := twist(g6, 1, -1, 1)
	check(int(r6["income"]) == 2 * GameState.FAITH_STEP and g6.faith == 2 * GameState.FAITH_STEP,
		"Tag 6: +%d Glaube je Menschen-Feld, das neu neben einer Kirche steht (%d)" % [GameState.FAITH_STEP, g6.faith])
	var r6b := twist(g6, 1, -1, -1)
	var r6c := twist(g6, 1, -1, 1)
	check(int(r6b["income"]) == 0 and int(r6c["income"]) == 0 and g6.faith == 2 * GameState.FAITH_STEP,
		"Tag 6: hin und her bringt keinen Glauben mehr (dieselbe Stufe zahlt nur einmal)")
	# Meteor-Farmen: auf keinem Tag-6-Brett reicht eine Scheibe hin und her in 6 Drehungen für einen Meteor
	var farm_meteor := 0
	for i in Days.pool_size(6):
		var b6 := Days.board(6, i)
		for m in GameState.MOVES:
			var gf := GameState.new()
			gf.setup_day(Days.config(6), b6["kinds"], int(b6["seed"]), 0)
			for t in 6:
				var tt: int = int(m[2]) if t % 2 == 0 else (-int(m[2]) if absi(int(m[2])) == 1 else 2)
				twist(gf, int(m[0]), int(m[1]), tt)
				if gf.is_over():
					break
			if gf.faith >= GameState.METEOR_COST:
				farm_meteor += 1
	check(farm_meteor == 0, "Tag 6: hin und her erspielt in 6 Drehungen keinen Meteor (%d Fälle)" % farm_meteor)
	var g5i := day_state(5)
	top(g5i, 0, 0).kind = CHURCH
	top(g5i, 1, 0).kind = HUT
	check(int(twist(g5i, 1, -1, 1)["income"]) == 0, "Tag 5: noch kein Glaube")


func test_day_tutorial() -> void:
	var b := Days.board(1, 0)
	var gs := GameState.new()
	gs.setup_day(Days.config(1), b["kinds"], int(b["seed"]), 0)
	check(gs.lines().is_empty() and gs.goal_progress() == 0, "Tag 1, Brett 0: keine fertige Reihe")
	var mv: Dictionary = Days.config(1)["tutorial"]
	var r := gs.play({"type": "twist", "axis": int(mv["axis"]), "layer": int(mv["layer"]), "turns": int(mv["turns"])})
	check(gs.goal_progress() >= 1 and _has_event(r, "goal") and gs.count(MEADOW) >= 1, "Tag 1, Brett 0: die vorgeführte Drehung (x = 1) lässt eine Wiese wachsen (%d)" % gs.goal_progress())
	check(gs.day_status()["progress"] == gs.goal_progress() and int(gs.day_status()["left"]) == 14, "Chip: 1/8, noch 14 Drehungen")


func test_day_save() -> void:
	var path := "user://test_rekord.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var g: Node = GameScript.new()
	g.save_path = path
	g.reminder_echo = false
	g.clock_override = lt(2026, 11, 9, 10, 0)
	g._load_best()
	check(g.first_launch and g.day_free == 1 and g.stars_total() == 0 and not g.world_done and g.current_day() == 1, "neues Profil: Tag 1, keine Sterne, erster Start")
	check(not g.start_day(2) and g.start_day(1) and g.in_day() and g.day_no == 1 and int(g.day_board["index"]) == 0, "nur Tag 1 ist frei; erster Besuch: Brett 0")
	check(g.day_tutorial() and int(g.tutorial_move().get("layer", 0)) == 1 and g.hint_free(), "Tag 1 Brett 0 ist das Tutorial; Tipp gratis")
	var won: Array = []
	var lost: Array = []
	g.day_won.connect(func(info): won.append(info))
	g.day_lost.connect(func(info): lost.append(info))
	_replay_in_game(g)
	check(won.size() == 1 and g.over and int(won[0]["stars"]) >= 1 and int(won[0]["next_day"]) == 2, "Tag 1 gewonnen: Signal mit Sternen und nächstem Tag (%s)" % str(won))
	check(g.day_free == 1 and not g.day_unlocked(2) and g.new_day_tomorrow() and bool(won[0]["next_locked"]) and g.stars_of(1) == int(won[0]["stars"]) and int(g.day_next_board[0]) == 1 and int(g.day_best[0]) > 0,
		"nach dem Sieg: Tag 2 erst morgen, Sterne und Brett gemerkt")
	check(not g.can_undo(), "ein beendeter Tag lässt sich nicht zurücknehmen")
	check(not g.next_day(), "Weiter zu Tag 2 geht erst morgen")
	g.clock_override += 86400
	check(g.day_free == 2 and g.day_unlocked(2), "am nächsten Spieltag: Tag 2 frei")
	# Scheitern: Gnade und nächstes Brett
	var nights: Array = []
	g.overnight_growth.connect(func(info): nights.append(info))
	check(g.next_day() and g.day_no == 2 and g.state.day_limit == 14, "Weiter zu Tag 2")
	check(nights.size() == 1 and str(nights[0]["type"]) == "overnight" and not (nights[0]["changes"] as Array).is_empty()
		and str(nights[0]["line"]) == "Erde wird Wiese" and not (g.day_info()["overnight"] as Dictionary).is_empty(),
		"Tag 2 startet mit „Neuer Morgen“ (overnight-Ereignis, %d Felder)" % ((nights[0]["changes"] as Array).size() if not nights.is_empty() else 0))
	g.state.twists = g.state.day_limit - 1
	g.state.rain = 0
	var res: Dictionary = g.state.play({"type": "twist", "axis": 1, "layer": 1, "turns": 2}, {})
	g.finish_round(res)
	check(lost.size() == 1 and str(lost[0]["why"]) == "twists" and int(lost[0]["mercy_next"]) == 2 and int(g.day_fails[1]) == 1, "Tag 2 gescheitert: +2 Drehungen beim nächsten Versuch (%s)" % str(lost))
	check(g.retry_day() and g.state.day_limit == 16 and int(g.day_board["index"]) == 1, "Nochmal: nächstes Brett, 16 Drehungen")
	check(nights.size() == 1 and (g.day_info()["overnight"] as Dictionary).is_empty(), "„Nochmal“: kein „Neuer Morgen“")
	_replay_in_game(g)
	check(won.size() == 2 and int(g.day_fails[1]) == 0 and g.next_new_day() == 3 and not g.day_unlocked(3), "Sieg setzt die Gnade zurück, Tag 3 erst morgen")
	# Rundreise: speichern → laden
	var g2: Node = GameScript.new()
	g2.save_path = path
	g2.reminder_echo = false
	g2.clock_override = g.clock_override
	g2._load_best()
	check(not g2.first_launch and g2.day_free == 2 and g2.day_stars == g.day_stars and g2.day_best == g.day_best
		and g2.day_next_board == g.day_next_board and g2.day_fails == g.day_fails and g2.current_day() == 2 and g2.daily["won_key"] == g.daily["won_key"]
		and int(g2.daily["streak"]) == 2, "Fortschritt: speichern und laden (%s)" % str(g2.day_stars))
	g2.clock_override += 86400
	check(g2.current_day() == 3, "am nächsten Spieltag geht es mit Tag 3 weiter")
	# Nach Tag 7: Welt vollendet, freies Spiel offen
	g2.debug_open_all = true
	g2.tutorial_done = false
	check(not g2.free_play_unlocked() and g2.start_day(7, 0), "Tag 7 frei (Test), freies Spiel noch zu")
	var won2: Array = []
	g2.day_won.connect(func(info): won2.append(info))
	_replay_in_game(g2)
	check(won2.size() == 1 and bool(won2[0]["world_complete"]) and g2.world_done and g2.free_play_unlocked() and int(won2[0]["next_day"]) == 0,
		"nach Tag 7: „Deine Welt ist vollendet!“, freies Spiel offen")
	g2.start_mode("mittel")
	check(not g2.in_day() and not g2.state.is_day() and g2.state.hearts and g2.state.is_choice(ANIMALS), "Freies Spiel: Herzen, alle Karten")
	# Ein Zug über Game (wie die World) behält die Regeln des Tages (Tag 1: kein Feuer)
	var g3: Node = GameScript.new()
	g3.save_path = path
	g3.reminder_echo = false
	g3._load_campaign(null)
	g3.start_day(1)
	var res3: Array = []
	g3.round_resolved.connect(func(result, before): res3.append(result))
	g3.play_turn(1, -1, 1)
	check(res3.size() == 1 and g3.state.no_fire and g3.state.twists == 1, "Game.play_turn an Tag 1: Feuer bleibt aus")
	# Erster Zug daneben: Die vorgeführte Drehung bringt nichts mehr → Hand und Leuchten zeigen eine, die wächst
	var orig: Dictionary = Days.config(1)["tutorial"]
	var tm: Dictionary = g3.tutorial_move()
	var tm_ok: bool = not tm.is_empty() and g3._twist_grows(int(tm["axis"]), int(tm["layer"]), int(tm["turns"]))
	check(not g3._twist_grows(int(orig["axis"]), int(orig["layer"]), int(orig["turns"])) and tm_ok,
		"Tutorial: Bringt der gezeigte Zug nichts mehr, zeigt die Hand einen, der eine Wiese wachsen lässt (%s)" % str(tm))
	g3.finish_round(res3[0])
	# Bretter: nach jedem Versuch eins weiter; ein ausdrücklich gewähltes Brett (Tutorial nochmal) spult nie zurück
	_lose_day(g3)
	var nb1 := int(g3.day_next_board[0])
	g3.day_next_board[0] = 7
	g3.start_day(1, 0)
	_lose_day(g3)
	var nb2 := int(g3.day_next_board[0])
	g3.start_day(1)
	var bi := int(g3.day_board["index"])
	_lose_day(g3)
	check(nb1 == 1 and nb2 == 7 and bi == 7 and int(g3.day_next_board[0]) == 8, "Bretter: weiter nach jedem Versuch, Tutorial nochmal spult nicht zurück (%d %d %d %d)" % [nb1, nb2, bi, int(g3.day_next_board[0])])
	g.free()
	g2.free()
	g3.free()
	DirAccess.remove_absolute(path)


## Den laufenden Tag mit der letzten Drehung verlieren (keine Drehungen mehr).
func _lose_day(g: Node) -> void:
	var gs: GameState = g.state
	gs.twists = gs.day_limit - 1
	gs.rain = 0
	var res: Dictionary = gs.play({"type": "twist", "axis": 1, "layer": 1, "turns": 2}, {})
	g.finish_round(res)


## Spielt die Pool-Lösung des laufenden Bretts im Autoload Game (mit finish_round wie die World).
func _replay_in_game(g: Node) -> void:
	for step in g.day_board["solution"]:
		if g.over:
			break
		var gs: GameState = g.state
		gs.will = {}
		var sa := Days.solution_step(step)
		var res: Dictionary = gs.play(sa[0], sa[1])
		g.finish_round(res)


## Tipp (best_action) an den Tagen: Bretter 0–2 jedes Tages gewinnt er sicher; auf 10 Brettern je Tag die Quote.
## Dazu der „schwache“ Bot (halb zufällig): soll deutlich schlechter sein. Grenzen locker nach der Spec (8.1).
func test_day_hint() -> void:
	var gs := day_state(2)
	top(gs, -1, 1).kind = MEADOW
	top(gs, 0, 1).kind = MEADOW
	top(gs, 1, 0).kind = MEADOW
	var b := gs.best_move()
	check(not b.is_empty() and str(b["type"]) == "twist", "Tipp an einem Tag: immer eine Drehung (best_move)")
	var ba := gs.best_action()
	check(not ba.is_empty() and ["twist", "rain", "strike"].has(str(ba["type"])), "best_action: Drehung, Regen oder Gewitter (%s)" % str(ba.get("type", "")))


func _play_good(n: int, i: int) -> GameState:
	var b := Days.board(n, i)
	var gs := GameState.new()
	gs.setup_day(Days.config(n), b["kinds"], int(b["seed"]), 0)
	var guard := 0
	while not gs.is_over() and guard < 60:
		guard += 1
		var a := gs.best_action()
		if a.is_empty():
			break
		var ans := {}
		if int(a["card"]) >= 0:
			ans[int(a["card"])] = int(a["choice"])
		gs.play(a, ans)
	return gs


func _play_weak(n: int, i: int, rng: RandomNumberGenerator) -> GameState:
	var b := Days.board(n, i)
	var gs := GameState.new()
	gs.setup_day(Days.config(n), b["kinds"], int(b["seed"]), 0)
	var guard := 0
	while not gs.is_over() and guard < 60:
		guard += 1
		if gs.rain > 0 and rng.randf() < 0.25:
			var spots: Array = []
			for f in gs.fields:
				if gs.rain_ok(f):
					spots.append(f.id)
			if not spots.is_empty():
				gs.play({"type": "rain", "field": int(spots[rng.randi_range(0, spots.size() - 1)])}, {})
				if gs.is_over():
					break
		var grow: Array = []
		for m in GameState.MOVES:
			var s := gs.clone()
			s.apply_rotation(int(m[0]), int(m[1]), int(m[2]))
			for ln in s.lines(s.moved):
				if s.counts(ln):
					grow.append(m)
					break
		var mv: Array = grow[rng.randi_range(0, grow.size() - 1)] if not grow.is_empty() and rng.randf() < 0.5 else GameState.MOVES[rng.randi_range(0, 26)]
		var act := {"type": "twist", "axis": int(mv[0]), "layer": int(mv[1]), "turns": int(mv[2])}
		var info := gs.choice_for(act)
		var ans := {}
		if not info.is_empty() and rng.randf() < 0.5:
			ans[int(info["kind"])] = 1
		gs.play(act, ans)
	return gs


func test_day_bots() -> void:
	var t0 := Time.get_ticks_msec()
	var boards := 6
	var low := {1: 0.9, 2: 0.9, 3: 0.8, 4: 0.8, 5: 0.6, 6: 0.6, 7: 0.6}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var first3 := true
	for n in range(1, 8):
		var won := 0
		var stars := [0, 0, 0, 0]
		var tw: Array = []
		for i in boards:
			var g := _play_good(n, i)
			if g.day_won:
				won += 1
				tw.append(g.day_won_at)
			elif i < 3 and n <= 4:
				first3 = false
			stars[g.stars()] += 1
		var weak := 0
		for i in boards:
			if _play_weak(n, i, rng).day_won:
				weak += 1
		tw.sort()
		var rate := float(won) / float(boards)
		print("  Tag %d: Tipp gewinnt %d/%d (Drehungen %s, Sterne ★★★/★★/★ %d/%d/%d), schwacher Bot %d/%d" % [n, won, boards, str(tw),
			stars[3], stars[2], stars[1], weak, boards])
		check(rate >= float(low[n]), "Tag %d: der Tipp löst mindestens %.0f %% (%.0f %%)" % [n, float(low[n]) * 100.0, rate * 100.0])
		check(weak <= won, "Tag %d: der schwache Bot ist nicht besser als der Tipp (%d/%d)" % [n, weak, won])
		check(tw.is_empty() or int(tw[0]) >= 3, "Tag %d: nie in weniger als 3 Drehungen gelöst" % n)
	check(first3, "Tipp gewinnt die Bretter 0–2 der Tage 1–4")
	print("  (Tage-Bots: %d ms)" % (Time.get_ticks_msec() - t0))


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
		(f as FieldData).kind = WATER
	for i in 40:
		twist(gp, 1, -1, 1)
		if gp.is_over():
			break
	check(gp.faith == 0, "Nichtstun bringt keinen Glauben")


# =============================================================================
# Täglich spielen (docs/GDPD_TAEGLICH_CHARAKTER.md 8.1): Spieltag, Freischalten nach Datum, Migration, Serie,
# Serienschutz, Uhr, Welt des Tages, Weiterbauen, Erinnerungs-Plan, Texte, Test-Knopf
# =============================================================================

func _daily_tests() -> void:
	test_daily_keys()
	test_daily_unlock()
	test_daily_migration()
	test_daily_streak()
	test_daily_shields()
	test_daily_clock()
	test_daily_week()
	test_daily_world()
	test_daily_world_game()
	test_daily_build()
	test_reminder_plan()
	test_reminder_templates()
	test_daily_debug()
	test_voice_and_ask()
	test_short_texts()


## Ortszeit (lokale Unix-Sekunden).
func lt(y: int, m: int, d: int, h: int = 12, mi: int = 0) -> int:
	return Daily.local_unix(y, m, d, h, mi)


## Ein Game-Knoten mit eigener Spielstand-Datei und fester Uhr (frisches Profil, wenn fresh).
func _daily_game(path: String, now: int, fresh: bool = true) -> Node:
	if fresh and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var g: Node = GameScript.new()
	g.save_path = path
	g.reminder_echo = false
	g.clock_override = now
	g._load_best()
	return g


## Den laufenden Tag (oder die Welt des Tages) mit der Pool-Lösung gewinnen; true = gewonnen.
func _win_in_game(g: Node) -> bool:
	_replay_in_game(g)
	return (g.state as GameState).day_won


func test_daily_keys() -> void:
	var k9 := Daily.day_key(lt(2026, 11, 9, 12))
	check(Daily.day_key(lt(2026, 11, 10, 2, 59)) == k9 and Daily.day_key(lt(2026, 11, 10, 3, 0)) == k9 + 1,
		"Spieltag: 2:59 gehört zum Vortag, 3:00 zum neuen Tag")
	check(Daily.day_key(lt(2026, 11, 9, 0, 10)) == k9 - 1 and Daily.day_key(lt(2026, 11, 8, 23, 50)) == k9 - 1,
		"Spieltag: um Mitternacht bleibt der Tag (23:50 und 0:10 sind derselbe Spieltag)")
	check(Daily.next_boundary(lt(2026, 11, 9, 12)) == lt(2026, 11, 10, 3) and Daily.next_boundary(lt(2026, 11, 10, 1)) == lt(2026, 11, 10, 3),
		"nächster Tageswechsel: das nächste 3 Uhr")
	check(Daily.weekday(k9) == 0 and Daily.weekday_name(k9) == "Montag" and Daily.weekday(k9 + 4) == 4 and Daily.weekday(k9 - 1) == 6,
		"Wochentag: 9.11.2026 ist ein Montag (0), Freitag 4, Sonntag 6")
	check(Daily.countdown_text(lt(2026, 11, 9, 12, 40)) == "Neuer Tag in 14 Std. 20 Min." and Daily.countdown_text(lt(2026, 11, 9, 19, 1)) == "Morgen früh"
		and Daily.countdown_text(lt(2026, 11, 10, 1)) == "Morgen früh", "Countdown: genau bis 8 h vorher, dann „Morgen früh“ (%s)" % Daily.countdown_text(lt(2026, 11, 9, 12, 40)))
	check(Daily.minute_of_day(lt(2026, 11, 9, 18, 10)) == 1090, "Minute des Tages")


func test_daily_unlock() -> void:
	# rein: Sterne + Tageszustand
	var t0 := lt(2026, 11, 9, 10)
	var d := Daily.fresh(t0)
	var k := Daily.day_key(t0)
	var st: Array = [0, 0, 0, 0, 0, 0, 0]
	check(Daily.day_unlocked(d, st, 1, k) and not Daily.day_unlocked(d, st, 2, k) and Daily.new_day_open(d, st, k), "neu: nur Tag 1 offen")
	st[0] = 2
	Daily.register_first_win(d, 1, k)
	check(not Daily.day_unlocked(d, st, 2, k) and Daily.new_day_tomorrow(d, st, k) and Daily.day_unlocked(d, st, 1, k), "Tag 1 an K geschafft: Tag 2 erst morgen, Tag 1 wiederholbar")
	check(Daily.day_unlocked(d, st, 2, k + 1) and Daily.day_unlocked(d, st, 2, k + 5) and not Daily.day_unlocked(d, st, 3, k + 5) and Daily.day_free(d, st, k + 5) == 2,
		"Tag 2 offen ab K+1 und auch an K+5 der einzige neue Tag (nichts stapelt sich)")
	st[1] = 1
	Daily.register_first_win(d, 2, k + 5)
	check(not Daily.day_unlocked(d, st, 3, k + 5) and Daily.day_unlocked(d, st, 3, k + 6) and Daily.day_unlocked(d, st, 1, k + 5) and Daily.day_unlocked(d, st, 2, k + 5),
		"Tag 3 nie am Spieltag des ersten Siegs von Tag 2; Wiederholungen immer offen")
	# im Autoload Game: Sieg, dann am selben Spieltag gesperrt, am nächsten offen
	var path := "user://test_taeglich.cfg"
	var g := _daily_game(path, lt(2026, 11, 9, 18, 10))
	g.session_start = lt(2026, 11, 9, 18, 0)
	check(g.start_day(1) and _win_in_game(g), "Game: Tag 1 gewonnen")
	var ti: Dictionary = g.today_info()
	check(not g.start_day(2) and g.start_day(1) and str(ti["state"]) == "done_next" and str(ti["line"]) == "Morgen geht's weiter: Tag 2 · Pflanzen"
		and g.locked_text(2) == "Morgen geht's weiter: Tag 2 · Pflanzen" and g.locked_text(3) == "Ab Mittwoch." and g.locked_text(4) == "Ab Donnerstag."
		and g.current_day() == 1 and str(ti["caps"]) == "Heute" and str(ti["title"]) == "Geschafft!",
		"Game: Tag 2 morgen, Heute-Karte „Geschafft!“ mit der Morgen-Zeile, Tag 3 „Ab Mittwoch.“ (%s | %s)" % [str(ti.get("line", "")), g.locked_text(3)])
	g.clock_override = lt(2026, 11, 10, 2, 30)
	check(not g.day_unlocked(2), "Game: um 2:30 ist noch derselbe Spieltag")
	g.clock_override = lt(2026, 11, 10, 3, 0)
	var ti2: Dictionary = g.today_info()
	check(g.day_unlocked(2) and str(ti2["state"]) == "new" and int(ti2["day"]) == 2 and str(ti2["title"]) == "Tag 2 · Pflanzen" and g.current_day() == 2,
		"Game: ab 3:00 ist Tag 2 offen („Heute neu“)")
	g.free()
	DirAccess.remove_absolute(path)


func test_daily_migration() -> void:
	var path := "user://test_taeglich_v1.cfg"
	var cfg := ConfigFile.new()
	cfg.set_value("konto", "credits", 4)
	cfg.set_value("schoepfung", "sterne", [3, 2, 0, 0, 0, 0, 0])
	cfg.set_value("schoepfung", "beste", [5, 9, 0, 0, 0, 0, 0])
	cfg.set_value("schoepfung", "frei", 3)
	cfg.set_value("schoepfung", "fehlversuche", [0, 0, 1, 0, 0, 0, 0])
	cfg.set_value("schoepfung", "brett", [1, 1, 1, 0, 0, 0, 0])
	cfg.set_value("schoepfung", "fertig", false)
	cfg.set_value("schoepfung", "version", 1)
	cfg.set_value("anderes", "wert", 7)
	cfg.save(path)
	var g := _daily_game(path, lt(2026, 11, 12, 9), false)
	check(g.day_unlocked(1) and g.day_unlocked(2) and g.day_unlocked(3) and not g.day_unlocked(4) and g.current_day() == 3
		and int(g.daily["streak"]) == 0 and int(g.daily["shields"]) == 0 and g.daily["won_key"] == [-1, -1, -1, -1, -1, -1, -1] and int(g.daily["last_new_key"]) == -1,
		"Migration v1: Tage 1–2 wiederholbar, Tag 3 heute offen, Serie 0")
	g._save_profile()
	var c2 := ConfigFile.new()
	c2.load(path)
	check(int(c2.get_value("schoepfung", "version", 0)) == 2 and c2.has_section("taeglich") and c2.has_section("erinnerung")
		and int(c2.get_value("anderes", "wert", 0)) == 7, "Migration: Version 2, [taeglich] und [erinnerung] gespeichert, andere Abschnitte bleiben")
	g.free()
	# vollendete Welt: heute schon die Welt des Tages
	var c3 := ConfigFile.new()
	c3.set_value("schoepfung", "sterne", [3, 3, 2, 2, 1, 1, 1])
	c3.set_value("schoepfung", "frei", 8)
	c3.set_value("schoepfung", "fertig", true)
	c3.save(path)
	var g3 := _daily_game(path, lt(2026, 11, 12, 9), false)
	check(g3.world_done and g3.daily_world_available() and str(g3.today_info()["state"]) == "wdt" and g3.start_daily_world() and g3.in_daily_world(),
		"Migration: vollendete Welt → heute die Welt des Tages")
	g3.free()
	DirAccess.remove_absolute(path)


func test_daily_streak() -> void:
	var t := lt(2026, 11, 9, 18)
	var d := Daily.fresh(t)
	var k := Daily.day_key(t)
	var w1 := Daily.win(d, k, 1080)
	var w1b := Daily.win(d, k, 1100)
	var w2 := Daily.win(d, k + 1)
	var w3 := Daily.win(d, k + 2)
	check(bool(w1["counted"]) and int(w1["streak"]) == 1 and not bool(w1b["counted"]) and int(w2["streak"]) == 2 and int(w3["streak"]) == 3
		and int(d["streak"]) == 3 and int(d["streak_best"]) == 3 and int(d["anchor"]) == 1080 and (d["streak_days"] as Array) == [k, k + 1, k + 2],
		"Serie: K, K+1, K+2 → 3; zweiter Sieg am selben Tag zählt nicht")
	check(Daily.day_check(d, k + 3) == "" and int(d["streak"]) == 3 and Daily.day_check(d, k + 4) == "lost" and int(d["streak"]) == 0
		and int(d["streak_best"]) == 3 and Daily.take_comeback(d) == "lost" and str(d["comeback"]) == "", "Serie: ein verpasster Tag ohne Schutz → 0 (Rekord bleibt, Comeback einmal)")
	# Game: eine Wiederholung zählt, ein Fehlversuch nicht
	var path := "user://test_taeglich.cfg"
	var g := _daily_game(path, lt(2026, 11, 9, 18))
	var streaks: Array = []
	g.streak_changed.connect(func(info): streaks.append(info))
	g.start_day(1)
	_win_in_game(g)
	g.clock_override += 86400
	g.start_day(2)
	_lose_day(g)
	check(g.streak() == 1 and not g.done_today(), "Game: ein Fehlversuch zählt nicht für die Serie")
	g.start_day(1)
	_win_in_game(g)
	check(g.streak() == 2 and g.done_today() and streaks.size() == 2 and int(streaks[1]["streak"]) == 2 and g.day_unlocked(2),
		"Game: eine Wiederholung (Tag 1) zählt; der neue Tag bleibt offen")
	g.start_day(2)
	_win_in_game(g)
	check(g.streak() == 2 and streaks.size() == 2 and not g.day_unlocked(3), "Game: der zweite Sieg am selben Tag zählt nicht mehr")
	g.free()
	DirAccess.remove_absolute(path)


func test_daily_shields() -> void:
	var t := lt(2026, 11, 9, 18)
	var k := Daily.day_key(t)
	var d := Daily.fresh(t)
	d["streak"] = 5
	d["streak_last"] = k
	d["shields"] = 1
	check(Daily.day_check(d, k + 2) == "saved" and int(d["streak"]) == 5 and int(d["shields"]) == 0 and (d["shield_days"] as Array) == [k + 1]
		and int(d["streak_last"]) == k + 1, "Schutz: Serie 5, ein Tag verpasst → bleibt, Schutz verbraucht, Schutz-Tag gemerkt")
	check(Daily.day_check(d, k + 2) == "", "Tagesprüfung zweimal: nichts doppelt")
	var d2 := Daily.fresh(t)
	d2["streak"] = 5
	d2["streak_last"] = k
	d2["shields"] = 1
	check(Daily.day_check(d2, k + 3) == "lost" and int(d2["streak"]) == 0 and int(d2["shields"]) == 1, "Schutz: zwei Tage verpasst mit einem Schutz → Serie 0, der Schutz bleibt")
	var d3 := Daily.fresh(t)
	d3["streak"] = 4
	d3["streak_last"] = k
	d3["shields"] = 2
	check(Daily.day_check(d3, k + 3) == "saved" and int(d3["shields"]) == 0 and int(d3["streak"]) == 4 and (d3["shield_days"] as Array) == [k + 1, k + 2],
		"Schutz: zwei Tage, zwei Schutze → gerettet")
	# Meilenstein 7: +1 Schutz; bei vollem Schutz +3 Münzen
	var d4 := Daily.fresh(t)
	d4["streak"] = 6
	d4["streak_last"] = k - 1
	var m := Daily.win(d4, k)
	check(bool(m["milestone"]) and bool(m["big"]) and int(m["shield"]) == 1 and int(d4["shields"]) == 1 and bool(d4["shields_ever"]), "Meilenstein 7: +1 Serienschutz")
	d4["streak"] = 13
	d4["shields"] = 2
	var m2 := Daily.win(d4, k + 1)
	check(int(m2["streak"]) == 14 and int(m2["shield"]) == 0 and int(m2["coins"]) == Balance.SHIELD_FULL_COINS and int(d4["shields"]) == 2, "Meilenstein mit vollem Schutz: +3 Münzen")
	var m3 := Daily.win(d4, k + 2)
	check(not bool(m3["milestone"]) and not bool(m3["big"]), "kein Meilenstein bei 15")
	# Kaufen (Game)
	var path := "user://test_taeglich.cfg"
	var g := _daily_game(path, t)
	g.credits = 4
	var e1: String = g.buy_shield()
	g.credits = 11
	var e2: String = g.buy_shield()
	var e3: String = g.buy_shield()
	var e4: String = g.buy_shield()
	check(e1 == "Dir fehlen 1 Münzen." and e2 == "" and e3 == "" and e4 == "Du hast genug Serienschutz." and g.shields() == 2 and g.credits == 1,
		"Serienschutz kaufen: 5 Münzen, höchstens 2 (%s | %s | %s | %s)" % [e1, e2, e3, e4])
	# Meilenstein im Game: Münzen kommen aufs Konto
	g.daily["streak"] = 13
	g.daily["streak_last"] = g.today_key() - 1
	var c0: int = g.credits
	g.start_day(1)
	_win_in_game(g)
	check(g.streak() == 14 and g.credits == c0 + Balance.SHIELD_FULL_COINS, "Game: Meilenstein 14 mit vollem Schutz → +3 Münzen")
	g.free()
	DirAccess.remove_absolute(path)


func test_daily_clock() -> void:
	var path := "user://test_taeglich.cfg"
	# Sommerzeit-Ende: 3:30 → 2:30 (eine Stunde zurück): derselbe Spieltag, nichts ändert sich
	var g := _daily_game(path, lt(2026, 10, 25, 3, 30))
	var k0: int = g.today_key()
	g.start_day(1)
	_win_in_game(g)
	g.clock_override = lt(2026, 10, 25, 2, 30)
	check(g.today_key() == k0 and not g.day_unlocked(2) and g.done_today() and int(g.daily["last_seen"]) == lt(2026, 10, 25, 3, 30),
		"Uhr 1 h zurück (Sommerzeit): derselbe Spieltag, nichts entsperrt, last_seen bleibt")
	# 3 Tage zurück: der Spieltag bleibt (Spielzeit = Systemzeit + 3 Tage); nichts wird umgeschrieben, nichts entsperrt
	g.clock_override = lt(2026, 10, 22, 12)
	var k1: int = g.today_key()
	check(k1 == k0 and g.streak() == 1 and g.done_today() and not g.day_unlocked(2) and int(g.daily["last_new_key"]) == k0
		and (g.daily["streak_days"] as Array) == [k0] and int(g.daily["clock_off"]) == 3, "Uhr 3 Tage zurück: derselbe Spieltag, Serie bleibt, heute nichts entsperrt")
	g.clock_override = lt(2026, 10, 23, 12)
	check(g.day_unlocked(2) and g.streak() == 1 and not g.done_today() and g.today_key() == k0 + 1, "falsche Uhr: am nächsten Morgen geht es normal weiter")
	g.start_day(2)
	_win_in_game(g)
	# Uhr wieder richtig: der Versatz geht weg, kein Tag gilt als verpasst, nichts öffnet
	g.clock_override = lt(2026, 10, 26, 13)
	check(g.today_key() == k0 + 1 and int(g.daily["clock_off"]) == 0 and g.streak() == 2 and str(g.daily["comeback"]) == "" and g.shields() == 0
		and not g.day_unlocked(3), "Uhr wieder richtig: derselbe Spieltag, Serie 2, nichts entsperrt")
	# Uhr vor: genau ein neuer Tag
	g.clock_override = lt(2026, 10, 27, 12)
	check(g.day_unlocked(3) and not g.day_unlocked(4) and g.streak() == 2, "Uhr einen Tag vor: der nächste Tag öffnet genau einmal")
	g.clock_override = lt(2026, 11, 2, 12)
	check(g.day_unlocked(3) and not g.day_unlocked(4) and g.streak() == 0 and str(g.daily["comeback"]) == "lost", "Uhr weit vor: ein neuer Tag, Serie vorbei (kein Schutz)")
	g.free()
	DirAccess.remove_absolute(path)
	# Umgehen: Tag 3 heute geschafft, Uhr 2 Tage zurück, App öffnen, Uhr richtig → Tag 4 bleibt zu
	var t := lt(2026, 11, 10, 12)
	g = _daily_game(path, t)
	for n in 3:
		g.clock_override = t + (n - 2) * Daily.DAY
		g.start_day(n + 1)
		_win_in_game(g)
	var kt: int = g.today_key()
	check(not g.day_unlocked(4) and g.streak() == 3, "Umgehen: nach Tag 3 heute ist Tag 4 zu")
	g.clock_override = t - 2 * Daily.DAY
	var kb: int = g.today_key()
	g.clock_override = t + 600
	check(kb == kt and g.today_key() == kt and not g.day_unlocked(4) and g.streak() == 3 and g.shields() == 0 and str(g.daily["comeback"]) == "",
		"Uhr 2 Tage zurück und wieder richtig: Tag 4 bleibt zu, Serie 3, kein Schutz verbraucht")
	for i in 3:
		g.clock_override = t - 2 * Daily.DAY + i
		g.today_key()
		g.clock_override = t + 700 + i
		g.today_key()
	check(not g.day_unlocked(4) and g.today_key() == kt, "Umgehen mehrmals hintereinander: Tag 4 bleibt zu")
	# 30 Tage zurück und wieder richtig; 1970 und wieder richtig: Serie bleibt, kein Schutz
	g.daily["shields"] = 1
	g.clock_override = t - 30 * Daily.DAY
	var k30: int = g.today_key()
	g.clock_override = t + 900
	check(k30 == kt and g.today_key() == kt and g.streak() == 3 and g.shields() == 1 and str(g.daily["comeback"]) == "", "Uhr 30 Tage zurück und richtig: Serie 3, Schutz bleibt")
	g.clock_override = Daily.local_unix(1970, 1, 1, 0, 5)
	var k70: int = g.today_key()
	g.clock_override = t + 1000
	check(k70 == kt and g.today_key() == kt and g.streak() == 3 and g.shields() == 1 and not g.day_unlocked(4), "Uhr auf 1970 und richtig: Serie 3, nichts entsperrt")
	g.clock_override = t + Daily.DAY
	check(g.day_unlocked(4) and g.streak() == 3, "danach am nächsten echten Tag: Tag 4 offen")
	# Vor und zurück: +1 Tag, +2 Tage, dann zurück zur echten Zeit → der Spieltag bleibt (nie rückwärts, nichts doppelt)
	g.clock_override = t + 3 * Daily.DAY
	var kf: int = g.today_key()
	g.clock_override = t + Daily.DAY + 3600
	check(g.today_key() == kf and int(g.daily["clock_off"]) == 2 and int(g.daily["last_new_key"]) <= kf, "vor und wieder zurück: der Spieltag bleibt stehen")
	g.clock_override = t + 2 * Daily.DAY + 3600
	check(g.today_key() == kf + 1, "danach läuft die Spielzeit in Echtzeit weiter")
	g.free()
	DirAccess.remove_absolute(path)
	# rein: Zurückstellen unter 36 h bleibt stehen, ab 36 h bleibt der Tag auch (Versatz), richtig = Versatz weg
	var d := Daily.fresh(lt(2026, 11, 10, 12))
	var kk := Daily.day_key(lt(2026, 11, 10, 12))
	check(Daily.observe(d, lt(2026, 11, 9, 1)) == kk and Daily.observe(d, lt(2026, 11, 8, 23, 59)) == kk and int(d["clock_off"]) == 2
		and Daily.game_time(d, lt(2026, 11, 8, 23, 59)) == lt(2026, 11, 10, 23, 59), "Uhr-Regel: < 36 h zurück bleibt der Tag, ≥ 36 h Versatz 2 Tage")
	check(Daily.observe(d, lt(2026, 11, 10, 12, 30)) == kk and int(d["clock_off"]) == 0, "Uhr-Regel: wieder richtig → Versatz 0, derselbe Tag")
	var cfg := ConfigFile.new()
	d["clock_off"] = 4
	d["sys_seen"] = lt(2026, 11, 6, 12)
	Daily.save(d, cfg)
	var d2 := Daily.load_from(cfg, lt(2026, 11, 6, 13))
	check(int(d2["clock_off"]) == 4 and int(d2["sys_seen"]) == lt(2026, 11, 6, 12), "Uhr-Versatz wird gespeichert")
	# Sieg kurz nach 3 Uhr: zählt für den Spieltag, an dem der Versuch kurz vorher begann
	var tg := lt(2026, 11, 11, 2, 50)
	g = _daily_game(path, tg - Daily.DAY)
	g.start_day(1)
	_win_in_game(g)
	var kd: int = g.today_key() + 1
	g.clock_override = tg
	g.start_day(2)
	g.clock_override = lt(2026, 11, 11, 3, 5)
	check(g.streak() == 1 and str(g.daily["comeback"]) == "", "Versuch über 3 Uhr: die Tagesprüfung wartet")
	_win_in_game(g)
	check(g.streak() == 2 and int(g.daily["streak_last"]) == kd and int((g.daily["won_key"] as Array)[1]) == kd and g.today_key() == kd + 1
		and g.day_unlocked(3) and str(g.daily["comeback"]) == "", "Sieg um 3:05 (Start 2:50): zählt für den alten Spieltag, Serie 2, Tag 3 gleich offen")
	g.free()
	DirAccess.remove_absolute(path)


func test_daily_week() -> void:
	var t := lt(2026, 11, 12, 18)     # Donnerstag
	var k := Daily.day_key(t)
	var d := Daily.fresh(t)
	d["first_key"] = k - 3            # Montag
	d["streak_days"] = [k - 3, k - 1]
	d["shield_days"] = [k - 2]
	var w := Daily.week(d, k)
	var states: Array = []
	for e in w:
		states.append(str((e as Dictionary)["state"]))
	check(w.size() == 7 and str((w[0] as Dictionary)["short"]) == "Mo" and states == ["streak", "shield", "streak", "today", "future", "future", "future"],
		"Wochenreihe Mo–So: Flamme, Schutz, Flamme, heute, Zukunft (%s)" % str(states))
	d["first_key"] = k - 1
	d["streak_days"] = [k - 1, k]
	d["shield_days"] = []
	states = []
	for e in Daily.week(d, k):
		states.append(str((e as Dictionary)["state"]))
	check(states == ["none", "none", "streak", "streak", "future", "future", "future"], "Wochenreihe: Tage vor dem ersten Spieltag sind leer, heute geschafft = Flamme (%s)" % str(states))
	d["first_key"] = k - 10
	states = []
	for e in Daily.week(d, k + 1):
		states.append(str((e as Dictionary)["state"]))
	check(states[0] == "missed" and states[4] == "today", "Wochenreihe: verpasst = leerer Ring")


## Welt des Tages: fest je Spieltag, jede Vorlage einmal in 6 Tagen, nie Brett 0, lösbar (die Pool-Lösung gewinnt im
## Spiel unter den Regeln der Welt des Tages) – für 60 Spieltage geprüft; dazu der Tipp-Bot auf einer Probe.
func test_daily_world() -> void:
	var k0 := Daily.day_key(lt(2026, 11, 9, 12))
	var same := Daily.wdt_config(k0 + 3)
	var same2 := Daily.wdt_config(k0 + 3)
	check(same == same2 and Daily.wdt_board(k0 + 3) == Daily.wdt_board(k0 + 3) and bool(same["wdt"]) and str(same["title"]) == "Welt des Tages"
		and (same["new"] as Dictionary).is_empty() and str(same["caps"]) == "Welt des Tages · Donnerstag", "Welt des Tages: gleicher Spieltag → gleiche Welt (%s)" % str(same.get("caps", "")))
	var seen := {}
	var prev := -1
	var repeat_next := false
	for i in 6:
		var t := Daily.wdt_template(k0 + i)
		seen[t] = true
		if t == prev:
			repeat_next = true
		prev = t
	check(seen.size() == 6 and not repeat_next and seen.has(2) and seen.has(7) and not seen.has(1), "6 Spieltage in Folge: 6 verschiedene Vorlagen (Tag 2–7)")
	var worlds := {}
	var board0 := 0
	for i in 114:
		var key := k0 + i
		var bi := Daily.wdt_board_index(key, 20)
		if bi == 0:
			board0 += 1
		worlds["%d/%d" % [Daily.wdt_template(key), bi]] = true
	check(board0 == 0 and worlds.size() == 114, "nie Brett 0; 114 verschiedene Welten, bevor sich eine wiederholt (%d)" % worlds.size())
	# Lösbar: 60 Spieltage (auch alte und künftige), die Pool-Lösung gewinnt unter den Regeln der Welt des Tages
	var bad := 0
	var rule_diff := 0
	var keys: Array = []
	for i in 60:
		keys.append(k0 - 200 + i * 7 + (i % 5))
	for key in keys:
		var cfg := Daily.wdt_config(int(key))
		var b := Daily.wdt_board(int(key))
		var tc := Days.config(Daily.wdt_template(int(key)))
		for rk in ["goal_type", "goal_target", "goal_kinds", "goal_green", "limit", "stars", "unlocked", "choices", "wishes", "wish_types", "war", "no_war", "smog", "strike", "income", "fire", "rain_start", "rain_every",
				"rows", "later_rows", "top", "needs", "lightning", "lightning_from", "war8", "meteor", "smog8", "flood8", "rain_acker", "rain_kinds"]:
			if cfg.get(rk) != tc.get(rk):
				rule_diff += 1
		var gs := GameState.new()
		gs.setup_day(cfg, b["kinds"], int(b["seed"]), 0)
		for step in b["solution"]:
			gs.will = {}
			var sa := Days.solution_step(step)
			gs.play(sa[0], sa[1])
			if gs.is_over():
				break
		if not gs.day_won or int(b["index"]) == 0:
			bad += 1
			print("  Welt des Tages %d: Vorlage %d Brett %d nicht gelöst (%s)" % [int(key), Daily.wdt_template(int(key)), int(b["index"]), gs.day_lost])
	check(rule_diff == 0, "Welt des Tages: dieselben Regeln wie die geprüfte Vorlage (%d Abweichungen)" % rule_diff)
	check(bad == 0, "Welt des Tages: 60 Spieltage, alle lösbar (Pool-Lösung gewinnt; %d nicht)" % bad)
	# Tipp-Bot auf einer Probe (eine Welt je Vorlage)
	var bot_won := 0
	for i in 6:
		var key2 := k0 + 40 + i
		var cfg2 := Daily.wdt_config(key2)
		var b2 := Daily.wdt_board(key2)
		var gs2 := GameState.new()
		gs2.setup_day(cfg2, b2["kinds"], int(b2["seed"]), 0)
		var guard := 0
		while not gs2.is_over() and guard < 60:
			guard += 1
			var a := gs2.best_action()
			if a.is_empty():
				break
			var ans := {}
			if int(a["card"]) >= 0:
				ans[int(a["card"])] = int(a["choice"])
			gs2.play(a, ans)
		if gs2.day_won:
			bot_won += 1
	print("  Welt des Tages: Tipp-Bot gewinnt %d von 6" % bot_won)
	check(bot_won >= 4, "Welt des Tages: der Tipp-Bot gewinnt die meisten (%d/6)" % bot_won)


## Welt des Tages im Autoload Game: erst nach Tag 7 (am Spieltag danach), zählt für die Serie, Gnade je Spieltag.
func test_daily_world_game() -> void:
	var path := "user://test_taeglich.cfg"
	var g := _daily_game(path, lt(2026, 11, 13, 17))
	for i in 6:
		g.day_stars[i] = 2
	g.daily["last_new_key"] = g.today_key() - 1
	check(g.day_unlocked(7) and not g.daily_world_available() and not g.start_daily_world(), "vor Tag 7: keine Welt des Tages")
	g.start_day(7)
	var won: Array = []
	g.day_won.connect(func(info): won.append(info))
	_win_in_game(g)
	var ti: Dictionary = g.today_info()
	check(g.world_done and not g.daily_world_available() and str(ti["state"]) == "world_done_today" and str(won[0]["next_line"]) == "Morgen: deine erste Welt des Tages",
		"Tag 7 heute geschafft: die erste Welt des Tages kommt morgen")
	g.clock_override += 86400
	var k: int = g.today_key()
	var ti2: Dictionary = g.today_info()
	check(g.daily_world_available() and str(ti2["state"]) == "wdt" and str(ti2["caps"]) == "Welt des Tages · " + Daily.weekday_name(k), "am Spieltag danach: Welt des Tages (%s)" % str(ti2.get("caps", "")))
	check(g.start_daily_world() and g.in_daily_world() and g.day_no == Daily.wdt_template(k) and str(g.day_info()["title"]) == "Welt des Tages" and bool(g.day_info()["wdt"]),
		"Welt des Tages startet mit ihrer Vorlage")
	_lose_day(g)
	check(Daily.wdt_mercy(g.daily, k) == 2 and g.retry_day() and g.in_daily_world() and g.state.day_limit == int(Days.config(g.day_no)["limit"]) + 2,
		"Welt des Tages: Gnade +2 an ihrem Spieltag, Nochmal = dieselbe Welt")
	var s0: int = g.streak()
	_win_in_game(g)
	var ti3: Dictionary = g.today_info()
	check(g.streak() == s0 + 1 and g.done_today() and str(ti3["state"]) == "wdt_done" and int(g.daily["wdt_total"]) == 1 and Daily.wdt_stars(g.daily, k) >= 1
		and bool(won[1]["wdt"]) and str(won[1]["next_line"]) == "Morgen gibt es eine neue Welt." and not g.next_day(), "Welt des Tages geschafft: zählt für die Serie, „Morgen gibt es eine neue Welt.“")
	g.clock_override += 86400
	check(Daily.wdt_mercy(g.daily, g.today_key()) == 0 and str(g.today_info()["state"]) == "wdt" and Daily.wdt_template(g.today_key()) != Daily.wdt_template(k),
		"nächster Spieltag: neue Welt, Gnade zurückgesetzt")
	g.free()
	DirAccess.remove_absolute(path)


func test_daily_build() -> void:
	var path := "user://test_taeglich.cfg"
	var g := _daily_game(path, lt(2026, 11, 9, 18))
	g.start_day(1)
	_win_in_game(g)
	var st0: int = g.stars_of(1)
	var gst0: int = g.state.stars()
	check(g.over and g.continue_build() and not g.over and g.state.day_free_build and g.state.twists_left() == -1 and not g.state.is_over()
		and g.can_resume_build(), "Weiterbauen: keine Grenze, nicht vorbei")
	var made0: int = g.state.total_made()
	var c0: int = g.credits
	var msgs: Array = []
	g.message.connect(func(text, kind): msgs.append(text))
	for i in 30:
		var gs: GameState = g.state
		var a := gs.best_action()
		if a.is_empty():
			a = {"type": "twist", "axis": 1, "layer": 1, "turns": 1}
		var ans := {}
		if int(a.get("card", -1)) >= 0:
			ans[int(a["card"])] = int(a["choice"])
		var res: Dictionary = gs.play(a, ans)
		g.finish_round(res)
	var growth: int = g.state.build_growth()
	print("  Weiterbauen Tag 1: %d Felder in 30 Drehungen gewachsen" % growth)
	var coins_want := mini(Balance.BUILD_COIN_MAX, growth / Balance.BUILD_COIN_EVERY)
	check(g.state.day_lost == "" and g.state.day_won and g.state.stars() == gst0 and g.stars_of(1) == st0 and not g.over and growth == g.state.total_made() - made0
		and int(g.state.day_status()["growth"]) == growth and bool(g.state.day_status()["free_build"]), "Weiterbauen: 30 Drehungen später nicht gescheitert, Sterne unverändert, Zähler = %d" % growth)
	check(g.credits == c0 + coins_want and msgs.count(str(Days.TEXT["build_coin"])) == coins_want, "Weiterbauen: +1 Münze je 10 Felder, höchstens 3 (%d gewachsen, %d Münzen)" % [growth, g.credits - c0])
	# Höchstens 3 je Spieltag – auch in einer zweiten Welt
	var d := Daily.fresh(lt(2026, 11, 9, 18))
	var kk := Daily.day_key(lt(2026, 11, 9, 18))
	var a1 := Daily.build_coins(d, kk, 25, 0)
	var a2 := Daily.build_coins(d, kk, 50, 2)
	var a3 := Daily.build_coins(d, kk + 1, 50, 0)
	check(a1 == 2 and a2 == 1 and a3 == 3, "Bau-Münzen: 2, dann nur noch 1 (Grenze 3), am nächsten Tag wieder 3 (%d %d %d)" % [a1, a2, a3])
	# Übersicht → zurück zum Weiterbauen; ein neuer Versuch beendet es
	var keep: GameState = g.state
	g.new_game()
	check(g.can_resume_build() and g.resume_build() and g.state == keep and g.state.day_free_build, "freies Spiel: die heutige Welt bleibt zum Weiterbauen")
	g.start_day(1)
	_win_in_game(g)
	g.continue_build()
	keep = g.state
	g.state = GameState.new()
	check(g.resume_build() and g.state == keep and g.state.day_free_build and g.in_day(), "Weiterbauen: aus der Übersicht zurück in dieselbe Welt")
	g.retry_day()
	check(g.can_resume_build() and not g.state.day_free_build and g.state != keep, "Nochmal: neuer Versuch, die heutige Welt bleibt")
	g.state.day_lost = "twists"
	g._finish_day()
	check(g.can_resume_build() and g.resume_build() and g.state == keep, "Nochmal verloren: Weiterbauen bringt die geschaffte Welt zurück")
	g.clock_override = lt(2026, 11, 10, 18)
	check(not g.can_resume_build(), "neuer Spieltag: die Welt von gestern ist nicht mehr zum Weiterbauen")
	g.free()
	# Tag 6: Krieg im Weiterbauen ist nur Krieg
	var gs6 := day_state(6)
	gs6.day_won = true
	gs6.day_won_at = 5
	gs6.start_free_build()
	gs6.field_at(Vector3i(1, 0, -1), Vector3i(0, 0, -1)).kind = CHURCH
	top(gs6, 0, 0).kind = CHURCH
	top(gs6, -1, 0).kind = VILLAGE
	var r6 := twist(gs6, 0, 1, 1)
	twist(gs6, 1, -1, 1)
	check(_has_event(r6, "war_start") and gs6.day_lost == "" and not gs6.is_over() and gs6.twists_left() == -1 and top(gs6, -1, 0).kind == HUT
		and gs6.stars() == Days.stars_for(gs6.day, 5), "Tag 6 im Weiterbauen: Krieg ist nur Krieg (die Front fällt), nichts scheitert")
	# Grenze egal: über die alte Grenze hinaus
	var gs2 := day_state(2)
	gs2.day_won = true
	gs2.start_free_build()
	gs2.twists = gs2.day_limit + 5
	twist(gs2, 1, 1, 1)
	check(gs2.day_lost == "" and not gs2.is_over() and gs2.clone().day_free_build and gs2.clone().build_made0 == gs2.build_made0, "Weiterbauen: über die Grenze hinaus, clone() behält es")
	DirAccess.remove_absolute(path)


func _plan_state(extra: Dictionary) -> Dictionary:
	var st := {"mode": "auto", "allowed": true, "tone": "lieb", "name": "Lumi", "tag": "Tag 2 · Pflanzen", "streak": 1, "history": []}
	st.merge(extra, true)
	return st


func _plan_ok_times(plan: Array) -> bool:
	for e in plan:
		var m := Daily.minute_of_day(int((e as Dictionary)["at"]))
		if m < Balance.REMIND_EARLIEST or m > Balance.REMIND_LATEST:
			return false
	return true


func test_reminder_plan() -> void:
	var now := lt(2026, 11, 9, 18, 40)
	var k := Daily.day_key(now)
	# gewonnen heute in der Sitzung ab 18:10: A morgen 17:40, dann +2, +4, +7
	var p := ReminderPlan.plan(_plan_state({"today": k, "done_today": true, "last_win_key": k, "last_open_key": k, "anchor_min": 1090}), now)
	var ids: Array = []
	var cats: Array = []
	var keys: Array = []
	for e in p:
		ids.append(int(e["id"]))
		cats.append(str(e["cat"]))
		keys.append(int(e["key"]) - k)
	check(ids == [101, 102, 104, 107] and cats == ["A", "B", "C", "F"] and keys == [1, 2, 4, 7], "Plan: Leiter +1, +2, +4, +7 mit A, B, C, F (%s %s)" % [str(ids), str(cats)])
	check(int(p[0]["at"]) == lt(2026, 11, 10, 17, 40) and int(p[0]["hour"]) == 17 and int(p[0]["minute"]) == 40 and int(p[0]["day"]) == 10 and str(p[0]["title"]) == "Lumi",
		"Plan: Sitzung 18:10 → morgen 17:40 (%s)" % ReminderPlan.log_line(p[0]))
	check(str(p[3]["tpl"]) == "lF" and str(p[3]["body"]) == ReminderPlan.text_of("lF") and _plan_ok_times(p), "Plan: zuletzt die freundliche letzte Nachricht; alle Zeiten 8:00–21:30")
	var tpls := {}
	for e in p:
		tpls[str(e["tpl"])] = true
	check(tpls.size() == 4, "Plan: vier verschiedene Texte")
	# Nachteule: Sitzung um 0:30 am 10.11. (Spieltag 9.11.) → nicht schon um 8:00, sondern 10.11. 21:30 (≈ 21 h später)
	var night := lt(2026, 11, 10, 0, 30)
	var kn := Daily.day_key(night)
	var pn := ReminderPlan.plan(_plan_state({"today": kn, "done_today": true, "last_win_key": kn, "last_open_key": kn, "anchor_min": 30}), night)
	check(not pn.is_empty() and int(pn[0]["at"]) == lt(2026, 11, 10, 21, 30) and ReminderPlan.minute_for("auto", 170, 0) == 1290
		and ReminderPlan.minute_for("auto", 200, 0) == 480 and ReminderPlan.minute_for("fest", 30, 600) == 600,
		"Nachteule: Sitzung 0:30 → Erinnerung 21:30 am selben Kalendertag, nicht 8:00 (%s)" % (ReminderPlan.log_line(pn[0]) if not pn.is_empty() else "leer"))
	# Uhrzeiten
	var p7 := ReminderPlan.plan(_plan_state({"today": k, "done_today": true, "last_win_key": k, "last_open_key": k, "anchor_min": 420}), now)
	var p23 := ReminderPlan.plan(_plan_state({"today": k, "done_today": true, "last_win_key": k, "last_open_key": k, "anchor_min": 1430}), now)
	var pu := ReminderPlan.plan(_plan_state({"today": k, "done_today": true, "last_win_key": k, "last_open_key": k, "anchor_min": -1}), now)
	var pf := ReminderPlan.plan(_plan_state({"today": k, "done_today": true, "last_win_key": k, "last_open_key": k, "anchor_min": 1090, "mode": "fest", "fixed_min": 600}), now)
	check(Daily.minute_of_day(int(p7[0]["at"])) == 480 and Daily.minute_of_day(int(p23[0]["at"])) == 1290 and Daily.minute_of_day(int(pu[0]["at"])) == 1080
		and Daily.minute_of_day(int(pf[0]["at"])) == 600 and _plan_ok_times(p23) and _plan_ok_times(p7), "Uhrzeit: Sitzung 7:00 → 8:00, 23:50 → 21:30, unbekannt → 18:00, „Feste Uhrzeit“ 10:00")
	# Aus / keine Erlaubnis
	check(ReminderPlan.plan(_plan_state({"today": k, "mode": "aus"}), now).is_empty() and ReminderPlan.plan(_plan_state({"today": k, "allowed": false}), now).is_empty(),
		"„Aus“ oder keine Erlaubnis: kein Plan")
	# heute nur geöffnet, nicht geschafft, früh am Tag: A morgen (nie gleich nach dem Besuch), und kein Slot heute
	var morning := lt(2026, 11, 9, 9, 0)
	var po := ReminderPlan.plan(_plan_state({"today": k, "done_today": false, "last_win_key": k - 1, "last_open_key": k, "anchor_min": 1090}), morning)
	check(int(po[0]["key"]) == k + 1 and str(po[0]["cat"]) == "A", "nur geöffnet: die Leiter beginnt neu, A morgen")
	# gestern gewonnen, heute noch nicht geöffnet (Plan von gestern Abend aus gesehen): A heute, nicht innerhalb von 2 h
	var pg := ReminderPlan.plan(_plan_state({"today": k, "done_today": false, "last_win_key": k - 1, "last_open_key": k - 1, "anchor_min": 1090}), lt(2026, 11, 9, 8, 0))
	var pg2 := ReminderPlan.plan(_plan_state({"today": k, "done_today": false, "last_win_key": k - 1, "last_open_key": k - 1, "anchor_min": 1090}), lt(2026, 11, 9, 16, 0))
	check(int(pg[0]["key"]) == k and int(pg[0]["at"]) == lt(2026, 11, 9, 17, 40) and int(pg2[0]["key"]) == k + 1 and str(pg2[0]["cat"]) == "B",
		"heute noch nicht gespielt: A heute 17:40; um 16:00 zu nah → erst B morgen")
	var gap_ok := true
	for e in pg2:
		if int(e["at"]) < lt(2026, 11, 9, 16, 0) + 7200:
			gap_ok = false
	check(gap_ok, "nie innerhalb von 2 h nach jetzt")
	# nach einer Woche ohne Besuch: nichts mehr
	check(ReminderPlan.plan(_plan_state({"today": k, "last_win_key": k - 8, "last_open_key": k - 8}), now).is_empty(), "nach der letzten Nachricht: Ruhe, bis der Spieler zurückkommt")
	# Sommerzeit: Wanduhr-Felder (das Plugin rechnet mit der Zeitzone des Handys)
	var kd := Daily.day_key(lt(2026, 10, 24, 18))
	var pd := ReminderPlan.plan(_plan_state({"today": kd, "done_today": true, "last_win_key": kd, "last_open_key": kd, "anchor_min": 1090}), lt(2026, 10, 24, 18, 40))
	check(int(pd[0]["day"]) == 25 and int(pd[0]["month"]) == 10 and int(pd[0]["hour"]) == 17 and int(pd[0]["minute"]) == 40, "Sommerzeit-Ende: trotzdem 17:40 Ortszeit am 25.10.")
	# Geschichte: Gezeigtes kommt nach vorn (die letzte Nachricht nicht), höchstens 8
	var hist := ReminderPlan.absorb_shown(["l01"], [{"at": 100, "tpl": "l03"}, {"at": 200, "tpl": "l09"}, {"at": 900, "tpl": "l12"}, {"at": 150, "tpl": "lF"}], 500)
	check(hist == ["l09", "l03", "l01"], "Geschichte: gezeigt (neueste zuerst), ohne die letzte Nachricht (%s)" % str(hist))
	var long := ReminderPlan.absorb_shown(["a", "b", "c", "d", "e", "f", "g"], [{"at": 1, "tpl": "x"}, {"at": 2, "tpl": "y"}], 5)
	check(long.size() == 8 and long[0] == "y", "Geschichte: höchstens 8")


func test_reminder_templates() -> void:
	var allowed := ["{name}", "{tag}", "{streak}"]
	var re := RegEx.new()
	re.compile("\\{[a-z]+\\}")
	var ok_ph := true
	var bad_start := 0
	var too_long: Array = []
	for tone in ReminderPlan.TONES:
		var n_ac := 0
		for e in ReminderPlan.templates(tone):
			var d: Dictionary = e
			n_ac += 1
			var txt := str(d["text"])
			for m in re.search_all(txt):
				if not allowed.has(m.get_string()):
					ok_ph = false
			if txt.begins_with("{tag}"):
				bad_start += 1
			for tg in ["die Welt des Tages", "Tag 4 · Menschen"]:
				var r := ReminderPlan.render(txt, "Abcdefghijkl", tg, 365)
				if r.length() > 90:
					too_long.append(str(d["id"]))
		var fin := ReminderPlan.render(ReminderPlan.text_of(ReminderPlan.final_id(tone)), "Abcdefghijkl", "die Welt des Tages", 365)
		if fin.length() > 110:
			too_long.append(ReminderPlan.final_id(tone))
		check(n_ac >= 12 and ReminderPlan.final_id(tone).ends_with("F") and ReminderPlan.text_of(ReminderPlan.final_id(tone)) != "", "Texte %s: ≥ 12 A–C und eine letzte Nachricht" % tone)
	check(ok_ph and bad_start == 0, "Texte: nur {name}, {tag}, {streak}; keiner beginnt mit {tag}")
	check(too_long.is_empty(), "Texte: höchstens 90 Zeichen (letzte ≤ 110) mit langem Namen (%s)" % str(too_long))
	# S-Texte: nie bei Serie < 2 und nie in B/C; F = die letzte Nachricht des Tons
	var s_bad := 0
	for tone in ReminderPlan.TONES:
		for i in 80:
			for cat in ["A", "B", "C"]:
				var streak := 1 if cat == "A" else 9
				var id := ReminderPlan.pick(tone, cat, streak, [], 20000 + i)
				if ["l05", "f05", "s05"].has(id):
					s_bad += 1
		check(ReminderPlan.pick(tone, "F", 3, ["x"], 5) == ReminderPlan.final_id(tone), "F ist die letzte Nachricht (%s)" % tone)
	check(s_bad == 0, "S-Texte nie bei Serie < 2 oder in B/C (%d)" % s_bad)
	# 60 Pläne nacheinander (mit Geschichte): nie zweimal derselbe Text hintereinander, die letzten 4 nie
	for tone in ReminderPlan.TONES:
		var hist: Array = []
		var shown: Array = []
		var k := Daily.day_key(lt(2026, 11, 9, 12))
		var repeat := 0
		var recent := 0
		var c_ok := true
		for i in 60:
			var cat := "A" if i % 3 != 2 else ("B" if i % 2 == 0 else "C")
			var id := ReminderPlan.pick(tone, cat, 5, hist, k + i)
			if not hist.is_empty() and hist[0] == id:
				repeat += 1
			if hist.slice(0, 4).has(id):
				recent += 1
			if cat == "C" and not (ReminderPlan.text_of(id) != ""):
				c_ok = false
			shown.append(id)
			hist.push_front(id)
			if hist.size() > 8:
				hist.pop_back()
		var distinct := {}
		for x in shown:
			distinct[x] = true
		check(repeat == 0 and recent == 0 and c_ok and distinct.size() >= 10, "60 Pläne %s: nie zweimal hintereinander, die letzten 4 nie (%d verschiedene)" % [tone, distinct.size()])
	# frech/streng: manchmal ein lieber Text
	var lieb := 0
	for i in 200:
		if ReminderPlan.pick("frech", "A", 3, [], 30000 + i).begins_with("l"):
			lieb += 1
	check(lieb > 5 and lieb < 70, "frech: etwa 15 %% liebe Texte (%d von 200)" % lieb)
	check(ReminderPlan.pick("frech", "A", 3, ["f01"], 7) == ReminderPlan.pick("frech", "A", 3, ["f01"], 7), "gleiche Eingabe → gleicher Text")


func test_daily_debug() -> void:
	var path := "user://test_taeglich.cfg"
	var g := _daily_game(path, lt(2026, 11, 9, 18, 10))
	g.session_start = lt(2026, 11, 9, 18, 0)
	var t0: int = g.now_local()
	g.start_day(1)
	var plans: Array = []
	g.reminders_planned.connect(func(plan): plans.append(plan))
	_win_in_game(g)
	check(plans.size() == 1 and (plans[0] as Array).size() == 4 and int(g.daily["anchor"]) == 1080 and int((plans[0] as Array)[0]["hour"]) == 17
		and int((plans[0] as Array)[0]["minute"]) == 30 and (g.remind["planned"] as Array).size() == 4, "nach dem Sieg: Erinnerungen neu geplant (morgen 17:30)")
	var toast: String = g.debug_next_day()
	check(OS.is_debug_build() and g.now_local() == t0 + 86400 and g.day_unlocked(2) and toast == "Test: Jetzt ist Dienstag." and g.debug_day_offset == 1,
		"Test-Knopf: ein ganzer Tag weiter, Tag 2 offen (%s)" % toast)
	var p2: Array = plans[plans.size() - 1]
	check(not p2.is_empty() and int(p2[0]["at_real"]) == int(p2[0]["at"]) - 86400 and int(p2[0]["key"]) == g.today_key() + 1, "Test-Tage: das Plugin bekommt die echte Uhrzeit")
	var g2 := _daily_game(path, lt(2026, 11, 9, 18, 10), false)
	check(g2.debug_day_offset == 1 and g2.today_key() == g.today_key() and (g2.remind["planned"] as Array).size() == (g.remind["planned"] as Array).size(),
		"Test-Tage und Plan werden gespeichert")
	var soon: Dictionary = g.debug_reminder_soon()
	check(int(soon["id"]) == 199 and str(soon["cat"]) == "A" and str(soon["body"]) != "" and int(soon["key"]) == 2147483647,
		"Test: Erinnerung in 10 s (Spieltag-Schlüssel, den das Plugin nie verwirft)")
	g.set_reminder_mode("aus")
	check(g.reminder_log.is_empty() and str(g.remind["mode"]) == "aus", "Einstellung „Aus“: kein Plan")
	g.set_reminder_mode("fest", 15 * 60)
	check(not g.reminder_log.is_empty() and int(g.reminder_log[0]["hour"]) == 15, "Feste Uhrzeit 15:00")
	g.debug_reset_streak()
	check(g.streak() == 0 and g.shields() == 0 and (g.remind["history"] as Array).is_empty(), "Test: Serie zurücksetzen")
	g.free()
	g2.free()
	DirAccess.remove_absolute(path)


## Der Charakter spricht (Voice: im Ton des Charakters, ohne Charakter lieb) und fragt höchstens zweimal nach der
## Erinnerung (nach dem ersten Sieg, dann ab einer Serie von 3 Tagen).
func test_voice_and_ask() -> void:
	var lieb := CharacterTexts.line("d1_c0", Voice.tone())
	check(Voice.day_coach(1, 0, "x") == lieb, "Voice: Tages-Hinweis im Ton des Charakters")
	check(Voice.day_coach(3, 5, "Rückfall") == "Rückfall", "Voice: ohne Fassung bleibt der Satz der Tagestabelle")
	check(Voice.day_face(2, 1) == "worried" and Voice.face("miss") == "worried", "Voice: Gesicht zur Feuer-Warnung")
	var a := Voice.praise()
	var b := Voice.praise()
	check(a != "" and a != b, "Voice: Lob nie zweimal hintereinander gleich")
	for ton in Character.TONES:
		var ask := CharacterTexts.line("ask_reminder", str(ton), {"tag": "Tag 2: Pflanzen"})
		check(ask.contains("morgen") or ask.begins_with("Morgen"), "Frage nach der Erinnerung, kurz und ohne Tag (%s: %s)" % [ton, ask])
	var path := "user://test_taeglich.cfg"
	var g := _daily_game(path, lt(2026, 11, 9, 18, 10))
	check(g.reminder_ask_due(0), "Fragen: beim ersten Mal ja")
	g.note_reminder_asked()
	check(not g.reminder_ask_due(1) and g.reminder_ask_due(3), "Fragen: danach erst ab 3 Tagen Serie")
	g.note_reminder_asked()
	check(not g.reminder_ask_due(9) and int(g.remind["asked"]) == 2, "Fragen: höchstens zweimal")
	g.free()
	DirAccess.remove_absolute(path)


## Regel für alle Spieler-Texte (NAECHSTE_SCHRITTE „Texte“): ein kurzer Satz, höchstens 8 Wörter; die Regel heißt
## allgemein „Bring 3 gleiche in eine Reihe.“ – nie „Bring 3 Erden zusammen“.
func test_short_texts() -> void:
	var texts: Array = []
	for k in Days.TEXT:
		texts.append(str(Days.TEXT[k]))
	for n in range(1, Days.count() + 1):
		var c := Days.config(n)
		texts.append(str(c.get("intro", "")))
		texts.append(str(c.get("goal_text", "")))
		texts.append(str(c.get("rule_line", "")))
		texts.append(str(c.get("coach_demo", "")))
		texts.append(str(c.get("coach_tool", "")))
		texts.append(str((c.get("new", {}) as Dictionary).get("text", "")))
		for t in (c.get("coach", []) as Array):
			texts.append(str(t))
	# ui.gd braucht das Autoload Game (im --script-Lauf nicht kompilierbar): die Texte aus dem Quelltext lesen
	var src := FileAccess.get_file_as_string("res://scripts/ui.gd")
	var re := RegEx.create_from_string('(?:"text"|"body"|"[a-z]+"): "([^"]*)"')
	for block in ["const TUT_STEPS = [", "const COACH = {", "const TOOLTIPS = {"]:
		var from := src.find(block)
		var to := src.find("\n}", from) if block.ends_with("{") else src.find("\n]", from)
		for m in re.search_all(src.substr(from, to - from)):
			var v := m.get_string(1)
			if v.contains(" "):
				texts.append(v)
	for t in FieldData.KIND_HELP:
		texts.append(str(t))
	for k in GameState.WISH_TEXT:
		texts.append(str(GameState.WISH_TEXT[k]))
	for k in Character.TONE_SAMPLE:
		texts.append(str(Character.TONE_SAMPLE[k]))
	for k in CharacterTexts.LINES:
		for ton in CharacterTexts.TONES:
			for v in CharacterTexts.variants(str(k), str(ton)):
				texts.append(str(v))
	for ton in CharacterTexts.NOTIFY:
		for e in (CharacterTexts.NOTIFY[ton] as Array):
			texts.append(str((e as Dictionary)["text"]))
	var bad: Array = []
	for t in texts:
		var tx := str(t)
		if tx.split(" ", false).size() > 8 or tx.contains("Erden") or tx.contains("zusammen"):
			bad.append(tx)
	check(bad.is_empty(), "Texte kurz (≤ 8 Wörter, „Bring 3 gleiche in eine Reihe“): %s" % str(bad))
	check(str(Days.config(1)["new"]["text"]) == "Bring 3 gleiche in eine Reihe.", "Tag 1 erklärt die Regel allgemein")
