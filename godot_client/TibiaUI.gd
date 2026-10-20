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
const BATTLE_FONT := 12  # cỡ chữ tên quái trong Battle
const VOC_NAMES := {1: "Sorcerer", 2: "Druid", 3: "Paladin", 4: "Knight"}

var minimap: Minimap
var tgt_name: Label
var tgt_hp: ProgressBar
var tgt_hp_text: Label
var map_btn: Button   # nút M vuông bo góc nhỏ ở góc dưới-phải Card Map (bấm = mở/đóng bản đồ thế giới, như phím M)
var map_lab: Label    # tên map (hàng dưới minimap, bên phải)
var clock_text: Label # giờ (hàng dưới minimap, bên trái — chỗ "N ^" cũ)
var vitals: VitalsBlock  # chân dung + HP/Mana/Stamina + icon Attack/Balance/Defense (trên cùng bên trái)
var hotbar: Hotbar       # hàng ô F1..F12 giữa-dưới
var cap_btn: Button
var money_lab: Label   # "Gold / Bank" dưới lưới Equipment trong panel Character (gói stats.gold / stats.bank)
var exp_bar: ProgressBar
var exp_text: Label
var auto_btn: IconBtn
var chase_btn: IconBtn
var logout_btn: IconBtn
var skill_labs := {}
var skill_bars := {}
var battle_rows: VBoxContainer
var battle_pager: Pager       # Battle theo trang (5 quái/trang), thay cho thanh cuộn
var _battle_cache: Array = []
var _battle_target := ""
const BATTLE_PER_PAGE := 5
var vip_pager: Pager
var _vip_cache: Array = []
const VIP_PER_PAGE := 8
var pack_pager: Pager         # túi đồ theo trang (7 cột x 4 hàng)
const PACK_PER_PAGE := 28
var battle_panel: PanelContainer
var skills_panel: PanelContainer
var vip_panel: PanelContainer
var vip_rows: VBoxContainer
var status_panel: PanelContainer
var party_panel: PartyPanel     # Panel Party (cột trái, vị trí cũ của Trạng thái); Trạng thái nay nằm cột phải trên Battle
var status_box: VBoxContainer
var status_exp_bar: ProgressBar  # thanh % EXP ngay dưới dòng "EXP" trong card Trạng thái
var status_exp_pct: Label
var cond_box: HFlowContainer  # chip condition (haste/poison...) trong panel Trạng thái
var spell_panel: SpellPanel
var auto_panel: AutoPanel
var char_panel: PanelContainer
var char_equip := {}
var pack_grid: GridContainer
var pack_count: Label
var pack_items := {}
var pack_cat := "all"
var cat_btns := {}
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
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.15, 0.2, 0.95)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.4, 0.45, 0.55)
	sb.set_content_margin_all(6)
	p.add_theme_stylebox_override("panel", sb)
	UiKit.block_world(p)   # chuột trên panel không lọt xuống bản đồ
	return p

func _bar(fill: Color, h := 14.0) -> ProgressBar:
	var b = ProgressBar.new()
	b.custom_minimum_size = Vector2(0, h)
	b.show_percentage = false
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.07)
	b.add_theme_stylebox_override("background", bg)
	var fg = StyleBoxFlat.new()
	fg.bg_color = fill
	b.add_theme_stylebox_override("fill", fg)
	return b

func _lab(t: String, sz := 12, col := Color(0.9, 0.9, 0.9)) -> Label:
	var l = Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
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
	_build_exp_bar()
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
	clock_text = _lab("--:--", 12, Color(0.7, 0.8, 0.9))  # giờ: thay chỗ "N ^"
	h.add_child(clock_text)
	map_lab = _lab("", 12, Color(0.8, 0.9, 1.0))  # tên map: thay chỗ nút "Centre"
	map_lab.size_flags_horizontal = SIZE_EXPAND_FILL
	map_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	map_lab.clip_text = true
	h.add_child(map_lab)
	map_btn = Button.new()   # cuối hàng dưới card = góc dưới-phải; Main nối sự kiện pressed
	map_btn.text = "M"
	map_btn.custom_minimum_size = Vector2(22, 22)
	map_btn.focus_mode = Control.FOCUS_NONE        # không cướp phím WASD
	map_btn.tooltip_text = "Bản đồ thế giới (M)"
	map_btn.add_theme_font_size_override("font_size", 12)
	map_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color(0.1, 0.12, 0.18, 0.9), "hover": Color(0.22, 0.28, 0.42, 0.95), "pressed": Color(0.3, 0.38, 0.55, 1.0)}[st]
		sb.set_corner_radius_all(4)    # vuông bo góc nhẹ cho đồng bộ với các panel
		sb.set_border_width_all(1)
		sb.border_color = Color(0.85, 0.75, 0.4, 0.9)
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		map_btn.add_theme_stylebox_override(st, sb)
	h.add_child(map_btn)

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
	tgt_hp = _bar(Color(0.8, 0.12, 0.12), 16.0)
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
	v.add_child(UiKit.title("Trạng thái"))
	status_box = VBoxContainer.new()
	v.add_child(status_box)
	status_exp_bar = _bar(Color(0.55, 0.25, 0.85), 12.0)
	status_exp_bar.max_value = 100
	status_exp_pct = UiKit.bar_overlay(status_exp_bar, 10)
	status_exp_pct.text = "0.0%"
	cond_box = HFlowContainer.new()
	cond_box.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_child(cond_box)

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

