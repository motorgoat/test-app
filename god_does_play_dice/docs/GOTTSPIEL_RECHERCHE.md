# God does play dice! wird ein Göttergame: Recherche und Vorschläge

*Stand: 5. November 2026. Grundlage: Recherche zu rund 30 Göttergames und Puzzlespielen, drei Konzept-Entwürfe (gemütlich, Gottgefühl, Wiederkommen) und zwei unabhängige Gutachten zu Spaß, Einfachheit und Technik. Alle Aufwände in diesem Dokument sind die korrigierten Zahlen aus den Gutachten.*

---

## 1. Kurzfassung

**Empfehlung in einem Satz:** Bau zuerst einen einzigen klaren Kreislauf: *Du drehst, dein Volk wächst, es betet zu dir, und wenn genug Menschen an dich glauben, fährt deine Welt in den Himmel auf.*

Warum:

- Alle großen Göttergames leben von genau diesem Kreislauf: Du handelst, dein Volk gedeiht, daraus wird deine Macht [1][3][5]. Die ersten zwei Schritte (Drehen und Wachsen) haben wir schon.
- **Gebete** deines Volks waren die stärkste Idee der Recherche. Alle fünf Rechercherichtungen sind unabhängig darauf gekommen (Vorbilder: Reus, Dorfromantik, Travel Town [8][10][12]). Gebete geben jedem Dreh einen Grund.
- Im Moment endet jede Partie mit einer Niederlage. Der Test-Bot verliert auf Mittel und Schwer immer, im Schnitt nach rund 30 Drehungen. Eine **Himmelfahrt als Ziel** macht daraus einen Sieg, den man erreichen kann.
- Die Spiele, die zuletzt gescheitert sind, haben zu viel auf einmal gewollt (Godus, Fata Deum, Universim [6][15][16]). Deshalb kommen Heiligtümer, Zorn, Vorzeichen und Heiden erst später und nur, wenn Version 1 bei echten Spielern gut ankommt.
- Vorher müssen wir einen Fehler beheben. Im Modus Einfach gibt es eine Punkte-Schleife ohne Ende, die jede Rangliste kaputt macht (Details in Abschnitt 4).

---

## 2. Was die beliebtesten Göttergames ausmacht

### 2.1 Die wichtigsten Spiele im Überblick

| Spiel | Jahr / Plattform | Kern | Was wir lernen |
|---|---|---|---|
| **Populous** [1] | 1989, PC | Land formen, Volk siedelt, Mana aus Volksgröße | Formen ist das Verb des Gottes. Bei uns ist das Drehen. |
| **Populous: The Beginning** [2] | 1998, PC | Steinköpfe geben Zauber-Ladungen, Tempel lehren Zauber dauerhaft | Heiligtümer, die sich aufladen |
| **Black & White** [3] | 2001, PC | Gebete geben Macht, Gut/Böse färbt die Welt um | Gnade oder Zorn als *Stil*. Kein HUD war ein Fehler [4]. |
| **From Dust** [5] | 2011, PC/Konsole | Jedes Dorf schenkt eine Kraft. Stirbt das Dorf, ist die Kraft weg. | Macht hängt sichtbar an deinem Volk |
| **Godus** [6] | 2014, Mobil/PC | Glaubensblasen antippen, Timer, Glaube kaufbar | **Abschreckendes Beispiel** |
| **Reus** / **Reus 2** [7][8] | 2013 / Reus 2 später, PC | Riesen erfüllen Projekte der Dörfer. Reus 2 hat Gier und Krieg gestrichen. | Wünsche des Volks als kurze Ziele. Weniger Strafe kam besser an. |
| **Dorfromantik** [10] | PC, später Konsole | Erfüllte Aufträge füllen den Kartenstapel auf. Scheitern kostet nichts. | Gebete füllen unser „Fehler-Budget“ wieder auf |
| **Triple Town** [11] | Mobil | 3 Gleiche verschmelzen. Bären werden eingesperrt und zu Kirchen. | Hindernisse, aus denen Wert wird. Kaum Meta-Ebene bringt wenig Umsatz [21]. |
| **Travel Town** [12] | Mobil | 2–3 Aufträge gleichzeitig sichtbar, du wählst aus | 2024 das umsatzstärkste Merge-Spiel |
| **Against the Storm** [13] | 2023, PC | Ruf gegen Ungeduld, kurze Läufe, Segen zur Auswahl | Klares Siegziel. Metacritic 91, über 1 Mio. verkauft. |
| **Islanders** [14] | 2019, PC/Mobil | Punkte schalten neue Bauteile frei, du wählst 1 von 2 | „Wähle 1 von 3 Segen“ |
| **Universim** [15] | 1.0 2024, PC | Glaubenspunkte, Zeitalter | Glaube ohne Folgen wirkt tot |
| **Fata Deum**, **Masters of Albion** [16][17] | Early Access, PC | Moderne Black-&-White-Nachfolger | Gottgefühl geht unter vielen Verwaltungs-Aufgaben unter. Beide nur „gemischt“ bewertet. |
| **Pocket God** [18] | 2009, iOS | Kleine Bewohner zum Anstupsen, komische Reaktionen | Reagierende Bewohner sind das billigste Gottgefühl |
| **WorldBox** [19] | PC/Mobil | Sandkasten, alle Kräfte gratis | Zen-Modus als Bonus, ca. 95 % positiv auf Steam |
| **Doodle God** [20] | Mobil | Elemente kombinieren, Entdeckungsbuch | Sammelbuch. Laut Entwickler über 100 Mio. Downloads (unbestätigt). |
| **Tiny Glade**, **Townscaper** [22][23] | PC / Mobil | Gemütliches Bauen mit viel „Knack und Plopp“ | Gutes Gefühl beim Bedienen hält Spieler. Tiny Glade: 616.000 Verkäufe im ersten Monat. |

