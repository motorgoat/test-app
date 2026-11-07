# gdpd – Punkte und Laden: eine Währung, ein fairer Laden

Stand: 7. November 2026. Grundlage: die Entscheidung „Die Schöpfung“ und die Wünsche in `NAECHSTE_SCHRITTE.md`
(„Kein Drehungs-Limit mehr … Je weniger Schritte, desto mehr Punkte (und Sterne)“, „Punkte sind die Währung … Münzen
und Punkte zu einer Währung zusammenlegen“, „Später mehr Teile und Skins (Shop, Premium)“). Dieses Dokument legt fest:
wie man Punkte verdient, wofür man sie ausgibt, was nie verkauft wird, wie der Laden aussieht, wie gespeichert und
umgestellt wird. Alle Zahlen sind mit einer Wirtschafts-Simulation über 30 und 60 Tage geprüft (Abschnitt 9).

Inhalt: 0 Entscheidungen · 1 Begriffe · 2 Punkte im Level · 3 Weitere Quellen · 4 Tages-Grenzen · 5 Laden-Katalog
und Preise · 6 Fairness-Regeln · 7 Laden-Ablauf (Oberfläche) · 8 Speichern und Umstellung · 9 Simulation ·
10 Umsetzung · 11 Tests und Tour-Prüfungen · 12 Texte · 13 Offene Fragen

---

## 0. Entscheidungen (Kurzfassung)

| Thema | Entscheidung |
|---|---|
| Währung | **Punkte** (Symbol: goldene Münze mit ✦, Icon `points`). Münzen gibt es nicht mehr. **Glaube** bleibt ein Wert *in* der Welt (Akt 6, freies Spiel) und ist keine Währung. **Sterne** (★) bewerten ein Level und kaufen nichts. |
| Level | Kein Schritt-Limit. `Punkte = 10 + 5 × Sterne + max(0, 2 × Ziel − Schritte)`. ★★★ bei ≤ Ziel-Schritte, ★★ bei ≤ Ziel2, sonst ★. Spanne 15 … ~35. |
| Wiederholen | „Nochmal“ zahlt nur die **Verbesserung** gegenüber dem besten Ergebnis dieses Levels. |
| Weitere Quellen | Serienbonus (+1 je Serientag, höchstens +5, beim ersten Sieg des Spieltags), Extras im Weiterbauen (+5), Wachsen im Weiterbauen (+1, höchstens 10 je Spieltag), Meilensteine (7er: Serienschutz oder +30; 14 / 30 / 50 / 100 / 365: +30 / +60 / +80 / +150 / +300), Welt des Tages (Level-Formel), freies Spiel und 100-Sekunden-Challenge (je höchstens +10 am Tag), Video (optional, +5, höchstens 2 am Tag). |
| Ausgaben | Wunder (Regen 6, Blitzschutz 10, Meteor 20), Hilfe (Tipp 3, Zurück 3, Serienschutz 40), Gott (Teile 50–180, Skins 400–750), später Welten-Themes (800) und ein Sammelstück (Goldener Würfel 2500). |
| Nie verkauft | Das Drehen und Wachsen, Level, Welt des Tages, Weiterbauen, freies Spiel, Fortschritt, Sterne. Ein Level kann nicht verloren gehen und braucht nie einen Kauf. Alles, was es heute gratis gibt (6 Grundformen, alle Farben, 13 Zubehörteile), bleibt gratis. |
| Gegen Sterne-Kauf | Ein gekauftes Wunder zählt **2 Schritte**. Gemessen: eine Regen-Hilfe spart dem guten Bot im Mittel 0,6–1,0 Schritte; mit +2 bringt sie in 4,7 % der Fälle einen Stern mehr, sonst nie. |
| Gegen Inflation | Tages-Grenzen auf alle wiederholbaren Quellen, Vorrats-Grenzen auf Verbrauchsgüter, monatlich neue Teile, ein teures Sammelstück. Kein Höchststand im Geldbeutel (nichts verfällt). |
| Werbung | Nur belohnte Videos, freiwillig, nur im Laden, nie im Level, nie auf einem Sieg- oder Hilfe-Bildschirm, nie in den ersten 3 Spieltagen. Heute ein Platzhalter (`Balance.ADS_ON = false`). |
| Premium (später) | Einmal-Kauf „Schöpfer-Paket“: keine Video-Knöpfe, ein Skin-Satz, ein Theme, Abzeichen. **Keine Punkte-Pakete, kein Abo, keine Lootboxen.** |
| Umstellung | `Punkte = 10 × Münzen` (alte Preise ×10, Serienschutz wird billiger: 50 → 40), einmalig, mit kurzem Hinweis. Neue Spieler starten mit 30 Punkten. |
| Laden | Eingang: Punkte-Chip in der Übersicht, Menü „Laden“, „Mehr Teile“ beim eigenen Gott, Serienschutz-Chip, leeres Wunder im Dock. 4 Reiter: Wunder · Hilfe · Gott · Welten. Kauf immer mit Bestätigung; Gott-Teile probiert man vorher an und kann sie zurückgeben, solange der Laden offen ist. |
| Nicht spoilern | Ein Wunder steht erst im Laden, wenn es im Spiel schon vorkam (Regen ab dem ersten Regen-Level, Blitzschutz ab dem ersten Blitz, Meteor ab dem Meteor-Level). Der Reiter „Welten“ zeigt vor dem Ende der Schöpfung nur „Bald mehr“. |

---

## 1. Begriffe

- **Schritt:** eine Drehung einer Scheibe. Ein Werkzeug aus dem Dock, das das Level selbst gibt (Regen, Meteor mit
  Glauben), ist kein Schritt. Ein **gekauftes** Wunder zählt 2 Schritte. „Zurück“ nimmt die Drehung zurück, der
  Schritt bleibt gezählt. Ein Tipp zeigt nur eine Drehung, erst die Drehung zählt.
- **Ziel / Ziel2:** pro Level in den Daten (`stars: [ziel, ziel2]`, wie heute in `Days`): ★★★ bei ≤ Ziel Schritten,
  ★★ bei ≤ Ziel2, ★ bei jedem Ende. Faustregel beim Bauen eines Levels: Ziel ≈ das beste Drittel des guten Bots,
  `Ziel2 = Ziel + ceil(Ziel / 2)` (die heutigen Tage: 4/6, 5/7, 4/6, 6/9, 4/7, 4/6, 4/6).
- **Spieltag:** wie in `Daily` (wechselt um 3 Uhr). Alle Tages-Grenzen zählen pro Spieltag.
- **Punkte:** die einzige Währung, ganzzahlig, nie negativ.
- **Vorrat:** gekaufte Verbrauchsgüter (Wunder, Tipps, Zurück, Serienschutz) liegen im Vorrat, bis man sie benutzt.

---

## 2. Punkte im Level

### 2.1 Formel

```
Punkte = BASE + PER_STAR × Sterne + max(0, 2 × Ziel − Schritte)
BASE = 10, PER_STAR = 5
```

