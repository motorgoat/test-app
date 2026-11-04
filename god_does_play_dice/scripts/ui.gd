class_name GameUI
extends CanvasLayer
## Oberfläche, Handy zuerst. Feste Zonen, damit sich nichts überlappt:
##   oben Kopfzeile (Menü · Punkte · Credits, darunter Zeitalter · Flammen · Herzen),
##   darunter die Meldungsspur (Tutorial, Vorschau, Meldungen), Mitte der Würfel,
##   unten die Kontextzone (Feld-Karte oder Bonus-Hinweis) über dem schwebenden Dock.
## Beim Drehen erscheint ganz oben ein roter Streifen: dorthin ziehen = abbrechen.

const STAGE_ICON = GameState.STAGE_ICON

var world: World
var root: Control
var _insets := Vector2.ZERO

# --- Kopfzeile ---
var top: VBoxContainer
var menu_b: Button
var score_box: VBoxContainer
var score_label: Label
var round_label: Label
var credits_btn: Button
var age_chip: PanelContainer
var stage_icon: TextureRect
var stage_label: Label
var flame_chip: PanelContainer
var _flame_sb: StyleBoxFlat
var flames_row: HBoxContainer
var miss_flames: Array = []
var hearts_chip: PanelContainer
var hearts_row: HBoxContainer
var hearts: Array = []

# --- Meldungsspur ---
var tut_card: PanelContainer
var tut_caps: Label
var tut_label: Label
var tut_dots: Array = []
var tut_finger: TextureRect
var preview_card: PanelContainer
var _preview_sb: StyleBoxFlat
var preview_icon: TextureRect
var preview_label: Label
var toast: PanelContainer
var toast_tile: PanelContainer
var toast_icon: TextureRect
var toast_label: Label
var banner: PanelContainer
var banner_icon: TextureRect
var banner_caps: Label
var banner_text: Label

# --- Kontextzone & Dock ---
var sheet: PanelContainer
var sheet_tile: PanelContainer
var sheet_title: Label
var sheet_caps: Label
var sheet_ladder: HBoxContainer
var sheet_from: Array = []
var sheet_next: TextureRect
var sheet_body: Label
var sheet_acts: HBoxContainer
var sheet_rain: Button
var sheet_bolt: Button
var mode_card: PanelContainer
var mode_tile: PanelContainer
var mode_label: Label
var mode_hint: Label
var dock: PanelContainer
var undo_btn: Button
var rain_btn: Button
var bolt_btn: Button
var monsoon_btn: Button
var hint_btn: Button

# --- Überlagerungen ---
var bubble_layer: Control
var gift_layer: Control
var coach_arrow: Panel
var coach: PanelContainer
var coach_tile: PanelContainer
var coach_icon: TextureRect
var coach_label: Label
var tip_card: PanelContainer
var tip_tile: PanelContainer
var tip_icon: TextureRect
var tip_title: Label
var tip_body: Label
var cancel_strip: PanelContainer
var cancel_icon: TextureRect
var cancel_label: Label

# --- Dialoge ---
var modal_bg: ColorRect
var help_card: PanelContainer
var menu_card: PanelContainer
var over_card: PanelContainer
var ad_card: PanelContainer
var ad_label: Label
var continue_btn: Button
var over_undo_btn: Button
var over_tile: PanelContainer
var over_title: Label
var over_score: Label
var over_age_icon: TextureRect
var over_age_label: Label
var _over_rec_sb: StyleBoxFlat
var over_rec_label: Label
var _menu_rows: Dictionary = {}
var _music_switch: Button
var _sfx_switch: Button
var _profile_btn: Button
var buy_card: PanelContainer
var buy_tile: PanelContainer
var buy_label: Label
var buy_btn: Button
var _buy_kind := ""
var confirm_card: PanelContainer
var _confirm_key := ""        # was nach „Ja“ startet: Spielart oder "tutorial"
var _help_ladder: Array = []
var _help_bolt_row: Control
var _help_monsoon_row: Control
const SLOT_W := 92.0          # Breite eines Platzes im Dock (das Dock wächst mit den sichtbaren Plätzen)

# --- Zustand ---
var bonus_mode := ""          # "", "rain", "bolt" oder "monsoon": nächstes angetipptes Feld bekommt den Bonus
var _shown_score := -1
var _score_display := 0.0
var _sheet_field := -1
var _bubbles: Array = []
var _time := 0.0
var _twisting := false
var _last_rain := -1
var _last_bolts := -1
var _last_monsoons := -1
var _last_lives := -1
var _last_age := ""
var _last_credits := -1
var _hud_tut := false         # Kopfzeile/Dock gerade im Tutorial-Zustand (reduziert)
var _own_twists := 0          # eigene Drehungen seit dem Tutorial (für die Hinweise)
var _fire_seen := false
const SETTINGS_PATH := "user://einstellungen.cfg"   # nur für „Hilfe gesehen“; Ton liest und schreibt Game

# Tutorial
var _demo_at := 0.0
var _auto_at := INF
var _auto_fired := false      # der vorgeführte erste Zug lief schon
var _tut_step_at := 0.0       # wann der aktuelle Tutorial-Schritt begann
var _tut_merged := false
const TUT_STEPS = [
	{"wait": "auto", "text": "Drei gleiche in einer Reihe – sie wachsen!"},
	{"wait": "twist", "text": "Jetzt du! Wisch über die leuchtende Reihe."},
]

# Hinweise im richtigen Moment (nicht blockierend, einer nach dem anderen, je einmal)
const COACH = {
	"miss": "Hier ist nichts gewachsen. Bei 3 Flammen fängt die Reihe Feuer.",
	"rain": "Das ist Regen. Er lässt ein Feld wachsen. Tippe drauf – dann leuchten die Felder, die du gießen kannst.",
	"fire": "Feuer! Gieß die brennenden Felder mit Regen – sonst schrumpfen sie. Jedes Feuer kostet ein Herz.",
	"bolt": "Blitz! Drei gleiche haben sich an einer Ecke getroffen. Tippe auf Blitz und dann auf ein leuchtendes Eckfeld.",
	"monsoon": "Monsun! Er lässt eine ganze Seite wachsen. Tippe drauf und dann auf den Würfel.",
	"hint": "Kommst du nicht weiter? Tipp zeigt dir die beste Drehung. Kostet 1 Münze.",
	"undo": "Vertan? Zurück nimmt deinen letzten Zug zurück. Kostet 1 Münze.",
	"coins": "Das sind deine Münzen. Neue gibt es für ein kurzes Video.",
	"age": "",      # Text kommt aus _coach_text (Zeitalter und was als Nächstes kommt)
	"hold": "Tipp: Halte ein Symbol gedrückt – dann erklärt es sich.",
}
const COACH_ICON = {"miss": "fire", "rain": "rain", "bolt": "lightning", "monsoon": "monsoon", "fire": "fire", "hold": "hand",
	"hint": "bulb", "undo": "undo", "coins": "coin"}
## Mit Artikel, für „Als Nächstes: Antike – bau ein Haus.“
const STAGE_WITH_ARTICLE = ["Erde", "eine Wiese", "einen kleinen Wald", "einen großen Wald", "eine Hütte", "ein Haus", "ein Dorf", "eine Stadt", "eine Großstadt", "eine Metropole"]
const AGE_PREP = {"Mittelalter": "im", "Industriezeitalter": "im"}
var _coach_queue: Array = []
var _coach_until := INF
var _coach_ready_at := 0.0
var _coach_twist := -1        # bei welcher eigenen Drehung zuletzt ein Hinweis kam (höchstens einer pro Zug)
var _miss_streak := 0         # Fehlversuche hintereinander (zeigt irgendwann den Tipp)
var _calm_since := 0.0        # seit wann nichts passiert (nach 15 s kommt der Tipp dazu)
var _tut_tries := 0           # Tutorial-Schritt 2: Fehlversuche (beim 2. geht es trotzdem weiter)
var _demo_until := 0.0        # die Hand führt gerade eine Drehung vor (kein Abbrechen-Streifen)
var _coach_in_hud := false    # der Hinweis hängt oben (dann wartet die Meldungsspur, keine Überlappung)

# Erklärung bei langem Drücken: TOOLTIPS[key] = {icon, title, body}; dynamische Teile in _tooltip_for.
const TOOLTIPS = {
	"menu": {"icon": "menu", "title": "Menü", "body": "Pause, neues Spiel, Ton und Hilfe."},
	"score": {"icon": "trophy", "title": "Punkte", "body": "Jedes Wachsen bringt Punkte. Wächst mehr auf einmal, gibt es extra."},
	"credits": {"icon": "coin", "title": "Münzen", "body": "Damit bezahlst du Tipp und Zurück. Neue gibt es für ein kurzes Video."},
	"age": {"icon": "hut", "title": "Zeitalter", "body": "Zeigt, wie weit deine Welt ist."},
	"flames": {"icon": "fire", "title": "Flammen", "body": "Wächst bei einer Drehung nichts, leuchtet eine Flamme. Bei 3 Flammen fängt die gedrehte Reihe Feuer."},
	"hearts": {"icon": "heart", "title": "Herzen", "body": "Jedes Feuer kostet ein Herz. Sind alle weg, ist das Spiel vorbei."},
	"undo": {"icon": "undo", "title": "Zurück", "body": "Nimmt deinen letzten Zug zurück."},
	"rain": {"icon": "rain", "title": "Regen", "body": "Lässt ein Feld wachsen oder löscht Feuer. Tippe drauf, dann auf ein leuchtendes Feld."},
	"bolt": {"icon": "lightning", "title": "Blitz", "body": "Gibt es, wenn sich an einer Ecke 3 gleiche treffen. Tippe drauf, dann auf ein leuchtendes Eckfeld: Die schräge Linie wächst."},
	"monsoon": {"icon": "monsoon", "title": "Monsun", "body": "Lässt eine ganze Seite wachsen – alle 9 Felder. Tippe drauf, dann auf den Würfel."},
	"hint": {"icon": "bulb", "title": "Tipp", "body": "Zeigt dir die beste Drehung."},
	"profile": {"icon": "profile", "title": "Profil", "body": "Kommt bald: dein Profil mit Rekorden und Erfolgen."},
	"mode_close": {"icon": "close", "title": "Abbrechen", "body": "Doch nicht? Damit legst du den Bonus wieder weg."},
	"mode_einfach": {"icon": "meadow", "title": "Einfach", "body": "Ganze Gruppen wachsen mit. 3 Herzen."},
	"mode_mittel": {"icon": "smallforest", "title": "Mittel", "body": "Auch schräge Reihen zählen. 3 Herzen."},
	"mode_schwer": {"icon": "nature", "title": "Schwer", "body": "Nur gerade Reihen zählen. 3 Herzen."},
	"mode_challenge": {"icon": "trophy", "title": "40 Drehungen", "body": "Wie viele Punkte schaffst du in 40 Drehungen? Regeln wie Mittel, 3 Herzen."},
}
var _lp_node: Control = null
var _lp_t := 0.0
var _lp_pos := Vector2.ZERO
var _lp_fired := false
var _lp_swallow: Control = null
var _tip_hide_at := INF
var _tip_owner: Control = null

# Meldungen (oben in der Spur, nacheinander)
const TOAST_ICON = {"good": "check", "bad": "fire", "info": "info", "reward": "coin"}
var _toasts: Array = []
var _toast_busy := false
var _toast_leaving := false
var _toast_until := 0.0
var _toast_free_at := 0.0

# Dialoge
var _modal: Control = null
var _modal_closable := true
var _pending: Callable = Callable()
var _pending_cost := 0

const SLOT_TINT = {"undo": Color("#F2EDE5"), "rain": Color("#E3EFFC"), "bolt": Color("#FDF0DA"), "monsoon": Color("#E7EBFA"), "hint": Color("#FDF0DA")}
const SLOT_COLOR = {"undo": Color("#4B5163"), "rain": Color("#3B8EEA"), "bolt": Color("#F2A93B"), "monsoon": Color("#5B74D6"), "hint": Color("#F2A93B")}
const MODES = [
	{"key": "einfach", "icon": "meadow", "title": "Einfach", "sub": "Ganze Gruppen wachsen mit", "tint": 1},
	{"key": "mittel", "icon": "smallforest", "title": "Mittel", "sub": "Auch schräge Reihen", "tint": 2},
	{"key": "schwer", "icon": "nature", "title": "Schwer", "sub": "Nur gerade Reihen", "tint": 3},
	{"key": "challenge", "icon": "trophy", "title": "40 Drehungen · Mittel", "sub": "Wie viele Punkte schaffst du?", "tint": 4},
]


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
	world.twist_state.connect(_on_twist_state)
	world.cancel_hover.connect(_on_cancel_hover)
	world.bolt_drawn.connect(_on_bolt_drawn)
	world.tutorial_tap.connect(_on_tutorial_tap)
	world.cancel_zone = cancel_strip
	Game.state_changed.connect(refresh)
	Game.new_game_started.connect(_on_new_game)
	Game.message.connect(_on_message)
	Game.game_over.connect(_on_game_over)
	Game.move_done.connect(_on_move_done)
	Game.tutorial_changed.connect(_tutorial_show)
	refresh()
	_tutorial_show()
	_hud_entrance.call_deferred()


# =============================================================================
# Aufbau
# =============================================================================

func _build() -> void:
	_insets = _safe_insets()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	# Reihenfolge = Zeichenreihenfolge (hinten nach vorne)
	_build_top()
	_build_lane()
	_build_banner()
	bubble_layer = _layer()
	_build_context()
	_build_dock()
	gift_layer = _layer()
	tut_finger = TextureRect.new()
	tut_finger.texture = Style.icon("touch")
	tut_finger.size = Vector2(72, 72)
	tut_finger.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tut_finger.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tut_finger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_finger.modulate.a = 0.0
	root.add_child(tut_finger)
	_build_coach()
	_build_cancel_strip()
	modal_bg = ColorRect.new()
	modal_bg.color = Style.SCRIM
	modal_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_bg.gui_input.connect(_on_backdrop_input)
	modal_bg.visible = false
	modal_bg.modulate.a = 0.0
	root.add_child(modal_bg)
	_build_help()
	_build_menu()
	_build_ad()
	_build_buy()
	_build_confirm()
	_build_over()
	_build_tip()      # ganz oben: Erklärungen gehen auch in Dialogen


func _layer() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	return c


