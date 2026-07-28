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
const SCHEMA_VERSION := 2

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


func _resolve_pending_actions() -> void:
	for action_id in _pending:
		if not can_afford(action_id):
			continue
		var action: Dictionary = Actions.spec(action_id)
		data.water = clampi(data.water + action.water, 0, Tuning.WATER_CAPACITY)
		data.core_temperature += action.temp
		# Cognitive load is flat per action (OQ-1); exertion and damping are
		# properties of the specific activity.
		data.neural_static += Tuning.COGNITIVE_LOAD + action.exertion - action.damping
		data.neural_static = clampf(data.neural_static, 0.0, Tuning.STATIC_BLACKOUT)
		SignalBus.action_resolved.emit(action_id)
	_pending.clear()


func _advance_vitals(sim_delta: float) -> void:
	data.core_temperature += Tuning.CORE_TEMP_RISE * sim_delta
	var over_threshold: float = maxf(
		0.0, data.core_temperature - Tuning.STATIC_HEAT_THRESHOLD
	)
	data.neural_static += Tuning.STATIC_HEAT_GAIN * over_threshold * sim_delta
	data.neural_static = clampf(data.neural_static, 0.0, Tuning.STATIC_BLACKOUT)


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
