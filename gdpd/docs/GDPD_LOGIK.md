# Logik der Kampagne (Build 14)

Stand: **eingebaut in Build 14.** Antwort auf die Meldung zu Build 13:
„Ich habe schon vorausgespielt und konnte dann keine Ursuppe mehr erstellen, weil ich gar kein Wasser mehr hatte.
Das muss logisch aufgebaut sein.“

## Was wir geprüft haben

- Jeden Weg, auf dem ein Level beginnt (neues Brett, Welt von gestern, gespeichertes Start-Brett, fortgesetzter
  Versuch, Nochmal, Nachholen, Neue Welt, Welt des Tages, alter Spielstand aus Build 12): 1176 echte Starts.
  **Kein Start ohne Wasser, keiner unlösbar.**
- Ein Brett ganz ohne Wasser ließ sich in den Ursuppe-Leveln nicht nachstellen. Der Fehler steckte in den Regeln:

## Was falsch war

1. **Das Rezept für Ursuppe verschwand still.** Level 6 und 7 lehren „Wasser braucht Glut und Fels“. Ab Level 8 galt
   das nicht mehr: Ursuppe kam nur noch aus Regen auf Wasser am Ufer. Level 9 braucht dafür zwei Regen.
2. **Regen war ein kleiner Vorrat, den man verschwenden konnte.** Wer ihn vorher auf Fels goss (so lehrt es Level 5),
   hatte keinen mehr, wenn die Ursuppe dran war. Oben stand dann nur „Dreh weiter, Regen kommt“.
3. **Nichts kam zurück.** Regen verbrauchte das Meer, nichts füllte es auf. Die Hilfe des Charakters nahm sich
   ausgerechnet Wasser.
4. **Die Prüfung „geht das Level noch?“ zählte nur Felder**, nicht, ob ihre Bedürfnisse erfüllbar sind. Sie sagte „passt“,
   wenn es nicht mehr passte. Hilfe kam erst nach 6 vergeblichen Schritten.
5. **Die Nacht baute die halbe Welt um** (im Schnitt 26 von 54 Feldern) und sagte nur „Über Nacht gewachsen“.
6. **Die Zeile oben nannte nicht immer eine Handlung** und führte manchmal im Kreis.

## Die Regeln ab Build 14

| Regel | Kurz |
|---|---|
| Ein Rezept bleibt | Wasser + 2 Wärme + Fels → Ursuppe gilt auch in Level 8 und 9. Regen ist dort nur noch eine Abkürzung. |
| Regen ist ein Kreislauf | Level 6–14: Regen macht Fels → Erde → Wasser → (am Ufer) Ursuppe oder Algen. „Regen füllt das Meer.“ Kein Regen ist verloren. |
| Regen erst, wenn es ihn gibt | In Level 1–4 gibt es keinen Regen, auch nicht als Hilfe von oben. Hilfe von oben kommt nur, wenn Regen etwas bringt. |
| Die Gefahr nimmt nie das Letzte | Hunger, Feuer, Eis, Vulkan, Krieg, Smog, Flut und Jagd lassen stehen, was das Ziel noch braucht („Hält durch!“). |
| Die Prüfung ist ehrlich | Sie zählt nur Felder, deren Bedürfnisse erfüllbar sind, und nur Regen, den es im Level gibt. |
| Hilfe sagt, was fehlt | „Zu wenig Lava. Ich helfe.“ Danach: „Geschenk: +3 Lava“. Die Hilfe nimmt kein Wasser weg, das das Level braucht. |
| Oben steht immer eine Handlung | Immer eine leuchtende Scheibe oder ein Werkzeug. Nie im Kreis. Gefahr zuerst (höchstens 2 Runden in Folge dieselbe). Voller Regen zuerst. Sackgasse: „Hilfe: hier tippen“. |
| Die Nacht ist ehrlich | Deine Welt bleibt erkennbar (im Test 15 statt 26 geänderte Felder). Der Banner nennt die größte Änderung: „Über Nacht: Ursuppe → Wasser“. |
| Jeder Start wird geprüft | Egal woher das Brett kommt (das „Tor“). Alte Stände aus Build 12 und 13: Ein laufender Versuch beginnt neu, ein altes Start-Brett wird neu geprüft. |
| Der Tipp folgt der Zeile | Findet die Suche nichts, nimmt der Tipp die Handlung der Zeile (Level 17, Brett 1). |
| Die Hilfe drängt sich nicht auf | Nach „Weiterspielen“ fragt der Charakter erst nach 12 Schritten wieder. Wer gerade aufholt, hängt nicht fest. |

Was gleich bleibt: jedes Level beginnt mit genau seiner Mischung (so bleibt es lösbar und die Sterne fair). Mehr zu
machen als nötig schadet nie.

