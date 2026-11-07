class_name FieldData
extends RefCounted
## Ein Feld auf dem Würfel. Reine Daten, keine Darstellung.
## Dazu die Art-Tabelle von gdpd (17 Arten, siehe docs/GDPD_7_TAGE.md, Abschnitt 1; Stein: GDPD_BALANCE_2.md 4.1).

# --- Arten (kind) -------------------------------------------------------------------
# Baum „Die Schöpfung in 7 Tagen“ (docs/GDPD_7_TAGE.md, Abschnitt 1): Land → Pflanzen → Tiere → Menschen → Nahrung,
# Glaube, Industrie. Erde → Wiese → Wald → Großer Wald → Tiere → Hütte → Haus → Dorf → Stadt | Kirche …
# Ids 0–14 bleiben wie in v1.1 (Spielstände, Tests, Bilder), Wasser kommt als 15 dazu.
const EMPTY := 0          # Erde: drei in einer neuen Reihe werden eine Wiese
const MEADOW := 1
const FOREST := 2
const FIELD := 3          # Acker
const BIGFOREST := 4
const ANIMALS := 5
const HUT := 6
const HOUSE := 7
const VILLAGE := 8
const TOWN := 9
const CHURCH := 10        # fertig
const BIGCITY := 11
const INDUSTRY := 12      # fertig
const METROPOLIS := 13    # fertig
const PARADISE := 14      # fertig (Naturwunder, nur im freien Spiel: zweite Wahl bei den Tieren)
const WATER := 15         # Wasser: Hintergrund, bildet nie eine Reihe, ändert sich nie
const STONE := 16         # Stein (GDPD_BALANCE_2.md 4.1): Hintergrund wie Wasser, gibt Arbeit (Tage 5–7)
const KIND_COUNT := 17

const KIND_KEY = ["empty", "meadow", "forest", "field", "bigforest", "animals", "hut", "house", "village", "town",
	"church", "bigcity", "industry", "metropolis", "paradise", "water", "stone"]
const KIND_NAME = ["Erde", "Wiese", "Wald", "Acker", "Großer Wald", "Tiere", "Hütte", "Haus", "Dorf", "Stadt",
	"Kirche", "Großstadt", "Industrie", "Metropole", "Paradies", "Wasser", "Stein"]
const KIND_SHORT = ["Erde", "Wiese", "Wald", "Acker", "gr. Wald", "Tiere", "Hütte", "Haus", "Dorf", "Stadt",
	"Kirche", "Großstadt", "Industrie", "Metropole", "Paradies", "Wasser", "Stein"]
const KIND_ARTICLE = ["Erde", "eine Wiese", "einen Wald", "einen Acker", "einen großen Wald", "Tiere", "eine Hütte",
	"ein Haus", "ein Dorf", "eine Stadt", "eine Kirche", "eine Großstadt", "Industrie", "eine Metropole", "ein Paradies",
	"Wasser", "einen Stein"]
## Mehrzahl für Ziele („Lass 8 Wiesen wachsen“).
const KIND_PLURAL = ["Erden", "Wiesen", "Wälder", "Äcker", "große Wälder", "Tiere", "Hütten", "Häuser", "Dörfer",
	"Städte", "Kirchen", "Großstädte", "Industrien", "Metropolen", "Paradiese", "Wasser", "Steine"]
## Icon-Namen (res://icons/<name>.svg). Fehlt eins, nimmt die Oberfläche KIND_ICON_FALLBACK.
const KIND_ICON = ["empty", "meadow", "smallforest", "field", "nature", "animals", "hut", "house", "village", "town",
	"church", "bigcity", "industry", "metropolis", "paradise", "water", "stone"]
const KIND_ICON_FALLBACK = {"field": "meadow", "animals": "paw", "paradise": "nature", "smallforest": "nature", "water": "rain",
	"stone": "empty"}
## Stufe: Reihenfolge, Glaube fürs Wachsen (Balance.GROW_FAITH), Diagonalen.
const TIER = [0, 1, 2, 2, 3, 4, 5, 6, 7, 8, 8, 9, 9, 10, 5, 0, 0]
## Familie: land (Erde), nature, food, people, faith (Kirche, zählt zu den Menschen), industry, none (Wasser).
const FAMILY = ["land", "nature", "nature", "food", "nature", "nature", "people", "people", "people", "people",
	"faith", "people", "industry", "people", "nature", "none", "none"]
