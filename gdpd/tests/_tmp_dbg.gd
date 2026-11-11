extends SceneTree
func _subsum(gs: GameState) -> int:
	var s := 0
	for v in gs.sub_values9():
		s += int(v)
	return s
func _run(n: int, bi: int, stop: int) -> void:
	var b: Dictionary = Campaign.board(n, bi)
	var gs := Campaign.new_state(n, b)
	var sol: Array = b.get("solution", [])
	for si in stop:
		var ab: Array = Days.solution_step(sol[si])
		gs.play(ab[0], ab[1])
	print("L", n, " na=", gs.next_action())
	print(" goal=", gs.goal9, " sub=", gs.sub_values9(), " rain=", gs.rain, " chain=", gs.chain9)
	var s0 := _subsum(gs)
	for m in GameState.MOVES:
		var c := gs.clone()
		var ev: Variant = c.play({"type": "twist", "axis": m[0], "layer": m[1], "turns": m[2]})
		if _subsum(c) > s0 or c.day_won:
			var ty: Array = []
			for e in (ev as Dictionary).get("events", []):
				ty.append(str(e.get("type", "")) + ":" + str(e.get("kind", "")) + ">" + str(e.get("to", "")))
			print(" helps ", m, " ", ty)
func _init() -> void:
	_run(54, 9, 8)
	_run(58, 7, 9)
	quit()
