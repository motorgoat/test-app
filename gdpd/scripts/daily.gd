class_name Daily
extends RefCounted
## Täglich spielen (docs/GDPD_TAEGLICH_CHARAKTER.md 1, 2, 7): Spieltag, Freischalten nach Datum, Serie, Serienschutz,
## Wochenkalender, Welt des Tages, Uhr-Regeln, Speichern [taeglich]. Nur reine statische Funktionen, keine Nodes.
##
## Zeit: „lokale Unix-Sekunden“ = die Ortszeit (Datum + Uhrzeit) so gelesen, als wäre sie UTC (Game.now_local()).
## Spieltag (key) = Tage seit 1970-01-01 von (Ortszeit − 3 h): Der Tag wechselt um 3 Uhr, nie um Mitternacht.
##
## Der Tageszustand ist ein Dictionary (fresh()); Game hält ihn in Game.daily und speichert ihn in [taeglich]:
##   won_key (Array, 7): Spieltag des ersten Siegs je Tag (−1 = keiner/unbekannt, z. B. alter Spielstand)
##   last_new_key: Spieltag des letzten ERSTEN Siegs eines Tages (−1 = keiner)
##   streak, streak_best, streak_last (Spieltag des letzten Serientags, −1), shields (0 … SHIELD_MAX),
##   shields_ever (je einen Schutz gehabt: Chip sichtbar), streak_days / shield_days (letzte 21 Spieltage)
##   last_seen (größte je gesehene Ortszeit), last_key (ihr Spieltag), first_key (erster Spieltag des Profils),
##   open_key (Spieltag des letzten Sitzungs-Starts), anchor (Minute des Tages, zu der die Sitzung begann, die den
##   letzten Serientag geschafft hat; −1 = unbekannt), wdt_stars ({"key": Sterne}, letzte 14), wdt_fails ([key, n]),
##   wdt_total (geschaffte Welten des Tages), build_coins ([key, Münzen] aus dem Weiterbauen), test_days (Test-Knopf),
##   comeback ("" | "saved" | "lost": einmal zeigen, dann take_comeback()),
##   clock_off (ganze Tage, die die Spielzeit vor der Systemuhr liegt, nach großem Zurückstellen; sonst 0),
##   sys_seen (zuletzt gesehene Systemzeit: erkennt das Wieder-Richtigstellen)

const DAY := 86400
const KEEP_DAYS := 21
const KEEP_WDT := 14
const BIG_BACK := 36 * 3600          # Uhr so weit zurück: neu aufsetzen (sonst bleibt der Spieltag stehen)
const SECTION := "taeglich"
const VERSION := 1
const WEEKDAYS = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]
const WEEKDAYS_SHORT = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]


# --- Zeit ------------------------------------------------------------------------------------

## Ortszeit des Systems als „lokale Unix-Sekunden“ (ohne Test-Verschiebung; die macht Game.now_local()).
static func system_local() -> int:
	return int(Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system(false)))


## Lokale Unix-Sekunden aus Datum und Uhrzeit (Tests, Plugin).
static func local_unix(year: int, month: int, day: int, hour: int = 0, minute: int = 0, second: int = 0) -> int:
	return int(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day,
		"hour": hour, "minute": minute, "second": second}))


## Spieltag einer Ortszeit (Tag wechselt um DAY_START_HOUR Uhr).
static func day_key(t: int) -> int:
	var s := t - Balance.DAY_START_HOUR * 3600
	return (s - posmod(s, DAY)) / DAY


## Ortszeit des nächsten Tageswechsels (das nächste 3 Uhr).
static func next_boundary(t: int) -> int:
	return (day_key(t) + 1) * DAY + Balance.DAY_START_HOUR * 3600


## Wochentag eines Spieltags: 0 = Montag … 6 = Sonntag.
static func weekday(key: int) -> int:
	return (int(Time.get_datetime_dict_from_unix_time(key * DAY + 43200)["weekday"]) + 6) % 7


static func weekday_name(key: int) -> String:
	return str(WEEKDAYS[weekday(key)])


## Minute des Tages (0 … 1439) einer Ortszeit.
static func minute_of_day(t: int) -> int:
	return posmod(t, DAY) / 60


