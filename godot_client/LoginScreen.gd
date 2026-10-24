class_name LoginScreen
extends Control
## Màn hình trước khi vào game: đăng nhập / đăng ký -> chọn nhân vật (5 ô) -> tạo nhân vật (tên + nghề, xem trước nghề).
## Chỉ lo giao diện; Main.gd nối tín hiệu với server (PROTOCOL.md §Đăng nhập). Mật khẩu gửi nguyên văn qua ws:// — chỉ dùng
## cục bộ/LAN, ra Internet phải dùng wss://.
## Ảnh nền: assets/ui/misc/background_login_panel.png (hoặc login_bg.png), phủ kín màn hình.

signal login_requested(account: String, password: String)
signal register_requested(account: String, password: String)
signal create_requested(slot: int, char_name: String, vocation: int)
signal delete_requested(slot: int, password: String)
signal enter_requested(slot: int)

const VOCS := [["Knight", 4], ["Paladin", 3], ["Druid", 2], ["Sorcerer", 1], ["Monk", 9]]
const VOC_NAMES := {1: "Sorcerer", 2: "Druid", 3: "Paladin", 4: "Knight", 9: "Monk"}
const BG_FILES := ["ui/misc/background_login_panel.png", "ui/panels/background_login_panel.png", "ui/background_login_panel.png", "ui/misc/login_bg.png"]
## Thông tin hiển thị khi chọn nghề. stars = [Máu, Mana, Tấn công, Phòng thủ] (1–5, chỉ để so sánh tương đối).
## spells = spell khởi đầu [tên, câu thần chú, mana] (lấy từ spells.json, cấp 1).
const VOC_INFO := {
	4: {"title": "Hiệp sĩ", "focus": "HP · Phòng thủ", "desc": "Chiến binh cận chiến, máu trâu, giữ tuyến đầu cho cả nhóm.", "stars": [5, 1, 4, 5],
		"spells": [["Bruise Bane", "exura infir ico", 10], ["Wound Cleansing", "exura ico (Lv 8)", 40]]},
	3: {"title": "Xạ thủ", "focus": "Tầm xa · Cân bằng", "desc": "Bắn cung từ xa, linh hoạt, vừa đánh vừa hỗ trợ đồng đội.", "stars": [3, 3, 4, 3],
		"spells": [["Arrow Call", "exevo infir con", 10], ["Magic Patch", "exura infir", 6]]},
	2: {"title": "Pháp sư Băng/Đất", "focus": "Hồi phục · Băng/Đất", "desc": "Phép băng và đất, hồi máu tốt, bền bỉ ở hàng sau.", "stars": [2, 5, 3, 2],
		"spells": [["Chill Out", "exevo infir frigo hur", 8], ["Mud Attack", "exori infir tera", 6], ["Magic Patch", "exura infir", 6]]},
	1: {"title": "Pháp sư Lửa/Điện", "focus": "Phép lửa/điện · Sát thương", "desc": "Sát thương phép cao nhất, đổi lại rất mỏng máu.", "stars": [2, 5, 5, 1],
		"spells": [["Scorch", "exevo infir flam hur", 8], ["Buzz", "exori infir vis", 6], ["Magic Patch", "exura infir", 6]]},
	9: {"title": "Võ sư", "focus": "Tay không · Harmony", "desc": "Đấm tay không, tích Harmony để tung chiêu mạnh dần.", "stars": [3, 3, 4, 3],
		"spells": [["Swift Jab", "exori infir pug", 3], ["Tiger Clash", "exori infir nia", 18], ["Magic Patch", "exura infir", 6]]},
}
const GOLD := Color("#e0a82e")
const DANGER := Color("#d9776e")
const R := 5   # bo góc nhỏ

