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


## Was an jedem Tag neu dazukommt und im Spiel an seinen Platz fliegt: [Symbol, Titel, Ziel].
const REVEAL = {2: ["rain", "Neu: Regen", "rain"], 3: ["animals", "Neu: Leben", "chip"], 4: ["hut", "Neu: Menschen", "chip"],
	5: ["field", "Neu: Du entscheidest!", "chip"], 6: ["church", "Neu: Glaube", "chip"], 7: ["strike", "Neu: Gewitter", "strike"]}
## Wo die erste Hinweis-Zeile eines Tages hinzeigt ("" = in der Spur unter der Kopfzeile).
const COACH_AT = {2: "rain"}
const TILE_W := 129.0
const TILE_H := 178.0

var ui: GameUI

# --- Übersicht ---
var overview: Control
var ov_tiles: Array = []          # je Tag: {"btn", "icon", "stars": [TextureRect×3], "lock", "title", "caps"}
var ov_stars: Label
var ov_play: Button
var ov_free: Button
var ov_banner: PanelContainer
var ov_box: VBoxContainer

# --- Karten ---
var goal_card: PanelContainer
var gc_caps: Label
var gc_intro: Label
var gc_goal_tile: PanelContainer
var gc_goal: Label
var gc_limit: Label
var gc_rule: PanelContainer
var gc_rule_label: Label
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
var wc_next: Button
var wc_again: Button
var wc_home: Button

var fail_card: PanelContainer
var fc_tile: PanelContainer
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
var rule_tag: PanelContainer

# --- Hinweis-Zeile (Spur) ---
var lane: PanelContainer
var lane_tile: PanelContainer
var lane_caps: Label
var lane_label: Label
var _lane_until := INF

var fx_layer: Control

# --- Zustand ---
var _info: Dictionary = {}          # day_info() beim Start des Versuchs
var _hold: Dictionary = {}          # Dinge, die erst nach „Los!“ an ihren Platz fliegen ("rain", "scale", "strike", "hint", "dock")
var _playing := false               # „Los!“ getippt, der Tag läuft
var _tut := 0                       # Tag 1 (Tutorial-Brett): 0 aus, 1 Hand zeigt den Zug, 2 „Jetzt du!“, 3 fertig
var _tut_at := 0.0
var _demo_at := INF
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
	fx_layer = Control.new()
	fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.root.add_child(fx_layer)
	ui.root.move_child(ui.tip_card, -1)        # Erklärungen bleiben ganz oben
	Game.day_started.connect(_on_day_started)
	Game.day_progress.connect(_on_day_progress)
	Game.day_won.connect(_on_day_won)
	Game.day_lost.connect(_on_day_lost)
	Game.new_game_started.connect(_on_new_game)
	Game.move_done.connect(_on_move_done)
	Game.choice_made.connect(_on_choice_made)
	Game.choice_needed.connect(_on_choice_needed)
	Game.round_resolved.connect(_on_round)


