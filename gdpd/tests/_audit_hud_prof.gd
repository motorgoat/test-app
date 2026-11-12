extends SceneTree
## Hilfsmessung zu _audit_hud.gd: was kostet clone / play / next_action / stuck9 / gift_plan9 / best_action (µs)?
func _init() -> void:
	for n in [7, 26, 54]:
		var gs := Campaign.new_state(n, Campaign.board(n, 1))
		var t := Time.get_ticks_usec()
		for i in 50:
			var c := gs.clone()
		var t_clone := (Time.get_ticks_usec() - t) / 50
		t = Time.get_ticks_usec()
		var c2 := gs.clone()
		for i in 50:
			var m: Array = GameState.MOVES[i % 27]
			c2.play({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])})
		var t_play := (Time.get_ticks_usec() - t) / 50
		t = Time.get_ticks_usec()
		for i in 50:
			c2._act_key = ""
			c2.next_action()
		var t_na := (Time.get_ticks_usec() - t) / 50
		t = Time.get_ticks_usec()
		for i in 50:
			c2.stuck9()
		var t_stuck := (Time.get_ticks_usec() - t) / 50
		t = Time.get_ticks_usec()
		for i in 20:
			c2.gift_plan9()
		var t_gift := (Time.get_ticks_usec() - t) / 20
		t = Time.get_ticks_usec()
		for i in 5:
			gs.best_action()
		var t_best := (Time.get_ticks_usec() - t) / 5
		t = Time.get_ticks_usec()
		for i in 50:
			c2.slot_board9()
		var t_slot := (Time.get_ticks_usec() - t) / 50
		print("n=%d clone=%d play=%d next_action=%d stuck9=%d gift_plan9=%d best_action=%d slot_board9=%d (µs)" % [n, t_clone, t_play, t_na, t_stuck, t_gift, t_best, t_slot])
	quit()
