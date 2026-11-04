# God does play dice! – Prototyp „Leiter“

Die Welt ist ein Zauberwürfel. Du bist ihr Gott und drehst die Welt, damit sie sich entwickelt,
ohne die Natur zu zerstören.

Godot 4.3, GDScript, Renderer „Compatibility“. Hochformat, Handy zuerst; PC-Versionen für Windows und Linux.

**Testversion:** GitHub → Releases → `dice-testversion` (Android-APK, Windows-EXE, Linux-ZIP).
Jeder Push baut sie neu. Screenshots aus dem Build: [`docs/screenshots`](docs/screenshots),
gesammelte Ideen: [`docs/IDEEN.md`](docs/IDEEN.md).

## Spielregeln (einfaches Punkte-Spiel)

1. **Start:** leere Erde und Wiesen, nie drei Wiesen beisammen.
2. **Die Leiter:** Erde · Wiese → kleiner Wald → großer Wald → Hütte → Haus → Dorf → Stadt → Großstadt → Metropole.
3. **Verschmelzen:** Bildest du durch einen Zug eine **neue** Reihe aus drei gleichen Feldern (oder Spalte; diagonal in Einfach schon ab der Wiese, in Mittel ab dem kleinen Wald), entwickeln sie sich. Reihen, die schon dastanden, zählen nicht:
   Das Feld, das zuletzt dazugekommen ist, steigt eine Stufe auf, die beiden anderen bleiben, wie sie sind.
   Das gibt Punkte (je höher die Stufe, desto mehr). **Kombo:** Jede weitere Verschmelzung im selben Zug zählt mehr (×2, ×3 …).
   **Ganze Seite** aus 9 gleichen Feldern: Die ganze Seite steigt eine Stufe auf (Punkte × 9) und bleibt stehen.
4. **Fehlversuch** = Drehung, die nichts verschmilzt (oben als Flammen). Jeder **3. Fehlversuch** setzt die
   gewischte Reihe in **Brand**. Der Zähler läuft weiter, ein Erfolg setzt ihn nicht zurück.
   Im nächsten Zug verliert jedes brennende Feld eine Stufe, dann ist das Feuer aus. Regen vorher rettet ein Feld.
5. **Boni aus Punkten:** **Regen** (alle 12 Punkte) hebt ein Feld der gerade niedrigsten Stufe eine Stufe (erst Erde, dann Wiese …) oder löscht ein Feuer.
   **Blitz**: gibt es für drei gleiche Felder an einer Würfelecke. Auf ein Eckfeld getippt, hebt er die Diagonale dieser Seite (3 Felder). Blitz und Monsun zählen als Zug, Regen nicht: Man kann mehrmals hintereinander gießen; beim Drehen ist der Regen wieder abgewählt.
   Wiese wächst nur durch Regen.
   **Monsun** (ab der Antike, dann alle 120 Punkte): hebt alle 9 Felder einer Seite.
   Kein Bonus da? Antippen und mit Credits kaufen (Regen 2, Blitz 3, Monsun 5). Bringt ein Tipp nichts, gibt es dafür einen Regen.
6. **Nach unten geht es nur durch Brände.** (Ein Gleichgewicht Natur/Zivilisation gibt es nicht mehr.)
8. **Endlos kann die Welt nicht sterben**; ist nichts mehr zu verbinden, gibt es einen Regen geschenkt.
   **Überleben**: 3 Herzen, jeder Brand kostet eines, nach dem 3. ist die Welt tot (einmal für Credits weiterspielen).
9. **Zeitalter** folgen der höchsten erreichten Stufe: Urzeit, Steinzeit (Hütte), Antike (Haus), Mittelalter (Dorf),
   Neuzeit (Stadt), Industriezeitalter (Großstadt), Moderne (Metropole).
10. **Credits** (Münze oben): eine Währung für alle Hilfen. **Tipp** (1, schaut zwei Züge voraus), **Schritt zurück** (1),
   **Weiterspielen** nach dem Ende (2, einmal pro Spiel). Credits gibt es für eine kurze Werbung (im Prototyp ein
   Platzhalter), später auch im Shop. Im Tutorial sind Tipps gratis.