## Datum und Uhrzeit (Kalender) einer Ortszeit: {"year", "month", "day", "hour", "minute", "weekday"}.
static func fields_of(t: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(t)


## Zeile unter der Heute-Karte: „Neuer Tag in 14 Std. 20 Min.“ – bei 8 Stunden oder weniger nur „Morgen früh“
## (niemand soll abends auf 3 Uhr warten).
static func countdown_text(now: int) -> String:
	var left := maxi(0, next_boundary(now) - now)
	if left <= Balance.COUNTDOWN_EXACT_HOURS * 3600:
		return str(Days.TEXT["countdown_late"])
	var mins := left / 60
	return str(Days.TEXT["countdown"]) % [mins / 60, mins % 60]


# --- Zustand -------------------------------------------------------------------------------

static func fresh(now: int, days: int = 7) -> Dictionary:
	var k := day_key(now)
	var won: Array = []
	for i in days:
		won.append(-1)
	return {"won_key": won, "last_new_key": -1, "streak": 0, "streak_best": 0, "streak_last": -1, "shields": 0,
		"shields_ever": false, "streak_days": [], "shield_days": [], "last_seen": now, "last_key": k, "first_key": k,
		"open_key": k, "anchor": -1, "wdt_stars": {}, "wdt_fails": [-1, 0], "wdt_total": 0, "build_coins": [-1, 0],
		"test_days": 0, "comeback": "", "clock_off": 0, "sys_seen": now}


## Fehlende Einträge ergänzen und Typen richten (alte/kaputte Spielstände). days: Anzahl der Tage.
static func sanitize(d: Dictionary, now: int, days: int = 7) -> Dictionary:
	var f := fresh(now, days)
	for k in f:
		if not d.has(k):
			d[k] = f[k]
	var won: Array = []
	for v in (d["won_key"] as Array):
		won.append(int(v))
	while won.size() < days:
		won.append(-1)
	while won.size() > days:
		won.pop_back()
	d["won_key"] = won
	for k in ["last_new_key", "streak", "streak_best", "streak_last", "shields", "last_seen", "last_key", "first_key",
			"open_key", "anchor", "wdt_total", "test_days", "clock_off", "sys_seen"]:
		d[k] = int(d[k])
	d["shields"] = clampi(int(d["shields"]), 0, Balance.SHIELD_MAX)
	d["shields_ever"] = bool(d["shields_ever"])
	d["comeback"] = str(d["comeback"])
	for k in ["streak_days", "shield_days"]:
		var a: Array = []
		for v in (d[k] as Array):
			a.append(int(v))
		d[k] = a
	for k in ["wdt_fails", "build_coins"]:
		var p: Array = d[k] if d[k] is Array else []
		d[k] = [int(p[0]), int(p[1])] if p.size() >= 2 else [-1, 0]
	var ws := {}
	var src: Dictionary = d["wdt_stars"] if d["wdt_stars"] is Dictionary else {}
	for k in src:
		ws[str(k)] = int(src[k])
	d["wdt_stars"] = ws
	return d


static func _push_key(arr: Array, key: int, keep: int = KEEP_DAYS) -> void:
	if not arr.has(key):
		arr.append(key)
	arr.sort()
	while arr.size() > keep:
		arr.pop_front()


# --- Uhr-Regeln (1.7) -------------------------------------------------------------------------

## Die Uhr ansehen: gibt den heutigen Spieltag zurück und merkt sich die Zeit. Die Spielzeit läuft nie rückwärts:
## Spielzeit = Systemzeit + clock_off ganze Tage (game_time). Gemerkte Spieltage werden nie umgeschrieben.
## - normal (Spielzeit ≥ last_seen): Spieltag der Spielzeit.
## - Uhr etwas zurück (< 36 h, Sommerzeit-Ende, Reise nach Westen): der Spieltag bleibt stehen (nie rückwärts).
## - Uhr weit zurück (≥ 36 h, falsches Datum): clock_off = so viele Tage, dass der Spieltag bleibt. Die Spielzeit
##   läuft von dort in Echtzeit weiter (am nächsten Morgen kommt der nächste Tag).
## - Uhr wieder richtig (Systemtag erreicht den Spieltag, oder ein Sprung ≥ 36 h vor, während clock_off > 0): erst
##   clock_off abbauen. Diese Tage zählen nicht als verpasst, nichts wird entsperrt, kein Schutz wird verbraucht.
## - Uhr vor (ohne clock_off): wird angenommen (öffnet höchstens einen neuen Tag je Spieltag; Serienschutz gilt).
static func observe(d: Dictionary, now: int) -> int:
	var seen := int(d.get("last_seen", now))
	var last := int(d.get("last_key", day_key(seen)))
	var off := maxi(0, int(d.get("clock_off", 0)))
	var sys_seen := int(d.get("sys_seen", seen - off * DAY))
	d["sys_seen"] = now
	if off > 0 and (day_key(now) >= last or now - sys_seen >= BIG_BACK):
		off = maxi(0, last - day_key(now))      # zurückgestellt: Uhr wieder richtig – erst den Versatz abbauen
	d["clock_off"] = off
	var g := now + off * DAY
	if g >= seen:
		d["last_seen"] = g
		d["last_key"] = maxi(last, day_key(g))
		return int(d["last_key"])
	if seen - g < BIG_BACK:
		return last
	off = maxi(0, last - day_key(now))           # weit zurück: der Spieltag bleibt, die Spielzeit läuft weiter
	d["clock_off"] = off
	d["last_key"] = last                         # last_seen bleibt: die Spielzeit holt ihn wieder ein
	return last


## Spielzeit (lokale Unix-Sekunden) zu einer Systemzeit: now + clock_off Tage (nach observe aufrufen).
static func game_time(d: Dictionary, now: int) -> int:
	return now + maxi(0, int(d.get("clock_off", 0))) * DAY


# --- Serie und Serienschutz (1.4, 1.5) ----------------------------------------------------------

## Tagesprüfung (Start, Fortsetzen, neuer Spieltag): verpasste Tage mit Serienschutz überbrücken – aber nur, wenn
## der Schutz die ganze Lücke schließt (sonst bleibt er, und die Serie ist vorbei). Gibt "" | "saved" | "lost" zurück.
## Mehrmals aufrufen schadet nicht.
static func day_check(d: Dictionary, today: int) -> String:
	var st := int(d["streak"])
	var last := int(d["streak_last"])
	if st <= 0 or last < 0:
		return ""
	var missed := today - last - 1
	if missed <= 0:
		return ""
	var sh := int(d["shields"])
	if missed <= sh:
		d["shields"] = sh - missed
		for k in range(last + 1, today):
			_push_key(d["shield_days"], k)
		d["streak_last"] = today - 1
		d["comeback"] = "saved"
		return "saved"
	d["streak"] = 0
	d["comeback"] = "lost"
	return "lost"


## Ist der Serientag heute schon geschafft?
static func done_today(d: Dictionary, today: int) -> bool:
	return int(d["streak_last"]) == today


## Ein Sieg (neuer Tag, Wiederholung oder Welt des Tages) am Spieltag today. anchor_min: Minute des Tages, zu der die
## Sitzung begann (−1 = unbekannt, bleibt wie es war). Nur der erste Sieg eines Spieltags zählt.
## {"counted", "before", "streak", "best", "milestone" (Vielfaches von 7), "big" (große Feier), "shield" (+1 Schutz),
##  "coins" (Münzen statt Schutz), "shields", "key" (der Spieltag, dem der Sieg zählt)}
static func win(d: Dictionary, today: int, anchor_min: int = -1) -> Dictionary:
	day_check(d, today)
	var before := int(d["streak"])
	var out := {"counted": false, "before": before, "streak": before, "best": int(d["streak_best"]), "milestone": false,
		"big": false, "shield": 0, "coins": 0, "shields": int(d["shields"]), "key": today}
	if int(d["streak_last"]) == today:
		return out
	var st := before + 1
	d["streak"] = st
	d["streak_last"] = today
	_push_key(d["streak_days"], today)
	d["streak_best"] = maxi(int(d["streak_best"]), st)
	if anchor_min >= 0:
		d["anchor"] = anchor_min
	out["counted"] = true
	out["streak"] = st
	out["best"] = int(d["streak_best"])
	if st % Balance.STREAK_MILESTONE == 0:
		out["milestone"] = true
		if int(d["shields"]) < Balance.SHIELD_MAX:
			d["shields"] = int(d["shields"]) + 1
			d["shields_ever"] = true
			out["shield"] = 1
		else:
			out["coins"] = Balance.SHIELD_FULL_COINS
	out["big"] = Balance.STREAK_BIG.has(st)
	out["shields"] = int(d["shields"])
	return out


## Warum man gerade keinen Serienschutz kaufen kann ("" = man kann). credits: Münzen des Spielers.
static func shield_buy_error(d: Dictionary, credits: int) -> String:
	if int(d["shields"]) >= Balance.SHIELD_MAX:
		return str(Days.TEXT["shield_full"])
	if credits < Balance.SHIELD_PRICE:
		return str(Days.TEXT["shield_missing"]) % (Balance.SHIELD_PRICE - credits)
	return ""


## Einen Serienschutz dazu (nach dem Bezahlen). false, wenn schon voll.
static func add_shield(d: Dictionary) -> bool:
	if int(d["shields"]) >= Balance.SHIELD_MAX:
		return false
	d["shields"] = int(d["shields"]) + 1
	d["shields_ever"] = true
	return true


## Comeback-Zeile („saved“/„lost“) einmal abholen.
static func take_comeback(d: Dictionary) -> String:
	var c := str(d.get("comeback", ""))
	d["comeback"] = ""
	return c


## Wochenreihe (Montag zuerst) der Woche von today: 7 × {"key", "weekday" (0 … 6), "short" („Mo“), "state"}.
## state: "streak" (Flamme), "shield" (überbrückt), "missed" (leerer Ring), "today" (heute, noch offen),
## "future" (kommt noch), "none" (vor dem ersten Spieltag des Profils).
static func week(d: Dictionary, today: int) -> Array:
	var mon := today - weekday(today)
	var out: Array = []
	var sd: Array = d["streak_days"]
	var hd: Array = d["shield_days"]
	for i in 7:
		var k := mon + i
		var st := "missed"
		if sd.has(k):
			st = "streak"
		elif hd.has(k):
			st = "shield"
		elif k == today:
			st = "today"
		elif k > today:
			st = "future"
		elif k < int(d["first_key"]):
			st = "none"
		out.append({"key": k, "weekday": i, "short": str(WEEKDAYS_SHORT[i]), "state": st})
	return out


# --- Freischalten nach Datum (1.2) -----------------------------------------------------------------
# stars: beste Sterne je Tag (Game.day_stars; > 0 = geschafft).

## Der nächste neue Tag (der erste noch nicht geschaffte; stars.size() + 1 = keiner mehr).
static func next_new_day(stars: Array) -> int:
	for i in stars.size():
		if int(stars[i]) <= 0:
			return i + 1
	return stars.size() + 1


## Ist heute ein neuer Tag offen? (Ein neuer Tag je Spieltag: erst an einem späteren Spieltag als der letzte erste Sieg.)
static func new_day_open(d: Dictionary, stars: Array, today: int) -> bool:
	return next_new_day(stars) <= stars.size() and today > int(d["last_new_key"])


## Ist der nächste neue Tag erst morgen dran (heute schon ein erster Sieg)?
static func new_day_tomorrow(d: Dictionary, stars: Array, today: int) -> bool:
	return next_new_day(stars) <= stars.size() and today <= int(d["last_new_key"])


## Ist Tag n spielbar? Tag 1 immer; sonst muss der Tag davor geschafft sein und n schon geschafft (Wiederholung)
## oder der heute offene neue Tag sein.
static func day_unlocked(d: Dictionary, stars: Array, n: int, today: int) -> bool:
	if n < 1 or n > stars.size():
		return false
	if n == 1:
		return true
	if int(stars[n - 2]) <= 0:
		return false
	if int(stars[n - 1]) > 0:
		return true
	return n == next_new_day(stars) and new_day_open(d, stars, today)


## Alter Wert „frei“ (höchster spielbarer Tag) für ältere Oberflächen-Teile und den Spielstand.
static func day_free(d: Dictionary, stars: Array, today: int) -> int:
	var nn := next_new_day(stars)
	if nn > stars.size():
		return stars.size() + 1
	return nn if new_day_open(d, stars, today) else maxi(1, nn - 1)


## Der erste Sieg von Tag n am Spieltag today.
static func register_first_win(d: Dictionary, n: int, today: int) -> void:
	var won: Array = d["won_key"]
	if n >= 1 and n <= won.size():
		won[n - 1] = today
	d["last_new_key"] = maxi(int(d["last_new_key"]), today)


# --- Die Schöpfung: ein neues Level je Spieltag (GDPD_SCHOEPFUNG.md 4, 13) -----------------------------
# c: Kampagnen-Zustand (Game.camp, gespeichert in [kampagne]): "stars" (Array 30, beste Sterne je Level),
# "won_key" (Array 30, Spieltag des ersten Siegs, −1), "last_new_key" (Spieltag des letzten ersten Siegs),
# "fast_to" (Schnellstart bis zu diesem Level, 0 = keiner), "fast_day" ([Spieltag, erste Siege an ihm]),
# "veteran" (die alten 7 Tage geschafft: Welt des Tages auch während der Kampagne).

## Das nächste neue Level (das erste noch nicht geschaffte; 31 = keins mehr).
static func next_new_level(c: Dictionary) -> int:
	return next_new_day(c["stars"])


## Erste Siege am Spieltag today (für den Schnellstart).
static func firsts_on(c: Dictionary, today: int) -> int:
	var fd: Array = c.get("fast_day", [-1, 0])
	return int(fd[1]) if fd.size() >= 2 and int(fd[0]) == today else 0


## Schnellstart (13.1): solange das nächste neue Level ≤ fast_to ist, öffnen bis zu 3 neue Level je Spieltag.
static func fast_track_on(c: Dictionary) -> bool:
	return next_new_level(c) <= int(c.get("fast_to", 0))


## Ist heute ein neues Level offen? (Eins je Spieltag; im Schnellstart bis zu 3.)
static func new_level_open(c: Dictionary, today: int) -> bool:
	var nn := next_new_level(c)
	if nn > (c["stars"] as Array).size():
		return false
	if today > int(c.get("last_new_key", -1)):
		return true
	return nn <= int(c.get("fast_to", 0)) and firsts_on(c, today) < Balance.FAST_TRACK_PER_DAY


## So viele neue Level gehen heute noch (für „Schnellstart: 3 heute“).
static func new_levels_left(c: Dictionary, today: int) -> int:
	if not new_level_open(c, today):
		return 0
	if not fast_track_on(c):
		return 1
	return maxi(1, Balance.FAST_TRACK_PER_DAY - firsts_on(c, today))


static func new_level_tomorrow(c: Dictionary, today: int) -> bool:
	return next_new_level(c) <= (c["stars"] as Array).size() and not new_level_open(c, today)


## Ist Level n spielbar? Level 1 immer; sonst muss das Level davor geschafft sein und n schon geschafft
## (Wiederholung) oder das heute offene neue Level sein.
static func level_unlocked(c: Dictionary, n: int, today: int) -> bool:
	var st: Array = c["stars"]
	if n < 1 or n > st.size():
		return false
	if n == 1:
		return true
	if int(st[n - 2]) <= 0:
		return false
	if int(st[n - 1]) > 0:
		return true
	return n == next_new_level(c) and new_level_open(c, today)


## Höchstes freies Level (Spielstand [kampagne] level).
static func level_free(c: Dictionary, today: int) -> int:
	var nn := next_new_level(c)
	var cnt := (c["stars"] as Array).size()
	if nn > cnt:
		return cnt
	return nn if level_unlocked(c, nn, today) else maxi(1, nn - 1)


## Der erste Sieg von Level n am Spieltag today.
static func register_level_win(c: Dictionary, n: int, today: int) -> void:
	var won: Array = c["won_key"]
	if n >= 1 and n <= won.size():
		won[n - 1] = today
	c["last_new_key"] = maxi(int(c.get("last_new_key", -1)), today)
	c["fast_day"] = [today, firsts_on(c, today) + 1]


## Welt des Tages in der Schöpfung: ab dem Spieltag nach dem ersten Sieg von Level 30; Veteranen (alte 7 Tage
## geschafft) jeden Tag.
static func wdt_available_camp(c: Dictionary, today: int) -> bool:
	if bool(c.get("veteran", false)):
		return true
	if next_new_level(c) <= (c["stars"] as Array).size():
		return false
	var won: Array = c["won_key"]
	return won.is_empty() or today > int(won[won.size() - 1])


# --- Welt des Tages (1.3) -------------------------------------------------------------------------

## Gibt es heute eine Welt des Tages? Ab dem Spieltag nach dem ersten Sieg von Tag 7.
static func wdt_available(d: Dictionary, stars: Array, today: int) -> bool:
	if next_new_day(stars) <= stars.size():
		return false
	var won: Array = d["won_key"]
	return won.is_empty() or today > int(won[won.size() - 1])


## Vorlage (Tag 2 … 7) der Welt des Tages: jede Art einmal in 6 Tagen, nie zweimal hintereinander.
static func wdt_template(key: int) -> int:
	return 2 + posmod(key, 6)


## Brett der Vorlage: nie Brett 0 (das Tutorial-/Startbrett); 6 × 19 = 114 Welten, bevor sich eine wiederholt.
static func wdt_board_index(key: int, pool: int = 20) -> int:
	if pool <= 1:
		return 0
	var block := (key - posmod(key, 6)) / 6
	return 1 + posmod(block, pool - 1)


## Regeln der Welt des Tages: die geprüfte Vorlage (Ziel, Grenze, Sterne, Systeme, Wahl) mit eigenem Titel, ohne
## „Neu:“-Aufdecken und ohne die Einführungs-Sätze des Tages. "wdt": true, "wdt_key", "caps" („Welt des Tages · Freitag“).
static func wdt_config(key: int) -> Dictionary:
	var t := wdt_template(key)
	var c := Days.config(t)
	if c.is_empty():
		return c
	c["template_title"] = str(c.get("title", ""))
	c["title"] = str(Days.TEXT["wdt"])
	c["caps"] = str(Days.TEXT["wdt_caps"]) % weekday_name(key)
	c["intro"] = str(Days.TEXT["wdt_intro"])
	c["new"] = {}
	c["coach"] = []
	c["coach_demo"] = ""
	c["onboard_hint"] = false
	c.erase("tutorial")
	c["wdt"] = true
	c["wdt_key"] = key
	return c


## Das Brett der Welt des Tages (Days.board der Vorlage).
static func wdt_board(key: int) -> Dictionary:
	var t := wdt_template(key)
	return Days.board(t, wdt_board_index(key, Days.pool_size(t)))


static func wdt_stars(d: Dictionary, key: int) -> int:
	return int((d["wdt_stars"] as Dictionary).get(str(key), 0))


static func wdt_done(d: Dictionary, key: int) -> bool:
	return wdt_stars(d, key) > 0


## Gnade der Welt des Tages (gilt nur für ihren Spieltag).
static func wdt_mercy(d: Dictionary, key: int) -> int:
	var p: Array = d["wdt_fails"]
	if int(p[0]) != key:
		return 0
	return mini(Balance.MERCY_MAX, int(p[1]) * Balance.MERCY_TWISTS)


static func wdt_fail(d: Dictionary, key: int) -> void:
	var p: Array = d["wdt_fails"]
	if int(p[0]) != key:
		d["wdt_fails"] = [key, 1]
	else:
		d["wdt_fails"] = [key, int(p[1]) + 1]


## Welt des Tages geschafft: Sterne merken (die besten, letzte 14 Spieltage). Gibt true beim ersten Sieg dieser Welt.
static func wdt_win(d: Dictionary, key: int, stars: int) -> bool:
	var ws: Dictionary = d["wdt_stars"]
	var first := int(ws.get(str(key), 0)) <= 0
	ws[str(key)] = maxi(int(ws.get(str(key), 0)), stars)
	if first:
		d["wdt_total"] = int(d["wdt_total"]) + 1
	var keys: Array = []
	for k in ws:
		keys.append(int(str(k)))
	keys.sort()
	while keys.size() > KEEP_WDT:
		ws.erase(str(keys.pop_front()))
	if int((d["wdt_fails"] as Array)[0]) == key:
		d["wdt_fails"] = [key, 0]
	return first


# --- Weiterbauen: Münzen (2.2) -----------------------------------------------------------------

## Münzen fürs Weiterbauen: 1 je BUILD_COIN_EVERY gewachsene Felder, höchstens BUILD_COIN_MAX je Spieltag.
## growth: seit dem Sieg in dieser Welt gewachsen; given: in dieser Welt schon bezahlt. Gibt die neuen Münzen zurück
## (und merkt sie für heute).
static func build_coins(d: Dictionary, today: int, growth: int, given: int) -> int:
	var p: Array = d["build_coins"]
	var today_n := int(p[1]) if int(p[0]) == today else 0
	var due := growth / maxi(1, Balance.BUILD_COIN_EVERY) - given
	var n := clampi(due, 0, maxi(0, Balance.BUILD_COIN_MAX - today_n))
	if n > 0:
		d["build_coins"] = [today, today_n + n]
	return n


# --- Speichern [taeglich] (1.8) ----------------------------------------------------------------------

static func save(d: Dictionary, cfg: ConfigFile) -> void:
	var s := SECTION
	cfg.set_value(s, "version", VERSION)
	cfg.set_value(s, "gewonnen_am", d["won_key"])
	cfg.set_value(s, "letzter_neuer", int(d["last_new_key"]))
	cfg.set_value(s, "serie", int(d["streak"]))
	cfg.set_value(s, "serie_best", int(d["streak_best"]))
	cfg.set_value(s, "serie_letzter", int(d["streak_last"]))
	cfg.set_value(s, "serie_tage", d["streak_days"])
	cfg.set_value(s, "schutz_tage", d["shield_days"])
	cfg.set_value(s, "schutz", int(d["shields"]))
	cfg.set_value(s, "schutz_je", bool(d["shields_ever"]))
	cfg.set_value(s, "zuletzt", int(d["last_seen"]))
	cfg.set_value(s, "zuletzt_tag", int(d["last_key"]))
	cfg.set_value(s, "erster_tag", int(d["first_key"]))
	cfg.set_value(s, "geoeffnet", int(d["open_key"]))
	cfg.set_value(s, "anker", int(d["anchor"]))
	cfg.set_value(s, "wdt_sterne", d["wdt_stars"])
	cfg.set_value(s, "wdt_fehlversuche", d["wdt_fails"])
	cfg.set_value(s, "wdt_gesamt", int(d["wdt_total"]))
	cfg.set_value(s, "bau_muenzen", d["build_coins"])
	cfg.set_value(s, "test_tage", int(d["test_days"]))
	cfg.set_value(s, "comeback", str(d["comeback"]))
	cfg.set_value(s, "uhr_versatz", int(d["clock_off"]))
	cfg.set_value(s, "zuletzt_system", int(d["sys_seen"]))


## Laden. Ohne [taeglich] (Spielstand v1 oder neu): Migration – jeder geschaffte Tag gilt als „früher geschafft“
## (gewonnen_am = −1), letzter_neuer = −1: Der nächste neue Tag ist heute offen. Niemand verliert einen Tag.
## Serie 0, kein Schutz. Ist die Welt schon vollendet, gibt es heute schon die Welt des Tages.
static func load_from(cfg: ConfigFile, now: int, days: int = 7) -> Dictionary:
	if cfg == null or not cfg.has_section(SECTION):
		return fresh(now, days)
	var s := SECTION
	var f := fresh(now, days)
	var d := {"won_key": cfg.get_value(s, "gewonnen_am", f["won_key"]),
		"last_new_key": cfg.get_value(s, "letzter_neuer", -1), "streak": cfg.get_value(s, "serie", 0),
		"streak_best": cfg.get_value(s, "serie_best", 0), "streak_last": cfg.get_value(s, "serie_letzter", -1),
		"streak_days": cfg.get_value(s, "serie_tage", []), "shield_days": cfg.get_value(s, "schutz_tage", []),
		"shields": cfg.get_value(s, "schutz", 0), "shields_ever": cfg.get_value(s, "schutz_je", false),
		"last_seen": cfg.get_value(s, "zuletzt", now), "first_key": cfg.get_value(s, "erster_tag", f["first_key"]),
		"open_key": cfg.get_value(s, "geoeffnet", f["open_key"]), "anchor": cfg.get_value(s, "anker", -1),
		"wdt_stars": cfg.get_value(s, "wdt_sterne", {}), "wdt_fails": cfg.get_value(s, "wdt_fehlversuche", [-1, 0]),
		"wdt_total": cfg.get_value(s, "wdt_gesamt", 0), "build_coins": cfg.get_value(s, "bau_muenzen", [-1, 0]),
		"test_days": cfg.get_value(s, "test_tage", 0), "comeback": cfg.get_value(s, "comeback", ""),
		"clock_off": cfg.get_value(s, "uhr_versatz", 0)}
	d["sys_seen"] = cfg.get_value(s, "zuletzt_system", int(d["last_seen"]) - int(d["clock_off"]) * DAY)
	d["last_key"] = cfg.get_value(s, "zuletzt_tag", day_key(int(d["last_seen"])))
	return sanitize(d, now, days)
