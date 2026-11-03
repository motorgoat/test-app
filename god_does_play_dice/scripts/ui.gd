class_name GameUI
extends CanvasLayer
## Oberfläche (GDD Kap. 15): minimalistisch, mit einem Finger bedienbar.
## Handy: Würfel in der Mitte, oben eine schmale Leiste, unten Kasten, Status und Knöpfe.
## PC (breit): links Auswahl und Status, rechts Zentrum und Zeit.

const HUMAN := GameState.HUMAN
const WIDE_MIN := 900.0

const C_PANEL := Color(1.0, 0.98, 0.94, 0.94)
const C_TEXT := Color("#2d2a26")
const C_SOFT := Color("#6f685e")
const C_GREEN := Color("#3fa34d")
const C_GOLD := Color("#f2b705")
const C_RED := Color("#d8352a")
const C_GREY := Color("#d6d0c4")

var world: World

var root: Control
var top_res: Label
var top_dots: HBoxContainer
var bottom: VBoxContainer
var left_col: VBoxContainer
var right_col: VBoxContainer

var sel_panel: PanelContainer
var sel_title: Label
var sel_info: Label
var sel_btn: Button
var sel_reason: Label

var status_panel: PanelContainer
var status_label: Label

var center_panel: PanelContainer
var center_title: Label
var center_info: Label
var upgrade_btn: Button
var trade_btn: Button
var rotate_btn: Button
var queued_box: HBoxContainer

var time_panel: PanelContainer
var pause_btn: Button
var progress: ProgressBar
var skip_btn: Button

var rot_layer: Control
var arrow_btns: Array = []
var rot_panel: PanelContainer
var rot_info: Label
var rot_ok: Button

var bubble_layer: Control
var menu_panel: PanelContainer
var ai_option: OptionButton
var rules_panel: PanelContainer
var trade_panel: PanelContainer
var give_option: OptionButton
var get_option: OptionButton
var end_panel: PanelContainer
var end_label: Label

var selected := -1
var rotating := false
var _arrows: Array = []
var _bubbles: Array = []
var _status_text := ""
var _status_bad := false
var _status_until := 0.0
var _ai_text := ""
var _wide := false
var _time := 0.0


func setup(w: World) -> void:
	world = w
	_build()
	world.field_tapped.connect(_on_field_tapped)
	world.field_info.connect(_on_field_info)
	world.preview_changed.connect(_on_preview_changed)
	Game.state_changed.connect(refresh)
	Game.new_game_started.connect(_on_new_game)
	Game.tick_finished.connect(_on_tick_finished)
	Game.message.connect(_on_message)
	Game.ai_log.connect(func(t: String) -> void: _ai_text = t)
	Game.game_over.connect(_on_game_over)
	get_viewport().size_changed.connect(_layout)
	_layout()
	refresh()


# =============================================================================
# Aufbau
# =============================================================================

