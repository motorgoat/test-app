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

const SAVE_PATH := "user://rekord.cfg"
const PRAISE = ["Dein Wille geschehe!", "Euer Wille geschehe!", "Halleluja!", "Gelobt sei der Herr!"]
const GASP = ["Um Gottes Willen!", "Grundgütiger!", "Gottverdammt!", "Herrgott nochmal!", "Heiliger Strohsack!"]

var state: GameState
var busy := false          # Runde wird ausgewertet/animiert
var over := false
var continued := false     # einmal pro Spiel weiterspielen
var undo_state: GameState = null   # Stand vor dem letzten Zug (ein Schritt zurück)
var best := 0              # Rekord in Punkten (je Modus)
var tutorial_done := false
var tutorial_step := -1    # Schritt im Tutorial, -1 = kein Tutorial
var coach_seen := {}       # Hinweise, die schon einmal gezeigt wurden
var _last_kind := ""
var credits := 0           # Credits für Tipps (gibt es für Werbung)
var new_record := false
var endless := true
const LEVELS = ["Einfach", "Mittel", "Schwer", "Profi"]
var survival := false      # Überleben: 3 Herzen, jeder Brand kostet eines
var level := 1             # 0 Einfach (berühren), 1 Mittel (Reihen + Diagonalen), 2 Schwer (nur Reihen), 3 Profi (ohne Gadgets)
var _best := {"0": 0, "1": 0, "2": 0, "3": 0, "challenge": 0}


func _ready() -> void:
	_load_best()
	new_game()


## endless_mode / lvl: -1 = wie zuletzt.
## survival_mode: -1 = wie zuletzt, 0 = aus, 1 = Überleben (3 Herzen).
func new_game(seed_value: int = 0, endless_mode: int = -1, lvl: int = -1, survival_mode: int = -1) -> void:
	if endless_mode >= 0:
		endless = endless_mode == 1
	if lvl >= 0:
		level = lvl
	if survival_mode >= 0:
		survival = survival_mode == 1
	if not endless:
		survival = false
	best = int(_best.get(_mode_key(), 0))
	if not tutorial_done and tutorial_step < 0:
		tutorial_step = 0
	if tutorial_step == 0:
		level = 0          # das erste Spiel ist Einfach, mit Tutorial
		endless = true
		survival = false
		best = int(_best.get(_mode_key(), 0))
	state = GameState.new()
	state.setup(seed_value, endless, level, survival)
	if tutorial_step == 0:
		state.setup_tutorial_board()
	busy = false
	over = false
	continued = false
	undo_state = null
	new_record = false
	new_game_started.emit()
	state_changed.emit()
	if tutorial_step < 0:
		var how := "Eine neue Reihe lässt die ganze Gruppe aufsteigen." if level == 0 else ("Dreh drei gleiche in eine Reihe (auch diagonal)." if level == 1 else "Dreh drei gleiche in eine gerade Reihe.")
		message.emit("%s: %s" % [LEVELS[level], how], "info")


func level_name() -> String:
	return str(LEVELS[level])


func _mode_key() -> String:
	if survival:
		return "survival" + str(level)
	return str(level) if endless else "challenge"


func rounds_survived() -> int:
	return state.turn - 1


## Schritt-für-Schritt-Tutorial im allerersten Spiel: Tipps und Vorschau inklusive.
func tutorial() -> bool:
	return tutorial_step >= 0


func restart_tutorial() -> void:
	tutorial_done = false
	tutorial_step = 0
	coach_seen = {}
	new_game(0, 1, 0, 0)


func tutorial_next() -> void:
	if tutorial_step < 0:
		return
	tutorial_step += 1
	tutorial_changed.emit()


func end_tutorial() -> void:
	tutorial_step = -1
	tutorial_done = true
	_save_best()
	tutorial_changed.emit()


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
	undo_state = state.clone()
	var before := snapshot(state)
	if turns != 0:
		state.apply_rotation(axis, layer, turns, row)
	_last_kind = "twist" if turns != 0 else "wait"
	var result := state.end_round()
	round_resolved.emit(result, before)


