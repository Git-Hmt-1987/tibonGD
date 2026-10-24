class_name PartyPanel
extends PanelContainer
## Panel Party (server party.py, P1). Nằm cột trái ngay dưới khối HP/Mana, ở vị trí cũ của "Trạng thái".
## Nhận gói `party` (mỗi giây khi đang ở party): {id|null, leader, share, min_level, bonus, members:[{id,name,level,vocation,hp,max_hp,mana,max_mana,map,leader}], invites:[tên]}
## và `party_invite {from, party, ttl}` / `party_invite_end {party}`. Panel chỉ gửi yêu cầu (signal `action`), server kiểm mọi luật rồi gửi lại trạng thái.

signal action(op: String, args: Dictionary)

const VOC_SHORT := {1: "Sorc", 2: "Druid", 3: "Pal", 4: "Knight", 9: "Monk"}
const COL_LEADER := Color(1.0, 0.85, 0.35)
const COL_NAME := Color(0.9, 0.95, 1.0)
const COL_FAR := Color(0.55, 0.58, 0.65)

var data: Dictionary = {}
var invites: Dictionary = {}        # party id (int) -> {"from": String, "until": int msec}
var my_id := ""
var _title: Label
var _info: Label
var _share_btn: Button
var _members_box: VBoxContainer
var _rows: Dictionary = {}          # member id -> {"name": Label, "hp": ProgressBar, "hp_t": Label, "mp": ProgressBar, "mp_t": Label}
var _sig := ""
var _empty_lab: Label
var _pending_box: VBoxContainer
var _pending_sig := "-"
var _inv_box: VBoxContainer
var _inv_sig := "-"
var _name_edit: LineEdit
var _invite_row: HBoxContainer
var _foot: HBoxContainer
var _leave_btn: Button
var _disband_btn: Button
var _armed := ""


func build() -> void:
	visible = false
	add_theme_stylebox_override("panel", UiKit.panel_style())
	UiKit.block_world(self)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	UiKit.head_sep(head)
	_title = UiKit.title("Party")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_share_btn = Button.new()
	_share_btn.focus_mode = Control.FOCUS_NONE
	_share_btn.add_theme_font_size_override("font_size", 11)
	_share_btn.pressed.connect(func(): action.emit("party_share", {"on": not bool(data.get("share", false))}))
	head.add_child(_share_btn)
	_info = UiKit.lab("", 11, Color(0.62, 0.66, 0.72))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(208, 0)   # label tự xuống dòng PHẢI có bề rộng tối thiểu (bài học HousePanel)
	v.add_child(_info)
	_members_box = VBoxContainer.new()
	_members_box.add_theme_constant_override("separation", 3)
	v.add_child(_members_box)
	_empty_lab = UiKit.lab("Bạn chưa ở trong party. Nhập tên người chơi để mời (hoặc chuột phải vào người chơi).", 11, Color(0.75, 0.78, 0.85))
	_empty_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_lab.custom_minimum_size = Vector2(208, 0)
	v.add_child(_empty_lab)
	_pending_box = VBoxContainer.new()
	v.add_child(_pending_box)
	_inv_box = VBoxContainer.new()
	v.add_child(_inv_box)
	_invite_row = HBoxContainer.new()
	_invite_row.add_theme_constant_override("separation", 4)
	v.add_child(_invite_row)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Tên người chơi"
	_name_edit.max_length = 20
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_size_override("font_size", 12)
	_name_edit.text_submitted.connect(func(_t): _on_invite())
	_invite_row.add_child(_name_edit)
	var inv_btn := Button.new()
	inv_btn.text = "Mời"
	inv_btn.focus_mode = Control.FOCUS_NONE
	inv_btn.pressed.connect(_on_invite)
	_invite_row.add_child(inv_btn)
	_foot = HBoxContainer.new()
	_foot.add_theme_constant_override("separation", 4)
	v.add_child(_foot)
	_leave_btn = Button.new()
	_leave_btn.text = "Rời party"
	_leave_btn.focus_mode = Control.FOCUS_NONE
	_leave_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leave_btn.pressed.connect(func(): action.emit("party_leave", {}))
	_foot.add_child(_leave_btn)
	_disband_btn = Button.new()
	_disband_btn.focus_mode = Control.FOCUS_NONE
	_disband_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_disband_btn.pressed.connect(_on_disband)
	_foot.add_child(_disband_btn)
	var t := Timer.new()           # hết hạn lời mời nhận được (server chỉ đẩy `party` khi đang ở party)
	t.wait_time = 1.0
	t.autostart = true
	t.timeout.connect(_tick)
	add_child(t)
	_refresh()


