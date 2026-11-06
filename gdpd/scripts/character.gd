class_name Character
extends RefCounted
## Der eigene Charakter (Spec: docs/GDPD_TAEGLICH_CHARAKTER.md, Abschnitt 3). Nur Daten, keine Knoten.
##
## Ein Aussehen („look“) ist ein Dictionary wie im Spielstand-Abschnitt [charakter]:
##   {"version": 1, "basis": "katze", "farben": {"haupt": "f1", "haut": "h2", "haar": "braun", "akzent": "gold",
##    "augen": "gruen"}, "augen": "gross", "kopf": "krone", "gesicht": "", "hals": "fliege", "name": "Miez",
##    "ton": "lieb", "bilder": 0}
## Farben sind Schlüssel in einer Palette (stabil, wenn die Hex-Werte später verfeinert werden).
## Die Teile liegen in icons/character/ (erzeugt von tools/character_art.py).

const VERSION := 1
const SAVE_PATH := "user://charakter.cfg"
const SECTION := "charakter"
const DIR := "res://icons/character/"
const NAME_MAX := 12
const CANVAS := 256.0                 # Leinwand der Körperteile
const FACE_BOX := 64.0                # Leinwand der Gesichtsteile (Mitte = Anker)
const ACC_BOX := 128.0                # Leinwand des Zubehörs (Mitte = Anker)
const LENS_R := 17.0                  # Radius eines Brillenglases (Gesichtseinheiten)

const SLOTS := ["haupt", "haut", "haar", "akzent", "augen"]
const TONES := ["lieb", "frech", "streng"]
const TONE_TITLE := {"lieb": "Lieb", "frech": "Frech", "streng": "Streng"}
const TONE_SAMPLE := {
	"lieb": "Schön, dass du da bist!",
	"frech": "Na endlich! Los geht's!",
	"streng": "Gut. Fangen wir an.",
}

# --- Paletten (3.4): Schlüssel -> Farbe -------------------------------------------------------------
const PALETTES := {
	"haupt": {"sonne": "#F2A93B", "himmel": "#3B8EEA", "blatt": "#3FA85F", "feuer": "#EF5B4C", "lavendel": "#C9B5F0",
		"nacht": "#5B74D6", "wolke": "#F4F1EA", "rosa": "#F4A7B9"},
	"haut": {"h1": "#FBE3CC", "h2": "#F1C7A0", "h3": "#D9A27A", "h4": "#B57A54", "h5": "#8A5636", "h6": "#5E3A24"},
	"haar": {"weiss": "#F4F1EA", "silber": "#C9CCD3", "blond": "#F2D27A", "rot": "#B5592E", "braun": "#6B4428",
		"schwarz": "#2B2B33", "lila": "#9B7AD8", "blau": "#3B8EEA"},
	"akzent": {"gold": "#F2A93B", "silber": "#C9CCD3", "rubin": "#EF5B4C", "smaragd": "#3FA85F", "saphir": "#3B8EEA",
		"rosa": "#F4A7B9"},
	"augen": {"braun": "#6B4428", "blau": "#3B8EEA", "gruen": "#3FA85F", "grau": "#6E7480", "gold": "#B5711A"},
	# eigene Paletten einzelner Basen (Schlüssel f1, f2 …)
	"kern": {"f1": "#FFD88A", "f2": "#FFE9B8", "f3": "#F7B9A8", "f4": "#F2A93B"},
	"fell": {"f1": "#F2A93B", "f2": "#C9CCD3", "f3": "#6B4428", "f4": "#2B2B33", "f5": "#F4F1EA"},
	"nudeln": {"f1": "#F3D27A", "f2": "#C99A5B", "f3": "#7CB36B", "f4": "#C85A7C"},
	"baellchen": {"f1": "#8A4B2E", "f2": "#B5592E", "f3": "#6B4428"},
}

const BASE_ORDER := ["bart", "goettin", "sonne", "wolke", "katze", "nudel"]

