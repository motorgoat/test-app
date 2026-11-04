# God does play dice! – Prototyp „Gleichgewicht“

Die Welt ist ein Zauberwürfel. Du bist ihr Gott und hast vor allem ein Werkzeug: **Du drehst die Welt.**
Ziel: so viel Glauben wie möglich, und die Welt dabei im Gleichgewicht halten.

Godot 4.3, GDScript, Renderer „Compatibility“ (läuft auf jedem Handy). Hochformat, Handy zuerst.

**Testversion fürs Handy (Android):** GitHub → Releases → `dice-testversion` → `god_does_play_dice.apk`.
Jeder Push baut sie neu. Aktuelle Screenshots aus dem Build liegen in [`docs/screenshots`](docs/screenshots),
gesammelte Ideen in [`docs/IDEEN.md`](docs/IDEEN.md).

## Spielregeln (Stand Prototyp)

**Vier Feldarten mit je drei Stufen**

| Art | Stufe 1 → 2 → 3 | braucht daneben |
|---|---|---|
| Natur | Wiese mit See → Fluss → Urwald | – |
| Siedlung (Volk) | Dorf → Stadt → Metropole | Natur |
| Industrie | Werkstatt → Fabrik → Industriegebiet | Siedlung |
| Glaube (Volk) | Kapelle → Kirche → Kathedrale | Siedlung des eigenen Volkes |

Dazu Berge (neutral, hier erwachen Vulkane) und Krater. Alle Felder drehen mit, auch die Mitten, wie bei einem echten Zauberwürfel.

- **Drehen:** über eine Reihe wischen. Jede Drehung ist eine Runde. „Warten“ lässt eine Runde verstreichen.
- **Drei in einer Reihe:** Drei gleiche Felder (gleiche Art, Stufe und bei Siedlung/Glaube gleiches Volk) in einer
  Reihe oder Spalte einer Seite verschmelzen **sofort**: Die äußeren fliegen ins mittlere, das steigt eine Stufe auf.
  Die frei gewordenen Felder füllen sich mit der Art, die gerade am meisten fehlt. Kettenreaktionen zählen als Kombo.
  Beim Wischen leuchten Reihen, die verschmelzen würden, golden auf.
- **Glaube** gibt es nur fürs Verschmelzen (10/30/90 je Stufe × Kombo, gedämpft bei schlechtem Gleichgewicht) und für Handel.
- **Bedürfnisse:** Fehlt 3 Runden lang, was ein Feld braucht, verliert es eine Stufe (Stufe 1 wird zum Krater).
- **Krieg und Handel:** Kirchen zweier Völker nebeneinander bedeuten Krieg, die Grenze verliert Stufen.
  Städte zweier Völker nebeneinander handeln (+Glaube), aber nicht im Krieg.
- **Verschmutzung:** Fabriken ab Stufe 2 schaden der Natur daneben.
- **Ausbreiten:** Stufe 3 wächst alle paar Runden auf ein Nachbarfeld.
- **Gleichgewicht:** Die Leisten oben zeigen den Anteil jeder Art, grün hinterlegt ist der gesunde Bereich.
  Wer 4 Runden in Folge aus dem Gleichgewicht ist, verliert.
- **Katastrophen sind Strafen**, immer mit Countdown angekündigt:
  zu viel Industrie → Gewitter über einer Fabrik, zu viele Siedlungen → Meteorit auf die größte Siedlung,
  zu viel Natur → Gewitter mit Waldbrand, zu wenig Glaube → ein Vulkan erwacht. Im Gleichgewicht bleibt es ruhig.
- **Zeitalter:** Alle 10 Runden wird der gesunde Bereich enger, Strafen kommen schneller und knapper angekündigt.
- **Blitz** (alle 5 Runden einer): vernichtet ein Feld. **Wunder** (alle 40 Glaube eines): aus einem Krater wird ein Feld nach Wahl.
- **Tipp:** Wer 10 Sekunden nichts tut, sieht eine lohnende Scheibe golden pulsieren.
- **Ende:** endlos. Rekord = Glaube.

Alle Zahlen stehen in [`scripts/balance.gd`](scripts/balance.gd).

## Bedienung

| Geste | Wirkung |
|---|---|
| Wischen auf dem Würfel | Reihe drehen (mit Vorschau ▲ ▼ +Glaube, loslassen rastet ein) |
| Wischen daneben | Ansicht drehen, mit Nachschwung |
| Zwei Finger / Mausrad | Zoom |
| Feld antippen | Info-Karte: was das Feld braucht und was gerade passiert |
| Blitz / Wunder unten | Werkzeug wählen, dann Feld antippen |
| Gefahr oben antippen | Ansicht dreht zur Gefahr |

## Aufbau

```
scripts/
  balance.gd      alle Zahlen
  field_data.gd   Feld-Daten
  game_state.gd   reine Spiellogik (Runde auswerten, Gefahren), kopierbar für die Vorschau
  game.gd         Autoload: Rundenablauf, Rekord, Signale
  world.gd        Würfel, Wisch-Drehen, Vorschau, Effekte, Kamera-Eingabe
  field_view.gd   Darstellung eines Felds
  hazard_view.gd  Darstellung einer angekündigten Gefahr
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
