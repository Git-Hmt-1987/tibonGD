class_name Hotbar
extends Control
## Hàng ô chọn nhanh (D4) theo hotkey Tibia gốc: F1..F12, mỗi ô gán 1 item/pot/rune HOẶC 1 spell.
## - Dùng: click ô hoặc phím F tương ứng. Item -> op `use` (pot/food/rune/trang bị như cũ), spell -> op `cast`.
## - Gán: click ô trống hoặc chuột phải -> bảng chọn từ Túi đồ / spell đã học. Lưu theo tên nhân vật (user://).
## - Cooldown hiển thị (chỉ để nhìn, server mới là nguồn sự thật):
##     spell = `cd` của chính spell + `gcd` cho các spell cùng group (spells.xml: cooldown / groupcooldown),
##     item  = 1000 ms (config.EX_ACTIONS_DELAY_INTERVAL = timeBetweenExActions; game.cpp setNextPotionAction),
##             không áp cho đồ trang bị / food.

signal use_item(item_id: int)
signal cast_spell(spell_id: String)

const COUNT := 12
const SLOT_W := 38
const GAP := 3
const PICKER_W := 540
const PICKER_H := 412
const PICKER_PER_PAGE := 8   # 2 cột x 4 hàng thẻ
const ITEM_EXHAUST := 1.0

var slots: Array = []        # [{kind, ref}] đúng COUNT phần tử
var btns: Array = []         # HotSlot
var pack: Dictionary = {}    # iid(int) -> {n, cat}
var spells: Array = []       # toàn bộ spell server gửi (gói `spells`)
var spell_by_id := {}
var voc := 4
var owner_name := ""
var name_fn: Callable        # (iid:int) -> String, TibiaUI gán vào
var picker: PanelContainer
var picker_grid: GridContainer
var picker_title: Label
var picker_now: Label        # ô đang gán gì (hiện ở đầu bảng)
var picker_slot := -1
var picker_tab := "spell"
var picker_filter := "all"   # lọc con: spell = tab (appren/voc/prem), đồ = cat (equip/food/...)
var picker_query := ""
var picker_pager: Pager
var picker_count: Label
var picker_sub: HBoxContainer
var picker_search: LineEdit
var tab_btns := {}

const SPELL_FILTERS := [["all", "Tất cả"], ["appren", "Tấn công"], ["voc", "Hồi / Hỗ trợ"], ["prem", "Triệu hồi"]]
const ITEM_FILTERS := [["all", "Tất cả"], ["equip", "Trang bị"], ["food", "Food"], ["valuables", "Quý"], ["others", "Pot / Rune / Khác"]]
const SPELL_COLORS := {"appren": Color(0.95, 0.5, 0.35), "voc": Color(0.45, 0.85, 0.5), "prem": Color(0.72, 0.52, 0.95)}
const ITEM_COLORS := {"equip": Color(0.55, 0.7, 0.95), "food": Color(0.95, 0.8, 0.4), "valuables": Color(0.95, 0.85, 0.3), "others": Color(0.62, 0.72, 0.85)}

static func total_width() -> int:
	return COUNT * SLOT_W + (COUNT - 1) * GAP

func build() -> void:
	custom_minimum_size = Vector2(total_width(), SLOT_W)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in COUNT:
		slots.append({"kind": "", "ref": ""})
		var b := HotSlot.new()
		b.setup(i, "F%d" % (i + 1))
		b.activated.connect(activate)
		b.assign_requested.connect(open_picker)
		row.add_child(b)
		btns.append(b)
	_build_picker()
	_refresh_all()

# ---------- dữ liệu từ server (TibiaUI gọi) ----------

func set_backpack(items: Dictionary) -> void:
	pack = items
	_refresh_all()
	if picker != null and picker.visible and picker_tab == "item":
		_fill_picker()

func set_spells(list: Array, p_voc: int) -> void:
	spells = list
	voc = p_voc
	spell_by_id = {}
	for s in list:
		spell_by_id[str(s.get("id", ""))] = s
	_refresh_all()
	if picker != null and picker.visible and picker_tab == "spell":
		_fill_picker()

func set_character_owner(nm: String) -> void:
	if nm == owner_name:
		return
	owner_name = nm
	_load()
	_refresh_all()

# ---------- dùng ô ----------

func activate(i: int) -> void:
	if i < 0 or i >= slots.size():
		return
	var s: Dictionary = slots[i]
	if s["kind"] == "item":
		use_item.emit(int(s["ref"]))
		_cooldown_items()
	elif s["kind"] == "spell":
		cast_spell.emit(str(s["ref"]))
		_cooldown_spell(str(s["ref"]))
	# ô trống + phím F: không làm gì (như Tibia gốc)

