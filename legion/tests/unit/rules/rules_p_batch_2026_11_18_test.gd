extends GdUnitTestSuite
## Owner feedback of 18 Nov 2026 (design/owner-feedback-2026-11-18.md), rules items.

const RADABLAST := 77          # tribute bonus: 1 Infiltrate to the unit summoned (cost 2)
const CLIFF := 174             # Spirit 2S
const CREEPING_NULL := 65      # Arcane 3A
const SPIRIT_SOLDIER := 20     # Courageous Soldier: On Destruction "You can apply 1 of any Buff to a Unit."
const NO_HUBRIS := 138         # a Spell
const MAGE := TB.FILLER


# @cards 77
func test_c077_radablast_spent_as_spirit_material_gives_the_spirit_infiltrate() -> void:
	var m := TB.make()
	var cliff := TB.card(m, 0, CLIFF, "extra")
	var rb := TB.card(m, 0, RADABLAST, "spent")
	assert_str(m.submit(0, {"t": "spirit", "uid": cliff})).is_empty()
	TB.choose_uids(m, [rb])
	TB.choose(m, [TB.slot_label(1)])
	assert_str(String(m.cards[cliff]["zone"])).is_equal("unit")
	assert_str(String(m.cards[rb]["zone"])).is_equal("exhaust")
	assert_int(m.status_count(cliff, "infiltrate")).is_equal(1)


# @cards 77
func test_c077_radablast_tributed_for_an_arcane_summon_gives_infiltrate() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	var rb := TB.unit(m, 1, RADABLAST, 0)
	m.apply_status(rb, "rune", 3)
	var r := TB.card(m, 1, CREEPING_NULL, "extra")
	assert_str(m.submit(1, {"t": "arcane", "uid": r})).is_empty()
	TB.choose_uids(m, [rb])
	TB.choose(m, [TB.slot_label(0)])
	for i in 3:
		if m.pending.is_empty():
			break
		TB.choose(m, ["Skip"])
	assert_str(String(m.cards[r]["zone"])).is_equal("unit")
	assert_int(m.status_count(r, "infiltrate")).is_equal(1)


func test_a_set_spell_cannot_be_activated_in_the_battle_phase() -> void:
	var m := TB.make()
	TB.unit(m, 1, MAGE, 0)
	var sp := TB.set_card(m, 1, NO_HUBRIS, 0)
	TB.p1_battle(m)
	assert_str(m.validate(1, {"t": "activate_set", "uid": sp})).is_not_empty()


# @cards 20
func test_c020_the_optional_any_buff_pick_can_be_skipped() -> void:
	var m := TB.make()
	var soldier := TB.unit(m, 0, SPIRIT_SOLDIER, 0)
	var mage := TB.unit(m, 0, MAGE, 1)
	TB.kill(m, soldier)
	TB.choose_uids(m, [mage])
	assert_str(TB.pend_kind(m)).is_equal("mode")
	var labels: Array = m.pending["options"].map(func(o): return String(o["label"]))
	assert_bool(labels.has("Skip")).is_true()
	assert_str(TB.choose(m, ["Skip"])).is_equal("")
	assert_bool(m.pending.is_empty()).is_true()
	assert_bool(MatchView.card_view(m, mage, 0)["statuses"].is_empty()).is_true()


func test_status_help_says_your_turn_or_your_opponents_turn() -> void:
	assert_str(StatusHelp.describe("poison", true)).contains("at the end of your turn you take")
	assert_str(StatusHelp.describe("poison", false)).contains("at the end of your opponent's turn")
	assert_str(StatusHelp.describe("burn", true)).contains("you take Damage")
	assert_str(StatusHelp.describe("paralyse")).contains("its controller's turn")


func test_card_views_say_whose_card_it_is() -> void:
	var m := TB.make()
	var mine := TB.unit(m, 0, MAGE, 0)
	assert_bool(MatchView.card_view(m, mine, 0)["mine"]).is_true()
	assert_bool(MatchView.card_view(m, mine, 1)["mine"]).is_false()
