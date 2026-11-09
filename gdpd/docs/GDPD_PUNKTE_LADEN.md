# gdpd – Punkte und Laden: eine Währung, ein fairer Laden

Stand: 8. November 2026 (Rev. 2). Grundlage: die Entscheidung „Die Schöpfung“ (`GDPD_SCHOEPFUNG.md`) und die Wünsche
in `NAECHSTE_SCHRITTE.md`: „Kein Drehungs-Limit mehr … Je weniger Schritte, desto mehr Punkte (und Sterne)“, „Punkte
sind die Währung … Münzen und Punkte zu einer Währung zusammenlegen“, „Später mehr Teile und Skins (Shop, Premium)“
und das Feedback vom 8. November: **„2 Sterne müssen gut erreichbar sein; 3 Sterne für gutes Spiel“**, „Kombinationen
bleiben wirksam“, „Menü übersichtlicher“.

Dieses Dokument ist **die verbindliche Quelle für alles rund um Punkte und Laden**. Es ersetzt die Punkte-Zeilen in
`GDPD_SCHOEPFUNG.md` (0 Nr. 9, 3.9 „Points“, 6, 13 `punkte`/`punkte_tag`/`gekauft`, 13.1 `credits`); was dort
anzupassen ist, steht in 10.3. Alle Zahlen sind mit einer Wirtschafts-Simulation über 30 und 60 Tage geprüft
(Abschnitt 9), die Schritte pro Level kommen aus dem Regelmodell der Kampagne (`gdpd_sim/b4`, 30 Level).

Inhalt: 0 Entscheidungen · 1 Begriffe · 2 Punkte und Sterne im Level · 3 Weitere Quellen · 4 Tages-Grenzen ·
5 Laden-Katalog und Preise · 6 Fairness-Regeln · 7 Laden-Ablauf (Oberfläche) · 8 Speichern und Umstellung ·
9 Simulation · 10 Umsetzung · 11 Tests und Tour-Prüfungen · 12 Texte · 13 Offene Fragen

---

## 0. Entscheidungen (Kurzfassung)

| Thema | Entscheidung |
|---|---|
| Währung | **Punkte** (Symbol: goldene Münze mit ✦, Icon `points`). Münzen gibt es nicht mehr (**1 Münze = 20 Punkte**). **Glaube** bleibt ein Wert *in* der Welt (Akt 6, freies Spiel) und ist keine Währung. **Sterne** (★) bewerten ein Level und kaufen nichts. |
| Level | Kein Schritt-Limit. `Punkte = 30 + 10 × Sterne + 5 × max(0, Par − Schritte)`, `Par = ★★★-Grenze + 4`. Spanne 40 (★, langsam) … 80 (★★★ genau auf der Grenze) … ~95. |
| Sterne | ★ = geschafft. **★★ für etwa 3 von 4 Spielen eines normalen Spielers** (Bot `greedy` ≥ 75 %, guter Bot ≥ 95 %). **★★★ für gutes Spiel** (guter Bot etwa jedes zweite Mal, 40–70 %). Die Grenzen je Level stehen in der Level-Tabelle der Kampagne und werden mit `stars10.py` aus dem Modell bestimmt (2.2). |
| Wiederholen | „Nochmal“ zahlt nur die **Verbesserung** gegenüber dem besten Ergebnis dieses Levels. |
| Weitere Quellen | Serie (+2 je Serientag, höchstens +10, beim ersten Sieg des Spieltags), Extras im Weiterbauen (+10, höchstens 3 je Level, einmalig), Wachsen im Weiterbauen (+1, höchstens 20 je Spieltag), Meilensteine (7er: Serienschutz oder +50; 14 / 30 / 50 / 100 / 365: +50 / +100 / +150 / +300 / +500), Welt des Tages (Level-Formel), freies Spiel oder 100-Sekunden-Challenge (+20 einmal am Tag), Video (optional, +10, höchstens 2 am Tag). |
| Ausgaben | Wunder (Regen 25, Blitzschutz 40, Meteor 60), Hilfe (Tipp 10, Zurück 10, Serienschutz 100), Gott (Teile 100 / 250 / 400 / 600, Skins 1500–3000), später Welten-Themes (3000) und ein Sammelstück (Goldener Würfel 10 000). |
| Nie verkauft | Das Drehen, Wachsen, Verbinden, Zusammenwachsen, jedes Level, Welt des Tages, Weiterbauen, freies Spiel, Fortschritt, Sterne. Ein Level kann nicht verloren gehen und braucht nie einen Kauf (Gnade und Rettungs-Tipp sind gratis). Alles, was es heute gratis gibt (6 Grundformen, alle Farben, 13 Zubehörteile), bleibt gratis. |
| Gegen Sterne-Kauf | Ein gekauftes Wunder zählt **2 Schritte**, höchstens 1 je Art und Level, höchstens 3 gekaufte Hilfen je Level; die Preis-Pille im Dock erscheint erst in der ★-Zone. Gemessen (9.4): ein gekaufter Regen spart im Mittel 0,36 Schritte; ohne Schritt-Kosten brächte er in 16–22 % der Fälle einen Stern mehr, mit 2 Schritten nur in 1–3 %. |
| Gegen Inflation | Tages-Grenzen auf alle wiederholbaren Quellen, Vorrats-Grenzen auf Verbrauchsgüter, monatlich neue Dinge, ein teures Sammelstück. Kein Höchststand im Geldbeutel (nichts verfällt). |
| Werbung | Nur belohnte Videos, freiwillig, nur im Laden, nie im Level, nie auf einem Sieg- oder Hilfe-Bildschirm, nie in den ersten 3 Spieltagen. Heute ein Platzhalter (`Balance.ADS_ON = false`). |
| Premium (später) | Einmal-Kauf „Schöpfer-Paket“: keine Video-Knöpfe, ein Skin, ein Theme, Abzeichen. **Keine Punkte-Pakete, kein Abo, keine Lootboxen.** |
| Umstellung | `Punkte = max(20 × Münzen, 60)` plus 20 je alter Stern (einmal, `GDPD_SCHOEPFUNG.md` 13.1), mit kurzem Hinweis. Neue Spieler starten mit 60 Punkten. |
| Laden | Eingang: Punkte-Chip in der Übersicht, Menü (oberer Block) „Laden“, „Mehr Teile“ beim eigenen Gott, Serienschutz-Chip, leeres Wunder im Dock. 4 Reiter: Wunder · Hilfe · Gott · Welten. Kauf immer mit Bestätigung; Gott-Teile probiert man vorher an und kann sie zurückgeben, solange der Laden offen ist. |
| Nicht spoilern | Ein Wunder steht erst im Laden, wenn es im Spiel schon vorkam (Regen ab Level 5, Blitzschutz ab Level 12, Meteor ab Level 23). Der Reiter „Welten“ zeigt vor dem Ende der Schöpfung nur „Bald mehr“. |

---

## 1. Begriffe

- **Schritt:** eine Drehung einer Scheibe. Ein Werkzeug, das das Level selbst gibt (Regen-Ladungen, Dampf-Regen,
  Gnade, Meteor aus Glauben), ist kein Schritt. Ein **gekauftes** Wunder zählt 2 Schritte. „Zurück“ nimmt die Drehung
  zurück, der Schritt bleibt gezählt. Ein Tipp zeigt nur eine Drehung, erst die Drehung zählt.
- **s3 / s2:** die Sterne-Grenzen eines Levels (`stars: [s3, s2]` in den Level-Daten): ★★★ bei ≤ s3 Schritten,
  ★★ bei ≤ s2, ★ bei jedem Ende.
- **Par:** `s3 + 4`. Bis dahin zählt jeder Schritt weniger 5 Punkte. (Bisher stand in `GDPD_SCHOEPFUNG.md`
  `par = s2 + 4`; seit die ★★-Grenzen großzügiger sind, wäre das bei Leveln wie 17 mit `s2 = 22` ein Par von 26 und
  damit über 100 Punkte für ein normales Spiel. Par hängt deshalb an s3.)
