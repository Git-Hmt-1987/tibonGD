class_name CharPanel
extends HBoxContainer
## Panel Character kiểu mới: [Nhân vật: tên + hero + ô trang bị] [Túi đồ: tab loại, tìm kiếm, lưới 5x5, gold] [Chi tiết vật phẩm].
## TibiaUI tạo 1 CharPanel, nối signal và gọi set_equip / set_items / set_identity / set_soul_cap / set_money.
## Ảnh hero đứng: assets/icons/classes/<knight|paladin|druid|sorcerer>_class.png ; icon nghề: <nghề>_icon.png (xem UiAssets.class_tex).
## Icon item: assets/icons/items/item_<id>.png (chưa có thì hiện chữ tên).

signal unequip(slot: String)
signal use_item(iid: int)
signal closed

const PER_PAGE := 25            # 5 cột x 5 hàng
const COLS := 5
const CELL := 62
## [id loại, chữ, icon vector dự phòng, tên file PNG trong assets/icons/buttons/]
const CATS := [["all", "Tất cả", "all", "icon_tat_ca"], ["equip", "Trang bị", "battle", "icon_trang_bi"],
	["food", "Thức ăn", "food", "icon_thuc_an"], ["valuables", "Quý giá", "gem", "icon_quy_gia"],
	["others", "Khác", "misc", "icon_khac"]]
## Nhãn các chỉ số vật phẩm (server gửi trong backpack[iid].stats = {"atk": 38, "def": 12, ...}); khóa lạ hiện nguyên tên.
const STAT_LABELS := {"atk": "Tấn công (ATK)", "def": "Phòng thủ (DEF)", "arm": "Giáp (ARM)", "bonus": "Bonus",
	"range": "Tầm đánh", "speed": "Tốc đánh", "weight": "Trọng lượng", "req_lv": "Cấp yêu cầu", "hands": "Cầm tay",
	"elem": "Nguyên tố", "dmg": "Sát thương", "vocs": "Nghề", "desc": "Mô tả", "hit": "Hit", "flee": "Flee"}
## Ô trang bị: [slot server, chú thích]
const LEFT_SLOTS := [["Neck", "Dây chuyền"], ["R-Hand", "Vũ khí"], ["L-Hand", "Khiên"], ["Ring", "Nhẫn"]]
const RIGHT_SLOTS := [["Head", "Mũ"], ["Armor", "Giáp"], ["Legs", "Quần"], ["Boots", "Giày"]]
const BOTTOM_SLOTS := [["Ammo", "Đạn"]]   # hàng cuối: Đạn | Cap | Soul

var equip_btns := {}            # slot -> Button
var items := {}                 # {iid: {n, cat}} server gửi
var cat := "all"
var query := ""
var sort_mode := 0              # 0 mặc định, 1 theo tên, 2 theo số lượng
var selected := 0
var page_pager: Pager
var grid: GridContainer
var cat_btns := {}
var search: LineEdit
var gold_lab: Label
var count_lab: Label
var sort_btn: Button
var name_lab: Label
var sub_lab: Label
var stage: HeroStage
var cap_tile: StatTile
var soul_tile: StatTile
var captions := {}   # iid -> chuỗi caption server gửi kèm gói npc_shop (dự phòng khi backpack chưa có stats)
var detail: PanelContainer
var d_name: Label
var d_icon: Control
var d_cat: Label
var d_info: Label
var d_stats: VBoxContainer   # bảng chỉ số: ATK / DEF / ARM / Bonus... (từ stats server gửi)
var d_use: Button
var _gold := 0
var _bank := 0
var _voc := ""


func build() -> void:
	visible = false
	add_theme_constant_override("separation", 8)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_build_character()
	_build_bag()
	_build_detail()
	set_items({})


# ------------------------------------------------------------------ cột 1: nhân vật

