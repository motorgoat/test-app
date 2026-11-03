class_name GameUI
extends CanvasLayer
## Oberfläche, Handy zuerst: schwebende Karten mit runden Ecken, große Knöpfe, wenig Text.
## Oben: Runde, Menschen, Tiere, Rekord, darunter Völker und Gefahren.
## Unten: „Warten“, Hilfe, Menü. Beim Wischen erscheint oben die Vorschau.

const HUMAN_ICON := "person"

var world: World
var root: Control

var round_label: Label
var people_label: Label
var animals_label: Label
var best_label: Label
var chips: HFlowContainer
var preview_card: PanelContainer
var preview_label: Label
var toast: PanelContainer
var toast_label: Label
var wait_btn: Button
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

var _sheet_field := -1
var _bubbles: Array = []
var _toast_until := 0.0
var _time := 0.0
var _shown_people := -1


func setup(w: World) -> void:
	world = w
	layer = 2
	_build()
	world.field_tapped.connect(_on_field_tapped)
	world.preview_changed.connect(_on_preview)
	world.deltas_shown.connect(_on_deltas)
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

	# --- Oben: Statuskarte ---
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 14)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	var card := _card()
	top.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var rbox := VBoxContainer.new()
	rbox.add_theme_constant_override("separation", -6)
	row.add_child(rbox)
	var rcap := _label("RUNDE", 12, Style.SOFT)
	rbox.add_child(rcap)
	round_label = _label("1", 30, Style.TEXT, true)
	rbox.add_child(round_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sp)
	people_label = _stat(row, "person")
	animals_label = _stat(row, "paw")
	best_label = _stat(row, "trophy")
	best_label.add_theme_font_size_override("font_size", 18)
	best_label.add_theme_color_override("font_color", Style.SOFT)

	chips = HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(chips)

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
	toast_label.custom_minimum_size = Vector2(240, 0)
	toast.add_child(toast_label)
	toast.modulate.a = 0.0
	bottom.add_child(toast)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 12)
	brow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(brow)
	brow.add_child(_round_button("help", func() -> void: _open_modal(help_card)))
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brow.add_child(sp2)
	wait_btn = Button.new()
	wait_btn.text = "Warten"
	wait_btn.icon = Style.icon("wait")
	wait_btn.expand_icon = false
	wait_btn.add_theme_constant_override("icon_max_width", 28)
	wait_btn.custom_minimum_size = Vector2(170, 60)
	wait_btn.add_theme_font_override("font", Style.bold())
	wait_btn.add_theme_font_size_override("font_size", 20)
	_pill_style(wait_btn, Color.WHITE)
	wait_btn.pressed.connect(func() -> void: world.wait_turn())
	brow.add_child(wait_btn)
	var sp3 := Control.new()
	sp3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brow.add_child(sp3)
	brow.add_child(_round_button("menu", func() -> void: _open_modal(menu_card)))

	bubble_layer = Control.new()
	bubble_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bubble_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bubble_layer)

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
	sheet_title = _label("", 24, Style.TEXT, true)
	sheet_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet_title.custom_minimum_size = Vector2(180, 0)
	h.add_child(sheet_title)
	var close := _round_button("", func() -> void: _close_sheet())
	close.text = "✕"
	close.custom_minimum_size = Vector2(48, 48)
	h.add_child(close)
	sheet_body = _label("", 18, Style.TEXT)
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
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(340, 0)
	c.add_child(v)
	var t := _label(title, 26, Style.TEXT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	root.add_child(c)
	return c


func _build_help() -> void:
	help_card = _modal_card("Beschütze die Völker")
	var v: VBoxContainer = help_card.get_child(0)
	v.add_child(_help_row("round", "Wisch über eine Reihe, um die Welt zu drehen. Jede Drehung ist eine Runde."))
	v.add_child(_help_row("village", "Dörfer wachsen neben freien Wiesen und Seen. Ohne sie hungern sie."))
	v.add_child(_help_row("swords", "Kirchen zweier Völker nebeneinander: Krieg. Wer Krieg führt, handelt nicht."))
	v.add_child(_help_row("trade", "Märkte zweier Völker nebeneinander: Handel, beide wachsen."))
	v.add_child(_help_row("meteor", "Meteor, Gewitter und Vulkan kündigen sich an. Dreh die Menschen weg!"))
	v.add_child(_help_row("paw", "Tiere mögen gleiches Land nebeneinander, Dörfer daneben jagen sie."))
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
	over_card = _modal_card("Die Welt ist leer")
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
	normal.shadow_size = 6
	normal.shadow_color = Color(0, 0, 0, 0.1)
	normal.shadow_offset = Vector2(0, 2)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", normal)
	var pressed := _sb(Color("#f1ece4"), 30, 10)
	t.set_stylebox("pressed", "Button", pressed)
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
	var s := _sb(bg, radius, 14)
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


func _stat(parent: Control, icon_name: String) -> Label:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(h)
	var tr := TextureRect.new()
	tr.texture = Style.icon(icon_name)
	tr.custom_minimum_size = Vector2(26, 26)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tr)
	var l := _label("0", 26, Style.TEXT, true)
	h.add_child(l)
	return l


