class_name TerminalPanel
extends VBoxContainer
## Phase 0 readouts and the player's verbs. Gray boxes and placeholder text by
## design-doc 8 -- the only colour is the vital bands, which are information
## rather than decoration.
##
## This is presentation only. It reads GameState every frame and never writes;
## pressing a button records an intent that the next Clock tick resolves.

const _BUTTON_GAP := 34.0
## Room around the row for buttons to wander into without clipping.
const _TREMOR_MARGIN := 44.0
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
var _refusal_reason := &""


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
	GameState.viewport_size = get_viewport_rect().size
	_refusal_timer = maxf(0.0, _refusal_timer - delta)
	_apply_contact_fade()
	_refresh_hardware_line()
	_temp_gauge.display(data.core_temperature, data.temp_velocity)
	_static_gauge.display(data.neural_static * 100.0, data.static_velocity)
	_water_gauge.display(float(data.water), 0.0)

	# Naming both rest points is the whole legibility of the model. Momentum
	# makes a bare reading a lie -- 30% settling toward 90% is an emergency and
	# looks identical to 30% settling toward 10% -- and pairing each symptom with
	# the cause driving it is RISK-1's mitigation.
	var here: Dictionary = GameState.place()
	_context_line.text = (
		"%s -- pulling core temp toward %.0f C.  Static always climbs toward 100 %%."
	) % [here.label, here.temperature]

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
		if _refusal_reason == GameState.REFUSED_BLOOM:
			_hardware_line.text = "CONTACT REFUSED -- pressure bloom has not cleared"
			_hardware_line.add_theme_color_override(
				"font_color", Vitals.BAND_COLOR[Vitals.Band.HYPER_DEADLY]
			)
		else:
			_hardware_line.text = "CONTACT TOO LIGHT -- panel did not register the press"
			_hardware_line.add_theme_color_override(
				"font_color", Vitals.BAND_COLOR[Vitals.Band.HYPO_DEADLY]
			)
		return

	var static_pct: float = GameState.data.neural_static * 100.0
	var hyper := Tuning.hyper_degradation(GameState.data.neural_static)
	var hypo := Tuning.hypo_degradation(GameState.data.neural_static)

	if hyper <= 0.0 and hypo <= 0.0:
		_hardware_line.text = "MOTOR CONTROL nominal   |   contact bloom %.1f s" % [
			GameState.bloom_hold_seconds(),
		]
		_hardware_line.add_theme_color_override("font_color", Color("64748b"))
		return

	if hyper > 0.0:
		_hardware_line.text = "PRESSING TOO HARD   |   contact bloom %.1f s" % [
			GameState.bloom_hold_seconds(),
		]
	else:
		_hardware_line.text = (
			"PRESSING TOO LIGHT   |   motor lag %d ms (%d in flight)   |   %d%% of contacts lost"
		) % [
			int(GameState.motor_lag_seconds() * 1000.0),
			GameState.data.input_queue.size(),
			int(GameState.light_press_miss_chance() * 100.0),
		]
	_hardware_line.add_theme_color_override(
		"font_color", Vitals.color_for(static_pct, Vitals.NEURAL_STATIC)
	)


## Buttons are positioned by hand rather than by a container, because a container
## would fight the tremor offset every frame. The row is a plain Control and each
## button owns its own position within it.
func _build_actions() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 22)
	add_child(spacer)

	_action_row = Control.new()
	_action_row.custom_minimum_size = Vector2(
		0, RoundButton.DIAMETER + _TREMOR_MARGIN * 2.0
	)
	add_child(_action_row)

	var index := 0
	for action_id in Actions.available():
		var action: Dictionary = Actions.spec(action_id)
		var button := RoundButton.new()
		button.text = action.label
		button.tooltip_text = "%s -- %s" % [action.caption, _describe_cost(action)]
		button.set_meta("home", Vector2(
			index * (RoundButton.DIAMETER + _BUTTON_GAP), _TREMOR_MARGIN
		))
		button.set_meta("offset", Vector2.ZERO)
		button.set_meta("dwell", 0.0)
		button.position = button.get_meta("home")
		button.pressed.connect(_on_action_pressed.bind(action_id))
		_action_row.add_child(button)
		_buttons[action_id] = button
		index += 1


## Keys fade as contact weakens.
##
## The HYPO tell: below the functional band the player is pressing too lightly
## for the panel to read, and some contacts simply do not land. Fading the keys
## is what makes that legible in advance -- the player watches the controls go
## faint and can see the next miss coming, instead of being told afterwards that
## a press they thought they made never happened.
func _apply_contact_fade() -> void:
	var faintness := Tuning.hypo_degradation(GameState.data.neural_static)
	var alpha := lerpf(1.0, Tuning.FADED_BUTTON_ALPHA, faintness)
	for action_id: StringName in _buttons:
		var button: Button = _buttons[action_id]
		button.modulate = Color(1.0, 1.0, 1.0, alpha)


func _on_action_pressed(action_id: StringName) -> void:
	var contact := get_viewport().get_mouse_position()
	var outcome := GameState.request_action(action_id, contact)
	if outcome == GameState.ACCEPTED:
		return
	# A refusal MUST be said out loud, and it must say WHICH refusal: a press
	# that silently does nothing reads as a broken build, which is RISK-1's
	# failure mode exactly.
	_refusal_reason = outcome
	_refusal_timer = _REFUSAL_HOLD_SECONDS


func _describe_cost(action: Dictionary) -> String:
	var parts: PackedStringArray = []
	parts.append("H2O %+d" % action.water)
	if action.temp_impulse != 0.0:
		parts.append("TEMP %s" % ("cools" if action.temp_impulse < 0.0 else "heats"))
	if action.brake > 0.0:
		parts.append("arrests static's climb")
	var net_static: float = (
		float(Tuning.live.cognitive_load) + action.exertion - action.damping
	)
	parts.append("STATIC %+.0f%%/s" % (net_static * 100.0))
	return "  ".join(parts)


func _build_status_line() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	add_child(spacer)

	_status_line = Label.new()
	_status_line.add_theme_font_size_override("font_size", 22)
	add_child(_status_line)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	add_child(controls)

	var reset := Button.new()
	reset.text = "RESET RUN"
	reset.custom_minimum_size = Vector2(130, 34)
	reset.pressed.connect(_on_reset_pressed)
	controls.add_child(reset)

	# A plain button, not a toggle. `toggled` did not fire in the exported web
	# build even though `pressed` on the identical layout did; rather than chase
	# that, this uses the path already known to work.
	var debug := Button.new()
	debug.text = "DEBUG"
	debug.custom_minimum_size = Vector2(100, 34)
	debug.pressed.connect(func() -> void: SignalBus.debug_toggle_requested.emit())
	controls.add_child(debug)

	var quit := Button.new()
	quit.text = "EXIT"
	quit.custom_minimum_size = Vector2(90, 34)
	quit.pressed.connect(func() -> void: get_tree().quit())
	controls.add_child(quit)


## Deliberately NOT routed through the bloom/lag machinery. These are controls on
## the case, not contacts on the pressure screen -- a player who has lost enough
## motor control to be unable to press RESET would have no way out at all.
func _on_reset_pressed() -> void:
	GameState.request_reset()
	_status_line.text = ""
	_refusal_timer = 0.0


func _on_blackout(cause: String) -> void:
	_status_line.text = "-- BLACKOUT: %s --" % cause
	_status_line.add_theme_color_override(
		"font_color", Vitals.BAND_COLOR[Vitals.Band.HYPER_DEADLY]
	)
