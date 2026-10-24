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

const PANEL_W := 660.0
const PANEL_H := 540.0
const PER_PAGE := 6
const ROW_H := 58
## Nhóm nhà theo diện tích (m²): [giới hạn trên, tên nhóm]. Icon: assets/icons/.../house_<nhóm>.png (chưa có thì vẽ hình tạm).
## Sửa ngưỡng ở đây khi chốt thiết kế.
const TIERS := [[24, "small"], [48, "medium"], [96, "large"], [1000000, "hotel"]]
const TIER_NAMES := {"small": "Nhỏ", "medium": "Vừa", "large": "Lớn", "hotel": "Khách sạn"}

var npc_id := ""
var data := {}
var view := "list"       # "list" = danh sách nhà, "guests" = quản lý khách của nhà guest_house
var guest_house := ""
var armed := ""          # "<buy|leave>:<house_id>" đang chờ bấm lần 2
var title_lab: Label
var gold_lab: Label
var info_lab: Label
var rows: VBoxContainer
var pager: Pager
var bank_tip := ""

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
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	UiKit.head_sep(head)
	title_lab = UiKit.title("Nhà", 17)
	title_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_lab)
	head.add_child(_gold_pill())
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(hide_panel)
	head.add_child(close_btn)
	info_lab = UiKit.lab("", 12, Color(0.4, 0.4, 0.45))
	info_lab.add_theme_color_override("font_color", UiTheme.muted())
	info_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_lab.custom_minimum_size = Vector2(PANEL_W - 24.0, 34)   # label tự xuống dòng PHẢI có bề rộng tối thiểu, không thì cao vô hạn
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
	rows.add_theme_constant_override("separation", 4)
	area.add_child(rows)
	pager = Pager.new()
	pager.page_changed.connect(func(_p): _refresh())
	v.add_child(pager)
	pager.attach_wheel(area)

func _gold_pill() -> Control:
	var p := PanelContainer.new()
	var sb := CharPanel._box(Color("#fffaf0"), Color("#8c7f5a"), 2, 5)
	sb.content_margin_left = 6
	sb.content_margin_right = 10
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	p.add_child(h)
	var coin := ActionDock.DockGlyph.new()
	coin.glyph = "coin"
	coin.custom_minimum_size = Vector2(20, 20)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(coin)
	gold_lab = UiKit.lab_raw("0", 14, Color("#b06a00"))
	gold_lab.add_theme_font_override("font", UiKit.bold_font())
	h.add_child(gold_lab)
	p.tooltip_text = "Gold trong túi"
	return p

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

func _center() -> void:
	RowKit.center(self, PANEL_W, PANEL_H)

func hide_panel() -> void:
	if visible:
		visible = false
		closed.emit(npc_id)

func _guest_house_data() -> Dictionary:
	for r in data.get("houses", []):
		if str(r.get("id", "")) == guest_house and str(r.get("status", "")) == "mine":
			return r
	return {}

func _clear_rows() -> void:
	for c in rows.get_children():
		rows.remove_child(c)   # gỡ ngay để min-size không cộng dồn thẻ cũ
		c.queue_free()

func _refresh() -> void:
	if view == "guests":
		_refresh_guests()
		return
	pager.visible = true
	var gold := int(data.get("gold", 0))
	var bank := int(data.get("bank", 0))
	title_lab.text = "%s — %s" % [str(data.get("name", "Nhà")), str(data.get("city_name", ""))]
	gold_lab.text = UiKit.fmt_int(gold)
	info_lab.text = "Bank: %s gp  ·  Sở hữu %d/%d nhà  ·  Thuê trừ từ Bank mỗi %s ngày  ·  Trả nhà không hoàn tiền" % [
		UiKit.fmt_int(bank), int(data.get("owned", 0)), int(data.get("limit", 1)), _days(float(data.get("period_days", 30.0)))]
	_clear_rows()
	var list: Array = data.get("houses", [])
	pager.set_total(list.size(), PER_PAGE)
	if list.is_empty():
		rows.add_child(UiKit.lab("(Thành phố này chưa có nhà)", 13, Color(0.4, 0.4, 0.45)))
	else:
		for r in Pager.slice(list, pager.page, PER_PAGE):
			rows.add_child(_house_row(r))
	_center()
	call_deferred("_center")

