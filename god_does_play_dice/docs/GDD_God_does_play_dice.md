# God does play dice! – Spielkonzept und Übergabe an Godot

Stand: 3. November 2026 · Autor der Spielidee: Philipp Golob · Prototyp: Browser (Three.js), Version „Kanten-Prototyp 0.5“

---

## 0. Auftrag an Claude Code

Baue dieses Spiel in **Godot 4 (GDScript)** neu auf. Grundlage sind dieses Dokument und der Browser-Prototyp:

- `prototyp_referenz.html` lässt sich im Browser öffnen und spielen. Es ist eine einzige Datei mit Three.js r128.
- `prototyp_spiellogik.js` enthält den lesbaren Kern der Spielregeln aus dem Prototyp.

**Wichtig:**
- **Nicht 1:1 portieren.** Der Prototyp ist über viele Regeländerungen gewachsen, dabei ist Patch auf Patch entstanden. Er hat tote Codepfade (alte Popup-Menüs, alte Arbeiter-, Haus- und Hunger-Logik) und Funktionen, die später überschrieben werden. Maßgeblich ist dieses Dokument. Den Code nur nachschlagen für die Würfel-Mathematik, für die Drehanimation und um zu sehen, wie sich etwas anfühlen soll.
- **Mit wenig Regeln anfangen.** Das Spiel soll zuerst übersichtlich sein. Punkte mit **[OFFEN]** sind noch nicht entschieden: Dort die einfachste Variante umsetzen und als Konstante oder Option einstellbar lassen.
- **Handy zuerst.** Alles muss mit einem Finger bedienbar und ohne Erklärung verständlich sein.
- Alle Zahlen gehören in **eine zentrale Balancing-Datei** (Resource oder Dictionary), damit man sie ohne Code-Suche ändern kann.

---

## 1. Idee in einem Satz

Ein Zauberwürfel ist die Spielwelt: Jede der 6 Seiten ist das Land eines Spielers. Man baut seine Felder aus, kauft und erobert Felder und darf ab und zu eine Scheibe des Würfels drehen. Dadurch wandern Felder samt Ausbau, Straßen und Rohstoffen auf andere Seiten, also zu anderen Besitzern.

**Look:** kleine Diorama-Welt im Stil von Lego Voyagers, aber ohne Lego. Low-Poly, freundliche Farben, kleine Figuren und Hütten.

---

## 2. Die Welt

- **Würfel:** 3×3×3. Jede Seite hat 9 Felder, insgesamt 54.
- **Zentrum:** Das Mittelfeld jeder Seite ist das Zentrum (die Basis) eines Spielers. Es dreht sich nie mit, es bleibt immer auf seiner Seite.
- **Spieler:** Du bist Gelb. Gegen 1–5 KI-Länder (Rot, Blau, Orange, Lila, Weiß). Seiten ohne Spieler sind neutral.
- **Gelände pro Feld** (zufällig verteilt):

| Gelände | Rohstoff | Gewicht beim Würfeln |
|---|---|---|
| Wiese (Acker) | Nahrung | 30 |
| Wald | Holz | 13 |
| See (ganzes Feld ist Wasser) | Nahrung | 12 |
| Berg | Stein | 14 |
| Goldmine | Gold | 8 |

- **Garantie:** Jede Spielerseite hat mindestens 1 See, 1 Goldmine, 1 Wald und 1 Berg.
- **Bodenfarben:** Jeder Rohstoff hat eine eigene Bodenfarbe und ein klar erkennbares Modell. Gold: sandgelb mit glänzenden Goldklumpen. Stein: grau mit Felsen und Schneespitze. Wald: Bäume. See: blau. Wiese: hellgrün.

---

## 3. Ressourcen

- **Holz, Stein, Nahrung, Gold.** Mehr nicht. Eisen und Lehm wurden bewusst gestrichen.
- **Bewohner** (freie Arbeitskräfte) und **Krieger** werden extra gezählt.
- **Startbestand:** 4 Holz, 0 Stein, 2 Nahrung, 6 Gold, 2 Bewohner.

---

## 4. Zeit

- **Echtzeit:** Alle **8 Sekunden** ein Takt. Es gibt Pause und „⏭“ (Takt sofort beenden).
- **Am Ende jedes Takts:** Erträge, dann Krieger aus der Kaserne, dann KI-Züge, dann alle vorgemerkten Drehungen (siehe Kapitel 9).
- **[OFFEN]** Für Multiplayer empfohlen: gleichzeitige Runden mit Zeitlimit statt echter Echtzeit. Das ist einfacher zu synchronisieren und passt zu den Drehungen am Rundenende.

