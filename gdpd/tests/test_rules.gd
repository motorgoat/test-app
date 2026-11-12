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
	Balance.CAMPAIGN_ON = false        # die alten Tests prüfen die Oberfläche der 7 Tage; test_ui9 schaltet um
	if OS.get_cmdline_user_args().has("--daily"):       # schneller Lauf: nur „Täglich spielen“
		_daily_tests()
		test_day_save()
		print("")
		print("%d Prüfungen, %d Fehler" % [checks, failures])
		quit(1 if failures > 0 else 0)
		return
	if OS.get_cmdline_user_args().has("--b14"):         # schneller Lauf: nur Build 14 (GDPD_LOGIK.md)
		_b14_tests()
		print("")
		print("%d Prüfungen, %d Fehler" % [checks, failures])
		quit(1 if failures > 0 else 0)
		return
	if OS.get_cmdline_user_args().has("--camp"):        # schneller Lauf: nur die Schöpfung
		await _camp_tests()
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
	test_bonus_stress()
	# Die Schöpfung (GDPD_SCHOEPFUNG.md v2)
	test_kinds9()
	test_groups9()
	test_thrive9()
	test_lasting_supply()
	test_volcano9()
	test_bolt9()
	test_pack_smog9()
	test_goal_progress9()
	test_mercy9()
	test_points9()
	test_rain9()
	test_xcheck9()
	test_pool_replay9()
	test_start_rules9()
	test_dangers_consequence9()
	test_farm9()
	test_carry9()
	test_solvable9()
	test_rescue_game()
	test_texts9()
	test_texts10()
	test_unlock60()
	test_migrate_v3()
	test_migrate_erde()
	test_sources10()
	test_hunt10()
	test_glacier10()
	test_impact10()
	test_rain_kind10()
	test_thrive10()
	test_reach10()
	test_level_game()
	test_ui9()
	test_hint9()
	test_rows_build12()
	test_save9()
	test_next_action9()
	test_next_action_all()
	test_next_action_concrete()
	test_review12()
	test_card_close9()
	_b14_tests()
	await process_frame          # das Autoload Game ist jetzt im Baum
	test_self_move_guard()
	await test_bonus_game()
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
	check(FieldData.KIND_COUNT == 40 and WATER == 15 and STONE == 16 and FieldData.LAVA == 17 and FieldData.SEED == 26
		and FieldData.JELLY == 27 and FieldData.CAMP == 39, "40 Arten (Erdgeschichte), Wasser ist 15, Fels 16, Lava 17 … Saat 26, Qualle 27 … Feuerstelle 39")
	check((FieldData.NEXT as Array).slice(0, 17) == [MEADOW, FOREST, BIGFOREST, HUT, ANIMALS, HUT, HOUSE, VILLAGE, TOWN, BIGCITY, -1, METROPOLIS, -1, -1, -1, -1, -1]
		and (FieldData.NEXT as Array).slice(17).count(-1) == 23, "NEXT wie in der Spec (neue Arten: nur in der Kampagne)")
	check((FieldData.DOWN as Array).slice(0, 17) == [E, E, MEADOW, MEADOW, FOREST, BIGFOREST, ANIMALS, HUT, HOUSE, VILLAGE, VILLAGE, TOWN, TOWN, BIGCITY, ANIMALS, WATER, STONE], "DOWN wie in der Spec")
	check((FieldData.TIER as Array).slice(0, 17) == [0, 1, 2, 2, 3, 4, 5, 6, 7, 8, 8, 9, 9, 10, 5, 0, 0] and Balance.GROW_FAITH.size() == 11, "TIER wie in der Spec, GROW_FAITH mit 11 Einträgen")
	check(not FieldData.can_row(STONE) and not FieldData.nature(STONE) and not FieldData.people(STONE) and FieldData.kind_name(STONE) == "Fels"
		and Days.CODE[STONE] == "R", "Fels (früher Stein): Hintergrund wie Wasser, keine Reihe, Brett-Zeichen R")
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
		and g5.kind_help(STONE) == "Fels. Gibt Arbeit.", "Tag 5: Erklärungen der Menschen (%s / %s / %s)" % [g5.kind_help(HUT), g5.kind_help(VILLAGE), g5.kind_help(STONE)])


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
	check(int(c2.get_value("schoepfung", "version", 0)) >= 2 and c2.has_section("taeglich") and c2.has_section("erinnerung")
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
	g.credits = 80
	var e1: String = g.buy_shield()
	g.credits = 220
	var e2: String = g.buy_shield()
	var e3: String = g.buy_shield()
	var e4: String = g.buy_shield()
	check(e1 == "Dir fehlen 20 ✦" and e2 == "" and e3 == "" and e4 == "Du hast genug Serienschutz." and g.shields() == 2 and g.points == 20,
		"Serienschutz kaufen: 100 Punkte, höchstens 2 (%s | %s | %s | %s)" % [e1, e2, e3, e4])
	# Meilenstein im Game: Münzen kommen aufs Konto
	g.daily["streak"] = 13
	g.daily["streak_last"] = g.today_key() - 1
	var c0: int = g.credits
	g.start_day(1)
	_win_in_game(g)
	var want14: int = Balance.SHIELD_FULL_COINS + Points.streak_bonus(14) + int(Points.milestone(14)["points"])
	check(g.streak() == 14 and g.points == c0 + want14, "Game: Meilenstein 14 mit vollem Schutz → +50, Serienbonus +10, Meilenstein 14 +50 (%d)" % (g.points - c0))
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
	# Build 12: Weiterbauen gibt es nicht mehr – nach dem Sieg ist der Tag vorbei, Game hat keinen Weg zurück hinein
	var gone := true
	for m in ["continue_build", "resume_build", "can_resume_build", "_keep_for_build", "_end_build", "_build_coins"]:
		if g.has_method(m):
			gone = false
	for pr in ["today_build", "build_state", "build_ctx", "_slot_live"]:
		if pr in g:
			gone = false
	check(g.over and g.state.day_won and not g.state.day_free_build and gone and not g.today_info().has("can_build")
		and not g.has_signal("build_started"), "Build 12: kein Weiterbauen nach dem Sieg (Game-API und Signal weg)")
	# Höchstens 3 je Spieltag – auch in einer zweiten Welt
	var d := Daily.fresh(lt(2026, 11, 9, 18))
	var kk := Daily.day_key(lt(2026, 11, 9, 18))
	var a1 := Daily.build_coins(d, kk, 25, 0)
	var a2 := Daily.build_coins(d, kk, 50, 2)
	var a3 := Daily.build_coins(d, kk + 1, 50, 0)
	check(a1 == 2 and a2 == 1 and a3 == 3, "Bau-Münzen: 2, dann nur noch 1 (Grenze 3), am nächsten Tag wieder 3 (%d %d %d)" % [a1, a2, a3])
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


# =============================================================================
# Weiterbauen hängt nie (Bericht „hat sich aufgehängt in der Bonusrunde“)
# =============================================================================

## Alle Tage und zwei Welten des Tages: nach dem Sieg Weiterbauen mit vielen Zufallszügen (Drehungen, dazwischen Regen
## und Meteor, vorher wie beim Ziehen Vorschau, Chip-Stand und Regen-Ziele). Kein Schritt dauert 200 ms oder mehr, das
## Spiel endet nie, insgesamt mindestens 3000 Drehungen in der Zeit. Dazu die Tipp-Suche in Schritten (wie im Spiel,
## Game.search_hint): Jeder Schritt bleibt unter 200 ms, und sie findet genau, was die Suche am Stück findet.
func test_bonus_stress() -> void:
	var step_limit := 200000          # µs je Schritt
	var time_budget := 240000         # ms für den ganzen Test
	var want_twists := 3000
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var worlds: Array = []
	for n in range(1, 8):
		worlds.append({"cfg": Days.config(n), "board": Days.board(n, 1 + n % 3), "name": "Tag %d" % n})
	for key in [20768, 20773]:
		worlds.append({"cfg": Daily.wdt_config(key), "board": Daily.wdt_board(key), "name": "Welt des Tages %d" % key})
	var per_world := ceili(float(want_twists) / float(worlds.size())) + 10
	var t_all := Time.get_ticks_msec()
	var twists := 0
	var tools := 0
	var worst := 0
	var worst_what := ""
	var ended := ""
	var search_worst := 0
	var search_same := true
	var searches := 0
	for wd in worlds:
		var cfg: Dictionary = wd["cfg"]
		var b: Dictionary = wd["board"]
		var gs := GameState.new()
		gs.setup_day(cfg, b["kinds"], int(b["seed"]), 0)
		# Ein paar Züge, dann gilt der Tag als geschafft (wie nach dem Sieg) und Weiterbauen beginnt
		for i in 4:
			var m0: Array = GameState.MOVES[rng.randi_range(0, GameState.MOVES.size() - 1)]
			gs.play({"type": "twist", "axis": int(m0[0]), "layer": int(m0[1]), "turns": int(m0[2])}, {})
		gs.day_lost = ""
		gs.day_won = true
		gs.day_won_at = gs.used_twists()
		gs.start_free_build()
		var done := 0
		while done < per_world and Time.get_ticks_msec() - t_all < time_budget:
			var m: Array = GameState.MOVES[rng.randi_range(0, GameState.MOVES.size() - 1)]
			var ax := int(m[0])
			var ly := int(m[1])
			var tu := int(m[2])
			var t0 := Time.get_ticks_usec()
			# Ziehen: die Vorschau (wie Game.preview), der Chip, die Regen-Ziele
			var sim := gs.clone()
			sim.apply_rotation(ax, ly, tu)
			sim.end_round()
			var _pv := gs.preview8(ax, ly, tu, sim)
			var _st := gs.day_status()
			var _rt := gs.rain_targets()
			var dt := Time.get_ticks_usec() - t0
			if dt > worst:
				worst = dt
				worst_what = "Vorschau"
			var r := rng.randf()
			var act := {"type": "twist", "axis": ax, "layer": ly, "turns": tu}
			if r < 0.12 and gs.rain > 0:
				var ids: Array = []
				for f in gs.fields:
					if gs.rain_ok(f) and gs.can_bonus("rain", f) == "":
						ids.append(f.id)
				if not ids.is_empty():
					act = {"type": "rain", "field": int(ids[rng.randi_range(0, ids.size() - 1)])}
			elif r < 0.2:
				var fid := rng.randi_range(0, gs.fields.size() - 1)
				if gs.can_bonus("strike", gs.fields[fid]) == "":
					act = {"type": "strike", "field": fid}
			t0 = Time.get_ticks_usec()
			gs.play(act, {})
			dt = Time.get_ticks_usec() - t0
			if dt > worst:
				worst = dt
				worst_what = str(act["type"])
			if str(act["type"]) == "twist":
				twists += 1
				done += 1
			else:
				tools += 1
			if gs.is_over() or not gs.day_free_build:
				ended = "%s nach %d Zügen" % [str(wd["name"]), done]
				break
			# Ab und zu der Tipp in Schritten (6 ms je Bild, wie Game.search_hint) gegen die Suche am Stück
			if done % 150 == 75:
				var only_twists := rng.randf() < 0.5
				var search := gs.clone().day_search(only_twists)
				var slices := 0
				var fin := false
				while search != null and not fin and slices < 100000:
					t0 = Time.get_ticks_usec()
					fin = search.step(GameScript.HINT_BUDGET_USEC)
					search_worst = maxi(search_worst, Time.get_ticks_usec() - t0)
					slices += 1
				var whole := gs.clone()._best_day_action8(only_twists)
				searches += 1
				# Drehungen brauchen mehrere Schritte (27 + bis zu 6 × 27 Simulationen); ein klarer Regen ist schneller fertig
				var sliced := slices > 1 or str(search.result.get("type", "")) != "twist"
				search_same = search_same and fin and sliced and str(search.result) == str(whole)
		if ended != "":
			break
	var secs := float(Time.get_ticks_msec() - t_all) / 1000.0
	print("Weiterbauen-Stresstest: %d Drehungen, %d Werkzeuge, %d Suchen in %.1f s, langsamster Schritt %.1f ms (%s), Suche je Schritt höchstens %.1f ms" % [
		twists, tools, searches, secs, float(worst) / 1000.0, worst_what, float(search_worst) / 1000.0])
	check(ended == "", "Weiterbauen endet nie von selbst (%s)" % ended)
	check(twists >= want_twists, "Weiterbauen: mindestens %d Zufallsdrehungen in der Zeit (%d in %.1f s)" % [want_twists, twists, secs])
	check(worst < step_limit, "Weiterbauen: kein Schritt dauert 200 ms (langsamster %.1f ms: %s)" % [float(worst) / 1000.0, worst_what])
	check(searches > 0 and search_same and search_worst < step_limit,
		"Tipp in Schritten: jeder Schritt unter 200 ms (höchstens %.1f ms), mehrere Schritte, dasselbe Ergebnis wie am Stück" % (float(search_worst) / 1000.0))


## Das echte Game (Autoload) an einem Tag: „Zurück“ ist kein neuer Versuch (undoing), und die Tipp-Suche (search_hint) verteilt sich auf mehrere Bilder, kein Bild steht dabei 200 ms, sie
## findet dasselbe wie die Suche am Stück und bricht ab, wenn der Spieler inzwischen dreht.
func test_bonus_game() -> void:
	var g: Node = root.get_node_or_null("Game")
	if g == null:
		check(false, "Autoload Game fehlt")
		return
	var path := "user://test_bonus.cfg"
	var old_path: String = g.save_path
	g.save_path = path
	g._start_attempt(2, Days.config(2), Days.board(2, 1), 0)
	check(bool(g.onboarding), "Tag 2: Gratis-Tipp am Tag")
	# „Zurück“ an einem Tag: new_game_started kommt mit undoing (die Oberfläche spielt weiter)
	g.play_turn(0, 1, 1)
	if g.has_choice():
		g.choose(0)
	g.busy = false
	var seen := {"undoing": false}
	var on_new := func() -> void:
		seen["undoing"] = bool(g.undoing)
	g.new_game_started.connect(on_new)
	var could: bool = g.can_undo()
	g.undo()
	g.new_game_started.disconnect(on_new)
	check(could and bool(seen["undoing"]) and not g.undoing and g.in_day() and not g.state.day_won,
		"Zurück an einem Tag: dasselbe Spiel läuft weiter (undoing nur während des Signals)")
	# Die Tipp-Suche über mehrere Bilder
	g.state.rain = 0
	var gaps := {"last": 0, "max": 0, "frames": 0}
	var tick := func() -> void:
		var now := Time.get_ticks_usec()
		if int(gaps["last"]) > 0:
			gaps["max"] = maxi(int(gaps["max"]), now - int(gaps["last"]))
		gaps["last"] = now
		gaps["frames"] = int(gaps["frames"]) + 1
	process_frame.connect(tick)
	var whole: Dictionary = g.state.clone().best_action()
	var act: Dictionary = await g.search_hint()
	process_frame.disconnect(tick)
	check(str(act) == str(whole) and int(gaps["frames"]) >= 2 and int(gaps["max"]) < 200000 and int(g.hint_searches) == 0,
		"Tipp-Suche verteilt: %d Bilder, längstes %.1f ms, dasselbe Ergebnis wie am Stück" % [int(gaps["frames"]), float(int(gaps["max"])) / 1000.0])
	# Dreht der Spieler während der Suche, bricht sie ab
	var box := {"act": {"x": 1}, "done": false}
	var run := func() -> void:
		box["act"] = await g.search_hint()
		box["done"] = true
	run.call()
	await process_frame
	g.state.play({"type": "twist", "axis": 1, "layer": 0, "turns": 1}, {})
	for i in 10:
		if bool(box["done"]):
			break
		await process_frame
	check(bool(box["done"]) and (box["act"] as Dictionary).is_empty() and int(g.hint_searches) == 0,
		"Tipp-Suche bricht ab, wenn inzwischen gedreht wird")
	g.save_path = old_path
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# =============================================================================
# Die Schöpfung (docs/GDPD_SCHOEPFUNG.md v2, Tests 14 / 1–21; GDPD_PUNKTE_LADEN.md 11.1)
# =============================================================================

const LAVA := FieldData.LAVA
const SOUP := FieldData.SOUP
const CELLS := FieldData.CELLS
const ALGAE := FieldData.ALGAE
const FISH := FieldData.FISH
const MOSS := FieldData.MOSS
const FERN := FieldData.FERN
const BIRDS := FieldData.BIRDS
const PRED := FieldData.PRED
const SEED := FieldData.SEED
const DOWN := Vector3i(0, -1, 0)


## Ein Level-Stand mit eigenem Brett: alles Wasser, dazu set ({Feld-ID: Art}). over: Teile der Level-Daten ersetzen.
func camp_state(n: int, set: Dictionary = {}, over: Dictionary = {}) -> GameState:
	var c := Campaign.config(n)
	for k in over:
		c[k] = over[k]
	var kinds: Array = []
	for i in 54:
		kinds.append(int(set.get(i, WATER)))
	var gs := GameState.new()
	gs.setup_level(c, kinds, 1)
	return gs


func tw(gs: GameState, m: Array) -> Dictionary:
	return gs.play({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])})


## Eine Vierteldrehung, die keines der Felder in keep bewegt (und, wenn move ≥ 0, das Feld move mitnimmt).
func move_avoiding(gs: GameState, keep: Array, move: int = -1) -> Array:
	for m in GameState.MOVES:
		if abs(int(m[2])) != 1:
			continue
		var a := int(m[0])
		var l := int(m[1])
		var ok := true
		for i in keep:
			if (gs.fields[int(i)] as FieldData).p[a] == l:
				ok = false
		if move >= 0 and (gs.fields[move] as FieldData).p[a] != l:
			ok = false
		if ok:
			return m
	return []


## Der i-te Nachbar von f auf einem ANDEREN Würfelchen (Sticker desselben Würfelchens drehen immer zusammen).
func other_nb(gs: GameState, f: int, i: int = 0) -> int:
	var out: Array = []
	for g in gs.nb9(f):
		if (gs.fields[g] as FieldData).p != (gs.fields[f] as FieldData).p:
			out.append(int(g))
	return int(out[i])


func _types(r: Dictionary) -> Array:
	var out: Array = []
	for e in r["events"]:
		out.append(str(e["type"]))
	return out


func test_kinds9() -> void:
	var nk := FieldData.KIND_COUNT
	check(nk == 40 and FieldData.CODE == "EwWAgTHhDSKGIMPoRLUzafmnvrs" + "qtibedxpcjkyF" and FieldData.CODE.length() == nk
		and FieldData.KIND_NAME[FieldData.LAVA] == "Lava" and FieldData.KIND_NAME[SEED] == "Saat"
		and FieldData.kind_plural(MOSS) == "Moose" and FieldData.kind_icon(PRED) == "pred", "kinds10: 40 Arten, Namen, CODE endet mit qtibedxpcjkyF")
	check(FieldData.water_family(WATER) and FieldData.water_family(FISH) and FieldData.water_family(SOUP)
		and FieldData.water_family(FieldData.JELLY) and FieldData.water_family(FieldData.TRILO) and not FieldData.water_family(FieldData.ICE)
		and not FieldData.water_family(MOSS) and FieldData.WATERS.size() == 7, "kinds10: Wasser-Familie mit Quallen und Trilobiten, Eis nicht")
	var names_ok := (FieldData.kind_name(FieldData.JELLY) == "Qualle" and FieldData.kind_plural(FieldData.JELLY) == "Quallen"
		and FieldData.kind_name(FieldData.TRILO) == "Trilobit" and FieldData.kind_plural(FieldData.MAMMOTH) == "Mammuts"
		and str(FieldData.KIND_ARTICLE[FieldData.ICE]) == "Eis" and str(FieldData.KIND_ARTICLE[FieldData.CAMP]) == "eine Feuerstelle"
		and FieldData.kind_icon(FieldData.SAURO) == "sauro" and FieldData.kind_icon(FieldData.EARLY) == "early"
		and FieldData.LIVING.has(FieldData.AMPHIB) and FieldData.LIVING.has(FieldData.EARLY) and not FieldData.LIVING.has(FieldData.ICE))
	var tiers := [5, 5, 5, 6, 6, 7, 8, 7, 0, 7, 8, 9, 9]
	for i in 13:
		if FieldData.tier(27 + i) != int(tiers[i]):
			names_ok = false
	check(names_ok, "kinds10: Namen, Mehrzahl, Artikel, Symbole, Stufen und Lebende der Arten 27–39")
	var nk_ok := true
	for k in nk:
		if FieldData.DOWN.size() != nk or FieldData.TIER.size() != nk or FieldData.KIND_HELP.size() != nk:
			nk_ok = false
	check(nk_ok and Balance.KIND_COUNT == nk, "kinds10: alle Tabellen haben 40 Einträge")
	var rt := true
	for n in range(1, Campaign.COUNT + 1):
		for i in Campaign.pool_size(n):
			var b := Campaign.board(n, i)
			if Campaign.encode(b["kinds"]) != str(b["board"]) or Campaign.decode(str(b["board"])) != b["kinds"]:
				rt = false
	check(rt and Campaign.pool_size(1) == 20 and Campaign.pool_size(Campaign.COUNT) == 20, "kinds10: decode(encode(b)) == b für jedes Pool-Brett")


func test_groups9() -> void:
	# Mitte oben: zwei Nachbarn gehören zu EINER Lava-Gruppe (3 Felder um die Ecke), ein Nachbar zu einer zweiten (1 Feld)
	var gs := camp_state(6)
	var f := gs.field_at(UP, UP).id
	var a := gs.field_at(Vector3i(0, 1, -1), UP).id
	var b := gs.field_at(Vector3i(-1, 1, 0), UP).id
	var link := gs.field_at(Vector3i(-1, 1, -1), UP).id
	var c := gs.field_at(Vector3i(1, 1, 0), UP).id
	for k in [a, b, link, c]:
		(gs.fields[int(k)] as FieldData).kind = LAVA
	gs._grp_ok = false
	check(gs.gsize9(a) == 3 and gs.gsize9(b) == 3 and gs.group_id9(a) == gs.group_id9(b) and gs.gsize9(c) == 1,
		"groups: gleiche Arten über Kanten = eine Gruppe (3) und eine zweite (1)")
	check(gs.supply9(f, "heat") == 3 + 1, "groups: Angebot = Summe der VERSCHIEDENEN Gruppen (3 + 1 = %d)" % gs.supply9(f, "heat"))
	var g3 := camp_state(54)
	for k in [a, b, link]:
		(g3.fields[int(k)] as FieldData).kind = FieldData.FOREST
	(g3.fields[f] as FieldData).kind = FieldData.TOWN
	g3._grp_ok = false
	check(g3.supply9(f, "work") == 3, "groups: Stadt neben zwei Feldern einer 3er-Gruppe Wald: Arbeit 3, nicht 6")
	# Stärke höchstens CAP 3: eine große Gruppe gibt nie mehr als 3
	var g2 := camp_state(6)
	var line: Array = []
	for fd in g2.fields:
		if fd.n == UP:
			fd.kind = LAVA
			line.append(fd.id)
	g2._grp_ok = false
	var edge := -1
	for fd in g2.fields:
		if fd.n != UP and fd.kind == WATER:
			for h in g2.nb9(fd.id):
				if (g2.fields[h] as FieldData).kind == LAVA:
					edge = fd.id
	check(edge >= 0 and g2.biggest9(LAVA) == 9 and g2.strength9(int(line[0])) == 3 and g2.supply9(edge, "heat") == 3,
		"groups: eine 9er-Gruppe über die Würfelkante gibt Stärke 3 (CAP), nicht 9")



func test_thrive9() -> void:
	# Lava mit 2 Wasser-Nachbarn kühlt nach G = 2 Runden zu Fels (Level 2); mit Dampf-Regen (Level 5) +1 Regen
	var gs := camp_state(2, {4: LAVA})
	var m := move_avoiding(gs, [4] + Array(gs.nb9(4)))
	tw(gs, m)
	check((gs.fields[4] as FieldData).kind == FieldData.STONE, "cooling: Lava mit 4 Wasser (doppelt versorgt) wird schon nach 1 Runde Fels")
	var g5 := camp_state(5, {4: LAVA})
	var m5 := move_avoiding(g5, [4] + Array(g5.nb9(4)))
	var rain0 := g5.rain
	var r5 := tw(g5, m5)
	check((g5.fields[4] as FieldData).kind == FieldData.STONE and g5.rain == rain0 + 1 and _types(r5).has("steam")
		and _types(r5).has("thrive"), "cooling + steam: reich versorgte Lava wird nach einer Runde Fels, +1 Regen (%s)" % str(_types(r5)))
	var g2 := camp_state(2, {4: LAVA, int(camp_state(2).nb9(4)[0]): FieldData.STONE, int(camp_state(2).nb9(4)[1]): FieldData.STONE})
	var mm := move_avoiding(g2, [4] + Array(g2.nb9(4)))
	tw(g2, mm)
	var k1 := (g2.fields[4] as FieldData).kind
	tw(g2, mm)
	check(k1 == LAVA and (g2.fields[4] as FieldData).kind == FieldData.STONE, "cooling: Lava mit genau 2 Wasser wird nach 2 Runden Fels")
	# Landgang (Level 25): Fisch neben Moos → Amphibie auf dem Moos, der Fisch wird Algen
	var g19 := camp_state(25)
	var fn := g19.nb9(4)
	var meadow := int(fn[0])
	g19 = camp_state(25, {4: FISH, meadow: MOSS})
	var m19 := move_avoiding(g19, [4, meadow])
	var spawned := false
	for i in 3:
		var r := tw(g19, m19)
		if _types(r).has("spawn"):
			spawned = true
	check(spawned and (g19.fields[meadow] as FieldData).kind == FieldData.AMPHIB and (g19.fields[4] as FieldData).kind == ALGAE,
		"thrive: Landgang – Fisch + Moos → Amphibie, der Fisch wird Algen")
	# Hunger (Level 35): Tiere ohne Pflanzen: Warnung bei H − 1, verhungern bei H → Wald (nicht Erde)
	var g20 := camp_state(35, {4: ANIMALS})
	(g20.fields[4] as FieldData).hungry = 0
	var m20 := move_avoiding(g20, [4] + Array(g20.nb9(4)))
	var seen: Array = []
	for i in 4:
		seen.append(_types(tw(g20, m20)))
	check(not (seen[1] as Array).has("hunger_warn") and (seen[2] as Array).has("hunger_warn") and (seen[3] as Array).has("starve")
		and (g20.fields[4] as FieldData).kind == FOREST, "starve_to_forest: Warnung in Runde 3, Runde 4 verhungert → Wald")
	# Vorrat: ein Tier vom Start-Brett hat 3 Runden extra
	var g20b := camp_state(35, {4: ANIMALS})
	var m20b := move_avoiding(g20b, [4] + Array(g20b.nb9(4)))
	var starved := false
	for i in 6:
		if _types(tw(g20b, m20b)).has("starve"):
			starved = true
	check(not starved and (g20b.fields[4] as FieldData).kind == ANIMALS, "Vorrat: Tiere vom Start-Brett verhungern nicht in 6 Runden")
	# Hütte verhungert nie (Level 49: keine down-Art)
	var g24 := camp_state(49, {4: HUT})
	var m24 := move_avoiding(g24, [4] + Array(g24.nb9(4)))
	var hk := true
	for i in 8:
		tw(g24, m24)
		if (g24.fields[4] as FieldData).kind != HUT:
			hk = false
	check(hk, "thrive: eine Hütte verhungert nie")
	# Dorf ohne Arbeit verhungert zur Hütte (Level 53), Stadt zum Dorf (Level 54)
	var g26 := camp_state(53, {4: VILLAGE, int(camp_state(53).nb9(4)[0]): ANIMALS})
	(g26.fields[4] as FieldData).hungry = 0
	var m26 := move_avoiding(g26, [4] + Array(g26.nb9(4)))
	for i in 4:
		tw(g26, m26)
	check((g26.fields[4] as FieldData).kind == HUT, "starve: Dorf, dessen 🔨 nie da war, wird nach H Runden Hütte")
	var g27 := camp_state(54, {4: TOWN})
	(g27.fields[4] as FieldData).hungry = 0
	var m27 := move_avoiding(g27, [4] + Array(g27.nb9(4)))
	for i in 4:
		tw(g27, m27)
	check((g27.fields[4] as FieldData).kind == VILLAGE, "starve: Stadt ohne Versorgung wird Dorf")


func test_lasting_supply() -> void:
	# Hütte neben Tieren: am Rundenende wird 🍞 versiegelt (need_sealed einmal)
	var probe := camp_state(49)
	var h := 4
	var a := other_nb(probe, h)
	var gs := camp_state(49, {h: HUT, a: ANIMALS})
	var m := move_avoiding(gs, [h, a])
	var r := tw(gs, m)
	var sealed := 0
	for e in r["events"]:
		if str(e["type"]) == "need_sealed" and int(e["field"]) == h and str(e["need"]) == "food":
			sealed += 1
	check(sealed == 1 and gs.sealed9(h, "food") and gs.satt9(h), "lasting: Hütte neben Tieren → 🍞 versiegelt (need_sealed einmal)")
	var p0 := gs.goal_progress()
	# die Tiere wegdrehen: die Hütte bleibt satt, der Chip fällt nicht
	var away := move_avoiding(gs, [h], a)
	var pv := gs.preview9(int(away[0]), int(away[1]), int(away[2]))
	check(not (pv["satt_lost"] as Array).has(h), "lasting_preview: ein versiegeltes Feld steht nie unter „satt verloren“")
	tw(gs, away)
	check(not gs.nb9(h).has(a) and gs.satt9(h) and gs.goal_progress() == p0, "lasting: Tiere weggedreht, die Hütte bleibt satt")
	var again := 0
	var mm := move_avoiding(gs, [h])
	for i in 5:
		for e in tw(gs, mm)["events"]:
			if str(e["type"]) == "need_sealed" and int(e["field"]) == h:
				again += 1
	check(again == 0 and gs.satt9(h), "lasting: 5 Runden später noch satt, kein zweites need_sealed")
	# Tiere satt bleiben (Level 20): keine Hunger-Warnung, nachdem die Wiese weg ist
	var p20 := camp_state(35)
	var t := 4
	var w := other_nb(p20, t)
	var g20 := camp_state(35, {t: ANIMALS, w: MEADOW})
	(g20.fields[t] as FieldData).hungry = 0
	tw(g20, move_avoiding(g20, [t, w]))
	var away2 := move_avoiding(g20, [t], w)
	tw(g20, away2)
	var warn := false
	var m2 := move_avoiding(g20, [t])
	for i in 5:
		if _types(tw(g20, m2)).has("hunger_warn"):
			warn = true
	check(not warn and (g20.fields[t] as FieldData).kind == ANIMALS and (g20.fields[t] as FieldData).hungry == 0,
		"lasting: Tiere, einmal gefüttert, hungern nie (Wiese weggedreht, 5 Runden)")
	# Regen versorgt: gleich versiegelt (Level 20: Regen macht Erde neben hungrigen Tieren zur Wiese, dann weggedreht)
	var g20r := camp_state(35, {t: ANIMALS, w: FieldData.EMPTY})
	g20r.rain = 1
	var rr := g20r.play({"type": "rain", "field": w})
	var pr := g20r.goal_progress()
	var sealed_r := _types(rr).has("need_sealed")
	var awr := move_avoiding(g20r, [t], w)
	tw(g20r, awr)
	check(sealed_r and not g20r.nb9(t).has(w), "lasting_rain: Regen → Wiese versiegelt, Wiese weggedreht")
	check(sealed_r and g20r.satt9(t) and g20r.goal_progress() >= pr, "lasting_rain: nach dem Regen bleiben die Tiere satt, der Fortschritt bleibt")
	# Ein Feuer löscht die Siegel (Level 24: Hütte brennt → Wiese)
	var gf := camp_state(49, {h: HUT, a: ANIMALS})
	tw(gf, move_avoiding(gf, [h, a]))
	(gf.fields[h] as FieldData).burning = true
	tw(gf, move_avoiding(gf, [h, a]))
	check((gf.fields[h] as FieldData).kind == MEADOW and (gf.fields[h] as FieldData).best.is_empty(), "lasting: Feuer löscht die Siegel (Hütte → Wiese)")
	# Hütte → Dorf behält 🍞 versiegelt, nur 🔨 ist neu (Level 26)
	var p26 := camp_state(53)
	var n26 := p26.nb9(h)
	var gd := camp_state(53, {h: HUT, int(n26[0]): ANIMALS, int(n26[1]): FieldData.STONE})
	var md := move_avoiding(gd, [h, int(n26[0]), int(n26[1])])
	var grew := false
	for i in 3:
		tw(gd, md)
		if (gd.fields[h] as FieldData).kind == VILLAGE:
			grew = true
			break
	var fd: FieldData = gd.fields[h]
	check(grew and fd.best.has("food") and not fd.best.has("work") or (grew and gd.satt9(h)),
		"lasting: Hütte → Dorf behält 🍞 (%s)" % str(fd.best))
	# best dreht mit: 4 Vierteldrehungen derselben Scheibe
	var gq := camp_state(49, {h: HUT, a: ANIMALS})
	tw(gq, move_avoiding(gq, [h, a]))
	var b0: Dictionary = (gq.fields[h] as FieldData).best.duplicate()
	var p_0 := (gq.fields[h] as FieldData).p
	var sl := move_avoiding(gq, [], h)
	for i in 4:
		tw(gq, sl)
	check((gq.fields[h] as FieldData).best == b0 and (gq.fields[h] as FieldData).p == p_0 and not b0.is_empty(),
		"lasting: best gehört zum Feld und dreht mit (4 Vierteldrehungen)")
	# satt-Menge wächst nur oder fällt durch eine Gefahr (zufälliges Spiel in Level 20–30)
	var ok := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for n in range(20, 31):
		var g := Campaign.new_state(n, Campaign.board(n, 3))
		for i in 25:
			var before := {}
			for x in g.satt_ids9():
				var all_sealed := true
				for need in g.need_list((g.fields[int(x)] as FieldData).kind):
					if not g.sealed9(int(x), str(need)):
						all_sealed = false
				if all_sealed:
					before[int(x)] = (g.fields[int(x)] as FieldData).kind
			var mv: Array = GameState.MOVES[rng.randi_range(0, 26)]
			tw(g, mv)
			for x in before:
				var f2: FieldData = g.fields[int(x)]
				if not g.satt9(f2.id) and f2.kind == int(before[x]) and not f2.burning and not g.front.has(f2.id):
					ok = false
	check(ok, "lasting: ein ganz versiegeltes Feld bleibt satt, bis eine Gefahr es ändert (Art, Feuer, Kriegsfront)")


