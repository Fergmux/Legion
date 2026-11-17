extends "res://src/dev/f02_driver.gd"
## Development-only windowed evidence for the card database update of 10 Nov 2026
## (design/card-database-update-2026-11-10.md). Launched with
##   godot --path rldb -- --carddb1110-shots=<absolute dir>
## 1. Deck builder: Draw Virus is greyed "Disabled" in the catalogue, cannot be added, and shows greyed
##    in a deck that still holds it; the new cards (192-196) sit with their kinds, with their new art.
## 2. Card library: The Great Leviathan (transformation-only) in the inspector.
## 3. A hot-seat match: Edwin (Burn, ATK above base) and Divine Serpent - Soul (Head, Body and Tail on the
##    Field) show a Transform button; Edwin transforms into Avatar, Soul into The Great Leviathan.
## Writes PNG screenshots and `carddb1110_report.json`, then quits.

const DRAW_VIRUS := 44
const EDWIN := 16
const SOUL := 160


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
	_check("Draw Virus cannot be added", db.add_card(DRAW_VIRUS, 1) == 0)
	_check("Draw Virus cell is marked disabled", db.cell_widget(DRAW_VIRUS).find_child("DisabledBand", true, false) != null)
	await _scroll_to(db, DRAW_VIRUS)
	await _shot("01_deckbuilder_draw_virus_disabled")
	# A saved deck from before the switch still holding it: shown greyed in the deck list.
	db.counts[DRAW_VIRUS] = 1
	db._recount()
	db._refresh_deck()
	for id in [192, 193, 194, 195, 196]:
		db.add_card(id, 1)
	await _wait(0.8)
	await _shot("02_deckbuilder_saved_deck_with_draw_virus_and_new_cards")
	await _scroll_to(db, 194)
	await _shot("03_deckbuilder_new_traps")
	await _scroll_to(db, 196)
	await _shot("04_deckbuilder_serpent_tail")
	await _scroll_to(db, 192)
	await _shot("05_deckbuilder_mithral_dome")
	main._clear_screens()
	await _wait(0.4)


func _library() -> void:
	main._show_card_list()
	await _wait(1.5)
	var cl = main.menu
	cl.browser.select(SOUL)
	await _wait(0.5)
	var ins: CardInspector = cl.inspect_card(197, cl._preview_card)
	await _wait(1.0)
	_check("Leviathan inspector opens", ins != null)
	await _shot("06_library_great_leviathan")
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
	uids["edwin"] = _put(a, EDWIN, 0, "atk")
	m.apply_status(uids["edwin"], "burn", 1)
	m.cards[uids["edwin"]]["mods"].append({"atk": 4, "def": 0, "until": "perm", "src": "dev"})
	uids["head"] = _put(a, 158, 1, "atk")
	uids["body"] = _put(a, 159, 2, "atk")
	uids["tail"] = _put(a, 196, 4, "atk")
	uids["soul"] = _put(a, SOUL, 5, "atk")
	uids["foe"] = _put(o, 1, 1, "atk")
	var pw := m._create_instance(149, o)
	m.cards[pw]["zone"] = "power"
	m.cards[pw]["slot"] = 0
	m.cards[pw]["face_up"] = true
	m.players[o]["powers"][0] = pw
	m.add_log("[dev] Board arranged for the 10 Nov card database verification run.")
	m.players[a]["ap"] = 6
	host.broadcast()
	_view_seat(a)
	await _wait(4.5)
	_check("Edwin may transform", m.validate(a, {"t": "ability", "uid": uids["edwin"], "idx": 0}) == "")
	_check("Soul may transform", m.validate(a, {"t": "ability", "uid": uids["soul"], "idx": 1}) == "")
	await _shot("07_match_transform_buttons")
	host.handle(a, {"t": "ability", "uid": uids["edwin"], "idx": 0})
	await _wait(0.6)
	await _shot("08_match_edwin_transforming")
	await _wait(2.5)
	_check("Edwin became Avatar", int(m.cards[uids["edwin"]]["id"]) == 14)
	await _shot("09_match_avatar")
	host.handle(a, {"t": "ability", "uid": uids["soul"], "idx": 1})
	for i in 6:
		await _wait(0.6)
		if m.pending.is_empty():
			break
		host.handle(int(m.pending["player"]), {"t": "choose", "id": m.pending["id"], "indices": [0]})
	await _wait(0.8)
	await _shot("10_match_leviathan_arriving")
	await _wait(9.0)
	_check("Soul became The Great Leviathan", int(m.cards[uids["soul"]]["id"]) == 197)
	_check("Head, Body and Tail exhausted", ["head", "body", "tail"].all(func(k): return String(m.cards[uids[k]]["zone"]) == "exhaust"))
	_check("the opponent's Power was destroyed", not m.on_field(pw))
	await _shot("11_match_leviathan")


func _finish() -> void:
	var fails := checks.filter(func(c): return not c["ok"])
	var f := FileAccess.open(out_dir.path_join("carddb1110_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "passed": checks.size() - fails.size(), "failed": fails.size()}, "  "))
	f.close()
	print("CARDDB1110 DRIVER DONE: %d passed, %d failed" % [checks.size() - fails.size(), fails.size()])
	get_tree().quit()
