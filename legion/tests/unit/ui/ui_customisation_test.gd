extends GdUnitTestSuite
## L25 / L28 (owner, 5 Nov): four table backgrounds, forest ruins by default, chosen in a new
## Options > Customisation screen and saved in the user settings; the main menu's top-level
## "Settings" became "Options" with Settings, Customisation and Credits sections, and a Card back
## section offers the card backs (L31; their own suite is ui_card_back_test.gd).

## A file of this suite's own (never the player's settings, never the shared TEST file).
const FILE := "user://test_ui_customisation_suite.cfg"


func before_test() -> void:
	_wipe()
	Customisation.path_override = FILE
	Customisation.reset_cache()


func after_test() -> void:
	_wipe()
	Customisation.path_override = ""
	Customisation.reset_cache()


func _wipe() -> void:
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))


# ---------------------------------------------------------------- the table store

func test_new_profile_plays_on_the_forest_ruins() -> void:
	# Arrange: no settings file. Act / Assert
	assert_str(Customisation.DEFAULT_TABLE).is_equal("ruins")
	assert_str(Customisation.table_id()).is_equal("ruins")
	assert_str(Customisation.table_path()).is_equal("res://assets/art/tables/table_ruins.jpg")


func test_every_table_has_a_name_art_and_a_thumbnail() -> void:
	# Arrange / Act
	var ids := []
	for t in Customisation.TABLES:
		ids.append(String(t["id"]))
		# Assert: every table has a display name, its art and a picker thumbnail on disk.
		assert_str(String(t["name"])).is_not_empty()
		assert_bool(ResourceLoader.exists(String(t["path"]))).is_true()
		assert_bool(ResourceLoader.exists(String(t["thumb"]))).is_true()
		assert_float(float(t["veil"])).is_between(0.0, 0.6)
	assert_array(ids).contains_exactly(["ruins", "volcano", "lagoon", "storm"])


func test_picked_table_is_saved_and_read_back() -> void:
	# Arrange
	var ok := Customisation.set_table("volcano")
	# Act: a fresh read from the file.
	Customisation.reset_cache()
	# Assert
	assert_bool(ok).is_true()
	assert_str(Customisation.table_id()).is_equal("volcano")
	assert_str(Customisation.table_path()).is_equal("res://assets/art/tables/table_volcano.jpg")


func test_unknown_table_is_refused() -> void:
	# Arrange
	Customisation.set_table("lagoon")
	# Act
	var ok := Customisation.set_table("velvet")
	# Assert
	assert_bool(ok).is_false()
	assert_str(Customisation.table_id()).is_equal("lagoon")


func test_unknown_saved_table_falls_back_to_the_default() -> void:
	# Arrange: a table id from some other version.
	var cf := ConfigFile.new()
	cf.set_value(Customisation.SECTION, "table", "marble")
	cf.save(FILE)
	# Act
	var id := Customisation.table_id()
	# Assert
	assert_str(id).is_equal(Customisation.DEFAULT_TABLE)


func test_saving_the_table_keeps_the_other_settings() -> void:
	# Arrange: the file UIStyle and Telemetry also write.
	var cf := ConfigFile.new()
	cf.set_value("ui", "reduce_motion", true)
	cf.set_value("privacy", "share_gameplay_stats", false)
	cf.save(FILE)
	# Act
	Customisation.set_table("storm")
	# Assert
	var back := ConfigFile.new()
	back.load(FILE)
	assert_bool(bool(back.get_value("ui", "reduce_motion", false))).is_true()
	assert_bool(bool(back.get_value("privacy", "share_gameplay_stats", true))).is_false()
	assert_str(String(back.get_value(Customisation.SECTION, "table", ""))).is_equal("storm")


func test_automated_runs_use_the_test_file() -> void:
	# Arrange
	Customisation.path_override = ""
	# Act
	var p := Customisation.settings_path()
	# Assert: GdUnit is an automated run, so the player's settings file is never touched.
	assert_str(p).is_equal(Customisation.TEST_PATH)
	assert_str(p).is_not_equal(Customisation.SETTINGS_PATH)


