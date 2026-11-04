class_name Balance
extends RefCounted
## Zentrale Balancing-Datei: ALLE Spielzahlen stehen hier.

# --- Völker und Start --------------------------------------------------------
static var NATION_COUNT := 3
static var START_SETTLEMENTS := 4        # Siedlungen pro Volk (als Gruppe)
static var START_FAITH := 1              # Kapellen pro Volk
static var START_INDUSTRY := 6
static var START_MOUNTAINS := 6          # Rest wird Natur

# --- Stufen ------------------------------------------------------------------
static var MAX_LEVEL := 3
# Drei Gleiche (gleiche Art, Stufe, Volk) in einer Reihe oder Spalte einer Seite verschmelzen sofort.
static var MERGE_POINTS := [0, 10, 30, 90]   # Glaube je Stufe der verschmolzenen Felder (× Kombo)
static var MERGE_HARMONY_MIN := 0.5      # bei Gleichgewicht 0 zählt eine Verschmelzung nur halb
static var MAX_CASCADES := 6
static var NEED_ROUNDS := 3              # so viele Runden ohne Bedürfnis, dann Stufe tiefer
static var WAR_ROUNDS := 2               # so viele Runden Krieg an der Grenze, dann Stufe tiefer
static var POLLUTION_ROUNDS := 2         # so viele Runden neben Fabrik, dann Natur Stufe tiefer
static var POLLUTION_MIN_LEVEL := 2      # ab dieser Industrie-Stufe wird verschmutzt
static var CRATER_REGROW := 8            # nach so vielen Runden wächst auf einem Krater wieder Natur
static var CHAPEL_EVERY := 3             # jede 3. Ausbreitung einer Stadt wird eine Kapelle

# Ausbreiten (Stufe 3 wächst aufs Nachbarfeld): alle N Runden, wird mit jedem Zeitalter schneller
static var SPREAD_EVERY := 5
static var SPREAD_EVERY_MIN := 2

# --- Glaube (Punkte) -----------------------------------------------------------
static var TRADE_POINTS := 3             # Städte zweier Völker nebeneinander, ohne Krieg
static var DISASTER_LOSS_PER_LEVEL := 4  # Glaube, der pro zerstörter Stufe einer Siedlung verloren geht

# --- Gleichgewicht -------------------------------------------------------------
# Anteil an allen beweglichen Feldern, der als „gesund“ gilt
static var IDEAL := {
	"nature": [0.25, 0.50],
	"settlement": [0.15, 0.40],
	"industry": [0.06, 0.25],
	"faith": [0.04, 0.16],
}
static var HARMONY_STRICTNESS := 3.0     # wie stark Abweichungen das Gleichgewicht drücken
static var HARMONY_DANGER := 0.15        # darunter gilt die Welt als aus dem Gleichgewicht
static var LOSE_AFTER_DISHARMONY := 4    # so viele Runden aus dem Gleichgewicht = Ende

# --- Werkzeuge ---------------------------------------------------------------------
static var LIGHTNING_START := 1
static var LIGHTNING_EVERY := 5          # alle 5 Runden ein neuer Blitz
static var LIGHTNING_MAX := 3
static var MIRACLE_EVERY_POINTS := 40    # alle 40 Glaube ein Wunder
static var MIRACLE_MAX := 2

# --- Gefahren und Zeitalter -----------------------------------------------------
static var AGE_LENGTH := 10              # Runden pro Zeitalter
static var HAZARD_FREE_ROUNDS := 3
static var HAZARD_CHANCE_BASE := 0.3
static var HAZARD_CHANCE_PER_AGE := 0.12
static var HAZARD_CHANCE_MAX := 0.9
static var HAZARD_MAX_BASE := 1          # gleichzeitig, plus 1 pro Zeitalter
static var HAZARD_MAX := 5
static var HAZARD_WEIGHTS := {"storm": 40, "meteor": 35, "volcano": 25}
static var HAZARD_TIMER := 3             # Vorwarnung in Runden
static var HAZARD_TIMER_MIN := 2         # ab Zeitalter 3 eine Runde weniger

# --- Spielende -----------------------------------------------------------------
static var MAX_ROUNDS := 0               # 0 = endlos

# --- Bedienung (etwas behäbig, damit es sich schwer und echt anfühlt) -------------
static var TWIST_SNAP_SECONDS := 0.42
static var TWIST_FINGER_UNITS := 2.1     # Fingerweg (in Würfelfeldern) für eine Vierteldrehung
static var TWIST_FOLLOW := 9.0           # wie schnell die Scheibe dem Finger folgt (kleiner = träger)
static var DRAG_START_PX := 12.0
