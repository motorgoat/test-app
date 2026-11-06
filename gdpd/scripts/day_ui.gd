class_name DayUI
extends Node
## „Die Schöpfung in 7 Tagen“ auf dem Bildschirm (docs/GDPD_7_TAGE.md, Abschnitt 4).
##   Übersicht (7 Kacheln + Freies Spiel) · Ziel-Karte („Los!“) · Ziel-Chip oben (Fortschritt, Drehungen übrig) ·
##   Hinweis-Zeile in der Spur (nicht blockierend) · Aufdecken der neuen Sache · Sieg- und Fehlversuch-Karte.
## Baut auf den Bausteinen von GameUI auf (Etiketten, Kacheln, Knöpfe, Bewegung, Dialoge). Kennt keine Regeln:
## alles kommt aus Game (day_info, day_status) und Days (Texte, Tabelle).


## Ring um die Zahl der übrigen Drehungen: voll am Anfang, leert sich; die letzten 3 färben ihn orange.
class TwistRing extends Control:
	var left := 0
	var limit := 1
	var warn := false

	func _init() -> void:
		custom_minimum_size = Vector2(46, 46)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	func set_value(l: int, lim: int, w: bool) -> void:
		left = l
		limit = maxi(1, lim)
		warn = w
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 3.0
		draw_arc(c, r, 0.0, TAU, 48, Color(Style.INK, 0.09), 5.0, true)
		var k := clampf(float(left) / float(limit), 0.0, 1.0)
		if k > 0.0:
			var col := Style.SUN if warn else Style.LEAF
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * k, 48, col, 5.0, true)
		var f := Style.black()
		var fs := 19
		var txt := str(left)
		var ts := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var asc := f.get_ascent(fs)
		var desc := f.get_descent(fs)
		draw_string(f, Vector2(c.x - ts.x * 0.5, c.y + (asc - desc) * 0.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Style.SUN_DEEP if warn else Style.INK)


## Ein Kreis der Wochenreihe (1.6): Serientag = goldene Flamme, Schutztag = blauer Schild, verpasst = leerer Ring,
## heute (noch nicht geschafft) = Ring, der sanft pulsiert, Zukunft = blasser Punkt.
class WeekDot extends Control:
	var state := "none"
	var _t := 0.0

	func _init(px: float = 40.0) -> void:
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	func set_state(s: String) -> void:
		state = s
		set_process(s == "today")
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		match state:
			"streak":
				draw_circle(c, r, Style.SUN_TINT)
				_icon("streak", r * 1.25)
			"shield":
				draw_circle(c, r, Style.WATER_TINT)
				_icon("shield", r * 1.2)
			"missed":
				draw_arc(c, r - 1.5, 0.0, TAU, 40, Color(Style.INK, 0.16), 3.0, true)
			"today":
				var k := 0.5 + 0.5 * sin(_t * TAU / 1.6)
				draw_circle(c, r, Color(Style.SUN_TINT, 0.5 + 0.5 * k))
				draw_arc(c, r - 1.5, 0.0, TAU, 40, Style.SUN, 3.0, true)
			"future":
				draw_circle(c, 4.0, Color(Style.INK, 0.14))
			_:
				draw_circle(c, 4.0, Color(Style.INK, 0.07))

	func _icon(icon_name: String, px: float) -> void:
		var tex := Style.icon(icon_name)
		if tex == null:
			return
		var sz := Vector2(px, px)
		draw_texture_rect(tex, Rect2(size * 0.5 - sz * 0.5, sz), false)


## Was an jedem Tag neu dazukommt und im Spiel an seinen Platz fliegt: [Symbol, Titel, Ziel].
const REVEAL = {2: ["rain", "Neu: Regen", "rain"], 3: ["animals", "Neu: Leben", "chip"], 4: ["hut", "Neu: Menschen", "chip"],
	5: ["field", "Neu: Du entscheidest!", "chip"], 6: ["church", "Neu: Glaube", "chip"], 7: ["strike", "Neu: Gewitter", "strike"]}
## Wo die erste Hinweis-Zeile eines Tages hinzeigt ("" = in der Spur unter der Kopfzeile).
const COACH_AT = {2: "rain"}
const TILE_W := 129.0
const TILE_H := 150.0
const WEEK_LETTERS = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

var ui: GameUI

# --- Übersicht (Startseite: Charakter, Serie, Heute-Karte, Woche, die 7 Tage) ---
var overview: Control
var ov_tiles: Array = []          # je Tag: {"btn", "icon", "stars": [TextureRect×3], "lock", "morgen", "title", "caps"}
var ov_stars: Label
var ov_free: Button
var ov_banner: PanelContainer
var ov_banner_label: Label
var ov_box: VBoxContainer
var ov_scroll: ScrollContainer
var ov_char: Control              # Kopfbild des Charakters (88 px)
var ov_name: Label
var ov_bubble: PanelContainer
var ov_say: Label                 # was der Charakter gerade sagt
var ov_streak_chip: PanelContainer
var ov_streak_icon: TextureRect
var ov_streak_num: Label
var ov_shield_chip: PanelContainer
var ov_shield_num: Label
var ov_coin_num: Label
var today_card: PanelContainer
var tc_tile: PanelContainer
var tc_caps: Label
var tc_title: Label
var tc_line: Label
var tc_count_row: HBoxContainer
var tc_count: Label
var tc_go: Button
var tc_build: Button
var tc_again: Button
var week_cells: Array = []        # WeekDot × 7
var week_letters: Array = []
var week_line: Label
var ov_debug: Button
var shield_card: PanelContainer
var sc_text: Label
var sc_buy: Button
var sc_why: Label
var _today: Dictionary = {}       # Game.today_info() beim letzten Füllen
var _ov_tick := 0.0
var _ov_said_key := ""            # was der Charakter in der Übersicht zuletzt gesagt hat (Zustand)

# --- Ersteller des eigenen Charakters (3.7) ---
var creator: CharacterCreator
var _creator_then_day := false    # nach „Fertig“ gleich Tag 1 (erster Start)
var _creator_edit := false
var _creator_shown := false       # offen (auch während des Ausblendens schon false)
var _char_banner := false         # nach dem Ersteller eines alten Spielstands: Banner in der Übersicht (einmal)

# --- Erinnern? (5.7) ---
var ask_card: PanelContainer
var ask_speaker: Control
var ask_text: Label
var ask_yes: Button
var ask_no: Button
var _ask_then: Callable = Callable()
var debug_ask_on_pc := false      # Tour: die Frage auch ohne Plugin zeigen (es gibt dann nichts zu erlauben)

# --- Karten ---
var goal_card: PanelContainer
var gc_caps: Label
var gc_intro: Label
var gc_speaker: Control
var gc_goal_tile: PanelContainer
var gc_goal: Label
var gc_limit: Label
var gc_rule: PanelContainer
var gc_rule_label: Label
var gc_rule_icon: TextureRect
var gc_new: PanelContainer
var gc_new_tile: PanelContainer
var gc_new_title: Label
var gc_new_text: Label
var gc_star_label: Label
var gc_mercy: Label
var gc_go: Button

var win_card: PanelContainer
var wc_title: Label
var wc_stars: Array = []
var wc_used: Label
var wc_row: HBoxContainer
var wc_days: HBoxContainer
var wc_total: Label
var wc_free_line: Label
var wc_char: CharacterView
var wc_say: Label                 # was der Charakter zum Sieg (und zur Serie) sagt
var wc_streak: PanelContainer     # Serien-Streifen: Flamme, Zahl, Woche
var wc_flame: TextureRect
var wc_streak_num: Label
var wc_streak_text: Label
var wc_week: Array = []           # WeekDot × 7 (klein)
var wc_big: Label                 # „7 Tage in Folge!“ (Meilenstein)
var wc_next_line: Label           # „Morgen geht's weiter: Tag 2 · Pflanzen“
var wc_next: Button               # Hauptknopf (Weiterbauen / Weiter zu Tag n)
var wc_alt: Button                # Zweitknopf (Nochmal · mehr Sterne / Weiterbauen / Freies Spiel)
var wc_home: Button               # „Zur Übersicht“
var _win_info: Dictionary = {}

var fail_card: PanelContainer
var fc_char: Control
var fc_tile: PanelContainer       # Abzeichen am Kopfbild (Krieg, Feuer, Drehungen)
var fc_caps: Label
var fc_title: Label
var fc_body: Label
var fc_progress_tile: PanelContainer
var fc_progress: Label
var fc_mercy: Label
var fc_again: Button

var free_card: PanelContainer
var free_continue: Button

# --- Kopfzeile ---
var chip: PanelContainer
var _chip_sb: StyleBoxFlat
var chip_tile: PanelContainer
var chip_caps: Label
var chip_num: Label
var ring: TwistRing
var ring_caps: Label
var _chip_sep: ColorRect
var grow_box: VBoxContainer       # Weiterbauen: gewachsene Felder seit dem Sieg (statt des Rings)
var grow_num: Label
var _build_said := false          # „Du kannst hier noch weiterbauen …“ (einmal je Sitzung)
var _praise_at := -100.0          # wann der Charakter zuletzt gelobt hat (höchstens alle paar Sekunden)
var _merges := 0
var rule_tag: PanelContainer

# --- Hinweis-Zeile (Spur) ---
var lane: PanelContainer
var lane_speaker: Control         # der Charakter spricht die Hinweis-Zeile
var lane_tile: PanelContainer     # Themen-Abzeichen am Kopfbild
var lane_caps: Label
var lane_label: Label
var _lane_until := INF

var fx_layer: Control

# --- Zustand ---
var _info: Dictionary = {}          # day_info() beim Start des Versuchs
var _hold: Dictionary = {}          # Dinge, die erst nach „Los!“ an ihren Platz fliegen ("rain", "scale", "strike", "hint", "dock")
var _playing := false               # „Los!“ getippt, der Tag läuft
var _tut := 0                       # Tag 1 (Tutorial-Brett): 0 aus, 1 „Schau zu!“ (die Hand spielt den ersten Zug), 2 „Jetzt du!“, 3 fertig
var _tut_at := 0.0
var _demo_at := INF                 # dann startet die eine Vorführung (INF = keine mehr)
var _demo_done := false             # die Vorführung lief (oder ging nicht): nie wieder in diesem Versuch
var _demo_started := 0.0
var _lock_at := 0.0                 # seit dann ist die Eingabe für die Vorführung gesperrt
var _tut_misses := 0
var _last_progress := -1
var _last_left := -1
var _warned_fire := false
var _first_card_done := false
var _end_gen := 0
var _goal_field := -1               # Feld, an dem im letzten Zug etwas für das Ziel gewachsen ist
var _time := 0.0


func build(owner_ui: GameUI) -> void:
	ui = owner_ui
	name = "Days"
	_build_chip()
	_build_lane()
	_build_overview()
	_build_goal_card()
	_build_win_card()
	_build_fail_card()
	_build_free_card()
	_build_shield_card()
	_build_ask_card()
	fx_layer = Control.new()
	fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.root.add_child(fx_layer)
	creator = CharacterCreator.new()
	creator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	creator.visible = false
	creator.finished.connect(_on_creator_finished)
	creator.cancelled.connect(_on_creator_cancelled)
	ui.root.add_child(creator)
	ui.root.move_child(ui.tip_card, -1)        # Erklärungen bleiben ganz oben
	Game.daily_changed.connect(_on_daily_changed)
	Game.build_started.connect(_on_build_started)
	Game.day_started.connect(_on_day_started)
	Game.day_progress.connect(_on_day_progress)
	Game.day_won.connect(_on_day_won)
	Game.day_lost.connect(_on_day_lost)
	Game.new_game_started.connect(_on_new_game)
	Game.move_done.connect(_on_move_done)
	Game.choice_made.connect(_on_choice_made)
	Game.choice_needed.connect(_on_choice_needed)
	Game.round_resolved.connect(_on_round)


## Beim Start der App: Noch kein eigener Charakter → erst der Ersteller (unter einer Minute), dann beim ersten Start
## gleich Tag 1 (Ziel-Karte), sonst die Übersicht. Mit Charakter: erster Start → Tag 1, sonst die Übersicht.
func startup() -> void:
	if Game.needs_creator():
		open_creator(false, Game.first_launch or (Game.in_day() and Game.day_no == 1 and Game.stars_of(1) == 0))
		Game.first_launch = false
		return
	if Game.in_day() and Game.first_launch:
		Game.first_launch = false
		_on_day_started.call_deferred(Game.day_info())
		return
	show_overview(false)


# =============================================================================
# Der eigene Charakter: Ersteller beim ersten Start, „Dein Charakter“ im Menü
# =============================================================================

## Den Ersteller öffnen. edit: aus dem Menü (Titel „Dein Charakter“, „Speichern“, Schließen). then_day: nach „Fertig“
## gleich Tag 1 (erster Start), sonst die Übersicht.
func open_creator(edit: bool = false, then_day: bool = false) -> void:
	ui._close_modal(true)
	ui.debug_close_all()
	_hide_lane(true)
	_creator_edit = edit
	_creator_then_day = then_day and not edit
	creator.open(Game.character if edit else {}, edit)
	creator.modulate.a = 1.0
	creator.visible = true
	_creator_shown = true
	ui.top.visible = false
	ui.dock.visible = false
	ui._appear(creator, Vector2(0, 0), Style.DUR_IN, 1.0)


func creator_open() -> bool:
	return creator != null and creator.visible and _creator_shown


func _on_creator_finished(look: Dictionary) -> void:
	Game.set_character(look)
	ui.refresh_speakers()
	_render_portraits.call_deferred()
	# Kurz zeigen, wie er sich freut (dreht sich), dann weiter
	get_tree().create_timer(0.7).timeout.connect(_after_creator)


func _after_creator() -> void:
	_creator_shown = false
	ui._disappear(creator, Vector2.ZERO, Style.DUR_OUT)
	if _creator_edit:
		_creator_edit = false
		if overview.visible:
			_fill_overview()
		else:
			ui.top.visible = true
			ui.refresh()
		return
	if _creator_then_day and Game.in_day():
		_creator_then_day = false
		ui.top.visible = true
		_on_day_started(Game.day_info())
		return
	_char_banner = Game.stars_total() > 0
	show_overview()


func _on_creator_cancelled() -> void:
	_creator_shown = false
	ui._disappear(creator, Vector2.ZERO, Style.DUR_OUT)
	_creator_edit = false
	if not overview.visible:
		ui.top.visible = true
		ui.refresh()


## Die Gesichter für die Benachrichtigungen (5.6): 256 px, je Stufe ein Ausdruck, nach user://erinnerung/.
func _render_portraits() -> void:
	if Game.character.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(Notifier.ICON_DIR)
	var faces := {"A": "happy", "B": "worried", "C": "neutral", "F": "sleepy"}
	for cat in faces:
		var img: Image = await CharacterView.render_image(ui, Game.character, str(faces[cat]), 256, true, Style.SUN_TINT, 0.82)
		if img == null:
			return            # ohne Grafik (headless): keine Bilder, die Erinnerung kommt dann ohne Gesicht
		img.save_png(Notifier.ICON_DIR + str(Notifier.ICONS[cat]))


# =============================================================================
# Aufbau
# =============================================================================

func _build_chip() -> void:
	# Ziel-Chip: mittig in der ersten Zeile der Kopfzeile (statt der Glaubenszahl)
	var row1: HBoxContainer = ui.score_box.get_parent()
	chip = PanelContainer.new()
	_chip_sb = Style.lift(Style.hairline(Style.box(Style.GLASS, 30, 12, 8)), 1)
	_chip_sb.content_margin_right = 14
	chip.add_theme_stylebox_override("panel", _chip_sb)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row1.add_child(chip)
	row1.move_child(chip, ui.score_box.get_index() + 1)
	var h := ui._hbox(12)
	chip.add_child(h)
	chip_tile = ui._tile("meadow", 52, Style.STAGE_TINT[1], 0.32)
	h.add_child(chip_tile)
	var v := ui._vbox(-6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.custom_minimum_size = Vector2(96, 0)
	h.add_child(v)
	chip_caps = ui._caps("Wiesen")
	v.add_child(chip_caps)
	chip_num = ui._label("0/8", 34, Style.INK, Style.W_BLACK)
	v.add_child(chip_num)
	var sep := ColorRect.new()
	sep.color = Style.HAIRLINE
	sep.custom_minimum_size = Vector2(1, 44)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(sep)
	_chip_sep = sep
	var rv := ui._vbox(0)
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(rv)
	ring = TwistRing.new()
	rv.add_child(ring)
	ring_caps = ui._caps("Drehungen")
	ring_caps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(ring_caps)
	# Weiterbauen: statt des Rings, wie viel seit dem Sieg gewachsen ist (Wiese + Zahl)
	grow_box = ui._vbox(-2)
	grow_box.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(grow_box)
	var gh := ui._hbox(4)
	gh.alignment = BoxContainer.ALIGNMENT_CENTER
	grow_box.add_child(gh)
	gh.add_child(ui._icon("meadow", 26))
	grow_num = ui._label("0", 22, Style.LEAF_DEEP, Style.W_BLACK)
	grow_num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gh.add_child(grow_num)
	var gc := ui._caps("gewachsen")
	gc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grow_box.add_child(gc)
	grow_box.visible = false
	ui._explain_only(chip, "day_goal")
	chip.visible = false
	# „Kein Krieg!“ (Tag 6): mittig unter dem Ziel-Chip (in der Zeile der Weltwaage, die an Tag 6 nicht zu sehen ist)
	rule_tag = PanelContainer.new()
	rule_tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule_tag.add_theme_stylebox_override("panel", Style.lift(Style.box(Style.FIRE_TINT, 20, 14, 6), 1))
	var rh := ui._hbox(8)
	rule_tag.add_child(rh)
	rh.add_child(ui._icon("swords", 24))
	var rl := ui._label("Kein Krieg!", 16, Style.FIRE_DEEP, Style.W_BOLD)
	rl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rh.add_child(rl)
	ui._explain_only(rule_tag, "day_rule")
	rule_tag.visible = false
	ui.row3.add_child(rule_tag)
	ui.row3.move_child(rule_tag, 0)


func _build_lane() -> void:
	lane = PanelContainer.new()
	lane.add_theme_stylebox_override("panel", Style.card(Style.R_CARD, 2, 18, 14))
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := ui._hbox(14)
	lane.add_child(h)
	lane_speaker = ui._speaker(56, 26)
	h.add_child(lane_speaker)
	lane_tile = lane_speaker.get_meta("badge")
	var v := ui._vbox(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	lane_caps = ui._caps("Du bist dran", Style.LEAF_DEEP)
	v.add_child(lane_caps)
	lane_label = ui._label("", 19, Style.INK, Style.W_BOLD)
	lane_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lane_label.custom_minimum_size = Vector2(Style.CONTENT_W - 36 - 56 - 14, 0)
	v.add_child(lane_label)
	lane.visible = false
	ui.root.add_child(lane)
	ui.root.move_child(lane, ui.toast.get_index())


func _build_overview() -> void:
	overview = Control.new()
	overview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overview.mouse_filter = Control.MOUSE_FILTER_STOP
	overview.visible = false
	var bg := ColorRect.new()
	bg.color = Color("#F4EEE6")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overview.add_child(bg)
	# Oben: Menü links; rechts Serie (Flamme), Serienschutz, Münzen
	var topbar := ui._hbox(8)
	topbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	topbar.offset_left = Style.MARGIN
	topbar.offset_right = -Style.MARGIN
	topbar.offset_top = ui._insets.x + Style.TOP_GAP
	overview.add_child(topbar)
	topbar.add_child(ui._icon_button("menu", ui._open_menu, 52, false, "menu"))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	topbar.add_child(sp)
	var stc := _top_chip("streak", "0")
	ov_streak_chip = stc[0]
	ov_streak_icon = stc[1]
	ov_streak_num = stc[2]
	topbar.add_child(ov_streak_chip)
	ui._explain_only(ov_streak_chip, "day_streak")
	var shc := _top_chip("shield", "0")
	ov_shield_chip = shc[0]
	ov_shield_num = shc[2]
	topbar.add_child(ov_shield_chip)
	ov_shield_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	ov_shield_chip.gui_input.connect(_on_shield_chip_input)
	var coc := _top_chip("coin", "0")
	ov_coin_num = coc[2]
	topbar.add_child(coc[0])
	ui._explain_only(coc[0], "day_coins")
	# Darunter alles in einer Spalte, die bei kleinen Bildschirmen scrollt
	ov_scroll = ScrollContainer.new()
	ov_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov_scroll.offset_top = ui._insets.x + Style.TOP_GAP + 64
	ov_scroll.offset_bottom = -ui._insets.y
	ov_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ov_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	overview.add_child(ov_scroll)
	var col := ui._vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	ov_scroll.add_child(col)
	ov_box = ui._vbox(14)
	ov_box.custom_minimum_size = Vector2(Style.CONTENT_W, 0)
	ov_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ov_box.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(ov_box)
	ov_banner = PanelContainer.new()
	ov_banner.add_theme_stylebox_override("panel", Style.box(Style.SUN_TINT, 18, 14, 6))
	ov_banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ov_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov_banner_label = ui._caps(str(Days.TEXT["banner_new"]), Style.SUN_DEEP)
	ov_banner.add_child(ov_banner_label)
	ov_banner.visible = false
	ov_box.add_child(ov_banner)
	# 1. Der Charakter und was er sagt
	var crow := ui._hbox(14)
	ov_box.add_child(crow)
	var cv := ui._vbox(2)
	cv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crow.add_child(cv)
	ov_char = ui._speaker(92, 0, Color("#FFF4DF"))
	cv.add_child(ov_char)
	ov_name = ui._caps("", Style.INK_2)
	ov_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(ov_name)
	ov_bubble = PanelContainer.new()
	var bsb := Style.card(22, 2, 18, 14)
	bsb.corner_radius_top_left = 6
	ov_bubble.add_theme_stylebox_override("panel", bsb)
	ov_bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ov_bubble.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ov_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crow.add_child(ov_bubble)
	ov_say = ui._label("", 18, Style.INK, Style.W_LABEL)
	ov_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ov_say.custom_minimum_size = Vector2(Style.CONTENT_W - 92 - 14 - 36, 0)
	ov_bubble.add_child(ov_say)
	# 2. Heute-Karte (der Hauptknopf der Seite)
	_build_today_card()
	# 3. Diese Woche
	_build_week()
	# 4. Die 7 Tage (4 + 3) und „Freies Spiel“
	var head := ui._hbox(8)
	ov_box.add_child(head)
	var hcaps := ui._caps(str(Days.TEXT["title"]), Style.INK_3)
	hcaps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hcaps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hcaps)
	var sh := ui._hbox(4)
	head.add_child(sh)
	sh.add_child(ui._icon("star", 20))
	ov_stars = ui._label("0/21", 16, Style.INK, Style.W_BLACK)
	ov_stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sh.add_child(ov_stars)
	ui._explain_only(head, "day_stars")
	var grid := ui._vbox(12)
	ov_box.add_child(grid)
	var r1 := ui._hbox(12)
	r1.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_child(r1)
	var r2 := ui._hbox(12)
	r2.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_child(r2)
	for n in range(1, Days.count() + 1):
		var row: HBoxContainer = r1 if n <= 4 else r2
		row.add_child(_day_tile(n))
	ov_free = ui._button(str(Days.TEXT["free"]), "secondary", "trophy", 56)
	ui._tap_or_explain(ov_free, _on_free_pressed, "day_free", false)
	ov_box.add_child(ov_free)
	# Nur in der Test-Version: einen Tag weiter, ohne zu warten (7)
	ov_debug = ui._button(str(Days.TEXT["test_next_day"]), "sun_soft", "moon", 46)
	ov_debug.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ov_debug.pressed.connect(_on_debug_next_day)
	ov_debug.visible = OS.is_debug_build()
	ov_box.add_child(ov_debug)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 24)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov_box.add_child(pad)
	ui.root.add_child(overview)
	ui.root.move_child(overview, ui.modal_bg.get_index())
	ui.root.move_child(ui.toast, ui.modal_bg.get_index())      # Meldungen auch über der Übersicht


## Chip oben in der Übersicht: [Pille, Symbol, Zahl].
func _top_chip(icon_name: String, text: String) -> Array:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", ui._chip_style(Style.GLASS, 24))
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := ui._hbox(6)
	c.add_child(h)
	var ic := ui._icon(icon_name, 26)
	h.add_child(ic)
	var l := ui._label(text, 18, Style.INK, Style.W_BLACK)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return [c, ic, l]


func _build_today_card() -> void:
	today_card = PanelContainer.new()
	var sb := Style.card(Style.R_CARD, 2, 20, 18)
	sb.border_color = Style.SUN
	sb.set_border_width_all(0)
	today_card.add_theme_stylebox_override("panel", sb)
	today_card.mouse_filter = Control.MOUSE_FILTER_PASS
	ov_box.add_child(today_card)
	var v := ui._vbox(12)
	today_card.add_child(v)
	var h := ui._hbox(16)
	v.add_child(h)
	tc_tile = ui._tile("meadow", 72, Style.STAGE_TINT[1], 0.32)
	h.add_child(tc_tile)
	var tv := ui._vbox(0)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tc_caps = ui._caps(str(Days.TEXT["today_new"]), Style.SUN_DEEP)
	tv.add_child(tc_caps)
	tc_title = ui._label("", 24, Style.INK, Style.W_BLACK)
	tc_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tc_title.custom_minimum_size = Vector2(Style.CONTENT_W - 40 - 72 - 16, 0)
	tv.add_child(tc_title)
	tc_line = ui._label("", 16, Style.INK_2, Style.W_LABEL)
	tc_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tc_line.custom_minimum_size = Vector2(Style.CONTENT_W - 40 - 72 - 16, 0)
	tv.add_child(tc_line)
	tc_count_row = ui._hbox(8)
	v.add_child(tc_count_row)
	tc_count_row.add_child(ui._icon("moon", 22))
	tc_count = ui._label("", 15, Style.INK_3, Style.W_LABEL)
	tc_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tc_count_row.add_child(tc_count)
	tc_go = ui._button(str(Days.TEXT["go"]), "primary", "play", 60)
	tc_go.add_theme_font_size_override("font_size", 20)
	tc_go.pressed.connect(_on_today_go)
	v.add_child(tc_go)
	var row := ui._hbox(10)
	v.add_child(row)
	tc_build = ui._button(str(Days.TEXT["build"]), "accent", "meadow", 54)
	tc_build.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tc_build.pressed.connect(_on_today_build)
	row.add_child(tc_build)
	tc_again = ui._button(str(Days.TEXT["again_stars"]), "secondary", "star", 54)
	tc_again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tc_again.pressed.connect(_on_today_again)
	row.add_child(tc_again)


func _build_week() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, Style.R_CARD, 18, 14))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	ov_box.add_child(p)
	ui._explain_only(p, "day_week")
	var v := ui._vbox(8)
	p.add_child(v)
	var head := ui._hbox(8)
	v.add_child(head)
	var c := ui._caps(str(Days.TEXT["week"]))
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(c)
	week_line = ui._label("", 14, Style.INK_2, Style.W_LABEL)
	head.add_child(week_line)
	var row := ui._hbox(0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for i in 7:
		var cell := ui._vbox(4)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cell)
		var dot := WeekDot.new(40.0)
		cell.add_child(dot)
		week_cells.append(dot)
		var l := ui._caps(str(WEEK_LETTERS[i]))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(l)
		week_letters.append(l)


