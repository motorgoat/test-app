# Start-Prompt für den Strategie-Prototyp „Würfelreiche“

## So startest du
1. Auf claude.ai/code eine **neue Sitzung** mit dem Repo `motorgoat/test-app` starten.
2. Den Text unten (alles zwischen den Linien) als erste Nachricht einfügen.
   Das Wort **ultracode** am Anfang muss drinbleiben: Es schaltet die gründliche Arbeitsweise mit
   vielen Helfer-Agenten ein, und Token-Sparen ist dann kein Ziel mehr.
3. Laufen lassen. Claude meldet sich nach jedem Meilenstein mit einem Link zur Testversion.
4. Bricht die Sitzung ab (Nutzungslimit, Neustart des Containers), einfach schreiben:
   **„weiter laut PROGRESS.md“**. Der Stand liegt immer im Repo.

Tipps:
- Schau dir nach jedem Meilenstein die Testversion an und gib kurz Rückmeldung. „Bis es passt“
  kann Claude bei Regeln und Technik selbst prüfen, aber nicht, ob es dir Spaß macht.
- Wünsche einfach in normalen Sätzen nachschieben. Sie landen in `DECISIONS.md`.

---

ultracode

Du baust einen spielbaren PC-Prototyp für ein neues, großes Strategiespiel: **Würfelreiche**.
Lies zuerst vollständig: `god_does_play_dice/docs/STRATEGIE_KONZEPT.md` (das Konzept, verbindlich),
dann den Code von `god_does_play_dice/` (das bestehende Handyspiel: Godot 4.3, GDScript). Davon
übernimmst du Würfel, Drehmechanik, Kamera, Modelle, Grafikstil, Icons und CI-Aufbau. Das Handyspiel
selbst bleibt unverändert.

### Rahmen
- Neuer Ordner `dice_empires/` im Repo, eigenes Godot-4.3-Projekt (GDScript, Renderer
  gl_compatibility). Code darf aus `god_does_play_dice/` kopiert und angepasst werden.
- Arbeite auf dem Branch, der dir für diese Sitzung vorgegeben ist. Kein Pull Request.
- PC zuerst (Maus, Tastatur, Mausrad), Touch soll aber nicht kaputtgehen.
- Eigene GitHub-Action `.github/workflows/dice-empires.yml` nach dem Vorbild von
  `god-does-play-dice.yml`: Regeltests headless, Probelauf headless, Screenshot-Tour unter xvfb
  (Screenshots ins Repo nach `dice_empires/docs/screenshots`), Exporte Windows und Linux, Release mit
  eigenem Tag `empires-testversion`. Godot läuft im Container dieser Sitzung nicht. CI ist deine
  echte Prüfung: Nach jedem Push wartest du auf die Action, liest das Log und schaust dir jeden
  Screenshot mit dem Read-Tool an.
- Bekannte GDScript-Fallen aus dem alten Projekt: kein `:=` bei Variant-Werten (Typ angeben),
  keine mehrzeiligen Lambdas in Funktionsaufrufen, keine Schleifenvariable, die eine äußere Variable
  verdeckt, keine doppelten `var` in einer Funktion. Vor jedem Push alle .gd-Dateien mit einem
  GDScript-Parser auf Syntax prüfen.

### Spiel (Prototyp-Umfang)
Rundenbasiert, 1 Spieler gegen 1 Computergegner auf gegenüberliegenden Würfelseiten, 4 neutrale
Seiten. Jedes Feld ist ein Grundstück mit Bau-Raster (z. B. 6×6) und einer Landschaft mit
Ressourcen (Wiese, Wald, Berg, Wasser, Sand). Mittelfeld jeder Spielerseite = Hauptstadt (bewegt
sich nie). Runde: Wirtschaft (sammeln, bauen, ausbilden), höchstens eine Drehung (mit Kosten oder
Abklingzeit), Kampf wo sich fremde Grundstücke berühren, Besitzwechsel. Zeitalter wie im Konzept,
im Prototyp mindestens Urzeit bis Antike. Mindestens 8 Gebäude und 3 Einheitentypen. Siegbedingung:
gegnerische Hauptstadt erobern. Offene Fragen aus dem Konzept entscheidest du selbst, sinnvoll und
spielbar, und schreibst die Entscheidung mit Begründung in `dice_empires/DECISIONS.md`.

