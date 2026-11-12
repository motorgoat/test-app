extends SceneTree
## Audit „deadend“, kleine Nachbauten (nur Messung): Stände, in denen eine Art der Ziel-Kette fehlt. Was sagt reach9,
## was die Zeile, was das Geschenk?   godot --headless --script res://tests/_audit_deadend_probe.gd


func _show(tag: String, gs: GameState) -> void:
	var cnt := {}
	for f in gs.fields:
		cnt[FieldData.kind_name(f.kind)] = int(cnt.get(FieldData.kind_name(f.kind), 0)) + 1
	var a := gs.next_action()
	print("%s: %s | reach9 %s | dead9 %s | stuck9 „%s“ | Zeile „%s“ (%s, Zug %s) | Geschenk %s" % [tag, str(cnt), str(gs.reach9()),
		str(gs.dead9()), gs.stuck9(), str(a.get("text", "")), str(a.get("type", "")), str(not (a.get("move", {}) as Dictionary).is_empty()),
		str(gs.gift_plan9())])


func _set_all(gs: GameState, from: int, to: int, keep: int = 0) -> void:
	var left := keep
	for f in gs.fields:
		if f.kind == from:
			if left > 0:
				left -= 1
			else:
				gs._setk9(f, to)
	gs._grp_ok = false
	gs._act_key = ""


func _init() -> void:
	# L49 Sesshaft (3 satte Hütten; Hütten nur aus 3 Frühmenschen in einer Reihe): nur noch 2 Frühmenschen, keine Hütte
	var g49 := Campaign.new_state(49, Campaign.board(49, 1))
	_set_all(g49, FieldData.EARLY, FieldData.MEADOW, 2)
	_show("L49, 2 Frühmenschen, 0 Hütten", g49)
	# L6 Urmeer: kein Fels mehr (alles zu Erde gemacht), nichts versiegelt
	var g6 := Campaign.new_state(6, Campaign.board(6, 1))
	_set_all(g6, FieldData.FELS, FieldData.EMPTY)
	_show("L6 ohne Fels", g6)
	# L7: dasselbe
	var g7 := Campaign.new_state(7, Campaign.board(7, 1))
	_set_all(g7, FieldData.FELS, FieldData.EMPTY)
	_show("L7 ohne Fels", g7)
	# L11 Sauerstoff: kein Wasser mehr (alles verregnet), keine Ursuppe, 4 Einzeller
	var g11 := Campaign.new_state(11, Campaign.board(11, 1))
	_set_all(g11, FieldData.WATER, FieldData.CELLS)
	_show("L11 ohne Wasser", g11)
	# L9: keine Ursuppe, kein Regen: Ursuppe gibt es nur noch durch Regen
	var g9 := Campaign.new_state(9, Campaign.board(9, 1))
	_set_all(g9, FieldData.SOUP, FieldData.CELLS)
	g9.rain = 0
	g9._act_key = ""
	_show("L9 ohne Ursuppe, Regen 0", g9)
	# L9: gar kein Wasser und keine Ursuppe (der Bericht des Spielers, wörtlich): merkt es das Spiel?
	var g9b := Campaign.new_state(9, Campaign.board(9, 1))
	_set_all(g9b, FieldData.WATER, FieldData.EMPTY)
	_set_all(g9b, FieldData.SOUP, FieldData.EMPTY)
	_show("L9 ohne Wasser und ohne Ursuppe", g9b)
	var g6b := Campaign.new_state(6, Campaign.board(6, 1))
	_set_all(g6b, FieldData.WATER, FieldData.EMPTY)
	_show("L6 ohne Wasser", g6b)
	var g6c := Campaign.new_state(6, Campaign.board(6, 1))
	_set_all(g6c, FieldData.WATER, FieldData.EMPTY, 9)
	_show("L6 mit 9 Wasser (Ziel 10)", g6c)
	# L8: Ursuppe braucht Wärme 2; ohne Lava
	var g8 := Campaign.new_state(8, Campaign.board(8, 1))
	_set_all(g8, FieldData.LAVA, FieldData.FELS)
	_show("L8 ohne Lava", g8)
	# L56 Städte: alle Städte zu Wiese (Krieg), 1 Dorf
	var g56 := Campaign.new_state(56, Campaign.board(56, 1))
	_set_all(g56, FieldData.TOWN, FieldData.MEADOW)
	_show("L56 ohne Stadt", g56)
	quit()
