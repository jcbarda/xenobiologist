extends Node
## The single serialisable state object.
##
## Everything the sim knows lives in `data`. It holds only JSON-round-trippable
## values -- no nodes, no object references, no Resources. That is what lets the
## whole run be saved, reloaded, and advanced by replaying N ticks, which is how
## offline progress stays a later feature instead of a later rewrite.
##
## Nothing may write to `data` outside a Clock tick.

## Bumped whenever the shape of `data` changes in a way old saves cannot satisfy.
const SCHEMA_VERSION := 1

var data: Dictionary = {}


func _ready() -> void:
	reset()


## Returns a fresh run. The vitals below are placeholders with no behaviour
## attached yet -- M1 defines their rates and the two stabilising actions.
func reset() -> void:
	data = {
		"schema_version": SCHEMA_VERSION,
		"ticks_elapsed": 0,
		"day": 1,
		"core_temperature": 37.0,
		"hydration": 1.0,
		"neural_static": 0.0,
	}


func to_json() -> String:
	return JSON.stringify(data)


## Returns false and leaves state untouched if the payload is unreadable or was
## written by a schema this build cannot interpret.
func from_json(json_text: String) -> bool:
	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameState: save payload is not a dictionary; ignoring.")
		return false
	var incoming: Dictionary = parsed
	if incoming.get("schema_version") != SCHEMA_VERSION:
		push_warning("GameState: save schema %s != %s; ignoring." % [
			incoming.get("schema_version"), SCHEMA_VERSION,
		])
		return false
	data = incoming
	return true
