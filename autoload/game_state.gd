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
const SCHEMA_VERSION := 4

var data: Dictionary = {}

## Raw presses the OS has reported since the last tick. Deliberately NOT part of
## `data`: it is what the outside world said, not anything the sim knows yet. The
## tick drains it, which is what keeps every write to `data` inside a tick.
##
## Entries are {"action": String, "x": float, "y": float}.
var _inbox: Array[Dictionary] = []

## Set by UI, consumed by the next tick. Starting a new run is not advancing the
## sim, but routing it through the tick keeps "data is written in exactly one
## place" true without exception.
var _reset_requested := false

## Screen bounds, so stray contacts land somewhere real. Presentation supplies
## it; the sim only reads it.
var viewport_size := Vector2(1280, 720)


## Deterministic, and advanced through `data`, so a saved run reproduces the same
## scatter when replayed.
func _next_random() -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.rng_seed)
	var value := rng.randf()
	data.rng_seed = rng.randi()
	return value


func _ready() -> void:
	reset()
	Clock.tick.connect(_on_tick)


func reset() -> void:
	data = {
		"schema_version": SCHEMA_VERSION,
		"ticks_elapsed": 0,
		"day": 1,
		"core_temperature": Tuning.CORE_TEMP_START,
		# Resting brain activity, not zero -- zero is death, not a healthy start.
		"neural_static": Tuning.STATIC_BASELINE,
		# Momentum. Serialised with everything else, so a reloaded run resumes
		# mid-glide rather than snapping to rest.
		"temp_velocity": 0.0,
		"static_velocity": 0.0,
		"water": Tuning.WATER_START,
		# Where the player is standing. The place fixes BOTH rest points, and
		# moving it is the whole of M4's excursion budget.
		"place": String(Tuning.STARTING_PLACE),
		# Seeded so a run replays identically from its state, including the
		# scatter of stray contacts. Advanced in place every time it is used.
		"rng_seed": 20260729,
		# Listed in design-doc 4.1 as a vital but deliberately inert for the
		# slice: section 8 names two clocks, and a third would blur the read.
		"hydration": 1.0,
		# Commands that have left the player's intent but not yet their body.
		# Entries are {"action": String, "ticks": int}; ticks counts down.
		"input_queue": [],
		# Contact blooms burned into the pressure layer. Entries are
		# {"x", "y", "radius", "ticks", "total"}. While one is live the panel
		# will not read a second contact inside it.
		"halos": [],
		# Empty while conscious; otherwise the reason, for the M5 lid slam.
		"blackout_cause": "",
	}
	_inbox.clear()


func is_blacked_out() -> bool:
	return data.blackout_cause != ""


## Queues a fresh run. Applied by the next tick, not here.
func request_reset() -> void:
	_reset_requested = true


func place() -> Dictionary:
	return Tuning.place(StringName(data.place))


## Called from UI on a press. Records the raw contact only -- the tick decides
## when (and whether) it becomes an action.
##
## Returns false when the panel refuses the contact because it landed inside a
## bloom that has not cleared. Presentation uses that to show the refusal, which
## matters: a press that silently does nothing reads as a broken build, and a
## press visibly swallowed by a mark the player can see reads as the device.
func request_action(action_id: StringName, press_position: Vector2) -> bool:
	if is_blacked_out():
		return false
	if is_blocked_by_bloom(press_position):
		return false
	_inbox.append({
		"action": String(action_id),
		"x": press_position.x,
		"y": press_position.y,
	})
	return true


## Read-only. Reading state outside a tick is fine; only writing is forbidden.
func is_blocked_by_bloom(press_position: Vector2) -> bool:
	for halo: Dictionary in data.halos:
		if press_position.distance_to(Vector2(halo.x, halo.y)) <= halo.radius:
			return true
	return false


# --- Degradation, derived from static ---------------------------------------
#
# All three read from Tuning.degradation(), so they worsen together and the
# player only ever has one cause to understand.


func motor_lag_seconds() -> float:
	return Tuning.degradation(data.neural_static) * Tuning.MOTOR_LAG_MAX_SECONDS


func tremor_pixels() -> float:
	return Tuning.degradation(data.neural_static) * Tuning.TREMOR_MAX_PIXELS


## How long a contact bloom lingers. Always non-zero -- the screen is
## pressure-sensitive by design -- but strain makes the press heavier.
func bloom_hold_seconds() -> float:
	return lerpf(
		Tuning.HALO_HOLD_SECONDS_MIN,
		Tuning.HALO_HOLD_SECONDS_MAX,
		Tuning.degradation(data.neural_static),
	)


## True when the action's water cost can currently be paid. Presentation uses this
## to disable buttons; the tick re-checks it, because state can move in between.
func can_afford(action_id: StringName) -> bool:
	var water_delta: int = Actions.spec(action_id).water
	return data.water + water_delta >= 0


# --- Simulation -------------------------------------------------------------


