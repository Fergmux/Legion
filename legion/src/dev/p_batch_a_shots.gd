extends "res://src/dev/f02_driver.gd"
## Development-only windowed evidence for owner feedback of 18 Nov 2026, items A1-A12
## (design/owner-feedback-2026-11-18.md). Launched with
##   godot --path legion -- --pbatcha-shots=<absolute dir>
## Main menu (Tutorial item, subtitle as wide as the logo, Join game opening the lobby browser at
## once, the statistics tooltip wrapping), then a hot-seat draft best-of-3 through the real main
## scene: the draft page (no opponent chip), the narrow deck-locked-in wait, the rewards (title,
## Picks heading, no result plate, no count pill, the remove list's select / deselect), the next
## game (Ready up, no result or chooser lines), the series over with a pause injected (no veil), and
## a bot pass (no "is ready" line). Writes PNGs prefixed "a_" and `pbatcha_report.json`, then quits.


func run(main_node: Node, dir: String) -> void:
	main = main_node
	out_dir = dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	if not Sfx._loaded:
		Sfx.load_settings()
	Sfx._muted = true   # in memory only
	await _frames(5)
	await _menu()
	main._clear_screens()
	await _wait(0.4)
	main._privacy = false
	main._start_local({"seed": 4242, "best_of": 3, "deck_mode": "draft", "names": ["Ana", "Ben"]})
	await _frames(8)
	host = main.local_host
	gs = main.screen
	await _draft()
	await _rewards()
	await _next_game()
	await _over()
	await _bot_pass()
	_finish()


# ---------------------------------------------------------------- menu (A8-A11)
func _menu() -> void:
	main._show_menu()
	await _wait(1.2)
	var mm: MainMenu = main.menu
	var labels := _items(mm)
	_check("A8 no 'Play tutorial' item", not labels.has("Play tutorial"), str(labels))
	var logo_w := MainMenu.logo_width()
	var sub_w := MainMenu.subtitle_width()
	_check("A11 subtitle spans the logo width (within 2 px)", absf(logo_w - sub_w) <= 2.0, "logo %.1f subtitle %.1f" % [logo_w, sub_w])
	var logo: Control = mm.find_child("Logo", true, false)
	var sub: Control = mm.find_child("Subtitle", true, false)
	if logo != null and sub != null:
		_check("A11 the subtitle starts under the logo", absf(logo.get_global_rect().position.x - sub.get_global_rect().position.x) <= 2.0,
			"%s vs %s" % [logo.get_global_rect(), sub.get_global_rect()])
	await _shot("a_01_menu_title")
	# A8: a fresh profile's root shows the one-word Tutorial item.
	PlayerProgress._played = false
	var saves_dir := SeriesStore.DIR
	SeriesStore.DIR = "user://pbatcha_no_saves"   # no saved series: a fresh profile
	mm._build_menu_level(false)
	await _wait(0.3)
	labels = _items(mm)
	_check("A8 fresh profile: 'Tutorial' item at the top", not labels.is_empty() and labels[0] == "Tutorial" and not labels.has("Play tutorial"), str(labels))
	await _shot("a_02_menu_tutorial_item")
	SeriesStore.DIR = saves_dir
	mm._build_menu_level(false)
	# A10: Join game opens the lobby browser straight away (no Join game panel first).
	var browse := [0]
	mm.steam_browse_requested.connect(func(): browse[0] += 1)
	mm.pick("@play")
	await _wait(0.3)
	mm.pick("@online")
	await _wait(0.4)
	mm.pick("join_online")
	await _wait(0.6)
	_check("A10 Join game asks for the lobby browser at once", browse[0] == 1, str(browse[0]))
	_check("A10 no Join game panel opened", mm._menu_center.get_child_count() == 0 or mm._menu_center.get_children().all(func(c): return not (c as Control).visible),
		str(mm._menu_center.get_children()))
	_check("A10 no 'Logged in as' text in the centre", not _texts(mm._menu_center).any(func(t): return t.begins_with("Logged in as")))
	var lists := main.get_children().filter(func(c): return c is LobbyListPanel)
	_check("A10 the lobby browser is open (Steam up) or main says why (Steam down)", not lists.is_empty() or main.status_label.text != "",
		"%d panels, status '%s'" % [lists.size(), main.status_label.text])
	await _wait(2.0)
	await _shot("a_03_join_game_opens_lobby_browser")
	for l in lists:
		(l as LobbyListPanel)._back()
	await _wait(0.4)
	# A9: the statistics tooltip wraps at its max width.
	mm.pick("@options")
	await _wait(0.4)
	# Back to the root first if the online level is still open.
	while mm._menu_path.size() > 1 and mm._menu_path[-1] != "options":
		mm.back_out()
		await _wait(0.2)
	mm.pick("settings")
	await _wait(1.0)
	var dots := mm.find_children("ShareInfo", "", true, false)
	_check("A9 info dot present", not dots.is_empty())
	if not dots.is_empty():
		var dot := dots[0] as Control
		var tip := dot._make_custom_tooltip(dot.tooltip_text) as Label
		_check("A9 tooltip label wraps", tip != null and tip.autowrap_mode != TextServer.AUTOWRAP_OFF)
		_check("A9 tooltip width capped", tip != null and tip.custom_minimum_size.x <= SettingsForm.InfoDot.TIP_MAX_W, str(tip.custom_minimum_size) if tip else "")
		if tip != null:
			tip.free()
		await _move(dot.get_global_rect().get_center())
		await _wait(1.6)
		var shown := get_tree().root.find_children("InfoTip", "", true, false)
		if not shown.is_empty():
			var sz := (shown[0] as Control).size
			_check("A9 shown tooltip is at most TIP_MAX_W wide", sz.x <= SettingsForm.InfoDot.TIP_MAX_W + 1.0, str(sz))
		await _shot("a_05_settings_share_tooltip")
		_hold = Vector2(-1, -1)
		await _move(Vector2(20, 980))


