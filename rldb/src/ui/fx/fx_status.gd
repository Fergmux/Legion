class_name FxStatus
extends FxPart
## L8 (owner feedback 2026-11-05): "each status application should have a cool animated effect and
## sound effect that clearly shows what has happened, as well as the text."
##
## Every status event on a board card plays three layers together:
##   1. its own animated look (FxStatusArt: goo for Poison, a flame flare for Burn, arcs for Paralyse...),
##   2. the status badge stamped onto the card (it pops at the centre, then shrinks into the card's
##      status row, so the player sees the badge that now sits there), with a glow in its colour,
##   3. the name in its accent colour ("Poison", "Burn ×2").
## The sound is scheduled by FxPlayer with the event (Sfx "status_<name>", "status_blocked",
## "poison_tick" / "burn_tick", "status_expire").
##
## Events: "status" (applied), "status_blocked" (a Cleanse / Curse stack stopped it: a ward flash),
## "status_tick" (Poison / Burn / Medic paying out), "status_expire" (it wore off).
##
## Several statuses landing on one card in one batch are staggered by FxPlayer (STAGGER) and a new look
## fades the one still playing on that card, so they never pile into mush. Under reduce_motion each is a
## short tinted flash with the badge shown in place and the name, no particles or travel.
##
## L4: the first HOLD_K of each look runs on FxPlayer.new_tween() (it holds the next view back), the
## rest on tail_tween() (its fade never does).

## Seconds of each look.
const LENGTH := 0.95
const TICK_LENGTH := 0.7
const BLOCKED_LENGTH := 1.0
const EXPIRE_LENGTH := 0.6
## Reduce-motion flash length.
const FLASH_LENGTH := 0.45
## Seconds between two statuses landing on the same card in one batch (FxPlayer schedules them).
const STAGGER := 0.42
## Fraction of a look that holds the queue of waiting views (L4); the rest is a tail.
const HOLD_K := 0.65
## Seconds after its start when an application look is at its fullest (evidence driver).
const PEAK_AT := 0.36
## The badge stamp: radius as a fraction of the card width, and its timeline (fractions of LENGTH).
const STAMP_K := 0.27
## Height of the stamp's centre on the card (fraction of its height): high on the art, so each look's
## centre motif (the padlock, the eye, the cross, the sigil) stays in view.
const STAMP_Y := 0.21
const STAMP_IN := 0.16
const STAMP_FLY := 0.38
const STAMP_END := 0.62
## M5: the same under reduce motion (a short beat; long enough that each name is read on its own).
const STAGGER_FLASH := 0.25
## M5 (owner, 2026-11-09: "Curse first, then buffs fade"): seconds from a status's application to the
## first status it clears on that card (Curse clearing Buffs, Cleanse clearing Debuffs). The cleared
## ones wait until the applied badge has landed in the card's status row (STAMP_END of its look).
const CLEAR_LEAD := LENGTH * STAMP_END + 0.12
## M5: the same under reduce motion (its badge is shown in place at once).
const CLEAR_LEAD_FLASH := 0.3
## Floating name: font size (base px) and rise (px).
const NAME_FS := 17
const NAME_RISE := 14.0
## Final review (2026-11-05): the name rises inside its own card, under the badge stamp, instead of
## above the card, where it covered the stats of the card in the row above for a second. Its centre
## starts at NAME_Y of the card's height; it shrinks to fit NAME_MAX_W of the card's width.
const NAME_Y := 0.74
const NAME_MAX_W := 1.3
## M5: seconds a name takes to clear when the next one on its card appears.
const NAME_CLEAR := 0.07
## Ward colours: Cleanse white-gold, Curse violet.
const WARD_CLEANSE := Color("ffe9a8")
const WARD_CURSE := Color("b98aff")

