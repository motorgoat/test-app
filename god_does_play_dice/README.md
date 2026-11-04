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
3. **Verschmelzen:** Drei gleiche Felder in einer Reihe (oder Spalte) entwickeln sich, sobald sich darin etwas verändert hat:
   Das Feld, das zuletzt dazugekommen ist, steigt eine Stufe auf, die beiden anderen bleiben, wie sie sind.
   Das gibt Punkte (je höher die Stufe, desto mehr, Kettenreaktionen zählen mehrfach).
   **Ganze Seite** aus 9 gleichen Feldern: Die ganze Seite steigt eine Stufe auf (Punkte × 9) und bleibt stehen.
4. **Fehlversuch** = Drehung, die nichts verschmilzt (oben als Flammen). Jeder **3. Fehlversuch** setzt die
   gewischte Reihe in **Brand**. Der Zähler läuft weiter, ein Erfolg setzt ihn nicht zurück.
   Brennende Felder verlieren jeden Zug eine Stufe, bis sie Erde sind oder Regen sie löscht.
5. **Boni aus Punkten:** **Regen** (alle 12 Punkte) hebt ein Feld eine Stufe oder löscht ein Feuer.
   **Blitz** (alle 40 Punkte) hebt eine ganze Reihe eine Stufe. Ein Bonus zählt als Zug.
   Wiese wächst nur durch Regen.
6. **Nach unten geht es nur durch Katastrophen** (Brand, Erdbeben).
7. **Mehr als 40 % Zivilisation:** **Erdbeben**, die Reihe mit der meisten Zivilisation fällt eine Stufe zurück.
8. Ein Erdbeben kostet ein **Leben** der Welt (3 Leben). Ohne Leben ist das Spiel vorbei, ebenso wenn nichts mehr
   zu verbinden ist (keine Stufe mit 3 Feldern, kein Regen, kein Blitz).
9. **Zeitalter** folgen der höchsten erreichten Stufe: Urzeit, Steinzeit (Hütte), Bronzezeit (Haus), Antike (Dorf),
   Mittelalter (Stadt), Industriezeitalter (Großstadt), Moderne (Metropole). Jedes neue gibt ein Leben zurück.
10. **Tipp** (Glühbirne): Die lohnendste Drehung leuchtet auf. Kostet 1 Credit, Credits gibt es für Werbung
   (im Prototyp ein Platzhalter). Im Tutorial sind Tipps gratis.
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
| Regen / Blitz unten | Bonus wählen, dann das Feld antippen (Blitz: dessen waagrechte Reihe) |

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
  style.gd        Schrift (Nunito), Symbole, Farben
  main.gd         Start, Skalierung, automatische Screenshots (-- --shots=ORDNER)
shaders/tilt_shift.gdshader   Miniatur-Unschärfe
icons/          eigene SVG-Symbole
fonts/          Nunito (SIL Open Font License)
tests/test_rules.gd           Regeltests
docs/           altes GDD, alter Browser-Prototyp, Screenshots
```

### Tests lokal

```bash
godot --headless --import
godot --headless --script res://tests/test_rules.gd
```
