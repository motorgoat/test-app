extends SceneTree
## Kontaktbogen des eigenen Charakters (braucht echtes GL, z. B. unter xvfb-run):
##   xvfb-run -a -s "-screen 0 1800x2000x24" godot --rendering-driver opengl3 --resolution 1700x1900 \
##       --script res://tests/character_sheet.gd -- --sheet=/pfad/charakter.png
## Bild 1: jede Basis x jeder Ausdruck. Bild 2 (_2): Augenformen, Zubehör, Farben, kleine Kopfbilder (40/72 px).
## Bild 3 (_3): der Ersteller (4 Schritte) in Handy-Größe.

const CELL := 230.0
const PAD := 12.0

var _sheet := ""
var _frames := 0
var _page := 0
var _holder: Control


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sheet="):
			_sheet = a.substr(8)
	if _sheet == "":
		_sheet = "user://charakter.png"
	_build_page(0)
	_icon()


## Benachrichtigungs-Bild (256 px, rund) als Probe für CharacterView.render_image
func _icon() -> void:
	await process_frame
	var l := Character.default_look("katze")
	l["kopf"] = "krone"
	var img: Image = await CharacterView.render_image(get_root(), l, "happy", 256, false)
	if img != null:
		img.save_png(_sheet.replace(".png", "_full.png"))
	img = await CharacterView.render_image(get_root(), l, "happy", 256, true, Style.SUN_TINT)
	if img != null:
		var p := _sheet.replace(".png", "_icon.png")
		img.save_png(p)
		print("Bild: ", p)


func _clear() -> void:
	if _holder != null:
		_holder.queue_free()
	_holder = Control.new()
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(_holder)
	var bg := ColorRect.new()
	bg.color = Color("#EEF3F8")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.add_child(bg)


func _label(t: String, pos: Vector2, sz: int = 15) -> void:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.add_theme_font_override("font", Style.font_w(Style.W_BOLD))
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", Style.INK_2)
	_holder.add_child(l)


func _view(l: Dictionary, expr: String, pos: Vector2, px: float, portrait: bool = false) -> CharacterView:
	var card := Panel.new()
	var sb := Style.box(Style.SURFACE, int(px * 0.12) if not portrait else int(px * 0.5), 0, 0)
	card.add_theme_stylebox_override("panel", sb)
	card.position = pos
	card.size = Vector2(px, px)
	_holder.add_child(card)
	var cv := CharacterView.make(l, px, portrait, expr)
	if portrait:
		cv.portrait_bg = Style.SUN_TINT
	cv.idle = false
	cv.position = pos
	_holder.add_child(cv)
	return cv


func _build_page(p: int) -> void:
	_clear()
	_page = p
	_frames = 0
	if p == 0:
		_label("Basis x Ausdruck (Standardfarben, Ton lieb)", Vector2(PAD, 6), 20)
		for c in Character.EXPRESSION_ORDER.size():
			_label(String(Character.EXPRESSION_ORDER[c]), Vector2(PAD + 110 + c * CELL, 40))
		for r in Character.BASE_ORDER.size():
			var basis: String = Character.BASE_ORDER[r]
			_label(basis, Vector2(PAD, 70 + r * CELL + CELL * 0.5))
			var l := Character.default_look(basis)
			for c in Character.EXPRESSION_ORDER.size():
				_view(l, String(Character.EXPRESSION_ORDER[c]), Vector2(PAD + 100 + c * CELL, 64 + r * CELL), CELL - 12)
	elif p == 1:
		_label("Augen, Zubehör, Farben · unten: Kopfbilder 72 px und 40 px", Vector2(PAD, 6), 20)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var heads := ["krone", "heiligenschein", "blumenkranz", "zauberhut", "schleife", "", ""]
		var faces := ["", "rundbrille", "", "sonnenbrille", "", "monokel", "rundbrille"]
		var necks := ["fliege", "", "schal", "", "amulett", "fliege", "schal"]
		for r in Character.BASE_ORDER.size():
			var basis: String = Character.BASE_ORDER[r]
			for c in 7:
				var l := Character.default_look(basis)
				if c > 0:
					Character.randomize_colors(l, rng)
				l["augen"] = Character.EYE_ORDER[c % 4]
				l["kopf"] = heads[(c + r) % 7]
				l["gesicht"] = faces[(c + r * 2) % 7]
				l["hals"] = necks[(c + r) % 7] if Character.has_neck(basis) else ""
				var fk: Array = Character.palette_keys("akzent")
				l["farben"]["akzent"] = fk[(c + r) % fk.size()]
				var ek: Array = Character.palette_keys("augen")
				l["farben"]["augen"] = ek[(c * 2 + r) % ek.size()]
				var ex: String = ["neutral", "happy", "cheeky", "proud", "neutral", "worried", "sleepy"][c]
				_view(l, ex, Vector2(PAD + 100 + c * CELL * 0.85, 40 + r * CELL * 0.85), CELL * 0.85 - 10)
			_label(basis, Vector2(PAD, 40 + r * CELL * 0.85 + 90))
		var y0 := 50.0 + 6 * CELL * 0.85
		for i in Character.BASE_ORDER.size():
			var l2 := Character.default_look(String(Character.BASE_ORDER[i]))
			_view(l2, "neutral", Vector2(PAD + 100 + i * 180, y0), 72, true)
			_view(l2, "happy", Vector2(PAD + 100 + i * 180 + 84, y0 + 16), 40, true)
			_view(l2, "neutral", Vector2(PAD + 100 + i * 180 + 84 + 46, y0 + 16), 40, false)
	else:
		_label("Ersteller", Vector2(PAD, 6), 20)
		for s in 4:
			var holder := SubViewportContainer.new()
			holder.position = Vector2(PAD + s * 430, 40)
			holder.stretch = false
			holder.size = Vector2(600, 1300)
			holder.scale = Vector2(0.7, 0.7)
			_holder.add_child(holder)
			var vp := SubViewport.new()
			vp.size = Vector2i(600, 1300)
			holder.add_child(vp)
			var cc := CharacterCreator.new()
			cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			vp.add_child(cc)
			var l3 := Character.default_look(["katze", "bart", "goettin", "nudel"][s])
			l3["kopf"] = ["krone", "", "blumenkranz", "zauberhut"][s]
			l3["hals"] = ["fliege", "", "", ""][s]
			cc.open(l3, false)
			cc.go_to_step(s)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 12:
		var img := get_root().get_texture().get_image()
		var path := _sheet if _page == 0 else _sheet.replace(".png", "_%d.png" % (_page + 1))
		img.save_png(path)
		print("Bild: ", path)
		if _page < 2:
			_build_page(_page + 1)
		else:
			quit(0)
	return false
