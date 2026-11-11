# gdpd – das Gottspiel auf dem Würfel (Arbeitstitel)

**gdpd** ist der Ableger von „God does play dice!“. Das Original bleibt unverändert in
[`../god_does_play_dice`](../god_does_play_dice) und wird dort weiter gebaut.

Godot 4.3, GDScript, Renderer „Compatibility“. Hochformat, Handy zuerst; PC-Versionen für Windows und Linux.

## Die Schöpfung in 7 Tagen

So beginnt das Spiel: Jeder Tag ist ein Level mit **einer** Aufgabe (oben immer zu sehen, z. B. „Hütten satt 1/3“
mit den Symbolen dessen, was verbunden werden muss), begrenzten Drehungen und 1–3 Sternen (weniger Drehungen = mehr
Sterne). Jeden Tag kommt genau **eine** neue Sache dazu. Leitsatz: *Zuerst schützt du die Menschen vor der Natur,
später die Natur vor den Menschen.*

Zwei Arten zu wachsen:
- **Erschaffen:** Natur wächst durch „Bring 3 gleiche in eine Reihe“ (Erde → Wiese → Wald → Tiere; 3 Tiere → Hütte).
  Jede Reihe wächst nur einmal: eine Scheibe hin und her bringt nichts.
- **Gedeihen:** Menschen (Hütte → Dorf → Stadt) wachsen durch ihre **Nachbarn**. Über jedem Menschen-Feld stehen die
  Bedürfnisse (🍞 Nahrung: Tiere, Acker · 🔨 Arbeit: Wald, Stein, Industrie · 🙏 Glaube: Kirche); was fehlt, ist rot.
  Satt 2 Runden → wächst, 4 Runden Hunger → schrumpft. Beim Drehen zeigt die Vorschau, wer satt wird (grün) und wer
  die Versorgung verliert (rot), und der Ziel-Chip zeigt „1→2/3“.

| Tag | Titel | Aufgabe (Drehungen) | Neu |
|---|---|---|---|
| 1 | Land | Lass 8 Wiesen wachsen (15) | Drehen: 3 gleiche in eine Reihe (Vorführung mit Hand) |
| 2 | Pflanzen | Lass 5 Wälder wachsen (14) | Regen |
| 3 | Tiere | Erschaffe 4 Tiere (10) | Blitz und Feuer (die Natur ist die Gefahr), Regen löscht |
| 4 | Menschen | Versorge 3 Hütten (14) | 3 Tiere → Hütte, Nahrung von den Nachbarn |
| 5 | Arbeit | Mach 3 Dörfer satt (13) | Arbeit (Wald, Stein), Regen neben Hütten macht Acker |
| 6 | Glaube | Mach 3 Städte satt (12) | Kirche; Kirche an Kirche = Krieg, der sich ausbreitet; Meteor (selten, mit Glauben) |
| 7 | Gleichgewicht | Mach 3 Städte satt (11) | Fabriken: Smog tötet Natur daneben, zu viel Stadt auf einer Seite → Flut |

Höchstens 3 Arten wachsen an einem Tag, und am Morgen liegen höchstens 1/2/2/3/5/6/6 verschiedene Arten (ohne Wasser)
auf dem Brett. Schafft man einen Tag nicht, gibt es „Nochmal“ – ohne Strafe, mit einem neuen Brett und +2 Drehungen.
Nach dem Sieg kann man weiterbauen („Extra: 4 Hütten satt“). Nach Tag 7: „Deine Welt ist vollendet!“ – dann ist das
**freie Spiel** offen (Einfach, Mittel, Schwer, 100 Sekunden). Weitere Pakete (Insel, Wüste, Winter) kommen als
Daten dazu. Regeln, Tabellen und Prüfungen: [`docs/GDPD_BALANCE_2.md`](docs/GDPD_BALANCE_2.md) (gilt vor der
älteren Spec [`docs/GDPD_7_TAGE.md`](docs/GDPD_7_TAGE.md)); Grafik: [`docs/GDPD_GRAFIK.md`](docs/GDPD_GRAFIK.md).

## Erdgeschichte (Kampagne)

