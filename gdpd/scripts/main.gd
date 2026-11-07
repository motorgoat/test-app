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
	world.tour_auto = true          # die Tour darf Züge ohne Finger spielen (das Spiel selbst nie)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	_only = only
	var t0 := Time.get_ticks_msec()
	if only == "" or only == "days" or only == "day1":
		await _days_tour(dir)
		print("Tour: Tage fertig nach %.0f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if only == "" or only == "free":
		await _free_tour(dir)
	if only == "" or only == "free" or only == "seamless":
		await _seamless_tour(dir)
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
	_check(won and wcard and Game.state.day_won and Game.stars_of(1) >= 1 and dui.wc_next.text == str(Days.TEXT["build"])
		and dui.wc_next_line.visible and dui.wc_next_line.text == line2 and dui.wc_streak_num.text == "1" and Game.streak() == 1,
		"day_success", "won=%s stars=%d drehungen=%d knopf=%s zeile=%s serie=%s" % [str(won), Game.stars_of(1), Game.state.day_won_at,
		dui.wc_next.text, dui.wc_next_line.text, dui.wc_streak_num.text])
	if _only == "day1":
		return
	# 4. „Weiterbauen“ (echte Eingabe). Vorher fragt der Charakter einmal, ob er morgen erinnern darf (am Handy
	# kommt danach der Android-Dialog): „Lieber nicht“
	await _tap(dui.wc_next)
	var ask := await _until_shown(dui.ask_card, 4.0)
	await _wait(0.6)
	await _shot(dir, "00e2_erinnern_frage")
	var ask_ok := ask and dui.ask_text.text == CharacterTexts.fill(str((CharacterTexts.LINES["ask_reminder"] as Dictionary)["frech"]), {"tag": "Tag 2: Pflanzen"})
	await _tap(dui.ask_no)
	await _wait(1.2)
	_check(ask_ok and int(Game.remind["asked"]) == 1 and not dui.ask_card.visible, "permission_ask",
		"frage=%s gefragt=%d" % [dui.ask_text.text.left(40), int(Game.remind["asked"])])
	# Weiterbauen: kein Drehungs-Limit, kein Scheitern – die Welt wächst weiter (3 echte Drehungen)
	var gs1 := Game.state
	var g0 := gs1.build_growth()
	# Die Aufgabe bleibt sichtbar: als Extra-Aufgabe („Extra: 9 Wiesen“, GDPD_BALANCE_2.md 6.3)
	var chip_build := dui.chip.visible and dui.grow_box.visible and not dui.ring.visible \
		and dui.chip_caps.text == Days.extra_line(Game.state.day, Game.state.extra_target())
	for i in 3:
		var act := Game.state.best_action()
		if act.is_empty() or str(act.get("type", "twist")) != "twist":
			var d := _twist_without_progress()
			act = {"axis": d[0], "layer": d[1], "turns": d[2], "choice": 0}
		await _swipe_move(int(act["axis"]), int(act["layer"]), int(act["turns"]))
		await _settle(8.0, int(act.get("choice", 0)))
	await _wait(0.8)
	await _shot(dir, "00v_weiterbauen")
	var g1 := Game.state.build_growth()
	_check(chip_build and Game.state == gs1 and gs1.day_free_build and gs1.twists_left() == -1 and gs1.day_won and gs1.day_lost == ""
		and not Game.over and not dui.fail_card.visible and not dui.win_card.visible and g1 > g0 and dui.grow_num.text == str(g1)
		and gs1.used_twists() >= gs1.day_won_at + 3, "continue_mode_no_limit",
		"chip=%s links=%d gewachsen=%d->%d drehungen=%d" % [str(chip_build), gs1.twists_left(), g0, g1, gs1.used_twists()])
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
		and dui.tc_count_row.visible and dui.tc_build.visible and (dui.week_cells[0] as DayUI.WeekDot).state == "streak"
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
	# die Hütte ist satt (neben anderen Tieren). Dann die ganze Lösung: geschafft → Weiterbauen mit der Extra-Aufgabe
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
	var build_btn: Button = dui.wc_next if dui.wc_next.text == str(Days.TEXT["build"]) else (dui.wc_alt if dui.wc_alt.text == str(Days.TEXT["build"]) else null)
	if wc4 and build_btn != null:
		await _tap(build_btn)
		await _wait(1.2)
	elif wc4:
		ui._close_modal(true)
		Game.continue_build()
		await _wait(1.2)
	if wc4:
		if dui.ask_card.visible:
			await _tap(dui.ask_no)
			await _wait(0.8)
	await _wait(0.6)
	await _shot(dir, "00k3_tag4_extra")
	var extra_txt := dui.chip_caps.text
	_check(won4 and wc4 and Game.in_day() and Game.day_no == 4 and Game.state.day_free_build and Game.state.twists_left() == -1 and extra_txt == "Extra: 4 Hütten satt"
		and dui.chip.visible, "extra_task", "gewonnen=%s knopf=%s chip=%s" % [str(won4), dui.wc_next.text, extra_txt])
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
		and dui.wc_next.text == str(Days.TEXT["build"]) and dui.wc_alt.text == str(Days.TEXT["free"]), "world_complete",
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


## Erster Start: Der Ersteller kommt vor Tag 1. Vier Schritte mit echter Eingabe (Würfeln, Katzengott, Farbe,
## Krone, Ton „Frech“), „Fertig – los geht's!“ speichert [charakter] und öffnet die Ziel-Karte von Tag 1.
func _creator_tour(dir: String) -> void:
	var dui := ui.day_ui
	var cc := dui.creator
	Game.set_character({})
	ui.refresh_speakers()
	Game.start_day(1)                    # wie beim ersten Start: Tag 1 läuft schon, die Ziel-Karte wartet
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
		and Game.in_day() and Game.day_no == 1 and dui.gc_intro.text.contains(Voice.char_name()), "creator_finish",
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
	await _wait(1.6)
	world.debug_view(Vector3(0.12, 1.0, 0.16), Vector3(0, 0, -1), 0.62)
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
	world.debug_begin_twist(probe.id, Vector2(1, 0.15), 0.5)
	await _wait(0.8)
	await _shot(dir, "32c_keine_luecken_drehung")
	world.debug_end_twist()
	for i in 60:
		await _wait(0.05)
		if not world.animating and not Game.busy:
			break
	world.debug_bright_bg(false)
	await _wait(0.6)
	world.debug_view(Vector3(0.12, 1.0, 0.16), Vector3(0, 0, -1), 0.62)
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