### 2.2 Die 10 wichtigsten Erkenntnisse

1. **Kreislauf: handeln → Volk reagiert → Wohlstand wird Macht.** Bei uns: drehen → Felder wachsen → Gläubige → Wunder.
2. **Wünsche schlagen abstrakte Ziele.** Wer einen Wunsch erfüllt, darf länger spielen. Dorfromantik gibt pro Auftrag Karten zurück [10].
3. **Das Haupt-Verb nie sperren, besteuern oder zur Pflichtarbeit machen.** Godus hat das Formen hinter Glaube versteckt und Tipp-Sammeln eingebaut. Peter Molyneux, der Macher von Godus, nannte das selbst „den größten Fehler der letzten 20 Jahre“ [6][24]. Drehen bleibt bei uns immer frei.
4. **Feste Anker sind gute Tempel**, wenn sie am *Teil* hängen und nicht an einer Himmelsrichtung (mehr dazu in 2.4).
5. **Alles ankündigen und die Ursache zeigen.** SimEarth und From Dust wurden kritisiert, weil man nicht sah, warum etwas passiert [5][25]. Unsere Vorschau mit roten Feuerfeldern ist schon ein großer Vorteil.
6. **Wenige Verben, tiefe Folgen.** Die erfolgreichen gemütlichen Spiele haben fast keine Knöpfe (Dorfromantik, Townscaper, Islanders).
7. **„Juice“ hält die Spieler.** Gemeint ist das gute Gefühl beim Bedienen: Klick-Geräusch, Vibration, steigende Tonhöhe, großer Moment bei Blitz und Monsun.
8. **Moral als Stil, nicht als Urteil.** Beide Wege müssen gleich stark sein. In Black & White 2 hat ein einziger Weg alles dominiert [26].
9. **Eine leichte Meta-Ebene ist Pflicht.** Meta-Ebene heißt: etwas, das über eine Partie hinaus bleibt, zum Beispiel Sterne, ein Sammelbuch oder Skins. Royal Match hat 2024 1,46 Mrd. $ umgesetzt, mit Sternen, die man nicht kaufen kann [27].
10. **Sanfte Strafe als Standard, Härte nur wer will.** Reus 2 hat Gier und Krieg gestrichen [9]. Dazu kommt ein klares Siegziel, sonst fehlt das „Wofür?“. Genau das wurde an Before We Leave kritisiert [28].

### 2.3 Fallen, die wir vermeiden

- **Godus:** Glauben sammeln durch Antippen, Timer, Glaube kaufbar, ungenaue Steuerung auf dem Handy [6].
- **Dungeon Keeper Mobile:** Timer, die immer länger werden, und Werbung mit „gratis“, die die britische Werbeaufsicht als irreführend gerügt hat [29].
- **Spore:** viele flache Stufen statt eines tiefen Kreislaufs.
- **Universim:** Glaube als Zahl ohne Folgen [15].
- **Fata Deum / Masters of Albion:** Verwaltung statt Gottgefühl [16][17].
- **Triple Town:** keine Meta-Ebene. Dazu die „Ninja-Bären“: Zufall, der die Partie entscheidet [11][21].
- **Energie-Timer** aus Merge-Spielen: niemals bei uns.
- **Gekaufte Macht in Ranglisten.** Das gilt auch für unsere Regen-, Blitz- und Monsun-Käufe mit Münzen.
- **Markenrecht:** in der Werbung nicht „Rubik“ verwenden und nicht die klassischen Würfelfarben.

### 2.4 Wichtige Korrektur zu unserem Würfel

In IDEEN.md und STRATEGIE_KONZEPT.md steht, die 6 Mittelfelder bewegen sich nie. **Das stimmt im Code nicht.** Dreht man die mittlere Scheibe, wandern 4 Mittelfelder auf andere Seiten mit. Ein Test prüft das sogar (`tests/test_rules.gd`, Zeile 156). Fest bleibt nur, welche Mitte welcher gegenüber liegt, wie bei einem echten Zauberwürfel.

Für das Göttergame heißt das: Ein Heiligtum **fährt mit seinem Mittelstück mit**. Gebete dürfen nie „die Nordseite“ sagen, sondern nur „das Feld von Anna“ oder „die Seite des Wasser-Heiligtums“.

---

## 3. Die empfohlenen Kombis

Größen beim Aufwand: S = bis 3 Tage, M = 4–7 Tage, L = 8–14 Tage, XL = mehr als 14 Tage (jeweils Entwicklertage).

### Kombi 1: Himmelfahrt (Gläubige, Ziel und Sterne) ⭐ **Top**