- **Spieltag:** wie in `Daily` (wechselt um 3 Uhr). Alle Tages-Grenzen zählen pro Spieltag.
- **Punkte:** die einzige Währung, ganzzahlig, nie negativ.
- **Vorrat:** gekaufte Verbrauchsgüter (Wunder, Tipps, Zurück, Serienschutz) liegen im Vorrat, bis man sie benutzt.
- **Verbindung bleibt:** Seit dem Feedback vom 8. November bleibt ein einmal versorgtes Feld versorgt, auch wenn man
  weiterdreht; nur eine Gefahr macht es rückgängig. Für die Punkte heißt das: ein Feld, das wieder satt wird, zählt im
  Weiterbauen nicht noch einmal (wie „jede Reihe wächst nur einmal“), und ein Verlust durch eine Gefahr („−1 Tier“)
  kostet Schritte, nie direkt Punkte.

---

## 2. Punkte und Sterne im Level

### 2.1 Formel

```
Punkte = DONE + PER_STAR × Sterne + FAST × max(0, Par − Schritte)
DONE = 30, PER_STAR = 10, FAST = 5, Par = s3 + 4
```

Beispiele (Grenzen 4/6 und 5/9):

| Schritte | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 12 | 20 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| s3 4, s2 6 (Par 8) | 90 ★★★ | 85 ★★★ | 80 ★★★ | 65 ★★ | 60 ★★ | 45 ★ | 40 ★ | 40 ★ | 40 ★ | 40 ★ | 40 ★ |
| s3 5, s2 9 (Par 9) | 95 ★★★ | 90 ★★★ | 85 ★★★ | 80 ★★★ | 65 ★★ | 60 ★★ | 55 ★★ | 50 ★★ | 40 ★ | 40 ★ | 40 ★ |

Warum so:
- **Schaffen zählt am meisten** (40 von ~80). Wer ein Level beendet, bekommt mindestens die Hälfte von dem, was ein
  Profi bekommt; pro Level gemessen: Profi 79, Normal 65, Gelegenheit 42 (9.2). Kein Level ist wertlos.
- **Ein Stern ist ein spürbarer Sprung** (+10 und meist auch Schritte unter Par, zusammen +15 … +25).
- **Jeder Schritt weniger zählt** bis Par; darüber bleibt es bei 40. Ein schwieriges Level ist nie eine Strafe, und
  es gibt keinen Grund, ein Level abzubrechen.
- Gefahren kosten **Felder und damit Schritte**, nie direkt Punkte. Fällt der Ziel-Fortschritt („−1 Tier“), braucht
  man mehr Schritte. Die Formel braucht dafür nichts Eigenes.
- Frühere Fassungen (`20 × Sterne + 5 × (Par − Schritte)`) gaben dem schwächsten Spieler nur ein Viertel des Profis
  pro Level; mit dem Sockel von 30 ist es gut die Hälfte (9.2).

### 2.2 Sterne-Grenzen (Feedback 8. November: „sehr schwer, überhaupt 2 Sterne zu bekommen“)

Regel für jedes Level (gilt für die Kampagne, die Welt des Tages und neue Welten):

| Stern | Ziel | Messung im Modell (300 bzw. 60 Bretter je Level) |
|---|---|---|
| ★ | jedes Ende | – |
| ★★ | **gut erreichbar**: ein normaler Spieler schafft es in etwa 3 von 4 Spielen | kleinste Grenze `s2 > s3`, bei der `greedy` ≥ 75 % **aller** Spiele und `good` ≥ 95 % mit ≤ s2 beendet |
| ★★★ | **gutes Spiel**: ein guter Spieler etwa jedes zweite Mal | `s3` = Schrittzahl, bei der `good` am nächsten an 55 % liegt (40–70 %) |

Die Grenzen bestimmt `gdpd_sim/b4/stars10.py` aus einem Modell-Lauf; sie stehen in der Level-Tabelle von
`GDPD_SCHOEPFUNG.md` 4.2 (die Kampagne besitzt sie, dieses Dokument nur die Regel). Stand des Laufs `q2.json`
(8. November, 60 Bretter je Level und Bot, Verbindungen bleiben):

| Level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| bisher s3/s2 | 4/6 | 4/5 | 5/7 | 5/6 | 4/6 | 5/7 | 4/6 | 5/7 | 4/6 | 5/6 | 6/8 | 6/7 | 5/6 | 5/8 | 5/8 |
| neu s3/s2 | 4/6 | 4/6 | 5/8 | 5/7 | 5/6 | 4/6 | 5/7 | 5/6 | 4/6 | 5/7 | 6/9 | 6/8 | 5/6 | 6/9 | 6/11 |

| Level | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 | 30 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| bisher s3/s2 | 5/6 | 5/8 | 5/7 | 6/7 | 3/5 | 4/6 | 3/5 | 2/3 | 5/11 | 4/6 | 3/5 | 4/6 | 4/6 | 5/9 | 6/10 |
| neu s3/s2 | 6/10 | 6/22 | 5/9 | 6/12 | 3/5 | 4/10 | 3/5 | 2/4 | 5/13 | 4/8 | 3/5 | 3/5 | 3/6 | 5/15 | 7/14 |

Wirkung über die ganze Kampagne (Simulation 9.2, gleiche Spieler, nur die Grenzen getauscht):

| Spieler | ★★ oder mehr bisher → neu | ★★★ bisher → neu | Sterne je Level bisher → neu |
|---|---|---|---|
| Profi (`good`) | 92 % → **98 %** | 52 % → 57 % | 2,44 → 2,55 |
| Normal (`greedy`) | 69 % → **83 %** | 31 % → 35 % | 1,99 → 2,17 |
| Gelegenheit (`weak`, halb zufällig) | 3 % → 10 % | 0 % → 0 % | 1,04 → 1,10 |

Ausreißer wie Level 17 (`s2 = 22`) zeigen ein Level, das für normale Spieler zu streuig ist; das ist eine Aufgabe für
den Level-Bau (Brett oder Ziel ändern), nicht für die Punkte. Durch `Par = s3 + 4` werden solche Grenzen nie zu einer
Punkte-Quelle. Der Bot `weak` ist absichtlich schwächer als ein echter Gelegenheits-Spieler (er dreht zur Hälfte
zufällig); seine Werte sind die Untergrenze.

HUD im Level: `👣 7` und ein kleiner Ring mit der nächsten Grenze (`★★★ bis 5`, dann `★★ bis 8`), wie in
`GDPD_SCHOEPFUNG.md` 12. Keine Punkte im Level: eine Zahl zum Optimieren genügt.

### 2.3 Bestes Ergebnis, Nochmal

- Pro Level wird das beste Ergebnis gespeichert (`level_best`). Ein Sieg zahlt `max(0, neu − bisher)`.
  Erster Sieg: alles. „Nochmal · mehr Sterne“ (gleiches Start-Brett, `GDPD_SCHOEPFUNG.md` 5): nur die Verbesserung
  (z. B. 45 → 65: +20).
- Simulation: Wer jedes Level 5-mal wiederholt, bekommt in 30 Tagen 146 Punkte mehr als mit einem Versuch (+6 % des
  Level-Einkommens). Wiederholen ist ein Spaß-Ziel, keine Farm.

### 2.4 Sieg-Karte

Die Sieg-Karte zählt die Punkte einzeln hoch (je eine Zeile, Icons zuerst, 0,25 s pro Zeile, zum Schluss fliegen die
Münzen zum Chip):

| Zeile | Wann |
|---|---|
| ✔ Geschafft +30 | immer |
| ★★ +20 | Sterne × 10 |
| ⚡ Schnell +15 | `5 × (Par − Schritte)`, nur wenn > 0 |
| 🔥 Serie +6 | erster Sieg des Spieltags: `2 × Serie`, höchstens 10 |
| ↑ Besser +20 | statt der drei ersten Zeilen bei „Nochmal“ (nur die Verbesserung); 0 → „Gleich gut“ |

