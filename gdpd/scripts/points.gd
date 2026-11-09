class_name Points
extends RefCounted
## Punkte: die eine Währung (docs/GDPD_PUNKTE_LADEN.md). Nur statische Funktionen, keine Nodes (wie Daily).
## Der Zustand ist ein Dictionary (fresh()); Game hält ihn in Game.pdata und speichert ihn in [punkte]:
##   level_best (Array 30: bestes bezahltes Ergebnis je Level), extras (Array 30: bezahlte Extras je Level),
##   wdt_best ({"Spieltag": bestes Ergebnis}), heute ([Spieltag, Weiterbauen, Videos, freies Spiel]),
##   summe (alles je verdient), verlauf (die letzten 50 Buchungen [Spieltag, Quelle, Punkte]).
## Der Kontostand selbst steht in [konto] punkte (Game.points).

const SECTION := "punkte"
const KEEP_LOG := 50
const KEEP_WDT := 21


static func fresh(levels: int = 30) -> Dictionary:
	var lb: Array = []
	var ex: Array = []
	for i in levels:
		lb.append(0)
		ex.append(0)
	return {"level_best": lb, "extras": ex, "wdt_best": {}, "heute": [-1, 0, 0, 0], "summe": 0, "verlauf": []}


static func sanitize(d: Dictionary, levels: int = 30) -> Dictionary:
	var f := fresh(levels)
	for k in f:
		if not d.has(k):
			d[k] = f[k]
	for k in ["level_best", "extras"]:
		var a: Array = []
		for v in (d[k] as Array):
			a.append(int(v))
		while a.size() < levels:
			a.append(0)
		while a.size() > levels:
			a.pop_back()
		d[k] = a
	var h: Array = d["heute"] if d["heute"] is Array else []
	d["heute"] = [int(h[0]) if h.size() > 0 else -1, int(h[1]) if h.size() > 1 else 0,
		int(h[2]) if h.size() > 2 else 0, int(h[3]) if h.size() > 3 else 0]
	var wb := {}
	var src: Dictionary = d["wdt_best"] if d["wdt_best"] is Dictionary else {}
	for k in src:
		wb[str(k)] = int(src[k])
	d["wdt_best"] = wb
	d["summe"] = int(d["summe"])
	return d


## Punkte eines Levels: 30 + 10 × Sterne + 5 × max(0, Par − Schritte), Par = ★★★-Grenze + 4 (2.1).
static func level_points(stars: int, steps: int, s3: int) -> int:
	return GameState.points_for9(stars, steps, s3 + Balance.PAR_PLUS)


## Ein Sieg in Level n (1 … 30) mit pts Punkten: bezahlt wird nur die Verbesserung gegenüber dem besten (2.3).
static func pay_level(d: Dictionary, n: int, pts: int, today: int = -1) -> int:
	var lb: Array = d["level_best"]
	if n < 1 or n > lb.size():
		return 0
	var due := maxi(0, pts - int(lb[n - 1]))
	lb[n - 1] = maxi(int(lb[n - 1]), pts)
	_book(d, today, "level:%d" % n, due)
	return due


## Welt des Tages: am Spieltag key voll, danach nur die Verbesserung.
static func pay_wdt(d: Dictionary, key: int, pts: int) -> int:
	var wb: Dictionary = d["wdt_best"]
	var had := int(wb.get(str(key), 0))
	var due := maxi(0, pts - had)
	wb[str(key)] = maxi(had, pts)
	var keys: Array = []
	for k in wb:
		keys.append(int(str(k)))
	keys.sort()
	while keys.size() > KEEP_WDT:
		wb.erase(str(keys.pop_front()))
	_book(d, key, "wdt", due)
	return due


## Weiterbauen: eine Extra-Aufgabe geschafft (+10, höchstens 3 je Level, jede nur einmal).
static func pay_extra(d: Dictionary, n: int, today: int = -1) -> int:
	var ex: Array = d["extras"]
	if n < 1 or n > ex.size() or int(ex[n - 1]) >= Balance.EXTRA_MAX:
		return 0
	ex[n - 1] = int(ex[n - 1]) + 1
	_book(d, today, "extra:%d" % n, Balance.EXTRA_POINTS)
	return Balance.EXTRA_POINTS