## The sound of status event `e` (FxPlayer schedules it with the look): "status_<name>" when applied,
## "status_blocked", "poison_tick" / "burn_tick" (Medic paying out: "status_medic"), "status_expire".
static func sound_for(e: Dictionary) -> String:
	var s := String(e.get("s", ""))
	match String(e.get("k", "")):
		"status":
			return "status_" + s if s != "" else ""
		"status_blocked":
			return "status_blocked"
		"status_tick":
			return s + "_tick" if s in ["poison", "burn"] else "status_" + s
		"status_expire":
			return "status_expire"
	return ""


## M5: seconds FxPlayer waits after status event `e` before the next status event on the same card,
## `next_k` the kind of that next event ("" when none). An application followed by an expiry (a Curse
## clearing Buffs, a Cleanse clearing Debuffs) waits for its badge to land (CLEAR_LEAD); everything
## else is staggered by STAGGER. `fast`: reduce motion.
static func gap_after(e: Dictionary, next_k: String, fast: bool) -> float:
	if String(e.get("k", "")) == "status" and next_k == "status_expire":
		return CLEAR_LEAD_FLASH if fast else CLEAR_LEAD
	return STAGGER_FLASH if fast else STAGGER


## M5: seconds after status event `e` starts when the card's own status row changes for it: an applied
## badge joins the row when its stamp lands there (at once under reduce motion, `fast`); an expiring
## one leaves the row as its fade starts; a ward spending a stack drops it at once.
static func badge_delay(e: Dictionary, fast: bool) -> float:
	if String(e.get("k", "")) == "status" and not fast:
		return LENGTH * STAMP_END
	return 0.0


## M5: card view `v` with status event `e` applied to its status row (a new Dictionary; `v` is not
## changed): "status" adds its stacks (Runes count apart), "status_expire" removes the status,
## "status_blocked" that consumed a ward stack ("used") takes one from the ward, except its last one:
## that badge stays until the ward's own "status_expire" (the rules always send one), so it fades
## instead of vanishing. Ticks change nothing.
static func step_view(v: Dictionary, e: Dictionary) -> Dictionary:
	var nv := v.duplicate()
	var st: Dictionary = (v.get("statuses", {}) as Dictionary).duplicate()
	var s := String(e.get("s", ""))
	match String(e.get("k", "")):
		"status":
			if s == "rune":
				nv["runes"] = int(v.get("runes", 0)) + int(e.get("n", 1))
			else:
				st[s] = int(st.get(s, 0)) + int(e.get("n", 1))
		"status_expire":
			st.erase(s)
		"status_blocked":
			var by := String(e.get("by", ""))
			if bool(e.get("used", true)) and int(st.get(by, 0)) > 1:
				st[by] = int(st[by]) - 1
	nv["statuses"] = st
	return nv


## M5: card view `final` as it was before the status events `evs` (in order) played on it, rebuilt
## backwards (used when the previous view of the card is not known). A status that expired had at
## least one stack; an application's stacks are taken off again; a spent ward stack is put back
## (once: a block that spent the ward's last stack is followed by that ward's expiry).
static func view_before(final: Dictionary, evs: Array) -> Dictionary:
	var v := final.duplicate()
	var st: Dictionary = (final.get("statuses", {}) as Dictionary).duplicate()
	var runes := int(final.get("runes", 0))
	var expiring := {}   # statuses whose expiry is still ahead: the stack a block spent is that one
	for i in range(evs.size() - 1, -1, -1):
		var e: Dictionary = evs[i]
		var s := String(e.get("s", ""))
		match String(e.get("k", "")):
			"status":
				if s == "rune":
					runes = maxi(0, runes - int(e.get("n", 1)))
				else:
					st[s] = int(st.get(s, 0)) - int(e.get("n", 1))
					if int(st[s]) <= 0:
						st.erase(s)
			"status_expire":
				st[s] = maxi(int(st.get(s, 0)), 1)
				expiring[s] = true
			"status_blocked":
				var by := String(e.get("by", ""))
				if bool(e.get("used", true)) and by != "":
					if expiring.has(by):
						expiring.erase(by)   # its last stack: the expiry above already put it back
					else:
						st[by] = int(st.get(by, 0)) + 1
	v["statuses"] = st
	v["runes"] = runes
	return v


