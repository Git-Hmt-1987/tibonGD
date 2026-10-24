class_name NpcPanel
extends PanelContainer
## Panel NPC (làn E): click NPC -> hộp thoại 2 tab Mua / Bán (không hội thoại). Dữ liệu từ gói `npc_shop`
## (PROTOCOL §Làn E): buy[] / sell[] là item {id,name,price,w,caption,vocs?,have?} hoặc spell {spell,name,words,price,level,prem,known}.
## Server kiểm tra tầm/tiền/capacity; panel chỉ gửi yêu cầu và vẽ lại khi server gửi `npc_shop` mới.
## Thiết kế: MUA = danh sách thẻ (icon, tên, mô tả, giá, nút Mua 1/10/100); BÁN = lưới đồ trong túi bên trái + thẻ chi tiết/số lượng bên phải.

signal buy_item(npc_id: String, item: int, n: int)
signal buy_spell(npc_id: String, spell: String)
signal sell_item(npc_id: String, item: int, n: int)
signal travel(npc_id: String, map_id: String)   # NPC Dịch Chuyển: đi tới thành phố map_id
signal closed(npc_id: String)

const MAX_QTY := 100   # mirror server npc.MAX_QTY
const PANEL_W := 760.0
const PANEL_H := 540.0
const PER_PAGE := 6    # số thẻ mỗi trang ở tab Mua (thẻ cao cố định)
const GRID_COLS := 5
const GRID_PER_PAGE := 20
const TILE := 64
const ROW_H := 60

var npc_id := ""
var tab := "buy"
var data := {}
var title_lab: Label
var gold_lab: Label
var gold_pill: Control
var info_lab: Label
var tab_btns := {}
var tabs_box: HBoxContainer
var body: VBoxContainer
var pager: Pager
var sel_item := 0          # tab Bán: id món đang chọn
var sell_qty := 1
var query := ""
var _gold_total := 0


func build() -> void:
	visible = false
	add_theme_stylebox_override("panel", UiKit.panel_style())
	set_anchors_preset(Control.PRESET_TOP_LEFT)   # tự đặt vị trí/kích thước trong _center() (không phụ thuộc anchor của parent)
	get_viewport().size_changed.connect(_center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	UiKit.head_sep(head)
	title_lab = UiKit.title("NPC", 17)
	title_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_lab)
	gold_pill = _gold_pill()
	head.add_child(gold_pill)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(hide_shop)
	head.add_child(close_btn)
	tabs_box = HBoxContainer.new()
	tabs_box.add_theme_constant_override("separation", 8)
	v.add_child(tabs_box)
	for t in [["buy", "Mua"], ["sell", "Bán"]]:
		var key: String = t[0]
		var b := _tab(str(t[1]), key == tab)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _set_tab(key))
		tabs_box.add_child(b)
		tab_btns[key] = b
	UiKit.block_world(self)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	v.add_child(body)
	var foot := HBoxContainer.new()
	v.add_child(foot)
	info_lab = UiKit.lab("", 11, Color(0.4, 0.4, 0.45))
	info_lab.add_theme_color_override("font_color", UiTheme.muted())
	info_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(info_lab)
	pager = Pager.new()
	pager.page_changed.connect(func(_p): _refresh())
	foot.add_child(pager)


## Ô vàng ở header: icon xu + số gold trong túi (tooltip: Bank).
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
	return p


func _tab(text: String, on: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = on
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 34)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_font_override("font", UiKit.bold_font())
	b.add_theme_stylebox_override("normal", CharPanel._box(Color("#e8dcc0"), Color("#c9b98f"), 2, 5))
	b.add_theme_stylebox_override("hover", CharPanel._box(Color("#f1e7cc"), UiTheme.accent(), 2, 5))
	b.add_theme_stylebox_override("pressed", CharPanel._box(UiTheme.accent(), UiTheme.accent_dark(), 2, 5))
	b.add_theme_stylebox_override("hover_pressed", CharPanel._box(UiTheme.accent(), UiTheme.accent_dark(), 2, 5))
	for cn in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(cn, Color.WHITE)
	return b


