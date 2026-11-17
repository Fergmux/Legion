extends GdUnitTestSuite
## Card database update of 17 Nov 2026 (design/card-database-update-2026-11-17.md): the owner's "10 Nov Changes"
## sheet, the mechanic renames (Arcane = Rune summon, Spirit = Spent summon, Transform) and the picked notes.

const MAGE := TB.FILLER            # Basic Mage (Water) 8/8
const KAYA := 170                  # Spirit Unit
const KOMODO := 35
const ANGERED := 199
const ENRAGED := 200
const SWEEPER := 29
const LONE_WARRIOR := 38
const BURNING_SOUL := 202
const ZADUS := 203
const HERETIC := 201
const ENERGY_CAPTURE := 85
const RUNE_STONE := 83
const EMERGENCY_EVADE := 50
const NO_LOYALTY := 164
const TYDE := 172
const TRITU := 176
const FENCE := 187
const PICKPOCKET := 17
const LARVA := 156
const SIPHONOPHORE := 157
const MIRRORFLESH := 94
const AVATAR := 14
const MANS_BEST_FRIEND := 73
const WARRIOR := 3                 # Basic Warrior (Water)
const DO_NOT_OPEN_BOX := 191


func _first(m: MatchEngine) -> void:
	m.submit(m.pending["player"], {"t": "choose", "id": m.pending["id"], "indices": [0]})


func _answer_all(m: MatchEngine, n: int = 8) -> void:
	for i in n:
		if m.pending.is_empty():
			return
		_first(m)


func _transform_idx(m: MatchEngine, uid: int) -> int:
	var abs: Array = m.script_of(uid).get("abilities", [])
	for i in abs.size():
		if abs[i].get("transform", false):
			return i
	return -1


# @cards 170,21,22,23,161,183
func test_spirit_units_are_exhausted_when_they_leave_the_field() -> void:
	var m := TB.make()
	var kaya := TB.unit(m, 0, KAYA, 0)
	TB.kill(m, kaya)
	_answer_all(m)
	assert_str(String(m.cards[kaya]["zone"])).is_equal("exhaust")
	for id in [21, 22, 23, 161, 160, 183, 201, 202]:
		assert_str(String(CardDB.get_def(id)["category"])).override_failure_message(str(id)).is_equal("spirit")


func test_transformed_forms_are_not_collectible() -> void:
	for id in [ANGERED, ENRAGED, LONE_WARRIOR, ZADUS, 197]:
		assert_bool(CardDB.is_collectible(id)).override_failure_message(str(id)).is_false()
	assert_int(CardDB.transforms_into(KOMODO)).is_equal(ANGERED)
	assert_int(CardDB.transforms_into(ANGERED)).is_equal(ENRAGED)
	assert_int(CardDB.transforms_into(SWEEPER)).is_equal(LONE_WARRIOR)
	assert_int(CardDB.transforms_into(BURNING_SOUL)).is_equal(ZADUS)


# @cards 35,199
func test_c035_battle_komodo_transforms_after_destroying_a_unit() -> void:
	var m := TB.make()
	var foe := TB.unit(m, 0, MAGE, 0)
	var kom := TB.unit(m, 1, KOMODO, 0)
	TB.to_turn2(m)
	var idx := _transform_idx(m, kom)
	assert_str(TB.ability(m, kom, idx)).is_not_empty()           # it has not destroyed anything yet
	TB.to_battle(m)
	assert_str(TB.attack(m, kom, foe)).is_equal("")
	_answer_all(m)
	assert_bool(m.on_field(foe)).is_false()
	m.submit(1, {"t": "next_phase"})                               # Recovery Phase
	assert_str(TB.ability(m, kom, idx)).is_equal("")
	_answer_all(m)
	assert_int(int(m.cards[kom]["id"])).is_equal(ANGERED)
	assert_str(TB.ability(m, kom, _transform_idx(m, kom))).is_not_empty()   # the mark went with the old form


# @cards 29,38
func test_c029_the_sweeper_transforms_once_it_has_had_eternal() -> void:
	var m := TB.make()
	var sw := TB.unit(m, 0, SWEEPER, 0)
	var idx := _transform_idx(m, sw)
	assert_str(TB.ability(m, sw, idx)).is_not_empty()
	m.apply_status(sw, "eternal", 1)
	m.decrement_status(sw, "eternal")                              # used up: it still "has had" Eternal
	assert_str(TB.ability(m, sw, idx)).is_equal("")
	_answer_all(m)
	assert_int(int(m.cards[sw]["id"])).is_equal(LONE_WARRIOR)