---

## 5. Wirtschaft (Kern-Kreislauf)

**Gold** ist die Hauptwährung und kommt automatisch:
- **+1 Gold pro Takt je Zentrum-Stufe** (Zelt 1 … Werkstatt 5)
- **+1 Gold pro Takt je Feld-Stufe** auf allen eigenen Feldern

**Mit Gold kauft man:**
1. **Bewohner:** Zentrum antippen. Preis: 4 Gold, alle 3 Käufe +1 Gold. Bewohner kommen nie von selbst.
2. **Feld-Ausbau:** eigenes Feld antippen, siehe Kapitel 6.
3. **Freie Felder:** ein angrenzendes neutrales Feld antippen, siehe Kapitel 7.
4. Zusammen mit Holz und Stein den **Ausbau des Zentrums**, siehe Kapitel 8.

**Rohstoffe** (Holz, Stein, Nahrung) kommen nur aus ausgebauten Feldern.

**Nahrung** braucht man nur für Krieger. Es gibt keinen Hunger und kein Bevölkerungslimit.

---

## 6. Felder ausbauen (Stufe 0–4)

- Jedes Feld hat 4 Viertel. Pro Stufe wird ein Viertel bewirtschaftet, man sieht also 1–4 Hütten (Holzfäller, Steinbruch, Fischer, Acker, Mine).
- **Ausbau auf Stufe L kostet:** 1 freien Bewohner (er arbeitet dann dort) + Gold + Holz.

| Stufe | Gold | Holz |
|---|---|---|
| 1 | 3 | 2 |
| 2 | 6 | 4 |
| 3 | 10 | 6 |
| 4 | 15 | 8 |

- **Grenze:** Ein Feld kann nie höher ausgebaut sein als die Stufe des eigenen Zentrums (Zelt = 1 … Kaserne = 4).
- **Ertrag pro Takt:** Stufe × Rohstoff des Felds (mit verbundener Straße ×2), dazu Stufe × Gold.
- Die Stufe gehört zum **Feld**: Dreht sich das Feld weg, nimmt es seinen Ausbau mit.

---

## 7. Besitz und Gebiet

- **Besitz hängt am Platz, nicht am Feld.** Dreht sich ein fremdes Feld auf deine Seite, gehört es dir, mit Ausbau und Straßenstücken. Dein weggedrehtes Feld gehört dem neuen Platz. Krieger auf einem Feld, das den Besitzer wechselt, gehen heim, Mauern verschwinden.
- **Start:** Im Prototyp gehören dir alle 8 Felder deiner Seite von Anfang an.
  - **[OFFEN]** Empfehlung: Man startet nur mit dem Zentrum und kauft die Felder der eigenen Seite einzeln (billig). Ein gekaufter Platz bleibt dir auch nach dem Drehen. Das macht den Anfang verständlicher, weil man sich Feld für Feld ausbreitet.
- **Freies Feld kaufen:** Es muss an dein Gebiet oder dein Zentrum grenzen. Preis: 6 Gold, jedes weitere gekaufte Feld +3. Über die Würfelkante erst ab Zentrum-Stufe 2.
- **Fremde Felder** kann man nur mit Kriegern erobern, siehe Kapitel 11.
- **Gebiet** (zählt für den Sieg): alle eigenen Felder ohne Zentrum.

---

## 8. Zentrum ausbauen (Stufen 1–5)

| Stufe | Name | Kosten | Bringt |
|---|---|---|---|
| 1 | Zelt | Start | +1 Gold/Takt, Felder bis Stufe 1, 1 Straße |
| 2 | Haus | 15 Holz, 5 Stein, 15 Gold | +1 Gold, Felder bis 2, über die Würfelkante |
| 3 | Marktplatz | 25 Holz, 15 Stein, 30 Gold | +1 Gold, Felder bis 3, Tausch 3:1 |
| 4 | Kaserne | 35 Holz, 30 Stein, 50 Gold | +1 Gold, Felder bis 4, 1 Krieger pro Takt (kostet 1 Nahrung) |
| 5 | Werkstatt | 45 Holz, 45 Stein, 80 Gold | +1 Gold, Krieger Stärke +1, Mauern |

- **Jeder Ausbau bringt 1 Drehung** und 1 weitere Straße.
- **Wartezeit:** Zwischen zwei Ausbauten müssen mindestens **12 Takte** liegen, damit niemand zu schnell dreht.
- **Der Ausbau-Knopf erscheint erst, wenn der Ausbau möglich ist.** Dann leuchtet er golden und es kommt ein kurzer Hinweis.
- **Optik des Zentrums:** Stufe 1 ist ein Zelt mit Lagerfeuer und Fahne, keine fertigen Wege. Ab Stufe 3 gibt es einen gepflasterten Platz, danach Turm bzw. Glasturm.