# ---------------------------------------------------------------- draft (A6)
func _draft() -> void:
	_view_seat(0)
	await _wait(1.2)
	# Ben drafts a few cards first, so the other seat has progress to (not) show.
	for i in 3:
		host.handle(1, {"t": "draft_pick", "index": 0})
	for i in 2:
		host.handle(0, {"t": "draft_pick", "index": 0})
	_view_seat(0)
	await _wait(1.5)
	var box := gs.overlays.overlay_box
	var txt := _texts(box)
	_check("A6 no '<opponent> is drafting' chip", not txt.any(func(t): return t.contains("is drafting") or t.contains("confirming")), str(txt))
	_check("A6 no OpponentProgress node", box.find_child("OpponentProgress", true, false) == null)
	_check("A6 the right pane shows the draft", gs.details.is_drafting() and gs.details.pile_zone == "draft")
	_check("A6 the right pane title has the card count", gs.details.details_title.text.contains("2"), gs.details.details_title.text)
	await _shot("a_06_draft_page")
	var guard := 0
	while not host.series.draft_complete(0) and guard < 80:
		host.handle(0, {"t": "draft_pick", "index": 0})
		guard += 1
	host.handle(0, {"t": "draft_confirm"})
	await _wait(0.4)
	_view_seat(0)
	await _wait(1.6)
	var w := gs.overlays.overlay.size.x
	_check("A6 deck-locked-in wait is narrow", w <= GameSeriesOverlay.WAIT_W + 1.0, str(w))
	await _shot("a_07_draft_done_waiting_narrow")
	while not host.series.draft_complete(1) and guard < 200:
		host.handle(1, {"t": "draft_pick", "index": 0})
		guard += 1
	host.handle(1, {"t": "draft_confirm"})
	await _wait(0.6)
	m = host.series.game
	gs._coin_shown[String(gs.view.get("save_id", "local"))] = true
	for n in gs.get_children():
		if n is CoinFlip:
			n.queue_free()
	_view_seat(0)
	await _wait(2.0)
	# Ben concedes: Ana won game 1, Ben chooses who goes first in game 2.
	host.handle(1, {"t": "concede"})
	await _wait(0.3)
	_view_seat(0)
	await _wait(6.0)
	_view_seat(0)
	await _wait(1.0)


