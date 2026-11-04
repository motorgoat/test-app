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
	test_needs()
	test_war_and_trade()
	test_pollution_and_spread()
	test_hazards()
	test_punishment()
	test_tools()
	test_harmony()
	test_preview_matches()
	test_long_run()
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


## Welt nur aus Bergen (neutral) für gezielte Tests.
func empty_state() -> GameState:
	var gs := new_state()
	for f in gs.fields:
		if f.is_center:
			continue
		f.kind = "mountain"
		f.level = 1
		f.nation = -1
		f.bond = 0
		f.need = 0
		f.damage = 0
		f.pollution = 0
		f.burning = false
		f.volcano = 0
	gs.hazards.clear()
	return gs


## Oberseite: Mitte (0,1,0) ist fest. Benachbarte bewegliche Felder dort.
func top(gs: GameState, x: int, z: int) -> FieldData:
	return gs.field_at(Vector3i(x, 1, z), Vector3i(0, 1, 0))


func put(f: FieldData, kind: String, level: int = 1, nation: int = -1) -> void:
	f.kind = kind
	f.level = level
	f.nation = nation


func test_setup() -> void:
	var gs := new_state()
	check(gs.fields.size() == 54, "54 Felder")
	check(gs.lines().is_empty(), "am Start keine fertigen Dreierreihen")
	check(gs.war_pairs().is_empty(), "kein Krieg am Start")
	check(gs.settlements() > 0, "es gibt Siedlungen")
	var hm := gs.harmony()
	check(float(hm["value"]) > 0.3, "Start ist einigermaßen im Gleichgewicht (%.2f)" % float(hm["value"]))


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
	put(a, "nature")
	put(b, "nature")
	check(gs.lines().is_empty(), "zwei reichen nicht")
	put(c, "nature", 2)
	check(gs.lines().is_empty(), "verschiedene Stufen verschmelzen nicht")
	put(c, "nature", 1)
	check(gs.lines().size() == 1, "drei gleiche in einer Reihe")
	var r := gs.end_round()
	check(b.kind == "nature" and b.level == 2, "Mitte wird zum Fluss (%s %d)" % [b.kind, b.level])
	check(a.kind != "nature" or a.level == 1, "Außen wird neu belegt")
	check(int(r["gain"]) > 0 and gs.faith > 0, "Verschmelzen bringt Glauben (%d)" % gs.faith)
	var merges := 0
	for e in r["events"]:
		if e["type"] == "merge":
			merges += 1
	check(merges >= 1, "Ereignis merge")
	# Völker: nur gleiches Volk verschmilzt
	var gs2 := empty_state()
	put(top(gs2, 1, -1), "settlement", 1, 0)
	put(top(gs2, 1, 0), "settlement", 1, 1)
	put(top(gs2, 1, 1), "settlement", 1, 0)
	check(gs2.lines().is_empty(), "verschiedene Völker verschmelzen nicht")
	# Ohne Verschmelzen kein Glaube
	var gs3 := empty_state()
	put(top(gs3, 1, 0), "nature")
	put(top(gs3, 1, 1), "nature")
	var r3 := gs3.end_round()
	check(int(r3["gain"]) == 0, "nebeneinander allein bringt nichts mehr")


func test_needs() -> void:
	var gs := empty_state()
	var s := top(gs, 1, 1)
	put(s, "settlement", 2, 0)
	for i in Balance.NEED_ROUNDS:
		gs.end_round()
	check(s.level == 1, "Siedlung ohne Natur verliert eine Stufe (%d)" % s.level)
	var gs2 := empty_state()
	var s2 := top(gs2, 1, 1)
	put(s2, "settlement", 2, 0)
	put(top(gs2, 1, 0), "nature")
	for i in Balance.NEED_ROUNDS:
		gs2.end_round()
	check(s2.level == 2, "Siedlung mit Natur bleibt (%d)" % s2.level)
	var gs3 := empty_state()
	var lone := top(gs3, 1, 1)
	put(lone, "industry", 1)
	for i in Balance.NEED_ROUNDS:
		gs3.end_round()
	check(lone.kind == "crater", "Werkstatt ohne Siedlung verfällt zum Krater")


