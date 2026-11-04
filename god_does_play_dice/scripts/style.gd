class_name Style
extends RefCounted
## Schrift, Symbole und Farben der Oberfläche an einer Stelle.

const BG := Color("#f7f4ef")
const PANEL := Color(1.0, 1.0, 1.0, 0.94)
const TEXT := Color("#1e222b")
const SOFT := Color("#8b909b")
const GOOD := Color("#2f9e5b")
const BAD := Color("#d6453b")
const ACCENT := Color("#1e222b")
const WATER := Color("#2f8fd8")
const LINE := Color("#e7e2da")

static var _font: Font
static var _bold: Font
static var _icons: Dictionary = {}


static func font() -> Font:
	if _font == null:
		_font = _variant(500)
	return _font


static func bold() -> Font:
	if _bold == null:
		_bold = _variant(760)
	return _bold


static func _variant(weight: int) -> Font:
	var base: Font = null
	if ResourceLoader.exists("res://fonts/Manrope.ttf"):
		base = load("res://fonts/Manrope.ttf")
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