func _on_tick(sim_delta: float) -> void:
	# Before the blackout gate, so a reset can revive a run that has ended.
	if _reset_requested:
		_reset_requested = false
		reset()
		return
	if is_blacked_out():
		return
	data.ticks_elapsed += 1
	_accept_contacts()
	_age_blooms()
	_resolve_ready_inputs()
	_advance_vitals(sim_delta)
	_check_collapse()


## Turn raw contacts into delayed commands, and burn a bloom where each landed.
## The lag is measured at the moment of contact, so a command issued while calm
## still arrives on time even if the player falls apart waiting for it.
func _accept_contacts() -> void:
	for contact: Dictionary in _inbox:
		var delay_ticks := int(round(motor_lag_seconds() / Clock.TICK_SECONDS))
		data.input_queue.append({
			"action": contact.action,
			"ticks": delay_ticks,
		})
		_burn_contacts(Vector2(contact.x, contact.y))
	_inbox.clear()


## A failing hand does not land once, cleanly.
##
## At high degradation the finger drags before it settles (a slide), and other
## fingers put down stray contacts elsewhere on the glass. Every one of those
## blooms, and every bloom both hides what is behind it and refuses presses
## inside it -- so a bad press can blind a control the player was not even
## reaching for.
func _burn_contacts(origin: Vector2) -> void:
	var wobble := Tuning.degradation(data.neural_static)
	_burn_one(origin)
	if wobble <= 0.0:
		return

	if _next_random() < Tuning.SLIDE_CHANCE * wobble:
		var angle := _next_random() * TAU
		var reach := Tuning.SLIDE_DISTANCE_PIXELS * wobble * (0.4 + _next_random() * 0.6)
		_burn_one(origin + Vector2.from_angle(angle) * reach)

	if _next_random() < Tuning.STRAY_CONTACT_CHANCE * wobble:
		_burn_one(Vector2(
			_next_random() * viewport_size.x,
			_next_random() * viewport_size.y,
		))


func _burn_one(at: Vector2) -> void:
	if data.halos.size() >= Tuning.HALO_MAX_ACTIVE:
		data.halos.pop_front()
	var hold_ticks := int(round(bloom_hold_seconds() / Clock.TICK_SECONDS))
	data.halos.append({
		"x": at.x,
		"y": at.y,
		"radius": Tuning.HALO_RADIUS_PIXELS,
		"ticks": hold_ticks,
		"total": maxi(hold_ticks, 1),
	})


func _age_blooms() -> void:
	var live: Array = []
	for halo: Dictionary in data.halos:
		halo.ticks -= 1
		if halo.ticks > 0:
			live.append(halo)
	data.halos = live


## Actions push velocity, never a value -- see actions.gd.
func _resolve_ready_inputs() -> void:
	var still_waiting: Array = []
	var ready: Array[StringName] = []
	for command: Dictionary in data.input_queue:
		command.ticks -= 1
		if command.ticks > 0:
			still_waiting.append(command)
		else:
			ready.append(StringName(command.action))
	data.input_queue = still_waiting

	for action_id in ready:
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


## Second-order integration: gravity accelerates each vital toward its rest
## point, friction bleeds the velocity off, and the value follows the velocity.
func _advance_vitals(sim_delta: float) -> void:
	# Both vitals are dragged toward the place the player is standing in, and
	# neither reads the other. Two independent loops, one tool each.
	var here: Dictionary = place()

	data.temp_velocity += (
		Tuning.TEMP_GRAVITY * (here.temperature - data.core_temperature) * sim_delta
	)
	data.temp_velocity -= data.temp_velocity * Tuning.TEMP_FRICTION * sim_delta
	data.core_temperature += data.temp_velocity * sim_delta

	data.static_velocity += (
		Tuning.STATIC_GRAVITY * (here.static - data.neural_static) * sim_delta
	)
	data.static_velocity -= data.static_velocity * Tuning.STATIC_FRICTION * sim_delta
	data.neural_static = clampf(
		data.neural_static + data.static_velocity * sim_delta, 0.0, Tuning.STATIC_SEIZURE
	)


## Not a death screen -- the sim halts and M5 will slam the lid on it.
##
## Static fails at BOTH ends, because it is brain activity: everything firing at
## once, or nothing firing at all. Over-suppression is a real way to die, which
## is what makes the damper genuinely double-edged rather than just expensive.
## Static is checked before heat so a spiral reports the symptom the player was
## actually watching climb.
func _check_collapse() -> void:
	if data.neural_static >= Tuning.STATIC_SEIZURE:
		data.blackout_cause = "NEURAL SEIZURE"
	elif data.neural_static <= Tuning.STATIC_SILENCE:
		data.blackout_cause = "NEURAL SILENCE"
	elif data.core_temperature >= Tuning.CORE_TEMP_COLLAPSE:
		data.blackout_cause = "CORE TEMPERATURE"
	else:
		return
	# Commands still in flight die with consciousness; blooms stay, because they
	# are marks on the glass rather than anything the body is doing.
	data.input_queue.clear()
	_inbox.clear()
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
	_inbox.clear()
	return true
