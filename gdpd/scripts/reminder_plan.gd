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

## Die Texte (4.7) stehen in CharacterTexts.NOTIFY (eine Quelle für Spiel und Erinnerung). streak = nur bei einer
## Serie ab 2 Tagen. F = die letzte Nachricht je Ton (immer dieselbe, zählt nicht für die Wiederholungs-Sperre).


static func _tone(t: String) -> String:
	return t if TONES.has(t) else "lieb"


## Uhrzeit (Minute des Tages) der Erinnerungen: „Feste Uhrzeit“ oder etwa 23,5 h nach dem Start der Sitzung, die den
## letzten Serientag geschafft hat (unbekannt: 18:00) – immer zwischen 8:00 und 21:30.
## Nachteule: Begann die Sitzung zwischen 0:00 und 3:00 (sie gehört zum Spieltag davor), kommt die Erinnerung um 21:30 –
## die erlaubte Zeit, die am nächsten an „etwa 24 h später“ liegt (nicht schon um 8:00 am selben Morgen).
static func minute_for(mode: String, anchor_min: int, fixed_min: int) -> int:
	if mode != "fest" and anchor_min >= 0 and anchor_min < Balance.DAY_START_HOUR * 60:
		return Balance.REMIND_LATEST
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
	var out: Array = []
	for e in (CharacterTexts.NOTIFY.get(_tone(tone), []) as Array):
		if str((e as Dictionary)["cat"]) != "F":
			out.append(e)
	return out


static func final_id(tone: String) -> String:
	for e in (CharacterTexts.NOTIFY.get(_tone(tone), []) as Array):
		if str((e as Dictionary)["cat"]) == "F":
			return str((e as Dictionary)["id"])
	return ""


## Text zu einer ID ("" = unbekannt).
static func text_of(id: String) -> String:
	return str(CharacterTexts.notification_by_id(id).get("text", ""))


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
		if bool(d.get("streak", false)) and (cat != "A" or streak < 2):
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
