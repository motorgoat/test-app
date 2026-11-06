class_name ReminderPlan
extends RefCounted
## Erinnerungen planen (docs/GDPD_TAEGLICH_CHARAKTER.md 4.7, 5.1–5.4): nur reine Funktionen – WANN erinnert wird
## und WELCHER Text. Das Planen beim Start/Fortsetzen/Pausieren und das Plugin macht der Aufrufer (Game.replan_reminders,
## das Android-Plugin „GdpdReminder“).
##
## Grundsätze: höchstens eine Erinnerung je Spieltag, nur wenn der Serientag noch nicht geschafft ist, etwa 23,5 h nach dem
## Start der letzten Sitzung, nie in der Ruhezeit 21:30–8:00, nie eine Warnung kurz vor Mitternacht. Wer nicht kommt,
## bekommt seltener eine (Leiter +1, +2, +4 Tage) und nach einer Woche eine freundliche letzte Nachricht – dann Ruhe, bis
## er wiederkommt (jeder Besuch fängt die Leiter neu an). Texte vom eigenen Charakter, nie zweimal hintereinander derselbe.
##
## plan(state, now) → Array von Einträgen
##   {"id" (101, 102, 104, 107), "at" (Ortszeit, lokale Unix-Sekunden), "key" (Spieltag), "cat" ("A"|"B"|"C"|"F"),
##    "tpl" (Text-ID), "title" (Name des Charakters), "body", "year", "month", "day", "hour", "minute"}
## state (alles optional, Standardwerte in brackets):
##   "today" [Daily.day_key(now)], "done_today" [false], "last_win_key" [-1], "last_open_key" [today],
##   "anchor_min" [-1 → 18:00], "mode" ["auto" | "fest" | "aus"], "fixed_min" [1080], "allowed" [true],
##   "tone" ["lieb" | "frech" | "streng"], "name" ["Gott"], "tag" ["Tag 1"], "streak" [0], "history" ([] neueste zuerst)

const MODES = ["auto", "fest", "aus"]
const TONES = ["lieb", "frech", "streng"]
const HISTORY_MAX := 8
const RECENT_BLOCK := 4         # die letzten 4 Texte nie wieder …
const RECENT_SOFT := 8          # … die 4 davor seltener (× 0,25)
const SOFT_WEIGHT := 0.25
const DEFAULT_NAME := "Gott"

## Kategorie je Stufe der Leiter: A = 1. Tag nach dem letzten Besuch, B = 2., C = 4., F = letzte Nachricht (7.).
const LADDER_CATS = ["A", "B", "C", "F"]