## The looks playing per card slot ("p:zone:slot" -> [nodes]); a new look fades the old one.
var _live := {}
## The name label rising over each card slot; a new one sends the old one up and out at once.
var _names := {}
## M5: the status rows held for the batch now playing, by card slot key: {"w": WeakRef to the card
## widget, "final": its real view, "shown": the view it draws now, "left": status events still to play}.
var _held := {}


## M5 (owner, 2026-11-09): the board is drawn in its final state before the batch plays, so a Curse
## clearing Buffs (or a Cleanse clearing Debuffs) took every badge off the card at once, before any
## fade, and a Curse spent doing so never showed its badge at all. For every card with status events
## in `events`, its widget draws its status row as it was before the batch (from `prev_mv`, the view
## before this update, when it shows the same card; else rebuilt with view_before) and FxPlayer moves
## it on one event at a time (badge_step). The last step, or a skip (finish_all), restores the real
## view. A card that changed in its slot during the batch is left to the board.
func hold_badges(events: Array, prev_mv: Dictionary) -> void:
	_held = {}
	if _fx.screen == null:
		return
	var per_slot := {}
	for e in events:
		if not (String(e.get("k", "")) in FxPlayer.STATUS_FX):
			continue
		var at: Dictionary = e.get("at", {})
		if at.is_empty():
			continue
		var key := _slot_key(at)
		if not per_slot.has(key):
			per_slot[key] = {"at": at, "evs": []}
		per_slot[key]["evs"].append(e)
	for key in per_slot:
		var at: Dictionary = per_slot[key]["at"]
		var it: Dictionary = _fx.screen.fx_slot_item(int(at.get("p", 0)), String(at.get("zone", "unit")), int(at.get("slot", 0)))
		if it.is_empty() or not (it.get("widget") is CardWidget):
			continue
		var w: CardWidget = it["widget"]
		var final: Dictionary = w.view
		if final.is_empty() or final.get("hidden", false) or not final.has("statuses"):
			continue
		var evs: Array = per_slot[key]["evs"]
		var start := view_before(final, evs)
		var pv := _prev_card(prev_mv, at)
		if pv.has("uid") and pv.get("uid") == final.get("uid"):
			start = final.duplicate()
			start["statuses"] = (pv.get("statuses", {}) as Dictionary).duplicate()
			start["runes"] = int(pv.get("runes", 0))
		elif pv.has("uid"):
			continue   # another card stood in this slot before the batch
		var entry := {"w": weakref(w), "final": final, "shown": start, "left": evs.size()}
		_held[key] = entry
		w.view = start
		w.request_face()
		_fx.add_cleanup_on(w, func(cw: CardWidget) -> void:
			if is_same(cw.view, entry["shown"]):
				cw.view = entry["final"]
				cw.request_face())


## M5: the step of the held status row for status event `e` (FxPlayer schedules it badge_delay after
## the event's look starts), or an empty Callable when that card's row is not held.
func badge_step(e: Dictionary) -> Callable:
	var at: Dictionary = e.get("at", {})
	if at.is_empty() or not _held.has(_slot_key(at)):
		return Callable()
	return _badge_step.bind(_held[_slot_key(at)], e)


func _badge_step(entry: Dictionary, e: Dictionary) -> void:
	var w = (entry["w"] as WeakRef).get_ref()
	if w == null or not is_same((w as CardWidget).view, entry["shown"]):
		return   # the card was set up again (a newer view) or the batch was skipped
	entry["left"] = int(entry["left"]) - 1
	var nv: Dictionary = entry["final"] if int(entry["left"]) <= 0 else step_view(entry["shown"], e)
	entry["shown"] = nv
	(w as CardWidget).view = nv
	(w as CardWidget).request_face()