- **Was du erlebst:** Um deinen kleinen Gott oben im Bild läuft ein Ring: „47 / 70 Gläubige“. Jedes Wachstum füllt ihn, Feuer leert ihn. Ist er voll, steigt deine Welt mit „Halleluja!“ in den Himmel auf. Du bekommst 1–3 Sterne.
- **Regel:**
  - Gläubige = Summe aller Feldstufen. Sie steigen um genau +1 pro Verschmelzung und fallen nur durch Feuer. Wer nur Fehlzüge macht, bekommt also nichts.
  - Ziel je Modus (erste Schätzung): Mittel 70, Schwer 60. Einfach erst nach der Reparatur (Abschnitt 5).
  - Sterne: ★ für das Ziel, ★★ wenn dabei noch mindestens 2 Herzen übrig sind, ★★★ wenn du es in höchstens 40 Drehungen schaffst.
  - Danach wählst du „Neue Welt“ oder „In die Ewigkeit“ (endlos weiterspielen).
  - Die Punkte heißen jetzt *Glaube* und laufen klein weiter. Sie lösen wie bisher Regen und Monsun aus.
  - Das Zeitalter richtet sich nach dem Höheren von beiden: höchste Stufe oder Gläubige. Sonst sieht auf Mittel kaum jemand ein späteres Zeitalter.
  - Glaube aus Gläubigen fliegt **von selbst** als Funken zum Gott. Es gibt nichts anzutippen.
- **Vorbilder:** Populous, Black & White, Against the Storm, From Dust, Royal Match (Sterne, die man nicht kaufen kann) [1][3][5][13][27].
- **Aufwand:** M. 4–5 Tage ohne Film-Sequenz, 7–8 Tage mit Avatar-Mimik und Aufstiegs-Film.
- **Risiko:** Ein falsches Ziel macht das Spiel zu leicht oder unschaffbar. Deshalb stellen wir es mit dem Bot ein: Er soll in 30–45 % der Partien aufsteigen. Menschen planen besser und landen dann bei etwa 50–70 %.

**Entscheidung zwischen den Konzepten:** Ein Konzept wollte das Ziel an den *Punkten* festmachen und mehrere Welten zu einem Lauf verketten. Beide Gutachter lehnen das ab. Punkte lassen sich in Einfach endlos hochtreiben, und die Kette macht zusätzlich Spielstand-Speichern nötig. Deshalb gilt in Version 1: **eine Welt, Ziel = Gläubige.** Die Kette kommt später in der „Pilgerfahrt“ (Kombi 5).

### Kombi 2: Gebete der Völker (mit Zweifel statt Flammen) ⭐ **Top**

- **Was du erlebst:** Über dem Würfel hängt eine Gebetskarte: *„Hütte Anna: Wir wünschen uns einen Wald neben uns! (noch 8 Drehungen)“*. Ein kleines Gesicht sitzt auf Annas Feld und dreht mit. Erfüllst du den Wunsch, ruft sie „Dein Wille geschehe!“ und eine Flamme geht aus. Verpasst du ihn, zuckt sie mit den Schultern. Sonst passiert nichts.
- **Regel:**
  - Das Gebet hängt an einem **Feld**, nicht an einer Seite. So stimmt es nach jeder Drehung, und wir brauchen dafür noch keine Heiligtümer.
  - Gebetsarten: etwas wachsen lassen, eine Stufe erreichen, ein bestimmtes Nachbarfeld, eine Reihe durch das Feld, „lass es bei uns regnen“ (bringt Regen bei), „drei Gleiche an einer Ecke“ (bringt Blitz bei).
  - Frist: etwa 8 Drehungen. Regen zählt nicht als Drehung.
  - Belohnung steht vorher auf der Karte: −1 Flamme, sonst +1 Regen, sonst Glaube. Höchstens 1 Flamme pro 10 Drehungen, damit Partien nicht endlos werden.
  - Die Flammen heißen jetzt **Zweifel**. Die Regel bleibt gleich: 3 Zweifel = Feuer. Es gibt aber jetzt eine Geschichte dazu.
  - In der Vorschau leuchtet die Karte golden, wenn der Dreh das Gebet erfüllt. Der Tipp bevorzugt solche Drehs. Tippst du auf die Karte, dreht sich der Würfel zu Annas Feld.
  - Version 1: 1 Karte. Ab Mittelalter: 2 Karten.
- **Vorbilder:** Reus (Projekte), Dorfromantik (Aufträge füllen den Stapel auf, Scheitern kostet nichts), Travel Town (Aufträge zur Auswahl), Pocket God (Figuren mit Namen) [7][10][12][18].
- **Aufwand:** M–L, 8–10 Tage. Die Konzepte schätzten 6. Die Gutachter rechnen mehr Zeit für Oberfläche, Feinschliff und Tests ein.
- **Risiko:**
  - Unerfüllbare Gebete frustrieren. Wir erzeugen nur Ziele, die höchstens eine Stufe über deiner besten liegen.
  - Wichtig für die Technik: Die Prüfung muss billig bleiben, denn sie läuft bei jeder Vorschau mit. Eine Suche im Voraus würde das Spiel ruckeln lassen.
  - Zu viele Karten machen den kleinen Bildschirm voll.

