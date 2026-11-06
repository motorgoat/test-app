class_name CharacterTexts
extends RefCounted
## Was der eigene Charakter sagt, je Ton (lieb / frech / streng). Spec: docs/GDPD_TAEGLICH_CHARAKTER.md, Abschnitt 4.
## Nur Daten und reine Hilfen (kein Zustand): Wer „nie zweimal hintereinander denselben Satz“ will, gibt den
## zuletzt gezeigten Satz als `last` mit.
##
## Platzhalter: {name} (Charakter), {tag} („Tag 3 · Tiere“ oder „die Welt des Tages“, nie am Satzanfang),
## {streak} (Zahl), {ziel} (Ziel der Welt des Tages, z. B. „5 Wäldern“).
##
##   CharacterTexts.line("win_3", "frech")                       # -> „Drei Sterne?! Okay, …“
##   CharacterTexts.line("praise", "lieb", {}, rng, letzter_satz) # zufällig, nie derselbe wie letzter_satz
##   CharacterTexts.face("miss")                                 # -> „worried“

const TONES := ["lieb", "frech", "streng"]

## Schlüssel -> {lieb, frech, streng}; ein Wert ist ein Satz oder eine Liste von Sätzen (zufällig).
const LINES := {
	# 4.1 Vorstellung (Ziel-Karte von Tag 1, erste Zeile)
	"intro": {
		"lieb": "Hallo, ich bin {name}! Heute erschaffen wir zusammen eine Welt.",
		"frech": "Hi, ich bin {name}. Ich zeig dir, wie man eine Welt baut. Ist ganz leicht. Meistens.",
		"streng": "Ich bin {name}. Ich zeige dir, wie man eine Welt erschafft. Pass gut auf.",
	},
	# 4.2 Tages-Hinweise (Days.DAYS[n].coach / coach_demo / coach_tool in dieser Reihenfolge)
	"d1_demo": {
		"lieb": "Schau zu: Ich dreh einmal für dich – drei Erden in einer geraden Reihe werden eine Wiese.",
		"frech": "Pass auf, ich zeig's dir einmal: Drei Erden in einer geraden Reihe werden eine Wiese.",
		"streng": "Schau genau hin: Drei Erden in einer geraden Reihe werden eine Wiese.",
	},
	"d1_c0": {
		"lieb": "Dreh mal eine Scheibe! Drei Erden in einer geraden Reihe werden eine Wiese.",
		"frech": "Los, dreh! Drei Erden in einer geraden Reihe – zack, eine Wiese.",
		"streng": "Dreh eine Scheibe. Drei Erden in einer geraden Reihe werden eine Wiese.",
	},
	"d1_c1": {
		"lieb": "Aus drei Erden wird eine Wiese. Wie schön!",
		"frech": "Drei Erden, eine Wiese. Nicht schlecht für den Anfang!",
		"streng": "Richtig. Aus drei Erden wird eine Wiese.",
	},
	"d1_c2": {
		"lieb": "Jetzt du! Wisch über die leuchtende Scheibe – oder finde selbst drei Erden.",
		"frech": "Dein Zug! Wisch über die leuchtende Scheibe – oder such dir selbst drei Erden.",
		"streng": "Jetzt du. Wisch über die leuchtende Scheibe – oder finde selbst drei Erden.",
	},
	"d1_c3": {
		"lieb": "Gut so! Das ist jetzt deine Welt.",
		"frech": "Läuft! Ab jetzt bist du hier der Boss.",
		"streng": "Gut. Diese Welt gehört jetzt dir. Pass gut auf sie auf.",
	},
	"d2_c0": {
		"lieb": "Heute wächst Wald: Drei Wiesen in einer Reihe werden ein Wald.",
		"frech": "Wiesen sind langweilig. Drei in einer Reihe – und es wird ein Wald!",
		"streng": "Heute: Wald. Drei Wiesen in einer Reihe werden ein Wald.",
	},
	"d2_c1": {
		"lieb": "Vorsicht: Wächst bei der nächsten Drehung wieder nichts, brennt es. Regen löscht Feuer.",
		"frech": "Uff, gleich wird's heiß! Wächst beim nächsten Mal nichts, brennt es. Regen löscht Feuer.",
		"streng": "Achtung. Wächst bei der nächsten Drehung nichts, brennt es. Regen löscht Feuer.",
	},
	"d2_tool": {
		"lieb": "Probier den Regen: Tipp drauf und dann auf eine Wiese – sie wird sofort ein Wald.",
		"frech": "Abkürzung gefällig? Tipp auf Regen, dann auf eine Wiese – schwupp, ein Wald.",
		"streng": "Nutze den Regen: Tipp drauf, dann auf eine Wiese. Sie wird sofort ein Wald.",
	},
	"d3_c0": {
		"lieb": "Drei Wälder werden ein großer Wald. Und drei große Wälder bringen Tiere!",
		"frech": "Drei Wälder? Großer Wald. Drei große Wälder? Tiere! So einfach.",
		"streng": "Drei Wälder werden ein großer Wald. Drei große Wälder bringen Tiere. Merk dir das.",
	},
	"d4_c0": {
		"lieb": "Drei Tiere in einer Reihe – und Menschen ziehen ein. Eine Hütte!",
		"frech": "Drei Tiere in einer Reihe, und schon stehen Menschen vor der Tür. Eine Hütte!",
		"streng": "Drei Tiere in einer Reihe: Menschen ziehen ein. Eine Hütte.",
	},
	"d4_c1": {
		"lieb": "Die Menschen wünschen sich etwas. Erfüll den Wunsch – dann wächst ihr Haus.",
		"frech": "Die haben schon Wünsche! Erfüll den Wunsch – dann wächst ihr Haus.",
		"streng": "Ein Wunsch. Erfüll ihn – dann wächst ihr Haus.",
	},
	"d5_c0": {
		"lieb": "Jetzt entscheidest du: Aus drei Wiesen wird Wald oder Acker. Ein Acker macht die Menschen satt.",
		"frech": "Du hast die Wahl: Wald oder Acker? Kleiner Tipp: Hungrige Menschen lieben Äcker.",
		"streng": "Du entscheidest: Aus drei Wiesen wird Wald oder Acker. Ein Acker macht die Menschen satt.",
	},
	"d6_c0": {
		"lieb": "Eine Kirche bringt jede Runde Glauben. Aber bitte nie zwei Kirchen zusammen – das gibt Krieg.",
		"frech": "Kirchen bringen Glauben. Zwei Kirchen nebeneinander? Gibt Streit. Großen Streit.",
		"streng": "Eine Kirche bringt jede Runde Glauben. Bring nie zwei Kirchen zusammen. Das gibt Krieg.",
	},
	"d7_c0": {
		"lieb": "Industrie bringt viel Glauben – aber zu viel Stadt macht die Luft schmutzig. Bring die Waage ins Grüne: mit Wald oder einem Gewitter über einer Fabrik.",
		"frech": "Fabriken sind fleißig, aber sie stinken. Halt die Waage im Grünen: mehr Wald – oder ein kleines Gewitter auf die Fabrik.",
		"streng": "Industrie bringt viel Glauben, aber auch Smog. Halte die Waage im Grünen: mit Wald oder einem Gewitter über einer Fabrik.",
	},
	# 4.2 Allgemeine Hinweise (ui.COACH)
	"miss": {
		"lieb": "Hier ist nichts gewachsen. Bei 3 Flammen fängt die Reihe Feuer.",
		"frech": "Nix gewachsen! Bei 3 Flammen wird's heiß – dann brennt die Reihe.",
		"streng": "Hier ist nichts gewachsen. Bei 3 Flammen brennt die Reihe.",
	},
	"fire": {
		"lieb": "Oh nein, Feuer! Gieß die brennenden Felder mit Regen – sonst schrumpfen sie.",
		"frech": "Es brennt! Schnell Regen drauf – sonst schrumpfen die Felder.",
		"streng": "Feuer. Gieß die brennenden Felder mit Regen, sonst schrumpfen sie.",
	},
	"war": {
		"lieb": "Oh weh, Krieg! Zwei Kirchen haben sich getroffen. Halte sie auseinander.",
		"frech": "Krach! Zwei Kirchen haben sich getroffen. Lass die mal schön getrennt.",
		"streng": "Krieg. Zwei Kirchen haben sich getroffen. Halte sie auseinander.",
	},
	"smog": {
		"lieb": "Die Luft ist schmutzig. Wälder welken, Tiere fliehen. Pflanz Wald oder schick ein Gewitter auf die Industrie.",
		"frech": "Puh, Smog! Wälder welken, Tiere hauen ab. Mehr Wald – oder ein Gewitter auf die Fabrik.",
		"streng": "Smog. Wälder welken, Tiere fliehen. Pflanz Wald oder strafe die Industrie.",
	},
	"hint": {
		"lieb": "Kommst du nicht weiter? Tipp zeigt dir die beste Drehung – heute gratis.",
		"frech": "Hängst du fest? Tipp verrät dir den besten Zug. Kostet heute nix.",
		"streng": "Kommst du nicht weiter? Tipp zeigt die beste Drehung. Heute gratis.",
	},
	"hold": {
		"lieb": "Halte ein Symbol gedrückt – dann erklär ich es dir.",
		"frech": "Psst: Halte ein Symbol gedrückt, dann erklär ich's dir.",
		"streng": "Halte ein Symbol gedrückt. Dann erkläre ich es dir.",
	},
	"mini": {
		"lieb": "Ab jetzt fragt eine kleine Pille über dem Feld. Tipp schnell das andere Bild – oder halte sie für die große Karte.",
		"frech": "Ab jetzt fragt eine kleine Pille über dem Feld. Tipp schnell das andere Bild – oder halte sie für die große Karte.",
		"streng": "Ab jetzt fragt eine kleine Pille über dem Feld. Tipp schnell das andere Bild – oder halte sie für die große Karte.",
	},
	"rest": {
		"lieb": "Das wächst erst an einem späteren Tag. Morgen wächst hier mehr!",
		"frech": "Geduld, Geduld! Morgen wächst hier mehr.",
		"streng": "Nicht heute. Morgen wächst hier mehr.",
	},
	# 4.3 Lob, Sieg, Fehlversuch
	"praise": {
		"lieb": ["Wie schön!", "Toll gemacht!", "Das wächst ja prima!", "Hach, schön grün!", "Super!"],
		"frech": ["Zack!", "Läuft bei dir!", "Nicht übel!", "Hui!", "Das hab ich dir beigebracht!"],
		"streng": ["Gut.", "Ordentlich.", "So ist es richtig.", "Sauber gedreht.", "Weiter so."],
	},
	"surprise": {"lieb": "Oje!", "frech": "Uiuiui!", "streng": "Achtung!"},
	"win_1": {
		"lieb": "Geschafft! Ich bin stolz auf dich.",
		"frech": "Geschafft! Knapp, aber wer zählt schon mit?",
		"streng": "Geschafft. Mit weniger Drehungen gibt es mehr Sterne.",
	},
	"win_2": {
		"lieb": "Zwei Sterne – richtig gut!",
		"frech": "Zwei Sterne. Der dritte schaut schon neidisch.",
		"streng": "Zwei Sterne. Gute Arbeit.",
	},
	"win_3": {
		"lieb": "Drei Sterne! Du bist ein Naturtalent.",
		"frech": "Drei Sterne?! Okay, du darfst ein bisschen angeben.",
		"streng": "Drei Sterne. Ausgezeichnet.",
	},
	"fail": {
		"lieb": "Nicht schlimm! Neue Welt, neues Glück.",
		"frech": "Na, das war nix. Nochmal – diesmal mit Schwung!",
		"streng": "Noch nicht. Versuch es nochmal – du bekommst mehr Drehungen.",
	},
	"fail_war": {
		"lieb": "Die Kirchen haben sich gestritten. Nochmal – halte sie auseinander.",
		"frech": "Streit unter Kirchen, typisch. Nochmal, aber schön auseinander!",
		"streng": "Krieg heißt: nochmal. Halte die Kirchen auseinander.",
	},
	# 4.4 Serie
	"streak_1": {
		"lieb": "Deine Serie beginnt: Tag 1! Morgen machen wir weiter.",
		"frech": "Serie gestartet! Mal sehen, ob du morgen wiederkommst …",
		"streng": "Tag 1 deiner Serie. Morgen geht es weiter.",
	},
	"streak_n": {
		"lieb": "{streak} Tage in Folge! Ich freu mich jeden Tag auf dich.",
		"frech": "{streak} Tage am Stück! Du wirst ja richtig zuverlässig.",
		"streng": "{streak} Tage in Folge. So wird eine Welt gebaut.",
	},
	"streak_7": {
		"lieb": "Eine ganze Woche! Dafür schenk ich dir einen Serienschutz.",
		"frech": "7 Tage! Eine Woche Schöpfung – kommt mir bekannt vor. Hier, ein Serienschutz.",
		"streng": "Sieben Tage. Eine Woche Schöpfung. Dafür bekommst du einen Serienschutz.",
	},
	"streak_7_full": {
		"lieb": "Eine ganze Woche! Dein Serienschutz ist schon voll – hier sind 3 Münzen.",
		"frech": "7 Tage! Schutz hast du genug, also: 3 Münzen. Nicht alles auf einmal ausgeben!",
		"streng": "Sieben Tage. Dein Schutz ist voll. Du bekommst 3 Münzen.",
	},
	"streak_big": {
		"lieb": "{streak} Tage! Unglaublich – danke, dass du immer wiederkommst.",
		"frech": "{streak} Tage?! Ich brauche einen größeren Kalender.",
		"streng": "{streak} Tage. Bemerkenswert. Weiter so.",
	},
	"shield_bought": {
		"lieb": "Gut aufgepasst! Jetzt ist deine Serie geschützt.",
		"frech": "Schlau! Jetzt kann dir ein freier Tag nichts anhaben.",
		"streng": "Vernünftig. Deine Serie ist geschützt.",
	},
	# 4.5 Wiederkommen (einmal beim ersten Öffnen nach verpassten Tagen)
	"comeback_saved": {
		"lieb": "Da bist du ja! Dein Serienschutz hat deine Serie gerettet.",
		"frech": "Glück gehabt! Dein Serienschutz hat die Serie gerettet. Ich hab nichts gesehen.",
		"streng": "Du warst weg. Dein Serienschutz hat die Serie gerettet. Heute spielen wir.",
	},
	"comeback_lost": {
		"lieb": "Schön, dass du wieder da bist! Wir fangen einfach neu an – heute ist Tag 1.",
		"frech": "Ah, da bist du ja! Ich hab schon Staub angesetzt. Neue Serie, los geht's!",
		"streng": "Willkommen zurück. Die alte Serie ist vorbei. Die neue beginnt heute.",
	},
	"open": {
		"lieb": "Hallo! Schön, dich zu sehen.",
		"frech": "Na, auch wieder da?",
		"streng": "Gut, dass du da bist.",
	},
	"open_night": {
		"lieb": "Gähn … Schön, dass du da bist. Aber nicht zu lange, ja?",
		"frech": "Gähn! Du bist ja eine richtige Nachteule.",
		"streng": "Es ist spät. Eine kurze Runde, dann wird geschlafen.",
	},
	# 4.6 Übersicht und Tagesablauf
	"day_open": {
		"lieb": "Heute wartet {tag} auf dich. Ich freu mich schon!",
		"frech": "Heute gibt's {tag}. Ich hab schon reingeschaut. Ein bisschen.",
		"streng": "Heute steht {tag} an. Fangen wir an.",
	},
	"day_done": {
		"lieb": "Für heute ist alles geschafft. Morgen geht's weiter mit {tag}!",
		"frech": "Hey, nicht vordrängeln! {tag} kommt morgen.",
		"streng": "Geduld. Eine Welt entsteht Tag für Tag. Morgen: {tag}.",
	},
	"wdt_open": {
		"lieb": "Ich hab dir eine neue Welt gebaut. Magst du sie dir ansehen?",
		"frech": "Neue Welt, frisch gewürfelt! Schaffst du sie?",
		"streng": "Die Welt des Tages ist bereit. Zeig, was du kannst.",
	},
	"wdt_done": {
		"lieb": "Geschafft! Morgen bau ich dir eine neue Welt.",
		"frech": "Erledigt! Morgen würfle ich dir was Neues.",
		"streng": "Erledigt. Morgen gibt es eine neue Welt.",
	},
	"weiterbauen": {
		"lieb": "Du kannst hier noch weiterbauen – ganz ohne Drehungs-Grenze.",
		"frech": "Bonusrunde! Bau weiter, so lange du willst. Ohne Limit.",
		"streng": "Das Ziel ist erreicht. Du darfst weiterbauen, ohne Grenze.",
	},
	"wdt_intro": {
		"lieb": "Heute eine Welt mit {ziel}. Viel Spaß!",
		"frech": "Heute: {ziel}. Das schaffst du locker. Wahrscheinlich.",
		"streng": "Heute: {ziel}. Konzentrier dich.",
	},
	# Ersteller und Erinnerung (3.7, 5.7)
	"ask_reminder": {
		"lieb": "Soll ich dich morgen erinnern, wenn {tag} bereit ist? Höchstens einmal am Tag – versprochen.",
		"frech": "Soll ich dir morgen Bescheid sagen, wenn {tag} da ist? Nur einmal am Tag, Ehrenwort.",
		"streng": "Ich erinnere dich morgen an {tag}. Einmal am Tag, nicht öfter. Einverstanden?",
	},
	"ask_yes": {
		"lieb": "Schön! Dann sag ich dir morgen Bescheid.",
		"frech": "Abgemacht! Ich melde mich.",
		"streng": "Gut. Ich erinnere dich.",
	},
	"ask_no": {
		"lieb": "Alles klar! Du findest mich ja auch so.",
		"frech": "Okay, okay. Ich warte dann einfach hier.",
		"streng": "Wie du willst. Die Welt wartet.",
	},
}