func _build_character() -> void:
	var p := UiKit.panel()
	p.custom_minimum_size = Vector2(330, 0)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var h := UiKit.title("Nhân vật", 17)
	v.add_child(h)
	UiKit.head_sep(h)
	# 2 tab: Trang bị (đang dùng) / Thời trang (chưa có)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	var t1 := _tab("Trang bị", true)
	t1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(t1)
	var t2 := _tab("Thời trang", false)
	t2.disabled = true
	t2.tooltip_text = "Chưa có"
	t2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(t2)
	# thẻ bên trong
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_box())
	v.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 0)
	card.add_child(cv)
	# dòng riêng trên cùng: tên + Lv · nghề
	name_lab = UiKit.lab("—", 17, Color(0.1, 0.1, 0.15))
	name_lab.add_theme_font_override("font", UiKit.bold_font())
	name_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lab.clip_text = true
	cv.add_child(name_lab)
	sub_lab = UiKit.lab("", 12, Color(0.45, 0.45, 0.5))
	sub_lab.add_theme_color_override("font_color", UiTheme.muted())
	sub_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(sub_lab)
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 2)
	cv.add_child(mid)
	mid.add_child(_slot_col(LEFT_SLOTS))
	stage = HeroStage.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(120, 200)
	mid.add_child(stage)
	mid.add_child(_slot_col(RIGHT_SLOTS))
	# hàng cuối: Đạn - Cap - Soul (icon + số như ô Túi đồ)
	var bot := HBoxContainer.new()
	bot.alignment = BoxContainer.ALIGNMENT_CENTER
	bot.add_theme_constant_override("separation", 20)
	cv.add_child(bot)
	for s2 in BOTTOM_SLOTS:
		bot.add_child(_slot_cell(s2[0], s2[1]))
	cap_tile = StatTile.new()
	cap_tile.setup("cap_icon", "misc", "Cap")
	bot.add_child(_tile_cell(cap_tile, "Cap"))
	soul_tile = StatTile.new()
	soul_tile.setup("soul_icon", "gem", "Soul")
	bot.add_child(_tile_cell(soul_tile, "Soul"))


func _tile_cell(t: Control, caption: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(t)
	var gap := Control.new()
	gap.custom_minimum_size.y = 3
	v.add_child(gap)
	var l := UiKit.lab(caption, 10, Color(0.3, 0.3, 0.35))
	l.custom_minimum_size.y = 16
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.add_theme_color_override("font_color", UiTheme.muted())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return v


func _slot_col(defs: Array) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 4)
	for s in defs:
		c.add_child(_slot_cell(s[0], s[1]))
	return c


func _slot_cell(slot: String, caption: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var b := Button.new()
	b.custom_minimum_size = Vector2(54, 54)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.expand_icon = true
	b.add_theme_font_size_override("font_size", 10)
	b.pressed.connect(func(): unequip.emit(slot))
	_style_slot(b, false)
	b.tooltip_text = "%s (trống)" % caption
	v.add_child(b)
	equip_btns[slot] = b
	var cl := UiKit.lab_raw("", 11, Color.WHITE)
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
	b.set_meta("count_lab", cl)
	var gap := Control.new()   # đệm để chữ chú thích không đè viền ô
	gap.custom_minimum_size.y = 3
	v.add_child(gap)
	var l := UiKit.lab(caption, 10, Color(0.3, 0.3, 0.35))
	l.custom_minimum_size.y = 16
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.add_theme_color_override("font_color", UiTheme.muted())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return v


func _style_slot(b: Button, filled: bool) -> void:
	var bg := Color("#f7d77c") if filled else Color("#ece0c0")
	var bd := Color("#b98a2a") if filled else Color("#c9b98f")
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, _box(bg, bd, 2, 10))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.15), UiTheme.accent(), 2, 10))
	b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.08), UiTheme.accent_dark(), 2, 10))
	b.add_theme_stylebox_override("hover_pressed", _box(bg.darkened(0.08), UiTheme.accent_dark(), 2, 10))
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(cn, UiTheme.ink_color())


# ------------------------------------------------------------------ cột 2: túi đồ

