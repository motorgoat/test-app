class_name CharacterView
extends Control
## Zeigt den eigenen Charakter aus Ebenen (Spec 3.8): Körperteile, Gesicht mit Ausdruck, Zubehör, Farben.
## Funktioniert klein (Kopfbild in der Sprechblase, 40 px, portrait = true) und groß (Ersteller, Jubel, 240 px).
## Nimmt nie Berührungen an (alle Ebenen MOUSE_FILTER_IGNORE).
##
##   var cv := CharacterView.new()
##   cv.custom_minimum_size = Vector2(240, 240)
##   cv.set_look(Character.load_look())
##   cv.set_expression("happy", 1.5)      # 1,5 s froh, dann wieder das Ruhegesicht
##   cv.react("hop")                      # hop | shake | spin | nod
##   cv.look_at_point(get_global_mouse_position())
##   cv.talking(true)

signal expression_changed(expression: String)

const C := 256.0
const FEET := Vector2(128, 236)

## Nur den Kopf zeigen (Ausschnitt aus Character.BASES[...]["portrait"]), z. B. in Sprechblasen.
@export var portrait := false:
	set(v):
		portrait = v
		_update_clip()
		_fit()
## Kopfbild rund ausschneiden (sonst eckig).
@export var portrait_round := true:
	set(v):
		portrait_round = v
		_update_clip()
## Hintergrund des Kopfbilds (durchsichtig = nur Ausschnitt).
@export var portrait_bg := Color(0, 0, 0, 0):
	set(v):
		portrait_bg = v
		_update_clip()
## Kopfbild-Ausschnitt: < 1 zeigt mehr (z. B. 0,85, damit Krone und Ohren ganz drauf sind).
@export var portrait_zoom := 1.0:
	set(v):
		portrait_zoom = maxf(0.2, v)
		_fit()
## Leerlauf-Bewegung (Blinzeln, Wippen, Strahlen …). Aus für ruhige Bilder (Benachrichtigungs-Bild, Tests).
@export var idle := true
## Wie stark der Charakter wippt (Leinwand-Pixel).
@export var bob_px := 3.0

var look: Dictionary = {}
var expression := "neutral"

static var _cache: Dictionary = {}

var _rig: Control               # Leinwand 256 x 256, skaliert auf die Größe des Knotens
var _body: Control              # Wippen, Stauchen, Schütteln (Drehpunkt: Füße)
var _spinner: Control           # Drehen (Drehpunkt: Mitte)
var _parts: Array = []          # [{node, anim, pivot}]
var _eyes: Array = []           # je Auge: {root, white, iris, pupil, lid, closed, brow, blush, center}
var _mouth: TextureRect
var _glasses: Array = []
var _extra: Dictionary = {}     # funkeln, schweiss, zzz
var _acc: Dictionary = {}       # Platz -> [TextureRect]
var _halo: TextureRect
var _bd: Dictionary = {}

var _t := 0.0
var _hold := -1.0
var _blink_in := 3.0
var _blink_left := 0.0
var _blink_again := false
var _talk_left := 0.0
var _talk_phase := 0.0
var _talk_open := false
var _look_target := Vector2.ZERO        # -1..1
var _look_now := Vector2.ZERO
var _look_set := false
var _swing := 0.0
var _twitch := 0.0

# von Tweens bewegt
var squash := Vector2.ONE
var jump := 0.0
var shake := 0.0
var spin := 0.0
var nod := 0.0
var _react_tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_rig = _plain("Rig", self)
	_body = _plain("Body", _rig)
	_body.pivot_offset = FEET
	_spinner = _plain("Spin", _body)
	_blink_in = randf_range(1.5, 4.0)


func _ready() -> void:
	resized.connect(_fit)
	if look.is_empty():
		set_look(Character.default_look("bart"))
	_fit()


## Erzeugt eine fertige Ansicht in einer festen Größe.
static func make(l: Dictionary, px: float, as_portrait: bool = false, expr: String = "neutral") -> CharacterView:
	var cv := CharacterView.new()
	cv.custom_minimum_size = Vector2(px, px)
	cv.size = Vector2(px, px)
	cv.portrait = as_portrait
	cv.set_look(l)
	cv.set_expression(expr)
	return cv


