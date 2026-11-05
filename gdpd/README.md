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

## Testversion

GitHub → Releases → `gdpd-testversion` (Android-APK, Windows-EXE, Linux-ZIP).
Jeder Push auf `gdpd/**` baut sie neu. Screenshots aus dem Build: [`docs/screenshots`](docs/screenshots).

Android-Paket: `at.identit.gdpd` – lässt sich also neben dem Original installieren.
