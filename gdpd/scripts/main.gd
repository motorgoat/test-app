extends Node
## Hauptszene: baut Welt und Oberfläche auf und skaliert die Oberfläche passend zum Bildschirm.
## Mit „-- --shots=ORDNER“ gestartet, macht das Spiel eine Reihe Screenshots und beendet sich.

const BASE_SHORT_SIDE := 600.0   # logische Pixel an der kurzen Bildschirmseite (Handy zuerst)

var world: World
var ui: GameUI
var _last_miss_why := "-"      # Screenshots: Grund des letzten Fehlversuchs ("", "repeat" oder "spent")


func _ready() -> void:
	_apply_scale()
	get_tree().root.size_changed.connect(_apply_scale)
	world = World.new()
	world.name = "World"
	add_child(world)
	ui = GameUI.new()
	ui.name = "UI"
	add_child(ui)
	ui.setup(world)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots(a.substr(8))


func _apply_scale() -> void:
	var win := get_tree().root
	var s := win.size
	var f := clampf(minf(float(s.x), float(s.y)) / BASE_SHORT_SIDE, 1.0, 3.0)
	if absf(win.content_scale_factor - f) > 0.01:
		win.content_scale_factor = f


# =============================================================================
# Automatische Screenshots (für die Prüfung in der GitHub-Action)
# Jede Prüfung druckt eine Zeile „CHECK ok=<true|false> name=<…>“. Der Build scheitert an ok=false.
# =============================================================================

var _seen := {}                 # Signale der Welt, die während der Tour kamen (war, smog, wish, punish)


func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	# Software-Grafik ist langsam: Antippen darf nie als Halten zählen (Würfel und Oberfläche)
	Balance.HOLD_TO_ORBIT_SECONDS = 30.0
	ui.long_press = 2.5
	world.war_shown.connect(_note.bind("war"))
	world.smog_shown.connect(_note2.bind("smog"))
	world.wish_done_shown.connect(_note2.bind("wish"))
	world.punish_shown.connect(_note3.bind("punish"))
	world.miss_shown.connect(_on_tour_miss)
	await _tutorial_tour(dir)
	ui.debug_close_all()
	ui.debug_reveal_all()          # ab hier wie ein Spieler, der schon alles kennt
	await _rain_check(dir)
	await _merge_check()
	await _choice_tour(dir)
	await _kinds_tour(dir)
	await _war_tour(dir)
	await _smog_tour(dir)
	await _wish_tour(dir)
	await _punish_tour(dir)
	ui.debug_close_all()
	ui.debug_show_help()
	await _wait(0.8)
	await _shot(dir, "15_hilfe")
	ui.debug_close_all()
	ui._open_menu()
	await _wait(0.8)
	await _shot(dir, "16_menue")
	ui.debug_close_all()
	await _complete_tour(dir)
	await _burn_tour(dir)
	# Letzte Zeile: Die Action prüft, dass die Tour ganz durchlief (sonst sind Bilder und Prüfungen unvollständig)
	print("TOUR-DONE checks=%d failed=%d" % [_checks, _failed])
	get_tree().quit()


func _note(_a: Variant, _b: Variant, key: String) -> void:
	_seen[key] = int(_seen.get(key, 0)) + 1


func _note2(_a: Variant, _b: Variant, key: String) -> void:
	_seen[key] = int(_seen.get(key, 0)) + 1


func _note3(_a: Variant, _b: Variant, _c: Variant, key: String) -> void:
	_seen[key] = int(_seen.get(key, 0)) + 1


var _checks := 0
var _failed := 0


func _check(ok: bool, check_name: String, extra: String = "") -> void:
	_checks += 1
	if not ok:
		_failed += 1
	print("CHECK ok=%s name=%s %s" % [str(ok), check_name, extra])


# --- Tutorial: erster Zug von selbst, dann die erste Wahl mit der Hand, dann selbst drehen ---------------

