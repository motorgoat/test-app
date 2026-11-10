extends SceneTree
## Hilfswerkzeug: Drehungen suchen, nach denen eine Hütte (oder ein anderes Ziel) wächst.
func _initialize() -> void:
	for lv in [24, 25, 26]:
		for bi in range(0, mini(8, Campaign.pool_size(lv))):
			var gs := Campaign.new_state(lv, Campaign.board(lv, bi))
			for m in GameState.MOVES:
				var r: Dictionary = gs.simulate({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])})
				var st: GameState = r["state"]
				var evs: Array = []
				for e in (r["result"] as Dictionary).get("events", []):
					evs.append(str((e as Dictionary).get("type", "")))
				for i in st.fields.size():
					var a: FieldData = gs.fields[i]
					var b: FieldData = st.fields[i]
					if a.kind != b.kind and b.kind == FieldData.HUT:
						print("L%d b%d move %s -> HUT at field %d n=%s events=%s" % [lv, bi, str(m), i, str(b.n), str(evs)])
	quit()
