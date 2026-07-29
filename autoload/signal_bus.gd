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

## Developer state dump asked to flip. Carries no state deliberately: the button
## and the overlay disagreeing about who is authoritative is what made the
## earlier toggle-mode version look broken.
signal debug_toggle_requested

## The sim has halted because the player went under. `cause` is the vital that
## gave out, so the panel can name it -- pairing symptom with cause is RISK-1's
## mitigation and matters more here than anywhere else. M5 slams the lid on this.
signal blackout(cause: String)