func _tutorial_tour(dir: String) -> void:
	Game.restart_tutorial()
	await _wait(1.0)
	await _shot(dir, "00a_tutorial_start")
	# Der erste Zug läuft von selbst: die Reihe leuchtet, ein „?“ steht über dem neuen Feld
	var got := await _until_choice(10.0)
	await _wait(0.15)
	await _shot(dir, "00b_auto_zug")
	var card1 := await _until_card(4.0)
	await _wait(1.4)              # die Hand zeigt auf beide Möglichkeiten
	await _shot(dir, "00c_erste_wahl")
	var fid1 := int(ui._choice.get("field", -1))
	var hand := ui.tut_finger.modulate.a > 0.5
	# Tutorial: Tippen daneben lässt die Karte nur wackeln (sie wartet auf eine Wahl)
	await _touch(_outside_card())
	await _wait(0.4)
	var waits := Game.has_choice() and ui.choice_card.visible
	# Echte Eingabe: „Acker“ antippen
	await _touch(_btn_center(1))
	await _wait(0.4)
	await _settle(8.0)
	var k1 := (Game.state.fields[fid1] as FieldData).kind if fid1 >= 0 else -1
	var step1 := Game.tutorial_step
	_check(got and card1 and hand and waits and k1 == FieldData.FIELD and step1 == 1, "tutorial_choice",
		"card=%s hand=%s waits=%s kind=%d step=%d" % [str(card1), str(hand), str(waits), k1, step1])
	# Schritt 2: der eigene Zug (hier vom Skript gespielt), die Karte kommt wieder: freie Wahl (Wald)
	await _wait(1.0)
	await _shot(dir, "00d_jetzt_du")
	for i in 30:
		if not Game.tutorial() or world.auto_twist(0, 1, 1):
			break
		await _wait(0.2)
	var card2 := await _until_card(8.0)
	var fid2 := int(ui._choice.get("field", -1))
	await _touch(_btn_center(0))
	await _wait(0.3)
	await _settle(8.0)
	var k2 := (Game.state.fields[fid2] as FieldData).kind if fid2 >= 0 else -1
	await _wait(1.6)
	if Game.tutorial():
		push_warning("Screenshots: Tutorial lief nicht durch, beende es direkt")
		Game.finish_tutorial()
	await _wait(1.0)
	await _shot(dir, "00e_nach_tutorial")
	_check(card2 and k2 == FieldData.FOREST and not Game.tutorial() and Game.state.count(FieldData.EMPTY) < 34, "tutorial",
		"card=%s kind=%d tutorial=%s erde=%d glaube=%d" % [str(card2), k2, str(Game.tutorial()), Game.state.count(FieldData.EMPTY), Game.state.faith])
	ui.debug_show_tooltip("rain")
	await _wait(0.6)
	await _shot(dir, "00f_erklaerung")
	ui.debug_close_all()


# --- Wahl im normalen Spiel: antippen, daneben tippen, warten, kleine Pille ------------------------------

## Brett für eine Wiesen-Reihe oben: zwei Wiesen liegen oben, die dritte kommt mit der Drehung x = 1.
func _meadow_board(seed_value: int) -> bool:
	var fixed := [[Vector3i(-1, 1, 1), Vector3i(0, 1, 0), FieldData.MEADOW], [Vector3i(0, 1, 1), Vector3i(0, 1, 0), FieldData.MEADOW],
		[Vector3i(1, 1, -1), Vector3i(0, 0, -1), FieldData.MEADOW]]
	return _prepare(seed_value, fixed, _twist(0, 1, 1), _want_meadow_card)


func _want_meadow_card(sim: Dictionary) -> bool:
	var st: GameState = sim["state"]
	return st.card == FieldData.MEADOW and _count_events(sim["result"], "choice") <= 1 and not _has_event(sim["result"], "war")


func _choice_tour(dir: String) -> void:
	ui.debug_close_all()
	Game.new_game(5151, 1, 1)
	Game.cards_seen = {}
	Game.always_ask = false
	await _wait(1.2)
	# 1. Antippen (echte Eingabe): Acker statt Wald
	var ok_board := _meadow_board(11)
	world.focus_place(Vector3i(0, 1, 0))
	await _wait(1.0)
	world.auto_twist(0, 1, 1)
	var card := await _until_card(6.0)
	await _wait(0.5)
	await _shot(dir, "01_wahl")
	var fid := int(ui._choice.get("field", -1))
	# Halten erklärt eine Möglichkeit (die Karte bleibt offen, die Zeit steht)
	var tip_ok := await _hold_check(_btn_center(1))
	await _shot(dir, "02_wahl_erklaerung")
	await _wait(0.6)
	await _touch(_btn_center(1))
	await _settle(8.0)
	var k := (Game.state.fields[fid] as FieldData).kind if fid >= 0 else -1
	_check(ok_board and card and k == FieldData.FIELD and Game.state.habit(FieldData.MEADOW) == 1 and not Game.busy, "choice",
		"board=%s card=%s kind=%d habit=%d" % [str(ok_board), str(card), k, Game.state.habit(FieldData.MEADOW)])
	_check(tip_ok, "choice_longpress")
	await _wait(0.6)
	await _shot(dir, "03_nach_wahl")
	# 2. Daneben tippen: deine letzte Wahl gilt (jetzt Acker)
	_meadow_board(12)
	await _wait(0.8)
	world.auto_twist(0, 1, 1)
	card = await _until_card(6.0)
	fid = int(ui._choice.get("field", -1))
	await _touch(_outside_card())
	await _settle(8.0)
	k = (Game.state.fields[fid] as FieldData).kind if fid >= 0 else -1
	_check(card and k == FieldData.FIELD and not Game.has_choice(), "choice_outside", "kind=%d" % k)
	# 3. Nichts tun: Nach der Zeit gilt die Gewohnheit, nichts hängt
	_meadow_board(13)
	await _wait(0.8)
	world.auto_twist(0, 1, 1)
	card = await _until_card(6.0)
	fid = int(ui._choice.get("field", -1))
	var gone := false
	var waited := 0.0
	for i in 140:
		await _wait(0.1)
		waited += 0.1
		if not Game.has_choice():
			gone = true
			break
	await _settle(8.0)
	k = (Game.state.fields[fid] as FieldData).kind if fid >= 0 else -1
	_check(card and gone and k == FieldData.FIELD, "choice_timeout", "kind=%d sec=%.1f" % [k, waited])
	# 4. Ab der vierten Wiesen-Wahl: die kleine Pille über dem Feld (nimmt nach 2 s die Gewohnheit)
	_meadow_board(14)
	await _wait(0.8)
	world.auto_twist(0, 1, 1)
	var pill := false
	for i in 60:
		await _wait(0.05)
		if ui.mini_pill.visible and ui.mini_pill.modulate.a > 0.9:
			pill = true
			break
	await _shot(dir, "04_mini_wahl")
	fid = int(ui._choice.get("field", -1))
	await _settle(8.0)
	k = (Game.state.fields[fid] as FieldData).kind if fid >= 0 else -1
	_check(pill and not Game.has_choice() and k == FieldData.FIELD, "choice_mini", "pill=%s kind=%d" % [str(pill), k])


