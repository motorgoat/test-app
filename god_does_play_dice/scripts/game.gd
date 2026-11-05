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

const SAVE_PATH := "user://rekord.cfg"
const SETTINGS_PATH := "user://einstellungen.cfg"
const PRAISE = ["Dein Wille geschehe!", "Euer Wille geschehe!", "Halleluja!", "Gelobt sei der Herr!"]
const GASP = ["Um Gottes Willen!", "Grundgütiger!", "Herrgott nochmal!", "Heiliger Strohsack!"]
## Drei Stufen (offen, bis die Welt verbrennt) und die Challenge (40 Drehungen, Mittel-Regeln).
const LEVELS = ["Einfach", "Mittel", "Schwer"]
const MODE_KEYS = ["einfach", "mittel", "schwer"]
const CHALLENGE_LEVEL := 1
const MODE_INTRO = {
	"einfach": "Einfach: Ganze Gruppen wachsen mit.",
	"mittel": "Mittel: Schräge Reihen zählen ab dem kleinen Wald.",
	"schwer": "Schwer: Nur gerade Reihen zählen.",
	"challenge": "40 Drehungen: Wie viele Punkte schaffst du?",
}
## Was neue Spieler nach und nach kennenlernen (in coach_seen gemerkt, „Tutorial nochmal“ setzt es zurück).
const REVEAL_FLAGS = ["show_undo", "show_hint", "show_bolt", "show_coins", "show_flames"]

var state: GameState
var busy := false          # Runde wird ausgewertet/animiert
var over := false
var continued := false     # einmal pro Spiel weiterspielen
var undo_state: GameState = null   # Stand vor dem letzten Zug (ein Schritt zurück)
var best := 0              # Rekord in Punkten (dieser Modus, Stand bei Spielbeginn)
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


func _ready() -> void:
	_load_settings()
	_load_best()
	new_game()


## endless_mode: -1 = wie zuletzt, 1 = offen, 0 = Challenge (40 Drehungen, immer Mittel). lvl: -1 = wie zuletzt.
## Alle Modi haben 3 Herzen.
func new_game(seed_value: int = 0, endless_mode: int = -1, lvl: int = -1) -> void:
	if state != null and not tutorial():
		_save_best()            # Punkte des alten Spiels zählen für den Rekord
	if endless_mode >= 0:
		endless = endless_mode == 1
	if lvl >= 0:
		level = clampi(lvl, 0, LEVELS.size() - 1)
	if not endless:
		level = CHALLENGE_LEVEL
	if not tutorial_done and tutorial_step < 0:
		tutorial_step = 0
	var ended_tutorial := false
	if tutorial_step > 0:
		# Neues Spiel mitten im Tutorial: das Tutorial ist damit vorbei
		tutorial_step = -1
		tutorial_done = true
		coach_seen["reveal_v1"] = true
		ended_tutorial = true
	_tut_board = false
	if tutorial_step == 0:
		level = 0          # das erste Spiel ist Einfach, mit Tutorial
		endless = true
	best = int(_best.get(mode_key(), 0))
	state = GameState.new()
	state.setup(seed_value, endless, level, true)
	if tutorial_step == 0:
		state.setup_tutorial_board()
		_tut_board = true
	state.no_fire = tutorial()
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
	if tutorial():
		tutorial_step = -1
		tutorial_done = true
		coach_seen["reveal_v1"] = true
		tutorial_changed.emit()
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


## Rekord einer Spielart (Punkte).
func best_for(key: String) -> int:
	return int(_best.get(key, 0))


func rounds_survived() -> int:
	return state.turn - 1


## Schritt-für-Schritt-Tutorial im allerersten Spiel: Tipps und Vorschau inklusive.
func tutorial() -> bool:
	return tutorial_step >= 0


func restart_tutorial() -> void:
	_save_best()               # Punkte des laufenden Spiels zählen noch für den Rekord
	tutorial_done = false
	tutorial_step = 0
	coach_seen = {}
	onboarding = false
	new_game(0, 1, 0)


func tutorial_next() -> void:
	if tutorial_step < 0:
		return
	tutorial_step += 1
	tutorial_changed.emit()


## Ende des Tutorials: kein Dialog, man spielt auf demselben Würfel weiter. Die leere Erde erblüht
## zu einem normalen Einfach-Start (Punkte bleiben), dann geht es sofort weiter.
func finish_tutorial() -> void:
	if not tutorial() and not _tut_board:
		return
	var was_board := _tut_board
	tutorial_step = -1
	tutorial_done = true
	_tut_board = false
	coach_seen["reveal_v1"] = true
	onboarding = true
	_onb_merges = 0
	_onb_twists = 0
	if state != null:
		state.no_fire = false
		state.misses = 0
	if was_board and state != null:
		var ids: Array = state.fill_after_tutorial()
		undo_state = null          # nicht zurück auf den Tutorial-Würfel
		tutorial_bloom.emit(ids)
		state_changed.emit()
	_save_best()
	tutorial_changed.emit()


## Alter Name (Notausgang im Tutorial, Menü).
func end_tutorial() -> void:
	finish_tutorial()


## Was zählt: die Punkte.
func score() -> int:
	return state.score