## Rendert den Charakter in ein Bild (z. B. das große Benachrichtigungs-Bild, 5.6). Koroutine:
##   var img: Image = await CharacterView.render_image(self, look, "happy", 256)
## host: irgendein Knoten im Baum. Ohne echte Grafik (headless) kommt null zurück.
static func render_image(host: Node, l: Dictionary, expr: String = "happy", px: int = 256, as_portrait: bool = true,
		bg: Color = Color(0, 0, 0, 0), zoom: float = 0.82) -> Image:
	if host == null or not host.is_inside_tree() or DisplayServer.get_name() == "headless":
		return null
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cv := CharacterView.make(l, float(px), as_portrait, expr)
	cv.idle = false
	cv.portrait_bg = bg
	cv.portrait_zoom = zoom
	vp.add_child(cv)
	host.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	return img


# --- Aussehen ---------------------------------------------------------------------------------------------

func set_look(l: Dictionary) -> void:
	look = Character.sanitize(l)
	_bd = Character.base(look)
	for c in _spinner.get_children():
		_spinner.remove_child(c)
		c.queue_free()
	_parts.clear()
	_eyes.clear()
	_glasses.clear()
	_extra.clear()
	_acc.clear()
	_halo = null
	var basis := String(look["basis"])
	# Körper
	var part_defs: Array = _bd["parts"]
	for pd_v in part_defs:
		var pd: Dictionary = pd_v
		var id := String(pd["id"])
		var slot := String(pd["slot"])
		var nodes: Array = []
		if slot == "":
			nodes.append(_layer(Character.DIR + basis + "/" + id + ".svg", Vector2(C, C), Vector2(128, 128)))
		else:
			var tf := _layer(Character.DIR + basis + "/" + id + "_f.svg", Vector2(C, C), Vector2(128, 128))
			tf.self_modulate = Character.color(look, slot)
			nodes.append(tf)
			if pd.get("l", false):
				nodes.append(_layer(Character.DIR + basis + "/" + id + "_l.svg", Vector2(C, C), Vector2(128, 128)))
		var pv: Array = pd.get("pivot", [128, 128])
		for n in nodes:
			var tr: TextureRect = n
			tr.pivot_offset = Vector2(float(pv[0]), float(pv[1]))
			_parts.append({"node": tr, "anim": String(pd.get("anim", ""))})
	# Gesicht
	var fs := float(_bd["face_scale"])
	var fb := Character.FACE_BOX * fs
	var stil := String(look["augen"])
	var lid_col := Character.color(look, String(_bd["lid"]))
	var iris_col := Character.color(look, "augen")
	var centers := _eye_centers()
	for i in 2:
		var root := _plain("Eye%d" % i, _spinner)
		root.position = centers[i]
		var e := {"root": root, "center": centers[i]}
		if _bd.has("blush"):
			# feste Wangen (Nudel: auf dem Knäuel, nicht auf den Stielen)
			var bp: Array = _bd["blush"]
			e["blush"] = _layer(Character.face_file("wangen"), Vector2(fb, fb), _v(bp[i]))
			e["blush_fixed"] = true
		else:
			e["blush"] = _layer(Character.face_file("wangen"), Vector2(fb, fb), Vector2.ZERO, root)
		e["white"] = _layer(Character.face_file("augen_%s_weiss" % stil), Vector2(fb, fb), Vector2.ZERO, root)
		e["iris"] = _layer(Character.face_file("augen_%s_iris" % stil), Vector2(fb, fb), Vector2.ZERO, root)
		(e["iris"] as TextureRect).self_modulate = iris_col
		e["pupil"] = _layer(Character.face_file("augen_%s_pupille" % stil), Vector2(fb, fb), Vector2.ZERO, root)
		e["lid"] = _layer(Character.face_file("lid_muede_" + stil), Vector2(fb, fb), Vector2.ZERO, root)
		(e["lid"] as TextureRect).self_modulate = lid_col
		e["closed"] = _layer(Character.face_file("augen_%s_zu" % stil), Vector2(fb, fb), Vector2.ZERO, root)
		if i == 1:
			for k in ["blush", "white", "iris", "pupil", "lid", "closed"]:
				(e[k] as TextureRect).flip_h = true
		_eyes.append(e)
	# Brille liegt über den Augen, unter den Brauen
	var gid := String(look["gesicht"])
	if gid != "":
		_glasses = _glasses_layers(gid, centers)
		_acc["gesicht"] = _glasses
	for i in 2:
		var e: Dictionary = _eyes[i]
		var broot := _plain("Brow%d" % i, _spinner)
		broot.position = centers[i]
		e["broot"] = broot
		e["brow"] = _layer(Character.face_file("brauen_neutral"), Vector2(fb, fb), Vector2.ZERO, broot)
		if i == 1:
			(e["brow"] as TextureRect).flip_h = true
	_mouth = _layer(Character.face_file("mund_neutral"), Vector2(fb, fb), _v(_bd["mouth"]))
	# Extras
	var pr: Array = _bd["portrait"]
	var pc := Vector2(float(pr[0]), float(pr[1]))
	var r := float(pr[2])
	var fl := _layer(Character.face_file("funkeln"), Vector2(r * 2.1, r * 2.1), pc)
	_extra["funkeln"] = fl
	var fc := _v(_bd["face"])
	var gap := float(_bd["eye_gap"])
	_extra["schweiss"] = _layer(Character.face_file("schweiss"), Vector2(fb, fb) * 0.8, fc + Vector2(gap * 0.5 + 24, -20) * fs)
	_extra["zzz"] = _layer(Character.face_file("zzz"), Vector2(64, 64) * maxf(1.0, r / 90.0), pc + Vector2(r * 0.66, -r * 0.6))
	# Zubehör Kopf und Hals
	for slot in ["kopf", "hals"]:
		var aid := String(look[slot])
		if aid != "" and (slot != "hals" or Character.has_neck(basis)):
			_acc[slot] = _acc_layers(slot, aid)
	if String(look["kopf"]) == "heiligenschein":
		var hl: Array = _acc["kopf"]
		_halo = hl[0]
	_apply_expression()
	_fit()