func show_shop(msg: Dictionary) -> void:
	if str(msg.get("id", "")) != npc_id:
		tab = "buy"
		_sync_tabs()
		pager.page = 0   # NPC khác: về trang 1
		sel_item = 0
		query = ""
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


func _sync_tabs() -> void:
	for k in tab_btns:
		(tab_btns[k] as Button).button_pressed = (k == tab)


func _set_tab(key: String) -> void:
	tab = key
	pager.page = 0
	_sync_tabs()
	_refresh()


func _clear_body() -> void:
	for c in body.get_children():
		body.remove_child(c)   # gỡ ngay để min-size không cộng dồn thẻ cũ
		c.queue_free()


func _refresh() -> void:
	var typ := str(data.get("type", ""))
	var tele := typ == "teleport"          # Dịch Chuyển: chỉ một danh sách điểm đến
	tabs_box.visible = not tele and typ != "spell"   # NPC bán spell cũng chỉ có Mua
	if tele or typ == "spell":
		tab = "buy"
		_sync_tabs()
	title_lab.text = str(data.get("name", "NPC"))
	var bag_gold := int(data.get("gold", 0))
	var bank := int(data.get("bank", 0))
	_gold_total = bag_gold + bank   # tiền thanh toán = gold trong túi + Bank (server wallet.pay: túi trước, thiếu lấy Bank)
	gold_lab.text = UiKit.fmt_int(bag_gold)
	gold_pill.tooltip_text = "Gold trong túi: %s\nBank: %s" % [UiKit.fmt_int(bag_gold), UiKit.fmt_int(bank)]
	info_lab.text = "Bank: %s gp   ·   Sức chứa còn: %.2f oz" % [UiKit.fmt_int(bank), float(data.get("cap", 0)) / 100.0]
	_clear_body()
	if tab == "sell":
		_build_sell()
	else:
		_build_buy()
	_center()
	call_deferred("_center")   # sau khi bố cục tính lại: ép panel về đúng cỡ cố định, không cho phình dần


# ------------------------------------------------------------------ MUA: danh sách thẻ

func _build_buy() -> void:
	var list: Array = data.get("buy", [])
	pager.visible = true
	pager.set_total(list.size(), PER_PAGE)   # giữ trang đang xem sau khi mua (server gửi lại npc_shop)
	var area := VBoxContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.clip_contents = true
	area.add_theme_constant_override("separation", 5)
	body.add_child(area)
	pager.attach_wheel(area)   # cuộn chuột trên vùng này = đổi trang, không zoom bản đồ
	if list.is_empty():
		area.add_child(UiKit.lab("(Hết hàng)", 13, Color(0.4, 0.4, 0.45)))
		return
	for r in Pager.slice(list, pager.page, PER_PAGE):
		if r.has("map"):
			area.add_child(_travel_row(r))
		elif r.has("spell"):
			area.add_child(_spell_row(r))
		else:
			area.add_child(_buy_row(r))


## Khung thẻ chung cho một hàng: nền kem, viền be, cao cố định ROW_H.
func _row_card() -> PanelContainer:
	var card := PanelContainer.new()
	var sb := CharPanel._box(Color("#fbf3dc"), Color("#bfae82"), 2, 5)
	sb.set_content_margin_all(5)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(0, ROW_H)
	return card


func _icon(iid: int, nm: String, px: int) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", CharPanel._box(Color("#e8dcc0"), Color("#9c8a5e"), 2, 5))
	frame.custom_minimum_size = Vector2(px, px)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic := CharPanel.ItemIcon.new()
	ic.custom_minimum_size = Vector2(px - 6, px - 6)
	ic.set_item(iid, nm)
	frame.add_child(ic)
	return frame


## Cột tên (đậm) + mô tả nhỏ (tối đa 2 dòng, hover xem đủ).
func _name_box(nm_txt: String, caption: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 0)
	var nm := UiKit.lab(nm_txt, 14, Color(0.1, 0.1, 0.15))
	nm.add_theme_font_override("font", UiKit.bold_font())
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.tooltip_text = nm_txt
	v.add_child(nm)
	if caption != "":
		var c := UiKit.lab(caption, 11, Color(0.4, 0.4, 0.45))
		c.add_theme_color_override("font_color", UiTheme.muted())
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.clip_text = true
		c.custom_minimum_size = Vector2(80, 28)
		c.tooltip_text = caption
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		v.add_child(c)
	return v


