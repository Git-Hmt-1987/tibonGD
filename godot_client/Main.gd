extends Control
## Main: network + state + nối UI. Quy ước Tibia: x+ = đông (phải), y+ = nam (xuống).

const SERVER_CFG := "user://server.cfg"   # nhớ địa chỉ server lần trước
var server_url := "ws://127.0.0.1:7172"

var ws := WebSocketPeer.new()
var connected := false
var connecting := false          # đã gọi connect_to_url, chưa mở xong
var pending_out: Array = []      # gói chờ gửi khi kết nối mở (đăng nhập/đăng ký...)
var ctx_menu: PopupMenu              # menu chuột phải lên người chơi khác (mời party)
var ctx_target := ""
var party_state: Dictionary = {}   # gói `party` mới nhất từ server (P1)
var auto_login: Array = []       # sau register_ok: tự gửi login với [account, password]
var login_screen: LoginScreen
var player_id := "local"
var my_name := "Hero"
var tiles := {}
var kinds := {}
var names := {}
var hps := {}
var stats := {"level": 8, "exp": 4200, "hp": 150}
var backpack := {}
var target := ""
var aim_item := 0              # rune đang ngắm lên ô đất (server gửi `aim`); click trái -> use_on, phải/ESC -> hủy
var auto_mode := false         # trạng thái Auto do SERVER xác nhận (gói auto_state)
var auto_origin := Vector2i(-1, -1)
var clock_acc := 0.0

var world: WorldView
var ui: TibiaUI
var map_id := "city"
var map_name := "Dream Land"
var my_voc := 4
var my_speed := 0  # tốc độ bước từ gói stats (hiện ở panel Trạng thái)
var death_label: Label
var spell_info := {}          # id spell -> dict (từ gói `spells`), để tô màu hiệu ứng theo element khi cast
var last_cast_element := ""   # element của spell mình vừa cast (D5: màu fx theo element)
var last_cast_t := -99.0
const VOC_NAMES := {1: "Sorcerer", 2: "Druid", 3: "Paladin", 4: "Knight"}
const NPC_RANGE := 4          # mirror server npc.RANGE (npc.cpp canInteract range 4)
const NPC_COLORS := {"Spell": [0.7, 0.45, 1.0], "Trang bị": [0.85, 0.55, 0.2], "Vật dụng": [0.3, 0.75, 0.4],
	"Potion": [0.9, 0.3, 0.35], "Dịch Chuyển": [0.25, 0.8, 0.95], "Nhà": [0.85, 0.35, 0.3]}   # màu áo NPC theo tên (chỉ để phân biệt, chưa có sprite)
var npc_panel: NpcPanel
var depot_panel: DepotPanel          # Hòm đồ + Bank (click NPC type depot)
var house_panel: HousePanel          # NPC Nhà: mua / trả nhà (click NPC type house, server house_npc.py)
var world_map_panel: WorldMapPanel   # bản đồ thế giới (phím M)
var pending_npc := ""         # NPC vừa click khi còn xa: tới gần sẽ tự mở shop

func _ready():
	world = $World
	ui = $UI
	ui.build()
	npc_panel = NpcPanel.new()
	ui.add_child(npc_panel)
	npc_panel.build()
	npc_panel.buy_item.connect(func(nid, iid, n): _send({"op": "npc_buy", "id": nid, "item": iid, "n": n}))
	npc_panel.buy_spell.connect(func(nid, sp): _send({"op": "npc_buy", "id": nid, "spell": sp}))
	npc_panel.sell_item.connect(func(nid, iid, n): _send({"op": "npc_sell", "id": nid, "item": iid, "n": n}))
	world_map_panel = WorldMapPanel.new()
	ui.add_child(world_map_panel)
	world_map_panel.build()
	world_map_panel.need_data.connect(func(): _send({"op": "world_map"}))
	ui.map_btn.pressed.connect(func(): world_map_panel.toggle())   # nút M ở góc dưới-phải Card Map
	npc_panel.travel.connect(func(nid, mp): _send({"op": "npc_travel", "id": nid, "map": mp}))   # NPC Dịch Chuyển
	npc_panel.closed.connect(func(nid): _send({"op": "npc_close", "id": nid}))
	depot_panel = DepotPanel.new()   # Hòm đồ kiêm Bank: gửi/lấy đồ + gửi/rút tiền (server depot.py)
	ui.add_child(depot_panel)
	depot_panel.build()
	depot_panel.put_item.connect(func(nid, iid, n): _send({"op": "depot_put", "id": nid, "item": iid, "n": n}))
	depot_panel.take_item.connect(func(nid, iid, n): _send({"op": "depot_take", "id": nid, "item": iid, "n": n}))
	depot_panel.put_gold.connect(func(nid, n): _send({"op": "depot_gold_put", "id": nid, "n": n}))
	depot_panel.take_gold.connect(func(nid, n): _send({"op": "depot_gold_take", "id": nid, "n": n}))
	depot_panel.closed.connect(func(nid): _send({"op": "depot_close", "id": nid}))
	house_panel = HousePanel.new()   # NPC Nhà: danh sách nhà của thành phố + Mua / Trả nhà (server house_npc.py)
	ui.add_child(house_panel)
	house_panel.build()
	house_panel.buy_house.connect(func(nid, hid): _send({"op": "house_buy", "id": nid, "house": hid}))
	house_panel.leave_house.connect(func(nid, hid): _send({"op": "house_leave", "id": nid, "house": hid}))
	house_panel.guest_add.connect(func(nid, hid, nm): _send({"op": "house_guest_add", "id": nid, "house": hid, "name": nm}))
	house_panel.guest_del.connect(func(nid, hid, nm): _send({"op": "house_guest_del", "id": nid, "house": hid, "name": nm}))
	house_panel.closed.connect(func(nid): _send({"op": "house_close", "id": nid}))
	_register_ui_blockers()
	ui.centre_pressed.connect(_on_centre)
	ui.logout_pressed.connect(_on_logout)
	ui.fight_pressed.connect(func(mode): _send({"op": "fight", "mode": mode}))
	ui.vip_pressed.connect(_on_vip)
	ui.target_selected.connect(set_target)
	ui.use_pressed.connect(func(iid): _send({"op": "use", "item": iid}))
	ui.unequip_pressed.connect(func(slot): _send({"op": "unequip", "slot": slot}))
	ui.chat_sent.connect(_on_chat)
	ui.party_action.connect(func(op: String, args: Dictionary):
		var m := {"op": op}
		m.merge(args)
		_send(m))
	ctx_menu = PopupMenu.new()
	add_child(ctx_menu)
	ctx_menu.id_pressed.connect(func(mid: int):
		if mid == 0 and ctx_target != "":
			_send({"op": "party_invite", "name": str(names.get(ctx_target, ""))}))
	ui.learn_pressed.connect(func(sid): _send({"op": "learn", "spell": sid}))
	ui.cast_pressed.connect(_on_cast_spell)
	ui.auto_toggled.connect(_on_auto)
	ui.chase_toggled.connect(func(on: bool): _send({"op": "chase", "on": on}))   # đuổi theo / đứng im
	ui.auto_cfg_changed.connect(func(c: Dictionary): _send({"op": "auto_cfg", "cfg": c}))
	login_screen = LoginScreen.new()
	add_child(login_screen)   # vẽ trên cùng (node cuối cùng), chặn chuột tới game bên dưới
	var from_link := LoginScreen.server_from_url()   # ?server=... trên link web ưu tiên hơn địa chỉ đã nhớ
	login_screen.set_server(from_link if from_link != "" else _load_server_text())
	login_screen.login_requested.connect(func(a, p): _queue({"op": "login", "account": a, "password": p}))
	login_screen.register_requested.connect(func(a, p):
		auto_login = [a, p]
		_queue({"op": "register", "account": a, "password": p}))
	login_screen.create_requested.connect(func(slot, n, v): _queue({"op": "create_char", "slot": slot, "name": n, "vocation": v}))
	login_screen.delete_requested.connect(func(slot, p): _queue({"op": "delete_char", "slot": slot, "password": p}))
	login_screen.enter_requested.connect(func(slot): _queue({"op": "enter", "slot": slot}))
	get_viewport().size_changed.connect(_layout)
	_layout()
	_place(player_id, Vector2i(20, 20), "player")
	_push_top()
	ui.add_log("server", "Đăng nhập tài khoản và chọn nhân vật để vào game.")