---

## 9. Drehen (das Herzstück)

- **Drehungen sind selten:** 1 pro Zentrum-Ausbau.
- **Alle 9 Scheiben** (3 Achsen × 3 Ebenen) sind drehbar, also auch die Mittelscheiben. **Die 6 Zentren drehen nie mit**, auch nicht bei Mittelscheiben.
- **Bedienung:**
  1. Knopf „Drehung vormerken“ öffnet den Drehmodus. Die Zeit steht, solange man plant.
  2. Um die vordere Seite erscheinen **12 Pfeile**: oberste, mittlere und unterste Reihe je ←/→, linke, mittlere und rechte Spalte je ↑/↓.
  3. Ein Pfeil dreht die Scheibe als Vorschau um 90°, nochmal tippen dreht weiter. Angezeigt wird, wie sich der eigene Ertrag ändern würde.
  4. „Vormerken“ übernimmt die Drehung, „Zurück“ verwirft sie. Eine vorgemerkte Drehung kann man zurücknehmen, dann bekommt man sie wieder gutgeschrieben.
- **Ausführung:** **Alle vorgemerkten Drehungen** aller Spieler (auch der KI) passieren **am Ende des Takts nacheinander** mit Animation. Die betroffene Scheibe wird kurz in der Spielerfarbe markiert.
- **Folgen einer Drehung:** Besitz nach Platz (Kapitel 7), Straßen können reißen oder sich neu verbinden (Kapitel 10).

---

## 10. Straßen

- Eine Straße führt **durchgehend über eine Kante** zwischen zwei Feldern. Technisch sind das zwei Hälften, auf jedem Feld eine, und jede Hälfte gehört zu ihrem Feld.
- **Selten:** **1 Straße pro Zentrum-Stufe**, also maximal 5 im ganzen Spiel. Kosten: 3 Holz.
- Eine Seite der Straße muss dir gehören. Über die Würfelkante erst ab Stufe 2.
- **Verbunden** sind zwei Felder nur, wenn beide Hälften an derselben Kante liegen. Beim Drehen wandern die Hälften mit ihren Feldern und können **auseinanderreißen**. Passen sie nach einer späteren Drehung wieder zusammen, ist die Straße wieder verbunden.
- **Bonus:** Ein Feld mit verbundener Straße bringt **doppelten Rohstoff-Ertrag**.
- **Straßennetz:** vom Zentrum aus über verbundene eigene Straßen. Krieger erreichen alle Felder im Netz und das Feld am Ende jeder eigenen Straße.
- **Darstellung:** Hat ein Feld mehrere Straßen, laufen sie in der Feldmitte zusammen. Eine unverbundene Hälfte ist heller gezeichnet.
- **[OFFEN]** Philipps Idee: Straßen werden zufällig fest verteilt und sind gar nicht oder nur sehr teuer baubar. Das Drehen wird dann zum Puzzle, mit dem man Straßen verbindet oder dem Gegner zerreißt.

---

## 11. Krieger, Angriff, Mauern

- Krieger kommen aus der Kaserne: 1 pro Takt, solange Nahrung da ist (je 1 Nahrung). Sie warten im Zentrum.
- **Bewegung nur über Straßen.**
- **Angriff:** Ein gegnerisches Feld antippen, das über eine eigene Straße erreichbar ist, und zwar mit der Karte „Krieger“. Dann greifen **alle bereiten Krieger** an.
  - Angriff = Krieger × Stärke. Stärke ist 1, mit Werkstatt 2.
  - Verteidigung = Krieger dort × deren Stärke + Feldstufe × 0,5 + 3 bei Mauer.
  - **Sieg, wenn Angriff > Verteidigung.** Das Feld gehört dann dem Angreifer, mit Ausbau. Verluste: aufrunden(Verteidigung ÷ eigene Stärke), die übrigen Krieger bleiben auf dem Feld.
  - Niederlage: Alle Angreifer sind weg. Der Verteidiger verliert abrunden(Angriff ÷ seine Stärke) Krieger.
- Zentren kann man nicht erobern.
- **Mauer** (ab Werkstatt): +3 Verteidigung. Kosten 3 Stein, jede weitere 2 Stein mehr.
- **Sichtbarkeit:** Wie viele Krieger und Bewohner ein Gegner auf einem Feld hat, sieht man nicht.

