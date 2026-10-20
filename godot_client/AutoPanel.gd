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
const FULL_W := 700.0
const FULL_H := 470.0
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
var _on_btn: Button
var _min_btn: Button
var _radius_lab: Label
var _hp_chk: CheckBox
var _hp_opt: OptionButton
var _hp_pct: SpinBox
var _mp_chk: CheckBox
var _mp_opt: OptionButton
var _mp_pct: SpinBox
var _atk_chk: CheckBox
var _atk_opts: Array = []
var _food_chk: CheckBox
var _rune_chk: CheckBox
var _rune_opt: OptionButton
var _heal_chk: CheckBox
var _heal_opt: OptionButton
var _heal_pct: SpinBox
var _sup_chk: CheckBox
var _sup_opts: Array = []
var _sup_pct: SpinBox
var _sup_note: Label

func build() -> void:
	add_theme_stylebox_override("panel", UiKit.panel_style())
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	# --- đầu: tiêu đề + thu nhỏ/phóng to panel + đóng
	var head := HBoxContainer.new()
	root.add_child(head)
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
	# --- nút bật/tắt + trạng thái (luôn hiện kể cả khi thu nhỏ)
	_on_btn = Button.new()
	_on_btn.toggle_mode = true
	_on_btn.text = "AUTO: TẮT"
	_on_btn.custom_minimum_size = Vector2(0, 28)
	_on_btn.toggled.connect(_on_toggle)
	root.add_child(_on_btn)
	_status = UiKit.lab(STATUS_TEXT["idle"], 11, Color(0.75, 0.85, 0.95))
	_status.clip_text = true
	root.add_child(_status)
	# --- thân: 3 cột, hiện đủ không cần cuộn
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	root.add_child(cols)
	_body = cols
	var c1 := _column(cols)
	var c2 := _column(cols)
	var c3 := _column(cols)
	_build_arena(c1)
	_build_pot(c1)
	_build_attack(c2)
	_build_food(c2)
	c2.add_child(UiKit.lab("Auto AOE: chưa làm (xem báo cáo).", 10, Color(0.6, 0.65, 0.7)))
	_build_heal(c3)
	_build_support(c3)
	_build_rune(c3)
	refresh_all()

func _column(parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.custom_minimum_size = Vector2(200, 0)
	v.add_theme_constant_override("separation", 5)
	parent.add_child(v)
	return v

func _section(parent: Control, text: String) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)
	parent.add_child(UiKit.title(text, 12))

func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	return h

func _opt() -> OptionButton:
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.clip_text = true
	o.fit_to_longest_item = false
	o.custom_minimum_size = Vector2(110, 0)
	o.item_selected.connect(_on_widget_changed)
	return o

