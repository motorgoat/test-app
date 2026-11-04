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
	test_cascade()
	test_regrow_and_pollution()
	test_bonus()
	restore()
	test_fire()
	test_quake()
	test_hint()
	test_easy()
	test_preview_matches()
	test_modes()
	test_bot()
	print("")
	print("%d Prüfungen, %d Fehler" % [checks, failures])
	quit(1 if failures > 0 else 0)


## Für die reinen Regeltests: keine Katastrophe, die dazwischenfunkt.
func calm() -> void:
	_saved = {"cmax": Balance.CIVILISATION_MAX, "fire": Balance.FIRE_AFTER}
	Balance.CIVILISATION_MAX = 1.0
	Balance.FIRE_AFTER = 999


func restore() -> void:
	Balance.CIVILISATION_MAX = _saved["cmax"]
	Balance.FIRE_AFTER = _saved["fire"]


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


func ids(fs: Array) -> Array:
	var out: Array = []
	for f in fs:
		out.append((f as FieldData).id)
	return out


## Lauter Siedlungen ohne Dreierreihe, auch nicht diagonal.
func civ_pattern(f: FieldData) -> int:
	var a := GameState.axis_of(f.n)
	var i: int = f.p[(a + 1) % 3] + 1
	var j: int = f.p[(a + 2) % 3] + 1
	return int([[4, 5, 4], [6, 4, 6], [5, 6, 5]][i][j])


func _disaster_of(r: Dictionary) -> Dictionary:
	for e in r["events"]:
		if str(e["type"]) == "disaster":
			return e
	return {}


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
	for sd in [1, 2, 3, 4, 5, 6, 7, 8]:
		var g := new_state(sd)
		var clumps := 0
		for f in g.fields:
			if f.stage != 1:
				continue
			var m := 0
			for h in g.neighbors(f):
				if (h as FieldData).stage == 1:
					m += 1
			if m >= 2:
				clumps += 1
		check(clumps == 0, "Seed %d: am Start nie drei Wiesen beisammen" % sd)
		check(g.in_balance() and g.nature_share() >= Balance.START_NATURE - 0.02, "Seed %d: genug Natur am Start (%.0f%%)" % [sd, g.nature_share() * 100.0])


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
	gs.moved[c.id] = true
	var r := gs.end_round()
	check(c.stage == 2, "das zuletzt dazugekommene Feld wird kleiner Wald (%d)" % c.stage)
	check(a.stage == 1 and b.stage == 1, "die anderen beiden bleiben Wiesen")
	check(int(r["gain"]) == int(Balance.MERGE_POINTS[1]), "Punkte fürs Verschmelzen (%d)" % int(r["gain"]))
	# Hat sich die ganze Reihe verändert (z. B. mitgedreht), steigt die Mitte auf
	var gw := empty_state()
	for x in [-1, 0, 1]:
		top(gw, x, 1).stage = 1
		gw.moved[top(gw, x, 1).id] = true
	gw.end_round()
	check(top(gw, 0, 1).stage == 2 and top(gw, -1, 1).stage == 1, "ganze Reihe verändert: die Mitte steigt auf")
	# Ganze Seite aus 9 gleichen: die ganze Seite steigt auf und bleibt stehen
	var gf := empty_state()
	for f in gf.fields:
		if f.n == Vector3i(0, 1, 0):
			f.stage = 2
	gf.moved = {top(gf, 1, 1).id: true}
	var rf := gf.end_round()
	var all3 := true
	for f in gf.fields:
		if f.n == Vector3i(0, 1, 0) and f.stage != 3:
			all3 = false
	check(all3 and int(rf["gain"]) == int(Balance.MERGE_POINTS[2]) * Balance.FACE_BONUS, "ganze Seite steigt auf (+%d)" % int(rf["gain"]))
	var rf2 := gf.end_round()
	check(top(gf, 0, 0).stage == 3 and int(rf2["gain"]) == 0, "fertige Seite bleibt stehen")
	# Durch eine Drehung: das hineingedrehte Feld steigt auf
	var gr := empty_state()
	top(gr, -1, 1).stage = 1
	top(gr, 0, 1).stage = 1
	var third := gr.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1))
	third.stage = 1
	gr.apply_rotation(0, 1, 1)
	check(top(gr, 1, 1) == third, "drittes Feld rückt in die Reihe")
	var rr := gr.end_round()
	check(third.stage == 2 and int(rr["gain"]) > 0, "hineingedrehtes Feld steigt auf")
	var gs4 := empty_state()
	for x in [-1, 0, 1]:
		top(gs4, x, 1).stage = 3
	gs4.moved = {top(gs4, 1, 1).id: true}
	gs4.resolve_merges([])
	check(top(gs4, 1, 1).stage == 4 and top(gs4, 0, 1).stage == 3 and top(gs4, -1, 1).stage == 3, "3 große Wälder → Hütte, die anderen bleiben große Wälder")
	# Die ganze Leiter hinauf
	var gs2 := empty_state()
	var names := []
	for st in range(1, Balance.MAX_STAGE):
		top(gs2, -1, -1).stage = st
		top(gs2, -1, 0).stage = st
		top(gs2, -1, 1).stage = st
		gs2.moved = {top(gs2, -1, 1).id: true}
		gs2.resolve_merges([])
		names.append(top(gs2, -1, 1).stage)
	check(names == [2, 3, 4, 5, 6, 7, 8, 9], "Leiter Wiese … Metropole (%s)" % str(names))
	# Diagonal („quer“) erst ab dem kleinen Wald
	var gd := empty_state()
	top(gd, -1, -1).stage = 1
	top(gd, 0, 0).stage = 1
	top(gd, 1, 1).stage = 1
	check(gd.lines().is_empty(), "Wiesen verbinden sich nicht diagonal")
	for f in [top(gd, -1, 1), top(gd, 0, 0), top(gd, 1, -1)]:
		(f as FieldData).stage = 2
	top(gd, -1, -1).stage = 0
	top(gd, 1, 1).stage = 0
	check(gd.lines().size() == 1, "kleine Wälder verbinden sich auch diagonal")
	gd.moved = {top(gd, 1, -1).id: true}
	gd.end_round()
	check(top(gd, 1, -1).stage == 3, "diagonale Reihe: das zuletzt dazugekommene Feld steigt auf")
	var gs3 := empty_state()
	top(gs3, 1, 0).stage = 3
	top(gs3, 1, 1).stage = 3
	check(int(gs3.end_round()["gain"]) == 0, "zwei gleiche nebeneinander bringen nichts")