---

## 3. Weitere Quellen

| Quelle | Punkte | Grenze | Bemerkung |
|---|---|---|---|
| Level geschafft | 40 … ~95 (2.1) | Verbesserung nur | ein neues Level pro Spieltag |
| Serienbonus | +2 × Serie, höchstens +10 | einmal je Spieltag | beim ersten Sieg des Spieltags (Level oder Welt des Tages) |
| 7er-Meilenstein | +1 Serienschutz, bei 2 Schutz: +50 | alle 7 Serientage | wie heute (`SHIELD_FULL_COINS` 3 Münzen → 50 Punkte) |
| große Meilensteine | 14: +50 · 30: +100 und Teil „Flammenkranz“ · 50: +150 · 100: +300 und Skin „Sonnengott gold“ · 365: +500 | einmal | zusätzlich zum 7er-Meilenstein |
| Weiterbauen: Extra | +10 je Extra (2 Extra-Aufgaben + 1 Extra der Welt, `GDPD_SCHOEPFUNG.md` 7) | höchstens 3 je Level, jedes nur einmal | ersetzt „+1 ✦“ |
| Weiterbauen: Wachsen | +1 je neu gewachsenes Feld (Reihe oder erstes Gedeihen zu einer Art) | **20 je Spieltag** (gemeinsam mit der Welt des Tages) | „jede Reihe nur einmal“ gilt weiter; wieder satt werden zählt nicht; ersetzt „1 Münze je 10 Felder, höchstens 3“ |
| Welt des Tages | Level-Formel | einmal je Spieltag voll, danach nur die Verbesserung | nach Level 30 (Veteranen: schon während der Kampagne) |
| Freies Spiel / 100-Sekunden-Challenge | +20 für die erste vollendete Welt oder den ersten Challenge-Lauf | **einmal je Spieltag** (zusammen) | ein neuer Rekord gibt keine Punkte, nur die Feier und den Rekord |
| Video (optional) | +10 | **2 je Spieltag** | nur im Laden, nur wenn `ADS_ON` (5.5) |
| Start | 60 | einmal | genug für einen Tipp und fast ein erstes Teil |
| alte Sterne (Veteranen) | +20 je Stern | einmal | `GDPD_SCHOEPFUNG.md` 13.1 („Danke fürs Mitspielen“) |

Was **keine** Punkte gibt: Drehen ohne Wachsen, Hin-und-her-Drehen (die „once“-Regel), Felder, die nach einer Gefahr
wieder satt werden, Glaube, Zeit im Spiel, Einloggen ohne Spielen, Benachrichtigungen antippen, Rekorde.

---

## 4. Tages-Grenzen (gegen Farmen und Inflation)

| Grenze | Wert | Warum |
|---|---|---|
| Weiterbauen-Wachsen | 20 je Spieltag | Ohne Grenze holt ein Farmer mit dem besten Hin-und-her (~60 Wachstümer am Tag) in 30 Tagen 1800 statt 600 Punkte aus dem Bauen und liegt (ohne Videos) 40 % über dem Profi; mit Grenze nur 13 % (9.3). |
| Extras | 3 je Level, einmalig | Extras sind Spaß-Ziele, kein Kreislauf. |
| Video | 2 je Spieltag | Videos bleiben unter 25 % des Einkommens eines Spielers, der sie jeden Tag schaut (9.2: 540 von 2493 = 22 %). |
| Freies Spiel + Challenge | 20 je Spieltag (zusammen) | Das freie Spiel ist offen und unbegrenzt spielbar, darf aber das tägliche Level nicht ersetzen. |
| Wiederholen | nur die Verbesserung | Das beste Ergebnis eines Levels ist höchstens ~95 wert. |
| Gekaufte Hilfe pro Level | 3 (Wunder + Tipps + Zurück zusammen), Wunder höchstens 1 je Art | Niemand kauft sich durch ein Level; die Sterne bleiben ehrlich. |
| Vorrat | Regen 3, Blitzschutz 2, Meteor 1, Tipp 5, Zurück 5, Serienschutz 2 | Kein Horten von Verbrauchsgütern; der Kauf-Knopf sagt „Vorrat voll“. |
| Geldbeutel | keine Grenze | Nichts verfällt (das wäre unfair). Gegen „alles gekauft“ helfen neue Dinge jeden Monat und das Sammelstück (5.4). |

Alle Grenzen stehen in `balance.gd` (10.1) und werden pro Spieltag in `[punkte] heute` gezählt (8.1). Die Uhr
verstellen bringt nichts: die Zähler hängen am Spieltag aus `Daily.observe`, wie die Serie.

---

## 5. Laden-Katalog und Preise

Preise in Punkten. „Tage“ = wie viele **gespielte** Spieltage ein Spieler dafür braucht (Median-Einkommen pro
gespieltem Spieltag aus 9.2: Profi 145, Normal 109, Gelegenheit 58).

### 5.1 Wunder (Reiter „Wunder“, Vorrat, benutzt im Dock)

| Wunder | Preis | Vorrat | Wirkung | ab | Tage (P / N / G) |
|---|---|---|---|---|---|
| Regen | 25 | 3 | wie eine Regen-Ladung des Levels (`GDPD_SCHOEPFUNG.md` 3.5: das Feld wächst nach der Regen-Tabelle, löscht Feuer, hebt die Blitz-Warnung auf) | Level 5 (erster Regen) | 0,2 / 0,2 / 0,4 |
| Blitzschutz | 40 | 2 | die nächsten 5 Runden schlägt kein Blitz ein (die Warnung wird zu „Geschützt“); andere Gefahren bleiben | Level 12 (erster Blitz) | 0,3 / 0,4 / 0,7 |
| Meteor | 60 | 1 | wie der Meteor (ein Feld wird Erde, Krater) ohne Glauben | Level 23 (Meteor) | 0,4 / 0,6 / 1,0 |

- In einem Level und in der Welt des Tages zählt jedes gekaufte Wunder **2 Schritte** (Pille „+2 Schritte“ beim
  Benutzen) und jede Art höchstens einmal. Im Weiterbauen und im freien Spiel zählt es nichts (dort gibt es keine
  Sterne). In der 100-Sekunden-Challenge gibt es keine gekauften Wunder (gleiche Bedingungen für den Rekord).
- Gekaufte Wunder liegen im Dock **hinter** den Ladungen des Levels: erst wird die Gratis-Ladung benutzt.
- Ist ein Werkzeug im Dock leer und hat man eines im Vorrat, zeigt das Dock den Vorrat (kleines Abzeichen „+2“).
  Hat man keins, zeigt das Dock **in der ★-Zone** (mehr als s2 Schritte) eine Preis-Pille „25 ✦“; Antippen öffnet die
  Kauf-Bestätigung (7.4). Vorher gibt es im Level keine Preis-Pille (sie würde meist einen Stern kosten, 9.4).
- Freies Spiel: die heutigen Münz-Preise für leere Werkzeuge (`RAIN_COST` 2, `BOLT_COST` 3, `MONSOON_COST` 5) werden
  25 / 40 / 60 Punkte. Strafen (Gewitter, Flut) kosten weiter Glauben, nicht Punkte. `CONTINUE_COST` (Weiterspielen
  nach dem Ende) entfällt: man kann nicht mehr verlieren.

### 5.2 Hilfe (Reiter „Hilfe“)

| Hilfe | Preis | Vorrat | gratis | Regel |
|---|---|---|---|---|
| Tipp | 10 | 5 | **immer in Level 1–5**; sonst **1 je Level**; der **Rettungs-Tipp** ist immer gratis | Rettungs-Tipp: sobald die Gnade greift (★-Zone, 3 Schritte ohne Fortschritt, `GDPD_SCHOEPFUNG.md` 3.5), leuchtet der Tipp-Knopf grün und jeder Tipp ist gratis. So bleibt niemand stecken. |
| Zurück | 10 | 5 | 1 je Level | nimmt die letzte Drehung zurück (auch Feuer und Verluste), der Schritt bleibt gezählt |
| Serienschutz | 100 | 2 | 1 alle 7 Serientage | wie heute (`Daily`): überbrückt verpasste Tage nur, wenn er die ganze Lücke schließt |