func test_volcano9() -> void:
	# 5 Lava am Stück (Level 3) warnen; bleibt die Gruppe ≥ 5, bricht sie aus (bis zu 3 Nachbarn werden Lava)
	var gs := camp_state(3)
	var ring: Array = []
	for fd in gs.fields:
		if fd.n == UP and ring.size() < 5 and not (fd.p.x == 0 and fd.p.z == 0):
			ring.append(fd.id)
	var probe := camp_state(3)
	var set := {}
	for i in ring:
		set[int(i)] = LAVA
	gs = camp_state(3, set)
	check(gs.biggest9(LAVA) >= 5, "volcano: Testbrett mit Lava-Klumpen (%d)" % gs.biggest9(LAVA))
	var down := [1, -1, 1]
	var m := [1, -1, 1]       # eine Scheibe weit weg von der oberen Seite
	var r1 := tw(gs, m)
	check(_types(r1).has("volcano_warn") and gs.volc >= 0, "volcano: eine Lava-Gruppe ≥ 5 warnt („Vulkan grollt!“)")
	# zur Mitte der oberen Seite: Fels als gemachtes Ziel-Feld (mk) daneben → Ausbruch kostet −1
	for fd in gs.fields:
		if fd.n == UP and fd.kind == WATER:
			fd.kind = FieldData.STONE
			fd.mk = true
			gs.made[FieldData.STONE] = int(gs.made[FieldData.STONE]) + 1
	gs._grp_ok = false
	var p0 := gs.goal_progress()
	var r2 := tw(gs, m)
	check(_types(r2).has("erupt") and _types(r2).has("goal_loss") and int(gs.lost9[FieldData.STONE]) > 0,
		"volcano: Ausbruch, ein gemachter Fels darunter zählt −1 (goal_loss) (%s)" % str(_types(r2)))
	var rest := false
	for fd in gs.fields:
		if fd.kind == LAVA and fd.crater_rest > 0:
			rest = true
	check(rest, "volcano: der Krater ruht danach")
	# Klumpen teilen → „Ruhe“
	var g2 := camp_state(3, set)
	tw(g2, m)
	for i in ring.slice(0, 2):
		(g2.fields[int(i)] as FieldData).kind = FieldData.STONE
	g2._grp_ok = false
	var r3 := tw(g2, m)
	check(_types(r3).has("volcano_calm") and not _types(r3).has("erupt"), "volcano: geteilte Lava → volcano_calm, kein Ausbruch")


func test_bolt9() -> void:
	# Level 12: nur trockene Wald-Gruppen (≥ 3, kein Wasser daneben) werden gewarnt
	var gs := camp_state(21)
	for fd in gs.fields:
		fd.kind = FieldData.EMPTY
	var top3: Array = []
	for fd in gs.fields:
		if fd.n == UP and fd.p.z == -1:
			fd.kind = FOREST
			top3.append(fd.id)
	gs._grp_ok = false
	gs.flood_warn = {}
	var m := move_avoiding(gs, top3)
	var r := tw(gs, m)
	check(_types(r).has("bolt_warn") and top3.has(gs.bolt), "bolt9: trockener Wald (3, kein Wasser) wird gewarnt")
	# Wasser daneben: der Blitz geht daneben (bolt_miss)
	var nb_water := -1
	for i in top3:
		for g in gs.nb9(int(i)):
			if (gs.fields[g] as FieldData).kind == FieldData.EMPTY and nb_water < 0:
				nb_water = g
	(gs.fields[nb_water] as FieldData).kind = WATER
	gs._grp_ok = false
	var m2 := move_avoiding(gs, top3 + [nb_water])
	var r2 := tw(gs, m2)
	check(_types(r2).has("bolt_miss") and not _types(r2).has("bolt"), "bolt9: Wasser an den Wald → bolt_miss")
	# Wald am Wasser wird nie gewarnt: kein Blitz nach Zeit (12 Runden, der ganze Wald berührt Wasser)
	var g3 := camp_state(21)
	for fd in g3.fields:
		if fd.n == UP:
			fd.kind = FOREST
	g3._grp_ok = false
	var warned := false
	for i in 12:
		if _types(tw(g3, [1, -1, 1])).has("bolt_warn"):
			warned = true
	check(not warned, "bolt9: Wald am Wasser wird nie gewarnt (kein Blitz nach Zeit)")
	# Regen auf das gewarnte Feld hebt die Warnung auf
	var g4 := camp_state(21)
	for fd in g4.fields:
		fd.kind = FieldData.EMPTY
	for i in top3:
		(g4.fields[int(i)] as FieldData).kind = FOREST
	g4._grp_ok = false
	tw(g4, m)
	g4.rain = 1
	var bf := g4.bolt
	var rr := g4.play({"type": "rain", "field": bf})
	check(bf >= 0 and g4.bolt == -1 and _types(rr).has("bolt_cancel"), "bolt9: Regen auf das gewarnte Feld → bolt_cancel")
	# Feuer springt nie auf nasse Felder
	var g5 := camp_state(21)
	for fd in g5.fields:
		fd.kind = FOREST if fd.n == UP else WATER
	g5._grp_ok = false
	var c: FieldData = null
	for fd in g5.fields:
		if fd.n == UP and fd.p.x == 0 and fd.p.z == 0:
			c = fd
	c.burning = true
	tw(g5, [1, -1, 1])
	var wet_burn := false
	for fd in g5.fields:
		if fd.burning and g5.wet9(fd.id):
			wet_burn = true
	check(not wet_burn, "bolt9: Feuer springt nie auf nasse Felder")


func test_pack_smog9() -> void:
	# Rudel (Level 23): 3 Raubtiere am Stück neben Tieren warnen; trennt man sie, jagen sie nicht
	var gs := camp_state(38)
	var top3: Array = []
	for fd in gs.fields:
		if fd.n == UP and fd.p.z == -1:
			fd.kind = PRED
			top3.append(fd.id)
	var prey := -1
	for fd in gs.fields:
		if fd.n == UP and fd.p.z == 0 and fd.p.x == 0:
			fd.kind = ANIMALS
			prey = fd.id
	gs._grp_ok = false
	var m := move_avoiding(gs, top3 + [prey])
	var r1 := tw(gs, m)
	check(_types(r1).has("pack_warn") and gs.pack_warn9.has(prey), "pack: Rudel (3) neben Tieren warnt")
	var g2 := gs.clone()
	var r2 := tw(gs, m)
	check(_types(r2).has("pack_hunt") and (gs.fields[prey] as FieldData).kind == MEADOW, "pack: eine Runde später wird gejagt (Tiere → Wiese)")
	(g2.fields[int(top3[1])] as FieldData).kind = FieldData.EMPTY
	g2._grp_ok = false
	var r3 := tw(g2, m)
	check(not _types(r3).has("pack_hunt") and (g2.fields[prey] as FieldData).kind == ANIMALS, "pack: getrennt → keine Jagd")
	# Meteor auf ein Raubtier hebt das Rudel auf
	var g3 := camp_state(38)
	for i in top3:
		(g3.fields[int(i)] as FieldData).kind = PRED
	(g3.fields[prey] as FieldData).kind = ANIMALS
	g3._grp_ok = false
	tw(g3, m)
	check(g3.meteors == 1 and g3.meteor_ok9(g3.fields[int(top3[1])]), "meteor: Level 38 (Rudel) hat einen Meteor")
	g3.play({"type": "meteor", "field": int(top3[1])})
	var r4 := tw(g3, m)
	check(g3.meteors == 0 and not _types(r4).has("pack_hunt"), "meteor: ein Raubtier weg → keine Jagd")
	# Smog (Level 28): Industrie neben Natur warnt; weggedreht welkt nichts
	var g4 := camp_state(57)
	var ind := 4
	var nat := other_nb(g4, ind)
	(g4.fields[ind] as FieldData).kind = INDUSTRY
	(g4.fields[nat] as FieldData).kind = FOREST
	g4._grp_ok = false
	var ms := move_avoiding(g4, [ind, nat])
	var r5 := tw(g4, ms)
	check(_types(r5).has("smog_warn") and g4.smog_warn9.has(nat), "smog9: Industrie neben Wald warnt (smog_warn)")
	var g5 := g4.clone()
	var r6 := tw(g4, ms)
	check(_types(r6).has("polluted") and (g4.fields[nat] as FieldData).kind == MEADOW, "smog9: eine Runde später welkt der Wald (Wiese)")
	var away := move_avoiding(g5, [ind], nat)
	var r7 := tw(g5, away)
	check(not _types(r7).has("polluted"), "smog9: weggedreht → kein Smog")


func test_goal_progress9() -> void:
	# make = gemacht − verloren; Wachsen nach oben ist kein Verlust; eine Gefahr auf ein gemachtes Feld −1
	var gs := camp_state(1)
	var row: Array = []
	for fd in gs.fields:
		if fd.n == UP and fd.p.z == 0:
			row.append(fd)
	for fd in row:
		(fd as FieldData).kind = LAVA
	gs.moved = {(row[1] as FieldData).id: true}
	gs._rotated = false
	gs.end_round()
	check(gs.goal_progress() == 1 and (row[1] as FieldData).mk, "make: eine Reihe Lava → 1 Fels (mk)")
	# Level 4: Fels → Erde ist Wachsen (kein Verlust für die Erde-Zählung, der Fels war kein Ziel)
	var g4 := camp_state(4)
	var r4: Array = []
	for fd in g4.fields:
		if fd.n == UP and fd.p.z == 0:
			fd.kind = FieldData.STONE
			r4.append(fd.id)
	g4.moved = {int(r4[1]): true}
	g4.end_round()
	check(g4.goal_progress() == 1 and int(g4.lost9[FieldData.STONE]) == 0, "make: Fels → Erde wächst, kein Verlust")
	# satt-Ziel (Level 20): zählt satte Tiere; group-Ziel (Level 15): größte Gruppe
	var g15 := camp_state(51)
	for fd in g15.fields:
		if fd.n == UP and fd.p.z == -1:
			fd.kind = FieldData.FIELD
	g15._grp_ok = false
	check(g15.goal_progress() == 3 and g15.goal_type() == "group", "group: größte Acker-Gruppe zählt (%d)" % g15.goal_progress())
	# kein Schritt-Limit: 60 Drehungen ohne Sieg → nie verloren
	var gl := Campaign.new_state(12, Campaign.board(12, 2))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lost := false
	for i in 60:
		if gl.day_won:
			break
		tw(gl, GameState.MOVES[rng.randi_range(0, 26)])
		if gl.day_lost != "":
			lost = true
	check(not lost and gl.twists_left() == -1 and gl.day_status()["limit"] == 0, "no_step_limit: ein Level kann man nicht verlieren")
	# Ära (10): Leben im Wasser ändert die Welt → Ereignis era
	var g9 := camp_state(10)
	var r9: Array = []
	for fd in g9.fields:
		if fd.n == UP and fd.p.z == 0:
			fd.kind = CELLS
			r9.append(fd.id)
	g9._era_last = GameState._era_key9(g9.era9())
	g9.moved = {int(r9[1]): true}
	var re9 := g9.end_round()
	check(_types(re9).has("era") and int(g9.era9()["life"]) == 2 and int(g9.era9()["act"]) == 3, "era: Algen im Meer → Ereignis era (Leben 2)")
	# hold (Level 60): Ruhe zählt nur Runden ohne Schaden
	var g30 := Campaign.new_state(60, Campaign.board(60, 0))
	check(g30.goal_type() == "hold" and int(g30.held9[0]) == 0, "hold: Level 60 hat ein Ruhe-Ziel")


func test_mercy9() -> void:
	# Gnade: ab der ★-Zone alle 3 Schritte ohne Fortschritt +1 Regen (höchstens 3), nie davor
	# Build 14: nur, wenn Regen etwas bringt (hier: Wasser am Ufer → Ursuppe)
	var gs := camp_state(10, {0: E, 20: E, 40: E})
	gs.rain = 0
	var before_zone := false
	var gave := 0
	var m := [1, 1, 1]
	for i in 20:
		var r := tw(gs, m)
		if _types(r).has("mercy"):
			gave += 1
			if gs.steps9() <= int(gs.stars9[1]):
				before_zone = true
	check(gave >= 1 and not before_zone and gs.rain <= 3, "mercy: Hilfe von oben erst in der ★-Zone (%d×)" % gave)
	check(gs.rescue() or gs.steps9() - gs.gain_at9 < 3, "mercy: rescue() = Rettungs-Tipp gratis in der Gnade")


func test_points9() -> void:
	# Tabelle 2.1: Grenzen 4/6 (Par 8) und 5/9 (Par 9)
	var a := [90, 85, 80, 65, 60, 45, 40, 40, 40]
	var ok := true
	for i in a.size():
		var steps := i + 2
		var st := GameState.stars_for9([4, 6], steps)
		if GameState.points_for9(st, steps, 8) != int(a[i]):
			ok = false
	var b := [95, 90, 85, 80, 65, 60, 55, 50, 40]
	for i in b.size():
		var steps2 := i + 2
		if GameState.points_for9(GameState.stars_for9([5, 9], steps2), steps2, 9) != int(b[i]):
			ok = false
	check(ok and Points.level_points(1, 30, 4) == 40, "points: 30 + 10 × Sterne + 5 × max(0, Par − Schritte), nie unter 40")
	var d := Points.fresh()
	var p1 := Points.pay_level(d, 3, 45)
	var p2 := Points.pay_level(d, 3, 65)
	var p3 := Points.pay_level(d, 3, 60)
	check(p1 == 45 and p2 == 20 and p3 == 0, "points: Nochmal zahlt nur die Verbesserung (45, +20, +0)")
	var e1 := 0
	for i in 5:
		e1 += Points.pay_extra(d, 3)
	check(e1 == 30, "points: Extras höchstens 3 je Level (+10 je)")
	var bp := 0
	for i in 25:
		bp += Points.build_point(d, 100)
	var bp2 := Points.build_point(d, 101)
	check(bp == 20 and bp2 == 1, "points: Weiterbauen höchstens 20 je Spieltag, am nächsten wieder")
	check(Points.streak_bonus(1) == 2 and Points.streak_bonus(4) == 8 and Points.streak_bonus(9) == 10
		and int(Points.milestone(30)["points"]) == 100 and str(Points.milestone(30)["gift"]) == "flammenkranz",
		"points: Serienbonus +2 × Serie (höchstens 10), Meilensteine")
	check(Points.migrate_coins(7, 0) == 140 and Points.migrate_coins(1, 0) == 60 and Points.migrate_coins(1, 7) == 200,
		"points: Umstellung 1 Münze = 20 Punkte, mindestens 60, + 20 je alter Stern")
	check(Points.free_play_point(d, 100) == 20 and Points.free_play_point(d, 100) == 0, "points: freies Spiel +20 einmal je Spieltag")
	# Weiterbauen: wieder satt zählt nicht; jede Reihe einmal
	var gs := Campaign.new_state(1, Campaign.board(1, 1))
	for st2 in (Campaign.board(1, 1)["solution"] as Array):
		var ab: Array = Days.solution_step(st2)
		gs.play(ab[0], ab[1])
	gs.start_free_build()
	check(gs.day_won and not gs.day_free_build, "Build 12: kein Weiterbauen in der Schöpfung (start_free_build tut nichts)")
	# gekauftes Wunder: 2 Schritte, eins je Art
	var gm := Campaign.new_state(6, Campaign.board(6, 1))
	gm.rain = 0
	var spot := -1
	for fd in gm.fields:
		if gm.rain_to9(fd) >= 0:
			spot = fd.id
			break
	var r := gm.play({"type": "rain", "field": spot, "bought": true})
	var spot2 := -1
	for fd in gm.fields:
		if gm.rain_to9(fd) >= 0:
			spot2 = fd.id
			break
	check(spot >= 0 and gm.steps9() == 2 and not gm.rain_ok9(gm.fields[spot2], true) and not bool(r.get("refused", false)),
		"miracle_steps: ein gekaufter Regen zählt 2 Schritte, ein zweiter im Level geht nicht")


func test_xcheck9() -> void:
	var X = load("res://tests/xcheck9.gd")
	var r: Dictionary = X.run("res://tests/data/xcheck10_cases.json")
	check(int(r["cases"]) >= 250 and int(r["steps"]) > 5000 and int(r["bad"]) == 0,
		"xcheck10: Abgleich mit engine10.py (neue, umgebaute und alte Level, Pool-Lösungen): %d Fälle, %d Schritte, %d abweichend" % [int(r["cases"]), int(r["steps"]), int(r["bad"])])


func test_pool_replay9() -> void:
	var bad := 0
	var n_boards := 0
	var stars_ok := true
	GameState.engine9_mode = true          # die Lösungen kommen aus dem Modell: genau dort nachspielen
	for n in range(1, Campaign.COUNT + 1):
		var c := Campaign.config(n)
		for i in Campaign.pool_size(n):
			var b := Campaign.board(n, i)
			var gs := Campaign.new_state(n, b)
			for st in (b["solution"] as Array):
				var ab: Array = Days.solution_step(st)
				gs.play(ab[0], ab[1])
			n_boards += 1
			if not gs.day_won or gs.day_won_at != int(b["solved_in"]) or gs.stars() != int(b["stars"]) or gs.level_points() != int(b["points"]):
				bad += 1
				if bad <= 3:
					print("  Pool: Level %d Brett %d: gewonnen %s bei %d (soll %d), Sterne %d/%d" % [n, i, str(gs.day_won), gs.day_won_at, int(b["solved_in"]), gs.stars(), int(b["stars"])])
		var cs: Array = c["stars"]
		var gs0 := Campaign.new_state(n, Campaign.board(n, 0))
		if [int(cs[0]), int(cs[1])] != Campaign.stars_of(n) or int(c["par"]) != int(cs[0]) + 4 or gs0.stars9 != Campaign.stars_of(n):
			stars_ok = false
	GameState.engine9_mode = false
	check(n_boards == 20 * Campaign.COUNT and bad == 0, "pool_replay10: alle %d Pool-Lösungen gewinnen im Modell-Modus genau bei solved_in mit ihren Sternen und Punkten (%d abweichend)" % [n_boards, bad])
	# Spielregeln (Build 12, späte Runde): jedes Pool-Brett bleibt lösbar – mit seiner Lösung oder dem Tipp, mit ★★+
	var by_sol := 0
	var by_hint := 0
	var lost: Array = []
	var t0 := Time.get_ticks_msec()
	for n2 in range(1, Campaign.COUNT + 1):
		for i2 in Campaign.pool_size(n2):
			var b2 := Campaign.board(n2, i2)
			var g2 := Campaign.new_state(n2, b2)
			for st2 in (b2["solution"] as Array):
				var ab2: Array = Days.solution_step(st2)
				g2.play(ab2[0], ab2[1])
				if g2.day_won:
					break
			if g2.day_won:
				by_sol += 1
				continue
			var g3 := Campaign.new_state(n2, b2)
			for k3 in 40:
				if g3.day_won:
					break
				var a3 := g3.best_action()
				if a3.is_empty():
					break
				g3.play(a3)
			if g3.day_won and g3.stars() >= 2:
				by_hint += 1
			else:
				lost.append([n2, i2, g3.day_won, g3.stars()])
	print("  Pool unter den Spielregeln: %d mit der Lösung, %d mit dem Tipp (%d ms)" % [by_sol, by_hint, Time.get_ticks_msec() - t0])
	check(lost.is_empty() and by_sol >= 19 * Campaign.COUNT, "pool_replay10: jedes Pool-Brett unter den Spielregeln gewonnen (Lösung %d, Tipp %d, offen %s)" % [by_sol, by_hint, str(lost.slice(0, 3))])
	check(stars_ok and Campaign.stars_of(16) == [5, 19] and Campaign.stars_of(1) == [4, 10] and Campaign.stars_of(59) == [5, 19]
		and Campaign.par_of(34) == 8, "stars_erde: Sterne-Grenzen und Par aus den Daten (stars12.py), Par = ★★★ + 4")


func test_start_rules9() -> void:
	# Jedes Pool-Brett erfüllt die Startbedingungen; satt-Ziele über Sticker-Arten erreichbar (satt_reachable)
	var bad := 0
	var infeas := 0
	var kinds_bad := 0
	for n in range(1, Campaign.COUNT + 1):
		for i in Campaign.pool_size(n):
			var b := Campaign.board(n, i)
			if not Campaign.start_ok(n, b["kinds"]):
				bad += 1
			var gs := Campaign.new_state(n, b)
			if Campaign.infeasible(gs, Campaign.config(n)) > 0:
				infeas += 1
			var vis := {}
			for k in b["kinds"]:
				if int(k) != WATER:
					vis[int(k)] = true
			if vis.size() > 6:
				kinds_bad += 1
	check(bad == 0, "start rules: jedes Pool-Brett ohne Reihe, Fortschritt und satte Ziel-Felder (%d falsch)" % bad)
	check(infeas == 0, "satt_reachable: jedes satt-Ziel über Sticker-Arten erreichbar (%d nicht)" % infeas)
	check(kinds_bad == 0, "Startbrett: höchstens 6 sichtbare Arten außer Wasser (%d mehr)" % kinds_bad)


func test_rain9() -> void:
	# Level 20–23: Regen auf einen Wald neben einer Wiese lockt Tiere; ohne Wiese geht er nicht
	var probe := camp_state(35)
	var f := 4
	var w := int(probe.nb9(f)[0])
	var gs := camp_state(35, {f: FOREST, w: MEADOW})
	check(gs.rain_ok9(gs.fields[f]) and gs.rain_to9(gs.fields[f]) == ANIMALS, "rain_lure: Wald neben Wiese → Tiere")
	var g2 := camp_state(35, {f: FOREST})
	check(not g2.rain_ok9(g2.fields[f]), "rain_lure: Wald ohne Wiese: kein Regen")
	# Level 12: Regen macht Wasser am Ufer zu Algen
	var g19 := camp_state(12, {w: MEADOW})
	check(g19.rain_to9(g19.fields[f]) == ALGAE, "rain12: Wasser am Ufer wird Algen")
	# Level 52: Regen auf Wiese neben Menschen → Saat, sonst Wald
	var g25 := camp_state(52, {f: MEADOW, w: HUT})
	var g25b := camp_state(52, {f: MEADOW})
	check(g25.rain_to9(g25.fields[f]) == SEED and g25b.rain_to9(g25b.fields[f]) == FOREST, "rain52: Wiese neben Hütte → Saat, sonst Wald")


func test_dangers_consequence9() -> void:
	# Jede Gefahr kommt nur als Folge und ist eine Runde vorher gewarnt (Zufallsspiel über alle Level)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var bad: Array = []
	var dangers := 0
	for n in range(1, Campaign.COUNT + 1):
		for bi in [2, 7]:
			var gs := Campaign.new_state(n, Campaign.board(n, bi))
			var prev: Array = []
			var prev_ev: Array = []
			var war_seen := false
			for i in 30:
				if gs.day_won:
					break
				var r := tw(gs, GameState.MOVES[rng.randi_range(0, 26)])
				var tr: Array = r["trace"]
				if tr.has("war_start"):
					war_seen = true
				for t in tr:
					var ts := str(t)
					if ts == "bolt" and not prev.has("bolt_warn"):
						bad.append("L%d bolt" % n)
					if ts == "erupt" and not prev.has("volcano_warn"):
						bad.append("L%d erupt" % n)
					if ts == "pack_hunt" and not prev.has("pack_warn"):
						bad.append("L%d pack" % n)
					if ts == "smog" and not prev.has("smog_warn"):
						bad.append("L%d smog" % n)
					if ts == "flood" and not prev.has("flood_warn"):
						bad.append("L%d flood" % n)
					if ts == "war_hit" and not war_seen:
						bad.append("L%d war" % n)
					if ["bolt", "erupt", "pack_hunt", "smog", "flood", "war_hit", "starve"].has(ts):
						dangers += 1
				for e in r["events"]:
					if str(e["type"]) == "starve":
						var warned := false
						for e0 in prev_ev:
							if str(e0["type"]) == "hunger_warn" and int(e0["field"]) == int(e["field"]):
								warned = true
						if not warned:
							bad.append("L%d starve" % n)
				prev = tr
				prev_ev = r["events"]
	check(bad.is_empty() and dangers > 0, "dangers: %d Gefahren im Zufallsspiel, jede eine Runde vorher gewarnt (%s)" % [dangers, str(bad.slice(0, 5))])


func test_farm9() -> void:
	# Hin-und-her-Drehen (jede Scheibe) holt nie ★★★ und ist nie schneller als die Pool-Lösung
	var bad: Array = []
	for n in range(1, Campaign.COUNT + 1):
		var b := Campaign.board(n, 1)
		var s3 := int(Campaign.stars_of(n)[0])
		for m in GameState.MOVES:
			var inv := [int(m[0]), int(m[1]), -int(m[2]) if absi(int(m[2])) == 1 else 2]
			var gs := Campaign.new_state(n, b)
			for i in 16:
				if gs.day_won:
					break
				tw(gs, m if i % 2 == 0 else inv)
			if gs.day_won and (gs.day_won_at <= s3 or gs.day_won_at < int(b["solved_in"])):
				bad.append("L%d %s in %d" % [n, str(m), gs.day_won_at])
	check(bad.is_empty(), "farm9: Hin und her ist nie ★★★ und nie schneller als ehrliches Spiel (%s)" % str(bad.slice(0, 5)))


func test_carry9() -> void:
	# Die Welt von gestern: genau die Start-Mischung, Startbedingungen erfüllt oder Pool-Brett; deterministisch
	var ok := true
	var carried := 0
	for n in [2, 3, 6, 7, 9, 10, 13, 14, 16, 17, 19, 22, 24, 26, 27, 29, 31, 32, 33, 35, 37, 39, 41, 42, 44, 45, 47, 49, 51,
			53, 55, 58, 60]:
		var prev := Campaign.new_state(n - 1, Campaign.board(n - 1, 4))
		for st in (Campaign.board(n - 1, 4)["solution"] as Array):
			var ab: Array = Days.solution_step(st)
			prev.play(ab[0], ab[1])
		var world := Campaign.decode(prev.slot_board9())
		var c1 := Campaign.carry(world, n, 3)
		var c2 := Campaign.carry(world, n, 3)
		if c1["kinds"] != c2["kinds"] or str(c1["how"]) != str(c2["how"]):
			ok = false
		if str(c1["how"]) == "carry":
			carried += 1
			var comp: Dictionary = Campaign.config(n)["comp"]
			var cnt := {}
			for k in c1["kinds"]:
				cnt[int(k)] = int(cnt.get(int(k), 0)) + 1
			for key in comp:
				if int(cnt.get(int(str(key)), 0)) != int(comp[key]):
					ok = false
			if not Campaign.start_ok(n, c1["kinds"]):
				ok = false
		elif c1["kinds"] != Campaign.board(n, 0)["kinds"]:
			ok = false
	var first := Campaign.carry(Campaign.board(4, 0)["kinds"], 5, 1)
	check(ok and carried >= 15, "carry10: getragene Welt = genau die Mischung, Startbedingungen, deterministisch (%d getragen)" % carried)
	var firsts := true
	for e in range(2, Campaign.era_count() + 1):
		var n1 := int(Campaign.era_levels(e)[0])
		var prev1: Array = Campaign.board(n1 - 1, 0)["kinds"]
		if str(Campaign.carry(prev1, n1, 1)["how"]) != "fallback" or not Campaign.first_of_era(n1):
			firsts = false
	check(str(first["how"]) == "fallback" and firsts, "carry10: jedes neue Zeitalter beginnt auf einem frischen Pool-Brett")


## Ein Spieler, der zufällig dreht und gießt (der schlechteste Spieler der Prüfung), mit dem Sicherheitsnetz wie
## Game._rescue_check: Sagt stuck9 etwas, nimmt er das Geschenk an. [gewonnen, Schritte, Geschenke, ohne Geschenk].
func _net_play(gs: GameState, rng: RandomNumberGenerator, cap: int) -> Array:
	var told_at := -99
	var dead_told := false
	var gifts := 0
	var acts := 0
	var nogift := 0
	while not gs.day_won and gs.twists < cap and acts < cap * 3:
		acts += 1
		var did := false
		if gs.rain > 0 and rng.randf() < 0.3:
			var cand: Array = []
			for f in gs.fields:
				if gs.rain_ok9(f):
					cand.append(f.id)
			if not cand.is_empty():
				gs.play({"type": "rain", "field": int(cand[rng.randi_range(0, cand.size() - 1)])})
				did = true
		if not did:
			tw(gs, GameState.MOVES[rng.randi_range(0, GameState.MOVES.size() - 1)])
		if gs.day_won:
			break
		var why := gs.stuck9()
		if why != "dead":
			dead_told = false
		if why == "":
			continue
		if (why == "dead" and not dead_told) or gs.steps9() - told_at >= GameState.STALL9:
			dead_told = why == "dead"
			told_at = gs.steps9()
			if gs.gift_plan9().is_empty():
				nogift += 1
			else:
				gs.play({"type": "gift"})
				gifts += 1
	return [gs.day_won, gs.steps9(), gifts, nogift]