## Pro Basis:
## - parts: Ebenen von hinten nach vorn. slot = Farbe, die das Teil tönt ("" = feste Farben). l = es gibt *_l.svg.
##   anim: "spin" (Strahlen), "sway" (Schwanz, Nudeln), "talk" (Bart wackelt beim Reden), "swing" (Haare beim Hüpfen)
## - face: Mitte zwischen den Augen; eye_gap: Abstand der Augen; face_scale: Größe der Gesichtsteile
## - eyes: optionale feste Augenpositionen (Nudel: auf den Stielen); blush: feste Wangen
## - mouth, head_top (+ head_scale), neck (+ neck_scale; fehlt = kein Halszubehör)
## - portrait: [cx, cy, r] Ausschnitt für kleine Kopfbilder (Sprechblase)
## - rows: Farbreihen im Schritt „Deine Farben“ (slot, Beschriftung, Palette)
## - lid: Farbe der Augenlider (müde/traurig)
const BASES := {
	"bart": {
		"title": "Bart-Gott", "name": "Barti",
		"parts": [
			{"id": "haar_hinten", "slot": "haar", "l": true},
			{"id": "robe", "slot": "haupt", "l": true},
			{"id": "haende", "slot": "haut"},
			{"id": "kopf", "slot": "haut", "l": true},
			{"id": "bart", "slot": "haar", "l": true, "anim": "talk", "pivot": [128, 120]},
			{"id": "haar_vorne", "slot": "haar"},
		],
		"face": [128, 104], "eye_gap": 50.0, "face_scale": 1.0, "mouth": [128, 138],
		"head_top": [128, 30], "head_scale": 1.0, "neck": [128, 196], "neck_scale": 0.9,
		"portrait": [128, 112, 84],
		"rows": [["haupt", "Farbe", "haupt"], ["haut", "Haut", "haut"], ["haar", "Haare", "haar"]],
		"lid": "haut",
		"default": {"haupt": "wolke", "haut": "h2", "haar": "weiss"},
	},
	"goettin": {
		"title": "Göttin", "name": "Lumi",
		"parts": [
			{"id": "haar_lang", "slot": "haar", "l": true, "anim": "swing", "pivot": [128, 60]},
			{"id": "kleid", "slot": "haupt", "l": true},
			{"id": "haende", "slot": "haut"},
			{"id": "kopf", "slot": "haut"},
			{"id": "pony", "slot": "haar", "l": true},
		],
		"face": [128, 120], "eye_gap": 50.0, "face_scale": 1.0, "mouth": [128, 146],
		"head_top": [128, 36], "head_scale": 0.95, "neck": [128, 160], "neck_scale": 0.85,
		"portrait": [128, 116, 80],
		"rows": [["haupt", "Farbe", "haupt"], ["haut", "Haut", "haut"], ["haar", "Haare", "haar"]],
		"lid": "haut",
		"default": {"haupt": "lavendel", "haut": "h3", "haar": "braun"},
	},
	"sonne": {
		"title": "Sonne", "name": "Sonni",
		"parts": [
			{"id": "strahlen", "slot": "haar", "anim": "spin", "pivot": [128, 132]},
			{"id": "scheibe", "slot": "haupt"},
			{"id": "glanz", "slot": ""},
		],
		"face": [128, 126], "eye_gap": 54.0, "face_scale": 1.1, "mouth": [128, 160],
		"head_top": [128, 30], "head_scale": 1.05,
		"portrait": [128, 132, 106],
		"rows": [["haupt", "Kern", "kern"], ["haar", "Strahlen", "haupt"]],
		"lid": "haupt",
		"default": {"haupt": "f1", "haar": "sonne"},
	},
	"wolke": {
		"title": "Wolke", "name": "Wolki",
		"parts": [
			{"id": "woelkchen", "slot": "haar", "anim": "drift"},
			{"id": "wolke", "slot": "haupt"},
			{"id": "bauch", "slot": ""},
		],
		"face": [128, 134], "eye_gap": 54.0, "face_scale": 1.05, "mouth": [128, 164],
		"head_top": [128, 40], "head_scale": 1.0,
		"portrait": [128, 134, 92],
		"rows": [["haupt", "Wolke", "haupt"], ["haar", "Wölkchen", "haupt"]],
		"lid": "haupt",
		"default": {"haupt": "wolke", "haar": "himmel"},
	},
	"katze": {
		"title": "Katzengott", "name": "Miez",
		"parts": [
			{"id": "schwanz", "slot": "haupt", "anim": "sway", "pivot": [166, 226]},
			{"id": "koerper", "slot": "haupt", "l": true},
			{"id": "ohren", "slot": "haupt", "l": true, "anim": "twitch", "pivot": [128, 96]},
			{"id": "kopf", "slot": "haupt"},
			{"id": "muster", "slot": "haar"},
			{"id": "schnauze", "slot": ""},
			{"id": "schnurrhaare", "slot": ""},
		],
		"face": [128, 112], "eye_gap": 58.0, "face_scale": 1.0, "mouth": [128, 151],
		"head_top": [128, 40], "head_scale": 0.95, "neck": [128, 168], "neck_scale": 0.85,
		"portrait": [128, 108, 86],
		"rows": [["haupt", "Fell", "fell"], ["haar", "Muster", "haar"]],
		"lid": "haupt",
		"default": {"haupt": "f1", "haar": "braun"},
	},
	"nudel": {
		"title": "Spaghettimonster", "name": "Nudelchen",
		"parts": [
			{"id": "nudeln_hinten", "slot": "haupt", "anim": "wiggle", "pivot": [128, 170]},
			{"id": "stiele", "slot": "haupt", "anim": "stalks", "pivot": [128, 112]},
			{"id": "knaeuel", "slot": "haupt", "l": true},
			{"id": "baellchen", "slot": "haar", "l": true},
		],
		"face": [128, 56], "eye_gap": 64.0, "face_scale": 0.95, "mouth": [128, 156],
		"eyes": [[96, 56], [160, 56]], "blush": [[98, 156], [158, 156]],
		"head_top": [128, 84], "head_scale": 0.8, "float_top": [128, 22],
		"portrait": [128, 112, 96],
		"rows": [["haupt", "Nudeln", "nudeln"], ["haar", "Bällchen", "baellchen"]],
		"lid": "haupt",
		"default": {"haupt": "f1", "haar": "f1"},
	},
}

