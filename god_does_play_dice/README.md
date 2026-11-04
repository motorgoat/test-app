# God does play dice! – Prototyp „Leiter“

Die Welt ist ein Zauberwürfel. Du bist ihr Gott und drehst die Welt, damit sie sich entwickelt,
ohne die Natur zu zerstören.

Godot 4.3, GDScript, Renderer „Compatibility“. Hochformat, Handy zuerst; PC-Versionen für Windows und Linux.

**Testversion:** GitHub → Releases → `dice-testversion` (Android-APK, Windows-EXE, Linux-ZIP).
Jeder Push baut sie neu. Screenshots aus dem Build: [`docs/screenshots`](docs/screenshots),
gesammelte Ideen: [`docs/IDEEN.md`](docs/IDEEN.md).

## Spielregeln

1. **Start:** nur leere Erde und Wiesen.
2. **Die Leiter** (steht immer oben im Bild):
   Erde · Wiese → kleiner Wald → großer Wald → Hütte → Haus → Dorf → Stadt → Großstadt → Metropole.
   Natur = Wiese bis großer Wald, Zivilisation = ab Hütte.
3. **Verschmelzen:** Vervollständigst du durch eine Drehung eine Reihe (oder Spalte) aus 3 gleichen Feldern,
   verschmelzen sie: Die Mitte steigt eine Stufe auf, die beiden äußeren fallen eine Stufe zurück.
   Was sich dabei ändert, kann eine Kettenreaktion auslösen (Kombo). Beim Warten verschmilzt nichts.
   **Jede Verbindung zählt nur einmal:** Das Spiel merkt sich jede Reihe (dieselben drei Felder auf derselben Stufe),
   die es je gab. Hin- und Herdrehen oder eine nur mitgedrehte fertige Reihe bringt deshalb kein Upgrade.
4. **Nachwachsen:** Leere Erde mit 2 Natur-Nachbarn wird wieder Wiese, höchstens 2 Felder pro Runde.
5. **Kein Punktestand:** Es zählt, wie lange deine Welt überlebt und wie weit sie sich entwickelt.
6. **Großstädte und Metropolen** zerstören jede Runde ein Natur-Feld daneben.
7. **Gleichgewicht:** Natur 30–75 %, Zivilisation höchstens 40 %. Endet eine Runde daneben, schlägt eine Katastrophe zu:
   - zu viel Zivilisation → **Erdbeben**: Die größte Siedlung fällt 2 Stufen, die Siedlungen daneben je eine.
   - zu wenig Natur → **Überschwemmung**: Die 3 kleinsten Siedlungen werden weggespült.
   - zu viel Natur → **Waldbrand**: Der dichteste Wald brennt mit aller Natur daneben nieder.
   Beim Drehen leuchten die Felder, die es treffen würde, rot. Die Welt hat **3 Leben**, jede Katastrophe kostet eines.
8. **Meteorit:** Feld und Nachbarn werden zu Erde. Du wählst Ort und Zeitpunkt. Am Anfang hast du einen,
   alle 10 Runden kommt einer dazu (höchstens 2).
9. **Modi:**
   - **Endlos** (Standard): Alle 20 Runden beginnt ein neues Zeitalter, dann braucht die Welt 2 % mehr Natur (bis 40 %)
     und verträgt weniger Natur (–3 %, bis 60 %) und weniger Zivilisation (–1 %, bis 35 %). Du bekommst ein Leben zurück.
     Ziel: so lange wie möglich überleben. Rekord = überlebte Runden.
   - **40 Runden:** Sterne für die höchste erreichte Stufe: Dorf / Stadt / Metropole = 1 / 2 / 3 Sterne.
   Beide Modi haben einen eigenen Rekord.

Alle Zahlen stehen in [`scripts/balance.gd`](scripts/balance.gd).
**Tutorial:** Im allerersten Spiel zeigt der Würfel in den ersten 5 Runden, welche Scheibe sich lohnt (golden pulsierend)
und was eine Drehung verschmilzt. Danach nur noch die Warnung vor Katastrophen (rote Felder). Im Menü: „Tutorial nochmal“.

## Bedienung

| Geste | Wirkung |
|---|---|
| Wischen auf dem Würfel | Reihe drehen (loslassen rastet ein; rote Felder = dort droht eine Katastrophe) |
| Wischen daneben | Ansicht drehen, mit Nachschwung |
| Zwei Finger / Mausrad | Zoom |
| Feld antippen | Info-Karte: was das Feld braucht und was gerade passiert |
| Meteorit unten | Meteorit wählen, dann das Ziel antippen |

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
