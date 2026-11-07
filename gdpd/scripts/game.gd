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
## Weiterbauen hat begonnen (oder geht weiter): info = day_info().
signal build_started(info: Dictionary)
## „Neuer Morgen“ (GDPD_BALANCE_2.md 5.6): beim ersten Start eines Tages ≥ 2 (nicht bei „Nochmal“, nicht in der
## Welt des Tages, nicht im Weiterbauen). info = {"type": "overnight", "day", "changes": [{"field", "from", "kind"}],
## "caps": „Neuer Morgen“, "line" („Erde wird Wiese“)}. Nur Darstellung: Die Regeln starten vom Pool-Brett.
signal overnight_growth(info: Dictionary)
## Weiterbauen: eine Extra-Aufgabe ist geschafft ({"type": "extra", "level", "target", "max", "done", "text"}).
signal extra_done(info: Dictionary)
## Ein neuer Erinnerungs-Plan (ReminderPlan.plan, schon mit echter Uhrzeit): das Plugin plant ihn ein.
## Hört niemand zu (PC, CI), schreibt Game die Zeilen „REMINDER …“ ins Protokoll.
signal reminders_planned(plan: Array)

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
var credits := 0           # Münzen für Tipps (gibt es für Werbung)
var new_record := false
var endless := true        # false = Challenge (40 Drehungen)
var level := 0             # 0 Einfach (berühren), 1 Mittel (Reihen + Diagonalen), 2 Schwer (nur Reihen)
var _best := {"einfach": 0, "mittel": 0, "schwer": 0, "challenge": 0}
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
var build_state: GameState = null   # Weiterbauen: die Welt, in der gerade weitergebaut wird (nur im Speicher, 2.4)
var build_ctx: Dictionary = {}   # {"day_no", "wdt_key", "board", "given" (bezahlte Zehner), "key" (Spieltag)}
## Die heute geschaffte Welt (der heutige Tag / die Welt des Tages): „Weiterbauen“ auf der Heute-Karte bringt sie
## zurück. Nur ein neuer Sieg im heutigen Level oder ein neuer Spieltag ersetzt sie (nicht „Nochmal“, nicht ein
## anderer Tag, nicht das freie Spiel).
var today_build: GameState = null
var today_build_ctx: Dictionary = {}
var _slot_live := false          # das laufende Weiterbauen ist die heutige Welt (Zurücknehmen hält sie aktuell)
var attempt_key := -1            # Spieltag, an dem der laufende Versuch begann (-1 = keiner)
var attempt_start := -1          # Spielzeit, zu der er begann
var _check_due := false          # Tagesprüfung (Serienschutz) steht noch aus
var _last_today := -2147483648
## Der eigene Charakter (Character, [charakter] in user://charakter.cfg). {} = noch keiner: der Ersteller kommt zuerst.
var character: Dictionary = {}


func _ready() -> void:
	_load_settings()
	_load_best()
	character = Character.load_look()
	note_session()
	call_deferred("replan_reminders")      # nach den anderen Autoloads (Plugin-Hülle)
	if world_done:
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
	tutorial_step = -1
	_tut_board = false
	day_no = 0
	day_board = {}
	wdt_key = -1
	_end_build()
	best = int(_best.get(mode_key(), 0))
	state = GameState.new()
	state.setup(seed_value, endless, level, true)
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
	if key == "challenge":
		new_game(0, 0, CHALLENGE_LEVEL)
	else:
		new_game(0, 1, maxi(0, MODE_KEYS.find(key)))


func level_name() -> String:
	return str(LEVELS[clampi(level, 0, LEVELS.size() - 1)])


## "einfach" | "mittel" | "schwer" | "challenge"
func mode_key() -> String:
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
		"supply": state.preview8(axis, layer, turns, sim) if state.v8 and turns != 0 else {},
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
		if state.day_free_build:
			_build_coins()
			for e in result["events"]:
				if str(e["type"]) == "extra":
					message.emit(str(Days.TEXT["extra_done"]), "good")
					extra_done.emit((e as Dictionary).duplicate())
		if moved_goal:
			day_progress.emit(state.day_status())
		if state.is_over() and not over:
			over = true
			state_changed.emit()
			move_done.emit(_last_kind)
			_finish_day()
			return
	elif state.is_over():
		over = true
		_save_best()
		game_over.emit()
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
	state = undo_state
	undo_state = null
	if build_state != null and state.day_free_build:
		build_state = state
		if _slot_live:
			today_build = state
	pending_choice = {}
	over = false
	# Die Welt baut sich neu auf (new_game_started); die Oberfläche erkennt an undoing, dass der Tag weiterläuft
	undoing = true
	new_game_started.emit()
	undoing = false
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
	if credits < cost:
		return false
	credits -= cost
	_save_profile()
	return true


