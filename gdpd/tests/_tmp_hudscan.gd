extends SceneTree
## For every pool board and every step of its stored solution: is the HUD line the generic fallback while one twist
## would raise the goal (sub-goal sum)? Prints per level counts.
func _subsum(gs: GameState) -> int:
	var s := 0
	for v in gs.sub_values9():
		s += int(v)
	return s

func _init() -> void:
	var tot := 0
	for n in range(1, Campaign.COUNT + 1):
		var gen := 0
		var gen_better := 0
		var states := 0
		var ex := ""
		for bi in Campaign.pool_size(n):
			var b: Dictionary = Campaign.board(n, bi)
			var gs := Campaign.new_state(n, b)
			var sol: Array = b.get("solution", [])
			for si in sol.size() + 1:
				if gs.day_won:
					break
				states += 1
				var na := gs.next_action()
				var t := str(na.get("text", ""))
				if t == "Dreh weiter, Regen kommt" or t == "Dreh eine Scheibe":
					gen += 1
					var s0 := _subsum(gs)
					for m in GameState.MOVES:
						var c := gs.clone()
						c.play({"type": "twist", "axis": m[0], "layer": m[1], "turns": m[2]})
						if _subsum(c) > s0 or c.day_won:
							gen_better += 1
							if ex == "":
								ex = "b%d s%d" % [bi, si]
							break
				if si < sol.size():
					var ab: Array = Days.solution_step(sol[si])
					gs.play(ab[0], ab[1])
		tot += gen_better
		if gen > 0:
			print("HUDSCAN L%d states=%d generic=%d generic_but_twist_helps=%d ex=%s" % [n, states, gen, gen_better, ex])
	print("HUDSCAN total generic_but_twist_helps=", tot)
	quit()
