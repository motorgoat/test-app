extends SceneTree
## Bot-Kennzahlen (gdpd_spec/GDPD_REGELN.md, 12.4). Kein CI-Test, nur zum Nachsehen beim Balancing:
##   godot --headless --script res://tests/bot_metrics.gd -- [seeds=20] [level=1] [strategy=eval] [challenge=0] [model]
## level: 0 Einfach, 1 Mittel, 2 Schwer. strategy: eval, nature, civ, random.

const Bot = preload("res://tests/gdpd_bot.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 20
	var level := int(args[1]) if args.size() > 1 else 1
	var strat := str(args[2]) if args.size() > 2 else "eval"
	var endless := not (args.size() > 3 and args[3] == "1")
	if args.size() > 4 and args[4] == "model":
		Balance.OTHER_CHOICE_HABIT = false      # wie das Python-Modell: weitere Wahl im selben Zug = Option 1
		print("(Modell-Variante: weitere Wahl im selben Zug = Option 1)")
	var t0 := Time.get_ticks_msec()
	var tw: Array = []
	var won := 0
	var wars := 0
	var smog := 0
	var ok := 0
	var fail := 0
	var faith: Array = []
	var reach := {}
	for sd in range(1, n + 1):
		var b := Bot.play(sd, level, strat, endless)
		var st: Dictionary = b["stats"]
		tw.append(int(b["twists"]))
		faith.append(int(b["faith"]))
		if bool(b["completed"]):
			won += 1
		wars += int(st["wars"])
		smog += int(st["smog"])
		ok += int(st["wish_ok"])
		fail += int(st["wish_fail"])
		for k in b["ever"]:
			reach[int(k)] = int(reach.get(int(k), 0)) + 1
		print("seed %d: %d Drehungen, %d Glaube, %s, Kriege %d, Smog %d, Wünsche %d/%d, Gewitter %d, Flut %d" % [sd, int(b["twists"]),
			int(b["faith"]), "vollendet" if bool(b["completed"]) else ("tot" if bool(b["dead"]) else "offen"), int(st["wars"]),
			int(st["smog"]), int(st["wish_ok"]), int(st["wish_ok"]) + int(st["wish_fail"]), int(st["strikes"]), int(st["floods"])])
	tw.sort()
	faith.sort()
	var total_tw := 0
	for t in tw:
		total_tw += int(t)
	var med: int = int(tw[tw.size() / 2])
	var won_pct := 100.0 * won / n
	var wars_pg := float(wars) / n
	var smog_pct := 100.0 * smog / maxi(1, total_tw)
	var wish_pct := 100.0 * ok / maxi(1, ok + fail)
	print("")
	print("Stufe %d, %s, %d Spiele (%d s)" % [level, strat, n, (Time.get_ticks_msec() - t0) / 1000])
	print("  Drehungen Median %d (p10 %d, p90 %d)   Ziel 50–110   %s" % [med, int(tw[n / 10]), int(tw[9 * n / 10]), _ok(med >= 50 and med <= 110)])
	print("  vollendet %.0f %%                        Ziel 15–40 %%  %s" % [won_pct, _ok(won_pct >= 15 and won_pct <= 40)])
	print("  Kriege pro Spiel %.2f                   Ziel 0,5–3    %s" % [wars_pg, _ok(wars_pg >= 0.5 and wars_pg <= 3.0)])
	print("  Smog %.0f %% der Drehungen                Ziel < 10 %%   %s" % [smog_pct, _ok(smog_pct < 10.0)])
	print("  Wünsche erfüllt %.0f %%                   Ziel 60–90 %%  %s" % [wish_pct, _ok(wish_pct >= 60 and wish_pct <= 90)])
	print("  Glaube Median %d" % int(faith[n / 2]))
	var line := "  erreicht:"
	for k in [FieldData.FIELD, FieldData.ANIMALS, FieldData.HUT, FieldData.VILLAGE, FieldData.TOWN, FieldData.CHURCH, FieldData.BIGCITY,
			FieldData.INDUSTRY, FieldData.METROPOLIS, FieldData.PARADISE]:
		line += " %s %d %%" % [FieldData.KIND_SHORT[k], 100 * int(reach.get(k, 0)) / n]
	print(line)
	var key_ok := true
	for k in [FieldData.HUT, FieldData.CHURCH, FieldData.PARADISE]:
		if 100 * int(reach.get(k, 0)) / n < 60:
			key_ok = false
	print("  Hütte, Kirche, Paradies je ≥ 60 %%        %s" % _ok(key_ok))
	quit()


func _ok(c: bool) -> String:
	return "ok" if c else "AUSSERHALB"
