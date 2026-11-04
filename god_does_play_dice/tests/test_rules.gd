extends SceneTree
## Regeltests ohne Grafik:
##   godot --headless --import
##   godot --headless --script res://tests/test_rules.gd

var failures := 0
var checks := 0


var _saved := {}


func _init() -> void:
	test_setup()
	calm()
	test_geometry()
	test_merge()
	test_only_new_lines()
	test_back_and_forth()
	test_cascade()
	test_regrow_and_pollution()
	restore()
	test_income_and_balance()
	test_disasters()
	test_meteor()
	test_preview_matches()
	test_modes()
	test_bot()
	print("")
	print("%d Prüfungen, %d Fehler" % [checks, failures])
	quit(1 if failures > 0 else 0)


## Für die reinen Regeltests: Gleichgewicht so weit, dass keine Katastrophe dazwischenfunkt.
func calm() -> void:
	_saved = {"nmin": Balance.NATURE_MIN, "nmax": Balance.NATURE_MAX, "cmax": Balance.CIVILISATION_MAX}
	Balance.NATURE_MIN = 0.0
	Balance.NATURE_MAX = 1.0
	Balance.CIVILISATION_MAX = 1.0


func restore() -> void:
	Balance.NATURE_MIN = _saved["nmin"]
	Balance.NATURE_MAX = _saved["nmax"]
	Balance.CIVILISATION_MAX = _saved["cmax"]


func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		push_error("FEHLER: " + what)
		print("FEHLER: " + what)


func new_state(seed_value := 12345) -> GameState:
	var gs := GameState.new()
	gs.setup(seed_value)
	return gs


## Alles leere Erde, damit nichts von selbst passiert.
func empty_state() -> GameState:
	var gs := new_state()
	for f in gs.fields:
		f.stage = 0
		f.fresh = 0
	return gs


func top(gs: GameState, x: int, z: int) -> FieldData:
	return gs.field_at(Vector3i(x, 1, z), Vector3i(0, 1, 0))


func test_setup() -> void:
	var gs := new_state()
	check(gs.fields.size() == 54, "54 Felder")
	check(gs.lines().is_empty(), "am Start keine fertigen Dreierreihen")
	var only := true
	for f in gs.fields:
		if f.stage > 1:
			only = false
	check(only, "Start nur mit Erde und Wiesen")
	check(gs.in_balance(), "Start ist im Gleichgewicht")


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
	var c := gs2.field_at(Vector3i(0, 1, 0), Vector3i(0, 1, 0))
	gs2.apply_rotation(0, 0, 1)
	check(c.n != Vector3i(0, 1, 0), "Mitte dreht mit der Mittelscheibe mit")


func test_merge() -> void:
	var gs := empty_state()
	var a := top(gs, 1, -1)
	var b := top(gs, 1, 0)
	var c := top(gs, 1, 1)
	a.stage = 1
	b.stage = 1
	check(gs.lines().is_empty(), "zwei reichen nicht")
	c.stage = 2
	check(gs.lines().is_empty(), "verschiedene Stufen verschmelzen nicht")
	c.stage = 1
	check(gs.lines().size() == 1, "drei Wiesen in einer Reihe")
	check(gs.moved_lines().is_empty(), "ohne Drehung verschmilzt nichts")
	var waited := gs.clone()
	waited.end_round()
	check((waited.fields[b.id] as FieldData).stage == 1, "Warten lässt die Reihe stehen")
	gs.moved[c.id] = true
	var r := gs.end_round()
	check(b.stage == 2, "Mitte wird Wald (%d)" % b.stage)
	check(a.stage == 0 and c.stage == 0, "Außen fällt zurück (Wiese → Erde)")
	var gs4 := empty_state()
	for x in [-1, 0, 1]:
		top(gs4, x, 1).stage = 3
	gs4.moved = {top(gs4, 1, 1).id: true}
	gs4.resolve_merges([])
	check(top(gs4, 0, 1).stage == 4 and top(gs4, -1, 1).stage == 2, "3 große Wälder → Hütte und zwei kleine Wälder")
	check(int(r["gain"]) == int(Balance.MERGE_POINTS[1]), "Wert fürs Verschmelzen (%d)" % int(r["gain"]))
	# Die ganze Leiter hinauf
	var gs2 := empty_state()
	var names := []
	for s in range(1, Balance.MAX_STAGE):
		top(gs2, -1, -1).stage = s
		top(gs2, -1, 0).stage = s
		top(gs2, -1, 1).stage = s
		gs2.moved = {top(gs2, -1, 1).id: true}
		gs2.resolve_merges([])
		names.append(top(gs2, -1, 0).stage)
	check(names == [2, 3, 4, 5, 6, 7, 8, 9], "Leiter Wiese … Metropole (%s)" % str(names))
	# Nebeneinander allein bringt nichts
	var gs3 := empty_state()
	top(gs3, 1, 0).stage = 3
	top(gs3, 1, 1).stage = 3
	check(int(gs3.end_round()["gain"]) == 0, "zwei Dörfer nebeneinander bringen nichts")


