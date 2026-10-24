class_name IconBtn
extends Button
## Nút icon TẠM. Có file `res://icons/<icon_name>.png` thì tự dùng ảnh thật, chưa có thì hiện chữ tạm (glyph).
## Thay icon = thả PNG đúng tên vào godot_client/icons/ (xem icons/README.md), KHÔNG cần sửa code.
##  - track_lit = true  : nút bật/tắt kiểu sáng (bật) / xám (tắt) — dùng cho Attack / Balance / Defense.
##  - track_lit = false : nút bấm thường (hàng icon góc phải-dưới); màu do nơi dùng tự đặt (vd. AUTO dùng modulate).

const ICON_DIR := "res://icons/"   # [SKIN] chỗ cũ; icon mới đặt ở res://assets/icons/<nhóm>/ (UiAssets.icon đọc cả hai)

var icon_name := ""
var glyph := ""
var has_tex := false
var track_lit := false
var accent := Color(0.35, 0.55, 0.9)
var skin_name := ""   # [SKIN] tên nền nút trong assets/ui/buttons/ ("icon" | "fight" | ...). Rỗng = tự chọn theo track_lit.

static func load_icon(icon_id: String) -> Texture2D:
	return UiAssets.icon(icon_id)   # [SKIN] assets/icons/<nhóm>/<id>.png, rồi res://icons/<id>.png

static func _sb(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.border_color = Color(0, 0, 0, 0.6)
	sb.set_content_margin_all(2)
	return sb

## Đặt `track_lit` / `toggle_mode` TRƯỚC khi gọi setup().
func setup(p_icon_name: String, p_glyph: String, tip: String, sz := Vector2(34, 34),
		p_accent := Color(0.35, 0.55, 0.9)) -> IconBtn:
	icon_name = p_icon_name
	glyph = p_glyph
	accent = p_accent
	if skin_name == "":
		skin_name = "fight" if track_lit else "icon"
	tooltip_text = tip
	custom_minimum_size = sz
	focus_mode = Control.FOCUS_NONE  # không giữ focus bàn phím (tránh phím Space/Enter bấm lại nút)
	add_theme_font_size_override("font_size", 12)
	var tex := load_icon(icon_name)
	has_tex = tex != null
	if has_tex:
		icon = tex
		expand_icon = true
		text = ""
	else:
		text = glyph
	_apply_look()
	if track_lit and has_tex:
		toggled.connect(func(_on: bool): _apply_tex_tint())
	return self

func set_glyph(g: String) -> void:
	glyph = g
	if not has_tex:
		text = g

## [SKIN] Đặt nền 1 trạng thái: có assets/ui/buttons/<skin_name>_<state>.png thì dùng ảnh, không thì style tạm `flat`.
func _put(state: String, flat: StyleBox) -> void:
	add_theme_stylebox_override(state, UiSkin.button(skin_name, state, flat))

func _apply_look() -> void:
	if has_tex:
		var flat := _sb(Color(0.1, 0.11, 0.15, 0.85))
		for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			_put(s, flat)
		_apply_tex_tint()
		return
	if track_lit:
		var off := Color(0.3, 0.3, 0.33)
		_put("normal", _sb(off))
		_put("hover", _sb(off.lightened(0.15)))
		_put("pressed", _sb(accent))
		_put("hover_pressed", _sb(accent.lightened(0.15)))
		add_theme_color_override("font_color", Color(0.65, 0.65, 0.68))
		add_theme_color_override("font_hover_color", Color(0.8, 0.8, 0.82))
		add_theme_color_override("font_pressed_color", Color.WHITE)
		add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	else:
		_put("normal", _sb(accent.darkened(0.35)))
		_put("hover", _sb(accent.darkened(0.1)))
		_put("pressed", _sb(accent.darkened(0.5)))
		_put("hover_pressed", _sb(accent.darkened(0.5)))
		add_theme_color_override("font_color", Color.WHITE)

func _apply_tex_tint() -> void:
	if track_lit:
		modulate = Color.WHITE if button_pressed else Color(0.4, 0.4, 0.4, 1.0)