func _day_tile(n: int) -> Button:
	var cfg := Days.config(n)
	var b := Button.new()
	b.custom_minimum_size = Vector2(TILE_W, TILE_H)
	b.focus_mode = Control.FOCUS_NONE
	var nsb := Style.lift(Style.box(Style.SURFACE, 24, 8, 8), 1)
	Style.skin(b, nsb, Style.box(Style.SURFACE_3, 24, 8, 8), Style.INK)
	b.set_meta("sb", nsb)
	ui._tap_or_explain(b, _on_tile.bind(n), "day_tile_%d" % n)
	var v := ui._vbox(4)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 10
	v.offset_bottom = -10
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(v)
	var caps := ui._caps(str(Days.TEXT["day"]) % n)
	caps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(caps)
	var icon_name := str(cfg.get("icon", "meadow"))
	var tl := ui._tile(icon_name, 54, ui._tint_for_icon(icon_name), 0.32)
	tl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(tl)
	var title := ui._label(str(cfg.get("title", "")), 15, Style.INK, Style.W_BOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sr := ui._hbox(2)
	sr.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(sr)
	var stars: Array = []
	for i in 3:
		var s := ui._icon("star_empty", 18)
		sr.add_child(s)
		stars.append(s)
	var lock := ui._icon("lock", 20)
	lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sr.add_child(lock)
	var morgen := ui._caps(str(Days.TEXT["tomorrow"]), Style.MONSOON_DEEP)
	morgen.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sr.add_child(morgen)
	ov_tiles.append({"btn": b, "tile": tl, "stars": stars, "lock": lock, "morgen": morgen, "title": title, "caps": caps,
		"icon": icon_name})
	return b


## Karte mit gleichem Aussehen wie die Dialoge von GameUI, aber ohne Titelzeile.
func _card() -> Array:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", Style.card(Style.R_MODAL, 3, 28, 28))
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.visible = false
	var v := ui._vbox(16)
	v.custom_minimum_size = Vector2(Style.CONTENT_W - 56, 0)
	c.add_child(v)
	ui.root.add_child(c)
	return [c, v]


func _center(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(Style.CONTENT_W - 56, 0)
	return l


func _build_goal_card() -> void:
	var cv := _card()
	goal_card = cv[0]
	var v: VBoxContainer = cv[1]
	gc_caps = _center(ui._caps("Tag 1 · Land", Style.SUN_DEEP))
	gc_caps.add_theme_font_size_override("font_size", 14)
	v.add_child(gc_caps)
	# Der Charakter stellt den Tag vor (seine Worte, sein Gesicht)
	var ih := ui._hbox(14)
	v.add_child(ih)
	gc_speaker = ui._speaker(64, 0)
	ih.add_child(gc_speaker)
	var ib := PanelContainer.new()
	var ibs := Style.box(Style.SURFACE_2, 20, 16, 12)
	ibs.corner_radius_top_left = 6
	ib.add_theme_stylebox_override("panel", ibs)
	ib.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ib.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ih.add_child(ib)
	gc_intro = ui._label("", 17, Style.INK, Style.W_LABEL)
	gc_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gc_intro.custom_minimum_size = Vector2(Style.CONTENT_W - 56 - 64 - 14 - 32, 0)
	ib.add_child(gc_intro)
	# Das Ziel: groß, mit Bild
	var gp := PanelContainer.new()
	gp.add_theme_stylebox_override("panel", Style.box(Style.SURFACE_2, 24, 18, 16))
	gp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gp)
	var gh := ui._hbox(16)
	gp.add_child(gh)
	gc_goal_tile = ui._tile("meadow", 76, Style.STAGE_TINT[1], 0.32)
	gh.add_child(gc_goal_tile)
	var gv := ui._vbox(2)
	gv.alignment = BoxContainer.ALIGNMENT_CENTER
	gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gh.add_child(gv)
	gv.add_child(ui._caps("Deine Aufgabe"))
	gc_goal = ui._label("", 25, Style.INK, Style.W_BLACK)
	gc_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gc_goal.custom_minimum_size = Vector2(Style.CONTENT_W - 56 - 36 - 76 - 16, 0)
	gv.add_child(gc_goal)
	gc_limit = ui._label("", 17, Style.INK_2, Style.W_LABEL)
	gv.add_child(gc_limit)
	# Regel (Tag 1: „Nur gerade Reihen zählen · Wasser wächst nie“, Tag 6: „Kein Krieg!“)
	gc_rule = PanelContainer.new()
	gc_rule.add_theme_stylebox_override("panel", Style.box(Style.FIRE_TINT, 18, 14, 6))
	gc_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	gc_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rh := ui._hbox(8)
	gc_rule.add_child(rh)
	gc_rule_icon = ui._icon("swords", 22)
	rh.add_child(gc_rule_icon)
	gc_rule_label = ui._label("Kein Krieg!", 16, Style.FIRE_DEEP, Style.W_BOLD)
	gc_rule_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rh.add_child(gc_rule_label)
	v.add_child(gc_rule)
	# Neu heute
	gc_new = PanelContainer.new()
	gc_new.add_theme_stylebox_override("panel", Style.box(Style.SUN_TINT, 24, 16, 14))
	gc_new.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gc_new)
	var nh := ui._hbox(14)
	gc_new.add_child(nh)
	gc_new_tile = ui._tile("rain", 56, Style.SURFACE, 0.32)
	nh.add_child(gc_new_tile)
	var nv := ui._vbox(0)
	nv.alignment = BoxContainer.ALIGNMENT_CENTER
	nh.add_child(nv)
	gc_new_title = ui._label("Neu: Regen", 18, Style.SUN_DEEP, Style.W_BLACK)
	nv.add_child(gc_new_title)
	gc_new_text = ui._label("", 15, Style.INK_2, Style.W_BODY)
	gc_new_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gc_new_text.custom_minimum_size = Vector2(Style.CONTENT_W - 56 - 32 - 56 - 14, 0)
	nv.add_child(gc_new_text)
	# Sterne
	var sr := ui._hbox(4)
	sr.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(sr)
	for i in 3:
		sr.add_child(ui._icon("star", 22))
	gc_star_label = ui._label("", 16, Style.INK_2, Style.W_LABEL)
	gc_star_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sr.add_child(gc_star_label)
	gc_mercy = _center(ui._label("", 16, Style.LEAF_DEEP, Style.W_BOLD))
	v.add_child(gc_mercy)
	gc_go = ui._button(str(Days.TEXT["go"]), "primary", "", 62)
	gc_go.add_theme_font_size_override("font_size", 21)
	gc_go.pressed.connect(_on_go)
	v.add_child(gc_go)


