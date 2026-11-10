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
	# Screenshot-Tour: Die Tour führt selbst (auch mit frischem Profil, wie in der CI): keine Ziel-Karte beim Start
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	if shots != "":
		Game.first_launch = false
	ui.setup(world)
	if shots != "":
		_shots(shots)


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

var _only := ""                 # --only=days|day1|free: nur ein Teil der Tour (zum Ausprobieren)
var _seen := {}                 # Signale der Welt, die während der Tour kamen (war, smog, wish, punish)


func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	# Software-Grafik (llvmpipe) schafft bei voller Auflösung nur 2 Bilder pro Sekunde. Die Bilder werden ohnehin
	# auf die halbe Größe verkleinert: Die 3D-Welt mit halber Auflösung rechnen (die Oberfläche bleibt scharf).
	get_viewport().scaling_3d_scale = 0.5
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	# Software-Grafik ist langsam: Antippen darf nie als Halten zählen (Würfel und Oberfläche)
	Balance.HOLD_TO_ORBIT_SECONDS = 30.0
	ui.long_press = 2.5
	world.war_shown.connect(_note.bind("war"))
	world.smog_shown.connect(_note2.bind("smog"))
	world.wish_done_shown.connect(_note2.bind("wish"))
	world.punish_shown.connect(_note3.bind("punish"))
	world.miss_shown.connect(_on_tour_miss)
	world.still_shown.connect(_on_tour_still)
	Game.level_started.connect(_note_level)
	world.tour_auto = true          # die Tour darf Züge ohne Finger spielen (das Spiel selbst nie)
	Game.rescue_on = false          # das Sicherheitsnetz nur in seiner eigenen Prüfung (level3_solvable): Züge bleiben planbar
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	_only = only
	var t0 := Time.get_ticks_msec()
	if only == "" or only == "camp":
		await _camp_tour(dir)
		print("Tour: Erdgeschichte fertig nach %.0f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if only == "acts":              # nur die Akte (Fehlersuche): frischer Fortschritt, alle Level offen
		Game.clock_override = Daily.local_unix(2026, 11, 9, 17, 40)
		Game.reset_campaign()
		Game.cards_seen = {}
		Game.coach_seen = {}
		Game.pdata = Points.fresh(Campaign.COUNT)
		Game.points = Balance.POINTS_START
		Game.debug_open_all = true
		await get_tree().process_frame
		await _acts_tour(dir)
		await _shop_tour(dir)
		await _free100_tour(dir)
		await _wdt_tour(dir)
	if only == "days" or only == "day1":
		await _days_tour(dir)
		print("Tour: Tage fertig nach %.0f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if only == "" or only == "free":
		await _free_tour(dir)
	if only == "" or only == "free" or only == "seamless":
		await _seamless_tour(dir)
	if only == "level3":            # nur Level 3 aus der eigenen Welt (Level 1–2 unordentlich gespielt) und das Netz
		await _level3_only(dir)
	if only == "bonus":             # nur die lange Bonusrunde (läuft sonst am Ende der Tage mit)
		await _bonus_round_tour(dir)
	if only == "" or only == "b12":   # Build 12: Was-jetzt-Zeile, keine Feld-Symbole, Vulkan-Kegel, Ansicht, Fels
		await _b12_tour(dir)
	if only == "" or only == "erde_look":   # Erdgeschichte: Zeitalter-Looks, Decke, Eis, Gestalten, Einschlag, Leistung
		await _erde_look_tour(dir)
	if only == "erde":              # nur die neuen Zeitalter (Saurier, Einschlag, Eiszeit, Affen, Feuer), alle Level offen
		Game.clock_override = Daily.local_unix(2026, 11, 9, 17, 40)
		Game.reset_campaign()
		Game.coach_seen = {}
		Game.cards_seen = {}
		Game.debug_open_all = true
		await get_tree().process_frame
		if ui.day_ui.creator_open():   # frisches Profil: erst den Charakter fertig (sonst liegt er über allem)
			ui.day_ui.creator.look = Character.default_look()
			ui.day_ui._on_creator_finished(Character.default_look())
			await _wait(1.0)
		await _erde_tour(dir)
	if only == "" or only == "migrate":   # ein alter Spielstand („Die Schöpfung“, 30 Level) wird zur Erdgeschichte
		await _migration_check(dir)
	# Letzte Zeile: Die Action prüft, dass die Tour ganz durchlief (sonst sind Bilder und Prüfungen unvollständig)
	print("Tour: %.0f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("TOUR-DONE checks=%d failed=%d" % [_checks, _failed])
	get_tree().quit()


## Freies Spiel (nach Tag 7): Werkzeuge, Wahl, Krieg, Smog, Wünsche, Strafen, Hilfe, Menü, Ende.
func _free_tour(dir: String) -> void:
	Game.world_done = true          # freies Spiel ist offen
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


# --- Die Schöpfung (30 Level in 7 Akten) ---------------------------------------------------------------

func _camp_tour(dir: String) -> void:
	var dui := ui.day_ui
	# Wie ein neuer Spieler: kein Fortschritt, keine Hinweise, noch kein eigener Gott; die Uhr steht fest auf Montag,
	# 9. November 2026, 17:40 (gleiche Bilder, gleiche Erinnerungs-Zeiten in jedem Lauf)
	Game.debug_open_all = false
	Game.debug_day_offset = 0
	Game.clock_override = Daily.local_unix(2026, 11, 9, 17, 40)
	Game.reset_campaign()
	Game.reset_daily()
	Game.note_session()
	Game.coach_seen = {}
	Game.cards_seen = {}
	Game.tutorial_done = false
	Game.always_ask = false
	Game.reminder_echo = true
	Game.pdata = Points.fresh(Campaign.COUNT)
	Game.points = Balance.POINTS_START
	Game.stock = {}
	Game.owned = []
	Character.owned_parts = Game.owned
	Game.hint_budget_usec = 40000
	dui.debug_ask_on_pc = true
	await get_tree().process_frame
	await _creator_tour(dir)
	# 1. Die Übersicht: Zeitalter der Erdgeschichte, nur „Urerde“ mit Level 1 offen, danach eine „?“-Kachel, nichts verraten
	dui.show_overview(false)
	await _wait(1.4)
	await _shot(dir, "00a_erdgeschichte")
	var spoil := _spoiler_labels(dui.overview)
	var a2: Dictionary = dui.ov_acts[1]
	_check(dui.is_open() and dui.ov_acts.size() == Campaign.era_count() and Game.level_unlocked(1) and not Game.level_unlocked(2)
		and (dui.ov_acts[0]["name"] as Label).text == "Urerde" and (a2["name"] as Label).text == "?"
		and not (a2["flow"] as Control).visible, "camp_overview",
		"zeitalter1=%s zeitalter2=%s heute=%s" % [(dui.ov_acts[0]["name"] as Label).text, (a2["name"] as Label).text, dui.tc_title.text])
	_check(spoil.is_empty(), "no_spoiler_campaign", "verraten=%s" % str(spoil))
	_era_overview_check("start")
	# 2. Den eigenen Gott antippen öffnet ihn (ansehen, ändern, Art zu reden)
	await _tap(dui.ov_char_btn)
	await _wait(1.0)
	var god_open := dui.creator_open() and dui._creator_edit
	await _shot(dir, "00b_gott_antippen")
	dui.creator._on_close()
	await _wait(0.8)
	_check(god_open and dui.is_open() and not dui.creator_open(), "god_tap_opens", "offen=%s" % str(god_open))
	# 3. Level 1 antippen (echte Eingabe): die Start-Karte mit Geschichte und Aufgabe, ohne Limit
	await _tap(dui.level_btn(1))
	var card1 := await _until_shown(dui.goal_card, 4.0)
	await _wait(0.5)
	await _shot(dir, "00c_level1_karte")
	_check(card1 and Game.level_no == 1 and dui.gc_goal.text == "Mach 6 Felsen" and dui.gc_limit.text == "Ohne Limit. Schritte zählen."
		and dui.gc_intro.text.contains("Die Erde glüht.") and dui.gc_go.text == str(Days.TEXT["go_demo"]) and dui.gc_star_label.text == "bis %d · ★★ bis %d" % [int(Campaign.stars_of(1)[0]), int(Campaign.stars_of(1)[1])],
		"l1_goal_card", "ziel=%s grenze=%s intro=%s sterne=%s" % [dui.gc_goal.text, dui.gc_limit.text, dui.gc_intro.text.left(40), dui.gc_star_label.text])
	# 4. „Zeig's mir“: die Hand spielt den ersten Zug vor (3 Lava → Fels), ein Wisch in der Zeit zählt nicht
	world.tour_auto = false
	await _tap(dui.gc_go)
	await _wait(0.2)
	var lane_cv := ui.speaker_view(dui.lane_speaker)
	_check(dui.lane.visible and str(lane_cv.look.get("basis", "")) == "katze" and dui.lane_label.text == CharacterTexts.line("d1_demo", "frech"),
		"character_coach", "basis=%s text=%s" % [str(lane_cv.look.get("basis", "")), dui.lane_label.text.left(40)])
	var vs0 := get_viewport().get_visible_rect().size
	await _swipe(vs0 * Vector2(0.3, 0.47), vs0 * Vector2(0.7, 0.47))
	var ignored := Game.state.twists == 0
	for i in 160:
		if Game.state.goal_progress() >= 1 and not world.animating and not Game.busy:
			break
		await _wait(0.05)
	await _wait(0.6)
	await _shot(dir, "00d_level1_lava_fels")
	var ring_cap := dui.ring_caps.text
	_check(ignored and Game.state.goal_progress() >= 1 and dui.chip_num.text == "%d/6" % Game.state.goal_progress()
		and Game.state.steps9() == 0 and Game.state.gift_twists == 1 and (Game.state.fields as Array).any(func(f: FieldData) -> bool: return f.kind == FieldData.STONE),
		"l1_tutorial_lava", "chip=%s schritte=%d ring=%s" % [dui.chip_num.text, Game.state.steps9(), ring_cap])
	# HUD mitten und groß genug (1080 × 2340: Chip-Mitte nah der Bildschirm-Mitte, Chips ≥ 56 px hoch)
	var sc := get_tree().root.content_scale_factor
	var cr := dui.chip.get_global_rect()
	var dr := ui.dock.get_global_rect()
	_check(absf(cr.get_center().x - vs0.x * 0.5) <= vs0.x * 0.12 and cr.size.y * sc >= 56.0 and absf(dr.get_center().x - vs0.x * 0.5) <= vs0.x * 0.12
		and ring_cap == "★★★ bis 4", "hud_central", "chip=%s dock=%s skala=%.2f ring=%s" % [str(cr), str(dr), sc, ring_cap])
	var your_turn := false
	for i in 100:
		if dui.lane_visible() and dui.lane_label.text == CharacterTexts.line("d1_c2", "frech") and ui.dock.visible:
			your_turn = true
			break
		await _wait(0.05)
	await _shot(dir, "00e_level1_jetzt_du")
	_check(your_turn and not ui.input_locked(), "l1_your_turn", "lane=%s" % dui.lane_label.text.left(30))
	await _no_auto_twist_check()
	world.tour_auto = true
	# Das Menü (echte Eingabe) mitten im Level: oben das Wichtige, Unwichtiges unter „Einstellungen“
	await _menu_check(dir)
	# 5. Den Rest selbst (wie der Tipp, echte Wische): geschafft – Sterne nach Schritten, Punkte einzeln
	var won := await _play_level(14)
	var wcard := await _until_shown(dui.win_card, 6.0)
	await _wait(3.2)
	await _shot(dir, "00f_level1_geschafft")
	var steps1 := Game.state.day_won_at
	var st1 := Campaign.stars_for(1, steps1)
	var pts1 := Campaign.points_for(1, steps1)
	var lines_ok := dui.wc_points.visible and dui.wc_points.get_child_count() >= 3 and dui.wc_total_pts.text == "+%d" % int(dui.wc_total_pts.get_meta("total", -1))
	_check(won and wcard and Game.level_stars(1) == st1 and st1 >= 2 and Game.state.level_points() == pts1 and lines_ok
		and dui.wc_title.text == "Glut geschafft!" and Game.streak() == 1, "stars_generous",
		"schritte=%d sterne=%d punkte=%d zeilen=%d summe=%s" % [steps1, st1, pts1, dui.wc_points.get_child_count(), dui.wc_total_pts.text])
	# Kein Weiterbauen mehr (Build 12): Level 2 erst morgen → „Nochmal · mehr Sterne“ (unter 3 Sternen) oder „Zur Übersicht“
	var no_build := true
	for b in [dui.wc_next, dui.wc_alt, dui.wc_home]:
		if (b as Button).visible and (b as Button).text == "Weiterbauen":
			no_build = false
	var main_ok := dui.wc_next.text == (str(Days.TEXT["again_stars"]) if st1 < 3 else str(Days.TEXT["to_overview"]))
	_check(won and wcard and no_build and main_ok and dui.wc_next_line.text == str(Campaign.TEXT["tomorrow"]),
		"level_success", "knopf=%s zweit=%s/%s zeile=%s" % [dui.wc_next.text, dui.wc_alt.text, str(dui.wc_alt.visible), dui.wc_next_line.text])
	# 6. „Zur Übersicht“: vorher fragt der Charakter, ob er erinnern darf („Lieber nicht“)
	await _tap(dui.wc_home if dui.wc_home.visible else dui.wc_next)
	var ask := await _until_shown(dui.ask_card, 4.0)
	await _wait(0.4)
	await _shot(dir, "00g_erinnern_frage")
	var ask_ok := ask and dui.ask_text.text == CharacterTexts.fill(str((CharacterTexts.LINES["ask_reminder"] as Dictionary)["frech"]), {"tag": "etwas Neues"})
	await _tap(dui.ask_no)
	await _wait(1.2)
	_check(ask_ok and int(Game.remind["asked"]) == 1 and not dui.ask_card.visible, "permission_ask", "frage=%s" % dui.ask_text.text.left(40))
	# 7. In der Übersicht: kein „Weiterbauen“ auf der Heute-Karte, keine Weiterbauen-Zeile im Spiel
	await _wait(0.6)
	await _shot(dir, "00h_uebersicht_ohne_weiterbauen")
	# Der Code-Weg ist weg: kein Knopf auf der Heute-Karte, keine Game-API, kein Signal
	var api_gone := not Game.has_method("continue_build") and not Game.has_method("resume_build") \
		and not Game.has_signal("build_started") and not ("tc_build" in dui) and not Game.today_info().has("can_build")
	_check(dui.is_open() and api_gone and not (Game.state != null and Game.state.day_free_build),
		"no_continue_build", "uebersicht=%s api_weg=%s" % [str(dui.is_open()), str(api_gone)])
	# 8. Zur Übersicht: Level 2 erst morgen; Antippen sagt „Erst morgen“ und die Uhr
	if not dui.is_open():
		await _tap(ui.menu_b)
		await _until_shown(ui.menu_card, 3.0)
		await _tap(ui._menu_days)
		await _wait(1.2)
	var lb2 := dui.level_btn(2)
	var morgen := dui.is_open() and bool(lb2.get_meta("morgen", false)) and not Game.level_unlocked(2) and dui.tc_title.text == str(Days.TEXT["today_done"])
	await _shot(dir, "00i_morgen")
	await _tap(lb2)
	var toast_ok := false
	for i in 80:
		if ui.toast.visible and (ui.toast_label.text.begins_with("Neuer Tag in") or ui.toast_label.text == str(Days.TEXT["countdown_late"])):
			toast_ok = true
			break
		await _wait(0.05)
	_check(morgen and toast_ok and dui.tc_line.text == str(Campaign.TEXT["locked"]), "level_locked_until_tomorrow",
		"morgen=%s toast=%s zeile=%s" % [str(morgen), str(toast_ok), dui.tc_line.text])
	# 9. „Nächster Tag (Test)“: Level 2 ist offen (Titel erst jetzt), die Welt von gestern läuft weiter
	dui.ov_scroll.ensure_control_visible(dui.ov_debug)
	await _wait(0.3)
	await _tap(dui.ov_debug)
	await _wait(0.9)
	dui.ov_scroll.scroll_vertical = 0
	await _wait(0.4)
	await _shot(dir, "00j_naechster_tag")
	_check(Game.level_unlocked(2) and dui.tc_title.text == "Abkühlen" and dui.tc_go.visible and Game.debug_day_offset == 1,
		"next_day_debug_unlocks", "heute=%s %s" % [dui.tc_caps.text, dui.tc_title.text])
	var world1 := str(Game.camp["world"])
	await _tap(dui.tc_go)
	var card2 := await _until_shown(dui.goal_card, 4.0)
	var same := 0
	var b2 := str(Game.level_board.get("board", ""))
	for i in mini(world1.length(), b2.length()):
		if world1[i] == b2[i]:
			same += 1
	await _shot(dir, "00k_level2_welt_von_gestern")
	_check(card2 and Game.level_no == 2 and str(Game.level_board.get("how", "")) == "carry" and same >= 27, "carry_world",
		"wie=%s gleich=%d/54" % [str(Game.level_board.get("how", "")), same])
	await _tap(dui.gc_go)
	await _wait(2.0)
	ui._coach_dismiss()
	# 10. Level 2 schaffen: die Serie wächst auf 2; der Plan der Erinnerungen
	var s0 := Game.streak()
	var won2 := await _play_level(20)
	var wc2 := await _until_shown(dui.win_card, 6.0)
	await _wait(3.0)
	await _shot(dir, "00l_serie")
	_check(won2 and wc2 and s0 == 1 and Game.streak() == 2 and dui.wc_streak_num.text == "2", "streak_increments",
		"serie=%d->%d zahl=%s" % [s0, Game.streak(), dui.wc_streak_num.text])
	await _reminder_check(dir)
	# Level 3 aus der eigenen Welt: erreichbar, und wenn doch alles schiefgeht, hilft der Charakter
	await _level3_check(dir)
	# Ab hier springt die Tour durch die Zeitalter (alle Level offen)
	Game.debug_open_all = true
	await _acts_tour(dir)
	await _erde_tour(dir)
	await _shop_tour(dir)
	await _free100_tour(dir)
	await _wdt_tour(dir)
	await _bonus_round_tour(dir)


## --only=level3: Level 1 und 2 unordentlich spielen (Zufallszüge, das Netz wie im Spiel, Weiterbauen) und die Welt
## speichern wie Game; dann die Prüfung level3_solvable.
func _level3_only(dir: String) -> void:
	Game.clock_override = Daily.local_unix(2026, 11, 9, 17, 40)
	Game.reset_campaign()
	Game.cards_seen = {}
	Game.debug_open_all = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var b: Dictionary = Campaign.board(1, 3)
	b["how"] = "pool"
	var world_s := ""
	for lv in [1, 2]:
		var gs := Campaign.new_state(lv, b)
		var acts := 0
		while not gs.day_won and acts < 300:
			acts += 1
			var m: Array = GameState.MOVES[rng.randi_range(0, GameState.MOVES.size() - 1)]
			gs.play({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])})
			if not gs.day_won and gs.stuck9() != "" and not gs.gift_plan9().is_empty():
				gs.play({"type": "gift"})
		(Game.camp["stars"] as Array)[lv - 1] = maxi(1, gs.stars())
		(Game.camp["steps"] as Array)[lv - 1] = gs.day_won_at
		gs.start_free_build()
		for i in rng.randi_range(5, 30):
			var m2: Array = GameState.MOVES[rng.randi_range(0, GameState.MOVES.size() - 1)]
			gs.play({"type": "twist", "axis": int(m2[0]), "layer": int(m2[1]), "turns": int(m2[2])})
		world_s = gs.slot_board9()
		if lv == 1:
			b = Campaign.ensure(2, Campaign.carry(Campaign.decode(world_s), 2, 2001, 0), 0)
	Game.camp["world"] = world_s
	Game.camp["world_level"] = 2
	await get_tree().process_frame
	await _level3_check(dir)


## level3_solvable (Spieler: „16 Felsen war bei mir nicht möglich“): Level 3 startet auf der eigenen Welt von Level 2
## (Game.start_level, Campaign.ensure) mit 14 Felsen als Ziel, erreichbar und ohne Riesen-Klumpen. Dann geht alles
## schief (drei Zufalls-Wische, danach ist alle Lava weg): Nach der nächsten Drehung merkt es der Charakter und
## bietet ein Geschenk an; Antippen bringt +1 Fels und Lava-Nachschub, das Ziel ist wieder erreichbar.
func _level3_check(dir: String) -> void:
	var dui := ui.day_ui
	Game.debug_open_all = true
	Game.rescue_on = true
	Game.start_level(3)
	var card := await _until_shown(dui.goal_card, 8.0)
	await _wait(0.3)
	if card:
		await _tap(dui.gc_go)
	await _wait(1.2)
	ui._coach_dismiss()
	var gs: GameState = Game.state
	var how := str(Game.level_board.get("how", ""))
	var clump := gs.biggest9(FieldData.LAVA)
	var start_ok := Game.level_no == 3 and gs.target9() == 14 and bool(gs.reach9()["ok"]) \
		and (how != "carry" or clump <= GameState.CLUMP_CAP9) and (how == "carry" or how == "fallback")
	await _shot(dir, "00m_level3_eigene_welt")
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for i in 3:
		if Game.state.day_won:
			break
		var m: Array = GameState.MOVES[rng.randi_range(0, GameState.MOVES.size() - 1)]
		await _swipe_move(int(m[0]), int(m[1]), int(m[2]))
		await _settle(8.0)
	# Alles verloren: keine Lava mehr (wie nach vielen Ausbrüchen und falschen Zügen) – so geht es nicht weiter
	for f in Game.state.fields:
		if f.kind == FieldData.LAVA:
			Game.state._setk9(f, FieldData.WATER)
	world.refresh_all()
	await _wait(0.4)
	var dead_now := Game.state.stuck9() == "dead"
	var d := _twist_without_progress()
	await _swipe_move(int(d[0]), int(d[1]), int(d[2]))
	await _settle(8.0)
	var shown := await _until_shown(dui.dead_card, 6.0)
	await _wait(0.6)
	await _shot(dir, "00n_level3_hilfe")
	var gift_vis := dui.dead_gift.visible and dui.dead_world.visible and dui.dead_text.text != ""
	var p0 := Game.state.progress9()
	if shown:
		await _tap(dui.dead_gift)
	await _settle(8.0)
	await _wait(0.8)
	await _shot(dir, "00o_level3_geschenk")
	var p1 := Game.state.progress9()
	var after_ok := p1 == p0 + 1 and bool(Game.state.reach9()["ok"]) and not dui.dead_card.visible and Game.rescue_offer.is_empty()
	Game.rescue_on = false
	_check(start_ok and dead_now and shown and gift_vis and after_ok, "level3_solvable",
		"wie=%s klumpen=%d ziel=%d sackgasse=%s karte=%s text=%s fortschritt=%d->%d" % [how, clump, gs.target9(), str(dead_now),
		str(shown), dui.dead_text.text, p0, p1])


## Texte in der Übersicht, die ein gesperrtes Level verraten würden (Titel, Geschichte, Aufgabe).
func _spoiler_labels(root: Node) -> Array:
	var bad: Array = []
	var words := {}
	for n in range(1, Campaign.COUNT + 1):
		if Game.level_unlocked(n):
			continue
		var c := Campaign.config(n)
		words[str(c.get("title", ""))] = n
		words[str(c.get("story", ""))] = n
	for a in range(1, Campaign.era_count() + 1):
		var reached := false
		for n in Campaign.era_levels(a):
			reached = reached or Game.level_unlocked(int(n))
		if not reached:
			words[Campaign.act_name(a)] = a
			words[str(Campaign.era_info(a).get("line", ""))] = a
	var stack: Array = [root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is Label and (nd as Label).is_visible_in_tree():
			var t := (nd as Label).text
			for w in words:
				if str(w) != "" and t.contains(str(w)):
					bad.append(t)
		for c in nd.get_children():
			stack.append(c)
	return bad


## era_overview_no_spoiler: Die Übersicht zeigt die erreichten Zeitalter (Name) und genau eine „?“-Kachel ohne Level;
## kein Name, keine Zeile eines späteren Zeitalters, kein Titel eines gesperrten Levels, nirgends „Tag 1–7“ oder
## „Schöpfung“ (Rahmen der Genesis ist weg).
var _era_ov_notes: Array = []


func _era_overview_check(tag: String) -> void:
	var dui := ui.day_ui
	var spoil := _spoiler_labels(dui.overview)
	var genesis := _genesis_labels(dui.overview)
	var reached := 0
	var q := 0
	var later_visible := false
	for t in dui.ov_acts:
		var d: Dictionary = t
		if not (d["panel"] as Control).visible:
			continue
		var nm := (d["name"] as Label).text
		var lv_open := false
		for n in Campaign.era_levels(int(d["act"])):
			lv_open = lv_open or Game.level_unlocked(int(n))
		if nm == "?":
			q += 1
			later_visible = later_visible or (d["flow"] as Control).visible
		elif lv_open and nm == Campaign.act_name(int(d["act"])):
			reached += 1
	var ok := spoil.is_empty() and genesis.is_empty() and q == 1 and reached >= 1 and not later_visible
	_era_ov_notes.append("%s:%s" % [tag, str(ok)])
	_check(ok, "era_overview_no_spoiler", "%s erreicht=%d fragezeichen=%d verraten=%s genesis=%s" % [tag, reached, q, str(spoil), str(genesis)])


## Sichtbare Texte mit dem alten Genesis-Rahmen („Tag 3“, „Schöpfung“, „siebte“, „Und es war gut“).
func _genesis_labels(root: Node) -> Array:
	var bad: Array = []
	var re := RegEx.new()
	re.compile("\\bTag [1-7]\\b|Schöpfung|siebte|Und es war gut|Akt [1-7]")
	var stack: Array = [root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if (nd is Label or nd is Button) and (nd as Control).is_visible_in_tree():
			var t := (nd as Label).text if nd is Label else (nd as Button).text
			if re.search(t) != null and not t.contains("Serie"):
				bad.append(t)
		for c in nd.get_children():
			stack.append(c)
	return bad


## Ein Level mit dem Tipp zu Ende spielen (echte Wische; Regen und Meteor wie der Tipp).
func _play_level(max_steps: int) -> bool:
	for i in max_steps:
		if not Game.in_day() or Game.state.day_won or Game.over:
			break
		var act: Dictionary = await Game.search_hint()
		var typ := str(act.get("type", "twist"))
		if (typ == "rain" or typ == "meteor" or typ == "strike") and act.has("field"):
			if Game.use_bonus("strike" if typ == "meteor" else typ, int(act["field"]), [], true):
				await _settle(8.0)
				continue
		if act.is_empty() or typ != "twist":
			var d := _twist_without_progress()
			act = {"axis": d[0], "layer": d[1], "turns": d[2], "choice": 0}
		await _swipe_move(int(act["axis"]), int(act["layer"]), int(act["turns"]))
		await _settle(8.0, int(act.get("choice", 0)))
	return Game.state.day_won


## Ein Level starten und die Start-Karte mit „Los!“ schließen (echte Eingabe). Wartet auf den Akt-Übergang.
func _start_lvl(n: int, board: int = 0) -> bool:
	var dui := ui.day_ui
	Game.start_level(n, board)
	var card := await _until_shown(dui.goal_card, 8.0)
	await _wait(0.3)
	if card:
		await _tap(dui.gc_go)
	await _wait(1.0)
	ui._coach_dismiss()
	return card and Game.level_no == n


## Eine Drehung, deren Runde ein Ereignis vom Typ t bringt (Simulation, ohne avoid), sonst [].
func _move_with(t: String, avoid: String = "") -> Array:
	for m in GameState.MOVES:
		var r: Dictionary = Game.state.simulate(_twist(int(m[0]), int(m[1]), int(m[2])))
		var res: Dictionary = r["result"]
		if _has_event(res, t) and (avoid == "" or not _has_event(res, avoid)):
			return m
	return []


## Ein Pool-Brett von Level lv (0 … 7), auf dem nach einer Drehung (depth 2: nach zweien) pred(vorher, Ergebnis)
## gilt. [Brett, [Drehungen]] oder [-1, []]. pred: func(gs: GameState, r: Dictionary) -> bool.
func _find_board(lv: int, pred: Callable, depth: int = 1) -> Array:
	for bi in range(0, mini(8, Campaign.pool_size(lv))):
		var gs := Campaign.new_state(lv, Campaign.board(lv, bi))
		for m1 in GameState.MOVES:
			var r1: Dictionary = gs.simulate(_twist(int(m1[0]), int(m1[1]), int(m1[2])))
			if pred.call(gs, r1):
				return [bi, [m1]]
		if depth < 2:
			continue
		for m1 in GameState.MOVES:
			var r1b: Dictionary = gs.simulate(_twist(int(m1[0]), int(m1[1]), int(m1[2])))
			var st1: GameState = r1b["state"]
			for m2 in GameState.MOVES:
				var r2: Dictionary = st1.simulate(_twist(int(m2[0]), int(m2[1]), int(m2[2])))
				if pred.call(st1, r2):
					return [bi, [m1, m2]]
	return [-1, []]


func _p_event(_gs: GameState, r: Dictionary, t: String) -> bool:
	return _has_event(r["result"], t)


func _p_more(gs: GameState, r: Dictionary, k: int) -> bool:
	return (r["state"] as GameState).count(k) > gs.count(k)


## Die Gruppe wächst, und zwei Felder der Art liegen danach nebeneinander auf derselben Seite (die Fuge ist im Bild).
func _p_group_face(gs: GameState, r: Dictionary, k: int) -> bool:
	if not _p_group(gs, r, k):
		return false
	var st: GameState = r["state"]
	var ks: Array = []
	for f in st.fields:
		if (f as FieldData).kind == k:
			ks.append(f)
	for a in ks:
		for b in ks:
			var fa: FieldData = a
			var fb: FieldData = b
			if fa.id < fb.id and fa.n == fb.n and absi(fa.p.x - fb.p.x) + absi(fa.p.y - fb.p.y) + absi(fa.p.z - fb.p.z) == 1:
				return true
	return false


func _p_group(gs: GameState, r: Dictionary, k: int) -> bool:
	return (r["state"] as GameState).biggest9(k) > gs.biggest9(k)


## Blitz droht nach dieser Runde, und eine nächste Drehung wendet ihn ab (Wasser an den Wald).
func _p_bolt(_gs: GameState, r: Dictionary) -> bool:
	if not _has_event(r["result"], "bolt_warn"):
		return false
	var st: GameState = r["state"]
	for m in GameState.MOVES:
		var r2: Dictionary = st.simulate(_twist(int(m[0]), int(m[1]), int(m[2])))
		if _has_event(r2["result"], "bolt_miss") and not _has_event(r2["result"], "bolt"):
			return true
	return false


## Ein Rudel droht, und der Meteor auf ein Raubtier beendet die Warnung.
func _p_pack(_gs: GameState, r: Dictionary) -> bool:
	var st: GameState = r["state"]
	if st.pack_warn9.is_empty():
		return false
	return _pack_breaker(st) >= 0


func _pack_breaker(st: GameState) -> int:
	var at := int(GameState.B9["PACK_AT"])
	for f in st.fields:
		var fd: FieldData = f
		if fd.kind != FieldData.PRED:
			continue
		var sm: Dictionary = st.simulate({"type": "strike", "field": fd.id, "row": []})
		var s2: GameState = sm["state"]
		var safe := true
		for i in st.pack_warn9:
			for g in s2.nb9(int(i)):
				if (s2.fields[g] as FieldData).kind == FieldData.PRED and s2.gsize9(g) >= at:
					safe = false
		if safe:
			return fd.id
	return -1


## Wald ganz oben auf der Seite n: die oberste Reihe wird Wald, Wasser daneben Wiese (trocken: Blitz droht).
func _paint_dry_forest(n: Vector3i) -> bool:
	var gs := Game.state
	var ff: Array = gs.face_fields(n)
	for i in 3:
		var f: FieldData = ff[i]
		f.kind = FieldData.FOREST
		f.fresh = 0
		f.burning = false
	gs._grp_ok = false
	for i in 3:
		for g in gs.nb9((ff[i] as FieldData).id):
			var fd: FieldData = gs.fields[g]
			if FieldData.water_family(fd.kind):
				fd.kind = FieldData.MEADOW
	gs._grp_ok = false
	Game.state_changed.emit()
	return gs.dry9((ff[0] as FieldData).id)


## Zwei Drehungen, nach denen ein Ereignis vom Typ t kommt (die erste allein bringt es nicht), sonst [].
func _seq_with(t: String) -> Array:
	for m1 in GameState.MOVES:
		var r1: Dictionary = Game.state.simulate(_twist(int(m1[0]), int(m1[1]), int(m1[2])))
		var st1: GameState = r1["state"]
		for m2 in GameState.MOVES:
			var r2: Dictionary = st1.simulate(_twist(int(m2[0]), int(m2[1]), int(m2[2])))
			if _has_event(r2["result"], t):
				return [m1, m2]
	return []


func _swipe_m(m: Array) -> void:
	_round_types = {}
	await _swipe_move(int(m[0]), int(m[1]), int(m[2]))
	await _settle(8.0)


## Menü (Feedback 8. November): Hauptseite = Weiter, Schöpfung, Freies Spiel, Laden, Dein Gott + Zahnrad, kein Schalter;
## „Einstellungen“ zeigt Ton, Erinnerung, Hilfe, Tutorial; der Pfeil führt zurück; die Schalter schalten.
func _menu_check(dir: String) -> void:
	await _tap(ui.menu_b)
	await _until_shown(ui.menu_card, 3.0)
	await _wait(0.4)
	await _shot(dir, "00m_menue")
	var main_ok := ui._menu_main.visible and ui._menu_cont.is_visible_in_tree() and ui._menu_days.is_visible_in_tree() \
		and ui._menu_free.is_visible_in_tree() and ui._menu_shop.is_visible_in_tree() and ui._menu_god.is_visible_in_tree() \
		and ui._menu_gear.is_visible_in_tree() and not ui._music_switch.is_visible_in_tree() and not ui._remind_box.is_visible_in_tree()
	var fits := ui.menu_card.get_global_rect().size.y <= ui._vs().y
	await _tap(ui._menu_gear)
	await _wait(0.6)
	await _shot(dir, "00n_einstellungen")
	var set_ok := ui.menu_on_settings() and ui._music_switch.is_visible_in_tree() and ui._sfx_switch.is_visible_in_tree() \
		and ui._remind_box.is_visible_in_tree() and ui._help_tile.is_visible_in_tree() and ui._tutorial_tile.is_visible_in_tree() \
		and not ui._menu_days.is_visible_in_tree()
	var m0 := Game.music_on
	await _tap(ui._music_switch)
	await _wait(0.3)
	var toggled := Game.music_on != m0
	await _tap(ui._music_switch)
	await _wait(0.3)
	await _tap(ui._menu_back)
	await _wait(0.5)
	_check(main_ok and fits and set_ok and toggled and Game.music_on == m0 and ui._menu_main.visible and not ui.menu_on_settings(),
		"menu_settings_submenu", "haupt=%s passt=%s einst=%s schalter=%s" % [str(main_ok), str(fits), str(set_ok), str(toggled)])
	ui._close_modal(true)
	await _wait(0.3)


## Erinnerungs-Plan nach dem Sieg (4 Stufen, 30 min vor der Uhrzeit dieser Sitzung, nie nachts) und „Feste Uhrzeit“
## in den Einstellungen.
func _reminder_check(dir: String) -> void:
	var dui := ui.day_ui
	var plan: Array = Game.reminder_log
	var ids: Array = []
	var cats: Array = []
	var in_window := true
	for e in plan:
		var d: Dictionary = e
		ids.append(int(d["id"]))
		cats.append(str(d["cat"]))
		var m := int(d["hour"]) * 60 + int(d["minute"])
		in_window = in_window and m >= Balance.REMIND_EARLIEST and m <= Balance.REMIND_LATEST
	var first: Dictionary = plan[0] if not plan.is_empty() else {}
	var a_time := "%02d:%02d" % [int(first.get("hour", -1)), int(first.get("minute", -1))]
	var ok_plan := ids == [101, 102, 104, 107] and cats == ["A", "B", "C", "F"] and in_window and a_time == "17:10"
	await _tap(dui.wc_home)
	await _wait(1.0)
	ui._open_menu()
	await _until_shown(ui.menu_card, 3.0)
	await _tap(ui._menu_gear)
	await _wait(0.5)
	var sc: ScrollContainer = ui.menu_card.get_meta("scroll")
	sc.ensure_control_visible(ui._remind_box)
	await _wait(0.4)
	await _tap(ui.segment_button(ui._remind_seg, "fest"))
	await _wait(0.6)
	sc.ensure_control_visible(ui._remind_box)
	await _shot(dir, "00o_erinnerung")
	var fixed_plan: Array = Game.reminder_log
	var fixed_ok := str(Game.remind["mode"]) == "fest" and not fixed_plan.is_empty() and int((fixed_plan[0] as Dictionary)["hour"]) == 18
	await _tap(ui.segment_button(ui._remind_seg, "auto"))
	await _wait(0.4)
	_check(ok_plan and fixed_ok and str(Game.remind["mode"]) == "auto", "reminder_scheduled",
		"ids=%s cats=%s A=%s fest=%s" % [str(ids), str(cats), a_time, str(fixed_ok)])
	ui._close_modal(true)


# --- Die Akte: je ein Level, mit den neuen Dingen und den Gefahren als Folgen ------------------------------

func _acts_tour(dir: String) -> void:
	var dui := ui.day_ui
	Game.round_resolved.connect(_on_tour_round)
	# Urerde · Level 3: ein Lava-Klumpen grollt (Warnung eine Runde vorher) – Teilen beruhigt; bricht er doch aus,
	# zählt der Verlust (−1 Fels fliegt zum Chip, der Chip zählt herunter)
	await _start_lvl(3, 0)
	await _shot(dir, "01a_level3_vulkan")
	# Hilfe in der Erdgeschichte: die Verben der Kampagne, keine Regeln des freien Spiels
	ui._show_help()
	await _wait(0.8)
	await _shot(dir, "00p_hilfe_kampagne")
	var hr: Dictionary = ui._help_rows
	_check((hr["c_steps"] as Control).is_visible_in_tree() and (hr["c_volcano"] as Control).is_visible_in_tree()
		and not (hr["wish"] as Control).is_visible_in_tree() and not (hr["fire"] as Control).is_visible_in_tree()
		and not (hr["scale"] as Control).is_visible_in_tree(), "help_campaign", "level=3")
	ui._close_modal(true)
	await _wait(0.4)
	var wm := _move_with("volcano_warn")
	if not wm.is_empty():
		await _swipe_m(wm)
	var warned := Game.state.volc >= 0
	var pill_v := _seen_type("volcano_warn")
	await _shot(dir, "01b_vulkan_grollt")
	var calm := _move_with("volcano_calm", "erupt")
	var avoided := false
	if not calm.is_empty():
		await _swipe_m(calm)
		avoided = Game.state.volc < 0 and _seen_type("volcano_calm") and not _seen_type("erupt")
	_check(warned and pill_v, "volcano_warn", "krater=%d pille=%s zug=%s" % [Game.state.volc, str(pill_v), str(wm)])
	_check(avoided, "consequence_danger_avoided", "ruhe=%s zug=%s" % [str(avoided), str(calm)])
	var p_before := Game.state.goal_progress()
	var lost0 := dui.loss_flown
	var loss_ok := false
	var seq := _seq_with("goal_loss")
	if not seq.is_empty():
		await _swipe_m(seq[0])
		var p_mid := Game.state.goal_progress()
		# Die Aufnahme, solange das rote −1 fliegt (nicht erst danach)
		var started0 := dui.loss_started
		_round_types = {}
		var m2s: Array = seq[1]
		await _swipe_move(int(m2s[0]), int(m2s[1]), int(m2s[2]))
		for i in 160:
			if dui.loss_started > started0:
				break
			await _wait(0.05)
		await _wait(0.25)
		await _shot(dir, "01c_verlust")
		await _settle(8.0)
		for i in 60:
			if dui.loss_flown > lost0:
				break
			await _wait(0.05)
		loss_ok = _seen_type("goal_loss") and dui.loss_flown > lost0 and Game.state.goal_progress() < maxi(p_mid, p_before) + 3
	_check(loss_ok, "goal_loss_cue", "folge=%s chip=%s geflogen=%d" % [str(seq), dui.chip_num.text, dui.loss_flown - lost0])
	# Urozean · Level 5: der Zeitalter-Übergang (Himmel, kurz der Name), Dampf wird Regen
	var acts0 := dui.act_shown
	var era0 := world.era_name
	Game.start_level(5, 0)
	await _wait(1.2)
	await _shot(dir, "02a_zeitalter_uebergang")
	await _until_shown(dui.goal_card, 8.0)
	_check(dui.act_shown == acts0 + 1 and world.era_name != era0 and dui.era_shown == "Urozean", "act_transition",
		"aera=%s->%s titel=%s" % [era0, world.era_name, dui.era_shown])
	await _tap(dui.gc_go)
	await _wait(3.0)
	ui._coach_dismiss()
	await _shot(dir, "02b_level5_regen")
	var fb := _find_board(5, _p_event.bind("steam"), 2)
	if int(fb[0]) >= 0:
		await _start_lvl(5, int(fb[0]))
	var r0 := Game.state.rain
	_round_types = {}
	for m in fb[1]:
		await _swipe_m(m)
	await _shot(dir, "02c_dampf")
	_check(int(fb[0]) >= 0 and Game.state.rain > r0 and _seen_type("steam"), "rain_from_steam", "brett=%d regen=%d->%d" % [int(fb[0]), r0, Game.state.rain])
	# Wasser lebt erst durch das Spiel: tot (6) → Ursuppe (7) → Einzeller (9) → Algen (10)
	var alive: Array = []
	var life_de: Array = []          # ΔE der Kachel-Farbe (Leben gegen totes Wasser): Einzeller, Algen
	for lv in [[6, -1], [8, FieldData.SOUP], [10, FieldData.CELLS], [18, FieldData.ALGAE], [15, FieldData.ALGAE]]:
		await _start_lvl(int(lv[0]), 0)
		var k := int(lv[1])
		var shown := k < 0
		for fid in world.views:
			if k >= 0 and (world.views[fid] as FieldView).get_kind() == k:
				shown = true
		alive.append(shown and (k >= 0 or Game.state.count(FieldData.SOUP) + Game.state.count(FieldData.CELLS) == 0))
		if int(lv[0]) == 10 or int(lv[0]) == 18:
			await _wait(1.0)
			life_de.append(await _life_delta_e(k))
		await _shot(dir, "03_wasser_level%d" % int(lv[0]))
	_check(not alive.has(false), "water_alive", "%s" % str(alive))
	_check(life_de.size() == 2 and float(life_de[0]) > 12.0 and float(life_de[1]) > 12.0, "water_life_visible",
		"dE einzeller=%.1f algen=%.1f" % [float(life_de[0]) if life_de.size() > 0 else -1.0, float(life_de[1]) if life_de.size() > 1 else -1.0])
	# Erstes Leben · Level 11: Algen machen den Himmel blau
	var fa := _find_board(11, _p_more.bind(FieldData.ALGAE), 2)
	await _start_lvl(11, maxi(0, int(fa[0])))
	await _wait(2.0)
	var b0 := world.sky_blue()
	for m in fa[1]:
		await _swipe_m(m)
	await _wait(3.0)
	await _shot(dir, "03e_himmel_blau")
	_check(world.sky_blue() > b0 + 0.01, "sky_blue", "blau=%.2f->%.2f" % [b0, world.sky_blue()])
	# Der Himmel im Bild (weit herausgezoomt): er muss sichtbar blau werden
	var z_sky := world.rig.zoom_factor
	world.rig.zoom(1.6 / maxf(z_sky, 0.01))
	await _wait(1.2)
	await _shot(dir, "03f_himmel_weit")
	world.rig.zoom(z_sky / maxf(world.rig.zoom_factor, 0.01))
	# Urwald · Level 22: ein trockener Wald (3 Wälder, kein Wasser daneben) – nach der Runde droht der Blitz (Warnung eine
	# Runde vorher); eine Drehung, die ihn teilt oder Wasser heranbringt, wendet ihn ab
	var blv := 22
	await _start_lvl(blv, 0)
	var dry_on := _paint_dry_forest(Vector3i(0, 1, 0))
	await _wait(1.0)
	var warn_m: Array = []
	var save: Array = []
	for m in GameState.MOVES:
		var rw: Dictionary = Game.state.simulate(_twist(int(m[0]), int(m[1]), int(m[2])))
		if not _has_event(rw["result"], "bolt_warn"):
			continue
		var stw: GameState = rw["state"]
		for m2 in GameState.MOVES:
			var rs: Dictionary = stw.simulate(_twist(int(m2[0]), int(m2[1]), int(m2[2])))
			if _has_event(rs["result"], "bolt_miss") and not _has_event(rs["result"], "bolt"):
				warn_m = m
				save = m2
				break
		if not warn_m.is_empty():
			break
	if not warn_m.is_empty():
		await _swipe_m(warn_m)
	var bolt_on := Game.state.bolt >= 0 and _seen_type("bolt_warn") and ui.day_ui.pill9_last == "bolt_warn"
	await _shot(dir, "04a_blitz_droht")
	var missed := false
	if not save.is_empty():
		await _swipe_m(save)
		missed = _round_types.has("bolt_miss") and not _round_types.has("bolt")
	# (Level 22: der gemalte Wald kann mit einem Wald am Wasser zusammenwachsen und ist dann erst nach der Drehung trocken)
	_check(bolt_on and missed, "dry_forest_bolt",
		"level=%d trocken=%s warnung=%s zug=%s abgewendet=%s" % [blv, str(dry_on), str(bolt_on), str(warn_m), str(save)])
	# Urwald · Level 22: die Sonne über der Sonnenseite (oben), weit herausgezoomt
	await _start_lvl(22, 0)
	var z_sun := world.rig.zoom_factor
	world.rig.focus(Vector3(0, 0, 1))          # von vorn: die Sonne steht über der Sonnenseite (oben) im Bild
	world.rig.zoom(1.6 / maxf(z_sun, 0.01))
	await _wait(1.5)
	await _shot(dir, "04b_sonne")
	world.rig.zoom(z_sun / maxf(world.rig.zoom_factor, 0.01))
	# Ackerbau · Level 51: Zusammenwachsen – zwei Äcker werden ein Feld (×2), die Gruppe zählt fürs Ziel
	var fg := _find_board(51, _p_group_face.bind(FieldData.FIELD), 2)
	await _start_lvl(51, maxi(0, int(fg[0])))
	await _shot(dir, "05a_level51_ernte")
	var mm: Array = fg[1]
	var big0 := Game.state.biggest9(FieldData.FIELD)
	if mm.size() > 1:
		await _swipe_m(mm[0])
		big0 = Game.state.biggest9(FieldData.FIELD)
	if not mm.is_empty():
		await _swipe_m(mm[mm.size() - 1])
	await _wait(1.0)
	var masks := 0                  # Fugen gehören nur einem der beiden Felder (Nord/Ost): mindestens eine
	for fid in world.views:
		var fv: FieldView = world.views[fid]
		# Fuge zusammengewachsen – oder ein Acker-Nachbar, dessen Furchen quer liegen (die wachsen absichtlich nicht
		# sichtbar zusammen: World._furrows_match), die Ansicht kennt ihn aber als gleiche Art
		var nb_same := false
		for i in mini(4, fv._nb.size()):
			nb_same = nb_same or int(fv._nb[i]) == FieldView.K_FIELD
		if fv.get_kind() == FieldData.FIELD and (fv.merge_mask() != 0 or fv._same4 != 0 or nb_same):
			masks += 1
	await _shot(dir, "05b_zusammenwachsen")
	_check(not mm.is_empty() and Game.state.biggest9(FieldData.FIELD) > big0 and masks >= 1 and dui.chip_num.text.begins_with(str(Game.state.biggest9(FieldData.FIELD))),
		"group_merge", "gruppe=%d->%d naehte=%d chip=%s" % [big0, Game.state.biggest9(FieldData.FIELD), masks, dui.chip_num.text])
	# Landgang · Level 25: ein Fisch am Moos geht an Land → Amphibie
	var fl := _find_board(25, _p_event.bind("spawn"), 2)
	await _start_lvl(25, maxi(0, int(fl[0])))
	var animals0 := Game.state.count(FieldData.AMPHIB)
	_round_types = {}
	for m in fl[1]:
		await _swipe_m(m)
	await _wait(1.0)
	await _shot(dir, "06a_landgang")
	_check(_seen_type("spawn") and Game.state.count(FieldData.AMPHIB) > animals0, "landgang",
		"brett=%d amphibien=%d->%d" % [int(fl[0]), animals0, Game.state.count(FieldData.AMPHIB)])
	# Säugetiere · Level 38: ein Rudel droht der Herde (Warnung) – der Meteor (echte Eingabe) trennt es
	var fp := _find_board(38, _p_pack)
	await _start_lvl(38, maxi(0, int(fp[0])))
	for m in fp[1]:
		await _swipe_m(m)
	var pack_on := not Game.state.pack_warn9.is_empty()
	await _shot(dir, "07a_rudel")
	var pred := _pack_breaker(Game.state)
	var met_ok := false
	if pred >= 0:
		await _tap(ui.strike_btn)
		await _wait(0.4)
		world.focus_field(pred)
		await _wait(1.0)
		var fs := world.field_screen(pred)
		await _touch(fs["pos"])
		await _wait(0.5)
		if ui.bonus_mode == "strike":
			await _touch(fs["pos"])          # Strafen: noch einmal tippen bestätigt
		await _settle(8.0)
		met_ok = (Game.state.fields[pred] as FieldData).kind != FieldData.PRED
	ui._set_bonus_mode("")
	await _shot(dir, "07b_meteor")
	# Die nächste Runde: das Rudel ist getrennt, die Herde bleibt (keine Jagd)
	var calm_m: Array = []
	for m in GameState.MOVES:
		var rp: Dictionary = Game.state.simulate(_twist(int(m[0]), int(m[1]), int(m[2])))
		if not _has_event(rp["result"], "pack_hunt"):
			calm_m = m
			break
	var hunted := true
	if met_ok and not calm_m.is_empty():
		_round_types = {}
		await _swipe_m(calm_m)
		hunted = _seen_type("pack_hunt")
	_check(pack_on and met_ok and not hunted, "pack_warn", "rudel=%s meteor=%s feld=%d jagd=%s" % [str(pack_on), str(met_ok), pred, str(hunted)])
	# Jäger und Sammler · Level 49: einmal versorgt bleibt versorgt – die Hütte behält ihr Siegel, auch wenn ihre
	# Quelle wegdreht
	await _start_lvl(49, 0)
	await _need_seal_check(dir)
	# Gleichgewicht · Level 60: Ruhe halten
	await _start_lvl(60, 0)
	await _shot(dir, "08a_level60_ruhe")
	_check(dui.chip_caps.text == "Ruhe" and dui.chip_num.text == "0/3", "hold_rest", "chip=%s %s" % [dui.chip_caps.text, dui.chip_num.text])
	# Wasser dreht mit der Scheibe (Rückmeldung 8. November)
	await _water_turn_check(dir)
	Game.round_resolved.disconnect(_on_tour_round)


## Level 49: Eine Hütte wird versorgt (Siegel), dann dreht ihre Quelle weg – sie bleibt satt, der Chip fällt nicht.
func _need_seal_check(dir: String) -> void:
	var dui := ui.day_ui
	var sm := _move_with("need_sealed")
	var seal_ok := false
	var stays := false
	var fid := -1
	if not sm.is_empty():
		var held := await _drag_hold(int(sm[0]), int(sm[1]), int(sm[2]))
		var marks := 0
		for f in world.views:
			if (world.views[f] as FieldView).supply_mode() != 0:
				marks += 1
		await _shot(dir, "07c_vorschau_versorgt")
		_check(held and marks >= 1, "supply_preview", "gehalten=%s marken=%d" % [str(held), marks])
		await _drag_release()
		await _settle(8.0)
		for f in Game.state.fields:
			var fd: FieldData = f
			if fd.kind == FieldData.HUT and Game.state.satt9(fd.id) and fid < 0:
				fid = fd.id
		seal_ok = fid >= 0 and _seen_type("need_sealed")
		await _shot(dir, "07d_siegel")
		var p0 := Game.state.goal_progress()
		# eine Drehung, die die Tiere (die Futter-Quelle) von dieser Hütte wegdreht
		for m in GameState.MOVES:
			var r: Dictionary = Game.state.simulate(_twist(int(m[0]), int(m[1]), int(m[2])))
			var st: GameState = r["state"]
			if not _has_event(r["result"], "goal_loss") and st.goal_progress() >= p0 and _pos_moved(fid, m):
				await _swipe_m(m)
				break
		await _wait(0.6)
		var nf := _field_now(fid)
		stays = nf >= 0 and Game.state.satt9(nf) and Game.state.goal_progress() >= p0
		await _shot(dir, "07e_siegel_bleibt")
	_check(seal_ok and stays, "need_seal_stays", "huette=%d siegel=%s bleibt=%s chip=%s" % [fid, str(seal_ok), str(stays), dui.chip_num.text])


## Bewegt die Drehung m das Feld fid? (Dann hat es danach andere Nachbarn.)
func _pos_moved(fid: int, m: Array) -> bool:
	var st: GameState = Game.state.simulate(_twist(int(m[0]), int(m[1]), int(m[2])))["state"]
	var a: FieldData = st.fields[fid]
	var b: FieldData = Game.state.fields[fid]
	return a.p != b.p or a.n != b.n


func _field_now(fid: int) -> int:
	return fid if fid >= 0 and fid < Game.state.fields.size() else -1


## Wasser dreht mit (Spec 10.1): Während eine Scheibe gezogen wird, steht das Wellen-Muster der Kacheln still (es dreht
## mit der Kachel); danach zählt die Deckseite eine Vierteldrehung weiter und alles liegt wieder nahtlos.
func _water_turn_check(dir: String) -> void:
	var cap := Vector3i(0, 1, 0)
	var fid := -1
	for f in Game.state.fields:
		var fd: FieldData = f
		if FieldData.water_family(fd.kind):
			var wf := world.debug_wave_frame(fd.id)
			if not wf.is_empty() and (wf["n"] as Vector3i) == cap:
				fid = fd.id
				break
	world.focus_place(cap)
	await _wait(1.0)
	var r0 := world.wave_rot(cap)
	var w0 := world.debug_wave_frame(fid) if fid >= 0 else {}
	var held := await _drag_hold(1, 1, 1)
	var w1 := world.debug_wave_frame(fid) if fid >= 0 else {}
	await _shot(dir, "09a_wasser_dreht_mit")
	await _drag_release()
	await _settle(8.0)
	await _wait(0.8)
	await _shot(dir, "09b_wasser_danach")
	var r1 := world.wave_rot(cap)
	var frozen := not w0.is_empty() and not w1.is_empty() and ((w0["m"] as Vector4) - (w1["m"] as Vector4)).is_zero_approx()
	_check(fid >= 0 and held and frozen and r1 != r0, "water_turns_with_slice", "feld=%d gehalten=%s steht=%s rot=%d->%d" % [fid, str(held), str(frozen), r0, r1])


# --- Laden, 100 Sekunden, Welt des Tages ----------------------------------------------------------------

func _shop_tour(dir: String) -> void:
	var dui := ui.day_ui
	dui.show_overview(false)
	await _wait(0.8)
	var p0 := Game.points
	var earned := p0 > Balance.POINTS_START
	if Game.points < 400:
		Game.points = 400            # die Tour hat nur ein paar Level gespielt: genug Punkte zum Zeigen
	await _tap(ui.menu_b)
	await _until_shown(ui.menu_card, 3.0)
	await _tap(ui._menu_shop)
	var open := await _until_shown(ui.shop.card, 3.0)
	await _wait(0.4)
	await _shot(dir, "10a_laden")
	var wunder_ids: Array = []
	for it in Game.shop_items("wunder"):
		wunder_ids.append(str((it as Dictionary)["id"]))
	await _tap(ui.shop.tab_btns["hilfe"])
	await _wait(0.5)
	var sh0 := Game.shields()
	var pts0 := Game.points
	await _tap(ui.shop.card_of("schutz"))
	var conf := await _until_shown(ui.shop.confirm, 3.0)
	await _wait(0.3)
	await _shot(dir, "10b_kaufen")
	var line_ok := ui.shop.cf_line.text == "✦ %d → %d" % [pts0, pts0 - 100]
	await _tap(ui.shop.cf_buy)
	await _wait(0.8)
	var bought := Game.shields() == sh0 + 1 and Game.points == pts0 - 100
	await _tap(ui.shop.tab_btns["gott"])
	await _wait(0.6)
	await _tap(ui.shop.card_of("stirnband"))
	await _wait(0.5)
	await _tap(ui.shop.god_act)
	await _until_shown(ui.shop.confirm, 3.0)
	await _tap(ui.shop.cf_buy)
	await _wait(1.0)
	await _shot(dir, "10c_laden_gott")
	var part := Game.owned.has("stirnband") and str(Game.character.get("kopf", "")) == "stirnband"
	_check(earned and open and conf and line_ok and bought and part and wunder_ids.has("regen"),
		"points_shop", "verdient=%d schutz=%d->%d punkte=%d->%d teil=%s wunder=%s" % [p0, sh0, Game.shields(), pts0, Game.points, str(part), str(wunder_ids)])
	ui._close_modal(true)


## 100-Sekunden-Challenge: die Uhr startet erst mit der ersten Drehung; ein Feuer kostet 5 s; die große Wahl-Karte
## hält die Uhr an; kein Tipp, kein Zurück.
func _free100_tour(dir: String) -> void:
	var dui := ui.day_ui
	dui.show_overview(false)
	await _wait(0.6)
	dui.ov_scroll.ensure_control_visible(dui.ov_free)
	await _wait(0.3)
	await _tap(dui.ov_free)
	var fc := await _until_shown(dui.free_card, 3.0)
	await _wait(0.3)
	await _shot(dir, "11a_freies_spiel")
	var row: Button = null
	for c in (dui.free_card.get_meta("body") as Control).get_children():
		if c is Button and str((c as Button).get_meta("explain", "")) == "mode_sek100":
			row = c
	if row != null:
		await _tap(row)
	await _wait(2.0)
	var waits := Game.sek100 and not Game.sek100_running and is_equal_approx(Game.sek100_left, 100.0)
	var no_help := not ui.hint_btn.is_visible_in_tree() and not ui.undo_btn.is_visible_in_tree() and ui.sek_chip.visible
	var mv := Game.state.best_move()
	await _swipe_move(int(mv.get("axis", 0)), int(mv.get("layer", 1)), int(mv.get("turns", 1)))
	await _settle(8.0)
	await _wait(1.0)
	var runs := Game.sek100_running and Game.sek100_left < 100.0
	var l0 := Game.sek100_left
	Game._sek100_fire()           # ein Feuer (wie nach 3 Fehlversuchen)
	var fire_ok := absf((l0 - Game.sek100_left) - 5.0) < 0.3
	Game.pending_choice = {"mini": false}     # die große Wahl-Karte ist offen
	var l1 := Game.sek100_left
	await _wait(1.2)
	var paused := is_equal_approx(l1, Game.sek100_left)
	Game.pending_choice = {}
	await _shot(dir, "11b_100_sekunden")
	Game.sek100_left = 0.5
	await _wait(1.5)
	var over := await _until_shown(ui.over_card, 4.0)
	await _wait(0.6)
	await _shot(dir, "11c_zeit")
	_check(fc and row != null and waits and no_help and runs and fire_ok and paused and over and ui.over_title.text == "Zeit!" and Game.best_for("sek100") >= 0,
		"free_100s", "wartet=%s ohne_hilfe=%s laeuft=%s feuer=%s pause=%s ende=%s" % [str(waits), str(no_help), str(runs), str(fire_ok), str(paused), str(over)])
	ui._close_modal(true)


## Nach Level 30: jeden Tag die Welt des Tages (Heute-Karte → Start-Karte).
func _wdt_tour(dir: String) -> void:
	var dui := ui.day_ui
	Game.debug_open_all = false
	var st: Array = Game.camp["stars"]
	var wk: Array = Game.camp["won_key"]
	for i in st.size():
		if int(st[i]) <= 0:
			st[i] = 1
		if int(wk[i]) < 0:
			wk[i] = Game.today_key()
	Game.camp["pos"] = Campaign.COUNT        # alles geschafft: die Kette ist am Ende (sonst wären Zeitalter verborgen)
	Game.debug_next_day()
	dui.show_overview(false)
	await _wait(1.2)
	var wdt_card := dui.tc_caps.text.begins_with(str(Days.TEXT["wdt"]) + " · ") and dui.tc_go.visible
	await _shot(dir, "12a_welt_des_tages")
	await _tap(dui.tc_go)
	var gcw := await _until_shown(dui.goal_card, 6.0)
	await _wait(0.6)
	await _shot(dir, "12b_welt_des_tages_karte")
	_check(wdt_card and gcw and Game.in_daily_world() and dui.gc_caps.text == dui.tc_caps.text and dui.gc_goal.text != "",
		"daily_world", "heute=%s karte=%s ziel=%s" % [dui.tc_caps.text, dui.gc_caps.text, dui.gc_goal.text])
	ui._close_modal(true)


# --- Die Schöpfung in 7 Tagen: Übersicht, Ziel-Karte, Tag 1 als Tutorial, Sieg, Fehlversuch, Wahl, Krieg, Smog ---

func _days_tour(dir: String) -> void:
	var dui := ui.day_ui
	# Wie ein neuer Spieler: kein Fortschritt, keine gesehenen Hinweise, noch kein eigener Charakter. Die Uhr steht
	# fest auf Montag, 9. November 2026, 17:40 (gleiche Bilder, gleiche Erinnerungs-Zeiten in jedem Lauf)
	Game.debug_open_all = false
	Game.debug_day_offset = 0
	Game.clock_override = Daily.local_unix(2026, 11, 9, 17, 40)
	Game.reset_campaign()
	Game.reset_daily()
	Game.note_session()
	Game.coach_seen = {}
	Game.cards_seen = {}
	Game.tutorial_done = false
	Game.always_ask = false
	Game.reminder_echo = true
	dui.debug_ask_on_pc = true          # die Frage „Soll ich dich erinnern?“ auch am PC zeigen
	await get_tree().process_frame       # was beim Start aufgeschoben wurde, ist durch
	await _creator_tour(dir)
	dui.show_overview(false)
	await _wait(1.4)
	await _shot(dir, "00a_tage")
	var locked := true
	for n in range(2, 8):
		locked = locked and not Game.day_unlocked(n)
	_check(dui.is_open() and dui.ov_tiles.size() == 7 and Game.day_unlocked(1) and locked and not Game.free_play_unlocked()
		and dui.ov_free.text.contains(str(Days.TEXT["free_locked"])), "day_overview", "frei=%d free=%s" % [Game.day_free, dui.ov_free.text])
	# 1. Tag 1 antippen (echte Eingabe): die Ziel-Karte
	await _tap((dui.ov_tiles[0] as Dictionary)["btn"])
	var card1 := await _until_shown(dui.goal_card, 4.0)
	await _wait(0.5)
	await _shot(dir, "00b_tag1_ziel")
	# Die Karte kündigt die Vorführung an („Zeig mir, wie es geht“, „Erst schaust du zu“) und nennt die Regel
	var announced := dui.gc_go.text == str(Days.TEXT["go_demo"]) and dui.gc_new.visible and dui.gc_new_title.text == str(Days.TEXT["demo_title"]) \
		and dui.gc_new_text.text == "3 gleiche in eine Reihe."
	var rule1 := dui.gc_rule.visible and dui.gc_rule_label.text.contains("gerade") and dui.gc_rule_label.text.contains("Wasser")
	_check(card1 and Game.in_day() and Game.day_no == 1 and dui.gc_goal.text == "Lass 8 Wiesen wachsen" and dui.gc_limit.text == "in 15 Drehungen"
		and announced and rule1, "day1_goal_card", "tag=%d ziel=%s grenze=%s knopf=%s angekuendigt=%s regel=%s" % [Game.day_no,
		dui.gc_goal.text, dui.gc_limit.text, dui.gc_go.text, str(announced), dui.gc_rule_label.text])
	# 2. „Los!“: „Schau zu!“ – die Eingabe ist gesperrt, die Hand spielt genau einen Zug vor (die Reihe wächst).
	# Ein Wisch des Spielers in dieser Zeit zählt nicht (echte Eingabe).
	var left0 := Game.state.twists_left()
	world.tour_auto = false
	await _tap(dui.gc_go)
	await _wait(0.2)
	var demo_frech := CharacterTexts.line("d1_demo", "frech")
	var locked0 := ui.input_locked() and dui.lane_caps.text == str(Days.TEXT["demo_caps"]) and Game.state.twists == 0 \
		and dui.lane_label.text == demo_frech
	# Der Hinweis kommt vom eigenen Charakter: sein Kopfbild (die Katze aus dem Ersteller) und sein Ton (frech)
	var lane_cv := ui.speaker_view(dui.lane_speaker)
	_check(dui.lane.visible and dui.lane_speaker.is_visible_in_tree() and str(lane_cv.look.get("basis", "")) == "katze"
		and dui.lane_label.text == demo_frech and lane_cv.portrait, "character_coach",
		"basis=%s text=%s" % [str(lane_cv.look.get("basis", "")), dui.lane_label.text.left(40)])
	var vs0 := get_viewport().get_visible_rect().size
	await _swipe(vs0 * Vector2(0.3, 0.47), vs0 * Vector2(0.7, 0.47))      # während der Sperre: wird ignoriert
	var swipe_ignored := Game.state.twists == 0 and world._touched_state != Game.state
	var demo_seen := false
	var locked_in_demo := false
	for i in 120:
		if ui.tut_finger.modulate.a > 0.8 and world._mode == "twist":
			demo_seen = true
			locked_in_demo = ui.input_locked() and Game.state.twists == 0
			break
		await _wait(0.05)
	await _wait(0.25)
	await _shot(dir, "00c_tag1_hand")
	var hand := dui.lane.visible and Game.day_tutorial()
	for i in 100:
		if Game.state.twists >= 1 and not world._mode == "twist":
			break          # die Vorführung hat ihren Zug gespielt (die Runde läuft jetzt)
		await _wait(0.05)
	await _settle(8.0)
	await _wait(0.5)
	await _shot(dir, "00d_tag1_erste_wiese")
	var p1 := Game.state.goal_progress()
	_check(locked0 and swipe_ignored and demo_seen and locked_in_demo and hand and p1 >= 1 and Game.state.twists == 1
		and Game.state.gift_twists == 1 and dui.chip_num.text == "%d/8" % p1, "day1_tutorial",
		"sperre=%s wisch_ignoriert=%s vorfuehrung=%s gesperrt=%s wiesen=%d chip=%s" % [str(locked0), str(swipe_ignored),
		str(demo_seen), str(locked_in_demo), p1, dui.chip_num.text])
	_check(dui.chip.visible and dui.ring.left == left0 and dui.ring.left == Game.state.twists_left(), "goal_chip",
		"left=%d->%d (die Vorführung kostet nichts)" % [left0, dui.ring.left])
	# „Jetzt du!“: Die Hand ist weg, das Dock mit dem Tipp kommt, der Spieler sucht selbst
	var c1: Array = Days.config(1).get("coach", [])
	var your_turn := false
	for i in 100:
		if dui.lane_visible() and dui.lane_label.text == CharacterTexts.line("d1_c2", "frech") and ui.dock.visible:
			your_turn = true
			break
		await _wait(0.05)
	await _wait(0.4)
	await _shot(dir, "00d2_tag1_jetzt_du")
	_check(your_turn and ui.hint_btn.is_visible_in_tree() and ui.tut_finger.modulate.a < 0.1 and not ui.input_locked(), "day1_your_turn",
		"lane=%s dock=%s sperre=%s" % [dui.lane_label.text.left(30), str(ui.dock.visible), str(ui.input_locked())])
	# Nach der ersten echten Eingabe bewegt sich keine Scheibe mehr von selbst: ein Wisch, der nichts wachsen lässt
	# (früher kam danach alle 4 s die Hand-Drehung, nach 16 s ein Auto-Zug), dann 30 s nichts tun
	await _no_auto_twist_check()
	world.tour_auto = true
	# 3. Den Rest selbst: immer die beste Drehung (wie „Tipp“), echte Wisch-Eingabe, bis das Ziel erreicht ist
	var won := await _play_day(14)
	var wcard := await _until_shown(dui.win_card, 5.0)
	await _wait(2.8)                      # Sterne, dann die Serien-Feier (die Zahl zählt hoch)
	await _shot(dir, "00e_tag1_geschafft")
	var line2 := str(Days.TEXT["tomorrow_next"]) % [2, str(Days.config(2)["title"])]
	_check(won and wcard and Game.state.day_won and Game.stars_of(1) >= 1 and dui.wc_next.text != "Weiterbauen"
		and dui.wc_next_line.visible and dui.wc_next_line.text == line2 and dui.wc_streak_num.text == "1" and Game.streak() == 1,
		"day_success", "won=%s stars=%d drehungen=%d knopf=%s zeile=%s serie=%s" % [str(won), Game.stars_of(1), Game.state.day_won_at,
		dui.wc_next.text, dui.wc_next_line.text, dui.wc_streak_num.text])
	if _only == "day1":
		return
	# 4. „Zur Übersicht“ (echte Eingabe, kein Weiterbauen mehr). Vorher fragt der Charakter einmal, ob er morgen
	# erinnern darf (am Handy kommt danach der Android-Dialog): „Lieber nicht“
	await _tap(dui.wc_home if dui.wc_home.visible else dui.wc_next)
	var ask := await _until_shown(dui.ask_card, 4.0)
	await _wait(0.6)
	await _shot(dir, "00e2_erinnern_frage")
	var ask_ok := ask and dui.ask_text.text == CharacterTexts.fill(str((CharacterTexts.LINES["ask_reminder"] as Dictionary)["frech"]), {"tag": "Tag 2: Pflanzen"})
	await _tap(dui.ask_no)
	await _wait(1.2)
	_check(ask_ok and int(Game.remind["asked"]) == 1 and not dui.ask_card.visible, "permission_ask",
		"frage=%s gefragt=%d" % [dui.ask_text.text.left(40), int(Game.remind["asked"])])
	# 5. Zur Übersicht (Menü, echte Eingabe): Tag 2 ist erst morgen dran (Mond, „Morgen“), die Heute-Karte sagt
	# „Heute geschafft!“ mit der Uhr bis zum neuen Tag, die Woche zeigt die erste Flamme
	await _tap(ui.menu_b)
	await _until_shown(ui.menu_card, 3.0)
	await _wait(0.3)
	await _tap(ui._menu_days)
	await _wait(1.2)
	var t2: Dictionary = dui.ov_tiles[1]
	var morgen := dui.is_open() and bool((t2["btn"] as Button).get_meta("morgen", false)) and (t2["morgen"] as Control).visible \
		and not Game.day_unlocked(2) and dui.tc_title.text == str(Days.TEXT["today_done"]) and dui.tc_count.text != "" \
		and dui.tc_count_row.visible and (dui.week_cells[0] as DayUI.WeekDot).state == "streak"
	await _shot(dir, "00u_morgen")
	await _tap(t2["btn"])
	var toast_ok := false
	for i in 80:
		if ui.toast.visible and (ui.toast_label.text.begins_with("Neuer Tag in") or ui.toast_label.text == str(Days.TEXT["countdown_late"])):
			toast_ok = true
			break
		await _wait(0.05)
	await _wait(0.4)
	await _shot(dir, "00u2_morgen_tippen")
	var said := CharacterTexts.line("day_wait", "frech", {"name": Voice.char_name()})
	_check(morgen and toast_ok and dui.ov_say.text == said, "day_locked_until_tomorrow",
		"morgen=%s toast=%s sagt=%s uhr=%s" % [str(morgen), str(toast_ok), dui.ov_say.text.left(40), dui.tc_count.text])
	# 6. „Nächster Tag (Test)“ (nur in der Test-Version, echte Eingabe): Tag 2 ist offen, die Heute-Karte zeigt ihn
	dui.ov_scroll.ensure_control_visible(dui.ov_debug)
	await _wait(0.4)
	var pill := dui.ov_debug.is_visible_in_tree() and OS.is_debug_build()
	await _tap(dui.ov_debug)
	await _wait(0.9)
	dui.ov_scroll.scroll_vertical = 0
	await _wait(0.5)
	await _shot(dir, "00u3_naechster_tag")
	_check(pill and Game.day_unlocked(2) and dui.tc_caps.text == str(Days.TEXT["today_new"]) and dui.tc_title.text == "Tag 2 · Pflanzen"
		and dui.tc_go.visible and not bool((t2["btn"] as Button).get_meta("morgen", false)) and Game.debug_day_offset == 1
		and (dui.week_cells[1] as DayUI.WeekDot).state == "today", "next_day_debug_unlocks",
		"knopf=%s heute=%s %s versatz=%d" % [str(pill), dui.tc_caps.text, dui.tc_title.text, Game.debug_day_offset])
	# „Los!“ auf der Heute-Karte (echte Eingabe): Ziel-Karte mit dem Neuen (Regen)
	await _tap(dui.tc_go)
	var card2 := await _until_shown(dui.goal_card, 4.0)
	await _wait(0.9)
	await _shot(dir, "00f_tag2_ziel")
	_check(card2 and Game.day_no == 2 and Game.day_unlocked(2) and dui.gc_new.visible and dui.gc_new_title.text == "Neu: Regen", "day_next",
		"tag=%d neu=%s" % [Game.day_no, dui.gc_new_title.text])
	# 5. „Los!“: Der Regen springt auf und fliegt in seinen Platz; ein Hinweis zeigt darauf
	await _tap(dui.gc_go)
	await _wait(0.8)
	await _shot(dir, "00g_tag2_neu")
	var rain_hidden := not ui.rain_btn.is_visible_in_tree()
	await _wait(2.4)
	await _shot(dir, "00h_tag2_regen")
	ui._coach_dismiss()
	await _wait(0.3)
	# Regen auf eine Wiese: Sie wird ein Wald – das zählt für das Ziel
	var w0 := int(Game.state.made[FieldData.FOREST])
	await _tap(ui.rain_btn)
	await _wait(0.5)
	var rt := _rain_target("target", -1, FieldData.MEADOW)
	if int(rt["fid"]) >= 0:
		await _touch(rt["pos"])
		await _wait(0.4)
		await _settle(6.0)
	ui._set_bonus_mode("")
	_check(rain_hidden and ui.rain_btn.is_visible_in_tree() and int(rt["fid"]) >= 0 and int(Game.state.made[FieldData.FOREST]) == w0 + 1
		and Game.state.goal_progress() == w0 + 1, "day2_rain_reveal", "fid=%d wald=%d" % [int(rt["fid"]), int(Game.state.made[FieldData.FOREST])])
	# Hilfe an Tag 2: die Aufgabe und „Was wächst woraus“ (Erde → Wiese → Wald), nichts von später (Glaube, Wahl)
	await _wait(0.6)
	ui.debug_show_help()
	await _wait(0.8)
	await _shot(dir, "00h2_tag2_hilfe")
	var tree_n := ui._help_tree.get_child_count()
	_check(ui.help_card.visible and (ui._help_rows["task"] as Control).visible and (ui._help_rows["tree"] as Control).visible
		and tree_n == 5 and not (ui._help_rows["faith"] as Control).visible and not (ui._help_rows["will"] as Control).visible,
		"day_help", "baum=%d" % tree_n)
	ui._close_modal(true)
	await _wait(0.4)
	# Tag 2: Eine neue Reihe aus drei Wäldern ruht (Großer Wald erst ab Tag 3): leuchtet mit Schloss, sagt warum,
	# und ist kein Fehlversuch
	await _resting_row_check(dir)
	# 5b. Tag 2 schaffen (ein neues Brett, genug Drehungen): Die Serie wächst auf 2, zwei Flammen in der Woche
	await _streak_day2(dir)
	# Ab hier sind alle Tage offen (die Tour springt)
	Game.debug_open_all = true
	Game.round_resolved.connect(_on_tour_round)
	await _no_farming_check(dir)
	var kinds_log: Array = []
	var vis_log: Array = []           # [Tag, verschiedene Arten ohne Wasser] (nicht zu viele auf einmal)
	var chip_log: Array = []
	# 6. Tag 3 (neuer Tag aus der Übersicht): „Neuer Morgen“ (Erde wird Wiese), dann die Blitz-Warnung
	var night3: Array = []
	var night_cb := func(info): night3.append(info)
	Game.overnight_growth.connect(night_cb)
	Game.start_day(3, 0)
	Game.overnight_growth.disconnect(night_cb)
	kinds_log.append(_growable(Game.state))
	vis_log.append([Game.day_no, Days.visible_kinds(_kinds_of(Game.state))])
	await _until_shown(dui.goal_card, 4.0)
	await _wait(0.9)
	await _shot(dir, "00i_tag3_ziel")
	await _tap(dui.gc_go)
	var night_pill := false
	for i in 60:
		if ui.banner.visible and ui.banner_caps.text == str(Days.TEXT["overnight"]) and ui.banner_text.text == "Erde wird Wiese":
			night_pill = true
			break
		await _wait(0.05)
	await _wait(0.35)
	await _shot(dir, "00i2_tag3_ueber_nacht")
	var ch3: Array = (night3[0] as Dictionary).get("changes", []) if not night3.is_empty() else []
	await _wait(2.2)
	# Die Welle: alle Felder von gestern sind jetzt in ihrer neuen Art zu sehen
	var wave_ok := not world.night_pending() and world.night_waved == ch3.size()
	for c in ch3:
		var cfid := int((c as Dictionary)["field"])
		if (world.views[cfid] as FieldView).get_kind() != (Game.state.fields[cfid] as FieldData).kind:
			wave_ok = false
	_check(night_pill and wave_ok and ch3.size() == mini(Days.OVERNIGHT_MAX, Game.state.count(FieldData.MEADOW)) and not ch3.is_empty() and int((ch3[0] as Dictionary)["from"]) == FieldData.EMPTY,
		"overnight_growth", "pille=%s welle=%d/%d wiesen=%d" % [str(night_pill), world.night_waved, ch3.size(), Game.state.count(FieldData.MEADOW)])
	chip_log.append(_chip_ok(3))
	world.focus_place(Vector3i(0, 1, 0))
	_round_types = {}
	await _swipe_move(0, 1, 1)
	await _settle(8.0)
	var bolt3 := Game.state.bolt
	var warn3 := bolt3 >= 0 and GameState.BOLT_KINDS8.has((Game.state.fields[bolt3] as FieldData).kind)
	var warn_pill := _seen_type("bolt_warn")
	await _shot(dir, "00i3_tag3_blitz")
	# die nächste Drehung, nach der der Blitz wirklich einschlägt (das Feld bleibt Wald/Tiere)
	var bm := [1, -1, 1]
	for m in GameState.MOVES:
		var r3: Dictionary = Game.state.simulate(_twist(int(m[0]), int(m[1]), int(m[2])))
		var hit := false
		for e in (r3.get("result", {}) as Dictionary).get("events", []):
			if str((e as Dictionary).get("type", "")) == "bolt":
				hit = true
		if hit:
			bm = m
			break
	_round_types = {}
	await _swipe_move(int(bm[0]), int(bm[1]), int(bm[2]))
	await _settle(8.0)
	var burns3 := (bolt3 >= 0 and (Game.state.fields[bolt3] as FieldData).burning) or _seen_type("bolt")
	await _shot(dir, "00i4_tag3_feuer")
	_check(warn3 and warn_pill and burns3, "bolt_warn", "blitz=%d warnung=%s brennt=%s" % [bolt3, str(warn_pill), str(burns3)])
	# … dann bringt die letzte Drehung nichts → gescheitert, „Nochmal“ mit +2 Drehungen (ohne „Neuer Morgen“)
	Game.state.day_limit = Game.state.twists + 1      # nur noch eine Drehung
	Game.state_changed.emit()
	await _wait(0.4)
	var b0 := int(Game.day_board.get("index", 0))
	var dud := _twist_without_progress()
	await _swipe_move(int(dud[0]), int(dud[1]), int(dud[2]))
	await _settle(8.0)
	var fcard := await _until_shown(dui.fail_card, 5.0)
	await _wait(0.4)
	await _shot(dir, "00j_fehlversuch")
	var lost := Game.state.day_lost
	var mercy_line := dui.fc_mercy.visible and dui.fc_mercy.text == str(Days.TEXT["mercy_next"]) % 2
	await _tap(dui.fc_again)
	var card3 := await _until_shown(dui.goal_card, 4.0)
	_check(fcard and lost == "twists" and mercy_line and card3 and Game.day_no == 3 and int(Game.day_board.get("index", -1)) == b0 + 1
		and Game.state.day_limit == int(Days.config(3)["limit"]) + 2 and dui.gc_mercy.visible and Game.overnight.is_empty(), "day_fail",
		"lost=%s brett=%d->%d grenze=%d nacht=%s" % [lost, b0, int(Game.day_board.get("index", -1)), Game.state.day_limit, str(Game.overnight.is_empty())])
	ui._close_modal(true)
	# 7. Tag 4 Brett 0: Menschen. Die erste Lösungs-Drehung: 3 Tiere → 1 Hütte (Feld 8), 23 und 24 werden Wiese,
	# die Hütte ist satt (neben anderen Tieren). Dann die ganze Lösung: geschafft (kein Weiterbauen mehr)
	Game.start_day(4, 0)
	kinds_log.append(_growable(Game.state))
	vis_log.append([Game.day_no, Days.visible_kinds(_kinds_of(Game.state))])
	await _until_shown(dui.goal_card, 4.0)
	await _wait(0.6)
	await _shot(dir, "00k_tag4_ziel")
	await _tap(dui.gc_go)
	await _wait(4.4)
	chip_log.append(_chip_ok(4))
	var sol4: Array = Game.day_board["solution"]
	_round_types = {}
	await _play_solution(sol4, 1)
	var gs4 := Game.state
	var hut8 := gs4.fields[8] as FieldData
	await _shot(dir, "00k2_tag4_huette")
	_check(hut8.kind == FieldData.HUT and (gs4.fields[23] as FieldData).kind == FieldData.MEADOW and (gs4.fields[24] as FieldData).kind == FieldData.MEADOW
		and gs4.satt(hut8) and _seen_type("consume"), "consume_hut", "8=%d 23=%d 24=%d satt=%s" % [hut8.kind, (gs4.fields[23] as FieldData).kind,
		(gs4.fields[24] as FieldData).kind, str(gs4.satt(hut8))])
	await _play_solution(sol4.slice(1), 99)
	var wc4 := await _until_shown(dui.win_card, 8.0)
	await _wait(2.0)
	var won4 := Game.state.day_won
	# Build 12: kein Weiterbauen – auf der Sieg-Karte gibt es keinen Knopf dafür
	var no_build4 := not [dui.wc_next.text, dui.wc_alt.text, dui.wc_home.text].has("Weiterbauen")
	await _shot(dir, "00k3_tag4_geschafft")
	_check(won4 and wc4 and no_build4 and not Game.state.day_free_build, "day4_won",
		"gewonnen=%s knopf=%s/%s" % [str(won4), dui.wc_next.text, dui.wc_alt.text])
	ui._close_modal(true)
	await _wait(0.6)
	# 8. Tag 5 Brett 0: Arbeit. Beim Ziehen einer Drehung zeigt die Vorschau ein Feld als satt (grüner Rand, Chip „0→1“);
	# nach dem Loslassen ist es satt
	Game.start_day(5, 0)
	kinds_log.append(_growable(Game.state))
	vis_log.append([Game.day_no, Days.visible_kinds(_kinds_of(Game.state))])
	await _until_shown(dui.goal_card, 4.0)
	await _wait(0.6)
	await _shot(dir, "00l_tag5_ziel")
	await _tap(dui.gc_go)
	await _wait(4.4)
	chip_log.append(_chip_ok(5))
	var sm := await _pick_supply_move()
	var mv5: Array = sm.get("move", [1, 0, -1])
	var f10 := int(sm.get("field", -1))
	var pv: Dictionary = Game.preview(int(mv5[0]), int(mv5[1]), int(mv5[2]))
	var sup: Dictionary = pv.get("supply", {})
	var pre10 := f10 >= 0 and (sup.get("satt_new", []) as Array).has(f10)
	_round_types = {}
	# Echte Eingabe: Finger zieht die Scheibe und bleibt liegen → das Feld bekommt den grünen Rand (wird satt)
	var held := await _drag_hold(int(mv5[0]), int(mv5[1]), int(mv5[2]))
	var mark10 := f10 >= 0 and (world.views[f10] as FieldView).supply_mode() == 1
	var marks := 0
	for fid in world.views:
		if (world.views[fid] as FieldView).supply_mode() != 0:
			marks += 1
	await _shot(dir, "00l1_tag5_vorschau")
	await _drag_release()
	await _settle(8.0)
	var marks_gone := true
	for fid in world.views:
		if (world.views[fid] as FieldView).supply_mode() != 0:
			marks_gone = false
	_check(held and mark10 and marks == (sup.get("satt_new", []) as Array).size() + (sup.get("satt_lost", []) as Array).size() and marks_gone,
		"supply_preview", "gehalten=%s feld%d=%s marken=%d weg=%s zug=%s" % [str(held), f10, str(mark10), marks, str(marks_gone), str(mv5)])
	await _shot(dir, "00l2_tag5_satt")
	_check(pre10 and Game.state.satt(Game.state.fields[f10]) and _seen_type("satt_new"), "thrive_preview",
		"vorschau=%s satt=%s" % [str(sup.get("satt_new", [])), str(Game.state.satt(Game.state.fields[f10]) if f10 >= 0 else false)])
	# 9. Tag 6 Brett 0: Glaube. Eine Drehung würde zwei Kirchen zusammenbringen (Vorschau: Schwerter) → „Krieg droht!“;
	# ein Meteor (12 Glauben, Platz des Gewitters) auf eine der Kirchen trennt sie
	Game.start_day(6, 0)
	kinds_log.append(_growable(Game.state))
	vis_log.append([Game.day_no, Days.visible_kinds(_kinds_of(Game.state))])
	await _until_shown(dui.goal_card, 4.0)
	await _wait(0.6)
	await _shot(dir, "00m_tag6_ziel")
	await _tap(dui.gc_go)
	await _wait(4.4)
	chip_log.append(_chip_ok(6))
	var wm6 := [0, -1, 1]
	var war_moves := 0
	for m in GameState.MOVES:
		if bool((Game.preview(int(m[0]), int(m[1]), int(m[2])).get("supply", {}) as Dictionary).get("war_risk", false)):
			if war_moves == 0:
				wm6 = m
			war_moves += 1
	var pv6: Dictionary = Game.preview(int(wm6[0]), int(wm6[1]), int(wm6[2])).get("supply", {})
	_round_types = {}
	await _swipe_move(int(wm6[0]), int(wm6[1]), int(wm6[2]))
	await _shot_on_banner(dir, "00n_tag6_krieg", str(Days.TEXT["war_start"]), 8.0)      # die Pille „Krieg droht!“
	await _settle(8.0)
	var war_pill := _seen_type("war_start")
	var ch6a: Array = Game.state.church_touch8()
	if not ch6a.is_empty():
		world.focus_field(int(ch6a[0]))      # die Front zeigen (roter Rand, Rauch, fliehende Menschen)
		await _wait(1.2)
	await _shot(dir, "00n2_tag6_front")
	_check(bool(pv6.get("war_risk", false)) and war_moves >= 1 and Game.state.war_on and war_pill and Game.state.day_lost == "",
		"war_preview", "vorschau=%s züge=%d krieg=%s" % [str(pv6.get("war_risk", false)), war_moves, str(Game.state.war_on)])
	var ch6: Array = Game.state.church_touch8()
	Game.state.faith = GameState.METEOR_COST
	Game.state_changed.emit()
	await _wait(0.8)
	var strike_on := ui.strike_btn.is_visible_in_tree()
	var met_ok := false
	if not ch6.is_empty():
		met_ok = Game.use_bonus("strike", int(ch6[0]), [], true)
		await _settle(8.0)
	await _shot(dir, "00o_tag6_meteor")
	_check(strike_on and met_ok and Game.state.church_touch8().is_empty() and Game.state.faith == 0, "meteor",
		"knopf=%s kirchen=%s" % [str(strike_on), str(Game.state.church_touch8())])
	# 10. Tag 7 Brett 0: eine Drehung bringt zu viel Stadt auf eine Seite → „Das Meer steigt!“
	Game.start_day(7, 0)
	kinds_log.append(_growable(Game.state))
	vis_log.append([Game.day_no, Days.visible_kinds(_kinds_of(Game.state))])
	await _until_shown(dui.goal_card, 4.0)
	await _wait(0.6)
	await _shot(dir, "00p_tag7_ziel")
	await _tap(dui.gc_go)
	await _wait(4.4)
	chip_log.append(_chip_ok(7))
	await _look_shots(dir)
	var fm := [0, -1, 1]
	var fc7 := -1
	for m in GameState.MOVES:
		var st7: GameState = Game.state.simulate(_twist(int(m[0]), int(m[1]), int(m[2])))["state"]
		if not st7.flood_warn.is_empty():
			fm = m
			fc7 = int(st7.flood_warn.keys()[0])
			break
	_round_types = {}
	await _swipe_move(int(fm[0]), int(fm[1]), int(fm[2]))
	await _shot_on_banner(dir, "00q_tag7_flut", str(Days.TEXT["flood_warn"]), 8.0)      # die Pille „Das Meer steigt!“
	await _settle(8.0)
	var flood_pill := _seen_type("flood_warn")
	if fc7 >= 0:
		world.focus_place(GameState.FACE_NORMALS[fc7])      # die Seite, an der das Meer steigt
	await _wait(1.2)
	await _shot(dir, "00q2_tag7_flut_seite")
	var w7 := Game.state.city_weight8(fc7) if fc7 >= 0 else 0
	_check(fc7 >= 0 and w7 >= int(Game.state.day.get("flood_at", 5)) and Game.state.flood_warn.has(fc7) and flood_pill, "flood_warn",
		"seite=%d gewicht=%d warnung=%s" % [fc7, w7, str(Game.state.flood_warn.keys())])
	var vis_ok := vis_log.size() == 5
	for vl in vis_log:
		if int((vl as Array)[1]) > int(Days.VISIBLE_MAX[int((vl as Array)[0])]):
			vis_ok = false
	_check(kinds_log.size() == 5 and _max_size(kinds_log) <= 3 and vis_ok, "kinds_per_day", "arten=%s sichtbar=%s" % [str(kinds_log), str(vis_log)])
	_check(chip_log.size() == 5 and not chip_log.has(false), "task_chip", "chips=%s" % str(chip_log))
	# 11. Tag 7 schaffen (seine Lösung, echte Eingabe): Die Welt ist vollendet, das freie Spiel geht auf
	Game.start_day(7, 0)
	await _until_shown(dui.goal_card, 4.0)
	await _tap(dui.gc_go)
	await _wait(4.4)
	await _play_solution(Game.day_board["solution"], 99)
	var wc7 := await _until_shown(dui.win_card, 8.0)
	await _wait(1.6)
	await _shot(dir, "00r_vollendet")
	_check(wc7 and dui.wc_title.text == str(Days.TEXT["complete"]) and Game.world_done and Game.free_play_unlocked()
		and dui.wc_next.text == str(Days.TEXT["to_overview"]) and dui.wc_alt.text == str(Days.TEXT["free"]), "world_complete",
		"titel=%s" % dui.wc_title.text)
	# 11. „Freies Spiel“ (echte Eingabe): die vier Spielarten, Mittel antippen
	await _tap(dui.wc_alt)
	var fc := await _until_shown(dui.free_card, 4.0)
	await _wait(0.6)
	await _shot(dir, "00s_freies_spiel")
	var row: Button = null
	for c in (dui.free_card.get_meta("body") as Control).get_children():
		if c is Button and (c as Button).has_meta("free_row") and str((c as Button).get_meta("explain", "")) == "mode_mittel":
			row = c
	if row != null:
		await _tap(row)
	await _wait(1.6)
	await _shot(dir, "00t_frei_mittel")
	_check(fc and row != null and not Game.in_day() and Game.state.endless and Game.level == 1 and not dui.is_open() and ui.score_box.visible,
		"free_play", "tag=%s stufe=%d" % [str(Game.in_day()), Game.level])
	# 12. Am Spieltag nach Tag 7: die Welt des Tages (Heute-Karte, echte Eingabe „Los!“ → ihre Ziel-Karte)
	Game.debug_open_all = false
	for i in Game.day_stars.size():        # die Tour hat die Tage 3–6 nur angespielt: als gewonnen zählen
		if int(Game.day_stars[i]) <= 0:
			Game.day_stars[i] = 1
	Game.debug_next_day()
	dui.show_overview(false)
	await _wait(1.2)
	var wdt_card := dui.tc_caps.text.begins_with(str(Days.TEXT["wdt"]) + " · ") and dui.tc_go.visible
	await _shot(dir, "00x_welt_des_tages")
	await _tap(dui.tc_go)
	var gcw := await _until_shown(dui.goal_card, 4.0)
	await _wait(0.6)
	await _shot(dir, "00x2_welt_des_tages_ziel")
	_check(wdt_card and gcw and Game.in_daily_world() and dui.gc_caps.text == dui.tc_caps.text and dui.gc_goal.text != "",
		"daily_world", "heute=%s karte=%s ziel=%s" % [dui.tc_caps.text, dui.gc_caps.text, dui.gc_goal.text])
	ui._close_modal(true)
	await _bonus_round_tour(dir)


# --- Eine lange Runde bleibt bedienbar (Bericht „hat sich aufgehängt in der Bonusrunde“) ---------------------------

## Misst die Rechenzeit des Spiels je Bild: vom Signal process_frame (danach laufen die wartenden Suchen weiter) bis
## zum Ende aller _process (diese Sonde läuft als letzte). Ohne die Software-Grafik der Tour und ohne die Tour selbst
## (ihre Schritte laufen in Timern, nach _process).
class FrameProbe extends Node:
	var on := false
	var frames := 0
	var max_usec := 0
	var slow := 0
	var max_wall := 0
	var _t0 := 0
	var _last := 0

	func _ready() -> void:
		process_priority = 1 << 30
		get_tree().process_frame.connect(_begin)

	func _begin() -> void:
		_t0 = Time.get_ticks_usec()

	func _process(_delta: float) -> void:
		if not on or _t0 == 0:
			return
		var now := Time.get_ticks_usec()
		var dt := now - _t0
		max_usec = maxi(max_usec, dt)
		if dt > 250000:
			slow += 1
		if _last > 0:
			max_wall = maxi(max_wall, now - _last)
		_last = now
		frames += 1


## Ein Feld, auf das das Werkzeug (Regen, Meteor) gerade darf und das auf dem Bildschirm frei liegt. {"fid", "pos"}
func _tool_target(kind: String) -> Dictionary:
	var mid := get_viewport().get_visible_rect().size * 0.5
	var best := -1
	var best_pos := Vector2.ZERO
	var best_d := INF
	for f in Game.state.fields:
		var fd: FieldData = f
		if Game.state.can_bonus(kind, fd) != "":
			continue
		var fs := world.field_screen(fd.id)
		if not bool(fs["visible"]):
			continue
		var pos: Vector2 = fs["pos"]
		if _under_ui(pos) or int((world._raycast(pos) as Dictionary).get("field", -1)) != fd.id:
			continue
		if pos.distance_to(mid) < best_d:
			best_d = pos.distance_to(mid)
			best = fd.id
			best_pos = pos
	return {"fid": best, "pos": best_pos}


## Wie _tool_target; liegt kein passendes Feld frei, dreht sich die Ansicht zu einem (wie ein Spieler, der den Würfel
## dreht).
func _visible_target(kind: String) -> Dictionary:
	var t := _tool_target(kind)
	if int(t["fid"]) >= 0:
		return t
	var tries := 0
	for f in Game.state.fields:
		if tries >= 6:
			break
		if Game.state.can_bonus(kind, f as FieldData) == "":
			tries += 1
			world.focus_field((f as FieldData).id)
			await _wait(1.4)
			t = _tool_target(kind)
			if int(t["fid"]) >= 0:
				return t
	return t


## Gerade frei für den Spieler: keine Runde, keine Animation, keine Karte, kein Werkzeug gewählt, keine Suche.
func _input_free() -> bool:
	return not Game.busy and not world.animating and world._mode == "" and not ui._blocked() and not ui.day_ui.blocking() \
		and not ui.modal_bg.visible and ui._hint_job < 0 and ui.bonus_mode == ""


var _bonus_seen: Array = []


func _on_bonus_round(result: Dictionary, _before: Dictionary) -> void:
	if result.has("bonus"):
		_bonus_seen.append(str((result["bonus"] as Dictionary).get("kind", "")))


## Tag 6 schaffen, „Weiterbauen“ (echte Eingabe), dann wie ein Spieler, der lange weiterbaut: 40 echte Wische,
## Regen und Meteor über Dock und Feld, Tipp, eine lange Pause, Menü auf und zu, „Zurück“. Danach nimmt das Spiel
## noch jede Eingabe an (Wisch, Werkzeug), und kein Bild hat lange gerechnet (Rechenzeit des Spiels je Bild).
const BONUS_SWIPES := 12        # echte Wische in der langen Runde (Software-Grafik: ~6 s je Wisch; kurz gehalten, damit die
                                # ganze Tour in der CI unter 55 Minuten bleibt)


func _bonus_round_tour(dir: String) -> void:
	var dui := ui.day_ui
	var open0 := Game.debug_open_all
	Game.debug_open_all = true
	if Balance.CAMPAIGN_ON:
		Game.start_level(26, 0)
	else:
		Game.start_day(6, 0)
	await _until_shown(dui.goal_card, 8.0)
	await _tap(dui.gc_go)
	await _wait(4.4)
	ui._coach_dismiss()
	await _settle(6.0)
	# Kein Weiterbauen mehr (Build 12): die lange Runde ist ein langes, ungelöstes Level (Zufallswische)
	var building := Game.in_day() and not Game.state.day_won and not Game.onboarding
	var gs := Game.state
	var tw0 := gs.twists
	# Software-Grafik schafft ~2 Bilder je Sekunde: die Suche darf je Bild mehr rechnen (sonst dauert ein Tipp eine
	# Minute), und die 3D-Welt wird hier mit Viertel-Auflösung gerechnet (die Bilder am Ende wieder mit halber)
	var budget0: int = Game.hint_budget_usec
	Game.hint_budget_usec = 60000
	var scale0 := get_viewport().scaling_3d_scale
	get_viewport().scaling_3d_scale = 0.25
	var probe := FrameProbe.new()
	add_child(probe)
	_bonus_seen = []
	Game.round_resolved.connect(_on_bonus_round)
	probe.on = true
	var t0 := Time.get_ticks_msec()
	# 40 echte Wische: meist zufällig, jeder vierte die beste Drehung
	var rng := RandomNumberGenerator.new()
	rng.seed = 606
	var swiped := 0
	var twisted_before := 0
	for i in BONUS_SWIPES:
		var m: Array = GameState.MOVES[rng.randi_range(0, GameState.MOVES.size() - 1)]
		if i % 4 == 3:
			var act := Game.state.best_move()
			if not act.is_empty():
				m = [int(act["axis"]), int(act["layer"]), int(act["turns"])]
		if Game.state.day_won or Game.over:
			# zufällig gelöst: „Nochmal“ (echte Eingabe) und auf einem neuen Versuch weiterwischen
			twisted_before += gs.twists - tw0
			await _bonus_again()
			gs = Game.state
			tw0 = gs.twists
		if await _swipe_move(int(m[0]), int(m[1]), int(m[2])):
			swiped += 1
		await _settle(8.0)
		if dui.ask_card.visible:
			await _tap(dui.ask_no)
			await _wait(0.6)
		ui._coach_dismiss()
	var twisted := twisted_before + gs.twists - tw0
	# Regen über das Dock auf ein Feld, auf das er darf (echte Eingabe)
	Game.state.rain = maxi(Game.state.rain, 2)
	Game.state_changed.emit()
	await _wait(0.4)
	await _tap(ui.rain_btn)
	await _wait(0.5)
	var rain_mode := ui.bonus_mode == "rain"
	var rt := await _visible_target("rain")
	var rain_left := Game.state.rain
	if int(rt["fid"]) >= 0:
		await _touch(rt["pos"])
		await _wait(0.4)
		await _settle(8.0)
	var rain_info := "%d:%d->%d" % [int(rt["fid"]), rain_left, Game.state.rain]
	ui._set_bonus_mode("")
	# Meteor (12 Glauben) über das Dock: ein Feld antippen (zeigt, was getroffen wird), noch einmal tippen bestätigt
	if Game.state.camp:
		Game.state.meteors = maxi(Game.state.meteors, 1)
	else:
		Game.state.faith = maxi(Game.state.faith, GameState.METEOR_COST)
	Game.state_changed.emit()
	await _wait(0.4)
	await _tap(ui.strike_btn)
	await _wait(0.5)
	var strike_mode := ui.bonus_mode == "strike"
	var mt := await _visible_target("strike")
	if int(mt["fid"]) >= 0:
		await _touch(mt["pos"])
		await _wait(0.5)
		await _touch(mt["pos"])
		await _wait(0.4)
		await _settle(8.0)
	ui._set_bonus_mode("")
	await _settle(4.0)
	var rained := _bonus_seen.has("rain")
	var struck := _bonus_seen.has("strike") or _bonus_seen.has("meteor")
	# Tipp (die Suche läuft verteilt über mehrere Bilder), dann eine lange Pause wie ein Spieler, der überlegt
	await _tap(ui.hint_btn)
	var hint_done := false
	for i in 600:
		await _wait(0.05)
		if ui._hint_job < 0:
			hint_done = true
			break
	await _wait(7.0)
	ui._set_bonus_mode("")
	# Menü auf und zu (echte Eingabe)
	await _tap(ui.menu_b)
	var menu_open := await _until_shown(ui.menu_card, 3.0)
	await _wait(0.3)
	await _tap(ui._menu_cont)
	await _wait(1.0)
	var menu_closed := not ui.modal_bg.visible and not dui.is_open()
	# „Zurück“ (nimmt den letzten Zug zurück): danach darf nichts gesperrt bleiben
	var m1: Array = GameState.MOVES[rng.randi_range(0, GameState.MOVES.size() - 1)]
	await _swipe_move(int(m1[0]), int(m1[1]), int(m1[2]))
	await _settle(8.0)
	var undone := false
	if Game.can_undo():
		Game.undo()
		undone = true
	await _wait(1.0)
	await _settle(6.0)
	# Nimmt das Spiel noch Eingaben an? Ein echter Wisch dreht, Regen im Dock lässt sich wählen
	var free_now := _input_free()
	var tw1 := Game.state.twists
	var m2: Array = GameState.MOVES[rng.randi_range(0, GameState.MOVES.size() - 1)]
	await _swipe_move(int(m2[0]), int(m2[1]), int(m2[2]))
	await _settle(8.0)
	var accepted := Game.state.twists == tw1 + 1
	Game.state.rain = maxi(Game.state.rain, 1)
	Game.state_changed.emit()
	await _wait(0.3)
	await _tap(ui.rain_btn)
	await _wait(0.4)
	var tool_ok := ui.bonus_mode == "rain"
	ui._set_bonus_mode("")
	await _wait(0.3)
	probe.on = false
	Game.round_resolved.disconnect(_on_bonus_round)
	Game.hint_budget_usec = budget0
	get_viewport().scaling_3d_scale = scale0
	var secs := float(Time.get_ticks_msec() - t0) / 1000.0
	var frames_ok := probe.frames > 100 and probe.max_usec < 250000
	await _wait(0.6)
	await _shot(dir, "00z_lange_runde_bedienbar")
	_check(building and swiped >= BONUS_SWIPES - 2 and twisted >= BONUS_SWIPES - 2 and rain_mode and rained and strike_mode and struck and hint_done and menu_open
		and menu_closed and undone and free_now and accepted and tool_ok and frames_ok and Game.in_day() and not Game.over,
		"bonus_round_responsive", ("lange_runde=%s wische=%d gedreht=%d regen=%s/%s/%s meteor=%s/%s werkzeuge=%s tipp=%s menue=%s/%s " +
		"zurueck=%s frei=%s wisch_danach=%s werkzeug=%s bilder=%d rechnen_max=%.0fms langsam=%d bild_max=%.0fms zeit=%.0fs") % [str(building),
		swiped, twisted, str(rain_mode), str(rained), rain_info, str(strike_mode), str(struck), str(_bonus_seen), str(hint_done), str(menu_open),
		str(menu_closed), str(undone), str(free_now), str(accepted), str(tool_ok), probe.frames, float(probe.max_usec) / 1000.0,
		probe.slow, float(probe.max_wall) / 1000.0, secs])
	probe.queue_free()
	Game.debug_open_all = open0


## Lange Runde: das Level war zufällig gelöst – Sieg-Karte „Nochmal“ (oder die Karte schließen und neu starten).
func _bonus_again() -> void:
	var dui := ui.day_ui
	await _until_shown(dui.win_card, 6.0)
	await _wait(1.0)
	var again: Button = null
	for b in [dui.wc_next, dui.wc_alt]:
		if (b as Button).visible and str((b as Button).get_meta("act", "")) == "again":
			again = b
	if again != null:
		await _tap(again)
		await _wait(0.8)
		if dui.ask_card.visible:
			await _tap(dui.ask_no)
			await _wait(0.6)
	if not Game.in_day() or Game.state.day_won:
		ui._close_modal(true)
		Game.start_level(Game.level_no, 0)
	await _until_shown(dui.goal_card, 8.0)
	await _tap(dui.gc_go)
	await _wait(3.0)
	ui._coach_dismiss()
	await _settle(6.0)


## Erster Start: Der Ersteller kommt vor Tag 1. Vier Schritte mit echter Eingabe (Würfeln, Katzengott, Farbe,
## Krone, Ton „Frech“), „Fertig – los geht's!“ speichert [charakter] und öffnet die Ziel-Karte von Tag 1.
func _creator_tour(dir: String) -> void:
	var dui := ui.day_ui
	var cc := dui.creator
	Game.set_character({})
	ui.refresh_speakers()
	if Balance.CAMPAIGN_ON:
		Game.start_level(1)              # wie beim ersten Start: Level 1 läuft schon, die Start-Karte wartet
	else:
		Game.start_day(1)                # wie beim ersten Start: Tag 1 läuft schon, die Ziel-Karte wartet
	dui.open_creator(false, true)
	await _wait(1.4)
	var opened := cc.visible and cc.step == 0 and Game.needs_creator() and not dui.goal_card.visible
	await _shot(dir, "00_charakter_1")
	var t_start := Time.get_ticks_msec()
	var before := cc.current_look()
	await _tap(cc.dice_button())
	await _wait(0.6)
	var rolled := cc.current_look() != before
	var cat_b := cc.pick_button("basis:katze")
	if cat_b != null:
		await _tap(cat_b)
	await _wait(0.6)
	var cat := str(cc.current_look()["basis"]) == "katze"
	await _tap(cc.next_button())
	await _wait(0.8)
	var s2 := cc.step == 1
	var sw: Array = cc.pick_buttons("farbe:haupt:")
	if sw.size() > 2:
		await _tap(sw[2])
	await _wait(0.6)
	await _shot(dir, "00_charakter_2")
	await _tap(cc.next_button())
	await _wait(0.8)
	var crown := cc.pick_button("kopf:krone")
	if crown != null:
		cc._scroll.ensure_control_visible(crown)
		await _wait(0.3)
		await _tap(crown)
	await _wait(0.6)
	var has_crown := str(cc.current_look()["kopf"]) == "krone"
	await _shot(dir, "00_charakter_3")
	await _tap(cc.next_button())
	await _wait(0.8)
	var frech := cc.pick_button("ton:frech")
	if frech != null:
		await _tap(frech)
	await _wait(1.0)
	var sample := cc.bubble_text() == str(Character.TONE_SAMPLE["frech"])
	await _shot(dir, "00_charakter_4")
	await _tap(cc.next_button())
	var card := await _until_shown(dui.goal_card, 6.0)
	var secs := (Time.get_ticks_msec() - t_start) / 1000.0
	await _wait(0.5)
	await _shot(dir, "00_charakter_5_tag1")
	var saved := Character.load_look()
	_check(opened and rolled and cat and s2 and has_crown and sample and card and not cc.visible and not Game.needs_creator()
		and str(saved.get("basis", "")) == "katze" and str(saved.get("ton", "")) == "frech" and str(saved.get("kopf", "")) == "krone"
		and Game.in_day() and (Game.day_no == 1 or Game.level_no == 1) and dui.gc_intro.text.contains(Voice.char_name()), "creator_finish",
		"offen=%s gewuerfelt=%s katze=%s krone=%s probe=%s karte=%s name=%s sek=%.0f intro=%s" % [str(opened), str(rolled), str(cat),
		str(has_crown), str(sample), str(card), Voice.char_name(), secs, dui.gc_intro.text.left(40)])
	ui._close_modal(true)


## Tag 2 auf einem neuen Brett schaffen (am zweiten Spieltag): Die Serie zählt von 1 auf 2, die Woche zeigt zwei
## Flammen. Danach: der Erinnerungs-Plan (4 Stufen, Zeiten, Texte) und die Einstellung „Erinnerung“ im Menü.
func _streak_day2(dir: String) -> void:
	var dui := ui.day_ui
	Game.retry_day()
	await _until_shown(dui.goal_card, 4.0)
	await _tap(dui.gc_go)
	await _wait(1.0)
	Game.state.day_limit = Game.state.used_twists() + 30        # genug Drehungen: hier geht es um die Serie
	Game.state_changed.emit()
	var s0 := Game.streak()
	var won := await _play_day(40)
	var wcard := await _until_shown(dui.win_card, 6.0)
	await _wait(3.0)
	await _shot(dir, "00w_serie")
	var flames := 0
	for c in dui.wc_week:
		if (c as DayUI.WeekDot).state == "streak":
			flames += 1
	_check(won and wcard and s0 == 1 and Game.streak() == 2 and dui.wc_streak_num.text == "2" and flames == 2
		and dui.wc_say.text == CharacterTexts.line("streak_n", "frech", {"streak": 2}), "streak_increments",
		"gewonnen=%s karte=%s serie=%d->%d zahl=%s flammen=%d sagt=%s" % [str(won), str(wcard), s0, Game.streak(), dui.wc_streak_num.text,
		flames, dui.wc_say.text.left(40)])
	# Der Plan nach dem Sieg: 4 Stufen (morgen, übermorgen, +4, +7 = Abschied), 30 min vor der Uhrzeit, zu der diese
	# Sitzung begann (17:40), nie zwischen 21:30 und 8:00; die Hülle (Notifier) hat jede Zeile eingeplant
	var plan: Array = Game.reminder_log
	var ids: Array = []
	var cats: Array = []
	var tpls := {}
	var in_window := true
	for e in plan:
		var d: Dictionary = e
		ids.append(int(d["id"]))
		cats.append(str(d["cat"]))
		tpls[str(d["tpl"])] = true
		var m := int(d["hour"]) * 60 + int(d["minute"])
		in_window = in_window and m >= Balance.REMIND_EARLIEST and m <= Balance.REMIND_LATEST
	var first: Dictionary = plan[0] if not plan.is_empty() else {}
	var logged := true
	for e in plan:
		logged = logged and ui.notifier.log_lines.has(ReminderPlan.log_line(e as Dictionary))
	var final_ok := not plan.is_empty() and str((plan[plan.size() - 1] as Dictionary)["tpl"]) == ReminderPlan.final_id("frech")
	var a_time := "%02d:%02d" % [int(first.get("hour", -1)), int(first.get("minute", -1))]
	var ok_plan := ids == [101, 102, 104, 107] and cats == ["A", "B", "C", "F"] and tpls.size() == 4 and in_window and final_ok \
		and a_time == "17:10" and str(first.get("title", "")) == Voice.char_name() and int(first.get("key", -1)) == Game.today_key() + 1 and logged
	# Menü → Erinnerung: am PC der Hinweis „nur auf dem Handy“; „Feste Uhrzeit“ (echte Eingabe) plant um 18:00
	await _tap(dui.wc_home)
	await _wait(1.0)
	await _shot(dir, "00w2_uebersicht_serie")
	ui._open_menu()
	await _until_shown(ui.menu_card, 3.0)
	var sc: ScrollContainer = ui.menu_card.get_meta("scroll")
	sc.ensure_control_visible(ui._remind_box)
	await _wait(0.5)
	var fest := ui.segment_button(ui._remind_seg, "fest")
	await _tap(fest)
	await _wait(0.6)
	sc.ensure_control_visible(ui._remind_box)
	await _wait(0.3)
	await _shot(dir, "00y_erinnerung")
	var fixed_plan: Array = Game.reminder_log
	var fixed_ok := str(Game.remind["mode"]) == "fest" and not fixed_plan.is_empty() and int((fixed_plan[0] as Dictionary)["hour"]) == 18 \
		and int((fixed_plan[0] as Dictionary)["minute"]) == 0 and ui._remind_time_row.visible
	var note_ok := ui._remind_note.visible and ui._remind_note.text == "Nur auf dem Handy."
	await _tap(ui.segment_button(ui._remind_seg, "auto"))
	await _wait(0.4)
	_check(ok_plan and fixed_ok and note_ok and str(Game.remind["mode"]) == "auto", "reminder_scheduled",
		"ids=%s cats=%s A=%s texte=%d fenster=%s abschied=%s protokoll=%s fest=%s hinweis=%s" % [str(ids), str(cats), a_time,
		tpls.size(), str(in_window), str(final_ok), str(logged), str(fixed_ok), str(note_ok)])
	ui._close_modal(true)


## Bis eine Karte ganz zu sehen ist.
func _until_shown(c: Control, sec: float) -> bool:
	var t := 0.0
	while t < sec:
		if c.visible and c.modulate.a > 0.98:
			return true
		await _wait(0.05)
		t += 0.05
	return false


## Einen Knopf (oder ein Element) antippen, echte Eingabe.
func _tap(c: Control) -> void:
	await _touch(c.get_global_rect().get_center())


## Den Tag mit der besten Aktion (wie „Tipp“) zu Ende spielen. Drehungen per echter Wisch-Eingabe.
func _play_day(max_twists: int) -> bool:
	for i in max_twists:
		if not Game.in_day() or Game.state.is_over() or Game.over:
			break
		var act := Game.state.best_action()
		var typ := str(act.get("type", "twist"))
		if typ == "rain" and Game.use_bonus("rain", int(act["field"]), [], true):
			await _settle(8.0, int(act.get("choice", 0)))       # Regen wie der Tipp (kein Zug)
			continue
		if act.is_empty() or typ != "twist":
			var d := _twist_without_progress()
			act = {"axis": d[0], "layer": d[1], "turns": d[2], "choice": 0}
		await _swipe_move(int(act["axis"]), int(act["layer"]), int(act["turns"]))
		await _settle(8.0, int(act.get("choice", 0)))
	return Game.state.day_won


## Eine Drehung, die dem Ziel nichts bringt (für den Fehlversuch). [Achse, Scheibe, Viertel]
func _twist_without_progress() -> Array:
	var gs := Game.state
	var p0 := gs.goal_progress()
	for a in 3:
		for l in [-1, 0, 1]:
			for t in [1, -1, 2]:
				var sim := gs.simulate(_twist(a, l, t))
				var st: GameState = sim["state"]
				if st.goal_progress() == p0 and st.card < 0 and not _has_event(sim["result"], "war"):
					return [a, l, t]
	return [1, -1, 1]


## Eine Drehung, nach der die Wiesen-Karte kommt (Tag 5). [] = keine.
func _meadow_card_twist() -> Array:
	var gs := Game.state
	for a in 3:
		for l in [-1, 0, 1]:
			for t in [1, -1]:
				var info := gs.choice_for(_twist(a, l, t))
				if not info.is_empty() and int(info["kind"]) == FieldData.MEADOW:
					return [a, l, t]
	return []


## Viel Stadt und Industrie, oben ein paar Wälder (Smog an Tag 7).
func _paint_smog(gs: GameState) -> void:
	var pal := [FieldData.INDUSTRY, FieldData.TOWN, FieldData.BIGCITY, FieldData.TOWN, FieldData.HOUSE, FieldData.VILLAGE,
		FieldData.VILLAGE, FieldData.INDUSTRY, FieldData.TOWN]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for f in gs.fields:
		(f as FieldData).kind = int(pal[rng.randi() % pal.size()])
		(f as FieldData).fresh = 0
		(f as FieldData).burning = false
	_paint_face(Vector3i(0, 1, 0), [FieldData.INDUSTRY, FieldData.FOREST, FieldData.TOWN, FieldData.ANIMALS, FieldData.INDUSTRY,
		FieldData.BIGFOREST, FieldData.TOWN, FieldData.FOREST, FieldData.INDUSTRY])
	gs.wishes = []


## Natur und Dörfer gemischt, bis die Waage grün ist (Gleichgewicht).
func _paint_green(gs: GameState) -> void:
	var nat := [FieldData.FOREST, FieldData.MEADOW, FieldData.BIGFOREST, FieldData.FIELD]
	var civ := [FieldData.VILLAGE, FieldData.HOUSE, FieldData.TOWN]
	for share in [4, 5, 3, 6, 2, 7]:
		for f in gs.fields:
			var fd: FieldData = f
			fd.kind = int(civ[fd.id % civ.size()]) if fd.id % 10 < share else int(nat[fd.id % nat.size()])
			fd.fresh = 0
			fd.burning = false
		if gs.balance() > Balance.WILD_AT + 12 and gs.balance() < Balance.CITY_AT - 12:
			break
	gs.wishes = []


# --- Wischen wie mit dem Finger ----------------------------------------------------------------------------

## Die Scheibe (axis, layer) um turns Viertel drehen: echter Wisch über ein sichtbares Feld dieser Scheibe.
## Ist keins zu sehen, dreht sich die Ansicht; klappt es dann noch nicht, dreht die Tour direkt (Warnung).
func _swipe_move(axis: int, layer: int, turns: int) -> bool:
	# Erst warten, bis nichts mehr dreht (auch keine Vorführung der Hand)
	for i in 60:
		if world._mode == "" and not world.animating and not Game.busy:
			break
		await _wait(0.05)
	var faces: Array = []
	for vn in [Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, -1), Vector3i(0, -1, 0)]:
		var vv: Vector3i = vn
		if vv[axis] == 0:
			faces.append(vv)
	for attempt in 3:
		var cand := _swipe_candidate(axis, layer, turns)
		if not cand.is_empty():
			await _swipe(cand["from"], cand["to"])
			return true
		world.focus_place(faces[attempt % faces.size()])
		await _wait(1.1)
	push_warning("Tour: kein sichtbares Feld für Scheibe %d/%d, drehe direkt" % [axis, layer])
	for i in 20:
		if world.auto_twist(axis, layer, turns):
			return false
		await _wait(0.1)
	return false


func _swipe_candidate(axis: int, layer: int, turns: int) -> Dictionary:
	var cam := world.rig.cam
	var vs := get_viewport().get_visible_rect().size
	var mid := vs * Vector2(0.5, 0.47)
	var best := {}
	var best_d := INF
	var why := {}
	for f in Game.state.fields:
		var fd: FieldData = f
		var na := GameState.axis_of(fd.n)
		if na == axis or fd.p[axis] != layer:
			continue
		var fs := world.field_screen(fd.id)
		if not bool(fs["visible"]):
			why["unsichtbar"] = int(why.get("unsichtbar", 0)) + 1
			continue
		# Mitte der Kachel (nicht der Punkt über dem Feld, der kann schon auf dem Nachbarn liegen)
		var v: FieldView = world.views.get(fd.id)
		var pos: Vector2 = cam.unproject_position(v.global_position + v.world_normal() * 0.1)
		if _under_ui(pos):
			why["ui"] = int(why.get("ui", 0)) + 1
			continue
		var hit: Dictionary = world._raycast(pos)
		if int(hit.get("field", -1)) != fd.id:
			why["verdeckt"] = int(why.get("verdeckt", 0)) + 1
			continue
		var hp: Vector3 = hit["point"]
		var s0 := cam.unproject_position(hp)
		var a := 3 - na - axis
		var t := GameState.unit(a, 1)
		var st := cam.unproject_position(hp + Vector3(t) * 0.5) - s0
		if st.length() < 10.0:
			why["schräg"] = int(why.get("schräg", 0)) + 1
			continue
		var k := Vector3(fd.n).cross(Vector3(t))
		var sgn := 1.0 if k[axis] > 0.0 else -1.0
		var pxq := maxf(40.0, st.length() * 2.0 * Balance.TWIST_FINGER_UNITS)
		# Ein halbes Viertel vor dem Ziel loslassen reicht (die Scheibe rastet ein). Eine halbe Drehung geht in beide Richtungen.
		for q in ([turns] if absi(turns) != 2 else [2, -2]):
			var qq := int(q)
			var along := (float(absi(qq)) - 0.3) * signf(float(qq)) * pxq * sgn
			var drag := st.normalized() * along
			var to := pos + drag
			if to.x < 12.0 or to.x > vs.x - 12.0 or to.y < ui._insets.x + 100.0 or to.y > vs.y - 12.0 or _under_ui(to):
				why["rand"] = int(why.get("rand", 0)) + 1
				continue
			var d := pos.distance_to(mid) + (pos + drag * 0.5).distance_to(mid) * 0.5
			if d < best_d:
				best_d = d
				best = {"from": pos, "to": to}
	if best.is_empty():
		print("Tour: keine Wisch-Stelle für %d/%d/%d: %s" % [axis, layer, turns, str(why)])
	return best


## Ein Finger wischt von a nach b (ScreenTouch + ScreenDrag, daraus macht Godot die Maus).
func _swipe(a: Vector2, b: Vector2) -> void:
	var tf: Transform2D = get_tree().root.get_final_transform()
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = tf * a
	t.pressed = true
	Input.parse_input_event(t)
	await get_tree().process_frame
	var last := tf * a
	var steps := 4
	for i in range(1, steps + 1):
		var p: Vector2 = tf * a.lerp(b, float(i) / float(steps))
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = p
		d.relative = p - last
		d.velocity = (p - last) * 60.0
		last = p
		Input.parse_input_event(d)
		await get_tree().process_frame
	await _wait(0.06)
	var r := InputEventScreenTouch.new()
	r.index = 0
	r.position = tf * b
	r.pressed = false
	Input.parse_input_event(r)
	await get_tree().process_frame
	await get_tree().process_frame


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
		(f as FieldData).kind = FieldData.WATER
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


# --- Nahtlos (GDPD_GRAFIK.md): Wasser fließt zusammen, Böden gehen ineinander über, keine Lichtlücken --------

## Wasser als T/L wie im Feedback-Bild, dazu gemischtes Land; Nahaufnahmen von oben, schräg, streifend, mitten
## in einer Drehung und vor grellem Hintergrund.
func _seamless_tour(dir: String) -> void:
	ui.debug_close_all()
	Game.new_game(4242, 1, 1)
	await _wait(1.0)
	var gs := Game.state
	var W := FieldData.WATER
	var M := FieldData.MEADOW
	var F := FieldData.FOREST
	var A := FieldData.ANIMALS
	var E := FieldData.EMPTY
	var R := FieldData.FIELD
	# Oben (y = 1), Zeile für Zeile von hinten (z = -1) nach vorn, Spalte x = -1 .. 1
	var top := [[W, W, W], [F, W, F], [M, W, W]]
	var front := [[A, W, R], [M, W, E], [F, M, A]]       # z = 1, Zeile y = 1 .. -1
	var right := [[W, M, F], [W, A, M], [R, F, E]]       # x = 1, Zeile y = 1 .. -1, Spalte z = 1 .. -1
	for f in gs.fields:
		(f as FieldData).kind = M
		(f as FieldData).fresh = 0
		(f as FieldData).burning = false
	for r in 3:
		for c in 3:
			_paint_at(Vector3i(c - 1, 1, r - 1), Vector3i(0, 1, 0), int(top[r][c]))
			_paint_at(Vector3i(c - 1, 1 - r, 1), Vector3i(0, 0, 1), int(front[r][c]))
			_paint_at(Vector3i(1, 1 - r, 1 - c), Vector3i(1, 0, 0), int(right[r][c]))
	gs.wishes = []
	Game.state_changed.emit()
	ui.visible = false
	world._hinted = true            # Nahaufnahmen ohne Hinweis-Leuchten
	world._clear_hint()
	await _wait(1.6)
	world.debug_view(Vector3(0.12, 1.0, 0.16), Vector3(0, 0, -1), 0.78)
	await _wait(0.8)
	await _shot(dir, "30_nahtlos_wasser")
	world.debug_view(Vector3(0.75, 0.95, 1.1), Vector3.UP, 0.7)
	await _wait(0.8)
	await _shot(dir, "30b_nahtlos_wasser_schraeg")
	world.debug_view(Vector3(1.0, 0.55, 0.35), Vector3.UP, 0.62)
	await _wait(0.8)
	await _shot(dir, "31_nahtlos_uebergang")
	world.debug_bright_bg(true)
	world.debug_view(Vector3(1.0, 0.08, 0.04), Vector3.UP, 0.75)
	await _wait(0.6)
	await _shot(dir, "32_keine_luecken")
	world.debug_view(Vector3(1.0, 1.0, 1.0), Vector3.UP, 0.75)
	await _wait(0.6)
	await _shot(dir, "32b_keine_luecken_ecke")
	var probe := gs.field_at(Vector3i(1, 1, 1), Vector3i(0, 1, 0))
	var pv: FieldView = world.views[probe.id]
	var nb_before: Array = pv.debug_neighbors()
	var ok_before := nb_before == world.debug_expected_neighbors(probe.id)
	world.debug_begin_twist(probe.id, Vector2(1, 0.15), 0.5)
	await _wait(0.8)
	await _shot(dir, "32c_keine_luecken_drehung")
	world.debug_end_twist()
	for i in 60:
		await _wait(0.05)
		if not world.animating and not Game.busy:
			break
	await _wait(0.3)
	# eine echte Vierteldrehung der Scheibe x = 1 (mit dem Eck-Feld oben rechts vorn)
	var turned := world.auto_twist(0, 1, 1)
	for i in 120:
		await _wait(0.05)
		if not world.animating and not Game.busy:
			break
	await _wait(0.4)
	world.debug_bright_bg(false)
	await _wait(0.6)
	# Nahtlos: Nach der Drehung kennt jedes Feld seine neuen Nachbarn (Wasser-Maske, Übergänge)
	var bad := 0
	var water_open := 0
	for fid in world.views:
		var v: FieldView = world.views[fid]
		if v.debug_neighbors() != world.debug_expected_neighbors(int(fid)):
			bad += 1
		if v.get_kind() == FieldView.K_WATER and v.debug_water_mask().has(1):
			water_open += 1
	var nb_after: Array = pv.debug_neighbors()
	var outer_ok := pv.outer_mask() != 0
	_check(turned and ok_before and bad == 0 and nb_after != nb_before and water_open >= 4 and outer_ok, "seamless",
		"falsch=%d vorher=%s nachher=%s wasser_verbunden=%d" % [bad, str(nb_before), str(nb_after), water_open])
	world.debug_view(Vector3(0.12, 1.0, 0.16), Vector3(0, 0, -1), 0.78)
	await _wait(0.8)
	await _shot(dir, "33_nahtlos_nach_drehung")
	ui.visible = true
	ui.debug_close_all()


func _paint_at(p: Vector3i, n: Vector3i, kind: int) -> void:
	var f := Game.state.field_at(p, n)
	if f != null:
		f.kind = kind
		f.fresh = 0
		f.burning = false


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
	for c in [ui.mode_card, ui.toast, ui.tip_card, ui.coach, ui.day_ui.lane]:
		var cc: Control = c
		if cc.visible:
			rects.append(cc.get_global_rect().grow(12.0))
	for r in rects:
		var rr: Rect2 = r
		if rr.has_point(pos):
			return true
	return false


## Ein sichtbares Feld, das man antippen kann. want: "target" = ein Regenziel, "other" = keins. {"fid", "pos"}
func _rain_target(want: String = "target", skip: int = -1, kind: int = -1) -> Dictionary:
	var tg := Game.state.rain_targets()
	var mid := get_viewport().get_visible_rect().size * 0.5
	var best := -1
	var best_pos := Vector2.ZERO
	var best_d := INF
	for f in Game.state.fields:
		var fid: int = (f as FieldData).id
		if fid == skip or tg.has(fid) != (want == "target"):
			continue
		if kind >= 0 and (f as FieldData).kind != kind:
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
			if ui.toast.visible and ui.toast_label.text == "Regen nur auf blau leuchtende Felder.":
				told = true
			for m in ui._toasts:
				if str((m as Dictionary)["text"]).begins_with("Regen nur"):
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


var _stills: Array = []          # stille Reihen, die die Welt gezeigt hat (still_shown)


func _on_tour_still(info: Dictionary) -> void:
	_stills.append(info)


## Tag 1 nach „Jetzt du!“: echte Eingabe (ein Wisch ohne Wachsen), dann 30 s warten. Keine Scheibe darf sich bewegen:
## kein Drehen (world._mode „twist“), keine Runde, keine Animation, keine Drehung mehr gezählt.
func _no_auto_twist_check() -> void:
	world.tour_auto = false
	var dud := _twist_without_progress()
	var swiped := await _swipe_move(int(dud[0]), int(dud[1]), int(dud[2]))
	await _settle(8.0)
	var t0 := Game.state.twists
	var touched := world._touched_state == Game.state
	var moved := false
	var waited := 0.0
	var t_start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_start < 30000:
		if world._mode == "twist" or world.animating or Game.busy or world._pivot != null and is_instance_valid(world._pivot):
			moved = true
		await get_tree().process_frame
	waited = (Time.get_ticks_msec() - t_start) / 1000.0
	var guard := not world.can_self_move() and not world.auto_twist(0, 1, 1)
	_check(swiped and touched and not moved and Game.state.twists == t0 and guard and Game.in_day() and not Game.over,
		"no_auto_twist_after_input", "wisch=%s beruehrt=%s bewegt=%s drehungen=%d->%d warten=%.0fs sperre=%s" % [str(swiped),
		str(touched), str(moved), t0, Game.state.twists, waited, str(guard)])


## Tag 2: Wald ruht (Großer Wald ist erst ab Tag 3 frei). Eine echte Drehung bildet oben eine neue Reihe aus drei
## Wäldern: Die drei Felder leuchten mit Schloss, die Pille sagt „Ruht · Großer Wald erst ab Tag 3“,
## kein Fehlversuch (misses bleibt).
func _resting_row_check(dir: String) -> void:
	var gs := Game.state
	for f in gs.fields:
		(f as FieldData).kind = FieldData.WATER
		(f as FieldData).burning = false
		(f as FieldData).fresh = 0
	gs.wishes = []
	gs.field_at(Vector3i(-1, 1, 1), Vector3i(0, 1, 0)).kind = FieldData.FOREST
	gs.field_at(Vector3i(0, 1, 1), Vector3i(0, 1, 0)).kind = FieldData.FOREST
	var third: FieldData = gs.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1))
	third.kind = FieldData.FOREST          # kommt mit der Drehung x = 1 nach oben in die Reihe
	gs.misses = 1
	Game.state_changed.emit()
	world.focus_place(Vector3i(0, 1, 0))
	await _wait(1.2)
	_stills.clear()
	var m0 := gs.misses
	var swiped := await _swipe_move(0, 1, 1)
	var pill := false
	var badge := false
	var pill_text := ""
	for i in 120:
		if ui.banner.visible and ui.banner_caps.text.contains("erst ab Tag 3") and ui.banner_text.text.contains("Wälder aus Wiesen"):
			pill = true
			pill_text = ui.banner_caps.text + " / " + ui.banner_text.text
		var v: FieldView = world.views.get(third.id)
		if v != null and v._badge_name == "lock" and v.is_still_marked():
			badge = true
		if pill and badge:
			break
		await _wait(0.05)
	await _shot(dir, "00h3_tag2_ruht")
	await _settle(6.0)
	var rest_seen := false
	for e in _stills:
		if str((e as Dictionary)["why"]) == "rest" and int((e as Dictionary)["kind"]) == FieldData.FOREST:
			rest_seen = true
	_check(swiped and rest_seen and pill and badge and third.kind == FieldData.FOREST and Game.state.misses == m0,
		"resting_row_feedback", "wisch=%s still=%s pille=%s schloss=%s fehlversuche=%d->%d text=%s" % [str(swiped), str(rest_seen),
		str(pill), str(badge), m0, Game.state.misses, pill_text])
	# Gleich danach Regen (kein Zug, dieselbe Zugnummer): Er macht aus einer Wiese den dritten Wald einer zweiten
	# ruhenden Reihe. Auch das sagt eine Pille (früher: Schloss, aber kein Wort, weil der Zug schon „gesagt“ hatte).
	gs.field_at(Vector3i(-1, 1, -1), Vector3i(0, 1, 0)).kind = FieldData.FOREST
	gs.field_at(Vector3i(0, 1, -1), Vector3i(0, 1, 0)).kind = FieldData.FOREST
	var wet: FieldData = gs.field_at(Vector3i(1, 1, -1), Vector3i(0, 1, 0))
	wet.kind = FieldData.MEADOW
	gs.rain = maxi(gs.rain, 1)
	Game.state_changed.emit()
	for i in 80:
		if not ui.banner.visible:
			break
		await _wait(0.05)
	await _wait(0.4)
	var turn0 := gs.turn
	await _tap(ui.rain_btn)
	await _wait(0.5)
	var rt := _rain_target("target", -1, FieldData.MEADOW)
	var rain_pill := false
	var rain_text := ""
	if int(rt["fid"]) == wet.id:
		await _touch(rt["pos"])
		for i in 120:
			if ui.banner.visible and ui.banner_caps.text.contains("erst ab Tag 3"):
				rain_pill = true
				rain_text = ui.banner_caps.text + " / " + ui.banner_text.text
				break
			await _wait(0.05)
	await _settle(6.0)
	ui._set_bonus_mode("")
	_check(rain_pill and wet.kind == FieldData.FOREST and gs.turn == turn0 and Game.state.misses == m0, "resting_row_rain",
		"ziel=%d wiese=%d pille=%s zug=%d->%d text=%s" % [int(rt["fid"]), wet.id, str(rain_pill), turn0, gs.turn, rain_text])