# ---------------------------------------------------------------- rewards (A1, A4, A5, A12)
func _rewards() -> void:
	_check("rewards stage", String(gs.view.get("stage", "")) == "rewards", String(gs.view.get("stage", "")))
	var box := gs.overlays.overlay_box
	var txt := _texts(box)
	_check("A4 rewards title is 'Rewards'", txt.has("Rewards") and not txt.any(func(t): return t.contains("complete")), str(txt))
	_check("A1 no 'won game' line", not txt.any(func(t): return t.contains("won game")), str(txt))
	var picks := box.find_child("Picks", true, false)
	_check("A5 Picks heading above the gem plate", picks != null and picks.find_child("PicksTitle", true, false) != null)
	_check("A5 the gem plate holds only the gems", picks != null and picks.get_child(1).find_children("*", "Label", true, false).is_empty())
	await _shot("a_08_rewards")
	# A12: the remove-a-card list.
	gs.overlays.rewards.choose_mode("remove")
	await _wait(0.9)
	var rows := box.find_children("*", "ChoiceTile", true, false).filter(func(t): return (t as Control).custom_minimum_size.y == 46)
	var prev := _remove_preview()
	_check("A12 remove list built", rows.size() >= 4 and prev != null, str(rows.size()))
	if rows.size() >= 4 and prev != null:
		await _move((rows[1] as Control).get_global_rect().get_center())
		await _wait(0.4)
		var hovered_name := _row_name(rows[1])
		_check("A12 nothing selected: hover previews the row", _preview_name().begins_with(hovered_name), "%s vs %s" % [_preview_name(), hovered_name])
		await _click((rows[2] as Control).get_global_rect().get_center())
		await _wait(0.6)
		rows = _remove_rows()
		var sel_name := _row_name(rows[2])
		_check("A12 click selects", gs.overlays.rewards.remove_selection() != -1)
		await _move((rows[3] as Control).get_global_rect().get_center())
		await _wait(0.4)
		_check("A12 selected card stays in the preview on hover", _preview_name().begins_with(sel_name), "%s vs %s" % [_preview_name(), sel_name])
		await _shot("a_09_remove_selected_hover_other")
		await _click((rows[2] as Control).get_global_rect().get_center())
		await _wait(0.6)
		rows = _remove_rows()
		_check("A12 clicking the selected card deselects it", gs.overlays.rewards.remove_selection() == -1)
		await _move((rows[3] as Control).get_global_rect().get_center())
		await _wait(0.4)
		var n3 := _row_name(rows[3])
		_check("A12 after deselect hover previews again", _preview_name().begins_with(n3), "%s vs %s" % [_preview_name(), n3])
		await _shot("a_10_remove_deselected_hover_preview")
		# Take the reward so the chosen list shows.
		await _click((rows[2] as Control).get_global_rect().get_center())
		await _wait(0.5)
		var ok: Button = null
		for b in box.find_children("*", "Button", true, false):
			if (b as Button).text.begins_with("Remove ") and not (b as Button).disabled:
				ok = b
		if ok != null:
			ok.pressed.emit()
		_hold = Vector2(-1, -1)
		await _wait(1.0)
	txt = _texts(box)
	_check("A5 'Rewards chosen' shown", txt.has("REWARDS CHOSEN"), str(txt))
	var head: Node = null
	for l in box.find_children("*", "Label", true, false):
		if (l as Label).text == "REWARDS CHOSEN":
			head = l.get_parent()
	_check("A5 no count beside 'Rewards chosen'", head != null and head.get_child_count() == 1, str(head.get_child_count()) if head else "no caption")
	await _shot("a_11_rewards_chosen_no_count")
	host.handle(0, {"t": "reward_finish"})
	await _wait(0.3)
	host.handle(1, {"t": "reward_finish"})
	await _wait(0.3)


func _remove_rows() -> Array:
	return gs.overlays.overlay_box.find_children("*", "ChoiceTile", true, false).filter(func(t): return (t as Control).custom_minimum_size.y == 46)