## Jedes Level bleibt lösbar (Spieler: „16 Felsen war bei mir nicht möglich“): reach9 auf allen Pool-Brettern, getragene
## Welten aus Ketten mit zufälligem Spiel und Weiterbauen (Campaign.carry + ensure), Vulkan-Klumpen, Nachschub,
## Rückfall, Level-3-Nachbau, Sackgassen nach Sticker-Arten (L16, L17), Geschenk = Fortschritt, Stocken.
func test_solvable9() -> void:
	# 1. Kein Pool-Brett gilt als Sackgasse (reach9 ist optimistisch, nie zu streng)
	var bad_pool: Array = []
	for n in range(1, Campaign.COUNT + 1):
		for i in Campaign.pool_size(n):
			var gp := Campaign.new_state(n, Campaign.board(n, i))
			if not bool(gp.reach9()["ok"]) or gp.stuck9() != "":
				bad_pool.append([n, i])
	check(bad_pool.is_empty(), "reach10: reach9 hält jedes der %d Pool-Bretter für erreichbar (%s)" % [20 * Campaign.COUNT, str(bad_pool.slice(0, 5))])
	# 2. Ketten je Akt: Pool-Brett → zufällig spielen (mit Netz) → 0–40 Drehungen Weiterbauen → carry + ensure → …
	var t0 := Time.get_ticks_msec()
	var fails: Array = []
	var won := 0
	var starts := 0
	var max_steps := {}
	var ensure_worst := 0
	var ensure_lines := 0
	var carry_worst := 0
	var start_rows: Array = []
	for act in range(1, Campaign.era_count() + 1):
		var levels := Campaign.act_levels(act)
		for chain in 2:
			var rng := RandomNumberGenerator.new()
			rng.seed = act * 101 + chain * 7
			var b: Dictionary = Campaign.board(int(levels[0]), 1 + chain)
			b["how"] = "pool"
			for li in levels.size():
				var lv := int(levels[li])
				var gs := Campaign.new_state(lv, b)
				starts += 1
				var clump := gs.biggest9(FieldData.LAVA)
				if not bool(gs.reach9()["ok"]) or (bool(gs.sys9["volcano"]) and str(b.get("how", "")) == "carry"
						and clump > GameState.CLUMP_CAP9):
					fails.append(["start", lv, chain, clump, str(b.get("how", ""))])
				var res := _net_play(gs, rng, 150)
				max_steps[lv] = maxi(int(max_steps.get(lv, 0)), int(res[1]))
				if not bool(res[0]) or int(res[3]) > 0:
					fails.append(["play", lv, chain, res, gs.progress9(), gs.target9()])
					break
				won += 1
				if li + 1 < levels.size():
					var nx := int(levels[li + 1])
					var tc := Time.get_ticks_usec()
					b = Campaign.carry(Campaign.decode(gs.slot_board9()), nx, chain + 1000 * nx + 1, chain)
					carry_worst = maxi(carry_worst, Time.get_ticks_usec() - tc)
					b["kinds"] = Campaign.decode(Campaign.encode(b["kinds"]))      # Speichern und Laden
					var te := Time.get_ticks_usec()
					b = Campaign.ensure(nx, b, chain)
					ensure_worst = maxi(ensure_worst, Time.get_ticks_usec() - te)
					if str(b.get("line", "")) != "":
						ensure_lines += 1
					var gl := Campaign.new_state(nx, b)
					if not gl.lines().is_empty():
						start_rows.append([nx, chain, str(b.get("how", ""))])
	print("  Lösbarkeit: %d Starts, %d gewonnen (Zufallsspieler mit Netz), %d ms, längstes Level %s" % [starts, won,
		Time.get_ticks_msec() - t0, str(max_steps)])
	# Der Start-Check läuft einmal beim Level-Start auf dem Haupt-Thread: am Handy (~4× langsamer) unter 150 ms
	print("  Start-Check (Campaign.ensure): höchstens %.1f ms am PC, %d Starts mit Nachschub/Teilen/Pool; carry höchstens %.1f ms" % [ensure_worst / 1000.0, ensure_lines, carry_worst / 1000.0])
	check(ensure_worst < 35000, "solvable9: Campaign.ensure höchstens %.1f ms (Handy-Budget 150 ms / 4)" % (ensure_worst / 1000.0))
	check(fails.is_empty() and won == starts, "solvable9: jede getragene Welt erreichbar, Lava-Klumpen ≤ %d, jedes Level gewonnen (%s)" % [GameState.CLUMP_CAP9, str(fails.slice(0, 3))])
	check(start_rows.is_empty(), "Build 12: keine fertige Reihe am Start einer getragenen Welt nach carry + ensure (%s)" % str(start_rows.slice(0, 3)))
	# 2b. Level 3 wie beim Spieler (eigene Welt aus Level 1–2): 20 unordentliche Ketten, Level 3 startet erreichbar mit
	# Lava-Klumpen ≤ CLUMP_CAP9 und wird gewonnen; ohne Geschenk (nur Drehen und Regen) zählt, wie oft es auch so geht
	var l3_fail: Array = []
	var l3_plain := 0
	var l3_clump := 0
	for ch3 in 20:
		var r3 := RandomNumberGenerator.new()
		r3.seed = 3300 + ch3
		var b3: Dictionary = Campaign.board(1, 1 + ch3 % maxi(1, Campaign.pool_size(1) - 1))
		b3["how"] = "pool"
		for lv3 in [1, 2, 3]:
			var g3s := Campaign.new_state(lv3, b3)
			if lv3 == 3:
				l3_clump = maxi(l3_clump, g3s.biggest9(FieldData.LAVA))
				if not bool(g3s.reach9()["ok"]) or g3s.target9() != 14 or g3s.biggest9(FieldData.LAVA) > GameState.CLUMP_CAP9:
					l3_fail.append(["start", ch3, str(b3.get("how", "")), g3s.biggest9(FieldData.LAVA)])
				var plain := g3s.clone()
				var pr := RandomNumberGenerator.new()
				pr.seed = r3.seed + 77
				while not plain.day_won and plain.twists < 60:
					tw(plain, GameState.MOVES[pr.randi_range(0, GameState.MOVES.size() - 1)])
				if plain.day_won:
					l3_plain += 1
			var rr3 := _net_play(g3s, r3, 150)
			if not bool(rr3[0]):
				l3_fail.append(["play", lv3, ch3, rr3])
				break
			if lv3 < 3:
				b3 = Campaign.carry(Campaign.decode(g3s.slot_board9()), lv3 + 1, ch3 + 1000 * (lv3 + 1) + 1, ch3)
				b3["kinds"] = Campaign.decode(Campaign.encode(b3["kinds"]))
				b3 = Campaign.ensure(lv3 + 1, b3, ch3)
	print("  Level 3 aus eigener Welt: 20 Ketten, größter Lava-Klumpen %d, nur Zufallsdrehen (ohne Hilfe) in 60 gewonnen: %d/20" % [l3_clump, l3_plain])
	check(l3_fail.is_empty(), "solvable9: Level 3 nach unordentlichem Level 1–2 immer erreichbar und gewonnen (%s)" % str(l3_fail.slice(0, 3)))
	# 3. Level 3 (Nachbau): ein riesiger Lava-Klumpen aus der eigenen Welt wird geteilt, die Mischung bleibt
	var k3: Array = []
	for i in 54:
		k3.append(STONE if i % 2 == 0 else WATER)
	var g3 := camp_state(3)
	var clump_ids: Array = [0]
	var seen := {0: true}
	while clump_ids.size() < 20:
		var grew := false
		for fid in clump_ids.duplicate():
			for h in g3.nb9(int(fid)):
				if not seen.has(int(h)) and clump_ids.size() < 20:
					seen[int(h)] = true
					clump_ids.append(int(h))
					grew = true
		if not grew:
			break
	for fid2 in clump_ids:
		k3[int(fid2)] = FieldData.LAVA
	var gk := Campaign.new_state(3, {"kinds": k3, "seed": 5})
	var te3 := Time.get_ticks_usec()
	var e3 := Campaign.ensure(3, {"kinds": k3, "seed": 5, "how": "carry"}, 1)
	te3 = Time.get_ticks_usec() - te3
	var ge := Campaign.new_state(3, e3)
	var n_lava := 0
	for fd in ge.fields:
		if fd.kind == FieldData.LAVA:
			n_lava += 1
	check(gk.biggest9(FieldData.LAVA) == 20 and str(e3["how"]) == "carry" and ge.biggest9(FieldData.LAVA) <= GameState.CLUMP_CAP9
		and n_lava == 20 and bool(ge.reach9()["ok"]) and str(e3["line"]) != "",
		"solvable9: Level 3 aus der eigenen Welt: Lava-Klumpen 20 → %d geteilt, 20 Lava bleiben („%s“)" % [ge.biggest9(FieldData.LAVA), str(e3["line"])])
	# Zu wenig Lava (5 für 14 Felsen): Nachschub reicht nicht → Pool-Brett, erklärt; 10 Lava: Nachschub über Nacht
	var few: Array = []
	var some: Array = []
	for i in 54:
		few.append(FieldData.LAVA if i < 5 else (STONE if i % 3 == 0 else WATER))
		some.append(FieldData.LAVA if i % 5 == 0 and i < 50 else (STONE if i % 3 == 0 else WATER))
	var ef := Campaign.ensure(3, {"kinds": few, "seed": 2, "how": "carry"}, 2)
	var tes := Time.get_ticks_usec()
	var es := Campaign.ensure(3, {"kinds": some, "seed": 2, "how": "carry"}, 2)
	tes = Time.get_ticks_usec() - tes
	print("  Start-Check im schlimmsten Fall: Klumpen 20 teilen %.1f ms, Nachschub %.1f ms (am PC)" % [te3 / 1000.0, tes / 1000.0])
	check(te3 < 35000 and tes < 35000, "solvable9: Teilen und Nachschub beim Start unter 35 ms am PC")
	var gs_s := Campaign.new_state(3, es)
	check(str(ef["how"]) == "fallback" and str(ef["line"]) == str(Campaign.TEXT["fresh"]) and ef["kinds"] == Campaign.board(3, 2)["kinds"],
		"solvable9: zu wenig Material → das Pool-Brett, mit „%s“" % str(ef["line"]))
	check(str(es["how"]) == "carry" and not (es["fixes"] as Array).is_empty() and bool(gs_s.reach9()["ok"])
		and str(es["line"]).begins_with("Über Nacht: +") and (es["fixes"] as Array).size() <= Campaign.TOPUP_MAX,
		"solvable9: fehlende Lava kommt über Nacht (%s, %d Felder)" % [str(es["line"]), (es["fixes"] as Array).size()])
	# Ein Pool-Brett bleibt, wie es ist (es hat eine geprüfte Lösung)
	var ep := Campaign.ensure(3, Campaign.board(3, 4).merged({"how": "pool"}), 4)
	check(ep["kinds"] == Campaign.board(3, 4)["kinds"] and str(ep["line"]) == "", "solvable9: Pool-Bretter ändert ensure nie")
	# 4. Level 3 mitten im Spiel: alle Lava weg → Sackgasse in derselben Runde; das Geschenk bringt +1 Fels und Lava
	var gd := Campaign.new_state(3, Campaign.board(3, 3))
	for fd2 in gd.fields:
		if fd2.kind == FieldData.LAVA:
			gd._setk9(fd2, WATER)
	var p_d := gd.progress9()
	var plan := gd.gift_plan9()
	check(gd.stuck9() == "dead" and not bool(gd.reach9()["ok"]) and not plan.is_empty(), "solvable9: Level 3 ohne Lava ist eine erkannte Sackgasse mit Geschenk")
	var rg := gd.play({"type": "gift"})
	check(gd.progress9() == p_d + 1 and bool(gd.reach9()["ok"]) and gd.stuck9() == "" and bool(rg.get("gift", false))
		and (rg["bonus"]["fields"] as Array).size() >= 2,
		"solvable9: Geschenk = +1 Fels und Lava-Nachschub (%d → %d, %d Felder)" % [p_d, gd.progress9(), (rg["bonus"]["fields"] as Array).size()])
	# 5. Level 15 (echte Sackgasse aus der Prüfung): Quallen nur auf Ecken und Mitten, keine Kante → keine Reihe mehr
	var a16 := {}
	var gg := camp_state(15)
	var corners := 0
	var centres := 0
	for fd3 in gg.fields:
		var t := FieldData.sticker_type(fd3.p)
		if t == 3 and corners < 8:
			a16[fd3.id] = FieldData.JELLY
			corners += 1
		elif t == 1 and centres < 2:
			a16[fd3.id] = FieldData.JELLY
			centres += 1
	var g16 := camp_state(15, a16)
	g16.made[FieldData.FISH] = 5
	var r16 := g16.reach9()
	check(not bool(r16["ok"]) and str(r16.get("why", "")) == "rows" and g16.stuck9() == "dead", "solvable9: Level 15 mit Quallen ohne Kante ist eine Sackgasse (%s)" % str(r16))
	g16.play({"type": "gift"})
	check(g16.day_won, "solvable9: das Geschenk macht den sechsten Fisch")
	# Level 16: Fische nur auf Ecken verschiedener Steine → kein Schwarm aus 5 möglich
	var f17 := {}
	var cubes := {}
	for fd4 in gg.fields:
		if FieldData.sticker_type(fd4.p) == 3 and not cubes.has(fd4.p) and cubes.size() < 6:
			cubes[fd4.p] = true
			f17[fd4.id] = FieldData.FISH
	var g17 := camp_state(16, f17)
	var b0 := g17.biggest9(FieldData.FISH)
	check(not bool(g17.reach9()["ok"]) and g17.stuck9() == "dead", "solvable9: Level 16 mit Fischen nur auf Ecken ist eine Sackgasse")
	g17.play({"type": "gift"})
	check(g17.biggest9(FieldData.FISH) >= b0 + 1, "solvable9: das Geschenk lässt den Schwarm wachsen (%d → %d)" % [b0, g17.biggest9(FieldData.FISH)])
	# 6. Das Geschenk bringt in jedem Level vom Pool-Start Fortschritt (Ruhe-Ziel: ein Teilziel mehr satt)
	var no_gift: Array = []
	for n in range(1, Campaign.COUNT + 1):
		var gx := Campaign.new_state(n, Campaign.board(n, 2))
		var s0 := gx._subs_sum9()
		var p0 := gx.progress9()
		gx.play({"type": "gift"})
		if gx._subs_sum9() <= s0 and gx.progress9() <= p0:
			no_gift.append(n)
	check(no_gift.is_empty(), "gift10: das Geschenk bringt in allen %d Leveln Fortschritt (%s)" % [Campaign.COUNT, str(no_gift)])
	# 7. Stocken: STALL9 Schritte ohne neuen Fortschritt
	var gst := Campaign.new_state(5, Campaign.board(5, 1))
	gst.twists = 9
	gst.gain_at9 = 9 - GameState.STALL9
	check(gst.stuck9() == "stall" and not gst.day_won, "solvable9: %d Schritte ohne Fortschritt = festgefahren" % GameState.STALL9)


## Das Sicherheitsnetz im Spiel (Game): Sackgasse innerhalb einer Drehung gemeldet (level_dead mit "why"), Geschenk,
## Stocken, „Neue Welt“ (Pool-Brett), Welt des Tages; ohne Netz (die Tour) nur die alte Sackgasse.
func test_rescue_game() -> void:
	var t := lt(2026, 11, 12, 10)
	var g := _daily_game("user://test_rescue_game.cfg", t, true)
	g.debug_open_all = true
	var told: Array = []
	g.level_dead.connect(func(info): told.append(info))
	check(g.start_level(3) and g.level_no == 3 and g.state.target9() == 14, "Level 3: Mach 14 Felsen")
	for fd in g.state.fields:
		if fd.kind == FieldData.LAVA:
			g.state._setk9(fd, WATER)
	var res: Dictionary = g.state.play({"type": "twist", "axis": 0, "layer": 1, "turns": 1})
	g.busy = true
	g.finish_round(res)
	var info: Dictionary = told[0] if not told.is_empty() else {}
	check(told.size() == 1 and str(info.get("why", "")) == "dead" and bool(info.get("gift", false)) and str(info.get("line", "")) != ""
		and not g.rescue_offer.is_empty(), "Netz: Sackgasse nach einer Drehung gemeldet, mit Geschenk („%s“)" % str(info.get("line", "")))
	var p0: int = g.state.progress9()
	var gr: Dictionary = g.take_gift()
	g.finish_round(gr)
	check(not gr.is_empty() and g.state.progress9() == p0 + 1 and bool(g.state.reach9()["ok"]) and g.rescue_offer.is_empty()
		and told.size() == 1 and not g.busy, "Netz: Geschenk angenommen, +1 Fels, wieder erreichbar, keine zweite Meldung")
	# Stocken: STALL9 Schritte ohne neuen Fortschritt → das Angebot kommt (einmal je STALL9 Schritte)
	g.state.gain_at9 = g.state.steps9() - GameState.STALL9
	g.rescue_told_at = -99
	g._rescue_check()
	g._rescue_check()
	check(told.size() == 2 and str((told[1] as Dictionary).get("why", "")) == "stall", "Netz: festgefahren → der Charakter bietet Hilfe an (einmal)")
	# Build 14: „Weiterspielen“ – das Angebot kommt erst nach 12 Schritten wieder (nicht alle 6)
	var s_now: int = g.state.steps9()
	g.rescue_later()
	g.state.twists += 8
	g.state.gain_at9 = g.state.steps9() - 3 * GameState.STALL9
	g._rescue_check()
	var early := told.size()
	g.state.twists += 4
	g._rescue_check()
	check(g.rescue_offer.size() > 0 and early == 2 and told.size() == 3 and g.state.steps9() == s_now + GameScript.RESCUE_WAIT,
		"Netz: nach „Weiterspielen“ fragt der Charakter erst nach %d Schritten wieder (%d → %d Angebote)" % [GameScript.RESCUE_WAIT, early, told.size()])
	g.state.twists -= 12
	g.rescue_offer = {}
	# Build 14: auch wiedergewonnener Boden zählt als Fortschritt (Gruppe fällt und steigt wieder)
	var gg := Campaign.new_state(11, Campaign.board(11, 1))
	gg.twists = 20
	gg.gain_at9 = 2
	gg.sum_at9 = gg._subs_sum9() - 1
	gg._check_goal9([], true)
	check(gg.gain_at9 == gg.steps9(), "Netz: wiedergewonnener Boden zählt als Fortschritt (kein „Hängst du fest?“ beim Aufholen)")
	# Neue Welt: dasselbe Level auf einem geprüften Pool-Brett
	check(g.new_world() and g.level_no == 3 and str(g.level_board.get("how", "")) == "pool" and int(g.level_board.get("index", 0)) >= 1
		and g.state.progress9() == 0 and g.rescue_offer.is_empty(), "Netz: „Neue Welt“ startet Level 3 auf Pool-Brett %d" % int(g.level_board.get("index", -1)))
	# Ohne Netz (Tour): nur die alte Sackgasse (dead9), kein Stocken
	g.rescue_on = false
	g.state.gain_at9 = g.state.steps9() - 20
	g._rescue_check()
	check(told.size() == 3, "Netz aus: kein Angebot fürs Stocken")
	g.rescue_on = true
	# Welt des Tages: dasselbe Netz, „Neue Welt“ = ein anderes Brett derselben Vorlage
	var gw := _daily_game("user://test_rescue_wdt.cfg", t, true)
	gw.camp["veteran"] = true
	for i in Campaign.COUNT:
		(gw.camp["stars"] as Array)[i] = 2
	var told_w: Array = []
	gw.level_dead.connect(func(info2): told_w.append(info2))
	if gw.start_level_wdt():
		var tpl: int = gw.level_no
		var idx0 := int(gw.level_board.get("index", -1))
		gw.state.gain_at9 = gw.state.steps9() - GameState.STALL9
		gw._rescue_check()
		check(told_w.size() == 1 and bool((told_w[0] as Dictionary).get("wdt", false)), "Netz: auch in der Welt des Tages")
		check(gw.new_world() and gw.wdt_key >= 0 and gw.level_no == tpl and int(gw.level_board.get("index", -1)) != idx0,
			"Netz: „Neue Welt“ in der Welt des Tages = anderes Brett derselben Vorlage (%d → %d)" % [idx0, int(gw.level_board.get("index", -1))])
	else:
		check(false, "Welt des Tages startet für den Netz-Test")
	g.free()
	gw.free()


func test_texts9() -> void:
	var long: Array = []
	for t in Campaign.player_texts():
		var s := str(t)
		if s.split(" ", false).size() > 6:
			long.append(s)
	check(long.is_empty(), "texts9: jeder Spieler-Text ≤ 6 Wörter (%s)" % str(long.slice(0, 5)))
	var spoil := false
	for n in range(1, Campaign.COUNT + 1):
		var t := Campaign.tile(n, false)
		var title := str(Campaign.config(n)["title"])
		if str(t["title"]) == title or str(t["story"]) != "" or str(t["icon"]) != "lock":
			spoil = true
	var at := Campaign.act_tile(3, false)
	check(not spoil and str(at["name"]) == "?", "texts9: gesperrte Level und Akte zeigen nur „?“ und ein Schloss")


# --- Erdgeschichte (docs/GDPD_ERDGESCHICHTE.md 13) ----------------------------------------------------------------

## Ein Nachbar-Feld von f auf einem anderen Würfelchen, das nicht in avoid liegt.
func _nb_free(gs: GameState, f: int, avoid: Array) -> int:
	for g in gs.nb9(f):
		if (gs.fields[g] as FieldData).p != (gs.fields[f] as FieldData).p and not avoid.has(int(g)):
			return int(g)
	return -1


## 2 Zeitalter-Quellen: 🌲 Wald, 🐞 Insekten, ❄ Eis, 🔥 Feuerstelle, 🌾 Farn, 🍖 Saurier, 🦶 Moos.
func test_sources10() -> void:
	var cases := [[24, FieldData.FERN, FOREST, "wood"], [26, FieldData.AMPHIB, FieldData.INSECTS, "bugs"],
		[41, FieldData.MAMMOTH, FieldData.ICE, "cold"], [47, FieldData.EARLY, FieldData.CAMP, "heat"],
		[28, FieldData.SAURO, FieldData.FERN, "plants"], [29, FieldData.REX, FieldData.SAURO, "prey"],
		[25, FISH, MOSS, "shore"]]
	var bad: Array = []
	for c in cases:
		var probe := camp_state(int(c[0]))
		var nb := other_nb(probe, 4)
		var gs := camp_state(int(c[0]), {4: int(c[1]), nb: int(c[2])})
		if gs.supply9(4, str(c[3])) != 1 or gs.src_kind9(str(c[3])) != int(c[2]):
			bad.append(str(c[3]))
	check(bad.is_empty() and GameState.NEED_NAME9["wood"] == "Holz" and GameState.NEED_ICON9["cold"] == "cold",
		"sources10: neue Quellen (Holz, Insekten, Kälte, Feuer, Farn, Saurier, Moos) %s" % str(bad))
	# alte Level: dieselben Quellen wie vorher (kein altes Level hat einen der neuen Nachbarn)
	var old_ok := true
	for n in range(1, Campaign.COUNT + 1):
		var c2 := Campaign.config(n)
		if c2.get("old") == null:
			continue
		var comp: Dictionary = c2["comp"]
		for key in comp:
			var k := int(str(key))
			if k >= FieldData.JELLY and not [15, 16, 22, 25, 28, 29, 30, 31, 38, 49].has(n):
				old_ok = false
	check(old_ok, "sources10: unveränderte alte Level haben keine neuen Arten")


## 3 Jagd: Raubsaurier ≥ 3 warnen die Saurier daneben; geteilt keine Jagd; eine Herde (≥ 3) ist sicher; gejagt = Verlust.
func test_hunt10() -> void:
	var gs := camp_state(32)
	var top3: Array = []
	for fd in gs.fields:
		if fd.n == UP and fd.p.z == -1:
			fd.kind = FieldData.REX
			top3.append(fd.id)
	var prey := -1
	for fd in gs.fields:
		if fd.n == UP and fd.p.z == 0 and fd.p.x == 0:
			fd.kind = FieldData.SAURO
			fd.mk = true
			prey = fd.id
	gs.made[FieldData.SAURO] = 1
	gs._grp_ok = false
	var m := move_avoiding(gs, top3 + [prey])
	var r1 := tw(gs, m)
	var warn_ev: Dictionary = {}
	for e in r1["events"]:
		if str(e["type"]) == "pack_warn":
			warn_ev = e
	check(gs.pack_warn9.has(prey) and int(warn_ev.get("hunter", -1)) == FieldData.REX
		and Campaign.pill(warn_ev) == ["Raubsaurier jagen!", "Trenn die Raubsaurier"], "hunt10: 3 Raubsaurier warnen den Saurier daneben (%s)" % str(Campaign.pill(warn_ev)))
	var na := gs.next_action()
	check(str(na["text"]) == "Trenn die Raubsaurier!" or str(na["danger"]) != "pack", "hunt10: die Zeile nennt die Raubsaurier (%s)" % str(na["text"]))
	var g2 := gs.clone()
	var r2 := tw(gs, m)
	check(_types(r2).has("pack_hunt") and _types(r2).has("goal_loss") and (gs.fields[prey] as FieldData).kind == FieldData.FERN,
		"hunt10: eine Runde später gejagt (Saurier → Farn), ein gemachtes Ziel-Feld zählt −1")
	(g2.fields[int(top3[1])] as FieldData).kind = FieldData.EMPTY
	g2._grp_ok = false
	var r3 := tw(g2, m)
	check(not _types(r3).has("pack_hunt") and (g2.fields[prey] as FieldData).kind == FieldData.SAURO, "hunt10: getrennt → keine Jagd")
	# Herde (Level 33): ein Saurier in einer Gruppe von 3 wird nicht gewarnt, ein einzelner schon
	var gh := camp_state(33)
	var single := -1
	var herd: Array = []
	for fd in gh.fields:
		if fd.n == UP and fd.p.z == -1:
			fd.kind = FieldData.REX
		elif fd.n == UP and fd.p.z == 0:
			fd.kind = FieldData.SAURO
			herd.append(fd.id)
	gh._grp_ok = false
	var tg := gh.hunt_targets9()
	check(tg.is_empty() and gh.gsize9(int(herd[0])) == 3, "hunt10: eine Herde aus 3 ist sicher")
	(gh.fields[int(herd[0])] as FieldData).kind = WATER
	(gh.fields[int(herd[2])] as FieldData).kind = WATER
	single = int(herd[1])
	gh._grp_ok = false
	check(gh.hunt_targets9().has(single), "hunt10: ein einzelner Saurier neben dem Rudel ist Beute")
	# das alte Rudel ist dieselbe Regel (Level 38 = altes 23, pack + hunt)
	var g38 := camp_state(38)
	check(g38.hunt9.size() == 1 and int((g38.hunt9[0] as Dictionary)["hunter"]) == PRED and int((g38.hunt9[0] as Dictionary)["to"]) == MEADOW
		and bool(g38.sys9["pack"]), "hunt10: das Rudel (Level 38) ist eine Jagd: Raubtiere ≥ 3 → Tiere werden Wiese")
	var g48 := camp_state(48)
	check(int((g48.hunt9[0] as Dictionary)["hunter"]) == FieldData.EARLY and Campaign.pill({"type": "pack_warn", "hunter": FieldData.EARLY})[0] == "Die Tiere fliehen!",
		"hunt10: zu viele Jäger (Level 48) verjagen die Tiere")


## 4 Gletscher: Eis ≥ 4 warnt, eine Runde später frieren höchstens 2 Nachbarn ein (Krater zuerst); Mammut und
## Feuerstelle nie, nichts neben einer Feuerstelle; Ruhe; Eis in der Sonne taut.
func test_glacier10() -> void:
	var gs := camp_state(40)
	var ice: Array = []
	for fd in gs.fields:
		if fd.n == DOWN and fd.p.z == -1:
			fd.kind = FieldData.ICE
			ice.append(fd.id)
	var c0 := -1
	for fd in gs.fields:
		if fd.n == DOWN and fd.p.z == 0 and fd.p.x == -1:
			fd.kind = FieldData.ICE
			ice.append(fd.id)
	for fd in gs.fields:
		if fd.n == DOWN and fd.kind == WATER:
			fd.kind = ANIMALS
	gs._grp_ok = false
	check(gs.biggest9(FieldData.ICE) == 4, "glacier: Testbrett mit 4 Eis am Stück")
	var m := [1, 1, 1]           # die obere Scheibe: weit weg von der unteren Seite
	var r1 := tw(gs, m)
	var thr: Array = gs.glacier_threat9(gs.glac9)
	check(_types(r1).has("glacier_warn") and gs.glac9 >= 0 and ice.has(gs.glac9) and thr.size() == 2,
		"glacier: eine Eis-Gruppe ≥ 4 warnt („Gletscher wächst!“), 2 Felder bedroht")
	var na := gs.next_action()
	check(str(na["danger"]) != "glacier" or str(na["text"]) == "Teil das Eis!", "glacier: die Zeile „Teil das Eis!“ (%s)" % str(na["text"]))
	var gcalm := gs.clone()
	var r2 := tw(gs, m)
	var frozen := 0
	for e in r2["events"]:
		if str(e["type"]) == "freeze":
			frozen += 1
			if not thr.has(int(e["field"])):
				frozen = 99
	var rest := true
	for i in ice:
		if int(gs.glac_rest9[int(i)]) <= 0:
			rest = false
	check(frozen == 2 and rest and gs.glac9 == -1, "glacier: eine Runde später frieren genau die 2 bedrohten Nachbarn ein, die Gruppe ruht")
	# geteilt → glacier_calm
	(gcalm.fields[int(ice[0])] as FieldData).kind = WATER
	gcalm._grp_ok = false
	var r3 := tw(gcalm, m)
	check(_types(r3).has("glacier_calm") and not _types(r3).has("freeze"), "glacier: geteiltes Eis → Ruhe, nichts friert")
	# Mammut nie; nichts neben einer Feuerstelle
	var gm := camp_state(47)
	for fd in gm.fields:
		if fd.n == DOWN and fd.p.z == -1:
			fd.kind = FieldData.ICE
		elif fd.n == DOWN and fd.p.z == 0:
			fd.kind = FieldData.EARLY
		elif fd.n == DOWN and fd.p.z == 1 and fd.p.x == 0:
			fd.kind = FieldData.CAMP
	(gm.fields[gm.field_at(Vector3i(-1, -1, 0), DOWN).id] as FieldData).kind = FieldData.ICE
	gm._grp_ok = false
	var early_safe := true
	var cand: Array = []
	for fd in gm.fields:
		if fd.kind == FieldData.EARLY:
			cand.append(fd.id)
	for i in cand:
		if gm.freezable9(int(i)) == gm._next_to9(int(i), FieldData.CAMP):
			early_safe = false
	var gmm := camp_state(41, {4: FieldData.MAMMOTH})
	check(early_safe and not gmm.freezable9(4) and not camp_state(41, {4: FieldData.CAMP}).freezable9(4),
		"glacier: neben einer Feuerstelle friert nichts ein; Mammut und Feuerstelle nie")
	# Tauen: Eis auf der Sonnenseite (oben) wird nach 2 Runden Wasser (Level 40), in Level 41 nicht
	var gt := camp_state(40, {4: FieldData.ICE})
	var top := gt.field_at(UP, UP).id
	gt = camp_state(40, {top: FieldData.ICE})
	var mt := move_avoiding(gt, [top])
	var thawed := false
	for i in 2:
		for e in tw(gt, mt)["events"]:
			if str(e["type"]) == "thrive" and int(e["field"]) == top and int(e["kind"]) == WATER:
				thawed = true
	var gt2 := camp_state(40, {gt.field_at(DOWN, DOWN).id: FieldData.ICE})
	var bot := gt2.field_at(DOWN, DOWN).id
	for i in 3:
		tw(gt2, move_avoiding(gt2, [bot]))
	check(thawed and (gt.fields[top] as FieldData).kind == WATER and (gt2.fields[bot] as FieldData).kind == FieldData.ICE
		and Campaign.thrive_pill(FieldData.ICE, WATER) == "Eis taut", "thaw: Eis in der Sonne taut (spätestens nach 2 Runden), unten nie („Eis taut“)")
	var g41 := camp_state(41)
	check(not g41.thrive9.has(FieldData.ICE) and g41.rain_to9(g41.fields[4]) == -1, "thaw: in Level 41 (Höhepunkt der Eiszeit) taut nichts")
	# Teilen beim Start einer übernommenen Welt (Campaign.ensure): Eis-Klumpen über 5 werden geteilt
	var kinds: Array = []
	for i in 54:
		kinds.append(WATER)
	var probe := camp_state(41)
	var clump: Array = [0]
	var seen := {0: true}
	while clump.size() < 8:
		for fid in clump.duplicate():
			for h in probe.nb9(int(fid)):
				if not seen.has(int(h)) and clump.size() < 8:
					seen[int(h)] = true
					clump.append(int(h))
	var comp: Dictionary = Campaign.config(41)["comp"]
	var rest_k: Array = []
	for key in comp:
		for j in int(comp[key]):
			rest_k.append(int(str(key)))
	rest_k.erase(FieldData.ICE)
	var ice_n := 0
	for fid in clump:
		kinds[int(fid)] = FieldData.ICE
		ice_n += 1
	var free: Array = []
	for i in 54:
		if not seen.has(i):
			free.append(i)
	var fi := 0
	for k in rest_k:
		if int(k) == FieldData.ICE:
			continue
		kinds[int(free[fi])] = int(k)
		fi += 1
	var e3 := Campaign.ensure(41, {"kinds": kinds, "seed": 3, "how": "carry"}, 1)
	var ge := Campaign.new_state(41, e3)
	check(ge.biggest9(FieldData.ICE) <= Campaign.CLUMP_CAP_ICE or str(e3["how"]) == "fallback",
		"ensure10: ein Eis-Klumpen aus der eigenen Welt wird geteilt (%d → %d, %s)" % [8, ge.biggest9(FieldData.ICE), str(e3.get("line", ""))])