## Lange auf einen Punkt drücken (echte Eingabe): Die Erklärung erscheint, die Wahl bleibt offen.
func _hold_check(p: Vector2) -> bool:
	var wp: Vector2 = get_tree().root.get_final_transform() * p
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = wp
	t.pressed = true
	Input.parse_input_event(t)
	var shown := false
	for i in 80:
		await _wait(0.05)
		if ui.tip_card.visible and ui.tip_card.modulate.a > 0.9:
			shown = true
			break
	await _wait(0.3)
	var still := Game.has_choice() and ui.choice_card.visible
	var title := ui.tip_title.text
	var r := InputEventScreenTouch.new()
	r.index = 0
	r.position = wp
	r.pressed = false
	Input.parse_input_event(r)
	await get_tree().process_frame
	await get_tree().process_frame
	await _wait(0.2)
	var still2 := Game.has_choice()
	return shown and still and still2 and title == FieldData.kind_name(FieldData.FIELD)


# --- Alle neuen Arten auf einen Blick ---------------------------------------------------------------------

func _kinds_tour(dir: String) -> void:
	ui.debug_close_all()
	Game.new_game(6161, 1, 1)
	await _wait(1.0)
	var gs := Game.state
	var top := [FieldData.ANIMALS, FieldData.FOREST, FieldData.FIELD, FieldData.BIGFOREST, FieldData.CHURCH, FieldData.HUT,
		FieldData.PARADISE, FieldData.MEADOW, FieldData.VILLAGE]
	var front := [FieldData.FIELD, FieldData.HOUSE, FieldData.TOWN, FieldData.MEADOW, FieldData.INDUSTRY, FieldData.BIGCITY,
		FieldData.FOREST, FieldData.FIELD, FieldData.METROPOLIS]
	var right := [FieldData.BIGFOREST, FieldData.ANIMALS, FieldData.MEADOW, FieldData.FOREST, FieldData.HUT, FieldData.FIELD,
		FieldData.MEADOW, FieldData.VILLAGE, FieldData.FOREST]
	_paint_face(Vector3i(0, 1, 0), top)
	_paint_face(Vector3i(0, 0, 1), front)
	_paint_face(Vector3i(1, 0, 0), right)
	gs.ever[FieldData.CHURCH] = true
	gs.ever[FieldData.INDUSTRY] = true
	Game.state_changed.emit()
	world.focus_place(Vector3i(0, 1, 0))
	await _wait(1.6)
	await _shot(dir, "05_arten")
	var church := -1
	for f in gs.fields:
		if (f as FieldData).kind == FieldData.CHURCH:
			church = (f as FieldData).id
	var pos := world.field_screen(church)
	await _touch(pos["pos"])
	await _wait(0.7)
	var ok := ui.sheet.visible and ui.sheet_title.text == "Kirche"
	_check(ok, "field_sheet", "title=%s" % ui.sheet_title.text)
	await _shot(dir, "06_feld_info")
	ui.debug_close_all()


## Eine Seite bemalen: 9 Arten, Reihe für Reihe (so wie face_fields sie liefert).
func _paint_face(n: Vector3i, kinds: Array) -> void:
	var ff: Array = Game.state.face_fields(n)
	for i in mini(ff.size(), kinds.size()):
		var f: FieldData = ff[i]
		f.kind = int(kinds[i])
		f.fresh = 0
		f.burning = false


# --- Krieg: Zwei Kirchen treffen sich durch eine Drehung --------------------------------------------------

func _want_war(sim: Dictionary) -> bool:
	return _has_event(sim["result"], "war") and (sim["state"] as GameState).card < 0


