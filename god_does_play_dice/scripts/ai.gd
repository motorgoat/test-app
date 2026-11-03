class_name AIPlayer
extends RefCounted
## Einfache regelbasierte KI (GDD Kap. 14). Arbeitet nur auf GameState, nie auf Szenen-Knoten.

## Ein KI-Zug für Spieler pid. Gibt zurück:
## {"log": Array[String], "rotation": {} oder {"axis", "layer", "turns"}}
static func act(gs: GameState, pid: int, already_queued: bool = false) -> Dictionary:
	var notes: Array = []
	var pl: PlayerData = gs.players[pid]

	# 1. Zentrum ausbauen, wenn möglich
	if gs.stage_up_error(pid) == "":
		gs.stage_up(pid)
		notes.append("baut %s" % Balance.STAGE_NAMES[pl.stage])

	# 2. Bewohner kaufen, wenn keiner frei ist (Gold für den nächsten Ausbau zurückhalten)
	if pl.residents == 0 and gs.resident_price(pid) <= _spendable(gs, pid) and gs.buy_resident_error(pid) == "":
		gs.buy_resident(pid)
		notes.append("kauft Bewohner")

	# 3. Bis zu 2 Feld-Ausbauten, bevorzugt der Rohstoff, der für den nächsten Ausbau fehlt
	for i in Balance.AI_MAX_FIELD_UPGRADES:
		var best: FieldData = null
		var best_score := -1.0
		var need := _need_weights(gs, pid)
		for f in gs.fields:
			if f.owner != pid or f.is_center:
				continue
			if gs.upgrade_error(pid, f) != "":
				continue
			var cost := GameState.upgrade_cost(f.level + 1)
			if int(cost.get("gold", 0)) > _spendable(gs, pid):
				continue
			var res: String = GameState.TERRAIN_RES[f.terrain]
			var score: float = float(need.get(res, 1.0)) * 10.0 - f.level
			if not f.roads.is_empty():
				score += 3.0
			if score > best_score:
				best_score = score
				best = f
		if best == null:
			break
		gs.upgrade_field(pid, best)
		notes.append("baut %s aus" % GameState.TERRAIN_NAME[best.terrain])

	# 4. Ein angrenzendes freies Feld kaufen, wenn genug Gold übrig ist
	var buy_target: FieldData = null
	var buy_score := -1.0
	for f in gs.fields:
		if f.owner != -1 or f.is_center:
			continue
		if gs.buy_field_error(pid, f) != "":
			continue
		if gs.field_price(pid, f) > _spendable(gs, pid):
			continue
		var res: String = GameState.TERRAIN_RES[f.terrain]
		var s: float = float(_need_weights(gs, pid).get(res, 1.0)) + f.level * 2.0
		if s > buy_score:
			buy_score = s
			buy_target = f
	if buy_target != null:
		gs.buy_field(pid, buy_target)
		notes.append("kauft ein Feld")

	# 5. Ab Marktplatz Überschuss tauschen
	if pl.stage >= Balance.MARKET_STAGE:
		var traded := _trade_surplus(gs, pid)
		if traded != "":
			notes.append(traded)

	# 6./7. Straßen und Angriffe: Projekt-Stufe 2 (siehe README)

	# 8. Drehung simulieren und vormerken
	var rot := {}
	if pl.rotations > 0 and not already_queued:
		rot = best_rotation(gs, pid)
		if not rot.is_empty():
			pl.rotations -= 1
			notes.append("merkt eine Drehung vor")

	return {"log": notes, "rotation": rot}


## Gold, das die KI ausgeben darf: ungefähr die Hälfte wird für den nächsten Zentrum-Ausbau zurückgehalten.
static func _spendable(gs: GameState, pid: int) -> int:
	var pl: PlayerData = gs.players[pid]
	var gold := int(pl.inv.get("gold", 0))
	var next := GameState.stage_cost(pl.stage + 1)
	if next.is_empty():
		return gold
	var reserve := mini(int(gold * Balance.AI_GOLD_RESERVE), int(int(next.get("gold", 0)) * Balance.AI_GOLD_RESERVE))
	return gold - reserve


## Wie dringend braucht die KI welchen Rohstoff? Fehlt etwas für den nächsten Ausbau, zählt es dreifach.
static func _need_weights(gs: GameState, pid: int) -> Dictionary:
	var pl: PlayerData = gs.players[pid]
	var w := {"gold": 1.0, "wood": 1.3, "stone": 1.1, "food": 0.6}
	var next := GameState.stage_cost(pl.stage + 1)
	for k in next:
		if int(pl.inv.get(k, 0)) < int(next[k]):
			w[k] = float(w.get(k, 1.0)) * 3.0
	if int(pl.inv.get("wood", 0)) < 4:
		w["wood"] = float(w["wood"]) * 2.0
	return w


static func _trade_surplus(gs: GameState, pid: int) -> String:
	var pl: PlayerData = gs.players[pid]
	var next := GameState.stage_cost(pl.stage + 1)
	if next.is_empty():
		return ""
	var want := ""
	var want_lack := 0
	for k in next:
		var lack: int = int(next[k]) - int(pl.inv.get(k, 0))
		if lack > want_lack:
			want_lack = lack
			want = k
	if want == "":
		return ""
	for give in GameState.RES_KEYS:
		if give == want:
			continue
		var keep: int = int(next.get(give, 0)) + Balance.AI_MARKET_KEEP
		if int(pl.inv.get(give, 0)) - Balance.TRADE_RATE >= keep and gs.trade_error(pid, give, want) == "":
			gs.trade(pid, give, want)
			return "tauscht %s gegen %s" % [GameState.RES_NAME[give], GameState.RES_NAME[want]]
	return ""


## Alle 9 Scheiben × 3 Richtungen auf einer Kopie simulieren.
## Bewertung: eigener Ertrag − 0,7 × Ertrag des menschlichen Spielers.
static func best_rotation(gs: GameState, pid: int) -> Dictionary:
	var base := _rot_score(gs, pid)
	var best := {}
	var best_score := base + Balance.AI_ROTATION_MIN_GAIN
	for axis in 3:
		for layer in [-1, 0, 1]:
			for turns in [1, -1, 2]:
				var sim := gs.clone()
				sim.apply_rotation(axis, layer, turns)
				var sc := _rot_score(sim, pid)
				if sc > best_score:
					best_score = sc
					best = {"axis": axis, "layer": layer, "turns": turns}
	return best


static func _rot_score(gs: GameState, pid: int) -> float:
	var own := gs.income_value(pid) + gs.territory(pid) * 0.5
	var human := gs.income_value(GameState.HUMAN) + gs.territory(GameState.HUMAN) * 0.5
	return own - Balance.AI_ROTATION_HUMAN_WEIGHT * human
