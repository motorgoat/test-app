# Auftrag 05 — Trefferfeedback

**Deine Dateien (NUR diese):**
- `src/StarterPlayer/StarterPlayerScripts/ImpactEffects.luau`
- `src/StarterPlayer/StarterPlayerScripts/DamageNumbers.luau`
- `src/ReplicatedStorage/Shared/Config/Effects.luau`

**Pflichtlektüre:** `ARCHITECTURE.md`, `CLAUDE.md`, `auftraege/README.md` (Protokoll).

## Mission

GEWICHT. Jeder Treffer muss körperlich spürbar sein — Screenshake, Partikel,
Knockback-Würdigung, der richtige Verweil-Moment.

## Anforderungen

- **Shake verfeinern:** Trauma-System beibehalten, plus Richtungs-Punch
  (erster Impuls weg vom Einschlag), Distanz-Falloff, Skalierung mit
  Kratergröße/Waffe.
- **Materialabhängige Partikel:** Erde/Fels/Wasser-Splash unterscheidbar;
  Explosionslicht, aufsteigender Staub, Trümmer-Andeutung.
- **Trefferpause-Illusion:** bei großen Treffern kurzer FOV-Punch +
  Kamera-Verweilen — koordiniert über CameraCue (KEIN globales
  Zeitskalieren, kein Eingriff in CameraDirector-Dateien: nur auf die
  vorhandenen Events reagieren).
- **DamageNumbers:** BillboardGui-Zahlen steigen aus dem Getroffenen auf,
  Größe skaliert mit Schaden, kritische Treffer fett.
- **Knockback würdigen:** kurzer Taumel-Moment beim Getroffenen (Humanoid
  Sit/PlatformStand kurz + Impuls sichtbar machen) — rein kosmetisch, die
  Physik kommt vom Server.
- Alles event-getrieben (ProjectileImpact/DamageEvent), alle Zahlen in
  Config/Effects.

## Wonach der Kritiker im Testplay urteilt

Naher Volltreffer vs. ferner Streifschuss: unterscheidbar mit geschlossenen
Augen (Shake) und auf Screenshot (Partikel, Zahlen)? Fühlt sich der große
Treffer nach Ereignis an — oder nach Partikel-Konfetti?


## Abnahme (Loop bis bestanden)

Kritiker-Protokoll siehe README.md in diesem Ordner: frischer Kritiker pro
Runde, echtes Testplay via Studio-MCP, Blindvergleich gegen Worms Armageddon,
binäres Urteil, EINE größte Lücke. Keine feste Rundenzahl — es gibt keine
letzte Runde außer der bestandenen. Commit nach jeder bestandenen Runde.