## 5 Einschlag: gewarnt vom Start, nach der ersten Drehung ist jeder Saurier Asche (Erde), kein Verlust, nur einmal.
func test_impact10() -> void:
	var b := Campaign.board(34, 0)
	var gs := Campaign.new_state(34, b)
	var dinos := 0
	for fd in gs.fields:
		if [FieldData.SAURO, FieldData.REX, FieldData.PTERO].has(fd.kind):
			dinos += 1
	var na := gs.next_action()
	check(gs.impact_pending9() and str(na["text"]) == "Dreh, der Meteor kommt" and str(na["danger"]) == "impact"
		and not (na["move"] as Dictionary).is_empty() and Campaign.PILL["impact_warn"][0] == "Meteor kommt!",
		"impact: Level 34 warnt vom Start („Dreh, der Meteor kommt“, Pille „Meteor kommt!“)")
	check(bool(gs.reach9()["ok"]) and gs.stuck9() == "", "impact: vor dem Einschlag ist das Ziel erreichbar (aus der Asche wird Wiese)")
	var before := gs.clone()
	var mv: Dictionary = na["move"]
	var r := tw(gs, [int(mv["axis"]), int(mv["layer"]), int(mv["turns"])])
	var left := 0
	for fd in gs.fields:
		if [FieldData.SAURO, FieldData.REX, FieldData.PTERO].has(fd.kind):
			left += 1
	var imp: Dictionary = {}
	for e in r["events"]:
		if str(e["type"]) == "impact":
			imp = e
	check(dinos == 15 and left == 0 and (imp.get("fields", []) as Array).size() == dinos and not _types(r).has("goal_loss")
		and gs.impact_done9 and not gs.impact_pending9() and int(gs.lost9[FieldData.MEADOW]) == 0,
		"impact: nach der ersten Drehung sind alle %d Saurier Asche, kein Verlust" % dinos)
	check(_dead_rows(gs).is_empty(), "impact: Reihen durch die neue Asche wachsen gleich (späte Runde)")
	check(str(gs.era9()["era"]) == Campaign.look_key("asche") and str(before.era9()["era"]) == Campaign.look_key("saurier")
		and bool(gs.era9().get("impact_done", false)), "impact: der Look wechselt zu Asche")
	var r2 := tw(gs, [1, 1, 1])
	check(not _types(r2).has("impact") and not before.impact_done9, "impact: nur einmal; der Stand davor (Zurück) hat ihn noch vor sich")
	var gl := GameState.load9(gs.save9(), Campaign.config(34))
	check(gl != null and gl.impact_done9 and not gl.impact_pending9(), "impact: gespeichert und geladen bleibt er geschehen")
	# Aus Asche wird Wiese: Erde mit 🌾 3 (Farn-Gruppe daneben)
	var g34 := camp_state(34, {}, {"impact": null})
	var ash := 4
	var nbs := g34.nb9(ash)
	var plants := {ash: FieldData.EMPTY}
	for j in 3:
		plants[int(nbs[j])] = FieldData.FERN
	var gp := camp_state(34, plants)
	gp.impact_done9 = true
	var mp := move_avoiding(gp, [ash, int(nbs[0]), int(nbs[1]), int(nbs[2])])
	for i in 2:
		tw(gp, mp)
	check((gp.fields[ash] as FieldData).kind == MEADOW and gp.goal_progress() >= 1 and Campaign.thrive_pill(FieldData.EMPTY, MEADOW) == "Asche wird Wiese",
		"impact: Asche mit 🌾 3 wird Wiese („Asche wird Wiese“)")


## 6 Regen lockt: ein Wald neben Farn wird Saurier (28–33), neben Wiese Tiere (40–42); sonst kein Regen.
func test_rain_kind10() -> void:
	var probe := camp_state(28)
	var f := 4
	var w := other_nb(probe, f)
	var g := camp_state(28, {f: FOREST, w: FieldData.FERN})
	g.rain = 1
	var g2 := camp_state(28, {f: FOREST, w: MEADOW})
	g2.rain = 1
	var g3 := camp_state(40, {f: FOREST, w: MEADOW})
	g3.rain = 1
	var g4 := camp_state(41, {f: WATER, w: MEADOW})
	g4.rain = 1
	check(g.rain_ok9(g.fields[f]) and g.rain_to9(g.fields[f]) == FieldData.SAURO and not g2.rain_ok9(g2.fields[f])
		and g3.rain_to9(g3.fields[f]) == ANIMALS and g4.rain_to9(g4.fields[f]) == FieldData.ICE,
		"rain_kind_cond: Regen lockt Saurier (neben Farn), Tiere (neben Wiese); Regen wird Schnee am Ufer")


## 7 Gedeihen der neuen Arten: Trilobit, Insekten, Flugsaurier, Affen, Feuerstelle; Amphibien verhungern zu Moos.
func test_thrive10() -> void:
	var cases := [[13, FieldData.JELLY, [STONE, STONE], FieldData.TRILO], [24, FieldData.FERN, [FOREST, FOREST], FieldData.INSECTS],
		[30, FOREST, [FISH, FISH], FieldData.PTERO], [43, ANIMALS, [FOREST, FOREST], FieldData.APES],
		[46, FieldData.EARLY, [STONE, FOREST], FieldData.CAMP], [22, FieldData.FERN, [WATER], FOREST]]
	var bad: Array = []
	for c in cases:
		var n := int(c[0])
		var probe := camp_state(n)
		var f := 4 if n != 22 else probe.field_at(UP, UP).id
		var set := {f: int(c[1])}
		var used: Array = []
		for src in c[2]:
			var g := _nb_free(probe, f, used)
			used.append(g)
			set[g] = int(src)
		for g2 in probe.nb9(f):
			if not set.has(int(g2)):
				set[int(g2)] = STONE if n == 22 else FieldData.EMPTY
		var gs := camp_state(n, set)
		var mv := move_avoiding(gs, [f] + used)
		var got := false
		for i in 3:
			var r := tw(gs, mv)
			for e in r["events"]:
				if str(e["type"]) == "thrive" and int(e["field"]) == f and int(e["kind"]) == int(c[3]):
					got = true
			if got:
				break
		if not got:
			bad.append([n, FieldData.kind_name(int(c[3])), (gs.fields[f] as FieldData).kind])
	check(bad.is_empty(), "thrive_new: Trilobit, Insekten, Flugsaurier, Affen, Feuerstelle, Farn → Wald im Licht (%s)" % str(bad))
	check(Campaign.thrive_pill(FieldData.FERN, FieldData.INSECTS) == "Es summt!" and Campaign.thrive_pill(FieldData.EARLY, FieldData.CAMP) == "Feuer brennt!"
		and Campaign.thrive_pill(FOREST, FieldData.PTERO) == "Flugsaurier fliegt" and Campaign.thrive_pill(FOREST, FieldData.BIRDS) == "Vögel nisten",
		"thrive_new: Pillen je Weg („Es summt!“, „Feuer brennt!“ …)")
	# Amphibie ohne Insekten verhungert zu Moos; einmal versorgt (🐞 versiegelt) nie mehr
	var ga := camp_state(26, {4: FieldData.AMPHIB})
	(ga.fields[4] as FieldData).hungry = 0
	var ma := move_avoiding(ga, [4] + Array(ga.nb9(4)))
	for i in 4:
		tw(ga, ma)
	var nb := other_nb(camp_state(26), 4)
	var gb := camp_state(26, {4: FieldData.AMPHIB, nb: FieldData.INSECTS})
	(gb.fields[4] as FieldData).hungry = 0
	tw(gb, move_avoiding(gb, [4, nb]))
	var mb := move_avoiding(gb, [4], nb)
	tw(gb, mb)
	var mb2 := move_avoiding(gb, [4])
	for i in 5:
		tw(gb, mb2)
	check((ga.fields[4] as FieldData).kind == MOSS and (gb.fields[4] as FieldData).kind == FieldData.AMPHIB and gb.satt9(4),
		"thrive_new: Amphibie ohne Insekten wird Moos; einmal versorgt bleibt sie")


## 10 Sackgassen der neuen Ziel-Arten werden erkannt, das Geschenk bringt +1 (make, group, satt); Level 53 nach
## Sticker-Art (Hütten auf Mitten, an die nie ein Wald kommt: Modell-Spiele levels10.generate(53, 47/78/84)).
func test_reach10() -> void:
	var bad: Array = []
	for n in range(1, Campaign.COUNT + 1):
		var c := Campaign.config(n)
		var g0: Array = (c["goal"] as Array)[0]
		var t := str(g0[0])
		if t != "make" and t != "group":
			continue
		var probe := camp_state(n)
		var gk := int((g0[1] as Array)[0]) if t == "make" else int(g0[1])
		var ks := {gk: true}
		var src := probe._sources9(ks, true)
		var filler := -1
		for k in [STONE, FieldData.EMPTY, LAVA, MEADOW, WATER, FieldData.CAMP, FieldData.CHURCH]:
			if not src.has(k) and k != gk and not probe.thrive9.has(k):
				filler = k
				break
		var set := {}
		if t == "group":
			var cubes := {}
			for fd in probe.fields:
				set[fd.id] = filler
				if FieldData.sticker_type(fd.p) == 3 and not cubes.has(fd.p) and cubes.size() < 6:
					cubes[fd.p] = true
					set[fd.id] = gk
		else:
			for fd in probe.fields:
				set[fd.id] = filler
		var gs := camp_state(n, set)
		if bool(gs.reach9()["ok"]):
			bad.append([n, "ok", filler])
			continue
		var p0 := gs.progress9()
		gs.play({"type": "gift"})
		if gs.progress9() < p0 + 1:
			bad.append([n, "gift", p0, gs.progress9()])
	check(bad.is_empty(), "reach10/gift10: jede Sackgasse eines make-/group-Ziels erkannt, das Geschenk bringt +1 (%s)" % str(bad.slice(0, 4)))
	# Level 53: die drei Spiele des Modells, die ohne Netz festsaßen (alle versorgten Hütten auf Mitten ohne Wald)
	var f := FileAccess.open("res://tests/data/l53_dead.json", FileAccess.READ)
	var games: Array = JSON.parse_string(f.get_as_text()) if f != null else []
	var found := 0
	for gd in games:
		var gdd: Dictionary = gd
		GameState.engine9_mode = true
		var gs2 := Campaign.new_state(53, {"kinds": Campaign.decode(str(gdd["board"])), "seed": int(gdd["seed"])})
		for a in gdd["actions"]:
			var aa: Array = a
			if str(aa[0]) == "twist":
				tw(gs2, aa[1])
			else:
				gs2.play({"type": str(aa[0]), "field": int(aa[1])})
		GameState.engine9_mode = false
		if Campaign.encode(Campaign.decode(gs2.slot_board9())) == "" or gs2.day_won:
			continue
		var r := gs2.reach9()
		var p1 := gs2.progress9()
		if not bool(r["ok"]) and gs2.stuck9() == "dead":
			gs2.play({"type": "gift"})
			if gs2.progress9() >= p1 + 1:
				found += 1
	check(games.size() == 3 and found == 3, "reach10: Level 53 – Hütten auf Mitten ohne Wald: erkannt, Geschenk +1 (%d/%d)" % [found, games.size()])


## 11 Die nächste Handlung auf jedem Pool-Brett nach jedem Schritt der Lösung (jedes vierte Brett, alle Level).
func test_next_action_all() -> void:
	var bad: Array = []
	var n_act := 0
	for n in range(1, Campaign.COUNT + 1):
		for i in range(0, Campaign.pool_size(n), 4):
			var b := Campaign.board(n, i)
			var gs := Campaign.new_state(n, b)
			for st in (b["solution"] as Array):
				var a := gs.next_action()
				n_act += 1
				var txt := str(a.get("text", ""))
				var wc := txt.split(" ", false).size()
				var why := _action_ok(gs, a)
				if txt == "" or wc > 6 or (why != "" and why != "two_fail"):
					bad.append([n, i, txt, why])
				var ab: Array = Days.solution_step(st)
				gs.play(ab[0], ab[1])
				if gs.day_won:
					break
	check(bad.is_empty(), "next_action_all: %d Stände auf allen Leveln, immer ≤ 6 Wörter und möglich (%s)" % [n_act, str(bad.slice(0, 3))])


## Review (Level 55 „Frieden“): Oben steht nie die allgemeine Ersatz-Zeile („Dreh weiter, Regen kommt“ / „Dreh eine
## Scheibe“), solange eine einzige Drehung ein Teilziel steigen lässt. Jedes zweite Pool-Brett, jeder Schritt der Lösung.
func test_next_action_concrete() -> void:
	var bad: Array = []
	var states := 0
	var generic := 0
	for n in range(1, Campaign.COUNT + 1):
		for i in range(1, Campaign.pool_size(n), 2):
			var b := Campaign.board(n, i)
			var gs := Campaign.new_state(n, b)
			for st in (b["solution"] as Array):
				if gs.day_won:
					break
				states += 1
				var t := str(gs.next_action().get("text", ""))
				if t == "Dreh weiter, Regen kommt" or t == "Dreh eine Scheibe":
					generic += 1
					var s0 := _subs_sum(gs)
					for m in GameState.MOVES:
						var c := gs.clone()
						tw(c, m)
						if _subs_sum(c) > s0 or c.day_won:
							bad.append([n, i, states, m])
							break
				var ab: Array = Days.solution_step(st)
				gs.play(ab[0], ab[1])
	check(bad.is_empty(), "next_action_concrete: %d Stände, %d allgemein, nie, wenn eine Drehung hilft (%s)" % [states, generic,
		str(bad.slice(0, 3))])
	# Level 55 (zwei satt-Ziele Stadt + Dorf, beide Ziel-Arten): am Start eine konkrete Drehung
	var g55 := Campaign.new_state(55, Campaign.board(55, 0))
	var a55 := g55.next_action()
	check(not (a55.get("move", {}) as Dictionary).is_empty() and str(a55["text"]) != "Dreh weiter, Regen kommt",
		"next_action_concrete: Level 55 nennt eine Drehung (%s)" % str(a55["text"]))


func _subs_sum(gs: GameState) -> int:
	var s := 0
	for v in gs.sub_values9():
		s += int(v)
	return s


## 13 Keine Genesis-Wörter in den Spieler-Texten; Texte kurz; Zeitalter ohne Spoiler.
func test_texts10() -> void:
	var bad: Array = []
	var re := RegEx.new()
	re.compile("Tag [1-7]\\b|Schöpfung|siebte|Und es war gut|Genesis|\\bRuhe\\b|\\bruhen\\b")
	var all: Array = Campaign.player_texts()
	for k in Days.TEXT:
		if ["today_new", "today_done", "today", "wdt", "wdt_tomorrow", "complete", "wdt_first_tomorrow"].has(str(k)):
			all.append(str(Days.TEXT[k]))
	all.append(Campaign.TEXT["title"])
	for t in all:
		if re.search(str(t)) != null:
			bad.append(str(t))
	var long: Array = []
	for t in Campaign.player_texts():
		if str(t).split(" ", false).size() > 8:
			long.append(str(t))
	check(bad.is_empty() and long.is_empty(), "texts10: keine Genesis-Wörter, nie mehr als 8 Wörter (%s %s)" % [str(bad.slice(0, 3)), str(long.slice(0, 3))])
	var spoil := false
	for e in range(1, Campaign.era_count() + 1):
		var t2 := Campaign.era_tile(e, false)
		if str(t2["name"]) != "?" or str(t2["icon"]) != "lock" or not (t2["levels"] as Array).is_empty() or str(t2["id"]) != "":
			spoil = true
	check(not spoil and Campaign.era_count() == 20 and Campaign.COUNT == 60 and str(Campaign.era_info(9)["title"]) == "Saurierzeit"
		and Campaign.era_of(34) == "meteor" and Campaign.era_index(60) == 20, "texts10: 20 Zeitalter, 60 Level; gesperrte Zeitalter nur „?“")
	# Geschichten nie doppelt: keine gleicht ihrer Zeitalter-Zeile, einer anderen Geschichte oder dem eigenen Titel
	var seen := {}
	var dup: Array = []
	for n in range(1, Campaign.COUNT + 1):
		var c := Campaign.config(n)
		var st := str(c.get("story", "")).trim_suffix(".")
		var eline := str(Campaign.era_info(Campaign.era_index(n)).get("line", "")).trim_suffix(".")
		if st == "" or st == eline or seen.has(st) or st == str(c.get("title", "")):
			dup.append("%d:%s" % [n, st])
		seen[st] = true
	check(dup.is_empty(), "texts10: jede Geschichte einmalig, nie gleich Zeitalter-Zeile oder Titel (%s)" % str(dup.slice(0, 4)))


## 15 Ein neues Level je Spieltag bis 60; die Kette springt über schon geschaffte (nach der Umstellung) am selben Tag.
func test_unlock60() -> void:
	var c := GameScript.fresh_camp()
	check((c["stars"] as Array).size() == Campaign.COUNT and Daily.level_unlocked(c, 1, 100) and not Daily.level_unlocked(c, 2, 100),
		"unlock60: am Anfang ist nur Level 1 offen")
	var day := 100
	var ok := true
	for n in range(1, Campaign.COUNT + 1):
		if not Daily.level_unlocked(c, n, day) or (n < Campaign.COUNT and Daily.level_unlocked(c, n + 1, day)):
			ok = false
		(c["stars"] as Array)[n - 1] = 2
		Daily.register_level_win(c, n, day)
		if n < Campaign.COUNT and (Daily.level_unlocked(c, n + 1, day) or not Daily.new_level_tomorrow(c, day)):
			ok = false
		day += 1
	check(ok and int(c["pos"]) == Campaign.COUNT and Daily.all_won(c) and not Daily.wdt_available_camp(c, day - 1)
		and Daily.wdt_available_camp(c, day), "unlock60: ein neues Level je Spieltag bis %d, danach die Welt des Tages" % Campaign.COUNT)
	# Kette über schon geschaffte: Level 5 schon geschafft (z. B. alt), Kette bei 3 → am nächsten Tag öffnen 4 (neu)
	var k := GameScript.fresh_camp()
	for n2 in [1, 2, 3, 5, 6]:
		(k["stars"] as Array)[n2 - 1] = 2
	k["pos"] = 3
	k["last_new_key"] = 10
	check(Daily.next_new_level(k) == 4 and not Daily.level_unlocked(k, 5, 10) and Daily.level_unlocked(k, 3, 10), "unlock60: Level 5 (schon geschafft) bleibt versteckt")
	(k["stars"] as Array)[3] = 1
	Daily.register_level_win(k, 4, 11)
	check(int(k["pos"]) == 4 and Daily.next_new_level(k) == 7 and not Daily.level_unlocked(k, 5, 11) and Daily.level_unlocked(k, 5, 12)
		and Daily.level_unlocked(k, 6, 12) and Daily.level_unlocked(k, 7, 12) and not Daily.level_unlocked(k, 8, 12),
		"unlock60: am nächsten Spieltag öffnen 5 und 6 (geschafft) mit dem neuen Level 7")
	# Nachholen zählt nicht als neues Level des Tages
	var h := GameScript.fresh_camp()
	for n3 in [1, 2, 4]:
		(h["stars"] as Array)[n3 - 1] = 2
	h["pos"] = 4
	h["last_new_key"] = 20
	check(Daily.catchup(h, 3) and Daily.level_unlocked(h, 3, 20) and Daily.next_new_level(h) == 5, "unlock60: Level 3 offen zum Nachholen")
	(h["stars"] as Array)[2] = 3
	Daily.register_level_win(h, 3, 21)
	check(int(h["pos"]) == 4 and int(h["last_new_key"]) == 20 and Daily.level_unlocked(h, 5, 21), "unlock60: ein Sieg beim Nachholen sperrt das neue Level nicht")
	# Schnellstart: 3 neue Level je Spieltag bis fast_to
	var f := GameScript.fresh_camp()
	f["fast_to"] = 8
	for n in [1, 2, 3]:
		check(Daily.level_unlocked(f, n, 200), "fasttrack: Level %d heute offen" % n)
		(f["stars"] as Array)[n - 1] = 1
		Daily.register_level_win(f, n, 200)
	check(not Daily.level_unlocked(f, 4, 200) and Daily.level_unlocked(f, 4, 201), "fasttrack: höchstens 3 neue je Spieltag")
	# Welt des Tages: Vorlagen (eine je Zeitalter), nur aus geschafften Leveln
	var v := GameScript.fresh_camp()
	v["veteran"] = true
	check(not Daily.wdt_available_camp(v, 5), "wdt: Veteran auf Level 1: noch keine Welt des Tages (nie spoilern)")
	for n0 in [1, 2, 3]:
		(v["stars"] as Array)[n0 - 1] = 2
	check(Daily.wdt_available_camp(v, 5), "wdt: Veteran mit Level 3 geschafft: Welt des Tages")
	var vmax := 0
	for kk in range(0, 40):
		vmax = maxi(vmax, Campaign.wdt_template(kk, v["stars"]))
	check(vmax == 3 and Campaign.wdt_config(7, "", v["stars"]).get("level", 0) == 3 and not Campaign.wdt_board(7, v["stars"]).is_empty(),
		"wdt: Veteran sieht nur Vorlagen aus geschafften Leveln (höchstens %d)" % vmax)
	check(Campaign.WDT == [3, 7, 11, 14, 16, 20, 23, 27, 32, 35, 38, 40, 44, 47, 48, 51, 54, 56, 58, 59]
		and Campaign.wdt_board_index(0) >= 1 and Campaign.wdt_template(0) != Campaign.wdt_template(1), "wdt: 20 Vorlagen (eine je Zeitalter), nie Brett 0")


## 14 Umstellung „Die Schöpfung“ (30 Level) → „Erdgeschichte“ (60): Sterne, Schritte, Siegtage und bezahlte Punkte
## wandern mit; Position P, „Nachholen“, versteckte geschaffte Level; zweites Laden ändert nichts.
func test_migrate_erde() -> void:
	var path := "user://test_migrate_erde.cfg"
	check(Campaign.old_to_new(1) == 1 and Campaign.old_to_new(7) == 8 and Campaign.old_to_new(14) == 50 and Campaign.old_to_new(23) == 38
		and Campaign.old_to_new(30) == 60 and Campaign.pos_of_old(19) == 25 and Campaign.pos_of_old(24) == 49 and Campaign.pos_of_old(30) == 60
		and Campaign.pos_of_old(13) == 22 and Campaign.pos_of_old(18) == 22, "migrate_erde: OLD_TO_NEW und POS_OF_OLD aus den Daten")
	var t := lt(2026, 11, 12, 10)
	var cfg := ConfigFile.new()
	var st: Array = []
	var sp: Array = []
	var wk: Array = []
	var lb: Array = []
	for j in 30:
		st.append(2 if j < 19 else 0)
		sp.append(5 + j if j < 19 else 0)
		wk.append(20000 + j if j < 19 else -1)
		lb.append(60 + j if j < 19 else 0)
	(st as Array)[13] = 3
	cfg.set_value("konto", "version", 2)
	cfg.set_value("konto", "punkte", 777)
	cfg.set_value("punkte", "level_best", lb)
	cfg.set_value("punkte", "extras", [])
	cfg.set_value("kampagne", "version", 1)
	cfg.set_value("kampagne", "sterne", st)
	cfg.set_value("kampagne", "schritte", sp)
	cfg.set_value("kampagne", "gewonnen_am", wk)
	cfg.set_value("kampagne", "letzter_neuer", Daily.day_key(t) - 1)
	cfg.set_value("kampagne", "welt", "R".repeat(54))
	cfg.set_value("kampagne", "welt_level", 19)
	cfg.set_value("kampagne", "start", Campaign.board(28, 1)["board"])
	cfg.set_value("kampagne", "start_level", 20)
	cfg.set_value("kampagne", "brett", [])
	cfg.save(path)
	# ein laufender Versuch des alten Levels 20 liegt daneben
	var run := ConfigFile.new()
	run.set_value("lauf", "daten", {"v": 1, "level": 20, "wdt": -1, "cfg": "x", "state": {}})
	run.save(path.get_basename() + "_lauf.cfg")
	var g := _daily_game(path, t, false)
	var c: Dictionary = g.camp
	var cu: Array = []
	for n in range(1, 25):
		if g.level_unlocked(n) and g.level_stars(n) == 0:
			cu.append(n)
	check(int(c["pos"]) == 25 and cu == [7, 11, 12, 13, 14, 17, 20, 23, 24], "migrate_erde: altes 1–19 → Position 25, Nachholen %s" % str(cu))
	check(g.level_stars(22) == 2 and g.level_stars(25) == 2 and g.level_stars(30) == 2 and g.level_stars(50) == 3 and g.level_stars(51) == 2
		and int((c["steps"] as Array)[24]) == 5 + 18 and int((c["won_key"] as Array)[49]) == 20013, "migrate_erde: Sterne, Schritte, Siegtage wandern mit")
	check(not g.level_unlocked(26) and not g.level_unlocked(30) and not g.level_unlocked(50) and g.new_level_tomorrow(),
		"migrate_erde: Level 26 erst am nächsten Spieltag; 30, 50, 51 geschafft aber versteckt")
	check(g.points == 777 and int((g.pdata["level_best"] as Array)[49]) == 73 and int((g.pdata["level_best"] as Array)[13]) == 0,
		"migrate_erde: Punkte bleiben, bestes bezahltes Ergebnis wandert mit (nichts wird neu bezahlt)")
	check(str(c["world"]) == "R".repeat(54) and int(c["world_level"]) == 25 and str(c["start"]) == Campaign.board(28, 1)["board"]
		and int(c["start_level"]) == 28 and g.saved_run().is_empty(),
		"migrate_erde: die Welt von 19 (→ 25) passt vor 26; Start-Brett mit gleicher Mischung bleibt (20 → 28); laufender Versuch neu")
	var ov: Dictionary = g.campaign_overview()
	var shown := ""
	for a in ov["eras"]:
		shown += str((a as Dictionary)["name"]) + ","
	check(g.take_migrated() and not g.take_migrated() and shown.begins_with("Urerde,Urozean") and not shown.contains("Saurierzeit")
		and shown.ends_with("?,"), "migrate_erde: „Die Welt ist größer geworden.“ einmal; Zeitalter bis zur Position, dann „?“ (%s)" % shown)
	var ti: Dictionary = g.camp_today_info()
	check(str(ti["state"]) == "catchup" and int(ti["day"]) == 7 and str(ti["caps"]) == "Nachholen · Level 7",
		"migrate_erde: Heute-Karte bietet das erste Nachholen an (%s %s)" % [str(ti["state"]), str(ti.get("day", ""))])
	g._save_profile()
	g.free()
	var g2 := _daily_game(path, t, false)
	check(int(g2.camp["pos"]) == 25 and g2.level_stars(50) == 3 and g2.points == 777, "migrate_erde: zweites Laden ändert nichts")
	g2.clock_override = t + Daily.DAY
	check(g2.level_unlocked(26) and not g2.level_unlocked(27) and g2.current_level() == 26, "migrate_erde: am nächsten Spieltag Level 26")
	var on_r := Balance.CAMPAIGN_ON
	Balance.CAMPAIGN_ON = true
	var rtag: String = g2.reminder_tag()
	Balance.CAMPAIGN_ON = on_r
	check(rtag == "Level 26" and not rtag.contains(str(Campaign.config(26).get("title", "x"))) and not rtag.contains("Tag"),
		"migrate_erde: Erinnerungen nennen nur die Nummer des nächsten Levels (%s)" % rtag)
	g2.free()
	# alte Kampagne fertig (30 Level): alles offen, Welt des Tages bleibt
	var c3 := ConfigFile.new()
	var st3: Array = []
	var wk3: Array = []
	for j in 30:
		st3.append(1)
		wk3.append(20000 + j)
	c3.set_value("kampagne", "version", 1)
	c3.set_value("kampagne", "sterne", st3)
	c3.set_value("kampagne", "gewonnen_am", wk3)
	c3.set_value("kampagne", "letzter_neuer", 20029)
	c3.save(path)
	var g3 := _daily_game(path, t, false)
	var all_open := true
	for n in range(1, Campaign.COUNT + 1):
		if not g3.level_unlocked(n):
			all_open = false
	check(int(g3.camp["pos"]) == 60 and all_open and Daily.wdt_available_camp(g3.camp, g3.today_key()) and not Daily.all_won(g3.camp),
		"migrate_erde: alte Kampagne fertig → alle 60 offen (30 zum Nachholen), Welt des Tages bleibt")
	g3.free()
	# alt 1–6 geschafft (nichts nachzuholen): am Tag der Umstellung öffnet Level 7 wie im alten Build (keine leere Karte)
	var c4 := ConfigFile.new()
	var st4: Array = []
	var wk4: Array = []
	for j in 30:
		st4.append(2 if j < 6 else 0)
		wk4.append(20000 + j if j < 6 else -1)
	c4.set_value("kampagne", "version", 1)
	c4.set_value("kampagne", "sterne", st4)
	c4.set_value("kampagne", "gewonnen_am", wk4)
	c4.set_value("kampagne", "letzter_neuer", Daily.day_key(t) - 1)
	c4.save(path)
	var g4 := _daily_game(path, t, false)
	var ti4: Dictionary = g4.camp_today_info()
	check(int(g4.camp["pos"]) == 6 and g4.level_unlocked(7) and str(ti4["state"]) == "new" and int(ti4["day"]) == 7,
		"migrate_erde: alt 1–6 → Level 7 heute offen (%s %s)" % [str(ti4["state"]), str(ti4.get("day", ""))])
	g4.free()
	# alt 1–20 geschafft (alt 18 → 30, geschafft aber versteckt): nach dem Sieg „Nochmal“ spielt das gerade geschaffte
	# Level (nie ein gesperrtes), und „mehr Sterne“ kommt durch (merge überschreibt)
	var c5 := ConfigFile.new()
	var st5: Array = []
	var wk5: Array = []
	for j in 30:
		st5.append(2 if j < 20 else 0)
		wk5.append(20000 + j if j < 20 else -1)
	c5.set_value("kampagne", "version", 1)
	c5.set_value("kampagne", "sterne", st5)
	c5.set_value("kampagne", "gewonnen_am", wk5)
	c5.set_value("kampagne", "letzter_neuer", Daily.day_key(t) - 1)
	c5.save(path)
	var g5 := _daily_game(path, t, false)
	var cu5: int = g5.first_catchup()
	var guard := 0
	while cu5 > 0 and guard < 20:
		(g5.camp["stars"] as Array)[cu5 - 1] = 2
		cu5 = g5.first_catchup()
		guard += 1
	g5.clock_override = t + Daily.DAY
	var nl: int = g5.current_level()
	(g5.camp["stars"] as Array)[nl - 1] = 2
	Daily.register_level_win(g5.camp, nl, g5.today_key())
	var ti5: Dictionary = g5.camp_today_info()
	var rd := int(ti5.get("replay_day", -1))
	check(str(ti5["state"]) == "done_next" and rd >= 1 and g5.level_unlocked(rd) and bool(ti5.get("more_stars", false)),
		"migrate_erde: nach dem Sieg „Nochmal · mehr Sterne“ für ein offenes Level (%s %d offen=%s mehr=%s)" % [str(ti5["state"]), rd,
		str(g5.level_unlocked(maxi(rd, 1))), str(ti5.get("more_stars", ""))])
	g5.free()
	DirAccess.remove_absolute(path)