func test_cascade() -> void:
	# Spalte x=1 oben: drei Wiesen, (1,1) kommt zuletzt dazu und wird Wald. Daneben zwei Wälder: Kombo
	var gs := empty_state()
	top(gs, 1, -1).stage = 1
	top(gs, 1, 0).stage = 1
	top(gs, 1, 1).stage = 1
	top(gs, 0, 1).stage = 2
	top(gs, -1, 1).stage = 2
	gs.moved = {top(gs, 1, 1).id: true}
	var ev: Array = []
	var pts := gs.resolve_merges(ev)
	check(ev.size() == 2, "Kettenreaktion: zwei Verschmelzungen (%d)" % ev.size())
	if ev.size() == 2:
		check(int(ev[1]["combo"]) == 2, "zweite zählt als Kombo")
		check(int(ev[1]["field"]) == top(gs, 1, 1).id and top(gs, 1, 1).stage == 3, "Kombo steigt am selben Feld weiter auf")
	check(pts == int(Balance.MERGE_POINTS[1]) + int(Balance.MERGE_POINTS[2]) * 2, "Kombo verdoppelt (%d)" % pts)


func test_regrow_and_pollution() -> void:
	var g0 := empty_state()
	top(g0, 0, 0).stage = 1
	top(g0, 1, 1).stage = 2
	g0.end_round()
	check(Balance.REGROW_PER_ROUND > 0 or top(g0, 1, 0).stage == 0, "Wiese wächst nicht von allein")
	var saved_regrow := Balance.REGROW_PER_ROUND
	Balance.REGROW_PER_ROUND = 2
	var gs := empty_state()
	top(gs, 0, 0).stage = 1
	top(gs, 1, 1).stage = 2
	var e := top(gs, 1, 0)
	gs.end_round()
	check(e.stage == 1, "(abschaltbar) Erde mit 2 Natur-Nachbarn wird Wiese")
	Balance.REGROW_PER_ROUND = saved_regrow
	var g1 := empty_state()
	top(g1, 1, 1).stage = 9
	top(g1, 1, 0).stage = 2
	g1.end_round()
	check(Balance.POLLUTION_FROM > Balance.MAX_STAGE and top(g1, 1, 0).stage == 2, "nach unten geht es nur durch Katastrophen (keine Verschmutzung)")
	var saved_poll := Balance.POLLUTION_FROM
	Balance.POLLUTION_FROM = 8
	var gs2 := empty_state()
	var fac := top(gs2, 1, 1)
	fac.stage = 8
	var nat := top(gs2, 1, 0)
	nat.stage = 2
	gs2.end_round()
	check(nat.stage == 0, "(abschaltbar) Großstadt zerstört Natur daneben")
	Balance.POLLUTION_FROM = saved_poll


