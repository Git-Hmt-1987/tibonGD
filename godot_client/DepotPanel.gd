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

const PANEL_W := 620.0
const PANEL_H := 540.0
const PER_PAGE := 5
const ROW_H := 54

var npc_id := ""
var tab := "put"   # "put" = gửi đồ vào Hòm, "take" = lấy đồ ra
var data := {}
var title_lab: Label
var gold_lab: Label
var bank_lab: Label
var cap_lab: Label
var used_lab: Label
var gold_spin: SpinBox
var bank_spin: SpinBox
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
	UiKit.head_sep(head)
	title_lab = UiKit.title("Hòm đồ", 17)
	title_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_lab)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(hide_panel)
	head.add_child(close_btn)
	# --- 2 khối tiền riêng: Gold trong túi (gửi vào Bank) | Bank (rút ra túi) ---
	var money := HBoxContainer.new()
	money.add_theme_constant_override("separation", 8)
	v.add_child(money)
	var g := _money_block("Gold trong túi", true)
	money.add_child(g)
	var bk := _money_block("Bank", false)
	money.add_child(bk)
	# --- tab đồ ---
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for t in [["put", "Gửi đồ vào Hòm"], ["take", "Lấy đồ ra"]]:
		var key: String = t[0]
		var b := RowKit.tab(str(t[1]), key == tab)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _set_tab(key))
		tabs.add_child(b)
		tab_btns[key] = b
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
	var foot := HBoxContainer.new()
	v.add_child(foot)
	var fl := VBoxContainer.new()
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fl.add_theme_constant_override("separation", 0)
	foot.add_child(fl)
	used_lab = _small("")
	fl.add_child(used_lab)
	cap_lab = _small("")
	fl.add_child(cap_lab)
	pager = Pager.new()
	pager.page_changed.connect(func(_p): _refresh())
	foot.add_child(pager)
	pager.attach_wheel(area)

func _small(t: String) -> Label:
	var l := UiKit.lab(t, 11, Color(0.4, 0.4, 0.45))
	l.add_theme_color_override("font_color", UiTheme.muted())
	l.clip_text = true
	l.custom_minimum_size = Vector2(60, 0)
	return l

## Khối tiền: nhãn + số (icon xu, căn phải) + ô nhập số + nút. Gold: Gửi vào Bank / Gửi hết. Bank: Rút ra / Rút hết.
func _money_block(label: String, is_gold: bool) -> Control:
	var p := RowKit.card_box()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)
	var l := UiKit.lab(label, 13, Color(0.1, 0.1, 0.15))
	l.add_theme_font_override("font", UiKit.bold_font())
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(l)
	var coin := ActionDock.DockGlyph.new()
	coin.glyph = "coin"
	coin.custom_minimum_size = Vector2(20, 20)
	top.add_child(coin)
	var num := UiKit.lab_raw("0", 15, Color("#b06a00"))
	num.add_theme_font_override("font", UiKit.bold_font())
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num.custom_minimum_size = Vector2(84, 0)
	top.add_child(num)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	v.add_child(r)
	var sp := RowKit.right_spin(SpinBox.new())
	sp.min_value = 1
	sp.max_value = 1
	sp.value = 1
	sp.custom_minimum_size = Vector2(96, 32)
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(sp)
	var b1 := RowKit.act_btn("Gửi vào" if is_gold else "Rút ra", true, 70)
	b1.pressed.connect(func(): _emit_gold(is_gold, false))
	r.add_child(b1)
	var b2 := RowKit.act_btn("Gửi hết" if is_gold else "Rút hết", true, 70, "plain")
	b2.pressed.connect(func(): _emit_gold(is_gold, true))
	r.add_child(b2)
	if is_gold:
		gold_lab = num
		gold_spin = sp
		btn_put_gold = b1
		btn_put_all = b2
	else:
		bank_lab = num
		bank_spin = sp
		btn_take_gold = b1
		btn_take_all = b2
	return p

## Server gửi `depot_pub` (mở Hòm, hoặc sau mỗi thao tác): vẽ lại. Hòm khác với lần trước thì về tab "Gửi đồ".
func show_panel(msg: Dictionary) -> void:
	if str(msg.get("id", "")) != npc_id:
		tab = "put"
		_sync_tabs()
		pager.page = 0
	npc_id = str(msg.get("id", ""))
	data = msg
	visible = true
	_refresh()
	_center()

