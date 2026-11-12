extends SceneTree
## Audit „hud“ (nur Messung, kein CI-Test): ein ganz neuer Spieler, der nur tut, was die Zeile oben sagt.
##   godot --headless --script res://tests/_audit_hud.gd -- mode=follow from=1 to=60 [boards=20 pre=0,20,60 net=1,0
##       start=pool,carry world=hint|sol]
##   godot --headless --script res://tests/_audit_hud.gd -- mode=chain seeds=6 pre=0,20,60 [to=60]
##   godot --headless --script res://tests/_audit_hud.gd -- mode=water [levels=6,7,8 keep=0,1,2,3 verbose=1]
##   godot --headless --script res://tests/_audit_hud.gd -- mode=one n=6 start=pool board=3 pre=20 net=1 [log=1]
##   godot --headless --script res://tests/_audit_hud.gd -- mode=probe n=8 board=1 set=18>16,15>16 rain=0 [steps=12]
##   godot --headless --script res://tests/_audit_hud.gd -- mode=static
## Der Bot (follow): fragt bei jedem Schritt GameState.next_action() (die Zeile oben) und tut genau das: ihre Drehung,
## ihr Werkzeug, „Hol dir Hilfe“ = Geschenk. Nennt die Zeile keine Drehung, zählt das als blinder Schritt (zufällige
## Drehung). net=1: das Angebot des Charakters (Game._rescue_check, hier nachgebaut) wird angenommen (Geschenk), net=0:
## „Weiterspielen“. Jede genannte Handlung wird gespielt und mit dem verglichen, was die Zeile verspricht.
## Zeilen der Ausgabe (je eine JSON-Zeile): LV (je Level und Lauf-Art), TX (jede Zeile oben, die der Bot sah),
## OF (Angebote des Sicherheitsnetzes), PB (Probleme mit dem ersten Fall zum Nachstellen), CH (Kette), WA/WS (Wasser).

const GameScript = preload("res://scripts/game.gd")
const W := FieldData.WATER
const DANGER_TRACE = {"volcano": ["erupt"], "bolt": ["bolt", "ignite", "burnt"], "pack": ["pack_hunt"], "hunger": ["starve"],
	"smog": ["smog"], "war": ["war_hit"], "flood": ["flood"], "glacier": ["freeze"]}

var args := {}
var name_kind := {}        # „Felsen“ → 16
var need_word := {}        # „Wärme“ → "heat"
var known: Array = []      # known[n]: Arten, die es bis Level n gibt
var first_lv := {}         # Art → erstes Level
var problems := {}         # "Klasse|Level|Zeile" → {"cls", "n", "line", "count", "repro"}
var texts := {}            # Level → {Schlüssel → {...}}
var offers := {}           # Level → {Schlüssel → {...}}
var t_now := 0


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := str(a).split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	t_now = Daily.local_unix(2026, 11, 12, 10)
	_build_names()
	var mode := str(args.get("mode", "follow"))
	if mode == "follow":
		run_follow()
	elif mode == "chain":
		run_chain()
	elif mode == "water":
		run_water()
	elif mode == "one":
		run_one()
	elif mode == "static":
		run_static()
	elif mode == "probe":
		run_probe()
	print("DONE mode=%s" % mode)
	quit()


# --- Wörter und Arten ------------------------------------------------------------------------------

func _build_names() -> void:
	for k in FieldData.KIND_COUNT:
		for nm in [FieldData.kind_name(k), FieldData.kind_plural(k)]:
			if not str(nm).contains(" ") and not name_kind.has(str(nm)):
				name_kind[str(nm)] = k
	for nd in GameState.NEED_NAME9:
		var wd := str(GameState.NEED_NAME9[nd])
		if not name_kind.has(wd) or str(nd) == "wet":
			need_word[wd] = str(nd)
	known = [{}]
	var acc := {}
	for n in range(1, Campaign.COUNT + 1):
		var ks := level_kinds(n)
		for k in ks:
			if not acc.has(k):
				first_lv[k] = n
			acc[k] = true
		known.append(acc.duplicate())


## Arten, die Level n kennt: Startmischung (mit Wasser), Reihen, Gedeihen, Regen, Ziel.
func level_kinds(n: int) -> Dictionary:
	var c := Campaign.config(n)
	var ks := {}
	var comp: Dictionary = c.get("comp", {})
	var total := 0
	for key in comp:
		ks[int(str(key))] = true
		total += int(comp[key])
	if total < 54:
		ks[W] = true
	var gs := GameState.new()
	gs.setup_level(c, Campaign.board(n, 0).get("kinds", []), 1)
	for k in gs.rows9:
		ks[int(k)] = true
		ks[int(gs.rows9[k])] = true
	for k2 in gs.thrive9:
		ks[int(k2)] = true
		var r: Dictionary = gs.thrive9[k2]
		if int(r["up"]) >= 0:
			ks[int(r["up"])] = true
		var sp: Array = r["spawn"]
		if not sp.is_empty():
			ks[int(sp[1])] = true
			for o in sp[0]:
				ks[int(o)] = true
	for it in gs.rain9:
		ks[int((it as Array)[0])] = true
		ks[int((it as Array)[2])] = true
	for sd in gs.goal9:
		var subs: Array = (sd as Dictionary)["subs"] if str((sd as Dictionary)["type"]) == "hold" else [sd]
		for x in subs:
			for k3 in (x as Dictionary)["kinds"]:
				ks[int(k3)] = true
	return ks


func words(s: String) -> Array:
	var t := s
	for ch in ["→", ",", ":", "!", "?", ".", "+", "/", "-", "(", ")"]:
		t = t.replace(ch, " ")
	var out: Array = []
	for w in t.split(" ", false):
		out.append(str(w))
	return out


