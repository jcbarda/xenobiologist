class_name TerminalPanel
extends VBoxContainer
## Phase 0 readouts and the player's verbs. Gray boxes and placeholder text by
## design-doc 8 -- the only colour is the vital bands, which are information
## rather than decoration.
##
## This is presentation only. It reads GameState every frame and never writes;
## pressing a button records an intent that the next Clock tick resolves.

const _BUTTON_FONT_SIZE := 18

var _temp_gauge: VitalGauge
var _static_gauge: VitalGauge
var _water_gauge: VitalGauge
var _context_line: Label
var _status_line: Label
var _buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 6)
	_build_gauges()
	_build_context_line()
	_build_actions()
	_build_status_line()
	SignalBus.blackout.connect(_on_blackout)


func _process(_delta: float) -> void:
	var data: Dictionary = GameState.data
	_temp_gauge.display(data.core_temperature, data.temp_velocity)
	_static_gauge.display(data.neural_static * 100.0, data.static_velocity)
	_water_gauge.display(float(data.water), 0.0)

	# Naming both rest points is the whole legibility of the model. Momentum
	# makes a bare reading a lie -- 30% settling toward 90% is an emergency and
	# looks identical to 30% settling toward 10% -- and pairing each symptom with
	# the cause driving it is RISK-1's mitigation.
	_context_line.text = (
		"AMBIENT %.0f C -> body pulled toward it   |   "
		+ "at %.1f C static settles toward %.0f %%"
	) % [
		data.ambient_temperature,
		data.core_temperature,
		Tuning.static_rest_point(data.core_temperature) * 100.0,
	]

	for action_id: StringName in _buttons:
		var button: Button = _buttons[action_id]
		button.disabled = GameState.is_blacked_out() or not GameState.can_afford(action_id)


func _build_gauges() -> void:
	_temp_gauge = _add_gauge("CORE TEMP", Vitals.CORE_TEMP, " C", "%.1f", 0.02)
	_static_gauge = _add_gauge("NEURAL STATIC", Vitals.NEURAL_STATIC, " %", "%.0f", 0.004)
	# Water moves only in whole units when an action lands, so a trend arrow on
	# it would be noise -- it is a reserve, not a vital under continuous drift.
	_water_gauge = _add_gauge("H2O RESERVE", Vitals.WATER, "", "%.0f", INF)


func _add_gauge(
	vital_name: String, spec: Dictionary, suffix: String, fmt: String, deadband: float
) -> VitalGauge:
	var gauge := VitalGauge.new()
	gauge.vital_name = vital_name
	gauge.spec = spec
	gauge.value_suffix = suffix
	gauge.value_format = fmt
	gauge.trend_deadband = deadband
	add_child(gauge)
	return gauge


func _build_context_line() -> void:
	_context_line = Label.new()
	_context_line.add_theme_font_size_override("font_size", 15)
	_context_line.add_theme_color_override("font_color", Color("94a3b8"))
	add_child(_context_line)


func _build_actions() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 22)
	add_child(spacer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	for action_id in Actions.available():
		var action: Dictionary = Actions.spec(action_id)
		var button := Button.new()
		button.text = action.label
		button.custom_minimum_size = Vector2(200, 56)
		button.add_theme_font_size_override("font_size", _BUTTON_FONT_SIZE)
		button.tooltip_text = _describe_cost(action)
		button.pressed.connect(GameState.request_action.bind(action_id))
		row.add_child(button)
		_buttons[action_id] = button


func _describe_cost(action: Dictionary) -> String:
	var parts: PackedStringArray = []
	parts.append("H2O %+d" % action.water)
	if action.temp_impulse != 0.0:
		parts.append("TEMP %s" % ("cools" if action.temp_impulse < 0.0 else "heats"))
	if action.brake > 0.0:
		parts.append("arrests static's climb")
	var net_static: float = Tuning.COGNITIVE_LOAD + action.exertion - action.damping
	parts.append("STATIC %+.0f%%/s" % (net_static * 100.0))
	return "  ".join(parts)


func _build_status_line() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	add_child(spacer)

	_status_line = Label.new()
	_status_line.add_theme_font_size_override("font_size", 22)
	add_child(_status_line)


func _on_blackout(cause: String) -> void:
	_status_line.text = "-- BLACKOUT: %s --" % cause
	_status_line.add_theme_color_override(
		"font_color", Vitals.BAND_COLOR[Vitals.Band.HYPER_DEADLY]
	)