func _round_button(icon_name: String, cb: Callable) -> Button:
	var b := Button.new()
	if icon_name != "":
		b.icon = Style.icon(icon_name)
		b.add_theme_constant_override("icon_max_width", 28)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(60, 60)
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
	var p := _sb(bg.darkened(0.06), 30, 10)
	b.add_theme_stylebox_override("pressed", p)
	var d := _sb(Color(1, 1, 1, 0.6), 30, 10)
	b.add_theme_stylebox_override("disabled", d)


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
	tr.custom_minimum_size = Vector2(40, 40)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tr)
	var l := _label(text, 17, Style.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(260, 0)
	h.add_child(l)
	return h


func _chip(icon_name: String, text: String, colors: Array, cb: Callable = Callable()) -> Control:
	var b := Button.new()
	b.text = text
	if icon_name != "":
		b.icon = Style.icon(icon_name)
		b.add_theme_constant_override("icon_max_width", 20)
	b.add_theme_font_override("font", Style.bold())
	b.add_theme_font_size_override("font_size", 15)
	var s := _sb(Color(1, 1, 1, 0.92), 16, 4)
	s.content_margin_left = 10
	s.content_margin_right = 10
	if colors.size() == 1:
		s.border_color = colors[0]
		s.set_border_width_all(3)
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", s)
	b.add_theme_stylebox_override("pressed", s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Style.TEXT)
	if cb.is_valid():
		b.pressed.connect(cb)
	else:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


# =============================================================================
# Aktualisieren
# =============================================================================

func refresh() -> void:
	if root == null or Game.state == null:
		return
	var gs := Game.state
	round_label.text = str(gs.turn)
	var ppl := gs.total_people()
	people_label.text = str(ppl)
	if _shown_people >= 0 and ppl != _shown_people:
		_pop(people_label)
	_shown_people = ppl
	animals_label.text = str(gs.total_animals())
	best_label.text = str(Game.best_rounds)
	_refresh_chips()
	wait_btn.disabled = Game.busy or Game.over or world.animating
	if _sheet_field >= 0 and sheet.visible:
		_fill_sheet(_sheet_field)


func _pop(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.25, 1.25), 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_chips() -> void:
	for c in chips.get_children():
		chips.remove_child(c)
		c.queue_free()
	var gs := Game.state
	for nation in Balance.NATION_COUNT:
		var cnt := gs.nation_people(nation)
		var chip := _chip("", "%s %d" % [GameState.NATION_NAMES[nation], cnt], [Style.nation_color(nation)])
		if cnt == 0:
			chip.modulate.a = 0.45
		chips.add_child(chip)
	for k in gs.war_pairs():
		var ab: PackedStringArray = str(k).split("|")
		chips.add_child(_chip("swords", "%s – %s" % [GameState.NATION_NAMES[int(ab[0])], GameState.NATION_NAMES[int(ab[1])]], [Style.BAD]))
	for k in gs.trade_pairs():
		var ab: PackedStringArray = str(k).split("|")
		chips.add_child(_chip("trade", "%s – %s" % [GameState.NATION_NAMES[int(ab[0])], GameState.NATION_NAMES[int(ab[1])]], [Style.GOOD]))
	for h in gs.hazards:
		var n: Vector3i = h["n"]
		var t: String = h["type"]
		chips.add_child(_chip(t, str(h["timer"]), [Style.BAD], world.focus_place.bind(n)))
	for f in gs.fields:
		if f.volcano > 0:
			chips.add_child(_chip("volcano", str(f.volcano), [Style.BAD], world.focus_field.bind(f.id)))


func _process(delta: float) -> void:
	_time += delta
	if toast.modulate.a > 0.0 and _time > _toast_until:
		toast.modulate.a = maxf(0.0, toast.modulate.a - delta * 3.0)
	_update_bubbles(delta)
	if wait_btn != null:
		wait_btn.disabled = Game.busy or Game.over or world.animating


# =============================================================================
# Vorschau beim Wischen
# =============================================================================

func _on_preview(info: Dictionary) -> void:
	var tw := preview_card.create_tween()
	if info.is_empty():
		tw.tween_property(preview_card, "modulate:a", 0.0, 0.15)
		return
	var dp := int(info["people"])
	var da := int(info["animals"])
	var parts := PackedStringArray()
	parts.append("%s Menschen" % _signed(dp))
	parts.append("%s Tiere" % _signed(da))
	var extra := ""
	var ps: GameState = info["state"]
	if not ps.war_pairs().is_empty():
		extra = "  ·  Krieg!"
	preview_label.text = "   ".join(parts) + extra
	var col := Style.GOOD if dp > 0 else (Style.BAD if dp < 0 else Style.TEXT)
	preview_label.add_theme_color_override("font_color", col)
	tw.tween_property(preview_card, "modulate:a", 1.0, 0.12)


static func _signed(v: int) -> String:
	if v > 0:
		return "+%d" % v
	if v < 0:
		return "−%d" % -v
	return "±0"


# =============================================================================
# Info-Karte
# =============================================================================

func _on_field_tapped(fid: int) -> void:
	if world.selected == fid and sheet.visible:
		_close_sheet()
		return
	world.select(fid)
	_sheet_field = fid
	_fill_sheet(fid)
	if not sheet.visible:
		sheet.visible = true
		sheet.modulate.a = 0.0
		var tw := sheet.create_tween().set_parallel(true)
		tw.tween_property(sheet, "modulate:a", 1.0, 0.18)


func _close_sheet() -> void:
	_sheet_field = -1
	world.select(-1)
	var tw := sheet.create_tween()
	tw.tween_property(sheet, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func() -> void: sheet.visible = false)


func _fill_sheet(fid: int) -> void:
	var gs := Game.state
	var f: FieldData = gs.fields[fid]
	var lines := PackedStringArray()
	var fc := gs.field_forecast(f)
	var terrain_name: String = GameState.TERRAIN_NAME[f.terrain]
	if f.settled():
		var bname: String = GameState.BUILDING_NAME[f.building]
		sheet_title.text = "%s der %s" % [bname, GameState.NATION_GENITIVE[f.nation]]
		sheet_icon.texture = Style.icon(f.building)
		lines.append("%d Menschen · auf %s" % [f.people, terrain_name])
		match f.building:
			"village":
				var food := int(fc["food"])
				if food >= Balance.GROWTH_FOOD_NEEDED:
					lines.append("Wächst: %d freie Wiesen oder Seen daneben." % food)
				elif food == 0:
					lines.append("Hunger! Keine freie Wiese und kein See daneben.")
				else:
					lines.append("Bleibt gleich: braucht %d freie Wiesen oder Seen daneben." % Balance.GROWTH_FOOD_NEEDED)
				if bool(fc["church"]):
					lines.append("Die eigene Kirche daneben hilft beim Wachsen.")
			"church":
				lines.append("Hilft Dörfern daneben. Neben einer fremden Kirche gibt es Krieg.")
			"market":
				lines.append("Neben einem fremden Markt: Handel, beide wachsen. Nicht im Krieg.")
		if int(fc["war"]) > 0:
			lines.append("Krieg: verliert %d pro Runde." % mini(int(fc["war"]), Balance.WAR_MAX))
		if int(fc["trade"]) > 0:
			lines.append("Handel: +%d pro Runde." % mini(int(fc["trade"]), Balance.TRADE_MAX))
	else:
		sheet_title.text = terrain_name
		sheet_icon.texture = Style.icon("paw") if f.animals > 0 else null
		if f.animals > 0:
			lines.append("%d %s" % [f.animals, GameState.ANIMAL_NAME[f.terrain]])
			if bool(fc["hunted"]):
				lines.append("Ein Dorf daneben jagt sie.")
			elif bool(fc["habitat"]):
				lines.append("Vermehren sich: gleiches Land daneben.")
			else:
				lines.append("Brauchen gleiches Land daneben, um sich zu vermehren.")
		match f.terrain:
			"meadow", "lake":
				lines.append("Nahrung für Dörfer daneben.")
			"crater":
				lines.append("Füllt sich in %d Runden mit Wasser." % maxi(1, Balance.CRATER_TO_LAKE - f.crater_age))
	if f.burning:
		lines.append("Brennt! Ein See daneben löscht das Feuer, sonst springt es auf Wälder über.")
	if f.volcano > 0:
		sheet_icon.texture = Style.icon("volcano")
		lines.append("Vulkan bricht in %d Runden aus: Nachbarn verlieren die Hälfte." % f.volcano)
	var h := gs.hazard_at(f)
	if not h.is_empty():
		var t: String = h["type"]
		sheet_icon.texture = Style.icon(t)
		if t == "meteor":
			lines.append("Meteorit schlägt in %d Runden genau hier ein und löscht das Feld aus. Dreh die Menschen weg!" % int(h["timer"]))
		else:
			lines.append("Gewitter in %d Runden genau hier: halbiert Menschen und Tiere, Wald fängt Feuer." % int(h["timer"]))
	sheet_body.text = "\n".join(lines)


# =============================================================================
# Blasen, Meldungen, Modale
# =============================================================================

func _on_deltas(list: Array) -> void:
	for d in list:
		var dp := int(d["people"])
		var da := int(d["animals"])
		if dp != 0:
			_bubble(int(d["field"]), _signed(dp), "person", Style.GOOD if dp > 0 else Style.BAD)
		elif da != 0:
			_bubble(int(d["field"]), _signed(da), "paw", Style.GOOD if da > 0 else Style.BAD)
	refresh()


func _bubble(fid: int, text: String, icon_name: String, color: Color) -> void:
	var b := Button.new()
	b.text = text
	b.icon = Style.icon(icon_name)
	b.add_theme_constant_override("icon_max_width", 18)
	b.add_theme_font_override("font", Style.bold())
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color.WHITE)
	var s := _sb(color, 14, 3)
	s.content_margin_left = 8
	s.content_margin_right = 10
	b.add_theme_stylebox_override("normal", s)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_layer.add_child(b)
	_bubbles.append({"node": b, "fid": fid, "t": 0.0, "dur": 1.5})


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
		b.modulate.a = 1.0 if k < 0.7 else clampf((1.0 - k) / 0.3, 0.0, 1.0)
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
	var s := _sb(bg, 22, 12)
	toast.add_theme_stylebox_override("panel", s)
	toast.modulate.a = 1.0
	_toast_until = _time + 3.2
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
	tw.tween_property(card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	if sheet.visible:
		sheet.visible = false
	_sheet_field = -1
	_shown_people = -1
	for bd in _bubbles:
		(bd["node"] as Control).queue_free()
	_bubbles.clear()
	refresh()


func _on_game_over() -> void:
	var lines := PackedStringArray()
	lines.append("Überlebt: %d Runden" % Game.rounds_survived())
	lines.append("Höchste Bevölkerung: %d" % Game.state.peak_people)
	if Game.new_record:
		lines.append("")
		lines.append("Neuer Rekord!")
	else:
		lines.append("Rekord: %d Runden" % Game.best_rounds)
	over_label.text = "\n".join(lines)
	_open_modal(over_card)


func _seen_help() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load("user://einstellungen.cfg") != OK:
		return false
	return bool(cfg.get_value("hilfe", "gesehen", false))


func _mark_help_seen() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("hilfe", "gesehen", true)
	cfg.save("user://einstellungen.cfg")


## Für die automatischen Screenshots.
func debug_show_field(fid: int) -> void:
	_on_field_tapped(fid)


func debug_show_help() -> void:
	_open_modal(help_card)


func debug_close_all() -> void:
	_close_modal()
	if sheet.visible:
		sheet.visible = false
