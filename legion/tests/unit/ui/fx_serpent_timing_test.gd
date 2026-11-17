extends GdUnitTestSuite
## 2026-11-10: the Divine Serpent 30-damage combo is gone from the cards, so the tests that played it
## for real were removed; FxSerpent stays reachable only through hand-built events.
## B5 (owner feedback 2026-10-20): a Divine Serpent whose On Summon destroys it in the same batch must be
## visibly summoned first and then destroyed. The summon and the destructions arrive in one view, so the
## final board already shows its slot empty: the arrival must play on a ghost of the card, and every
## destruction must wait until that arrival has landed. The Serpent effect plays its own set piece.

const HEAD := 158
const BODY := 159


## The real event batch of a Serpent's Normal Summon, read from the rules engine (viewer = the summoner).
## 2026-11-17: Soul of Crashing Ocean is a Spirit Unit (no Normal Summon), so the Body is the summoned one.
func _serpent_batch() -> Array:
	var m := TB.make()
	TB.unit(m, 0, HEAD, 0)
	var since: int = int(m.log_entries[-1]["seq"])
	TB.summon(m, 0, BODY, 4)
	var events := []
	for row in MatchView.log_for(m, 0, since):
		for f in row["fx"]:
			events.append(f)
	return events


func _screen() -> GameScreen:
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	return gs


func _first(plan: Array, prefix: String) -> Dictionary:
	for s in plan:
		if String(s["tag"]).begins_with(prefix):
			return s
	return {}




func test_summoned_serpent_ghost_is_visible_in_its_slot() -> void:
	var gs := _screen()
	await await_idle_frame()
	gs.fx.play(_serpent_batch(), {})
	await await_millis(int(FxPlayer.TRANSIENT_HOLD * 0.8 * 1000.0 * UIStyle.dur(1.0)) + 60)
	var slot_c := gs.fx_slot_global_rect(0, "unit", 4).get_center()
	var found := false
	for n in gs.fx_layer.get_children():
		if n is CardWidget and is_instance_valid(n) and int((n as CardWidget).view.get("id", -1)) == BODY:
			if n.get_global_rect().get_center().distance_to(slot_c) < 40.0 and n.modulate.a > 0.5:
				found = true
	assert_bool(found).is_true()
	gs.fx.finish_all()
	# a click (finish_all) clears every ghost and hold
	await await_idle_frame()
	for n in gs.fx_layer.get_children():
		assert_bool(n is CardWidget and not n.is_queued_for_deletion()).is_false()
