class_name VitalsBlock
extends PanelContainer
## Khối trên-trái (D1 tách từ TibiaUI): chân dung + level, tên, thanh HP / Mana / Stamina,
## và 3 icon chế độ chiến đấu Attack / Balance / Defense (bật = sáng, tắt = xám).
## Logic stamina/màu giữ nguyên bản cũ (player.hpp staminaMinutes, getFinalBonusStamina).

signal fight_selected(mode: String)
signal chase_toggled(on: bool)   # nút Đ: bật = đuổi target đã chọn, tắt = đứng im (vẫn đánh khi trong tầm)

const STAMINA_MAX := 2520  # phút (42h)
# Ngưỡng theo server: >2340 (39h) xanh = exp x1.5 nếu Premium · 841..2340 cam = x1.0 · <=840 (14h) đỏ = x0.5
const ST_GREEN := Color(0.3, 0.78, 0.3)
const ST_ORANGE := Color(0.95, 0.6, 0.15)
const ST_RED := Color(0.85, 0.15, 0.15)
const FIGHT_MODES := [
	["attack", "At", "Attack (dmg 100%, def 50%)", Color(0.85, 0.25, 0.2)],
	["balanced", "Ba", "Balance (dmg 75%, def 75%)", Color(0.9, 0.7, 0.2)],
	["defense", "De", "Defense (dmg 50%, def 100%)", Color(0.25, 0.5, 0.9)],
]

var hp: ProgressBar
var hp_text: Label
var mp: ProgressBar
var mp_text: Label
var st: ProgressBar
var st_text: Label
var name_lab: Label
var lvl_lab: Label
var job_lab: Label
var portrait: Portrait
var fight_btns := {}
var chase_btn: IconBtn  # nút "Đuổi theo", nằm cạnh 3 nút Attack/Balance/Defense
var prem_btn: IconBtn  # icon Premium (chỉ hiển thị: sáng = có Premium, xám = không), căn phải cùng hàng fight
var _prem := false

func build() -> void:
	add_theme_stylebox_override("panel", UiKit.panel_style())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)
	# cột trái: avatar tròn + huy hiệu "Lv N" (pill vàng) đè lên mép dưới avatar
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", -9)
	top.add_child(left)
	var av := Portrait.new()
	portrait = av
	av.circle = true
	av.custom_minimum_size = Vector2(58, 58)
	left.add_child(av)
	lvl_lab = UiKit.lab_raw("Lv 1", 12, Color(0.25, 0.15, 0.05))
	lvl_lab.add_theme_font_override("font", UiKit.bold_font())
	lvl_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color(1.0, 0.85, 0.45)
	lsb.set_corner_radius_all(9)
	lsb.set_border_width_all(2)
	lsb.border_color = Color(0.55, 0.38, 0.15)
	lsb.content_margin_left = 8
	lsb.content_margin_right = 8
	lsb.content_margin_top = 0
	lsb.content_margin_bottom = 0
	lvl_lab.add_theme_stylebox_override("normal", lsb)
	lvl_lab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(lvl_lab)
	# cột phải: tên (đậm) + job (nhỏ, xám) rồi các thanh có nhãn HP / MP / ST ở đầu thanh
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	top.add_child(col)
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 6)
	col.add_child(nr)
	name_lab = UiKit.lab("—", 15, Color(1, 1, 1))   # tự đổi sang màu chữ tối
	name_lab.add_theme_font_override("font", UiKit.bold_font())
	nr.add_child(name_lab)
	job_lab = UiKit.lab("", 11, Color(0.65, 0.7, 0.82))
	job_lab.size_flags_vertical = Control.SIZE_SHRINK_END
	nr.add_child(job_lab)
	hp = UiKit.bar(Color(0.8, 0.12, 0.12), 18.0, "hp")
	col.add_child(hp)
	_bar_tag(hp, "HP")
	hp_text = UiKit.bar_overlay(hp)
	mp = UiKit.bar(Color(0.15, 0.3, 0.85), 18.0, "mana")
	col.add_child(mp)
	_bar_tag(mp, "MP")
	mp_text = UiKit.bar_overlay(mp)
	st = UiKit.bar(ST_GREEN, 18.0, "stamina")  # màu đổi theo ngưỡng trong set_stamina()
	st.max_value = STAMINA_MAX
	st.tooltip_text = "Stamina (tối đa 42:00)"
	col.add_child(st)
	_bar_tag(st, "ST")
	st_text = UiKit.bar_overlay(st)
	st_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 3 icon chế độ chiến đấu (thay 3 nút chữ Attack/Balance/Defense; cùng logic: gửi op `fight`)
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", 4)
	v.add_child(fr)
	for m in FIGHT_MODES:
		var b := IconBtn.new()
		b.toggle_mode = true
		b.track_lit = true
		b.setup("fight_" + str(m[0]), str(m[1]), str(m[2]), Vector2(32, 32), m[3])
		b.pressed.connect(_on_fight.bind(str(m[0])))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fr.add_child(b)
		fight_btns[str(m[0])] = b
	# nút Đuổi theo (bật/tắt kiểu sáng/xám như 3 nút trên; mặc định BẬT, khớp server)
	chase_btn = IconBtn.new()
	chase_btn.toggle_mode = true
	chase_btn.track_lit = true
	chase_btn.setup("btn_chase", "Đ", "Đuổi theo target: BẬT = đuổi + đánh · TẮT = đứng im, chỉ đánh khi trong tầm (F)", Vector2(32, 32), Color(0.85, 0.55, 0.25))
	chase_btn.set_pressed_no_signal(true)
	chase_btn._apply_tex_tint()   # có PNG icon: áp độ sáng ban đầu (bật = sáng)
	chase_btn.toggled.connect(func(on: bool): chase_toggled.emit(on))
	chase_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fr.add_child(chase_btn)
	# icon Premium: đẩy sang phải bằng 1 spacer giãn; không bấm được (bấm xong tự trả về trạng thái server)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fr.add_child(spacer)
	prem_btn = IconBtn.new()
	prem_btn.toggle_mode = true
	prem_btn.track_lit = true
	prem_btn.setup("status_premium", "Pre", "Premium: không", Vector2(32, 32), Color(0.95, 0.75, 0.2))
	prem_btn.pressed.connect(func(): prem_btn.button_pressed = _prem)
	prem_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fr.add_child(prem_btn)
	set_fight("attack")
	set_premium(_prem)