func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)

	# --- Obere Leiste ---
	var top := _panel()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 8)
	root.add_child(top)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 8)
	top.add_child(th)
	top_res = Label.new()
	top_res.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_res.clip_text = true
	th.add_child(top_res)
	top_dots = HBoxContainer.new()
	top_dots.add_theme_constant_override("separation", 4)
	th.add_child(top_dots)

	# --- Container für die Layouts ---
	bottom = VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 8)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 6)
	root.add_child(bottom)

	left_col = _column()
	left_col.anchor_left = 0.0
	left_col.anchor_right = 0.0
	left_col.offset_left = 8
	left_col.offset_right = 360
	root.add_child(left_col)
	right_col = _column()
	right_col.anchor_left = 1.0
	right_col.anchor_right = 1.0
	right_col.offset_left = -360
	right_col.offset_right = -8
	root.add_child(right_col)

	# --- Status ---
	status_panel = _panel()
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 15)
	status_panel.add_child(status_label)

	# --- Auswahl-Kasten ---
	sel_panel = _panel()
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	sel_panel.add_child(sv)
	var sh := HBoxContainer.new()
	sv.add_child(sh)
	sel_title = Label.new()
	sel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_title.add_theme_font_size_override("font_size", 19)
	sh.add_child(sel_title)
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.custom_minimum_size = Vector2(40, 36)
	close.pressed.connect(func() -> void: _select(-1))
	sh.add_child(close)
	sel_info = Label.new()
	sel_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sel_info.add_theme_color_override("font_color", C_SOFT)
	sel_info.add_theme_font_size_override("font_size", 15)
	sv.add_child(sel_info)
	sel_btn = Button.new()
	sel_btn.custom_minimum_size = Vector2(0, 54)
	sel_btn.add_theme_font_size_override("font_size", 18)
	_style_button(sel_btn, C_GREEN, Color.WHITE)
	sel_btn.pressed.connect(_press_action)
	sv.add_child(sel_btn)
	sel_reason = Label.new()
	sel_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sel_reason.add_theme_color_override("font_color", C_RED)
	sel_reason.add_theme_font_size_override("font_size", 15)
	sv.add_child(sel_reason)
	sel_panel.visible = false

	# --- Zentrum ---
	center_panel = _panel()
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	center_panel.add_child(cv)
	center_title = Label.new()
	center_title.add_theme_font_size_override("font_size", 17)
	cv.add_child(center_title)
	center_info = Label.new()
	center_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_info.add_theme_color_override("font_color", C_SOFT)
	center_info.add_theme_font_size_override("font_size", 14)
	cv.add_child(center_info)
	var cb := HBoxContainer.new()
	cb.add_theme_constant_override("separation", 6)
	cv.add_child(cb)
	upgrade_btn = Button.new()
	upgrade_btn.custom_minimum_size = Vector2(0, 46)
	upgrade_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(upgrade_btn, C_GOLD, C_TEXT)
	upgrade_btn.pressed.connect(func() -> void: Game.stage_up())
	cb.add_child(upgrade_btn)
	trade_btn = Button.new()
	trade_btn.text = "⇄ Tausch"
	trade_btn.custom_minimum_size = Vector2(0, 46)
	trade_btn.pressed.connect(_open_trade)
	cb.add_child(trade_btn)
	rotate_btn = Button.new()
	rotate_btn.custom_minimum_size = Vector2(0, 46)
	rotate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotate_btn.pressed.connect(_start_rotate)
	cb.add_child(rotate_btn)
	queued_box = HBoxContainer.new()
	queued_box.add_theme_constant_override("separation", 6)
	cv.add_child(queued_box)

	# --- Zeit ---
	time_panel = _panel()
	var tb := HBoxContainer.new()
	tb.add_theme_constant_override("separation", 6)
	time_panel.add_child(tb)
	pause_btn = Button.new()
	pause_btn.custom_minimum_size = Vector2(46, 40)
	pause_btn.pressed.connect(_toggle_pause)
	tb.add_child(pause_btn)
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.max_value = 1.0
	progress.step = 0.001
	progress.custom_minimum_size = Vector2(60, 14)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tb.add_child(progress)
	skip_btn = Button.new()
	skip_btn.text = "⏭"
	skip_btn.tooltip_text = "Takt sofort beenden"
	skip_btn.custom_minimum_size = Vector2(46, 40)
	skip_btn.pressed.connect(func() -> void: Game.skip_tick())
	tb.add_child(skip_btn)
	var menu_btn := Button.new()
	menu_btn.text = "☰"
	menu_btn.custom_minimum_size = Vector2(46, 40)
	menu_btn.pressed.connect(_open_menu)
	tb.add_child(menu_btn)

	_build_rotate_overlay()
	bubble_layer = Control.new()
	bubble_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bubble_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bubble_layer)
	_build_menu()
	_build_rules()
	_build_trade()
	_build_end()


