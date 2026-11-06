class_name Balance
extends RefCounted
## Zentrale Balancing-Datei: ALLE Spielzahlen stehen hier.

# --- gdpd: Arten, Wahl und Glaube (docs/GDPD_7_TAGE.md Abschnitt 1, GDPD_REGELN.md Abschnitt 13) -----
# Die Arten stehen in FieldData (Art-Tabelle). Drei gleiche in einer NEUEN Reihe wachsen:
#   Erde → Wiese → Wald | Acker, Wald → Großer Wald → Tiere → Hütte | Paradies ★ (nur freies Spiel), Acker → Hütte,
#   Hütte → Haus → Dorf → Stadt | Kirche ★, Stadt → Großstadt | Industrie ★, Großstadt → Metropole ★. Wasser: nie.
#   ★ = fertig: wächst nicht mehr, bildet keine Reihe, bringt jede Drehung Glauben.
static var MAX_STAGE := 15                # höchste Art-Nummer (alter Name, Oberfläche)
static var KIND_COUNT := 16
# Glaube fürs Wachsen nach Stufe (tier) der Art vor dem Wachsen, × Kombo.
static var GROW_FAITH := [0, 2, 4, 7, 11, 16, 24, 35, 50, 75, 100]
static var MERGE_POINTS := GROW_FAITH     # alter Name
static var MAX_CASCADES := 6
static var OTHERS_DROP := 0               # die beiden anderen Felder der Reihe bleiben
static var DIAGONAL_FROM := 2             # Mittel: Diagonalen ab Stufe 2 (Einfach ab 1, Schwer nie)
static var DIAGONAL_FROM_EASY := 1
static var FACE_BONUS := 9                # ganze Seite: Glaube der Stufe × so viel

# --- Start (freies Spiel, GDPD_7_TAGE.md 3.2: vorläufig) ---------------------------------
# So viele Felder je Art, nach Sticker-Art verteilt (etwa die Hälfte auf Ecken), dann fertige Reihen auflösen.
static var START_KINDS := {FieldData.MEADOW: 26, FieldData.EMPTY: 24, FieldData.WATER: 4}
static var START_CORNER_SHARE := 0.5      # Anteil jeder Art auf Ecken …
static var START_CENTER_SHARE := 0.1      # … und auf Mitten (der Rest auf Kanten)
static var START_MEADOW := 0.5            # alt (v1.1-Würfeln), nicht mehr benutzt
static var START_NATURE := 0.40

# --- Jede Drehung ------------------------------------------------------------------
# Glaube pro Drehung von fertigen Feldern (nicht bei Smog, nie bei Regen/Werkzeugen).
static var INCOME := {FieldData.CHURCH: 3, FieldData.INDUSTRY: 5, FieldData.METROPOLIS: 2, FieldData.PARADISE: 1}
# Weltwaage W = 100·(C − N)/(C + N): −100 nur Natur … +100 nur Stadt.
static var NATURE_WEIGHT := {FieldData.MEADOW: 1, FieldData.FOREST: 2, FieldData.BIGFOREST: 3, FieldData.ANIMALS: 3, FieldData.PARADISE: 4}
static var CIV_WEIGHT := {FieldData.FIELD: 1, FieldData.HUT: 1, FieldData.HOUSE: 2, FieldData.VILLAGE: 2, FieldData.TOWN: 3,
	FieldData.CHURCH: 2, FieldData.BIGCITY: 4, FieldData.METROPOLIS: 5, FieldData.INDUSTRY: 6}
static var WILD_AT := -50                 # W ≤ das: Wildnis (Menschen wünschen sich einen Acker)
static var CITY_AT := 20                  # W ≥ das: viel Stadt (Wünsche: Wald, Tiere, Regen)
static var SMOG_AT := 50                  # W ≥ das: Smog (kein Glaube pro Drehung, Industrie lässt Natur welken, kein Nachwachsen)
static var REGROW_PER_TWIST := 1          # so viele Erde-Felder werden pro Drehung wieder Wiese …
static var REGROW_NEIGHBORS := 2          # … wenn sie so viele Natur-Nachbarn haben
static var REGROW_PER_ROUND := 1          # alter Name

# --- Krieg ------------------------------------------------------------------------
static var WAR_FAITH_MIN := 20            # Krieg kostet max(20, 20 % des Glaubens)
static var WAR_FAITH_PCT := 20
static var WAR_DROP := FieldData.HOUSE    # Kirchen im Krieg werden Haus

# --- Wünsche ------------------------------------------------------------------------
static var WISH_EVERY := 4                # bei Drehung 4, 8, 12 …
static var WISH_FROM_TWIST := 3
static var WISH_MAX := 2
static var WISH_TWISTS := 8               # so viele Drehungen Zeit
static var WISH_FAITH := 15