var _root: Control
var _card: PanelContainer
var _page_login: VBoxContainer
var _page_chars: VBoxContainer
var _page_create: VBoxContainer
var _page_delete: VBoxContainer
var _acc: LineEdit
var _server: LineEdit
var _pw: LineEdit
var _login_msg: Label
var _mode := "login"
var _tab_btns := {}
var _login_go: Button
var _slots_box: HBoxContainer
var _slots_lab: Label
var _acc_lab: Label
var _enter_btn: Button
var _del_btn: Button
var _chars_msg: Label
var _slots_n := 5
var _chars: Array = []
var _sel_slot := -1
var _new_name: LineEdit
var _create_msg: Label
var _create_title: Label
var _voc_btns := {}
var _sel_voc := 4
var _pv: Control          # khung xem trước nghề (cột phải)
var _del_pw: LineEdit
var _del_msg: Label
var _create_slot := -1
var _delete_slot := -1
var _busy := false


func _ready() -> void:
	# Main là Node2D nên Control không tự canh theo màn hình: đặt toàn bộ vào CanvasLayer cao nhất (phủ lên mọi panel game).
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	for f in BG_FILES:   # [SKIN] ảnh nền (tùy chọn)
		var bg_tex := UiAssets.tex(f)
		if bg_tex == null:
			for alt in ["res://background_login_panel.png", "res://assets/background_login_panel.png", "res://assets/ui/background_login_panel.png"]:
				if f == BG_FILES[0] and ResourceLoader.exists(alt):
					bg_tex = load(alt)
					break
		if bg_tex != null:
			var bg_img := TextureRect.new()
			bg_img.texture = bg_tex
			bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			bg_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
			_root.add_child(bg_img)
			break
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(centre)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", _box(UiTheme.body(), UiTheme.accent_dark(), 2, 6))
	centre.add_child(_card)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	_card.add_child(root)
	_build_login(root)
	_build_chars(root)
	_build_create(root)
	_build_delete(root)
	show_login()


# ---------- tiện ích dựng giao diện ----------

static func _box(bg: Color, border: Color, bw := 2, radius := 5) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	return sb


func _label(t: String, size := 14, col := Color(0.12, 0.13, 0.2), bold := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", UiTheme.fs(size))
	l.add_theme_color_override("font_color", col)
	if bold:
		l.add_theme_font_override("font", UiKit.bold_font())
	return l


func _msg_label() -> Label:
	var l := _label("", 13, Color("#c0392b"), true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(200, 18)
	return l


## Dải tiêu đề xanh trên đầu panel. Trả về HBox để thêm nút bên phải nếu cần.
func _header(parent: Control, title: String) -> Label:
	var band := PanelContainer.new()
	var sb := _box(UiTheme.accent(), UiTheme.accent_dark(), 0, 0)
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.set_content_margin_all(0)
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	band.add_theme_stylebox_override("panel", sb)
	parent.add_child(band)
	var l := _label(title, 18, Color.WHITE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	band.add_child(l)
	return l


func _body(parent: Control, w: int, pad := 18) -> VBoxContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, pad)
	m.custom_minimum_size = Vector2(w, 0)
	parent.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	return v


func _field(ph: String, secret := false, max_len := 64) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = ph
	e.secret = secret
	e.max_length = max_len
	e.custom_minimum_size = Vector2(0, 36)
	e.add_theme_font_size_override("font_size", UiTheme.fs(14))
	e.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15))
	e.add_theme_color_override("font_placeholder_color", Color(0.55, 0.55, 0.6))
	var sn := _box(Color("#fffdf6"), Color("#c9bfa0"), 2, R)
	var sf := _box(Color("#fffdf6"), UiTheme.accent(), 2, R)
	for sb in [sn, sf]:
		sb.content_margin_left = 12
		sb.content_margin_right = 12
	e.add_theme_stylebox_override("normal", sn)
	e.add_theme_stylebox_override("focus", sf)
	return e


