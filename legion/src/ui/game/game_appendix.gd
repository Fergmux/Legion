class_name GameAppendix
extends RefCounted
## P batch B6 (owner, 18 Nov): the in-match appendix, a rules reference opened from an icon button
## (a drawn open book, BookGlyph) in the top strip beside Chat and Menu. Its popover shows the game's
## reference content graphically, from the rules data: the Type advantage cycle (Type icons and
## arrows, CardDB.TYPE_ADVANTAGE) and every status with its badge, its name in its own colour and
## its effect (CardDB.STATUS_HELP), grouped as Buffs, Debuffs and Runes. Read-only: it never sends
## anything. Esc, the close button or the button again closes it.

## Popover size (px), as the chat box.
const W := 430.0
const H := 560.0
## Side of the status badges and Type icons in the list.
const ICON := 26.0
const TYPE_ICON := 22.0

## The host screen this component works on.
var gs: GameScreen
## The icon button in the top strip.
var button: Button
## The popover (hidden until opened).
var panel: HousePanel
## Its round close button.
var close_button: RoundCloseButton
## The list's scroll area.
var scroll: ScrollContainer


func _init(screen: GameScreen) -> void:
	gs = screen


## Builds the icon button (into the top strip `row`, just before `before`) and the hidden popover.
func build(row: HBoxContainer, before: Control) -> void:
	button = UIStyle.secondary_button("", 15)
	button.name = "AppendixButton"
	button.custom_minimum_size = GameMenu.MENU_BUTTON
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = "Appendix"
	button.pressed.connect(toggle)
	var glyph := BookGlyph.new()
	glyph.name = "BookGlyph"
	button.add_child(glyph)
	button.mouse_entered.connect(glyph.queue_redraw)
	button.mouse_exited.connect(glyph.queue_redraw)
	row.add_child(button)
	row.move_child(button, before.get_index())
	panel = HousePanel.new("Appendix", "", Vector2(UIStyle.sp("lg"), UIStyle.sp("lg")), UIStyle.sp("sm"))
	panel.name = "AppendixPanel"
	panel.visible = false
	panel.z_index = UiLayers.GAME_MENU
	panel.custom_minimum_size = Vector2(W, H)
	gs.add_child(panel)
	close_button = GameChat.add_close(panel, close_box)
	scroll = ScrollContainer.new()
	scroll.name = "AppendixScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.theme = Ornate.scroll_theme()
	panel.body.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "AppendixList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", UIStyle.sp("sm"))
	scroll.add_child(list)
	_build_content(list)


## The reference content: the Type cycle, then the statuses by kind.
func _build_content(list: VBoxContainer) -> void:
	list.add_child(_heading("Type advantage"))
	var grid := GridContainer.new()
	grid.name = "TypeCycle"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UIStyle.sp("lg"))
	grid.add_theme_constant_override("v_separation", 6)
	for t in CardDB.ELEMENTS:
		var beats := String(CardDB.TYPE_ADVANTAGE.get(t, ""))
		if beats != "":
			grid.add_child(type_pair(String(t), beats))
	list.add_child(grid)
	list.add_child(_heading("Buffs"))
	for k in CardDB.BUFFS:
		list.add_child(status_row(String(k)))
	list.add_child(_heading("Debuffs"))
	for k in CardDB.DEBUFFS:
		list.add_child(status_row(String(k)))
	list.add_child(_heading("Runes"))
	list.add_child(status_row("rune"))


