extends GdUnitTestSuite
## Card database update of 10 Nov 2026 (design/card-database-update-2026-11-10.md): the owner's
## "CD - JB edit" sheet. Evolutions are Summons and can happen whenever their condition holds in the
## controller's Setup or Recovery Phase; six new cards; changed card behaviour; disabled cards.

const EDWIN := 16
const AVATAR := 14
const SOLOMON_CAPTAIN := 37
const SOLOMON_TYRANNICAL := 181
const SPAWN := 155
const LARVA := 156
const HEAD := 158
const BODY := 159
const SOUL := 160
const TAIL := 196
const LEVIATHAN := 197
const MITHRAL_DOME := 192
const GREAT_HEIST := 193
const TH_SUPPRESSION := 194
const TH_SPIKES := 195
const TH_ENSNAREMENT := 49
const SHEN := 21                  # "If your opponent Summons a Unit, then that Unit Permanently loses -10 ATK."
const DRAW_VIRUS := 44
const ABYSS := 149
const SNOW_TIGER := 190
const YAMATA := 183
const LANTERN := 179
const LONE_WARRIOR := 38
const NARZYL := 18
const DRAGON_RIDER := 135         # a cost-2 unit, 10/4
const DANTE := 36
const MAGE := TB.FILLER           # Basic Mage (Water) 8/8


## Answers every pending choice with its first option (Skip for a Trap window), at most `n` times.
func _answer_all(m: MatchEngine, n: int = 8) -> void:
	for i in n:
		if m.pending.is_empty():
			return
		m.submit(m.pending["player"], {"t": "choose", "id": m.pending["id"], "indices": [0]})


func _evolve_idx(m: MatchEngine, uid: int) -> int:
	var abs: Array = m.script_of(uid).get("abilities", [])
	for i in abs.size():
		if abs[i].get("evolve", false):
			return i
	return -1


# ------------------------------------------------------------ data

# @cards 192,193,194,195,196,197,14,181,36,179
func test_new_cards_have_stable_ids_and_evolution_chains() -> void:
	CardDB.ensure_loaded()
	assert_str(String(CardDB.get_def(TAIL)["name"])).is_equal("Divine Serpent - Tail")
	assert_str(String(CardDB.get_def(LEVIATHAN)["name"])).is_equal("The Great Leviathan")
	assert_int(CardDB.evolves_into(EDWIN)).is_equal(AVATAR)
	assert_int(CardDB.evolves_into(SOLOMON_CAPTAIN)).is_equal(SOLOMON_TYRANNICAL)
	assert_int(CardDB.evolves_into(SOUL)).is_equal(LEVIATHAN)
	for id in [AVATAR, SOLOMON_TYRANNICAL, LEVIATHAN, LARVA]:
		assert_bool(CardDB.is_collectible(id)).override_failure_message(str(id)).is_false()
	assert_str(String(CardDB.get_def(SOLOMON_TYRANNICAL)["category"])).is_equal("unit")
	assert_str(String(CardDB.get_def(DANTE)["category"])).is_equal("fusion")
	assert_str(String(CardDB.get_def(LANTERN)["category"])).is_equal("spell")
	for id in [192, 193, 194, 195, 196, 197]:
		assert_bool(CardScripts.is_implemented(id)).override_failure_message(str(id)).is_true()


# ------------------------------------------------------------ evolution

# @cards 16,14
func test_edwin_cannot_evolve_until_it_has_burn_and_atk_above_base() -> void:
	var m := TB.make()
	var edwin := TB.unit(m, 0, EDWIN, 0)
	var idx := _evolve_idx(m, edwin)
	assert_int(idx).is_not_equal(-1)
	assert_str(TB.ability(m, edwin, idx)).is_not_empty()            # no Burn
	m.apply_status(edwin, "burn", 1)
	assert_str(TB.ability(m, edwin, idx)).is_not_empty()            # Burn, but ATK at base
	m.cards[edwin]["mods"].append({"atk": 4, "def": 0, "until": "perm", "src": "test"})
	assert_str(TB.ability(m, edwin, idx)).is_equal("")
	assert_int(int(m.cards[edwin]["id"])).is_equal(AVATAR)


