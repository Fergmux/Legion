extends GdUnitTestSuite
## M batch (owner feedback 9 Nov 2026).
## M6: every inspect entry point draws a card's rules as the same coloured timing sections, because
##     MatchView.summary_view (draft, rewards, deck builder, card list) carries the same text_parts
##     and abilities as MatchView.def_view (game log, draft list, transform preview).
## M8: card lists order by kind first (CardDB.KIND_ORDER), so the 3 Nov cards with no sheet index
##     (Owlbear Druid, Snow Tiger Paladin: Fusions; Do Not Open Box: a Trap) sit with their kind. The
##     10 Nov cards have no sheet index either (Mithral Dome: a Power; A Great Heist: a Spell; Trap Hole
##     of Suppression / of Spikes: Traps; Divine Serpent - Tail: a Unit; The Great Leviathan: a Unit,
##     transformation-only, so not collectible). The 17 Nov cards have no sheet index either (Muscle of the
##     Marked Claw: a Unit; Angered / Bloodlust Komodo and Zadus: Units, transformation-only; Heretic of the
##     Divine Order and Soul of Burning Revenge: Spirits).

const OWLBEAR := 189
const SNOW_TIGER := 190
const BOX := 191
const MITHRAL_DOME := 192
const GREAT_HEIST := 193
const TH_SUPPRESSION := 194
const TH_SPIKES := 195
const SERPENT_TAIL := 196
const LEVIATHAN := 197
const MUSCLE := 198
const ANGERED_KOMODO := 199
const ENRAGED_KOMODO := 200
const HERETIC := 201
const BURNING_SOUL := 202
const ZADUS := 203


# ---------------------------------------------------------------- M6

func test_summary_view_and_def_view_give_identical_rule_sections_for_every_card() -> void:
	var n := 0
	for d in CardDB.all():
		var id := int(d["id"])
		var sv := MatchView.summary_view(Series.card_summary(id))
		var dv := MatchView.def_view(id)
		assert_array(sv.get("text_parts", [])).override_failure_message("text_parts differ for card %d" % id).is_equal(dv["text_parts"])
		assert_array(sv.get("abilities", [])).override_failure_message("abilities differ for card %d" % id).is_equal(dv.get("abilities", []))
		assert_str(String(sv["text"])).is_equal(String(dv["text"]))
		n += 1
	assert_int(n).is_equal(203)                           # 191 + the six cards of 2026-11-10 + six of 2026-11-17


func test_spawn_and_larva_both_have_separate_sections() -> void:
	# The owner's example: Symbiote Spawn showed one "Rules" block, Larva (def_view) separate ones.
	var spawn := MatchView.summary_view(Series.card_summary(155))
	assert_int((spawn["text_parts"] as Array).size()).is_greater(1)
	assert_int((MatchView.def_view(156)["text_parts"] as Array).size()).is_greater(1)


# ---------------------------------------------------------------- M8

func _ids(defs: Array) -> Array:
	return defs.map(func(d): return int(d["id"]))


func test_collectible_is_grouped_by_kind_in_kind_order() -> void:
	var defs := CardDB.collectible()
	var last := -1
	for d in defs:
		var r := CardDB.kind_rank(String(d["category"]))
		assert_int(r).is_greater_equal(last)
		last = r


