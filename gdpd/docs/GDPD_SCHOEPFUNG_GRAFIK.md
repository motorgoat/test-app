# gdpd – Grafik für „Die Schöpfung“: Zeitalter, neue Arten, Zusammenwachsen

Stand: 7. November 2026. Grundlage: die Entscheidung „Die Schöpfung“ in `NAECHSTE_SCHRITTE.md` (7 Akte, etwa 30 Level
nach der Erdgeschichte, ein Level pro echtem Tag). Dieses Dokument baut auf `GDPD_GRAFIK.md` auf und ändert dessen
Regeln nicht: **realistisches Miniatur-Diorama, Lesbarkeit zuerst, eine Würfelseite ist eine Landschaft (nahtloser
Boden-Shader mit 8 Nachbarn), Wasser ist ein zusammenhängender Körper, gesättigte Farbe ist ein Spielsignal.**

Neu ist eine Ebene über den Arten: das **Zeitalter**. Es färbt Himmel, Licht, Wasser und Boden der ganzen Welt und
zeigt, wie weit die Schöpfung ist. Dazu kommen etwa 20 neue Arten, das sichtbare Zusammenwachsen gleicher Felder,
ein Verlust-Hinweis („−1“) und eine einheitliche Sprache für Gefahren, die eine Drehung vorher warnt.

Inhalt: 0 Prototyp · 1 Leitlinien · 2 Zeitalter-System · 3 Looks je Akt · 4 Arten-Katalog · 5 Zusammenwachsen ·
6 Verlust-Hinweis · 7 Gefahren als Folgen · 8 Tag/Nacht und Jahreszeiten · 9 Oberfläche · 10 Leistung ·
11 Umsetzung (Dateien, Funktionen) · 12 Reihenfolge und Prüfungen · 13 Offene Fragen

---

## 0. Prototyp (Scratchpad, echtes Projekt als Kopie, lokales Godot 4.3, `opengl3`, 1080×2340)

Ich habe die drei riskantesten Looks in einer Kopie des Projekts gebaut. Es wurde mit den echten Bausteinen
`World`, `FieldView`, `Models`, `Look` und `ground.gdshader` gerendert, mit dem echten Licht, der Post-Ebene und dem
Hintergrund. Im Spiel selbst ist nichts geändert. Die Quellen liegen in `docs/grafik/schoepfung/prototyp/`
(`schoepfung_look.diff` gegen den heutigen Stand, `era.gd`/`era.tscn` als Look-Dev-Szene, `render.sh`).

### 0.1 Zeitalter-Himmel: Akt 1 Glut · Akt 2 Dunst · Akt 3 blau (nach Sauerstoff) · Akt 4 Nacht

![Zeitalter](grafik/schoepfung/zeitalter_himmel.jpg)

- **Glut:** Der Himmel ist oben fast schwarz und unten rot-orange. Wolkenunterseiten glühen von der Lava
  (`low_glow`), Asche-Schlieren steigen, und 60 Funken steigen um den Würfel. Basalt ist schwarzgrau, Lava hat
  glühende Risse, das Urmeer ist grau und tot.
- **Dunst:** Die Uratmosphäre ist ein ockergrauer, flacher Himmel mit dichtem Dunst (`haze`) und kaum Schatten.
  Das Wasser ist oliv-trüb mit kaum sichtbaren Einzeller-Pünktchen. Lava gibt es nur noch als Rest.
- **Blau:** Das ist der heutige `tag`-Himmel. Er ist hier verdient, denn Algen haben ihn gemacht. Im Wasser
  liegen grüne Algenmatten im Flachen, an Land Moos (hier Wiese als Platzhalter) und Wald.
- **Nacht:** Der Himmel ist tiefblau mit Sternen, die im Backdrop-Shader funkeln (ohne Textur). Mondlicht kommt
  als kühles Füll-Licht. Felder und Dorf bleiben lesbar.

### 0.2 Lava und Urozean (Nahaufnahme, Zoom 0,62)

![Lava und Urozean](grafik/schoepfung/lava_urozean.jpg)

Die Lava ist **kein eigenes Mesh**. Sie läuft als Zweig im Boden-Shader: Krustenplatten aus Zellrauschen, glühende
Risse und in der Mitte großer Lava-Flächen fließende Becken. Alles liegt in Würfel-Koordinaten, deshalb laufen Risse
und Fluss lückenlos über Fugen und Würfelkanten. Die Glut kommt aus der Emission (über 1,0, mit Glühen) und nicht aus
Lampen. Grenzt Lava an Basalt, kühlt sie zum Rand hin ab, denn ihr Anteil (`lav`) wird wie die Bodenfarben mit den
Nachbarn gemischt. Am Ufer zum Urmeer spiegelt das Wasser die Glut, und Dampf steigt auf.

### 0.3 Zusammenwachsen: Wald vorher / nachher (gleiche Belegung)

![Wald zusammenwachsen](grafik/schoepfung/wald_zusammenwachsen.jpg)

Links ist der heutige Stand: jedes Waldfeld ist ein eigener Hain, und an jeder Fuge ist eine Lichtung. Rechts liegen
gleiche Waldfelder nebeneinander und teilen ein Kronendach: Bäume stehen **auf** den gemeinsamen Fugen, die Bäume
innen sind 18 % größer, und es wirkt wie ein durchgehender Wald. Die Regel, wer einen Fugenbaum setzt, verhindert
Doppelte: Jede Fuge gehört dem Feld südlich bzw. westlich davon, also setzt jedes Feld nur an seiner N- und O-Fuge
und an der Ecke NO.

### 0.4 Gemessen und gelernt

| Szene (ganzer Würfel belegt) | Draw-Calls | Primitive |
|---|---|---|
| Akt 1 Glut (Lava, Basalt, Urmeer, Funken, Dampf) | 224 | 37 k |
| Akt 2 Dunst | 156 | 34 k |
| Akt 3 blau (Wald, Moos, Algen) | 217 | 115 k |
| Akt 4 Nacht (Äcker, Dorf, Wald) | 221 | 143 k |
| Wald vorher / **nachher** (Zusammenwachsen) | 219 / **219** | 121 k / **140 k (+15 %)** |

- Die Lava kostet keine Draw-Calls und kaum Ecken. Der Shader-Zweig läuft nur, wo `lav > 0` ist (2 triplanare
  Abfragen mehr, also 6 Textur-Zugriffe). Der Fugen-Wald wird mitgebacken: gleiche Draw-Calls, +15 % Primitive.
- **Fehler im ersten Versuch:** Die Lava war mit Emission 2,4 und feinem Zellraster (Maßstab 3,4) zu einem weißen
  Rauschteppich ausgebrannt. Richtig sind Emission 1,25, grobe Platten (Maßstab 0,55), schmale Risse und gelbe
  Becken nur in der Mitte großer Flächen. Regel für alle Glut-Arten: **Kern gelb, Rand rot, Fläche dunkel**.
- Totes Wasser darf nicht zu dunkel werden, sonst liest es sich als Loch (erster Versuch `#1d2427`). Mit `#2a3438` /
  `#5a625c`, Fresnel zum Himmel und Glitzern bleibt es Wasser.
- In der Nahaufnahme glitzert totes Wasser zu stark (viele Lichtpunkte). Im Zeitalter Glut soll das Glitzern halb so
  stark sein (`glint` × 0,5), denn die Sonne steht hinter Asche.
- Dampf-Billboards mit 0,11 sahen in der Nahaufnahme wie Schneeflocken aus. Sie brauchen ≥ 0,22, Alpha ≤ 0,35 und
  steigen langsam (siehe 4.1).