func cnt(gs: GameState, k: int) -> int:
	var c := 0
	for f in gs.fields:
		if f.kind == k:
			c += 1
	return c


func wfam(gs: GameState) -> int:
	var c := 0
	for f in gs.fields:
		if FieldData.water_family(f.kind):
			c += 1
	return c


func twist(m: Array) -> Dictionary:
	return {"type": "twist", "axis": int(m[0]), "layer": int(m[1]), "turns": int(m[2])}


func pb(cls: String, n: int, line: String, repro: String) -> void:
	var key := "%s|%d|%s" % [cls, n, line]
	if not problems.has(key):
		problems[key] = {"cls": cls, "n": n, "line": line, "count": 0, "repro": repro}
	(problems[key] as Dictionary)["count"] = int((problems[key] as Dictionary)["count"]) + 1


func note_text(n: int, a: Dictionary, gs: GameState) -> void:
	if not texts.has(n):
		texts[n] = {}
	var key := "%s|%s|%s" % [str(a.get("type", "")), str(a.get("line", "")), str(a.get("hint", ""))]
	var d: Dictionary = texts[n]
	if not d.has(key):
		var unk: Array = []
		for w in words(str(a.get("line", "")) + " " + str(a.get("hint", ""))):
			if name_kind.has(w) and not (known[n] as Dictionary).has(int(name_kind[w])):
				unk.append("%s(L%d)" % [w, int(first_lv.get(int(name_kind[w]), 0))])
		d[key] = {"n": n, "type": str(a.get("type", "")), "text": str(a.get("text", "")), "line": str(a.get("line", "")),
			"hint": str(a.get("hint", "")), "count": 0, "moves": 0, "tool": str(a.get("tool", "")), "unknown": unk,
			"danger": str(a.get("danger", "")), "steps": int(a.get("steps", 1)), "rain_pos": 0, "rain_max": 0}
	var e: Dictionary = d[key]
	e["count"] = int(e["count"]) + 1
	if gs.rain > 0:
		e["rain_pos"] = int(e["rain_pos"]) + 1       # die Zeile stand da, während Regen bereit lag
	if gs.rain >= int(GameState.B9["RAIN_MAX"]):
		e["rain_max"] = int(e["rain_max"]) + 1
	if not (a.get("move", {}) as Dictionary).is_empty():
		e["moves"] = int(e["moves"]) + 1


## Spricht die Zeile (oder die zweite Zeile) von einer Art, die nicht auf dem Brett liegt?
func check_absent(gs: GameState, n: int, a: Dictionary, repro: String) -> void:
	var text := str(a.get("text", ""))
	for w in words(text):
		if name_kind.has(w) and cnt(gs, int(name_kind[w])) == 0:
			pb("absent_text:%s" % w, n, str(a.get("line", "")), repro)
	var hint := str(a.get("hint", ""))
	if hint == "":
		return
	var left := hint.split("→")[0]
	var first := true
	for w2 in words(left):
		if need_word.has(w2) and (not first or not name_kind.has(w2)):
			var nd := str(need_word[w2])
			var any := false
			if nd == "wet":
				any = cnt(gs, W) > 0
				if not any:
					pb("absent_hint:Wasser(Familie %d)" % wfam(gs), n, hint, repro)
				first = false
				continue
			if nd == "sun":
				first = false
				continue
			for s in GameState.SOURCES9.get(nd, []):
				if cnt(gs, int(s)) > 0:
					any = true
			if not any:
				pb("absent_hint:%s" % w2, n, hint, repro)
		elif name_kind.has(w2) and cnt(gs, int(name_kind[w2])) == 0:
			pb("absent_hint:%s" % w2, n, hint, repro)
		first = false


# --- Der Zeile folgen -------------------------------------------------------------------------------

## Eine Aktion spielen: nur auf dem Stand, oder im echten Game (finish_round: Netz, Lauf speichern, Sieg).
func do_play(gs: GameState, g: Node, action: Dictionary) -> Dictionary:
	if g != null and str(action.get("type", "")) == "gift":
		var r: Dictionary = g.take_gift()
		if not r.is_empty():
			g.finish_round(r)
		return r
	var res: Dictionary = gs.play(action)
	if g != null:
		g.finish_round(res)
	return res


## Sorglose Drehungen (nie eine, die gewinnt: kurz vor dem Ziel wird jede Drehung erst auf einer Kopie geprüft).
## Gibt den Stand danach zurück. st["pre_won"]: trotzdem gewonnen (ein Sprung über das Ziel).
func careless(gs0: GameState, g: Node, rng: RandomNumberGenerator, t_max: int, st: Dictionary) -> GameState:
	var gs := gs0
	var done := 0
	var guard := 0
	while done < t_max and guard < t_max * 6:
		guard += 1
		var m: Array = GameState.MOVES[rng.randi_range(0, 26)]
		if g != null or gs.target9() - gs.progress9() <= 3:
			var c := gs.clone()
			c.play(twist(m))
			if c.day_won:
				continue
			if g == null:
				gs = c
				net_check(gs, st, false, true)
				done += 1
				continue
		if g != null:
			do_play(gs, g, twist(m))
			if not (g.rescue_offer as Dictionary).is_empty():
				st["pre_offers"] = int(st.get("pre_offers", 0)) + 1
				g.rescue_offer = {}
		else:
			gs.play(twist(m))
			if gs.day_won:
				st["pre_won"] = true
				break
			net_check(gs, st, false, true)
		done += 1
	st["pre_done"] = done
	return gs