# --- Gesicht (3.5) ----------------------------------------------------------------------------------
## Augenform: Halbachsen des Augenweiß (für Lider, Brauen, Wangen) in Gesichtseinheiten.
const EYE_STYLES := {
	"rund": {"title": "Rund", "rx": 11.5, "ry": 11.5},
	"oval": {"title": "Oval", "rx": 9.5, "ry": 13.0},
	"gross": {"title": "Groß", "rx": 14.5, "ry": 14.5},
	"schmal": {"title": "Schmal", "rx": 13.0, "ry": 8.5},
}
const EYE_ORDER := ["rund", "oval", "gross", "schmal"]
const IRIS_MOVE := 3.0                # so weit wandert die Iris beim Hinschauen

## Ausdrücke. eyes: open | froh | zu; right: Abweichung rechtes Auge (zwinker); lid: muede | traurig;
## eye_scale/iris_scale: große Augen bei Sorge; brows: [links, rechts]; extras: wangen, funkeln, schweiss, zzz.
const EXPRESSIONS := {
	"neutral": {"eyes": "open", "brows": ["neutral", "neutral"], "mouth": "neutral"},
	"happy": {"eyes": "froh", "brows": ["hoch", "hoch"], "mouth": "lachen", "extras": ["wangen"], "brow_lift": 3.0},
	"proud": {"eyes": "froh", "brows": ["neutral", "neutral"], "mouth": "stolz", "extras": ["funkeln", "wangen"]},
	"worried": {"eyes": "open", "eye_scale": 1.15, "iris_scale": 0.8, "brows": ["sorge", "sorge"], "mouth": "sorge",
		"extras": ["schweiss"], "brow_lift": 2.0},
	"sad": {"eyes": "open", "lid": "traurig", "brows": ["sorge", "sorge"], "mouth": "traurig", "look": [0.0, 1.0]},
	"sleepy": {"eyes": "open", "lid": "muede", "brows": ["neutral", "neutral"], "mouth": "o", "extras": ["zzz"],
		"look": [0.0, 1.0]},
	"cheeky": {"eyes": "open", "right": "zwinker", "brows": ["streng", "hoch"], "mouth": "frech", "look": [-0.6, 0.0]},
}
const EXPRESSION_ORDER := ["neutral", "happy", "proud", "worried", "sad", "sleepy", "cheeky"]
## Ruhegesicht je Ton (lieb lächelt, streng schaut ernst).
const TONE_REST := {
	"lieb": {"mouth": "laecheln"},
	"frech": {"mouth": "stolz"},
	"streng": {"brows": ["streng", "streng"]},
}