func _build_rotate_overlay() -> void:
	rot_layer = Control.new()
	rot_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rot_layer.visible = false
	root.add_child(rot_layer)
	var round_sb := _sb(Color(1, 1, 1, 0.85), 26, 4, Color("#2d2a26"))
	for i in 12:
		var b := Button.new()
		b.custom_minimum_size = Vector2(52, 52)
		b.size = Vector2(52, 52)
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_stylebox_override("normal", round_sb)
		b.add_theme_stylebox_override("hover", _sb(Color(1, 0.95, 0.75, 0.95), 26, 4, Color("#2d2a26")))
		b.add_theme_stylebox_override("pressed", _sb(C_GOLD, 26, 4, Color("#2d2a26")))
		b.pressed.connect(_on_arrow.bind(i))
		rot_layer.add_child(b)
		arrow_btns.append(b)
	rot_panel = _panel()
	rot_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 8)
	rot_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	rot_layer.add_child(rot_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	rot_panel.add_child(v)
	rot_info = Label.new()
	rot_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(rot_info)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var back := Button.new()
	back.text = "Zurück"
	back.custom_minimum_size = Vector2(0, 50)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_rotate_back)
	h.add_child(back)
	rot_ok = Button.new()
	rot_ok.text = "Vormerken"
	rot_ok.custom_minimum_size = Vector2(0, 50)
	rot_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(rot_ok, C_GREEN, Color.WHITE)
	rot_ok.pressed.connect(_rotate_ok)
	h.add_child(rot_ok)


func _build_menu() -> void:
	menu_panel = _popup("God does play dice!")
	var v: VBoxContainer = menu_panel.get_child(0)
	v.add_child(_popup_button("Weiter", func() -> void: _close_popups()))
	v.add_child(_popup_button("Regeln", _show_rules))
	var hb := HBoxContainer.new()
	var l := Label.new()
	l.text = "KI-Länder:"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	ai_option = OptionButton.new()
	for i in range(1, 6):
		ai_option.add_item(str(i), i)
	hb.add_child(ai_option)
	v.add_child(hb)
	v.add_child(_popup_button("Neu starten", _restart_from_menu))


func _build_rules() -> void:
	rules_panel = _popup("Regeln")
	var v: VBoxContainer = rules_panel.get_child(0)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(300, 0)
	rt.add_theme_color_override("default_color", C_TEXT)
	rt.text = _rules_text()
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(320, 360)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(rt)
	v.add_child(sc)
	v.add_child(_popup_button("Schließen", func() -> void: _close_popups()))


func _rules_text() -> String:
	return ("Der Würfel ist die Welt. Jede Seite ist ein Land. Du bist [b]Gelb[/b] (oben).\n\n"
		+ "[b]Gold[/b] kommt von selbst: je Zentrum-Stufe und je Feld-Stufe.\n\n"
		+ "[b]Feld antippen[/b] wählt es aus. Der große Knopf baut es aus (kostet 1 Bewohner, Gold und Holz) "
		+ "oder kauft ein freies Nachbarfeld. Nochmal antippen = Knopf drücken.\n\n"
		+ "[b]Dein Zentrum antippen[/b]: Bewohner kaufen.\n\n"
		+ "[b]Zentrum ausbauen[/b] (Zelt → Haus → Marktplatz → Kaserne → Werkstatt): Der goldene Knopf erscheint, "
		+ "sobald es geht. Felder können nie höher sein als dein Zentrum. Jeder Ausbau bringt [b]1 Drehung[/b].\n\n"
		+ "[b]Drehen[/b]: „Drehung vormerken“, Pfeil tippen, „Vormerken“. Alle Drehungen passieren am Ende des Takts. "
		+ "Besitz hängt am Platz: Was auf deine Seite dreht, gehört dir, mit Ausbau.\n\n"
		+ "[b]Sieg[/b]: Wer zuerst %d Felder hat. Sonst nach %d Takten, wer die meisten hat.\n\n"
		+ "[b]Ansicht[/b]: Ziehen dreht, Tipp neben den Würfel dreht um eine Seite, Mausrad/zwei Finger zoomen, "
		+ "langes Drücken zeigt die Feldinfo.") % [Balance.WIN_FIELDS, Balance.TIME_LIMIT_TICKS]


