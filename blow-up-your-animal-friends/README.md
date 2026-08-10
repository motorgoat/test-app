# Blow Up Your Animal Friends

Artilleriespiel mit zerstörbarem Voxel-Terrain für Roblox.
Aktueller Meilenstein: **Schießen / Game Feel** — Terrain, Zielen, Projektil mit
Flugbahn-Vorschau, Krater. Allein testbar, kein Multiplayer.

## Setup

### 1. Rojo installieren

Empfohlen über [rokit](https://github.com/rojo-rbx/rokit) (oder das ältere aftman):

```sh
# rokit (empfohlen)
rokit init            # einmalig in diesem Verzeichnis
rokit add rojo-rbx/rojo

# alternativ: aftman
aftman init
aftman add rojo-rbx/rojo
```

Außerdem in Roblox Studio das **Rojo-Plugin** installieren
(im Rojo-Terminal: `rojo plugin install`, oder aus dem Creator Store).

### 2. Sync starten

```sh
cd blow-up-your-animal-friends
rojo serve default.project.json
```

Dann in Roblox Studio einen leeren Baseplace öffnen (Baseplate löschen, stört aber
nicht — die Insel spawnt bei den Weltkoordinaten um den Ursprung), Rojo-Plugin öffnen
und **Connect** drücken. Die `src/`-Dateien erscheinen live in ReplicatedStorage,
ServerScriptService und StarterPlayer.

### 3. Allein testen

- In Studio **Play (F5)** drücken — ein Spieler genügt.
- Der Server generiert die Insel und erstellt die RemoteEvents; der Client startet
  Zielen + Vorschau automatisch.
- **Steuerung:** Maus bewegen = zielen (gepunktete Flugbahn folgt der Maus).
  **Linke Maustaste halten** = Kraft aufladen (Balken unten, Vorschau wächst mit).
  **Loslassen** = Feuern. Einschlag sprengt sofort einen Krater ins Terrain.
- Terrain zurücksetzen (z. B. in der Kommandozeile des Server-Kontexts):
  `require(game.ServerScriptService.TerrainIsland).resetTerrain()`

## Game-Feel-Gauntlet

Der Game-Feel-Gauntlet (Testplays mit Bewertung von Flugbahn-Lesbarkeit,
Einschlags-Gewicht und Treffer-Befriedigung) läuft **lokal über Studio-MCP** —
Studio muss dafür mit laufendem `rojo serve` verbunden sein.

## Architektur in einem Absatz

Der Client sendet ausschließlich `(Richtung, Stärke)` über
`ReplicatedStorage/Remotes/FireRequest`. Der Server validiert, simuliert das Projektil
kinematisch (Heartbeat + Raycast) und ist alleiniger Eigentümer des Terrains
(`FillBall` → Krater). Client und Server rechnen beide mit
`Shared/Ballistics.luau` und derselben Config-Gravitation, dadurch stimmen
Vorschau-Flugbahn und echte Flugbahn exakt überein. Alle Zahlenwerte liegen in
`Shared/Config.luau`.
