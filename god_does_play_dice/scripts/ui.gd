class_name GameUI
extends CanvasLayer
## Oberfläche, Handy zuerst. Oben: Runde, Leben, Rekord, die Leiter (Wiese … Metropole)
## mit Anzahl je Stufe und die zwei Leisten Natur/Zivilisation. Unten: Meteorit, Warten, Hilfe.

const STAGE_ICON = GameState.STAGE_ICON

var world: World
var root: Control

var round_label: Label
var score_label: Label
var stage_label: Label
var stage_icon: TextureRect
var danger_label: Label
var hearts: Array = []
var preview_card: PanelContainer
var preview_label: Label
var toast: PanelContainer
var toast_label: Label
var bolt_btn: Button
var rain_btn: Button
var mode_label: Label
var mode_card: PanelContainer
var sheet: PanelContainer
var sheet_icon: TextureRect
var sheet_title: Label
var sheet_body: Label
var modal_bg: ColorRect
var help_card: PanelContainer
var menu_card: PanelContainer
var over_card: PanelContainer
var ad_card: PanelContainer
var sheet_rain: Button
var sheet_bolt: Button
var miss_pill: Button
var hint_btn: Button
var continue_btn: Button
var over_undo_btn: Button
var undo_btn: Button
var credits_btn: Button
var ad_label: Label
var rain_ready: Button
var _pending: Callable = Callable()
var _pending_cost := 0
var over_label: Label
var bubble_layer: Control
var combo_label: Label

var bonus_mode := ""          # "", "rain" oder "bolt": nächstes angetipptes Feld bekommt den Bonus
var _shown_score := -1
var _score_display := 0.0
var _sheet_field := -1
var _bubbles: Array = []
var _toast_until := 0.0
var _time := 0.0