func _build_bag() -> void:
	var p := UiKit.panel()
	p.custom_minimum_size = Vector2(404, 0)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	UiKit.head_sep(head)
	var t := UiKit.title("Túi đồ", 17)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := Button.new()
	x.text = "X"
	x.pressed.connect(func(): closed.emit())
	head.add_child(x)
	# tab loại (icon + chữ)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	v.add_child(tabs)
	for c in CATS:
		var b := CatTab.new()
		b.setup(str(c[0]), str(c[1]), str(c[2]), str(c[3]))
		b.pressed.connect(_set_cat.bind(str(c[0])))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		cat_btns[str(c[0])] = b
	cat_btns["all"].button_pressed = true
	# ô tìm kiếm
	search = LineEdit.new()
	search.placeholder_text = "Tìm theo tên..."
	search.clear_button_enabled = true
	var sb := _box(Color.WHITE.lerp(UiTheme.body(), 0.25), UiTheme.accent_dark(), 2, 16)
	sb.content_margin_left = 12
	search.add_theme_stylebox_override("normal", sb)
	search.add_theme_stylebox_override("focus", _box(Color.WHITE.lerp(UiTheme.body(), 0.25), UiTheme.accent(), 2, 16))
	search.text_changed.connect(func(tx: String):
		query = tx.strip_edges().to_lower()
		page_pager.page = 0
		_rebuild())
	v.add_child(search)
	# lưới 5x5 (chia trang, cuộn chuột = đổi trang)
	var gcard := PanelContainer.new()
	gcard.add_theme_stylebox_override("panel", _card_box())
	gcard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gcard)
	var gv := VBoxContainer.new()
	gcard.add_child(gv)
	var area := VBoxContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gv.add_child(area)
	grid = GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	area.add_child(grid)
	page_pager = Pager.new()
	page_pager.page_changed.connect(func(_p): _rebuild())
	gv.add_child(page_pager)
	page_pager.attach_wheel(area)
	# chân: gold | đếm | sắp xếp
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	v.add_child(foot)
	var gp := PanelContainer.new()
	gp.add_theme_stylebox_override("panel", _box(UiTheme.body().lightened(0.55), UiTheme.accent_dark(), 2, 14))
	gp.custom_minimum_size = Vector2(96, 28)
	foot.add_child(gp)
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 4)
	gp.add_child(gh)
	var coin := ActionDock.DockGlyph.new()
	coin.glyph = "coin"
	coin.custom_minimum_size = Vector2(20, 20)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gh.add_child(coin)
	gold_lab = UiKit.lab("0", 14, Color(0.72, 0.45, 0.05))
	gold_lab.add_theme_color_override("font_color", Color(0.72, 0.45, 0.05))
	gold_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gh.add_child(gold_lab)
	count_lab = UiKit.lab("", 12, Color(0.4, 0.4, 0.45))
	count_lab.add_theme_color_override("font_color", UiTheme.muted())
	count_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(count_lab)
	sort_btn = _blue_btn("Sắp xếp: mặc định")
	sort_btn.pressed.connect(func():
		sort_mode = (sort_mode + 1) % 3
		_rebuild())
	foot.add_child(sort_btn)


# ------------------------------------------------------------------ cột 3: chi tiết vật phẩm

func _build_detail() -> void:
	detail = UiKit.panel()
	detail.custom_minimum_size = Vector2(236, 0)
	detail.visible = false
	add_child(detail)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	detail.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	UiKit.head_sep(head)
	d_name = UiKit.title("Vật phẩm", 16)
	d_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_name.clip_text = true
	head.add_child(d_name)
	var xb := Button.new()
	xb.text = "X"
	xb.pressed.connect(func():
		selected = 0
		_rebuild()
		_refresh_detail())
	head.add_child(xb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _box(Color("#e8dcc0"), Color("#9c8a5e"), 3, 12))
	frame.custom_minimum_size = Vector2(96, 96)
	row.add_child(frame)
	d_icon = ItemIcon.new()
	d_icon.custom_minimum_size = Vector2(88, 88)
	frame.add_child(d_icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	d_cat = UiKit.lab_raw("", 12, Color.WHITE)
	d_cat.add_theme_font_override("font", UiKit.bold_font())
	d_cat.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(d_cat)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_box())
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(card)
	var cvv := VBoxContainer.new()
	cvv.add_theme_constant_override("separation", 4)
	card.add_child(cvv)
	d_info = UiKit.lab("", 13, Color(0.1, 0.1, 0.15))
	d_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cvv.add_child(d_info)
	d_stats = VBoxContainer.new()
	d_stats.add_theme_constant_override("separation", 0)
	cvv.add_child(d_stats)
	d_use = _blue_btn("Dùng")
	d_use.custom_minimum_size = Vector2(0, 34)
	d_use.pressed.connect(func():
		if selected > 0:
			use_item.emit(selected))
	v.add_child(d_use)