- Die Nacht war zu dunkel für Fensterlicht: Die heutigen `warm`-Fenster (Emission 1,25) gehen unter. Bei Nacht
  müssen sie ×2,5 leuchten, mit Laternen und Glühwürmchen (Abschnitt 8).
- Ein heller Strich über eine ganze Scheibe in frühen Renderings war der Onboarding-Tipp, der nach einer Pause
  leuchtet, kein Grafikfehler (`era.gd` setzt deshalb `Game.onboarding = false`).

---

## 1. Leitlinien für die Schöpfung

1. **Das Zeitalter ist eine Welt-Größe, keine Art.** Himmel, Licht, Wasserfarbe und Bodenpaletten hängen am
   Zeitalter. Die Art eines Felds sagt nur, *was* darauf ist. Deshalb sieht Erde in Akt 1 wie Basalt aus und in
   Akt 6 wie Ackerboden, mit derselben Lesbarkeits-Regel (Boden, Silhouette, Merkmal; `GDPD_GRAFIK.md` 2.3).
2. **Leben entsteht sichtbar durch Spielen.** Das Wasser ist am Anfang tot: kein Grün, kein Glitzern von Leben, keine
   Fische, keine Enten. Jede Lebens-Stufe (Einzeller → Algen → Fische) erscheint erst, wenn der Spieler sie schafft,
   zuerst leise und dann deutlicher. Auch der **blaue Himmel ist eine Folge**: Er kommt in Akt 3 mit dem Sauerstoff
   aus den Algen, schrittweise je geschaffener Alge (Abschnitt 2.3).
3. **Wenige Arten zugleich, jede sofort erkennbar.** Ein Level hat höchstens 3 wachsende Arten und am Morgen
   höchstens etwa 6 verschiedene. Jede neue Art braucht deshalb **ein** klares Merkmal, das bei 120 px Kachelbreite
   in unter einer halben Sekunde wirkt, auch in Graustufen.
4. **Gleiche Arten wachsen zusammen.** Wald wird ein Wald, Acker ein großes Feld, Wasser ein See, Tiere eine Herde,
   Häuser eine Stadt. Gruppen sehen größer und wertvoller aus, nicht nur bunter (Abschnitt 5).
5. **Gefahren sind sichtbare Folgen.** Jede Gefahr hat eine Ursache, die man auf dem Würfel sieht (trockener Wald
   ohne Wasser, zu viel Lava an einem Fleck, zu viel Stadt am Meer). Eine Drehung vorher warnt ein Vorzeichen
   (Abschnitt 7).
6. **Nicht spoilern.** Kein Bild, Himmel, Symbol oder Modell eines späteren Akts taucht vorher auf: nicht in der
   Übersicht, nicht im Laden, nicht in Benachrichtigungen. Gesperrte Kacheln zeigen nur Schloss bzw. „?“. Der Laden
   zeigt nur Dinge aus Akten, die man schon erreicht hat.

---

## 2. Zeitalter-System

### 2.1 Datensatz `Eras` (neu: `scripts/eras.gd`, nur Konstanten)

Ein Eintrag je Zeitalter-Stufe (mehrere je Akt). `World` und `Look` lesen nur diesen Datensatz:

```
"glut": {
  "mood": "glut",                     # Licht, Himmel, Post (World.MOODS, neue Einträge)
  "sky": {"lowglow": 0.55, "haze": 0.2, "stars": 0.0, "ash": 0.5},   # Backdrop-Zusätze
  "water": {"deep": "#2a3438", "shallow": "#5a625c", "glint": 0.5},  # Wasserfarbe dieses Zeitalters
  "ground": {0: {...Basalt...}, LAVA: {...Kruste...}},                 # überschreibt Look.GROUND je Art
  "ambient": {"pollen": false, "birds": false, "embers": 60, "fireflies": 0},
}
```

- `Look.set_era(e)` setzt die Bodenpaletten (`ground_params` sieht zuerst in `e.ground` nach), die Wasserfarben
  (`w_deep`, `w_shallow`) und `glint` auf alle Boden-Materialien. Felder mit gleicher Art nutzen das Material wie
  heute. Ein Zeitalterwechsel rechnet die Uniforms um und baut keine Meshes neu, nur Inhalte, deren Modell vom
  Zeitalter abhängt (Basalt-Brocken, Lava-Rauch, Enten).
- `World.set_era(name, dur)` blendet über `set_mood` (Tween wie heute) und setzt `_life_on`, Funken, Glühwürmchen.
  Stimmungen nach Ereignissen (`regen`, `krieg`, `smog`) haben weiter Vorrang (`hold_mood`), danach kehrt die Welt
  zur Zeitalter-Stimmung zurück statt zu `tag`. `_day_mood()` wird dafür zu „Ereignis > Smog > Sieg > Zeitalter“.
- Der Back-Cache-Schlüssel (`FieldView._bake_key`) bekommt das Zeitalter. Nur Modelle, die sich ändern, zählen.

### 2.2 Stufen je Akt (Vorschlag; welche Level genau, legt der Regel-Plan fest)

| Akt | Stufen (`Eras`) | Himmel | Licht |
|---|---|---|---|
| 1 Licht | `glut` → `glut_kuehl` | schwarz-rot, glühende Wolkenunterseiten, Asche; später weniger Glut, erste graue Regenwolken | Sonne orange 0,95, Füll-Licht rötlich, Glühen 0,9 |
| 2 Himmel | `dunst` → `regen_ur` | ocker-grauer Dunst, flache Wolkendecke, Blitze in der Ferne (Backdrop-Flash) | weich, kaum Schatten, Sättigung 0,85 |
| 3 Land und Pflanzen | `dunst` → `blau` (fließend, 2.3) | Dunst lichtet sich zu blau, erste weiße Haufenwolken | wird zum heutigen `tag` |
| 4 Sonne, Mond, Sterne | `tag`, `abend`, `nacht`, `morgen` im Wechsel; Jahreszeiten | wie heute, dazu Sterne und Mond | Abschnitt 8 |
| 5 Wasser und Luft | `tag` (klar, Vögel) | klar, mehr Vögel, Möwen über Wasser | heute |
| 6 Tiere und Menschen | `tag` → `abend` (Städte) | Smog färbt den Himmel (heute `smog`), Krieg (`krieg`) | heute |
| 7 Ruhe | `vollendet` | goldene Stunde | heute `vollendet` |

### 2.3 Der Himmel wird blau – als Folge (Akt 3)

`World.set_era_mix(a, b, t)` mischt zwei Zeitalter mit `t` = 0…1 (alle Werte der Stimmung, Wasser und Boden).
In Akt 3 ist `t` = Sauerstoff = Zahl der Algen-Felder (auch der früheren Level desselben Akts, wenn die Welt
weitergeführt wird) geteilt durch das Ziel des Akts. Jede neue Alge lässt den Himmel sichtbar ein Stück blauer werden
(0,8 s Überblendung, dazu ein kurzer heller Puls am Horizont). Verliert man Algen, wird er nicht wieder grau, denn
Sauerstoff bleibt in der Luft. So ist der Fortschritt ohne Text sichtbar.

### 2.4 Bleibt die Welt innerhalb eines Akts? (Empfehlung aus Sicht der Grafik)

