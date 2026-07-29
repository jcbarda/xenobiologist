class_name DebugOverlay
extends PanelContainer
## Every value in GameState.data, with anything that just changed highlighted.
##
## Deliberately a dump rather than a curated view: the point is to see the whole
## state at once while playing, including the fields no gauge shows -- velocities,
## queue depths, the RNG seed. Highlighting is what makes it readable in motion,
## since a wall of numbers that all look alike tells you nothing about which one
## just moved.

const HIGHLIGHT_SECONDS := 1.2
const WIDTH := 340.0
const _MARGIN := 8.0
## Tight, because the state dump plus six sliders has to clear 720px of viewport
## without scrolling -- a tuning panel you have to scroll is one you stop reading.
const _BODY_FONT := 12
const _CAPTION_FONT := 11
const _SKIP := ["halos", "input_queue"]

var _text: RichTextLabel
var _pause_button: Button
var _sliders: Array[Dictionary] = []
var _previous: Dictionary = {}
var _changed_at: Dictionary = {}


func _ready() -> void:
	# Positioned directly in _process rather than by anchors. As a bare child of
	# a CanvasLayer this control has no parent rect for anchors to resolve
	# against, and right-anchoring silently pushed it off the viewport.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.04, 0.05, 0.88)
	box.set_border_width_all(1)
	box.border_color = Color("334155")
	box.set_content_margin_all(9)
	add_theme_stylebox_override("panel", box)

	# Mouse must reach the sliders, so the panel itself cannot ignore input --
	# only the read-only text inside it does.
	mouse_filter = Control.MOUSE_FILTER_PASS

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	add_child(column)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", _BODY_FONT)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_text)

	_build_controls(column)
	_reposition()


func _build_controls(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)

	_pause_button = Button.new()
	_pause_button.text = "PAUSE"
	_pause_button.custom_minimum_size = Vector2(92, 26)
	_pause_button.pressed.connect(_on_pause_pressed)
	row.add_child(_pause_button)

	var defaults := Button.new()
	defaults.text = "DEFAULTS"
	defaults.custom_minimum_size = Vector2(104, 26)
	defaults.pressed.connect(_on_defaults_pressed)
	row.add_child(defaults)

	for entry: Dictionary in Tuning.SLIDERS:
		var caption := Label.new()
		caption.add_theme_font_size_override("font_size", _CAPTION_FONT)
		caption.add_theme_color_override("font_color", Color("cbd5e1"))
		column.add_child(caption)

		var slider := HSlider.new()
		slider.min_value = entry.min
		slider.max_value = entry.max
		slider.step = entry.step
		slider.value = Tuning.live[entry.key]
		slider.custom_minimum_size = Vector2(0, 14)
		slider.value_changed.connect(
			func(v: float) -> void: Tuning.live[entry.key] = v
		)
		column.add_child(slider)
		_sliders.append({"entry": entry, "node": slider, "caption": caption})
	_refresh_captions()


func _on_pause_pressed() -> void:
	Clock.paused = not Clock.paused
	_pause_button.text = "RESUME" if Clock.paused else "PAUSE"


func _on_defaults_pressed() -> void:
	Tuning.restore_defaults()
	for row: Dictionary in _sliders:
		row.node.set_value_no_signal(Tuning.live[row.entry.key])
	_refresh_captions()


func _refresh_captions() -> void:
	for row: Dictionary in _sliders:
		row.caption.text = "%s   %.4f" % [row.entry.label, Tuning.live[row.entry.key]]


## Uses the configured viewport width rather than get_viewport_rect(), which under
## `canvas_items` stretch does not reliably report the coordinate space this
## CanvasLayer is actually laid out in -- and a wrong answer here puts the panel
## silently off-screen rather than visibly in the wrong place.
func _reposition() -> void:
	var width := float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280))
	position = Vector2(width - WIDTH - _MARGIN, _MARGIN)


func _process(_delta: float) -> void:
	if not visible:
		return
	_reposition()
	var now := Time.get_ticks_msec() / 1000.0
	var lines: PackedStringArray = ["[b]GAME STATE[/b]"]

	for key: String in GameState.data:
		if key in _SKIP:
			continue
		var value: Variant = GameState.data[key]
		if not _previous.has(key) or not is_same(_previous[key], value):
			# Floats drift every tick; only flag a move big enough to mean
			# something, or the whole panel stays permanently lit.
			if _is_meaningful_change(_previous.get(key), value):
				_changed_at[key] = now
			_previous[key] = value
		lines.append(_format(key, value, now))

	lines.append("")
	lines.append("[b]QUEUES[/b]")
	lines.append("  in flight   %d" % GameState.data.input_queue.size())
	lines.append("  live blooms %d" % GameState.data.halos.size())
	lines.append("")
	lines.append("[b]DERIVED[/b]")
	var st: float = GameState.data.neural_static
	lines.append("  hyper       %.2f  (press too hard)" % Tuning.hyper_degradation(st))
	lines.append("  hypo        %.2f  (too slow / too light)" % Tuning.hypo_degradation(st))
	lines.append("  motor lag   %d ms" % int(GameState.motor_lag_seconds() * 1000.0))
	lines.append("  lost presses %d%%" % int(GameState.light_press_miss_chance() * 100.0))
	lines.append("  bloom hold  %.2f s" % GameState.bloom_hold_seconds())
	var here: Dictionary = GameState.place()
	lines.append("  place       %s (%.0f C, static pull %.4f)" % [
		here.label, here.temperature, here.static_gravity,
	])
	if Clock.paused:
		lines.append("[color=#fbbf24]  -- PAUSED --[/color]")

	_text.text = "\n".join(lines)
	_refresh_captions()


func _is_meaningful_change(before: Variant, after: Variant) -> bool:
	if before == null:
		return false
	if typeof(after) == TYPE_FLOAT and typeof(before) == TYPE_FLOAT:
		return absf(after - before) > 0.01
	return true


func _format(key: String, value: Variant, now: float) -> String:
	var shown: String
	if typeof(value) == TYPE_FLOAT:
		shown = "%.4f" % value
	else:
		shown = str(value)
	var line := "  %-20s %s" % [key, shown]
	var since: float = now - float(_changed_at.get(key, -999.0))
	if since < HIGHLIGHT_SECONDS:
		return "[color=#fbbf24]%s[/color]" % line
	return "[color=#94a3b8]%s[/color]" % line