## Game._rescue_check nachgebaut (ohne Game-Knoten). take: das Geschenk annehmen. Gibt true zurück, wenn geschenkt wurde.
func net_check(gs: GameState, st: Dictionary, take: bool, pre: bool = false) -> bool:
	if gs.day_won:
		return false
	var why := gs.stuck9()
	if why != "dead":
		st["dead_told"] = false
	if why == "":
		return false
	var s := gs.steps9()
	var fresh_dead := why == "dead" and not bool(st.get("dead_told", false))
	if not fresh_dead and s - int(st.get("told_at", -99)) < GameState.STALL9:
		return false
	if why == "dead":
		st["dead_told"] = true
	st["told_at"] = s
	var has_gift := not gs.gift_plan9().is_empty()
	note_offer(gs, why, has_gift, gs.rescue_line9(why), st, pre)
	if pre:
		return false
	st["offers"] = int(st.get("offers", 0)) + 1
	if not has_gift:
		st["offers_nogift"] = int(st.get("offers_nogift", 0)) + 1
		return false
	if not take:
		return false
	var sum0 := gs._subs_sum9()
	var held0 := str(gs.held9)
	gs.play({"type": "gift"})
	st["dead_told"] = false
	st["told_at"] = gs.steps9()
	st["gifts_modal"] = int(st.get("gifts_modal", 0)) + 1
	if gs._subs_sum9() <= sum0 and str(gs.held9) == held0 and not gs.day_won:
		pb("gift_no_progress", gs.level_no, gs.rescue_line9(why), str(st.get("repro", "")))
	return true


func note_offer(gs: GameState, why: String, has_gift: bool, line: String, st: Dictionary, pre: bool) -> void:
	var n := gs.level_no
	if not offers.has(n):
		offers[n] = {}
	var r := gs.reach9()
	var key := "%s|%s|%s|%s|%s" % [why, line, str(has_gift), str(r.get("why", "")),
		FieldData.kind_name(int(r["kind"])) if r.has("kind") else ""]
	var d: Dictionary = offers[n]
	if not d.has(key):
		d[key] = {"n": n, "why": why, "line": line, "gift": has_gift, "reach_why": str(r.get("why", "")),
			"reach_kind": FieldData.kind_name(int(r["kind"])) if r.has("kind") else "", "dead9": gs.dead9(), "count": 0,
			"pre": 0, "water": cnt(gs, W), "hud": str(gs.next_action().get("line", "")), "repro": str(st.get("repro", "")),
			"board": gs.slot_board9()}
	(d[key] as Dictionary)["count"] = int((d[key] as Dictionary)["count"]) + 1
	if pre:
		(d[key] as Dictionary)["pre"] = int((d[key] as Dictionary)["pre"]) + 1


