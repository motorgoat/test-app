# gdpd – das Gottspiel auf dem Würfel (Arbeitstitel)

**gdpd** ist der Ableger von „God does play dice!“. Das Original bleibt unverändert in
[`../god_does_play_dice`](../god_does_play_dice) und wird dort weiter gebaut.

Godot 4.3, GDScript, Renderer „Compatibility“. Hochformat, Handy zuerst; PC-Versionen für Windows und Linux.

## Die Idee

Die Welt ist ein Zauberwürfel und du bist ihr Gott. Die eine Regel bleibt:
**Dreh drei gleiche Felder in eine neue Reihe – sie wachsen.**

Neu: An ein paar Stellen entscheidest du, was aus dem neuen Feld wird („Dein Wille geschehe“):

- Wiesen → **Wald** (Natur) oder **Acker** (Essen für die Menschen)
- große Wälder → **Tiere** (Natur) oder **Hütte** (Menschen kommen)
- Dörfer → **Stadt** oder **Kirche** (viel Glaube)
- Städte → **Großstadt** oder **Industrie** (schnell stark, aber Schmutz)

Aus deinen Entscheidungen entstehen Folgen: Kirchen, die sich berühren, führen Krieg;
viel Industrie verschmutzt die Natur; fehlt Natur, wünschen sich die Menschen Wald, Tiere oder Regen.
**Glaube** ist die wichtigste Zahl und bezahlt Wunder. Kippt die Welt, kannst du strafen –
das kostet Glauben, rettet aber die Welt. Eine einzige Waage zeigt Natur ↔ Stadt/Industrie.

## Die Regeln kurz

- **Drehen:** Wisch über eine Reihe. Kommen drei gleiche Felder in eine *neue* Reihe, wachsen sie
  (Wiese → Wald → großer Wald …, Acker → Hütte → Haus → Dorf …). In Einfach wächst die ganze Gruppe mit.
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
