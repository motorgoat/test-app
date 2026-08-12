# Auftrag 01 — Zerstörbares Voxel-Terrain

**Deine Dateien (NUR diese):**
- `src/ServerScriptService/TerrainWorld.luau`
- `src/ReplicatedStorage/Shared/Config/Terrain.luau`

**Pflichtlektüre:** `ARCHITECTURE.md`, `CLAUDE.md`, `auftraege/README.md` (Protokoll).

## Mission

Ersetze die v11-Insel durch den 2.5D-Spielstreifen und gib Kratern den
Charakter eines echten Einschlags. Messlatte: Terrain-Zerstörung, die sich im
Blindvergleich mit Worms Armageddon behauptet — Krater dürfen sich NICHT
anfühlen wie eine Kugel, die aus dem Boden verschwindet.

## Anforderungen

- **Spielstreifen:** hügelige Landschaft mit Überhängen, Plateaus, Senken und
  mindestens einem markanten Landmark zwischen den Wänden (z = ±15, Tiefe des
  Streifens ≈ 24 studs), Wasser darunter (Wasserlinie = Todeszone),
  Materialschichten Gras → Erde → Fels, die Krater sichtbar freilegen.
  Seed-Variation: jedes Match sieht anders aus, aber immer spielbar
  (begehbare Fläche, erreichbare Spawns).
- **Krater mit Charakter:** `carveCrater(position, radius)` = unregelmäßige
  Form aus mehreren versetzten FillBalls (Radius-Jitter), verkohlter Rand
  (dunkles Material als Ring: z. B. CrackedLava/Basalt/Slate abgestuft),
  Parameter pro Waffe über den radius hinaus in Config/Terrain
  (Jitter-Anzahl, Randdicke). CraterCarved-Signal beibehalten.
- **`resetTerrain()`** generiert idempotent neu — `Terrain:CopyRegion` bleibt
  VERBOTEN (crashte den Live-Server).
- **`getSpawnPoints(count)`**: verteilte, flache, begehbare Standorte auf der
  Oberfläche (Mindestabstand, kein Spawn über Wasser oder am Steilhang).
- ServerBootStep-Marks beibehalten (BootHud-Diagnose).

## Wonach der Kritiker im Testplay urteilt

Mehrere Einschläge nebeneinander: Sehen die Krater organisch aus (Rand,
Schichten, Unregelmäßigkeit)? Bleibt zerklüftetes Terrain begehbar und
lesbar? Fühlt sich die Landschaft nach einem Ort an, um den man kämpfen will?


## Abnahme (Loop bis bestanden)

Kritiker-Protokoll siehe README.md in diesem Ordner: frischer Kritiker pro
Runde, echtes Testplay via Studio-MCP, Blindvergleich gegen Worms Armageddon,
binäres Urteil, EINE größte Lücke. Keine feste Rundenzahl — es gibt keine
letzte Runde außer der bestandenen. Commit nach jeder bestandenen Runde.
