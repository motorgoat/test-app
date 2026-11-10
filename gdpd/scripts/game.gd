extends Node
## Autoload „Game“: hält den Spielstand, den Rundenablauf, die Boni und den Rekord.
## Keine Darstellung hier. World und UI hören auf die Signale.

signal state_changed
signal new_game_started
signal round_resolved(result: Dictionary, before: Dictionary)   # World spielt die Effekte ab
signal message(text: String, kind: String)                     # kind: info, good, bad
signal game_over
signal move_done(kind: String)                                   # "twist", "rain", "bolt", "monsoon" (fürs Tutorial)
signal tutorial_changed
signal tutorial_bloom(ids: Array)                                # nach dem Tutorial: diese Felder erblühen (World animiert)
## gdpd: Ein Zug braucht eine Wahl („Dein Wille geschehe“). Die Oberfläche zeigt die Karte (oder die kleine Pille,
## wenn info["mini"]) und ruft danach Game.choose(0/1) auf (oder Game.choose_default() bei Zeitablauf/Tipp daneben).
## Hört niemand auf das Signal, nimmt Game sofort den Standard. Während die Wahl offen ist, ist busy = true.
## info: {"kind", "field", "fields", "options": [Art 1, Art 2], "default": 0/1, "best": 0/1 (Empfehlung),
##        "mini": bool, "timeout": Sekunden (0 = kein Zeitlimit, Tutorial), "action": {...}}
signal choice_needed(info: Dictionary)
signal choice_made(info: Dictionary)                             # info wie oben plus "picked"
## Die Schöpfung in 7 Tagen (docs/GDPD_7_TAGE.md). info siehe day_info(): Ziel-Karte zeigen.
signal day_started(info: Dictionary)
## Der Fortschritt zum Ziel hat sich bewegt (Chip hüpft): status = GameState.day_status().
signal day_progress(status: Dictionary)
## Tag geschafft: info = day_info() + {"stars", "used", "best_stars", "first_win", "next_day" (0 = keiner),
## "world_complete" (Tag 7 zum ersten Mal), "stars_total", "stars_max"}.
signal day_won(info: Dictionary)
## Tag gescheitert: info = day_info() + {"why" ("twists"|"war"|"fire"), "progress", "target", "mercy_next"}.
signal day_lost(info: Dictionary)
## Täglich spielen (docs/GDPD_TAEGLICH_CHARAKTER.md): der Spieltag, die Freischaltung, die Serie oder der Serienschutz
## haben sich geändert (neuer Spieltag, Test-Knopf, Kauf). Die Übersicht zeichnet neu (today_info()).
signal daily_changed
## Ein Serientag ist geschafft: info = Daily.win() ({"counted", "before", "streak", "best", "milestone", "big",
## "shield", "coins", "shields"}). Kommt direkt nach day_won (dort steht es auch als info["streak"]).
signal streak_changed(info: Dictionary)
## „Neuer Morgen“ (GDPD_BALANCE_2.md 5.6): beim ersten Start eines Tages ≥ 2 (nicht bei „Nochmal“, nicht in der
## Welt des Tages). info = {"type": "overnight", "day", "changes": [{"field", "from", "kind"}],
## "caps": „Neuer Morgen“, "line" („Erde wird Wiese“)}. Nur Darstellung: Die Regeln starten vom Pool-Brett.
signal overnight_growth(info: Dictionary)
## Ein neuer Erinnerungs-Plan (ReminderPlan.plan, schon mit echter Uhrzeit): das Plugin plant ihn ein.
## Hört niemand zu (PC, CI), schreibt Game die Zeilen „REMINDER …“ ins Protokoll.
signal reminders_planned(plan: Array)
## Punkte haben sich geändert (delta, Quelle: "level", "streak", "extra", "bau", "frei", "video", "kauf", "migration").
signal points_changed(delta: int, source: String)
## Die Schöpfung: ein Level beginnt (info wie level_info()).
signal level_started(info: Dictionary)
## Sackgasse in einem Level (GameState.dead9): das Ziel geht nicht mehr – die Oberfläche bietet „Nochmal“ (gratis).
signal level_dead(info: Dictionary)

const SAVE_PATH := "user://rekord.cfg"
const SETTINGS_PATH := "user://einstellungen.cfg"
const PRAISE = ["Dein Wille geschehe!", "Euer Wille geschehe!", "Halleluja!", "Gelobt sei der Herr!"]
const GASP = ["Um Gottes Willen!", "Grundgütiger!", "Herrgott nochmal!", "Heiliger Strohsack!"]
## Drei Stufen (offen, bis die Welt verbrennt) und die Challenge (40 Drehungen, Mittel-Regeln).
const LEVELS = ["Einfach", "Mittel", "Schwer"]
const MODE_KEYS = ["einfach", "mittel", "schwer"]
const CHALLENGE_LEVEL := 1
const MODE_INTRO = {
	"einfach": "Einfach: Gruppen wachsen mit. 5 Herzen.",
	"mittel": "Mittel: Schräg zählt ab Wald.",
	"schwer": "Schwer: Nur gerade Reihen.",
	"challenge": "Wie viel Glaube in 40 Drehungen?",
	"sek100": "Uhr startet mit der ersten Drehung.",
}
## Was neue Spieler nach und nach kennenlernen (in coach_seen gemerkt, „Tutorial nochmal“ setzt es zurück).
const REVEAL_FLAGS = ["show_undo", "show_hint", "show_bolt", "show_coins", "show_flames"]

var state: GameState
var busy := false          # Runde wird ausgewertet/animiert
var over := false
var continued := false     # einmal pro Spiel weiterspielen
var undo_state: GameState = null   # Stand vor dem letzten Zug (ein Schritt zurück)
var best := 0              # Rekord in Glauben (dieser Modus, Stand bei Spielbeginn)
var pending_choice: Dictionary = {}   # offene Wahl (siehe choice_needed), sonst leer
var cards_seen := {}       # Art → so oft wurde die große Wahl-Karte schon gezeigt (danach die kleine Pille)
var always_ask := false    # Einstellung „Immer fragen“: immer die große Karte
var tutorial_done := false
var tutorial_step := -1    # Schritt im Tutorial, -1 = kein Tutorial
var coach_seen := {}       # Hinweise, die schon einmal gezeigt wurden (und was schon aufgedeckt ist)
var onboarding := false    # die ersten Minuten nach dem Tutorial: Tipp leuchtet gratis nach einer Pause
var undoing := false       # während undo() new_game_started sendet: dasselbe Spiel läuft weiter (kein neuer Versuch)
var hint_searches := 0     # laufende Tipp-Suchen (search_hint)
var _onb_merges := 0
var _onb_twists := 0
var _tut_board := false    # das Spiel läuft auf dem Tutorial-Würfel
var _announce := false     # Spielart im Menü gewählt: kurz sagen, was gilt
var _last_kind := ""
var points := 0            # Punkte: die eine Währung (GDPD_PUNKTE_LADEN.md), gespeichert in [konto] punkte
## Alter Name (Münzen) für ältere Oberflächen-Teile: dasselbe wie points.
var credits: int:
	get:
		return points
	set(v):
		points = maxi(0, v)
var points_migrated := 0   # > 0: Punkte aus der Umstellung Münzen → Punkte, der Hinweis ist noch nicht gezeigt
var pdata: Dictionary = {}  # Punkte-Buchhaltung (Points.fresh), gespeichert in [punkte]
var new_record := false
var endless := true        # false = Challenge (40 Drehungen)
var level := 0             # 0 Einfach (berühren), 1 Mittel (Reihen + Diagonalen), 2 Schwer (nur Reihen)
var _best := {"einfach": 0, "mittel": 0, "schwer": 0, "challenge": 0, "sek100": 0}
var music_on := true
var sfx_on := true

# --- Die Schöpfung in 7 Tagen ----------------------------------------------------------------
var day_no := 0              # laufender Tag (1 … 7), 0 = freies Spiel
var day_board := {}          # das Brett dieses Versuchs (Days.board): kinds, seed, index, solution …
var first_launch := false    # allererster Start: gleich in Tag 1 (keine Übersicht)
## Fortschritt (in rekord.cfg, Abschnitt [schoepfung]), getrennt von den Rekorden des freien Spiels:
var day_stars: Array = []    # beste Sterne je Tag (0 = nicht geschafft)
var day_best: Array = []     # wenigste Drehungen je Tag (0 = keine)
## Höchster spielbarer Tag (1 … 7; 8 = alle geschafft). Alter Wert: Er folgt der Freischaltung nach Datum
## (Daily.day_free); gesetzt wird nur noch der gespeicherte Rohwert.
var day_free: int:
	get:
		if daily.is_empty() or day_stars.size() != Days.count():
			return _day_free_raw
		return Daily.day_free(daily, day_stars, today_key())
	set(v):
		_day_free_raw = v
var _day_free_raw := 1
var day_fails: Array = []    # Fehlversuche seit dem letzten Sieg je Tag (Gnade)
var day_next_board: Array = []   # nächstes Pool-Brett je Tag
var world_done := false      # Tag 7 einmal geschafft: freies Spiel offen, „Vollendet“
var save_path := SAVE_PATH   # Tests leiten das auf eine eigene Datei um

# --- Täglich spielen (GDPD_TAEGLICH_CHARAKTER.md 1, 2, 5, 7; reine Logik in Daily und ReminderPlan) -----------
var daily: Dictionary = {}       # Tageszustand (Daily.fresh), gespeichert in [taeglich]
## Erinnerungen [erinnerung]: "mode" ("auto" | "fest" | "aus"), "fixed_min" (Minute des Tages), "asked" (so oft
## wurde im Spiel gefragt, 0–2), "history" (letzte Text-IDs, neueste zuerst), "planned" ({id, at, tpl, key} des Plans)
var remind: Dictionary = {}
var remind_permission := false   # das Plugin setzt das (Android: Erlaubnis da und Benachrichtigungen an)
var reminder_log: Array = []     # der letzte Plan (Tests, Tour)
var reminder_echo := true        # ohne Zuhörer: Plan als „REMINDER …“-Zeilen ausgeben
var clock_override := -1         # Tests/Tour: feste Ortszeit (lokale Unix-Sekunden); -1 = Systemuhr
var debug_day_offset := 0        # „Nächster Tag (Test)“: so viele ganze Tage weiter (nur in Test-Versionen)
var debug_open_all := false      # Tour: alle 7 Tage offen (nur in Test-Versionen)
var session_start := -1          # Ortszeit, zu der diese Sitzung begann (Uhrzeit der Erinnerung)
var wdt_key := -1                # dieser Versuch ist die Welt des Tages dieses Spieltags (-1 = ein Tag 1 … 7)
var overnight: Dictionary = {}   # „Neuer Morgen“ dieses Versuchs (overnight_growth), {} = keins
var _retrying := false           # retry_day läuft gerade (kein „Neuer Morgen“)
var attempt_key := -1            # Spieltag, an dem der laufende Versuch begann (-1 = keiner)
var attempt_start := -1          # Spielzeit, zu der er begann
var _check_due := false          # Tagesprüfung (Serienschutz) steht noch aus
var _last_today := -2147483648
## Der eigene Charakter (Character, [charakter] in user://charakter.cfg). {} = noch keiner: der Ersteller kommt zuerst.
var character: Dictionary = {}


func _ready() -> void:
	set_process(true)
	_load_settings()
	_load_best()
	character = Character.load_look()
	note_session()
	call_deferred("replan_reminders")      # nach den anderen Autoloads (Plugin-Hülle)
	if Balance.CAMPAIGN_ON:
		if not resume_run():          # Build 12: ein laufendes Level geht genau dort weiter, wo die App zuging
			start_level(current_level())
	elif world_done:
		new_game()
	else:
		start_day(current_day())


## endless_mode: -1 = wie zuletzt, 1 = offen, 0 = Challenge (40 Drehungen, immer Mittel). lvl: -1 = wie zuletzt.
## Alle Modi haben 3 Herzen.
## Freies Spiel (das Tutorial ist jetzt Tag 1, siehe start_day).
func new_game(seed_value: int = 0, endless_mode: int = -1, lvl: int = -1) -> void:
	if state != null:
		_save_best()            # Punkte des alten Spiels zählen für den Rekord (Tage zählen nicht)
	if endless_mode >= 0:
		endless = endless_mode == 1
	if lvl >= 0:
		level = clampi(lvl, 0, LEVELS.size() - 1)
	if not endless:
		level = CHALLENGE_LEVEL
	var ended_tutorial := tutorial_step >= 0
	# „Neues Spiel“ nach der Challenge (ohne Spielart): wieder 100 Sekunden, nicht still ins endlose Mittel
	sek100 = _sek_next or (endless_mode < 0 and lvl < 0 and sek100 and state != null and not state.is_day())
	_sek_next = false
	sek100_left = SEK100
	sek100_running = false
	sek100_done = false
	if sek100:
		endless = true
		level = CHALLENGE_LEVEL
	tutorial_step = -1
	_tut_board = false
	if level_no > 0:
		_clear_run()                 # das Level wird verlassen: es beginnt beim nächsten Mal neu
	day_no = 0
	level_no = 0
	day_board = {}
	wdt_key = -1
	best = int(_best.get(mode_key(), 0))
	state = GameState.new()
	state.setup(seed_value, endless, level, not sek100)   # Challenge: keine Herzen, ein Feuer kostet nur 5 s
	pending_choice = {}
	busy = false
	over = false
	continued = false
	undo_state = null
	new_record = false
	new_game_started.emit()
	state_changed.emit()
	if tutorial_step >= 0 or ended_tutorial:
		tutorial_changed.emit()      # Oberfläche zeigt den Tutorial-Schritt (auch nach „Tutorial neu“)
	if tutorial_step < 0 and _announce:
		message.emit(str(MODE_INTRO.get(mode_key(), "")), "info")
	_announce = false


## Neues Spiel in einer Spielart: "einfach" | "mittel" | "schwer" | "challenge" (aus dem Menü).
func start_mode(key: String) -> void:
	_announce = true
	if key == "sek100":
		_sek_next = true
		new_game(0, 1, CHALLENGE_LEVEL)
		return
	if key == "challenge":
		new_game(0, 0, CHALLENGE_LEVEL)
	else:
		new_game(0, 1, maxi(0, MODE_KEYS.find(key)))


func level_name() -> String:
	return str(LEVELS[clampi(level, 0, LEVELS.size() - 1)])


## "einfach" | "mittel" | "schwer" | "challenge"
func mode_key() -> String:
	if sek100:
		return "sek100"
	if not endless:
		return "challenge"
	return str(MODE_KEYS[clampi(level, 0, MODE_KEYS.size() - 1)])


func _mode_key() -> String:
	return mode_key()


## Rekord einer Spielart (Glaube).
func best_for(key: String) -> int:
	return int(_best.get(key, 0))


func rounds_survived() -> int:
	return state.turn - 1


## Das alte Schritt-für-Schritt-Tutorial gibt es nicht mehr: Tag 1 ist das Tutorial (day_tutorial()).
## Bleibt false, damit ältere Oberflächen-Teile weiter laufen.
func tutorial() -> bool:
	return tutorial_step >= 0


## „Tutorial nochmal“: Hinweise zurücksetzen und Tag 1 auf dem Tutorial-Brett (Brett 0) spielen.
func restart_tutorial() -> void:
	coach_seen = {}
	cards_seen = {}
	onboarding = false
	start_day(1, 0)