# --- Zubehör (3.6) --------------------------------------------------------------------------------
## files: [Datei, getönt?]; anchor: head_top | face | neck; float: schwebt (Heiligenschein).
## y: Versatz vom Anker (Zubehör-Einheiten, vor der Skalierung).
const ACCESSORIES := {
	"kopf": [
		{"id": "", "title": "Keins"},
		{"id": "krone", "title": "Krone", "files": [["krone_f", true], ["krone_l", false]]},
		{"id": "heiligenschein", "title": "Heiligenschein", "files": [["heiligenschein", false]], "float": true, "y": -6.0},
		{"id": "blumenkranz", "title": "Blumenkranz", "files": [["blumenkranz", false]], "y": -8.0},
		{"id": "zauberhut", "title": "Zauberhut", "files": [["zauberhut_f", true], ["zauberhut_l", false]], "y": -6.0},
		{"id": "schleife", "title": "Schleife", "files": [["schleife_f", true], ["schleife_l", false]], "y": 2.0},
	],
	# Gesicht: lens = ein Glas je Auge (rechts gespiegelt), bridge = Steg in der Mitte; right_only: nur rechts
	"gesicht": [
		{"id": "", "title": "Keins"},
		{"id": "rundbrille", "title": "Brille", "lens": [["rundbrille_glas_f", true], ["rundbrille_glas_l", false]],
			"bridge": [["rundbrille_steg_f", true]]},
		{"id": "sonnenbrille", "title": "Sonnenbrille", "lens": [["sonnenbrille_glas", false]],
			"bridge": [["sonnenbrille_steg", false]]},
		{"id": "monokel", "title": "Monokel", "lens": [["monokel_f", true], ["monokel_l", false]], "right_only": true},
	],
	"hals": [
		{"id": "", "title": "Keins"},
		{"id": "fliege", "title": "Fliege", "files": [["fliege_f", true]]},
		{"id": "schal", "title": "Schal", "files": [["schal_f", true], ["schal_l", false]]},
		{"id": "amulett", "title": "Amulett", "files": [["amulett_band", false], ["amulett_f", true], ["amulett_l", false]], "y": -10.0},
	],
}
const ACC_SLOTS := ["kopf", "gesicht", "hals"]
const ACC_ANCHOR := {"kopf": "head_top", "gesicht": "face", "hals": "neck"}
const ACC_TITLE := {"kopf": "Auf dem Kopf", "gesicht": "Im Gesicht", "hals": "Am Hals"}


## Gesicht für die n-te Sprechblase ohne eigenen Ausdruck (3.5): frech zwinkert bei jeder dritten.
static func idle_face(ton: String, bubble_index: int) -> String:
	if ton == "frech" and bubble_index % 3 == 2:
		return "cheeky"
	return "neutral"


# --- Aussehen bauen -------------------------------------------------------------------------------------

static func base(look: Dictionary) -> Dictionary:
	var b := String(look.get("basis", "bart"))
	return BASES.get(b, BASES["bart"])


static func default_look(basis: String = "bart") -> Dictionary:
	if not BASES.has(basis):
		basis = "bart"
	var bd: Dictionary = BASES[basis]
	var d: Dictionary = bd["default"]
	var farben := {"haupt": "wolke", "haut": "h2", "haar": "weiss", "akzent": "gold", "augen": "braun"}
	for k in d:
		farben[k] = d[k]
	return {
		"version": VERSION, "basis": basis, "farben": farben, "augen": "rund",
		"kopf": "", "gesicht": "", "hals": "", "name": String(bd["name"]), "ton": "lieb", "bilder": 0,
	}