## The card view at `at` in the previous view `prev_mv`, or {}.
static func _prev_card(prev_mv: Dictionary, at: Dictionary) -> Dictionary:
	if prev_mv.is_empty() or not prev_mv.has("players"):
		return {}
	var pls: Array = prev_mv["players"]
	var p := int(at.get("p", 0))
	if p < 0 or p >= pls.size():
		return {}
	var arr: Variant = (pls[p] as Dictionary).get(Zones.KEY.get(String(at.get("zone", "unit")), "units"), [])
	var slot := int(at.get("slot", -1))
	if not (arr is Array) or slot < 0 or slot >= (arr as Array).size() or not (arr[slot] is Dictionary):
		return {}
	return arr[slot]


## A status was applied: `at` {p, zone, slot}, `s` the status, `n` the stacks added.
func apply(at: Dictionary, s: String, n: int) -> void:
	var rect := _rect(at)
	if rect.size == Vector2.ZERO:
		return
	var col := CardStatusIcons.accent(s)
	var label := s.capitalize() + (" ×%d" % n if n > 1 else "")
	_glow(at, col, 0.95)
	_name(at, rect, label, col, NAME_FS, 1.0)
	if UIStyle.reduce_motion:
		_still_badge(rect, s, n)
		return
	_look(at, rect, s, "apply", "", LENGTH)
	_stamp(rect, s, n, LENGTH)


## Poison / Burn / Medic paid out `n` from the card at `at`: a smaller, quicker look and a badge pulse.
func tick(at: Dictionary, s: String, n: int) -> void:
	var rect := _rect(at)
	if rect.size == Vector2.ZERO:
		return
	var col := CardStatusIcons.accent(s)
	_glow(at, col, 0.8)
	if UIStyle.reduce_motion:
		_still_badge(rect, s, n)
		return
	_look(at, rect, s, "tick", "", TICK_LENGTH)
	_pulse(rect, s, TICK_LENGTH)


## A Cleanse (`by` "cleanse") or Curse ("curse") stack stopped `s` on the card at `at`: a ward dome
## flashes and the stopped badge bounces off it, with "<Status> blocked" in the ward's colour.
func blocked(at: Dictionary, s: String, by: String) -> void:
	var rect := _rect(at)
	if rect.size == Vector2.ZERO:
		return
	var wc := WARD_CLEANSE if by == "cleanse" else WARD_CURSE
	_glow(at, wc, 0.95)
	_name(at, rect, "%s blocked" % s.capitalize(), wc, NAME_FS - 1, 1.1)
	if UIStyle.reduce_motion:
		_still_badge(rect, by, 1)
		return
	_look(at, rect, s, "blocked", by, BLOCKED_LENGTH)
	_bounce(rect, s, BLOCKED_LENGTH)


## Status `s` wore off the card at `at`: a ring and motes in its colour, the badge fading up.
func expire(at: Dictionary, s: String) -> void:
	var rect := _rect(at)
	if rect.size == Vector2.ZERO:
		return
	var col := CardStatusIcons.accent(s)
	_name(at, rect, "%s fades" % s.capitalize(), Color(col, 0.9), NAME_FS - 3, 0.8)
	if UIStyle.reduce_motion:
		return
	_look(at, rect, s, "expire", "", EXPIRE_LENGTH)
	var badge := _fade_up(rect, s, EXPIRE_LENGTH)
	# M5: the next look on this card (the next cleared status) clears this badge first, so two fading
	# badges never sit on top of each other.
	(_live.get(_slot_key(at), []) as Array).append(badge)


# ---------------------------------------------------------------- pieces

static func _slot_key(at: Dictionary) -> String:
	return "%d:%s:%d" % [int(at.get("p", 0)), String(at.get("zone", "")), int(at.get("slot", 0))]