# @cards 16,14,21
func test_evolution_keeps_statuses_and_is_a_summon() -> void:
	var m := TB.make()
	TB.unit(m, 1, SHEN, 0)                                          # the opponent's Shen
	var edwin := TB.unit(m, 0, EDWIN, 1)
	m.apply_status(edwin, "burn", 2)
	m.apply_status(edwin, "rune", 1)
	m.cards[edwin]["mods"].append({"atk": 4, "def": 0, "until": "perm", "src": "test"})
	assert_str(TB.ability(m, edwin, _evolve_idx(m, edwin))).is_equal("")
	_answer_all(m)
	assert_int(int(m.cards[edwin]["id"])).is_equal(AVATAR)
	assert_int(m.status_count(edwin, "burn")).is_equal(2)
	assert_int(m.status_count(edwin, "rune")).is_equal(1)
	assert_int(m.atk_of(edwin)).is_equal(18 + 4 - 10)               # Avatar 18, kept +4, Shen's -10


# @cards 16
func test_evolve_action_is_refused_in_the_battle_phase() -> void:
	var m := TB.make()
	var edwin := TB.unit(m, 1, EDWIN, 0)
	m.apply_status(edwin, "burn", 1)
	m.cards[edwin]["mods"].append({"atk": 4, "def": 0, "until": "perm", "src": "test"})
	TB.p1_battle(m)
	assert_str(TB.ability(m, edwin, _evolve_idx(m, edwin))).is_equal(MatchEngine.EVOLVE_MAIN_ONLY)


# @cards 155,156,49
func test_symbiote_start_of_turn_evolve_is_a_summon_with_a_summon_window() -> void:
	var m := TB.make()
	TB.unit(m, 0, SHEN, 1)
	TB.set_card(m, 0, TH_ENSNAREMENT, 0)                            # answers a Summon in column 1
	var spawn := TB.unit(m, 1, SPAWN, 3)                            # back row, column 1
	TB.to_turn2(m)
	assert_str(TB.pend_kind(m)).is_equal("evolve")
	TB.choose(m, ["Evolve"])
	assert_int(int(m.cards[spawn]["id"])).is_equal(LARVA)
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	assert_bool(m.cards[spawn]["mods"].is_empty()).is_false()      # Shen's -10 applied


# @cards 16
func test_edwin_is_not_asked_at_the_start_of_the_turn() -> void:
	var m := TB.make()
	var edwin := TB.unit(m, 1, EDWIN, 0)
	m.apply_status(edwin, "burn", 1)
	m.cards[edwin]["mods"].append({"atk": 4, "def": 0, "until": "perm", "src": "test"})
	TB.to_turn2(m)
	assert_str(TB.pend_kind(m)).is_not_equal("evolve")


# @cards 160,158,159,196,197
func test_soul_evolves_into_leviathan_exhausting_head_body_and_tail() -> void:
	var m := TB.make()
	var head := TB.unit(m, 0, HEAD, 0)
	var body := TB.unit(m, 0, BODY, 1)
	var tail := TB.unit(m, 0, TAIL, 2)
	var soul := TB.unit(m, 0, SOUL, 3)
	var trap := TB.set_card(m, 1, TH_SPIKES, 2)
	var pw := TB.power(m, 0, ABYSS, 0)
	assert_str(TB.ability(m, soul, _evolve_idx(m, soul))).is_equal("")
	_answer_all(m)
	assert_int(int(m.cards[soul]["id"])).is_equal(LEVIATHAN)
	for u in [head, body, tail]:
		assert_str(String(m.cards[u]["zone"])).is_equal("exhaust")
	assert_bool(m.on_field(trap)).is_false()
	assert_bool(m.on_field(pw)).is_false()
	assert_int(m.status_count(soul, "eternal")).is_equal(1)
	assert_int(m.status_count(soul, "cleanse")).is_equal(1)


# @cards 160
func test_soul_cannot_evolve_without_the_tail() -> void:
	var m := TB.make()
	TB.unit(m, 0, HEAD, 0)
	TB.unit(m, 0, BODY, 1)
	var soul := TB.unit(m, 0, SOUL, 3)
	assert_str(TB.ability(m, soul, _evolve_idx(m, soul))).is_not_empty()


