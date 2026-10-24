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

## Nền panel chung. [SKIN] Có assets/ui/panels/panel.png thì dùng ảnh 9-slice, chưa có thì giao diện tạm cũ (xem UiSkin.panel).
static func panel_style() -> StyleBox:
	return UiSkin.panel("panel")

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

## [SKIN] `skin` = tên thanh ("hp" | "mana" | "stamina" | "exp" | "target"): có assets/ui/bars/<skin>_bg|fill.png thì dùng ảnh, chưa có thì màu tạm `fill`.
static func bar(fill: Color, h := 14.0, skin := "") -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(0, h)
	b.show_percentage = false
	var st := UiSkin.bar_styles(skin, fill)
	b.add_theme_stylebox_override("background", st[0])
	b.add_theme_stylebox_override("fill", st[1])
	return b

## Nhãn chữ trên NỀN SÁNG: màu `col` (viết cho nền tối) tự đổi sang màu tối tương ứng (UiTheme.ink), cỡ chữ +FONT_BUMP.
static func lab(t: String, sz := 12, col := Color(0.9, 0.9, 0.9)) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", UiTheme.fs(sz))
	l.add_theme_color_override("font_color", UiTheme.ink(col))
	return l

## Nhãn giữ NGUYÊN màu/cỡ (dùng trên nền tối: thanh HP, ô hotbar...).
static func lab_raw(t: String, sz := 12, col := Color(0.9, 0.9, 0.9)) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l

## Font đậm dùng cho title các card. [SKIN] có assets/fonts/ui_bold.ttf thì dùng, chưa có thì làm đậm từ font thường như cũ.
static func bold_font() -> Font:
	return UiSkin.font("bold")

## Title card: IN ĐẬM, vàng nhạt (kiểu "Trạng thái"). sz 13 cho Trạng thái/Skills, 12 cho Chat/Battle.
static func title(t: String, sz := 13) -> Label:
	var l := lab(t, sz, Color(0.3, 0.4, 0.7))   # tiêu đề: xanh đậm trên nền sáng; trong header (head_sep) tự thành chữ trắng
	l.add_theme_color_override("font_color", UiTheme.accent_dark())
	l.add_theme_font_override("font", bold_font())
	return l

