extends SceneTree
## Boots the main scene and runs the M batch UI evidence driver (src/dev/m_batch_ui_shots.gd) in it,
## without a command-line hook in main.gd. Run NOT headless:
##   godot --path legion -s res://src/dev/m_batch_ui_shots_boot.gd -- <absolute dir> [<old cursor dir>] --m-batch-shots
## The "--m-batch-shots" argument makes Main use the development save paths (as every *shots run).


func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	root.size = Vector2i(1600, 1000)
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var plain := Array(args).filter(func(s): return not String(s).begins_with("--"))
	var dir: String = String(plain[0]) if plain.size() > 0 else "user://m_batch_ui_shots"
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 5:
		await process_frame
	var driver: Node = load("res://src/dev/m_batch_ui_shots.gd").new()
	if plain.size() > 1:
		driver.set("old_cursor_dir", String(plain[1]))
	main.add_child(driver)
	driver.run(main, dir)
