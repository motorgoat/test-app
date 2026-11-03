extends Node
## Autoload „Game“: hält den GameState, den Takt und die Drehwarteschlange.
## Keine Darstellung hier. World und UI hören auf die Signale.

signal state_changed
signal new_game_started
signal tick_finished(gains: Dictionary)   # {Spieler-ID: Ertrag}
signal rotations_to_play                  # World spielt jetzt die Warteschlange ab
signal message(text: String, bad: bool)
signal ai_log(text: String)
signal game_over(winner: int)

const HUMAN := GameState.HUMAN

var state: GameState
var ai_count: int = Balance.DEFAULT_AI_COUNT
var tick_time := 0.0
var paused := false
var planning := false      # Drehmodus offen: Zeit steht
var animating := false     # Drehungen werden abgespielt: Zeit steht
var menu_open := false     # Menü/Regeln offen: Zeit steht
var over := false
var winner_id := -1
var queue: Array = []      # [{"pid", "axis", "layer", "turns"}]
var _stage_was_ready := false


func _ready() -> void:
	new_game()


func new_game(count: int = -1) -> void:
	if count > 0:
		ai_count = clampi(count, 1, 5)
	state = GameState.new()
	state.setup(ai_count)
	queue.clear()
	tick_time = 0.0
	paused = false
	planning = false
	animating = false
	over = false
	winner_id = -1
	_stage_was_ready = false
	new_game_started.emit()
	state_changed.emit()


func human() -> PlayerData:
	return state.players[HUMAN]


func is_running() -> bool:
	return not (paused or planning or animating or menu_open or over)


func tick_progress() -> float:
	return clampf(tick_time / Balance.TICK_SECONDS, 0.0, 1.0)


func _process(delta: float) -> void:
	if not is_running():
		return
	tick_time += delta
	if tick_time >= Balance.TICK_SECONDS:
		end_tick()


## Takt beenden: Erträge, (Krieger: Stufe 2), KI-Züge, dann alle vorgemerkten Drehungen.
func end_tick() -> void:
	if over or animating or planning:
		return
	tick_time = 0.0
	state.tick += 1
	var gains := state.collect_income()

	var notes := PackedStringArray()
	for pl in state.players:
		if not pl.active or pl.human:
			continue
		var res := AIPlayer.act(state, pl.id, _has_queued(pl.id))
		var rot: Dictionary = res["rotation"]
		if not rot.is_empty():
			queue.append({"pid": pl.id, "axis": rot["axis"], "layer": rot["layer"], "turns": rot["turns"]})
		var log_lines: Array = res["log"]
		if not log_lines.is_empty():
			var parts := PackedStringArray()
			for s in log_lines:
				parts.append(str(s))
			notes.append("%s %s" % [pl.name, ", ".join(parts)])

	tick_finished.emit(gains)
	if not notes.is_empty():
		ai_log.emit(" · ".join(notes))
	_check_stage_ready()
	if _check_over():
		state_changed.emit()
		return
	if queue.is_empty():
		state_changed.emit()
	else:
		animating = true
		state_changed.emit()
		rotations_to_play.emit()


func _has_queued(pid: int) -> bool:
	for q in queue:
		if int(q["pid"]) == pid:
			return true
	return false


## World holt sich die nächste Drehung. Die Logik wird sofort angewendet, die World animiert danach.
func pop_rotation() -> Dictionary:
	if queue.is_empty():
		return {}
	var r: Dictionary = queue.pop_front()
	state.apply_rotation(int(r["axis"]), int(r["layer"]), int(r["turns"]))
	return r


func rotations_done() -> void:
	animating = false
	_check_stage_ready()
	_check_over()
	state_changed.emit()


func _check_over() -> bool:
	if over:
		return true
	var w := state.winner()
	if w >= 0:
		over = true
		winner_id = w
		game_over.emit(w)
		return true
	return false


func _check_stage_ready() -> void:
	var ready_now := state.stage_up_error(HUMAN) == ""
	if ready_now and not _stage_was_ready:
		message.emit("Ausbau zu %s ist jetzt möglich" % Balance.STAGE_NAMES[human().stage + 1], false)
	_stage_was_ready = ready_now


# =============================================================================
# Aktionen des Menschen
# =============================================================================