Beispiele (Ziel 4, Ziel2 6 · Ziel 6, Ziel2 9):

| Schritte | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 12 | 20 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Ziel 4/6 | 31 ★★★ | 30 ★★★ | 29 ★★★ | 23 ★★ | 22 ★★ | 16 ★ | 15 ★ | 15 ★ | 15 ★ | 15 ★ | 15 ★ |
| Ziel 6/9 | 35 ★★★ | 34 ★★★ | 33 ★★★ | 32 ★★★ | 31 ★★★ | 25 ★★ | 24 ★★ | 23 ★★ | 17 ★ | 15 ★ | 15 ★ |

Warum so:
- **Schaffen zählt am meisten** (15 von höchstens ~35). Ein schwacher Spieler bekommt fast die Hälfte von dem, was
  ein Profi bekommt, und kein Level ist wertlos.
- **Jeder Schritt weniger zählt** (der „Schnell“-Teil), aber nur bis zum Doppelten des Ziels; darüber bleibt es bei 15.
  So ist ein schwieriges Level nie eine Strafe, und es gibt keinen Grund, ein Level abzubrechen.
- Ein Stern ist ein großer Sprung (+5), damit „noch ein Stern“ sich lohnt.
- Gefahren kosten **Felder und damit Schritte**, nie direkt Punkte: verbrennt der Wald, braucht man mehr Drehungen.
  Fällt der Ziel-Fortschritt („−1 Tier“), braucht man ebenfalls mehr Schritte. Die Formel braucht dafür nichts Eigenes.

### 2.2 Bestes Ergebnis, Nochmal

- Pro Level wird das beste Ergebnis gespeichert (`level_best`). Ein Sieg zahlt `max(0, neu − bisher)`.
  Erster Sieg: alles. „Nochmal“ mit einem neuen Brett: nur die Verbesserung (z. B. 16 → 23: +7).
- Simulation: Wer jedes Level 5-mal wiederholt, bekommt in 30 Tagen +96 Punkte mehr als ein Profi ohne Wiederholen
  (+6 %). Wiederholen ist ein Spaß-Ziel, keine Farm.

### 2.3 Sieg-Karte

Die Sieg-Karte zählt die Punkte einzeln hoch (je eine Zeile, Icons zuerst, 0,25 s pro Zeile, zum Schluss fliegen die
Münzen zum Chip):

| Zeile | Wann |
|---|---|
| ✔ Geschafft +10 | immer |
| ★★ +10 | Sterne × 5 |
| ⚡ Schnell +3 | `2 × Ziel − Schritte`, nur wenn > 0 |
| 🔥 Serie +4 | erster Sieg des Spieltags |
| ↑ Besser +7 | statt der drei ersten Zeilen bei „Nochmal“ (nur die Verbesserung); 0 → „Gleich gut“ |

Im Level selbst zeigt das HUD nur **Schritte** und die Sterne-Leiste (★★★ bis 4, dann ★★ bis 6), keine Punkte:
eine Zahl zum Optimieren genügt.

---

## 3. Weitere Quellen

| Quelle | Punkte | Grenze | Bemerkung |
|---|---|---|---|
| Level geschafft | 15 … ~35 (2.1) | Verbesserung nur | ein neues Level pro Spieltag |
| Serienbonus | +min(Serie, 5) | einmal je Spieltag | beim ersten Sieg des Spieltags (Level oder Welt des Tages) |
| 7er-Meilenstein | +1 Serienschutz, bei 2 Schutz: +30 | alle 7 Serientage | wie heute (`SHIELD_FULL_COINS` 3 Münzen → 30 Punkte) |
| große Meilensteine | 14: +30 · 30: +60 und Teil „Flammenkranz“ · 50: +80 · 100: +150 und Skin „Sonnengott gold“ · 365: +300 | einmal | zusätzlich zum 7er-Meilenstein |
| Weiterbauen: Extra | +5 je Extra („Extra: 4 Wälder“) | so viele Extras, wie das Level hat (1–3) | wie heute „+1 ✦“, jetzt Punkte |
| Weiterbauen: Wachsen | +1 je neu gewachsenes Feld | **10 je Spieltag** (gemeinsam mit der Welt des Tages) | „jede Reihe nur einmal“ gilt weiter; ersetzt „1 Münze je 10 Felder, höchstens 3“ |
| Welt des Tages | Level-Formel | Verbesserung nur, einmal je Spieltag neu | nach der Schöpfung (ab Level 31) |
| Freies Spiel | +10 für eine vollendete Welt | einmal je Spieltag | Einfach/Mittel/Schwer |
| 100-Sekunden-Challenge | +10 für einen neuen Rekord | einmal je Spieltag | sonst nur der Rekord (pro Modus) |
| Video (optional) | +5 | **2 je Spieltag** | nur im Laden, nur wenn `ADS_ON` (8.4) |
| Start | 30 | einmal | genug für einen Tipp-Versuch und fast ein erstes Teil |

Was **keine** Punkte gibt: Drehen ohne Wachsen, Hin-und-her-Drehen (die „once“-Regel), Glaube, Wünsche, Zeit im
Spiel, Einloggen ohne Spielen, Benachrichtigungen antippen.

---

## 4. Tages-Grenzen (gegen Farmen und Inflation)

| Grenze | Wert | Warum |
|---|---|---|
| Weiterbauen-Wachsen | 10 je Spieltag | Ohne Grenze holt ein Farmer mit 300 Drehungen am Tag 617 statt 234 Punkte in 30 Tagen; mit Grenze liegt er nur 4 % über dem Profi (9.3). |
| Video | 2 je Spieltag | Videos bleiben unter 25 % des Einkommens eines Spielers, der sie jeden Tag schaut (9.2: 270 von 1066). |
| Freies Spiel, Challenge | je 10 je Spieltag | Das freie Spiel ist offen und unbegrenzt spielbar, darf aber das tägliche Level nicht ersetzen. |
| Wiederholen | nur die Verbesserung | Das beste Ergebnis eines Levels ist höchstens ~35 wert. |
| Gekaufte Hilfe pro Level | 3 (Wunder + Tipps + Zurück zusammen) | Niemand kauft sich durch ein Level; die Sterne bleiben ehrlich. |
| Vorrat | Regen 3, Blitzschutz 2, Meteor 1, Tipp 5, Zurück 5, Serienschutz 2 | Kein Horten von Verbrauchsgütern; der Kauf-Knopf sagt „Vorrat voll“. |
| Geldbeutel | keine Grenze | Nichts verfällt (das wäre unfair). Gegen „alles gekauft“ helfen neue Teile jeden Monat und das Sammelstück (5.4). |

Alle Grenzen stehen in `balance.gd` (10.1) und werden pro Spieltag in `[punkte] heute` gezählt (8.1). Die Uhr
verstellen bringt nichts: die Zähler hängen am Spieltag aus `Daily.observe`, wie die Serie.

---

