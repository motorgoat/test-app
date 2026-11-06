class_name FieldData
extends RefCounted
## Ein Feld auf dem Würfel. Reine Daten, keine Darstellung.
## Dazu die Art-Tabelle von gdpd (16 Arten, siehe docs/GDPD_7_TAGE.md, Abschnitt 1).

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
const KIND_COUNT := 16

const KIND_KEY = ["empty", "meadow", "forest", "field", "bigforest", "animals", "hut", "house", "village", "town",
	"church", "bigcity", "industry", "metropolis", "paradise", "water"]
const KIND_NAME = ["Erde", "Wiese", "Wald", "Acker", "Großer Wald", "Tiere", "Hütte", "Haus", "Dorf", "Stadt",
	"Kirche", "Großstadt", "Industrie", "Metropole", "Paradies", "Wasser"]
const KIND_SHORT = ["Erde", "Wiese", "Wald", "Acker", "gr. Wald", "Tiere", "Hütte", "Haus", "Dorf", "Stadt",
	"Kirche", "Großstadt", "Industrie", "Metropole", "Paradies", "Wasser"]
const KIND_ARTICLE = ["Erde", "eine Wiese", "einen Wald", "einen Acker", "einen großen Wald", "Tiere", "eine Hütte",
	"ein Haus", "ein Dorf", "eine Stadt", "eine Kirche", "eine Großstadt", "Industrie", "eine Metropole", "ein Paradies",
	"Wasser"]
## Mehrzahl für Ziele („Lass 8 Wiesen wachsen“).
const KIND_PLURAL = ["Erden", "Wiesen", "Wälder", "Äcker", "große Wälder", "Tiere", "Hütten", "Häuser", "Dörfer",
	"Städte", "Kirchen", "Großstädte", "Industrien", "Metropolen", "Paradiese", "Wasser"]
## Icon-Namen (res://icons/<name>.svg). Fehlt eins, nimmt die Oberfläche KIND_ICON_FALLBACK.
const KIND_ICON = ["empty", "meadow", "smallforest", "field", "nature", "animals", "hut", "house", "village", "town",
	"church", "bigcity", "industry", "metropolis", "paradise", "water"]
const KIND_ICON_FALLBACK = {"field": "meadow", "animals": "paw", "paradise": "nature", "smallforest": "nature", "water": "rain"}
## Stufe: Reihenfolge, Glaube fürs Wachsen (Balance.GROW_FAITH), Diagonalen.
const TIER = [0, 1, 2, 2, 3, 4, 5, 6, 7, 8, 8, 9, 9, 10, 5, 0]
## Familie: land (Erde), nature, food, people, faith (Kirche, zählt zu den Menschen), industry, none (Wasser).
const FAMILY = ["land", "nature", "nature", "food", "nature", "nature", "people", "people", "people", "people",
	"faith", "people", "industry", "people", "nature", "none"]
## Nächste Art bei einer neuen Dreierreihe (der Standardweg; -1: fertig oder Wasser). Eine Wahl hat als Option 1 diesen Weg.
const NEXT = [MEADOW, FOREST, BIGFOREST, HUT, ANIMALS, HUT, HOUSE, VILLAGE, TOWN, BIGCITY, -1, METROPOLIS, -1, -1, -1, -1]
## Wahl („Dein Wille geschehe“): Art → [Option 1 (Standard), Option 2]. Welche davon gerade gilt, entscheidet der
## Spielstand (GameState.is_choice: an einem Tag erst ab dem Tag, an dem Option 2 freigeschaltet ist).
const CHOICE = {MEADOW: [FOREST, FIELD], VILLAGE: [TOWN, CHURCH], TOWN: [BIGCITY, INDUSTRY], ANIMALS: [HUT, PARADISE]}
## Fällt (Feuer, Krieg, Gewitter, Flut, Smog) auf diese Art. Erde bleibt Erde, Wasser bleibt Wasser.
const DOWN = [EMPTY, EMPTY, MEADOW, MEADOW, FOREST, BIGFOREST, ANIMALS, HUT, HOUSE, VILLAGE, VILLAGE, TOWN, TOWN,
	BIGCITY, ANIMALS, WATER]
## Zeitalter (0 Urzeit … 6 Moderne), das diese Art beim ersten Bau erreicht (Natur ändert nichts; nur freies Spiel).
const AGE_OF = [0, 0, 0, 1, 0, 0, 1, 2, 3, 4, 4, 5, 5, 6, 0, 0]