## kind: "primary" (xanh) | "danger" (đỏ nhạt) | "plain" (be, viền xanh)
func _button(t: String, cb: Callable, kind := "primary", h := 38) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_size_override("font_size", UiTheme.fs(14))
	b.add_theme_font_override("font", UiKit.bold_font())
	var bg := UiTheme.accent().lightened(0.1)
	var bd := UiTheme.accent_dark()
	var fc := Color.WHITE
	if kind == "danger":
		bg = DANGER
		bd = DANGER.darkened(0.3)
	elif kind == "plain":
		bg = Color("#efe6cc")
		bd = Color("#b9ac85")
		fc = Color("#2a3354")
	b.add_theme_stylebox_override("normal", _box(bg, bd, 2, R))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.12), bd, 2, R))
	b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.1), bd, 2, R))
	var gray := Color("#a9acb6")
	b.add_theme_stylebox_override("disabled", _box(gray, gray.darkened(0.3), 2, R))
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(cn, fc if cn != "font_disabled_color" else Color.WHITE)
	b.pressed.connect(cb)
	return b


func _sep() -> Control:
	var c := ColorRect.new()
	c.color = Color("#d9cfae")
	c.custom_minimum_size = Vector2(0, 2)
	return c


# ---------- trang đăng nhập ----------

func _build_login(root: VBoxContainer) -> void:
	_page_login = VBoxContainer.new()
	root.add_child(_page_login)
	_header(_page_login, "Tài khoản người chơi")
	var v := _body(_page_login, 380)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	for t in [["login", "Đăng nhập"], ["register", "Đăng ký"]]:
		var key: String = t[0]
		var tb := _button(t[1], func(): _set_mode(key), "plain", 36)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tb)
		_tab_btns[key] = tb
	v.add_child(_label("Tên đăng nhập", 13, UiTheme.muted(), true))
	_acc = _field("3–20 ký tự: chữ, số, _", false, 20)
	v.add_child(_acc)
	v.add_child(_label("Mật khẩu", 13, UiTheme.muted(), true))
	_pw = _field("ít nhất 6 ký tự", true)
	v.add_child(_pw)
	_acc.text_submitted.connect(func(_t): _pw.grab_focus())
	_pw.text_submitted.connect(func(_t): _on_login_go())
	_login_msg = _msg_label()
	v.add_child(_login_msg)
	_login_go = _button("Đăng nhập", _on_login_go, "primary", 42)
	v.add_child(_login_go)
	v.add_child(_sep())
	v.add_child(_label("Máy chủ (địa chỉ:cổng)", 12, UiTheme.muted(), true))
	_server = _field("vd 100.64.0.5:7172 hoặc ten-may.ts.net", false, 120)
	v.add_child(_server)
	_set_mode("login")


func _set_mode(m: String) -> void:
	_mode = m
	for k in _tab_btns:
		var b: Button = _tab_btns[k]
		var on: bool = (k == m)
		var bg := UiTheme.accent().lightened(0.1) if on else Color("#efe6cc")
		var bd := UiTheme.accent_dark() if on else Color("#b9ac85")
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, _box(bg if st != "hover" else bg.lightened(0.1), bd, 2, R))
		for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(cn, Color.WHITE if on else Color("#2a3354"))
	if _login_go != null:
		_login_go.text = "Đăng nhập" if m == "login" else "Tạo tài khoản"
	if _login_msg != null:
		_login_msg.text = ""


func _on_login_go() -> void:
	if _mode == "login":
		_on_login()
	else:
		_on_register()


# ---------- trang chọn nhân vật ----------