## Gesicht zu einem Schlüssel (Abschnitt 3.5 / 4.2). Fehlt ein Schlüssel: „neutral“.
const FACE := {
	"intro": "happy", "d1_demo": "happy", "d1_c1": "happy", "d1_c3": "proud", "d2_c1": "worried", "d2_tool": "cheeky",
	"d6_c0": "worried", "d7_c0": "worried",
	"miss": "worried", "fire": "worried", "war": "worried", "smog": "worried", "hint": "cheeky", "hold": "happy",
	"mini": "neutral", "wish": "happy", "rest": "cheeky",
	"praise": "happy", "surprise": "worried", "win_1": "proud", "win_2": "proud", "win_3": "proud", "fail": "neutral",
	"fail_war": "neutral",
	"streak_1": "proud", "streak_n": "proud", "streak_7": "proud", "streak_7_full": "proud", "streak_big": "proud",
	"shield_bought": "happy",
	"comeback_saved": "happy", "comeback_lost": "sad", "open": "happy", "open_night": "sleepy",
	"day_open": "happy", "day_done": "cheeky", "wdt_open": "happy", "wdt_done": "proud", "weiterbauen": "happy",
	"wdt_intro": "neutral", "ask_reminder": "happy", "ask_yes": "happy", "ask_no": "neutral",
}

