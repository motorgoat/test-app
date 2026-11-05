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
	test_hint()
	test_hint_ignores_seen()
	test_start_no_ready_lines()
	test_tutorial_flow()
	test_easy()
	test_new_rows()
	test_rain_rules()
	test_preview_matches()
	test_modes()
	test_bot()
	print("")
	print("%d Prüfungen, %d Fehler" % [checks, failures])
	quit(1 if failures > 0 else 0)


## Für die reinen Regeltests: keine Katastrophe, die dazwischenfunkt.
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


func _event(r: Dictionary, kind: String) -> Dictionary:
	for e in r["events"]:
		if str(e["type"]) == kind:
			return e
	return {}


func _has_event(r: Dictionary, kind: String) -> bool:
	return not _event(r, kind).is_empty()


func _merges(r: Dictionary) -> int:
	var n := 0
	for e in r["events"]:
		if str(e["type"]) == "merge":
			n += 1
	return n


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
	# Eine Reihe, die schon dastand und nur mitgedreht wird, löst nichts aus
	var gn := empty_state()
	for x in [-1, 0, 1]:
		top(gn, x, 1).stage = 1
	gn.apply_rotation(2, 1, 1)
	check(int(gn.end_round()["gain"]) == 0, "nur neu gebildete Reihen lösen aus (mitgedreht zählt nicht)")
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
	# Regen hebt nur die aktuell niedrigste Stufe
	var gl2 := empty_state()
	gl2.rain = 2
	top(gl2, 0, 0).stage = 1
	check(gl2.can_bonus("rain", top(gl2, 0, 0)) != "", "Regen nicht auf Wiese, solange es Erde gibt")
	for fd in gl2.fields:
		if fd.stage == 0:
			fd.stage = 1
	top(gl2, 0, 0).stage = 2
	check(gl2.can_bonus("rain", top(gl2, 1, 1)) == "" and gl2.can_bonus("rain", top(gl2, 0, 0)) != "", "ohne Erde: Regen hebt Wiesen, nicht den Wald")
	gl2.apply_bonus("rain", top(gl2, 1, 1))
	check(top(gl2, 1, 1).stage == 2, "Regen: Wiese wird kleiner Wald")
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
	check(gs.lives == Balance.LIVES - 1 and not gs.died(), "Brand kostet ein Herz (noch %d)" % gs.lives)
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


