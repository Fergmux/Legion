extends "res://src/dev/f02_driver.gd"
## Development-only windowed evidence for the M batch UI items (owner feedback 9 Nov 2026):
##   m3   the cursor sizes before and after (the baked images stamped on the menu at native pixels,
##        since window captures never contain the OS cursor),
##   m10  Options opening with no section chosen, and a section's Close staying in Options,
##   m12  each of the four tables in a match before and after the faint recede.
## Launched through its boot script, NOT headless:
##   godot --path legion -s res://src/dev/m_batch_ui_shots_boot.gd -- <absolute dir> <old cursor dir> --m-batch-shots
## <old cursor dir> holds the L22 cursor PNGs (normal_40.png, normal_80.png ...) for the "before"
## row; without it the m3 sheet shows only the new sizes. Writes JPGs (q88, at most 1600 px wide)
## and `m_batch_report.json`, then quits. Uses the TEST customisation file (automated run).

const SHOT_W := 1600
const JPG_Q := 0.88

## Folder of the pre-M-batch cursor images ("" = none).
var old_cursor_dir: String = ""


func run(main_node: Node, dir: String) -> void:
	main = main_node
	out_dir = dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	if not Sfx._loaded:
		Sfx.load_settings()
	Sfx._muted = true   # in memory only: the audio settings file is never written
	await _frames(10)
	await _menu_steps()
	await _cursor_sheet()
	await _table_steps()
	_finish_m()


# ---------------------------------------------------------------- m10: Options

func _menu() -> MainMenu:
	return main.menu as MainMenu


func _menu_steps() -> void:
	var mm := _menu()
	mm.pick("@options")
	await _wait(0.9)
	var active := mm._menu_list.get_children().filter(func(n): return n is MenuItem and (n as MenuItem).active)
	_check("m10 Options opens with no section chosen", active.is_empty() and mm._menu_leaf == "")
	_check("m10 Options centre is clear", mm._menu_center.get_child_count() == 0)
	await _jpg("m10-options-opened")
	mm.pick("settings")
	await _wait(0.9)
	await _jpg("m10-options-settings-chosen")
	mm.step_back()   # the section's Close / Esc
	await _wait(0.9)
	_check("m10 Close leaves the section and stays in Options", mm._menu_path == ["root", "options"] and mm._menu_leaf == "")
	await _jpg("m10-options-after-close")
	mm.step_back()
	await _wait(0.6)
	_check("m10 Esc again returns to the main menu", mm._menu_path == ["root"])


# ---------------------------------------------------------------- m3: cursor sizes

func _cursor_sheet() -> void:
	var panel := Rect2i(560, 250, 1000, 520)
	var rows := []
	if old_cursor_dir != "":
		rows.append(["BEFORE (L22): 32 px design window, 40 at 1080p, 48 at 1440p, 80 at 4K", [32, 40, 48, 80], old_cursor_dir])
	rows.append(["AFTER: 28 px at 100%, 36 at 125%, 42 at 150%, 56 at 200% display scaling (any window)", [28, 36, 42, 56], ""])
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.035, 0.03, 0.92)
	bg.position = Vector2(panel.position)
	bg.size = Vector2(panel.size)
	get_tree().root.add_child(bg)
	for i in rows.size():
		var l := UIStyle.label(String(rows[i][0]), 15, UIStyle.GOLD_HI)
		l.position = Vector2(36, 24 + i * 240)
		bg.add_child(l)
	await _wait(0.4)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	bg.queue_free()
	var y := panel.position.y + 70
	for r in rows:
		var x := panel.position.x + 40
		for n in r[1]:
			for key in ["normal", "pointer", "target_lock", "knife"]:
				var c := _cursor_image(String(key), int(n), String(r[2]))
				if c != null:
					img.blend_rect(c, Rect2i(0, 0, c.get_width(), c.get_height()), Vector2i(x, y))
				x += int(n) + 6
			x += 18
		y += 240
	img.save_jpg(out_dir.path_join("m3-cursor-sizes-before-after.jpg"), JPG_Q)
	_check("m3 live size at 100% is 28 px", CursorSkin.size_for_scale(CursorSkin.ui_scale(96)) == 28)
	_check("m3 live size at 150% is 42 px", CursorSkin.size_for_scale(CursorSkin.ui_scale(144)) == 42)


func _cursor_image(key: String, n: int, dir: String) -> Image:
	if dir == "":
		var t := CursorSkin.texture(StringName(key), n)
		if t == null:
			return null
		var im := t.get_image()
		im.decompress()
		im.convert(Image.FORMAT_RGBA8)
		return im
	var path := dir.path_join("%s_%d.png" % [key, n])
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGBA8)
	return img


# ---------------------------------------------------------------- m12: tables

func _table_steps() -> void:
	main._privacy = false
	main._start_local({"seed": 4242, "best_of": 3, "deck_mode": "starter", "names": ["Ana", "Ben"]})
	await _frames(8)
	host = main.local_host
	host.handle(0, {"t": "pick_starter", "index": 1})
	host.handle(1, {"t": "pick_starter", "index": 3})
	await _frames(4)
	m = host.series.game
	gs = main.screen
	_stage()
	host.broadcast()
	_view_seat(a)
	await _wait(4.2)   # past the coin flip and the deal
	for t in Customisation.TABLES:
		var id := String(t["id"])
		Customisation.set_table(id)
		_swap_table(false)
		await _wait(0.3)
		await _jpg("m12-table-%s-before" % id)
		_swap_table(true)
		await _wait(0.3)
		var tb: Control = gs.board.table
		_check("m12 %s has the recede veil in the match" % id, tb.get_node_or_null("Recede") != null)
		await _jpg("m12-table-%s-after" % id)
	Customisation.set_table(Customisation.DEFAULT_TABLE)


## Rebuilds the board's table from the chosen table in place (a table is otherwise fixed for a
## game); `recede` false strips the M batch layer to show the "before".
func _swap_table(recede: bool) -> void:
	var old: Control = gs.board.table
	var nt := UIStyle.table_background()
	if not recede:
		var r := nt.get_node_or_null("Recede")
		if r != null:
			nt.remove_child(r)
			r.free()
		(nt.get_child(0) as TextureRect).material = null
	nt.set_anchors_preset(Control.PRESET_TOP_LEFT)
	nt.clip_contents = true
	nt.position = old.position
	nt.size = old.size
	var parent := old.get_parent()
	parent.add_child(nt)
	parent.move_child(nt, old.get_index())
	var dust: Node = gs.board.dust
	if dust != null and dust.get_parent() == old:
		old.remove_child(dust)
		nt.add_child(dust)
	gs.board.table = nt
	parent.remove_child(old)
	old.queue_free()


# ---------------------------------------------------------------- output

func _jpg(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.get_width() > SHOT_W:
		img.resize(SHOT_W, int(img.get_height() * float(SHOT_W) / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_jpg(out_dir.path_join(name + ".jpg"), JPG_Q)


func _finish_m() -> void:
	var fails := checks.filter(func(c): return not c["ok"])
	var f := FileAccess.open(out_dir.path_join("m_batch_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "passed": checks.size() - fails.size(), "failed": fails.size()}, "  "))
	f.close()
	print("M BATCH UI SHOTS DONE: %d passed, %d failed" % [checks.size() - fails.size(), fails.size()])
	get_tree().quit()
