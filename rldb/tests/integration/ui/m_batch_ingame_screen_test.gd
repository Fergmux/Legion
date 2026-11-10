extends GdUnitTestSuite
## M batch (owner feedback 9 Nov 2026), the in-match screen:
## M1 the open in-game menu takes clicks (its outside-click catcher sits under it in tree order) and a
## click off it still closes it; M4 the series score lives in the in-game menu, not the top strip;
## M9 neither player plate overlaps a zone, and the icon Menu button sits left of the opponent's plate
## with the menu opening under it; M13 the table light is a round glow over the field's centre.
## Story: production/m-batch-brief.md, items M1 M4 M9 M13.

const DIR := "user://test_saves_m_ingame"
## Logical screen sizes (the window stretches from 1600x1000 with "expand"): 16:10 (1280x800),
## 16:9 (1280x720 / 1600x900 / 1920x1080 / 2560x1440) and a wider window.
const SIZES := [Vector2(1600, 1000), Vector2(1778, 1000), Vector2(1851, 1000)]
const NAMES := ["Ann", "Bea"]


func before_test() -> void:
	SeriesStore.DIR = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	UIStyle.reduce_motion = true   # instant motion: the tests read settled states


func after_test() -> void:
	UIStyle.reduce_motion = false
	for fn in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, fn])


func _screen(sz: Vector2 = SIZES[1], best_of: int = 3) -> GameScreen:
	var host: LocalHost = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 13, "best_of": best_of, "deck_mode": "starter", "names": NAMES, "mode": "local"})
	host.handle(0, {"t": "pick_starter", "index": 0})
	host.handle(1, {"t": "pick_starter", "index": 1})
	var gs: GameScreen = auto_free(GameScreen.new())
	gs.size = sz
	add_child(gs)
	await gs.attach(host.seats[0])
	for i in 4:
		await await_idle_frame()
	gs.sidebar.update_scoreboard()
	await await_idle_frame()
	return gs


func _zone_rects(gs: GameScreen) -> Array:
	var out := []
	for k in gs.board.slots:
		out.append((gs.board.slots[k]["zone_node"] as Control).get_global_rect())
	for side in 2:
		for z in gs.board.piles[side]:
			out.append((gs.board.piles[side][z] as Control).get_global_rect())
	return out


# ---------------------------------------------------------------- M1

func test_m1_the_outside_catcher_is_under_the_menu_in_tree_order() -> void:
	var gs := await _screen()
	var m := gs.menu
	# GUI input is picked by tree order, not z_index: the catcher must come before the menu.
	assert_int(m.outside_catcher.get_index()).is_less(m.game_menu.get_index())
	assert_int(m.settings_veil.get_index()).is_less(m.settings_popup.get_index())


func test_m1_the_pointer_over_an_open_menu_item_reaches_the_item() -> void:
	var gs := await _screen()
	var m := gs.menu
	m.toggle()
	await await_idle_frame()
	var b: Control = m.items["settings"]
	var at := b.get_global_rect().get_center()
	# Act: the pointer moves over the Settings item.
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	get_viewport().push_input(mv, true)
	await await_idle_frame()
	# Assert: the item (not the full-window catcher) is under the pointer.
	var hov := get_viewport().gui_get_hovered_control()
	assert_object(hov).is_not_null()
	assert_bool(hov == b or b.is_ancestor_of(hov)).override_failure_message("hovered %s" % hov).is_true()


func test_m1_a_click_off_the_menu_still_closes_it_once() -> void:
	var gs := await _screen()
	var m := gs.menu
	m.toggle()
	await await_idle_frame()
	Sfx.debug_ui.clear()
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	m.outside_catcher.gui_input.emit(e)
	await await_idle_frame()
	assert_bool(m.game_menu.visible).is_false()
	assert_int(Sfx.debug_ui.count("panel_close")).is_equal(1)


# ---------------------------------------------------------------- M4

func test_m4_the_series_score_is_in_the_menu_not_the_top_strip() -> void:
	var gs := await _screen()
	var sb := gs.menu.scoreboard
	assert_bool(gs.menu.game_menu.is_ancestor_of(sb)).is_true()
	assert_bool(gs.menu.top_strip.is_ancestor_of(sb)).is_false()
	assert_bool(gs.menu.series_box.visible).is_true()
	assert_bool(sb.is_visible_in_tree()).is_false()   # the menu is closed
	gs.menu.toggle()
	await await_idle_frame()
	assert_bool(sb.is_visible_in_tree()).is_true()
	# It fits the menu's series width and sits inside the menu panel.
	assert_float(sb.size.x * sb.scale.x).is_less_equal(GameMenu.SERIES_W + 0.5)
	assert_bool(gs.menu.game_menu.get_global_rect().encloses(sb.get_global_rect())).is_true()
	assert_str(gs.menu.series_status.text).is_equal("Game 1 · first to 2 wins")


func test_m4_a_single_game_shows_no_series_section() -> void:
	var gs := await _screen(SIZES[1], 1)
	gs.menu.toggle()
	await await_idle_frame()
	assert_bool(gs.menu.series_box.visible).is_false()