func test_easy() -> void:
	var gs := GameState.new()
	gs.setup(12345, true, 0)
	for f in gs.fields:
		f.stage = 0
	# drei Wiesen über Eck (keine Reihe): lösen nichts aus
	top(gs, 0, 0).stage = 1
	top(gs, 1, 0).stage = 1
	top(gs, 1, 1).stage = 1
	gs.moved = {top(gs, 1, 1).id: true}
	check(int(gs.end_round()["gain"]) == 0, "einfacher Modus: ohne Reihe passiert nichts")
	# eine Reihe löst aus: alle gleichen, die damit zusammenhängen, steigen auf (auch die Wiese daneben)
	top(gs, -1, 0).stage = 1
	gs.moved = {top(gs, -1, 0).id: true}
	var r := gs.end_round()
	var all2 := top(gs, -1, 0).stage == 2 and top(gs, 0, 0).stage == 2 and top(gs, 1, 0).stage == 2 and top(gs, 1, 1).stage == 2
	check(int(r["gain"]) > 0 and all2, "einfacher Modus: Reihe löst aus, alle zusammenhängenden steigen auf, nichts verschwindet")
	# Hin- und Herschieben bringt nichts: dieselbe Reihe zählt nur einmal
	gs.apply_rotation(0, -1, 1)
	gs.end_round()
	gs.apply_rotation(0, -1, -1)
	var rb := gs.end_round()
	check(int(rb["gain"]) == 0 and top(gs, 0, 0).stage == 2, "einfacher Modus: hin und her bringt nichts")
	check(_has_event(rb, "repeat") and str(_event(rb, "miss").get("why", "")) == "repeat", "hin und her: die Oberfläche erfährt, warum nichts wächst")
	var r2 := gs.end_round()
	check(int(r2["gain"]) == 0, "aufgestiegene Gruppe steigt nicht von allein weiter")
	# Auch mit einem anderen Zug dazwischen: Dieselben drei Felder sind zusammen aufgestiegen, die Reihe zählt nie wieder
	# (sonst: auflösen, anderer Zug, zurückdrehen – und die ganze Gruppe steigt immer weiter)
	gs.misses = 0
	gs.apply_rotation(0, -1, 1)
	gs.end_round()
	gs.misses = 0
	gs.apply_rotation(1, -1, 1)
	gs.end_round()
	gs.misses = 0
	gs.apply_rotation(0, -1, -1)
	var r3 := gs.end_round()
	check(int(r3["gain"]) == 0 and top(gs, 0, 0).stage == 2, "einfacher Modus: zusammen aufgestiegene Reihe nach einem anderen Zug wieder zusammengedreht zählt nicht (%d)" % int(r3["gain"]))
	check(str(_event(r3, "miss").get("why", "")) == "spent", "zusammen aufgestiegene Reihe: die Oberfläche erfährt, warum nichts wächst (%s)" % str(_event(r3, "miss").get("why", "")))
	# Ein anderes Feld derselben Stufe kommt in die Reihe: neue Reihe, sie wächst
	gs.misses = 0
	var newcomer: FieldData = gs.field_at(Vector3i(-1, 0, -1), Vector3i(0, 0, -1))     # kommt mit x = -1 nach oben (-1, 0)
	newcomer.stage = 2
	newcomer.burning = false
	gs.apply_rotation(0, -1, 1)
	var r4 := gs.end_round()
	check(top(gs, -1, 0) == newcomer, "einfacher Modus: das neue Feld liegt oben in der Reihe")
	check(int(r4["gain"]) > 0 and newcomer.stage == 3 and top(gs, 0, 0).stage == 3, "einfacher Modus: Reihe mit einem anderen Feld wächst (%d)" % int(r4["gain"]))


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


## Eine Reihe, die schon dasteht, bringt nichts (auch nicht mitgedreht oder hin und zurück): Der Tipp schlägt sie nicht vor.
func test_hint_ignores_seen() -> void:
	var gs := empty_state()
	top(gs, -1, 1).stage = 2
	top(gs, 0, 1).stage = 2
	top(gs, 1, 1).stage = 2
	gs.end_round()       # die Reihe steht zu Beginn des nächsten Zugs schon da
	check(gs.best_move().is_empty(), "Tipp ignoriert Reihen, die es schon gab (%s)" % str(gs.best_move()))
	var sim := gs.clone()
	sim.moved = {}
	sim.apply_rotation(1, 1, 1)
	check(sim.merge_value() == 0, "Verschieben einer alten Reihe zählt nicht")


## Am Start nie eine fertige Reihe, auch keine schräge aus Wiesen (Einfach zählt Wiesen schräg).
func test_start_no_ready_lines() -> void:
	var bad := 0
	for sd in range(1, 61):
		for lv in [0, 1, 2]:
			var g := GameState.new()
			g.setup(sd, true, lv)
			if not g.lines().is_empty():
				bad += 1
	check(bad == 0, "Start: keine fertige Reihe in 180 Würfen (%d mit Reihe)" % bad)
	var e := GameState.new()
	e.setup(7, true, 0)
	check(e.nature_share() >= Balance.START_NATURE - 0.08, "Start Einfach: trotzdem genug Natur (%.0f%%)" % (e.nature_share() * 100.0))


