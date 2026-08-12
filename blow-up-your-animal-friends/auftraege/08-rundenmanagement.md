# Auftrag 08 — Rundenmanagement und Match-Fluss

**Deine Dateien (NUR diese):**
- `src/ServerScriptService/MatchServer.luau`
- `src/ServerScriptService/BotBrain.luau`
- `src/ReplicatedStorage/Shared/Config/Match.luau`

**Pflichtlektüre:** `ARCHITECTURE.md`, `CLAUDE.md`, `auftraege/README.md` (Protokoll).

## Mission

Das Herzstück: rundenbasiertes Match mit Timer, Wind, HP, Sieg — und
Bot-Ziegen, damit Solo-Testen ein echtes Match ist.

## Anforderungen

- **Zustandsmaschine** (Details in ARCHITECTURE.md): Warten → Matchstart
  (Teams; Solo mit 3 Bot-Ziegen auffüllen — Part-Rigs mit Humanoid,
  serverseitig; Spawns via TerrainWorld.getSpawnPoints) → Runde: Windwurf,
  MatchEvent(phase, data) an alle, Zielphase mit Timer
  (FireHandler.setCanFire NUR für den Aktiven; Nicht-Aktive serverseitig
  verankert), Auflösung (warten bis alle Projektile/Cluster fertig —
  Seam mit ProjectileServer abstimmen), Schadensabrechnung (HP, Fallschaden
  bei harten Landungen, Wasser = sofort tot), Rückzugszeit → Siegprüfung →
  Sieg-Banner + QuipEvent + Match-Neustart nach Pause.
- **MatchEvent-Datenform** definieren und in ARCHITECTURE.md nachdokumentieren
  (Elemente 03/06/09 konsumieren sie).
- **BotBrain:** Ziel = nächster lebender Gegner; Schusslösung mit
  Shared/Ballistics (inkl. Wind) + konfigurierbare Streuung; simple
  Waffenwahl; kurze Denkpause; feuert AUSSCHLIESSLICH über dieselben
  Server-Pfade wie Spieler (FireHandler/WeaponServer) — keine Sonderrechte.
- **HP-Verwaltung** inkl. DamageEvent-Versand (Payload s. ARCHITECTURE.md);
  QuipEvent-Auslösung an den passenden Stellen (volltreffer, wasserTod, …).
- Alle Zahlen in Config/Match.

## Wonach der Kritiker im Testplay urteilt

Ein komplettes Solo-Match gegen die Bot-Ziegen: Trägt der Rundenrhythmus
(Spannung beim Timer, Erleichterung im Rückzug)? Sind die Bots gefährlich
genug zum Ernstnehmen, aber schlagbar? Endet das Match sauber mit Sieg und
Neustart?


## Abnahme (Loop bis bestanden)

Kritiker-Protokoll siehe README.md in diesem Ordner: frischer Kritiker pro
Runde, echtes Testplay via Studio-MCP, Blindvergleich gegen Worms Armageddon,
binäres Urteil, EINE größte Lücke. Keine feste Rundenzahl — es gibt keine
letzte Runde außer der bestandenen. Commit nach jeder bestandenen Runde.