func tutorial_next() -> void:
	pass


## Altes Tutorial-Ende (nichts mehr zu tun).
func finish_tutorial() -> void:
	if tutorial_step >= 0:
		tutorial_step = -1
		tutorial_changed.emit()


## Alter Name (Notausgang im Tutorial, Menü).
func end_tutorial() -> void:
	finish_tutorial()


## Was zählt: der Glaube (alter Name score).
func score() -> int:
	return state.faith


func faith() -> int:
	return state.faith


## Was würde diese Drehung bewirken? row: die Felder, über die gewischt wird.
func preview(axis: int, layer: int, turns: int, row: Array = []) -> Dictionary:
	var sim := state.clone()
	if turns != 0:
		sim.apply_rotation(axis, layer, turns, row)
	var arranged := sim.clone()
	var result := sim.end_round()
	var war: Array = []
	for e in result["events"]:
		if str(e["type"]) == "war":
			war = e["fields"]
	return {
		"arranged": arranged,     # Welt direkt nach der Drehung
		"state": sim,             # Welt nach der Auswertung (mit der Gewohnheit als Antwort)
		"gain": int(result["gain"]),
		"faith": int(result["faith"]),
		"events": result["events"],
		"card": sim.card,         # Art der Wahl, die kommen würde (-1: keine) → „?“ über card_field
		"card_field": sim.card_field,
		"war": war,               # Kirchen, die Krieg führen würden (gekreuzte Schwerter)
		# Neue Tage (GDPD_BALANCE_2.md 4.6): wer wird satt, wer verliert es, Krieg/Flut/Feuer-Gefahr nach der Drehung
		"supply": state.preview8(axis, layer, turns, sim) if (state.v8 or state.camp) and turns != 0 else {},
	}


static func snapshot(gs: GameState) -> Dictionary:
	var s := {}
	for f in gs.fields:
		s[f.id] = f.kind
	return s


## Einen Zug spielen. turns = 0 heißt „Warten“. Die World ruft danach finish_round() auf.
func play_turn(axis: int, layer: int, turns: int, row: Array = []) -> void:
	if busy or over:
		return
	busy = true
	if not state.is_day():
		state.no_fire = tutorial()      # im Tutorial zählen Fehlversuche nicht (an den Tagen: der Tag entscheidet)
		state.calm = tutorial()
	_last_kind = "twist" if turns != 0 else "wait"
	if sek100 and turns != 0 and not sek100_running and not sek100_done:
		sek100_running = true          # die Uhr startet mit der ersten Drehung
		sek100_changed.emit(sek100_left, 0.0)
	_start({"type": "twist", "axis": axis, "layer": layer, "turns": turns, "row": row.duplicate()})


## Einen Zug beginnen: Kommt eine Wahl, erst fragen (choice_needed), sonst gleich auswerten.
## Das ist deterministisch: Bis zur ersten Wahl hängt der Zug nicht von der Antwort ab.
func _start(action: Dictionary) -> void:
	var info := state.choice_for(action)
	if info.is_empty():
		_resolve(action, {})
		return
	var k := int(info["kind"])
	info["action"] = action
	info["mini"] = not tutorial() and not always_ask and int(cards_seen.get(k, 0)) >= Balance.CHOICE_FULL_CARDS
	# An den Tagen hat die große Karte kein Zeitlimit: Wer die Wahl zum ersten Mal sieht, soll in Ruhe lesen dürfen.
	var calm := tutorial() or (in_day() and not bool(info["mini"]))
	info["timeout"] = 0.0 if calm else (Balance.MINI_CARD_SECONDS if bool(info["mini"]) else Balance.CHOICE_TIMEOUT)
	info["best"] = state.recommend_choice(action)
	if not bool(info["mini"]) and not tutorial():
		cards_seen[k] = int(cards_seen.get(k, 0)) + 1
	pending_choice = info
	choice_needed.emit(info)
	if choice_needed.get_connections().is_empty() and not pending_choice.is_empty():
		choose_default()


## Antwort auf die offene Wahl: 0 = erste Option, 1 = zweite. Wertet den Zug aus.
func choose(option: int) -> void:
	if pending_choice.is_empty():
		return
	var info := pending_choice
	pending_choice = {}
	info["picked"] = clampi(option, 0, 1)
	choice_made.emit(info)
	_resolve(info["action"], {int(info["kind"]): int(info["picked"])})


## Zeit abgelaufen oder daneben getippt: die Gewohnheit (deine letzte Wahl) gilt.
func choose_default() -> void:
	if pending_choice.is_empty():
		return
	choose(int(pending_choice["default"]))


func has_choice() -> bool:
	return not pending_choice.is_empty()


func _resolve(action: Dictionary, answers: Dictionary) -> void:
	undo_state = state.clone()
	var before := snapshot(state)
	var result := state.play(action, answers)
	round_resolved.emit(result, before)


func finish_round(result: Dictionary) -> void:
	busy = false
	_commit_stock()                  # Build 12: gekauftes Wunder und Lauf ändern sich zusammen
	# Neues Zeitalter, neuer Bonus: Das zeigt die Oberfläche (Pille, Geschenk, beim ersten Mal ein Hinweis).
	if onboarding and _last_kind == "twist" and not state.is_day():
		_onb_twists += 1
		if int(result.get("gain", 0)) > 0:
			_onb_merges += 1
		if _onb_merges >= Balance.ONBOARD_MERGES or _onb_twists >= Balance.ONBOARD_TWISTS:
			onboarding = false
	for e in result["events"]:
		if str(e["type"]) == "complete":
			message.emit("Deine Welt ist vollendet!", "good")
		if str(e["type"]) == "disaster" and sek100 and sek100_running:
			_sek100_fire()             # ein Feuer kostet 5 Sekunden
		if str(e["type"]) == "disaster" and not state.is_over() and coach_seen.has("fire"):
			# Beim ersten Feuer erklärt ein Hinweis alles; danach eine kurze Meldung
			if state.hearts:
				message.emit("Feuer! Noch %d %s." % [state.lives, "Herz" if state.lives == 1 else "Herzen"], "bad")
			else:
				message.emit("Feuer! Gieß es mit Regen.", "bad")
		if str(e["type"]) == "gift":
			message.emit("Nichts passt. Hier, ein Regen!", "good")
	# Nichts mehr zu verbinden? Dann gibt es einen Regen geschenkt. (An den Tagen macht das der Spielstand.)
	if not state.is_day() and not state.is_over() and state.gadgets and state.stuck():
		state.grant("rain")
		message.emit("Nichts passt. Hier, ein Regen!", "good")
	var moved_goal := false
	for e in result["events"]:
		if str(e["type"]) == "goal":
			moved_goal = true
	if state.is_day():
		if moved_goal:
			day_progress.emit(state.day_status())
		if level_no > 0 and not state.day_won:
			_rescue_check()
		if state.is_over() and not over:
			over = true
			state_changed.emit()
			move_done.emit(_last_kind)
			_finish_day()
			return
	elif state.is_over():
		over = true
		if sek100:
			sek100_done = true
			sek100_running = false
		_save_best()
		game_over.emit()
	elif sek100 and sek100_running and sek100_left <= 0.0:
		_sek100_end()
	if level_no > 0 and state.camp:
		_save_run()                  # Build 12: nach jeder Runde (App zu → das Level geht genau hier weiter)
	state_changed.emit()
	move_done.emit(_last_kind)


## Werkzeug: "rain" | "bolt" | "monsoon" (Segen) | "strike" (Gewitter) | "flood" (Flut) auf ein Feld.
## Blitz: row = 3 IDs (sonst die Eck-Diagonale). Zählt als Zug (Regen nicht); die World spielt ihn ab.
## Kommt dabei eine Wahl, gibt es erst choice_needed (wie bei play_turn).
## quiet: keine Meldung, wenn es nicht geht (die Oberfläche zeigt es selbst).
func use_bonus(kind: String, fid: int, row: Array = [], quiet: bool = false) -> bool:
	if busy or over:
		return false
	var f: FieldData = state.fields[fid]
	var err := state.can_bonus(kind, f)
	if err != "":
		if not quiet:
			message.emit(err, "info")
		return false
	busy = true
	state.calm = tutorial()
	_last_kind = kind
	# Regen ist kein ganzer Zug (resolve_now): Man kann mehrmals hintereinander gießen
	_start({"type": kind, "field": fid, "row": row.duplicate()})
	return true


static func praise() -> String:
	return str(PRAISE[randi() % PRAISE.size()])


static func gasp() -> String:
	return str(GASP[randi() % GASP.size()])


## Einstellung „Immer fragen“: immer die große Wahl-Karte statt der kleinen Pille.
func set_always_ask(on: bool) -> void:
	always_ask = on
	_save_profile()


## Art-Tabelle für die Oberfläche (Name, Icon, Stufe, Optionen, Glaube pro Drehung, Erklärung).
static func kind_info(k: int) -> Dictionary:
	return FieldData.info(k)


## Einmal pro Spiel nach dem Ende weiterspielen (kostet Münzen).
func can_continue() -> bool:
	return over and not continued and state.died()


## Einen Schritt zurück: der Stand vor dem letzten Zug (nur einmal hintereinander). Ein beendeter Tag nicht.
func can_undo() -> bool:
	return undo_state != null and not busy and not (over and day_no > 0)


func undo() -> void:
	if not can_undo():
		return
	var steps_before := state.steps9() if state.camp else 0
	state = undo_state
	undo_state = null
	if state.camp and not state.day_won:
		state.extra_steps += maxi(0, steps_before - state.steps9())      # der Schritt bleibt gezählt
	pending_choice = {}
	over = false
	# Die Welt baut sich neu auf (new_game_started); die Oberfläche erkennt an undoing, dass der Tag weiterläuft
	undoing = true
	new_game_started.emit()
	undoing = false
	if level_no > 0 and state.camp:
		_save_run()
	state_changed.emit()
	message.emit("Zug zurückgenommen.", "info")


func continue_game() -> void:
	if not can_continue():
		return
	continued = true
	if state.died():
		state.lives = 1
	if state.stuck():
		state.rain = maxi(state.rain, 2)
	over = false
	message.emit("Noch eine Chance!", "good")
	state_changed.emit()


## Bonus schenken oder kaufen (außerhalb eines Zugs).
func grant(kind: String) -> void:
	state.grant(kind)
	state_changed.emit()


## Münzen ausgeben. true = bezahlt.
func spend(cost: int) -> bool:
	if points < cost:
		return false
	points -= cost
	_save_profile()
	points_changed.emit(-cost, "kauf")
	return true


## Platzhalter für „Video ansehen“: gibt Punkte (+10, höchstens 2 je Spieltag, nur mit Balance.ADS_ON und nicht in den
## ersten 3 Spieltagen). Später kommt hier die echte Werbung hin.
func reward_ad() -> void:
	_ensure_daily()
	var k := today_key()
	var played := k - int(daily.get("first_key", k)) + 1
	if not Balance.ADS_ON:
		points += Balance.CREDITS_PER_AD          # Platzhalter der Test-Versionen (der Video-Knopf ist sonst aus)
		_save_profile()
		points_changed.emit(Balance.CREDITS_PER_AD, "video")
		return
	_add_points(Points.pay_ad(pdata, k, played), "video")
	_save_profile()


func save_settings() -> void:
	_save_profile()


# =============================================================================
# Ton: Musik und Effekte (Busse „Music“ und „SFX“; Effekte aus = auch keine Vibration)
# =============================================================================

func set_audio(music: bool, sfx: bool) -> void:
	music_on = music
	sfx_on = sfx
	_apply_audio()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)            # andere Einträge (z. B. Hilfe gesehen) behalten
	cfg.set_value("audio", "musik", music_on)
	cfg.set_value("audio", "effekte", sfx_on)
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_on = bool(cfg.get_value("audio", "musik", true))
		sfx_on = bool(cfg.get_value("audio", "effekte", true))
	_apply_audio()


static func _ensure_bus(bus_name: String) -> int:
	var i := AudioServer.get_bus_index(bus_name)
	if i == -1:
		AudioServer.add_bus()
		i = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	return i


func _apply_audio() -> void:
	AudioServer.set_bus_mute(_ensure_bus("Music"), not music_on)
	AudioServer.set_bus_mute(_ensure_bus("SFX"), not sfx_on)
	Style.haptics_on = sfx_on


# =============================================================================
# Speichern: Rekord je Spielart, Tutorial, Hinweise, Münzen
# =============================================================================

func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		for k in _best.keys():
			_best[k] = int(cfg.get_value("rekorde", str(k), _old_best(cfg, str(k))))
		# zuletzt gespielte Spielart wieder aufnehmen
		var mk: String = str(cfg.get_value("spiel", "modus", "einfach"))
		if mk == "sek100":
			mk = "mittel"
		endless = mk != "challenge"
		level = CHALLENGE_LEVEL if mk == "challenge" else maxi(0, MODE_KEYS.find(mk))
		tutorial_done = bool(cfg.get_value("tutorial", "fertig", false))
		for k in cfg.get_value("tutorial", "hinweise", []):
			coach_seen[str(k)] = true
		_load_points(cfg)
		var cs: Dictionary = cfg.get_value("wahl", "karten", {})
		for k in cs:
			cards_seen[int(k)] = int(cs[k])
		always_ask = bool(cfg.get_value("wahl", "immer_fragen", false))
		_load_campaign(cfg)
	else:
		points = Balance.POINTS_START
		pdata = Points.fresh(Campaign.COUNT)
		first_launch = true
		_load_campaign(null)
	# Wer das Tutorial schon aus einer älteren Version kennt, sieht gleich alles
	if tutorial_done and not coach_seen.has("reveal_v1"):
		for k in REVEAL_FLAGS:
			coach_seen[str(k)] = true
		coach_seen["reveal_v1"] = true


## Rekorde aus älteren Versionen (Abschnitt „rekord“: stufe_0..3, survival0..3, runden40_punkte).
static func _old_best(cfg: ConfigFile, key: String) -> int:
	if key == "challenge":
		return int(cfg.get_value("rekord", "runden40_punkte", 0))
	var lv := MODE_KEYS.find(key)
	if lv < 0:
		return 0
	var lvs: Array = [lv, 3] if lv == 2 else [lv]      # Profi gibt es nicht mehr: zählt zu Schwer
	var out := 0
	for l in lvs:
		out = maxi(out, int(cfg.get_value("rekord", "stufe_" + str(l), 0)))
		out = maxi(out, int(cfg.get_value("rekord", "stufe_survival" + str(l), 0)))
	return out


## Spielende (oder ein laufendes Spiel wird verlassen): der Glaube JETZT zählt für den Rekord.
## Mitten im Spiel nie aufrufen – Glaube kann wieder sinken (Krieg, Strafen), der Rekord zählt das Ende.
func _save_best() -> void:
	if state != null and not tutorial() and not state.is_day():
		var mk := mode_key()
		if over:
			new_record = score() > best
		_best[mk] = maxi(int(_best.get(mk, 0)), score())
		if over:
			best = maxi(best, score())
	_save_profile()