## Nächste Art bei einer neuen Dreierreihe (der Standardweg; -1: fertig oder Wasser). Eine Wahl hat als Option 1 diesen Weg.
const NEXT = [MEADOW, FOREST, BIGFOREST, HUT, ANIMALS, HUT, HOUSE, VILLAGE, TOWN, BIGCITY, -1, METROPOLIS, -1, -1, -1, -1, -1]
## Wahl („Dein Wille geschehe“): Art → [Option 1 (Standard), Option 2]. Welche davon gerade gilt, entscheidet der
## Spielstand (GameState.is_choice: an einem Tag erst ab dem Tag, an dem Option 2 freigeschaltet ist).
const CHOICE = {MEADOW: [FOREST, FIELD], VILLAGE: [TOWN, CHURCH], TOWN: [BIGCITY, INDUSTRY], ANIMALS: [HUT, PARADISE]}
## Fällt (Feuer, Krieg, Gewitter, Flut, Smog) auf diese Art. Erde bleibt Erde, Wasser bleibt Wasser.
const DOWN = [EMPTY, EMPTY, MEADOW, MEADOW, FOREST, BIGFOREST, ANIMALS, HUT, HOUSE, VILLAGE, VILLAGE, TOWN, TOWN,
	BIGCITY, ANIMALS, WATER, STONE]
## Zeitalter (0 Urzeit … 6 Moderne), das diese Art beim ersten Bau erreicht (Natur ändert nichts; nur freies Spiel).
const AGE_OF = [0, 0, 0, 1, 0, 0, 1, 2, 3, 4, 4, 5, 5, 6, 0, 0, 0]

# --- Texte für die Wahl-Karte ------------------------------------------------------------
const CHOICE_HEADER := "Dein Wille geschehe"
const CHOICE_TITLE = {MEADOW: "Was soll hier wachsen?", VILLAGE: "Was baut das Dorf?", TOWN: "Wie wächst die Stadt?",
	ANIMALS: "Was wird aus den Tieren?", BIGFOREST: "Wer soll hier leben?"}
## Kurzer Satz unter jeder Option (Schlüssel: die Art, die daraus wird).
const CHOICE_LINE = {FOREST: "Für Tiere und Luft.", FIELD: "Essen für die Menschen.",
	ANIMALS: "Leben im Wald.", HUT: "Menschen ziehen ein.",
	TOWN: "Eine Stadt entsteht.", CHURCH: "Viel Glaube, aber Streit.",
	BIGCITY: "Mehr Menschen, mehr Leben.", INDUSTRY: "Viel Glaube, aber Smog.",
	PARADISE: "Ein Naturwunder. Bringt Glauben."}
## Erklärung beim langen Drücken auf ein Feld (freies Spiel; an einem Tag: GameState.kind_help).
const KIND_HELP = [
	"Erde. Wird zur Wiese.",
	"Wiese. Wird Wald oder Acker.",
	"Wald. Wird großer Wald.",
	"Acker. Essen. Wird zur Hütte.",
	"Großer Wald. Bringt Tiere.",
	"Tiere. Werden Hütte oder Paradies.",
	"Hier wohnen Menschen.",
	"Hier wohnen Menschen.",
	"Dorf. Wird Stadt oder Kirche.",
	"Stadt. Wird Großstadt oder Industrie.",
	"Kirche. +3 Glauben. Zwei Kirchen: Krieg!",
	"Großstadt. Wird Metropole.",
	"Industrie. +5 Glauben. Macht Smog.",
	"Metropole. +2 Glauben.",
	"Paradies. +1 Glauben.",
	"Wasser. Hier wächst nichts.",
	"Stein. Gibt Arbeit.",
]
## Texte, solange die Wahl dieser Art noch nicht freigeschaltet ist (vor Tag 5 bzw. in den 7 Tagen).
const KIND_HELP_NO_CHOICE = {MEADOW: "Wiese. Wird Wald.",
	ANIMALS: "Tiere. Werden Hütte.",
	VILLAGE: "Dorf. Wird Stadt.", TOWN: "Stadt. Wird Großstadt."}
## Zusatz für eine Art, die heute ruht (ihre nächste Art ist an diesem Tag noch nicht freigeschaltet).
const REST_HELP := "Wächst erst später."

# --- Ein Feld -----------------------------------------------------------------------------
var id: int = 0
var p: Vector3i = Vector3i.ZERO   # Würfelchen im 3×3×3-Gitter (−1/0/1)
var n: Vector3i = Vector3i.ZERO   # Normale = Seite
var kind: int = 0                 # Art (siehe oben), 0 = Erde, 15 = Wasser
var fresh: int = 0                # > 0: frisch verwüstet (Smog, Gewitter), zeigt Rauch, wächst nicht nach
var burning := false              # brennt: fällt am nächsten Rundenende eine Stufe (DOWN)
## Gedeihen (die 7 Tage, GDPD_BALANCE_2.md 4.3): satt seit so vielen Rundenenden, hungrig seit so vielen, höchste je
## erreichte Menschen-Stufe (0 Hütte, 1 Dorf, 2 Stadt; -1 nie). Gehören zum Feld und drehen mit.
var fed: int = 0
var hungry: int = 0
var maxlvl: int = -1
## Glaube (7.3): höchste Stufe, für die dieses Feld schon Glauben gebracht hat (-1: noch nie). Ein Feld zahlt nur für eine
## NEUE Stufe neben einer Kirche, Hin-und-her-Drehen bringt keinen Glauben.
var flvl: int = -1
## Alter Name für kind (Oberfläche aus dem Würfelspiel). Neu: kind benutzen.
var stage: int:
	get:
		return kind
	set(v):
		kind = v