**Entscheidung zwischen den Konzepten:** Ein Konzept hängte Gebete an die Seite eines Heiligtums. Dafür bräuchte Version 1 aber schon alle Heiligtümer. Wir nehmen die feld-gebundene Version. Gebete mit Heiligtum-Namen kommen mit Kombi 6.

### Kombi 3: Lebendiges Volk ⭐ **Top**

- **Was du erlebst:** Auf deinen Feldern wohnen kleine Leute. Machst du eine Reihe, jubeln sie. Bei Regen, Blitz und Monsun knien sie nieder. Droht Feuer (rote Felder in der Vorschau), rennen sie panisch umher. Ein Ältester ruft „Um Gottes Willen!“ oder „Grundgütiger!“. Jede Drehung klickt hörbar und vibriert, und Kombos werden hörbar höher.
- **Regel:**
  - Keine neue Spielregel, nur Darstellung. Vorschau, Tipp und Rückgängig können dadurch also nicht kaputtgehen.
  - Wir nutzen die Figuren, die es schon gibt (`_bobbers` in `field_view.gd`), und die Sprüche-Listen `PRAISE` und `GASP`.
  - Sprechblasen höchstens alle paar Sekunden, damit es nicht nervt.
  - Optional: Ein kleiner Siedler läuft zum wachsenden Feld, bevor das Gebäude erscheint. So siehst du: „Die Reihe hat das gemacht.“
- **Vorbilder:** Pocket God, Black & White, From Dust (die fehlende Reaktion des Volks war dort die Hauptkritik), Dorfromantik, Townscaper [3][5][18][23].
- **Aufwand:** M. Kleine Version 5 Tage (die Konzepte sagten 3), volle Version 8–10 Tage. Der Siedler-Lauf greift in die Reihenfolge der Animationen ein und muss auf einem echten Android-Gerät geprüft werden. Ziel: mindestens 50 Bilder pro Sekunde.
- **Risiko:** Animationen bremsen das Tempo, deshalb muss alles überspringbar sein und bei Kombos schneller laufen. Bei vielen Figuren kann die Leistung auf dem Handy leiden.

**Warum Top:** Ein Gutachter sagt: Ohne diese Kombi wirkt Version 1 wie „ein Puzzle mit Fortschrittsbalken“, nicht wie ein Göttergame.

### Kombi 4: Segen der Zeitalter

- **Was du erlebst:** Erste Hütte, die Steinzeit beginnt. Kurz wird gefeiert, dann liegen 3 Karten vor dir. Du wählst zum Beispiel *„Sanfter Regen: Regen kommt öfter“*.
- **Regel:**
  - Angebot bei jedem neuen Zeitalter **und** bei halbem Gläubigen-Ziel. Auf Mittel erreicht man sonst nur 1–2 Zeitalter.
  - Startkarten, die jeweils nur einen Wert ändern:
    - Sanfter Regen: Regen alle 9 statt 12 Punkte.
    - Volle Wolken: 5 statt 3 Regen.
    - Gnädige Flammen: Das nächste Feuer verlischt sofort.
    - Geduld: Das nächste Feuer kommt erst bei 4 Zweifeln.
    - Starkes Herz: +1 Herz.
    - Erhörung: Die nächsten 2 Gebete geben doppelt.
  - Karten wie „Doppelblitz“, die die Reihen-Regeln ändern, kommen später.
  - Die Karten zieht das Spiel aus der Welt-Zufallszahl. Bei gleichem Startwert gibt es also gleiche Karten.
- **Vorbilder:** Islanders, Against the Storm, Reus [7][13][14].
- **Aufwand:** S–M, 3–5 Tage. Plus 2 Tage, sobald Karten die Reihen-Regeln ändern.
- **Risiko:** Eine Karte ist zu stark und alle nehmen nur noch sie. Der Bot misst, wie viel jede Karte bringt. Mehr als +25 % ist zu viel.

### Kombi 5: Welt des Tages (später Pilgerfahrt)

- **Was du erlebst:** Im Menü wartet „Welt des Tages · Tag 12 🔥“. Alle Spieler bekommen denselben Würfel. Danach kannst du teilen: „God does play dice · 5. Nov · ★★★ · 34 Drehungen · Antike“.
- **Regel:**
  - Startwert aus dem Datum. Das geht schon heute über `setup(seed_value)`.
  - Ersetzt den eigenen Menüpunkt für die 40-Züge-Herausforderung.
  - Gekaufte Gadgets und „Weiterspielen“ sind hier aus.
  - Eine Serie über mehrere Tage schaltet Kosmetik frei.
  - Später kommt die wöchentliche „Pilgerfahrt“ mit 7 Welten. Dort passt auch die Welten-Kette aus dem gemütlichen Konzept hin.
- **Vorbilder:** Two Dots (Wochenaufgaben), Polytopia (begrenzte Punkte-Läufe), Tiny Glade und Infinite Craft (teilen) [30][31].
- **Aufwand:** S, 2–3 Tage lokal. Online-Rangliste über Google Play Games / Game Center: 8–10 Tage. Eigener Server mit Betrugsschutz: 12–20 Tage.
- **Risiko:** Ein Tag kann unlösbar sein. Deshalb spielt der Bot die Welt von morgen vorab durch.

### Kombi 6: Sechs Heiligtümer