## 5. Laden-Katalog und Preise

Preise in Punkten. „Tage“ = wie viele Spieltage ein Spieler dafür braucht (Median-Einkommen pro Spieltag aus 9.2:
Profi 51, Normal 42, Gelegenheit 23).

### 5.1 Wunder (Reiter „Wunder“, Vorrat, benutzt im Dock)

| Wunder | Preis | Vorrat | Wirkung | ab | Tage (P / N / G) |
|---|---|---|---|---|---|
| Regen | 6 | 3 | wie der Regen im Dock (Natur wächst, löscht Feuer, macht Acker bei Menschen) | erstes Regen-Level (Akt 2) | 0,1 / 0,1 / 0,3 |
| Blitzschutz | 10 | 2 | die nächsten 5 Schritte schlägt kein Blitz ein (die Warnung wird zu „Geschützt“) | erstes Blitz-Level (Akt 3) | 0,2 / 0,2 / 0,4 |
| Meteor | 20 | 1 | wie der Meteor (eine Art fällt um eine Stufe, löscht Krieg) ohne Glauben | Meteor-Level (Akt 6) | 0,4 / 0,5 / 0,9 |

- Im Level und in der Welt des Tages zählt jedes gekaufte Wunder **2 Schritte** (Pille „+2 Schritte“ beim Benutzen).
  Im Weiterbauen und im freien Spiel zählt es nichts (dort gibt es keine Sterne). In der 100-Sekunden-Challenge
  gibt es keine gekauften Wunder (gleiche Bedingungen für den Rekord).
- Gekaufte Wunder liegen im Dock **hinter** den Werkzeugen des Levels: erst wird das Gratis-Werkzeug benutzt.
- Ist ein Werkzeug im Dock leer und hat man eines im Vorrat, zeigt das Dock den Vorrat (kleines Münz-Abzeichen
  „+2“). Hat man keins, zeigt das Dock eine Preis-Pille „6 ✦“; Antippen öffnet die Kauf-Bestätigung (7.4).
- Freies Spiel: die heutigen Münz-Preise für leere Werkzeuge (`RAIN_COST` 2, `BOLT_COST` 3, `MONSOON_COST` 5) werden
  6 / 8 / 15 Punkte. Strafen (Gewitter, Flut) kosten weiter Glauben, nicht Punkte.

### 5.2 Hilfe (Reiter „Hilfe“)

| Hilfe | Preis | Vorrat | gratis | Regel |
|---|---|---|---|---|
| Tipp | 3 | 5 | **1 je Level**; in den ersten 3 Leveln leuchtet er nach einer Pause von selbst (wie heute Tag 1–2); der **Rettungs-Tipp** ist immer gratis | Rettungs-Tipp: ab `3 × Ziel` Schritten leuchtet der Tipp-Knopf, jeder Tipp ist dann gratis. So bleibt niemand stecken. |
| Zurück | 3 | 5 | 1 je Level | nimmt die letzte Drehung zurück (auch Feuer und Verluste), der Schritt bleibt gezählt |
| Serienschutz | 40 | 2 | 1 alle 7 Serientage | wie heute (`Daily`): überbrückt verpasste Tage nur, wenn er die ganze Lücke schließt |

Im Level gilt: höchstens 3 gekaufte Hilfen zusammen (4.). Der Tipp-Knopf zeigt den Zustand: „1 frei“ → „3 ✦“ →
„Rettung“ (grün).

### 5.3 Gott (Reiter „Gott“)

Alles, was es heute im Ersteller gibt, bleibt **gratis**: 6 Grundformen (Bart, Göttin, Sonne, Wolke, Katze, Nudel),
alle Farben, 13 Zubehörteile in 3 Plätzen (Kopf, Gesicht, Hals). Neu kommen dazu (Daten-Zeilen + SVGs, wie
`Character.ACCESSORIES`; Spec `GDPD_TAEGLICH_CHARAKTER.md` 3.8):

| Stufe | Preis | Anzahl zum Start | Beispiele | Tage (P / N / G) |
|---|---|---|---|---|
| einfach | 50 | 4 | Stirnband, Federn, Sommersprossen, Ohrringe | 1 / 1,2 / 2,2 |
| schön | 80 | 6 | Lorbeerkranz, Sternenbrille, Wolkenschal, Mondsichel, Blüten im Haar, Halskette | 1,6 / 1,9 / 3,5 |
| besonders | 120 | 6 | Sternenkrone, Regenbogenschal, Funkenaugen, Blitz-Amulett, Sonnenhut, Muschelkette | 2,4 / 2,9 / 5,2 |
| prächtig | 180 | 4 | Sonnenstrahlen-Krone, Glutaugen, Nordlicht-Umhang, Kometenschweif | 3,5 / 4,3 / 7,8 |
| Skin (ganze Grundform) | 400 / 500 / 600 / 750 | 4 | Spaghettimonster mit Fleischbällchen-Krone (die Nudel als echtes Monster), Sternengöttin, Vulkan-Gott, Baumgeist | 8–15 / 10–18 / 17–33 |

- Gott-Teile dürfen nichts aus späteren Akten zeigen (kein Meteor-Amulett vor dem Meteor-Level). Solche Teile haben
  `ab: "level:N"` und stehen erst danach im Laden.
- Geschenke: „Flammenkranz“ bei 30 Serientagen, „Sonnengott gold“ (Skin) bei 100. Sie stehen nie zum Verkauf.
- Ein Skin ändert nur das Aussehen und die Sprechblasen-Farbe, nie Regeln, Texte oder Hilfe.

### 5.4 Welten (Reiter „Welten“, später)

| Ding | Preis | ab | Wirkung |
|---|---|---|---|
| Würfel-Theme (Holz, Marmor, Gold-Rand) | 800 | nach Level 30 | Rahmen und Fugen des Würfels, Hintergrund; Lesbarkeit der Felder bleibt (GDPD_GRAFIK.md) |
| Himmel-Theme (Polarlicht, Sternennebel) | 800 | nach Level 30 | Himmel und Licht im Weiterbauen und im freien Spiel; nie in einem Level der Schöpfung (dort zeigt der Himmel das Zeitalter) |
| Goldener Würfel (Sammelstück) | 2500 | nach Level 30 | ein goldener Rand und ein Titel unter dem Gott („Schöpfer“); für alle, die schon alles haben |
| neue Welten (Insel, Wüste, Winter) | **gratis** | später | neue Inhalte sind Spiel, kein Laden-Ding; der Reiter zeigt nur ihren Start |

Vor dem Ende der Schöpfung zeigt der Reiter genau eine Kachel: ein Schloss und „Bald mehr“. Keine Namen, keine Bilder.

### 5.5 Videos (Platzhalter)

Unten im Laden, nur wenn `Balance.ADS_ON` (heute `false`): Knopf „▶ Video · +5 ✦“, darunter „2 heute“. Nie im
Level, nie auf der Sieg- oder Hilfe-Karte, nie als Pop-up, nicht in den ersten 3 Spieltagen, aus im Kinder-Modus.
Heute ruft er `Game.reward_ad()` auf (Platzhalter, ohne echte Werbung).