func test_board_table_is_the_chosen_art_under_its_veil() -> void:
	# Arrange
	Customisation.set_table("lagoon")
	# Act
	var bg: Control = auto_free(UIStyle.table_background())
	# Assert
	var art := bg.get_child(0) as TextureRect
	assert_str(art.texture.resource_path).is_equal("res://assets/art/tables/table_lagoon.jpg")
	var veil := bg.get_child(1) as ColorRect
	assert_float(veil.color.a).is_equal_approx(float(Customisation.table("lagoon")["veil"]), 0.001)
	assert_str(String(bg.name)).is_equal("Table_lagoon")


# ---------------------------------------------------------------- the Options menu

func _menu() -> MainMenu:
	var host := Control.new()
	host.size = Vector2(1600, 900)
	add_child(host)
	auto_free(host)
	var mm := MainMenu.new(SessionOptions.new())
	host.add_child(mm)
	return mm


func test_root_menu_has_options_instead_of_settings_and_credits() -> void:
	# Arrange / Act
	var labels := []
	for e in MainMenu.MENU["root"]:
		labels.append(String(e[0]))
	var sections := []
	for e in MainMenu.MENU["options"]:
		sections.append(String(e[1]))
	# Assert
	assert_array(labels).contains(["Options"])
	assert_array(labels).not_contains(["Settings", "Credits"])
	assert_array(sections).contains_exactly(["settings", "customisation", "credits"])


func test_m10_opening_options_selects_no_section() -> void:
	# M batch (owner, 9 Nov): Options lists its sections with none chosen and the centre clear.
	# Arrange
	var mm := _menu()
	# Act
	mm.pick("@options")
	await get_tree().process_frame
	# Assert
	assert_array(mm._menu_path).is_equal(["root", "options"])
	assert_str(mm._menu_leaf).is_equal("")
	assert_object(mm.find_child("SettingsForm", true, false)).is_null()
	assert_int(mm._menu_center.get_child_count()).is_equal(0)
	var labels := []
	for mi in mm._menu_list.get_children():
		if mi is MenuItem:
			assert_bool((mi as MenuItem).active).override_failure_message("%s is selected" % (mi as MenuItem).label_text).is_false()
			labels.append((mi as MenuItem).label_text)
	assert_array(labels).contains_exactly(["Settings", "Customisation", "Credits", "Back"])


func test_m10_closing_an_options_section_stays_in_options() -> void:
	# Arrange
	var mm := _menu()
	mm.pick("@options")
	mm.pick("customisation")
	# Act: the section's Close (and Esc) close the section only.
	mm.step_back()
	# Assert
	assert_array(mm._menu_path).is_equal(["root", "options"])
	assert_str(mm._menu_leaf).is_equal("")
	assert_int(mm._menu_center.get_child_count()).is_equal(0)
	# Esc again returns to the main menu.
	mm.step_back()
	assert_array(mm._menu_path).is_equal(["root"])


func test_m10_back_from_an_options_section_returns_to_the_main_menu() -> void:
	# Arrange
	var mm := _menu()
	mm.pick("@options")
	mm.pick("settings")
	# Act
	mm.back_out()
	# Assert
	assert_array(mm._menu_path).is_equal(["root"])
	assert_str(mm._menu_leaf).is_equal("")


