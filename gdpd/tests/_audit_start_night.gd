extends SceneTree
## Audit „start“, Sonde: was die Nacht mit der Welt macht (Campaign.carry + ensure). Je Übergang n−1 → n: die Welt am
## Sieg (geprüfte Pool-Lösung, Bretter 1–10) gegen das Start-Brett: geänderte Felder und Arten vorher → nachher.
func _init() -> void:
	var tot_changed := 0
	var tot_n := 0
	for n in range(2, Campaign.COUNT + 1):
		if Campaign.first_of_era(n):
			print("NIGHT %d->%d first of era: fresh pool board (yesterday's world is dropped)" % [n - 1, n])
			continue
		var before := {}
		var after := {}
		var changed := 0
		var runs := 0
		var hows := {}
		var goal_before := 0
		var gk := -1
		var prev_goal: Array = Campaign.config(n - 1).get("goal", [])
		for i in range(1, 11):
			var b := Campaign.board(n - 1, i)
			var gs := Campaign.new_state(n - 1, b)
			for st in (b["solution"] as Array):
				if gs.day_won:
					break
				var ab: Array = Days.solution_step(st)
				gs.play(ab[0], ab[1])
			var world := Campaign.decode(gs.slot_board9())
			var c := Campaign.carry(world, n, 1000 * n + 1, 0)
			c["board"] = Campaign.encode(c["kinds"])
			c = Campaign.ensure(n, c, 0)
			hows[str(c["how"])] = int(hows.get(str(c["how"]), 0)) + 1
			if str(c["how"]) != "carry":
				continue
			runs += 1
			var kinds: Array = c["kinds"]
			for j in 54:
				before[int(world[j])] = int(before.get(int(world[j]), 0)) + 1
				after[int(kinds[j])] = int(after.get(int(kinds[j]), 0)) + 1
				if int(world[j]) != int(kinds[j]):
					changed += 1
		if runs == 0:
			print("NIGHT %d->%d never carried: %s" % [n - 1, n, str(hows)])
			continue
		var ks := {}
		for k in before:
			ks[k] = true
		for k2 in after:
			ks[k2] = true
		var keys: Array = ks.keys()
		keys.sort()
		var s := ""
		for k3 in keys:
			var a := float(int(before.get(k3, 0))) / runs
			var z := float(int(after.get(k3, 0))) / runs
			if absf(a - z) >= 0.5:
				s += "%s %.0f→%.0f, " % [FieldData.kind_name(int(k3)), a, z]
		tot_changed += changed
		tot_n += runs
		print("NIGHT %d->%d (%s → %s) changed %.0f/54 | %s| %s" % [n - 1, n, str(Campaign.config(n - 1).get("chip", "")).replace("{n}", str(int((prev_goal[0] as Array)[2])) if not prev_goal.is_empty() and str((prev_goal[0] as Array)[0]) != "hold" else "n"),
			str(Campaign.config(n).get("chip", "")).replace("{n}", "n"), float(changed) / runs, s, str(hows)])
	print("NIGHT average changed fields per carried start: %.1f of 54 (%d starts)" % [float(tot_changed) / maxi(1, tot_n), tot_n])
	quit()
