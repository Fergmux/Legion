extends GdUnitTestSuite
## Responses, trigger ordering, immediate defeat and card-specific acceptance checks.


func _battle_match() -> MatchEngine:
	var m := TB.make()
	TB.to_turn2(m)
	TB.to_battle(m)
	return m


func test_trap_prompt_suspends_active_player_indefinitely() -> void:
	var m := _battle_match()
	TB.set_card(m, 0, 45, 0)                    # Magic Cylinder, column 1
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	var d := TB.unit(m, 0, TB.WATER, 0, "atk", 8)
	TB.attack(m, a, d)
	assert_str(m.pending["kind"]).is_equal("trap_response")
	assert_int(m.pending["player"]).is_equal(0)
	assert_str(m.submit(1, {"t": "next_phase"})).is_equal("Waiting for the opponent.")
	assert_str(m.submit(1, {"t": "attack", "uid": a})).is_equal("Waiting for the opponent.")
	assert_str(m.submit(1, {"t": "choose", "id": m.pending["id"], "indices": [0]})).is_equal("This choice belongs to the other player.")
	assert_str(m.phase).is_equal("battle")


func test_magic_cylinder_resolves_hp_loss_first_then_battle_continues() -> void:
	var m := _battle_match()
	var mc := TB.set_card(m, 0, 45, 0)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	var d := TB.unit(m, 0, TB.WATER, 0, "atk", 8)
	TB.attack(m, a, d)
	assert_str(TB.choose(m, ["Activate Dimensional Redirect"])).is_empty()
	assert_int(m.players[1]["hp"]).is_equal(50)
	assert_str(m.cards[d]["zone"]).is_equal("spent")
	assert_int(m.players[0]["hp"]).is_equal(58)
	assert_str(m.cards[a]["zone"]).is_equal("unit")
	assert_int(m.current_cost(mc)).is_equal(2 + 1)             # Dimensional Redirect costs 2 since 2026-11-10
	assert_bool(TB.log_index(m, "loses 10 HP") < TB.log_index(m, "Battle:")).is_true()


func test_magic_cylinder_lethal_ends_game_before_battle() -> void:
	var m := _battle_match()
	TB.set_card(m, 0, 45, 0)
	m.players[1]["hp"] = 10
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	var d := TB.unit(m, 0, TB.WATER, 0, "atk", 8)
	TB.attack(m, a, d)
	TB.choose(m, ["Activate"])
	assert_int(m.winner).is_equal(0)
	assert_str(m.cards[d]["zone"]).is_equal("unit")
	assert_int(TB.log_index(m, "Battle:")).is_equal(-1)


func test_passing_on_trap_lets_battle_resolve() -> void:
	var m := _battle_match()
	TB.set_card(m, 0, 45, 0)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	var d := TB.unit(m, 0, TB.WATER, 0, "atk", 8)
	TB.attack(m, a, d)
	TB.choose(m, ["Skip"])
	assert_str(m.cards[d]["zone"]).is_equal("spent")
	assert_int(m.players[1]["hp"]).is_equal(60)


func test_mirror_force_destroys_attacker_so_battle_does_not_resolve() -> void:
	var m := _battle_match()
	TB.set_card(m, 0, 46, 2)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 30)
	for s in [1, 2, 3]:
		TB.unit(m, 1, TB.WATER, s, "atk")
	var d := TB.unit(m, 0, TB.WATER, 0, "atk", 8)
	TB.attack(m, a, d)
	TB.choose(m, ["Activate Sorcerer's Forcefield"])
	assert_str(m.cards[a]["zone"]).is_equal("spent")
	assert_str(m.cards[d]["zone"]).is_equal("unit")
	assert_int(m.field_units(1).size()).is_equal(0)
	assert_int(m.players[0]["hp"]).is_equal(60)


func test_mirror_force_needs_attacker_with_four_field_cards() -> void:
	var m := _battle_match()
	TB.set_card(m, 0, 46, 2)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 30)
	var d := TB.unit(m, 0, TB.WATER, 0, "atk", 8)
	TB.attack(m, a, d)
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(m.cards[d]["zone"]).is_equal("spent")