func copy() -> FieldData:
	var f := FieldData.new()
	f.id = id
	f.p = p
	f.n = n
	f.kind = kind
	f.fresh = fresh
	f.burning = burning
	f.fed = fed
	f.hungry = hungry
	f.maxlvl = maxlvl
	f.flvl = flvl
	return f


func is_nature() -> bool:
	return FieldData.nature(kind)


## Zivilisation: Acker, Menschen, Kirche, Industrie (alles mit Stadt-Gewicht).
func is_civilisation() -> bool:
	return FieldData.civ(kind)


func is_people() -> bool:
	return FieldData.people(kind)


func is_finished() -> bool:
	return FieldData.finished(kind)


# --- Abfragen zur Art-Tabelle ---------------------------------------------------------------

static func valid(k: int) -> bool:
	return k >= 0 and k < KIND_COUNT


static func nature(k: int) -> bool:
	return k == MEADOW or k == FOREST or k == BIGFOREST or k == ANIMALS or k == PARADISE


static func people(k: int) -> bool:
	return k == HUT or k == HOUSE or k == VILLAGE or k == TOWN or k == CHURCH or k == BIGCITY or k == METROPOLIS


static func civ(k: int) -> bool:
	return valid(k) and k != EMPTY and k != WATER and not nature(k)


## Fertig (★): wächst nicht mehr, bildet keine Reihe, bringt jede Drehung Glauben.
static func finished(k: int) -> bool:
	return k == CHURCH or k == INDUSTRY or k == METROPOLIS or k == PARADISE


## Menschen der 7 Tage (Gedeihen): Hütte → Dorf → Stadt. Stufe 0, 1, 2 (-1: keine).
static func level8(k: int) -> int:
	if k == HUT:
		return 0
	if k == VILLAGE:
		return 1
	if k == TOWN:
		return 2
	return -1


## Kann diese Art überhaupt eine Reihe bilden? (Nicht Wasser, nicht fertig.) Ob sie es heute darf (Tag),
## sagt GameState.can_row.
static func can_row(k: int) -> bool:
	return k != WATER and k != STONE and valid(k) and not finished(k)


## Sticker-Art eines Platzes p: 3 Ecke, 2 Kante, 1 Mitte (so viele Koordinaten ≠ 0). Eine Drehung ändert sie nie;
## eine gerade Reihe ist immer Ecke–Kante–Ecke oder Kante–Mitte–Kante.
static func sticker_type(p: Vector3i) -> int:
	return int(p.x != 0) + int(p.y != 0) + int(p.z != 0)


static func is_choice(k: int) -> bool:
	return CHOICE.has(k)


## Die beiden Optionen einer Wahl ([] wenn keine Wahl).
static func options(k: int) -> Array:
	if CHOICE.has(k):
		return (CHOICE[k] as Array).duplicate()
	return []


## Nächste Art. option: 0/1 bei einer Wahl. Fertige Arten bleiben, wie sie sind.
static func next_kind(k: int, option: int = 0) -> int:
	if CHOICE.has(k):
		return int((CHOICE[k] as Array)[clampi(option, 0, 1)])
	if not valid(k):
		return k
	var nx: int = int(NEXT[k])
	return nx if nx >= 0 else k


static func down(k: int) -> int:
	return int(DOWN[clampi(k, 0, KIND_COUNT - 1)])


static func tier(k: int) -> int:
	return int(TIER[clampi(k, 0, KIND_COUNT - 1)])


static func kind_name(k: int) -> String:
	return str(KIND_NAME[clampi(k, 0, KIND_COUNT - 1)])


static func kind_icon(k: int) -> String:
	return str(KIND_ICON[clampi(k, 0, KIND_COUNT - 1)])


static func kind_plural(k: int) -> String:
	return str(KIND_PLURAL[clampi(k, 0, KIND_COUNT - 1)])


## Eintrag der Art-Tabelle als Dictionary (für die Oberfläche).
static func info(k: int) -> Dictionary:
	var c := clampi(k, 0, KIND_COUNT - 1)
	return {
		"kind": c, "key": KIND_KEY[c], "name": KIND_NAME[c], "short": KIND_SHORT[c], "icon": KIND_ICON[c],
		"tier": TIER[c], "family": FAMILY[c], "finished": finished(c), "choice": options(c),
		"next": next_kind(c, 0), "down": DOWN[c], "income": int(Balance.INCOME.get(c, 0)), "help": KIND_HELP[c],
	}
