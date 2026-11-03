class_name Balance
extends RefCounted
## Zentrale Balancing-Datei: ALLE Spielzahlen stehen hier.

# --- Völker und Start --------------------------------------------------------
static var NATION_COUNT := 3
static var START_VILLAGES := 2            # Dörfer pro Volk
static var START_VILLAGE_PEOPLE := 3
static var START_CHURCH_PEOPLE := 2
static var START_MARKET_PEOPLE := 2
static var START_ANIMAL_HERDS := 8
static var START_ANIMALS := 2

# Gelände-Gewichte beim Verteilen
static var TERRAIN_WEIGHTS := {"meadow": 40, "forest": 26, "lake": 18, "mountain": 16}

# --- Wachsen und Schrumpfen ---------------------------------------------------
static var MAX_PEOPLE := 9                # pro Feld
static var MAX_ANIMALS := 6               # pro Feld
static var GROWTH_FOOD_NEEDED := 2        # Dorf wächst mit so vielen freien Wiesen/Seen daneben
static var CHURCH_BONUS := 1              # Dorf neben eigener Kirche wächst zusätzlich
static var TRADE_GAIN := 1                # Markt neben fremdem Markt (kein Krieg): +1
static var TRADE_MAX := 2
static var WAR_LOSS := 1                  # pro Berührung mit einem Feind
static var WAR_MAX := 3
static var EXPAND_AT := 8                 # ab so vielen Menschen gründet ein Dorf ein neues
static var EXPAND_COST := 2
static var NEW_VILLAGE_PEOPLE := 2

# --- Katastrophen --------------------------------------------------------------
static var FIRE_DAMAGE := 2
static var CRATER_TO_LAKE := 5            # nach so vielen Runden füllt sich ein Krater mit Wasser
static var HAZARD_FREE_ROUNDS := 2        # die ersten Runden sind ruhig
static var HAZARD_CHANCE_BASE := 0.35
static var HAZARD_CHANCE_STEP := 0.03     # pro Runde wahrscheinlicher
static var HAZARD_CHANCE_MAX := 0.9
static var HAZARD_MAX_BASE := 1           # gleichzeitig aktive Gefahren am Anfang
static var HAZARD_MAX_EVERY := 6          # alle 6 Runden eine mehr
static var HAZARD_MAX := 4
static var HAZARD_WEIGHTS := {"storm": 40, "meteor": 30, "volcano": 30}
static var HAZARD_TIMER := {"storm": 2, "meteor": 3, "volcano": 3}
static var HAZARD_TARGET_SETTLED := 0.7   # so oft zielt eine Gefahr auf bewohntes Land

# --- Spielende -----------------------------------------------------------------
static var MAX_ROUNDS := 0                # 0 = endlos, bis alle Menschen tot sind

# --- Bedienung -----------------------------------------------------------------
static var TWIST_SNAP_SECONDS := 0.22
static var TWIST_FINGER_UNITS := 1.5      # Fingerweg (in Würfelfeldern) für eine Vierteldrehung
static var DRAG_START_PX := 12.0
