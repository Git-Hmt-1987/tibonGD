class_name HotSlot
extends Button
## Một ô hotbar: icon/chữ tạm, nhãn phím (F1..F12), số lượng/mana, lớp phủ cooldown.
## Click trái: ô có đồ -> dùng, ô trống -> mở bảng gán. Chuột phải: mở bảng gán/đổi/xoá.

signal activated(idx: int)
signal assign_requested(idx: int)

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
	custom_minimum_size = Vector2(38, 38)
	focus_mode = Control.FOCUS_NONE
	clip_text = true
	add_theme_font_size_override("font_size", 9)
	add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	key_lab = _corner_label(key_text, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, Color(1, 0.9, 0.4))
	cnt_lab = _corner_label("", HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM, Color.WHITE)
	cd_rect = ColorRect.new()
	cd_rect.color = Color(0, 0, 0, 0.65)
	cd_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_rect.visible = false
	add_child(cd_rect)
	cd_rect.anchor_left = 0.0
	cd_rect.anchor_right = 1.0
	cd_rect.anchor_bottom = 1.0
	cd_rect.anchor_top = 1.0
	cd_rect.offset_left = 0
	cd_rect.offset_right = 0
	cd_rect.offset_top = 0
	cd_rect.offset_bottom = 0
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

static func _box(border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.1, 0.14, 0.92)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(1)
	return sb

## label = chữ tạm (khi chưa có icon thật), tex = icon thật nếu có file trong res://icons/
func set_content(p_kind: String, p_ref: String, label: String, tip: String, tex: Texture2D) -> void:
	kind = p_kind
	ref = p_ref
	var border := Color(0.35, 0.37, 0.45)
	if kind == "item":
		border = Color(0.85, 0.7, 0.3)
	elif kind == "spell":
		border = Color(0.4, 0.65, 1.0)
	add_theme_stylebox_override("normal", _box(border))
	add_theme_stylebox_override("hover", _box(border.lightened(0.35)))
	add_theme_stylebox_override("pressed", _box(border.lightened(0.55)))
	if kind == "":
		text = ""
		icon = null
		tooltip_text = "%s — ô trống\nClick hoặc chuột phải: gán item / pot / spell" % key_lab.text
		cnt_lab.text = ""
		modulate = Color(1, 1, 1, 0.7)
		return
	modulate = Color.WHITE
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
