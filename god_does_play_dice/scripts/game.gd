extends Node
## Autoload „Game“: hält den Spielstand, den Rundenablauf und den Rekord.
## Keine Darstellung hier. World und UI hören auf die Signale.

signal state_changed
signal new_game_started
signal round_resolved(events: Array, before: Dictionary)   # World spielt die Effekte ab
signal hazards_spawned(list: Array)
signal message(text: String, kind: String)                 # kind: info, good, bad
signal game_over

const SAVE_PATH := "user://rekord.cfg"

var state: GameState
var busy := false          # Runde wird ausgewertet/animiert
var over := false
var best_rounds := 0
var best_people := 0
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
	message.emit("Wisch über eine Reihe, um die Welt zu drehen.", "info")


func rounds_survived() -> int:
	return state.turn - 1


## Was würde diese Drehung bewirken? turns = 0: nur warten.
func preview(axis: int, layer: int, turns: int) -> Dictionary:
	var sim := state.clone()
	if turns != 0:
		sim.apply_rotation(axis, layer, turns)
	var events := sim.end_round()
	return {
		"state": sim,
		"events": events,
		"people": sim.total_people() - state.total_people(),
		"animals": sim.total_animals() - state.total_animals(),
	}


static func snapshot(gs: GameState) -> Dictionary:
	var s := {}
	for f in gs.fields:
		s[f.id] = [f.people, f.animals]
	return s


## Eine Runde spielen. turns = 0 heißt „Warten“. Die World ruft danach finish_round() auf.
func play_turn(axis: int, layer: int, turns: int) -> void:
	if busy or over:
		return
	busy = true
	var before := snapshot(state)
	if turns != 0:
		state.apply_rotation(axis, layer, turns)
	var events := state.end_round()
	round_resolved.emit(events, before)


func finish_round() -> void:
	var spawned := state.spawn_hazards()
	busy = false
	if not spawned.is_empty():
		hazards_spawned.emit(spawned)
		var h: Dictionary = spawned[0]
		var t: String = h["type"]
		var timer := int(Balance.HAZARD_TIMER[t])
		message.emit("%s in %d Runden! Dreh die Menschen weg." % [GameState.HAZARD_NAME[t], timer], "bad")
	if state.is_over():
		over = true
		_save_best()
		game_over.emit()
	state_changed.emit()


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_rounds = int(cfg.get_value("rekord", "runden", 0))
		best_people = int(cfg.get_value("rekord", "menschen", 0))


func _save_best() -> void:
	new_record = rounds_survived() > best_rounds
	best_rounds = maxi(best_rounds, rounds_survived())
	best_people = maxi(best_people, state.peak_people)
	var cfg := ConfigFile.new()
	cfg.set_value("rekord", "runden", best_rounds)
	cfg.set_value("rekord", "menschen", best_people)
	cfg.save(SAVE_PATH)
