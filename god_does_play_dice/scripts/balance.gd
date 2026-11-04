class_name Balance
extends RefCounted
## Zentrale Balancing-Datei: ALLE Spielzahlen stehen hier.

# --- Die Leiter -------------------------------------------------------------------
# Drei gleiche in einer Reihe verschmelzen, wenn DEINE Drehung die Reihe vervollständigt:
#   die Mitte steigt eine Stufe auf, die beiden äußeren fallen eine Stufe zurück.
#   Erde (0) · Wiese (1) → kleiner Wald (2) → großer Wald (3) → Hütte (4) → Haus (5)
#   → Dorf (6) → Stadt (7) → Großstadt (8) → Metropole (9)
#   Natur = Stufe 1–3, Zivilisation = ab Stufe 4.
static var MAX_STAGE := 9
static var NATURE_STAGES := [1, 3]
static var CIVILISATION_FROM := 4
# Glaube fürs Verschmelzen, nach Stufe der verschmolzenen Felder (Index = Stufe), × Kombo
static var MERGE_POINTS := [0, 2, 4, 7, 11, 16, 24, 35, 50, 75]
static var MAX_CASCADES := 6

# --- Start ----------------------------------------------------------------------
static var START_MEADOW := 0.5            # Anteil Wiesen, der Rest ist leere Erde

# --- Jede Runde -------------------------------------------------------------------
static var INCOME := [0, 0, 0, 0, 0, 0, 1, 2, 4, 8]   # Glaube pro Runde je Feld (ab Dorf)
static var REGROW_NEIGHBORS := 2          # leere Erde wird Wiese bei so vielen Natur-Nachbarn
static var REGROW_PER_ROUND := 2          # höchstens so viele Felder wachsen pro Runde nach (die mit der meisten Natur)
static var POLLUTION_FROM := 8            # ab dieser Stufe (Großstadt) wird Natur daneben zerstört
static var POLLUTION_PER_FIELD := 1       # so viele Natur-Nachbarn pro Runde

# --- Gleichgewicht ------------------------------------------------------------------
static var NATURE_MIN := 0.30             # mindestens so viel Natur (Wiese, Wälder)
static var CIVILISATION_MAX := 0.40       # höchstens so viel Zivilisation (ab Hütte)
static var LOSE_AFTER := 3                # so viele Runden in Folge außerhalb = die Welt stirbt

# --- Meteorit -------------------------------------------------------------------------
static var METEOR_COST := 30              # Glaube für den ersten Meteoriten
static var METEOR_COST_STEP := 15         # jeder weitere kostet mehr

# --- Modi ------------------------------------------------------------------------------
# Endlos: alle AGE_LENGTH Runden ein neues Zeitalter, der gesunde Bereich wird enger.
static var AGE_LENGTH := 20
static var NATURE_MIN_STEP := 0.02        # pro Zeitalter mehr Natur nötig …
static var NATURE_MIN_MAX := 0.42
static var CIVILISATION_MAX_STEP := 0.02  # … und weniger Zivilisation erlaubt
static var CIVILISATION_MAX_MIN := 0.28
# 40 Runden: am Ende zählt der Glaube.
static var MAX_ROUNDS := 40
static var STARS := [50, 120, 220]        # Glaube für 1, 2, 3 Sterne

# --- Bedienung (etwas behäbig, damit es sich schwer und echt anfühlt) ----------------
static var TWIST_SNAP_SECONDS := 0.42
static var TWIST_FINGER_UNITS := 2.1      # Fingerweg (in Würfelfeldern) für eine Vierteldrehung
static var TWIST_FOLLOW := 9.0            # wie schnell die Scheibe dem Finger folgt (kleiner = träger)
static var DRAG_START_PX := 12.0
static var HINT_AFTER_SECONDS := 8.0      # so lange nichts getan, dann pulsiert eine lohnende Scheibe
static var TUTORIAL_HINT_ROUNDS := 3      # in den ersten Runden kommt der Tipp sofort