11. **Stufen** (Menü): **Einfach** – eine neue Reihe löst aus, dann steigen alle gleichen Felder auf, die damit zusammenhängen (jede Reihe zählt nur einmal); **Mittel** – Reihen und
   Diagonalen; **Schwer** – nur gerade Reihen; **Profi** – nur gerade Reihen, ohne Regen, Blitz, Monsun und Tipp.
   Dazu die Modi 40 Drehungen (gezählt werden nur Drehungen) und Überleben (3 Herzen). Rekord = Punkte je Stufe.

Oben stehen nur die Punkte, die Entwicklungsstufe (höchste erreichte Stufe), die Leben und die Fehlversuche.

**Tutorial:** Im allerersten Spiel zeigt der Würfel in den ersten 5 Runden, welche Scheibe sich lohnt,
und was eine Drehung bringt. Danach nur noch die Warnung vor Katastrophen. Im Menü: „Tutorial nochmal“.

Alle Zahlen stehen in [`scripts/balance.gd`](scripts/balance.gd).
**Tutorial:** Das allererste Spiel ist „Einfach“ (dort zählen auch Wiesen diagonal). Der erste Zug wird vorgezeigt
(Finger wischt, Scheibe dreht an). Eine Karte führt Schritt für Schritt durch Drehen, Verschmelzen, Fehlversuche, Regen,
Blitz und Credits. Es geht erst weiter, wenn man die erklärte Aktion ausführt oder „Weiter“ tippt. Im Menü: „Tutorial nochmal“.

## Bedienung

| Geste | Wirkung |
|---|---|
| Wischen auf dem Würfel | Reihe drehen (loslassen rastet ein; rote Felder = dort droht eine Katastrophe) |
| Wischen daneben, oder 1 s auf dem Würfel halten und ziehen | Ansicht drehen, mit Nachschwung |
| Zwei Finger / Mausrad | Zoom; zwei Finger verschieben = schwenken, drehen = um die Blickachse drehen |
| Handy schwenken | Würfel neigt sich leicht mit |
| Feld antippen | Info-Karte: was das Feld braucht und was gerade passiert |
| Feld antippen | Info-Karte mit „Gießen“ / „Löschen“ und „Blitz“ (wenn vorhanden) |
| „Regen bereit“ über dem Würfel | du kannst gießen: antippen, dann ein Feld wählen |
| 🔥 1/3 unten | Fehlversuche bis zum nächsten Brand |
| Dock unten (Mitte): Regen / Blitz / Monsun, daneben die Flammen | Bonus wählen (Regen: Erde antippen, mehrmals; Blitz: Eckfeld antippen). Links „Zurück“, rechts „Tipp“, Hilfe im Menü |
| Beim Drehen auf „Abbrechen“ ziehen | Drehung abbrechen, zählt nicht als Zug |

## Aufbau

```
scripts/
  balance.gd      alle Zahlen
  field_data.gd   Feld-Daten
  game_state.gd   reine Spiellogik (Runde auswerten, Gefahren), kopierbar für die Vorschau
  game.gd         Autoload: Rundenablauf, Rekord, Signale
  world.gd        Würfel, Wisch-Drehen, Vorschau, Effekte, Kamera-Eingabe
  field_view.gd   Darstellung eines Felds
  models.gd       prozedurale Spielzeug-Modelle (abgerundete Formen)
  camera_rig.gd   Kamera mit Licht, passt sich dem Bildschirm an
  ui.gd           Oberfläche
  style.gd        Schrift (Manrope), Symbole, Farben
  main.gd         Start, Skalierung, automatische Screenshots (-- --shots=ORDNER)
shaders/tilt_shift.gdshader   Miniatur-Unschärfe
icons/          eigene SVG-Symbole
fonts/          Manrope (SIL Open Font License)
tests/test_rules.gd           Regeltests
docs/           altes GDD, alter Browser-Prototyp, Screenshots
```

### Tests lokal

```bash
godot --headless --import
godot --headless --script res://tests/test_rules.gd
```
