extends GdUnitTestSuite
## Final L-batch review (design/review-final-2026-11-05.md, item d): the opponent-responding notice,
## sacrifice mode's hint pill and the top-strip buttons (Menu, Chat, spectators) must never collide.
## M4 (owner, 9 Nov): the series scoreboard left the top strip for the in-game menu, so the old
## "scoreboard steps aside for the hint" checks are gone; m_batch_ingame_screen_test covers the
## scoreboard in its new home. The window stretches canvas items from 1600x1000 with "expand", so
## 1280x800 lays out as 1600x1000, and 1920x1080 and 3840x2160 as 1851x1000 (1280x720 as 1778x1000).

const DIR := "user://test_saves_final_top_strip"
## Logical screen sizes: 1280x800 / 1600x1000, 1280x720, 1920x1080 / 4K.
const SIZES := [Vector2(1600, 1000), Vector2(1778, 1000), Vector2(1851, 1000)]
## Long names and the longest series (best of 5).
const NAMES := ["Maximiliana Thornwood", "Bartholomew Ashgrave"]


func before_test() -> void:
	SeriesStore.DIR = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	UIStyle.reduce_motion = true   # instant fades: the test reads the settled layout


func after_test() -> void:
	UIStyle.reduce_motion = false
	for fn in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, fn])


func _screen(sz: Vector2) -> GameScreen:
	var host: LocalHost = auto_free(LocalHost.new())
	add_child(host)
	host.start({"seed": 21, "best_of": 5, "deck_mode": "starter", "names": NAMES, "mode": "local"})
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


## Visible top-strip buttons (Menu, Chat, the spectator badge...).
func _buttons(gs: GameScreen) -> Array:
	var out := []
	for b in gs.menu.top_strip.find_children("*", "BaseButton", true, false):
		if (b as Control).is_visible_in_tree():
			out.append(b)
	return out


func _hint_rect(gs: GameScreen) -> Rect2:
	var v := gs.sacrifice.vignette
	return v.hint.get_global_rect()


func test_series_scoreboard_is_not_in_the_top_strip() -> void:
	# Arrange / Act
	var gs := await _screen(SIZES[0])
	# Assert: M4 moved it into the menu panel.
	assert_bool(gs.menu.top_strip.is_ancestor_of(gs.menu.scoreboard)).is_false()


func test_sacrifice_hint_never_covers_a_top_strip_button() -> void:
	for sz in SIZES:
		# Arrange
		var gs := await _screen(sz)
		# Act: the mode's banner comes up (the same call start() makes).
		gs.sacrifice._show_vignette(true)
		await await_idle_frame()
		var hint := _hint_rect(gs)
		# Assert
		for b in _buttons(gs):
			assert_bool(hint.intersects((b as Control).get_global_rect())) \
				.override_failure_message("hint hits %s at %s" % [b.name, sz]).is_false()
		gs.queue_free()
		await await_idle_frame()


func test_wait_notice_clears_the_top_strip_centred_and_docked() -> void:
	for sz in SIZES:
		# Arrange
		var gs := await _screen(sz)
		var wn := gs.prompt.wait_chip as WaitNotice
		# Act
		wn.show_text("Opponent is responding…", "They may answer with a Trap")
		await await_idle_frame()
		var a: Array = gs.prompt.wait_anchors()
		var gt := gs.get_global_transform()
		var s := WaitNotice.DOCK_SCALE
		var centred := Rect2(gt * (Vector2(a[0]) - wn.size / 2.0), wn.size)
		var docked := Rect2(gt * (Vector2(a[1]) - Vector2(wn.size.x * s, 0.0)), wn.size * s)
		var top := Rect2(gt * Vector2.ZERO, Vector2(sz.x, GameScreen.TOP_H))
		# Assert
		for r in [centred, docked]:
			assert_bool(r.intersects(top)).override_failure_message("notice %s in the top strip at %s" % [r, sz]).is_false()
			for b in _buttons(gs):
				assert_bool(r.intersects((b as Control).get_global_rect())).is_false()
		# The docked notice stays left of the sidebar.
		assert_float(docked.end.x).is_less_equal((gt * Vector2(gs.play_area.end.x, 0)).x + 1.0)
		wn.show_text("")
		gs.queue_free()
		await await_idle_frame()