### 5.6 Premium (später, eigenes Dokument vor dem Einbau)

- Einmal-Kauf „Schöpfer-Paket“ (Richtwert 4,99 €): keine Video-Knöpfe, ein Skin („Himmelsschmied“), ein Theme,
  ein Abzeichen am Gott. Danach gibt es nichts weiter zu kaufen.
- Kein Verkauf von Punkten, Serienschutz, Wundern oder Leveln für Geld. Kein Abo. Keine Lootboxen. Echte Käufe
  nur hinter einer Eltern-Sperre (Rechenaufgabe), nie aus einer Benachrichtigung.

---

## 6. Fairness-Regeln (gelten für jeden späteren Laden-Inhalt)

1. **Das Kernverb ist nie zu kaufen.** Drehen, Wachsen, Verbinden, Zusammenwachsen, jedes Level, die Welt des Tages,
   Weiterbauen, freies Spiel und die Challenge kosten nie Punkte und haben keine Energie und keine Wartezeit außer
   „ein neues Level pro Tag“ (das gilt für alle gleich und ist nicht kaufbar).
2. **Kein Level braucht einen Kauf.** Ein Level ist nicht zu verlieren; es gibt einen Gratis-Tipp je Level und den
   Rettungs-Tipp ab `3 × Ziel`. Die Simulation prüft, dass der schwache Bot jedes Level ohne Kauf beendet (9.1).
3. **Sterne sind nicht zu kaufen.** Gekaufte Wunder zählen 2 Schritte; höchstens 3 gekaufte Hilfen pro Level; Sterne
   schalten nichts frei. Gemessen: mit +2 bringt ein gekaufter Regen nur in 4,7 % der Fälle einen Stern mehr.
4. **Was gratis war, bleibt gratis.** Nichts aus dem heutigen Ersteller kommt hinter einen Preis.
5. **Kein Druck.** Keine Countdown-Angebote, keine falschen Rabatte, keine „nur heute“-Preise, kein Laden-Knopf auf
   dem Bildschirm „Serie verloren“, keine Benachrichtigung mit Laden-Inhalt, keine Lootboxen, keine zweite (Premium-)
   Währung. Der Charakter sagt nie „Kauf …“; er sagt höchstens „Neu im Laden“ (einmal, wenn ein Teil dazukommt).
6. **Klare Preise.** Jeder Preis steht in Punkten am Ding; der Kauf-Knopf zeigt den Stand vorher → nachher.
   Gott-Teile kann man vorher anprobieren und zurückgeben, solange der Laden offen ist.
7. **Nicht spoilern.** Was erst später im Spiel vorkommt, steht nicht im Laden (siehe 0.).

Das Gegenbeispiel ist *Godus* (22cans, 2014): Das Kernverb (Land formen) war an Glaube gebunden, den man mühsam
einsammeln musste; Edelsteine (eine Premium-Währung) verkürzten Wartezeiten, und der Fortschritt hing an
Truhen-Timern. Spieler hatten das Gefühl, das Spiel sei absichtlich zäh gemacht, um Abkürzungen zu verkaufen.
gdpd macht deshalb das Gegenteil: eine Währung, die man nur durch Spielen verdient; keine Timer außer dem einen
neuen Level pro Tag; nichts Mühsames, das man wegkaufen kann; nur Schmuck und kleine Hilfen im Laden.

---

## 7. Laden-Ablauf (Oberfläche)

### 7.1 Eingänge

| Wo | Was | Öffnet |
|---|---|---|
| Übersicht, Kopfzeile | Punkte-Chip (ersetzt den Münz-Chip; Antippen, Halten erklärt „Deine Punkte“) | Laden, letzter Reiter |
| Menü | Zeile „Laden“ mit Münz-Icon und Punktestand | Laden, Reiter „Wunder“ |
| Übersicht, eigener Gott | Antippen öffnet den Gott (Wunsch: ansehen, ändern, Art zu reden); dort Knopf „Mehr Teile“ | Laden, Reiter „Gott“ |
| Serienschutz-Chip | Antippen | Laden, Reiter „Hilfe“, Serienschutz hervorgehoben (ersetzt die heutige Schutz-Karte) |
| Dock im Level | Preis-Pille an einem leeren Wunder | nur die Kauf-Bestätigung (7.4), kein ganzer Laden |
| Sieg-Karte | **kein** Eingang | – |

Der Laden ist ab dem ersten geschafften Level offen (vorher gibt es nichts zu kaufen außer Hilfe, die gratis ist).
Beim ersten Öffnen zeigt der Charakter einmal: „Dein Laden. Nur Schönes.“

### 7.2 Aufbau (Hochformat, ein Bildschirm)

```
┌──────────────────────────────────┐
│ ←   Laden              ✦ 312     │  Kopf: zurück, Titel, Punkte-Chip
│ [Wunder] [Hilfe] [Gott] [Welten] │  Reiter als Icon-Pillen (Icon + 1 Wort)
│ ┌──────────┐ ┌──────────┐        │
│ │  (Bild)  │ │  (Bild)  │        │  2 Spalten, Karten 1:1,2
│ │  Regen   │ │Blitzschutz│       │  Name (1–2 Wörter)
│ │  6 ✦  x2 │ │  10 ✦    │        │  Preis-Chip; Vorrat „x2“
│ └──────────┘ └──────────┘        │
│ …                                │
│        ▶ Video · +5 ✦ (2 heute)  │  nur mit ADS_ON
└──────────────────────────────────┘
```

- Reiter „Gott“: oben groß der eigene Gott (wie im Ersteller, 40 % der Höhe), darunter die Plätze als kleine
  Pillen (Kopf · Gesicht · Hals · Form), darunter die Teile. Antippen eines Teils **setzt es probehalber auf** (der Gott
  freut sich); der Knopf unten wird „Kaufen · 80 ✦“ oder „Anlegen“ (wenn schon gekauft) oder „Ablegen“.
- Zustände einer Karte: **Preis** (kaufbar), **grauer Preis** (zu wenig Punkte), **✔ Hast du** (gekauft), **Angelegt**
  (grüner Rand), **x2** (Vorrat), **Vorrat voll**, **Neu** (Punkt oben rechts, bis einmal angesehen).
- Leere Reiter gibt es nicht: „Welten“ zeigt vor dem Ende die Schloss-Kachel „Bald mehr“.

### 7.3 Nicht genug Punkte

Der Kauf-Knopf ist grau und sagt „Dir fehlen 12 ✦“. Darunter eine Zeile Icons, wie man Punkte bekommt:
★ Level · 🔨 Weiterbauen · 🔥 Serie. Kein Video-Angebot an dieser Stelle.

### 7.4 Kauf-Bestätigung (immer)

Ein Blatt von unten (wie die heutigen Modal-Karten, `ui._modal_card`):