## Spielstand v2 → v3 (GDPD_SCHOEPFUNG.md 13.1, GDPD_PUNKTE_LADEN.md 8.2): Münzen → Punkte, alte Sterne → Punkte,
## alte Tage → Schnellstart, alle 7 Tage → Welt des Tages bleibt.
func test_migrate_v3() -> void:
	var path := "user://test_migrate_v3.cfg"
	var cfg := ConfigFile.new()
	cfg.set_value("konto", "credits", 7)
	cfg.set_value("schoepfung", "sterne", [3, 2, 0, 0, 0, 0, 0])
	cfg.set_value("schoepfung", "frei", 3)
	cfg.set_value("schoepfung", "fertig", false)
	cfg.set_value("schoepfung", "version", 2)
	cfg.set_value("taeglich", "bau_muenzen", [20400, 2])
	cfg.save(path)
	var g := _daily_game(path, lt(2026, 11, 12, 9), false)
	check(g.points == 140 + 5 * 20 and g.credits == g.points and g.points_migrated == g.points, "migrate_v3: 7 Münzen → 140 Punkte, + 20 je alter Stern (%d)" % g.points)
	check(int(g.camp["fast_to"]) == 9 and not bool(g.camp["veteran"]) and int(g.camp["thanks"]) == 100 and g.level_unlocked(1)
		and not g.level_unlocked(2), "migrate_v3: alte Tage 1–2 → Schnellstart bis Level 9, Level 1 offen")
	check(int((g.pdata["heute"] as Array)[1]) == 20, "migrate_v3: Bau-Münzen von heute → Weiterbauen-Zähler")
	g._save_profile()
	g.free()
	var c2 := ConfigFile.new()
	c2.load(path)
	check(int(c2.get_value("konto", "version", 0)) == 2 and int(c2.get_value("konto", "punkte", 0)) == 240
		and not c2.has_section_key("konto", "credits") and c2.has_section("kampagne") and c2.has_section("punkte")
		and int(c2.get_value("schoepfung", "version", 0)) == 3, "migrate_v3: [konto] punkte, version 2, credits weg, [kampagne] und [punkte] da")
	var g2 := _daily_game(path, lt(2026, 11, 12, 9), false)
	check(g2.points == 240 and int(g2.camp["fast_to"]) == 9, "migrate_v3: zweites Laden ändert nichts")
	g2.free()
	# alle 7 Tage geschafft: Schnellstart bis 28, die Welt des Tages bleibt
	var c3 := ConfigFile.new()
	c3.set_value("konto", "credits", 1)
	c3.set_value("schoepfung", "sterne", [3, 3, 2, 2, 1, 1, 1])
	c3.set_value("schoepfung", "fertig", true)
	c3.save(path)
	var g3 := _daily_game(path, lt(2026, 11, 12, 9), false)
	check(g3.points == 60 + 13 * 20 and int(g3.camp["fast_to"]) == 57 and bool(g3.camp["veteran"])
		and not Daily.wdt_available_camp(g3.camp, g3.today_key()), "migrate_v3: alle 7 Tage → Schnellstart bis 57, Welt des Tages ab dem ersten Vorlage-Level")
	g3.free()
	# neuer Spieler: 60 Punkte, kein Schnellstart
	var g4 := _daily_game(path, lt(2026, 11, 12, 9), true)
	check(g4.points == Balance.POINTS_START and int(g4.camp["fast_to"]) == 0 and g4.current_level() == 1, "neuer Spieler: 60 Punkte, Level 1")
	g4.free()
	DirAccess.remove_absolute(path)


## Ein Level im Game: Start (Tutorial-Brett), Sieg mit der Pool-Lösung, Sterne, Punkte, ein neues Level je Spieltag,
## die Welt läuft weiter, Speichern und Laden.
func test_level_game() -> void:
	var path := "user://test_level_game.cfg"
	var t := lt(2026, 11, 12, 10)
	var g := _daily_game(path, t, true)
	var p0: int = g.points
	check(g.start_level(1) and g.state.camp and g.level_no == 1 and int(g.level_board["index"]) == 0
		and not (g.level_info()["tutorial"] as Dictionary).is_empty(), "Level 1 beginnt auf dem Tutorial-Brett")
	var won := []
	g.day_won.connect(func(info): won.append(info))
	_replay_in_game(g)
	var info: Dictionary = won[0] if not won.is_empty() else {}
	var pts := int(info.get("points", 0))
	check(g.state.day_won and g.level_stars(1) == g.state.stars() and pts == g.state.level_points()
		and g.points == p0 + pts + Points.streak_bonus(1) and int((g.pdata["level_best"] as Array)[0]) == pts,
		"Sieg: Sterne, Punkte %d (+%d Serie) gutgeschrieben" % [pts, Points.streak_bonus(1)])
	check(not (info.get("lines", []) as Array).is_empty() and str((info["lines"] as Array)[0][0]) == "win_done", "Sieg-Karte: Punkte-Zeilen")
	check(not g.level_unlocked(2) and g.new_level_tomorrow() and str(g.camp["world"]).length() == 54, "Level 2 erst morgen; die Welt ist gespeichert")
	# Build 12: kein Weiterbauen – die Welt von morgen ist die Welt beim Sieg
	check(not g.has_method("continue_build") and not g.state.day_free_build and not g.has_method("resume_build")
		and g.saved_run().is_empty(), "Build 12: kein Weiterbauen im Level, kein laufender Versuch nach dem Sieg")
	check(str(g.camp["world"]) == g.state.slot_board9(), "Build 12: die Welt beim Sieg trägt ins nächste Level")
	var w1 := str(g.camp["world"])
	# nächster Spieltag: Level 2 offen, getragene Welt (oder Pool-Brett)
	g.clock_override = t + Daily.DAY
	check(g.level_unlocked(2) and g.start_level(2) and g.state.camp and g.level_no == 2, "nächster Spieltag: Level 2 offen")
	var how := str(g.level_board.get("how", ""))
	check(how == "carry" or how == "fallback", "Level 2 startet auf der Welt von gestern (%s)" % how)
	var kinds0: Array = []
	for fd in g.state.fields:
		kinds0.append(fd.kind)
	g.state.play({"type": "twist", "axis": 1, "layer": 1, "turns": 1})
	check(g.retry_level() and Campaign.encode(kinds0) == str(g.camp["start"]), "Nochmal: dasselbe Start-Brett")
	var same := true
	for fd in g.state.fields:
		if fd.kind != int(kinds0[fd.id]):
			same = false
	check(same, "Nochmal: dieselben Arten")
	g._save_profile()
	g.free()
	var g2 := _daily_game(path, t + Daily.DAY, false)
	check(g2.level_stars(1) > 0 and str(g2.camp["start"]) == Campaign.encode(kinds0) and int(g2.camp["start_level"]) == 2
		and str(g2.camp["world"]) == w1 and g2.current_level() == 2, "Speichern/Laden: Sterne, Welt und Start-Brett bleiben")
	check(g2.start_level(2) and str(g2.level_board["how"]) == "stored", "Neustart der App: das gleiche Start-Brett")
	var ov: Dictionary = g2.campaign_overview()
	var locked_ok := true
	for a in ov["acts"]:
		for lv in (a as Dictionary)["levels"]:
			var ld: Dictionary = lv
			if not bool(ld["open"]) and str(ld["title"]) != "?":
				locked_ok = false
	var eras_ov: Array = ov["eras"]
	check(locked_ok and (ov["acts"] as Array).size() == Campaign.era_count() and str(((ov["acts"] as Array)[6] as Dictionary)["name"]) == "?"
		and eras_ov.size() == 2 and str((eras_ov[0] as Dictionary)["name"]) == "Urerde" and str((eras_ov[1] as Dictionary)["name"]) == "?"
		and ((eras_ov[1] as Dictionary)["levels"] as Array).is_empty(),
		"Übersicht: ein erreichtes Zeitalter „Urerde“ und eine „?“-Kachel; gesperrte Level und Zeitalter nur „?“ (kein Spoiler)")
	# Die Welt für morgen kommt nur aus dem neuesten Level: Level 2 geschafft, dann Level 1 wiederholt → bleibt Level 2
	g2.start_level(2, 1)
	_replay_in_game(g2)
	var w2 := str(g2.camp["world"])
	var wl2 := int(g2.camp["world_level"])
	g2.clock_override = t + 2 * Daily.DAY
	g2.start_level(1, 1)
	_replay_in_game(g2)
	check(g2.level_stars(2) > 0 and wl2 == 2 and int(g2.camp["world_level"]) == 2 and str(g2.camp["world"]) == w2,
		"Welt von morgen: eine Wiederholung von Level 1 überschreibt die Welt von Level 2 nicht")
	g2.free()
	DirAccess.remove_absolute(path)


# --- Build 12 ------------------------------------------------------------------------------------------------------

## Reihen, die nicht zählen: nach jeder Aktion keine Reihe auf dem Brett, die nicht schon gewachsen ist.
func _dead_rows(gs: GameState) -> Array:
	var out: Array = []
	for ln in gs.lines():
		if not gs.spent.has(GameState.line_key(ln)):
			out.append(ids(ln))
	return out


func _has_late_merge(r: Dictionary) -> bool:
	for e in r["events"]:
		if str(e["type"]) == "merge" and bool(e.get("late", false)):
			return true
	return false


## „Drei gleiche in einer geraden Reihe wachsen immer“: Reihen, die die Welt am Rundenende bildet (Abkühlen, Ausbruch,
## Landgang …), wachsen sofort; Geschenk und Meteor lösen ihre Reihen auf; eine gewachsene Reihe, die ein Ausbruch
## zurückbringt, wächst wieder; niemand wird für eine Reihe getadelt, die nie wachsen konnte.
func test_rows_build12() -> void:
	# Spieler-Fall (Investigation): Level 5, Brett 0 – Lava kühlt zu einer Fels-Reihe, die früher still stehen blieb
	var g5 := Campaign.new_state(5, Campaign.board(5, 0))
	tw(g5, [0, -1, 2])
	var r5 := tw(g5, [1, 1, 1])
	var trio := [(g5.fields[22] as FieldData).kind, (g5.fields[26] as FieldData).kind, (g5.fields[49] as FieldData).kind]
	check(_dead_rows(g5).is_empty() and _has_late_merge(r5) and trio != [STONE, STONE, STONE],
		"rows12: abgekühlte Fels-Reihe (22, 26, 49) wächst sofort (spät) – keine stille Reihe (%s, %s)" % [str(trio), str(_dead_rows(g5))])
	var g5m := Campaign.new_state(5, Campaign.board(5, 0))
	GameState.engine9_mode = true
	tw(g5m, [0, -1, 2])
	tw(g5m, [1, 1, 1])
	GameState.engine9_mode = false
	check(not _dead_rows(g5m).is_empty(), "rows12: im Modell-Modus bleibt die alte Regel (Abgleich mit engine9)")
	# Level 4 und 3, Brett 0: der Ausbruch macht Lava-Reihen – sie wachsen sofort
	var ok_e := true
	for n in [3, 4]:
		var ge := Campaign.new_state(n, Campaign.board(n, 0))
		tw(ge, [0, -1, 1])
		tw(ge, [0, -1, 1])
		if not _dead_rows(ge).is_empty():
			ok_e = false
	var g4 := Campaign.new_state(4, Campaign.board(4, 0))
	tw(g4, [0, 0, -1])
	tw(g4, [0, -1, 1])
	check(ok_e and _dead_rows(g4).is_empty(), "rows12: Ausbruch-Reihen (Level 3/4) und wiederkehrende Reihen wachsen, keine stille Reihe")
	# Akt 1 und mehr: Pool-Bretter, zufällig gespielt, mit Geschenk und Regen – nach jeder Aktion keine stille Reihe
	var rng := RandomNumberGenerator.new()
	rng.seed = 1212
	var acts := 0
	var dead: Array = []
	var gifts := 0
	var repeat_bad := 0
	for n2 in [1, 2, 3, 4, 5, 9, 11, 12, 19, 24, 28]:
		for i2 in 4:
			var gs := Campaign.new_state(int(n2), Campaign.board(int(n2), i2))
			if not gs.lines().is_empty():
				dead.append(["start", n2, i2])
			for k in 30:
				if gs.day_won:
					break
				var r: Dictionary
				if gs.rain > 0 and rng.randf() < 0.2:
					var spot := -1
					for f in gs.fields:
						if gs.rain_ok9(f):
							spot = f.id
							break
					r = gs.play({"type": "rain", "field": spot}) if spot >= 0 else tw(gs, GameState.MOVES[rng.randi_range(0, 26)])
				elif k % 9 == 8 and not gs.gift_plan9().is_empty():
					r = gs.play({"type": "gift"})
					gifts += 1
				else:
					r = tw(gs, GameState.MOVES[rng.randi_range(0, 26)])
				acts += 1
				var d := _dead_rows(gs)
				if not d.is_empty():
					dead.append([n2, i2, k, d])
				for e in r["events"]:
					if str(e["type"]) == "still" and str(e["why"]) == "repeat" and not gs.spent.has(GameState._key9(int(e["fields"][0]), int(e["fields"][1]), int(e["fields"][2]), int(e["kind"]))):
						repeat_bad += 1
	check(dead.is_empty() and acts > 500 and gifts > 0, "rows12: %d Aktionen (Drehen, Regen, %d Geschenke) ohne stille Reihe (%s)" % [acts, gifts, str(dead.slice(0, 3))])
	check(repeat_bad == 0, "rows12: „Zurückgedreht“ nur für Reihen, die schon gewachsen sind (%d falsch)" % repeat_bad)
	# Getragene Welten aus Akt 1 (carry + ensure): keine fertige Reihe am Start
	var carried_rows := 0
	for ch in 6:
		var b: Dictionary = Campaign.board(1, 1 + ch)
		b["how"] = "pool"
		var cr := RandomNumberGenerator.new()
		cr.seed = 77 + ch
		for lv in [1, 2, 3, 4, 5]:
			var gc := Campaign.new_state(lv, b)
			if not gc.lines().is_empty():
				carried_rows += 1
			_net_play(gc, cr, 120)
			if lv < 5:
				b = Campaign.carry(Campaign.decode(gc.slot_board9()), lv + 1, ch + 1000 * (lv + 1) + 1, ch)
				b = Campaign.ensure(lv + 1, b, ch)
	check(carried_rows == 0, "rows12: getragene Welten in Akt 1 starten ohne fertige Reihe (%d)" % carried_rows)
	# Meteor schließt 3 Erde (Level 23: Erde → Wiese): die Reihe wächst sofort
	var g0 := camp_state(38)
	var f0: FieldData = g0.fields[4]
	var row_m: Array = []
	for along in 3:
		var ln0 := g0.line_through(f0, along)
		if ln0.size() == 3 and row_m.is_empty():
			row_m = ln0
	var third := int(row_m[2]) if row_m.size() == 3 else -1
	var gm := camp_state(38, {int(row_m[0]): E, int(row_m[1]): E, third: FOREST} if third >= 0 else {})
	if third >= 0:
		gm.meteors = 1
		var rm := gm.play({"type": "meteor", "field": third})
		check(_types(rm).has("merge") and _dead_rows(gm).is_empty(), "rows12: Meteor macht 3 Erde in einer Reihe → sie wächst sofort")
	else:
		check(false, "rows12: Meteor-Aufbau (Reihe mit Feld 0 und 1 gefunden)")
	# Texte: eine stille Reihe sagt immer, warum (Fels im Ziel-Level ist kein leerer Fehlversuch)
	var gt := Campaign.new_state(2, Campaign.board(2, 1))
	check(gt._miss_why([{"type": "still", "why": "stone"}]) == "stone" and gt._miss_why([{"type": "still", "why": "done"}]) == "done"
		and gt._miss_why([{"type": "still", "why": "thrive"}, {"type": "still", "why": "diag"}]) == "diag",
		"rows12: _miss_why kennt stone, done, thrive, water_life, people (unter schräg)")


## Der laufende Level-Versuch bleibt (App zu): GameState.save9/load9 genau gleich, über ConfigFile; die nächste
## Drehung gibt dasselbe Ergebnis; Game speichert nach jeder Runde und setzt beim Start fort; Sieg löscht ihn.
func test_save9() -> void:
	var path := "user://test_save9_lauf.cfg"
	var same := 0
	var cases := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for n in [3, 5, 6, 12, 19, 23, 24, 28, 30]:
		var gs := Campaign.new_state(n, Campaign.board(n, 2))
		for k in rng.randi_range(3, 8):
			if gs.day_won:
				break
			if k == 2 and not gs.gift_plan9().is_empty():
				gs.play({"type": "gift"})
			else:
				tw(gs, GameState.MOVES[rng.randi_range(0, 26)])
		if gs.day_won:
			continue
		cases += 1
		var cf := ConfigFile.new()
		cf.set_value("lauf", "daten", gs.save9())
		cf.save(path)
		var cf2 := ConfigFile.new()
		cf2.load(path)
		var g2 := GameState.load9(cf2.get_value("lauf", "daten", {}), Campaign.config(n))
		if g2 == null:
			continue
		var eq: bool = g2.record9() == gs.record9() and g2.spent == gs.spent and g2.standing == gs.standing \
			and g2.broken == gs.broken and g2.steps9() == gs.steps9() and g2.progress9() == gs.progress9() \
			and g2.rain == gs.rain and g2.meteors == gs.meteors and g2.volc == gs.volc and g2.gain_at9 == gs.gain_at9 \
			and g2.next_action()["text"] == gs.next_action()["text"]
		var m: Array = GameState.MOVES[rng.randi_range(0, 26)]
		var ra := tw(gs, m)
		var rb := tw(g2, m)
		if eq and g2.record9() == gs.record9() and _types(ra) == _types(rb):
			same += 1
		else:
			print("  save9 abweichend: Level %d" % n)
	DirAccess.remove_absolute(path)
	check(cases >= 6 and same == cases, "save9: Stand mitten im Level über ConfigFile genau gleich, nächste Drehung gleich (%d/%d)" % [same, cases])
	var bad := Campaign.new_state(3, Campaign.board(3, 0)).save9()
	bad["v"] = 99
	check(GameState.load9(bad, Campaign.config(3)) == null and GameState.load9(Campaign.new_state(3, Campaign.board(3, 0)).save9(), Campaign.config(4)) == null,
		"save9: andere Version oder anderes Level wird nicht geladen")
	# Game: Runde → gespeichert; neue App → genau dort weiter; Sieg löscht den Lauf
	var gpath := "user://test_save9_game.cfg"
	var t := lt(2026, 11, 12, 10)
	var g := _daily_game(gpath, t, true)
	g._clear_run()
	check(g.start_level(1, 1) and g.saved_run().is_empty(), "save9: ein neuer Versuch hat noch keinen gespeicherten Lauf")
	var sol: Array = g.level_board["solution"]
	var half := maxi(1, sol.size() / 2)
	for st in sol.slice(0, half):
		var ab: Array = Days.solution_step(st)
		g.undo_state = (g.state as GameState).clone()
		var res: Dictionary = g.state.play(ab[0], ab[1])
		g.finish_round(res)
	var rec := (g.state as GameState).record9()
	var hint_left: int = g.hint_free_left
	var run: Dictionary = g.saved_run()
	check(not run.is_empty() and int(run["level"]) == 1 and int(run["steps"]) == (g.state as GameState).steps9(),
		"save9: nach jeder Runde gespeichert (Level 1, %d Schritte)" % int(run.get("steps", -1)))
	g.free()
	var g2g := _daily_game(gpath, t + 3600, false)
	var started := []
	g2g.level_started.connect(func(info): started.append(info))
	check(g2g.resume_run() and g2g.level_no == 1 and (g2g.state as GameState).record9() == rec and g2g.hint_free_left == hint_left
		and not started.is_empty() and bool((started[0] as Dictionary).get("resumed", false)) and g2g.can_undo(),
		"save9: App neu → Level 1 genau dort weiter (Brett, Schritte, Fortschritt, Zurück), resumed")
	_replay_in_game_from(g2g, sol.slice(half))
	check((g2g.state as GameState).day_won and g2g.saved_run().is_empty() and g2g.level_stars(1) > 0,
		"save9: gewonnen → kein laufender Versuch mehr")
	# Ein Lauf eines anderen Levels, das neu beginnt (retry), wird gelöscht; kaputte Version: neu
	g2g.start_level(1, 2)
	var a2: Dictionary = (g2g.state as GameState).play({"type": "twist", "axis": 0, "layer": 1, "turns": 1})
	g2g.finish_round(a2)
	check(not g2g.saved_run().is_empty() and g2g.retry_level() and g2g.saved_run().is_empty(), "save9: Nochmal beginnt neu und löscht den Lauf")
	var a3: Dictionary = (g2g.state as GameState).play({"type": "twist", "axis": 0, "layer": 1, "turns": 1})
	g2g.finish_round(a3)
	var steps_before: int = (g2g.state as GameState).steps9()
	check(g2g.start_level(1) and (g2g.state as GameState).steps9() == steps_before, "save9: das Level aus der Übersicht wieder öffnen → es geht weiter")
	var cfr := ConfigFile.new()
	cfr.load(g2g.run_path())
	var dd: Dictionary = cfr.get_value("lauf", "daten", {})
	dd["v"] = 0
	cfr.set_value("lauf", "daten", dd)
	cfr.save(g2g.run_path())
	check(not g2g.resume_run() and not FileAccess.file_exists(g2g.run_path()), "save9: ein Lauf mit anderer Version wird verworfen")
	g2g.free()
	DirAccess.remove_absolute(gpath)


## Build 12: Der erste Start (Ersteller → Start-Karte von Level 1) speichert keinen Lauf. Wird die Karte vor „Los“
## geschlossen (App zu, Pause, Fokus weg) oder die App neu gestartet, beginnt Level 1 wieder neu: Karte mit Begrüßung,
## Vorführung „Zeig's mir“ noch offen. Ein Fortschritt-Reset nimmt einen alten Lauf mit (sonst ginge Level 1 dort weiter).
func test_card_close9() -> void:
	var on0 := Balance.CAMPAIGN_ON
	Balance.CAMPAIGN_ON = true
	var path := "user://test_card_close9.cfg"
	var t := lt(2026, 11, 9, 17, 40)
	var g := _daily_game(path, t, true)
	g._clear_run()
	g.coach_seen = {}
	var started := []
	g.level_started.connect(func(info): started.append(info))
	var ok_start: bool = g.start_level(1)
	var info0: Dictionary = g.level_info()
	check(ok_start and g.level_no == 1 and int(g.day_board.get("index", -1)) == 0 and g.demo_pending() and not g.run_resumed
		and bool(info0.get("first_visit", false)) and not (info0.get("tutorial", {}) as Dictionary).is_empty()
		and not bool((started[-1] as Dictionary).get("resumed", true)),
		"card_close9: Level 1 zum ersten Mal → Lehr-Brett, Begrüßung, Vorführung offen, nicht fortgesetzt")
	# Die Karte geht zu, bevor „Los“ gedrückt wurde: die App wird geschlossen, pausiert, verliert den Fokus
	g.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	g.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	g.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(g.saved_run().is_empty() and not FileAccess.file_exists(g.run_path()) and not g.coach_seen.has("day1_demo"),
		"card_close9: Karte vor „Los“ zu (App zu/Pause) → kein gespeicherter Lauf, Vorführung bleibt offen")
	# Aus der Übersicht wieder Level 1: neu, nicht fortgesetzt, Vorführung immer noch dran
	check(g.start_level(1) and not g.run_resumed and g.demo_pending() and (g.state as GameState).twists == 0
		and bool(g.level_info().get("first_visit", false)),
		"card_close9: Level 1 wieder antippen → wieder die Start-Karte mit „Zeig's mir“")
	g.free()
	# Neue App: nichts fortzusetzen, Level 1 beginnt mit Karte und Vorführung
	var g2 := _daily_game(path, t + 600, false)
	g2.coach_seen = {}
	var resumed2: bool = g2.resume_run()
	check(not resumed2 and g2.start_level(1) and g2.demo_pending() and not g2.run_resumed,
		"card_close9: App neu nach geschlossener Karte → Level 1 neu, Vorführung offen")
	# Ein alter Lauf (eine Drehung in Level 1) überlebt keinen Fortschritt-Reset
	var r: Dictionary = (g2.state as GameState).play({"type": "twist", "axis": 0, "layer": 1, "turns": 1})
	g2.finish_round(r)
	var had_run: bool = not g2.saved_run().is_empty()
	g2.reset_campaign()
	var gone: bool = g2.saved_run().is_empty() and not FileAccess.file_exists(g2.run_path())
	check(had_run and gone and g2.start_level(1) and not g2.run_resumed and (g2.state as GameState).twists == 0 and g2.demo_pending(),
		"card_close9: Fortschritt-Reset löscht den laufenden Versuch → Level 1 mit Karte und Vorführung (Lauf=%s weg=%s)" % [str(had_run), str(gone)])
	g2._clear_run()
	g2.free()
	DirAccess.remove_absolute(path)
	Balance.CAMPAIGN_ON = on0


## Build 12 (Review): Die Feld-Karte zeigt in der Schöpfung, was eine Reihe wirklich ergibt (rows9: Fels → Erde,
## nicht „Fels → Fels“); die Welt des Tages geht aus der Übersicht weiter; ein gekauftes Wunder wird erst mit dem
## Ende seiner Runde abgebucht (App mitten im Wunder zu → Vorrat und Lauf wie vorher).
func test_review12() -> void:
	var bad: Array = []
	var rows_seen := 0
	for n in range(1, Campaign.COUNT + 1):
		var gs := Campaign.new_state(n, Campaign.board(n, 0))
		for k in gs.rows9:
			rows_seen += 1
			if gs.row_result(int(k)) != int(gs.rows9[k]) or not gs.can_row(int(k)):
				bad.append("L%d %s→%s" % [n, FieldData.kind_name(int(k)), FieldData.kind_name(gs.row_result(int(k)))])
	var g4 := Campaign.new_state(4, Campaign.board(4, 0))
	var fels_ok := g4.rows9.has(FieldData.FELS) and g4.row_result(FieldData.FELS) == int(g4.rows9[FieldData.FELS]) \
		and g4.row_result(FieldData.FELS) != FieldData.FELS
	var ui_src := FileAccess.get_file_as_string("res://scripts/ui.gd")
	check(bad.is_empty() and rows_seen >= 30 and fels_ok and ui_src.contains("Game.state.row_result(k)"),
		"review12: Feld-Karte = rows9 für jede Reihen-Art aller Level, Fels → %s (%d Arten, falsch: %s)" % [
			FieldData.kind_name(g4.row_result(FieldData.FELS)), rows_seen, str(bad.slice(0, 4))])
	# Welt des Tages: verlassen und wieder öffnen → geht weiter; „Nochmal“ beginnt neu
	var t := lt(2026, 11, 12, 10)
	var wpath := "user://test_review12_wdt.cfg"
	var gw := _daily_game(wpath, t, true)
	gw._clear_run()
	gw.camp["veteran"] = true
	for i in Campaign.COUNT:
		(gw.camp["stars"] as Array)[i] = 2
	if gw.start_level_wdt():
		for m in [[0, 1, 1], [1, -1, 1]]:
			if (gw.state as GameState).day_won:
				break
			var r: Dictionary = (gw.state as GameState).play({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])})
			gw.finish_round(r)
		var rec := (gw.state as GameState).record9()
		var stp: int = (gw.state as GameState).steps9()
		var run_w: Dictionary = gw.saved_run()
		check(not run_w.is_empty() and bool(run_w["wdt"]) and gw.start_level_wdt() and gw.wdt_key >= 0
			and (gw.state as GameState).record9() == rec and (gw.state as GameState).steps9() == stp and gw.run_resumed,
			"review12: Welt des Tages aus der Übersicht wieder öffnen → geht weiter (%d Schritte)" % stp)
		check(gw.retry_level() and (gw.state as GameState).steps9() == 0 and gw.saved_run().is_empty() and not gw.run_resumed,
			"review12: Nochmal in der Welt des Tages beginnt neu")
	else:
		check(false, "review12: Welt des Tages startet")
	gw.free()
	DirAccess.remove_absolute(wpath)
	# Gekaufter Regen: abgebucht erst in finish_round, zusammen mit dem Lauf
	var spath := "user://test_review12_stock.cfg"
	var gs0 := _daily_game(spath, t, true)
	gs0._clear_run()
	gs0.debug_open_all = true
	var fid := -1
	var lv := 0
	for n in [1, 2, 3, 4, 5, 6, 7, 8]:
		if not gs0.start_level(n, 0):
			continue
		var r0: Dictionary = (gs0.state as GameState).play({"type": "twist", "axis": 0, "layer": 1, "turns": 1})
		gs0.finish_round(r0)
		if (gs0.state as GameState).day_won:
			continue
		for f in (gs0.state as GameState).fields:
			if (gs0.state as GameState).rain_ok9(f as FieldData, true):
				fid = (f as FieldData).id
				break
		if fid >= 0:
			lv = n
			break
	if fid >= 0:
		gs0.stock["regen"] = 1
		gs0._save_profile()
		var steps_run := int(gs0.saved_run().get("steps", -1))
		var got: Array = []
		gs0.round_resolved.connect(func(res, _b): got.append(res))
		var used: bool = gs0.use_stock("rain", fid)
		var mid := _daily_game(spath, t, false)
		var mid_ok: bool = int(mid.stock.get("regen", 0)) == 1 and int(mid.saved_run().get("steps", -2)) == steps_run
		mid.free()
		check(used and gs0.busy and gs0.stock_of("rain") == 0 and int(gs0.stock["regen"]) == 1 and mid_ok,
			"review12: Regen gekauft, Runde läuft – gespeichert noch 1 Regen, Lauf vor der Runde (Level %d)" % lv)
		if not got.is_empty():
			gs0.finish_round(got[0])
		var after := _daily_game(spath, t, false)
		check(int(gs0.stock.get("regen", 0)) == 0 and gs0.stock_of("rain") == 0 and int(after.stock.get("regen", 0)) == 0
			and not got.is_empty(), "review12: Runde fertig → Regen abgebucht und gespeichert, zusammen mit dem Lauf")
		after.free()
	else:
		check(false, "review12: ein Feld für gekauften Regen gefunden")
	gs0.free()
	DirAccess.remove_absolute(spath)


func _replay_in_game_from(g: Node, sol: Array) -> void:
	for st in sol:
		if (g.state as GameState).day_won:
			break
		var ab: Array = Days.solution_step(st)
		var res: Dictionary = g.state.play(ab[0], ab[1])
		g.finish_round(res)