func setup(w: World) -> void:
	world = w
	layer = 2
	_build()
	world.field_tapped.connect(_on_field_tapped)
	world.preview_changed.connect(_on_preview)
	world.deltas_shown.connect(_on_deltas)
	world.merged.connect(_on_merged)
	world.disaster_shown.connect(_on_disaster)
	world.face_completed.connect(_on_face)
	world.miss_shown.connect(_on_miss)
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
	# Oben ohne Kasten: Punkte und Zeitalter stehen frei auf dem Hintergrund
	var card := PanelContainer.new()
	var clear := StyleBoxEmpty.new()
	clear.content_margin_left = 10
	clear.content_margin_right = 4
	clear.content_margin_top = 6
	card.add_theme_stylebox_override("panel", clear)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	card.add_child(cv)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	cv.add_child(row)
	# Punkte
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", -4)
	sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sv)
	score_label = _label("0", 44, Style.TEXT, true)
	sv.add_child(score_label)
	round_label = _label("Punkte", 12, Style.SOFT, true)
	sv.add_child(round_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sp)
	# Entwicklungsstufe (höchste erreichte Stufe)
	var st := HBoxContainer.new()
	st.add_theme_constant_override("separation", 6)
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(st)
	stage_icon = TextureRect.new()
	stage_icon.custom_minimum_size = Vector2(34, 34)
	stage_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stage_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stage_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(stage_icon)
	var stv := VBoxContainer.new()
	stv.add_theme_constant_override("separation", -3)
	stv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(stv)
	stv.add_child(_label("Zeitalter", 12, Style.SOFT, true))
	stage_label = _label("Wiese", 18, Style.TEXT, true)
	stv.add_child(stage_label)
	var sp_top := Control.new()
	sp_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sp_top)
	# Leben der Welt (klein)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 3)
	lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lv)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 1)
	hrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lv.add_child(hrow)
	for i in Balance.LIVES:
		var h := TextureRect.new()
		h.texture = Style.icon("heart")
		h.custom_minimum_size = Vector2(18, 18)
		h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hrow.add_child(h)
		hearts.append(h)
	# Credits (für Tipp, Schritt zurück, Weiterspielen)
	var cb := Button.new()
	cb.icon = Style.icon("coin")
	cb.add_theme_constant_override("icon_max_width", 22)
	cb.add_theme_font_override("font", Style.bold())
	cb.add_theme_font_size_override("font_size", 17)
	cb.custom_minimum_size = Vector2(0, 46)
	_pill_style(cb, Color.WHITE)
	cb.pressed.connect(_on_credits_pressed)
	row.add_child(cb)
	credits_btn = cb
	row.add_child(_round_button("menu", func() -> void: _open_modal(menu_card), 46))
	# Warnung, nur wenn etwas droht
	danger_label = _label("", 15, Style.BAD, true)
	danger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	danger_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	danger_label.custom_minimum_size = Vector2(300, 0)
	danger_label.visible = false
	cv.add_child(danger_label)

	preview_card = _card(Color(1, 1, 1, 0.97))
	preview_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview_label = _label("", 22, Style.TEXT, true)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_card.add_child(preview_label)
	preview_card.modulate.a = 0.0
	top.add_child(preview_card)
	# Ein Hinweis über dem Würfel: Regen ist bereit (statt Symbolen auf jedem Feld)
	rain_ready = Button.new()
	rain_ready.text = "Regen bereit: Feld antippen"
	rain_ready.icon = Style.icon("rain")
	rain_ready.add_theme_constant_override("icon_max_width", 26)
	rain_ready.add_theme_font_override("font", Style.bold())
	rain_ready.add_theme_font_size_override("font_size", 15)
	rain_ready.add_theme_color_override("font_color", Style.WATER)
	rain_ready.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_pill_style(rain_ready, Color(1, 1, 1, 0.9))
	rain_ready.pressed.connect(func() -> void: _set_bonus_mode("rain"))
	rain_ready.visible = false
	top.add_child(rain_ready)

	# --- Unten ---
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 16)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)
	toast = _card(Color(0.118, 0.133, 0.169, 0.92))
	toast.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	toast_label = _label("", 15, Color.WHITE)
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
	mode_label = _label("", 17, Color.WHITE, true)
	mh.add_child(mode_label)
	var cancel := _round_button("", func() -> void: _set_bonus_mode(""), 40)
	cancel.text = "✕"
	mh.add_child(cancel)
	mode_card.visible = false
	bottom.add_child(mode_card)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	brow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(brow)
	rain_btn = _bonus_button("rain", _on_bonus_pressed.bind("rain"))
	brow.add_child(rain_btn)
	bolt_btn = _bonus_button("lightning", _on_bonus_pressed.bind("bolt"))
	brow.add_child(bolt_btn)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brow.add_child(sp2)
	# Fehlversuche: groß und eindeutig
	miss_pill = Button.new()
	miss_pill.icon = Style.icon("fire")
	miss_pill.add_theme_constant_override("icon_max_width", 26)
	miss_pill.custom_minimum_size = Vector2(76, 50)
	miss_pill.add_theme_font_override("font", Style.bold())
	miss_pill.add_theme_font_size_override("font_size", 18)
	miss_pill.add_theme_color_override("font_color", Style.BAD)
	miss_pill.add_theme_color_override("font_disabled_color", Style.BAD)
	miss_pill.tooltip_text = "Fehlversuche"
	miss_pill.pressed.connect(func() -> void: _on_message("Fehlversuche: Drehungen, die nichts verschmelzen. Beim %d. fängt die gedrehte Reihe Feuer." % Balance.FIRE_AFTER, "info"))
	brow.add_child(miss_pill)
	var sp4 := Control.new()
	sp4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp4.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brow.add_child(sp4)
	var sp3 := Control.new()
	sp3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brow.add_child(sp3)
	undo_btn = _round_button("undo", _on_undo_pressed, 54)
	brow.add_child(undo_btn)
	hint_btn = _round_button("bulb", _on_hint_pressed, 54)
	brow.add_child(hint_btn)
	brow.add_child(_round_button("help", func() -> void: _open_modal(help_card), 54))

	bubble_layer = Control.new()
	bubble_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bubble_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bubble_layer)

	combo_label = _label("", 34, Color("#e0a100"), true)
	combo_label.add_theme_color_override("font_outline_color", Color.WHITE)
	combo_label.add_theme_constant_override("outline_size", 8)
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
	_build_ad()
	_build_over()


