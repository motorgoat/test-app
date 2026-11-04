class_name GameUI
extends CanvasLayer
## Oberfläche, Handy zuerst. Oben: Glaube, die Leiter (Wiese → Wald → Dorf → Stadt → Fabrik)
## mit Anzahl je Stufe und die zwei Leisten Natur/Zivilisation. Unten: Meteorit, Warten, Hilfe.

const STAGE_ICON = ["empty", "meadow", "nature", "village", "town", "industry"]

var world: World
var root: Control

var round_label: Label
var faith_label: Label
var best_label: Label
var ladder_counts: Array = []
var nature_bar: Dictionary = {}
var civ_bar: Dictionary = {}
var danger_label: Label
var preview_card: PanelContainer
var preview_label: Label
var toast: PanelContainer
var toast_label: Label
var wait_btn: Button
var meteor_btn: Button
var mode_card: PanelContainer
var sheet: PanelContainer
var sheet_icon: TextureRect
var sheet_title: Label
var sheet_body: Label
var modal_bg: ColorRect
var help_card: PanelContainer
var menu_card: PanelContainer
var over_card: PanelContainer
var over_label: Label
var bubble_layer: Control
var combo_label: Label

var meteor_mode := false
var _sheet_field := -1
var _bubbles: Array = []
var _toast_until := 0.0
var _time := 0.0
var _shown_faith := -1
var _faith_display := 0.0


func setup(w: World) -> void:
	world = w
	layer = 2
	_build()
	world.field_tapped.connect(_on_field_tapped)
	world.preview_changed.connect(_on_preview)
	world.deltas_shown.connect(_on_deltas)
	world.merged.connect(_on_merged)
	Game.state_changed.connect(refresh)
	Game.new_game_started.connect(_on_new_game)
	Game.message.connect(_on_message)
	Game.game_over.connect(_on_game_over)
	refresh()
	if not _seen_help():
		_open_modal(help_card)


# =============================================================================
# Aufbau
# =============================================================================

