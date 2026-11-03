extends SceneTree
## Regeltests ohne Grafik:
##   godot --headless --import
##   godot --headless --script res://tests/test_rules.gd

var failures := 0
var checks := 0


func _init() -> void:
	test_setup()
	test_geometry()
	test_growth()
	test_war_and_trade()
	test_meteor_and_storm()
	test_fire_and_lake()
	test_volcano()
	test_preview_matches()
	test_long_run()
	print("")
	print("%d Prüfungen, %d Fehler" % [checks, failures])
	quit(1 if failures > 0 else 0)


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


## Leere Welt (nur Wiesen) für gezielte Tests.
func empty_state() -> GameState:
	var gs := new_state()
	for f in gs.fields:
		f.terrain = "meadow"
		f.nation = -1
		f.building = ""
		f.people = 0
		f.animals = 0
		f.burning = false
		f.volcano = 0
	gs.hazards.clear()
	return gs


func at(gs: GameState, p: Vector3i, n: Vector3i) -> FieldData:
	return gs.field_at(p, n)


func settle(f: FieldData, nation: int, building: String, people: int) -> void:
	f.nation = nation
	f.building = building
	f.people = people


func test_setup() -> void:
	var gs := new_state()
	check(gs.fields.size() == 54, "54 Felder")
	check(gs.war_pairs().is_empty(), "kein Krieg am Start")
	for nation in Balance.NATION_COUNT:
		check(gs.nation_people(nation) > 0, "Volk %d lebt" % nation)
	check(gs.total_animals() > 0, "es gibt Tiere")
	check(gs.hazards.is_empty(), "keine Gefahren am Start")


