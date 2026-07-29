class_name Tuning
extends RefCounted
## Every balance number in the slice, in one place.
##
## The vitals are second-order: each has a value and a velocity, acted on by
## gravity (a pull toward a rest point) and momentum (velocity persists, so
## nothing lands on the frame it is pressed).
##
## **Core temperature and neural static are independent.** Each is pulled toward
## its own rest point and neither reads the other -- two control loops with one
## tool each: coolant for heat, the damper for static.
##
## **Static's rest point is always 100%.** The character's condition is chronic
## signal flooding; left alone it always wins. What a PLACE changes is how hard
## it pulls, not where it is pulling to -- the cave drags slowly, open surface
## drags fast. So shelter buys time rather than safety, and the M5 lid-close
## becomes the only thing that genuinely resets a day.
##
## Tuned for a person to hold, not a bot to optimise: a human-paced policy
## (half-second reactions, threshold responses) holds the functional band at
## about one press every 3 seconds, and neglect kills in ~4 minutes.
##
## Numbers marked LIVE below can be moved while the game runs, from the debug
## panel. The consts are the documented defaults; `live` is what the sim reads.

# --- Core temperature -------------------------------------------------------

const CORE_TEMP_START := 37.0
const CORE_TEMP_COLLAPSE := 41.0

## LIVE. Pull toward ambient. Friction is thermal inertia, so temperature glides.
const TEMP_GRAVITY := 0.0050
const TEMP_FRICTION := 1.8

# --- Neural static ----------------------------------------------------------

## Static is the level of brain activity. 100% is everything firing at once --
## seizure. 0% is silence -- braindead. Roughly 10-30% is the band a person
## actually functions in, and it is the narrowest safe range in the game.
const STATIC_SEIZURE := 1.0
const STATIC_SILENCE := 0.02

## Resting brain activity, and where a run starts. Nobody boots at zero.
const STATIC_BASELINE := 0.15

const STATIC_FRICTION := 1.1

## LIVE. Flat per-action cost (OQ-1), so frantic clicking is self-punishing.
## Small, because it is paid on EVERY press including the draws that fund the
## others.
const COGNITIVE_LOAD := 0.020

## Fraction of static velocity a damper removes, on top of its push.
const DAMPER_BRAKE := 0.50

# --- Places -----------------------------------------------------------------

## Each place sets ambient heat and how hard static is dragged toward 100%.
## Only OASIS_EDGE is reachable in the slice.
##
## A location can only kill by HEAT if its ambient exceeds CORE_TEMP_COLLAPSE.
## Below that, temperature converges to ambient and sits there -- which is the
## definition of shelter, and why the cave is survivable for a long time.
const PLACES := {
	&"cave": {"label": "CAVE", "temperature": 35.0, "static_gravity": 0.0020},
	&"oasis_edge": {"label": "OASIS EDGE", "temperature": 46.0, "static_gravity": 0.0060},
	&"open_surface": {"label": "OPEN SURFACE", "temperature": 60.0, "static_gravity": 0.0200},
}

const STARTING_PLACE := &"oasis_edge"

# --- Water ------------------------------------------------------------------

## A small, legible economy: one press draws one unit, everything else spends
## one. Roughly half of all clicking is therefore logistics, which is the
## biggest single driver of how busy the game feels.
const WATER_START := 4
const WATER_CAPACITY := 8

# --- Action deltas (LIVE) ---------------------------------------------------

const FLUSH_TEMP_IMPULSE := -0.60
const DAMPER_DAMPING := 0.16
const DRAW_TEMP_IMPULSE := 0.08

# --- Interface degradation --------------------------------------------------
#
# One symptom per extreme, because the whole gamut at once read as noise rather
# than as a body. Both are motor, never perceptual -- no hallucinations, no false
# readings, the instruments never lie (design-doc 4.1).
#
#   TOO MUCH brain activity -> you press too HARD. Contact blooms burn into the
#     pressure layer and refuse the next press inside them.
#   TOO LITTLE               -> you are slow and press too LIGHTLY. Commands lag
#     leaving the body, and some contacts are too faint to register at all.
#
# Cut after playtesting: tremor (jumping buttons did not meaningfully defeat
# aiming unless the buttons were too small to be usable) and stray multi-finger
# contacts (read as a visual glitch rather than as a hand).

## Where each side's degradation begins -- the edges of the functional band.
const HYPER_ONSET := 0.30
const HYPO_ONSET := 0.10

## Hyper: pressing too hard.
const HALO_RADIUS_PIXELS := 68.0
const HALO_HOLD_SECONDS_MIN := 0.30
const HALO_HOLD_SECONDS_MAX := 2.2
## The contact lands off where it was aimed, as the finger drags before settling.
const SLIDE_DISTANCE_PIXELS := 46.0
const HALO_MAX_ACTIVE := 8

## Hypo: slow, and too light to register.
const MOTOR_LAG_MAX_SECONDS := 0.80
const LIGHT_PRESS_MISS_CHANCE := 0.55
## Buttons fade as contact weakens, so the player can see the press failing
## before it fails -- pairing symptom with cause, per RISK-1.
const FADED_BUTTON_ALPHA := 0.28

# --- Loop shape -------------------------------------------------------------

## Flip to false to cut DRAW WATER out of the loop entirely.
const DRAW_WATER_ENABLED := true

# --- Live, editable while running -------------------------------------------

static var live := {
	"temp_gravity": TEMP_GRAVITY,
	"static_gravity_scale": 1.0,
	"cognitive_load": COGNITIVE_LOAD,
	"flush_temp": FLUSH_TEMP_IMPULSE,
	"damper_damping": DAMPER_DAMPING,
	"draw_temp": DRAW_TEMP_IMPULSE,
}

## Drives the debug panel's sliders.
const SLIDERS := [
	{"key": "temp_gravity", "label": "TEMP accel", "min": 0.0, "max": 0.020, "step": 0.0005},
	{"key": "static_gravity_scale", "label": "STATIC accel x", "min": 0.0, "max": 5.0, "step": 0.1},
	{"key": "cognitive_load", "label": "cognitive load", "min": 0.0, "max": 0.08, "step": 0.002},
	{"key": "flush_temp", "label": "FLUSH cooling", "min": -1.5, "max": 0.0, "step": 0.05},
	{"key": "damper_damping", "label": "DAMP strength", "min": 0.0, "max": 0.40, "step": 0.01},
	{"key": "draw_temp", "label": "DRAW heating", "min": 0.0, "max": 0.60, "step": 0.02},
]


static func restore_defaults() -> void:
	live = {
		"temp_gravity": TEMP_GRAVITY,
		"static_gravity_scale": 1.0,
		"cognitive_load": COGNITIVE_LOAD,
		"flush_temp": FLUSH_TEMP_IMPULSE,
		"damper_damping": DAMPER_DAMPING,
		"draw_temp": DRAW_TEMP_IMPULSE,
	}


static func place(place_id: StringName) -> Dictionary:
	return PLACES[place_id]


## 0 inside the functional band, 1 at seizure. Drives the contact bloom.
static func hyper_degradation(neural_static: float) -> float:
	return clampf(
		(neural_static - HYPER_ONSET) / (STATIC_SEIZURE - HYPER_ONSET), 0.0, 1.0
	)


## 0 inside the functional band, 1 at silence. Drives lag and light presses.
static func hypo_degradation(neural_static: float) -> float:
	return clampf(
		(HYPO_ONSET - neural_static) / (HYPO_ONSET - STATIC_SILENCE), 0.0, 1.0
	)
