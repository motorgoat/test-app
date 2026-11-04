extends SceneTree
## Regeltests ohne Grafik:
##   godot --headless --import
##   godot --headless --script res://tests/test_rules.gd

var failures := 0
var checks := 0


func _init() -> void:
	test_setup()
	test_geometry()
	test_merge()
	test_cascade()
	test_regrow_and_pollution()
	test_income_and_balance()
	test_meteor()
	test_preview_matches()
	test_bot()
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
	var r := gs.end_round()
	check(b.stage == 2, "Mitte wird Wald (%d)" % b.stage)
	check(a.stage == 0 and c.stage == 0, "Außen wird leere Erde")
	check(int(r["gain"]) == int(Balance.MERGE_POINTS[1]), "Glaube fürs Verschmelzen (%d)" % int(r["gain"]))
	# Die ganze Leiter hinauf
	var gs2 := empty_state()
	var names := []
	for s in range(1, Balance.MAX_STAGE):
		top(gs2, -1, -1).stage = s
		top(gs2, -1, 0).stage = s
		top(gs2, -1, 1).stage = s
		gs2.resolve_merges([])
		names.append(top(gs2, -1, 0).stage)
	check(names == [2, 3, 4, 5], "Leiter Wiese → Wald → Dorf → Stadt → Fabrik (%s)" % str(names))
	# Nebeneinander allein bringt nichts
	var gs3 := empty_state()
	top(gs3, 1, 0).stage = 3
	top(gs3, 1, 1).stage = 3
	check(int(gs3.end_round()["gain"]) == 0, "zwei Dörfer nebeneinander bringen nichts")


func test_cascade() -> void:
	# Spalte x=1 oben: Wald, Wiese, Wald; dazu zwei Wälder neben der Mitte, die eine Kombo auslösen
	var gs := empty_state()
	top(gs, 1, -1).stage = 1
	top(gs, 1, 0).stage = 1
	top(gs, 1, 1).stage = 1
	top(gs, 0, 0).stage = 2
	top(gs, -1, 0).stage = 2
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
	fac.stage = 5
	var nat := top(gs2, 1, 0)
	nat.stage = 2
	gs2.end_round()
	check(nat.stage == 0, "Fabrik zerstört Natur daneben")


func test_income_and_balance() -> void:
	var gs := empty_state()
	top(gs, 1, 1).stage = 4
	top(gs, -1, -1).stage = 5
	check(gs.income() == int(Balance.INCOME[4]) + int(Balance.INCOME[5]), "Stadt und Fabrik bringen Glauben")
	check(not gs.in_balance(), "nur Erde: zu wenig Natur")
	for i in Balance.LOSE_AFTER:
		gs.end_round()
	check(gs.is_over(), "zu lange aus dem Gleichgewicht: Ende")


func test_meteor() -> void:
	var gs := new_state()
	var f := top(gs, 0, 0)
	check(gs.can_meteor() != "", "ohne Glauben kein Meteorit")
	gs.faith = 100
	var cost := gs.meteor_cost()
	var ids := gs.use_meteor(f)
	check(ids.size() == 5, "Feld und 4 Nachbarn getroffen")
	check(gs.faith == 100 - cost, "kostet Glauben")
	var all_empty := true
	for i in ids:
		if (gs.fields[int(i)] as FieldData).stage != 0:
			all_empty = false
	check(all_empty, "alles wird Erde")
	check(gs.meteor_cost() > cost, "nächster Meteorit ist teurer")
	gs.end_round()
	check(f.stage == 0, "frischer Krater wächst nicht sofort zu")


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


## Ein einfacher Bot: wählt die beste Drehung, setzt den Meteoriten auf die dichteste Zivilisation,
## wenn das Gleichgewicht kippt. Zeigt, ob das Spiel lange spielbar ist.
func test_bot() -> void:
	for s in [11, 22, 33]:
		var gs := new_state(s)
		var rounds := 0
		var meteors := 0
		for t in 150:
			if gs.faith >= gs.meteor_cost() and (gs.civilisation_share() > Balance.CIVILISATION_MAX - 0.04 or gs.nature_share() < Balance.NATURE_MIN + 0.04):
				var best_f: FieldData = null
				var best_c := -1
				for f in gs.fields:
					var c := 1 if f.is_civilisation() else 0
					for g in gs.neighbors(f):
						if g.is_civilisation():
							c += 1
					if c > best_c:
						best_c = c
						best_f = f
				gs.use_meteor(best_f)
				meteors += 1
			var best := [0, 0, 0]
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
						if not sim.in_balance():
							score -= 50.0
						if sim.is_over():
							score -= 10000.0
						if score > best_score:
							best_score = score
							best = [axis, layer, turns]
			if int(best[2]) != 0:
				gs.apply_rotation(int(best[0]), int(best[1]), int(best[2]))
			gs.end_round()
			rounds += 1
			if gs.is_over():
				break
		var counts := []
		for st in range(0, Balance.MAX_STAGE + 1):
			counts.append(gs.count(st))
		print("Bot Seed %d: %d Runden, Glaube %d, Meteoriten %d, Natur %.0f%%, Zivilisation %.0f%%, Stufen %s" % [
			s, rounds, gs.faith, meteors, gs.nature_share() * 100.0, gs.civilisation_share() * 100.0, str(counts)])