## Die nächste Handlung (Zeile oben im HUD): auf jedem Brett ein kurzer Text, und nie etwas Unmögliches – eine
## genannte Drehung macht ihre Reihe, versorgt ihr Feld oder wendet ihre Gefahr ab; ein Werkzeug wirkt.
func test_next_action9() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var n_act := 0
	var bad: Array = []
	var words_bad: Array = []
	var types := {}
	var worst := 0
	var total := 0
	var two_ok := 0
	var two_n := 0
	for n in range(1, Campaign.COUNT + 1):
		for i in 2:
			var gs := Campaign.new_state(n, Campaign.board(n, i + 1))
			for k in 14:
				if gs.day_won:
					break
				var t0 := Time.get_ticks_usec()
				var a := gs.next_action()
				var dt := Time.get_ticks_usec() - t0
				worst = maxi(worst, dt)
				total += dt
				n_act += 1
				var tp := str(a.get("type", ""))
				types[tp] = int(types.get(tp, 0)) + 1
				var wc := str(a.get("text", "")).split(" ", false).size()
				if wc < 2 or wc > 6:
					words_bad.append(str(a.get("text", "")))
				var mv: Dictionary = a.get("move", {})
				var why := _action_ok(gs, a)
				if why == "two_fail":
					two_n += 1
				elif why != "":
					bad.append([n, i, k, tp, str(a["text"]), why])
				elif int(a.get("steps", 1)) == 2:
					two_n += 1
					two_ok += 1
				# weiter: meist der Vorschlag, manchmal zufällig
				if not mv.is_empty() and rng.randf() < 0.6:
					tw(gs, [int(mv["axis"]), int(mv["layer"]), int(mv["turns"])])
				elif str(a.get("tool", "")) == "rain" and int(a.get("field", -1)) >= 0:
					gs.play({"type": "rain", "field": int(a["field"])})
				elif str(a.get("tool", "")) == "gift":
					gs.play({"type": "gift"})
				else:
					tw(gs, GameState.MOVES[rng.randi_range(0, 26)])
	print("  Nächste Handlung: %d Bretter-Stände, Typen %s, %.1f ms im Mittel, höchstens %.1f ms (PC); 2 Züge %d/%d" % [n_act, str(types),
		float(total) / maxf(1.0, float(n_act)) / 1000.0, worst / 1000.0, two_ok, two_n])
	check(bad.is_empty(), "next_action: nie etwas Unmögliches (%d Stände, falsch: %s)" % [n_act, str(bad.slice(0, 3))])
	check(words_bad.is_empty(), "next_action: 2–6 Wörter (%s)" % str(words_bad.slice(0, 3)))
	check(two_n == 0 or two_ok * 10 >= two_n * 9, "next_action: Vorbereitung über 2 Züge stimmt meist (%d/%d)" % [two_ok, two_n])
	check(worst < 60000 and types.has("row") and types.has("thrive"), "next_action: billig genug für jede Runde (%.1f ms am PC)" % (worst / 1000.0))
	# Geschafft, Gefahr, Hinweis-Satz, Feld-Blatt
	var gw := Campaign.new_state(1, Campaign.board(1, 1))
	for st in (Campaign.board(1, 1)["solution"] as Array):
		var ab: Array = Days.solution_step(st)
		gw.play(ab[0], ab[1])
	check(str(gw.next_action()["type"]) == "won", "next_action: nach dem Sieg „Geschafft!“")
	var g20 := Campaign.new_state(35, Campaign.board(35, 1))
	check(str(g20.next_action()["hint"]).begins_with("Tiere brauchen Pflanzen: ") and str(g20.next_action()["hint"]).ends_with("/6 versorgt"),
		"next_action: Versorgungs-Satz für satt-Ziele (%s)" % str(g20.next_action()["hint"]))
	check(GameState.kind_caps9(STONE) == "Gestein" and GameState.kind_caps9(FieldData.LAVA) == "Glut", "kind_caps9: Fels heißt nicht „Essen“")
	# Vulkan droht und eine Drehung teilt die Lava: „Teil die Lava!“
	var found_volc := false
	for i2 in Campaign.pool_size(3):
		var gv := Campaign.new_state(3, Campaign.board(3, i2))
		for k2 in 8:
			if gv.volc >= 0 or gv.day_won:
				break
			var a2 := gv.next_action()
			var mv2: Dictionary = a2.get("move", {})
			if mv2.is_empty():
				tw(gv, GameState.MOVES[k2 % 27])
			else:
				tw(gv, [int(mv2["axis"]), int(mv2["layer"]), int(mv2["turns"])])
		if gv.volc >= 0 and not gv.day_won:
			var av := gv.next_action()
			if str(av["danger"]) == "volcano":
				found_volc = true
				var mv3: Dictionary = av["move"]
				var rv3 := tw(gv, [int(mv3["axis"]), int(mv3["layer"]), int(mv3["turns"])])
				check(not _types(rv3).has("erupt"), "next_action: die genannte Drehung verhindert den Ausbruch")
				break
	check(found_volc, "next_action: Vulkan droht → „Teil die Lava!“ (Level 3)")
	# Sackgasse: das Sicherheitsnetz
	var gd := camp_state(57, {0: FieldData.TOWN, 9: FieldData.TOWN})
	var ad := gd.next_action()
	check(str(ad["type"]) == "help" or gd.gift_plan9().is_empty(), "next_action: Sackgasse → „Hol dir Hilfe“ (%s)" % str(ad["text"]))


## Stimmt die Handlung auf diesem Stand? "" = ja, sonst warum nicht ("two_fail": die 2-Züge-Vorbereitung ging nicht auf).
func _action_ok(gs: GameState, a: Dictionary) -> String:
	var tp := str(a.get("type", ""))
	if str(a.get("text", "")) == "":
		return "kein Text"
	var mv: Dictionary = a.get("move", {})
	if tp == "won":
		return "" if gs.day_won else "nicht gewonnen"
	if tp == "help":
		return "" if not gs.gift_plan9().is_empty() else "kein Geschenk"
	if tp == "rain":
		var f: FieldData = gs.fields[int(a["field"])]
		return "" if gs.rain_ok9(f) else "Regen wirkt nicht"
	if not mv.is_empty() and int(a.get("steps", 1)) == 1:
		var c := gs.clone()
		var r := tw(c, [int(mv["axis"]), int(mv["layer"]), int(mv["turns"])])
		if tp == "row":
			for e in r["events"]:
				if str(e["type"]) == "merge" and int(e["from"]) == int(gs.fields[int(a["fields"][0])].kind):
					return ""
			return "keine Reihe"
		if tp == "thrive":
			var fid := int(a["fields"][0])
			var fc: FieldData = c.fields[fid]
			if fc.kind != (gs.fields[fid] as FieldData).kind or c.satt9(fid) or fc.fed > 0:
				return ""
			for e2 in r["events"]:
				if str(e2["type"]) == "need_sealed" and int(e2["field"]) == fid:
					return ""
			return "nicht versorgt"
		if tp == "group":
			var gk := -1
			for sd in gs.goal9:
				if str((sd as Dictionary)["type"]) == "group":
					gk = int((sd as Dictionary)["kind"])
			var c0 := gs.clone()
			c0.apply_rotation(int(mv["axis"]), int(mv["layer"]), int(mv["turns"]))      # die Drehung selbst (vor Jagd/Hunger der Runde)
			return "" if c.biggest9(gk) > gs.biggest9(gk) or c0.biggest9(gk) > gs.biggest9(gk) \
				or c.sub_progress9(gs.goal9[0]) > gs.sub_progress9(gs.goal9[0]) else "Gruppe nicht größer"
		if tp == "grow":
			return "" if _subs_sum(c) > _subs_sum(gs) or c.day_won else "kein Fortschritt"
		if tp == "danger" and not bool(a.get("averts", true)):
			return ""                  # Build 14: keine Drehung wendet sie ab – die Zeile sagt es, die Scheibe verliert am wenigsten
		if tp == "danger":
			var hit := {"volcano": "erupt", "bolt": "bolt", "pack": "pack_hunt", "hunger": "starve", "smog": "polluted",
				"war": "war_hit", "flood": "flood", "glacier": "freeze", "impact": "-"}
			var bad_t := str(hit.get(str(a["danger"]), "?"))
			return "Gefahr trat ein" if _types(r).has(bad_t) else ""
		return ""
	if tp == "goal" and int(a.get("steps", 1)) == 2:
		var c2 := gs.clone()
		tw(c2, [int(mv["axis"]), int(mv["layer"]), int(mv["turns"])])
		for m2 in GameState.MOVES:
			var c3 := c2.clone()
			var r3 := tw(c3, m2)
			if _types(r3).has("merge"):
				return ""
		return "two_fail"
	if tp == "goal" and str(a["text"]).begins_with("Bring 3 "):
		var kk := -1
		for k in gs.rows9:
			if str(a["text"]) == "Bring 3 %s in eine Reihe" % FieldData.kind_plural(int(k)):
				kk = int(k)
		return "" if kk >= 0 and gs._row_cap9(kk) > 0 else "Reihe geht nicht"
	return ""


func _camp_tests() -> void:
	test_kinds9()
	test_groups9()
	test_thrive9()
	test_lasting_supply()
	test_volcano9()
	test_bolt9()
	test_pack_smog9()
	test_goal_progress9()
	test_mercy9()
	test_points9()
	test_rain9()
	test_xcheck9()
	test_pool_replay9()
	test_start_rules9()
	test_dangers_consequence9()
	test_farm9()
	test_carry9()
	test_solvable9()
	test_rescue_game()
	test_texts9()
	test_texts10()
	test_unlock60()
	test_migrate_v3()
	test_migrate_erde()
	test_sources10()
	test_hunt10()
	test_glacier10()
	test_impact10()
	test_rain_kind10()
	test_thrive10()
	test_reach10()
	test_level_game()
	test_ui9()
	test_hint9()
	test_rows_build12()
	test_save9()
	test_next_action9()
	test_next_action_all()
	test_next_action_concrete()
	_b14_tests()
	await process_frame


## Oberfläche der Schöpfung (Game-Seite): Heute-Karte ohne Spoiler, Laden (kaufen, Vorrat voll, zu wenig Punkte,
## Gott-Teil zurückgeben), Blitzschutz, „Zurück“ zählt den Schritt, 100-Sekunden-Challenge (Uhr ab der ersten
## Drehung, Feuer −5 s, die große Wahl-Karte hält an, Rekord je Modus), freies Spiel erst nach der Schöpfung.
func test_ui9() -> void:
	var on0 := Balance.CAMPAIGN_ON
	Balance.CAMPAIGN_ON = true
	var path := "user://test_ui9.cfg"
	var t := lt(2026, 11, 12, 10)
	var g := _daily_game(path, t, true)
	var ti: Dictionary = g.today_info()
	check(str(ti.get("state", "")) == "new" and int(ti["day"]) == 1 and str(ti["title"]) == "Glut" and bool(ti.get("camp", false)),
		"Heute-Karte: Level 1 neu (%s)" % str(ti.get("title", "")))
	check(not g.free_play_unlocked() and g.free_locked_text() == "Nach der Erdgeschichte." and g.stars_max() == 3 * Campaign.COUNT,
		"freies Spiel erst nach der Erdgeschichte")
	check(g.start_level(1), "UI: Level 1 startet")
	_replay_in_game(g)
	ti = g.today_info()
	var told := str(ti.get("title", "")) + str(ti.get("line", "")) + str(ti.get("caps", ""))
	check(str(ti["state"]) == "done_next" and str(ti["line"]) == str(Campaign.TEXT["locked"]) and not told.contains("Abkühlen"),
		"Heute geschafft: „Morgen wartet etwas Neues“, kein Titel von Level 2")
	check(g.level_locked_text(2) == str(Campaign.TEXT["locked"]) and g.level_locked_text(5) == "Erst Level 2 schaffen.", "gesperrte Level ohne Titel")
	# Laden: Wunder erst, wenn sie vorkamen; kaufen mit Vorrat-Grenze; zu wenig Punkte
	var ids: Array = []
	for it in g.shop_items("wunder"):
		ids.append(str((it as Dictionary)["id"]))
	check(ids.is_empty() and g.shop_items("welten").size() == 1, "Laden: in Level 1 noch keine Wunder (nicht spoilern)")
	g.points = 200
	g.camp["veteran"] = true
	check(g.buy("regen") == "" and g.points == 175 and g.stock_of("rain") == 1, "Laden: Regen für 25 in den Vorrat")
	g.stock["regen"] = 3
	check(g.buy("regen") == "Vorrat voll" and g.points == 175, "Laden: Vorrat voll")
	check(g.buy("sonnenkrone") == "Dir fehlen 425 ✦" and not g.owned.has("sonnenkrone"), "Laden: zu wenig Punkte")
	check(g.buy("stirnband") == "" and g.owned.has("stirnband") and Character.accessory_ids("kopf", "bart").has("stirnband"), "Laden: Gott-Teil gekauft und wählbar")
	g.wear("stirnband", true)
	check(str(g.character.get("kopf", "")) == "stirnband", "Laden: Teil angelegt")
	check(g.refund("stirnband") and g.points == 175 and str(g.character.get("kopf", "")) == "" and not g.owned.has("stirnband"), "Laden: zurückgeben erstattet alles")
	# Level 21 (Wälder, Blitz): Blitzschutz aus dem Vorrat (2 Schritte, je Level einmal)
	g.debug_open_all = true
	check(g.start_level(21, 0), "Level 21 startet")
	g.stock["blitzschutz"] = 2
	var s0: int = g.state.steps9()
	check(g.use_stock("guard") and g.state.bolt_guard9 == 5 and g.state.steps9() == s0 + 2 and int(g.stock["blitzschutz"]) == 1, "Blitzschutz: 5 Runden, zählt 2 Schritte")
	check(not g.use_stock("guard"), "Blitzschutz: je Level einmal")
	var guard_bolts := 0
	for i in 5:
		var r: Dictionary = g.state.play({"type": "twist", "axis": i % 3, "layer": 1, "turns": 1})
		for e in r["events"]:
			if ["bolt", "bolt_warn"].has(str((e as Dictionary)["type"])):
				guard_bolts += 1
	check(guard_bolts == 0 and g.state.bolt_guard9 == 0, "Blitzschutz: kein Blitz, keine Warnung in 5 Runden")
	# „Zurück“ nimmt die Drehung zurück, der Schritt bleibt gezählt
	g.start_level(21, 0)
	g.play_turn(0, 1, 1)
	if g.has_choice():
		g.choose_default()
	g.finish_round({"events": []})
	var s1: int = g.state.steps9()
	g.undo()
	check(g.state.steps9() == s1 and g.state.twists == s1 - 1, "Zurück: der Schritt bleibt gezählt (%d)" % g.state.steps9())
	# 100-Sekunden-Challenge
	g.start_mode("sek100")
	check(g.sek100 and g.mode_key() == "sek100" and not g.sek100_running and is_equal_approx(g.sek100_left, 100.0), "100 s: Uhr wartet auf die erste Drehung")
	g._process(5.0)
	check(is_equal_approx(g.sek100_left, 100.0), "100 s: vor der ersten Drehung läuft nichts")
	g.play_turn(0, 1, 1)
	if g.has_choice():
		g.choose_default()
	g.finish_round({"events": []})
	g._process(2.0)
	check(g.sek100_running and is_equal_approx(g.sek100_left, 98.0), "100 s: Uhr läuft ab der ersten Drehung")
	g.finish_round({"events": [{"type": "disaster"}]})
	check(is_equal_approx(g.sek100_left, 93.0), "100 s: Feuer kostet 5 s")
	g.pending_choice = {"mini": false}
	g._process(3.0)
	check(is_equal_approx(g.sek100_left, 93.0), "100 s: die große Wahl-Karte hält die Uhr an")
	g.pending_choice = {"mini": true}
	g._process(1.0)
	check(is_equal_approx(g.sek100_left, 92.0), "100 s: die kleine Pille hält sie nicht an")
	g.pending_choice = {}
	g.state.faith = 77
	var over := [false]
	g.game_over.connect(func(): over[0] = true)
	g._process(100.0)
	check(g.over and over[0] and g.sek100_done and g.best_for("sek100") == 77 and g.best_for("mittel") != 77, "100 s: Zeit! Rekord je Modus")
	g.new_game()          # „Neues Spiel“ auf der Ergebnis-Karte
	check(g.sek100 and g.mode_key() == "sek100" and not g.state.hearts and not g.state.died(),
		"100 s: „Neues Spiel“ startet wieder die Challenge, ohne Herzen (Feuer kostet nur Zeit)")
	g.start_mode("mittel")
	check(not g.sek100 and g.state.hearts, "100 s: eine andere Spielart beendet die Challenge")
	g.start_level(1)
	check(not g.sek100, "100 s: ein Level beendet die Challenge")
	g.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Balance.CAMPAIGN_ON = on0


## Der Tipp in einem Level (wie der Bot „good“ des Modells): gewinnt die Pool-Bretter, meist mit ★★ oder mehr.
func test_hint9() -> void:
	var wins := 0
	var two := 0
	var tried := 0
	var steps: Array = []
	for n in [1, 3, 5, 8, 11, 13, 16, 19, 20, 22, 24, 26, 28, 30]:
		var b := Campaign.board(n, 1)
		var gs := Campaign.new_state(n, b)
		tried += 1
		for i in 40:
			if gs.day_won:
				break
			var a := gs.best_action()
			if a.is_empty():
				break
			gs.play(a)
		if gs.day_won:
			wins += 1
			steps.append(gs.day_won_at)
			if gs.stars() >= 2:
				two += 1
	print("  Tipp in der Schöpfung: %d/%d gewonnen, ★★+ %d, Schritte %s" % [wins, tried, two, str(steps)])
	# Die Tipp-Suche bleibt begrenzt (späte Level, frisch und festgefahren, auch im Weiterbauen): höchstens 150 Simulationen
	var most := 0
	var wall := 0.0
	var rng9 := RandomNumberGenerator.new()
	rng9.seed = 9
	for n9 in [24, 26, 27, 28, 29]:
		var g9 := Campaign.new_state(n9, Campaign.board(n9, 1))
		for round_i in 2:
			var t0 := Time.get_ticks_usec()
			var se: GameState.DaySearch8 = g9.clone().day_search(false)
			while se != null and not se.step(6000):
				pass
			wall = maxf(wall, (Time.get_ticks_usec() - t0) / 1000.0)
			if se != null:
				most = maxi(most, se.sims)
			var guard := 0
			while g9.twists - g9.gain_at9 < 5 and guard < 40 and not g9.day_won:
				guard += 1
				var mv: Array = GameState.MOVES[rng9.randi_range(0, 26)]
				var act := {"type": "twist", "axis": int(mv[0]), "layer": int(mv[1]), "turns": int(mv[2])}
				if not (g9.simulate(act)["state"] as GameState).day_won:
					g9.play(act)
	# Sackgasse (dead9): Level 28 braucht 3 Städte, nur 2 Menschen-Felder übrig und keine Regel macht neue
	check(camp_state(57, {0: FieldData.TOWN, 9: FieldData.TOWN}).dead9() and not camp_state(57, {0: FieldData.TOWN, 9: FieldData.TOWN, 18: HUT}).dead9()
		and not camp_state(49, {0: HUT}).dead9(), "dead9: Level 28 mit 2 Städten ist eine Sackgasse, mit 3 Menschen-Feldern nicht; Level 24 (Reihen machen Hütten) nie")
	print("  Tipp-Suche Level 24–29: höchstens %d Simulationen, %.0f ms" % [most, wall])
	check(most > 0 and most <= 150, "hint9: die Tipp-Suche bleibt begrenzt (%d Simulationen ≤ 150)" % most)
	check(wins == tried and two * 10 >= tried * 7, "hint9: der Tipp gewinnt jedes geprüfte Level (%d/%d), meist ★★+ (%d)" % [wins, tried, two])
	# Vorschau-Vertrag (11): alle Schlüssel da
	var g := Campaign.new_state(24, Campaign.board(24, 2))
	var pv := g.preview8(1, 1, 1)
	var keys_ok := true
	for k in ["satt_new", "satt_lost", "need_met", "need_lost", "rows", "war_risk", "flood_risk", "fire_risk", "goal_delta",
			"volcano_risk", "bolt_risk", "pack_risk", "smog_risk", "hunger", "merge", "sealed"]:
		if not pv.has(k):
			keys_ok = false
	var fs := g.field_state8(g.fields[0])
	check(keys_ok and fs.has("sealed") and fs.has("have") and fs.has("strength") and g.day_status().has("subs")
		and g.day_status().has("next_star"), "preview9/field_state9/day_status: Vertrag der Oberfläche")


# =============================================================================
# Build 14 (docs/GDPD_LOGIK.md): „Das muss logisch aufgebaut sein.“ Die Meldung zu Build 13: vorausgespielt, dann ging
# keine Ursuppe mehr, weil kein Wasser mehr da war. Diese Prüfungen halten fest, was seitdem immer gilt:
#   1 jeder Start ist lösbar, auf jedem Weg  2 keine Gefahr macht ein Level unlösbar  3 macht es der Spieler selbst
#   unlösbar, kommt die Hilfe sofort, sagt, was fehlt, und bringt Fortschritt  4 oben steht immer eine Handlung, die geht.
# Feste Seeds; zusammen etwa eine Minute.
# =============================================================================

func _b14_tests() -> void:
	var t0 := Time.get_ticks_msec()
	test_logic14_layer()
	test_soup_recipe14()
	test_rain_cycle14()
	test_mercy14()
	test_reach14()
	test_last_holds14()
	test_net_water14()
	test_line_follow14()
	test_start_gate14()
	test_night14()
	test_hint14()
	test_never_stuck14()
	test_start_invariant14()
	test_play_invariant14()
	test_no_water_ursuppe14()
	test_texts14()
	print("  Build 14: alle Prüfungen zusammen %d ms" % (Time.get_ticks_msec() - t0))


func _cnt14(gs: GameState, k: int) -> int:
	var n := 0
	for f in gs.fields:
		if f.kind == k:
			n += 1
	return n


func _water_of(n: int) -> int:
	var comp: Dictionary = Campaign.config(n)["comp"]
	var t := 0
	for key in comp:
		t += int(comp[key])
	return 54 - t


func _kinds_of(gs: GameState) -> Array:
	var out: Array = []
	for f in gs.fields:
		out.append(f.kind)
	return out


## Die Zeile oben an diesem Stand prüfen (GDPD_LOGIK.md 4): 2–6 Wörter, eine Scheibe oder ein Werkzeug, möglich
## (_action_ok), nie die alten Ersatz-Zeilen. Fehler landen in bad.
func _line_ok14(gs: GameState, a: Dictionary, bad: Array, tag: String) -> void:
	var txt := str(a.get("text", ""))
	var mv: Dictionary = a.get("move", {})
	var tool := str(a.get("tool", ""))
	var wc := txt.split(" ", false).size()
	var why := _action_ok(gs, a)
	var wrong := ""
	if wc < 2 or wc > 6:
		wrong = "Wörter"
	elif mv.is_empty() and tool == "":
		wrong = "keine Handlung"
	elif txt == "Dreh eine Scheibe" or txt == "Dreh weiter, Regen kommt" or txt.contains(" wächst") or txt == "Hol dir Hilfe":
		wrong = "alte Zeile"
	elif why != "" and why != "two_fail":
		wrong = why
	elif tool == "rain" and not gs.rain_ok9(gs.fields[int(a.get("field", 0))]):
		wrong = "Regen geht nicht"
	if wrong != "" and bad.size() < 8:
		bad.append([tag, gs.level_no, gs.steps9(), txt, wrong])


## Ein Spieler, der genau tut, was oben steht (Drehung oder Werkzeug). net: Er nimmt die Hilfe an, wenn die Zeile sie
## nennt oder das Netz sie anbietet (wie Game._rescue_check). Ohne Netz: sagt die Zeile „Hilfe“, dreht er irgendeine
## Scheibe (blind). Jede Zeile wird geprüft (_line_ok14). {"won", "steps", "gifts", "blind", "most" (so oft dieselbe
## Stellung), "nogift" (Angebot ohne Geschenk), "flat" (Geschenk ohne Fortschritt)}.
func _follow14(gs: GameState, cap: int, net: bool, bad: Array, tag: String = "") -> Dictionary:
	var gifts := 0
	var blind := 0
	var acts := 0
	var seen := {}
	var most := 0
	var told_at := -99
	var dead_told := false
	var nogift := 0
	var flat := 0
	while not gs.day_won and gs.steps9() < cap and acts < cap * 4:
		acts += 1
		var a := gs.next_action()
		_line_ok14(gs, a, bad, tag)
		var mv: Dictionary = a.get("move", {})
		var tool := str(a.get("tool", ""))
		if tool == "gift":
			if net and not gs.gift_plan9().is_empty():
				var s0 := gs._subs_sum9() + gs.progress9()
				gs.play({"type": "gift"})
				gifts += 1
				if gs._subs_sum9() + gs.progress9() <= s0 and not gs.day_won:
					flat += 1
				told_at = gs.steps9()
			else:
				blind += 1
				tw(gs, GameState.MOVES[(acts * 7 + gs.steps9()) % 27])
		elif tool == "rain" or tool == "meteor":
			gs.play({"type": tool, "field": int(a["field"])})
		elif not mv.is_empty():
			tw(gs, [int(mv["axis"]), int(mv["layer"]), int(mv["turns"])])
			var key := gs.slot_board9()
			seen[key] = int(seen.get(key, 0)) + 1
			most = maxi(most, int(seen[key]))
		else:
			blind += 1
			tw(gs, GameState.MOVES[(acts * 7 + gs.steps9()) % 27])
		if gs.day_won or not net:
			continue
		var why := gs.stuck9()
		if why != "dead":
			dead_told = false
		if why == "":
			continue
		if (why == "dead" and not dead_told) or gs.steps9() - told_at >= GameState.STALL9:
			dead_told = why == "dead"
			told_at = gs.steps9()
			if gs.gift_plan9().is_empty():
				nogift += 1
			else:
				var s1 := gs._subs_sum9() + gs.progress9()
				gs.play({"type": "gift"})
				gifts += 1
				if gs._subs_sum9() + gs.progress9() <= s1 and not gs.day_won:
					flat += 1
	return {"won": gs.day_won, "steps": gs.steps9(), "gifts": gifts, "blind": blind, "most": most, "nogift": nogift, "flat": flat}


## Der Tipp-Bot: spielt nur den Tipp (best_action). net: mit dem Sicherheitsnetz wie im Spiel. [gewonnen, Schritte, Geschenke]
func _hint14(gs: GameState, cap: int, net: bool) -> Array:
	var gifts := 0
	var told_at := -99
	var dead_told := false
	var acts := 0
	while not gs.day_won and gs.steps9() < cap and acts < cap * 3:
		acts += 1
		var a := gs.best_action()
		if a.is_empty():
			break
		gs.play(a)
		if gs.day_won or not net:
			continue
		var why := gs.stuck9()
		if why != "dead":
			dead_told = false
		if why == "":
			continue
		if (why == "dead" and not dead_told) or gs.steps9() - told_at >= GameState.STALL9:
			dead_told = why == "dead"
			told_at = gs.steps9()
			if not gs.gift_plan9().is_empty():
				gs.play({"type": "gift"})
				gifts += 1
	return [gs.day_won, gs.steps9(), gifts]


## Ein sorgloser Spieler („vorausgespielt“): twists zufällige Drehungen; jeder Regen sofort auf ein Feld, auf das er
## wirkt (burn: zuerst auf Wasser – so verbraucht er das Meer), Meteore irgendwohin. Hört auf, wenn das Level gewonnen ist.
func _careless14(gs: GameState, rng: RandomNumberGenerator, twists: int, burn: bool, no_win: bool = false) -> void:
	var t0 := gs.twists
	var guard := 0
	while not gs.day_won and gs.twists - t0 < twists and guard < twists * 6:
		guard += 1
		if no_win:
			# sorglos, aber nie die Aktion, die das Level beendet (der Stand danach soll geprüft werden)
			var mvn: Array = GameState.MOVES[rng.randi_range(0, GameState.MOVES.size() - 1)]
			var cn := gs.clone()
			tw(cn, mvn)
			if not cn.day_won:
				tw(gs, mvn)
				if gs.rain > 0:
					var wn: Array = []
					for f in gs.fields:
						if gs.rain_ok9(f) and (not burn or f.kind == WATER):
							wn.append(f.id)
					if not wn.is_empty():
						var cr := gs.clone()
						var pick := int(wn[rng.randi_range(0, wn.size() - 1)])
						cr.play({"type": "rain", "field": pick})
						if not cr.day_won:
							gs.play({"type": "rain", "field": pick})
			continue
		if gs.rain > 0:
			var cand: Array = []
			var wat: Array = []
			for f in gs.fields:
				if gs.rain_ok9(f):
					cand.append(f.id)
					if f.kind == WATER:
						wat.append(f.id)
			if burn and not wat.is_empty():
				cand = wat
			if not cand.is_empty():
				gs.play({"type": "rain", "field": int(cand[rng.randi_range(0, cand.size() - 1)])})
				continue
		if gs.meteors > 0 and rng.randf() < 0.5:
			var land: Array = []
			for f in gs.fields:
				if gs.meteor_ok9(f):
					land.append(f.id)
			if not land.is_empty():
				gs.play({"type": "strike", "field": int(land[rng.randi_range(0, land.size() - 1)])})
				continue
		tw(gs, GameState.MOVES[rng.randi_range(0, GameState.MOVES.size() - 1)])


## A1: Die Regeln ab Build 14 leben im Code (nur im Spiel, nie im Modell-Modus) und haben einen Fingerabdruck.
func test_logic14_layer() -> void:
	GameState.engine9_mode = true
	var m8 := Campaign.new_state(8, Campaign.board(8, 1))
	var m1 := Campaign.new_state(1, Campaign.board(1, 1))
	var m1_rain := m1.tool_in_level9("rain")
	GameState.engine9_mode = false
	var g8 := Campaign.new_state(8, Campaign.board(8, 1))
	var g1 := Campaign.new_state(1, Campaign.board(1, 1))
	var data_rain: Array = Campaign.config(8)["rain"]
	check(not m8.thrive9.has(WATER) and m8.rain9.size() == data_rain.size() and not m8.cycle9 and m1_rain,
		"logic14: im Modell-Modus gelten genau die Level-Daten (kein Wasser-Rezept in Level 8, Regen-Tabelle wie in den Daten)")
	check(g8.thrive9.has(WATER) and int((g8.thrive9[WATER] as Dictionary)["up"]) == SOUP and g8.rain9.size() == data_rain.size() + 1
		and g8.cycle9 and not g1.tool_in_level9("rain") and not g1.cycle9,
		"logic14: im Spiel gelten die Regeln ab Build 14 (Rezept in Level 8, Kreislauf, kein Regen in Level 1)")
	check(not (Campaign.config(8)["thrive"] as Dictionary).has(str(WATER)) and g8.day["rain"] == data_rain,
		"logic14: die Level-Daten selbst bleiben unverändert (der Abgleich mit dem Modell spielt sie)")
	var c8 := Campaign.config(8)
	check(GameState.RULES_VERSION >= 14 and GameScript._cfg_hash(c8) == GameScript._cfg_hash(c8, GameState.RULES_VERSION)
		and GameScript._cfg_hash(c8, 13) != GameScript._cfg_hash(c8, 14) and GameScript._cfg_hash(c8) != GameScript._cfg_hash(Campaign.config(9)),
		"logic14: der Fingerabdruck eines Levels rechnet die Regel-Version ein (ein alter Versuch beginnt neu)")
	# die Welt des Tages bekommt die Regeln über die Level-Nummer ihrer Vorlage
	var cw := Campaign.config(9)
	cw["title"] = "Welt des Tages"
	var gw := GameState.new()
	gw.setup_level(cw, Campaign.board(9, 2)["kinds"], 3)
	check(gw.thrive9.has(WATER) and gw.cycle9, "logic14: auch die Welt des Tages (Vorlage Level 9) hat Rezept und Kreislauf")