static func _today(d: Dictionary, today: int) -> Array:
	var h: Array = d["heute"]
	if int(h[0]) != today:
		h = [today, 0, 0, 0]
		d["heute"] = h
	return h


## Weiterbauen: ein neu gewachsenes Feld → +1, höchstens BUILD_POINTS_MAX je Spieltag. Gibt 0 oder 1.
static func build_point(d: Dictionary, today: int) -> int:
	var h := _today(d, today)
	if int(h[1]) >= Balance.BUILD_POINTS_MAX:
		return 0
	h[1] = int(h[1]) + 1
	_book(d, today, "bau", 1)
	return 1


## Freies Spiel oder 100-Sekunden-Challenge: +20 einmal je Spieltag.
static func free_play_point(d: Dictionary, today: int) -> int:
	var h := _today(d, today)
	if int(h[3]) > 0:
		return 0
	h[3] = Balance.FREE_PLAY_POINTS
	_book(d, today, "frei", Balance.FREE_PLAY_POINTS)
	return Balance.FREE_PLAY_POINTS


## Video (Platzhalter): +10, höchstens 2 je Spieltag, nicht in den ersten 3 Spieltagen, nur mit ADS_ON.
static func ad_ok(d: Dictionary, today: int, played_days: int) -> bool:
	if not Balance.ADS_ON or played_days < Balance.ADS_FROM_DAY:
		return false
	var h := _today(d, today)
	return int(h[2]) < Balance.AD_MAX


static func pay_ad(d: Dictionary, today: int, played_days: int) -> int:
	if not ad_ok(d, today, played_days):
		return 0
	var h := _today(d, today)
	h[2] = int(h[2]) + 1
	_book(d, today, "video", Balance.AD_POINTS)
	return Balance.AD_POINTS


## Serienbonus beim ersten Sieg des Spieltags: +2 × Serie, höchstens +10.
static func streak_bonus(streak: int) -> int:
	return mini(Balance.STREAK_BONUS_MAX, Balance.STREAK_BONUS_STEP * maxi(0, streak))


## Meilensteine der Serie: {"points", "gift"} (der 7er-Meilenstein mit vollem Schutz zahlt Daily.win selbst).
static func milestone(streak: int) -> Dictionary:
	return {"points": int(Balance.MILESTONE_BIG.get(streak, 0)), "gift": str(Balance.MILESTONE_GIFT.get(streak, ""))}


static func _book(d: Dictionary, today: int, src: String, pts: int) -> void:
	if pts <= 0:
		return
	d["summe"] = int(d["summe"]) + pts
	var log: Array = d["verlauf"]
	log.append([today, src, pts])
	while log.size() > KEEP_LOG:
		log.pop_front()


## Umstellung Münzen → Punkte (8.2), einmal (konto.version < 2): max(20 × Münzen, 60) + 20 je alter Stern.
## Gibt die neuen Punkte zurück.
static func migrate_coins(credits: int, old_stars: int) -> int:
	var p := maxi(Balance.POINTS_PER_COIN * maxi(0, credits), Balance.POINTS_START)
	return p + Balance.POINTS_PER_OLD_STAR * maxi(0, old_stars)


static func save(d: Dictionary, cfg: ConfigFile) -> void:
	cfg.set_value(SECTION, "level_best", d["level_best"])
	cfg.set_value(SECTION, "extras", d["extras"])
	cfg.set_value(SECTION, "wdt_best", d["wdt_best"])
	cfg.set_value(SECTION, "heute", d["heute"])
	cfg.set_value(SECTION, "summe", int(d["summe"]))
	cfg.set_value(SECTION, "verlauf", d["verlauf"])


static func load_from(cfg: ConfigFile, levels: int = 30) -> Dictionary:
	if cfg == null or not cfg.has_section(SECTION):
		return fresh(levels)
	var d := {"level_best": cfg.get_value(SECTION, "level_best", []), "extras": cfg.get_value(SECTION, "extras", []),
		"wdt_best": cfg.get_value(SECTION, "wdt_best", {}), "heute": cfg.get_value(SECTION, "heute", [-1, 0, 0, 0]),
		"summe": cfg.get_value(SECTION, "summe", 0), "verlauf": cfg.get_value(SECTION, "verlauf", [])}
	return sanitize(d, levels)
