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

Dazu Berge (neutral, hier erwachen Vulkane), Krater und die **6 festen Mitten**: Leuchtturm, Windmühle,
Weltenbaum, Steinkreis, Pyramide und Sternwarte. Sie drehen sich nie und dienen der Orientierung.

- **Drehen:** über eine Reihe wischen. Jede Drehung ist eine Runde. „Warten“ lässt eine Runde verstreichen.
- **Zusammenführen:** Gleiche Felder nebeneinander bringen Glauben. Zwei gleiche Felder **gleicher Stufe**
  steigen nach 3 Runden eine Stufe auf.
- **Bedürfnisse:** Fehlt 3 Runden lang, was ein Feld braucht, verliert es eine Stufe (Stufe 1 wird zum Krater).
- **Krieg und Handel:** Kirchen zweier Völker nebeneinander bedeuten Krieg, die Grenze verliert Stufen.
  Städte zweier Völker nebeneinander handeln (+Glaube), aber nicht im Krieg.
- **Verschmutzung:** Fabriken ab Stufe 2 schaden der Natur daneben.
- **Ausbreiten:** Stufe 3 wächst alle paar Runden auf ein Nachbarfeld. Urwald verschluckt Dörfer, Städte und
  Industrie fressen Natur. Städte gründen dabei auch Kapellen.
- **Gleichgewicht:** Die Leisten oben zeigen den Anteil jeder Art, grün hinterlegt ist der gesunde Bereich.
  Glaube pro Runde = Punkte der Paare × Gleichgewicht. Wer 4 Runden in Folge aus dem Gleichgewicht ist, verliert.
- **Blitz** (alle 5 Runden einer): vernichtet ein Feld, das überhandnimmt.
- **Wunder** (alle 40 Glaube eines): aus einem Krater wird ein Feld nach Wahl.
- **Katastrophen** kündigen sich mit Countdown an: Meteorit (Feld wird Krater), Gewitter (eine Stufe weniger,
  Natur brennt), Vulkan (Nachbarn verlieren eine Stufe). Feuer springt über, ein Fluss daneben löscht.
- **Zeitalter:** Alle 10 Runden wird es schwerer: mehr Katastrophen, kürzere Vorwarnung, schnelleres Ausbreiten.
- **Ende:** endlos. Rekord = Glaube.

Alle Zahlen stehen in [`scripts/balance.gd`](scripts/balance.gd). Der Test-Bot in `tests/test_rules.gd`
(wählt immer die beste Drehung, ohne Blitz und Wunder) überlebt derzeit 70 bis 120 Runden, zufälliges Drehen 30 bis 40.

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