func _build_chars(root: VBoxContainer) -> void:
	_page_chars = VBoxContainer.new()
	root.add_child(_page_chars)
	_header(_page_chars, "Chọn nhân vật")
	var v := _body(_page_chars, 780)
	var top := HBoxContainer.new()
	v.add_child(top)
	_acc_lab = _label("", 13, UiTheme.muted(), true)
	_acc_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_acc_lab)
	var out := _button("Đăng xuất", func(): show_login(), "plain", 30)
	out.custom_minimum_size = Vector2(96, 30)
	top.add_child(out)
	_slots_box = HBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 10)
	v.add_child(_slots_box)
	_chars_msg = _msg_label()
	v.add_child(_chars_msg)
	var bot := HBoxContainer.new()
	bot.add_theme_constant_override("separation", 8)
	v.add_child(bot)
	_slots_lab = _label("", 13, UiTheme.muted(), true)
	_slots_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slots_lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bot.add_child(_slots_lab)
	_del_btn = _button("Xoá nhân vật", func(): if _sel_slot >= 0: _open_delete(_sel_slot), "danger", 38)
	_del_btn.custom_minimum_size = Vector2(130, 38)
	bot.add_child(_del_btn)
	_enter_btn = _button("Vào game ▸", func(): if _sel_slot >= 0: _on_enter(_sel_slot), "primary", 38)
	_enter_btn.custom_minimum_size = Vector2(140, 38)
	bot.add_child(_enter_btn)


func _char_of(slot: int) -> Dictionary:
	for c in _chars:
		if int(c.get("slot", -1)) == slot:
			return c
	return {}


func _rebuild_slots() -> void:
	for c in _slots_box.get_children():
		_slots_box.remove_child(c)
		c.queue_free()
	for i in range(_slots_n):
		_slots_box.add_child(_slot_card(i))
	_slots_lab.text = "%d/%d ô nhân vật" % [_chars.size(), _slots_n]
	var has := _sel_slot >= 0 and not _char_of(_sel_slot).is_empty()
	_enter_btn.disabled = not has
	_del_btn.disabled = not has


func _slot_card(i: int) -> Control:
	var c := _char_of(i)
	var filled := not c.is_empty()
	var sel := filled and i == _sel_slot
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 210)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := Color("#fff4d0") if sel else Color("#fffdf6")
	var bd := GOLD if sel else Color("#c9bfa0")
	b.add_theme_stylebox_override("normal", _box(bg, bd, 2, R))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.0) if sel else Color("#f4f0ff"), GOLD if sel else UiTheme.accent(), 2, R))
	b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.05), bd, 2, R))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.offset_top = 6
	v.offset_bottom = -6
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	b.add_child(v)
	v.add_child(_label("Ô %d" % (i + 1), 11, UiTheme.muted(), true))
	if filled:
		var voc := int(c.get("vocation", 0))
		var pv := VocView.new()
		pv.voc = voc
		pv.zoom = 1.6
		pv.bg = Color("#ffe6ee") if sel else UiTheme.accent_light()
		pv.custom_minimum_size = Vector2(0, 96)
		pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(pv)
		var nm := _label(str(c.get("name", "?")), 14, Color(0.1, 0.1, 0.15), true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(nm)
		var vl := _label(VOC_NAMES.get(voc, "?"), 12, UiTheme.accent_dark(), true)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(vl)
		var lv := _label("Level %d" % int(c.get("level", 1)), 12, UiTheme.muted(), true)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(lv)
		b.pressed.connect(func():
			_sel_slot = i
			_rebuild_slots())
		b.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.double_click and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_enter(i))
	else:
		var sp := Control.new()
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(sp)
		var plus := _label("+", 40, UiTheme.accent(), true)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(plus)
		var t := _label("Tạo nhân vật mới", 12, UiTheme.muted(), true)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(t)
		var sp2 := Control.new()
		sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sp2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(sp2)
		b.pressed.connect(func(): _open_create(i))
	return b


# ---------- trang tạo nhân vật ----------