## Platzhalter für „Video ansehen“: gibt Münzen. Später kommt hier die echte Werbung hin.
func reward_ad() -> void:
	credits += Balance.CREDITS_PER_AD
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
		endless = mk != "challenge"
		level = CHALLENGE_LEVEL if mk == "challenge" else maxi(0, MODE_KEYS.find(mk))
		tutorial_done = bool(cfg.get_value("tutorial", "fertig", false))
		for k in cfg.get_value("tutorial", "hinweise", []):
			coach_seen[str(k)] = true
		credits = int(cfg.get_value("konto", "credits", Balance.CREDITS_START))
		var cs: Dictionary = cfg.get_value("wahl", "karten", {})
		for k in cs:
			cards_seen[int(k)] = int(cs[k])
		always_ask = bool(cfg.get_value("wahl", "immer_fragen", false))
		_load_campaign(cfg)
	else:
		credits = Balance.CREDITS_START
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
	cfg.set_value("konto", "credits", credits)
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
	cfg.set_value("schoepfung", "version", 2)
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
	if state != null and not state.is_day():
		_save_best()             # Glaube des freien Spiels zählt noch für den Rekord
	_end_build()
	attempt_key = today_key()
	attempt_start = game_now()
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
	if wdt_key >= 0:
		return start_daily_world()
	_retrying = true
	var ok := start_day(maxi(1, day_no))
	_retrying = false
	return ok


## Nach einem Sieg: der nächste Tag (false, wenn es keinen gibt – dann ist die Welt vollendet).
func next_day() -> bool:
	if wdt_key >= 0 or day_no >= Days.count():
		return false
	return start_day(day_no + 1)


## Läuft gerade ein Tag?
func in_day() -> bool:
	return day_no > 0 and state != null and state.is_day()


## Tag 1 auf dem Tutorial-Brett (Brett 0): die Oberfläche zeigt die Hand und die Coach-Sätze von Tag 1.
func day_tutorial() -> bool:
	return in_day() and day_no == 1 and int(day_board.get("index", -1)) == 0 and state.used_twists() < 3


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
	var t := 0
	for v in day_stars:
		t += int(v)
	return t


func stars_max() -> int:
	return 3 * Days.count()


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
	return world_done or tutorial_done


## Tipp gratis? (An den Tagen ja – Produktentscheidung, Balance.DAY_HINT_FREE.)
func hint_free() -> bool:
	return in_day() and Balance.DAY_HINT_FREE


