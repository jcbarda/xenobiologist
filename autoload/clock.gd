extends Node
## Fixed-step simulation clock. ~10 Hz, decoupled from framerate.
##
## The one architectural inviolable: no game state mutates outside a tick. The
## sim advances only by replaying ticks, so a run is fully reconstructible from
## its state object plus a tick count -- which is what turns offline progress
## into a later feature rather than a later rewrite.
##
## Presentation (halo, input lag, drift) reads state every frame and is free to
## interpolate; it just may not write.

const TICK_HZ := 10.0
const TICK_SECONDS := 1.0 / TICK_HZ

## Ceiling on ticks replayed in a single frame. A backgrounded browser tab hands
## back an enormous delta on return; without this the catch-up loop would stall
## the frame it is trying to recover. Offline progress will later replay the gap
## deliberately in batches rather than inside _process.
const MAX_TICKS_PER_FRAME := 60

## Fires once per simulation step. `sim_delta` is always TICK_SECONDS -- it is
## passed so sim code reads its own timebase instead of closing over the constant.
signal tick(sim_delta: float)

var _accumulator := 0.0

## Development control. Halts the simulation without touching state, so the debug
## panel can be read at leisure and sliders moved against a frozen run.
var paused := false


func _process(delta: float) -> void:
	if paused:
		# Drop the accumulated time rather than banking it, or unpausing would
		# fast-forward through everything that "happened" while stopped.
		_accumulator = 0.0
		return
	_accumulator += delta
	var budget := MAX_TICKS_PER_FRAME
	while _accumulator >= TICK_SECONDS and budget > 0:
		_accumulator -= TICK_SECONDS
		_advance_one_tick()
		budget -= 1
	if budget == 0:
		# Drop the unpayable remainder rather than compounding the debt into the
		# next frame. Real gap recovery belongs to offline progress, not here.
		_accumulator = 0.0


## Clock deliberately touches no state of its own. It only says "a step happened";
## GameState owns every write, including the tick counter.
func _advance_one_tick() -> void:
	tick.emit(TICK_SECONDS)
