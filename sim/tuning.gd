class_name Tuning
extends RefCounted
## Every balance number in the slice, in one place.
##
## The vitals are second-order: each has a value and a velocity, acted on by
## gravity (a pull toward a rest point) and momentum (velocity persists, so
## nothing lands on the frame it is pressed).
##
## **Core temperature and neural static are independent.** Each is pulled toward
## a rest point fixed by the PLACE the player is standing in, and neither reads
## the other. Two separate control loops with one tool each: coolant for heat,
## the damper for static. An earlier build derived static's rest point from body
## heat; it made every number interlock with every other and was much harder to
## hold, reason about, or tune.
##
## Consequence worth remembering: **a location can only kill by heat if its
## ambient exceeds CORE_TEMP_COLLAPSE.** Below that, temperature simply converges
## to ambient and sits there. The cave is survivable indefinitely for exactly
## this reason, and it is not an accident -- it is the definition of shelter.
##
## Tuned for a person to hold, not a bot to optimise: a human-paced policy
## (half-second reactions, threshold responses) holds the functional band at
## about one press every 3.7 seconds, and neglect kills in ~4 minutes.

# --- Core temperature -------------------------------------------------------

const CORE_TEMP_START := 37.0
const CORE_TEMP_COLLAPSE := 41.0

## Pull toward ambient, and thermal inertia. Friction is high, so temperature
## glides -- a flush is felt over seconds, not on the frame it is pressed.
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

const STATIC_GRAVITY := 0.014
const STATIC_FRICTION := 1.1

## OQ-1: cognitive load is a flat per-action cost, so frantic clicking is
## self-punishing. Small, because it is paid on EVERY press -- including the
## draws that fund the other presses -- and a large value made deliberate play
## lose to sitting still.
const COGNITIVE_LOAD := 0.020

## Fraction of static velocity a damper removes, on top of its push.
const DAMPER_BRAKE := 0.50

# --- Places -----------------------------------------------------------------

## Each location fixes BOTH rest points. Only OASIS_EDGE is reachable in the
## slice; the other two are the endpoints M4's excursions will run between,
## recorded because they set the shape of the curve.
##
## Static ambient is what the place does to a nervous system, independent of
## heat: the cave is restful and sits inside the functional band, the oasis edge
## sits just above it, open surface is punishing.
const PLACES := {
	&"cave": {"label": "CAVE", "temperature": 35.0, "static": 0.15},
	&"oasis_edge": {"label": "OASIS EDGE", "temperature": 46.0, "static": 0.38},
	&"open_surface": {"label": "OPEN SURFACE", "temperature": 60.0, "static": 0.75},
}

const STARTING_PLACE := &"oasis_edge"

# --- Water ------------------------------------------------------------------

## Water is the universal chokepoint (design-doc 4.7). Deliberately a small,
## legible economy: one press draws one unit, and every other action spends one.
##
## That means roughly half of all clicking is logistics -- each useful press
## needs a second press to pay for it, and that draw costs cognitive load and
## heat of its own. It is the single biggest driver of how busy the game feels.
const WATER_START := 4
const WATER_CAPACITY := 6

# --- Interface degradation (M2) ---------------------------------------------

## Degradation begins where the functional band ends. Inside 10-30% the player
## has full control; leaving the band is what costs them their hands. Tying the
## onset to the band means the gauge is already explaining the symptom at the
## moment control starts slipping.
const DEGRADATION_ONSET := 0.30

## Strain, not confusion. The command is late leaving the body -- never wrong,
## never dropped. See design-doc 4.1: no hallucinations, no false readings.
const MOTOR_LAG_MAX_SECONDS := 0.65

## Tremor. The buttons genuinely move, so a miss is real geometry rather than a
## rolled failure. Erratic by design: it holds still, then jumps.
const TREMOR_MAX_PIXELS := 30.0
const TREMOR_DWELL_MIN := 0.05
const TREMOR_DWELL_MAX := 0.30

## Contact bloom: pressing too hard leaves a negative halo burned into the
## pressure layer, and the panel will not read a second contact inside it until
## it clears. Mashing one button blinds the spot you keep hitting.
const HALO_RADIUS_PIXELS := 68.0
const HALO_HOLD_SECONDS_MIN := 0.30
const HALO_HOLD_SECONDS_MAX := 2.2

## A failing hand does not land once, cleanly. At high degradation a single
## press also drags (a slide) and puts down stray contacts elsewhere -- which
## bloom over whatever was behind them.
const SLIDE_CHANCE := 0.9
const SLIDE_DISTANCE_PIXELS := 90.0
const STRAY_CONTACT_CHANCE := 0.7

const HALO_MAX_ACTIVE := 12

# --- Loop shape -------------------------------------------------------------

## Flip to false to cut DRAW WATER out of the loop entirely -- the action leaves
## the catalogue and its button never appears.
##
## true  -> treadmill. Water is renewable, so Phase 0 runs until the player
##          misjudges the heat cost of fetching it.
## false -> countdown. A fixed canteen, allocation is the only agency, and the
##          run is always eventually fatal.
const DRAW_WATER_ENABLED := true


## 0 inside the functional band, ramping to 1 at seizure. Every degradation reads
## from this, so they worsen together and share one visible cause.
static func degradation(neural_static: float) -> float:
	var span := STATIC_SEIZURE - DEGRADATION_ONSET
	return clampf((neural_static - DEGRADATION_ONSET) / span, 0.0, 1.0)


static func place(place_id: StringName) -> Dictionary:
	return PLACES[place_id]