func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)

	# --- Oben ---
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 14)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	var card := _card()
	top.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	card.add_child(cv)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	cv.add_child(row)
	round_label = _label("Runde 1", 20, Style.SOFT, true)
	round_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(round_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sp)
	faith_label = _stat(row, "faith", 32)
	best_label = _stat(row, "trophy", 18)
	best_label.add_theme_color_override("font_color", Style.SOFT)
	row.add_child(_round_button("menu", func() -> void: _open_modal(menu_card), 46))

	# Die Leiter
	var ladder := HBoxContainer.new()
	ladder.add_theme_constant_override("separation", 2)
	ladder.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_child(ladder)
	for s in range(1, Balance.MAX_STAGE + 1):
		if s > 1:
			var arrow := _label("›", 26, Style.SOFT, true)
			arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ladder.add_child(arrow)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.custom_minimum_size = Vector2(60, 0)
		ladder.add_child(col)
		var tr := TextureRect.new()
		tr.texture = Style.icon(STAGE_ICON[s])
		tr.custom_minimum_size = Vector2(38, 38)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		col.add_child(tr)
		var nm := _label(GameState.stage_name(s), 12, Style.SOFT, true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(nm)
		var cnt := _label("0", 16, Style.TEXT, true)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(cnt)
		ladder_counts.append(cnt)
	var rule := _label("Dreh 3 gleiche in eine Reihe: Mitte steigt auf, Rand fällt zurück", 13, Style.SOFT, true)
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(rule)

	# Leisten
	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 14)
	cv.add_child(bars)
	nature_bar = _bar(bars, "nature", "Natur", Color("#4fae55"), Balance.NATURE_MIN, true)
	civ_bar = _bar(bars, "town", "Zivilisation", Color("#e0a54a"), Balance.CIVILISATION_MAX, false)
	danger_label = _label("", 15, Style.BAD, true)
	danger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	danger_label.visible = false
	cv.add_child(danger_label)

	preview_card = _card(Color(1, 1, 1, 0.97))
	preview_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview_label = _label("", 22, Style.TEXT, true)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_card.add_child(preview_label)
	preview_card.modulate.a = 0.0
	top.add_child(preview_card)

	# --- Unten ---
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 16)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)
	toast = _card(Color(0.17, 0.19, 0.25, 0.9))
	toast.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toast_label = _label("", 17, Color.WHITE)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.custom_minimum_size = Vector2(260, 0)
	toast.add_child(toast_label)
	toast.modulate.a = 0.0
	bottom.add_child(toast)
	mode_card = _card(Color("#2f3442"))
	mode_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 10)
	mode_card.add_child(mh)
	mh.add_child(_label("Tippe, wo der Meteorit einschlagen soll", 17, Color.WHITE, true))
	var cancel := _round_button("", func() -> void: _set_meteor_mode(false), 40)
	cancel.text = "✕"
	mh.add_child(cancel)
	mode_card.visible = false
	bottom.add_child(mode_card)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 12)
	brow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(brow)
	meteor_btn = Button.new()
	meteor_btn.icon = Style.icon("meteor")
	meteor_btn.add_theme_constant_override("icon_max_width", 30)
	meteor_btn.custom_minimum_size = Vector2(110, 62)
	meteor_btn.add_theme_font_override("font", Style.bold())
	meteor_btn.add_theme_font_size_override("font_size", 18)
	_pill_style(meteor_btn, Color.WHITE)
	meteor_btn.pressed.connect(func() -> void: _set_meteor_mode(not meteor_mode))
	brow.add_child(meteor_btn)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brow.add_child(sp2)
	wait_btn = Button.new()
	wait_btn.text = "Warten"
	wait_btn.icon = Style.icon("wait")
	wait_btn.add_theme_constant_override("icon_max_width", 28)
	wait_btn.custom_minimum_size = Vector2(150, 62)
	wait_btn.add_theme_font_override("font", Style.bold())
	wait_btn.add_theme_font_size_override("font_size", 20)
	_pill_style(wait_btn, Color.WHITE)
	wait_btn.pressed.connect(func() -> void: world.wait_turn())
	brow.add_child(wait_btn)
	var sp3 := Control.new()
	sp3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brow.add_child(sp3)
	brow.add_child(_round_button("help", func() -> void: _open_modal(help_card), 62))

	bubble_layer = Control.new()
	bubble_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bubble_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bubble_layer)

	combo_label = _label("", 44, Color("#ffb400"), true)
	combo_label.add_theme_color_override("font_outline_color", Color.WHITE)
	combo_label.add_theme_constant_override("outline_size", 14)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	combo_label.offset_top = 330
	combo_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	combo_label.modulate.a = 0.0
	root.add_child(combo_label)

	_build_sheet()
	modal_bg = ColorRect.new()
	modal_bg.color = Color(0.12, 0.13, 0.18, 0.45)
	modal_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_bg.visible = false
	root.add_child(modal_bg)
	_build_help()
	_build_menu()
	_build_over()


func _bar(parent: Control, icon_name: String, title: String, color: Color, limit: float, is_min: bool) -> Dictionary:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var tr := TextureRect.new()
	tr.texture = Style.icon(icon_name)
	tr.custom_minimum_size = Vector2(20, 20)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(tr)
	var l := _label(title, 14, Style.TEXT, true)
	h.add_child(l)
	var pct := _label("0%", 14, Style.TEXT, true)
	pct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pct)
	var back := ColorRect.new()
	back.color = Color("#ece6dc")
	back.custom_minimum_size = Vector2(0, 10)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(back)
	var fill := ColorRect.new()
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)
	var mark := ColorRect.new()
	mark.color = Style.TEXT
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(mark)
	var hint := _label(("mind. %d%%" if is_min else "höchstens %d%%") % int(round(limit * 100.0)), 11, Style.SOFT)
	v.add_child(hint)
	return {"back": back, "fill": fill, "mark": mark, "pct": pct, "color": color, "limit": limit, "is_min": is_min}


