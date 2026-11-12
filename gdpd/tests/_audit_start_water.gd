extends SceneTree
## Audit „start“, Sonde: Wasser als Vorrat. In Level 8–14 macht nur Regen auf Wasser am Ufer neue Ursuppe (8–11) bzw.
## Algen (12–14); nichts bringt Wasser zurück. Wie viel gießbares Wasser liegt am Start, und wann ist es weg, wenn
## jemand jeden Regen gleich auf Wasser gießt (sorglos drehen, den Sieg vermeiden)?
func rainable(gs: GameState) -> int:
	var n := 0
	var r := gs.rain
	gs.rain = 1
	for f in gs.fields:
		if f.kind == FieldData.WATER and gs.rain_ok9(f):
			n += 1
	gs.rain = r
	return n


func _init() -> void:
	for n in range(6, 15):
		var w0_min := 99
		var r0_min := 99
		var r0_sum := 0
		var none_rainable_at: Array = []
		var none_water_at: Array = []
		var rains_used: Array = []
		for i in range(1, 7):
			var gs := Campaign.new_state(n, Campaign.board(n, i))
			w0_min = mini(w0_min, gs.count(FieldData.WATER))
			var r0 := rainable(gs)
			r0_min = mini(r0_min, r0)
			r0_sum += r0
			var rng := RandomNumberGenerator.new()
			rng.seed = n * 100 + i
			var first_nr := -1
			var first_nw := -1
			var used := 0
			var guard := 0
			while gs.twists < 150 and not gs.day_won and guard < 3000:
				guard += 1
				var action := {}
				if gs.rain > 0:
					var cand: Array = []
					for f in gs.fields:
						if f.kind == FieldData.WATER and gs.rain_ok9(f):
							cand.append(f.id)
					if not cand.is_empty():
						action = {"type": "rain", "field": int(cand[rng.randi_range(0, cand.size() - 1)])}
					elif first_nr < 0 and gs.count(FieldData.WATER) > 0:
						first_nr = gs.twists
				if action.is_empty():
					var m: Array = GameState.MOVES[rng.randi_range(0, 26)]
					action = {"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])}
				var s := gs.clone()
				s.play(action)
				if s.day_won:
					continue
				gs.play(action)
				if str(action["type"]) == "rain":
					used += 1
				if first_nw < 0 and gs.count(FieldData.WATER) == 0:
					first_nw = gs.twists
			none_rainable_at.append(first_nr)
			none_water_at.append(first_nw)
			rains_used.append(used)
			if i == 1:
				var a: Dictionary = gs.next_action()
				print("  L%d board1 after %d twists: water=%d ursuppe=%d rain=%d progress=%d/%d reach=%s stuck='%s' HUD[%s]='%s' hint='%s'" % [n, gs.twists,
					gs.count(FieldData.WATER), gs.count(18), gs.rain, gs.progress9(), gs.target9(), str(bool(gs.reach9()["ok"])), gs.stuck9(),
					str(a.get("type", "")), str(a.get("line", "")), str(a.get("hint", ""))])
		print("WATER n=%d %s: start water min %d, gießbar (am Ufer) min %d avg %.1f | Regen da, aber kein gießbares Wasser zuerst bei Drehung %s | gar kein Wasser mehr bei Drehung %s | Regen auf Wasser %s" % [n,
			str(Campaign.config(n).get("title", "")), w0_min, r0_min, r0_sum / 6.0, str(none_rainable_at), str(none_water_at), str(rains_used)])
	quit()
