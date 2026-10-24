class_name DockIcons
extends RefCounted
## Icon vẽ bằng code (vector) cho Panel icon góc phải-dưới. Có PNG trong assets/icons/buttons/ thì DockCell dùng PNG, không thì dùng hình ở đây.
## draw(ci, id, c, s): vẽ icon `id` lên CanvasItem `ci`, tâm `c`, nửa-cạnh `s` (px). Gọi trong _draw() của control.

const GOLD := Color(1.0, 0.82, 0.3)
const GOLD_D := Color(0.75, 0.5, 0.12)
const STEEL := Color(0.82, 0.86, 0.95)
const INK := Color(0.04, 0.05, 0.1, 0.9)

static var _sb := StyleBoxFlat.new()


static func _p(c: Vector2, s: float, x: float, y: float) -> Vector2:
	return c + Vector2(x, y) * s


static func _poly(ci: CanvasItem, c: Vector2, s: float, pts: Array, col: Color) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + (p as Vector2) * s)
	ci.draw_colored_polygon(out, col)


static func _rr(ci: CanvasItem, r: Rect2, col: Color, rad := 3, border := 0, bcol := Color.BLACK) -> void:
	_sb.draw_center = true
	_sb.bg_color = col
	_sb.set_corner_radius_all(rad)
	_sb.set_border_width_all(border)
	_sb.border_color = bcol
	ci.draw_style_box(_sb, r)


static func _rrs(ci: CanvasItem, c: Vector2, s: float, x: float, y: float, w: float, h: float, col: Color, rad := 3) -> void:
	_rr(ci, Rect2(c + Vector2(x, y) * s, Vector2(w, h) * s), col, rad)


static func _star(ci: CanvasItem, c: Vector2, s: float, pts: int, inner: float, col: Color) -> void:
	var arr := PackedVector2Array()
	for i in pts * 2:
		var a := -PI / 2.0 + i * PI / pts
		var r := s if i % 2 == 0 else s * inner
		arr.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(arr, col)


static func _sword(ci: CanvasItem, c: Vector2, s: float, hilt: Vector2, tip: Vector2) -> void:
	var pa := c + hilt * s
	var pb := c + tip * s
	var d := (pb - pa).normalized()
	var n := Vector2(-d.y, d.x)
	ci.draw_line(pa, pb, STEEL, maxf(2.5, s * 0.26))
	var g := pa + d * s * 0.5
	ci.draw_line(g - n * s * 0.38, g + n * s * 0.38, GOLD, maxf(2.0, s * 0.2))
	ci.draw_circle(pa, maxf(1.8, s * 0.16), GOLD_D)


static func _head(ci: CanvasItem, c: Vector2, s: float, x: float, y: float, k: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(x, y) * s, s * 0.26 * k, col.lightened(0.25))
	_rr(ci, Rect2(c + Vector2(x - 0.34 * k, y + 0.34 * k) * s, Vector2(0.68 * k, 0.55 * k) * s), col, int(s * 0.25))


