extends Node
## Decoupled event bus.
##
## Exists so UI can listen to the sim without the sim holding references to UI
## nodes. Emitters are sim code running inside a Clock tick; listeners are
## presentation. Do not mutate GameState from a listener -- see clock.gd.
##
## The per-tick signal is NOT here. Clock owns `tick` directly, because the tick
## is the sim's heartbeat rather than a gameplay event.

## A stabilising action, an assay, a synthesis -- anything the player initiated
## that the sim has now actually applied. Carries the action id.
signal action_resolved(action_id: StringName)

## Emitted when the run's day index advances. The lid owns the transition (M5);
## this only announces it.
signal day_advanced(day: int)