**Ja, innerhalb eines Akts geht die Welt sichtbar weiter.** Das Zeitalter (Himmel, Wasser, Sauerstoff) wird mit dem
Akt gespeichert, nicht mit dem Level. Das Brett eines neuen Levels darf neu sein (geprüfte Pools, wie heute), aber es
beginnt mit „Neuer Morgen“ (`World.overnight_wave`): Ein paar Felder wachsen über Nacht herauf, und Himmel und Wasser
sind so wie gestern am Ende. Zwischen den Akten gibt es einen **Akt-Übergang** von 3–4 s ohne Text. Die Kamera zieht
etwas zurück, das Zeitalter blendet über, ein Lichtstrahl fällt auf den Würfel, und die Welt wird mit der Welle neu
gelegt. Erst danach erscheint die Ziel-Karte. Was der nächste Akt bringt, zeigt sich erst, wenn er beginnt.

---

## 3. Looks je Akt

Kurzform. Die neuen Arten stehen in Abschnitt 4, die Gefahren in 7.

### Akt 1 – Licht (glühende Erde, Lava, Urozean, Fels)

- **Himmel:** `glut` (Prototyp). Zuerst fast schwarz mit roter Unterseite. Am Ende des Akts reißt die Decke etwas auf
  (`glut_kuehl`: weniger `lowglow`, mehr grau).
- **Land:** Basalt (Erde in diesem Zeitalter) ist schwarzgrau mit hellen Brocken und ohne Gras. Lava hat Kruste
  und glühende Risse. Erstarrte Lava wird in diesem Akt zu Fels.
- **Wasser:** Das Urmeer ist grau, tot und trüb. Neben Lava wird der Rand orange und dampft. Es gibt keine Enten,
  keine Algen und keine Pünktchen.
- **Leben (Umgebung):** keins. Statt Pollen steigen Funken, statt Vögeln gibt es Asche. Kamera-Schütteln nur bei
  Vulkan.

### Akt 2 – Himmel (Atmosphäre, erster Regen, Ursuppe, Einzeller)

- **Himmel:** `dunst`. Später regnet es zum ersten Mal: Die heutige Regen-Stimmung bekommt hier einen ockrigen Ton,
  und Blitze leuchten in der Ferne (Bildblitz 0,05, ohne Einschlag).
- **Land:** Fels wird heller und grauer, nach dem Regen nass glänzend (`wet`). In Senken stehen Pfützen.
- **Wasser:** Die **Ursuppe** ist bräunlich-oliv und warm. **Einzeller** sind feine, treibende, schwach leuchtende
  Pünktchen. Sie müssen bewusst kaum sichtbar sein und wirken nur aus der Nähe und im Zusammenhang (Abschnitt 4.2).
- **Leben (Umgebung):** keine Vögel, keine Pollen. Bei Regen Spritzer (wie heute).

### Akt 3 – Land und Pflanzen (Algen → Sauerstoff → blauer Himmel, Moos, Farne, Wälder)

- **Himmel:** Mischung `dunst` → `blau` nach Sauerstoff (2.3).
- **Wasser:** Algen bilden grüne Matten im Flachen am Ufer, und das Tiefe wird von olivgrün zu klarem Blaugrün. Sind
  alle Algen da, ist es das heutige Wasser.
- **Land:** Moos ist ein niedriger, samtiger Teppich auf Fels. Farne sind kniehoch und gefiedert. Dann kommen die
  ersten Wälder, zuerst urtümlich mit Baumfarnen und Schachtelhalmen (4.3), am Ende des Akts heutiger Mischwald.
- **Leben (Umgebung):** Pollen erst ab Farnen. Noch keine Vögel und keine Tiere.

### Akt 4 – Sonne, Mond und Sterne (Tag/Nacht, Jahreszeiten, Wachstum und Ernte)

- Tag/Nacht und Jahreszeiten sind hier das Thema (Abschnitt 8). Pflanzen wachsen und reifen sichtbar im Jahreslauf.

### Akt 5 – Leben in Wasser und Luft (Fische, Vögel, Landgang)

- **Wasser:** Fische sind Schwärme aus dunklen Rücken knapp unter der Oberfläche, mit Silberblitzen beim Wenden.
  Dazu ab und zu Ringe an der Oberfläche.
- **Luft:** Vögel nisten auf Felsen und Bäumen und kreisen über ihrem Feld. Der heutige Schwarm wird häufiger.
- **Landgang:** Amphibien leben am Ufer mit Schilf, Tümpel und Laich.

### Akt 6 – Tiere und Menschen (Nahrungskette, Meteor, Menschen, Ackerbau, Dörfer, Glaube, Städte, Industrie, Smog, Flut)

- Der Look ist heute schon fast da (`GDPD_GRAFIK.md` 13–16). Neu sind Wildtiere statt Haustiere vor den Menschen
  (Pflanzenfresser, Raubtiere), sichtbares Futter und sichtbare Jagd, Äcker mit Hunger-Zustand, Meteor mit Ära-Ende
  (Staubwinter, 7.4) und die Stadt, die zusammenwächst.
- **Himmel:** `tag`. Bei Städten geht er Richtung `abend`, bei Industrie wird er zu `smog`.

### Akt 7 – Ruhe (Gleichgewicht der vollendeten Welt)

- `vollendet`: goldene Stunde, alles lebt leise. Gruppen leuchten bei Gleichgewicht kurz golden (Abschnitt 5). Keine
  Gefahren-Vorzeichen, solange alles im Gleichgewicht ist.
- Danach kommt die „Welt des Tages“ im Zeitalter `tag` und später neue Welten (Insel, Wüste, Winter) als eigene
  Paletten im selben `Eras`-System.

---

## 4. Arten-Katalog (neu und geändert)

Die Ids und Namen legt der Regel-Plan fest. Hier steht, **wie** jede Art aussieht. Jede Zeile erfüllt die drei
Kennzeichen der Lesbarkeits-Regel. „Basis“ ist das Modell bzw. der Builder, auf dem sie aufbaut
(`field_view.gd::_b_*`, `models.gd::get_model`).

### 4.1 Urzeit (Akt 1–2)

| Art | Boden (Ton / Helligkeit / Muster) | Silhouette | Merkmal (eines!) | Bewegung | Basis |
|---|---|---|---|---|---|
| **Lava** | Kruste `#231d1a`, dunkelst | flach | glühende Risse, gelbe Becken in großen Flächen | Fluss im Shader, Flackern, 1 Rauchfaden | `ground.gdshader` Lava-Zweig, `_b_lava`: 2 erstarrte Brocken + Rauch |
| **Fels / Basalt** (Erde der Urzeit) | `#2c2c2d`/`#3c3b3a` mit hellen Körnern | niedrig, kantig | 2–3 große, scharfkantige Brocken | – | `_b_earth` Zeitalter-Zweig, `rock`/`boulder` mit dunkler Vertexfarbe |
| **Urozean** (Wasser der Urzeit) | Wasser grau `#2a3438`/`#5a625c` | flach | tot: Spiegel ohne Leben; an Lava orange Rand + Dampf | Wellen wie heute, Glitzern ×0,5 | `is_water`, Farben aus `Eras` |
| **Vulkan** (Folge, keine Wachs-Art) | Lava-Boden | hoch, Kegel | Krater mit Glut und Rauchsäule | Rauch, Glut pulsiert, vor Ausbruch Beben | neues Modell `volcano` (Kegel aus verbeultem Ico, Krater-Ring, `warm`-Glut innen); Symbol `volcano.svg` gibt es |
| **Ursuppe** (Wasser mit Wärme) | Wasser oliv-braun `#26302a`/`#55604c` | flach | trüb, Schaum-Schlieren | träge Wellen (Wellen-Tempo ×0,6) | `is_water`, `w_life` 0,1 |
| **Einzeller** | Wasser wie Ursuppe | flach | **feine, schwach leuchtende Pünktchen**, die langsam treiben | Treiben, Pulsieren | `w_life` 0,35 (Prototyp), Leuchten ≤ 0,12 |