## 2026-11-10: Defensive Rally answers only an attack on a unit in its column, so the attacked unit
## stands in column 3 with it; Dimensional Redirect answers the attacker's column (column 1).
func test_trap_owner_orders_multiple_eligible_traps() -> void:
	var m := _battle_match()
	TB.set_card(m, 0, 45, 0)                    # Dimensional Redirect, column 1: the attacker's column
	TB.set_card(m, 0, 47, 0 + 1)                # Dimensional Conversion, column 2 (neither column)
	TB.set_card(m, 0, 51, 2)                    # Defensive Rally, column 3: the attacked unit's column
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	var d := TB.unit(m, 0, TB.WATER, 2, "atk", 8)
	TB.attack(m, a, d)
	var labels: Array = m.pending["options"].map(func(o): return o["label"])
	assert_array(labels).contains(["Skip", "Skip for the rest of this turn", "Activate Dimensional Redirect", "Activate Defensive Rally"])
	assert_array(labels).not_contains(["Activate Dimensional Conversion"])
	TB.choose(m, ["Activate Defensive Rally"])
	assert_str(m.pending["kind"]).is_equal("trap_response")
	TB.choose(m, ["Activate Dimensional Redirect"])
	assert_int(m.players[1]["hp"]).is_equal(50)


func test_traps_cannot_activate_on_own_turn() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	TB.set_card(m, 1, 49, 0)                    # Trap Hole owned by active player
	var u := TB.card(m, 1, 28)
	m.submit(1, {"t": "summon", "uid": u})
	TB.choose(m, ["Front row, column 1"])
	TB.choose(m, ["Attack"])
	assert_bool(m.pending.is_empty() or m.pending["kind"] != "trap_response").is_true()


## 2026-11-10: Avatar (the old fixture: lose 6, then the opponent loses 6) no longer loses HP; Grandmother
## Kaya's On Destruction (take 10 Damage, then add a card from Spent to Hand) is the ordered effect now.
func test_own_hp_reaching_zero_in_ordered_loss_ends_before_second_step() -> void:
	var m := TB.make()
	var kaya := TB.unit(m, 0, 170, 0)           # Grandmother Kaya: take 10, then add a Spent card to Hand
	var spent := TB.card(m, 0, TB.WATER, "spent")
	m.players[0]["hp"] = 10
	m.destroy(kaya, "effect", -1, 1)
	m.run()
	assert_str(TB.choose(m, ["Yes"])).is_empty()
	assert_int(m.winner).is_equal(1)
	assert_bool(m.pending.is_empty()).is_true()
	assert_str(String(m.cards[spent]["zone"])).is_equal("spent")


func test_narzyl_destroying_crevasse_resolves_narzyl_rune_before_crevasse_paralyse() -> void:
	var m := _battle_match()
	var narzyl := TB.unit(m, 1, 18, 0)          # Corrupted Narzyl 14/2 (active player)
	var crevasse := TB.unit(m, 0, 100, 0)       # Gaping Crevasse 0/10, cost 0
	m.cards[crevasse]["cost_p"] = 1             # Narzyl's Runes equal the victim's Cost (2026-11-10): 1
	TB.attack(m, narzyl, crevasse)
	var rune_i := TB.log_index(m, "gains 1 Rune")
	var para_i := TB.log_index(m, "gains 2 Paralyse")
	assert_int(rune_i).is_greater(0)
	assert_int(para_i).is_greater(rune_i)
	assert_int(m.status_count(narzyl, "paralyse")).is_equal(2)
	assert_int(m.status_count(narzyl, "rune")).is_equal(1)


func test_necrovast_destruction_can_move_exhausted_card_to_draw() -> void:
	var m := TB.make()
	var nv := TB.unit(m, 0, 64, 0)
	var ex := TB.card(m, 0, 28, "exhaust")
	m.destroy(nv, "effect", -1, 1)
	m.run()
	assert_str(m.pending["kind"]).is_equal("select")
	TB.choose_uids(m, [ex])
	assert_str(m.cards[ex]["zone"]).is_equal("draw")


func test_ordinary_effect_cannot_return_card_from_exhaust() -> void:
	var m := TB.make()
	var ex := TB.card(m, 0, 28, "exhaust")
	var f := m.make_frame(-1, 0, [], "")
	assert_bool(ex in m.select(f, {"kind": "spent", "side": "self"})).is_false()