func _build_hotbar():
	hotbar = Hotbar.new()
	hotbar.name_fn = func(iid: int) -> String: return name_of(iid)
	hotbar.anchor_left = 0.5
	hotbar.anchor_right = 0.5
	hotbar.anchor_top = 1.0
	hotbar.anchor_bottom = 1.0
	var w := Hotbar.total_width()
	hotbar.offset_left = -w / 2.0
	hotbar.offset_right = w / 2.0
	hotbar.offset_top = -(Hotbar.SLOT_W + 30)
	hotbar.offset_bottom = -30
	add_child(hotbar)
	hotbar.build()
	hotbar.use_item.connect(func(iid: int): use_pressed.emit(iid))
	hotbar.cast_spell.connect(func(sid: String): cast_pressed.emit(sid))

# ---------- đáy: thanh EXP ----------

func _build_exp_bar():
	var ex = HBoxContainer.new()
	ex.anchor_top = 1.0
	ex.anchor_bottom = 1.0
	ex.offset_left = 8
	ex.offset_right = -8
	ex.offset_top = -24
	ex.offset_bottom = -4
	add_child(ex)
	exp_text = _lab("Lv 8", 11)
	exp_text.custom_minimum_size = Vector2(150, 0)
	ex.add_child(exp_text)
	exp_bar = _bar(Color(0.55, 0.25, 0.85), 12.0)
	exp_bar.max_value = 100
	exp_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	ex.add_child(exp_bar)

# ---------- phải-dưới: icon gọn 2 hàng (icon tạm — thay bằng PNG trong icons/, xem icons/README.md) ----------

func _build_bottom_right_icons():
	var g = GridContainer.new()
	g.columns = 4
	g.anchor_left = 1.0
	g.anchor_right = 1.0
	g.anchor_top = 1.0
	g.anchor_bottom = 1.0
	g.offset_left = -160
	g.offset_right = -8
	g.offset_top = -144
	g.offset_bottom = -30
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	add_child(g)
	# [id, tên file icon, chữ tạm, tooltip, màu nền tạm]
	for b in [["char", "btn_char", "Ch", "Character (C)", Color(0.35, 0.55, 0.9)],
			["skills", "btn_skills", "Sk", "Skills (K)", Color(0.35, 0.7, 0.45)],
			["battle", "btn_battle", "Bt", "Battle list (B)", Color(0.85, 0.35, 0.3)],
			["vip", "btn_vip", "Vp", "Online / VIP (V)", Color(0.8, 0.65, 0.25)],
			["status", "btn_status", "St", "Trạng thái (U)", Color(0.55, 0.45, 0.85)],
			["party", "btn_party", "Pt", "Party", Color(0.35, 0.75, 0.4)],
			["auto", "btn_auto", "AU", "Bật/tắt Auto săn theo vùng (T)", Color(0.3, 0.75, 0.6)],
			["autocfg", "btn_autocfg", "Ac", "Cấu hình Auto (Y)", Color(0.3, 0.6, 0.75)],
			["spell", "btn_spell", "Sp", "Spells", Color(0.35, 0.65, 0.95)],
			["logout", "btn_logout", "Out", "Logout", Color(0.6, 0.6, 0.65)]]:
		var btn := IconBtn.new()
		btn.setup(str(b[1]), str(b[2]), str(b[3]), Vector2(34, 34), b[4])
		if b[0] == "auto":
			btn.toggle_mode = true  # logic AUTO của user: giữ nguyên (toggled -> _on_auto_btn, modulate xanh khi bật)
			btn.toggled.connect(_on_auto_btn)
			auto_btn = btn
		elif b[0] == "logout":
			logout_btn = btn
			btn.pressed.connect(_on_fun.bind("logout"))
		else:
			btn.pressed.connect(_on_fun.bind(str(b[0])))
		g.add_child(btn)