func test_only_new_lines() -> void:
	# Eine fertige Reihe, die nur als Ganzes mitgedreht wird, verschmilzt nicht
	var gs := empty_state()
	for x in [-1, 0, 1]:
		top(gs, x, 1).stage = 1
	gs.apply_rotation(2, 1, 1)
	check(gs.moved_lines().is_empty(), "mitgedrehte fertige Reihe zählt nicht")
	var r := gs.end_round()
	check(int(r["gain"]) == 0, "keine Punkte für alte Reihe")
	# Eine neu verbundene Reihe verschmilzt
	var gs2 := empty_state()
	top(gs2, -1, 1).stage = 1
	top(gs2, 0, 1).stage = 1
	var third := gs2.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1))
	third.stage = 1
	gs2.apply_rotation(0, 1, 1)
	var now := top(gs2, 1, 1)
	check(now == third, "drittes Feld rückt in die Reihe")
	check(gs2.moved_lines().size() == 1, "neu verbundene Reihe zählt")


func test_back_and_forth() -> void:
	# Reihe wegdrehen und zurückdrehen bringt nichts
	var gs := empty_state()
	for x in [-1, 0, 1]:
		top(gs, x, 1).stage = 1
	gs.end_round()
	gs.apply_rotation(0, 1, 1)
	gs.end_round()
	gs.apply_rotation(0, 1, -1)
	check(gs.lines().size() >= 1, "Reihe steht wieder da")
	check(gs.moved_lines().is_empty(), "hin und her zählt nicht")
	var r := gs.end_round()
	check(int(r["gain"]) == 0, "keine Punkte fürs Hin- und Herdrehen")


func test_cascade() -> void:
	# Spalte x=1 oben: Wald, Wiese, Wald; dazu zwei Wälder neben der Mitte, die eine Kombo auslösen
	var gs := empty_state()
	top(gs, 1, -1).stage = 1
	top(gs, 1, 0).stage = 1
	top(gs, 1, 1).stage = 1
	top(gs, 0, 0).stage = 2
	top(gs, -1, 0).stage = 2
	gs.moved = {top(gs, 1, 1).id: true}
	var ev: Array = []
	var pts := gs.resolve_merges(ev)
	check(ev.size() == 2, "Kettenreaktion: zwei Verschmelzungen (%d)" % ev.size())
	if ev.size() == 2:
		check(int(ev[1]["combo"]) == 2, "zweite zählt als Kombo")
	check(pts == int(Balance.MERGE_POINTS[1]) + int(Balance.MERGE_POINTS[2]) * 2, "Kombo verdoppelt (%d)" % pts)


func test_regrow_and_pollution() -> void:
	var gs := empty_state()
	top(gs, 0, 0).stage = 1
	top(gs, 1, 1).stage = 2
	var e := top(gs, 1, 0)
	gs.end_round()
	check(e.stage == 1, "Erde mit 2 Natur-Nachbarn wird Wiese")
	var gs2 := empty_state()
	var fac := top(gs2, 1, 1)
	fac.stage = Balance.POLLUTION_FROM
	var nat := top(gs2, 1, 0)
	nat.stage = 2
	gs2.end_round()
	check(nat.stage == 0, "Fabrik zerstört Natur daneben")


func test_income_and_balance() -> void:
	var gs := empty_state()
	top(gs, 1, 1).stage = 8
	top(gs, -1, -1).stage = 9
	check(gs.threat() == "flood", "nur Erde: zu wenig Natur, Überschwemmung droht")
	for i in Balance.LIVES:
		check(not gs.is_over(), "Welt lebt noch vor Katastrophe %d" % (i + 1))
		gs.end_round()
	check(gs.is_over() and gs.died(), "nach %d Katastrophen stirbt die Welt" % Balance.LIVES)


func _disaster_of(r: Dictionary) -> Dictionary:
	for e in r["events"]:
		if str(e["type"]) == "disaster":
			return e
	return {}