- Dampf über Wasser neben Lava: 3 Billboards je Ufer, Durchmesser ≥ 0,22, Alpha ≤ 0,35, langsam
  (`FieldView._update_steam` im Prototyp). Höchstens 12 Dampf-Billboards gleichzeitig im ganzen Würfel.
- Einzeller sind bewusst leise (Philipp: „Einzeller dezent“). Damit man sie trotzdem findet, zeigt **das Entstehen**
  sie deutlich: Beim Schaffen leuchtet der See einmal türkis auf (0,6 s, `pulse_light` im Wasser) und die Pünktchen
  ziehen sich kurz zusammen. Im Ruhezustand sind sie fast unsichtbar.

### 4.2 Leben im Wasser (Akt 2–5): eine Wasserfläche, mehrere Lebens-Stufen

**Grundregel: Leben im Wasser ist ein Zustand der Wasserfläche, kein eigenes Becken.** Auch wenn Einzeller, Algen und
Fische für die Regeln eigene Arten sind, bleiben sie für den Boden-Shader Wasser (`is_water = 1`). Sie verbinden sich
also nahtlos zu einem See. Was darin lebt, kommt als Stärke `w_life` je Feld und wird an der Fuge wie die
Nachbar-Zustände (`nb_fx`) gemischt. So gibt es keine Kante zwischen Algenwasser und totem Wasser, sondern einen
weichen Übergang wie bei Nässe und Smog.

| Art | `w_life` | Aussehen | Merkmal |
|---|---|---|---|
| totes Wasser | 0 | grau/trüb (Zeitalter) | nichts |
| Einzeller | 0,35 | Pünktchen, kaum sichtbar | Leuchtpuls beim Entstehen |
| **Algen** | 1,0 | grüne Matten im Flachen (Ufer), Tiefe olivgrün; Prototyp | grüner Uferring |
| **Fische** | 1,0 + Schwarm | klares Blaugrün, dunkle Rücken, Silberblitze, Ringe | Schwarm (MultiMesh je Feld, 6–9 Fische, Kreisbahn im Shader) |
| Fische + Vögel (Akt 5) | wie Fische | dazu Möwen, die tauchen | – |

- `nb_fx` bekommt eine fünfte Größe. Weil `nb_fx` schon `vec4` ist (verwelkt, Smog, Nässe, Markierung), kommt
  `w_life` in ein eigenes `nb_life[8]` (float) dazu.
- Fische schwimmen nur auf zugewandten Seiten (LOD wie Agenten). Ein MultiMesh je Wasserfeld mit Bewegung im
  Vertex-Shader, Phase je Instanz: 1 Draw-Call je Feld, auf „niedrig“ aus (nur Ringe).

### 4.3 Pflanzen (Akt 3–4)

| Art | Boden | Silhouette | Merkmal | Basis |
|---|---|---|---|---|
| **Moos** | samtig-grün `#4f6a2a`/`#6b7f36` auf Fels, Fels-Körner schauen durch | ganz flach (niedriger als Wiese) | Polster: runde, dichte Buckel (Zellrauschen als Höhe im Shader), keine Blumen | `GROUND` + `samt`-Variante „Polster“, `cover()` mit Moos-Büscheln (kurze, dicke Halme) |
| **Farne** | dunkler Humus `#3d3a24` | **kniehoch, buschig** | gefiederte Wedel in Rosetten (5–7 Wedel je Pflanze, gebogen) | neues Modell `fern` (Wedel aus Grashalm-Streifen mit Fiederkerben, Wind über `COLOR.a`) |
| **Urwald** (Akt 3) | sehr dunkler Waldboden | hoch, schmal | Baumfarne (Schopf auf dünnem Stamm), Schachtelhalm-Säulen | Modelle `tree_fern`, `horsetail`; später ersetzt durch heutige Bäume (`_b_forest`) |
| **Wald** | wie heute | mittel | gemischte Kronen | heute |
| **Wiese** (ab Akt 4) | wie heute | flach | Blumen | heute |

- Moos gegen Wiese: Moos ist dunkler, hat keine Blumen, ist ein Polster statt Halmen und liegt nur auf
  Fels-Untergrund. Moos und Wiese kommen nie im selben Level vor (Pool-Regel im Regel-Plan prüfen).
- Farne gegen Wald: Farne sind halb so hoch und haben keine Stämme. Auf 360 px Graustufen ist der Unterschied die
  Höhe des Schattens.

### 4.4 Tiere (Akt 5–6)

**Wildtiere vor den Menschen, Haustiere erst mit Menschen.** Schafe, Kühe, Zaun und Tränke (heute „Tiere“) passen
erst nach dem Ackerbau.

| Art | Boden | Silhouette | Merkmal | Bewegung | Basis |
|---|---|---|---|---|---|
| **Vögel** (Nistplatz) | Fels/Klippe oder Baumgruppe hell gefleckt (Vogelkot als helle Tupfer) | mittel | 2–3 Nester, **Vögel kreisen über dem Feld** | Kreisen (MultiMesh, Flügelschlag im Shader), Landen | Vogel-MultiMesh wie `World._birds`, aber je Feld; Modell `nest` |
| **Amphibien** (Landgang) | sumpfig, dunkelgrün-braun, Tümpel (Wasser-Shader im Kleinen über `w_seg`/Kern) | flach mit Schilf | Schilf + Frösche/Molche am Tümpel | Frösche hüpfen (Agent `frog`: idle → hop) | `_b_swamp`: Tümpel als Mini-Wasserkern, Modell `reed`, Figur `frog` |
| **Pflanzenfresser** (Herde) | Gras abgegrast, Trittpfade | flach mit Tieren | **Herde aus 4–6 Tieren gleicher Art** (Hirsche/Wisente/Urrinder, Farbe braun) | grasen, ziehen gemeinsam | `creature_mesh("deer"/"bison")`, Herden-Agenten (5.4) |
| **Raubtiere** | Fels mit dunklem Gras, Knochen als helle Punkte | flach mit 1–2 Tieren | **graue Wölfe** (niedrig, lang, dunkel), Höhle/Felsspalt | schleichen, sitzen, heulen (Kopf hoch) | Figur `wolf` (Rumpf lang, Schwanz, spitze Ohren), Modell `den` |
| **Haustiere** (nach Ackerbau) | wie heute „Tiere“ | wie heute | Zaun, Schafe, Kühe | heute | `_b_animals` |

- Pflanzenfresser gegen Raubtiere ist bei 120 px die schwierigste Unterscheidung. Lösung über drei Kennzeichen:
  Raubtiere **dunkelgrau auf dunklem Boden mit Felsen**, wenige (1–2); Pflanzenfresser **braun auf hellem Gras**,
  viele (4–6), oft mit Kopf unten. Dazu das Bedürfnis-Symbol: Raubtiere zeigen das Symbol „Pflanzenfresser“
  (`paw`), Pflanzenfresser das Symbol „Pflanze“.
- **„Gib den Tieren Futter“** (Verbinden): Ein satt versorgtes Tierfeld zeigt Futter sichtbar. Die Tiere stehen am
  Rand zum Pflanzen-Nachbarn und grasen in seine Richtung (Agenten-Ziel = Fuge zum Futterfeld). Fehlt Futter, sind
  sie mager und grau (`_sad` wie bei Menschen) und laufen suchend hin und her. Beim Drehen zeigt die Vorschau wie
  heute den grünen bzw. roten Rand (`supply_up`/`supply_down`).
- **Jagd** (Raubtier frisst Pflanzenfresser): kein Blut. Ein Wolf läuft zur Fuge, die Herde nebenan schreckt auf und
  rückt zusammen. Ist es ein Verlust, verschwindet ein Tier mit dem Staubwölkchen aus Abschnitt 6.