func show_panel() -> void:
	visible = true
	_refresh()


func hide_panel() -> void:
	visible = false


func toggle() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()


## Gói `party` từ server.
func set_state(msg: Dictionary) -> void:
	data = msg
	_armed = ""
	_refresh()


## Gói `party_invite`: lưu lời mời, tự mở panel.
func add_invite(party_id: int, from: String, ttl: int) -> void:
	invites[party_id] = {"from": from, "until": Time.get_ticks_msec() + ttl * 1000}
	visible = true
	_refresh()


func end_invite(party_id: int) -> void:
	invites.erase(party_id)
	_refresh()


func in_party() -> bool:
	return data.get("id") != null


func is_leader() -> bool:
	return in_party() and str(data.get("leader", "")) == my_id


func _on_invite() -> void:
	var n := _name_edit.text.strip_edges()
	if n == "":
		return
	action.emit("party_invite", {"name": n})
	_name_edit.clear()
	_name_edit.release_focus()


func _on_disband() -> void:
	if _armed != "disband":
		_armed = "disband"          # giải tán không hoàn tác: bấm 2 lần
		_refresh()
		return
	_armed = ""
	action.emit("party_disband", {})


func _tick() -> void:
	var now := Time.get_ticks_msec()
	var changed := false
	for pid in invites.keys():
		if int(invites[pid]["until"]) <= now:
			invites.erase(pid)
			changed = true
	if changed:
		_refresh()


# ---------- vẽ ----------

func _refresh() -> void:
	if _title == null:
		return
	var inp := in_party()
	var lead := is_leader()
	var members: Array = data.get("members", []) if inp else []
	_empty_lab.visible = not inp
	_members_box.visible = inp
	_share_btn.visible = inp
	_foot.visible = inp
	_invite_row.visible = (not inp) or lead
	_disband_btn.visible = lead
	_disband_btn.text = "Chắc chắn?" if _armed == "disband" else "Giải tán"
	if inp:
		_title.text = "Party (%d)" % members.size()
		var on := bool(data.get("share", false))
		_share_btn.text = "Chia EXP: BẬT" if on else "Chia EXP: TẮT"
		_share_btn.modulate = Color(0.6, 1.0, 0.6) if on else Color(1, 1, 1)
		_share_btn.disabled = not lead
		_info.text = "Chia EXP cho người từ Lv %d · thưởng ×%.1f theo số nghề khác nhau" % [int(data.get("min_level", 0)), float(data.get("bonus", 1.0))]
		if on and bool(data.get("share_active", false)):
			_info.text += "\nĐANG CHIA EXP"
			_info.add_theme_color_override("font_color", Color(0.1, 0.5, 0.2))
		elif on:
			_info.text += "\nChưa chia được: %s" % str(data.get("share_why", ""))
			_info.add_theme_color_override("font_color", Color(0.75, 0.35, 0.1))
		else:
			_info.add_theme_color_override("font_color", UiTheme.muted())
	else:
		_title.text = "Party"
		_info.text = ""
	_info.visible = inp
	_refresh_members(members, lead)
	_refresh_pending(data.get("invites", []) if lead else [])
	_refresh_received()


