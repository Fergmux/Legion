extends GdUnitTestSuite
## M5 (owner feedback 2026-11-09): "When curse is applied to a unit with a buff the animation ordering
## is weird" -> "Curse first, then buffs fade." The rules emit the Curse application, then one
## "status_expire" per cleared Buff, then the Curse's own expiry when its stack is spent; FxPlayer plays
## the Curse look and sound first, the cleared statuses only after its badge has landed
## (FxStatus.CLEAR_LEAD), one by one, the spent Curse last. Cleanse clearing Debuffs is the mirror.
## Batches come from the real rules engine (MatchView.log_for), as the screen sees them.


func _batch(m: MatchEngine, viewer: int, since: int) -> Array:
	var out := []
	for row in MatchView.log_for(m, viewer, since):
		for f in row["fx"]:
			out.append(f)
	return out


func _since(m: MatchEngine) -> int:
	return int(m.log_entries[-1]["seq"])


func _screen() -> GameScreen:
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	return gs


func _kinds(evs: Array) -> Array:
	return evs.filter(func(e): return String(e["k"]).begins_with("status")).map(
		func(e): return "%s:%s" % [e["k"], e.get("s", "")])


## [[tag, t]] of the plan entries whose tag starts with one of `prefixes`, in plan order.
func _plan(plan: Array, prefixes: Array) -> Array:
	var out := []
	for s in plan:
		for p in prefixes:
			if String(s["tag"]).begins_with(p):
				out.append([String(s["tag"]), float(s["t"])])
				break
	return out


## A unit with `start` statuses gains one stack of `ward`; returns [rules events, the unit's statuses].
func _ward_batch(start: Dictionary, ward: String) -> Array:
	var m := TB.make()
	var u := TB.unit(m, 1, TB.FILLER, 0)
	for s in start:
		m.cards[u]["st"][s] = int(start[s])
	var since := _since(m)
	m.apply_status(u, ward, 1)
	return [_batch(m, 0, since), m.cards[u]["st"].duplicate()]


func after_test() -> void:
	UIStyle.reduce_motion = false


func test_core_emits_curse_then_each_cleared_buff_then_the_spent_curse() -> void:
	# Arrange / Act
	var r := _ward_batch({"eternal": 1, "retain": 1}, "curse")
	# Assert: the application first, then the cleared Buffs, the spent Curse last; nothing left.
	assert_array(_kinds(r[0])).is_equal(["status:curse", "status_expire:eternal", "status_expire:retain", "status_expire:curse"])
	assert_dict(r[1]).is_empty()


func test_core_emits_cleanse_then_each_cleared_debuff_then_the_spent_cleanse() -> void:
	var r := _ward_batch({"poison": 2, "burn": 1}, "cleanse")
	assert_array(_kinds(r[0])).is_equal(["status:cleanse", "status_expire:poison", "status_expire:burn", "status_expire:cleanse"])
	assert_dict(r[1]).is_empty()


func test_curse_plays_first_and_the_buffs_fade_after_its_badge_lands() -> void:
	# Arrange
	var evs: Array = _ward_batch({"eternal": 1, "retain": 1}, "curse")[0]
	var gs := _screen()
	await await_idle_frame()
	# Act
	gs.fx.play(evs, {})
	var looks := _plan(gs.fx.last_plan, ["status:", "status_expire"])
	# Assert: Curse at the start; the first fade CLEAR_LEAD later (after the stamp lands); then STAGGER.
	var k := UIStyle.dur(1.0)
	assert_int(looks.size()).is_equal(4)
	assert_str(looks[0][0]).is_equal("status:curse")
	assert_float(looks[0][1]).is_equal_approx(0.0, 0.001)
	assert_float(FxStatus.CLEAR_LEAD).is_greater_equal(FxStatus.LENGTH * FxStatus.STAMP_END)
	assert_float(looks[1][1] - looks[0][1]).is_equal_approx(FxStatus.CLEAR_LEAD * k, 0.01)
	assert_float(looks[2][1] - looks[1][1]).is_equal_approx(FxStatus.STAGGER * k, 0.01)
	assert_float(looks[3][1] - looks[2][1]).is_equal_approx(FxStatus.STAGGER * k, 0.01)
	# Each look's sound starts with it: the Curse cue first, then one expiry cue per fade.
	var cues := _plan(gs.fx.last_plan, ["sfx:status"])
	assert_array(cues.map(func(c): return c[0])).is_equal(["sfx:status_curse", "sfx:status_expire", "sfx:status_expire", "sfx:status_expire"])
	for i in 4:
		assert_float(cues[i][1]).is_equal_approx(looks[i][1], 0.001)
	gs.fx.finish_all()


func test_cleanse_clearing_debuffs_uses_the_same_order() -> void:
	var evs: Array = _ward_batch({"poison": 2, "burn": 1}, "cleanse")[0]
	var gs := _screen()
	await await_idle_frame()
	gs.fx.play(evs, {})
	var looks := _plan(gs.fx.last_plan, ["status:", "status_expire"])
	assert_str(looks[0][0]).is_equal("status:cleanse")
	assert_float(looks[1][1] - looks[0][1]).is_equal_approx(FxStatus.CLEAR_LEAD * UIStyle.dur(1.0), 0.01)
	gs.fx.finish_all()


