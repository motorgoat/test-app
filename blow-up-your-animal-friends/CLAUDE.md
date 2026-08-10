# Blow Up Your Animal Friends — Projektregeln

Dieses Verzeichnis (`blow-up-your-animal-friends/`) ist ein eigenständiges Roblox-Projekt.
Die Firebase-PWA an der Repo-Wurzel ist ein anderes Projekt — **nicht anfassen**.

## Stack

- **Roblox Studio** (Play-Testen, Terrain, Rendering)
- **Luau** (strikt: keine deprecated APIs)
- **Rojo** (Dateisystem ⇄ Studio-Sync, `default.project.json`)
- **Git** (Commit nach jedem abgeschlossenen Schritt)
- **Studio-MCP** läuft lokal (Testplays, Game-Feel-Gauntlet)

## Regeln

- **Keine deprecated APIs.** Kein `wait()`/`spawn()`/`delay()` (→ `task.*`), kein
  `Mouse.KeyDown` (→ `UserInputService`/`ContextActionService`), keine BodyMover
  (`BodyVelocity` etc.). Bei Unsicherheit gegen create.roblox.com/docs prüfen, nicht raten.
- **Server-autoritativ.** Spiellogik, Schaden und Terrainänderungen leben ausschließlich in
  `ServerScriptService`. Clients senden nur Eingaben (Richtung als Einheitsvektor, Stärke 0..1)
  und rendern Kosmetik. Der Server validiert jede Eingabe.
- **Terrain wird nur serverseitig verändert** (aktuell nur in `ProjectileServer.luau`).
- **Struktur:**
  - `src/ReplicatedStorage/Shared/` — geteilte, pure Module (Config, Ballistics)
  - `src/ServerScriptService/` — Server-Bootstrap + Server-Module
  - `src/StarterPlayer/StarterPlayerScripts/` — Client-Bootstrap + Client-Module
- **ModuleScripts, keine Monolithen.** Eine Datei = eine Verantwortung.
- **Alle Magic Numbers in `Config.luau`.** Null Zahlenliterale in Logikmodulen
  (außer 0/1-Trivialfälle und mathematische Formelkonstanten).
- **Rojo-Namenskonventionen:** `.server.luau`, `.client.luau`, ModuleScripts plain `.luau`.
- **Commit nach jedem abgeschlossenen Schritt.**

## Kontext

Artilleriespiel mit zerstörbarem Voxel-Terrain; später gleichzeitige Züge
(Worms Armageddon / ShellShock Live als Referenz).

**Aktueller Meilenstein: Schießen / Game Feel.** Umfang strikt begrenzt auf:
Terrain, Zielen im Stand, Projektil, Krater — allein testbar. Kein Multiplayer,
kein Rundensystem, keine Phasenlogik, keine Bewegungssperre, keine Waffenauswahl,
keine Gegner, keine Menüs. Seams für die spätere Zustandsmaschine:
`FireHandler.setCanFire()`, `AimController.enable()/disable()`,
`TerrainIsland.resetTerrain()` — kleine Haken, keine Vorab-Implementierung.

**Oberste Game-Feel-Priorität:** Die Flugbahn-Vorschau und die echte Flugbahn müssen
EXAKT übereinstimmen. Deshalb rechnen Client und Server ausschließlich mit
`Shared/Ballistics.luau` und der Gravitation aus `Config.luau` — niemals
`workspace.Gravity` an mehreren Stellen lesen.
