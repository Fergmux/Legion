extends GdUnitTestSuite
## N batch (owner feedback 16 Nov 2026, items A1-A8): the series modal's waiting screens carry the
## rewards footer's View your deck button and no status chips or "(N cards)" suffix; the in-game menu
## has no "Game N · first to N wins" line; the remove-a-card list is in catalogue order; the waiting
## line's dots no longer move its text; the pile viewer has no hint line and a pile no tooltip.
## Story: design/owner-feedback-2026-11-16.md A1-A8.

const DIR := "user://test_saves_nbatch_a"


func before_test() -> void:
	SeriesStore.DIR = DIR
	DirAccess.make_dir_recursive_absolute(DIR)


func after_test() -> void:
	for fn in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, fn])


func _series(deck_mode: String = "starter") -> Series:
	var s := Series.new()
	s.setup({"seed": 22, "best_of": 7, "deck_mode": deck_mode, "names": ["Ann", "Bea"], "mode": "local"})
	return s


func _host(s: Series) -> LocalHost:
	var host: LocalHost = auto_free(LocalHost.new())
	add_child(host)
	host.start({"resume": s})
	return host


func _screen(host: LocalHost, seat: int = 0) -> GameScreen:
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = Vector2(1600, 900)
	add_child(gs)
	await gs.attach(host.seats[seat])
	for i in 4:
		await await_idle_frame()
	return gs


func _texts(n: Node) -> Array:
	return n.find_children("*", "Label", true, false).map(func(l): return (l as Label).text).filter(func(t): return t != "")


func _view_deck_button(gs: GameScreen) -> Button:
	var found := gs.overlays.overlay_box.find_children("ViewDeckButton", "Button", true, false)
	return found[0] if not found.is_empty() else null


# ---------------------------------------------------------------- A1 / A2 / A3

func test_deck_locked_in_wait_has_view_deck_and_no_chips() -> void:
	# Arrange: Ann has locked in a Structure deck, Bea has not.
	var s := _series()
	s.submit(0, {"t": "pick_starter", "index": 0})
	var gs := await _screen(_host(s))
	# Act
	var see := _view_deck_button(gs)
	var plates := gs.overlays.overlay_box.find_children("*", "WaitPlate", true, false)
	# Assert
	assert_object(see).is_not_null()
	assert_str(see.text).is_equal("View your deck")
	assert_int(plates.size()).is_equal(1)
	assert_array((plates[0] as Node).find_children("*", "StatusDot", true, false)).is_empty()
	assert_bool(_texts(gs.overlays.overlay_box).any(func(t): return t.to_lower().contains("deck locked in") and t.contains(":"))).is_false()


func test_drafted_deck_wait_line_has_no_card_count() -> void:
	# Arrange: a draft series whose seat 0 has locked in (the wait reads "your drafted deck").
	var s := _series("draft")
	s.deck_ready[0] = true
	s.decks[0] = s.decks[0] if not s.decks[0].is_empty() else [1, 1, 1]
	var gs := await _screen(_host(s))
	# Act
	var txt := _texts(gs.overlays.overlay_box)
	# Assert
	assert_bool(txt.any(func(t): return t.contains("your drafted deck."))).is_true()
	assert_bool(txt.any(func(t): return t.contains(" cards)"))).is_false()


func test_next_game_wait_has_the_footer_view_deck_button_and_no_chips() -> void:
	# Arrange: Ann won game 1 (Bea conceded), both finished rewards, Ann pressed Start.
	var s := _series()
	s.submit(0, {"t": "pick_starter", "index": 0})
	s.submit(1, {"t": "pick_starter", "index": 1})
	s.submit(1, {"t": "concede"})
	s.submit(0, {"t": "reward_finish"})
	s.submit(1, {"t": "reward_finish"})
	s.submit(0, {"t": "start_duel"})
	var gs := await _screen(_host(s))
	# Act
	var see := _view_deck_button(gs)
	var plates := gs.overlays.overlay_box.find_children("*", "WaitPlate", true, false)
	# Assert
	assert_str(String(gs.view["stage"])).is_equal("first_player")
	assert_object(see).is_not_null()
	assert_float(see.custom_minimum_size.x).is_equal(GameRewardPanels.FOOTER_BUTTON_W)
	assert_int(plates.size()).is_equal(1)
	assert_array((plates[0] as Node).find_children("*", "StatusDot", true, false)).is_empty()


