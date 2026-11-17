extends GdUnitTestSuite
## M5 (owner feedback 2026-11-09): "Curse first, then buffs fade." On the real GameScreen bound to a
## local host: the board is drawn in its final state before a batch plays, so the badges a Curse
## cleared used to vanish from the card at once, before any fade, and a Curse spent doing so never
## showed. The card's status row now walks through the batch: the Buffs stay until their fades, the
## Curse badge joins when its stamp lands, each cleared status leaves as its fade starts, the spent
## Curse last; a skip shows the final row at once. Cleanse clearing Debuffs is the mirror.

var host: LocalHost
var gs: GameScreen
var m: MatchEngine
var a: int
var o: int
var was_seq: bool
var was_rm: bool


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	was_seq = FxPlayer.sequence_views
	was_rm = UIStyle.reduce_motion
	FxPlayer.sequence_views = true
	UIStyle.reduce_motion = false
	host = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 11, "best_of": 3, "deck_mode": "starter", "names": ["A", "B"]})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	m = host.series.game
	TB.to_battle(m)
	a = m.active
	o = 1 - a
	gs = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	GameScreen._coin_shown[String(host.series.view_for(a).get("save_id", "local"))] = true
	await gs.attach(host.seats[a])
	await await_idle_frame()


func after_test() -> void:
	FxPlayer.sequence_views = was_seq
	UIStyle.reduce_motion = was_rm


## An opponent unit in slot 0 carrying `start`, shown and settled.
func _unit_with(start: Dictionary) -> int:
	var u := TB.unit(m, o, TB.FILLER, 0)
	for s in start:
		m.cards[u]["st"][s] = int(start[s])
	host.broadcast()
	gs.skip_effects()
	return u


## The statuses the card in the opponent's slot 0 draws now, sorted.
func _row() -> Array:
	var w: CardWidget = gs.board.slot_item(o, "unit", 0)["widget"]
	var out: Array = []
	for s in w.view.get("statuses", {}):
		if int(w.view["statuses"][s]) > 0:
			out.append(s)
	out.sort()
	return out


## Every distinct row the card shows, frame by frame, until the effects are done (at most `secs`).
func _rows_until_settled(secs: float = 6.0) -> Array:
	var rows := [_row()]
	var t0 := Time.get_ticks_msec()
	while (gs.fx.gating() or not gs.fx.views.is_empty()) and Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await get_tree().process_frame
		var r := _row()
		if r != rows[-1]:
			rows.append(r)
	return rows


func test_curse_on_buffs_shows_curse_then_each_buff_leaving_then_the_curse() -> void:
	# Arrange
	var u := _unit_with({"eternal": 1, "retain": 1})
	# Act
	m.apply_status(u, "curse", 1)
	host.broadcast()
	var rows := await _rows_until_settled()
	# Assert: the Buffs stay until their fades; Curse joins; Eternal, Retain, then Curse leave in turn.
	assert_array(rows).is_equal([["eternal", "retain"], ["curse", "eternal", "retain"], ["curse", "retain"], ["curse"], []])
	var w: CardWidget = gs.board.slot_item(o, "unit", 0)["widget"]
	assert_dict(w.view["statuses"]).is_empty()


func test_cleanse_on_debuffs_shows_cleanse_then_each_debuff_leaving_then_the_cleanse() -> void:
	var u := _unit_with({"poison": 2, "burn": 1})
	m.apply_status(u, "cleanse", 1)
	host.broadcast()
	var rows := await _rows_until_settled()
	assert_array(rows).is_equal([["burn", "poison"], ["burn", "cleanse", "poison"], ["burn", "cleanse"], ["cleanse"], []])


func test_a_curse_with_stacks_left_keeps_its_badge() -> void:
	var u := _unit_with({"eternal": 1, "curse": 1})
	m.apply_status(u, "curse", 1)
	host.broadcast()
	var rows := await _rows_until_settled()
	assert_array(rows).is_equal([["curse", "eternal"], ["curse"]])
	assert_int(int(m.cards[u]["st"].get("curse", 0))).is_equal(1)


func test_reduce_motion_keeps_the_same_row_order() -> void:
	UIStyle.reduce_motion = true
	var u := _unit_with({"eternal": 1, "retain": 1})
	m.apply_status(u, "curse", 1)
	host.broadcast()
	var rows := await _rows_until_settled()
	assert_array(rows).is_equal([["curse", "eternal", "retain"], ["curse", "retain"], ["curse"], []])


func test_a_skip_shows_the_final_row_at_once() -> void:
	# Arrange
	var u := _unit_with({"eternal": 1, "retain": 1})
	m.apply_status(u, "curse", 1)
	host.broadcast()
	assert_array(_row()).is_equal(["eternal", "retain"])
	# Act
	gs.skip_effects()
	# Assert: the real view, the one the rules left.
	var w: CardWidget = gs.board.slot_item(o, "unit", 0)["widget"]
	assert_array(_row()).is_empty()
	assert_bool(is_same(w.view, gs.pv(o)["units"][0])).is_true()