## Tutorial: zwei Züge auf dem vorbereiteten Würfel, dann erblüht die Erde und man spielt weiter.
func test_tutorial_flow() -> void:
	var gs := GameState.new()
	gs.setup(4242, true, 0)
	gs.setup_tutorial_board()
	gs.no_fire = true
	check(gs.lines().is_empty(), "Tutorial-Würfel: keine fertige Reihe")
	gs.apply_rotation(0, 1, 1)
	var r1 := gs.end_round()
	check(int(r1["gain"]) > 0, "Tutorial: der vorgeführte Zug lässt etwas wachsen")
	var bm := gs.best_move()
	check(not bm.is_empty() and int(bm["steps"]) == 1 and int(bm["points"]) > 0, "Tutorial: der Tipp findet danach eine Drehung, die sofort wächst (%s)" % str(bm))
	var miss := gs.clone()
	for i in Balance.FIRE_AFTER:
		miss.apply_rotation(1, -1, 1)
		miss.end_round()
	check(miss.misses == 0 and miss.disasters == 0, "Tutorial: Fehlversuche zählen nicht, nichts brennt")
	gs.apply_rotation(0, 1, 1)
	var r2 := gs.end_round()
	check(int(r2["gain"]) > 0, "Tutorial: dieselbe Drehung noch einmal wächst wieder")
	var score_before := gs.score
	var grown := 0
	for f in gs.fields:
		if (f as FieldData).stage >= 2:
			grown += 1
	var erde_before := gs.count(0)
	gs.no_fire = false
	var bloomed := gs.fill_after_tutorial()
	check(not bloomed.is_empty(), "nach dem Tutorial: die Erde erblüht (%d neue Wiesen)" % bloomed.size())
	check(gs.count(0) < erde_before and gs.count(0) <= int(gs.fields.size() * 0.66), "nach dem Tutorial: nicht mehr fast alles Erde (%d → %d)" % [erde_before, gs.count(0)])
	check(gs.score == score_before, "nach dem Tutorial: die Punkte bleiben")
	var kept := 0
	for f in gs.fields:
		if (f as FieldData).stage >= 2:
			kept += 1
	check(kept == grown, "nach dem Tutorial: was gewachsen ist, bleibt")
	check(gs.misses == 0, "nach dem Tutorial: keine Flamme")
	# Die neuen Wiesen bilden keine Reihe (was im Tutorial gewachsen ist, darf stehen bleiben)
	var fresh := true
	for ln in gs.lines():
		for g in ln:
			if bloomed.has((g as FieldData).id):
				fresh = false
	check(fresh, "nach dem Tutorial: keine fertige neue Reihe")
	check(gs.standing.is_empty() and gs.broken.is_empty() and gs.spent.is_empty(), "nach dem Tutorial: keine Reihe ist vorgemerkt (frischer Start)")
	check(gs.rain >= Balance.RAIN_START and not gs.rain_targets().is_empty(), "nach dem Tutorial: Regen ist da (%d) und hat Ziele" % gs.rain)
	check(gs.nature_share() >= 0.3, "nach dem Tutorial: genug Natur (%.0f%%)" % (gs.nature_share() * 100.0))
	var bm2 := gs.best_move()
	check(not bm2.is_empty() and int(bm2["steps"]) == 1, "nach dem Tutorial: eine Drehung wächst sofort (%s)" % str(bm2))