func test_bonus() -> void:
	# Regen: ein Feld steigt eine Stufe
	var gs := empty_state()
	gs.rain = 1
	var f := top(gs, 0, 0)
	check(gs.can_bonus("rain", f) == "", "Regen geht")
	gs.apply_bonus("rain", f)
	check(f.stage == 1 and gs.rain == 0, "Regen: Erde wird Wiese, Regen verbraucht")
	var others := 0
	for g in gs.neighbors(f):
		others += (g as FieldData).stage
	check(others == 0, "Regen trifft nur ein Feld")
	check(gs.can_bonus("rain", f) != "", "ohne Regen kein Regen")
	gs.end_round()
	# Blitz: eine ganze Reihe steigt eine Stufe
	gs.bolts = 1
	var row := gs.line_through(f, 0)
	top(gs, -1, 0).stage = 2
	gs.apply_bonus("bolt", f, row)
	check(top(gs, -1, 0).stage == 3 and f.stage == 2 and top(gs, 1, 0).stage == 1 and gs.bolts == 0, "Blitz hebt die ganze Reihe")
	# Blitz: das angetippte Feld steigt beim Verschmelzen auf
	var gb := empty_state()
	gb.bolts = 1
	for x in [-1, 0, 1]:
		top(gb, x, 0).stage = 1
	var tap := top(gb, 1, 0)
	gb.apply_bonus("bolt", tap, gb.line_through(tap, 0))
	# jetzt drei kleine Wälder in einer Reihe, alle verändert: das angetippte steigt auf
	gb.end_round()
	check(tap.stage == 3 and top(gb, 0, 0).stage == 2, "Blitz: das angetippte Feld steigt beim Verschmelzen auf")
	# Blitz für drei gleiche Felder an einer Würfelecke
	var gc := empty_state()
	gc.bolts = 0
	var corner := Vector3i(1, 1, 1)
	gc.field_at(corner, Vector3i(1, 0, 0)).stage = 1
	gc.field_at(corner, Vector3i(0, 0, 1)).stage = 1
	var third_c := gc.field_at(corner, Vector3i(0, 1, 0))
	third_c.stage = 1
	gc.moved = {third_c.id: true}
	var rc := gc.end_round()
	check(gc.bolts == 1 and int((rc["bonus_gained"] as Dictionary)["bolt"]) == 1, "drei gleiche an einer Ecke: ein Blitz")
	# Blitz auf ein Eckfeld: die Diagonale dieser Seite steigt
	var gd2 := empty_state()
	gd2.bolts = 1
	var cf := top(gd2, 1, 1)
	check(gd2.can_bonus("bolt", top(gd2, 0, 1)) != "" and gd2.can_bonus("bolt", cf) == "", "Blitz nur auf Eckfelder")
	gd2.apply_bonus("bolt", cf)
	check(cf.stage == 1 and top(gd2, 0, 0).stage == 1 and top(gd2, -1, -1).stage == 1 and top(gd2, 1, -1).stage == 0, "Blitz hebt die Diagonale ab dem Eckfeld")
	# Regen ist kein ganzer Zug
	var gr2 := empty_state()
	gr2.rain = 2
	var t0 := gr2.turn
	gr2.apply_bonus("rain", top(gr2, 0, 0))
	gr2.resolve_now()
	gr2.apply_bonus("rain", top(gr2, 1, 0))
	gr2.resolve_now()
	check(gr2.turn == t0 and top(gr2, 0, 0).stage == 1 and top(gr2, 1, 0).stage == 1, "zweimal gießen hintereinander, ohne Zug")
	# Regen kann eine Reihe vervollständigen: Dann verschmilzt sie dort
	var gl := empty_state()
	gl.rain = 1
	top(gl, -1, 1).stage = 1
	top(gl, 0, 1).stage = 1
	gl.apply_bonus("rain", top(gl, 1, 1))
	var r := gl.end_round()
	check(top(gl, 1, 1).stage == 2 and int(r["gain"]) > 0, "Regen macht die dritte Wiese: Sie wird Wald")
	# Monsun: die ganze Seite steigt eine Stufe
	var gm2 := empty_state()
	gm2.monsoons = 1
	top(gm2, 0, 0).stage = 1
	top(gm2, 1, 0).stage = 2
	gm2.apply_bonus("monsoon", top(gm2, 0, 0))
	var face_ok := true
	for fd in gm2.fields:
		if fd.n == Vector3i(0, 1, 0) and fd.stage < 1:
			face_ok = false
	check(face_ok and top(gm2, 0, 0).stage == 2 and top(gm2, 1, 0).stage == 3 and gm2.monsoons == 0, "Monsun hebt die ganze Seite")
	var gu := empty_state()
	top(gu, 0, 0).stage = Balance.MONSOON_FROM_STAGE
	var ru := gu.end_round()
	check(gu.monsoon_unlocked and gu.monsoons == 1 and int((ru["bonus_gained"] as Dictionary)["monsoon"]) == 1, "Monsun ab der Antike freigeschaltet")
	# Punkte bringen Regen
	var gp := empty_state()
	gp.rain = 0
	gp.score = Balance.RAIN_EVERY - 1
	for x in [-1, 0, 1]:
		top(gp, x, -1).stage = 1
	gp.moved = {top(gp, 1, -1).id: true}
	var rp := gp.end_round()
	check(gp.rain == 1 and int((rp["bonus_gained"] as Dictionary)["rain"]) == 1, "bei %d Punkten gibt es Regen" % Balance.RAIN_EVERY)


