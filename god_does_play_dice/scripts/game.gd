extends Node
## Autoload „Game“: hält den Spielstand, den Rundenablauf, die Boni und den Rekord.
## Keine Darstellung hier. World und UI hören auf die Signale.

signal state_changed
signal new_game_started
signal round_resolved(result: Dictionary, before: Dictionary)   # World spielt die Effekte ab
signal message(text: String, kind: String)                     # kind: info, good, bad
signal game_over

const SAVE_PATH := "user://rekord.cfg"
const PRAISE = ["Dein Wille geschehe!", "Euer Wille geschehe!", "Halleluja!", "Gelobt sei der Herr!"]
const GASP = ["Um Gottes Willen!", "Grundgütiger!", "Gottverdammt!", "Herrgott nochmal!", "Heiliger Strohsack!"]

var state: GameState
var busy := false          # Runde wird ausgewertet/animiert
var over := false
var best := 0              # Rekord in Punkten (je Modus)
var tutorial_done := false
var credits := 0           # Credits für Tipps (gibt es für Werbung)
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
	message.emit("Dreh drei gleiche Felder in eine Reihe. Jeder 3. Fehlversuch löst einen Brand aus.", "info")


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
	var before := snapshot(state)
	if turns != 0:
		state.apply_rotation(axis, layer, turns, row)
	var result := state.end_round()
	round_resolved.emit(result, before)


func finish_round(result: Dictionary) -> void:
	busy = false
	if bool(result.get("new_age", false)) and not state.is_over():
		message.emit("%s Die Welt erreicht %s. Ein Leben zurück." % [praise(), state.age_name()], "good")
	var got: Dictionary = result.get("bonus_gained", {})
	if not state.is_over():
		if int(got.get("bolt", 0)) > 0:
			message.emit("Blitz! Er hebt eine ganze Reihe eine Stufe.", "good")
		elif int(got.get("rain", 0)) > 0:
			message.emit("Regen! Er hebt ein Feld eine Stufe oder löscht ein Feuer.", "good")
	for e in result["events"]:
		if str(e["type"]) == "disaster" and not state.is_over():
			var kind := str(e["kind"])
			var tail := "Lösch die Flammen mit Regen." if kind == "fire" else "Die Welt hält noch %d %s aus." % [state.lives, "Katastrophe" if state.lives == 1 else "Katastrophen"]
			message.emit("%s %s! %s. %s" % [gasp(), GameState.DISASTER_NAME[kind], GameState.DISASTER_WHY[kind], tail], "bad")
	if not tutorial_done and state.turn > Balance.TUTORIAL_ROUNDS:
		tutorial_done = true
		_save_best()
	if state.is_over():
		over = true
		_save_best()
		game_over.emit()
	state_changed.emit()


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
	var before := snapshot(state)
	var hit: Array = row.duplicate() if kind == "bolt" and not row.is_empty() else [fid]
	state.apply_bonus(kind, f, row)
	var stages := {}
	for i in hit:
		stages[int(i)] = (state.fields[int(i)] as FieldData).stage
	var result := state.end_round()
	result["bonus"] = {"kind": kind, "field": fid, "fields": hit, "stages": stages}
	round_resolved.emit(result, before)
	return true


static func praise() -> String:
	return str(PRAISE[randi() % PRAISE.size()])


static func gasp() -> String:
	return str(GASP[randi() % GASP.size()])


## Tipp kaufen: kostet Credits. true = bezahlt.
func spend_hint() -> bool:
	if credits < Balance.HINT_COST:
		return false
	credits -= Balance.HINT_COST
	_save_best()
	return true


## Platzhalter für „Werbung ansehen“: gibt einen Credit. Später kommt hier die echte Werbung hin.
func reward_ad() -> void:
	credits += 1
	_save_best()


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		_best["endless"] = int(cfg.get_value("rekord", "endlos_punkte", 0))
		_best["challenge"] = int(cfg.get_value("rekord", "runden40_punkte", 0))
		tutorial_done = bool(cfg.get_value("tutorial", "fertig", false))
		credits = int(cfg.get_value("konto", "credits", Balance.CREDITS_START))
	else:
		credits = Balance.CREDITS_START


func _save_best() -> void:
	if over:
		new_record = score() > best
		best = maxi(best, score())
		_best[_mode_key()] = best
	var cfg := ConfigFile.new()
	cfg.set_value("rekord", "endlos_punkte", int(_best["endless"]))
	cfg.set_value("rekord", "runden40_punkte", int(_best["challenge"]))
	cfg.set_value("tutorial", "fertig", tutorial_done)
	cfg.set_value("konto", "credits", credits)
	cfg.save(SAVE_PATH)
