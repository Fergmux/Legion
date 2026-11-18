extends "res://src/dev/f02_driver.gd"
## Development-only windowed evidence for owner feedback of 18 Nov 2026, items B1-B9
## (design/owner-feedback-2026-11-18.md). Launched with
##   godot --path legion -- --pbatchb-shots=<absolute dir>
## A hot-seat draft series: seat 1 is still drafting (the right pane lists its picks) when its confirm
## starts the game, and the pane must turn into card details (B3). Then, on a staged board: the Spent
## pile list with a row's coloured tooltip (B1), the hover preview with nothing selected and a selected
## card that stays while another is hovered (B4), an empty zone click that deselects (B5), the Chat and
## Appendix icon buttons and the open appendix (B6), Heretic of the Divine Order's status choices (B2),
## then the card list sorted by cost with Basics first and its wider pane (B8 / B9) and the deck
## builder's facts without the kind line (B9). Writes PNGs prefixed "b_" and `pbatchb_report.json`.

const HERETIC := 201
const BASIC_MAGE := 1


func run(main_node: Node, dir: String) -> void:
	main = main_node
	out_dir = dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	if not Sfx._loaded:
		Sfx.load_settings()
	Sfx._muted = true   # in memory only
	await _frames(5)
	main._privacy = false
	await _draft_to_game()
	await _board()
	await _menus()
	_finish()


# ---------------------------------------------------------------- B3

func _draft_to_game() -> void:
	main._start_local({"seed": 4242, "best_of": 1, "deck_mode": "draft", "names": ["Ana", "Ben"]})
	await _frames(8)
	host = main.local_host
	gs = main.screen
	var guard := 0
	while not host.series.draft_complete(0) and guard < 80:
		host.handle(0, {"t": "draft_pick", "index": 0})
		guard += 1
	host.handle(0, {"t": "draft_confirm"})
	while not host.series.draft_complete(1) and guard < 200:
		host.handle(1, {"t": "draft_pick", "index": 0})
		guard += 1
	_view_seat(1)
	await _wait(1.0)
	_check("B3 seat 1's pane lists its draft before confirming", gs.details.pile_zone == GameDetails.DRAFT_ZONE and gs.details.pile_scroll.visible)
	await _shot("b_00_draft_pane_before_confirm")
	gs.send({"t": "draft_confirm"})   # seat 1's own confirm: the game starts in this update
	await _wait(0.6)
	m = host.series.game
	gs._coin_shown[String(gs.view.get("save_id", "local"))] = true
	for n in gs.get_children():
		if n is CoinFlip:
			n.queue_free()
	_view_seat(1)
	await _move(Vector2(1120, 640))
	await _wait(2.0)
	_check("B3 game started", String(gs.view.get("stage", "")) == "game")
	_check("B3 the pane is card details, not the draft list", gs.details.pile_zone == "" and gs.details.details_scroll.visible and gs.details.details_title.text == "Card details", gs.details.details_title.text)
	await _shot("b_01_game_started_pane_is_card_details")


# ---------------------------------------------------------------- B1 B2 B4 B5 B6