func _eye_centers() -> Array:
	if _bd.has("eyes"):
		var es: Array = _bd["eyes"]
		return [_v(es[0]), _v(es[1])]
	var fc := _v(_bd["face"])
	var g := float(_bd["eye_gap"]) * 0.5
	return [fc + Vector2(-g, 0), fc + Vector2(g, 0)]


func _acc_layers(slot: String, id: String) -> Array:
	var ad := Character.accessory(slot, id)
	var out: Array = []
	if ad.is_empty():
		return out
	var anchor_key := String(Character.ACC_ANCHOR[slot])
	if not _bd.has(anchor_key):
		return out
	var a := _v(_bd[anchor_key])
	if ad.get("float", false) and _bd.has("float_top"):
		a = _v(_bd["float_top"])
	var sc := Vector2.ONE
	match slot:
		"kopf":
			sc = Vector2.ONE * float(_bd["head_scale"])
		"hals":
			sc = Vector2.ONE * float(_bd.get("neck_scale", 1.0))
	var y := float(ad.get("y", 0.0))
	var center := a + Vector2(0, y * sc.y)
	var akz := Character.color(look, "akzent")
	for fl_v in ad.get("files", []):
		var fl: Array = fl_v
		var tr := _layer(Character.acc_file(String(fl[0])), Vector2(Character.ACC_BOX, Character.ACC_BOX), center)
		tr.scale = sc
		if bool(fl[1]):
			tr.self_modulate = akz
		out.append(tr)
	return out


## Brille: ein Glas je Auge (passt sich der Augenform an), Steg dazwischen.
func _glasses_layers(id: String, centers: Array) -> Array:
	var ad := Character.accessory("gesicht", id)
	var out: Array = []
	if ad.is_empty():
		return out
	var fs := float(_bd["face_scale"])
	var es_d: Dictionary = Character.EYE_STYLES[String(look["augen"])]
	var k := fs * maxf(1.0, (maxf(float(es_d["rx"]), float(es_d["ry"])) + 2.5) / 14.0)
	var akz := Character.color(look, "akzent")
	var box := Vector2(Character.FACE_BOX, Character.FACE_BOX)
	var c0: Vector2 = centers[0]
	var c1: Vector2 = centers[1]
	var right_only := bool(ad.get("right_only", false))
	if ad.has("bridge"):
		var span := c0.distance_to(c1) - 2.0 * Character.LENS_R * k + 6.0
		for fl_v in ad["bridge"]:
			var fl: Array = fl_v
			var tr := _layer(Character.acc_file(String(fl[0])), box, (c0 + c1) * 0.5)
			tr.scale = Vector2(maxf(0.15, span / 24.0), fs)
			if bool(fl[1]):
				tr.self_modulate = akz
			out.append(tr)
	for i in 2:
		if right_only and i == 0:
			continue
		for fl_v in ad.get("lens", []):
			var fl: Array = fl_v
			var tr := _layer(Character.acc_file(String(fl[0])), box, centers[i])
			tr.scale = Vector2(k, k)
			tr.flip_h = i == 1 and not right_only
			if bool(fl[1]):
				tr.self_modulate = akz
			out.append(tr)
	return out