- **Was du erlebst:** Auf jedem Mittelfeld steht ein kleiner Tempel, zum Beispiel Wasser, Sonne oder Volk. Wachstum auf seiner Seite füllt seine Lichter. Sind alle voll, schenkt er dir sein Wunder. Brennt es auf seiner Seite, wird er dunkler.
- **Regel:**
  - Das Heiligtum ist nur ein **Zusatz** auf dem Mittelfeld. Das Feld bleibt ein normales Stufen-Feld mit seinen 4 Reihen, dem Seiten-Bonus und der Blitz-Diagonale.
  - Es fährt bei Mittel-Drehungen sichtbar mit. Ein Hinweis erklärt das: „Die Heiligtümer wandern mit!“
  - Aufladung: +1 für Wachstum auf seiner aktuellen Seite, +2 für eine Reihe durch die Mitte. Start mit 6–8 Ladungen, der Bot stellt den Wert ein.
  - Geschenke sind die Gadgets, die es schon gibt: Wasser gibt Regen, Sonne löscht und nimmt 1 Zweifel, Volk gibt ein Drittel Herz. Es gibt keine neuen Knöpfe.
  - Pro Zeitalter wird ein Heiligtum freigeschaltet. Ab dann dürfen Gebete Heiligtümer nennen.
- **Vorbilder:** Populous: The Beginning (Steinköpfe), From Dust (Kraft hängt am Dorf), Populous II (Element-Bereiche), Black & White (Tempel) [2][3][5].
- **Aufwand:** L, 10–14 Tage mit 6 Tempel-Modellen und ihren Zeitalter-Stufen. 5–6 Tage für die ersten 3.
- **Risiko:**
  - Spieler glauben, der Tempel steht fest.
  - Zu viele Geschenke blähen die Wirtschaft auf. Dann müssen Regen und Monsun seltener kommen.

**Entscheidung:** Wunder wie „3 Drehungen ohne Fehler“ oder „Gratis-Drehung“ aus dem Gottgefühl-Konzept streichen wir. Sie hebeln das knappe Fehler-Budget aus und sind laut Gutachten zu stark. Bei der Aufladung nehmen wir beide Quellen. Nur „Reihe durch die Mitte“ wäre zu langsam: Laut Bot laufen nur etwa 33 % der Reihen durch eine Mitte. Nur „Wachstum auf der Seite“ wäre zu beliebig.

### Kombi 7: Gnade oder Zorn

- **Was du erlebst:** Jedes Feuer macht dich ein bisschen zornig. Du bekommst einen **Zorn-Blitz**, der ein Feld eine Stufe senkt. So kannst du eine verklemmte Reihe lösen. Wer viel regnet, bekommt einen goldenen Himmel und Lobgesänge. Wer viel blitzt, bekommt Gewitterwolken und „Gnade, Herr!“.
- **Regel:**
  - Zorn-Blitz: 1 pro Feuer, höchstens 2.
  - Er zählt nicht als Drehung und nicht als Fehler, kann aber eine neue Reihe auslösen.
  - Er gibt keinen Regen als Bonus. Sonst entsteht eine Gadget-Schleife.
  - Der Gnade/Zorn-Wert bleibt unsichtbar und ändert **nur das Aussehen**: Himmel, Gesicht des Gottes, Sprüche und Skin-Varianten. Kein Weg ist stärker.
- **Vorbilder:** Black & White, Fata Deum, Dungeon Keeper („Böse sein macht Spaß“), Triple Town (Werkzeug zum Entfernen) [3][11][16].
- **Aufwand:** Code S, 3 Tage. Grafik 5–8 Tage für zwei Stimmungen. Zwei vollständige Skin-Reihen sind ohne Grafiker kaum planbar.
- **Risiko:** Der Zorn-Blitz ist sehr stark, daher die Grenze von 2. Der Ton „eigenes Volk bestrafen“ muss witzig bleiben: Die Leute schütteln die Faust und bauen wieder auf.

**Entscheidung:** Ein Gutachter will den Zorn-Blitz als Umschalter am Blitz-Knopf, weil die Leiste schon voll ist. Der andere findet einen Umschalter zu kompliziert. Unsere Lösung: Der Zorn-Blitz sitzt im Blitz-Knopf, aber nur als zweite Ladung, wenn du einen hast. Es gibt keinen Umschalter, der immer da ist.

### Kombi 8: Schöpfungsbuch und Himmelreich (Sammeln und Skins)

- **Was du erlebst:** Ein Buch voller Schatten-Bilder, die sich mit deinen Entdeckungen füllen: erste Hütte, erstes Zeitalter, erster Eck-Blitz und so weiter. Sterne kaufen Teile für deinen Gott: Hut, Gewand, Brille, Spaghettimonster-Körper. Aufgestiegene Welten kreisen als Planeten um deinen Thron.
- **Regel:**
  - Einträge bleiben, auch wenn eine Welt abbrennt. Das ist der Trost beim Verlieren.
  - Sterne kann man nie kaufen.
  - Kosmetik bekommt man mit Sternen oder Münzen.
  - Alles auf **einem** Bildschirm.