```
   (Bild des Dings)
   Regen kaufen?
   ✦ 312 → 306
   [ Kaufen ]   [ Nein ]
```

- Im Level zusätzlich die Zeile „Zählt 2 Schritte“ (bei Wundern) bzw. „2 von 3 Hilfen“ (wenn das die Grenze berührt).
- Nach „Kaufen“: Münzen fliegen vom Chip zum Ding, die Karte dreht sich zu „✔ Hast du“, kurzer Ton, der Charakter sagt
  einen Satz („Steht dir!“, „Gut für schlechte Tage.“, „Regen bereit.“). Ein Wunder aus dem Dock wird sofort
  benutzbar (der Finger zeigt auf das Feld wie heute bei Regen).
- Gott-Teile: „Zurückgeben“ unter dem angelegten Teil, solange der Laden offen ist (volle Erstattung). Verbrauchsgüter
  kann man nicht zurückgeben.
- Doppeltes Tippen kauft nie zweimal (der Knopf ist bis zum Ende der Animation gesperrt).

### 7.5 HUD und Übersicht

- Übersicht: Kopfzeile Menü · Serie · Serienschutz · **✦ Punkte** (der Wunsch „HUD mehr ins Zentrum und etwas
  größer“ gilt auch hier: die Chips stehen mittig, Schrift 1,15×).
- Level: kein Punkte-Chip, nur „Schritte 7“ und die Sterne-Leiste. Erst die Sieg-Karte zeigt Punkte.
- Weiterbauen: der Chip „Extra: …“ wie heute; „+1 ✦“ fliegt beim Wachsen hoch, bis „10/10 heute“ (dann kommt eine
  Pille „Heute genug Punkte · Bau weiter“ und weiteres Wachsen zählt nur noch für Extras).

---

## 8. Speichern und Umstellung

### 8.1 Spielstand (Profil `save_path`, ConfigFile)

```
[konto]
punkte = 312                 ; int ≥ 0, die einzige Währung
version = 2                  ; 1 = Münzen (alt), 2 = Punkte
umgestellt = 0               ; > 0: Punkte aus der Umstellung, der Hinweis ist noch nicht gezeigt (dann 0)
; „credits“ wird bei der Umstellung gelöscht (cfg.erase_section_key)

[punkte]
level_best = [29, 23, 15, …] ; Array[int], bestes bezahltes Ergebnis je Level der Schöpfung (0 = nie)
wdt_best = {20401: 23, …}    ; Dictionary Spieltag → bestes Ergebnis der Welt des Tages (letzte 21)
heute = [20437, 6, 1, 0, 10] ; [Spieltag, Weiterbauen, Videos, freies Spiel, Challenge] – alte Spieltage = 0
summe = 1507                 ; alles je verdient (Statistik, Feier „1000 Punkte“)
verlauf = [[20437, "level", 23], [20437, "kauf:regen", -6], …]   ; die letzten 50 Buchungen (Hilfe bei Fehlern)

[laden]
besitz = ["stirnband", "lorbeer"]       ; gekaufte und geschenkte Gott-Teile, Skins, Themes (ids)
vorrat = {"regen": 2, "tipp": 1}        ; Verbrauchsgüter (Serienschutz bleibt in [taeglich] schutz)
gesehen = ["regen", "stirnband", …]     ; ids, deren „Neu“-Punkt schon weg ist
theme = ""                              ; angelegtes Theme ("" = Standard)
```

- Angelegte Gott-Teile stehen weiter im Aussehen in `[charakter]` (`user://charakter.cfg`); der Laden prüft beim
  Laden des Aussehens, ob ein Teil in `besitz` ist (gratis-Teile immer), sonst wird es abgelegt.
- Der Level-Zähler für „gekaufte Hilfe ≤ 3“ und „1 Tipp / 1 Zurück frei“ lebt nur im laufenden Versuch
  (`GameState`), wird also nicht gespeichert.
- Serienschutz: Anzahl weiter in `[taeglich] schutz` (Daily); der Kauf zieht Punkte ab und ruft `Daily.add_shield`.
- `bau_muenzen` in `[taeglich]` wird `heute[1]` in `[punkte]` (beim Umstellen gelesen, dann gelöscht).

### 8.2 Umstellung (einmal, beim Laden, `konto.version < 2`)

```
punkte = 10 × credits                 ; Münzen werden Punkte (alte Preise ×10)
punkte = max(punkte, POINTS_START)    ; wer 0–2 Münzen hatte, bekommt mindestens 30
umgestellt = punkte
heute = [bau_muenzen[0], 10 × bau_muenzen[1] (höchstens 10), 0, 0, 0]
version = 2; credits löschen; bau_muenzen löschen
```

- Kein Doppel-Zählen: die Umstellung läuft nur bei `version < 2` und schreibt `version = 2` im selben Speichern.
- Hinweis in der Übersicht, einmal (Sprechblase des Charakters): „Deine Münzen sind jetzt Punkte.“ mit dem
  Münz-Icon und der Zahl. Danach `umgestellt = 0`.
- Sterne der alten 7 Tage: die neue Kampagne hat ein eigenes Dokument für die Umstellung des Fortschritts; für die
  Punkte zählt nur `level_best` der neuen Level (es gibt keine Punkte rückwirkend, damit niemand doppelt bekommt).
- Neue Spieler: `punkte = 30`, `version = 2`.

---

## 9. Simulation

### 9.1 Methode

- **Schritte pro Level** kommen aus dem echten Regelmodell (`gdpd_sim/b3`, `run8.py`) mit den drei Bots
  (`good` = der Tipp, `greedy` = 1-Zug ohne Werkzeuge, `weak` = halb zufällig) **ohne Schritt-Grenze** (`limit 60`),
  auf 80 erzeugten Brettern und den 20 Pool-Brettern je Tag (zusammen 100 je Tag und Bot). Bleibt ein Bot stecken
  (totes Brett), zählt er als gerettet (Rettungs-Tipp) mit `4–6 × Ziel` Schritten → 15 Punkte.
  Die Tabelle zeigt die 80 erzeugten Bretter; die Simulation zieht aus allen 100.

  | Vorlage | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
  |---|---|---|---|---|---|---|---|
  | good Median / ★★★ | 5 / 28 % | 6 / 30 % | 5 / 26 % | 8 / 39 % | 3 / 88 % | 5 / 20 % | 7,5 / 19 % |
  | greedy Median / fertig | 5 / 98 % | 8 / 100 % | 9,5 / 100 % | 10 / 66 % | 6 / 65 % | 8 / 39 % | 6,5 / 25 % |
  | weak Median / fertig | 11 / 100 % | 14 / 100 % | 25 / 100 % | 24 / 64 % | 20 / 56 % | 30,5 / 10 % | 36 / 2,5 % |

  „fertig“ ohne Hilfe; der Rest braucht den Rettungs-Tipp. Für die Akte 6–7 der Schöpfung müssen die neuen Level
  so gebaut werden, dass der schwache Bot mit Rettungs-Tipps fertig wird (siehe Regel 6.2).