## Gửi gói tới server; chưa kết nối thì xếp hàng rồi mở kết nối (cờ `connecting` tránh mở 2 lần).
func _queue(msg: Dictionary) -> void:
	if connected and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(msg))
		return
	pending_out.append(msg)
	if not connecting and ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_connect()

func _layout():
	var vp = get_viewport_rect().size
	# view_size (trừ 190 đáy) chỉ để canh tâm camera; world VẼ và NHẬN CLICK trên toàn màn hình (full_size) —
	# trước đây click bị chặn ở dải đáy (vy >= view_size.y) dù map vẫn vẽ ở đó. Panel UI tự chặn click của chính nó.
	world.view_size = Vector2(vp.x, vp.y - 190)
	world.full_size = vp
	world.queue_redraw()

func _load_server_text() -> String:
	var f := FileAccess.open(SERVER_CFG, FileAccess.READ)
	if f == null:
		return ""
	return f.get_line().strip_edges()

func _save_server_text(t: String) -> void:
	var f := FileAccess.open(SERVER_CFG, FileAccess.WRITE)
	if f != null:
		f.store_line(t)

func _connect():
	connecting = true
	server_url = login_screen.get_server_url()
	_save_server_text(server_url.trim_prefix("ws://").trim_prefix("wss://"))
	if ws.connect_to_url(server_url) != OK:
		connecting = false
		pending_out.clear()
		login_screen.show_login("Không kết nối được máy chủ (%s)." % server_url)

func _process(dt):
	# arena AUTO: hiện khi Auto bật hoặc khi đang mở panel cấu hình (xem trước kích thước)
	world.auto_origin = auto_origin if auto_mode else Vector2i(-1, -1)
	world.auto_range = float(ui.auto_panel.cfg["radius"]) if (auto_mode or ui.auto_panel.visible) else 0.0
	ws.poll()
	clock_acc += dt
	if clock_acc >= 1.0:
		clock_acc = 0.0
		var d = Time.get_datetime_dict_from_system()
		ui.set_clock("%02d:%02d" % [d["hour"], d["minute"]])
	var state = ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not connected:
			connected = true
			connecting = false
			ui.set_online(true)
			ui.add_log("server", "Connected!")
		while not pending_out.is_empty():
			ws.send_text(JSON.stringify(pending_out.pop_front()))
		while ws.get_available_packet_count() > 0:
			var msg = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			if msg is Dictionary:
				_handle(msg)
	elif state == WebSocketPeer.STATE_CLOSED:
		if connected:
			connected = false
			ui.set_online(false)
			ui.add_log("server", "[i]Mất kết nối với máy chủ.[/i]")
			pending_out.clear()
			login_screen.show_login("Mất kết nối với máy chủ.")
		elif connecting:
			connecting = false   # mở kết nối thất bại
			pending_out.clear()
			login_screen.show_login("Không kết nối được máy chủ (%s)." % server_url)
		elif not pending_out.is_empty():
			_connect()           # đang chờ gửi gói sau khi đóng kết nối cũ

# ---------- exp (port player.cpp:4207) ----------

static func exp_for_level(lv: int) -> int:
	return (((lv - 6) * lv + 17) * lv - 12) / 6 * 100

