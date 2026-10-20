class_name NpcPanel
extends PanelContainer
## Panel NPC (làn E): click NPC -> hộp thoại 2 tab Mua / Bán (không hội thoại). Dữ liệu từ gói `npc_shop`
## (PROTOCOL §Làn E): buy[] / sell[] là item {id,name,price,w,vocs?,have?} hoặc spell {spell,name,words,price,level,prem,known}.
## Server kiểm tra tầm/tiền/capacity; panel chỉ gửi yêu cầu và vẽ lại khi server gửi `npc_shop` mới.

signal buy_item(npc_id: String, item: int, n: int)
signal buy_spell(npc_id: String, spell: String)
signal sell_item(npc_id: String, item: int, n: int)
signal travel(npc_id: String, map_id: String)   # NPC Dịch Chuyển: đi tới thành phố map_id
signal closed(npc_id: String)

const MAX_QTY := 100   # mirror server npc.MAX_QTY
const PANEL_W := 540.0
const PANEL_H := 460.0
const PER_PAGE := 7    # số hàng mỗi trang (hàng spell có caption cao hơn -> chừa chỗ)

var npc_id := ""
var tab := "buy"
var data := {}
var title_lab: Label
var gold_lab: Label
var tab_btns := {}
var tabs_box: HBoxContainer
var rows: VBoxContainer
var pager: Pager

func build() -> void:
	visible = false
	add_theme_stylebox_override("panel", UiKit.panel_style())
	set_anchors_preset(Control.PRESET_TOP_LEFT)   # tự đặt vị trí/kích thước trong _center() (không phụ thuộc anchor của parent)
	get_viewport().size_changed.connect(_center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	title_lab = UiKit.lab("NPC", 15, Color(1.0, 0.85, 0.4))
	title_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_lab)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(hide_shop)
	head.add_child(close_btn)
	gold_lab = UiKit.lab("", 12, Color(1.0, 0.9, 0.4))
	v.add_child(gold_lab)
	var tabs := HBoxContainer.new()
	tabs_box = tabs
	v.add_child(tabs)
	var grp := ButtonGroup.new()
	for t in [["buy", "Mua"], ["sell", "Bán"]]:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.button_group = grp
		b.button_pressed = (t[0] == tab)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = t[0]
		b.pressed.connect(func(): _set_tab(key))
		tabs.add_child(b)
		tab_btns[key] = b
	UiKit.block_world(self)
	# danh sách theo TRANG (không cuộn): cuộn chuột trên vùng này = lùi/tiến trang, không zoom bản đồ
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

func show_shop(msg: Dictionary) -> void:
	if msg.get("id", "") != npc_id:
		tab = "buy"
		(tab_btns["buy"] as Button).button_pressed = true
		pager.page = 0   # NPC khác: về trang 1
	npc_id = str(msg.get("id", ""))
	data = msg
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

func hide_shop() -> void:
	if visible:
		visible = false
		closed.emit(npc_id)

func _set_tab(key: String) -> void:
	tab = key
	pager.page = 0
	_refresh()

func _refresh() -> void:
	var tele := str(data.get("type", "")) == "teleport"   # Dịch Chuyển: chỉ một danh sách điểm đến, không có tab Mua/Bán
	tabs_box.visible = not tele
	if tele:
		tab = "buy"
	title_lab.text = str(data.get("name", "NPC"))
	var bag_gold := int(data.get("gold", 0))
	var bank := int(data.get("bank", 0))
	var gold := bag_gold + bank   # tiền dùng để thanh toán = gold trong túi + Bank (server wallet.pay: túi trước, thiếu lấy Bank)
	gold_lab.text = "Vàng: %s gp     Bank: %s gp     Sức chứa còn: %.2f oz" % [UiKit.fmt_int(bag_gold), UiKit.fmt_int(bank), float(data.get("cap", 0)) / 100.0]
	for c in rows.get_children():
		c.queue_free()
	var list: Array = data.get(tab, [])
	pager.set_total(list.size(), PER_PAGE)   # giữ trang đang xem sau khi mua/bán (server gửi lại npc_shop)
	if list.is_empty():
		rows.add_child(UiKit.lab("(Không có gì)" if tab == "sell" else "(Hết hàng)", 12, Color(0.7, 0.7, 0.7)))
		return
	for r in Pager.slice(list, pager.page, PER_PAGE):
		if r.has("map"):
			rows.add_child(_travel_row(r, gold))
		elif r.has("spell"):
			rows.add_child(_spell_row(r, gold))
		else:
			rows.add_child(_item_row(r, gold))

