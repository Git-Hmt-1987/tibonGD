class_name HotSlot
extends Button
## Một ô hotbar: icon/chữ tạm, nhãn phím (F1..F12), số lượng/mana, lớp phủ cooldown.
## Click trái: ô có đồ -> dùng, ô trống -> mở bảng gán. Chuột phải: mở bảng gán/đổi/xoá.

signal activated(idx: int)
signal assign_requested(idx: int)

const GOLD_HOVER := Color("#e0b84f")
var idx := 0
var kind := ""   # "" | "item" | "spell"
var ref := ""    # id item (chuỗi số) hoặc id spell
var key_lab: Label
var cnt_lab: Label
var cd_rect: ColorRect
var cd_from := 0.0   # giây (đồng hồ Time.get_ticks_msec)
var cd_until := 0.0

func setup(i: int, key_text: String) -> void:
	idx = i
	custom_minimum_size = Vector2(Hotbar.SLOT_W, Hotbar.SLOT_W)
	focus_mode = Control.FOCUS_NONE
	clip_text = true
	add_theme_font_size_override("font_size", 10)
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(cn, Color("#e6e6ea"))
	cnt_lab = _corner_label("", HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM, Color.WHITE)
	cnt_lab.offset_right = -4
	cnt_lab.offset_bottom = -2
	# nhãn phím: viên thuốc trắng nằm vắt lên mép trên ô (như mẫu)
	key_lab = Label.new()
	key_lab.text = key_text
	key_lab.add_theme_font_size_override("font_size", 10)
	key_lab.add_theme_font_override("font", UiKit.bold_font())
	key_lab.add_theme_color_override("font_color", Color.BLACK)
	var ksb := StyleBoxFlat.new()   # ô vuông nền trắng, bo nhẹ, chữ đen
	ksb.bg_color = Color.WHITE
	ksb.set_corner_radius_all(3)
	ksb.content_margin_left = 3
	ksb.content_margin_right = 3
	ksb.content_margin_top = 0
	ksb.content_margin_bottom = 0
	key_lab.add_theme_stylebox_override("normal", ksb)
	key_lab.custom_minimum_size = Vector2(22, 0)
	key_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(key_lab)
	key_lab.set_anchors_preset(Control.PRESET_CENTER_TOP)
	key_lab.grow_horizontal = Control.GROW_DIRECTION_BOTH
	key_lab.offset_top = -Hotbar.KEY_H
	key_lab.offset_bottom = -4
	cd_rect = ColorRect.new()
	cd_rect.color = Color(0, 0, 0, 0.65)
	cd_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_rect.visible = false
	add_child(cd_rect)
	cd_rect.anchor_left = 0.0
	cd_rect.anchor_right = 1.0
	cd_rect.anchor_bottom = 1.0
	cd_rect.anchor_top = 1.0
	cd_rect.offset_left = 2   # thụt vào để không lòi ra góc bo tròn
	cd_rect.offset_right = -2
	cd_rect.offset_top = 0
	cd_rect.offset_bottom = -2
	pressed.connect(_on_pressed)
	gui_input.connect(_on_gui_input)
	set_process(false)
	set_content("", "", "", "", null)

func _corner_label(t: String, ha: HorizontalAlignment, va: VerticalAlignment, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = ha
	l.vertical_alignment = va
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return l

static func _box(border: Color, bg := Color("#26262b"), bw := 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(bw)
	sb.border_color = border
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(2)
	return sb


## Ô trống: dấu "+" mờ ở giữa (như mẫu).
func _draw() -> void:
	if kind != "":
		return
	var c := size * 0.5
	var col := Color("#4a4a53")
	draw_line(c - Vector2(6, 0), c + Vector2(6, 0), col, 2.0, true)
	draw_line(c - Vector2(0, 6), c + Vector2(0, 6), col, 2.0, true)

## label = chữ tạm (khi chưa có icon thật), tex = icon thật nếu có file trong res://icons/
func set_content(p_kind: String, p_ref: String, label: String, tip: String, tex: Texture2D) -> void:
	kind = p_kind
	ref = p_ref
	var border := Color("#3c3c44")   # ô trống: nền đen xám, viền mờ
	var bg := Color("#222226")
	var bw := 1
	if kind == "item" or kind == "spell":
		border = Color("#8c97b8")   # ô có đồ: viền xám xanh sáng hơn
		bg = Color("#2c2c33")
		bw = 2
	# [SKIN] có assets/ui/slots/slot_<kind>_<state>.png / slot_<state>.png thì dùng ảnh, chưa có thì hộp viền màu như cũ
	add_theme_stylebox_override("normal", UiSkin.slot("normal", kind, _box(border, bg, bw)))
	add_theme_stylebox_override("hover", UiSkin.slot("hover", kind, _box(GOLD_HOVER, bg.lightened(0.15), 2)))
	add_theme_stylebox_override("pressed", UiSkin.slot("pressed", kind, _box(GOLD_HOVER, bg.darkened(0.2), 2)))
	if kind == "":
		text = ""
		icon = null
		tooltip_text = "%s — ô trống\nClick hoặc chuột phải: gán item / pot / spell" % key_lab.text
		cnt_lab.text = ""
		modulate = Color.WHITE
		queue_redraw()
		return
	modulate = Color.WHITE
	queue_redraw()
	tooltip_text = tip
	if tex != null:
		icon = tex
		expand_icon = true
		text = ""
	else:
		icon = null
		text = label

func set_count(t: String, dim: bool) -> void:
	cnt_lab.text = t
	if kind != "":
		modulate = Color(1, 1, 1, 0.45) if dim else Color.WHITE

func start_cooldown(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now + seconds <= cd_until:
		return  # đang có cooldown dài hơn
	cd_from = now
	cd_until = now + seconds
	cd_rect.visible = true
	set_process(true)

func _process(_dt: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now >= cd_until:
		cd_rect.visible = false
		set_process(false)
		return
	var frac := (cd_until - now) / maxf(0.001, cd_until - cd_from)
	cd_rect.anchor_top = 1.0 - clampf(frac, 0.0, 1.0)

func _on_pressed() -> void:
	if kind == "":
		assign_requested.emit(idx)
	else:
		activated.emit(idx)

func _on_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		assign_requested.emit(idx)
		accept_event()