## Einstellungen, Münzen, Hinweise und Wahl-Karten speichern, ohne den Rekord anzufassen.
func _save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.load(save_path)                # andere Abschnitte (z. B. von neueren Teilen) behalten
	for k in _best.keys():
		cfg.set_value("rekorde", str(k), int(_best[k]))
	cfg.set_value("tutorial", "fertig", tutorial_done)
	cfg.set_value("tutorial", "hinweise", coach_seen.keys())
	cfg.set_value("konto", "punkte", points)
	cfg.set_value("konto", "version", 2)
	cfg.set_value("konto", "umgestellt", points_migrated)
	if cfg.has_section_key("konto", "credits"):
		cfg.erase_section_key("konto", "credits")
	if pdata.is_empty():
		pdata = Points.fresh(Campaign.COUNT)
	Points.save(pdata, cfg)
	_save_camp(cfg)
	cfg.set_value("spiel", "modus", mode_key())
	cfg.set_value("wahl", "karten", cards_seen)
	cfg.set_value("wahl", "immer_fragen", always_ask)
	_ensure_campaign()
	cfg.set_value("schoepfung", "sterne", day_stars)
	cfg.set_value("schoepfung", "beste", day_best)
	cfg.set_value("schoepfung", "frei", day_free)
	cfg.set_value("schoepfung", "fehlversuche", day_fails)
	cfg.set_value("schoepfung", "brett", day_next_board)
	cfg.set_value("schoepfung", "fertig", world_done)
	cfg.set_value("schoepfung", "version", 3)
	_ensure_daily()
	daily["test_days"] = debug_day_offset
	Daily.save(daily, cfg)
	_save_remind(cfg)
	cfg.save(save_path)


# =============================================================================
# Die Schöpfung in 7 Tagen: Tage starten, Sieg/Niederlage, Gnade, Fortschritt (GDPD_7_TAGE.md 2–4)
# =============================================================================

## Tag n starten (nur, wenn er frei ist). board_index: welches Pool-Brett (-1 = das nächste laut Fortschritt;
## der erste Besuch von Tag 1 ist Brett 0, das Tutorial-Brett). Gnade: +2 Drehungen je Fehlversuch (höchstens +6).
## Gibt false zurück, wenn der Tag gesperrt ist. Ein laufender Tag, der verlassen wird, zählt nicht (kein Nachteil).
func start_day(n: int, board_index: int = -1) -> bool:
	_ensure_campaign()
	if n < 1 or n > Days.count() or not day_unlocked(n):
		return false
	var idx := board_index if board_index >= 0 else int(day_next_board[n - 1])
	_board_explicit = board_index >= 0
	wdt_key = -1
	var b := Days.board(n, idx)
	var cfg := Days.config(n)
	overnight = {}
	if n >= 2 and not _retrying and not b.is_empty():
		var ch := Days.overnight_changes(cfg, b["kinds"])
		if not ch.is_empty():
			overnight = {"type": "overnight", "day": n, "changes": ch, "caps": str(Days.TEXT["overnight"]),
				"line": str(cfg.get("overnight_line", ""))}
	_start_attempt(n, cfg, b, day_mercy(n))
	if not overnight.is_empty():
		overnight_growth.emit(overnight.duplicate(true))
	return true


## Die Welt des Tages von heute starten (nach Tag 7, GDPD_TAEGLICH_CHARAKTER.md 1.3). false: gibt es heute nicht.
func start_daily_world() -> bool:
	if Balance.CAMPAIGN_ON:
		return start_level_wdt()
	_ensure_campaign()
	var k := today_key()
	if not Daily.wdt_available(daily, day_stars, k):
		return false
	var cfg := Daily.wdt_config(k)
	if cfg.is_empty():
		return false
	_board_explicit = true
	wdt_key = k
	overnight = {}
	_start_attempt(int(cfg["day"]), cfg, Daily.wdt_board(k), Daily.wdt_mercy(daily, k))
	return true


## Gibt es heute eine Welt des Tages (Tag 7 an einem früheren Spieltag geschafft)?
func daily_world_available() -> bool:
	_ensure_campaign()
	return Daily.wdt_available(daily, day_stars, today_key())


## Läuft gerade die Welt des Tages?
func in_daily_world() -> bool:
	return in_day() and wdt_key >= 0


func _start_attempt(n: int, cfg: Dictionary, b: Dictionary, mercy: int) -> void:
	sek100 = false
	if state != null and not state.is_day():
		_save_best()             # Glaube des freien Spiels zählt noch für den Rekord
	attempt_key = today_key()
	attempt_start = game_now()
	level_no = 0
	day_no = n
	day_board = b
	tutorial_step = -1
	_tut_board = false
	state = GameState.new()
	if b.is_empty():
		push_warning("Days: kein Brett für Tag %d" % n)
		state.setup_day(cfg, [], 1, mercy)
	else:
		state.setup_day(cfg, b["kinds"], int(b["seed"]), mercy)
	pending_choice = {}
	busy = false
	over = false
	continued = false
	undo_state = null
	new_record = false
	onboarding = bool(cfg.get("onboard_hint", false))
	new_game_started.emit()
	state_changed.emit()
	day_started.emit(day_info())


## Denselben Tag noch einmal (das nächste Brett des Pools, eine Wiederholung ist nie ein Gedächtnistest).
## Die Welt des Tages: dieselbe Welt noch einmal (an ihrem Spieltag).
func retry_day() -> bool:
	if level_no > 0:
		return retry_level()
	if wdt_key >= 0:
		return start_daily_world()
	_retrying = true
	var ok := start_day(maxi(1, day_no))
	_retrying = false
	return ok


## Nach einem Sieg: der nächste Tag (false, wenn es keinen gibt – dann ist die Welt vollendet).
func next_day() -> bool:
	if level_no > 0:
		return wdt_key < 0 and level_no < Campaign.COUNT and start_level(level_no + 1)
	if wdt_key >= 0 or day_no >= Days.count():
		return false
	return start_day(day_no + 1)


## Läuft gerade ein Tag?
func in_day() -> bool:
	return (day_no > 0 or level_no > 0) and state != null and state.is_day()


## Tag 1 auf dem Tutorial-Brett (Brett 0): die Oberfläche zeigt die Hand und die Coach-Sätze von Tag 1.
func day_tutorial() -> bool:
	return in_day() and (day_no == 1 or (level_no == 1 and wdt_key < 0)) and int(day_board.get("index", -1)) == 0 \
		and state.used_twists() < 3


## Spielt die Hand gleich den ersten Zug vor („Zeig's mir“)? Level/Tag 1 auf dem Lehr-Brett, noch keine Drehung, und
## die Vorführung lief noch nie (oder Brett 0 wurde ausdrücklich gewählt). Ein Versuch, der nur bis zur Start-Karte
## kam (App zu, Karte zu vor „Los“), lässt sie offen: er wird nicht gespeichert.
func demo_pending() -> bool:
	return day_tutorial() and state.twists == 0 and (not coach_seen.has("day1_demo") or _board_explicit)


## Die vorgezeigte Drehung des Tutorials ({"axis", "layer", "turns"}) oder {}.
## Lässt sie (nach einem anderen ersten Zug) nichts mehr wachsen, zeigen Hand und Leuchten eine Drehung, die es tut –
## nie einen Zug, der nichts bringt. Gibt es keine, {} (dann hilft der Tipp).
func tutorial_move() -> Dictionary:
	if not day_tutorial():
		return {}
	var key := "%d:%d" % [state.get_instance_id(), state.twists]
	if key == _tut_move_key:
		return _tut_move.duplicate()
	_tut_move_key = key
	_tut_move = {}
	var mv: Dictionary = (Days.config(1).get("tutorial", {}) as Dictionary).duplicate()
	if level_no == 1:
		mv = {"axis": 0, "layer": 1, "turns": 1}
	if not mv.is_empty() and _twist_grows(int(mv["axis"]), int(mv["layer"]), int(mv["turns"])):
		_tut_move = mv
		return mv.duplicate()
	# Erst Scheiben, die oben auf dem Würfel liegen (dort schaut man hin), dann die anderen
	for a in [0, 2, 1]:
		for l in [1, 0, -1]:
			for t in [1, -1]:
				if _twist_grows(int(a), int(l), int(t)):
					_tut_move = {"axis": int(a), "layer": int(l), "turns": int(t)}
					return _tut_move.duplicate()
	return {}


var _tut_move_key := ""
var _board_explicit := false     # dieser Versuch läuft auf einem ausdrücklich gewählten Brett (nicht dem nächsten)
var _tut_move := {}


## Lässt diese Drehung sofort etwas für das Ziel des Tages wachsen?
func _twist_grows(axis: int, layer: int, turns: int) -> bool:
	var sim: GameState = state.simulate({"type": "twist", "axis": axis, "layer": layer, "turns": turns})["state"]
	return sim.goal_progress() > state.goal_progress()


## Ist Tag n spielbar? Tag 1 immer; ein geschaffter Tag immer (Wiederholung); der nächste neue Tag erst an einem
## späteren Spieltag als der letzte erste Sieg (ein neuer Tag je echtem Tag).
func day_unlocked(n: int) -> bool:
	_ensure_campaign()
	if debug_open_all and OS.is_debug_build():
		return n >= 1 and n <= Days.count()
	return Daily.day_unlocked(daily, day_stars, n, today_key())


## Beste Sterne von Tag n (0 = noch nicht geschafft).
func stars_of(n: int) -> int:
	_ensure_campaign()
	return int(day_stars[n - 1]) if n >= 1 and n <= day_stars.size() else 0


func stars_total() -> int:
	_ensure_campaign()
	if Balance.CAMPAIGN_ON:
		_ensure_camp()
		return _camp_stars_total()
	var t := 0
	for v in day_stars:
		t += int(v)
	return t


func stars_max() -> int:
	return 3 * (Campaign.COUNT if Balance.CAMPAIGN_ON else Days.count())


## Der Tag, mit dem es weitergeht: der erste freie, noch nicht geschaffte Tag (sonst der letzte freie).
## Ist der neue Tag erst morgen dran, kommt der zuletzt geschaffte.
func current_day() -> int:
	_ensure_campaign()
	var nn := Daily.next_new_day(day_stars)
	if nn > Days.count():
		return Days.count()
	if day_unlocked(nn):
		return nn
	return maxi(1, nn - 1)


## Gnade für den nächsten Versuch von Tag n (zusätzliche Drehungen).
func day_mercy(n: int) -> int:
	_ensure_campaign()
	if n < 1 or n > day_fails.size():
		return 0
	return mini(Balance.MERCY_MAX, int(day_fails[n - 1]) * Balance.MERCY_TWISTS)


## Freies Spiel offen? Nach Tag 7 – oder für Spieler, die das alte Tutorial schon kannten.
func free_play_unlocked() -> bool:
	if Balance.CAMPAIGN_ON:
		_ensure_camp()
		return world_done or bool(camp["veteran"]) or level_stars(Campaign.COUNT) > 0 or (debug_open_all and OS.is_debug_build())
	return world_done or tutorial_done


## Warum das freie Spiel noch zu ist (kurz, ohne zu verraten, was kommt).
func free_locked_text() -> String:
	return "Nach der Schöpfung." if Balance.CAMPAIGN_ON else "Erst die 7 Tage schaffen."


## Tipp gratis? (An den Tagen ja – Produktentscheidung, Balance.DAY_HINT_FREE.)
func hint_free() -> bool:
	if level_no > 0 and state != null and state.camp:
		return level_no <= Balance.HINT_FREE_LEVELS or state.rescue() or hint_free_left > 0
	return in_day() and Balance.DAY_HINT_FREE


## Alles für die Ziel-Karte und den Chip: {"day", "title", "intro", "goal_text", "goal_icon", "goal_type",
## "target", "rule_line", "limit" (mit Gnade), "base_limit", "mercy", "stars" ([★★★ bis, ★★ bis]), "new"
## ({"key", "icon", "title", "text"}), "coach" (Sätze), "best_stars", "best_twists", "board", "tutorial" (Drehung
## oder {}), "first_visit", "status" (GameState.day_status())}.
func day_info() -> Dictionary:
	if not in_day():
		return {}
	if level_no > 0:
		return level_info()
	var cfg := state.day
	var n := day_no
	var wdt := wdt_key >= 0
	return {"day": n, "title": str(cfg.get("title", "")), "intro": str(cfg.get("intro", "")),
		"wdt": wdt, "wdt_key": wdt_key, "caps": str(cfg.get("caps", str(Days.TEXT["day"]) % n)),
		"goal_text": Days.goal_line(cfg), "goal_icon": str(cfg.get("goal_icon", "")), "goal_type": state.goal_type(),
		"target": state.goal_target(), "rule_line": str(cfg.get("rule_line", "")), "rule_icon": str(cfg.get("rule_icon", "swords")),
		"limit": state.day_limit, "base_limit": int(cfg.get("limit", 0)), "mercy": state.day_limit - int(cfg.get("limit", 0)),
		"stars": (cfg.get("stars", [0, 0]) as Array).duplicate(), "new": (cfg.get("new", {}) as Dictionary).duplicate(),
		"coach": (cfg.get("coach", []) as Array).duplicate(), "coach_demo": str(cfg.get("coach_demo", "")),
		"best_stars": Daily.wdt_stars(daily, wdt_key) if wdt else stars_of(n),
		"best_twists": 0 if wdt else int(day_best[n - 1]), "board": int(day_board.get("index", 0)),
		"tutorial": (cfg.get("tutorial", {}) as Dictionary).duplicate() if int(day_board.get("index", -1)) == 0 and n == 1 and not wdt else {},
		"first_visit": false if wdt else (int(day_stars[n - 1]) == 0 and int(day_fails[n - 1]) == 0),
		"status": state.day_status(), "overnight": overnight.duplicate(true), "v8": state.v8}


## Ende eines Versuchs: Sterne, Freischalten, Gnade, nächstes Brett, speichern, Signal.
func _finish_day() -> void:
	if level_no > 0:
		_finish_level()
		return
	_ensure_campaign()
	var today := _win_key()
	if wdt_key >= 0:
		_finish_daily_world(today)
		return
	var n := day_no
	var i := n - 1
	var info := day_info()
	# Das nächste Brett: nach jedem Versuch eins weiter. Ein ausdrücklich gewähltes Brett (Tutorial nochmal) spult den
	# Zähler nie zurück – Wiederholungen sind kein Gedächtnistest.
	var stored := int(day_next_board[i])
	day_next_board[i] = maxi(stored if _board_explicit else stored + 1, int(day_board.get("index", 0)) + 1)
	if state.day_won:
		var st := state.stars()
		var used := state.day_won_at
		var first_win := int(day_stars[i]) == 0
		info["best_before"] = int(day_stars[i])
		day_stars[i] = maxi(int(day_stars[i]), st)
		day_best[i] = used if int(day_best[i]) == 0 else mini(int(day_best[i]), used)
		day_fails[i] = 0
		if first_win:
			Daily.register_first_win(daily, n, today)
		_sync_day_free()
		var complete := n >= Days.count() and not world_done
		if n >= Days.count():
			world_done = true
		var streak := _streak_win(today)
		_end_attempt()
		_save_profile()
		info["streak"] = streak
		_add_next_info(info, today)
		info["stars"] = st
		info["used"] = used
		info["best_stars"] = int(day_stars[i])
		info["first_win"] = first_win
		info["next_day"] = n + 1 if n < Days.count() else 0
		info["world_complete"] = complete
		info["stars_total"] = stars_total()
		info["stars_max"] = stars_max()
		day_won.emit(info)
		_after_win(streak)
	else:
		day_fails[i] = int(day_fails[i]) + 1
		_end_attempt()
		_save_profile()
		info["why"] = state.day_lost
		info["progress"] = state.goal_progress()
		info["target"] = state.goal_target()
		info["mercy_next"] = day_mercy(n)
		day_lost.emit(info)


