class_name PressureHaloOverlay
extends ColorRect
## Feeds the live contact blooms to the halo shader.
##
## Presentation only: it reads GameState.data.halos every frame and never writes.
## The blooms themselves are sim state, because they gate input -- a mark on the
## glass that refuses a press is a rule, not a decoration.

const _SHADER := preload("res://shaders/pressure_halo.gdshader")

var _halo_data: PackedVector4Array


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(1, 1, 1, 1)
	var mat := ShaderMaterial.new()
	mat.shader = _SHADER
	material = mat
	_halo_data.resize(Tuning.HALO_MAX_ACTIVE)


func _process(_delta: float) -> void:
	var viewport := get_viewport_rect().size
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		return

	for i in Tuning.HALO_MAX_ACTIVE:
		_halo_data[i] = Vector4.ZERO

	var halos: Array = GameState.data.halos
	var count: int = mini(halos.size(), Tuning.HALO_MAX_ACTIVE)
	for i in count:
		var halo: Dictionary = halos[i]
		# Fade as the bloom clears, so the dead zone visibly shrinks in
		# confidence rather than vanishing between one frame and the next.
		var remaining: float = float(halo.ticks) / float(halo.total)
		_halo_data[i] = Vector4(
			halo.x / viewport.x,
			halo.y / viewport.y,
			halo.radius / viewport.y,
			clampf(remaining, 0.0, 1.0),
		)

	material.set_shader_parameter("halos", _halo_data)
	material.set_shader_parameter("aspect", Vector2(viewport.x / viewport.y, 1.0))
