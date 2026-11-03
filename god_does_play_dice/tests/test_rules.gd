extends SceneTree
## Regeltests ohne Grafik. Start (im Ordner god_does_play_dice):
##   godot --headless --import            (einmal, legt den Klassen-Cache an)
##   godot --headless --script res://tests/test_rules.gd

var failures := 0
var checks := 0


func _init() -> void:
	test_setup()
	test_geometry()
	test_ownership_by_place()
	test_economy()
	test_buy_field()
	test_stage_up()
	test_clone_independent()
	test_ai_long_run()
	print("")
	print("%d Prüfungen, %d Fehler" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		push_error("FEHLER: " + what)
		print("FEHLER: " + what)


func new_state(ai := 3, seed_value := 12345) -> GameState:
	var gs := GameState.new()
	gs.setup(ai, seed_value)
	return gs


func test_setup() -> void:
	var gs := new_state()
	check(gs.fields.size() == 54, "54 Felder")
	var centers := 0
	for f in gs.fields:
		if f.is_center:
			centers += 1
	check(centers == 6, "6 Zentren")
	for pid in 6:
		var pl: PlayerData = gs.players[pid]
		var side: Array = []
		for f in gs.fields:
			if f.n == GameState.FACE_NORMALS[pid] and not f.is_center:
				side.append(f.terrain)
		check(side.size() == 8, "8 Felder pro Seite")
		for t in Balance.GUARANTEED_TERRAIN:
			check(side.has(t), "Seite %d hat %s" % [pid, t])
		if pl.active:
			check(gs.territory(pid) == (8 if Balance.START_OWNS_SIDE else 0), "Startgebiet Spieler %d" % pid)
			check(gs.center_of(pid).owner == pid, "Zentrum gehört Spieler %d" % pid)
	check(gs.players[0].human and gs.players[0].active, "Gelb ist der Mensch")
	check(not gs.players[4].active and not gs.players[5].active, "bei 3 KI sind Lila und Weiß neutral")


func test_geometry() -> void:
	var gs := new_state()
	var center_pos := {}
	for f in gs.fields:
		if f.is_center:
			center_pos[f.id] = [f.p, f.n]
	# Vier Vierteldrehungen = Ausgangslage
	var before := []
	for f in gs.fields:
		before.append([f.p, f.n])
	for i in 4:
		gs.apply_rotation(0, 1, 1)
	var same := true
	for f in gs.fields:
		if before[f.id][0] != f.p or before[f.id][1] != f.n:
			same = false
	check(same, "4 × 90° = keine Änderung")
	# Drehung und Gegendrehung
	gs.apply_rotation(2, 0, 2)
	gs.apply_rotation(2, 0, -2)
	same = true
	for f in gs.fields:
		if before[f.id][0] != f.p or before[f.id][1] != f.n:
			same = false
	check(same, "180° hin und zurück = keine Änderung")
	# Viele zufällige Drehungen: Felder bleiben auf der Oberfläche, Zentren bleiben stehen
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 300:
		gs.apply_rotation(rng.randi_range(0, 2), rng.randi_range(-1, 1), [1, -1, 2][rng.randi_range(0, 2)])
	var keys := {}
	var ok_surface := true
	var ok_nbrs := true
	for f in gs.fields:
		keys[GameState.pos_key(f.p, f.n)] = true
		var a := GameState.axis_of(f.n)
		if f.p[a] != f.n[a]:
			ok_surface = false
		if gs.neighbors(f).size() != 4:
			ok_nbrs = false
		if f.is_center:
			check(center_pos[f.id][0] == f.p and center_pos[f.id][1] == f.n, "Zentrum %d dreht sich nie" % f.id)
	check(keys.size() == 54, "jeder Platz genau einmal belegt")
	check(ok_surface, "alle Felder auf der Oberfläche")
	check(ok_nbrs, "jedes Feld hat 4 Nachbarn")
	# Ecken haben 2 Nachbarn über die Kante, Kanten 1, Zentren 0
	for f in gs.fields:
		var cross := 0
		for nb in gs.neighbors(f):
			if nb["cross"]:
				cross += 1
		var nonzero := 0
		for a in 3:
			if f.p[a] != 0:
				nonzero += 1
		check(cross == nonzero - 1, "Kanten-Nachbarn von Feld %d" % f.id)


func test_ownership_by_place() -> void:
	var gs := new_state()
	# Scheibe x = 1 um die x-Achse: Gelbe Felder (oben) wandern nach vorne (Blau, +z)
	var moved: Array = []
	for f in gs.fields:
		if not f.is_center and f.p.x == 1 and f.n == Vector3i(0, 1, 0):
			moved.append(f)
			f.level = 2
	gs.apply_rotation(0, 1, 1)
	for f in moved:
		check(f.n == Vector3i(0, 0, 1), "Feld wandert von oben nach vorne")
		check(f.owner == 2, "Besitz hängt am Platz: jetzt Blau")
		check(f.level == 2, "Ausbau wandert mit")
	# Ein gekaufter Platz bleibt dir: Was dorthin dreht, gehört dir
	var gs2 := new_state()
	var f: FieldData = null
	for x in gs2.fields:
		if x.owner < 0 and not x.is_center:
			f = x
			break
	var place_p := f.p
	var place_n := f.n
	f.owner = 0
	gs2.pos_owner[GameState.pos_key(place_p, place_n)] = 0
	var axis := 0
	for a in 3:
		if place_n[a] == 0:
			axis = a
			break
	gs2.apply_rotation(axis, place_p[axis], 1)
	var g := gs2.field_at(place_p, place_n)
	check(g != f, "anderes Feld auf dem gekauften Platz")
	check(g.owner == 0, "Feld auf gekauftem Platz gehört dir")
	check(f.owner == int(gs2.pos_owner.get(GameState.pos_key(f.p, f.n), -1)), "weggedrehtes Feld gehört dem neuen Platz")


func test_economy() -> void:
	var gs := new_state()
	var me: PlayerData = gs.players[0]
	var inc := gs.income(0)
	check(int(inc["gold"]) == Balance.GOLD_PER_CENTER_STAGE, "Start-Einkommen = 1 Gold")
	var f: FieldData = null
	for x in gs.fields:
		if x.owner == 0 and not x.is_center and x.terrain == "forest":
			f = x
	check(f != null, "Gelb hat einen Wald")
	check(gs.upgrade_error(0, f) == "", "Ausbau auf Stufe 1 möglich")
	var gold_before := int(me.inv["gold"])
	gs.upgrade_field(0, f)
	check(f.level == 1, "Stufe 1")
	check(me.residents == Balance.START_RESIDENTS - 1, "Bewohner verbraucht")
	check(int(me.inv["gold"]) == gold_before - 3, "3 Gold bezahlt")
	check(gs.upgrade_error(0, f) != "", "Stufe 2 nur mit Haus")
	inc = gs.income(0)
	check(int(inc["wood"]) == 1, "+1 Holz")
	check(int(inc["gold"]) == 2, "+2 Gold (Zentrum + Feld)")
	gs.collect_income()
	check(int(me.inv["wood"]) == 4 - 2 + 1, "Holz gutgeschrieben")
	# Bewohnerpreis steigt alle 3 Käufe
	me.inv["gold"] = 100
	var prices: Array = []
	for i in 4:
		prices.append(gs.resident_price(0))
		gs.buy_resident(0)
	check(prices == [4, 4, 4, 5], "Bewohnerpreis 4,4,4,5")


func test_buy_field() -> void:
	var gs := new_state()
	var me: PlayerData = gs.players[0]
	me.inv["gold"] = 100
	var same_side: FieldData = null
	var cross_only: FieldData = null
	for f in gs.fields:
		if f.owner >= 0 or f.is_center:
			continue
		var touches_same := false
		var touches_cross := false
		for nb in gs.neighbors(f):
			if nb["field"].owner == 0:
				if nb["cross"]:
					touches_cross = true
				else:
					touches_same = true
		if touches_same and same_side == null:
			same_side = f
		if touches_cross and not touches_same and cross_only == null:
			cross_only = f
	if cross_only != null:
		check(gs.buy_field_error(0, cross_only) != "", "über die Kante erst ab Haus")
		me.stage = 2
		check(gs.buy_field_error(0, cross_only) == "", "über die Kante ab Haus möglich")
		gs.buy_field(0, cross_only)
		check(cross_only.owner == 0, "Feld gekauft")
		check(gs.field_price(0, cross_only) == Balance.FIELD_BASE_PRICE + Balance.FIELD_PRICE_STEP, "Preis steigt")
	# Fremdes Feld nicht kaufbar
	for f in gs.fields:
		if f.owner == 1 and not f.is_center:
			check(gs.buy_field_error(0, f) != "", "fremdes Feld nicht kaufbar")
			break


func test_stage_up() -> void:
	var gs := new_state()
	var me: PlayerData = gs.players[0]
	me.inv = {"gold": 999, "wood": 999, "stone": 999, "food": 0}
	check(gs.stage_up_error(0) != "", "Wartezeit am Anfang")
	gs.tick = Balance.STAGE_COOLDOWN_TICKS
	check(gs.stage_up_error(0) == "", "nach 12 Takten möglich")
	gs.stage_up(0)
	check(me.stage == 2 and me.rotations == 1, "Haus + 1 Drehung")
	check(gs.stage_up_error(0) != "", "wieder Wartezeit")
	check(gs.trade_error(0, "wood", "food") != "", "Tausch erst ab Marktplatz")
	me.stage = 3
	check(gs.trade_error(0, "wood", "food") == "", "Tausch ab Marktplatz")
	var wood_before := int(me.inv["wood"])
	gs.trade(0, "wood", "food")
	check(int(me.inv["food"]) == 1 and int(me.inv["wood"]) == wood_before - 3, "3:1 getauscht")


func test_clone_independent() -> void:
	var gs := new_state()
	var c := gs.clone()
	c.apply_rotation(1, -1, 1)
	c.players[0].inv["gold"] = 999
	check(gs.fields[0].p == Vector3i(-1, -1, -1) and c.fields[0].p != gs.fields[0].p, "Original unverändert")
	check(int(gs.players[0].inv["gold"]) == Balance.START_INV["gold"], "Inventar nicht geteilt")


func test_ai_long_run() -> void:
	var gs := new_state(5, 99)
	var rotations := 0
	for t in 200:
		gs.tick += 1
		gs.collect_income()
		for pl in gs.players:
			if not pl.active or pl.human:
				continue
			var res := AIPlayer.act(gs, pl.id)
			var r: Dictionary = res["rotation"]
			if not r.is_empty():
				gs.apply_rotation(int(r["axis"]), int(r["layer"]), int(r["turns"]))
				rotations += 1
	var ok := true
	for pl in gs.players:
		for k in pl.inv:
			if int(pl.inv[k]) < 0:
				ok = false
		if pl.residents < 0:
			ok = false
	check(ok, "KI hat nie negative Bestände")
	var best := 0
	for pl in gs.players:
		if pl.active and not pl.human:
			best = maxi(best, pl.stage)
	check(best >= 3, "Balancing: KI erreicht in 200 Takten mindestens Marktplatz (beste: %d)" % best)
	print("KI-Lauf: %d Drehungen, Stufen: %s, Felder: %s" % [rotations,
		str(gs.players.map(func(p): return p.stage)),
		str(gs.players.map(func(p): return gs.territory(p.id)))])
