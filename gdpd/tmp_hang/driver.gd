extends Node
## TEMP hang hunter (remove afterwards). Drives main.tscn with real input through days -> win -> Weiterbauen.

var main: Node
var world: World
var ui: GameUI
var dui: DayUI
var step := "start"
var _last_us := 0
var max_ms := 0.0
var max_step := ""
var slow: Array = []
var hangs: Array = []
var frames := 0
var rng := RandomNumberGenerator.new()
var days_arg: Array = [1, 2, 3, 4, 5, 6, 7]
var build_moves := 40


func _ready() -> void:
	rng.seed = 4242
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days_arg = []
			for s in a.substr(7).split(","):
				days_arg.append(int(s))
		if a.begins_with("--moves="):
			build_moves = int(a.substr(8))
		if a.begins_with("--seed="):
			rng.seed = int(a.substr(7))
	get_tree().root.size = Vector2i(540, 960)
	Game.set_character(Character.default_look())
	var ps: PackedScene = load("res://main.tscn")
	main = ps.instantiate()
	add_child(main)
	world = main.world
	ui = main.ui
	dui = ui.day_ui
	dui.debug_ask_on_pc = true
	_last_us = Time.get_ticks_usec()
	_run()


func _process(_d: float) -> void:
	frames += 1
	var now := Time.get_ticks_usec()
	var ms := float(now - _last_us) / 1000.0
	_last_us = now
	if frames > 30 and ms > max_ms:
		max_ms = ms
		max_step = step
	if frames > 30 and ms > 250.0:
		slow.append("%.0fms @ %s" % [ms, step])
		print("SLOW FRAME %.0f ms @ %s" % [ms, step])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _touch(p: Vector2, hold: float = 0.08) -> void:
	var wp: Vector2 = get_tree().root.get_final_transform() * p
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = wp
	t.pressed = true
	Input.parse_input_event(t)
	await get_tree().process_frame
	await get_tree().process_frame
	await _wait(hold)
	var r := InputEventScreenTouch.new()
	r.index = 0
	r.position = wp
	r.pressed = false
	Input.parse_input_event(r)
	await get_tree().process_frame
	await get_tree().process_frame


func _tap(c: Control) -> void:
	await _touch(c.get_global_rect().get_center())


func _until_shown(c: Control, sec: float) -> bool:
	var t := 0.0
	while t < sec:
		if c.visible and c.modulate.a > 0.98:
			return true
		await _wait(0.05)
		t += 0.05
	return false


func _idle() -> bool:
	return not Game.busy and not world.animating and world._mode == "" and not Game.has_choice() and ui._queued_tap < 0


func dump(tag: String) -> String:
	var s := "%s: busy=%s anim=%s mode='%s' choice=%s queued=%d over=%s in_day=%s playing=%s modal_bg=%s(a=%.2f) modal=%s blocking=%s locked=%s bonus_mode='%s' free=%s twists=%d" % [
		tag, str(Game.busy), str(world.animating), world._mode, str(Game.has_choice()), ui._queued_tap, str(Game.over),
		str(Game.in_day()), str(dui._playing), str(ui.modal_bg.visible), ui.modal_bg.modulate.a,
		str(ui._modal.name if ui._modal != null else "null"), str(dui.blocking()), str(ui.input_locked()), ui.bonus_mode,
		str(Game.state.day_free_build if Game.state != null else false), Game.state.twists if Game.state != null else -1]
	return s


## Wait until idle; answers choice cards via real taps.
func _settle(sec: float, pick: int = 0) -> bool:
	var t0 := Time.get_ticks_msec()
	var t := 0.0
	while t < sec:
		if Game.has_choice() and ui.choice_card.visible and ui.choice_card.modulate.a > 0.98:
			await _wait(0.3)
			if Game.has_choice():
				await _touch((ui.choice_btns[pick] as Control).get_global_rect().get_center())
		if _idle():
			await _wait(0.25)
			if _idle():
				return true
		await _wait(0.1)
		t += 0.1
	var msg := dump("SOFT HANG after %s (%.1fs game, %d ms real)" % [step, sec, Time.get_ticks_msec() - t0])
	print(msg)
	hangs.append(msg)
	return false