## A2: Ein Rezept bleibt – Wasser + 2 Wärme + Fels → Ursuppe gilt auch in Level 8 und 9. Der Fall des Spielers:
## Regen vorher verbraucht, trotzdem geht Ursuppe.
func test_soup_recipe14() -> void:
	for n in [6, 7, 8, 9]:
		# Wasser 20 berührt eine Lava-Gruppe aus 2 (Wärme 2) und einen Fels
		var probe := camp_state(n)
		var a := other_nb(probe, 20, 0)
		var b := other_nb(probe, 20, 1)
		var a2 := -1
		for g in probe.nb9(a):
			if int(g) != 20 and int(g) != b and not probe.nb9(20).has(int(g)):
				a2 = int(g)
				break
		var gs := camp_state(n, {a: LAVA, a2: LAVA, b: STONE})
		gs.rain = 0
		var m := move_avoiding(gs, [20, a, a2, b])
		var became := false
		var pill := false
		for i in 4:
			var r := tw(gs, m)
			for e in r["events"]:
				if str(e["type"]) == "thrive" and int(e["field"]) == 20 and int(e["kind"]) == SOUP:
					pill = Campaign.thrive_pill(int(e["from"]), int(e["kind"])) == "Ursuppe entsteht"
			if (gs.fields[20] as FieldData).kind == SOUP or (gs.fields[20] as FieldData).kind == CELLS:
				became = true
				break
		check(became and pill, "soup14: Level %d – Wasser neben 2 Wärme und Fels wird Ursuppe („Ursuppe entsteht“)" % n)
	# Level 9, die ersten zwei Regen verschwendet (auf Fels, wie Level 5 es lehrt): die Zeile führt trotzdem zum Ziel
	var bad: Array = []
	var worst := 0
	var lost: Array = []
	for i in range(1, 11):
		var gs9 := Campaign.new_state(9, Campaign.board(9, i))
		var wasted := 0
		var guard := 0
		while wasted < 2 and guard < 12:
			guard += 1
			if gs9.rain > 0:
				for f in gs9.fields:
					if f.kind == STONE and gs9.rain_ok9(f):
						gs9.play({"type": "rain", "field": f.id})
						wasted += 1
						break
			else:
				tw(gs9, GameState.MOVES[(i + guard) % 27])
		var res := _follow14(gs9, 40, false, bad, "L9/%d" % i)
		worst = maxi(worst, int(res["steps"]))
		if not bool(res["won"]) or int(res["blind"]) > 0:
			lost.append([i, res])
	print("  soup14: Level 9 mit 2 verschwendeten Regen, 10 Bretter, der Zeile folgen: höchstens %d Schritte" % worst)
	check(lost.is_empty() and bad.is_empty() and worst <= 11, "soup14: Level 9 mit 2 verschwendeten Regen – wer der Zeile folgt, gewinnt ohne Hilfe (höchstens %d Schritte; offen %s, Zeilen %s)" % [worst, str(lost.slice(0, 2)), str(bad.slice(0, 2))])
	# alle Pool-Lösungen von Level 8 und 9 gewinnen im Spiel spätestens bei solved_in
	var late: Array = []
	for n2 in [8, 9]:
		for i2 in Campaign.pool_size(n2):
			var b2 := Campaign.board(n2, i2)
			var g2 := Campaign.new_state(n2, b2)
			for st in (b2["solution"] as Array):
				var ab: Array = Days.solution_step(st)
				g2.play(ab[0], ab[1])
				if g2.day_won:
					break
			if not g2.day_won or g2.day_won_at > int(b2["solved_in"]):
				late.append([n2, i2, g2.day_won, g2.day_won_at, int(b2["solved_in"])])
	check(late.is_empty(), "soup14: alle 40 Pool-Lösungen von Level 8/9 gewinnen im Spiel spätestens bei solved_in (%s)" % str(late.slice(0, 3)))


## A3: Regen ist ein Kreislauf (Level 6–14): Regen auf Erde macht Wasser. Ohne Wasser führt die Zeile zurück zum Meer.
func test_rain_cycle14() -> void:
	var ok := true
	for n in range(6, 15):
		var gs := camp_state(n, {0: E, 1: STONE})
		gs.rain = 1
		if gs.rain_to9(gs.fields[0]) != WATER:
			ok = false
	var g18 := camp_state(18, {0: E})
	var g5 := camp_state(5, {0: E, 1: STONE})
	check(ok and g18.rain_to9(g18.fields[0]) == MOSS and g5.rain_to9(g5.fields[0]) < 0 and not g5.cycle9,
		"cycle14: Regen auf Erde macht in Level 6–14 Wasser; Level 18 Moos, Level 5 nichts")
	# Der Tipp wertet den Kreislauf nicht (keine Reihe „3 Felsen → Erde“ fürs Ziel): Erde und Fels gehören nicht zur Kette
	var g6 := Campaign.new_state(6, Campaign.board(6, 1))
	check(not g6.chain9.has(E) and not g6.chain9.has(STONE) and g6.chain9.has(WATER), "cycle14: der Kreislauf ändert die Ziel-Kette nicht")
	# Level 6–9 ganz ohne Wasser (alles Wasser ist Erde), 1 Regen: erreichbar, die Zeile gießt Erde, es geht ohne Geschenk
	var bad: Array = []
	var notes: Array = []
	var fails: Array = []
	for n2 in [6, 7, 8, 9]:
		var b := Campaign.board(n2, 1)
		var kinds: Array = (b["kinds"] as Array).duplicate()
		for i in kinds.size():
			if int(kinds[i]) == WATER:
				kinds[i] = E
		var gd := Campaign.new_state(n2, {"kinds": kinds, "seed": 3})
		gd.rain = 1
		var a := gd.next_action()
		# Level 6/7: die erste Zeile gießt Erde; Level 8/9 haben noch Ursuppe und beginnen mit ihr
		var first_ok: bool = bool(gd.reach9()["ok"]) and (n2 >= 8 or (str(a.get("tool", "")) == "rain" and int(a.get("result", -1)) == WATER
			and (gd.fields[int(a.get("field", 0))] as FieldData).kind == E and str(a["text"]) == "Gieß Erde mit Regen"))
		var res := _follow14(gd, 120, false, bad, "ohne Wasser L%d" % n2)
		notes.append("L%d %d" % [n2, int(res["steps"])])
		if not first_ok or not bool(res["won"]) or int(res["blind"]) > 0:
			fails.append([n2, first_ok, str(a.get("text", "")), res])
	check(fails.is_empty() and bad.is_empty(), "cycle14: Level 6–9 ohne ein einziges Wasser-Feld – „Gieß Erde mit Regen → Wasser“, gewonnen ohne Geschenk (Schritte %s; %s %s)" % [str(notes), str(fails.slice(0, 2)), str(bad.slice(0, 2))])
	# Level 9 ohne Wasser und ohne Erde: die Zeile nennt den Fels (Fels → Erde → Wasser)
	var b9 := Campaign.board(9, 1)
	var k9: Array = (b9["kinds"] as Array).duplicate()
	for i2 in k9.size():
		if int(k9[i2]) == WATER or int(k9[i2]) == E or int(k9[i2]) == SOUP:
			k9[i2] = STONE
	var g9 := Campaign.new_state(9, {"kinds": k9, "seed": 3})
	g9.rain = 1
	var a9 := g9.next_action()
	check(str(a9.get("tool", "")) == "rain" and (g9.fields[int(a9.get("field", 0))] as FieldData).kind == STONE and str(a9["text"]) == "Gieß Fels mit Regen",
		"cycle14: Level 9 ohne Wasser und Erde – die Zeile gießt Fels (%s)" % str(a9.get("line", "")))
	# Solange es Wasser am Ufer gibt, nennt die Zeile nie Regen auf Erde oder Fels
	var gp := Campaign.new_state(9, Campaign.board(9, 2))
	gp.rain = 3
	var ap := gp.next_action()
	check(str(ap.get("tool", "")) == "rain" and (gp.fields[int(ap.get("field", 0))] as FieldData).kind == WATER,
		"cycle14: mit Wasser am Ufer gießt die Zeile Wasser, nie den Fels (%s)" % str(ap.get("line", "")))


## A4: Regen erst, wenn es ihn gibt (nie in Level 1–4), Hilfe von oben nur, wenn Regen etwas bringt.
func test_mercy14() -> void:
	var rng := RandomNumberGenerator.new()
	var bad: Array = []
	for n in [1, 2, 3, 4]:
		rng.seed = 140 + n
		var gs := Campaign.new_state(n, Campaign.board(n, 1))
		var mercy := 0
		for i in 150:
			if gs.day_won:
				break
			var mv: Array = GameState.MOVES[rng.randi_range(0, 26)]
			var c := gs.clone()
			tw(c, mv)
			if c.day_won:
				continue               # sorglos: nie der Zug, der gewinnt
			var r := tw(gs, mv)
			if _types(r).has("mercy"):
				mercy += 1
		if gs.rain != 0 or mercy > 0 or gs.tool_unlocked("rain") or gs.steps9() < 10:
			bad.append([n, gs.rain, mercy, gs.steps9()])
	check(bad.is_empty(), "mercy14: Level 1–4 nach 150 sorglosen Drehungen: kein Regen, keine Hilfe von oben, kein Regen-Knopf (%s)" % str(bad))
	var g5 := Campaign.new_state(5, Campaign.board(5, 1))
	var g41 := Campaign.new_state(41, Campaign.board(41, 1))
	check(g5.tool_unlocked("rain") and Campaign.new_state(6, Campaign.board(6, 1)).tool_unlocked("rain"),
		"mercy14: ab Level 5 gibt es den Regen (Dampf), ab Level 6 von Anfang an")
	# Level 41 ganz aus Eis: Regen brächte nichts → keine Hilfe von oben
	for f in g41.fields:
		if f.kind != FieldData.MAMMOTH:
			g41._setk9(f, FieldData.ICE)
	g41.rain = 0
	var gave := 0
	for i2 in 24:
		var r2 := tw(g41, [1, 1, 1])
		if _types(r2).has("mercy"):
			gave += 1
	check(gave == 0 and g41.rain <= 3, "mercy14: Level 41 ganz aus Eis – keine Hilfe von oben, die nichts bringt (%d×)" % gave)


## A5: Die Prüfung „geht das Level noch?“ ist ehrlich, aber nie zu streng.
func test_reach14() -> void:
	# 1. Kein Fehlalarm: jedes Pool-Brett und jeder Stand entlang der Pool-Lösungen, die im Spiel gewinnen
	var t0 := Time.get_ticks_msec()
	var states := 0
	var alarms: Array = []
	var worst := 0
	for n in range(1, Campaign.COUNT + 1):
		for i in range(n % 5, Campaign.pool_size(n), 5):
			var b := Campaign.board(n, i)
			var gs := Campaign.new_state(n, b)
			var hist: Array = [gs.clone()]
			for st in (b["solution"] as Array):
				var ab: Array = Days.solution_step(st)
				gs.play(ab[0], ab[1])
				if gs.day_won:
					break
				hist.append(gs.clone())
			if not gs.day_won:
				continue
			for h in hist:
				states += 1
				(h as GameState).satt_ids9()          # Nachbarn und Gruppen der Kopie sind dann gerechnet (zählen nicht zur Prüfung)
				var tu := Time.get_ticks_usec()
				var r := (h as GameState).reach9()
				worst = maxi(worst, Time.get_ticks_usec() - tu)
				if not bool(r["ok"]) and alarms.size() < 5:
					alarms.append([n, i, (h as GameState).steps9(), r])
	print("  reach14: %d Stände entlang der Pool-Lösungen, reach9 höchstens %.2f ms (%d ms)" % [states, worst / 1000.0, Time.get_ticks_msec() - t0])
	check(alarms.is_empty() and states > 1200, "reach14: kein Fehlalarm auf %d Ständen entlang gewinnender Pool-Lösungen (%s)" % [states, str(alarms.slice(0, 2))])
	check(worst < 6000, "reach14: reach9 höchstens %.2f ms am PC (allein gemessen etwa 1,5 ms)" % (worst / 1000.0))
	# 2. Echte Sackgassen werden gesehen
	var dead: Array = []
	# Level 1: 6 Lava nur auf Ecken (keine Reihe möglich, kein Regen im Level)
	var set1 := {}
	var probe := camp_state(1)
	var nc := 0
	for f in probe.fields:
		if FieldData.sticker_type(f.p) == 3 and nc < 6:
			set1[f.id] = LAVA
			nc += 1
	var g1 := camp_state(1, set1)
	var r1 := g1.reach9()
	if bool(r1["ok"]) or str(r1["why"]) != "rows":
		dead.append(["L1 Ecken", r1])
	# Level 8 mit 1 Lava: Ursuppe braucht 2 Wärme
	var g8 := Campaign.new_state(8, Campaign.board(8, 1))
	var keep := true
	for f in g8.fields:
		if f.kind == LAVA:
			if keep:
				keep = false
			else:
				g8._setk9(f, STONE)
	var r8 := g8.reach9()
	if bool(r8["ok"]) or str(r8["why"]) != "needs" or int(r8["kind"]) != LAVA:
		dead.append(["L8 eine Lava", r8])
	# Level 13 mit 1 Fels: Quallen brauchen 2 Fels
	var g13 := Campaign.new_state(13, Campaign.board(13, 1))
	keep = true
	for f in g13.fields:
		if f.kind == STONE:
			if keep:
				keep = false
			else:
				g13._setk9(f, E)
	if bool(g13.reach9()["ok"]):
		dead.append(["L13 ein Fels", g13.reach9()])
	# Level 26 ohne Insekten, 46 ohne Fels, 47 ohne Feuerstelle
	for item in [[26, FieldData.INSECTS, WATER], [46, STONE, WATER], [47, FieldData.CAMP, WATER]]:
		var gx := Campaign.new_state(int(item[0]), Campaign.board(int(item[0]), 1))
		for f in gx.fields:
			if f.kind == int(item[1]):
				gx._setk9(f, int(item[2]))
		var rx := gx.reach9()
		if bool(rx["ok"]) or gx.stuck9() != "dead" or gx.gift_plan9().is_empty():
			dead.append(["L%d ohne %s" % [int(item[0]), FieldData.kind_name(int(item[1]))], rx])
	# Level 49 mit 2 Frühmenschen und keiner Hütte: nie 3 Hütten
	var g49 := camp_state(49, {0: FieldData.EARLY, 9: FieldData.EARLY, 20: ANIMALS, 30: FOREST})
	var r49 := g49.reach9()
	if bool(r49["ok"]) or str(r49["why"]) != "few":
		dead.append(["L49", r49])
	# Level 41: 53 Eis und 1 Mammut
	var set41 := {}
	for i41 in 54:
		set41[i41] = FieldData.ICE
	set41[7] = FieldData.MAMMOTH
	var g41 := camp_state(41, set41)
	if bool(g41.reach9()["ok"]):
		dead.append(["L41 Eis", g41.reach9()])
	check(dead.is_empty(), "reach14: echte Sackgassen erkannt (L1 Ecken, L8 eine Lava, L13 ein Fels, L26/46/47 ohne Quelle, L49, L41) (%s)" % str(dead.slice(0, 3)))
	# 3. Versiegelte Dörfer neben Kirchen (Level 58, Meldung der Prüfung): kein Fehlalarm
	var p58 := camp_state(58)
	var set58 := {}
	var used := {}
	var placed := 0
	for f in p58.fields:
		if placed >= 3:
			break
		if FieldData.sticker_type(f.p) != 2 or used.has(f.id):
			continue
		var nbf := -1
		for g in p58.nb9(f.id):
			if not used.has(int(g)) and (p58.fields[int(g)] as FieldData).p != f.p:
				var free := true
				for g2 in p58.nb9(int(g)):
					if used.has(int(g2)):
						free = false
				if free:
					nbf = int(g)
					break
		if nbf < 0:
			continue
		var clash := false
		for g3 in p58.nb9(f.id):
			if used.has(int(g3)):
				clash = true
		if clash:
			continue
		set58[f.id] = VILLAGE
		set58[nbf] = CHURCH
		used[f.id] = true
		used[nbf] = true
		for g4 in p58.nb9(f.id):
			used[int(g4)] = true
		for g5 in p58.nb9(nbf):
			used[int(g5)] = true
		placed += 1
	var g58 := camp_state(58, set58)
	for f in g58.fields:
		if f.kind == VILLAGE:
			f.best = {"food": 1, "work": 1}
	check(placed == 3 and g58.church_touch9().is_empty() and bool(g58.reach9()["ok"]),
		"reach14: Level 58 – 3 versorgte (versiegelte) Dörfer neben Kirchen, kein Futter auf dem Brett: kein Fehlalarm (%s)" % str(g58.reach9()))


## A6: Die Gefahr nimmt nie das Letzte, was das Ziel braucht.
func test_last_holds14() -> void:
	var t0 := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	var broke: Array = []
	var holds := 0
	var rounds := 0
	for n in [27, 41, 42, 47, 48, 55, 56, 57, 58, 59]:
		for bi in [1]:
			rng.seed = n * 100 + bi
			var gs := Campaign.new_state(n, Campaign.board(n, bi))
			for i in 60:
				if gs.day_won:
					break
				var mv: Array = GameState.MOVES[rng.randi_range(0, 26)]
				# Nur die Gefahr zählt: was die Drehung selbst anrichtet (Reihen, die Quellen verbrauchen), ist Sache des Netzes
				var pre := gs.clone()
				pre.apply_rotation(int(mv[0]), int(mv[1]), int(mv[2]))
				pre._resolve_merges9([])
				var before_ok := bool(pre.reach9()["ok"])
				var r := tw(gs, mv)
				rounds += 1
				for e in r["events"]:
					if str(e["type"]) == "hold_last":
						holds += 1
				if before_ok and not gs.day_won and not bool(gs.reach9()["ok"]):
					var danger := false
					for tp in _types(r):
						if ["starve", "burn", "erupt", "pack_hunt", "freeze", "polluted", "flood", "war_hit"].has(tp):
							danger = true
					if danger and broke.size() < 5:
						broke.append([n, bi, i, gs.reach9()])
	print("  hold14: %d Runden in 10 späten Leveln, %d× „Hält durch!“ (%d ms)" % [rounds, holds, Time.get_ticks_msec() - t0])
	check(broke.is_empty(), "hold14: keine Gefahr macht ein Level unerreichbar (%d Runden, %s)" % [rounds, str(broke.slice(0, 2))])
	# Level 56: genau 3 Städte, Krieg läuft – die Front nimmt keine der drei
	var p := camp_state(56)
	var c1 := 4
	var c2 := other_nb(p, c1, 0)
	var towns: Array = []
	for g in p.nb9(c1):
		if int(g) != c2 and towns.size() < 2:
			towns.append(int(g))
	for g2 in p.nb9(c2):
		if int(g2) != c1 and not towns.has(int(g2)) and towns.size() < 3:
			towns.append(int(g2))
	var set := {c1: CHURCH, c2: CHURCH}
	for t in towns:
		set[int(t)] = TOWN
	# Futter und Arbeit auf jeder Sticker-Art (sonst wäre das Ziel schon vorher unerreichbar)
	var extra := {1: 0, 2: 0, 3: 0}
	for f in p.fields:
		var tt := FieldData.sticker_type(f.p)
		if set.has(f.id) or int(extra[tt]) >= 4:
			continue
		var near_war := false
		for g3 in p.nb9(f.id):
			if set.has(int(g3)) and int(set[int(g3)]) != FIELD and int(set[int(g3)]) != FOREST:
				near_war = true
		if near_war:
			continue
		set[f.id] = FIELD if int(extra[tt]) % 2 == 0 else FOREST
		extra[tt] = int(extra[tt]) + 1
	var gw := camp_state(56, set)
	var keep: Array = [c1, c2]
	keep.append_array(towns)
	var m := move_avoiding(gw, keep)
	var ev_hold := false
	var hits := 0
	for i2 in 8:
		var r2 := tw(gw, m)
		if _types(r2).has("hold_last"):
			ev_hold = true
		hits += _count_events(r2, "war_hit")
	# Der Krieg darf Städte zu Dörfern und Hütten machen (die wachsen wieder), aber nie die letzten drei Menschen-Felder
	# zur Wiese: aus einer Wiese wird in diesem Level nie wieder eine Stadt
	var people := _cnt14(gw, TOWN) + _cnt14(gw, VILLAGE) + _cnt14(gw, HUT)
	check(towns.size() == 3 and people == 3 and ev_hold and hits >= 3 and bool(gw.reach9()["ok"]),
		"hold14: Level 56 mit genau 3 Städten im Krieg – die letzten drei Menschen-Felder halten durch (%d übrig, %d Treffer)" % [people, hits])
	# Modell-Modus: kein Schutz (der Abgleich mit dem Modell bleibt)
	GameState.engine9_mode = true
	var gm := camp_state(56, set)
	for i3 in 8:
		tw(gm, m)
	var people_m := _cnt14(gm, TOWN) + _cnt14(gm, VILLAGE) + _cnt14(gm, HUT)
	GameState.engine9_mode = false
	check(people_m < 3, "hold14: im Modell-Modus trifft der Krieg wie im Modell (%d Menschen-Felder übrig)" % people_m)
	# Der Meteor des Spielers wird nie aufgehalten
	var gmet := camp_state(56, set)
	gmet.meteors = 1
	gmet.play({"type": "strike", "field": int(towns[0])})
	check((gmet.fields[int(towns[0])] as FieldData).kind == E, "hold14: der Meteor des Spielers trifft immer")


## A7: Die Hilfe nimmt kein Wasser weg und sagt, was sie bringt.
func test_net_water14() -> void:
	for n in [2, 3]:
		var gs := Campaign.new_state(n, Campaign.board(n, 1))
		var left := 3
		for f in gs.fields:
			if f.kind == LAVA:
				if left > 0:
					left -= 1
				else:
					gs._setk9(f, STONE)
		var w0 := _cnt14(gs, WATER)
		var s0 := _cnt14(gs, STONE)
		var line := gs.rescue_line9("dead")
		var c := gs.clone()
		var top := c.top_up9(6)
		check(not top.is_empty() and _cnt14(c, WATER) == w0 and _cnt14(c, STONE) < s0 and line == "Zu wenig Lava. Ich helfe.",
			"net14: Level %d mit 3 Lava – Nachschub aus Fels, das Wasser bleibt (%d → %d Wasser, „%s“)" % [n, w0, _cnt14(c, WATER), line])
		var pills: Array = []
		for i in 6:
			if gs.day_won or gs.gift_plan9().is_empty():
				break
			var r := gs.play({"type": "gift"})
			pills.append(GameState.gift_line9(r))
		check(_cnt14(gs, WATER) == w0 and not pills.is_empty() and str(pills[0]).begins_with("Geschenk: +") and str(pills[0]).ends_with("Lava"),
			"net14: Level %d – sechs Geschenke lassen das Wasser, wie es ist (%d → %d), Pille „%s“" % [n, w0, _cnt14(gs, WATER), str(pills[0]) if not pills.is_empty() else ""])
	# Level 5, 20, 22: das Material der Kette wird knapp – der Nachschub nimmt kein Wasser, solange es anderes gibt
	var took: Array = []
	for item in [[5, STONE, 2], [20, MOSS, 1], [22, FERN, 1]]:
		var n2 := int(item[0])
		var g2 := Campaign.new_state(n2, Campaign.board(n2, 1))
		var keepn := int(item[2])
		for f in g2.fields:
			if f.kind == int(item[1]):
				if keepn > 0:
					keepn -= 1
				else:
					g2._setk9(f, E if n2 != 5 else LAVA)
		var w1 := _cnt14(g2, WATER)
		g2.top_up9(6)
		for i2 in 4:
			if not g2.day_won and not g2.gift_plan9().is_empty():
				g2.play({"type": "gift"})
		if _cnt14(g2, WATER) < w1:
			took.append([n2, w1, _cnt14(g2, WATER)])
	check(took.is_empty(), "net14: Level 5, 20, 22 – Nachschub und Geschenk nehmen kein Wasser (%s)" % str(took))
	# Die Sätze der Hilfe nennen, was fehlt
	var g3 := Campaign.new_state(3, Campaign.board(3, 2))
	for f in g3.fields:
		if f.kind == LAVA:
			g3._setk9(f, WATER)
	check(g3.rescue_line9("dead").contains("Lava") and g3.rescue_line9("stall") == "Hängst du fest? Ich helfe dir.",
		"net14: „%s“" % g3.rescue_line9("dead"))
	var set15 := {}
	var p15 := camp_state(15)
	for f in p15.fields:
		if FieldData.sticker_type(f.p) == 3 and set15.size() < 8:
			set15[f.id] = FieldData.JELLY
	var g15 := camp_state(15, set15)
	g15.made[FISH] = 5
	check(not bool(g15.reach9()["ok"]) and g15.rescue_line9("dead") == "Keine Reihe möglich. Ich helfe.", "net14: keine Reihe möglich → „%s“ (%s)" % [g15.rescue_line9("dead"), str(g15.reach9())])


## A8: Oben steht immer eine Handlung, die geht, und sie führt nie im Kreis.
func test_line_follow14() -> void:
	var t0 := Time.get_ticks_msec()
	var bad: Array = []
	var lost: Array = []
	var loops: Array = []
	var worst_t := 0
	var steps_sum := 0
	for n in range(1, 31):
		var gs := Campaign.new_state(n, Campaign.board(n, 1))
		var tu := Time.get_ticks_usec()
		gs.next_action()
		worst_t = maxi(worst_t, Time.get_ticks_usec() - tu)
		var res := _follow14(gs, 4 * gs.par9, false, bad, "folgen")
		steps_sum += int(res["steps"])
		if not bool(res["won"]):
			lost.append([n, res])
		if int(res["most"]) >= 3:
			loops.append([n, int(res["most"])])
	# die Kreise aus der Prüfung: Level 16 Brett 10, Level 59 Brett 5 und 9, Level 51 Brett 1, Level 60 Brett 3
	for item in [[16, 10], [59, 5], [59, 9], [51, 1], [60, 3]]:
		var g2 := Campaign.new_state(int(item[0]), Campaign.board(int(item[0]), int(item[1])))
		var r2 := _follow14(g2, 6 * g2.par9, true, bad, "Kreis")
		if not bool(r2["won"]):
			lost.append([item, r2])
		if int(r2["most"]) >= 3:
			loops.append([item, int(r2["most"])])
	print("  folgen14: Level 1–30 nur mit der Zeile, zusammen %d Schritte; erste Zeile höchstens %.1f ms (%d ms)" % [steps_sum, worst_t / 1000.0, Time.get_ticks_msec() - t0])
	check(lost.is_empty(), "folgen14: wer nur der Zeile folgt, gewinnt Level 1–30 (Brett 1) in 4 × Par ohne Hilfe; die Kreis-Bretter mit Netz (%s)" % str(lost.slice(0, 3)))
	check(loops.is_empty(), "folgen14: keine Stellung dreimal (%s)" % str(loops.slice(0, 4)))
	check(bad.is_empty(), "folgen14: jede Zeile hat eine Scheibe oder ein Werkzeug und geht (%s)" % str(bad.slice(0, 4)))
	# Jeder Stand: sorgloser Spieler 20 Drehungen auf Brett 1 jedes Levels, an jedem Stand die Zeile prüfen
	var t1 := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	var bad2: Array = []
	var states := 0
	var worst2 := 0
	for n2 in range(1, Campaign.COUNT + 1):
		rng.seed = 5000 + n2
		var g3 := Campaign.new_state(n2, Campaign.board(n2, 1))
		for i in 5:
			if g3.day_won:
				break
			var tu2 := Time.get_ticks_usec()
			var a := g3.next_action()
			worst2 = maxi(worst2, Time.get_ticks_usec() - tu2)
			_line_ok14(g3, a, bad2, "sorglos")
			states += 1
			_careless14(g3, rng, 1, false)
	print("  folgen14: %d sorglose Stände, die Zeile höchstens %.1f ms (%d ms)" % [states, worst2 / 1000.0, Time.get_ticks_msec() - t1])
	check(bad2.is_empty() and states > 250, "folgen14: an %d sorglosen Ständen aller Level nennt die Zeile eine Handlung, die geht (%s)" % [states, str(bad2.slice(0, 4))])
	check(maxi(worst_t, worst2) < 80000, "folgen14: die Zeile kostet höchstens %.1f ms am PC" % (maxi(worst_t, worst2) / 1000.0))
	# Gefahr ohne Abhilfe: rot, mit Scheibe; dieselbe Gefahr höchstens 2 Runden in Folge
	var g59 := Campaign.new_state(59, Campaign.board(59, 1))
	var run := 0
	var most_run := 0
	var last := ""
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 59
	_careless14(g59, rng2, 5, false)
	for i2 in 30:
		if g59.day_won:
			break
		var a2 := g59.next_action()
		var dg := str(a2.get("danger", "")) if str(a2["type"]) == "danger" else ""
		if dg != "" and dg == last:
			run += 1
		else:
			run = 1 if dg != "" else 0
		last = dg
		most_run = maxi(most_run, run)
		var mv2: Dictionary = a2.get("move", {})
		if str(a2.get("tool", "")) == "rain":
			g59.play({"type": "rain", "field": int(a2["field"])})
			last = ""
		elif str(a2.get("tool", "")) == "gift":
			g59.play({"type": "gift"})
		elif not mv2.is_empty():
			tw(g59, [int(mv2["axis"]), int(mv2["layer"]), int(mv2["turns"])])
	check(most_run <= 3, "folgen14: Level 59 – dieselbe Gefahr steht nie endlos oben (höchstens %d in Folge)" % most_run)


