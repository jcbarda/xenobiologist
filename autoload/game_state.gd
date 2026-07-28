extends Node
## The single serialisable state object, and the rules that advance it.
##
## Everything the sim knows lives in `data`, which holds only JSON-round-trippable
## values -- no nodes, no object references, no Resources. That is what lets a run
## be saved, reloaded, and advanced by replaying N ticks, which is how offline
## progress stays a later feature instead of a later rewrite.
##
## `data` is written in exactly one place: _on_tick, driven by Clock. Player input
## does not mutate anything -- it enqueues an intent that the next tick resolves.
## Presentation may read `data` every frame; it may never write.

## Bumped whenever the shape of `data` changes in a way old saves cannot satisfy.
const SCHEMA_VERSION := 3

var data: Dictionary = {}

## Actions pressed since the last tick, resolved in press order. M2 will delay
## entry into this queue proportionally to static -- the input lag hook is here
## precisely so degradation does not need to reach into the sim later.
var _pending: Array[StringName] = []


func _ready() -> void:
	reset()
	Clock.tick.connect(_on_tick)


func reset() -> void:
	data = {
		"schema_version": SCHEMA_VERSION,
		"ticks_elapsed": 0,
		"day": 1,
		"core_temperature": Tuning.CORE_TEMP_START,
		"neural_static": 0.0,
		# Momentum. Serialised with everything else, so a reloaded run resumes
		# mid-glide rather than snapping to rest.
		"temp_velocity": 0.0,
		"static_velocity": 0.0,
		"water": Tuning.WATER_START,
		# Listed in design-doc 4.1 as a vital but deliberately inert for the
		# slice: section 8 names two clocks, and a third would blur the read.
		"hydration": 1.0,
		# Empty while conscious; otherwise the reason, for the M5 lid slam.
		"blackout_cause": "",
	}
	_pending.clear()


func is_blacked_out() -> bool:
	return data.blackout_cause != ""


## Called from UI. Records intent only -- see the class comment.
func request_action(action_id: StringName) -> void:
	if is_blacked_out():
		return
	_pending.append(action_id)


## True when the action's water cost can currently be paid. Presentation uses this
## to disable buttons; the tick re-checks it, because state can move in between.
func can_afford(action_id: StringName) -> bool:
	var water_delta: int = Actions.spec(action_id).water
	return data.water + water_delta >= 0


# --- Simulation -------------------------------------------------------------


func _on_tick(sim_delta: float) -> void:
	if is_blacked_out():
		return
	data.ticks_elapsed += 1
	_resolve_pending_actions()
	_advance_vitals(sim_delta)
	_check_collapse()


## Actions push velocity, never a value -- see actions.gd.
func _resolve_pending_actions() -> void:
	for action_id in _pending:
		if not can_afford(action_id):
			continue
		var action: Dictionary = Actions.spec(action_id)
		data.water = clampi(data.water + action.water, 0, Tuning.WATER_CAPACITY)
		data.temp_velocity += action.temp_impulse

		# Brake before paying the cognitive load, so a damper can never cancel
		# the cost of having been pressed. This ordering is what makes spamming
		# it strictly negative once static has stopped climbing.
		data.static_velocity *= 1.0 - float(action.brake)
		# Cognitive load is flat per action (OQ-1); exertion and damping belong
		# to the specific activity.
		data.static_velocity += (
			Tuning.COGNITIVE_LOAD + action.exertion - action.damping
		)
		SignalBus.action_resolved.emit(action_id)
	_pending.clear()


## Second-order integration: gravity accelerates each vital toward its rest
## point, friction bleeds the velocity off, and the value follows the velocity.
func _advance_vitals(sim_delta: float) -> void:
	# Core temperature falls toward ambient, which is well past collapse.
	data.temp_velocity += (
		Tuning.TEMP_GRAVITY * (Tuning.AMBIENT_TEMP - data.core_temperature) * sim_delta
	)
	data.temp_velocity -= data.temp_velocity * Tuning.TEMP_FRICTION * sim_delta
	data.core_temperature += data.temp_velocity * sim_delta

	# Static settles wherever body heat says it should. This is the coupling that
	# makes cooling the only durable treatment.
	var rest: float = Tuning.static_rest_point(data.core_temperature)
	data.static_velocity += Tuning.STATIC_GRAVITY * (rest - data.neural_static) * sim_delta
	data.static_velocity -= data.static_velocity * Tuning.STATIC_FRICTION * sim_delta
	data.neural_static = clampf(
		data.neural_static + data.static_velocity * sim_delta, 0.0, Tuning.STATIC_BLACKOUT
	)


## Not a death screen -- the sim halts and M5 will slam the lid on it. Static is
## checked first so a heat-driven spiral reports the symptom the player was
## watching climb.
func _check_collapse() -> void:
	if data.neural_static >= Tuning.STATIC_BLACKOUT:
		data.blackout_cause = "NEURAL STATIC"
	elif data.core_temperature >= Tuning.CORE_TEMP_COLLAPSE:
		data.blackout_cause = "CORE TEMPERATURE"
	else:
		return
	_pending.clear()
	SignalBus.blackout.emit(data.blackout_cause)


# --- Serialisation ----------------------------------------------------------


func to_json() -> String:
	return JSON.stringify(data)


## Returns false and leaves state untouched if the payload is unreadable or was
## written by a schema this build cannot interpret.
func from_json(json_text: String) -> bool:
	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameState: save payload is not a dictionary; ignoring.")
		return false
	var incoming: Dictionary = parsed
	if incoming.get("schema_version") != SCHEMA_VERSION:
		push_warning("GameState: save schema %s != %s; ignoring." % [
			incoming.get("schema_version"), SCHEMA_VERSION,
		])
		return false
	data = incoming
	_pending.clear()
	return true