## Màn hình khách của nhà guest_house: danh sách + ô nhập tên để mời + nút quay lại.
func _refresh_guests() -> void:
	var hd := _guest_house_data()
	_clear_rows()
	pager.visible = false
	pager.set_total(0, PER_PAGE)
	if hd.is_empty():
		view = "list"
		_refresh()
		return
	title_lab.text = "Khách của %s" % str(hd.get("name", ""))
	info_lab.text = "Mời theo TÊN NHÂN VẬT (phải đã tồn tại). Khách đi qua cửa và ngủ giường được. Bỏ khách thì họ không vào/ngủ được nữa; đang ở trong nhà thì bị đưa ra cửa."
	var back := RowKit.act_btn("‹ Quay lại danh sách nhà", true, 190, "plain", 34)
	back.pressed.connect(func():
		view = "list"
		_refresh())
	rows.add_child(back)
	var add_card := RowKit.row_card(48)
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 6)
	add_card.add_child(add_row)
	var edit := LineEdit.new()
	edit.placeholder_text = "Tên nhân vật"
	edit.max_length = 30
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0, 34)
	add_row.add_child(edit)
	var add_btn := RowKit.act_btn("Mời", true, 70, "primary", 34)
	var do_add := func():
		var nm := edit.text.strip_edges()
		if nm != "":
			guest_add.emit(npc_id, guest_house, nm)
	add_btn.pressed.connect(do_add)
	edit.text_submitted.connect(func(_t): do_add.call())
	add_row.add_child(add_btn)
	rows.add_child(add_card)
	var guests: Array = hd.get("guests", [])
	if guests.is_empty():
		rows.add_child(UiKit.lab("(Chưa mời ai)", 13, Color(0.4, 0.4, 0.45)))
	for g in guests:
		var gname := str(g)
		var card := RowKit.row_card(44)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		card.add_child(line)
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(6, 0)
		line.add_child(pad)
		var gl := UiKit.lab(gname, 14, Color(0.1, 0.1, 0.15))
		gl.add_theme_font_override("font", UiKit.bold_font())
		gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(gl)
		var del := RowKit.act_btn("Bỏ", true, 64, "danger")
		del.pressed.connect(func(): guest_del.emit(npc_id, guest_house, gname))
		line.add_child(del)
		rows.add_child(card)
	_center()
	call_deferred("_center")

static func _days(d: float) -> String:
	return str(int(d)) if is_equal_approx(d, floorf(d)) else "%.1f" % d

static func tier_of(size_m2: int) -> String:
	for t in TIERS:
		if size_m2 <= int(t[0]):
			return str(t[1])
	return "hotel"

