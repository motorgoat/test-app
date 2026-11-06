class_name CharacterCreator
extends Control
## Ersteller des eigenen Charakters (Spec 3.7): höchstens 4 kurze Schritte, unter einer Minute.
##   1 Form · 2 Farben · 3 Gesicht und Schmuck · 4 Name und Art zu reden
## Oben die große Vorschau (wippt, hüpft froh bei jeder Änderung), darunter der Schritt.
## „Würfeln“ würfelt den aktuellen Schritt neu, langes Drücken würfelt alles.
## Eigenständig: braucht nur Style, Character und CharacterView. Kein Zugriff auf GameUI oder Game.
##
##   var cc := CharacterCreator.new()
##   cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
##   parent.add_child(cc)
##   cc.finished.connect(func(look: Dictionary) -> void: ...)
##   cc.open()                          # erster Start
##   cc.open(Character.load_look(), true)   # Menü „Dein Charakter“ (Titel und „Speichern“)

signal finished(look: Dictionary)
signal cancelled
signal step_changed(step: int)

const STEPS := 4
const NAME_PLACEHOLDER := "Name"

## Beim Fertig gleich nach user://charakter.cfg speichern (Character.save_look).
@export var autosave := true

var look: Dictionary = {}
var step := 0
var edit_mode := false

var preview: CharacterView
var _rng := RandomNumberGenerator.new()
var _bg: TextureRect
var _top: Control
var _name_label: Label
var _bubble: PanelContainer
var _bubble_label: Label
var _caps: Label
var _progress: HBoxContainer
var _dice: Button
var _close: Button
var _card: PanelContainer
var _title: Label
var _sub: Label
var _scroll: ScrollContainer
var _content: VBoxContainer
var _back: Button
var _next: Button
var _name_edit: LineEdit
var _tone_label: Label
var _dice_held := 0.0
var _dice_long := false
var _bubble_gen := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_build()
	look = Character.default_look("bart")
	_refresh_all()
	resized.connect(_layout)


func _ready() -> void:
	_layout()


## Öffnet den Ersteller. l: Ausgangs-Aussehen ({} = Bart-Gott mit Standardfarben). edit: aus dem Menü.
func open(l: Dictionary = {}, edit: bool = false) -> void:
	look = Character.sanitize(l) if not l.is_empty() else Character.default_look("bart")
	edit_mode = edit
	step = 0
	visible = true
	_refresh_all()


func go_to_step(s: int) -> void:
	step = clampi(s, 0, STEPS - 1)
	_fill_step()
	step_changed.emit(step)


func current_look() -> Dictionary:
	return Character.sanitize(look)


# --- Für Tests und die Screenshot-Tour (echte Eingabe auf echte Knöpfe) ---------------------------------

func next_button() -> Button:
	return _next


func dice_button() -> Button:
	return _dice


func name_edit() -> LineEdit:
	return _name_edit


func bubble_text() -> String:
	return _bubble_label.text if _bubble.visible else ""


## Der Knopf des aktuellen Schritts mit dieser Wahl („basis:katze“, „farbe:haupt:f2“, „augen:gross“, „kopf:krone“,
## „ton:frech“) oder null.
func pick_button(pick: String) -> Button:
	return _find_pick(_content, pick)


func _find_pick(n: Node, pick: String) -> Button:
	for c in n.get_children():
		if c is Button and String((c as Button).get_meta("pick", "")) == pick:
			return c as Button
		var r := _find_pick(c, pick)
		if r != null:
			return r
	return null


## Alle Wahl-Knöpfe des aktuellen Schritts, die so anfangen („farbe:haupt:“).
func pick_buttons(prefix: String) -> Array:
	var out: Array = []
	_collect_picks(_content, prefix, out)
	return out


func _collect_picks(n: Node, prefix: String, out: Array) -> void:
	for c in n.get_children():
		if c is Button and String((c as Button).get_meta("pick", "")).begins_with(prefix):
			out.append(c)
		_collect_picks(c, prefix, out)


# --- Aufbau ---------------------------------------------------------------------------------------------