func _build_win_card() -> void:
	var cv := _card()
	win_card = cv[0]
	var v: VBoxContainer = cv[1]
	v.add_theme_constant_override("separation", 12)
	wc_title = _center(ui._label("", 30, Style.INK, Style.W_BLACK))
	v.add_child(wc_title)
	wc_row = ui._hbox(10)
	wc_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(wc_row)
	for i in 3:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(70, 70)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wc_row.add_child(holder)
		var empty := TextureRect.new()
		empty.texture = Style.icon("star_empty")
		empty.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		empty.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(empty)
		var full := TextureRect.new()
		full.texture = Style.icon("star")
		full.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		full.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		full.mouse_filter = Control.MOUSE_FILTER_IGNORE
		full.visible = false
		holder.add_child(full)
		wc_stars.append(full)
	wc_used = _center(ui._label("", 16, Style.INK_2, Style.W_LABEL))
	v.add_child(wc_used)
	# Nach Tag 7: die sieben Tage und alle Sterne
	wc_days = ui._hbox(6)
	wc_days.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(wc_days)
	for n in range(1, Days.count() + 1):
		var ic := str(Days.config(n).get("icon", "meadow"))
		wc_days.add_child(ui._tile(ic, 52, ui._tint_for_icon(ic), 0.32))
	wc_total = _center(ui._label("", 18, Style.SUN_DEEP, Style.W_BLACK))
	v.add_child(wc_total)
	wc_free_line = _center(ui._label(str(Days.TEXT["free_open"]), 17, Style.INK_2, Style.W_BODY))
	v.add_child(wc_free_line)
	# Der Charakter freut sich und sagt etwas dazu
	var ch := ui._hbox(12)
	v.add_child(ch)
	wc_char = ui._figure(112)
	ch.add_child(wc_char)
	var bub := PanelContainer.new()
	var bs := Style.box(Style.SURFACE_2, 20, 16, 12)
	bs.corner_radius_bottom_left = 6
	bub.add_theme_stylebox_override("panel", bs)
	bub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.add_child(bub)
	wc_say = ui._label("", 17, Style.INK, Style.W_LABEL)
	wc_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wc_say.custom_minimum_size = Vector2(Style.CONTENT_W - 56 - 112 - 12 - 32, 0)
	bub.add_child(wc_say)
	# Die Serie: Flamme, Zahl (zählt hoch), Zeile, diese Woche
	wc_streak = PanelContainer.new()
	wc_streak.add_theme_stylebox_override("panel", Style.box(Style.SUN_TINT, 22, 16, 10))
	wc_streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(wc_streak)
	var sh := ui._hbox(12)
	wc_streak.add_child(sh)
	wc_flame = ui._icon("streak", 46)
	sh.add_child(wc_flame)
	wc_streak_num = ui._label("0", 34, Style.SUN_DEEP, Style.W_BLACK)
	wc_streak_num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wc_streak_num.custom_minimum_size = Vector2(30, 0)
	sh.add_child(wc_streak_num)
	var sv := ui._vbox(4)
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	sh.add_child(sv)
	wc_streak_text = ui._label("", 16, Style.SUN_DEEP, Style.W_BOLD)
	sv.add_child(wc_streak_text)
	var wr := ui._hbox(5)
	sv.add_child(wr)
	for i in 7:
		var d := WeekDot.new(28.0)
		wr.add_child(d)
		wc_week.append(d)
	wc_big = _center(ui._label("", 28, Style.SUN_DEEP, Style.W_BLACK))
	wc_big.visible = false
	v.add_child(wc_big)
	wc_next_line = _center(ui._label("", 16, Style.INK_2, Style.W_LABEL))
	v.add_child(wc_next_line)
	var acts := ui._vbox(8)
	v.add_child(acts)
	wc_next = ui._button("Weiter", "primary", "", 60)
	wc_next.add_theme_font_size_override("font_size", 20)
	wc_next.add_theme_constant_override("icon_max_width", 26)
	wc_next.pressed.connect(_on_win_next)
	acts.add_child(wc_next)
	var row := ui._hbox(10)
	acts.add_child(row)
	wc_alt = ui._button(str(Days.TEXT["again"]), "secondary", "", 54)
	wc_alt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wc_alt.pressed.connect(_on_win_alt)
	row.add_child(wc_alt)
	wc_home = ui._button(str(Days.TEXT["to_overview"]), "secondary", "", 54)
	wc_home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wc_home.pressed.connect(_on_win_home)
	row.add_child(wc_home)


