extends SceneTree
## Boots the main scene and runs the M5 status-order evidence driver (src/dev/m5_status_order_shots.gd).
## Run NOT headless:
##   godot --path rldb -s res://src/dev/m5_status_order_boot.gd -- <absolute dir> [tag] --m5-shots
## The "--m5-shots" argument makes Main use the development save paths (as every *shots run).


func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	root.size = Vector2i(1600, 1000)
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = String(args[0]) if args.size() > 0 and not String(args[0]).begins_with("--") else "user://m5_shots"
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 5:
		await process_frame
	var driver: Node = load("res://src/dev/m5_status_order_shots.gd").new()
	if args.size() > 1 and not String(args[1]).begins_with("--"):
		driver.set("tag", String(args[1]))
	main.add_child(driver)
	driver.run(main, dir)