func test_view_deck_popup_title_has_no_card_count() -> void:
	# Arrange
	var s := _series()
	s.submit(0, {"t": "pick_starter", "index": 0})
	s.submit(1, {"t": "pick_starter", "index": 1})
	s.submit(1, {"t": "concede"})
	var gs := await _screen(_host(s))
	# Act
	_view_deck_button(gs).pressed.emit()
	await await_idle_frame()
	# Assert
	assert_bool(gs.overlays.pile_popup.visible).is_true()
	var txt := _texts(gs.overlays.pile_box)
	assert_bool(txt.has("Your deck")).is_true()
	assert_bool(txt.any(func(t): return t.begins_with("Your deck ("))).is_false()


# ---------------------------------------------------------------- A4

func test_series_status_is_empty_while_the_series_is_played() -> void:
	var md := {"over": false, "winner": -1, "current": 0, "need": 4, "names": ["Ann", "Bea"]}
	assert_str(GameMenu.series_status_text(md)).is_equal("")
	md["over"] = true
	md["winner"] = 0
	assert_str(GameMenu.series_status_text(md)).is_equal("Ann wins the series")


# ---------------------------------------------------------------- A6

func test_remove_list_is_in_catalogue_order_once_per_card() -> void:
	# Arrange: a deck in the order its cards were added (a reward card last), with duplicates.
	var ids := [110, 13, 1, 40, 13, 1, 74]
	var deck := ids.map(func(i): return Series.card_summary(i))
	deck.append(Series.card_summary(102))
	# Act
	var order := GameRewardPanels.remove_order(deck).map(func(c): return int(c["id"]))
	# Assert
	var want := CardDB.sort_ids([110, 13, 1, 40, 74, 102])
	assert_array(order).is_equal(want)


# ---------------------------------------------------------------- A7

func test_waiting_dots_keep_one_text_and_reveal_the_dots() -> void:
	# Arrange
	var was := UIStyle.reduce_motion
	UIStyle.reduce_motion = false
	var wd: WaitingDots = auto_free(WaitingDots.new("Waiting for your opponent", 20))
	var texts := {}
	var shown := []
	# Act
	for n in 4:
		wd._refresh(n)
		texts[wd.text] = true
		shown.append(wd.visible_characters)
	UIStyle.reduce_motion = was
	# Assert: the text (so its centred layout) never changes; only the dots are revealed.
	var base := "Waiting for your opponent".length()
	assert_array(texts.keys()).is_equal(["Waiting for your opponent..."])
	assert_array(shown).is_equal([base, base + 1, base + 2, base + 3])
	assert_int(wd.visible_characters_behavior).is_equal(TextServer.VC_CHARS_AFTER_SHAPING)


# ---------------------------------------------------------------- A8

func test_pile_stack_has_no_tooltip() -> void:
	var ps: PileStack = auto_free(PileStack.new())
	ps.set_pile(8, true)
	assert_str(ps.tooltip_text).is_equal("")


func test_pile_viewers_have_no_hint_line() -> void:
	# Arrange: game 1 under way.
	var s := _series()
	s.submit(0, {"t": "pick_starter", "index": 0})
	s.submit(1, {"t": "pick_starter", "index": 1})
	var host := _host(s)
	var gs := await _screen(host, s.game.active)
	# Act: the side-pane pile list, then the pile browser.
	gs.details.show_pile("draw")
	await await_idle_frame()
	var list_hint_visible := gs.details.pile_hint.visible
	gs.details.close_pile()
	assert_bool(gs.inspect.open_pile("draw")).is_true()
	await await_idle_frame()
	# Assert
	assert_bool(list_hint_visible).is_false()
	assert_str(gs.inspect.browser._hint_label.text).is_equal("")
	gs.inspect.close_all()