func _build_fail_card() -> void:
	var cv := _card()
	fail_card = cv[0]
	var v: VBoxContainer = cv[1]
	fc_char = ui._speaker(96, 38)
	v.add_child(fc_char)
	fc_tile = fc_char.get_meta("badge")
	var tv := ui._vbox(2)
	v.add_child(tv)
	fc_caps = _center(ui._caps("", Style.INK_3))
	tv.add_child(fc_caps)
	fc_title = _center(ui._label("Fast geschafft!", 30, Style.INK, Style.W_BLACK))
	tv.add_child(fc_title)
	fc_body = _center(ui._label(str(Days.TEXT["lost_body"]), 17, Style.INK_2, Style.W_BODY))
	v.add_child(fc_body)
	var pp := PanelContainer.new()
	pp.add_theme_stylebox_override("panel", Style.box(Style.SURFACE_2, 22, 16, 8))
	pp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pp)
	var ph := ui._hbox(10)
	pp.add_child(ph)
	fc_progress_tile = ui._tile("hut", 40, Style.STAGE_TINT[6], 0.32)
	ph.add_child(fc_progress_tile)
	fc_progress = ui._label("", 19, Style.INK, Style.W_BLACK)
	fc_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(fc_progress)
	fc_mercy = _center(ui._label("", 16, Style.LEAF_DEEP, Style.W_BOLD))
	v.add_child(fc_mercy)
	var acts := ui._vbox(10)
	v.add_child(acts)
	fc_again = ui._button(str(Days.TEXT["again"]), "primary", "", 62)
	fc_again.add_theme_font_size_override("font_size", 20)
	fc_again.pressed.connect(_on_again)
	acts.add_child(fc_again)
	var home := ui._button(str(Days.TEXT["to_overview"]), "ghost", "", 50)
	home.pressed.connect(_on_home)
	acts.add_child(home)


func _build_free_card() -> void:
	free_card = ui._modal_card(str(Days.TEXT["free"]), true)
	var v: VBoxContainer = free_card.get_meta("body")
	var sub := _center(ui._label("Bau deine Welt weiter, bis sie vollendet ist.", 16, Style.INK_2, Style.W_BODY))
	v.add_child(sub)
	free_continue = ui._button("Weiterspielen", "primary", "", 56)
	free_continue.pressed.connect(_on_free_continue)
	v.add_child(free_continue)
	for m in GameUI.MODES:
		var md: Dictionary = m
		v.add_child(ui._mode_row(md, false))


## „Serienschutz“ (1.5): was er tut, wie viele man hat, kaufen für 5 Münzen.
func _build_shield_card() -> void:
	shield_card = ui._modal_card(str(Days.TEXT["shield"]), true)
	var v: VBoxContainer = shield_card.get_meta("body")
	var ic := ui._tile("shield", 84, Style.WATER_TINT, 0.5)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	sc_text = _center(ui._label("", 17, Style.INK_2, Style.W_BODY))
	v.add_child(sc_text)
	sc_buy = ui._button("", "water", "coin", 58)
	sc_buy.pressed.connect(_on_shield_buy)
	v.add_child(sc_buy)
	sc_why = _center(ui._label("", 15, Style.INK_3, Style.W_LABEL))
	v.add_child(sc_why)


## „Soll ich dich morgen erinnern?“ (5.7): der Charakter fragt, bevor Android fragt.
func _build_ask_card() -> void:
	var cv := _card()
	ask_card = cv[0]
	var v: VBoxContainer = cv[1]
	var h := ui._hbox(16)
	v.add_child(h)
	ask_speaker = ui._speaker(84, 30)
	h.add_child(ask_speaker)
	ask_text = ui._label("", 19, Style.INK, Style.W_BOLD)
	ask_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask_text.custom_minimum_size = Vector2(Style.CONTENT_W - 56 - 84 - 16, 0)
	ask_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ask_text)
	var foot := _center(ui._label("Höchstens eine am Tag. Nie zwischen 21:30 und 8:00 Uhr.", 14, Style.INK_3, Style.W_LABEL))
	v.add_child(foot)
	ask_yes = ui._button("Ja, gern", "primary", "check", 60)
	ask_yes.pressed.connect(_on_ask_answer.bind(true))
	v.add_child(ask_yes)
	ask_no = ui._button("Lieber nicht", "ghost", "", 50)
	ask_no.pressed.connect(_on_ask_answer.bind(false))
	v.add_child(ask_no)


# =============================================================================
# Übersicht
# =============================================================================

func is_open() -> bool:
	return overview != null and overview.visible


## Die Übersicht zeigen (Kopfzeile und Dock sind dann weg, der Würfel liegt dahinter).
func show_overview(animate: bool = true) -> void:
	ui._close_modal(true)
	ui.debug_close_all()
	_hide_lane(true)
	ui._close_choice()
	_end_gen += 1
	_playing = false
	_tut = 0
	_unlock_input()
	ui._hide_finger()
	_ov_said_key = ""
	_fill_overview()
	ui.top.visible = false
	ui.dock.visible = false
	overview.visible = true
	overview.modulate.a = 1.0
	ov_scroll.scroll_vertical = 0
	if animate:
		overview.modulate.a = 0.0
		var tw := ui._fx(overview, "v")
		tw.tween_property(overview, "modulate:a", 1.0, 0.25)
	var tiles: Array = [today_card]
	for t in ov_tiles:
		tiles.append((t as Dictionary)["btn"])
	ui._stagger_in(tiles, Vector2.ZERO, 0.9, 0.04)
	_pulse_current()
	Game.replan_reminders()       # jede Rückkehr zur Übersicht: der Plan passt zum Stand


func hide_overview() -> void:
	if not overview.visible:
		return
	overview.visible = false
	ui.top.visible = true
	ui._home_top()
	for t in ov_tiles:
		ui._pulse((t as Dictionary)["btn"], false)
	ui._pulse(tc_go, false)


func _fill_overview() -> void:
	_today = Game.today_info()
	var ti := _today
	var cur := Game.current_day()
	var all_done := Game.world_done
	var nn := Game.next_new_day()
	var tomorrow := Game.new_day_tomorrow()
	for i in ov_tiles.size():
		var n := i + 1
		var t: Dictionary = ov_tiles[i]
		var open := Game.day_unlocked(n)
		var morgen := not open and tomorrow and n == nn
		var st := Game.stars_of(n)
		var b: Button = t["btn"]
		var sb: StyleBoxFlat = b.get_meta("sb")
		var is_cur := open and n == cur and not (all_done and st == 3)
		sb.bg_color = Style.SURFACE if open else (Color("#EEF0FA") if morgen else Color(Style.SURFACE_2, 0.9))
		sb.border_color = Style.SUN
		sb.set_border_width_all(3 if is_cur and str(ti.get("state", "")) == "new" else 0)
		var stars: Array = t["stars"]
		for k in 3:
			var s: TextureRect = stars[k]
			s.visible = open
			s.texture = Style.icon("star" if k < st else "star_empty")
		var lock: TextureRect = t["lock"]
		lock.visible = not open
		lock.texture = Style.icon("moon" if morgen else "lock")
		(t["morgen"] as Control).visible = morgen
		var tl: PanelContainer = t["tile"]
		ui._set_tile(tl, str(t["icon"]), ui._tint_for_icon(str(t["icon"])) if open else (Color("#E1E6F6") if morgen else Style.SURFACE_3))
		(tl.get_child(0) as Control).modulate = Color(1, 1, 1, 1.0 if open else (0.6 if morgen else 0.35))
		(t["title"] as Label).add_theme_color_override("font_color", Style.INK if open else Style.INK_3)
		(t["caps"] as Label).add_theme_color_override("font_color", Style.SUN_DEEP if is_cur else (Style.MONSOON_DEEP if morgen else Style.INK_3))
		b.set_meta("current", is_cur and str(ti.get("state", "")) == "new")
		b.set_meta("morgen", morgen)
	ov_stars.text = "%d/%d" % [Game.stars_total(), Game.stars_max()]
	var free_ok := Game.free_play_unlocked()
	ov_free.text = str(Days.TEXT["free"]) if free_ok else "%s · %s" % [str(Days.TEXT["free"]), str(Days.TEXT["free_locked"])]
	ov_free.icon = Style.icon("trophy" if free_ok else "lock")
	ov_free.modulate.a = 1.0 if free_ok else 0.6
	# Kopfzeile: Serie, Serienschutz, Münzen
	var streak := int(ti.get("streak", 0))
	ov_streak_num.text = str(streak)
	ov_streak_icon.texture = Style.icon("streak" if streak > 0 else "streak_off")
	ov_streak_num.add_theme_color_override("font_color", Style.SUN_DEEP if streak > 0 else Style.INK_3)
	ov_shield_chip.visible = bool(ti.get("shields_visible", false))
	ov_shield_num.text = str(int(ti.get("shields", 0)))
	ov_coin_num.text = str(Game.credits)
	ov_name.text = Voice.char_name()
	var new_char := _char_banner          # alter Spielstand: einmal „Neu: Dein eigener Gott!“ nach dem Ersteller
	_char_banner = false
	ov_banner.visible = (Game.tutorial_done and Game.stars_total() == 0) or new_char
	ov_banner_label.text = "Neu: Dein eigener Gott!" if new_char else str(Days.TEXT["banner_new"])
	_fill_today(ti)
	_fill_week(ti.get("week", []) as Array, streak, int(ti.get("best", 0)))
	ov_debug.visible = OS.is_debug_build()
	_ov_say_state()


## Die Heute-Karte (1.6): neuer Tag · heute geschafft (morgen geht's weiter) · Welt des Tages · vollendet.
func _fill_today(ti: Dictionary) -> void:
	var state := str(ti.get("state", "new"))
	var day := int(ti.get("day", 1))
	var done := state != "new" and state != "wdt"
	tc_caps.text = str(ti.get("caps", ""))
	tc_caps.add_theme_color_override("font_color", Style.LEAF_DEEP if done else Style.SUN_DEEP)
	tc_title.text = str(ti.get("title", ""))
	tc_line.text = str(ti.get("line", ""))
	if state == "wdt":
		tc_title.text = str(ti.get("goal", ""))
		tc_line.text = str(Days.TEXT["wdt_intro"])
	if done:
		ui._set_tile(tc_tile, "check", Style.LEAF_TINT)
	else:
		var ic := "star"
		if day >= 1 and day <= Days.count():
			ic = str(Days.config(day).get("icon", "star"))
		if state == "wdt":
			ic = "trophy"
		ui._set_tile(tc_tile, ic, ui._tint_for_icon(ic))
	tc_count_row.visible = done
	tc_count.text = str(ti.get("countdown", ""))
	tc_go.visible = not done
	tc_go.text = str(Days.TEXT["go"])
	tc_build.visible = done and bool(ti.get("can_build", false))
	tc_again.visible = done and bool(ti.get("more_stars", false))
	tc_again.text = str(Days.TEXT["again_stars"])
	(tc_build.get_parent() as Control).visible = tc_build.visible or tc_again.visible
	var sb: StyleBoxFlat = today_card.get_theme_stylebox("panel")
	sb.set_border_width_all(0 if done else 3)
	sb.bg_color = Style.SURFACE if not done else Color("#F7FBF6")


func _fill_week(week: Array, streak: int, best: int) -> void:
	for i in week_cells.size():
		var st := "none"
		if i < week.size():
			var e: Variant = week[i]
			st = str((e as Dictionary).get("state", "none")) if e is Dictionary else str(e)
		(week_cells[i] as WeekDot).set_state(st)
		(week_letters[i] as Label).add_theme_color_override("font_color", Style.SUN_DEEP if st == "today" or st == "streak" else Style.INK_3)
	week_line.text = str(Days.TEXT["streak"]) % [streak, best] if streak != 1 else "Serie: 1 Tag · Rekord: %d" % best


