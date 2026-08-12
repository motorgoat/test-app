# Auftrag 02 — Projektilphysik

**Deine Dateien (NUR diese):**
- `src/ReplicatedStorage/Shared/Ballistics.luau`
- `src/ServerScriptService/ProjectileServer.luau`
- `src/ReplicatedStorage/Shared/Config/Ballistics.luau`

**Pflichtlektüre:** `ARCHITECTURE.md`, `CLAUDE.md`, `auftraege/README.md` (Protokoll).

## Mission

Flugbahn, Wind, Abpraller, Gewicht — Physik, die sich fett anfühlt und
EXAKT mit der Vorschau übereinstimmt (Parität ist heilig).

## Anforderungen

- **Wind:** horizontaler Beschleunigungsterm als Parameter der puren
  Ballistics-Funktionen (positionAtTime/step/trajectoryPoints erweitern —
  Signaturen mit den Elementen 03 (Vorschau nutzt dieselben Funktionen) über
  ARCHITECTURE.md abstimmen). Wirkung skaliert mit windFactor der Waffe
  (WeaponDefs). Wind kommt pro Runde vom MatchServer.
- **Abpraller:** Raycast-Reflexion mit Restitution und
  Mindest-Restgeschwindigkeit (Granaten hoppeln glaubwürdig aus, kein
  ewiges Zittern), Zündtimer läuft weiter.
- **Gewichtsklassen:** leicht = windanfällig + höhere Restitution,
  schwer = stur; als Parameter, nicht als Codepfade.
- **Cluster-fähig:** mehrere gleichzeitige Projektile mit shotId-Verwaltung;
  WeaponServer kann Kind-Projektile nachschieben (Seam: fire-API, die auch
  Startposition + Startgeschwindigkeit direkt akzeptiert).
- **2.5D:** Simulation in der X/Y-Ebene, z bleibt 0 (Richtungen vorher auf
  die Ebene projizieren/validieren).
- Heartbeat+Raycast-Simulation, MaxFlightTime/KillY, Server-Referenz-Part —
  bestehende Muster beibehalten. Keine deprecated APIs.

## Wonach der Kritiker im Testplay urteilt

Bogen hoch gegen den Wind, Granate einen Hang hinunterhoppeln lassen,
flacher Direktschuss: Stimmen Vorschau und Realität exakt überein? Fühlt
sich die Granate schwer, die Bazooka windgetrieben an? Wirken Abpraller
physisch statt arcade-billig?


## Abnahme (Loop bis bestanden)

Kritiker-Protokoll siehe README.md in diesem Ordner: frischer Kritiker pro
Runde, echtes Testplay via Studio-MCP, Blindvergleich gegen Worms Armageddon,
binäres Urteil, EINE größte Lücke. Keine feste Rundenzahl — es gibt keine
letzte Runde außer der bestandenen. Commit nach jeder bestandenen Runde.