func test_hypnotised_unit_cannot_be_sacrificed_and_returns_at_end_of_turn() -> void:
	var m := TB.make()
	var victim := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	var spell := TB.card(m, 0, 180)
	assert_str(m.submit(0, {"t": "cast", "uid": spell})).is_empty()
	assert_str(TB.choose_uids(m, [victim])).is_empty()    # sole legal target is still chosen by the player
	assert_str(TB.choose(m, ["Front row, column 1"])).is_empty()   # L9: the caster picks the zone
	assert_int(m.cards[victim]["ctl"]).is_equal(0)
	assert_str(m.validate(0, {"t": "sacrifice", "uid": victim})).contains("temporarily controlled")
	TB.to_turn2(m)
	assert_int(m.cards[victim]["ctl"]).is_equal(1)


## Takes control of `victim` for player 0 with Hypnotise, into player 0's first free zone (L9: the
## caster picks it).
func _hypnotise(m: MatchEngine, victim: int) -> void:
	var spell := TB.card(m, 0, 180)
	m.players[0]["ap"] = 10
	assert_str(m.submit(0, {"t": "cast", "uid": spell})).is_empty()
	assert_str(TB.choose_uids(m, [victim])).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("slot")
	assert_str(TB.choose(m, [String(m.pending["options"][0]["label"])])).is_empty()


func test_hypnotise_cannot_be_cast_without_a_free_zone() -> void:
	# Ruling 2026-10-16: no target zone, so the Spell cannot be played at all.
	var m := TB.make()
	TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	for s in 6:
		TB.unit(m, 0, TB.WATER, s)
	var spell := TB.card(m, 0, 180)
	m.players[0]["ap"] = 10
	assert_str(m.validate(0, {"t": "cast", "uid": spell})).contains("free zone")


func test_hypnotised_unit_returns_to_its_original_zone() -> void:
	var m := TB.make()
	var victim := TB.unit(m, 1, TB.WATER, 4, "atk", 10)
	_hypnotise(m, victim)
	TB.to_turn2(m)
	assert_int(m.cards[victim]["ctl"]).is_equal(1)
	assert_int(m.cards[victim]["slot"]).is_equal(4)
	assert_int(m.players[1]["units"][4]).is_equal(victim)


func test_hypnotised_unit_goes_to_spent_when_its_zone_was_filled() -> void:
	var m := TB.make()
	var victim := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	_hypnotise(m, victim)
	TB.unit(m, 1, TB.WATER, 0)
	TB.to_turn2(m)
	assert_str(m.cards[victim]["zone"]).is_equal("spent")
	assert_bool(victim in m.players[1]["spent"]).is_true()


func test_hypnotised_unit_keeps_its_statuses_when_it_returns() -> void:
	var m := TB.make()
	var victim := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	_hypnotise(m, victim)
	m.apply_status(victim, "rune", 2)
	TB.to_turn2(m)
	assert_int(m.status_count(victim, "rune")).is_equal(2)


func test_hypnotised_unit_can_be_arcane_material_and_goes_to_its_owners_spent() -> void:
	# Ruling 2026-10-16: it cannot be sacrificed, but it can be tributed (Arcane, Fusion).
	var m := TB.make()
	var victim := TB.unit(m, 1, TB.WATER, 0, "atk", 10)
	m.apply_status(victim, "rune", 3)
	_hypnotise(m, victim)
	var roma := TB.card(m, 0, 96, "extra")
	assert_str(m.submit(0, {"t": "arcane", "uid": roma})).is_empty()
	assert_str(TB.choose_uids(m, [victim])).is_empty()
	TB.choose(m, ["Front row, column 1"])
	TB.choose(m, ["Attack"])
	assert_int(m.atk_of(roma)).is_equal(3 * 10)                # Roma +10 per Rune since 2026-11-03
	assert_bool(victim in m.players[1]["spent"]).is_true()


# ---------------------------------------------------------------- Sneaky Snunday

func _cast(m: MatchEngine, p: int, id: int, target: int = -1) -> int:
	var uid := TB.card(m, p, id)
	m.players[p]["ap"] = 10
	var e := m.submit(p, {"t": "cast", "uid": uid})
	assert_str(e).is_empty()
	if target != -1:
		assert_str(TB.choose_uids(m, [target])).is_empty()   # the target is always the player's choice
	return uid


