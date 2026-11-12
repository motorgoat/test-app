extends SceneTree
## Audit „start“, Sonde: ein Spieler, der genau der Zeile oben folgt (next_action: Werkzeug aufs genannte Feld, die
## genannte Drehung; nennt sie keine, dreht er zufällig). Level 6–14, Bretter 1–4: Schritte, Wasser, Sieg.
## Zweiter Lauf „eager“: wie oben, aber jeder Regen geht sofort auf ein Wasser am Ufer („vorausspielen“).
func run(n: int, i: int, eager: bool) -> String:
	var gs := Campaign.new_state(n, Campaign.board(n, i))
	var rng := RandomNumberGenerator.new()
	rng.seed = n * 31 + i
	var acts := 0
	var rand_moves := 0
	var w_min := gs.count(FieldData.WATER)
	var first_stall := -1
	var types := {}
	var no_water_line := ""
	while not gs.day_won and gs.steps9() < 60 and acts < 200:
		acts += 1
		var a: Dictionary = gs.next_action()
		types[str(a.get("type", ""))] = int(types.get(str(a.get("type", "")), 0)) + 1
		var action := {}
		if eager and gs.rain > 0:
			var cand: Array = []
			for f in gs.fields:
				if f.kind == FieldData.WATER and gs.rain_ok9(f):
					cand.append(f.id)
			if not cand.is_empty():
				action = {"type": "rain", "field": int(cand[rng.randi_range(0, cand.size() - 1)])}
		if action.is_empty() and str(a.get("tool", "")) == "rain" and int(a.get("field", -1)) >= 0:
			action = {"type": "rain", "field": int(a["field"])}
		elif action.is_empty() and not (a.get("move", {}) as Dictionary).is_empty():
			var mv: Dictionary = a["move"]
			action = {"type": "twist", "axis": int(mv["axis"]), "layer": int(mv["layer"]), "turns": int(mv["turns"])}
		elif action.is_empty():
			var m: Array = GameState.MOVES[rng.randi_range(0, 26)]
			action = {"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])}
			rand_moves += 1
		gs.play(action)
		w_min = mini(w_min, gs.count(FieldData.WATER))
		if first_stall < 0 and gs.stuck9() != "":
			first_stall = gs.steps9()
		if no_water_line == "" and gs.count(FieldData.WATER) == 0 and not gs.day_won:
			var a2: Dictionary = gs.next_action()
			no_water_line = "at step %d: reach=%s stuck='%s' HUD='%s' ursuppe=%d rain=%d prog=%d/%d" % [gs.steps9(), str(bool(gs.reach9()["ok"])),
				gs.stuck9(), str(a2.get("line", "")), gs.count(18), gs.rain, gs.progress9(), gs.target9()]
	return "won=%s steps=%d water_end=%d(min %d) ursuppe_end=%d rand_moves=%d first_stall=%d types=%s %s" % [str(gs.day_won), gs.steps9(), gs.count(FieldData.WATER),
		w_min, gs.count(18), rand_moves, first_stall, str(types), ("NO_WATER " + no_water_line) if no_water_line != "" else ""]


func _init() -> void:
	for n in range(6, 15):
		for i in range(1, 4):
			print("HUD n=%d board=%d follow: %s" % [n, i, run(n, i, false)])
			print("HUD n=%d board=%d eager:  %s" % [n, i, run(n, i, true)])
	quit()
