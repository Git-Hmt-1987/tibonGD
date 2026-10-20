class_name HousePanel
extends PanelContainer
## Panel NPC "Nhà" (server house_npc.py, Bước 3B/3D). Click NPC type "house" -> server gửi gói `house_pub`:
##   {id,name,city,city_name,gold,bank,limit,owned,period_days,houses:[{id,key,name,street,side,rect,door,front,beds,size,bed_count,rent,price,owner,status}]}
## status: "free" (mua được) | "mine" | "taken" (người khác giữ) | "limit" (còn trống nhưng account đã đủ nhà).
## Nhà của mình có nút "Khách": mở màn hình danh sách khách (mời theo tên nhân vật / bỏ khách); khách đi qua cửa và ngủ giường được.
## Mua / Trả nhà đều cần bấm 2 lần (lần 1 đổi nút thành "Chắc chắn?") vì tốn tiền / không hoàn tiền.
## Server kiểm mọi điều kiện (tầm, tiền, giới hạn, quyền) và gửi lại `house_pub` sau mỗi thao tác; panel chỉ gửi yêu cầu và vẽ lại.

signal buy_house(npc_id: String, house: String)
signal leave_house(npc_id: String, house: String)
signal guest_add(npc_id: String, house: String, guest: String)
signal guest_del(npc_id: String, house: String, guest: String)
signal closed(npc_id: String)

const PANEL_W := 600.0
const PANEL_H := 480.0
const PER_PAGE := 6

var npc_id := ""
var data := {}
var view := "list"       # "list" = danh sách nhà, "guests" = quản lý khách của nhà guest_house
var guest_house := ""
var armed := ""          # "<buy|leave>:<house_id>" đang chờ bấm lần 2
var title_lab: Label
var money_lab: Label
var info_lab: Label
var rows: VBoxContainer
var pager: Pager

func build() -> void:
	visible = false
	add_theme_stylebox_override("panel", UiKit.panel_style())
	clip_contents = true
	set_anchors_preset(Control.PRESET_TOP_LEFT)   # tự đặt vị trí/kích thước trong _center() (như NpcPanel)
	get_viewport().size_changed.connect(_center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	title_lab = UiKit.lab("Nhà", 15, Color(1.0, 0.85, 0.4))
	title_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_lab)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(hide_panel)
	head.add_child(close_btn)
	money_lab = UiKit.lab("", 13, Color(1.0, 0.9, 0.4))
	v.add_child(money_lab)
	info_lab = UiKit.lab("", 11, Color(0.62, 0.66, 0.72))
	info_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_lab.custom_minimum_size = Vector2(PANEL_W - 24.0, 0)   # label tự xuống dòng PHẢI có bề rộng tối thiểu, không thì cao vô hạn đẩy mất chân trang
	v.add_child(info_lab)
	UiKit.block_world(self)
	var area := VBoxContainer.new()
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.clip_contents = true
	v.add_child(area)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 3)
	area.add_child(rows)
	pager = Pager.new()
	pager.page_changed.connect(func(_p): _refresh())
	v.add_child(pager)
	pager.attach_wheel(area)

## Server gửi `house_pub` (mở NPC, hoặc sau mỗi thao tác): vẽ lại. NPC khác với lần trước thì về trang 1.
func show_panel(msg: Dictionary) -> void:
	if str(msg.get("id", "")) != npc_id:
		pager.page = 0
	npc_id = str(msg.get("id", ""))
	data = msg
	armed = ""
	if str(msg.get("id", "")) != "" and view == "guests" and _guest_house_data().is_empty():
		view = "list"   # nhà không còn là của mình (trả nhà / mất nhà)
	visible = true
	_refresh()
	_center()

## Đặt panel ra GIỮA cửa sổ, vừa khít (thu nhỏ nếu cửa sổ bé hơn), nổi trên các UI khác.
func _center() -> void:
	if not visible:
		return
	var vp := get_viewport_rect().size
	var sz := Vector2(minf(PANEL_W, vp.x - 16.0), minf(PANEL_H, vp.y - 16.0))
	custom_minimum_size = sz
	size = sz
	global_position = ((vp - sz) / 2.0).floor()
	z_index = 100
	if get_parent() != null:
		get_parent().move_child(self, -1)   # vẽ trên cùng trong ui

func hide_panel() -> void:
	if visible:
		visible = false
		closed.emit(npc_id)

func _guest_house_data() -> Dictionary:
	for r in data.get("houses", []):
		if str(r.get("id", "")) == guest_house and str(r.get("status", "")) == "mine":
			return r
	return {}

func _refresh() -> void:
	if view == "guests":
		_refresh_guests()
		return
	pager.visible = true
	var gold := int(data.get("gold", 0))
	var bank := int(data.get("bank", 0))
	title_lab.text = "%s — %s" % [str(data.get("name", "Nhà")), str(data.get("city_name", ""))]
	money_lab.text = "Gold trong túi: %s gp        Bank: %s gp" % [UiKit.fmt_int(gold), UiKit.fmt_int(bank)]
	info_lab.text = "Sở hữu %d/%d nhà · thuê trừ từ Bank mỗi %s ngày · trả nhà không hoàn tiền" % [
		int(data.get("owned", 0)), int(data.get("limit", 1)), _days(float(data.get("period_days", 30.0)))]
	for c in rows.get_children():
		c.queue_free()
	var list: Array = data.get("houses", [])
	pager.set_total(list.size(), PER_PAGE)
	if list.is_empty():
		rows.add_child(UiKit.lab("(Thành phố này chưa có nhà)", 12, Color(0.7, 0.7, 0.7)))
		return
	for r in Pager.slice(list, pager.page, PER_PAGE):
		rows.add_child(_house_row(r))