## Was der Charakter in der Übersicht sagt: einmal das Wiederkommen (Serienschutz / neue Serie), spät am Abend
## müde, sonst passend zur Heute-Karte. Ändert sich nur, wenn sich der Zustand ändert.
func _ov_say_state() -> void:
	var come := Game.take_comeback()
	var state := str(_today.get("state", "new"))
	var nn := Game.next_new_day()
	var tag := str(Days.TEXT["day_title"]) % [nn, str(Days.config(nn).get("title", ""))] if nn <= Days.count() else str(Days.TEXT["wdt_tag"])
	if come == "saved" or come == "lost":
		_ov_say("comeback_" + come, {})
		if come == "lost":
			get_tree().create_timer(1.6).timeout.connect(_ov_face_later.bind("happy"))
		return
	var key := "day_open"
	match state:
		"done_next":
			key = "day_done"
		"wdt":
			key = "wdt_open"
		"wdt_done", "world_done_today":
			key = "wdt_done"
	var m := Daily.minute_of_day(Game.now_local())
	if _ov_said_key == "" and (m >= Balance.REMIND_LATEST or m < Balance.REMIND_EARLIEST) and not Game.coach_seen.has("night_%d" % Game.today_key()):
		key = "open_night"
		Game.coach_seen["night_%d" % Game.today_key()] = true
	var said := "%s:%s" % [key, tag]
	if said == _ov_said_key:
		return
	_ov_say(key, {"tag": tag})
	_ov_said_key = said


func _ov_say(key: String, args: Dictionary) -> void:
	ov_say.text = Voice.line(key, args)
	ui._speak(ov_char, Voice.face(key), "", Style.SURFACE, overview.visible)
	if overview.visible:
		ui._pop(ov_bubble, 1.03)


func _ov_face_later(expr: String) -> void:
	if overview.visible:
		ui.speaker_view(ov_char).set_expression(expr, 2.0)
		ui.speaker_view(ov_char).react("hop")


func _pulse_current() -> void:
	for t in ov_tiles:
		var b: Button = (t as Dictionary)["btn"]
		ui._pulse(b, false)
	ui._pulse(tc_go, false)
	if tc_go.visible:
		get_tree().create_timer(0.6).timeout.connect(ui._pulse.bind(tc_go, true))


func _on_tile(n: int) -> void:
	if not Game.day_unlocked(n):
		var t: Dictionary = ov_tiles[n - 1]
		ui._shake(t["btn"])
		Style.haptic(Style.HAPTIC_TAP)
		if bool((t["btn"] as Button).get_meta("morgen", false)):
			# „Morgen geht's weiter: Tag 3 · Tiere“ – und der Charakter sagt es auf seine Art
			var tag := str(Days.TEXT["day_title"]) % [n, str(Days.config(n).get("title", ""))]
			_ov_say("day_done", {"tag": tag})
			_ov_said_key = "day_done:%s" % tag
			Game.message.emit(Game.locked_text(n), "info")
			return
		ui._show_tooltip(t["btn"], "lock", str(Days.TEXT["day_title"]) % [n, str(Days.config(n).get("title", ""))],
			Game.locked_text(n))
		ui._tip_hide_at = ui._time + 2.4
		return
	ui.ask_day(n)


## „Los!“ auf der Heute-Karte: der neue Tag oder die Welt des Tages.
func _on_today_go() -> void:
	var state := str(_today.get("state", "new"))
	if state == "wdt":
		_start_wdt()
		return
	ui.ask_day(maxi(1, int(_today.get("day", Game.current_day()))))


func _start_wdt() -> void:
	ui._close_modal(true)
	if not Game.start_daily_world():
		_fill_overview()


## „Weiterbauen“ (Heute-Karte): zurück in die gewonnene Welt (solange die App läuft).
func _on_today_build() -> void:
	if not Game.resume_build():
		_fill_overview()


## „Nochmal · mehr Sterne“ (Heute-Karte): der heute geschaffte Tag auf einem neuen Brett.
func _on_today_again() -> void:
	var state := str(_today.get("state", ""))
	if state == "wdt_done":
		_start_wdt()
		return
	ui.ask_day(maxi(1, int(_today.get("replay_day", Game.current_day()))))


## Test-Version: „Nächster Tag (Test)“ – ein ganzer Tag weiter, ohne zu warten.
func _on_debug_next_day() -> void:
	var msg := Game.debug_next_day()
	if msg == "":
		return
	_ov_said_key = ""
	_fill_overview()
	ui._pop(today_card, 1.04)
	Game.message.emit(msg, "info")


func _on_daily_changed() -> void:
	if overview != null and overview.visible:
		_fill_overview()


## Serienschutz-Chip: Halten erklärt, Tippen öffnet „Serienschutz“ (kaufen).
func _on_shield_chip_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (ev as InputEventMouseButton).pressed:
		_open_shield()


func _open_shield() -> void:
	var have := Game.shields()
	sc_text.text = str(Days.TEXT["shield_text"]) % have
	sc_buy.text = str(Days.TEXT["shield_buy"]) % Balance.SHIELD_PRICE
	var err := Daily.shield_buy_error(Game.daily, Game.credits)
	sc_buy.disabled = err != ""
	sc_buy.modulate.a = 0.5 if err != "" else 1.0
	sc_why.text = err
	sc_why.visible = err != ""
	ui._open_modal(shield_card)


func _on_shield_buy() -> void:
	var err := Game.buy_shield()
	if err != "":
		sc_why.text = err
		sc_why.visible = true
		ui._shake(sc_buy)
		return
	ui._close_modal()
	_fill_overview()
	_ov_say("shield_bought", {})
	ui._pop(ov_shield_chip, 1.2)
	Style.haptic(Style.HAPTIC_COMBO)


func _on_free_pressed() -> void:
	if not Game.free_play_unlocked():
		ui._shake(ov_free)
		ui._show_tooltip(ov_free, "lock", str(Days.TEXT["free"]), "Erst die 7 Tage schaffen. Dann ist deine Welt vollendet – und das freie Spiel geht auf.")
		ui._tip_hide_at = ui._time + 2.6
		return
	_open_free()


## „Freies Spiel“: die vier Spielarten mit ihrem Rekord.
func _open_free() -> void:
	for c in (free_card.get_meta("body") as Control).get_children():
		if c is Button and (c as Button).has_meta("free_row"):
			var row: Dictionary = (c as Button).get_meta("free_row")
			var key := str((c as Button).get_meta("explain", "")).trim_prefix("mode_")
			var best := Game.best_for(key)
			(row["num"] as Label).text = str(best) if best > 0 else "–"
	# Läuft noch ein freies Spiel? Dann geht es dort weiter.
	var gs := Game.state
	free_continue.visible = gs != null and not Game.in_day() and not Game.over and gs.twists > 0
	free_continue.text = "Weiterspielen · %s" % Game.level_name() if gs != null and gs.endless else "Weiterspielen · 40 Drehungen"
	ui._open_modal(free_card)


func _on_free_continue() -> void:
	ui._close_modal(true)
	hide_overview()
	ui.refresh()


# =============================================================================
# Ein Tag beginnt: Ziel-Karte
# =============================================================================

func _on_new_game() -> void:
	hide_overview()
	_end_gen += 1
	_hide_lane(true)
	_hold = {}
	_playing = false
	_tut = 0
	_demo_at = INF
	_demo_done = false
	_unlock_input()
	_last_progress = -1
	_last_left = -1
	_warned_fire = false
	_first_card_done = false
	if not Game.in_day():
		chip.visible = false
		rule_tag.visible = false


func _on_day_started(info: Dictionary) -> void:
	if info.is_empty():
		return
	hide_overview()
	_info = info
	var n := int(info["day"])
	# Neues fliegt erst nach „Los!“ an seinen Platz (beim ersten Besuch)
	_hold = {}
	if REVEAL.has(n) and not Game.coach_seen.has("day_rev_%d" % n):
		var target := str((REVEAL[n] as Array)[2])
		if target != "chip":
			_hold[target] = true
	if Game.day_tutorial():
		_hold["dock"] = true
	_fill_goal_card(info)
	ui.refresh()
	ui.world.focus_place(Vector3i(0, 1, 0))
	_open_goal_card.call_deferred()


