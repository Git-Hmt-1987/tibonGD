class_name UiSkin
extends RefCounted
## Nguồn style DUY NHẤT cho giao diện: panel / nút / thanh / ô / font / màu.
## Có PNG trong assets/ui/... -> trả StyleBoxTexture (9-slice). Không có -> trả đúng giao diện tạm hiện tại (StyleBoxFlat).
## Thêm một kiểu nền mới: thêm 1 hàm ở đây + 1 dòng gọi ở nơi vẽ. Không đụng từng panel.
## Lề 9-slice / màu / cỡ chữ chỉnh trong assets/skin.cfg (tùy chọn).

const PANEL_BG := Color(0.97, 0.96, 0.91, 1.0)   # (dự phòng; nền thật lấy từ UiTheme.body())
const PANEL_BORDER := Color(0.25, 0.47, 0.84)

static var _fonts := {}


# ---------------------------------------------------------------- màu / cấu hình
## Màu đặt tên trong skin.cfg mục [colors] (chuỗi "#rrggbb" hoặc Color(...)). Không có = mặc định `fallback`.
static func color(cname: String, fallback: Color) -> Color:
	var v: Variant = UiAssets.cfg_get("colors", cname, null)
	if v is Color:
		return v
	if v is String and Color.html_is_valid(v):
		return Color.html(v)
	return fallback


static func _to_color(v: Variant) -> Color:
	if v is Color:
		return v
	if v is String and Color.html_is_valid(v):
		return Color.html(v)
	return Color.WHITE


## StyleBoxTexture 9-slice từ ảnh `t`. Lề lấy từ skin.cfg [section] (margin / margin_left|top|right|bottom / content / tint / tile).
static func _tex_style(t: Texture2D, section: String, def_margin := 8, def_content := -1) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = t
	var all := int(UiAssets.cfg_get(section, "margin", def_margin))
	sb.texture_margin_left = float(UiAssets.cfg_get(section, "margin_left", all))
	sb.texture_margin_top = float(UiAssets.cfg_get(section, "margin_top", all))
	sb.texture_margin_right = float(UiAssets.cfg_get(section, "margin_right", all))
	sb.texture_margin_bottom = float(UiAssets.cfg_get(section, "margin_bottom", all))
	var content := int(UiAssets.cfg_get(section, "content", all if def_content < 0 else def_content))
	sb.set_content_margin_all(float(content))
	var tint: Variant = UiAssets.cfg_get(section, "tint", null)
	if tint != null:
		sb.modulate_color = _to_color(tint)
	if bool(UiAssets.cfg_get(section, "tile", false)):
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return sb


# ---------------------------------------------------------------- panel
## Nền panel. pname: "panel" (chung) | "login" | "tooltip" | tên tùy ý có file assets/ui/panels/<tên>.png.
static func panel(pname := "panel") -> StyleBox:
	var t := UiAssets.tex("ui/panels/%s.png" % pname)
	if t != null:
		return _tex_style(t, "panel." + pname, 8)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.body()
	sb.border_color = UiTheme.accent_dark()
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)   # mọi panel bo tròn
	sb.set_content_margin_all(18 if pname == "login" else 6)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 3
	return sb


# ---------------------------------------------------------------- nút / ô (nhiều trạng thái)
## Chọn ảnh theo trạng thái: <dir><base>_<state>.png; thiếu thì lấy _normal rồi làm sáng/tối. Không có gì = null.
static func _state_tex(dir: String, bases: Array, state: String) -> Array:   # [Texture2D hoặc null, Color tint]
	var file_state := "pressed" if state == "hover_pressed" else state
	for b in bases:
		var t := UiAssets.tex("%s%s_%s.png" % [dir, b, file_state])
		if t != null:
			return [t, Color.WHITE]
	for b in bases:
		var tn := UiAssets.tex("%s%s_normal.png" % [dir, b])
		if tn != null:
			var tint := Color.WHITE
			match state:
				"hover", "hover_pressed":
					tint = Color(1.15, 1.15, 1.15)
				"pressed":
					tint = Color(0.8, 0.8, 0.8)
				"disabled":
					tint = Color(0.5, 0.5, 0.5, 0.7)
			return [tn, tint]
	return [null, Color.WHITE]