# ------------------------------------------------------------------ API

func set_identity(nm: String, level: int, voc_name: String) -> void:
	name_lab.text = nm
	sub_lab.text = "Lv %d%s" % [level, " · " + voc_name if voc_name != "" else ""]
	if voc_name != _voc:
		_voc = voc_name
		stage.set_voc(voc_name)


func set_money(gold: int, bank: int) -> void:
	_gold = gold
	_bank = bank
	gold_lab.text = UiKit.fmt_int(gold)
	gold_lab.get_parent().get_parent().tooltip_text = "Gold trong túi: %s\nBank: %s" % [UiKit.fmt_int(gold), UiKit.fmt_int(bank)]


func set_soul_cap(soul: int, max_soul: int, free_cap: float, max_cap: float) -> void:
	soul_tile.set_value(str(soul), "Soul: %d/%d" % [soul, max_soul])
	cap_tile.set_value(_oz(free_cap), "Capacity còn trống: %s / %s oz" % [_oz(free_cap), _oz(max_cap)])


## Lưu caption (chỉ số dạng chữ) từ các dòng Mua/Bán của shop NPC để hiện ở panel chi tiết.
func add_captions(rows: Array) -> void:
	for r in rows:
		if r is Dictionary and r.has("id") and str(r.get("caption", "")) != "":
			captions[int(r["id"])] = str(r["caption"])
	if detail != null and selected > 0:
		_refresh_detail()


func set_equip(equip: Dictionary, counts := {}) -> void:
	for slot in equip_btns:
		var b: Button = equip_btns[slot]
		var iid := int(equip.get(slot, 0))
		var cap := _caption(slot)
		var cl: Label = b.get_meta("count_lab")
		var ghost: Texture2D = UiAssets.icon("dan_icon") if slot == "Ammo" else null   # ô đạn trống: icon mờ
		if iid > 0:
			var nm := TibiaUI.name_of(iid)
			var n := int(counts.get(slot, 0))
			var tex := UiAssets.icon("item_%d" % iid)
			b.icon = tex
			b.text = "" if tex != null else nm.left(7)
			cl.text = str(n) if n > 1 else ""
			b.tooltip_text = "%s: %s%s (click: tháo)" % [cap, nm, " x%d" % n if n > 1 else ""]
			b.add_theme_color_override("icon_normal_color", Color.WHITE)
			_style_slot(b, true)
		else:
			b.icon = ghost
			b.add_theme_color_override("icon_normal_color", Color(1, 1, 1, 0.5))
			b.text = ""
			cl.text = ""
			b.tooltip_text = "%s (trống)" % cap
			_style_slot(b, false)


func set_items(p_items: Dictionary) -> void:
	items = p_items
	if selected > 0 and not items.has(selected):
		selected = 0
	_rebuild()


# ------------------------------------------------------------------ nội bộ

func _caption(slot: String) -> String:
	for d in LEFT_SLOTS + RIGHT_SLOTS + BOTTOM_SLOTS:
		if d[0] == slot:
			return d[1]
	return slot


func _set_cat(c: String) -> void:
	cat = c
	page_pager.page = 0
	for k in cat_btns:
		cat_btns[k].button_pressed = (k == c)
	_rebuild()


func _entries() -> Array:
	var out: Array = []
	for iid in items:
		var e = items[iid]
		var n := int(e["n"]) if e is Dictionary else int(e)
		var ct := str(e["cat"]) if e is Dictionary else "others"
		if cat != "all" and ct != cat:
			continue
		var nm := TibiaUI.name_of(int(iid))
		if query != "" and not nm.to_lower().contains(query):
			continue
		out.append([int(iid), n, ct, nm])
	if sort_mode == 1:
		out.sort_custom(func(a, b): return str(a[3]).naturalnocasecmp_to(str(b[3])) < 0)
	elif sort_mode == 2:
		out.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	return out


