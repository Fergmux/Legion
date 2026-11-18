extends GdUnitTestSuite
## Owner feedback of 18 Nov 2026 (design/owner-feedback-2026-11-18.md), P batch items B1, B2, B8, B9:
## the pile row tooltip's coloured identity chips, status options styled like Type options, the
## card list's cost order (Basic units first) and the catalogue facts without the kind line.

const ULTIMATE_DRAGON := 151
const BASIC_MAGE := 1   # Basic Unit, 1 AP, Mage, Water


func _chip_texts(n: Node) -> Array:
	return n.find_children("*", "Label", true, false).map(func(l): return String((l as Label).text))


# ---------------------------------------------------------------- B1

func test_b1_card_tooltip_shows_the_identity_as_coloured_chips() -> void:
	# Arrange: a unit (category, cost, Race and Type)
	var v := MatchView.def_view(BASIC_MAGE)
	# Act
	var t: Control = auto_free(StatusHelp.card_tooltip(v))
	# Assert: the kind line is a row of chips, the Type chip in the Type's colour
	var kind := t.find_child("TipKind", true, false)
	assert_object(kind).is_instanceof(HFlowContainer)
	var ty := String(v["type"])
	var type_chip: PanelContainer = null
	for chip in kind.get_children():
		if _chip_texts(chip).has(ty):
			type_chip = chip
	assert_object(type_chip).is_not_null()
	var sb := type_chip.get_theme_stylebox("panel") as StyleBoxFlat
	assert_float(sb.border_color.r).is_equal_approx(UIStyle.type_color(ty).r, 0.01)
	assert_float(sb.border_color.b).is_equal_approx(UIStyle.type_color(ty).b, 0.01)
	assert_array(_chip_texts(kind)).contains([String(v["race"])])


func test_b1_identity_chips_match_the_details_panel_chips() -> void:
	# Arrange
	var v := MatchView.def_view(ULTIMATE_DRAGON)
	var panel: CardDetailsPanel = auto_free(CardDetailsPanel.new())
	# Act
	var mine: Control = auto_free(CardDetailsPanel.identity_chips(v))
	var theirs: Control = auto_free(panel.identity_badges(v))
	# Assert: the same chips in the same order
	assert_array(_chip_texts(mine)).is_equal(_chip_texts(theirs))


# ---------------------------------------------------------------- B2

func test_b2_status_key_of_reads_status_option_labels() -> void:
	assert_str(GamePromptBanner.status_key_of("1 Burn")).is_equal("burn")
	assert_str(GamePromptBanner.status_key_of("2 Infiltrate")).is_equal("infiltrate")
	assert_str(GamePromptBanner.status_key_of("Nimble")).is_equal("nimble")
	assert_str(GamePromptBanner.status_key_of("Apply 1 Burn to a unit")).is_equal("")
	assert_str(GamePromptBanner.status_key_of("Fire")).is_equal("")


func test_b2_a_mode_choice_of_statuses_is_a_status_choice() -> void:
	# Arrange: the options of Heretic of the Divine Order's buff ability (CardScripts.ANY_BUFF)
	var opts := []
	for o in CardScripts.ANY_BUFF:
		opts.append({"label": o["label"]})
	# Act / Assert
	assert_bool(GamePromptBanner.is_status_choice({"kind": "mode", "options": opts})).is_true()
	assert_bool(GamePromptBanner.is_status_choice({"kind": "mode", "options": [{"label": "1 Burn"}, {"label": "Draw a card"}]})).is_false()
	assert_bool(GamePromptBanner.is_status_choice({"kind": "confirm", "options": opts})).is_false()
	assert_bool(GamePromptBanner.is_type_choice({"kind": "mode", "options": opts})).is_false()


func test_b2_status_button_is_tinted_in_the_status_colour_with_its_badge() -> void:
	# Act
	var b: Button = auto_free(GamePromptBanner.status_button("1 Poison", 15))
	# Assert: the rim in the status accent, the badge where the Type icon sits, the label kept
	var acc := CardStatusIcons.accent("poison")
	var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
	assert_float(sb.border_color.g).is_equal_approx(acc.lightened(0.1).g, 0.01)
	assert_str(b.text).is_equal("1 Poison")
	var icons := b.get_children().filter(func(c): return c is CardStatusIcons.Token)
	assert_int(icons.size()).is_equal(1)
	assert_str((icons[0] as CardStatusIcons.Token).key).is_equal("poison")


# ---------------------------------------------------------------- B8

func test_b8_cost_order_puts_basic_units_first_then_cheaper_cards() -> void:
	# Arrange
	var idx := CardBrowser.catalogue_index()
	var basic := {"id": 1, "category": "basic_unit", "cost_kind": "ap", "cost": 3}
	var cheap := {"id": 2, "category": "spell", "cost_kind": "ap", "cost": 1}
	var dear := {"id": 3, "category": "unit", "cost_kind": "ap", "cost": 4}
	var fusion := {"id": 4, "category": "fusion", "cost_kind": "fusion", "cost": null}
	# Act
	var order := [fusion, dear, cheap, basic]
	order.sort_custom(func(a, b): return CardBrowser.cost_before(a, b, idx))
	# Assert
	assert_array(order.map(func(d): return int(d["id"]))).is_equal([1, 2, 3, 4])


func test_b8_card_list_opens_sorted_by_cost_basics_first() -> void:
	# Arrange / Act
	var s: CardListScreen = auto_free(CardListScreen.new())
	add_child(s)
	# Assert: every Basic unit before the rest, then AP costs never decreasing
	var defs: Array = s.browser.visible_ids().map(func(id): return CardDB.get_def(int(id)))
	var basics := defs.filter(func(d): return String(d["category"]) == "basic_unit")
	assert_int(basics.size()).is_greater(0)
	assert_array(defs.slice(0, basics.size())).is_equal(basics)
	for group in [basics, defs.slice(basics.size())]:
		var last := -1.0
		for d in group:
			var c: float = float(d["cost"]) if String(d["cost_kind"]) == "ap" and d["cost"] != null else 1000.0
			assert_float(c).is_greater_equal(last)
			last = c
	assert_str(String(s.browser.sort_opt.get_item_metadata(s.browser.sort_opt.selected))).is_equal("cost")


# ---------------------------------------------------------------- B9

func test_b9_catalogue_facts_have_no_kind_line() -> void:
	var f: PreviewFacts = auto_free(PreviewFacts.new(false))
	f.show_card(ULTIMATE_DRAGON, true)
	assert_object(f.find_child("Kind", true, false)).is_null()
	for l in _chip_texts(f):
		assert_str(String(l)).not_contains("Fusion summon")


func test_b9_card_list_details_pane_is_wider() -> void:
	assert_int(CardListScreen.PREVIEW_W).is_greater_equal(460)
