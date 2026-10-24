class_name TibiaUI
extends Control
## Layout: map phải-trên, bar giữa-trên = máu QUÁI target, khối HP/Mana/Stamina + Attack/Balance/Defense
## trên cùng bên trái (VitalsBlock) rồi tới panel Trạng thái / Skills, hàng ô hotbar F1..F12 giữa-dưới (Hotbar),
## icon gọn 2 hàng phải-dưới (IconBtn), EXP tím đáy, chat gọn trái-dưới. Minimap có hàng [giờ | tên map] bên dưới.
## D1 (đang chia dần): VitalsBlock / Hotbar / HotSlot / IconBtn / SpellPanel / UiKit đã ở file riêng.

signal centre_pressed
signal fight_pressed(mode: String)
signal auto_toggled(on: bool)
signal chase_toggled(on: bool)   # nút "Đuổi theo" (bật = đuổi target đã chọn, tắt = đứng im, chỉ đánh khi trong tầm)
signal auto_cfg_changed(cfg: Dictionary)   # panel Auto đổi cấu hình -> Main gửi op auto_cfg
signal logout_pressed
signal vip_pressed
signal learn_pressed(spell_id: String)
signal cast_pressed(spell_id: String)
signal use_pressed(item_id: int)
signal unequip_pressed(slot: String)
signal target_selected(cid: String)
signal chat_sent(text: String)
signal party_action(op: String, args: Dictionary)   # Panel Party -> Main gửi op party_* (kèm args)

# Tên item do server gửi (gói có field "names": {id: tên}); ITEM_NAMES dưới đây chỉ là dự phòng offline.
static var server_names := {}
var has_premium := false:  # server gửi trong hello / spells (config.FREE_PREMIUM)
	set(v):
		has_premium = v
		if vitals != null:
			vitals.set_premium(v)  # icon Pre cạnh Attack/Balance/Defense
		if spell_panel != null:
			spell_panel.set_premium(v)
		if auto_panel != null:
			auto_panel.set_premium(v)

static func merge_names(names: Dictionary) -> void:
	for k in names:
		server_names[int(k)] = str(names[k])

static func name_of(iid: int) -> String:
	if server_names.has(iid):
		return server_names[iid]
	return str(ITEM_NAMES.get(iid, "item #%d" % iid))

const ITEM_NAMES := {
	3031: "gold coin", 3035: "platinum coin", 3030: "small ruby",
	3032: "small emerald", 3033: "small amethyst", 9057: "small topaz",
	3039: "red gem", 6499: "demonic essence", 3034: "talon",
	238: "great mana potion", 7643: "ultimate health potion", 7642: "great spirit potion",
	2848: "purple tome", 5954: "demon horn", 3731: "fire mushroom",
	7368: "assassin star", 3048: "might ring", 3049: "stealth ring",
	3425: "dwarven shield", 7773: "steel axe", 3359: "brass armor", 3354: "brass helmet",
	3372: "brass legs", 7774: "jagged sword", 3327: "daramian mace", 3003: "rope",
	5710: "light shovel", 266: "health potion", 268: "mana potion",
	3277: "spear", 3571: "ranger's cloak", 8095: "ranger legs",
	3350: "bow", 3447: "arrow", 3059: "spellbook",
	3074: "wand of vortex", 3066: "snakebite rod",
	7991: "magician's robe", 7992: "mage hat", 3362: "studded legs",
	3264: "sword", 3286: "mace", 3577: "meat", 3582: "ham", 3492: "worm",
	9692: "lump of dirt", 3374: "legion helmet", 3607: "cheese",
	3412: "wooden shield", 3361: "leather armor", 3355: "leather helmet",
	3559: "leather legs", 3552: "leather boots",
}
const INV_SLOTS := ["Head", "Neck", "Pack", "Armor", "L-Hand",
	"R-Hand", "Legs", "Boots", "Ring", "Ammo"]
const CATS := [["all", "Tất cả"], ["equip", "Equipment"], ["food", "Food"],
	["valuables", "Valuables"], ["others", "Others"]]
const SKILL_NAMES := {"m": "Magic", "0": "Fist", "1": "Club", "2": "Sword",
	"3": "Axe", "4": "Dist", "5": "Shield", "6": "Fish"}
const CHAT_FONT := 12    # cỡ chữ khung Chat (log + ô nhập); chỉnh ở đây
const BATTLE_FONT := 14  # cỡ chữ tên quái trong Battle
const VOC_NAMES := {1: "Sorcerer", 2: "Druid", 3: "Paladin", 4: "Knight", 9: "Monk"}