func _item_row(r: Dictionary, gold: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var nm := UiKit.lab(str(r.get("name", r.get("id", "?"))), 12)
	_fit_name(nm)
	h.add_child(_name_box(nm, str(r.get("caption", ""))))
	var price := int(r.get("price", 0))
	h.add_child(UiKit.lab("%d gp" % price, 12, Color(1.0, 0.9, 0.4)))
	var buying := tab == "buy"
	var sp := SpinBox.new()
	sp.min_value = 1
	sp.max_value = MAX_QTY if buying else maxi(1, int(r.get("have", 1)))
	sp.value = 1
	sp.custom_minimum_size = Vector2(72, 0)
	h.add_child(sp)
	var b := Button.new()
	b.text = "Mua" if buying else "Bán"
	b.disabled = buying and gold < price
	var iid := int(r.get("id", 0))
	if buying:
		b.pressed.connect(func(): buy_item.emit(npc_id, iid, int(sp.value)))
	else:
		b.pressed.connect(func(): sell_item.emit(npc_id, iid, int(sp.value)))
	h.add_child(b)
	if not buying:   # bán hết số đang có chỉ với một cú bấm
		var ball := Button.new()
		ball.text = "Tất cả"
		var have := maxi(1, int(r.get("have", 1)))
		ball.pressed.connect(func(): sell_item.emit(npc_id, iid, have))
		h.add_child(ball)
	return h

func _travel_row(r: Dictionary, gold: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var rec = r.get("rec", [])
	var nm_txt := str(r.get("name", "?"))
	if rec is Array and rec.size() == 2:
		nm_txt += "   (Lv %d-%d)" % [int(rec[0]), int(rec[1])]   # mức level khuyến nghị của thành phố
	var nm := UiKit.lab(nm_txt, 13)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nm)
	var price := int(r.get("price", 0))
	h.add_child(UiKit.lab("%d gp" % price, 12, Color(1.0, 0.9, 0.4)))
	var b := Button.new()
	var here := bool(r.get("here", false))
	b.text = "Đang ở đây" if here else "Đi"
	b.disabled = here or gold < price
	var mid := str(r.get("map", ""))
	b.pressed.connect(func(): travel.emit(npc_id, mid))
	h.add_child(b)
	return h

func _spell_row(r: Dictionary, gold: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var txt := "%s  (%s)  Lv %d" % [str(r.get("name", "?")), str(r.get("words", "")), int(r.get("level", 1))]
	if bool(r.get("prem", false)):
		txt += "  [Premium]"
	var nm := UiKit.lab(txt, 12)
	_fit_name(nm)
	h.add_child(_name_box(nm, str(r.get("caption", ""))))
	var price := int(r.get("price", 0))
	h.add_child(UiKit.lab("%d gp" % price, 12, Color(1.0, 0.9, 0.4)))
	var b := Button.new()
	var known := bool(r.get("known", false))
	b.text = "Đã học" if known else "Mua"
	b.disabled = known or gold < price
	var sid := str(r.get("spell", ""))
	b.pressed.connect(func(): buy_spell.emit(npc_id, sid))
	h.add_child(b)
	return h

## Cột tên co giãn theo chỗ còn lại, chữ dài thì cắt "..." (hover xem đầy đủ) để giá + nút luôn nằm trong panel.
func _fit_name(l: Label) -> void:
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(120, 0)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

## Cột trái của một hàng: tên (một dòng, cắt "...") + caption nhỏ màu xám bên dưới (tự xuống dòng, hover xem đủ tên).
func _name_box(nm: Label, caption: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.custom_minimum_size = Vector2(150, 0)
	v.add_theme_constant_override("separation", 0)
	nm.tooltip_text = nm.text
	v.add_child(nm)
	if caption != "":
		var c := UiKit.lab(caption, 10, Color(0.62, 0.66, 0.72))
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.custom_minimum_size = Vector2(150, 0)
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(c)
	return v