static func exp_percent(exp: int, lv: int) -> float:
	var cur = exp_for_level(lv)
	var nxt = exp_for_level(lv + 1)
	if nxt <= cur:
		return 0.0
	return clampf(float(exp - cur) / float(nxt - cur) * 100.0, 0.0, 100.0)

static func max_hp_for(lv: int) -> int:
	return 150 + 15 * maxi(0, lv - 8)

# ---------- network ----------

func _send(msg: Dictionary):
	if connected:
		ws.send_text(JSON.stringify(msg))

func _handle(msg: Dictionary):
	if msg.get("names") is Dictionary:
		TibiaUI.merge_names(msg["names"])  # tên item từ server, nạp trước khi vẽ túi/đồ mặc/loot
	match msg.get("op", ""):
		"register_ok":
			if auto_login.size() == 2:   # tài khoản vừa tạo -> đăng nhập luôn
				_queue({"op": "login", "account": auto_login[0], "password": auto_login[1]})
				auto_login = []
		"login_err":
			auto_login = []
			login_screen.show_error(str(msg.get("text", "Đăng nhập thất bại.")))
		"char_err":
			login_screen.show_error(str(msg.get("text", "Lỗi.")))
		"chars":
			login_screen.show_chars(int(msg.get("slots", 5)), msg.get("chars", []))
		"hello":
			login_screen.hide_screen()
			var new_id = str(msg["id"])
			# xóa marker demo "local" + các player cũ (tránh ma xanh đứng yên,
			# server sẽ gửi lại spawn cho player còn online ngay sau hello)
			for pid in tiles.keys():
				if kinds.get(pid) == "player":
					_remove(pid)
			player_id = new_id
			my_name = str(msg.get("name", new_id))
			ui.party_panel.my_id = new_id
			ui.party_panel.invites.clear()
			ui.set_party({"id": null, "members": [], "invites": []})   # vào game mới: chưa ở party
			my_voc = int(msg.get("vocation", 4))
			world.vocations[new_id] = my_voc   # animation theo vocation (VocSprite.SPECS)
			target = ""
			stats = {"level": msg.get("level", 8), "exp": msg.get("exp", 0), "hp": msg.get("hp", 150),
				"max_hp": msg.get("max_hp", max_hp_for(int(msg.get("level", 8))))}
			_place(player_id, Vector2i(int(msg.get("x", 100)), int(msg.get("y", 100))), "player")
			ui.has_premium = bool(msg.get("premium", false))
			_push_stats()
			_push_top()
			_push_status(msg)
			ui.set_mana(int(msg.get("mana", 0)), int(msg.get("max_mana", 1)))
			ui.set_skills(msg.get("skills", {}), msg.get("skill_pct", {}),
				int(msg.get("maglevel", 0)), float(msg.get("mag_pct", 0.0)))
			ui.set_equip(msg.get("equip", {}))
			ui.set_fight(str(msg.get("fight", "attack")))
			ui.set_chase(bool(msg.get("chase", true)))
			ui.add_log("server", "You are " + player_id)
			ui.set_conditions([])
			auto_mode = false
			auto_origin = Vector2i(-1, -1)
			if msg.get("auto") is Dictionary:
				ui.set_auto_info(msg["auto"])   # potion, giới hạn, cấu hình Auto đã lưu
			ui.apply_auto_state({"on": false})
		"chase":
			ui.set_chase(bool(msg.get("on", true)))
		"auto_target":
			# server (Auto) tự chọn/bỏ target: cập nhật thanh target + viền chọn, KHÔNG gửi lại lệnh attack
			target = str(msg.get("id", ""))
			_push_world()
			_push_battle()
			_push_target()
		"auto_state":
			var on_now := bool(msg.get("on", false))
			if on_now != auto_mode:
				ui.add_log("server", "[i]AUTO %s.[/i]" % ("BẬT" if on_now else "TẮT"))
			auto_mode = on_now
			var ao = msg.get("origin")
			auto_origin = Vector2i(int(ao[0]), int(ao[1])) if (ao is Array and ao.size() >= 2) else Vector2i(-1, -1)
			ui.apply_auto_state(msg)
		"spawn":
			world.set_invisible(str(msg["id"]), bool(msg.get("invisible", false)))
			if msg.has("vocation"):
				world.vocations[str(msg["id"])] = int(msg["vocation"])   # net.pub gửi vocation cho người chơi khác (14/10/2026)
			_place(str(msg["id"]), Vector2i(int(msg["x"]), int(msg["y"])),
				str(msg.get("kind", "player")), str(msg.get("name", "")),
				int(msg.get("hp", 1)), int(msg.get("max_hp", 1)))
			world.sleeping[str(msg["id"])] = bool(msg.get("sleeping", false))   # người đang ngủ trên giường (server beds.py)
			if msg.has("party"):
				world.party_of[str(msg["id"])] = int(msg["party"])               # cờ party (server party.py)
				world.party_leader[str(msg["id"])] = bool(msg.get("party_leader", false))
			else:
				world.party_of.erase(str(msg["id"]))
				world.party_leader.erase(str(msg["id"]))
			if str(msg.get("kind", "")) == "npc":
				world.set_look(str(msg["id"]), NPC_COLORS.get(str(msg.get("name", "")), [0.6, 0.6, 0.7]), null)
				world.npc_types[str(msg["id"])] = str(msg.get("npc_type", ""))   # "depot" -> WorldView vẽ rương
			if msg.has("color") or msg.has("size"):  # tùy chọn (PROTOCOL §Làn D, đề xuất cho làn B)
				world.set_look(str(msg["id"]), msg.get("color", null), msg.get("size", null))
		"sleep":
			# người chơi lên/xuống giường (server beds.py): vẽ Zzz; chính mình ngủ thì nhắc cách thức dậy
			var sid := str(msg.get("id", ""))
			var son := bool(msg.get("on", false))
			world.sleeping[sid] = son
			world.queue_redraw()
			if sid == player_id:
				ui.add_log("server", "Bạn đang ngủ: hồi HP/mana nhanh, cộng Soul. Bấm di chuyển để thức dậy." if son else "Bạn đã thức dậy.")
		"invisible":
			# condition tàng hình (utana vid, chiêu `invisible` của quái): ẩn/hiện sprite + bỏ/khôi phục khỏi Battle
			world.set_invisible(str(msg.get("id", "")), bool(msg.get("on", false)))
			_push_battle()
		"move", "creature_move":
			_move_mark(str(msg["id"]), Vector2i(int(msg["x"]), int(msg["y"])))
		"say":
			ui.add_log("local", "[color=#5fb0ff]%s:[/color] %s" % [msg.get("name", msg.get("id", "?")), _esc(str(msg.get("text", "")))])
		"party":
			party_state = msg
			ui.set_party(msg)
		"party_invite":
			ui.party_panel.add_invite(int(msg.get("party", 0)), str(msg.get("from", "?")), int(msg.get("ttl", 120)))
			ui.add_log("server", "[color=#ffd060]%s mời bạn vào party. Gõ /p accept để vào, /p decline để từ chối (hết hạn sau %d giây).[/color]" % [_esc(str(msg.get("from", "?"))), int(msg.get("ttl", 0))])
		"party_invite_end":
			ui.party_panel.end_invite(int(msg.get("party", 0)))
		"party_say":
			ui.add_log("local", "[color=#7fe08a][Party] %s:[/color] %s" % [_esc(str(msg.get("from", "?"))), _esc(str(msg.get("text", "")))])
		"effect":
			var eid = str(msg.get("id", "?"))
			var dmg = int(msg.get("dmg", 0))
			var ek = str(msg.get("kind", "hit"))
			if ek == "death":
				world.mark_dead(eid)   # animation nằm gục
				# chỉ báo chết, không có số sát thương (server đã gửi `move` về đền + `stats` ngay sau)
				if eid == player_id:
					ui.add_log("server", "[color=red]You are dead.[/color]")
					_show_death()
			elif ek == "mana":
				# mana shield nuốt sát thương: số xanh, không nháy trắng (A5)
				if tiles.has(eid):
					_float_dmg(eid, dmg, "mana")
			else:
				ui.add_log("server", "%s %s dmg=%s" % [ek, eid, dmg])
				if tiles.has(eid):
					world.hit(eid)
					_float_dmg(eid, dmg, ek)
					var src = str(msg.get("from", ""))
					if src != "" and tiles.has(src) and src != eid and ek == "hit":
						world.swing(src, tiles[eid])   # animation đánh thường
						world.basic_shot(tiles[src], tiles[eid], int(world.vocations.get(src, 0)))  # đạn đánh thường xa (Druid đá / Sorc sét / Paladin tên)
		"fx":
			# hiệu ứng spell/đạn (làn F): tiles = ô bị ảnh hưởng, ani = đạn bay từ `from`
			var fid = str(msg.get("id", ""))
			if tiles.has(fid):
				world.cast(fid)   # animation thi pháp
			var fr = msg.get("from", [])
			if fr is Array and fr.size() >= 2:
				world.add_fx(Vector2i(int(fr[0]), int(fr[1])), msg.get("tiles", []),
					msg.has("ani"), msg.has("me") or not msg.has("ani"), _fx_color(msg))
		"aim":
			# rune vùng/field/tường cần ô đất: vào chế độ ngắm, click trái chọn ô (use_on), chuột phải / ESC hủy
			aim_item = int(msg.get("item", 0))
			world.aim_active = aim_item != 0
			ui.add_log("server", "Chọn ô để dùng rune (chuột phải hoặc ESC để hủy).")
			world.queue_redraw()
		"fields":
			world.set_fields(msg.get("list", []))
		"field":
			world.set_field(int(msg.get("x", 0)), int(msg.get("y", 0)), str(msg.get("kind", "")), bool(msg.get("blocking", false)))
		"field_rm":
			world.remove_field(int(msg.get("x", 0)), int(msg.get("y", 0)))
		"area_fx":
			# B4/A6: hiệu ứng CONST_ME_* trên từng ô của vùng (chiêu quái, rune, spell vùng). Khối màu tạm theo tên hằng.
			var acol = _const_fx_color(str(msg.get("effect", "")))
			if acol.a > 0.0:
				world.add_area_fx(msg.get("tiles", []), acol)
		"shoot_fx":
			# đạn bay CONST_ANI_* từ `from` tới `to` (2 ô [x,y]); khối tròn nhỏ + vệt, màu theo tên hằng.
			var sa = msg.get("from", [])
			var sb = msg.get("to", [])
			if sa is Array and sb is Array and sa.size() >= 2 and sb.size() >= 2:
				world.add_shoot_fx(Vector2i(int(sa[0]), int(sa[1])), Vector2i(int(sb[0]), int(sb[1])),
					_const_fx_color(str(msg.get("effect", ""))))
		"conditions":
			if str(msg.get("id", player_id)) == player_id:
				ui.set_conditions(msg.get("list", []))
		"stats":
			if str(msg.get("id", player_id)) == player_id:
				stats = {"level": msg.get("level", 0), "exp": msg.get("exp", 0), "hp": msg.get("hp", 0),
					"max_hp": msg.get("max_hp", stats.get("max_hp", max_hp_for(int(msg.get("level", 8)))))}
				_push_stats()
				_push_top()
				if msg.has("mana"):
					ui.set_mana(int(msg["mana"]), int(msg.get("max_mana", 1)))
					_push_status(msg)
				if msg.has("skills"):
					ui.set_skills(msg["skills"], msg.get("skill_pct", {}),
						int(msg.get("maglevel", 0)), float(msg.get("mag_pct", 0.0)))
				if msg.has("speed"):
					my_speed = int(msg["speed"])
					_push_status(msg)
				if msg.has("stamina"):
					ui.set_stamina(int(msg["stamina"]))
				if msg.has("soul"):
					ui.set_soul_cap(int(msg["soul"]), int(msg.get("max_soul", 100)),
						float(msg.get("free_cap", 0.0)), float(msg.get("cap", 0.0)))
				if msg.has("gold"):
					ui.set_money(int(msg["gold"]), int(msg.get("bank", 0)))   # Gold / Bank trong panel Character
		"who":
			ui.refresh_vip(msg.get("players", []))
		"fight":
			ui.set_fight(str(msg.get("mode", "attack")))
		"map":
			world.clear_fields()
			_cancel_aim()
			map_id = str(msg.get("id", "city"))
			map_name = str(msg.get("name", map_id))
			var rec = msg.get("rec", [])
			if rec is Array and rec.size() == 2:
				map_name += "  Lv %d-%d" % [int(rec[0]), int(rec[1])]   # mức level khuyến nghị hiện cạnh tên map
			if world_map_panel.visible:
				_send({"op": "world_map"})   # đang mở sơ đồ: làm mới (vừa khám phá map mới)
			world.map_theme = str(msg.get("theme", "grass"))   # giao diện map (set_map sinh decor theo theme)
			world.set_map_size(map_id, int(msg.get("w", 0)), int(msg.get("h", 0)))   # nền/tường/decor theo kích thước map
			world.set_map(msg.get("walls", []), msg.get("gates", []),
				msg.get("bg", [0.16, 0.28, 0.16]),
				Vector2i(int(msg.get("temple", [20, 20])[0]), int(msg.get("temple", [20, 20])[1])))
			world.my_name = my_name
			world.sleeping.clear()
			world.set_houses(msg.get("houses", []))   # nhà của map (Bước 3A gửi, 3D vẽ)
			house_panel.hide_panel()
			for pid in tiles.keys():
				if pid != player_id:
					_remove(pid)
			target = ""
			pending_npc = ""
			npc_panel.hide_shop()
			world.anchor = tiles.get(player_id, Vector2i(20, 20))
			_push_world()
			_push_battle()
			_push_target()
			_push_minimap()
			_push_status(msg)
		"spells":
			ui.has_premium = bool(msg.get("premium", ui.has_premium))
			spell_info = {}
			for sp in msg.get("spells", []):
				spell_info[str(sp.get("id", ""))] = sp
			ui.refresh_spells(msg.get("spells", []), my_voc)
		"backpack":
			backpack = {}
			for k in msg.get("items", {}):
				var e = msg["items"][k]
				backpack[int(k)] = {"n": int(e["n"]), "cat": str(e.get("cat", "others"))}
			ui.refresh_backpack(backpack)
		"equip":
			ui.set_equip(msg.get("slots", {}), msg.get("counts", {}))
		"npc_shop":
			depot_panel.hide_panel()
			house_panel.hide_panel()
			npc_panel.show_shop(msg)
		"depot_pub":
			npc_panel.hide_shop()
			house_panel.hide_panel()
			depot_panel.show_panel(msg)
		"house_pub":
			npc_panel.hide_shop()
			depot_panel.hide_panel()
			world.my_name = my_name
			world.update_houses(msg.get("houses", []))   # mua/trả nhà xong: bảng hiệu + cửa trên map đổi theo
			house_panel.show_panel(msg)
		"world_map":
			world_map_panel.set_data(msg)
		"npc_close":
			npc_panel.hide_shop()
			depot_panel.hide_panel()
			house_panel.hide_panel()
		"msg":
			ui.add_log("server", _esc(str(msg.get("text", ""))))
		"creature_hp":
			var cid = str(msg["id"])
			if hps.has(cid):
				hps[cid][0] = int(msg["hp"])
				_push_world()
				if cid == target:
					_push_target()
		"creature_dead":
			ui.add_log("server", "%s died." % _cname(str(msg["id"])))
			if target == str(msg["id"]):
				target = ""
			_remove(str(msg["id"]))
		"loot":
			var parts := []
			for it in msg.get("items", []):
				parts.append("%dx %s" % [it[1], TibiaUI.name_of(int(it[0]))])
			ui.refresh_backpack(backpack)
			ui.add_log("server", "[color=yellow]Loot:[/color] " + ", ".join(parts))
		"leave":
			if target == str(msg.get("id", "")):
				target = ""
			_remove(str(msg.get("id", "")))