### 4.5 Menschen, Nahrung, Glaube, Städte (Akt 6)

| Art | Änderung gegenüber heute | Basis |
|---|---|---|
| **Menschen / Hütte** | heute (`_b_hut`, Blockhütte, Feuerstelle). Neu: die ersten Menschen als Zelt-Lager (Modell `tent` gibt es) | `_b_hut` Variante „Lager“ |
| **Acker** | Zustände: **Saat → grün → reif → geerntet** (Stoppeln, Garben), dazu **dürr** (braun, rissig, ohne Regen) und **nass** (nach Regen, dunkle Furchen, Pfützen). Reif = gold. Das ist das einzige gesättigte Gold auf dem Land und deshalb sofort lesbar. | `Models.crops(stage …)`: Stufen 0–2 gibt es, neu: 3 geerntet, `dry` gibt es |
| **Dorf** | heute. Satt (Nahrung + Arbeit): Rauch aus allen Kaminen, Menschen tragen Garben vom Acker. Hungrig: kein Rauch, Menschen sitzen | `_b_village`, Agenten-Ziel Acker-Fuge |
| **Kirche** | heute. Glaube als violettes Fensterlicht. Zwei Kirchen nebeneinander: rote Front (heute) | `_b_church` |
| **Stadt** | heute. Neu: zusammenwachsend (5.5) | `_b_town` |
| **Industrie** | heute (Hallen, Schlote, Rauch) | `_b_industry` |
| **Smog** | heute (gelbgrauer Dunst, Stimmung `smog`). Neu: Dunst **zieht sichtbar vom Schlot zum Opferfeld** (Rauch-Billboards entlang der Verbindung) | `world.gd` Smog-FX |
| **Flut** | heute (blauer Rand, steigender Wasserspiegel). Zu viel Stadt → das Meer steigt | `_set_flood_risk`, `flood()` |

### 4.6 Graustufen- und Größen-Prüfung (neu: Sheet je Akt)

`test_models.gd --sheet=` baut heute alle Arten nebeneinander. Neu: `--era=<name>` baut das Sheet mit den Arten und
Paletten dieses Zeitalters. Das Sheet wird auf 360 px Breite und in Graustufen angesehen. Pflichtpaare, die
unterscheidbar sein müssen:

- Akt 1: Lava / Basalt / Urozean. Basalt und totes Wasser liegen in Graustufen nah beieinander, deshalb: Wasser
  heller (Himmel-Fresnel), Ufer-Saum sichtbar, Basalt mit großen hellen Brocken.
- Akt 2: Ursuppe / Einzeller (der Unterschied darf leise sein, die Regel sagt es mit dem Bedürfnis-Symbol) und
  Fels nass / trocken.
- Akt 3: Moos / Farn / Wald, Algen / Wasser.
- Akt 5–6: Pflanzenfresser / Raubtiere / Haustiere / Vögel / Amphibien.

---

## 5. Zusammenwachsen (gleiche Felder, die sich berühren)

### 5.1 Regel für alle Arten

- **Wer ist „gleich“?** Dieselbe Art (beim Acker zusätzlich dieselbe Furchenrichtung, wie heute in
  `World._furrows_match`). Das gilt auf derselben Seite **und über Würfelkanten**.
- **Der Boden ist schon zusammen.** Gleiche Art zählt im Boden-Shader als „selbst“ (`nb_b.a = 2`). Pflaster,
  Furchen, Kiesel, Moos und Wasser laufen heute schon durch. Neu ist der **Inhalt**: Teile auf der Fuge.
- **Besitz-Regel:** Jede Fuge gehört dem Feld südlich bzw. westlich davon. Ein Feld setzt Fugen-Teile nur an seiner
  N- und O-Fuge und an der Ecke NO, wenn N, O und NO gleich sind. So entsteht nichts doppelt (`FieldView._merge_mask`,
  Prototyp).
- **Würfelkanten:** Auf der gebogenen Kante steht nie ein Teil, denn es würde über die Kante kippen. Dort zeigt nur
  der Boden die Verbindung, und die Teile rücken auf beiden Seiten bis an die Kante heran (statt
  `INSIDE`-Abstand nur 0,02 nach innen).
- **Bauen:** Der Fugen-Inhalt hängt an den Nachbarn. `FieldView.set_neighbors` rechnet die Maske, und ändert sie
  sich, wird nur dieses Feld neu gelegt und gebacken (Cache-Schlüssel enthält die Maske; Prototyp). Ein Teil im
  Cache je Maske: 8 Masken × 4 Varianten bleiben unter dem LRU-Limit (64), weil nur Felder mit gleichen Nachbarn sie
  brauchen.
- **Animation:** Wird eine Gruppe verbunden, läuft ein Lichtpuls entlang der neuen Fuge (Markierung `merge` für
  0,4 s), und die Fugen-Teile wachsen gestaffelt (`_grow_in`). Wird sie getrennt, schrumpfen sie in 0,25 s. Beim
  Drehen gilt die laufende Fuge als neutral (wie heute), nach dem Einrasten wird neu gerechnet.
- **Gruppen-Ertrag:** Bringt eine Gruppe mehr (z. B. 2 reife Äcker = ×2 Ernte), zeigt die Gruppe beim Ertrag
  **eine** Zahl über ihrer Mitte („×2“ als goldene Plakette, 0,8 s), nicht eine je Feld. Die Gruppen-Mitte rechnet
  `World` aus den Feldern der Gruppe (Mittelwert der Weltpositionen, auf die Würfeloberfläche projiziert).

### 5.2 Wald → ein Wald (Prototyp)

Fugen-Bäume, die Bäume innen sind 18 % größer, es gibt kein Totholz und keine Stümpfe am Rand zur gleichen Art, und
der Hirsch darf bis an die Fuge laufen. Ab 4 Feldern stehen in der Mitte der Gruppe 1–2 Großbäume (Eiche 1,5×).
Beim Großen Wald sind die Fugen-Bäume Fichten.

### 5.3 Acker → ein großes Feld

Furchen laufen durch (heute schon). Neu: Die Saatreihen (`Models.crops`) laufen bis an die Fuge (heute enden sie
vorher), der Zaun steht nur am **Außenrand der Gruppe** (Zaun-Seiten aus der Nachbarmaske: nur dort, wo kein gleicher
Acker liegt), es gibt **eine** Vogelscheuche je Gruppe (in dem Feld mit der kleinsten Id) und ab 3 Feldern einen
Feldweg mit Karren über die Fuge. Erntezustand: Alle Felder einer Gruppe reifen gleichzeitig (Regel), also stehen sie
als eine goldene Fläche da.

### 5.4 Tiere → eine Herde

Herden-Agenten dürfen über gleiche Fugen laufen. Technisch bleibt jeder Agent in seiner `FieldView`, aber sein Raum
(`_free`-Punkte) reicht über die N- und O-Fuge in das gleiche Nachbarfeld. Beim Wechsel übergibt das Feld den Agenten
mit Position an den Nachbarn (`FieldView.hand_over`, nur auf derselben Seite). Die Herde hält zusammen: Ziel-Punkte
werden zum Schwerpunkt der Gruppe gezogen. Ab 3 Feldern führt ein Leittier, und die anderen folgen versetzt.

### 5.5 Häuser → eine Stadt; Wasser → ein See; Moos/Wiese → ein Teppich