## The status name in its colour, rising over the lower part of its own card (under the badge stamp,
## clear of the neighbouring cards). A name still showing on that card is cleared first (M5: a quick
## fade of its own, gone before the new name has finished popping in), so two never overlap.
func _name(at: Dictionary, rect: Rect2, text: String, col: Color, fs: int, life: float) -> void:
	var key := _slot_key(at)
	# QA final: untyped, because a skip (FxPlayer.finish_all) frees the label it remembers, and assigning
	# a freed instance to a typed variable is a script error that stopped every later name on the card.
	var old = _names.get(key, null)
	if old != null and is_instance_valid(old):
		# M5 (owner, 2026-11-09): the old name used to lift away over 0.14 s while its own fade tween
		# fought that one, so two names read on top of each other for a moment. It now fades on
		# self_modulate (no other tween touches it) in NAME_CLEAR, or goes at once under reduce motion.
		if UIStyle.reduce_motion:
			_fx.free_node(old)
		else:
			var ot := _fx.tail_tween()
			ot.tween_property(old, "self_modulate:a", 0.0, UIStyle.dur(NAME_CLEAR))
			ot.tween_callback(_fx.free_node.bind(old))
	var l := Label.new()
	l.text = text
	var font := UIStyle.font_display(700)
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var max_w := (_fx.fx_pos(rect.end).x - _fx.fx_pos(rect.position).x) * NAME_MAX_W
	if sz.x > max_w and sz.x > 0.0:
		fs = maxi(10, floori(fs * max_w / sz.x))
		l.add_theme_font_size_override("font_size", fs)
		sz = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	l.size = Vector2(sz.x + 8, fs * 1.4)
	l.pivot_offset = l.size / 2.0
	var p0 := name_origin(_fx.fx_pos(rect.position), _fx.fx_pos(rect.end), l.size)
	l.position = p0
	_fx.add_text(l)
	_names[key] = l
	var tw := _fx.tail_tween()
	if UIStyle.reduce_motion:
		tw.tween_interval(life * 0.7)
		tw.tween_property(l, "modulate:a", 0.0, life * 0.3)
	else:
		l.scale = Vector2(1.35, 1.35)
		tw.set_parallel(true)
		tw.tween_property(l, "scale", Vector2.ONE, UIStyle.dur(0.12)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "position:y", p0.y - NAME_RISE, UIStyle.dur(life)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "modulate:a", 0.0, UIStyle.dur(0.25)).set_delay(UIStyle.dur(life - 0.25))
	tw.chain().tween_callback(func() -> void:
		if _names.get(key, null) == l:
			_names.erase(key)
		_fx.free_node(l))


## Top-left of a floating name of `label_size` over the card box from `a` to `b` (fx-layer
## coordinates): centred across the card, its middle at NAME_Y of the card's height.
static func name_origin(a: Vector2, b: Vector2, label_size: Vector2) -> Vector2:
	var c := Vector2((a.x + b.x) / 2.0, a.y + (b.y - a.y) * NAME_Y)
	return c - label_size / 2.0


func _rect(at: Dictionary) -> Rect2:
	if at.is_empty() or _fx.screen == null:
		return Rect2()
	return _fx.screen.fx_slot_global_rect(int(at.get("p", 0)), String(at.get("zone", "unit")), int(at.get("slot", 0)))


