class_name RowKit
extends RefCounted
## Bộ dựng chung cho các panel dạng "danh sách thẻ theo dòng" (Hòm đồ, Nhà, ...): thẻ dòng, tab to, nút xanh, ô tiền, icon.
## Bo góc nhỏ (5px), viền mảnh (2px), màu xanh theo UiTheme.accent().

static func row_card(h: int = 56) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := CharPanel._box(Color("#fbf3dc"), Color("#bfae82"), 2, 5)
	sb.set_content_margin_all(5)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(0, h)
	return card


static func card_box() -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := CharPanel._box(Color("#fffdf6"), Color("#c9bfa0"), 2, 5)
	sb.set_content_margin_all(8)
	pc.add_theme_stylebox_override("panel", sb)
	return pc


static func tab(text: String, on: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = on
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 34)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_font_override("font", UiKit.bold_font())
	b.add_theme_stylebox_override("normal", CharPanel._box(Color("#e8dcc0"), Color("#c9b98f"), 2, 5))
	b.add_theme_stylebox_override("hover", CharPanel._box(Color("#f1e7cc"), UiTheme.accent(), 2, 5))
	b.add_theme_stylebox_override("pressed", CharPanel._box(UiTheme.accent(), UiTheme.accent_dark(), 2, 5))
	b.add_theme_stylebox_override("hover_pressed", CharPanel._box(UiTheme.accent(), UiTheme.accent_dark(), 2, 5))
	for cn in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(cn, Color.WHITE)
	return b


## kind: "primary" xanh | "danger" đỏ nhạt | "plain" be. enabled = false -> xám.
static func act_btn(text: String, enabled := true, w := 60, kind := "primary", h := 32) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, h)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_font_override("font", UiKit.bold_font())
	var bg := UiTheme.accent().lightened(0.1)
	var bd := UiTheme.accent_dark()
	var fc := Color.WHITE
	if kind == "danger":
		bg = Color("#d9776e")
		bd = bg.darkened(0.3)
	elif kind == "plain":
		bg = Color("#efe6cc")
		bd = Color("#b9ac85")
		fc = Color("#2a3354")
	b.add_theme_stylebox_override("normal", CharPanel._box(bg, bd, 2, 5))
	b.add_theme_stylebox_override("hover", CharPanel._box(bg.lightened(0.12), bd, 2, 5))
	b.add_theme_stylebox_override("pressed", CharPanel._box(bg.darkened(0.1), bd, 2, 5))
	var gray := Color("#a9acb6")
	b.add_theme_stylebox_override("disabled", CharPanel._box(gray, gray.darkened(0.3), 2, 5))
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(cn, fc)
	b.add_theme_color_override("font_disabled_color", Color.WHITE)
	return b


## Ô số (SpinBox): chữ căn PHẢI cho dễ đọc, đệm hai bên.
static func right_spin(sp: SpinBox) -> SpinBox:
	var le := sp.get_line_edit()
	le.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return sp


## Số tiền: icon xu + số (vàng đậm), căn phải.
static func coin_box(amount: int, w := 0) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.alignment = BoxContainer.ALIGNMENT_END
	h.custom_minimum_size = Vector2(w, 0)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var coin := ActionDock.DockGlyph.new()
	coin.glyph = "coin"
	coin.custom_minimum_size = Vector2(20, 20)
	h.add_child(coin)
	var l := UiKit.lab_raw(UiKit.fmt_int(amount), 14, Color("#b06a00"))
	l.add_theme_font_override("font", UiKit.bold_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(l)
	return h


static func item_icon(iid: int, nm: String, px: int) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", CharPanel._box(Color("#e8dcc0"), Color("#9c8a5e"), 2, 5))
	frame.custom_minimum_size = Vector2(px, px)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic := CharPanel.ItemIcon.new()
	ic.custom_minimum_size = Vector2(px - 6, px - 6)
	ic.set_item(iid, nm)
	frame.add_child(ic)
	return frame


## Cột tên đậm + dòng phụ nhỏ (1 dòng, hover xem đủ).
static func name_box(title: String, sub: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 0)
	var nm := UiKit.lab(title, 14, Color(0.1, 0.1, 0.15))
	nm.add_theme_font_override("font", UiKit.bold_font())
	nm.clip_text = true
	nm.custom_minimum_size = Vector2(60, 0)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.tooltip_text = title
	v.add_child(nm)
	if sub != "":
		var c := UiKit.lab(sub, 11, Color(0.4, 0.4, 0.45))
		c.add_theme_color_override("font_color", UiTheme.muted())
		c.clip_text = true
		c.custom_minimum_size = Vector2(60, 0)
		c.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		c.tooltip_text = sub
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		v.add_child(c)
	return v


## Đặt panel ra GIỮA cửa sổ với cỡ cố định (thu nhỏ nếu cửa sổ bé), nổi trên cùng.
static func center(p: Control, w: float, h: float) -> void:
	if not p.visible:
		return
	var vp := p.get_viewport_rect().size
	var sz := Vector2(minf(w, vp.x - 16.0), minf(h, vp.y - 16.0))
	p.custom_minimum_size = sz
	p.size = sz
	p.global_position = ((vp - sz) / 2.0).floor()
	p.z_index = 100
	if p.get_parent() != null:
		p.get_parent().move_child(p, -1)