func _rebuild() -> void:
	if grid == null:
		return
	for c in grid.get_children():
		grid.remove_child(c)   # gỡ ngay để min-size không cộng dồn thẻ cũ
		c.queue_free()
	var entries := _entries()
	page_pager.set_total(entries.size(), PER_PAGE)
	var slice := Pager.slice(entries, page_pager.page, PER_PAGE)
	for en in slice:
		grid.add_child(_item_cell(en))
	for i in range(PER_PAGE - slice.size()):   # ô trống để lưới luôn đủ 5x5
		grid.add_child(_empty_cell())
	count_lab.text = "%d loại" % items.size()
	sort_btn.text = "Sắp xếp: " + ["mặc định", "tên", "số lượng"][sort_mode]
	_refresh_detail()


func _empty_cell() -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(CELL, CELL)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _box(Color("#e6d9b8"), Color("#d4c59c"), 2, 10))
	return p


func _item_cell(en: Array) -> Control:
	var iid: int = en[0]
	var n: int = en[1]
	var nm: String = en[3]
	var b := Button.new()
	b.custom_minimum_size = Vector2(CELL, CELL)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.expand_icon = true
	b.add_theme_font_size_override("font_size", 11)
	var sel := iid == selected
	var bg := UiTheme.accent_light() if sel else Color("#fbf3dc")
	var bd := UiTheme.accent() if sel else Color("#bfae82")
	b.add_theme_stylebox_override("normal", _box(bg, bd, 3 if sel else 2, 10))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.2), UiTheme.accent(), 2, 10))
	b.add_theme_stylebox_override("pressed", _box(bg, UiTheme.accent_dark(), 3, 10))
	b.add_theme_stylebox_override("hover_pressed", _box(bg, UiTheme.accent_dark(), 3, 10))
	var tex := UiAssets.icon("item_%d" % iid)
	if tex != null:
		b.icon = tex
	else:
		b.text = nm.left(9)
	b.tooltip_text = "%s x%s (click: xem · nhấp đúp: dùng)" % [nm, n]
	b.pressed.connect(func():
		selected = iid
		_rebuild())
	b.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.double_click and ev.button_index == MOUSE_BUTTON_LEFT:
			use_item.emit(iid))
	if n > 1:
		var cl := UiKit.lab_raw(str(n), 11, Color.WHITE)
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


func _refresh_detail() -> void:
	if selected <= 0 or not items.has(selected):
		detail.visible = false
		return
	detail.visible = visible
	var e = items[selected]
	var n := int(e["n"]) if e is Dictionary else int(e)
	var ct := str(e["cat"]) if e is Dictionary else "others"
	d_name.text = TibiaUI.name_of(selected)
	(d_icon as ItemIcon).set_item(selected, d_name.text)
	var cname := "Khác"
	for c in CATS:
		if c[0] == ct:
			cname = str(c[1])
	d_cat.text = " %s " % cname
	var chip := _box(UiTheme.accent(), UiTheme.accent_dark(), 2, 8)
	chip.content_margin_top = 0
	chip.content_margin_bottom = 0
	d_cat.add_theme_stylebox_override("normal", chip)
	d_info.text = "Số lượng: %d\nLoại: %s" % [n, cname]
	d_use.text = "Trang bị" if ct == "equip" else "Dùng"
	var st: Dictionary = e["stats"] if e is Dictionary and e.get("stats") is Dictionary else {}
	if st.is_empty() and captions.has(selected):   # dự phòng: tách caption server "Atk 38 Def 12 · Level 8 · Knight · 40.00 oz"
		st = _parse_caption(str(captions[selected]))
	_fill_stats(st)


func _parse_caption(cap: String) -> Dictionary:
	var out := {}
	var rx := RegEx.new()
	rx.compile("(Atk|Def|Arm|Range|Level)\\s+([^\\s]+)")
	for part in cap.split(" · "):
		var ms := rx.search_all(part)
		if not ms.is_empty():
			for m in ms:
				var key: String = {"Atk": "atk", "Def": "def", "Arm": "arm", "Range": "range", "Level": "req_lv"}[m.get_string(1)]
				out[key] = m.get_string(2)
		elif part.ends_with(" oz"):
			out["weight"] = part
		elif part in ["Knight", "Paladin", "Druid", "Sorcerer", "Monk"] or part.contains("/"):
			out["vocs"] = part
		else:
			out["desc"] = part
	return out