## Texte (4.7). s = nur bei einer Serie ab 2 Tagen. Platzhalter: {name}, {tag}, {streak}. Nie mit {tag} beginnen.
const TEMPLATES = {
	"lieb": [
		{"id": "l01", "cat": "A", "text": "Hallo! Heute wartet {tag} auf dich."},
		{"id": "l02", "cat": "A", "text": "Deine Welt ist aufgewacht. Kommst du sie besuchen?"},
		{"id": "l03", "cat": "A", "text": "Ich hab Regen für dich aufgehoben. Spielen wir eine Runde?"},
		{"id": "l04", "cat": "A", "text": "Ein paar Drehungen, und deine Welt wird wieder ein Stück grüner."},
		{"id": "l05", "cat": "A", "s": true, "text": "Deine Serie: {streak} Tage! Machen wir heute weiter?"},
		{"id": "l06", "cat": "A", "text": "Die Wiesen fragen schon nach dir. Schaust du kurz vorbei?"},
		{"id": "l07", "cat": "A", "text": "Heute ist ein guter Tag für {tag}. Ich freu mich auf dich!"},
		{"id": "l08", "cat": "A", "text": "Nur fünf Minuten? Mehr braucht deine Welt heute nicht."},
		{"id": "l09", "cat": "B", "text": "Ich hab dich gestern vermisst. Hast du heute ein bisschen Zeit?"},
		{"id": "l10", "cat": "B", "text": "Deine Welt ist ein bisschen still ohne dich. Kommst du heute?"},
		{"id": "l11", "cat": "B", "text": "Kein Stress! Wenn du Zeit hast: {tag} ist bereit."},
		{"id": "l12", "cat": "C", "text": "Ich denk an dich! Deine Welt ist noch da – genau wie ich."},
		{"id": "l13", "cat": "C", "text": "Wir können jederzeit neu anfangen. Ich warte gern auf dich."},
		{"id": "l14", "cat": "C", "text": "Schau doch mal wieder rein. Ich hab dir viel zu zeigen!"},
	],
	"frech": [
		{"id": "f01", "cat": "A", "text": "Psst! {tag} ist da. Ich hab nicht reingeschaut. Fast nicht."},
		{"id": "f02", "cat": "A", "text": "Deine Welt dreht sich nicht von allein. Hilfst du mir?"},
		{"id": "f03", "cat": "A", "text": "Mir ist langweilig. Rettest du mich mit ein paar Drehungen?"},
		{"id": "f04", "cat": "A", "text": "Die Wiesen wollen Wald werden. Ich kann das nicht – du schon."},
		{"id": "f05", "cat": "A", "s": true, "text": "{streak} Tage am Stück! Machen wir heute einen mehr draus?"},
		{"id": "f06", "cat": "A", "text": "Achtung, Durchsage: {name} sucht Gesellschaft. Belohnung: Spaß!"},
		{"id": "f07", "cat": "A", "text": "Ich hab ganz zufällig Regen übrig. Willst du?"},
		{"id": "f08", "cat": "A", "text": "Kurze Frage: Wer hat hier die Welt erschaffen? Genau, du. Weiter geht's!"},
		{"id": "f09", "cat": "B", "text": "Gestern keine Drehung? Ich hab's gesehen. Ich sag's aber keinem."},
		{"id": "f10", "cat": "B", "text": "Huhu! Deine Welt hat ein kleines bisschen Staub angesetzt. Kommst du?"},
		{"id": "f11", "cat": "B", "text": "Ich hab Kekse. Okay, hab ich nicht. Aber {tag} hab ich!"},
		{"id": "f12", "cat": "C", "text": "Ich hab angefangen, mit den Wolken zu reden. Komm bitte zurück!"},
		{"id": "f13", "cat": "C", "text": "Lange nicht gesehen! Ich hab neue Witze. Und deine Welt."},
		{"id": "f14", "cat": "C", "text": "Hallooo? Ist da wer? Deine Welt würde gern weiterwachsen."},
	],
	"streng": [
		{"id": "s01", "cat": "A", "text": "Die Welt wartet. Heute ist {tag} bereit."},
		{"id": "s02", "cat": "A", "text": "Zeit für deine tägliche Schöpfung. Ein paar Minuten genügen."},
		{"id": "s03", "cat": "A", "text": "Ordnung muss sein: heute eine Runde. Ich zähle auf dich."},
		{"id": "s04", "cat": "A", "text": "Eine Welt baut sich nicht von selbst. Fangen wir an."},
		{"id": "s05", "cat": "A", "s": true, "text": "{streak} Tage in Folge. So eine Serie pflegt man."},
		{"id": "s06", "cat": "A", "text": "Heute steht {tag} an. Pünktlich, bitte."},
		{"id": "s07", "cat": "A", "text": "Die Wiesen stehen bereit. Es fehlt nur noch jemand, der dreht."},
		{"id": "s08", "cat": "A", "text": "Eine Runde am Tag. Das ist der Plan. Bleib dabei."},
		{"id": "s09", "cat": "B", "text": "Gestern war Pause. Heute geht es weiter."},
		{"id": "s10", "cat": "B", "text": "Deine Welt hat heute noch nichts von dir gehört. Eine Runde?"},
		{"id": "s11", "cat": "B", "text": "Kurze Erinnerung: {tag} ist bereit. Mehr verlange ich nicht."},
		{"id": "s12", "cat": "C", "text": "Es ist ruhig geworden. Wenn du bereit bist, machen wir weiter."},
		{"id": "s13", "cat": "C", "text": "Deine Welt ist in Ordnung. Ich habe aufgepasst. Kommst du zurück?"},
		{"id": "s14", "cat": "C", "text": "Jede Welt verdient eine zweite Chance. Deine auch."},
	],
}