## Chữ đè lên giữa thanh (có viền đen cho dễ đọc). Trả về Label để cập nhật text.
static func bar_overlay(b: ProgressBar, sz := 10) -> Label:
	var l := lab_raw("--", sz, Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return l

## HEADER panel: bọc `head` (Label tiêu đề hoặc HBox tiêu đề) vào một dải xanh (UiTheme.accent) bo tròn, chữ trắng đậm.
## Gọi SAU khi `head` đã được add vào container cha (con thêm vào head về sau cũng tự được tô kiểu header).
static func head_sep(head: Control) -> Control:
	var par := head.get_parent()
	if par == null:
		return head
	var idx := head.get_index()
	var pc := par.get_parent() as PanelContainer
	var flush := pc != null and par is VBoxContainer and idx == 0
	var band := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.accent()
	if flush:   # header liền khối, sát mép trên/trái/phải panel (bo góc trên khớp viền panel)
		sb.corner_radius_top_left = 11
		sb.corner_radius_top_right = 11
		sb.content_margin_left = 10
		sb.content_margin_right = 8
	else:       # container không phải panel gốc: dải bo tròn nằm trong
		sb.set_corner_radius_all(9)
		sb.content_margin_left = 8
		sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	band.add_theme_stylebox_override("panel", sb)
	band.mouse_filter = Control.MOUSE_FILTER_PASS
	if flush:
		# panel: bỏ lề trong (chỉ chừa độ dày viền) -> [header | thân có lề 6px]
		var base := pc.get_theme_stylebox("panel")
		var ps := base.duplicate() as StyleBox
		var bw := 3.0
		if ps is StyleBoxFlat:
			bw = float((ps as StyleBoxFlat).border_width_left)
		ps.content_margin_left = bw
		ps.content_margin_right = bw
		ps.content_margin_top = bw
		ps.content_margin_bottom = bw
		pc.add_theme_stylebox_override("panel", ps)
		var shell := VBoxContainer.new()
		shell.add_theme_constant_override("separation", 0)
		var body := MarginContainer.new()
		for m in ["left", "right", "top", "bottom"]:
			body.add_theme_constant_override("margin_" + m, 6)
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		pc.remove_child(par)
		pc.add_child(shell)
		shell.add_child(band)
		shell.add_child(body)
		body.add_child(par)
		par.size_flags_vertical = Control.SIZE_EXPAND_FILL
		par.remove_child(head)
	else:
		par.add_child(band)
		par.move_child(band, idx)
		par.remove_child(head)
	band.add_child(head)
	if head is Container:
		head.add_theme_constant_override("separation", 6)
	_style_head(head)
	head.child_entered_tree.connect(func(n: Node): _style_head.call_deferred(n))
	return band

static func _style_head(n: Node) -> void:
	if not is_instance_valid(n):
		return
	if n is Label:
		n.add_theme_color_override("font_color", Color.WHITE)
		n.add_theme_color_override("font_outline_color", UiTheme.accent().darkened(0.3))
		n.add_theme_constant_override("outline_size", 3)
		(n as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER   # tiêu đề căn giữa như thiết kế
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if n.get_theme_font_size("font_size") < 13:
			n.add_theme_font_size_override("font_size", 13)
	elif n is Button and ((n as Button).text == "X" or (n as Button).get_meta("close_btn", false)):   # nút đóng
		var xb := n as Button
		var ctex: Texture2D = UiAssets.icon("btn_close")   # assets/icons/buttons/btn_close.png: có ảnh thì dùng ảnh
		if ctex != null:
			xb.set_meta("close_btn", true)
			xb.text = ""
			xb.icon = ctex
			xb.expand_icon = true
			xb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			xb.custom_minimum_size = Vector2(24, 24)
			xb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
				xb.add_theme_stylebox_override(st, StyleBoxEmpty.new())
			if not xb.mouse_entered.is_connected(_close_hover):
				xb.mouse_entered.connect(_close_hover.bind(xb, true))
				xb.mouse_exited.connect(_close_hover.bind(xb, false))
			return
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color(0.9, 0.27, 0.3)
		rs.set_corner_radius_all(99)
		rs.set_border_width_all(2)
		rs.border_color = Color(1, 0.93, 0.93)
		rs.set_content_margin_all(0)
		var rh: StyleBoxFlat = rs.duplicate()
		rh.bg_color = Color(1.0, 0.4, 0.42)
		for st in ["normal", "disabled", "pressed"]:
			xb.add_theme_stylebox_override(st, rs)
		for st in ["hover", "hover_pressed"]:
			xb.add_theme_stylebox_override(st, rh)
		for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			xb.add_theme_color_override(cn, Color.WHITE)
		xb.custom_minimum_size = Vector2(22, 22)
		xb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	elif n is Button:
		var b := n as Button
		var c0 := Color(1, 1, 1, 0.16)
		for st in ["normal", "disabled"]:
			b.add_theme_stylebox_override(st, _head_chip(c0))
		b.add_theme_stylebox_override("hover", _head_chip(Color(1, 1, 1, 0.32)))
		b.add_theme_stylebox_override("pressed", _head_chip(Color(1, 1, 1, 0.9)))
		b.add_theme_stylebox_override("hover_pressed", _head_chip(Color(1, 1, 1, 0.95)))
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", UiTheme.accent_dark())
		b.add_theme_color_override("font_hover_pressed_color", UiTheme.accent_dark())
		b.add_theme_color_override("font_focus_color", Color.WHITE)
	for c in n.get_children():
		if n is HBoxContainer or n is VBoxContainer or n is Label:
			_style_head(c)

static func _close_hover(b: Button, on: bool) -> void:
	b.modulate = Color(1.2, 1.2, 1.2) if on else Color.WHITE

static func _head_chip(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(7)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb

## Đặt chữ đậm cho một Label/Button tiêu đề.
static func make_bold(c: Control) -> void:
	c.add_theme_font_override("font", bold_font())