## Jede neu gebildete Reihe wächst: nichts bleibt als fertige Dreierreihe stehen, ohne dass etwas passiert.
func test_new_rows() -> void:
	# Mittel: eine Drehung macht eine gerade und eine schräge Reihe, die sich ein Feld teilen (das nicht bewegt wurde)
	var gm := GameState.new()
	gm.setup(12345, true, 1)
	for f in gm.fields:
		f.stage = 0
	top(gm, -1, 1).stage = 2
	top(gm, 0, 1).stage = 2
	top(gm, 0, 0).stage = 2
	gm.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1)).stage = 2     # kommt nach oben (1, 1)
	gm.field_at(Vector3i(1, -1, -1), Vector3i(0, 0, -1)).stage = 2    # kommt nach oben (1, -1)
	gm.apply_rotation(0, 1, 1)
	check(gm.lines().size() == 2, "Mittel: eine Drehung bildet zwei Reihen (%d)" % gm.lines().size())
	var rm := gm.end_round()
	check(_merges(rm) == 2 and gm.lines().is_empty(), "Mittel: beide Reihen wachsen, auch wenn sie sich ein Feld teilen (%d, übrig %d)" % [_merges(rm), gm.lines().size()])
	# Einfach: Die aufgestiegene Gruppe bildet mit alten kleinen Wäldern eine neue Reihe: Kettenreaktion
	var ge := GameState.new()
	ge.setup(12345, true, 0)
	for f in ge.fields:
		f.stage = 0
	top(ge, -1, 1).stage = 1
	top(ge, 0, 1).stage = 1
	top(ge, -1, 0).stage = 2
	top(ge, -1, -1).stage = 2
	ge.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1)).stage = 1
	ge.apply_rotation(0, 1, 1)
	var re := ge.end_round()
	check(_merges(re) == 2 and top(ge, -1, 0).stage == 3 and top(ge, -1, -1).stage == 3, "Einfach: neue Reihe aus aufgestiegenen und alten Feldern wächst weiter (%d)" % _merges(re))
	check(not _has_event(re, "miss"), "Einfach: Kettenreaktion ist kein Fehlversuch")
	# Einfach: eine schräge Reihe aus Wiesen wächst ganz (nicht nur ein Feld) und bringt Punkte
	var gd := GameState.new()
	gd.setup(12345, true, 0)
	for f in gd.fields:
		f.stage = 0
	top(gd, -1, -1).stage = 1
	top(gd, 0, 0).stage = 1
	gd.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1)).stage = 1     # kommt nach oben (1, 1)
	gd.apply_rotation(0, 1, 1)
	var rd := gd.end_round()
	check(int(rd["gain"]) > 0 and not _has_event(rd, "miss") and top(gd, -1, -1).stage == 2 and top(gd, 0, 0).stage == 2 and top(gd, 1, 1).stage == 2, "Einfach: schräge Wiesen-Reihe wächst ganz und zählt (%d Punkte)" % int(rd["gain"]))
	# Dieselben Felder an anderer Stelle neu zusammengebracht: zählt (Mittel, die ganze Reihe wandert nach vorn)
	var gp := GameState.new()
	gp.setup(12345, true, 1)
	for f in gp.fields:
		f.stage = 0
	for x in [-1, 0, 1]:
		top(gp, x, 1).stage = 2
	var gains: Array = []
	for layer in [-1, 0, 1]:
		gp.apply_rotation(0, layer, 1)
		gains.append(int(gp.end_round()["gain"]))
	check(int(gains[0]) == 0 and int(gains[1]) == 0 and int(gains[2]) > 0, "dieselben Felder an anderer Stelle wieder in einer Reihe: wächst (%s)" % str(gains))
	# Mitgedreht (die Reihe stand schon da) zählt weiterhin nicht
	var gc := GameState.new()
	gc.setup(12345, true, 1)
	for f in gc.fields:
		f.stage = 0
	for x in [-1, 0, 1]:
		top(gc, x, 1).stage = 2
	gc.apply_rotation(2, 1, 1)
	check(int(gc.end_round()["gain"]) == 0, "eine Reihe, die nur mitgedreht wird, wächst nicht")
	# Feuer: Ein Feld brennt ab und passt dann zu seinen Nachbarn: Die neue Reihe wächst gleich (wird nach dem Brand gezeigt)
	var gb := GameState.new()
	gb.setup(12345, true, 1)
	for f in gb.fields:
		f.stage = 0
	top(gb, -1, 1).stage = 2
	top(gb, 0, 1).stage = 2
	top(gb, 1, 1).stage = 3
	top(gb, 1, 1).burning = true
	var rb := gb.end_round()
	var late := false
	for e in rb["events"]:
		if str(e["type"]) == "merge" and bool(e.get("late", false)):
			late = true
	check(late and gb.lines().is_empty() and int(rb["gain"]) > 0, "durch Feuer entstandene Reihe bleibt nicht tot stehen")
	# Zufallsspiele: Nach jedem Zug steht keine neu gebildete Reihe da, die nicht gewachsen ist
	# (erlaubt: mitgedreht, sofort zurückgedreht, gerade zusammen aufgestiegen, früher zusammen aufgestiegen, Metropolen)
	for lv in [0, 1, 2]:
		var bad := 0
		var twists := 0
		for sd in [3, 4, 5]:
			var g := GameState.new()
			g.setup(sd, true, lv)
			g.no_fire = true
			g.rain = 0
			var rng := RandomNumberGenerator.new()
			rng.seed = sd * 31 + lv
			for i in 50:
				var before_pos := {}
				for pl in _lines_at(g):
					before_pos[pl] = true
				var st0 := {}
				for f in g.fields:
					st0[f.id] = (f as FieldData).stage
				var prev_broken: Dictionary = g.broken.duplicate()
				var prev_spent: Dictionary = g.spent.duplicate()
				var mv := _quick_move(g)
				if mv.is_empty() or rng.randf() < 0.4:
					mv = {"axis": rng.randi_range(0, 2), "layer": rng.randi_range(-1, 1), "turns": [1, -1, 2][rng.randi_range(0, 2)]}
				g.apply_rotation(int(mv["axis"]), int(mv["layer"]), int(mv["turns"]))
				var was_standing: Dictionary = g.standing.duplicate()
				g.end_round()
				twists += 1
				for pl in _lines_at(g):
					if before_pos.has(pl):
						continue
					var k: String = str(pl).get_slice("|", 1)
					if was_standing.has(k) or prev_broken.has(k) or prev_spent.has(k):
						continue
					var rose := true
					var maxed := false
					for ln in g.lines():
						if GameState.line_key(ln) == k:
							for h in ln:
								if (h as FieldData).stage <= int(st0[(h as FieldData).id]):
									rose = false
								if (h as FieldData).stage >= Balance.MAX_STAGE:
									maxed = true
					if not rose and not maxed:
						bad += 1
		print("  MERGE-FUZZ Stufe %d: %d Drehungen, %d tote Reihen" % [lv, twists, bad])
		check(bad == 0, "Stufe %d: keine neu gebildete Reihe bleibt ohne Wachsen stehen (%d)" % [lv, bad])