func _war_tour(dir: String) -> void:
	ui.debug_close_all()
	Game.new_game(7171, 1, 1)
	await _wait(1.0)
	var fixed := [[Vector3i(0, 1, 1), Vector3i(0, 1, 0), FieldData.CHURCH], [Vector3i(1, 1, -1), Vector3i(0, 0, -1), FieldData.CHURCH]]
	var ok_board := _prepare(21, fixed, _twist(0, 1, 1), _want_war)
	var gs := Game.state
	gs.faith = 240
	gs.ever[FieldData.CHURCH] = true
	Game.state_changed.emit()
	var a := gs.field_at(Vector3i(0, 1, 1), Vector3i(0, 1, 0))
	var b := gs.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1))
	world.focus_place(Vector3i(0, 1, 0))
	await _wait(1.2)
	# Die Vorschau beim Ziehen kennt den Krieg schon (gekreuzte Schwerter über den Kirchen)
	var pv: Dictionary = Game.preview(0, 1, 1)
	var swords := not (pv["war"] as Array).is_empty()
	_seen.erase("war")
	var f0 := gs.faith
	world.auto_twist(0, 1, 1)
	for i in 120:
		await _wait(0.05)
		if _seen.has("war"):
			break
	await _wait(0.35)
	await _shot(dir, "07_krieg")
	await _settle(8.0)
	await _wait(0.6)
	var loss := f0 - Game.state.faith
	var ok := ok_board and swords and _seen.has("war") and a.kind == FieldData.HOUSE and b.kind == FieldData.HOUSE and loss >= Balance.WAR_FAITH_MIN
	_check(ok, "war", "board=%s swords=%s a=%d b=%d loss=%d" % [str(ok_board), str(swords), a.kind, b.kind, loss])


# --- Smog: zu viel Industrie, der Wald daneben welkt ------------------------------------------------------

func _smog_tour(dir: String) -> void:
	ui.debug_close_all()
	Game.new_game(8181, 1, 1)
	await _wait(1.0)
	var gs := Game.state
	var pal := [FieldData.INDUSTRY, FieldData.TOWN, FieldData.BIGCITY, FieldData.INDUSTRY, FieldData.HOUSE, FieldData.METROPOLIS,
		FieldData.VILLAGE, FieldData.INDUSTRY, FieldData.TOWN]
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for f in gs.fields:
		(f as FieldData).kind = int(pal[rng.randi() % pal.size()])
		(f as FieldData).fresh = 0
		(f as FieldData).burning = false
	# Oben: Wald und Tiere zwischen den Fabriken
	_paint_face(Vector3i(0, 1, 0), [FieldData.INDUSTRY, FieldData.FOREST, FieldData.TOWN, FieldData.ANIMALS, FieldData.INDUSTRY,
		FieldData.BIGFOREST, FieldData.TOWN, FieldData.FOREST, FieldData.INDUSTRY])
	gs.wishes = []
	gs.ever[FieldData.INDUSTRY] = true
	gs.faith = 300
	Game.state_changed.emit()
	world.focus_place(Vector3i(0, 1, 0))
	await _wait(1.2)
	var w0 := gs.balance()
	var nat0 := 0
	for f in gs.face_fields(Vector3i(0, 1, 0)):
		nat0 += FieldData.tier(f.kind) if f.is_nature() else 0
	_seen.erase("smog")
	# Eine Drehung unten (y = −1): oben bleibt alles, wo es ist
	world.auto_twist(1, -1, 1)
	for i in 120:
		await _wait(0.05)
		if _seen.has("smog"):
			break
	await _wait(0.9)
	await _shot(dir, "08_smog")
	await _settle(8.0)
	var nat1 := 0
	for f in gs.face_fields(Vector3i(0, 1, 0)):
		nat1 += FieldData.tier(f.kind) if f.is_nature() else 0
	_check(w0 >= Balance.SMOG_AT and _seen.has("smog") and nat1 < nat0 and gs.tool_unlocked("flood"), "smog",
		"w=%d natur=%d->%d flut=%s" % [w0, nat0, nat1, str(gs.tool_unlocked("flood"))])


# --- Wunsch: eine Hütte wünscht sich Wald, die Drehung bringt ihn -----------------------------------------

func _want_wish(sim: Dictionary) -> bool:
	return _has_event(sim["result"], "wish_done") and (sim["state"] as GameState).card < 0 and not _has_event(sim["result"], "war")


func _wish_tour(dir: String) -> void:
	ui.debug_close_all()
	Game.new_game(9191, 1, 1)
	await _wait(1.0)
	var gs := Game.state
	var hut := gs.field_at(Vector3i(0, 1, 1), Vector3i(0, 1, 0))
	gs.wishes = [{"id": 900, "type": "wald", "field": hut.id, "left": 6}]
	gs.wish_seq = 901
	var fixed := [[Vector3i(0, 1, 1), Vector3i(0, 1, 0), FieldData.HUT], [Vector3i(1, 1, -1), Vector3i(0, 0, -1), FieldData.FOREST]]
	var ok_board := _prepare(31, fixed, _twist(0, 1, 1), _want_wish)
	gs.wishes = [{"id": 900, "type": "wald", "field": hut.id, "left": 6}]
	gs.ever[FieldData.HOUSE] = true
	gs.monsoon_unlocked = true
	gs.monsoons = 1
	gs.misses = 0
	gs.faith = 120
	Game.state_changed.emit()
	world.focus_place(Vector3i(0, 1, 0))
	await _wait(2.4)
	# Der erste Wunsch: eine Pille, dann zeigt ein Hinweis auf die Blase (blockiert nichts)
	Game.coach_seen.erase("wish")
	ui._coach_queue.clear()
	ui._coach_twist = -1
	ui._coach_ready_at = 0.0
	ui._on_wish_made(hut.id)
	var coach := false
	for i in 100:
		await _wait(0.05)
		if ui.coach.visible and ui.coach.modulate.a > 0.95:
			coach = true
			break
	var bubble: Dictionary = world.wish_screen(hut.id)
	await _shot(dir, "09_wunsch")
	# Der Hinweis sagt, WAS die Menschen wollen, und die echte Zahl der Drehungen (wie der Ring an der Blase)
	_check(coach and ui.coach_label.text.begins_with(str(GameState.WISH_TEXT["wald"])) and ui.coach_label.text.contains("6 Drehungen"),
		"coach_wish", "text=%s" % ui.coach_label.text.left(60))
	ui._coach_dismiss()
	await _wait(0.4)
	var f0 := gs.faith
	_seen.erase("wish")
	world.auto_twist(0, 1, 1)
	for i in 120:
		await _wait(0.05)
		if _seen.has("wish"):
			break
	await _wait(0.5)
	await _shot(dir, "10_wunsch_erfuellt")
	await _settle(8.0)
	var ok := ok_board and bool(bubble["visible"]) and _seen.has("wish") and gs.wishes.is_empty() and hut.kind == FieldData.HOUSE and gs.faith - f0 >= Balance.WISH_FAITH and gs.misses == 0
	_check(ok, "wish", "board=%s bubble=%s kind=%d faith=%d misses=%d" % [str(ok_board), str(bubble["visible"]), hut.kind, gs.faith - f0, gs.misses])