- **Vorbilder:** Doodle God, Infinite Craft, Royal Match/Homescapes, Polytopia [20][27][31].
- **Aufwand:** Buch M, 3–4 Tage. Avatar und Himmel L, 8–12 Tage, vor allem Grafik. Ein 2D-Avatar aus Schichten ist viel billiger als 3D.
- **Risiko:** Die Meta-Ebene wächst immer weiter, wie bei Fabledom. Klein halten.

### Kombi 9: Vorsehung (Vorzeichen, nur Mittel/Schwer)

- **Was du erlebst:** Manchmal erscheint ein Zeichen auf einem Feld und fährt mit:
  - Ein **goldener Stern** bedeutet: Machst du hier eine Reihe, wächst es doppelt.
  - Eine **dunkle Wolke** bedeutet: In 3 Drehungen kommt Dürre, wenn du nicht vorher regnest oder das Feld wegdrehst.
- **Regel:**
  - Erscheint nur in der Scheibe, die du gerade gedreht hast.
  - Sterne kommen öfter als Wolken.
  - Dürre kostet nie ein Herz.
  - Kein Vorzeichen, wenn schon 2 Zweifel da sind.
  - Die Vorschau zeigt die Gefahr rot, wie beim Feuer.
- **Vorbilder:** Timberborn (Dürre-Zeiten), From Dust (Tsunami-Warnung), Threes (nur Teil-Infos) [5][32][33].
- **Aufwand:** M, 5–6 Tage.
- **Risiko:** Du hast die Natur-Katastrophen bewusst gestrichen. Darum ist das nur für Mittel/Schwer gedacht, gut sichtbar und vermeidbar.

### Kombi 10: Zweifler und Kapellen (nur als Option, eher für den PC)

- **Was du erlebst:** Eine grummelige graue Wolke wandert über deine Natur-Felder und blockiert sie. Umzingelst du sie mit Städten, wird sie gläubig und baut eine **Kapelle**. Drei Kapellen in einer Reihe werden eine **Kirche**, die ihre Seite einmal vor Feuer schützt.
- **Regel:**
  - Neue Schicht über den Feldern mit einer festen Lauf-Regel.
  - Die Kirchen-Leiter ist eine zweite Leiter, die neben der normalen Stufen-Leiter herläuft.
  - Name „Zweifler“, nicht „Heiden“, weil das abwertend klingt.
- **Vorbilder:** Triple Town (Bär → Grabstein → Kirche), Merge Dragons, Black & White 2 (bekehren statt erobern) [11][26].
- **Aufwand:** XL, 15–20 Tage.
- **Risiko:** Das ist eine zweite Puzzle-Grammatik und der größte Angriff auf „einfach“. Beide Gutachter sagen: aufschieben, höchstens als Schwer-Option. Krieg passt besser in das PC-Spiel *Würfelreiche* (STRATEGIE_KONZEPT.md).

---

## 4. Fahrplan

**Vorweg: Was die Gutachter korrigiert haben.** Die drei Konzepte haben für Version 1 jeweils 14–15 Tage geschätzt. Realistisch wären für ihren Umfang 22–25 Tage. Deshalb ist Version 1 hier kleiner geschnitten.

### Fundament (3–4 Tage, Pflicht, für Spieler unsichtbar)

- **Punkte-Schleife reparieren.** Eine Metropolen-Reihe zahlt weiter Punkte (75 × Kombo), obwohl nichts mehr wachsen kann. Im Code geprüft: `resolve_merges` in `game_state.gd`. Im Bot-Test lief eine Einfach-Partie mit 20 Metropolen von 13.643 auf 27.593 Punkte, ohne dass sich ein Feld änderte. Neu: Sie zahlt einmal, danach nicht mehr.
- **Alten Code entfernen:** Verschmutzung, Nachwachsen, `meteors_used`, `next_bolt`.
- **Schutz-Test:** Ein Test prüft automatisch, dass beim Kopieren des Spielstands kein Wert vergessen wird. Jede neue Kombi braucht das.
- **Bot-Simulation in GitHub:** Sie misst automatisch Aufstiegs-Rate, Drehungen und Feuer. Ohne diese Zahlen sind alle Ziele oben nur geraten.

### v1 „Der Gott und sein Volk“ (ca. 3 Wochen, sofort spürbar besser)

| Inhalt | Kombi | Tage |
|---|---|---|
| Fundament | – | 3–4 |
| Himmelfahrt (Ring, Ziel, Sterne; ohne Film) | 1 | 4–5 |
| Gebete (1 Karte, 4–6 Arten) + Zweifel statt Flammen | 2 | 8–10 |
| Klick-Geräusch + Vibration + Jubeln (Mini-Teil von Kombi 3) | 3 | 1–2 |

Version 1 ist fertig, wenn:

- der Bot auf Mittel länger überlebt (von etwa 30 auf 40–50 Drehungen);
- 50–70 % der Gebete erfüllt werden;
- 5 Testspieler zum Gebets-Feld hindrehen, ohne den Text zu lesen.

### v2 „Wille und Wunder“ (ca. 6–7 Wochen)