func _swipe(a: Vector2, b: Vector2) -> void:
	var tf: Transform2D = get_tree().root.get_final_transform()
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = tf * a
	t.pressed = true
	Input.parse_input_event(t)
	await get_tree().process_frame
	var last := tf * a
	var steps := 4
	for i in range(1, steps + 1):
		var p: Vector2 = tf * a.lerp(b, float(i) / float(steps))
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = p
		d.relative = p - last
		d.velocity = (p - last) * 60.0
		last = p
		Input.parse_input_event(d)
		await get_tree().process_frame
	await _wait(0.06)
	var r := InputEventScreenTouch.new()
	r.index = 0
	r.position = tf * b
	r.pressed = false
	Input.parse_input_event(r)
	await get_tree().process_frame
	await get_tree().process_frame


func _under_ui(pos: Vector2) -> bool:
	var rects: Array = [ui.dock.get_global_rect().grow(12.0), ui.top.get_global_rect().grow(12.0)]
	for c in [ui.mode_card, ui.toast, ui.tip_card, ui.coach, ui.day_ui.lane]:
		var cc: Control = c
		if cc.visible:
			rects.append(cc.get_global_rect().grow(12.0))
	for r in rects:
		if (r as Rect2).has_point(pos):
			return true
	return false


func _swipe_candidate(axis: int, layer: int, turns: int) -> Dictionary:
	var cam := world.rig.cam
	var vs := get_viewport().get_visible_rect().size
	var mid := vs * Vector2(0.5, 0.47)
	var best := {}
	var best_d := INF
	var why := {}
	for f in Game.state.fields:
		var fd: FieldData = f
		var na := GameState.axis_of(fd.n)
		if na == axis or fd.p[axis] != layer:
			continue
		var fs := world.field_screen(fd.id)
		if not bool(fs["visible"]):
			why["unsichtbar"] = int(why.get("unsichtbar", 0)) + 1
			continue
		var v: FieldView = world.views.get(fd.id)
		var pos: Vector2 = cam.unproject_position(v.global_position + v.world_normal() * 0.1)
		if _under_ui(pos):
			why["ui"] = int(why.get("ui", 0)) + 1
			continue
		var hit: Dictionary = world._raycast(pos)
		if int(hit.get("field", -1)) != fd.id:
			why["verdeckt"] = int(why.get("verdeckt", 0)) + 1
			continue
		var hp: Vector3 = hit["point"]
		var s0 := cam.unproject_position(hp)
		var a := 3 - na - axis
		var tt := GameState.unit(a, 1)
		var st := cam.unproject_position(hp + Vector3(tt) * 0.5) - s0
		if st.length() < 10.0:
			why["schraeg"] = int(why.get("schraeg", 0)) + 1
			continue
		var k := Vector3(fd.n).cross(Vector3(tt))
		var sgn := 1.0 if k[axis] > 0.0 else -1.0
		var pxq := maxf(40.0, st.length() * 2.0 * Balance.TWIST_FINGER_UNITS)
		for q in ([turns] if absi(turns) != 2 else [2, -2]):
			var qq := int(q)
			var along := (float(absi(qq)) - 0.3) * signf(float(qq)) * pxq * sgn
			var drag := st.normalized() * along
			var to := pos + drag
			if to.x < 12.0 or to.x > vs.x - 12.0 or to.y < ui._insets.x + 100.0 or to.y > vs.y - 12.0 or _under_ui(to):
				why["rand"] = int(why.get("rand", 0)) + 1
				continue
			var dd := pos.distance_to(mid) + (pos + drag * 0.5).distance_to(mid) * 0.5
			if dd < best_d:
				best_d = dd
				best = {"from": pos, "to": to}
	if best.is_empty():
		print("no spot why=%s vs=%s" % [str(why), str(vs)])
	return best


