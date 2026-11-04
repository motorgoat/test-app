class_name Balance
extends RefCounted
## Zentrale Balancing-Datei: ALLE Spielzahlen stehen hier.

# --- Die Leiter -------------------------------------------------------------------
# Drei gleiche in einer Reihe verschmelzen, wenn DEINE Drehung die Reihe vervollständigt:
#   die Mitte steigt eine Stufe auf, die beiden äußeren fallen eine Stufe zurück.
#   Leere Erde (0) · Wiese (1) → Wald (2) → Dorf (3) → Stadt (4) → Fabrik (5)
static var MAX_STAGE := 5
# Glaube fürs Verschmelzen, nach Stufe der verschmolzenen Felder (Index = Stufe), × Kombo
static var MERGE_POINTS := [0, 2, 5, 12, 25, 50]
static var MAX_CASCADES := 6

# --- Start ----------------------------------------------------------------------
static var START_MEADOW := 0.5            # Anteil Wiesen, der Rest ist leere Erde

# --- Jede Runde -------------------------------------------------------------------
static var INCOME := [0, 0, 0, 0, 1, 3]   # Glaube pro Runde je Feld dieser Stufe (Stadt, Fabrik)
static var REGROW_NEIGHBORS := 2          # leere Erde wird Wiese bei so vielen Natur-Nachbarn
static var REGROW_PER_ROUND := 2          # höchstens so viele Felder wachsen pro Runde nach (die mit der meisten Natur)
static var POLLUTION_PER_FACTORY := 1     # jede Fabrik macht pro Runde so viele Natur-Nachbarn zu Erde

# --- Gleichgewicht ------------------------------------------------------------------
static var NATURE_MIN := 0.30             # mindestens so viel Natur (Wiese + Wald)
static var CIVILISATION_MAX := 0.40       # höchstens so viel Zivilisation (Dorf + Stadt + Fabrik)
static var LOSE_AFTER := 3                # so viele Runden in Folge außerhalb = die Welt stirbt

# --- Meteorit -------------------------------------------------------------------------
static var METEOR_COST := 30              # Glaube für den ersten Meteoriten
static var METEOR_COST_STEP := 15         # jeder weitere kostet mehr

# --- Spielende --------------------------------------------------------------------
static var MAX_ROUNDS := 40               # Rundenzahl einer Partie (0 = endlos)
static var STARS := [80, 180, 320]        # Glaube für 1, 2, 3 Sterne

# --- Bedienung (etwas behäbig, damit es sich schwer und echt anfühlt) ----------------
static var TWIST_SNAP_SECONDS := 0.42
static var TWIST_FINGER_UNITS := 2.1      # Fingerweg (in Würfelfeldern) für eine Vierteldrehung
static var TWIST_FOLLOW := 9.0            # wie schnell die Scheibe dem Finger folgt (kleiner = träger)
static var DRAG_START_PX := 12.0
static var HINT_AFTER_SECONDS := 8.0      # so lange nichts getan, dann pulsiert eine lohnende Scheibe
static var TUTORIAL_HINT_ROUNDS := 3      # in den ersten Runden kommt der Tipp sofort