func _chk(text: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.toggled.connect(_on_widget_changed)
	return c

func _spin(lo: int, hi: int, suffix: String) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.suffix = suffix
	s.custom_minimum_size = Vector2(78, 0)
	s.value_changed.connect(_on_widget_changed)
	return s

func _build_arena(parent: Control) -> void:
	_section(parent, "Arena (vùng đánh)")
	var r := _row()
	parent.add_child(r)
	var minus := Button.new()
	minus.text = "–"
	minus.tooltip_text = "Thu nhỏ arena"
	minus.pressed.connect(_on_radius.bind(-1))
	r.add_child(minus)
	_radius_lab = UiKit.lab("", 12, Color(0.6, 1, 0.75))
	_radius_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_radius_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.add_child(_radius_lab)
	var plus := Button.new()
	plus.text = "+"
	plus.tooltip_text = "Phóng to arena"
	plus.pressed.connect(_on_radius.bind(1))
	r.add_child(plus)
	parent.add_child(UiKit.lab("Điểm xuất phát = ô đứng lúc bật Auto.", 10, Color(0.6, 0.65, 0.7)))

func _build_pot(parent: Control) -> void:
	_section(parent, "Auto Pot")
	_hp_chk = _chk("HP pot")
	parent.add_child(_hp_chk)
	_hp_opt = _opt()
	parent.add_child(_hp_opt)
	var r1 := _row()
	parent.add_child(r1)
	r1.add_child(UiKit.lab("dùng khi HP <", 11))
	_hp_pct = _spin(1, 99, "%")
	r1.add_child(_hp_pct)
	_mp_chk = _chk("MP (SP) pot")
	parent.add_child(_mp_chk)
	_mp_opt = _opt()
	parent.add_child(_mp_opt)
	var r2 := _row()
	parent.add_child(r2)
	r2.add_child(UiKit.lab("dùng khi MP <", 11))
	_mp_pct = _spin(1, 99, "%")
	r2.add_child(_mp_pct)

func _build_attack(parent: Control) -> void:
	_section(parent, "Auto Spell Attack")
	_atk_chk = _chk("Bật (ô 1 dùng trước)")
	parent.add_child(_atk_chk)
	for i in ATTACK_SLOTS:
		var r := _row()
		parent.add_child(r)
		r.add_child(UiKit.lab("%d." % (i + 1), 11, Color(1, 0.9, 0.5)))
		var o := _opt()
		r.add_child(o)
		_atk_opts.append(o)

func _build_food(parent: Control) -> void:
	_section(parent, "Auto Food")
	_food_chk = _chk("Tự ăn khi sắp đói")
	parent.add_child(_food_chk)
	parent.add_child(UiKit.lab("Ăn món bất kỳ đang có trong túi.", 10, Color(0.6, 0.65, 0.7)))

func _build_rune(parent: Control) -> void:
	_section(parent, "Auto Rune (dùng lên target)")
	_rune_chk = _chk("Bật")
	parent.add_child(_rune_chk)
	_rune_opt = _opt()
	parent.add_child(_rune_opt)

func _build_heal(parent: Control) -> void:
	_section(parent, "Auto Spell Heal (bản thân)")
	_heal_chk = _chk("Bật")
	parent.add_child(_heal_chk)
	_heal_opt = _opt()
	parent.add_child(_heal_opt)
	var r := _row()
	parent.add_child(r)
	r.add_child(UiKit.lab("dùng khi HP <", 11))
	_heal_pct = _spin(1, 99, "%")
	r.add_child(_heal_pct)

func _build_support(parent: Control) -> void:
	_section(parent, "Auto Support tạo rune")
	_sup_chk = _chk("Bật")
	parent.add_child(_sup_chk)
	for i in SUPPORT_SLOTS:
		var r := _row()
		parent.add_child(r)
		r.add_child(UiKit.lab("%d." % (i + 1), 11, Color(1, 0.9, 0.5)))
		var o := _opt()
		r.add_child(o)
		_sup_opts.append(o)
	var r2 := _row()
	parent.add_child(r2)
	r2.add_child(UiKit.lab("chỉ tạo khi MP ≥", 11))
	_sup_pct = _spin(1, 100, "%")
	r2.add_child(_sup_pct)
	_sup_note = UiKit.lab("", 10, Color(0.95, 0.6, 0.45))
	parent.add_child(_sup_note)

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
	if _on_btn != null:
		_on_btn.set_pressed_no_signal(on)
		_on_btn.text = "AUTO: BẬT" if on else "AUTO: TẮT"
		_on_btn.modulate = Color(0.5, 1, 0.5) if on else Color.WHITE
	if _status != null:
		_status.text = STATUS_TEXT.get(status, status) if on else STATUS_TEXT["idle"]

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
	return {"id": str(s.get("id", "")), "label": lab}

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
		out.append({"id": int(p["id"]), "label": "%s (%d-%d) x%d" % [nm, int(rng[0]), int(rng[1]), have]})
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
		out.append({"id": id, "label": "%s x%d" % [TibiaUI.name_of(id), have]})
	return out

func _fill(ob: OptionButton, entries: Array, current) -> void:
	_syncing = true
	ob.clear()
	ob.add_item("— trống —")
	ob.set_item_metadata(0, null)
	var sel := 0
	for e in entries:
		ob.add_item(str(e["label"]))
		var idx := ob.item_count - 1
		ob.set_item_metadata(idx, e["id"])
		if current != null and typeof(current) == typeof(e["id"]) and current == e["id"]:
			sel = idx
	ob.select(sel)
	_syncing = false

func _picked(ob: OptionButton, empty_value):
	var idx := ob.selected
	if idx < 0:
		return empty_value
	var m = ob.get_item_metadata(idx)
	return empty_value if m == null else m

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

func _on_toggle(on: bool) -> void:
	_on_btn.text = "AUTO: BẬT" if on else "AUTO: TẮT"
	_on_btn.modulate = Color(0.5, 1, 0.5) if on else Color.WHITE
	toggled.emit(on)

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
