class_name Style
extends RefCounted
## Schrift, Symbole und Farben der Oberfläche an einer Stelle.

const BG := Color("#fffaf3")
const PANEL := Color(1.0, 0.985, 0.96, 0.96)
const TEXT := Color("#2f3442")
const SOFT := Color("#7a8091")
const GOOD := Color("#34a853")
const BAD := Color("#e5483c")
const ACCENT := Color("#3f86e8")
const LINE := Color("#ebe4d8")

static var _font: Font
static var _bold: Font
static var _icons: Dictionary = {}


static func font() -> Font:
	if _font == null:
		_font = _variant(600)
	return _font


static func bold() -> Font:
	if _bold == null:
		_bold = _variant(850)
	return _bold


static func _variant(weight: int) -> Font:
	var base: Font = null
	if ResourceLoader.exists("res://fonts/Nunito.ttf"):
		base = load("res://fonts/Nunito.ttf")
	if base == null:
		return ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = base
	var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	fv.variation_opentype = {tag: weight}
	return fv


static func icon(name: String) -> Texture2D:
	if _icons.has(name):
		return _icons[name]
	var path := "res://icons/%s.svg" % name
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_icons[name] = tex
	return tex


static func nation_color(n: int) -> Color:
	if n < 0:
		return SOFT
	return Color(GameState.NATION_COLORS[n])
