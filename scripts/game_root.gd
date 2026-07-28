extends Control
## Boot node. Owns nothing gameplay-side -- it wires the panel into the scene
## tree and keeps the casing's day counter current.

@onready var _day_counter: Label = $PhysicalCasing/DayCounterText
@onready var _mode_switcher: Control = $TerminalUI/MainLayout/ModeSwitcher


func _ready() -> void:
	SignalBus.day_advanced.connect(_on_day_advanced)
	_refresh_day_counter()
	_mode_switcher.add_child(TerminalPanel.new())
	# Printed so an exported browser build can be verified from the JS console.
	print("Xenobiologist boot: renderer=%s tick_hz=%s draw_water=%s" % [
		RenderingServer.get_video_adapter_api_version(),
		Clock.TICK_HZ,
		Tuning.DRAW_WATER_ENABLED,
	])


func _on_day_advanced(_day: int) -> void:
	_refresh_day_counter()


func _refresh_day_counter() -> void:
	_day_counter.text = "DAY %d" % GameState.data.day