## Die letzte Nachricht je Ton (Kategorie F, immer dieselbe, zählt nicht für die Wiederholungs-Sperre).
const FINALS = {
	"lieb": {"id": "lF", "text": "Ich erinnere dich jetzt nicht mehr. Deine Welt und ich sind da, wenn du wiederkommst. Alles Liebe!"},
	"frech": {"id": "fF", "text": "Okay, ich hab's kapiert: Pause! Ich bin jetzt still. Aber wenn du wiederkommst, freu ich mich riesig."},
	"streng": {"id": "sF", "text": "Ich erinnere dich nicht mehr. Deine Welt bleibt, wie sie ist. Wenn du wiederkommst: Ich bin bereit."},
}


static func _tone(t: String) -> String:
	return t if TONES.has(t) else "lieb"


## Uhrzeit (Minute des Tages) der Erinnerungen: „Feste Uhrzeit“ oder etwa 23,5 h nach dem Start der Sitzung, die den
## letzten Serientag geschafft hat (unbekannt: 18:00) – immer zwischen 8:00 und 21:30.
static func minute_for(mode: String, anchor_min: int, fixed_min: int) -> int:
	var m := fixed_min if mode == "fest" else (Balance.REMIND_DEFAULT_MIN if anchor_min < 0 else anchor_min - Balance.REMIND_LEAD)
	return clampi(m, Balance.REMIND_EARLIEST, Balance.REMIND_LATEST)


## Der ganze Plan ab jetzt (siehe oben). Leer bei „Aus“ oder ohne Erlaubnis.
static func plan(state: Dictionary, now: int) -> Array:
	var mode := str(state.get("mode", "auto"))
	if mode == "aus" or not MODES.has(mode) or not bool(state.get("allowed", true)):
		return []
	var today := int(state.get("today", Daily.day_key(now)))
	var done := bool(state.get("done_today", false))
	var base := maxi(int(state.get("last_win_key", -1)), int(state.get("last_open_key", today)))
	if base < 0:
		base = today
	var minute := minute_for(mode, int(state.get("anchor_min", -1)), int(state.get("fixed_min", Balance.REMIND_DEFAULT_MIN)))
	var tone := _tone(str(state.get("tone", "lieb")))
	var who := str(state.get("name", DEFAULT_NAME))
	if who.strip_edges() == "":
		who = DEFAULT_NAME
	var tag := str(state.get("tag", "Tag 1"))
	var streak := int(state.get("streak", 0))
	var hist: Array = (state.get("history", []) as Array).duplicate()
	var out: Array = []
	for i in Balance.REMIND_LADDER.size():
		var step := int(Balance.REMIND_LADDER[i])
		var cat := str(LADDER_CATS[mini(i, LADDER_CATS.size() - 1)])
		var key := base + step
		if key < today or (key == today and done):
			continue
		var at := key * Daily.DAY + minute * 60
		if at < now + Balance.REMIND_MIN_GAP:
			continue
		var tpl := pick(tone, cat, streak, hist, key)
		var e := entry(100 + step, at, key, cat, tpl, who, tag, streak)
		out.append(e)
		if cat != "F":
			hist.push_front(tpl)      # im selben Plan nie zweimal derselbe Text
	return out


## Ein Eintrag des Plans (auch für den Test „Erinnerung in 10 s“).
static func entry(id: int, at: int, key: int, cat: String, tpl: String, who: String, tag: String, streak: int) -> Dictionary:
	var f := Daily.fields_of(at)
	return {"id": id, "at": at, "key": key, "cat": cat, "tpl": tpl, "title": who,
		"body": render(text_of(tpl), who, tag, streak), "year": int(f["year"]), "month": int(f["month"]),
		"day": int(f["day"]), "hour": int(f["hour"]), "minute": int(f["minute"])}


## Alle Texte eines Tons (ohne die letzte Nachricht).
static func templates(tone: String) -> Array:
	return TEMPLATES.get(_tone(tone), [])


static func final_id(tone: String) -> String:
	return str((FINALS[_tone(tone)] as Dictionary)["id"])