## Arrays des Fortschritts auf 7 Einträge bringen (alte/fehlende Spielstände).
func _ensure_campaign() -> void:
	var n := Days.count()
	for arr in [day_stars, day_best, day_fails, day_next_board]:
		var a: Array = arr
		while a.size() < n:
			a.append(0)
		while a.size() > n:
			a.pop_back()
	_day_free_raw = clampi(_day_free_raw, 1, n + 1)


func _load_campaign(cfg: ConfigFile) -> void:
	day_stars = []
	day_best = []
	day_fails = []
	day_next_board = []
	day_free = 1
	world_done = false
	if cfg != null:
		for v in cfg.get_value("schoepfung", "sterne", []):
			day_stars.append(int(v))
		for v in cfg.get_value("schoepfung", "beste", []):
			day_best.append(int(v))
		for v in cfg.get_value("schoepfung", "fehlversuche", []):
			day_fails.append(int(v))
		for v in cfg.get_value("schoepfung", "brett", []):
			day_next_board.append(int(v))
		day_free = int(cfg.get_value("schoepfung", "frei", 1))
		world_done = bool(cfg.get_value("schoepfung", "fertig", false))
	_ensure_campaign()
	# Täglich spielen: [taeglich] laden – oder aus einem Spielstand v1 übernehmen (Daily.load_from)
	if cfg != null:
		debug_day_offset = int(cfg.get_value(Daily.SECTION, "test_tage", 0))
	daily = Daily.load_from(cfg, now_local(), Days.count())
	_last_today = -2147483648
	_load_remind(cfg)
	_sync_day_free()
	_load_camp(cfg)


## Fortschritt der 7 Tage löschen (Einstellungen/Tests). Rekorde des freien Spiels bleiben.
## Build 12: Ein gespeicherter laufender Versuch gehört zum alten Fortschritt und geht mit (sonst setzte das nächste
## start_level(1) ihn fort: keine Start-Karte, keine Begrüßung, keine Vorführung).
func reset_campaign() -> void:
	_clear_run()
	run_resumed = false
	_load_campaign(null)
	_save_profile()


# =============================================================================
# Täglich spielen (docs/GDPD_TAEGLICH_CHARAKTER.md 1, 2, 5, 7): Uhr, Spieltag, Serie, Welt des Tages,
# Erinnerungs-Plan, Test-Knopf. Die Regeln selbst stehen in Daily und ReminderPlan (rein, getestet).
# =============================================================================

## Ortszeit als „lokale Unix-Sekunden“ (Datum/Uhrzeit der Ortszeit, als wäre es UTC). Tests und Tour stellen die Uhr
## mit clock_override; der Test-Knopf „Nächster Tag“ zählt ganze Tage dazu (nur in Test-Versionen).
func now_local() -> int:
	var t := clock_override
	if t < 0:
		t = Daily.system_local()
	if OS.is_debug_build():
		t += debug_day_offset * Daily.DAY
	return t


## Der heutige Spieltag (Uhr-Regeln: nie rückwärts, großes Zurückstellen setzt neu auf). Beim Wechsel des Spieltags:
## Tagesprüfung (Serienschutz) und daily_changed.
func today_key() -> int:
	_ensure_daily()
	var k := Daily.observe(daily, now_local())
	if k != _last_today:
		var first := _last_today == -2147483648
		_last_today = k
		_check_due = true
		_sync_day_free()
		if not first:
			call_deferred("emit_signal", "daily_changed")
	if _check_due and not _win_grace(k):
		_check_due = false
		Daily.day_check(daily, k)
	return k


## Spielzeit (lokale Unix-Sekunden): Ortszeit + Versatz nach großem Zurückstellen der Uhr (Daily.observe). Für
## Countdown und Erinnerungs-Plan; die Uhrzeit ist dieselbe wie now_local (der Versatz sind ganze Tage).
func game_now() -> int:
	today_key()
	return Daily.game_time(daily, now_local())


## Läuft ein Versuch, der kurz vor dem Tageswechsel (3 Uhr) begann? Dann zählt sein Sieg noch für den alten Spieltag
## (Balance.WIN_GRACE), und die Tagesprüfung wartet bis zum Ende des Versuchs.
func _win_grace(k: int) -> bool:
	if attempt_key < 0 or attempt_key != k - 1 or attempt_start < 0 or not in_day():
		return false
	var boundary := Daily.next_boundary(attempt_start)
	# nur für einen Versuch, der kurz vor 3 Uhr begann – und höchstens 3 × so lange danach (ein liegen gelassener
	# Versuch hält die Tagesprüfung nicht ewig auf)
	return boundary - attempt_start <= Balance.WIN_GRACE \
		and Daily.game_time(daily, now_local()) - boundary <= 3 * Balance.WIN_GRACE


## Spieltag, dem ein Sieg gutgeschrieben wird: der heutige – oder der Spieltag, an dem der Versuch kurz vor 3 Uhr begann.
func _win_key() -> int:
	var k := today_key()
	return attempt_key if _win_grace(k) else k


## Der Versuch ist zu Ende: die aufgeschobene Tagesprüfung jetzt machen.
func _end_attempt() -> void:
	attempt_key = -1
	attempt_start = -1
	today_key()


## Eine Sitzung beginnt (Start, Rückkehr in die App): Uhrzeit merken, die Erinnerungs-Leiter fängt neu an.
func note_session() -> void:
	session_start = now_local()
	var k := today_key()
	daily["open_key"] = k


func _ensure_daily() -> void:
	if daily.is_empty():
		daily = Daily.fresh(now_local(), Days.count())


## Alter Wert day_free (höchster spielbarer Tag) passend zur Freischaltung nach Datum (der Rohwert für den Spielstand).
func _sync_day_free() -> void:
	if daily.is_empty() or day_stars.size() != Days.count():
		return
	_day_free_raw = Daily.day_free(daily, day_stars, Daily.observe(daily, now_local()))


## Der nächste neue Tag (1 … 7; 8 = alle geschafft).
func next_new_day() -> int:
	_ensure_campaign()
	return Daily.next_new_day(day_stars)


## Ist heute ein neuer Tag offen?
func new_day_open() -> bool:
	_ensure_campaign()
	return Daily.new_day_open(daily, day_stars, today_key())


## Ist der nächste neue Tag erst morgen dran (heute schon ein erster Sieg)?
func new_day_tomorrow() -> bool:
	_ensure_campaign()
	return Daily.new_day_tomorrow(daily, day_stars, today_key()) and not (debug_open_all and OS.is_debug_build())


## Text für einen gesperrten Tag: „Morgen geht's weiter: Tag 3 · Tiere“ (der nächste neue, morgen), ein späterer
## Tag „Ab Mittwoch.“ (ein neuer Tag je Spieltag), sonst „Erst Tag 3 schaffen.“
func locked_text(n: int) -> String:
	var nn := next_new_day()
	if n >= nn and new_day_tomorrow():
		if n == nn:
			return str(Days.TEXT["tomorrow_next"]) % [n, str(Days.config(n).get("title", ""))]
		return str(Days.TEXT["locked_on"]) % Daily.weekday_name(today_key() + n - nn + 1)   # „Ab Mittwoch.“
	return str(Days.TEXT["locked"]) % mini(nn, Days.count())


## Ist der Serientag heute geschafft?
func done_today() -> bool:
	return Daily.done_today(daily, today_key())


func streak() -> int:
	today_key()
	return int(daily["streak"])


func shields() -> int:
	today_key()
	return int(daily["shields"])


## Alles für die Übersicht (Heute-Karte, Kopfzeile, Wochenreihe):
## {"today" (Spieltag), "weekday" („Freitag“), "state", "day" (Tag der Karte, 0 = Welt des Tages), "title"
##  („Tag 3 · Tiere“ / „Welt des Tages“), "caps", "goal", "line" (Zeile unter dem Titel), "countdown", "done_today",
##  "streak", "best", "shields", "shields_visible", "week" (Daily.week),
##  "more_stars" (heute geschaffter Tag hat < 3 Sterne), "comeback" ("" | "saved" | "lost", nicht abgeholt)}
## state: "new" (neuer Tag offen) · "done_next" (heute geschafft, der nächste kommt morgen) · "wdt" (Welt des Tages
## offen) · "wdt_done" (heute geschafft) · "world_done_today" (Tag 7 heute geschafft, ab morgen Welt des Tages)
func today_info() -> Dictionary:
	_ensure_campaign()
	if Balance.CAMPAIGN_ON:
		return camp_today_info()
	var k := today_key()
	var now := game_now()
	var nn := Daily.next_new_day(day_stars)
	var out := {"today": k, "weekday": Daily.weekday_name(k), "countdown": Daily.countdown_text(now),
		"done_today": Daily.done_today(daily, k), "streak": int(daily["streak"]), "best": int(daily["streak_best"]),
		"shields": int(daily["shields"]), "shields_visible": int(daily["shields"]) > 0 or bool(daily["shields_ever"]),
		"week": Daily.week(daily, k), "comeback": str(daily["comeback"]),
		"more_stars": false}
	if nn <= Days.count():
		var title := str(Days.TEXT["day_title"]) % [nn, str(Days.config(nn).get("title", ""))]
		if day_unlocked(nn):
			out.merge({"state": "new", "day": nn, "title": title, "caps": str(Days.TEXT["today_new"]),
				"goal": Days.goal_line(Days.config(nn)), "line": Days.goal_line(Days.config(nn))})
		else:
			var last := maxi(1, nn - 1)
			out.merge({"state": "done_next", "day": nn, "title": str(Days.TEXT["today_done"]),
				"caps": str(Days.TEXT["today"]), "goal": Days.goal_line(Days.config(nn)),
				"line": str(Days.TEXT["tomorrow_next"]) % [nn, str(Days.config(nn).get("title", ""))],
				"more_stars": stars_of(last) < 3, "replay_day": last})
		return out
	if Daily.wdt_available(daily, day_stars, k):
		var cfg := Daily.wdt_config(k)
		if Daily.wdt_done(daily, k):
			out.merge({"state": "wdt_done", "day": 0, "title": str(Days.TEXT["today_done"]), "caps": str(cfg.get("caps", "")),
				"goal": Days.goal_line(cfg), "line": str(Days.TEXT["wdt_tomorrow"]), "more_stars": Daily.wdt_stars(daily, k) < 3})
		else:
			out.merge({"state": "wdt", "day": 0, "title": str(Days.TEXT["wdt"]), "caps": str(cfg.get("caps", "")),
				"goal": Days.goal_line(cfg), "line": Days.goal_line(cfg)})
		return out
	out.merge({"state": "world_done_today", "day": Days.count(), "title": str(Days.TEXT["complete"]),
		"caps": str(Days.TEXT["today"]), "goal": "", "line": str(Days.TEXT["wdt_first_tomorrow"]),
		"more_stars": stars_of(Days.count()) < 3, "replay_day": Days.count()})
	return out


## Comeback-Zeile („saved“ / „lost“) einmal abholen (danach "").
func take_comeback() -> String:
	_ensure_daily()
	var c := Daily.take_comeback(daily)
	if c != "":
		_save_profile()
	return c


## Serienschutz kaufen. "" = gekauft, sonst der Grund („Du hast genug Serienschutz.“ / „Dir fehlen 2 Münzen.“).
func buy_shield() -> String:
	today_key()
	var err := Daily.shield_buy_error(daily, points)
	if err != "":
		return err
	points -= Balance.SHIELD_PRICE
	points_changed.emit(-Balance.SHIELD_PRICE, "kauf")
	Daily.add_shield(daily)
	_save_profile()
	daily_changed.emit()
	return ""


## Der Sieg zählt für die Serie (nur der erste eines Spieltags). Meilenstein mit vollem Schutz: Münzen.
func _streak_win(today: int) -> Dictionary:
	var start := session_start if session_start >= 0 else now_local()
	var s := Daily.win(daily, today, Daily.minute_of_day(start))
	if int(s["coins"]) > 0:
		_add_points(int(s["coins"]), "streak")
	if bool(s.get("counted", false)):
		var bonus := Points.streak_bonus(int(s["streak"]))
		var ms := Points.milestone(int(s["streak"]))
		s["bonus"] = bonus
		s["milestone_points"] = int(ms["points"])
		s["gift"] = str(ms["gift"])
		_add_points(bonus + int(ms["points"]), "streak")
		if str(ms["gift"]) != "" and not owned.has(str(ms["gift"])):
			owned.append(str(ms["gift"]))
	return s


## Für die Sieg-Karte: Was kommt als Nächstes? "next_new" (nächster neuer Tag, 0 = keiner), "next_open" (heute
## schon offen: „Weiter zu Tag 3“), "next_locked" (erst morgen), "next_line" („Morgen geht's weiter: Tag 2 · Pflanzen“).
func _add_next_info(info: Dictionary, today: int) -> void:
	var nn := Daily.next_new_day(day_stars)
	var has_next := nn <= Days.count()
	var open := has_next and day_unlocked(nn)
	info["next_new"] = nn if has_next else 0
	info["next_open"] = open
	info["next_locked"] = has_next and not open
	if has_next and not open:
		info["next_line"] = str(Days.TEXT["tomorrow_next"]) % [nn, str(Days.config(nn).get("title", ""))]
	elif not has_next:
		info["next_line"] = str(Days.TEXT["wdt_tomorrow"]) if Daily.wdt_available(daily, day_stars, today) else str(Days.TEXT["wdt_first_tomorrow"])
	else:
		info["next_line"] = ""


func _after_win(streak_info: Dictionary) -> void:
	if bool(streak_info.get("counted", false)):
		streak_changed.emit(streak_info)
	daily_changed.emit()
	replan_reminders()


func _finish_daily_world(today: int) -> void:
	var key := wdt_key
	var info := day_info()
	if state.day_won:
		var st := state.stars()
		var first := Daily.wdt_win(daily, key, st)
		var streak := _streak_win(today)
		_end_attempt()
		_save_profile()
		info["stars"] = st
		info["used"] = state.day_won_at
		info["best_before"] = 0 if first else Daily.wdt_stars(daily, key)
		info["best_stars"] = Daily.wdt_stars(daily, key)
		info["first_win"] = first
		info["next_day"] = 0
		info["world_complete"] = false
		info["stars_total"] = stars_total()
		info["stars_max"] = stars_max()
		info["streak"] = streak
		info["next_new"] = 0
		info["next_open"] = false
		info["next_locked"] = true
		info["next_line"] = str(Days.TEXT["wdt_tomorrow"])
		day_won.emit(info)
		_after_win(streak)
	else:
		Daily.wdt_fail(daily, key)
		_end_attempt()
		_save_profile()
		info["why"] = state.day_lost
		info["progress"] = state.goal_progress()
		info["target"] = state.goal_target()
		info["mercy_next"] = Daily.wdt_mercy(daily, key)
		day_lost.emit(info)