# --- Strafen: Gewitter auf eine Fabrik, Flut über eine Stadtseite (echte Eingabe) -------------------------

func _punish_tour(dir: String) -> void:
	ui.debug_close_all()
	Game.new_game(1212, 1, 1)
	await _wait(1.0)
	var gs := Game.state
	_paint_face(Vector3i(0, 1, 0), [FieldData.FOREST, FieldData.TOWN, FieldData.MEADOW, FieldData.HOUSE, FieldData.INDUSTRY,
		FieldData.FIELD, FieldData.BIGFOREST, FieldData.VILLAGE, FieldData.FOREST])
	_paint_face(Vector3i(0, 0, 1), [FieldData.TOWN, FieldData.BIGCITY, FieldData.HOUSE, FieldData.INDUSTRY, FieldData.TOWN,
		FieldData.METROPOLIS, FieldData.FIELD, FieldData.MEADOW, FieldData.HUT])
	var ind := gs.field_at(Vector3i(0, 1, 0), Vector3i(0, 1, 0))
	ind.kind = FieldData.INDUSTRY
	gs.field_at(Vector3i(0, 0, 1), Vector3i(0, 0, 1)).kind = FieldData.TOWN
	gs.ever[FieldData.INDUSTRY] = true
	gs.stats["smog"] = 1
	gs.faith = 160
	gs.wishes = []
	Game.state_changed.emit()
	world.focus_place(Vector3i(0, 1, 0))
	await _wait(1.4)
	# 1. Gewitter in der Leiste antippen: Felder leuchten
	await _touch(ui.strike_btn.get_global_rect().get_center())
	await _wait(0.7)
	var sel := ui.bonus_mode == "strike"
	await _shot(dir, "11_strafe_ziel")
	# 2. Die Fabrik antippen: Sie leuchtet, die Karte fragt nach
	var fs := world.field_screen(ind.id)
	await _touch(fs["pos"])
	await _wait(0.6)
	var asked := ui._pick == ind.id and ind.kind == FieldData.INDUSTRY
	await _shot(dir, "12_strafe_bestaetigen")
	# 3. Noch einmal tippen: Der Blitz schlägt ein
	var f0 := gs.faith
	_seen.erase("punish")
	await _touch(fs["pos"])
	for i in 80:
		await _wait(0.05)
		if _seen.has("punish"):
			break
	await _wait(0.3)
	await _shot(dir, "13_gewitter")
	await _settle(8.0)
	var ok := sel and asked and ind.kind == FieldData.EMPTY and f0 - gs.faith == Balance.STRIKE_COST
	_check(ok, "strike", "sel=%s asked=%s kind=%d cost=%d" % [str(sel), str(asked), ind.kind, f0 - gs.faith])
	# Flut über die vordere Seite
	world.focus_place(Vector3i(0, 0, 1))
	await _wait(1.2)
	var town := gs.field_at(Vector3i(0, 0, 1), Vector3i(0, 0, 1))
	var civ0 := 0
	for f in gs.face_fields(Vector3i(0, 0, 1)):
		civ0 += int(Balance.CIV_WEIGHT.get(f.kind, 0))
	await _touch(ui.flood_btn.get_global_rect().get_center())
	await _wait(0.6)
	var fs2 := world.field_screen(town.id)
	await _touch(fs2["pos"])
	await _wait(0.5)
	var f1 := gs.faith
	_seen.erase("punish")
	await _touch(fs2["pos"])
	for i in 80:
		await _wait(0.05)
		if _seen.has("punish"):
			break
	await _wait(0.6)
	await _shot(dir, "14_flut")
	await _settle(8.0)
	var civ1 := 0
	for f in gs.face_fields(Vector3i(0, 0, 1)):
		civ1 += int(Balance.CIV_WEIGHT.get(f.kind, 0))
	_check(civ1 < civ0 and f1 - gs.faith == Balance.FLOOD_COST, "flood", "stadt=%d->%d cost=%d" % [civ0, civ1, f1 - gs.faith])


