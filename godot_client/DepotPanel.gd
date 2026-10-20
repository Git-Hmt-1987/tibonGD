class_name DepotPanel
extends PanelContainer
## Panel Hòm đồ + Bank (server depot.py / wallet.py). Click Hòm (NPC type "depot") -> server gửi gói `depot_pub`:
##   {id,name,city,city_name,gold,bank,cap,pack:[{id,name,n,cat,w}],depot:[...],used,limit}.
## Hòm đồ chính là Bank: phần TIỀN gửi/rút gold giữa túi và Bank (Bank dùng chung mọi thành phố, hiện cả ở panel Character).
## Phần ĐỒ: tab "Gửi đồ" (túi -> Hòm của thành phố này) và "Lấy đồ" (Hòm -> túi, server kiểm capacity).
## Server kiểm tầm / tiền / đồ / capacity / giới hạn Hòm và gửi lại `depot_pub` sau mỗi thao tác; panel chỉ gửi yêu cầu và vẽ lại.

signal put_item(npc_id: String, item: int, n: int)
signal take_item(npc_id: String, item: int, n: int)
signal put_gold(npc_id: String, n: int)
signal take_gold(npc_id: String, n: int)
signal closed(npc_id: String)

const PANEL_W := 560.0
const PANEL_H := 500.0
const PER_PAGE := 7

var npc_id := ""
var tab := "put"   # "put" = gửi đồ vào Hòm, "take" = lấy đồ ra
var data := {}
var title_lab: Label
var money_lab: Label
var cap_lab: Label
var used_lab: Label
var gold_spin: SpinBox
var btn_put_gold: Button
var btn_take_gold: Button
var btn_put_all: Button
var btn_take_all: Button
var tab_btns := {}
var rows: VBoxContainer
var pager: Pager

func build() -> void:
	visible = false
	add_theme_stylebox_override("panel", UiKit.panel_style())
	set_anchors_preset(Control.PRESET_TOP_LEFT)   # tự đặt vị trí/kích thước trong _center() (như NpcPanel)
	get_viewport().size_changed.connect(_center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	title_lab = UiKit.lab("Hòm đồ", 15, Color(1.0, 0.85, 0.4))
	title_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_lab)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(hide_panel)
	head.add_child(close_btn)
	money_lab = UiKit.lab("", 13, Color(1.0, 0.9, 0.4))
	v.add_child(money_lab)
	cap_lab = UiKit.lab("", 11, Color(0.62, 0.66, 0.72))
	v.add_child(cap_lab)
	# --- hàng tiền: gửi / rút gold ---
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 4)
	v.add_child(mrow)
	mrow.add_child(UiKit.lab("Tiền:", 12))
	gold_spin = SpinBox.new()
	gold_spin.min_value = 1
	gold_spin.max_value = 1
	gold_spin.value = 1
	gold_spin.custom_minimum_size = Vector2(110, 0)
	mrow.add_child(gold_spin)
	btn_put_gold = Button.new()
	btn_put_gold.text = "Gửi vào Bank"
	btn_put_gold.pressed.connect(func(): _emit_gold(true, false))
	mrow.add_child(btn_put_gold)
	btn_take_gold = Button.new()
	btn_take_gold.text = "Rút ra"
	btn_take_gold.pressed.connect(func(): _emit_gold(false, false))
	mrow.add_child(btn_take_gold)
	btn_put_all = Button.new()
	btn_put_all.text = "Gửi hết"
	btn_put_all.pressed.connect(func(): _emit_gold(true, true))
	mrow.add_child(btn_put_all)
	btn_take_all = Button.new()
	btn_take_all.text = "Rút hết"
	btn_take_all.pressed.connect(func(): _emit_gold(false, true))
	mrow.add_child(btn_take_all)
	# --- tab đồ ---
	var tabs := HBoxContainer.new()
	v.add_child(tabs)
	var grp := ButtonGroup.new()
	for t in [["put", "Gửi đồ vào Hòm"], ["take", "Lấy đồ ra"]]:
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
	used_lab = UiKit.lab("", 11, Color(0.62, 0.66, 0.72))
	v.add_child(used_lab)
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