func _build_sheet() -> void:
	sheet = _card(Color(1, 0.99, 0.97, 0.98), 26)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 12)
	sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sheet.visible = false
	root.add_child(sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	sheet.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	sheet_icon = TextureRect.new()
	sheet_icon.custom_minimum_size = Vector2(44, 44)
	sheet_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sheet_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(sheet_icon)
	sheet_title = _label("", 23, Style.TEXT, true)
	sheet_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_title.custom_minimum_size = Vector2(180, 0)
	h.add_child(sheet_title)
	var close := _round_button("", func() -> void: _close_sheet(), 48)
	close.text = "✕"
	h.add_child(close)
	sheet_body = _label("", 17, Style.TEXT)
	sheet_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet_body.custom_minimum_size = Vector2(280, 0)
	v.add_child(sheet_body)


func _modal_card(title: String) -> PanelContainer:
	var c := _card(Color(1, 0.99, 0.97, 1.0), 28)
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH
	c.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(350, 0)
	c.add_child(v)
	var t := _label(title, 25, Style.TEXT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	root.add_child(c)
	return c


func _build_help() -> void:
	help_card = _modal_card("So geht's")
	var v: VBoxContainer = help_card.get_child(0)
	v.add_child(_help_row("round", "Wisch über eine Reihe des Würfels, um sie zu drehen. Jede Drehung ist eine Runde."))
	v.add_child(_help_row("up", "Vervollständigst du durch eine Drehung eine Reihe aus 3 gleichen Feldern, verschmelzen sie: Die Mitte steigt auf (Wiese → Wald → Dorf → Stadt → Fabrik), die beiden äußeren fallen eine Stufe zurück."))
	v.add_child(_help_row("meadow", "Leere Erde wird wieder zur Wiese, wenn 3 Natur-Felder daneben liegen."))
	v.add_child(_help_row("industry", "Städte und Fabriken bringen jede Runde Glauben. Fabriken zerstören aber die Natur daneben."))
	v.add_child(_help_row("balance", "Zu wenig Natur oder zu viel Zivilisation: Die Welt stirbt."))
	v.add_child(_help_row("meteor", "Der Meteorit kostet Glauben und macht ein Feld samt Nachbarn zu Erde. Setz ihn im richtigen Moment ein."))
	v.add_child(_help_row("trophy", "Ziel: in %d Runden möglichst viel Glauben. %d / %d / %d Glaube = 1 / 2 / 3 Sterne." % [Balance.MAX_ROUNDS, int(Balance.STARS[0]), int(Balance.STARS[1]), int(Balance.STARS[2])]))
	var go := _wide_button("Los geht's", Style.ACCENT, Color.WHITE)
	go.pressed.connect(_on_help_done)
	v.add_child(go)


func _build_menu() -> void:
	menu_card = _modal_card("Pause")
	var v: VBoxContainer = menu_card.get_child(0)
	var cont := _wide_button("Weiter", Style.ACCENT, Color.WHITE)
	cont.pressed.connect(func() -> void: _close_modal())
	v.add_child(cont)
	var restart := _wide_button("Neues Spiel", Color.WHITE, Style.TEXT)
	restart.pressed.connect(_restart)
	v.add_child(restart)
	var help := _wide_button("So geht's", Color.WHITE, Style.TEXT)
	help.pressed.connect(_show_help)
	v.add_child(help)


func _build_over() -> void:
	over_card = _modal_card("Die Welt ist gestorben")
	var v: VBoxContainer = over_card.get_child(0)
	over_label = _label("", 19, Style.TEXT)
	over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	over_label.custom_minimum_size = Vector2(300, 0)
	v.add_child(over_label)
	var again := _wide_button("Nochmal", Style.ACCENT, Color.WHITE)
	again.pressed.connect(_restart)
	v.add_child(again)


# --- Bausteine ---------------------------------------------------------------

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = Style.font()
	t.default_font_size = 18
	t.set_color("font_color", "Label", Style.TEXT)
	t.set_stylebox("panel", "PanelContainer", _sb(Style.PANEL, 22, 14))
	var normal := _sb(Color.WHITE, 30, 10)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", normal)
	t.set_stylebox("pressed", "Button", _sb(Color("#f1ece4"), 30, 10))
	t.set_stylebox("disabled", "Button", _sb(Color("#eeeae4"), 30, 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", Style.TEXT)
	t.set_color("font_disabled_color", "Button", Color("#b4ada3"))
	return t


func _sb(bg: Color, radius: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 10
	s.anti_aliasing = true
	s.content_margin_left = pad + 4
	s.content_margin_right = pad + 4
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


func _card(bg: Color = Style.PANEL, radius: int = 22) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _sb(bg, radius, 12)
	s.shadow_size = 12
	s.shadow_color = Color(0.1, 0.12, 0.2, 0.12)
	s.shadow_offset = Vector2(0, 4)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", Style.bold())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _stat(parent: Control, icon_name: String, size: int) -> Label:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(h)
	var tr := TextureRect.new()
	tr.texture = Style.icon(icon_name)
	tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tr)
	var l := _label("0", size, Style.TEXT, true)
	h.add_child(l)
	return l


func _round_button(icon_name: String, cb: Callable, size: int = 60) -> Button:
	var b := Button.new()
	if icon_name != "":
		b.icon = Style.icon(icon_name)
		b.add_theme_constant_override("icon_max_width", int(size * 0.46))
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(size, size)
	_pill_style(b, Color.WHITE)
	b.pressed.connect(cb)
	return b


func _pill_style(b: Button, bg: Color) -> void:
	var n := _sb(bg, 30, 10)
	n.shadow_size = 10
	n.shadow_color = Color(0.1, 0.12, 0.2, 0.16)
	n.shadow_offset = Vector2(0, 3)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("pressed", _sb(bg.darkened(0.08), 30, 10))
	b.add_theme_stylebox_override("disabled", _sb(Color(1, 1, 1, 0.55), 30, 10))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _wide_button(text: String, bg: Color, fg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_override("font", Style.bold())
	b.add_theme_font_size_override("font_size", 20)
	_pill_style(b, bg)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, fg)
	return b


func _help_row(icon_name: String, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var tr := TextureRect.new()
	tr.texture = Style.icon(icon_name)
	tr.custom_minimum_size = Vector2(36, 36)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tr)
	var l := _label(text, 16, Style.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(270, 0)
	h.add_child(l)
	return h


# =============================================================================
# Aktualisieren
# =============================================================================

func refresh() -> void:
	if root == null or Game.state == null:
		return
	var gs := Game.state
	round_label.text = "Runde %d / %d" % [mini(gs.turn, Balance.MAX_ROUNDS), Balance.MAX_ROUNDS] if Balance.MAX_ROUNDS > 0 else "Runde %d" % gs.turn
	if _shown_faith < 0:
		_faith_display = gs.faith
	if _shown_faith >= 0 and gs.faith != _shown_faith:
		_pop(faith_label)
	_shown_faith = gs.faith
	best_label.text = str(Game.best_faith)
	for s in range(1, Balance.MAX_STAGE + 1):
		(ladder_counts[s - 1] as Label).text = str(gs.count(s))
	meteor_btn.text = str(gs.meteor_cost())
	if gs.bad_rounds > 0 and not Game.over:
		var left := Balance.LOSE_AFTER - gs.bad_rounds
		danger_label.text = "Die Welt stirbt in %d %s!" % [left, "Runde" if left == 1 else "Runden"]
		danger_label.visible = true
	else:
		danger_label.visible = false
	_update_buttons()
	if _sheet_field >= 0 and sheet.visible:
		_fill_sheet(_sheet_field)


func _update_buttons() -> void:
	var gs := Game.state
	var blocked := Game.busy or Game.over or world.animating
	wait_btn.disabled = blocked
	meteor_btn.disabled = blocked or gs.faith < gs.meteor_cost()


func _draw_bar(b: Dictionary, value: float) -> void:
	var back: ColorRect = b["back"]
	var fill: ColorRect = b["fill"]
	var mark: ColorRect = b["mark"]
	var w := back.size.x
	var limit: float = b["limit"]
	var ok := value >= limit if bool(b["is_min"]) else value <= limit
	fill.size = Vector2(maxf(2.0, w * clampf(value, 0.0, 1.0)), 10)
	fill.color = b["color"] if ok else Style.BAD
	mark.position = Vector2(w * limit - 1.5, -3)
	mark.size = Vector2(3, 16)
	var pct: Label = b["pct"]
	pct.text = "%d%%" % int(round(value * 100.0))
	pct.add_theme_color_override("font_color", Style.TEXT if ok else Style.BAD)


func _pop(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.25, 1.25), 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	if toast.modulate.a > 0.0 and _time > _toast_until:
		toast.modulate.a = maxf(0.0, toast.modulate.a - delta * 3.0)
	_update_bubbles(delta)
	if Game.state == null or faith_label == null:
		return
	var target := float(Game.state.faith)
	_faith_display = move_toward(_faith_display, target, maxf(1.0, absf(target - _faith_display)) * delta * 4.0)
	faith_label.text = str(int(round(_faith_display)))
	_draw_bar(nature_bar, Game.state.nature_share())
	_draw_bar(civ_bar, Game.state.civilisation_share())
	_update_buttons()


# =============================================================================
# Meteorit
# =============================================================================

func _set_meteor_mode(on: bool) -> void:
	meteor_mode = on
	mode_card.visible = on
	_close_sheet()


# =============================================================================
# Vorschau beim Wischen
# =============================================================================

func _on_preview(info: Dictionary) -> void:
	var tw := preview_card.create_tween()
	if info.is_empty():
		tw.tween_property(preview_card, "modulate:a", 0.0, 0.15)
		return
	var arranged: GameState = info["arranged"]
	var merges := arranged.moved_lines().size()
	var gain := int(info["gain"])
	if merges > 0:
		preview_label.text = "%d× Verschmelzen   ·   +%d Glaube" % [merges, gain]
		preview_label.add_theme_color_override("font_color", Color("#c98a00"))
	else:
		preview_label.text = "Keine Dreierreihe   ·   +%d Glaube" % gain
		preview_label.add_theme_color_override("font_color", Style.SOFT)
	tw.tween_property(preview_card, "modulate:a", 1.0, 0.12)


# =============================================================================
# Info-Karte
# =============================================================================

func _on_field_tapped(fid: int) -> void:
	if meteor_mode:
		if Game.use_meteor(fid):
			_set_meteor_mode(false)
		return
	if world.selected == fid and sheet.visible:
		_close_sheet()
		return
	world.select(fid)
	_sheet_field = fid
	_fill_sheet(fid)
	if not sheet.visible:
		sheet.visible = true
		sheet.modulate.a = 0.0
		var tw := sheet.create_tween()
		tw.tween_property(sheet, "modulate:a", 1.0, 0.18)


func _close_sheet() -> void:
	_sheet_field = -1
	world.select(-1)
	if not sheet.visible:
		return
	var tw := sheet.create_tween()
	tw.tween_property(sheet, "modulate:a", 0.0, 0.15)
	tw.tween_callback(sheet.hide)


func _fill_sheet(fid: int) -> void:
	var f: FieldData = Game.state.fields[fid]
	sheet_title.text = GameState.stage_name(f.stage)
	sheet_icon.texture = Style.icon(STAGE_ICON[f.stage])
	var lines := PackedStringArray()
	if f.stage == 0:
		lines.append("Wird wieder zur Wiese, wenn %d Natur-Felder daneben liegen." % Balance.REGROW_NEIGHBORS)
	elif f.stage >= Balance.MAX_STAGE:
		lines.append("Höchste Stufe. Bringt +%d Glauben pro Runde." % int(Balance.INCOME[f.stage]))
		lines.append("Zerstört jede Runde ein Natur-Feld daneben.")
		lines.append("Drei Fabriken in einer Reihe: +%d Glaube." % int(Balance.MERGE_POINTS[f.stage]))
	else:
		if true:
			lines.append("Dreh 3 davon in eine Reihe: Die Mitte wird %s (+%d Glaube), die beiden äußeren werden %s." % [GameState.stage_name(f.stage + 1), int(Balance.MERGE_POINTS[f.stage]), GameState.stage_name(f.stage - 1)])
			if int(Balance.INCOME[f.stage]) > 0:
				lines.append("Bringt +%d Glauben pro Runde." % int(Balance.INCOME[f.stage]))
	sheet_body.text = "\n".join(lines)


# =============================================================================
# Blasen, Meldungen, Modale
# =============================================================================

func _on_merged(fid: int, points: int, combo: int) -> void:
	_bubble(fid, "+%d" % points, "up", Color("#f2a900"))
	var f: FieldData = Game.state.fields[fid]
	if combo >= 2:
		combo_label.text = "Kombo ×%d!" % combo
	else:
		combo_label.text = GameState.stage_name(f.stage) + "!"
	combo_label.pivot_offset = combo_label.size * 0.5
	combo_label.scale = Vector2(0.5, 0.5)
	combo_label.modulate.a = 1.0
	var tw := combo_label.create_tween()
	tw.tween_property(combo_label, "scale", Vector2(1.1, 1.1), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(combo_label, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(0.6)
	tw.tween_property(combo_label, "modulate:a", 0.0, 0.35)


func _on_deltas(list: Array, gain: int) -> void:
	for d in list:
		var fid := int(d["field"])
		match str(d["change"]):
			"lost":
				_bubble(fid, "verschmutzt", "smog", Style.BAD)
			"new":
				_bubble(fid, "Wiese", "meadow", Style.GOOD)
	if gain > 0:
		_on_message("+%d Glaube" % gain, "good")
	refresh()


func _bubble(fid: int, text: String, icon_name: String, color: Color) -> void:
	var b := Button.new()
	b.text = text
	b.icon = Style.icon(icon_name)
	b.add_theme_constant_override("icon_max_width", 18)
	b.add_theme_font_override("font", Style.bold())
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color.WHITE)
	var s := _sb(color, 14, 3)
	s.content_margin_left = 6
	s.content_margin_right = 10
	b.add_theme_stylebox_override("normal", s)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_layer.add_child(b)
	_bubbles.append({"node": b, "fid": fid, "t": 0.0, "dur": 1.8})
	_update_bubbles(0.0)


func _update_bubbles(delta: float) -> void:
	for i in range(_bubbles.size() - 1, -1, -1):
		var bd: Dictionary = _bubbles[i]
		bd["t"] = float(bd["t"]) + delta
		var b: Control = bd["node"]
		if float(bd["t"]) >= float(bd["dur"]):
			b.queue_free()
			_bubbles.remove_at(i)
			continue
		var info := world.field_screen(int(bd["fid"]))
		var k: float = float(bd["t"]) / float(bd["dur"])
		var sz := b.get_combined_minimum_size()
		b.size = sz
		b.visible = info["visible"]
		b.position = (info["pos"] as Vector2) - Vector2(sz.x * 0.5, sz.y + 40.0 * ease(k, 0.4))
		b.modulate.a = 1.0 if k < 0.75 else clampf((1.0 - k) / 0.25, 0.0, 1.0)
		var sc := 1.0 if k > 0.15 else lerpf(0.4, 1.0, ease(k / 0.15, 0.3))
		b.pivot_offset = sz * 0.5
		b.scale = Vector2(sc, sc)


func _on_message(text: String, kind: String) -> void:
	toast_label.text = text
	var bg := Color(0.17, 0.19, 0.25, 0.92)
	if kind == "bad":
		bg = Color("#e5483c")
	elif kind == "good":
		bg = Color("#34a853")
	toast.add_theme_stylebox_override("panel", _sb(bg, 22, 12))
	toast.modulate.a = 1.0
	_toast_until = _time + 3.0
	toast.pivot_offset = toast.size * 0.5
	toast.scale = Vector2(0.9, 0.9)
	var tw := toast.create_tween()
	tw.tween_property(toast, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_help_done() -> void:
	_mark_help_seen()
	_close_modal()


func _restart() -> void:
	_close_modal()
	Game.new_game()


func _show_help() -> void:
	_close_modal()
	_open_modal(help_card)


func _open_modal(card: PanelContainer) -> void:
	for c in [help_card, menu_card, over_card]:
		(c as Control).visible = false
	modal_bg.visible = true
	modal_bg.modulate.a = 0.0
	card.visible = true
	card.size = Vector2.ZERO
	card.reset_size()
	_recenter.call_deferred(card)
	card.modulate.a = 0.0
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.92, 0.92)
	var tw := card.create_tween().set_parallel(true)
	tw.tween_property(modal_bg, "modulate:a", 1.0, 0.18)
	tw.tween_property(card, "modulate:a", 1.0, 0.18)
	tw.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _recenter(card: Control) -> void:
	card.size = Vector2.ZERO
	card.reset_size()
	var vs := root.get_viewport_rect().size
	card.position = (vs - card.size) * 0.5
	card.pivot_offset = card.size * 0.5


func _close_modal() -> void:
	for c in [help_card, menu_card, over_card]:
		(c as Control).visible = false
	modal_bg.visible = false


func _on_new_game() -> void:
	_close_modal()
	_set_meteor_mode(false)
	sheet.visible = false
	_sheet_field = -1
	_shown_faith = -1
	for bd in _bubbles:
		(bd["node"] as Control).queue_free()
	_bubbles.clear()
	refresh()


func _on_game_over() -> void:
	var gs := Game.state
	var lines := PackedStringArray()
	var title: Label = (over_card.get_child(0) as VBoxContainer).get_child(0)
	if gs.died():
		title.text = "Die Welt ist gestorben"
		if gs.nature_share() < Balance.NATURE_MIN:
			lines.append("Es gab zu wenig Natur.")
		else:
			lines.append("Es gab zu viel Zivilisation.")
		lines.append("Überlebt: %d Runden" % Game.rounds_survived())
	else:
		title.text = "Geschafft!"
		var st := gs.stars()
		lines.append("★".repeat(st) + "☆".repeat(3 - st))
	lines.append("")
	lines.append("Glaube: %d" % gs.faith)
	if Game.new_record:
		lines.append("Neuer Rekord!")
	else:
		lines.append("Rekord: %d Glaube" % Game.best_faith)
	over_label.text = "\n".join(lines)
	_open_modal(over_card)


func _seen_help() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load("user://einstellungen.cfg") != OK:
		return false
	return bool(cfg.get_value("hilfe", "gesehen_v4", false))


func _mark_help_seen() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("hilfe", "gesehen_v4", true)
	cfg.save("user://einstellungen.cfg")


## Für die automatischen Screenshots.
func debug_show_field(fid: int) -> void:
	_on_field_tapped(fid)


func debug_show_help() -> void:
	_open_modal(help_card)


func debug_close_all() -> void:
	_close_modal()
	_set_meteor_mode(false)
	sheet.visible = false