func test_new_cards_sit_among_their_kind() -> void:
	var ids := _ids(CardDB.collectible())
	var fusions := _ids(CardDB.collectible().filter(func(d): return d["category"] == "fusion"))
	var traps := _ids(CardDB.collectible().filter(func(d): return d["category"] == "trap"))
	var units := _ids(CardDB.collectible().filter(func(d): return d["category"] == "unit"))
	var spells := _ids(CardDB.collectible().filter(func(d): return d["category"] == "spell"))
	var powers := _ids(CardDB.collectible().filter(func(d): return d["category"] == "power"))
	# Unindexed cards come last within their kind, by id.
	assert_array(fusions.slice(fusions.size() - 2)).is_equal([OWLBEAR, SNOW_TIGER])
	assert_array(traps.slice(traps.size() - 3)).is_equal([BOX, TH_SUPPRESSION, TH_SPIKES])
	assert_array(units.slice(units.size() - 2)).is_equal([SERPENT_TAIL, MUSCLE])
	var spirits := _ids(CardDB.collectible().filter(func(d): return d["category"] == "spirit"))
	assert_array(spirits.slice(spirits.size() - 2)).is_equal([HERETIC, BURNING_SOUL])
	assert_int(spells[-1]).is_equal(GREAT_HEIST)
	assert_int(powers[-1]).is_equal(MITHRAL_DOME)
	for id in [LEVIATHAN, ANGERED_KOMODO, ENRAGED_KOMODO, ZADUS]:
		assert_bool(ids.has(id)).override_failure_message("%d is transformation-only" % id).is_false()
	# The unindexed Traps come right after the last indexed Trap, before the first Power.
	var first_power: int = powers[0]
	assert_int(ids.find(TH_SPIKES) + 1).is_equal(ids.find(first_power))
	# The two Fusions come before the first Arcane.
	var first_arcane: int = _ids(CardDB.collectible().filter(func(d): return d["category"] == "arcane"))[0]
	assert_int(ids.find(SNOW_TIGER) + 1).is_equal(ids.find(first_arcane))


func test_within_a_kind_the_source_order_is_kept() -> void:
	var defs := CardDB.collectible()
	for i in range(1, defs.size()):
		var a: Dictionary = defs[i - 1]
		var b: Dictionary = defs[i]
		if a["category"] != b["category"]:
			continue
		assert_bool(CardDB._order_before(a, b)).is_true()


func test_all_keeps_plain_source_order_for_rules_code() -> void:
	var ids := _ids(CardDB.all())
	assert_array(ids.slice(ids.size() - 15)).is_equal([OWLBEAR, SNOW_TIGER, BOX, MITHRAL_DOME, GREAT_HEIST,
		TH_SUPPRESSION, TH_SPIKES, SERPENT_TAIL, LEVIATHAN, MUSCLE, ANGERED_KOMODO, ENRAGED_KOMODO, HERETIC,
		BURNING_SOUL, ZADUS])


func test_browser_catalogue_index_and_deck_list_follow_catalogue_order() -> void:
	var idx := CardBrowser.catalogue_index()
	assert_int(int(idx[BOX])).is_less(int(idx[OWLBEAR]))
	var first_power: int = _ids(CardDB.collectible().filter(func(d): return d["category"] == "power"))[0]
	assert_int(int(idx[BOX])).is_less(int(idx[first_power]))
	# A deck holding a Power, the Box and an Arcane lists the Box first (it is a Trap).
	var first_arcane: int = _ids(CardDB.collectible().filter(func(d): return d["category"] == "arcane"))[0]
	var deck := [first_arcane, first_power, BOX]
	assert_array(DeckBuilder.catalogue_sorted(deck, idx)).is_equal([BOX, first_power, first_arcane])
	assert_array(CardDB.sort_ids(deck)).is_equal([BOX, first_power, first_arcane])
	# Extra Deck: the new Fusions before every Arcane and Spirit.
	var extra := [first_arcane, SNOW_TIGER, OWLBEAR]
	assert_array(DeckBuilder.catalogue_sorted(extra, idx)).is_equal([OWLBEAR, SNOW_TIGER, first_arcane])


func test_sort_ids_keeps_duplicates_and_puts_unknown_ids_last() -> void:
	assert_array(CardDB.sort_ids([999999, BOX, 1, BOX])).is_equal([1, BOX, BOX, 999999])


func test_match_extra_deck_view_lists_in_catalogue_order() -> void:
	var first_arcane: int = _ids(CardDB.collectible().filter(func(d): return d["category"] == "arcane"))[0]
	var deck := [first_arcane, SNOW_TIGER, 1, 1, 1, OWLBEAR]
	var m := MatchEngine.new()
	m.setup([deck, deck.duplicate()], 0, 7)
	var v := MatchView.build(m, 0)
	var shown: Array = v["players"][0]["extra"].map(func(c): return int(c["id"]))
	assert_array(shown).is_equal([OWLBEAR, SNOW_TIGER, first_arcane])