func _cooldown_items() -> void:
	for i in COUNT:
		if slots[i]["kind"] != "item":
			continue
		var e = pack.get(int(slots[i]["ref"]), null)
		var cat := "others"
		if e is Dictionary:
			cat = str(e.get("cat", "others"))
		if cat == "equip" or cat == "food":
			continue
		btns[i].start_cooldown(ITEM_EXHAUST)

func _cooldown_spell(sid: String) -> void:
	var sp: Dictionary = spell_by_id.get(sid, {})
	if sp.is_empty():
		return
	var cd := float(sp.get("cd", 0.0))
	var gcd := float(sp.get("gcd", 0.0))
	var gcd2 := float(sp.get("gcd2", 0.0))
	var grp := str(sp.get("group", ""))
	var grp2 := str(sp.get("group2", ""))
	for i in COUNT:
		if slots[i]["kind"] != "spell":
			continue
		var other_id := str(slots[i]["ref"])
		var o: Dictionary = spell_by_id.get(other_id, {})
		if o.is_empty():
			continue
		var t := 0.0
		if other_id == sid:
			t = maxf(cd, maxf(gcd, gcd2))
		else:
			if grp != "" and str(o.get("group", "")) == grp:
				t = maxf(t, gcd)
			if grp2 != "" and str(o.get("group2", "")) == grp2:
				t = maxf(t, gcd2)
		if t > 0.0:
			btns[i].start_cooldown(t)

# ---------- vẽ lại ô ----------

static func _short(nm: String) -> String:
	var w := nm.split(" ", false)
	if w.size() >= 2:
		return "%s\n%s" % [w[0].left(5), w[1].left(5)]
	return nm.left(6)

func _item_name(iid: int) -> String:
	if name_fn.is_valid():
		return str(name_fn.call(iid))
	return "item #%d" % iid

func _refresh_all() -> void:
	for i in btns.size():
		_refresh_slot(i)

func _refresh_slot(i: int) -> void:
	var s: Dictionary = slots[i]
	var b: HotSlot = btns[i]
	if s["kind"] == "item":
		var iid := int(s["ref"])
		var nm := _item_name(iid)
		var e = pack.get(iid, null)
		var n := 0
		if e is Dictionary:
			n = int(e.get("n", 0))
		elif e != null:
			n = int(e)
		b.set_content("item", str(iid), _short(nm),
			"%s\nF%d · click / phím: dùng · chuột phải: đổi / xoá" % [nm, i + 1], IconBtn.load_icon("item_%d" % iid))
		b.set_count(str(n), n <= 0)
	elif s["kind"] == "spell":
		var sid := str(s["ref"])
		var sp: Dictionary = spell_by_id.get(sid, {})
		var words := str(sp.get("words", sid))
		var tip := "%s (%s)\nLv %d · %d mana · F%d\nclick / phím: cast · chuột phải: đổi / xoá" % [
			str(sp.get("name", sid)), words, int(sp.get("level", 0)), int(sp.get("mana", 0)), i + 1]
		b.set_content("spell", sid, _short(words), tip, IconBtn.load_icon("spell_" + sid))
		b.set_count(str(int(sp.get("mana", 0))) if not sp.is_empty() else "", false)
	else:
		b.set_content("", "", "", "", null)

# ---------- bảng chọn (thẻ có icon, tab + lọc + tìm kiếm + phân trang) ----------

