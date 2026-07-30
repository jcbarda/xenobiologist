class_name Actions
extends RefCounted
## The player's verbs, as data.
##
## Actions push velocity, never a value. Nothing lands on the frame it is
## pressed -- the vitals carry momentum, so every action is a bet on where things
## will be in a few seconds rather than a correction to where they are now.
##
## Specs are built fresh from Tuning.live on every read, so the debug panel's
## sliders take effect immediately rather than on the next run.
##
## Fields (all applied to velocity):
##   water         -- units gained (+) or spent (-); the shared chokepoint
##   temp_impulse  -- push on core temperature's velocity
##   exertion      -- static added by physical effort, before cognitive load
##   damping       -- static actively pushed down
##   brake         -- fraction of static velocity killed outright

const FLUSH_COOLANT := &"flush_coolant"
const NEURAL_DAMPER := &"neural_damper"
const DRAW_WATER := &"draw_water"


static func available() -> Array[StringName]:
	var ids: Array[StringName] = [FLUSH_COOLANT, NEURAL_DAMPER]
	if Tuning.DRAW_WATER_ENABLED:
		ids.append(DRAW_WATER)
	return ids


static func spec(action_id: StringName) -> Dictionary:
	match action_id:
		# Pulls core temperature down. Slow, because thermal inertia is high, so
		# it must be pressed before the player feels they need it.
		FLUSH_COOLANT:
			return {
				"label": "FLUSH",
				"caption": "COOLANT",
				"water": -1,
				"temp_impulse": float(Tuning.live.flush_temp),
				"exertion": 0.005,
				"damping": 0.0,
				"brake": 0.0,
			}
		# The only thing that pushes static down, against a rest point of 100%
		# that never stops pulling. Buys time, never a cure.
		NEURAL_DAMPER:
			return {
				"label": "DAMP",
				"caption": "NEURAL",
				"water": -1,
				"temp_impulse": 0.0,
				"exertion": 0.0,
				"damping": float(Tuning.live.damper_impulse),
				"brake": Tuning.DAMPER_BRAKE,
			}
		# Physical labour, so almost entirely a HEAT cost. Its static charge is
		# only the flat cognitive load plus a token of situational stress.
		_:
			return {
				"label": "DRAW",
				"caption": "WATER",
				"water": 1,
				"temp_impulse": float(Tuning.live.draw_temp),
				"exertion": 0.005,
				"damping": 0.0,
				"brake": 0.0,
			}