func _bonus_button(icon_name: String, cb: Callable) -> Button:
	var b := Button.new()
	b.icon = Style.icon(icon_name)
	b.add_theme_constant_override("icon_max_width", 30)
	b.custom_minimum_size = Vector2(72, 54)
	b.add_theme_font_override("font", Style.bold())
	b.add_theme_font_size_override("font_size", 18)
	_pill_style(b, Color.WHITE)
	b.pressed.connect(cb)
	return b


func _on_bonus_pressed(kind: String) -> void:
	_set_bonus_mode("" if bonus_mode == kind else kind)


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
	# Direkt am Feld handeln: gießen oder Blitz
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	v.add_child(acts)
	sheet_rain = _wide_button("Gießen", Color("#3fa7e8"), Color.WHITE)
	sheet_rain.icon = Style.icon("rain")
	sheet_rain.add_theme_constant_override("icon_max_width", 30)
	sheet_rain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_rain.pressed.connect(_sheet_bonus.bind("rain"))
	acts.add_child(sheet_rain)
	sheet_bolt = _wide_button("Blitz", Color("#f2a900"), Color.WHITE)
	sheet_bolt.icon = Style.icon("lightning")
	sheet_bolt.add_theme_constant_override("icon_max_width", 30)
	sheet_bolt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_bolt.pressed.connect(_sheet_bonus.bind("bolt"))
	acts.add_child(sheet_bolt)


func _sheet_bonus(kind: String) -> void:
	var fid := _sheet_field
	if fid < 0:
		return
	var row: Array = world.screen_row(fid) if kind == "bolt" else []
	_close_sheet()
	if Game.use_bonus(kind, fid, row):
		_bubble(fid, Game.praise(), "up", Color("#4a90d9"))


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
	v.add_child(_help_row("up", "Drei gleiche Felder in einer Reihe verschmelzen: Das Feld, das zuletzt dazugekommen ist, steigt eine Stufe auf, die beiden anderen bleiben, wie sie sind. Das gibt Punkte. Mehrere Verschmelzungen in einem Zug sind eine Kombo: jede zählt mehr (×2, ×3 …)."))
	v.add_child(_help_row("smallforest", "Die Leiter: Wiese → kleiner Wald → großer Wald → Hütte → Haus → Dorf → Stadt → Großstadt → Metropole. Ab dem kleinen Wald zählen auch Diagonalen (quer über die Seite)."))
	v.add_child(_help_row("fire", "Jede Drehung, die nichts verschmilzt, ist ein Fehlversuch (unten in der Mitte gezählt). Beim %d. fängt die gedrehte Reihe Feuer und brennt jeden Zug eine Stufe ab." % Balance.FIRE_AFTER))
	v.add_child(_help_row("rain", "Regen (alle %d Punkte): Tippe ein Feld an und gieß es. Es steigt eine Stufe auf, ein brennendes Feld wird gelöscht. Ein Tropfen über dem Feld heißt: Gießen lohnt sich hier. Wiese wächst nur durch Regen." % Balance.RAIN_EVERY))
	v.add_child(_help_row("lightning", "Blitz (alle %d Punkte): Eine ganze Reihe steigt eine Stufe auf." % Balance.BOLT_EVERY))
	v.add_child(_help_row("quake", "Mehr als %d%% Zivilisation: Erdbeben, die Reihe mit der meisten Zivilisation fällt eine Stufe zurück." % int(round(Balance.CIVILISATION_MAX * 100.0))))
	v.add_child(_help_row("bulb", "Tipp: Die lohnendste Drehung leuchtet auf. Kostet einen Credit, den gibt es für eine kurze Werbung."))
	v.add_child(_help_row("heart", "Herzen sind die Leben der Welt. Ein Erdbeben (mehr als %d%% Zivilisation) kostet eines, jedes neue Zeitalter gibt eines zurück. Sind alle weg oder ist nichts mehr zu verbinden, ist das Spiel vorbei. Einmal kannst du mit Werbung weiterspielen." % int(round(Balance.CIVILISATION_MAX * 100.0))))
	v.add_child(_help_row("trophy", "Zeitalter: Urzeit, Steinzeit (Hütte), Bronzezeit (Haus), Antike (Dorf), Mittelalter (Stadt), Industriezeitalter (Großstadt), Moderne (Metropole). Jedes neue gibt ein Leben zurück. Im Menü gibt es auch 40 Runden."))
	var go := _wide_button("Los geht's", Style.ACCENT, Color.WHITE)
	go.pressed.connect(_on_help_done)
	v.add_child(go)