func test_fire() -> void:
	# Oben verschiedene Stufen (ohne Großstadt, die würde Natur zerstören), sonst Erde:
	# Drehungen der unteren Scheibe verschmelzen nichts
	var gs := empty_state()
	var k := 0
	for f in gs.fields:
		if f.n == Vector3i(0, 1, 0):
			k += 1
			f.stage = k if k < Balance.POLLUTION_FROM else 0
	var row := ids([top(gs, -1, -1), top(gs, -1, 0), top(gs, -1, 1)])
	for i in Balance.FIRE_AFTER - 1:
		gs.apply_rotation(1, -1, 1)
		var r := gs.end_round()
		check(_disaster_of(r).is_empty(), "Fehlversuch %d: noch kein Brand" % (i + 1))
	check(gs.misses == Balance.FIRE_AFTER - 1, "Fehlversuche werden gezählt (%d)" % gs.misses)
	var before := top(gs, -1, 0).stage
	gs.apply_rotation(1, -1, 1, row)
	var rf := gs.end_round()
	var e := _disaster_of(rf)
	check(str(e.get("kind", "")) == "fire" and (e["hit"] as Array).size() == 3, "%d. Fehlversuch: die gewischte Reihe brennt" % Balance.FIRE_AFTER)
	check(top(gs, -1, 0).burning and gs.misses == 0, "Felder brennen, Zähler beginnt von vorn")
	check(gs.lives == Balance.LIVES - (1 if Balance.FIRE_COSTS_LIFE else 0), "Brand kostet ein Leben (wenn eingestellt)")
	gs.rain = 1
	var saved_f := top(gs, -1, 1)
	var saved_st := saved_f.stage
	gs.apply_bonus("rain", saved_f)
	check(not saved_f.burning and top(gs, -1, 0).burning, "Regen löscht genau ein Feld")
	gs.end_round()
	check(top(gs, -1, 0).stage == before - 1 and not top(gs, -1, 0).burning, "Brand: eine Stufe zurück, dann ist das Feuer aus (%d → %d)" % [before, top(gs, -1, 0).stage])
	check(saved_f.stage == saved_st, "gelöschtes Feld verliert nichts")
	gs.end_round()
	check(top(gs, -1, 0).stage == before - 1, "Brand dauert nur eine Runde")
	# Ein Erfolg setzt den Zähler nicht zurück
	var gm := empty_state()
	gm.misses = 1
	top(gm, -1, 1).stage = 1
	top(gm, 0, 1).stage = 1
	var third := gm.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1))
	third.stage = 1
	gm.apply_rotation(0, 1, 1)
	var rm := gm.end_round()
	check(int(rm["gain"]) > 0 and gm.misses == 1, "Erfolg setzt Fehlversuche nicht zurück")