func _build() -> void:
	# Weicher Himmel
	_bg = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color("#BFDDF5"))
	g.set_color(1, Color("#FBF8F3"))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	_bg.texture = gt
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	# Vorschau
	_top = Control.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)
	var shadow := Panel.new()
	shadow.name = "Shadow"
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.122, 0.141, 0.188, 0.10)
	ss.set_corner_radius_all(999)
	shadow.add_theme_stylebox_override("panel", ss)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(shadow)
	preview = CharacterView.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(preview)
	_name_label = _label("", Style.F_TITLE, Style.INK, Style.W_BLACK)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.add_child(_name_label)
	_bubble = PanelContainer.new()
	var bs := Style.card(22, 2, 16, 12)
	_bubble.add_theme_stylebox_override("panel", bs)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	_bubble_label = _label("", Style.F_BODY_S, Style.INK, Style.W_LABEL)
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.add_child(_bubble_label)
	_top.add_child(_bubble)
	# Kopfzeile
	_caps = _caps_label("1 von 4")
	add_child(_caps)
	_progress = HBoxContainer.new()
	_progress.add_theme_constant_override("separation", 6)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in STEPS:
		var seg := Panel.new()
		seg.custom_minimum_size = Vector2(28, 8)
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_progress.add_child(seg)
	add_child(_progress)
	_dice = _button("Würfeln", "glass", "dice", 44)
	_dice.button_down.connect(_on_dice_down)
	_dice.button_up.connect(_on_dice_up)
	add_child(_dice)
	_close = _button("", "glass", "close", 44)
	_close.custom_minimum_size = Vector2(44, 44)
	_close.add_theme_constant_override("icon_max_width", 20)
	_close.pressed.connect(_on_close)
	add_child(_close)
	# Karte unten
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", Style.card(Style.R_MODAL, 3, 22, 20))
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(v)
	_title = _label("", Style.F_TITLE, Style.INK, Style.W_BLACK)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	_sub = _label("", Style.F_BODY_S, Style.INK_2, Style.W_BODY)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_sub)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	v.add_child(_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 6)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(pad)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	pad.add_child(_content)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(foot)
	_back = _button("Zurück", "secondary", "", 56)
	_back.custom_minimum_size = Vector2(120, 56)
	_back.pressed.connect(_on_back)
	foot.add_child(_back)
	_next = _button("Weiter", "primary", "", 56)
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next.pressed.connect(_on_next)
	foot.add_child(_next)


func _layout() -> void:
	if _card == null:
		return
	var s := size
	var m := float(Style.S3)
	var top_h := s.y * 0.42
	_caps.position = Vector2(Style.MARGIN, Style.TOP_GAP + 2)
	_progress.position = Vector2(Style.MARGIN, Style.TOP_GAP + 24)
	_progress.size = _progress.get_combined_minimum_size()
	_dice.size = _dice.get_combined_minimum_size()
	_dice.position = Vector2(s.x - Style.MARGIN - _dice.size.x, Style.TOP_GAP)
	_close.size = Vector2(44, 44)
	_close.position = Vector2(s.x - Style.MARGIN - _dice.size.x - 10 - 44, Style.TOP_GAP)
	_close.visible = edit_mode
	var pv := clampf(minf(top_h - 110.0, s.x - 2 * Style.MARGIN), 120.0, 260.0)
	_top.position = Vector2.ZERO
	_top.size = Vector2(s.x, top_h)
	preview.size = Vector2(pv, pv)
	preview.custom_minimum_size = Vector2(pv, pv)
	preview.position = Vector2((s.x - pv) * 0.5, Style.TOP_GAP + 44 + maxf(0.0, (top_h - pv - 110.0) * 0.5))
	var shadow: Panel = _top.get_node("Shadow")
	shadow.size = Vector2(pv * 0.56, pv * 0.08)
	shadow.position = preview.position + Vector2(pv * 0.22, pv * 0.9)
	_name_label.size = Vector2(s.x, 36)
	_name_label.position = Vector2(0, preview.position.y + pv + 4)
	_layout_bubble()
	_card.position = Vector2(m, top_h)
	_card.size = Vector2(s.x - 2 * m, s.y - top_h - m)