---

## 12. Markt

Ab Marktplatz tauscht man Rohstoffe 3:1: 3 von einem Rohstoff gegen 1 von einem anderen, über zwei Auswahllisten und einen Knopf.

---

## 13. Sieg

- **Prototyp:** Wer zuerst **24 Felder** besitzt, gewinnt.
- **[OFFEN, wichtig]** Mit seltenen Straßen und Kriegern nur über Straßen sind 24 Felder kaum erreichbar. In den Tests blieben die KIs bei 12–15 Feldern hängen. Vorschläge:
  - **(a)** Die meisten Felder nach X Minuten.
  - **(b)** Wer zuerst Zentrum-Stufe 5 hat und Y Felder besitzt.
  - **(c)** Punkte aus Felder × Stufen.

---

## 14. KI (einfach, regelbasiert)

**Jeden Takt, in dieser Reihenfolge:**
1. Zentrum ausbauen, wenn möglich.
2. Bewohner kaufen, wenn keiner frei ist. Dabei ungefähr die Hälfte des Golds für den nächsten Ausbau zurückhalten.
3. Bis zu 2 Feld-Ausbauten. Bevorzugt werden Felder mit dem Rohstoff, der für den nächsten Zentrum-Ausbau fehlt, und Felder mit Straße.
4. Ein angrenzendes freies Feld kaufen, wenn genug Gold übrig ist.
5. Ab Marktplatz Überschuss tauschen, in das, was für den nächsten Ausbau fehlt.
6. Straße bauen, wenn noch eine frei ist, bevorzugt zu gegnerischen Feldern.
7. Angreifen, wenn sicher stärker als die Verteidigung.
8. **Drehung:** jede mögliche Drehung simulieren (9 Scheiben × 3 Richtungen) und bewerten: eigener Ertrag minus 0,7 × Ertrag des menschlichen Spielers. Die beste vormerken, wenn sie klar besser ist als nicht zu drehen.

---

## 15. Bedienung und Oberfläche

**Grundsatz:** minimalistisch. Keine Popups mitten im Bild, keine blauen Markierungskacheln, keine Zahlenwolken, die alles verdecken.

**Antippen:**
- **Feld antippen** wählt es aus: Es bekommt einen weißen Rahmen, und unten erscheint ein **Auswahl-Kasten** mit Name, Stufe, Ertrag und **einem großen Knopf** („Ausbauen auf Stufe 2 · 👤1 6🪙 4🪵“ oder „Feld kaufen · 9🪙“). Geht es nicht, ist der Knopf grau und darunter steht der Grund. Dasselbe Feld nochmal antippen = Knopf drücken.
- **Zentrum antippen:** Der Kasten zeigt „+1 Bewohner kaufen“.

**Feld-Schild:** Auf jedem Feld steht nur das Rohstoff-Symbol, dazu Stufen-Punkte (●●○○) und ein kleiner grüner Punkt: ↑ = ausbauen möglich, + = kaufen möglich.

**Weitere Rückmeldung:**
- Kurze farbige Blase direkt am Feld: grün bei Erfolg, rot mit Grund.
- Am Takt-Ende kurz „+2 Holz“ über den Feldern.

**Oben:** eine Leiste mit Takt, Holz, Stein, Nahrung, Gold, freien Bewohnern, Kriegern und Gold pro Takt. Daneben die Spielerfarben als Punkte; Antippen dreht die Ansicht zu diesem Land.

**Unten bzw. an der Seite:**
- Modus-Karten: **Ausbauen** (Standard), **Straße (n übrig)**, **Krieger**, **Mauer** (ab Werkstatt).
- Zentrum-Info, Ausbau-Knopf (nur wenn möglich), Tausch, „Drehung vormerken (n)“.
- Pause, Fortschrittsbalken des Takts und ⏭.
- Regeln, Neu starten, Spieler.

**Kamera:**
- Ziehen dreht die Ansicht frei.
- **Tipp neben den Würfel** dreht die Ansicht um eine Seite in diese Richtung.
- Mausrad oder zwei Finger zoomen. Mittlere Maustaste oder zwei Finger hoch/runter heben bzw. senken die Kamera.
- Rechtsklick oder langes Drücken zeigt die Feldinfo.

**Layout:**
- **Handy:** Würfel groß in der Mitte, oben eine schmale Leiste, unten Kasten, Status, Karten und Knöpfe. Karten wischbar.
- **PC:** Karten links, Zentrum und Ausbau rechts.

**Code-Konvention aus dem Web-Prototyp:** Alle CSS-Klassen und IDs haben das Präfix `iIT_`. In Godot nicht nötig, nur falls wieder eine Web-Version entsteht.

