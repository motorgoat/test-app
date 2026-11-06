class_name GameUI
extends CanvasLayer
## Oberfläche von gdpd, Handy zuerst. Feste Zonen, damit sich nichts überlappt:
##   oben Kopfzeile (Menü · Glaube · Münzen, darunter Zeitalter · Flammen · Herzen, darunter Weltwaage · Ziel),
##   darunter die Meldungsspur (Tutorial, Vorschau, Meldungen), Mitte der Würfel,
##   unten die Kontextzone (Feld-Karte oder Bonus-Hinweis) über dem schwebenden Dock.
## Beim Drehen erscheint ganz oben ein roter Streifen: dorthin ziehen = abbrechen.

const STAGE_ICON = GameState.STAGE_ICON


## Die Weltwaage als kleiner Balken: links Natur (rot = Wildnis), Mitte grün, rechts gelb (viel Stadt), dann rot (Smog).
## Der Knopf gleitet weich zum Wert W (−100 … 100).
class WorldScale extends Control:
	var value := 0.0
	var target := 0.0
	var wild_warn := false     # erst wenn es Menschen gibt, ist „nur Wildnis“ ein Problem (dann rot)

	func _init() -> void:
		custom_minimum_size = Vector2(150, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func set_w(w: int, instant: bool = false) -> void:
		target = clampf(float(w), -100.0, 100.0)
		if instant:
			value = target
		queue_redraw()

	func _process(delta: float) -> void:
		if absf(value - target) > 0.05:
			value = lerpf(value, target, 1.0 - exp(-5.0 * delta))
			if absf(value - target) <= 0.05:
				value = target
			queue_redraw()

	func _x(w: float) -> float:
		var r := 8.0
		return r + (w + 100.0) / 200.0 * (size.x - 2.0 * r)

	func _draw() -> void:
		var h := 8.0
		var cy := size.y * 0.5
		var wild_col := Color("#F0907F") if wild_warn else Color("#B9DDB0")
		var segs := [[-100.0, float(Balance.WILD_AT), wild_col], [float(Balance.WILD_AT), float(Balance.CITY_AT), Color("#7CC98F")],
			[float(Balance.CITY_AT), float(Balance.SMOG_AT), Color("#F5C76A")], [float(Balance.SMOG_AT), 100.0, Color("#F0907F")]]
		for sg in segs:
			var x0 := _x(float(sg[0]))
			var x1 := _x(float(sg[1]))
			draw_rect(Rect2(x0, cy - h * 0.5, x1 - x0, h), sg[2])
		draw_circle(Vector2(_x(-100.0), cy), h * 0.5, segs[0][2])
		draw_circle(Vector2(_x(100.0), cy), h * 0.5, segs[3][2])
		var kx := _x(value)
		draw_circle(Vector2(kx, cy + 1.5), 8.5, Color(0.12, 0.14, 0.19, 0.16))
		draw_circle(Vector2(kx, cy), 8.0, Color.WHITE)
		draw_arc(Vector2(kx, cy), 7.0, 0.0, TAU, 24, Style.INK, 2.5, true)

var world: World
var root: Control
var day_ui: DayUI          # Die Schöpfung in 7 Tagen: Übersicht, Ziel-Karte, Ziel-Chip, Sieg/Fehlversuch
var notifier: Notifier    # Erinnerungen als Handy-Benachrichtigung (ohne Plugin: nur Protokoll-Zeilen)
# Menü: Charakter, Erinnerung, Test
var _menu_char: Control
var _menu_char_name: Label
var _menu_char_sub: Label
var _tone_seg: HBoxContainer
var _remind_seg: HBoxContainer
var _remind_sub: Label
var _remind_time_row: HBoxContainer
var _remind_time: Label
var _remind_note: Label
var _remind_settings: Button
var _remind_box: Control
var _test_box: Control
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
var row3: HBoxContainer
var scale_chip: PanelContainer
var _scale_sb: StyleBoxFlat
var scale_bar: WorldScale
var goal_chip: PanelContainer
var goal_label: Label
var goal_icon: TextureRect
var _goal_sb: StyleBoxFlat
var faith_icon: TextureRect

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
var sheet_or: Label
var sheet_next2: TextureRect
var sheet_rule: Label
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
var strike_btn: Button
var flood_btn: Button

# --- Wahl-Karte „Dein Wille geschehe“ ---
var choice_scrim: ColorRect
var choice_catcher: Control
var choice_card: PanelContainer
var choice_caps: Label
var choice_title: Label
var choice_btns: Array = []        # zwei große Knöpfe
var choice_tiles: Array = []
var choice_names: Array = []
var choice_lines: Array = []
var choice_bars: Array = []        # dünner Zeitbalken im Standard-Knopf
var choice_tags: Array = []        # „Empfohlen“ (nach einem Tipp)
var mini_pill: PanelContainer
var mini_btns: Array = []
var mini_bar: Panel           # Zeitbalken der kleinen Pille (bis die Gewohnheit gilt)
var _choice: Dictionary = {}       # offene Wahl (Kopie von Game.pending_choice)
var _choice_left := 0.0
var _choice_total := 0.0
var _choice_full := false          # große Karte (sonst die kleine Pille)
var _choice_outside := 0           # Tutorial: daneben getippt (beim zweiten Mal gilt der Standard)
var _choice_gen := 0
var _hint_live := false            # gerade wurde ein Tipp gekauft: die empfohlene Wahl leuchtet
var long_press := Style.LONG_PRESS # Screenshots auf langsamer Grafik: länger, damit Tippen kein Halten wird
var _pick := -1                    # Strafe: angetipptes Ziel (zweites Tippen bestätigt)
var _anchor: Control               # unsichtbarer Anker für Hinweise an einem Feld
var _last_faith := -1
var _last_scale_zone := ""
var _smog_banner := false
var _banner_keep_until := 0.0      # bis dahin bleibt eine wichtige Pille stehen
var _banner_next: Array = []       # die Pille, die danach kommt
var _resume_mode := ""             # Werkzeug, das nach der Wahl wieder gewählt wird (Regen)          # in diesem Spiel kam der Smog-Hinweis schon

# --- Überlagerungen ---
var bubble_layer: Control
var gift_layer: Control
var coach_arrow: Panel
var coach: PanelContainer
var coach_tile: PanelContainer      # das kleine Themen-Abzeichen am Kopfbild des Charakters
var coach_speaker: Control         # Kopfbild des eigenen Charakters: Er spricht jeden Hinweis
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
var _menu_cont: Button
var _menu_days: Button
var _menu_free_caps: Label
var _music_switch: Button
var _sfx_switch: Button
var _ask_switch: Button
var _profile_btn: Button
var _ask_rows: Array = []
var buy_card: PanelContainer
var buy_tile: PanelContainer
var buy_label: Label
var buy_btn: Button
var _buy_kind := ""
var confirm_card: PanelContainer
var _help_tree: HFlowContainer
var _confirm_yes: Button
var _confirm_key := ""        # was nach „Ja“ startet: Spielart oder "tutorial"
var _help_rows: Dictionary = {}     # Zeilen der Hilfe, die erst erscheinen, wenn man das Ding kennt
var _help_goal: Label
const SLOT_W := 92.0          # Breite eines Platzes im Dock (das Dock wächst mit den sichtbaren Plätzen)

# --- Zustand ---
var bonus_mode := ""          # "", "rain", "bolt", "monsoon", "strike" oder "flood": nächstes angetipptes Feld bekommt das Werkzeug
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
	{"wait": "auto", "text": "Bring 3 gleiche in eine Reihe."},
	{"wait": "twist", "text": "Jetzt du! Wisch die leuchtende Reihe."},
]

# Hinweise im richtigen Moment (nicht blockierend, einer nach dem anderen, je einmal)
const COACH = {
	"miss": "Nichts gewachsen. 3 Flammen: Feuer.",
	"rain": "Regen! Tipp drauf, dann aufs Feld.",
	"fire": "Feuer! Gieß es mit Regen.",
	"bolt": "Blitz! Tipp drauf, dann aufs Eckfeld.",
	"monsoon": "Monsun! Tipp drauf, dann auf den Würfel.",
	"hint": "Fest? Tipp zeigt die beste Drehung.",
	"undo": "Vertan? Zurück hilft.",
	"coins": "Deine Münzen. Mehr gibt's per Video.",
	"age": "",      # Text kommt aus _coach_text (Zeitalter und was als Nächstes kommt)
	"hold": "Halte ein Symbol für Hilfe.",
	"scale": "Die Waage: links Natur, rechts Stadt.",
	"wish": "Ein Wunsch! Erfüll ihn bald.",
	"church": "Kirchen geben Glauben. Zwei geben Krieg!",
	"war": "Krieg! Halte Kirchen auseinander.",
	"finished": "Fertig! Bringt jetzt Glauben.",
	"industry": "Industrie: viel Glaube, aber Smog.",
	"smog": "Smog! Pflanz Wald oder schick Gewitter.",
	"nopeople": "Ohne Menschen kein Glaube.",
	"mini": "Tipp schnell das andere Bild.",
}
const COACH_ICON = {"miss": "fire", "rain": "rain", "bolt": "lightning", "monsoon": "monsoon", "fire": "fire", "hold": "hand",
	"hint": "bulb", "undo": "undo", "coins": "coin", "scale": "balance", "wish": "wish", "church": "church", "war": "swords",
	"finished": "star", "industry": "industry", "smog": "smog", "nopeople": "hut", "mini": "check"}
const AGE_PREP = {"Mittelalter": "im", "Industriezeitalter": "im"}
## Hinweise, die es auch an den 7 Tagen gibt (alles andere stellt der Tag selbst vor).
const DAY_COACH = ["wish", "fire", "mini", "smog", "war"]
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
	"menu": {"icon": "menu", "title": "Menü", "body": "Pause, Spiel, Ton, Hilfe."},
	"score": {"icon": "faith", "title": "Glaube", "body": "Kommt vom Wachsen und von Wünschen."},
	"scale": {"icon": "balance", "title": "Weltwaage", "body": "Links Natur, rechts Stadt. Grün ist gut."},
	"goal": {"icon": "star", "title": "Vollenden", "body": "Vollende %d fertige Felder."},
	"choice": {"icon": "wish", "title": "Dein Wille geschehe", "body": "Du wählst, was hier wächst."},
	"mini": {"icon": "check", "title": "Deine Wahl", "body": "Tipp das andere Bild zum Wechseln."},
	"strike": {"icon": "strike", "title": "Gewitter", "body": "Straft ein Feld. Kostet 15 Glauben."},
	"flood": {"icon": "flood", "title": "Flut", "body": "Wäscht eine Seite rein. 40 Glauben."},
	"always_ask": {"icon": "help", "title": "Wahl-Karte immer zeigen", "body": "An: immer die große Karte."},
	"credits": {"icon": "coin", "title": "Münzen", "body": "Für Tipp und Zurück."},
	"age": {"icon": "hut", "title": "Zeitalter", "body": "Zeigt, wie weit deine Welt ist."},
	"flames": {"icon": "fire", "title": "Flammen", "body": "Wächst nichts: Flamme. 3 Flammen: Feuer."},
	"hearts": {"icon": "heart", "title": "Herzen", "body": "Jedes Feuer kostet ein Herz."},
	"undo": {"icon": "undo", "title": "Zurück", "body": "Nimmt deinen letzten Zug zurück."},
	"rain": {"icon": "rain", "title": "Regen", "body": "Lässt Natur wachsen. Löscht Feuer."},
	"bolt": {"icon": "lightning", "title": "Blitz", "body": "Die Schräge an der Ecke wächst."},
	"monsoon": {"icon": "monsoon", "title": "Monsun", "body": "Monsun: Eine ganze Seite wächst."},
	"hint": {"icon": "bulb", "title": "Tipp", "body": "Zeigt dir die beste Drehung."},
	"profile": {"icon": "profile", "title": "Profil", "body": "Kommt bald."},
	"mode_close": {"icon": "close", "title": "Abbrechen", "body": "Werkzeug weglegen."},
	"mode_einfach": {"icon": "meadow", "title": "Einfach", "body": "Ganze Gruppen wachsen mit. 5 Herzen."},
	"mode_mittel": {"icon": "smallforest", "title": "Mittel", "body": "Schräg zählt ab Wald. 3 Herzen."},
	"mode_schwer": {"icon": "nature", "title": "Schwer", "body": "Nur gerade Reihen zählen. 3 Herzen."},
	"mode_challenge": {"icon": "trophy", "title": "40 Drehungen", "body": "Wie viel Glaube in 40 Drehungen?"},
}
var _lp_node: Control = null
var _lp_t := 0.0
var _lp_pos := Vector2.ZERO
var _lp_fired := false
var _lp_swallow: Control = null
var _tip_hide_at := INF
var _queued_tap := -1          # Bonus-Feld, angetippt während einer Animation: wird danach eingesetzt
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

const SLOT_TINT = {"undo": Color("#F2EDE5"), "rain": Color("#E3EFFC"), "bolt": Color("#FDF0DA"), "monsoon": Color("#E7EBFA"), "hint": Color("#FDF0DA"),
	"strike": Color("#EEE7FA"), "flood": Color("#DDEBFA")}
const SLOT_COLOR = {"undo": Color("#4B5163"), "rain": Color("#3B8EEA"), "bolt": Color("#F2A93B"), "monsoon": Color("#5B74D6"), "hint": Color("#F2A93B"),
	"strike": Color("#7E57C9"), "flood": Color("#2366B8")}
const PUNISH_TINT := Color("#EEE7FA")
const PUNISH := Color("#7E57C9")
const PUNISH_DEEP := Color("#5B3AA0")
const MODES = [
	{"key": "einfach", "icon": "meadow", "title": "Einfach", "sub": "Ganze Gruppen wachsen mit", "tint": 1},
	{"key": "mittel", "icon": "smallforest", "title": "Mittel", "sub": "Auch schräge Reihen zählen", "tint": 2},
	{"key": "schwer", "icon": "nature", "title": "Schwer", "sub": "Nur gerade Reihen", "tint": 4},
	{"key": "challenge", "icon": "trophy", "title": "40 Drehungen · Mittel", "sub": "Wie viel Glauben schaffst du?", "tint": 3},
]


func setup(w: World) -> void:
	world = w
	layer = 2
	notifier = Notifier.attach(Game)
	notifier.permission_changed.connect(_on_permission_changed)
	_build()
	day_ui = DayUI.new()
	add_child(day_ui)
	day_ui.build(self)
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
	world.war_shown.connect(_on_war)
	world.smog_shown.connect(_on_smog)
	world.wish_done_shown.connect(_on_wish_done)
	world.wish_made_shown.connect(_on_wish_made)
	world.income_shown.connect(_on_income)
	world.punish_shown.connect(_on_punish)
	world.still_shown.connect(_on_still)
	world.cancel_zone = cancel_strip
	Game.choice_needed.connect(_on_choice_needed)
	Game.choice_made.connect(_on_choice_made)
	Game.state_changed.connect(refresh)
	Game.new_game_started.connect(_on_new_game)
	Game.message.connect(_on_message)
	Game.game_over.connect(_on_game_over)
	Game.move_done.connect(_on_move_done)
	Game.tutorial_changed.connect(_tutorial_show)
	refresh()
	_tutorial_show()
	_hud_entrance.call_deferred()
	day_ui.startup()


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
	bubble_layer = _layer()        # Feld-Blasen liegen unter der Jubel-Pille (sie verdecken sie nicht)
	_build_banner()
	_build_context()
	_build_dock()
	gift_layer = _layer()
	_anchor = Control.new()
	_anchor.size = Vector2(44, 44)
	_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gift_layer.add_child(_anchor)
	_build_choice()
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