## Der Tipp an einem Tag auf einer Kopie des Stands, auf mehrere Bilder verteilt (je Bild höchstens hint_budget_usec
## Rechenzeit plus eine Simulation), damit das Spiel flüssig bleibt. Immer auf dem Haupt-Thread: Godot 4.3 liest const-Tabellen nicht
## threadsicher (ein zweiter Thread führte zu Abstürzen und Hängern). Ändert sich der Stand inzwischen (Drehung,
## Werkzeug, neues Spiel), bricht die Suche ab: {}. twist_only: nur Drehungen (wie best_move).
## Ohne neue Regeln (oder außerhalb eines Tages) am Stück wie bisher.
const HINT_BUDGET_USEC := 6000
var hint_budget_usec := HINT_BUDGET_USEC      # die Tour (Software-Grafik, 2 Bilder je Sekunde) erlaubt mehr je Bild


func search_hint(twist_only: bool = false) -> Dictionary:
	var st0 := state
	var tw0 := state.twists
	var key0 := _hint_key()
	var search := state.clone().day_search(twist_only)
	if search == null:
		if twist_only:
			return state.best_move()
		return state.best_action()
	hint_searches += 1
	while not search.step(hint_budget_usec):
		await get_tree().process_frame
		if state != st0 or state.twists != tw0 or _hint_key() != key0:
			hint_searches -= 1
			return {}
	hint_searches -= 1
	return search.result


func _hint_key() -> String:
	return "%d|%d|%d" % [state.rain, state.faith, state.turn]


# --- Erinnerungen (5): Plan rechnen, Geschichte führen, an das Plugin geben --------------------------

const REMIND_DEFAULTS = {"mode": "auto", "fixed_min": 1080, "asked": 0, "history": [], "planned": []}


func _load_remind(cfg: ConfigFile) -> void:
	remind = REMIND_DEFAULTS.duplicate(true)
	if cfg == null or not cfg.has_section("erinnerung"):
		return
	var m := str(cfg.get_value("erinnerung", "modus", "auto"))
	remind["mode"] = m if ReminderPlan.MODES.has(m) else "auto"
	remind["fixed_min"] = clampi(int(cfg.get_value("erinnerung", "uhrzeit", Balance.REMIND_DEFAULT_MIN)), Balance.REMIND_EARLIEST, Balance.REMIND_LATEST)
	remind["asked"] = int(cfg.get_value("erinnerung", "gefragt", 0))
	var h: Array = []
	for v in cfg.get_value("erinnerung", "verlauf", []):
		h.append(str(v))
	remind["history"] = h
	var pl: Array = []
	for v in cfg.get_value("erinnerung", "geplant", []):
		if v is Dictionary:
			pl.append({"id": int(v.get("id", 0)), "at": int(v.get("at", 0)), "tpl": str(v.get("tpl", "")), "key": int(v.get("key", 0))})
	remind["planned"] = pl


func _save_remind(cfg: ConfigFile) -> void:
	if remind.is_empty():
		remind = REMIND_DEFAULTS.duplicate(true)
	cfg.set_value("erinnerung", "modus", str(remind["mode"]))
	cfg.set_value("erinnerung", "uhrzeit", int(remind["fixed_min"]))
	cfg.set_value("erinnerung", "gefragt", int(remind["asked"]))
	cfg.set_value("erinnerung", "verlauf", remind["history"])
	cfg.set_value("erinnerung", "geplant", remind["planned"])


## Dürfen Erinnerungen geplant werden? Ohne Plugin (PC, CI) immer (dann nur Protokoll-Zeilen).
func reminders_allowed() -> bool:
	if not Engine.has_singleton("GdpdReminder"):
		return true
	return remind_permission


## Name und Ton des eigenen Charakters ([charakter] in user://charakter.cfg; Game.character, wenn es das gibt).
func _character_value(key: String, fallback: String) -> String:
	var c: Variant = get("character")
	if c is Dictionary and (c as Dictionary).has(key):
		return str((c as Dictionary)[key])
	var cf := ConfigFile.new()
	if cf.load("user://charakter.cfg") == OK and cf.has_section_key("charakter", key):
		return str(cf.get_value("charakter", key, fallback))
	return fallback


## Gibt es noch keinen eigenen Charakter? Dann kommt der Ersteller vor allem anderen (erster Start, alte Spielstände).
func needs_creator() -> bool:
	return character.is_empty()


## Den Charakter übernehmen und speichern (Ersteller „Fertig“, Menü „Dein Charakter“, Ton im Menü). Plant die
## Erinnerungen neu (Name und Ton stehen in den Texten).
func set_character(look: Dictionary) -> void:
	character = Character.sanitize(look) if not look.is_empty() else {}
	if character.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Character.SAVE_PATH))
		return
	Character.save_look(character)
	replan_reminders()


## Soll der Charakter jetzt fragen, ob er erinnern darf (5.7)? Nach dem ersten Sieg (gefragt 0) und noch einmal ab
## einer Serie von 3 Tagen (gefragt 1). Nie, wenn Erinnerungen aus sind oder die Erlaubnis schon da ist.
func reminder_ask_due(streak_now: int) -> bool:
	if remind.is_empty():
		remind = REMIND_DEFAULTS.duplicate(true)
	if str(remind["mode"]) == "aus" or remind_permission:
		return false
	var asked := int(remind["asked"])
	return asked == 0 or (asked == 1 and streak_now >= 3)


## Die Frage wurde gezeigt (Antwort egal: „Ja, gern“ fragt danach Android).
func note_reminder_asked() -> void:
	if remind.is_empty():
		remind = REMIND_DEFAULTS.duplicate(true)
	remind["asked"] = mini(2, int(remind["asked"]) + 1)
	_save_profile()


## {tag} der Erinnerung: der Tag, der als Nächstes wartet („Tag 3: Tiere“), nach Tag 7 „die Welt des Tages“.
func reminder_tag() -> String:
	var nn := next_new_day()
	if nn <= Days.count():
		return str(Days.TEXT["day_tag"]) % [nn, str(Days.config(nn).get("title", ""))]
	return str(Days.TEXT["wdt_tag"])


## Eingabe für ReminderPlan.plan aus dem Spielstand.
func reminder_input() -> Dictionary:
	if remind.is_empty():
		remind = REMIND_DEFAULTS.duplicate(true)
	var k := today_key()
	return {"today": k, "done_today": Daily.done_today(daily, k), "last_win_key": int(daily["streak_last"]),
		"last_open_key": int(daily["open_key"]), "anchor_min": int(daily["anchor"]), "mode": str(remind["mode"]),
		"fixed_min": int(remind["fixed_min"]), "allowed": reminders_allowed(), "tone": _character_value("ton", "lieb"),
		"name": _character_value("name", ReminderPlan.DEFAULT_NAME), "tag": reminder_tag(), "streak": int(daily["streak"]),
		"history": (remind["history"] as Array).duplicate()}


## Neu planen (Start, Rückkehr, Pause, nach jedem Serientag, nach einer Einstellung): Was schon gezeigt wurde, kommt in
## die Geschichte; der neue Plan ersetzt den alten (das Plugin löscht vorher alle). Gibt den Plan zurück.
## Jeder Eintrag hat zusätzlich "at_real" und die Kalender-Felder der echten Uhr (ohne die Test-Tage).
func replan_reminders() -> Array:
	if remind.is_empty():
		remind = REMIND_DEFAULTS.duplicate(true)
	var now := game_now()
	remind["history"] = ReminderPlan.absorb_shown(remind["history"], remind["planned"], now)
	var plan := ReminderPlan.plan(reminder_input(), now)
	var real := clock_override if clock_override >= 0 else Daily.system_local()
	var shift := now - real         # Test-Tage und Uhr-Versatz: das Plugin bekommt die echte Uhrzeit
	var stored: Array = []
	for e in plan:
		var d: Dictionary = e
		d["at_real"] = int(d["at"]) - shift
		if shift != 0:
			var f := Daily.fields_of(int(d["at_real"]))
			for fk in ["year", "month", "day", "hour", "minute"]:
				d[fk] = int(f[fk])
		stored.append({"id": int(d["id"]), "at": int(d["at"]), "tpl": str(d["tpl"]), "key": int(d["key"])})
	remind["planned"] = stored
	reminder_log = plan
	_save_profile()
	reminders_planned.emit(plan)
	if reminder_echo and reminders_planned.get_connections().is_empty():
		print("REMINDER cancel_all")
		for e in plan:
			print(ReminderPlan.log_line(e))
	return plan


## Einstellung „Erinnerung“: "auto" | "fest" | "aus"; fixed_min (Minute des Tages, 8:00–21:30) für „Feste Uhrzeit“.
func set_reminder_mode(mode: String, fixed_min: int = -1) -> void:
	if remind.is_empty():
		remind = REMIND_DEFAULTS.duplicate(true)
	remind["mode"] = mode if ReminderPlan.MODES.has(mode) else "auto"
	if fixed_min >= 0:
		remind["fixed_min"] = clampi(fixed_min, Balance.REMIND_EARLIEST, Balance.REMIND_LATEST)
	replan_reminders()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		note_session()
		daily_changed.emit()
		replan_reminders()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_save_running()
		replan_reminders()          # wichtig: vielleicht kommt der Spieler nie zurück
	elif what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_save_running()


# --- Test-Knopf und Test-Haken (7) -----------------------------------------------------------------

## „Nächster Tag (Test)“: einen ganzen Tag weiter (nur in Test-Versionen). Gibt den Toast-Text zurück
## („Test: Jetzt ist Freitag.“), "" in einer Store-Version.
func debug_next_day() -> String:
	if not OS.is_debug_build():
		return ""
	debug_day_offset += 1
	var k := today_key()
	note_session()
	_save_profile()
	replan_reminders()
	daily_changed.emit()
	return str(Days.TEXT["test_now"]) % Daily.weekday_name(k)


## Test: „Erinnerung in 10 s“ – ein Eintrag (id 199) mit dem nächsten A-Text, 10 s nach der echten Uhr. Sein Spieltag
## ist DEBUG_REMINDER_KEY: Das Plugin zeigt ihn immer (auch wenn heute geschafft ist, auch in der Ruhezeit).
const DEBUG_REMINDER_KEY := 2147483647


func debug_reminder_soon() -> Dictionary:
	var inp := reminder_input()
	var at := Daily.system_local() + 10
	var tpl := ReminderPlan.pick(str(inp["tone"]), "A", int(inp["streak"]), inp["history"], int(inp["today"]))
	var e := ReminderPlan.entry(199, at, DEBUG_REMINDER_KEY, "A", tpl, str(inp["name"]), str(inp["tag"]), int(inp["streak"]))
	e["at_real"] = at
	return e


## Test: „Serie zurücksetzen“ – Serie 0, kein Schutz, keine Text-Geschichte.
func debug_reset_streak() -> void:
	_ensure_daily()
	daily["streak"] = 0
	daily["shields"] = 0
	daily["streak_days"] = []
	daily["shield_days"] = []
	daily["comeback"] = ""
	if not remind.is_empty():
		remind["history"] = []
	_save_profile()
	daily_changed.emit()


## Test/Einstellungen: [taeglich] und [erinnerung] frisch (der Fortschritt der 7 Tage bleibt; die Test-Tage auch).
func reset_daily() -> void:
	daily = Daily.fresh(now_local(), Days.count())
	_last_today = -2147483648
	remind = REMIND_DEFAULTS.duplicate(true)
	_sync_day_free()
	_save_profile()
	daily_changed.emit()


# =============================================================================
# Die Schöpfung (docs/GDPD_SCHOEPFUNG.md v2): 30 Level, ein neues je Spieltag, die Welt läuft im Akt weiter,
# Punkte statt Münzen (GDPD_PUNKTE_LADEN.md). Die Regeln stehen in GameState (setup_level), die Daten in Campaign,
# das Freischalten in Daily (level_unlocked). Balance.CAMPAIGN_ON schaltet den Start auf die Kampagne um (die
# Oberfläche der 7 Tage läuft bis dahin weiter).
# =============================================================================

const CAMP_SECTION := "kampagne"
var level_no := 0                # laufendes Level (1 … 30), 0 = keins
var level_board: Dictionary = {} # das Start-Brett dieses Versuchs ({"kinds", "seed", "index", "how", "board"})
var hint_free_left := 0          # Gratis-Tipps in diesem Level (1 je Level)
var undo_free_left := 0          # Gratis-Zurück in diesem Level (1 je Level)
var owned: Array = []            # [laden] besitz: gekaufte und geschenkte Dinge
var stock: Dictionary = {}       # [laden] vorrat: gekaufte Verbrauchsgüter (regen, blitzschutz, meteor, tipp, zurueck)
var seen_shop: Array = []        # [laden] gesehen: Dinge ohne „Neu“-Punkt
## Kampagnen-Zustand (gespeichert in [kampagne]): "stars", "steps", "won_key" (je 30), "last_new_key", "world"
## (Brett-Text nach Plätzen), "world_level", "start" (Start-Brett des laufenden, noch nicht geschafften Levels),
## "start_level", "start_seed", "fast_to" (Schnellstart bis), "fast_day", "veteran", "next_board" (je 30),
## "thanks" (Punkte aus alten Sternen, Hinweis noch nicht gezeigt).
var camp: Dictionary = {}


static func fresh_camp() -> Dictionary:
	var st: Array = []
	var sp: Array = []
	var wk: Array = []
	var nb: Array = []
	for i in Campaign.COUNT:
		st.append(0)
		sp.append(0)
		wk.append(-1)
		nb.append(0)
	return {"stars": st, "steps": sp, "won_key": wk, "last_new_key": -1, "world": "", "world_level": 0,
		"start": "", "start_level": 0, "start_seed": 1, "fast_to": 0, "fast_day": [-1, 0], "veteran": false,
		"next_board": nb, "thanks": 0}


## Punkte laden; einmal (konto.version < 2) die Münzen umstellen: max(20 × Münzen, 60) + 20 je alter Stern (8.2).
func _load_points(cfg: ConfigFile) -> void:
	pdata = Points.load_from(cfg, Campaign.COUNT)
	if int(cfg.get_value("konto", "version", 1)) >= 2:
		points = maxi(0, int(cfg.get_value("konto", "punkte", Balance.POINTS_START)))
		points_migrated = int(cfg.get_value("konto", "umgestellt", 0))
		_load_owned(cfg)
		return
	var coins := int(cfg.get_value("konto", "credits", 0))
	var old_stars := 0
	for v in cfg.get_value("schoepfung", "sterne", []):
		old_stars += maxi(0, int(v))
	points = Points.migrate_coins(coins, old_stars)
	points_migrated = points
	var bm: Variant = cfg.get_value(Daily.SECTION, "bau_muenzen", [-1, 0])
	if bm is Array and (bm as Array).size() >= 2:
		pdata["heute"] = [int((bm as Array)[0]), mini(Balance.BUILD_POINTS_MAX, 10 * int((bm as Array)[1])), 0, 0]
	_load_owned(cfg)


func _load_owned(cfg: ConfigFile) -> void:
	owned = []
	for v in cfg.get_value("laden", "besitz", []):
		owned.append(str(v))
	Character.owned_parts = owned
	stock = {}
	var vr: Variant = cfg.get_value("laden", "vorrat", {})
	if vr is Dictionary:
		for k in (vr as Dictionary):
			stock[str(k)] = int((vr as Dictionary)[k])
	seen_shop = []
	for v in cfg.get_value("laden", "gesehen", []):
		seen_shop.append(str(v))


