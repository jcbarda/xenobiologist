class_name Actions
extends RefCounted
## The player's verbs, as data.
##
## Activity is physical, so an action moves core temperature and adds exertion
## static on top of the flat cognitive cost every action pays. That is what makes
## fetching water a real decision rather than free upkeep: hauling it in the heat
## costs you the very thing you are hauling it to fix.
##
## Fields:
##   water     -- units gained (+) or spent (-); the shared chokepoint
##   temp      -- core temperature delta in degrees C
##   exertion  -- static added by physical effort, before COGNITIVE_LOAD
##   damping   -- static actively removed; the action's therapeutic effect

const FLUSH_COOLANT := &"flush_coolant"
const NEURAL_DAMPER := &"neural_damper"
const DRAW_WATER := &"draw_water"

const CATALOGUE := {
	# Cheap on the body, expensive on the canteen. Buys temperature headroom,
	# which indirectly slows future static -- but cannot touch static already
	# banked.
	FLUSH_COOLANT: {
		"label": "FLUSH COOLANT",
		"water": -2,
		"temp": -1.5,
		"exertion": 0.01,
		"damping": 0.0,
	},
	# The only way to claw back accumulated static, and the cheaper of the two
	# stabilisers -- so the trap is dampering through a crisis while core
	# temperature keeps climbing and the canteen empties.
	NEURAL_DAMPER: {
		"label": "NEURAL DAMPER",
		"water": -1,
		"temp": 0.0,
		"exertion": 0.0,
		"damping": 0.15,
	},
	# Renews the chokepoint, but it is the one genuinely strenuous act available:
	# it heats you and it costs the most static of anything here.
	DRAW_WATER: {
		"label": "DRAW WATER",
		"water": 4,
		"temp": 0.4,
		"exertion": 0.05,
		"damping": 0.0,
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
