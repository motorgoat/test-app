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
3. **Verschmelzen:** Drei gleiche Felder in einer Reihe (oder Spalte, ab dem kleinen Wald auch diagonal) entwickeln sich, sobald sich darin etwas verändert hat:
   Das Feld, das zuletzt dazugekommen ist, steigt eine Stufe auf, die beiden anderen bleiben, wie sie sind.
   Das gibt Punkte (je höher die Stufe, desto mehr). **Kombo:** Jede weitere Verschmelzung im selben Zug zählt mehr (×2, ×3 …).
   **Ganze Seite** aus 9 gleichen Feldern: Die ganze Seite steigt eine Stufe auf (Punkte × 9) und bleibt stehen.
4. **Fehlversuch** = Drehung, die nichts verschmilzt (oben als Flammen). Jeder **3. Fehlversuch** setzt die
   gewischte Reihe in **Brand**. Der Zähler läuft weiter, ein Erfolg setzt ihn nicht zurück.
   Im nächsten Zug verliert jedes brennende Feld eine Stufe, dann ist das Feuer aus. Regen vorher rettet ein Feld.
5. **Boni aus Punkten:** **Regen** (alle 12 Punkte) macht leere Erde zur Wiese (nur die unterste Stufe) oder löscht ein Feuer.
   **Blitz** (alle 40 Punkte) hebt eine ganze Reihe eine Stufe. Ein Bonus zählt als Zug.
   Wiese wächst nur durch Regen.
   **Monsun** (ab der Antike, dann alle 120 Punkte): hebt alle 9 Felder einer Seite.
   Kein Bonus da? Antippen und mit Credits kaufen (Regen 2, Blitz 3, Monsun 5). Bringt ein Tipp nichts, gibt es dafür einen Regen.
6. **Nach unten geht es nur durch Katastrophen** (Brand, Erdbeben).
7. **Mehr als 40 % Zivilisation:** **Erdbeben**, die Reihe mit der meisten Zivilisation fällt eine Stufe zurück.
8. **Herzen** = Leben der Welt (3). Ein Erdbeben kostet eines, jedes neue Zeitalter gibt eines zurück.
   **Spielende:** alle Herzen weg oder nichts mehr zu verbinden (keine Stufe mit 3 Feldern, kein Regen, kein Blitz).
   Einmal pro Spiel kann man für Credits weiterspielen.
9. **Zeitalter** folgen der höchsten erreichten Stufe: Urzeit, Steinzeit (Hütte), Antike (Haus), Mittelalter (Dorf),
   Neuzeit (Stadt), Industriezeitalter (Großstadt), Moderne (Metropole). Jedes neue gibt ein Herz zurück.
10. **Credits** (Münze oben): eine Währung für alle Hilfen. **Tipp** (1, schaut zwei Züge voraus), **Schritt zurück** (1),
   **Weiterspielen** nach dem Ende (2, einmal pro Spiel). Credits gibt es für eine kurze Werbung (im Prototyp ein
   Platzhalter), später auch im Shop. Im Tutorial sind Tipps gratis.
11. **Modi:** Endlos oder 40 Runden. Rekord = Punkte.

Oben stehen nur die Punkte, die Entwicklungsstufe (höchste erreichte Stufe), die Leben und die Fehlversuche.

**Tutorial:** Im allerersten Spiel zeigt der Würfel in den ersten 5 Runden, welche Scheibe sich lohnt,
und was eine Drehung bringt. Danach nur noch die Warnung vor Katastrophen. Im Menü: „Tutorial nochmal“.

Alle Zahlen stehen in [`scripts/balance.gd`](scripts/balance.gd).
**Tutorial:** Im allerersten Spiel zeigt der Würfel in den ersten 5 Runden, welche Scheibe sich lohnt (golden pulsierend)
und was eine Drehung verschmilzt. Danach nur noch die Warnung vor Katastrophen (rote Felder). Im Menü: „Tutorial nochmal“.

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
| Regen / Blitz unten | Regen: wählen, dann Feld antippen. Blitz: wählen, dann Finger über die Reihe ziehen (jede Richtung) |
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