60 Level in 20 Zeitaltern der Erdgeschichte (Urerde, Urozean, Erstes Leben, Kambrium, Zeit der Fische, Grün an Land,
Urwald, Landgang, Saurierzeit, Der Einschlag, Säugetiere, Eiszeit, Affen, Feuer, Jäger und Sammler, Ackerbau, Glaube,
Große Städte, Industrie, Gleichgewicht), ein neues Level je Spieltag, offen erweiterbar (Zeitalter und Level sind Daten).
Ohne Bibel-Rahmen (Entscheidung vom 10. November 2026). Spec: [`docs/GDPD_ERDGESCHICHTE.md`](docs/GDPD_ERDGESCHICHTE.md),
Grafik: [`docs/GDPD_ERDGESCHICHTE_GRAFIK.md`](docs/GDPD_ERDGESCHICHTE_GRAFIK.md), Punkte und Laden:
`docs/GDPD_PUNKTE_LADEN.md`. Die 30 Level der früheren Kampagne „Die Schöpfung“ leben darin weiter (ein alter
Spielstand wird umgestellt: Sterne wandern mit, übersprungene neue Level sind zum Nachholen offen).

- Regeln: `scripts/game_state.gd` (`setup_level`, Kampagnen-Abschnitt): Erschaffen (Reihen, `once`), Gedeihen
  (Bedürfnisse aus den Nachbarn; einmal versorgt bleibt versorgt), Zusammenwachsen (Gruppen geben Stärke bis 3),
  Gefahren nur als Folge und immer eine Runde vorher gewarnt (Vulkan, Blitz, Jagd, Gletscher, Smog, Flut, Krieg; der
  Einschlag ist erzählt und vom Start an angekündigt), kein Schritt-Limit; 40 Arten (`scripts/field_data.gd`).
- Daten: `data/kampagne_erde.json` (Zeitalter, Level-Regeln, Texte, Looks, alte → neue Level, 20 geprüfte
  Start-Bretter je Level mit Lösung), gelesen von `scripts/campaign.gd` (auch: Welt läuft im Zeitalter weiter, Welt des
  Tages, Zeitalter-Look).
- Fortschritt und Punkte: `scripts/game.gd` (`start_level`, `[kampagne]` Version 2 mit der Umstellung), `scripts/daily.gd`
  (ein neues Level je Spieltag, Nachholen, Schnellstart), `scripts/points.gd` (Punkte-Formel, Tages-Grenzen).
- Abgleich mit dem Python-Modell (`engine10`): `godot --headless --script res://tests/xcheck9.gd` (in `test_rules.gd`
  mit 260 Fällen; alle 2000 Fälle: `-- --cases=<xcheck10_all.json>`); nur die Kampagnen-Tests:
  `godot --headless --script res://tests/test_rules.gd -- --camp`.
- Oberfläche (`Balance.CAMPAIGN_ON = true`, das Spiel startet in der Erdgeschichte): Übersicht mit den erreichten
  Zeitaltern (Name, Symbol, Level mit Sternen; nachzuholende Level mit blauem Punkt) und genau einer „?“-Kachel für das
  nächste – nie ein Name, eine Zeile oder ein Level-Titel, die noch nicht offen sind; Heute-Karte (neues Level,
  „Nachholen · Level 7“ nach einem alten Spielstand, Welt des Tages), Serie und Woche; Antippen des eigenen Gottes
  öffnet ihn. Start-Karte „Saurierzeit · Level 28“ mit Geschichte und Aufgabe („Ohne Limit. Schritte zählen.“),
  Ziel-Chip mit bis zu zwei Teilzielen, Schritte-Ring mit der nächsten Sterne-Grenze („★★★ bis 4“), oben immer die
  nächste Handlung, Verlust-Plakette „−1 Fels“ fliegt zum Chip, Pillen für die Gefahren (immer eine Runde vorher:
  Vulkan, Blitz, Jagd mit ihren Jägern, Gletscher, „Meteor kommt!“ am Start des Einschlags), Zeitalter-Übergang
  (Himmel/Wasser wechseln, kurz „Neues Zeitalter · Kambrium · Das Meer wimmelt.“), das Neue (eigene Symbole der 13
  neuen Arten) fliegt an seinen Platz, kurze Sätze vom eigenen Gott; nach der Umstellung sagt er einmal „Die Welt ist
  größer geworden.“. Erinnerungen nennen nur die Nummer des nächsten Levels. Sieg-Karte mit Sternen und Punkte-Zeilen.
  `scripts/day_ui.gd` (Kampagnen-Zweige `_fill_acts`, `_fill_goal_card9`, `_refresh_hud9`, `_pill9`).
- **Laden** (`scripts/shop_ui.gd`, `Game.shop_items/buy/refund/use_stock`): Wunder (Regen, Blitzschutz, Meteor – erst
  wenn sie im Spiel vorkamen), Hilfe (Tipp, Zurück, Serienschutz), Gott (6 neue Teile zum Anprobieren und Zurückgeben),
  Welten („Bald mehr“). Kauf immer mit Bestätigung (✦ vorher → nachher); ein gekauftes Wunder zählt 2 Schritte.
  Im Level: Tipp gratis in Level 1–5, einmal je Level und als Rettung, sonst aus dem Vorrat; Zurück einmal frei.
