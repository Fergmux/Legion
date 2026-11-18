extends GdUnitTestSuite
## Owner feedback of 18 Nov 2026 (design/owner-feedback-2026-11-18.md), P batch items B3-B6 on the
## match screen: the draft list gives way to card details when the game starts, the hover preview
## in the details panel, empty zones as bare table, and the Chat / Appendix icon buttons.

var host: LocalHost
var gs: GameScreen
var m: MatchEngine


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	UIStyle.reduce_motion = true
	host = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 11, "best_of": 1, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	m = host.series.game
	gs = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 1000)
	add_child(gs)
	await gs.attach(host.seats[m.active])
	await await_idle_frame()


func after_test() -> void:
	UIStyle.reduce_motion = false


## An empty unit zone of mine: its background widget.
func _empty_zone_bg() -> CardWidget:
	for k in gs.board.slots.keys():
		var sl: Dictionary = gs.board.slots[k]
		if (k as String).begins_with("1:unit:") and not (sl["widget"] as CardWidget).visible:
			return sl["bg"]
	return null


# ---------------------------------------------------------------- B3

func test_b3_draft_list_left_open_when_the_game_starts_returns_to_card_details() -> void:
	# Arrange: the panel still holds the draft list (the game began in the update that ended my draft)
	gs.details.pile_zone = GameDetails.DRAFT_ZONE
	gs.details.render_pile_list()
	assert_bool(gs.details.pile_scroll.visible).is_true()
	# Act
	gs.render_all()
	# Assert: the normal card details panel
	assert_str(gs.details.pile_zone).is_equal("")
	assert_bool(gs.details.pile_scroll.visible).is_false()
	assert_bool(gs.details.details_scroll.visible).is_true()
	assert_str(gs.details.details_title.text).is_equal("Card details")


# ---------------------------------------------------------------- B4

func test_b4_hovering_with_nothing_selected_shows_the_hovered_card() -> void:
	# Arrange
	var uid: int = gs.hand.order[0]
	# Act
	gs.hover.debug_hover_hand(0)
	await await_idle_frame()
	# Assert
	assert_int(gs.details.details_uid()).is_equal(uid)
	assert_str(gs.details.details_view.all_text()).contains(String(gs.details.find_card(uid)["name"]))
	gs.hover.debug_clear()


func test_b4_a_selected_card_stays_shown_while_another_is_hovered() -> void:
	# Arrange
	var first: int = gs.hand.order[0]
	gs.selection.on_widget_pressed(gs.hand.items[first]["widget"])
	await await_idle_frame()
	# Act
	gs.hover.debug_hover_hand(gs.hand.order.size() - 1)
	await await_idle_frame()
	# Assert
	assert_int(gs.details.details_uid()).is_equal(first)
	gs.hover.debug_clear()


func test_b4_an_open_pile_list_keeps_the_panel_while_hovering() -> void:
	gs.details.show_pile("spent")
	gs.hover.debug_hover_hand(0)
	await await_idle_frame()
	assert_int(gs.details.details_uid()).is_equal(-1)
	assert_bool(gs.details.pile_scroll.visible).is_true()
	gs.hover.debug_clear()


# ---------------------------------------------------------------- B5

func test_b5_an_empty_zone_has_no_pointer_cursor() -> void:
	var bg := _empty_zone_bg()
	assert_object(bg).is_not_null()
	assert_int(bg.mouse_default_cursor_shape).is_equal(Control.CURSOR_ARROW)


func test_b5_clicking_an_empty_zone_deselects() -> void:
	# Arrange
	var first: int = gs.hand.order[0]
	gs.selection.on_widget_pressed(gs.hand.items[first]["widget"])
	await await_idle_frame()
	assert_int(gs.selected_uid).is_equal(first)
	# Act
	gs.selection.on_widget_pressed(_empty_zone_bg())
	await await_idle_frame()
	# Assert
	assert_int(gs.selected_uid).is_equal(-1)
	assert_object(gs.action_row.stack).is_null()


# ---------------------------------------------------------------- B6

func test_b6_chat_is_an_icon_button() -> void:
	assert_str(gs.chat.button.text).is_equal("")
	assert_object(gs.chat.button.find_child("ChatIcon", false, false)).is_not_null()
	assert_vector(gs.chat.button.custom_minimum_size).is_equal(GameMenu.MENU_BUTTON)


func test_b6_appendix_icon_button_sits_before_menu_and_opens_the_reference() -> void:
	# Arrange
	var b := gs.appendix.button
	assert_bool(b.is_visible_in_tree()).is_true()
	assert_str(b.text).is_equal("")
	assert_int(b.get_index()).is_equal(gs.menu.menu_button.get_index() - 1)
	# Act
	b.pressed.emit()
	await await_idle_frame()
	# Assert: open, one row per status and Runes, and the Type cycle
	assert_bool(gs.appendix.is_open()).is_true()
	var rows := gs.appendix.panel.find_children("Status_*", "HBoxContainer", true, false)
	assert_int(rows.size()).is_equal(CardDB.STATUS_ORDER.size() + 1)
	assert_int(gs.appendix.panel.find_child("TypeCycle", true, false).get_child_count()).is_equal(CardDB.TYPE_ADVANTAGE.size())
	# Act: the button again closes it
	b.pressed.emit()
	await await_millis(400)
	assert_bool(gs.appendix.is_open()).is_false()
