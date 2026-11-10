gdpd – Trailer v2 („Die Schöpfung“)
====================================

Fertige Dateien (in diesem Ordner)
  gdpd_trailer_v2.mp4          Hochformat 1080x1920, 30 fps, 34,6 s, H.264 + AAC (-14 LUFS, Spitze <= -1 dBTP)
  gdpd_trailer_v2_square.mp4   Quadrat 1080x1080, eigener Render mit angepasstem Layout (gleiche Zeitleiste)
  gdpd_trailer_v2_15s.mp4      Kurzfassung 15 s (Haken -> 4 Montage-Schnitte -> Meteor -> fertige Welt -> Abspann)
  frames_v2/                   8 Standbilder aus dem Hochformat
  cues_v2.json                 Zeitmarken aller Klang-Ereignisse (schreibt die Szene beim Rendern)

Quellen im Projekt (nichts im Spiel geändert)
  gdpd/trailer/trailer.tscn, trailer.gd   die Trailer-Szene (echte World, echte Level-Bretter, echte Zeitalter)
  gdpd/trailer/grade.gdshader             Farbkorrektur, Vignette, Bildblitz, Wisch-Unschärfe
  gdpd/trailer/tools/make_audio.py        Tonspur aus den Zeitmarken (nur numpy, keine fremden Samples)
  gdpd/trailer/tools/scout.gd, scout_hut.gd   Hilfen zum Finden passender Bretter/Drehungen (godot --headless -s ...)

Neu rendern
  0) einmal importieren:
       cd <projekt>/gdpd && godot --headless --import
  1) Bilder (Movie Maker, jedes Bild deterministisch, verlustfreie PNG-Folge):
       cd <projekt>/gdpd
       xvfb-run -a -s "-screen 0 1100x2400x24" godot --rendering-driver opengl3 --resolution 1080x1920 \
         --write-movie <out>/raw_v2/f.png --fixed-fps 30 res://trailer/trailer.tscn -- --cues=<out>/cues_v2.json
     Quadrat: dasselbe mit --resolution 1080x1080 (Layout und Zoom passen sich an), Ziel raw_v2_square/,
     cues_v2_square.json. Schnellprobe: --resolution 540x960 --fixed-fps 6 (ca. 2 min statt ca. 45 min).
     Hier fertig verdrahtet:  ./render_v2.sh <ordner> <BxH> <fps> [cues.json]
  2) Ton + Video zusammenbauen (Tonspur erzeugen, zwei Durchgänge loudnorm auf -14 LUFS / -2 dBTP (nach AAC <= -1 dBTP), x264 crf 19):
       ./assemble_v2.sh all          (oder: portrait | square | cut15)
     Die Kurzfassung nimmt die Abschnitte aus SEG (Sekunden der langen Fassung), Ton wird dafür neu verteilt.

Ablauf v2 (Sekunden)
  0,0  Haken: Lava-Würfel dreht sofort, Finger wischt, „Aus Glut …“ – Schnitt auf die fertige Welt „… wird eine Welt.“
  1,8  „Am Anfang war die Glut.“ (Wasser kühlt Lava zu Fels, Dampf; totes Wasser heller/blauer)
  4,3  DAMPF WIRD REGEN (echter Regen-Bonus)
  5,8  Algen: Finger wischt, der Himmel wird in 0,8 s blau, „Du bist Gott.“, Miez hüpft herein
  8,8  Montage, ein Takt je Schnitt mit Wisch-Schwenk, nach jedem Wachsen kurzer Schub auf das gewachsene Feld:
       WÄLDER, FISCHE, LANDGANG, ZEIT DER RIESEN (drei Langhälse, nah, stampfend)
  16,8 DER METEOR: Schweif über den Himmel, weißer Blitz, Beben, roter Himmel, Asche, die Riesen fallen, dunkel
  18,8 DANACH: SÄUGETIERE (aus dem Dunkel) – AFFEN – MENSCHEN (Hütte wächst oben) – DÖRFER UND STÄDTE
  26,2 Die fertige Welt, „Erschaffe deine Welt – Tag für Tag.“
  29,7 Abspann bis zum letzten Bild: „Die Welt ist ein Würfel. Du bist Gott.“, gdpd · Das Gottspiel auf dem Würfel,
       Miez, „Jetzt vorregistrieren“, Plaketten Google Play / App Store (nur Text, keine fremden Logos)

Hinweise
  - Langhälse, Flugsaurier und Affen sind die echten Modelle des Spiels (Models.creature_mesh "sauro", "ptero", "ape",
    GDPD_ERDGESCHICHTE_GRAFIK.md 10); nur der Meteor-Schweif ist eine eigene Form des Trailers.
  - Die Schnitte nennen Level der alten Zählung (1 … 30); trailer.gd rechnet sie mit Campaign.old_to_new auf die
    Erdgeschichte um. „Zeit der Riesen“, „Säugetiere“ und „Affen“ nehmen die neuen Level 28, 36, 43 (echte Saurier,
    Säugetiere, Affen). Die Bretter sind dadurch andere als im fertigen Video v2: vor dem nächsten Rendern ansehen.
  - Text liegt in den sicheren Zonen (Titel y 250–480, Bildunterschrift um y 1320, alles in 1080er-Koordinaten).
  - Beim Wechsel auf eine frische World mitten in einer Runde meldet Godot harmlose „!is_inside_tree“-Fehler.

Messwerte der fertigen Dateien
  gdpd_trailer_v2.mp4          34,65 s, 1080x1920, 30 fps, -14,1 LUFS, Spitze -1,0 dBTP, ca. 49 MB
  gdpd_trailer_v2_square.mp4   34,65 s, 1080x1080, 30 fps, -14,1 LUFS, Spitze -1,0 dBTP, ca. 36 MB
  gdpd_trailer_v2_15s.mp4      15,0 s,  1080x1920, 30 fps, -14,1 LUFS, Spitze -1,6 dBTP, ca. 20 MB

Zwischendateien (dürfen gelöscht werden, je ca. 2–3 GB): raw_v2/, raw_v2_square/, cut15_frames/ (nur Verweise),
  *_mix_raw.wav. Die fertigen Tonspuren: v2_mix.wav, v2sq_mix.wav, cut15_mix.wav.