## Alles für die Ziel-Karte und den Chip: {"day", "title", "intro", "goal_text", "goal_icon", "goal_type",
## "target", "rule_line", "limit" (mit Gnade), "base_limit", "mercy", "stars" ([★★★ bis, ★★ bis]), "new"
## ({"key", "icon", "title", "text"}), "coach" (Sätze), "best_stars", "best_twists", "board", "tutorial" (Drehung
## oder {}), "first_visit", "status" (GameState.day_status())}.
func day_info() -> Dictionary:
	if not in_day():
		return {}
	var cfg := state.day
	var n := day_no
	var wdt := wdt_key >= 0
	return {"day": n, "title": str(cfg.get("title", "")), "intro": str(cfg.get("intro", "")),
		"wdt": wdt, "wdt_key": wdt_key, "caps": str(cfg.get("caps", str(Days.TEXT["day"]) % n)),
		"free_build": state.day_free_build,
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
		if first_win or int((daily["won_key"] as Array)[i]) == today:
			_keep_for_build()       # der heute geschaffte Tag: Weiterbauen geht auch später aus der Übersicht
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


## Fortschritt der 7 Tage löschen (Einstellungen/Tests). Rekorde des freien Spiels bleiben.
func reset_campaign() -> void:
	_load_campaign(null)
	_save_profile()


# =============================================================================
# Täglich spielen (docs/GDPD_TAEGLICH_CHARAKTER.md 1, 2, 5, 7): Uhr, Spieltag, Serie, Welt des Tages,
# Weiterbauen, Erinnerungs-Plan, Test-Knopf. Die Regeln selbst stehen in Daily und ReminderPlan (rein, getestet).
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
##  "streak", "best", "shields", "shields_visible", "week" (Daily.week), "can_build" (Weiterbauen möglich),
##  "more_stars" (heute geschaffter Tag hat < 3 Sterne), "comeback" ("" | "saved" | "lost", nicht abgeholt)}
## state: "new" (neuer Tag offen) · "done_next" (heute geschafft, der nächste kommt morgen) · "wdt" (Welt des Tages
## offen) · "wdt_done" (heute geschafft) · "world_done_today" (Tag 7 heute geschafft, ab morgen Welt des Tages)
func today_info() -> Dictionary:
	_ensure_campaign()
	var k := today_key()
	var now := game_now()
	var nn := Daily.next_new_day(day_stars)
	var out := {"today": k, "weekday": Daily.weekday_name(k), "countdown": Daily.countdown_text(now),
		"done_today": Daily.done_today(daily, k), "streak": int(daily["streak"]), "best": int(daily["streak_best"]),
		"shields": int(daily["shields"]), "shields_visible": int(daily["shields"]) > 0 or bool(daily["shields_ever"]),
		"week": Daily.week(daily, k), "can_build": can_resume_build(), "comeback": str(daily["comeback"]),
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
	var err := Daily.shield_buy_error(daily, credits)
	if err != "":
		return err
	credits -= Balance.SHIELD_PRICE
	Daily.add_shield(daily)
	_save_profile()
	daily_changed.emit()
	return ""


## Der Sieg zählt für die Serie (nur der erste eines Spieltags). Meilenstein mit vollem Schutz: Münzen.
func _streak_win(today: int) -> Dictionary:
	var start := session_start if session_start >= 0 else now_local()
	var s := Daily.win(daily, today, Daily.minute_of_day(start))
	if int(s["coins"]) > 0:
		credits += int(s["coins"])
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
		_keep_for_build()
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


# --- Weiterbauen (2) -------------------------------------------------------------------------

## Nach dem Sieg in derselben Welt weiterbauen: keine Drehungs-Grenze, kein Scheitern, Wünsche und Glaube laufen
## weiter, Münzen fürs Wachsen. Die Sterne bleiben die des Sieges. false, wenn gerade kein gewonnener Tag läuft.
func continue_build() -> bool:
	if not in_day() or not state.day_won or state.day_free_build:
		return false
	state.start_free_build()
	over = false
	busy = false
	onboarding = false        # Weiterbauen braucht keinen Gratis-Tipp nach jeder Pause (Tag 1–2)
	pending_choice = {}
	undo_state = null
	build_state = state
	build_ctx = {"day_no": day_no, "wdt_key": wdt_key, "board": day_board, "given": 0, "key": today_key()}
	_slot_live = today_build == state
	if _slot_live:
		build_ctx = today_build_ctx
	state_changed.emit()
	day_progress.emit(state.day_status())
	build_started.emit(day_info())
	return true


## Gibt es die heute geschaffte Welt zum Weiterbauen (im Speicher, solange die App läuft, nur an ihrem Spieltag)?
func can_resume_build() -> bool:
	return today_build != null and int(today_build_ctx.get("key", -1)) == today_key()


## Die gerade im heutigen Level geschaffte Welt merken: „Weiterbauen“ auf der Heute-Karte bringt sie zurück (auch ohne
## vorher auf der Erfolgskarte „Weiterbauen“ getippt zu haben). Weiterbauen selbst beginnt erst mit resume_build.
func _keep_for_build() -> void:
	today_build = state
	today_build_ctx = {"day_no": day_no, "wdt_key": wdt_key, "board": day_board, "given": 0, "key": today_key()}


## Zurück in die heute geschaffte Welt zum Weiterbauen (aus der Übersicht).
func resume_build() -> bool:
	if not can_resume_build():
		return false
	if not today_build.day_free_build:
		today_build.start_free_build()
	state = today_build
	build_state = today_build
	build_ctx = today_build_ctx
	_slot_live = true
	day_no = int(build_ctx.get("day_no", day_no))
	wdt_key = int(build_ctx.get("wdt_key", -1))
	day_board = build_ctx.get("board", {})
	attempt_key = -1
	attempt_start = -1
	over = false
	busy = false
	onboarding = false
	pending_choice = {}
	undo_state = null
	new_game_started.emit()
	state_changed.emit()
	build_started.emit(day_info())
	return true


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


## Das laufende Weiterbauen endet (ein neuer Versuch, „Nochmal“, freies Spiel). Die heute geschaffte Welt bleibt.
func _end_build() -> void:
	build_state = null
	build_ctx = {}
	_slot_live = false


## Weiterbauen: 1 Münze je 10 gewachsene Felder, höchstens 3 je Spieltag.
func _build_coins() -> void:
	var g := state.build_growth()
	var given := int(build_ctx.get("given", 0))
	var n := Daily.build_coins(daily, today_key(), g, given)
	build_ctx["given"] = maxi(given, g / maxi(1, Balance.BUILD_COIN_EVERY))
	if n > 0:
		credits += n
		_save_profile()
		for i in n:
			message.emit(str(Days.TEXT["build_coin"]), "good")


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
		replan_reminders()          # wichtig: vielleicht kommt der Spieler nie zurück


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
