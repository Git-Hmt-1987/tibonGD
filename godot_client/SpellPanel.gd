class_name SpellPanel
extends PanelContainer
## Spell panel thiết kế lại: header + 3 tab lớn; cột trái = danh sách spell (nút Học / Đã học), cột phải = thẻ chi tiết
## (icon, thông số gồm cả giá học, mô tả, nút Học/Cast). Lọc theo vocation, tìm tên/words, "đủ level", phân trang.
## Dữ liệu spell do server gửi (gói `spells`, PROTOCOL §Làn F); không tự đặt số.

signal learn_pressed(spell_id: String)
signal cast_pressed(spell_id: String)

const PER_PAGE := 6
const VOC_NAMES := {1: "Sorcerer", 2: "Druid", 3: "Paladin", 4: "Knight", 9: "Monk"}
const TABS := [["appren", "Tấn công"], ["voc", "Hồi/Hỗ trợ"], ["prem", "Triệu hồi"]]
const TAB_NAMES := {"appren": "Tấn công", "voc": "Hồi / Hỗ trợ", "prem": "Triệu hồi"}

var has_premium := false
var my_level := 1
var voc := 4
var all_spells: Array = []
var tab := "appren"
var page := 0
var only_ready := false
var query := ""
var selected := ""
var rows: VBoxContainer
var tab_btns := {}
var count_lab: Label
var info_lab: Label
var pager: Pager
var detail_box: VBoxContainer


func build() -> void:
	add_theme_stylebox_override("panel", UiKit.panel_style())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var title := HBoxContainer.new()
	v.add_child(title)
	UiKit.head_sep(title)
	var tt := UiKit.title("Spells", 17)
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tt)
	var x := Button.new()
	x.text = "X"
	x.pressed.connect(hide)
	title.add_child(x)
	info_lab = UiKit.lab("", 14, Color(0.1, 0.1, 0.15))
	UiKit.make_bold(info_lab)
	info_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info_lab)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for t in TABS:
		var b := _tab(str(t[1]), t[0] == "appren")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_tab.bind(str(t[0])))
		tabs.add_child(b)
		tab_btns[str(t[0])] = b
	UiKit.block_world(self)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	# ---- cột trái: tìm kiếm + danh sách + phân trang
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", CharPanel._card_box())
	left.custom_minimum_size = Vector2(400, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	left.add_child(lv)
	var srow := HBoxContainer.new()
	lv.add_child(srow)
	var search := LineEdit.new()
	search.placeholder_text = "Tìm theo tên / words..."
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.clear_button_enabled = true
	search.text_changed.connect(_on_search)
	srow.add_child(search)
	var chk := CheckBox.new()
	chk.text = "Đủ level"
	chk.toggled.connect(_on_ready_toggled)
	srow.add_child(chk)
	var area := VBoxContainer.new()   # danh sách theo TRANG (không cuộn): cuộn chuột trên vùng này = đổi trang
	area.custom_minimum_size = Vector2(0, 372)
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.clip_contents = true
	lv.add_child(area)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.add_child(rows)
	count_lab = UiKit.lab("", 11, Color(0.4, 0.4, 0.45))
	count_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(count_lab)
	pager = Pager.new()
	pager.page_changed.connect(func(pg):
		page = pg
		rebuild())
	lv.add_child(pager)
	pager.attach_wheel(area)
	# ---- cột phải: thẻ chi tiết nền xanh đậm
	var right := PanelContainer.new()
	var rsb := CharPanel._box(UiTheme.accent_dark().darkened(0.45), UiTheme.accent_dark(), 3, 12)
	rsb.set_content_margin_all(12)
	right.add_theme_stylebox_override("panel", rsb)
	right.custom_minimum_size = Vector2(300, 0)
	body.add_child(right)
	detail_box = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 8)
	right.add_child(detail_box)


func set_data(spells: Array, p_voc: int) -> void:
	all_spells = spells
	voc = p_voc
	rebuild()


func set_level(lv: int) -> void:
	if lv != my_level:
		my_level = lv
		rebuild()