# --- Ausdruck ---------------------------------------------------------------------------------------------

## e: neutral | happy | proud | worried | sad | sleepy | cheeky. hold > 0: nach so vielen Sekunden zurück zum
## Ruhegesicht (neutral im Ton des Charakters).
func set_expression(e: String, hold: float = 0.0) -> void:
	if not Character.EXPRESSIONS.has(e):
		e = "neutral"
	var changed := e != expression
	expression = e
	_hold = hold if hold > 0.0 else -1.0
	_blink_left = 0.0
	_apply_expression()
	if changed:
		expression_changed.emit(e)


func get_expression() -> String:
	return expression


func _expr() -> Dictionary:
	var ed: Dictionary = (Character.EXPRESSIONS[expression] as Dictionary).duplicate()
	if expression == "neutral":
		var rest: Dictionary = Character.TONE_REST.get(String(look.get("ton", "lieb")), {})
		for k in rest:
			ed[k] = rest[k]
	return ed


func _apply_expression() -> void:
	if _eyes.is_empty():
		return
	var ed := _expr()
	var stil := String(look["augen"])
	var es_d: Dictionary = Character.EYE_STYLES[stil]
	var ry := float(es_d["ry"])
	var fs := float(_bd["face_scale"])
	var eye_k := float(ed.get("eye_scale", 1.0))
	var iris_k := float(ed.get("iris_scale", 1.0))
	var eyes_mode := String(ed.get("eyes", "open"))
	var lid := String(ed.get("lid", ""))
	var brows: Array = ed.get("brows", ["neutral", "neutral"])
	var extras: Array = ed.get("extras", [])
	var lift := float(ed.get("brow_lift", 0.0))
	var blinking := _blink_left > 0.0
	for i in 2:
		var e: Dictionary = _eyes[i]
		var mode := eyes_mode
		if i == 1 and ed.has("right"):
			mode = String(ed["right"])
		if blinking and mode == "open":
			mode = "zu"
		var open := mode == "open"
		for k in ["white", "iris", "pupil"]:
			var tr: TextureRect = e[k]
			tr.visible = open
			tr.scale = Vector2.ONE * eye_k * (iris_k if k != "white" else 1.0)
		var closed: TextureRect = e["closed"]
		closed.visible = not open
		if not open:
			closed.texture = _tex(Character.face_file("augen_%s_%s" % [stil, mode]))
		closed.scale = Vector2.ONE * eye_k
		var lt: TextureRect = e["lid"]
		lt.visible = open and lid != ""
		if lt.visible:
			lt.texture = _tex(Character.face_file("lid_%s_%s" % [lid, stil]))
			lt.scale = Vector2.ONE * eye_k
		var bt: TextureRect = e["brow"]
		bt.texture = _tex(Character.face_file("brauen_" + String(brows[i])))
		bt.position = Vector2(0, -(ry * eye_k + 9.0 + lift) * fs) - bt.size * 0.5
		var bl: TextureRect = e["blush"]
		bl.visible = extras.has("wangen")
		var side := -1.0 if i == 0 else 1.0
		if not e.has("blush_fixed"):
			bl.position = Vector2(side * 7.0, ry * eye_k + 8.0) * fs - bl.size * 0.5
	_set_mouth(String(ed.get("mouth", "neutral")))
	for k in _extra:
		(_extra[k] as TextureRect).visible = extras.has(k)


func _set_mouth(m: String) -> void:
	if _mouth != null:
		_mouth.texture = _tex(Character.face_file("mund_" + m))


# --- Bewegung -----------------------------------------------------------------------------------------------