Im Level gilt: höchstens 3 gekaufte Hilfen zusammen (4.). Der Tipp-Knopf zeigt den Zustand: „1 frei“ → „10 ✦“ →
„Rettung“ (grün).

### 5.3 Gott (Reiter „Gott“)

Alles, was es heute im Ersteller gibt, bleibt **gratis**: 6 Grundformen (Bart, Göttin, Sonne, Wolke, Katze, Nudel),
alle Farben, 13 Zubehörteile in 3 Plätzen (Kopf, Gesicht, Hals). Neu kommen dazu (Daten-Zeilen + SVGs, wie
`Character.ACCESSORIES`; Spec `GDPD_TAEGLICH_CHARAKTER.md` 3.8):

| Stufe | Preis | Anzahl zum Start | Beispiele | Tage (P / N / G) |
|---|---|---|---|---|
| einfach | 100 | 4 | Stirnband, Federn, Sommersprossen, Ohrringe | 0,7 / 0,9 / 1,7 |
| schön | 250 | 6 | Lorbeerkranz, Sternenbrille, Wolkenschal, Mondsichel, Blüten im Haar, Halskette | 1,7 / 2,3 / 4,3 |
| besonders | 400 | 6 | Sternenkrone, Regenbogenschal, Funkenaugen, Blitz-Amulett, Sonnenhut, Muschelkette | 2,8 / 3,7 / 6,9 |
| prächtig | 600 | 4 | Sonnenstrahlen-Krone, Glutaugen, Nordlicht-Umhang, Kometenschweif | 4,1 / 5,5 / 10 |
| Skin (ganze Grundform) | 1500 / 2000 / 2500 / 3000 | 4 | Spaghettimonster mit Fleischbällchen-Krone (die Nudel als echtes Monster), Sternengöttin, Vulkan-Gott, Baumgeist | 10–21 / 14–28 / 26–52 |

- Gott-Teile dürfen nichts aus späteren Leveln zeigen (kein Blitz-Amulett vor Level 12, kein Meteor vor Level 23).
  Solche Teile haben `ab: "level:N"` und stehen erst danach im Laden.
- Geschenke: „Flammenkranz“ bei 30 Serientagen, „Sonnengott gold“ (Skin) bei 100. Sie stehen nie zum Verkauf.
- Ein Skin ändert nur das Aussehen und die Sprechblasen-Farbe, nie Regeln, Texte oder Hilfe.

### 5.4 Welten (Reiter „Welten“, später)

| Ding | Preis | ab | Wirkung |
|---|---|---|---|
| Würfel-Theme (Holz, Marmor, Gold-Rand) | 3000 | nach Level 30 | Rahmen und Fugen des Würfels, Hintergrund; Lesbarkeit der Felder bleibt (`GDPD_GRAFIK.md`) |
| Himmel-Theme (Polarlicht, Sternennebel) | 3000 | nach Level 30 | Himmel und Licht im Weiterbauen und im freien Spiel; nie in einem Level der Schöpfung (dort zeigt der Himmel das Zeitalter) |
| Goldener Würfel (Sammelstück) | 10 000 | nach Level 30 | ein goldener Rand und ein Titel unter dem Gott („Schöpfer“); für alle, die schon alles haben |
| neue Welten (Insel, Wüste, Winter) | **gratis** | später | neue Inhalte sind Spiel, kein Laden-Ding; der Reiter zeigt nur ihren Start. (Das ersetzt „Themes / neue Welten 1500“ aus `GDPD_SCHOEPFUNG.md` 6: Welten werden nie verkauft.) |

Vor dem Ende der Schöpfung zeigt der Reiter genau eine Kachel: ein Schloss und „Bald mehr“. Keine Namen, keine Bilder.

### 5.5 Videos (Platzhalter)

Unten im Laden, nur wenn `Balance.ADS_ON` (heute `false`): Knopf „▶ Video · +10 ✦“, darunter „2 heute“. Nie im
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
2. **Kein Level braucht einen Kauf.** Ein Level ist nicht zu verlieren; es gibt Gnade (gratis Regen in der ★-Zone),
   einen Gratis-Tipp je Level und den Rettungs-Tipp. Die Simulation prüft, dass jeder Bot jedes Level ohne Kauf
   beendet (9.1).
3. **Sterne sind nicht zu kaufen.** Gekaufte Wunder zählen 2 Schritte, höchstens 1 je Art und Level, höchstens 3
   gekaufte Hilfen pro Level; Sterne schalten nichts frei. Gemessen in 9.4: mit 2 Schritten bringt ein gekaufter
   Regen nur in 1–3 % der Fälle einen Stern mehr.
4. **Was gratis war, bleibt gratis.** Nichts aus dem heutigen Ersteller kommt hinter einen Preis. Neue Welten sind
   gratis.
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
| Menü, oberer Block | Zeile „Laden“ mit Münz-Icon und Punktestand | Laden, Reiter „Wunder“ |
| Übersicht, eigener Gott | Antippen öffnet den Gott (Wunsch: ansehen, ändern, Art zu reden); dort Knopf „Mehr Teile“ | Laden, Reiter „Gott“ |
| Serienschutz-Chip | Antippen | Laden, Reiter „Hilfe“, Serienschutz hervorgehoben (ersetzt die heutige Schutz-Karte) |
| Dock im Level | Preis-Pille an einem leeren Wunder (nur in der ★-Zone) | nur die Kauf-Bestätigung (7.4), kein ganzer Laden |
| Sieg-Karte | **kein** Eingang | – |

**Menü (Wunsch 8. November: übersichtlicher, Unwichtiges in ein Untermenü).** Der Laden gehört in den oberen Block:

```
┌──────────────────────────────┐
│  ▶ Weiter                    │   oberer Block: was man oft braucht
│  ◎ Übersicht                 │
│  ✦ Laden            312      │
│  ☺ Dein Gott                 │
│  ? Hilfe                     │
│ ──────────────────────────── │
│  ⚙ Einstellungen          ›  │   Untermenü: Ton, Erinnerungen, Uhrzeit, Grafik,
│                              │   Sprache des Gottes, Testversion „Nächster Tag“
└──────────────────────────────┘
```

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
│ │  25 ✦ x2 │ │  40 ✦    │        │  Preis-Chip; Vorrat „x2“
│ └──────────┘ └──────────┘        │
│ …                                │
│        ▶ Video · +10 ✦ (2 heute) │  nur mit ADS_ON
└──────────────────────────────────┘
```

- Reiter „Gott“: oben groß der eigene Gott (wie im Ersteller, 40 % der Höhe), darunter die Plätze als kleine
  Pillen (Kopf · Gesicht · Hals · Form), darunter die Teile. Antippen eines Teils **setzt es probehalber auf** (der Gott
  freut sich); der Knopf unten wird „Kaufen · 250 ✦“ oder „Anlegen“ (wenn schon gekauft) oder „Ablegen“.
- Zustände einer Karte: **Preis** (kaufbar), **grauer Preis** (zu wenig Punkte), **✔ Hast du** (gekauft), **Angelegt**
  (grüner Rand), **x2** (Vorrat), **Vorrat voll**, **Neu** (Punkt oben rechts, bis einmal angesehen).
- Leere Reiter gibt es nicht: „Welten“ zeigt vor dem Ende die Schloss-Kachel „Bald mehr“.

### 7.3 Nicht genug Punkte

Der Kauf-Knopf ist grau und sagt „Dir fehlen 120 ✦“. Darunter eine Zeile Icons, wie man Punkte bekommt:
★ Level · 🔨 Weiterbauen · 🔥 Serie. Kein Video-Angebot an dieser Stelle.

### 7.4 Kauf-Bestätigung (immer)

Ein Blatt von unten (wie die heutigen Modal-Karten, `ui._modal_card`):

```
   (Bild des Dings)
   Regen kaufen?
   ✦ 312 → 287
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
  größer“ gilt auch hier: die Chips stehen mittig, +15 % Höhe, `GDPD_SCHOEPFUNG.md` 12).
