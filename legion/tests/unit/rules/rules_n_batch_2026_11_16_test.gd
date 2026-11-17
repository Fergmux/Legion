extends GdUnitTestSuite
## Owner feedback of 16 Nov 2026 (design/owner-feedback-2026-11-16.md), rules items.

const TH_SPIKES := 195
const SOLOMON_CAPTAIN := 37      # 20 ATK: Trap Hole of Spikes has no target
const MAGE := TB.FILLER          # 8 ATK
const MAGICAL_COUNCIL := 139
const HOT_STOVE := 153
const DELAYED_GRATIFICATION := 41
const REINFORCEMENTS := 178


## Answers the pending choice with its first option.
func _first(m: MatchEngine) -> void:
	m.submit(m.pending["player"], {"t": "choose", "id": m.pending["id"], "indices": [0]})


# @cards 195
func test_c195_trap_hole_of_spikes_is_not_offered_without_a_target() -> void:
	var m := TB.make()
	TB.set_card(m, 0, TH_SPIKES, 0)
	TB.to_turn2(m)
	TB.summon(m, 1, SOLOMON_CAPTAIN, 0)                   # column 1, but 20 ATK
	assert_str(TB.pend_kind(m)).is_not_equal("trap_response")
	TB.summon(m, 1, MAGE, 3)                              # column 1 again, 8 ATK: a target
	assert_str(TB.pend_kind(m)).is_equal("trap_response")


# @cards 139,153
func test_c153_hot_stove_answers_magical_council_lowering_a_spells_cost() -> void:
	var m := TB.make()
	var council := TB.power(m, 0, MAGICAL_COUNCIL, 0)
	TB.set_card(m, 1, HOT_STOVE, 0)
	TB.cast(m, 0, DELAYED_GRATIFICATION)
	for i in 4:
		if TB.pend_kind(m) == "trap_response":
			break
		_first(m)
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	assert_str(TB.choose(m, ["Hot Stove"])).is_equal("")
	for i in 4:
		if m.pending.is_empty():
			break
		_first(m)
	assert_bool(m.on_field(council)).is_false()
	assert_int(int(m.players[0]["hp"])).is_equal(GameCore.START_HP - 4)


# @cards 139
func test_c139_no_hot_stove_window_when_the_council_saves_nothing() -> void:
	var m := TB.make()
	TB.power(m, 0, MAGICAL_COUNCIL, 0)
	var spell := TB.card(m, 0, DELAYED_GRATIFICATION)
	m.cards[spell]["cost_p"] = -1                         # already free: the Council lowers nothing
	assert_array(m.discount_powers(spell)).is_empty()


# @cards 178
func test_c178_reinforcements_lowers_only_cards_in_hand() -> void:
	var m := TB.make()
	TB.power(m, 0, REINFORCEMENTS, 0)
	TB.unit(m, 1, MAGE, 0)                                # only the opponent controls a unit
	var in_hand := TB.card(m, 0, SOLOMON_CAPTAIN)
	var in_draw := TB.card(m, 0, SOLOMON_CAPTAIN, "draw")
	assert_int(m.current_cost(in_hand)).is_equal(2)       # 3 - 1
	assert_int(m.current_cost(in_draw)).is_equal(3)
