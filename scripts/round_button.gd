class_name RoundButton
extends Button
## A circular key on the pressure panel.
##
## The hit area is circular too, not just the paint. That matters more here than
## it would anywhere else: tremor makes the player miss on purpose, so the shape
## they are aiming at has to be the shape that actually catches the press. A
## round button with a square hit box would forgive misses the player could see
## themselves make.

const DIAMETER := 104.0

var _radius := DIAMETER * 0.5


func _init() -> void:
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	size = Vector2(DIAMETER, DIAMETER)
	add_theme_font_size_override("font_size", 17)
	_style(&"normal", Color("1c2230"), Color("3d4a63"))
	_style(&"hover", Color("242c3d"), Color("5a6b8c"))
	_style(&"pressed", Color("11151d"), Color("7c8db0"))
	_style(&"disabled", Color("16191f"), Color("2a2f39"))


func _style(state: StringName, fill: Color, border: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(_radius))
	add_theme_stylebox_override(state, box)


func _has_point(point: Vector2) -> bool:
	return point.distance_to(Vector2(_radius, _radius)) <= _radius