func _build_trade() -> void:
	trade_panel = _popup("Tausch %d:1" % Balance.TRADE_RATE)
	var v: VBoxContainer = trade_panel.get_child(0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	give_option = OptionButton.new()
	get_option = OptionButton.new()
	for i in GameState.RES_KEYS.size():
		var k: String = GameState.RES_KEYS[i]
		give_option.add_item("%d %s %s" % [Balance.TRADE_RATE, GameState.RES_ICON[k], GameState.RES_NAME[k]], i)
		get_option.add_item("1 %s %s" % [GameState.RES_ICON[k], GameState.RES_NAME[k]], i)
	give_option.select(1)
	get_option.select(2)
	h.add_child(give_option)
	var arrow := Label.new()
	arrow.text = "→"
	h.add_child(arrow)
	h.add_child(get_option)
	v.add_child(h)
	var go := _popup_button("Tauschen", _do_trade)
	_style_button(go, C_GREEN, Color.WHITE)
	v.add_child(go)
	v.add_child(_popup_button("Schließen", func() -> void: _close_popups()))


func _build_end() -> void:
	end_panel = _popup("Spielende")
	var v: VBoxContainer = end_panel.get_child(0)
	end_label = Label.new()
	end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_label.custom_minimum_size = Vector2(300, 0)
	v.add_child(end_label)
	v.add_child(_popup_button("Neu starten", _restart))


# --- Bausteine ---------------------------------------------------------------

func _sb(bg: Color, radius: int = 12, pad: int = 8, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad + 4
	s.content_margin_right = pad + 4
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	if border.a > 0.0:
		s.set_border_width_all(2)
		s.border_color = border
	return s


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	t.set_stylebox("panel", "PanelContainer", _sb(C_PANEL, 14, 8))
	t.set_color("font_color", "Label", C_TEXT)
	for tname in ["Button", "OptionButton"]:
		t.set_stylebox("normal", tname, _sb(Color("#ffffff"), 12, 6, Color("#ddd5c6")))
		t.set_stylebox("hover", tname, _sb(Color("#fff7e2"), 12, 6, Color("#d6c9ad")))
		t.set_stylebox("pressed", tname, _sb(Color("#f3e6c6"), 12, 6, Color("#cbb98f")))
		t.set_stylebox("disabled", tname, _sb(Color("#eeeae2"), 12, 6, Color("#e2ddd2")))
		t.set_stylebox("focus", tname, StyleBoxEmpty.new())
		t.set_color("font_color", tname, C_TEXT)
		t.set_color("font_hover_color", tname, C_TEXT)
		t.set_color("font_pressed_color", tname, C_TEXT)
		t.set_color("font_focus_color", tname, C_TEXT)
		t.set_color("font_disabled_color", tname, Color("#a39c90"))
	t.set_stylebox("background", "ProgressBar", _sb(Color("#e6dfd1"), 7, 0))
	t.set_stylebox("fill", "ProgressBar", _sb(Color("#7cc06a"), 7, 0))
	return t


func _style_button(b: Button, bg: Color, fg: Color) -> void:
	b.add_theme_stylebox_override("normal", _sb(bg, 12, 6))
	b.add_theme_stylebox_override("hover", _sb(bg.lightened(0.12), 12, 6))
	b.add_theme_stylebox_override("pressed", _sb(bg.darkened(0.12), 12, 6))
	b.add_theme_stylebox_override("disabled", _sb(C_GREY, 12, 6))
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_focus_color", fg)
	b.add_theme_color_override("font_disabled_color", Color("#8f887c"))


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


func _column() -> VBoxContainer:
	var c := VBoxContainer.new()
	c.anchor_top = 0.0
	c.anchor_bottom = 1.0
	c.offset_top = 70
	c.offset_bottom = -8
	c.alignment = BoxContainer.ALIGNMENT_END
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_theme_constant_override("separation", 6)
	return c


func _popup(title: String) -> PanelContainer:
	var p := _panel()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.custom_minimum_size = Vector2(300, 0)
	p.add_child(v)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 22)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	root.add_child(p)
	return p


func _popup_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(cb)
	return b


# =============================================================================
# Layout
# =============================================================================

func _layout() -> void:
	var vs := root.get_viewport_rect().size
	_wide = vs.x >= WIDE_MIN and vs.x > vs.y
	for c in [status_panel, sel_panel, center_panel, time_panel]:
		var ctl := c as Control
		if ctl.get_parent() != null:
			ctl.get_parent().remove_child(ctl)
	if _wide:
		left_col.add_child(status_panel)
		left_col.add_child(sel_panel)
		right_col.add_child(center_panel)
		right_col.add_child(time_panel)
		world.rig.cam.v_offset = 0.0
	else:
		bottom.add_child(status_panel)
		bottom.add_child(sel_panel)
		bottom.add_child(center_panel)
		bottom.add_child(time_panel)
		world.rig.cam.v_offset = -0.9
	left_col.visible = _wide and not rotating
	right_col.visible = _wide and not rotating
	bottom.visible = not _wide and not rotating


# =============================================================================
# Aktualisieren
# =============================================================================

func _process(delta: float) -> void:
	_time += delta
	progress.value = Game.tick_progress()
	# goldener Ausbau-Knopf pulsiert leicht
	if upgrade_btn.visible:
		upgrade_btn.modulate = Color(1, 1, 1).lerp(Color(1.15, 1.1, 0.8), 0.5 + 0.5 * sin(_time * 4.0))
	# Status-Meldung läuft ab
	if _status_text != "" and _time > _status_until:
		_status_text = ""
		_update_status()
	if rotating:
		_place_arrows()
	_update_bubbles(delta)


func refresh() -> void:
	if Game.state == null or root == null:
		return
	var gs := Game.state
	var me := Game.human()
	var inc := gs.income(HUMAN)
	var limit := ""
	if Balance.TIME_LIMIT_TICKS > 0:
		limit = "/%d" % Balance.TIME_LIMIT_TICKS
	top_res.text = "Takt %d%s   🪵%d  🪨%d  🌾%d  🪙%d (+%d)   👤%d   🌍%d/%d" % [
		gs.tick, limit,
		int(me.inv["wood"]), int(me.inv["stone"]), int(me.inv["food"]), int(me.inv["gold"]), int(inc["gold"]),
		me.residents, gs.territory(HUMAN), Balance.WIN_FIELDS]
	_refresh_dots()
	_refresh_center()
	_refresh_selection()
	pause_btn.text = "▶" if Game.paused else "⏸"
	_update_status()


func _refresh_dots() -> void:
	var gs := Game.state
	var active: Array = []
	for pl in gs.players:
		if pl.active:
			active.append(pl)
	if top_dots.get_child_count() != active.size():
		_clear(top_dots)
		for pl in active:
			var b := Button.new()
			b.custom_minimum_size = Vector2(36, 36)
			b.add_theme_font_size_override("font_size", 14)
			var border := Color("#2d2a26") if pl.human else Color(0, 0, 0, 0.25)
			var sb := _sb(pl.color, 18, 2, border)
			b.add_theme_stylebox_override("normal", sb)
			b.add_theme_stylebox_override("hover", sb)
			b.add_theme_stylebox_override("pressed", sb)
			b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			var fg := Color.BLACK if pl.color.get_luminance() > 0.55 else Color.WHITE
			b.add_theme_color_override("font_color", fg)
			b.add_theme_color_override("font_hover_color", fg)
			b.add_theme_color_override("font_pressed_color", fg)
			b.tooltip_text = pl.name
			b.pressed.connect(world.focus_player.bind(pl.id))
			b.set_meta("pid", pl.id)
			top_dots.add_child(b)
	for b in top_dots.get_children():
		if b.has_meta("pid"):
			(b as Button).text = str(gs.territory(int(b.get_meta("pid"))))


func _refresh_center() -> void:
	var gs := Game.state
	var me := Game.human()
	var icons := ["", "⛺", "🏠", "🏪", "🏰", "🛠"]
	center_title.text = "%s %s · Stufe %d/%d · Drehungen: %d" % [icons[me.stage], Balance.STAGE_NAMES[me.stage], me.stage, Balance.MAX_STAGE, me.rotations]
	if me.stage < Balance.MAX_STAGE:
		var nxt := me.stage + 1
		var info := "Nächster Ausbau: %s · %s" % [Balance.STAGE_NAMES[nxt], GameState.cost_text(GameState.stage_cost(nxt))]
		var wait := gs.stage_wait(HUMAN)
		if wait > 0:
			info += " · frühestens in %d %s" % [wait, "Takt" if wait == 1 else "Takten"]
		info += "\nBringt: " + GameState.stage_benefits(nxt)
		center_info.text = info
	else:
		center_info.text = "Höchste Stufe erreicht"
	var can_up := gs.stage_up_error(HUMAN) == "" and not Game.over
	upgrade_btn.visible = can_up
	if can_up:
		upgrade_btn.text = "Ausbau → %s" % Balance.STAGE_NAMES[me.stage + 1]
	else:
		upgrade_btn.modulate = Color.WHITE
	trade_btn.visible = me.stage >= Balance.MARKET_STAGE
	rotate_btn.text = "⟳ Drehung vormerken (%d)" % me.rotations
	rotate_btn.disabled = me.rotations <= 0 or Game.animating or Game.over
	_clear(queued_box)
	for q in Game.human_queue():
		var b := Button.new()
		b.text = "Vorgemerkt ⟳ ✕"
		b.tooltip_text = "Zurücknehmen"
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(Game.cancel_human_rotation.bind(q))
		queued_box.add_child(b)
	queued_box.visible = queued_box.get_child_count() > 0 or not Game.human_queue().is_empty()


func _refresh_selection() -> void:
	if selected < 0 or rotating:
		sel_panel.visible = false
		return
	var gs := Game.state
	var f: FieldData = gs.fields[selected]
	sel_panel.visible = true
	var owner_txt := "neutral"
	if f.owner == HUMAN:
		owner_txt = "dein Land"
	elif f.owner >= 0:
		owner_txt = gs.players[f.owner].name
	if f.is_center:
		var pl_txt := "Zentrum"
		if f.owner >= 0:
			pl_txt = "Zentrum von %s" % ("dir" if f.owner == HUMAN else gs.players[f.owner].name)
			pl_txt += " · %s" % Balance.STAGE_NAMES[gs.players[f.owner].stage]
		sel_title.text = pl_txt
		if f.home == HUMAN:
			sel_info.text = "Freie Bewohner: %d. Bewohner arbeiten auf deinen Feldern, wenn du sie ausbaust." % Game.human().residents
		else:
			sel_info.text = "Zentren drehen sich nie mit."
	else:
		sel_title.text = "%s %s · Stufe %d/%d" % [GameState.RES_ICON[GameState.TERRAIN_RES[f.terrain]], GameState.TERRAIN_NAME[f.terrain], f.level, Balance.MAX_FIELD_LEVEL]
		var y := gs.field_yield(f)
		var res: String = GameState.TERRAIN_RES[f.terrain]
		var yield_txt := "kein Ertrag (Stufe 0)"
		if f.level > 0:
			if res == "gold":
				yield_txt = "+%d%s pro Takt" % [int(y["gold"]), GameState.RES_ICON["gold"]]
			else:
				yield_txt = "+%d%s +%d%s pro Takt" % [int(y[res]), GameState.RES_ICON[res], int(y["gold"]), GameState.RES_ICON["gold"]]
		sel_info.text = "Besitz: %s · Ertrag: %s" % [owner_txt, yield_txt]
	var act := Game.describe_action(selected)
	var err: String = act["error"]
	sel_btn.visible = act["kind"] != "none"
	sel_btn.text = str(act["label"])
	sel_btn.disabled = err != "" or Game.over
	sel_reason.text = err
	sel_reason.visible = err != ""
	if act["kind"] == "none":
		sel_reason.add_theme_color_override("font_color", C_SOFT)
	else:
		sel_reason.add_theme_color_override("font_color", C_RED)


func _update_status() -> void:
	var t := _status_text
	var bad := _status_bad
	if t == "":
		bad = false
		if Game.over:
			t = "Spiel vorbei."
		elif Game.paused:
			t = "Pause. ▶ geht weiter."
		elif selected < 0:
			t = "Tipp ein Feld an. Ziehen dreht die Ansicht."
			if _ai_text != "":
				t = _ai_text
		else:
			t = "Nochmal antippen = Knopf drücken."
	status_label.text = t
	status_label.add_theme_color_override("font_color", C_RED if bad else C_TEXT)


func _set_status(t: String, bad: bool, seconds: float = 3.0) -> void:
	_status_text = t
	_status_bad = bad
	_status_until = _time + seconds
	_update_status()


# =============================================================================
# Feld-Auswahl
# =============================================================================

func _on_field_tapped(fid: int) -> void:
	if rotating or world.busy:
		return
	if fid == selected:
		_press_action()
	else:
		_select(fid)


func _on_field_info(fid: int) -> void:
	if rotating:
		return
	_select(fid)


func _select(fid: int) -> void:
	selected = fid
	world.select(fid)
	_refresh_selection()
	_update_status()


func _press_action() -> void:
	if selected < 0:
		return
	var res := Game.primary_action(selected)
	var text: String = res["text"]
	if text != "":
		_bubble(selected, text, C_GREEN if res["ok"] else C_RED)


# =============================================================================
# Blasen am Feld
# =============================================================================

func _bubble(fid: int, text: String, bg: Color, plain: bool = false) -> void:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if plain:
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_color_override("font_outline_color", Color(0.15, 0.12, 0.1, 0.9))
		l.add_theme_constant_override("outline_size", 6)
	else:
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_stylebox_override("normal", _sb(bg, 10, 4))
	bubble_layer.add_child(l)
	_bubbles.append({"node": l, "fid": fid, "t": 0.0, "dur": 1.6 if not plain else 1.3})
	_place_bubble(_bubbles[-1])


func _update_bubbles(delta: float) -> void:
	for i in range(_bubbles.size() - 1, -1, -1):
		var b: Dictionary = _bubbles[i]
		b["t"] = float(b["t"]) + delta
		if float(b["t"]) >= float(b["dur"]):
			(b["node"] as Label).queue_free()
			_bubbles.remove_at(i)
			continue
		_place_bubble(b)


func _place_bubble(b: Dictionary) -> void:
	var l: Label = b["node"]
	var info := world.field_screen(int(b["fid"]))
	var k: float = float(b["t"]) / float(b["dur"])
	l.visible = info["visible"]
	var sz := l.get_combined_minimum_size()
	l.size = sz
	l.position = (info["pos"] as Vector2) - Vector2(sz.x * 0.5, sz.y + 10.0 + 34.0 * k)
	l.modulate.a = 1.0 if k < 0.7 else clampf((1.0 - k) / 0.3, 0.0, 1.0)


func _on_tick_finished(_gains: Dictionary) -> void:
	# Am Takt-Ende kurz „+2🪵“ über den eigenen Feldern
	var gs := Game.state
	for f in gs.fields:
		if f.is_center or f.owner != HUMAN or f.level <= 0:
			continue
		var res: String = GameState.TERRAIN_RES[f.terrain]
		var y := gs.field_yield(f)
		_bubble(f.id, "+%d%s" % [int(y[res]), GameState.RES_ICON[res]], Color.WHITE, true)


func _on_message(text: String, bad: bool) -> void:
	_set_status(text, bad, 3.5)


# =============================================================================
# Drehmodus
# =============================================================================

func _start_rotate() -> void:
	if Game.human().rotations <= 0 or Game.animating or Game.over or world.busy:
		return
	rotating = true
	_select(-1)
	Game.set_planning(true)
	rot_info.text = "Tipp einen Pfeil: Die Scheibe dreht sich als Vorschau. Nochmal tippen dreht weiter. Die Zeit steht."
	rot_ok.disabled = true
	rot_layer.visible = true
	_layout()


func _end_rotate() -> void:
	rotating = false
	rot_layer.visible = false
	Game.set_planning(false)
	_layout()
	refresh()


func _place_arrows() -> void:
	if world.busy:
		for b in arrow_btns:
			(b as Button).visible = false
		return
	_arrows = world.rotate_arrows()
	var vs := root.get_viewport_rect().size
	for i in arrow_btns.size():
		var b: Button = arrow_btns[i]
		if i >= _arrows.size():
			b.visible = false
			continue
		var a: Dictionary = _arrows[i]
		b.visible = true
		b.text = str(a["text"])
		var p: Vector2 = a["pos"]
		p.x = clampf(p.x, 30.0, vs.x - 30.0)
		p.y = clampf(p.y, 70.0, vs.y - 30.0)
		b.position = p - b.size * 0.5


func _on_arrow(i: int) -> void:
	if world.busy or i >= _arrows.size():
		return
	var a: Dictionary = _arrows[i]
	world.preview_turn(int(a["axis"]), int(a["layer"]), int(a["d"]))


func _on_preview_changed(ps: GameState) -> void:
	if not rotating:
		return
	var gs := Game.state
	var before := int(gs.income_value(HUMAN))
	var after := int(ps.income_value(HUMAN))
	var fb := gs.territory(HUMAN)
	var fa := ps.territory(HUMAN)
	var net := 0
	if not world.preview.is_empty():
		net = int(world.preview["net"])
	if net == 0:
		rot_info.text = "Keine Änderung. Tipp einen Pfeil."
		rot_ok.disabled = true
		return
	rot_info.text = "Dein Ertrag pro Takt: %d → %d (%s%d)   Felder: %d → %d" % [before, after, "+" if after >= before else "", after - before, fb, fa]
	rot_ok.disabled = false


func _rotate_ok() -> void:
	if world.busy:
		return
	var r: Dictionary = await world.take_preview()
	if not r.is_empty():
		Game.queue_human_rotation(int(r["axis"]), int(r["layer"]), int(r["net"]))
	_end_rotate()


func _rotate_back() -> void:
	if world.busy:
		return
	await world.cancel_preview()
	_end_rotate()


# =============================================================================
# Menü, Tausch, Spielende
# =============================================================================

func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _toggle_pause() -> void:
	Game.paused = not Game.paused
	refresh()


func _show_rules() -> void:
	_close_popups()
	_open_popup(rules_panel)


func _restart_from_menu() -> void:
	if world.busy or Game.animating:
		_set_status("Einen Moment, die Drehung läuft noch", true)
		return
	_close_popups()
	Game.new_game(ai_option.get_selected_id())


func _restart() -> void:
	if world.busy or Game.animating:
		return
	_close_popups()
	Game.new_game()


func _do_trade() -> void:
	Game.trade(GameState.RES_KEYS[give_option.get_selected_id()], GameState.RES_KEYS[get_option.get_selected_id()])


func _open_popup(p: PanelContainer) -> void:
	p.visible = true
	Game.menu_open = true
	p.reset_size()


func _close_popups() -> void:
	for p in [menu_panel, rules_panel, trade_panel, end_panel]:
		(p as Control).visible = false
	Game.menu_open = false


func _open_menu() -> void:
	ai_option.select(Game.ai_count - 1)
	_open_popup(menu_panel)


func _open_trade() -> void:
	_open_popup(trade_panel)
	Game.menu_open = false   # Tauschen hält die Zeit nicht an


func _on_new_game() -> void:
	_close_popups()
	if rotating:
		rotating = false
		rot_layer.visible = false
	_select(-1)
	_status_text = ""
	_ai_text = ""
	for b in _bubbles:
		(b["node"] as Label).queue_free()
	_bubbles.clear()
	_clear(top_dots)
	_layout()
	refresh()


func _on_game_over(w: int) -> void:
	var gs := Game.state
	var lines := PackedStringArray()
	if w == HUMAN:
		lines.append("🏆 Du hast gewonnen!")
	else:
		lines.append("%s gewinnt." % gs.players[w].name)
	lines.append("")
	for pl in gs.players:
		if pl.active:
			lines.append("%s: %d Felder, %s" % [pl.name, gs.territory(pl.id), Balance.STAGE_NAMES[pl.stage]])
	end_label.text = "\n".join(lines)
	_open_popup(end_panel)
