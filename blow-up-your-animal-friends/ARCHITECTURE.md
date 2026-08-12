# Architektur — Vollausbau „Worms Armageddon, modern, Roblox/Luau"

Stand: Skelett fertig (Cloud-Session 2026-08-12). Der v11-Spielkern (Zielen,
Schuss, Krater, BootHud-Diagnose) bleibt durchgehend funktionsfähig; alle neuen
Module sind als Stubs verdrahtet und werden je von EINEM Element gefüllt
(Aufträge in `auftraege/`).

## Spielform

**2.5D-Seitenansicht** (Worms ist 2D): Spielstreifen aus Voxel-Terrain
(Tiefe ≈ 24 studs) zwischen zwei statischen unsichtbaren Wänden bei z = ±15
(`Workspace.PlayFieldWallFront/Back`, CanQuery=false — Zielraycasts gehen durch).
Bewegung und Schüsse in der X/Y-Ebene (z = 0). Kamera seitlich bei negativem z,
Blick +Z. Teams: 1 Avatar pro Spieler; Solo-Matches füllt der MatchServer mit
Bot-Ziegen auf (Part-Rigs mit Humanoid, serverseitig). Rundenbasiert mit Timer,
Wind pro Runde, HP, Fallschaden, Wasser = Tod, Sieg = letztes lebendes Team.

## Eiserne Regeln (alle aus echten Live-Bugs dieses Projekts)

1. **Server-autoritativ:** Clients senden NUR Eingaben (Einheitsrichtung,
   Stärke 0..1, Waffenwahl, Bewegungsabsicht). Server validiert und clampt
   JEDEN Remote-Parameter. Terrainänderungen NUR über `TerrainWorld.carveCrater`.
2. **`Terrain:CopyRegion`/`PasteRegion` VERBOTEN** — crashte den Live-Server hart.
3. **Client-Code:** Nachbar-Module und ReplicatedStorage-Inhalte IMMER via
   `WaitForChild` — direkter Punktzugriff tötete den Bootstrap im Live-Join
   (Klone treffen progressiv ein). Server-Code darf direkt zugreifen.
4. **Instanzen, die Client und Server brauchen** (Remotes, Wände) liegen
   STATISCH in `default.project.json` — nie zur Laufzeit erstellen.
5. **Keine deprecated APIs:** `task.*` statt wait/spawn/delay;
   UserInputService/ContextActionService statt Mouse-Events;
   `ApplyImpulse`/`AssemblyLinearVelocity` statt BodyMover.
6. **Luau `--!strict`** in jeder Datei; deutsche Kommentare im bestehenden Stil;
   eine Datei = eine Verantwortung.
7. **Alle Zahlenwerte in `Shared/Config/<Bereich>.luau`** — null
   Game-Feel-Literale in Logik (BootHud ist dokumentierte Ausnahme).
8. **Sounds:** bevorzugt `rbxasset://`-Builtins (garantiert hörbar); fremde
   `rbxassetid://` können unter Audio-Privacy STUMM sein — nur mit Kommentar
   als Risiko. KEINE Worms-Originalassets (Copyright) — Sprüche sind eigene
   deutsche Texte via Sprechblasen.
9. **Flugbahn-Parität ist heilig:** Client-Vorschau und Server-Simulation
   rechnen BEIDE ausschließlich mit `Shared/Ballistics` + Config — nie
   `workspace.Gravity` lesen. Wind ist ein Parameter derselben Funktionen.

## RemoteEvents (statisch, `ReplicatedStorage/Remotes`)

| Remote | Richtung | Payload |
|---|---|---|
| FireRequest | C→S | (direction: Vector3-Einheitsvektor, power: 0..1) |
| ProjectileFired | S→C | (shotId, origin, initialVelocity[, weaponId]) |
| ProjectileImpact | S→C | (shotId, position, craterRadius) |
| WeaponSelect | C→S | (weaponId: string) — Server validiert gegen WeaponDefs+Munition |
| MatchEvent | S→C | (phase: string, data: table) — Rundenzustand, s. u. |
| QuipEvent | S→C | (situation: string, wurmName: string) |
| CameraCue | S→C | (cue: string, data: table) — z. B. "impactFraming", "followNext" |
| DamageEvent | S→C | (targetCharacter, damage: number, isCrit: boolean, position: Vector3) |