func _layout_bubble() -> void:
	if not _bubble.visible:
		return
	var w := minf(size.x - 2 * Style.MARGIN, 380.0)
	# Erst die Breite des Satzes festlegen, dann seine Höhe messen (sonst bricht er jedes Wort um und die Blase
	# wird riesig und leer)
	_bubble_label.custom_minimum_size = Vector2(w - 32, 0)
	_bubble_label.size = Vector2(w - 32, 0)
	var h := _bubble_label.get_minimum_size().y + 24.0
	_bubble.size = Vector2(w, h)
	_bubble.position = Vector2((size.x - w) * 0.5, maxf(Style.TOP_GAP + 52.0, preview.position.y - h + 18.0))


# --- Schritte -------------------------------------------------------------------------------------------

func _refresh_all() -> void:
	preview.set_look(look)
	preview.set_expression("happy", 1.2)
	_update_name()
	_fill_step()
	_layout()


func _fill_step() -> void:
	for c in _content.get_children():
		# nicht aus dem Baum nehmen: ein Knopf, der gerade gedrückt wird, hat noch einen Tween (der darf nicht
		# außerhalb des Baums laufen); versteckt nimmt er keinen Platz mehr ein und ist am Ende des Bilds weg
		(c as CanvasItem).visible = false
		c.queue_free()
	_name_edit = null
	_tone_label = null
	_caps.text = "%d von %d" % [step + 1, STEPS]
	for i in _progress.get_child_count():
		var seg: Panel = _progress.get_child(i)
		seg.add_theme_stylebox_override("panel", Style.box(Style.SUN if i <= step else Color(Style.INK, 0.10), 4, 0, 0))
	_back.visible = step > 0
	_next.text = "Weiter"
	match step:
		0:
			_title.text = "Dein Charakter" if edit_mode else "Wer hilft dir beim Erschaffen?"
			_sub.text = "Such dir deinen Gott aus. Du kannst ihn später ändern."
			_step_form()
		1:
			_title.text = "Deine Farben"
			_sub.text = "Tipp auf eine Farbe – %s zeigt sie dir gleich." % String(look["name"])
			_step_colors()
		2:
			_title.text = "Gesicht und Schmuck"
			_sub.text = "Augen, Hut, Brille – ganz wie du magst."
			_step_face()
		3:
			_title.text = "Wie heißt du?"
			_sub.text = "Gib deinem Gott einen Namen."
			_step_name()
			_next.text = "Speichern" if edit_mode else "Fertig – los geht's!"
	_scroll.scroll_vertical = 0
	if is_inside_tree():
		_content.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_content, "modulate:a", 1.0, Style.DUR_IN).set_trans(Style.T_OUT).set_ease(Tween.EASE_OUT)
	_layout()


func _step_form() -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(grid)
	for basis_v in Character.BASE_ORDER:
		var basis: String = basis_v
		var b := Button.new()
		b.toggle_mode = false
		b.custom_minimum_size = Vector2(0, 150)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sel := String(look["basis"]) == basis
		_skin_choice(b, sel, Style.R_TILE + 4)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var lk := Character.default_look(basis)
		if sel:
			lk = look.duplicate(true)
		var cv := CharacterView.make(lk, 108, false, "neutral")
		cv.idle = sel
		cv.bob_px = 2.0
		cv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(cv)
		var bd: Dictionary = Character.BASES[basis]
		var l := _label(String(bd["title"]), Style.F_SLOT + 1, Style.INK if sel else Style.INK_2, Style.W_BOLD)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		v.add_child(l)
		b.pressed.connect(_on_base.bind(basis))
		b.set_meta("pick", "basis:" + basis)
		_press_fx(b)
		grid.add_child(b)
	if not edit_mode:
		var quick := _button("Würfeln und los", "ghost", "dice", 44)
		quick.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		quick.pressed.connect(_on_quick)
		_content.add_child(quick)