# @cards 202,203
func test_c202_burning_soul_becomes_zadus_at_16_burn() -> void:
	var m := TB.make()
	var soul := TB.unit(m, 0, BURNING_SOUL, 0)
	var idx := _transform_idx(m, soul)
	m.apply_status(soul, "burn", 15)
	assert_str(TB.ability(m, soul, idx)).is_not_empty()
	m.apply_status(soul, "burn", 1)
	assert_str(TB.ability(m, soul, idx)).is_equal("")
	_answer_all(m)
	assert_int(int(m.cards[soul]["id"])).is_equal(ZADUS)
	assert_int(int(m.players[0]["hp"])).is_equal(GameCore.START_HP + 6)
	assert_int(int(m.players[1]["hp"])).is_equal(GameCore.START_HP - 6)


# @cards 85,83
func test_c085_energy_capture_answers_the_opponent_applying_a_rune() -> void:
	var m := TB.make()
	TB.unit(m, 0, MAGE, 0)
	TB.set_card(m, 1, ENERGY_CAPTURE, 0)
	TB.cast(m, 0, RUNE_STONE)
	for i in 4:
		if TB.pend_kind(m) == "trap_response":
			break
		_first(m)
	assert_str(TB.pend_kind(m)).is_equal("trap_response")


# @cards 85
func test_c085_energy_capture_ignores_an_ordinary_summon() -> void:
	var m := TB.make()
	TB.set_card(m, 1, ENERGY_CAPTURE, 0)
	TB.summon(m, 0, MAGE, 0)
	assert_str(TB.pend_kind(m)).is_not_equal("trap_response")


# @cards 50
func test_c050_emergency_evade_only_for_an_unprotected_unit() -> void:
	var m := TB.make()
	TB.set_card(m, 0, EMERGENCY_EVADE, 0)
	var front := TB.unit(m, 0, MAGE, 0)
	var a := TB.unit(m, 1, MAGE, 0, "atk", 20)
	TB.p1_battle(m)
	TB.attack(m, a, front)
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	TB.choose(m, ["Emergency Evade"])
	_answer_all(m)
	assert_bool(m.on_field(front)).is_true()                       # Eternal saved it


# @cards 164
func test_c164_no_loyalty_curses_debilitates_and_boosts_the_attacked_unit() -> void:
	var m := TB.make()
	TB.set_card(m, 0, NO_LOYALTY, 0)
	var d := TB.unit(m, 0, MAGE, 0)
	var a := TB.unit(m, 1, MAGE, 0, "atk", 12)
	TB.p1_battle(m)
	TB.attack(m, a, d)
	TB.choose(m, ["No Loyalty"])
	assert_int(m.status_count(d, "curse")).is_equal(1)
	assert_int(m.status_count(d, "debilitate")).is_equal(1)
	_answer_all(m)


# @cards 172
func test_c172_tyde_permanently_lowers_a_hand_cards_cost() -> void:
	var m := TB.make()
	var c := TB.card(m, 0, LONE_WARRIOR)                           # costs 2
	TB.special(m, 0, TYDE, 0)
	TB.choose_uids(m, [c])
	_answer_all(m)
	assert_int(m.current_cost(c)).is_equal(1)
	assert_str(String(CardDB.get_def(TYDE)["category"])).is_equal("arcane")


# @cards 176
func test_c176_tritu_takes_the_adjacent_water_units_stats() -> void:
	var m := TB.make()
	TB.unit(m, 0, MAGE, 1)                                          # adjacent Water 8/8
	TB.unit(m, 0, MAGE, 2)                                          # not adjacent to slot 0
	var tr := TB.special(m, 0, TRITU, 0)
	_answer_all(m)
	assert_int(m.atk_of(tr)).is_equal(8)
	assert_str(String(CardDB.get_def(TRITU)["category"])).is_equal("unit")


# @cards 187
func test_c187_fence_takes_10_to_search_any_card() -> void:
	var m := TB.make()
	var fence := TB.unit(m, 0, FENCE, 0)
	var hand_n: int = m.players[0]["hand"].size()
	assert_str(TB.ability(m, fence, 0)).is_equal("")
	_answer_all(m)
	assert_int(m.players[0]["hand"].size()).is_equal(hand_n + 1)
	assert_int(int(m.players[0]["hp"])).is_equal(GameCore.START_HP - 10)