func test_war_and_trade() -> void:
	var gs := empty_state()
	var c1 := top(gs, 1, 1)
	var c2 := top(gs, 1, 0)
	put(c1, "faith", 2, 0)
	put(c2, "faith", 2, 1)
	put(top(gs, 0, 1), "settlement", 1, 0)
	put(top(gs, 1, -1), "settlement", 1, 1)
	put(top(gs, -1, 1), "nature")
	put(top(gs, 0, -1), "nature")
	check(gs.war_pairs().has(GameState.pair_key(0, 1)), "Kirchen nebeneinander: Krieg")
	for i in Balance.WAR_ROUNDS:
		gs.end_round()
	check(c1.level == 1 and c2.level == 1, "Krieg kostet beide eine Stufe (%d, %d)" % [c1.level, c2.level])
	# Handel zwischen Städten
	var gs2 := empty_state()
	var t1 := top(gs2, 1, 1)
	var t2 := top(gs2, 1, 0)
	put(t1, "settlement", 2, 0)
	put(t2, "settlement", 2, 1)
	check(gs2.trade_pairs().has(GameState.pair_key(0, 1)), "Städte zweier Völker: Handel")
	# Krieg verhindert Handel
	put(top(gs2, -1, 1), "faith", 1, 0)
	put(top(gs2, -1, 0), "faith", 1, 1)
	check(gs2.trade_pairs().is_empty(), "im Krieg kein Handel")


func test_pollution_and_spread() -> void:
	var gs := empty_state()
	var fac := top(gs, 1, 1)
	var nat := top(gs, 1, 0)
	put(fac, "industry", 2)
	put(top(gs, 0, 1), "settlement", 1, 0)
	put(nat, "nature", 2)
	put(top(gs, 1, -1), "nature", 2)
	for i in Balance.POLLUTION_ROUNDS:
		gs.end_round()
	check(nat.level < 2 or nat.kind == "crater", "Fabrik verschmutzt Natur daneben")
	# Ausbreiten: Stadt Stufe 3 frisst Natur Stufe 1
	var gs2 := empty_state()
	var city := top(gs2, 1, 1)
	put(city, "settlement", 3, 0)
	var grass := top(gs2, 1, 0)
	put(grass, "nature", 1)
	gs2.turn = gs2.spread_every()
	gs2.end_round()
	check(grass.has_nation() and grass.nation == 0, "Metropole breitet sich auf Natur aus")


func test_hazards() -> void:
	var gs := empty_state()
	var v := top(gs, 1, 1)
	put(v, "settlement", 2, 0)
	put(top(gs, 1, 0), "nature")
	gs.hazards.append({"type": "meteor", "p": v.p, "n": v.n, "timer": 1})
	gs.apply_rotation(0, 1, 1)   # Scheibe x=1 dreht: Siedlung wandert weg
	var hit := gs.field_at(Vector3i(1, 1, 1), Vector3i(0, 1, 0))
	check(hit != v, "Siedlung ist weggedreht")
	gs.end_round()
	check(hit.kind == "crater", "Meteor macht einen Krater")
	check(v.kind == "settlement", "weggedrehte Siedlung überlebt")
	# Feuer und Fluss
	var gs2 := empty_state()
	var f1 := top(gs2, 1, 1)
	put(f1, "nature", 1)
	f1.burning = true
	var f2 := top(gs2, 1, 0)
	put(f2, "nature", 1)
	gs2.end_round()
	check(f1.kind == "crater", "Feuer brennt Natur nieder")
	check(f2.burning, "Feuer springt über")
	var gs3 := empty_state()
	var g1 := top(gs3, 1, 1)
	put(g1, "nature", 1)
	g1.burning = true
	put(top(gs3, 1, 0), "nature", 2)
	gs3.end_round()
	check(g1.kind == "nature" and not g1.burning, "Fluss daneben löscht")


func test_tools() -> void:
	var gs := new_state()
	var f: FieldData = null
	for g in gs.fields:
		if g.kind == "nature":
			f = g
			break
	check(gs.can_lightning(f) == "", "Blitz am Start bereit")
	gs.use_lightning(f)
	check(f.kind == "crater" and gs.lightning == Balance.LIGHTNING_START - 1, "Blitz macht Krater")
	check(gs.can_miracle(f) != "", "ohne Wunder kein Wunder")
	gs.miracles = 1
	gs.use_miracle(f, "industry")
	check(f.kind == "industry" and f.level == 1, "Wunder erschafft Feld nach Wahl")