static func draw(ci: CanvasItem, id: String, c: Vector2, s: float) -> void:
	match id:
		"char":   # khiên
			var pts := [Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(0.8, 0.1), Vector2(0, 0.95), Vector2(-0.8, 0.1)]
			_poly(ci, c, s, pts, STEEL)
			var inner := []
			for p in pts:
				inner.append((p as Vector2) * 0.72 + Vector2(0, -0.02))
			_poly(ci, c, s, inner, Color(0.78, 0.2, 0.2))
			_rrs(ci, c, s, -0.1, -0.62, 0.2, 1.3, GOLD, 1)
			_rrs(ci, c, s, -0.55, -0.22, 1.1, 0.2, GOLD, 1)
		"skills":   # ngọn lửa
			_poly(ci, c, s, [Vector2(0.05, -1.0), Vector2(0.5, -0.35), Vector2(0.78, 0.25), Vector2(0.5, 0.85),
				Vector2(0, 1.0), Vector2(-0.5, 0.85), Vector2(-0.78, 0.25), Vector2(-0.45, -0.15), Vector2(-0.25, -0.5)],
				Color(0.95, 0.42, 0.12))
			_poly(ci, c + Vector2(0, 0.28 * s), s * 0.58, [Vector2(0.05, -1.0), Vector2(0.5, -0.35), Vector2(0.78, 0.25),
				Vector2(0.5, 0.85), Vector2(0, 1.0), Vector2(-0.5, 0.85), Vector2(-0.78, 0.25), Vector2(-0.45, -0.15),
				Vector2(-0.25, -0.5)], Color(1.0, 0.85, 0.3))
		"bag":   # ba lô
			_rrs(ci, c, s, -0.62, -0.7, 1.24, 1.65, Color(0.62, 0.4, 0.2), int(s * 0.4))
			_rrs(ci, c, s, -0.62, -0.7, 1.24, 0.5, Color(0.45, 0.28, 0.14), int(s * 0.4))
			_rrs(ci, c, s, -0.4, 0.2, 0.8, 0.55, Color(0.78, 0.55, 0.3), int(s * 0.2))
			_rrs(ci, c, s, -0.09, 0.02, 0.18, 0.3, GOLD, 1)
			ci.draw_arc(_p(c, s, 0, -0.72), s * 0.28, PI, TAU, 12, Color(0.35, 0.22, 0.1), maxf(2.0, s * 0.14))
		"battle":   # hai kiếm bắt chéo
			_sword(ci, c, s, Vector2(-0.8, 0.8), Vector2(0.85, -0.85))
			_sword(ci, c, s, Vector2(0.8, 0.8), Vector2(-0.85, -0.85))
		"map":   # tấm bản đồ gấp
			_poly(ci, c, s, [Vector2(-0.95, -0.6), Vector2(-0.32, -0.82), Vector2(-0.32, 0.62), Vector2(-0.95, 0.84)], Color(0.86, 0.74, 0.5))
			_poly(ci, c, s, [Vector2(-0.32, -0.82), Vector2(0.32, -0.6), Vector2(0.32, 0.84), Vector2(-0.32, 0.62)], Color(0.95, 0.85, 0.62))
			_poly(ci, c, s, [Vector2(0.32, -0.6), Vector2(0.95, -0.82), Vector2(0.95, 0.62), Vector2(0.32, 0.84)], Color(0.86, 0.74, 0.5))
			var w := maxf(2.0, s * 0.16)
			ci.draw_line(_p(c, s, -0.15, -0.1), _p(c, s, 0.15, 0.3), Color(0.8, 0.15, 0.15), w)
			ci.draw_line(_p(c, s, 0.15, -0.1), _p(c, s, -0.15, 0.3), Color(0.8, 0.15, 0.15), w)
		"party":   # 3 người
			_head(ci, c, s, -0.62, -0.05, 0.8, Color(0.3, 0.6, 0.35))
			_head(ci, c, s, 0.62, -0.05, 0.8, Color(0.85, 0.55, 0.2))
			_head(ci, c, s, 0.0, -0.2, 1.05, Color(0.3, 0.5, 0.9))
		"vip":   # vương miện
			_poly(ci, c, s, [Vector2(-0.88, 0.55), Vector2(-0.88, -0.5), Vector2(-0.42, 0.0), Vector2(0, -0.85),
				Vector2(0.42, 0.0), Vector2(0.88, -0.5), Vector2(0.88, 0.55)], GOLD)
			_rrs(ci, c, s, -0.88, 0.52, 1.76, 0.3, GOLD_D, 2)
			for p in [Vector2(-0.88, -0.55), Vector2(0, -0.9), Vector2(0.88, -0.55)]:
				ci.draw_circle(c + (p as Vector2) * s, maxf(1.8, s * 0.13), Color.WHITE)
		"status":   # sách
			_rrs(ci, c, s, -0.72, -0.9, 1.44, 1.8, Color(0.62, 0.15, 0.15), int(s * 0.18))
			_rrs(ci, c, s, -0.72, -0.9, 0.24, 1.8, Color(0.4, 0.08, 0.08), 2)
			_star(ci, _p(c, s, 0.12, 0.0), s * 0.38, 4, 0.4, GOLD)
		"spell":   # sao trong vòng tròn
			ci.draw_circle(c, s * 0.95, Color(0.18, 0.3, 0.62))
			ci.draw_arc(c, s * 0.95, 0, TAU, 28, Color(0.5, 0.7, 1.0), maxf(1.5, s * 0.1))
			_star(ci, _p(c, s, 0, 0.05), s * 0.68, 5, 0.45, GOLD)
		"autocfg":   # bánh răng
			var gc := Color(0.7, 0.78, 0.9)
			for i in 8:
				var a := i * TAU / 8.0
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(c + d * s * 0.6, c + d * s * 0.95, gc, maxf(2.5, s * 0.3))
			ci.draw_circle(c, s * 0.72, gc)
			ci.draw_circle(c, s * 0.3, INK)
		"chase":   # mũi tên đuổi
			var w2 := maxf(2.5, s * 0.24)
			var col := Color(0.35, 0.85, 0.7)
			for ox in [-0.45, 0.35]:
				ci.draw_polyline(PackedVector2Array([_p(c, s, ox - 0.25, -0.65), _p(c, s, ox + 0.35, 0.0), _p(c, s, ox - 0.25, 0.65)]), col, w2)
		"logout", "login":   # nút nguồn
			var pc := Color(0.9, 0.35, 0.3) if id == "logout" else Color(0.4, 0.85, 0.45)
			var w3 := maxf(2.5, s * 0.22)
			ci.draw_arc(_p(c, s, 0, 0.08), s * 0.72, -PI / 2.0 + 0.65, -PI / 2.0 + TAU - 0.65, 24, pc, w3)
			ci.draw_line(_p(c, s, 0, -0.9), _p(c, s, 0, -0.1), pc, w3)
		"coin":
			ci.draw_circle(c, s, GOLD_D)
			ci.draw_circle(c, s * 0.82, GOLD)
			ci.draw_arc(c, s * 0.55, 0, TAU, 16, GOLD_D, maxf(1.0, s * 0.12))
		"pad":   # biểu tượng cộng đồng (tay cầm) cho nút Discord
			_rrs(ci, c, s, -0.95, -0.55, 1.9, 1.2, Color.WHITE, int(s * 0.5))
			ci.draw_circle(_p(c, s, -0.38, 0.05), s * 0.2, Color(0.35, 0.4, 0.95))
			ci.draw_circle(_p(c, s, 0.38, 0.05), s * 0.2, Color(0.35, 0.4, 0.95))
		"all":   # lưới 4 ô
			var cols := [Color(0.35, 0.6, 0.95), Color(0.95, 0.6, 0.25), Color(0.4, 0.8, 0.45), Color(0.8, 0.45, 0.85)]
			var k := 0
			for yy in [-0.9, 0.08]:
				for xx in [-0.9, 0.08]:
					_rrs(ci, c, s, xx, yy, 0.82, 0.82, cols[k], int(s * 0.2))
					k += 1
		"food":   # quả táo
			ci.draw_circle(_p(c, s, -0.28, 0.2), s * 0.62, Color(0.88, 0.22, 0.2))
			ci.draw_circle(_p(c, s, 0.28, 0.2), s * 0.62, Color(0.88, 0.22, 0.2))
			ci.draw_line(_p(c, s, 0, -0.35), _p(c, s, 0.1, -0.85), Color(0.4, 0.25, 0.1), maxf(2.0, s * 0.16))
			_poly(ci, c, s, [Vector2(0.1, -0.7), Vector2(0.6, -0.95), Vector2(0.55, -0.45)], Color(0.3, 0.7, 0.3))
		"gem":   # kim cương
			_poly(ci, c, s, [Vector2(-0.85, -0.25), Vector2(-0.45, -0.85), Vector2(0.45, -0.85), Vector2(0.85, -0.25), Vector2(0, 0.95)], Color(0.35, 0.8, 0.95))
			_poly(ci, c, s, [Vector2(-0.45, -0.85), Vector2(0.45, -0.85), Vector2(0.25, -0.25), Vector2(-0.25, -0.25)], Color(0.7, 0.95, 1.0))
		"misc":   # túi nhỏ
			ci.draw_circle(_p(c, s, 0, 0.3), s * 0.7, Color(0.62, 0.4, 0.2))
			_poly(ci, c, s, [Vector2(-0.3, -0.35), Vector2(0.3, -0.35), Vector2(0.45, -0.85), Vector2(-0.45, -0.85)], Color(0.45, 0.28, 0.14))
			_rrs(ci, c, s, -0.4, -0.45, 0.8, 0.18, GOLD, 1)
		"plus":
			var w4 := maxf(1.5, s * 0.16)
			ci.draw_line(_p(c, s, -0.5, 0), _p(c, s, 0.5, 0), Color(1, 1, 1, 0.5), w4)
			ci.draw_line(_p(c, s, 0, -0.5), _p(c, s, 0, 0.5), Color(1, 1, 1, 0.5), w4)
