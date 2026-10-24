class_name Portrait
extends Control
## Ảnh nhân vật vẽ procedural (chưa có sprite thật). Dùng trong Character panel.

var shirt := Color(0.15, 0.3, 0.85)
var t := 0.0
var bare := false   # true: không vẽ nền/viền vuông (dùng làm hero đứng trong panel Character)
var icon_tex: Texture2D = null   # icon nghề (<nghề>_icon.png) cho avatar tròn; null = hình vẽ tạm
var circle := false   # true: avatar tròn kiểu bán thân (viền vàng kem), dùng ở khối HP trên-trái

func _process(dt):
	t += dt
	queue_redraw()

func _draw_circle_bust() -> void:
	var c := size / 2.0
	var R := minf(size.x, size.y) / 2.0 - 2.0
	if icon_tex != null:   # ảnh icon nghề cắt tròn (polygon có UV) + viền vàng kem
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 48:
			var a := i * TAU / 48.0
			var d := Vector2(cos(a), sin(a))
			pts.append(c + d * R)
			uvs.append(Vector2(0.5, 0.5) + d * 0.5)
		draw_colored_polygon(pts, Color.WHITE, uvs, icon_tex)
		draw_arc(c, R, 0, TAU, 48, Color(0.96, 0.88, 0.62), 3.0, true)
		draw_arc(c, R + 1.5, 0, TAU, 48, Color(0.12, 0.1, 0.08, 0.8), 1.5, true)
		return
	draw_circle(c, R, Color(0.16, 0.2, 0.32))                      # nền
	var s := R / 40.0
	var bob := sin(t * 2.0) * 0.8 * s
	# thân: phần đĩa tròn nằm dưới đường vai (cắt hình học, không tràn ra ngoài vòng)
	var y0 := 14.0 * s
	var pts := PackedVector2Array()
	var a1 := asin(clampf(y0 / R, -1.0, 1.0))
	for i in 21:
		var a := lerpf(PI - a1, a1, i / 20.0)   # nửa cung dưới, từ trái sang phải
		pts.append(c + Vector2(cos(a), sin(a)) * R)
	for i in 1:
		pass
	var top := PackedVector2Array()
	for i in 9:
		var x := lerpf(pts[pts.size() - 1].x - c.x, pts[0].x - c.x, i / 8.0)
		top.append(c + Vector2(x, y0 - 4.0 * s * sin(PI * i / 8.0)))   # vai hơi cong lên
	for p in top:
		pts.append(p)
	draw_colored_polygon(pts, shirt)
	draw_circle(c + Vector2(0, -8.0 * s + bob), 15.0 * s, Color(0.95, 0.8, 0.65))   # đầu
	draw_arc(c + Vector2(0, -9.0 * s + bob), 15.0 * s, PI, TAU, 16, Color(0.35, 0.22, 0.12), 6.0 * s)   # tóc
	draw_circle(c + Vector2(-5.5 * s, -7.0 * s + bob), 1.9 * s, Color(0.1, 0.1, 0.1))
	draw_circle(c + Vector2(5.5 * s, -7.0 * s + bob), 1.9 * s, Color(0.1, 0.1, 0.1))
	draw_arc(c, R, 0, TAU, 48, Color(0.96, 0.88, 0.62), 3.0, true)   # viền vàng kem
	draw_arc(c, R + 1.5, 0, TAU, 48, Color(0.12, 0.1, 0.08, 0.8), 1.5, true)

func _draw():
	if circle:
		_draw_circle_bust()
		return
	var c = size / 2.0
	# nền
	if not bare:
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
