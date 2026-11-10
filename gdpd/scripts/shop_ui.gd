class_name ShopUI
extends Node
## Der Laden (docs/GDPD_PUNKTE_LADEN.md 5, 7): eine Karte mit 4 Reitern (Wunder · Hilfe · Gott · Welten), Karten mit
## Preis und Vorrat, Kauf immer mit Bestätigung (vorher → nachher), Gott-Teile probiert man an und kann sie
## zurückgeben, solange der Laden offen ist. Nichts aus späteren Leveln steht im Laden (Game.shop_items).
## Baut auf den Bausteinen von GameUI auf. Kennt keine Preise: alles kommt aus Game.

var ui: GameUI
var card: PanelContainer
var points_num: Label
var tabs: HBoxContainer
var tab_btns: Dictionary = {}
var grid: GridContainer
var god_box: VBoxContainer
var god_view: CharacterView
var god_act: Button
var god_back: Button
var hint_row: HBoxContainer
var empty_line: Label
var tab := "wunder"
var items: Array = []            # die Karten des Reiters: [{"btn", "item"}]
var _try := ""                    # Gott: das Teil, das gerade anprobiert wird ("" = keins)
var _bought_here: Array = []      # in dieser Sitzung gekaufte Gott-Teile (zurückgeben geht, solange der Laden offen ist)

# Kauf-Bestätigung (ein Blatt, wie die anderen Dialoge)
var confirm: PanelContainer
var cf_tile: PanelContainer
var cf_title: Label
var cf_line: Label
var cf_steps: Label
var cf_buy: Button
var cf_no: Button
var cf_why: Label
var _cf_id := ""
var _cf_then: Callable = Callable()
var _cf_lock := false
var last_error := ""              # Tour: warum der letzte Kauf nicht ging


func build(owner_ui: GameUI) -> void:
	ui = owner_ui
	name = "Shop"
	card = ui._modal_card("Laden", true)
	var v: VBoxContainer = card.get_meta("body")
	# Punkte-Chip unter dem Titel
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", ui._chip_style(Style.SUN_TINT, 22))
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pc)
	var ph := ui._hbox(6)
	pc.add_child(ph)
	ph.add_child(ui._icon("points", 28))
	points_num = ui._label("0", 22, Style.SUN_DEEP, Style.W_BLACK)
	points_num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(points_num)
	ui._explain_only(pc, "points")
	# Reiter
	tabs = ui._hbox(6)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(tabs)
	for t in Game.SHOP_TABS:
		var b := Button.new()
		b.text = str((t as Array)[1])
		b.icon = Style.icon(str((t as Array)[2]))
		b.add_theme_constant_override("icon_max_width", 22)
		b.add_theme_constant_override("h_separation", 4)
		b.add_theme_font_override("font", Style.font_w(Style.W_BOLD))
		b.add_theme_font_size_override("font_size", 15)
		b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(show_tab.bind(str((t as Array)[0])))
		ui._press_fx(b)
		tabs.add_child(b)
		tab_btns[str((t as Array)[0])] = b
	# Gott: groß der eigene Gott (Anprobieren), darunter die Teile – scrollt bei Bedarf
	var inner := ui._modal_scroll(card, 300.0)
	god_box = ui._vbox(8)
	inner.add_child(god_box)
	var gh := ui._hbox(0)
	gh.alignment = BoxContainer.ALIGNMENT_CENTER
	god_box.add_child(gh)
	god_view = ui._figure(120)
	god_view.allow_shop = true
	gh.add_child(god_view)
	# Karten (2 Spalten)
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	inner.add_child(grid)
	empty_line = ui._label("", 15, Style.INK_3, Style.W_LABEL)
	empty_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(empty_line)
	god_act = ui._button("", "primary", "", 56)
	god_act.pressed.connect(_on_god_act)
	v.add_child(god_act)
	god_back = ui._button("Zurückgeben", "ghost", "", 44)
	god_back.pressed.connect(_on_god_refund)
	v.add_child(god_back)
	# Wie man Punkte bekommt (7.3): Level · Serie (Weiterbauen gibt es nicht mehr, Build 12)
	hint_row = ui._hbox(14)
	hint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(hint_row)
	for p in [["star", "Level"], ["streak", "Serie"]]:
		var h := ui._hbox(4)
		h.add_child(ui._icon(str(p[0]), 20))
		var l := ui._label(str(p[1]), 14, Style.INK_3, Style.W_LABEL)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		hint_row.add_child(h)
	_build_confirm()