## Text zu einer ID ("" = unbekannt).
static func text_of(id: String) -> String:
	for t in TONES:
		if str((FINALS[t] as Dictionary)["id"]) == id:
			return str((FINALS[t] as Dictionary)["text"])
		for e in (TEMPLATES[t] as Array):
			if str((e as Dictionary)["id"]) == id:
				return str((e as Dictionary)["text"])
	return ""


static func is_final(id: String) -> bool:
	return id.ends_with("F")


static func render(text: String, who: String, tag: String, streak: int) -> String:
	return text.replace("{name}", who).replace("{tag}", tag).replace("{streak}", str(streak))


## Kandidaten einer Kategorie: S-Texte nur in A und nur ab einer Serie von 2.
static func _pool(tone: String, cat: String, streak: int) -> Array:
	var out: Array = []
	for e in templates(tone):
		var d: Dictionary = e
		if str(d["cat"]) != cat:
			continue
		if bool(d.get("s", false)) and (cat != "A" or streak < 2):
			continue
		out.append(str(d["id"]))
	return out


static func _without(pool: Array, ids: Array) -> Array:
	var out: Array = []
	for p in pool:
		if not ids.has(p):
			out.append(p)
	return out


## Einen Text wählen (5.4): Kategorie cat, ohne die letzten 4 benutzten (history, neueste zuerst; wird der Pool leer,
## nur ohne den allerletzten), die 4 davor seltener. C nimmt A dazu, wenn C nichts Unbenutztes mehr hat. frech/streng:
## manchmal (15 %) ein lieber Text. F: immer die letzte Nachricht des Tons. Gleiche Eingaben → gleicher Text.
static func pick(tone: String, cat: String, streak: int, history: Array, key: int) -> String:
	tone = _tone(tone)
	if cat == "F":
		return final_id(tone)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([key, tone, history.size(), cat])
	var src := tone
	if tone != "lieb" and rng.randf() < Balance.REMIND_LIEB_SHARE:
		src = "lieb"
	var block: Array = history.slice(0, RECENT_BLOCK)
	var soft: Array = history.slice(RECENT_BLOCK, RECENT_SOFT)
	var full := _pool(src, cat, streak)
	var pool := _without(full, block)
	if pool.is_empty() and cat == "C":
		pool = _without(full + _pool(src, "A", 0), block)
	if pool.is_empty() and not history.is_empty():
		pool = _without(full, [history[0]])
	if pool.is_empty():
		pool = full
	if pool.is_empty():
		return final_id(tone)
	var total := 0.0
	var weights: Array = []
	for id in pool:
		var w := SOFT_WEIGHT if soft.has(id) else 1.0
		weights.append(w)
		total += w
	var r := rng.randf() * total
	for i in pool.size():
		r -= float(weights[i])
		if r <= 0.0:
			return str(pool[i])
	return str(pool[pool.size() - 1])


## Beim Neuplanen: Was vom alten Plan schon gezeigt wurde (at ≤ now), kommt vorne in die Geschichte (höchstens 8,
## neueste zuerst; die letzte Nachricht nicht). Gibt die neue Geschichte zurück.
static func absorb_shown(history: Array, planned: Array, now: int) -> Array:
	var shown: Array = []
	for e in planned:
		var d: Dictionary = e
		if int(d.get("at", 0)) <= now and not is_final(str(d.get("tpl", ""))) and str(d.get("tpl", "")) != "":
			shown.append(d)
	shown.sort_custom(func(a, b): return int(a["at"]) > int(b["at"]))
	var out: Array = []
	for d in shown:
		out.append(str((d as Dictionary)["tpl"]))
	for h in history:
		out.append(str(h))
	while out.size() > HISTORY_MAX:
		out.pop_back()
	return out


## Eine Zeile fürs Protokoll (PC/CI ohne Plugin, Tour): „REMINDER plan id=101 at=2026-11-07 17:30 cat=A tpl=l03 …“
static func log_line(e: Dictionary) -> String:
	return "REMINDER plan id=%d at=%04d-%02d-%02d %02d:%02d cat=%s tpl=%s title=%s text=%s" % [int(e["id"]),
		int(e["year"]), int(e["month"]), int(e["day"]), int(e["hour"]), int(e["minute"]), str(e["cat"]),
		str(e["tpl"]), str(e["title"]), str(e["body"])]