func _refresh_members(members: Array, lead: bool) -> void:
	var ids: Array = []
	for m in members:
		ids.append(str(m.get("id", "")))
	var sig := ",".join(ids) + "|" + str(data.get("leader", "")) + "|" + str(lead)
	if sig != _sig:       # đổi thành phần: dựng lại hàng; còn lại chỉ cập nhật số (không nháy, không mất click)
		_sig = sig
		for c in _members_box.get_children():
			c.queue_free()
		_rows.clear()
		for m in members:
			_build_row(m, lead)
	var my_map := ""
	for m in members:
		if str(m.get("id", "")) == my_id:
			my_map = str(m.get("map", ""))
	for m in members:
		var r: Dictionary = _rows.get(str(m.get("id", "")), {})
		if r.is_empty():
			continue
		var far := str(m.get("map", "")) != my_map
		var is_lead := bool(m.get("leader", false))
		var nm: Label = r["name"]
		nm.text = "%s%s  Lv %d %s%s" % ["★ " if is_lead else "", str(m.get("name", "?")), int(m.get("level", 1)),
				str(VOC_SHORT.get(int(m.get("vocation", 0)), "")), "  (xa)" if far else ""]
		nm.add_theme_color_override("font_color", UiTheme.ink(COL_FAR if far else (COL_LEADER if is_lead else COL_NAME)))
		var hp: ProgressBar = r["hp"]
		hp.max_value = maxi(1, int(m.get("max_hp", 1)))
		hp.value = int(m.get("hp", 0))
		(r["hp_t"] as Label).text = "%d/%d" % [int(m.get("hp", 0)), int(m.get("max_hp", 1))]
		var mp: ProgressBar = r["mp"]
		mp.max_value = maxi(1, int(m.get("max_mana", 1)))
		mp.value = int(m.get("mana", 0))
		(r["mp_t"] as Label).text = "%d/%d" % [int(m.get("mana", 0)), int(m.get("max_mana", 1))]


func _build_row(m: Dictionary, lead: bool) -> void:
	var mid := str(m.get("id", ""))
	var mname := str(m.get("name", ""))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	_members_box.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 2)
	box.add_child(top)
	var nm := UiKit.lab("", 12)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	top.add_child(nm)
	if lead and mid != my_id:
		top.add_child(_small_btn("L", "Chuyển quyền leader cho %s" % mname, func(): action.emit("party_pass", {"name": mname})))
		top.add_child(_small_btn("X", "Đuổi %s khỏi party" % mname, func(): action.emit("party_kick", {"name": mname})))
	var hp := UiKit.bar(Color(0.8, 0.15, 0.15), 9.0)
	var hp_t := UiKit.bar_overlay(hp, 9)
	box.add_child(hp)
	var mp := UiKit.bar(Color(0.25, 0.4, 0.95), 7.0)
	var mp_t := UiKit.bar_overlay(mp, 8)
	box.add_child(mp)
	_rows[mid] = {"name": nm, "hp": hp, "hp_t": hp_t, "mp": mp, "mp_t": mp_t}


func _small_btn(t: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(20, 18)
	b.add_theme_font_size_override("font_size", 10)
	b.pressed.connect(cb)
	return b


## Lời mời MÌNH đã gửi (leader thấy): có nút Hủy.
func _refresh_pending(names: Array) -> void:
	var sig := ",".join(names)
	if sig == _pending_sig:
		return
	_pending_sig = sig
	for c in _pending_box.get_children():
		c.queue_free()
	for n in names:
		var nn := str(n)
		var row := HBoxContainer.new()
		_pending_box.add_child(row)
		var l := UiKit.lab("Đang mời: %s" % nn, 11, Color(0.8, 0.8, 0.5))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		row.add_child(l)
		row.add_child(_small_btn("Hủy", "Thu hồi lời mời", func(): action.emit("party_kick", {"name": nn})))


## Lời mời MÌNH nhận được (đang chưa ở party hoặc đang ở party khác vẫn hiện): Nhận / Từ chối.
func _refresh_received() -> void:
	var ids: Array = invites.keys()
	ids.sort()
	var sig := ",".join(ids.map(func(i): return str(i)))
	if sig == _inv_sig:
		return
	_inv_sig = sig
	for c in _inv_box.get_children():
		c.queue_free()
	for pid in ids:
		var from := str(invites[pid]["from"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		_inv_box.add_child(row)
		var l := UiKit.lab("%s mời bạn" % from, 12, Color(1.0, 0.9, 0.5))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		row.add_child(l)
		var ok := _small_btn("Nhận", "Vào party của %s" % from, func(): action.emit("party_accept", {"from": from}))
		ok.custom_minimum_size = Vector2(38, 20)
		row.add_child(ok)
		var no := _small_btn("Bỏ", "Từ chối", func(): action.emit("party_decline", {"from": from}))
		no.custom_minimum_size = Vector2(30, 20)
		row.add_child(no)