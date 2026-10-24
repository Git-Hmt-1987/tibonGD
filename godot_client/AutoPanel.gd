class_name AutoPanel
extends PanelContainer
## Panel AUTO (14/10/2026): bật/tắt Auto, thu nhỏ/phóng to Arena, Auto Pot, Auto Spell Attack (xếp trước dùng trước),
## Auto Heal bản thân, Auto Support tạo rune. Toàn bộ logic chạy ở SERVER (tibia_py/auto.py); panel chỉ gửi cấu hình.
## Nguồn dữ liệu: gói `hello.auto` (potion, giới hạn, cấu hình đã lưu), gói `spells`, gói `backpack`, gói `auto_state`.
## Cấu hình gửi lên: op `auto_cfg {cfg}` (đầy đủ mỗi lần đổi); server chuẩn hóa rồi trả `auto_state`.
## Cấu hình từ `auto_state` KHÔNG ghi đè ô đang chỉnh (chỉ `hello` mới nạp lại cấu hình) để tránh nhảy số khi chỉnh nhanh.

signal cfg_changed(cfg: Dictionary)
signal toggled(on: bool)

const RADIUS_MIN := 1
const RADIUS_MAX := 15
const ATTACK_SLOTS := 5
const SUPPORT_SLOTS := 1
const FULL_W := 640.0
const FULL_H := 400.0
const MINI_H := 100.0   # chỉ còn tiêu đề + nút bật/tắt + trạng thái
const STATUS_TEXT := {
	"idle": "Tắt",
	"waiting": "Chờ quái ở điểm xuất phát",
	"hunting": "Đang đánh quái",
	"returning": "Đang quay về điểm xuất phát",
}

var cfg := {
	"radius": 6,
	"hp_pot": {"on": false, "item": 0, "pct": 50},
	"mp_pot": {"on": false, "item": 0, "pct": 30},
	"attack": {"on": false, "spells": []},
	"heal": {"on": false, "spell": "", "pct": 60},
	"food": {"on": false},
	"rune": {"on": false, "item": 0},
	"support": {"on": false, "spells": [], "min_mp": 70},
}
var attack_runes: Array = []   # id rune tấn công (hello.auto.attack_runes); lọc trong túi
var potions: Array = []        # [{id,name,hp:[lo,hi]|null,mp:[lo,hi]|null,level,vocs:[..]|null}] từ hello.auto.potions
var backpack := {}             # {item_id: {n, cat}}
var all_spells: Array = []     # gói `spells` (đã lọc vocation ở server)
var my_level := 1
var voc := 4
var has_premium := true
var auto_on := false
var collapsed := false

var _syncing := false
var _body: Control
var _status: Label
var _min_btn: Button
var _radius_lab: Label
var _hp_chk: CheckBox
var _hp_opt: AutoSlot
var _hp_pct: SpinBox
var _mp_chk: CheckBox
var _mp_opt: AutoSlot
var _mp_pct: SpinBox
var _atk_chk: CheckBox
var _atk_opts: Array = []
var _food_chk: CheckBox
var _rune_chk: CheckBox
var _rune_opt: AutoSlot
var _heal_chk: CheckBox
var _heal_opt: AutoSlot
var _heal_pct: SpinBox
var _sup_chk: CheckBox
var _sup_opts: Array = []
var _sup_pct: SpinBox
var _sup_note: Label

