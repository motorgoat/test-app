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
# Wert eines Verschmelzens nach Stufe (Index = Stufe), × Kombo. Nur intern: für Tipps und den Test-Bot.
static var MERGE_POINTS := [0, 2, 4, 7, 11, 16, 24, 35, 50, 75]
static var MAX_CASCADES := 6

# --- Start ----------------------------------------------------------------------
static var START_MEADOW := 0.5            # Anteil Wiesen, der Rest ist leere Erde

# --- Jede Runde -------------------------------------------------------------------
static var REGROW_NEIGHBORS := 2          # leere Erde wird Wiese bei so vielen Natur-Nachbarn
static var REGROW_PER_ROUND := 2          # höchstens so viele Felder wachsen pro Runde nach (die mit der meisten Natur)
static var POLLUTION_FROM := 8            # ab dieser Stufe (Großstadt) wird Natur daneben zerstört
static var POLLUTION_PER_FIELD := 1       # so viele Natur-Nachbarn pro Runde

# --- Gleichgewicht ------------------------------------------------------------------
static var NATURE_MIN := 0.30             # mindestens so viel Natur (Wiese, Wälder), sonst Überschwemmung
static var NATURE_MAX := 0.75             # höchstens so viel Natur, sonst Waldbrand
static var CIVILISATION_MAX := 0.40       # höchstens so viel Zivilisation (ab Hütte), sonst Erdbeben

# --- Katastrophen (Strafe, wenn eine Runde außerhalb des Gleichgewichts endet) -------
static var LIVES := 3                     # so viele Katastrophen hält die Welt aus
static var QUAKE_DROP := 2                # Erdbeben: die größte Siedlung fällt so viele Stufen, Siedlungen daneben eine
static var FLOOD_FIELDS := 3              # Überschwemmung: so viele kleinste Siedlungen werden weggespült

# --- Meteorit -------------------------------------------------------------------------
static var METEOR_START := 1              # so viele Meteoriten hast du am Anfang
static var METEOR_EVERY := 10             # alle so viele Runden kommt einer dazu …
static var METEOR_MAX := 2                # … bis höchstens so viele

# --- Modi ------------------------------------------------------------------------------
# Endlos: alle AGE_LENGTH Runden ein neues Zeitalter: ein Leben zurück, aber der gesunde Bereich wird enger.
static var AGE_LENGTH := 20
static var NATURE_MIN_STEP := 0.02        # pro Zeitalter mehr Natur nötig …
static var NATURE_MIN_MAX := 0.40
static var NATURE_MAX_STEP := 0.03        # … weniger Natur erlaubt (die Menschen brauchen Platz) …
static var NATURE_MAX_MIN := 0.60
static var CIVILISATION_MAX_STEP := 0.01  # … und etwas weniger Zivilisation
static var CIVILISATION_MAX_MIN := 0.35
# 40 Runden: Sterne für die höchste erreichte Stufe.
static var MAX_ROUNDS := 40
static var STAR_STAGES := [6, 7, 9]       # Dorf, Stadt, Metropole = 1, 2, 3 Sterne

# --- Bedienung (etwas behäbig, damit es sich schwer und echt anfühlt) ----------------
static var TWIST_SNAP_SECONDS := 0.42
static var TWIST_FINGER_UNITS := 2.1      # Fingerweg (in Würfelfeldern) für eine Vierteldrehung
static var TWIST_FOLLOW := 9.0            # wie schnell die Scheibe dem Finger folgt (kleiner = träger)
static var DRAG_START_PX := 12.0
static var HOLD_TO_ORBIT_SECONDS := 1.0  # so lange auf dem Würfel halten (ohne Bewegen), dann dreht Ziehen die Ansicht
static var TUTORIAL_ROUNDS := 5           # im allerersten Spiel: so viele Runden mit Drehtipps und Vorschau