- Level: kein Punkte-Chip, nur `👣 7` und der Sterne-Ring. Erst die Sieg-Karte zeigt Punkte.
- Weiterbauen: der Chip „Extra: …“ wie heute; „+1 ✦“ fliegt beim Wachsen hoch, bis „20/20 heute“ (dann kommt eine
  Pille „Heute genug Punkte · Bau weiter“ und weiteres Wachsen zählt nur noch für Extras).

---

## 8. Speichern und Umstellung

### 8.1 Spielstand (`user://rekord.cfg`, Profil `save_path`, ConfigFile)

```
[konto]
punkte = 312                 ; int ≥ 0, die einzige Währung
version = 2                  ; 1 = Münzen (alt), 2 = Punkte
umgestellt = 0               ; > 0: Punkte aus der Umstellung, der Hinweis ist noch nicht gezeigt (dann 0)
; „credits“ wird bei der Umstellung gelöscht (cfg.erase_section_key)

[punkte]
level_best = [80, 65, 45, …] ; Array[int] (30), bestes bezahltes Ergebnis je Level der Schöpfung (0 = nie)
extras = [3, 1, 0, …]        ; Array[int] (30), bezahlte Extras je Level (höchstens 3)
wdt_best = {20401: 65, …}    ; Dictionary Spieltag → bestes Ergebnis der Welt des Tages (letzte 21)
heute = [20437, 6, 1, 20]    ; [Spieltag, Weiterbauen, Videos, freies Spiel/Challenge] – alte Spieltage = 0
summe = 4536                 ; alles je verdient (Statistik, Feier „1000 Punkte“)
verlauf = [[20437, "level", 65], [20437, "kauf:regen", -25], …]   ; die letzten 50 Buchungen (Hilfe bei Fehlern)

[laden]
besitz = ["stirnband", "lorbeer"]       ; gekaufte und geschenkte Gott-Teile, Skins, Themes (ids)
vorrat = {"regen": 2, "tipp": 1}        ; Verbrauchsgüter (Serienschutz bleibt in [taeglich] schutz)
gesehen = ["regen", "stirnband", …]     ; ids, deren „Neu“-Punkt schon weg ist
theme = ""                              ; angelegtes Theme ("" = Standard)
```

- Das ersetzt die Schlüssel `punkte`, `punkte_tag` und `gekauft` in `[kampagne]` aus `GDPD_SCHOEPFUNG.md` 13: die
  Kampagne speichert Fortschritt (Level, Sterne, Schritte, Welt), dieses Dokument die Währung.
- Angelegte Gott-Teile stehen weiter im Aussehen in `[charakter]` (`user://charakter.cfg`); der Laden prüft beim
  Laden des Aussehens, ob ein Teil in `besitz` ist (gratis-Teile immer), sonst wird es abgelegt.
- Der Level-Zähler für „gekaufte Hilfe ≤ 3“, „Wunder 1 je Art“ und „1 Tipp / 1 Zurück frei“ lebt nur im laufenden
  Versuch (`GameState`), wird also nicht gespeichert.
- Serienschutz: Anzahl weiter in `[taeglich] schutz` (Daily); der Kauf zieht Punkte ab und ruft `Daily.add_shield`.
- `bau_muenzen` in `[taeglich]` wird `heute[1]` in `[punkte]` (beim Umstellen gelesen, dann gelöscht).

### 8.2 Umstellung (einmal, beim Laden, `konto.version < 2`)

```
punkte = 20 × credits                 ; 1 Münze = 20 Punkte (Serienschutz 5 Münzen = 100 Punkte behält seinen Wert)
punkte = max(punkte, POINTS_START)    ; wer 0–2 Münzen hatte, bekommt mindestens 60
punkte += 20 × (Summe der alten Sterne der 7 Tage)     ; GDPD_SCHOEPFUNG.md 13.1, einmal
umgestellt = punkte
heute = [bau_muenzen[0], min(20, 10 × bau_muenzen[1]), 0, 0]
version = 2; credits löschen; bau_muenzen löschen
```

- Kein Doppel-Zählen: die Umstellung läuft nur bei `version < 2` und schreibt `version = 2` im selben Speichern.
- Hinweis in der Übersicht, einmal (Sprechblase des Charakters): „Deine Münzen sind jetzt Punkte.“ mit dem
  Münz-Icon und der Zahl. Danach `umgestellt = 0`.
- Punkte für die neuen Level gibt es nicht rückwirkend (`level_best` startet bei 0); die alten Sterne zählen nur über
  die einmalige Gutschrift oben.
- Neue Spieler: `punkte = 60`, `version = 2`.
- Wer mehr als ~40 Münzen hatte (sehr viele Videos), bekommt 800+ Punkte: das ist gewollt (nichts geht verloren) und
  reicht für ein paar Teile, nicht für den Katalog.

---

## 9. Simulation

### 9.1 Methode

- **Schritte pro Level** kommen aus dem Regelmodell der Kampagne (`gdpd_sim/b4`, `run9.py`, Lauf `q2.json` vom
  8. November: 30 Level × 60 erzeugte Bretter × Bots `good` = der Tipp, `greedy` = 1-Zug-Spieler, `weak` = halb
  zufällig; kein Schritt-Limit, Gnade an, Verbindungen bleiben). Beendet `weak` ein Level im Modell nicht (Level
  19–23: 43–83 % fertig), zählt es als mit Gnade und Rettungs-Tipp beendet: Schritte + 5, ★.
- **Sterne-Grenzen:** die neue Regel (2.2, `stars10.py` auf denselben Lauf); zum Vergleich die bisherigen aus
  `levels9.py`.
- **Kampagne:** ein neues Level pro gespieltem Spieltag; wer einen Tag auslässt, spielt am nächsten das wartende
  Level. Nach Level 30 jeden gespielten Tag eine Welt des Tages aus den 14 Vorlagen (`GDPD_SCHOEPFUNG.md` 8).
- **Serie** wie `Daily`: Serienschutz überbrückt nur ganze Lücken, 7er-Meilenstein gibt Schutz oder +50.
- **Spieler** (je 300 Läufe):

  | Spieler | Bot | spielt (nach Spieltag / nach Pause) | Wiederholen | Wachsen im Weiterbauen je Tag | Extras je Level (von 3) | freies Spiel | Videos | Hilfe kaufen |
  |---|---|---|---|---|---|---|---|---|
  | Profi | good | 100 % | 1× je Level | 40 (Grenze 20) | 2,5 | jeden 2. Tag | 0 | nie |
  | Normal | greedy | 92 % / 70 % | nie | 15 | 1,5 | jeden 5. Tag | 0 | Regen in 30 % der zähen Level |
  | Gelegenheit | weak | 75 % / 50 % | nie | 5 | 0,5 | nie | 0 | Regen in 50 % der zähen Level |
  | Video | weak | 92 % / 70 % | nie | 8 | 0,8 | nie | 2 je Tag | 50 % |
  | Farmer | good | 100 % | 5× je Level | 400 (Grenze 20) | 3 | jeden Tag | 2 je Tag | nie |

  „Zäh“ = mehr als `2 × s3` Schritte. Kaufen: Serienschutz, wenn man keinen hat (nicht Profi/Farmer); sonst sofort
  das billigste Gott-Teil, dann Skins, nach Level 30 Themes (eine Reserve von 100 für den Schutz bleibt).