func _hbox(sep: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


func _vbox(sep: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _build_top() -> void:
	top = _vbox(10)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = Style.MARGIN
	top.offset_right = -Style.MARGIN
	_home_top()
	root.add_child(top)

	# Zeile 1: [Menü] · große Punkte · [Credits]; beide Seiten gleich breit, damit die Punkte mittig stehen
	var row1 := _hbox(0)
	top.add_child(row1)
	var lcl := _hbox(0)
	lcl.custom_minimum_size = Vector2(112, 0)
	row1.add_child(lcl)
	menu_b = _icon_button("menu", _open_menu, 52, false, "menu")
	lcl.add_child(menu_b)
	score_box = _vbox(-18)
	score_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_child(score_box)
	score_label = _label("0", Style.F_SCORE, Style.INK, Style.W_BLACK)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_box.add_child(score_label)
	round_label = _caps("Punkte")
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_box.add_child(round_label)
	_explain_only(score_box, "score")
	var rcl := _hbox(0)
	rcl.custom_minimum_size = Vector2(112, 0)
	rcl.alignment = BoxContainer.ALIGNMENT_END
	row1.add_child(rcl)
	credits_btn = Button.new()
	credits_btn.icon = Style.icon("coin")
	credits_btn.add_theme_constant_override("icon_max_width", 24)
	credits_btn.add_theme_constant_override("h_separation", 8)
	credits_btn.add_theme_font_override("font", Style.black())
	credits_btn.add_theme_font_size_override("font_size", 18)
	credits_btn.custom_minimum_size = Vector2(92, 48)
	credits_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Style.skin(credits_btn, _chip_style(Style.GLASS, 24), Style.box(Style.SURFACE_3, 24, 14, 6), Style.INK)
	_tap_or_explain(credits_btn, _on_credits_pressed, "credits")
	rcl.add_child(credits_btn)

	# Zeile 2: Zeitalter · Flammen (Fehlversuche) · Herzen
	var row2 := _hbox(0)
	top.add_child(row2)
	var left := _hbox(0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(left)
	age_chip = PanelContainer.new()
	age_chip.add_theme_stylebox_override("panel", _chip_style())
	left.add_child(age_chip)
	var ah := _hbox(8)
	age_chip.add_child(ah)
	stage_icon = _icon("meadow", 28)
	ah.add_child(stage_icon)
	stage_label = _label("Urzeit", 16, Style.INK, Style.W_BOLD)
	stage_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ah.add_child(stage_label)
	_explain_only(age_chip, "age")
	flame_chip = PanelContainer.new()
	_flame_sb = _chip_style()
	flame_chip.add_theme_stylebox_override("panel", _flame_sb)
	row2.add_child(flame_chip)
	flames_row = _hbox(4)
	flame_chip.add_child(flames_row)
	for i in Balance.FIRE_AFTER:
		var fl := _icon("fire_off", 24)
		flames_row.add_child(fl)
		miss_flames.append(fl)
	_explain_only(flame_chip, "flames")
	var right := _hbox(0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	row2.add_child(right)
	hearts_chip = PanelContainer.new()
	hearts_chip.add_theme_stylebox_override("panel", _chip_style())
	right.add_child(hearts_chip)
	hearts_row = _hbox(2)
	hearts_chip.add_child(hearts_row)
	for i in maxi(Balance.LIVES, 1):
		var h := _icon("heart", 24)
		h.set_meta("idx", i)
		hearts_row.add_child(h)
		hearts.append(h)
	_explain_only(hearts_chip, "hearts")


func _home_top() -> void:
	top.offset_top = _insets.x + Style.TOP_GAP
	top.offset_bottom = top.offset_top


func _build_lane() -> void:
	# Tutorial: ein großer Satz unter der Kopfzeile, mit Schritt-Punkten
	tut_card = PanelContainer.new()
	tut_card.add_theme_stylebox_override("panel", Style.card(Style.R_CARD, 2, 24, 18))
	tut_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_card.custom_minimum_size = Vector2(Style.CONTENT_W, 0)
	var tv := _vbox(10)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tut_card.add_child(tv)
	tut_caps = _caps("Du bist dran", Style.LEAF_DEEP)
	tut_caps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tut_caps.visible = false
	tv.add_child(tut_caps)
	tut_label = _label("", 21, Style.INK, Style.W_BOLD)
	tut_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tut_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tut_label.custom_minimum_size = Vector2(Style.CONTENT_W - 48, 0)
	tv.add_child(tut_label)
	var dots := _hbox(6)
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_child(dots)
	for i in TUT_STEPS.size():
		var d := Panel.new()
		d.add_theme_stylebox_override("panel", Style.box(Color(Style.INK, 0.2), 4, 0, 0))
		d.custom_minimum_size = Vector2(8, 8)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(d)
		tut_dots.append(d)
	tut_card.visible = false
	root.add_child(tut_card)

	# Vorschau beim Drehen (z. B. „Danach brennt diese Reihe“)
	preview_card = PanelContainer.new()
	_preview_sb = Style.card(28, 2, 18, 10, Style.FIRE_TINT)
	preview_card.add_theme_stylebox_override("panel", _preview_sb)
	preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ph := _hbox(10)
	preview_card.add_child(ph)
	preview_icon = _icon("fire", 24)
	ph.add_child(preview_icon)
	preview_label = _label("", 16, Style.FIRE_DEEP, Style.W_BOLD)
	preview_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(preview_label)
	preview_card.visible = false
	root.add_child(preview_card)

	# Meldung: helles Banner, gleitet von oben in die Spur
	toast = PanelContainer.new()
	toast.add_theme_stylebox_override("panel", Style.card(28, 2, 20, 12))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := _hbox(12)
	toast.add_child(th)
	toast_tile = _tile("info", 40, Style.WATER_TINT, 0.5)
	th.add_child(toast_tile)
	toast_icon = toast_tile.get_child(0)
	toast_label = _label("", 17, Style.INK, Style.W_LABEL)
	toast_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(toast_label)
	toast.visible = false
	root.add_child(toast)


func _build_banner() -> void:
	banner = PanelContainer.new()
	banner.add_theme_stylebox_override("panel", Style.card(30, 2, 22, 10))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := _hbox(12)
	banner.add_child(h)
	banner_icon = _icon("up", 36)
	h.add_child(banner_icon)
	var v := _vbox(-4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	banner_caps = _caps("")
	v.add_child(banner_caps)
	banner_text = _label("", 24, Style.INK, Style.W_BLACK)
	v.add_child(banner_text)
	banner.visible = false
	root.add_child(banner)


func _build_context() -> void:
	# Feld-Karte: was ist das Feld, was wird daraus, direkt gießen
	sheet = PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", Style.card(Style.R_CARD, 2, 20, 18))
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet.custom_minimum_size = Vector2(Style.CONTENT_W, 0)
	sheet.visible = false
	root.add_child(sheet)
	var sv := _vbox(14)
	sheet.add_child(sv)
	var head := _hbox(14)
	sv.add_child(head)
	sheet_tile = _tile("meadow", 56, Style.STAGE_TINT[1])
	head.add_child(sheet_tile)
	var tv := _vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(tv)
	sheet_title = _label("", Style.F_HEAD, Style.INK, Style.W_BLACK)
	tv.add_child(sheet_title)
	sheet_caps = _caps("")
	tv.add_child(sheet_caps)
	head.add_child(_icon_button("close", _close_sheet, 40, true))
	# Die Regel als Bild: 3 × Feld → nächste Stufe
	sheet_ladder = _hbox(8)
	sheet_ladder.alignment = BoxContainer.ALIGNMENT_CENTER
	sv.add_child(sheet_ladder)
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", Style.box(Style.SURFACE_2, Style.R_ROW, 16, 8))
	lp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_ladder.add_child(lp)
	var lh := _hbox(6)
	lh.alignment = BoxContainer.ALIGNMENT_CENTER
	lp.add_child(lh)
	for i in 3:
		var ic := _icon("meadow", 28)
		lh.add_child(ic)
		sheet_from.append(ic)
	var arrow := _icon("arrow_up", 20)
	arrow.pivot_offset = Vector2(10, 10)
	arrow.rotation = PI * 0.5
	arrow.modulate = Color(1, 1, 1, 0.45)
	lh.add_child(arrow)
	sheet_next = _icon("smallforest", 34)
	lh.add_child(sheet_next)
	var rule := _label("  3 in einer Reihe", 15, Style.INK_2, Style.W_LABEL)
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lh.add_child(rule)
	sheet_body = _label("", Style.F_BODY_S, Style.INK_2, Style.W_BODY)
	sheet_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet_body.custom_minimum_size = Vector2(Style.CONTENT_W - 40, 0)
	sv.add_child(sheet_body)
	sheet_acts = _hbox(12)
	sv.add_child(sheet_acts)
	sheet_rain = _button("Gießen", "water_soft", "rain", 52)
	sheet_rain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tap_or_explain(sheet_rain, _sheet_bonus.bind("rain"), "rain", false)   # Halten erklärt, ohne zu gießen
	sheet_acts.add_child(sheet_rain)
	sheet_bolt = _button("Blitz", "sun_soft", "lightning", 52)
	sheet_bolt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tap_or_explain(sheet_bolt, _sheet_bonus.bind("bolt"), "bolt", false)
	sheet_acts.add_child(sheet_bolt)

	# Bonus-Hinweis: helle Pille statt dunkler Karte
	mode_card = PanelContainer.new()
	mode_card.add_theme_stylebox_override("panel", Style.card(28, 2, 14, 10))
	mode_card.mouse_filter = Control.MOUSE_FILTER_STOP
	mode_card.visible = false
	root.add_child(mode_card)
	var mh := _hbox(12)
	mode_card.add_child(mh)
	mode_tile = _tile("rain", 44, Style.WATER_TINT)
	mh.add_child(mode_tile)
	var mv := _vbox(0)
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mh.add_child(mv)
	mode_label = _label("", 16, Style.INK, Style.W_BOLD)
	mv.add_child(mode_label)
	mode_hint = _label("", 14, Style.INK_3, Style.W_BODY)
	mv.add_child(mode_hint)
	mh.add_child(_icon_button("close", _on_mode_close, 36, true, "mode_close"))


func _build_dock() -> void:
	dock = PanelContainer.new()
	var ds := Style.card(Style.R_DOCK, 2, 8, 12, Style.GLASS)
	dock.add_theme_stylebox_override("panel", ds)
	dock.mouse_filter = Control.MOUSE_FILTER_STOP
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_left = Style.MARGIN
	dock.offset_right = -Style.MARGIN
	dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_home_dock()
	root.add_child(dock)
	var bh := _hbox(0)
	dock.add_child(bh)
	undo_btn = _slot(bh, "undo", "undo", "Zurück", _on_undo_pressed)
	rain_btn = _slot(bh, "rain", "rain", "Regen", _on_bonus_pressed.bind("rain"))
	bolt_btn = _slot(bh, "bolt", "lightning", "Blitz", _on_bonus_pressed.bind("bolt"))
	monsoon_btn = _slot(bh, "monsoon", "monsoon", "Monsun", _on_bonus_pressed.bind("monsoon"))
	hint_btn = _slot(bh, "hint", "bulb", "Tipp", _on_hint_pressed)


## Das Dock ist eine Pille, so breit wie seine sichtbaren Plätze, immer mittig über dem unteren Rand.
func _home_dock(animate: bool = false) -> void:
	var n := 0
	for b in [undo_btn, rain_btn, bolt_btn, monsoon_btn, hint_btn]:
		var bb: Button = b
		if bb != null and (bb.get_meta("slot") as Control).visible:
			n += 1
	var w := minf(float(maxi(n, 1)) * SLOT_W + 16.0, float(Style.CONTENT_W))
	dock.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dock.offset_bottom = -(_insets.y + Style.BOTTOM_GAP)
	dock.offset_top = dock.offset_bottom - Style.DOCK_H
	if animate and dock.visible:
		var tw := _fx(dock, "w")
		tw.set_parallel(true)
		tw.tween_property(dock, "offset_left", -w * 0.5, 0.3).set_trans(Style.T_OUT).set_ease(Tween.EASE_OUT)
		tw.tween_property(dock, "offset_right", w * 0.5, 0.3).set_trans(Style.T_OUT).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(_dock_rest)
	else:
		dock.offset_left = -w * 0.5
		dock.offset_right = w * 0.5
		dock.set_meta("rest", dock.position)


func _dock_rest() -> void:
	dock.set_meta("rest", dock.position)


func _build_coach() -> void:
	coach_arrow = Panel.new()
	coach_arrow.add_theme_stylebox_override("panel", Style.box(Style.SURFACE, 3, 0, 0))
	coach_arrow.size = Vector2(18, 18)
	coach_arrow.pivot_offset = Vector2(9, 9)
	coach_arrow.rotation = PI / 4.0
	coach_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coach_arrow.visible = false
	root.add_child(coach_arrow)
	coach = PanelContainer.new()
	coach.add_theme_stylebox_override("panel", Style.card(Style.R_CARD, 3, 18, 14))
	coach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ch := _hbox(12)
	coach.add_child(ch)
	coach_tile = _tile("rain", 44, Style.WATER_TINT)
	ch.add_child(coach_tile)
	coach_icon = coach_tile.get_child(0)
	coach_label = _label("", 17, Style.INK, Style.W_LABEL)
	coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coach_label.custom_minimum_size = Vector2(260, 0)
	coach_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ch.add_child(coach_label)
	coach.visible = false
	root.add_child(coach)


func _build_tip() -> void:
	tip_card = PanelContainer.new()
	tip_card.add_theme_stylebox_override("panel", Style.card(Style.R_CARD, 3, 18, 16))
	tip_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := _hbox(14)
	tip_card.add_child(h)
	tip_tile = _tile("info", 52, Style.SURFACE_2)
	tip_tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(tip_tile)
	tip_icon = tip_tile.get_child(0)
	var v := _vbox(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	tip_title = _label("", 17, Style.INK, Style.W_BLACK)
	v.add_child(tip_title)
	tip_body = _label("", Style.F_BODY_S, Style.INK_2, Style.W_BODY)
	tip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_body.custom_minimum_size = Vector2(240, 0)
	v.add_child(tip_body)
	tip_card.visible = false
	root.add_child(tip_card)


## Beim Drehen: ganz oben, über die ganze Breite, leicht rot. Dorthin ziehen und loslassen = abbrechen.
func _build_cancel_strip() -> void:
	cancel_strip = PanelContainer.new()
	cancel_strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	cancel_strip.offset_top = 0.0
	cancel_strip.offset_bottom = _insets.x + 92.0
	var s := Style.box(Color(Style.FIRE_TINT, 0.97), 0, 24, 0)
	s.corner_radius_bottom_left = 28
	s.corner_radius_bottom_right = 28
	s.content_margin_top = _insets.x + 8.0
	s.content_margin_bottom = 8
	s.shadow_color = Color(Style.FIRE, 0.18)
	s.shadow_size = 18
	s.shadow_offset = Vector2(0, 6)
	cancel_strip.add_theme_stylebox_override("panel", s)
	cancel_strip.set_meta("sb", s)
	cancel_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := _hbox(12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	cancel_strip.add_child(h)
	cancel_icon = _icon("cancel", 32)
	h.add_child(cancel_icon)
	cancel_label = _label("Hierher ziehen zum Abbrechen", 17, Style.FIRE_DEEP, Style.W_BOLD)
	cancel_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(cancel_label)
	cancel_strip.visible = false
	root.add_child(cancel_strip)


# --- Dialoge ------------------------------------------------------------------

## Dialogkarte: Titel (optional mit Schließen-Knopf), Inhalt in card.get_meta("body").
func _modal_card(title: String, with_close: bool = false) -> PanelContainer:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", Style.card(Style.R_MODAL, 3, 28, 28))
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.visible = false
	var v := _vbox(16)
	v.custom_minimum_size = Vector2(Style.CONTENT_W - 56, 0)
	c.add_child(v)
	var t := _label(title, Style.F_TITLE, Style.INK, Style.W_BLACK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if with_close:
		var head := _hbox(0)
		v.add_child(head)
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(40, 40)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(pad)
		head.add_child(t)
		head.add_child(_icon_button("close", _close_modal, 40, true))
	else:
		v.add_child(t)
	c.set_meta("body", v)
	c.set_meta("title", t)
	root.add_child(c)
	return c


## Scrollbereich in einer Dialogkarte (wird beim Öffnen an die Bildschirmhöhe angepasst).
func _modal_scroll(card: PanelContainer, reserve: float) -> VBoxContainer:
	var v: VBoxContainer = card.get_meta("body")
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(sc)
	var inner := _vbox(16)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.add_child(inner)
	card.set_meta("scroll", sc)
	card.set_meta("inner", inner)
	card.set_meta("reserve", reserve)
	return inner


## „So geht's“: wenige Zeilen, je ein Bild und ein Satz. Blitz und Monsun erst, wenn man sie kennt.
func _build_help() -> void:
	help_card = _modal_card("So geht's", true)
	var inner := _modal_scroll(help_card, 150.0)
	inner.add_child(_help_row("round", Style.SURFACE_2, "Drehen", "Wisch über eine Reihe, um sie zu drehen. Nach ganz oben ziehen bricht ab."))
	var grow := _help_row("up", Style.LEAF_TINT, "Wachsen", "Drei gleiche in einer Reihe? Sie wachsen.")
	inner.add_child(grow)
	# Die Leiter als Bild: alle Stufen, noch nicht erreichte als graue Schatten
	var lad := _hbox(4)
	(grow.get_child(1) as Control).add_child(lad)
	for st in range(1, Balance.MAX_STAGE + 1):
		var ic := _icon(STAGE_ICON[st], 26)
		lad.add_child(ic)
		_help_ladder.append(ic)
	inner.add_child(_help_row("fire", Style.FIRE_TINT, "Flammen & Herzen", "Wächst nichts, leuchtet eine Flamme. Bei 3 Flammen brennt die Reihe – das kostet ein Herz. Ohne Herzen ist das Spiel vorbei."))
	inner.add_child(_help_row("rain", Style.WATER_TINT, "Regen", "Regen lässt ein leuchtendes Feld wachsen und löscht Feuer."))
	inner.add_child(_help_row("hand", Style.SUN_TINT, "Erklärungen", "Halte ein Symbol gedrückt – dann erklärt es sich."))
	_help_bolt_row = _help_row("lightning", Style.SUN_TINT, "Blitz", "3 gleiche an einer Ecke. Dann wächst eine schräge Linie.")
	inner.add_child(_help_bolt_row)
	_help_monsoon_row = _help_row("monsoon", Style.MONSOON_TINT, "Monsun", "Eine ganze Seite wächst.")
	inner.add_child(_help_monsoon_row)
	var v: VBoxContainer = help_card.get_meta("body")
	var go := _button("Alles klar", "primary")
	go.pressed.connect(_on_help_done)
	v.add_child(go)


func _help_row(icon_name: String, tint: Color, title: String, body: String) -> HBoxContainer:
	var h := _hbox(14)
	var tl := _tile(icon_name, 44, tint)
	tl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(tl)
	var v := _vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(_label(title, 17, Style.INK, Style.W_BOLD))
	var l := _label(body, Style.F_BODY_S, Style.INK_2, Style.W_BODY)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(Style.CONTENT_W - 56 - 44 - 14 - 8, 0)
	v.add_child(l)
	return h


func _build_menu() -> void:
	menu_card = _modal_card("Menü", true)
	var inner := _modal_scroll(menu_card, 130.0)
	var cont := _button("Weiterspielen", "primary")
	cont.pressed.connect(_close_modal)
	inner.add_child(cont)
	# Spielen: drei Stufen und die Challenge, je mit Rekord
	var play := _vbox(8)
	inner.add_child(play)
	play.add_child(_caps("Neues Spiel"))
	for m in MODES:
		var md: Dictionary = m
		play.add_child(_mode_row(md))
	# Einstellungen: Musik und Effekte (Schalter)
	var sets := _vbox(8)
	inner.add_child(sets)
	sets.add_child(_caps("Einstellungen"))
	var group := PanelContainer.new()
	group.add_theme_stylebox_override("panel", Style.box(Style.SURFACE_2, Style.R_ROW, 14, 4))
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sets.add_child(group)
	var gv := _vbox(0)
	group.add_child(gv)
	_music_switch = _switch(Game.music_on, _on_music_toggled)
	gv.add_child(_toggle_row("music", "Musik", _music_switch))
	var line := ColorRect.new()
	line.color = Style.HAIRLINE
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gv.add_child(line)
	_sfx_switch = _switch(Game.sfx_on, _on_sfx_toggled)
	gv.add_child(_toggle_row("sound", "Effekte", _sfx_switch))
	# Kacheln: Profil (bald), Hilfe, Tutorial
	var tiles := _hbox(8)
	inner.add_child(tiles)
	_profile_btn = _menu_tile("Profil", "profile", _on_profile)
	tiles.add_child(_profile_btn)
	tiles.add_child(_menu_tile("Hilfe", "help", _show_help))
	tiles.add_child(_menu_tile("Tutorial", "round", _restart_tutorial))


func _mode_row(md: Dictionary) -> Button:
	var key: String = str(md["key"])
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 72)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := Style.box(Style.SURFACE_2, Style.R_ROW, 14, 10)
	Style.skin(b, n, Style.box(Style.SURFACE_3, Style.R_ROW, 14, 10), Style.INK)
	b.set_meta("sb", n)
	_tap_or_explain(b, _on_mode_row.bind(key), "mode_" + key)     # Halten erklärt die Spielart
	var h := _hbox(14)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -18
	b.add_child(h)
	var tint: Color = Style.STAGE_TINT[int(md["tint"])]
	h.add_child(_tile(str(md["icon"]), 48, tint))
	var tv := _vbox(0)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(_label(str(md["title"]), 17, Style.INK, Style.W_BOLD))
	tv.add_child(_label(str(md["sub"]), 14, Style.INK_3, Style.W_BODY))
	var rv := _vbox(0)
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(rv)
	var rc := _caps("Rekord")
	rc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rv.add_child(rc)
	var num := _label("0", 17, Style.INK, Style.W_BLACK)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rv.add_child(num)
	_menu_rows[key] = {"btn": b, "caps": rc, "num": num}
	return b


func _toggle_row(icon_name: String, title: String, sw: Button) -> HBoxContainer:
	var h := _hbox(14)
	h.custom_minimum_size = Vector2(0, 56)
	var tl := _tile(icon_name, 40, Style.SURFACE)
	h.add_child(tl)
	var l := _label(title, 17, Style.INK, Style.W_BOLD)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	h.add_child(sw)
	sw.set_meta("tile", tl)
	sw.set_meta("icon_on", icon_name)
	h.mouse_filter = Control.MOUSE_FILTER_PASS      # die ganze Zeile schaltet (PASS: Scrollen geht weiter)
	h.gui_input.connect(_on_toggle_row_input.bind(h, sw))
	return h


## Tippen irgendwo auf die Zeile (Symbol, Text) schaltet den Schalter um.
func _on_toggle_row_input(ev: InputEvent, h: Control, sw: Button) -> void:
	if not (ev is InputEventMouseButton) or (ev as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var mb := ev as InputEventMouseButton
	if mb.pressed:
		h.set_meta("down", mb.global_position)
	elif h.has_meta("down"):
		var p0: Vector2 = h.get_meta("down")
		h.remove_meta("down")
		if mb.global_position.distance_to(p0) <= Style.HOLD_SLOP:
			sw.button_pressed = not sw.button_pressed     # löst toggled aus -> _on_switch


func _menu_tile(text: String, icon_name: String, cb: Callable) -> Button:
	var b := _button(text, "secondary", icon_name, 60)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_constant_override("icon_max_width", 22)
	b.add_theme_constant_override("h_separation", 6)
	var n := Style.box(Style.SURFACE_2, Style.R_ROW, 10, 0)
	Style.skin(b, n, Style.box(Style.SURFACE_3, Style.R_ROW, 10, 0), Style.INK)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


## Credits: eine Währung für alle Hilfen (Tipp, Schritt zurück, Weiterspielen).
## Reichen sie nicht, wird eine kurze Werbung angeboten (im Prototyp ein Platzhalter).
func _build_ad() -> void:
	ad_card = _modal_card("Münzen")
	var v: VBoxContainer = ad_card.get_meta("body")
	var tl := _tile("coin", 72, Style.SUN_TINT)
	tl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(tl)
	v.move_child(tl, 0)
	ad_label = _label("", 17, Style.INK_2, Style.W_BODY)
	ad_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ad_label.custom_minimum_size = Vector2(Style.CONTENT_W - 56, 0)
	ad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ad_label)
	var acts := _vbox(12)
	v.add_child(acts)
	var watch := _button("Video ansehen (+%d)" % Balance.CREDITS_PER_AD, "primary")
	watch.pressed.connect(_on_ad_watched)
	acts.add_child(watch)
	var no := _button("Später", "ghost")
	no.pressed.connect(_on_ad_declined)
	acts.add_child(no)


## Leerer Bonus angetippt: kaufen oder warten (nie aus Versehen bezahlen).
func _build_buy() -> void:
	buy_card = _modal_card("Regen")
	var v: VBoxContainer = buy_card.get_meta("body")
	buy_tile = _tile("rain", 72, Style.WATER_TINT)
	buy_tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(buy_tile)
	v.move_child(buy_tile, 0)
	buy_label = _label("", 17, Style.INK_2, Style.W_BODY)
	buy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buy_label.custom_minimum_size = Vector2(Style.CONTENT_W - 56, 0)
	buy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(buy_label)
	var acts := _vbox(12)
	v.add_child(acts)
	buy_btn = _button("Kaufen", "primary")
	buy_btn.pressed.connect(_on_buy_confirm)
	acts.add_child(buy_btn)
	var wait := _button("Warten", "ghost")
	wait.pressed.connect(_close_modal)
	acts.add_child(wait)


## Neues Spiel aus dem Menü, während eines läuft: kurz nachfragen (nie aus Versehen ein Spiel beenden).
func _build_confirm() -> void:
	confirm_card = _modal_card("Neues Spiel starten?")
	var v: VBoxContainer = confirm_card.get_meta("body")
	var l := _label("Dein Spiel endet. Deine Punkte zählen für den Rekord.", 17, Style.INK_2, Style.W_BODY)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(Style.CONTENT_W - 56, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var acts := _vbox(12)
	v.add_child(acts)
	var yes := _button("Ja, neues Spiel", "primary")
	yes.pressed.connect(_on_confirm_new)
	acts.add_child(yes)
	var no := _button("Abbrechen", "ghost")
	no.pressed.connect(_on_confirm_back)
	acts.add_child(no)


func _build_over() -> void:
	over_card = _modal_card("Deine Welt ist verbrannt")
	var v: VBoxContainer = over_card.get_meta("body")
	over_title = over_card.get_meta("title")
	over_tile = _tile("fire", 88, Style.FIRE_TINT)
	over_tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(over_tile)
	v.move_child(over_tile, 0)
	var sv := _vbox(-6)
	v.add_child(sv)
	var pc := _caps("Punkte")
	pc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(pc)
	over_score = _label("0", 64, Style.INK, Style.W_BLACK)
	over_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(over_score)
	var chips := _hbox(8)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(chips)
	var ac := PanelContainer.new()
	ac.add_theme_stylebox_override("panel", Style.box(Style.SURFACE_2, 20, 14, 6))
	ac.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_child(ac)
	var ah := _hbox(8)
	ac.add_child(ah)
	over_age_icon = _icon("meadow", 24)
	ah.add_child(over_age_icon)
	over_age_label = _label("", 15, Style.INK, Style.W_BOLD)
	over_age_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ah.add_child(over_age_label)
	var rc := PanelContainer.new()
	_over_rec_sb = Style.box(Style.SURFACE_2, 20, 14, 6)
	rc.add_theme_stylebox_override("panel", _over_rec_sb)
	rc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_child(rc)
	over_rec_label = _label("", 15, Style.INK, Style.W_BOLD)
	over_rec_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rc.add_child(over_rec_label)
	var acts := _vbox(12)
	v.add_child(acts)
	continue_btn = _button("Weiterspielen (%d Münzen)" % Balance.CONTINUE_COST, "water", "coin")
	continue_btn.pressed.connect(_on_continue)
	acts.add_child(continue_btn)
	var again := _button("Neues Spiel", "primary")
	again.pressed.connect(_restart)
	acts.add_child(again)
	over_undo_btn = _button("Einen Zug zurück (%d %s)" % [Balance.UNDO_COST, "Münze" if Balance.UNDO_COST == 1 else "Münzen"], "ghost")
	over_undo_btn.pressed.connect(_on_over_undo)
	acts.add_child(over_undo_btn)


# --- Bausteine ---------------------------------------------------------------

## Abstand oben (x) und unten (y) für Notch und Gestenleiste, in Oberflächen-Einheiten.
func _safe_insets() -> Vector2:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var csf := get_tree().root.content_scale_factor
	if csf <= 0.0 or safe.size.y <= 0:
		return Vector2.ZERO
	var t := maxf(0.0, float(safe.position.y)) / csf
	var b := maxf(0.0, float(win.y - safe.end.y)) / csf
	return Vector2(clampf(t, 0.0, 80.0), clampf(b, 0.0, 80.0))


func _vs() -> Vector2:
	if root != null and root.size.x > 1.0:
		return root.size
	return root.get_viewport_rect().size


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = Style.font()
	t.default_font_size = 18
	t.set_color("font_color", "Label", Style.INK)
	t.set_constant("line_spacing", "Label", 2)
	t.set_stylebox("panel", "PanelContainer", Style.card())
	var normal := Style.box(Style.SURFACE_2, 28, 24, 0)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", normal)
	t.set_stylebox("pressed", "Button", Style.box(Style.SURFACE_3, 28, 24, 0))
	t.set_stylebox("disabled", "Button", normal)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", Style.INK)
	t.set_color("font_disabled_color", "Button", Color(Style.INK, 0.4))
	var track := Style.box(Color(Style.INK, 0.05), 3, 0, 0)
	track.content_margin_left = 3
	track.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("grabber", "VScrollBar", Style.box(Color(Style.INK, 0.18), 3, 0, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", Style.box(Color(Style.INK, 0.26), 3, 0, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", Style.box(Color(Style.INK, 0.32), 3, 0, 0))
	return t


func _label(text: String, size: int, color: Color, weight: int = Style.W_BODY) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Style.font_w(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _caps(text: String, color: Color = Style.INK_3) -> Label:
	var l := Label.new()
	l.text = text
	l.uppercase = true
	l.add_theme_font_override("font", Style.caps())
	l.add_theme_font_size_override("font_size", Style.F_CAPS)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _icon(icon_name: String, px: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Style.icon(icon_name)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Symbol auf einer abgerundeten, getönten Kachel. radius_k 0.5 = rund.
func _tile(icon_name: String, px: int, tint: Color, radius_k: float = 0.3) -> PanelContainer:
	var p := PanelContainer.new()
	var pad := int(px * 0.18)
	p.add_theme_stylebox_override("panel", Style.box(tint, int(px * radius_k), pad, pad))
	p.custom_minimum_size = Vector2(px, px)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(_icon(icon_name, px - pad * 2))
	return p


func _set_tile(p: PanelContainer, icon_name: String, tint: Color) -> void:
	var ic: TextureRect = p.get_child(0)
	ic.texture = Style.icon(icon_name)
	var s: StyleBoxFlat = p.get_theme_stylebox("panel")
	s.bg_color = tint


## Knöpfe. variant: primary (Tinte), accent (Sonne), water, water_soft, sun_soft, secondary, ghost.
func _button(text: String, variant: String = "primary", icon_name: String = "", h: int = 56) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_override("font", Style.font_w(Style.W_BOLD))
	b.add_theme_font_size_override("font_size", Style.F_BUTTON)
	b.add_theme_constant_override("h_separation", 10)
	if icon_name != "":
		b.icon = Style.icon(icon_name)
		b.add_theme_constant_override("icon_max_width", 24)
	var r := int(h / 2.0)
	var n: StyleBoxFlat
	var p: StyleBoxFlat
	var fg := Style.INK
	match variant:
		"primary":
			n = Style.lift(Style.box(Style.INK, r, 24, 0), 1)
			p = Style.box(Style.INK_PRESSED, r, 24, 0)
			fg = Color.WHITE
		"accent":
			n = Style.lift(Style.box(Style.SUN, r, 24, 0), 1)
			p = Style.box(Style.SUN.darkened(0.08), r, 24, 0)
		"water":
			n = Style.lift(Style.box(Style.WATER, r, 24, 0), 1)
			p = Style.box(Style.WATER.darkened(0.1), r, 24, 0)
			fg = Color.WHITE
		"water_soft":
			n = Style.box(Style.WATER_TINT, r, 20, 0)
			p = Style.box(Style.WATER_TINT.darkened(0.06), r, 20, 0)
			fg = Style.WATER_DEEP
		"sun_soft":
			n = Style.box(Style.SUN_TINT, r, 20, 0)
			p = Style.box(Style.SUN_TINT.darkened(0.06), r, 20, 0)
			fg = Style.SUN_DEEP
		"secondary":
			n = Style.box(Style.SURFACE_2, r, 24, 0)
			p = Style.box(Style.SURFACE_3, r, 24, 0)
		_:
			n = Style.box(Color(0, 0, 0, 0), r, 20, 0)
			p = Style.box(Color(Style.INK, 0.06), r, 20, 0)
			fg = Style.INK_2
	Style.skin(b, n, p, fg)
	_press_fx(b)
	return b


## Runder Symbolknopf (Menü 52, Schließen 40 schlicht). key: Erklärung bei langem Drücken.
func _icon_button(icon_name: String, cb: Callable, size: int = 52, ghost: bool = false, key: String = "") -> Button:
	var b := Button.new()
	b.icon = Style.icon(icon_name)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", int(size * 0.44))
	b.custom_minimum_size = Vector2(size, size)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var r := int(size / 2.0)
	var n: StyleBoxFlat = Style.box(Style.SURFACE_2, r, 0, 0) if ghost else Style.lift(Style.hairline(Style.box(Style.GLASS, r, 0, 0)), 1)
	var p := Style.box(Style.SURFACE_3, r, 0, 0)
	Style.skin(b, n, p, Style.INK)
	if key != "":
		_tap_or_explain(b, cb, key)
	else:
		b.pressed.connect(cb)
		_press_fx(b)
	return b


## Chip in der Kopfzeile (Zeitalter, Flammen, Herzen, Credits): Pille, Glas, Haarlinie.
func _chip_style(bg: Color = Style.GLASS, radius: int = 20) -> StyleBoxFlat:
	return Style.lift(Style.hairline(Style.box(bg, radius, 14, 6)), 1)


## Ein Platz im Dock: runder Knopf, Zähler-Abzeichen, Beschriftung darunter.
func _slot(parent: Control, kind: String, icon_name: String, title: String, cb: Callable) -> Button:
	var v := _vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(v)
	var b := Button.new()
	b.icon = Style.icon(icon_name)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 34)
	b.custom_minimum_size = Vector2(64, 64)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.set_meta("slot", v)
	b.set_meta("kind", kind)
	v.add_child(b)
	var lab := _label(title, Style.F_SLOT, Style.INK_2, Style.W_BOLD)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lab)
	b.set_meta("label", lab)
	_slot_style(b, false)
	_tap_or_explain(b, cb, kind)
	var badge := PanelContainer.new()
	var bs := Style.box(Style.WATER, 13, 6, 0)
	bs.set_border_width_all(2)
	bs.border_color = Style.SURFACE
	badge.add_theme_stylebox_override("panel", bs)
	badge.set_meta("sb", bs)
	badge.custom_minimum_size = Vector2(26, 26)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -20
	badge.offset_right = 6
	badge.offset_top = -6
	badge.offset_bottom = 20
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	b.add_child(badge)
	b.set_meta("badge", badge)
	var bl := _label("", 13, Color.WHITE, Style.W_BLACK)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(bl)
	return b


func _slot_style(b: Button, selected: bool) -> void:
	var kind: String = str(b.get_meta("kind"))
	var tint: Color = SLOT_TINT.get(kind, Style.SURFACE_2)
	var col: Color = SLOT_COLOR.get(kind, Style.INK_2)
	var n: StyleBoxFlat = Style.ring(tint, col, 32) if selected else Style.box(tint, 32, 0, 0)
	var p := Style.box(tint.darkened(0.06), 32, 0, 0)
	Style.skin(b, n, p, Style.INK, n)     # disabled == normal: kein Flackern während Animationen
	var lab: Label = b.get_meta("label")
	lab.add_theme_color_override("font_color", col if selected else Style.INK_2)
	var slot: Control = b.get_meta("slot")
	slot.pivot_offset = slot.size * 0.5
	var tw := _fx(slot, "s")
	tw.tween_property(slot, "scale", Vector2.ONE * (1.06 if selected else 1.0), Style.DUR_FAST).set_trans(Style.T_OUT).set_ease(Tween.EASE_OUT)


## Zähler-Abzeichen: Anzahl in der Bedeutungsfarbe, „+“ auf Sonne, wenn keiner da ist (kaufen).
func _set_badge(b: Button, have: int) -> void:
	var badge: PanelContainer = b.get_meta("badge")
	var bl: Label = badge.get_child(0)
	var kind: String = str(b.get_meta("kind"))
	var col: Color = SLOT_COLOR.get(kind, Style.WATER)
	var before := bl.text
	if have <= 0 and not _known("coins"):
		badge.visible = false        # kein „kaufen“-Plus, solange man Münzen noch nicht kennt
		bl.text = ""
		return
	bl.text = str(have) if have > 0 else "+"
	var bs: StyleBoxFlat = badge.get_meta("sb")
	bs.bg_color = col if have > 0 else Style.SUN
	bl.add_theme_color_override("font_color", Color.WHITE if have > 0 else Style.INK)
	badge.visible = true
	if before != "" and before != bl.text:
		_pop(badge, 1.35)


## iOS-artiger Schalter (Musik / Effekte). cb bekommt (on: bool).
func _switch(on: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = on
	b.custom_minimum_size = Vector2(56, 34)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var knob := Panel.new()
	knob.add_theme_stylebox_override("panel", Style.lift(Style.box(Color.WHITE, 14, 0, 0), 1))
	knob.size = Vector2(28, 28)
	knob.position = Vector2(25.0 if on else 3.0, 3.0)
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(knob)
	b.set_meta("knob", knob)
	_skin_switch(b, on)
	b.toggled.connect(_on_switch.bind(b, cb))
	return b


func _on_switch(on: bool, b: Button, cb: Callable) -> void:
	var knob: Panel = b.get_meta("knob")
	var tw := _fx(knob, "v")
	tw.tween_property(knob, "position:x", 25.0 if on else 3.0, 0.22).set_trans(Style.T_OUT).set_ease(Tween.EASE_OUT)
	_skin_switch(b, on)
	cb.call(on)
	Style.haptic(Style.HAPTIC_TAP)


func _skin_switch(b: Button, on: bool) -> void:
	var track := Style.box(Style.LEAF if on else Color(Style.INK, 0.16), 17, 0, 0)
	Style.skin(b, track, track, Color.WHITE)
	if b.has_meta("tile"):
		var tl: PanelContainer = b.get_meta("tile")
		var base: String = str(b.get_meta("icon_on"))
		_set_tile(tl, base if on else base + "_off", Style.SURFACE)


# =============================================================================
# Bewegung (eine laufende Animation pro Knoten und Kanal)
# =============================================================================

## Kanäle: "s" Skalierung, "v" Sichtbarkeit, "c" Farbe, "t" Zeitgeber, "p" Puls, "n" Zahl.
func _fx(n: Node, channel: String) -> Tween:
	var key := "fx_" + channel
	if n.has_meta(key):
		var old: Tween = n.get_meta(key)
		if old != null and old.is_valid():
			old.kill()
	var tw := n.create_tween()
	n.set_meta(key, tw)
	return tw


func _press_fx(b: BaseButton) -> void:
	b.button_down.connect(_on_fx_down.bind(b))
	b.button_up.connect(_on_fx_up.bind(b))


func _on_fx_down(b: Control) -> void:
	b.pivot_offset = b.size * 0.5
	var tw := _fx(b, "s")
	tw.tween_property(b, "scale", Vector2.ONE * Style.PRESS_SCALE, Style.DUR_PRESS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Style.haptic(Style.HAPTIC_TAP)


func _on_fx_up(b: Control) -> void:
	b.pivot_offset = b.size * 0.5
	var tw := _fx(b, "s")
	tw.tween_property(b, "scale", Vector2.ONE, Style.DUR_POP).set_trans(Style.T_POP).set_ease(Tween.EASE_OUT)


## Einblenden mit Gleiten (+ optional Skalieren). Knoten VORHER an seine Endposition setzen.
## Kinder von Containern: from = Vector2.ZERO (der Container bestimmt die Position).
func _appear(n: Control, from: Vector2 = Vector2(0, -12), dur: float = Style.DUR_IN, scale_from: float = 1.0, delay: float = 0.0) -> void:
	var tw := _fx(n, "v")
	var rest := n.position
	n.set_meta("rest", rest)
	n.visible = true
	n.modulate.a = 0.0
	n.pivot_offset = n.size * 0.5
	tw.set_parallel(true)
	tw.tween_property(n, "modulate:a", 1.0, dur * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(delay)
	if from != Vector2.ZERO:
		n.position = rest + from
		tw.tween_property(n, "position", rest, dur).set_trans(Style.T_OUT).set_ease(Tween.EASE_OUT).set_delay(delay)
	if scale_from != 1.0:
		n.scale = Vector2.ONE * scale_from
		tw.tween_property(n, "scale", Vector2.ONE, dur + 0.08).set_trans(Style.T_POP).set_ease(Tween.EASE_OUT).set_delay(delay)


## Ausblenden mit Gleiten, dann verstecken (oder freigeben). Stellt die Ruheposition wieder her.
func _disappear(n: Control, to: Vector2 = Vector2(0, -8), dur: float = Style.DUR_OUT, free_after: bool = false) -> void:
	if not n.visible:
		return
	var tw := _fx(n, "v")
	var rest: Vector2 = n.get_meta("rest", n.position)
	tw.set_parallel(true)
	tw.tween_property(n, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if to != Vector2.ZERO:
		tw.tween_property(n, "position", rest + to, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(_after_hide.bind(n, rest, free_after))


func _after_hide(n: Control, rest: Vector2, free_after: bool) -> void:
	if free_after:
		n.queue_free()
		return
	n.visible = false
	n.position = rest
	n.scale = Vector2.ONE
	n.modulate.a = 1.0


## Sofort verstecken (ohne Animation), z. B. bei neuem Spiel.
func _hide_now(n: Control) -> void:
	if n.has_meta("fx_v"):
		var old: Tween = n.get_meta("fx_v")
		if old != null and old.is_valid():
			old.kill()
	if n.visible:
		var rest: Vector2 = n.get_meta("rest", n.position)
		_after_hide(n, rest, false)


func _stagger_in(nodes: Array, from: Vector2, scale_from: float = 0.92, base_delay: float = 0.0) -> void:
	var i := 0
	for x in nodes:
		var c: Control = x
		if c == null or not c.visible:
			continue
		_appear(c, from, Style.DUR_IN, scale_from, base_delay + Style.STAGGER * i)
		i += 1


func _number_pop(l: Label, flash: Color = Style.SUN_DEEP, rest_color: Color = Style.INK) -> void:
	l.pivot_offset = l.size * 0.5
	var tw := _fx(l, "s")
	tw.tween_property(l, "scale", Vector2.ONE * 1.12, 0.09).set_trans(Style.T_OUT).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.32).set_trans(Style.T_POP).set_ease(Tween.EASE_OUT)
	var tc := _fx(l, "c")
	tc.tween_method(_set_font_color.bind(l), flash, rest_color, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _set_font_color(c: Color, l: Label) -> void:
	l.add_theme_color_override("font_color", c)


func _pop(c: Control, amount: float = 1.18) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := _fx(c, "s")
	tw.tween_property(c, "scale", Vector2.ONE * amount, 0.1).set_trans(Style.T_OUT).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, Style.DUR_POP).set_trans(Style.T_POP).set_ease(Tween.EASE_OUT)


func _shake(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := _fx(c, "r")
	for k in 3:
		tw.tween_property(c, "rotation", 0.14, 0.05)
		tw.tween_property(c, "rotation", -0.14, 0.05)
	tw.tween_property(c, "rotation", 0.0, 0.06)


## Puls in Schleife; mehrfach aufrufbar, ohne neu zu starten.
func _pulse(c: Control, on: bool) -> void:
	if bool(c.get_meta("pulsing", false)) == on:
		return
	c.set_meta("pulsing", on)
	c.pivot_offset = c.size * 0.5
	var tw := _fx(c, "p")
	if not on:
		tw.tween_property(c, "scale", Vector2.ONE, 0.15)
		return
	tw.set_loops()
	tw.tween_property(c, "scale", Vector2.ONE * 1.07, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Flug im Bogen (Mittelpunkte in globalen Koordinaten). tween_callback an das Ergebnis hängen.
func _fly(node: Control, from_c: Vector2, to_c: Vector2, dur: float = Style.DUR_FLY, lift: float = 140.0, end_scale: float = 0.42) -> Tween:
	var half := node.size * 0.5
	var ctrl := (from_c + to_c) * 0.5 + Vector2(0, -lift)
	node.pivot_offset = half
	var tw := node.create_tween()
	tw.tween_method(_fly_step.bind(node, from_c - half, ctrl - half, to_c - half), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(node, "scale", Vector2.ONE * end_scale, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tw


func _fly_step(t: float, node: Control, p0: Vector2, p1: Vector2, p2: Vector2) -> void:
	var u := 1.0 - t
	node.position = p0 * (u * u) + p1 * (2.0 * u * t) + p2 * (t * t)


func _ripple(target: Control, color: Color) -> void:
	var r := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.set_border_width_all(3)
	s.border_color = color
	s.set_corner_radius_all(int(target.size.x * 0.5) + 2)
	s.anti_aliasing = true
	r.add_theme_stylebox_override("panel", s)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = target.size
	r.position = target.get_global_rect().position
	r.pivot_offset = r.size * 0.5
	gift_layer.add_child(r)
	var tw := r.create_tween().set_parallel(true)
	tw.tween_property(r, "scale", Vector2.ONE * 1.55, 0.6).set_trans(Style.T_OUT).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(r.queue_free)


func _count_up(l: Label, to: int, dur: float = 0.9) -> void:
	l.text = "0"
	var tw := _fx(l, "n")
	tw.tween_method(_set_int_text.bind(l), 0.0, float(to), dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func _set_int_text(v: float, l: Label) -> void:
	l.text = str(int(round(v)))


## Neues Spiel: Kopfzeile gleitet von oben, Dock von unten, Elemente nacheinander.
func _hud_entrance() -> void:
	if top == null:
		return
	_home_top()
	_appear(top, Vector2(0, -16))
	_stagger_in([menu_b, score_box, credits_btn, age_chip, flame_chip, hearts_chip], Vector2.ZERO, 0.92, 0.06)
	if _hud_tut:
		dock.visible = false
		return
	_dock_in(0.0)


func _dock_in(delay: float) -> void:
	_home_dock()
	_appear(dock, Vector2(0, 28), Style.DUR_IN, 1.0, delay)
	var slots: Array = []
	for b in [undo_btn, rain_btn, bolt_btn, monsoon_btn, hint_btn]:
		var bb: Button = b
		if (bb.get_meta("slot") as Control).visible:
			slots.append(bb)
	_stagger_in(slots, Vector2.ZERO, 0.8, delay + 0.12)


## Im Tutorial nur das Nötigste: Punkte und Herzen. Kein Menü, keine Münzen, kein Dock.
## Danach gleitet alles herein (das Dock zuerst nur mit Regen).
func _apply_tutorial_hud() -> void:
	var tut := Game.tutorial()
	if tut == _hud_tut:
		return
	_hud_tut = tut
	if tut:
		menu_b.visible = false
		credits_btn.visible = false
		age_chip.visible = false
		flame_chip.visible = false
		_hide_now(dock)
		return
	menu_b.visible = true
	_sync_slots(false)
	_stagger_in([menu_b, age_chip, credits_btn, flame_chip], Vector2.ZERO, 0.8, 0.0)
	_dock_in(0.35)


# =============================================================================
# Nach und nach aufdecken: neue Spieler sehen nur, was sie gerade brauchen
# =============================================================================

func _known(flag: String) -> bool:
	return Game.coach_seen.has("show_" + flag)


## Ab jetzt immer zeigen (gemerkt; „Tutorial nochmal“ setzt es zurück).
func _reveal(flag: String) -> void:
	if Game.tutorial() or _known(flag):
		return
	Game.coach_seen["show_" + flag] = true
	Game.save_settings()


## Welche Plätze im Dock und welche Chips oben sichtbar sind. animate: Neues ploppt auf.
func _sync_slots(animate: bool) -> void:
	var gs := Game.state
	if gs == null:
		return
	var tut := Game.tutorial()
	if not tut:
		if gs.bolts > 0:
			_reveal("bolt")
		if gs.disasters > 0:
			_reveal("undo")
		if gs.misses > 0:
			_reveal("flames")
	var changed := false
	changed = _slot_show(undo_btn, not tut and _known("undo"), animate) or changed
	changed = _slot_show(rain_btn, not tut and gs.gadgets, animate) or changed
	changed = _slot_show(bolt_btn, not tut and gs.gadgets and (_known("bolt") or gs.bolts > 0), animate) or changed
	changed = _slot_show(monsoon_btn, not tut and gs.gadgets and (gs.monsoon_unlocked or gs.monsoons > 0), animate) or changed
	changed = _slot_show(hint_btn, not tut and _known("hint"), animate) or changed
	if changed:
		_home_dock(animate)
	if tut:
		return
	_chip_show(age_chip, true, animate)
	_chip_show(credits_btn, _known("coins"), animate)
	_chip_show(flame_chip, _known("flames"), animate)


func _slot_show(b: Button, on: bool, animate: bool) -> bool:
	var slot: Control = b.get_meta("slot")
	if slot.visible == on:
		return false
	slot.visible = on
	if on and animate and dock.visible:
		_appear(b, Vector2.ZERO, 0.4, 0.5, 0.15)
		get_tree().create_timer(0.45).timeout.connect(_ripple.bind(b, SLOT_COLOR.get(str(b.get_meta("kind")), Style.SUN)))
	return true


func _chip_show(c: Control, on: bool, animate: bool) -> void:
	if c.visible == on:
		return
	c.visible = on
	if on and animate:
		_appear(c, Vector2.ZERO, 0.35, 0.7)


# =============================================================================
# Langes Drücken: Erklärung
# =============================================================================

## Tippen = Aktion, Halten = Erklärung. Statt b.pressed.connect(cb) verwenden (inkl. Drück-Effekt).
## with_fx = false für Knöpfe aus _button (die haben den Drück-Effekt schon).
func _tap_or_explain(b: BaseButton, cb: Callable, key: String, with_fx: bool = true) -> void:
	b.set_meta("cb", cb)
	b.pressed.connect(_on_tapped.bind(b))
	_make_holdable(b, key)
	if with_fx:
		_press_fx(b)


## Beliebiges Element: nach LONG_PRESS Sekunden Halten erscheint TOOLTIPS[key].
## Das Loslassen danach löst die Aktion des Knopfs nicht aus.
func _make_holdable(c: Control, key: String) -> void:
	c.set_meta("explain", key)
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.gui_input.connect(_on_hold_input.bind(c))


## Reine Anzeige (Zeitalter, Flammen, Herzen, Punkte): Tippen oder Halten erklärt.
func _explain_only(c: Control, key: String) -> void:
	_make_holdable(c, key)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.gui_input.connect(_on_info_input.bind(c))


func _on_tapped(b: BaseButton) -> void:
	if _lp_swallow == b:
		_lp_swallow = null
		return
	_hide_tip()
	var cb: Callable = b.get_meta("cb")
	if cb.is_valid():
		cb.call()


func _on_hold_input(ev: InputEvent, c: Control) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := ev as InputEventMouseButton
		if mb.pressed:
			_lp_node = c
			_lp_t = 0.0
			_lp_pos = mb.global_position
			_lp_fired = false
			_lp_swallow = null
		else:
			if _lp_fired and _lp_node == c:
				_lp_swallow = c          # gui_input kommt vor dem „pressed“ des Knopfs
				_tip_hide_at = _time + 2.2
			_lp_node = null
	elif ev is InputEventMouseMotion and _lp_node == c:
		if (ev as InputEventMouseMotion).global_position.distance_to(_lp_pos) > Style.HOLD_SLOP:
			_lp_node = null


func _on_info_input(ev: InputEvent, c: Control) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_show_tip(c)
		_tip_hide_at = _time + 3.2


func _hold_tick(delta: float) -> void:
	if _lp_node != null and not _lp_fired:
		if not is_instance_valid(_lp_node) or not _lp_node.is_visible_in_tree():
			_lp_node = null
		else:
			_lp_t += delta
			if _lp_t >= Style.LONG_PRESS:
				_lp_fired = true
				Style.haptic(Style.HAPTIC_HOVER)
				_on_fx_up(_lp_node)
				if not (tip_card.visible and _tip_owner == _lp_node):
					_show_tip(_lp_node)
				_tip_hide_at = INF
	if tip_card.visible and _time > _tip_hide_at:
		_hide_tip()


## Text für eine Erklärung. Hier können dynamische Teile (Anzahl, Rekord …) ergänzt werden.
func _tooltip_for(key: String) -> Dictionary:
	if not TOOLTIPS.has(key):
		return {}
	var d: Dictionary = (TOOLTIPS[key] as Dictionary).duplicate()
	var gs := Game.state
	var body := str(d["body"])
	match key:
		"credits":
			body += " Du hast %d." % Game.credits
		"score":
			var rec := Game.best_for(Game.mode_key())
			if rec > 0:
				body += " Rekord: %d." % rec
		"age":
			if gs != null:
				d["icon"] = STAGE_ICON[clampi(gs.best_stage, 1, Balance.MAX_STAGE)]
				d["title"] = "Zeitalter: %s" % gs.age_name()
				body += " " + _next_age_text()
		"hearts":
			if gs != null:
				body += " Noch %d %s." % [gs.lives, "Herz" if gs.lives == 1 else "Herzen"]
		"rain":
			if gs != null and gs.rain <= 0:
				body += " Nächster Regen bei %d Punkten." % gs.next_rain
		"undo":
			body += " Kostet %d %s." % [Balance.UNDO_COST, _coin_word(Balance.UNDO_COST)]
		"hint":
			body += " Kostet %d %s." % [Balance.HINT_COST, _coin_word(Balance.HINT_COST)]
		"mode_close":
			var what := "den Regen" if bonus_mode == "rain" else ("den Blitz" if bonus_mode == "bolt" else ("den Monsun" if bonus_mode == "monsoon" else "den Bonus"))
			body = "Doch nicht? Damit legst du %s wieder weg." % what
	d["body"] = body
	return d


func _show_tip(c: Control) -> void:
	var key: String = str(c.get_meta("explain", ""))
	var d := _tooltip_for(key)
	if d.is_empty():
		return
	_show_tooltip(c, str(d.get("icon", "info")), str(d.get("title", "")), str(d.get("body", "")))


## Erklärkarte an target: über dem Element, wenn es in der unteren Hälfte liegt, sonst darunter.
func _show_tooltip(target: Control, icon_name: String, title: String, body: String) -> void:
	_coach_dismiss()
	_tip_owner = target
	_set_tile(tip_tile, icon_name, _tint_for_icon(icon_name))
	tip_title.text = title
	tip_body.text = body
	tip_card.size = Vector2.ZERO
	tip_card.reset_size()
	var vs := _vs()
	var r := target.get_global_rect()
	var x := clampf(r.get_center().x - tip_card.size.x * 0.5, Style.MARGIN, vs.x - Style.MARGIN - tip_card.size.x)
	var above := r.get_center().y > vs.y * 0.5
	var y := r.position.y - tip_card.size.y - 14.0 if above else r.end.y + 14.0
	tip_card.position = Vector2(roundf(x), roundf(y))
	_appear(tip_card, Vector2(0, 8.0 if above else -8.0), Style.DUR_FAST + 0.04, 0.96)


func _hide_tip() -> void:
	_tip_hide_at = INF
	_tip_owner = null
	if tip_card != null and tip_card.visible:
		_disappear(tip_card, Vector2.ZERO, 0.14)


## Kompatibler Name.
func _hide_tooltip() -> void:
	_hide_tip()


func _tint_for_icon(icon_name: String) -> Color:
	match icon_name:
		"rain", "monsoon", "help", "info":
			return Style.WATER_TINT
		"fire", "heart", "cancel":
			return Style.FIRE_TINT
		"coin", "bulb", "lightning", "trophy", "gift", "star":
			return Style.SUN_TINT
		"check", "up":
			return Style.LEAF_TINT
	var si := STAGE_ICON.find(icon_name)
	if si >= 0:
		return Style.STAGE_TINT[si]
	return Style.SURFACE_2


# =============================================================================
# Eingabe & Takt
# =============================================================================

func _input(event: InputEvent) -> void:
	var down := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if not down:
		return
	if coach != null and coach.visible:
		_coach_dismiss()
	if tip_card != null and tip_card.visible and _tip_hide_at != INF:
		_hide_tip()


func _process(delta: float) -> void:
	_time += delta
	_update_bubbles(delta)
	if Game.state == null or score_label == null:
		return
	_hold_tick(delta)
	_toast_tick()
	_coach_tick()
	_tutorial_tick()
	_stuck_tick()
	var target := float(Game.state.score)
	_score_display = lerpf(_score_display, target, 1.0 - exp(-8.0 * delta))
	if absf(target - _score_display) < 0.5:
		_score_display = target
	score_label.text = str(int(round(_score_display)))
	_update_buttons()


## Lange nichts passiert (nach der Eingewöhnung)? Dann kommt der Tipp dazu.
func _stuck_tick() -> void:
	if Game.tutorial() or Game.onboarding or _known("hint") or Game.over:
		_calm_since = _time
		return
	if _twisting or world.animating or Game.busy or modal_bg.visible or bonus_mode != "":
		_calm_since = _time
		return
	if _time - _calm_since > 15.0:
		_calm_since = _time
		_reveal_hint()


# =============================================================================
# Aktualisieren
# =============================================================================

func refresh() -> void:
	if root == null or Game.state == null:
		return
	var gs := Game.state
	_apply_tutorial_hud()
	var settled := _last_rain >= 0     # nicht der erste Aufbau nach einem neuen Spiel
	if gs.endless or Game.tutorial():
		round_label.text = "Punkte"
	else:
		round_label.text = "Drehung %d von %d" % [mini(gs.twists + 1, Balance.MAX_TWISTS), Balance.MAX_TWISTS]
	if _shown_score < 0:
		_score_display = gs.score
	elif gs.score > _shown_score:
		_number_pop(score_label)
	_shown_score = gs.score
	# Zeitalter
	var best_stage := clampi(gs.best_stage, 1, Balance.MAX_STAGE)
	var age := gs.age_name()
	if _last_age != "" and age != _last_age and not Game.tutorial():
		_show_banner("age", "Deine Welt wächst", age + "!", STAGE_ICON[best_stage])
		_pop(age_chip, 1.15)
		Style.haptic(Style.HAPTIC_COMBO)
		_coach_once("age", age_chip)
	_last_age = age
	stage_label.text = age
	stage_icon.texture = Style.icon(STAGE_ICON[best_stage])
	# Credits
	credits_btn.text = str(Game.credits)
	if _last_credits >= 0 and Game.credits != _last_credits:
		_pop(credits_btn, 1.12)
	_last_credits = Game.credits
	if bonus_mode == "rain":
		if gs.rain <= 0:
			_set_bonus_mode("")
		elif not world.animating:
			_world_targets("rain")
	_sync_slots(settled)
	_set_badge(rain_btn, gs.rain)
	_set_badge(bolt_btn, gs.bolts)
	_set_badge(monsoon_btn, gs.monsoons)
	if _last_monsoons >= 0 and gs.monsoons > _last_monsoons:
		_show_gift("monsoon", monsoon_btn)
	if _last_rain >= 0 and gs.rain > _last_rain:
		_show_gift("rain", rain_btn)
	if _last_bolts >= 0 and gs.bolts > _last_bolts:
		_show_gift("lightning", bolt_btn)
	_last_monsoons = gs.monsoons
	_last_rain = gs.rain
	_last_bolts = gs.bolts
	# Flammen (Fehlversuche)
	for i in miss_flames.size():
		var fl: TextureRect = miss_flames[i]
		if _time < float(fl.get_meta("lock", 0.0)):
			continue
		fl.texture = Style.icon("fire" if i < gs.misses else "fire_off")
	var warn := gs.misses >= Balance.FIRE_AFTER - 1 and not Game.over
	_flame_sb.bg_color = Style.FIRE_TINT if warn else Style.GLASS
	_pulse(flames_row, warn)
	# Herzen: immer sichtbar
	var lives := gs.lives
	if _last_lives >= 0 and lives < _last_lives:
		for i in range(maxi(lives, 0), mini(_last_lives, hearts.size())):
			_heart_lost(hearts[i])
	_last_lives = lives
	for i in hearts.size():
		var h: TextureRect = hearts[i]
		if _time < float(h.get_meta("lock", 0.0)):
			continue
		h.texture = Style.icon("heart" if i < lives else "heart_empty")
	_pulse(hearts_row, lives == 1 and not Game.over)
	_update_buttons()
	if _sheet_field >= 0 and sheet.visible:
		_fill_sheet(_sheet_field)
		if absf(sheet.get_combined_minimum_size().y - sheet.size.y) > 0.5:
			_place_context(sheet)


func _heart_lost(h: TextureRect) -> void:
	h.set_meta("lock", _time + 0.4)
	_shake(h)
	Style.haptic(Style.HAPTIC_FIRE)
	get_tree().create_timer(0.36).timeout.connect(_heart_swap.bind(h))


func _heart_swap(h: TextureRect) -> void:
	h.set_meta("lock", 0.0)
	var idx := int(h.get_meta("idx", 0))
	h.texture = Style.icon("heart" if Game.state != null and idx < Game.state.lives else "heart_empty")
	_pop(h, 1.3)


## Das Dock wird nie „disabled“ (sonst ginge das Halten für die Erklärung nicht): Die Knöpfe prüfen selbst.
func _update_buttons() -> void:
	# Nur dimmen, wenn wirklich nichts zurückzunehmen ist (nicht während Animationen)
	var dim := Game.undo_state == null
	var us: Control = undo_btn.get_meta("slot")
	if bool(us.get_meta("dim", false)) != dim:
		us.set_meta("dim", dim)
		var tw := _fx(us, "c")
		tw.tween_property(us, "modulate:a", 0.45 if dim else 1.0, Style.DUR_FAST)


func _world_targets(kind: String) -> void:
	if world.has_method("show_targets"):
		world.call("show_targets", kind)
	elif world.has_method("show_rain_spots"):
		world.call("show_rain_spots", kind == "rain")


# =============================================================================
# Booster: Regen, Blitz, Monsun, Tipp, Zurück
# =============================================================================

## Neuer Bonus: ein Geschenk springt auf, zeigt den Bonus und fliegt im Bogen in seinen Platz.
func _show_gift(icon_name: String, target: Control) -> void:
	var box := TextureRect.new()
	box.texture = Style.icon("gift")
	box.size = Vector2(96, 96)
	box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gift_layer.add_child(box)
	var vs := _vs()
	box.position = Vector2(vs.x * 0.5 - 48.0, vs.y * 0.42)
	box.pivot_offset = Vector2(48, 48)
	box.scale = Vector2.ZERO
	var tw := box.create_tween()
	tw.tween_property(box, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for k in 2:
		tw.tween_property(box, "rotation", 0.16, 0.07).set_trans(Tween.TRANS_SINE)
		tw.tween_property(box, "rotation", -0.16, 0.07).set_trans(Tween.TRANS_SINE)
	tw.tween_property(box, "rotation", 0.0, 0.06)
	tw.tween_callback(_gift_reveal.bind(box, icon_name))
	tw.tween_interval(0.75)
	tw.tween_callback(_gift_fly.bind(box, target, icon_name))


func _gift_reveal(box: TextureRect, icon_name: String) -> void:
	box.texture = Style.icon(icon_name)
	_pop(box, 1.25)
	Style.haptic(Style.HAPTIC_MERGE)


func _gift_fly(box: TextureRect, target: Control, icon_name: String) -> void:
	if not is_instance_valid(box):
		return
	var from_c := box.position + box.size * 0.5
	var to_c := target.get_global_rect().get_center()
	var tw := _fly(box, from_c, to_c, Style.DUR_FLY, 160.0, 0.4)
	tw.tween_callback(_gift_land.bind(box, target, icon_name))


func _gift_land(box: TextureRect, target: Control, icon_name: String) -> void:
	box.queue_free()
	var kind: String = str(target.get_meta("kind", ""))
	_pop(target, 1.2)
	_ripple(target, SLOT_COLOR.get(kind, Style.SUN))
	var badge: Control = target.get_meta("badge", null)
	if badge != null:
		_pop(badge, 1.35)
	Style.haptic(Style.HAPTIC_TAP)
	var key: String = str({"rain": "rain", "lightning": "bolt", "monsoon": "monsoon"}.get(icon_name, ""))
	if key != "":
		_coach_once(key, target)


## Gerade geht nichts (Animation, Spielende, Tutorial)?
func _blocked() -> bool:
	return Game.busy or Game.over or world.animating or Game.tutorial()


func _slot_btn(kind: String) -> Button:
	match kind:
		"rain":
			return rain_btn
		"bolt":
			return bolt_btn
		"monsoon":
			return monsoon_btn
		"hint":
			return hint_btn
	return undo_btn


func _on_bonus_pressed(kind: String) -> void:
	if _blocked():
		_shake(_slot_btn(kind))
		return
	var gs := Game.state
	var have := gs.rain if kind == "rain" else (gs.bolts if kind == "bolt" else gs.monsoons)
	if have <= 0:
		_offer_buy(kind)
		return
	_set_bonus_mode("" if bonus_mode == kind else kind)


## Keiner da: sagen, wann der nächste kommt, und anbieten, einen zu kaufen.
func _offer_buy(kind: String) -> void:
	var gs := Game.state
	_buy_kind = kind
	var cost := _bonus_cost(kind)
	var title := "Regen" if kind == "rain" else ("Blitz" if kind == "bolt" else "Monsun")
	var icon_name := "rain" if kind == "rain" else ("lightning" if kind == "bolt" else "monsoon")
	(buy_card.get_meta("title") as Label).text = title
	_set_tile(buy_tile, icon_name, _tint_for_icon(icon_name))
	var when := ""
	if kind == "rain":
		when = "Noch %d Punkte bis zum nächsten Regen. " % maxi(1, gs.next_rain - gs.score)
	elif kind == "bolt":
		when = "Einen Blitz gibt es, wenn sich an einer Ecke 3 gleiche treffen. "
	else:
		when = "Der nächste Monsun kommt mit mehr Punkten. "
	buy_label.text = when + "Oder jetzt für %d %s." % [cost, _coin_word(cost)]
	buy_btn.text = "Kaufen (%d)" % cost
	_open_modal(buy_card)


func _on_buy_confirm() -> void:
	var kind := _buy_kind
	_close_modal(true)
	if kind == "":
		return
	var what := "Ein Regen" if kind == "rain" else ("Ein Blitz" if kind == "bolt" else "Ein Monsun")
	_pay(_bonus_cost(kind), what, _buy_and_use.bind(kind))


func _bonus_cost(kind: String) -> int:
	return Balance.RAIN_COST if kind == "rain" else (Balance.BOLT_COST if kind == "bolt" else Balance.MONSOON_COST)


static func _coin_word(n: int) -> String:
	return "Münze" if n == 1 else "Münzen"


func _buy_and_use(kind: String) -> void:
	Game.grant(kind)
	_set_bonus_mode(kind)


func _on_mode_close() -> void:
	_set_bonus_mode("")


func _set_bonus_mode(kind: String) -> void:
	var was := bonus_mode
	bonus_mode = kind
	for pair in [[rain_btn, "rain"], [bolt_btn, "bolt"], [monsoon_btn, "monsoon"]]:
		var bb: Button = pair[0]
		var sel := kind == str(pair[1])
		if sel != (was == str(pair[1])):
			_slot_style(bb, sel)
	_world_targets(kind)
	world.set("bolt_mode", false)      # Blitz wird nicht gezogen, sondern auf ein Eckfeld getippt
	_hide_tip()
	if kind == "":
		if mode_card.visible:
			_disappear(mode_card, Vector2(0, 16), Style.DUR_FAST)
		return
	_close_sheet()
	if kind == "rain":
		_set_tile(mode_tile, "rain", Style.WATER_TINT)
		mode_label.text = "Tippe auf ein leuchtendes Feld."
		mode_hint.text = "Brennende Felder löschst du so auch."
	elif kind == "bolt":
		_set_tile(mode_tile, "lightning", Style.SUN_TINT)
		mode_label.text = "Tippe auf ein leuchtendes Eckfeld."
		mode_hint.text = "Die schräge Linie von dort wächst."
	elif kind == "monsoon":
		_set_tile(mode_tile, "monsoon", Style.MONSOON_TINT)
		mode_label.text = "Tippe auf eine Seite des Würfels."
		mode_hint.text = "Alle 9 Felder dort wachsen."
	if was == "" or not mode_card.visible:
		_place_context(mode_card)
		_appear(mode_card, Vector2(0, 20), Style.DUR_IN, 0.98)


## Kontextzone: wächst nach oben, direkt über dem Dock. Breite Karten mittig.
func _place_context(n: Control) -> void:
	n.size = Vector2.ZERO
	n.reset_size()
	var vs := _vs()
	var bottom := vs.y - _insets.y - Style.BOTTOM_GAP - Style.DOCK_H - 12.0
	n.position = Vector2(roundf((vs.x - n.size.x) * 0.5), roundf(bottom - n.size.y))


func _on_hint_pressed() -> void:
	if _blocked():
		_shake(hint_btn)
		return
	if Game.state.best_move().is_empty():
		# Keine Drehung bringt etwas: statt eines Tipps gibt es einen Regen
		_pay(Balance.HINT_COST, "Ein Tipp", _hint_gives_rain)
		return
	_pay(Balance.HINT_COST, "Ein Tipp", _use_hint)


func _hint_gives_rain() -> void:
	Game.grant("rain")
	_on_message("Gerade passt keine Drehung. Dafür bekommst du einen Regen!", "reward")


func _use_hint() -> void:
	var best := world.show_hint()
	if int(best.get("steps", 1)) == 2:
		_on_message("Dreh die leuchtende Reihe. Danach passt es.", "info")
	else:
		_on_message("Dreh die leuchtende Reihe!", "info")


func _on_undo_pressed() -> void:
	if _blocked():
		_shake(undo_btn)
		return
	if not Game.can_undo():
		_shake(undo_btn)
		_on_message("Noch nichts zum Zurücknehmen.", "info")
		return
	_pay(Balance.UNDO_COST, "Zurück", Game.undo)


## Kostet cost Münzen und führt dann action aus. Reicht es nicht, wird erst ein kurzes Video angeboten.
func _pay(cost: int, what: String, action: Callable) -> void:
	# Wer zum ersten Mal bezahlt, lernt die Münzen kennen (oben rechts)
	if not _known("coins"):
		_reveal("coins")
		_coach_once("coins", credits_btn)
	if Game.spend(cost):
		action.call()
		refresh()
		return
	_pending = action
	_pending_cost = cost
	ad_label.text = "%s kostet %d %s. Du hast %d.\nSchau ein kurzes Video und bekomm %d %s." % [
		what, cost, _coin_word(cost), Game.credits, Balance.CREDITS_PER_AD, _coin_word(Balance.CREDITS_PER_AD)]
	refresh()
	_open_modal(ad_card)


func _on_ad_watched() -> void:
	_close_modal()
	Game.reward_ad()
	_on_message("Danke! +%d %s." % [Balance.CREDITS_PER_AD, _coin_word(Balance.CREDITS_PER_AD)], "reward")
	refresh()
	if _pending.is_valid():
		var act := _pending
		_pending = Callable()
		_pay(_pending_cost, "Das", act)
	return


func _on_ad_declined() -> void:
	_pending = Callable()
	_close_modal()
	if Game.over:
		_open_modal(over_card, false)


func _on_credits_pressed() -> void:
	_pending = Callable()
	ad_label.text = "Mit Münzen bezahlst du Tipp (%d), Zurück (%d) und Weiterspielen (%d).\nDu hast %d." % [
		Balance.HINT_COST, Balance.UNDO_COST, Balance.CONTINUE_COST, Game.credits]
	_open_modal(ad_card)


func _on_continue() -> void:
	_close_modal()
	_pay(Balance.CONTINUE_COST, "Weiterspielen", Game.continue_game)


func _on_over_undo() -> void:
	_close_modal()
	_pay(Balance.UNDO_COST, "Zurück", Game.undo)


# =============================================================================
# Vorschau beim Wischen (in der Spur)
# =============================================================================

func _on_preview(info: Dictionary) -> void:
	if info.is_empty():
		_disappear(preview_card, Vector2(0, -6), Style.DUR_FAST)
		return
	var arranged: GameState = info["arranged"]
	var merges := 0
	for ln in arranged.lines(arranged.moved):
		if not arranged.seen.has(GameState.line_key(ln)):
			merges += 1
	var kind := ""
	for e in info["events"]:
		if str(e["type"]) == "disaster":
			kind = str(e["kind"])
	var text := ""
	if kind != "":
		text = "Achtung: Diese Reihe fängt Feuer!"
		_preview_sb.bg_color = Style.FIRE_TINT
		preview_icon.texture = Style.icon("fire")
		preview_label.add_theme_color_override("font_color", Style.FIRE_DEEP)
	elif Game.tutorial():
		if merges > 0:
			text = "+%d Punkte" % int(info["gain"])
			_preview_sb.bg_color = Style.LEAF_TINT
			preview_icon.texture = Style.icon("up")
			preview_label.add_theme_color_override("font_color", Style.LEAF_DEEP)
		else:
			text = "Hier wächst nichts"
			_preview_sb.bg_color = Style.SURFACE
			preview_icon.texture = Style.icon("round")
			preview_label.add_theme_color_override("font_color", Style.INK_2)
	if text == "":
		_disappear(preview_card, Vector2(0, -6), Style.DUR_FAST)
		return
	var changed := preview_label.text != text
	preview_label.text = text
	if preview_card.visible and preview_card.modulate.a > 0.99 and not changed:
		return
	preview_card.size = Vector2.ZERO
	preview_card.reset_size()
	var vs := _vs()
	preview_card.position = Vector2(roundf((vs.x - preview_card.size.x) * 0.5), _lane_y())
	if preview_card.visible and preview_card.modulate.a > 0.99:
		_pop(preview_card, 1.04)
	else:
		_appear(preview_card, Vector2(0, -10), Style.DUR_IN, 0.96)


# =============================================================================
# Tutorial Schritt für Schritt
# =============================================================================

func _tutorial_show() -> void:
	if not Game.tutorial() or Game.tutorial_step >= TUT_STEPS.size():
		if Game.tutorial():
			Game.end_tutorial()
		if tut_card.visible:
			_disappear(tut_card, Vector2(0, -8), Style.DUR_OUT)
		refresh()
		return
	var st: Dictionary = TUT_STEPS[Game.tutorial_step]
	_tut_set(str(st["text"]), str(st["wait"]) == "twist", Game.tutorial_step)
	_tut_step_at = _time
	_tut_tries = 0
	if str(st["wait"]) == "twist":
		_demo_at = _time + 0.8      # gleich zeigt die Hand, wie man wischt
	if str(st["wait"]) == "auto":
		# Würfel dreht sich zu den leuchtenden Feldern, dann spielt sich der erste Zug von selbst
		world.focus_place(Vector3i(0, 1, 0))
		_auto_fired = false
		_auto_at = _time + 1.6


## Tutorial-Karte wechseln: kurz ausblenden, Text tauschen, wieder einblenden.
func _tut_set(text: String, your_turn: bool, step: int) -> void:
	if tut_card.visible and tut_label.text != text:
		_disappear(tut_card, Vector2(0, -6), 0.14)
		get_tree().create_timer(0.16).timeout.connect(_tut_fill.bind(text, your_turn, step))
		return
	_tut_fill(text, your_turn, step)


func _tut_fill(text: String, your_turn: bool, step: int) -> void:
	if not Game.tutorial():
		return
	tut_label.text = text
	tut_caps.visible = your_turn
	for i in tut_dots.size():
		var d: Panel = tut_dots[i]
		var on := i == step
		d.custom_minimum_size = Vector2(22 if on else 8, 8)
		var ds: StyleBoxFlat = d.get_theme_stylebox("panel")
		ds.bg_color = Style.INK if on else Color(Style.INK, 0.2)
	tut_card.size = Vector2.ZERO
	tut_card.reset_size()
	var vs := _vs()
	tut_card.position = Vector2(roundf((vs.x - tut_card.size.x) * 0.5), _insets.x + Style.LANE_Y)
	if tut_card.visible and tut_card.modulate.a > 0.99:
		_pop(tut_card, 1.03)
		return
	_appear(tut_card, Vector2(0, -10), Style.DUR_IN, 0.98)


## Tippen während des Vorführ-Zugs: sofort loslegen statt warten.
func _on_tutorial_tap() -> void:
	if _tut_wait() == "auto" and not _auto_fired:
		_auto_at = minf(_auto_at, _time)


## Tutorial-Ablauf pro Frame. Robust: Der erste Zug startet sicher von selbst (auch nach
## „Tutorial neu“), und klappt das nicht, darf man nach kurzer Zeit selbst drehen.
func _tutorial_tick() -> void:
	var tw_wait := _tut_wait()
	if tw_wait == "twist":
		# Die Hand zeigt den Zug, bis man selbst dreht (alle paar Sekunden wieder)
		if _time >= _demo_at and world._idle > 1.0 and not _twisting and not world.animating and not Game.busy and not modal_bg.visible:
			_demo_at = _time + 4.0
			_play_demo()
		return
	if tw_wait != "auto":
		return
	if _auto_at == INF and not _auto_fired:
		_auto_at = _time + 1.6
		_tut_step_at = _time
		world.focus_place(Vector3i(0, 1, 0))
	if _auto_fired:
		if _time - _tut_step_at > 14.0 and not world.animating and not Game.busy:
			Game.tutorial_next()      # Zug lief, Schritt ging aber nicht weiter: freigeben
		return
	if _time < _auto_at:
		return
	if modal_bg != null and modal_bg.visible:
		return
	if world.auto_twist(0, 1, 1):
		_auto_fired = true
		_auto_at = INF
	elif _time - _tut_step_at > 6.0 and not world.animating and not Game.busy:
		# Notausgang: nie festhängen, dann zeigt die Hand den Zug und man dreht selbst
		push_warning("Tutorial: Auto-Zug blockiert, gebe Steuerung frei")
		_auto_fired = true
		Game.tutorial_next()


## Tutorial: den Zug vorzeigen (Finger wischt, Scheibe dreht ein Stück an).
func _play_demo() -> void:
	var gs := Game.state
	var a := gs.field_at(Vector3i(1, 1, -1), Vector3i(0, 1, 0))
	var b := gs.field_at(Vector3i(1, 1, 1), Vector3i(0, 1, 0))
	var mid := gs.field_at(Vector3i(1, 1, 0), Vector3i(0, 1, 0))
	if a == null or b == null or mid == null:
		return
	var sa := world.field_screen(a.id)
	var sb := world.field_screen(b.id)
	if not bool(sa["visible"]) or not bool(sb["visible"]):
		return
	var p0: Vector2 = sa["pos"]
	var p1: Vector2 = sb["pos"]
	_demo_until = _time + 1.6           # solange ist es eine Vorführung (kein Abbrechen-Streifen)
	var dir := world.demo_twist(mid.id, p1 - p0, 0, 1)
	if dir == Vector2.ZERO:
		_demo_until = 0.0
		return
	var from := p0 if dir.dot(p1 - p0) > 0.0 else p1
	var to := p1 if from == p0 else p0
	tut_finger.position = from - tut_finger.size * 0.5
	tut_finger.pivot_offset = tut_finger.size * 0.5
	tut_finger.scale = Vector2.ONE * 1.1
	var tw := _fx(tut_finger, "v")
	tw.tween_property(tut_finger, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(tut_finger, "scale", Vector2.ONE, 0.18)
	tw.tween_property(tut_finger, "position", to - tut_finger.size * 0.5, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(tut_finger, "modulate:a", 0.0, 0.3)


func _tut_wait() -> String:
	if not Game.tutorial() or Game.tutorial_step >= TUT_STEPS.size():
		return ""
	return str(TUT_STEPS[Game.tutorial_step]["wait"])


func _on_move_done(kind: String) -> void:
	var grew := _tut_merged
	_tut_merged = false
	_calm_since = _time
	var w := _tut_wait()
	if w == "auto":
		Game.tutorial_next()
	elif w == "twist" and kind == "twist":
		_hide_finger()
		if not grew and _tut_tries < 1:
			# Nichts gewachsen: noch einmal, die Reihe leuchtet weiter, die Hand zeigt es wieder
			_tut_tries += 1
			_tut_set("Fast! Probier die leuchtende Reihe.", true, Game.tutorial_step)
			_demo_at = _time + 1.0
			return
		_finish_tutorial_flow()
	elif not Game.tutorial() and kind == "twist":
		_own_twists += 1
		_coach_check()


## Übergang ins freie Spiel: kein Dialog. Die Karte geht, die Erde erblüht, das Dock gleitet herein.
func _finish_tutorial_flow() -> void:
	_mark_help_seen()
	_own_twists = 0
	_coach_twist = -1
	_miss_streak = 0
	_coach_ready_at = _time + 6.0          # die ersten Sekunden: Ruhe, nur spielen
	Game.finish_tutorial()
	get_tree().create_timer(0.9).timeout.connect(_welcome)


func _welcome() -> void:
	if Game.tutorial() or Game.over:
		return
	_show_banner("welcome", "Super!", "Jetzt spiel einfach weiter.", "check")


func _hide_finger() -> void:
	if tut_finger.has_meta("fx_v"):
		var old: Tween = tut_finger.get_meta("fx_v")
		if old != null and old.is_valid():
			old.kill()
	tut_finger.modulate.a = 0.0


# =============================================================================
# Hinweise im richtigen Moment (blockieren nie)
# =============================================================================

## Hinweis einmalig zeigen (key aus COACH), als Sprechblase an target.
func _coach_once(key: String, target: Control) -> void:
	if Game.tutorial() or Game.coach_seen.has(key) or not COACH.has(key):
		return
	for it in _coach_queue:
		if str((it as Array)[0]) == key:
			return
	_coach_queue.append([key, target])


## Hinweise, die sich aus dem Spielstand ergeben.
func _coach_check() -> void:
	if Game.state == null or Game.tutorial():
		return
	if Game.state.gadgets and Game.state.rain > 0:
		_coach_once("rain", rain_btn)
	if _own_twists >= 4 and _coach_queue.is_empty():
		_coach_once("hold", rain_btn)
	if not Game.onboarding and _miss_streak >= 2:
		_reveal_hint()


## Der Tipp kommt dazu (mit den Münzen), wenn man feststeckt: 2 Fehlversuche hintereinander oder 15 s Pause.
func _reveal_hint() -> void:
	if Game.tutorial() or _known("hint") or not Game.state.gadgets:
		return
	_reveal("hint")
	_reveal("coins")
	refresh()
	_coach_once("hint", hint_btn)


## Text eines Hinweises (manche hängen vom Spielstand ab).
func _coach_text(key: String) -> String:
	var gs := Game.state
	if key == "fire" and gs != null and gs.rain <= 0:
		return "Feuer! Brennende Felder schrumpfen beim nächsten Zug. Regen löscht sie. Jedes Feuer kostet ein Herz."
	if key == "age" and gs != null:
		var age := gs.age_name()
		return "Deine Welt ist jetzt %s %s. %s" % [str(AGE_PREP.get(age, "in der")), age, _next_age_text()]
	return str(COACH.get(key, ""))


func _coach_icon(key: String) -> String:
	if key == "age" and Game.state != null:
		return STAGE_ICON[clampi(Game.state.best_stage, 1, Balance.MAX_STAGE)]
	return str(COACH_ICON.get(key, "info"))


## „Als Nächstes: Antike – bau ein Haus.“ (oder: das letzte Zeitalter)
func _next_age_text() -> String:
	var gs := Game.state
	if gs == null:
		return ""
	var a := gs.age()
	if a >= Balance.AGES.size():
		return "Das letzte Zeitalter!"
	var st := int(Balance.AGE_FROM_STAGE[a])
	return "Als Nächstes: %s – bau %s." % [str(Balance.AGES[a]), str(STAGE_WITH_ARTICLE[clampi(st, 0, STAGE_WITH_ARTICLE.size() - 1)])]


## Zeigt den nächsten Hinweis, wenn gerade Ruhe ist.
func _coach_tick() -> void:
	if coach.visible:
		if _time > _coach_until:
			_coach_dismiss()
		return
	if _coach_queue.is_empty() or _time < _coach_ready_at:
		return
	if Game.tutorial() or Game.busy or Game.over or world.animating or _twisting:
		return
	if modal_bg.visible or tip_card.visible or _lp_node != null:
		return
	if _coach_twist == _own_twists:
		return      # höchstens ein Hinweis pro Zug
	for i in _coach_queue.size():
		var item: Array = _coach_queue[i]
		var key: String = str(item[0])
		var target: Control = item[1]
		if not is_instance_valid(target) or Game.coach_seen.has(key):
			_coach_queue.remove_at(i)
			return
		if key == "rain" and _own_twists < 2 and not _fire_seen:
			continue      # nicht direkt nach dem Tutorial
		var in_dock := target.is_inside_tree() and dock.is_ancestor_of(target)
		if in_dock and (sheet.visible or mode_card.visible):
			continue
		if not in_dock and (_toast_busy or banner.visible or preview_card.visible):
			continue      # oben ist gerade die Meldungsspur belegt
		if not target.is_visible_in_tree():
			continue
		_coach_queue.remove_at(i)
		Game.coach_seen[key] = true
		Game.save_settings()
		_coach_twist = _own_twists
		_coach_in_hud = not in_dock
		_place_coach(target, _coach_icon(key), _coach_text(key))
		return


func _place_coach(target: Control, icon_name: String, text: String) -> void:
	_set_tile(coach_tile, icon_name, _tint_for_icon(icon_name))
	coach_label.text = text
	coach.size = Vector2.ZERO
	coach.reset_size()
	var vs := _vs()
	var r := target.get_global_rect()
	var below := r.get_center().y < vs.y * 0.5
	var x := clampf(r.get_center().x - coach.size.x * 0.5, Style.MARGIN, vs.x - Style.MARGIN - coach.size.x)
	var y := r.end.y + 16.0 if below else r.position.y - coach.size.y - 16.0
	coach.position = Vector2(roundf(x), roundf(y))
	var ax := clampf(r.get_center().x, x + 28.0, x + coach.size.x - 28.0)
	coach_arrow.position = Vector2(ax - 9.0, (y - 8.0) if below else (y + coach.size.y - 10.0))
	var from := Vector2(0, -10) if below else Vector2(0, 10)
	_appear(coach_arrow, from, 0.28)
	_appear(coach, from, 0.28, 0.96)
	if target.is_visible_in_tree():
		_pop(target)
		_ripple(target, Style.SUN)
	_coach_until = _time + 5.0


func _coach_dismiss() -> void:
	_coach_until = INF
	if coach == null or not coach.visible:
		return
	_disappear(coach, Vector2.ZERO, Style.DUR_FAST)
	_disappear(coach_arrow, Vector2.ZERO, Style.DUR_FAST)
	_coach_ready_at = _time + 1.0


# =============================================================================
# Drehen: Abbrechen-Streifen oben
# =============================================================================

func _on_twist_state(on: bool) -> void:
	_twisting = on
	_on_cancel_hover(false)
	_calm_since = _time
	var h := _insets.x + 92.0
	if not on:
		_demo_until = 0.0     # Vorführung vorbei (oder abgebrochen): die nächste echte Drehung zeigt den Streifen
	if on and (_time < _demo_until or (Game.tutorial() and Game.tutorial_step == 0)):
		return      # die Hand führt vor: kein Abbrechen-Streifen
	if on:
		_hide_finger()
		_hide_tip()
		_coach_dismiss()
		if bonus_mode != "":
			_set_bonus_mode("")      # sobald man dreht, ist der Bonus wieder abgewählt
		_close_sheet()
		if toast.visible:
			_toast_until = minf(_toast_until, _time)     # Spur frei machen für die Vorschau
		cancel_strip.position = Vector2.ZERO
		_appear(cancel_strip, Vector2(0, -h * 0.6), Style.DUR_IN)
	else:
		_disappear(cancel_strip, Vector2(0, -h * 0.5), Style.DUR_OUT)


func _on_cancel_hover(on: bool) -> void:
	if bool(cancel_strip.get_meta("hover", false)) == on:
		return
	cancel_strip.set_meta("hover", on)
	var s: StyleBoxFlat = cancel_strip.get_meta("sb")
	var tw := _fx(cancel_strip, "c")
	tw.set_parallel(true)
	tw.tween_property(s, "bg_color", Color(Style.FIRE, 0.94) if on else Color(Style.FIRE_TINT, 0.97), Style.DUR_FAST)
	tw.tween_method(_set_font_color.bind(cancel_label), Color.WHITE if not on else Style.FIRE_DEEP, Color.WHITE if on else Style.FIRE_DEEP, Style.DUR_FAST)
	cancel_label.text = "Loslassen zum Abbrechen" if on else "Hierher ziehen zum Abbrechen"
	if on:
		Style.haptic(Style.HAPTIC_HOVER)
		_pop(cancel_icon, 1.25)


# =============================================================================
# Felder antippen: Bonus einsetzen oder Info-Karte
# =============================================================================

func _on_bolt_drawn(fid: int, row: Array) -> void:
	if Game.use_bonus("bolt", fid, row):
		_set_bonus_mode("")
		_bubble(fid, Game.praise(), "up", Style.SUN_DEEP)


func _on_field_tapped(fid: int) -> void:
	if bonus_mode != "":
		var kind := bonus_mode
		if Game.busy or Game.over or world.animating:
			return
		var err := Game.state.can_bonus(kind, Game.state.fields[fid])
		if err != "":
			# Hier geht es nicht: Feld wackelt, die Ziele leuchten noch einmal auf, die Karte zeigt, was zu tun ist
			world.nudge(fid)
			_world_targets(kind)
			_pop(mode_card, 1.05)
			return
		if Game.use_bonus(kind, fid, [], true):
			_bubble(fid, Game.praise(), "up", Style.WATER_DEEP if kind != "bolt" else Style.SUN_DEEP)
			# Regen bleibt ausgewählt, solange noch Regen da ist (mehrmals hintereinander gießen)
			if kind != "rain":
				_set_bonus_mode("")
		return
	if world.selected == fid and sheet.visible:
		_close_sheet()
		return
	_coach_dismiss()
	world.select(fid)
	var was_open := sheet.visible and sheet.modulate.a > 0.99
	_sheet_field = fid
	_fill_sheet(fid)
	_place_context(sheet)
	if was_open:
		_pop(sheet_tile, 1.1)
	else:
		_appear(sheet, Vector2(0, 20), Style.DUR_IN)


func _sheet_bonus(kind: String) -> void:
	var fid := _sheet_field
	if fid < 0:
		return
	_close_sheet()
	if Game.use_bonus(kind, fid, []):
		_bubble(fid, Game.praise(), "up", Style.WATER_DEEP if kind == "rain" else Style.SUN_DEEP)


func _close_sheet() -> void:
	_sheet_field = -1
	world.select(-1)
	if sheet.visible:
		_disappear(sheet, Vector2(0, 16), Style.DUR_FAST)


func _fill_sheet(fid: int) -> void:
	var gs := Game.state
	var f: FieldData = gs.fields[fid]
	var tint: Color = Style.STAGE_TINT[clampi(f.stage, 0, Style.STAGE_TINT.size() - 1)]
	_set_tile(sheet_tile, STAGE_ICON[f.stage], tint)
	sheet_title.text = GameState.stage_name(f.stage)
	if f.burning:
		sheet_caps.text = "Brennt!"
	elif f.stage == 0:
		sheet_caps.text = "Leer"
	elif f.is_civilisation():
		sheet_caps.text = "Siedlung"
	else:
		sheet_caps.text = "Natur"
	var can_grow := f.stage > 0 and f.stage < Balance.MAX_STAGE
	sheet_ladder.visible = can_grow
	if can_grow:
		for ic in sheet_from:
			(ic as TextureRect).texture = Style.icon(STAGE_ICON[f.stage])
		sheet_next.texture = Style.icon(STAGE_ICON[f.stage + 1])
	var tut := Game.tutorial()      # Regen und Blitz kommen erst nach dem Tutorial
	var body := ""
	if f.burning:
		body = "Brennt! Beim nächsten Zug schrumpft es – außer du gießt es."
	elif f.stage == 0:
		body = "Leere Erde." if tut else "Leere Erde. Mit Regen wird hier eine Wiese."
	elif f.stage >= Balance.MAX_STAGE:
		body = "Größer geht es nicht!"
	sheet_body.text = body
	sheet_body.visible = body != ""
	var blocked := Game.busy or Game.over or world.animating
	sheet_rain.visible = not tut and gs.rain > 0 and (f.burning or (f.stage == gs.lowest_stage() and f.stage < Balance.MAX_STAGE))
	sheet_rain.disabled = blocked or gs.can_bonus("rain", f) != ""
	sheet_rain.text = ("Löschen (%d)" if f.burning else "Gießen (%d)") % gs.rain
	sheet_bolt.visible = not tut and gs.bolts > 0 and not gs.corner_diagonal(f).is_empty()
	sheet_bolt.disabled = blocked
	sheet_bolt.text = "Blitz (%d)" % gs.bolts
	sheet_acts.visible = sheet_rain.visible or sheet_bolt.visible


# =============================================================================
# Jubel-Pille, Blasen, Meldungen
# =============================================================================

## kind: merge, combo, age, face, miss, fire. Ein neuer Aufruf ersetzt die aktuelle Pille.
func _show_banner(kind: String, caps: String, text: String, icon_name: String) -> void:
	var bg := Style.SURFACE
	var cc := Style.SUN_DEEP
	if kind == "age":
		bg = Style.SUN_TINT
	elif kind == "miss" or kind == "fire":
		bg = Style.FIRE_TINT
		cc = Style.FIRE_DEEP
	var sb: StyleBoxFlat = banner.get_theme_stylebox("panel")
	sb.bg_color = bg
	banner_caps.text = caps
	banner_caps.visible = caps != ""
	banner_caps.add_theme_color_override("font_color", cc)
	banner_text.text = text
	banner_icon.texture = Style.icon(icon_name)
	banner.size = Vector2.ZERO
	banner.reset_size()
	var vs := _vs()
	var y := maxf(_insets.x + Style.BANNER_Y, _lane_bottom() + 12.0)
	banner.position = Vector2(roundf((vs.x - banner.size.x) * 0.5), roundf(y))
	_appear(banner, Vector2(0, 8), 0.3, 0.6)
	var hold := 1.6 if kind == "age" or kind == "combo" else 1.1
	if kind == "welcome":
		hold = 2.5
	var tw := _fx(banner, "t")
	tw.tween_interval(hold)
	tw.tween_callback(_disappear.bind(banner, Vector2(0, -16), 0.22, false))


func _on_merged(fid: int, points: int, combo: int, stage: int) -> void:
	_tut_merged = true
	_miss_streak = 0
	_bubble(fid, "+%d" % points, "up", Style.SUN_DEEP)
	if combo >= 2:
		_show_banner("combo", "", "%s! ×%d" % [GameState.stage_name(stage), combo], STAGE_ICON[clampi(stage, 0, Balance.MAX_STAGE)])
		Style.haptic(Style.HAPTIC_COMBO)
	else:
		_show_banner("merge", "", GameState.stage_name(stage) + "!", STAGE_ICON[clampi(stage, 0, Balance.MAX_STAGE)])
		Style.haptic(Style.HAPTIC_MERGE)


## Fehlversuch: Pille zeigen, dann fliegt eine Flamme oben in ihren Platz.
func _on_miss(_fid: int, count: int) -> void:
	if Game.tutorial():
		return
	_miss_streak += 1
	# Die Flammen oben erscheinen mit dem ersten Fehlversuch (die Flamme fliegt hinein)
	_reveal("flames")
	_chip_show(flame_chip, true, true)
	_coach_once("miss", flame_chip)
	if count < Balance.FIRE_AFTER:
		_show_banner("miss", "", "Nichts gewachsen", "fire_off")
		Style.haptic(Style.HAPTIC_TAP)
	var slot: TextureRect = miss_flames[clampi(count - 1, 0, miss_flames.size() - 1)]
	slot.set_meta("lock", _time + 1.2)
	var fl := TextureRect.new()
	fl.texture = Style.icon("fire")
	fl.size = Vector2(56, 56)
	fl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gift_layer.add_child(fl)
	var vs := _vs()
	var from_c := Vector2(vs.x * 0.5, maxf(_insets.x + Style.BANNER_Y, _lane_bottom() + 12.0) + 110.0)
	fl.position = from_c - fl.size * 0.5
	fl.pivot_offset = fl.size * 0.5
	fl.scale = Vector2.ZERO
	var tw := fl.create_tween()
	tw.tween_property(fl, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.3)
	tw.tween_callback(_flame_fly.bind(fl, slot))


func _flame_fly(fl: TextureRect, slot: TextureRect) -> void:
	var from_c := fl.position + fl.size * 0.5
	var tw := _fly(fl, from_c, slot.get_global_rect().get_center(), 0.5, 80.0, 0.45)
	tw.tween_callback(_flame_land.bind(fl, slot))


func _flame_land(fl: TextureRect, slot: TextureRect) -> void:
	fl.queue_free()
	slot.set_meta("lock", 0.0)
	_pop(flame_chip, 1.12)
	refresh()


func _on_face(fid: int, points: int, stage: int) -> void:
	_show_banner("face", "Ganze Seite", GameState.stage_name(stage) + "!", "up")
	Style.haptic(Style.HAPTIC_COMBO)
	if fid >= 0:
		_bubble(fid, "+%d" % points, "up", Style.SUN_DEEP)


func _on_disaster(kind: String, fid: int) -> void:
	_fire_seen = true
	if kind == "fire":
		_coach_once("fire", rain_btn if Game.state.rain > 0 and rain_btn.is_visible_in_tree() else flame_chip)
		_reveal("undo")              # wer brennt, lernt Zurück kennen
		_coach_once("undo", undo_btn)
	_show_banner("fire", "-1 Herz", str(GameState.DISASTER_NAME.get(kind, "Feuer")) + "!", "fire")
	Style.haptic(Style.HAPTIC_FIRE)
	if fid >= 0:
		_bubble(fid, "-1 Herz", "heart", Style.FIRE_DEEP)


func _on_deltas(list: Array, _gain: int) -> void:
	for d in list:
		var fid := int(d["field"])
		match str(d["change"]):
			"lost":
				_bubble(fid, "verschmutzt", "smog", Style.FIRE_DEEP)
			"new":
				_bubble(fid, "Wiese", "meadow", Style.LEAF_DEEP)
	refresh()


## Kleine Pille über einem Feld (folgt dem Feld, steigt auf und verblasst).
func _bubble(fid: int, text: String, icon_name: String, color: Color) -> void:
	var b := Button.new()
	b.text = text
	b.icon = Style.icon(icon_name)
	b.add_theme_constant_override("icon_max_width", 16)
	b.add_theme_constant_override("h_separation", 4)
	b.add_theme_font_override("font", Style.black())
	b.add_theme_font_size_override("font_size", 15)
	var s := Style.lift(Style.box(Style.SURFACE, 14, 10, 3), 1)
	s.content_margin_left = 6
	Style.skin(b, s, s, color)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.focus_mode = Control.FOCUS_NONE
	bubble_layer.add_child(b)
	_bubbles.append({"node": b, "fid": fid, "t": 0.0, "dur": 2.6})
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


## Meldungen: helle Banner in der Spur unter der Kopfzeile, nacheinander, ohne Doppelte.
func _on_message(text: String, kind: String) -> void:
	if _toast_busy and toast_label.text == text:
		return
	for m in _toasts:
		if str((m as Dictionary)["text"]) == text:
			return
	_toasts.append({"text": text, "kind": kind})
	while _toasts.size() > 3:
		_toasts.pop_front()


func _toast_tick() -> void:
	if _toast_busy:
		if not _toast_leaving and _time >= _toast_until:
			_toast_leaving = true
			_toast_free_at = _time + Style.DUR_OUT + 0.08
			_disappear(toast, Vector2(0, -12), Style.DUR_OUT)
		elif _toast_leaving and _time >= _toast_free_at:
			_toast_busy = false
			_toast_leaving = false
		return
	if _toasts.is_empty() or _twisting:
		return
	if coach.visible and _coach_in_hud:
		return      # erst der Hinweis oben, dann die Meldung
	var m: Dictionary = _toasts.pop_front()
	var text: String = str(m["text"])
	var kind: String = str(m["kind"])
	_fill_toast(text, kind)
	_toast_busy = true
	_toast_leaving = false
	_toast_until = _time + clampf(1.6 + text.length() * 0.035, Style.TOAST_MIN, Style.TOAST_MAX)
	_appear(toast, Vector2(0, -18), Style.DUR_IN, 0.96)


func _fill_toast(text: String, kind: String) -> void:
	toast_label.text = text
	var icon_name: String = str(TOAST_ICON.get(kind, "info"))
	var tint := Style.WATER_TINT
	var fg := Style.INK
	match kind:
		"good":
			tint = Style.LEAF_TINT
			fg = Style.LEAF_DEEP
		"bad":
			tint = Style.FIRE_TINT
			fg = Style.FIRE_DEEP
		"reward":
			tint = Style.SUN_TINT
			fg = Style.SUN_DEEP
	_set_tile(toast_tile, icon_name, tint)
	toast_label.add_theme_color_override("font_color", fg)
	var max_text := float(Style.CONTENT_W - 20 * 2 - 40 - 12)
	var w := Style.font_w(Style.W_LABEL).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if w > max_text else TextServer.AUTOWRAP_OFF
	toast_label.custom_minimum_size.x = max_text if w > max_text else 0.0
	toast.size = Vector2.ZERO
	toast.reset_size()
	var vs := _vs()
	toast.position = Vector2(roundf((vs.x - toast.size.x) * 0.5), roundf(_lane_y()))


func _lane_y() -> float:
	if tut_card != null and tut_card.visible and Game.tutorial():
		return tut_card.position.y + tut_card.size.y + 12.0
	return _insets.x + Style.LANE_Y


func _lane_bottom() -> float:
	var y := _lane_y() - 12.0
	if preview_card.visible:
		y = maxf(y, preview_card.position.y + preview_card.size.y)
	if toast.visible:
		y = maxf(y, toast.position.y + toast.size.y)
	return y


# =============================================================================
# Dialoge
# =============================================================================

func _open_modal(card: Control, closable: bool = true) -> void:
	if _modal != null and _modal != card:
		_hide_now(_modal)
	_modal = card
	_modal_closable = closable
	_hide_tip()
	_coach_dismiss()
	modal_bg.visible = true
	var tb := _fx(modal_bg, "v")
	tb.tween_property(modal_bg, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fit_modal(card)
	card.size = Vector2.ZERO
	card.reset_size()
	var vs := _vs()
	card.position = ((vs - card.size) * 0.5).round()
	_appear(card, Vector2(0, 10), Style.DUR_MODAL, 0.94)


## Lange Inhalte scrollen, statt aus dem Bildschirm zu laufen.
func _fit_modal(card: Control) -> void:
	if not card.has_meta("scroll"):
		return
	var sc: ScrollContainer = card.get_meta("scroll")
	var inner: Control = card.get_meta("inner")
	var reserve := float(card.get_meta("reserve", 140.0))
	var max_h := _vs().y - _insets.x - _insets.y - 96.0 - reserve
	sc.custom_minimum_size = Vector2(0, maxf(160.0, minf(inner.get_combined_minimum_size().y, max_h)))
	sc.scroll_vertical = 0


func _close_modal(instant: bool = false) -> void:
	var card := _modal
	_modal = null
	if instant:
		if card != null:
			_hide_now(card)
		if modal_bg.has_meta("fx_v"):
			var old: Tween = modal_bg.get_meta("fx_v")
			if old != null and old.is_valid():
				old.kill()
		modal_bg.visible = false
		modal_bg.modulate.a = 0.0
		return
	if card != null:
		_disappear(card, Vector2(0, 6), Style.DUR_FAST)
	if not modal_bg.visible:
		return
	var tb := _fx(modal_bg, "v")
	tb.tween_property(modal_bg, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tb.tween_callback(modal_bg.hide)


## Tippen neben die Karte schließt Menü, Hilfe und Credits (nicht das Spielende).
func _on_backdrop_input(ev: InputEvent) -> void:
	var down := ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed
	if not down or not _modal_closable or _modal == null:
		return
	if _modal == ad_card:
		_on_ad_declined()
	else:
		_close_modal()


func _open_menu() -> void:
	_refresh_menu()
	_open_modal(menu_card)


func _refresh_menu() -> void:
	var cur := _current_mode_key()
	for key in _menu_rows:
		var row: Dictionary = _menu_rows[key]
		var b: Button = row["btn"]
		var rc: Label = row["caps"]
		var num: Label = row["num"]
		var is_cur := str(key) == cur and not Game.tutorial()
		var n: StyleBoxFlat = b.get_meta("sb")
		n.bg_color = Style.SUN_TINT if is_cur else Style.SURFACE_2
		rc.text = "Aktuell" if is_cur else "Rekord"
		rc.add_theme_color_override("font_color", Style.SUN_DEEP if is_cur else Style.INK_3)
		var best := _mode_best(str(key))
		num.text = str(best) if best > 0 else "–"
	_sync_switch(_music_switch, Game.music_on)
	_sync_switch(_sfx_switch, Game.sfx_on)


func _sync_switch(b: Button, on: bool) -> void:
	b.set_pressed_no_signal(on)
	_skin_switch(b, on)
	var knob: Panel = b.get_meta("knob")
	knob.position = Vector2(25.0 if on else 3.0, 3.0)


## "einfach" | "mittel" | "schwer" | "challenge"
func _current_mode_key() -> String:
	if Game.has_method("mode_key"):
		return str(Game.call("mode_key"))
	if Game.state != null and not Game.state.endless:
		return "challenge"
	var keys := ["einfach", "mittel", "schwer"]
	var lv = Game.get("level")
	return str(keys[clampi(int(lv) if lv != null else 1, 0, 2)])


func _mode_best(key: String) -> int:
	if Game.has_method("best_for"):
		return int(Game.call("best_for", key))
	var legacy := {"einfach": "0", "mittel": "1", "schwer": "2", "challenge": "challenge"}
	var store = Game.get("_best")
	if store is Dictionary:
		var d: Dictionary = store
		if d.has(key):
			return int(d[key])
		return int(d.get(str(legacy.get(key, key)), 0))
	return 0


## Läuft gerade ein Spiel, das man verlieren würde?
func _game_running() -> bool:
	return Game.state != null and Game.state.score > 0 and not Game.over and not Game.tutorial()


## Zeile im Menü angetippt: die laufende Spielart = weiterspielen, sonst (nach Rückfrage) neu starten.
func _on_mode_row(key: String) -> void:
	if key == _current_mode_key() and _game_running():
		_close_modal()
		return
	_ask_new_game(key)


func _ask_new_game(key: String) -> void:
	if not _game_running():
		_run_new(key)
		return
	_confirm_key = key
	_open_modal(confirm_card)


func _on_confirm_new() -> void:
	var key := _confirm_key
	_confirm_key = ""
	_run_new(key)


func _on_confirm_back() -> void:
	_confirm_key = ""
	_open_menu()


func _run_new(key: String) -> void:
	if key == "tutorial":
		_close_modal(true)
		Game.restart_tutorial()
	elif key != "":
		_start_mode(key)


## Neues Spiel in einer Spielart: "einfach" | "mittel" | "schwer" | "challenge".
func _start_mode(key: String) -> void:
	_close_modal(true)
	if Game.has_method("start_mode"):
		Game.call("start_mode", key)
		return
	if Game.tutorial():
		Game.end_tutorial()
	var lv := {"einfach": 0, "mittel": 1, "schwer": 2, "challenge": 1}
	Game.callv("new_game", [0, 0 if key == "challenge" else 1, int(lv.get(key, 1))])


func _on_profile() -> void:
	_pop(_profile_btn, 1.08)
	var d := _tooltip_for("profile")
	_show_tooltip(_profile_btn, str(d["icon"]), str(d["title"]), str(d["body"]))
	_tip_hide_at = _time + 2.6


func _on_help_done() -> void:
	_mark_help_seen()
	_close_modal()


func _restart_tutorial() -> void:
	_ask_new_game("tutorial")


func _restart() -> void:
	_close_modal(true)
	Game.new_game()


func _show_help() -> void:
	var gs := Game.state
	var top_stage := gs.best_stage if gs != null else 1
	for i in _help_ladder.size():
		var ic: TextureRect = _help_ladder[i]
		var reached := i + 1 <= top_stage
		ic.modulate = Color(1, 1, 1, 1) if reached else Color(0.35, 0.37, 0.42, 0.28)
	_help_bolt_row.visible = Game.coach_seen.has("bolt") or _known("bolt") or (gs != null and gs.bolts > 0)
	_help_monsoon_row.visible = Game.coach_seen.has("monsoon") or (gs != null and gs.monsoon_unlocked)
	_open_modal(help_card)


func _on_new_game() -> void:
	_close_modal(true)
	_set_bonus_mode("")
	_hide_now(sheet)
	_hide_now(tip_card)
	_hide_now(coach)
	_hide_now(coach_arrow)
	_hide_now(banner)
	_hide_now(preview_card)
	_coach_until = INF
	_sheet_field = -1
	world.select(-1)
	_shown_score = -1
	_last_rain = -1
	_last_bolts = -1
	_last_monsoons = -1
	_last_lives = -1
	_last_age = ""
	_miss_streak = 0
	_calm_since = _time
	_hide_finger()
	_toasts.clear()
	for fl in miss_flames:
		(fl as TextureRect).set_meta("lock", 0.0)
	for bd in _bubbles:
		(bd["node"] as Control).queue_free()
	_bubbles.clear()
	refresh()
	if Game.state != null and Game.state.score == 0:
		_hud_entrance()


func _on_game_over() -> void:
	var gs := Game.state
	var died := gs.died()
	over_title.text = "Deine Welt ist verbrannt" if died else "Geschafft!"
	_set_tile(over_tile, "fire" if died else "trophy", Style.FIRE_TINT if died else Style.SUN_TINT)
	var bs := clampi(gs.best_stage, 1, Balance.MAX_STAGE)
	over_age_icon.texture = Style.icon(STAGE_ICON[bs])
	over_age_label.text = gs.age_name()
	if Game.new_record:
		over_rec_label.text = "Neuer Rekord!"
		over_rec_label.add_theme_color_override("font_color", Style.SUN_DEEP)
		_over_rec_sb.bg_color = Style.SUN_TINT
	else:
		over_rec_label.text = "Rekord: %d" % Game.best
		over_rec_label.add_theme_color_override("font_color", Style.INK)
		_over_rec_sb.bg_color = Style.SURFACE_2
	continue_btn.visible = Game.can_continue()
	_hide_finger()
	over_undo_btn.visible = Game.can_undo()
	_open_modal(over_card, false)
	_count_up(over_score, gs.score, 0.9)
	if Game.new_record:
		_pop.call_deferred(over_rec_label.get_parent(), 1.15)


# =============================================================================
# Einstellungen: Musik und Effekte
# =============================================================================

## Ton: eine Quelle – Game hält, wendet an und speichert die Einstellung.
func _on_music_toggled(on: bool) -> void:
	Game.set_audio(on, Game.sfx_on)


func _on_sfx_toggled(on: bool) -> void:
	Game.set_audio(Game.music_on, on)


func _seen_help() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return false
	return bool(cfg.get_value("hilfe", "gesehen_v4", false))


func _mark_help_seen() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)            # laden, sonst gehen die Ton-Einstellungen verloren
	cfg.set_value("hilfe", "gesehen_v4", true)
	cfg.save(SETTINGS_PATH)


# =============================================================================
# Für die automatischen Screenshots
# =============================================================================

func debug_show_field(fid: int) -> void:
	_on_field_tapped(fid)


func debug_show_help() -> void:
	_show_help()


## Erklärkarte direkt öffnen (wie nach langem Drücken), z. B. debug_show_tooltip("rain").
func debug_show_tooltip(key: String) -> void:
	var target: Control = rain_btn
	match key:
		"menu":
			target = menu_b
		"score":
			target = score_box
		"credits":
			target = credits_btn
		"age":
			target = age_chip
		"flames":
			target = flame_chip
		"hearts":
			target = hearts_chip
		"undo", "bolt", "monsoon", "hint":
			target = _slot_btn(key)
	if not target.is_visible_in_tree():
		target = hearts_chip
	var d := _tooltip_for(key)
	if d.is_empty():
		return
	_show_tooltip(target, str(d.get("icon", "info")), str(d.get("title", "")), str(d.get("body", "")))
	_tip_owner = target
	_tip_hide_at = INF


## Für spätere Screenshots: alles aufdecken, als kenne man das Spiel schon.
func debug_reveal_all() -> void:
	for k in ["show_undo", "show_hint", "show_bolt", "show_coins", "show_flames"]:
		Game.coach_seen[str(k)] = true
	refresh()


func debug_close_all() -> void:
	_close_modal(true)
	_set_bonus_mode("")
	_hide_now(mode_card)
	_hide_now(sheet)
	_hide_now(tip_card)
	_hide_now(coach)
	_hide_now(coach_arrow)
	_hide_now(banner)
	_sheet_field = -1
	world.select(-1)