## The card's own glow, pulsing in `col` once.
func _glow(at: Dictionary, col: Color, peak: float) -> void:
	var it: Dictionary = _fx.screen.fx_slot_item(int(at.get("p", 0)), String(at.get("zone", "unit")), int(at.get("slot", 0)))
	if it.is_empty():
		return
	var w: CardWidget = it["widget"]
	w.fx_glow = Color(col, peak)
	_fx.add_cleanup_on(w, func(cw: CardWidget) -> void: cw.fx_glow = FxCardEffects.NO_GLOW)
	var tw := _fx.new_tween()
	var d := FLASH_LENGTH if UIStyle.reduce_motion else 0.55
	tw.tween_property(w, "fx_glow", Color(col, 0.0), UIStyle.dur(d)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## The two FxStatusArt passes over the card, `t` tweened over `length` (HOLD_K of it holding the queue).
func _look(at: Dictionary, rect: Rect2, s: String, mode: String, ward: String, length: float) -> void:
	var slot_key := _slot_key(at)
	_fade_live(slot_key)
	var seed_value := hash([slot_key, s, mode, Time.get_ticks_msec()])
	var nodes: Array = []
	for g in [false, true]:
		var art := FxStatusArt.new()
		art.glow = g
		art.key = s
		art.mode = mode
		art.ward = ward
		art.seed_value = seed_value
		if g:
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			art.material = mat
		_place(art, rect)
		art.z_as_relative = false
		art.z_index = UiLayers.FX
		_fx.add_node(art)
		nodes.append(art)
	_live[slot_key] = nodes
	var main := _fx.new_tween().set_parallel(true)
	for art in nodes:
		main.tween_property(art, "t", HOLD_K, UIStyle.dur(length * HOLD_K))
	main.chain().tween_callback(func() -> void:
		# M5: only the art passes (an expiring badge may share the list; it runs its own fade).
		var live: Array = nodes.filter(func(n): return is_instance_valid(n) and n is FxStatusArt)
		if live.is_empty():
			return
		var tail := _fx.tail_tween().set_parallel(true)
		for art in live:
			tail.tween_property(art, "t", 1.0, UIStyle.dur(length * (1.0 - HOLD_K)))
		tail.chain().tween_callback(func() -> void:
			for art in live:
				_fx.free_node(art)
			if _live.get(slot_key, []) == nodes:
				_live.erase(slot_key)))


## Fades out the look still playing on a card (a new one starts there).
func _fade_live(slot_key: String) -> void:
	var old: Array = _live.get(slot_key, [])
	_live.erase(slot_key)
	var alive := old.filter(func(n): return is_instance_valid(n))
	if alive.is_empty():
		return
	var tw := _fx.tail_tween().set_parallel(true)
	for n in alive:
		# M5: self_modulate, so it never fights the node's own fade (an expiring badge tweens modulate).
		tw.tween_property(n, "self_modulate:a", 0.0, UIStyle.dur(0.14))


## Positions `c` over the card box `rect` (global) in fx-layer coordinates.
func _place(c: Control, rect: Rect2) -> void:
	var a := _fx.fx_pos(rect.position)
	var b := _fx.fx_pos(rect.end)
	c.position = a
	c.size = b - a


## The badge stamp: pops at the card's centre, holds, then shrinks into the status row and fades.
func _stamp(rect: Rect2, s: String, n: int, length: float) -> void:
	var st := _badge_node(rect, s, n)
	# The status row sits over the art's lower edge, just above the name banner.
	var to := _fx.fx_pos(Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.52)) - st.size / 2.0
	st.scale = Vector2(0.2, 0.2)
	st.modulate.a = 0.0
	var tw := _fx.new_tween()
	tw.set_parallel(true)
	tw.tween_property(st, "modulate:a", 1.0, UIStyle.dur(length * STAMP_IN * 0.6))
	tw.tween_property(st, "scale", Vector2.ONE, UIStyle.dur(length * STAMP_IN)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(UIStyle.dur(length * (STAMP_FLY - STAMP_IN)))
	tw.chain().tween_property(st, "position", to, UIStyle.dur(length * (STAMP_END - STAMP_FLY))).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(st, "scale", Vector2(0.42, 0.42), UIStyle.dur(length * (STAMP_END - STAMP_FLY))).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(st, "modulate:a", 0.0, UIStyle.dur(length * 0.12)).set_delay(UIStyle.dur(length * (STAMP_END - STAMP_FLY - 0.12)))
	tw.chain().tween_callback(_fx.free_node.bind(st))


## A quick badge pulse at the centre (ticks).
func _pulse(rect: Rect2, s: String, length: float) -> void:
	var st := _badge_node(rect, s, 1, 0.22)
	st.scale = Vector2(0.6, 0.6)
	st.modulate.a = 0.0
	var tw := _fx.new_tween()
	tw.set_parallel(true)
	tw.tween_property(st, "modulate:a", 1.0, UIStyle.dur(length * 0.12))
	tw.tween_property(st, "scale", Vector2(1.15, 1.15), UIStyle.dur(length * 0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(st, "modulate:a", 0.0, UIStyle.dur(length * 0.35))
	tw.chain().tween_callback(_fx.free_node.bind(st))


## The stopped badge drops onto the ward, strikes it and spins off, fading.
func _bounce(rect: Rect2, s: String, length: float) -> void:
	var st := _badge_node(rect, s, 1, 0.26)
	var rest: Vector2 = st.position
	var r := rect.size.x * 0.62
	var hit := rest + Vector2(0, -r * 0.62)
	st.position = rest + Vector2(0, -rect.size.y * 0.75)
	st.modulate.a = 0.0
	var tw := _fx.new_tween()
	tw.set_parallel(true)
	tw.tween_property(st, "modulate:a", 1.0, UIStyle.dur(length * 0.08))
	tw.tween_property(st, "position", hit, UIStyle.dur(length * 0.24)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_property(st, "position", hit + Vector2(rect.size.x * 0.55, -rect.size.y * 0.35), UIStyle.dur(length * 0.4)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(st, "rotation", 2.4, UIStyle.dur(length * 0.4))
	tw.parallel().tween_property(st, "scale", Vector2(0.55, 0.55), UIStyle.dur(length * 0.4))
	tw.parallel().tween_property(st, "modulate:a", 0.0, UIStyle.dur(length * 0.3)).set_delay(UIStyle.dur(length * 0.12))
	tw.chain().tween_callback(_fx.free_node.bind(st))


## The badge fades up and away (expire); returns its node.
func _fade_up(rect: Rect2, s: String, length: float) -> Control:
	var st := _badge_node(rect, s, 1, 0.2)
	var tw := _fx.new_tween()
	tw.set_parallel(true)
	tw.tween_property(st, "position:y", st.position.y - rect.size.y * 0.25, UIStyle.dur(length)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(st, "modulate:a", 0.0, UIStyle.dur(length)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(_fx.free_node.bind(st))
	return st


## Reduce motion: the badge shown in place at the centre, fading out.
func _still_badge(rect: Rect2, s: String, n: int) -> void:
	var st := _badge_node(rect, s, n)
	var tw := _fx.new_tween()
	tw.tween_interval(UIStyle.dur(FLASH_LENGTH * 0.5))
	tw.tween_property(st, "modulate:a", 0.0, UIStyle.dur(FLASH_LENGTH * 0.5))
	tw.tween_callback(_fx.free_node.bind(st))


## A badge Control centred on the card (radius `k` x card width), above the looks.
func _badge_node(rect: Rect2, s: String, n: int, k: float = STAMP_K) -> Control:
	var a := _fx.fx_pos(rect.position)
	var b := _fx.fx_pos(rect.end)
	var r := (b.x - a.x) * k
	var st := Stamp.new()
	st.key = s
	st.n = n
	st.size = Vector2(r, r) * 2.0
	st.pivot_offset = st.size / 2.0
	st.position = _fx.fx_pos(Vector2(rect.get_center().x, rect.position.y + rect.size.y * STAMP_Y)) - st.size / 2.0
	st.z_as_relative = false
	st.z_index = UiLayers.FX + 1
	_fx.add_node(st)
	return st


## The status badge as a node (CardStatusIcons.draw_token), with its stack count above 1.
class Stamp extends Control:
	var key := ""
	var n := 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0
		draw_texture_rect(FxStatusArt.soft_texture(), Rect2(Vector2.ZERO - Vector2(r, r) * 0.5, size + Vector2(r, r)), false, Color(CardStatusIcons.accent(key), 0.55))
		CardStatusIcons.draw_token(self, size / 2.0, r, key, n, CardStatusIcons.kind_of(key), n > 1)