## Giá: icon xu + số (vàng đậm).
func _price_box(price: int, w := 86) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.alignment = BoxContainer.ALIGNMENT_END
	h.custom_minimum_size = Vector2(w, 0)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var coin := ActionDock.DockGlyph.new()
	coin.glyph = "coin"
	coin.custom_minimum_size = Vector2(20, 20)
	h.add_child(coin)
	var l := UiKit.lab_raw(UiKit.fmt_int(price), 14, Color("#b06a00"))
	l.add_theme_font_override("font", UiKit.bold_font())
	h.add_child(l)
	return h


## Nút hành động: xanh (bấm được) / xám (không đủ tiền...). Bo nhỏ 5px.
func _act_btn(text: String, enabled: bool, w := 56) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 32)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_font_override("font", UiKit.bold_font())
	var bg := UiTheme.accent().lightened(0.1)
	b.add_theme_stylebox_override("normal", CharPanel._box(bg, UiTheme.accent_dark(), 2, 5))
	b.add_theme_stylebox_override("hover", CharPanel._box(bg.lightened(0.15), UiTheme.accent_dark(), 2, 5))
	b.add_theme_stylebox_override("pressed", CharPanel._box(bg.darkened(0.1), UiTheme.accent_dark(), 2, 5))
	var gray := Color("#a9acb6")
	b.add_theme_stylebox_override("disabled", CharPanel._box(gray, gray.darkened(0.3), 2, 5))
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(cn, Color.WHITE)
	return b


func _buy_row(r: Dictionary) -> Control:
	var iid := int(r.get("id", 0))
	var nm := str(r.get("name", iid))
	var price := int(r.get("price", 0))
	var card := _row_card()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	card.add_child(h)
	h.add_child(_icon(iid, nm, 48))
	var need_prem := bool(r.get("prem", false))
	var locked := need_prem and not bool(data.get("premium", true))
	var cap_txt := str(r.get("caption", ""))
	if need_prem:
		cap_txt = ("Chỉ dành cho tài khoản Premium. " if locked else "Premium. ") + cap_txt
	var nb := _name_box(nm + ("  [Premium]" if need_prem else ""), cap_txt)
	h.add_child(nb)
	h.add_child(_price_box(price))
	for q in [1, 10, 100]:
		var qq: int = q
		var b := _act_btn("Mua %d" % qq, _gold_total >= price * qq and not locked, 62)
		b.tooltip_text = "Cần tài khoản Premium" if locked else "Tổng: %s gp" % UiKit.fmt_int(price * qq)
		b.pressed.connect(func(): buy_item.emit(npc_id, iid, qq))
		h.add_child(b)
	return card


func _spell_row(r: Dictionary) -> Control:
	var txt := "%s  (%s)" % [str(r.get("name", "?")), str(r.get("words", ""))]
	var cap := "Lv %d%s · %s" % [int(r.get("level", 1)), " · Premium" if bool(r.get("prem", false)) else "", str(r.get("caption", ""))]
	var price := int(r.get("price", 0))
	var known := bool(r.get("known", false))
	var card := _row_card()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	card.add_child(h)
	h.add_child(_name_box(txt, cap))
	h.add_child(_price_box(price))
	var b := _act_btn("Đã học" if known else "Học", not known and _gold_total >= price, 80)
	var sid := str(r.get("spell", ""))
	b.pressed.connect(func(): buy_spell.emit(npc_id, sid))
	h.add_child(b)
	return card


func _travel_row(r: Dictionary) -> Control:
	var rec = r.get("rec", [])
	var cap := ""
	if rec is Array and rec.size() == 2:
		cap = "Level khuyến nghị: %d-%d" % [int(rec[0]), int(rec[1])]   # mức level khuyến nghị của thành phố
	var price := int(r.get("price", 0))
	var here := bool(r.get("here", false))
	var card := _row_card()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	card.add_child(h)
	h.add_child(_name_box(str(r.get("name", "?")), cap))
	h.add_child(_price_box(price))
	var b := _act_btn("Đang ở đây" if here else "Đi", not here and _gold_total >= price, 90)
	var mid := str(r.get("map", ""))
	b.pressed.connect(func(): travel.emit(npc_id, mid))
	h.add_child(b)
	return card