func set_premium(on: bool) -> void:
	if on != has_premium:
		has_premium = on
		rebuild()


func _set_tab(t: String) -> void:
	tab = t
	page = 0
	selected = ""
	for k in tab_btns:
		tab_btns[k].button_pressed = (k == t)
	rebuild()


func _visible_spells() -> Array:
	var out: Array = []
	for s in all_spells:
		var ok := false
		for vv in s.get("voc", [1, 2, 3, 4]):
			if int(vv) == voc:
				ok = true
		if not ok:
			continue  # chỉ hiện spell đúng vocation mình
		if str(s.get("tab", "appren")) != tab:
			continue
		if only_ready and int(s.get("level", 0)) > my_level:
			continue
		if query != "":
			var hay := ("%s %s" % [s.get("name", ""), s.get("words", "")]).to_lower()
			if hay.find(query) < 0:
				continue
		out.append(s)
	out.sort_custom(_cmp)
	return out


func _cmp(a: Dictionary, b: Dictionary) -> bool:
	if int(a.get("level", 0)) != int(b.get("level", 0)):
		return int(a.get("level", 0)) < int(b.get("level", 0))
	return str(a.get("name", "")) < str(b.get("name", ""))


func _on_search(t: String) -> void:
	query = t.strip_edges().to_lower()
	page = 0
	rebuild()


func _on_ready_toggled(on: bool) -> void:
	only_ready = on
	page = 0
	rebuild()


func rebuild() -> void:
	if rows == null:
		return
	for c in rows.get_children():
		rows.remove_child(c)   # gỡ ngay để min-size không cộng dồn thẻ cũ
		c.queue_free()
	var list := _visible_spells()
	var learned_n := 0
	for s in all_spells:
		if s.get("learned"):
			learned_n += 1
	info_lab.text = "%s · Lv %d · Đã học %d/%d spell" % [VOC_NAMES.get(voc, "?"), my_level, learned_n, all_spells.size()]
	pager.page = page
	pager.set_total(list.size(), PER_PAGE)
	page = pager.page
	count_lab.text = "%d spell" % list.size() if list.size() > 0 else "Không có spell phù hợp"
	var sel: Dictionary = {}
	for s in list:
		if str(s.get("id", "")) == selected:
			sel = s
	if sel.is_empty() and not list.is_empty():   # chưa chọn / spell đã bị lọc mất: chọn món đầu danh sách
		sel = list[0]
		selected = str(sel.get("id", ""))
	for s in Pager.slice(list, page, PER_PAGE):
		_add_row(s)
	_fill_detail(sel)


func _select(id: String) -> void:
	selected = id
	rebuild()


func _status(s: Dictionary) -> String:
	if s.get("prem") and not has_premium:
		return "prem"
	return "learned" if s.get("learned") else "learn"


## Một dòng spell ở cột trái: icon, tên + words, Lv, nút Học / Đã học.
func _add_row(s: Dictionary) -> void:
	var id := str(s.get("id", ""))
	var on := id == selected
	var card := PanelContainer.new()
	var sb := CharPanel._box(UiTheme.accent_light() if on else Color("#fbf3dc"), UiTheme.accent() if on else Color("#bfae82"), 3 if on else 2, 10)
	sb.set_content_margin_all(5)
	card.add_theme_stylebox_override("panel", sb)
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_select(id))
	rows.add_child(card)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	card.add_child(h)
	var ic := SpellIcon.new()
	ic.setup(id, str(s.get("name", "?")), 46)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(mid)
	var nm := UiKit.lab(str(s.get("name", "?")), 14, Color(0.1, 0.1, 0.15))
	UiKit.make_bold(nm)
	nm.clip_text = true
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(nm)
	var lv_ok := int(s.get("level", 0)) <= my_level
	var sub := UiKit.lab("Lv %d  ·  %s" % [int(s.get("level", 0)), str(s.get("words", ""))], 11, Color(0.3, 0.45, 0.2) if lv_ok else Color(0.75, 0.25, 0.2))
	sub.clip_text = true
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(sub)
	h.add_child(_action_btn(s, Vector2(84, 32), false))