func test_m4_series_status_text() -> void:
	var md := {"over": false, "winner": -1, "current": 1, "need": 2, "names": ["Ann", "Bea"]}
	assert_str(GameMenu.series_status_text(md)).is_equal("Game 2 · first to 2 wins")
	md["over"] = true
	md["winner"] = 1
	assert_str(GameMenu.series_status_text(md)).is_equal("Bea wins the series")
	assert_str(GameMenu.series_status_text({})).is_equal("")


# ---------------------------------------------------------------- M9

func test_m9_plates_clear_every_zone_at_every_size() -> void:
	for sz in SIZES:
		var gs := await _screen(sz)
		var zones := _zone_rects(gs)
		for side in 2:
			var pr := (gs.board.plates[side] as Control).get_global_rect()
			assert_bool(gs.get_global_rect().encloses(pr)).override_failure_message("plate %d off screen at %s" % [side, sz]).is_true()
			for z in zones:
				assert_bool(pr.intersects(z)).override_failure_message("plate %d hits %s at %s" % [side, z, sz]).is_false()
		# The duel controls stay under my plate and on screen.
		var cr := Rect2(gs.board.controls.position, DuelControls.block_size())
		assert_float(cr.position.y).is_greater_equal((gs.board.plates[1] as Control).get_global_rect().end.y)
		assert_float(cr.end.y).is_less_equal(gs.size.y)
		gs.queue_free()
		await await_idle_frame()


func test_m9_icon_menu_button_sits_left_of_the_opponent_plate() -> void:
	for sz in SIZES:
		var gs := await _screen(sz)
		var mb := gs.menu.menu_button
		var br := mb.get_global_rect()
		var opp := (gs.board.plates[0] as Control).get_global_rect()
		assert_str(mb.text).is_empty()
		assert_str(mb.tooltip_text).is_equal("Menu")
		assert_float(br.end.x).is_equal_approx(opp.position.x - GameMenu.PLATE_GAP, 1.0)
		assert_float(br.position.y).is_equal_approx(opp.position.y, 1.0)
		assert_bool(br.intersects(opp)).is_false()
		# The menu opens under the button, right edges aligned, and on screen.
		gs.menu.toggle()
		await await_idle_frame()
		var mr := gs.menu.game_menu.get_global_rect()
		assert_float(mr.end.x).is_equal_approx(br.end.x, 1.0)
		assert_float(mr.position.y).is_greater_equal(br.end.y)
		assert_bool(gs.get_global_rect().encloses(mr)).is_true()
		gs.queue_free()
		await await_idle_frame()


# ---------------------------------------------------------------- M13

func test_m13_the_table_light_is_a_glow_on_the_field_centre() -> void:
	var gs := await _screen()
	var dust := gs.board.dust
	assert_vector(dust.shaft.size).is_equal(Vector2.ZERO)        # no cone from the top edge
	assert_object(dust.glow_rect).is_not_null()
	assert_bool(dust.glow_rect.visible).is_true()
	assert_vector(dust.glow_center).is_equal(gs.board.field_center())
	assert_vector(dust.glow_radius).is_equal(GameBoardView.GLOW_RADIUS)
	# Between the two unit grids: the centre line of the board.
	assert_float(gs.board.field_center().y).is_equal_approx(gs.board.deco.mid_y, 0.5)


func test_m13_glow_falloff_is_soft_and_ends_before_the_rim() -> void:
	assert_float(AmbientMotes.glow_falloff(0.0)).is_equal_approx(1.0, 0.0001)
	assert_float(AmbientMotes.glow_falloff(1.0)).is_equal_approx(0.0, 0.0001)
	var prev := 1.0
	for i in range(1, 21):
		var f := AmbientMotes.glow_falloff(float(i) / 20.0)
		assert_float(f).is_less_equal(prev)
		# No hard edge: never a drop of more than a fifth of the peak between neighbouring steps.
		assert_float(prev - f).is_less(0.2)
		prev = f


func test_m13_glow_breathes_inside_the_old_shaft_range_and_rests_under_reduce_motion() -> void:
	var m: AmbientMotes = auto_free(AmbientMotes.dust())
	assert_float(AmbientMotes.GLOW_ALPHA.y).is_less_equal(AmbientMotes.SHAFT_ALPHA.y)
	UIStyle.reduce_motion = false
	for i in 16:
		var a := m.glow_alpha(float(i) * 0.37)
		assert_float(a).is_between(AmbientMotes.GLOW_ALPHA.x, AmbientMotes.GLOW_ALPHA.y)
	UIStyle.reduce_motion = true
	var mid := (AmbientMotes.GLOW_ALPHA.x + AmbientMotes.GLOW_ALPHA.y) / 2.0
	assert_float(m.glow_alpha(0.0)).is_equal_approx(mid, 0.0001)
	assert_float(m.glow_alpha(3.1)).is_equal_approx(mid, 0.0001)


func test_m13_a_zero_radius_hides_the_glow() -> void:
	var m: AmbientMotes = auto_free(AmbientMotes.dust())
	m.set_glow(Vector2(100, 100), Vector2(50, 50))
	assert_bool(m.glow_rect.visible).is_true()
	m.set_glow(Vector2.ZERO, Vector2.ZERO)
	assert_bool(m.glow_rect.visible).is_false()
