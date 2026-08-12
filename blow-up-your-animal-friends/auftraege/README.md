# Aufträge — je einer pro lokale Claude-Code-Session (mit Studio-MCP)

Jede Datei hier ist ein in sich geschlossener Auftrag für EIN Element.
Start in der lokalen Session z. B. mit:

> Lies blow-up-your-animal-friends/auftraege/01-terrain.md und führe den
> Auftrag aus.

Reihenfolge-Empfehlung (wegen Abhängigkeiten der Testbarkeit):
01 Terrain -> 02 Projektilphysik -> 04 Waffen -> 03 Zielsystem ->
08 Rundenmanagement -> 09 UI -> 06 Kamera -> 05 Trefferfeedback ->
07 Sound & Sprüche. Parallel ist möglich (disjunkte Dateien), aber die
Kritiker sehen dann Baustellen anderer Elemente mit.

## Das Protokoll (gilt für JEDEN Auftrag)

- **Rollen:** Du bist Orchestrator, du implementierst nichts selbst.
  Builder-Agents schließen Lücken. Für jede Bewertung ein FRISCHER
  Kritiker-Agent, der Mission, Messlatte und das LAUFENDE Spiel bekommt —
  niemals Builder-Historie oder -Zusammenfassungen.
- **Der Kritiker prüft das ECHTE Spiel** via Studio-MCP: Testplay starten,
  Screenshots/Videos aufnehmen, Output-Logs lesen. Er bewertet nie
  Code-Beschreibungen.
- **Messlatte = Blindvergleich:** unser Element gegen dasselbe Element aus
  Worms Armageddon, ohne zu wissen, welches welches ist. Verliert unseres,
  benennt der Kritiker die EINE größte Lücke — keine Liste, keine Punktzahl,
  kein „könnte man verbessern". Dann macht der Builder weiter.
- **KEINE feste Rundenzahl.** Der Loop endet mit dem Bestehen (der Kritiker
  wählt unseres und ist von der Qualität umgehauen) oder mit dem Stopp durch
  den Menschen. Nichts anderes beendet ihn.
- **Git-Commit nach jeder bestandenen Runde.**
- **Verboten:** Fertigmelden ohne Kritiker-Blick aufs laufende Spiel;
  Zusatzfeatures als Fortschritt ausgeben; Dateien anderer Elemente anfassen
  (Eigentumstabelle in ARCHITECTURE.md).

## Pflichtlektüre vor jedem Auftrag

1. `blow-up-your-animal-friends/ARCHITECTURE.md` — Spielform, eiserne Regeln,
   Remote-Verträge, Zustandsmaschine, Datei-Eigentum, Seams.
2. `blow-up-your-animal-friends/CLAUDE.md` — Projektregeln.
3. Die eigenen Dateien des Elements (Stubs enthalten den API-Vertrag).

## Technik-Checks vor jedem Commit

- Rojo-Sync läuft (`rojo serve default.project.json`), Studio verbunden.
- Testplay startet ohne Fehler in der Output-Konsole (Client UND Server).
- BootHud zeigt den weißen Ready-Zustand (kein roter Fehler).