## Ein neues Aussehen mit anderer Basis, das die passenden Wahlen behält (Augen, Zubehör, Name, Ton).
static func with_base(look: Dictionary, basis: String) -> Dictionary:
	var out := default_look(basis)
	var old := sanitize(look)
	for k in ["augen", "kopf", "gesicht", "ton", "bilder"]:
		out[k] = old[k]
	out["hals"] = old["hals"] if has_neck(basis) else ""
	var of: Dictionary = old["farben"]
	var nf: Dictionary = out["farben"]
	nf["akzent"] = of["akzent"]
	nf["augen"] = of["augen"]
	# Name nur behalten, wenn er selbst gewählt war (nicht der Standardname der alten Basis)
	var oname := String(old["name"])
	var odef := String((BASES[String(old["basis"])] as Dictionary)["name"])
	if oname != odef:
		out["name"] = oname
	return sanitize(out)


## Zufälliges, stimmiges Aussehen (Standardname der Basis). from: Ton von dort übernehmen.
static func random(rng: RandomNumberGenerator, from: Dictionary = {}) -> Dictionary:
	var basis: String = BASE_ORDER[rng.randi_range(0, BASE_ORDER.size() - 1)]
	var look := default_look(basis)
	randomize_colors(look, rng)
	look["augen"] = EYE_ORDER[rng.randi_range(0, EYE_ORDER.size() - 1)]
	randomize_accessories(look, rng)
	if not from.is_empty():
		look["ton"] = String(from.get("ton", "lieb"))
	return sanitize(look)


## Zufällige Farben (Würfel). Nie zweimal (fast) dieselbe Farbe in einem Aussehen (sonst verschwindet z. B. das
## Muster im gleich braunen Fell) – solange die Palette eine andere hat. Verglichen wird die Farbe, nicht der Name
## (Fell „f3“ und Haar „braun“ sind dasselbe Braun).
static func randomize_colors(look: Dictionary, rng: RandomNumberGenerator) -> void:
	var farben: Dictionary = look.get("farben", {})
	var used: Array = []
	for row in rows(String(look.get("basis", "bart"))):
		var pal := String(row[2])
		var keys := palette_keys(pal)
		var free: Array = []
		for k in keys:
			if not _near_any(palette_color(pal, String(k)), used):
				free.append(k)
		var pool: Array = free if not free.is_empty() else keys
		var picked := String(pool[rng.randi_range(0, pool.size() - 1)])
		farben[String(row[0])] = picked
		used.append(palette_color(pal, picked))
	look["farben"] = farben


## Gleicht Platz slot (fast) einem anderen Platz, bekommt er die Farbe seiner Palette, die sich am meisten abhebt.
## Für Plätze, die der Spieler (noch) nicht selbst gewählt hat. Gibt true, wenn sich etwas geändert hat.
static func make_distinct(look: Dictionary, slot: String) -> bool:
	var others: Array = []
	var pal := ""
	for row in rows(String(look.get("basis", "bart"))):
		if String(row[0]) == slot:
			pal = String(row[2])
		else:
			others.append(color(look, String(row[0])))
	if pal == "" or not _near_any(color(look, slot), others):
		return false
	var best := ""
	var best_d := -1.0
	for k in palette_keys(pal):
		var d := 99.0
		for o in others:
			d = minf(d, _color_dist(palette_color(pal, String(k)), o as Color))
		if d > best_d:
			best_d = d
			best = String(k)
	var farben: Dictionary = look.get("farben", {})
	farben[slot] = best
	look["farben"] = farben
	return true


