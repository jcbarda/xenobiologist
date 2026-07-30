class_name Tuning
extends RefCounted
## Every balance number in the slice, in one place.
##
## The vitals are Newtonian: a value, a velocity, and a **constant acceleration**
## toward the steady state. Velocity persists. Left alone a vital does not drift
## at a fixed rate -- it picks up speed, so neglect gets worse the longer it runs.
##
## Corrected 2026-07-29. The previous version applied an acceleration proportional
## to the DISTANCE from the steady state and bled velocity off with a friction
## term -- a damped spring, not gravity. Two wrong behaviours followed: vitals
## *slowed down* as they approached the end instead of speeding up, and setting
## acceleration to zero brought everything to a halt instead of coasting.
##
## There is deliberately NO friction. Zero acceleration means constant velocity,
## because that is what momentum means. Actions are impulses: they change
## velocity, never the value, and their effect therefore persists until something
## cancels it.
##
## UNITS. Stored in base units (per second); displayed per minute, which is where
## the numbers become human-readable.
##
##   core temperature   degC        velocity degC/min   accel degC/min^2
##   neural static      microvolts  velocity uV/min     accel uV/min^2
##   water              decilitres
##
## Static is an EEG-style cortical amplitude: ~15 uV at rest, 10-30 uV is the
## functional band, 100 uV is a seizure-grade discharge, 2 uV is silence.

## Seconds per minute -- the conversion between stored and displayed units.
const PER_MIN := 60.0
const PER_MIN_SQ := 3600.0

# --- Core temperature (degC) ------------------------------------------------

const CORE_TEMP_START := 37.0
const CORE_TEMP_COLLAPSE := 41.0

## Temperature acceleration is a property of the PLACE, not a global -- see
## PLACES below. With constant acceleration the ambient value only sets the
## direction and where the body settles; it no longer sets the rate, so each
## location has to state its own. Without that, open surface cooked you at
## exactly the same speed as the oasis.

# --- Neural static (uV) -----------------------------------------------------

## Brain activity. Everything firing at once is a seizure; nothing firing is
## silence. Both are fatal, and 10-30 uV is the only band a person functions in.
const STATIC_SEIZURE := 100.0
const STATIC_SILENCE := 2.0
const STATIC_BASELINE := 15.0

## Static's steady state is ALWAYS seizure -- the condition is chronic signal
## flooding and it always wins if left alone. A place changes how hard it pulls,
## never where it pulls to.

## LIVE, uV/s. Flat per-action cost (OQ-1), so frantic clicking is
## self-punishing. Paid on EVERY press, including the draws that fund the others.
## Displayed as 0.24 uV/min.
const COGNITIVE_LOAD := 0.004

## Fraction of static velocity a damper cancels outright, on top of its impulse.
## This is the one place damping is wanted: a brake the player chooses to apply,
## rather than friction the world applies for free.
const DAMPER_BRAKE := 0.35

# --- Places -----------------------------------------------------------------

## Ambient heat, and how hard static is dragged toward seizure. Only OASIS_EDGE
## is reachable in the slice.
##
## A location can only kill by HEAT if its ambient exceeds CORE_TEMP_COLLAPSE.
## Below that, temperature arrives at ambient and settles -- which is the
## definition of shelter, and why the cave is survivable.
## `temperature` is where the body settles; `temp_accel` is how fast it is
## dragged there. Idle lifetimes that fall out of these:
##   cave          cools to 35 degC and stops; static seizes at ~10 min
##   oasis edge    heat collapse at ~250 s
##   open surface  heat collapse at ~82 s
const PLACES := {
	&"cave": {
		"label": "CAVE",
		"temperature": 35.0, "temp_accel": 0.00008,
		"static_accel": 0.00045,
	},
	&"oasis_edge": {
		"label": "OASIS EDGE",
		"temperature": 46.0, "temp_accel": 0.00013,
		"static_accel": 0.00140,
	},
	&"open_surface": {
		"label": "OPEN SURFACE",
		"temperature": 60.0, "temp_accel": 0.00120,
		"static_accel": 0.00420,
	},
}