var minimap: Minimap
var tgt_name: Label
var tgt_hp: ProgressBar
var tgt_hp_text: Label
signal map_pressed   # ô M trong ActionDock: Main mở/đóng bản đồ thế giới
var map_lab: Label    # tên map (hàng dưới minimap, bên phải)
var clock_text: Label # tọa độ nhân vật (hàng dưới minimap, bên trái)
var vitals: VitalsBlock  # chân dung + HP/Mana/Stamina + icon Attack/Balance/Defense (trên cùng bên trái)
var hotbar: Hotbar       # hàng ô F1..F12 giữa-dưới
var auto_btn: DockCell   # nút tròn AUTO trong ActionDock
var dock: ActionDock     # Panel icon góc phải-dưới
var chase_btn: IconBtn
var skill_labs := {}
var skill_bars := {}
var battle_rows: VBoxContainer
var battle_pager: Pager       # Battle theo trang (5 quái/trang), thay cho thanh cuộn
var _battle_cache: Array = []
var _battle_target := ""
const BATTLE_PER_PAGE := 4   # 4 quái/bảng
const BATTLE_ROW_H := 26    # chiều cao mỗi dòng quái
const BATTLE_MAX := 20       # chỉ lấy 20 quái gần nhất = 5 bảng
var vip_pager: Pager
var _vip_cache: Array = []
const VIP_PER_PAGE := 8
var battle_panel: PanelContainer
var skills_panel: PanelContainer
var vip_panel: PanelContainer
var vip_rows: VBoxContainer
var status_panel: PanelContainer
var party_panel: PartyPanel     # Panel Party (cột trái, vị trí cũ của Trạng thái); Trạng thái nay nằm cột phải trên Battle
var status_box: VBoxContainer
var status_exp_bar: ProgressBar  # thanh % EXP ngay dưới dòng "EXP" trong card Trạng thái
var status_exp_pct: Label
var food_icon: StatusIcon
var bar_cfg_pop: PanelContainer
var _bar_on := {"m": true, "5": true, "0": false, "1": false, "2": false, "3": false, "4": false}
var _last_run := []
var status_exp_lv: Label
var run_box: VBoxContainer
var _run_rows := {}
var cap_icon: StatusIcon
var _level := 0
var _exp_pct := 0.0
var _cap_known := false
var cond_box: HFlowContainer  # chip condition (haste/poison...) trong panel Trạng thái
var spell_panel: SpellPanel
var auto_panel: AutoPanel
var char_panel: CharPanel   # Character + Túi đồ + Chi tiết vật phẩm (CharPanel.gd)
var pack_items := {}
var status_tab_btn: Button
var bag_tab_btn: Button
var bag_page: Control
var status_page: Control
var chat_log: RichTextLabel
var chat_input: LineEdit
var channel := "local"
var lines: Array = []
var chan_btns := {}

func _panel() -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.panel_style())   # [SKIN] nền panel chung (ảnh nếu có, không thì style tạm cũ)
	UiKit.block_world(p)   # chuột trên panel không lọt xuống bản đồ
	return p

func _bar(fill: Color, h := 14.0, skin := "") -> ProgressBar:
	return UiKit.bar(fill, h, skin)   # [SKIN] skin = "exp" | "target" (assets/ui/bars/)

func _lab(t: String, sz := 12, col := Color(0.9, 0.9, 0.9)) -> Label:
	var l = Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", UiTheme.fs(sz))
	l.add_theme_color_override("font_color", UiTheme.ink(col))   # nền sáng: màu sáng tự đổi sang màu tối tương ứng
	return l

func build():
	mouse_filter = MOUSE_FILTER_IGNORE
	var left = VBoxContainer.new()
	left.anchor_left = 0.0
	left.anchor_right = 0.0
	left.offset_left = 8
	left.offset_right = 248
	left.offset_top = 8
	left.add_theme_constant_override("separation", 6)
	left.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(left)
	var right = VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -228
	right.offset_right = -8
	right.offset_top = 8
	right.add_theme_constant_override("separation", 6)
	right.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(right)
	_build_top_right(right)
	_build_top_center()
	_build_vitals(left)  # TRÊN CÙNG, trước panel Trạng thái / Skills
	_build_top_left_status(right)   # Trạng thái: cột phải, ngay dưới minimap và trên Battle
	_build_party_panel(left)        # Party: cột trái, ngay dưới HP/Mana (vị trí cũ của Trạng thái)
	_build_hotbar()
	_build_bottom_right_icons()
	_build_chat()
	_build_side_popups(left, right)
	_build_spell_panel()
	_build_auto_panel()
	_build_char_panel()

# ---------- phải-trên: minimap + (giờ | tên map) ----------

func _build_top_right(col: VBoxContainer):
	var mp = _panel()
	col.add_child(mp)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	mp.add_child(v)
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(0, 120)
	v.add_child(minimap)
	var h = HBoxContainer.new()
	v.add_child(h)
	clock_text = _lab("X:- Y:-", 12, Color(0.7, 0.8, 0.9))  # tọa độ nhân vật (thay giờ)
	h.add_child(clock_text)
	map_lab = _lab("", 12, Color(0.8, 0.9, 1.0))  # tên map: thay chỗ nút "Centre"
	map_lab.size_flags_horizontal = SIZE_EXPAND_FILL
	map_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	map_lab.clip_text = true
	h.add_child(map_lab)

# ---------- giữa-trên: tên + máu QUÁI target ----------

func _build_top_center():
	var tc = VBoxContainer.new()
	tc.anchor_left = 0.5
	tc.anchor_right = 0.5
	tc.offset_left = -180
	tc.offset_right = 180
	tc.offset_top = 8
	tc.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(tc)
	tgt_name = _lab("—", 14, Color(1, 0.6, 0.4))
	tgt_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tgt_name.mouse_filter = MOUSE_FILTER_IGNORE
	tc.add_child(tgt_name)
	var hh = HBoxContainer.new()
	hh.mouse_filter = MOUSE_FILTER_IGNORE
	tc.add_child(hh)
	tgt_hp = _bar(Color(0.8, 0.12, 0.12), 18.0, "target")
	tgt_hp.size_flags_horizontal = SIZE_EXPAND_FILL
	tgt_hp.mouse_filter = MOUSE_FILTER_IGNORE
	hh.add_child(tgt_hp)
	tgt_hp_text = _lab("", 12)
	tgt_hp_text.mouse_filter = MOUSE_FILTER_IGNORE
	hh.add_child(tgt_hp_text)