func _sync_tabs() -> void:
	for k in tab_btns:
		(tab_btns[k] as Button).set_pressed_no_signal(k == tab)

func _center() -> void:
	RowKit.center(self, PANEL_W, PANEL_H)

func hide_panel() -> void:
	if visible:
		visible = false
		closed.emit(npc_id)

func _set_tab(key: String) -> void:
	tab = key
	_sync_tabs()
	pager.page = 0
	_refresh()

func _refresh() -> void:
	var gold := int(data.get("gold", 0))
	var bank := int(data.get("bank", 0))
	title_lab.text = "%s — %s" % [str(data.get("name", "Hòm đồ")), str(data.get("city_name", ""))]
	gold_lab.text = UiKit.fmt_int(gold)
	bank_lab.text = UiKit.fmt_int(bank)
	cap_lab.text = "Sức chứa còn: %.2f oz  ·  Bank dùng chung mọi thành phố" % (float(data.get("cap", 0)) / 100.0)
	gold_spin.max_value = maxi(1, gold)
	gold_spin.value = clampi(int(gold_spin.value), 1, int(gold_spin.max_value))
	bank_spin.max_value = maxi(1, bank)
	bank_spin.value = clampi(int(bank_spin.value), 1, int(bank_spin.max_value))
	btn_put_gold.disabled = gold <= 0
	btn_put_all.disabled = gold <= 0
	btn_take_gold.disabled = bank <= 0
	btn_take_all.disabled = bank <= 0
	used_lab.text = "Hòm %s: %d / %d ô (đồ trong Hòm riêng từng thành phố)" % [str(data.get("city_name", "")), int(data.get("used", 0)), int(data.get("limit", 0))]
	for c in rows.get_children():
		rows.remove_child(c)   # gỡ ngay để min-size không cộng dồn thẻ cũ (queue_free chỉ xoá cuối khung)
		c.queue_free()
	var list: Array = data.get("pack" if tab == "put" else "depot", [])
	pager.set_total(list.size(), PER_PAGE)
	if list.is_empty():
		rows.add_child(UiKit.lab("(Túi không có đồ để gửi)" if tab == "put" else "(Hòm trống)", 13, Color(0.4, 0.4, 0.45)))
	else:
		for r in Pager.slice(list, pager.page, PER_PAGE):
			rows.add_child(_item_row(r))
	_center()
	call_deferred("_center")

func _item_row(r: Dictionary) -> Control:
	var card := RowKit.row_card(ROW_H)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	card.add_child(h)
	var iid := int(r.get("id", 0))
	var n := maxi(1, int(r.get("n", 1)))
	var nm := str(r.get("name", ""))
	if nm == "" or nm == str(iid):
		nm = TibiaUI.name_of(iid)
	h.add_child(RowKit.item_icon(iid, nm, 44))
	var sub := "x%s  ·  %.2f oz mỗi cái" % [UiKit.fmt_int(n), float(r.get("w", 0)) / 100.0]
	var nb := RowKit.name_box(nm, sub)
	nb.tooltip_text = "%s [%s]" % [nm, str(r.get("cat", "others"))]
	h.add_child(nb)
	var sp := RowKit.right_spin(SpinBox.new())
	sp.min_value = 1
	sp.max_value = n
	sp.value = 1
	sp.custom_minimum_size = Vector2(84, 32)
	sp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sp)
	var putting := tab == "put"
	var b := RowKit.act_btn("Gửi" if putting else "Lấy", true, 56)
	b.pressed.connect(func():
		sp.apply()
		_emit_item(putting, iid, int(sp.value)))
	h.add_child(b)
	var ball := RowKit.act_btn("Tất cả", true, 62, "plain")
	ball.pressed.connect(func(): _emit_item(putting, iid, n))
	h.add_child(ball)
	return card

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
		var sp := gold_spin if deposit else bank_spin
		sp.apply()
		n = int(sp.value)
	if n <= 0:
		return
	if deposit:
		put_gold.emit(npc_id, n)
	else:
		take_gold.emit(npc_id, n)