## Tag 1 „Schau zu!“: Würfel und Oberfläche kurz sperren (eine unsichtbare Fläche über allem fängt jedes Tippen).
## Wird immer wieder freigegeben (day_ui: nach der Vorführung, Übersicht, neues Spiel, Sieg, Niederlage).
var input_block: Control = null


func set_input_locked(on: bool) -> void:
	if world != null:
		world.input_locked = on
		if on:
			world._touches.clear()
	if on and input_block == null:
		input_block = Control.new()
		input_block.name = "InputBlock"
		input_block.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		input_block.mouse_filter = Control.MOUSE_FILTER_STOP
		input_block.gui_input.connect(_on_block_input)
		root.add_child(input_block)
	if input_block != null:
		input_block.visible = on
		if on:
			root.move_child(input_block, root.get_child_count() - 1)


func input_locked() -> bool:
	return world != null and world.input_locked


## Ein Tippen/Wischen während der Sperre: zählt nicht, aber die „Schau zu!“-Zeile antwortet sichtbar.
func _on_block_input(ev: InputEvent) -> void:
	var press := false
	if ev is InputEventMouseButton:
		press = (ev as InputEventMouseButton).pressed
	elif ev is InputEventScreenTouch:
		press = (ev as InputEventScreenTouch).pressed
	if press and day_ui != null:
		day_ui.blocked_tap()


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
	var sh := _hbox(6)
	sh.alignment = BoxContainer.ALIGNMENT_CENTER
	score_box.add_child(sh)
	faith_icon = _icon("faith", 40)
	sh.add_child(faith_icon)
	score_label = _label("0", Style.F_SCORE, Style.INK, Style.W_BLACK)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sh.add_child(score_label)
	var pad := Control.new()          # gleicht das Symbol aus, damit die Zahl mittig bleibt
	pad.custom_minimum_size = Vector2(20, 0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.add_child(pad)
	round_label = _caps("Glaube")
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
	for i in maxi(Balance.LIVES_EASY, Balance.LIVES):
		var h := _icon("heart", 24)
		h.set_meta("idx", i)
		hearts_row.add_child(h)
		hearts.append(h)
	_explain_only(hearts_chip, "hearts")

	# Zeile 3: Weltwaage (ab dem ersten Acker oder der ersten Hütte) · Ziel (ab dem ersten fertigen Feld)
	row3 = _hbox(8)
	row3.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(row3)
	scale_chip = PanelContainer.new()
	_scale_sb = _chip_style()
	_scale_sb.content_margin_top = 5
	_scale_sb.content_margin_bottom = 5
	scale_chip.add_theme_stylebox_override("panel", _scale_sb)
	row3.add_child(scale_chip)
	var sch := _hbox(8)
	scale_chip.add_child(sch)
	sch.add_child(_icon("nature", 24))
	scale_bar = WorldScale.new()
	sch.add_child(scale_bar)
	sch.add_child(_icon("bigcity", 24))
	_explain_only(scale_chip, "scale")
	scale_chip.visible = false
	goal_chip = PanelContainer.new()
	var gsb := _chip_style()
	gsb.content_margin_top = 5
	gsb.content_margin_bottom = 5
	goal_chip.add_theme_stylebox_override("panel", gsb)
	_goal_sb = gsb
	row3.add_child(goal_chip)
	var gh := _hbox(6)
	goal_chip.add_child(gh)
	goal_icon = _icon("star", 22)
	gh.add_child(goal_icon)
	goal_label = _label("0/22", 15, Style.INK, Style.W_BOLD)
	goal_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gh.add_child(goal_label)
	_explain_only(goal_chip, "goal")
	goal_chip.visible = false


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
	lh.add_child(_arrow_right(20))
	sheet_next = _icon("smallforest", 34)
	lh.add_child(sheet_next)
	sheet_or = _label("oder", 14, Style.INK_3, Style.W_BOLD)
	sheet_or.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lh.add_child(sheet_or)
	sheet_next2 = _icon("field", 34)
	lh.add_child(sheet_next2)
	sheet_rule = _label("  3 in einer Reihe", 15, Style.INK_2, Style.W_LABEL)
	sheet_rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lh.add_child(sheet_rule)
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
	strike_btn = _slot(bh, "strike", "strike", "Gewitter", _on_bonus_pressed.bind("strike"))
	flood_btn = _slot(bh, "flood", "flood", "Flut", _on_bonus_pressed.bind("flood"))
	hint_btn = _slot(bh, "hint", "bulb", "Tipp", _on_hint_pressed)


func _dock_btns() -> Array:
	return [undo_btn, rain_btn, bolt_btn, monsoon_btn, strike_btn, flood_btn, hint_btn]


## Das Dock ist eine Pille, so breit wie seine sichtbaren Plätze, immer mittig über dem unteren Rand.
func _home_dock(animate: bool = false) -> void:
	var n := 0
	for b in _dock_btns():
		var bb: Button = b
		if bb != null and (bb.get_meta("slot") as Control).visible:
			n += 1
	# Viele Plätze (bis zu 7): etwas kleinere Knöpfe, damit alles in eine Zeile passt
	var slot_w := SLOT_W if n <= 5 else (84.0 if n == 6 else 76.0)
	var bsz := 64.0 if n <= 5 else (60.0 if n == 6 else 56.0)
	for b in _dock_btns():
		var bb: Button = b
		if bb != null:
			bb.custom_minimum_size = Vector2(bsz, bsz)
			bb.add_theme_constant_override("icon_max_width", int(bsz * 0.53))
	var w := minf(float(maxi(n, 1)) * slot_w + 16.0, float(Style.CONTENT_W))
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
	coach_speaker = _speaker(52, 24)
	ch.add_child(coach_speaker)
	coach_tile = coach_speaker.get_meta("badge")
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


## „So geht's“: wenige Zeilen, je ein Bild und ein Satz. Neues erscheint erst, wenn man es kennt.
func _build_help() -> void:
	help_card = _modal_card("So geht's", true)
	var inner := _modal_scroll(help_card, 150.0)
	# An den Tagen zuerst: die Aufgabe, die Drehungen und die Sterne
	_help_rows["task"] = _help_row("goal", Style.SUN_TINT, "Deine Aufgabe", "Weniger Drehungen, mehr Sterne.")
	inner.add_child(_help_rows["task"])
	inner.add_child(_help_row("round", Style.SURFACE_2, "Drehen", "Wisch über eine Reihe."))
	inner.add_child(_help_row("up", Style.LEAF_TINT, "Wachsen", "Bring 3 gleiche in eine Reihe."))
	# Was wächst woraus (an den Tagen: nur, was heute schon wachsen kann), als Bildreihe
	var tree := _help_row("up", Style.LEAF_TINT, "Was wächst woraus", "Daraus wird das Nächste:")
	inner.add_child(tree)
	_help_rows["tree"] = tree
	_help_tree = HFlowContainer.new()
	_help_tree.add_theme_constant_override("h_separation", 6)
	_help_tree.add_theme_constant_override("v_separation", 6)
	_help_tree.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_tree.custom_minimum_size = Vector2(Style.CONTENT_W - 56 - 44 - 14 - 8, 0)
	(tree.get_child(1) as Control).add_child(_help_tree)
	# Die Wahl als Bild: Wiese → Wald oder Acker
	var will := _help_row("hand", Style.SUN_TINT, "Dein Wille geschehe", "Hier wählst du, was wächst.")
	inner.add_child(will)
	_help_rows["will"] = will
	var pic := _hbox(6)
	(will.get_child(1) as Control).add_child(pic)
	pic.add_child(_icon("meadow", 26))
	pic.add_child(_arrow_right(16))
	pic.add_child(_icon("smallforest", 26))
	var orl := _label("oder", 14, Style.INK_3, Style.W_BOLD)
	orl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.add_child(orl)
	pic.add_child(_icon(_kind_icon(FieldData.FIELD), 26))
	_help_rows["faith"] = _help_row("faith", Style.SUN_TINT, "Glaube", "Kommt vom Wachsen und von Wünschen.")
	inner.add_child(_help_rows["faith"])
	_help_rows["scale"] = _help_row("balance", Style.LEAF_TINT, "Weltwaage", "Links Natur, rechts Stadt. Grün ist gut.")
	_help_rows["wish"] = _help_row("wish", Style.SUN_TINT, "Wünsche", "Erfüll Wünsche in %d Drehungen." % Balance.WISH_TWISTS)
	_help_rows["war"] = _help_row("swords", Style.FIRE_TINT, "Krieg", "Treffen sich zwei Kirchen: Krieg.")
	_help_rows["smog"] = _help_row("smog", Style.FIRE_TINT, "Smog", "Zu viel Industrie: Natur welkt.")
	_help_rows["goal"] = _help_row("star", Style.SUN_TINT, "Vollenden", "Fertige Felder bringen Glauben.")
	for key in ["scale", "wish", "war", "smog", "goal"]:
		inner.add_child(_help_rows[key])
	_help_goal = ((_help_rows["goal"] as Control).get_child(1) as Control).get_child(1) as Label
	_help_rows["fire"] = _help_row("fire", Style.FIRE_TINT, "Flammen & Herzen", "3 Flammen: Feuer. Kostet ein Herz.")
	inner.add_child(_help_rows["fire"])
	_help_rows["rain"] = _help_row("rain", Style.WATER_TINT, "Regen", "Natur wächst. Feuer geht aus.")
	inner.add_child(_help_rows["rain"])
	_help_rows["bolt"] = _help_row("lightning", Style.SUN_TINT, "Blitz", "3 gleiche an einer Ecke. Dann wächst die schräge Linie dort.")
	_help_rows["monsoon"] = _help_row("monsoon", Style.MONSOON_TINT, "Monsun", "Eine ganze Seite wächst.")
	_help_rows["strike"] = _help_row("strike", PUNISH_TINT, "Gewitter", "Straft ein Feld. Kostet %d Glauben." % Balance.STRIKE_COST)
	_help_rows["flood"] = _help_row("flood", Style.WATER_TINT, "Flut", "Wäscht eine Seite rein. %d Glauben." % Balance.FLOOD_COST)
	for key in ["bolt", "monsoon", "strike", "flood"]:
		inner.add_child(_help_rows[key])
	inner.add_child(_help_row("hand", Style.SUN_TINT, "Erklärungen", "Halte ein Symbol gedrückt."))
	var v: VBoxContainer = help_card.get_meta("body")
	var go := _button("Alles klar", "primary")
	go.pressed.connect(_on_help_done)
	v.add_child(go)


## Die Bildreihe „Was wächst woraus“: Erde → Wiese → Wald → … so weit, wie es an diesem Tag geht.
func _fill_help_tree(gs: GameState) -> void:
	for c in _help_tree.get_children():
		c.queue_free()
	var unlocked: Array = gs.day.get("unlocked", [])
	var k := FieldData.EMPTY
	var first := true
	while k >= 0 and (unlocked.is_empty() or unlocked.has(k)):
		if not first:
			_help_tree.add_child(_arrow_right(14))
		first = false
		var ic := _icon(_kind_icon(k), 26)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_help_tree.add_child(ic)
		k = int(FieldData.NEXT[k])


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
	_menu_cont = cont
	# Die 7 Tage: zur Übersicht
	var days := _vbox(8)
	inner.add_child(days)
	days.add_child(_caps(str(Days.TEXT["title"])))
	_menu_days = _mode_row({"key": "tage", "icon": "days", "title": "Tage", "sub": "Alle Tage und deine Sterne", "tint": 1}, false)
	days.add_child(_menu_days)
	# Freies Spiel: drei Stufen und die Challenge, je mit Rekord (offen nach Tag 7)
	var play := _vbox(8)
	inner.add_child(play)
	_menu_free_caps = _caps(str(Days.TEXT["free"]))
	play.add_child(_menu_free_caps)
	for m in MODES:
		var md: Dictionary = m
		play.add_child(_mode_row(md))
	# Der eigene Charakter und seine Erinnerungen
	_build_menu_character(inner)
	_build_menu_reminder(inner)
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
	var line2 := ColorRect.new()
	line2.color = Style.HAIRLINE
	line2.custom_minimum_size = Vector2(0, 1)
	line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gv.add_child(line2)
	_ask_switch = _switch(Game.always_ask, _on_ask_toggled)
	var ask_row := _toggle_row("help", "Wahl-Karte immer zeigen", _ask_switch)
	_make_holdable(ask_row, "always_ask")
	gv.add_child(ask_row)
	_ask_rows = [line2, ask_row]      # erst, wenn man schon eine Wahl-Karte gesehen hat
	# Kacheln: Profil (bald), Hilfe, Tutorial
	var tiles := _hbox(8)
	inner.add_child(tiles)
	_profile_btn = _menu_tile("Profil", "profile", _on_profile)
	tiles.add_child(_profile_btn)
	_profile_btn.visible = false      # Profile gibt es noch nicht
	tiles.add_child(_menu_tile("Hilfe", "help", _show_help))
	tiles.add_child(_menu_tile("Tutorial", "round", _restart_tutorial))
	if OS.is_debug_build():
		_build_menu_test(inner)


## Menü „Dein Charakter“: Kopfbild, Name, Ton (lieb · frech · streng) und „Ändern“ (der Ersteller).
func _build_menu_character(inner: VBoxContainer) -> void:
	var box := _vbox(8)
	inner.add_child(box)
	box.add_child(_caps("Dein Charakter"))
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 76)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Style.skin(b, Style.box(Style.SURFACE_2, Style.R_ROW, 14, 10), Style.box(Style.SURFACE_3, Style.R_ROW, 14, 10), Style.INK)
	b.pressed.connect(_on_edit_character)
	_press_fx(b)
	box.add_child(b)
	var h := _hbox(14)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -18
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	_menu_char = _speaker(56, 0, Style.SURFACE)
	h.add_child(_menu_char)
	var tv := _vbox(0)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	_menu_char_name = _label("", 17, Style.INK, Style.W_BOLD)
	tv.add_child(_menu_char_name)
	_menu_char_sub = _label("Aussehen, Name und Art zu reden", 14, Style.INK_3, Style.W_BODY)
	tv.add_child(_menu_char_sub)
	var ch := _label("Ändern", 15, Style.SUN_DEEP, Style.W_BOLD)
	ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ch)
	_tone_seg = _segmented([["lieb", "Lieb"], ["frech", "Frech"], ["streng", "Streng"]], _on_tone_picked)
	box.add_child(_tone_seg)