func _build_create(root: VBoxContainer) -> void:
	_page_create = VBoxContainer.new()
	root.add_child(_page_create)
	_create_title = _header(_page_create, "Tạo nhân vật")
	var v := _body(_page_create, 780)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	v.add_child(cols)
	# --- cột trái: tên + chọn nghề
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.custom_minimum_size = Vector2(340, 0)
	cols.add_child(left)
	left.add_child(_label("Tên nhân vật", 13, UiTheme.muted(), true))
	_new_name = _field("3–16 chữ cái, không số", false, 16)
	left.add_child(_new_name)
	_new_name.text_submitted.connect(func(_t): _on_create())
	var hint := _label("Chỉ chữ cái, 3–16 ký tự. Nghề không đổi được sau khi tạo.", 11, UiTheme.muted())
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(hint)
	left.add_child(_label("Chọn nghề", 13, UiTheme.muted(), true))
	for vo in VOCS:
		var vid: int = vo[1]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 62)
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 6
		h.offset_right = -8
		h.offset_top = 5
		h.offset_bottom = -5
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 10)
		b.add_child(h)
		var th := VocView.new()
		th.voc = vid
		th.zoom = 0.85
		th.custom_minimum_size = Vector2(52, 0)
		th.bg = UiTheme.accent_light()
		th.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(th)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tv.add_theme_constant_override("separation", 0)
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(tv)
		var info: Dictionary = VOC_INFO[vid]
		var l1 := _label("%s  ·  %s" % [info["title"], vo[0]], 14, Color(0.1, 0.1, 0.15), true)
		l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(l1)
		var l2 := _label(str(info["focus"]), 12, Color("#a06a00"), true)
		l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(l2)
		b.pressed.connect(func(): _pick_voc(vid))
		left.add_child(b)
		_voc_btns[vid] = b
	# --- cột phải: xem trước nghề
	_pv = VBoxContainer.new()
	_pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pv.add_theme_constant_override("separation", 6)
	cols.add_child(_pv)
	_create_msg = _msg_label()
	v.add_child(_create_msg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var back := _button("◂ Quay lại", func(): _show_page(_page_chars), "plain", 38)
	back.custom_minimum_size = Vector2(120, 38)
	row.add_child(back)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var ok := _button("Tạo nhân vật", _on_create, "primary", 38)
	ok.custom_minimum_size = Vector2(160, 38)
	row.add_child(ok)
	_pick_voc(4)


func _pick_voc(vid: int) -> void:
	_sel_voc = vid
	for k in _voc_btns:
		var b: Button = _voc_btns[k]
		var on: bool = (k == vid)
		var bg := Color("#fff4d0") if on else Color("#fffdf6")
		var bd := GOLD if on else Color("#c9bfa0")
		b.add_theme_stylebox_override("normal", _box(bg, bd, 2, R))
		b.add_theme_stylebox_override("hover", _box(bg, GOLD if on else UiTheme.accent(), 2, R))
		b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.05), bd, 2, R))
	_fill_preview()