## hop (Hüpfer), shake (Kopfschütteln), spin (einmal drehen), nod (Nicken).
func react(kind: String) -> void:
	if _react_tween != null and _react_tween.is_valid():
		_react_tween.kill()
	squash = Vector2.ONE
	jump = 0.0
	shake = 0.0
	nod = 0.0
	spin = 0.0
	if kind == "hop":
		_swing = 1.0
	if not is_inside_tree():
		return
	var tw := create_tween()
	_react_tween = tw
	match kind:
		"hop":
			_swing = 1.0
			tw.tween_property(self, "squash", Vector2(1.1, 0.9), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(self, "squash", Vector2(0.92, 1.08), 0.1).set_trans(Tween.TRANS_QUAD)
			tw.parallel().tween_property(self, "jump", -16.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(self, "jump", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(self, "squash", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"shake":
			for x in [6.0, -6.0, 4.0, -3.0, 0.0]:
				tw.tween_property(self, "shake", x, 0.06)
		"spin":
			tw.tween_property(self, "spin", TAU, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func() -> void: spin = 0.0)
		"nod":
			for a in [5.0, -2.0, 4.0, 0.0]:
				tw.tween_property(self, "nod", deg_to_rad(a), 0.1)


## Mund bewegt sich beim Sprechen (die ersten 1,2 s einer Sprechblase).
func talking(on: bool) -> void:
	_talk_left = 1.2 if on else 0.0
	_talk_phase = 0.0
	if not on:
		_talk_open = false
		_apply_expression()


func blink() -> void:
	_blink_left = 0.12
	_twitch = 1.0
	_apply_expression()


## Die Augen schauen zu einem Punkt (globale Koordinaten).
func look_at_point(p: Vector2) -> void:
	if _eyes.is_empty():
		return
	var local := _spinner.get_global_transform().affine_inverse() * p
	var mid := (_eyes[0]["center"] as Vector2 + _eyes[1]["center"] as Vector2) * 0.5
	var d := local - mid
	look_dir(d / maxf(40.0, d.length()))


## Blickrichtung -1..1 (x nach rechts, y nach unten).
func look_dir(v: Vector2) -> void:
	_look_target = v.limit_length(1.0)
	_look_set = true


func look_center() -> void:
	_look_set = false
	_look_target = Vector2.ZERO


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if _hold > 0.0:
		_hold -= delta
		if _hold <= 0.0:
			_hold = -1.0
			set_expression("neutral")
	# Blinzeln
	if idle:
		if _blink_left > 0.0:
			_blink_left -= delta
			if _blink_left <= 0.0:
				_apply_expression()
				if _blink_again:
					_blink_again = false
					_blink_in = 0.14
		else:
			_blink_in -= delta
			if _blink_in <= 0.0:
				var ed: Dictionary = Character.EXPRESSIONS[expression]
				if String(ed.get("eyes", "open")) == "open" and not ed.has("lid"):
					blink()
					_blink_again = randf() < 0.15
				_blink_in = randf_range(2.5, 6.0)
	# Sprechen
	if _talk_left > 0.0:
		_talk_left -= delta
		_talk_phase += delta
		var want := int(_talk_phase / 0.14) % 2 == 0
		if _talk_left <= 0.0:
			want = false
		if want != _talk_open:
			_talk_open = want
			if _talk_left > 0.0:
				_set_mouth("lachen" if want else "laecheln")
			else:
				_apply_expression()
	# Blick
	var lt := _look_target
	if not _look_set:
		var lv: Array = Character.EXPRESSIONS[expression].get("look", [0.0, 0.0])
		lt = Vector2(float(lv[0]), float(lv[1]))
	_look_now = _look_now.lerp(lt, clampf(delta * 10.0, 0.0, 1.0))
	var off := _look_now * Character.IRIS_MOVE * float(_bd.get("face_scale", 1.0))
	for e_v in _eyes:
		var e: Dictionary = e_v
		for k in ["iris", "pupil"]:
			var tr: TextureRect = e[k]
			tr.position = off - tr.size * 0.5
	_animate(delta)


func _animate(delta: float) -> void:
	var t := _t if idle else 0.0
	var bob := sin(t * TAU / 2.4) * bob_px
	var breathe := 1.0 + 0.015 * sin(t * TAU / 2.4 + 0.6)
	var drift := 0.0
	if String(look.get("basis", "")) == "wolke":
		drift = sin(t * TAU / 4.2) * 4.0
	_body.position = Vector2(drift + shake, bob + jump)
	_body.scale = Vector2(squash.x, squash.y * breathe)
	_body.rotation = nod
	_spinner.pivot_offset = _portrait_center()
	_spinner.rotation = spin
	_swing = move_toward(_swing, 0.0, delta * 1.4)
	_twitch = move_toward(_twitch, 0.0, delta * 6.0)
	for p_v in _parts:
		var p: Dictionary = p_v
		var n: TextureRect = p["node"]
		match String(p["anim"]):
			"spin":
				n.rotation = deg_to_rad(6.0) * t
			"sway":
				n.rotation = sin(t * TAU / 3.2) * deg_to_rad(8.0)
			"wiggle":
				n.rotation = sin(t * TAU / 2.2) * deg_to_rad(3.0)
			"drift":
				n.position = Vector2(sin(t * TAU / 4.2 + 1.7) * 5.0, 0.0)
			"twitch":
				n.scale = Vector2(1.0, 1.0 - 0.06 * _twitch)
			"talk":
				n.rotation = sin(t * 28.0) * deg_to_rad(2.0) if _talk_left > 0.0 else 0.0
			"swing":
				n.rotation = sin(_swing * 14.0) * _swing * deg_to_rad(4.0)
	if _halo != null:
		var base_y: float = _halo.get_meta("y0", _halo.position.y)
		if not _halo.has_meta("y0"):
			_halo.set_meta("y0", base_y)
		_halo.position.y = base_y + sin(t * TAU / 2.0) * 2.0
	var fl: TextureRect = _extra.get("funkeln")
	if fl != null and fl.visible:
		fl.modulate.a = 0.75 + 0.25 * sin(t * 5.0)
	var zz: TextureRect = _extra.get("zzz")
	if zz != null and zz.visible:
		zz.modulate.a = 0.55 + 0.45 * sin(t * 2.0)


func _update_clip() -> void:
	var round_clip := portrait and portrait_round
	clip_contents = portrait and not portrait_round
	if round_clip:
		clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW if portrait_bg.a > 0.0 else CanvasItem.CLIP_CHILDREN_ONLY
	else:
		clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
	queue_redraw()


func _draw() -> void:
	if not portrait:
		return
	var side := minf(size.x, size.y)
	if portrait_round:
		var col := portrait_bg if portrait_bg.a > 0.0 else Color.WHITE
		draw_circle(size * 0.5, side * 0.5, col)
	elif portrait_bg.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), portrait_bg)


# --- Größe ---------------------------------------------------------------------------------------------------

func _portrait_center() -> Vector2:
	if _bd.is_empty():
		return Vector2(128, 128)
	var pr: Array = _bd["portrait"]
	return Vector2(float(pr[0]), float(pr[1]))


func _fit() -> void:
	if _rig == null:
		return
	queue_redraw()
	var s := size
	if s.x <= 0.0 or s.y <= 0.0:
		s = custom_minimum_size
	var side := minf(s.x, s.y)
	if side <= 0.0:
		return
	if portrait and not _bd.is_empty():
		var pr: Array = _bd["portrait"]
		var k := side / (2.0 * float(pr[2]) / portrait_zoom)
		_rig.scale = Vector2(k, k)
		_rig.position = s * 0.5 - Vector2(float(pr[0]), float(pr[1])) * k
	else:
		var k := side / C
		_rig.scale = Vector2(k, k)
		_rig.position = (s - Vector2(C, C) * k) * 0.5
	_animate(0.0)


# --- Bausteine -------------------------------------------------------------------------------------------------

func _plain(n: String, parent: Control) -> Control:
	var c := Control.new()
	c.name = n
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(C, C)
	parent.add_child(c)
	return c


## Eine Bildebene mit Mitte center (in Leinwand-Einheiten des Elternknotens).
func _layer(path: String, box: Vector2, center: Vector2, parent: Control = null) -> TextureRect:
	var t := TextureRect.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture = _tex(path)
	t.size = box
	t.position = center - box * 0.5
	t.pivot_offset = box * 0.5
	(parent if parent != null else _spinner).add_child(t)
	return t


static func _v(a: Variant) -> Vector2:
	var arr: Array = a
	return Vector2(float(arr[0]), float(arr[1]))


static func _tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		push_warning("Charakter-Teil fehlt: " + path)
	_cache[path] = tex
	return tex