func _on_fight(mode: String) -> void:
	set_fight(mode)
	fight_selected.emit(mode)

## Server báo trạng thái "đuổi theo" (hello + gói chase): chỉ cập nhật nút, không phát lại tín hiệu.
func set_chase(on: bool) -> void:
	chase_btn.set_pressed_no_signal(on)
	chase_btn._apply_tex_tint()   # icon PNG: set_pressed_no_signal không phát toggled nên tự cập nhật độ sáng

func set_fight(mode: String) -> void:
	for k in fight_btns:
		fight_btns[k].button_pressed = (k == mode)

func set_premium(on: bool) -> void:
	_prem = on
	if prem_btn != null:
		prem_btn.button_pressed = on
		prem_btn.tooltip_text = "Premium: có" if on else "Premium: không"

func set_identity(nm: String, level: int, voc_name: String) -> void:
	name_lab.text = nm
	job_lab.text = voc_name
	if portrait != null:
		portrait.icon_tex = UiAssets.class_tex(voc_name, "icon")   # icon nghề nếu có (assets/icons/classes/)
		portrait.queue_redraw()
	lvl_lab.text = "Lv %d" % level

## Nhãn nhỏ đậm (HP / MP / ST) nằm sát mép trái trong thanh.
func _bar_tag(b: ProgressBar, t: String) -> void:
	var l := UiKit.lab_raw(t, 11, Color.WHITE)
	l.add_theme_font_override("font", UiKit.bold_font())
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	l.offset_left = 10

func set_hp(v: int, mx: int) -> void:
	hp.max_value = maxi(1, mx)
	hp.value = v
	hp_text.text = "%d/%d" % [v, maxi(1, mx)]

func set_mana(v: int, mx: int) -> void:
	mp.max_value = maxi(1, mx)
	mp.value = v
	mp_text.text = "%d/%d" % [v, maxi(1, mx)]

func set_stamina(minutes: int) -> void:
	minutes = clampi(minutes, 0, STAMINA_MAX)
	st.max_value = STAMINA_MAX
	st.value = minutes
	var h := floori(minutes / 60.0)
	st_text.text = "%d:%02d" % [h, minutes % 60]
	var col := ST_GREEN if minutes > 2340 else (ST_ORANGE if minutes > 840 else ST_RED)
	UiSkin.tint_bar_fill(st, col)   # [SKIN] hỗ trợ cả style phẳng lẫn ảnh (ảnh: tô màu lên stamina_fill.png)
	st.tooltip_text = "Stamina %d:%02d / 42:00\nXanh (>39:00): exp x1.5 (Premium) · Cam: x1.0 · Đỏ (<=14:00): x0.5" % [h, minutes % 60]