func test_quake() -> void:
	# Lauter Siedlungen ohne Dreierreihe, oben eine besonders große Reihe
	var gq := empty_state()
	for f in gq.fields:
		f.stage = civ_pattern(f)
	var big := [top(gq, -1, 1), top(gq, 0, 1), top(gq, 1, 1)]
	(big[0] as FieldData).stage = 8
	(big[1] as FieldData).stage = 9
	(big[2] as FieldData).stage = 8
	gq.best_stage = Balance.MAX_STAGE
	check(gq.lines().is_empty(), "Testaufbau ohne Dreierreihe")
	check(gq.threat() == "quake", "zu viel Zivilisation: Erdbeben droht")
	var r := gq.end_round()
	var e := _disaster_of(r)
	var hit: Array = e.get("hit", [])
	hit.sort()
	var want := ids(big)
	want.sort()
	check(str(e.get("kind", "")) == "quake" and hit == want, "Erdbeben trifft die Reihe mit der meisten Zivilisation")
	check((big[1] as FieldData).stage == 8 and (big[0] as FieldData).stage == 7, "die Reihe fällt eine Stufe zurück")
	check(gq.lives == Balance.LIVES - (1 if Balance.LIVES > 0 else 0), "Erdbeben kostet ein Leben (wenn es Leben gibt)")
	# Ohne Leben ist Schluss; neues Zeitalter gibt eines zurück
	var gd := empty_state()
	gd.lives = 1
	for f in gd.fields:
		f.stage = civ_pattern(f)
	gd.end_round()
	check(gd.died() == (Balance.LIVES > 0), "ohne Leben stirbt die Welt (nur wenn es Leben gibt)")
	var gx := empty_state()
	gx.rain = 0
	gx.bolts = 0
	top(gx, 0, 0).stage = 1
	top(gx, 1, 1).stage = 1
	check(gx.stuck() and gx.is_over(), "nichts mehr zu verbinden: Spielende")
	gx.rain = 1
	check(not gx.stuck(), "mit Regen geht es weiter")
	var ga := empty_state()
	ga.lives = 1
	top(ga, 0, 0).stage = 4
	var ra := ga.end_round()
	check(bool(ra["new_age"]) and ga.age_name() == "Steinzeit", "erste Hütte: Steinzeit")
	check(Balance.LIVES == 0 or ga.lives == 2, "neues Zeitalter: ein Leben zurück (wenn es Leben gibt)")


func test_easy() -> void:
	var gs := GameState.new()
	gs.setup(12345, true, true)
	for f in gs.fields:
		f.stage = 0
	# drei Wiesen über Eck (keine Reihe): im einfachen Modus verschmelzen sie
	top(gs, 0, 0).stage = 1
	top(gs, 1, 0).stage = 1
	top(gs, 1, 1).stage = 1
	gs.moved = {top(gs, 1, 1).id: true}
	var r := gs.end_round()
	check(int(r["gain"]) > 0 and top(gs, 1, 1).stage == 2 and top(gs, 0, 0).stage == 1, "einfacher Modus: drei sich berührende Wiesen verschmelzen")
	var gn := empty_state()
	top(gn, 0, 0).stage = 1
	top(gn, 1, 0).stage = 1
	top(gn, 1, 1).stage = 1
	gn.moved = {top(gn, 1, 1).id: true}
	check(int(gn.end_round()["gain"]) == 0, "normaler Modus: über Eck zählt nicht")


func test_hint() -> void:
	var gs := empty_state()
	check(gs.best_move().is_empty(), "nur Erde: kein Tipp")
	top(gs, -1, 1).stage = 1
	top(gs, 0, 1).stage = 1
	gs.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1)).stage = 1
	var b := gs.best_move()
	check(not b.is_empty() and int(b["steps"]) == 1, "Tipp findet die Drehung, die sofort verschmilzt")
	var g2 := empty_state()
	top(g2, -1, 1).stage = 1
	top(g2, 0, 1).stage = 1
	g2.field_at(Vector3i(1, -1, -1), Vector3i(0, 0, -1)).stage = 1
	var b2 := g2.best_move()
	var direct := 0
	for axis in 3:
		for layer in [-1, 0, 1]:
			for turns in [1, -1, 2]:
				var sim := g2.clone()
				sim.moved = {}
				sim.apply_rotation(axis, layer, turns)
				direct += sim.merge_value()
	check(not b2.is_empty() and (int(b2["steps"]) == 1) == (direct > 0), "Tipp schaut zwei Züge voraus, wenn sofort nichts geht (%s)" % str(b2))


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