func _open_goal_card() -> void:
	if not Game.in_day() or Game.over or creator_open():
		return
	ui._open_modal(goal_card, false)
	if gc_new.visible:
		# Das Neue zoomt herein
		gc_new_tile.pivot_offset = gc_new_tile.custom_minimum_size * 0.5
		gc_new_tile.scale = Vector2.ONE * 0.2
		var tw := ui._fx(gc_new_tile, "s")
		tw.tween_interval(0.3)
		tw.tween_property(gc_new_tile, "scale", Vector2.ONE * 1.15, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(gc_new_tile, "scale", Vector2.ONE, 0.2)


func _fill_goal_card(info: Dictionary) -> void:
	var n := int(info["day"])
	gc_caps.text = str(Days.TEXT["day_title"]) % [n, str(info.get("title", ""))]
	var intro := str(info.get("intro", ""))
	var face := "happy"
	if bool(info.get("wdt", false)):
		gc_caps.text = str(info.get("caps", ""))
		intro = Voice.line("wdt_open")
	elif n == 1 and bool(info.get("first_visit", false)):
		intro = Voice.line("intro")          # „Hallo, ich bin Miez! …“ – der Charakter stellt sich vor
	elif n == 1 and Game.day_tutorial():
		intro = Voice.line("intro")
	else:
		face = "neutral"
	gc_intro.text = intro
	ui._speak(gc_speaker, face, "", Style.SURFACE, false)
	var gi := _goal_icon(info)
	ui._set_tile(gc_goal_tile, gi, ui._tint_for_icon(gi))
	gc_goal.text = str(info.get("goal_text", ""))
	gc_limit.text = Days.limit_line(int(info.get("limit", 0)))
	var rule := str(info.get("rule_line", ""))
	gc_rule.visible = rule != ""
	gc_rule_label.text = rule
	# Krieg: rot; eine Spielregel (Tag 1): grün
	var war_rule := str(info.get("rule_icon", "swords")) == "swords"
	gc_rule_icon.texture = Style.icon(str(info.get("rule_icon", "swords")))
	gc_rule.add_theme_stylebox_override("panel", Style.box(Style.FIRE_TINT if war_rule else Style.LEAF_TINT, 18, 14, 6))
	gc_rule_label.add_theme_color_override("font_color", Style.FIRE_DEEP if war_rule else Style.LEAF_DEEP)
	var nw: Dictionary = info.get("new", {})
	var demo := demo_due()
	gc_new.visible = (not nw.is_empty() and n > 1) or demo
	if demo:
		# Tag 1, ganz am Anfang: Die Karte sagt vorher, dass erst die Hand einen Zug zeigt (dann wundert sich niemand)
		ui._set_tile(gc_new_tile, "hand", Style.SURFACE)
		gc_new_title.text = str(Days.TEXT["demo_title"])
		gc_new_text.text = str(Days.TEXT["demo_text"])
	elif gc_new.visible:
		var ic := str(nw.get("icon", "star"))
		ui._set_tile(gc_new_tile, ic, Style.SURFACE)
		gc_new_title.text = str(nw.get("title", ""))
		gc_new_text.text = str(nw.get("text", ""))
	gc_go.text = str(Days.TEXT["go_demo"]) if demo else str(Days.TEXT["go"])
	var st: Array = info.get("stars", [0, 0])
	gc_star_label.text = Days.limit_line(int(st[0]))
	var mercy := int(info.get("mercy", 0))
	gc_mercy.visible = mercy > 0
	gc_mercy.text = str(Days.TEXT["mercy"]) % mercy


## Zeigt die Hand gleich den ersten Zug vor? Nur ganz am Anfang: Tag 1 auf dem Tutorial-Brett, solange die
## Vorführung noch nie eine Wiese gezeigt hat (oder „Tutorial“ im Menü / ein ausdrücklich gewähltes Brett 0).
func demo_due() -> bool:
	return Game.day_tutorial() and Game.state.twists == 0 and (not Game.coach_seen.has("day1_demo") or Game._board_explicit)


func _on_go() -> void:
	ui._close_modal()
	_playing = true
	_tut_at = ui._time
	var n := int(_info.get("day", 0))
	if demo_due():
		# „Schau zu!“: Ganz am Anfang, bevor man etwas tun kann, spielt die Hand genau einen Zug vor (die Reihe
		# wächst). Die Ziel-Karte hat das angekündigt („Zeig mir, wie es geht“). Solange ist die Eingabe gesperrt
		# (ein Tippen lässt die Zeile kurz hüpfen); sobald die Wiese da ist: frei – und der Würfel bewegt sich nie
		# mehr von selbst.
		_tut = 1
		_tut_misses = 0
		_demo_done = false
		_demo_at = ui._time + 0.25
		_lock_at = ui._time
		ui.set_input_locked(true)
		var c: Array = _info.get("coach", [])
		var demo_line := str(_info.get("coach_demo", ""))
		if demo_line == "" and not c.is_empty():
			demo_line = str(c[0])
		demo_line = Voice.day_coach(1, "demo", demo_line)
		_show_lane(demo_line, str(Days.TEXT["demo_caps"]), "hand", Style.LEAF_TINT, INF, Voice.day_face(1, "demo"))
		ui.world.focus_place(Vector3i(0, 1, 0))
		return
	if Game.day_tutorial():
		# Die Vorführung lief schon einmal (Tag 1 verlassen und wieder da): keine Sperre, keine Hand – gleich
		# „Jetzt du!“ mit der leuchtenden Scheibe
		_tut = 2
		_tut_misses = 0
		_demo_done = true
		_demo_at = INF
		_tut_your_turn(_end_gen)
		ui.world.focus_place(Vector3i(0, 1, 0))
		return
	var delay := 0.35
	if REVEAL.has(n) and not Game.coach_seen.has("day_rev_%d" % n):
		Game.coach_seen["day_rev_%d" % n] = true
		Game.save_settings()
		get_tree().create_timer(0.35).timeout.connect(_reveal_fly.bind(n, _end_gen))
		delay = 2.3
	if not Game.coach_seen.has("day_coach_%d" % n):
		get_tree().create_timer(delay).timeout.connect(_first_coach.bind(n, _end_gen))


## Die erste Hinweis-Zeile eines Tages (einmal): zeigt auf das Neue oder steht in der Spur.
func _first_coach(n: int, gen: int) -> void:
	if gen != _end_gen or not Game.in_day() or Game.over:
		return
	var c: Array = _info.get("coach", [])
	if c.is_empty():
		return
	Game.coach_seen["day_coach_%d" % n] = true
	Game.save_settings()
	var at := str(COACH_AT.get(n, ""))
	var tool_text := Voice.day_coach(n, "tool", str(Game.state.day.get("coach_tool", "")))
	if at == "rain" and tool_text != "" and ui.rain_btn.is_visible_in_tree():
		# Oben die Aufgabe (wie wächst das Ziel?), unten am Regen das Neue
		_show_lane(coach_line(0), "Deine Aufgabe", _goal_icon(_info), ui._tint_for_icon(_goal_icon(_info)), 7.0, coach_face(0))
		ui._place_coach(ui.rain_btn, "rain", tool_text, Voice.day_face(n, "tool"))
		ui._coach_until = ui._time + 6.0
		return
	var nw: Dictionary = _info.get("new", {})
	var ic := str(nw.get("icon", "info"))
	_show_lane(coach_line(0), "Neu heute", ic, ui._tint_for_icon(ic), 7.0, coach_face(0))


# =============================================================================
# Aufdecken: Das Neue springt in der Mitte auf und fliegt an seinen Platz
# =============================================================================

func _reveal_fly(n: int, gen: int) -> void:
	if gen != _end_gen or not Game.in_day():
		return
	var r: Array = REVEAL[n]
	var icon_name := str(r[0])
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.card(28, 3, 22, 18))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := ui._vbox(8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(v)
	var tl := ui._tile(icon_name, 96, ui._tint_for_icon(icon_name), 0.32)
	tl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(tl)
	var lb := ui._label(str(r[1]), 22, Style.INK, Style.W_BLACK)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lb)
	fx_layer.add_child(card)
	card.reset_size()
	var vs := ui._vs()
	card.position = (Vector2(vs.x * 0.5, vs.y * 0.44) - card.size * 0.5).round()
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ZERO
	card.set_meta("reveal", n)
	var tw := card.create_tween()
	tw.tween_property(card, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.tween_callback(_reveal_go.bind(card, n, gen))
	Style.haptic(Style.HAPTIC_MERGE)


func _reveal_go(card: PanelContainer, n: int, gen: int) -> void:
	if not is_instance_valid(card):
		return
	if gen != _end_gen:
		card.queue_free()
		return
	var target := _reveal_target(str((REVEAL[n] as Array)[2]))
	# Damit das Ziel einen Platz hat, wird es schon sichtbar (das Fliegen landet dort)
	_hold.erase(str((REVEAL[n] as Array)[2]))
	ui.refresh()
	var to_c := target.get_global_rect().get_center() if target != null else ui._vs() * Vector2(0.5, 0.1)
	var from_c := card.position + card.size * 0.5
	var tw := ui._fly(card, from_c, to_c, 0.6, 120.0, 0.2)
	tw.parallel().tween_property(card, "modulate:a", 0.4, 0.6)
	tw.tween_callback(_reveal_land.bind(card, target))


func _reveal_land(card: PanelContainer, target: Control) -> void:
	card.queue_free()
	if target != null and is_instance_valid(target) and target.is_visible_in_tree():
		ui._pop(target, 1.2)
		ui._ripple(target, Style.SUN)
	Style.haptic(Style.HAPTIC_TAP)


func _reveal_target(key: String) -> Control:
	match key:
		"rain":
			return ui.rain_btn
		"strike":
			return ui.strike_btn
		"scale":
			return ui.scale_chip
	return chip_tile


## Was gerade noch zurückgehalten wird (fliegt gleich herein): "rain", "scale", "strike", "dock".
func held(what: String) -> bool:
	return _hold.has(what)


# =============================================================================
# Kopfzeile während eines Tages
# =============================================================================

## Wird von GameUI.refresh aufgerufen: Ziel-Chip, Drehungen, „Kein Krieg!“.
func refresh_hud() -> void:
	var gs := Game.state
	var day := Game.in_day()
	chip.visible = day
	rule_tag.visible = day and bool(gs.day.get("no_war", false)) and not overview.visible
	if not day:
		return
	var st := gs.day_status()
	var building := bool(st.get("free_build", false))
	ring.visible = not building
	ring_caps.visible = not building
	grow_box.visible = building
	if building:
		# Weiterbauen: Haken, „Weiterbauen“, wie viel seit dem Sieg gewachsen ist – keine Drehungs-Grenze
		chip_caps.text = str(Days.TEXT["build"])
		chip_caps.add_theme_color_override("font_color", Style.LEAF_DEEP)
		ui._set_tile(chip_tile, "check", Style.LEAF_TINT)
		var tg := int(st.get("target", 0))
		chip_num.text = "%d/%d" % [tg, tg] if tg > 0 else "✓"
		var g := int(st.get("growth", 0))
		if grow_num.text != str(g) and grow_num.text != "":
			ui._number_pop(grow_num, Style.LEAF_DEEP, Style.LEAF_DEEP)
		grow_num.text = str(g)
		_chip_sb.bg_color = Style.GLASS
		ui._pulse(ring, false)
		_last_left = -1
		_last_progress = int(st.get("progress", 0))
		return
	var target := int(st.get("target", 0))
	var prog := int(st.get("progress", 0))
	var left := int(st.get("left", 0))
	# Tag 7: Glaube UND grüne Waage – beide Hälften des Ziels sind immer zu sehen
	var need_green := bool(st.get("need_green", false))
	var green := bool(st.get("green", true))
	var waage := need_green and prog >= target and not green and not bool(st.get("won", false))
	chip_num.text = "%d/%d" % [mini(prog, target), target]
	if waage:
		chip_caps.text = str(Days.TEXT["balance_needed"])
		chip_caps.add_theme_color_override("font_color", Style.FIRE_DEEP)
		ui._set_tile(chip_tile, "balance", Style.FIRE_TINT)
	else:
		if need_green:
			chip_caps.text = str(Days.TEXT["balance_ok"] if green else Days.TEXT["balance_goal"])
			chip_caps.add_theme_color_override("font_color", Style.LEAF_DEEP if green else Style.INK_3)
		else:
			chip_caps.text = _goal_noun(gs)
			chip_caps.add_theme_color_override("font_color", Style.INK_3)
		var gi := _goal_icon(_info if not _info.is_empty() else Game.day_info())
		ui._set_tile(chip_tile, gi, ui._tint_for_icon(gi))
	var warn := left <= 3 and not bool(st.get("won", false))
	ring.set_value(left, int(st.get("limit", 1)), warn)
	_chip_sb.bg_color = Style.SUN_TINT if warn else (Style.FIRE_TINT if waage else Style.GLASS)
	ui._pulse(ring, warn and not Game.over)
	if _last_left >= 0 and left < _last_left and warn:
		ui._pop(ring, 1.15)
	_last_left = left
	if _last_progress >= 0 and prog > _last_progress:
		ui._pop(chip, 1.1)
		ui._number_pop(chip_num, Style.LEAF_DEEP)
		ui._ripple(chip_tile, Style.LEAF)
	_last_progress = prog
	# Feuer-Warnung an Tag 2 (einmal): beim zweiten Fehlversuch hintereinander
	if gs.misses == Balance.FIRE_AFTER - 1 and not gs.no_fire and not _warned_fire and _playing:
		_warned_fire = true
		var c: Array = _info.get("coach", [])
		if int(_info.get("day", 0)) == 2 and c.size() > 1 and not Game.coach_seen.has("day_fire_warn"):
			Game.coach_seen["day_fire_warn"] = true
			_show_lane(coach_line(1), "Achtung", "fire", Style.FIRE_TINT, 6.0, "worried")
	if gs.misses == 0:
		_warned_fire = false


func _goal_noun(gs: GameState) -> String:
	var t := gs.goal_type()
	if t == "make":
		var ks := gs.goal_kinds()
		var k := int(ks[0]) if not ks.is_empty() else FieldData.MEADOW
		return FieldData.kind_plural(k) if gs.goal_target() != 1 else FieldData.kind_name(k)
	if t == "wishes":
		return "Wünsche"
	return "Glaube"


func _goal_icon(info: Dictionary) -> String:
	var gi := str(info.get("goal_icon", "star"))
	if Style.icon(gi) == null:
		gi = "star"
	return gi


func _on_day_progress(_status: Dictionary) -> void:
	if not Game.in_day():
		return
	var p := Game.state.goal_progress()
	if _tut == 1 and p >= 1:
		_tut = 2
		ui._hide_finger()
		_demo_at = INF
		# Die Wiese ist da: sofort frei (kein Warten auf die Kamera), und die Vorführung kommt nie wieder
		_unlock_input()
		if not Game.coach_seen.has("day1_demo"):
			Game.coach_seen["day1_demo"] = true
			Game.save_settings()
		# Die erste Wiese nicht verpassen: Die Kamera dreht zu ihr (liegt sie auf einer Seite, schräg von oben)
		if _goal_field >= 0:
			ui.world.focus_field(_goal_field)
		var c: Array = _info.get("coach", [])
		_show_lane(coach_line(1), "", "meadow", Style.LEAF_TINT, 2.4, coach_face(1))
		get_tree().create_timer(2.6).timeout.connect(_tut_your_turn.bind(_end_gen))
	elif _tut == 2 and p >= 2:
		_tut = 3
		var c2: Array = _info.get("coach", [])
		_show_lane(coach_line(3) if c2.size() > 3 else "", "", "check", Style.LEAF_TINT, 2.8, coach_face(3))


func _tut_your_turn(gen: int) -> void:
	if gen != _end_gen or not Game.in_day() or Game.over:
		return
	_unlock_input()          # (schon frei, seit die Wiese da ist; nur zur Sicherheit)
	_hold.erase("dock")
	ui.refresh()
	if not ui.dock.visible:
		ui._dock_in(0.0)
	if _tut != 2:
		return
	var c: Array = _info.get("coach", [])
	_show_lane(coach_line(2) if c.size() > 2 else "", "Du bist dran", "meadow", Style.LEAF_TINT, INF, coach_face(2))


func _on_move_done(kind: String) -> void:
	if not Game.in_day() or kind != "twist":
		return
	if _tut == 1 and Game.state.goal_progress() == 0:
		_tut_misses += 1
		# Der Tipp ist ab jetzt da (falls der gezeigte Zug nicht mehr reicht)
		if _hold.has("dock"):
			_hold.erase("dock")
			ui.refresh()
			if not ui.dock.visible:
				ui._dock_in(0.0)
		# Nur Text und Leuchten (die Scheibe bewegt sich nicht von selbst)
		if Game.tutorial_move().is_empty():
			_show_lane("Tipp auf „Tipp“ – dann leuchtet eine gute Reihe.", "Du bist dran", "bulb", Style.LEAF_TINT, INF)
		else:
			_show_lane("Fast! Wisch über die leuchtende Reihe.", "Du bist dran", "touch", Style.LEAF_TINT, INF)
	elif lane.visible and _lane_until == INF and _tut != 1 and _tut != 2:
		_hide_lane()
	elif lane.visible and _tut == 0 and _lane_until != INF:
		_lane_until = minf(_lane_until, ui._time + 1.5)


## Ein Zug wird ausgewertet: Eine Hinweis-Zeile mit Zeit macht Platz für das, was jetzt passiert (Jubel, Krieg …).
## Die Zeilen des Tutorials (ohne Zeit) bleiben.
func _on_round(result: Dictionary, _before: Dictionary) -> void:
	if lane.visible and _lane_until != INF:
		_hide_lane()
	# Der Charakter lobt ab und zu (höchstens alle 10 s, jede 4. Runde mit Wachstum; nie im Tutorial)
	var grew := false
	for e0 in result.get("events", []):
		if str((e0 as Dictionary).get("type", "")) == "merge":
			grew = true
	if grew and Game.in_day() and _playing and _tut == 0 and not lane.visible:
		_merges += 1
		if _merges % 4 == 0 and _time - _praise_at > 10.0:
			_praise_at = _time
			_show_lane(Voice.praise(), "", "meadow", Style.LEAF_TINT, 1.8, "happy")
	# Wo ist gerade etwas für das Ziel gewachsen? (Tag 1: die Kamera schaut dorthin)
	_goal_field = -1
	if Game.in_day() and Game.state.goal_type() == "make":
		var ks := Game.state.goal_kinds()
		for e in result.get("events", []):
			var ev: Dictionary = e
			if str(ev.get("type", "")) == "merge" and ks.has(int(ev.get("kind", -1))):
				_goal_field = int(ev.get("field", -1))


## Kommt die Wahl-Karte, macht die Hinweis-Zeile Platz (die Karte erklärt sich selbst).
func _on_choice_needed(_info_c: Dictionary) -> void:
	if Game.in_day() and lane.visible:
		_hide_lane()


func _on_choice_made(_info_c: Dictionary) -> void:
	if not Game.in_day() or _first_card_done:
		return
	_first_card_done = true


# =============================================================================
# Hinweis-Zeile in der Spur (blockiert nie)
# =============================================================================

## Satz i der Tages-Hinweise im Ton des eigenen Charakters ("" = gibt es nicht).
func coach_line(i: int) -> String:
	var c: Array = _info.get("coach", [])
	if i < 0 or i >= c.size():
		return ""
	return Voice.day_coach(int(_info.get("day", 0)), i, str(c[i]))


func coach_face(i: int) -> String:
	return Voice.day_face(int(_info.get("day", 0)), i)


func _show_lane(text: String, caps: String, icon_name: String, tint: Color, hold: float, face: String = "neutral") -> void:
	if text == "":
		return
	ui._speak(lane_speaker, face, icon_name, tint)
	lane_label.text = text
	lane_caps.text = caps
	lane_caps.visible = caps != ""
	lane_caps.add_theme_color_override("font_color", Style.FIRE_DEEP if tint == Style.FIRE_TINT else Style.LEAF_DEEP)
	ui._set_tile(lane_tile, icon_name, tint)
	lane.size = Vector2.ZERO
	lane.reset_size()
	var vs := ui._vs()
	lane.position = Vector2(roundf((vs.x - lane.size.x) * 0.5), roundf(ui._lane_base()))
	_lane_until = ui._time + hold if hold < INF else INF
	if lane.visible and lane.modulate.a > 0.99:
		ui._pop(lane, 1.03)
	else:
		ui._appear(lane, Vector2(0, -10), Style.DUR_IN, 0.98)


func _hide_lane(instant: bool = false) -> void:
	_lane_until = INF
	if lane == null:
		return
	if instant:
		ui._hide_now(lane)
	elif lane.visible:
		ui._disappear(lane, Vector2(0, -8), Style.DUR_OUT)


func lane_visible() -> bool:
	return lane != null and lane.visible and lane.modulate.a > 0.05


func lane_bottom() -> float:
	return lane.position.y + lane.size.y


# =============================================================================
# Takt: Tag-1-Hand, Hinweis-Zeile ausblenden
# =============================================================================

func _process(delta: float) -> void:
	_time += delta
	if ui == null:
		return
	if lane.visible and ui._time > _lane_until:
		_hide_lane()
	if overview.visible:
		# Übersicht offen: jede Sekunde prüfen, ob ein neuer Spieltag begann; die Uhr-Zeile einmal je Minute
		_ov_tick += delta
		if _ov_tick >= 1.0:
			_ov_tick = 0.0
			Game.today_key()
			if int(_time) % 30 == 0:
				tc_count.text = Daily.countdown_text(Game.now_local())
	if not _playing or not Game.in_day() or Game.over:
		if ui.input_locked():
			_unlock_input()
		return
	var w := ui.world
	if _tut == 1 and not _demo_done and ui._time >= _demo_at and ui.input_locked():
		# Die eine Vorführung (nur vor jeder Eingabe; wartet, solange etwas offen ist oder sich bewegt)
		if not w.animating and not Game.busy and w._mode == "" and not ui.modal_bg.visible:
			_demo_done = true
			_demo_at = INF
			_demo_started = ui._time
			var demo := Game.tutorial_move()      # nur ein Zug, der auch etwas wachsen lässt
			if demo.is_empty() or not w.can_self_move() or not ui._play_demo_move(demo):
				_demo_failed()
	if ui.input_locked():
		# Notausgang: Die Eingabe bleibt nie hängen (Vorführung lief nicht durch, App pausiert …): nach 6 s, sobald
		# sich nichts mehr bewegt; spätestens nach 12 s
		var still := not w.animating and not Game.busy and w._mode == ""
		var idle_after := _tut == 1 and _demo_done and still and ui._time - _demo_started > 3.0
		if idle_after or (still and ui._time - _lock_at > 6.0) or ui._time - _lock_at > 12.0:
			_demo_failed()


## Während „Schau zu!“ getippt oder gewischt: Das zählt nicht – aber man sieht, dass es ankam (die Zeile hüpft).
func blocked_tap() -> void:
	if _tut != 1 or lane == null or not lane.visible:
		return
	lane_caps.text = str(Days.TEXT["demo_caps"])
	lane_caps.visible = true
	ui._pop(lane, 1.06)


## Die Vorführung ging nicht (oder nicht ganz): sofort freigeben, der Spieler dreht selbst (Leuchten zeigt die Scheibe).
func _demo_failed() -> void:
	_demo_done = true
	_demo_at = INF
	ui._hide_finger()
	_unlock_input()
	if _tut == 1:
		var c: Array = _info.get("coach", [])
		_show_lane(coach_line(0) if not c.is_empty() else "", "Du bist dran", "touch", Style.LEAF_TINT, INF, coach_face(0))


func _unlock_input() -> void:
	if ui != null:
		ui.set_input_locked(false)


## Halten: Erklärungen für den Ziel-Chip, die Kacheln und „Kein Krieg!“.
func tooltip(key: String) -> Dictionary:
	if key == "day_goal":
		if not Game.in_day():
			return {}
		var info := Game.day_info()
		var left := Game.state.twists_left()
		if Game.state.day_free_build:
			return {"icon": "check", "title": str(Days.TEXT["build"]), "body": "Geschafft! Jetzt baust du ohne Grenze weiter. Die Zahl zeigt, wie viel seit dem Sieg gewachsen ist. Je 10 Felder gibt es 1 Münze (höchstens 3 am Tag)."}
		var body := "%s. %s" % [str(info.get("goal_text", "")), str(Days.TEXT["left"]) % left]
		var st: Dictionary = info.get("status", {})
		if bool(st.get("need_green", false)):
			body += " Grün ist die Mitte der Weltwaage."
		return {"icon": _goal_icon(info), "title": "Deine Aufgabe", "body": body}
	if key == "day_rule":
		return {"icon": "swords", "title": "Kein Krieg!", "body": "Bring nie zwei Kirchen durch eine Drehung zusammen. Ein Krieg beendet den Tag."}
	if key == "day_streak":
		var st := Game.streak()
		return {"icon": "streak", "title": "Deine Serie", "body": "%s Jeden Tag, an dem du ein Level schaffst, wächst sie um eins. Rekord: %d." % [
			"Noch keine Serie." if st == 0 else ("1 Tag in Folge." if st == 1 else "%d Tage in Folge." % st), int(Game.daily.get("streak_best", 0))]}
	if key == "day_week":
		return {"icon": "streak", "title": str(Days.TEXT["week"]), "body": "Flamme: geschafft. Schild: dein Serienschutz hat den Tag gerettet. Leerer Kreis: verpasst."}
	if key == "day_coins":
		return {"icon": "coin", "title": "Münzen", "body": "Du hast %d Münzen. Damit kaufst du Serienschutz (5 Münzen) und im freien Spiel Tipps. Neue gibt es fürs Weiterbauen." % Game.credits}
	if key == "day_stars":
		return {"icon": "star", "title": "Sterne", "body": "Je weniger Drehungen du für einen Tag brauchst, desto mehr Sterne. Du hast %d von %d." % [Game.stars_total(), Game.stars_max()]}
	if key == "day_free":
		return {"icon": "trophy", "title": str(Days.TEXT["free"]), "body": "Bau deine Welt weiter, bis sie vollendet ist: Einfach, Mittel, Schwer oder 40 Drehungen. Geht nach Tag 7 auf."}
	if key.begins_with("day_tile_"):
		var n := int(key.substr(9))
		var cfg := Days.config(n)
		var title := str(Days.TEXT["day_title"]) % [n, str(cfg.get("title", ""))]
		if not Game.day_unlocked(n):
			return {"icon": "lock", "title": title, "body": Game.locked_text(n)}
		var b := "%s – %s. %s." % [Days.goal_line(cfg), Days.limit_line(int(cfg.get("limit", 0))), Days.star_line(cfg)]
		var st2 := Game.stars_of(n)
		if st2 > 0:
			b += " Dein Bestes: %d %s." % [st2, "Stern" if st2 == 1 else "Sterne"]
		return {"icon": str(cfg.get("icon", "star")), "title": title, "body": b}
	return {}


# =============================================================================
# Geschafft / nicht geschafft
# =============================================================================

func _on_day_won(info: Dictionary) -> void:
	_playing = false
	_tut = 0
	_unlock_input()
	_end_gen += 1
	_hide_lane()
	ui._hide_finger()
	get_tree().create_timer(0.9).timeout.connect(_show_win.bind(info, _end_gen))


func _show_win(info: Dictionary, gen: int) -> void:
	if gen != _end_gen:
		return
	_win_info = info
	var n := int(info["day"])
	var wdt := bool(info.get("wdt", false))
	var complete := bool(info.get("world_complete", false))
	var got := int(info.get("stars", 0))
	wc_title.text = str(Days.TEXT["complete"]) if complete else (str(Days.TEXT["won"]) % n if not wdt else "%s geschafft!" % str(Days.TEXT["wdt"]))
	var used := int(info.get("used", 0))
	var three := int((Game.state.day.get("stars", [0, 0]) as Array)[0])
	if got < 3 and three > 0:
		wc_used.text = str(Days.TEXT["won_more"]) % [used, three]       # was der 3. Stern braucht
	else:
		wc_used.text = str(Days.TEXT["won_in"]) % used
	wc_days.visible = complete
	wc_total.visible = complete
	wc_free_line.visible = complete
	wc_total.text = str(Days.TEXT["stars_total"]) % [int(info.get("stars_total", 0)), int(info.get("stars_max", 21))]
	wc_row.visible = true
	# Was als Nächstes kommt (2.1): Ist der nächste neue Tag erst morgen, heißt der Hauptknopf „Weiterbauen“
	var next_open := bool(info.get("next_open", false))
	var nxt := int(info.get("next_new", 0))
	var more := got < 3
	wc_next.set_meta("act", "build")
	wc_alt.set_meta("act", "again")
	wc_next.text = str(Days.TEXT["build"])
	wc_next.icon = Style.icon("meadow")
	wc_alt.text = str(Days.TEXT["again_stars"]) if more else str(Days.TEXT["again"])
	wc_alt.visible = more
	if complete:
		wc_alt.text = str(Days.TEXT["free"])
		wc_alt.set_meta("act", "free")
		wc_alt.visible = true
	elif next_open and nxt > 0 and not wdt:
		wc_next.text = str(Days.TEXT["next"]) % [nxt, str(Days.config(nxt).get("title", ""))]
		wc_next.icon = null
		wc_next.set_meta("act", "next")
		wc_next.set_meta("next", nxt)
		wc_alt.text = str(Days.TEXT["build"])
		wc_alt.set_meta("act", "build")
		wc_alt.visible = true
	wc_next_line.text = str(info.get("next_line", ""))
	wc_next_line.visible = wc_next_line.text != "" and not next_open
	# Der Charakter: stolz (3 Sterne: dreht sich), sagt den Sieg-Satz
	wc_char.set_look(ui.char_look())
	wc_char.set_expression("proud", 3.0)
	wc_say.text = Voice.line("win_%d" % clampi(got, 1, 3))
	# Serie: erst die alte Zahl, nach den Sternen zählt sie hoch
	var si: Dictionary = info.get("streak", {})
	var counted := bool(si.get("counted", false))
	var before := int(si.get("before", Game.streak()))
	var now_s := int(si.get("streak", Game.streak()))
	wc_streak_num.text = str(before if counted else now_s)
	wc_flame.texture = Style.icon("streak" if (before > 0 or not counted) and now_s > 0 else "streak_off")
	wc_streak_text.text = _streak_caption(now_s if not counted else before, false)
	var week: Array = Daily.week(Game.daily, Game.today_key())
	for i in wc_week.size():
		var st := str((week[i] as Dictionary).get("state", "none")) if i < week.size() else "none"
		if counted and st == "streak" and int((week[i] as Dictionary).get("key", -1)) == Game.today_key():
			st = "today"           # leuchtet gleich auf
		(wc_week[i] as WeekDot).set_state(st)
	wc_big.visible = false
	for s in wc_stars:
		(s as Control).visible = false
	ui._open_modal(win_card, false)
	_confetti()
	for i in got:
		get_tree().create_timer(0.45 + 0.28 * i).timeout.connect(_star_in.bind(i, gen))
	get_tree().create_timer(0.5 + 0.28 * got).timeout.connect(_win_char_cheer.bind(got, gen))
	if counted:
		get_tree().create_timer(0.85 + 0.28 * got).timeout.connect(_streak_step.bind(si, gen))
	Style.haptic(Style.HAPTIC_COMBO)


func _win_char_cheer(got: int, gen: int) -> void:
	if gen != _end_gen or not win_card.visible:
		return
	wc_char.talking(true)
	wc_char.react("spin" if got >= 3 else "hop")


## „Deine Serie beginnt“ · „2 Tage in Folge!“
func _streak_caption(n: int, fresh: bool) -> String:
	if n <= 0:
		return "Noch keine Serie"
	if n == 1:
		return str(Days.TEXT["streak_one"]) if fresh else "1 Tag in Folge"
	return str(Days.TEXT["streak_days"]) % n


## Die Serien-Feier (1.5): Die Zahl zählt hoch, heute leuchtet in der Woche, der Charakter sagt den Serien-Satz.
## Meilensteine (7, 14, 30 …): Konfetti und groß „7 Tage in Folge!“.
func _streak_step(si: Dictionary, gen: int) -> void:
	if gen != _end_gen or not win_card.visible:
		return
	var st := int(si.get("streak", 0))
	wc_streak_num.text = str(st)
	wc_flame.texture = Style.icon("streak")
	wc_streak_text.text = _streak_caption(st, true)
	ui._pop(wc_streak, 1.08)
	ui._number_pop(wc_streak_num, Style.SUN, Style.SUN_DEEP)
	wc_flame.pivot_offset = wc_flame.size * 0.5
	ui._pop(wc_flame, 1.35)
	ui._ripple(wc_flame, Style.SUN)
	var k := Game.today_key()
	var week: Array = Daily.week(Game.daily, k)
	for i in wc_week.size():
		if i < week.size():
			(wc_week[i] as WeekDot).set_state(str((week[i] as Dictionary).get("state", "none")))
			if int((week[i] as Dictionary).get("key", -1)) == k:
				ui._pop(wc_week[i], 1.4)
	var key := "streak_n"
	if st == 1:
		key = "streak_1"
	elif bool(si.get("milestone", false)) and st == Balance.STREAK_MILESTONE:
		key = "streak_7" if int(si.get("shield", 0)) > 0 else "streak_7_full"
	elif bool(si.get("big", false)) or bool(si.get("milestone", false)):
		key = "streak_big"
	wc_say.text = Voice.line(key, {"streak": st})
	wc_char.set_expression("proud", 3.0)
	wc_char.talking(true)
	wc_char.react("hop")
	if bool(si.get("milestone", false)) or bool(si.get("big", false)):
		wc_big.text = str(Days.TEXT["streak_days"]) % st
		wc_big.visible = true
		ui._appear(wc_big, Vector2(0, 8), 0.3, 0.6)
		_confetti()
		if int(si.get("shield", 0)) > 0:
			Game.message.emit(str(Days.TEXT["shield_won"]), "reward")
		elif int(si.get("coins", 0)) > 0:
			Game.message.emit(str(Days.TEXT["shield_coins"]) % int(si.get("coins", 0)), "reward")
	Style.haptic(Style.HAPTIC_COMBO)


func _star_in(i: int, gen: int) -> void:
	if gen != _end_gen or not win_card.visible:
		return
	var s: TextureRect = wc_stars[i]
	s.visible = true
	s.pivot_offset = s.size * 0.5
	s.scale = Vector2.ONE * 2.2
	s.modulate.a = 0.0
	s.rotation = -0.5
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 1.0, 0.18)
	tw.tween_property(s, "rotation", 0.0, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ui._ripple(s, Style.SUN)
	Style.haptic(Style.HAPTIC_MERGE)


## Bunte Schnipsel und kleine Symbole fallen von oben (über der Karte, blockieren nichts).
func _confetti() -> void:
	var vs := ui._vs()
	var cols := [Style.SUN, Style.LEAF, Style.WATER, Style.FIRE, Color("#C9B5F0"), Color("#FFD88A")]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_msec())
	for k in 42:
		var p: Control
		if k % 7 == 0:
			var t := TextureRect.new()
			t.texture = Style.icon(["star", "heart", "meadow", "faith"][k % 4])
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.size = Vector2(30, 30)
			p = t
		else:
			var r := Panel.new()
			r.add_theme_stylebox_override("panel", Style.box(cols[k % cols.size()], 3, 0, 0))
			r.size = Vector2(rng.randf_range(9, 15), rng.randf_range(14, 22))
			p = r
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx_layer.add_child(p)
		var x0 := vs.x * 0.5 + rng.randf_range(-60, 60)
		var y0 := vs.y * 0.3 + rng.randf_range(-20, 20)
		p.position = Vector2(x0, y0)
		p.pivot_offset = p.size * 0.5
		p.rotation = rng.randf_range(0, TAU)
		var vx := rng.randf_range(-330, 330)
		var up := rng.randf_range(260, 560)
		var dur := rng.randf_range(1.5, 2.3)
		var tw := p.create_tween().set_parallel(true)
		tw.tween_method(_confetti_step.bind(p, Vector2(x0, y0), Vector2(vx, -up)), 0.0, dur, dur)
		tw.tween_property(p, "rotation", p.rotation + rng.randf_range(-8, 8), dur)
		tw.tween_property(p, "modulate:a", 0.0, 0.4).set_delay(dur - 0.4)
		tw.chain().tween_callback(p.queue_free)


