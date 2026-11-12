extends SceneTree
## Audit „start“, Sonde: was sagt die Zeile oben (next_action), wenn in Level 6–11 der Stoff für Ursuppe fehlt?
func show(tag: String, gs: GameState) -> void:
	var a: Dictionary = gs.next_action()
	var r: Dictionary = gs.reach9()
	print("%s | water=%d ursuppe=%d fels=%d lava=%d rain=%d next_rain_in=%d | reach=%s stuck='%s' gift=%s | HUD type=%s line='%s' hint='%s' tool=%s" % [tag,
		gs.count(FieldData.WATER), gs.count(18), gs.count(16), gs.count(17), gs.rain, gs.next_rain - gs.twists, str(r), gs.stuck9(),
		str(not gs.gift_plan9().is_empty()), str(a.get("type", "")), str(a.get("line", "")), str(a.get("hint", "")), str(a.get("tool", ""))])

func _init() -> void:
	for n in [6, 7, 8, 9, 10, 11]:
		var b := Campaign.board(n, 1)
		var gs := Campaign.new_state(n, b)
		show("L%d start" % n, gs)
		# a) Regen verbraucht (auf Fels), kein Regen da
		var g2 := gs.clone()
		g2.rain = 0
		g2._act_seq += 1
		show("L%d rain=0" % n, g2)
		# b) alle Ursuppe schon gewachsen (zählt), kein Regen
		var g3 := gs.clone()
		for f in g3.fields:
			if f.kind == 18 and n >= 8:
				g3._rise9(f, 19)
		g3.rain = 0
		g3._act_seq += 1
		show("L%d ursuppe used, rain=0 (progress %d/%d)" % [n, g3.progress9(), g3.target9()], g3)
		g3.rain = 1
		g3._act_seq += 1
		show("L%d ursuppe used, rain=1" % n, g3)
		# c) kein Wasser mehr (alles Wasser ist Erde)
		var g4 := g3.clone()
		for f in g4.fields:
			if f.kind == FieldData.WATER:
				g4._setk9(f, FieldData.EMPTY)
		g4._act_seq += 1
		show("L%d no water, rain=1" % n, g4)
		var top := g4.clone().top_up9(6)
		print("    top_up9(6) from no water: %s" % str(top))
		var gp: Dictionary = g4.gift_plan9()
		print("    gift_plan9: %s" % str(gp))
		# d) kein Fels mehr (Level 6/7: Wasser braucht Fels)
		if n <= 7:
			var g5 := gs.clone()
			for f in g5.fields:
				if f.kind == 16:
					g5._setk9(f, FieldData.EMPTY)
			g5.rain = 0
			g5._act_seq += 1
			show("L%d no rock, rain=0" % n, g5)
	quit()
