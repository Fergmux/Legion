extends "res://src/dev/f02_driver.gd"
## Development-only windowed evidence for the card database update of 17 Nov 2026 and the mechanic renames
## (design/card-database-update-2026-11-17.md). Launched with
##   godot --path legion -- --carddb1117-shots=<absolute dir>
## Deck builder: a Spirit Unit (Soul of Burning Revenge) and an Arcane Unit (Tyde) in the details pane, the
## new cards; card library: Zadus (transformation-only); a match: Battle Komodo and The Sweeper with their
## Transform buttons, Battle Komodo transforming into Angered Komodo.
## Writes PNG screenshots and `carddb1117_report.json`, then quits.


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
	await _deck_builder()
	await _library()
	await _match()
	_finish()


func _scroll_to(db: DeckBuilder, id: int) -> void:
	var cell := db.cell_widget(id)
	var n: Node = cell
	while n != null and not (n is ScrollContainer):
		n = n.get_parent()
	if n != null:
		(n as ScrollContainer).ensure_control_visible(cell)
	db.show_preview(id)
	await _wait(0.8)


func _deck_builder() -> void:
	main._show_deck_builder()
	await _wait(1.2)
	var db := main.menu as DeckBuilder
	await _scroll_to(db, 202)
	await _shot("01_deckbuilder_spirit_soul_of_burning_revenge")
	await _scroll_to(db, 172)
	await _shot("02_deckbuilder_arcane_tyde")
	await _scroll_to(db, 198)
	await _shot("03_deckbuilder_muscle_new_unit")
	await _scroll_to(db, 201)
	await _shot("04_deckbuilder_heretic_spirit")
	main._clear_screens()
	await _wait(0.4)


func _library() -> void:
	main._show_card_list()
	await _wait(1.5)
	var cl = main.menu
	cl.browser.select(35)
	await _wait(0.5)
	await _shot("05_library_battle_komodo_transform_section")
	var ins: CardInspector = cl.inspect_card(203, cl._preview_card)
	await _wait(1.0)
	_check("Zadus inspector opens", ins != null)
	await _shot("06_library_zadus")
	if ins:
		ins.close()
	await _wait(0.4)
	main._clear_screens()
	await _wait(0.4)


func _match() -> void:
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
	uids["komodo"] = _put(a, 35, 0, "atk")
	m.mark(uids["komodo"], "destroyed_unit")    # as if it had destroyed a unit last turn
	uids["sweeper"] = _put(a, 29, 1, "atk")
	m.apply_status(uids["sweeper"], "eternal", 1)
	uids["foe"] = _put(o, 1, 1, "atk")
	m.add_log("[dev] Board arranged for the 17 Nov card database verification run.")
	m.players[a]["ap"] = 6
	host.broadcast()
	_view_seat(a)
	await _wait(4.5)
	var ki := _transform_idx(uids["komodo"])
	var si := _transform_idx(uids["sweeper"])
	_check("Battle Komodo may transform", m.validate(a, {"t": "ability", "uid": uids["komodo"], "idx": ki}) == "")
	_check("The Sweeper may transform", m.validate(a, {"t": "ability", "uid": uids["sweeper"], "idx": si}) == "")
	await _shot("07_match_transform_buttons")
	host.handle(a, {"t": "ability", "uid": uids["komodo"], "idx": ki})
	await _wait(0.6)
	await _shot("08_match_komodo_transforming")
	await _wait(3.0)
	_check("Battle Komodo became Angered Komodo", int(m.cards[uids["komodo"]]["id"]) == 199)
	await _shot("09_match_angered_komodo")


func _transform_idx(uid: int) -> int:
	var abs: Array = m.script_of(uid).get("abilities", [])
	for i in abs.size():
		if abs[i].get("transform", false):
			return i
	return -1


func _finish() -> void:
	var fails := checks.filter(func(c): return not c["ok"])
	var f := FileAccess.open(out_dir.path_join("carddb1117_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "passed": checks.size() - fails.size(), "failed": fails.size()}, "  "))
	f.close()
	print("CARDDB1117 DRIVER DONE: %d passed, %d failed" % [checks.size() - fails.size(), fails.size()])
	get_tree().quit()
