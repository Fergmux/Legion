extends "res://src/dev/l_status_shots.gd"
## Development-only windowed evidence for M batch item 5 (owner feedback 2026-11-09): "When curse is
## applied to a unit with a buff the animation ordering is weird" -> "Curse first, then buffs fade."
## Applies Curse to a unit carrying buffs (and the mirror: Cleanse to a unit carrying debuffs) in a
## real match and records, frame by frame, the badges drawn on the card, the status names on screen
## and the scheduled looks and sounds. Launched through its boot script, NOT headless:
##   godot --path rldb -s res://src/dev/m5_status_order_boot.gd -- <absolute dir> [tag] --m5-shots
## `tag` (default "after") is appended to the sheet names. Writes JPG sheets (q88, at most 1600 px wide)
## and `m5_report.json`, then quits.

## Seconds after the broadcast at which each frame of a sequence is taken.
const FRAMES := [0.1, 0.35, 0.6, 0.8, 1.0, 1.2, 1.45, 1.7, 2.0, 2.6]
## Frames taken under reduced motion.
const FRAMES_RM := [0.05, 0.2, 0.35, 0.5, 0.65, 0.8, 1.0, 1.4]

## Suffix of every sheet name ("before" / "after").
var tag := "after"
var _report := {}


func _steps() -> void:
	await _move(Vector2(1300, 60))
	await _sequence("curse_on_buffs", uids["t1"], {"eternal": 1, "retain": 1}, "curse", FRAMES)
	await _sequence("cleanse_on_debuffs", uids["t1"], {"poison": 2, "burn": 1}, "cleanse", FRAMES)
	await _sequence("curse_x2_on_buff", uids["t1"], {"eternal": 1, "curse": 1}, "curse", FRAMES)
	var was := UIStyle.reduce_motion
	UIStyle.reduce_motion = true   # in memory only: the settings file is never written
	await _sequence("curse_on_buffs_reduced", uids["t1"], {"eternal": 1, "retain": 1}, "curse", FRAMES_RM)
	UIStyle.reduce_motion = was


## Gives `uid` exactly the statuses `start`, broadcasts, then applies one stack of `ward` and films it.
## A start that already holds the ward ("curse_x2") adds the stack on top (two stacks, one spent).
func _sequence(name: String, uid: int, start: Dictionary, ward: String, times: Array) -> void:
	await _settle()
	var st: Dictionary = m.cards[uid]["st"]
	st.clear()
	m.cards[uid]["runes"] = 0
	var pre_ward := int(start.get(ward, 0))
	for s in start:
		if s != ward:
			st[s] = int(start[s])
	host.broadcast()
	await _wait(0.3)
	await _settle()
	if pre_ward > 0:
		st[ward] = pre_ward   # quietly (no event): the card simply shows it after the next view
		host.broadcast()
		await _wait(0.3)
		await _settle()
	var since := int(m.log_entries[-1]["seq"])
	m.add_log("[dev] M5: %s is applied" % ward.capitalize())
	m.apply_status(uid, ward, 1)
	var events := []
	for row in MatchView.log_for(m, a, since):
		for f in row["fx"]:
			events.append({"k": f["k"], "s": f.get("s", "")})
	host.broadcast()
	var t0 := Time.get_ticks_msec()
	var tiles := []
	var frames := []
	for at in times:
		while Time.get_ticks_msec() - t0 < int(float(at) * 1000.0):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var r := _slot_rect(o, "unit", int(m.cards[uid]["slot"]))
		var badges := _badges(uid)
		var names := _names_on_screen()
		frames.append({"t": at, "badges": badges, "names": names})
		var cap := "%.2f s  [%s]  %s" % [at, ", ".join(badges), " / ".join(names)]
		tiles.append([_crop(img, r.grow_individual(r.size.x * 0.5, r.size.y * 0.42, r.size.x * 0.5, r.size.y * 0.22), 1.5), cap])
	var plan := []
	for p in gs.fx.last_plan:
		var tg := String(p["tag"])
		if tg.begins_with("status") or tg.begins_with("sfx:status") or tg.begins_with("badges"):
			plan.append({"t": snappedf(float(p["t"]), 0.001), "tag": tg})
	_report[name] = {"core_events": events, "plan": plan, "frames": frames, "final": m.cards[uid]["st"].duplicate()}
	print("M5 %s events %s" % [name, JSON.stringify(events)])
	print("M5 %s plan %s" % [name, JSON.stringify(plan)])
	for f in frames:
		print("M5 %s  %s" % [name, JSON.stringify(f)])
	await _show_sheet("m5-%s-%s" % [name, tag], tiles, 5)


## The statuses the card widget at `uid`'s slot currently draws (its view), "name n" each.
func _badges(uid: int) -> Array:
	var w := _w_slot(o, "unit", int(m.cards[uid]["slot"]))
	var out := []
	var sts: Dictionary = w.view.get("statuses", {})
	for s in sts:
		if int(sts[s]) > 0:
			out.append("%s %d" % [s, int(sts[s])])
	return out


## The status names (FxStatus labels) visible on screen, most opaque first.
func _names_on_screen() -> Array:
	var out := []
	for l in gs.fx_layer.find_children("*", "Label", true, false):
		var lab: Label = l
		if lab.is_visible_in_tree() and lab.modulate.a > 0.15:
			out.append("%s(%.1f)" % [lab.text, lab.modulate.a])
	return out


func _finish() -> void:
	var f := FileAccess.open(out_dir.path_join("m5_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "  "))
	f.close()
	print("M5 DRIVER DONE")
	get_tree().quit()