## Was würde diese Drehung bewirken? row: die Felder, über die gewischt wird.
func preview(axis: int, layer: int, turns: int, row: Array = []) -> Dictionary:
	var sim := state.clone()
	if turns != 0:
		sim.apply_rotation(axis, layer, turns, row)
	var arranged := sim.clone()
	var result := sim.end_round()
	return {
		"arranged": arranged,     # Welt direkt nach der Drehung
		"state": sim,             # Welt nach der Auswertung
		"gain": int(result["gain"]),
		"events": result["events"],
	}


static func snapshot(gs: GameState) -> Dictionary:
	var s := {}
	for f in gs.fields:
		s[f.id] = f.stage
	return s


## Einen Zug spielen. turns = 0 heißt „Warten“. Die World ruft danach finish_round() auf.
func play_turn(axis: int, layer: int, turns: int, row: Array = []) -> void:
	if busy or over:
		return
	busy = true
	state.no_fire = tutorial()      # im Tutorial zählen Fehlversuche nicht
	undo_state = state.clone()
	var before := snapshot(state)
	if turns != 0:
		state.apply_rotation(axis, layer, turns, row)
	_last_kind = "twist" if turns != 0 else "wait"
	var result := state.end_round()
	round_resolved.emit(result, before)


func finish_round(result: Dictionary) -> void:
	busy = false
	# Neues Zeitalter, neuer Bonus: Das zeigt die Oberfläche (Pille, Geschenk, beim ersten Mal ein Hinweis).
	if onboarding and _last_kind == "twist":
		_onb_twists += 1
		if int(result.get("gain", 0)) > 0:
			_onb_merges += 1
		if _onb_merges >= Balance.ONBOARD_MERGES or _onb_twists >= Balance.ONBOARD_TWISTS:
			onboarding = false
	for e in result["events"]:
		if str(e["type"]) == "disaster" and not state.is_over() and coach_seen.has("fire"):
			# Beim ersten Feuer erklärt ein Hinweis alles; danach eine kurze Meldung
			if state.hearts:
				message.emit("Feuer! Noch %d %s. Gieß die brennenden Felder." % [state.lives, "Herz" if state.lives == 1 else "Herzen"], "bad")
			else:
				message.emit("Feuer! Gieß die brennenden Felder.", "bad")
	# Nichts mehr zu verbinden? Dann gibt es einen Regen geschenkt.
	if not state.is_over() and state.gadgets and state.stuck():
		state.grant("rain")
		message.emit("Gerade passt nichts zusammen. Hier ist ein Regen!", "good")
	if state.is_over():
		over = true
		_save_best()
		game_over.emit()
	state_changed.emit()
	move_done.emit(_last_kind)


## Bonus: "rain" auf ein Feld oder "bolt" auf eine Reihe (row, 3 IDs). Zählt als Zug; die World spielt ihn ab.
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
	undo_state = state.clone()
	var before := snapshot(state)
	var hit: Array = [fid]
	if kind == "bolt":
		hit = row.duplicate() if not row.is_empty() else state.corner_diagonal(f)
	if kind == "monsoon":
		hit = [fid]
		for g in state.fields:
			if (g as FieldData).n == f.n and (g as FieldData).id != fid:
				hit.append((g as FieldData).id)
	state.apply_bonus(kind, f, row)
	var stages := {}
	for i in hit:
		stages[int(i)] = (state.fields[int(i)] as FieldData).stage
	# Regen ist kein ganzer Zug: Man kann mehrmals hintereinander gießen
	var result := state.resolve_now() if kind == "rain" else state.end_round()
	result["bonus"] = {"kind": kind, "field": fid, "fields": hit, "stages": stages}
	_last_kind = kind
	round_resolved.emit(result, before)
	return true


static func praise() -> String:
	return str(PRAISE[randi() % PRAISE.size()])


static func gasp() -> String:
	return str(GASP[randi() % GASP.size()])


## Einmal pro Spiel nach dem Ende weiterspielen (kostet Münzen).
func can_continue() -> bool:
	return over and not continued and state.died()


## Einen Schritt zurück: der Stand vor dem letzten Zug (nur einmal hintereinander).
func can_undo() -> bool:
	return undo_state != null and not busy


func undo() -> void:
	if not can_undo():
		return
	state = undo_state
	undo_state = null
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
	_save_best()
	return true


## Platzhalter für „Video ansehen“: gibt Münzen. Später kommt hier die echte Werbung hin.
func reward_ad() -> void:
	credits += Balance.CREDITS_PER_AD
	_save_best()


func save_settings() -> void:
	_save_best()


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
	if cfg.load(SAVE_PATH) == OK:
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
	else:
		credits = Balance.CREDITS_START
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


func _save_best() -> void:
	if state != null and not tutorial():
		var mk := mode_key()
		if over:
			new_record = score() > best
		_best[mk] = maxi(int(_best.get(mk, 0)), score())
		if over:
			best = maxi(best, score())
	var cfg := ConfigFile.new()
	for k in _best.keys():
		cfg.set_value("rekorde", str(k), int(_best[k]))
	cfg.set_value("tutorial", "fertig", tutorial_done)
	cfg.set_value("tutorial", "hinweise", coach_seen.keys())
	cfg.set_value("konto", "credits", credits)
	cfg.set_value("spiel", "modus", mode_key())
	cfg.save(SAVE_PATH)