func finish_round(result: Dictionary) -> void:
	busy = false
	if bool(result.get("new_age", false)) and not state.is_over():
		message.emit("%s Die Welt erreicht %s.%s" % [praise(), state.age_name(), " Ein Leben zurück." if Balance.LIVES > 0 else ""], "good")
	var got: Dictionary = result.get("bonus_gained", {})
	if not state.is_over():
		if int(got.get("monsoon", 0)) > 0:
			message.emit("Monsun! Tippe eine Seite an: Alle 9 Felder steigen eine Stufe.", "good")
		elif int(got.get("bolt", 0)) > 0:
			message.emit("Blitz! Tippe ein Feld an: Seine ganze Reihe steigt eine Stufe.", "good")
		elif int(got.get("rain", 0)) > 0:
			message.emit("Regen! Gieß ein Feld der niedrigsten Stufe: Es steigt eine Stufe.", "good")
	for e in result["events"]:
		if str(e["type"]) == "disaster" and not state.is_over():
			var kind := str(e["kind"])
			var tail := "Gieß die brennenden Felder, um sie zu retten."
			if state.survival:
				tail = "Noch %d %s. Gieß die brennenden Felder, um sie zu retten." % [state.lives, "Herz" if state.lives == 1 else "Herzen"]
			message.emit("%s %s! %s. %s" % [gasp(), GameState.DISASTER_NAME[kind], GameState.DISASTER_WHY[kind], tail], "bad")
	# Nichts mehr zu verbinden? Die Welt stirbt nicht: Es gibt einen Regen geschenkt.
	if not state.is_over() and state.gadgets and state.stuck():
		state.grant("rain")
		message.emit("Nichts mehr zu verbinden. %s Hier ist ein Regen." % praise(), "good")
	if state.is_over():
		over = true
		_save_best()
		game_over.emit()
	state_changed.emit()
	move_done.emit(_last_kind)


## Bonus: "rain" auf ein Feld oder "bolt" auf eine Reihe (row, 3 IDs). Zählt als Zug; die World spielt ihn ab.
func use_bonus(kind: String, fid: int, row: Array = []) -> bool:
	if busy or over:
		return false
	var f: FieldData = state.fields[fid]
	var err := state.can_bonus(kind, f)
	if err != "":
		message.emit(err, "bad")
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


## Einmal pro Spiel nach dem Ende weiterspielen (kostet Credits).
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
	message.emit("Ein Schritt zurück.", "info")


func continue_game() -> void:
	if not can_continue():
		return
	continued = true
	if state.died():
		state.lives = 1
	if state.stuck():
		state.rain = maxi(state.rain, 2)
	over = false
	message.emit("%s Die Welt bekommt noch eine Chance." % praise(), "good")
	state_changed.emit()


## Bonus schenken oder kaufen (außerhalb eines Zugs).
func grant(kind: String) -> void:
	state.grant(kind)
	state_changed.emit()


## Credits ausgeben. true = bezahlt.
func spend(cost: int) -> bool:
	if credits < cost:
		return false
	credits -= cost
	_save_best()
	return true


## Platzhalter für „Werbung ansehen“: gibt Credits. Später kommt hier die echte Werbung hin.
func reward_ad() -> void:
	credits += Balance.CREDITS_PER_AD
	_save_best()


func save_settings() -> void:
	_save_best()


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		for k in ["0", "1", "2", "3", "survival0", "survival1", "survival2", "survival3"]:
			_best[k] = int(cfg.get_value("rekord", "stufe_" + k, 0))
		_best["challenge"] = int(cfg.get_value("rekord", "runden40_punkte", 0))
		tutorial_done = bool(cfg.get_value("tutorial", "fertig", false))
		for k in cfg.get_value("tutorial", "hinweise", []):
			coach_seen[str(k)] = true
		credits = int(cfg.get_value("konto", "credits", Balance.CREDITS_START))
	else:
		credits = Balance.CREDITS_START


func _save_best() -> void:
	if over:
		new_record = score() > best
		best = maxi(best, score())
		_best[_mode_key()] = best
	var cfg := ConfigFile.new()
	for k in ["0", "1", "2", "3", "survival0", "survival1", "survival2", "survival3"]:
		cfg.set_value("rekord", "stufe_" + k, int(_best.get(k, 0)))
	cfg.set_value("rekord", "runden40_punkte", int(_best["challenge"]))
	cfg.set_value("tutorial", "fertig", tutorial_done)
	cfg.set_value("tutorial", "hinweise", coach_seen.keys())
	cfg.set_value("konto", "credits", credits)
	cfg.save(SAVE_PATH)