# ------------------------------------------------------------------ BÁN: lưới đồ + chi tiết

func _sell_list() -> Array:
	var out: Array = []
	for r in data.get("sell", []):
		if query != "" and str(r.get("name", "")).to_lower().find(query) < 0:
			continue
		out.append(r)
	return out


func _find_sell(iid: int) -> Dictionary:
	for r in data.get("sell", []):
		if int(r.get("id", 0)) == iid:
			return r
	return {}


func _build_sell() -> void:
	var list := _sell_list()
	if _find_sell(sel_item).is_empty():   # món đang chọn đã bán hết / bị lọc: chọn món đầu danh sách
		sel_item = int(list[0]["id"]) if not list.is_empty() else 0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	# ---- trái: tìm kiếm + lưới
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", CharPanel._card_box())
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size = Vector2(GRID_COLS * (TILE + 6) + 16, 0)
	row.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	left.add_child(lv)
	var hint := UiKit.lab("Túi đồ của bạn", 14, Color(0.1, 0.1, 0.15))
	hint.add_theme_font_override("font", UiKit.bold_font())
	lv.add_child(hint)
	var search := LineEdit.new()
	search.placeholder_text = "Tìm theo tên..."
	search.clear_button_enabled = true
	search.text = query
	search.text_changed.connect(func(t: String):
		query = t.strip_edges().to_lower()
		pager.page = 0
		_refresh_keep_focus())
	lv.add_child(search)
	pager.visible = true
	pager.set_total(list.size(), GRID_PER_PAGE)
	var area := VBoxContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.clip_contents = true
	lv.add_child(area)
	pager.attach_wheel(area)
	if list.is_empty():
		area.add_child(UiKit.lab("(Không có gì để bán)", 13, Color(0.4, 0.4, 0.45)))
	else:
		var g := GridContainer.new()
		g.columns = GRID_COLS
		g.add_theme_constant_override("h_separation", 6)
		g.add_theme_constant_override("v_separation", 6)
		area.add_child(g)
		for r in Pager.slice(list, pager.page, GRID_PER_PAGE):
			g.add_child(_tile(r))
	# ---- phải: chi tiết món đang chọn
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", CharPanel._card_box())
	right.custom_minimum_size = Vector2(270, 0)
	row.add_child(right)
	_fill_sell_detail(right)


func _refresh_keep_focus() -> void:
	_refresh()


func _tile(r: Dictionary) -> Control:
	var iid := int(r.get("id", 0))
	var nm := str(r.get("name", iid))
	var have := int(r.get("have", 1))
	var sel := iid == sel_item
	var b := Button.new()
	b.custom_minimum_size = Vector2(TILE, TILE)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.expand_icon = true
	b.add_theme_font_size_override("font_size", 11)
	var bg := UiTheme.accent_light() if sel else Color("#fbf3dc")
	var bd := UiTheme.accent() if sel else Color("#bfae82")
	b.add_theme_stylebox_override("normal", CharPanel._box(bg, bd, 3 if sel else 2, 5))
	b.add_theme_stylebox_override("hover", CharPanel._box(bg.lightened(0.2), UiTheme.accent(), 2, 5))
	b.add_theme_stylebox_override("pressed", CharPanel._box(bg, UiTheme.accent_dark(), 3, 5))
	b.add_theme_stylebox_override("hover_pressed", CharPanel._box(bg, UiTheme.accent_dark(), 3, 5))
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(cn, UiTheme.ink_color())
	var tex := UiAssets.icon("item_%d" % iid)
	if tex != null:
		b.icon = tex
	else:
		b.text = nm.left(9)
	b.tooltip_text = "%s x%s · %s gp/cái" % [nm, UiKit.fmt_int(have), UiKit.fmt_int(int(r.get("price", 0)))]
	b.pressed.connect(func():
		sel_item = iid
		sell_qty = 1
		_refresh())
	if have > 1:
		var cl := UiKit.lab_raw(UiKit.fmt_int(have), 11, Color.WHITE)
		cl.add_theme_font_override("font", UiKit.bold_font())
		cl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		cl.add_theme_constant_override("outline_size", 4)
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		b.add_child(cl)
		cl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cl.offset_right = -5
		cl.offset_bottom = -2
	return b