func _step_colors() -> void:
	var basis := String(look["basis"])
	for row_v in Character.rows(basis):
		var row: Array = row_v
		var slot := String(row[0])
		_content.add_child(_row_title(String(row[1])))
		_content.add_child(_swatches(slot, String(row[2])))


func _step_face() -> void:
	var basis := String(look["basis"])
	_content.add_child(_row_title("Augen"))
	var eyes := _flow()
	for stil_v in Character.EYE_ORDER:
		var stil: String = stil_v
		var es: Dictionary = Character.EYE_STYLES[stil]
		var chip := _chip(String(es["title"]), String(look["augen"]) == stil, _eye_icon(stil))
		chip.pressed.connect(_on_eyes.bind(stil))
		chip.set_meta("pick", "augen:" + stil)
		eyes.add_child(chip)
	_content.add_child(eyes)
	_content.add_child(_row_title("Augenfarbe"))
	_content.add_child(_swatches("augen", "augen"))
	for slot_v in Character.ACC_SLOTS:
		var slot: String = slot_v
		var no_neck := slot == "hals" and not Character.has_neck(basis)
		var t := String(Character.ACC_TITLE[slot])
		if no_neck:
			t += " · hat %s nicht" % ("die Sonne" if basis == "sonne" else ("die Wolke" if basis == "wolke" else "das Monster"))
		_content.add_child(_row_title(t))
		var fl := _flow()
		for a_v in Character.ACCESSORIES[slot]:
			var ad: Dictionary = a_v
			var id := String(ad["id"])
			var chip := _chip(String(ad["title"]), String(look[slot]) == id, _acc_icon(slot, id) if id != "" else null)
			chip.disabled = no_neck and id != ""
			chip.pressed.connect(_on_acc.bind(slot, id))
			chip.set_meta("pick", "%s:%s" % [slot, id])
			fl.add_child(chip)
		_content.add_child(fl)
	_content.add_child(_row_title("Schmuckfarbe"))
	_content.add_child(_swatches("akzent", "akzent"))


func _step_name() -> void:
	_name_edit = LineEdit.new()
	_name_edit.text = String(look["name"])
	_name_edit.max_length = Character.NAME_MAX
	_name_edit.placeholder_text = NAME_PLACEHOLDER
	_name_edit.custom_minimum_size = Vector2(0, 60)
	_name_edit.add_theme_font_override("font", Style.font_w(Style.W_BOLD))
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.add_theme_color_override("font_color", Style.INK)
	_name_edit.add_theme_color_override("font_placeholder_color", Style.INK_3)
	_name_edit.add_theme_color_override("caret_color", Style.INK)
	var n := Style.box(Style.SURFACE_2, 20, 18, 8)
	var fsb := Style.ring(Style.SURFACE, Style.SUN, 20)
	fsb.content_margin_left = 18
	fsb.content_margin_right = 18
	_name_edit.add_theme_stylebox_override("normal", n)
	_name_edit.add_theme_stylebox_override("focus", fsb)
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _name_edit.release_focus())
	_content.add_child(_name_edit)
	_tone_label = _row_title("Wie soll %s reden?" % String(look["name"]))
	_content.add_child(_tone_label)
	for ton_v in Character.TONES:
		var ton: String = ton_v
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 74)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sel := String(look["ton"]) == ton
		_skin_choice(b, sel, Style.R_ROW)
		var m := MarginContainer.new()
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right"]:
			m.add_theme_constant_override("margin_" + side, 18)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		m.add_child(v)
		v.add_child(_label(String(Character.TONE_TITLE[ton]), Style.F_HEAD, Style.INK, Style.W_BLACK))
		var sample := _label(String(Character.TONE_SAMPLE[ton]), Style.F_SLOT + 1, Style.INK_2, Style.W_BODY)
		sample.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sample.clip_text = true
		v.add_child(sample)
		b.add_child(m)
		b.pressed.connect(_on_tone.bind(ton))
		b.set_meta("pick", "ton:" + ton)
		_press_fx(b)
		_content.add_child(b)


