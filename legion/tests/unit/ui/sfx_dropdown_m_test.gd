extends GdUnitTestSuite
## M batch (owner, 9 Nov): "Selecting a dropdown option should have a sound effect". Choosing an item
## in any OptionButton plays dropdown_select once (borrowing select.wav until its own take ships);
## building a form (select() in code) is silent; the open list's rows give the rate-limited hover cue.

var _nodes: Array = []


func before_test() -> void:
	Sfx.install_button_sounds()
	Sfx._reset_ui()
	Sfx._reset_hover()


func after_test() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			n.free()
	_nodes.clear()
	Sfx._reset_ui()
	Sfx._reset_hover()


func _dropdown(count: int = 3) -> OptionButton:
	var ob := OptionButton.new()
	for i in count:
		ob.add_item("Item %d" % i)
	_nodes.append(ob)
	add_child(ob)
	return ob


func test_m_dropdown_cue_is_registered_with_a_ui_priority() -> void:
	assert_bool(Sfx.NAMES.has("dropdown_select")).is_true()
	assert_bool(Sfx.UI_PRIORITY.has("dropdown_select")).is_true()
	# Outranks the plain clicks, yields to a handler's meaningful cue (confirm, back ...).
	assert_int(int(Sfx.UI_PRIORITY["dropdown_select"])).is_greater(int(Sfx.UI_PRIORITY["click_secondary"]))
	assert_int(int(Sfx.UI_PRIORITY["dropdown_select"])).is_less(int(Sfx.UI_PRIORITY["confirm"]))


func test_m_dropdown_cue_falls_back_to_the_select_file() -> void:
	# Until the owner's take (dropdown_select.wav / .ogg) is added, the cue is audible as select.wav.
	if not FileAccess.file_exists(Sfx.DIR + "dropdown_select.wav") and not FileAccess.file_exists(Sfx.DIR + "dropdown_select.ogg"):
		assert_str(Sfx.asset_path("dropdown_select")).is_equal(Sfx.asset_path("select"))
	assert_bool(Sfx.has_asset("dropdown_select")).is_true()


func test_m_choosing_an_item_plays_the_dropdown_cue_once() -> void:
	# Arrange
	var ob := _dropdown()
	Sfx._reset_ui()
	# Act: the popup emits item_selected when the player picks a row.
	ob.item_selected.emit(2)
	# Assert
	assert_array(Sfx.debug_ui).is_equal(["dropdown_select"])


func test_m_scripted_select_is_silent() -> void:
	# Arrange
	var ob := _dropdown()
	Sfx._reset_ui()
	# Act: forms set their current value in code while building.
	ob.select(1)
	ob.select(2)
	# Assert
	assert_array(Sfx.debug_ui).is_empty()


func test_m_a_real_pick_in_the_open_list_plays_the_cue() -> void:
	# Arrange
	var ob := _dropdown(4)
	ob.position = Vector2(100, 100)
	await get_tree().process_frame
	ob.show_popup()
	await get_tree().process_frame
	await get_tree().process_frame
	var pm := ob.get_popup()
	Sfx._reset_ui()
	# Act: click the last row of the list.
	var ft := get_tree().root.get_final_transform()
	for down in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = down
		b.position = ft * (Vector2(pm.position) + Vector2(20, pm.size.y - 12))
		b.global_position = b.position
		Input.parse_input_event(b)
	Input.flush_buffered_events()
	await get_tree().process_frame
	# Assert
	assert_int(ob.selected).is_equal(3)
	assert_array(Sfx.debug_ui).is_equal(["dropdown_select"])


func test_m_a_handler_cue_in_the_same_frame_wins() -> void:
	# Arrange: a dropdown whose handler asks for a weightier UI sound.
	var ob := _dropdown()
	ob.item_selected.connect(func(_i): Sfx.play("confirm"))
	Sfx._reset_ui()
	# Act
	ob.item_selected.emit(1)
	# Assert: one action, one sound.
	assert_array(Sfx.debug_ui).is_equal(["confirm"])


func test_m_silenced_dropdown_stays_silent() -> void:
	var ob := _dropdown()
	ob.set_meta(Sfx.BUTTON_META, "none")
	Sfx._reset_ui()
	ob.item_selected.emit(0)
	assert_array(Sfx.debug_ui).is_empty()


func test_m_popup_rows_are_equal_slices_of_the_list() -> void:
	# Arrange
	var ob := _dropdown(4)
	var pm := ob.get_popup()
	pm.size = Vector2i(120, 108)
	var sb := pm.get_theme_stylebox(&"panel")
	var top := sb.get_margin(SIDE_TOP) if sb != null else 0.0
	var row_h := (108.0 - top - (sb.get_margin(SIDE_BOTTOM) if sb != null else 0.0)) / 4.0
	# Act / Assert
	assert_int(Sfx.popup_row_at(pm, top + 1.0)).is_equal(0)
	assert_int(Sfx.popup_row_at(pm, top + row_h * 2.5)).is_equal(2)
	assert_int(Sfx.popup_row_at(pm, top + row_h * 3.9)).is_equal(3)
	assert_int(Sfx.popup_row_at(pm, -5.0)).is_equal(-1)
	assert_int(Sfx.popup_row_at(pm, 500.0)).is_equal(-1)
	pm.set_item_disabled(1, true)
	assert_int(Sfx.popup_row_at(pm, top + row_h * 1.5)).is_equal(-1)


func test_m_popup_hover_sounds_once_per_new_row() -> void:
	# Arrange
	var ob := _dropdown(4)
	var pm := ob.get_popup()
	# Act / Assert: a new row plays; the same row again is silent; another row plays (past the limiter).
	assert_bool(Sfx.popup_hover(pm, 1)).is_true()
	assert_bool(Sfx.popup_hover(pm, 1)).is_false()
	Sfx._last_hover_ms = -100000
	assert_bool(Sfx.popup_hover(pm, 2)).is_true()
	assert_bool(Sfx.popup_hover(pm, -1)).is_false()
	assert_array(Sfx.debug_hover).is_equal(["ui_hover", "ui_hover"])


func test_m_pointer_motion_over_the_open_list_gives_the_hover_cue() -> void:
	# Arrange
	var ob := _dropdown(4)
	var pm := ob.get_popup()
	pm.size = Vector2i(120, 108)
	assert_bool(pm.has_meta("_sfx_wired")).is_true()
	Sfx._reset_hover()
	# Act: the list's window reports a motion over its second row.
	var ev := InputEventMouseMotion.new()
	ev.position = Vector2(20, 108.0 * 0.4)
	pm.window_input.emit(ev)
	pm.window_input.emit(ev)
	# Assert: one cue for the row, not one per motion event.
	assert_array(Sfx.debug_hover).is_equal(["ui_hover"])


func test_m_reopening_the_list_forgets_the_last_row() -> void:
	var ob := _dropdown(4)
	var pm := ob.get_popup()
	Sfx.popup_hover(pm, 2)
	pm.about_to_popup.emit()
	assert_int(int(pm.get_meta(Sfx.POPUP_ROW_META))).is_equal(-1)