- Skript: `/tmp/claude-0/-home-user-test-app/3861a76b-89b3-5028-950e-8c56bdad2d34/scratchpad/econ2/econ.py`
  (`python3 econ.py 300 30 new`; `old` = bisherige Grenzen; viertes Argument JSON mit Änderungen an `B`/`P`), die
  Messung der gekauften Wunder: `miracle.py 40 miracle.json` und `mir_an.py` im selben Ordner.

### 9.2 Ergebnis: 30 Tage (Mittelwerte aus 300 Läufen, neue Sterne-Grenzen)

| Spieler | Level | ★/Level | ★★+ | ★★★ | verdient | davon Level | Serie | Extras | Bauen | Meilensteine | freies Spiel | Video | Hilfe gekauft | Schutz gekauft | Teile (von 20) | Rest | 1. Teil (Tag) | je gespieltem Tag (Median) | erste Woche | Serie am Ende |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Profi | 30 | 2,55 | 98 % | 57 % | **4536** | 2361 | 280 | 753 | 600 | 250 | 293 | 0 | 0 | 0 | 16,0 | 296 | 1 | 145 | 1028 | 30 |
| Normal | 26,9 | 2,17 | 83 % | 35 % | **3020** | 1738 | 244 | 404 | 404 | 124 | 106 | 0 | 20 | 169 | 12,0 | 187 | 2 | 109 | 736 | 24,0 |
| Gelegenheit | 20,0 | 1,10 | 10 % | 0 % | **1213** | 838 | 149 | 99 | 100 | 27 | 0 | 0 | 121 | 264 | 5,4 | 131 | 5 | 58 | 336 | 9,5 |
| Video | 27,0 | 1,15 | 14 % | 1 % | **2493** | 1148 | 243 | 215 | 216 | 131 | 0 | 540 | 202 | 169 | 10,2 | 166 | 2 | 88 | 584 | 23,7 |
| Farmer | 30 | 2,55 | 98 % | 57 % | **5737** | 2507 | 280 | 900 | 600 | 250 | 600 | 600 | 0 | 0 | 18,0 | 297 | 1 | 184 | 1308 | 30 |

Erster Spieltag (mit Start 60): Profi 192, Normal 158, Gelegenheit 103 → jeder kann am ersten Tag ein erstes Teil
(100) kaufen; der Gelegenheits-Spieler legt in der Simulation zuerst 100 für den Serienschutz zurück und kauft sein
erstes Teil am 5. Spieltag.

### 9.3 Ergebnis: 60 Tage (Schöpfung fertig, danach Welt des Tages)

| Spieler | verdient | Teile (von 20) | Skins (von 4) | 1. Skin (Tag) | Rest | Serie am Ende |
|---|---|---|---|---|---|---|
| Profi | 9170 | 20 | 1,0 | 54 | 1030 | 60 |
| Normal | 6028 | 18,0 | 0 | – | 302 | 43,3 |
| Gelegenheit | 2547 | 9,2 | 0 | – | 148 | 10,6 |
| Video | 5218 | 15,9 | 0 | – | 265 | 42,0 |
| Farmer | 11 630 | 20 | 2,0 | 43 | 1490 | 60 |

Gegenproben (30 Tage, 300 Läufe):

| Probe | Ergebnis |
|---|---|
| bisherige statt neue Sterne-Grenzen | Normal ★★+ 69 % statt 83 %, verdient 2970 statt 3020; Profi 4494 statt 4536. Die neuen Grenzen machen ★★ häufiger, ohne das Einkommen aufzublähen (Par hängt an s3). |
| Weiterbauen **ohne** Tages-Grenze (Farmer mit dem besten Hin-und-her, ~60 Wachstümer am Tag) | 1800 statt 600 Punkte aus dem Bauen; ohne Videos läge der Farmer dann 40 % über dem Profi (mit Grenze 13 %) |
| Farmer ohne Videos (mit Grenzen) | 5137 (Profi 4536: +13 %; der Rest kommt aus täglich freiem Spiel, 5× Wiederholen und allen Extras) |
| alte Formel `20 × Sterne + 5 × max(0, s2 + 4 − Schritte)` (neue Grenzen) | Profi 95 je Level, Gelegenheit 28 (29 % statt 53 % des Profis); Level mit großzügiger ★★-Grenze zahlen über 100 für ein normales Spiel |

### 9.4 Gekaufte Wunder und Sterne

Messung: derselbe Bot auf demselben Brett, einmal ohne, einmal mit **einer zusätzlichen Ladung** von Anfang an (so
wirkt ein gekauftes Wunder), 40 Bretter je Level, alle Level mit Regen (5–30) bzw. Meteor (23–30); Sterne nach den
neuen Grenzen. „Kosten“ = wie viele Schritte das gekaufte Wunder zählt.

| Bot · Wunder | Spiele | gesparte Schritte (Mittel) | Kosten 0: Stern mehr / weniger | Kosten 1 | **Kosten 2** |
|---|---|---|---|---|---|
| good · Regen | 1200 | 0,36 | 15,9 % / 2,7 % | 3,9 % / 34,2 % | **1,1 % / 64,8 %** |
| greedy · Regen | 1200 | 0,36 | 21,5 % / 4,2 % | 8,5 % / 29,5 % | **3,2 % / 55,2 %** |
| good · Meteor | 320 | −0,03 | 1,6 % / 2,2 % | 0,6 % / 40,3 % | **0,0 % / 70,9 %** |
| greedy · Meteor | 320 | −0,38 | 3,8 % / 2,5 % | 2,2 % / 30,3 % | **1,2 % / 55,0 %** |

Was daraus folgt:
- **Ohne Schritt-Kosten wären Sterne käuflich** (jeder 5. gekaufte Regen bringt einen Stern mehr). Deshalb zählt ein
  gekauftes Wunder 2 Schritte: dann bringt es nur noch in 1–3 % der Fälle einen Stern mehr.
- **Mit 2 Schritten kostet ein Wunder vor der ★-Zone oft einen Stern.** Ein Wunder ist darum eine Hilfe für die, die
  feststecken, kein Trick für Sterne. Damit niemand sich aus Versehen einen Stern wegkauft, erscheint die
  **Preis-Pille im Dock erst in der ★-Zone** (mehr als s2 Schritte, dort kann kein Stern mehr verloren gehen); Wunder
  aus dem Vorrat kann man immer benutzen, die Bestätigung sagt „Zählt 2 Schritte“.
- Im Weiterbauen und im freien Spiel (keine Sterne) kostet ein Wunder keine Schritte; dort ist es ein reines
  Spielzeug.
- Der Meteor spart im Mittel nichts (er ist ein gezieltes Werkzeug: Rudel trennen, Krieg beenden); er bleibt teuer
  (60) und auf 1 im Vorrat begrenzt.

### 9.5 Was die Zahlen sagen

- **Das tägliche Level trägt die Wirtschaft** (52 % beim Profi, 69 % beim Gelegenheits-Spieler). Können zahlt sich
  aus (pro Level: Profi 79, Normal 65, Gelegenheit 42), aber ein schwacher Spieler bekommt pro Level immer noch gut
  die Hälfte vom Profi. Zuverlässiges Spielen zahlt sich auch aus (Serie + Meilensteine 12 % beim Profi).
- **2 Sterne sind jetzt die Regel:** der normale Spieler holt in 83 % der Level ★★ oder mehr (bisher 69 %), der
  Profi in 98 %. ★★★ bleibt etwas Besonderes (Profi 57 %, Normal 35 %). Die Grenzen ändern das Einkommen kaum
  (Normal +2 %): Sterne sind ein Gefühl von Können, keine Geldquelle.
- **Farmen lohnt sich nicht:** mit Tages-Grenzen holt ein Bot, der 400 Mal am Tag dreht, jeden Tag frei spielt und
  jedes Level 5-mal wiederholt, ohne Videos nur 13 % mehr als ein Profi.
- **Videos sind ein Zubrot, kein Muss:** 22 % beim täglichen Video-Schauer; wer nie schaut, verpasst kein Teil, das
  nicht nach ein paar Tagen Spielen ohnehin kommt.