# --- Reaktionen -----------------------------------------------------------------------------------------

func _changed(expr: String = "happy") -> void:
	look = Character.sanitize(look)
	preview.set_look(look)
	preview.set_expression(expr, 1.0)
	preview.react("hop")
	_update_name()
	Style.haptic(Style.HAPTIC_TAP)


func _on_base(basis: String) -> void:
	if basis == String(look["basis"]):
		preview.react("hop")
		return
	look = Character.with_base(look, basis)
	_changed()
	_fill_step()


func _on_quick() -> void:
	look = Character.random(_rng)
	_changed()
	go_to_step(3)


func _on_color(slot: String, key: String) -> void:
	var farben: Dictionary = look["farben"]
	farben[slot] = key
	_changed()
	_fill_step_keep_scroll()


func _on_eyes(stil: String) -> void:
	look["augen"] = stil
	_changed()
	_fill_step_keep_scroll()


func _on_acc(slot: String, id: String) -> void:
	look[slot] = id
	_changed("proud" if id != "" else "happy")
	_fill_step_keep_scroll()


func _on_name_changed(t: String) -> void:
	look["name"] = t
	var shown := Character.sanitize_name(t, String(look["basis"]))
	_name_label.text = shown
	if _tone_label != null:
		_tone_label.text = "Wie soll %s reden?" % shown


func _on_tone(ton: String) -> void:
	look["ton"] = ton
	look = Character.sanitize(look)
	preview.set_look(look)
	var face := {"lieb": "happy", "frech": "cheeky", "streng": "neutral"}
	preview.set_expression(String(face[ton]), 2.4)
	preview.react("nod" if ton == "streng" else "hop")
	preview.talking(true)
	say(String(Character.TONE_SAMPLE[ton]))
	_fill_step_keep_scroll()
	if _name_edit != null:
		_name_edit.text = String(look["name"])


func _on_next() -> void:
	if step < STEPS - 1:
		go_to_step(step + 1)
		preview.react("hop")
		return
	if _name_edit != null:
		look["name"] = _name_edit.text
	look = Character.sanitize(look)
	if autosave:
		Character.save_look(look)
	preview.set_expression("proud", 2.0)
	preview.react("spin")
	finished.emit(look.duplicate(true))


func _on_back() -> void:
	if step > 0:
		go_to_step(step - 1)


func _on_close() -> void:
	cancelled.emit()


func _on_dice_down() -> void:
	_dice_held = 0.0
	_dice_long = false
	set_process(true)


func _on_dice_up() -> void:
	if _dice_long:
		return
	randomize_step()


func _process(delta: float) -> void:
	if _dice != null and _dice.button_pressed and not _dice_long:
		_dice_held += delta
		if _dice_held >= Style.LONG_PRESS:
			_dice_long = true
			randomize_all()


## Würfelt den aktuellen Schritt neu.
func randomize_step() -> void:
	match step:
		0:
			var others: Array = []
			for b in Character.BASE_ORDER:
				if String(b) != String(look["basis"]):
					others.append(b)
			look = Character.with_base(look, String(others[_rng.randi_range(0, others.size() - 1)]))
		1:
			Character.randomize_colors(look, _rng)
		2:
			look["augen"] = Character.EYE_ORDER[_rng.randi_range(0, Character.EYE_ORDER.size() - 1)]
			Character.randomize_accessories(look, _rng)
		3:
			look["ton"] = Character.TONES[_rng.randi_range(0, Character.TONES.size() - 1)]
	_changed()
	_fill_step_keep_scroll()
	if step == 3:
		say(String(Character.TONE_SAMPLE[String(look["ton"])]))
		preview.talking(true)


## Würfelt alles (Name bleibt, wenn er selbst gewählt war).
func randomize_all() -> void:
	var old_name := String(look["name"])
	var old_def := String((Character.BASES[String(look["basis"])] as Dictionary)["name"])
	look = Character.random(_rng, look)
	if old_name != old_def:
		look["name"] = old_name
	_changed()
	preview.react("spin")
	_fill_step()