---

## 16. Technische Hinweise für Godot

**Datenmodell, getrennt von der Darstellung:**
- `Field`: id, `p: Vector3i` (Position im 3×3×3-Gitter, Werte −1/0/1), `n: Vector3i` (Normale = Seite), terrain, owner, `level` 0–4, troops, wall, `roads: Array[{dir: Vector3i, owner}]`, `is_center`.
- Die 54 Felder liegen auf den Oberflächen der 26 Würfelchen. Ein Zentrum hat genau 1 Koordinate ≠ 0.
- `GameState`: Felder, Spieler (Inventar, Stufe, Bewohner, Krieger, Drehungen, Kaufzähler, `upgrade_tick`), `pos_owner: Dictionary` (Platz-Schlüssel `p|n` → Besitzer), Drehwarteschlange.

**Drehung einer Scheibe** (Achse a ∈ {0,1,2}, Ebene ∈ {−1,0,1}, Richtung d = ±1): Für jedes Feld mit `p[a] == Ebene` und **nicht** Zentrum: `p = rv(p,a,d)`, `n = rv(n,a,d)`, Straßenrichtungen `dir = rv(dir,a,d)`. Danach den Besitz nach Platz neu setzen.

```
rv(v,a,d):
  a==0: d>0 ? (x,-z,y) : (x,z,-y)
  a==1: d>0 ? (z,y,-x) : (-z,y,x)
  a==2: d>0 ? (-y,x,z) : (y,-x,z)
```

Positives d entspricht +90° um die positive Achse (rechte Hand). Die Animation dreht die Würfelchen der Scheibe (ohne Zentrum-Würfelchen) in einem Pivot-Knoten und rastet danach ein.

**Nachbarn eines Felds:**
- Auf derselben Seite: p ± 1 in den beiden Achsen ≠ Normale.
- Über die Würfelkante: Wäre p außerhalb (|p[a]| > 1), ist der Nachbar das Feld an derselben Position p mit Normale = Einheitsvektor in Richtung a.

**Richtung von Feld f zum Nachbarn q:** gleiche Seite → `q.p − f.p`, über die Kante → `q.n`. Eine Straße ist verbunden, wenn f eine Hälfte mit `dir = Richtung(f→q)` hat und q eine mit `dir = Richtung(q→f)`.

**KI-Bewertung von Drehungen:** auf einer Kopie des GameState simulieren, nicht auf den Szenen-Knoten.

**Empfohlene Szenen:**
- `World` (Würfel, Felder, Kamera)
- `FieldView` (Boden, Rohstoffmodell, Hütten je Stufe, Straßenarme, Figuren)
- `UI` (CanvasLayer: TopBar, SelectionPanel, ModeCards, CenterPanel, RotateArrows, Toasts)
- `GameState` (Autoload, reine Logik)
- `AI`
- `Balance` (Resource mit allen Zahlen)

---

## 17. Bekannte Probleme aus den Tests

- **Zu viel Gold später:** Ab etwa Takt 50 hat die KI über 1000 Gold, weil jede Feld-Stufe Gold bringt. Das Gold pro Feld-Stufe sollte halbiert oder gedeckelt werden.
- **Kaum Eroberungen:** Die KIs erobern wegen der seltenen Straßen fast nie etwas. Hängt an der Siegbedingung und an der Straßen-Idee (Kapitel 10 und 13).
- **Zäher Anfang:** Nach 2 Ausbauten ist alles leer. Eventuell mehr Startgold.
- **Zu viele Regeln:** Der Prototyp war unübersichtlich, weil zu viele Systeme gleichzeitig da waren. In Godot erst den Kern bauen und testen: Gold, Felder ausbauen, Felder kaufen, Zentrum ausbauen, Drehen. Straßen, Krieger und Markt erst danach.

---

## 18. Entwicklung der Idee (zur Einordnung)

1. Erste Version: Häuser bauen und Bewohner zuordnen, runden-basiert, 3 Phasen (Abrechnung, Zuordnen und Bauen, Drehen).
2. Kanten-Modell: Arbeiter auf Felder, Straßen an Kanten, Krieger, Siedler/Age-of-Empires-Mischung.
3. Von Runden zu Echtzeit gewechselt, Drehungen am Takt-Ende.
4. Wirtschaft 0.5 (aktuell): Gold als Hauptwährung, Feld-Stufen, Felder kaufen, Bewohner kaufen. Angelehnt an **Polytopia** (eine Währung, wenige Regeln, gut am Handy).