static func _color_dist(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


static func _near_any(c: Color, list: Array) -> bool:
	for o in list:
		if _color_dist(c, o as Color) < 0.12:
			return true
	return false


static func randomize_accessories(look: Dictionary, rng: RandomNumberGenerator) -> void:
	var basis := String(look.get("basis", "bart"))
	var farben: Dictionary = look.get("farben", {})
	# Meist schlicht: je Platz 45 % Chance auf ein Teil
	for slot in ACC_SLOTS:
		var opts := accessory_ids(slot, basis)
		look[slot] = opts[rng.randi_range(1, opts.size() - 1)] if opts.size() > 1 and rng.randf() < 0.45 else ""
	var ak := palette_keys("akzent")
	farben["akzent"] = ak[rng.randi_range(0, ak.size() - 1)]
	var au := palette_keys("augen")
	farben["augen"] = au[rng.randi_range(0, au.size() - 1)]
	look["farben"] = farben


## Bringt ein (geladenes, vielleicht altes oder kaputtes) Aussehen in eine gültige Form.
static func sanitize(look: Dictionary) -> Dictionary:
	var basis := String(look.get("basis", "bart"))
	if not BASES.has(basis):
		basis = "bart"
	var out := default_look(basis)
	var src_f: Variant = look.get("farben", {})
	var farben: Dictionary = out["farben"]
	if src_f is Dictionary:
		var sf: Dictionary = src_f
		for slot in SLOTS:
			var key := String(sf.get(slot, ""))
			if palette_keys(palette_for(basis, slot)).has(key):
				farben[slot] = key
	var eye := String(look.get("augen", "rund"))
	out["augen"] = eye if EYE_STYLES.has(eye) else "rund"
	for slot in ACC_SLOTS:
		var a := String(look.get(slot, ""))
		out[slot] = a if accessory_ids(slot, basis).has(a) else ""
	out["name"] = sanitize_name(String(look.get("name", "")), basis)
	var ton := String(look.get("ton", "lieb"))
	out["ton"] = ton if TONES.has(ton) else "lieb"
	out["bilder"] = int(look.get("bilder", 0))
	return out


## Name: trimmen, Zeilenumbrüche und {} weg, höchstens 12 Zeichen, leer -> Standardname der Basis.
static func sanitize_name(n: String, basis: String = "bart") -> String:
	var s := n.replace("\n", " ").replace("\r", " ").replace("\t", " ").replace("{", "").replace("}", "")
	s = s.strip_edges()
	while s.find("  ") >= 0:
		s = s.replace("  ", " ")
	if s.length() > NAME_MAX:
		s = s.substr(0, NAME_MAX).strip_edges()
	if s == "":
		var bd: Dictionary = BASES.get(basis, BASES["bart"])
		s = String(bd["name"])
	return s


# --- Farben ---------------------------------------------------------------------------------------------

## Welche Palette ein Farbplatz bei dieser Basis nutzt.
static func palette_for(basis: String, slot: String) -> String:
	var bd: Dictionary = BASES.get(basis, BASES["bart"])
	for row in bd["rows"]:
		if String(row[0]) == slot:
			return String(row[2])
	return slot


static func palette_keys(palette: String) -> Array:
	var p: Dictionary = PALETTES.get(palette, {})
	return p.keys()


static func palette_color(palette: String, key: String) -> Color:
	var p: Dictionary = PALETTES.get(palette, {})
	if p.has(key):
		return Color(String(p[key]))
	var first: Array = p.values()
	return Color(String(first[0])) if not first.is_empty() else Color.WHITE


## Farbe eines Platzes (haupt, haut, haar, akzent, augen) für dieses Aussehen.
static func color(look: Dictionary, slot: String) -> Color:
	var basis := String(look.get("basis", "bart"))
	var farben: Dictionary = look.get("farben", {})
	return palette_color(palette_for(basis, slot), String(farben.get(slot, "")))


static func rows(basis: String) -> Array:
	var bd: Dictionary = BASES.get(basis, BASES["bart"])
	return bd["rows"]


# --- Zubehör ----------------------------------------------------------------------------------------------

static func has_neck(basis: String) -> bool:
	var bd: Dictionary = BASES.get(basis, BASES["bart"])
	return bd.has("neck")


static func accessory(slot: String, id: String) -> Dictionary:
	for a in ACCESSORIES.get(slot, []):
		var ad: Dictionary = a
		if String(ad["id"]) == id:
			return ad
	return {}


## Wählbare Zubehör-Ids eines Platzes ("" = keins zuerst). Ohne Hals: nur "".
static func accessory_ids(slot: String, basis: String) -> Array:
	var out: Array = []
	for a in ACCESSORIES.get(slot, []):
		var ad: Dictionary = a
		var id := String(ad["id"])
		if id != "" and slot == "hals" and not has_neck(basis):
			continue
		out.append(id)
	return out


# --- Dateien ----------------------------------------------------------------------------------------------

static func part_files(basis: String) -> Array:
	## [[Pfad, Farbplatz oder ""], …] von hinten nach vorn
	var out: Array = []
	var bd: Dictionary = BASES.get(basis, BASES["bart"])
	for p in bd["parts"]:
		var pd: Dictionary = p
		var id := String(pd["id"])
		var slot := String(pd["slot"])
		if slot == "":
			out.append([DIR + basis + "/" + id + ".svg", ""])
		else:
			out.append([DIR + basis + "/" + id + "_f.svg", slot])
			if pd.get("l", false):
				out.append([DIR + basis + "/" + id + "_l.svg", ""])
	return out


static func face_file(name: String) -> String:
	return DIR + "face/" + name + ".svg"


static func acc_file(name: String) -> String:
	return DIR + "acc/" + name + ".svg"


## Alle Dateien, die irgendein Aussehen brauchen kann (für Tests und Vorladen).
static func all_files() -> Array:
	var out: Array = []
	for basis in BASE_ORDER:
		for pf in part_files(basis):
			out.append(String(pf[0]))
	for stil in EYE_ORDER:
		for k in ["weiss", "iris", "pupille", "froh", "zu", "zwinker"]:
			out.append(face_file("augen_%s_%s" % [stil, k]))
		out.append(face_file("lid_muede_" + stil))
		out.append(face_file("lid_traurig_" + stil))
	for e in EXPRESSIONS:
		var ed: Dictionary = EXPRESSIONS[e]
		out.append(face_file("mund_" + String(ed["mouth"])))
		for b in ed["brows"]:
			out.append(face_file("brauen_" + String(b)))
		for x in ed.get("extras", []):
			out.append(face_file(String(x)))
	for t in TONE_REST:
		var td: Dictionary = TONE_REST[t]
		if td.has("mouth"):
			out.append(face_file("mund_" + String(td["mouth"])))
	out.append(face_file("mund_laecheln"))
	out.append(face_file("mund_lachen"))
	for slot in ACC_SLOTS:
		for a in ACCESSORIES[slot]:
			var ad: Dictionary = a
			for key in ["files", "lens", "bridge"]:
				for fl in ad.get(key, []):
					out.append(acc_file(String(fl[0])))
	var uniq: Array = []
	for p in out:
		if not uniq.has(p):
			uniq.append(p)
	return uniq


# --- Speichern ------------------------------------------------------------------------------------------

static func exists(path: String = SAVE_PATH) -> bool:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return false
	return cf.has_section(SECTION)


## Lädt das Aussehen. Kein Spielstand -> {} (dann zeigt das Spiel den Ersteller).
static func load_look(path: String = SAVE_PATH) -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(path) != OK or not cf.has_section(SECTION):
		return {}
	return from_config(cf)


static func save_look(look: Dictionary, path: String = SAVE_PATH) -> int:
	var cf := ConfigFile.new()
	cf.load(path)             # andere Abschnitte behalten
	to_config(cf, look)
	return cf.save(path)


## In eine fremde ConfigFile schreiben (z. B. den Spielstand von Game, Abschnitt [charakter]).
static func to_config(cf: ConfigFile, look: Dictionary) -> void:
	var l := sanitize(look)
	cf.set_value(SECTION, "version", VERSION)
	for k in ["basis", "farben", "augen", "kopf", "gesicht", "hals", "name", "ton", "bilder"]:
		cf.set_value(SECTION, k, l[k])


static func from_config(cf: ConfigFile) -> Dictionary:
	var d := {}
	for k in ["version", "basis", "farben", "augen", "kopf", "gesicht", "hals", "name", "ton", "bilder"]:
		if cf.has_section_key(SECTION, k):
			d[k] = cf.get_value(SECTION, k)
	return sanitize(d)