## Der HUD-Folger. o: {"net": bool, "budget": Schritte, "log": bool, "repro": Text, "g": Game-Knoten oder null}.
## st trägt den Netz-Stand (told_at, dead_told) über das Vorausspielen hinweg.
func follow(gs: GameState, rng: RandomNumberGenerator, o: Dictionary, st: Dictionary) -> Dictionary:
	var n := gs.level_no
	var g: Node = o.get("g")
	var net := bool(o.get("net", true))
	var budget := int(o.get("budget", 4 * gs.par9))
	var logit := bool(o.get("log", false))
	var s0 := gs.steps9()
	var acts := 0
	var blind := 0
	var waits := 0
	var named := 0
	var tools := 0
	var gifts_line := 0
	var revisits := 0
	var streak := 0
	var max_streak := 0
	var last_line := ""
	var last_sum := -1
	var damage := {}
	var seen := {}
	var pending: Array = []        # [Feld, Art vorher, Art versprochen, Aktion Nr., Zeile]
	seen["%s|%d|%d" % [gs.slot_board9(), gs.rain, gs._subs_sum9()]] = true
	while not gs.day_won and gs.steps9() - s0 < budget and acts < budget * 4 + 20:
		acts += 1
		var a: Dictionary = gs.next_action()
		var typ := str(a.get("type", ""))
		var line := str(a.get("line", ""))
		var mv: Dictionary = a.get("move", {})
		var tl := str(a.get("tool", ""))
		var fid := int(a.get("field", -1))
		var repro := "%s akt=%d schritt=%d regen=%d brett=%s" % [str(o.get("repro", "")), acts, gs.steps9(), gs.rain, gs.slot_board9()]
		st["repro"] = repro
		note_text(n, a, gs)
		check_absent(gs, n, a, repro)
		var sum0 := gs._subs_sum9()
		if line == last_line and sum0 == last_sum:
			streak += 1
			max_streak = maxi(max_streak, streak)
			if streak == 5:
				pb("same_line_6x_no_progress", n, line, repro)
		else:
			streak = 0
		last_line = line
		last_sum = sum0
		var action := {}
		var how := "blind"
		if typ == "help" or tl == "gift":
			if gs.gift_plan9().is_empty():
				pb("help_without_gift", n, line, repro)
				action = twist(GameState.MOVES[rng.randi_range(0, 26)])
			else:
				action = {"type": "gift"}
				how = "gift"
		elif (tl == "rain" or tl == "meteor") and fid >= 0:
			action = {"type": tl, "field": fid}
			how = "tool"
		elif not mv.is_empty():
			action = {"type": "twist", "axis": int(mv["axis"]), "layer": int(mv["layer"]), "turns": int(mv["turns"])}
			how = "named"
		else:
			action = twist(GameState.MOVES[rng.randi_range(0, 26)])
			how = "wait" if typ == "wait" else "blind"
		var made0: Array = gs.made.duplicate()
		var held0 := str(gs.held9)
		var fl: Array = a.get("fields", [])
		var f0 := int(fl[0]) if not fl.is_empty() else -1
		var k0 := (gs.fields[f0] as FieldData).kind if f0 >= 0 else -1
		var big0 := gs.biggest9(k0) if typ == "group" and k0 >= 0 else 0
		var threats: Array = gs._act_threats9()
		gs._nb_ok = false
		gs._grp_ok = false
		var res: Dictionary = do_play(gs, g, action)
		if how == "named":
			named += 1
		elif how == "tool":
			tools += 1
		elif how == "gift":
			gifts_line += 1
		elif how == "wait":
			waits += 1
		else:
			blind += 1
		var trace: Array = res.get("trace", [])
		var sum1 := gs._subs_sum9()
		var result := int(a.get("result", -1))
		# --- was die Zeile versprach ---
		if typ == "row" and how == "named" and result >= 0 and int(gs.made[result]) <= int(made0[result]):
			pb("row_no_result", n, line, repro)
		if typ == "group" and how == "named" and k0 >= 0 and gs.biggest9(k0) <= big0:
			pb("group_not_bigger", n, line, repro)
		if typ == "thrive" and how == "named" and f0 >= 0:
			var ff: FieldData = gs.fields[f0]
			if ff.kind == k0 and not gs.satt9(f0):
				pb("thrive_not_supplied", n, line, repro)
			elif ff.kind == k0 and result >= 0:
				pending.append([f0, k0, result, acts, line, repro])
		if typ == "wait" and f0 >= 0:
			var fw: FieldData = gs.fields[f0]
			if fw.kind == k0 and not gs.satt9(f0):
				pb("wait_supply_lost", n, line, repro)
			elif fw.kind == k0:
				var have := false
				for p in pending:
					if int((p as Array)[0]) == f0:
						have = true
				if not have:
					pending.append([f0, k0, result, acts, line, repro])
		if typ == "danger" and how == "named":
			for t in DANGER_TRACE.get(str(a.get("danger", "")), []):
				if trace.has(t):
					pb("danger_not_averted:%s" % str(a.get("danger", "")), n, line, repro)
					break
		if typ == "goal" and how == "named" and int(a.get("steps", 1)) == 2 and not gs.day_won:
			var a2: Dictionary = gs.next_action()
			var want := str(a.get("text", "")).replace("Bring 3", "Dreh 3")
			if str(a2.get("text", "")) != want or str(a2.get("type", "")) != "row":
				if (a2.get("move", {}) as Dictionary).is_empty() and str(a2.get("tool", "")) == "":
					pb("two_step_then_blind", n, line + " ⇒ " + str(a2.get("line", "")), repro)
				elif sum1 <= sum0:
					pb("two_step_other_line", n, line + " ⇒ " + str(a2.get("line", "")), repro)
		if how == "tool":
			if bool(res.get("refused", false)):
				pb("tool_refused", n, line, repro)
			elif result >= 0 and (gs.fields[fid] as FieldData).kind != result and int(gs.made[result]) <= int(made0[result]):
				pb("tool_wrong_result", n, line, repro)
		if typ == "grow" and how == "named" and sum1 <= sum0 and not gs.day_won:
			pb("grow_no_progress", n, line, repro)
		if how == "gift" and sum1 <= sum0 and str(gs.held9) == held0 and not gs.day_won:
			pb("gift_no_progress", n, line, repro)
		# Schaden, während der Spieler tat, was die Zeile sagte
		if how == "named" or how == "tool":
			for t2 in trace:
				if GameState.DAMAGE9.has(str(t2)) and str(t2) != "goal_loss":
					damage[str(t2)] = int(damage.get(str(t2), 0)) + 1
					if not threats.is_empty() and typ != "danger":
						pb("damage_after_non_danger_line:%s" % str(t2), n, line, repro)
		# versprochenes Wachsen: nach 6 weiteren Aktionen immer noch die alte Art?
		var keep: Array = []
		for p2 in pending:
			var pa: Array = p2
			var pf: FieldData = gs.fields[int(pa[0])]
			if pf.kind != int(pa[1]):
				continue
			if acts - int(pa[3]) >= 6:
				pb("promised_growth_not_after_6", n, str(pa[4]), str(pa[5]))
				continue
			keep.append(pa)
		pending = keep
		var key := "%s|%d|%d" % [gs.slot_board9(), gs.rain, sum1]
		if how == "named" and seen.has(key) and not gs.day_won:
			revisits += 1
			pb("loop_named_move_back_to_seen_state", n, line, repro)
		seen[key] = true
		if logit:
			print("  %2d s=%2d [%s] '%s' | '%s' -> %s%s | Fortschritt %d/%d Wasser %d Ursuppe %d Regen %d%s" % [acts, gs.steps9(), typ,
				line, str(a.get("hint", "")), how, (" " + str(action)) if how != "gift" else "", gs.progress9(), gs.target9(),
				cnt(gs, W), cnt(gs, FieldData.SOUP), gs.rain, (" trace=" + str(trace)) if not trace.is_empty() else ""])
		# --- das Sicherheitsnetz ---
		if gs.day_won:
			break
		if g != null:
			var of: Dictionary = g.rescue_offer
			if not of.is_empty():
				note_offer(gs, str(of.get("why", "")), bool(of.get("gift", false)), str(of.get("line", "")), st, false)
				st["offers"] = int(st.get("offers", 0)) + 1
				if logit:
					print("     NETZ: '%s' Geschenk=%s (why=%s reach=%s)" % [str(of.get("line", "")), str(of.get("gift", false)),
						str(of.get("why", "")), str(gs.reach9())])
				if net and bool(of.get("gift", false)):
					var rg: Dictionary = do_play(gs, g, {"type": "gift"})
					st["gifts_modal"] = int(st.get("gifts_modal", 0)) + 1
					if logit:
						print("     GESCHENK: %s | Fortschritt %d/%d Wasser %d" % [str((rg.get("bonus", {}) as Dictionary).get("stages", {})),
							gs.progress9(), gs.target9(), cnt(gs, W)])
				else:
					if not bool(of.get("gift", false)):
						st["offers_nogift"] = int(st.get("offers_nogift", 0)) + 1
					g.rescue_offer = {}
		else:
			var o0 := int(st.get("offers", 0))
			var took := net_check(gs, st, net)
			if logit and int(st.get("offers", 0)) > o0:
				print("     NETZ: '%s' angenommen=%s | Fortschritt %d/%d Wasser %d reach=%s" % [gs.rescue_line9(gs.stuck9()) if not took else "(Geschenk)",
					str(took), gs.progress9(), gs.target9(), cnt(gs, W), str(gs.reach9())])
	var steps := gs.steps9() - s0
	return {"won": gs.day_won, "steps": steps, "total_steps": gs.steps9(), "acts": acts, "blind": blind, "waits": waits,
		"named": named, "tools": tools, "gifts_line": gifts_line, "gifts_modal": int(st.get("gifts_modal", 0)),
		"offers": int(st.get("offers", 0)), "offers_nogift": int(st.get("offers_nogift", 0)), "revisits": revisits,
		"max_streak": max_streak + 1 if acts > 0 else 0, "damage": damage,
		"stars": GameState.stars_for9(gs.stars9, gs.steps9()) if gs.day_won else 0}


