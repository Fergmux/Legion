extends GdUnitTestSuite
## N batch (owner feedback, design/owner-feedback-2026-11-16.md), UI items B1-B9: the details pane's
## empty state has no sub line, ?/? units colour their stats against the base they were given, a
## rules part splits its Once-per-turn sentences from its passive ones (Dante), the opponent's chosen
## targets are public in a Trap response window (Assassinate), Reveal reads "Permanent", next turn's
## promised AP shows as pending gem sockets, and the game log can hide to a thin bar.

const DANTE := 36
const ASSASSINATE := 84
const ENERGY_DISPEL := 140      # answers any activated effect (Energy Capture only answers Runes / Spirit summons since 2026-11-17)

var _was_hidden: bool


func before_test() -> void:
	_was_hidden = GameLog.hidden()


func after_test() -> void:
	GameLog.store_hidden(_was_hidden)


# ---------------------------------------------------------------- B1

func test_details_empty_state_has_no_sub_line() -> void:
	var art: DetailsEmptyArt = auto_free(DetailsEmptyArt.new())
	assert_str(art.sub).is_empty()
	assert_str(art.hint).is_not_empty()


# ---------------------------------------------------------------- B3

func _field_unit(atk, def, printed_atk, printed_def, base_atk = null, base_def = null) -> Dictionary:
	var v := {"zone": "unit", "atk": atk, "def": def, "printed_atk": printed_atk, "printed_def": printed_def}
	if base_atk != null:
		v["base_atk"] = base_atk
	if base_def != null:
		v["base_def"] = base_def
	return v


func test_question_mark_unit_trend_compares_with_its_given_base() -> void:
	# Ultimate Dragon (?/?) became 30/24 on arrival, then +6 ATK and -4 DEF from effects.
	var v := _field_unit(36, 20, null, null, 30, 24)
	assert_int(CardStatBadge.trend(v, true)).is_equal(1)
	assert_int(CardStatBadge.trend(v, false)).is_equal(-1)
	# Unchanged from its base: no colour.
	assert_int(CardStatBadge.trend(_field_unit(30, 24, null, null, 30, 24), true)).is_equal(0)


func test_printed_unit_trend_still_compares_with_printed_stats() -> void:
	var v := _field_unit(10, 6, 8, 8)
	assert_int(CardStatBadge.trend(v, true)).is_equal(1)
	assert_int(CardStatBadge.trend(v, false)).is_equal(-1)
	# Off the Field nothing is coloured.
	v["zone"] = "hand"
	assert_int(CardStatBadge.trend(v, true)).is_equal(0)


# ---------------------------------------------------------------- B4

func test_dante_once_per_turn_and_on_field_are_separate_blocks() -> void:
	var v := MatchView.def_view(DANTE)
	var keys := []
	for part in v["text_parts"]:
		for p in CardDetailsPanel.split_timings(part):
			keys.append(String(p["k"]))
	assert_array(keys).is_equal(["Materials", "On Summon", "Once per turn", "On Field", "On Destruction"])
	var p: CardDetailsPanel = auto_free(CardDetailsPanel.new())
	p.show_card(v)
	assert_int(p.count_text("You can apply 1 Cleanse or 5 Burn to a Unit.")).is_equal(1)
	assert_int(p.count_text("This Unit gains +2 ATK for each Burn on this Unit.")).is_equal(1)


func test_two_once_per_turn_sentences_make_two_blocks() -> void:
	var parts := CardDetailsPanel.split_timings({"k": "On Field",
		"t": "Once per turn: you can apply 1 Paralyse to a Unit. Once per turn: you can apply 1 Infiltrate to a Unit."})
	assert_int(parts.size()).is_equal(2)
	assert_str(String(parts[0]["t"])).is_equal("You can apply 1 Paralyse to a Unit.")
	assert_str(String(parts[1]["t"])).is_equal("You can apply 1 Infiltrate to a Unit.")


func test_part_without_once_per_turn_is_one_block() -> void:
	var parts := CardDetailsPanel.split_timings({"k": "On Field", "t": "This Unit is Unaffected. It cannot attack."})
	assert_int(parts.size()).is_equal(1)
	assert_str(String(parts[0]["k"])).is_equal("On Field")
	assert_str(String(parts[0]["t"])).is_equal("This Unit is Unaffected. It cannot attack.")


# ---------------------------------------------------------------- B5