- **Menü**: Weiter · Erdgeschichte · Freies Spiel · Laden · Dein Gott; alles andere unter „Einstellungen“ (Ton,
  Erinnerung, Wahl-Karte, Hilfe, Tutorial, Test-Knöpfe). Die Art zu reden stellt man nur im Gott ein
  (Menü → Dein Gott → Name & Art).
- **Freies Spiel** (nach der Erdgeschichte): Einfach, Mittel, Schwer und die **100-Sekunden-Challenge** (ersetzt
  „40 Drehungen“): Uhr ab der ersten Drehung, Feuer −5 s (keine Herzen), die große Wahl-Karte hält die Uhr an, kein
  Tipp/Zurück, Rekord je Modus; „Neues Spiel“ auf der Ergebnis-Karte startet wieder die Challenge.
- **Versorgt bleibt versorgt:** Ein Bedürfnis, das einmal gedeckt war, bleibt gedeckt (goldenes Häkchen) – auch wenn
  ein Regen oder ein Meteor es gedeckt hat; nur Gefahren (Feuer, Flut, Krieg, Meteor) nehmen es wieder. Wächst eine
  Reihe aus einer Ziel-Art, wächst lieber ein Feld, das noch nicht satt ist (Weiterentwickeln ist kein Verlust).
- **Sterne großzügig** (`gdpd_sim/b4/stars11.py`, Tabelle je Level in `docs/GDPD_SCHOEPFUNG.md` 9.2): ein normaler
  Spieler (greedy-Bot) schafft meist ★★, ein schwacher oft ★–★★ (Level 1–5 etwa die Hälfte ★★), ★★★ braucht gutes Spiel.
- **Welt von gestern:** Nur das neueste geschaffte Level (die Welt beim Sieg) gibt die Welt an das nächste Level
  weiter – nie eine Wiederholung eines früheren Levels und nie die Welt des Tages.
- **Welt des Tages:** nur aus Vorlagen schon geschaffter Level (auch für Veteranen der alten 7 Tage: nie ein Spoiler);
  Extras dort zählen nicht für das Vorlage-Level.
- **Jedes Level bleibt lösbar** (`docs/GDPD_SCHOEPFUNG.md` 5.1): Vor dem Start prüft `GameState.reach9` ohne Suche,
  ob das Ziel von diesem Brett aus erreichbar ist (genug Material, nach Sticker-Arten); eine eigene Welt bekommt sonst
  Nachschub über Nacht („Über Nacht: +3 Lava“) oder das Pool-Brett, Lava-Klumpen über 6 werden geteilt. Im Level merkt
  der Charakter eine Sackgasse nach der Drehung, die sie verursacht hat, oder 6 Schritte ohne Fortschritt, und bietet
  ein **Geschenk** (+1 und Nachschub, gratis) oder eine **Neue Welt** (das geprüfte Pool-Brett) an – auch in der Welt des
  Tages. Level 3 ist jetzt „Mach 14 Felsen“.
- **Tipp-Suche:** begrenzt (höchstens 150 Simulationen, auf späten Leveln etwa 0,3 s am PC); festgefahren schaut sie
  gestreut voraus und wiederholt keine Stellung der letzten Runden.
- **Build 12 – immer wissen, was zu tun ist:** Oben steht unter dem Ziel („Erde 6/11“) die nächste Handlung aus dem
  echten Brett („Dreh 3 Felsen in eine Reihe → Erde“, „Teil die Lava!“), nach jeder Aktion neu, nie unmöglich; keine
  Symbole mehr auf den Feldern. Die Feld-Karte zeigt die Regel der Schöpfung (3 × Fels → Erde, nicht „Fels → Fels“).
  Beim Neigen des Handys ist oben/unten umgekehrt; Ziehen mit dem Finger ist normal. Kein Weiterbauen (Knopf, Code und Signal weg). **Speichern mitten im Level**
  (`user://rekord_lauf.cfg`): App zu → genau dort weiter, auch die Welt des Tages aus der Übersicht; ein gekauftes
  Wunder (Regen, Meteor) wird erst mit dem Ende seiner Runde abgebucht, zusammen mit dem Lauf.