- **Kampagne:** 30 Level in 7 Akten (4 / 4 / 5 / 4 / 4 / 7 / 2), jedes Level nimmt die Vorlage seines Akts
  (die 7 heutigen Tage als Schwierigkeits-Stellvertreter; Akt 6: Vorlagen 6, 6, 6, 7, 6, 7, 7).
  Ein Level pro gespieltem Spieltag; wer einen Tag auslässt, spielt am nächsten das wartende Level.
- **Weiterbauen:** Wachsen je Drehung aus `GDPD_BALANCE_2.md` 6.3 (ehrlich 0,31 / 0,60 / 0,94 / 0,63 / 0,04 / 0,24 /
  0,07; zufällig 0,10 … 0,29; bestes Hin-und-her 0,01 … 0,21), Extras mit den gemessenen Quoten, langsamere Spieler
  brauchen 1,5× (greedy) bzw. 2,5× (weak) so viele Drehungen dafür.
- **Serie** wie `Daily`: Serienschutz überbrückt nur ganze Lücken, 7er-Meilenstein gibt Schutz oder +30.
- **Spieler** (je 500 Läufe):

  | Spieler | Bot | spielt (nach Spieltag / nach Pause) | Weiterbauen je Tag | Videos | Wiederholen | Hilfe kaufen |
  |---|---|---|---|---|---|---|
  | Profi | good | 100 % | 40 Drehungen, ehrlich | 0 | 1× je Level | nie |
  | Normal | greedy | 92 % / 70 % | 15, ehrlich | 0 | nie | 50 % der zähen Level (Regen + Tipp) |
  | Gelegenheit | weak | 75 % / 50 % | 5, zufällig | 0 | nie | 80 % der zähen Level |
  | Video | weak | 92 % / 70 % | 10, zufällig | 2 je Tag | nie | 80 % |
  | Farmer | good | 100 % | 300, bestes Hin-und-her | 2 je Tag | 5× je Level | nie |

  „Zäh“ = mehr als `2 × Ziel` Schritte. Kaufen: Serienschutz, wenn man keinen hat (nicht Profi/Farmer); sonst
  sofort das billigste Gott-Teil (eine Reserve von 40 für den Schutz bleibt).
- Skript: `/tmp/claude-0/-home-user-test-app/3861a76b-89b3-5028-950e-8c56bdad2d34/scratchpad/econ/econ_sim.py`
  (`python3 econ_sim.py 500 30`); die Schritt-Daten: `run8.py gen:80 1,2,3,4,5,6,7 good,greedy,weak
  '{"all":{"limit":60}}' econ_steps_gen.json` und `run8.py pool:<days_schoepfung.json> … econ_steps_pool.json`.

### 9.2 Ergebnis: 30 Tage (Mittelwerte aus 500 Läufen)

| Spieler | Level | ★/Level | verdient | davon Level | Serie | Extras | Bauen | Meilensteine | Video | Hilfe gekauft | Schutz gekauft | Teile (von 20) | Rest | 1. Teil (Tag) | 400 gespart (Tag) | je Spieltag (Median / 90 %) | Serie am Ende |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Profi | 30 | 2,07 | **1507** | 770 | 140 | 223 | 224 | 150 | 0 | 0 | 0 | 16,1 | 127 | 1 | 7 | 51 / 66 | 30 |
| Normal | 26,8 | 1,44 | **1063** | 497 | 121 | 216 | 157 | 73 | 0 | 55 | 70 | 11,9 | 60 | 2 | 11 | 42 / 52 | 23,6 |
| Gelegenheit | 20,2 | 1,02 | **478** | 307 | 75 | 65 | 14 | 17 | 0 | 118 | 101 | 4,6 | 36 | 6 | 28 | 23 / 27 | 8,5 |
| Video | 27,0 | 1,02 | **1066** | 409 | 122 | 155 | 32 | 78 | 270 | 172 | 67 | 11,0 | 54 | 2 | 14 | 38 / 45 | 23,9 |
| Farmer | 30 | 2,07 | **1912** | 866 | 140 | 222 | 233 | 150 | 300 | 0 | 0 | 18,5 | 84 | 1 | 6 | 63 / 79 | 30 |

Erster Spieltag (inkl. Start 30): Profi 79, Normal 73, Gelegenheit 51 → jeder kann am ersten oder zweiten Tag ein
erstes Teil (50) kaufen. Erste Woche: 380 / 283 / 112.

### 9.3 Ergebnis: 60 Tage (Schöpfung fertig, danach Welt des Tages; 300 Läufe)

| Spieler | verdient | Teile (von 20) | Skins (von 4) | Rest | Serie am Ende |
|---|---|---|---|---|---|
| Profi | 3031 | 20 | 1,7 | 176 | 60 |
| Normal | 2128 | 18,5 | 0 | 90 | 41,8 |
| Gelegenheit | 924 | 7,6 | 0 | 43 | 10,8 |
| Video | 2173 | 17,5 | 0 | 90 | 40,7 |
| Farmer | 3845 | 20 | 3,0 | 255 | 60 |

Gegenproben (30 Tage, 300 Läufe):

| Probe | Ergebnis |
|---|---|
| Weiterbauen **ohne** Tages-Grenze | Profi 492, Farmer 617 Punkte nur aus dem Bauen (+25 % fürs Farmen); mit Grenze 10: 224 / 234 (+4 %) |
| Farmer ohne Videos | 1612 (Profi 1507: +7 %, fast alles aus 5× Wiederholen) |
| gekaufter Regen (+2 Schritte) | spart dem guten Bot im Mittel 0,97 / 0,76 / 0,63 / 0,84 / 0,00 Schritte (Vorlagen 2–6); ein Stern mehr in 18 von 384 Fällen (4,7 %) |

### 9.4 Was die Zahlen sagen

- **Das tägliche Level trägt die Wirtschaft** (51 % beim Profi, 64 % bei Gelegenheit). Zuverlässiges Spielen zahlt
  sich aus (Serie + Meilensteine 19 % beim Profi), Können auch (pro Level: Profi 25,7, Normal 18,5, Gelegenheit 15,2),
  ein schwacher Spieler bekommt pro Level also immer noch 60 % vom Profi.
- **Farmen lohnt sich nicht:** mit Tages-Grenzen holt ein Bot, der 300 Mal am Tag hin und her dreht und jedes Level
  5-mal wiederholt, ohne Videos nur 7 % mehr als ein Profi.
- **Videos sind ein Zubrot, kein Muss:** 25 % beim täglichen Video-Schauer; wer nie schaut, verpasst kein Teil, das
  nicht nach ein paar Tagen Spielen ohnehin kommt.
