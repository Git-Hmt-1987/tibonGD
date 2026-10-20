class_name WorldMapPanel
extends PanelContainer
## Bản đồ thế giới (phím M / nút M): sơ đồ các thành phố + map con ĐÃ ĐI QUA nối bằng cổng; hero là chấm nhấp nháy ở map đang đứng.
## Dữ liệu tĩnh từ gói `world_map` (server worldmap.py): maps[{id,name,kind,theme,w,h,x,y,rec,visited}], links[[a,b]], canvas[w,h].
## Điều khiển: cuộn chuột = phóng to/thu nhỏ quanh con trỏ · giữ chuột trái kéo = di chuyển · nút + − ⌖ (về hero) ▣ (vừa khung).
## Màu Lv: xanh = level bạn nằm trong khoảng khuyến nghị · cam = bạn thấp hơn (nguy hiểm) · xám = bạn cao hơn.

signal need_data()

const PANEL_W := 920.0
const PANEL_H := 640.0
const SIDE_K := 0.16   # cạnh ô vuông của map trên sơ đồ = w * SIDE_K (mirror server worldmap.SIDE_K)
const ZOOM_MIN := 0.35
const ZOOM_MAX := 9.0
const THEME_COL := {"grass": Color(0.30, 0.55, 0.30), "mine": Color(0.50, 0.45, 0.40),
	"hell": Color(0.78, 0.25, 0.15), "desert": Color(0.86, 0.72, 0.40), "sky": Color(0.62, 0.80, 0.96)}

var maps := {}            # id -> dict từ server
var links: Array = []
var hero_map := ""
var hero_pos := Vector2i.ZERO
var hero_level := 1
var canvas: Control
var info_lab: Label
var pulse := 0.0
var sc := 1.5                     # px / đơn vị sơ đồ
var view_c := Vector2.ZERO        # điểm sơ đồ nằm giữa canvas
var user_moved := false           # người chơi đã tự phóng/kéo -> không tự vừa khung nữa
var dragging := false

func build() -> void:
	visible = false
	add_theme_stylebox_override("panel", UiKit.panel_style())
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	get_viewport().size_changed.connect(_center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	v.add_child(head)
	var title := UiKit.lab("Bản đồ thế giới  (phím M)", 15, Color(1.0, 0.85, 0.4))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	for spec in [["+", "Phóng to", 1], ["−", "Thu nhỏ", -1]]:
		var zb := Button.new()
		zb.text = spec[0]
		zb.tooltip_text = spec[1]
		zb.focus_mode = Control.FOCUS_NONE
		zb.custom_minimum_size = Vector2(30, 0)
		var dir: int = spec[2]
		zb.pressed.connect(func(): _zoom_at(canvas.size / 2.0, 1.4 if dir > 0 else 1.0 / 1.4))
		head.add_child(zb)
	var hb := Button.new()
	hb.text = "⌖"
	hb.tooltip_text = "Về vị trí của bạn"
	hb.focus_mode = Control.FOCUS_NONE
	hb.custom_minimum_size = Vector2(30, 0)
	hb.pressed.connect(center_on_hero)
	head.add_child(hb)
	var fb := Button.new()
	fb.text = "▣"
	fb.tooltip_text = "Vừa khung (xem tất cả map đã khám phá)"
	fb.focus_mode = Control.FOCUS_NONE
	fb.custom_minimum_size = Vector2(30, 0)
	fb.pressed.connect(fit_view)
	head.add_child(fb)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(hide_map)
	head.add_child(close_btn)
	info_lab = UiKit.lab("", 12, Color(0.9, 0.95, 1.0))
	v.add_child(info_lab)
	canvas = Control.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_draw_canvas)
	canvas.gui_input.connect(_canvas_input)
	v.add_child(canvas)
	v.add_child(UiKit.lab("Cuộn chuột = phóng/thu · kéo chuột = di chuyển · viền vàng = thành phố (mờ = chưa đến) · chấm trắng = bạn · Lv xanh = hợp level, cam = còn yếu.", 11, Color(0.7, 0.75, 0.8)))

func toggle() -> void:
	if visible:
		hide_map()
		return
	visible = true
	_center()
	need_data.emit()   # luôn xin lại (nhẹ, tĩnh) để map mới của server hiện ngay
	_refresh_info()
	if not user_moved:
		fit_view()
	canvas.queue_redraw()

func hide_map() -> void:
	visible = false
	dragging = false