# --- Start-Bretter ----------------------------------------------------------------------------------

## Die Welt am Sieg von Level n auf Pool-Brett i: Tipp-Bot (how "hint", wie der Spieler mit Tipps), sonst die geprüfte
## Lösung. [gewonnen, Welt als 54 Arten nach Plätzen, wie]
func won_world(n: int, i: int, how: String) -> Array:
	var b := Campaign.board(n, i)
	var gs := Campaign.new_state(n, b)
	if how == "hint":
		var acts := 0
		while not gs.day_won and gs.steps9() <= 4 * gs.par9 and acts < 12 * gs.par9:
			acts += 1
			var a: Dictionary = gs.best_action()
			if a.is_empty():
				break
			gs.play(a)
		if gs.day_won:
			return [true, Campaign.decode(gs.slot_board9()), "hint"]
		gs = Campaign.new_state(n, b)
	for st in (b["solution"] as Array):
		if gs.day_won:
			break
		var ab: Array = Days.solution_step(st)
		gs.play(ab[0], ab[1])
	return [gs.day_won, Campaign.decode(gs.slot_board9()), "sol"]


## Wie Game._level_start_board + Campaign.ensure für einen neuen Spieler (brett[n] = 0): die Welt von gestern.
func carried_board(n: int, prev: Array) -> Dictionary:
	var c := Campaign.carry(prev, n, 1000 * n + 1, 0)
	c["board"] = Campaign.encode(c["kinds"])
	return Campaign.ensure(n, c, 0)


func median(a: Array) -> float:
	if a.is_empty():
		return -1.0
	var s := a.duplicate()
	s.sort()
	var m := s.size() / 2
	if s.size() % 2 == 1:
		return float(s[m])
	return (float(s[m - 1]) + float(s[m])) / 2.0


func ints(s: String) -> Array:
	var out: Array = []
	for x in s.split(",", false):
		out.append(int(x))
	return out


# --- mode=follow ---------------------------------------------------------------------------------------