- **Preise passen:** ein Regen kostet weniger als die Hälfte des Tageseinkommens eines Gelegenheits-Spielers (25 von
  58); Serienschutz ≈ ein Spieltag; ein Teil 1–10 Spieltage; ein Skin 2–7 Wochen. In 30 Tagen hat der Profi 16 der 20
  Teile, Normal 12, Gelegenheit 5 – jeder hat etwas, keiner alles; den ersten Skin gibt es nach etwa 8 Wochen.
- **Inflation nach der Schöpfung:** der Profi verdient in der Welt des Tages weiter ~4400 im Monat. Damit Punkte
  etwas wert bleiben, kommen **jeden Monat neue Dinge für etwa 4000 Punkte** (4 Teile ≈ 1300, ein Skin oder ein
  Theme ≈ 2500), und es gibt das Sammelstück (10 000). Für Normal- und Gelegenheits-Spieler reicht der Start-Katalog
  Monate.
- **Gelegenheits-Spieler** gibt 32 % für Hilfe und Schutz aus. Das ist gewollt (Hilfe ist für sie da), aber kein
  Muss: ohne Käufe bleibt jedes Level lösbar (Gnade, Rettungs-Tipp). Wird der Wert im Feldtest höher, zuerst Regen
  auf 20 senken.

---

## 10. Umsetzung

### 10.1 `scripts/balance.gd` (neu bzw. umbenannt)

```gdscript
# --- Punkte und Laden (docs/GDPD_PUNKTE_LADEN.md) -------------------------------------------------
static var POINTS_START := 60            # ersetzt CREDITS_START (3)
static var POINTS_PER_COIN := 20         # Umstellung Münzen → Punkte
static var POINTS_PER_OLD_STAR := 20     # Umstellung: alte Sterne der 7 Tage
static var LEVEL_DONE := 30              # Level: 30 + 10 × Sterne + 5 × max(0, Par − Schritte)
static var LEVEL_PER_STAR := 10
static var LEVEL_FAST := 5
static var PAR_PLUS := 4                 # Par = ★★★-Grenze + 4
static var STREAK_BONUS_STEP := 2        # erster Sieg des Spieltags: +2 × Serie …
static var STREAK_BONUS_MAX := 10        # … höchstens +10
static var MILESTONE_POINTS := 50        # ersetzt SHIELD_FULL_COINS (3)
static var MILESTONE_BIG := {14: 50, 30: 100, 50: 150, 100: 300, 365: 500}
static var MILESTONE_GIFT := {30: "flammenkranz", 100: "sonnengott_gold"}
static var EXTRA_POINTS := 10
static var EXTRA_MAX := 3                # je Level, einmalig
static var BUILD_POINTS_MAX := 20        # ersetzt BUILD_COIN_EVERY / BUILD_COIN_MAX
static var FREE_PLAY_POINTS := 20        # freies Spiel oder Challenge, einmal je Spieltag
static var ADS_ON := false
static var AD_POINTS := 10               # ersetzt CREDITS_PER_AD
static var AD_MAX := 2
static var ADS_FROM_DAY := 4             # kein Video-Knopf in den ersten 3 Spieltagen
static var SHIELD_PRICE := 100           # war 5 Münzen
static var HINT_COST := 10               # war 1 Münze
static var UNDO_COST := 10
static var HINT_FREE_LEVELS := 5         # Level 1–5: Tipp immer gratis
static var HINT_FREE := 1                # sonst je Level
static var UNDO_FREE := 1
static var MIRACLE_STEPS := 2            # gekauftes Wunder zählt so viele Schritte
static var MIRACLE_PER_KIND := 1         # je Art und Level
static var HELP_MAX := 3                 # gekaufte Hilfen je Level
static var RAIN_COST := 25               # freies Spiel: leeres Werkzeug kaufen (war 2 / 3 / 5 Münzen)
static var BOLT_COST := 40
static var MONSOON_COST := 60
# CONTINUE_COST entfällt (man kann nicht mehr verlieren)
```

Die Katalog-Preise stehen nicht in `balance.gd`, sondern in `data/laden.json` (5.).

### 10.2 Dateien

| Datei | Änderung |
|---|---|
| `data/laden.json` (neu) | Katalog: `{"id", "tab": "wunder"\|"hilfe"\|"gott"\|"welten", "art": "wunder"\|"hilfe"\|"teil"\|"skin"\|"theme"\|"sammel", "preis", "vorrat" (max, 0 = einmalig), "ab": "" \| "level:N" \| "fertig" \| "geschenk", "platz" (kopf/gesicht/hals/basis), "icon", "titel"}`. Ein Test prüft: ids eindeutig, Preise > 0 außer Geschenken, Titel ≤ 2 Wörter. |
| `scripts/points.gd` (neu, `class_name Points`, statisch wie `Daily`) | `level_points(stars, steps, s3) -> int`, `pay_level(d, level, pts) -> int` (Verbesserung), `pay_extra(d, level) -> int`, `pay_wdt`, `build_point(d, today) -> int` (0/1, Grenze), `ad_ok`, `free_play_ok`, `streak_bonus(streak)`, `milestone(streak, shields_full) -> {points, gift}`, `migrate(cfg) -> int`, `save(cfg, d)`, `load(cfg) -> d`. Keine Knoten. |
| `scripts/shop.gd` (neu, `class_name Shop`, statisch) | `catalog()`, `visible(item, progress) -> bool` (Spoiler-Regel), `buy_error(item, points, owned, stock) -> String` ("" = geht), `buy(...)`, `refund(...)` (nur Gott-Teile in derselben Laden-Sitzung), `owned(id)`, `stock(id)`, `use(id)`. |
| `scripts/game.gd` | `credits` → `points` (mit `credits` als Alias-Getter für alten Code bis zum Umbau), `spend(cost)` bleibt, `_save_profile` / `_load_best` schreiben `[konto] punkte`, `[punkte]`, `[laden]`, Umstellung in `_load_best`; Sieg (Level, Welt des Tages) bucht über `Points`; `_build_coins` → `_build_point`; `buy_shield()` mit neuem Preis; `reward_ad()` mit Grenze; Signal `points_changed(delta, source)`. |
| `scripts/game_state.gd` | Schritt-Zähler `steps` (Drehungen + 2 je gekauftem Wunder), `help_bought`, `miracle_bought` (je Art), `hint_free_left`, `undo_free_left`, `rescue()` (Gnade aktiv); kein Drehungs-Limit (gehört zum Kampagnen-Umbau). |
| `scripts/daily.gd` | `win()` gibt `points` statt `coins` (Meilenstein), `build_coins` entfällt (Grenze in `Points`), `shield_buy_error` mit Punkten. |
| `scripts/day_ui.gd` | Münz-Chip → Punkte-Chip (Antippen öffnet den Laden), Schutz-Karte → Laden „Hilfe“, Sieg-Karte mit Punkte-Zeilen (2.4), Gott in der Übersicht antippbar. |
| `scripts/shop_ui.gd` (neu) | der Laden (7.2–7.4), gebaut aus `ui._modal_card`, `ui._tile`, `ui._button`; Gott-Vorschau mit `CharacterView`. Überlagerungen, die nicht blockieren, mit `MOUSE_FILTER_IGNORE`. |
| `scripts/ui.gd` | Menü neu (oberer Block mit „Laden“, Untermenü „Einstellungen“, 7.1), Dock-Preis-Pille, Tipp-Knopf-Zustände („1 frei“, „10 ✦“, „Rettung“), Pille „+2 Schritte“. |
| `scripts/character.gd`, `character_creator.gd` | Laden-Teile in `ACCESSORIES` mit `"preis"`; der Ersteller zeigt gekaufte Teile, nicht gekaufte mit Schloss und „Im Laden“. Bestehende Teile ohne Preis = gratis. |
| `icons/points.svg` (neu) | goldene Münze mit ✦ (klar anders als ★) |