func _swipe_move(axis: int, layer: int, turns: int) -> bool:
	for i in 60:
		if world._mode == "" and not world.animating and not Game.busy:
			break
		await _wait(0.05)
	var faces: Array = []
	for vn in [Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, -1), Vector3i(0, -1, 0)]:
		var vv: Vector3i = vn
		if vv[axis] == 0:
			faces.append(vv)
	for attempt in 3:
		var cand := _swipe_candidate(axis, layer, turns)
		if not cand.is_empty():
			await _swipe(cand["from"], cand["to"])
			return true
		world.focus_place(faces[attempt % faces.size()])
		await _wait(1.1)
	print("WARN no swipe spot %d/%d/%d" % [axis, layer, turns])
	return false


func _timed_best() -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var act := Game.state.best_action()
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	_last_us += Time.get_ticks_usec() - t0
	if ms > 1500.0:
		print("best_action took %.0f ms (%s)" % [ms, step])
	return act


func _tool_on_field(btn: Button, fid: int) -> void:
	await _tap(btn)
	await _wait(0.2)
	var fs := world.field_screen(fid)
	if bool(fs["visible"]):
		await _touch(fs["pos"])
	else:
		world.focus_field(fid)
		await _wait(1.0)
		fs = world.field_screen(fid)
		await _touch(fs["pos"])
	await _wait(0.2)
	if ui.bonus_mode != "":
		# cancel tool mode by tapping the button again
		await _tap(btn)


func _play_one(act: Dictionary) -> void:
	var typ := str(act.get("type", "twist"))
	if typ == "rain" and Game.state.rain > 0:
		await _tool_on_field(ui.rain_btn, int(act["field"]))
	elif typ == "strike":
		await _tool_on_field(ui.strike_btn, int(act["field"]))
	elif not act.is_empty() and typ == "twist":
		await _swipe_move(int(act["axis"]), int(act["layer"]), int(act["turns"]))
	else:
		await _swipe_move(rng.randi_range(0, 2), rng.randi_range(-1, 1), [1, -1][rng.randi_range(0, 1)])


func _run() -> void:
	await _wait(1.0)
	await get_tree().process_frame
	# first launch: goal card of day 1 probably
	for d in days_arg:
		await _day(int(d))
	print("=== DONE frames=%d max_frame=%.0fms @ %s" % [frames, max_ms, max_step])
	print("HANGS: %d" % hangs.size())
	for h in hangs:
		print("  " + str(h))
	print("SLOW: %d" % slow.size())
	for s in slow.slice(0, 40):
		print("  " + str(s))
	get_tree().quit()


func _day(n: int) -> void:
	step = "start day %d" % n
	print("--- " + step)
	ui._close_modal(true)
	if n > 1:
		Game.debug_next_day()
	if Game.in_day() and Game.day_no == n and not Game.state.day_won and dui.goal_card.visible:
		pass
	elif not Game.start_day(n):
		print("could not start day %d" % n)
		return
	var gc := await _until_shown(dui.goal_card, 5.0)
	if gc:
		await _tap(dui.gc_go)
	await _wait(0.6)
	# tutorial lock on day 1
	var t := 0.0
	while ui.input_locked() and t < 20.0:
		await _wait(0.2)
		t += 0.2
	await _settle(15.0)
	for i in 30:
		if Game.state.day_won or Game.over or not Game.in_day():
			break
		step = "day %d win-move %d" % [n, i]
		var act := _timed_best()
		await _play_one(act)
		await _settle(15.0)
	step = "day %d win card" % n
	if not Game.state.day_won:
		print("day %d not won (lost=%s), skip" % [n, Game.state.day_lost])
		return
	var wc := await _until_shown(dui.win_card, 6.0)
	await _wait(3.0)
	print("win card shown=%s next=%s act=%s" % [str(wc), dui.wc_next.text, str(dui.wc_next.get_meta("act", "?"))])
	step = "day %d tap Weiterbauen" % n
	var bb: Button = dui.wc_next if str(dui.wc_next.get_meta("act", "")) == "build" else dui.wc_alt
	print("tapping %s (%s)" % [bb.text, str(bb.get_meta("act", ""))])
	await _tap(bb)
	await _wait(0.5)
	if dui.ask_card.visible:
		print("ask card visible -> yes (permission)")
		await _wait(0.6)
		await _tap(dui.ask_yes)
		# simulate the Android permission dialog: focus out / pause / resume / focus in
		get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		await _wait(0.5)
		get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		await _wait(0.8)
	await _wait(1.0)
	print(dump("after Weiterbauen"))
	if not Game.state.day_free_build:
		print("NOT in free build! act=%s" % str(dui.wc_next.get_meta("act", "?")))
		if not Game.continue_build():
			return
	await _build(n)