## Nút trạng thái: Học (xanh dương, bấm được) / Đã học (xanh lá, mờ) / Premium (khóa). Giá học nằm ở thông số, không ở nút.
func _action_btn(s: Dictionary, sz: Vector2, big: bool) -> Button:
	var id := str(s.get("id", ""))
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = sz
	b.add_theme_font_size_override("font_size", 15 if big else 13)
	var st := _status(s)
	var bg := UiTheme.accent().lightened(0.1)
	match st:
		"learned":
			b.text = "Đã học"
			b.disabled = true
			bg = Color("#6fae5a")
		"prem":
			b.text = "Premium"
			b.disabled = true
			b.tooltip_text = "Cần tài khoản Premium"
			bg = Color("#b59a6a")
		_:
			b.text = "Học"
			b.pressed.connect(func(): learn_pressed.emit(id))
	b.add_theme_stylebox_override("normal", CharPanel._box(bg, bg.darkened(0.35), 2, 10))
	b.add_theme_stylebox_override("hover", CharPanel._box(bg.lightened(0.15), bg.darkened(0.35), 2, 10))
	b.add_theme_stylebox_override("pressed", CharPanel._box(bg.darkened(0.1), bg.darkened(0.4), 2, 10))
	b.add_theme_stylebox_override("disabled", CharPanel._box(bg, bg.darkened(0.35), 2, 10))
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(cn, Color.WHITE)
	return b


## Thẻ chi tiết bên phải.
func _fill_detail(s: Dictionary) -> void:
	for c in detail_box.get_children():
		detail_box.remove_child(c)   # gỡ ngay để min-size không cộng dồn thẻ cũ
		c.queue_free()
	if s.is_empty():
		var e := UiKit.lab_raw("Chọn một spell để xem chi tiết", 13, Color(0.8, 0.85, 0.95))
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_box.add_child(e)
		return
	var id := str(s.get("id", ""))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	detail_box.add_child(top)
	var ic := SpellIcon.new()
	ic.setup(id, str(s.get("name", "?")), 76)
	top.add_child(ic)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	var nm := UiKit.lab_raw(str(s.get("name", "?")), 18, Color.WHITE)
	nm.add_theme_font_override("font", UiKit.bold_font())
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(nm)
	if str(s.get("words", "")) != "":
		var w := UiKit.lab_raw("“%s”" % str(s.get("words", "")), 13, Color(0.75, 0.88, 1.0))
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tv.add_child(w)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 4)
	tv.add_child(chips)
	chips.add_child(_chip(TAB_NAMES.get(str(s.get("tab", "appren")), "Spell"), Color("#3d86d6")))
	if s.get("prem"):
		chips.add_child(_chip("Premium", Color("#c28a2c")))
	# thông số cơ bản
	var lv_need := int(s.get("level", 0))
	var vv: Array = s.get("voc", [1, 2, 3, 4])
	var vn := []
	for x in vv:
		vn.append(str(VOC_NAMES.get(int(x), "?")))
	var stats := [
		["Cấp yêu cầu", "%d" % lv_need, Color("#8fe08a") if lv_need <= my_level else Color("#ff8a80")],
		["Mana", str(int(s.get("mana", 0))), Color.WHITE],
	]
	if int(s.get("soul", 0)) > 0:
		stats.append(["Soul", str(int(s.get("soul", 0))), Color.WHITE])
	stats.append(["Giá học", "%s gold" % UiKit.fmt_int(int(s.get("price", 0))), Color("#ffd56b")])
	stats.append(["Nghề", "Tất cả" if vv.size() >= 4 else "/".join(vn), Color.WHITE])
	var tbl := VBoxContainer.new()
	tbl.add_theme_constant_override("separation", 0)
	detail_box.add_child(tbl)
	for i in stats.size():
		tbl.add_child(_stat_row(str(stats[i][0]), str(stats[i][1]), stats[i][2], i % 2 == 1))
	# mô tả
	var dh := UiKit.lab_raw("Mô tả", 14, Color(0.75, 0.88, 1.0))
	dh.add_theme_font_override("font", UiKit.bold_font())
	detail_box.add_child(dh)
	var d := UiKit.lab_raw(str(s.get("desc", "")) if str(s.get("desc", "")) != "" else "(Chưa có mô tả)", 13, Color.WHITE)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_child(d)
	# nút
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	detail_box.add_child(btns)
	var main_b := _action_btn(s, Vector2(0, 38), true)
	main_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(main_b)
	if s.get("learned"):   # mọi spell đã học đều cast được
		var cb := Button.new()
		cb.text = "Cast"
		cb.focus_mode = Control.FOCUS_NONE
		cb.custom_minimum_size = Vector2(0, 38)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.add_theme_font_size_override("font_size", 15)
		var cbg := UiTheme.accent().lightened(0.1)
		cb.add_theme_stylebox_override("normal", CharPanel._box(cbg, cbg.darkened(0.35), 2, 10))
		cb.add_theme_stylebox_override("hover", CharPanel._box(cbg.lightened(0.15), cbg.darkened(0.35), 2, 10))
		cb.add_theme_stylebox_override("pressed", CharPanel._box(cbg.darkened(0.1), cbg.darkened(0.4), 2, 10))
		for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			cb.add_theme_color_override(cn, Color.WHITE)
		cb.pressed.connect(func(): cast_pressed.emit(id))
		btns.add_child(cb)


