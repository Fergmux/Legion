extends SceneTree
## Development-only evidence driver for the M batch in-match items (owner feedback 9 Nov 2026):
## M1 the in-game menu takes clicks (and a click off it still closes it), M4 the series score lives in
## the menu, M9 the player plates clear the field zones and the icon Menu button sits left of the
## opponent's plate, M13 the table light is a round glow over the middle of the field.
## Run windowed from legion/:
##   godot --path . -s res://src/dev/m_ingame_shots.gd -- --out=<abs dir> [--size=1600x900] [--best-of=3]
## Prints PASS / FAIL lines and exits 1 when a check fails. Uses test paths for every user file.

var main: Node
var host: LocalHost
var m: MatchEngine
var gs: GameScreen
var out_dir := ""
var want := Vector2i(1600, 900)
var best_of := 3
var tag := ""
var fails := 0
var names := ["Ana", "Ben"]
var show_chat := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.split("=", true, 1)[1]
		elif arg.begins_with("--size="):
			var p := arg.split("=")[1].split("x")
			want = Vector2i(int(p[0]), int(p[1]))
		elif arg.begins_with("--best-of="):
			best_of = int(arg.split("=")[1])
		elif arg.begins_with("--names="):
			names = Array(arg.split("=", true, 1)[1].split(","))
		elif arg == "--chat":
			show_chat = true
	tag = "%dx%d_bo%d%s" % [want.x, want.y, best_of, "_chat" if show_chat else ""]
	DirAccess.make_dir_recursive_absolute(out_dir)
	SeriesStore.DIR = "user://dev_saves_m_ingame"
	DeckStore.PATH = "user://dev_m_ingame_decks.json"
	PlayerStats.PATH = "user://dev_m_ingame_stats.json"
	PlayerProgress.persist = false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(want)
	root.size = want
	_run.call_deferred()


func _run() -> void:
	await _wait(0.3)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _wait(0.5)
	DisplayServer.window_set_size(want)
	root.size = want
	await _wait(0.4)
	main._auto_started = true
	main._privacy = false
	main._sessions.start_local({"seed": 9, "best_of": best_of, "deck_mode": "starter", "names": names})
	await _wait(0.5)
	host = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 1})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _wait(0.4)
	m = host.series.game
	gs = main.screen
	gs._coin_shown[String(gs.view.get("save_id", "local"))] = true
	for n in gs.get_children():
		if n is CoinFlip:
			n.queue_free()
	_stage()
	await _wait(1.5)
	_move(gs.get_global_transform() * Vector2(gs.board._ux - 260.0, gs.board._y0 + 360.0))
	await _wait(0.6)
	_freeze_motes()
	await _snap("board")
	_check_layout()
	await _glow_checks()
	if best_of > 1:
		await _menu_checks()
	else:
		gs.menu.toggle()
		await _wait(0.6)
		await _snap("menu_single")
		gs.menu.close_menu()
		await _wait(0.5)
	print("M INGAME SHOTS DONE %s fails=%d" % [tag, fails])
	quit(1 if fails > 0 else 0)


## Units, set cards and Power on both halves, so every zone kind is in use.
func _stage() -> void:
	m.submit(m.active, {"t": "next_phase"})
	m.submit(m.active, {"t": "next_phase"})
	for p in 2:
		TB.unit(m, p, 110, 0, "atk", 10)
		TB.unit(m, p, 1, 4, "def", 12)
		TB.set_card(m, p, 49, 2)
		TB.card(m, p, 1, "spent")
	host.broadcast()


func _check_layout() -> void:
	_force_chat()
	var zones: Array = []
	for side in 2:
		for zone in GameBoardView.ZONE_SLOTS:
			for s in GameBoardView.ZONE_SLOTS[zone]:
				var it: Dictionary = gs.board.slots[GameBoardView.key(side, zone, s)]
				zones.append([zone, (it["zone_node"] as Control).get_global_rect()])
		for z in gs.board.piles[side]:
			zones.append(["pile " + z, (gs.board.piles[side][z] as Control).get_global_rect()])
	for side in 2:
		var pr: Rect2 = (gs.board.plates[side] as Control).get_global_rect()
		var hit := ""
		for z in zones:
			if pr.intersects(z[1]):
				hit = "%s %s" % [z[0], z[1]]
		_check("plate %d clears every zone at %s" % [side, tag], hit == "", "plate %s hit %s" % [pr, hit])
		var vis := gs.get_global_rect()
		_check("plate %d on screen at %s" % [side, tag], vis.encloses(pr), str(pr))
	var mb: Control = gs.menu.menu_button
	var opp: Rect2 = (gs.board.plates[0] as Control).get_global_rect()
	var br := mb.get_global_rect()
	_check("menu button left of the opponent plate at %s" % tag, br.end.x <= opp.position.x and br.end.x >= opp.position.x - 24.0
			and br.get_center().y > opp.position.y and br.get_center().y < opp.end.y, "button %s plate %s" % [br, opp])
	for b in gs.menu.top_strip.find_children("*", "BaseButton", true, false):
		var c := b as Control
		if c.is_visible_in_tree() and c != mb:
			_check("%s clear of the menu button and plate at %s" % [c.name, tag],
					not c.get_global_rect().intersects(br) and not c.get_global_rect().intersects(opp), str(c.get_global_rect()))