## Bảng "Chỉ số | Giá trị" (sọc xen kẽ như ảnh mẫu). Giá trị mảng [a, b] hiện "a–b".
func _fill_stats(st: Dictionary) -> void:
	for c in d_stats.get_children():
		d_stats.remove_child(c)   # gỡ ngay để min-size không cộng dồn thẻ cũ
		c.queue_free()
	if st.is_empty():
		var l := UiKit.lab("(Server chưa gửi chỉ số vật phẩm này)", 12, Color(0.4, 0.4, 0.45))
		l.add_theme_color_override("font_color", UiTheme.muted())
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_stats.add_child(l)
		return
	var head := _stat_row("Chỉ số", "Giá trị", true, false)
	d_stats.add_child(head)
	var i := 0
	for k in st:
		var v = st[k]
		var vt := "%d–%d" % [int(v[0]), int(v[1])] if v is Array and v.size() >= 2 else str(v)
		d_stats.add_child(_stat_row(str(STAT_LABELS.get(str(k), str(k))), vt, false, i % 2 == 1))
		i += 1


func _stat_row(a: String, b: String, header: bool, odd: bool) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#e3d6b4") if header else (Color("#efe3c3") if odd else Color("#f9f1da"))
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	p.add_child(h)
	var la := UiKit.lab(a, 13, Color(0.1, 0.1, 0.15))
	la.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(la)
	var lb := UiKit.lab(b, 13, Color(0.1, 0.1, 0.15))
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(lb)
	return p


func visibility_changed_hook() -> void:
	if detail != null and not visible:
		detail.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and detail != null:
		if visible:
			_refresh_detail()
		else:
			detail.visible = false


static func _oz(v: float) -> String:
	return "%d" % roundi(v) if absf(v - roundf(v)) < 0.005 else "%.1f" % v


static func _box(bg: Color, border: Color, bw := 2, radius := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(4)
	return sb


static func _card_box() -> StyleBoxFlat:
	var sb := _box(UiTheme.body().lightened(0.35), UiTheme.body().darkened(0.18), 2, 12)
	sb.set_content_margin_all(6)
	return sb


func _tab(text: String, on: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = on
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 30)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_stylebox_override("normal", _box(Color("#e8dcc0"), Color("#c9b98f"), 2, 10))
	b.add_theme_stylebox_override("hover", _box(Color("#f1e7cc"), UiTheme.accent(), 2, 10))
	b.add_theme_stylebox_override("pressed", _box(UiTheme.accent(), UiTheme.accent_dark(), 2, 10))
	b.add_theme_stylebox_override("hover_pressed", _box(UiTheme.accent(), UiTheme.accent_dark(), 2, 10))
	b.add_theme_stylebox_override("disabled", _box(Color("#e8dcc0"), Color("#c9b98f"), 2, 10))
	b.add_theme_color_override("font_disabled_color", UiTheme.muted())
	return b


func _chip_lab(t: String) -> Label:
	var l := UiKit.lab(t, 13, Color(0.1, 0.1, 0.15))
	l.add_theme_stylebox_override("normal", _box(UiTheme.body().lightened(0.5), UiTheme.accent_dark(), 2, 10))
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


func _blue_btn(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_stylebox_override("normal", _box(UiTheme.accent().lightened(0.1), UiTheme.accent_dark(), 2, 10))
	b.add_theme_stylebox_override("hover", _box(UiTheme.accent().lightened(0.25), UiTheme.accent_dark(), 2, 10))
	b.add_theme_stylebox_override("pressed", _box(UiTheme.accent().darkened(0.1), UiTheme.accent_dark(), 2, 10))
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(cn, Color.WHITE)
	return b


# ------------------------------------------------------------------ control phụ

## Hero đứng giữa panel: ảnh <nghề>_class.png (nếu có) + bóng đổ dưới chân; chưa có ảnh thì dùng hình vẽ tạm.
class HeroStage extends Control:
	var tex: Texture2D = null
	var fallback: Portrait = null

	func set_voc(voc_name: String) -> void:
		tex = UiAssets.class_tex(voc_name, "class")
		if tex == null and fallback == null:
			fallback = Portrait.new()
			fallback.bare = true
			fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
			fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(fallback)
		if fallback != null:
			fallback.visible = tex == null
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y - 40.0)
		var pts := PackedVector2Array()
		for i in 32:
			var a := i * TAU / 32.0
			pts.append(c + Vector2(cos(a) * size.x * 0.4, sin(a) * 11.0))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.16))   # bóng dưới chân
		if tex != null:
			var ts := tex.get_size()
			var k := minf((size.x - 4.0) / ts.x, (size.y - 26.0) / ts.y)
			var sz := ts * k
			draw_texture_rect(tex, Rect2(Vector2((size.x - sz.x) * 0.5, size.y - 32.0 - sz.y), sz), false)