# Màu hiệu ứng ma thuật (CONST_ME_* chưa có sprite nên tô khối màu tạm): fx do CHÍNH MÌNH vừa cast (<=1.5s)
# thì theo element spell (trường `element` trong gói spells); còn lại giữ màu cam mặc định.
func _fx_color(msg: Dictionary) -> Color:
	var base := Color(1.0, 0.55, 0.15)
	if str(msg.get("id", "")) != player_id:
		return base
	if Time.get_ticks_msec() / 1000.0 - last_cast_t > 1.5:
		return base
	match last_cast_element:
		"COMBAT_FIREDAMAGE": return Color(1.0, 0.45, 0.1)
		"COMBAT_ICEDAMAGE": return Color(0.45, 0.8, 1.0)
		"COMBAT_ENERGYDAMAGE": return Color(0.7, 0.45, 1.0)
		"COMBAT_EARTHDAMAGE": return Color(0.35, 0.8, 0.3)
		"COMBAT_HOLYDAMAGE": return Color(1.0, 0.95, 0.55)
		"COMBAT_DEATHDAMAGE": return Color(0.4, 0.3, 0.45)
		"COMBAT_HEALING": return Color(0.4, 1.0, 0.5)
		"COMBAT_PHYSICALDAMAGE": return Color(0.85, 0.85, 0.85)
	return base