func test_geometry() -> void:
	var gs := new_state()
	var before := []
	for f in gs.fields:
		before.append([f.p, f.n])
	for i in 4:
		gs.apply_rotation(1, 0, 1)
	var same := true
	for f in gs.fields:
		if before[f.id][0] != f.p or before[f.id][1] != f.n:
			same = false
	check(same, "4 × 90° = keine Änderung (Mittelscheibe)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 300:
		gs.apply_rotation(rng.randi_range(0, 2), rng.randi_range(-1, 1), [1, -1, 2][rng.randi_range(0, 2)])
	var keys := {}
	var ok := true
	for f in gs.fields:
		keys[GameState.pos_key(f.p, f.n)] = true
		var a := GameState.axis_of(f.n)
		if f.p[a] != f.n[a]:
			ok = false
		if gs.neighbors(f).size() != 4:
			ok = false
	check(keys.size() == 54, "jeder Platz genau einmal belegt")
	check(ok, "Felder bleiben auf der Oberfläche und haben 4 Nachbarn")
	# Mittelscheibe bewegt auch die Mitte (wie beim echten Würfel)
	var gs2 := new_state()
	var c := at(gs2, Vector3i(0, 0, 1), Vector3i(0, 0, 1))
	gs2.apply_rotation(1, 0, 1)
	check(c.n == Vector3i(1, 0, 0), "Mitte wandert mit der Mittelscheibe")


func test_growth() -> void:
	var gs := empty_state()
	var v := at(gs, Vector3i(0, 1, 0), Vector3i(0, 1, 0))
	settle(v, 0, "village", 3)
	gs.end_round()
	check(v.people == 4, "Dorf mit 4 Wiesen daneben wächst (%d)" % v.people)
	# Hunger: alle Nachbarn sind Berge
	var gs2 := empty_state()
	var v2 := at(gs2, Vector3i(0, 1, 0), Vector3i(0, 1, 0))
	settle(v2, 0, "village", 3)
	for g in gs2.neighbors(v2):
		g.terrain = "mountain"
	gs2.end_round()
	check(v2.people == 2, "Dorf ohne Nahrung schrumpft (%d)" % v2.people)
	# Ausbreiten
	var gs3 := empty_state()
	var v3 := at(gs3, Vector3i(0, 1, 0), Vector3i(0, 1, 0))
	settle(v3, 0, "village", Balance.EXPAND_AT)
	gs3.end_round()
	var new_villages := 0
	for g in gs3.neighbors(v3):
		if g.building == "village":
			new_villages += 1
	check(new_villages == 1, "volles Dorf gründet ein neues")


func test_war_and_trade() -> void:
	var gs := empty_state()
	var a := at(gs, Vector3i(0, 1, 0), Vector3i(0, 1, 0))
	var b := at(gs, Vector3i(1, 1, 0), Vector3i(0, 1, 0))
	settle(a, 0, "church", 4)
	settle(b, 1, "church", 4)
	check(gs.war_pairs().has(GameState.pair_key(0, 1)), "Kirchen nebeneinander: Krieg")
	gs.end_round()
	check(a.people == 3 and b.people == 3, "Krieg kostet beide Seiten (%d, %d)" % [a.people, b.people])
	# Handel
	var gs2 := empty_state()
	var m1 := at(gs2, Vector3i(0, 1, 0), Vector3i(0, 1, 0))
	var m2 := at(gs2, Vector3i(1, 1, 0), Vector3i(0, 1, 0))
	settle(m1, 0, "market", 3)
	settle(m2, 1, "market", 3)
	check(gs2.trade_pairs().has(GameState.pair_key(0, 1)), "Märkte nebeneinander: Handel")
	gs2.end_round()
	check(m1.people == 4 and m2.people == 4, "Handel lässt beide wachsen (%d, %d)" % [m1.people, m2.people])
	# Krieg verhindert Handel
	var c1 := at(gs2, Vector3i(-1, 1, 0), Vector3i(0, 1, 0))
	var c2 := at(gs2, Vector3i(-1, 1, 1), Vector3i(0, 1, 0))
	settle(c1, 0, "church", 3)
	settle(c2, 1, "church", 3)
	check(gs2.trade_pairs().is_empty(), "im Krieg kein Handel")
	gs2.end_round()
	check(m1.people == 3 and m2.people == 3, "Märkte im Krieg verlieren statt zu wachsen (%d, %d)" % [m1.people, m2.people])


func test_meteor_and_storm() -> void:
	var gs := empty_state()
	var v := at(gs, Vector3i(0, 1, 0), Vector3i(0, 1, 0))
	settle(v, 0, "village", 5)
	gs.hazards.append({"type": "meteor", "p": v.p, "n": v.n, "timer": 2})
	gs.end_round()
	check(v.people > 0, "Meteor schlägt noch nicht ein")
	# wegdrehen: die Ebene y=1 drehen, dann landet ein anderes Feld am Platz
	gs.apply_rotation(1, 1, 1)
	var place_field := gs.field_at(Vector3i(0, 1, 0), Vector3i(0, 1, 0))
	check(place_field == v, "Mitte der oberen Seite bleibt bei Drehung um die y-Achse")
	gs.apply_rotation(1, 1, -1)
	gs.apply_rotation(0, 0, 1)
	var hit := gs.field_at(Vector3i(0, 1, 0), Vector3i(0, 1, 0))
	check(hit != v, "Dorf ist weggedreht")
	var ev := gs.end_round()
	check(hit.terrain == "crater", "Meteor macht einen Krater")
	check(v.people > 0, "weggedrehtes Dorf überlebt")
	var types := []
	for e in ev:
		types.append(e["type"])
	check(types.has("meteor"), "Ereignis Meteor")
	# Gewitter halbiert
	var gs2 := empty_state()
	var w := at(gs2, Vector3i(0, 1, 0), Vector3i(0, 1, 0))
	settle(w, 0, "village", 6)
	w.terrain = "forest"
	gs2.hazards.append({"type": "storm", "p": w.p, "n": w.n, "timer": 1})
	gs2.end_round()
	check(w.people <= 4, "Gewitter halbiert (%d)" % w.people)
	check(w.burning, "Blitz im Wald: Feuer")


func test_fire_and_lake() -> void:
	var gs := empty_state()
	var f := at(gs, Vector3i(0, 1, 0), Vector3i(0, 1, 0))
	f.terrain = "forest"
	f.burning = true
	var nb: Array = gs.neighbors(f)
	(nb[0] as FieldData).terrain = "forest"
	gs.end_round()
	check(not f.burning and f.terrain == "meadow", "Feuer brennt aus")
	check((nb[0] as FieldData).burning, "Feuer springt auf Nachbarwald")
	var gs2 := empty_state()
	var g := at(gs2, Vector3i(0, 1, 0), Vector3i(0, 1, 0))
	g.terrain = "forest"
	g.burning = true
	(gs2.neighbors(g)[0] as FieldData).terrain = "lake"
	gs2.end_round()
	check(not g.burning and g.terrain == "forest", "See daneben löscht")


func test_volcano() -> void:
	var gs := empty_state()
	var m := at(gs, Vector3i(0, 1, 0), Vector3i(0, 1, 0))
	m.terrain = "mountain"
	m.volcano = 1
	var nb: Array = gs.neighbors(m)
	settle(nb[0], 0, "village", 6)
	gs.end_round()
	check(m.volcano == 0, "Vulkan ist ausgebrochen")
	check((nb[0] as FieldData).people <= 4, "Nachbarn verlieren die Hälfte")


func test_preview_matches() -> void:
	var gs := new_state(777)
	gs.hazards.append({"type": "meteor", "p": Vector3i(0, 1, 0), "n": Vector3i(0, 1, 0), "timer": 1})
	var sim := gs.clone()
	sim.apply_rotation(2, 1, 1)
	sim.end_round()
	gs.apply_rotation(2, 1, 1)
	gs.end_round()
	var same := true
	for f in gs.fields:
		var g: FieldData = sim.fields[f.id]
		if f.people != g.people or f.animals != g.animals or f.terrain != g.terrain or f.p != g.p:
			same = false
	check(same, "Vorschau = echte Runde")


func test_long_run() -> void:
	for s in [1, 2, 3]:
		var gs := new_state(s)
		var rng := RandomNumberGenerator.new()
		rng.seed = s * 99
		var rounds := 0
		for t in 120:
			gs.apply_rotation(rng.randi_range(0, 2), rng.randi_range(-1, 1), [1, -1][rng.randi_range(0, 1)])
			gs.end_round()
			gs.spawn_hazards()
			rounds += 1
			if gs.is_over():
				break
		var ok := true
		for f in gs.fields:
			if f.people < 0 or f.animals < 0 or f.people > Balance.MAX_PEOPLE:
				ok = false
			if f.building != "" and f.nation < 0:
				ok = false
		check(ok, "Werte bleiben gültig (Seed %d)" % s)
		print("Zufallsspiel Seed %d: %d Runden, %d Menschen, %d Tiere, Spitze %d" % [s, rounds, gs.total_people(), gs.total_animals(), gs.peak_people])
