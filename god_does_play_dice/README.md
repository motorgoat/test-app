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
   Natur = Wiese bis großer Wald, Zivilisation = ab Hütte.
3. **Verschmelzen:** Vervollständigst du mit einer Drehung eine Reihe (oder Spalte) aus 3 gleichen Feldern,
   steigt das Feld auf, das zuletzt dazugekommen ist. Die beiden anderen fallen eine Stufe zurück.
   Das gibt Punkte (je höher die Stufe, desto mehr, Kettenreaktionen zählen mehrfach).
   **Jede Verbindung zählt nur einmal:** Hin- und Herdrehen bringt nichts.
4. **Wiese wächst nicht von allein.** Alle 12 Punkte gibt es einen **Bonus** (höchstens 3 auf Vorrat):
   - **Regen:** leere Erde wird Wiese, die leere Erde daneben auch. Vervollständigt das eine Reihe, verschmilzt sie.
   - **Meteorit:** ein einzelnes Feld wird wieder Erde.
   Ein Bonus zählt als Zug.
5. **Großstädte und Metropolen** zerstören jede Runde ein Natur-Feld daneben.
6. **Gleichgewicht:** Natur 20–75 %, Zivilisation höchstens 40 %. Endet ein Zug daneben, schlägt eine Katastrophe zu:
   - zu viel Zivilisation → **Erdbeben**: Die größte Siedlung fällt 2 Stufen, die Siedlungen daneben je eine.
   - zu wenig Natur → **Überschwemmung**: Die 3 kleinsten Siedlungen werden weggespült.
   - zu viel Natur → **Waldbrand**: Der dichteste Wald brennt mit aller Natur daneben nieder.
   Beim Drehen leuchten die Felder rot, die es treffen würde. Die Welt hat **3 Leben**.
7. **Modi:** Endlos (alle 20 Runden ein neues Zeitalter: ein Leben zurück, der Bereich wird enger) oder 40 Runden.
   Rekord = Punkte.

Oben stehen nur die Punkte, die Entwicklungsstufe (höchste erreichte Stufe) und die Leben.

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
| Zwei Finger / Mausrad | Zoom |
| Feld antippen | Info-Karte: was das Feld braucht und was gerade passiert |
| Regen / Meteorit unten | Bonus wählen, dann das Feld antippen |

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