### Meilensteine (jeweils mit Abnahme)
Jeder Meilenstein gilt erst als fertig, wenn die Abnahme erfüllt und per CI belegt ist
(Tests grün, kein „SCRIPT ERROR“ im Log, Screenshots zeigen es).

- **M0 Gerüst:** Projekt, CI, leerer Würfel mit Drehen und Zoom läuft. Abnahme: CI grün, Screenshot.
- **M1 Zoom:** Stufenlos vom ganzen Würfel bis in ein Grundstück zoomen (Mausrad, Doppelklick auf ein
  Feld). Nah: Bau-Raster und Details. Weit: vereinfachte Ansicht und Besitzerfarben. Flüssig bei
  allen 54 Grundstücken voll bebaut (Detailstufen, MultiMesh). Abnahme: Screenshots nah, mittel,
  weit. Probelauf mit voll bebautem Würfel ohne Fehler.
- **M2 Wirtschaft:** Ressourcen, Bauen per Klick auf das Raster (Vorschau, Kosten, ungültige Plätze
  rot), Lager, Produktion pro Runde, Zeitalter-Aufstieg. Abnahme: Regeltests für Kosten, Produktion
  und Aufstieg. Screenshot einer gewachsenen Stadt.
- **M3 Drehen und Kampf:** Drehung als Spielzug (Vorschau, welche Grundstücke dadurch an den Gegner
  grenzen), Kampfauflösung, Eroberung, Einheiten drehen mit. Abnahme: Regeltests für Kampf und
  Besitzwechsel, Hauptstadt bleibt immer an ihrem Platz.
- **M4 Computergegner:** KI baut, sammelt, dreht und greift an. Abnahme: Simulation KI gegen KI
  (mindestens 20 Partien in den Tests) endet immer mit einem Sieger, keine Partie hängt, keine
  Partie ist nach wenigen Runden vorbei (Balance-Werte im Log).
- **M5 Oberfläche und Gefühl:** Moderne, ruhige, professionelle Oberfläche im Stil des Handyspiels
  (siehe dessen `scripts/style.gd` und Icons): Ressourcenleiste, Baumenü, Rundenknopf, Tooltips per
  Hover, Kurz-Tutorial für die erste Partie, Sieg-/Niederlage-Bildschirm. Animationen weich, nichts
  klebt am Rand, nichts überlappt. Abnahme: Screenshots aller Bildschirme, selbst kritisch geprüft.
- **M6 Politur:** Mindestens zwei Runden mit eigener Kritik an den Screenshots und dem Spielablauf.
  Jede gefundene Schwäche beheben.

### Arbeitsweise (wichtig)
- **Nichts abspecken.** Keine Platzhalter, keine Attrappen, kein „TODO später“ in fertigen
  Meilensteinen. Wird etwas schwierig, löse es. Ist etwas wirklich nicht machbar, schreib es mit
  Grund und Vorschlag in `PROGRESS.md` unter „Offen“, statt es stillschweigend wegzulassen.
- **Nicht fragen, entscheiden.** Ich bin nicht dauernd da. Triff vernünftige Entscheidungen, schreib
  sie in `DECISIONS.md` und arbeite weiter. Frag nur, wenn du sonst gar nicht weiterkommst.
- **Gründlich prüfen.** Für größere Schritte Workflows mit mehreren Agenten: entwerfen, umsetzen,
  unabhängig und kritisch prüfen (Code-Review auf Godot-4.3-Fehler, Spieler-Sicht), dann beheben.
- **Fortschritt sichern.** Nach jedem Meilenstein und mindestens jede Stunde: committen, pushen und
  `dice_empires/PROGRESS.md` aktualisieren (fertig, in Arbeit, nächster Schritt, offene Probleme).
  Die Sitzung kann jederzeit abbrechen. Eine neue Sitzung muss allein aus `PROGRESS.md` und
  `DECISIONS.md` weitermachen können.
- **Mitteilen.** Nach jedem Meilenstein kurz auf Deutsch melden, was neu ist, mit dem Link
  https://github.com/motorgoat/test-app/releases/tag/empires-testversion
- **Erst aufhören, wenn M0 bis M6 abgenommen sind.** Danach eine Liste mit Vorschlägen für die
  nächste Ausbaustufe (Online-Mehrspieler, mehr Zeitalter, bis zu 6 Spieler) in `PROGRESS.md`.

---