const STARTING_PLACE := &"oasis_edge"

# --- Water (dL) -------------------------------------------------------------

## A small, legible economy: one press draws one decilitre, everything else
## spends one. Roughly half of all clicking is therefore logistics, which is the
## biggest single driver of how busy the game feels.
const WATER_START := 4
const WATER_CAPACITY := 8

# --- Action impulses (LIVE) -------------------------------------------------
#
# Impulses change VELOCITY, so they carry the velocity units.

const FLUSH_TEMP_IMPULSE := -0.0045   # degC/s  (-0.27 degC/min)
const DRAW_TEMP_IMPULSE := 0.0010     # degC/s  (+0.06 degC/min)
const DAMPER_IMPULSE := 0.0280        # uV/s    (-1.68 uV/min)

# --- Interface degradation --------------------------------------------------
#
# One symptom per extreme; the whole gamut at once read as noise rather than as
# a body. Both are motor, never perceptual -- no hallucinations, no false
# readings, the instruments never lie.

const HYPER_ONSET := 30.0   # uV
const HYPO_ONSET := 10.0    # uV

## Hyper: pressing too hard.
const HALO_RADIUS_PIXELS := 68.0
const HALO_HOLD_SECONDS_MIN := 0.30
const HALO_HOLD_SECONDS_MAX := 2.2
const SLIDE_DISTANCE_PIXELS := 46.0
const HALO_MAX_ACTIVE := 8

## Hypo: slow, and too light to register.
const MOTOR_LAG_MAX_SECONDS := 0.80
const LIGHT_PRESS_MISS_CHANCE := 0.55
const FADED_BUTTON_ALPHA := 0.28

# --- Loop shape -------------------------------------------------------------

const DRAW_WATER_ENABLED := true

# --- Live, editable while running -------------------------------------------

static var live := {
	"temp_accel_scale": 1.0,
	"static_accel_scale": 1.0,
	"cognitive_load": COGNITIVE_LOAD,
	"flush_temp": FLUSH_TEMP_IMPULSE,
	"damper_impulse": DAMPER_IMPULSE,
	"draw_temp": DRAW_TEMP_IMPULSE,
}

## Drives the debug panel. `scale` converts stored units to displayed ones.
const SLIDERS := [
	{
		"key": "temp_accel_scale", "label": "TEMP accel", "unit": "x",
		"scale": 1.0, "min": 0.0, "max": 5.0, "step": 0.1,
	},
	{
		"key": "static_accel_scale", "label": "STATIC accel", "unit": "x",
		"scale": 1.0, "min": 0.0, "max": 5.0, "step": 0.1,
	},
	{
		"key": "cognitive_load", "label": "cognitive load", "unit": "uV/min",
		"scale": PER_MIN, "min": 0.0, "max": 0.02, "step": 0.0005,
	},
	{
		"key": "flush_temp", "label": "FLUSH", "unit": "degC/min",
		"scale": PER_MIN, "min": -0.020, "max": 0.0, "step": 0.0002,
	},
	{
		"key": "damper_impulse", "label": "DAMP", "unit": "uV/min",
		"scale": PER_MIN, "min": 0.0, "max": 0.12, "step": 0.002,
	},
	{
		"key": "draw_temp", "label": "DRAW heat", "unit": "degC/min",
		"scale": PER_MIN, "min": 0.0, "max": 0.008, "step": 0.0002,
	},
]


static func restore_defaults() -> void:
	live = {
		"temp_accel_scale": 1.0,
		"static_accel_scale": 1.0,
		"cognitive_load": COGNITIVE_LOAD,
		"flush_temp": FLUSH_TEMP_IMPULSE,
		"damper_impulse": DAMPER_IMPULSE,
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