# Màu tạm cho CONST_ME_* / CONST_ANI_* của `area_fx` / `shoot_fx` (chưa có sprite): đoán theo từ khoá trong tên hằng.
# Trả Color alpha 0 = không vẽ (CONST_ME_NONE / rỗng). Tên lạ -> cam mặc định để vẫn thấy được hiệu ứng.
func _const_fx_color(effect: String) -> Color:
	var e := effect.to_upper()
	if e == "" or e.ends_with("_NONE"):
		return Color(0, 0, 0, 0)
	for kv in FX_KEYWORD_COLORS:
		for kw in kv[0]:
			if e.contains(kw):
				return kv[1]
	return Color(1.0, 0.55, 0.15)

const FX_KEYWORD_COLORS := [
	[["ICE", "SNOW", "FREEZ", "FROST"], Color(0.45, 0.8, 1.0)],
	[["ENERGY", "ELECTRIC", "PURPLE", "PINK", "VIOLET"], Color(0.7, 0.45, 1.0)],
	[["POISON", "EARTH", "GREEN", "PLANT", "LEAF", "SLIME", "ACID"], Color(0.35, 0.8, 0.3)],
	[["HOLY", "YELLOW", "GOLD", "LIGHT"], Color(1.0, 0.95, 0.55)],
	[["MORT", "DEATH", "BLACK", "DARK", "SHADOW", "CURSE", "DRAIN"], Color(0.4, 0.3, 0.45)],
	[["BLOOD", "RED", "BLEED"], Color(0.9, 0.15, 0.15)],
	[["BLUE", "WATER", "MANA", "TELEPORT"], Color(0.35, 0.6, 1.0)],
	[["FIRE", "FLAM", "EXPLOSION", "BURN", "LAVA", "BOMB"], Color(1.0, 0.45, 0.1)],
	[["SPEAR", "ARROW", "BOLT", "STONE", "THROWINGKNIFE", "THROWINGSTAR", "SMALLSTONE", "WHIRLWIND"], Color(0.85, 0.85, 0.85)],
]