- Lebendiges Volk komplett (Kombi 3)
- Segen der Zeitalter (Kombi 4)
- Welt des Tages lokal (Kombi 5)
- Laufende Welt speichern. Auf dem Handy wird die App oft beendet.
- Schöpfungsbuch + 2D-Avatar mit ersten Skins, Spaghettimonster als erstes Premium-Kosmetik (Kombi 8)
- Sechs Heiligtümer, zuerst 3 (Kombi 6)
- Gnade oder Zorn, erst nur Himmel und Sprüche (Kombi 7)
- **Faire Monetarisierung (12–18 Tage):**
  - Belohnungs-Videos nur bei Weiterspielen, doppelten Sternsplittern, Serien-Schutz und Tagesgeschenk;
  - einmaliger Premium-Kauf „Hohepriester“: keine Werbung, Skin-Set, Zen-Modus „Garten Eden“;
  - Kosmetik-Laden;
  - in der EU Pflicht: Einwilligungs-Dialog (DSGVO), Datenschutzerklärung und Altersfreigabe.
- Online-Rangliste über Play Games / Game Center (8–10 Tage)

### v3 „Glaube und Kirchen“ (nur wenn v2 gut läuft)

- Vorsehung (Kombi 9)
- Wöchentliche Pilgerfahrt mit 7 Welten
- Welten mit Sonderregeln: Wüste, Eis, Meer
- Pantheon-Bildschirm
- Weihnachts-Thema
- Eigener Ranglisten-Server
- Zweifler und Kapellen als Schwer-Option, oder ganz ins PC-Spiel (Kombi 10)

---

## 5. Was wir vereinfachen oder streichen würden

- **Regen, Blitz und Monsun mit Münzen kaufen.** Wunder sollen von deinem Volk kommen. Mindestens in Welt des Tages und Ranglisten wären sie aus. Münzen bleiben für Tipp, Rückgängig, Weiterspielen und Kosmetik.
- **Einfach in der jetzigen Form.** 10 Wiesen werden in etwa 10 Drehungen zur Metropole. Entweder wir bremsen das Gruppenwachstum, oder Einfach wird der gemütliche „Garten“ ohne Rangliste.
- **Die 40-Züge-Herausforderung als eigener Menüpunkt.** Sie geht in der Welt des Tages auf.
- **Endlos ohne Ziel.** Die Himmelfahrt ersetzt es, „In die Ewigkeit“ bleibt als Wahl.
- **Zwei gleich große Zahlen.** Die Überschrift ist der Gläubigen-Ring, Glaube (Punkte) wird klein.
- **Nicht ins Handyspiel:** Krieg, rivalisierende Götter, Gier, Glauben antippen und einsammeln, Glaube zum Ausgeben, Energie-Timer, kaufbare Macht.
- **Die gestrichenen Strafen** (Erdbeben, Überschwemmung, Waldbrand) bleiben gestrichen. Vorzeichen sind etwas anderes: angekündigt, vermeidbar und nur auf Mittel/Schwer.
- **Leiter, Reihen-Regeln, Feuer und Herzen** bleiben in v1 unverändert.
- **IDEEN.md und STRATEGIE_KONZEPT.md** sollten korrigiert werden: Die Mitten wandern mit der Mittelscheibe.

---

## 6. Offene Fragen an dich

1. **Regen:** Heute lässt Regen nur ein Feld der *niedrigsten* Stufe wachsen oder löscht Feuer. Soll Regen jedes Feld wachsen lassen? Wichtig für das Gebet „Lass es bei uns regnen“, das ein bestimmtes Feld braucht. Optionen:
   - (A) wie heute;
   - (B) jedes Feld, das ist sehr stark, denn dann wird aus einer Stadt eine Großstadt;
   - (C) **meine Empfehlung:** jedes Feld der Stufen 0–3, also Erde und Natur. Regen hilft Pflanzen, nicht Städten. Das ist leicht zu verstehen und bleibt fair. Der Bot prüft vorher, ob es zu stark ist.
2. **Ende einer Welt:** Soll jede Welt mit der Himmelfahrt enden (meine Empfehlung, „In die Ewigkeit“ als Wahl)? Oder soll endlos der Standard bleiben und die Himmelfahrt nur ein Meilenstein sein?
3. **Einfach:** Soll Einfach „sanft, aber mit Ende“ werden (Wachstum bremsen)? Oder wird es der Zen-Garten ohne Rangliste?
4. **Religiöser Ton:** Passen christliche Sätze („Dein Wille geschehe“, „Halleluja“), Kirchen und das Spaghettimonster zusammen? Ist „Zweifler“ statt „Heiden“ okay? Darf der Zorn-Blitz „Gottverdammt!“ sagen? Das ist wichtig für Altersfreigabe und Store-Prüfung.
5. **Münzen und Geschäftsmodell:** Sollen gekaufte Gadgets ganz weg oder nur in Ranglisten aus sein? Und: kostenlos mit Belohnungs-Videos plus einmaligem Premium-Kauf (meine Empfehlung) oder Bezahl-App für ca. 4,99 € ohne Werbung?
6. **Grafik und Gott:** Wer macht Avatar und Skins? Reicht ein 2D-Gott aus Schichten (billig), oder soll er eine 3D-Spielfigur wie der Würfel sein (2–3× Aufwand)? Und ist der Gott ein fester „Gott“ oder gleich dein eigener, selbst gebauter?

---

## 7. Quellen