func test_reduce_motion_keeps_the_order_with_short_beats() -> void:
	# Arrange
	UIStyle.reduce_motion = true
	var evs: Array = _ward_batch({"eternal": 1, "retain": 1}, "curse")[0]
	var gs := _screen()
	await await_idle_frame()
	# Act
	gs.fx.play(evs, {})
	var looks := _plan(gs.fx.last_plan, ["status:", "status_expire"])
	# Assert: same order; the flash beats, each shorter than the full lead and stagger.
	var k := UIStyle.dur(1.0)
	assert_str(looks[0][0]).is_equal("status:curse")
	assert_float(looks[1][1] - looks[0][1]).is_equal_approx(FxStatus.CLEAR_LEAD_FLASH * k, 0.01)
	assert_float(looks[2][1] - looks[1][1]).is_equal_approx(FxStatus.STAGGER_FLASH * k, 0.01)
	assert_float(FxStatus.CLEAR_LEAD_FLASH).is_less(FxStatus.CLEAR_LEAD)
	assert_float(FxStatus.STAGGER_FLASH).is_less(FxStatus.STAGGER)
	gs.fx.finish_all()


func test_gap_after_waits_for_the_badge_only_before_a_cleared_status() -> void:
	assert_float(FxStatus.gap_after({"k": "status", "s": "curse"}, "status_expire", false)).is_equal(FxStatus.CLEAR_LEAD)
	assert_float(FxStatus.gap_after({"k": "status", "s": "poison"}, "status", false)).is_equal(FxStatus.STAGGER)
	assert_float(FxStatus.gap_after({"k": "status_expire", "s": "eternal"}, "status_expire", false)).is_equal(FxStatus.STAGGER)
	assert_float(FxStatus.gap_after({"k": "status", "s": "curse"}, "status_expire", true)).is_equal(FxStatus.CLEAR_LEAD_FLASH)


func test_next_status_kinds_follows_each_card_separately() -> void:
	var a := {"p": 1, "zone": "unit", "slot": 0}
	var b := {"p": 1, "zone": "unit", "slot": 1}
	var evs := [{"k": "status", "at": a, "s": "curse"}, {"k": "status", "at": b, "s": "poison"},
		{"k": "hp", "p": 0, "d": -1}, {"k": "status_expire", "at": a, "s": "eternal"}]
	var nk := FxPlayer.next_status_kinds(evs)
	assert_str(String(nk.get(0, ""))).is_equal("status_expire")
	assert_bool(nk.has(1)).is_false()
	assert_bool(nk.has(3)).is_false()


func test_view_before_rebuilds_the_row_the_batch_started_from() -> void:
	# Curse (spent) cleared Eternal and Retain: before the batch the card had both Buffs, no Curse.
	var final := {"uid": 5, "statuses": {}, "runes": 0}
	var at := {"p": 1, "zone": "unit", "slot": 0}
	var evs := [{"k": "status", "at": at, "s": "curse", "n": 1}, {"k": "status_expire", "at": at, "s": "eternal"},
		{"k": "status_expire", "at": at, "s": "retain"}, {"k": "status_expire", "at": at, "s": "curse"}]
	var v := FxStatus.view_before(final, evs)
	assert_dict(v["statuses"]).is_equal({"eternal": 1, "retain": 1})
	# Stepping forward through the same events walks the row as it is shown, ending where the rules did.
	var rows := []
	for e in evs:
		v = FxStatus.step_view(v, e)
		var keys: Array = (v["statuses"] as Dictionary).keys()
		keys.sort()
		rows.append(keys)
	assert_array(rows).is_equal([["curse", "eternal", "retain"], ["curse", "retain"], ["curse"], []])
	assert_dict(final["statuses"]).is_empty()   # the real view is never changed


func test_a_ward_block_spends_its_stack_and_the_last_one_fades() -> void:
	var at := {"p": 1, "zone": "unit", "slot": 0}
	var evs := [{"k": "status_blocked", "at": at, "s": "eternal", "by": "curse", "used": true}, {"k": "status_expire", "at": at, "s": "curse"}]
	var v := FxStatus.view_before({"statuses": {}, "runes": 0}, evs)
	assert_dict(v["statuses"]).is_equal({"curse": 1})
	# The last stack's badge stays through the block and leaves with the ward's own fade.
	var blocked := FxStatus.step_view(v, evs[0])
	assert_dict(blocked["statuses"]).is_equal({"curse": 1})
	assert_dict(FxStatus.step_view(blocked, evs[1])["statuses"]).is_empty()
	# A ward with stacks to spare shows one fewer at once.
	var two := FxStatus.view_before({"statuses": {"curse": 1}, "runes": 0}, [evs[0]])
	assert_dict(two["statuses"]).is_equal({"curse": 2})
	assert_dict(FxStatus.step_view(two, evs[0])["statuses"]).is_equal({"curse": 1})