## Punkte gutschreiben (nie negativ) und melden.
func _add_points(n: int, source: String) -> void:
	if n <= 0:
		return
	points += n
	points_changed.emit(n, source)


## Den Hinweis „Deine Münzen sind jetzt Punkte.“ einmal abholen (0 = nichts zu zeigen).
func take_points_migrated() -> int:
	var n := points_migrated
	if n > 0:
		points_migrated = 0
		_save_profile()
	return n


## [kampagne] laden. Ohne den Abschnitt: neu – oder Veteran der 7 Tage (13.1): Level 1 offen und Schnellstart bis
## zum Level, das dem höchsten geschafften alten Tag entspricht (3 neue Level je Spieltag); wer alle 7 Tage
## geschafft hat, behält die Welt des Tages jeden Tag.
func _load_camp(cfg: ConfigFile) -> void:
	camp = fresh_camp()
	if cfg != null and cfg.has_section(CAMP_SECTION):
		var s := CAMP_SECTION
		for key in ["stars", "steps", "won_key", "next_board"]:
			var src: Array = cfg.get_value(s, {"stars": "sterne", "steps": "schritte", "won_key": "gewonnen_am",
				"next_board": "brett"}[key], [])
			var a: Array = camp[key]
			for i in mini(a.size(), src.size()):
				a[i] = int(src[i])
		camp["last_new_key"] = int(cfg.get_value(s, "letzter_neuer", -1))
		camp["world"] = str(cfg.get_value(s, "welt", ""))
		camp["world_level"] = int(cfg.get_value(s, "welt_level", 0))
		camp["start"] = str(cfg.get_value(s, "start", ""))
		camp["start_level"] = int(cfg.get_value(s, "start_level", 0))
		camp["start_seed"] = int(cfg.get_value(s, "start_seed", 1))
		camp["fast_to"] = int(cfg.get_value(s, "schnell_bis", 0))
		var fd: Variant = cfg.get_value(s, "schnell_tag", [-1, 0])
		camp["fast_day"] = [int((fd as Array)[0]), int((fd as Array)[1])] if fd is Array and (fd as Array).size() >= 2 else [-1, 0]
		camp["veteran"] = bool(cfg.get_value(s, "veteran", false))
		camp["thanks"] = int(cfg.get_value(s, "danke", 0))
		return
	# Umstellung v2 → v3 (13.1): alte Tage → Schnellstart
	var top := 0
	for i in day_stars.size():
		if int(day_stars[i]) > 0:
			top = i + 1
	if world_done:
		top = maxi(top, 7)
	if top > 0:
		camp["fast_to"] = int(Campaign.FAST_TRACK[clampi(top, 0, 7)])
		camp["veteran"] = world_done
		var old := 0
		for v in day_stars:
			old += maxi(0, int(v))
		camp["thanks"] = Balance.POINTS_PER_OLD_STAR * old


func _save_camp(cfg: ConfigFile) -> void:
	if camp.is_empty():
		camp = fresh_camp()
	var s := CAMP_SECTION
	cfg.set_value(s, "version", 1)
	cfg.set_value(s, "level", level_free())
	cfg.set_value(s, "sterne", camp["stars"])
	cfg.set_value(s, "schritte", camp["steps"])
	cfg.set_value(s, "gewonnen_am", camp["won_key"])
	cfg.set_value(s, "letzter_neuer", int(camp["last_new_key"]))
	cfg.set_value(s, "welt", str(camp["world"]))
	cfg.set_value(s, "welt_level", int(camp["world_level"]))
	cfg.set_value(s, "start", str(camp["start"]))
	cfg.set_value(s, "start_level", int(camp["start_level"]))
	cfg.set_value(s, "start_seed", int(camp["start_seed"]))
	cfg.set_value(s, "schnell_bis", int(camp["fast_to"]))
	cfg.set_value(s, "schnell_tag", camp["fast_day"])
	cfg.set_value(s, "veteran", bool(camp["veteran"]))
	cfg.set_value(s, "brett", camp["next_board"])
	cfg.set_value(s, "danke", int(camp["thanks"]))
	cfg.set_value("laden", "besitz", owned)
	cfg.set_value("laden", "vorrat", stock)
	cfg.set_value("laden", "gesehen", seen_shop)


func _ensure_camp() -> void:
	if camp.is_empty():
		camp = fresh_camp()


## „Danke fürs Mitspielen: +140 Punkte“ einmal abholen (0 = nichts zu zeigen). Die Punkte sind schon gutgeschrieben.
func take_thanks() -> int:
	_ensure_camp()
	var n := int(camp["thanks"])
	if n > 0:
		camp["thanks"] = 0
		_save_profile()
	return n


## Höchstes freies Level.
func level_free() -> int:
	_ensure_camp()
	return Daily.level_free(camp, Daily.observe(daily, now_local()) if not daily.is_empty() else 0)


func level_unlocked(n: int) -> bool:
	_ensure_camp()
	if debug_open_all and OS.is_debug_build():
		return n >= 1 and n <= Campaign.COUNT
	return Daily.level_unlocked(camp, n, today_key())


func level_stars(n: int) -> int:
	_ensure_camp()
	return int((camp["stars"] as Array)[n - 1]) if n >= 1 and n <= Campaign.COUNT else 0


func next_new_level() -> int:
	_ensure_camp()
	return Daily.next_new_level(camp)


func new_level_open() -> bool:
	_ensure_camp()
	return Daily.new_level_open(camp, today_key())


func new_level_tomorrow() -> bool:
	_ensure_camp()
	return Daily.new_level_tomorrow(camp, today_key()) and not (debug_open_all and OS.is_debug_build())


## Das Level, mit dem es weitergeht: das neue (wenn heute offen), sonst das zuletzt geschaffte.
func current_level() -> int:
	_ensure_camp()
	var nn := Daily.next_new_level(camp)
	if nn > Campaign.COUNT:
		return Campaign.COUNT
	if level_unlocked(nn):
		return nn
	return maxi(1, nn - 1)


## Für die Übersicht: je Akt die Kachel (Name nur, wenn erreicht) und je Level {"level", "open", "stars", "title",
## "icon", "current"} – gesperrte Level zeigen nur „?“ (nie spoilern).
func campaign_overview() -> Dictionary:
	_ensure_camp()
	var acts: Array = []
	var cur := current_level()
	for a in range(1, 8):
		var lv: Array = []
		var reached := false
		for n in Campaign.act_levels(a):
			var open := level_unlocked(n)
			reached = reached or open
			var t := Campaign.tile(n, open)
			t["stars"] = level_stars(n)
			t["current"] = n == cur
			lv.append(t)
		var at := Campaign.act_tile(a, reached)
		at["levels"] = lv
		acts.append(at)
	var k := today_key()
	return {"acts": acts, "current": cur, "next_new": next_new_level(), "new_open": new_level_open(),
		"fast_left": Daily.new_levels_left(camp, k) if Daily.fast_track_on(camp) else 0,
		"fast_line": str(Campaign.TEXT["fast_track"]) % Daily.new_levels_left(camp, k) if Daily.fast_track_on(camp) and new_level_open() else "",
		"wdt": Daily.wdt_available_camp(camp, k), "points": points, "stars": _camp_stars_total()}


func _camp_stars_total() -> int:
	var t := 0
	for v in camp["stars"]:
		t += int(v)
	return t


## Level n starten (nur, wenn es frei ist). Das Start-Brett (5): ein laufendes, noch nicht geschafftes Level startet
## wieder auf seinem gespeicherten Brett; das neue Level eines Akts auf der Welt von gestern (Campaign.carry), der
## erste Level eines Akts und Wiederholungen auf einem Pool-Brett (Level 1 beim ersten Mal: Brett 0, das Tutorial).
## board_index ≥ 0: genau dieses Pool-Brett.
func start_level(n: int, board_index: int = -1) -> bool:
	_ensure_camp()
	if n < 1 or n > Campaign.COUNT or not level_unlocked(n):
		return false
	if board_index < 0:
		var run := saved_run()
		if not run.is_empty() and int(run["level"]) == n and not bool(run["wdt"]) and resume_run():
			return true           # Build 12: ein laufender Versuch geht weiter (nie wieder von 0)
	var b := _level_start_board(n, board_index)
	# Jedes Level bleibt lösbar: vor dem Start prüfen (ohne Suche), sonst Nachschub über Nacht oder das Pool-Brett
	b = Campaign.ensure(n, b, int((camp["next_board"] as Array)[n - 1]))
	_board_explicit = board_index >= 0
	overnight = {}
	var fixes: Array = b.get("fixes", [])
	var how_b := str(b.get("how", ""))
	if (how_b == "carry" and not (b.get("changed", []) as Array).is_empty()) or not fixes.is_empty() \
			or str(b.get("line", "")) != "":
		# Die Welle (5, „Neuer Morgen“): höchstens 6 Felder wachsen sichtbar herauf, die anderen sind einfach da.
		# Nachschub zuerst (der Banner erklärt ihn in wenigen Worten).
		var prev := Campaign.decode(str(camp["world"])) if how_b == "carry" else []
		var kinds: Array = b.get("kinds", [])
		var ch: Array = []
		var shown := {}
		for fx in fixes:
			var fd: Dictionary = fx
			if ch.size() >= Days.OVERNIGHT_MAX:
				break
			ch.append(fd.duplicate())
			shown[int(fd["field"])] = true
		if how_b == "carry":
			for i0 in b.get("changed", []):
				var i := int(i0)
				if ch.size() >= Days.OVERNIGHT_MAX:
					break
				if shown.has(i):
					continue
				ch.append({"field": i, "from": int(prev[i]) if i < prev.size() else 0, "kind": int(kinds[i]) if i < kinds.size() else 0})
		overnight = {"type": "overnight", "level": n, "day": n, "changes": ch,
			"caps": str(Campaign.TEXT["overnight"]), "line": str(b.get("line", ""))}
	_start_level_state(n, b)
	if not overnight.is_empty():
		overnight_growth.emit(overnight.duplicate(true))
	return true


func _level_start_board(n: int, board_index: int) -> Dictionary:
	var won := level_stars(n) > 0
	if board_index >= 0:
		var pb := Campaign.board(n, board_index)
		pb["how"] = "pool"
		return pb
	if not won and int(camp["start_level"]) == n and str(camp["start"]).length() == 54:
		var idx0 := -1
		var pb0 := Campaign.board(n, 0)
		if str(pb0.get("board", "")) == str(camp["start"]):
			idx0 = 0              # das Lehr-Brett (Level 1: Tutorial) bleibt es auch nach einem Neustart
		return {"kinds": Campaign.decode(str(camp["start"])), "seed": int(camp["start_seed"]), "index": idx0,
			"how": "stored", "board": str(camp["start"]), "solution": pb0.get("solution", []) if idx0 == 0 else []}
	if not won and not Campaign.first_of_act(n) and int(camp["world_level"]) == n - 1 \
			and str(camp["world"]).length() == 54:
		var idx := int((camp["next_board"] as Array)[n - 1])
		var c := Campaign.carry(Campaign.decode(str(camp["world"])), n, idx + 1000 * n + 1, idx)
		c["board"] = Campaign.encode(c["kinds"])
		return c
	var i := int((camp["next_board"] as Array)[n - 1])
	if n > 1 and i == 0:
		i = 1 if Campaign.pool_size(n) > 1 else 0      # Brett 0 bleibt das Lehr-Brett (Level 1: Tutorial)
	var pb2 := Campaign.board(n, i)
	pb2["how"] = "pool"
	return pb2


func _start_level_state(n: int, b: Dictionary) -> void:
	if state != null and not state.is_day():
		_save_best()
	sek100 = false
	attempt_key = today_key()
	attempt_start = game_now()
	day_no = 0
	level_no = n
	wdt_key = -1
	level_board = b
	day_board = b
	tutorial_step = -1
	_tut_board = false
	hint_free_left = Balance.HINT_FREE
	undo_free_left = Balance.UNDO_FREE
	state = Campaign.new_state(n, b)
	dead_told = false
	rescue_told_at = -99
	rescue_offer = {}
	_clear_run()                  # ein neuer Versuch (gespeichert wird ab der ersten Runde)
	run_resumed = false
	if level_stars(n) == 0:
		camp["start"] = Campaign.encode(b.get("kinds", []))
		camp["start_level"] = n
		camp["start_seed"] = int(b.get("seed", 1))
	pending_choice = {}
	busy = false
	over = false
	continued = false
	undo_state = null
	new_record = false
	onboarding = n <= 2
	_save_profile()
	new_game_started.emit()
	state_changed.emit()
	var info := level_info()
	day_started.emit(info)
	level_started.emit(info)


## „Nochmal · mehr Sterne“: dasselbe Start-Brett noch einmal.
func retry_level() -> bool:
	if level_no <= 0:
		return false
	if wdt_key >= 0:
		_clear_run()              # Nochmal: neu beginnen (start_level_wdt() würde den Lauf sonst fortsetzen)
		return start_level_wdt()
	if level_board.is_empty():
		return start_level(level_no)
	_start_level_state(level_no, level_board)
	return true


## Welt des Tages in der Schöpfung (nach Level 30; Veteranen jeden Tag).
func start_level_wdt(board_index: int = -1) -> bool:
	_ensure_camp()
	var k := today_key()
	if not Daily.wdt_available_camp(camp, k):
		return false
	if board_index < 0:
		var run := saved_run()
		if not run.is_empty() and bool(run["wdt"]) and resume_run():
			return true           # Build 12: auch die Welt des Tages geht weiter (resume_run prüft den Tag)
	var cfg := Campaign.wdt_config(k, Daily.weekday_name(k), camp["stars"])
	if cfg.is_empty():
		return false
	var b := Campaign.wdt_board(k, camp["stars"])
	if board_index >= 0:
		var t := int(cfg["level"])
		var sz := maxi(1, Campaign.pool_size(t))
		var pick := posmod(board_index, sz)
		if sz > 1 and pick == 0:
			pick = 1                  # nie Brett 0 (wie Campaign.wdt_board_index)
		b = Campaign.board(t, pick)
	sek100 = false
	attempt_key = k
	attempt_start = game_now()
	day_no = 0
	level_no = int(cfg["level"])
	wdt_key = k
	level_board = b
	day_board = b
	hint_free_left = Balance.HINT_FREE
	undo_free_left = Balance.UNDO_FREE
	state = GameState.new()
	state.setup_level(cfg, b.get("kinds", []), int(b.get("seed", 1)))
	dead_told = false
	rescue_told_at = -99
	rescue_offer = {}
	_clear_run()
	run_resumed = false
	pending_choice = {}
	busy = false
	over = false
	undo_state = null
	new_game_started.emit()
	state_changed.emit()
	var info := level_info()
	day_started.emit(info)
	level_started.emit(info)
	return true