# ---------- Panel Party (cột trái) ----------

func _build_party_panel(left: VBoxContainer):
	party_panel = PartyPanel.new()
	left.add_child(party_panel)
	party_panel.build()
	party_panel.action.connect(func(op: String, args: Dictionary): party_action.emit(op, args))

## Gói `party` từ server. Lần đầu vào party thì tự mở panel; rời hết thì giữ nguyên trạng thái mở/đóng.
func set_party(msg: Dictionary):
	var was: bool = party_panel.in_party()
	party_panel.set_state(msg)
	if party_panel.in_party() and not was:
		party_panel.show_panel()

# ---------- Status panel (cột phải, trên Battle) ----------

func _build_top_left_status(col: VBoxContainer):
	status_panel = _panel()
	col.add_child(status_panel)
	var v = VBoxContainer.new()
	status_panel.add_child(v)
	var st_head := HBoxContainer.new()
	v.add_child(st_head)
	UiKit.head_sep(st_head)
	var st_h := UiKit.title("Trạng thái")
	st_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st_h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st_head.add_child(st_h)
	var cfg_btn := Button.new()
	cfg_btn.custom_minimum_size = Vector2(24, 24)
	cfg_btn.tooltip_text = "Chọn thanh skill hiển thị"
	cfg_btn.flat = true
	cfg_btn.focus_mode = Control.FOCUS_NONE
	cfg_btn.draw.connect(func(): DockIcons.draw(cfg_btn, "autocfg", cfg_btn.size / 2.0, minf(cfg_btn.size.x, cfg_btn.size.y) * 0.42))
	cfg_btn.pressed.connect(_toggle_bar_cfg)
	st_head.add_child(cfg_btn)
	_load_bar_cfg()
	status_box = VBoxContainer.new()   # không còn dòng chữ (Cấp độ / No / Cap): giữ node rỗng cho tương thích
	status_box.visible = false
	v.add_child(status_box)
	status_exp_bar = _bar(Color(0.55, 0.25, 0.85), 18.0, "exp")
	status_exp_bar.max_value = 100
	v.add_child(status_exp_bar)
	status_exp_pct = UiKit.bar_overlay(status_exp_bar, 11)   # % ở giữa
	status_exp_pct.text = "0.0%"
	status_exp_lv = _bar_left_label(status_exp_bar, "Lvl 0")   # chữ căn trái
	# các skill đang tăng (% > 0) hiện dưới thanh LVL, cùng kiểu
	run_box = VBoxContainer.new()
	run_box.add_theme_constant_override("separation", 2)
	v.add_child(run_box)
	# hàng icon: No (food) + Cap, rồi tới chip condition (nhiễm độc, haste...)
	cond_box = HFlowContainer.new()
	cond_box.mouse_filter = MOUSE_FILTER_IGNORE
	cond_box.add_theme_constant_override("h_separation", 4)
	cond_box.add_theme_constant_override("v_separation", 4)
	v.add_child(cond_box)
	food_icon = StatusIcon.new()
	food_icon.setup("status_food_icon", "No", Color(0.9, 0.6, 0.25))
	cond_box.add_child(food_icon)
	cap_icon = StatusIcon.new()
	cap_icon.setup("status_cap_icon", "Cap", Color(0.45, 0.6, 0.85))
	cond_box.add_child(cap_icon)
	food_icon.set_state(true, "Đang no")
	cap_icon.set_state(true, "Sức chứa")

# ---------- trên cùng bên trái: HP / Mana / Stamina + Attack/Balance/Defense ----------

func _build_vitals(left: VBoxContainer):
	vitals = VitalsBlock.new()
	vitals.build()
	vitals.fight_selected.connect(_on_fight_btn)
	chase_btn = vitals.chase_btn   # nút Đ nằm cạnh Attack/Balance/Defense (Main dùng ui.chase_btn cho phím F)
	vitals.chase_toggled.connect(func(on: bool): chase_toggled.emit(on))
	vitals.set_premium(has_premium)
	left.add_child(vitals)

# ---------- giữa-dưới: hàng ô chọn nhanh (item / pot / rune / spell) ----------

const CHAT_RIGHT := 380.0   # mép phải Chat Panel (xem _build_chat)


## Căn hotbar vào chính giữa khoảng trống giữa Chat Panel (trái) và ActionDock (phải); kẹp để không chồng lên hai bên.
func _place_hotbar() -> void:
	if hotbar == null or dock == null:
		return
	var w := float(Hotbar.total_width())
	var right_edge := dock.global_position.x if dock.size.x > 0.0 else size.x
	var x := (CHAT_RIGHT + right_edge) * 0.5 - w * 0.5
	x = clampf(x, CHAT_RIGHT + 6.0, maxf(CHAT_RIGHT + 6.0, right_edge - w - 6.0))
	if absf(hotbar.offset_left - x) > 0.5:
		hotbar.offset_left = x
		hotbar.offset_right = x + w


func _build_hotbar():
	hotbar = Hotbar.new()
	hotbar.name_fn = func(iid: int) -> String: return name_of(iid)
	hotbar.anchor_left = 0.0   # vị trí X đặt trong _process: căn giữa khoảng giữa Chat Panel và khối icon phải-dưới
	hotbar.anchor_right = 0.0
	hotbar.anchor_top = 1.0
	hotbar.anchor_bottom = 1.0
	hotbar.offset_left = 400
	hotbar.offset_right = 400 + Hotbar.total_width()
	hotbar.offset_top = -(Hotbar.total_height() + 8)
	hotbar.offset_bottom = -8
	add_child(hotbar)
	hotbar.build()
	hotbar.use_item.connect(func(iid: int): use_pressed.emit(iid))
	hotbar.cast_spell.connect(func(sid: String): cast_pressed.emit(sid))

