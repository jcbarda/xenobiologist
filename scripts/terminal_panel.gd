class_name TerminalPanel
extends VBoxContainer
## Phase 0 readouts and the player's verbs. Gray boxes and placeholder text by
## design-doc 8 -- no theme work, no art.
##
## This is presentation only. It reads GameState every frame and never writes;
## pressing a button records an intent that the next Clock tick resolves.

const _READOUT_FONT_SIZE := 22
const _BUTTON_FONT_SIZE := 18

var _temp_readout: Label
var _static_readout: Label
var _water_readout: Label
var _status_line: Label
var _buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 10)
	_build_readouts()
	_build_actions()
	_build_status_line()
	SignalBus.blackout.connect(_on_blackout)


func _process(_delta: float) -> void:
	var data: Dictionary = GameState.data
	_temp_readout.text = "CORE TEMP        %5.1f C  %s" % [
		data.core_temperature, _trend(data.temp_velocity, 0.02),
	]
	# The rest point is shown because momentum makes the number alone a lie: a
	# static reading of 30%% that is settling toward 70%% is an emergency, and it
	# looks identical to one that is settling toward 10%%. Naming where it is
	# headed -- and that core temperature is what decides it -- is RISK-1's
	# pair-the-symptom-with-its-cause, applied to the model's least visible part.
	_static_readout.text = "NEURAL STATIC    %5.0f %%  %s   settling toward %.0f %%" % [
		data.neural_static * 100.0,
		_trend(data.static_velocity, 0.004),
		Tuning.static_rest_point(data.core_temperature) * 100.0,
	]
	_water_readout.text = "H2O RESERVE      %2d / %d" % [
		data.water, Tuning.WATER_CAPACITY,
	]
	for action_id: StringName in _buttons:
		var button: Button = _buttons[action_id]
		button.disabled = GameState.is_blacked_out() or not GameState.can_afford(action_id)


func _build_readouts() -> void:
	_temp_readout = _add_readout()
	_static_readout = _add_readout()
	_water_readout = _add_readout()


func _add_readout() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", _READOUT_FONT_SIZE)
	add_child(label)
	return label


func _build_actions() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
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
		# The cost is on the face of the button. RISK-1 says degradation must
		# always be paired with its cause; the player has to be able to see that
		# an action they chose is what moved the needle.
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


## Momentum is otherwise invisible: the value can sit still for a second while
## the velocity behind it is already committed.
func _trend(velocity: float, deadband: float) -> String:
	if velocity > deadband:
		return "^"
	if velocity < -deadband:
		return "v"
	return "-"


func _build_status_line() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	add_child(spacer)

	_status_line = Label.new()
	_status_line.add_theme_font_size_override("font_size", _READOUT_FONT_SIZE)
	add_child(_status_line)


func _on_blackout(cause: String) -> void:
	_status_line.text = "-- BLACKOUT: %s --" % cause
