class_name TerminalPanel
extends VBoxContainer
## Phase 0 readouts and the player's verbs. Gray boxes and placeholder text by
## design-doc 8 -- the only colour is the vital bands, which are information
## rather than decoration.
##
## This is presentation only. It reads GameState every frame and never writes;
## pressing a button records an intent that the next Clock tick resolves.

const _BUTTON_FONT_SIZE := 18
const _BUTTON_SIZE := Vector2(200, 56)
const _BUTTON_GAP := 12.0
## Room around the row for buttons to wander into without clipping.
const _TREMOR_MARGIN := 40.0
const _REFUSAL_HOLD_SECONDS := 1.1

var _temp_gauge: VitalGauge
var _static_gauge: VitalGauge
var _water_gauge: VitalGauge
var _context_line: Label
var _hardware_line: Label
var _status_line: Label
var _action_row: Control
var _buttons: Dictionary = {}
var _refusal_timer := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 6)
	_build_gauges()
	_build_context_line()
	_build_hardware_line()
	_build_actions()
	_build_status_line()
	SignalBus.blackout.connect(_on_blackout)


func _process(delta: float) -> void:
	var data: Dictionary = GameState.data
	_refusal_timer = maxf(0.0, _refusal_timer - delta)
	_apply_tremor()
	_refresh_hardware_line()
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


func _build_hardware_line() -> void:
	_hardware_line = Label.new()
	_hardware_line.add_theme_font_size_override("font_size", 15)
	add_child(_hardware_line)


## The single most important line on screen for RISK-1.
##
## Input lag, drifting buttons and refused presses are indistinguishable from
## defects unless the terminal states, on the same frame, that it is measuring
## them. Naming the numbers turns "this build is broken" into "look what is
## happening to me" -- so these readouts appear the instant degradation begins
## and are silent while the player is inside the functional band.
func _refresh_hardware_line() -> void:
	if _refusal_timer > 0.0:
		_hardware_line.text = "CONTACT REFUSED -- pressure bloom has not cleared"
		_hardware_line.add_theme_color_override(
			"font_color", Vitals.BAND_COLOR[Vitals.Band.HYPER_DEADLY]
		)
		return

	var lag := GameState.motor_lag_seconds()
	var tremor := GameState.tremor_pixels()
	var in_flight: int = GameState.data.input_queue.size()

	if lag <= 0.0 and tremor <= 0.0:
		_hardware_line.text = "MOTOR CONTROL nominal   |   contact bloom %.1f s" % [
			GameState.bloom_hold_seconds(),
		]
		_hardware_line.add_theme_color_override("font_color", Color("64748b"))
		return

	_hardware_line.text = (
		"MOTOR LAG %d ms (%d in flight)   |   TREMOR %.0f px   |   BLOOM %.1f s"
	) % [int(lag * 1000.0), in_flight, tremor, GameState.bloom_hold_seconds()]
	_hardware_line.add_theme_color_override(
		"font_color", Vitals.color_for(GameState.data.neural_static * 100.0, Vitals.NEURAL_STATIC)
	)


## Buttons are positioned by hand rather than by a container, because a container
## would fight the tremor offset every frame. The row is a plain Control and each
## button owns its own position within it.
func _build_actions() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 22)
	add_child(spacer)

	_action_row = Control.new()
	_action_row.custom_minimum_size = Vector2(0, _BUTTON_SIZE.y + _TREMOR_MARGIN * 2.0)
	add_child(_action_row)

	var index := 0
	for action_id in Actions.available():
		var action: Dictionary = Actions.spec(action_id)
		var button := Button.new()
		button.text = action.label
		button.size = _BUTTON_SIZE
		button.add_theme_font_size_override("font_size", _BUTTON_FONT_SIZE)
		button.tooltip_text = _describe_cost(action)
		button.set_meta("home", Vector2(
			index * (_BUTTON_SIZE.x + _BUTTON_GAP), _TREMOR_MARGIN
		))
		# Each button gets its own phase so they twitch independently -- a row
		# moving in unison reads as the camera shaking, not as a hand.
		button.set_meta("phase", float(index) * 2.399)
		button.position = button.get_meta("home")
		button.pressed.connect(_on_action_pressed.bind(action_id))
		_action_row.add_child(button)
		_buttons[action_id] = button
		index += 1


## The buttons genuinely move, so a miss is a real miss against real geometry --
## the player's aim was beaten by a hand that will not hold still, rather than by
## a hidden dice roll. Nothing here writes state.
func _apply_tremor() -> void:
	var amplitude := GameState.tremor_pixels()
	var t := float(Time.get_ticks_msec()) / 1000.0
	for action_id: StringName in _buttons:
		var button: Button = _buttons[action_id]
		var phase: float = button.get_meta("phase")
		var home: Vector2 = button.get_meta("home")
		button.position = home + Vector2(
			_twitch(t, phase) * amplitude,
			_twitch(t * 1.17, phase + 4.1) * amplitude * 0.7,
		)


## Two detuned sines: fast enough to read as tremor, irrational enough in ratio
## that it never settles into a visible loop. Range is about [-1, 1].
func _twitch(t: float, phase: float) -> float:
	return (
		0.6 * sin(t * Tuning.TREMOR_JITTER_HZ + phase)
		+ 0.4 * sin(t * Tuning.TREMOR_JITTER_HZ * 2.37 + phase * 1.7)
	)


func _on_action_pressed(action_id: StringName) -> void:
	var contact := get_viewport().get_mouse_position()
	if GameState.request_action(action_id, contact):
		return
	# Refused because the contact landed inside a bloom that has not cleared.
	# This MUST be said out loud: a press that silently does nothing reads as a
	# broken build, which is RISK-1's failure mode exactly.
	_refusal_timer = _REFUSAL_HOLD_SECONDS


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
