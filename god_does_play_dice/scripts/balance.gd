class_name Balance
extends RefCounted
## Zentrale Balancing-Datei: ALLE Spielzahlen stehen hier.
## Werte ändern, ohne im Code zu suchen. (GDD Kap. 0: „eine zentrale Balancing-Datei“)
## Punkte, die im GDD als [OFFEN] markiert sind, sind hier als Schalter/Option angelegt.

# --- Zeit (GDD Kap. 4) -------------------------------------------------------
static var TICK_SECONDS := 8.0            # Länge eines Takts in Sekunden
static var ROTATION_ANIM_SECONDS := 0.6   # Dauer einer Drehanimation am Takt-Ende
static var PREVIEW_ANIM_SECONDS := 0.25   # Dauer der Vorschau-Drehung im Drehmodus

# --- Spieler -----------------------------------------------------------------
static var DEFAULT_AI_COUNT := 3          # 1–5 KI-Länder; Seiten ohne Spieler sind neutral

# --- Welt (GDD Kap. 2) -------------------------------------------------------
# Gewicht beim Würfeln des Geländes
static var TERRAIN_WEIGHTS := {
	"meadow": 30,
	"forest": 13,
	"lake": 12,
	"mountain": 14,
	"gold": 8,
}
# Jede Spielerseite bekommt mindestens je 1 von diesen Geländen
static var GUARANTEED_TERRAIN := ["lake", "gold", "forest", "mountain"]

# --- Ressourcen (GDD Kap. 3) -------------------------------------------------
static var START_INV := {"wood": 4, "stone": 0, "food": 2, "gold": 6}
static var START_RESIDENTS := 2

# --- Wirtschaft (GDD Kap. 5) -------------------------------------------------
static var GOLD_PER_CENTER_STAGE := 1     # +Gold pro Takt je Zentrum-Stufe
static var GOLD_PER_FIELD_LEVEL := 1      # +Gold pro Takt je Feld-Stufe (alle eigenen Felder)
## GDD Kap. 17: „Zu viel Gold später“. Deckel für das Gold aus Feld-Stufen pro Takt.
## 0 = kein Deckel.
static var FIELD_GOLD_CAP := 12

static var RESIDENT_BASE_PRICE := 4       # Bewohner kaufen: Grundpreis in Gold
static var RESIDENT_PRICE_STEP_EVERY := 3 # … alle 3 Käufe
static var RESIDENT_PRICE_STEP := 1       # … +1 Gold

# --- Felder ausbauen (GDD Kap. 6) --------------------------------------------
static var MAX_FIELD_LEVEL := 4
# Kosten für den Ausbau AUF Stufe L (Index = L). Jeder Ausbau kostet zusätzlich 1 freien Bewohner.
static var FIELD_UPGRADE_COST := [
	{},
	{"gold": 3, "wood": 2},
	{"gold": 6, "wood": 4},
	{"gold": 10, "wood": 6},
	{"gold": 15, "wood": 8},
]
static var FIELD_UPGRADE_RESIDENTS := 1
static var ROAD_YIELD_MULTIPLIER := 2     # Rohstoff-Ertrag mit verbundener Straße (Stufe 2 des Projekts)

# --- Besitz / Felder kaufen (GDD Kap. 7) -------------------------------------
## [OFFEN] true = Prototyp: alle 8 Felder der eigenen Seite gehören dir von Anfang an.
## false = GDD-Empfehlung: Start nur mit dem Zentrum, Felder der eigenen Seite einzeln billig kaufen.
static var START_OWNS_SIDE := true
static var OWN_SIDE_FIELD_PRICE := 2      # nur wenn START_OWNS_SIDE == false
static var FIELD_BASE_PRICE := 6          # freies Feld kaufen
static var FIELD_PRICE_STEP := 3          # jedes weitere gekaufte Feld +3
static var CROSS_EDGE_MIN_STAGE := 2      # über die Würfelkante kaufen erst ab Zentrum-Stufe 2

# --- Zentrum (GDD Kap. 8) ----------------------------------------------------
static var STAGE_NAMES := ["", "Zelt", "Haus", "Marktplatz", "Kaserne", "Werkstatt"]
# Kosten für den Ausbau AUF Stufe S (Index = S)
static var STAGE_COST := [
	{},
	{},
	{"wood": 15, "stone": 5, "gold": 15},
	{"wood": 25, "stone": 15, "gold": 30},
	{"wood": 35, "stone": 30, "gold": 50},
	{"wood": 45, "stone": 45, "gold": 80},
]
static var MAX_STAGE := 5
static var STAGE_COOLDOWN_TICKS := 12     # mindestens 12 Takte zwischen zwei Ausbauten
static var ROTATIONS_PER_STAGE_UP := 1    # jeder Ausbau bringt 1 Drehung
static var START_ROTATIONS := 0
static var MARKET_STAGE := 3              # ab Marktplatz: Tausch
static var TRADE_RATE := 3                # 3:1

# --- Sieg (GDD Kap. 13) ------------------------------------------------------
static var WIN_FIELDS := 24               # wer zuerst so viele Felder (ohne Zentrum) besitzt, gewinnt
## [OFFEN, Variante (a)] Nach so vielen Takten gewinnt, wer die meisten Felder hat. 0 = aus.
## 150 Takte × 8 s = 20 Minuten.
static var TIME_LIMIT_TICKS := 150

# --- KI (GDD Kap. 14) --------------------------------------------------------
static var AI_GOLD_RESERVE := 0.5         # ungefähr die Hälfte des Golds für den nächsten Ausbau zurückhalten
static var AI_MAX_FIELD_UPGRADES := 2     # pro Takt
static var AI_ROTATION_HUMAN_WEIGHT := 0.7  # Bewertung: eigener Ertrag − 0,7 × Ertrag des Menschen
static var AI_ROTATION_MIN_GAIN := 2.0    # nur drehen, wenn klar besser als nicht drehen
static var AI_MARKET_KEEP := 3            # so viel von einem Rohstoff behält die KI beim Tauschen mindestens

# --- Oberfläche --------------------------------------------------------------
static var LONG_PRESS_SECONDS := 0.5
static var TAP_MAX_MOVE_PX := 10.0