func _fill_sell_detail(right: Control) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	right.add_child(v)
	var r := _find_sell(sel_item)
	if r.is_empty():
		var e := UiKit.lab("Chọn một món trong túi để bán", 13, Color(0.4, 0.4, 0.45))
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(e)
		return
	var nm := str(r.get("name", sel_item))
	var price := int(r.get("price", 0))
	var have := maxi(1, int(r.get("have", 1)))
	sell_qty = clampi(sell_qty, 1, have)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	top.add_child(_icon(sel_item, nm, 64))
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	var nl := UiKit.lab(nm, 16, Color(0.1, 0.1, 0.15))
	nl.add_theme_font_override("font", UiKit.bold_font())
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size = Vector2(120, 0)
	tv.add_child(nl)
	var hv := UiKit.lab("Đang có: %s" % UiKit.fmt_int(have), 12, Color(0.4, 0.4, 0.45))
	hv.add_theme_color_override("font_color", UiTheme.muted())
	tv.add_child(hv)
	var cap := str(r.get("caption", ""))
	if cap != "":
		var sc := ScrollContainer.new()   # mô tả dài chỉ cuộn trong khung, không làm panel phình ra
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.custom_minimum_size = Vector2(0, 40)
		v.add_child(sc)
		var c := UiKit.lab(cap, 12, Color(0.3, 0.3, 0.35))
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.custom_minimum_size = Vector2(230, 0)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(c)
	else:
		var sp0 := Control.new()
		sp0.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(sp0)
	var pr := HBoxContainer.new()
	v.add_child(pr)
	var pl := UiKit.lab("Giá bán / cái", 13, Color(0.1, 0.1, 0.15))
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pr.add_child(pl)
	pr.add_child(_price_box(price, 0))
	# số lượng: [-] [ô nhập] [+] [Tối đa]
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 4)
	v.add_child(qrow)
	var spin := RowKit.right_spin(SpinBox.new())
	spin.min_value = 1
	spin.max_value = have
	spin.value = sell_qty
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var total_lab := UiKit.lab_raw("", 14, Color("#b06a00"))
	total_lab.add_theme_font_override("font", UiKit.bold_font())
	var upd := func(): total_lab.text = UiKit.fmt_int(price * sell_qty)
	var minus := _act_btn("−", true, 32)
	minus.pressed.connect(func(): spin.value = maxf(1.0, spin.value - 1.0))
	var plus := _act_btn("+", true, 32)
	plus.pressed.connect(func(): spin.value = minf(float(have), spin.value + 1.0))
	var mx := _act_btn("Tối đa", true, 60)
	mx.pressed.connect(func(): spin.value = float(have))
	spin.value_changed.connect(func(val: float):
		sell_qty = int(val)
		upd.call())
	qrow.add_child(minus)
	qrow.add_child(spin)
	qrow.add_child(plus)
	qrow.add_child(mx)
	var tr := HBoxContainer.new()
	v.add_child(tr)
	var tl := UiKit.lab("Tổng nhận", 13, Color(0.1, 0.1, 0.15))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.add_child(tl)
	var tb := HBoxContainer.new()
	tb.add_theme_constant_override("separation", 4)
	var coin := ActionDock.DockGlyph.new()
	coin.glyph = "coin"
	coin.custom_minimum_size = Vector2(20, 20)
	tb.add_child(coin)
	tb.add_child(total_lab)
	tr.add_child(tb)
	upd.call()
	var sell_b := _act_btn("Bán", true, 0)
	sell_b.custom_minimum_size = Vector2(0, 38)
	sell_b.add_theme_font_size_override("font_size", 15)
	sell_b.pressed.connect(func(): sell_item.emit(npc_id, sel_item, sell_qty))
	v.add_child(sell_b)