## M13: the glow brightens the field's centre and leaves the corners alone. Saves the board with the
## glow off and a 6x-strength view of its shape (diagnostic only), and prints the measured lift.
func _glow_checks() -> void:
	var dust: AmbientMotes = gs.board.dust
	var on := await _grab()
	var mat := dust.glow_rect.material as ShaderMaterial
	dust.glow_rect.visible = false
	var off := await _grab()
	dust.glow_rect.visible = true
	var c := root.get_final_transform() * (gs.get_global_transform() * gs.board.field_center())
	var corner := root.get_final_transform() * (gs.get_global_transform() * Vector2(30, gs.size.y * 0.5))
	var lift_c := _lum(on, c) - _lum(off, c)
	var lift_e := _lum(on, corner) - _lum(off, corner)
	print("glow lift centre %.4f edge %.4f" % [lift_c, lift_e])
	_check("glow lifts the field centre", lift_c > 0.004, "lift %.4f" % lift_c)
	_check("glow leaves the far edge alone", absf(lift_e) < 0.003, "lift %.4f" % lift_e)
	off.save_jpg(out_dir.path_join("glow_off_%s.jpg" % tag), 0.88)
	dust.clock = func() -> float: return 1.0e6
	mat.set_shader_parameter(&"strength", 0.5)
	dust.set_process(false)
	await _snap("glow_shape_x6")
	dust.set_process(true)
	_freeze_motes()
	await process_frame


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


## Mean luminance of a 41 px square of `img` round window pixel `p`.
func _lum(img: Image, p: Vector2) -> float:
	var t := 0.0
	var n := 0
	for y in range(-20, 21, 4):
		for x in range(-20, 21, 4):
			var px := Vector2i(p) + Vector2i(x, y)
			if px.x >= 0 and px.y >= 0 and px.x < img.get_width() and px.y < img.get_height():
				t += img.get_pixelv(px).get_luminance()
				n += 1
	return t / maxf(1.0, float(n))


func _menu_checks() -> void:
	# Open with a real click on the icon button.
	await _click(gs.menu.menu_button.get_global_rect().get_center())
	await _wait(0.6)
	_check("menu opens from the icon button", gs.menu.game_menu.visible)
	_freeze_motes()
	await _snap("menu_open")
	var sb: SeriesScoreboard = gs.menu.scoreboard
	_check("series score shown in the menu", sb != null and sb.is_visible_in_tree() and gs.menu.game_menu.is_ancestor_of(sb))
	# A click on a menu item works (Settings opens).
	var setb: Control = gs.menu.items["settings"]
	await _click(setb.get_global_rect().get_center())
	await _wait(0.6)
	_check("a click on Settings opens the settings", gs.menu.settings_popup.visible and not gs.menu.game_menu.visible)
	gs.menu.close_settings()
	await _wait(0.6)
	# A click off the menu closes it.
	await _click(gs.menu.menu_button.get_global_rect().get_center())
	await _wait(0.6)
	_check("menu reopens", gs.menu.game_menu.visible)
	await _click(gs.get_global_transform() * Vector2(gs.board._ux - 260.0, gs.board._y0 + 360.0))
	await _wait(0.6)
	_check("a click off the menu closes it", not gs.menu.game_menu.visible)
	# A click on the menu panel's body (not a button) keeps it open.
	await _click(gs.menu.menu_button.get_global_rect().get_center())
	await _wait(0.6)
	var pr := gs.menu.game_menu.get_global_rect()
	await _click(Vector2(pr.position.x + 6.0, pr.get_center().y))
	await _wait(0.4)
	_check("a click on the menu panel keeps it open", gs.menu.game_menu.visible)
	gs.menu.close_menu()
	await _wait(0.5)


func _freeze_motes() -> void:
	for n in gs.find_children("*", "AmbientMotes", true, false):
		(n as AmbientMotes).clock = func() -> float: return 2.0
		(n as AmbientMotes).queue_redraw()


func _check(name: String, ok: bool, detail: String = "") -> void:
	if not ok:
		fails += 1
	print("%s  %s %s" % ["PASS" if ok else "FAIL", name, "" if ok else detail])


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


## Layout only: the online strip's Chat button and spectator badge, forced on in a local game (a
## render re-hides them, so this runs right before every shot and check).
func _force_chat() -> void:
	if not show_chat:
		return
	gs.chat.button.visible = true
	gs.spectate.badge.visible = true
	gs.spectate._badge_label.text = "2 watching"


func _snap(name: String) -> void:
	_force_chat()
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img.get_width() > 1600:
		img.resize(1600, int(img.get_height() * 1600.0 / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_jpg(out_dir.path_join("%s_%s.jpg" % [name, tag]), 0.88)
	print("shot ", name)


## Pushed input is in canvas coordinates (push_input's in_local_coords).
func _win(p: Vector2) -> Vector2:
	return p


func _move(pos: Vector2) -> void:
	var wp := _win(pos)
	var ev := InputEventMouseMotion.new()
	ev.position = wp
	ev.global_position = wp
	ev.relative = Vector2(4, 0)
	root.push_input(ev, true)


func _click(pos: Vector2) -> void:
	_move(pos)
	await process_frame
	await process_frame
	var wp := _win(pos)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = wp
		e.global_position = wp
		root.push_input(e, true)
		await process_frame
