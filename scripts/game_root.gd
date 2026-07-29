extends Control
## Boot node. Owns nothing gameplay-side -- it wires the panel into the scene
## tree and keeps the casing's day counter current.

@onready var _day_counter: Label = $PhysicalCasing/DayCounterText
@onready var _mode_switcher: Control = $TerminalUI/MainLayout/ModeSwitcher


var _debug: DebugOverlay


func _ready() -> void:
	SignalBus.day_advanced.connect(_on_day_advanced)
	SignalBus.debug_toggle_requested.connect(_on_debug_toggle_requested)
	_refresh_day_counter()
	_mode_switcher.add_child(TerminalPanel.new())
	_build_debug_overlay()
	# Printed so an exported browser build can be verified from the JS console.
	print("Xenobiologist boot: renderer=%s tick_hz=%s draw_water=%s" % [
		RenderingServer.get_video_adapter_api_version(),
		Clock.TICK_HZ,
		Tuning.DRAW_WATER_ENABLED,
	])


## Its own layer, above the halo so it stays readable while blooms are inverting
## everything underneath, and below the casing.
func _build_debug_overlay() -> void:
	# Above the casing. The halo overlay samples the screen texture, and anything
	# a developer needs to read while playing has to sit clear of that entirely.
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	_debug = DebugOverlay.new()
	layer.add_child(_debug)
	# Starts shown. This is a tuning build and the state dump is the point of it;
	# the DEBUG button turns it off for anyone who wants a clean screen.
	_debug.visible = true


func _on_debug_toggle_requested() -> void:
	_debug.visible = not _debug.visible


## F3 as well as the button, because the state dump is the thing you reach for
## when something on screen is already misbehaving.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			_on_debug_toggle_requested()


func _on_day_advanced(_day: int) -> void:
	_refresh_day_counter()


func _refresh_day_counter() -> void:
	_day_counter.text = "DAY %d" % GameState.data.day