*Hinweis: Viele Seiten (z. B. Wikipedia, gamedeveloper.com) ließen sich nicht direkt öffnen. Die Fakten stammen aus Suchergebnis-Auszügen. Zahlen vor einer Verwendung in Store-Texten bitte noch einmal prüfen. Die Bot-Zahlen stammen aus einem einfachen Test-Bot mit 8 Startwerten und sind nur ein Anhaltspunkt.*

1. Populous: https://en.wikipedia.org/wiki/Populous_(video_game) und Handbuch https://ts.popre.net/archive/Downloads/Docs/Populous_1989_Manual.pdf
2. Populous: The Beginning: https://en.wikipedia.org/wiki/Populous:_The_Beginning und https://wiki.popre.net/Mana
3. Black & White: https://en.wikipedia.org/wiki/Black_%26_White_(video_game) und https://blackandwhite.fandom.com/wiki/Worship_Site
4. Molyneux zur Oberfläche ohne Symbole: https://www.gamespot.com/articles/black-and-white-updated-qanda-peter-molyneux/1100-2692754/
5. From Dust: https://en.wikipedia.org/wiki/From_Dust und https://www.trustedreviews.com/reviews/from-dust
6. Godus: https://www.pocketgamer.com/godus/review/ und https://kotaku.com/why-peter-molyneuxs-godus-is-such-a-disaster-1685539932
7. Reus: https://en.wikipedia.org/wiki/Reus_(video_game) und https://www.gamepressure.com/reus/greed/z24fce
8. Reus 2: https://game8.co/articles/reviews/reus-2-review
9. Reus 2 ohne Gier und Krieg: https://www.superjumpmagazine.com/how-changing-one-mechanic-elevated-reus-2-beyond-its-predecessor/
10. Dorfromantik: https://gamepretty.com/dorfromantik-beginners-guide-quests-rewards-tile-placement/ und https://www.gamedeveloper.com/disciplines/sparking-joy-through-tile-placement-in-idyllic-village-builder-i-dorfromantik-i-
11. Triple Town: https://support.spryfox.com/hc/en-us/articles/219104828-How-to-play-Triple-Town und https://unwinnable.com/2012/02/28/the-app-hole-ninja-bears-my-new-mortal-enemy/
12. Travel Town: https://naavik.co/digest/why-travel-town-is-dominating-mobile-merge/
13. Against the Storm: https://gamespress.com/Against-the-Storm-1-million-sales und https://en.wikipedia.org/wiki/Against_the_Storm_(video_game)
14. Islanders: https://en.wikipedia.org/wiki/Islanders_(video_game) und https://www.pocketgamer.com/islanders-mobile/
15. Universim: https://game8.co/articles/reviews/the-universim-review und https://gamingonlinux.com/2024/01/the-universim-god-game-city-builder-10-is-out-now
16. Fata Deum: https://store.steampowered.com/app/1330360/Fata_Deum__The_God_Sim/ und https://www.pcgames.de/Fata-Deum-Spiel-75397/Specials/Deutsche-Goetter-Sim-will-Black-und-White-beerben-unser-Early-Access-Fazit-1482507/2/
17. Masters of Albion: https://www.player2.net.au/2026/05/the-early-access-report-masters-of-albion/
18. Pocket God: https://gamesbeat.com/pocket-god-sells-2m-units-on-the-iphone-first-paid-app-to-do-so/
19. WorldBox: https://superworldbox.com/faq und https://steamdb.info/app/1206560
20. Doodle God: https://www.pocketgamer.biz/interview/52539/100-million-downloads-is-just-the-start-for-us-says-joybits-ceo-paul-baldwin/
21. Triple Town, Umsatz und Meta-Ebene: https://www.gamedeveloper.com/business/free-to-play-tips-from-i-triple-town-i-s-studio-head
22. Tiny Glade: https://newsletter.gamediscover.co/p/how-tiny-glade-built-its-way-to-600k
23. Townscaper Mobil: https://toucharcade.com/2021/10/20/townscaper-mobile-review-iphone-android-ipad-icloud-controller-support-raw-fury/
24. Molyneux über Godus: https://gamesbeat.com/peter-molyneux-on-underestimating-mobile-monetization-the-biggest-mistake-ive-made-in-the-last-20-years
25. SimEarth: https://en.wikipedia.org/wiki/SimEarth
26. Black & White 2, Bekehren durch Bauen: https://nexusmods.com/blackandwhite2/mods/311
27. Royal Match Umsatz: https://appmagic.rocks/blog/dream-games-3-billion und Meta-Ebenen: https://gamerefinery.com/casual-match3-meta-layer-new-winning-formula
28. Before We Leave: https://apptrigger.com/2020/05/01/before-we-leave-review/
29. Dungeon Keeper Mobile: https://www.engadget.com/2014-07-02-uk-regulator-rules-free-dungeon-keeper-ad-was-misleading.html
30. Two Dots: https://en.wikipedia.org/wiki/Two_Dots_(video_game)
31. Infinite Craft: https://en.wikipedia.org/wiki/Infinite_Craft
32. Timberborn: https://www.pcgamer.com/games/city-builder/beaver-themed-city-builder-timberborn-has-gnawed-its-way-out-of-early-access-and-surprise-it-has-factorio-style-automation-now
33. Threes: https://www.pocketgamer.biz/feature/58813/fighting-the-monsters-the-making-of-threes/
