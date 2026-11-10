extends SceneTree
## Abgleich der Kampagnen-Regeln mit dem Python-Modell (docs/GDPD_ERDGESCHICHTE.md 12, engine10):
##   godot --headless --script res://tests/xcheck9.gd [-- --cases=<datei.json>] [--out=<datei.json>]
## Spielt jeden Fall durch den echten GameState (setup_level + play) und vergleicht nach jeder Aktion die Rekord-Zeile
## (GameState.record9) über ihre md5 mit dem Modell (gdpd_sim/b7/mk_xcheck10.py), im Modell-Modus
## (GameState.engine9_mode: ohne die Regeln aus Build 12). --out schreibt die Zeilen der ersten
## abweichenden Fälle (zum Vergleich mit dem Modell). Endet mit „ 0 abweichend“.


func _init() -> void:
	var path := "res://tests/data/xcheck10_cases.json"
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cases="):
			path = a.substr(8)
		elif a.begins_with("--out="):
			out = a.substr(6)
	var r := run(path, out)
	print("xcheck9: %d Fälle, %d Schritte, %d abweichend" % [int(r["cases"]), int(r["steps"]), int(r["bad"])])
	quit(1 if int(r["bad"]) > 0 or int(r["cases"]) == 0 else 0)


static func run(path: String, out: String = "") -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"cases": 0, "steps": 0, "bad": 1}
	# Das Modell kennt die Regeln aus Build 12 nicht (späte Runde usw.): Abgleich im Modell-Modus
	var mode0 := GameState.engine9_mode
	GameState.engine9_mode = true
	var r := _run(f, out)
	GameState.engine9_mode = mode0
	return r


static func _run(f: FileAccess, out: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var bad := 0
	var steps := 0
	var dump: Array = []
	var cases: Array = data["cases"]
	for c in cases:
		var cd: Dictionary = c
		var n := int(cd["level"])
		var gs := GameState.new()
		gs.setup_level(Campaign.config(n), Campaign.decode(str(cd["board"])), int(cd["seed"]))
		var recs: Array = []
		var first_bad := -1
		var sm: Array = cd.get("step_md5", [])
		for a in cd["actions"]:
			var ad: Array = a
			if str(ad[0]) == "twist":
				var m: Array = ad[1]
				gs.play({"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])})
			else:
				gs.play({"type": str(ad[0]), "field": int(ad[1])})
			var rec := gs.record9()
			if first_bad < 0 and recs.size() < sm.size() and rec.md5_text().substr(0, 8) != str(sm[recs.size()]):
				first_bad = recs.size()
			recs.append(rec)
			steps += 1
			if gs.day_won:
				break
		var s := ";".join(PackedStringArray(recs))
		if recs.size() != int(cd["steps"]) or s.md5_text() != str(cd["md5"]):
			bad += 1
			if bad <= 5:
				print("  xcheck9: Level %d Seed %d (%s) weicht ab ab Schritt %d (Schritte %d/%d)" % [n, int(cd["seed"]),
					str(cd.get("kind", "")), first_bad, recs.size(), int(cd["steps"])])
			if out != "" and dump.size() < 20:
				dump.append({"level": n, "seed": int(cd["seed"]), "kind": str(cd.get("kind", "")), "first": first_bad,
					"recs": recs})
	if out != "":
		var w := FileAccess.open(out, FileAccess.WRITE)
		if w != null:
			w.store_string(JSON.stringify({"bad": dump}))
	return {"cases": cases.size(), "steps": steps, "bad": bad}