# --- Katastrophen ------------------------------------------------------------------------
static var LIVES := 3                     # Herzen (Mittel, Schwer, Challenge)
static var LIVES_EASY := 5                # Herzen in Einfach
static var FIRE_AFTER := 3                # jeder so vielte Fehlversuch (Drehung ohne Wachsen) setzt die Reihe in Brand
static var FIRE_COSTS_LIFE := true

# --- Werkzeuge (Dock) ---------------------------------------------------------------------
static var RAIN_START := 1                # Regen: Erde → Wiese → Wald → Großer Wald, oder löscht Feuer
static var RAIN_EVERY_TWISTS := 5         # alle so viele Drehungen ein Regen …
static var RAIN_MAX := 3                  # … bis höchstens so viele
static var RAIN_EVERY := RAIN_EVERY_TWISTS   # alter Name
static var BOLT_START := 0                # Blitz: für drei gleiche Felder an einer Würfelecke
static var BOLT_MAX := 2
static var MONSOON_EVERY_FAITH := 150     # Monsun: ab dem ersten Haus, dann alle so viel verdienter Glaube
static var MONSOON_EVERY := MONSOON_EVERY_FAITH   # alter Name
static var MONSOON_MAX := 1
static var STRIKE_COST := 15              # Gewitter (Strafe): kostet Glauben
static var FLOOD_COST := 40               # Flut (Strafe): kostet Glauben
# Kaufen mit Münzen, wenn keiner da ist
static var RAIN_COST := 2
static var BOLT_COST := 3
static var MONSOON_COST := 5

# --- Wahl-Karte -----------------------------------------------------------------------------
static var CHOICE_TIMEOUT := 6.0          # so lange wartet die Karte, dann gilt der Standard (deine letzte Wahl)
static var CHOICE_FULL_CARDS := 3         # so oft pro Art die große Karte, danach die kleine Pille
static var MINI_CARD_SECONDS := 2.0
static var OTHER_CHOICE_HABIT := true      # weitere Wahl im selben Zug (ohne Karte): true = Gewohnheit (Spec), false = immer Option 1 (Python-Modell)

# --- Ziel und Modi ------------------------------------------------------------------------------
static var COMPLETE_AT := [36, 18, 16]    # Vollendet (vorläufig, GDPD_7_TAGE.md 3.2): so viele fertige Felder (Einfach, Mittel, Schwer) …
static var COMPLETE_BONUS_PCT_PER_HEART := 10   # … und WILD_AT < W < SMOG_AT. Bonus: so viel % Glaube pro Herz
static var AGES := ["Urzeit", "Steinzeit", "Antike", "Mittelalter", "Neuzeit", "Industriezeitalter", "Moderne"]
## Eine typische Art je Zeitalter (für Icons; alter Name).
static var AGE_FROM_STAGE := [FieldData.MEADOW, FieldData.HUT, FieldData.HOUSE, FieldData.VILLAGE, FieldData.TOWN, FieldData.BIGCITY, FieldData.METROPOLIS]
static var AGE_GOAL := ["Steinzeit – Acker oder Hütte.", "Antike – ein Haus.", "Mittelalter – ein Dorf.",
	"Neuzeit – Stadt oder Kirche.", "Industriezeitalter – Großstadt oder Industrie.", "Moderne – eine Metropole.",
	"Vollende deine Welt!"]
# Challenge: 40 Drehungen nach Mittel-Regeln, so viel Glauben wie möglich.
static var MAX_TWISTS := 40

# --- Die Schöpfung in 7 Tagen (GDPD_7_TAGE.md; die Tag-Tabelle steht in Days) -------------------
static var MERCY_TWISTS := 2               # jeder Fehlversuch eines Tages: nächster Versuch so viele Drehungen mehr …
static var MERCY_MAX := 6                  # … höchstens so viele
static var DAY_HINT_FREE := true           # Tipp kostet an den Tagen nichts (Produktentscheidung, 4.6)
static var DAY_ONBOARD_HINT_DAYS := 2      # Tag 1–2: der Tipp leuchtet nach einer Pause von selbst