func test_snunday_reverses_shimmer_serum_atk_but_not_blind() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", 10)
	_cast(m, 0, 154)
	_cast(m, 0, 182, u)
	assert_int(m.atk_of(u)).is_equal(0)
	assert_int(m.status_count(u, "blind")).is_equal(1)


# 2026-10-18: Damage is not a "loss", so Sneaky Snunday no longer turns it into healing. 2026-11-10: the
# Divine Serpent 30-damage combo (the old fixture) is gone; Shaman's Snunday Brew deals the Damage now.
func test_snunday_no_longer_turns_damage_into_healing() -> void:
	var m := TB.make()
	_cast(m, 0, 154)
	var brew := TB.power(m, 0, 167)
	assert_str(TB.ability(m, brew)).is_empty()
	assert_str(TB.choose(m, ["Opponent takes 4 Damage"])).is_empty()
	assert_int(m.players[1]["hp"]).is_equal(GameCore.START_HP - 4)


# L15 (2026-11-05): Sneaky Snunday reverses ATK/DEF only, so the AP next turn is not reversed.
func test_delayed_gratification_under_snunday_still_gives_plus_one_ap() -> void:
	var m := TB.make()
	_cast(m, 0, 154)
	_cast(m, 0, 41)
	assert_str(m.pending["kind"]).is_equal("select")   # which Hand card gets Retain
	m.submit(0, {"t": "choose", "id": m.pending["id"], "indices": [0]})
	TB.to_turn2(m)
	for i in 3:
		m.submit(1, {"t": "next_phase"})
	assert_int(m.active).is_equal(0)
	assert_int(m.players[0]["ap"]).is_equal(GameCore.BASE_AP + 1)


func test_snunday_flips_continuous_aura_while_active_and_restores_after() -> void:
	var m := TB.make()
	TB.unit(m, 0, 159, 0)                       # Divine Serpent - Body: adjacent +8 DEF (2026-11-10)
	var friend := TB.unit(m, 0, TB.WATER, 1, "atk", 8, 20)
	assert_int(m.def_of(friend)).is_equal(20 + 8)
	_cast(m, 0, 154)
	assert_int(m.def_of(friend)).is_equal(20 - 8)
	TB.to_turn2(m)
	assert_int(m.def_of(friend)).is_equal(20 + 8)


# L15 (2026-11-05): "all new and ongoing" gains are reversed, so a gain from before Snunday is too.
func test_snunday_reverses_an_already_resolved_gain() -> void:
	var m := TB.make()
	var u := TB.unit(m, 0, TB.WATER, 0, "atk", 10)
	_cast(m, 0, 182, u)                         # Shimmer Serum +10 before the reversal
	assert_int(m.atk_of(u)).is_equal(20)
	_cast(m, 0, 154)
	assert_int(m.atk_of(u)).is_equal(0)


func test_snunday_does_not_reverse_battle_damage_or_ap_payment() -> void:
	var m := TB.make()
	TB.to_turn2(m)
	var spell := TB.card(m, 1, 154)
	m.submit(1, {"t": "cast", "uid": spell})
	assert_int(m.players[1]["ap"]).is_equal(1)
	TB.to_battle(m)
	var a := TB.unit(m, 1, TB.WATER, 0, "atk", 12)
	TB.attack(m, a, -1)
	assert_int(m.players[0]["hp"]).is_equal(48)


func test_controller_orders_own_simultaneous_triggers() -> void:
	var m := TB.make()
	# 2026-11-17: Accursed Zealot (the old start-of-turn Rune) is now Pickpocket, with no turn-start trigger;
	# Muscle of the Marked Claw (new) blinds itself at the start of its controller's turn.
	var muscle := TB.unit(m, 1, 198, 0)                 # start of turn: Blind
	var neva := TB.unit(m, 1, 161, 1)                   # start of turn: Eternal
	TB.to_turn2(m)
	assert_str(m.pending["kind"]).is_equal("order")
	TB.choose(m, ["Neva"])
	assert_int(TB.log_index(m, "Neva the Divine Mother gains 1 Eternal")).is_less(TB.log_index(m, "Muscle of the Marked Claw gains 1 Blind"))
	assert_int(m.status_count(muscle, "blind")).is_equal(1)
	assert_int(m.status_count(neva, "eternal")).is_equal(1)