- **Preise passen:** ein Regen kostet ein Viertel des Tageseinkommens eines Gelegenheits-Spielers (6 von 23); Serienschutz ≈ ein bis zwei Spieltage;
  ein Teil 1–8 Spieltage; ein Skin 1–3 Wochen. In 30 Tagen hat der Profi 16 der 20 Teile, Normal 12, Gelegenheit 5
  – jeder hat etwas, keiner alles.
- **Inflation nach der Schöpfung:** der Profi verdient in der Welt des Tages weiter ~1500 im Monat. Damit Punkte
  etwas wert bleiben, kommen **jeden Monat neue Dinge für etwa 1300 Punkte** (4 Teile ≈ 500 + ein Theme 800) und es
  gibt das Sammelstück (2500). Für Normal- und Gelegenheits-Spieler reicht der Start-Katalog Monate.
- **Gelegenheits-Spieler** gibt 46 % für Hilfe und Schutz aus. Das ist gewollt (Hilfe ist für sie da), aber kein Muss:
  ohne Käufe bleibt jedes Level lösbar (Rettungs-Tipp). Wird der Wert im Feldtest höher, zuerst Regen auf 5 senken.

---

## 10. Umsetzung

### 10.1 `scripts/balance.gd` (neu bzw. umbenannt)

```gdscript
# --- Punkte und Laden (docs/GDPD_PUNKTE_LADEN.md) -------------------------------------------------
static var POINTS_START := 30            # ersetzt CREDITS_START (3)
static var POINTS_PER_COIN := 10         # Umstellung Münzen → Punkte
static var LEVEL_BASE := 10              # Level: 10 + 5 × Sterne + max(0, 2 × Ziel − Schritte)
static var LEVEL_PER_STAR := 5
static var LEVEL_FAST_FACTOR := 2
static var STREAK_BONUS_MAX := 5         # erster Sieg des Spieltags: +min(Serie, 5)
static var MILESTONE_POINTS := 30        # ersetzt SHIELD_FULL_COINS (3)
static var MILESTONE_BIG := {14: 30, 30: 60, 50: 80, 100: 150, 365: 300}
static var MILESTONE_GIFT := {30: "flammenkranz", 100: "sonnengott_gold"}
static var EXTRA_POINTS := 5
static var BUILD_POINTS_MAX := 10        # ersetzt BUILD_COIN_EVERY / BUILD_COIN_MAX
static var FREE_PLAY_POINTS := 10
static var CHALLENGE_RECORD_POINTS := 10
static var ADS_ON := false
static var AD_POINTS := 5                # ersetzt CREDITS_PER_AD
static var AD_MAX := 2
static var ADS_FROM_DAY := 4             # kein Video-Knopf in den ersten 3 Spieltagen
static var SHIELD_PRICE := 40            # war 5 Münzen
static var HINT_COST := 3                # war 1 Münze
static var UNDO_COST := 3
static var HINT_FREE := 1                # je Level
static var UNDO_FREE := 1
static var RESCUE_AT := 3                # ab 3 × Ziel Schritten ist jeder Tipp gratis
static var MIRACLE_STEPS := 2            # gekauftes Wunder zählt so viele Schritte
static var HELP_MAX := 3                 # gekaufte Hilfen je Level
static var RAIN_COST := 6                # freies Spiel: leeres Werkzeug kaufen (war 2 / 3 / 5 Münzen)
static var BOLT_COST := 8
static var MONSOON_COST := 15
```

Die Katalog-Preise stehen nicht in `balance.gd`, sondern in `data/laden.json` (5.).

### 10.2 Dateien

| Datei | Änderung |
|---|---|
| `data/laden.json` (neu) | Katalog: `{"id", "tab": "wunder"\|"hilfe"\|"gott"\|"welten", "art": "wunder"\|"hilfe"\|"teil"\|"skin"\|"theme"\|"sammel", "preis", "vorrat" (max, 0 = einmalig), "ab": "" \| "mech:regen" \| "mech:blitz" \| "mech:meteor" \| "level:N" \| "fertig" \| "geschenk", "platz" (kopf/gesicht/hals/basis), "icon", "titel"}`. Ein Test prüft: ids eindeutig, Preise > 0 außer Geschenken, Titel ≤ 2 Wörter. |
| `scripts/points.gd` (neu, `class_name Points`, statisch wie `Daily`) | `level_points(stars, steps, ziel) -> int`, `pay_level(d, level, pts) -> int` (Verbesserung), `pay_wdt`, `build_point(d, today) -> int` (0/1, Grenze), `ad_ok`, `free_play_ok`, `challenge_ok`, `streak_bonus(streak)`, `milestone(streak, shields_full) -> {points, gift}`, `migrate(cfg) -> int`, `save(cfg, d)`, `load(cfg) -> d`. Keine Knoten. |
| `scripts/shop.gd` (neu, `class_name Shop`, statisch) | `catalog()`, `visible(item, progress) -> bool` (Spoiler-Regel), `buy_error(item, points, owned, stock) -> String` ("" = geht), `buy(...)`, `refund(...)` (nur Gott-Teile in derselben Laden-Sitzung), `owned(id)`, `stock(id)`, `use(id)`. |
| `scripts/game.gd` | `credits` → `points` (mit `credits` als Alias-Getter für alten Code bis zum Umbau), `spend(cost)` bleibt, `_save_profile` / `_load_best` schreiben `[konto] punkte`, `[punkte]`, `[laden]`, Umstellung in `_load_best`; Sieg (`_finish_day`, Welt des Tages) bucht über `Points`; `_build_coins` → `_build_point`; `buy_shield()` mit neuem Preis; `reward_ad()` mit Grenze; Signal `points_changed(delta, source)`. |
| `scripts/game_state.gd` | Schritt-Zähler `steps` (Drehungen + 2 je gekauftem Wunder), `help_bought`, `hint_free_left`, `undo_free_left`, `rescue()` (`steps ≥ RESCUE_AT × ziel`); kein Drehungs-Limit (gehört zum Kampagnen-Umbau). |
| `scripts/daily.gd` | `win()` gibt `points` statt `coins` (Meilenstein), `build_coins` entfällt (Grenze in `Points`), `shield_buy_error` mit Punkten. |
| `scripts/day_ui.gd` | Münz-Chip → Punkte-Chip (Antippen öffnet den Laden), Schutz-Karte → Laden „Hilfe“, Sieg-Karte mit Punkte-Zeilen (2.3), Gott in der Übersicht antippbar. |
| `scripts/shop_ui.gd` (neu) | der Laden (7.2–7.4), gebaut aus `ui._modal_card`, `ui._tile`, `ui._button`; Gott-Vorschau mit `CharacterView`. Überlagerungen, die nicht blockieren, mit `MOUSE_FILTER_IGNORE`. |
| `scripts/ui.gd` | Menü-Zeile „Laden“, Dock-Preis-Pille, Tipp-Knopf-Zustände („1 frei“, „3 ✦“, „Rettung“), Pille „+2 Schritte“. |
| `scripts/character.gd`, `character_creator.gd` | Laden-Teile in `ACCESSORIES` mit `"preis"`; der Ersteller zeigt gekaufte Teile, nicht gekaufte mit Schloss und „Im Laden“. Bestehende Teile ohne Preis = gratis. |
| `icons/points.svg` (neu) | goldene Münze mit ✦ (klar anders als ★) |