# @cards 197
func test_leviathan_attacks_twice_while_the_opponent_controls_a_unit() -> void:
	var m := TB.make()
	TB.unit(m, 0, MAGE, 0)
	TB.unit(m, 0, MAGE, 1)
	var lev := TB.unit(m, 1, LEVIATHAN, 0)
	TB.p1_battle(m)
	var targets: Array = m.field_units(0)
	assert_str(TB.attack(m, lev, targets[0])).is_equal("")
	_answer_all(m)
	assert_str(TB.attack(m, lev, m.field_units(0)[0])).is_equal("")
	_answer_all(m)
	assert_str(m._attack_check(1, lev)).is_not_empty()


# ------------------------------------------------------------ new Traps, Spell, Power

# @cards 195
func test_trap_hole_of_spikes_destroys_weak_units_summoned_in_its_column_only() -> void:
	var m := TB.make()
	TB.set_card(m, 0, TH_SPIKES, 0)
	TB.to_turn2(m)
	var other := TB.summon(m, 1, MAGE, 1)                           # column 2: no window
	assert_str(TB.pend_kind(m)).is_not_equal("trap_response")
	var mage := TB.summon(m, 1, MAGE, 0)                            # column 1
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	assert_str(TB.choose(m, ["Trap Hole of Spikes"])).is_equal("")
	_answer_all(m)
	assert_bool(m.on_field(mage)).is_false()
	assert_bool(m.on_field(other)).is_true()


# @cards 194
func test_trap_hole_of_suppression_debilitates_their_units_in_its_column() -> void:
	var m := TB.make()
	TB.set_card(m, 0, TH_SUPPRESSION, 0)
	TB.to_turn2(m)
	var mage := TB.summon(m, 1, MAGE, 0)
	assert_str(TB.choose(m, ["Trap Hole of Suppression"])).is_equal("")
	_answer_all(m)
	assert_int(m.status_count(mage, "debilitate")).is_equal(1)


# @cards 192
func test_mithral_dome_is_destroyed_instead_of_a_trap() -> void:
	var m := TB.make()
	var dome := TB.power(m, 0, MITHRAL_DOME, 0)
	var trap := TB.set_card(m, 0, TH_SPIKES, 0)
	assert_bool(m.destroy(trap, "effect", -1, 1)).is_false()
	assert_bool(m.on_field(trap)).is_true()
	assert_bool(m.on_field(dome)).is_false()


# @cards 193
func test_a_great_heist_takes_an_opponents_power_for_good() -> void:
	var m := TB.make()
	var pw := TB.power(m, 1, ABYSS, 0)
	TB.cast(m, 0, GREAT_HEIST)
	_answer_all(m)
	assert_int(int(m.cards[pw]["ctl"])).is_equal(0)
	assert_bool(m.power_cards(0).has(pw)).is_true()
	assert_int(int(m.cards[pw]["owner"])).is_equal(1)


# ------------------------------------------------------------ changed cards

# @cards 38
func test_lone_warrior_is_unaffected_by_trap_effects() -> void:
	var m := TB.make()
	var lw := TB.unit(m, 1, LONE_WARRIOR, 0)
	var mage := TB.unit(m, 1, MAGE, 1)
	var trap := TB.set_card(m, 0, TH_SPIKES, 0)
	var f := m.make_frame(trap, 0, [], "")
	var picked := m.select(f, {"kind": "unit", "side": "opp"})
	assert_bool(picked.has(lw)).is_false()
	assert_bool(picked.has(mage)).is_true()


# @cards 18
func test_corrupted_narzyl_gains_runes_equal_to_the_destroyed_units_cost() -> void:
	var m := TB.make()
	var rider := TB.unit(m, 0, DRAGON_RIDER, 0)
	var narzyl := TB.unit(m, 1, NARZYL, 0)
	TB.p1_battle(m)
	assert_str(TB.attack(m, narzyl, rider)).is_equal("")
	_answer_all(m)
	assert_bool(m.on_field(rider)).is_false()
	assert_int(m.status_count(narzyl, "rune")).is_equal(2)


# @cards 149
func test_marked_by_the_abyss_raises_base_ap_without_exhaust() -> void:
	var m := TB.make()
	TB.power(m, 1, ABYSS, 0)
	TB.to_turn2(m)
	assert_int(int(m.players[1]["ap"])).is_equal(GameCore.BASE_AP + 1)


