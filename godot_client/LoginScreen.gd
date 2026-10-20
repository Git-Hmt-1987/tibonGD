class_name LoginScreen
extends Control
## Màn hình trước khi vào game: đăng nhập / tạo tài khoản -> chọn nhân vật (5 slot) -> tạo nhân vật (tên + nghề).
## Chỉ lo giao diện; Main.gd nối tín hiệu với server (PROTOCOL.md §Đăng nhập). Mật khẩu gửi nguyên văn qua ws:// — chỉ dùng
## cục bộ/LAN, ra Internet phải dùng wss://.

signal login_requested(account: String, password: String)
signal register_requested(account: String, password: String)
signal create_requested(slot: int, char_name: String, vocation: int)
signal delete_requested(slot: int, password: String)
signal enter_requested(slot: int)

const VOCS := [["Knight", 4], ["Paladin", 3], ["Druid", 2], ["Sorcerer", 1]]
const VOC_NAMES := {1: "Sorcerer", 2: "Druid", 3: "Paladin", 4: "Knight"}

var _page_login: VBoxContainer
var _page_chars: VBoxContainer
var _page_create: VBoxContainer
var _page_delete: VBoxContainer
var _acc: LineEdit
var _server: LineEdit
var _pw: LineEdit
var _login_msg: Label
var _slots_box: VBoxContainer
var _chars_msg: Label
var _new_name: LineEdit
var _new_voc: OptionButton
var _create_msg: Label
var _del_pw: LineEdit
var _del_msg: Label
var _create_slot := -1
var _delete_slot := -1
var _busy := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.15, 0.2, 0.98)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(380, 0)
	centre.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	root.add_child(_label("DREAM LAND", 22, Color(1, 0.9, 0.5)))
	_build_login(root)
	_build_chars(root)
	_build_create(root)
	_build_delete(root)
	show_login()


# ---------- dựng giao diện ----------

func _label(t: String, size := 14, col := Color(0.9, 0.9, 0.9)) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if size >= 20 else HORIZONTAL_ALIGNMENT_LEFT
	return l


func _msg_label() -> Label:
	var l := _label("", 13, Color(1, 0.55, 0.45))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(340, 0)
	return l


func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.pressed.connect(cb)
	return b


func _build_login(root: VBoxContainer) -> void:
	_page_login = VBoxContainer.new()
	_page_login.add_theme_constant_override("separation", 6)
	root.add_child(_page_login)
	_page_login.add_child(_label("Máy chủ (địa chỉ:cổng):"))
	_server = LineEdit.new()
	_server.max_length = 120
	_server.placeholder_text = "vd 100.64.0.5:7172 hoặc ten-may.ts.net"
	_page_login.add_child(_server)
	_page_login.add_child(_label("Tên đăng nhập:"))
	_acc = LineEdit.new()
	_acc.max_length = 20
	_acc.placeholder_text = "3–20 ký tự: chữ, số, _"
	_page_login.add_child(_acc)
	_page_login.add_child(_label("Mật khẩu:"))
	_pw = LineEdit.new()
	_pw.secret = true
	_pw.max_length = 64
	_pw.placeholder_text = "ít nhất 6 ký tự"
	_page_login.add_child(_pw)
	_acc.text_submitted.connect(func(_t): _pw.grab_focus())
	_pw.text_submitted.connect(func(_t): _on_login())
	_login_msg = _msg_label()
	_page_login.add_child(_login_msg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_page_login.add_child(row)
	var b1 := _button("Đăng nhập", _on_login)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b1)
	var b2 := _button("Tạo tài khoản", _on_register)
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b2)


func _build_chars(root: VBoxContainer) -> void:
	_page_chars = VBoxContainer.new()
	_page_chars.add_theme_constant_override("separation", 6)
	root.add_child(_page_chars)
	_page_chars.add_child(_label("Chọn nhân vật:"))
	_slots_box = VBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 6)
	_page_chars.add_child(_slots_box)
	_chars_msg = _msg_label()
	_page_chars.add_child(_chars_msg)
	_page_chars.add_child(_button("Đăng xuất tài khoản", func(): show_login()))


func _build_create(root: VBoxContainer) -> void:
	_page_create = VBoxContainer.new()
	_page_create.add_theme_constant_override("separation", 6)
	root.add_child(_page_create)
	_page_create.add_child(_label("Tạo nhân vật mới", 16, Color(1, 0.9, 0.5)))
	_page_create.add_child(_label("Tên nhân vật:"))
	_new_name = LineEdit.new()
	_new_name.max_length = 16
	_new_name.placeholder_text = "3–16 chữ cái, không số"
	_page_create.add_child(_new_name)
	_page_create.add_child(_label("Nghề (không đổi được sau khi tạo):"))
	_new_voc = OptionButton.new()
	for vo in VOCS:
		_new_voc.add_item(vo[0], vo[1])
	_page_create.add_child(_new_voc)
	_create_msg = _msg_label()
	_page_create.add_child(_create_msg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_page_create.add_child(row)
	var ok := _button("Tạo", _on_create)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ok)
	var back := _button("Quay lại", func(): _show_page(_page_chars))
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(back)
	_new_name.text_submitted.connect(func(_t): _on_create())


func _build_delete(root: VBoxContainer) -> void:
	_page_delete = VBoxContainer.new()
	_page_delete.add_theme_constant_override("separation", 6)
	root.add_child(_page_delete)
	_page_delete.add_child(_label("Xoá nhân vật", 16, Color(1, 0.6, 0.5)))
	_page_delete.add_child(_label("Nhập lại mật khẩu để xác nhận. Xoá là mất hẳn."))
	_del_pw = LineEdit.new()
	_del_pw.secret = true
	_del_pw.max_length = 64
	_page_delete.add_child(_del_pw)
	_del_msg = _msg_label()
	_page_delete.add_child(_del_msg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_page_delete.add_child(row)
	var ok := _button("Xoá", _on_delete)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ok)
	var back := _button("Huỷ", func(): _show_page(_page_chars))
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(back)
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
	visible = true
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
	visible = true
	for c in _slots_box.get_children():
		c.queue_free()
	var by_slot := {}
	for c in chars:
		by_slot[int(c.get("slot", -1))] = c
	for i in range(slots):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_slots_box.add_child(row)
		if by_slot.has(i):
			var c: Dictionary = by_slot[i]
			var play := Button.new()
			play.text = "%s  ·  %s  ·  Lv %d" % [str(c.get("name", "?")), VOC_NAMES.get(int(c.get("vocation", 0)), "?"), int(c.get("level", 1))]
			play.alignment = HORIZONTAL_ALIGNMENT_LEFT
			play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			play.pressed.connect(func(): _on_enter(i))
			row.add_child(play)
			var del := Button.new()
			del.text = "Xoá"
			del.pressed.connect(func(): _open_delete(i))
			row.add_child(del)
		else:
			var add := Button.new()
			add.text = "Slot %d — trống · Tạo nhân vật" % (i + 1)
			add.alignment = HORIZONTAL_ALIGNMENT_LEFT
			add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			add.pressed.connect(func(): _open_create(i))
			row.add_child(add)
	_chars_msg.text = ""
	_show_page(_page_chars)


func hide_screen() -> void:
	visible = false
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
	create_requested.emit(_create_slot, n, _new_voc.get_selected_id())


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