## Server gửi `depot_pub` (mở Hòm, hoặc sau mỗi thao tác): vẽ lại. Hòm khác với lần trước thì về tab "Gửi đồ".
func show_panel(msg: Dictionary) -> void:
	if str(msg.get("id", "")) != npc_id:
		tab = "put"
		(tab_btns["put"] as Button).button_pressed = true
		pager.page = 0
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

func hide_panel() -> void:
	if visible:
		visible = false
		closed.emit(npc_id)

func _set_tab(key: String) -> void:
	tab = key
	pager.page = 0
	_refresh()

func _refresh() -> void:
	var gold := int(data.get("gold", 0))
	var bank := int(data.get("bank", 0))
	title_lab.text = "%s — %s" % [str(data.get("name", "Hòm đồ")), str(data.get("city_name", ""))]
	money_lab.text = "Gold trong túi: %s gp        Bank: %s gp" % [UiKit.fmt_int(gold), UiKit.fmt_int(bank)]
	cap_lab.text = "Sức chứa còn: %.2f oz  ·  Bank dùng chung mọi thành phố, đồ trong Hòm riêng từng thành phố" % (float(data.get("cap", 0)) / 100.0)
	gold_spin.max_value = maxi(1, maxi(gold, bank))
	gold_spin.value = clampi(int(gold_spin.value), 1, int(gold_spin.max_value))
	btn_put_gold.disabled = gold <= 0
	btn_put_all.disabled = gold <= 0
	btn_take_gold.disabled = bank <= 0
	btn_take_all.disabled = bank <= 0
	used_lab.text = "Hòm %s: %d / %d ô" % [str(data.get("city_name", "")), int(data.get("used", 0)), int(data.get("limit", 0))]
	for c in rows.get_children():
		c.queue_free()
	var list: Array = data.get("pack" if tab == "put" else "depot", [])
	pager.set_total(list.size(), PER_PAGE)
	if list.is_empty():
		rows.add_child(UiKit.lab("(Túi không có đồ để gửi)" if tab == "put" else "(Hòm trống)", 12, Color(0.7, 0.7, 0.7)))
		return
	for r in Pager.slice(list, pager.page, PER_PAGE):
		rows.add_child(_item_row(r))

func _item_row(r: Dictionary) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var iid := int(r.get("id", 0))
	var n := maxi(1, int(r.get("n", 1)))
	var nm := str(r.get("name", ""))
	if nm == "" or nm == str(iid):
		nm = TibiaUI.name_of(iid)
	var lab := UiKit.lab("%s  x%s" % [nm, UiKit.fmt_int(n)], 12)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.custom_minimum_size = Vector2(150, 0)
	lab.clip_text = true
	lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lab.tooltip_text = "%s [%s] · %.2f oz mỗi cái" % [nm, str(r.get("cat", "others")), float(r.get("w", 0)) / 100.0]
	h.add_child(lab)
	var sp := SpinBox.new()
	sp.min_value = 1
	sp.max_value = n
	sp.value = 1
	sp.custom_minimum_size = Vector2(72, 0)
	h.add_child(sp)
	var putting := tab == "put"
	var b := Button.new()
	b.text = "Gửi" if putting else "Lấy"
	b.pressed.connect(func():
		sp.apply()
		_emit_item(putting, iid, int(sp.value)))
	h.add_child(b)
	var ball := Button.new()
	ball.text = "Tất cả"
	ball.pressed.connect(func(): _emit_item(putting, iid, n))
	h.add_child(ball)
	return h

func _emit_item(putting: bool, iid: int, n: int) -> void:
	if iid <= 0 or n <= 0:
		return
	if putting:
		put_item.emit(npc_id, iid, n)
	else:
		take_item.emit(npc_id, iid, n)

## deposit = true: gửi gold túi -> Bank; false: rút Bank -> túi. all_of_it: lấy hết số đang có thay vì số trong ô nhập.
func _emit_gold(deposit: bool, all_of_it: bool) -> void:
	var n := int(data.get("gold", 0)) if deposit else int(data.get("bank", 0))
	if not all_of_it:
		gold_spin.apply()
		n = int(gold_spin.value)
	if n <= 0:
		return
	if deposit:
		put_gold.emit(npc_id, n)
	else:
		take_gold.emit(npc_id, n)