# --- Täglich spielen (GDPD_TAEGLICH_CHARAKTER.md 1, 2, 5; Logik in Daily und ReminderPlan) ----------------
static var DAY_START_HOUR := 3             # der Spieltag wechselt um 3 Uhr Ortszeit
static var COUNTDOWN_EXACT_HOURS := 8      # mehr als so viele Stunden bis zum neuen Tag: genaue Zeit, sonst „Morgen früh“
static var SHIELD_MAX := 2                 # Serienschutz: höchstens so viele …
static var SHIELD_PRICE := 5               # … kaufen für so viele Münzen …
static var STREAK_MILESTONE := 7           # … und einer geschenkt alle so viele Tage in Folge
static var SHIELD_FULL_COINS := 3          # Meilenstein mit vollem Serienschutz: so viele Münzen statt dessen
static var STREAK_BIG := [7, 14, 30, 50, 100, 365]   # Meilensteine mit großer Feier
static var BUILD_COIN_EVERY := 10          # Weiterbauen: 1 Münze je so viele gewachsene Felder …
static var BUILD_COIN_MAX := 3             # … höchstens so viele je Spieltag
static var REMIND_EARLIEST := 480          # Erinnerungen nie vor 8:00 …
static var REMIND_LATEST := 1290           # … und nie nach 21:30 (Minuten des Tages)
static var REMIND_LEAD := 30               # so viele Minuten vor der Uhrzeit der letzten Sitzung (≈ 23,5 h danach)
static var REMIND_DEFAULT_MIN := 1080      # unbekannte Uhrzeit / Standard für „Feste Uhrzeit“: 18:00
static var REMIND_LADDER := [1, 2, 4, 7]   # Tage nach dem letzten Besuch: A, B, C, dann die letzte Nachricht (F)
static var REMIND_MIN_GAP := 7200          # nie innerhalb von 2 Stunden nach jetzt
static var REMIND_LIEB_SHARE := 0.15       # frech/streng: so oft ein lieber Text (bleibt freundlich und abwechslungsreich)

# --- Bedienung (etwas behäbig, damit es sich schwer und echt anfühlt) ----------------
static var TWIST_SNAP_SECONDS := 0.42
static var TWIST_FINGER_UNITS := 2.5      # Fingerweg (in Würfelfeldern) für eine Vierteldrehung
static var TWIST_FOLLOW := 6.0            # wie schnell die Scheibe dem Finger folgt (kleiner = träger)
static var TWIST_DETENT := 2.4            # wie stark die Scheibe zur nächsten Rastung zieht (1 = gar nicht)
static var DRAG_START_PX := 12.0
static var TWIST_AUTO_MARGIN_PX := 56.0    # Finger so weit neben dem Würfel gehalten (in Drehrichtung, auch oben/unten): die Scheibe dreht von selbst weiter …
static var TWIST_EDGE_PX := 70.0           # … ebenso, wenn er so nah am Bildschirmrand gehalten wird …
static var TWIST_AUTO_SECONDS := 0.6       # … gleichmäßig eine Vierteldrehung in so vielen Sekunden (mit Rastung)
static var TWIST_AUTO_DWELL_SECONDS := 0.25 # … aber erst, wenn der Finger so lange draußen liegt …
static var TWIST_AUTO_MIN_QUARTER := 0.75   # … und (neben dem Würfel) die Hand schon so viel von einem Viertel gedreht hat
static var CUBE_HALF := 1.5                # halbe Würfelkante (Weltmaß) für den Umriss auf dem Bildschirm
static var CANCEL_ENTER_PX := 6.0          # Abbrechen-Streifen oben: so weit unter seiner Unterkante zählt der Finger schon als „drauf“ …
static var CANCEL_LEAVE_PX := 26.0         # … und erst so weit darunter wieder als „weg“ (kein Flackern)
static var TILT_MAX := 0.3                # Handy schwenken: so weit (Bogenmaß, ~17°) neigt sich die Ansicht höchstens. 0 = aus
static var HOLD_TO_ORBIT_SECONDS := 1.0  # so lange auf dem Würfel halten (ohne Bewegen), dann dreht Ziehen die Ansicht
# Credits: eine Währung für alle Hilfen. Es gibt sie für eine kurze Werbung (später auch im Shop).
static var HINT_COST := 1                 # Tipp: die lohnendste Drehung leuchtet auf
static var UNDO_COST := 1                 # einen Schritt zurück
static var CONTINUE_COST := 2             # nach dem Spielende weiterspielen (einmal pro Spiel)
static var CREDITS_PER_AD := 1            # so viele Credits bringt eine Werbung
static var CREDITS_START := 3             # so viele Credits zum Ausprobieren
# Neue Spieler: die ersten Minuten nach dem Tutorial
static var ONBOARD_MERGES := 2            # so oft selbst etwas wachsen lassen, dann ist die Eingewöhnung vorbei …
static var ONBOARD_TWISTS := 12           # … oder nach so vielen Drehungen
static var ONBOARD_HINT_SECONDS := 6.0    # in der Eingewöhnung leuchtet nach so langer Pause die passende Reihe (gratis)
