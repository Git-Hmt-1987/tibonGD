class_name SpellPanel
extends PanelContainer
## Danh sách spell đầy đủ (D5, tách từ TibiaUI): lọc theo vocation (+ tùy chọn "đủ level"), tìm theo tên/words,
## 3 tab (tấn công / hồi-hỗ trợ / triệu hồi), phân trang. Nút Học/Cast/Premium giữ logic cũ.
## Dữ liệu spell do server gửi (gói `spells`, PROTOCOL §Làn F); không tự đặt số.

signal learn_pressed(spell_id: String)
signal cast_pressed(spell_id: String)

const PER_PAGE := 7
const VOC_NAMES := {1: "Sorcerer", 2: "Druid", 3: "Paladin", 4: "Knight"}
const TABS := [["appren", "Tấn công"], ["voc", "Hồi/Hỗ trợ"], ["prem", "Triệu hồi"]]

var has_premium := false
var my_level := 1
var voc := 4
var all_spells: Array = []
var tab := "appren"
var page := 0
var only_ready := false
var query := ""
var rows: VBoxContainer
var tab_btns := {}
var count_lab: Label
var pager: Pager

func build() -> void:
	add_theme_stylebox_override("panel", UiKit.panel_style())
	var v := VBoxContainer.new()
	add_child(v)
	var title := HBoxContainer.new()
	v.add_child(title)
	var tt := UiKit.lab("Spells", 16, Color(0.7, 0.85, 1))
	tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tt)
	var x := Button.new()
	x.text = "X"
	x.pressed.connect(hide)
	title.add_child(x)
	var tabs := HBoxContainer.new()
	v.add_child(tabs)
	for t in TABS:
		var b := Button.new()
		b.text = str(t[1])
		b.toggle_mode = true
		b.button_pressed = (t[0] == "appren")
		b.pressed.connect(_set_tab.bind(str(t[0])))
		tabs.add_child(b)
		tab_btns[str(t[0])] = b
	var srow := HBoxContainer.new()
	v.add_child(srow)
	var search := LineEdit.new()
	search.placeholder_text = "Tìm theo tên / words..."
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(_on_search)
	srow.add_child(search)
	var chk := CheckBox.new()
	chk.text = "Chỉ đủ level"
	chk.toggled.connect(_on_ready_toggled)
	srow.add_child(chk)
	UiKit.block_world(self)
	var area := VBoxContainer.new()   # danh sách theo TRANG (không cuộn): cuộn chuột trên vùng này = đổi trang
	area.custom_minimum_size = Vector2(0, 380)
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.clip_contents = true
	v.add_child(area)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.add_child(rows)
	count_lab = UiKit.lab("", 11, Color(0.8, 0.85, 0.95))
	count_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(count_lab)
	pager = Pager.new()
	pager.page_changed.connect(func(pg):
		page = pg
		rebuild())
	v.add_child(pager)
	pager.attach_wheel(area)

func set_data(spells: Array, p_voc: int) -> void:
	all_spells = spells
	voc = p_voc
	rebuild()

func set_level(lv: int) -> void:
	if lv != my_level:
		my_level = lv
		if only_ready:
			rebuild()

func set_premium(on: bool) -> void:
	if on != has_premium:
		has_premium = on
		rebuild()

func _set_tab(t: String) -> void:
	tab = t
	page = 0
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
		c.queue_free()
	var list := _visible_spells()
	pager.page = page
	pager.set_total(list.size(), PER_PAGE)
	page = pager.page
	count_lab.text = "%d spell" % list.size() if list.size() > 0 else "Không có spell phù hợp"
	for s in Pager.slice(list, page, PER_PAGE):
		_add_card(s)

func _add_card(s: Dictionary) -> void:
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 6)
	rows.add_child(card)
	var icon_btn := IconBtn.new()
	icon_btn.setup("spell_" + str(s.get("id", "")), "?", "Icon chờ art thật (icons/spell_%s.png)" % str(s.get("id", "")),
		Vector2(48, 48), Color(0.4, 0.65, 1.0))
	icon_btn.disabled = true
	card.add_child(icon_btn)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(mid)
	var nm := "%s  %s" % [s.get("name", "?"), ("(%s)" % s.get("words", "")) if s.get("words", "") != "" else ""]
	mid.add_child(UiKit.lab(nm, 13, Color(1, 0.9, 0.6)))
	mid.add_child(UiKit.lab(str(s.get("desc", "")), 11, Color(0.8, 0.8, 0.8)))
	var req := "Lv %d · %d mana · %d gold" % [int(s.get("level", 0)), int(s.get("mana", 0)), int(s.get("price", 0))]
	var vv: Array = s.get("voc", [1, 2, 3, 4])
	if vv.size() < 4:
		var vn := []
		for v in vv:
			vn.append(str(VOC_NAMES.get(int(v), "?")))
		req += " · " + "/".join(vn)
	var col := Color(0.7, 0.85, 1) if int(s.get("level", 0)) <= my_level else Color(0.95, 0.5, 0.45)
	mid.add_child(UiKit.lab(req, 11, col))
	var act := Button.new()
	act.custom_minimum_size = Vector2(84, 48)
	if s.get("prem") and not has_premium:
		act.text = "Premium"
		act.disabled = true
		act.tooltip_text = "Cần tài khoản Premium"
	elif s.get("learned"):
		act.text = "Cast"  # mọi spell (tấn công/hồi/hỗ trợ/conjure) đều cast được
		act.pressed.connect(func(): cast_pressed.emit(str(s.get("id", ""))))
	else:
		act.text = "Học\n%dg" % int(s.get("price", 0))
		act.pressed.connect(func(): learn_pressed.emit(str(s.get("id", ""))))
	card.add_child(act)
