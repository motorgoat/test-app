# Gauntlet-Handoff — Stand nach Cloud-Session (2026-08-11)

## Aktueller Stand
Meilenstein-1-Code ist vollständig gebaut und zwei Code-Review-Runden durchlaufen
(Kritiker 1 fand einen atan2-Bug, gefixt in 18c198e; Kritiker 2: keine blockierende
Lücke auf Code-Ebene). **Kein Kritiker hat das laufende Spiel gesehen — die Messlatte
ist NICHT bestanden.** Das passiert jetzt hier, lokal, mit Studio-MCP.

## Vorbedingung (früh prüfen!)
Testplay starten und einen Screenshot zurückbekommen. Wenn das nicht funktioniert,
STOPP — ohne Screenshots bewertet der Kritiker Text und der Loop ist wertlos.

## Zwei Beobachtungspunkte aus den Code-Reviews fürs erste Testplay
1. Explosions-Sound `rbxassetid://165969964` (Config.luau): spielt er unter den
   Audio-Privacy-Regeln ab? Ein stummer Einschlag reißt die Messlatte.
2. Latenz zwischen Loslassen und Projektil-Erscheinen (ProjectileFired-Roundtrip):
   in Studio-Solo ≈ 0 ms, trotzdem prüfen, ob der Mündungs-Kick die Lücke trägt.

## Der Gauntlet-Prompt (an Claude Code lokal geben)

```
MISSION
Führe für "Blow Up Your Animal Friends" (dieses Rojo-Projekt, bereits gebaut)
den Game-Feel-Gauntlet durch. Es zählt genau eine Sache — das Schießen muss
sich exzellent anfühlen.

DIE MESSLATTE
Referenzen: Worms Armageddon und ShellShock Live (Lesbarkeit der Flugbahn,
Gewicht des Einschlags, Befriedigung des Treffers). Bestanden, wenn ein
fremder Spieler nach drei Schüssen ohne Erklärung versteht, wie er zielt,
und beim vierten Schuss lächeln würde. Nichts darunter zählt.

UMFANG
Terrain, Zielen im Stand, Projektil, Krater. Ein Spieler. Kein Multiplayer,
kein Rundensystem, keine Phasenlogik, keine Waffen, keine Gegner, keine Menüs.

ROLLEN
Du bist Orchestrator, du implementierst nichts selbst.
- Builder-Agents schließen Lücken.
- Für jede Bewertung ein FRISCHER Kritiker-Agent: bekommt Mission, Messlatte
  und das laufende Spiel — niemals Builder-Historie oder -Zusammenfassungen.
- Der Kritiker prüft das ECHTE Spiel: Testplay starten, Screenshots aufnehmen,
  Output-Logs lesen. Er bewertet nie Code-Beschreibungen.
- Urteil binär: bestanden oder die EINE größte Lücke. Keine Listen, keine
  Punktzahlen, kein "sieht gut aus, könnte besser sein".

LOOP
Kritiker prüft, Builder schließt die größte Lücke, nächster frischer Kritiker.
Kein Rundenlimit. Git-Commit nach jeder bestandenen Runde.

VERBOTEN
- Fertig melden, ohne dass ein Kritiker das laufende Spiel gesehen hat.
- Zusätzliche Features als Fortschritt ausgeben.
- Vorgriff auf Phasenlogik oder Multiplayer.

TECHNISCHE LEITPLANKEN
- Luau, Rojo. Terrainänderungen nur serverseitig via Terrain:FillBall.
- Client sendet nur Richtung und Stärke; Server validiert und simuliert.
- Keine deprecated APIs; bei Unsicherheit create.roblox.com/docs prüfen.
- Alle Zahlenwerte in Config.luau.

Bei fundamentaler Unklarheit fragen. Bei Geschmacksfragen entscheidet der
Kritiker.
```
