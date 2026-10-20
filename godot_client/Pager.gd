class_name Pager
extends HBoxContainer
## Thanh phân trang dùng chung cho mọi danh sách trong panel:  ‹  1  2  3  …  9  ›
## - Thay cho ScrollContainer: cuộn chuột KHÔNG còn làm zoom bản đồ, danh sách đổi trang rõ ràng.
## - Cách dùng: pager.set_total(list.size(), PER_PAGE); for x in Pager.slice(list, pager.page, PER_PAGE): ...
##   Nối signal `page_changed` để vẽ lại. `attach_wheel(ctrl)`: lăn chuột trên vùng `ctrl` = lùi/tiến 1 trang.
## - Tự ẩn khi chỉ có 1 trang. Trang hiện tại tô vàng; nhiều trang thì rút gọn bằng "…".

signal page_changed(page: int)

const MAX_NUMS := 7        # số nút số tối đa (kể cả "…")
const GOLD := Color(1.0, 0.85, 0.4)

var page := 0              # 0-based
var pages := 1
var per_page := 8

func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 3)

## Cắt phần tử của trang `pg` (0-based).
static func slice(list: Array, pg: int, per: int) -> Array:
	var a := clampi(pg * per, 0, list.size())
	var b := clampi(a + per, 0, list.size())
	return list.slice(a, b)

## Cập nhật tổng số phần tử; giữ nguyên trang đang xem (kẹp lại nếu vượt). reset=true: về trang 1.
func set_total(count: int, p_per_page: int, reset := false) -> void:
	per_page = maxi(1, p_per_page)
	pages = maxi(1, ceili(count / float(per_page)))
	page = 0 if reset else clampi(page, 0, pages - 1)
	_rebuild()

func go(p: int) -> void:
	p = clampi(p, 0, pages - 1)
	if p == page:
		return
	page = p
	_rebuild()
	page_changed.emit(page)

## Lăn chuột trên `area` = đổi trang (và chặn sự kiện lan xuống bản đồ).
func attach_wheel(area: Control) -> void:
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	area.gui_input.connect(_on_wheel)

func _on_wheel(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			go(page - 1)
			accept_event()
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			go(page + 1)
			accept_event()

func _nums() -> Array:
	var out: Array = []
	if pages <= MAX_NUMS:
		for i in pages:
			out.append(i)
		return out
	var keep := {0: true, pages - 1: true, page: true, page - 1: true, page + 1: true}
	var idx: Array = keep.keys()
	idx = idx.filter(func(i): return i >= 0 and i < pages)
	idx.sort()
	var prev := -1
	for i in idx:
		if prev >= 0 and i - prev > 1:
			out.append(-1)   # "…"
		out.append(i)
		prev = i
	return out

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	visible = pages > 1
	if pages <= 1:
		return
	add_child(_btn("‹", page > 0, false, page - 1))
	for i in _nums():
		if i < 0:
			var dots := Label.new()
			dots.text = "…"
			dots.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
			add_child(dots)
		else:
			add_child(_btn(str(i + 1), true, i == page, i))
	add_child(_btn("›", page < pages - 1, false, page + 1))

func _btn(t: String, enabled: bool, current: bool, target: int) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(26, 24)
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", 12)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(2)
	sb.bg_color = Color(0.42, 0.33, 0.1) if current else Color(0.17, 0.2, 0.27)
	sb.border_color = GOLD if current else Color(0.35, 0.4, 0.5)
	b.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate() as StyleBoxFlat
	hov.bg_color = hov.bg_color.lightened(0.15)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", hov)
	b.add_theme_stylebox_override("disabled", sb)
	var col := GOLD if current else Color(0.85, 0.88, 0.95)
	for cn in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(cn, col)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.55))
	b.pressed.connect(go.bind(target))
	return b