static func _flat(bg: Color, border: Color, bw := 1, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(4)
	return sb

func _build_picker() -> void:
	picker = PanelContainer.new()
	picker.add_theme_stylebox_override("panel", _flat(Color(0.1, 0.12, 0.17, 0.98), Color(0.55, 0.47, 0.25), 2, 8))
	picker.visible = false
	picker.z_index = 20
	picker.custom_minimum_size = Vector2(PICKER_W, PICKER_H)
	add_child(picker)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	picker.add_child(v)
	# --- đầu bảng: tiêu đề + đang gán gì + Xoá ô + đóng ---
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	var tbox := VBoxContainer.new()
	tbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tbox.add_theme_constant_override("separation", 0)
	head.add_child(tbox)
	picker_title = UiKit.title("Gán vào ô", 15)
	tbox.add_child(picker_title)
	picker_now = UiKit.lab("", 11, Color(0.62, 0.68, 0.78))
	tbox.add_child(picker_now)
	var clear := Button.new()
	clear.text = "Xoá ô"
	clear.focus_mode = Control.FOCUS_NONE
	clear.add_theme_stylebox_override("normal", _flat(Color(0.35, 0.14, 0.14), Color(0.75, 0.3, 0.3)))
	clear.add_theme_stylebox_override("hover", _flat(Color(0.5, 0.18, 0.18), Color(0.9, 0.4, 0.4)))
	clear.add_theme_stylebox_override("pressed", _flat(Color(0.5, 0.18, 0.18), Color(0.9, 0.4, 0.4)))
	clear.pressed.connect(func(): _assign("", ""))
	head.add_child(clear)
	var x := Button.new()
	x.text = "✕"
	x.focus_mode = Control.FOCUS_NONE
	x.custom_minimum_size = Vector2(30, 0)
	x.pressed.connect(close_picker)
	head.add_child(x)
	# --- tab lớn: Spell | Đồ ---
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	v.add_child(tabs)
	for t in [["spell", "Spell đã học"], ["item", "Đồ / Pot / Rune (túi)"]]:
		var tb := Button.new()
		tb.text = str(t[1])
		tb.toggle_mode = true
		tb.focus_mode = Control.FOCUS_NONE
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size = Vector2(0, 30)
		tb.add_theme_font_override("font", UiKit.bold_font())
		tb.add_theme_stylebox_override("normal", _flat(Color(0.15, 0.18, 0.25), Color(0.32, 0.37, 0.48)))
		tb.add_theme_stylebox_override("hover", _flat(Color(0.2, 0.24, 0.33), Color(0.5, 0.55, 0.68)))
		tb.add_theme_stylebox_override("pressed", _flat(Color(0.38, 0.3, 0.1), Color(1.0, 0.85, 0.4), 2))
		tb.add_theme_stylebox_override("hover_pressed", _flat(Color(0.42, 0.33, 0.12), Color(1.0, 0.85, 0.4), 2))
		tb.pressed.connect(_set_tab.bind(str(t[0])))
		tabs.add_child(tb)
		tab_btns[str(t[0])] = tb
	# --- lọc con (chip) + ô tìm ---
	picker_sub = HBoxContainer.new()
	picker_sub.add_theme_constant_override("separation", 4)
	v.add_child(picker_sub)
	picker_search = LineEdit.new()
	picker_search.placeholder_text = "🔍 Tìm theo tên / words..."
	picker_search.clear_button_enabled = true
	picker_search.text_changed.connect(func(t: String):
		picker_query = t.strip_edges().to_lower()
		picker_pager.page = 0
		_fill_picker())
	v.add_child(picker_search)
	# --- lưới thẻ (2 cột) trong vùng cố định, KHÔNG cuộn: lăn chuột = đổi trang ---
	var area := VBoxContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.clip_contents = true
	v.add_child(area)
	picker_grid = GridContainer.new()
	picker_grid.columns = 2
	picker_grid.add_theme_constant_override("h_separation", 6)
	picker_grid.add_theme_constant_override("v_separation", 6)
	picker_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.add_child(picker_grid)
	picker_count = UiKit.lab("", 11, Color(0.62, 0.68, 0.78))
	picker_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(picker_count)
	picker_pager = Pager.new()
	picker_pager.page_changed.connect(func(_p): _fill_picker())
	v.add_child(picker_pager)
	picker_pager.attach_wheel(area)

func open_picker(i: int) -> void:
	picker_slot = i
	picker_title.text = "Gán vào ô F%d" % (i + 1)
	var cur: Dictionary = slots[i]
	if cur["kind"] == "spell":
		picker_tab = "spell"
		picker_now.text = "Đang gán: %s" % str(spell_by_id.get(str(cur["ref"]), {}).get("name", cur["ref"]))
	elif cur["kind"] == "item":
		picker_tab = "item"
		picker_now.text = "Đang gán: %s" % _item_name(int(cur["ref"]))
	else:
		picker_now.text = "Ô trống · chọn một thẻ bên dưới"
	picker_filter = "all"
	picker_query = ""
	picker_search.text = ""
	picker_pager.page = 0
	picker.visible = true
	_fill_picker()
	_place_picker()

## Đặt bảng ngay trên hotbar, căn giữa, kẹp trong khung nhìn (không tràn ra ngoài màn hình).
func _place_picker() -> void:
	var vp := get_viewport_rect().size
	var w := minf(float(PICKER_W), vp.x - 16.0)
	picker.size = Vector2(w, PICKER_H)
	var gx := global_position.x + (total_width() - w) / 2.0
	var gy := global_position.y - PICKER_H - 6.0
	picker.global_position = Vector2(clampf(gx, 8.0, maxf(8.0, vp.x - w - 8.0)), maxf(8.0, gy))

func close_picker() -> void:
	picker.visible = false
	picker_slot = -1

func _set_tab(t: String) -> void:
	picker_tab = t
	picker_filter = "all"
	picker_pager.page = 0
	_fill_picker()

func _chip(text: String, active: bool, key: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 11)
	var bg := Color(0.38, 0.3, 0.1) if active else Color(0.15, 0.18, 0.25)
	var bd := Color(1.0, 0.85, 0.4) if active else Color(0.32, 0.37, 0.48)
	b.add_theme_stylebox_override("normal", _flat(bg, bd, 1, 10))
	b.add_theme_stylebox_override("hover", _flat(bg.lightened(0.12), bd, 1, 10))
	b.add_theme_stylebox_override("pressed", _flat(bg.lightened(0.12), bd, 1, 10))
	var col := Color(1, 0.9, 0.5) if active else Color(0.8, 0.84, 0.92)
	for cn in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(cn, col)
	b.pressed.connect(func():
		picker_filter = key
		picker_pager.page = 0
		_fill_picker())
	return b

## Thẻ: viền màu theo loại + icon (thật nếu có, không thì ô màu + chữ cái) + tên + dòng phụ. `current` = đang gán ở ô này.
func _card(title: String, sub: String, accent: Color, tex: Texture2D, glyph: String, tip: String, current: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 52)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	var base := Color(0.2, 0.17, 0.09) if current else Color(0.15, 0.18, 0.25)
	var edge := Color(1.0, 0.85, 0.4) if current else Color(0.3, 0.35, 0.46)
	b.add_theme_stylebox_override("normal", _flat(base, edge, 2 if current else 1))
	b.add_theme_stylebox_override("hover", _flat(base.lightened(0.14), accent, 2))
	b.add_theme_stylebox_override("pressed", _flat(base.lightened(0.22), accent, 2))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	b.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	var stripe := ColorRect.new()
	stripe.color = accent
	stripe.custom_minimum_size = Vector2(3, 0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stripe)
	if tex != null:
		var icon_tex := TextureRect.new()
		icon_tex.texture = tex
		icon_tex.custom_minimum_size = Vector2(38, 38)
		icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon_tex)
	else:
		var ph := PanelContainer.new()
		ph.custom_minimum_size = Vector2(38, 38)
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ph.add_theme_stylebox_override("panel", _flat(accent.darkened(0.55), accent, 1, 8))
		var gl := UiKit.lab(glyph, 17, accent.lightened(0.35))
		gl.add_theme_font_override("font", UiKit.bold_font())
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ph.add_child(gl)
		row.add_child(ph)
	var mid := VBoxContainer.new()
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_theme_constant_override("separation", 1)
	row.add_child(mid)
	var t1 := UiKit.lab(title, 12, Color(1, 0.93, 0.7) if current else Color(0.95, 0.95, 0.98))
	t1.add_theme_font_override("font", UiKit.bold_font())
	t1.clip_text = true
	t1.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(t1)
	var t2 := UiKit.lab(sub, 10, Color(0.62, 0.68, 0.78))
	t2.clip_text = true
	t2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(t2)
	if current:
		var ck := UiKit.lab("✓", 16, Color(1.0, 0.85, 0.4))
		ck.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ck)
	return b