## Menü „Erinnerung“ (5.7): Automatisch · Feste Uhrzeit · Aus, Uhrzeit, Hinweise zur Erlaubnis.
func _build_menu_reminder(inner: VBoxContainer) -> void:
	var box := _vbox(8)
	inner.add_child(box)
	_remind_box = box
	box.add_child(_caps("Erinnerung"))
	_remind_seg = _segmented([["auto", "Automatisch"], ["fest", "Feste Uhrzeit"], ["aus", "Aus"]], _on_remind_mode)
	box.add_child(_remind_seg)
	_remind_sub = _label("", 15, Style.INK_2, Style.W_BODY)
	_remind_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_remind_sub.custom_minimum_size = Vector2(Style.CONTENT_W - 56 - 24, 0)
	box.add_child(_remind_sub)
	_remind_time_row = _hbox(14)
	_remind_time_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_remind_time_row)
	var minus := _button("−", "secondary", "", 48)
	minus.custom_minimum_size = Vector2(64, 48)
	minus.add_theme_font_size_override("font_size", 24)
	minus.pressed.connect(_on_remind_step.bind(-15))
	_remind_time_row.add_child(minus)
	_remind_time = _label("18:00", 26, Style.INK, Style.W_BLACK)
	_remind_time.custom_minimum_size = Vector2(96, 0)
	_remind_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_remind_time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_remind_time_row.add_child(_remind_time)
	var plus := _button("+", "secondary", "", 48)
	plus.custom_minimum_size = Vector2(64, 48)
	plus.add_theme_font_size_override("font_size", 24)
	plus.pressed.connect(_on_remind_step.bind(15))
	_remind_time_row.add_child(plus)
	var foot := _label("Max. 1 am Tag. Nie nachts.", 13, Style.INK_3, Style.W_LABEL)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.custom_minimum_size = Vector2(Style.CONTENT_W - 56 - 24, 0)
	box.add_child(foot)
	_remind_note = _label("", 15, Style.FIRE_DEEP, Style.W_BOLD)
	_remind_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_remind_note.custom_minimum_size = Vector2(Style.CONTENT_W - 56 - 24, 0)
	box.add_child(_remind_note)
	_remind_settings = _button("Einstellungen öffnen", "secondary", "", 48)
	_remind_settings.pressed.connect(_on_remind_settings)
	box.add_child(_remind_settings)


## Nur in der Test-Version (7): einen Tag weiter, Erinnerung in 10 s, Serie zurücksetzen.
func _build_menu_test(inner: VBoxContainer) -> void:
	var box := _vbox(8)
	inner.add_child(box)
	_test_box = box
	box.add_child(_caps("Test", Style.MONSOON_DEEP))
	var row := _hbox(8)
	box.add_child(row)
	row.add_child(_menu_tile("Nächster Tag", "moon", _on_test_next_day))
	row.add_child(_menu_tile("Erinnerung in 10 s", "info", _on_test_remind))
	box.add_child(_menu_tile("Serie zurücksetzen", "streak_off", _on_test_reset))


## Segmentierte Auswahl: [[key, Text], …]. cb(key). Meta "keys", Knöpfe als Kinder (Meta "key").
func _segmented(opts: Array, cb: Callable) -> HBoxContainer:
	var h := _hbox(6)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for o_v in opts:
		var o: Array = o_v
		var b := Button.new()
		b.text = str(o[1])
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_override("font", Style.font_w(Style.W_BOLD))
		b.add_theme_font_size_override("font_size", 15)
		b.set_meta("key", str(o[0]))
		b.pressed.connect(cb.bind(str(o[0])))
		_press_fx(b)
		h.add_child(b)
	return h


func _sync_segmented(seg: HBoxContainer, key: String) -> void:
	for c in seg.get_children():
		var b: Button = c
		var on := str(b.get_meta("key", "")) == key
		var n := Style.box(Style.INK if on else Style.SURFACE_2, 24, 10, 0)
		var p := Style.box(Style.INK_PRESSED if on else Style.SURFACE_3, 24, 10, 0)
		Style.skin(b, n, p, Color.WHITE if on else Style.INK_2)


func segment_button(seg: HBoxContainer, key: String) -> Button:
	for c in seg.get_children():
		if str((c as Button).get_meta("key", "")) == key:
			return c as Button
	return null


func _refresh_menu_daily() -> void:
	if _menu_char == null:
		return
	speaker_view(_menu_char).set_look(char_look())
	_menu_char_name.text = Voice.char_name()
	_menu_char_sub.text = "%s · %s" % [str((Character.BASES.get(str(char_look().get("basis", "bart")), {}) as Dictionary).get("title", "")),
		str(Character.TONE_TITLE.get(Voice.tone(), "Lieb"))]
	_sync_segmented(_tone_seg, Voice.tone())
	var mode := str(Game.remind.get("mode", "auto"))
	_sync_segmented(_remind_seg, mode)
	var fixed := int(Game.remind.get("fixed_min", 1080))
	_remind_time.text = "%d:%02d" % [fixed / 60, fixed % 60]
	_remind_time_row.visible = mode == "fest"
	match mode:
		"auto":
			_remind_sub.text = "Wenn du sonst spielst."
		"fest":
			_remind_sub.text = "Täglich um diese Uhrzeit."
		_:
			_remind_sub.text = "Keine Erinnerungen."
	var supported := Notifier.is_supported()
	var usable := supported or OS.is_debug_build()       # Test-Version am PC: einstellbar, plant nur Protokoll-Zeilen
	_remind_seg.modulate.a = 1.0 if usable else 0.5
	for c in _remind_seg.get_children():
		(c as Button).disabled = not usable
	_remind_settings.visible = false
	if not supported:
		_remind_note.text = "Erinnerungen gibt es nur auf dem Handy."
		_remind_note.add_theme_color_override("font_color", Style.INK_3)
		_remind_note.visible = true
	elif mode != "aus" and not notifier.notifications_enabled():
		_remind_note.text = "Benachrichtigungen sind aus."
		_remind_note.add_theme_color_override("font_color", Style.FIRE_DEEP)
		_remind_note.visible = true
		_remind_settings.visible = true
	else:
		_remind_note.visible = false


func _on_edit_character() -> void:
	day_ui.open_creator(true)


func _on_tone_picked(ton: String) -> void:
	var lk := char_look().duplicate(true)
	lk["ton"] = ton
	Game.set_character(lk)
	refresh_speakers()
	_refresh_menu_daily()
	var cv := speaker_view(_menu_char)
	var faces := {"lieb": "happy", "frech": "cheeky", "streng": "neutral"}
	cv.set_expression(str(faces.get(ton, "happy")), 2.0)
	cv.react("nod" if ton == "streng" else "hop")
	_show_tooltip(_menu_char, "info", Voice.char_name(), str(Character.TONE_SAMPLE.get(ton, "")))
	_tip_hide_at = _time + 2.6


func _on_remind_mode(mode: String) -> void:
	Game.set_reminder_mode(mode)
	if mode != "aus" and Notifier.is_supported() and not notifier.notifications_enabled():
		notifier.request_permission()
	_refresh_menu_daily()


func _on_remind_step(delta_min: int) -> void:
	var m := clampi(int(Game.remind.get("fixed_min", 1080)) + delta_min, Balance.REMIND_EARLIEST, Balance.REMIND_LATEST)
	Game.set_reminder_mode("fest", m)
	_refresh_menu_daily()


func _on_remind_settings() -> void:
	notifier.open_settings()


func _on_permission_changed(_granted: bool) -> void:
	if menu_card != null and menu_card.visible:
		_refresh_menu_daily()


func _on_test_next_day() -> void:
	var msg := Game.debug_next_day()
	_close_modal(true)
	day_ui.show_overview()
	if msg != "":
		Game.message.emit(msg, "info")


func _on_test_remind() -> void:
	var e := Game.debug_reminder_soon()
	notifier.schedule_entry(e)
	Game.message.emit("Erinnerung kommt in 10 Sekunden.", "info")


func _on_test_reset() -> void:
	Game.debug_reset_streak()
	if day_ui.is_open():
		day_ui._fill_overview()
	Game.message.emit("Serie zurückgesetzt.", "info")