func test_harmony() -> void:
	var gs := empty_state()
	for f in gs.fields:
		if not f.is_center:
			put(f, "industry", 1)
	check(float(gs.harmony()["value"]) < 0.1, "nur Industrie: kein Gleichgewicht")
	gs.bad_rounds = Balance.LOSE_AFTER_DISHARMONY
	check(gs.is_over(), "zu lange aus dem Gleichgewicht: Ende")


func test_preview_matches() -> void:
	var gs := new_state(777)
	gs.hazards.append({"type": "meteor", "p": Vector3i(1, 1, 1), "n": Vector3i(0, 1, 0), "timer": 1})
	var sim := gs.clone()
	sim.apply_rotation(2, 1, 1)
	var r1 := sim.end_round()
	gs.apply_rotation(2, 1, 1)
	var r2 := gs.end_round()
	var same := int(r1["gain"]) == int(r2["gain"]) and sim.faith == gs.faith
	for f in gs.fields:
		var g: FieldData = sim.fields[f.id]
		if f.kind != g.kind or f.level != g.level or f.p != g.p:
			same = false
	check(same, "Vorschau = echte Runde")


func test_long_run() -> void:
	for s in [1, 2, 3]:
		var gs := new_state(s)
		var rng := RandomNumberGenerator.new()
		rng.seed = s * 99
		var rounds := 0
		for t in 150:
			gs.apply_rotation(rng.randi_range(0, 2), rng.randi_range(-1, 1), [1, -1][rng.randi_range(0, 1)])
			gs.end_round()
			gs.spawn_hazards()
			rounds += 1
			if gs.is_over():
				break
		var ok := true
		for f in gs.fields:
			if f.level < 1 or f.level > 3:
				ok = false
			if f.has_nation() and f.nation >= Balance.NATION_COUNT:
				ok = false
		check(ok, "Werte bleiben gültig (Seed %d)" % s)
		var hm := gs.harmony()
		print("Zufallsspiel Seed %d: %d Runden, Glaube %d, Gleichgewicht %.2f, Anteile %s" % [s, rounds, gs.faith, float(hm["value"]), str(hm["counts"])])


## Ein einfacher Bot wählt jede Runde die Drehung mit dem besten Ergebnis (Glaube + Gleichgewicht).
## Kein Test im engeren Sinn: zeigt, wie lange ein aufmerksamer Spieler überlebt.
func test_bot() -> void:
	for s in [11, 22, 33]:
		var gs := new_state(s)
		var rounds := 0
		for t in 120:
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
						var score: float = int(r["gain"]) - int(r["loss"]) + 60.0 * float(sim.harmony()["value"])
						if sim.is_over():
							score -= 10000.0
						if score > best_score:
							best_score = score
							best = [axis, layer, turns]
			if int(best[2]) != 0:
				gs.apply_rotation(int(best[0]), int(best[1]), int(best[2]))
			gs.end_round()
			gs.spawn_hazards()
			rounds += 1
			if gs.is_over():
				break
		var hm := gs.harmony()
		print("Bot Seed %d: %d Runden (Zeitalter %d), Glaube %d, Gleichgewicht %.2f, Anteile %s" % [s, rounds, gs.age(), gs.faith, float(hm["value"]), str(hm["counts"])])


func test_punishment() -> void:
	var gs := new_state()
	gs.turn = 10
	var none := true
	for i in 30:
		if not gs.spawn_hazards().is_empty():
			none = false
	check(none, "im Gleichgewicht keine Katastrophen")
	# Zu viel Industrie: Strafe trifft eine Fabrik
	var gs2 := new_state()
	gs2.turn = 10
	var k := 0
	for f in gs2.fields:
		if f.kind == "nature" and k < 14:
			f.kind = "industry"
			k += 1
	check(gs2.harmony()["status"]["industry"] == "high", "zu viel Industrie erkannt")
	var spawned: Array = []
	for i in 30:
		spawned = gs2.spawn_hazards()
		if not spawned.is_empty():
			break
	check(not spawned.is_empty(), "Strafe kommt")
	if not spawned.is_empty():
		var h: Dictionary = spawned[0]
		check(str(h["cause"]) == "industry", "Grund: Industrie")
		var target := gs2.field_at(h["p"], h["n"])
		check(target != null and target.kind == "industry", "Ziel ist eine Fabrik")