### 10.3 Abgleich mit `GDPD_SCHOEPFUNG.md`

| Stelle dort | wird zu |
|---|---|
| 0 Nr. 3 und 3.9: `20 × stars + 5 × max(0, par − steps)`, `par = s2 + 4` | `30 + 10 × Sterne + 5 × max(0, Par − Schritte)`, `Par = s3 + 4` (2.1); Spalte `par` der Level-Tabelle = s3 + 4 |
| 4.2 Sterne-Grenzen | nach der Regel 2.2 (`stars10.py`) |
| 0 Nr. 9 und 6: Preise (Schutz 100, Regen 25, Meteor 50, Tipp 10, Zurück 5, Teile 150–300, Skins 500, Themes/Welten 1500), Wunder „no step“ | Katalog 5. (Schutz 100, Regen 25, Blitzschutz 40, Meteor 60, Tipp 10, Zurück 10, Teile 100–600, Skins 1500–3000, Themes 3000; neue Welten gratis); gekaufte Wunder zählen 2 Schritte, 1 je Art und Level |
| 6: Weiterbauen-Grenze 30, Meilenstein +50 | Grenze 20 (4.), Meilenstein +50 (gleich) |
| 13: `[kampagne] punkte`, `punkte_tag`, `gekauft` | `[konto] punkte`, `[punkte] heute`, `[laden] besitz` (8.1) |
| 13.1: `credits × 20`, alte Sterne × 20 | gleich, dazu mindestens 60 (8.2) |
| 14 Nr. 10 Test „points“ | Tests 11.1 Nr. 1–2 |

---

## 11. Tests und Tour-Prüfungen

### 11.1 `tests/test_rules.gd` (müssen mit „ 0 Fehler“ enden)

1. **level_points:** Tabelle 2.1 (4/6 und 5/9) genau; nie unter 40 bei einem Sieg; `Par = s3 + 4`.
2. **improvement:** 45, dann 65 → +20; dann 60 → +0; Welt des Tages getrennt je Spieltag; Extras je Level höchstens 3
   und nur einmal.
3. **streak_bonus / milestones:** Serie 1…6 → +2, +4, …, +10, +10; Tag 7 mit 2 Schutz → +50; Tag 14 → +50 zusätzlich;
   Tag 30 → +100 und Geschenk „flammenkranz“ in `besitz`.
4. **build_cap:** 25 Wachstümer an einem Spieltag → 20 Punkte; ein Feld, das nach einer Gefahr wieder satt wird, → 0;
   am nächsten Spieltag wieder ab 0; Uhr zurück und vor gibt keine neuen 20.
5. **ad_cap:** `reward_ad` 3× → +20; vor Spieltag 4 und mit `ADS_ON = false` → 0.
6. **migration:** `credits = 7`, `version` fehlt → 140 Punkte, `credits` weg, `version = 2`; zweites Laden ändert
   nichts; `credits = 1` → 60; alte Sterne 7 → +140; `bau_muenzen = [k, 2]` → `heute[1] = 20`.
7. **shop_buy:** zu wenig Punkte → „Dir fehlen %d ✦“; Vorrat voll → Fehler; Kauf zieht genau den Preis ab; Gott-Teil
   zurückgeben in derselben Sitzung → volle Erstattung, danach nicht mehr; Verbrauchsgut nie.
8. **spoiler:** vor Level 5 ist „regen“ nicht `visible`; Blitzschutz erst ab Level 12; Meteor erst ab Level 23;
   „Welten“ vor Level 30 nur die Schloss-Kachel.
9. **miracle_steps:** ein gekauftes Wunder im Level → `steps + 2`; ein zweiter gekaufter Regen im selben Level geht
   nicht; im Weiterbauen → `+0`; dritte gekaufte Hilfe geht, vierte nicht (`HELP_MAX`); die Dock-Preis-Pille ist erst
   bei `steps > s2` sichtbar.
10. **rescue:** sobald die Gnade greift, kostet der Tipp nichts, auch ohne Punkte; in Level 1–5 immer gratis.
11. **free_items:** alle heutigen Grundformen und Zubehörteile haben keinen Preis.
12. **texts:** alle neuen Laden-Texte ≤ 6 Wörter (die bestehende ≤ 8-Wörter-Prüfung deckt sie mit ab).

### 11.2 Tour (`main.gd`, Namen in die Liste in `.github/workflows/gdpd.yml`, wenn es sie gibt)

| CHECK | Was |
|---|---|
| `points_win` | Level gewinnen: die Sieg-Karte zeigt die Zeilen 2.4, der Chip zählt hoch; Bild `points_win.jpg` |
| `shop_open` | Punkte-Chip antippen → Laden mit 4 Reitern; Bild `shop_wunder.jpg` |
| `shop_god` | Reiter „Gott“: Teil antippen → der Gott trägt es probehalber; kaufen; „✔ Hast du“; Bild `shop_god.jpg` |
| `shop_poor` | mit 0 Punkten: grauer Knopf „Dir fehlen …“, kein Video-Knopf; Bild `shop_poor.jpg` |
| `shop_dock` | im Level leeres Wunder: vor der ★-Zone keine Preis-Pille; in der ★-Zone Preis-Pille → Bestätigung mit „Zählt 2 Schritte“ → Schritte +2 |
| `menu_shop` | Menü: „Laden“ im oberen Block, Einstellungen als Untermenü; Bild `menu.jpg` |
| `points_migrate` | Profil mit `credits = 7` laden → 140 Punkte, Hinweis einmal |

---

## 12. Texte (alle neu oder geändert, ≤ 6 Wörter)

| Schlüssel | Text |
|---|---|
| `points` | Punkte |
| `points_explain` (Chip halten) | Deine Punkte. Für den Laden. |
| `shop` | Laden |
| `shop_first` (Charakter, einmal) | Dein Laden. Nur Schönes. |
| `tab_wunder` / `tab_hilfe` / `tab_gott` / `tab_welten` | Wunder / Hilfe / Gott / Welten |
| `menu_settings` | Einstellungen |
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
| `ad_button` | Video · +10 ✦ |
| `ad_left` | %d heute |
| `migrated` | Deine Münzen sind jetzt Punkte. |
| `shield_buy` | Kaufen · %d ✦ |
| `shield_missing` | Dir fehlen %d ✦ |
| `bought_part` / `bought_shield` / `bought_miracle` (lieb) | Steht dir! / Gut für schlechte Tage. / Regen bereit. |
| frech | Schick, schick! / Sicher ist sicher. / Na dann, Regen! |
| streng | Passt. / Vernünftig. / Bereit. |
| `streak_7_full` (geändert) | Eine Woche! Hier, 50 Punkte. · 7 Tage! 50 Punkte für dich. · Sieben Tage. 50 Punkte. |

---

## 13. Offene Fragen (für Philipp)

1. **Wunder im Level:** sollen gekaufte Wunder in Leveln der Schöpfung überhaupt erlaubt sein (mit +2 Schritten, wie
   hier), oder nur im Weiterbauen und im freien Spiel? Vorschlag: erlaubt, weil sie Spielern helfen, die feststecken,
   und die Sterne ehrlich bleiben (9.4).
2. **Name der Währung:** „Punkte“ (wie gewünscht) – oder „Lichter“ / „Sternenstaub“, passend zur Schöpfung? Der
   Text oben nimmt „Punkte“ und das Symbol ✦.
3. **Premium:** Einmal-Kauf ja/nein und Preis; Videos ganz weglassen, wenn es Premium gibt?
4. **Rangliste der Challenge:** bekommt der Wochen-Beste etwas (z. B. ein Abzeichen, keine Punkte)?
5. **Ersteller:** sollen die neuen Laden-Teile im Ersteller sichtbar sein (mit Schloss) oder nur im Laden?
   Vorschlag: sichtbar mit Schloss, ohne Preis-Druck, Antippen öffnet den Laden beim Teil.
