extends SceneTree
## Dev-only windowed evidence for the M batch card items (owner feedback 9 Nov 2026):
##   M2  a hovered draft offer card stays lifted / tilted while the opponent drafts (views arrive);
##   M6  the inspect modal shows coloured rule sections from every entry point;
##   M7  right-click inspect in the deck builder / card library zooms from the clicked card and
##       lands exactly on the inspector's card;
##   M8  new cards sit with their kind in the deck builder catalogue and deck list.
## Run NOT headless:
##   godot --path legion -s res://src/dev/m_batch_cards_shots.gd -- <absolute output dir> [WxH] [parts]
## `parts` is a comma list of m2,m6,m7,m8 (default all). Saves JPGs (q88, <= 1600 px wide), prints
## PASS / FAIL and quits with the number of failures. Uses the TEST deck / stats paths (a -s run).

var out_dir: String = ""
var main: Node
var fails: int = 0
var parts: Array = ["m2", "m6", "m7", "m8"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://m_batch_cards"
	var sz := Vector2i(1600, 1000)
	if args.size() > 1 and String(args[1]).contains("x"):
		var p := String(args[1]).split("x")
		sz = Vector2i(int(p[0]), int(p[1]))
	if args.size() > 2:
		parts = Array(String(args[2]).split(","))
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(sz)
	root.size = sz
	SeriesStore.DIR = "user://dev_saves_m_batch"
	PlayerProgress.persist = false
	create_timer(240.0).timeout.connect(func(): print("FAIL watchdog"); quit(99))
	run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _sleep(secs: float) -> void:
	await create_timer(secs).timeout


func _wait(cond: Callable, secs: float = 10.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		return
	if img.get_width() > 1600:
		img.resize(1600, int(img.get_height() * 1600.0 / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_jpg(out_dir.path_join(name + ".jpg"), 0.88)
	print("SHOT ", name)


func _check(name: String, ok: bool, detail: String = "") -> void:
	if not ok:
		fails += 1
	print("%s  %s %s" % ["PASS" if ok else "FAIL", name, detail])


func _move(pos: Vector2) -> void:
	# The real cursor too: code that reads the pointer position (not events) sees the same place.
	Input.warp_mouse(root.get_final_transform() * pos)   # window pixels (the window may be scaled)
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	mv.relative = Vector2(2, 0)
	root.push_input(mv, true)
	await _frames(2)


func _click(pos: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	await _move(pos)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = down
		e.position = pos
		e.global_position = pos
		root.push_input(e, true)
		await _frames(1)


func _gs() -> GameScreen:
	return main.screen if main != null and is_instance_valid(main.screen) else null


func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(10)
	main._auto_started = true
	main._privacy = false
	if "m2" in parts:
		await _m2()
	if "m6" in parts:
		await _m6()
	if "m7" in parts:
		await _m7()
	if "m8" in parts:
		await _m8()
	print("M BATCH CARDS DONE fails=%d" % fails)
	quit(fails)


# ---------------------------------------------------------------- M2 draft hover
func _offer_cards() -> Array:
	var gs := _gs()
	if gs == null:
		return []
	var row := gs.overlays.overlay_box.find_child("Offer", true, false)
	if row == null:
		return []
	return row.find_children("*", "CardWidget", true, false)


func _m2() -> void:
	main._start_local({"seed": 4242, "best_of": 3, "deck_mode": "draft", "names": ["Ana", "Ben"]})
	await _wait(func(): return _gs() != null and not _gs().view.is_empty(), 5.0)
	await _sleep(1.5)
	var cards := _offer_cards()
	_check("M2 draft offer shown", cards.size() >= 2, str(cards.size()))
	if cards.size() < 2:
		return
	var cw: CardWidget = cards[1]
	var at := cw.get_global_rect().get_center() + Vector2(30, 0)
	for i in cards.size():
		var w: CardWidget = cards[i]
		var k := i
		w.mouse_entered.connect(func(): print("  [t=%d] enter card %d" % [Time.get_ticks_msec(), k]))
		w.mouse_exited.connect(func(): print("  [t=%d] exit card %d" % [Time.get_ticks_msec(), k]))
		w.tree_exiting.connect(func(): print("  [t=%d] freed card %d" % [Time.get_ticks_msec(), k]))
	await _move(at)
	await _sleep(0.5)
	_check("M2 hovered card lifts", cw.lift_k > 1.01, "lift_k=%.3f" % cw.lift_k)
	_check("M2 hovered card tilts", absf(cw.rotation_degrees) > 0.5 or UIStyle.reduce_motion, "rot=%.2f" % cw.rotation_degrees)
	print("  window=%s root=%s card rect=%s lift_k=%.3f final=%s" % [DisplayServer.window_get_size(), root.size, cw.get_global_rect(), cw.lift_k, root.get_final_transform()])
	await _shot("m2-draft-hover-before")
	# The opponent (seat 1) drafts: each pick changes the view this seat receives.
	var host: LocalHost = main._sessions.local_host
	for i in 3:
		host.handle(1, {"t": "draft_pick", "index": 0})
		await _sleep(0.45)
		var now := _offer_cards()
		var same: bool = now.size() > 1 and now[1] == cw
		var hovered: CardWidget = now[1] if now.size() > 1 else null
		print("  after opponent pick %d: same widget=%s lift_k=%.3f rot=%.2f size=%s min=%s" % [i + 1, same,
			hovered.lift_k if hovered else -1.0, hovered.rotation_degrees if hovered else 0.0,
			hovered.size if hovered else Vector2.ZERO, hovered.custom_minimum_size if hovered else Vector2.ZERO])
		_check("M2 card still lifted after opponent pick %d" % (i + 1), hovered != null and hovered.lift_k > 1.01 and hovered.size.x > hovered.custom_minimum_size.x + 1.0,
			"lift_k=%.3f" % (hovered.lift_k if hovered else -1.0))
		_check("M2 card still tilted after opponent pick %d" % (i + 1), hovered != null and (absf(hovered.rotation_degrees) > 0.5 or UIStyle.reduce_motion))
	await _shot("m2-draft-hover-after-opponent-picks")
	# A full rebuild (same offer) under the still pointer: the new widget comes back hovered.
	_gs().overlays.refresh()
	await _sleep(0.5)
	var rebuilt := _offer_cards()
	var rb: CardWidget = rebuilt[1] if rebuilt.size() > 1 else null
	_check("M2 rebuild made new widgets", rb != null and rb != cw)
	_check("M2 a rebuilt card under the still pointer comes back lifted", rb != null and rb.lift_k > 1.01, "lift_k=%.3f pointer_inside=%s" % [rb.lift_k if rb else -1.0, rb.pointer_inside() if rb else false])
	await _shot("m2-draft-rebuilt-under-still-pointer")
	# Leaving the card drops the lift.
	await _move(Vector2(40, 40))
	await _sleep(0.5)
	var after := _offer_cards()
	var c1: CardWidget = after[1] if after.size() > 1 else null
	_check("M2 leaving the card drops the lift", c1 != null and c1.lift_k < 1.005 and absf(c1.rotation_degrees) < 0.2,
		"lift_k=%.3f rot=%.2f" % [c1.lift_k if c1 else -1.0, c1.rotation_degrees if c1 else 0.0])
	# Our own pick rebuilds the offer under a still pointer: the new card under it comes back hovered.
	var c0: CardWidget = after[0]
	var p0 := c0.get_global_rect().get_center()
	await _click(p0)
	await _sleep(1.4)
	var fresh := _offer_cards()
	var under: CardWidget = null
	for w in fresh:
		if (w as CardWidget).get_global_rect().has_point(p0):
			under = w
	_check("M2 a rebuilt card under the pointer comes back hovered", under != null and under.lift_k > 1.01, "lift_k=%.3f" % (under.lift_k if under else -1.0))
	await _shot("m2-draft-new-offer-under-pointer")
	main._clear_screens()
	await _sleep(0.5)


# ---------------------------------------------------------------- M6 rule sections everywhere
func _m6() -> void:
	# The draft: right-click an offer card.
	main._start_local({"seed": 4242, "best_of": 3, "deck_mode": "draft", "names": ["Ana", "Ben"]})
	await _wait(func(): return _gs() != null and not _gs().view.is_empty(), 5.0)
	await _sleep(1.5)
	var cards := _offer_cards()
	if not cards.is_empty():
		var cw: CardWidget = cards[0]
		await _click(cw.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
		await _sleep(0.8)
		var ins := _ins()
		_check("M6 draft inspect has timing sections", ins != null and (ins.card().get("text_parts", []) as Array).size() >= 1,
			str(ins.card().get("text_parts", []) if ins else []))
		await _shot("m6-draft-inspect-sections")
		if ins:
			ins.close()
		await _sleep(0.5)
	main._clear_screens()
	await _sleep(0.4)
	# The card library: Symbiote Spawn (the owner's example) in the details pane and the inspector.
	main._show_card_list()
	await _sleep(1.5)
	var cl = main.menu
	cl.browser.select(155)
	await _sleep(0.6)
	_check("M6 card library pane shows Spawn's sections", (cl._details.sections as Array).has("rules"))
	await _shot("m6-cardlist-spawn-pane")
	var ins2: CardInspector = cl.inspect_card(155, cl._preview_card)
	await _sleep(0.8)
	_check("M6 card library inspector: Spawn has 3 rule sections", ins2 != null and (ins2.card()["text_parts"] as Array).size() == 3)
	await _shot("m6-cardlist-spawn-inspect")
	ins2.close()
	await _sleep(0.5)


func _ins() -> CardInspector:
	return CardInspector.topmost()


## Right-clicks `w` and follows the inspector's flying copy: returns {start, end, final, frames} with
## the ghost's first and last global rects and the inspector card's resting rect.
func _follow_fly(w: Control, prefix: String) -> Dictionary:
	await _move(w.get_global_rect().get_center())
	await _sleep(0.3)
	var src := w.get_global_rect()   # where it is on screen (a hovered card is lifted)
	await _click(w.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	var ins := _ins()
	var out := {"src": src, "start": Rect2(), "end": Rect2(), "final": Rect2(), "frames": 0, "from": Rect2()}
	if ins == null:
		return out
	out["from"] = ins._from
	var shot_mid := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900:
		var g: CardWidget = ins._ghost
		if g != null and is_instance_valid(g) and g.is_inside_tree():
			var r := g.get_global_rect()
			if out["frames"] == 0:
				out["start"] = r
			out["end"] = r
			out["frames"] = int(out["frames"]) + 1
			if not shot_mid and Time.get_ticks_msec() - t0 > 50:
				shot_mid = true
				await _shot(prefix + "-mid-flight")
		await process_frame
	await _sleep(0.4)
	out["final"] = ins._card_widget.get_global_rect()
	out["landed"] = ins.fly_landed
	await _shot(prefix + "-at-rest")
	return out


func _near(a: Rect2, b: Rect2, tol: float) -> bool:
	return a.position.distance_to(b.position) <= tol and absf(a.size.x - b.size.x) <= tol and absf(a.size.y - b.size.y) <= tol


func _report_fly(name: String, f: Dictionary) -> void:
	print("  %s: src=%s ghost start=%s landed=%s final=%s frames=%d" % [name, f["src"], f["start"], f.get("landed"), f["final"], f["frames"]])
	_check("M7 %s: the zoom starts from the clicked card" % name, f["frames"] > 0 and _near(f["from"], f["src"], 1.0) and _near(f["start"], f["src"], 40.0))
	_check("M7 %s: the zoom lands on the inspector's card" % name, f["frames"] > 0 and _near(f.get("landed", Rect2()), f["final"], 1.0))


func _m7() -> void:
	main._show_deck_builder()
	await _sleep(1.2)
	var db := main.menu as DeckBuilder
	var id := 155   # Symbiote Spawn
	var cell := db.cell_widget(id)
	db.browser.grid.get_parent()
	db.browser.select(id)
	await _sleep(0.3)
	db.add_card(id, 2)
	await _sleep(0.6)
	# 1. the catalogue cell
	var n: Node = cell
	while n != null and not (n is ScrollContainer):
		n = n.get_parent()
	if n != null:
		(n as ScrollContainer).ensure_control_visible(cell)
	await _sleep(0.3)
	_report_fly("deck builder catalogue", await _follow_fly(cell, "m7-deckbuilder-catalogue"))
	_ins().close()
	await _sleep(0.6)
	# 2. the preview card in the details pane
	db.show_preview(id)
	await _sleep(0.5)
	_report_fly("deck builder preview card", await _follow_fly(db._preview_card, "m7-deckbuilder-preview"))
	_ins().close()
	await _sleep(0.6)
	# 3. the deck list tile
	var tile: Control = db._deck_tiles.get(id)
	var tw: Control = (tile.get_meta("rec") as Dictionary)["widget"] if tile != null else null
	if tw != null:
		_report_fly("deck builder deck tile", await _follow_fly(tw, "m7-deckbuilder-decktile"))
		_ins().close()
		await _sleep(0.6)
	main._show_card_list()
	await _sleep(1.5)
	var cl = main.menu
	if cl != null and cl.has_method("inspect_card"):
		cl.browser.select(id)
		await _sleep(0.5)
		_report_fly("card library preview card", await _follow_fly(cl._preview_card, "m7-cardlist-preview"))
		_ins().close()
		await _sleep(0.6)
		# A catalogue cell scrolled out of view gives no fly source (it used to fly in from off screen).
		var far: CardWidget = cl.browser.cell_widget(id)
		var ins2: CardInspector = cl.inspect_card(id)
		_check("M7 card library: a scrolled-off catalogue cell is not a fly source", ins2 != null and (not far.get_global_rect().intersects(root.get_visible_rect()) or ins2._from.size.x > 0.0) and (ins2._from.size.x == 0.0 or ins2._from.intersects(root.get_visible_rect())),
			"cell=%s from=%s" % [far.get_global_rect(), ins2._from if ins2 else Rect2()])
		ins2.close()
		await _sleep(0.6)


# ---------------------------------------------------------------- M8 new cards among their kind
func _m8() -> void:
	main._show_deck_builder()
	await _sleep(1.2)
	var db := main.menu as DeckBuilder
	var trap: int = CardDB.collectible().filter(func(d): return d["category"] == "trap")[0]["id"]
	var power: int = CardDB.collectible().filter(func(d): return d["category"] == "power")[0]["id"]
	var spell: int = CardDB.collectible().filter(func(d): return d["category"] == "spell")[0]["id"]
	var fusion: int = CardDB.collectible().filter(func(d): return d["category"] == "fusion")[0]["id"]
	var arcane: int = CardDB.collectible().filter(func(d): return d["category"] == "arcane")[0]["id"]
	for id in [191, power, trap, spell, 189, 190, arcane, fusion]:
		db.add_card(id, 1)
	await _sleep(1.0)
	var main_flow: HFlowContainer = db._sections["main"]["flow"]
	var main_ids: Array = main_flow.get_children().map(func(t): return int(t.get_meta("card_id")))
	var extra_ids: Array = (db._sections["extra"]["flow"] as HFlowContainer).get_children().map(func(t): return int(t.get_meta("card_id")))
	_check("M8 deck list Main: spell, traps (Box last), power", main_ids == [spell, trap, 191, power], str(main_ids))
	_check("M8 deck list Extra: fusions (new ones last), then arcane", extra_ids == [fusion, 189, 190, arcane], str(extra_ids))
	# The catalogue around Do Not Open Box: the last Traps, then the first Powers.
	var cell := db.cell_widget(191)
	var n: Node = cell
	while n != null and not (n is ScrollContainer):
		n = n.get_parent()
	if n != null:
		(n as ScrollContainer).ensure_control_visible(cell)
	db.show_preview(191)
	await _sleep(0.8)
	_check("M8 catalogue: Box right before the first Power", db.browser.cell(191).get_index() + 1 == db.browser.cell(power).get_index())
	_check("M8 catalogue: Snow Tiger right before the first Arcane", db.browser.cell(190).get_index() + 1 == db.browser.cell(arcane).get_index())
	await _shot("m8-deckbuilder-box-among-traps")
	var cell2 := db.cell_widget(189)
	if n != null:
		(n as ScrollContainer).ensure_control_visible(cell2)
	await _sleep(0.6)
	await _shot("m8-deckbuilder-fusions-in-place")