func test_trap_window_shows_the_opponents_chosen_target() -> void:
	var m := TB.make()
	var victim := TB.unit(m, 1, TB.FILLER, 1)
	TB.set_card(m, 1, ENERGY_DISPEL, 0)
	TB.cast(m, 0, ASSASSINATE)
	assert_str(TB.choose_uids(m, [victim])).is_empty()
	assert_str(TB.pend_kind(m)).is_equal("trap_response")
	var pd: Dictionary = MatchView.build(m, 1)["pending"]
	assert_array(pd["cause"].get("targets", [])).is_equal([{"p": 1, "zone": "unit", "slot": 1}])


func test_trap_window_without_a_chosen_target_has_none() -> void:
	var m := TB.make()
	TB.unit(m, 1, TB.FILLER, 1)
	var ev := {"name": "activate", "player": 0, "card": -1}
	assert_array(MatchView.event_targets(m, {"event": ev, "source": -1})).is_empty()
	assert_array(MatchView.event_targets(m, {"event": {"name": "attack"}})).is_empty()


# ---------------------------------------------------------------- B6

func test_reveal_help_says_permanent() -> void:
	assert_str(String(CardDB.STATUS_HELP["reveal"])).contains("Permanent")
	assert_str(String(CardDB.STATUS_HELP["reveal"]).to_lower()).not_contains("no duration")


# ---------------------------------------------------------------- B8

func test_next_turn_ap_adds_pending_gem_sockets() -> void:
	var plate: PlayerPlate = auto_free(PlayerPlate.new())
	plate.update_from({"name": "P", "hp": 60, "ap": 1, "ap_start": 2, "ap_peak": 2,
		"ap_next": [{"n": 1, "src": "Delayed Gratification"}]}, true, true, "", "")
	assert_int(plate.ap_gems.slots()).is_equal(2)
	assert_int(plate.ap_gems.total_slots()).is_equal(3)
	assert_str(plate.ap_gems.tooltip_text).contains("+1 AP at the start of your next turn")
	assert_str(plate.next_label.text).is_empty()
	# Next turn begins: the promise is spent, the extra socket goes.
	plate.update_from({"name": "P", "hp": 60, "ap": 3, "ap_start": 3, "ap_peak": 3, "ap_next": []}, true, true, "", "")
	assert_int(plate.ap_gems.total_slots()).is_equal(3)
	assert_int(plate.ap_gems.ap_bonus).is_equal(0)


func test_net_ap_loss_adds_no_sockets() -> void:
	assert_int(PlayerPlate.next_ap({"ap_next": [{"n": 2}, {"n": -1}]})).is_equal(1)
	var g: ApGemRow = auto_free(ApGemRow.new())
	g.set_values(2, 2, 2, true)
	g.set_bonus(-1)
	assert_int(g.total_slots()).is_equal(2)


# ---------------------------------------------------------------- B9

func test_hidden_log_has_no_height_share() -> void:
	assert_float(GameSidebar.log_height(1000.0, false, true)).is_equal(0.0)
	assert_float(GameSidebar.log_height(1000.0, true, true)).is_equal(0.0)
	assert_float(GameSidebar.log_height(1000.0)).is_greater(0.0)


func test_hidden_log_choice_is_saved_and_shown_by_default() -> void:
	var cf := ConfigFile.new()
	cf.load(GameLog.settings_path())
	if cf.has_section_key(GameLog.SIZE_SECTION, GameLog.HIDDEN_KEY):
		cf.erase_section_key(GameLog.SIZE_SECTION, GameLog.HIDDEN_KEY)
	cf.save(GameLog.settings_path())
	GameLog._hidden_loaded = false
	assert_bool(GameLog.hidden()).is_false()
	GameLog.store_hidden(true)
	GameLog._hidden_loaded = false
	GameLog._hidden = false
	assert_bool(GameLog.hidden()).is_true()


func test_hide_button_folds_the_log_to_its_header() -> void:
	GameLog.store_hidden(false, false)
	var log := GameLog.new(null)
	var col: VBoxContainer = auto_free(VBoxContainer.new())
	log.build(col)
	assert_bool(log.well.visible).is_true()
	assert_str(log.hide_btn.text).is_equal("Hide")
	log.set_hidden(true, false)
	assert_bool(log.well.visible).is_false()
	assert_bool(log.toggle.visible).is_false()
	assert_str(log.hide_btn.text).is_equal("Show")
	log.set_hidden(false, false)
	assert_bool(log.well.visible).is_true()
	assert_bool(log.toggle.visible).is_true()
