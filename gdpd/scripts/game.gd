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

const SAVE_PATH := "user://rekord.cfg"
const SETTINGS_PATH := "user://einstellungen.cfg"
const PRAISE = ["Dein Wille geschehe!", "Euer Wille geschehe!", "Halleluja!", "Gelobt sei der Herr!"]
const GASP = ["Um Gottes Willen!", "Grundgütiger!", "Herrgott nochmal!", "Heiliger Strohsack!"]
## Drei Stufen (offen, bis die Welt verbrennt) und die Challenge (40 Drehungen, Mittel-Regeln).
const LEVELS = ["Einfach", "Mittel", "Schwer"]
const MODE_KEYS = ["einfach", "mittel", "schwer"]
const CHALLENGE_LEVEL := 1
const MODE_INTRO = {
	"einfach": "Einfach: Ganze Gruppen wachsen mit. Du hast 5 Herzen.",
	"mittel": "Mittel: Schräge Reihen zählen ab dem Wald.",
	"schwer": "Schwer: Nur gerade Reihen zählen.",
	"challenge": "40 Drehungen: Wie viel Glauben schaffst du?",
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
var day_free := 1            # höchster spielbarer Tag (1 … 7; 8 = alle geschafft)
var day_fails: Array = []    # Fehlversuche seit dem letzten Sieg je Tag (Gnade)
var day_next_board: Array = []   # nächstes Pool-Brett je Tag
var world_done := false      # Tag 7 einmal geschafft: freies Spiel offen, „Vollendet“
var save_path := SAVE_PATH   # Tests leiten das auf eine eigene Datei um


func _ready() -> void:
	_load_settings()
	_load_best()
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
				message.emit("Feuer! Noch %d %s. Gieß die brennenden Felder." % [state.lives, "Herz" if state.lives == 1 else "Herzen"], "bad")
			else:
				message.emit("Feuer! Gieß die brennenden Felder.", "bad")
		if str(e["type"]) == "gift":
			message.emit("Gerade passt nichts zusammen. Hier ist ein Regen!", "good")
	# Nichts mehr zu verbinden? Dann gibt es einen Regen geschenkt. (An den Tagen macht das der Spielstand.)
	if not state.is_day() and not state.is_over() and state.gadgets and state.stuck():
		state.grant("rain")
		message.emit("Gerade passt nichts zusammen. Hier ist ein Regen!", "good")
	var moved_goal := false
	for e in result["events"]:
		if str(e["type"]) == "goal":
			moved_goal = true
	if state.is_day():
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
	pending_choice = {}
	over = false
	new_game_started.emit()
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
	message.emit("Deine Welt bekommt noch eine Chance!", "good")
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
	cfg.set_value("schoepfung", "version", 1)
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
	if state != null and not state.is_day():
		_save_best()             # Glaube des freien Spiels zählt noch für den Rekord
	var idx := board_index if board_index >= 0 else int(day_next_board[n - 1])
	_board_explicit = board_index >= 0
	var b := Days.board(n, idx)
	var cfg := Days.config(n)
	var mercy := day_mercy(n)
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
	return true


## Denselben Tag noch einmal (das nächste Brett des Pools, eine Wiederholung ist nie ein Gedächtnistest).
func retry_day() -> bool:
	return start_day(maxi(1, day_no))


## Nach einem Sieg: der nächste Tag (false, wenn es keinen gibt – dann ist die Welt vollendet).
func next_day() -> bool:
	if day_no >= Days.count():
		return false
	return start_day(day_no + 1)


## Läuft gerade ein Tag?
func in_day() -> bool:
	return day_no > 0 and state != null and state.is_day()


## Tag 1 auf dem Tutorial-Brett (Brett 0): die Oberfläche zeigt die Hand und die Coach-Sätze von Tag 1.
func day_tutorial() -> bool:
	return in_day() and day_no == 1 and int(day_board.get("index", -1)) == 0 and state.twists < 3


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


## Ist Tag n spielbar?
func day_unlocked(n: int) -> bool:
	return n >= 1 and n <= Days.count() and n <= day_free


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
func current_day() -> int:
	_ensure_campaign()
	for n in range(1, mini(day_free, Days.count()) + 1):
		if int(day_stars[n - 1]) == 0:
			return n
	return clampi(day_free, 1, Days.count())


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
	return {"day": n, "title": str(cfg.get("title", "")), "intro": str(cfg.get("intro", "")),
		"goal_text": Days.goal_line(cfg), "goal_icon": str(cfg.get("goal_icon", "")), "goal_type": state.goal_type(),
		"target": state.goal_target(), "rule_line": str(cfg.get("rule_line", "")),
		"limit": state.day_limit, "base_limit": int(cfg.get("limit", 0)), "mercy": state.day_limit - int(cfg.get("limit", 0)),
		"stars": (cfg.get("stars", [0, 0]) as Array).duplicate(), "new": (cfg.get("new", {}) as Dictionary).duplicate(),
		"coach": (cfg.get("coach", []) as Array).duplicate(), "best_stars": stars_of(n),
		"best_twists": int(day_best[n - 1]), "board": int(day_board.get("index", 0)),
		"tutorial": (cfg.get("tutorial", {}) as Dictionary).duplicate() if int(day_board.get("index", -1)) == 0 and n == 1 else {},
		"first_visit": int(day_stars[n - 1]) == 0 and int(day_fails[n - 1]) == 0,
		"status": state.day_status()}


## Ende eines Versuchs: Sterne, Freischalten, Gnade, nächstes Brett, speichern, Signal.
func _finish_day() -> void:
	_ensure_campaign()
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
		day_free = maxi(day_free, n + 1)
		var complete := n >= Days.count() and not world_done
		if n >= Days.count():
			world_done = true
		_save_profile()
		info["stars"] = st
		info["used"] = used
		info["best_stars"] = int(day_stars[i])
		info["first_win"] = first_win
		info["next_day"] = n + 1 if n < Days.count() else 0
		info["world_complete"] = complete
		info["stars_total"] = stars_total()
		info["stars_max"] = stars_max()
		day_won.emit(info)
	else:
		day_fails[i] = int(day_fails[i]) + 1
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
	day_free = clampi(day_free, 1, n + 1)


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


## Fortschritt der 7 Tage löschen (Einstellungen/Tests). Rekorde des freien Spiels bleiben.
func reset_campaign() -> void:
	_load_campaign(null)
	_save_profile()
