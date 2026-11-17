extends "res://src/dev/f02_driver.gd"
## Development-only windowed evidence for owner feedback of 16 Nov 2026, items A1-A8
## (design/owner-feedback-2026-11-16.md). Launched with
##   godot --path rldb -- --nbatcha-shots=<absolute dir>
## Plays a hot-seat best-of-7 through the real main scene with pointer events pushed into the
## viewport: the deck-locked-in waiting screen (View your deck, no chips, no card-count suffix),
## the in-game menu (no "Game N · first to N wins"), the pile list / pile browser (no hint line) and
## a pile hover (no tooltip), the rewards (View your deck popup: Close and right-click work; the
## remove-a-card list in catalogue order; the waiting line keeps still) and the next-game wait.
## Writes PNGs prefixed "a_" and `nbatcha_report.json`, then quits.


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
	main._start_local({"seed": 4242, "best_of": 7, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _frames(8)
	host = main.local_host
	gs = main.screen
	_view_seat(0)
	await _wait(0.8)
	host.handle(0, {"t": "pick_starter", "index": 1})
	await _wait(0.3)
	_view_seat(0)
	await _wait(1.2)
	await _deck_waiting()
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _wait(0.6)
	m = host.series.game
	gs._coin_shown[String(gs.view.get("save_id", "local"))] = true
	for n in gs.get_children():
		if n is CoinFlip:
			n.queue_free()
	_view_seat(0)
	await _wait(2.5)
	await _in_game()
	# Ben concedes: Ana won, Ben chooses who goes first in game 2.
	host.handle(1, {"t": "concede"})
	await _wait(0.3)
	_view_seat(0)
	await _wait(6.0)
	_view_seat(0)
	await _wait(1.0)
	await _rewards()
	await _next_game()
	await _bot_pass()
	_finish()


## A5 again in a bot series (the bot answers at once): the rewards popup after a real game end.
func _bot_pass() -> void:
	main._clear_screens()
	await _wait(0.5)
	main._start_bot({"seed": 77, "best_of": 7, "deck_mode": "starter"})
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
	host.handle(1, {"t": "concede"})   # the bot's seat concedes: Player wins game 1
	await _wait(7.0)
	_check("bot pass: rewards stage", String(gs.view.get("stage", "")) == "rewards", String(gs.view.get("stage", "")))
	var see := _find_button(gs.overlays.overlay_box, "View your deck")
	if see != null:
		await _popup_probe(see, "bot rewards", "a_14_bot_rewards_view_deck")


func _deck_waiting() -> void:
	var box := gs.overlays.overlay_box
	var txt := _texts(box)
	_check("A2 deck waiting: no 'deck locked in' chips", not txt.any(func(t): return t.to_lower().contains(": deck locked in")), str(txt))
	_check("A3 deck waiting: no '(N cards)' suffix", not txt.any(func(t): return t.contains(" cards)")), str(txt))
	var see := _find_button(box, "View your deck")
	_check("A1 deck waiting: View your deck button", see != null and see.name == "ViewDeckButton")
	await _shot("a_01_deck_waiting")
	if see != null:
		await _popup_probe(see, "deck waiting", "a_02_deck_waiting_view_deck")


## Opens the View your deck popup with a real click and checks right-click inspect and Close.
func _popup_probe(see: Button, where: String, shot: String) -> void:
	await _click(see.get_global_rect().get_center())
	await _wait(0.6)
	var pp := gs.overlays.pile_popup
	_check("A5 %s: popup opens" % where, pp.visible)
	var head_txt := _texts(pp)
	_check("A3 %s: popup title has no '(N cards)'" % where, not head_txt.any(func(t): return t.begins_with("Your deck (")), str(head_txt.slice(0, 4)))
	var cards := pp.find_children("*", "CardWidget", true, false)
	if not cards.is_empty():
		var at := (cards[0] as Control).get_global_rect().get_center()
		await _move(at)
		await _wait(0.3)
		var hc := get_viewport().gui_get_hovered_control()
		_check("A5 %s: the pointer over a card reaches the popup" % where, hc != null and pp.is_ancestor_of(hc), str(hc.get_path()) if hc else "none")
		await _shot(shot)
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.position = at
			ev.global_position = at
			ev.button_index = MOUSE_BUTTON_RIGHT
			ev.pressed = pressed
			get_viewport().push_input(ev, true)
			await _frames(1)
		await _wait(0.6)
		_check("A5 %s: right-click opens the inspector" % where, gs.inspect.is_open())
		await _shot(shot + "_inspect")
		gs.inspect.close_all()
		await _wait(0.4)
	var close := _find_button(pp, "Close")
	if close != null:
		var cat := close.get_global_rect().get_center()
		await _move(cat)
		var hc2 := get_viewport().gui_get_hovered_control()
		_check("A5 %s: the pointer over Close reaches it" % where, hc2 == close, str(hc2.get_path()) if hc2 else "none")
		await _click(cat)
		await _wait(0.3)
	_check("A5 %s: Close closes the popup" % where, not pp.visible)


func _in_game() -> void:
	# A4: the in-game menu has no "Game N · first to N wins" line.
	gs.menu.toggle()
	await _wait(0.8)
	_check("A4 menu: no 'first to N wins' line", not gs.menu.series_status.is_visible_in_tree() or not gs.menu.series_status.text.contains("first to"), gs.menu.series_status.text)
	await _shot("a_03_menu_series_no_status_line")
	gs.menu.close_menu()
	await _wait(0.6)
	# A8: hovering a pile shows no tooltip; the pile list and the pile browser have no hint line.
	var ps: PileStack = gs.board.piles[1]["draw"]
	_check("A8 pile stack has no tooltip", ps.tooltip_text == "", ps.tooltip_text)
	await _move(ps.get_global_rect().get_center())
	await _wait(1.6)
	await _shot("a_04_pile_hover_no_tooltip")
	await _click(ps.get_global_rect().get_center())
	await _wait(0.8)
	_check("A8 pile list: no hint line", not gs.details.pile_hint.visible, gs.details.pile_hint.text)
	await _shot("a_05_pile_list_no_hint")
	gs.details.close_pile()
	gs.inspect.open_pile("draw")
	await _wait(0.9)
	var hint: Label = gs.inspect.browser._hint_label if gs.inspect.browser != null else null
	_check("A8 pile browser: no hint line", hint != null and hint.text == "", hint.text if hint else "no browser")
	await _shot("a_06_pile_browser_no_hint")
	gs.inspect.close_all()
	await _wait(0.5)
	_hold = Vector2(-1, -1)


func _rewards() -> void:
	_check("rewards stage", String(gs.view.get("stage", "")) == "rewards", String(gs.view.get("stage", "")))
	await _shot("a_07_rewards")
	var see := _find_button(gs.overlays.overlay_box, "View your deck")
	if see != null:
		await _popup_probe(see, "rewards", "a_08_rewards_view_deck")
	# A6: the remove-a-card list in catalogue order.
	gs.overlays.rewards.choose_mode("remove")
	await _wait(0.8)
	var ids := []
	var seen := {}
	for c in gs.view["deck"]:
		if not seen.has(int(c["id"])):
			seen[int(c["id"])] = true
			ids.append(int(c["id"]))
	var want := CardDB.sort_ids(ids)
	var shown := gs.overlays.rewards.remove_order(gs.view["deck"]).map(func(c): return int(c["id"]))
	_check("A6 remove list in catalogue order", shown == want, "%s vs %s" % [shown, want])
	await _shot("a_09_remove_list_catalogue_order")
	host.handle(0, {"t": "reward_finish"})
	await _wait(0.3)
	_view_seat(0)
	await _wait(1.0)
	var dots: Array = gs.overlays.overlay_box.find_children("*", "WaitingDots", true, false)
	_check("A7 waiting line shown", not dots.is_empty())
	if not dots.is_empty():
		var wd := dots[0] as WaitingDots
		var texts := {}
		var vis := {}
		for i in 12:
			texts[wd.text] = true
			vis[wd.visible_characters] = true
			await _wait(0.15)
		_check("A7 waiting line text keeps still (one text, dots revealed)", texts.size() == 1 and vis.size() > 1, "%s %s" % [texts.keys(), vis.keys()])
	await _shot("a_10_rewards_waiting_a")
	await _wait(0.5)
	await _shot("a_11_rewards_waiting_b")


func _next_game() -> void:
	host.handle(1, {"t": "reward_finish"})
	await _wait(0.3)
	host.handle(0, {"t": "start_duel"})
	await _wait(0.3)
	_view_seat(0)
	await _wait(1.2)
	var box := gs.overlays.overlay_box
	var txt := _texts(box)
	_check("next game: waiting for Ben's choice", txt.any(func(t): return t.contains("choose who goes first")), str(txt))
	_check("A2 next game waiting: no ready chips", not txt.any(func(t): return t.begins_with("You: ")), str(txt))
	var see := _find_button(box, "View your deck")
	_check("A1 next game waiting: View your deck button", see != null and see.name == "ViewDeckButton")
	await _shot("a_12_next_game_waiting")
	if see != null:
		await _popup_probe(see, "next game waiting", "a_13_next_game_view_deck")


func _texts(n: Node) -> Array:
	var out := []
	for l in n.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree() and (l as Label).text != "":
			out.append((l as Label).text)
	return out


func _finish() -> void:
	var fails := checks.filter(func(c): return not c["ok"])
	var f := FileAccess.open(out_dir.path_join("nbatcha_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "passed": checks.size() - fails.size(), "failed": fails.size()}, "  "))
	f.close()
	print("NBATCHA DRIVER DONE: %d passed, %d failed" % [checks.size() - fails.size(), fails.size()])
	get_tree().quit()