## Was immer gilt (und ein Test prüft es bei jedem Build)

1. Jeder Start ist lösbar, auf jedem Weg.
2. Keine Gefahr macht ein Level unlösbar.
3. Macht es der Spieler selbst unlösbar (Regen, Meteor, Reihen), kommt die Hilfe in derselben Runde, sagt, was fehlt,
   und bringt immer Fortschritt.
4. Oben steht immer eine Handlung, die geht.

Die Prüfungen dazu stehen in `tests/test_rules.gd` (Abschnitt „Build 14“, schneller Lauf: `-- --b14`):

| Prüfung | Was sie festhält |
|---|---|
| `test_start_invariant14` | Start: aus Welten, die ein sorgloser Spieler hinterlässt, aus Extrem-Welten (kein Wasser, nur Wasser, nur eine Art) und aus Ständen von Build 12 ist jedes geprüfte Level erreichbar, hat das Wasser seiner Mischung und wird vom Tipp-Bot oder von der Zeile gewonnen. |
| `test_play_invariant14` | Spiel: nach sorglosem Spiel (Regen aufs Meer gegossen) gewinnen Tipp-Bot und Zeile noch; an jedem Stand nennt die Zeile eine Handlung, die geht. |
| `test_no_water_ursuppe14` | Der gemeldete Fall beim Namen: Level 6–11 beginnen nie ohne Wasser (auch nach einer Welt ganz ohne Wasser) und gehen weiter, wenn mitten im Level kein Wasser mehr da ist. |
| `test_never_stuck14` | Aus entarteten Starts (kein Wasser, Ziel-Kette fehlt, verspielte Welt) gewinnt selbst der Zufallsspieler mit dem Netz; jedes Geschenk bringt Fortschritt. |
| `test_soup_recipe14`, `test_rain_cycle14`, `test_mercy14` | Rezept in Level 8/9, Kreislauf in Level 6–14, kein Regen in Level 1–4. |
| `test_reach14`, `test_last_holds14`, `test_net_water14` | Ehrliche Prüfung ohne Fehlalarm, „Hält durch!“, Hilfe ohne Wasser-Verlust. |
| `test_line_follow14`, `test_hint14`, `test_texts14` | Zeile mit Handlung und ohne Kreis, Tipp folgt der Zeile, Texte. |
| `test_start_gate14`, `test_night14` | Das Tor für jeden Start und alte Stände, die ehrliche Nacht. |

Tour (echte Eingabe, `--only=b14`): `no_rain_before_level5`, `soup_recipe_stays`, `action_line_always_move`,
`rain_fills_sea`, `net_keeps_water`, `night_line_names_change`.

## Wie es gebaut ist (kurz, für Entwickler)

- Die neuen Regeln leben im Code, nicht in den Level-Daten: `GameState._apply_logic9()` (nur im Spiel, nie im
  Modell-Modus `engine9_mode`; der Abgleich mit dem Python-Modell spielt weiter die unveränderten Daten).
  `GameState.RULES_VERSION = 14` ist der Fingerabdruck; `Game._cfg_hash` rechnet ihn ein.
- `reach9` zählt je Feld, was es an Ort und Stelle werden kann (`_becomes9`, Bedürfnisse nach Sticker-Art und Menge:
  `_feed_ok9`), Reihen nach Beteiligten (die letzten zwei bleiben übrig). „Nicht ok“ heißt sicher festgefahren.
- `_holds9` schützt an den acht Gefahren-Stellen das Feld, dessen Verlust `reach9` kippen würde.
- `Campaign.gate` ist das Tor (54 bekannte Arten, erreichbar, keine fertige Reihe, nicht schon gewonnen);
  `Campaign.ensure` mischt ein gespeichertes Start-Brett nie neu.

## Später (bewusst nicht jetzt)

- Was du gestern gemacht hast, bleibt über Nacht liegen (braucht neue Mischungen für 7 Übergänge).
- Tauwetter in Level 41 (gemessen: 8 von 20 geprüften Lösungen gingen dann nicht mehr).
- Siedler für die Menschen-Level, Zwillings-Level 28/35, 29/37, 30/36, 33/39.
- Ein laufender Versuch je Level (heute: einer insgesamt).
- Das Geschenk als Regel des Levels (heute: +1 und Nachschub, nur ohne Wasser-Verlust und mit Ansage).
- Zwei Drehungen voraus für Versorgung in Level 47–60 (die Zeile nennt dort oft nur die beste sichere Scheibe).
- Nicht am Handy geprüft: Breite der langen Zeile „Dreh 3 Frühmenschen in eine Reihe“.