func _build_confirm() -> void:
	confirm = ui._modal_card("", false)
	var v: VBoxContainer = confirm.get_meta("body")
	(confirm.get_meta("title") as Label).visible = false
	cf_tile = ui._tile("rain", 84, Style.SUN_TINT, 0.4)
	cf_tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(cf_tile)
	cf_title = ui._label("", 24, Style.INK, Style.W_BLACK)
	cf_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cf_title)
	cf_line = ui._label("", 20, Style.SUN_DEEP, Style.W_BLACK)
	cf_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cf_line)
	cf_steps = ui._label("Zählt 2 Schritte", 16, Style.INK_2, Style.W_LABEL)
	cf_steps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cf_steps)
	cf_why = ui._label("", 16, Style.FIRE_DEEP, Style.W_BOLD)
	cf_why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cf_why)
	var row := ui._hbox(10)
	v.add_child(row)
	cf_buy = ui._button("Kaufen", "primary", "points", 58)
	cf_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cf_buy.pressed.connect(_on_confirm_buy)
	row.add_child(cf_buy)
	cf_no = ui._button("Nein", "secondary", "", 58)
	cf_no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cf_no.pressed.connect(_on_confirm_no)
	row.add_child(cf_no)


func is_open() -> bool:
	return card != null and card.visible and card.modulate.a > 0.05


## Den Laden öffnen (Reiter: "wunder" | "hilfe" | "gott" | "welten").
func open(t: String = "wunder") -> void:
	_try = ""
	_bought_here = []
	if not Game.coach_seen.has("shop_hello"):
		Game.coach_seen["shop_hello"] = true
		Game.save_settings()
		Game.message.emit("Dein Laden. Nur Schönes.", "info")
	show_tab(t)
	ui._open_modal(card)


func show_tab(t: String) -> void:
	tab = t
	for k in tab_btns:
		var b: Button = tab_btns[k]
		var on := str(k) == t
		var n := Style.box(Style.INK if on else Style.SURFACE_2, 23, 12, 0)
		Style.skin(b, n, Style.box(Style.INK_PRESSED if on else Style.SURFACE_3, 23, 12, 0), Color.WHITE if on else Style.INK_2)
	_fill()
	if card.visible:
		ui._fit_modal(card)
		card.size = Vector2.ZERO
		card.reset_size()
		card.position = ((ui._vs() - card.size) * 0.5).round()


func _fill() -> void:
	points_num.text = str(Game.points)
	for c in grid.get_children():
		c.queue_free()
	items = []
	var list := Game.shop_items(tab)
	var god := tab == "gott"
	god_box.visible = god
	god_act.visible = god
	god_back.visible = false
	if god:
		var lk := Game.character.duplicate(true) if not Game.character.is_empty() else Character.default_look("bart")
		if _try != "":
			lk[Character.shop_slot(_try)] = _try
		god_view.set_look(lk)
	for it in list:
		var b := _item_card(it as Dictionary)
		grid.add_child(b)
		items.append({"btn": b, "item": it})
	empty_line.visible = list.is_empty()
	empty_line.text = "Bald mehr"
	hint_row.visible = not god
	var ids: Array = []
	for it in list:
		ids.append(str((it as Dictionary)["id"]))
	if god:
		_fill_god_act()
	get_tree().create_timer(1.2).timeout.connect(Game.mark_shop_seen.bind(ids))


