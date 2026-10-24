class_name DashLine
extends Control
## Đường kẻ ngang mờ, nét đứt — ngăn cách các dòng trong danh sách (Battle...).

var dash := 4.0
var gap := 3.0

func _init() -> void:
	custom_minimum_size = Vector2(0, 3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var col := UiTheme.ink_color()
	col.a = 0.28
	var y := size.y * 0.5
	var x := 2.0
	while x < size.x - 2.0:
		draw_line(Vector2(x, y), Vector2(minf(x + dash, size.x - 2.0), y), col, 1.0)
		x += dash + gap
