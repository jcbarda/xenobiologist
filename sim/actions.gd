class_name Actions
extends RefCounted
## The player's verbs, as data.
##
## Actions push velocity, never a value. Nothing lands on the frame it is
## pressed -- the vitals carry momentum, so every action is a bet on where things
## will be in a few seconds rather than a correction to where they are now.
##
## Activity is physical, so an action moves core temperature and adds exertion on
## top of the flat cognitive load every action pays. That is what makes fetching
## water a real decision rather than free upkeep: hauling it in the heat costs
## you the very thing you are hauling it to fix.
##
## Fields (all applied to velocity):
##   water         -- units gained (+) or spent (-); the shared chokepoint
##   temp_impulse  -- push on core temperature's velocity
##   exertion      -- static added by physical effort, before COGNITIVE_LOAD
##   damping       -- static actively pushed down; bounded by Tuning's exchange rate
##   brake         -- fraction of static velocity killed outright

const FLUSH_COOLANT := &"flush_coolant"
const NEURAL_DAMPER := &"neural_damper"
const DRAW_WATER := &"draw_water"

const CATALOGUE := {
	# The only durable treatment. It does not touch static directly -- it drags
	# core temperature down, which lowers static's rest point, and gravity does
	# the rest. Slow, because thermal inertia is high, so it must be pressed
	# before the player feels they need it.
	FLUSH_COOLANT: {
		"label": "FLUSH COOLANT",
		"water": -2,
		"temp_impulse": -0.55,
		"exertion": 0.02,
		"damping": 0.0,
		"brake": 0.0,
	},
	# The emergency brake. Kills static's momentum and shoves it down a little,
	# but cannot get beneath the rest point core temperature dictates -- so it
	# buys seconds, never a cure. Leaning on it instead of cooling is the trap.
	NEURAL_DAMPER: {
		"label": "NEURAL DAMPER",
		"water": -2,
		"temp_impulse": 0.0,
		"exertion": 0.0,
		"damping": 0.12,
		"brake": Tuning.DAMPER_BRAKE,
	},
	# Renews the chokepoint, and is the one genuinely strenuous act available: it
	# heats you and costs the most static of anything here. Its exertion is what
	# keeps the treadmill from becoming a static engine.
	DRAW_WATER: {
		"label": "DRAW WATER",
		"water": Tuning.WATER_PER_DRAW,
		"temp_impulse": 0.12,
		"exertion": 0.14,
		"damping": 0.0,
		"brake": 0.0,
	},
}


## The verbs actually available this run. DRAW WATER drops out entirely when
## disabled, rather than being shown greyed out -- a countdown run should not
## advertise a treadmill it does not have.
static func available() -> Array[StringName]:
	var ids: Array[StringName] = [FLUSH_COOLANT, NEURAL_DAMPER]
	if Tuning.DRAW_WATER_ENABLED:
		ids.append(DRAW_WATER)
	return ids


static func spec(action_id: StringName) -> Dictionary:
	return CATALOGUE[action_id]