---

## 11. Tests und Tour-Prüfungen

### 11.1 `tests/test_rules.gd` (müssen mit „ 0 Fehler“ enden)

1. **level_points:** Tabelle 2.1 (Ziel 4/6 und 6/9) genau; nie unter 15 bei einem Sieg.
2. **improvement:** 16, dann 23 → +7; dann 20 → +0; Welt des Tages getrennt je Spieltag.
3. **streak_bonus / milestones:** Serie 1…9 → +1…+5; Tag 7 mit 2 Schutz → +30; Tag 14 → +30 zusätzlich; Tag 30 →
   +60 und Geschenk „flammenkranz“ in `besitz`.
4. **build_cap:** 15 Wachstümer an einem Spieltag → 10 Punkte; am nächsten Spieltag wieder ab 0; Uhr zurück und vor
   gibt keine neuen 10.
5. **ad_cap:** `reward_ad` 3× → +10; vor Spieltag 4 und mit `ADS_ON = false` → 0.
6. **migration:** `credits = 7`, `version` fehlt → 70 Punkte, `credits` weg, `version = 2`; zweites Laden ändert
   nichts; `credits = 1` → 30; `bau_muenzen = [k, 2]` → `heute[1] = 10`.
7. **shop_buy:** zu wenig Punkte → „Dir fehlen %d ✦“; Vorrat voll → Fehler; Kauf zieht genau den Preis ab; Gott-Teil
   zurückgeben in derselben Sitzung → volle Erstattung, danach nicht mehr; Verbrauchsgut nie.
8. **spoiler:** vor dem ersten Regen-Level ist „regen“ nicht `visible`; Meteor erst nach dem Meteor-Level; „Welten“
   vor Level 30 nur die Schloss-Kachel.
9. **miracle_steps:** ein gekauftes Wunder im Level → `steps + 2`; im Weiterbauen → `+0`; dritte gekaufte Hilfe geht,
   vierte nicht (`HELP_MAX`).
10. **rescue:** ab `3 × Ziel` Schritten kostet der Tipp nichts, auch ohne Punkte.
11. **free_items:** alle heutigen Grundformen und Zubehörteile haben keinen Preis.
12. **texts:** alle neuen Laden-Texte ≤ 6 Wörter (die bestehende ≤ 8-Wörter-Prüfung deckt sie mit ab).

### 11.2 Tour (`main.gd`, Namen in die Liste in `.github/workflows/gdpd.yml`)

| CHECK | Was |
|---|---|
| `points_win` | Level gewinnen: die Sieg-Karte zeigt die Zeilen 2.3, der Chip zählt hoch; Bild `points_win.jpg` |
| `shop_open` | Punkte-Chip antippen → Laden mit 4 Reitern; Bild `shop_wunder.jpg` |
| `shop_god` | Reiter „Gott“: Teil antippen → der Gott trägt es probehalber; kaufen; „✔ Hast du“; Bild `shop_god.jpg` |
| `shop_poor` | mit 0 Punkten: grauer Knopf „Dir fehlen …“, kein Video-Knopf; Bild `shop_poor.jpg` |
| `shop_dock` | im Level leeres Wunder → Preis-Pille → Bestätigung mit „Zählt 2 Schritte“ → Schritte +2 |
| `points_migrate` | Profil mit `credits = 7` laden → 70 Punkte, Hinweis einmal |

---

## 12. Texte (alle neu oder geändert, ≤ 6 Wörter)

| Schlüssel | Text |
|---|---|
| `points` | Punkte |
| `points_explain` (Chip halten) | Deine Punkte. Für den Laden. |
| `shop` | Laden |
| `shop_first` (Charakter, einmal) | Dein Laden. Nur Schönes. |
| `tab_wunder` / `tab_hilfe` / `tab_gott` / `tab_welten` | Wunder / Hilfe / Gott / Welten |
| `buy` | Kaufen · %d ✦ |
| `buy_ask` | %s kaufen? |
| `buy_no` | Nein |
| `buy_missing` | Dir fehlen %d ✦ |
| `stock_full` | Vorrat voll |
| `owned` | Hast du |
| `worn` | Angelegt |
| `wear` / `unwear` | Anlegen / Ablegen |
| `refund` | Zurückgeben |
| `more_parts` | Mehr Teile |
| `soon` | Bald mehr |
| `new_in_shop` (Charakter, einmal je neuem Teil) | Neu im Laden! |
| `steps_cost` | Zählt 2 Schritte |
| `help_left` | %d von 3 Hilfen |
| `hint_free` / `hint_rescue` | 1 frei / Rettung |
| `win_done` / `win_stars` / `win_fast` / `win_streak` / `win_better` / `win_same` | Geschafft / Sterne / Schnell / Serie / Besser / Gleich gut |
| `build_point` | +1 ✦ |
| `build_cap` | Heute genug Punkte · Bau weiter |
| `ad_button` | Video · +5 ✦ |
| `ad_left` | %d heute |
| `migrated` | Deine Münzen sind jetzt Punkte. |
| `shield_buy` | Kaufen · %d ✦ |
| `shield_missing` | Dir fehlen %d ✦ |
| `bought_part` / `bought_shield` / `bought_miracle` (lieb) | Steht dir! / Gut für schlechte Tage. / Regen bereit. |
| frech | Schick, schick! / Sicher ist sicher. / Na dann, Regen! |
| streng | Passt. / Vernünftig. / Bereit. |
| `streak_7_full` (geändert) | Eine Woche! Hier, 30 Punkte. · 7 Tage! 30 Punkte für dich. · Sieben Tage. 30 Punkte. |

---

## 13. Offene Fragen (für Philipp)

1. **Wunder im Level:** sollen gekaufte Wunder in Leveln der Schöpfung überhaupt erlaubt sein (mit +2 Schritten, wie
   hier), oder nur im Weiterbauen und im freien Spiel? Vorschlag: erlaubt, weil sie Spielern helfen, die feststecken,
   und die Sterne ehrlich bleiben.
2. **Name der Währung:** „Punkte“ (wie gewünscht) – oder „Lichter“ / „Sterne-Staub“, passend zur Schöpfung? Der
   Text oben nimmt „Punkte“ und das Symbol ✦.
3. **Premium:** Einmal-Kauf ja/nein und Preis; Videos ganz weglassen, wenn es Premium gibt?
4. **Rangliste der Challenge:** bekommt der Wochen-Beste etwas (z. B. ein Abzeichen, keine Punkte)?
5. **Ersteller:** sollen die neuen Laden-Teile im Ersteller sichtbar sein (mit Schloss) oder nur im Laden?
   Vorschlag: sichtbar mit Schloss, ohne Preis-Druck, Antippen öffnet den Laden beim Teil.