# --- Spielende: vollendet und verbrannt ---------------------------------------------------------------------

func _complete_tour(dir: String) -> void:
	Game.new_game(1313, 1, 1)
	await _wait(1.0)
	var gs := Game.state
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var pal := [FieldData.PARADISE, FieldData.PARADISE, FieldData.METROPOLIS, FieldData.PARADISE, FieldData.INDUSTRY,
		FieldData.METROPOLIS, FieldData.FOREST, FieldData.HOUSE, FieldData.PARADISE]
	for f in gs.fields:
		(f as FieldData).kind = int(pal[rng.randi() % pal.size()])
		(f as FieldData).fresh = 0
	gs.wishes = []
	gs.faith = 1800
	Game.state_changed.emit()
	await _wait(1.0)
	var w := gs.balance()
	world.auto_twist(1, -1, 1)
	for i in 160:
		await _wait(0.05)
		if Game.over and ui.over_card.visible:
			break
	await _wait(1.4)
	await _shot(dir, "17_vollendet")
	_check(gs.completed and Game.over and ui.over_title.text == "Deine Welt ist vollendet!", "complete",
		"fertig=%d w=%d" % [gs.finished_count(), w])
	ui.debug_close_all()


func _burn_tour(dir: String) -> void:
	Game.new_game(777, 1, 1)
	await _wait(1.0)
	var gs := Game.state
	var face: Vector3i = (gs.fields[_visible_field()] as FieldData).n
	var kinds := [FieldData.MEADOW, FieldData.FOREST, FieldData.FIELD, FieldData.BIGFOREST, FieldData.HUT, FieldData.HOUSE,
		FieldData.VILLAGE, FieldData.TOWN, FieldData.BIGCITY]
	for f in gs.fields:
		(f as FieldData).kind = FieldData.EMPTY
	_paint_face(face, kinds)
	gs.misses = Balance.FIRE_AFTER - 1
	gs.lives = 1
	gs.rain = 0
	gs.bolts = 0
	gs.wishes = []
	gs.faith = 420
	Game.state_changed.emit()
	await _wait(0.8)
	world.debug_begin_twist(_visible_field(), Vector2(1, 0.15), 0.62)
	await _wait(1.0)
	await _shot(dir, "18_brand_vorschau")
	world.debug_end_twist()
	for i in 200:
		await _wait(0.05)
		if Game.over and ui.over_card.visible:
			break
	await _wait(1.4)
	await _shot(dir, "19_ende")
	_check(Game.over and gs.died(), "game_over", "herzen=%d" % gs.lives)


# =============================================================================
# Prüfung mit echter Eingabe (Input.parse_input_event, wie Finger am Handy)
# =============================================================================

## Ein Finger tippt auf p (Koordinaten der Oberfläche). Wie am Handy: ScreenTouch, daraus macht Godot
## die Maus (input_devices/pointing/emulate_mouse_from_touch). Geht durch Oberfläche und 3D-Ansicht.
func _touch(p: Vector2, hold: float = 0.08) -> void:
	var wp: Vector2 = get_tree().root.get_final_transform() * p
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = wp
	t.pressed = true
	Input.parse_input_event(t)
	await get_tree().process_frame
	await get_tree().process_frame
	await _wait(hold)
	var r := InputEventScreenTouch.new()
	r.index = 0
	r.position = wp
	r.pressed = false
	Input.parse_input_event(r)
	await get_tree().process_frame
	await get_tree().process_frame


## Mitte eines Knopfs der Wahl-Karte (0 = erste Möglichkeit).
func _btn_center(i: int) -> Vector2:
	return (ui.choice_btns[i] as Control).get_global_rect().get_center()


## Ein Punkt neben der Wahl-Karte (dort, wo mehr Platz ist).
func _outside_card() -> Vector2:
	var r := ui.choice_card.get_global_rect()
	var vs := get_viewport().get_visible_rect().size
	if r.position.y > vs.y - r.end.y:
		return Vector2(vs.x * 0.5, r.position.y * 0.6)
	return Vector2(vs.x * 0.5, r.end.y + (vs.y - r.end.y) * 0.4)


## Warten, bis Game eine Wahl braucht.
func _until_choice(sec: float) -> bool:
	var t := 0.0
	while t < sec:
		if Game.has_choice():
			return true
		await _wait(0.05)
		t += 0.05
	return false


## Warten, bis die große Wahl-Karte ganz zu sehen ist.
func _until_card(sec: float) -> bool:
	var t := 0.0
	while t < sec:
		if Game.has_choice() and ui.choice_card.visible and ui.choice_card.modulate.a > 0.98:
			await _wait(0.35)
			return true
		await _wait(0.05)
		t += 0.05
	return false


## Liegt dieser Punkt unter der Oberfläche (Leiste, Karte, oben)?
func _under_ui(pos: Vector2) -> bool:
	var rects: Array = [ui.dock.get_global_rect().grow(12.0), ui.top.get_global_rect().grow(12.0)]
	for c in [ui.mode_card, ui.toast, ui.tip_card, ui.coach]:
		var cc: Control = c
		if cc.visible:
			rects.append(cc.get_global_rect().grow(12.0))
	for r in rects:
		var rr: Rect2 = r
		if rr.has_point(pos):
			return true
	return false