# ---------- phải-dưới: Panel icon (ActionDock: header AUTO/Discord/Gold + lưới 5x3 có phím tắt) ----------

func _build_bottom_right_icons():
	dock = ActionDock.new()
	add_child(dock)
	dock.build()
	auto_btn = dock.auto_btn
	auto_btn.toggled.connect(_on_auto_btn)   # logic AUTO của user: giữ nguyên (toggled -> _on_auto_btn)
	dock.action.connect(_on_fun)

## Viền vàng cho ô đang mở (panel đang hiện / đuổi theo đang bật).
func _process(_dt: float) -> void:
	if dock == null or char_panel == null or auto_panel == null:
		return
	_place_hotbar()
	dock.set_lit("char", char_panel.visible)
	dock.set_lit("skills", skills_panel.visible)
	dock.set_lit("battle", battle_panel.visible)
	dock.set_lit("status", status_panel.visible)
	dock.set_lit("vip", vip_panel.visible)
	dock.set_lit("party", party_panel.visible)
	dock.set_lit("spell", spell_panel.visible)
	dock.set_lit("autocfg", auto_panel.visible)

## Server xác nhận / báo trạng thái "đuổi theo" (hello + gói chase): chỉ cập nhật nút, không phát lại tín hiệu.
func set_chase(on: bool):
	vitals.set_chase(on)

func _on_fun(which: String):
	match which:
		"char", "bag": toggle_char()   # túi đồ nằm chung panel Character
		"map": map_pressed.emit()
		"chase": vitals.chase_btn.button_pressed = not vitals.chase_btn.button_pressed
		"skills": toggle_popup("skills")
		"battle": toggle_popup("battle")
		"vip": toggle_popup("vip")
		"status": toggle_popup("status")
		"party": party_panel.toggle()
		"spell": toggle_spell()
		"autocfg": toggle_auto_panel()
		"logout": logout_pressed.emit()

func toggle_spell():
	spell_panel.visible = not spell_panel.visible

func toggle_popup(which: String):
	match which:
		"skills": skills_panel.visible = not skills_panel.visible
		"battle": battle_panel.visible = not battle_panel.visible
		"status": status_panel.visible = not status_panel.visible
		"vip":
			vip_panel.visible = not vip_panel.visible
			if vip_panel.visible:
				vip_pressed.emit()

# ---------- chat gọn góc trái-dưới ----------

func _build_chat():
	var bot = _panel()
	bot.anchor_top = 1.0
	bot.anchor_bottom = 1.0
	bot.offset_left = 8
	bot.offset_right = 380
	bot.offset_top = -168
	bot.offset_bottom = -8
	add_child(bot)
	var v = VBoxContainer.new()
	bot.add_child(v)
	var tabs = HBoxContainer.new()
	v.add_child(tabs)
	UiKit.head_sep(tabs)
	for t in [["local", "Chat"], ["server", "Log"], ["npcs", "NPCs"]]:
		var b = Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.button_pressed = (t[0] == "local")
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", UiKit.bold_font())  # title tab: đậm, cỡ 12 như dòng Speed
		b.add_theme_font_size_override("font_size", 14)
		chan_btns[t[0]] = b
		b.pressed.connect(_set_channel.bind(t[0]))
		tabs.add_child(b)
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.scroll_following = true
	for fs in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		chat_log.add_theme_font_size_override(fs, CHAT_FONT)  # chữ khung chat nhỏ lại
	chat_log.size_flags_vertical = SIZE_EXPAND_FILL
	v.add_child(chat_log)
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Enter: chat"
	chat_input.add_theme_font_size_override("font_size", CHAT_FONT)
	chat_input.text_submitted.connect(_on_chat_submit)
	v.add_child(chat_input)

func _on_chat_submit(t: String):
	chat_sent.emit(t)
	chat_input.clear()

func _set_channel(c: String):
	channel = c
	for k in chan_btns:
		chan_btns[k].button_pressed = (k == c)
	refresh_chat()

# ---------- popup phải: battle / skills / vip ----------

