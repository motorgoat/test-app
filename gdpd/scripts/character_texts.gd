class_name CharacterTexts
extends RefCounted
## Was der eigene Charakter sagt, je Ton (lieb / frech / streng). Spec: docs/GDPD_TAEGLICH_CHARAKTER.md, Abschnitt 4.
## Nur Daten und reine Hilfen (kein Zustand): Wer „nie zweimal hintereinander denselben Satz“ will, gibt den
## zuletzt gezeigten Satz als `last` mit.
##
## Platzhalter: {name} (Charakter), {tag} („Tag 3: Tiere“ oder „die Welt des Tages“, nie am Satzanfang),
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
		"lieb": "Hallo, ich bin {name}!",
		"frech": "Hi, ich bin {name}. Los!",
		"streng": "Ich bin {name}. Pass auf.",
	},
	# 4.2 Tages-Hinweise (Days.DAYS[n].coach / coach_demo / coach_tool in dieser Reihenfolge)
	"d1_demo": {
		"lieb": "Schau: 3 gleiche in eine Reihe!",
		"frech": "Pass auf: 3 gleiche in eine Reihe!",
		"streng": "3 gleiche in eine Reihe. Schau.",
	},
	"d1_c0": {
		"lieb": "Bring 3 gleiche in eine Reihe!",
		"frech": "Los: 3 gleiche in eine Reihe!",
		"streng": "Bring 3 gleiche in eine Reihe.",
	},
	"d1_c1": {
		"lieb": "Eine Wiese! Wie schön!",
		"frech": "Zack, eine Wiese!",
		"streng": "Richtig. Eine Wiese.",
	},
	"l1_c1": {
		"lieb": "Ein Fels! Wie schön!",
		"frech": "Zack, ein Fels!",
		"streng": "Richtig. Ein Fels.",
	},
	"d1_c2": {
		"lieb": "Jetzt du! Wisch die leuchtende Reihe.",
		"frech": "Dein Zug! Wisch die leuchtende Reihe.",
		"streng": "Jetzt du. Wisch die leuchtende Reihe.",
	},
	# Tutorial: Wisch ging daneben (1.) / öfter daneben (Tipp zeigen)
	"d1_retry": {
		"lieb": "Fast! Wisch die leuchtende Reihe.",
		"frech": "Knapp! Die leuchtende Reihe!",
		"streng": "Die leuchtende Reihe.",
	},
	"d1_hint": {
		"lieb": "Drück die Lampe. Sie hilft.",
		"frech": "Drück die Lampe!",
		"streng": "Drück die Lampe.",
	},
	"d1_c3": {
		"lieb": "Gut so! Deine Welt.",
		"frech": "Läuft! Du bist der Boss.",
		"streng": "Gut. Pass auf deine Welt auf.",
	},
	# Ziel-Karte ab Tag 2: der erste Satz im Ton des Charakters (sonst Days.DAYS[n].intro)
	"d2_intro": {"lieb": "Heute wachsen Pflanzen!", "frech": "Heute: Pflanzen! Los!", "streng": "Heute: Pflanzen."},
	"d3_intro": {"lieb": "Heute kommen Tiere. Und Blitze.", "frech": "Tiere! Und Blitze!", "streng": "Heute: Tiere, Blitz."},
	"d4_intro": {"lieb": "Heute kommen Menschen!", "frech": "Menschen! Jetzt wird's laut.", "streng": "Heute: Menschen."},
	"d5_intro": {"lieb": "Die Menschen wollen arbeiten.", "frech": "Arbeit! Dörfer bauen!", "streng": "Heute: Arbeit."},
	"d6_intro": {"lieb": "Die Menschen beten zu dir.", "frech": "Sie beten dich an!", "streng": "Heute: Glaube."},
	"d7_intro": {"lieb": "Schütze jetzt die Natur.", "frech": "Jetzt die Natur retten!", "streng": "Heute: Natur schützen."},
	"d2_c0": {
		"lieb": "Heute wächst Wald!",
		"frech": "Wiesen? Langweilig. Mach Wald!",
		"streng": "Heute: Wald.",
	},
	"d2_c1": {
		"lieb": "Regen macht Wald.",
		"frech": "Regen drauf: Wald!",
		"streng": "Regen: Wiese wird Wald.",
	},
	"d2_tool": {
		"lieb": "Tipp Regen, dann eine Wiese.",
		"frech": "Abkürzung: Regen auf eine Wiese!",
		"streng": "Regen auf eine Wiese: Wald.",
	},
	"d3_c0": {
		"lieb": "Blitz kommt! Regen schützt.",
		"frech": "Achtung, Blitz! Regen hilft.",
		"streng": "Blitz: Regen schützt.",
	},
	"d4_c0": {
		"lieb": "Tiere neben die Hütte.",
		"frech": "Hunger! Tiere daneben!",
		"streng": "Tiere neben die Hütte.",
	},
	"d4_c1": {
		"lieb": "Satt? Dann wächst es.",
		"frech": "Satt? Dann wird's mehr!",
		"streng": "Satt: es wächst.",
	},
	"d5_c0": {
		"lieb": "Wald oder Stein gibt Arbeit.",
		"frech": "Arbeit? Wald oder Stein!",
		"streng": "Arbeit: Wald oder Stein.",
	},
	"d6_c0": {
		"lieb": "Stadt braucht eine Kirche.",
		"frech": "Kirche daneben, aber nur eine!",
		"streng": "Stadt braucht eine Kirche.",
	},
	"d7_c0": {
		"lieb": "Fabrik weg vom Wald.",
		"frech": "Fabriken stinken. Weg vom Wald!",
		"streng": "Fabrik weg vom Wald.",
	},
	# 4.2 Allgemeine Hinweise (ui.COACH)
	"miss": {
		"lieb": "Nichts gewachsen. 3 Flammen: Feuer.",
		"frech": "Nix gewachsen! Gleich wird's heiß.",
		"streng": "Nichts gewachsen. 3 Flammen: Feuer.",
	},
	"fire": {
		"lieb": "Feuer! Gieß es mit Regen.",
		"frech": "Es brennt! Regen drauf!",
		"streng": "Feuer. Regen drauf.",
	},
	"war": {
		"lieb": "Oh weh, Krieg!",
		"frech": "Krach! Kirchen-Krieg!",
		"streng": "Krieg. Halte Kirchen auseinander.",
	},
	"smog": {
		"lieb": "Smog! Pflanz mehr Wald.",
		"frech": "Puh, Smog! Mehr Wald!",
		"streng": "Smog. Pflanz Wald.",
	},
	"hint": {
		"lieb": "Fest? Tipp hilft – heute gratis.",
		"frech": "Hängst du? Tipp ist gratis.",
		"streng": "Tipp zeigt die beste Drehung.",
	},
	"hold": {
		"lieb": "Halte ein Symbol für Hilfe.",
		"frech": "Psst: Symbol gedrückt halten!",
		"streng": "Halte ein Symbol gedrückt.",
	},
	"mini": {
		"lieb": "Tipp schnell das andere Bild.",
		"frech": "Tipp schnell das andere Bild.",
		"streng": "Tipp schnell das andere Bild.",
	},
	"rest": {
		"lieb": "Das wächst erst später.",
		"frech": "Geduld! Morgen mehr.",
		"streng": "Nicht heute.",
	},
	# 4.3 Lob, Sieg, Fehlversuch
	"praise": {
		"lieb": ["Wie schön!", "Toll gemacht!", "Das wächst ja prima!", "Hach, schön grün!", "Super!"],
		"frech": ["Zack!", "Läuft bei dir!", "Nicht übel!", "Hui!", "Hab ich dir beigebracht!"],
		"streng": ["Gut.", "Ordentlich.", "So ist es richtig.", "Sauber gedreht.", "Weiter so."],
	},
	"surprise": {
		"lieb": "Oje!",
		"frech": "Uiuiui!",
		"streng": "Achtung!",
	},
	"win_1": {
		"lieb": "Geschafft! Ich bin stolz.",
		"frech": "Geschafft! Knapp, aber egal.",
		"streng": "Geschafft. Gut.",
	},
	"win_2": {
		"lieb": "Zwei Sterne – super!",
		"frech": "Zwei Sterne. Fast!",
		"streng": "Zwei Sterne. Gut.",
	},
	"win_3": {
		"lieb": "Drei Sterne! Naturtalent!",
		"frech": "Drei Sterne?! Angeber!",
		"streng": "Drei Sterne. Ausgezeichnet.",
	},
	"fail": {
		"lieb": "Nicht schlimm! Neues Glück!",
		"frech": "Das war nix. Auf ein Neues!",
		"streng": "Konzentrier dich. Nächster Versuch.",
	},
	"fail_war": {
		"lieb": "Halte die Kirchen auseinander.",
		"frech": "Kirchen auseinander! Nochmal!",
		"streng": "Kirchen auseinander halten.",
	},
	# 4.4 Serie
	"streak_1": {
		"lieb": "Deine Serie beginnt!",
		"frech": "Serie gestartet!",
		"streng": "Tag 1 deiner Serie.",
	},
	"streak_n": {
		"lieb": "{streak} Tage in Folge!",
		"frech": "{streak} Tage am Stück!",
		"streng": "{streak} Tage in Folge. Gut.",
	},
	"streak_7": {
		"lieb": "Eine Woche! Hier, ein Serienschutz.",
		"frech": "7 Tage! Hier, ein Serienschutz.",
		"streng": "Sieben Tage. Ein Serienschutz.",
	},
	"streak_7_full": {
		"lieb": "Eine Woche! Hier, 50 Punkte.",
		"frech": "7 Tage! 50 Punkte für dich.",
		"streng": "Sieben Tage. 50 Punkte.",
	},
	"streak_big": {
		"lieb": "{streak} Tage! Unglaublich!",
		"frech": "{streak} Tage?! Wahnsinn!",
		"streng": "{streak} Tage. Bemerkenswert.",
	},
	"shield_bought": {
		"lieb": "Deine Serie ist geschützt!",
		"frech": "Schlau! Serie geschützt.",
		"streng": "Vernünftig. Serie geschützt.",
	},
	# 4.5 Wiederkommen (einmal beim ersten Öffnen nach verpassten Tagen)
	"comeback_saved": {
		"lieb": "Da bist du ja! Serie gerettet.",
		"frech": "Glück gehabt! Serie gerettet.",
		"streng": "Der Schutz hat deine Serie gerettet.",
	},
	"comeback_lost": {
		"lieb": "Schön, dass du wieder da bist!",
		"frech": "Da bist du ja! Neue Serie!",
		"streng": "Neue Serie. Heute geht's los.",
	},
	"open": {
		"lieb": "Hallo! Schön, dich zu sehen.",
		"frech": "Na, auch wieder da?",
		"streng": "Gut, dass du da bist.",
	},
	"open_night": {
		"lieb": "Gähn … nicht zu lange, ja?",
		"frech": "Gähn! Du Nachteule!",
		"streng": "Spät. Nur eine Runde.",
	},
	# 4.6 Übersicht und Tagesablauf
	"day_open": {
		"lieb": "Heute wartet {tag}!",
		"frech": "Heute gibt's {tag}!",
		"streng": "Bereit für {tag}?",
	},
	"day_done": {
		"lieb": "Morgen kommt {tag}!",
		"frech": "Morgen gibt's {tag}!",
		"streng": "Morgen folgt {tag}.",
	},
	# Tippen auf den gesperrten Tag von morgen
	"day_wait": {
		"lieb": "Geduld! Morgen geht's weiter.",
		"frech": "Nicht drängeln! Erst morgen.",
		"streng": "Erst morgen.",
	},
	"wdt_open": {
		"lieb": "Eine neue Welt für dich!",
		"frech": "Neue Welt! Schaffst du's?",
		"streng": "Die Welt des Tages wartet.",
	},
	"wdt_done": {
		"lieb": "Geschafft! Morgen gibt's eine neue.",
		"frech": "Erledigt! Morgen was Neues.",
		"streng": "Erledigt. Morgen eine neue Welt.",
	},
	"weiterbauen": {
		"lieb": "Bau weiter, ohne Grenze!",
		"frech": "Bonusrunde! Ohne Limit!",
		"streng": "Weiterbauen. Ohne Grenze.",
	},
	"wdt_intro": {
		"lieb": "Heute: {ziel}. Viel Spaß!",
		"frech": "Heute: {ziel}. Locker!",
		"streng": "Heute: {ziel}.",
	},
	# Ersteller und Erinnerung (3.7, 5.7)
	"ask_reminder": {
		"lieb": "Morgen erinnern?",
		"frech": "Soll ich dich morgen erinnern?",
		"streng": "Ich erinnere dich morgen. Okay?",
	},
	"ask_yes": {
		"lieb": "Schön! Bis morgen!",
		"frech": "Abgemacht!",
		"streng": "Gut.",
	},
	"ask_no": {
		"lieb": "Alles klar!",
		"frech": "Okay, okay.",
		"streng": "Wie du willst.",
	},
}