## Eine Drehung bildet oben eine neue Reihe aus 3 Wäldern (Mittel): Sie muss wachsen.
## Danach hin und zurück (zählt nicht) und eine Reihe mit einem anderen Feld (zählt).
func _merge_check() -> void:
	ui.debug_close_all()
	Game.new_game(4243, 1, 1)
	await _wait(1.0)
	var gs := Game.state
	for f in gs.fields:
		(f as FieldData).kind = FieldData.WATER
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


## Bild, sobald die Pille mit diesem Text (Kopfzeile oder Satz) zu sehen ist; sonst nach sec Sekunden trotzdem.
## Die Wartezeit ist echte Zeit (Software-Grafik schafft nur 2–3 Bilder je Sekunde: jedes _wait dauert mindestens ein Bild).
func _shot_on_banner(dir: String, shot_name: String, want: String, sec: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) < sec * 1000.0:
		if ui.banner.visible and (ui.banner_caps.text == want or ui.banner_text.text == want):
			await _wait(0.35)
			await _shot(dir, shot_name)
			return true
		await _wait(0.05)
	await _shot(dir, shot_name)
	return false


func _shot(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	img.save_jpg("%s/%s.jpg" % [dir, shot_name], 0.85)
	print("Screenshot: %s (%.1f s, %d fps)" % [shot_name, Time.get_ticks_msec() / 1000.0, Engine.get_frames_per_second()])


## Mittlere Farbe der Mitte einer Kachel im Bild (5×5-Raster um die Feldmitte, die Ränder ausgelassen).
func _tile_rgb(img: Image, fid: int) -> Color:
	var p: Vector2 = world.field_screen(fid)["pos"]
	var vs := Vector2(img.get_width(), img.get_height())
	var sc := vs / get_viewport().get_visible_rect().size
	var c := Color(0, 0, 0)
	var n := 0
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var q := (p + Vector2(dx, dy) * 9.0) * sc
			if q.x >= 0 and q.y >= 0 and q.x < vs.x and q.y < vs.y:
				c += img.get_pixelv(Vector2i(q))
				n += 1
	return c / float(maxi(n, 1))


static func _lab(c: Color) -> Vector3:
	var lin := Vector3(c.srgb_to_linear().r, c.srgb_to_linear().g, c.srgb_to_linear().b)
	var x := (0.4124 * lin.x + 0.3576 * lin.y + 0.1805 * lin.z) / 0.95047
	var y := 0.2126 * lin.x + 0.7152 * lin.y + 0.0722 * lin.z
	var z := (0.0193 * lin.x + 0.1192 * lin.y + 0.9505 * lin.z) / 1.08883
	var f := func(t: float) -> float: return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
	var fx: float = f.call(x)
	var fy: float = f.call(y)
	var fz: float = f.call(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


## ΔE (CIE76) zwischen einer gut sichtbaren Kachel der Art k und einer Kachel totes Wasser (−1: keine zu sehen).
func _life_delta_e(k: int) -> float:
	var cam_pos := world.rig.cam.global_position
	var best := {}
	for f in Game.state.fields:
		var fd: FieldData = f
		if fd.kind != k and fd.kind != FieldData.WATER:
			continue
		var v: FieldView = world.views.get(fd.id)
		if v == null or not bool(world.field_screen(fd.id)["visible"]):
			continue
		var face := v.world_normal().dot((cam_pos - v.global_position).normalized())
		if face > float((best.get(fd.kind, [-1, -INF]) as Array)[1]):
			best[fd.kind] = [fd.id, face]
	if not best.has(k) or not best.has(FieldData.WATER):
		return -1.0
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var a := _lab(_tile_rgb(img, int((best[k] as Array)[0])))
	var b := _lab(_tile_rgb(img, int((best[FieldData.WATER] as Array)[0])))
	return a.distance_to(b)


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


# --- Die neuen Tage (GDPD_BALANCE_2.md 12): Hilfen der Tour -------------------------------------------------

var _round_types := {}           # Ereignis-Typen der Runden seit dem letzten _seen_type-Zurücksetzen


func _on_tour_round(result: Dictionary, _before: Dictionary) -> void:
	for e in result.get("events", []):
		_round_types[str((e as Dictionary).get("type", ""))] = true


## Kam seit dem letzten Aufruf ein Ereignis dieses Typs? (Setzt die Liste zurück.)
func _seen_type(t: String) -> bool:
	var ok := _round_types.has(t)
	_round_types = {}
	return ok


## Eine Pool-Lösung (oder ihren Anfang) mit echter Eingabe spielen: Drehungen wischen, Regen/Meteor wie der Tipp.
func _play_solution(sol: Array, upto: int) -> void:
	var n := 0
	for step in sol:
		if n >= upto or not Game.in_day() or Game.state.is_over() or Game.over:
			break
		n += 1
		var sa := Days.solution_step(step)
		var act: Dictionary = sa[0]
		var t := str(act["type"])
		if t == "twist":
			await _swipe_move(int(act["axis"]), int(act["layer"]), int(act["turns"]))
		else:
			Game.use_bonus("strike" if t == "meteor" else t, int(act["field"]), [], true)
		await _settle(8.0)


## Arten, die auf dem Brett heute wachsen können (Reihen-Arten mit ≥ 3 Feldern, Menschen unter der Tages-Stufe).
func _growable(gs: GameState) -> Array:
	var cnt := {}
	for f in gs.fields:
		cnt[f.kind] = int(cnt.get(f.kind, 0)) + 1
	var out: Array = []
	for k in gs.rows8:
		if int(cnt.get(int(k), 0)) >= 3:
			out.append(FieldData.kind_name(int(k)))
	if gs.top8 >= 0:
		for k in GameState.PEOPLE8:
			if cnt.has(int(k)) and FieldData.level8(int(k)) < FieldData.level8(gs.top8):
				out.append(FieldData.kind_name(int(k)))
	return out


func _max_size(lists: Array) -> int:
	var m := 0
	for l in lists:
		m = maxi(m, (l as Array).size())
	return m


func _kinds_of(gs: GameState) -> Array:
	var out: Array = []
	for f in gs.fields:
		out.append((f as FieldData).kind)
	return out


## Tag 5: eine Drehung, die jemanden satt macht und deren Scheibe im Bild zu ziehen ist (Kamera auf das Feld).
## {"move": [a, l, t], "field": ID} oder {}.
func _pick_supply_move() -> Dictionary:
	for m in GameState.MOVES:
		var sup: Dictionary = Game.preview(int(m[0]), int(m[1]), int(m[2])).get("supply", {})
		var sn: Array = sup.get("satt_new", [])
		if sn.is_empty():
			continue
		var fid := int(sn[0])
		world.focus_field(fid)
		await _wait(1.2)
		if not _swipe_candidate(int(m[0]), int(m[1]), int(m[2])).is_empty() and bool(world.field_screen(fid)["visible"]):
			return {"move": m, "field": fid}
	return {}


## Ziel-Chip sichtbar; ab Tag 4 mit den Symbolen dessen, was verbunden werden muss.
func _chip_ok(n: int) -> bool:
	var dui := ui.day_ui
	if not dui.chip.visible:
		return false
	if n < 4:
		return not dui.chip_needs.visible
	return dui.chip_needs.visible and dui.chip_needs.get_child_count() == Game.state.goal_needs().size()


## Steht irgendwo unter root ein Label mit genau diesem Text?
func _has_label(root: Node, text: String) -> bool:
	if root is Label and (root as Label).text == text:
		return true
	for c in root.get_children():
		if _has_label(c, text):
			return true
	return false


## Pillen, die sagen, warum hin und her nichts bringt (Schon gewachsen, Zurückgedreht, Stand schon da).
const FARM_CAPS = ["Schon gewachsen", "Zurückgedreht", "Stand schon da", "Hin und her"]


## Wie _settle, achtet dabei aber auf eine Pille mit einer dieser Kopfzeilen (true: kam).
func _settle_watch(sec: float, caps: Array) -> bool:
	var said := false
	var t := 0.0
	while t < sec and (Game.busy or world.animating or ui._queued_tap >= 0 or (t < 1.2 and not said)):
		if ui.banner.visible and caps.has(ui.banner_caps.text):
			said = true
		await _wait(0.1)
		t += 0.1
	if ui.banner.visible and caps.has(ui.banner_caps.text):
		said = true
	await _wait(0.2)
	return said


var _hold_at := Vector2.ZERO
var _dwell0 := 0.25


## Finger auf die Scheibe, ziehen und liegen lassen (Vorschau beim Drehen). true: die Welt dreht gerade.
func _drag_hold(axis: int, layer: int, turns: int) -> bool:
	for i in 60:
		if world._mode == "" and not world.animating and not Game.busy:
			break
		await _wait(0.05)
	var cand := _swipe_candidate(axis, layer, turns)
	if cand.is_empty():
		return false
	var tf: Transform2D = get_tree().root.get_final_transform()
	var a: Vector2 = cand["from"]
	var b: Vector2 = cand["to"]
	# Liegt der Finger neben dem Würfel, dreht die Scheibe von selbst weiter: beim Halten für die Aufnahme nicht
	_dwell0 = Balance.TWIST_AUTO_DWELL_SECONDS
	Balance.TWIST_AUTO_DWELL_SECONDS = 999.0
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = tf * a
	t.pressed = true
	Input.parse_input_event(t)
	await get_tree().process_frame
	var last := tf * a
	for i in range(1, 7):
		var p: Vector2 = tf * a.lerp(b, float(i) / 6.0)
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = p
		d.relative = p - last
		d.velocity = Vector2.ZERO
		last = p
		Input.parse_input_event(d)
		await get_tree().process_frame
	_hold_at = tf * b
	await _wait(0.9)
	return world._mode == "twist" and World._norm_turns(world._tw_quarter) == turns


func _drag_release() -> void:
	var r := InputEventScreenTouch.new()
	r.index = 0
	r.position = _hold_at
	r.pressed = false
	Input.parse_input_event(r)
	await get_tree().process_frame
	await get_tree().process_frame
	Balance.TWIST_AUTO_DWELL_SECONDS = _dwell0


## Nahaufnahmen der neuen Optik (Tag 7: alle Arten auf einem Brett): Start, Wasser, Wald, Dorf, Tiere, Menschen.
## Prüft nebenbei, dass Tiere und Menschen leben (Agenten auf ihren Feldern).
func _look_shots(dir: String) -> void:
	ui._coach_dismiss()
	ui.day_ui._hide_lane(true)
	world.focus_place(Vector3i(0, 1, 0))
	await _wait(1.0)
	await _shot(dir, "20_look_start")
	var z0 := world.rig.zoom_factor
	var life := {}
	var used_faces := {}
	for spec in [["21_look_wasser", [FieldData.WATER]], ["22_look_wald", [FieldData.FOREST, FieldData.BIGFOREST]],
			["23_look_dorf", [FieldData.VILLAGE, FieldData.TOWN]], ["24_look_tiere", [FieldData.ANIMALS]],
			["25_look_menschen", [FieldData.TOWN, FieldData.HUT, FieldData.VILLAGE]]]:
		var sp: Array = spec
		var fid := _field_of(sp[1] as Array, used_faces)
		if fid < 0:
			continue
		used_faces[(Game.state.fields[fid] as FieldData).n] = true
		world.focus_field(fid)
		world.rig.zoom_factor = 0.66
		world.rig._apply()
		await _wait(1.3)
		var fv: FieldView = world.views[fid]
		life[str(sp[0])] = fv.agent_count()
		await _shot(dir, str(sp[0]))
	world.rig.zoom_factor = z0
	world.rig._apply()
	world.focus_place(Vector3i(0, 1, 0))
	await _wait(0.8)
	_check(int(life.get("24_look_tiere", 0)) > 0 and int(life.get("25_look_menschen", 0)) > 0 and life.size() == 5, "look_life",
		"agenten=%s" % str(life))


## Ein Feld dieser Arten: am liebsten eine Seitenmitte (steht nach focus_field mitten im Bild) auf einer Seite,
## die noch keine Nahaufnahme hatte; sonst nah an der Mitte.
func _field_of(kinds: Array, used: Dictionary) -> int:
	var best := -1
	var best_s := -INF
	for f in Game.state.fields:
		var fd: FieldData = f
		if not kinds.has(fd.kind):
			continue
		var off := 0.0
		for ax in 3:
			if fd.n[ax] == 0:
				off += absf(float(fd.p[ax]))
		var sc := -off * 4.0 - float(kinds.find(fd.kind)) * 0.5 + float(fd.n.y) * 0.5
		if used.has(fd.n):
			sc -= 6.0
		if sc > best_s:
			best_s = sc
			best = fd.id
	return best


## Tag 2, Brett 0: eine Scheibe hin und her (x = 1, echte Wisch-Eingabe, 6-mal) → genau 1 Mal wächst etwas (Drehung 1).
## Danach „Schon gewachsen“: dieselbe Reihe nach einem anderen Zug wieder gebildet (Pille, Eingabe nie gesperrt).
func _no_farming_check(dir: String) -> void:
	var dui := ui.day_ui
	Game.start_day(2, 0)
	await _until_shown(dui.goal_card, 4.0)
	await _tap(dui.gc_go)
	await _wait(2.6)
	ui._coach_dismiss()
	world.focus_place(Vector3i(0, 1, 0))
	var grew: Array = []
	var farm_said := 0
	for t in 6:
		var m0 := 0
		for k in Game.state.made:
			m0 += int(k)
		await _swipe_move(0, 1, 1 if t % 2 == 0 else -1)
		if t > 0 and await _settle_watch(8.0, FARM_CAPS):
			farm_said += 1
		elif t == 0:
			await _settle(8.0)
		var m1 := 0
		for k in Game.state.made:
			m1 += int(k)
		grew.append(m1 - m0)
	await _shot(dir, "00w3_kein_farmen")
	_check(grew[0] == 1 and grew.slice(1) == [0, 0, 0, 0, 0] and farm_said >= 3, "no_farming",
		"wachsen=%s pillen=%d" % [str(grew), farm_said])
	# „Schon gewachsen“: eine Erde-Reihe oben wächst, ihr Ziel fällt zurück, ein anderer Zug, dann wieder gebildet
	var gs := Game.state
	for f in gs.fields:
		(f as FieldData).kind = FieldData.WATER
		(f as FieldData).burning = false
	gs.field_at(Vector3i(-1, 1, 1), Vector3i(0, 1, 0)).kind = FieldData.EMPTY
	gs.field_at(Vector3i(0, 1, 1), Vector3i(0, 1, 0)).kind = FieldData.EMPTY
	var third: FieldData = gs.field_at(Vector3i(1, 1, -1), Vector3i(0, 0, -1))
	third.kind = FieldData.EMPTY
	Game.state_changed.emit()
	await _wait(0.8)
	await _swipe_move(0, 1, 1)
	await _settle(8.0)
	third.kind = FieldData.EMPTY
	Game.state_changed.emit()
	await _swipe_move(0, 1, -1)
	await _settle(8.0)
	await _swipe_move(1, -1, 1)
	await _settle(8.0)
	_stills.clear()
	await _swipe_move(0, 1, 1)
	var pill := false
	for i in 120:
		if ui.banner.visible and ui.banner_caps.text == "Schon gewachsen":
			pill = true
			break
		await _wait(0.05)
	await _shot(dir, "00w4_schon_gewachsen")
	await _settle(8.0)
	var spent_seen := false
	for e in _stills:
		if str((e as Dictionary)["why"]) == "spent":
			spent_seen = true
	_check(pill and spent_seen and third.kind == FieldData.EMPTY and not ui.input_locked(), "spent_feedback",
		"pille=%s still=%s" % [str(pill), str(spent_seen)])
	ui.debug_show_help()
	await _wait(0.8)
	_check(_has_label(ui.help_card, str(Days.TEXT["once_rule"])), "help_once", "")
	ui._close_modal(true)
	await _wait(0.4)


# --- Build 12 (Rückmeldung nach Build 11) -------------------------------------------------------------------------
# „oben und unten schwenken invertieren“ · „zeig oben an, was man machen muss und nicht direkt am Feld“ · „die Icons am
# Feld entfernen“ · „manche Felsen sehen komisch aus“ · „Weiterbauen brauchen wir nicht“ · „man soll immer genau
# wissen, was man tun muss“.

## Sichtbare Symbole an den Feldern (Plaketten, Abzeichen, Vorschau-Pfeile, „×2“, Kühl-Punkte, „!“/„?“).
func _b12_field_icons() -> int:
	var n := 0
	for fid in world.views:
		var v: FieldView = world.views[fid]
		if v._needs != null and v._needs.visible and v._needs.get_child_count() > 0:
			n += 1
		if v._badge != null and v._badge.visible:
			n += 1
		if v._supply_icon != null and v._supply_icon.visible:
			n += 1
		if v._strength_lbl != null and v._strength_lbl.visible:
			n += 1
		if v._cool_node != null and v._cool_node.visible:
			n += 1
		if v._preview_label.text != "":
			n += 1
	return n


## Liegt unter dem Feld noch ein Vulkan-Kegel (Mesh des Modells „volcano“)?
func _b12_has_cone(v: FieldView) -> bool:
	var meshes := {}
	for pv in Models.get_model("volcano", 0):
		meshes[(pv as Array)[0]] = true
	var stack: Array = [v]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is MeshInstance3D and meshes.has((nd as MeshInstance3D).mesh) and (nd as Node3D).is_visible_in_tree():
			var sc := (nd.get_parent() as Node3D).scale.y if nd.get_parent() is Node3D else 1.0
			if sc > 0.1:
				return true
		for c in nd.get_children():
			stack.append(c)
	return false


func _b12_tour(dir: String) -> void:
	var dui := ui.day_ui
	if dui.creator_open():          # --only=b12 mit frischem Profil: erst den Charakter fertig (sonst liegt er über allem)
		dui.creator.look = Character.default_look()
		dui._on_creator_finished(Character.default_look())
		await _wait(1.5)
		ui._close_modal(true)
	Game.clock_override = Daily.local_unix(2026, 11, 9, 17, 40)
	Game.reset_campaign()
	Game.cards_seen = {}
	Game.coach_seen = {}
	Game.pdata = Points.fresh(Campaign.COUNT)
	Game.points = Balance.POINTS_START
	Game.debug_open_all = true
	await get_tree().process_frame
	# 1. Level 3 (Glut) auf einem Brett, auf dem nach zwei Drehungen der Vulkan ausbricht
	var fb := _find_board(3, _p_event.bind("erupt"), 2)
	await _start_lvl(3, maxi(0, int(fb[0])))
	await _wait(1.5)
	var a0 := str(dui.action_shown.get("text", ""))
	var ar := dui.act_line.get_global_rect()
	var cr := dui.chip.get_global_rect()
	var vs := get_viewport().get_visible_rect().size
	await _shot(dir, "b12a_was_jetzt")
	_check(dui.act_line.visible and a0 != "" and absf(ar.get_center().x - vs.x * 0.5) <= vs.x * 0.06 and ar.position.y >= cr.end.y - 2.0
		and ar.end.y <= vs.y * 0.2 and dui.act_label.get_theme_font_size("font_size") >= 18, "action_line",
		"text=%s symbole=%d rect=%s chip=%s" % [a0, dui.act_icons.get_child_count(), str(ar), str(cr)])
	_check(FieldView.quiet and _b12_field_icons() == 0, "no_field_icons", "sichtbar=%d" % _b12_field_icons())
	# Eine lange Zeile (3 Symbole, Ergebnis, zweite Zeile) bleibt mittig und in der Kopfzeile (Bild: Hütten-Level)
	dui._show_action({"text": "Dreh 3 Tiere in eine Reihe", "line": "Dreh 3 Tiere in eine Reihe → Hütte",
		"icons": ["animals", "animals", "animals"], "result_icon": "hut", "hint": "Hütten brauchen Nahrung: 0/3 versorgt"})
	await _wait(0.5)
	var lr := dui.act_line.get_global_rect()
	var tr := ui.top.get_global_rect()
	await _shot(dir, "b12a2_lange_zeile")
	_check(absf(lr.get_center().x - vs.x * 0.5) <= 4.0 and lr.position.x >= tr.position.x - 1.0 and lr.end.x <= tr.end.x + 1.0
		and dui.act_hint.visible, "action_line_fits", "zeile=%s kopf=%s text=%s" % [str(lr), str(tr), dui.act_label.text])
	dui._act_key = ""
	dui.refresh_hud()
	# 2. Nach jeder Drehung neu gerechnet (auch in der Vorschau keine Symbole an den Feldern)
	var calc0 := dui.act_calc
	var texts: Array = [a0]
	var icons_during := 0
	var crater := -1
	for m in (fb[1] as Array):
		var mm: Array = m
		for i in 40:
			if world.auto_twist(int(mm[0]), int(mm[1]), int(mm[2])):
				break
			await _wait(0.1)
		icons_during += _b12_field_icons()
		await _settle(8.0)
		await _wait(0.6)
		texts.append(str(dui.action_shown.get("text", "")))
		for k in world._cones:
			crater = int(k)
	await _shot(dir, "b12b_nach_ausbruch")
	_check(dui.act_calc >= calc0 + (fb[1] as Array).size() and str(texts[-1]) != "" and icons_during == 0 and _b12_field_icons() == 0,
		"action_line_updates", "zeilen=%s neu=%d" % [str(texts), dui.act_calc - calc0])
	# 3. Der Kegel ist ein Ereignis: nach dem Ausbruch sinkt er zurück (vorher blieb er für immer, auch auf Fels)
	await _wait(3.5)
	var gone := world._cones.is_empty()
	if crater < 0:
		for f in Game.state.fields:
			if (f as FieldData).kind == FieldData.LAVA:
				crater = (f as FieldData).id
				break
	var cone_left := crater >= 0 and _b12_has_cone(world.views[crater])
	# Wird der Krater Fels (Lava abgekühlt), geht ein Kegel sofort (refresh_all), auch wenn er gerade erst kam
	var fels_ok := false
	if crater >= 0:
		world._erupt_fx(crater, crater)
		await _wait(0.2)
		(Game.state.fields[crater] as FieldData).kind = FieldData.FELS
		world.refresh_all()
		await _wait(1.4)
		fels_ok = not world._cones.has(crater) and not _b12_has_cone(world.views[crater])
		world.focus_field(crater)
		await _wait(1.2)
		await _shot(dir, "b12c_fels_ohne_kegel")
	_check(fb[0] != -1 and gone and not cone_left and fels_ok, "volcano_cone_sinks",
		"brett=%s krater=%d weg=%s fels=%s" % [str(fb[0]), crater, str(gone), str(fels_ok)])
	# 4. Ansicht: Ziehen wie früher (Finger nach unten zeigt mehr von oben); nur das Handy-Kippen ist senkrecht umgekehrt
	var b0 := world.rig.basis
	var y0 := world.rig.cam.global_position.y
	world.rig.orbit(Vector2(0, 60), 0.0)
	world.rig.stop()
	await get_tree().process_frame
	var y1 := world.rig.cam.global_position.y
	world.rig.basis = b0
	_check(not CameraRig.ORBIT_INVERT_Y and CameraRig.TILT_INVERT_Y and y1 > y0 + 0.05, "orbit_inverted", "kippen umgekehrt, ziehen normal: y %.2f -> %.2f" % [y0, y1])
	# 5. Nach einer Pause leuchtet, was zu tun ist (nur Leuchten, keine Symbole) – wenn die Regeln es sagen
	if not world.action_hint.is_empty():
		var hv := world._hint_views.size()
		world._show_action_hint()
		var lit := world._hint_views.size() > hv
		await _wait(0.6)
		await _shot(dir, "b12d_leuchten")
		world._clear_hint()
		_check(lit and _b12_field_icons() == 0, "action_nudge", "hinweis=%s" % str(world.action_hint))
	# 6. Akt 2 nach Akt 1 in derselben Sitzung: Fels hell und grau, kein Basalt aus dem Back-Cache
	await _start_lvl(6, 0)
	await _wait(2.0)
	var mk := Look.model_key()
	await _shot(dir, "b12e_akt2_fels")
	# Schlüssel: je Gestalt-Zweig eine Stelle, nach „basalt“ (Stelle 3) die Stelle für dunklen Basalt (4): hier 0
	_check(not Look.basalt_dark() and mk.length() == Look.MODEL_FLAGS.size() + 1 and mk[4] == "0", "rocks_act2", "zeitalter=%s schluessel=%s" % [Look.era_name, mk])
	# Feld-Karte (Build-11-Bild): das Regel-Bild zeigt, was eine Reihe in der Schöpfung wirklich wird (Fels → Erde)
	var gs6 := Game.state
	var sf := -1
	for f in gs6.fields:
		var fk := (f as FieldData).kind
		if gs6.rows9.has(fk) and (sf < 0 or fk == FieldData.FELS):
			sf = (f as FieldData).id
			if fk == FieldData.FELS:
				break
	var sheet_ok := false
	var sheet_txt := ""
	if sf >= 0:
		world.focus_field(sf)
		await _wait(1.2)
		var sk := (gs6.fields[sf] as FieldData).kind
		var want := Style.icon(ui._kind_icon(int(gs6.rows9[sk])))
		var sp := world.field_screen(sf)
		await _touch(sp["pos"])
		await _wait(0.7)
		sheet_txt = "%s → %s" % [FieldData.kind_name(sk), FieldData.kind_name(int(gs6.rows9[sk]))]
		sheet_ok = ui.sheet.visible and ui.sheet_title.text == FieldData.kind_name(sk) and ui.sheet_ladder.visible \
			and ui.sheet_next.texture == want and ui.sheet_caps.text != "Essen"
		await _shot(dir, "b12e2_feldkarte_regel")
		ui._close_sheet()
		await _wait(0.5)
	_check(sheet_ok, "sheet_rule_camp", "feld=%d regel=%s karte=%s" % [sf, sheet_txt, ui.sheet_title.text])
	# 7. „Man soll immer genau wissen, was man tun muss“: oben steht in jedem Level die nächste Handlung der Regeln
	await _b12_task_at_top(dir)
	# 8. „3 Felsen in einer Reihe … nichts passiert“: keine Reihe steht schon am Start, eine echte Fels-Reihe wächst
	await _b12_rock_rows(dir)
	# 9. Mitten im Level die App schließen: der Versuch geht genau dort weiter
	await _b12_save_mid(dir, fb)


var _b12_res: Dictionary = {}      # die letzte Runde (Game.round_resolved), für die Prüfungen unten


func _b12_on_round(result: Dictionary, _before: Dictionary) -> void:
	_b12_res = result


## Wie viele Wörter hat eine Zeile (ohne „→ Ergebnis“)?
func _b12_words(t: String) -> int:
	return t.split(" ", false).size()


## Zeigt die Zeile oben, was die Regeln sagen (text oder line), mittig in der Kopfzeile über dem Würfel?
func _b12_line_ok(na: Dictionary) -> bool:
	var dui := ui.day_ui
	var shown := str(dui.action_shown.get("text", ""))
	var vs := get_viewport().get_visible_rect().size
	var r := dui.act_line.get_global_rect()
	return dui.act_line.visible and shown != "" and (shown == str(na.get("text", "")) or shown == str(na.get("line", ""))) \
		and r.end.y <= vs.y * 0.22 and dui.chip.visible and _b12_words(str(na.get("text", ""))) <= 6


## In Leveln aus mehreren Akten: Nach dem Start und nach jeder Aktion steht oben genau die Handlung der Regeln
## (GameState.next_action). Was sie nennt, geht wirklich: eine genannte Reihe wächst (Simulation), ein Werkzeug wirkt,
## „Hol dir Hilfe“ ist selbst der Knopf. Gespielt wird, was die Zeile sagt (echte Eingabe).
func _b12_task_at_top(dir: String) -> void:
	var dui := ui.day_ui
	if not Game.round_resolved.is_connected(_b12_on_round):
		Game.round_resolved.connect(_b12_on_round)
	var said: Array = []
	var bad: Array = []
	var impossible: Array = []
	# Erdgeschichte: je ein Level aus Kambrium, Saurierzeit und Feuer, je 3 Schritte (die Tour bleibt kurz)
	for n in [12, 32, 46]:
		await _start_lvl(n, 0)
		await _wait(1.0)
		for step in 3:
			if not Game.in_day() or Game.state.day_won:
				break
			var na := Game.next_action()
			if not _b12_line_ok(na):
				bad.append([n, step, str(dui.action_shown.get("text", "")), str(na.get("text", ""))])
			said.append("L%d:%s" % [n, str(na.get("text", ""))])
			if step == 0:
				await _shot(dir, "b12f_aufgabe_L%d" % n)
			var mv: Dictionary = na.get("move", {})
			var typ := str(na.get("type", ""))
			if typ == "help":
				var g0 := Game.state.actions9()
				await _tap(dui.act_line)
				await _settle(8.0)
				if Game.state.actions9() == g0:
					impossible.append([n, step, "hilfe"])
			elif str(na.get("tool", "")) == "rain" and int(na.get("field", -1)) >= 0:
				if not Game.use_bonus("rain", int(na["field"]), [], true):
					impossible.append([n, step, "regen"])
				await _settle(8.0)
			elif not mv.is_empty():
				var tw := _twist(int(mv["axis"]), int(mv["layer"]), int(mv["turns"]))
				if typ == "row" and int(na.get("steps", 1)) == 1:
					var sim: Dictionary = Game.state.simulate(tw)
					if not _has_event(sim["result"], "merge"):
						impossible.append([n, step, str(na.get("text", ""))])
				await _swipe_move(int(mv["axis"]), int(mv["layer"]), int(mv["turns"]))
				await _settle(8.0)
			else:
				var m: Array = GameState.MOVES[(n + step * 7) % GameState.MOVES.size()]
				await _swipe_move(int(m[0]), int(m[1]), int(m[2]))
				await _settle(8.0)
			await _wait(0.6)
		if Game.in_day() and not Game.state.day_won:
			var na2 := Game.next_action()
			if not _b12_line_ok(na2):
				bad.append([n, "ende", str(dui.action_shown.get("text", "")), str(na2.get("text", ""))])
	_check(bad.is_empty() and impossible.is_empty() and said.size() >= 8 and _b12_field_icons() == 0, "task_at_top",
		"zeilen=%s falsch=%s unmoeglich=%s" % [str(said), str(bad.slice(0, 3)), str(impossible)])


## Eine Drehung bildet eine neue Fels-Reihe (sie wächst, oder die Runde sagt, warum nicht).
func _b12_p_fels(_gs: GameState, r: Dictionary) -> bool:
	for e in (r["result"] as Dictionary)["events"]:
		var ed: Dictionary = e
		if str(ed["type"]) == "merge" and int(ed.get("from", -1)) == FieldData.FELS and not bool(ed.get("late", false)):
			return true
	return false


## Reihen auf dem Brett, die nicht gewachsen sind (dürfen nach keiner Runde und an keinem Start stehen).
func _b12_dead_rows(gs: GameState) -> int:
	var n := 0
	for ln in gs.lines():
		if not gs.spent.has(GameState.line_key(ln)):
			n += 1
	return n


## Akt 1 (und Level 5): Kein Level beginnt mit einer fertigen Reihe (die zählte nie: „nichts passiert“). Dann eine
## Fels-Reihe per echtem Wisch: sie wächst sichtbar zu Erde (oder eine Pille sagt warum), danach steht keine Reihe still.
func _b12_rock_rows(dir: String) -> void:
	var pre: Array = []
	var starts := 0
	for n in [1, 2, 3, 4, 5]:
		for b in range(0, mini(3, Campaign.pool_size(n))):
			Game.start_level(n, b)
			await get_tree().process_frame
			starts += 1
			if _b12_dead_rows(Game.state) > 0:
				pre.append([n, b])
		Game.start_level(n)          # die eigene (getragene) Welt
		await get_tree().process_frame
		starts += 1
		if _b12_dead_rows(Game.state) > 0:
			pre.append([n, "eigen"])
	ui._close_modal(true)
	var lv := 4
	var fb := _find_board(4, _b12_p_fels, 1)
	if int(fb[0]) < 0:
		lv = 5
		fb = _find_board(5, _b12_p_fels, 1)
	var grew := false
	var told := ""
	var dead_after := -1
	var mv: Array = []
	if int(fb[0]) >= 0:
		await _start_lvl(lv, int(fb[0]))
		for m in GameState.MOVES:
			var mm: Array = m
			if _b12_p_fels(Game.state, Game.state.simulate(_twist(int(mm[0]), int(mm[1]), int(mm[2])))):
				mv = mm
				break
	if not mv.is_empty():
		if not Game.round_resolved.is_connected(_b12_on_round):
			Game.round_resolved.connect(_b12_on_round)
		_b12_res = {}
		_stills.clear()
		world.focus_place(Vector3i(0, 1, 0))
		await _wait(0.6)
		await _swipe_move(int(mv[0]), int(mv[1]), int(mv[2]))
		var shot_done := false
		for i in 80:
			if not _b12_res.is_empty() and not shot_done:
				for e in _b12_res["events"]:
					var ed: Dictionary = e
					if str(ed["type"]) == "merge" and int(ed.get("from", -1)) == FieldData.FELS:
						grew = true
						world.focus_field(int(ed["field"]))
				shot_done = true
			if ui.banner.visible and told == "":
				told = ui.banner_caps.text
			if shot_done and not Game.busy and not world.animating:
				break
			await _wait(0.1)
		await _wait(0.8)
		await _shot(dir, "b12g_fels_reihe")
		await _settle(8.0)
		dead_after = _b12_dead_rows(Game.state)
	_check(pre.is_empty() and starts >= 15 and not mv.is_empty() and (grew or told != "") and dead_after == 0, "rock_row_counts",
		"start_reihen=%s level=%d brett=%s zug=%s gewachsen=%s pille=%s still=%d" % [str(pre), lv, str(fb[0]), str(mv),
		str(grew), told, dead_after])


## Kurzer Fingerabdruck eines Versuchs (Brett, Schritte, Fortschritt, Siegel, Gefahren, Werkzeuge, Geschenke).
func _b12_run_print() -> String:
	var gs := Game.state
	return "%s|%s|%d|%d|%d|%d|%d|%s|%s|%s" % [gs.record9(), var_to_str(gs.save9()).md5_text(), gs.steps9(), gs.progress9(),
		gs.rain, gs.meteors, gs.actions9(), str(gs.spent.keys()), str(gs.standing.keys()), str(gs.broken.keys())]


## Mitten im Level (Vulkan-Level, ein paar echte Züge, Ausbruch) die App „schließen“ und neu starten: Brett, Schritte,
## Fortschritt, Siegel, Gefahren, Werkzeuge und Geschenk-Stand sind genau wie vorher, keine Start-Karte, dieselbe Zeile
## oben – und der nächste Zug ergibt genau dasselbe.
func _b12_save_mid(dir: String, fb: Array) -> void:
	var dui := ui.day_ui
	var lv := 3
	await _start_lvl(lv, maxi(0, int(fb[0])))
	var moves: Array = (fb[1] as Array).duplicate()
	var na0 := Game.next_action()
	var m0: Dictionary = na0.get("move", {})
	if not m0.is_empty():
		moves.append([int(m0["axis"]), int(m0["layer"]), int(m0["turns"])])
	for m in moves:
		var mm: Array = m
		await _swipe_move(int(mm[0]), int(mm[1]), int(mm[2]))
		await _settle(8.0)
	await _wait(0.6)
	var steps0 := Game.state.steps9()
	var fp0 := _b12_run_print()
	var text0 := str(dui.action_shown.get("text", ""))
	var free0 := [Game.hint_free_left, Game.undo_free_left]
	var probe: Array = GameState.MOVES[5]
	var next0: String = (Game.state.simulate(_twist(int(probe[0]), int(probe[1]), int(probe[2])))["state"] as GameState).record9()
	await _shot(dir, "b12h_vor_dem_schliessen")
	# App zu (Schließen-Anfrage), dann ein anderes Level im Speicher (wie ein Neustart: nichts bleibt im Speicher)
	Game.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	var path := Game.run_path()
	var saved := FileAccess.file_exists(path)
	var bytes := FileAccess.get_file_as_bytes(path) if saved else PackedByteArray()
	Game.start_level(1, 0)
	await get_tree().process_frame
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_buffer(bytes)
		f.close()
	ui._close_modal(true)
	ui.debug_close_all()
	await _wait(0.3)
	# Neustart: Game._ready setzt fort, die Oberfläche geht ohne Übersicht und Start-Karte ins Level
	var resumed := Game.resume_run()
	await _wait(2.0)
	var fp1 := _b12_run_print() if Game.state != null else ""
	var views_ok := true
	for fid in world.views:
		var v: FieldView = world.views[fid]
		if v._kind != (Game.state.fields[int(fid)] as FieldData).kind:
			views_ok = false
	var text1 := str(dui.action_shown.get("text", ""))
	var no_card := not (dui.goal_card.visible and dui.goal_card.modulate.a > 0.5) and not dui.overview.visible
	var next1: String = (Game.state.simulate(_twist(int(probe[0]), int(probe[1]), int(probe[2])))["state"] as GameState).record9()
	await _shot(dir, "b12i_nach_neustart")
	# Und echt weiter: derselbe Zug wie vorhergesagt
	await _swipe_move(int(probe[0]), int(probe[1]), int(probe[2]))
	await _settle(8.0)
	var real_same := Game.state.record9() == next0
	_check(saved and resumed and steps0 > 0 and fp0 == fp1 and views_ok and text0 == text1 and no_card and next0 == next1 and real_same
		and Game.level_no == lv and [Game.hint_free_left, Game.undo_free_left] == free0 and Game.level_info().get("resumed", false),
		"save_mid_level", "datei=%s fortgesetzt=%s schritte=%d gleich=%s felder=%s zeile=%s/%s karte_zu=%s naechster=%s echt=%s" % [
		str(saved), str(resumed), steps0, str(fp0 == fp1), str(views_ok), text0, text1, str(no_card), str(next0 == next1), str(real_same)])
	Game.retry_level()
	await _wait(0.5)
	ui._close_modal(true)



# =============================================================================
# Erdgeschichte – Grafik (GDPD_ERDGESCHICHTE_GRAFIK.md 13): je Zeitalter ein Bild (e_<name>), Decke und Eis auf allen
# Boden-Materialien (auch neu gebauten), Eis an der Fuge auf beiden Seiten gleich, Gestalten der Arten, Einschlag,
# Übergang, Leistung. Freies Brett (unabhängig von den Kampagnen-Regeln), Arten direkt gemalt.
# =============================================================================

## Bretter wie tests/era_lookdev.gd (oben, vorn +z, rechts +x; Zeile für Zeile, ein Buchstabe je Art).
const ERDE_KEY := {"B": 0, "G": 1, "W": 2, "T": 5, "H": 6, "K": 10, "A": 15, "R": 16, "F": 23, "P": 25, "q": 27, "t": 28, "i": 29,
	"b": 30, "e": 31, "d": 32, "x": 33, "p": 34, "c": 35, "j": 36, "k": 37, "y": 38, "f": 39}
const ERDE_BOARDS := {
	"kambrium": ["AqA/qtB/RBR", "RAq/BtA/RBA", "qAR/tqB/AAR"],
	"karbon": ["iWW/bAA/eFW", "AbW/eiW/FWW", "WWi/FbA/WiA"],
	"saurier": ["ddF/dAA/WxF", "AAW/xFW/ppF", "WWF/ddA/FAA"],
	"eiszeit": ["jjG/GAA/WPc", "AAW/PGc/ccG", "WWG/jjA/cAA"],
	"savanne": ["kGW/GAA/ykG", "AAG/kkW/WGG", "GGW/TTA/GAA"],
	"feuer": ["fGW/GAA/kyG", "AAG/fGW/WkG", "GfW/yyA/GAA"],
	"tag": ["TTG/GAA/WPG", "AAW/PGR/GWG", "GWW/TTA/GAA"],      # Vergleich: die heutige Welt (gleiche Messung)
}


func _erde_paint(board: Array) -> void:
	for f in Game.state.fields:
		(f as FieldData).kind = FieldData.MEADOW
		(f as FieldData).fresh = 0
		(f as FieldData).burning = false
	for face in 3:
		var rows := String(board[face]).split("/")
		for r in 3:
			for c in 3:
				var k := int(ERDE_KEY.get(rows[r][c], 1))
				match face:
					0:
						_paint_at(Vector3i(c - 1, 1, r - 1), Vector3i(0, 1, 0), k)
					1:
						_paint_at(Vector3i(c - 1, 1 - r, 1), Vector3i(0, 0, 1), k)
					2:
						_paint_at(Vector3i(1, 1 - r, 1 - c), Vector3i(1, 0, 0), k)
	Game.state.wishes = []
	world.refresh_all()


func _erde_agents() -> Dictionary:
	var seen := {}
	for fid in world.views:
		var v: FieldView = world.views[fid]
		for k in v.agent_kinds() + v.flyer_kinds():
			seen[String(k)] = int(seen.get(String(k), 0)) + 1
	return seen


func _erde_look_tour(dir: String) -> void:
	ui.debug_close_all()
	Game.new_game(5151, 1, 1)
	Game.onboarding = false          # keine Vorführung und kein Hinweis-Leuchten: nur Bilder und Messungen
	await _wait(1.0)
	ui.visible = false
	world._abort_demo()
	world._hinted = true
	world._clear_hint()
	# Gestalten je Zeitalter: was da sein muss, was nicht da sein darf (CHECK era_models)
	var want := {"kambrium": [["jelly", "trilobite"], ["fish", "bison"]], "karbon": [["dragonfly", "amph", "lizard"], ["deer", "bison"]],
		"saurier": [["sauro", "ptero"], ["bison", "deer", "wolf"]], "eiszeit": [["mammoth", "cave_lion"], ["wolf", "sheep"]],
		"savanne": [["ape", "antelope", "hunter"], ["bison", "sauro"]], "feuer": [["hunter"], ["sauro", "mammoth"]]}
	for en in ["tag", "kambrium", "karbon", "saurier", "eiszeit", "savanne", "feuer"]:
		world.set_era(en, 0.0)
		_erde_paint(ERDE_BOARDS[en])
		world.debug_view(Vector3(1.0, 1.15, 1.35), Vector3.UP, 1.0)
		await _wait(1.6)
		world._abort_demo()
		world._clear_hint()
		await _shot(dir, "e_" + en)
		var seen := _erde_agents()
		if not want.has(en):
			_check(true, "perf", "era=%s draw=%d prims=%d" % [en, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
			continue
		var miss: Array = []
		var bad: Array = []
		for k in (want[en] as Array)[0]:
			if not seen.has(k):
				miss.append(k)
		for k in (want[en] as Array)[1]:
			if seen.has(k):
				bad.append(k)
		_check(miss.is_empty() and bad.is_empty(), "era_models", "era=%s fehlt=%s falsch=%s" % [en, str(miss), str(bad)])
		_check(true, "perf", "era=%s draw=%d prims=%d" % [en, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
	# Decke: alle Boden-Materialien tragen denselben Schnee (auch ein neu gebautes), Laub auch (CHECK era_blanket)
	world.set_era("eiszeit", 0.0)
	await _wait(0.3)
	var fresh := Look.ground_material()
	var ok_b := absf((fresh.get_shader_parameter("blanket") as Color).a - 0.4) < 0.001
	var ice_vals := {}
	for fid in world.views:
		var gm: ShaderMaterial = (world.views[fid] as FieldView)._ground
		var bc: Color = gm.get_shader_parameter("blanket")
		ok_b = ok_b and absf(bc.a - 0.4) < 0.001
		ice_vals[snappedf(float(gm.get_shader_parameter("ice")), 0.001)] = true
	var fol := Look.foliage(Color.WHITE, true)
	ok_b = ok_b and absf((fol.get_shader_parameter("blanket") as Color).a - 0.4) < 0.001
	_check(ok_b, "era_blanket", "eiszeit decke=0.4 felder=%d" % world.views.size())
	# Eis an der Fuge: eine Welt-Größe, auf beiden Seiten jeder Fuge derselbe Wert (Maske aus wd und Würfel-Rauschen)
	_check(ice_vals.size() == 1 and ice_vals.has(0.55), "ice_seam", "werte=%s" % str(ice_vals.keys()))
	# Übergang (Welle über den Würfel): danach haben alle Felder die Gestalt des neuen Zeitalters
	_erde_paint(ERDE_BOARDS["savanne"])
	await _wait(0.6)
	await world.era_transition("eiszeit")
	await _wait(0.6)
	var seen2 := _erde_agents()
	_check(seen2.has("bison") and not seen2.has("antelope") and world.era_name == "eiszeit", "era_transition",
		"tiere=%s" % str(seen2.keys()))
	# Einschlag: die Saurier werden Asche, der Himmel wird Aschewinter, Licht über den Untergrenzen (CHECK meteor_era)
	world.set_era("saurier", 0.0)
	_erde_paint(ERDE_BOARDS["saurier"])
	world.set_meteor(true)
	world.debug_view(Vector3(1.0, 1.15, 1.35), Vector3.UP, 1.0)
	await _wait(1.6)
	await _shot(dir, "e_meteor_kommt")
	var dinos: Array = []
	for f in Game.state.fields:
		if [32, 33, 34].has((f as FieldData).kind):
			dinos.append((f as FieldData).id)
			(f as FieldData).kind = FieldData.EMPTY
	world.meteor_strike(dinos)
	await _wait(1.2)
	await _shot(dir, "e_einschlag")
	await _wait(2.6)
	await _shot(dir, "e_asche")
	var m: Dictionary = World.MOODS["asche"]
	var floors := float(m["sun_e"]) >= 0.8 and float(m["fill_e"]) >= 0.6 and float(m["amb_e"]) >= 0.85 and float(m["sat"]) >= 0.75
	var dead := 0
	for fid in dinos:
		if (world.views[int(fid)] as FieldView).get_kind() == FieldView.K_EMPTY:
			dead += 1
	_check(world.era_name == "asche" and floors and dead == dinos.size() and not world.meteor_visible(), "meteor_era",
		"zeitalter=%s untergrenzen=%s asche=%d/%d" % [world.era_name, str(floors), dead, dinos.size()])
	world.set_era("", 0.0)
	ui.visible = true


# --- Erdgeschichte: die neuen Zeitalter (Spec GDPD_ERDGESCHICHTE.md 14) -------------------------------------------

var _eras_seen := {}              # Zeitalter (Nummer), in denen die Tour ein Level gestartet hat


func _note_level(info: Dictionary) -> void:
	if not bool(info.get("wdt", false)):
		_eras_seen[Campaign.era_index(int(info.get("level", 0)))] = true


## Die Zeile oben (Build 12): nicht leer, kurz.
func _line_ok() -> bool:
	var t := ui.day_ui.act_label.text
	return ui.day_ui.act_line.visible and t != "" and _b12_words(t) <= 8


## Ein Level, das ein neues Zeitalter beginnt: Übergang (Name kurz über dem Würfel), dann die Ziel-Karte und „Los!“.
## [Übergang lief, Titel] – der Übergang läuft nur beim ersten Besuch des Zeitalters.
func _start_era(n: int, board: int, dir: String, shot_name: String) -> Array:
	var dui := ui.day_ui
	var a0 := dui.act_shown
	Game.coach_seen.erase("era_%s" % Campaign.era_of(n))
	Game.start_level(n, board)
	await _wait(1.3)
	await _shot(dir, shot_name)
	var card := await _until_shown(dui.goal_card, 8.0)
	await _wait(0.3)
	var caps_ok := dui.gc_caps.text.begins_with(Campaign.act_name(Campaign.era_index(n)))
	if card:
		await _tap(dui.gc_go)
	await _wait(1.0)
	ui._coach_dismiss()
	return [dui.act_shown == a0 + 1 and caps_ok, dui.era_shown]


func _views_of(k: int) -> int:
	var c := 0
	for fid in world.views:
		if (world.views[fid] as FieldView).get_kind() == k:
			c += 1
	return c


func _erde_tour(dir: String) -> void:
	var dui := ui.day_ui
	var t0 := Time.get_ticks_msec()
	if not Game.round_resolved.is_connected(_on_tour_round):
		Game.round_resolved.connect(_on_tour_round)
	# Kambrium · Level 12: das Meer wimmelt (Quallen, klares Wasser)
	var e12 := await _start_era(12, 0, dir, "20a_kambrium_uebergang")
	await _shot(dir, "20b_kambrium")
	var kamb_ok := bool(e12[0]) and str(e12[1]) == "Kambrium" and world.era_name == "kambrium" and _line_ok()
	# Saurierzeit · Level 28: der Übergang nennt das Zeitalter, Saurier stehen auf dem Würfel, die Zeile sagt, was zu tun ist
	var e28 := await _start_era(28, 0, dir, "21a_saurierzeit_uebergang")
	await _wait(0.6)
	await _shot(dir, "21b_saurier")
	var dinos := _views_of(FieldData.SAURO)
	var dino_ok := bool(e28[0]) and str(e28[1]) == "Saurierzeit" and world.era_name == "saurier" and dinos >= 3 and _line_ok()
	# Level 32: drei Raubsaurier jagen (Warnung eine Runde vorher); die Zeile wendet es ab
	var fb := _find_board(32, _p_rex_warn)
	await _start_lvl(32, maxi(0, int(fb[0])))
	_round_types = {}
	for m in fb[1]:
		await _swipe_m(m)
	var warned := not Game.state.pack_warn9.is_empty() and dui.pill9_last == "pack_warn" and ui.banner_text.text + ui.banner_caps.text != "" \
		and (ui.banner_caps.text.contains("Raubsaurier") or ui.banner_text.text.contains("Raubsaurier"))
	await _shot(dir, "21c_raubsaurier_jagen")
	var na: Dictionary = dui.next_action(Game.state)
	var mv: Dictionary = na.get("move", {})
	var line_fix := str(na.get("danger", "")) == "pack" and not mv.is_empty()
	var cancelled := false
	if line_fix:
		_round_types = {}
		await _swipe_m([int(mv["axis"]), int(mv["layer"]), int(mv["turns"])])
		cancelled = not _seen_type("pack_hunt")
	_check(dino_ok and warned and line_fix and cancelled, "dino_era",
		"titel=%s aera=%s saurier=%d zeile=%s warnung=%s abwenden=%s/%s pille=%s|%s" % [str(e28[1]), world.era_name, dinos,
		dui.act_label.text, str(warned), str(line_fix), str(cancelled), ui.banner_caps.text, ui.banner_text.text])
	# Der Einschlag · Level 34: angekündigt (Meteor am Himmel, Pille, Zeile), nach der ersten Drehung sind alle Saurier
	# Asche, der Himmel wird Asche, der Chip zählt keinen Verlust
	var e34 := await _start_era(34, 0, dir, "22a_einschlag_uebergang")
	var pill_seen := false
	for i in 140:
		if ui.banner.visible and ui.banner_text.text == "Meteor kommt!":
			pill_seen = true
			break
		await _wait(0.05)
	await _wait(0.6)
	await _shot(dir, "22b_meteor_kommt")
	var na34: Dictionary = dui.next_action(Game.state)
	var before_ok := Game.state.impact_pending9() and world.meteor_visible() and dui.act_label.text == "Dreh, der Meteor kommt" \
		and dui.chip_num.text.begins_with("0/") and pill_seen
	var dino0 := Game.state.count(FieldData.SAURO) + Game.state.count(FieldData.REX) + Game.state.count(FieldData.PTERO)
	var p0 := Game.state.goal_progress()
	var m34: Dictionary = na34.get("move", {})
	_round_types = {}
	if not m34.is_empty():
		await _swipe_move(int(m34["axis"]), int(m34["layer"]), int(m34["turns"]))
		await _wait(1.4)
		await _shot(dir, "22c_einschlag")
		await _settle(12.0)
	await _wait(1.5)
	await _shot(dir, "22d_asche")
	var dino1 := Game.state.count(FieldData.SAURO) + Game.state.count(FieldData.REX) + Game.state.count(FieldData.PTERO)
	var after_ok := Game.state.impact_done9 and dino1 == 0 and dino0 > 0 and _seen_type("impact") and world.era_name == "asche" \
		and Game.state.goal_progress() >= p0 and _views_of(FieldData.SAURO) == 0
	_check(bool(e34[0]) and str(e34[1]) == "Der Einschlag" and before_ok and after_ok, "meteor_transition",
		"titel=%s vorher=%s pille=%s zeile=%s chip=%s saurier=%d->%d aera=%s fortschritt=%d->%d" % [str(e34[1]), str(before_ok),
		str(pill_seen), dui.act_label.text, dui.chip_num.text, dino0, dino1, world.era_name, p0, Game.state.goal_progress()])
	# Eiszeit · Level 40: ein Eis-Klumpen wächst (Warnung, „Teil das Eis!“), die Drehung der Zeile beruhigt ihn
	var fi := _find_board(40, _p_glacier)
	var e40 := await _start_era(40, maxi(0, int(fi[0])), dir, "24a_eiszeit_uebergang")
	_round_types = {}
	for m in fi[1]:
		await _swipe_m(m)
	var gl_warn := Game.state.glac9 >= 0 and dui.pill9_last == "glacier_warn" and dui.act_label.text == "Teil das Eis!"
	await _shot(dir, "24b_gletscher_waechst")
	var na40: Dictionary = dui.next_action(Game.state)
	var m40: Dictionary = na40.get("move", {})
	var calm := false
	if not m40.is_empty():
		_round_types = {}
		await _swipe_m([int(m40["axis"]), int(m40["layer"]), int(m40["turns"])])
		calm = Game.state.glac9 < 0 and not _seen_type("freeze")
	await _shot(dir, "24c_eis_geteilt")
	_check(bool(e40[0]) and str(e40[1]) == "Eiszeit" and world.era_name == "eiszeit" and gl_warn and calm and _views_of(FieldData.ICE) > 0,
		"ice_age", "titel=%s aera=%s warnung=%s ruhe=%s eis=%d" % [str(e40[1]), world.era_name, str(gl_warn), str(calm), _views_of(FieldData.ICE)])
	# Affen · Level 43: Tiere zwischen zwei Wäldern klettern hinauf
	var fa := _find_board(43, _p_more.bind(FieldData.APES), 2)
	var e43 := await _start_era(43, maxi(0, int(fa[0])), dir, "25a_affen_uebergang")
	var apes0 := Game.state.count(FieldData.APES)
	for m in fa[1]:
		await _swipe_m(m)
	await _wait(0.8)
	await _shot(dir, "25b_affen")
	_check(bool(e43[0]) and str(e43[1]) == "Affen" and Game.state.count(FieldData.APES) > apes0 and _views_of(FieldData.APES) > 0,
		"apes_climb", "titel=%s affen=%d->%d" % [str(e43[1]), apes0, Game.state.count(FieldData.APES)])
	# Feuer · Level 46: ein Frühmensch neben Fels und Wald macht Feuer (Feuerstelle mit Licht)
	var ff := _find_board(46, _p_more.bind(FieldData.CAMP), 2)
	var e46 := await _start_era(46, maxi(0, int(ff[0])), dir, "26a_feuer_uebergang")
	var camp0 := Game.state.count(FieldData.CAMP)
	var early0 := _views_of(FieldData.EARLY)
	for m in ff[1]:
		await _swipe_m(m)
	await _wait(1.0)
	await _shot(dir, "26b_feuerstelle")
	_check(bool(e46[0]) and str(e46[1]) == "Feuer" and early0 > 0 and Game.state.count(FieldData.CAMP) > camp0
		and _views_of(FieldData.CAMP) > 0 and world.era_name == "feuer" and _line_ok(), "early_humans_fire",
		"titel=%s fruehmenschen=%d feuer=%d->%d aera=%s" % [str(e46[1]), early0, camp0, Game.state.count(FieldData.CAMP), world.era_name])
	# Die übrigen Zeitalter einmal: Name auf der Karte, Zeile oben
	var rest_ok := kamb_ok
	var rest_notes: Array = ["12:%s" % str(kamb_ok)]
	for n in [54, 56, 57]:
		var e := await _start_era(n, 0, dir, "27_zeitalter_level%d" % n)
		var ok_n := bool(e[0]) and _line_ok()
		rest_ok = rest_ok and ok_n
		rest_notes.append("%d:%s" % [n, str(ok_n)])
	var missing: Array = []
	for a in range(1, Campaign.era_count() + 1):
		if not _eras_seen.has(a):
			missing.append(a)
	_check(rest_ok and (missing.is_empty() or _only == "erde"), "era_levels_visit", "%s fehlen=%s" % [str(rest_notes), str(missing)])
	if Game.round_resolved.is_connected(_on_tour_round):
		Game.round_resolved.disconnect(_on_tour_round)
	print("Tour: Erdgeschichte-Zeitalter %.0f s" % ((Time.get_ticks_msec() - t0) / 1000.0))


func _p_rex_warn(_gs: GameState, r: Dictionary) -> bool:
	var st: GameState = r["state"]
	return not st.pack_warn9.is_empty() and str(st.next_action().get("danger", "")) == "pack"


func _p_glacier(_gs: GameState, r: Dictionary) -> bool:
	var st: GameState = r["state"]
	return st.glac9 >= 0 and str(st.next_action().get("text", "")) == "Teil das Eis!"


## migration_from_schoepfung: ein Spielstand der alten Kampagne („Die Schöpfung“, 30 Level, alte Level 1–19 geschafft)
## wird beim Laden zur Erdgeschichte: Position 25, die übersprungenen neuen Level offen als „Nachholen“, Sterne wandern
## mit, der Charakter sagt „Die Welt ist größer geworden.“, die Heute-Karte bietet das erste Nachholen an.
func _migration_check(dir: String) -> void:
	var dui := ui.day_ui
	ui.debug_close_all()
	Game.debug_open_all = false
	Game.debug_day_offset = 0
	Game.clock_override = Daily.local_unix(2026, 11, 12, 10, 0)
	var path := "user://tour_alter_spielstand.cfg"
	var cfg := ConfigFile.new()
	cfg.load(Game.save_path)          # der eigene Gott und die Einstellungen bleiben
	if cfg.has_section("kampagne"):
		cfg.erase_section("kampagne")
	var today := Daily.day_key(Game.clock_override)
	var st: Array = []
	var sp: Array = []
	var wk: Array = []
	for j in 30:
		st.append(2 if j < 19 else 0)
		sp.append(6 + j % 5 if j < 19 else 0)
		wk.append(today - 25 + j if j < 19 else -1)
	st[13] = 3
	cfg.set_value("kampagne", "version", 1)
	cfg.set_value("kampagne", "sterne", st)
	cfg.set_value("kampagne", "schritte", sp)
	cfg.set_value("kampagne", "gewonnen_am", wk)
	cfg.set_value("kampagne", "letzter_neuer", today - 1)
	cfg.set_value("kampagne", "brett", [])
	cfg.save(path)
	var old_path := Game.save_path
	Game.save_path = path
	Game._load_best()
	Game.clock_override = Daily.local_unix(2026, 11, 12, 10, 0)
	await get_tree().process_frame
	var cu: Array = []
	for n in range(1, 25):
		if Game.level_unlocked(n) and Game.level_stars(n) == 0:
			cu.append(n)
	var pos := int(Game.camp.get("pos", 0))
	var stars_ok := Game.level_stars(1) == 2 and Game.level_stars(25) == 2 and Game.level_stars(50) == 3 and Game.level_stars(18) == 2 \
		and not Game.level_unlocked(26)
	dui.show_overview(false)
	await _wait(1.6)
	await _shot(dir, "30a_umstellung_uebersicht")
	var said := dui.ov_say.text == str(Campaign.TEXT["bigger"])
	var b7 := dui.level_btn(7)
	var dot7 := b7 != null and bool(b7.get_meta("catchup", false)) and b7.is_visible_in_tree()
	var today_ok := str(dui._today.get("state", "")) == "catchup" and dui.tc_caps.text == str(Campaign.TEXT["catchup_caps"]) % 7 \
		and dui.tc_title.text == str(Campaign.config(7).get("title", ""))
	_era_overview_check("umstellung")
	var era_names: Array = []
	for t in dui.ov_acts:
		if ((t as Dictionary)["panel"] as Control).visible:
			era_names.append(((t as Dictionary)["name"] as Label).text)
	dui.ov_scroll.ensure_control_visible(dui.level_btn(24))
	await _wait(0.5)
	await _shot(dir, "30b_umstellung_nachholen")
	dui.ov_scroll.scroll_vertical = 0
	await _wait(0.3)
	await _tap(dui.tc_go)
	var card := await _until_shown(dui.goal_card, 8.0)
	await _wait(0.5)
	await _shot(dir, "30c_nachholen_level7")
	var card_ok := card and Game.level_no == 7 and dui.gc_caps.text.begins_with(str(Campaign.TEXT["catchup"]))
	_check(pos == 25 and cu == [7, 11, 12, 13, 14, 17, 20, 23, 24] and stars_ok and said and dot7 and today_ok and card_ok
		and era_names.size() == 9 and str(era_names[8]) == "?", "migration_from_schoepfung",
		"position=%d nachholen=%s sterne=%s gesagt=%s punkt7=%s heute=%s|%s karte=%s zeitalter=%s" % [pos, str(cu), str(stars_ok),
		str(said), str(dot7), dui.tc_caps.text, dui.tc_title.text, str(card_ok), str(era_names)])
	ui.debug_close_all()
	Game.save_path = old_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
