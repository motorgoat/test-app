extends Node
## Autoload „Game“: hält den Spielstand, den Rundenablauf, die Werkzeuge und den Rekord.
## Keine Darstellung hier. World und UI hören auf die Signale.

signal state_changed
signal new_game_started
signal round_resolved(result: Dictionary, before: Dictionary)   # World spielt die Effekte ab
signal hazards_spawned(list: Array)
signal message(text: String, kind: String)                     # kind: info, good, bad
signal tool_used(kind: String, fid: int)                       # "lightning" / "miracle"
signal game_over

const SAVE_PATH := "user://rekord.cfg"

var state: GameState
var busy := false          # Runde wird ausgewertet/animiert
var over := false
var best_faith := 0
var best_rounds := 0
var new_record := false
var last_gain := 0


func _ready() -> void:
	_load_best()
	new_game()


func new_game(seed_value: int = 0) -> void:
	state = GameState.new()
	state.setup(seed_value)
	busy = false
	over = false
	new_record = false
	last_gain = 0
	new_game_started.emit()
	state_changed.emit()
	message.emit("Bring Gleiches zusammen. Wisch über eine Reihe, um die Welt zu drehen.", "info")


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
		"arranged": arranged,     # Welt direkt nach der Drehung (für Paare/Punkte pro Feld)
		"state": sim,             # Welt nach der Auswertung
		"gain": int(result["gain"]),
		"loss": int(result["loss"]),
		"events": result["events"],
		"harmony": float(sim.harmony()["value"]),
	}


static func snapshot(gs: GameState) -> Dictionary:
	var s := {}
	for f in gs.fields:
		s[f.id] = [f.kind, f.level, f.nation]
	return s


## Eine Runde spielen. turns = 0 heißt „Warten“. Die World ruft danach finish_round() auf.
func play_turn(axis: int, layer: int, turns: int) -> void:
	if busy or over:
		return
	busy = true
	var before := snapshot(state)
	var age_before := state.age()
	if turns != 0:
		state.apply_rotation(axis, layer, turns)
	var result := state.end_round()
	last_gain = int(result["gain"]) - int(result["loss"])
	result["new_age"] = state.age() > age_before
	round_resolved.emit(result, before)


func finish_round(result: Dictionary) -> void:
	var spawned := state.spawn_hazards()
	busy = false
	if bool(result.get("new_age", false)):
		message.emit("Zeitalter %d beginnt. Die Welt wird unruhiger." % state.age(), "bad")
	elif not spawned.is_empty():
		var h: Dictionary = spawned[0]
		var t: String = h["type"]
		var timer := int(h.get("timer", 0))
		if t == "volcano":
			timer = (state.fields[int(h["field"])] as FieldData).volcano
		message.emit("%s in %d Runden!" % [GameState.HAZARD_NAME[t], timer], "bad")
	elif state.bad_rounds > 0:
		message.emit("Die Welt ist aus dem Gleichgewicht! Noch %d Runden." % (Balance.LOSE_AFTER_DISHARMONY - state.bad_rounds), "bad")
	if not spawned.is_empty():
		hazards_spawned.emit(spawned)
	if state.is_over():
		over = true
		_save_best()
		game_over.emit()
	state_changed.emit()


func use_lightning(fid: int) -> bool:
	var f: FieldData = state.fields[fid]
	var err := state.can_lightning(f)
	if err != "" or busy or over:
		if err != "":
			message.emit(err, "bad")
		return false
	state.use_lightning(f)
	tool_used.emit("lightning", fid)
	state_changed.emit()
	return true


func use_miracle(fid: int, kind: String) -> bool:
	var f: FieldData = state.fields[fid]
	var err := state.can_miracle(f)
	if err != "" or busy or over:
		if err != "":
			message.emit(err, "bad")
		return false
	state.use_miracle(f, kind)
	tool_used.emit("miracle", fid)
	message.emit("Wunder! Hier entsteht: %s" % GameState.level_name(f), "good")
	state_changed.emit()
	return true


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_faith = int(cfg.get_value("rekord", "glaube", 0))
		best_rounds = int(cfg.get_value("rekord", "runden", 0))


func _save_best() -> void:
	new_record = state.faith > best_faith
	best_faith = maxi(best_faith, state.faith)
	best_rounds = maxi(best_rounds, rounds_survived())
	var cfg := ConfigFile.new()
	cfg.set_value("rekord", "glaube", best_faith)
	cfg.set_value("rekord", "runden", best_rounds)
	cfg.save(SAVE_PATH)
