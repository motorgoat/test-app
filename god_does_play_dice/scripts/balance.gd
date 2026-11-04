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
static var OTHERS_DROP := 0               # um so viele Stufen fallen die beiden anderen Felder der Reihe zurück (0 = bleiben)
static var FACE_BONUS := 9               # ganze Seite geschafft: Punkte der Stufe × so viel

# --- Start ----------------------------------------------------------------------
static var START_MEADOW := 0.5            # Anteil Wiesen beim Würfeln, der Rest ist leere Erde …
static var START_NATURE := 0.40           # … nie drei Wiesen beisammen, dann bis zu diesem Anteil auffüllen

# --- Jede Runde -------------------------------------------------------------------
static var REGROW_NEIGHBORS := 2          # leere Erde wird Wiese bei so vielen Natur-Nachbarn
static var REGROW_PER_ROUND := 0          # höchstens so viele Felder wachsen pro Runde nach (die mit der meisten Natur). 0 = Wiese wächst nie von allein
static var POLLUTION_FROM := 99           # ab dieser Stufe wird Natur daneben zerstört (99 = aus: nach unten geht es nur durch Katastrophen)
static var POLLUTION_PER_FIELD := 1       # so viele Natur-Nachbarn pro Runde

# --- Gleichgewicht ------------------------------------------------------------------
static var CIVILISATION_MAX := 0.40       # höchstens so viel Zivilisation (ab Hütte), sonst Erdbeben

# --- Katastrophen ------------------------------------------------------------------------
static var LIVES := 0                     # Leben der Welt (Erdbeben kosten eines). 0 = keine Leben, keine Herzen
static var FIRE_AFTER := 3                # jeder so vielte Fehlversuch (Drehung ohne Verschmelzen) setzt die Reihe in Brand
static var FIRE_COSTS_LIFE := false       # kostet ein Brand ein Leben?

# --- Boni ------------------------------------------------------------------------------
static var RAIN_START := 1                # Regen: hebt ein Feld eine Stufe oder löscht es
static var RAIN_EVERY := 12               # alle so viele Punkte ein Regen …
static var RAIN_MAX := 3                  # … bis höchstens so viele
static var BOLT_START := 0                # Blitz: hebt eine ganze Reihe eine Stufe
static var BOLT_EVERY := 40
static var BOLT_MAX := 2

# --- Modi ------------------------------------------------------------------------------
# Zeitalter: bestimmt die höchste erreichte Stufe. Jedes neue Zeitalter gibt ein Leben zurück.
static var AGES := ["Urzeit", "Steinzeit", "Bronzezeit", "Antike", "Mittelalter", "Industriezeitalter", "Moderne"]
static var AGE_FROM_STAGE := [1, 4, 5, 6, 7, 8, 9]   # ab dieser Stufe beginnt das Zeitalter (Hütte = Steinzeit …)
# 40 Runden: so viele Punkte wie möglich.
static var MAX_ROUNDS := 40

# --- Bedienung (etwas behäbig, damit es sich schwer und echt anfühlt) ----------------
static var TWIST_SNAP_SECONDS := 0.42
static var TWIST_FINGER_UNITS := 2.1      # Fingerweg (in Würfelfeldern) für eine Vierteldrehung
static var TWIST_FOLLOW := 9.0            # wie schnell die Scheibe dem Finger folgt (kleiner = träger)
static var DRAG_START_PX := 12.0
static var TILT_MAX := 0.16               # Handy schwenken: so weit (Bogenmaß, ~9°) neigt sich die Ansicht höchstens. 0 = aus
static var HOLD_TO_ORBIT_SECONDS := 1.0  # so lange auf dem Würfel halten (ohne Bewegen), dann dreht Ziehen die Ansicht
static var HINT_COST := 1                 # ein Tipp kostet so viele Credits (Credits gibt es für Werbung)
static var CREDITS_START := 1             # so viele Credits zum Ausprobieren
static var TUTORIAL_ROUNDS := 5           # im allerersten Spiel: so viele Runden mit Drehtipps und Vorschau