func _remove_preview() -> CardWidget:
	for cw in gs.overlays.overlay_box.find_children("*", "CardWidget", true, false):
		if (cw as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE:
			return cw
	return null


func _preview_name() -> String:
	var p := _remove_preview()
	return String(p.view.get("name", "")) if p != null and p.view != null else ""


func _row_name(row: Node) -> String:
	for l in row.find_children("*", "Label", true, false):
		if (l as Label).text != "":
			return (l as Label).text.split(" ×")[0]
	return String(row.get("title")) if row.get("title") != null else ""


# ---------------------------------------------------------------- next game (A1-A4)
func _next_game() -> void:
	_view_seat(0)
	await _wait(1.2)
	var box := gs.overlays.overlay_box
	var txt := _texts(box)
	_check("next game stage", String(gs.view.get("stage", "")) == "first_player", String(gs.view.get("stage", "")))
	_check("A1 no 'won game' line", not txt.any(func(t): return t.contains("won game")), str(txt))
	_check("A2 no chooser lines", not txt.any(func(t): return t.contains("goes first in game") or t.contains("chose you") or t.contains("is choosing")), str(txt))
	_check("A4 'Ready up' button", _find_button(box, "Ready up") != null and _find_button(box, "Start next duel") == null)
	await _shot("a_12_next_game_winner")
	_view_seat(1)
	await _wait(1.0)
	txt = _texts(box)
	_check("A2 loser: no 'you lost, so you choose' line", not txt.any(func(t): return t.contains("You lost")), str(txt))
	await _shot("a_13_next_game_chooser")
	host.handle(1, {"t": "first_player", "who": 1})
	await _wait(0.3)
	_view_seat(0)
	await _wait(1.0)
	txt = _texts(box)
	_check("A2 no '<name> chose ...' line", not txt.any(func(t): return t.contains(" chose ")), str(txt))
	await _shot("a_14_next_game_after_choice")


# ---------------------------------------------------------------- series over (A7)
func _over() -> void:
	host.handle(0, {"t": "forfeit_series"})
	await _wait(0.3)
	_view_seat(0)
	await _wait(6.0)
	_check("series over", String(gs.view.get("stage", "")) == "over", String(gs.view.get("stage", "")))
	# A network view at this point may still say paused (an opponent dropping); nothing may show.
	var v := gs.view.duplicate()
	v["net"] = {"paused": true, "message": "Opponent disconnected — match paused, waiting for them to reconnect.", "opponent_connected": false, "is_host": true}
	gs.view = v
	gs.overlays.render_pause()
	gs.menu.update_conn()
	await _wait(0.5)
	_check("A7 no pause veil once the series is over", not gs.overlays.pause_dim.visible)
	_check("A7 no connection notice once the series is over", not gs.menu.conn_label.visible, gs.menu.conn_label.text)
	_check("A7 Back to main menu shown", gs.overlays.overlay_box.find_child("BackToMenu", true, false) != null)
	await _shot("a_15_series_over_no_pause")


# ---------------------------------------------------------------- bot (A3)
func _bot_pass() -> void:
	main._clear_screens()
	await _wait(0.5)
	main._start_bot({"seed": 77, "best_of": 3, "deck_mode": "starter"})
	await _wait(1.0)
	host = main.local_host
	gs = main.screen
	host.handle(0, {"t": "pick_starter", "index": 2})
	await _wait(1.5)
	if String(host.series.stage) != "game":
		_check("bot pass: game started", false, String(host.series.stage))
		return
	gs._coin_shown[String(gs.view.get("save_id", "local"))] = true
	for n in gs.get_children():
		if n is CoinFlip:
			n.queue_free()
	await _wait(1.5)
	host.handle(1, {"t": "concede"})
	await _wait(7.0)
	host.handle(0, {"t": "reward_finish"})
	await _wait(2.0)
	var box := gs.overlays.overlay_box
	var txt := _texts(box)
	_check("bot pass: next game stage", String(gs.view.get("stage", "")) == "first_player", String(gs.view.get("stage", "")))
	_check("A3 no 'is ready' line", not txt.any(func(t): return t.ends_with("is ready.")), str(txt))
	_check("A3 no ready tick against the bot", box.find_child("ReadyTick", true, false) == null)
	await _shot("a_16_bot_next_game_no_ready_text")


## The texts of the menu column's items.
func _items(mm: MainMenu) -> Array:
	return mm._menu_list.get_children().filter(func(c): return c is MenuItem).map(func(c): return (c as MenuItem).label_text)


func _texts(n: Node) -> Array:
	var out := []
	for l in n.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree() and (l as Label).text != "":
			out.append((l as Label).text)
	return out


func _finish() -> void:
	var fails := checks.filter(func(c): return not c["ok"])
	var f := FileAccess.open(out_dir.path_join("pbatcha_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "passed": checks.size() - fails.size(), "failed": fails.size()}, "  "))
	f.close()
	print("PBATCHA DRIVER DONE: %d passed, %d failed" % [checks.size() - fails.size(), fails.size()])
	get_tree().quit()