func _build_menu() -> void:
	menu_card = _modal_card("Pause")
	var v: VBoxContainer = menu_card.get_child(0)
	var cont := _wide_button("Weiter", Style.ACCENT, Color.WHITE)
	cont.pressed.connect(func() -> void: _close_modal())
	v.add_child(cont)
	var endless_btn := _wide_button("Neues Spiel: Endlos", Color.WHITE, Style.TEXT)
	endless_btn.pressed.connect(_restart_mode.bind(1))
	v.add_child(endless_btn)
	var challenge_btn := _wide_button("Neues Spiel: 40 Runden", Color.WHITE, Style.TEXT)
	challenge_btn.pressed.connect(_restart_mode.bind(0))
	v.add_child(challenge_btn)
	var help := _wide_button("So geht's", Color.WHITE, Style.TEXT)
	help.pressed.connect(_show_help)
	v.add_child(help)
	var tut := _wide_button("Tutorial nochmal", Color.WHITE, Style.TEXT)
	tut.pressed.connect(_restart_tutorial)
	v.add_child(tut)


## „Werbung ansehen“ für einen Tipp. Noch ein Platzhalter: Die echte Werbung kommt später.
## Credits: eine Währung für alle Hilfen (Tipp, Schritt zurück, Weiterspielen).
## Reichen sie nicht, wird eine kurze Werbung angeboten (im Prototyp ein Platzhalter).
func _build_ad() -> void:
	ad_card = _modal_card("Credits")
	var v: VBoxContainer = ad_card.get_child(0)
	ad_label = _label("", 17, Style.TEXT)
	ad_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ad_label.custom_minimum_size = Vector2(300, 0)
	ad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ad_label)
	var watch := _wide_button("Werbung ansehen (+%d)" % Balance.CREDITS_PER_AD, Style.ACCENT, Color.WHITE)
	watch.icon = Style.icon("coin")
	watch.add_theme_constant_override("icon_max_width", 24)
	watch.pressed.connect(_on_ad_watched)
	v.add_child(watch)
	var no := _wide_button("Nein danke", Color.WHITE, Style.TEXT)
	no.pressed.connect(_on_ad_declined)
	v.add_child(no)


## Kostet cost Credits und führt dann action aus. Reicht es nicht, wird erst eine Werbung angeboten.
func _pay(cost: int, what: String, action: Callable) -> void:
	if Game.spend(cost):
		action.call()
		refresh()
		return
	_pending = action
	_pending_cost = cost
	ad_label.text = "%s kostet %d %s. Du hast %d.\nSchau eine kurze Werbung an und bekomm %d %s." % [
		what, cost, "Credit" if cost == 1 else "Credits", Game.credits,
		Balance.CREDITS_PER_AD, "Credit" if Balance.CREDITS_PER_AD == 1 else "Credits"]
	_open_modal(ad_card)