## Gesicht zu einem Schlüssel (Abschnitt 3.5 / 4.2). Fehlt ein Schlüssel: „neutral“.
const FACE := {
	"intro": "happy", "l1_c1": "happy", "d1_demo": "happy", "d1_c1": "happy", "d1_c3": "proud", "d2_c1": "worried", "d2_tool": "cheeky",
	"d6_c0": "worried", "d7_c0": "worried",
	"d2_intro": "happy", "d3_intro": "happy", "d4_intro": "happy", "d5_intro": "worried", "d6_intro": "proud",
	"d7_intro": "neutral",
	"miss": "worried", "fire": "worried", "war": "worried", "smog": "worried", "hint": "cheeky", "hold": "happy",
	"mini": "neutral", "wish": "happy", "rest": "cheeky",
	"praise": "happy", "surprise": "worried", "win_1": "proud", "win_2": "proud", "win_3": "proud", "fail": "neutral",
	"fail_war": "neutral",
	"streak_1": "proud", "streak_n": "proud", "streak_7": "proud", "streak_7_full": "proud", "streak_big": "proud",
	"shield_bought": "happy",
	"comeback_saved": "happy", "comeback_lost": "sad", "open": "happy", "open_night": "sleepy",
	"day_open": "happy", "day_done": "happy", "day_wait": "cheeky", "d1_retry": "worried", "d1_hint": "cheeky", "wdt_open": "happy", "wdt_done": "proud", "weiterbauen": "happy",
	"wdt_intro": "neutral", "ask_reminder": "happy", "ask_yes": "happy", "ask_no": "neutral",
}