## Server xác nhận / báo trạng thái "đuổi theo" (hello + gói chase): chỉ cập nhật nút, không phát lại tín hiệu.
func set_chase(on: bool):
	vitals.set_chase(on)

func _on_fun(which: String):
	match which:
		"char": toggle_char()
		"skills": toggle_popup("skills")
		"battle": toggle_popup("battle")
		"vip": toggle_popup("vip")
		"status": toggle_popup("status")
		"party": party_panel.toggle()
		"spell": spell_panel.visible = not spell_panel.visible
		"autocfg": toggle_auto_panel()
		"logout": logout_pressed.emit()

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
	bot.offset_top = -190
	bot.offset_bottom = -30
	add_child(bot)
	var v = VBoxContainer.new()
	bot.add_child(v)
	var tabs = HBoxContainer.new()
	v.add_child(tabs)
	for t in [["local", "Chat"], ["server", "Log"], ["npcs", "NPCs"]]:
		var b = Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.button_pressed = (t[0] == "local")
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", UiKit.bold_font())  # title tab: đậm, cỡ 12 như dòng Speed
		b.add_theme_font_size_override("font_size", 12)
		for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(cn, Color(1, 0.9, 0.5))
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
	bv.add_child(UiKit.title("Battle (click = target+đánh)", 12))
	var battle_area = VBoxContainer.new()   # không cuộn: danh sách chia trang, cuộn chuột trên vùng này = đổi trang
	battle_area.custom_minimum_size = Vector2(0, 130)
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
	sv.add_child(UiKit.title("Skills"))
	for k in SKILL_NAMES:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		sv.add_child(row)
		var l = _lab(SKILL_NAMES[k], 11)
		l.custom_minimum_size = Vector2(48, 0)
		row.add_child(l)
		var bar = _bar(Color(0.92, 0.92, 0.92), 5.0)  # thấp còn 1/2 (10 -> 5)
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
	spell_panel.offset_left = -300
	spell_panel.offset_right = 300
	spell_panel.offset_top = -270
	spell_panel.offset_bottom = 270
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
	auto_btn.set_pressed_no_signal(on)
	auto_btn.modulate = Color(0.5, 1, 0.5) if on else Color.WHITE
	auto_panel.apply_state(msg)

func refresh_spells(spells: Array, voc := 4):
	spell_panel.set_data(spells, voc)
	auto_panel.set_spells(spells, voc)
	hotbar.set_spells(spells, voc)

