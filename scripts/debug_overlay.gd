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
const _MARGIN := 16.0
const _SKIP := ["halos", "input_queue"]

var _text: RichTextLabel
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
	box.set_content_margin_all(12)
	add_theme_stylebox_override("panel", box)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 13)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text)
	_reposition()


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
	lines.append("  degradation %.2f" % Tuning.degradation(GameState.data.neural_static))
	lines.append("  motor lag   %d ms" % int(GameState.motor_lag_seconds() * 1000.0))
	lines.append("  tremor      %.0f px" % GameState.tremor_pixels())
	lines.append("  bloom hold  %.2f s" % GameState.bloom_hold_seconds())
	var here: Dictionary = GameState.place()
	lines.append("  place       %s (%.0f C / %.0f%% static)" % [
		here.label, here.temperature, here.static * 100.0,
	])

	_text.text = "\n".join(lines)


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