func _build_side_popups(left: VBoxContainer, right: VBoxContainer):
	battle_panel = _panel()
	right.add_child(battle_panel)
	var bv = VBoxContainer.new()
	battle_panel.add_child(bv)
	var bt_h := UiKit.title("Battle (click = target+đánh)", 12)
	bv.add_child(bt_h)
	UiKit.head_sep(bt_h)
	var battle_area = VBoxContainer.new()   # không cuộn: danh sách chia trang, cuộn chuột trên vùng này = đổi trang
	battle_area.custom_minimum_size = Vector2(0, BATTLE_PER_PAGE * (BATTLE_ROW_H + 3))   # vừa đủ 4 dòng, không thừa trắng
	battle_area.clip_contents = true
	bv.add_child(battle_area)
	battle_rows = VBoxContainer.new()
	battle_rows.size_flags_horizontal = SIZE_EXPAND_FILL
	battle_area.add_child(battle_rows)
	battle_pager = Pager.new()
	battle_pager.page_changed.connect(func(_p): refresh_battle(_battle_cache, _battle_target))
	bv.add_child(battle_pager)
	battle_pager.attach_wheel(battle_area)

	skills_panel = _panel()
	left.add_child(skills_panel)
	skills_panel.visible = false
	var sv = VBoxContainer.new()
	skills_panel.add_child(sv)
	var sk_h := UiKit.title("Skills")
	sv.add_child(sk_h)
	UiKit.head_sep(sk_h)
	for k in SKILL_NAMES:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		sv.add_child(row)
		var l = _lab(SKILL_NAMES[k], 11)
		l.custom_minimum_size = Vector2(48, 0)
		row.add_child(l)
		var bar = _bar(UiTheme.accent(), 5.0)  # thấp còn 1/2 (10 -> 5)
		bar.max_value = 100
		bar.size_flags_horizontal = SIZE_EXPAND_FILL
		bar.size_flags_vertical = SIZE_SHRINK_CENTER  # không bị kéo cao theo hàng chữ
		row.add_child(bar)
		var lv2 = _lab("0" if k == "m" else "10", 11)
		lv2.custom_minimum_size = Vector2(24, 0)
		row.add_child(lv2)
		skill_labs[k] = [l, lv2]
		skill_bars[k] = bar

	vip_panel = _panel()
	right.add_child(vip_panel)
	vip_panel.visible = false
	var vv = VBoxContainer.new()
	vip_panel.add_child(vv)
	vv.add_child(_lab("Online", 12))
	vip_rows = VBoxContainer.new()
	vv.add_child(vip_rows)
	vip_pager = Pager.new()
	vip_pager.page_changed.connect(func(_p): refresh_vip(_vip_cache))
	vv.add_child(vip_pager)
	vip_pager.attach_wheel(vip_rows)

# ---------- Character panel 2 cột (bỏ tab Trạng thái, ra panel riêng) ----------

func _build_spell_panel():
	spell_panel = SpellPanel.new()
	spell_panel.anchor_left = 0.5
	spell_panel.anchor_right = 0.5
	spell_panel.anchor_top = 0.5
	spell_panel.anchor_bottom = 0.5
	spell_panel.offset_left = -390
	spell_panel.offset_right = 390
	spell_panel.offset_top = -285
	spell_panel.offset_bottom = 285
	spell_panel.visible = false
	add_child(spell_panel)
	spell_panel.build()
	spell_panel.has_premium = has_premium
	spell_panel.learn_pressed.connect(func(sid: String): learn_pressed.emit(sid))
	spell_panel.cast_pressed.connect(func(sid: String): cast_pressed.emit(sid))

func _build_auto_panel():
	auto_panel = AutoPanel.new()
	auto_panel.anchor_left = 0.5   # giữa màn hình
	auto_panel.anchor_right = 0.5
	auto_panel.anchor_top = 0.5
	auto_panel.anchor_bottom = 0.5
	auto_panel.offset_left = -AutoPanel.FULL_W / 2.0
	auto_panel.offset_right = AutoPanel.FULL_W / 2.0
	auto_panel.offset_top = -AutoPanel.FULL_H / 2.0
	auto_panel.offset_bottom = AutoPanel.FULL_H / 2.0
	auto_panel.visible = false
	add_child(auto_panel)
	auto_panel.build()
	auto_panel.cfg_changed.connect(func(c: Dictionary): auto_cfg_changed.emit(c))
	auto_panel.toggled.connect(func(on: bool): auto_toggled.emit(on))

func toggle_auto_panel():
	auto_panel.visible = not auto_panel.visible

## hello.auto: nạp potion + cấu hình đã lưu vào panel.
func set_auto_info(info: Dictionary):
	auto_panel.set_info(info)

## auto_state từ server: đồng bộ nút AU và panel (không phát lại tín hiệu bật/tắt).
func apply_auto_state(msg: Dictionary):
	var on := bool(msg.get("on", false))
	auto_btn.set_pressed_no_signal(on)   # DockCell tự vẽ xanh khi bật
	auto_panel.apply_state(msg)

func refresh_spells(spells: Array, voc := 4):
	spell_panel.set_data(spells, voc)
	auto_panel.set_spells(spells, voc)
	hotbar.set_spells(spells, voc)

func _build_char_panel():
	char_panel = CharPanel.new()
	add_child(char_panel)
	char_panel.build()
	char_panel.unequip.connect(_on_inv_click)
	char_panel.use_item.connect(_on_pack_click)
	char_panel.closed.connect(toggle_char)

func toggle_char():
	char_panel.visible = not char_panel.visible

func _on_auto_btn(on: bool):
	auto_toggled.emit(on)

func _on_fight_btn(mode: String):
	fight_pressed.emit(mode)  # VitalsBlock đã tự bật icon tương ứng

func set_fight(mode: String):
	vitals.set_fight(mode)

func _on_inv_click(slot: String):
	unequip_pressed.emit(slot)

func _on_pack_click(iid: int):
	use_pressed.emit(iid)

# ---------- API cho Main.gd ----------

func set_target_bar(name: String, hp: int, mx: int):
	if name == "":
		tgt_name.text = "—"
		tgt_hp.value = 0
		tgt_hp_text.text = ""
	else:
		tgt_name.text = name
		tgt_hp.max_value = maxi(1, mx)
		tgt_hp.value = hp
		tgt_hp_text.text = "%d/%d" % [hp, maxi(1, mx)]

func set_hp(hp: int, mx: int):
	vitals.set_hp(hp, mx)

func set_mana(mp: int, mx: int):
	vitals.set_mana(mp, mx)

func set_stamina(minutes: int):
	vitals.set_stamina(minutes)

# tên + level + vocation cho khối trên-trái; đồng thời chọn bộ hotbar theo tên nhân vật
func set_identity(nm: String, level: int, voc_name: String):
	vitals.set_identity(nm, level, voc_name)
	if char_panel != null:
		char_panel.set_identity(nm, level, voc_name)
	hotbar.set_character_owner(nm)