func _build_char_panel():
	char_panel = _panel()
	char_panel.anchor_left = 0.5
	char_panel.anchor_right = 0.5
	char_panel.anchor_top = 0.5
	char_panel.anchor_bottom = 0.5
	char_panel.offset_left = -340
	char_panel.offset_right = 340
	char_panel.offset_top = -250
	char_panel.offset_bottom = 250
	char_panel.visible = false
	add_child(char_panel)
	var v = VBoxContainer.new()
	char_panel.add_child(v)
	var title = HBoxContainer.new()
	v.add_child(title)
	var tt = _lab("Character", 16, Color(1, 0.9, 0.5))
	tt.size_flags_horizontal = SIZE_EXPAND_FILL
	title.add_child(tt)
	var x = Button.new()
	x.text = "X"
	x.pressed.connect(toggle_char)
	title.add_child(x)
	var cols = HBoxContainer.new()
	cols.size_flags_vertical = SIZE_EXPAND_FILL
	v.add_child(cols)
	var left = VBoxContainer.new()
	left.custom_minimum_size = Vector2(170, 0)
	cols.add_child(left)
	left.add_child(_lab("Equipment (click: tháo)", 12))
	var eq = GridContainer.new()
	eq.columns = 3
	left.add_child(eq)
	var order = ["Head", "Neck", "Pack", "Armor", "Portrait", "R-Hand",
		"L-Hand", "Legs", "Boots", "Ring", "Ammo", "Soul"]
	for s in order:
		if s == "Portrait":
			var pt = Portrait.new()
			pt.custom_minimum_size = Vector2(56, 76)
			eq.add_child(pt)
			continue
		var b = Button.new()
		b.custom_minimum_size = Vector2(52, 42)
		b.text = s.left(6) if s != "Pack" else "Pack"
		b.tooltip_text = s
		if s == "Soul":
			b.disabled = true
			b.text = "Soul\n--"
			b.add_theme_font_size_override("font_size", 11)
			b.add_theme_color_override("font_disabled_color", Color(0.9, 0.9, 0.9))
		else:
			b.pressed.connect(_on_inv_click.bind(s))
		eq.add_child(b)
		char_equip[s] = b
	cap_btn = Button.new()
	cap_btn.custom_minimum_size = Vector2(52, 42)
	cap_btn.disabled = true
	cap_btn.text = "Cap\n--"
	cap_btn.tooltip_text = "Capacity"
	cap_btn.add_theme_font_size_override("font_size", 11)
	cap_btn.add_theme_color_override("font_disabled_color", Color(0.9, 0.9, 0.9))
	eq.add_child(cap_btn)
	money_lab = _lab("Gold: 0\nBank: 0", 12, Color(1.0, 0.9, 0.4))
	money_lab.tooltip_text = "Gold trong túi / số dư Bank (gửi, rút ở Hòm đồ)"
	left.add_child(money_lab)
	var right = VBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	cols.add_child(right)
	var cats = HBoxContainer.new()
	right.add_child(cats)
	for c in CATS:
		var b = Button.new()
		b.text = c[1]
		b.toggle_mode = true
		b.button_pressed = (c[0] == "all")
		b.pressed.connect(_set_cat.bind(c[0]))
		cats.add_child(b)
		cat_btns[c[0]] = b
	var pack_area = VBoxContainer.new()   # túi đồ theo TRANG (không cuộn): cuộn chuột trên vùng này = đổi trang
	pack_area.size_flags_vertical = SIZE_EXPAND_FILL
	pack_area.clip_contents = true
	right.add_child(pack_area)
	pack_grid = GridContainer.new()
	pack_grid.columns = 7
	pack_area.add_child(pack_grid)
	pack_pager = Pager.new()
	pack_pager.page_changed.connect(func(_p): refresh_backpack(pack_items))
	right.add_child(pack_pager)
	pack_pager.attach_wheel(pack_area)
	pack_count = _lab("", 11)
	right.add_child(pack_count)
	refresh_backpack({})

func toggle_char():
	char_panel.visible = not char_panel.visible

func _set_cat(c: String):
	pack_cat = c
	pack_pager.page = 0
	for k in cat_btns:
		cat_btns[k].button_pressed = (k == c)
	refresh_backpack(pack_items)

func _on_auto_btn(on: bool):
	auto_btn.modulate = Color(0.5, 1, 0.5) if on else Color.WHITE
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
	hotbar.set_character_owner(nm)

## Gold trong túi + số dư Bank (server gửi trong gói stats).
func set_money(gold: int, bank: int):
	if money_lab == null:
		return
	money_lab.text = "Gold: %s\nBank: %s" % [UiKit.fmt_int(gold), UiKit.fmt_int(bank)]

func _oz(v: float) -> String:
	return "%d" % roundi(v) if absf(v - roundf(v)) < 0.005 else "%.1f" % v

func set_soul_cap(soul: int, max_soul: int, free_cap: float, max_cap: float):
	var sb: Button = char_equip["Soul"]
	sb.text = "Soul\n%d" % soul
	sb.tooltip_text = "Soul: %d/%d" % [soul, max_soul]
	cap_btn.text = "Cap\n%s" % _oz(free_cap)
	cap_btn.tooltip_text = "Capacity còn trống: %s / %s oz" % [_oz(free_cap), _oz(max_cap)]

func set_exp(exp: int, level: int, percent: float):
	exp_bar.max_value = 100
	exp_bar.value = percent
	exp_text.text = "Lv %d · %d · %.1f%%" % [level, exp, percent]
	status_exp_bar.max_value = 100
	status_exp_bar.value = percent
	status_exp_pct.text = "%.1f%%" % percent
	spell_panel.set_level(level)
	if auto_panel != null:
		auto_panel.set_level(level)

func set_clock(t: String):
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
		c.queue_free()
	for it in list:
		var t := str(it.get("t", "?"))
		var info: Array = COND_CHIP.get(t, [t.left(3).to_upper(), Color(0.5, 0.5, 0.5)])
		var chip = _lab(str(info[0]), 11, Color.WHITE)
		var sb = StyleBoxFlat.new()
		sb.bg_color = info[1]
		sb.set_content_margin_all(2)
		chip.add_theme_stylebox_override("normal", sb)
		var left_ms := int(it.get("left", -1))
		chip.tooltip_text = t if left_ms < 0 else "%s · còn %d giây" % [t, ceili(left_ms / 1000.0)]
		chip.mouse_filter = MOUSE_FILTER_PASS
		cond_box.add_child(chip)