func _build(n: int) -> void:
	var extras := 0
	for i in build_moves:
		step = "day %d build move %d" % [n, i]
		if not _idle() or dui.blocking():
			print(dump("not idle before " + step))
		var r := rng.randf()
		var lvl0 := Game.state.extra_level
		if r < 0.45:
			var act := _timed_best()
			await _play_one(act)
		elif r < 0.7:
			await _swipe_move(rng.randi_range(0, 2), rng.randi_range(-1, 1), [1, -1, 2][rng.randi_range(0, 2)])
		elif r < 0.75:
			step += " hint"
			await _tap(ui.hint_btn)
			await _wait(1.5)
			var act2 := _timed_best()
			await _play_one(act2)
		elif r < 0.8:
			step += " menu"
			await _tap(ui.menu_b)
			await _until_shown(ui.menu_card, 3.0)
			await _wait(0.3)
			# close by tapping the backdrop outside the card
			var rr := ui.menu_card.get_global_rect()
			await _touch(Vector2(rr.get_center().x, maxf(20.0, rr.position.y * 0.5)))
			await _wait(0.6)
			if ui.modal_bg.visible:
				print(dump("menu still open after backdrop tap"))
				ui._close_modal(true)
		elif r < 0.85:
			step += " pause-resume"
			get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)
			await _wait(0.3)
			get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_RESUMED)
			get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
			await _wait(0.3)
			var act3 := _timed_best()
			await _play_one(act3)
		elif r < 0.9:
			step += " focus-mid-swipe"
			# press, drag a bit, lose focus (no release), then continue
			var act4 := _timed_best()
			if str(act4.get("type", "")) == "twist":
				var cand := _swipe_candidate(int(act4["axis"]), int(act4["layer"]), int(act4["turns"]))
				if not cand.is_empty():
					var tf: Transform2D = get_tree().root.get_final_transform()
					var t := InputEventScreenTouch.new()
					t.index = 0
					t.position = tf * (cand["from"] as Vector2)
					t.pressed = true
					Input.parse_input_event(t)
					await get_tree().process_frame
					var dd := InputEventScreenDrag.new()
					dd.index = 0
					dd.position = tf * (cand["from"] as Vector2).lerp(cand["to"], 0.6)
					dd.relative = dd.position - t.position
					Input.parse_input_event(dd)
					await get_tree().process_frame
					await get_tree().process_frame
					get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
					await _wait(0.5)
					get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
					await _wait(0.5)
		else:
			step += " rapid double swipe"
			var act5 := _timed_best()
			if str(act5.get("type", "")) == "twist":
				var cand2 := _swipe_candidate(int(act5["axis"]), int(act5["layer"]), int(act5["turns"]))
				if not cand2.is_empty():
					await _swipe(cand2["from"], cand2["to"])
					await _wait(0.05)
					await _swipe(cand2["from"], cand2["to"])     # during the round animation
		var ok := await _settle(20.0, rng.randi_range(0, 1))
		if Game.state.extra_level != lvl0:
			extras += 1
			print("extra done -> level %d/%d" % [Game.state.extra_level, Game.state.extra_max()])
		if not ok:
			# try to see whether it ever recovers
			var rec := await _settle(40.0)
			print("recovered=%s" % str(rec))
			if not rec:
				return
		await _wait(rng.randf_range(0.0, 1.5))
		# input-accepted check: a tap on a visible field must not be blocked by an invisible control
		if dui.blocking() or ui.modal_bg.visible:
			print(dump("blocking after " + step))
	print("day %d build done: twists=%d extras=%d growth=%d" % [n, Game.state.twists, extras, Game.state.build_growth()])