## Gold trong túi + số dư Bank (server gửi trong gói stats).
func set_money(gold: int, bank: int):
	if char_panel != null:
		char_panel.set_money(gold, bank)
	if dock != null:
		dock.set_gold(gold)

func _oz(v: float) -> String:
	return "%d" % roundi(v) if absf(v - roundf(v)) < 0.005 else "%.1f" % v

func set_soul_cap(soul: int, max_soul: int, free_cap: float, max_cap: float):
	_free_cap = free_cap
	_max_cap = max_cap
	_cap_known = true
	_update_cap_icon()
	if char_panel != null:
		char_panel.set_soul_cap(soul, max_soul, free_cap, max_cap)

func set_exp(exp: int, level: int, percent: float):
	status_exp_bar.max_value = 100
	status_exp_bar.value = percent
	_level = level
	_exp_pct = percent
	_refresh_exp_text()
	spell_panel.set_level(level)
	if auto_panel != null:
		auto_panel.set_level(level)

func _bar_left_label(b: ProgressBar, t: String, sz := 11) -> Label:
	var l := UiKit.lab_raw(t, sz, Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.offset_left = 6
	return l

## Thanh skill đang chạy: tên + level (trái), % (giữa). Chỉ hiện skill có % > 0.
func _update_running(items: Array) -> void:
	# items: [[key, "Magic 12", pct], ...]
	var keep := {}
	for it in items:
		var k: String = it[0]
		keep[k] = true
		if not _run_rows.has(k):
			var b := _bar(Color(0.55, 0.25, 0.85), 16.0, "exp")
			b.max_value = 100
			var pc := UiKit.bar_overlay(b, 11)
			var lf := _bar_left_label(b, "")
			run_box.add_child(b)
			_run_rows[k] = [b, lf, pc]
		var r = _run_rows[k]
		r[0].value = it[2]
		r[1].text = it[1]
		r[2].text = "%.1f%%" % it[2]
	for k in _run_rows.keys():
		if not keep.has(k):
			var b = _run_rows[k][0]
			run_box.remove_child(b)
			b.queue_free()
			_run_rows.erase(k)
	# giữ thứ tự theo items
	for i in items.size():
		run_box.move_child(_run_rows[items[i][0]][0], i)

func _refresh_exp_text() -> void:
	status_exp_lv.text = "Lvl %d" % _level
	status_exp_pct.text = "%.1f%%" % _exp_pct

func set_coord(p: Vector2i):
	var t := "X:%d Y:%d" % [p.x, p.y]
	if clock_text.text != t:
		clock_text.text = t

func set_map_name(n: String):
	map_lab.text = n
	map_lab.tooltip_text = n

# loại condition server gửi (gói `conditions`) -> [chữ ngắn, màu]; loại lạ hiện chữ 3 ký tự đầu, màu xám
const COND_CHIP := {
	"haste": ["HST", Color(0.2, 0.75, 0.3)], "paralyze": ["PAR", Color(0.75, 0.2, 0.2)],
	"manashield": ["MS", Color(0.25, 0.45, 0.9)], "regeneration": ["REG", Color(0.3, 0.8, 0.6)],
	"invisible": ["INV", Color(0.5, 0.5, 0.6)], "light": ["LGT", Color(0.9, 0.85, 0.3)],
	"attributes": ["BUF", Color(0.7, 0.5, 0.9)], "pacified": ["PAC", Color(0.8, 0.8, 0.8)],
	"fire": ["FIR", Color(0.95, 0.4, 0.1)], "energy": ["ENG", Color(0.6, 0.4, 0.95)],
	"poison": ["PSN", Color(0.3, 0.7, 0.2)], "bleeding": ["BLD", Color(0.8, 0.1, 0.15)],
	"cursed": ["CRS", Color(0.4, 0.3, 0.4)], "dazzled": ["DZL", Color(0.95, 0.9, 0.6)],
	"freezing": ["FRZ", Color(0.4, 0.8, 0.95)], "drown": ["DRN", Color(0.2, 0.4, 0.8)],
	"feared": ["FEA", Color(0.6, 0.35, 0.6)], "drunk": ["DRK", Color(0.75, 0.6, 0.3)],
	"outfit": ["OUT", Color(0.55, 0.55, 0.55)], "infight": ["FGT", Color(0.7, 0.3, 0.3)],
}

func set_conditions(list: Array):
	for c in cond_box.get_children():
		if c is StatusIcon:
			continue   # No / Cap luôn nằm đầu hàng
		cond_box.remove_child(c)
		c.queue_free()
	for it in list:
		var t := str(it.get("t", "?"))
		var info: Array = COND_CHIP.get(t, [t.left(3).to_upper(), Color(0.5, 0.5, 0.5)])
		var chip = UiKit.lab_raw(str(info[0]), 12, Color.WHITE)   # chữ trắng trên chip màu
		var sb = StyleBoxFlat.new()
		sb.bg_color = info[1]
		sb.set_content_margin_all(2)
		chip.add_theme_stylebox_override("normal", sb)
		var left_ms := int(it.get("left", -1))
		chip.tooltip_text = t if left_ms < 0 else "%s · còn %d giây" % [t, ceili(left_ms / 1000.0)]
		chip.mouse_filter = MOUSE_FILTER_PASS
		cond_box.add_child(chip)

var _status_lines: Array = []
var _free_cap := -1.0
var _max_cap := 0.0

func set_status(lines: Array):
	_status_lines = lines
	for ln in lines:
		var t := str(ln)
		if t.begins_with("Cấp độ"):
			_level = int(t.get_slice(":", 1).strip_edges())
			_refresh_exp_text()
		elif t.begins_with("No"):
			# "No: m:ss (food)" -> số giây còn no; 0 = đói
			var rest := t.get_slice(":", 1).strip_edges()
			var mm := int(rest.get_slice(":", 0))
			var ss := int(rest.get_slice(":", 1).get_slice(" ", 0))
			_set_food(mm * 60 + ss)

func _set_food(secs: int) -> void:
	if secs > 0:
		food_icon.set_state(true, "No: còn %d:%02d\nĂn thêm food để giữ hồi phục HP/mana." % [secs / 60, secs % 60])
	else:
		food_icon.set_state(false, "Đói: hết no.\nĂn food để hồi phục HP/mana tự nhiên.")

func _update_cap_icon() -> void:
	if not _cap_known:
		return
	if _free_cap > 0.0:
		cap_icon.set_state(true, "Sức chứa còn: %s oz / %s oz" % [_oz(_free_cap), _oz(_max_cap)])
	else:
		cap_icon.set_state(false, "Quá tải: hết sức chứa (%s oz).\nVứt bớt đồ hoặc gửi vào Hòm đồ." % _oz(_max_cap))

func set_skills(skills: Dictionary, pcts := {}, maglv := -1, magpct := 0.0):
	_skill_cache = [skills, pcts, maglv, magpct]
	_rebuild_run_bars()
	_set_skills_panel(skills, pcts, maglv, magpct)

func _rebuild_run_bars() -> void:
	if run_box == null or _skill_cache.is_empty():
		return
	var skills: Dictionary = _skill_cache[0]
	var pcts: Dictionary = _skill_cache[1]
	var run := []
	if _bar_on.get("m", false) and int(_skill_cache[2]) >= 0:
		run.append(["m", "Magic %d" % int(_skill_cache[2]), float(_skill_cache[3])])
	for k in ["5", "0", "1", "2", "3", "4"]:
		if _bar_on.get(k, false):
			run.append([k, "%s %d" % [SKILL_NAMES[k], int(skills.get(k, skills.get(int(k), 10)))],
				float(pcts.get(k, pcts.get(int(k), 0.0)))])
	_update_running(run)

const BAR_CFG := "user://status_bars.cfg"

func _load_bar_cfg() -> void:
	var c := ConfigFile.new()
	if c.load(BAR_CFG) == OK:
		for k in _bar_on.keys():
			_bar_on[k] = bool(c.get_value("bars", k, _bar_on[k]))

func _save_bar_cfg() -> void:
	var c := ConfigFile.new()
	for k in _bar_on.keys():
		c.set_value("bars", k, _bar_on[k])
	c.save(BAR_CFG)

func _toggle_bar_cfg() -> void:
	if bar_cfg_pop != null:
		bar_cfg_pop.visible = not bar_cfg_pop.visible
		if bar_cfg_pop.visible:
			_place_bar_cfg()
		return
	bar_cfg_pop = PanelContainer.new()
	var pst := CharPanel._box(UiTheme.body(), UiTheme.accent_dark(), 2, 5)
	pst.set_content_margin_all(0)
	bar_cfg_pop.add_theme_stylebox_override("panel", pst)
	bar_cfg_pop.z_index = 30
	UiKit.block_world(bar_cfg_pop)
	add_child(bar_cfg_pop)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	bar_cfg_pop.add_child(vb)
	# header xanh đồng bộ tone
	var hd := PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = UiTheme.accent()
	hsb.corner_radius_top_left = 3
	hsb.corner_radius_top_right = 3
	hsb.content_margin_left = 10
	hsb.content_margin_right = 10
	hsb.content_margin_top = 4
	hsb.content_margin_bottom = 4
	hd.add_theme_stylebox_override("panel", hsb)
	var ht := UiKit.lab_raw("Hiện thanh skill", 13, Color.WHITE)
	ht.add_theme_font_override("font", UiKit.bold_font())
	ht.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hd.add_child(ht)
	vb.add_child(hd)
	var mc := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + m, 6)
	vb.add_child(mc)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	mc.add_child(body)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.set_corner_radius_all(4)
	flat.content_margin_left = 4
	flat.content_margin_right = 6
	flat.content_margin_top = 3
	flat.content_margin_bottom = 3
	var hov := flat.duplicate() as StyleBoxFlat
	hov.bg_color = UiTheme.accent().lerp(UiTheme.body(), 0.8)
	for k in ["m", "5", "0", "1", "2", "3", "4"]:
		var cb := CheckBox.new()
		cb.text = SKILL_NAMES[k]
		cb.focus_mode = Control.FOCUS_NONE
		cb.button_pressed = bool(_bar_on[k])
		for sn in ["normal", "pressed", "focus", "hover_pressed"]:
			cb.add_theme_stylebox_override(sn, flat)
		cb.add_theme_stylebox_override("hover", hov)
		for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			cb.add_theme_color_override(cn, Color("#2a3354"))
		cb.add_theme_font_size_override("font_size", 13)
		cb.toggled.connect(func(on: bool):
			_bar_on[k] = on
			_save_bar_cfg()
			_rebuild_run_bars())
		body.add_child(cb)
	var ok := RowKit.act_btn("Đóng", true, 90, "primary", 26)
	ok.pressed.connect(func(): bar_cfg_pop.visible = false)
	body.add_child(ok)
	_place_bar_cfg()