## Beim Start der App: Erster Start → gleich Tag 1 (Ziel-Karte). Sonst die Übersicht.
func startup() -> void:
	if Game.in_day() and Game.first_launch:
		Game.first_launch = false
		_on_day_started.call_deferred(Game.day_info())
		return
	show_overview(false)


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
	var rv := ui._vbox(0)
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(rv)
	ring = TwistRing.new()
	rv.add_child(ring)
	ring_caps = ui._caps("Drehungen")
	ring_caps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(ring_caps)
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
	lane_tile = ui._tile("meadow", 48, Style.LEAF_TINT)
	lane_tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(lane_tile)
	var v := ui._vbox(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	lane_caps = ui._caps("Du bist dran", Style.LEAF_DEEP)
	v.add_child(lane_caps)
	lane_label = ui._label("", 19, Style.INK, Style.W_BOLD)
	lane_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lane_label.custom_minimum_size = Vector2(Style.CONTENT_W - 36 - 48 - 14, 0)
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
	# Oben: Menü (Einstellungen) und die Sterne
	var topbar := ui._hbox(0)
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
	var sc := PanelContainer.new()
	sc.add_theme_stylebox_override("panel", ui._chip_style(Style.GLASS, 24))
	sc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	topbar.add_child(sc)
	var sh := ui._hbox(8)
	sc.add_child(sh)
	sh.add_child(ui._icon("star", 26))
	ov_stars = ui._label("0/21", 18, Style.INK, Style.W_BLACK)
	ov_stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sh.add_child(ov_stars)
	ui._explain_only(sc, "day_stars")
	# Mitte: Titel, 4 + 3 Kacheln, „Spielen“, „Freies Spiel“
	ov_box = ui._vbox(18)
	ov_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ov_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ov_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	ov_box.custom_minimum_size = Vector2(Style.CONTENT_W, 0)
	overview.add_child(ov_box)
	ov_banner = PanelContainer.new()
	ov_banner.add_theme_stylebox_override("panel", Style.box(Style.SUN_TINT, 18, 14, 6))
	ov_banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ov_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := ui._caps(str(Days.TEXT["banner_new"]), Style.SUN_DEEP)
	ov_banner.add_child(bl)
	ov_banner.visible = false
	ov_box.add_child(ov_banner)
	var tv := ui._vbox(2)
	ov_box.add_child(tv)
	var t1 := ui._label("Die Schöpfung", 40, Style.INK, Style.W_BLACK)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t1)
	var t2 := ui._caps("in 7 Tagen", Style.SUN_DEEP)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.add_theme_font_size_override("font_size", 15)
	tv.add_child(t2)
	var sub := ui._label("Erschaffe deine Welt – Tag für Tag.", 17, Style.INK_2, Style.W_BODY)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov_box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov_box.add_child(gap)
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
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 8)
	gap2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov_box.add_child(gap2)
	ov_play = ui._button("Spielen", "primary", "play", 64)
	ov_play.add_theme_font_size_override("font_size", 20)
	ov_play.pressed.connect(_on_play_pressed)
	ov_box.add_child(ov_play)
	ov_free = ui._button(str(Days.TEXT["free"]), "secondary", "trophy", 58)
	ui._tap_or_explain(ov_free, _on_free_pressed, "day_free", false)
	ov_box.add_child(ov_free)
	ui.root.add_child(overview)
	ui.root.move_child(overview, ui.modal_bg.get_index())