## Ein einfacher Bot: wählt den besten Zug (ein Zug voraus), auch Regen und Blitz.
func run_bot(s: int, passive: bool, max_rounds: int = 150) -> Dictionary:
	var gs := new_state(s)
	var bonuses := 0
	var fires := 0
	for t in max_rounds:
		var best: Array = [0, 0, 0]
		if not passive:
			var best_score := -INF
			var moves: Array = []
			for axis in 3:
				for layer in [-1, 0, 1]:
					for turns in [1, -1, 2]:
						moves.append([axis, layer, turns])
			if gs.rain > 0:
				for f in gs.fields:
					if f.burning or f.stage == 0:
						moves.append(["rain", f.id, []])
			if gs.bolts > 0:
				for line in gs.all_rows():
					moves.append(["bolt", (line[1] as FieldData).id, ids(line)])
			for mv in moves:
				var sim := gs.clone()
				var penalty := 0.0
				if mv[0] is String:
					sim.apply_bonus(str(mv[0]), sim.fields[int(mv[1])], mv[2])
					penalty = 4.0
				else:
					sim.apply_rotation(int(mv[0]), int(mv[1]), int(mv[2]))
				var r := sim.end_round()
				var score: float = int(r["gain"]) - penalty
				if sim.lives < gs.lives:
					score -= 60.0
				for f in sim.fields:
					if f.burning:
						score -= 3.0
				if sim.is_over():
					score -= 10000.0
				if score > best_score:
					best_score = score
					best = mv
		if best[0] is String:
			gs.apply_bonus(str(best[0]), gs.fields[int(best[1])], best[2])
			bonuses += 1
		elif not passive:
			gs.apply_rotation(int(best[0]), int(best[1]), int(best[2]))
		var r2 := gs.end_round()
		if not _disaster_of(r2).is_empty() and str(_disaster_of(r2)["kind"]) == "fire":
			fires += 1
		if gs.is_over():
			break
	var counts := []
	for st in range(0, Balance.MAX_STAGE + 1):
		counts.append(gs.count(st))
	return {"rounds": gs.turn - 1, "score": gs.score, "best": gs.best_stage, "bonuses": bonuses, "fires": fires,
		"disasters": gs.disasters, "civ": gs.civilisation_share(), "counts": counts, "dead": gs.died()}


func test_bot() -> void:
	var saved := Balance.FIRE_COSTS_LIFE
	for costs in [true, false]:
		Balance.FIRE_COSTS_LIFE = costs
		print("--- Brand kostet ein Leben: %s ---" % ("ja" if costs else "nein"))
		for sd in [11, 22, 33]:
			var b := run_bot(sd, false, 100)
			print("  Bot Seed %d: %d Runden, %d Punkte, Entwicklung %s, Boni %d, Brände %d, Katastrophen %d, Zivilisation %.0f%%, Stufen %s" % [
				sd, int(b["rounds"]), int(b["score"]), GameState.stage_name(int(b["best"])), int(b["bonuses"]), int(b["fires"]),
				int(b["disasters"]), float(b["civ"]) * 100.0, str(b["counts"])])
	Balance.FIRE_COSTS_LIFE = saved
	var passive := run_bot(11, true, 40)
	check(int(passive["score"]) == 0, "Nichtstun bringt keine Punkte")


func test_modes() -> void:
	var gs := GameState.new()
	gs.setup(5, true)
	check(gs.age() == 1 and gs.age_name() == "Urzeit", "Start in der Urzeit")
	var names := []
	for st in range(1, Balance.MAX_STAGE + 1):
		gs.best_stage = st
		names.append(gs.age_name())
	check(names[3] == "Steinzeit" and names[4] == "Antike" and names[5] == "Mittelalter" and names[6] == "Neuzeit" and names[8] == "Moderne", "Zeitalter folgen der höchsten Stufe (%s)" % str(names))
	gs.turn = 999
	check(not gs.finished(), "Endlos endet nicht nach Runden")
	var ch := GameState.new()
	ch.setup(5, false)
	ch.turn = Balance.MAX_ROUNDS + 1
	check(ch.finished(), "40-Runden-Modus endet")