# @cards 17
func test_c017_pickpocket_moves_a_rune() -> void:
	var m := TB.make()
	var pp := TB.unit(m, 0, PICKPOCKET, 0)
	var foe := TB.unit(m, 1, MAGE, 0)
	var mine := TB.unit(m, 0, MAGE, 1)
	m.apply_status(foe, "rune", 1)
	assert_str(TB.ability(m, pp, 0)).is_equal("")
	TB.choose_uids(m, [foe])
	TB.choose_uids(m, [mine])
	_answer_all(m)
	assert_int(m.status_count(foe, "rune")).is_equal(0)
	assert_int(m.status_count(mine, "rune")).is_equal(1)
	assert_int(int(m.players[0]["hp"])).is_equal(GameCore.START_HP - 6)


# @cards 156,157
func test_larva_and_siphonophore_draw_once_per_turn_by_button() -> void:
	var m := TB.make()
	var sip := TB.unit(m, 0, SIPHONOPHORE, 0)
	var hand_n: int = m.players[0]["hand"].size()
	assert_str(TB.ability(m, sip, 0)).is_equal("")
	_answer_all(m)
	assert_int(m.players[0]["hand"].size()).is_equal(hand_n + 1)
	assert_str(TB.ability(m, sip, 0)).is_not_empty()               # once per turn
	assert_bool(CardScripts.get_entry(LARVA).get("on", []).is_empty()).is_true()


# @cards 94
func test_c094_mirrorflesh_debilitates_only_a_stronger_unit() -> void:
	var m := TB.make()
	var mf := TB.unit(m, 0, MIRRORFLESH, 0, "atk", 10, 10)
	var weak := TB.unit(m, 1, MAGE, 0)
	var strong := TB.unit(m, 1, MAGE, 1, "atk", 20)
	var f := m.make_frame(mf, 0, [], "")
	var picks := m.select(f, {"kind": "unit", "atk_above_self": true})
	assert_bool(picks.has(strong)).is_true()
	assert_bool(picks.has(weak)).is_false()


# @cards 14
func test_c014_avatar_debilitates_a_unit_on_summon() -> void:
	var m := TB.make()
	var foe := TB.unit(m, 1, MAGE, 0)
	TB.special(m, 0, AVATAR, 0)
	TB.choose_uids(m, [foe])
	_answer_all(m)
	assert_int(m.status_count(foe, "debilitate")).is_equal(1)
	assert_int(int(CardDB.get_def(AVATAR)["atk"])).is_equal(20)


# @cards 73
func test_c073_mans_best_friend_is_exhausted_guarding_a_warrior() -> void:
	var m := TB.make()
	var dog := TB.unit(m, 0, MANS_BEST_FRIEND, 0)
	var war := TB.unit(m, 0, WARRIOR, 3)
	TB.kill(m, war)
	_answer_all(m)
	assert_bool(m.on_field(war)).is_true()
	assert_str(String(m.cards[dog]["zone"])).is_equal("exhaust")


# @cards 191
func test_c191_do_not_open_box_can_summon_from_spent() -> void:
	var m := TB.make()
	TB.to_turn2(m)                                                 # the opponent's turn
	var box := TB.set_card(m, 0, DO_NOT_OPEN_BOX, 1)
	m.players[0]["draw"] = []
	var spent_unit := TB.card(m, 0, MAGE, "spent")
	m.destroy(box, "effect", -1, 1)
	m.run()
	for i in 8:
		if TB.pend_kind(m) == "trap_response":
			TB.choose(m, ["Do Not Open Box"])
		elif TB.pend_kind(m) == "select":
			TB.choose_uids(m, [spent_unit])
		elif not m.pending.is_empty():
			_first(m)
	assert_str(String(m.cards[spent_unit]["zone"])).is_equal("unit")


# @cards 201
func test_c201_heretic_offers_any_buff_and_any_debuff() -> void:
	var labels: Array = CardScripts.get_entry(HERETIC)["abilities"].map(func(a): return String(a["label"]))
	assert_array(labels).contains(["Apply 1 of any Buff to a unit", "Apply 1 of any Debuff to a unit"])