func _fill_preview() -> void:
	for c in _pv.get_children():
		_pv.remove_child(c)
		c.queue_free()
	var info: Dictionary = VOC_INFO[_sel_voc]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color("#fffdf6"), Color("#c9bfa0"), 2, R))
	_pv.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	card.add_child(m)
	m.add_child(v)
	var big := VocView.new()
	big.voc = _sel_voc
	big.zoom = 1.9
	big.bg = UiTheme.accent_light()
	big.custom_minimum_size = Vector2(0, 170)
	v.add_child(big)
	var nm := _label("%s  ·  %s" % [info["title"], VOC_NAMES.get(_sel_voc, "")], 17, Color(0.1, 0.1, 0.15), true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var ds := _label(str(info["desc"]), 12, UiTheme.muted())
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ds.custom_minimum_size = Vector2(200, 34)
	v.add_child(ds)
	v.add_child(_sep())
	var stars: Array = info["stars"]
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 4)
	v.add_child(g)
	var names := ["Máu", "Mana", "Tấn công", "Phòng thủ"]
	for i in 4:
		var cell := HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(cell)
		var l := _label(names[i], 12, UiTheme.muted(), true)
		l.custom_minimum_size = Vector2(66, 0)
		cell.add_child(l)
		var bar := StarBar.new()
		bar.n = int(stars[i])
		bar.custom_minimum_size = Vector2(70, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(bar)
	v.add_child(_sep())
	v.add_child(_label("Spell khởi đầu", 13, UiTheme.accent_dark(), true))
	for sp in info["spells"]:
		var r := HBoxContainer.new()
		v.add_child(r)
		var a := _label(str(sp[0]), 13, Color(0.1, 0.1, 0.15), true)
		a.custom_minimum_size = Vector2(110, 0)
		r.add_child(a)
		var w := _label(str(sp[1]), 11, UiTheme.muted())
		w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		w.clip_text = true
		r.add_child(w)
		var mn := _label("%d mana" % int(sp[2]), 11, Color("#2f5fb0"), true)
		r.add_child(mn)


# ---------- trang xoá nhân vật ----------

func _build_delete(root: VBoxContainer) -> void:
	_page_delete = VBoxContainer.new()
	root.add_child(_page_delete)
	_header(_page_delete, "Xoá nhân vật")
	var v := _body(_page_delete, 380)
	var t := _label("Nhập lại mật khẩu để xác nhận. Xoá là mất hẳn.", 13, Color(0.12, 0.13, 0.2))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	_del_pw = _field("Mật khẩu", true)
	v.add_child(_del_pw)
	_del_msg = _msg_label()
	v.add_child(_del_msg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var back := _button("Huỷ", func(): _show_page(_page_chars), "plain", 38)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(back)
	var ok := _button("Xoá", _on_delete, "danger", 38)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ok)
	_del_pw.text_submitted.connect(func(_t): _on_delete())


func _show_page(p: Control) -> void:
	for q in [_page_login, _page_chars, _page_create, _page_delete]:
		q.visible = (q == p)
	_busy = false


# ---------- API cho Main.gd ----------

func set_server(text: String) -> void:
	_server.text = text


## Đọc ô địa chỉ -> URL đầy đủ. "" -> localhost. Đã có ws:// hoặc wss:// thì giữ nguyên.
## Không ghi giao thức: bản web chạy trang https, hoặc tên miền tunnel (*.trycloudflare.com...) -> wss:// (cổng 443 mặc định);
## còn lại ws:// và thiếu cổng -> :7172.
func get_server_url() -> String:
	var t := _server.text.strip_edges()
	if t == "":
		return "ws://127.0.0.1:7172"
	if t.begins_with("ws://") or t.begins_with("wss://"):
		return t
	var host_part := t.split("/")[0]
	var secure := _page_is_https() or host_part.split(":")[0].ends_with(".trycloudflare.com")
	if secure:
		return "wss://" + t
	if not (":" in host_part):
		t = host_part + ":7172"
	return "ws://" + t


static func _page_is_https() -> bool:
	if not OS.has_feature("web"):
		return false
	return str(JavaScriptBridge.eval("location.protocol")) == "https:"


## Bản web: link dạng https://trang/?server=ten.trycloudflare.com tự điền ô máy chủ. Không phải web -> "".
static func server_from_url() -> String:
	if not OS.has_feature("web"):
		return ""
	var v = JavaScriptBridge.eval("new URLSearchParams(location.search).get('server') || ''")
	return str(v).strip_edges()


func show_login(message := "") -> void:
	_root.visible = true
	_pw.text = ""
	_login_msg.text = message
	_show_page(_page_login)
	_acc.grab_focus()


func show_error(text: String) -> void:
	_busy = false
	if _page_login.visible:
		_login_msg.text = text
	elif _page_create.visible:
		_create_msg.text = text
	elif _page_delete.visible:
		_del_msg.text = text
	else:
		_chars_msg.text = text


func show_chars(slots: int, chars: Array) -> void:
	_root.visible = true
	_slots_n = slots
	_chars = chars
	if _char_of(_sel_slot).is_empty():
		_sel_slot = -1
		for i in range(slots):
			if not _char_of(i).is_empty():
				_sel_slot = i
				break
	_acc_lab.text = "Tài khoản: %s" % _acc.text.strip_edges()
	_rebuild_slots()
	_chars_msg.text = ""
	_show_page(_page_chars)


func hide_screen() -> void:
	_root.visible = false
	_pw.text = ""
	_busy = false


# ---------- thao tác ----------

func _on_login() -> void:
	var a := _acc.text.strip_edges()
	if a == "" or _pw.text == "":
		_login_msg.text = "Nhập tên đăng nhập và mật khẩu."
		return
	_login_msg.text = "Đang đăng nhập ..."
	login_requested.emit(a, _pw.text)


func _on_register() -> void:
	var a := _acc.text.strip_edges()
	if a.length() < 3 or _pw.text.length() < 6:
		_login_msg.text = "Tên đăng nhập ≥ 3 ký tự, mật khẩu ≥ 6 ký tự."
		return
	_login_msg.text = "Đang tạo tài khoản ..."
	register_requested.emit(a, _pw.text)


func _open_create(slot: int) -> void:
	_create_slot = slot
	_new_name.text = ""
	_create_msg.text = ""
	_create_title.text = "Tạo nhân vật · Ô %d" % (slot + 1)
	_show_page(_page_create)
	_new_name.grab_focus()


func _on_create() -> void:
	var n := _new_name.text.strip_edges()
	if n.length() < 3:
		_create_msg.text = "Tên nhân vật tối thiểu 3 ký tự."
		return
	if _busy:
		return
	_busy = true
	create_requested.emit(_create_slot, n, _sel_voc)


func _open_delete(slot: int) -> void:
	_delete_slot = slot
	_del_pw.text = ""
	_del_msg.text = ""
	_show_page(_page_delete)
	_del_pw.grab_focus()


func _on_delete() -> void:
	if _del_pw.text == "":
		_del_msg.text = "Nhập mật khẩu để xoá."
		return
	if _busy:
		return
	_busy = true
	delete_requested.emit(_delete_slot, _del_pw.text)


func _on_enter(slot: int) -> void:
	if _busy:
		return
	_busy = true
	_chars_msg.text = "Đang vào game ..."
	enter_requested.emit(slot)


## Hình nghề (idle, hướng xuống) phóng to theo `zoom`, đặt trên nền màu bo nhỏ. Chỉ để trang trí/xem trước.
class VocView extends Control:
	var voc := 4
	var zoom := 1.0
	var bg := Color(0, 0, 0, 0)
	var _t := 0.0

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		if bg.a > 0.0:
			draw_style_box(LoginScreen._box(bg, bg.darkened(0.15), 2, 5), Rect2(Vector2.ZERO, size))
		if not VocSprite.has(voc):
			return
		var tex := VocSprite.texture(voc)
		if tex == null:
			return
		var sp: Dictionary = VocSprite.SPECS[voc]
		var f := VocSprite.frame(voc, VocSprite.State.IDLE, VocSprite.Dir.S, _t)
		var src: Rect2 = f["src"]
		var feet: Vector2 = f["feet"]
		var sc: float = float(sp["scale"]) * 1.5 * zoom
		var base := Vector2(size.x * 0.5, size.y - 6.0)
		var rect := Rect2(base - feet * sc, src.size * sc)
		if f["flip"]:
			rect.position.x = base.x - (src.size.x - feet.x) * sc
			rect.size.x = -src.size.x * sc
		draw_texture_rect_region(tex, rect, src)


## Thanh 5 ô nhỏ (đầy = n).
class StarBar extends Control:
	var n := 3

	func _draw() -> void:
		var w := (size.x - 4.0 * 3.0) / 5.0
		for i in 5:
			var col := Color("#2f5fb0") if i < n else Color("#d9d2bd")
			draw_rect(Rect2(i * (w + 3.0), 2, w, size.y - 4), col)