## 4.7 Benachrichtigungen. Titel = {name}. cat: A (1. Tag nach dem Spielen), B (2.), C (4.), F (Abschied, 7.).
## streak: nur wenn die Serie mindestens 2 ist. B und C nutzen nie Serien-Texte.
const NOTIFY := {
	"lieb": [
		{"id": "l01", "cat": "A", "text": "Hallo! Heute wartet {tag} auf dich."},
		{"id": "l02", "cat": "A", "text": "Deine Welt ist aufgewacht. Kommst du sie besuchen?"},
		{"id": "l03", "cat": "A", "text": "Ich hab Regen für dich aufgehoben. Spielen wir eine Runde?"},
		{"id": "l04", "cat": "A", "text": "Ein paar Drehungen, und deine Welt wird wieder ein Stück grüner."},
		{"id": "l05", "cat": "A", "streak": true, "text": "Deine Serie: {streak} Tage! Machen wir heute weiter?"},
		{"id": "l06", "cat": "A", "text": "Die Wiesen fragen schon nach dir. Schaust du kurz vorbei?"},
		{"id": "l07", "cat": "A", "text": "Heute ist ein guter Tag für {tag}. Ich freu mich auf dich!"},
		{"id": "l08", "cat": "A", "text": "Nur fünf Minuten? Mehr braucht deine Welt heute nicht."},
		{"id": "l09", "cat": "B", "text": "Ich hab dich gestern vermisst. Hast du heute ein bisschen Zeit?"},
		{"id": "l10", "cat": "B", "text": "Deine Welt ist ein bisschen still ohne dich. Kommst du heute?"},
		{"id": "l11", "cat": "B", "text": "Kein Stress! Wenn du Zeit hast: {tag} ist bereit."},
		{"id": "l12", "cat": "C", "text": "Ich denk an dich! Deine Welt ist noch da – genau wie ich."},
		{"id": "l13", "cat": "C", "text": "Wir können jederzeit neu anfangen. Ich warte gern auf dich."},
		{"id": "l14", "cat": "C", "text": "Schau doch mal wieder rein. Ich hab dir viel zu zeigen!"},
		{"id": "lF", "cat": "F", "text": "Ich erinnere dich jetzt nicht mehr. Deine Welt und ich sind da, wenn du wiederkommst. Alles Liebe!"},
	],
	"frech": [
		{"id": "f01", "cat": "A", "text": "Psst! {tag} ist da. Ich hab nicht reingeschaut. Fast nicht."},
		{"id": "f02", "cat": "A", "text": "Deine Welt dreht sich nicht von allein. Hilfst du mir?"},
		{"id": "f03", "cat": "A", "text": "Mir ist langweilig. Rettest du mich mit ein paar Drehungen?"},
		{"id": "f04", "cat": "A", "text": "Die Wiesen wollen Wald werden. Ich kann das nicht – du schon."},
		{"id": "f05", "cat": "A", "streak": true, "text": "{streak} Tage am Stück! Machen wir heute einen mehr draus?"},
		{"id": "f06", "cat": "A", "text": "Achtung, Durchsage: {name} sucht Gesellschaft. Belohnung: Spaß!"},
		{"id": "f07", "cat": "A", "text": "Ich hab ganz zufällig Regen übrig. Willst du?"},
		{"id": "f08", "cat": "A", "text": "Kurze Frage: Wer hat hier die Welt erschaffen? Genau, du. Weiter geht's!"},
		{"id": "f09", "cat": "B", "text": "Gestern keine Drehung? Ich hab's gesehen. Ich sag's aber keinem."},
		{"id": "f10", "cat": "B", "text": "Huhu! Deine Welt hat ein kleines bisschen Staub angesetzt. Kommst du?"},
		{"id": "f11", "cat": "B", "text": "Ich hab Kekse. Okay, hab ich nicht. Aber {tag} hab ich!"},
		{"id": "f12", "cat": "C", "text": "Ich hab angefangen, mit den Wolken zu reden. Komm bitte zurück!"},
		{"id": "f13", "cat": "C", "text": "Lange nicht gesehen! Ich hab neue Witze. Und deine Welt."},
		{"id": "f14", "cat": "C", "text": "Hallooo? Ist da wer? Deine Welt würde gern weiterwachsen."},
		{"id": "fF", "cat": "F", "text": "Okay, ich hab's kapiert: Pause! Ich bin jetzt still. Aber wenn du wiederkommst, freu ich mich riesig."},
	],
	"streng": [
		{"id": "s01", "cat": "A", "text": "Die Welt wartet. Heute ist {tag} bereit."},
		{"id": "s02", "cat": "A", "text": "Zeit für deine tägliche Schöpfung. Ein paar Minuten genügen."},
		{"id": "s03", "cat": "A", "text": "Ordnung muss sein: heute eine Runde. Ich zähle auf dich."},
		{"id": "s04", "cat": "A", "text": "Eine Welt baut sich nicht von selbst. Fangen wir an."},
		{"id": "s05", "cat": "A", "streak": true, "text": "{streak} Tage in Folge. So eine Serie pflegt man."},
		{"id": "s06", "cat": "A", "text": "Heute steht {tag} an. Pünktlich, bitte."},
		{"id": "s07", "cat": "A", "text": "Die Wiesen stehen bereit. Es fehlt nur noch jemand, der dreht."},
		{"id": "s08", "cat": "A", "text": "Eine Runde am Tag. Das ist der Plan. Bleib dabei."},
		{"id": "s09", "cat": "B", "text": "Gestern war Pause. Heute geht es weiter."},
		{"id": "s10", "cat": "B", "text": "Deine Welt hat heute noch nichts von dir gehört. Eine Runde?"},
		{"id": "s11", "cat": "B", "text": "Kurze Erinnerung: {tag} ist bereit. Mehr verlange ich nicht."},
		{"id": "s12", "cat": "C", "text": "Es ist ruhig geworden. Wenn du bereit bist, machen wir weiter."},
		{"id": "s13", "cat": "C", "text": "Deine Welt ist in Ordnung. Ich habe aufgepasst. Kommst du zurück?"},
		{"id": "s14", "cat": "C", "text": "Jede Welt verdient eine zweite Chance. Deine auch."},
		{"id": "sF", "cat": "F", "text": "Ich erinnere dich nicht mehr. Deine Welt bleibt, wie sie ist. Wenn du wiederkommst: Ich bin bereit."},
	],
}