## Die erste Drehung, die sofort etwas wachsen lässt ({} = keine).
func _quick_move(g: GameState) -> Dictionary:
	for axis in 3:
		for layer in [-1, 0, 1]:
			for turns in [1, -1, 2]:
				var sim := g.clone()
				sim.moved = {}
				sim.apply_rotation(axis, layer, turns)
				if sim.merge_value() > 0:
					return {"axis": axis, "layer": layer, "turns": turns}
	return {}


## Alle Reihen mit Platz: "Seite/Linie|Schlüssel".
func _lines_at(g: GameState) -> Array:
	var out: Array = []
	for ln in g.lines():
		var pos := ""
		for h in ln:
			pos += str(GameState.pos_key((h as FieldData).p, (h as FieldData).n)) + ","
		out.append(pos + "|" + GameState.line_key(ln))
	return out


## Regen: geht auf jedes leuchtende Feld, lässt es wachsen und bleibt wählbar, solange Regen da ist.
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
	var fid0: int = int(tg.keys()[0])
	var f0: FieldData = gs.fields[fid0]
	var st0 := f0.stage
	gs.apply_bonus("rain", f0)
	gs.resolve_now()
	check(f0.stage >= st0 + 1 and gs.rain == 1, "Regen: das Feld wächst (%d → %d), ein Regen verbraucht" % [st0, f0.stage])
	check(not gs.rain_targets().is_empty(), "Regen: bleibt wählbar, solange noch Regen da ist")
	# Ein Feld, das nicht leuchtet, wird abgelehnt (mit Grund)
	var other := -1
	for f in gs.fields:
		if not gs.rain_targets().has(f.id):
			other = f.id
			break
	check(other < 0 or gs.can_bonus("rain", gs.fields[other]) != "", "Regen: nicht leuchtende Felder gehen nicht")
	# Regen, der eine Reihe fertig macht, wird als lohnend angezeigt und lässt sie wirklich wachsen
	var gl := GameState.new()
	gl.setup(12345, true, 0)
	for f in gl.fields:
		f.stage = 0
	gl.rain = 1
	top(gl, -1, 0).stage = 1
	top(gl, 0, 0).stage = 1
	check(str(gl.rain_spots().get(top(gl, 1, 0).id, "")) == "up", "Regen: das Feld, das die Reihe fertig macht, ist lohnend")
	gl.apply_bonus("rain", top(gl, 1, 0))
	var rr := gl.resolve_now()
	check(int(rr["gain"]) > 0 and top(gl, 0, 0).stage == 2, "Regen macht die Reihe fertig: sie wächst")
	# Einfach: Die drei sind zusammen aufgestiegen. Auflösen, anderer Zug, wieder zusammendrehen bringt nichts (kein Hochzüchten)
	gl.apply_rotation(0, 1, 1)
	gl.end_round()
	gl.misses = 0
	gl.apply_rotation(1, -1, 1)
	gl.end_round()
	gl.misses = 0
	gl.apply_rotation(0, 1, -1)
	var rg := gl.end_round()
	check(int(rg["gain"]) == 0 and top(gl, 0, 0).stage == 2, "durch Regen zusammen aufgestiegene Reihe zählt nicht noch einmal (%d)" % int(rg["gain"]))
	# Lohnend heißt wirklich lohnend: Jede Wolke über einem Feld bringt beim Gießen Punkte
	var gz := GameState.new()
	gz.setup(99, true, 1)
	gz.rain = 3
	var spots := gz.rain_spots()
	var lies := 0
	for fid in spots:
		if str(spots[fid]) != "up":
			continue
		var sim := gz.clone()
		sim.apply_bonus("rain", sim.fields[int(fid)])
		if int(sim.resolve_now()["gain"]) <= 0:
			lies += 1
	check(lies == 0, "Regen: jedes lohnende Feld lässt wirklich etwas wachsen (%d falsch)" % lies)


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
	var gx := empty_state()
	gx.rain = 0
	gx.bolts = 0
	top(gx, 0, 0).stage = 1
	top(gx, 1, 1).stage = 1
	check(gx.stuck() and not gx.is_over(), "nichts mehr zu verbinden: die Welt stirbt trotzdem nicht")
	gx.rain = 1
	check(not gx.stuck(), "mit Regen geht es weiter")
	var ga := empty_state()
	ga.lives = 1
	top(ga, 0, 0).stage = 4
	var ra := ga.end_round()
	check(bool(ra["new_age"]) and ga.age_name() == "Steinzeit", "erste Hütte: Steinzeit")
	# Stufen: Einfach, Mittel, Schwer – alle mit Regen, Blitz, Monsun und 3 Herzen
	for lv in [0, 1, 2]:
		var g := GameState.new()
		g.setup(5, true, lv)
		check(g.gadgets and g.rain == Balance.RAIN_START and g.lives == Balance.LIVES and g.hearts, "Stufe %d: mit Gadgets und %d Herzen" % [lv, Balance.LIVES])
	var four := GameState.new()
	four.setup(5, true, 3)
	check(four.gadgets and not four.diagonals, "es gibt keine 4. Stufe mehr (wird Schwer)")
	var hard := GameState.new()
	hard.setup(5, true, 2)
	check(hard.gadgets and not hard.diagonals and not hard.easy, "Schwer: nur gerade Reihen")
	var ch := GameState.new()
	ch.setup(5, false)
	check(not ch.finished(), "40 Drehungen: läuft noch")
	check(ch.hearts and ch.lives == Balance.LIVES and ch.diagonals and not ch.easy, "40 Drehungen: mit Herzen")
	for i in Balance.MAX_TWISTS:
		ch.apply_rotation(1, -1, 1)
		ch.end_round()
	check(ch.finished() and ch.twists == Balance.MAX_TWISTS, "nach 40 Drehungen ist Schluss")
	# Alle Modi: 3 Herzen, jeder Brand kostet eines, nach dem 3. ist die Welt tot
	for endless_mode in [true, false]:
		var sv := GameState.new()
		sv.setup(5, endless_mode, 1)
		check(sv.hearts and sv.lives == Balance.LIVES, "startet mit %d Herzen (%s)" % [Balance.LIVES, "offen" if endless_mode else "40 Drehungen"])
		for i in Balance.LIVES:
			check(not sv.is_over(), "lebt noch vor Brand %d" % (i + 1))
			sv.last_row = [0, 1, 2]
			sv.disaster("fire", [])
		check(sv.died() and sv.is_over(), "nach dem %d. Brand ist die Welt tot" % Balance.LIVES)