- **Build 13 – Review der Erdgeschichte:** Die Zeile oben nennt immer eine konkrete Drehung oder ein Werkzeug (auch in
  Level 55 „Frieden“ mit zwei satt-Zielen; im seltenen Rest „Dreh: Dorf wird Stadt“ mit leuchtender Scheibe; Test
  `next_action_concrete`, Tour `next_action_line`). Bringt die Fortschritts-Drehung zugleich Rettung, sagt die zweite
  Zeile „Rettet auch den Wald“ statt eines Rezepts; das Rezept steht nie doppelt. „Pflanzen“ statt „Futter“ als
  Bedürfnis. Level 60 heißt „Blühende Welt“ („Halte 3 Runden das Gleichgewicht“, kein Mond, keine „Ruhe“). Neue
  Geschichten ohne Wiederholung, Level 51 „Neu: Ernte“, Level 38 „Neu: Dein Meteor“. Größere Saurier, Affen,
  Frühmenschen und Feuerstellen (Tour `creature_size`), heller Rauch des fernen Vulkans links vom Würfel, Fels im
  Kambrium grau, Himmel bis zu den Algen im Dunst. Start-Karte schon im Zeitalter-Look (`era_look_on_card`), Zeile
  oben mittig, Pille rückt unter die Blase, „−1“ fliegt unter der Zeile durch, nach dem Einschlag sofort die neue
  Zeile. Heute-Karte: „Nochmal · mehr Sterne“ wieder sichtbar (und nur für ein offenes Level); nach der Umstellung
  ohne Nachholen öffnet das nächste Level am selben Tag. Leistung ist jetzt ein echtes CI-Tor (`perf` mit Budget).
  Behoben: Absturz beim Wechsel in ein anderes Level, während die Hand in Level 1 noch vorführt; die Kopfzeile wächst
  bei breitem Ziel-Chip nach beiden Seiten (bleibt mittig).

## Täglich spielen und dein eigener Charakter