## Nền nút. bname: "button" | "icon" | "fight". state: normal | hover | pressed | hover_pressed | disabled.
## `fallback` = style tạm cũ của nơi gọi (dùng khi chưa có PNG).
static func button(bname: String, state: String, fallback: StyleBox) -> StyleBox:
	var r := _state_tex("ui/buttons/", [bname], state)
	if r[0] == null:
		return fallback
	var tint: Color = r[1]
	var sb := _tex_style(r[0], "button." + bname, 6, 4)
	sb.modulate_color = sb.modulate_color * tint
	return sb


## Nền ô hotbar. kind: "item" | "spell" | "" (ô trống). Thử slot_<kind>_<state> rồi slot_<state>.
static func slot(state: String, kind: String, fallback: StyleBox) -> StyleBox:
	var bases: Array = ["slot_" + (kind if kind != "" else "empty"), "slot"]
	var r := _state_tex("ui/slots/", bases, state)
	if r[0] == null:
		return fallback
	var tint: Color = r[1]
	var sb := _tex_style(r[0], "slot", 4, 2)
	sb.modulate_color = sb.modulate_color * tint
	return sb


# ---------------------------------------------------------------- thanh chỉ số
## [nền, phần đầy] của thanh `bname` ("hp" | "mana" | "stamina" | "exp" | "target" | ""). Thiếu PNG thì dùng màu tạm.
static func bar_styles(bname: String, fill_col: Color) -> Array:
	var bg: StyleBox = null
	var fg: StyleBox = null
	if bname != "":
		var tb := UiAssets.tex("ui/bars/%s_bg.png" % bname)
		var tf := UiAssets.tex("ui/bars/%s_fill.png" % bname)
		if tb != null:
			bg = _tex_style(tb, "bar." + bname, 2, 0)
		if tf != null:
			fg = _tex_style(tf, "bar." + bname, 2, 0)
	if bg == null:
		var fb := StyleBoxFlat.new()
		fb.bg_color = Color(0.05, 0.05, 0.07)
		bg = fb
	if fg == null:
		var ff := StyleBoxFlat.new()
		ff.bg_color = fill_col
		fg = ff
	return [bg, fg]


## Đổi màu phần đầy của một thanh (dùng cho thanh đổi màu theo ngưỡng như stamina). Hỗ trợ cả style phẳng lẫn ảnh.
static func tint_bar_fill(b: ProgressBar, col: Color) -> void:
	var s := b.get_theme_stylebox("fill")
	if s is StyleBoxFlat:
		(s as StyleBoxFlat).bg_color = col
	elif s is StyleBoxTexture:
		(s as StyleBoxTexture).modulate_color = col


# ---------------------------------------------------------------- font
## Font theo vai trò: "ui" | "bold" | "title" | "damage" | "world". Luôn trả về Font dùng được (không null).
static func font(role: String) -> Font:
	if _fonts.has(role):
		return _fonts[role]
	var f: Font = null
	match role:
		"bold":
			f = UiAssets.font("ui_bold")
			if f == null:
				var fv := FontVariation.new()
				fv.base_font = font("ui")
				fv.variation_embolden = 0.7   # giống bản cũ: đậm giả từ font thường
				f = fv
		"title":
			f = UiAssets.font("title")
			if f == null:
				f = font("bold")
		"damage":
			f = UiAssets.font("damage")
			if f == null:
				f = font("ui")
		"world":
			f = UiAssets.font("world")
			if f == null:
				f = font("ui")
		_:
			f = UiAssets.font("ui")
			if f == null:
				f = ThemeDB.fallback_font
	if f is FontFile:
		f = _tight(f)   # Baloo 2 có dòng rất cao -> thu gọn khoảng cách trên/dưới mỗi dòng chữ
	_fonts[role] = f
	return f


## Bọc font để dòng chữ sít lại: spacing_top/bottom âm (px). Chỉnh ở skin.cfg [fonts] line_trim (mặc định 3).
static func _tight(f: Font) -> Font:
	var fv := FontVariation.new()
	fv.base_font = f
	var trim := int(UiAssets.cfg_get("fonts", "line_trim", 3))
	fv.spacing_top = -trim
	fv.spacing_bottom = -maxi(trim - 1, 0)   # 3 / 2: dòng ~19px ở cỡ 14, chữ không bị dính mép
	return fv


