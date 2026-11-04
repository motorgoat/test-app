extends Node
## Autoload „Game“: hält den Spielstand, den Rundenablauf, die Boni und den Rekord.
## Keine Darstellung hier. World und UI hören auf die Signale.

signal state_changed
signal new_game_started
signal round_resolved(result: Dictionary, before: Dictionary)   # World spielt die Effekte ab
signal message(text: String, kind: String)                     # kind: info, good, bad
signal game_over

const SAVE_PATH := "user://rekord.cfg"

var state: GameState
var busy := false          # Runde wird ausgewertet/animiert
var over := false
var best := 0              # Rekord in Punkten (je Modus)
var tutorial_done := false
var new_record := false
var endless := true
var _best := {"endless": 0, "challenge": 0}


func _ready() -> void:
	_load_best()
	new_game()


func new_game(seed_value: int = 0, endless_mode: int = -1) -> void:
	if endless_mode >= 0:
		endless = endless_mode == 1
	best = int(_best[_mode_key()])
	state = GameState.new()
	state.setup(seed_value, endless)
	busy = false
	over = false
	new_record = false
	new_game_started.emit()
	state_changed.emit()
	message.emit("Endlos-Spiel: Dreh drei gleiche Felder in eine Reihe." if endless else "40 Runden: Dreh drei gleiche Felder in eine Reihe.", "info")


func _mode_key() -> String:
	return "endless" if endless else "challenge"


func rounds_survived() -> int:
	return state.turn - 1


## Im allerersten Spiel: Drehtipps und Vorschau, was eine Drehung bringt.
func tutorial() -> bool:
	return not tutorial_done and state != null and state.turn <= Balance.TUTORIAL_ROUNDS


func restart_tutorial() -> void:
	tutorial_done = false
	new_game(0, 1)


## Was zählt: die Punkte.
func score() -> int:
	return state.score


## Was würde diese Drehung bewirken? turns = 0: nur warten.
func preview(axis: int, layer: int, turns: int) -> Dictionary:
	var sim := state.clone()
	if turns != 0:
		sim.apply_rotation(axis, layer, turns)
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


## Eine Runde spielen. turns = 0 heißt „Warten“. Die World ruft danach finish_round() auf.
func play_turn(axis: int, layer: int, turns: int) -> void:
	if busy or over:
		return
	busy = true
	var before := snapshot(state)
	if turns != 0:
		state.apply_rotation(axis, layer, turns)
	var age_before := state.age()
	var result := state.end_round()
	result["new_age"] = state.age() > age_before
	round_resolved.emit(result, before)


func finish_round(result: Dictionary) -> void:
	busy = false
	if bool(result.get("new_age", false)) and not state.is_over():
		message.emit("Zeitalter %d: ein Leben zurück. Jetzt Natur %d–%d%%, Zivilisation höchstens %d%%." % [
			state.age(), int(round(state.nature_min() * 100.0)), int(round(state.nature_max() * 100.0)),
			int(round(state.civilisation_max() * 100.0))], "info")
	if int(result.get("bonus_gained", 0)) > 0 and not state.is_over():
		message.emit("Bonus! Setz Regen oder einen Meteoriten auf ein Feld.", "good")
	for e in result["events"]:
		if str(e["type"]) == "disaster" and not state.is_over():
			var kind := str(e["kind"])
			message.emit("%s! %s. Die Welt hält noch %d %s aus." % [GameState.DISASTER_NAME[kind], GameState.DISASTER_WHY[kind],
				state.lives, "Katastrophe" if state.lives == 1 else "Katastrophen"], "bad")
	if not tutorial_done and state.turn > Balance.TUTORIAL_ROUNDS:
		tutorial_done = true
		_save_best()
	if state.is_over():
		over = true
		_save_best()
		game_over.emit()
	state_changed.emit()


## Bonus auf ein Feld: "rain" oder "meteor". Zählt als Zug; die World spielt ihn ab.
func use_bonus(kind: String, fid: int) -> bool:
	if busy or over:
		return false
	var f: FieldData = state.fields[fid]
	var err := state.can_bonus(kind, f)
	if err != "":
		message.emit(err, "bad")
		return false
	busy = true
	var before := snapshot(state)
	state.apply_bonus(kind, f)
	var wet: Array = []
	for id in state.moved:
		wet.append(int(id))
	var age_before := state.age()
	var result := state.end_round()
	result["new_age"] = state.age() > age_before
	result["bonus"] = {"kind": kind, "field": fid, "fields": wet if kind == "rain" else [fid]}
	round_resolved.emit(result, before)
	return true


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		_best["endless"] = int(cfg.get_value("rekord", "endlos_punkte", 0))
		_best["challenge"] = int(cfg.get_value("rekord", "runden40_punkte", 0))
		tutorial_done = bool(cfg.get_value("tutorial", "fertig", false))


func _save_best() -> void:
	if over:
		new_record = score() > best
		best = maxi(best, score())
		_best[_mode_key()] = best
	var cfg := ConfigFile.new()
	cfg.set_value("rekord", "endlos_punkte", int(_best["endless"]))
	cfg.set_value("rekord", "runden40_punkte", int(_best["challenge"]))
	cfg.set_value("tutorial", "fertig", tutorial_done)
	cfg.save(SAVE_PATH)