Wie bei Duolingo: **ein neuer Tag pro echtem Tag** (der Spieltag wechselt um 3 Uhr). Ist das heutige Level
geschafft, ist das nächste bis morgen gesperrt („Morgen geht's weiter: Tag 3 · Tiere“, mit Countdown) – im
geschafften Level kann man ohne Drehungs-Grenze **weiterbauen** (Sterne verbessern, Glauben und Münzen sammeln).
Nach Tag 7 gibt es jeden Tag eine **Welt des Tages**; das freie Spiel ist jederzeit offen.
**Serie** mit Flamme und Feier, **Serienschutz** (alle 7 Tage einer, oder für Münzen), Wochenkalender.
Die Uhr verstellen bringt nichts: zurück und wieder richtig öffnet kein Level und kostet keinen Schutz.

Vor Tag 1 erstellt man in unter einer Minute seinen **eigenen Gott** (Grundform, Farben, Gesicht, Schmuck, Name,
Ton lieb/frech/streng). Er ist der Begleiter: alle Hinweise kommen als Sprechblase von ihm, kurz („Bring 3 gleiche
in eine Reihe.“). Er schickt auch die **Erinnerungen** am Handy (Android-Plugin): höchstens eine am Tag, etwa zur
Uhrzeit des letzten Spiels, nur wenn heute noch nicht gespielt, nie nachts (8:00–21:30, auch ein später Wecker wird
verworfen), seltener wenn man nicht kommt, nach einer Woche eine freundliche letzte Nachricht. Einstellbar oder aus.
In der Test-Version gibt es „Nächster Tag (Test)“ und „Erinnerung in 10 s“.
Spec: [`docs/GDPD_TAEGLICH_CHARAKTER.md`](docs/GDPD_TAEGLICH_CHARAKTER.md).

## Die Idee (freies Spiel)

Die Welt ist ein Zauberwürfel und du bist ihr Gott. Die eine Regel bleibt:
**Dreh drei gleiche Felder in eine neue Reihe – sie wachsen.**

Neu: An ein paar Stellen entscheidest du, was aus dem neuen Feld wird („Dein Wille geschehe“):

- Wiesen → **Wald** (Natur) oder **Acker** (Essen für die Menschen)
- Tiere → **Hütte** (Menschen kommen) oder **Paradies** (nur im freien Spiel)
- Dörfer → **Stadt** oder **Kirche** (viel Glaube)
- Städte → **Großstadt** oder **Industrie** (schnell stark, aber Schmutz)

Aus deinen Entscheidungen entstehen Folgen: Kirchen, die sich berühren, führen Krieg;
viel Industrie verschmutzt die Natur; fehlt Natur, wünschen sich die Menschen Wald, Tiere oder Regen.
**Glaube** ist die wichtigste Zahl und bezahlt Wunder. Kippt die Welt, kannst du strafen –
das kostet Glauben, rettet aber die Welt. Eine einzige Waage zeigt Natur ↔ Stadt/Industrie.

## Die Regeln kurz (freies Spiel; die 7 Tage siehe oben)

- **Drehen:** Wisch über eine Reihe. Kommen drei gleiche Felder in eine *neue* Reihe, wachsen sie
  (Wiese → Wald → großer Wald …, Acker → Hütte → Haus → Dorf …). In Einfach wächst die ganze Gruppe mit.
  Wächst eine Reihe aus drei gleichen nicht, sagt das Spiel immer, warum: Die drei Felder leuchten mit einem
  Abzeichen, dazu eine Pille mit dem Grund und was man stattdessen tun kann („Schräg zählt nicht · Bring 3 gleiche
  in eine gerade Reihe“, „Wasser wächst nie · Bring 3 gleiche in eine Reihe“, „Ruht · Großer Wald erst ab Tag 3 ·
  Mach neue Wälder aus Wiesen“) – auch, wenn Regen die Reihe fertig macht. Eine Reihe, die
  heute nur ruht, ist kein Fehlversuch.
- **Tag 1 – Schau zu!:** Die Ziel-Karte kündigt es an („Zeig's mir“) und nennt die Regel („Nur gerade
  Reihen · Wasser wächst nie“). Dann spielt die Hand genau einmal, ganz am Anfang, einen Zug vor (kostet
  nichts); ein Tippen in der Zeit zählt nicht, die Zeile hüpft. Sobald die Wiese da ist: „Jetzt du!“. Danach
  dreht sich keine Scheibe mehr von selbst; Hilfe ist nur Leuchten und der Tipp. Wer Tag 1 verlässt und
  wiederkommt, sieht die Vorführung nicht noch einmal.
- **Dein Wille geschehe:** An den vier Weggabelungen oben zeigt eine Karte zwei Bilder. Tipp eins an.
  Tippst du daneben oder wartest du, gilt deine letzte Wahl. Nach drei Karten pro Art reicht eine kleine Pille
  über dem Feld (sie blockiert nichts; „Wahl-Karte immer zeigen“ im Menü schaltet sie ab).
- **Glaube** ist die Zahl oben: für Wachsen, für erfüllte Wünsche und jede Runde von fertigen Feldern
  (Kirche +3, Industrie +5, Metropole +2, Paradies +1). Der Rekord zählt den Glauben am Spielende.
- **Krieg:** Bringt eine Drehung zwei Kirchen zusammen, sterben Menschen: Die Kirchen werden wieder Häuser,
  du verlierst Glauben.
- **Weltwaage:** links Natur, rechts Stadt. Grün in der Mitte ist gut. Zu viel Industrie macht **Smog**:
  Wälder welken, Tiere fliehen, kein Glaube pro Runde. Nur Wildnis heißt: Die Menschen haben Hunger.
- **Wünsche:** Eine Sprechblase über einem Menschen-Feld (sie fährt mit dem Feld mit). Erfüllst du sie in
  8 Drehungen (z. B. ein Wald daneben), gibt es +15 Glauben und das Feld wächst. Verpasst: nichts passiert.
- **Werkzeuge:** Regen (Natur wächst, löscht Feuer), Blitz (Schräge an einer Ecke), Monsun (ganze Seite).
  Strafen kosten Glauben, retten aber die Welt: **Gewitter** (−15, Industrie wird Erde) und **Flut**
  (−40, eine Seite wird reingewaschen).
- **Feuer:** Wächst bei einer Drehung nichts, leuchtet eine Flamme; bei drei brennt die Reihe und kostet ein
  Herz. Ohne Herzen ist die Welt verbrannt. **Vollendet** ist sie mit genug fertigen Feldern (Einfach 36,
  sonst 22) und der Waage nicht im Roten.
- Halte ein Symbol gedrückt, dann erklärt es sich.

Die vollständigen Regeln (für Entwickler, mit allen Zahlen): [`docs/GDPD_REGELN.md`](docs/GDPD_REGELN.md).

## Testversion

GitHub → Releases → `gdpd-testversion` (Android-APK, Windows-EXE, Linux-ZIP).
Jeder Push auf `gdpd/**` baut sie neu. Screenshots aus dem Build: [`docs/screenshots`](docs/screenshots).

Android-Paket: `at.identit.gdpd` – lässt sich also neben dem Original installieren.