func _confetti_step(t: float, p: Control, p0: Vector2, v0: Vector2) -> void:
	p.position = p0 + v0 * t + Vector2(0, 620.0) * t * t


func _on_day_lost(info: Dictionary) -> void:
	_playing = false
	_tut = 0
	_unlock_input()
	_end_gen += 1
	_hide_lane()
	ui._hide_finger()
	get_tree().create_timer(1.1 if str(info.get("why", "")) == "war" else 0.7).timeout.connect(_show_fail.bind(info, _end_gen))


func _show_fail(info: Dictionary, gen: int) -> void:
	if gen != _end_gen:
		return
	var why := str(info.get("why", "twists"))
	var target := int(info.get("target", 0))
	var prog := int(info.get("progress", 0))
	# „Fast geschafft!“ nur, wenn es auch stimmt (mindestens die Hälfte des Ziels)
	var close := target > 0 and prog * 2 >= target
	var try_title := str(Days.TEXT["lost_close"] if close else Days.TEXT["lost_try"])
	fc_body.text = str(Days.TEXT["lost_body"])
	if why == "war":
		fc_caps.text = "Krieg!"
		fc_title.text = str(Days.TEXT["lost_war"])
		fc_body.text = str(Days.TEXT["lost_war_body"])
		ui._set_tile(fc_tile, "swords", Style.FIRE_TINT)
	elif why == "fire":
		fc_caps.text = "Feuer"
		fc_title.text = try_title
		ui._set_tile(fc_tile, "fire", Style.FIRE_TINT)
	else:
		fc_caps.text = str(Days.TEXT["lost_twists"])
		fc_title.text = try_title
		ui._set_tile(fc_tile, "round", Style.SUN_TINT)
	var gi := _goal_icon(info)
	ui._set_tile(fc_progress_tile, gi, ui._tint_for_icon(gi))
	var noun := _goal_noun(Game.state)
	fc_progress.text = "%d/%d %s" % [mini(prog, target), target, noun]
	var mercy := int(info.get("mercy_next", 0))
	fc_mercy.visible = mercy > 0
	fc_mercy.text = str(Days.TEXT["mercy_next"]) % mercy
	# Der Charakter erschrickt kurz – und macht dann Mut (nie traurig über den Spieler)
	fc_body.text = Voice.line("fail_war" if why == "war" else "fail")
	var cvf := ui.speaker_view(fc_char)
	cvf.set_look(ui.char_look())
	cvf.set_expression("worried", 0.7)
	cvf.react("shake")
	(fc_tile as Control).visible = true
	ui._open_modal(fail_card, false)
	fc_tile.pivot_offset = fc_tile.custom_minimum_size * 0.5
	ui._shake(fc_tile)


