# Auftrag 03 — Zielsystem

**Deine Dateien (NUR diese):**
- `src/StarterPlayer/StarterPlayerScripts/AimController.luau`
- `src/StarterPlayer/StarterPlayerScripts/TrajectoryPreview.luau`
- `src/StarterPlayer/StarterPlayerScripts/PowerBar.luau`
- `src/ReplicatedStorage/Shared/Config/Aiming.luau`

**Pflichtlektüre:** `ARCHITECTURE.md`, `CLAUDE.md`, `auftraege/README.md` (Protokoll).

## Mission

Zielen, das ein Fremder nach drei Schüssen ohne Erklärung versteht — Winkel,
Stärke, Vorschau, Lesbarkeit auf ShellShock/Worms-Niveau.

## Anforderungen

- **2.5D-Zielen:** Mausposition auf die Spielebene z=0 projizieren
  (Ray-Plane-Schnitt statt Welt-Raycast); Winkel frei in X/Y, Stärke durch
  Halten (bestehendes Muster: halten = laden, loslassen = feuern). Touch
  gleichwertig (bestehende lastTouchPosition-Mechanik weiterführen).
- **Vorschau MIT Wind und erstem Abpraller** (für Abpraller-Waffen) — mit
  exakt den Server-Funktionen aus Shared/Ballistics (Parität!). Wind kommt
  aus MatchEvent-Daten.
- **Waffenabhängige Vorschau** (WeaponDefs.previewKind): "arc" = Punktbogen,
  "ray" = Strahl (Hitscan), "marker" = Zielmarker (Luftschlag), "none".
- **Lesbarkeit:** Punktdichte = Geschwindigkeit, Einschlagsmarker,
  Farbverlauf entlang der Bahn; PowerBar mit Gefühl (Farbrampe, evtl. Tick
  beim Maximum).
- **Phasen-Disziplin:** aktiv nur während der eigenen Zielphase —
  enable()/disable() werden vom MatchEvent gesteuert (Verdrahtung über den
  bestehenden Seam; MatchEvent-Empfang gehört Element 09/08 — hier nur die
  enable/disable-API sauber bedienen lassen).
- Fire sendet weiterhin NUR (Richtung, Stärke) — die Waffe kennt der Server.

## Wonach der Kritiker im Testplay urteilt

Drei Schüsse ohne Erklärung: verstanden? Vorschau vs. Einschlag: exakt?
Vierter Schuss: Lust auf den fünften? Fühlt sich das Aufladen dosierbar an?


## Abnahme (Loop bis bestanden)

Kritiker-Protokoll siehe README.md in diesem Ordner: frischer Kritiker pro
Runde, echtes Testplay via Studio-MCP, Blindvergleich gegen Worms Armageddon,
binäres Urteil, EINE größte Lücke. Keine feste Rundenzahl — es gibt keine
letzte Runde außer der bestandenen. Commit nach jeder bestandenen Runde.