## Gesicht im großen Benachrichtigungs-Bild (5.6) je Kategorie.
const NOTIFY_FACE := {"A": "happy", "B": "worried", "C": "neutral", "F": "sleepy"}


## Alle Varianten eines Schlüssels für einen Ton (unbekannter Ton -> lieb, unbekannter Schlüssel -> []).
static func variants(key: String, ton: String) -> Array:
	if not LINES.has(key):
		return []
	var byt: Dictionary = LINES[key]
	var t := ton if byt.has(ton) else "lieb"
	var v: Variant = byt[t]
	if v is Array:
		return (v as Array).duplicate()
	return [String(v)]


## Ein Satz mit gefüllten Platzhaltern. Bei mehreren Varianten zufällig (rng oder global), nie gleich `last`.
static func line(key: String, ton: String, args: Dictionary = {}, rng: RandomNumberGenerator = null, last: String = "") -> String:
	var vs := variants(key, ton)
	if vs.is_empty():
		return ""
	var pool: Array = []
	for v in vs:
		if fill(String(v), args) != last:
			pool.append(v)
	if pool.is_empty():
		pool = vs
	var i := 0
	if pool.size() > 1:
		i = rng.randi_range(0, pool.size() - 1) if rng != null else randi_range(0, pool.size() - 1)
	return fill(String(pool[i]), args)


## Platzhalter füllen: {name}, {tag}, {streak}, {ziel}. Unbekannte bleiben stehen.
static func fill(text: String, args: Dictionary) -> String:
	var out := text
	for k in args:
		out = out.replace("{" + String(k) + "}", str(args[k]))
	return out.strip_edges()


static func face(key: String) -> String:
	return String(FACE.get(key, "neutral"))


## Benachrichtigungs-Vorlagen eines Tons und einer Kategorie. with_streak: Serien-Texte (S) erlaubt.
## C ohne unbenutzte Texte darf A-Texte nehmen (das entscheidet der Plan, nicht diese Liste).
static func notifications(ton: String, cat: String, with_streak: bool = true) -> Array:
	var all: Array = NOTIFY.get(ton, NOTIFY["lieb"])
	var out: Array = []
	for n_v in all:
		var n: Dictionary = n_v
		if String(n["cat"]) != cat:
			continue
		if n.get("streak", false) and (not with_streak or cat != "A"):
			continue
		out.append(n)
	return out


static func notification_by_id(id: String) -> Dictionary:
	for ton in NOTIFY:
		for n_v in NOTIFY[ton]:
			var n: Dictionary = n_v
			if String(n["id"]) == id:
				return n
	return {}
