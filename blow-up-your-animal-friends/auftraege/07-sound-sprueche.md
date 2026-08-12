# Auftrag 07 — Sound und Sprüche

**Deine Dateien (NUR diese):**
- `src/StarterPlayer/StarterPlayerScripts/SoundDirector.luau`
- `src/StarterPlayer/StarterPlayerScripts/QuipSystem.luau`
- `src/ReplicatedStorage/Shared/QuipDefs.luau`
- `src/ReplicatedStorage/Shared/Config/Sound.luau`

**Pflichtlektüre:** `ARCHITECTURE.md`, `CLAUDE.md`, `auftraege/README.md` (Protokoll).

## Mission

Die Identität von Worms sind die Stimmen. Wir bauen sie OHNE Worms-Assets:
freche deutsche Sprüche als Sprechblasen + tonale Blips, dazu ein
Sound-Layer mit Gewicht und Varianz.

## Anforderungen

- **SoundDirector:** Ereignis→Sound-Mapping (Abschuss pro Waffentyp,
  Projektil-Zischen, Abpraller-Plopp, Explosion gestaffelt nach Größe,
  Schadens-Autsch, Wasser-Platsch, UI-Klicks, Rundenstart, Sieg) mit
  Pitch-/Volume-Variation gegen Monotonie. Basis NUR rbxasset://-Builtins
  (Audio-Privacy: fremde rbxassetid können stumm sein — der stumme
  Einschlag war ein realer Befund dieses Projekts!). Marketplace-IDs nur
  als dokumentierte, einzeln testbare Option.
- **QuipDefs:** mindestens 8 Situationen × 4 Varianten (rundenstart,
  volltreffer, fehlschuss, eigenerSchaden, beinaheTreffer, langeweile,
  sieg, wasserTod) — kurz, frech, deutsch, jugendfrei.
- **QuipSystem:** QuipEvent(situation, wurmName) → Sprechblase
  (BillboardGui über dem Kopf, Tween-Pop, kurze Standzeit, nie zwei
  gleiche hintereinander) + tonaler Blip (Pitch nach Stimmung).
- Alle Zahlen in Config/Sound.

## Wonach der Kritiker im Testplay urteilt

Zwei Minuten spielen mit Ton: Hat jeder Wumms sein Gewicht? Nervt die
Wiederholung (Varianz!)? Zünden die Sprüche — grinst man mindestens einmal?
Ist NICHTS stumm?


## Abnahme (Loop bis bestanden)

Kritiker-Protokoll siehe README.md in diesem Ordner: frischer Kritiker pro
Runde, echtes Testplay via Studio-MCP, Blindvergleich gegen Worms Armageddon,
binäres Urteil, EINE größte Lücke. Keine feste Rundenzahl — es gibt keine
letzte Runde außer der bestandenen. Commit nach jeder bestandenen Runde.