func test_disasters() -> void:
	# Erdbeben: zu viel Zivilisation, die größte Siedlung stürzt ein
	var gs := empty_state()
	for f in gs.fields:
		f.stage = 5 if f.id < 24 else 1
	var big := top(gs, 0, 0)
	big.stage = 7
	check(gs.threat() == "quake", "zu viel Zivilisation: Erdbeben droht")
	var r := gs.end_round()
	var e := _disaster_of(r)
	check(str(e.get("kind", "")) == "quake" and int(e["field"]) == big.id, "Erdbeben trifft die größte Siedlung")
	check(big.stage == 7 - Balance.QUAKE_DROP, "größte Siedlung fällt %d Stufen" % Balance.QUAKE_DROP)
	check(gs.lives == Balance.LIVES - 1, "Katastrophe kostet ein Leben")
	# Waldbrand: zu viel Natur, der dichteste Wald brennt
	var gf := empty_state()
	for f in gf.fields:
		f.stage = 1
	var forest := top(gf, 0, 0)
	forest.stage = 3
	check(gf.threat() == "fire", "zu viel Natur: Waldbrand droht")
	var rf := gf.end_round()
	var ef := _disaster_of(rf)
	check(str(ef.get("kind", "")) == "fire" and (ef["hit"] as Array).size() == 5, "Waldbrand: Wald und 4 Nachbarn brennen")
	check(forest.stage == 0 and gf.count(0) == 5, "verbrannt ist Erde")
	gf.end_round()
	check(forest.stage == 0, "Brandfläche wächst nicht sofort nach")
	# Überschwemmung: zu wenig Natur, die kleinsten Siedlungen werden weggespült
	var gw := empty_state()
	top(gw, 1, 1).stage = 4
	top(gw, -1, -1).stage = 4
	top(gw, -1, 1).stage = 4
	top(gw, 1, -1).stage = 5
	check(gw.threat() == "flood", "zu wenig Natur: Überschwemmung droht")
	var rw := gw.end_round()
	check(str(_disaster_of(rw).get("kind", "")) == "flood", "Überschwemmung kommt")
	check(gw.count(4) == 0 and top(gw, 1, -1).stage == 5, "die %d kleinsten Siedlungen sind weg" % Balance.FLOOD_FIELDS)
	# Im Gleichgewicht passiert nichts, neues Zeitalter gibt ein Leben zurück
	var ga := new_state(5)
	ga.lives = 1
	ga.turn = Balance.AGE_LENGTH
	var ra := ga.end_round()
	check(_disaster_of(ra).is_empty(), "im Gleichgewicht keine Katastrophe")
	check(ga.lives == 2, "neues Zeitalter: ein Leben zurück")


func test_meteor() -> void:
	var gs := new_state()
	var f := top(gs, 0, 0)
	check(gs.meteors == Balance.METEOR_START and gs.can_meteor() == "", "am Anfang %d Meteorit" % Balance.METEOR_START)
	var ids := gs.use_meteor(f)
	check(ids.size() == 5, "Feld und 4 Nachbarn getroffen")
	check(gs.meteors == Balance.METEOR_START - 1 and gs.can_meteor() != "", "Meteorit verbraucht")
	var all_empty := true
	for i in ids:
		if (gs.fields[int(i)] as FieldData).stage != 0:
			all_empty = false
	check(all_empty, "alles wird Erde")
	gs.end_round()
	check(f.stage == 0, "frischer Krater wächst nicht sofort zu")
	var gm := new_state(3)
	gm.meteors = 0
	var waited := 0
	while gm.meteors == 0 and waited < 50:
		check(gm.meteor_in() > 0, "Meteorit lädt noch")
		gm.end_round()
		waited += 1
	check(waited == Balance.METEOR_EVERY, "nach %d Runden kommt ein Meteorit (%d)" % [Balance.METEOR_EVERY, waited])


func test_preview_matches() -> void:
	var gs := new_state(777)
	var sim := gs.clone()
	sim.apply_rotation(2, 1, 1)
	var r1 := sim.end_round()
	gs.apply_rotation(2, 1, 1)
	var r2 := gs.end_round()
	var same := int(r1["gain"]) == int(r2["gain"])
	for f in gs.fields:
		var g: FieldData = sim.fields[f.id]
		if f.stage != g.stage or f.p != g.p:
			same = false
	check(same, "Vorschau = echte Runde")


