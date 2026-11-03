# God does play dice! – Prototyp „Beschütze die Völker“

Die Welt ist ein Zauberwürfel. Darauf leben mehrere Völker und Tiere. Du bist der Gott dieser Welt
und hast nur ein Werkzeug: **Du drehst die Welt.**

Godot 4.3, GDScript, Renderer „Compatibility“ (läuft auf jedem Handy). Hochformat, Handy zuerst.

**Testversion fürs Handy (Android):** GitHub → Releases → `dice-testversion` → `god_does_play_dice.apk`.
Jeder Push baut sie neu. Aktuelle Screenshots aus dem Build liegen in [`docs/screenshots`](docs/screenshots).

## Spielregeln (Stand Prototyp)

- **Drehen:** Mit dem Finger über eine Reihe wischen. Jede Drehung ist eine Runde. „Warten“ lässt eine Runde ohne Drehung verstreichen.
- **Vorschau:** Während du ziehst, steht über jedem Feld, wie viele Menschen bzw. Tiere es gewinnt oder verliert, und oben die Summe.
- **Dörfer** wachsen mit mindestens 2 freien Wiesen/Seen daneben, ohne Nahrung schrumpfen sie. Die eigene Kirche daneben hilft. Volle Dörfer gründen neue.
- **Kirchen** zweier Völker nebeneinander: **Krieg** zwischen diesen Völkern. Jede Berührung kostet beide Seiten Menschen.
- **Märkte** zweier Völker nebeneinander: **Handel**, beide wachsen. Völker im Krieg handeln nicht.
- **Tiere** vermehren sich neben gleichem Land, Dörfer daneben jagen sie.
- **Gefahren** kündigen sich mit Countdown an:
  - **Meteorit:** schlägt an einem Platz im Raum ein und löscht das Feld aus (wird zum Krater, später zum See).
  - **Gewitter:** halbiert Menschen und Tiere, Wald fängt Feuer.
  - **Vulkan:** ein Berg bricht aus, die Nachbarn verlieren die Hälfte, Wälder brennen.
  - **Feuer** springt auf Nachbarwälder über, ein See daneben löscht es.

  Meteor und Gewitter zielen auf einen **Platz**: Dreh die Menschen weg. Der Vulkan sitzt auf seinem **Feld**: Dreh ihn weg von den Menschen.
- **Ende:** endlos, bis alle Menschen tot sind. Gefahren werden mit der Zeit häufiger. Rekord = überlebte Runden.

Alle Zahlen stehen in [`scripts/balance.gd`](scripts/balance.gd) (z. B. `MAX_ROUNDS` für ein festes Ende).

## Bedienung

| Geste | Wirkung |
|---|---|
| Wischen auf dem Würfel | Reihe drehen (mit Vorschau, loslassen rastet ein) |
| Wischen daneben | Ansicht drehen, mit Nachschwung |
| Zwei Finger / Mausrad | Zoom |
| Feld antippen | Info-Karte mit Erklärung, was dort gerade passiert |
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