func _place_bar_cfg() -> void:
	await get_tree().process_frame
	if bar_cfg_pop == null or status_panel == null:
		return
	var r := status_panel.get_global_rect()
	bar_cfg_pop.reset_size()
	bar_cfg_pop.global_position = Vector2(r.position.x - bar_cfg_pop.size.x - 6, r.position.y)

var _skill_cache := []

func _set_skills_panel(skills: Dictionary, pcts := {}, maglv := -1, magpct := 0.0):
	for k in SKILL_NAMES:
		if k == "m":
			if maglv < 0:
				continue
			skill_labs[k][0].text = "Magic"
			skill_labs[k][1].text = str(maglv)
			skill_bars[k].value = magpct
			continue
		var lv = int(skills.get(k, skills.get(int(k), 10)))
		skill_labs[k][0].text = SKILL_NAMES[k]
		skill_labs[k][1].text = str(lv)
		skill_bars[k].value = float(pcts.get(k, pcts.get(int(k), 0.0)))

func set_equip(equip: Dictionary, counts := {}):
	if char_panel != null:
		char_panel.set_equip(equip, counts)

func set_online(on: bool):
	dock.set_online(on)

func set_auto(on: bool):
	auto_btn.set_pressed_no_signal(on)

func refresh_battle(creatures: Array, target: String):
	creatures = creatures.slice(0, BATTLE_MAX)   # Main đã sắp gần -> xa
	_battle_cache = creatures
	_battle_target = target
	for c in battle_rows.get_children():
		c.queue_free()
	battle_pager.set_total(creatures.size(), BATTLE_PER_PAGE)
	var page_items := Pager.slice(creatures, battle_pager.page, BATTLE_PER_PAGE)
	for i in page_items.size():
		var e: Dictionary = page_items[i]
		var b := Button.new()
		b.text = "%s [%d]" % [e.get("name", e.get("id", "?")), e.get("hp", 0)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", BATTLE_FONT)
		b.custom_minimum_size = Vector2(0, BATTLE_ROW_H)
		# không viền: nền trong suốt; hover nhẹ; mục tiêu đang chọn = nền xanh nhạt
		var none := StyleBoxEmpty.new()
		none.content_margin_left = 4
		none.content_margin_right = 4
		var hov := StyleBoxFlat.new()
		hov.bg_color = UiTheme.accent_light()
		hov.bg_color.a = 0.6
		hov.set_corner_radius_all(6)
		hov.content_margin_left = 4
		var sel := hov.duplicate() as StyleBoxFlat
		sel.bg_color = UiTheme.accent_mid()
		var is_t: bool = e.get("id") == target
		for st in ["normal", "disabled"]:
			b.add_theme_stylebox_override(st, sel if is_t else none)
		b.add_theme_stylebox_override("hover", sel if is_t else hov)
		b.add_theme_stylebox_override("pressed", sel)
		b.add_theme_stylebox_override("hover_pressed", sel)
		var cid = e.get("id", "")
		b.pressed.connect(target_selected.emit.bind(cid))
		battle_rows.add_child(b)
		if i < page_items.size() - 1:
			battle_rows.add_child(DashLine.new())   # kẻ đứt mờ ngăn cách các quái

func refresh_vip(players: Array):
	_vip_cache = players
	for c in vip_rows.get_children():
		c.queue_free()
	vip_pager.set_total(players.size(), VIP_PER_PAGE)
	for p in Pager.slice(players, vip_pager.page, VIP_PER_PAGE):
		vip_rows.add_child(_lab("%s  (lv %s)" % [p.get("name", p.get("id", "?")), p.get("level", "?")], 12))

func refresh_backpack(items: Dictionary):
	if auto_panel != null:
		auto_panel.set_backpack(items)
	if char_panel != null:
		char_panel.set_items(items)   # lưới túi đồ 5x5 + ô chi tiết
	if hotbar != null:
		hotbar.set_backpack(items)  # cập nhật số lượng pot/rune trên các ô hotbar

func add_log(ch: String, bbcode: String):
	lines.append([ch, bbcode])
	while lines.size() > 200:
		lines.pop_front()
	refresh_chat()

func refresh_chat():
	chat_log.clear()
	for ln in lines:
		if ln[0] == channel or (channel == "local" and ln[0] == "npcs"):
			chat_log.append_text(UiTheme.ink_bbcode(ln[1]) + "\n")


## Icon trạng thái 28x28 (No / Cap): sáng = ổn, tối = đói / quá tải. Có assets/icons/status/<tên>.png thì dùng, chưa có thì ô chữ tạm.
class StatusIcon extends Control:
	var tex: Texture2D = null
	var glyph := ""
	var accent := Color(0.5, 0.5, 0.5)
	var lit := true

	func setup(icon_name: String, p_glyph: String, p_accent: Color) -> void:
		tex = IconBtn.load_icon(icon_name)
		glyph = p_glyph
		accent = p_accent
		custom_minimum_size = Vector2(28, 28)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_state(on: bool, tip: String) -> void:
		lit = on
		tooltip_text = tip
		modulate = Color.WHITE if on else Color(0.38, 0.38, 0.4, 1.0)
		queue_redraw()

	func _draw() -> void:
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
			return
		var sb := StyleBoxFlat.new()
		sb.bg_color = accent.darkened(0.2)
		sb.border_color = accent.darkened(0.55)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(5)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var f := get_theme_default_font()
		draw_string(f, Vector2(0, size.y * 0.5 + 5), glyph, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color.WHITE)