- **Stadt:** Die Straßen verbinden sich (Pflaster läuft heute schon durch). Neu: Häuserzeile über die Fuge
  (Stadthäuser Giebel an Giebel), ein Marktplatz an der Ecke NO, wenn 4 Stadtfelder zusammenkommen, und ab 3 Feldern
  ein Turm in der Mitte der Gruppe. Dorf: ein gemeinsamer Brunnen und Wege von Tür zu Tür über die Fuge.
- **See:** ist schon da (`Look.water_boxes/segs`). Neu nur: Leben (4.2) mischt an den Fugen weich.
- **Moos/Wiese:** keine Büsche am Rand zur gleichen Art, die Blumen laufen durch.

### 5.6 Kosten

Im Prototyp gleiche Draw-Calls und +15 % Primitive bei einer 7er-Waldgruppe. Ziel: höchstens +20 % Primitive bei voll
verbundenem Würfel; Fugen-Teile werden mitgebacken.

---

## 6. Verlust-Hinweis („−1“)

Der Ziel-Fortschritt fällt, wenn ein Ziel-Feld durch eine Gefahr verloren geht (verbrannt, überflutet, gefressen,
verhungert, im Krieg zerstört). Weiterentwickeln zur nächsten Stufe ist **kein** Verlust und zeigt nie ein Minus.

1. **Am Feld (0,5 s):** Der Grund ist sichtbar. Feuer ist Asche (`burn`), Flut deckt das Feld mit Wasser zu
   (`flood`), Hunger macht es grau und die Figuren sinken (`_dust`), ein Raubtier lässt ein Tier mit Staubwölkchen
   verschwinden, Krieg hinterlässt Rauch (`war_fx`). Das kommt aus den heutigen Effekten.
2. **Marke (0,8 s):** Aus dem Feld steigt eine kleine rote Plakette mit dem Art-Symbol und „−1“
   (`icons/<kind>.svg` + Zahl, roter Rand `#e5483c`). Sie fliegt zum Ziel-Chip (wie die Glaubens-Herzen heute fliegen).
   Ist das Feld nicht im Bild, startet die Plakette am Bildrand in Richtung des Felds.
3. **Chip:** Die Zahl zählt sichtbar herunter (2 → 1), blinkt einmal rot (`Style.FIRE_DEEP`, wie die rote
   Vorschau beim Drehen), und der Chip zittert kurz (±3 px, 0,2 s). Kein Text-Pill bei einem einzelnen Verlust; bei 3
   oder mehr in einer Runde ein Pill „−3“ mit Symbol.
4. Das Gegenstück beim Gewinn bleibt wie heute (goldene Plakette „+1“). Plus und Minus sehen gleich aus, nur Farbe und
   Vorzeichen unterscheiden sich. So lernt man es ohne Erklärung.

Schnittstelle: Event `loss` {field, from, kind, cause} aus den Regeln (Regel-Plan). `World` spielt 1, `day_ui.gd`
spielt 2–3 (`_on_loss`, neben `_on_preview_chip`). Die Vorschau beim Drehen zeigt Verluste schon heute als rote
Geister-Zahl („2→1/3“).

---

## 7. Gefahren als Folgen: Vorzeichen eine Drehung vorher

Einheitliche Sprache für alle Gefahren, damit man sie ohne Text lernt:

- **Ursache sichtbar:** Das Feld, das die Gefahr *auslöst*, trägt das Vorzeichen in der Welt (Wolke, Glut, Dunst,
  Wasserspiegel).
- **Ziel markiert:** Das Feld, das etwas *verliert*, bekommt den roten Gefahren-Rand im Boden (`set_mark("danger")`,
  pulsierend, heute schon) und ein Symbol darüber (wie Blitz und Flut heute).
- **Verbindung:** Wo Ursache und Ziel verschiedene Felder sind (Smog, Raubtier, Vulkan), verbindet sie ein zarter
  Streifen über die Fuge (Rauchband, Spur, Glutlinie), damit man sieht, *was* man wegdrehen muss.
- **Vorschau beim Drehen:** Vorzeichen erscheinen und verschwinden schon beim Ziehen, wie Bedürfnis-Symbole heute
  (`preview` liefert `fire_risk`, `flood_risk`, neu `volcano_risk`, `hunt_risk`). Wer die Ursache wegdreht, sieht das
  Vorzeichen verblassen, bevor er loslässt.

| Gefahr (Folge) | Ursache (sichtbar) | Vorzeichen eine Drehung vorher | Ereignis | Kamera |
|---|---|---|---|---|
| **Blitz** | trockener Wald ohne Wasser daneben | dunkle Wolke **nur** über diesem Wald, trockenes Laub (leicht gelblich, `scorch` 0,2), Blitz-Symbol | Blitz + Feuer (heute) | dreht hin (heute `_focus_round8`) |
| **Vulkan** | zu viel Lava an einem Fleck (Klumpen) | die Lava-Gruppe glüht heller (`lava_e` +40 %), Risse pulsieren, Rauchsäule, Beben (`quake` 0,3) | Ausbruch: Kegel wächst, Glutbrocken fallen auf Nachbarn, Asche-Himmel 2 s | dreht hin, schüttelt |
| **Hunger** (Menschen, Tiere) | Futter/Nahrung fehlt | Bedürfnis-Symbol grau und pulsierend, Figuren grau und langsam (heute) | Feld schrumpft, Staub | dreht hin (heute) |
| **Jagd / Überjagung** | Raubtiere neben Pflanzenfressern ohne Ausweichen | Wolf steht an der Fuge, Herde drängt sich zusammen, Spur über die Fuge | ein Tier weniger (6) | – |
| **Krieg** | Kirche an Kirche | gekreuzte Schwerter, rote Front (heute) | Front fällt (heute) | – |
| **Smog** | Industrie neben Natur | Dunstband vom Schlot zum Opferfeld, Opferfeld vergilbt leicht | Feld fällt (heute) | – |
| **Flut** | zu viel Stadt auf einer Seite | blauer Rand, Wasserspiegel steigt an den Kanten (heute) | Wasser über Felder (heute) | dreht hin (heute) |
| **Meteor** | (Werkzeug, Antwort auf Krieg) | Zielkreuz am Boden, Glutpunkt am Himmel wächst | Einschlag, Krater, Staubwinter (7.4) | Schütteln |

### 7.1 Vulkan (neu, Akt 1)

- Klumpen = mehr Lava-Felder zusammenhängend als die Regel erlaubt. Das Vorzeichen liegt auf der ganzen Gruppe
  (Glut heller, gemeinsamer Puls im Shader-Takt `TIME`, damit alle Felder gleich pulsieren).
- Ausbruch: Auf dem Feld mit den meisten Lava-Nachbarn wächst ein Kegel (Modell `volcano`, 0,6 s mit `_grow_in`).
  4–6 Glutbrocken fliegen in Bögen (CPUParticles3D, 12 Teilchen) auf die Nachbarn, und die Stimmung hält 2 s `glut`
  mit Asche ×2.

### 7.2 Blitz nur bei Trockenheit

Wasser in der Nähe zeigt sich als Schutz: Wald neben Wasser hat sattes, dunkles Grün und am Rand zum Wasser
nassen Boden (`wet` 0,3 dauerhaft als Ufer-Feuchte). Trockener Wald hat einen leichten Gelbstich. So sieht man die
Gefahr, bevor die Wolke kommt.

### 7.3 Warnungen und Ziel-Chip

Wie in `GDPD_GRAFIK.md` 7.4: Kein Vorzeichen, kein Rauch und keine Wolke verdeckt den Ziel-Chip. Vorzeichen leben in
der 3D-Welt unter der Oberfläche.

### 7.4 Meteor-Folge (Akt 6)

