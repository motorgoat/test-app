# Würfelreiche: Strategie-Ausbau für PC (Konzept)

Stand: 5. November 2026. Baut auf „God does play dice!“ auf (gleicher Würfel, gleiche Drehmechanik,
gleicher Grafikstil), wird aber ein eigenes, viel größeres Projekt in einem eigenen Ordner und Chat.
Arbeitstitel: **Würfelreiche**.

## Kernidee
Ein Strategiespiel auf einem 3×3×3-Zauberwürfel. Jedes Feld der Oberfläche ist ein **Grundstück**.
Jeder Spieler besitzt eine Seite des Würfels. Man baut auf seinen Grundstücken Gebäude und Äcker,
sammelt Ressourcen und steigt in Zeitaltern auf. Mit einer **Drehung** schiebt man eigene Grundstücke
an die Grenze des Gegners (Angriff) oder holt sich eines seiner Grundstücke auf die eigene Seite.

## Warum der Würfel dafür passt
- **Hauptstadt ist sicher:** Das Mittelfeld jeder Seite bewegt sich beim Drehen nie. Dort steht die
  Hauptstadt (das Rathaus) jedes Spielers.
- **Kanten und Ecken sind Front:** Diese Felder wandern beim Drehen auf andere Seiten. Eckfelder
  grenzen an drei Seiten gleichzeitig: wertvoll, aber am stärksten umkämpft.
- **Spielerzahl:** 2 Spieler auf gegenüberliegenden Seiten (4 neutrale Seiten dazwischen) oder bis
  zu 6 Spieler, eine Seite pro Spieler.
- **Eine Drehung ist ein starker, seltener Zug:** Sie verändert die ganze Landkarte.

## Ablauf (Empfehlung: rundenbasiert)
Echtzeit (wie Age of Empires) und Drehen beißen sich: Was passiert mit Einheiten mitten im Kampf,
wenn sich ihre Reihe wegdreht? Deshalb rundenbasiert oder halb-rundenbasiert, eher wie
Civilization/Polytopia:

1. **Wirtschaft:** Ressourcen der eigenen Grundstücke einsammeln, bauen, Einheiten ausbilden.
2. **Drehung:** Höchstens eine Drehung pro Runde. Sie kostet etwas, z. B. „Glaube/Macht“ oder eine
   Abklingzeit von einigen Runden.
3. **Kampf:** Wo sich nach der Drehung Grundstücke verschiedener Besitzer berühren, wird gekämpft
   (Einheiten auf den Grundstücken gegeneinander, Mauern/Türme verteidigen).
4. **Besitzwechsel:** Wer ein Grundstück erobert, übernimmt es samt (beschädigten) Gebäuden.

Spätere Option: Echtzeit-Wirtschaft mit pausierten Kampf-/Drehphasen.

## Grundstücke (Felder)
- Jedes Grundstück hat ein Bau-Raster, z. B. 6×6 oder 8×8 Kacheln.
- Jedes Grundstück hat eine **Landschaft** mit eigenen Ressourcen:

| Landschaft | Ressourcen |
|---|---|
| Wiese | Nahrung (Acker, Weide) |
| Wald | Holz |
| Berg/Fels | Stein, Erz |
| Fluss/See | Nahrung (Fischer) und schnellere Wege |
| Wüste/Sand | wenig, dafür seltene Ressource (z. B. Gold) |

- Die Landschaften werden beim Spielstart zufällig, aber fair verteilt.
- Gebäude (Beispiele, nach Zeitalter freigeschaltet): Rathaus, Haus, Acker, Holzfäller, Steinbruch,
  Mine, Lager, Markt, Kaserne, Schießstand, Stall, Mauer, Turm, Tempel, Werkstatt.
- Die Gebäude in einem Grundstück bestimmen, wie stark es verteidigt ist und was es pro Runde bringt.

## Zeitalter
Wie im aktuellen Spiel: Urzeit, Steinzeit, Antike, Mittelalter, Neuzeit, Industriezeitalter, Moderne.
- Aufstieg kostet Ressourcen und braucht bestimmte Gebäude.
- Jedes Zeitalter schaltet neue Gebäude und Einheiten frei und ändert das Aussehen.
- Ein Zeitalter-Aufstieg könnte eine zusätzliche Drehung freischalten.

## Kamera und Zoom
- **Würfelansicht** (weit weg): Wie jetzt. Felder zeigen vereinfacht, was darauf steht, plus
  Besitzerfarbe am Rand.
- **Grundstücksansicht** (nah dran): Hineinzoomen bis auf ein Grundstück, dort Gebäude setzen,
  Acker anlegen, Einheiten sehen.
- Stufenloser Übergang mit Mausrad (PC) bzw. Zwei-Finger-Zoom.
- Technik: Detailstufen (weit weg einfache Modelle, nah die Details), MultiMesh für viele gleiche
  Objekte (Bäume, Ackerfurchen, Einheiten), damit es flüssig bleibt.

## Gegner
- **Zuerst:** Computergegner (KI), lokal. Er baut, sammelt und dreht nach einfachen Zielen
  (Grenze sichern, schwache Grundstücke angreifen).
- **Später:** Online-Mehrspieler, rundenbasiert und asynchron (jeder zieht, wenn er Zeit hat).
  Das braucht Server, Konten und Synchronisation.

## Offene Fragen
- Was passiert mit Einheiten, die auf einem Grundstück stehen, das weggedreht wird?
  Vorschlag: Sie drehen mit und kämpfen auf der neuen Seite.
- Darf man auch Reihen drehen, die nur fremde Grundstücke enthalten?
- Wie verhindert man, dass ein Spieler mit einer Drehung alles gewinnt (Abklingzeit, Kosten,
  Mauern, die eine Drehung blockieren)?
- Neutrale Seiten: Barbaren, freie Rohstoffe, Wunder in der Mitte?
- Siegbedingung: Hauptstadt des Gegners erobern, eine Anzahl Grundstücke halten, ein Wunder bauen
  oder alle 6 Mittelfelder kontrollieren?
- Bleibt das Handyspiel ein eigener Modus? (Empfehlung: ja, gleiche Technik.)

## Ausbaustufen und grobe Aufwände

| Stufe | Inhalt | Aufwand (grob) |
|---|---|---|
| M1 Zoom-Prototyp | In ein Grundstück zoomen, 3–4 Gebäude, 2–3 Ressourcen | 2–4 Wochen |
| M2 Gegner und Drehkampf | Rundenbasiert gegen einen Computergegner, Kampf beim Drehen | 2–4 Monate |
| M3 Online | Rundenbasierter Online-Mehrspieler | +3–6 Monate |
| M4 Echtzeit | Echtzeit-RTS mit Einheiten und Mehrspieler | 1–2+ Jahre, eher im Team |

Zeitfresser: Grafik, Balancing, ein guter Computergegner.

## Was vom aktuellen Spiel wiederverwendet wird
- `GameState`: Regeln getrennt von der Grafik. `FieldData` wird um Grundstück, Gebäude, Besitzer
  und Einheiten erweitert.
- `World`: Würfel, Drehung mit Einrasten, Abbrechen, Weiterdrehen am Rand.
- `CameraRig`, `Models`, `FieldView`, `Style`, die Icons und der Grafikstil.
- CI: Regeltests, Probelauf, Screenshot-Tour, Exporte (Windows, Linux, Android).

Den Start-Prompt für den eigenen Chat gibt es in [STRATEGIE_PROMPT.md](STRATEGIE_PROMPT.md).