## Ein sichtbares Feld, das man antippen kann. want: "target" = ein Regenziel, "other" = keins. {"fid", "pos"}
func _rain_target(want: String = "target", skip: int = -1) -> Dictionary:
	var tg := Game.state.rain_targets()
	var mid := get_viewport().get_visible_rect().size * 0.5
	var best := -1
	var best_pos := Vector2.ZERO
	var best_d := INF
	for f in Game.state.fields:
		var fid: int = (f as FieldData).id
		if fid == skip or tg.has(fid) != (want == "target"):
			continue
		if want == "target" and not Game.state.choice_for({"type": "rain", "field": fid}).is_empty():
			continue      # dieser Regen brächte eine Wahl (die Prüfung will nur gießen)
		var fs := world.field_screen(fid)
		if not bool(fs["visible"]):
			continue
		var pos: Vector2 = fs["pos"]
		if _under_ui(pos):
			continue
		var hit: Dictionary = world._raycast(pos)
		if int(hit.get("field", -1)) != fid:
			continue
		var d := pos.distance_to(mid)
		if d < best_d:
			best_d = d
			best = fid
			best_pos = pos
	return {"fid": best, "pos": best_pos}


func _rain_check(dir: String) -> void:
	Game.new_game(4242, 1, 0)
	ui.debug_close_all()
	await _wait(1.6)
	Game.state.rain = 3
	Game.state.wishes = []
	Game.state_changed.emit()
	await _wait(0.8)
	# 1. Regen in der Leiste antippen: Der Regen ist gewählt, Felder leuchten
	await _touch(ui.rain_btn.get_global_rect().get_center())
	await _wait(0.6)
	var mode_ok := ui.bonus_mode == "rain" and ui.mode_card.visible
	await _shot(dir, "00g_regen")
	# 2. Ein leuchtendes Feld antippen: Es wächst, ein Regen ist verbraucht, Regen bleibt gewählt
	var t := _rain_target()
	var fid := int(t["fid"])
	var before := -1
	var after := -1
	var rain_before := Game.state.rain
	if fid >= 0:
		before = FieldData.tier((Game.state.fields[fid] as FieldData).kind)
		await _touch(t["pos"])
		await _wait(0.5)
		await _settle(6.0)
		after = FieldData.tier((Game.state.fields[fid] as FieldData).kind)
	var ok := mode_ok and fid >= 0 and after >= before + 1 and Game.state.rain == rain_before - 1 and not Game.busy and not world.animating and ui.bonus_mode == "rain"
	_check(ok, "rain", "before=%d after=%d rain=%d mode=%s fid=%d step=leuchtendes_feld" % [before, after, Game.state.rain, ui.bonus_mode, fid])
	# 3. Ein Feld, das nicht leuchtet: Es passiert nichts, aber eine Meldung sagt, wohin der Regen geht.
	# Auf dem frischen Einfach-Würfel ist fast alles ein Regenziel: Eine Hütte an einer sichtbaren Stelle ist keins.
	await _settle(6.0)
	if int(_rain_target("other")["fid"]) < 0:
		var spot := int(_rain_target("target", fid)["fid"])
		if spot >= 0:
			(Game.state.fields[spot] as FieldData).kind = FieldData.HUT
			(Game.state.fields[spot] as FieldData).burning = false
			Game.state_changed.emit()
			await _wait(0.6)
	var w := _rain_target("other")
	var wid := int(w["fid"])
	var rain_w := Game.state.rain
	var told := false
	if wid >= 0:
		var st_w := (Game.state.fields[wid] as FieldData).kind
		await _touch(w["pos"])
		for i in 60:
			await get_tree().process_frame
			if ui.toast.visible and ui.toast_label.text.begins_with("Regen geht"):
				told = true
			for m in ui._toasts:
				if str((m as Dictionary)["text"]).begins_with("Regen geht"):
					told = true
			if told:
				break
		told = told and (Game.state.fields[wid] as FieldData).kind == st_w and Game.state.rain == rain_w
	_check(wid >= 0 and told, "rain_refused", "fid=%d rain=%d" % [wid, Game.state.rain])
	await _wait(1.0)
	# 4. Regen in der Leiste noch einmal: abgewählt
	await _settle(6.0)
	await _touch(ui.rain_btn.get_global_rect().get_center())
	await _wait(0.5)
	_check(ui.bonus_mode == "", "rain_off", "mode=%s" % ui.bonus_mode)


## Warten, bis keine Runde mehr läuft und nichts mehr animiert (höchstens sec Sekunden).
## Kommt dabei eine Wahl, die keiner erwartet, nimmt die Tour die erste Möglichkeit (echte Eingabe).
func _settle(sec: float, pick: int = 0) -> void:
	var t := 0.0
	while t < sec and (Game.busy or world.animating or ui._queued_tap >= 0):
		if pick >= 0 and Game.has_choice() and ui.choice_card.visible and ui.choice_card.modulate.a > 0.98 and not Game.tutorial():
			await _wait(0.3)
			if Game.has_choice():
				await _touch(_btn_center(pick))
		await _wait(0.1)
		t += 0.1
	await _wait(0.2)