func _on_ad_watched() -> void:
	_close_modal()
	Game.reward_ad()
	_on_message("Danke! +%d Credit." % Balance.CREDITS_PER_AD, "good")
	refresh()
	if _pending.is_valid():
		var act := _pending
		_pending = Callable()
		_pay(_pending_cost, "Das", act)


func _on_ad_declined() -> void:
	_pending = Callable()
	_close_modal()
	if Game.over:
		_open_modal(over_card)


func _on_credits_pressed() -> void:
	_pending = Callable()
	ad_label.text = "Credits brauchst du für Tipp (%d), Schritt zurück (%d) und Weiterspielen (%d).\nDu hast %d." % [
		Balance.HINT_COST, Balance.UNDO_COST, Balance.CONTINUE_COST, Game.credits]
	_open_modal(ad_card)


func _on_hint_pressed() -> void:
	if Game.busy or Game.over or world.animating:
		return
	if Game.state.best_move().is_empty():
		_on_message("Auch in zwei Zügen bringt keine Drehung etwas. Probier Regen oder Blitz.", "info")
		return
	_pay(Balance.HINT_COST, "Ein Tipp", _use_hint)


func _use_hint() -> void:
	var best := world.show_hint()
	if int(best.get("steps", 1)) == 2:
		_on_message("Diese Scheibe drehen: Danach kannst du verschmelzen.", "info")
	else:
		_on_message("Diese Scheibe drehen: Das verschmilzt sofort.", "info")


func _on_undo_pressed() -> void:
	if world.animating or not Game.can_undo():
		_on_message("Gerade gibt es keinen Schritt zum Zurücknehmen.", "info")
		return
	_pay(Balance.UNDO_COST, "Ein Schritt zurück", Game.undo)


func _build_over() -> void:
	over_card = _modal_card("Die Welt ist gestorben")
	var v: VBoxContainer = over_card.get_child(0)
	over_label = _label("", 19, Style.TEXT)
	over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	over_label.custom_minimum_size = Vector2(300, 0)
	v.add_child(over_label)
	continue_btn = _wide_button("Weiterspielen (%d Credits)" % Balance.CONTINUE_COST, Style.WATER, Color.WHITE)
	continue_btn.pressed.connect(_on_continue)
	v.add_child(continue_btn)
	over_undo_btn = _wide_button("Einen Schritt zurück (%d Credit)" % Balance.UNDO_COST, Color.WHITE, Style.TEXT)
	over_undo_btn.pressed.connect(_on_over_undo)
	v.add_child(over_undo_btn)
	var again := _wide_button("Nochmal", Style.ACCENT, Color.WHITE)
	again.pressed.connect(_restart)
	v.add_child(again)


func _on_continue() -> void:
	_close_modal()
	_pay(Balance.CONTINUE_COST, "Weiterspielen", Game.continue_game)


func _on_over_undo() -> void:
	_close_modal()
	_pay(Balance.UNDO_COST, "Ein Schritt zurück", Game.undo)


# --- Bausteine ---------------------------------------------------------------

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = Style.font()
	t.default_font_size = 18
	t.set_color("font_color", "Label", Style.TEXT)
	t.set_stylebox("panel", "PanelContainer", _sb(Style.PANEL, 18, 14))
	var normal := _sb(Color.WHITE, 16, 10, true)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", normal)
	t.set_stylebox("pressed", "Button", _sb(Color("#f0ede8"), 16, 10, true))
	t.set_stylebox("disabled", "Button", _sb(Color(1, 1, 1, 0.5), 16, 10, true))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", Style.TEXT)
	t.set_color("font_disabled_color", "Button", Color("#b4ada3"))
	return t