# @cards 190
func test_snow_tiger_effects_are_continuous() -> void:
	var m := TB.make()
	var tiger := TB.unit(m, 0, SNOW_TIGER, 0)                       # front: Protecting the unit behind
	TB.unit(m, 0, MAGE, 3)
	var trap_card := TB.card(m, 0, TH_SPIKES)
	assert_int(m.current_cost(trap_card)).is_equal(0)              # 1 - 1
	var m2 := TB.make()
	TB.unit(m2, 0, MAGE, 0)
	TB.unit(m2, 0, SNOW_TIGER, 3)                                   # back: Protected by a unit
	var set_trap := TB.set_card(m2, 0, TH_SPIKES, 0)
	assert_bool(m2.destroy(set_trap, "effect", -1, 1)).is_false()
	assert_bool(m.on_field(tiger)).is_true()


# @cards 183
func test_yamata_lets_the_opponent_take_a_power_at_zero_cost() -> void:
	var m := TB.make()
	var yam := TB.unit(m, 0, YAMATA, 0)
	var pw := TB.card(m, 1, ABYSS, "draw")
	TB.kill(m, yam)
	assert_int(int(m.pending.get("player", -1))).is_equal(1)
	TB.choose_uids(m, [pw])
	_answer_all(m)
	assert_str(String(m.cards[pw]["zone"])).is_equal("hand")
	assert_int(m.current_cost(pw)).is_equal(0)


# @cards 179
func test_tyrants_lantern_burns_and_makes_the_unit_fire_this_turn() -> void:
	var m := TB.make()
	var mage := TB.unit(m, 0, MAGE, 0)
	TB.cast(m, 0, LANTERN)
	_answer_all(m)
	assert_str(m.unit_type(mage)).is_equal("Fire")
	assert_int(m.atk_of(mage)).is_equal(12)
	assert_int(m.status_count(mage, "burn")).is_equal(1)


# @cards 181
func test_solomon_tyrannical_destroys_its_protector_for_eternal_and_ap() -> void:
	var m := TB.make()
	var guard := TB.unit(m, 0, MAGE, 0)
	var sol := TB.unit(m, 0, SOLOMON_TYRANNICAL, 3)
	var ap_before := 5
	assert_str(TB.ability(m, sol, 0)).is_equal("")
	_answer_all(m)
	assert_bool(m.on_field(guard)).is_false()
	assert_int(m.status_count(sol, "eternal")).is_equal(1)
	assert_int(int(m.players[0]["ap"])).is_equal(ap_before + 1)


# @cards 36
func test_dante_gains_two_atk_per_burn() -> void:
	var m := TB.make()
	var dante := TB.unit(m, 0, DANTE, 0)
	m.apply_status(dante, "burn", 3)
	assert_int(m.atk_of(dante)).is_equal(28 + 6)


# ------------------------------------------------------------ disabled cards

# @cards 44
func test_draw_virus_is_disabled_everywhere_but_kept_in_the_data() -> void:
	assert_bool(CardDB.is_disabled(DRAW_VIRUS)).is_true()
	assert_bool(CardDB.is_collectible(DRAW_VIRUS)).is_true()        # still listed (greyed)
	assert_bool(CardScripts.is_implemented(DRAW_VIRUS)).is_true()
	assert_bool(Series.is_offerable(DRAW_VIRUS)).is_false()
	assert_str(DeckStore.add_block_reason(0, 0, DRAW_VIRUS)).is_equal(DeckStore.DISABLED_REASON)


# @cards 44
func test_a_deck_holding_a_disabled_card_plays_without_it() -> void:
	var m := MatchEngine.new()
	var deck := []
	for i in 19:
		deck.append(MAGE)
	deck.append(DRAW_VIRUS)
	m.setup([deck.duplicate(), deck.duplicate()], 0, 7)
	for uid in m.cards:
		assert_int(int(m.cards[uid]["id"])).is_not_equal(DRAW_VIRUS)


func test_starter_decks_hold_no_disabled_or_evolution_only_cards() -> void:
	var decks: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/starter_decks.json"))["decks"]
	var serpent := false
	for dk in decks:
		for id in dk["main"] + dk["extra"]:
			assert_bool(Series.is_offerable(int(id))).override_failure_message("%s: %s" % [dk["name"], id]).is_true()
		if String(dk["name"]) == "Divine Serpent's Rising":
			serpent = (dk["main"] as Array).has(float(TAIL)) or (dk["main"] as Array).has(TAIL)
	assert_bool(serpent).is_true()