func set_data(msg: Dictionary) -> void:
	maps = {}
	for m in msg.get("maps", []):
		maps[str(m.get("id", ""))] = m
	links = msg.get("links", [])
	_refresh_info()
	if not user_moved:
		fit_view()
	canvas.queue_redraw()

func set_hero(map_id: String, pos: Vector2i, level: int = 1) -> void:
	hero_map = map_id
	hero_pos = pos
	hero_level = level
	if visible:
		_refresh_info()

func _refresh_info() -> void:
	if info_lab == null:
		return
	var m: Dictionary = maps.get(hero_map, {})
	var nm: String = str(m.get("name", hero_map))
	var rec = m.get("rec", [])
	var lv := ""
	if rec is Array and rec.size() == 2:
		lv = "   ·   Level khuyến nghị: %d-%d" % [int(rec[0]), int(rec[1])]
	info_lab.text = "Bạn đang ở: %s  (%d, %d)%s   ·   Level của bạn: %d" % [nm, hero_pos.x, hero_pos.y, lv, hero_level]

func _center() -> void:
	if not visible:
		return
	var vp := get_viewport_rect().size
	var sz := Vector2(minf(PANEL_W, vp.x - 16.0), minf(PANEL_H, vp.y - 16.0))
	custom_minimum_size = sz
	size = sz
	global_position = ((vp - sz) / 2.0).floor()
	z_index = 100
	if get_parent() != null:
		get_parent().move_child(self, -1)

func _process(delta: float) -> void:
	if visible:
		pulse += delta
		canvas.queue_redraw()

# ---------- khung nhìn ----------

func _node_center(m: Dictionary) -> Vector2:
	return Vector2(float(m.get("x", 0)), float(m.get("y", 0)))

func _to_screen(p: Vector2) -> Vector2:
	return canvas.size / 2.0 + (p - view_c) * sc

## Vừa khung: thu phóng + căn giữa để thấy mọi map đang hiện.
func fit_view() -> void:
	user_moved = false
	if maps.is_empty() or canvas == null:
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for id in maps:
		var m: Dictionary = maps[id]
		var c := _node_center(m)
		var h := float(m.get("w", 64)) * SIDE_K / 2.0 + 10.0   # chừa chỗ ghi tên + level
		lo = Vector2(minf(lo.x, c.x - h), minf(lo.y, c.y - h))
		hi = Vector2(maxf(hi.x, c.x + h), maxf(hi.y, c.y + h + 10.0))
	var span := hi - lo
	var cs := canvas.size if canvas.size.x > 10.0 else Vector2(PANEL_W - 24.0, PANEL_H - 120.0)
	sc = clampf(minf(cs.x / maxf(span.x, 1.0), cs.y / maxf(span.y, 1.0)), ZOOM_MIN, 4.0)
	view_c = (lo + hi) / 2.0
	canvas.queue_redraw()

func center_on_hero() -> void:
	var m: Dictionary = maps.get(hero_map, {})
	if m.is_empty():
		return
	user_moved = true
	var side := float(m.get("w", 64))
	var fx := float(hero_pos.x) / maxf(1.0, side)
	var fy := float(hero_pos.y) / maxf(1.0, float(m.get("h", 64)))
	var half := side * SIDE_K / 2.0
	view_c = _node_center(m) + Vector2((fx - 0.5) * 2.0 * half, (fy - 0.5) * 2.0 * half)
	sc = maxf(sc, 3.0)
	canvas.queue_redraw()

func _zoom_at(screen_pt: Vector2, factor: float) -> void:
	user_moved = true
	var before := view_c + (screen_pt - canvas.size / 2.0) / sc     # điểm sơ đồ dưới con trỏ
	sc = clampf(sc * factor, ZOOM_MIN, ZOOM_MAX)
	view_c = before - (screen_pt - canvas.size / 2.0) / sc          # giữ điểm đó đứng yên dưới con trỏ
	canvas.queue_redraw()

func _canvas_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			_zoom_at(e.position, 1.2)
			canvas.accept_event()
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			_zoom_at(e.position, 1.0 / 1.2)
			canvas.accept_event()
		elif e.button_index == MOUSE_BUTTON_LEFT:
			dragging = e.pressed
			canvas.accept_event()
	elif e is InputEventMouseMotion and dragging:
		user_moved = true
		view_c -= e.relative / sc
		canvas.accept_event()
		canvas.queue_redraw()

# ---------- vẽ ----------

func _text_w(txt: String, fs: int) -> float:
	var font: Font = ThemeDB.fallback_font
	return font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