## Alles für die Ziel-Karte und den Chip eines Levels: Titel, Geschichte, Aufgabe, Teilziele, Sterne-Grenzen, Neu-Karte,
## Coach-Satz, Ära, beste Sterne/Schritte, Brett, Tutorial, Status (GameState.level_status9).
func level_info() -> Dictionary:
	if state == null or not state.camp:
		return {}
	var cfg := state.day
	var n := level_no
	var wdt := wdt_key >= 0
	var newc: Array = cfg.get("new", [])
	return {"day": n, "level": n, "camp": true, "act": int(cfg.get("act", 0)), "act_name": str(cfg.get("act_name", "")),
		"title": str(cfg.get("title", "")), "story": str(cfg.get("story", "")), "intro": str(cfg.get("story", "")),
		"wdt": wdt, "wdt_key": wdt_key, "caps": str(cfg.get("caps", str(Campaign.TEXT["act_caps"]) % int(cfg.get("act", 1)))),
		"goal_text": Campaign.goal_line(cfg), "goal_type": state.goal_type(),
		"goal_icon": FieldData.kind_icon(maxi(0, int(state.goal_kinds()[0]) if not state.goal_kinds().is_empty() else 0)),
		"target": state.goal_target(), "subs": state.sub_status9(), "stars": state.stars9.duplicate(), "par": state.par9,
		"limit": 0, "base_limit": 0, "mercy": 0,
		"new": {"key": "level%d" % n, "icon": FieldData.kind_icon(maxi(0, int(state.goal_kinds()[0]) if not state.goal_kinds().is_empty() else 0)),
			"title": str(newc[0]) if newc.size() > 0 else "", "text": str(newc[1]) if newc.size() > 1 else ""} if not wdt else {},
		"coach": [str(cfg.get("coach", ""))] if not wdt and str(cfg.get("coach", "")) != "" else [], "coach_demo": "",
		"best_stars": Daily.wdt_stars(daily, wdt_key) if wdt else level_stars(n),
		"best_twists": 0 if wdt else int((camp["steps"] as Array)[n - 1]), "board": int(level_board.get("index", -1)),
		"how": str(level_board.get("how", "")),
		"tutorial": {"axis": 0, "layer": 1, "turns": 1} if n == 1 and not wdt and int(level_board.get("index", -1)) == 0 and not run_resumed else {},
		"first_visit": not wdt and level_stars(n) == 0 and not run_resumed, "status": state.day_status(),
		"overnight": overnight.duplicate(true), "era": state.era9(), "v8": false, "resumed": run_resumed}


## Ende eines Level-Versuchs (nur gewonnen – ein Level kann man nicht verlieren): Sterne, Schritte, Freischalten,
## Punkte (Verbesserung, Serienbonus), die Welt für morgen, speichern, day_won.
func _finish_level() -> void:
	_ensure_camp()
	var today := _win_key()
	var n := level_no
	var info := level_info()
	if not state.day_won:
		return
	var st := state.stars()
	var steps := state.day_won_at
	var pts := state.level_points()
	if wdt_key >= 0:
		var first_w := Daily.wdt_win(daily, wdt_key, st)
		var paid_w := Points.pay_wdt(pdata, wdt_key, pts)
		_add_points(paid_w, "wdt")
		var streak_w := _streak_win(today)
		_end_attempt()
		_save_profile()
		info.merge({"stars": st, "used": steps, "steps": steps, "points": pts, "paid": paid_w, "first_win": first_w,
			"best_stars": Daily.wdt_stars(daily, wdt_key), "streak": streak_w, "next_day": 0, "next_new": 0,
			"next_open": false, "next_locked": true, "next_line": str(Days.TEXT["wdt_tomorrow"]),
			"world_complete": false}, true)
		_clear_run()
		day_won.emit(info)
		_after_win(streak_w)
		return
	var i := n - 1
	var stars_a: Array = camp["stars"]
	var steps_a: Array = camp["steps"]
	var first_win := int(stars_a[i]) == 0
	info["best_before"] = int(stars_a[i])
	stars_a[i] = maxi(int(stars_a[i]), st)
	steps_a[i] = steps if int(steps_a[i]) == 0 else mini(int(steps_a[i]), steps)
	var nb: Array = camp["next_board"]
	if str(level_board.get("how", "")) == "pool":
		nb[i] = maxi(int(nb[i]), int(level_board.get("index", 0)) + 1)
	if first_win:
		Daily.register_level_win(camp, n, today)
		camp["start"] = ""
		camp["start_level"] = 0
	var before_best := int((pdata["level_best"] as Array)[i])
	var paid := Points.pay_level(pdata, n, pts, today)
	_add_points(paid, "level")
	if _world_carries():
		camp["world"] = state.slot_board9()     # die Welt für morgen: nur aus dem neuesten Level (keine Wiederholung)
		camp["world_level"] = n
	var complete := n >= Campaign.COUNT and first_win
	var streak := _streak_win(today)
	_end_attempt()
	_save_profile()
	var nn := Daily.next_new_level(camp)
	var open := nn <= Campaign.COUNT and level_unlocked(nn)
	info.merge({"stars": st, "used": steps, "steps": steps, "points": pts, "paid": paid, "best_points": before_best,
		"lines": _win_lines(st, steps, pts, paid, before_best, streak), "best_stars": int(stars_a[i]),
		"first_win": first_win, "next_day": n + 1 if n < Campaign.COUNT else 0, "next_new": nn if nn <= Campaign.COUNT else 0,
		"next_open": open, "next_locked": nn <= Campaign.COUNT and not open,
		"next_line": str(Campaign.TEXT["tomorrow"]) if nn <= Campaign.COUNT and not open else "",
		"world_complete": complete, "stars_total": _camp_stars_total(), "stars_max": 3 * Campaign.COUNT,
		"streak": streak}, true)
	_clear_run()                  # geschafft: kein laufendes Level mehr (Build 12: kein Weiterbauen)
	day_won.emit(info)
	_after_win(streak)


## Trägt diese Welt ins nächste Level (5)? Nur das höchste geschaffte Level der Kampagne – nie eine Wiederholung
## eines früheren Levels und nie die Welt des Tages (deren level_no ist nur die Vorlage).
func _world_carries() -> bool:
	if level_no <= 0 or wdt_key >= 0 or camp.is_empty():
		return false
	return level_stars(level_no) > 0 and level_no == Daily.next_new_level(camp) - 1


## Zeilen der Sieg-Karte (GDPD_PUNKTE_LADEN.md 2.4): [[Schlüssel, Punkte]].
static func _win_lines(st: int, steps: int, pts: int, paid: int, before: int, streak: Dictionary) -> Array:
	var lines: Array = []
	if before > 0:
		lines.append(["win_better" if paid > 0 else "win_same", paid])
	else:
		lines.append(["win_done", Balance.LEVEL_DONE])
		lines.append(["win_stars", Balance.LEVEL_PER_STAR * st])
		var fast := pts - Balance.LEVEL_DONE - Balance.LEVEL_PER_STAR * st
		if fast > 0:
			lines.append(["win_fast", fast])
	if int(streak.get("bonus", 0)) > 0:
		lines.append(["win_streak", int(streak["bonus"])])
	return lines


## Was ein Tipp gerade kostet (0 = gratis: Level 1–5, der Gratis-Tipp des Levels, die Rettung).
func hint_cost() -> int:
	return 0 if hint_free() else Balance.HINT_COST


## Ein Tipp wurde benutzt: erst der Gratis-Tipp des Levels.
func note_hint_used() -> void:
	if level_no > 0 and level_no > Balance.HINT_FREE_LEVELS and not state.rescue() and hint_free_left > 0:
		hint_free_left -= 1


# =============================================================================
# Oberfläche der Schöpfung: Heute-Karte, gesperrte Level, Laden, 100-Sekunden-Challenge
# =============================================================================

## Wie today_info, für die Kampagne: state "new" (neues Level offen) · "done_next" (heute geschafft, morgen das
## nächste – nie verraten, was kommt) · "wdt" / "wdt_done" (Welt des Tages) · "world_done_today" (Level 30 heute).
func camp_today_info() -> Dictionary:
	_ensure_camp()
	var k := today_key()
	var now := game_now()
	var nn := Daily.next_new_level(camp)
	var out := {"today": k, "weekday": Daily.weekday_name(k), "countdown": Daily.countdown_text(now),
		"done_today": Daily.done_today(daily, k), "streak": int(daily["streak"]), "best": int(daily["streak_best"]),
		"shields": int(daily["shields"]), "shields_visible": int(daily["shields"]) > 0 or bool(daily["shields_ever"]),
		"week": Daily.week(daily, k), "comeback": str(daily["comeback"]),
		"more_stars": false, "camp": true, "fast_line": ""}
	var wdt_ok := Daily.wdt_available_camp(camp, k)
	if nn <= Campaign.COUNT and level_unlocked(nn):
		var c := Campaign.config(nn)
		out.merge({"state": "new", "day": nn, "title": str(c.get("title", "")),
			"caps": "%s · Level %d" % [str(Days.TEXT["today_new"]), nn],     # „Tag“ hieße hier: Spieltag – darum Level
			"goal": Campaign.goal_line(c), "line": str(c.get("story", "")), "icon": str(Campaign.ICON.get(int(c.get("act", 1)), "star"))})
		if Daily.fast_track_on(camp):
			out["fast_line"] = str(Campaign.TEXT["fast_track"]) % Daily.new_levels_left(camp, k)
		return out
	if wdt_ok:
		var cfg := Campaign.wdt_config(k, Daily.weekday_name(k), camp["stars"])
		if Daily.wdt_done(daily, k):
			out.merge({"state": "wdt_done", "day": 0, "title": str(Days.TEXT["today_done"]), "caps": str(cfg.get("caps", "")),
				"goal": Campaign.goal_line(cfg), "line": str(Days.TEXT["wdt_tomorrow"]), "more_stars": Daily.wdt_stars(daily, k) < 3,
				"icon": "trophy"})
		else:
			out.merge({"state": "wdt", "day": 0, "title": str(Days.TEXT["wdt"]), "caps": str(cfg.get("caps", "")),
				"goal": Campaign.goal_line(cfg), "line": Campaign.goal_line(cfg), "icon": "trophy"})
		return out
	if nn <= Campaign.COUNT:
		var last := maxi(1, nn - 1)
		out.merge({"state": "done_next", "day": nn, "title": str(Days.TEXT["today_done"]), "caps": str(Days.TEXT["today"]),
			"goal": "", "line": str(Campaign.TEXT["locked"]), "more_stars": level_stars(last) < 3, "replay_day": last,
			"icon": "check"})
		return out
	out.merge({"state": "world_done_today", "day": Campaign.COUNT, "title": str(Days.TEXT["complete"]),
		"caps": str(Days.TEXT["today"]), "goal": "", "line": str(Days.TEXT["wdt_first_tomorrow"]),
		"more_stars": level_stars(Campaign.COUNT) < 3, "replay_day": Campaign.COUNT, "icon": "check"})
	return out


## Text für ein gesperrtes Level (nie mit Titel): das nächste neue „Morgen wartet etwas Neues“, sonst „Erst Level n“.
func level_locked_text(n: int) -> String:
	var nn := next_new_level()
	if n == nn and new_level_tomorrow():
		return str(Campaign.TEXT["locked"])
	return "Erst Level %d schaffen." % mini(nn, Campaign.COUNT)


# --- Laden (GDPD_PUNKTE_LADEN.md 5, 7) ------------------------------------------------------------------

## Wunder und Hilfe: id → [Reiter, Titel, Symbol, Preis, Vorrat, ab Level (0 = immer), Satt-Satz nach dem Kauf]
const SHOP_ITEMS = {
	"regen": ["wunder", "Regen", "rain", 25, 3, 5, "Regen bereit."],
	"blitzschutz": ["wunder", "Blitzschutz", "sparkle_shield", 40, 2, 12, "Gut für schlechte Tage."],
	"meteor": ["wunder", "Meteor", "meteor", 60, 1, 23, "Meteor bereit."],
	"tipp": ["hilfe", "Tipp", "bulb", 10, 5, 0, "Gut für schlechte Tage."],
	"zurueck": ["hilfe", "Zurück", "undo", 10, 5, 0, "Gut für schlechte Tage."],
	"schutz": ["hilfe", "Serienschutz", "shield", 100, 2, 0, "Deine Serie ist sicher."],
}
const SHOP_TABS = [["wunder", "Wunder", "miracle"], ["hilfe", "Hilfe", "bulb"], ["gott", "Gott", "profile"], ["welten", "Welten", "days"]]


## Höchstes je erreichtes Level (für „steht erst im Laden, wenn es im Spiel schon vorkam“).
func shop_level_seen() -> int:
	_ensure_camp()
	if bool(camp["veteran"]) or world_done:
		return Campaign.COUNT
	return maxi(level_free(), level_no)


## Die Karten eines Reiters: [{"id", "title", "icon", "price", "have" (Vorrat/besitzt), "max", "full", "owned",
## "worn" (angelegt), "slot", "new", "locked"}]. Nicht spoilern: was noch nicht vorkam, fehlt ganz.
func shop_items(tab: String) -> Array:
	var out: Array = []
	var seen := shop_level_seen()
	if tab == "gott":
		for slot in Character.ACC_SLOTS:
			for a in Character.SHOP_PARTS.get(slot, []):
				var ad: Dictionary = a
				var id := str(ad["id"])
				out.append({"id": id, "title": str(ad["title"]), "icon": "", "price": int(ad["price"]), "slot": str(slot),
					"owned": owned.has(id), "worn": str(character.get(str(slot), "")) == id, "have": 1 if owned.has(id) else 0,
					"max": 1, "full": owned.has(id), "new": not seen_shop.has(id), "part": true})
		return out
	if tab == "welten":
		return [{"id": "bald", "title": "Bald mehr", "icon": "lock", "price": 0, "locked": true, "have": 0, "max": 0,
			"full": false, "new": false}]
	for id in SHOP_ITEMS:
		var it: Array = SHOP_ITEMS[id]
		if str(it[0]) != tab or int(it[5]) > seen:
			continue
		var have := shields() if id == "schutz" else int(stock.get(id, 0))
		var mx := Balance.SHIELD_MAX if id == "schutz" else int(it[4])
		out.append({"id": id, "title": str(it[1]), "icon": str(it[2]), "price": int(it[3]), "have": have, "max": mx,
			"full": have >= mx, "new": not seen_shop.has(id), "owned": false})
	return out


func shop_price(id: String) -> int:
	if SHOP_ITEMS.has(id):
		return int((SHOP_ITEMS[id] as Array)[3])
	var slot := Character.shop_slot(id)
	return int(Character.accessory(slot, id).get("price", 0)) if slot != "" else 0


func shop_title(id: String) -> String:
	if SHOP_ITEMS.has(id):
		return str((SHOP_ITEMS[id] as Array)[1])
	var slot := Character.shop_slot(id)
	return str(Character.accessory(slot, id).get("title", id)) if slot != "" else id


## Kaufen: "" = gekauft, sonst der Grund („Vorrat voll“, „Dir fehlen 20 ✦“).
func buy(id: String) -> String:
	var price := shop_price(id)
	if price <= 0:
		return "Gibt es nicht."
	if id == "schutz":
		return buy_shield()
	if SHOP_ITEMS.has(id):
		var mx := int((SHOP_ITEMS[id] as Array)[4])
		if int(stock.get(id, 0)) >= mx:
			return "Vorrat voll"
	elif owned.has(id):
		return "Hast du schon"
	if points < price:
		return "Dir fehlen %d ✦" % (price - points)
	points -= price
	if SHOP_ITEMS.has(id):
		stock[id] = int(stock.get(id, 0)) + 1
	else:
		owned.append(id)
		Character.owned_parts = owned
	Points._book(pdata, today_key(), "kauf:" + id, 0)
	points_changed.emit(-price, "kauf")
	_save_profile()
	return ""


