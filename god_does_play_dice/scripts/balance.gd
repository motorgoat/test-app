class_name Balance
extends RefCounted
## Zentrale Balancing-Datei: ALLE Spielzahlen stehen hier.

# --- Die Leiter -------------------------------------------------------------------
# Drei gleiche in einer Reihe verschmelzen, wenn DEINE Drehung die Reihe vervollständigt:
#   das zuletzt dazugekommene Feld steigt eine Stufe auf, die beiden anderen bleiben, wie sie sind.
#   Erde (0) · Wiese (1) → kleiner Wald (2) → großer Wald (3) → Hütte (4) → Haus (5)
#   → Dorf (6) → Stadt (7) → Großstadt (8) → Metropole (9)
#   Natur = Stufe 1–3, Zivilisation = ab Stufe 4.
static var MAX_STAGE := 9
static var NATURE_STAGES := [1, 3]
static var CIVILISATION_FROM := 4
# Punkte fürs Verschmelzen nach Stufe (Index = Stufe), × Kombo.
static var MERGE_POINTS := [0, 2, 4, 7, 11, 16, 24, 35, 50, 75]
static var MAX_CASCADES := 6
static var EASY_REFILL_MEADOW := 0.5      # Einfach: verbrauchte Felder füllen sich mit dieser Wahrscheinlichkeit mit Wiese, sonst Erde
static var OTHERS_DROP := 0               # um so viele Stufen fallen die beiden anderen Felder der Reihe zurück (0 = bleiben)
static var DIAGONAL_FROM := 2             # ab dieser Stufe (kleiner Wald) zählen auch Diagonalen als Reihe
static var FACE_BONUS := 9               # ganze Seite geschafft: Punkte der Stufe × so viel

# --- Start ----------------------------------------------------------------------
static var START_MEADOW := 0.5            # Anteil Wiesen beim Würfeln, der Rest ist leere Erde …
static var START_NATURE := 0.40           # … nie drei Wiesen beisammen, dann bis zu diesem Anteil auffüllen

# --- Jede Runde -------------------------------------------------------------------
static var REGROW_NEIGHBORS := 2          # leere Erde wird Wiese bei so vielen Natur-Nachbarn
static var REGROW_PER_ROUND := 0          # höchstens so viele Felder wachsen pro Runde nach (die mit der meisten Natur). 0 = Wiese wächst nie von allein
static var POLLUTION_FROM := 99           # ab dieser Stufe wird Natur daneben zerstört (99 = aus: nach unten geht es nur durch Katastrophen)
static var POLLUTION_PER_FIELD := 1       # so viele Natur-Nachbarn pro Runde

# --- Katastrophen ------------------------------------------------------------------------
static var LIVES := 3                     # Überleben-Modus: so viele Herzen; jeder Brand kostet eines
static var FIRE_AFTER := 3                # jeder so vielte Fehlversuch (Drehung ohne Verschmelzen) setzt die Reihe in Brand
static var FIRE_COSTS_LIFE := false       # kostet ein Brand ein Leben?

# --- Boni ------------------------------------------------------------------------------
static var RAIN_START := 1                # Regen: hebt ein Feld eine Stufe oder löscht es
static var RAIN_EVERY := 12               # alle so viele Punkte ein Regen …
static var RAIN_MAX := 3                  # … bis höchstens so viele
static var BOLT_START := 0                # Blitz: gibt es für drei gleiche Felder an einer Würfelecke;
static var BOLT_EVERY := 999999           #   (nicht mehr für Punkte)
static var BOLT_MAX := 2                  #   eingesetzt auf ein Eckfeld hebt er die Diagonale dieser Seite
static var MONSOON_FROM_STAGE := 5        # Monsun (hebt eine ganze Seite): freigeschaltet ab dem ersten Haus (Antike) …
static var MONSOON_EVERY := 120           # … danach alle so viele Punkte einer
static var MONSOON_MAX := 1
# Kaufen mit Credits, wenn keiner da ist
static var RAIN_COST := 2
static var BOLT_COST := 3
static var MONSOON_COST := 5

# --- Modi ------------------------------------------------------------------------------
# Zeitalter: bestimmt die höchste erreichte Stufe. Jedes neue Zeitalter gibt ein Leben zurück.
static var AGES := ["Urzeit", "Steinzeit", "Antike", "Mittelalter", "Neuzeit", "Industriezeitalter", "Moderne"]
static var AGE_FROM_STAGE := [1, 4, 5, 6, 7, 8, 9]   # Hütte = Steinzeit, Haus = Antike, Dorf = Mittelalter, Stadt = Neuzeit …
# 40 Drehungen: so viele Punkte wie möglich (gezählt werden nur Drehungen).
static var MAX_TWISTS := 40

# --- Bedienung (etwas behäbig, damit es sich schwer und echt anfühlt) ----------------
static var TWIST_SNAP_SECONDS := 0.42
static var TWIST_FINGER_UNITS := 2.5      # Fingerweg (in Würfelfeldern) für eine Vierteldrehung
static var TWIST_FOLLOW := 6.0            # wie schnell die Scheibe dem Finger folgt (kleiner = träger)
static var TWIST_DETENT := 2.4            # wie stark die Scheibe zur nächsten Rastung zieht (1 = gar nicht)
static var DRAG_START_PX := 12.0
static var TWIST_EDGE_PX := 70.0           # Finger so nah am Rand gehalten: die Scheibe dreht von selbst weiter …
static var TWIST_EDGE_SECONDS := 0.6        # … eine Vierteldrehung in so vielen Sekunden
static var TILT_MAX := 0.3                # Handy schwenken: so weit (Bogenmaß, ~17°) neigt sich die Ansicht höchstens. 0 = aus
static var HOLD_TO_ORBIT_SECONDS := 1.0  # so lange auf dem Würfel halten (ohne Bewegen), dann dreht Ziehen die Ansicht
# Credits: eine Währung für alle Hilfen. Es gibt sie für eine kurze Werbung (später auch im Shop).
static var HINT_COST := 1                 # Tipp: die lohnendste Drehung leuchtet auf
static var UNDO_COST := 1                 # einen Schritt zurück
static var CONTINUE_COST := 2             # nach dem Spielende weiterspielen (einmal pro Spiel)
static var CREDITS_PER_AD := 1            # so viele Credits bringt eine Werbung
static var CREDITS_START := 3             # so viele Credits zum Ausprobieren
static var TUTORIAL_ROUNDS := 5           # im allerersten Spiel: so viele Runden mit Drehtipps und Vorschau
