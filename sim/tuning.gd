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

## Stored 0..1 and displayed as a percentage. Normalised because M2's lag, drift
## and halo curves all want a 0..1 driver.
const STATIC_BLACKOUT := 1.0

## Static wants 100% when the body is stressed, and sheds toward zero when it is
## cool and resting. This mapping is the spine of the model -- it is why cooling
## is the real treatment, why the damper is only ever a stopgap, and why the cave
## is a refuge rather than merely a cooler place to die.
##
## It is also load-bearing against RISK-6. Tried and rejected: pinning the rest
## point at 100% unconditionally. It reads well ("static always wants to win")
## but it leaves the damper as the ONLY downward force, which makes every action's
## cognitive load permanent -- and then doing nothing outlives playing well
## (172s vs 81s, measured). Paralysis must never be the optimal strategy.
const STATIC_CALM_TEMP := 36.0
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

## The exchange rate that keeps the water treadmill honest, and the single
## easiest thing to break by accident:
##
##   (WATER_PER_DRAW / damper water cost) * (damping - COGNITIVE_LOAD)
##       must stay BELOW  (COGNITIVE_LOAD + draw exertion)
##
## Above that line, fetching water refunds more calm than it costs, the treadmill
## becomes a static engine, and any fast clicker holds a pristine interface
## forever -- which would delete the degradation M2 exists to test. Currently
## 2 x (0.12 - 0.05) = 0.14  <  0.05 + 0.14 = 0.19. Re-check it after touching
## any of those four numbers.
const WATER_PER_DRAW := 4

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
	return clampf((core_temperature - STATIC_CALM_TEMP) / span, 0.0, 1.0)