## Ein Gott-Teil zurückgeben (solange der Laden offen ist): volle Erstattung, angelegt wird es abgelegt.
func refund(id: String) -> bool:
	if not owned.has(id) or SHOP_ITEMS.has(id):
		return false
	owned.erase(id)
	Character.owned_parts = owned
	var slot := Character.shop_slot(id)
	if slot != "" and str(character.get(slot, "")) == id:
		var lk := character.duplicate(true)
		lk[slot] = ""
		set_character(lk)
	var price := shop_price(id)
	points += price
	points_changed.emit(price, "zurueck")
	_save_profile()
	return true


## Ein gekauftes Teil anlegen / ablegen.
func wear(id: String, on: bool) -> void:
	var slot := Character.shop_slot(id)
	if slot == "" or (on and not owned.has(id)):
		return
	var lk := character.duplicate(true) if not character.is_empty() else Character.default_look("bart")
	lk[slot] = id if on else ""
	set_character(lk)


func mark_shop_seen(ids: Array) -> void:
	var changed := false
	for id in ids:
		if not seen_shop.has(str(id)):
			seen_shop.append(str(id))
			changed = true
	if changed:
		_save_profile()


## Ein gekauftes Wunder aus dem Vorrat benutzen (Regen, Meteor: auf ein Feld; Blitzschutz: sofort). Zählt im Level
## 2 Schritte, je Art einmal (GameState). true = es läuft.
var _stock_pending := ""          # gekauftes Wunder (regen/meteor), dessen Runde gerade läuft: abgebucht in finish_round


func use_stock(kind: String, fid: int = -1) -> bool:
	var id := {"rain": "regen", "strike": "meteor", "meteor": "meteor", "guard": "blitzschutz"}.get(kind, kind) as String
	if int(stock.get(id, 0)) <= 0 or state == null or busy or over:
		return false
	if id == "blitzschutz":
		if not state.guard_bolt9():
			return false
		stock[id] = int(stock[id]) - 1
		_save_profile()
		_save_running()
		message.emit("Geschützt", "good")
		state_changed.emit()
		return true
	if fid < 0 or not state.camp:
		return false
	var f: FieldData = state.fields[fid]
	var ok := state.rain_ok9(f, true) if id == "regen" else state.meteor_ok9(f, true)
	if not ok:
		return false
	# Erst wenn die Runde fertig ist (finish_round), zusammen mit dem Lauf: App mitten im Wunder zu → beides wie vorher
	_stock_pending = id
	busy = true
	_last_kind = "rain" if id == "regen" else "strike"
	_start({"type": "rain" if id == "regen" else "strike", "field": fid, "row": [], "bought": true})
	return true


func stock_of(kind: String) -> int:
	var id := {"rain": "regen", "strike": "meteor", "meteor": "meteor", "guard": "blitzschutz"}.get(kind, kind) as String
	return maxi(0, int(stock.get(id, 0)) - (1 if _stock_pending == id else 0))


## Das gekaufte Wunder der gerade fertigen Runde abbuchen (in finish_round, direkt vor _save_run).
func _commit_stock() -> void:
	if _stock_pending == "":
		return
	stock[_stock_pending] = maxi(0, int(stock.get(_stock_pending, 0)) - 1)
	_stock_pending = ""
	_save_profile()


# --- 100-Sekunden-Challenge (GDPD_SCHOEPFUNG.md 12; ersetzt „40 Drehungen“) ---------------------------------

signal sek100_changed(left: float, delta: float)

const SEK100 := 100.0
const SEK100_FIRE := 5.0
var sek100 := false              # das laufende freie Spiel ist die Challenge
var sek100_left := SEK100
var sek100_running := false      # die Uhr läuft (ab der ersten Drehung)
var sek100_done := false
var _sek_next := false
var dead_told := false           # die Sackgasse dieses Versuchs ist schon gemeldet
## Sicherheitsnetz (jedes Level bleibt lösbar, nie eine stille Sackgasse): Nach jeder Runde prüft GameState.stuck9, ob
## das Ziel noch erreichbar ist (reach9) oder ob du seit STALL9 Schritten festhängst. Dann bietet der Charakter Hilfe an
## (level_dead mit "why"): ein Geschenk (take_gift, +1 Fortschritt und Nachschub) oder eine neue Welt (new_world, das
## geprüfte Pool-Brett). Die Tour schaltet es außerhalb ihrer eigenen Prüfung ab (rescue_on), damit ihre Züge planbar bleiben.
var rescue_on := true
var rescue_told_at := -99        # Schritt, an dem der Charakter zuletzt geholfen hat
var rescue_offer: Dictionary = {}   # das offene Angebot (die Oberfläche zeigt es, sobald nichts anderes offen ist)


func _rescue_check() -> void:
	if not rescue_on:
		if not dead_told and state.dead9():
			dead_told = true
			level_dead.emit({"level": level_no, "wdt": wdt_key >= 0})
		return
	var why := state.stuck9()
	if why != "dead":
		dead_told = false
	if why == "":
		return
	var s := state.steps9()
	var fresh_dead := why == "dead" and not dead_told
	if not fresh_dead and s - rescue_told_at < GameState.STALL9:
		return
	if why == "dead":
		dead_told = true
	rescue_told_at = s
	rescue_offer = {"level": level_no, "wdt": wdt_key >= 0, "why": why, "gift": not state.gift_plan9().is_empty(),
		"line": state.rescue_line9(why), "step": s}
	level_dead.emit(rescue_offer.duplicate())


## Das Geschenk des Charakters annehmen (Sicherheitsnetz): +1 Fortschritt und, wenn nötig, Nachschub. Kein Schritt,
## kostet nichts. Die World spielt es wie einen Regen ab (round_resolved, danach finish_round). {} = nichts zu schenken.
func take_gift() -> Dictionary:
	if busy or over or state == null or not state.camp or state.day_won:
		return {}
	if state.gift_plan9().is_empty():
		return {}
	busy = true
	_last_kind = "gift"
	rescue_offer = {}
	dead_told = false
	rescue_told_at = state.steps9()
	undo_state = state.clone()
	var before := snapshot(state)
	var result := state.play({"type": "gift"})
	round_resolved.emit(result, before)
	return result


## „Neue Welt“ (Sicherheitsnetz): dieses Level noch einmal auf seinem geprüften Pool-Brett (Welt des Tages: ein anderes
## Brett derselben Vorlage). Sterne und Punkte wie immer.
func new_world() -> bool:
	if level_no <= 0 or busy:
		return false
	rescue_offer = {}
	if wdt_key >= 0:
		return start_level_wdt(int(level_board.get("index", 0)) + 1)
	var size := Campaign.pool_size(level_no)
	if size <= 0:
		return retry_level()
	var idx := int(level_board.get("index", -1))
	var pick := idx + 1 if idx >= 0 else maxi(1, int((camp["next_board"] as Array)[level_no - 1]))
	if size > 1 and posmod(pick, size) == 0:
		pick += 1                    # Brett 0 ist das Lehr-Brett
	return start_level(level_no, posmod(pick, size))


# --- Build 12: der laufende Level-Versuch bleibt (App zu, Handy aus) --------------------------------------

## Version des Laufs (user://rekord_lauf.cfg, [lauf]). Passt sie nicht, beginnt das Level neu (nie ein kaputter Stand).
const RUN_VERSION := 1
## Der laufende Versuch wurde fortgesetzt (resume_run), nicht neu begonnen: level_info()["resumed"] ist true (keine
## Start-Karte, keine Vorführung, keine Welle). Jeder neue Versuch setzt es zurück.
var run_resumed := false


## Datei des laufenden Versuchs: neben dem Spielstand (Tests leiten save_path um, der Lauf folgt).
func run_path() -> String:
	return save_path.get_basename() + "_lauf.cfg"


## Fingerabdruck der Level-Regeln: Ändert ein Update das Level, beginnt ein gespeicherter Versuch neu.
static func _cfg_hash(cfg: Dictionary) -> String:
	return var_to_str(cfg).md5_text()


## Den laufenden Versuch speichern (nach jeder Runde, nach Zurück, beim Pausieren). Gewonnen oder kein Level: löschen.
func _save_run() -> void:
	if state == null or not state.camp or level_no <= 0 or state.day_won or over \
			or (state.actions9() == 0 and state.steps9() == 0):
		_clear_run()              # nichts getan: das Level beginnt wie gewohnt (mit Start-Karte)
		return
	var d := {"v": RUN_VERSION, "level": level_no, "wdt": wdt_key, "cfg": _cfg_hash(state.day),
		"state": state.save9(), "undo": undo_state.save9() if undo_state != null and undo_state.camp else {},
		"board": level_board.duplicate(true), "hint_free": hint_free_left, "undo_free": undo_free_left,
		"rescue_at": rescue_told_at, "dead_told": dead_told, "offer": rescue_offer.duplicate(true),
		"attempt_key": attempt_key, "attempt_start": attempt_start, "steps": state.steps9(),
		"progress": state.progress9(), "target": state.target9()}
	if wdt_key >= 0:
		d["wdt_cfg"] = state.day.duplicate(true)
	var cfg := ConfigFile.new()
	cfg.set_value("lauf", "daten", d)
	cfg.save(run_path())


## Beim Pausieren/Schließen: nur, wenn gerade ein Level läuft (sonst bleibt ein gespeicherter Versuch, wie er ist).
## Läuft gerade eine Runde (busy), bleibt der Stand vor ihr: das Brett ist schon weiter, finish_round (Sieg, Netz)
## aber noch nicht gelaufen – sonst ginge beim Schließen mitten im Siegeszug der Versuch verloren.
func _save_running() -> void:
	if state != null and state.camp and level_no > 0 and not busy:
		_save_run()


func _clear_run() -> void:
	if FileAccess.file_exists(run_path()):
		DirAccess.remove_absolute(run_path())


## Der gespeicherte Versuch, kurz (für die Übersicht: „Weiter“ statt „Los“): {"level", "wdt" (bool), "steps",
## "progress", "target"} oder {} (keiner oder unbrauchbar).
func saved_run() -> Dictionary:
	var d := _load_run()
	if d.is_empty():
		return {}
	return {"level": int(d["level"]), "wdt": int(d.get("wdt", -1)) >= 0, "steps": int(d.get("steps", 0)),
		"progress": int(d.get("progress", 0)), "target": int(d.get("target", 0))}


func _load_run() -> Dictionary:
	if not FileAccess.file_exists(run_path()):
		return {}
	var cfg := ConfigFile.new()
	if cfg.load(run_path()) != OK:
		return {}
	var v: Variant = cfg.get_value("lauf", "daten", {})
	if not (v is Dictionary):
		return {}
	var d: Dictionary = v
	if int(d.get("v", 0)) != RUN_VERSION or not (d.get("state") is Dictionary):
		return {}
	var n := int(d.get("level", 0))
	if n < 1 or n > Campaign.COUNT:
		return {}
	return d


## Den gespeicherten Versuch fortsetzen (App-Start, oder das Level wird aus der Übersicht wieder geöffnet): Brett,
## Schritte, Fortschritt mit Verlusten, Siegel, Gefahren, Werkzeuge, Geschenk-Stand, Zufall – genau wie vorher.
## false (und der Versuch ist weg), wenn er nicht mehr passt: Level gesperrt, andere Regeln, Welt des Tages von gestern.
## level_started/day_started tragen dann "resumed": true (keine Start-Karte, keine Welle „Neuer Morgen“).
func resume_run() -> bool:
	run_resumed = false
	var d := _load_run()
	if d.is_empty():
		_clear_run()
		return false
	_ensure_camp()
	var n := int(d["level"])
	var wk := int(d.get("wdt", -1))
	var cfg: Dictionary = {}
	if wk >= 0:
		if wk != today_key() or not (d.get("wdt_cfg") is Dictionary):
			_clear_run()
			return false
		cfg = d["wdt_cfg"]
	else:
		if not level_unlocked(n):
			_clear_run()
			return false
		cfg = Campaign.config(n)
		if _cfg_hash(cfg) != str(d.get("cfg", "")):
			_clear_run()
			return false
	var gs := GameState.load9(d["state"], cfg)
	if gs == null or gs.day_won:
		_clear_run()
		return false
	if state != null and not state.is_day():
		_save_best()
	sek100 = false
	day_no = 0
	level_no = n
	wdt_key = wk
	var b: Variant = d.get("board", {})
	level_board = (b as Dictionary).duplicate(true) if b is Dictionary else {}
	day_board = level_board
	tutorial_step = -1
	_tut_board = false
	overnight = {}
	hint_free_left = int(d.get("hint_free", Balance.HINT_FREE))
	undo_free_left = int(d.get("undo_free", Balance.UNDO_FREE))
	attempt_key = int(d.get("attempt_key", today_key()))
	attempt_start = int(d.get("attempt_start", game_now()))
	state = gs
	var ud: Variant = d.get("undo", {})
	undo_state = GameState.load9(ud, cfg) if ud is Dictionary and not (ud as Dictionary).is_empty() else null
	dead_told = bool(d.get("dead_told", false))
	rescue_told_at = int(d.get("rescue_at", -99))
	var of: Variant = d.get("offer", {})
	rescue_offer = (of as Dictionary).duplicate(true) if of is Dictionary else {}
	pending_choice = {}
	busy = false
	over = false
	continued = false
	new_record = false
	onboarding = n <= 2
	new_game_started.emit()
	state_changed.emit()
	run_resumed = true
	var info := level_info()
	day_started.emit(info)
	level_started.emit(info)
	if not rescue_offer.is_empty():
		level_dead.emit(rescue_offer.duplicate())
	return true


## Build 12: was jetzt zu tun ist (Zeile oben im HUD), aus den Regeln (GameState.next_action, Schlüssel dort).
## {} außerhalb eines Levels und während eine Runde läuft. "type" "help": das Sicherheitsnetz (take_gift) hilft.
func next_action() -> Dictionary:
	if state == null or not state.camp or level_no <= 0 or busy:
		return {}
	return state.next_action()


func sek100_paused() -> bool:
	return not pending_choice.is_empty() and not bool(pending_choice.get("mini", false))


func _process(delta: float) -> void:
	if not sek100 or not sek100_running or sek100_done or state == null or state.is_day():
		return
	if sek100_paused():
		return              # die große Wahl-Karte hält die Uhr an (die kleine Pille nicht)
	sek100_left = maxf(0.0, sek100_left - delta)
	if sek100_left <= 0.0 and not busy:
		_sek100_end()


func _sek100_fire() -> void:
	sek100_left = maxf(0.0, sek100_left - SEK100_FIRE)
	sek100_changed.emit(sek100_left, -SEK100_FIRE)


func _sek100_end() -> void:
	if sek100_done:
		return
	sek100_done = true
	sek100_running = false
	pending_choice = {}
	over = true
	_save_best()
	_add_points(Points.free_play_point(pdata, today_key()), "frei")
	_save_profile()
	sek100_changed.emit(0.0, 0.0)
	game_over.emit()