func _on_tour_miss(_fid: int, _count: int, why: String) -> void:
	_last_miss_why = why


## Eine Drehung bildet oben eine neue Reihe aus 3 Wäldern (Mittel): Sie muss wachsen.
## Danach hin und zurück (zählt nicht) und eine Reihe mit einem anderen Feld (zählt).
func _merge_check() -> void:
	ui.debug_close_all()
	Game.new_game(4243, 1, 1)
	await _wait(1.0)
	var gs := Game.state
	for f in gs.fields:
		(f as FieldData).kind = FieldData.EMPTY
		(f as FieldData).burning = false
	gs.wishes = []
	gs.field_at(Vector3i(-1, 1, 1), Vector3i(0, 1, 0)).kind = FieldData.FOREST
	gs.field_at(Vector3i(0, 1, 1), Vector3i(0, 1, 0)).kind = FieldData.FOREST
	var third: FieldData = gs.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1))
	third.kind = FieldData.FOREST          # kommt mit der Drehung x = 1 nach oben in die Reihe
	Game.state_changed.emit()
	await _wait(0.6)
	# 1. Neue Reihe: Sie wächst (Wald → großer Wald)
	var r1 := await _merge_step(0, 1, 1)
	var ok1 := bool(r1["started"]) and int(r1["gain"]) > 0 and third.kind == FieldData.BIGFOREST and _last_miss_why == "-"
	_check(ok1, "merge", "gain=%d kind=%d why=%s step=neue_reihe" % [int(r1["gain"]), third.kind, _last_miss_why])
	# 2. Eine Reihe steht schon da; weg und wieder zurück drehen zählt nicht
	third.kind = FieldData.FOREST
	Game.state_changed.emit()
	await _wait(0.4)
	await _merge_step(0, 1, -1)
	var r3 := await _merge_step(0, 1, 1)
	var ok3 := bool(r3["started"]) and int(r3["gain"]) == 0 and _last_miss_why == "repeat"
	_check(ok3, "merge_repeat", "gain=%d why=%s step=hin_und_zurueck" % [int(r3["gain"]), _last_miss_why])
	Game.state.misses = 0


func _merge_step(axis: int, layer: int, turns: int) -> Dictionary:
	Game.state.misses = 0
	_last_miss_why = "-"
	var faith0 := Game.state.faith
	var started := false
	for i in 30:
		if world.auto_twist(axis, layer, turns):
			started = true
			break
		await _wait(0.2)
	await _wait(0.6)
	await _settle(6.0)
	return {"started": started and not Game.busy and not world.animating, "gain": Game.state.faith - faith0}


# --- Bretter bauen ------------------------------------------------------------------------------------------

func _twist(axis: int, layer: int, turns: int) -> Dictionary:
	return {"type": "twist", "axis": axis, "layer": layer, "turns": turns}


func _has_event(res: Dictionary, t: String) -> bool:
	return _count_events(res, t) > 0


func _count_events(res: Dictionary, t: String) -> int:
	var c := 0
	for e in res["events"]:
		if str((e as Dictionary)["type"]) == t:
			c += 1
	return c


## Eine hübsche, gemischte Welt: Natur und erste Siedlungen (nichts Fertiges).
func _scenic(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pal := [FieldData.MEADOW, FieldData.MEADOW, FieldData.FOREST, FieldData.FOREST, FieldData.FIELD, FieldData.BIGFOREST,
		FieldData.HUT, FieldData.HOUSE, FieldData.EMPTY, FieldData.FOREST, FieldData.MEADOW, FieldData.ANIMALS]
	for f in Game.state.fields:
		(f as FieldData).kind = int(pal[rng.randi() % pal.size()])
		(f as FieldData).fresh = 0
		(f as FieldData).burning = false


## Brett bauen: hübsch gemischt, dazu feste Felder [p, n, Art]. want(sim) prüft die geplante Aktion
## (simuliert, mit der Gewohnheit). Bis zu 80 Versuche. true = passt.
func _prepare(seed_value: int, fixed: Array, action: Dictionary, want: Callable) -> bool:
	var gs := Game.state
	gs.misses = 0
	var ok := false
	for attempt in 80:
		_scenic(seed_value * 100 + attempt)
		for fx in fixed:
			var f: FieldData = gs.field_at(fx[0], fx[1])
			f.kind = int(fx[2])
		if bool(want.call(gs.simulate(action))):
			ok = true
			break
	Game.state_changed.emit()
	return ok


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	img.save_jpg("%s/%s.jpg" % [dir, shot_name], 0.85)
	print("Screenshot: ", shot_name)


## Ein gut sichtbares Feld (zur Kamera gewandt).
func _visible_field() -> int:
	var cam_pos := world.rig.cam.global_position
	var best := 0
	var best_score := -INF
	for f in Game.state.fields:
		var v: FieldView = world.views.get(f.id)
		if v == null:
			continue
		var score := v.world_normal().dot((cam_pos - v.global_position).normalized())
		if score > best_score:
			best_score = score
			best = f.id
	return best