## Beschreibung des großen Knopfs im Auswahl-Kasten.
## {"label": String, "error": String, "kind": "upgrade"|"buy"|"resident"|"none"}
func describe_action(fid: int) -> Dictionary:
	var f: FieldData = state.fields[fid]
	if f.is_center:
		if f.home == HUMAN:
			return {"label": "+1 Bewohner kaufen · %d%s" % [state.resident_price(HUMAN), GameState.RES_ICON["gold"]],
				"error": state.buy_resident_error(HUMAN), "kind": "resident"}
		var who: String = "neutral" if f.owner < 0 else state.players[f.owner].name
		return {"label": "", "error": "Zentrum von %s. Zentren kann man nicht kaufen." % who if f.owner >= 0 else "Neutrales Zentrum", "kind": "none"}
	if f.owner == HUMAN:
		var target := f.level + 1
		if target > Balance.MAX_FIELD_LEVEL:
			return {"label": "Voll ausgebaut", "error": "Höchste Stufe erreicht", "kind": "upgrade"}
		var label := "Ausbauen auf Stufe %d · %s" % [target, GameState.cost_text(GameState.upgrade_cost(target), Balance.FIELD_UPGRADE_RESIDENTS)]
		return {"label": label, "error": state.upgrade_error(HUMAN, f), "kind": "upgrade"}
	if f.owner < 0:
		var label2 := "Feld kaufen · %d%s" % [state.field_price(HUMAN, f), GameState.RES_ICON["gold"]]
		return {"label": label2, "error": state.buy_field_error(HUMAN, f), "kind": "buy"}
	return {"label": "", "error": "Gehört %s. Fremde Felder kann man nicht kaufen." % state.players[f.owner].name, "kind": "none"}


## Großen Knopf drücken. Gibt {"ok": bool, "text": String} zurück.
func primary_action(fid: int) -> Dictionary:
	if over:
		return {"ok": false, "text": "Das Spiel ist vorbei"}
	var f: FieldData = state.fields[fid]
	var info := describe_action(fid)
	var err: String = info["error"]
	if err != "" or info["kind"] == "none":
		return {"ok": false, "text": err}
	var text := ""
	match info["kind"]:
		"resident":
			state.buy_resident(HUMAN)
			text = "+1 Bewohner"
		"upgrade":
			state.upgrade_field(HUMAN, f)
			text = "Stufe %d" % f.level
		"buy":
			state.buy_field(HUMAN, f)
			text = "Feld gekauft"
	_check_stage_ready()
	_check_over()
	state_changed.emit()
	return {"ok": true, "text": text}


func stage_up() -> String:
	var err := state.stage_up_error(HUMAN)
	if err != "":
		message.emit(err, true)
		return err
	state.stage_up(HUMAN)
	message.emit("%s gebaut! +1 Drehung" % Balance.STAGE_NAMES[human().stage], false)
	_check_stage_ready()
	state_changed.emit()
	return ""


func trade(give: String, get_res: String) -> String:
	var err := state.trade_error(HUMAN, give, get_res)
	if err != "":
		message.emit(err, true)
		return err
	state.trade(HUMAN, give, get_res)
	message.emit("%d %s → 1 %s" % [Balance.TRADE_RATE, GameState.RES_NAME[give], GameState.RES_NAME[get_res]], false)
	_check_stage_ready()
	state_changed.emit()
	return ""


func queue_human_rotation(axis: int, layer: int, turns: int) -> bool:
	if human().rotations <= 0 or turns == 0:
		return false
	human().rotations -= 1
	queue.append({"pid": HUMAN, "axis": axis, "layer": layer, "turns": turns})
	message.emit("Drehung vorgemerkt. Sie passiert am Ende des Takts.", false)
	state_changed.emit()
	return true


func human_queue() -> Array:
	var out: Array = []
	for q in queue:
		if int(q["pid"]) == HUMAN:
			out.append(q)
	return out


## Vorgemerkte Drehung zurücknehmen: Sie wird wieder gutgeschrieben.
func cancel_human_rotation(entry: Dictionary) -> void:
	if animating:
		return
	var i := queue.find(entry)
	if i < 0:
		return
	queue.remove_at(i)
	human().rotations += 1
	message.emit("Drehung zurückgenommen", false)
	state_changed.emit()


func set_planning(on: bool) -> void:
	planning = on
	state_changed.emit()


func skip_tick() -> void:
	if not (planning or animating or over or menu_open):
		end_tick()