## 4.7 Benachrichtigungen. Titel = {name}. cat: A (1. Tag nach dem Spielen), B (2.), C (4.), F (Abschied, 7.).
## streak: nur wenn die Serie mindestens 2 ist. B und C nutzen nie Serien-Texte.
const NOTIFY := {
	"lieb": [
		{"id": "l01", "cat": "A", "text": "Heute wartet {tag}!"},
		{"id": "l02", "cat": "A", "text": "Deine Welt ist wach. Kommst du?"},
		{"id": "l03", "cat": "A", "text": "Ich hab Regen für dich!"},
		{"id": "l04", "cat": "A", "text": "Ein paar Drehungen?"},
		{"id": "l05", "cat": "A", "streak": true, "text": "{streak} Tage! Machen wir weiter?"},
		{"id": "l06", "cat": "A", "text": "Die Wiesen fragen nach dir."},
		{"id": "l07", "cat": "A", "text": "Heute ist {tag} dran!"},
		{"id": "l08", "cat": "A", "text": "Nur fünf Minuten?"},
		{"id": "l09", "cat": "B", "text": "Ich hab dich vermisst!"},
		{"id": "l10", "cat": "B", "text": "Ohne dich ist es still."},
		{"id": "l11", "cat": "B", "text": "Kein Stress! {tag} wartet."},
		{"id": "l12", "cat": "C", "text": "Ich denk an dich!"},
		{"id": "l13", "cat": "C", "text": "Ich warte gern auf dich."},
		{"id": "l14", "cat": "C", "text": "Schau mal wieder rein!"},
		{"id": "lF", "cat": "F", "text": "Ich bin jetzt still. Bis bald!"},
	],
	"frech": [
		{"id": "f01", "cat": "A", "text": "Psst! {tag} ist da."},
		{"id": "f02", "cat": "A", "text": "Deine Welt dreht sich nicht allein."},
		{"id": "f03", "cat": "A", "text": "Mir ist langweilig. Hilfe!"},
		{"id": "f04", "cat": "A", "text": "Die Wiesen wollen Wald werden."},
		{"id": "f05", "cat": "A", "streak": true, "text": "{streak} Tage! Einer mehr?"},
		{"id": "f06", "cat": "A", "text": "Ich such Gesellschaft!"},
		{"id": "f07", "cat": "A", "text": "Regen übrig. Willst du?"},
		{"id": "f08", "cat": "A", "text": "Wer hat die Welt erschaffen? Du!"},
		{"id": "f09", "cat": "B", "text": "Gestern nichts gedreht? Ich sag nix."},
		{"id": "f10", "cat": "B", "text": "Huhu! Deine Welt staubt ein."},
		{"id": "f11", "cat": "B", "text": "Hey, {tag} wartet!"},
		{"id": "f12", "cat": "C", "text": "Ich rede schon mit Wolken!"},
		{"id": "f13", "cat": "C", "text": "Lange nicht gesehen!"},
		{"id": "f14", "cat": "C", "text": "Hallooo? Jemand da?"},
		{"id": "fF", "cat": "F", "text": "Okay, Pause! Ich bin still."},
	],
	"streng": [
		{"id": "s01", "cat": "A", "text": "Heute ist {tag} bereit."},
		{"id": "s02", "cat": "A", "text": "Zeit für deine Schöpfung."},
		{"id": "s03", "cat": "A", "text": "Ich zähle auf dich."},
		{"id": "s04", "cat": "A", "text": "Die Welt baut sich nicht allein."},
		{"id": "s05", "cat": "A", "streak": true, "text": "{streak} Tage. Bleib dran."},
		{"id": "s06", "cat": "A", "text": "Bitte pünktlich zu {tag}."},
		{"id": "s07", "cat": "A", "text": "Die Wiesen warten auf dich."},
		{"id": "s08", "cat": "A", "text": "Eine Runde am Tag."},
		{"id": "s09", "cat": "B", "text": "Gestern Pause. Heute weiter."},
		{"id": "s10", "cat": "B", "text": "Deine Welt wartet auf dich."},
		{"id": "s11", "cat": "B", "text": "Zeit für {tag}."},
		{"id": "s12", "cat": "C", "text": "Wenn du bereit bist: weiter."},
		{"id": "s13", "cat": "C", "text": "Ich habe aufgepasst. Kommst du?"},
		{"id": "s14", "cat": "C", "text": "Jede Welt verdient eine Chance."},
		{"id": "sF", "cat": "F", "text": "Ich bin jetzt still. Bis dann."},
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