## Hauptknopf der Sieg-Karte: „Weiterbauen“ oder „Weiter zu Tag n“.
func _on_win_next() -> void:
	_leave_win(str(wc_next.get_meta("act", "build")))


func _on_win_alt() -> void:
	_leave_win(str(wc_alt.get_meta("act", "again")))


func _on_win_home() -> void:
	_leave_win("home")


## Die Sieg-Karte verlassen. Darf der Charakter jetzt fragen, ob er morgen erinnern soll (5.7), kommt erst die Frage.
func _leave_win(act: String) -> void:
	if _ask_due():
		_open_ask(_win_action.bind(act))
		return
	_win_action(act)


func _win_action(act: String) -> void:
	match act:
		"build":
			ui._close_modal(true)
			if not Game.continue_build():
				show_overview()
		"next":
			ui._close_modal(true)
			if not Game.start_day(int(wc_next.get_meta("next", 0))):
				show_overview()          # der nächste Tag kommt erst morgen (Game.locked_text)
		"again":
			Game.retry_day()
		"free":
			ui._close_modal(true)
			show_overview()
			_open_free()
		_:
			show_overview()


## Weiterbauen beginnt (Sieg-Karte oder Übersicht): zurück ins Spiel, der Charakter sagt einmal, was jetzt gilt.
func _on_build_started(info: Dictionary) -> void:
	hide_overview()
	ui._close_modal(true)
	_info = info
	_hold = {}
	_playing = true
	_tut = 0
	_unlock_input()
	_last_left = -1
	ui.refresh()
	if not ui.dock.visible:
		ui._dock_in(0.1)
	if not _build_said:
		_build_said = true
		get_tree().create_timer(0.4).timeout.connect(_show_lane.bind(Voice.line("weiterbauen"), str(Days.TEXT["build"]), "check",
			Style.LEAF_TINT, 5.0, Voice.face("weiterbauen")))


# --- Erinnern? Der Charakter fragt, bevor Android fragt (5.7) -------------------------------------

func _ask_due() -> bool:
	if not (Notifier.is_supported() or (debug_ask_on_pc and OS.is_debug_build())):
		return false
	return Game.reminder_ask_due(Game.streak())


func _open_ask(then: Callable) -> void:
	_ask_then = then
	var nn := Game.next_new_day()
	var tag := str(Days.TEXT["day_title"]) % [nn, str(Days.config(nn).get("title", ""))] if nn <= Days.count() else str(Days.TEXT["wdt_tag"])
	ask_text.text = Voice.line("ask_reminder", {"tag": tag})
	ui._speak(ask_speaker, "happy", "bell" if Style.icon("bell") != null else "moon", Style.MONSOON_TINT)
	Game.note_reminder_asked()
	ui._open_modal(ask_card, false)


func _on_ask_answer(yes: bool) -> void:
	var then := _ask_then
	_ask_then = Callable()
	ui._close_modal(true)
	if yes and ui.notifier != null:
		ui.notifier.request_permission()
	Game.message.emit(Voice.line("ask_yes" if yes else "ask_no"), "good" if yes else "info")
	Game.replan_reminders()
	if then.is_valid():
		then.call()


func _on_again() -> void:
	Game.retry_day()


func _on_home() -> void:
	show_overview()


## Läuft gerade etwas, das Eingaben ins Spiel sperrt (Übersicht, Ziel-Karte, Ende des Tages)?
func blocking() -> bool:
	return is_open() or creator_open() or (Game.in_day() and not _playing)