func _house_row(r: Dictionary) -> Control:
	var card := RowKit.row_card(ROW_H)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	card.add_child(h)
	var hid := str(r.get("id", ""))
	var status := str(r.get("status", "taken"))
	var sz := int(r.get("size", 0))
	var tier := tier_of(sz)
	var ic := HouseIcon.new()
	ic.setup(tier, status)
	h.add_child(ic)
	var nm := str(r.get("name", hid))
	var street := str(r.get("street", ""))
	var sub := "%d m²  ·  %d giường  ·  Thuê %s gp/kỳ" % [sz, int(r.get("bed_count", 0)), UiKit.fmt_int(int(r.get("rent", 0)))]
	var nb := RowKit.name_box(nm if street == "" else "%s  (%s)" % [nm, street], sub)
	nb.tooltip_text = "%s · nhóm %s · %d m² · %d giường · thuê %s gp/kỳ · giá %s gp" % [
		nm, TIER_NAMES.get(tier, tier), sz, int(r.get("bed_count", 0)), UiKit.fmt_int(int(r.get("rent", 0))), UiKit.fmt_int(int(r.get("price", 0)))]
	h.add_child(nb)
	h.add_child(RowKit.coin_box(int(r.get("price", 0)), 96))
	var b: Button
	match status:
		"free":
			var key := "buy:" + hid
			b = RowKit.act_btn("Chắc chắn?" if armed == key else "Mua", true, 104, "danger" if armed == key else "primary")
			b.pressed.connect(func(): _on_press(key, hid, true))
		"mine":
			var gb := RowKit.act_btn("Khách (%d)" % (r.get("guests", []) as Array).size(), true, 86, "plain")   # đặt TRƯỚC nút Trả nhà
			gb.pressed.connect(func():
				view = "guests"
				guest_house = hid
				armed = ""
				_refresh())
			h.add_child(gb)
			var key2 := "leave:" + hid
			b = RowKit.act_btn("Chắc chắn?" if armed == key2 else "Trả nhà", true, 104, "danger")
			b.pressed.connect(func(): _on_press(key2, hid, false))
		"limit":
			b = RowKit.act_btn("Đã đủ nhà", false, 104)
		_:
			var ow = r.get("owner")
			b = RowKit.act_btn("Chủ: %s" % str(ow) if ow != null else "Đã bán", false, 104)
			b.clip_text = true
	h.add_child(b)
	return card

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


## Icon nhà theo nhóm diện tích: có file house_<nhóm>.png (qua IconBtn.load_icon) thì dùng, chưa có thì vẽ hình tạm
## (nhà càng lớn càng rộng/nhiều tầng). Viền/nền đổi theo trạng thái: free xanh nhạt, mine vàng, còn lại xám.
class HouseIcon extends Control:
	var tier := "small"
	var status := "free"
	var tex: Texture2D = null

	func setup(p_tier: String, p_status: String) -> void:
		tier = p_tier
		status = p_status
		tex = IconBtn.load_icon("house_" + tier)
		custom_minimum_size = Vector2(46, 46)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var bg := Color("#e8dcc0")
		var bd := Color("#9c8a5e")
		if status == "mine":
			bg = Color("#fff0b8")
			bd = Color("#c9a24a")
		elif status == "free":
			bg = UiTheme.accent_light()
			bd = UiTheme.accent()
		draw_style_box(CharPanel._box(bg, bd, 2, 5), Rect2(Vector2.ZERO, size))
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(4, 4), size - Vector2(8, 8)), false)
			return
		var wall := Color("#c9b48a") if status != "taken" else Color("#a9a39a")
		var roof := Color("#b5533c") if status != "taken" else Color("#8d8880")
		var c := size * 0.5
		var floors := {"small": 1, "medium": 1, "large": 2, "hotel": 3}.get(tier, 1) as int
		var w := {"small": 16.0, "medium": 22.0, "large": 26.0, "hotel": 30.0}.get(tier, 18.0) as float
		var fh := 9.0
		var base_y := size.y - 8.0
		var top_y := base_y - fh * floors
		draw_rect(Rect2(c.x - w * 0.5, top_y, w, fh * floors), wall)
		draw_rect(Rect2(c.x - w * 0.5, top_y, w, fh * floors), wall.darkened(0.35), false, 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(c.x - w * 0.5 - 3, top_y), Vector2(c.x, top_y - 10), Vector2(c.x + w * 0.5 + 3, top_y)]), roof)
		draw_rect(Rect2(c.x - 3, base_y - 8, 6, 8), Color("#6b4a2a"))
		if floors > 1:
			for i in floors:
				draw_rect(Rect2(c.x - w * 0.5 + 3, top_y + 2 + i * fh, 4, 4), Color("#f7e9a8"))
				draw_rect(Rect2(c.x + w * 0.5 - 7, top_y + 2 + i * fh, 4, 4), Color("#f7e9a8"))