func set_status(lines: Array):
	if status_exp_bar.get_parent() != null:
		status_exp_bar.get_parent().remove_child(status_exp_bar)  # giữ lại, không để bị free cùng các dòng
	for c in status_box.get_children():
		c.queue_free()
	for ln in lines:
		status_box.add_child(_lab(ln, 12))
		if str(ln).begins_with("EXP"):
			status_box.add_child(status_exp_bar)  # thanh % ngay dưới dòng EXP

func set_skills(skills: Dictionary, pcts := {}, maglv := -1, magpct := 0.0):
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
	for slot in char_equip:
		if slot == "Soul":
			continue  # ô Soul hiển thị điểm soul (set_soul_cap), không phải đồ mặc
		var iid = int(equip.get(slot, 0))
		var b: Button = char_equip[slot]
		if iid > 0:
			var nm = name_of(iid)
			var n = int(counts.get(slot, 0))
			b.text = nm.left(7)
			if n > 1:
				b.text = "%s x%d" % [nm.left(5), n]
			b.tooltip_text = "%s: %s%s (click: tháo)" % [slot, nm, " x%d" % n if n > 1 else ""]
		else:
			b.text = slot.left(6) if slot != "Pack" else "Pack"
			b.tooltip_text = slot + " (empty)"

func set_online(on: bool):
	logout_btn.set_glyph("Out" if on else "In")
	logout_btn.tooltip_text = "Logout" if on else "Login"

func set_auto(on: bool):
	auto_btn.set_pressed_no_signal(on)
	auto_btn.modulate = Color(0.5, 1, 0.5) if on else Color.WHITE

func refresh_battle(creatures: Array, target: String):
	_battle_cache = creatures
	_battle_target = target
	for c in battle_rows.get_children():
		c.queue_free()
	battle_pager.set_total(creatures.size(), BATTLE_PER_PAGE)
	for e in Pager.slice(creatures, battle_pager.page, BATTLE_PER_PAGE):
		var b = Button.new()
		b.text = "%s [%d]" % [e.get("name", e.get("id", "?")), e.get("hp", 0)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", BATTLE_FONT)  # tên quái trong Battle nhỏ lại
		if e.get("id") == target:
			b.modulate = Color(1, 0.5, 0.5)
		var cid = e.get("id", "")
		b.pressed.connect(target_selected.emit.bind(cid))
		battle_rows.add_child(b)

func refresh_vip(players: Array):
	_vip_cache = players
	for c in vip_rows.get_children():
		c.queue_free()
	vip_pager.set_total(players.size(), VIP_PER_PAGE)
	for p in Pager.slice(players, vip_pager.page, VIP_PER_PAGE):
		vip_rows.add_child(_lab("%s  (lv %s)" % [p.get("name", p.get("id", "?")), p.get("level", "?")], 12))

func refresh_backpack(items: Dictionary):
	pack_items = items
	if auto_panel != null:
		auto_panel.set_backpack(items)
	for c in pack_grid.get_children():
		c.queue_free()
	var entries: Array = []   # [iid, n, cat] sau khi lọc theo tab
	for iid in items:
		var e = items[iid]
		var n = int(e["n"]) if e is Dictionary else int(e)
		var cat = str(e["cat"]) if e is Dictionary else "others"
		if pack_cat != "all" and cat != pack_cat:
			continue
		entries.append([iid, n, cat])
	pack_pager.set_total(entries.size(), PACK_PER_PAGE)
	var shown = 0
	for en in Pager.slice(entries, pack_pager.page, PACK_PER_PAGE):
		var iid = en[0]
		var n = en[1]
		var cat = en[2]
		var nm = name_of(int(iid))
		var b = Button.new()
		b.custom_minimum_size = Vector2(56, 50)
		b.text = "%s\nx%s" % [nm.left(9), n]
		b.tooltip_text = "%s [%s] (click: dùng)" % [nm, cat]
		b.pressed.connect(_on_pack_click.bind(int(iid)))
		pack_grid.add_child(b)
		shown += 1
	var total = items.size()
	pack_count.text = "%d loại · hiện %d · tab %s" % [total, shown, pack_cat]
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
			chat_log.append_text(ln[1] + "\n")
