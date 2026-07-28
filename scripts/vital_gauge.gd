class_name VitalGauge
extends Control
## One vital, read out as a sensor instrument rather than a number.
##
## Shows the value, which band it is in, which way it is moving, and -- the part
## a bare number cannot convey -- where the safe ground is relative to where the
## player currently stands. Design-doc 7 asks for the terminal to behave like an
## instrument, and a bar with the danger ranges printed on it is the cheapest
## honest version of that.
##
## Momentum makes the trend arrow essential rather than decorative: a value can
## sit still for a second while the velocity behind it is already committed.

const HEIGHT := 66.0
const BAR_TOP := 34.0
const BAR_HEIGHT := 16.0
const BAND_ALPHA := 0.30

var vital_name := ""
var spec := {}
var value_suffix := ""
var value_format := "%.1f"
## Velocity below which the trend reads as steady. Set per vital because core
## temperature and static move on very different scales.
var trend_deadband := 0.01

var _value := 0.0
var _velocity := 0.0
var _label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(560, HEIGHT)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 20)
	add_child(_label)


## Presentation only -- the sim never calls this, and this never writes state.
func display(value: float, velocity: float) -> void:
	_value = value
	_velocity = velocity
	var band_color: Color = Vitals.color_for(value, spec)
	_label.text = "%-16s %s%s  %s   %s" % [
		vital_name,
		value_format % value,
		value_suffix,
		_trend_glyph(),
		Vitals.label_for(value, spec),
	]
	_label.add_theme_color_override("font_color", band_color)
	queue_redraw()


func _trend_glyph() -> String:
	if _velocity > trend_deadband:
		return "^"
	if _velocity < -trend_deadband:
		return "v"
	return "-"


func _draw() -> void:
	var width := size.x
	var lo: float = spec.min
	var hi: float = spec.max
	var span: float = maxf(hi - lo, 0.0001)

	# The bands themselves, dimmed -- they are the map, not the reading.
	var cursor := lo
	for entry: Dictionary in spec.bands:
		var upper: float = minf(entry.until, hi)
		if upper <= cursor:
			continue
		var x0 := (cursor - lo) / span * width
		var x1 := (upper - lo) / span * width
		var color: Color = Vitals.BAND_COLOR[entry.band]
		color.a = BAND_ALPHA
		draw_rect(Rect2(x0, BAR_TOP, x1 - x0, BAR_HEIGHT), color)
		cursor = upper
		if cursor >= hi:
			break

	# Where the player actually is, at full strength so it reads against the bands.
	var marker_x := clampf((_value - lo) / span, 0.0, 1.0) * width
	var marker_color: Color = Vitals.color_for(_value, spec)
	draw_rect(Rect2(marker_x - 2.0, BAR_TOP - 4.0, 4.0, BAR_HEIGHT + 8.0), marker_color)