func test_m12_match_table_recedes_behind_the_cards() -> void:
	# M batch (owner, 9 Nov): every table gets a faint extra veil and a slight desaturation in a match.
	for t in Customisation.TABLES:
		# Arrange
		Customisation.set_table(String(t["id"]))
		# Act
		var bg: Control = auto_free(UIStyle.table_background())
		# Assert
		var recede := bg.get_node_or_null("Recede") as ColorRect
		assert_object(recede).override_failure_message("%s has no Recede veil" % t["id"]).is_not_null()
		assert_float(recede.color.a).is_between(0.05, 0.12)
		assert_float(recede.color.a).is_equal_approx(float(t["recede"]), 0.001)
		assert_int(recede.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		var mat := (bg.get_child(0) as TextureRect).material as ShaderMaterial
		assert_object(mat).is_not_null()
		assert_float(float(mat.get_shader_parameter("desat"))).is_between(0.0, 0.2)
		# The table's own veil is unchanged and sits under the new one.
		assert_float((bg.get_child(1) as ColorRect).color.a).is_equal_approx(float(t["veil"]), 0.001)
		assert_int(recede.get_index()).is_greater(1)


func test_m12_menu_backdrop_keeps_the_full_art() -> void:
	# Arrange / Act
	var bg: Control = auto_free(UIStyle.background(MainMenu.BACKGROUND_DIM, UIStyle.MENU_BACKGROUND))
	# Assert
	assert_object(bg.get_node_or_null("Recede")).is_null()
	assert_object((bg.get_child(0) as TextureRect).material).is_null()


func test_options_sections_share_one_width() -> void:
	# Arrange
	var mm := _menu()
	var widths := []
	# Act
	for leaf in ["settings", "customisation", "credits"]:
		var p: Control = auto_free(mm._leaf_panel(leaf))
		widths.append(p.custom_minimum_size.x)
	# Assert
	assert_array(widths).is_equal([MainMenu.OPTIONS_PANEL_W, MainMenu.OPTIONS_PANEL_W, MainMenu.OPTIONS_PANEL_W])


# ---------------------------------------------------------------- the Customisation panel

func test_picker_marks_the_table_in_use() -> void:
	# Arrange
	Customisation.set_table("storm")
	# Act
	var cp: CustomisationPanel = auto_free(CustomisationPanel.new())
	# Assert
	assert_int(cp.tiles.size()).is_equal(4)
	for id in cp.tiles:
		assert_bool((cp.tiles[id] as CustomisationPanel.TableTile).chosen).is_equal(id == "storm")


func test_picking_a_tile_saves_it_and_moves_the_mark() -> void:
	# Arrange
	var cp: CustomisationPanel = auto_free(CustomisationPanel.new())
	var picked := []
	cp.table_picked.connect(func(id): picked.append(id))
	# Act
	(cp.tiles["volcano"] as Button).pressed.emit()
	# Assert
	assert_str(Customisation.table_id()).is_equal("volcano")
	assert_array(picked).is_equal(["volcano"])
	assert_bool((cp.tiles["volcano"] as CustomisationPanel.TableTile).chosen).is_true()
	assert_bool((cp.tiles["ruins"] as CustomisationPanel.TableTile).chosen).is_false()


func test_tiles_click_with_the_customise_cue() -> void:
	# Arrange
	var cp: CustomisationPanel = auto_free(CustomisationPanel.new())
	# Act
	var cue := Sfx.button_sound(cp.tiles["lagoon"] as Button)
	# Assert
	assert_str(cue).is_equal("customise_select")
	assert_bool(Sfx.NAMES.has("customise_select")).is_true()


func test_card_back_section_shows_a_tile_for_every_back() -> void:
	# Arrange
	var cp: CustomisationPanel = auto_free(CustomisationPanel.new())
	# Act
	cp.tabs.select("card_back")
	# Assert: the page is open, with one tile per back (L31) and no "coming soon" placeholder.
	assert_str(cp.section).is_equal("card_back")
	assert_bool((cp.find_child("CardBackPage", true, false) as Control).visible).is_true()
	assert_bool((cp.find_child("TablePage", true, false) as Control).visible).is_false()
	assert_int(cp.back_tiles.size()).is_equal(Customisation.CARD_BACKS.size())
	assert_object(cp.find_child("ComingSoon", true, false)).is_null()


func test_host_game_panel_has_no_steam_login_line() -> void:
	# Arrange: owner, 18 Nov: the menu foot already says who is logged in.
	var mm := _menu()
	# Act
	var p: Control = auto_free(mm._leaf_panel("host_online"))
	# Assert
	var texts := p.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	assert_array(texts).not_contains([SteamBridge.describe()])
	for t in texts:
		assert_str(String(t)).not_contains("Logged in")
