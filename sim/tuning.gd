class_name Tuning
extends RefCounted
## Every balance number in the slice, in one place.
##
## These are meant to be moved by feel, not derived. The derivations below record
## what each value was aiming at so a change can be judged against its intent --
## they are not claims that the intent is correct.

# --- Core temperature -------------------------------------------------------

const CORE_TEMP_START := 37.0
const CORE_TEMP_COLLAPSE := 41.0

## Unmitigated, this walks 37 -> 41 in ~178s. Chosen so the temperature clock and
## the static clock land together (see STATIC_HEAT_GAIN) rather than one always
## arriving first and making the other decorative.
const CORE_TEMP_RISE := 0.0225

# --- Neural static ----------------------------------------------------------

## Stored 0..1 and displayed as a percentage. Normalised because M2's lag, drift
## and halo curves all want a 0..1 driver.
const STATIC_BLACKOUT := 1.0

## Static only accrues from heat once the body is actually over-heating; below
## this the temperature clock runs alone.
const STATIC_HEAT_THRESHOLD := 37.5

## Per degree over threshold, per second. Integrated across an unmitigated
## 37 -> 41 climb this totals ~0.98 -- i.e. static arrives at blackout at almost
## exactly the moment core temperature reaches collapse.
const STATIC_HEAT_GAIN := 0.0036

## OQ-1, decided 2026-07-28: cognitive load is a flat per-action cost. Every
## action pays this regardless of what it is, so frantic clicking is
## self-punishing. Exertion is separate and lives per-action in actions.gd.
const COGNITIVE_LOAD := 0.02

# --- Water ------------------------------------------------------------------

## Water is the universal chokepoint (design-doc 4.7): every action spends it or
## fetches it, and the two stabilising actions compete for the same reserve.
const WATER_START := 10
const WATER_CAPACITY := 12

# --- Loop shape -------------------------------------------------------------

## Flip to false to cut DRAW WATER out of the loop entirely -- the action is
## dropped from the catalogue and its button never appears.
##
## true  -> treadmill. Water is renewable, so Phase 0 runs until the player
##          misjudges the exertion cost of fetching it.
## false -> countdown. A fixed canteen, allocation is the only agency, and the
##          run is always eventually fatal.
##
## This is the A/B for what Phase 0 *is*. Both readings are defensible against
## design-doc 8 and the difference is a feel judgement, not a derivable one.
const DRAW_WATER_ENABLED := true