## Chữ căn giữa theo x, kèm nền tối mờ phía sau để luôn đọc được trên mọi màu nền / đường nối.
func _label(txt: String, cx: float, y: float, fs: int, col: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var w := _text_w(txt, fs)
	canvas.draw_rect(Rect2(cx - w / 2.0 - 3.0, y - fs, w + 6.0, fs + 4.0), Color(0.03, 0.04, 0.07, 0.72))
	canvas.draw_string(font, Vector2(cx - w / 2.0, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _lv_color(rec: Array, a: float) -> Color:
	if hero_level < int(rec[0]):
		return Color(1.0, 0.62, 0.25, a)     # còn yếu so với khuyến nghị
	if hero_level > int(rec[1]):
		return Color(0.62, 0.68, 0.78, a)    # vượt level khu này
	return Color(0.45, 0.95, 0.5, a)         # hợp level

func _draw_canvas() -> void:
	var sz := canvas.size
	canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.05, 0.07, 0.10))
	if maps.is_empty():
		_label("Đang tải bản đồ...", sz.x / 2.0, sz.y / 2.0, 14, Color(0.8, 0.8, 0.8))
		return
	for l in links:   # đường nối (cổng) vẽ trước, node đè lên
		var a: Dictionary = maps.get(str(l[0]), {})
		var b: Dictionary = maps.get(str(l[1]), {})
		if a.is_empty() or b.is_empty():
			continue
		canvas.draw_line(_to_screen(_node_center(a)), _to_screen(_node_center(b)), Color(0.55, 0.58, 0.68, 0.9), maxf(1.5, sc * 0.5))
	var fs_name := clampi(roundi(8.0 + sc * 1.8), 10, 17)
	var fs_lv := maxi(9, fs_name - 2)
	var hero_rect := Rect2()
	for id in maps:
		var m: Dictionary = maps[id]
		var side := float(m.get("w", 64)) * SIDE_K * sc
		var c := _to_screen(_node_center(m))
		var r := Rect2(c - Vector2(side, side) / 2.0, Vector2(side, side))
		if r.end.x < -80.0 or r.position.x > sz.x + 80.0 or r.end.y < -80.0 or r.position.y > sz.y + 80.0:
			continue
		var col: Color = THEME_COL.get(str(m.get("theme", "grass")), Color(0.4, 0.5, 0.4))
		var seen := bool(m.get("visited", true))
		var al := 1.0 if seen else 0.35          # thành phố chưa đến: vẽ mờ
		col.a = al
		canvas.draw_rect(r, col)
		var is_city := str(m.get("kind", "hunt")) == "city"
		var edge := Color(1.0, 0.85, 0.3, al) if is_city else Color(0.12, 0.12, 0.16)
		canvas.draw_rect(r, edge, false, 3.0 if is_city else 1.5)
		if id == hero_map:
			hero_rect = r
			var glow := 0.55 + 0.45 * sin(pulse * 5.0)
			canvas.draw_rect(r.grow(3.0), Color(1, 1, 1, glow), false, 2.0)
		var cx := r.position.x + r.size.x / 2.0
		var fn := fs_name + (2 if is_city else 0)
		_label(str(m.get("name", id)), cx, r.end.y + fn + 3.0, fn, Color(1.0, 0.95, 0.7, al) if is_city else Color(0.92, 0.94, 0.98))
		var rec = m.get("rec", [])
		if rec is Array and rec.size() == 2:    # mức level khuyến nghị dưới tên map (màu theo level của bạn)
			_label("Lv %d-%d" % [int(rec[0]), int(rec[1])], cx, r.end.y + fn + fs_lv + 8.0, fs_lv, _lv_color(rec, al))
	if hero_rect.size.x > 0.0 and maps.has(hero_map):   # chấm hero đúng vị trí tương đối trong map
		var hm: Dictionary = maps[hero_map]
		var fx := clampf(float(hero_pos.x) / maxf(1.0, float(hm.get("w", 1))), 0.0, 1.0)
		var fy := clampf(float(hero_pos.y) / maxf(1.0, float(hm.get("h", 1))), 0.0, 1.0)
		var p := hero_rect.position + Vector2(fx, fy) * hero_rect.size
		canvas.draw_circle(p, 5.0 + 2.0 * sin(pulse * 5.0), Color(1, 0.2, 0.2, 0.55))
		canvas.draw_circle(p, 3.0, Color.WHITE)
