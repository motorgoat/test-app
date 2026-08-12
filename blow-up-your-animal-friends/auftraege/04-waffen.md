# Auftrag 04 — Waffenarsenal

**Deine Dateien (NUR diese):**
- `src/ReplicatedStorage/Shared/WeaponDefs.luau`
- `src/ServerScriptService/WeaponServer.luau`
- `src/ServerScriptService/FireHandler.luau`
- `src/ReplicatedStorage/Shared/Config/Weapons.luau`

**Pflichtlektüre:** `ARCHITECTURE.md`, `CLAUDE.md`, `auftraege/README.md` (Protokoll).

## Mission

Mindestens 14 Waffen, jede mit eigenem Charakter — das absurde Herz von
Worms. Datengetrieben, serverautoritativ, balanciert.

## Anforderungen

- **WeaponDefs füllen** (Schema steht im Stub): Bazooka (Standard, windvoll),
  Mörser (steiler Bogen, schwer), Granate (3s-Zünder, hoppelt),
  Splittergranate (5 Cluster), Heilige Granate (lange Zündung, Riesenkrater,
  Halleluja-Moment), Banane (Cluster, stark + chaotisch), Schrotflinte
  (2× Hitscan mit Streuung), Uzi (10er-Salve, Recoil-Streuung), Dynamit
  (fallen lassen, 5s, gewaltig), Mine (Näherungszünder), Luftschlag
  (5 Bomben von oben auf Zielmarker), Ziegenbombe (läuft als Rig los,
  explodiert bei Nähe/Timer — Sheep-Hommage), Baseballschläger (Melee:
  großer Knockback, wenig Schaden), Teleport (verbraucht die Runde).
- **FireHandler:** validiert (Richtung, Stärke) + gewählte Waffe + Munition
  serverseitig; delegiert an WeaponServer.fire. setCanFire-Seam beibehalten.
- **WeaponServer:** orchestriert Projektile via ProjectileServer (Cluster,
  Timer, Hitscan-Raycasts), Krater via TerrainWorld.carveCrater, Schaden mit
  Distanz-Falloff + Knockback via ApplyImpulse (KEINE BodyMover) und meldet
  DamageEvent. WeaponSelect-Remote: validieren, Munition prüfen.
- **Balance:** Munitionsverteilung und Schadenswerte so, dass Standardwaffen
  tragen und Spezialwaffen Momente sind (alles in Config/Weapons/WeaponDefs).

## Wonach der Kritiker im Testplay urteilt

Jede Waffe einmal abfeuern: Hat jede einen EIGENEN Charakter (Flugbild,
Krater, Wumms)? Gibt es mindestens einen „Halleluja-Moment"? Fühlt sich
keine Waffe wie eine Kopie einer anderen an?


## Abnahme (Loop bis bestanden)

Kritiker-Protokoll siehe README.md in diesem Ordner: frischer Kritiker pro
Runde, echtes Testplay via Studio-MCP, Blindvergleich gegen Worms Armageddon,
binäres Urteil, EINE größte Lücke. Keine feste Rundenzahl — es gibt keine
letzte Runde außer der bestandenen. Commit nach jeder bestandenen Runde.