func _float_dmg(pid: String, dmg: int, kind := "hit"):
	var lab = Label.new()
	lab.text = "+%d" % dmg if kind == "heal" else str(dmg)
	lab.add_theme_font_size_override("font_size", 14)
	if kind == "heal":
		lab.add_theme_color_override("font_color", Color(0.3, 1, 0.4))
	elif kind == "mana":
		lab.add_theme_color_override("font_color", Color(0.35, 0.6, 1))
	else:
		lab.add_theme_color_override("font_color", Color(1, 0.3, 0.2) if pid == player_id else Color(1, 0.9, 0.2))
	lab.position = world.tile_to_screen(tiles[pid]) + Vector2(4, -14)
	add_child(lab)
	var tw = create_tween().set_parallel()
	tw.tween_property(lab, "position:y", lab.position.y - 18.0, 0.7)
	tw.tween_property(lab, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(lab.queue_free)

func _show_death():
	# màn hình chết tối giản: chữ giữa màn hình ~2.5s (server đã đưa player về đền)
	if death_label == null:
		death_label = Label.new()
		death_label.text = "You are dead."
		death_label.add_theme_font_size_override("font_size", 32)
		death_label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
		death_label.add_theme_color_override("font_outline_color", Color.BLACK)
		death_label.add_theme_constant_override("outline_size", 6)
		death_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(death_label)
		death_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		death_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	death_label.modulate.a = 1.0
	death_label.show()
	var tw = create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(death_label, "modulate:a", 0.0, 1.0)

func _esc(s: String) -> String:
	return s.replace("[", "(").replace("]", ")").left(200)

func _cname(cid: String) -> String:
	return str(names.get(cid, cid))

# ---------- actions (nối nút UI + phím) ----------

## Chuột có đang nằm trong một vùng UI (group "ui_block": panel đang hiện) không.
func _over_ui(pos: Vector2) -> bool:
	for n in get_tree().get_nodes_in_group("ui_block"):
		var c := n as Control
		if c != null and c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false

## Đăng ký các panel/thanh không dựng bằng UiKit.panel()/TibiaUI._panel() vào group "ui_block".
func _register_ui_blockers() -> void:
	for c in [npc_panel, depot_panel, house_panel, world_map_panel, ui.spell_panel, ui.auto_panel, ui.hotbar, ui.hotbar.picker, ui.minimap, ui.vitals]:
		if c != null:
			UiKit.block_world(c)

func _unhandled_input(e):
	if e is InputEventKey and get_viewport().gui_get_focus_owner() is LineEdit:
		return  # đang gõ chat: chỉ chặn phím, chuột vẫn dùng được
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode >= KEY_F1 and e.keycode <= KEY_F12:
			ui.hotbar.activate(e.keycode - KEY_F1)  # hotbar F1..F12 như hotkey Tibia gốc
			return
		match e.keycode:
			KEY_W, KEY_UP: _do_move(0, -1)
			KEY_S, KEY_DOWN: _do_move(0, 1)
			KEY_A, KEY_LEFT: _do_move(-1, 0)
			KEY_D, KEY_RIGHT: _do_move(1, 0)
			KEY_ESCAPE: _cancel_aim()
			KEY_T: ui.auto_btn.button_pressed = not ui.auto_btn.button_pressed
			KEY_Y: ui.toggle_auto_panel()
			KEY_F: ui.chase_btn.button_pressed = not ui.chase_btn.button_pressed   # bật/tắt đuổi theo
			KEY_C: ui.toggle_char()
			KEY_M: world_map_panel.toggle()
			KEY_K: ui.toggle_popup("skills")
			KEY_B: ui.toggle_popup("battle")
			KEY_U: ui.toggle_popup("status")
			KEY_V:
				ui.toggle_popup("vip")
				_send({"op": "who"})
			KEY_E: _send({"op": "add_exp", "exp": 500})
	elif e is InputEventMouseButton and e.pressed:
		get_viewport().gui_release_focus()
		if e.position.x >= world.full_size.x or e.position.y >= world.full_size.y:
			return
		if _over_ui(e.position):
			return   # chuột đang ở trên một panel/thanh UI: cuộn/click KHÔNG tác động bản đồ (hết lỗi zoom khi cuộn list)
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			world.zoom_step(1)   # cuộn lên: phóng to (x1 -> x2 -> x3)
			return
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			world.zoom_step(-1)  # cuộn xuống: thu nhỏ
			return
		if aim_item != 0:
			if e.button_index == MOUSE_BUTTON_LEFT:
				var aim_t := world.screen_to_tile(e.position)
				_send({"op": "use_on", "item": aim_item, "x": aim_t.x, "y": aim_t.y})
			if e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_aim()
				return
		if e.button_index == MOUSE_BUTTON_LEFT:
			var cid = world.entity_at(e.position)
			if cid != "" and kinds.get(cid) == "npc":
				_click_npc(cid)  # NPC: mở panel Mua/Bán
			elif cid != "":
				set_target(cid)  # chọn target
			else:
				var t = world.screen_to_tile(e.position)
				if world.map_w > 0 and (t.x < 0 or t.y < 0 or t.x >= world.map_w or t.y >= world.map_h):
					return   # click ra ngoài map (nước/viền): bỏ qua, không gửi goto
				_manual_override()
				world.dest = t
				_send({"op": "goto", "x": t.x, "y": t.y})  # đi tới ô click
				ui.add_log("server", "Đi tới (%d, %d)" % [t.x, t.y])
				world.queue_redraw()
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			var cid2 = world.entity_at(e.position)
			if cid2 != "" and kinds.get(cid2) == "creature":
				set_target(cid2)  # chọn là tự dí + đánh (gửi trong set_target)
			elif cid2 != "" and kinds.get(cid2) == "player" and cid2 != player_id:
				_player_menu(cid2, e.position)   # người chơi khác: menu Mời vào Party
			else:
				_right_click_bed(world.screen_to_tile(e.position))

## Chuột phải giường: đứng cạnh (<= 1 ô) thì ngủ (server kiểm quyền chủ/khách + mọi điều kiện), còn xa thì đi tới giường trước.
func _player_menu(cid: String, pos: Vector2) -> void:
	ctx_target = cid
	ctx_menu.clear()
	ctx_menu.add_item("Mời %s vào Party" % str(names.get(cid, cid)), 0)
	ctx_menu.popup(Rect2i(Vector2i(pos), Vector2i.ZERO))

func _right_click_bed(t: Vector2i) -> void:
	var bh: Dictionary = world.bed_house_at(t)
	if bh.is_empty():
		return
	var me: Vector2i = tiles.get(player_id, Vector2i(0, 0))
	if maxi(absi(t.x - me.x), absi(t.y - me.y)) <= 1:
		_send({"op": "bed_sleep", "x": t.x, "y": t.y})
		return
	_manual_override()
	world.dest = t
	_send({"op": "goto", "x": t.x, "y": t.y})
	ui.add_log("server", "Đi tới giường... chuột phải giường lần nữa để ngủ.")
	world.queue_redraw()

func _cancel_aim() -> void:
	aim_item = 0
	world.aim_active = false
	world.queue_redraw()

func _click_npc(cid: String):
	var me: Vector2i = tiles.get(player_id, Vector2i(0, 0))
	var t: Vector2i = tiles.get(cid, me)
	if maxi(absi(t.x - me.x), absi(t.y - me.y)) <= NPC_RANGE:
		pending_npc = ""
		_send({"op": "npc_open", "id": cid})
		return
	pending_npc = cid   # còn xa: đi tới gần, tới nơi _npc_check sẽ tự mở
	_manual_override()
	var dest: Vector2i = t + Vector2i(signi(me.x - t.x), signi(me.y - t.y)) * 2
	world.dest = dest
	_send({"op": "goto", "x": dest.x, "y": dest.y})
	ui.add_log("server", "Đi tới %s..." % _cname(cid))
	world.queue_redraw()

## Gọi mỗi khi nhân vật mình đổi ô: tới gần NPC đã click thì mở shop; đi xa NPC đang mở thì đóng panel.
func _npc_check():
	var me: Vector2i = tiles.get(player_id, Vector2i(0, 0))
	if pending_npc != "" and tiles.has(pending_npc):
		var t: Vector2i = tiles[pending_npc]
		if maxi(absi(t.x - me.x), absi(t.y - me.y)) <= NPC_RANGE:
			var nid := pending_npc
			pending_npc = ""
			_send({"op": "npc_open", "id": nid})
	if npc_panel.visible and tiles.has(npc_panel.npc_id):
		var t2: Vector2i = tiles[npc_panel.npc_id]
		if maxi(absi(t2.x - me.x), absi(t2.y - me.y)) > NPC_RANGE:
			npc_panel.hide_shop()
	if depot_panel.visible and tiles.has(depot_panel.npc_id):
		var t3: Vector2i = tiles[depot_panel.npc_id]
		if maxi(absi(t3.x - me.x), absi(t3.y - me.y)) > NPC_RANGE:
			depot_panel.hide_panel()
	if house_panel.visible and tiles.has(house_panel.npc_id):
		var t4: Vector2i = tiles[house_panel.npc_id]
		if maxi(absi(t4.x - me.x), absi(t4.y - me.y)) > NPC_RANGE:
			house_panel.hide_panel()

## Người chơi tự đi (WASD / click đất / click NPC) thì tắt Auto để không giằng co với lệnh đi của Auto.
func _manual_override():
	if auto_mode and connected:
		_send({"op": "auto", "on": false})

func _do_move(dx: int, dy: int):
	_manual_override()
	pending_npc = ""
	_send({"op": "move", "dx": dx, "dy": dy})
	if not connected:
		_move_mark(player_id, tiles.get(player_id, Vector2i(100, 100)) + Vector2i(dx, dy))

func set_target(cid: String):
	target = cid
	ui.add_log("server", "Attacking " + _cname(cid) + " ...")
	if connected and kinds.get(cid) == "creature":
		_send({"op": "attack", "target": cid, "auto": true})  # chọn là đánh luôn
	_push_world()
	_push_battle()
	_push_target()

## Bật/tắt Auto: logic chạy ở server (tibia_py/auto.py); trạng thái thật về qua gói auto_state.
func _on_auto(on: bool):
	if not connected:
		ui.add_log("server", "[i]Auto cần kết nối server.[/i]")
		ui.apply_auto_state({"on": false})
		return
	_send({"op": "auto", "on": on})

func _push_target():
	if target != "" and tiles.has(target):
		ui.set_target_bar(_cname(target), int(hps.get(target, [0, 1])[0]),
			int(hps.get(target, [0, 1])[1]) if hps.has(target) else 1)
	else:
		ui.set_target_bar("", 0, 1)

func _on_centre():
	world.follow = true
	world.anchor = tiles.get(player_id, Vector2i(100, 100))
	world.queue_redraw()
	_push_minimap()

func _on_vip():
	_send({"op": "who"})

func _on_logout():
	# thoát game: server lưu nhân vật khi ngắt kết nối; quay về màn đăng nhập (đăng nhập lại nếu muốn chơi tiếp)
	pending_out.clear()
	if connected:
		ws.close()
		connected = false
		ui.set_online(false)
		ui.add_log("server", "[i]Đã đăng xuất.[/i]")
	login_screen.show_login()

func _on_cast_spell(sid: String):
	var info: Dictionary = spell_info.get(sid, {})
	last_cast_element = str(info.get("element", ""))
	last_cast_t = Time.get_ticks_msec() / 1000.0
	world.cast(player_id)   # animation thi pháp (không chờ server)
	_send({"op": "cast", "spell": sid, "target": target})
	if not connected:
		ui.add_log("server", "[i]Offline: không cast được.[/i]")

func _on_chat(text: String):
	var t = text.strip_edges()
	ui.chat_input.release_focus()
	if t == "":
		return
	if t.begins_with("/"):
		_send({"op": "party_cmd", "text": t})   # lệnh chat tạm (/party invite <tên>...) cho tới khi có Panel Party
		return
	_send({"op": "say", "text": t})
	if not connected:
		ui.add_log("local", "[color=#5fb0ff]%s:[/color] %s" % [player_id, _esc(t)])

# ---------- state -> view ----------

func _place(pid: String, t: Vector2i, kind: String, pname := "", hp := 1, max_hp := 1):
	tiles[pid] = t
	kinds[pid] = kind
	if pname != "":
		names[pid] = pname
	if kind == "creature":
		hps[pid] = [hp, max_hp]
	if pid == player_id and world.follow:
		world.anchor = t
	_push_world()
	_push_battle()
	_push_minimap()

func _move_mark(pid: String, t: Vector2i):
	if not tiles.has(pid):
		_place(pid, t, kinds.get(pid, "player"))
		return
	tiles[pid] = t
	if pid == player_id:
		if world.follow:
			world.anchor = t  # camera bám theo
		if world.dest == t:
			world.dest = Vector2i(-1, -1)  # tới nơi
		_npc_check()
	_push_world()
	_push_minimap()

func _remove(pid: String):
	world.looks.erase(pid)
	world.forget(pid)
	tiles.erase(pid)
	kinds.erase(pid)
	names.erase(pid)
	hps.erase(pid)
	_push_world()
	_push_battle()
	_push_minimap()
	if pid == target:
		_push_target()

func _push_top():
	_push_target()

func _push_status(msg := {}):
	var no = int(msg.get("regen_s", 0))
	ui.set_identity(my_name, int(stats.get("level", 0)), str(VOC_NAMES.get(my_voc, "")))
	ui.set_map_name(map_name)  # tên map đặt dưới minimap (thay nút Centre)
	ui.set_status([
		"Speed: %d" % my_speed,
		"EXP %d" % int(stats.get("exp", 0)),
		"No: %d:%02d (ăn food để nạp)" % [no / 60, no % 60],
	])

func _push_world():
	world.set_data(tiles, kinds, names, hps, player_id)
	world.target = target
	world.queue_redraw()
	_push_minimap()

func _push_minimap():
	world_map_panel.set_hero(map_id, tiles.get(player_id, Vector2i.ZERO), int(stats.get("level", 1)))
	ui.minimap.refresh(tiles, kinds, world.anchor, world.walls, player_id, world.gates)

func _push_battle():
	var list := []
	var me: Vector2i = tiles.get(player_id, Vector2i(100, 100))
	for pid in tiles:
		if kinds.get(pid) == "creature" and not world.invisible.get(pid, false):
			var t: Vector2i = tiles[pid]
			list.append({"id": pid, "name": names.get(pid, pid), "hp": hps.get(pid, [0])[0],
				"d": maxi(absi(t.x - me.x), absi(t.y - me.y))})
	list.sort_custom(func(a, b): return a["d"] < b["d"])  # gần nhất lên đầu
	ui.refresh_battle(list, target)

func _push_stats():
	ui.set_hp(int(stats.get("hp", 0)), int(stats.get("max_hp", max_hp_for(int(stats.get("level", 8))))))
	ui.set_exp(int(stats["exp"]), int(stats["level"]), exp_percent(int(stats["exp"]), int(stats["level"])))