## Tab loại túi đồ: icon vector phía trên + chữ; chọn = nền xanh.
class CatTab extends Button:
	var glyph := ""
	var label := ""
	var tex_name := ""

	func setup(id: String, p_label: String, p_glyph: String, p_tex := "") -> void:
		glyph = p_glyph
		tex_name = p_tex
		label = p_label
		toggle_mode = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(0, 52)
		tooltip_text = p_label
		var on := UiTheme.accent()
		add_theme_stylebox_override("normal", CharPanel._box(Color("#e8dcc0"), Color("#c9b98f"), 2, 10))
		add_theme_stylebox_override("hover", CharPanel._box(Color("#f1e7cc"), UiTheme.accent(), 2, 10))
		add_theme_stylebox_override("pressed", CharPanel._box(on, UiTheme.accent_dark(), 2, 10))
		add_theme_stylebox_override("hover_pressed", CharPanel._box(on, UiTheme.accent_dark(), 2, 10))

	func _draw() -> void:
		var tex: Texture2D = UiAssets.icon(tex_name) if tex_name != "" else null
		if tex != null:   # icon_*.png nếu có (assets/icons/buttons/), không thì icon vector
			draw_texture_rect(tex, Rect2(Vector2(size.x * 0.5 - 15.0, 3.0), Vector2(30, 30)), false)
		else:
			DockIcons.draw(self, glyph, Vector2(size.x * 0.5, 19.0), 12.0)
		var font := get_theme_default_font()
		var col := Color.WHITE if button_pressed else UiTheme.ink_color()
		draw_string(font, Vector2(0, size.y - 6.0), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, col)


## Icon vật phẩm lớn (ô chi tiết): ảnh item_<id>.png nếu có, không thì chữ cái đầu.
class ItemIcon extends Control:
	var tex: Texture2D = null
	var letter := "?"

	func set_item(iid: int, nm: String) -> void:
		tex = UiAssets.icon("item_%d" % iid)
		letter = nm.left(1).to_upper()
		queue_redraw()

	func _draw() -> void:
		if tex != null:
			var e := minf(size.x, size.y)
			draw_texture_rect(tex, Rect2((size - Vector2(e, e)) * 0.5, Vector2(e, e)), false)
		else:
			var font := get_theme_default_font()
			draw_string(font, Vector2(0, size.y * 0.5 + 14.0), letter, HORIZONTAL_ALIGNMENT_CENTER, size.x, 44, UiTheme.muted())


## Ô Cap / Soul ở hàng cuối: nền giống ô slot, icon (cap_icon.png / soul_icon.png) + con số góc phải-dưới như ô Túi đồ.
class StatTile extends Control:
	var tex_name := ""
	var glyph := ""
	var value := "--"

	func setup(p_tex: String, p_glyph: String, tip: String) -> void:
		tex_name = p_tex
		glyph = p_glyph
		tooltip_text = tip
		custom_minimum_size = Vector2(54, 54)

	func set_value(v: String, tip: String) -> void:
		value = v
		tooltip_text = tip
		queue_redraw()

	func _draw() -> void:
		var box := CharPanel._box(Color("#ece0c0"), Color("#c9b98f"), 2, 10)
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		var tex: Texture2D = UiAssets.icon(tex_name)
		if tex != null:
			var e := minf(size.x, size.y) - 8.0
			draw_texture_rect(tex, Rect2((size - Vector2(e, e)) * 0.5, Vector2(e, e)), false)
		else:
			DockIcons.draw(self, glyph, size * 0.5 - Vector2(0, 3), 13.0)
		var font := UiKit.bold_font()
		var pos := Vector2(0, size.y - 5.0)
		draw_string_outline(font, pos, value, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 5.0, 11, 4, Color(0, 0, 0, 0.85))
		draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 5.0, 11, Color.WHITE)