## Ein einfacher Bot: wählt die beste Drehung (ein Zug voraus), setzt den Meteoriten, wenn das
## Gleichgewicht kippt. passive = immer nur warten. Zeigt, ob das Spiel lange spielbar ist.
func run_bot(s: int, passive: bool, max_rounds: int = 150) -> Dictionary:
	var gs := new_state(s)
	var meteors := 0
	for t in max_rounds:
		if not passive and gs.meteors > 0:
			var want := ""
			if gs.civilisation_share() > gs.civilisation_max() - 0.03 or gs.nature_share() < gs.nature_min() + 0.03:
				want = "civ"
			elif gs.nature_share() > gs.nature_max() - 0.03:
				want = "nature"
			if want != "":
				var best_f: FieldData = null
				var best_c := -1
				for f in gs.fields:
					var c := 0
					for g in [f] + gs.neighbors(f):
						var h: FieldData = g
						if (want == "civ" and h.is_civilisation()) or (want == "nature" and h.is_nature()):
							c += 1
					if c > best_c:
						best_c = c
						best_f = f
				gs.use_meteor(best_f)
				meteors += 1
		var best := [0, 0, 0]
		if not passive:
			var best_score := -INF
			for axis in 3:
				for layer in [-1, 0, 1]:
					for turns in [0, 1, -1, 2]:
						if turns == 0 and (axis > 0 or layer != -1):
							continue
						var sim := gs.clone()
						if turns != 0:
							sim.apply_rotation(axis, layer, turns)
						var r := sim.end_round()
						var score: float = int(r["gain"])
						if sim.lives < gs.lives:
							score -= 60.0
						if not sim.in_balance():
							score -= 10.0
						if sim.is_over():
							score -= 10000.0
						if score > best_score:
							best_score = score
							best = [axis, layer, turns]
		if int(best[2]) != 0:
			gs.apply_rotation(int(best[0]), int(best[1]), int(best[2]))
		gs.end_round()
		if gs.is_over():
			break
	var counts := []
	for st in range(0, Balance.MAX_STAGE + 1):
		counts.append(gs.count(st))
	return {"rounds": gs.turn - 1, "age": gs.age(), "best": gs.best_stage, "meteors": meteors, "disasters": gs.disasters,
		"nature": gs.nature_share(), "civ": gs.civilisation_share(), "counts": counts, "dead": gs.died()}


func test_bot() -> void:
	var saved := Balance.NATURE_MAX
	for nmax in [0.70, 0.75, 0.80]:
		Balance.NATURE_MAX = nmax
		print("--- Natur höchstens %d%% ---" % int(round(nmax * 100.0)))
		for s in [11, 22, 33]:
			var p := run_bot(s, true)
			print("  Nur warten, Seed %d: %d Runden, Katastrophen %d, %s" % [s, int(p["rounds"]), int(p["disasters"]), "tot" if bool(p["dead"]) else "lebt"])
		for s in [11, 22, 33]:
			var b := run_bot(s, false)
			print("  Bot Seed %d: %d Runden (Zeitalter %d), höchste Stufe %d, Meteoriten %d, Katastrophen %d, Natur %.0f%%, Zivilisation %.0f%%, Stufen %s" % [
				s, int(b["rounds"]), int(b["age"]), int(b["best"]), int(b["meteors"]), int(b["disasters"]),
				float(b["nature"]) * 100.0, float(b["civ"]) * 100.0, str(b["counts"])])
	Balance.NATURE_MAX = saved
	var passive := run_bot(11, true)
	check(bool(passive["dead"]) and int(passive["rounds"]) < 80, "Nur warten verliert irgendwann")


func test_modes() -> void:
	var gs := GameState.new()
	gs.setup(5, true)
	check(gs.age() == 1, "Endlos startet in Zeitalter 1")
	var nmin := gs.nature_min()
	gs.turn = Balance.AGE_LENGTH + 1
	check(gs.age() == 2, "nach %d Runden Zeitalter 2" % Balance.AGE_LENGTH)
	check(gs.nature_min() > nmin and gs.nature_max() < Balance.NATURE_MAX and gs.civilisation_max() < Balance.CIVILISATION_MAX, "Gleichgewicht wird enger")
	gs.turn = 999
	check(not gs.finished(), "Endlos endet nicht nach Runden")
	var ch := GameState.new()
	ch.setup(5, false)
	ch.turn = Balance.MAX_ROUNDS + 1
	check(ch.finished(), "40-Runden-Modus endet")
	check(ch.age() == 1, "40 Runden ohne Zeitalter")