func _spell_list() -> Array:
	var list: Array = []
	for s in spells:
		var ok := false
		for vv in s.get("voc", [1, 2, 3, 4]):
			if int(vv) == voc:
				ok = true
		if not ok or not s.get("learned", false):
			continue
		if picker_filter != "all" and str(s.get("tab", "appren")) != picker_filter:
			continue
		if picker_query != "":
			var hay := ("%s %s" % [s.get("name", ""), s.get("words", "")]).to_lower()
			if hay.find(picker_query) < 0:
				continue
		list.append(s)
	list.sort_custom(func(a, b): return int(a.get("level", 0)) < int(b.get("level", 0)))
	return list

func _item_list() -> Array:
	var list: Array = []
	for iid in pack.keys():
		if int(iid) == 3031 or int(iid) == 3035 or int(iid) == 3043:
			continue   # gold / platinum / crystal không dùng được
		var e = pack[iid]
		var n := int(e.get("n", 0)) if e is Dictionary else int(e)
		var cat := str(e.get("cat", "others")) if e is Dictionary else "others"
		if picker_filter != "all" and cat != picker_filter:
			continue
		var nm := _item_name(int(iid))
		if picker_query != "" and nm.to_lower().find(picker_query) < 0:
			continue
		list.append({"id": int(iid), "n": n, "cat": cat, "name": nm})
	list.sort_custom(func(a, b): return str(a["name"]) < str(b["name"]))
	return list

