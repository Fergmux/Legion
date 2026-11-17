extends "res://src/dev/f02_driver.gd"
## Development-only windowed evidence for owner feedback of 16 Nov 2026, items B1-B9
## (design/owner-feedback-2026-11-16.md). Launched with
##   godot --path legion -- --nbatchb-shots=<absolute dir>
## A hot-seat match staged on turn 2: the details pane's empty state (no sub line), next turn's AP as a
## pending gem socket (no "next turn +1 AP" text), Sneaky Snunday active with no note by the phase
## button, a ?/? unit (Ultimate Dragon) with stats above / below the base it was given, Dante's
## details (Once per turn and On Field apart), a revealed set card's Reveal ("Permanent"), the game
## log hidden to its thin bar, the opponent's Assassinate arrow during an Energy Capture prompt, and
## a Transform prompt with no hint line. Writes PNGs prefixed "b_" and `nbatchb_report.json`, then quits.

const DANTE := 36
const ULTIMATE_DRAGON := 151
const ASSASSINATE := 84
const ENERGY_CAPTURE := 85
const SPAWN := 155


func run(main_node: Node, dir: String) -> void:
	main = main_node
	out_dir = dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	if not Sfx._loaded:
		Sfx.load_settings()
	Sfx._muted = true   # in memory only
	GameLog.store_hidden(false, false)
	await _frames(5)
	main._privacy = false
	await _match()
	_finish()


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
	# B3: a ?/? unit given a 30/24 base on arrival, then +6 ATK and -4 DEF from effects.
	uids["dragon"] = _put(a, ULTIMATE_DRAGON, 0, "atk")
	m.cards[uids["dragon"]]["base_atk"] = 30
	m.cards[uids["dragon"]]["base_def"] = 24
	m.cards[uids["dragon"]]["mods"].append({"atk": 6, "def": -4, "until": "perm", "src": "dev"})
	uids["dante"] = _put(a, DANTE, 1, "atk")
	# B5: the opponent's unit Assassinate will target, and their set Energy Capture.
	uids["victim"] = _put(o, 1, 1, "atk")
	uids["trap"] = _set_card(o, ENERGY_CAPTURE, 0)
	# B6: a revealed set card of the opponent.
	uids["revealed"] = _set_card(o, 182, 2)
	m.cards[uids["revealed"]]["st"]["reveal"] = 1
	# B2: the opponent's Symbiote Spawn, asked to transform at the start of their turn.
	uids["spawn"] = _put(o, SPAWN, 4, "atk")
	# B7: Sneaky Snunday active this turn. B8: Delayed Gratification's +1 AP next turn.
	m.reversal_turn = m.turn
	m.reversal_count = 1
	m.players[a]["ap"] = 6
	m.players[a]["ap_next"].append({"n": 1, "src": "Delayed Gratification"})
	m.add_log("[dev] Board arranged for the 16 Nov N batch (B items) verification run.")
	host.broadcast()
	_view_seat(a)
	await _move(Vector2(1120, 640))   # rest the pointer on an empty part of the board
	await _wait(6.5)   # past the coin flip
	_check("B1 empty details has no sub line", gs.details.empty_art.sub == "")
	_check("B7 no Sneaky Snunday note", not gs.sidebar.turn_note.visible)
	var pl: PlayerPlate = gs.plate_of(a)
	_check("B8 pending gem socket", pl.ap_gems.total_slots() == pl.ap_gems.slots() + 1)
	_check("B8 no next-turn text", pl.next_label.text == "")
	# Sneaky Snunday reverses the +6 ATK / -4 DEF this turn: 24 ATK (below its 30 base), 28 DEF (above 24).
	_check("B3 dragon ATK below its given base (reversed)", CardStatBadge.trend(_w_slot(a, "unit", 0).view, true) == -1)
	_check("B3 dragon DEF above its given base (reversed)", CardStatBadge.trend(_w_slot(a, "unit", 0).view, false) == 1)
	await _shot("b_01_board_empty_details_ap_gems_snunday_qmark_unit")
	# B8 close-up: my plate's gem row, x3.
	var r := pl.get_global_rect().grow(6.0)
	var img := get_viewport().get_texture().get_image().get_region(Rect2i(r))
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_LANCZOS)
	img.save_png(out_dir.path_join("b_01b_ap_gems_pending_socket_x3.png"))
	# B4: Dante's details.
	await _click(_slot_rect(a, "unit", 1).get_center())
	await _move(Vector2(1120, 640))
	await _wait(1.0)
	await _shot("b_02_dante_details_sections")
	# B6: the revealed set card's Reveal status.
	await _click(_slot_rect(o, "backrow", 2).get_center())
	await _move(Vector2(1120, 640))
	await _wait(1.0)
	await _shot("b_03_reveal_permanent")
	# B9: the log hidden to its thin bar, then shown again.
	gs.game_log.set_hidden(true, false)
	await _wait(1.0)
	_check("B9 log well hidden", not gs.game_log.well.visible)
	await _shot("b_04_game_log_hidden")
	gs.game_log.set_hidden(false, false)
	await _wait(1.0)
	await _shot("b_05_game_log_shown_again")
	# B5: Assassinate on the opponent's unit; their Energy Capture prompt shows the arrow.
	var sp := m._create_instance(ASSASSINATE, a)
	m.cards[sp]["zone"] = "hand"
	m.players[a]["hand"].append(sp)
	host.broadcast()
	await _wait(0.6)
	host.handle(a, {"t": "cast", "uid": sp})
	await _wait(0.6)
	if m.pending.get("kind", "") == "select":
		host.handle(a, {"t": "choose", "id": m.pending["id"], "values": [uids["victim"]]})
	await _wait(1.5)
	_check("B5 trap prompt for the opponent", String(m.pending.get("kind", "")) == "trap_response" and int(m.pending.get("player", -1)) == o)
	_view_seat(o)
	await _wait(2.5)
	_check("B5 arrow on", gs.arrow.on)
	_check("B5 public target in the view", not gs.pending().get("cause", {}).get("targets", []).is_empty())
	await _shot("b_06_trap_prompt_shows_assassinate_arrow")
	host.handle(o, {"t": "choose", "id": m.pending["id"], "indices": [0]})   # Skip
	await _wait(2.5)
	# Transform: end this turn; the opponent is asked to transform Symbiote Spawn.
	_view_seat(a)
	for i in 8:
		if m.active != a or not m.pending.is_empty():
			break
		host.handle(a, {"t": "next_phase"})
		await _wait(0.6)
	for i in 6:
		if String(m.pending.get("kind", "")) == "transform" or m.pending.is_empty():
			break
		host.handle(int(m.pending["player"]), {"t": "choose", "id": m.pending["id"], "indices": [0]})
		await _wait(0.6)
	_check("Transform prompt asked", String(m.pending.get("kind", "")) == "transform")
	# Turn 3, no reversal: the ?/? unit reads 36 ATK (raised) and 20 DEF (lowered) against its 30/24 base.
	_check("B3 dragon ATK above its given base", CardStatBadge.trend(MatchView.card_view(m, uids["dragon"], o), true) == 1)
	_check("B3 dragon DEF below its given base", CardStatBadge.trend(MatchView.card_view(m, uids["dragon"], o), false) == -1)
	_view_seat(o)
	await _wait(3.0)
	_check("B2 no hint under the Transform prompt", not gs.prompt.banner_sub.visible)
	await _shot("b_07_transform_prompt_no_hint")


func _set_card(p: int, id: int, col: int) -> int:
	var uid := m._create_instance(id, p)
	m.cards[uid]["zone"] = "backrow"
	m.cards[uid]["slot"] = col
	m.cards[uid]["ctl"] = p
	m.cards[uid]["set_turn"] = m.turn - 1
	m.players[p]["backrow"][col] = uid
	return uid


func _finish() -> void:
	var fails := checks.filter(func(c): return not c["ok"])
	var f := FileAccess.open(out_dir.path_join("nbatchb_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "passed": checks.size() - fails.size(), "failed": fails.size()}, "  "))
	f.close()
	print("NBATCHB DRIVER DONE: %d passed, %d failed" % [checks.size() - fails.size(), fails.size()])
	get_tree().quit()