## Sprechblase über der Vorschau (z. B. die Ton-Probe).
func say(text: String, seconds: float = 3.2) -> void:
	_bubble_gen += 1
	var gen := _bubble_gen
	_bubble_label.text = text
	_bubble.visible = true
	_bubble.modulate.a = 0.0
	_layout_bubble()
	if not is_inside_tree():
		_bubble.modulate.a = 1.0
		return
	_bubble.pivot_offset = Vector2(_bubble.size.x * 0.5, _bubble.size.y)
	_bubble.scale = Vector2(0.9, 0.9)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_bubble, "modulate:a", 1.0, Style.DUR_FAST)
	tw.tween_property(_bubble, "scale", Vector2.ONE, Style.DUR_POP).set_trans(Style.T_POP).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(seconds).timeout
	if gen != _bubble_gen or not is_instance_valid(_bubble):
		return
	var tw2 := create_tween()
	tw2.tween_property(_bubble, "modulate:a", 0.0, Style.DUR_OUT)
	tw2.tween_callback(_bubble.hide)


func _fill_step_keep_scroll() -> void:
	var sv := _scroll.scroll_vertical
	_fill_step()
	_content.modulate.a = 1.0
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = sv


func _update_name() -> void:
	_name_label.text = String(look["name"])


# --- Bausteine ---------------------------------------------------------------------------------------------

func _label(text: String, sz: int, color: Color, weight: int = Style.W_BODY) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Style.font_w(weight))
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _caps_label(text: String, color: Color = Style.INK_3) -> Label:
	var l := _label(text, Style.F_CAPS, color, Style.W_BLACK)
	l.uppercase = true
	l.add_theme_font_override("font", Style.caps())
	return l


func _row_title(text: String) -> Label:
	var l := _caps_label(text, Style.INK_3)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 8)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f


func _swatches(slot: String, palette: String) -> HFlowContainer:
	var f := _flow()
	f.add_theme_constant_override("h_separation", 10)
	var farben: Dictionary = look["farben"]
	var cur := String(farben.get(slot, ""))
	for key_v in Character.palette_keys(palette):
		var key: String = key_v
		var col := Character.palette_color(palette, key)
		var b := Button.new()
		b.custom_minimum_size = Vector2(46, 46)
		var n := Style.hairline(Style.box(col, 23, 0, 0), Color(Style.INK, 0.14))
		var sel := key == cur
		if sel:
			# gewählt: Farbe mit hellem Innenrand und Tinten-Ring außen
			var inner := Style.box(col, 23, 0, 0)
			inner.set_border_width_all(3)
			inner.border_color = Style.SURFACE
			Style.skin(b, inner, inner, Style.INK)
			var ring := Panel.new()
			var rs := StyleBoxFlat.new()
			rs.draw_center = false
			rs.set_corner_radius_all(27)
			rs.set_border_width_all(3)
			rs.border_color = Style.INK
			rs.anti_aliasing = true
			rs.set_expand_margin_all(4)
			ring.add_theme_stylebox_override("panel", rs)
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			b.add_child(ring)
		else:
			Style.skin(b, n, Style.box(col.darkened(0.08), 23, 0, 0), Style.INK)
		b.pressed.connect(_on_color.bind(slot, key))
		b.set_meta("pick", "farbe:%s:%s" % [slot, key])
		_press_fx(b)
		f.add_child(b)
	return f


func _chip(text: String, sel: bool, icon_node: Control) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 48)
	b.text = text
	b.add_theme_font_override("font", Style.font_w(Style.W_BOLD))
	b.add_theme_font_size_override("font_size", Style.F_BODY_S)
	b.add_theme_constant_override("h_separation", 8)
	_skin_choice(b, sel, 24, 14 if icon_node == null else 50)
	if icon_node != null:
		icon_node.position = Vector2(10, 7)
		b.add_child(icon_node)
	_press_fx(b)
	return b