func _board() -> void:
	main._start_local({"seed": 4242, "best_of": 1, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _frames(8)
	host = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 7})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _frames(4)
	m = host.series.game
	gs = main.screen
	m.submit(m.active, {"t": "next_phase"})
	m.submit(m.active, {"t": "next_phase"})      # turn 2, the other player active
	a = m.active
	o = 1 - a
	uids["heretic"] = _put(a, HERETIC, 1, "atk")
	uids["mage"] = _put(a, BASIC_MAGE, 0, "atk")
	uids["o_unit"] = _put(o, 110, 1, "atk")
	for id in [151, 20, 1, 46]:
		_new(a, id, "spent")
	m.players[a]["ap"] = 6
	m.add_log("[dev] Board arranged for the 18 Nov P batch (B items) verification run.")
	host.broadcast()
	_view_seat(a)
	await _move(Vector2(1120, 640))
	await _wait(6.5)   # past the coin flip
	# B1: the Spent pile list and one row's tooltip.
	await _click((gs.board.piles[1]["spent"] as Control).get_global_rect().get_center())
	await _wait(0.6)
	_check("B1 pile list open", gs.details.pile_scroll.visible)
	var rows := gs.details.pile_list.get_children().filter(func(r): return r.has_meta("uid"))
	if not rows.is_empty():
		var row: Control = rows[0]
		_check("B1 no right-click hint in the row tooltip", not row.tooltip_text.contains("Right-click"))
		await _move(row.get_global_rect().get_center() + Vector2(0, -4))
		await _wait(1.6)
		await _shot("b_02_pile_row_tooltip_coloured_chips")
	_hold = Vector2(-1, -1)
	gs.details.close_pile()
	await _move(Vector2(1120, 640))
	await _wait(0.6)
	# B4: hover preview with nothing selected.
	# The pointer warp does not reach the OS pointer when the window is not focused, so the hover is
	# forced through the screen's dev API (the same set_hover path the pointer takes).
	var huid: int = gs.hand.order[0]
	gs.hover.debug_hover_hand(0)
	await _wait(0.6)
	_check("B4 hover shows the hovered card", gs.details.details_uid() == huid and not gs.details.empty_art.visible)
	await _shot("b_03_hover_preview_nothing_selected")
	gs.hover.debug_clear()
	await _wait(0.6)
	_check("B4 the empty state returns when the hover ends", gs.details.details_uid() == -1 and gs.details.empty_art.visible)
	# B4: a selected card stays while another is hovered.
	await _click(_slot_rect(a, "unit", 1).get_center())
	await _wait(0.4)
	gs.hover.debug_hover_hand(0)
	await _wait(0.6)
	_check("B4 the selected card stays shown on hover", gs.details.details_uid() == uids["heretic"])
	await _shot("b_04_selected_stays_while_hovering")
	gs.hover.debug_clear()
	# B5: an empty zone shows no pointer; a click on it deselects.
	await _move(_zone_rect(a, "unit", 2).get_center())
	await _wait(0.4)
	var bg: CardWidget = gs.board.slots[GameBoardView.key(1, "unit", 2)]["bg"]
	_check("B5 empty zone cursor is the arrow", bg.mouse_default_cursor_shape == Control.CURSOR_ARROW)
	await _click(_zone_rect(a, "unit", 2).get_center())
	await _wait(0.4)
	_check("B5 empty zone click deselected", gs.selected_uid == -1 and gs.action_row.stack == null)
	await _move(Vector2(1120, 640))
	await _wait(0.4)
	await _shot("b_05_empty_zone_click_deselected")
	# B6: the top strip's icon buttons (Chat is online only: shown here for the picture) and the appendix.
	gs.chat.button.visible = true
	await _wait(0.3)
	var strip := gs.menu._row.get_global_rect().grow(6.0)
	var lft := gs.chat.button.get_global_rect().position.x - 12.0
	var r := Rect2(Vector2(lft, strip.position.y), Vector2(strip.end.x - lft, strip.size.y))
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image().get_region(Rect2i(r))
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_LANCZOS)
	img.save_png(out_dir.path_join("b_06_top_strip_chat_appendix_menu_x3.png"))
	_check("B6 chat button has no text", gs.chat.button.text == "")
	await _click(gs.appendix.button.get_global_rect().get_center())
	await _wait(0.8)
	_check("B6 appendix open", gs.appendix.is_open())
	await _move(gs.appendix.panel.get_global_rect().get_center())
	await _wait(0.3)
	await _shot("b_07_appendix_open")
	gs.appendix.scroll.scroll_vertical = 100000
	await _wait(0.4)
	await _shot("b_07b_appendix_scrolled")
	await _key(KEY_ESCAPE)
	await _wait(0.5)
	_check("B6 Esc closes the appendix", not gs.appendix.is_open())
	gs.chat.button.visible = false
	await _move(Vector2(1120, 640))
	# B2: Heretic of the Divine Order's "Apply 1 of any Buff" then "... Debuff" status choices.
	for idx in [0, 1]:
		host.handle(a, {"t": "ability", "uid": uids["heretic"], "idx": idx})
		await _wait(0.5)
		if String(m.pending.get("kind", "")) == "select":
			host.handle(a, {"t": "choose", "id": m.pending["id"], "values": [uids["mage"] if idx == 0 else uids["o_unit"]]})
			await _wait(0.6)
		_check("B2 status mode prompt (%d)" % idx, String(m.pending.get("kind", "")) == "mode")
		await _wait(1.0)
		var btns := gs.prompt.type_grid.get_children().filter(func(b): return b.has_meta("status_choice"))
		_check("B2 status buttons in the grid (%d)" % idx, btns.size() == m.pending.get("options", []).size(), str(btns.size()))
		if not btns.is_empty():
			await _move((btns[0] as Control).get_global_rect().get_center())
			await _wait(0.4)
		await _shot("b_08_heretic_buff_choices" if idx == 0 else "b_09_heretic_debuff_choices")
		await _move(Vector2(1120, 640))
		if String(m.pending.get("kind", "")) == "mode":
			host.handle(a, {"t": "choose", "id": m.pending["id"], "indices": [0]})
			await _wait(1.2)


# ---------------------------------------------------------------- B8 B9

func _menus() -> void:
	main._show_card_list()
	await _frames(6)
	await _move(Vector2(20, 980))
	await _wait(1.0)
	var cl := main.menu as CardListScreen
	if cl != null:
		var ids: Array = cl.browser.visible_ids()
		_check("B8 card list starts with a Basic unit", not ids.is_empty() and String(CardDB.get_def(int(ids[0]))["category"]) == "basic_unit")
	await _shot("b_10_card_list_cost_order_wide_pane")
	if cl != null:
		cl.browser.select(151)   # Ultimate Dragon: a Fusion unit (its kind line said "Fusion summon")
		await _wait(0.6)
	await _shot("b_11_card_list_fusion_no_kind_line")
	main._show_deck_builder()
	await _frames(6)
	await _wait(1.0)
	await _shot("b_12_deck_builder_facts_no_kind_line")


func _finish() -> void:
	var fails := checks.filter(func(c): return not c["ok"])
	var f := FileAccess.open(out_dir.path_join("pbatchb_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "passed": checks.size() - fails.size(), "failed": fails.size()}, "  "))
	f.close()
	print("PBATCHB DRIVER DONE: %d passed, %d failed" % [checks.size() - fails.size(), fails.size()])
	get_tree().quit()
