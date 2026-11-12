extends SceneTree
## Audit „start“, Sonde: ein Pool-Brett, das als gespeichertes Start-Brett wiederkommt (App zu und wieder auf, bevor
## das Level geschafft ist: _level_start_board → how "stored" → Campaign.ensure behandelt es wie eine eigene Welt).
func _init() -> void:
	var total := 0
	var changed_boards := 0
	for n in range(1, Campaign.COUNT + 1):
		var bad: Array = []
		for i in Campaign.pool_size(n):
			var b := Campaign.board(n, i)
			var stored := {"kinds": (b["kinds"] as Array).duplicate(), "seed": int(b["seed"]), "index": -1, "how": "stored",
				"board": str(b["board"]), "solution": []}
			var e := Campaign.ensure(n, stored, 0)
			total += 1
			var diff := 0
			var k2: Array = e["kinds"]
			for j in 54:
				if int(k2[j]) != int((b["kinds"] as Array)[j]):
					diff += 1
			if diff > 0 or str(e.get("line", "")) != "" or str(e.get("how", "")) != "stored":
				changed_boards += 1
				var gs := Campaign.new_state(n, b)
				bad.append("i%d diff=%d how=%s line='%s' lava_clump=%d" % [i, diff, str(e.get("how", "")), str(e.get("line", "")), gs.biggest9(FieldData.LAVA)])
		if not bad.is_empty():
			print("STORED n=%d first_of_era=%s: %d/%d pool boards change when they come back as stored start: %s" % [n,
				str(Campaign.first_of_era(n)), bad.size(), Campaign.pool_size(n), str(bad.slice(0, 4))])
	print("STORED total=%d changed=%d" % [total, changed_boards])
	quit()