func _stat_row(a: String, b: String, vcol: Color, odd: bool) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.09) if odd else Color(1, 1, 1, 0.03)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	p.add_child(h)
	var la := UiKit.lab_raw(a, 13, Color(0.75, 0.88, 1.0))
	la.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(la)
	var lb := UiKit.lab_raw(b, 13, vcol)
	lb.add_theme_font_override("font", UiKit.bold_font())
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(lb)
	return p


func _chip(t: String, bg: Color) -> Label:
	var l := UiKit.lab_raw(t, 11, Color.WHITE)
	l.add_theme_font_override("font", UiKit.bold_font())
	var sb := CharPanel._box(bg, bg.darkened(0.3), 2, 8)
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	l.add_theme_stylebox_override("normal", sb)
	return l


func _tab(text: String, on: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = on
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 36)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_font_override("font", UiKit.bold_font())
	b.add_theme_stylebox_override("normal", CharPanel._box(Color("#e8dcc0"), Color("#c9b98f"), 2, 12))
	b.add_theme_stylebox_override("hover", CharPanel._box(Color("#f1e7cc"), UiTheme.accent(), 2, 12))
	b.add_theme_stylebox_override("pressed", CharPanel._box(UiTheme.accent(), UiTheme.accent_dark(), 2, 12))
	b.add_theme_stylebox_override("hover_pressed", CharPanel._box(UiTheme.accent(), UiTheme.accent_dark(), 2, 12))
	for cn in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(cn, Color.WHITE)
	return b


## Icon spell: ảnh spell_<id>.png (assets/icons/spells/) nếu có, không thì ô bo góc + chữ cái đầu.
class SpellIcon extends Control:
	var tex: Texture2D = null
	var letter := "?"

	func setup(id: String, nm: String, px: int) -> void:
		tex = UiAssets.icon("spell_" + id)
		letter = nm.left(1).to_upper()
		custom_minimum_size = Vector2(px, px)
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	func _draw() -> void:
		draw_style_box(CharPanel._box(Color("#e8dcc0"), Color("#9c8a5e"), 2, 10), Rect2(Vector2.ZERO, size))
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(3, 3), size - Vector2(6, 6)), false)
		else:
			var font := get_theme_default_font()
			draw_string(font, Vector2(0, size.y * 0.5 + size.y * 0.18), letter, HORIZONTAL_ALIGNMENT_CENTER, size.x, int(size.y * 0.5), UiTheme.muted())