func run_follow() -> void:
	var from := int(args.get("from", 1))
	var to := int(args.get("to", Campaign.COUNT))
	var nb := int(args.get("boards", 20))
	var pres := ints(str(args.get("pre", "0,20,60")))
	var nets := ints(str(args.get("net", "1,0")))
	var starts: Array = Array(str(args.get("start", "pool,carry")).split(",", false))
	var wh := str(args.get("world", "hint"))
	for n in range(from, to + 1):
		var par := Campaign.par_of(n)
		var boards: Array = []      # [start, idx, Dictionary]
		if starts.has("pool"):
			for i in mini(nb, Campaign.pool_size(n)):
				var pbd := Campaign.board(n, i)
				pbd["how"] = "pool"
				boards.append(["pool", i, pbd])
		var info := {"n": n, "carry": 0, "fallback": 0, "topup": 0, "world_hint": 0, "world_sol": 0, "world_fail": 0, "lines": {}}
		if starts.has("carry") and n > 1 and not Campaign.first_of_act(n):
			for i2 in mini(nb, Campaign.pool_size(n - 1)):
				var ww := won_world(n - 1, i2, wh)
				if not bool(ww[0]):
					info["world_fail"] = int(info["world_fail"]) + 1
					continue
				info["world_" + str(ww[2])] = int(info["world_" + str(ww[2])]) + 1
				var cb := carried_board(n, ww[1])
				var hw := str(cb.get("how", ""))
				info["carry" if hw == "carry" else "fallback"] = int(info["carry" if hw == "carry" else "fallback"]) + 1
				if not (cb.get("fixes", []) as Array).is_empty():
					info["topup"] = int(info["topup"]) + 1
				var ln := str(cb.get("line", ""))
				if ln != "":
					(info["lines"] as Dictionary)[ln] = int((info["lines"] as Dictionary).get(ln, 0)) + 1
				boards.append(["carry", i2, cb])
		print("ST " + JSON.stringify(info))
		var acc := {}
		for be in boards:
			var ba: Array = be
			var bd: Dictionary = ba[2]
			for pre in pres:
				var rng := RandomNumberGenerator.new()
				rng.seed = n * 100003 + int(ba[1]) * 977 + int(pre) * 13 + (7 if str(ba[0]) == "carry" else 0)
				var base := Campaign.new_state(n, bd)
				var st0 := {"repro": "mode=one n=%d start=%s board=%d pre=%d (im Vorausspielen)" % [n, str(ba[0]), int(ba[1]), int(pre)]}
				if int(pre) > 0:
					base = careless(base, null, rng, int(pre), st0)
				for net in nets:
					var ak := "%s|%d|%d" % [str(ba[0]), int(pre), int(net)]
					if not acc.has(ak):
						acc[ak] = {"n": n, "start": str(ba[0]), "pre": int(pre), "net": int(net), "runs": 0, "wins": 0, "steps": [],
							"st3": 0, "st2": 0, "st1": 0, "blind": 0, "blind_runs": 0, "waits": 0, "named": 0, "tools": 0,
							"gifts_line": 0, "gifts_modal": 0, "gift_runs": 0, "offers": 0, "offers_nogift": 0, "revisits": 0,
							"max_streak": 0, "damage": {}, "fails": [], "pre_won": 0}
					var ac: Dictionary = acc[ak]
					if bool(st0.get("pre_won", false)):
						ac["pre_won"] = int(ac["pre_won"]) + 1
						continue
					var gs := base.clone()
					var st := st0.duplicate(true)
					var rng2 := RandomNumberGenerator.new()
					rng2.seed = rng.seed + 1000003
					var rp := "mode=one n=%d start=%s board=%d pre=%d net=%d" % [n, str(ba[0]), int(ba[1]), int(pre), int(net)]
					var r := follow(gs, rng2, {"net": int(net) == 1, "budget": 4 * par, "repro": rp}, st)
					ac["runs"] = int(ac["runs"]) + 1
					if bool(r["won"]):
						ac["wins"] = int(ac["wins"]) + 1
						(ac["steps"] as Array).append(int(r["steps"]))
						var sn := GameState.stars_for9(gs.stars9, int(r["steps"]))
						var sk := "st3" if sn >= 3 else ("st2" if sn == 2 else "st1")
						ac[sk] = int(ac[sk]) + 1
					else:
						(ac["fails"] as Array).append(int(ba[1]))
						pb("not_won_in_4x_par", n, "start=%s pre=%d net=%d" % [str(ba[0]), int(pre), int(net)], rp)
					for fld in ["blind", "waits", "named", "tools", "gifts_line", "gifts_modal", "offers", "offers_nogift", "revisits"]:
						ac[fld] = int(ac[fld]) + int(r[fld])
					if int(r["blind"]) > 0:
						ac["blind_runs"] = int(ac["blind_runs"]) + 1
					if int(r["gifts_line"]) + int(r["gifts_modal"]) > 0:
						ac["gift_runs"] = int(ac["gift_runs"]) + 1
					ac["max_streak"] = maxi(int(ac["max_streak"]), int(r["max_streak"]))
					for dk in (r["damage"] as Dictionary):
						(ac["damage"] as Dictionary)[dk] = int((ac["damage"] as Dictionary).get(dk, 0)) + int((r["damage"] as Dictionary)[dk])
		for ak2 in acc:
			var a2: Dictionary = acc[ak2]
			var sw: Array = a2["steps"]
			a2["med"] = median(sw)
			a2["max"] = sw.max() if not sw.is_empty() else -1
			a2["par"] = par
			a2["s3"] = int(Campaign.stars_of(n)[0])
			a2["s2"] = int(Campaign.stars_of(n)[1])
			a2.erase("steps")
			print("LV " + JSON.stringify(a2))
		flush(n)


func flush(n: int) -> void:
	if texts.has(n):
		for key in (texts[n] as Dictionary):
			print("TX " + JSON.stringify((texts[n] as Dictionary)[key]))
		texts.erase(n)
	if offers.has(n):
		for key2 in (offers[n] as Dictionary):
			print("OF " + JSON.stringify((offers[n] as Dictionary)[key2]))
		offers.erase(n)
	var gone: Array = []
	for key3 in problems:
		if int((problems[key3] as Dictionary)["n"]) == n:
			print("PB " + JSON.stringify(problems[key3]))
			gone.append(key3)
	for k in gone:
		problems.erase(k)


# --- mode=one: ein Lauf zum Nachstellen (mit Protokoll) --------------------------------------------------

func run_one() -> void:
	var n := int(args.get("n", 6))
	var start := str(args.get("start", "pool"))
	var bi := int(args.get("board", 1))
	var pre := int(args.get("pre", 0))
	var net := int(args.get("net", 1))
	var bd: Dictionary = {}
	if start == "pool":
		bd = Campaign.board(n, bi)
	else:
		var ww := won_world(n - 1, bi, str(args.get("world", "hint")))
		bd = carried_board(n, ww[1])
		print("Welt von gestern (%s): %s -> how=%s line='%s' fixes=%s" % [str(ww[2]), Campaign.encode(ww[1]), str(bd.get("how", "")),
			str(bd.get("line", "")), str(bd.get("fixes", []))])
	var rng := RandomNumberGenerator.new()
	rng.seed = n * 100003 + bi * 977 + pre * 13 + (7 if start == "carry" else 0)
	var gs := Campaign.new_state(n, bd)
	var st := {}
	if pre > 0:
		gs = careless(gs, null, rng, pre, st)
	print("Start n=%d %s#%d pre=%d: Brett %s Wasser %d reach=%s" % [n, start, bi, pre, gs.slot_board9(), cnt(gs, W), str(gs.reach9())])
	if bool(st.get("pre_won", false)):
		print("Im Vorausspielen schon gewonnen.")
		return
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = rng.seed + 1000003
	var r := follow(gs, rng2, {"net": net == 1, "budget": int(args.get("budget", 4 * gs.par9)), "repro": "one", "log": str(args.get("log", "1")) == "1"}, st)
	print("Ergebnis: %s" % str(r))
	flush(n)


# --- mode=chain: ein neuer Spieler von Level 1 bis 60, die eigene Welt läuft weiter -------------------------