func _day_tile(n: int) -> Button:
	var cfg := Days.config(n)
	var b := Button.new()
	b.custom_minimum_size = Vector2(TILE_W, TILE_H)
	b.focus_mode = Control.FOCUS_NONE
	var nsb := Style.lift(Style.box(Style.SURFACE, 24, 8, 8), 1)
	Style.skin(b, nsb, Style.box(Style.SURFACE_3, 24, 8, 8), Style.INK)
	b.set_meta("sb", nsb)
	ui._tap_or_explain(b, _on_tile.bind(n), "day_tile_%d" % n)
	var v := ui._vbox(6)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 14
	v.offset_bottom = -14
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(v)
	var caps := ui._caps(str(Days.TEXT["day"]) % n)
	caps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(caps)
	var icon_name := str(cfg.get("icon", "meadow"))
	var tl := ui._tile(icon_name, 62, ui._tint_for_icon(icon_name), 0.32)
	tl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(tl)
	var title := ui._label(str(cfg.get("title", "")), 16, Style.INK, Style.W_BOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sr := ui._hbox(2)
	sr.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(sr)
	var stars: Array = []
	for i in 3:
		var s := ui._icon("star_empty", 20)
		sr.add_child(s)
		stars.append(s)
	var lock := ui._icon("lock", 22)
	lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sr.add_child(lock)
	ov_tiles.append({"btn": b, "tile": tl, "stars": stars, "lock": lock, "title": title, "caps": caps, "icon": icon_name})
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
	gc_intro = _center(ui._label("", 19, Style.INK_2, Style.W_BODY))
	v.add_child(gc_intro)
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
	# Regel (Tag 6: „Kein Krieg!“)
	gc_rule = PanelContainer.new()
	gc_rule.add_theme_stylebox_override("panel", Style.box(Style.FIRE_TINT, 18, 14, 6))
	gc_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	gc_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rh := ui._hbox(8)
	gc_rule.add_child(rh)
	rh.add_child(ui._icon("swords", 22))
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
	wc_title = _center(ui._label("", 30, Style.INK, Style.W_BLACK))
	v.add_child(wc_title)
	wc_row = ui._hbox(10)
	wc_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(wc_row)
	for i in 3:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(76, 76)
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
	wc_used = _center(ui._label("", 17, Style.INK_2, Style.W_LABEL))
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
	var acts := ui._vbox(10)
	v.add_child(acts)
	wc_next = ui._button("Weiter", "primary", "", 62)
	wc_next.add_theme_font_size_override("font_size", 20)
	wc_next.pressed.connect(_on_win_next)
	acts.add_child(wc_next)
	var row := ui._hbox(10)
	acts.add_child(row)
	wc_again = ui._button(str(Days.TEXT["again"]), "secondary", "", 54)
	wc_again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wc_again.pressed.connect(_on_again)
	row.add_child(wc_again)
	wc_home = ui._button("Alle Tage", "secondary", "", 54)
	wc_home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wc_home.pressed.connect(_on_home)
	row.add_child(wc_home)


func _build_fail_card() -> void:
	var cv := _card()
	fail_card = cv[0]
	var v: VBoxContainer = cv[1]
	fc_tile = ui._tile("round", 84, Style.SURFACE_2, 0.5)
	fc_tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(fc_tile)
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
	var home := ui._button("Alle Tage", "ghost", "", 50)
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
	ui._hide_finger()
	_fill_overview()
	ui.top.visible = false
	ui.dock.visible = false
	overview.visible = true
	overview.modulate.a = 1.0
	if animate:
		overview.modulate.a = 0.0
		var tw := ui._fx(overview, "v")
		tw.tween_property(overview, "modulate:a", 1.0, 0.25)
	var tiles: Array = []
	for t in ov_tiles:
		tiles.append((t as Dictionary)["btn"])
	ui._stagger_in(tiles, Vector2.ZERO, 0.86, 0.05)
	_pulse_current()


func hide_overview() -> void:
	if not overview.visible:
		return
	overview.visible = false
	ui.top.visible = true
	ui._home_top()
	for t in ov_tiles:
		ui._pulse((t as Dictionary)["btn"], false)


func _fill_overview() -> void:
	var cur := Game.current_day()
	var all_done := Game.world_done
	for i in ov_tiles.size():
		var n := i + 1
		var t: Dictionary = ov_tiles[i]
		var open := Game.day_unlocked(n)
		var st := Game.stars_of(n)
		var b: Button = t["btn"]
		var sb: StyleBoxFlat = b.get_meta("sb")
		var is_cur := open and n == cur and not (all_done and st == 3)
		sb.bg_color = Style.SURFACE if open else Color(Style.SURFACE_2, 0.9)
		sb.border_color = Style.SUN
		sb.set_border_width_all(3 if is_cur else 0)
		var stars: Array = t["stars"]
		for k in 3:
			var s: TextureRect = stars[k]
			s.visible = open
			s.texture = Style.icon("star" if k < st else "star_empty")
		(t["lock"] as Control).visible = not open
		var tl: PanelContainer = t["tile"]
		ui._set_tile(tl, str(t["icon"]), ui._tint_for_icon(str(t["icon"])) if open else Style.SURFACE_3)
		(tl.get_child(0) as Control).modulate = Color(1, 1, 1, 1.0 if open else 0.35)
		(t["title"] as Label).add_theme_color_override("font_color", Style.INK if open else Style.INK_3)
		(t["caps"] as Label).add_theme_color_override("font_color", Style.SUN_DEEP if is_cur else Style.INK_3)
		b.set_meta("current", is_cur)
	ov_stars.text = "%d/%d" % [Game.stars_total(), Game.stars_max()]
	ov_play.text = ("Tag %d spielen" % cur) if not all_done else "Freies Spiel"
	var free_ok := Game.free_play_unlocked()
	ov_free.text = str(Days.TEXT["free"]) if free_ok else "%s · %s" % [str(Days.TEXT["free"]), str(Days.TEXT["free_locked"])]
	ov_free.icon = Style.icon("trophy" if free_ok else "lock")
	ov_free.modulate.a = 1.0 if free_ok else 0.6
	ov_free.visible = not all_done
	ov_banner.visible = Game.tutorial_done and Game.stars_total() == 0
	if all_done:
		ov_play.icon = Style.icon("trophy")
	else:
		ov_play.icon = Style.icon("play")


func _pulse_current() -> void:
	for t in ov_tiles:
		var b: Button = (t as Dictionary)["btn"]
		ui._pulse(b, false)
		if bool(b.get_meta("current", false)):
			get_tree().create_timer(0.5).timeout.connect(ui._pulse.bind(b, true))


func _on_tile(n: int) -> void:
	if not Game.day_unlocked(n):
		var t: Dictionary = ov_tiles[n - 1]
		ui._shake(t["lock"])
		Style.haptic(Style.HAPTIC_TAP)
		ui._show_tooltip(t["btn"], "lock", str(Days.TEXT["day_title"]) % [n, str(Days.config(n).get("title", ""))],
			str(Days.TEXT["locked"]) % mini(Game.day_free, Days.count()))
		ui._tip_hide_at = ui._time + 2.4
		return
	ui.ask_day(n)


func _on_play_pressed() -> void:
	if Game.world_done and Game.current_day() == Days.count() and Game.stars_of(Days.count()) > 0:
		_on_free_pressed()
		return
	ui.ask_day(Game.current_day())


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
	if not Game.in_day() or Game.over:
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
	gc_intro.text = str(info.get("intro", ""))
	var gi := _goal_icon(info)
	ui._set_tile(gc_goal_tile, gi, ui._tint_for_icon(gi))
	gc_goal.text = str(info.get("goal_text", ""))
	gc_limit.text = Days.limit_line(int(info.get("limit", 0)))
	var rule := str(info.get("rule_line", ""))
	gc_rule.visible = rule != ""
	gc_rule_label.text = rule
	var nw: Dictionary = info.get("new", {})
	gc_new.visible = not nw.is_empty() and n > 1
	if gc_new.visible:
		var ic := str(nw.get("icon", "star"))
		ui._set_tile(gc_new_tile, ic, Style.SURFACE)
		gc_new_title.text = str(nw.get("title", ""))
		gc_new_text.text = str(nw.get("text", ""))
	var st: Array = info.get("stars", [0, 0])
	gc_star_label.text = Days.limit_line(int(st[0]))
	var mercy := int(info.get("mercy", 0))
	gc_mercy.visible = mercy > 0
	gc_mercy.text = str(Days.TEXT["mercy"]) % mercy


func _on_go() -> void:
	ui._close_modal()
	_playing = true
	_tut_at = ui._time
	var n := int(_info.get("day", 0))
	if Game.day_tutorial():
		_tut = 1
		_tut_misses = 0
		_demo_at = ui._time + 0.9
		var c: Array = _info.get("coach", [])
		_show_lane(str(c[0]) if not c.is_empty() else "", "Du bist dran", "touch", Style.LEAF_TINT, INF)
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
	var tool_text := str(Game.state.day.get("coach_tool", ""))
	if at == "rain" and tool_text != "" and ui.rain_btn.is_visible_in_tree():
		# Oben die Aufgabe (wie wächst das Ziel?), unten am Regen das Neue
		_show_lane(str(c[0]), "Deine Aufgabe", _goal_icon(_info), ui._tint_for_icon(_goal_icon(_info)), 7.0)
		ui._place_coach(ui.rain_btn, "rain", tool_text)
		ui._coach_until = ui._time + 6.0
		return
	var nw: Dictionary = _info.get("new", {})
	var ic := str(nw.get("icon", "info"))
	_show_lane(str(c[0]), "Neu heute", ic, ui._tint_for_icon(ic), 7.0)


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
			_show_lane(str(c[1]), "Achtung", "fire", Style.FIRE_TINT, 6.0)
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
		# Die erste Wiese nicht verpassen: Die Kamera dreht zu ihr (liegt sie auf einer Seite, schräg von oben)
		if _goal_field >= 0:
			ui.world.focus_field(_goal_field)
		var c: Array = _info.get("coach", [])
		_show_lane(str(c[1]) if c.size() > 1 else "", "", "meadow", Style.LEAF_TINT, 2.4)
		get_tree().create_timer(2.6).timeout.connect(_tut_your_turn.bind(_end_gen))
	elif _tut == 2 and p >= 2:
		_tut = 3
		var c2: Array = _info.get("coach", [])
		_show_lane(str(c2[3]) if c2.size() > 3 else "", "", "check", Style.LEAF_TINT, 2.8)


func _tut_your_turn(gen: int) -> void:
	if gen != _end_gen or not Game.in_day() or Game.over:
		return
	_hold.erase("dock")
	ui.refresh()
	if not ui.dock.visible:
		ui._dock_in(0.0)
	if _tut != 2:
		return
	var c: Array = _info.get("coach", [])
	_show_lane(str(c[2]) if c.size() > 2 else "", "Du bist dran", "meadow", Style.LEAF_TINT, INF)


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
		if Game.tutorial_move().is_empty():
			_show_lane("Tipp auf „Tipp“ – dann leuchtet eine gute Reihe.", "Du bist dran", "bulb", Style.LEAF_TINT, INF)
		else:
			_show_lane("Fast! Wisch über die leuchtende Reihe.", "Du bist dran", "touch", Style.LEAF_TINT, INF)
		_demo_at = ui._time + 1.0
	elif lane.visible and _lane_until == INF and _tut != 1 and _tut != 2:
		_hide_lane()
	elif lane.visible and _tut == 0 and _lane_until != INF:
		_lane_until = minf(_lane_until, ui._time + 1.5)


## Ein Zug wird ausgewertet: Eine Hinweis-Zeile mit Zeit macht Platz für das, was jetzt passiert (Jubel, Krieg …).
## Die Zeilen des Tutorials (ohne Zeit) bleiben.
func _on_round(result: Dictionary, _before: Dictionary) -> void:
	if lane.visible and _lane_until != INF:
		_hide_lane()
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

func _show_lane(text: String, caps: String, icon_name: String, tint: Color, hold: float) -> void:
	if text == "":
		return
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
	if not _playing or not Game.in_day() or Game.over:
		return
	if _tut == 1:
		# Die Hand zeigt den Zug (immer wieder), bis man selbst dreht. Dreht man lange nicht, dreht er sich selbst.
		var w := ui.world
		if ui._time >= _demo_at and w._idle > 0.8 and not ui._twisting and not w.animating and not Game.busy and not ui.modal_bg.visible:
			_demo_at = ui._time + 4.2
			var demo := Game.tutorial_move()      # nur ein Zug, der auch etwas wachsen lässt
			if not demo.is_empty():
				ui._play_demo(demo)
		if Game.state.twists == 0 and ui._time - _tut_at > 16.0 and not ui._twisting and not w.animating and not Game.busy:
			var mv := Game.tutorial_move()
			if not mv.is_empty() and w.auto_twist(int(mv["axis"]), int(mv["layer"]), int(mv["turns"])):
				ui._hide_finger()
				_demo_at = INF


## Halten: Erklärungen für den Ziel-Chip, die Kacheln und „Kein Krieg!“.
func tooltip(key: String) -> Dictionary:
	if key == "day_goal":
		if not Game.in_day():
			return {}
		var info := Game.day_info()
		var left := Game.state.twists_left()
		var body := "%s. %s" % [str(info.get("goal_text", "")), str(Days.TEXT["left"]) % left]
		var st: Dictionary = info.get("status", {})
		if bool(st.get("need_green", false)):
			body += " Grün ist die Mitte der Weltwaage."
		return {"icon": _goal_icon(info), "title": "Deine Aufgabe", "body": body}
	if key == "day_rule":
		return {"icon": "swords", "title": "Kein Krieg!", "body": "Bring nie zwei Kirchen durch eine Drehung zusammen. Ein Krieg beendet den Tag."}
	if key == "day_stars":
		return {"icon": "star", "title": "Sterne", "body": "Je weniger Drehungen du für einen Tag brauchst, desto mehr Sterne. Du hast %d von %d." % [Game.stars_total(), Game.stars_max()]}
	if key == "day_free":
		return {"icon": "trophy", "title": str(Days.TEXT["free"]), "body": "Bau deine Welt weiter, bis sie vollendet ist: Einfach, Mittel, Schwer oder 40 Drehungen. Geht nach Tag 7 auf."}
	if key.begins_with("day_tile_"):
		var n := int(key.substr(9))
		var cfg := Days.config(n)
		var title := str(Days.TEXT["day_title"]) % [n, str(cfg.get("title", ""))]
		if not Game.day_unlocked(n):
			return {"icon": "lock", "title": title, "body": str(Days.TEXT["locked"]) % mini(Game.day_free, Days.count())}
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
	_end_gen += 1
	_hide_lane()
	ui._hide_finger()
	get_tree().create_timer(0.9).timeout.connect(_show_win.bind(info, _end_gen))


func _show_win(info: Dictionary, gen: int) -> void:
	if gen != _end_gen:
		return
	var n := int(info["day"])
	var complete := bool(info.get("world_complete", false))
	var nxt := int(info.get("next_day", 0))
	wc_title.text = str(Days.TEXT["complete"]) if complete else str(Days.TEXT["won"]) % n
	var used := int(info.get("used", 0))
	var three := int((Days.config(n).get("stars", [0, 0]) as Array)[0])
	if int(info.get("stars", 0)) < 3 and three > 0:
		wc_used.text = str(Days.TEXT["won_more"]) % [used, three]       # was der 3. Stern braucht
	else:
		wc_used.text = str(Days.TEXT["won_in"]) % used
	wc_days.visible = complete
	wc_total.visible = complete
	wc_free_line.visible = complete
	wc_total.text = str(Days.TEXT["stars_total"]) % [int(info.get("stars_total", 0)), int(info.get("stars_max", 21))]
	wc_row.visible = true
	if complete:
		wc_next.text = str(Days.TEXT["free"])
	elif nxt > 0:
		wc_next.text = str(Days.TEXT["next"]) % [nxt, str(Days.config(nxt).get("title", ""))]
	else:
		wc_next.text = "Alle Tage"
	wc_next.set_meta("next", nxt)
	wc_next.set_meta("complete", complete)
	wc_again.text = str(Days.TEXT["again"]) if int(info.get("stars", 0)) >= 3 else "%s · %s" % [str(Days.TEXT["again"]), "mehr Sterne"]
	for s in wc_stars:
		(s as Control).visible = false
	ui._open_modal(win_card, false)
	_confetti()
	var got := int(info.get("stars", 0))
	for i in got:
		get_tree().create_timer(0.45 + 0.28 * i).timeout.connect(_star_in.bind(i, gen))
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
	ui._open_modal(fail_card, false)
	fc_tile.pivot_offset = fc_tile.custom_minimum_size * 0.5
	ui._shake(fc_tile)


func _on_win_next() -> void:
	if bool(wc_next.get_meta("complete", false)):
		ui._close_modal(true)
		show_overview()
		_open_free()
		return
	var nxt := int(wc_next.get_meta("next", 0))
	if nxt > 0:
		Game.next_day()
	else:
		show_overview()


func _on_again() -> void:
	Game.retry_day()


func _on_home() -> void:
	show_overview()


## Läuft gerade etwas, das Eingaben ins Spiel sperrt (Übersicht, Ziel-Karte, Ende des Tages)?
func blocking() -> bool:
	return is_open() or (Game.in_day() and not _playing)
