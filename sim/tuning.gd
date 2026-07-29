class_name Tuning
extends RefCounted
## Every balance number in the slice, in one place.
##
## The vitals are second-order: each has a value and a velocity. Two forces act
## on them.
##
##   Gravity  -- a pull toward a rest point. Core temperature's rest point is
##               whatever the PLACE is: 35C in the cave, 46C at the oasis edge,
##               75C on open surface. Static's rest point is set by body heat --
##               a stressed body drives toward total overload, a cool resting one
##               sheds it.
##   Momentum -- velocity persists, so nothing responds instantly. Panic
##               overshoots and takes time to bleed off; relief arrives late.
##
## This is what stops static being a bar the player can simply clear. Actions
## push velocity, never the value, so the only durable way to lower static is to
## lower core temperature and move the rest point underneath it.
##
## It also means the excursion budget in M4 needs no timer of its own: how long
## the player can survive somewhere simply IS that location's ambient temperature
## working against their thermal inertia.
##
## The derivations below record what each value was aiming at, so a change can be
## judged against its intent. They are not claims the intent is correct.

# --- Core temperature -------------------------------------------------------

const CORE_TEMP_START := 37.0
const CORE_TEMP_COLLAPSE := 41.0

## Ambient is a property of the PLACE, and it is what the body is dragged toward.
## Unmitigated survival time falls straight out of it: indefinite in the cave,
## ~172s at the oasis edge, ~33s on open surface.
##
## Only OASIS_EDGE is reachable in the slice -- Phase 0 happens there. The other
## two are the endpoints M4's excursions will run between, recorded here because
## they are what set the shape of the curve, not because anything uses them yet.
const AMBIENT_CAVE := 35.0
const AMBIENT_OASIS_EDGE := 46.0
const AMBIENT_OPEN_SURFACE := 75.0

## Pull toward ambient.
const TEMP_GRAVITY := 0.0075

## Thermal inertia. High, so temperature glides rather than snapping -- a coolant
## flush is felt over several seconds, not on the frame it is pressed.
const TEMP_FRICTION := 1.8

# --- Neural static ----------------------------------------------------------

## Static is the level of brain activity. 100% is everything firing at once --
## seizure. 0% is silence -- braindead. Neither end is survivable, and roughly
## 10-30% is the band a person actually functions in.
##
## Stored 0..1 and displayed as a percentage. Normalised because M2's lag, drift
## and halo curves all want a 0..1 driver.
const STATIC_SEIZURE := 1.0
const STATIC_SILENCE := 0.02

## Resting brain activity. Static settles here when the body is calm, which is
## why it is also the value a run starts at -- nobody boots at zero.
const STATIC_BASELINE := 0.15

## Static drives to 100% when the body is stressed and falls back to
## STATIC_BASELINE when it is cool and resting -- not to zero, because zero is
## death. This mapping is the spine of the model: it is why cooling is the real
## treatment, why the damper is only ever a stopgap, and why the cave is a refuge
## rather than merely a cooler place to die.
##
## CALM sits at normal body temperature, so holding the functional 10-30% band
## means holding core temperature within about half a degree of 37. That is a
## demanding target, and it is what keeps FLUSH COOLANT the constant activity.
##
## It is also load-bearing against RISK-6. Tried and rejected: pinning the rest
## point at 100% unconditionally. It reads well ("static always wants to win")
## but it leaves the damper as the ONLY downward force, which makes every action's
## cognitive load permanent -- and then doing nothing outlives playing well
## (172s vs 81s, measured). Paralysis must never be the optimal strategy.
const STATIC_CALM_TEMP := 37.0
const STATIC_STRESS_TEMP := 40.0

const STATIC_GRAVITY := 0.055
const STATIC_FRICTION := 1.1

## OQ-1, decided 2026-07-28: cognitive load is a flat per-action cost. Every
## action pays it regardless of what it is, so frantic clicking is
## self-punishing. Now applied as a velocity impulse rather than a value delta.
##
## It is also what makes the damper's brake self-limiting: braking is only worth
## the press when static is climbing faster than COGNITIVE_LOAD / DAMPER_BRAKE.
const COGNITIVE_LOAD := 0.05

## Fraction of static velocity a damper removes. A brake cannot push static below
## its rest point, so it can never be run as an engine.
const DAMPER_BRAKE := 0.60

# --- Water ------------------------------------------------------------------

## Water is the universal chokepoint (design-doc 4.7): every action spends it or
## fetches it, and the stabilisers compete for the same reserve.
const WATER_START := 10
const WATER_CAPACITY := 12

## What stops the water treadmill becoming a "static engine" -- a loop that
## refunds more calm than it costs, letting a fast clicker hold a clean interface
## forever and deleting the degradation M2 exists to test.
##
## This guard MOVED when DRAW WATER became physical labour. It used to be
## arithmetic: draw exertion had to exceed what the water bought back in damping.
## Now that drawing is thermally expensive and nearly free in static, that
## inequality no longer binds -- the guard is physical instead. Running the loop
## fast enough to suppress static means drawing fast enough to cook yourself, and
## the flushes needed to survive that cost cognitive load of their own.
##
## Verified adversarially rather than assumed: a policy built specifically to run
## the engine dies either way -- seizure at 175s in the cave (cognitive load of
## ~1500 actions), heat at 157s at the oasis edge.
##
## So the number to watch when tuning is DRAW_WATER's temp_impulse. Drop it far
## and the engine reopens.
const WATER_PER_DRAW := 6

# --- Loop shape -------------------------------------------------------------

## Flip to false to cut DRAW WATER out of the loop entirely -- the action is
## dropped from the catalogue and its button never appears.
##
## true  -> treadmill. Water is renewable, so Phase 0 runs until the player
##          misjudges the exertion cost of fetching it.
## false -> countdown. A fixed canteen, allocation is the only agency, and the
##          run is always eventually fatal.
const DRAW_WATER_ENABLED := true


## Where static settles for a given body temperature. Gravity pulls toward this,
## so it is the level no amount of dampering gets under.
static func static_rest_point(core_temperature: float) -> float:
	var span := STATIC_STRESS_TEMP - STATIC_CALM_TEMP
	var stress := clampf((core_temperature - STATIC_CALM_TEMP) / span, 0.0, 1.0)
	return lerpf(STATIC_BASELINE, 1.0, stress)