# --- Texte für die Wahl-Karte ------------------------------------------------------------
const CHOICE_HEADER := "Dein Wille geschehe"
const CHOICE_TITLE = {MEADOW: "Was soll hier wachsen?", VILLAGE: "Was baut das Dorf?", TOWN: "Wie wächst die Stadt?",
	ANIMALS: "Was wird aus den Tieren?", BIGFOREST: "Wer soll hier leben?"}
## Kurzer Satz unter jeder Option (Schlüssel: die Art, die daraus wird).
const CHOICE_LINE = {FOREST: "Für Tiere und frische Luft.", FIELD: "Essen für die Menschen.",
	ANIMALS: "Tiere machen den Wald lebendig.", HUT: "Menschen ziehen zu den Tieren.",
	TOWN: "Die Menschen bauen eine Stadt.", CHURCH: "Viel Glaube. Aber Kirchen streiten gern.",
	BIGCITY: "Mehr Menschen, mehr Leben.", INDUSTRY: "Schnell viel Glaube – aber Smog.",
	PARADISE: "Ein Naturwunder. Wächst nicht mehr, bringt Glauben."}
## Erklärung beim langen Drücken auf ein Feld (freies Spiel; an einem Tag: GameState.kind_help).
const KIND_HELP = [
	"Erde. Drei in einer Reihe werden eine Wiese.",
	"Wiese. Drei in einer Reihe: Wald oder Acker – du wählst.",
	"Wald. Drei in einer Reihe werden ein großer Wald.",
	"Acker. Essen für Menschen. Drei in einer Reihe: eine Hütte.",
	"Großer Wald. Drei in einer Reihe bringen Tiere.",
	"Tiere. Drei in einer Reihe: Menschen ziehen ein – eine Hütte oder ein Paradies.",
	"Hier wohnen Menschen. Drei in einer Reihe wachsen weiter.",
	"Hier wohnen Menschen. Drei in einer Reihe wachsen weiter.",
	"Dorf. Drei in einer Reihe: Stadt oder Kirche.",
	"Stadt. Drei in einer Reihe: Großstadt oder Industrie.",
	"Kirche. Fertig. Bringt jede Runde 3 Glauben. Treffen sich zwei Kirchen durch eine Drehung, gibt es Krieg.",
	"Großstadt. Drei in einer Reihe: eine Metropole.",
	"Industrie. Fertig. Bringt jede Runde 5 Glauben – aber sie macht die Welt schmutzig.",
	"Metropole. Fertig. Bringt jede Runde 2 Glauben.",
	"Paradies. Fertig – wächst nicht mehr. Bringt jede Runde 1 Glauben.",
	"Wasser. Hier wächst nichts.",
]
## Texte, solange die Wahl dieser Art noch nicht freigeschaltet ist (vor Tag 5 bzw. in den 7 Tagen).
const KIND_HELP_NO_CHOICE = {MEADOW: "Wiese. Drei in einer Reihe werden ein Wald.",
	ANIMALS: "Tiere. Drei in einer Reihe: Menschen ziehen ein – eine Hütte.",
	VILLAGE: "Dorf. Drei in einer Reihe werden eine Stadt.", TOWN: "Stadt. Drei in einer Reihe werden eine Großstadt."}
## Zusatz für eine Art, die heute ruht (ihre nächste Art ist an diesem Tag noch nicht freigeschaltet).
const REST_HELP := "Morgen wächst hier mehr."

# --- Ein Feld -----------------------------------------------------------------------------
var id: int = 0
var p: Vector3i = Vector3i.ZERO   # Würfelchen im 3×3×3-Gitter (−1/0/1)
var n: Vector3i = Vector3i.ZERO   # Normale = Seite
var kind: int = 0                 # Art (siehe oben), 0 = Erde, 15 = Wasser
var fresh: int = 0                # > 0: frisch verwüstet (Smog, Gewitter), zeigt Rauch, wächst nicht nach
var burning := false              # brennt: fällt am nächsten Rundenende eine Stufe (DOWN)
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


## Kann diese Art überhaupt eine Reihe bilden? (Nicht Wasser, nicht fertig.) Ob sie es heute darf (Tag),
## sagt GameState.can_row.
static func can_row(k: int) -> bool:
	return k != WATER and valid(k) and not finished(k)


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
