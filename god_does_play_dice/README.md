# God does play dice! – Prototyp „Leiter“

Die Welt ist ein Zauberwürfel. Du bist ihr Gott und drehst die Welt, damit sie sich entwickelt,
ohne die Natur zu zerstören.

Godot 4.3, GDScript, Renderer „Compatibility“. Hochformat, Handy zuerst; PC-Versionen für Windows und Linux.

**Testversion:** GitHub → Releases → `dice-testversion` (Android-APK, Windows-EXE, Linux-ZIP).
Jeder Push baut sie neu. Screenshots aus dem Build: [`docs/screenshots`](docs/screenshots),
gesammelte Ideen: [`docs/IDEEN.md`](docs/IDEEN.md).

## Spielregeln (einfaches Punkte-Spiel)

1. **Start:** leere Erde und Wiesen, nie drei Wiesen beisammen und keine fertige Reihe (auch nicht schräg).
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
   Ist Regen gewählt, leuchten alle Felder, die man gießen kann (blauer Ring); beim Blitz die Eckfelder.
   Kein Bonus da? Antippen: Es steht da, wann der nächste kommt, und man kann ihn mit Münzen kaufen (Regen 2, Blitz 3, Monsun 5). Bringt ein Tipp nichts, gibt es dafür einen Regen.
6. **Nach unten geht es nur durch Brände.** (Ein Gleichgewicht Natur/Zivilisation gibt es nicht mehr.)
8. **Herzen in allen Modi:** Jede Welt hat 3 Herzen, jeder Brand kostet eines, nach dem 3. ist die Welt tot
   (einmal für Münzen weiterspielen). Ist nichts mehr zu verbinden, gibt es einen Regen geschenkt.
9. **Zeitalter** folgen der höchsten erreichten Stufe: Urzeit, Steinzeit (Hütte), Antike (Haus), Mittelalter (Dorf),
   Neuzeit (Stadt), Industriezeitalter (Großstadt), Moderne (Metropole).
10. **Münzen** (oben rechts, erscheinen, sobald man sie braucht): eine Währung für alle Hilfen. **Tipp** (1, schaut zwei Züge voraus), **Zurück** (1),
   **Weiterspielen** nach dem Ende (2, einmal pro Spiel). Münzen gibt es für ein kurzes Video (im Prototyp ein
   Platzhalter), später auch im Shop.
11. **Spielarten** (Menü, je mit Rekord): **Einfach** – eine neue Reihe löst aus, dann steigen alle gleichen Felder auf, die damit
   zusammenhängen (jede Reihe zählt nur einmal; Wiesen zählen schon schräg); **Mittel** – Reihen und Diagonalen (ab dem kleinen Wald);
   **Schwer** – nur gerade Reihen. Alle drei laufen offen, bis die Welt verbrennt. Dazu die Challenge **40 Drehungen · Mittel**
   (gezählt werden nur Drehungen). Regen, Blitz und Monsun gibt es überall. Rekord = Punkte je Spielart.

Oben stehen die Punkte, das Zeitalter, die Flammen (Fehlversuche) und die Herzen. **Halten** auf einem Symbol erklärt es.
Menü: Weiterspielen, die vier Spielarten mit Rekord, Schalter **Musik** und **Effekte** (Effekte aus = auch keine Vibration;
gespeichert in `user://einstellungen.cfg`, Busse „Music“ und „SFX“), **Profil** (kommt bald), **Hilfe**, **Tutorial**.
Tippen neben eine Karte schließt sie (nicht beim Spielende).

**Tutorial** (wie in Handyspielen üblich): Das allererste Spiel ist „Einfach“. Der Würfel dreht sich zur leuchtenden Reihe,
dann spielt sich der erste Zug von selbst und drei Wiesen wachsen. Danach „Jetzt du!“: Die Hand zeigt den Wisch, man dreht
selbst (Fehlversuche zählen im Tutorial nicht). Danach erblüht die leere Erde zu einem normalen Start, das Dock gleitet herein
und man spielt einfach weiter – kein Dialog. Neues erscheint erst, wenn man es braucht (Flammen beim ersten Fehlversuch,
Zurück nach dem ersten Feuer, Blitz beim ersten Blitz, Tipp und Münzen, wenn man feststeckt), jeweils mit einer kleinen
Sprechblase, die nie im Weg ist. In den ersten Minuten leuchtet nach einer Pause gratis die passende Reihe. Im Menü: „Tutorial nochmal“.
Alle Zahlen stehen in [`scripts/balance.gd`](scripts/balance.gd).

## Bedienung

| Geste | Wirkung |
|---|---|
| Wischen auf dem Würfel | Reihe drehen (loslassen rastet ein; rote Felder = dort droht eine Katastrophe) |
| Wischen daneben, oder 1 s auf dem Würfel halten und ziehen | Ansicht drehen, mit Nachschwung |
| Zwei Finger / Mausrad | Zoom; zwei Finger verschieben = schwenken, drehen = um die Blickachse drehen |
| Handy schwenken | Würfel neigt sich leicht mit |
| Feld antippen | Info-Karte mit „Gießen“ / „Löschen“ und „Blitz“ (wenn vorhanden) |
| Symbol halten | Erklärung (auch bei Knöpfen, die gerade nicht gehen) |
| Dock unten: Zurück · Regen · Blitz · Monsun · Tipp | Bonus wählen, dann ein leuchtendes Feld antippen (Regen mehrmals hintereinander) |
| Beim Drehen den Finger neben dem Würfel halten (links/rechts, oben/unten) | die Scheibe dreht von selbst weiter |
| Beim Drehen nach ganz oben auf den roten Streifen ziehen | Drehung abbrechen, zählt nicht als Zug |

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
