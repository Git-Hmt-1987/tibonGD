class_name DockCell
extends Button
## Một ô của Panel icon góc phải-dưới (ActionDock): nền bo góc + icon (PNG nếu có, không thì vector DockIcons) + chữ phím tắt góc trái-dưới.
##  - round_btn = true : nút tròn kiểu AUTO (vòng viền + nhãn "AUTO"), bật = xanh lá.
##  - lit              : ô đang "mở" (panel đang hiện / chế độ đang bật) -> viền vàng.
##  - empty_slot       : ô trống dự phòng (mờ, không bấm được).

const BG := Color(0.12, 0.15, 0.24)
const BG_HOVER := Color(0.19, 0.24, 0.38)
const BORDER := Color(0.26, 0.31, 0.48)
const LIT := Color(1.0, 0.72, 0.15)

var icon_id := ""
var tex_name := ""
var key_hint := ""
var round_btn := false
var lit := false : set = set_lit
var empty_slot := false


static func _box(bg: Color, border: Color, bw := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(bw)
	sb.border_color = border
	return sb


func setup(p_id: String, p_tex: String, p_key: String, tip: String, sz: Vector2) -> DockCell:
	icon_id = p_id
	tex_name = p_tex
	key_hint = p_key
	tooltip_text = tip
	custom_minimum_size = sz
	focus_mode = Control.FOCUS_NONE   # không cướp phím WASD / Space
	text = ""
	if round_btn:
		for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			add_theme_stylebox_override(s, StyleBoxEmpty.new())
	elif empty_slot:
		disabled = true
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			add_theme_stylebox_override(s, _box(Color(0.09, 0.11, 0.17, 0.7), Color(0.18, 0.21, 0.32, 0.7), 1))
	else:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		# ô icon nền xanh đậm (suy ra từ UiTheme.accent) để icon sáng màu nổi bật trên panel trắng kem
		add_theme_stylebox_override("normal", _box(UiTheme.accent().darkened(0.55), UiTheme.accent_dark()))
		add_theme_stylebox_override("hover", _box(UiTheme.accent().darkened(0.35), UiTheme.accent()))
		add_theme_stylebox_override("pressed", _box(UiTheme.accent().darkened(0.7), LIT))
		add_theme_stylebox_override("hover_pressed", _box(UiTheme.accent().darkened(0.6), LIT))
	return self


func set_lit(v: bool) -> void:
	if lit != v:
		lit = v
		queue_redraw()


func _draw() -> void:
	var sz := size
	var c := sz / 2.0
	if round_btn:
		_draw_round(c, sz)
		return
	if empty_slot:
		DockIcons.draw(self, "plus", c, minf(sz.x, sz.y) * 0.22)
		return
	var s := minf(sz.x, sz.y) * 0.5
	var ic := c + Vector2(0, -1)
	var tex: Texture2D = UiAssets.icon(tex_name) if tex_name != "" else null
	if tex != null:
		var e := s * 1.3
		draw_texture_rect(tex, Rect2(ic - Vector2(e, e) / 2.0, Vector2(e, e)), false)
	else:
		DockIcons.draw(self, icon_id, ic, s * 0.58)
	if lit:   # viền vàng báo ô đang mở
		var sb := _box(Color(0, 0, 0, 0), LIT, 3)
		sb.draw_center = false
		draw_style_box(sb, Rect2(Vector2.ZERO, sz))
	if key_hint != "":
		var font := get_theme_default_font()
		var pos := Vector2(5, sz.y - 4)
		draw_string_outline(font, pos, key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, UiTheme.accent_dark())
		draw_string(font, pos, key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


func _draw_round(c: Vector2, sz: Vector2) -> void:
	var on := button_pressed
	# viền bo tròn dày 2px (cùng độ dày viền các ô khác): xanh dương khi tắt, xanh lá khi bật
	var ring := Color(0.4, 0.9, 0.5) if on else (Color(0.6, 0.75, 1.0) if is_hovered() else Color(0.35, 0.55, 0.95))
	var compact := sz.y <= 34.0   # bản nhỏ cạnh ô Gold: chỉ vòng tròn + icon, không nhãn "AUTO"
	var r := minf(sz.x, sz.y) * 0.5 - (1.0 if compact else 3.0)
	var cc := c if compact else Vector2(c.x, r + 2.0)
	var tex: Texture2D = UiAssets.icon(tex_name) if tex_name != "" else null
	if tex != null:
		# PNG cắt tròn (polygon có UV) nên ảnh vuông cũng khớp viền bo tròn; có AUTO bật thì phủ nhẹ màu xanh lá
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 48:
			var a := i * TAU / 48.0
			var d := Vector2(cos(a), sin(a))
			pts.append(cc + d * (r - 1.0))
			uvs.append(Vector2(0.5, 0.5) + d * 0.5)
		draw_colored_polygon(pts, Color.WHITE if on else Color(0.85, 0.85, 0.85), uvs, tex)
	else:
		draw_circle(cc, r, Color(0.1, 0.38, 0.22) if on else Color(0.1, 0.13, 0.22))
		DockIcons.draw(self, "battle", cc, r * 0.55)
	draw_arc(cc, r - 1.0, 0, TAU, 48, ring, 2.0, true)
	if compact:
		return
	var pill := Rect2(Vector2(c.x - 19, sz.y - 13), Vector2(38, 13))
	DockIcons._rr(self, pill, Color(0.07, 0.09, 0.16), 6, 1, ring)
	var font := get_theme_default_font()
	draw_string(font, Vector2(pill.position.x, pill.position.y + 10), "AUTO", HORIZONTAL_ALIGNMENT_CENTER, pill.size.x, 10,
		Color(0.6, 1.0, 0.65) if on else Color(0.95, 0.85, 0.55))