## One link of the Type cycle: `a`'s icon and name, an arrow, `b`'s icon and name (a beats b).
static func type_pair(a: String, b: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.name = "Beats_%s_%s" % [a, b]
	hb.add_theme_constant_override("separation", 5)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for t in [a, b]:
		if t == b:
			var arrow := UIStyle.label("→", 16, UIStyle.GOLD)
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hb.add_child(arrow)
		hb.add_child(TypeIcons.TypeBadge.new(t, TYPE_ICON))
		var l := UIStyle.label(t, 14, UIStyle.type_color(t).lightened(0.2))
		l.add_theme_font_override("font", UIStyle.font_bold())
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(l)
	return hb


## One status: its badge, its name in its accent colour and its effect underneath.
static func status_row(key: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.name = "Status_%s" % key
	hb.set_meta(&"status", key)
	hb.add_theme_constant_override("separation", UIStyle.sp("sm"))
	var tok := CardStatusIcons.Token.new(key, CardStatusIcons.kind_of(key), ICON)
	tok.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(tok)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(col)
	var nm := UIStyle.label(key.capitalize(), 15, CardStatusIcons.accent(key))
	nm.add_theme_font_override("font", UIStyle.font_bold())
	col.add_child(nm)
	var body := UIStyle.label(CardDetailsPanel._strip_status_prefix(StatusHelp.describe(key)), 14, UIStyle.TEXT, true)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size.x = 40.0
	col.add_child(body)
	return hb


func _heading(text: String) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var l := UIStyle.label(text.to_upper(), 12, UIStyle.GOLD, false, true)
	hb.add_child(l)
	var line := HSeparator.new()
	var sl := StyleBoxLine.new()
	sl.color = Color(UIStyle.BRONZE, 0.9)
	sl.thickness = 1
	line.add_theme_stylebox_override("separator", sl)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(line)
	return hb


## Places the popover under the top-right button row, right edge level with the row's end (as Chat).
func layout(w: float) -> void:
	if panel == null:
		return
	panel.size = Vector2(W, H)
	var right: float = gs.menu.menu_anchor_right() if gs.menu != null and gs.board != null else w - gs.sidebar_w - 10.0
	panel.position = Vector2(roundf(maxf(float(UIStyle.SAFE_HUD), right - W)), GameMenu.popup_top())


## True while the popover is open (not while it plays its closing motion).
func is_open() -> bool:
	return panel != null and panel.is_open()


## Opens or closes the popover.
func toggle() -> void:
	if is_open():
		close_box()
	else:
		open_box()


## Opens the popover (every other top-strip popover closes first).
func open_box() -> void:
	gs.menu.close_popups()
	Sfx.play("select")
	panel.visible = true
	GameChat.raise_for_input(panel)
	panel.appear()
	scroll.scroll_vertical = 0
	gs.hover.clear()


## Closes the popover with the house closing motion.
func close_box() -> void:
	if not is_open():
		return
	panel.dismiss()


## The Appendix button's icon: an open book in gold (two pages on a spine with ruled lines), with a
## soft dark under-stroke; brighter while the button is hovered. Click-through. The house style of
## the Menu button's MenuGlyph.
class BookGlyph extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var b := get_parent() as BaseButton
		var lit := b != null and b.is_hovered()
		var col := UIStyle.GOLD_HI if lit else UIStyle.GOLD
		var s := minf(size.x, size.y)
		var c := size / 2.0
		var hw := s * 0.3          # half the book's width
		var top := c.y - s * 0.2
		var bot := c.y + s * 0.2
		var dip := s * 0.05        # the pages sag towards the spine
		var th := maxf(1.5, s * 0.05)
		for side in [-1.0, 1.0]:
			var outer: float = c.x + side * hw
			var page := PackedVector2Array([Vector2(c.x, top + dip), Vector2(outer, top), Vector2(outer, bot), Vector2(c.x, bot + dip)])
			draw_colored_polygon(page, Color(col.darkened(0.72), 0.95))
			var rim := PackedVector2Array(page)
			rim.append(page[0])
			draw_polyline(rim, Color(0, 0, 0, 0.5), th + 1.0, true)
			draw_polyline(rim, col, th, true)
			for i in 3:
				var y := top + s * (0.1 + 0.09 * i)
				var x0: float = c.x + side * s * 0.06
				var x1: float = outer - side * s * 0.06
				draw_line(Vector2(x0, y + dip * 0.6), Vector2(x1, y), Color(col, 0.75), maxf(1.0, th * 0.6), true)
