class_name UiKit
extends RefCounted
## Hàm dựng UI dùng chung cho các panel đã tách khỏi TibiaUI.gd (D1). Chỉ có hàm static.

## 1234567 -> "1,234,567" (hiển thị gold / Bank).
static func fmt_int(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	var i := s.length()
	while i > 3:
		out = "," + s.substr(i - 3, 3) + out
		i -= 3
	out = s.substr(0, i) + out
	return ("-" if v < 0 else "") + out

static func panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.15, 0.2, 0.95)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.4, 0.45, 0.55)
	sb.set_content_margin_all(6)
	return sb

## Đăng ký một control là "vùng UI": chuột (cuộn/click) nằm trong vùng này KHÔNG được lọt xuống bản đồ (zoom/đi tới).
## Main._unhandled_input kiểm group "ui_block" (control đang hiện + rect chứa chuột).
static func block_world(c: Control) -> void:
	if not c.is_in_group("ui_block"):
		c.add_to_group("ui_block")

static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style())
	block_world(p)
	return p

static func bar(fill: Color, h := 14.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(0, h)
	b.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.07)
	b.add_theme_stylebox_override("background", bg)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	b.add_theme_stylebox_override("fill", fg)
	return b

static func lab(t: String, sz := 12, col := Color(0.9, 0.9, 0.9)) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l

static var _bold_font: FontVariation

## Font đậm (làm đậm từ font mặc định của theme) dùng cho title các card.
static func bold_font() -> Font:
	if _bold_font == null:
		_bold_font = FontVariation.new()
		_bold_font.base_font = ThemeDB.fallback_font
		_bold_font.variation_embolden = 0.7
	return _bold_font

## Title card: IN ĐẬM, vàng nhạt (kiểu "Trạng thái"). sz 13 cho Trạng thái/Skills, 12 cho Chat/Battle.
static func title(t: String, sz := 13) -> Label:
	var l := lab(t, sz, Color(1, 0.9, 0.5))
	l.add_theme_font_override("font", bold_font())
	return l

## Chữ đè lên giữa thanh (có viền đen cho dễ đọc). Trả về Label để cập nhật text.
static func bar_overlay(b: ProgressBar, sz := 10) -> Label:
	var l := lab("--", sz, Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return l