## A9: Ein Tor für jeden Start; alte Stände landen heil.
func test_start_gate14() -> void:
	var t0 := Time.get_ticks_msec()
	var bad: Array = []
	var starts := 0
	var levels: Array = range(2, 15)
	levels.append_array([19, 24, 29, 34, 39, 44, 49, 54, 59])
	for n in levels:
		if Campaign.first_of_era(n):
			continue
		var worlds: Array = []
		var all_w: Array = []
		var all_f: Array = []
		for i in 54:
			all_w.append(WATER)
			all_f.append(STONE)
		var prev := Campaign.new_state(n - 1, Campaign.board(n - 1, 3))
		for st in (Campaign.board(n - 1, 3)["solution"] as Array):
			var ab: Array = Days.solution_step(st)
			prev.play(ab[0], ab[1])
		worlds.append(Campaign.decode(prev.slot_board9()))
		if n <= 14:
			worlds.append(all_w)
			worlds.append(all_f)
		for wi in worlds.size():
			var b := Campaign.carry(worlds[wi], n, 7 + wi, 2)
			b = Campaign.ensure(n, b, 2)
			var gs := Campaign.new_state(n, b)
			starts += 1
			if not bool(gs.reach9()["ok"]) or not gs.lines().is_empty() or _cnt14(gs, WATER) != _water_of(n) or Campaign._all_met(gs) \
					or not Campaign.gate(n, b["kinds"], int(b["seed"])):
				bad.append([n, wi, str(b.get("how", "")), _cnt14(gs, WATER), _water_of(n), gs.reach9()])
			if str(b.get("how", "")) == "fallback" and str(b.get("line", "")) != str(Campaign.TEXT["fresh"]):
				bad.append([n, wi, "stiller Rückfall"])
	check(bad.is_empty() and starts >= 30, "gate14: %d getragene Starts aus gelöster Welt, nur Wasser, nur Fels: erreichbar, keine Reihe, genau das Wasser der Mischung (%s)" % [starts, str(bad.slice(0, 3))])
	# Müll als gespeichertes Start-Brett (54 Arten des Levels, kein Wasser), mit und ohne Fingerabdruck: alle 60 Level
	var t := lt(2026, 11, 12, 10)
	var g := _daily_game("user://test_gate14.cfg", t, true)
	g.debug_open_all = true
	var bad2: Array = []
	for n2 in range(1, Campaign.COUNT + 1):
		var comp: Dictionary = Campaign.config(n2)["comp"]
		var land := -1
		for key in comp:
			if not FieldData.water_family(int(str(key))):
				land = int(str(key))
		var junk: Array = []
		for i2 in 54:
			junk.append(land if land >= 0 else STONE)
		for with_print in [true, false]:
			g.camp["start"] = Campaign.encode(junk)
			g.camp["start_level"] = n2
			g.camp["start_seed"] = 5
			g.camp["start_cfg"] = GameScript._cfg_hash(Campaign.config(n2)) if with_print else ""
			g.camp["world"] = ""
			g.camp["world_level"] = 0
			g._clear_run()
			var ok: bool = g.start_level(n2)
			var gs2: GameState = g.state
			if not ok or not bool(gs2.reach9()["ok"]) or not gs2.lines().is_empty() or _cnt14(gs2, WATER) != _water_of(n2) \
					or str(g.level_board.get("how", "")) == "stored":
				bad2.append([n2, with_print, ok, str(g.level_board.get("how", "")), _cnt14(gs2, WATER)])
	check(bad2.is_empty(), "gate14: ein Start-Brett ohne Wasser wird in keinem der 60 Level benutzt (mit und ohne Fingerabdruck): das Level beginnt mit seinem Wasser (%s)" % str(bad2.slice(0, 3)))
	# Ein Pool-Brett, das als gespeichertes Start-Brett zurückkommt, bleibt gleich und ohne „Neuer Morgen“ (Level 5 Brett 2)
	var nights: Array = []
	g.overnight_growth.connect(func(info): nights.append(info))
	g._clear_run()
	g.camp["start"] = ""
	g.camp["start_level"] = 0
	check(g.start_level(5, 2), "gate14: Level 5 Brett 2 startet")
	var first: Array = _kinds_of(g.state)
	(g.camp["stars"] as Array)[0] = 2          # Level 1 ist geschafft: ein Blick dorthin ändert das Start-Brett von Level 5 nicht
	check(g.start_level(1, 1) and g.start_level(5), "gate14: Level 5 wieder geöffnet")
	check(_kinds_of(g.state) == first and str(g.level_board.get("how", "")) == "stored" and nights.is_empty(),
		"gate14: das gespeicherte Start-Brett kommt genau so zurück, ohne Welle (%s, %d Wellen)" % [str(g.level_board.get("how", "")), nights.size()])
	# Fortgesetzter Versuch in einer Sackgasse: die Hilfe kommt vor der ersten Drehung
	g._clear_run()
	check(g.start_level(3, 1), "gate14: Level 3 startet")
	var res: Dictionary = g.state.play({"type": "twist", "axis": 0, "layer": 1, "turns": 1})
	g.busy = true
	g.finish_round(res)
	for fd in g.state.fields:
		if fd.kind == LAVA:
			g.state._setk9(fd, WATER)
	g.rescue_offer = {}
	g.dead_told = false
	g._save_run()
	var told: Array = []
	g.level_dead.connect(func(info2): told.append(info2))
	var again: bool = g.resume_run()
	var info3: Dictionary = told[0] if not told.is_empty() else {}
	check(again and told.size() == 1 and str(info3.get("why", "")) == "dead" and bool(info3.get("gift", false)) and str(info3.get("line", "")).contains("Lava"),
		"gate14: fortgesetzter Versuch ohne Lava – Hilfe sofort („%s“)" % str(info3.get("line", "")))
	# Ein Versuch aus einem älteren Build (andere Regel-Version) beginnt neu
	var cf := ConfigFile.new()
	cf.load(g.run_path())
	var d: Dictionary = cf.get_value("lauf", "daten", {})
	d.erase("rv")
	cf.set_value("lauf", "daten", d)
	cf.save(g.run_path())
	check(g.saved_run().is_empty() and not g.resume_run() and not FileAccess.file_exists(g.run_path()),
		"gate14: ein Versuch ohne die Regel-Version von Build 14 gilt nicht mehr (beginnt neu)")
	g.free()
	# Stand aus Build 13 (Version 2, Start-Brett ohne Fingerabdruck und ohne Wasser, Versuch mit altem Fingerabdruck)
	var path := "user://test_gate14_b13.cfg"
	var c13 := ConfigFile.new()
	var st: Array = []
	var wk: Array = []
	for j in Campaign.COUNT:
		st.append(2 if j < 5 else 0)
		wk.append(20000 + j if j < 5 else -1)
	var dry: Array = []
	for i3 in 54:
		dry.append(STONE if i3 % 3 else LAVA)
	c13.set_value("kampagne", "version", 2)
	c13.set_value("kampagne", "kette", 5)
	c13.set_value("kampagne", "sterne", st)
	c13.set_value("kampagne", "gewonnen_am", wk)
	c13.set_value("kampagne", "letzter_neuer", Daily.day_key(t) - 1)
	c13.set_value("kampagne", "start", Campaign.encode(dry))
	c13.set_value("kampagne", "start_level", 6)
	c13.set_value("kampagne", "start_seed", 4)
	c13.save(path)
	var run := ConfigFile.new()
	run.set_value("lauf", "daten", {"v": 1, "level": 6, "wdt": -1, "cfg": var_to_str(Campaign.config(6)).md5_text(), "state": Campaign.new_state(6, Campaign.board(6, 1)).save9()})
	run.save(path.get_basename() + "_lauf.cfg")
	var g13 := _daily_game(path, t, false)
	var had_run: bool = not g13.saved_run().is_empty()
	var ok13: bool = g13.start_level(6)
	check(not had_run and ok13 and not g13.run_resumed and _cnt14(g13.state, WATER) == _water_of(6) and bool(g13.state.reach9()["ok"])
		and str(g13.level_board.get("how", "")) != "stored",
		"gate14: Stand aus Build 13 – Versuch beginnt neu, das Start-Brett ohne Wasser fällt weg, Level 6 beginnt mit %d Wasser" % _cnt14(g13.state, WATER))
	g13.free()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute("user://test_gate14.cfg")
	print("  gate14: %d ms" % (Time.get_ticks_msec() - t0))


## A10: Die Nacht behält die Welt (weniger Umbau) und sagt, was sich geändert hat.
func test_night14() -> void:
	var t0 := Time.get_ticks_msec()
	var changed := 0
	var carried := 0
	var bad: Array = []
	var worst := 0
	for n in [2, 3, 6, 7, 9, 10, 13, 14, 16, 17, 19, 22, 24, 26, 27, 29, 31, 32, 33, 35, 37, 39, 41, 42, 44, 45, 47, 49, 51,
			53, 55, 58, 60]:
		var prev := Campaign.new_state(n - 1, Campaign.board(n - 1, 4))
		for st in (Campaign.board(n - 1, 4)["solution"] as Array):
			var ab: Array = Days.solution_step(st)
			prev.play(ab[0], ab[1])
		var world := Campaign.decode(prev.slot_board9())
		var tu := Time.get_ticks_usec()
		var c1 := Campaign.carry(world, n, 3)
		worst = maxi(worst, Time.get_ticks_usec() - tu)
		if str(c1["how"]) != "carry":
			var e1 := Campaign.ensure(n, c1, 0)
			if str(e1.get("line", "")) != str(Campaign.TEXT["fresh"]):
				bad.append([n, "Rückfall ohne Satz"])
			continue
		carried += 1
		changed += (c1["changed"] as Array).size()
		var pair := Campaign.night_pair(world, c1["kinds"])
		var real := 0
		for i in 54:
			if int(world[i]) == int(pair.get("from", -1)) and int((c1["kinds"] as Array)[i]) == int(pair.get("to", -1)):
				real += 1
		if pair.is_empty() or real != int(pair["n"]) or real == 0:
			bad.append([n, pair])
	var mean := float(changed) / maxf(1.0, float(carried))
	print("  nacht14: %d getragene Welten, im Mittel %.1f geänderte Felder, carry höchstens %.0f ms (%d ms)" % [carried, mean, worst / 1000.0, Time.get_ticks_msec() - t0])
	check(carried >= 15 and mean <= 18.0, "nacht14: die Nacht ändert im Mittel höchstens 18 Felder (%.1f; Build 13: 26)" % mean)
	check(bad.is_empty() and worst < 1000000, "nacht14: das genannte Paar stimmt mit der Welt überein, ein Rückfall sagt „Heute eine frische Welt“ (%s)" % str(bad.slice(0, 3)))
	# Im Spiel: Level 6 gewonnen, am nächsten Tag Level 7 – der Banner nennt die größte Änderung
	var t := lt(2026, 11, 12, 10)
	var g := _daily_game("user://test_night14.cfg", t, true)
	for i2 in 5:
		(g.camp["stars"] as Array)[i2] = 2
		(g.camp["won_key"] as Array)[i2] = Daily.day_key(t) - 6 + i2
	g.camp["pos"] = 5
	g.camp["last_new_key"] = Daily.day_key(t) - 1
	var nights: Array = []
	g.overnight_growth.connect(func(info): nights.append(info))
	check(g.start_level(6), "nacht14: Level 6 startet")
	_replay_in_game(g)
	check(g.state.day_won and int(g.camp["world_level"]) == 6, "nacht14: Level 6 gewonnen, die Welt ist gemerkt")
	g.clock_override = t + Daily.DAY
	nights.clear()
	check(g.start_level(7), "nacht14: Level 7 am nächsten Tag")
	var line := str((nights[0] as Dictionary).get("line", "")) if not nights.is_empty() else ""
	check(str(g.level_board.get("how", "")) == "carry" and line == "Über Nacht: Ursuppe → Wasser" and line.split(" ", false).size() <= 6,
		"nacht14: der Banner nennt die größte Änderung („%s“, %s)" % [line, str(g.level_board.get("how", ""))])
	if not nights.is_empty():
		var chs: Array = (nights[0] as Dictionary).get("changes", [])
		var first_c: Dictionary = chs[0] if not chs.is_empty() else {}
		check(int(first_c.get("from", -1)) == SOUP and int(first_c.get("kind", -1)) == WATER, "nacht14: die Welle zeigt zuerst Felder des genannten Paars")
	g.free()
	DirAccess.remove_absolute("user://test_night14.cfg")


## A11: Der Tipp widerspricht der Zeile nicht (Level 17 Brett 1: der Tipp allein gewann nicht).
func test_hint14() -> void:
	var t0 := Time.get_ticks_msec()
	var lost: Array = []
	var notes: Array = []
	for item in [[17, 1]]:
		var n := int(item[0])
		var gs := Campaign.new_state(n, Campaign.board(n, int(item[1])))
		var r := _hint14(gs, 4 * gs.par9, false)
		notes.append("%d/%d: %d" % [n, int(item[1]), int(r[1])])
		if not bool(r[0]):
			lost.append([item, r])
	print("  tipp14: Tipp allein %s (%d ms)" % [str(notes), Time.get_ticks_msec() - t0])
	check(lost.is_empty(), "tipp14: der Tipp allein gewinnt Level 17 Brett 1 in 4 × Par (%s)" % str(lost))


## A12: Nie festgefahren – aus drei entarteten Starts je Level gewinnt selbst der Zufallsspieler mit dem Netz.
func test_never_stuck14() -> void:
	var t0 := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	var fails: Array = []
	var runs := 0
	var gifts := 0
	var flat := 0
	for n in range(1, Campaign.COUNT + 1):
		if n % 3 != 0 and (n < 6 or n > 14):
			continue                   # alle Level der Ursuppe- und Regen-Zeit (6–14), sonst jedes dritte
		var base: Array = Campaign.board(n, 1)["kinds"]
		var probe := Campaign.new_state(n, Campaign.board(n, 1))
		var chain := probe.chain9
		var starts: Array = []
		# 1 kein Wasser (Wasser wird die häufigste Land-Art des Bretts)
		var cnt := {}
		for k in base:
			if not FieldData.water_family(int(k)):
				cnt[int(k)] = int(cnt.get(int(k), 0)) + 1
		var land := STONE
		var most := 0
		for k2 in cnt:
			if int(cnt[k2]) > most or (int(cnt[k2]) == most and int(k2) < land):
				most = int(cnt[k2])
				land = int(k2)
		var dry: Array = []
		for k3 in base:
			dry.append(land if int(k3) == WATER else int(k3))
		starts.append(dry)
		# 2 jede Art der Ziel-Kette fehlt (wird Wasser)
		var bare: Array = []
		for k4 in base:
			bare.append(WATER if chain.has(int(k4)) else int(k4))
		starts.append(bare)
		# 3 Brett 1 nach 40 sorglosen Drehungen, jeder Regen auf Wasser
		rng.seed = 1400 + n
		var gc := Campaign.new_state(n, Campaign.board(n, 1))
		_careless14(gc, rng, 40, true)
		if not gc.day_won:
			starts.append(Campaign.decode(gc.slot_board9()))
		for si in starts.size():
			# wie ein Start aus der eigenen Welt: Nachschub oder das Pool-Brett (Campaign.ensure)
			var b := Campaign.ensure(n, {"kinds": starts[si], "seed": 3 + si, "how": "carry"}, 1)
			var gs := Campaign.new_state(n, b)
			if not bool(gs.reach9()["ok"]) or not gs.lines().is_empty():
				fails.append(["start", n, si, gs.reach9()])
				continue
			rng.seed = n * 31 + si
			runs += 1
			var res := _net_play14(gs, rng, 150)
			gifts += int(res[2])
			flat += int(res[4])
			if not bool(res[0]) or int(res[3]) > 0:
				fails.append(["play", n, si, res, gs.progress9(), gs.target9()])
	print("  nie14: %d entartete Starts, alle gewonnen (Zufallsspieler mit Netz), %d Geschenke (%d ms)" % [runs, gifts, Time.get_ticks_msec() - t0])
	check(fails.is_empty() and runs >= 50, "nie14: aus jedem entarteten Start (kein Wasser, Ziel-Kette fehlt, verspielte Welt) gewinnbar, nie ein Angebot ohne Geschenk (%s)" % str(fails.slice(0, 3)))
	check(flat == 0, "nie14: jedes Geschenk bringt Fortschritt (%d ohne)" % flat)


## Wie _net_play, zählt aber auch Geschenke ohne Fortschritt. [gewonnen, Schritte, Geschenke, ohne Geschenk, flach]
func _net_play14(gs: GameState, rng: RandomNumberGenerator, cap: int) -> Array:
	var told_at := -99
	var dead_told := false
	var gifts := 0
	var acts := 0
	var nogift := 0
	var flat := 0
	while not gs.day_won and gs.twists < cap and acts < cap * 3:
		acts += 1
		var did := false
		if gs.rain > 0 and rng.randf() < 0.3:
			var cand: Array = []
			for f in gs.fields:
				if gs.rain_ok9(f):
					cand.append(f.id)
			if not cand.is_empty():
				gs.play({"type": "rain", "field": int(cand[rng.randi_range(0, cand.size() - 1)])})
				did = true
		if not did:
			tw(gs, GameState.MOVES[rng.randi_range(0, GameState.MOVES.size() - 1)])
		if gs.day_won:
			break
		var why := gs.stuck9()
		if why != "dead":
			dead_told = false
		if why == "":
			continue
		if (why == "dead" and not dead_told) or gs.steps9() - told_at >= GameState.STALL9:
			dead_told = why == "dead"
			told_at = gs.steps9()
			if gs.gift_plan9().is_empty():
				nogift += 1
			else:
				var s0 := gs._subs_sum9() + gs.progress9()
				gs.play({"type": "gift"})
				gifts += 1
				if gs._subs_sum9() + gs.progress9() <= s0 and not gs.day_won:
					flat += 1
	return [gs.day_won, gs.steps9(), gifts, nogift, flat]


## Dauerhafte Prüfung 1 – der Start: Aus den Welten, die ein sorgloser oder übereifriger Spieler hinterlässt, aus
## Extrem-Welten (kein Wasser, nur Wasser, nur eine Art) und aus umgestellten Ständen von Build 12 ist jedes geprüfte
## Level für den Tipp-Bot gewinnbar.
func test_start_invariant14() -> void:
	var t0 := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	var fails: Array = []
	var starts := 0
	var hint_won := 0
	var hint_runs := 0
	var gifts := 0
	var bad: Array = []
	for n in [2, 3, 6, 7, 9, 10, 11, 14, 27, 42, 48, 57]:
		if Campaign.first_of_era(n):
			continue
		# gestern: Brett 2 von Level n − 1, erst 30 sorglose Drehungen (jeder Regen aufs Wasser), dann mit der Zeile fertig
		rng.seed = 7000 + n
		var prev := Campaign.new_state(n - 1, Campaign.board(n - 1, 2))
		_careless14(prev, rng, 30, true)
		var rp := _follow14(prev, 200, true, bad, "gestern")
		if not bool(rp["won"]):
			fails.append(["gestern", n - 1, rp])
			continue
		var worlds: Array = [Campaign.decode(prev.slot_board9())]
		if n % 3 == 0:
			var dry: Array = []
			var one: Array = []
			var wet: Array = []
			for i in 54:
				dry.append(STONE if i % 2 == 0 else E)
				one.append(int((worlds[0] as Array)[0]))
				wet.append(WATER)
			worlds.append(dry)
			worlds.append(one)
			worlds.append(wet)
		for wi in worlds.size():
			var b := Campaign.carry(worlds[wi], n, 11 + wi, 1)
			b = Campaign.ensure(n, b, 1)
			var gs := Campaign.new_state(n, b)
			starts += 1
			if not bool(gs.reach9()["ok"]) or not gs.lines().is_empty() or _cnt14(gs, WATER) != _water_of(n):
				fails.append(["start", n, wi, str(b.get("how", "")), _cnt14(gs, WATER), _water_of(n)])
				continue
			if wi == 0 and [7, 9, 14, 27, 42, 57].has(n):
				hint_runs += 1
				var rh := _hint14(gs, 6 * gs.par9, true)
				gifts += int(rh[2])
				if bool(rh[0]):
					hint_won += 1
				else:
					fails.append(["tipp", n, wi, rh])
			else:
				var rf := _follow14(gs, 6 * gs.par9, true, bad, "start")
				if not bool(rf["won"]):
					fails.append(["zeile", n, wi, rf])
	# Stände aus Build 12 (alte Kampagne mit 30 Leveln): altes Level k geschafft, dazu ein altes Start-Brett ohne
	# Wasser und ein laufender Versuch – jedes Level, das danach offen ist, beginnt heil und ist gewinnbar
	var t := lt(2026, 11, 12, 10)
	var path := "user://test_start14_b12.cfg"
	var b12 := 0
	for old_top in [5, 6]:
		var cfg := ConfigFile.new()
		var st: Array = []
		var wk: Array = []
		for j in 30:
			st.append(2 if j < old_top else 0)
			wk.append(20000 + j if j < old_top else -1)
		var dryb: Array = []
		for i2 in 54:
			dryb.append(STONE if i2 % 3 else LAVA)
		cfg.set_value("kampagne", "version", 1)
		cfg.set_value("kampagne", "sterne", st)
		cfg.set_value("kampagne", "gewonnen_am", wk)
		cfg.set_value("kampagne", "letzter_neuer", Daily.day_key(t) - 1)
		cfg.set_value("kampagne", "welt", Campaign.encode(dryb))
		cfg.set_value("kampagne", "welt_level", old_top)
		cfg.set_value("kampagne", "start", Campaign.encode(dryb))
		cfg.set_value("kampagne", "start_level", old_top + 1)
		cfg.set_value("kampagne", "start_seed", 2)
		cfg.save(path)
		var run := ConfigFile.new()
		run.set_value("lauf", "daten", {"v": 1, "level": old_top + 1, "wdt": -1, "cfg": "alt", "state": {}})
		run.save(path.get_basename() + "_lauf.cfg")
		var g := _daily_game(path, t, false)
		if not g.saved_run().is_empty():
			fails.append(["b12 Versuch bleibt", old_top])
		for day in 2:
			g.clock_override = t + day * Daily.DAY
			for n2 in range(5, 12):
				if not g.level_unlocked(n2) or g.level_stars(n2) > 0:
					continue
				if not g.start_level(n2):
					fails.append(["b12 start", old_top, n2])
					continue
				b12 += 1
				var gs2: GameState = g.state
				if not bool(gs2.reach9()["ok"]) or not gs2.lines().is_empty() or _cnt14(gs2, WATER) != _water_of(n2) or g.run_resumed:
					fails.append(["b12 brett", old_top, n2, str(g.level_board.get("how", "")), _cnt14(gs2, WATER)])
					continue
				var c2 := gs2.clone()
				var r2 := _follow14(c2, 6 * c2.par9, true, bad, "b12")
				if not bool(r2["won"]):
					fails.append(["b12 spiel", old_top, n2, r2])
		g.free()
		DirAccess.remove_absolute(path)
	print("  start14: %d Starts aus verspielten und extremen Welten, Tipp-Bot %d/%d (%d Geschenke), %d Starts aus Build-12-Ständen (%d ms)" % [starts, hint_won, hint_runs, gifts, b12, Time.get_ticks_msec() - t0])
	check(fails.is_empty() and starts >= 20 and hint_runs >= 5 and b12 >= 4, "start14: jeder Start erreichbar, mit dem Wasser seiner Mischung, und gewinnbar (Tipp-Bot %d/%d, %s)" % [hint_won, hint_runs, str(fails.slice(0, 3))])
	check(bad.is_empty(), "start14: die Zeile nennt dabei immer eine Handlung, die geht (%s)" % str(bad.slice(0, 3)))


## Dauerhafte Prüfung 2 – das Spiel: Nach sorglosem Spiel und nachdem ein Rohstoff verbraucht ist, gewinnt der
## Tipp-Bot noch, und die Zeile oben nennt an jedem Stand eine Handlung, die geht.
func test_play_invariant14() -> void:
	var t0 := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	var fails: Array = []
	var bad: Array = []
	var runs := 0
	var gifts := 0
	var plain := 0
	var hints := 0
	for item in [[2, 15, 0], [5, 15, 1], [6, 25, 1], [8, 25, 1], [9, 25, 1], [11, 40, 1], [12, 30, 1], [14, 30, 1], [20, 20, 1],
			[27, 15, 0], [35, 15, 0], [41, 40, 1], [42, 25, 1], [48, 15, 0], [55, 15, 0], [56, 15, 0], [59, 10, 0]]:
		var n := int(item[0])
		rng.seed = 9000 + n
		var gs := Campaign.new_state(n, Campaign.board(n, 1))
		_careless14(gs, rng, int(item[1]), int(item[2]) == 1, true)
		if gs.day_won:
			continue
		runs += 1
		# die Zeile an diesem Stand und an jedem Stand danach (ein Spieler, der ihr folgt, mit Netz)
		var line := gs.clone()
		var rl := _follow14(line, gs.steps9() + 8 * gs.par9, true, bad, "nach %d sorglosen" % int(item[1]))
		if not bool(rl["won"]) or int(rl["nogift"]) > 0 or int(rl["flat"]) > 0:
			fails.append(["zeile", n, rl])
		# der Tipp-Bot (mit dem Netz wie im Spiel) auf einer Auswahl (er rechnet je Zug lange)
		if not [6, 9, 41].has(n):
			continue
		hints += 1
		var rh := _hint14(gs, gs.steps9() + 8 * gs.par9, true)
		gifts += int(rh[2])
		if int(rh[2]) == 0:
			plain += 1
		if not bool(rh[0]):
			fails.append(["tipp", n, rh, gs.progress9(), gs.target9()])
	print("  spiel14: %d verspielte Stände (Zeile mit Netz), Tipp-Bot auf %d davon: alle gewonnen (%d ohne Geschenk, sonst %d Geschenke) (%d ms)" % [runs, hints, plain, gifts, Time.get_ticks_msec() - t0])
	check(fails.is_empty() and runs >= 16 and hints >= 3, "spiel14: nach sorglosem Spiel gewinnen Tipp-Bot und Zeile noch (%s)" % str(fails.slice(0, 3)))
	check(bad.is_empty(), "spiel14: an jedem Stand nennt die Zeile eine Handlung, die geht (%s)" % str(bad.slice(0, 3)))


## Dauerhafte Prüfung 3 – der gemeldete Fall beim Namen: „Ich habe schon vorausgespielt und konnte dann keine Ursuppe
## mehr erstellen, weil ich gar kein Wasser mehr hatte.“ Ein Level, das Ursuppe braucht (6–11), beginnt nie ohne Wasser
## und geht weiter, wenn mitten im Level kein Wasser mehr da ist.
func test_no_water_ursuppe14() -> void:
	var t0 := Time.get_ticks_msec()
	var t := lt(2026, 11, 12, 10)
	var path := "user://test_ursuppe14.cfg"
	var fails: Array = []
	var bad: Array = []
	var notes: Array = []
	for n in [6, 7, 8, 9, 10, 11]:
		# (a) gestern alles Wasser verbraucht: die Welt von Level n − 1 hat kein einziges Wasser-Feld
		var g := _daily_game(path, t, true)
		for i in n - 1:
			(g.camp["stars"] as Array)[i] = 2
			(g.camp["won_key"] as Array)[i] = Daily.day_key(t) - n + i
		g.camp["pos"] = n - 1
		g.camp["last_new_key"] = Daily.day_key(t) - 1
		var yesterday: Array = (Campaign.board(n - 1, 1)["kinds"] as Array).duplicate()
		for i2 in 54:
			if FieldData.water_family(int(yesterday[i2])):
				yesterday[i2] = E if i2 % 2 == 0 else STONE
		g.camp["world"] = Campaign.encode(yesterday)
		g.camp["world_level"] = n - 1
		if not g.start_level(n):
			fails.append(["start", n])
			g.free()
			continue
		var gs: GameState = g.state
		var water := _cnt14(gs, WATER)
		if water != _water_of(n) or water < 20 or not bool(gs.reach9()["ok"]):
			fails.append(["Welt ohne Wasser", n, water, str(g.level_board.get("how", ""))])
		if n == 6 or n == 9:
			var c := gs.clone()
			var rh := _hint14(c, 6 * c.par9, true)
			if not bool(rh[0]):
				fails.append(["Tipp nach Start", n, rh])
		# (b) mitten im Level ist das Wasser weg (wie auch immer): fortsetzen
		var res: Dictionary = g.state.play({"type": "twist", "axis": 1, "layer": 1, "turns": 1})
		g.busy = true
		g.finish_round(res)
		for fd in g.state.fields:
			if fd.kind == WATER:
				g.state._setk9(fd, E)
		g.state.rain = 0
		g.rescue_offer = {}
		g.dead_told = false
		g._save_run()
		var told: Array = []
		g.level_dead.connect(func(info): told.append(info))
		var cont: bool = g.start_level(n)
		var gs2: GameState = g.state
		var a := gs2.next_action()
		_line_ok14(gs2, a, bad, "ohne Wasser L%d" % n)
		var reach_ok := bool(gs2.reach9()["ok"])
		# entweder geht es in der Welt weiter (Regen füllt das Meer) oder die Hilfe kommt sofort und bringt Wasser
		if not cont or not g.run_resumed or _cnt14(gs2, WATER) != 0 or (not reach_ok and told.is_empty()):
			fails.append(["fortsetzen", n, cont, g.run_resumed, reach_ok, told.size()])
		# wer der Zeile folgt, kommt ohne Geschenk ans Ziel (Level 6–9 über den Kreislauf, 10/11 über die Reihen)
		var cl := gs2.clone()
		var rl := _follow14(cl, 150, false, bad, "ohne Wasser L%d" % n)
		notes.append("L%d Zeile %d" % [n, int(rl["steps"])])
		if not bool(rl["won"]) or int(rl["blind"]) > 0:
			fails.append(["Zeile ohne Wasser", n, rl, str(a.get("line", ""))])
		# und der Tipp-Bot mit dem Netz gewinnt auch (Level 8 und 9: er rechnet je Zug lange)
		if n == 9:
			var ch := gs2.clone()
			var rh2 := _hint14(ch, 150, true)
			notes.append("Tipp %d (%d Geschenke)" % [int(rh2[1]), int(rh2[2])])
			if not bool(rh2[0]):
				fails.append(["Tipp ohne Wasser", n, rh2])
		g.free()
		DirAccess.remove_absolute(path)
	print("  ursuppe14: %s (%d ms)" % [str(notes), Time.get_ticks_msec() - t0])
	check(fails.is_empty(), "ursuppe14: Level 6–11 beginnen nie ohne Wasser (auch nach einer Welt ganz ohne Wasser) und gehen ohne Wasser mitten im Level weiter (%s)" % str(fails.slice(0, 3)))
	check(bad.is_empty(), "ursuppe14: die Zeile nennt dabei immer eine Handlung, die geht (%s)" % str(bad.slice(0, 3)))
	# Level 9 genau wie gemeldet: zwei Regen vorher verbraucht, dann Ursuppe nötig – die Zeile nennt das Rezept
	var g9 := Campaign.new_state(9, Campaign.board(9, 1))
	var poured := 0
	var guard := 0
	while poured < 2 and guard < 12:
		guard += 1
		if g9.rain > 0:
			for f in g9.fields:
				if f.kind == STONE and g9.rain_ok9(f):
					g9.play({"type": "rain", "field": f.id})
					poured += 1
					break
		else:
			tw(g9, GameState.MOVES[guard % 27])
	var seen_recipe := false
	var waits := 0
	for i3 in 30:
		if g9.day_won:
			break
		var a9 := g9.next_action()
		if str(a9["text"]).begins_with("Wasser neben"):
			seen_recipe = true
		if str(a9["text"]).begins_with("Regen in") or str(a9["text"]) == "Gleich kommt Regen":
			waits += 1
		var mv: Dictionary = a9.get("move", {})
		if str(a9.get("tool", "")) == "rain":
			g9.play({"type": "rain", "field": int(a9["field"])})
		elif not mv.is_empty():
			tw(g9, [int(mv["axis"]), int(mv["layer"]), int(mv["turns"])])
		else:
			break
	check(g9.day_won and waits <= 2, "ursuppe14: Level 9 mit verbrauchtem Regen – gewonnen in %d Schritten, „Regen in …“ nur %d× (Rezept-Zeile gesehen: %s)" % [g9.steps9(), waits, str(seen_recipe)])


## B: Texte der Zeile (kurz, wahr, kein Spoiler).
func test_texts14() -> void:
	# Level 32: die Jagd nennt die Saurier, nicht „Tiere“
	var g32 := camp_state(32)
	g32.pack_warn9 = {3: true}
	g32.fields[3].kind = FieldData.SAURO
	check(g32._act_also9("pack") == "Rettet auch die Saurier" and g32._act_also9("bolt") == "Rettet auch den Wald", "texte14: „%s“" % g32._act_also9("pack"))
	# zweite Zeile im Plural: „3 Wälder → Saurier“
	var g28 := Campaign.new_state(29, Campaign.board(29, 1))
	var hint := g28._act_hint9({"type": "make", "kind": FieldData.REX, "kinds": [FieldData.REX], "target": 3})
	check(hint == "3 Saurier → Raubsaurier", "texte14: Rezept-Zeile im Plural (%s)" % hint)
	var g12 := Campaign.new_state(12, Campaign.board(12, 1))
	check(str(g12._act_hint9(g12._act_goal9())) == "3 Algen → Qualle", "texte14: „%s“" % str(g12._act_hint9(g12._act_goal9())))
	# Level 60, Ruhe-Phase: „Halte das Gleichgewicht“, kein Rezept, eine Scheibe, nach der die Runde zählt
	var g60 := Campaign.new_state(60, Campaign.board(60, 1))
	var held := false
	var bad: Array = []
	for i in 60:
		if g60.day_won:
			break
		var a := g60.next_action()
		if str(a.get("hint", "")).contains("→ Erde"):
			bad.append(a)
		if str(a["type"]) == "hold":
			# Ruhe-Phase: der Zeile folgen
			held = true
			var mv: Dictionary = a.get("move", {})
			if str(a["text"]) != "Halte das Gleichgewicht" or not str(a["hint"]).begins_with("Noch ") or mv.is_empty():
				bad.append(a)
				break
			tw(g60, [int(mv["axis"]), int(mv["layer"]), int(mv["turns"])])
		else:
			# bis dahin spielt der Tipp (mit dem Netz, wenn es hakt)
			var ha := g60.best_action()
			g60.play(ha)
			if not g60.day_won and g60.stuck9() != "" and not g60.gift_plan9().is_empty():
				g60.play({"type": "gift"})
	check(held and bad.is_empty() and g60.day_won, "texte14: Level 60 – in der Ruhe-Phase „Halte das Gleichgewicht“ mit Scheibe, gewonnen (%s, %s)" % [str(held), str(bad.slice(0, 1))])
	# Coach-Sätze, die dem Level widersprachen
	check(str(Campaign.config(53)["coach"]) == "Wald gibt Arbeit." and str(Campaign.config(58)["coach"]) == "Fabriken ans Wasser."
		and str(Campaign.config(42)["coach"]) == "Mammut braucht Eis.", "texte14: Coach-Sätze von Level 42, 53, 58 passen zum Level")
	# Die neue Zeile für „Regen kommt“: nur ohne Regen, mit Scheibe
	var words_ok := true
	for s in ["Regen in 3 Drehungen", "Gleich kommt Regen", "Hilfe: hier tippen", "Dreh die leuchtende Scheibe", "Halte das Gleichgewicht",
			"Zu wenig Lava. Ich helfe.", "Keine Reihe möglich. Ich helfe.", "Über Nacht: Ursuppe → Wasser", "Geschenk: +3 Lava", "Hält durch!",
			"Regen füllt das Meer."]:
		if str(s).split(" ", false).size() > 6:
			words_ok = false
	check(words_ok, "texte14: alle neuen Texte höchstens 6 Wörter")
