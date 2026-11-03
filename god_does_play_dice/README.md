# God does play dice! – Godot 4

Neuaufbau des Browser-Prototyps (Kanten-Prototyp 0.5) in **Godot 4.3+ / GDScript**.
Maßgeblich ist das Spielkonzept in [`docs/GDD_God_does_play_dice.md`](docs/GDD_God_does_play_dice.md).
Der alte Prototyp liegt nur zum Nachschlagen in `docs/`.

## Starten

1. Godot 4.3 oder neuer installieren.
2. In Godot „Importieren“ wählen und `god_does_play_dice/project.godot` öffnen.
3. F5 drücken.

Der Renderer ist „Compatibility“ (OpenGL). Er läuft auf Handy, PC und im Web.

### Regeltests (ohne Grafik)

```bash
cd god_does_play_dice
godot --headless --import                       # einmal, legt den Klassen-Cache an
godot --headless --script res://tests/test_rules.gd
```

Die Tests prüfen die Würfel-Mathematik (Zentren drehen nie mit, 4 × 90° = Ausgangslage, jedes Feld hat 4 Nachbarn),
Besitz nach Platz, Kosten, Wartezeit, Tausch, das Kopieren des Spielstands und einen 200-Takte-Lauf nur mit KIs.

## Was drin ist (Projekt-Stufe 1: der Kern)

GDD Kap. 17 sagt: zuerst den Kern bauen und testen. Das ist umgesetzt:

| Bereich | Stand |
|---|---|
| Würfel 3×3×3, 54 Felder, Gelände mit Garantie je Seite | ✅ |
| Gold pro Takt (Zentrum-Stufe + Feld-Stufen), Rohstoffe aus Feldern | ✅ |
| Bewohner kaufen (Zentrum antippen), Preis steigt alle 3 Käufe | ✅ |
| Felder ausbauen 0–4, Grenze = Zentrum-Stufe, Hütten je Viertel | ✅ |
| Freie Felder kaufen (angrenzend, über die Kante ab Haus) | ✅ |
| Zentrum Zelt → Haus → Marktplatz → Kaserne → Werkstatt, 12 Takte Wartezeit, +1 Drehung je Ausbau | ✅ |
| Drehen: 12 Pfeile um die vordere Seite, Vorschau mit Ertragsänderung, Vormerken/Zurück, Zurücknehmen mit Gutschrift | ✅ |
| Alle Drehungen am Takt-Ende nacheinander mit Animation, Scheibe kurz in Spielerfarbe markiert | ✅ |
| Besitz hängt am Platz (wandernde Felder wechseln den Besitzer, Ausbau wandert mit) | ✅ |
| Markt 3:1 ab Marktplatz | ✅ |
| KI nach GDD Kap. 14 (Ausbau, Bewohner, Felder, Kauf, Tausch, Drehung per Simulation) | ✅ |
| Sieg: 24 Felder oder nach Zeitlimit die meisten Felder | ✅ |
| Echtzeit-Takt 8 s, Pause, ⏭ | ✅ |
| Handy zuerst: ein Finger, Auswahl-Kasten mit einem großen Knopf, nochmal tippen = Knopf | ✅ |
| Kamera: ziehen, Tipp neben den Würfel, Zoom (Rad/zwei Finger), Höhe (mittlere Taste/zwei Finger), langes Drücken = Info | ✅ |

**Noch nicht drin (Projekt-Stufe 2):** Straßen, Krieger, Angriff, Mauern.
Das Datenmodell ist vorbereitet (`FieldData.roads`, `troops`, `wall`; `GameState.road_connected()` und der
Straßen-Bonus im Ertrag sind schon da). Die Kaserne bringt deshalb noch keine Krieger, Nahrung braucht man
vorerst nur zum Tauschen.

## Entscheidungen zu den [OFFEN]-Punkten

Alle Punkte stehen als Schalter in `scripts/balance.gd`:

| Punkt | Umgesetzt | Schalter |
|---|---|---|
| Start mit ganzer Seite oder nur Zentrum (Kap. 7) | wie im Prototyp: ganze Seite | `START_OWNS_SIDE`, `OWN_SIDE_FIELD_PRICE` |
| Siegbedingung (Kap. 13) | 24 Felder **oder** Variante (a): nach 150 Takten (20 min) die meisten Felder | `WIN_FIELDS`, `TIME_LIMIT_TICKS` (0 = aus) |
| Zu viel Gold später (Kap. 17) | Gold aus Feld-Stufen pro Takt auf 12 gedeckelt | `FIELD_GOLD_CAP` (0 = kein Deckel) |
| Echtzeit vs. Runden (Kap. 4) | Echtzeit mit 8-s-Takt | `TICK_SECONDS` |

## Aufbau

```
project.godot          Autoload „Game“, Renderer Compatibility
main.tscn              einzige Szene, baut alles per Code auf
scripts/
  balance.gd           ALLE Zahlen (Balancing-Datei)
  field_data.gd        Feld-Daten (p, n, terrain, owner, level, …)
  player_data.gd       Land-Daten (Inventar, Stufe, Bewohner, Drehungen, …)
  game_state.gd        reine Spiellogik, kopierbar (clone) für die KI
  ai.gd                regelbasierte KI, simuliert Drehungen auf Kopien
  game.gd              Autoload: Takt, Drehwarteschlange, Aktionen des Menschen, Signale
  world.gd             Würfel, Würfelchen, Felder, Eingabe, Drehanimation (Pivot + Einrasten)
  field_view.gd        Darstellung eines Felds (Boden, Modelle, Hütten, Rahmen, Schild)
  models.gd            prozedurale Low-Poly-Modelle (Bäume, Felsen, Hütten, Zelt, …)
  camera_rig.gd        Kamera mit Licht, frei drehbar
  ui.gd                Oberfläche (CanvasLayer), Handy- und PC-Layout
tests/test_rules.gd    Regeltests
docs/                  GDD und alter Prototyp zum Nachschlagen
```

Logik und Darstellung sind getrennt: `GameState` kennt keine Knoten. `World` liest den Zustand und animiert.
Eine Drehung wird in der Logik sofort angewendet (`Game.pop_rotation`), die World animiert danach dieselbe Scheibe.

**Koordinaten:** Spieler-ID = Seite. 0 Gelb (+Y, du), 1 Rot (+X), 2 Blau (+Z), 3 Orange (−X), 4 Lila (−Z), 5 Weiß (−Y).
Mit 3 KIs sind Lila und Weiß neutral.

## Bekannte Grenzen

- Emojis (🪵🪨🌾🪙) kommen aus der System-Schrift. Auf Desktop, Android und iOS klappt das.
  Für einen **Web-Export** eine Emoji-Schrift (z. B. Noto Color Emoji) als Fallback-Font ins Projekt-Theme legen.
- Balancing ist ungetestet übernommen. Die Zahlen stehen alle in `balance.gd`.
