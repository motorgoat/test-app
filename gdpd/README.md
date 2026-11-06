# gdpd – das Gottspiel auf dem Würfel (Arbeitstitel)

**gdpd** ist der Ableger von „God does play dice!“. Das Original bleibt unverändert in
[`../god_does_play_dice`](../god_does_play_dice) und wird dort weiter gebaut.

Godot 4.3, GDScript, Renderer „Compatibility“. Hochformat, Handy zuerst; PC-Versionen für Windows und Linux.

## Die Schöpfung in 7 Tagen

So beginnt das Spiel: Jeder Tag ist ein Level mit **einer** Aufgabe (oben immer zu sehen, z. B. „Tiere 1/3“),
begrenzten Drehungen und 1–3 Sternen (weniger Drehungen = mehr Sterne). Jeden Tag kommt genau **eine** neue Sache dazu.

| Tag | Titel | Aufgabe | Neu |
|---|---|---|---|
| 1 | Land | Lass 8 Wiesen wachsen (15 Drehungen) | Drehen: drei gleiche in einer Reihe wachsen (Tutorial mit Hand) |
| 2 | Pflanzen | Lass 5 Wälder wachsen | Regen (und Feuer, wenn lange nichts wächst) |
| 3 | Tiere | Erschaffe 3 Tiere | Leben: Wald → großer Wald → Tiere |
| 4 | Menschen | Baue 4 Hütten | Drei Tiere in einer Reihe bringen Menschen; sie haben Wünsche |
| 5 | Nahrung | Erfülle 3 Wünsche | Die erste Wahl: Wiese → Wald oder Acker |
| 6 | Glaube | Sammle 150 Glauben – kein Krieg! | Kirche und Glaube; zwei Kirchen treffen sich = Krieg |
| 7 | Ruhe | Sammle 250 Glauben – mit grüner Waage | Industrie und Gewitter; die Weltwaage und Smog |

Schafft man einen Tag nicht (keine Drehungen mehr, Krieg), gibt es „Nochmal“ – ohne Strafe, mit einem neuen
Brett und +2 Drehungen. Sterne und freie Tage werden gespeichert. Nach Tag 7: „Deine Welt ist vollendet!“ –
dann ist das **freie Spiel** offen (Einfach, Mittel, Schwer, 40 Drehungen). Weitere Pakete (Insel, Wüste, Winter)
kommen als Daten dazu. Spec: [`docs/GDPD_7_TAGE.md`](docs/GDPD_7_TAGE.md).

## Die Idee

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

## Die Regeln kurz

- **Drehen:** Wisch über eine Reihe. Kommen drei gleiche Felder in eine *neue* Reihe, wachsen sie
  (Wiese → Wald → großer Wald …, Acker → Hütte → Haus → Dorf …). In Einfach wächst die ganze Gruppe mit.
  Wächst eine Reihe aus drei gleichen nicht, sagt das Spiel immer, warum: Die drei Felder leuchten mit einem
  Abzeichen, dazu eine Pille mit dem Grund und was man stattdessen tun kann („Schräg zählt nicht · Leg die drei
  gerade nebeneinander“, „Wasser wächst nie · Bring drei Erden zusammen“, „Ruht heute · Wälder wachsen erst ab
  Tag 3 weiter · Mach lieber neue Wälder aus Wiesen“) – auch, wenn Regen die Reihe fertig macht. Eine Reihe, die
  heute nur ruht, ist kein Fehlversuch.
- **Tag 1 – Schau zu!:** Die Ziel-Karte kündigt es an („Zeig mir, wie es geht“) und nennt die Regel („Nur gerade
  Reihen zählen · Wasser wächst nie“). Dann spielt die Hand genau einmal, ganz am Anfang, einen Zug vor (kostet
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