func run_chain() -> void:
	var seeds := int(args.get("seeds", 4))
	var pres := ints(str(args.get("pre", "0,20,60")))
	var to := int(args.get("to", Campaign.COUNT))
	var from_seed := int(args.get("seed0", 1))
	for pre in pres:
		for sd in range(from_seed, from_seed + seeds):
			var world: Array = []
			var rng := RandomNumberGenerator.new()
			rng.seed = sd * 7919 + int(pre)
			for n in range(1, to + 1):
				var bd: Dictionary = {}
				if n == 1:
					bd = Campaign.board(1, 0)
					bd["how"] = "pool"
				elif Campaign.first_of_act(n) or world.size() != 54:
					bd = Campaign.board(n, 1)
					bd["how"] = "pool"
				else:
					bd = carried_board(n, world)
				var gs := Campaign.new_state(n, bd)
				var w0 := cnt(gs, W)
				var reach0 := bool(gs.reach9()["ok"])
				var st := {}
				if int(pre) > 0:
					gs = careless(gs, null, rng, int(pre), st)
				var w1 := cnt(gs, W)
				var rp := "chain seed=%d pre=%d n=%d" % [sd, int(pre), n]
				var r := follow(gs, rng, {"net": true, "budget": 4 * gs.par9, "repro": rp}, st)
				var late := false
				if not bool(r["won"]):
					pb("chain_not_won_in_4x_par", n, "pre=%d how=%s" % [int(pre), str(bd.get("how", ""))], rp + " startbrett=" + Campaign.encode(bd["kinds"]))
					var r2 := follow(gs, rng, {"net": true, "budget": 12 * gs.par9, "repro": rp + " (weiter)"}, st)
					late = bool(r2["won"])
				print("CH " + JSON.stringify({"seed": sd, "pre": int(pre), "n": n, "how": str(bd.get("how", "")), "line": str(bd.get("line", "")),
					"fixes": (bd.get("fixes", []) as Array).size(), "water0": w0, "water_pre": w1, "water_end": cnt(gs, W),
					"reach0": reach0, "won": bool(r["won"]), "late": late, "steps": int(r["steps"]), "stars": int(r["stars"]),
					"blind": int(r["blind"]), "waits": int(r["waits"]), "gifts_line": int(r["gifts_line"]),
					"gifts_modal": int(r["gifts_modal"]), "offers": int(r["offers"]), "par": gs.par9}))
				if gs.day_won:
					world = Campaign.decode(gs.slot_board9())
				else:
					world = []           # „Neue Welt“: morgen ein Pool-Brett
	for n2 in range(1, to + 1):
		flush(n2)


# --- mode=water: Level, deren Ziel-Kette Wasser braucht, mit wenig oder ohne Wasser --------------------------

## Braucht die Ziel-Kette von Level n Wasser? "kind": Wasser wird selbst zu etwas (Reihe, Gedeihen, Regen),
## "wet": eine Art der Kette braucht Wasser-Nachbarn, "": nein.
func water_role(n: int) -> String:
	var gs := Campaign.new_state(n, Campaign.board(n, 1))
	var out: Array = []
	if gs.chain9.has(W):
		out.append("kind")
	for k in gs.thrive9:
		var r: Dictionary = gs.thrive9[k]
		if (r["needs"] as Dictionary).has("wet") and (gs.chain9.has(int(k)) or gs._act_satt_goal9(int(k))):
			out.append("wet")
			break
	return "+".join(PackedStringArray(out))