## Màn hình khách của nhà guest_house: danh sách + ô nhập tên để mời + nút quay lại.
func _refresh_guests() -> void:
	var hd := _guest_house_data()
	for c in rows.get_children():
		c.queue_free()
	pager.visible = false
	pager.set_total(0, PER_PAGE)
	if hd.is_empty():
		view = "list"
		_refresh()
		return
	title_lab.text = "Khách của %s" % str(hd.get("name", ""))
	money_lab.text = "Khách đi qua cửa và ngủ giường được, nhưng không sửa danh sách."
	info_lab.text = "Mời theo TÊN NHÂN VẬT (phải đã tồn tại). Bỏ khách thì họ không vào/ngủ được nữa; đang ở trong nhà thì bị đưa ra cửa."
	var back := Button.new()
	back.text = "‹ Quay lại danh sách nhà"
	back.pressed.connect(func():
		view = "list"
		_refresh())
	rows.add_child(back)
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 6)
	var edit := LineEdit.new()
	edit.placeholder_text = "Tên nhân vật"
	edit.max_length = 30
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(edit)
	var add_btn := Button.new()
	add_btn.text = "Mời"
	var do_add := func():
		var nm := edit.text.strip_edges()
		if nm != "":
			guest_add.emit(npc_id, guest_house, nm)
	add_btn.pressed.connect(do_add)
	edit.text_submitted.connect(func(_t): do_add.call())
	add_row.add_child(add_btn)
	rows.add_child(add_row)
	var guests: Array = hd.get("guests", [])
	if guests.is_empty():
		rows.add_child(UiKit.lab("(Chưa mời ai)", 12, Color(0.7, 0.7, 0.7)))
	for g in guests:
		var gname := str(g)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var gl := UiKit.lab(gname, 12)
		gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(gl)
		var del := Button.new()
		del.text = "Bỏ"
		del.pressed.connect(func(): guest_del.emit(npc_id, guest_house, gname))
		line.add_child(del)
		rows.add_child(line)

static func _days(d: float) -> String:
	return str(int(d)) if is_equal_approx(d, floorf(d)) else "%.1f" % d

func _house_row(r: Dictionary) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var hid := str(r.get("id", ""))
	var status := str(r.get("status", "taken"))
	var nm := "%s  (%s)" % [str(r.get("name", hid)), str(r.get("street", ""))]
	var lab := UiKit.lab(nm, 12)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.custom_minimum_size = Vector2(130, 0)
	lab.clip_text = true
	lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lab.tooltip_text = "%s · %d m² · %d giường · thuê %s gp/kỳ · giá %s gp" % [
		nm, int(r.get("size", 0)), int(r.get("bed_count", 0)), UiKit.fmt_int(int(r.get("rent", 0))), UiKit.fmt_int(int(r.get("price", 0)))]
	h.add_child(lab)
	var det := UiKit.lab("%d m² · %d giường" % [int(r.get("size", 0)), int(r.get("bed_count", 0))], 11, Color(0.62, 0.66, 0.72))
	det.custom_minimum_size = Vector2(100, 0)
	h.add_child(det)
	var price := UiKit.lab("%s gp" % UiKit.fmt_int(int(r.get("price", 0))), 12, Color(1.0, 0.9, 0.4))
	price.custom_minimum_size = Vector2(80, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(price)
	var b := Button.new()
	b.custom_minimum_size = Vector2(120, 0)
	match status:
		"free":
			var key := "buy:" + hid
			b.text = "Chắc chắn?" if armed == key else "Mua"
			b.pressed.connect(func(): _on_press(key, hid, true))
		"mine":
			var key2 := "leave:" + hid
			b.text = "Chắc chắn?" if armed == key2 else "Trả nhà"
			b.pressed.connect(func(): _on_press(key2, hid, false))
			var gb := Button.new()   # đặt TRƯỚC nút Trả nhà trong hàng
			gb.text = "Khách (%d)" % (r.get("guests", []) as Array).size()
			gb.custom_minimum_size = Vector2(80, 0)
			gb.pressed.connect(func():
				view = "guests"
				guest_house = hid
				armed = ""
				_refresh())
			h.add_child(gb)
		"limit":
			b.text = "Đã đủ nhà"
			b.disabled = true
		_:
			var ow = r.get("owner")
			b.text = "Chủ: %s" % str(ow) if ow != null else "Đã bán"
			b.disabled = true
			b.clip_text = true
	h.add_child(b)
	return h

## Bấm lần 1: chờ xác nhận (vẽ lại nút). Bấm lần 2 đúng nhà đó: gửi yêu cầu.
func _on_press(key: String, hid: String, buying: bool) -> void:
	if armed != key:
		armed = key
		_refresh()
		return
	armed = ""
	if buying:
		buy_house.emit(npc_id, hid)
	else:
		leave_house.emit(npc_id, hid)
