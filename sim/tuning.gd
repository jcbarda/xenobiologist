class_name Tuning
extends RefCounted
## Every balance number in the slice, in one place.
##
## The vitals are second-order: each has a value and a velocity. Two forces act
## on them.
##
##   Gravity  -- a pull toward a rest point. Core temperature's rest point is the
##               ambient heat of the planet, which is lethal; static's rest point
##               is set by core temperature, because a nervous system settles
##               where body heat says it should.
##   Momentum -- velocity persists, so nothing responds instantly. Panic
##               overshoots and takes time to bleed off; relief arrives late.
##
## This is what stops static being a bar the player can simply clear. Actions
## push velocity, never the value, so the only durable way to lower static is to
## lower core temperature and move the rest point underneath it.
##
## The derivations below record what each value was aiming at, so a change can be
## judged against its intent. They are not claims the intent is correct.

# --- Core temperature -------------------------------------------------------

const CORE_TEMP_START := 37.0
const CORE_TEMP_COLLAPSE := 41.0

## The planet is hotter than the player. Core temperature is always falling
## toward this; coolant only argues with it.
const AMBIENT_TEMP := 44.0

## Pull toward ambient. Unmitigated this walks 37 -> 41 in ~248s.
const TEMP_GRAVITY := 0.0075

## Thermal inertia. High, so temperature glides rather than snapping -- a coolant
## flush is felt over several seconds, not on the frame it is pressed.
const TEMP_FRICTION := 1.8

# --- Neural static ----------------------------------------------------------

## Stored 0..1 and displayed as a percentage. Normalised because M2's lag, drift
## and halo curves all want a 0..1 driver.
const STATIC_BLACKOUT := 1.0

## At or below this body temperature static rests at zero; at CORE_TEMP_COLLAPSE
## it rests at 1.0. Everything between interpolates. This mapping is the spine of
## the model: it is why cooling is the real treatment and the damper is not.
const STATIC_REST_FLOOR := 37.5

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
## so it is the floor no amount of dampering gets under.
static func static_rest_point(core_temperature: float) -> float:
	var span := CORE_TEMP_COLLAPSE - STATIC_REST_FLOOR
	return clampf((core_temperature - STATIC_REST_FLOOR) / span, 0.0, 1.0)