# ---------------------------------------------------------------- theme toàn cục
## Theme mặc định cho cả game. Chỉ chứa mục có asset thật -> chưa dán gì thì giao diện y như cũ.
static func build_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font("ui")   # font đậm (Baloo 2 Bold) cho toàn bộ chữ
	var fs := int(UiAssets.cfg_get("fonts", "size", 14))
	th.default_font_size = fs
	var ink := UiTheme.ink_color()
	# --- Label / RichText / LineEdit: chữ tối trên nền sáng
	th.set_color("font_color", "Label", ink)
	th.set_color("default_color", "RichTextLabel", ink)
	th.set_color("font_color", "LineEdit", ink)
	th.set_color("font_placeholder_color", "LineEdit", UiTheme.muted())
	th.set_color("caret_color", "LineEdit", ink)
	var le := _chip(UiTheme.body().lightened(0.55), UiTheme.accent_dark(), 2, 8)
	le.set_content_margin_all(3)
	le.content_margin_left = 10   # chữ không dính mép trái
	le.content_margin_right = 10
	th.set_stylebox("normal", "LineEdit", le)
	var le_f := _chip(UiTheme.body().lightened(0.55), UiTheme.accent(), 2, 8)
	le_f.content_margin_left = 10
	le_f.content_margin_right = 10
	th.set_stylebox("focus", "LineEdit", le_f)
	# --- Button: chip xanh nhạt, viền xanh, bấm = xanh đậm chữ trắng
	var has_btn_tex := UiAssets.tex("ui/buttons/button_normal.png") != null
	if has_btn_tex:
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			th.set_stylebox(st, "Button", button("button", st, empty))
	else:
		th.set_stylebox("normal", "Button", _chip(UiTheme.accent_light(), UiTheme.accent_dark(), 2, 8))
		th.set_stylebox("hover", "Button", _chip(UiTheme.accent_mid(), UiTheme.accent_dark(), 2, 8))
		th.set_stylebox("pressed", "Button", _chip(UiTheme.accent(), UiTheme.accent_dark(), 2, 8))
		th.set_stylebox("hover_pressed", "Button", _chip(UiTheme.accent().lightened(0.12), UiTheme.accent_dark(), 2, 8))
		th.set_stylebox("disabled", "Button", _chip(UiTheme.accent_light().lerp(UiTheme.body(), 0.5), UiTheme.accent_dark().lerp(UiTheme.body(), 0.5), 2, 8))
		th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", ink)
	th.set_color("font_hover_color", "Button", ink)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", UiTheme.muted())
	th.set_color("font_focus_color", "Button", ink)
	for cn in ["Button"]:
		th.set_constant("h_separation", cn, 4)
	# --- khoảng cách giữa các dòng/ô trong container: sít lại
	th.set_constant("separation", "VBoxContainer", 2)
	th.set_constant("separation", "HBoxContainer", 4)
	th.set_constant("h_separation", "GridContainer", 3)
	th.set_constant("v_separation", "GridContainer", 3)
	th.set_constant("line_spacing", "Label", -1)
	# --- panel
	th.set_stylebox("panel", "PanelContainer", panel("panel"))
	th.set_stylebox("panel", "Panel", panel("panel"))
	if UiAssets.tex("ui/panels/tooltip.png") != null:
		th.set_stylebox("panel", "TooltipPanel", panel("tooltip"))
	else:   # tooltip nền tối -> chữ trắng
		var tp := StyleBoxFlat.new()
		tp.bg_color = Color(0.08, 0.1, 0.16, 0.95)
		tp.set_corner_radius_all(6)
		tp.set_border_width_all(1)
		tp.border_color = Color(0.35, 0.4, 0.55)
		tp.content_margin_left = 8
		tp.content_margin_right = 8
		tp.content_margin_top = 4
		tp.content_margin_bottom = 4
		th.set_stylebox("panel", "TooltipPanel", tp)
	th.set_color("font_color", "TooltipLabel", Color.WHITE)
	return th


## Ô/chip bo góc dùng chung cho theme (nút, ô nhập).
static func _chip(bg: Color, border: Color, bw := 2, radius := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 6    # padding nút nhỏ lại
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	return sb


## Gắn theme vào cửa sổ gốc (gọi 1 lần ở đầu Main._ready): Main.gd -> UiSkin.apply(get_tree().root)
static func apply(win: Window) -> void:
	win.theme = build_theme()