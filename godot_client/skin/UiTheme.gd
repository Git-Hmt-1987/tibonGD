class_name UiTheme
extends RefCounted
## BẢNG MÀU / CỠ CHỮ TOÀN CỤC của giao diện sáng (nền trắng kem + header xanh).
##
##   >>> ĐỔI MÀU XANH CHỦ ĐẠO Ở ĐÂY: sửa hằng ACCENT (hoặc `accent=` trong assets/skin.cfg mục [colors], cfg thắng). <<<
##
## Mọi thứ xanh (thanh header, viền panel, nút, chip tab...) đều suy ra từ ACCENT nên chỉ cần đổi 1 chỗ.
## Màu nền thân panel / màu chữ cũng đổi được tại đây (hoặc skin.cfg: body=, ink=).

const ACCENT := Color("#2f58a8")   # <<< biến toàn cục: màu xanh chủ đạo
const BODY := Color("#f3e7c8")     # nền thân panel (trắng kem đậm)
const INK := Color("#27304d")      # chữ chính trên nền sáng
const FONT_BUMP := 1               # cộng thêm vào mọi cỡ chữ đặt bằng UiKit.lab / TibiaUI._lab / title

static func accent() -> Color:
	return UiSkin.color("accent", ACCENT)

static func body() -> Color:
	return UiSkin.color("body", BODY)

static func ink_color() -> Color:
	return UiSkin.color("ink", INK)

static func accent_dark() -> Color:    # viền panel, viền nút
	return accent().darkened(0.38)

static func accent_light() -> Color:   # nền chip/nút nhạt
	return accent().lerp(Color.WHITE, 0.82)

static func accent_mid() -> Color:     # hover
	return accent().lerp(Color.WHITE, 0.62)

static func muted() -> Color:          # chữ phụ
	return ink_color().lerp(body(), 0.45)

## Cỡ chữ theo thiết kế mới (to hơn một chút).
static func fs(sz: int) -> int:
	return sz + FONT_BUMP

## Đổi màu chữ "sáng" (viết cho nền tối) thành màu tương ứng đọc được trên nền sáng.
## Màu đã tối/đậm giữ nguyên. Trắng/xám nhạt -> INK; vàng -> nâu cam; xanh nhạt -> xanh đậm; ...
static func ink(col: Color) -> Color:
	var v := col.v
	if v < 0.62:
		return col
	if col.s < 0.18:
		return ink_color() if v > 0.8 else ink_color().lerp(body(), 0.35)
	return Color.from_hsv(col.h, minf(1.0, col.s * 1.15 + 0.15), 0.42 if col.h > 0.08 and col.h < 0.18 else 0.5)

## Đổi các thẻ [color=...] trong BBCode (viết cho nền tối) sang màu đọc được trên nền sáng.
static func ink_bbcode(t: String) -> String:
	var re := RegEx.new()
	re.compile("\\[color=([^\\]]+)\\]")
	var out := ""
	var pos := 0
	for m in re.search_all(t):
		out += t.substr(pos, m.get_start() - pos)
		var c := Color.from_string(m.get_string(1), Color(-1, 0, 0))
		out += "[color=#%s]" % ink(c).to_html(false) if c.r >= 0.0 else m.get_string()
		pos = m.get_end()
	return out + t.substr(pos)