func _mode_row(md: Dictionary, register: bool = true) -> Button:
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
	if register:
		_menu_rows[key] = {"btn": b, "caps": rc, "num": num}
	else:
		b.set_meta("free_row", {"caps": rc, "num": num})
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
	var l := _label("Dein Spiel endet. Glaube zählt.", 17, Style.INK_2, Style.W_BODY)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(Style.CONTENT_W - 56, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var acts := _vbox(12)
	v.add_child(acts)
	var yes := _button("Ja, neues Spiel", "primary")
	yes.pressed.connect(_on_confirm_new)
	acts.add_child(yes)
	_confirm_yes = yes
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
	var pc := _caps("Glaube")
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
	var home := _button("Alle Tage", "ghost")
	home.pressed.connect(_on_over_home)
	acts.add_child(home)


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


## Pfeil nach rechts (Container setzen die Drehung ihrer Kinder zurück, darum in einer Hülle).
func _arrow_right(px: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(px, px)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE      # vor der Größe setzen, sonst bleibt die Bildgröße
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture = Style.icon("arrow_up")
	t.size = Vector2(px, px)
	t.pivot_offset = Vector2(px, px) * 0.5
	t.rotation = PI * 0.5
	t.modulate = Color(1, 1, 1, 0.45)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(t)
	return holder


func _set_tile(p: PanelContainer, icon_name: String, tint: Color) -> void:
	var ic: TextureRect = p.get_child(0)
	ic.texture = Style.icon(icon_name)
	var s: StyleBoxFlat = p.get_theme_stylebox("panel")
	s.bg_color = tint


# --- Der eigene Charakter als Sprecher (Sprechblasen, Spur, Karten; GDPD_TAEGLICH_CHARAKTER.md 3.10) -------------

var _speakers: Array = []          # alle Kopfbilder (bekommen ein neues Aussehen, wenn sich der Charakter ändert)


## Aussehen des Charakters für die Anzeige (ohne eigenen: der Bart-Gott, bis der Ersteller fertig ist).
func char_look() -> Dictionary:
	return Game.character if not Game.character.is_empty() else Character.default_look("bart")


## Rundes Kopfbild des Charakters (px) mit einem kleinen Themen-Abzeichen unten rechts (badge_px, 0 = keins).
## Nimmt nie Berührungen an. Meta: "cv" (CharacterView), "badge" (Kachel oder null).
func _speaker(px: int, badge_px: int = 0, bg: Color = Style.SUN_TINT) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(px, px)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cv := CharacterView.make(char_look(), float(px), true, "neutral")
	cv.portrait_round = true
	cv.portrait_bg = bg
	cv.portrait_zoom = 0.86
	cv.bob_px = 2.0
	holder.add_child(cv)
	holder.set_meta("cv", cv)
	if badge_px > 0:
		var b := _tile("info", badge_px, Style.SURFACE, 0.5)
		var sb: StyleBoxFlat = b.get_theme_stylebox("panel")
		sb.set_border_width_all(2)
		sb.border_color = Style.SURFACE
		b.position = Vector2(px - badge_px * 0.78, px - badge_px * 0.78)
		b.size = Vector2(badge_px, badge_px)
		holder.add_child(b)
		holder.set_meta("badge", b)
	_speakers.append(holder)
	return holder


## Ganzer Charakter (nicht nur der Kopf), z. B. auf den Karten und in der Übersicht.
func _figure(px: int) -> CharacterView:
	var cv := CharacterView.make(char_look(), float(px), false, "neutral")
	cv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_speakers.append(cv)
	return cv


func speaker_view(sp: Control) -> CharacterView:
	if sp is CharacterView:
		return sp as CharacterView
	return sp.get_meta("cv") as CharacterView


## Der Charakter spricht: Gesicht, Abzeichen (icon_name "" = keins), Mund bewegt sich, kleiner Hüpfer.
func _speak(sp: Control, expr: String, icon_name: String = "", tint: Color = Style.SURFACE, hop: bool = true) -> void:
	var cv := speaker_view(sp)
	cv.set_expression(expr, 3.5 if expr != "neutral" else 0.0)
	cv.talking(true)
	if hop:
		cv.react("shake" if expr == "worried" else "hop")
	if not (sp is CharacterView):
		var b: Variant = sp.get_meta("badge") if sp.has_meta("badge") else null
		if b is PanelContainer:
			(b as PanelContainer).visible = icon_name != "" and Style.icon(icon_name) != null
			if (b as PanelContainer).visible:
				_set_tile(b as PanelContainer, icon_name, tint if tint != Style.SURFACE else _tint_for_icon(icon_name))


## Alle sichtbaren Charaktere zeigen ein Gefühl (Wachsen: froh, Feuer: besorgt …). hold: Sekunden.
func char_react(expr: String, kind: String = "", hold: float = 1.6) -> void:
	for sp_v in _speakers:
		if not is_instance_valid(sp_v):
			continue
		var sp: Control = sp_v
		if not sp.is_visible_in_tree():
			continue
		var cv := speaker_view(sp)
		cv.set_expression(expr, hold)
		if kind != "":
			cv.react(kind)


## Der Charakter hat sich geändert (Ersteller, Menü): alle Bilder neu.
func refresh_speakers() -> void:
	var lk := char_look()
	var keep: Array = []
	for sp_v in _speakers:
		if not is_instance_valid(sp_v):
			continue
		keep.append(sp_v)
		speaker_view(sp_v as Control).set_look(lk)
	_speakers = keep


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
		var off := base + "_off"
		_set_tile(tl, base if on or Style.icon(off) == null else off, Style.SURFACE)
		(tl.get_child(0) as Control).modulate.a = 1.0 if on or Style.icon(off) != null else 0.5


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
	for b in _dock_btns():
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
		if gs.ever.has(FieldData.FIELD) or gs.ever.has(FieldData.HUT):
			_reveal("scale")
	if Game.in_day() and day_ui != null:
		_sync_day_slots(animate)
		return
	score_box.visible = true
	_chip_show(hearts_chip, true, false)
	var changed := false
	changed = _slot_show(undo_btn, not tut and _known("undo"), animate) or changed
	changed = _slot_show(rain_btn, not tut and gs.gadgets and gs.tool_unlocked("rain"), animate) or changed
	changed = _slot_show(bolt_btn, not tut and gs.gadgets and (_known("bolt") or gs.bolts > 0), animate) or changed
	changed = _slot_show(monsoon_btn, not tut and gs.gadgets and (gs.monsoon_unlocked or gs.monsoons > 0), animate) or changed
	changed = _slot_show(strike_btn, not tut and gs.gadgets and gs.tool_unlocked("strike"), animate) or changed
	changed = _slot_show(flood_btn, not tut and gs.gadgets and gs.tool_unlocked("flood"), animate) or changed
	changed = _slot_show(hint_btn, not tut and _known("hint"), animate) or changed
	if changed:
		_home_dock(animate)
	if not dock.visible and not tut and not _hud_tut and (day_ui == null or not day_ui.is_open()) and not _dock_any_hidden():
		_dock_in(0.0)
	if tut:
		_chip_show(scale_chip, false, false)
		_chip_show(goal_chip, false, false)
		return
	_chip_show(scale_chip, _known("scale"), animate)
	_chip_show(goal_chip, gs.endless and gs.tool_unlocked("strike"), animate)
	_chip_show(age_chip, true, animate)
	_chip_show(credits_btn, _known("coins"), animate)
	_chip_show(flame_chip, _known("flames"), animate)


## Ein Tag: nur, was dieser Tag kennt. Kein Glaube (bis Tag 6 zeigt der Ziel-Chip ihn), keine Münzen, keine Herzen,
## kein Zeitalter. Im Dock: Regen ab Tag 2, Gewitter an Tag 7, Tipp (gratis) – Neues fliegt erst nach „Los!“ herein.
func _sync_day_slots(animate: bool) -> void:
	var gs := Game.state
	var hold_dock := day_ui.held("dock") or day_ui.is_open()
	score_box.visible = false
	var changed := false
	changed = _slot_show(undo_btn, false, animate) or changed
	changed = _slot_show(rain_btn, gs.tool_unlocked("rain") and not day_ui.held("rain"), animate) or changed
	changed = _slot_show(bolt_btn, false, animate) or changed
	changed = _slot_show(monsoon_btn, false, animate) or changed
	changed = _slot_show(strike_btn, gs.tool_unlocked("strike") and not day_ui.held("strike"), animate) or changed
	changed = _slot_show(flood_btn, false, animate) or changed
	changed = _slot_show(hint_btn, true, animate) or changed
	if changed:
		_home_dock(animate)
	if hold_dock:
		if dock.visible:
			_hide_now(dock)
	elif not dock.visible:
		_dock_in(0.0)
	# Die Waage steuert schon ab Tag 5 die Wünsche, zu sehen ist sie erst, wenn sie Ziel ist (Tag 7): eine neue Sache je Tag
	var scale_on := bool(gs.day.get("scale_visible", gs.day.get("scale", false)))
	_chip_show(scale_chip, scale_on and not day_ui.held("scale"), animate)
	_chip_show(goal_chip, false, false)
	_chip_show(age_chip, false, false)
	_chip_show(credits_btn, false, false)
	_chip_show(hearts_chip, false, false)
	_chip_show(flame_chip, not gs.no_fire and gs.misses > 0, animate)


## Ist das Dock gerade absichtlich weg (Tag 1 am Anfang, Übersicht)?
func _dock_any_hidden() -> bool:
	return day_ui != null and (day_ui.is_open() or day_ui.held("dock"))


func _slot_show(b: Button, on: bool, animate: bool) -> bool:
	var slot: Control = b.get_meta("slot")
	if slot.visible == on:
		return false
	slot.visible = on
	if on and animate and dock.visible:
		_appear(slot, Vector2.ZERO, 0.4, 0.6, 0.1)
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
	# Kam das Loslassen nicht an (z. B. weil die App kurz den Fokus verlor), ist das Halten vorbei
	if _lp_node != null and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_lp_node = null
	if _lp_node != null and not _lp_fired:
		if not is_instance_valid(_lp_node) or not _lp_node.is_visible_in_tree():
			_lp_node = null
		else:
			_lp_t += delta
			if _lp_t >= long_press:
				_lp_fired = true
				Style.haptic(Style.HAPTIC_HOVER)
				_on_fx_up(_lp_node)
				if str(_lp_node.get_meta("explain", "")) == "mini":
					_open_full_choice()          # lange auf die kleine Pille: die große Karte
				elif not (tip_card.visible and _tip_owner == _lp_node):
					_show_tip(_lp_node)
				_tip_hide_at = INF
	if tip_card.visible and _time > _tip_hide_at:
		_hide_tip()


## Erklärung einer Art ohne den Namen vorneweg (der steht schon im Titel). in_sheet: die Feld-Karte zeigt
## „Fertig · +N Glaube pro Runde“ schon oben, dann fällt auch dieser Satz weg.
static var _re_finished: RegEx = null


func _kind_body(k: int, in_sheet: bool) -> String:
	var body := Game.state.kind_help(k) if Game.state != null else str(FieldData.KIND_HELP[clampi(k, 0, FieldData.KIND_COUNT - 1)])
	body = body.trim_prefix(FieldData.kind_name(k) + ". ")
	if in_sheet:
		if _re_finished == null:
			_re_finished = RegEx.create_from_string("^(Fertig\\.?( – wächst nicht mehr\\.)?\\s*)?(Bringt jede Runde \\d+ Glauben|\\+\\d+ Glauben)?(\\.\\s*| – )?")
		body = _re_finished.sub(body, "").strip_edges()
	if body != "":
		body = body.substr(0, 1).to_upper() + body.substr(1)
	return body


## Text für eine Erklärung. Hier können dynamische Teile (Anzahl, Rekord …) ergänzt werden.
func _tooltip_for(key: String) -> Dictionary:
	# Arten (Feld-Karte, Wahl-Karte): Name und Erklärung aus der Art-Tabelle
	if key.begins_with("kind_") or key.begins_with("choice_opt_"):
		var k := -1
		if key.begins_with("kind_"):
			k = int(key.substr(5))
		elif not _choice.is_empty():
			var opts: Array = _choice["options"]
			k = int(opts[clampi(int(key.substr(11)), 0, 1)])
		if k < 0:
			return {}
		return {"icon": _kind_icon(k), "title": FieldData.kind_name(k), "body": _kind_body(k, false)}
	if key.begins_with("wish_"):
		var w := Game.state.wish_at(int(key.substr(5))) if Game.state != null else {}
		if w.is_empty():
			return {}
		var left := int(w["left"])
		return {"icon": str(GameState.WISH_ICON.get(str(w["type"]), "wish")), "title": "Ein Wunsch",
			"body": "%s Noch %d %s." % [str(GameState.WISH_TEXT.get(str(w["type"]), "")), left, "Drehung" if left == 1 else "Drehungen"]}
	if key.begins_with("day_") and day_ui != null:
		return day_ui.tooltip(key)
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
				d["icon"] = _age_icon()
				d["title"] = "Zeitalter: %s" % gs.age_name()
				body += " " + _next_age_text()
		"hearts":
			if gs != null:
				body += " Noch %d %s." % [gs.lives, "Herz" if gs.lives == 1 else "Herzen"]
		"rain":
			if gs != null and gs.rain <= 0:
				body += " Der nächste Regen kommt in %d Drehungen." % maxi(1, gs.next_rain - gs.twists)
		"goal":
			body = body % (gs.complete_goal() if gs != null else 22)
			if gs != null:
				body += " Du hast %d." % gs.finished_count()
				if gs.endless and not gs.completed and gs.finished_count() >= gs.complete_goal():
					d["icon"] = "balance"
					body += " Jetzt Waage ins Grüne."
		"scale":
			if gs != null:
				body += " Gerade: %s." % str(GameState.ZONE_NAME.get(gs.zone(), ""))
		"strike", "flood":
			var cost := Balance.STRIKE_COST if key == "strike" else Balance.FLOOD_COST
			if gs != null and gs.faith < cost:
				body += " Du hast %d." % gs.faith
		"undo":
			body += " Kostet %d %s." % [Balance.UNDO_COST, _coin_word(Balance.UNDO_COST)]
		"hint":
			if Game.hint_free():
				body += " Heute gratis."
			else:
				body += " Kostet %d %s." % [Balance.HINT_COST, _coin_word(Balance.HINT_COST)]
		"flames":
			if Game.in_day():
				body = "Wächst nichts: Flamme. 3 Flammen: Feuer."
		"rain":
			if Game.in_day() and gs != null:
				body = "Lässt Natur wachsen. Du hast %d." % gs.rain
		"mode_close":
			var what := str({"rain": "den Regen", "bolt": "den Blitz", "monsoon": "den Monsun", "strike": "das Gewitter", "flood": "die Flut"}.get(bonus_mode, "das Werkzeug"))
			body = "Doch nicht? %s weglegen." % what
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
	if choice_card.visible and choice_card.is_ancestor_of(target):
		var cr := choice_card.get_global_rect()
		above = cr.position.y - tip_card.size.y - 12.0 >= _insets.x + 8.0
		y = cr.position.y - tip_card.size.y - 12.0 if above else cr.end.y + 12.0
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
		"coin", "bulb", "lightning", "trophy", "gift", "star", "faith", "wish":
			return Style.SUN_TINT
		"check", "up", "balance":
			return Style.LEAF_TINT
		"swords", "smog":
			return Style.FIRE_TINT
		"strike":
			return PUNISH_TINT
		"flood":
			return Style.WATER_TINT
		"paw":
			return Style.STAGE_TINT[FieldData.ANIMALS]
	var si := STAGE_ICON.find(icon_name)
	if si >= 0:
		return Style.STAGE_TINT[si]
	return Style.SURFACE_2


# =============================================================================
# Eingabe & Takt
# =============================================================================

## App verliert den Fokus (Android: kurz pausiert): ein angefangenes Halten zählt nicht, eine Erklärung verschwindet bald.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_lp_node = null
		_lp_fired = false
		if tip_card != null and tip_card.visible and _tip_hide_at == INF:
			_tip_hide_at = _time + 2.0


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
	_choice_tick(delta)
	_queued_tick()
	_toast_tick()
	_coach_tick()
	_tutorial_tick()
	_stuck_tick()
	var target := float(Game.state.faith)
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
		round_label.text = "Glaube"
	else:
		round_label.text = "Glaube · Drehung %d von %d" % [mini(gs.twists + 1, Balance.MAX_TWISTS), Balance.MAX_TWISTS]
	if _shown_score < 0:
		_score_display = gs.faith
	elif gs.faith > _shown_score:
		_number_pop(score_label)
	elif gs.faith < _shown_score:
		_number_pop(score_label, Style.FIRE_DEEP)     # Krieg oder eine Strafe hat Glauben gekostet
		_shake(faith_icon)
	_shown_score = gs.faith
	# Weltwaage und Ziel
	var w := gs.balance()
	var zone := gs.zone()
	var goal := gs.complete_goal()
	var blocked_by_scale := gs.endless and not gs.completed and gs.finished_count() >= goal
	# Am Anfang ist alles Wiese (ganz links): Das ist kein Fehler, solange es noch keine Menschen gibt
	var wild_warn := gs.ever.has(FieldData.HUT) or blocked_by_scale
	if scale_bar.wild_warn != wild_warn:
		scale_bar.wild_warn = wild_warn
		scale_bar.queue_redraw()
	scale_bar.set_w(w, _last_scale_zone == "")
	var calm_zone := zone == "ok" or (zone == "wild" and not wild_warn)
	_scale_sb.bg_color = Style.GLASS if calm_zone else (Style.SUN_TINT if zone == "city" else Style.FIRE_TINT)
	if _last_scale_zone != "" and zone != _last_scale_zone and scale_chip.visible:
		_pop(scale_chip, 1.1)
		if zone == "city":
			_on_message("Viel Stadt! Mehr Natur, bitte.", "info")
		elif zone == "wild" and wild_warn:
			_on_message("Viel Wildnis! Äcker, bitte.", "info")
		elif zone == "ok" and (_last_scale_zone == "smog" or _last_scale_zone == "city"):
			_on_message("Die Waage ist wieder im Grünen.", "good")
	_last_scale_zone = zone
	_pulse(scale_chip, zone == "smog" and not Game.over)
	# Genug fertige Felder, aber nicht vollendet: Dann bremst die Waage (das sagt der Chip statt „27/22“)
	if blocked_by_scale:
		goal_label.text = "Waage!"
		goal_icon.texture = Style.icon("balance")
		_goal_sb.bg_color = Style.FIRE_TINT
	else:
		goal_label.text = "%d/%d" % [mini(gs.finished_count(), goal), goal]
		goal_icon.texture = Style.icon("star")
		_goal_sb.bg_color = Style.GLASS
	# Zeitalter
	var age := gs.age_name()
	if _last_age != "" and age != _last_age and not Game.tutorial() and not Game.over and not Game.in_day():
		_show_banner("age", "Deine Welt wächst", age + "!", _age_icon())
		_pop(age_chip, 1.15)
		Style.haptic(Style.HAPTIC_COMBO)
		_coach_once("age", age_chip)
	_last_age = age
	stage_label.text = age
	stage_icon.texture = Style.icon(_age_icon())
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
			_rain_mode_text()
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
	for i in hearts.size():
		(hearts[i] as Control).visible = i < maxi(gs.max_lives, 1)
	_set_cost_badge(strike_btn, Balance.STRIKE_COST, gs.faith >= Balance.STRIKE_COST)
	_set_cost_badge(flood_btn, Balance.FLOOD_COST, gs.faith >= Balance.FLOOD_COST)
	_update_buttons()
	if day_ui != null:
		day_ui.refresh_hud()
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
	return Game.busy or Game.over or world.animating or Game.tutorial() or (day_ui != null and day_ui.blocking())


func _slot_btn(kind: String) -> Button:
	match kind:
		"rain":
			return rain_btn
		"bolt":
			return bolt_btn
		"monsoon":
			return monsoon_btn
		"strike":
			return strike_btn
		"flood":
			return flood_btn
		"hint":
			return hint_btn
	return undo_btn


func _on_bonus_pressed(kind: String) -> void:
	if _blocked():
		_shake(_slot_btn(kind))
		return
	var gs := Game.state
	if kind == "strike" or kind == "flood":
		# Strafen kosten Glauben (keine Münzen): Reicht er nicht, sagt eine Meldung, wie viel man braucht
		var cost := Balance.STRIKE_COST if kind == "strike" else Balance.FLOOD_COST
		if gs.faith < cost and bonus_mode != kind:
			_shake(_slot_btn(kind))
			_on_message("Dafür brauchst du %d Glauben." % cost, "info")
			return
		_set_bonus_mode("" if bonus_mode == kind else kind)
		return
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
		var left := maxi(1, gs.next_rain - gs.twists)
		when = "Der nächste Regen kommt in %d %s. " % [left, "Drehung" if left == 1 else "Drehungen"]
	elif kind == "bolt":
		when = "Blitz: 3 gleiche an einer Ecke. "
	else:
		when = "Monsun kommt mit mehr Glauben. "
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
	_pick = -1
	world.set_pick([])
	world.tool_mode = kind != ""
	if kind == "":
		_queued_tap = -1
	for pair in [[rain_btn, "rain"], [bolt_btn, "bolt"], [monsoon_btn, "monsoon"], [strike_btn, "strike"], [flood_btn, "flood"]]:
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
		_rain_mode_text()
		_focus_targets()
	elif kind == "bolt":
		_set_tile(mode_tile, "lightning", Style.SUN_TINT)
		mode_label.text = "Tippe auf ein leuchtendes Eckfeld."
		mode_hint.text = "Die schräge Linie von dort wächst."
	elif kind == "monsoon":
		_set_tile(mode_tile, "monsoon", Style.MONSOON_TINT)
		mode_label.text = "Tippe auf eine Seite des Würfels."
		mode_hint.text = "Alle 9 Felder dort wachsen."
	elif kind == "strike":
		_set_tile(mode_tile, "strike", PUNISH_TINT)
		mode_label.text = "Tipp ein Feld zum Strafen."
		mode_hint.text = "Industrie wird Erde. %d Glauben." % Balance.STRIKE_COST
	elif kind == "flood":
		_set_tile(mode_tile, "flood", Style.WATER_TINT)
		mode_label.text = "Tippe auf eine Seite mit Stadt."
		mode_hint.text = "Stadt schrumpft. %d Glauben." % Balance.FLOOD_COST
	if was == "" or not mode_card.visible:
		_place_context(mode_card)
		_appear(mode_card, Vector2(0, 20), Style.DUR_IN, 0.98)
	else:
		_place_context(mode_card)


## Regen: sagen, welche Felder gerade gehen (nur die niedrigste Stufe wächst, Feuer wird gelöscht).
func _rain_mode_text() -> void:
	mode_label.text = "Tippe auf ein blau leuchtendes Feld."
	mode_hint.text = "Lässt wachsen. Löscht Feuer."


## Leuchtet auf der sichtbaren Seite kein Ziel, dreht sich die Ansicht zur Seite mit den meisten.
func _focus_targets() -> void:
	var gs := Game.state
	if gs == null:
		return
	var tg := gs.rain_targets()
	if tg.is_empty():
		return
	var per_face := {}
	for fid in tg:
		if bool(world.field_screen(int(fid))["visible"]):
			return
		var fn: Vector3i = (gs.fields[int(fid)] as FieldData).n
		per_face[fn] = int(per_face.get(fn, 0)) + 1
	var best := Vector3i.ZERO
	var best_c := 0
	for nk in per_face:
		if int(per_face[nk]) > best_c:
			best_c = int(per_face[nk])
			best = nk
	if best != Vector3i.ZERO:
		world.focus_place(best)


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
	if Game.in_day():
		_day_hint()
		return
	if Game.state.best_move().is_empty():
		# Keine Drehung bringt etwas: statt eines Tipps gibt es einen Regen
		_pay(0 if Game.hint_free() else Balance.HINT_COST, "Ein Tipp", _hint_gives_rain)
		return
	_pay(0 if Game.hint_free() else Balance.HINT_COST, "Ein Tipp", _use_hint)


## Tipp an einem Tag (gratis): die beste Aktion für das Ziel. Eine Drehung leuchtet; hilft Regen oder Gewitter
## mehr, ist das Werkzeug gleich gewählt.
func _day_hint() -> void:
	var act := Game.state.best_action()
	var t := str(act.get("type", ""))
	if t == "twist":
		_hint_live = true
		var best := world.show_hint(act)
		_on_message("Erst diese Reihe, dann passt's." if int(best.get("steps", 1)) == 2 else "Dreh die leuchtende Reihe!", "info")
		return
	if (t == "rain" and Game.state.rain > 0) or t == "strike":
		_set_bonus_mode(t)
		if act.has("field"):
			world.nudge(int(act["field"]))
		_on_message("Gieß ein leuchtendes Feld!" if t == "rain" else "Strafe eine Fabrik mit Gewitter!", "info")
		return
	var mv := Game.state.best_move()
	if not mv.is_empty():
		_hint_live = true
		world.show_hint(mv)
		_on_message("Dreh die leuchtende Reihe!", "info")
		return
	_on_message("Kein guter Zug. Dreh einfach.", "info")


func _hint_gives_rain() -> void:
	Game.grant("rain")
	_on_message("Kein Zug passt. Hier, ein Regen!", "reward")


func _use_hint() -> void:
	_hint_live = true          # kommt bei dieser Drehung eine Wahl, leuchtet die empfohlene
	var best := world.show_hint()
	if int(best.get("steps", 1)) == 2:
		_on_message("Erst diese Reihe, dann passt's.", "info")
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
	ad_label.text = "Tipp %d · Zurück %d · Weiterspielen %d\nDu hast %d." % [
		Balance.HINT_COST, Balance.UNDO_COST, Balance.CONTINUE_COST, Game.credits]
	_open_modal(ad_card)


func _on_continue() -> void:
	_close_modal()
	_pay(Balance.CONTINUE_COST, "Weiterspielen", Game.continue_game)


func _on_over_home() -> void:
	_close_modal(true)
	day_ui.show_overview()


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
		if arranged.counts(ln):
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
			text = "+%d Glauben" % int(info["gain"])
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


## Das alte Schritt-für-Schritt-Tutorial ist weg (Tag 1 ist das Tutorial). Hier bewegte sich früher der Würfel von
## selbst (Hand alle paar Sekunden, Auto-Zug): Das gibt es nicht mehr. Die einzige Vorführung spielt day_ui ganz am
## Anfang von Tag 1, solange die Eingabe gesperrt ist (_play_demo_move).
func _tutorial_tick() -> void:
	pass


## Tag 1 „Schau zu!“: Die Hand spielt den ersten Zug vor (Finger wischt, die Scheibe dreht ganz, die Reihe wächst).
## mv: {"axis", "layer", "turns"}. Die Hand wischt auf der ersten sichtbaren Seite, auf der die Scheibe liegt.
## Nur, solange World.can_self_move() gilt (vor jeder Eingabe). false = ging nicht (dann keine Vorführung).
func _play_demo_move(mv: Dictionary) -> bool:
	var gs := Game.state
	var axis := int(mv.get("axis", 0))
	var layer := int(mv.get("layer", 1))
	var turns := int(mv.get("turns", 1))
	var a: FieldData = null
	var b: FieldData = null
	var mid: FieldData = null
	var sa := {}
	var sb := {}
	for nv in [Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]:
		var n: Vector3i = nv
		var na := GameState.axis_of(n)
		if na == axis:
			continue
		var free_axis := 3 - axis - na
		a = gs.field_at(_demo_pos(n, axis, layer, free_axis, -1), n)
		b = gs.field_at(_demo_pos(n, axis, layer, free_axis, 1), n)
		mid = gs.field_at(_demo_pos(n, axis, layer, free_axis, 0), n)
		if a == null or b == null or mid == null:
			continue
		sa = world.field_screen(a.id)
		sb = world.field_screen(b.id)
		if bool(sa["visible"]) and bool(sb["visible"]):
			break
		a = null
	if a == null:
		return false
	var p0: Vector2 = sa["pos"]
	var p1: Vector2 = sb["pos"]
	_demo_until = _time + 2.0           # solange ist es eine Vorführung (kein Abbrechen-Streifen)
	var dir := world.demo_move(mid.id, p1 - p0, axis, layer, turns)
	if dir == Vector2.ZERO:
		_demo_until = 0.0
		return false
	var from := p0 if dir.dot(p1 - p0) > 0.0 else p1
	var to := p1 if from == p0 else p0
	tut_finger.position = from - tut_finger.size * 0.5
	tut_finger.pivot_offset = tut_finger.size * 0.5
	tut_finger.scale = Vector2.ONE * 1.1
	var tw := _fx(tut_finger, "v")
	tw.tween_property(tut_finger, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(tut_finger, "scale", Vector2.ONE, 0.18)
	tw.tween_property(tut_finger, "position", to - tut_finger.size * 0.5, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(tut_finger, "modulate:a", 0.0, 0.3)
	return true


## Ein Würfelplatz auf der Seite n: Koordinate layer auf der Drehachse, off (-1, 0, 1) auf der freien Achse.
static func _demo_pos(n: Vector3i, axis: int, layer: int, free_axis: int, off: int) -> Vector3i:
	var c := [n.x, n.y, n.z]
	c[axis] = layer
	c[free_axis] = off
	return Vector3i(int(c[0]), int(c[1]), int(c[2]))


func _tut_wait() -> String:
	if not Game.tutorial() or Game.tutorial_step >= TUT_STEPS.size():
		return ""
	return str(TUT_STEPS[Game.tutorial_step]["wait"])


func _on_move_done(kind: String) -> void:
	var grew := _tut_merged
	_tut_merged = false
	if kind != "rain":
		_hint_live = false
	if _resume_mode != "":
		var rm := _resume_mode
		_resume_mode = ""
		if bonus_mode == "" and Game.state != null and Game.state.rain > 0 and not Game.over:
			_set_bonus_mode(rm)
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
	if not Game.tutorial():
		_coach_world()


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
## fid >= 0: Der Hinweis zeigt auf dieses Feld (target ist dann der unsichtbare Anker).
func _coach_once(key: String, target: Control, fid: int = -1) -> void:
	if Game.tutorial() or Game.coach_seen.has(key) or not COACH.has(key):
		return
	if Game.in_day() and not DAY_COACH.has(key):
		return      # an den Tagen erklärt jeder Tag sein Neues selbst (nur diese allgemeinen Hinweise bleiben)
	for it in _coach_queue:
		if str((it as Array)[0]) == key:
			return
	_coach_queue.append([key, target, fid, _time])


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


## Hinweise aus der Welt (einmal, im richtigen Moment): Weltwaage, Kirche, fertige Felder, Industrie, Smog, keine Menschen.
func _coach_world() -> void:
	var gs := Game.state
	if gs == null or Game.tutorial() or Game.over:
		return
	if _known("scale") and scale_chip.visible:
		_coach_once("scale", scale_chip)
	var church := _field_of(FieldData.CHURCH)
	if church >= 0:
		_coach_once("church", _anchor, church)
	var ind := _field_of(FieldData.INDUSTRY)
	if ind >= 0:
		_coach_once("industry", _anchor, ind)
	if gs.tool_unlocked("strike") and strike_btn.is_visible_in_tree():
		_coach_once("finished", strike_btn)
	if gs.tool_unlocked("flood") and flood_btn.is_visible_in_tree():
		_coach_once("smog", flood_btn)
	if gs.wild_twists >= 10:
		_coach_once("nopeople", scale_chip if scale_chip.visible else score_box)


## Ein Feld dieser Art, am liebsten eines, das man gerade sieht (-1: keins).
func _field_of(k: int) -> int:
	var any := -1
	for f in Game.state.fields:
		if (f as FieldData).kind != k:
			continue
		if bool(world.field_screen((f as FieldData).id)["visible"]):
			return (f as FieldData).id
		if any < 0:
			any = (f as FieldData).id
	return any


## Der Tipp kommt dazu (mit den Münzen), wenn man feststeckt: 2 Fehlversuche hintereinander oder 15 s Pause.
func _reveal_hint() -> void:
	if Game.tutorial() or _known("hint") or not Game.state.gadgets:
		return
	_reveal("hint")
	_reveal("coins")
	refresh()
	_coach_once("hint", hint_btn)


## Text eines Hinweises (manche hängen vom Spielstand ab).
func _coach_text(key: String, fid: int = -1) -> String:
	var gs := Game.state
	if key == "wish" and gs != null and fid >= 0:
		var w := gs.wish_at(fid)
		if not w.is_empty():
			var left := int(w["left"])
			var wt := str(GameState.WISH_TEXT.get(str(w["type"]), ""))
			if Game.in_day() and not _faith_shown():
				return "%s Dann wächst ihr Haus." % wt
			return "%s Noch %d %s." % [wt, left, "Drehung" if left == 1 else "Drehungen"]
	if key == "fire" and Game.in_day():
		return Voice.line("fire")
	if Voice.has(key) and (Game.in_day() or ["miss", "war", "smog", "hold", "mini"].has(key)) and key != "fire":
		return Voice.line(key)          # Der Charakter sagt es in seinem Ton (der Inhalt bleibt derselbe)
	if key == "fire" and gs != null and gs.rain <= 0:
		return "Feuer! Gleich schrumpft es."
	if key == "age" and gs != null:
		var age := gs.age_name()
		return "%s! %s" % [age, _next_age_text()]
	return str(COACH.get(key, ""))


func _coach_icon(key: String) -> String:
	if key == "age" and Game.state != null:
		return _age_icon()
	return str(COACH_ICON.get(key, "info"))


## „Als Nächstes: Antike – bau ein Haus.“ (oder: das letzte Zeitalter)
func _next_age_text() -> String:
	var gs := Game.state
	if gs == null:
		return ""
	return gs.next_age_goal()


## Symbol des Zeitalters: die fortschrittlichste Siedlung, die je gebaut wurde (Urzeit: Wiese).
func _age_icon() -> String:
	var gs := Game.state
	if gs == null:
		return "meadow"
	return _kind_icon(clampi(gs.best_stage, 0, FieldData.KIND_COUNT - 1))


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
		var fid := int(item[2])
		var about := fid           # das Feld, um das es geht (auch wenn der Hinweis an der Zahl hängt)
		if not is_instance_valid(target) or Game.coach_seen.has(key):
			_coach_queue.remove_at(i)
			return
		if key == "rain" and _own_twists < 2 and not _fire_seen:
			continue      # nicht direkt nach dem Tutorial
		if fid >= 0:
			# Hinweis an einem Feld: nur, wenn man es gerade sieht; sonst nach einer Weile an der Glaubenszahl
			if not _aim_anchor(fid, key == "wish"):
				if _time - float(item[3]) < 10.0:
					continue
				target = score_box
				fid = -1
			if sheet.visible or mode_card.visible:
				continue
		var in_dock := target.is_inside_tree() and dock.is_ancestor_of(target)
		if in_dock and (sheet.visible or mode_card.visible):
			continue
		if fid < 0 and not in_dock and (_toast_busy or banner.visible or preview_card.visible):
			continue      # oben ist gerade die Meldungsspur belegt
		if not target.is_visible_in_tree():
			continue
		_coach_queue.remove_at(i)
		Game.coach_seen[key] = true
		Game.save_settings()
		_coach_twist = _own_twists
		_coach_in_hud = not in_dock and fid < 0
		_place_coach(target, _coach_icon(key), _coach_text(key, about), Voice.face(key))
		return


func _place_coach(target: Control, icon_name: String, text: String, face: String = "") -> void:
	_speak(coach_speaker, face if face != "" else "neutral", icon_name, _tint_for_icon(icon_name))
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
		_queued_tap = -1
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
		if Game.over:
			return
		if Game.busy or world.animating:
			# Es läuft noch eine Animation (z. B. der letzte Regen): merken und gleich danach einsetzen
			_queued_tap = fid
			world.select(fid)
			return
		var err := Game.state.can_bonus(kind, Game.state.fields[fid])
		if err != "":
			# Hier geht es nicht: Feld wackelt, die Ziele leuchten noch einmal auf, die Karte und eine Meldung sagen, was geht
			world.nudge(fid)
			_world_targets(kind)
			_pop(mode_card, 1.05)
			_on_message(_bonus_refusal(kind, err), "info")
			return
		if (kind == "strike" or kind == "flood") and not _same_pick(kind, fid):
			_punish_pick(kind, fid)       # erst zeigen, was getroffen wird; noch einmal tippen bestätigt
			return
		if Game.use_bonus(kind, fid, [], true):
			if kind != "strike" and kind != "flood":
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


## Warum der Bonus hier nicht geht, in Worten, die man versteht.
func _bonus_refusal(kind: String, err: String) -> String:
	var gs := Game.state
	if kind == "rain" and gs != null and gs.rain > 0:
		return "Regen nur auf blau leuchtende Felder."
	return err


## Strafe: Ist das dasselbe Ziel wie beim ersten Tippen? (Flut: dieselbe Seite.)
func _same_pick(kind: String, fid: int) -> bool:
	if _pick < 0:
		return false
	if kind == "flood":
		return (Game.state.fields[_pick] as FieldData).n == (Game.state.fields[fid] as FieldData).n
	return _pick == fid


## Strafe: Ziel zeigen (es leuchtet) und um Bestätigung bitten.
func _punish_pick(kind: String, fid: int) -> void:
	var gs := Game.state
	_pick = fid
	var f: FieldData = gs.fields[fid]
	world.set_pick(gs.bonus_fields(kind, f))
	world.nudge(fid)
	if kind == "strike":
		var to := "Erde" if f.kind == FieldData.INDUSTRY else FieldData.kind_name(FieldData.down(f.kind))
		mode_label.text = "Noch einmal tippen: Gewitter!"
		mode_hint.text = "%s wird %s. Kostet %d Glauben." % [FieldData.kind_name(f.kind), to, Balance.STRIKE_COST]
	else:
		mode_label.text = "Noch einmal tippen: Flut!"
		mode_hint.text = "Wäscht diese Seite. %d Glauben." % Balance.FLOOD_COST
	_place_context(mode_card)
	_pop(mode_card, 1.04)
	Style.haptic(Style.HAPTIC_TAP)


## Feld, das während einer Animation für den Bonus angetippt wurde: jetzt einsetzen.
func _queued_tick() -> void:
	if _queued_tap < 0:
		return
	if bonus_mode == "" or Game.over:
		_queued_tap = -1
		return
	if Game.busy or world.animating:
		return
	var q := _queued_tap
	_queued_tap = -1
	world.select(-1)
	_on_field_tapped(q)


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
	var k := f.kind
	_set_tile(sheet_tile, _kind_icon(k), _kind_tint(k))
	sheet_title.text = FieldData.kind_name(k)
	if f.burning:
		sheet_caps.text = "Brennt!"
	elif k == FieldData.EMPTY:
		sheet_caps.text = "Leer"
	elif f.is_finished():
		sheet_caps.text = "Fertig · +%d Glaube pro Runde" % int(Balance.INCOME.get(k, 0))
	elif FieldData.people(k):
		sheet_caps.text = "Menschen"
	elif FieldData.nature(k):
		sheet_caps.text = "Natur"
	else:
		sheet_caps.text = "Essen"
	# Die Regel als Bild: 3 × Feld → nächste Art (an einer Wahl: beide Möglichkeiten)
	var can_grow := Game.state.can_row(k)
	sheet_ladder.visible = can_grow
	if can_grow:
		for ic in sheet_from:
			(ic as TextureRect).texture = Style.icon(_kind_icon(k))
		var opts := Game.state.options_of(k)
		var choice := opts.size() >= 2
		sheet_next.texture = Style.icon(_kind_icon(int(opts[0]) if choice else Game.state.next_of(k)))
		sheet_or.visible = choice
		sheet_next2.visible = choice
		if choice:
			sheet_next2.texture = Style.icon(_kind_icon(int(opts[1])))
		sheet_rule.text = "  Du wählst" if choice else "  3 in einer Reihe"
	var tut := Game.tutorial()      # Regen und Blitz kommen erst nach dem Tutorial
	var body := ""
	if f.burning:
		body = "Brennt! Gieß es schnell."
	elif k == FieldData.EMPTY:
		body = "Leere Erde." if tut else _kind_body(0, false) + " Mit Regen wird hier eine Wiese."
	else:
		body = _kind_body(k, f.is_finished())
	if not f.burning and world.smog_fields(gs).has(fid):
		body += "\nSmog! Industrie daneben macht die Luft schmutzig. Mehr Natur oder ein Gewitter hilft."
	if k == FieldData.CHURCH:
		for g in gs.neighbors(f):
			if (g as FieldData).kind == FieldData.CHURCH:
				body += "\nAchtung: Kirche daneben – das gibt Krieg."
				break
	body = body.strip_edges()
	var w := gs.wish_at(fid)
	if not w.is_empty():
		var left := int(w["left"])
		body += "\nWunsch: %s Noch %d %s." % [str(GameState.WISH_TEXT.get(str(w["type"]), "")), left, "Drehung" if left == 1 else "Drehungen"]
	sheet_body.text = body
	sheet_body.visible = body != ""
	var blocked := Game.busy or Game.over or world.animating
	sheet_rain.visible = not tut and gs.rain > 0 and gs.can_bonus("rain", f) == ""
	sheet_rain.disabled = blocked
	sheet_rain.text = ("Löschen (%d)" if f.burning else "Gießen (%d)") % gs.rain
	sheet_bolt.visible = not tut and gs.bolts > 0 and not gs.corner_diagonal(f).is_empty()
	sheet_bolt.disabled = blocked
	sheet_bolt.text = "Blitz (%d)" % gs.bolts
	sheet_acts.visible = sheet_rain.visible or sheet_bolt.visible


# =============================================================================
# Jubel-Pille, Blasen, Meldungen
# =============================================================================

## kind: merge, combo, age, face, miss, fire. Ein neuer Aufruf ersetzt die aktuelle Pille.
## Wichtige Pillen (Krieg, Wunsch, Smog, Strafe) bleiben kurz stehen; was dann kommt, wartet dahinter.
const BANNER_KEEP = {"war": 1.3, "wish": 1.3, "smog": 1.2, "punish": 1.1, "fire": 1.0, "still": 1.2}


func _show_banner(kind: String, caps: String, text: String, icon_name: String) -> void:
	if banner.visible and _time < _banner_keep_until and not BANNER_KEEP.has(kind):
		_banner_next = [kind, caps, text, icon_name]
		var wait := _fx(banner, "q")
		wait.tween_interval(maxf(0.05, _banner_keep_until - _time))
		wait.tween_callback(_banner_flush)
		return
	_banner_keep_until = _time + float(BANNER_KEEP.get(kind, 0.0))
	var bg := Style.SURFACE
	var cc := Style.SUN_DEEP
	if kind == "age" or kind == "wish":
		bg = Style.SUN_TINT
	elif kind == "miss" or kind == "fire" or kind == "war" or kind == "smog":
		bg = Style.FIRE_TINT
		cc = Style.FIRE_DEEP
	elif kind == "punish":
		bg = PUNISH_TINT
		cc = PUNISH_DEEP
	var sb: StyleBoxFlat = banner.get_theme_stylebox("panel")
	sb.bg_color = bg
	banner_caps.text = caps
	banner_caps.visible = caps != ""
	banner_caps.add_theme_color_override("font_color", cc)
	banner_text.text = text
	banner_text.add_theme_font_size_override("font_size", 24 if text.length() <= 28 else 20)      # lange Ratschläge passen noch
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
	elif kind == "miss" or kind == "still":
		hold = 2.0 if caps.length() > 24 else 1.7        # Grund und Ratschlag: Zeit zum Lesen
	var tw := _fx(banner, "t")
	tw.tween_interval(hold)
	tw.tween_callback(_disappear.bind(banner, Vector2(0, -16), 0.22, false))


func _banner_flush() -> void:
	if _banner_next.is_empty():
		return
	var n: Array = _banner_next
	_banner_next = []
	_show_banner(str(n[0]), str(n[1]), str(n[2]), str(n[3]))


func _on_merged(fid: int, points: int, combo: int, stage: int) -> void:
	_tut_merged = true
	char_react("proud" if combo >= 2 else "happy", "hop", 1.4)      # der Charakter freut sich mit
	_miss_streak = 0
	if _faith_shown():
		_bubble(fid, "+%d" % points, "faith", Style.SUN_DEEP)
	elif Game.state.goal_kinds().has(stage):
		_bubble(fid, "+1", _kind_icon(stage), Style.LEAF_DEEP)      # zählt für das Ziel des Tages
	if combo >= 2:
		_show_banner("combo", "", "%s! ×%d" % [GameState.stage_name(stage), combo], STAGE_ICON[clampi(stage, 0, Balance.MAX_STAGE)])
		Style.haptic(Style.HAPTIC_COMBO)
	else:
		_show_banner("merge", "", GameState.stage_name(stage) + "!", STAGE_ICON[clampi(stage, 0, Balance.MAX_STAGE)])
		Style.haptic(Style.HAPTIC_MERGE)


## Warum ist nichts gewachsen? [Kopfzeile = der Grund, Satz = was man stattdessen tun kann] für die Pille
## (why aus GameState._miss_why / still).
func _miss_text(why: String) -> Array:
	if why == "repeat":
		return ["Zurückgedreht", "Dreh eine andere Scheibe"]
	if why == "spent":
		return ["Schon gewachsen", "Bring ein anderes Feld rein"]
	if why == "standing":
		return ["Stand schon da", "Bring ein neues Feld rein"]
	if why == "finished":
		return ["Fertig", "Wächst nicht mehr"]
	if why == "diag":
		if _diag_text() == "Nur gerade Reihen zählen":
			return ["Schräg zählt nicht", "Bring 3 gleiche in eine gerade Reihe"]
		return ["Schräg", _diag_text()]
	if why == "water":
		return ["Wasser wächst nie", "Bring 3 gleiche in eine Reihe"]
	return ["", "Nichts gewachsen"]


## Ruht die Art k: Was wächst heute stattdessen? „Mach lieber neue Wälder aus Wiesen“ (sonst „Morgen wächst hier mehr.“).
func _rest_action(k: int) -> String:
	var gs := Game.state
	if gs != null:
		for p in FieldData.KIND_COUNT:
			if int(FieldData.NEXT[p]) == k and gs.can_row(p):
				return "Mach neue %s aus %s" % [FieldData.kind_plural(k), FieldData.kind_plural(p)]
	return str(Days.TEXT["rest"])


## Schräge Reihen: an den Tagen nie, im freien Spiel je nach Stufe.
func _diag_text() -> String:
	var gs := Game.state
	if gs == null or gs.is_day() or not gs.diagonals:
		return "Nur gerade Reihen zählen"
	for k in FieldData.KIND_COUNT:
		if FieldData.can_row(k) and FieldData.tier(k) == gs.diag_from:
			return "Schräg zählt erst ab %s" % FieldData.kind_name(k)
	return "Schräg zählt hier nicht"


## Ab welchem Tag wächst die ruhende Art k weiter? Satz für die Pille.
func _rest_text(k: int, nx: int) -> String:
	var name := FieldData.kind_plural(k)
	name = name.substr(0, 1).to_upper() + name.substr(1)
	var from := Game.day_no + 1 if Game.in_day() else 1
	for d in range(maxi(1, from), Days.count() + 1):
		if (Days.config(d).get("unlocked", []) as Array).has(nx):
			return "%s erst ab Tag %d" % [name, d]
	return "%s erst im freien Spiel" % name


## Eine stille Reihe (World._still_fx): drei gleiche, die nicht wachsen. Die Felder leuchten schon mit Abzeichen;
## hier steht kurz, warum. Kam ein Fehlversuch, sagt dessen Pille den Grund (keine zweite Pille).
var _still_said := -1          # in dieser Runde schon eine Pille für eine stille Reihe (World.round_no; Regen ist eine eigene Runde)


func _on_still(info: Dictionary) -> void:
	var why := str(info.get("why", ""))
	if why == "other" or why == "water":
		return            # Wasser: nur das Abzeichen (und der Grund in der Fehlversuch-Pille)
	if bool(info.get("miss", false)) and why != "rest":
		return
	if not bool(info.get("visible", true)) or input_locked():
		return            # Reihe gerade nicht zu sehen, oder die Vorführung von Tag 1 läuft (dort zählt nur das Wachsen)
	var rnd := int(info.get("round", -1))
	if Game.state == null or _still_said == rnd:
		return
	_still_said = rnd
	var caps := ""
	var text := ""
	var icon_name := str(World.STILL_BADGE.get(why, "info"))
	if why == "rest":
		# Kopfzeile: warum (ruht bis Tag n), Satz: was heute stattdessen wächst (eine Pille, keine zweite Karte)
		caps = "Ruht · " + _rest_text(int(info.get("kind", 0)), int(info.get("next", -1)))
		text = _rest_action(int(info.get("kind", 0)))
	else:
		var mt := _miss_text(why)
		caps = str(mt[0])
		text = str(mt[1])
	Style.haptic(Style.HAPTIC_TAP)
	if bool(info.get("grew", false)) and banner.visible:
		# Erst die Jubel-Pille fürs Gewachsene sehen lassen, dann diese
		_banner_next = ["still", caps, text, icon_name]
		var wait := _fx(banner, "q")
		wait.tween_interval(0.8)
		wait.tween_callback(_banner_flush)
		return
	_show_banner("still", caps, text, icon_name)


## Fehlversuch: Pille zeigen, dann fliegt eine Flamme oben in ihren Platz.
func _on_miss(_fid: int, count: int, why: String = "") -> void:
	if Game.tutorial():
		return
	if count >= Balance.FIRE_AFTER - 1:
		char_react("worried", "", 2.0)       # große Augen: gleich brennt es
	if Game.in_day() and Game.state.no_fire:
		# Ohne Feuer (Tag 1) zählen Fehlversuche nicht: nur kurz sagen, warum nichts gewachsen ist
		_miss_streak += 1
		var mt0 := _miss_text(why)
		_show_banner("miss", str(mt0[0]), str(mt0[1]), str(World.STILL_BADGE.get(why, "info")))
		return
	_miss_streak += 1
	# Die Flammen oben erscheinen mit dem ersten Fehlversuch (die Flamme fliegt hinein)
	_reveal("flames")
	_chip_show(flame_chip, true, true)
	_coach_once("miss", flame_chip)
	if count < Balance.FIRE_AFTER:
		# Nur zurückgedreht? Dann sagen, warum die Reihe diesmal nicht wächst
		# Sagen, warum die Reihe diesmal nicht wächst (zurückgedreht, schon gewachsen, schräg, Wasser …)
		var mt := _miss_text(why)
		_show_banner("miss", str(mt[0]), str(mt[1]), "fire_off")
		Style.haptic(Style.HAPTIC_TAP)
	elif why == "repeat":
		_on_message("Zurückgedreht zählt nicht.", "info")       # gleich brennt es: sagen, warum
	elif why == "spent" or why == "standing":
		_on_message("Diese Reihe zählt nur einmal.", "info")
	elif why == "diag":
		_on_message(_diag_text() + ".", "info")
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
	char_react("worried", "shake", 2.2)
	if kind == "fire":
		_coach_once("fire", rain_btn if Game.state.rain > 0 and rain_btn.is_visible_in_tree() else flame_chip)
		_reveal("undo")              # wer brennt, lernt Zurück kennen
		_coach_once("undo", undo_btn)
	var hearts_on := Game.state.hearts
	_show_banner("fire", "-1 Herz" if hearts_on else "Die Reihe brennt", str(GameState.DISASTER_NAME.get(kind, "Feuer")) + "!", "fire")
	Style.haptic(Style.HAPTIC_FIRE)
	if fid >= 0:
		_bubble(fid, "-1 Herz" if hearts_on else "Feuer!", "heart" if hearts_on else "fire", Style.FIRE_DEEP)


func _on_deltas(list: Array, _gain: int) -> void:
	for d in list:
		var fid := int(d["field"])
		match str(d["change"]):
			"lost":
				_bubble(fid, "weg", "empty", Style.INK_2)
			"new":
				_bubble(fid, "Wiese", "meadow", Style.LEAF_DEEP)
	refresh()


## Kleine Pille über einem Feld (folgt dem Feld, steigt auf und verblasst).
func _bubble(fid: int, text: String, icon_name: String, color: Color, lift: float = 0.0) -> void:
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
	_bubbles.append({"node": b, "fid": fid, "t": 0.0, "dur": 2.6, "lift": lift})
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
		b.position = (info["pos"] as Vector2) - Vector2(sz.x * 0.5, sz.y + float(bd.get("lift", 0.0)) + 40.0 * ease(k, 0.4))
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
	if day_ui != null and day_ui.is_open():
		# In der Übersicht unten (oben spricht der Charakter in seiner Blase)
		toast.position.y = roundf(vs.y - _insets.y - Style.BOTTOM_GAP - toast.size.y - 12.0)


func _lane_y() -> float:
	if tut_card != null and tut_card.visible and Game.tutorial():
		return tut_card.position.y + tut_card.size.y + 12.0
	if day_ui != null and day_ui.lane_visible():
		return day_ui.lane_bottom() + 12.0
	return _lane_base()


## Oberkante der Meldungsspur: unter der Kopfzeile (ohne Hinweis-Zeile).
func _lane_base() -> float:
	var y := _insets.x + Style.LANE_Y
	if top != null and top.visible and row3 != null and row3.is_visible_in_tree():
		y = maxf(y, top.get_global_rect().end.y + 14.0)     # die Weltwaage macht die Kopfzeile höher
	return y


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
	_menu_cont.text = "Zurück" if day_ui.is_open() else "Weiterspielen"
	var dr: Dictionary = _menu_days.get_meta("free_row")
	(dr["caps"] as Label).text = "Sterne"
	(dr["num"] as Label).text = "%d/%d" % [Game.stars_total(), Game.stars_max()]
	var free_ok := Game.free_play_unlocked()
	_menu_free_caps.text = str(Days.TEXT["free"]) if free_ok else "%s · %s" % [str(Days.TEXT["free"]), str(Days.TEXT["free_locked"])]
	for key in _menu_rows:
		var rb: Button = (_menu_rows[key] as Dictionary)["btn"]
		rb.modulate.a = 1.0 if free_ok else 0.5
	for key in _menu_rows:
		var row: Dictionary = _menu_rows[key]
		var b: Button = row["btn"]
		var rc: Label = row["caps"]
		var num: Label = row["num"]
		var is_cur := str(key) == cur and not Game.tutorial() and not Game.in_day() and not day_ui.is_open()
		var n: StyleBoxFlat = b.get_meta("sb")
		n.bg_color = Style.SUN_TINT if is_cur else Style.SURFACE_2
		rc.text = "Aktuell" if is_cur else "Rekord"
		rc.add_theme_color_override("font_color", Style.SUN_DEEP if is_cur else Style.INK_3)
		var best := _mode_best(str(key))
		num.text = str(best) if best > 0 else "–"
	_sync_switch(_music_switch, Game.music_on)
	_sync_switch(_sfx_switch, Game.sfx_on)
	_sync_switch(_ask_switch, Game.always_ask)
	for r in _ask_rows:
		(r as Control).visible = not Game.cards_seen.is_empty() or Game.always_ask
	_refresh_menu_daily()


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
	if Game.in_day():
		return false        # einen Tag verlässt man ohne Nachteil
	return Game.state != null and (Game.state.faith > 0 or Game.state.twists > 0) and not Game.over and not Game.tutorial()


## Zeile im Menü angetippt: die laufende Spielart = weiterspielen, sonst (nach Rückfrage) neu starten.
func _on_mode_row(key: String) -> void:
	if key == "tage":
		_close_modal(true)
		day_ui.show_overview()
		return
	if not Game.free_play_unlocked():
		var row: Dictionary = _menu_rows.get(key, {})
		var b: Control = row.get("btn", _menu_free_caps)
		_shake(b)
		_show_tooltip(b, "lock", str(Days.TEXT["free"]), "Erst die 7 Tage schaffen.")
		_tip_hide_at = _time + 2.4
		return
	if key == _current_mode_key() and _game_running():
		_close_modal()
		return
	_ask_new_game(key)


func _ask_new_game(key: String) -> void:
	if not _game_running():
		_run_new(key)
		return
	_confirm_key = key
	var day := key.begins_with("day:")
	(confirm_card.get_meta("title") as Label).text = ("Tag %d starten?" % int(key.substr(4))) if day else "Neues Spiel starten?"
	_confirm_yes.text = "Ja, Tag %d spielen" % int(key.substr(4)) if day else "Ja, neues Spiel"
	_open_modal(confirm_card)


## Einen Tag starten (Übersicht). Läuft noch ein freies Spiel, erst fragen – es endet sonst ohne Warnung.
func ask_day(n: int) -> void:
	_ask_new_game("day:%d" % n)


func _on_confirm_new() -> void:
	var key := _confirm_key
	_confirm_key = ""
	_run_new(key)


func _on_confirm_back() -> void:
	var was_day := _confirm_key.begins_with("day:")
	_confirm_key = ""
	if was_day:
		_close_modal()          # zurück zur Übersicht der Tage
		return
	_open_menu()


func _run_new(key: String) -> void:
	if key.begins_with("day:"):
		_close_modal(true)
		Game.start_day(int(key.substr(4)))
	elif key == "tutorial":
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
	var seen := Game.coach_seen
	var ever := gs.ever if gs != null else {}
	(_help_rows["scale"] as Control).visible = _known("scale")
	(_help_rows["wish"] as Control).visible = seen.has("wish") or (gs != null and not gs.wishes.is_empty())
	(_help_rows["war"] as Control).visible = ever.has(FieldData.CHURCH) or seen.has("church")
	(_help_rows["smog"] as Control).visible = ever.has(FieldData.INDUSTRY) or (gs != null and gs.tool_unlocked("flood"))
	(_help_rows["goal"] as Control).visible = gs != null and gs.tool_unlocked("strike")
	if gs != null and gs.complete_goal() > 0:
		_help_goal.text = "Vollende %d fertige Felder." % gs.complete_goal()
	else:
		_help_goal.text = "Fertige Felder bringen Glauben."
	(_help_rows["bolt"] as Control).visible = seen.has("bolt") or _known("bolt") or (gs != null and gs.bolts > 0)
	(_help_rows["monsoon"] as Control).visible = seen.has("monsoon") or (gs != null and gs.monsoon_unlocked)
	(_help_rows["strike"] as Control).visible = gs != null and gs.tool_unlocked("strike")
	(_help_rows["flood"] as Control).visible = gs != null and gs.tool_unlocked("flood")
	# An den Tagen: nur, was dieser Tag schon kennt (keine Herzen, Wahl ab Tag 5, Glaube ab Tag 6)
	var day := gs != null and Game.in_day()
	(_help_rows["task"] as Control).visible = day
	(_help_rows["tree"] as Control).visible = day
	if day:
		_fill_help_tree(gs)
	var wish_l := ((_help_rows["wish"] as Control).get_child(1) as Control).get_child(1) as Label
	if day and not _faith_shown():
		wish_l.text = "Wunsch in %d Drehungen: Haus wächst." % Balance.WISH_TWISTS
	else:
		wish_l.text = "Erfüll Wünsche in %d Drehungen." % Balance.WISH_TWISTS
	(_help_rows["will"] as Control).visible = not day or not (gs.day.get("choices", []) as Array).is_empty()
	(_help_rows["faith"] as Control).visible = not day or gs.goal_type() == "faith"
	(_help_rows["fire"] as Control).visible = not day or not gs.no_fire
	(_help_rows["rain"] as Control).visible = not day or gs.tool_unlocked("rain")
	var fire_l := ((_help_rows["fire"] as Control).get_child(1) as Control).get_child(1) as Label
	var fire_t := ((_help_rows["fire"] as Control).get_child(1) as Control).get_child(0) as Label
	if day:
		fire_t.text = "Flammen"
		fire_l.text = "Wächst nichts: Flamme. 3 Flammen: Feuer."
	else:
		fire_t.text = "Flammen & Herzen"
		fire_l.text = "3 Flammen: Feuer. Kostet ein Herz."
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
	_smog_banner = false
	for i in range(_coach_queue.size() - 1, -1, -1):
		if int((_coach_queue[i] as Array)[2]) >= 0:
			_coach_queue.remove_at(i)      # Hinweise an Feldern gehören zum alten Spiel
	_banner_next = []
	_banner_keep_until = 0.0
	_last_scale_zone = ""
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
	if Game.state != null and Game.state.faith == 0 and Game.state.twists == 0:
		_hud_entrance()


func _on_game_over() -> void:
	var gs := Game.state
	_close_choice()
	_hide_now(banner)
	_banner_next = []
	_toasts.clear()            # die Karte sagt schon alles
	var died := gs.died()
	if died:
		over_title.text = "Deine Welt ist verbrannt"
		_set_tile(over_tile, "fire", Style.FIRE_TINT)
	elif gs.completed:
		over_title.text = "Deine Welt ist vollendet!"
		_set_tile(over_tile, "star", Style.SUN_TINT)
	else:
		over_title.text = "Geschafft!"
		_set_tile(over_tile, "trophy", Style.SUN_TINT)
	over_age_icon.texture = Style.icon(_age_icon())
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
	over_undo_btn.visible = Game.can_undo() and died     # einen Sieg nimmt man nicht zurück
	_open_modal(over_card, false)
	_count_up(over_score, gs.faith, 0.9)
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


## „Immer fragen“: bei jeder Wahl die große Karte (sonst nach ein paar Mal die kleine Pille).
func _on_ask_toggled(on: bool) -> void:
	Game.set_always_ask(on)


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
# gdpd: Wahl-Karte „Dein Wille geschehe“ (zwei große Knöpfe) und die kleine Pille
# =============================================================================

func _build_choice() -> void:
	# Leichter Schleier (lässt alles durch) und ein Fänger: Tippen daneben schließt die Karte mit dem Standard
	choice_scrim = ColorRect.new()
	choice_scrim.color = Color(Style.INK, 0.10)
	choice_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choice_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_scrim.visible = false
	root.add_child(choice_scrim)
	choice_catcher = Control.new()
	choice_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choice_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	choice_catcher.gui_input.connect(_on_choice_outside)
	choice_catcher.visible = false
	root.add_child(choice_catcher)
	choice_card = PanelContainer.new()
	choice_card.add_theme_stylebox_override("panel", Style.card(Style.R_MODAL, 3, 20, 20))
	choice_card.mouse_filter = Control.MOUSE_FILTER_STOP
	choice_card.visible = false
	root.add_child(choice_card)
	var v := _vbox(14)
	v.custom_minimum_size = Vector2(Style.CONTENT_W - 40, 0)
	choice_card.add_child(v)
	var head := _vbox(2)
	v.add_child(head)
	choice_caps = _caps(FieldData.CHOICE_HEADER, Style.SUN_DEEP)
	choice_caps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(choice_caps)
	choice_title = _label("", Style.F_TITLE, Style.INK, Style.W_BLACK)
	choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(choice_title)
	_explain_only(head, "choice")
	var opts := _hbox(12)
	v.add_child(opts)
	var inner_w := (Style.CONTENT_W - 40 - 12) / 2 - 28
	for i in 2:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 212)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		var n := Style.box(Style.SURFACE_2, 22, 12, 12)
		var pr := Style.box(Style.SURFACE_3, 22, 12, 12)
		Style.skin(b, n, pr, Style.INK)
		b.set_meta("sb", n)
		_tap_or_explain(b, _on_choice_pick.bind(i), "choice_opt_%d" % i)
		opts.add_child(b)
		var bv := _vbox(6)
		bv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bv.offset_left = 12
		bv.offset_right = -12
		bv.offset_top = 22
		bv.offset_bottom = -22
		bv.alignment = BoxContainer.ALIGNMENT_BEGIN
		b.add_child(bv)
		var tl := _tile("smallforest", 80, Style.STAGE_TINT[2], 0.32)
		tl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bv.add_child(tl)
		var nm := _label("", 21, Style.INK, Style.W_BLACK)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bv.add_child(nm)
		var ln := _label("", 15, Style.INK_2, Style.W_BODY)
		ln.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ln.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ln.custom_minimum_size = Vector2(inner_w, 0)
		bv.add_child(ln)
		# „Tipp“: nach einem gekauften Tipp leuchtet die empfohlene Wahl
		var tag := PanelContainer.new()
		tag.add_theme_stylebox_override("panel", Style.box(Style.SUN, 11, 10, 2))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		tag.offset_left = -64
		tag.offset_right = -10
		tag.offset_top = 10
		tag.offset_bottom = 32
		tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		var tg := _caps("Tipp", Style.INK)
		tg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_child(tg)
		tag.visible = false
		b.add_child(tag)
		# Zeitbalken: so lange, bis der Standard gilt (nur im Standard-Knopf)
		var bar := Panel.new()
		bar.add_theme_stylebox_override("panel", Style.box(Color(Style.SUN_DEEP, 0.55), 2, 0, 0))
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.visible = false
		b.add_child(bar)
		choice_btns.append(b)
		choice_tiles.append(tl)
		choice_names.append(nm)
		choice_lines.append(ln)
		choice_tags.append(tag)
		choice_bars.append(bar)
	# Kleine Pille über dem neuen Feld (ab der vierten Wahl derselben Art): beide Bilder, die Gewohnheit leuchtet
	mini_pill = PanelContainer.new()
	mini_pill.add_theme_stylebox_override("panel", Style.card(30, 2, 8, 6))
	mini_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	mini_pill.visible = false
	root.add_child(mini_pill)
	var mv := _vbox(4)
	mini_pill.add_child(mv)
	var mh := _hbox(6)
	mv.add_child(mh)
	for i in 2:
		var mb := Button.new()
		mb.custom_minimum_size = Vector2(52, 52)
		mb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mb.add_theme_constant_override("icon_max_width", 34)
		mb.focus_mode = Control.FOCUS_NONE
		_tap_or_explain(mb, _on_mini_pick.bind(i), "mini")
		mh.add_child(mb)
		mini_btns.append(mb)
	mini_bar = Panel.new()
	mini_bar.add_theme_stylebox_override("panel", Style.box(Color(Style.SUN_DEEP, 0.55), 2, 0, 0))
	mini_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_bar.custom_minimum_size = Vector2(0, 4)
	mini_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mv.add_child(mini_bar)


func _kind_icon(k: int) -> String:
	var n := FieldData.kind_icon(k)
	if Style.icon(n) == null:
		return str(FieldData.KIND_ICON_FALLBACK.get(n, "meadow"))
	return n


func _kind_tint(k: int) -> Color:
	return Style.STAGE_TINT[clampi(k, 0, Style.STAGE_TINT.size() - 1)]


func _on_choice_needed(info: Dictionary) -> void:
	_choice = info.duplicate()
	_choice_gen += 1
	_choice_outside = 0
	_choice_total = float(info.get("timeout", Balance.CHOICE_TIMEOUT))
	_choice_left = _choice_total
	_choice_full = not bool(info.get("mini", false))
	_close_sheet()
	_hide_tip()
	_coach_dismiss()
	_resume_mode = bonus_mode if bonus_mode == "rain" else ""     # Regen bleibt nach der Wahl gewählt
	if bonus_mode != "":
		_set_bonus_mode("")
	world.show_choice(info)
	Style.haptic(Style.HAPTIC_MERGE)
	if Game.tutorial():
		_tut_set("Du bestimmst! Tipp auf ein Bild.", true, Game.tutorial_step)
	# Erst sieht man die Reihe leuchten, dann kommt ruhig die Karte
	get_tree().create_timer(0.45 if _choice_full else 0.2).timeout.connect(_choice_open.bind(_choice_gen))


func _choice_open(gen: int) -> void:
	if gen != _choice_gen or _choice.is_empty() or not Game.has_choice():
		return
	if not _choice_full:
		_fill_mini()
		_place_mini()
		_appear(mini_pill, Vector2(0, 10), Style.DUR_IN, 0.7)
		return
	_fill_choice_card()
	_place_choice()
	choice_catcher.visible = true
	choice_scrim.visible = true
	var ts := _fx(choice_scrim, "v")
	choice_scrim.modulate.a = 0.0
	ts.tween_property(choice_scrim, "modulate:a", 1.0, 0.25)
	_appear(choice_card, Vector2(0, 26), Style.DUR_MODAL, 0.95)
	for i in 2:
		var b: Button = choice_btns[i]
		_appear(b, Vector2.ZERO, Style.DUR_IN, 0.88, 0.08 + 0.06 * i)
	if Game.tutorial():
		get_tree().create_timer(0.5).timeout.connect(_choice_hand.bind(gen))


func _fill_choice_card() -> void:
	var k := int(_choice["kind"])
	var opts: Array = _choice["options"]
	choice_title.text = str(FieldData.CHOICE_TITLE.get(k, "Was soll hier wachsen?"))
	var def := int(_choice.get("default", 0))
	var best := int(_choice.get("best", -1))
	for i in 2:
		var ok := int(opts[i])
		_set_tile(choice_tiles[i], _kind_icon(ok), _kind_tint(ok))
		(choice_names[i] as Label).text = FieldData.kind_name(ok)
		(choice_lines[i] as Label).text = str(FieldData.CHOICE_LINE.get(ok, ""))
		var rec := _hint_live and i == best
		(choice_tags[i] as Control).visible = rec
		var b: Button = choice_btns[i]
		var n: StyleBox = Style.ring(Style.SUN_TINT, Style.SUN, 22) if rec else (b.get_meta("sb") as StyleBox)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", n)
		(choice_bars[i] as Control).visible = i == def and _choice_total > 0.0
	_update_choice_bars()


func _place_choice() -> void:
	choice_card.size = Vector2.ZERO
	choice_card.reset_size()
	var vs := _vs()
	var bottom := vs.y - _insets.y - Style.BOTTOM_GAP - (Style.DOCK_H + 12.0 if dock.visible else 24.0)
	var y := bottom - choice_card.size.y
	# Liegt das neue Feld hinter der Karte, kommt die Karte nach oben (unter die Kopfzeile)
	var fid := int(_choice.get("field", -1))
	if fid >= 0:
		var fs := world.field_screen(fid)
		if bool(fs["visible"]) and (fs["pos"] as Vector2).y > y - 40.0:
			y = _lane_y()
	choice_card.position = Vector2(roundf((vs.x - choice_card.size.x) * 0.5), roundf(y))


func _fill_mini() -> void:
	var opts: Array = _choice["options"]
	var def := int(_choice.get("default", 0))
	for i in 2:
		var mb: Button = mini_btns[i]
		mb.icon = Style.icon(_kind_icon(int(opts[i])))
		var on := i == def
		var n: StyleBoxFlat = Style.ring(Style.SUN_TINT, Style.SUN, 26) if on else Style.box(Style.SURFACE_2, 26, 0, 0)
		Style.skin(mb, n, Style.box(Style.SURFACE_3, 26, 0, 0), Style.INK)
		mb.modulate.a = 1.0 if on else 0.75
	mini_bar.visible = _choice_total > 0.0
	_update_choice_bars()


func _place_mini() -> void:
	mini_pill.size = Vector2.ZERO
	mini_pill.reset_size()
	var vs := _vs()
	var fid := int(_choice.get("field", -1))
	var p := Vector2(vs.x * 0.5, vs.y * 0.42)
	if fid >= 0:
		var fs := world.field_screen(fid)
		if bool(fs["visible"]):
			p = fs["pos"]
	var x := clampf(p.x - mini_pill.size.x * 0.5, Style.MARGIN, vs.x - Style.MARGIN - mini_pill.size.x)
	var y := clampf(p.y - mini_pill.size.y - 46.0, _lane_y(), vs.y - 300.0)
	mini_pill.position = Vector2(roundf(x), roundf(y))
	mini_pill.set_meta("rest", mini_pill.position)


## Tutorial: Die Hand zeigt abwechselnd auf beide Möglichkeiten (tippen).
func _choice_hand(gen: int) -> void:
	if gen != _choice_gen or not choice_card.visible:
		return
	var a: Vector2 = (choice_tiles[0] as Control).get_global_rect().get_center() + Vector2(10, 34)
	var b: Vector2 = (choice_tiles[1] as Control).get_global_rect().get_center() + Vector2(10, 34)
	var half := tut_finger.size * 0.5
	tut_finger.pivot_offset = half
	tut_finger.position = a - half + Vector2(0, 40)
	tut_finger.scale = Vector2.ONE
	var tw := _fx(tut_finger, "v")
	tw.tween_property(tut_finger, "modulate:a", 1.0, 0.25)
	tw.tween_property(tut_finger, "position", a - half, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_hand_loop.bind(a - half, b - half, gen))


func _hand_loop(pa: Vector2, pb: Vector2, gen: int) -> void:
	if gen != _choice_gen or not choice_card.visible:
		return
	var tw := _fx(tut_finger, "v")
	tw.set_loops()
	tw.tween_property(tut_finger, "scale", Vector2.ONE * 0.86, 0.14)
	tw.tween_property(tut_finger, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(tut_finger, "position", pb, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(tut_finger, "scale", Vector2.ONE * 0.86, 0.14)
	tw.tween_property(tut_finger, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(tut_finger, "position", pa, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Daneben getippt: deine letzte Wahl gilt. Im Tutorial wackelt die Karte erst einmal (man lernt das Tippen).
func _on_choice_outside(ev: InputEvent) -> void:
	var down := ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if not down or _choice.is_empty():
		return
	if Game.tutorial() and _choice_outside == 0:
		_choice_outside += 1
		_pop(choice_card, 1.03)
		Style.haptic(Style.HAPTIC_TAP)
		return
	_choice_pick_default()


func _choice_pick_default() -> void:
	if _choice.is_empty():
		return
	_choose(int(_choice.get("default", 0)))


func _on_choice_pick(i: int) -> void:
	if _choice.is_empty():
		return
	var b: Button = choice_btns[i]
	_pop(b, 1.06)
	_choose(i)


func _on_mini_pick(i: int) -> void:
	if _choice.is_empty():
		return
	_pop(mini_btns[i], 1.15)
	_choose(i)


func _choose(i: int) -> void:
	_close_choice(i)
	if Game.has_choice():
		Game.choose(i)


func _close_choice(picked: int = -1) -> void:
	_choice = {}
	_choice_gen += 1
	world.clear_choice()
	choice_catcher.visible = false
	_hide_finger()
	if choice_card.visible:
		for i in 2:
			if i != picked:
				var ob: Control = choice_btns[i]
				var tw := _fx(ob, "c")
				tw.tween_property(ob, "modulate:a", 0.35, 0.12)
		_disappear(choice_card, Vector2(0, 18), Style.DUR_OUT + 0.04)
	if choice_scrim.visible:
		var ts := _fx(choice_scrim, "v")
		ts.tween_property(choice_scrim, "modulate:a", 0.0, 0.2)
		ts.tween_callback(choice_scrim.hide)
	if mini_pill.visible:
		_disappear(mini_pill, Vector2(0, -10), Style.DUR_FAST)


## Lange auf die kleine Pille gedrückt: die große Karte (mit voller Zeit).
func _open_full_choice() -> void:
	if _choice.is_empty() or _choice_full:
		return
	_choice_full = true
	_choice_total = Balance.CHOICE_TIMEOUT
	_choice_left = _choice_total
	_hide_now(mini_pill)
	_choice_open(_choice_gen)


func _on_choice_made(info: Dictionary) -> void:
	if not _choice.is_empty():
		_close_choice(int(info.get("picked", -1)))
	if Game.tutorial() and Game.tutorial_step >= 1:
		_tut_set("Gut so! Du bist der Gott dieser Welt.", false, Game.tutorial_step)
	if bool(info.get("mini", false)):
		_coach_once("mini", _anchor, int(info.get("field", -1)))


func _choice_tick(delta: float) -> void:
	if _choice.is_empty():
		return
	if not Game.has_choice():
		_close_choice()
		return
	if mini_pill.visible and not _choice_full:
		_place_mini()
	if _choice_total <= 0.0:
		return
	var shown := (choice_card.visible and _choice_full) or (mini_pill.visible and not _choice_full)
	if not shown or _lp_node != null or tip_card.visible:
		return
	_choice_left -= delta
	_update_choice_bars()
	if _choice_left <= 0.0:
		_choice_pick_default()


func _update_choice_bars() -> void:
	var k := clampf(_choice_left / _choice_total, 0.0, 1.0) if _choice_total > 0.0 else 0.0
	if mini_bar != null and not _choice_full and mini_bar.visible:
		var row: Control = mini_bar.get_parent().get_child(0)
		mini_bar.custom_minimum_size = Vector2(maxf(0.0, row.size.x) * k, 4.0)
	for i in 2:
		var bar: Panel = choice_bars[i]
		if not bar.visible:
			continue
		var b: Control = choice_btns[i]
		var full := maxf(0.0, b.size.x - 48.0)
		bar.position = Vector2(24.0, b.size.y - 14.0)
		bar.size = Vector2(full * k, 4.0)


# =============================================================================
# gdpd: Ereignisse der Welt (Krieg, Smog, Wünsche, Glaube pro Runde, Strafen)
# =============================================================================

func _on_war(fids: Array, faith: int) -> void:
	char_react("worried", "shake", 2.2)
	var caps := "Zwei Kirchen trafen sich · %d Glauben" % faith
	if Game.in_day() and Game.state.no_war:
		caps = "Zwei Kirchen trafen sich"       # an Tag 6 beendet der Krieg den Tag (die Karte sagt es gleich)
	_show_banner("war", caps, "Krieg!", "swords")
	Style.haptic(Style.HAPTIC_FIRE)
	if not fids.is_empty():
		if not (Game.in_day() and Game.state.no_war):
			_bubble(int(fids[0]), "%d" % faith, "faith", Style.FIRE_DEEP)
			_coach_once("war", _anchor, int(fids[0]))


func _on_smog(_w: int, withered: Array) -> void:
	if _last_scale_zone != "smog" or not _smog_banner:
		_smog_banner = true
		_show_banner("smog", "Zu viel Industrie", "Smog!", "smog")
		_pop(scale_chip, 1.12)
	var n := 0
	for i in withered:
		if n >= 2:
			break
		var f: FieldData = Game.state.fields[int(i)]
		_bubble(int(i), "Die Tiere fliehen" if f.kind == FieldData.BIGFOREST else "welkt", "smog", Style.INK_2)
		n += 1


func _on_wish_done(fid: int, faith: int) -> void:
	char_react("proud", "hop", 1.6)
	_show_banner("wish", ("+%d Glauben" % faith) if _faith_shown() else "Die Menschen freuen sich", "Wunsch erfüllt!", "heart")
	Style.haptic(Style.HAPTIC_COMBO)
	var fs := world.field_screen(fid)
	var from: Vector2 = fs["pos"] if bool(fs["visible"]) else _vs() * Vector2(0.5, 0.45)
	_fly_faith(from, faith)


func _on_wish_made(fid: int) -> void:
	_bubble(fid, "Ein Wunsch!", "wish", Style.SUN_DEEP, 96.0)
	_coach_once("wish", _anchor, fid)


func _on_income(amount: int) -> void:
	if amount <= 0:
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Style.lift(Style.box(Style.SUN_TINT, 14, 10, 3), 1))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := _hbox(4)
	p.add_child(h)
	h.add_child(_icon("faith", 16))
	var l := _label("+%d pro Runde" % amount, 14, Style.SUN_DEEP, Style.W_BLACK)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	gift_layer.add_child(p)
	p.reset_size()
	# Neben der Zahl (rechts, sonst links vom Symbol): nie über den Flammen in der zweiten Zeile
	var r := score_label.get_global_rect()
	var x := r.end.x + 8.0
	var x_max := (credits_btn.get_global_rect().position.x - 6.0 if credits_btn.visible else _vs().x - Style.MARGIN) - p.size.x
	if x > x_max:
		x = faith_icon.get_global_rect().position.x - 8.0 - p.size.x
	p.position = Vector2(roundf(x), roundf(r.get_center().y - p.size.y * 0.5))
	if Game.in_day():
		# An den Tagen: unter dem Ziel-Chip (dort steht der Glaube)
		var cr := day_ui.chip.get_global_rect()
		p.position = Vector2(roundf(cr.get_center().x - p.size.x * 0.5), roundf(cr.end.y + 8.0))
	p.pivot_offset = p.size * 0.5
	p.scale = Vector2.ONE * 0.6
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.set_parallel(true)
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.2)
	tw.chain().tween_property(p, "position:y", p.position.y - 10.0, 0.4)
	tw.parallel().tween_property(p, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(p.queue_free)


func _on_punish(kind: String, fid: int, cost: int) -> void:
	_bubble(fid, "-%d" % cost, "faith", PUNISH_DEEP)
	_show_banner("punish", "-%d Glauben" % cost, "Gewitter!" if kind == "strike" else "Flut!", "strike" if kind == "strike" else "flood")
	Style.haptic(Style.HAPTIC_FIRE)


## Wird Glaube gerade gezeigt? Im freien Spiel immer, an den Tagen erst, wenn das Ziel Glaube ist (Tag 6 und 7).
func _faith_shown() -> bool:
	return not Game.in_day() or Game.state.goal_type() == "faith"


## Wohin Glaube fliegt: die Zahl oben (an den Tagen der Ziel-Chip).
func _faith_target() -> Control:
	if Game.in_day() and day_ui != null:
		return day_ui.chip_tile
	return faith_icon


## Glaube fliegt im Bogen nach oben in die Zahl.
func _fly_faith(from: Vector2, amount: int) -> void:
	if not _faith_shown():
		return
	for k in 3:
		var t := TextureRect.new()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.texture = Style.icon("faith")
		t.size = Vector2(40, 40)
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gift_layer.add_child(t)
		var start := from + Vector2(-18.0 + 18.0 * k, 0)
		t.position = start - t.size * 0.5
		var tw := _fly(t, start, _faith_target().get_global_rect().get_center(), Style.DUR_FLY + 0.1 * k, 120.0, 0.5)
		tw.tween_callback(_faith_land.bind(t, k == 0, amount))


func _faith_land(t: Control, first: bool, _amount: int) -> void:
	t.queue_free()
	if first and Game.in_day():
		_pop(_faith_target(), 1.15)
	elif first:
		_pop(faith_icon, 1.3)
		_number_pop(score_label)
		_ripple(faith_icon, Style.SUN)


## Kostet-Abzeichen der Strafen (Glaube); zu wenig Glaube: gedimmt.
func _set_cost_badge(b: Button, cost: int, ok: bool) -> void:
	var badge: PanelContainer = b.get_meta("badge")
	var bl: Label = b.get_meta("cost_label") if b.has_meta("cost_label") else null
	if bl == null:
		# Einmal umbauen: Glaubens-Symbol und „−15“ nebeneinander, hell wie ein Preisschild
		bl = badge.get_child(0)
		badge.remove_child(bl)
		var ph := _hbox(2)
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ph.alignment = BoxContainer.ALIGNMENT_CENTER
		badge.add_child(ph)
		ph.add_child(_icon("faith", 16))
		ph.add_child(bl)
		b.set_meta("cost_label", bl)
		badge.offset_left = -34
		badge.offset_right = 14
	bl.text = "−%d" % cost
	var bs: StyleBoxFlat = badge.get_meta("sb")
	bs.bg_color = Style.SURFACE
	bs.border_color = SLOT_COLOR.get(str(b.get_meta("kind")), PUNISH) if ok else Style.INK_3
	bl.add_theme_color_override("font_color", SLOT_COLOR.get(str(b.get_meta("kind")), PUNISH) if ok else Style.INK_3)
	badge.custom_minimum_size = Vector2(0, 26)
	badge.visible = true
	var slot: Control = b.get_meta("slot")
	if bool(slot.get_meta("dim", false)) == ok:
		slot.set_meta("dim", not ok)
		var tw := _fx(slot, "c")
		tw.tween_property(slot, "modulate:a", 1.0 if ok else 0.5, Style.DUR_FAST)


## Anker für einen Hinweis an einem Feld (oder an seiner Wunsch-Blase). false = gerade nicht zu sehen.
func _aim_anchor(fid: int, wish: bool) -> bool:
	var fs := world.wish_screen(fid) if wish else world.field_screen(fid)
	if not bool(fs["visible"]):
		if wish:
			fs = world.field_screen(fid)
		if not bool(fs["visible"]):
			return false
	var p: Vector2 = fs["pos"]
	_anchor.position = p - _anchor.size * 0.5
	return true


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