func _fill_picker() -> void:
	for c in picker_grid.get_children():
		c.queue_free()
	for c in picker_sub.get_children():
		c.queue_free()
	for k in tab_btns:
		tab_btns[k].button_pressed = (k == picker_tab)
	var spell_tab := picker_tab == "spell"
	for f in (SPELL_FILTERS if spell_tab else ITEM_FILTERS):
		picker_sub.add_child(_chip(str(f[1]), picker_filter == str(f[0]), str(f[0])))
	var cur: Dictionary = slots[picker_slot] if picker_slot >= 0 and picker_slot < COUNT else {"kind": "", "ref": ""}
	var list: Array = _spell_list() if spell_tab else _item_list()
	picker_pager.set_total(list.size(), PICKER_PER_PAGE)
	if list.is_empty():
		var msg := ""
		if picker_query != "" or picker_filter != "all":
			msg = "Không có kết quả phù hợp."
		elif spell_tab:
			msg = "Chưa có spell đã học (mở bảng Spell để học)."
		else:
			msg = "Túi trống (không có đồ để gán)."
		picker_count.text = ""
		var l := UiKit.lab(msg, 12, Color(0.7, 0.7, 0.7))
		picker_grid.add_child(l)
		return
	picker_count.text = "%d %s" % [list.size(), "spell" if spell_tab else "loại đồ"]
	for e in Pager.slice(list, picker_pager.page, PICKER_PER_PAGE):
		var card: Button
		if spell_tab:
			var sid := str(e.get("id", ""))
			var words := str(e.get("words", ""))
			var nm := str(e.get("name", "?"))
			var accent: Color = SPELL_COLORS.get(str(e.get("tab", "appren")), Color(0.6, 0.7, 0.9))
			var sub := "%s · Lv %d · %d mana" % [words, int(e.get("level", 0)), int(e.get("mana", 0))]
			var tip := "%s (%s)\nLv %d · %d mana" % [nm, words, int(e.get("level", 0)), int(e.get("mana", 0))]
			card = _card(nm, sub, accent, IconBtn.load_icon("spell_" + sid), nm.left(1).to_upper(), tip,
				cur["kind"] == "spell" and str(cur["ref"]) == sid)
			card.pressed.connect(_assign.bind("spell", sid))
		else:
			var iid := int(e["id"])
			var accent2: Color = ITEM_COLORS.get(str(e["cat"]), Color(0.62, 0.72, 0.85))
			var nm2 := str(e["name"])
			card = _card(nm2, "x%d · %s" % [int(e["n"]), str(e["cat"])], accent2, IconBtn.load_icon("item_%d" % iid),
				nm2.left(1).to_upper(), "%s [%s]\nCó %d trong túi" % [nm2, str(e["cat"]), int(e["n"])],
				cur["kind"] == "item" and int(cur["ref"]) == iid)
			card.pressed.connect(_assign.bind("item", str(iid)))
		picker_grid.add_child(card)

func _assign(kind: String, ref: String) -> void:
	if picker_slot < 0 or picker_slot >= COUNT:
		return
	slots[picker_slot] = {"kind": kind, "ref": ref}
	_save()
	_refresh_slot(picker_slot)
	close_picker()

# ---------- lưu / nạp theo nhân vật ----------

func _path() -> String:
	return "user://hotbar_%s.cfg" % owner_name.validate_filename()

func _load() -> void:
	if slots.size() != COUNT:
		return  # chưa build()
	for i in COUNT:
		slots[i] = {"kind": "", "ref": ""}
	if owner_name == "":
		return
	var cf := ConfigFile.new()
	if cf.load(_path()) != OK:
		return
	for i in COUNT:
		var v := str(cf.get_value("hotbar", "s%d" % i, ""))
		var p := v.find(":")
		if p > 0:
			var k := v.left(p)
			if k == "item" or k == "spell":
				slots[i] = {"kind": k, "ref": v.substr(p + 1)}

func _save() -> void:
	if owner_name == "":
		return
	var cf := ConfigFile.new()
	for i in COUNT:
		var s: Dictionary = slots[i]
		cf.set_value("hotbar", "s%d" % i, "" if s["kind"] == "" else "%s:%s" % [s["kind"], s["ref"]])
	cf.save(_path())
