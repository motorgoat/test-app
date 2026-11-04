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
var continued := false     # einmal pro Spiel weiterspielen
var undo_state: GameState = null   # Stand vor dem letzten Zug (ein Schritt zurück)
var best := 0              # Rekord in Punkten (je Modus)
var tutorial_done := false
var credits := 0           # Credits für Tipps (gibt es für Werbung)
var new_record := false
var endless := true
var _best := {"endless": 0, "challenge": 0, "easy": 0}
var easy := false          # einfacher Modus


func _ready() -> void:
	_load_best()
	new_game()


## endless_mode / easy_mode: -1 = wie zuletzt, 0 = aus, 1 = an.
func new_game(seed_value: int = 0, endless_mode: int = -1, easy_mode: int = -1) -> void:
	if endless_mode >= 0:
		endless = endless_mode == 1
	if easy_mode >= 0:
		easy = easy_mode == 1
	best = int(_best[_mode_key()])
	state = GameState.new()
	state.setup(seed_value, endless, easy)
	busy = false
	over = false
	continued = false
	undo_state = null
	new_record = false
	new_game_started.emit()
	state_changed.emit()
	if easy:
		message.emit("Einfacher Modus: Drei gleiche Felder, die sich berühren, verschmelzen.", "info")
	else:
		message.emit("Dreh drei gleiche Felder in eine Reihe. Jeder 3. Fehlversuch löst einen Brand aus.", "info")


func _mode_key() -> String:
	if easy:
		return "easy"
	return "endless" if endless else "challenge"


func rounds_survived() -> int:
	return state.turn - 1


## Im allerersten Spiel: Drehtipps und Vorschau, was eine Drehung bringt.
func tutorial() -> bool:
	return not tutorial_done and state != null and state.turn <= Balance.TUTORIAL_ROUNDS


func restart_tutorial() -> void:
	tutorial_done = false
	new_game(0, 1, 0)


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
			message.emit("Regen! Gieß leere Erde: Sie wird zur Wiese.", "good")
	for e in result["events"]:
		if str(e["type"]) == "disaster" and not state.is_over():
			var kind := str(e["kind"])
			var tail := "Gieß die brennenden Felder, um sie zu löschen." if kind == "fire" else "Die Reihe mit der meisten Zivilisation fällt zurück."
			if kind == "quake" and Balance.LIVES > 0:
				tail = "Die Welt hält noch %d %s aus." % [state.lives, "Katastrophe" if state.lives == 1 else "Katastrophen"]
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
	round_resolved.emit(result, before)
	return true


static func praise() -> String:
	return str(PRAISE[randi() % PRAISE.size()])


static func gasp() -> String:
	return str(GASP[randi() % GASP.size()])


## Einmal pro Spiel nach dem Ende weiterspielen (kostet Credits).
func can_continue() -> bool:
	return over and not continued and (state.died() or state.stuck())


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


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		_best["endless"] = int(cfg.get_value("rekord", "endlos_punkte", 0))
		_best["challenge"] = int(cfg.get_value("rekord", "runden40_punkte", 0))
		_best["easy"] = int(cfg.get_value("rekord", "einfach_punkte", 0))
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
	cfg.set_value("rekord", "einfach_punkte", int(_best["easy"]))
	cfg.set_value("tutorial", "fertig", tutorial_done)
	cfg.set_value("konto", "credits", credits)
	cfg.save(SAVE_PATH)
