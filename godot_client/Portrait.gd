class_name Portrait
extends Control
## Ảnh nhân vật vẽ procedural (chưa có sprite thật). Dùng trong Character panel.

var shirt := Color(0.15, 0.3, 0.85)
var t := 0.0

func _process(dt):
	t += dt
	queue_redraw()

func _draw():
	var c = size / 2.0
	# nền
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.14, 0.2))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 0.45, 0.55), false, 2.0)
	var s = min(size.x, size.y) / 96.0  # scale theo khung
	var bob = sin(t * 2.0) * 1.5 * s
	# chân
	draw_line(c + Vector2(-8, 18) * s + Vector2(0, bob), c + Vector2(-8, 34) * s, Color(0.3, 0.2, 0.15), 7.0 * s)
	draw_line(c + Vector2(8, 18) * s + Vector2(0, -bob), c + Vector2(8, 34) * s, Color(0.3, 0.2, 0.15), 7.0 * s)
	# thân
	draw_rect(Rect2(c + Vector2(-13, -6) * s, Vector2(26, 26) * s), shirt)
	draw_rect(Rect2(c + Vector2(-13, -6) * s, Vector2(26, 26) * s), Color(0, 0, 0, 0.4), false, 2.0)
	# tay
	draw_line(c + Vector2(-15, 0) * s, c + Vector2(-19, 14) * s, shirt, 6.0 * s)
	draw_line(c + Vector2(15, 0) * s, c + Vector2(19, 14) * s, shirt, 6.0 * s)
	# đầu
	draw_circle(c + Vector2(0, -18) * s, 11.0 * s, Color(0.95, 0.8, 0.65))
	draw_circle(c + Vector2(-4, -19) * s, 1.6 * s, Color(0.1, 0.1, 0.1))
	draw_circle(c + Vector2(4, -19) * s, 1.6 * s, Color(0.1, 0.1, 0.1))
	# tóc
	draw_arc(c + Vector2(0, -19) * s, 11.0 * s, PI, TAU, 12, Color(0.35, 0.22, 0.12), 4.0 * s)