func build() -> void:
	add_theme_stylebox_override("panel", UiKit.panel_style())
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	# --- đầu: tiêu đề + thu nhỏ/phóng to panel + đóng
	var head := HBoxContainer.new()
	root.add_child(head)
	UiKit.head_sep(head)
	var tt := UiKit.title("AUTO", 14)
	tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tt)
	_min_btn = Button.new()
	_min_btn.text = "–"
	_min_btn.tooltip_text = "Thu nhỏ / phóng to panel"
	_min_btn.pressed.connect(_toggle_collapse)
	head.add_child(_min_btn)
	var x := Button.new()
	x.text = "X"
	x.pressed.connect(hide)
	head.add_child(x)
	# --- trạng thái Auto (bật/tắt bằng nút Auto ở thanh dock hoặc phím T)
	_status = UiKit.lab(STATUS_TEXT["idle"], 11, Color(0.75, 0.85, 0.95))
	_status.clip_text = true
	_status.add_theme_color_override("font_color", UiTheme.accent_dark())
	root.add_child(_status)
	# --- thân: thanh tab + 3 trang
	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	root.add_child(body)
	_body = body
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	body.add_child(tabs)
	for t in TABS:
		var key: String = t[0]
		var tb := Button.new()
		tb.text = t[1]
		tb.focus_mode = Control.FOCUS_NONE
		tb.custom_minimum_size = Vector2(0, 34)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_override("font", UiKit.bold_font())
		tb.add_theme_font_size_override("font_size", 14)
		tb.pressed.connect(func(): _set_tab(key))
		tabs.add_child(tb)
		_tab_btns[key] = tb
	var pot_page := _page(body)
	var c1 := _column(pot_page)
	var c2 := _column(pot_page)
	_build_pot(c1, c2)
	_pages["pot"] = pot_page
	var spell_page := _page(body)
	var s1 := _column(spell_page)
	var s2 := _column(spell_page)
	_build_attack(s1)
	_build_heal(s2)
	_build_aoe(s2)
	_pages["spell"] = spell_page
	var melee_page := _page(body)
	var m1 := _column(melee_page)
	var m2 := _column(melee_page)
	_build_arena(m1)
	_build_food(m1)
	_build_support(m2)
	_build_rune(m2)
	_pages["melee"] = melee_page
	_popup = _make_popup()
	add_child(_popup)
	_set_tab("pot")
	refresh_all()

const TABS := [["pot", "Auto Potion"], ["spell", "Auto Spell"], ["melee", "Auto đánh thường"]]
var _tab_btns := {}
var _pages := {}
var _sliders: Array = []   # [[SpinBox, HSlider]] giữ 2 chiều đồng bộ

func _page(parent: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 10)
	parent.add_child(h)
	return h

func _set_tab(key: String) -> void:
	_close_popup()
	for k in _pages:
		_pages[k].visible = (k == key)
	for k in _tab_btns:
		var b: Button = _tab_btns[k]
		var on: bool = (k == key)
		var bg: Color = UiTheme.accent().lightened(0.1) if on else Color("#e8ddbf")
		var bd: Color = UiTheme.accent_dark() if on else Color("#c9bfa0")
		b.add_theme_stylebox_override("normal", CharPanel._box(bg, bd, 2, 5))
		b.add_theme_stylebox_override("hover", CharPanel._box(bg.lightened(0.1), bd, 2, 5))
		b.add_theme_stylebox_override("pressed", CharPanel._box(bg.darkened(0.08), bd, 2, 5))
		for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(cn, Color.WHITE if on else Color("#2a3354"))

