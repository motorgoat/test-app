# Auftrag 06 — Kamera-Regie

**Deine Dateien (NUR diese):**
- `src/StarterPlayer/StarterPlayerScripts/CameraDirector.luau`
- `src/ReplicatedStorage/Shared/Config/Camera.luau`

**Pflichtlektüre:** `ARCHITECTURE.md`, `CLAUDE.md`, `auftraege/README.md` (Protokoll).

## Mission

Eine Kamera, die das Match INSZENIERT: Verfolgung, Einschlag-Framing,
weiche Übergänge — Seitenansicht wie Worms, Gefühl wie ein Regisseur.

## Anforderungen

- **Scriptable Camera**, immer vor den Wänden (z deutlich negativ), Blick +Z.
- **Standard:** weiches Follow des aktiven Wurms (Deadzone, Lookahead in
  Blickrichtung, Glättung).
- **Schuss:** Projektilverfolgung mit Vorhalt; sanfter Zoom-Out bei hohen
  Bögen, damit Abschuss + Ziel im Bild bleiben (ProjectileFired →
  clientseitige Bahnberechnung mit Shared/Ballistics für den Vorhalt).
- **Einschlag:** kurzes Framing auf den Krater mit Verweilen (CameraCue),
  dann weiche Fahrt zurück bzw. zum nächsten aktiven Wurm (MatchEvent) —
  parametrisierte Lerp-Fahrten (Dauer/Easing in Config), NIE harte Schnitte
  mitten in der Action.
- **Zielphase:** freies Umsehen (Randscrollen und/oder mittlere Maustaste
  ziehen; Touch: Zwei-Finger-Pan), Rücksprung bei Aktion.

## Wonach der Kritiker im Testplay urteilt

Kompletter Schuss-Zyklus: Verliert man je das Projektil aus den Augen? Ruckt
oder schneidet die Kamera irgendwo? Fühlt sich der Einschlag-Moment gerahmt
an wie im Original?


## Abnahme (Loop bis bestanden)

Kritiker-Protokoll siehe README.md in diesem Ordner: frischer Kritiker pro
Runde, echtes Testplay via Studio-MCP, Blindvergleich gegen Worms Armageddon,
binäres Urteil, EINE größte Lücke. Keine feste Rundenzahl — es gibt keine
letzte Runde außer der bestandenen. Commit nach jeder bestandenen Runde.
