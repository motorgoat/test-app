class_name Voice
extends RefCounted
## Die Stimme des eigenen Charakters (docs/GDPD_TAEGLICH_CHARAKTER.md 4): Satz im Ton des Charakters
## (lieb / frech / streng) und das passende Gesicht. Die Sätze stehen in CharacterTexts; hier kommen Ton, Name und
## „nie zweimal hintereinander derselbe Satz“ dazu (je Schlüssel).
##
##   Voice.line("win_3")                       # „Drei Sterne?! Okay, du darfst ein bisschen angeben.“ (frech)
##   Voice.line("day_open", {"tag": "Tag 3: Tiere"})
##   Voice.face("miss")                        # „worried“
##   Voice.day_coach(2, 1, fallback)           # Tages-Hinweis von Tag 2, Satz 1 (Feuer-Warnung)

static var _last: Dictionary = {}       # Schlüssel -> zuletzt gesagter Satz


## Ton des Charakters ("lieb", wenn es noch keinen gibt).
static func tone() -> String:
	var c: Dictionary = _character()
	var t := str(c.get("ton", "lieb"))
	return t if Character.TONES.has(t) else "lieb"


## Name des Charakters (Standard der Grundform, „Gott“ ohne Charakter).
static func char_name() -> String:
	var c: Dictionary = _character()
	if c.is_empty():
		return ReminderPlan.DEFAULT_NAME
	return str(c.get("name", ReminderPlan.DEFAULT_NAME))


## Ein Satz im Ton des Charakters, Platzhalter gefüllt ({name} immer). "" für unbekannte Schlüssel.
static func line(key: String, args: Dictionary = {}) -> String:
	var a := args.duplicate()
	if not a.has("name"):
		a["name"] = char_name()
	var s := CharacterTexts.line(key, tone(), a, null, str(_last.get(key, "")))
	_last[key] = s
	return s


static func has(key: String) -> bool:
	return CharacterTexts.LINES.has(key)


## Gesicht zu einem Schlüssel (neutral, wenn keins festgelegt ist).
static func face(key: String) -> String:
	return CharacterTexts.face(key)


## Tages-Hinweis: Satz i von Tag n (coach), "demo" (coach_demo) oder "tool" (coach_tool) im Ton des Charakters.
## Gibt es keine Fassung im Ton, bleibt der Satz der Tagestabelle (fallback).
static func day_key(n: int, which: Variant) -> String:
	if which is String:
		return "d%d_%s" % [n, str(which)]
	return "d%d_c%d" % [n, int(which)]


static func day_coach(n: int, which: Variant, fallback: String) -> String:
	var k := day_key(n, which)
	if not has(k):
		return fallback
	var s := line(k)
	return s if s != "" else fallback


static func day_face(n: int, which: Variant) -> String:
	return face(day_key(n, which))


## Lobt beim Wachsen (zufällig, nie zweimal derselbe).
static func praise() -> String:
	return line("praise")


static func _character() -> Dictionary:
	var g: Node = Engine.get_main_loop().root.get_node_or_null("Game") if Engine.get_main_loop() is SceneTree else null
	if g != null:
		var c: Variant = g.get("character")
		if c is Dictionary:
			return c as Dictionary
	return {}