func _column(parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.custom_minimum_size = Vector2(250, 0)
	v.add_theme_constant_override("separation", 8)
	parent.add_child(v)
	return v

## Thẻ nền sáng viền mảnh: trả về VBox bên trong để thêm nội dung.
func _card(parent: Control) -> VBoxContainer:
	var pc := PanelContainer.new()
	var sb := CharPanel._box(Color("#fffdf6"), Color("#c9bfa0"), 2, 5)
	sb.set_content_margin_all(10)
	pc.add_theme_stylebox_override("panel", sb)
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	return v

func _note(parent: Control, text: String) -> void:
	var l := UiKit.lab(text, 11, Color(0.4, 0.4, 0.45))
	l.add_theme_color_override("font_color", UiTheme.muted())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(200, 0)
	parent.add_child(l)

func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	return h

func _opt() -> AutoSlot:
	var o := AutoSlot.new()
	o.changed.connect(_on_widget_changed)
	o.open_requested.connect(_open_popup)
	return o

func _chk(text: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.add_theme_font_override("font", UiKit.bold_font())
	c.add_theme_font_size_override("font_size", 14)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		c.add_theme_stylebox_override(st, StyleBoxEmpty.new())   # bỏ khung chip, chỉ còn ô tick + chữ
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		c.add_theme_color_override(cn, Color(0.1, 0.1, 0.15))
	c.add_theme_icon_override("unchecked", _chk_tex(false))
	c.add_theme_icon_override("checked", _chk_tex(true))
	c.add_theme_icon_override("unchecked_disabled", _chk_tex(false))
	c.add_theme_icon_override("checked_disabled", _chk_tex(true))
	c.toggled.connect(_on_widget_changed)
	return c

static var _chk_cache := {}

## Ô tích tự vẽ: nền vàng kem đậm, viền nâu vàng, dấu tích xanh đậm khi bật.
static func _chk_tex(on: bool) -> Texture2D:
	if _chk_cache.has(on):
		return _chk_cache[on]
	var n := 22
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fill := Color("#e6d5a3")
	var edge := Color("#9c8a5e")
	for y in n:
		for x in n:
			var dx := mini(x, n - 1 - x)
			var dy := mini(y, n - 1 - y)
			if dx < 1 and dy < 1:
				continue   # bo góc nhỏ
			img.set_pixel(x, y, edge if (dx < 2 or dy < 2) else fill)
	if on:
		var ink := Color("#1f4fa3")
		var pts := [Vector2(5, 11), Vector2(9, 15), Vector2(17, 6)]
		for i in 2:
			var p0: Vector2 = pts[i]
			var p1: Vector2 = pts[i + 1]
			for t in 41:
				var q := p0.lerp(p1, t / 40.0)
				for ox in [-1, 0, 1]:
					for oy in [-1, 0, 1]:
						img.set_pixel(clampi(int(q.x) + ox, 0, n - 1), clampi(int(q.y) + oy, 0, n - 1), ink)
	var tex := ImageTexture.create_from_image(img)
	_chk_cache[on] = tex
	return tex

func _spin(lo: int, hi: int, suffix: String) -> SpinBox:
	var s := RowKit.right_spin(SpinBox.new())
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.suffix = suffix
	s.custom_minimum_size = Vector2(78, 0)
	s.value_changed.connect(_on_widget_changed)
	return s

## Hàng "nhãn · thanh kéo · ô số %": thanh kéo và SpinBox luôn khớp nhau.
func _pct_row(parent: Control, label: String, spin: SpinBox) -> void:
	var r := _row()
	parent.add_child(r)
	var l := UiKit.lab(label, 12, Color(0.1, 0.1, 0.15))
	l.add_theme_font_override("font", UiKit.bold_font())
	r.add_child(l)
	var sl := HSlider.new()
	sl.min_value = spin.min_value
	sl.max_value = spin.max_value
	sl.step = 1
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.custom_minimum_size = Vector2(80, 18)
	sl.value_changed.connect(func(v: float): if not _syncing: spin.value = v)
	spin.value_changed.connect(func(v: float): sl.set_value_no_signal(v))
	r.add_child(sl)
	r.add_child(spin)
	_sliders.append([spin, sl])

func _sync_sliders() -> void:
	for p in _sliders:
		(p[1] as HSlider).set_value_no_signal((p[0] as SpinBox).value)

func _build_arena(parent: Control) -> void:
	var c := _card(parent)
	c.add_child(UiKit.title("Arena (vùng đánh)", 13))
	var r := _row()
	c.add_child(r)
	var minus := Button.new()
	minus.text = "–"
	minus.tooltip_text = "Thu nhỏ arena"
	minus.custom_minimum_size = Vector2(36, 30)
	minus.pressed.connect(_on_radius.bind(-1))
	r.add_child(minus)
	_radius_lab = UiKit.lab("", 13, Color(0.1, 0.35, 0.2))
	_radius_lab.add_theme_font_override("font", UiKit.bold_font())
	_radius_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_radius_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.add_child(_radius_lab)
	var plus := Button.new()
	plus.text = "+"
	plus.tooltip_text = "Phóng to arena"
	plus.custom_minimum_size = Vector2(36, 30)
	plus.pressed.connect(_on_radius.bind(1))
	r.add_child(plus)
	_note(c, "Điểm xuất phát = ô đứng lúc bật Auto. Nhân vật chỉ đi trong vùng này để tìm và đánh quái.")

## Hàng: ô chọn vuông bên trái + cột điều khiển bên phải (trả về cột đó).
func _slot_row(parent: Control, slot: AutoSlot) -> VBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	parent.add_child(h)
	slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(slot)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 6)
	h.add_child(v)
	return v

func _build_pot(left: Control, _right: Control) -> void:
	var c := _card(left)
	_hp_chk = _chk("Dùng HP potion tự động")
	c.add_child(_hp_chk)
	_hp_opt = _opt()
	var v := _slot_row(c, _hp_opt)
	_hp_pct = _spin(1, 99, "%")
	_pct_row(v, "Khi HP ≤", _hp_pct)
	_note(c, "Bấm ô vuông để chọn potion. Uống khi HP xuống dưới ngưỡng; chỉ hiện potion hợp level và nghề.")
	var c2 := _card(_right)
	_mp_chk = _chk("Dùng MP (SP) potion tự động")
	c2.add_child(_mp_chk)
	_mp_opt = _opt()
	var v2 := _slot_row(c2, _mp_opt)
	_mp_pct = _spin(1, 99, "%")
	_pct_row(v2, "Khi MP ≤", _mp_pct)
	_note(c2, "Bấm ô vuông để chọn potion mana. Uống khi MP xuống dưới ngưỡng.")

func _build_attack(parent: Control) -> void:
	var c := _card(parent)
	_atk_chk = _chk("Auto Spell Attack")
	c.add_child(_atk_chk)
	_note(c, "Bấm ô vuông để chọn spell. Ô trái nhất dùng trước; hết mana hoặc đang hồi thì dùng ô kế tiếp.")
	var r := _row()
	r.add_theme_constant_override("separation", 8)
	c.add_child(r)
	for i in ATTACK_SLOTS:
		var o := _opt()
		r.add_child(o)
		_atk_opts.append(o)

func _build_heal(parent: Control) -> void:
	var c := _card(parent)
	_heal_chk = _chk("Auto Spell Heal (bản thân)")
	c.add_child(_heal_chk)
	_heal_opt = _opt()
	var v := _slot_row(c, _heal_opt)
	_heal_pct = _spin(1, 99, "%")
	_pct_row(v, "Khi HP ≤", _heal_pct)

func _build_aoe(parent: Control) -> void:
	var c := _card(parent)
	c.add_child(UiKit.title("Auto Spell AOE", 13))
	_note(c, "Chưa làm.")

func _build_food(parent: Control) -> void:
	var c := _card(parent)
	_food_chk = _chk("Auto Food")
	c.add_child(_food_chk)
	_note(c, "Tự ăn khi sắp đói, món bất kỳ đang có trong túi.")

func _build_rune(parent: Control) -> void:
	var c := _card(parent)
	_rune_chk = _chk("Auto Rune (dùng lên target)")
	c.add_child(_rune_chk)
	_rune_opt = _opt()
	var v := _slot_row(c, _rune_opt)
	_note(v, "Bấm ô vuông để chọn rune tấn công đang có trong túi.")

func _build_support(parent: Control) -> void:
	var c := _card(parent)
	_sup_chk = _chk("Auto tạo rune")
	c.add_child(_sup_chk)
	var o := _opt()
	var v := _slot_row(c, o)
	_sup_opts.append(o)
	_sup_pct = _spin(1, 100, "%")
	_pct_row(v, "Tạo khi MP ≥", _sup_pct)
	_sup_note = UiKit.lab("", 10, Color(0.75, 0.3, 0.2))
	_sup_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sup_note.custom_minimum_size = Vector2(200, 0)
	c.add_child(_sup_note)

# ---------------------------------------------------------------- bảng chọn (popup) cho ô vuông

var _popup: PanelContainer
var _pop_title: Label
var _pop_grid: GridContainer
var _pop_slot: AutoSlot = null

func _make_popup() -> PanelContainer:
	var p := PanelContainer.new()
	p.top_level = true   # container cha không sắp xếp; toạ độ theo màn hình
	p.visible = false
	p.z_index = 50
	var sb := CharPanel._box(Color("#f4e8c8"), UiTheme.accent_dark(), 2, 5)
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	_pop_title = UiKit.title("Chọn", 13)
	v.add_child(_pop_title)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(430, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	_pop_grid = GridContainer.new()
	_pop_grid.columns = 2
	_pop_grid.add_theme_constant_override("h_separation", 6)
	_pop_grid.add_theme_constant_override("v_separation", 6)
	_pop_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_pop_grid)
	return p

func _open_popup(slot: AutoSlot) -> void:
	if _popup.visible and _pop_slot == slot:
		_close_popup()
		return
	_pop_slot = slot
	for c in _pop_grid.get_children():
		_pop_grid.remove_child(c)
		c.queue_free()
	_pop_title.text = "Chọn (bấm lại ô để đóng)"
	_pop_grid.add_child(_pop_card(slot, {"id": null, "label": "— Bỏ trống —", "icon": ""}))
	for e in slot.entries:
		_pop_grid.add_child(_pop_card(slot, e))
	if slot.entries.is_empty():
		_pop_title.text = "Chưa có gì để chọn"
	_popup.visible = true
	_popup.reset_size()
	var sc: ScrollContainer = _pop_grid.get_parent()
	sc.custom_minimum_size.y = minf(280.0, _pop_grid.get_combined_minimum_size().y)
	_popup.reset_size()
	var vp := get_viewport_rect().size
	var pos := slot.global_position + Vector2(0, slot.size.y + 4)
	if pos.y + _popup.size.y > vp.y - 6:
		pos.y = maxf(6.0, slot.global_position.y - _popup.size.y - 4)
	pos.x = clampf(pos.x, 6.0, maxf(6.0, vp.x - _popup.size.x - 6))
	_popup.global_position = pos

func _close_popup() -> void:
	if _popup != null:
		_popup.visible = false
	_pop_slot = null

func _pop_card(slot: AutoSlot, e: Dictionary) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cur: bool = (e["id"] == null and slot.value == null) or (e["id"] != null and slot.value != null and typeof(e["id"]) == typeof(slot.value) and e["id"] == slot.value)
	var base := UiTheme.accent_light() if cur else Color("#fbf3dc")
	var edge := UiTheme.accent() if cur else Color("#bfae82")
	b.add_theme_stylebox_override("normal", CharPanel._box(base, edge, 2, 5))
	b.add_theme_stylebox_override("hover", CharPanel._box(base.lightened(0.2), UiTheme.accent(), 2, 5))
	b.add_theme_stylebox_override("pressed", CharPanel._box(base, UiTheme.accent_dark(), 2, 5))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	b.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	var ic := AutoSlot.Mini.new()
	ic.setup(str(e.get("icon", "")), str(e["label"]))
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var t := UiKit.lab(str(e["label"]), 12, Color(0.1, 0.1, 0.15))
	t.add_theme_font_override("font", UiKit.bold_font())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(t)
	b.pressed.connect(func():
		slot.set_value(e["id"], e)
		_close_popup()
		_on_widget_changed())
	return b

func _input(ev: InputEvent) -> void:
	if _popup != null and _popup.visible and ev is InputEventMouseButton and ev.pressed:
		if not _popup.get_global_rect().has_point(ev.position) and not (_pop_slot != null and _pop_slot.get_global_rect().has_point(ev.position)):
			_close_popup()

# ---------------------------------------------------------------- dữ liệu từ server

## hello.auto: {on, cfg, potions, limits}. Nạp cấu hình đã lưu vào panel.
func set_info(info: Dictionary) -> void:
	potions = info.get("potions", [])
	attack_runes = info.get("attack_runes", [])
	auto_on = false
	if info.get("cfg") is Dictionary:
		_merge_cfg(info["cfg"])
	refresh_all()
	_apply_on(false, "idle")

func set_spells(spells: Array, p_voc: int) -> void:
	all_spells = spells
	voc = p_voc
	refresh_all()

func set_backpack(items: Dictionary) -> void:
	backpack = items
	refresh_pots()

func set_level(lv: int) -> void:
	if lv != my_level:
		my_level = lv
		refresh_all()

func set_premium(on: bool) -> void:
	if on != has_premium:
		has_premium = on
		refresh_all()

## auto_state: {on, cfg, origin, status, reason?}. Chỉ lấy trạng thái bật/tắt + trạng thái săn (xem ghi chú đầu file).
func apply_state(msg: Dictionary) -> void:
	_apply_on(bool(msg.get("on", false)), str(msg.get("status", "idle")))

func _apply_on(on: bool, status: String) -> void:
	auto_on = on
	if _status != null:
		_status.text = ("Auto BẬT · " + str(STATUS_TEXT.get(status, status))) if on else "Auto TẮT (bật bằng nút Auto ở dock / phím T)"

func _merge_cfg(src: Dictionary) -> void:
	cfg["radius"] = clampi(int(src.get("radius", cfg["radius"])), RADIUS_MIN, RADIUS_MAX)
	for k in ["hp_pot", "mp_pot", "attack", "heal", "food", "rune", "support"]:
		if src.get(k) is Dictionary:
			for kk in src[k]:
				cfg[k][kk] = src[k][kk]

# ---------------------------------------------------------------- danh sách chọn

func _learned_spells() -> Array:
	var out: Array = []
	for s in all_spells:
		if not s.get("learned", false):
			continue
		if s.get("prem", false) and not has_premium:
			continue
		var ok := false
		for vv in s.get("voc", [1, 2, 3, 4]):
			if int(vv) == voc:
				ok = true
		if ok:
			out.append(s)
	out.sort_custom(func(a, b): return int(a.get("level", 0)) < int(b.get("level", 0)))
	return out

func _spell_entry(s: Dictionary) -> Dictionary:
	var lab := "%s (%d mana)" % [s.get("name", "?"), int(s.get("mana", 0))]
	if int(s.get("level", 0)) > my_level:
		lab += " Lv%d" % int(s.get("level", 0))
	return {"id": str(s.get("id", "")), "label": lab, "icon": "spell_" + str(s.get("id", "")), "name": str(s.get("name", "?"))}

## Spell tấn công 1 mục tiêu (khớp luật server auto.attack_ok): kind single + aim target/target_or_dir.
func _attack_entries() -> Array:
	var out: Array = []
	for s in _learned_spells():
		if str(s.get("kind", "")) == "single" and str(s.get("aim", "")) in ["target", "target_or_dir"]:
			out.append(_spell_entry(s))
	return out

## Spell hồi máu cho bản thân (khớp auto.heal_ok).
func _heal_entries() -> Array:
	var out: Array = []
	for s in _learned_spells():
		if str(s.get("kind", "")) == "heal" and str(s.get("aim", "")) in ["self", "pos"] \
				and str(s.get("element", "")) == "COMBAT_HEALING":
			out.append(_spell_entry(s))
	return out

## Spell tạo rune (khớp auto.support_ok).
func _support_entries() -> Array:
	var out: Array = []
	for s in _learned_spells():
		if str(s.get("kind", "")) == "conjure":
			out.append(_spell_entry(s))
	return out

func _pot_entries(kind: String) -> Array:
	var out: Array = []
	for p in potions:
		var rng = p.get("hp") if kind == "hp" else p.get("mp")
		if not (rng is Array) or rng.size() < 2:
			continue
		if int(p.get("level", 0)) > my_level:
			continue
		var vocs = p.get("vocs")
		if vocs is Array:
			var voc_ok := false
			for vv in vocs:
				if int(vv) == voc:   # JSON trả số thực (4.0): so bằng int
					voc_ok = true
			if not voc_ok:
				continue
		var nm := str(p.get("name", ""))
		if nm == "":
			nm = TibiaUI.name_of(int(p["id"]))
		var have := 0
		var e = backpack.get(int(p["id"]), null)
		if e is Dictionary:
			have = int(e.get("n", 0))
		out.append({"id": int(p["id"]), "label": "%s (%d-%d) x%d" % [nm, int(rng[0]), int(rng[1]), have], "icon": "item_%d" % int(p["id"]), "name": nm, "n": have})
	return out

## Rune tấn công đang có trong túi (+ rune đã chọn dù hết) để danh sách gọn.
func _rune_entries() -> Array:
	var out: Array = []
	var cur := int(cfg["rune"]["item"])
	for rid in attack_runes:
		var id := int(rid)
		var have := 0
		var e = backpack.get(id, null)
		if e is Dictionary:
			have = int(e.get("n", 0))
		if have <= 0 and id != cur:
			continue
		out.append({"id": id, "label": "%s x%d" % [TibiaUI.name_of(id), have], "icon": "item_%d" % id, "name": TibiaUI.name_of(id), "n": have})
	return out

func _fill(ob: AutoSlot, entries: Array, current) -> void:
	_syncing = true
	ob.entries = entries
	ob.value = null
	ob.info = {}
	for e in entries:
		if current != null and typeof(current) == typeof(e["id"]) and current == e["id"]:
			ob.value = e["id"]
			ob.info = e
	ob.queue_redraw()
	ob.refresh_tip()
	_syncing = false

func _picked(ob: AutoSlot, empty_value):
	return empty_value if ob.value == null else ob.value

func refresh_pots() -> void:
	if _hp_opt == null:
		return
	_fill(_hp_opt, _pot_entries("hp"), int(cfg["hp_pot"]["item"]))
	_fill(_mp_opt, _pot_entries("mp"), int(cfg["mp_pot"]["item"]))
	_fill(_rune_opt, _rune_entries(), int(cfg["rune"]["item"]))

## Dựng lại mọi ô từ `cfg` hiện có (sau khi nhận spells / level / hello...).
func refresh_all() -> void:
	if _hp_opt == null:
		return
	_syncing = true
	_radius_lab.text = _radius_text()
	_hp_chk.set_pressed_no_signal(bool(cfg["hp_pot"]["on"]))
	_mp_chk.set_pressed_no_signal(bool(cfg["mp_pot"]["on"]))
	_hp_pct.set_value_no_signal(float(cfg["hp_pot"]["pct"]))
	_mp_pct.set_value_no_signal(float(cfg["mp_pot"]["pct"]))
	_atk_chk.set_pressed_no_signal(bool(cfg["attack"]["on"]))
	_food_chk.set_pressed_no_signal(bool(cfg["food"]["on"]))
	_rune_chk.set_pressed_no_signal(bool(cfg["rune"]["on"]))
	_heal_chk.set_pressed_no_signal(bool(cfg["heal"]["on"]))
	_heal_pct.set_value_no_signal(float(cfg["heal"]["pct"]))
	_sup_chk.set_pressed_no_signal(bool(cfg["support"]["on"]))
	_sup_pct.set_value_no_signal(float(cfg["support"]["min_mp"]))
	_syncing = false
	_sync_sliders()
	refresh_pots()
	var atk := _attack_entries()
	var chosen: Array = cfg["attack"]["spells"]
	for i in _atk_opts.size():
		_fill(_atk_opts[i], atk, chosen[i] if i < chosen.size() else null)
	_fill(_heal_opt, _heal_entries(), str(cfg["heal"]["spell"]))
	var sup := _support_entries()
	var chosen2: Array = cfg["support"]["spells"]
	for i in _sup_opts.size():
		_fill(_sup_opts[i], sup, chosen2[i] if i < chosen2.size() else null)
	_sup_note.text = "" if not sup.is_empty() else "Chưa có spell tạo rune đã học (nghề này có thể không có)."

func _radius_text() -> String:
	var r := int(cfg["radius"])
	return "Bán kính %d  (%d×%d ô)" % [r, 2 * r + 1, 2 * r + 1]

# ---------------------------------------------------------------- sự kiện

func _toggle_collapse() -> void:
	collapsed = not collapsed
	_body.visible = not collapsed
	_min_btn.text = "+" if collapsed else "–"
	offset_bottom = offset_top + (MINI_H if collapsed else FULL_H)

func _on_radius(d: int) -> void:
	cfg["radius"] = clampi(int(cfg["radius"]) + d, RADIUS_MIN, RADIUS_MAX)
	_radius_lab.text = _radius_text()
	cfg_changed.emit(cfg)

func _on_widget_changed(_v = null) -> void:
	if _syncing:
		return
	_collect()
	cfg_changed.emit(cfg)

## Đọc lại mọi ô thành `cfg`.
func _collect() -> void:
	cfg["hp_pot"] = {"on": _hp_chk.button_pressed, "item": int(_picked(_hp_opt, 0)), "pct": int(_hp_pct.value)}
	cfg["mp_pot"] = {"on": _mp_chk.button_pressed, "item": int(_picked(_mp_opt, 0)), "pct": int(_mp_pct.value)}
	var atk: Array = []
	for o in _atk_opts:
		var sid := str(_picked(o, ""))
		if sid != "" and not (sid in atk):
			atk.append(sid)
	cfg["attack"] = {"on": _atk_chk.button_pressed, "spells": atk}
	cfg["food"] = {"on": _food_chk.button_pressed}
	cfg["rune"] = {"on": _rune_chk.button_pressed, "item": int(_picked(_rune_opt, 0))}
	cfg["heal"] = {"on": _heal_chk.button_pressed, "spell": str(_picked(_heal_opt, "")), "pct": int(_heal_pct.value)}
	var sup: Array = []
	for o in _sup_opts:
		var sid2 := str(_picked(o, ""))
		if sid2 != "" and not (sid2 in sup):
			sup.append(sid2)
	cfg["support"] = {"on": _sup_chk.button_pressed, "spells": sup, "min_mp": int(_sup_pct.value)}


## Ô vuông chọn (giống ô Hotbar): trống = dấu +, có = icon (thiếu icon thì chữ cái đầu). Bấm = mở bảng chọn.
class AutoSlot extends Button:
	signal changed
	signal open_requested(slot)
	const SZ := 52
	var entries: Array = []
	var value = null      # id đang chọn (int / String) hoặc null
	var info := {}

	func _init() -> void:
		custom_minimum_size = Vector2(SZ, SZ)
		focus_mode = Control.FOCUS_NONE
		pressed.connect(func(): open_requested.emit(self))
		var n := CharPanel._box(Color("#e6d5a3"), Color("#9c8a5e"), 2, 5)
		add_theme_stylebox_override("normal", n)
		add_theme_stylebox_override("hover", CharPanel._box(Color("#efe0b4"), UiTheme.accent(), 2, 5))
		add_theme_stylebox_override("pressed", CharPanel._box(Color("#d8c690"), UiTheme.accent_dark(), 2, 5))

	func set_value(id, e: Dictionary) -> void:
		value = id
		info = e if id != null else {}
		queue_redraw()
		refresh_tip()
		changed.emit()

	func refresh_tip() -> void:
		tooltip_text = ("%s\nBấm để đổi" % str(info.get("name", info.get("label", "")))) if value != null else "Ô trống — bấm để chọn"

	func _draw() -> void:
		if value == null:
			var c := size * 0.5
			var col := Color("#a8966a")
			draw_line(c - Vector2(8, 0), c + Vector2(8, 0), col, 2.0, true)
			draw_line(c - Vector2(0, 8), c + Vector2(0, 8), col, 2.0, true)
			return
		var tex: Texture2D = IconBtn.load_icon(str(info.get("icon", ""))) if str(info.get("icon", "")) != "" else null
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(5, 5), size - Vector2(10, 10)), false)
		else:
			var nm := str(info.get("name", "?"))
			draw_string(get_theme_default_font(), Vector2(0, size.y * 0.5 + 8), nm.left(1).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color("#4a3c18"))
		if info.has("n"):
			var n := int(info["n"])
			draw_string(get_theme_default_font(), Vector2(0, size.y - 4), str(n), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4, 12, Color("#c0392b") if n <= 0 else Color("#2a2210"), 12)

	## Icon nhỏ trong thẻ của bảng chọn.
	class Mini extends Control:
		var tex: Texture2D = null
		var letter := "?"

		func setup(icon_name: String, label: String) -> void:
			custom_minimum_size = Vector2(36, 36)
			size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if icon_name != "":
				tex = IconBtn.load_icon(icon_name)
			letter = label.left(1).to_upper() if label != "— Bỏ trống —" else "∅"

		func _draw() -> void:
			draw_style_box(CharPanel._box(Color("#e6d5a3"), Color("#9c8a5e"), 2, 5), Rect2(Vector2.ZERO, size))
			if tex != null:
				draw_texture_rect(tex, Rect2(Vector2(3, 3), size - Vector2(6, 6)), false)
			else:
				draw_string(get_theme_default_font(), Vector2(0, size.y * 0.5 + 6), letter, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, Color("#4a3c18"))