Nach dem Einschlag 1 Runde **Staubwinter**: Stimmung `dunst` mit 50 %, Sonne schwach. Danach blendet die Stimmung
zurück. Rein optisch, die Regeln entscheiden, ob es Folgen hat.

---

## 8. Tag/Nacht und Jahreszeiten (Akt 4)

### 8.1 Tag und Nacht

- **Wann:** im Takt der Drehungen, nicht der Uhr (z. B. 4 Drehungen Tag, 2 Nacht; Regel-Plan). Ein kleines
  Sonne/Mond-Symbol neben dem Ziel-Chip zeigt, wann die Nacht kommt (`moon.svg` gibt es). Das ist ein Hinweis, kein
  Text.
- **Look:** `tag` → `abend` (eine Drehung) → `nacht` (Prototyp) → `morgen`. Überblendung 1,5 s nach dem Einrasten,
  nie während einer Drehung.
- **Nacht muss lesbar bleiben:** Füll-Licht ≥ 0,6, Umgebung ≥ 0,85 (Prototyp-Werte), Sterne nur im Himmel.
  Nachts gibt es Licht: Fenster `warm` ×2,5, Laternen, Lagerfeuer bei Hütten, Glühwürmchen über Wiesen (CPUParticles3D
  mit `mote`, 20 Stück, nur „hoch“). Ein Mond (Billboard-Scheibe im Backdrop, `moon_uv`) steht gegenüber der Sonne.
- **Spiel-Bedeutung zeigen:** Was nachts ruht (Pflanzen wachsen nicht), bekommt einen blauen Schimmer statt Wachs-Puls.
  Was nachts gefährlich ist (Raubtiere jagen?), hat Augen-Leuchten. Das gilt nur, wenn die Regeln es so vorsehen.

### 8.2 Jahreszeiten

Ein globaler Wert `season` (0 Frühling, 1 Sommer, 2 Herbst, 3 Winter, fließend) in `Look.set_season(s)`:

| | Boden (`ground.gdshader`) | Laub (`foliage.gdshader`) | Acker (`crops`) | Himmel |
|---|---|---|---|---|
| Frühling | frisches Grün, Blütentupfer +50 % | hellgrün, Blütenbäume blühen | Saat | klar |
| Sommer | wie heute | wie heute | grün → reif | warm |
| Herbst | Wiese gelblicher, Laubstreu | **Laubbäume gelb-orange** (Ton je Baum aus `UV2.x`-Zufall), Nadelbäume bleiben | reif → geerntet | goldener |
| Winter | **leichte Schneedecke** (≤ 45 %, Rauschen, nur Oberseiten), Wasser mit Eisrand | Laubbäume kahl (Krone ausgeblendet über `COLOR.a`-Maske, Stamm bleibt), Fichten mit Schnee-Tupfern | Stoppeln mit Schnee | grau-blau, Schneeflocken (wie Regen-Striche) |

- **Lesbarkeits-Grenze:** Schnee nie über 45 % und nie auf Wasser, Lava oder Pflaster. Die Arten bleiben an der
  Silhouette erkennbar. Das Graustufen-Sheet wird für den Winter einzeln geprüft.
- **Wachstum und Ernte im Jahreslauf:** Die Ernte ist das Ereignis des Herbsts. Menschen tragen Garben heim, die
  Felder werden zu Stoppeln, und über dem Dorf erscheint die Ernte-Zahl der Gruppe (×2 bei Gruppen, 5.1).
- Kosten: nur Uniforms, kein Neubau. Die Kronen im Winter blendet der Shader über eine Maske in `COLOR.b` aus; Laub
  und Stamm sind getrennt markiert, und der Baker behält Vertexfarben.

---

## 9. Oberfläche (Grafik-Anteil der Backlog-Wünsche)

- **Übersicht der Schöpfung:** 7 Akte als Band. Erreichte Akte zeigen ein kleines Bild der eigenen Welt (Schnappschuss
  am Ende des letzten Levels, 256² JPG in `user://`). Gesperrte Akte zeigen nur das Schloss und keinen Himmel des
  Zeitalters (nicht spoilern). Der aktuelle Akt hat den Himmel seines Zeitalters als Hintergrund der Kachel.
- **Gott in der Übersicht antippen** öffnet ihn (Backlog). Grafisch: weicher Lichtrand um den Gott, wenn man ihn
  berührt (`CharacterView`), danach der Editor.
- **HUD zentrierter und etwas größer** (Backlog): Ziel-Chip, Schritte-Zähler (statt Drehungs-Limit) und Punkte stehen
  in **einer** Leiste in der Mitte. Den Abbrechen-Streifen unten gibt es schon. Schritte: kleine Zahl mit Fuß-Symbol,
  ohne Ring-Countdown, denn es gibt kein Limit mehr. Sterne-Schwellen zeigen sich als 3 kleine Punkte unter der Zahl,
  die erlöschen, wenn man darüber ist.
- **Punkte als einzige Währung, Laden:** Münz-Symbol wird Punkte-Symbol (`star` oder neu `points.svg`). Der Laden zeigt
  Wunder (Regen, Meteor), Serien-Schutz und Gott-Teile als Karten mit 3D-Vorschau. Nichts aus späteren Akten.
- **100-Sekunden-Challenge:** großer Ring-Timer um den Punkte-Zähler, rot in den letzten 10 s. Feuer kostet 5 s:
  „−5 s“-Plakette fliegt vom Feuer zum Ring. Pausiert die Wahl-Karte, wird der Ring grau.

---

## 10. Leistungsbudget

Es gilt `GDPD_GRAFIK.md` 10 (Mittelklasse-Handy: ≤ 350 Draw-Calls, ≤ 250 k Primitive, 60 fps ruhig).
Zusätze der Schöpfung:

| Baustein | Kosten | Grenze / Qualitätsstufe |
|---|---|---|
| Zeitalter (Stimmung, Paletten) | nur Uniforms, Tween 2 s | – |
| Backdrop: Glut, Dunst, Asche, Sterne | +1 Textur-Abfrage (Asche), Sterne ohne Textur | niedrig: kein Funkeln, keine Asche |
| Lava im Boden-Shader | +2 triplanare Abfragen (6 Zugriffe), nur wo `lav > 0` (Zweig) | niedrig: kein Fluss (`TIME` aus), nur Risse |
| Leben im Wasser (Einzeller, Algen) | +1 Abfrage (Zellen), nur bei `w_life > 0` | niedrig: Algen ja, Pünktchen aus |
| Funken (Akt 1), Glühwürmchen (Nacht) | 1 CPUParticles3D je, 60 / 20 Teilchen | mittel: halb, niedrig: aus |
| Dampf an Lava-Ufern | Billboards, ≤ 12 im Würfel | niedrig: ≤ 4 |
| Fische | 1 MultiMesh je Wasserfeld, Bewegung im Shader | niedrig: nur Ringe |
| Vögel je Nistplatz | 1 MultiMesh je Feld (5 Vögel) | niedrig: 2 |
| Zusammenwachsen (Fugen-Teile) | mitgebacken, gleiche Draw-Calls, ≤ +20 % Primitive | – |
| Herden über Fugen | Agenten wie heute, ≤ 40 aktive | niedrig ≤ 15 |
| Jahreszeiten, Schnee | Uniforms im Boden- und Laub-Shader | – |

Prototyp-Messung (llvmpipe, voller Würfel): 156–224 Draw-Calls, 30–143 k Primitive. Alle Zeitalter liegen unter dem
Ziel. Die Tour bekommt `CHECK perf` je Akt (Abschnitt 12).

---

## 11. Umsetzung: was wohin gehört

