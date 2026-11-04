class_name Style
extends RefCounted
## Design-Tokens und reine StyleBox-Bausteine. Keine Knoten, keine Signale, keine Tweens hier.

# --- Flächen & Tinte -----------------------------------------------------------------
const SURFACE := Color("#FBF8F3")                       # Karten, Leisten, Dock, Meldungen
const SURFACE_2 := Color("#F2EDE5")                     # Zweitknöpfe, Listenzeilen
const SURFACE_3 := Color("#E8E1D6")                     # gedrückt (SURFACE_2)
const GLASS := Color(0.984, 0.973, 0.953, 0.94)         # schwebende Leisten über der 3D-Szene
const INK := Color("#1F2430")                           # Titel, Zahlen, Hauptknopf
const INK_2 := Color("#4B5163")                         # Fließtext
const INK_3 := Color("#8A8F9C")                         # Beschriftung, Mikro-Labels
const INK_PRESSED := Color("#353C4D")
const HAIRLINE := Color(0.122, 0.141, 0.188, 0.07)      # 1-px-Kanten, Trenner
const SCRIM := Color(0.122, 0.141, 0.188, 0.40)         # Hintergrund hinter Dialogen
const SHADOW_1 := Color(0.122, 0.141, 0.188, 0.08)
const SHADOW_2 := Color(0.122, 0.141, 0.188, 0.12)
const SHADOW_3 := Color(0.122, 0.141, 0.188, 0.16)

# --- Ein Akzent + Bedeutungsfarben (Grund / Tönung / Schrift auf Tönung) ------------------
const SUN := Color("#F2A93B")
const SUN_TINT := Color("#FDF0DA")
const SUN_DEEP := Color("#B5711A")
const WATER := Color("#3B8EEA")
const WATER_TINT := Color("#E3EFFC")
const WATER_DEEP := Color("#2366B8")
const LEAF := Color("#3FA85F")
const LEAF_TINT := Color("#E2F3E7")
const LEAF_DEEP := Color("#287A43")
const FIRE := Color("#EF5B4C")
const FIRE_TINT := Color("#FDE5E2")
const FIRE_DEEP := Color("#C23A2C")
const MONSOON := Color("#5B74D6")
const MONSOON_TINT := Color("#E7EBFA")
const MONSOON_DEEP := Color("#3B51A8")

# Kachel-Tönung hinter jedem Stufen-Symbol (Index = Stufe 0..9)
const STAGE_TINT := [
	Color("#F1E6D8"), Color("#EAF4DC"), Color("#E1F1E3"), Color("#D9EDDD"), Color("#F6EBDD"),
	Color("#F7E7DA"), Color("#F3E9DF"), Color("#E9ECF3"), Color("#E4E8F1"), Color("#E6E4F3"),
]

# --- Alte Namen (anderer Code nutzt sie noch) ----------------------------------------
const BG := SURFACE
const PANEL := GLASS
const TEXT := INK
const SOFT := INK_3
const GOOD := LEAF
const BAD := FIRE
const ACCENT := INK
const LINE := HAIRLINE

# --- Radien (Pillen: Höhe/2) ------------------------------------------------------------
const R_TILE := 16
const R_ROW := 20
const R_CARD := 24
const R_MODAL := 28
const R_DOCK := 32

# --- Abstände (8-px-Raster) -----------------------------------------------------------
const S1 := 4
const S2 := 8
const S3 := 12
const S4 := 16
const S5 := 20
const S6 := 24
const S7 := 28
const S8 := 32
const MARGIN := 24          # Seitenrand
const TOP_GAP := 20         # sicherer Bereich oben -> Kopfzeile
const BOTTOM_GAP := 28      # Dock -> sicherer Bereich unten
const CONTENT_W := 552      # 600 - 2 * MARGIN: größte Kartenbreite
const DOCK_H := 112
const LANE_Y := 184.0       # + oberer Rand: Meldungsspur unter der Kopfzeile
const BANNER_Y := 280.0     # + oberer Rand: Jubel-Pille

# --- Schrift (Größe, Gewicht) ------------------------------------------------------------
const F_SCORE := 72
const F_TITLE := 26
const F_HEAD := 20
const F_BODY := 18
const F_BODY_S := 16
const F_LABEL := 16
const F_BUTTON := 18
const F_SLOT := 13
const F_CAPS := 12
const W_BODY := 500
const W_LABEL := 650
const W_BOLD := 750
const W_BLACK := 800