func mk_game(path: String) -> Node:
	for p in [path, path.get_basename() + "_lauf.cfg"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	var g: Node = GameScript.new()
	g.save_path = path
	g.reminder_echo = false
	g.clock_override = t_now
	g._load_best()
	return g


func set_progress(g: Node, n: int, world: String) -> void:
	g.camp = GameScript.fresh_camp()
	var k: int = g.today_key()
	for i in n - 1:
		(g.camp["stars"] as Array)[i] = 1
		(g.camp["won_key"] as Array)[i] = k - 1
	g.camp["pos"] = n - 1
	g.camp["last_new_key"] = k - 1
	g.camp["world"] = world
	g.camp["world_level"] = n - 1 if world.length() == 54 else 0
	g._clear_run()


## Pool-Brett 1 von Level n, alles Wasser bis auf keep Felder durch die häufigste Land-Art der Mischung ersetzt.
func dry_board(n: int, keep: int, fill: int = -1) -> Array:
	var kinds: Array = (Campaign.board(n, 1)["kinds"] as Array).duplicate()
	var c := {}
	for k in kinds:
		if not FieldData.water_family(int(k)):
			c[int(k)] = int(c.get(int(k), 0)) + 1
	var rep := fill
	if rep < 0:
		var best := -1
		for k2 in c:
			if int(c[k2]) > best:
				best = int(c[k2])
				rep = int(k2)
	var left := keep
	for i in kinds.size():
		if int(kinds[i]) == W:
			if left > 0:
				left -= 1
			else:
				kinds[i] = rep
	return kinds


func run_water() -> void:
	var lvs: Array = []
	if args.has("levels"):
		lvs = ints(str(args["levels"]))
	else:
		for n in range(1, Campaign.COUNT + 1):
			if water_role(n) != "":
				lvs.append(n)
	var roles := {}
	for n0 in range(1, Campaign.COUNT + 1):
		roles[n0] = water_role(n0)
	print("WR " + JSON.stringify(roles))
	var keeps := ints(str(args.get("keep", "0,1,2,3")))
	var verbose := str(args.get("verbose", "0")) == "1"
	var paths: Array = Array(str(args.get("paths", "carry,stored,raw")).split(",", false))
	for n in lvs:
		for keep in keeps:
			for path in paths:
				var kinds := dry_board(n, int(keep), int(args.get("fill", -1)))
				var board := Campaign.encode(kinds)
				var g: Node = null
				var gs: GameState = null
				var how := ""
				var oline := ""
				var fixes := 0
				if str(path) == "raw":
					# mitten im Level (z. B. ein fortgesetzter Lauf): kein Campaign.ensure
					g = mk_game("user://audit_hud_w.cfg")
					set_progress(g, n, "")
					g.start_level(n)
					g.state = Campaign.new_state(n, {"kinds": kinds, "seed": 1})
					gs = g.state
					how = "raw"
				elif str(path) == "carry":
					if Campaign.first_of_act(n):
						continue
					g = mk_game("user://audit_hud_w.cfg")
					set_progress(g, n, board)
					g.start_level(n)
					gs = g.state
					how = str(g.level_board.get("how", ""))
					oline = str((g.overnight as Dictionary).get("line", ""))
					fixes = (g.level_board.get("fixes", []) as Array).size()
				else:
					g = mk_game("user://audit_hud_w.cfg")
					set_progress(g, n, "")
					g.camp["start"] = board
					g.camp["start_level"] = n
					g.camp["start_seed"] = 1
					g.start_level(n)
					gs = g.state
					how = str(g.level_board.get("how", ""))
					oline = str((g.overnight as Dictionary).get("line", ""))
					fixes = (g.level_board.get("fixes", []) as Array).size()
				var a0: Dictionary = gs.next_action()
				var w_start := cnt(gs, W)
				var reach0 := gs.reach9()
				var head := {"n": n, "title": str(Campaign.config(n).get("title", "")), "role": str(roles[n]), "keep": int(keep),
					"path": str(path), "how": how, "overnight": oline, "fixes": fixes, "water_in": int(keep), "water_start": w_start,
					"reach_ok": bool(reach0["ok"]), "reach": str(reach0), "stuck": gs.stuck9(), "dead9": gs.dead9(),
					"gift": not gs.gift_plan9().is_empty(), "hud": str(a0.get("line", "")), "hud_type": str(a0.get("type", "")),
					"hint": str(a0.get("hint", "")), "goal": str(Campaign.config(n).get("goal_line", "")), "board_in": board}
				var rng := RandomNumberGenerator.new()
				rng.seed = n * 31 + int(keep)
				var st := {}
				if verbose:
					print("WA-START " + JSON.stringify(head))
				var r := follow(gs, rng, {"net": true, "budget": 4 * gs.par9, "repro": "water n=%d keep=%d path=%s" % [n, int(keep), str(path)],
					"log": verbose, "g": g}, st)
				head.merge({"won": bool(r["won"]), "steps": int(r["steps"]), "blind": int(r["blind"]), "waits": int(r["waits"]),
					"gifts_line": int(r["gifts_line"]), "gifts_modal": int(r["gifts_modal"]), "offers": int(r["offers"]),
					"offers_nogift": int(r["offers_nogift"]), "water_end": cnt(gs, W), "par": gs.par9, "max_streak": int(r["max_streak"])})
				print("WA " + JSON.stringify(head))
				g.free()
		flush(n)


# --- mode=static: die Zeile am Start jedes Levels und alle festen Texte des Netzes ---------------------------

func run_static() -> void:
	for n in range(1, Campaign.COUNT + 1):
		var c := Campaign.config(n)
		for i in [0, 1]:
			var gs := Campaign.new_state(n, Campaign.board(n, i))
			var a: Dictionary = gs.next_action()
			print("S0 " + JSON.stringify({"n": n, "board": i, "title": str(c.get("title", "")), "goal": str(c.get("goal_line", "")),
				"new": c.get("new", []), "coach": str(c.get("coach", "")), "type": str(a.get("type", "")), "line": str(a.get("line", "")),
				"text": str(a.get("text", "")), "hint": str(a.get("hint", "")), "move": not (a.get("move", {}) as Dictionary).is_empty(),
				"rain": gs.rain, "rain_every": gs.rain_every}))
	for key in ["rescue_dead", "rescue_few", "rescue_stall", "rescue_rows", "gift", "new_world", "play_on", "topup", "fresh",
			"calmer", "calmer_ice", "overnight", "overnight_line"]:
		print("S1 %s = '%s' (%d Zeichen)" % [key, str(Campaign.TEXT[key]), str(Campaign.TEXT[key]).length()])


# --- mode=probe: ein Pool-Brett mit ausgetauschten Arten (set=von>zu,…) und festem Regen: was sagt die Zeile? -------

func run_probe() -> void:
	var n := int(args.get("n", 8))
	var bd := Campaign.board(n, int(args.get("board", 1)))
	var kinds: Array = (bd["kinds"] as Array).duplicate()
	for pair in str(args.get("set", "")).split(",", false):
		var ft := str(pair).split(">")
		if ft.size() != 2:
			continue
		for i in kinds.size():
			if int(kinds[i]) == int(ft[0]):
				kinds[i] = int(ft[1])
	var gs := Campaign.new_state(n, {"kinds": kinds, "seed": int(bd.get("seed", 1))})
	if args.has("rain"):
		gs.rain = int(args["rain"])
	var a: Dictionary = gs.next_action()
	print("PROBE n=%d set=%s regen=%d Wasser=%d Ursuppe=%d | reach=%s stuck='%s' dead9=%s Geschenk=%s | Zeile [%s] '%s' || '%s' | Zug=%s" % [n,
		str(args.get("set", "")), gs.rain, cnt(gs, W), cnt(gs, FieldData.SOUP), str(gs.reach9()), gs.stuck9(), str(gs.dead9()),
		str(gs.gift_plan9()), str(a.get("type", "")), str(a.get("line", "")), str(a.get("hint", "")), str(a.get("move", {}))])
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var r := follow(gs, rng, {"net": str(args.get("net", "1")) == "1", "budget": int(args.get("steps", 4 * gs.par9)), "repro": "probe", "log": true}, {})
	print("Ergebnis: %s" % str(r))