| Thema | Datei | Funktion / Stelle | Prototyp |
|---|---|---|---|
| Zeitalter-Tabelle | neu `scripts/eras.gd` (`class_name Eras`) | `ERAS`, `era_of(act, level)`, `mix(a, b, t)` | `Look.ERA_GROUND`, `ERA_WATER` |
| Zeitalter setzen | `scripts/world.gd` | `set_era(name, dur)`, `set_era_mix(a, b, t)`, `_day_mood()` → Zeitalter statt `morgen/abend` nach Tag-Nummer | `World.MOODS` „glut“, „dunst“, „nacht“ |
| Stimmungen | `scripts/world.gd` | `MOODS` + Schlüssel `lowglow`, `haze`, `stars`, `ash`, `moon` in `_apply_mood` | ja |
| Himmel | `shaders/backdrop.gdshader` | `glow_c`, `low_glow`, `haze`, `stars`, `ash`; neu `moon_uv` | ja (ohne Mond) |
| Bodenpaletten je Zeitalter | `scripts/look.gd` | `set_era()`, `ground_params()` mit Überschreibung, `_nb_b` (Lava-Flag 3), `apply_ground` (`lava`, `w_deep`, `w_shallow`, `w_life`, `glint`) | ja |
| Lava, Wasser-Leben | `shaders/ground.gdshader` | Lava-Zweig nach dem Nachbar-Mischen (`lav`), `w_life`-Block im Wasser, Gleich-Prüfung `nb_b.a` 1,5–2,5 | ja |
| Leben mischt an Fugen | `ground.gdshader`, `field_view.gd` | `nb_life[8]` neben `nb_fx`, `_push_fx` | – |
| neue Arten (Inhalt) | `scripts/field_view.gd` | `_build_content`: `_b_lava`, `_b_rock`, `_b_moss`, `_b_fern`, `_b_swamp`, `_b_nest`, `_b_herd`, `_b_predator`, Zeitalter-Zweige in `_b_earth`, `_b_water` (Enten erst ab Akt 5) | Lava, Basalt, Enten-Sperre |
| neue Modelle | `scripts/models.gd` | `get_model`: `volcano`, `fern`, `tree_fern`, `horsetail`, `reed`, `nest`, `den`, `bones`, `sheaf`, `stubble`; Figuren `creature_mesh`: `wolf`, `bison`, `frog`, `fish` | – |
| Wasser-Dampf | `field_view.gd` | `_update_steam(kinds)` aus `set_neighbors` | ja |
| Fische | `field_view.gd` + neu `shaders/fish.gdshader` | MultiMesh je Wasserfeld, Kreisbahn im Vertex-Shader | – |
| Zusammenwachsen | `field_view.gd` | `_merge_mask` in `set_neighbors`, Fugen-Teile je Builder, `_bake_key` + Maske; Herden: `hand_over()` | Wald |
| Gruppen | `world.gd` | `_groups()` (Flutfüllung über Nachbarn gleicher Art, auch über Kanten), Gruppen-Mitte, `merge`-Lichtpuls | – |
| Verlust-Hinweis | `world.gd` (Feld-FX), `day_ui.gd` (`_on_loss`, Chip) | Event `loss` | – |
| Vorzeichen | `field_view.gd` | `apply_state8`: neue Schlüssel `volcano`, `hunt`, `dry`; `_set_bolt` nur trockener Wald | – |
| Jahreszeiten | `look.gd`, `ground.gdshader`, `foliage.gdshader`, `models.gd` (`COLOR.b` Laubmaske) | `Look.set_season(s)` | – |
| Nacht-Lichter | `models.gd::material("warm")`, `world.gd::_add_life` | Emission nach Stimmung, Glühwürmchen | – |
| Akt-Übergang | `world.gd`, `day_ui.gd` | `act_transition()` vor der Ziel-Karte, mit `overnight_wave` | – |
| Graustufen-Sheet je Zeitalter | `tests/test_models.gd` | `--era=`; neue Arten und Zustände in `specs` | – |

---

## 12. Reihenfolge und Prüfungen

1. **Zeitalter-Grundlage** (`eras.gd`, `Look.set_era`, `World.set_era`, Backdrop, Moods): Damit sieht Akt 1–3 schon
   anders aus, auch mit heutigen Arten. Prüfung: Tour-Bilder `s1_glut`, `s2_dunst`, `s3_blau`; `CHECK era <name>`.
2. **Urzeit-Arten** (Lava, Basalt, Urozean, Dampf, Vulkan) mit den Prototyp-Werten aus Abschnitt 0.
   Prüfung: Graustufen-Sheet Akt 1; `CHECK lava_glow` (Emission > 0 an Lava, = 0 an Basalt ohne Lava-Nachbarn).
3. **Leben im Wasser** (`w_life`, `nb_life`, Algen, Einzeller-Puls, Himmel wird blau mit Sauerstoff).
   Prüfung: `CHECK water_life` (totes Wasser in Akt 1: `w_life == 0`, keine Enten, keine Fische).
4. **Zusammenwachsen** Wald, Acker, Stadt; danach Herde. Prüfung: `test_models` „Fugen-Teile: keine Doppelten“
   (zwei gleiche Nachbarn → genau ein Satz Fugenbäume); `CHECK merge_seam`.
5. **Verlust-Hinweis** und Vorzeichen (Vulkan, trockener Wald, Jagd). Prüfung: `CHECK loss_cue` (Chip zählt herunter,
   Plakette erscheint), Tour-Bild `s6_verlust`.
6. **Pflanzen und Tiere** (Moos, Farn, Urwald, Vögel, Amphibien, Pflanzenfresser, Raubtiere, Fische).
7. **Tag/Nacht und Jahreszeiten.** Prüfung: Graustufen-Sheet Nacht und Winter.
8. **Leistung:** `CHECK perf act=<n> draw=<n> prims=<n>` je Akt in der Tour; Messung am Handy.

Jeder Schritt einzeln: `test_rules` „0 Fehler“, `test_models` „OK test_models“, Smoke, Tour, und die Bilder ansehen.
Neue `CHECK`-Namen müssen in die Liste in `.github/workflows/gdpd.yml`.

---

## 13. Offene Fragen und Risiken

- **Ids und Regeln der neuen Arten** kommen aus dem Regel-Plan. Dieses Dokument nimmt an: Einzeller, Algen und Fische
  sind für die Grafik Wasser (`is_water`) mit Lebens-Stufe. Wenn die Regeln sie als Land-Arten führen, bricht der
  „eine See“. Bitte im Regel-Plan so festhalten.
- **Moos gegen Wiese** und **Pflanzenfresser gegen Raubtiere** sind die riskantesten Paare. Wenn das Graustufen-Sheet
  sie nicht trennt, gilt die Reihenfolge Boden-Helligkeit → Silhouette → Anzahl (wie `GDPD_GRAFIK.md` 2.3).
- **Glühen am Handy:** Die Lava lebt vom Environment-Glühen (Emission > 1). Ist es am Gerät schwach, braucht die
  Lava eine hellere Albedo in den Rissen (Rückfall: Risse `#ff7a2a` als Albedo, Emission 0,8).
- **Tag/Nacht-Takt** nach Drehungen kann unruhig wirken. Nur nach dem Einrasten überblenden und nie öfter als alle
  3 Drehungen.
- **Welt weiterführen im Akt** (2.4) braucht Speicherplatz für Zeitalter und Sauerstoff je Akt. Das Brett selbst
  bleibt aus den Pools.
- Am echten Handy zu prüfen: Lava-Glühen, Nacht-Lesbarkeit, Fisch-MultiMesh, Bildrate mit Funken.