func _sb(bg: Color, radius: int, pad: int, border: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	if border:
		s.set_border_width_all(1)
		s.border_color = Style.LINE
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
	var s := _sb(bg, mini(radius, 18), 12, true)
	s.shadow_size = 6
	s.shadow_color = Color(0.1, 0.12, 0.2, 0.05)
	s.shadow_offset = Vector2(0, 2)
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
	var n := _sb(bg, 16, 8, true)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("pressed", _sb(bg.darkened(0.06), 16, 8, true))
	b.add_theme_stylebox_override("disabled", _sb(Color(1, 1, 1, 0.45), 16, 8, true))
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
	if gs.endless:
		round_label.text = "Punkte"
	else:
		round_label.text = "Punkte · Runde %d/%d" % [mini(gs.turn, Balance.MAX_ROUNDS), Balance.MAX_ROUNDS]
	if _shown_score < 0:
		_score_display = gs.score
	elif gs.score != _shown_score:
		_pop(score_label)
	_shown_score = gs.score
	var best_stage := clampi(gs.best_stage, 1, Balance.MAX_STAGE)
	if stage_label.text != gs.age_name() and _shown_score > 0:
		_pop(stage_icon)
	stage_label.text = gs.age_name()
	stage_icon.texture = Style.icon(STAGE_ICON[best_stage])
	if rain_btn.text != "" and gs.rain > int(rain_btn.text):
		_pop(rain_btn)
	if bolt_btn.text != "" and gs.bolts > int(bolt_btn.text):
		_pop(bolt_btn)
	credits_btn.text = str(Game.credits)
	rain_ready.visible = gs.rain > 0 and not Game.over and bonus_mode == ""
	rain_btn.text = str(gs.rain)
	bolt_btn.text = str(gs.bolts)
	miss_pill.text = "%d/%d" % [gs.misses, Balance.FIRE_AFTER]
	_pill_style(miss_pill, Color("#ffe1d6") if gs.misses >= Balance.FIRE_AFTER - 1 else Color.WHITE)
	for i in hearts.size():
		(hearts[i] as TextureRect).texture = Style.icon("heart" if i < gs.lives else "heart_empty")
	var th := gs.threat()
	var warn := ""
	if th != "":
		warn = "%s! Bring das in Ordnung, sonst: %s" % [GameState.DISASTER_WHY[th], GameState.DISASTER_NAME[th]]
	elif gs.misses == Balance.FIRE_AFTER - 1:
		warn = "Noch ein Fehlversuch, dann brennt die Reihe!"
	danger_label.text = warn
	danger_label.visible = warn != "" and not Game.over
	_update_buttons()
	if _sheet_field >= 0 and sheet.visible:
		_fill_sheet(_sheet_field)


func _update_buttons() -> void:
	var gs := Game.state
	var blocked := Game.busy or Game.over or world.animating
	hint_btn.disabled = blocked
	undo_btn.disabled = blocked or not Game.can_undo()
	rain_btn.disabled = blocked or gs.rain <= 0
	bolt_btn.disabled = blocked or gs.bolts <= 0


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
	if Game.state == null or score_label == null:
		return
	if rain_ready.visible:
		rain_ready.pivot_offset = rain_ready.size * 0.5
		var k := 0.5 + 0.5 * sin(_time * 3.0)
		rain_ready.scale = Vector2.ONE * (0.97 + 0.05 * k)
	var target := float(Game.state.score)
	_score_display = move_toward(_score_display, target, maxf(1.0, absf(target - _score_display)) * delta * 4.0)
	score_label.text = str(int(round(_score_display)))
	_update_buttons()


# =============================================================================
# Bonus: Regen oder Meteorit
# =============================================================================

func _set_bonus_mode(kind: String) -> void:
	bonus_mode = kind
	mode_card.visible = kind != ""
	world.show_rain_spots(kind == "rain")
	if rain_ready != null:
		rain_ready.visible = kind == "" and Game.state.rain > 0 and not Game.over
	if kind == "rain":
		mode_label.text = "Tippe auf ein Feld (Wolke = lohnt sich):\nEs steigt auf oder wird gelöscht"
	elif kind == "bolt":
		mode_label.text = "Tippe auf ein Feld: Der Blitz\nhebt seine waagrechte Reihe"
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
	var merges := arranged.lines(arranged.moved).size()
	var kind := ""
	for e in info["events"]:
		if str(e["type"]) == "disaster":
			kind = str(e["kind"])
	if kind == "" and not Game.tutorial():
		tw.tween_property(preview_card, "modulate:a", 0.0, 0.15)
		return
	var parts := PackedStringArray()
	if Game.tutorial():
		parts.append("%d× Verschmelzen  ·  +%d Punkte" % [merges, int(info["gain"])] if merges > 0 else "Keine neue Dreierreihe")
		preview_label.add_theme_color_override("font_color", Color("#c98a00") if merges > 0 else Style.SOFT)
	if kind != "":
		parts.append("Danach: %s! (%s)" % [GameState.DISASTER_NAME[kind], GameState.DISASTER_WHY[kind]])
		preview_label.add_theme_color_override("font_color", Style.BAD)
	preview_label.text = "\n".join(parts)
	tw.tween_property(preview_card, "modulate:a", 1.0, 0.12)


# =============================================================================
# Info-Karte
# =============================================================================

func _on_field_tapped(fid: int) -> void:
	if bonus_mode != "":
		var row: Array = world.screen_row(fid) if bonus_mode == "bolt" else []
		if Game.use_bonus(bonus_mode, fid, row):
			_set_bonus_mode("")
			_bubble(fid, Game.praise(), "up", Color("#4a90d9"))
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
		lines.append("Leere Erde. Mit Regen (Bonus) wird sie zur Wiese.")
	elif f.stage >= Balance.MAX_STAGE:
		lines.append("Höchste Stufe.")
	else:
		lines.append("Dreh 3 davon in eine Reihe: Das zuletzt dazugekommene wird %s." % GameState.stage_name(f.stage + 1))
	if f.stage >= Balance.POLLUTION_FROM:
		lines.append("Zerstört jede Runde ein Natur-Feld daneben.")
	if f.burning:
		lines.insert(0, "Brennt! Verliert jeden Zug eine Stufe, bis du es gießt.")
	elif f.is_civilisation():
		lines.append("Zählt zur Zivilisation (mehr als %d%% lösen ein Erdbeben aus)." % int(round(Balance.CIVILISATION_MAX * 100.0)))
	sheet_body.text = "\n".join(lines)
	var gs := Game.state
	var blocked := Game.busy or Game.over or world.animating
	sheet_rain.visible = gs.rain > 0
	sheet_rain.disabled = blocked or gs.can_bonus("rain", f) != ""
	if f.burning:
		sheet_rain.text = "Löschen (%d)" % gs.rain
	elif f.stage < Balance.MAX_STAGE:
		sheet_rain.text = "Gießen: %s (%d)" % [GameState.STAGE_SHORT[f.stage + 1], gs.rain]
	else:
		sheet_rain.text = "Höchste Stufe"
	sheet_bolt.visible = gs.bolts > 0
	sheet_bolt.disabled = blocked
	sheet_bolt.text = "Blitz auf Reihe (%d)" % gs.bolts
	(sheet_rain.get_parent() as Control).visible = sheet_rain.visible or sheet_bolt.visible


# =============================================================================
# Blasen, Meldungen, Modale
# =============================================================================

func _on_merged(fid: int, points: int, combo: int, stage: int) -> void:
	_bubble(fid, "+%d" % points, "up", Color("#f2a900"))
	if combo >= 2:
		combo_label.text = "%s! Kombo ×%d" % [GameState.stage_name(stage), combo]
	else:
		combo_label.text = GameState.stage_name(stage) + "!"
	combo_label.add_theme_color_override("font_color", Color("#e0a100"))
	_pop_banner()


func _on_miss(fid: int, count: int) -> void:
	_pop(miss_pill)
	if fid >= 0:
		_bubble(fid, "Fehlversuch %d/%d" % [count, Balance.FIRE_AFTER], "fire", Color("#e8772e"))


func _on_face(fid: int, points: int, stage: int) -> void:
	combo_label.text = "Ganze Seite: %s!" % GameState.stage_name(stage)
	_on_message(Game.praise(), "good")
	combo_label.add_theme_color_override("font_color", Color("#e0a100"))
	_pop_banner()
	if fid >= 0:
		_bubble(fid, "+%d" % points, "up", Color("#f2a900"))


func _on_disaster(kind: String, fid: int) -> void:
	combo_label.text = GameState.DISASTER_NAME[kind] + "!"
	combo_label.add_theme_color_override("font_color", Style.BAD)
	_pop_banner()
	if fid >= 0 and (kind == "quake" or Balance.FIRE_COSTS_LIFE):
		_bubble(fid, "-1 Leben", "heart", Style.BAD)


func _pop_banner() -> void:
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
	refresh()


func _bubble(fid: int, text: String, icon_name: String, color: Color) -> void:
	var b := Button.new()
	b.text = text
	b.icon = Style.icon(icon_name)
	b.add_theme_constant_override("icon_max_width", 18)
	b.add_theme_font_override("font", Style.bold())
	b.add_theme_font_size_override("font_size", 13)
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
	var bg := Color(0.118, 0.133, 0.169, 0.92)
	if kind == "bad":
		bg = Color("#b8372e")
	elif kind == "good":
		bg = Color("#2a7d4b")
	toast.add_theme_stylebox_override("panel", _sb(bg, 14, 10))
	toast.modulate.a = 1.0
	_toast_until = _time + 3.0
	toast.pivot_offset = toast.size * 0.5
	toast.scale = Vector2(0.9, 0.9)
	var tw := toast.create_tween()
	tw.tween_property(toast, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_help_done() -> void:
	_mark_help_seen()
	_close_modal()


func _restart_tutorial() -> void:
	_close_modal()
	Game.restart_tutorial()


func _restart() -> void:
	_close_modal()
	Game.new_game()


func _restart_mode(endless_mode: int) -> void:
	_close_modal()
	Game.new_game(0, endless_mode)


func _show_help() -> void:
	_close_modal()
	_open_modal(help_card)


func _open_modal(card: PanelContainer) -> void:
	for c in [help_card, menu_card, over_card, ad_card]:
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
	for c in [help_card, menu_card, over_card, ad_card]:
		(c as Control).visible = false
	modal_bg.visible = false


func _on_new_game() -> void:
	_close_modal()
	_set_bonus_mode("")
	sheet.visible = false
	_sheet_field = -1
	_shown_score = -1
	for bd in _bubbles:
		(bd["node"] as Control).queue_free()
	_bubbles.clear()
	refresh()


func _on_game_over() -> void:
	var gs := Game.state
	var lines := PackedStringArray()
	var title: Label = (over_card.get_child(0) as VBoxContainer).get_child(0)
	if gs.stuck() and not gs.died():
		title.text = "Nichts mehr zu verbinden"
		lines.append("Keine Stufe hat mehr drei Felder, und es gibt keinen Regen und keinen Blitz.")
	elif gs.died():
		title.text = "Die Welt ist gestorben"
		lines.append("Zu viele Katastrophen.")
		if gs.last_disaster != "":
			var why: String = GameState.DISASTER_WHY[gs.last_disaster]
			lines.append("Zuletzt: %s (%s)." % [GameState.DISASTER_NAME[gs.last_disaster], why.left(1).to_lower() + why.substr(1)])
	else:
		title.text = "Geschafft!"
	lines.append("")
	lines.append("Punkte: %d" % gs.score)
	lines.append("Entwicklung: %s" % GameState.stage_name(gs.best_stage))
	lines.append("Runden: %d · %s" % [Game.rounds_survived(), gs.age_name()])
	if Game.new_record:
		lines.append("Neuer Rekord!")
	else:
		lines.append("Rekord: %d Punkte" % Game.best)
	over_label.text = "\n".join(lines)
	continue_btn.visible = Game.can_continue()
	over_undo_btn.visible = Game.can_undo()
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
	_set_bonus_mode("")
	sheet.visible = false
