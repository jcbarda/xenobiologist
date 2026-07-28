extends Control
## Boot node. Owns nothing yet -- the milestones hang their systems off here.

@onready var _day_counter: Label = $PhysicalCasing/DayCounterText


func _ready() -> void:
	SignalBus.day_advanced.connect(_on_day_advanced)
	_refresh_day_counter()
	# Printed so an exported browser build can be verified from the JS console.
	print("Xenobiologist boot: renderer=%s tick_hz=%s" % [
		RenderingServer.get_video_adapter_api_version(), Clock.TICK_HZ,
	])


func _on_day_advanced(_day: int) -> void:
	_refresh_day_counter()


func _refresh_day_counter() -> void:
	_day_counter.text = "DAY %d" % GameState.data.day