func _item_card(it: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2((Style.CONTENT_W - 56 - 10 - GameUI.MODAL_SCROLL_PAD) * 0.5 - 4, 140)
	b.focus_mode = Control.FOCUS_NONE
	var worn := bool(it.get("worn", false))
	var tried := str(it["id"]) == _try
	var nsb := Style.box(Style.SURFACE_2, 22, 10, 10)
	if worn or tried:
		nsb.border_color = Style.LEAF if worn else Style.SUN
		nsb.set_border_width_all(3)
	Style.skin(b, nsb, Style.box(Style.SURFACE_3, 22, 10, 10), Style.INK)
	b.set_meta("id", str(it["id"]))
	b.pressed.connect(_on_item.bind(str(it["id"])))
	ui._press_fx(b)
	var v := ui._vbox(4)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 10
	v.offset_bottom = -10
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	if bool(it.get("part", false)):
		var lk := Game.character.duplicate(true) if not Game.character.is_empty() else Character.default_look("bart")
		for sl in Character.ACC_SLOTS:
			lk[sl] = ""
		lk[str(it["slot"])] = str(it["id"])
		var holder := ui._hbox(0)
		holder.alignment = BoxContainer.ALIGNMENT_CENTER
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(holder)
		var cv := CharacterView.make(lk, 64, true, "happy")
		cv.allow_shop = true
		cv.set_look(lk)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(cv)
	else:
		var tl := ui._tile(str(it["icon"]), 60, ui._tint_for_icon(str(it["icon"])), 0.32)
		tl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(tl)
	var t := ui._label(str(it["title"]), 16, Style.INK, Style.W_BOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var row := ui._hbox(4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	if bool(it.get("locked", false)):
		row.add_child(ui._icon("lock", 20))
		b.disabled = true
		return b
	var price := int(it["price"])
	var lab := ""
	var col := Style.INK
	if bool(it.get("part", false)) and bool(it.get("owned", false)):
		lab = "Angelegt" if worn else "✔ Hast du"
		col = Style.LEAF_DEEP
	elif bool(it.get("full", false)):
		lab = "Vorrat voll"
		col = Style.INK_3
	else:
		row.add_child(ui._icon("points", 20))
		lab = str(price)
		col = Style.INK if Game.points >= price else Style.INK_3
	var pl := ui._label(lab, 16, col, Style.W_BLACK)
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pl)
	var have := int(it.get("have", 0))
	if not bool(it.get("part", false)) and have > 0:
		var hb := ui._label("x%d" % have, 15, Style.WATER_DEEP, Style.W_BLACK)
		hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(hb)
	if bool(it.get("new", false)):
		var dot := Panel.new()
		dot.add_theme_stylebox_override("panel", Style.box(Style.FIRE, 7, 0, 0))
		dot.size = Vector2(14, 14)
		dot.position = Vector2(b.custom_minimum_size.x - 24, 10)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(dot)
	return b


func card_of(id: String) -> Button:
	for e in items:
		if str((e as Dictionary)["item"]["id"]) == id:
			return (e as Dictionary)["btn"]
	return null


func _item(id: String) -> Dictionary:
	for e in items:
		if str((e as Dictionary)["item"]["id"]) == id:
			return (e as Dictionary)["item"]
	return {}


func _on_item(id: String) -> void:
	var it := _item(id)
	if it.is_empty():
		return
	if bool(it.get("part", false)):
		# Anprobieren: der Gott freut sich; der Knopf unten kauft, legt an oder ab
		_try = id
		_fill()
		god_view.set_expression("happy", 2.0)
		god_view.react("hop")
		return
	if bool(it.get("full", false)):
		ui._shake(card_of(id))
		return
	ask(id)


func _fill_god_act() -> void:
	god_back.visible = false
	if _try == "":
		god_act.text = "Tipp ein Teil an"
		god_act.disabled = true
		god_act.modulate.a = 0.5
		return
	god_act.disabled = false
	god_act.modulate.a = 1.0
	var it := _item(_try)
	if bool(it.get("owned", false)):
		god_act.text = "Ablegen" if bool(it.get("worn", false)) else "Anlegen"
		god_back.visible = _bought_here.has(_try)
	else:
		var price := int(it.get("price", 0))
		god_act.text = "Kaufen · %d ✦" % price if Game.points >= price else "Dir fehlen %d ✦" % (price - Game.points)
		god_act.modulate.a = 1.0 if Game.points >= price else 0.55


func _on_god_act() -> void:
	if _try == "":
		return
	var it := _item(_try)
	if bool(it.get("owned", false)):
		Game.wear(_try, not bool(it.get("worn", false)))
		ui.refresh_speakers()
		_fill()
		god_view.set_expression("proud", 2.0)
		god_view.react("spin")
		return
	ask(_try)


func _on_god_refund() -> void:
	if _try != "" and Game.refund(_try):
		_bought_here.erase(_try)
		ui.refresh_speakers()
		_fill()


## Die Kauf-Bestätigung (immer): Bild, „Regen kaufen?“, ✦ vorher → nachher, im Level „Zählt 2 Schritte“.
## then: nach dem Kauf (z. B. das Wunder gleich benutzen); ohne: zurück in den Laden.
func ask(id: String, then: Callable = Callable()) -> void:
	_cf_id = id
	_cf_then = then
	_cf_lock = false
	var price := Game.shop_price(id)
	var slot := Character.shop_slot(id)
	var icon := str((Game.SHOP_ITEMS[id] as Array)[2]) if Game.SHOP_ITEMS.has(id) else "profile"
	ui._set_tile(cf_tile, icon, ui._tint_for_icon(icon) if slot == "" else Style.SUN_TINT)
	cf_title.text = "%s kaufen?" % Game.shop_title(id)
	cf_line.text = "✦ %d → %d" % [Game.points, Game.points - price]
	var miracle := Game.SHOP_ITEMS.has(id) and str((Game.SHOP_ITEMS[id] as Array)[0]) == "wunder"
	cf_steps.visible = miracle and Game.in_day() and Game.state != null and not Game.state.day_won
	var ok := Game.points >= price
	cf_why.visible = not ok
	cf_why.text = "Dir fehlen %d ✦" % (price - Game.points)
	cf_buy.disabled = not ok
	cf_buy.modulate.a = 1.0 if ok else 0.5
	cf_buy.text = "Kaufen"
	ui._open_modal(confirm, true)


func _on_confirm_buy() -> void:
	if _cf_lock:
		return              # doppeltes Tippen kauft nie zweimal
	_cf_lock = true
	var err := Game.buy(_cf_id)
	last_error = err
	if err != "":
		cf_why.text = err
		cf_why.visible = true
		ui._shake(cf_buy)
		_cf_lock = false
		return
	Style.haptic(Style.HAPTIC_COMBO)
	var id := _cf_id
	var said := str((Game.SHOP_ITEMS[id] as Array)[6]) if Game.SHOP_ITEMS.has(id) else "Steht dir!"
	if not Game.SHOP_ITEMS.has(id):
		_bought_here.append(id)
		Game.wear(id, true)
		ui.refresh_speakers()
	var then := _cf_then
	_cf_then = Callable()
	ui._close_modal(true)
	Game.message.emit(said, "reward")
	if then.is_valid():
		then.call()
		return
	_fill()
	ui._open_modal(card)
	var b := card_of(id)
	if b != null:
		ui._pop(b, 1.1)
		ui._ripple(b, Style.SUN)


func _on_confirm_no() -> void:
	var then := _cf_then
	_cf_then = Callable()
	ui._close_modal(true)
	if then.is_valid():
		return              # aus dem Dock: zurück ins Level
	ui._open_modal(card)