## Auswahl-Kachel: gewählt = Sonnen-Ring, sonst ruhige Fläche.
func _skin_choice(b: Button, sel: bool, radius: int, pad_left: int = 14) -> void:
	var n := Style.box(Style.SURFACE_2, radius, 14, 0)
	n.content_margin_left = pad_left
	var p := Style.box(Style.SURFACE_3, radius, 14, 0)
	p.content_margin_left = pad_left
	var on := Style.ring(Style.SUN_TINT, Style.SUN, radius)
	on.content_margin_left = pad_left
	on.content_margin_right = 14
	var dis := Style.box(Color(Style.SURFACE_2, 0.5), radius, 14, 0)
	dis.content_margin_left = pad_left
	Style.skin(b, on if sel else n, on if sel else p, Style.INK if sel else Style.INK_2, dis)


func _eye_icon(stil: String) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(34, 34)
	c.size = Vector2(34, 34)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var iris := Character.color(look, "augen")
	for k in ["weiss", "iris", "pupille"]:
		var t := _icon_rect(Character.face_file("augen_%s_%s" % [stil, k]), 34)
		if k == "iris":
			t.self_modulate = iris
		c.add_child(t)
	return c


func _acc_icon(slot: String, id: String) -> Control:
	var ad := Character.accessory(slot, id)
	var c := Control.new()
	c.custom_minimum_size = Vector2(34, 34)
	c.size = Vector2(34, 34)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var akz := Character.color(look, "akzent")
	var files: Array = ad.get("files", ad.get("lens", []))
	for fl_v in files:
		var fl: Array = fl_v
		var t := _icon_rect(Character.acc_file(String(fl[0])), 34)
		if slot == "kopf" or slot == "hals":
			# Zubehör ist auf 128 gezeichnet und nutzt etwa die Mitte: größer zeigen
			t.size = Vector2(52, 52)
			t.position = Vector2(-9, -9 + (6 if slot == "kopf" else 0))
		if bool(fl[1]):
			t.self_modulate = akz
		c.add_child(t)
	return c


func _icon_rect(path: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(path):
		t.texture = load(path)
	t.size = Vector2(px, px)
	return t


## Knöpfe: primary (Tinte), secondary (Fläche), glass (schwebend über dem Himmel), ghost (nur Text).
func _button(text: String, variant: String, icon_name: String, h: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_override("font", Style.font_w(Style.W_BOLD))
	b.add_theme_font_size_override("font_size", Style.F_BUTTON if h >= 52 else Style.F_BODY_S)
	b.add_theme_constant_override("h_separation", 8)
	if icon_name != "":
		b.icon = Style.icon(icon_name)
		b.add_theme_constant_override("icon_max_width", 22)
	var r := int(h / 2.0)
	var n: StyleBoxFlat
	var p: StyleBoxFlat
	var fg := Style.INK
	match variant:
		"primary":
			n = Style.lift(Style.box(Style.INK, r, 24, 0), 1)
			p = Style.box(Style.INK_PRESSED, r, 24, 0)
			fg = Color.WHITE
		"secondary":
			n = Style.box(Style.SURFACE_2, r, 22, 0)
			p = Style.box(Style.SURFACE_3, r, 22, 0)
		"glass":
			n = Style.lift(Style.hairline(Style.box(Style.GLASS, r, 16, 0)), 1)
			p = Style.box(Style.SURFACE_3, r, 16, 0)
		_:
			n = Style.box(Color(0, 0, 0, 0), r, 18, 0)
			p = Style.box(Color(Style.INK, 0.06), r, 18, 0)
			fg = Style.INK_2
	Style.skin(b, n, p, fg)
	_press_fx(b)
	return b


func _press_fx(b: BaseButton) -> void:
	b.button_down.connect(func() -> void: _press(b, true))
	b.button_up.connect(func() -> void: _press(b, false))


func _press(b: Control, down: bool) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween()
	if down:
		tw.tween_property(b, "scale", Vector2.ONE * Style.PRESS_SCALE, Style.DUR_PRESS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(b, "scale", Vector2.ONE, Style.DUR_POP).set_trans(Style.T_POP).set_ease(Tween.EASE_OUT)