`MatchEvent`-Phasen: `warten`, `matchstart` {teams}, `rundenstart`
{aktiverName, wind, timerSeconds}, `zielphase`, `aufloesung`, `rueckzug`
{seconds}, `sieg` {teamName}. Die genaue data-Form definiert das Element
„Rundenmanagement" und dokumentiert sie HIER nach.

## Zustandsmaschine (MatchServer)

Warten (≥1 Spieler) → Matchstart (Teams, Bot-Ziegen, Spawns via
`TerrainWorld.getSpawnPoints`) → je Runde: Windwurf → MatchEvent →
Zielphase mit Timer (`FireHandler.setCanFire` nur für den Aktiven;
Nicht-Aktive serverseitig verankert) → nach Schuss Auflösung (alle
Projektile/Cluster fertig) → Schadensabrechnung (HP, Fallschaden,
Wasser=Tod) → Rückzugszeit → Siegprüfung → nächste Runde bzw. Sieg-Banner
und Match-Neustart.

## Modul-Eigentum (ein Element = ein Auftrag = diese Dateien, sonst NICHTS)

| Element | Dateien |
|---|---|
| 01 Terrain | `ServerScriptService/TerrainWorld.luau`, `Shared/Config/Terrain.luau` |
| 02 Projektilphysik | `Shared/Ballistics.luau`, `ServerScriptService/ProjectileServer.luau`, `Shared/Config/Ballistics.luau` |
| 03 Zielsystem | `StarterPlayerScripts/AimController.luau`, `TrajectoryPreview.luau`, `PowerBar.luau`, `Shared/Config/Aiming.luau` |
| 04 Waffen | `Shared/WeaponDefs.luau`, `ServerScriptService/WeaponServer.luau`, `FireHandler.luau`, `Shared/Config/Weapons.luau` |
| 05 Trefferfeedback | `StarterPlayerScripts/ImpactEffects.luau`, `DamageNumbers.luau`, `Shared/Config/Effects.luau` |
| 06 Kamera | `StarterPlayerScripts/CameraDirector.luau`, `Shared/Config/Camera.luau` |
| 07 Sound & Sprüche | `StarterPlayerScripts/SoundDirector.luau`, `QuipSystem.luau`, `Shared/QuipDefs.luau`, `Shared/Config/Sound.luau` |
| 08 Rundenmanagement | `ServerScriptService/MatchServer.luau`, `BotBrain.luau`, `Shared/Config/Match.luau` |
| 09 UI/HUD | `StarterPlayerScripts/HudController.luau`, `WeaponWheel.luau`, `Shared/Config/UI.luau` |

Bootstraps (`Server.server.luau`, `Client.client.luau`), `BootHud`,
`default.project.json` und dieses Dokument gehören der Integration — Elemente
fassen sie NICHT an (die Stubs sind bereits verdrahtet; ein Element füllt nur
seine Module). Braucht ein Element eine Vertragsänderung (neue Remote-Payload,
neuer Seam), dokumentiert es sie hier unter „Offene Vertragsänderungen" und
stimmt sie mit dem Orchestrator ab.

## Seams zwischen den Elementen

- `TerrainWorld.carveCrater(position, radius)` — einzige Terrainänderung;
  `TerrainWorld.CraterCarved`-Signal für Server-Hörer.
- `TerrainWorld.getSpawnPoints(count)` — MatchServer holt Spawns.
- `FireHandler.setCanFire(fn)` — MatchServer steuert, wer feuern darf.
- `WeaponServer.getSelectedWeapon(player)` / `WeaponServer.fire(...)` —
  FireHandler delegiert den validierten Schuss.
- `AimController.enable()/disable()` — Client-Reaktion auf MatchEvent.
- Alle Client-Module bekommen in `init(remotes)` DIESELBE Remote-Tabelle.

## Offene Vertragsänderungen

(leer — hier tragen Elemente Abweichungen nach)