# --- Bewegung ------------------------------------------------------------------------------
const DUR_PRESS := 0.08
const DUR_FAST := 0.16
const DUR_OUT := 0.18
const DUR_IN := 0.26
const DUR_MODAL := 0.32
const DUR_POP := 0.35
const DUR_FLY := 0.55
const STAGGER := 0.04
const PRESS_SCALE := 0.94
const T_OUT := Tween.TRANS_QUART      # Standard beim Erscheinen (mit EASE_OUT)
const T_BIG := Tween.TRANS_EXPO       # große Wege: Leisten, Abbrechen-Streifen
const T_POP := Tween.TRANS_BACK       # Aufploppen / Loslassen eines Knopfs
const TOAST_MIN := 2.2
const TOAST_MAX := 4.5
const LONG_PRESS := 0.45
const HOLD_SLOP := 16.0

# --- Vibration (ms) -------------------------------------------------------------------------
const HAPTIC_TAP := 12
const HAPTIC_MERGE := 22
const HAPTIC_COMBO := 34
const HAPTIC_FIRE := 45
const HAPTIC_HOVER := 18

static var haptics_on := true         # vom Schalter „Effekte“

static var _fonts: Dictionary = {}
static var _icons: Dictionary = {}


static func font() -> Font:
	return font_w(W_BODY)


static func bold() -> Font:
	return font_w(W_BOLD)


static func black() -> Font:
	return font_w(W_BLACK)


## Schwere, leicht gesperrte Schrift für Mikro-Labels in Großbuchstaben.
static func caps() -> Font:
	return font_w(W_BLACK, 1)


static func font_w(weight: int, glyph_spacing: int = 0) -> Font:
	var key := "%d_%d" % [weight, glyph_spacing]
	if _fonts.has(key):
		return _fonts[key]
	var f: Font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://fonts/Manrope.ttf"):
		var base: Font = load("res://fonts/Manrope.ttf")
		var fv := FontVariation.new()
		fv.base_font = base
		var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
		fv.variation_opentype = {tag: weight}
		if glyph_spacing != 0:
			fv.set_spacing(TextServer.SPACING_GLYPH, glyph_spacing)
		f = fv
	_fonts[key] = f
	return f


static func icon(name: String) -> Texture2D:
	if _icons.has(name):
		return _icons[name]
	var path := "res://icons/%s.svg" % name
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_icons[name] = tex
	return tex


static func haptic(ms: int) -> void:
	if haptics_on:
		Input.vibrate_handheld(ms)


# --- StyleBox-Bausteine ----------------------------------------------------------------------

static func box(bg: Color, radius: int, pad_h: int = 16, pad_v: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 12 if radius >= 20 else 8
	s.anti_aliasing = true
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


## Höhe: 0 flach, 1 Chip/Knopf, 2 Karte/Dock/Meldung, 3 Dialog/Erklärung/Hinweis.
static func lift(s: StyleBoxFlat, level: int) -> StyleBoxFlat:
	if level <= 0:
		s.shadow_size = 0
		return s
	var sizes := [0, 8, 16, 26]
	var offs := [0, 3, 5, 8]
	var cols := [SHADOW_1, SHADOW_1, SHADOW_2, SHADOW_3]
	var i := clampi(level, 1, 3)
	s.shadow_size = int(sizes[i])
	s.shadow_offset = Vector2(0, float(offs[i]))
	s.shadow_color = cols[i]
	return s


static func hairline(s: StyleBoxFlat, c: Color = HAIRLINE) -> StyleBoxFlat:
	s.set_border_width_all(1)
	s.border_color = c
	return s


## Karte / Leiste / Meldung: SURFACE, Radius, Haarlinie, Schatten.
static func card(radius: int = R_CARD, level: int = 2, pad_h: int = 20, pad_v: int = 18, bg: Color = SURFACE) -> StyleBoxFlat:
	return lift(hairline(box(bg, radius, pad_h, pad_v)), level)


## Leuchtring für „ausgewählt“ (Dock-Platz in Benutzung).
static func ring(bg: Color, ring_color: Color, radius: int) -> StyleBoxFlat:
	var s := box(bg, radius, 0, 0)
	s.set_border_width_all(3)
	s.border_color = ring_color
	s.set_expand_margin_all(3)
	s.shadow_color = Color(ring_color.r, ring_color.g, ring_color.b, 0.35)
	s.shadow_size = 14
	s.shadow_offset = Vector2.ZERO
	return s


## Ein Aussehen für alle Knopf-Zustände. hover == normal mit Absicht (Touch bleibt sonst „hover“).
static func skin(b: Button, normal: StyleBox, pressed: StyleBox, fg: Color, disabled: StyleBox = null) -> void:
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled if disabled != null else normal)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg.r, fg.g, fg.b, 0.4))
