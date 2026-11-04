extends Node
## Autoload „Game“: hält den Spielstand, den Rundenablauf, den Meteoriten und den Rekord.
## Keine Darstellung hier. World und UI hören auf die Signale.

signal state_changed
signal new_game_started
signal round_resolved(result: Dictionary, before: Dictionary)   # World spielt die Effekte ab
signal meteor_struck(fid: int, ids: Array)
signal message(text: String, kind: String)                     # kind: info, good, bad
signal game_over

const SAVE_PATH := "user://rekord.cfg"

var state: GameState
var busy := false          # Runde wird ausgewertet/animiert
var over := false
var best_faith := 0
var new_record := false


func _ready() -> void:
	_load_best()
	new_game()


func new_game(seed_value: int = 0) -> void:
	state = GameState.new()
	state.setup(seed_value)
	busy = false
	over = false
	new_record = false
	new_game_started.emit()
	state_changed.emit()
	message.emit("Dreh drei gleiche Felder in eine Reihe.", "info")


func rounds_survived() -> int:
	return state.turn - 1


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
	var result := state.end_round()
	round_resolved.emit(result, before)


func finish_round(_result: Dictionary) -> void:
	busy = false
	if state.bad_rounds > 0 and not state.is_over():
		var left := Balance.LOSE_AFTER - state.bad_rounds
		var why := "Zu wenig Natur!" if state.nature_share() < Balance.NATURE_MIN else "Zu viel Zivilisation!"
		message.emit("%s Die Welt stirbt in %d %s. Ein Meteorit kann helfen." % [why, left, "Runde" if left == 1 else "Runden"], "bad")
	if state.is_over():
		over = true
		_save_best()
		game_over.emit()
	state_changed.emit()


func use_meteor(fid: int) -> bool:
	if busy or over:
		return false
	var err := state.can_meteor()
	if err != "":
		message.emit(err, "bad")
		return false
	var f: FieldData = state.fields[fid]
	var ids := state.use_meteor(f)
	meteor_struck.emit(fid, ids)
	state_changed.emit()
	return true


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_faith = int(cfg.get_value("rekord", "glaube_v4", 0))


func _save_best() -> void:
	new_record = state.faith > best_faith
	best_faith = maxi(best_faith, state.faith)
	var cfg := ConfigFile.new()
	cfg.set_value("rekord", "glaube_v4", best_faith)
	cfg.save(SAVE_PATH)
