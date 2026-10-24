class_name WorldView
extends Node2D
## Vẽ thế giới: lưới, tường demo, actors procedural (hero/quái) + flash khi trúng đòn.
## Tọa độ tuyệt đối neo ở anchor (follow player), W = lên trên (y-1) giống Tibia.
## Khi có sprite thật (Tibia.spr -> PNG): thay _draw_creature_placeholder bằng AnimatedSprite2D,
## dùng sprite_ids từ tibia_py.items.load_sprites() (lookType Rat=21, Rotworm=26...).
## D2: quái là KHỐI MÀU TẠM suy ra từ thông số (max_hp), không còn vẽ riêng theo tên quái.

const TILE := 32.0   # 1 ô = 32px (asset 64px vẽ tỉ lệ 0.5; sprite hero cao ≈ 1 ô)
const GRID_R := 13
const TREE_FADE_ALPHA := 0.45   # độ mờ của cây khi có nhân vật/quái đứng dưới tán
const DROP_TILES := 2.0   # hero đứng thấp hơn tâm màn hình 2 ô (cân đối hơn, thấy nhiều phía trên hơn)
const ZOOM_LEVELS := [1.0, 2.0, 3.0]   # nấc phóng to (cuộn chuột đổi nấc)

var tiles := {}    # id -> Vector2i
var kinds := {}    # id -> String
var names := {}    # id -> String
var hps := {}      # id -> [hp, max_hp]
var anchor := Vector2i(20, 20)
var follow := true  # camera bám theo player
var target := ""
var dest := Vector2i(-1, -1)  # điểm đến của goto (vẽ dấu X)
var player_id := "local"
var walls: Array = []
var gates: Array = []  # [{x, y}] cổng warp
var bg := Color(0.16, 0.28, 0.16)
var full_size := Vector2(1280, 720)   # TOÀN màn hình: vùng vẽ + vùng nhận click (Main._layout gán). view_size chỉ để canh tâm camera
var view_size := Vector2(1048, 552)  # vùng game = cửa sổ - sidebar - chat

var zoom := 1.0           # hệ số phóng to hiện tại (một trong ZOOM_LEVELS)
var zoom_idx := 0
var _in_draw := false     # đang trong _draw (đã áp transform zoom) -> tile_to_screen trả tọa độ chưa zoom
var map_id := ""
var map_theme := "grass"       # giao diện map (MapArt.theme_def): grass / mine / hell / desert
var map_w := 0
var map_h := 0
var wall_set := {}          # Vector2i -> true (tra cứu nhanh khi vẽ tường đá)
var decor: Array = []       # MapArt.gen_decor: cây + props (chỉ hình, không va chạm)
var tree_alpha := {}        # index cây -> alpha hiện tại (mờ dần mượt)
var _dt := 0.016
var anim := 0.0
var moved_at := {}  # pid -> anim time lúc đổi ô (đi bộ thì quẫy chân)
var flash := {}     # pid -> tới khi nào còn trắng (trúng đòn)
var slashes: Array = []  # {a, b, until} gạch chém giữa 2 ô
var map_fields: Dictionary = {}   # Vector2i -> {kind, blocking}: field/tường trên map (gói fields/field/field_rm, làn F8)
var aim_active := false           # đang ngắm rune lên ô đất (server gửi `aim`): vẽ ô dưới con trỏ
var fx_cells: Array = []    # {cells: Array[Vector2i], t0, until, color} hiệu ứng ma thuật trên ô (gói fx.tiles)
var fx_shots: Array = []    # {a, b, t0, until, color} đạn bay (gói fx.ani)
var npc_types := {}         # id NPC -> npc_type ("spell"/"shop"/"teleport"/"depot"/"house"); "depot" vẽ rương, "house" vẽ ngôi nhà nhỏ (Main điền khi spawn)
var houses: Array = []      # gói `map.houses` (server houses.public + status khi qua house_pub): nhà của map hiện tại, vẽ ở _draw_houses
var party_of := {}           # id người chơi -> id party (spawn.party): vẽ cờ party trên đầu
var party_leader := {}       # id -> true nếu là leader
var sleeping := {}          # id -> true: đang ngủ trên giường (gói `sleep`, spawn.sleeping) -> vẽ Zzz + phủ xanh tối
var my_name := ""           # tên nhân vật mình: so với house.owner để biết nhà của mình (cửa mở)
var looks := {}             # id -> {color: Color, size: float(ô)} — tùy chọn do server gửi (spawn.color / spawn.size)
# --- Animation vocation (VocSprite.gd) ---
var vocations := {}   # pid -> vocation id (1..4 có sprite trong VocSprite.SPECS; Main.gd điền khi hello/spawn)
var facing := {}      # pid -> VocSprite.Dir
var harmony := {}     # pid -> số linh cầu Harmony (Monk, 0..5): vẽ cầu sáng xoay trên đầu
var virtue := {}      # pid -> Virtue đang bật (0 không, 1 Harmony, 2 Justice, 3 Sustain): đổi màu cầu
const ORB_SLOTS := 5
const ORB_COLORS := [Color(1.0, 0.86, 0.38), Color(0.45, 0.82, 1.0), Color(1.0, 0.5, 0.32), Color(0.5, 1.0, 0.58)]
var swing_at := {}    # pid -> anim time bắt đầu đánh thường
var cast_at := {}     # pid -> anim time bắt đầu thi pháp
var dead_until := {}  # pid -> tới khi nào còn nằm gục
var walk_start := {}  # pid -> anim time bắt đầu 1 chuỗi đi liên tục (chu kỳ chân chạy liên tục, không reset mỗi bước)
var invisible := {}   # pid -> true: đang tàng hình (server gửi spawn.invisible / gói invisible). Người khác/quái: không vẽ; chính mình: vẽ kèm nhãn
var auto_origin := Vector2i(-1, -1)   # điểm xuất phát của Auto (server gửi); x<0 = chưa bật -> vẽ thử quanh hero
var auto_range := 0.0   # >0: bán kính (ô) vòng tròn nét đứt quanh hero khi AUTO bật (Main đặt mỗi frame)
var vis := {}         # pid -> vị trí hiển thị (ô, số thực) trượt mượt tới tiles[pid]
var step_dur := {}    # pid -> thời gian 1 bước ước lượng (s), đo từ khoảng cách giữa 2 lần `move`
var cam_off := Vector2.ZERO  # lệch camera (ô) = vis của mình - ô của mình -> cuộn nền mượt
var last_tile := {}   # pid -> ô trước đó (suy ra hướng đi; Main truyền cùng 1 Dictionary nên không so với `tiles` được)

func _process(dt):
	_dt = dt
	anim += dt
	_glide(dt)
	queue_redraw()

## Trượt vis[pid] tới ô thật với vận tốc = 1 ô / step_dur (hơi nhanh hơn 10% để luôn kịp bước kế tiếp).
func _glide(dt: float) -> void:
	for id in tiles:
		var tgt := Vector2(tiles[id])
		if not vis.has(id):
			vis[id] = tgt
			continue
		var cur: Vector2 = vis[id]
		var dist := cur.distance_to(tgt)
		if dist > 2.5:
			vis[id] = tgt   # dịch chuyển xa (warp/respawn): không trượt
		elif dist > 0.0:
			var spd := 1.1 / clampf(float(step_dur.get(id, 0.3)), 0.06, 0.8)   # ô/giây
			if dist > 1.2:
				spd *= dist   # tụt lại sau: đuổi nhanh dần
			vis[id] = cur.move_toward(tgt, spd * dt)
	for id in vis.keys():
		if not tiles.has(id):
			vis.erase(id)
			step_dur.erase(id)
	cam_off = Vector2.ZERO
	if follow and tiles.has(player_id) and vis.has(player_id) and anchor == tiles[player_id]:
		cam_off = vis[player_id] - Vector2(tiles[player_id])

## Vị trí vẽ (góc trái-trên) của 1 thực thể: ô thật + phần trượt.
func actor_screen(pid: String) -> Vector2:
	var z := 1.0 if _in_draw else zoom
	var off: Vector2 = (vis.get(pid, Vector2(tiles[pid])) - Vector2(tiles[pid]))
	return tile_to_screen(tiles[pid]) + off * TILE * z

func set_data(t: Dictionary, k: Dictionary, n: Dictionary, h: Dictionary, pid: String):
	for id in t:
		var cur: Vector2i = t[id]
		if last_tile.has(id) and last_tile[id] != cur:
			var dtm := anim - float(moved_at.get(id, -9.0))
			if dtm < 1.0:
				step_dur[id] = lerpf(float(step_dur.get(id, dtm)), dtm, 0.5)   # làm mượt nhịp bước
			if dtm >= _walk_gap(id):
				walk_start[id] = anim   # chuỗi đi mới (đã đứng yên đủ lâu) -> chu kỳ chân bắt đầu từ khung đầu
			moved_at[id] = anim
			var d: Vector2i = cur - last_tile[id]
			if absi(d.x) <= 1 and absi(d.y) <= 1:
				facing[id] = VocSprite.dir_from_delta(d.x, d.y, facing.get(id, VocSprite.Dir.S))
		last_tile[id] = cur
	for id in last_tile.keys():
		if not t.has(id):
			last_tile.erase(id)
	tiles = t
	kinds = k
	names = n
	hps = h
	player_id = pid

func hit(pid: String):
	flash[pid] = anim + 0.25

## Gói `fx` của server: `tiles` = các ô bị hiệu ứng ma thuật; `ani` + `from` = đạn bay tới ô xa nhất.
## CONST_ME_*/CONST_ANI_* chưa có sprite nên chỉ vẽ khối màu tạm (thông số đúng, hình thay sau).
func add_fx(from_t: Vector2i, cells_in: Array, has_ani: bool, has_me: bool, col := Color(1.0, 0.55, 0.15), defs := {}):
	var cells: Array = []
	for c in cells_in:
		cells.append(Vector2i(int(c[0]), int(c[1])))
	if has_ani and not cells.is_empty():
		var far: Vector2i = cells[0]
		for c in cells:
			if maxi(absi(c.x - from_t.x), absi(c.y - from_t.y)) > maxi(absi(far.x - from_t.x), absi(far.y - from_t.y)):
				far = c
		fx_shots.append({"a": from_t, "b": far, "t0": anim, "until": anim + 0.25, "color": col, "def": defs.get("shot", {})})
	if has_me and not cells.is_empty():
		var cdef: Dictionary = defs.get("cell", {})   # [SKIN] sprite thật (FxLib) nếu có, rỗng = khối màu tạm
		fx_cells.append({"cells": cells, "t0": anim, "until": anim + (FxLib.duration(cdef) if not cdef.is_empty() else 0.45), "color": col, "def": cdef})

## Gói `area_fx` (B4/A6): `tiles` = [[x,y],...] tuyệt đối. Mỗi lần gửi = một nhịp hiệu ứng ~0.45s. Giới hạn 400 ô/gói để gói xấu
## (hoặc vùng khổng lồ) không làm tràn bộ nhớ vẽ.
func add_area_fx(tiles_in: Array, col: Color, def := {}) -> void:
	var cells: Array = []
	for c in tiles_in:
		if c is Array and c.size() >= 2:
			cells.append(Vector2i(int(c[0]), int(c[1])))
		if cells.size() >= 400:
			break
	if not cells.is_empty():
		fx_cells.append({"cells": cells, "t0": anim, "until": anim + (FxLib.duration(def) if not def.is_empty() else 0.45), "color": col, "def": def})

## [SKIN] Hiệu ứng 1 lần trên đúng 1 ô (trúng đòn / hồi máu / chết / mana shield...). def lấy từ FxLib.for_hit(...).
func add_tile_fx(cell: Vector2i, def: Dictionary) -> void:
	if def.is_empty():
		return
	fx_cells.append({"cells": [cell], "t0": anim, "until": anim + FxLib.duration(def), "color": Color(1, 1, 1), "def": def})

## Gói `shoot_fx` (B4/A6): đạn bay từ ô `a` tới ô `b`; thời gian bay tỉ lệ khoảng cách (tối thiểu 0.12s, tối đa 0.5s).
func add_shoot_fx(a: Vector2i, b: Vector2i, col: Color, def := {}) -> void:
	var dist := float(maxi(absi(b.x - a.x), absi(b.y - a.y)))
	var dur := clampf(0.06 * dist, 0.12, 0.5)
	fx_shots.append({"a": a, "b": b, "t0": anim, "until": anim + dur, "color": col, "def": def})

## Đạn ĐÁNH THƯỜNG XA theo vocation (hình tạm, thay sprite thật sau): 1 Sorcerer = sét, 2 Druid = đá, 3 Paladin = mũi tên.
## Knight (4) và quái không có đạn -> không làm gì. Thời gian bay tỉ lệ khoảng cách (0.15 – 0.4s).
const SHOT_VOC_STYLE := {1: "bolt", 2: "stone", 3: "arrow"}

func basic_shot(a: Vector2i, b: Vector2i, voc: int) -> void:
	var st: String = SHOT_VOC_STYLE.get(voc, "")
	if st == "":
		return
	var dist := float(maxi(absi(b.x - a.x), absi(b.y - a.y)))
	var dur := clampf(0.05 * dist, 0.15, 0.4)
	fx_shots.append({"a": a, "b": b, "t0": anim, "until": anim + dur, "style": st, "def": FxLib.for_basic(st)})   # [SKIN] fx/basic/<style>.png

## [SKIN] Vẽ đạn bằng sprite FxLib, xoay theo hướng bay (ảnh vẽ hướng →). Phải ghép với phép zoom đang dùng trong _draw().
func _draw_fx_shot_tex(d: Dictionary, pa: Vector2, pb: Vector2, u: float, age: float) -> void:
	var head := pa.lerp(pb, clampf(u, 0.0, 1.0))
	var ang := (pb - pa).angle() if pb.distance_to(pa) > 0.01 else 0.0
	var base := Transform2D(0.0, Vector2(zoom, zoom), 0.0, center() * (1.0 - zoom))   # đúng phép đặt ở đầu _draw()
	draw_set_transform_matrix(base * Transform2D(ang, head))
	FxLib.draw_at(self, d, Vector2.ZERO, TILE, age)
	draw_set_transform_matrix(base)

func _draw_shot_style(st: String, pa: Vector2, pb: Vector2, u: float) -> void:
	var k := clampf(u, 0.0, 1.0)
	var head := pa.lerp(pb, k)
	var dir := (pb - pa).normalized() if pb.distance_to(pa) > 0.01 else Vector2.RIGHT
	var perp := dir.orthogonal()
	match st:
		"stone":
			# viên đá xoay: đa giác 6 cạnh méo + vệt bụi
			var radii := [1.0, 0.75, 1.0, 0.8, 0.95, 0.7]
			var pts := PackedVector2Array()
			for i in 6:
				var ang := anim * 14.0 + TAU * float(i) / 6.0
				pts.append(head + Vector2(cos(ang), sin(ang)) * 5.5 * float(radii[i]))
			draw_colored_polygon(pts, Color(0.58, 0.52, 0.45))
			var ol := pts.duplicate()
			ol.append(pts[0])
			draw_polyline(ol, Color(0.25, 0.2, 0.15), 1.5)
			draw_circle(head - dir * 8.0, 2.0, Color(0.6, 0.55, 0.45, 0.5))
			draw_circle(head - dir * 13.0, 1.5, Color(0.6, 0.55, 0.45, 0.3))
		"bolt":
			# tia sét ngoằn ngoèo từ người bắn tới đầu đạn, nhấp nháy mỗi ~1/40s
			var n := maxi(2, int(pa.distance_to(head) / 7.0))
			var seed_i := int(anim * 40.0)
			var pts := PackedVector2Array()
			for i in n + 1:
				var base := pa.lerp(head, float(i) / float(n))
				if i > 0 and i < n:
					var r := fposmod(sin(float(i * 127 + seed_i * 311)) * 43758.5453, 1.0) - 0.5
					base += perp * r * 10.0
				pts.append(base)
			draw_polyline(pts, Color(0.35, 0.55, 1.0, 0.5), 5.0)
			draw_polyline(pts, Color(0.7, 0.88, 1.0), 2.5)
			draw_polyline(pts, Color.WHITE, 1.0)
			draw_circle(head, 4.0, Color(0.8, 0.92, 1.0, 0.8))
		"arrow":
			# mũi tên: thân nâu + đầu thép + 2 cánh lông ở đuôi, quay theo hướng bay
			var tail := head - dir * 14.0
			draw_line(tail, head, Color(0.55, 0.38, 0.2), 2.0)
			var base_pt := head - dir * 3.0
			draw_colored_polygon(PackedVector2Array([head + dir * 4.0, base_pt + perp * 3.5, base_pt - perp * 3.5]), Color(0.85, 0.87, 0.92))
			draw_line(tail, tail - dir * 3.0 + perp * 3.0, Color(0.92, 0.92, 0.92), 1.5)
			draw_line(tail, tail - dir * 3.0 - perp * 3.0, Color(0.92, 0.92, 0.92), 1.5)

## Look tùy chọn từ server (D2): col = [r,g,b] 0..1, sz = kích thước theo ô. Thiếu field thì tự suy ra từ max_hp.
func set_look(pid: String, col, sz) -> void:
	var d := {}
	if col is Array and col.size() >= 3:
		d["color"] = Color(float(col[0]), float(col[1]), float(col[2]))
	if sz != null:
		d["size"] = clampf(float(sz), 0.5, 1.0)
	looks[pid] = d

## Nhân vật `pid` vung kiếm về ô `target_tile` (Main gọi khi nhận effect `hit` có `from`).
func swing(pid: String, target_tile: Vector2i):
	swing_at[pid] = anim
	if tiles.has(pid):
		var d: Vector2i = target_tile - tiles[pid]
		facing[pid] = VocSprite.dir_from_delta(d.x, d.y, facing.get(pid, VocSprite.Dir.S))

## Nhân vật `pid` thi pháp (Main gọi khi mình cast / nhận gói `fx`).
func cast(pid: String):
	cast_at[pid] = anim

func mark_dead(pid: String, seconds := 1.5):
	dead_until[pid] = anim + seconds

## Dọn trạng thái animation của một thực thể khi bị xóa.
func set_invisible(pid: String, on: bool) -> void:
	if on:
		invisible[pid] = true
	else:
		invisible.erase(pid)
	queue_redraw()

func forget(pid: String):
	party_of.erase(pid)
	party_leader.erase(pid)
	sleeping.erase(pid)
	npc_types.erase(pid)
	invisible.erase(pid)
	vocations.erase(pid)
	harmony.erase(pid)
	virtue.erase(pid)
	facing.erase(pid)
	swing_at.erase(pid)
	cast_at.erase(pid)
	dead_until.erase(pid)
	walk_start.erase(pid)
	last_tile.erase(pid)

func slash(a: Vector2i, b: Vector2i):
	slashes.append({"a": a, "b": b, "until": anim + 0.18})

func set_map(walls_in: Array, gates_in: Array, bg_in: Array, temple: Vector2i):
	walls = []
	for w in walls_in:
		walls.append(Vector2i(int(w[0]), int(w[1])))
	gates = []
	for g in gates_in:
		gates.append(Vector2i(int(g["x"]), int(g["y"])))
	bg = Color(float(bg_in[0]), float(bg_in[1]), float(bg_in[2]))
	anchor = temple
	dest = Vector2i(-1, -1)
	wall_set = {}
	for wc in walls:
		wall_set[wc] = true
	decor = MapArt.gen_decor(map_id, map_w, map_h, wall_set, gates, temple, map_theme) if map_w > 0 else []
	tree_alpha = {}
	queue_redraw()

## Main gọi TRƯỚC set_map: kích thước + id map (để sinh nền/decor theo map).
## Nhà của map (gói `map.houses`). Gọi SAU set_map: bỏ cây/props sinh ngẫu nhiên nằm trong chân nhà.
func set_houses(list_in: Array) -> void:
	houses = list_in.duplicate()
	if not houses.is_empty():
		decor = decor.filter(func(d): return not _in_any_house(Vector2i(int(d["x"]), int(d["y"]))))
	queue_redraw()

## Cập nhật chủ/trạng thái các nhà đã biết theo gói `house_pub` (mua/trả nhà xong vẽ lại bảng hiệu + cửa).
func update_houses(list_in: Array) -> void:
	for u in list_in:
		for i in houses.size():
			if str(houses[i].get("id", "")) == str(u.get("id", "?")):
				houses[i] = u
	queue_redraw()

## Nhà có giường nằm ở ô t (đầu hoặc chân giường); {} nếu t không phải giường. Main dùng để chuột phải giường -> ngủ.
func bed_house_at(t: Vector2i) -> Dictionary:
	for h in houses:
		for b in h.get("beds", []):
			for key in ["head", "foot"]:
				var c: Array = b.get(key, [])
				if c.size() >= 2 and int(c[0]) == t.x and int(c[1]) == t.y:
					return h
	return {}

func _in_any_house(c: Vector2i) -> bool:
	for h in houses:
		var rc: Array = h.get("rect", [])
		if rc.size() >= 4 and c.x >= int(rc[0]) and c.x <= int(rc[2]) and c.y >= int(rc[1]) and c.y <= int(rc[3]):
			return true
	return false

func set_map_size(id: String, w: int, h: int) -> void:
	map_id = id
	map_w = w
	map_h = h

func center() -> Vector2:
	var drop := minf(DROP_TILES * TILE * zoom, view_size.y * 0.3)   # hạ hero xuống (không quá 30% chiều cao khung)
	return Vector2(view_size.x / 2.0, view_size.y / 2.0 + drop)

## Đổi nấc zoom (+1 = phóng to, -1 = thu nhỏ), kẹp trong ZOOM_LEVELS. Phóng to quanh tâm màn hình (= nhân vật khi camera bám).
func zoom_step(d: int) -> void:
	zoom_idx = clampi(zoom_idx + d, 0, ZOOM_LEVELS.size() - 1)
	zoom = ZOOM_LEVELS[zoom_idx]
	queue_redraw()

## Tọa độ màn hình (đã tính zoom) của góc trái-trên ô t. Bên trong _draw (đã set transform) trả tọa độ gốc chưa zoom.
func tile_to_screen(t: Vector2i) -> Vector2:
	var z := 1.0 if _in_draw else zoom
	return center() + (Vector2(t) - Vector2(anchor) - cam_off) * TILE * z - Vector2(TILE, TILE) / 2.0 * z

## ---- Field / tường trên map (rune Fire/Poison/Energy field, Magic Wall, Wild Growth) — khối màu tạm theo loại
func clear_fields() -> void:
	map_fields.clear()
	queue_redraw()

func set_fields(list_in: Array) -> void:
	map_fields.clear()
	for e in list_in:
		if e is Array and e.size() >= 5:
			map_fields[Vector2i(int(e[0]), int(e[1]))] = {"kind": str(e[2]), "blocking": bool(e[4])}
	queue_redraw()

func set_field(x: int, y: int, kind: String, blocking: bool) -> void:
	map_fields[Vector2i(x, y)] = {"kind": kind, "blocking": blocking}
	queue_redraw()

func remove_field(x: int, y: int) -> void:
	map_fields.erase(Vector2i(x, y))
	queue_redraw()

func _field_color(kind: String) -> Color:
	match kind:
		"fire": return Color(1.0, 0.45, 0.1)
		"poison": return Color(0.35, 0.85, 0.2)
		"energy": return Color(0.45, 0.65, 1.0)
		"magicwall": return Color(0.75, 0.55, 0.98)
		"wildgrowth": return Color(0.2, 0.55, 0.15)
	return Color(1, 1, 1)

func _draw_fields() -> void:
	if map_fields.is_empty() and not aim_active:
		return
	var pulse := 0.5 + 0.5 * sin(anim * 5.0)
	for cell in map_fields.keys():
		var f: Dictionary = map_fields[cell]
		var col := _field_color(str(f.get("kind", "")))
		var rect := Rect2(tile_to_screen(cell), Vector2(TILE, TILE))
		if bool(f.get("blocking", false)):
			draw_rect(rect, Color(col.r, col.g, col.b, 0.85))
			draw_rect(rect.grow(-3.0), Color(col.r, col.g, col.b, 0.35 + 0.3 * pulse))
			draw_rect(rect, Color(1, 1, 1, 0.9), false, 2.0)
		else:
			draw_rect(rect, Color(col.r, col.g, col.b, 0.35 + 0.25 * pulse))
			draw_rect(rect.grow(-6.0), Color(col.r, col.g, col.b, 0.55))
	if aim_active:
		var ht := screen_to_tile(get_local_mouse_position())
		var hr := Rect2(tile_to_screen(ht), Vector2(TILE, TILE))
		draw_rect(hr, Color(1, 1, 0.3, 0.25))
		draw_rect(hr, Color(1, 1, 0.3, 0.95), false, 2.0)
		draw_line(hr.position + Vector2(TILE, TILE) / 2 - Vector2(8, 0), hr.position + Vector2(TILE, TILE) / 2 + Vector2(8, 0), Color(1, 1, 0.3), 2.0)
		draw_line(hr.position + Vector2(TILE, TILE) / 2 - Vector2(0, 8), hr.position + Vector2(TILE, TILE) / 2 + Vector2(0, 8), Color(1, 1, 0.3), 2.0)
		queue_redraw()

func screen_to_tile(px: Vector2) -> Vector2i:
	var d = ((px - center()) / zoom + Vector2(TILE, TILE) / 2.0) / TILE
	var dd: Vector2 = d + cam_off
	return anchor + Vector2i(floori(dd.x), floori(dd.y))

func entity_at(px: Vector2) -> String:
	var t = screen_to_tile(px)
	for pid in tiles:
		if tiles[pid] == t and pid != player_id and not invisible.get(pid, false):
			return pid
	return ""

## Khoảng nghỉ (s) sau lần đổi ô cuối mà vẫn tính là đang đi: tối thiểu 0.45, dài hơn khi bước chậm (tránh nháy đi/đứng).
func _walk_gap(pid: String) -> float:
	return maxf(0.45, float(step_dur.get(pid, 0.3)) * 1.4)

func _walking(pid: String) -> bool:
	return anim - float(moved_at.get(pid, -9.0)) < _walk_gap(pid)

func _draw():
	var c = center()
	var font = UiSkin.font("world")
	draw_rect(Rect2(Vector2.ZERO, full_size), bg)   # nền vẽ trước, chưa zoom (phủ cả dải đáy màn hình)
	draw_set_transform(c * (1.0 - zoom), 0.0, Vector2(zoom, zoom))   # zoom quanh tâm màn hình
	_in_draw = true
	_draw_ground(c)
	for g in gates:
		var gp = tile_to_screen(g)
		if MapArt.ready():
			MapArt.draw_floor(self, MapArt.theme_def(map_theme), gp, Vector2(TILE, TILE), g)
		draw_rect(Rect2(gp, Vector2(TILE, TILE)), Color(0.2, 0.8, 0.9, 0.35))   # cổng warp: phủ xanh nhạt
		draw_rect(Rect2(gp, Vector2(TILE, TILE)), Color(1, 1, 1, 0.9), false, 2.0)
	if dest.x >= 0:
		var dp = tile_to_screen(dest)
		draw_line(dp, dp + Vector2(TILE, TILE), Color(1, 1, 0), 2.0)
		draw_line(dp + Vector2(TILE, 0), dp + Vector2(0, TILE), Color(1, 1, 0), 2.0)
	_draw_houses()
	_draw_auto_range()
	slashes.clear()   # gạch trắng khi hit đã bỏ (hàm slash() còn nhưng không vẽ)
	_draw_props()
	_draw_fields()
	fx_cells = fx_cells.filter(func(f): return anim < f["until"])
	for f in fx_cells:
		var cdef: Dictionary = f.get("def", {})
		if not cdef.is_empty():   # [SKIN] có sprite thật: vẽ khung hiện tại trên từng ô, bỏ khối màu tạm
			for cell in f["cells"]:
				FxLib.draw_at(self, cdef, tile_to_screen(cell) + Vector2(TILE, TILE) / 2, TILE, anim - f["t0"])
			continue
		var k = 1.0 - (anim - f["t0"]) / (f["until"] - f["t0"])
		var fc: Color = f.get("color", Color(1.0, 0.55, 0.15))
		for cell in f["cells"]:
			draw_rect(Rect2(tile_to_screen(cell), Vector2(TILE, TILE)), Color(fc.r, fc.g, fc.b, 0.55 * k))
	fx_shots = fx_shots.filter(func(f): return anim < f["until"])
	for f in fx_shots:
		var u = (anim - f["t0"]) / (f["until"] - f["t0"])
		var pa = tile_to_screen(f["a"]) + Vector2(TILE, TILE) / 2
		var pb = tile_to_screen(f["b"]) + Vector2(TILE, TILE) / 2
		var sc: Color = f.get("color", Color(1, 0.95, 0.5))
		var sdef: Dictionary = f.get("def", {})
		if not sdef.is_empty():   # [SKIN] đạn có sprite thật (xoay theo hướng bay)
			_draw_fx_shot_tex(sdef, pa, pb, u, anim - f["t0"])
			continue
		var st: String = f.get("style", "")
		if st != "":
			_draw_shot_style(st, pa, pb, u)   # đạn đánh thường theo vocation
			continue
		var head := pa.lerp(pb, clampf(u, 0.0, 1.0))
		var tail := pa.lerp(pb, clampf(u - 0.25, 0.0, 1.0))
		draw_line(tail, head, Color(sc.r, sc.g, sc.b, 0.6), 2.0)   # vệt đuôi
		draw_circle(head, 3.5, sc.lightened(0.35))
	# Thứ tự vẽ: ground/props -> quái -> CÂY (mờ nếu có ai đứng dưới tán) -> người chơi khác -> hero của mình.
	# Hero luôn trên cùng; trong cùng nhóm ô phía dưới (y lớn) vẽ sau.
	var order: Array = tiles.keys()
	order.sort_custom(func(a, b): return _layer_key(a) < _layer_key(b))
	var trees_done := false
	for pid in order:
		if not trees_done and kinds.get(pid) != "creature":
			_draw_trees()
			trees_done = true
		var ap := actor_screen(pid)
		if _on_screen(ap):
			_draw_actor(pid, ap)
			if sleeping.get(pid, false):
				_draw_sleep_overlay(ap)
			if party_of.has(pid):
				_draw_party_flag(pid, ap)
	if not trees_done:
		_draw_trees()
	_in_draw = false
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if zoom > 1.0:
		draw_string(font, Vector2(8, view_size.y - 8), "Zoom x%d (cuộn chuột để đổi)" % int(zoom),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.6))

## Arena AUTO: hình vuông bán kính `auto_range` ô quanh điểm xuất phát (nét đứt + nền mờ) + dấu X ở điểm xuất phát.
## Chưa bật Auto (auto_origin.x < 0) thì vẽ thử quanh hero để chỉnh kích thước. Vẽ dưới nhân vật/quái.
func _draw_auto_range() -> void:
	if auto_range <= 0.0:
		return
	var o := auto_origin
	var live := o.x >= 0
	if not live:
		if not tiles.has(player_id):
			return
		o = tiles[player_id]
	var r := int(auto_range)
	var tl := tile_to_screen(o - Vector2i(r, r))
	var side := float(2 * r + 1) * TILE
	var col := Color(0.4, 1.0, 0.6, 0.85 if live else 0.45)
	draw_rect(Rect2(tl, Vector2(side, side)), Color(0.4, 1.0, 0.6, 0.06 if live else 0.03))
	var br := tl + Vector2(side, side)
	var tr := Vector2(br.x, tl.y)
	var bl := Vector2(tl.x, br.y)
	draw_dashed_line(tl, tr, col, 2.0, 8.0)
	draw_dashed_line(tr, br, col, 2.0, 8.0)
	draw_dashed_line(br, bl, col, 2.0, 8.0)
	draw_dashed_line(bl, tl, col, 2.0, 8.0)
	if live:
		var p := tile_to_screen(o)
		draw_line(p + Vector2(6, 6), p + Vector2(TILE - 6, TILE - 6), col, 2.0)
		draw_line(p + Vector2(TILE - 6, 6), p + Vector2(6, TILE - 6), col, 2.0)

## Khoá sắp xếp lớp vẽ: nhóm (quái 0 < người chơi khác 1 < mình 2) rồi theo y của ô.
func _layer_key(pid: String) -> float:
	var grp := 0
	if kinds.get(pid) != "creature":
		grp = 2 if pid == player_id else 1
	return grp * 100000.0 + float(tiles[pid].y) * 10.0 + float(tiles[pid].x) * 0.001

## Ô (tọa độ gốc chưa zoom, góc trái-trên) có nằm trong vùng nhìn thấy sau khi zoom không (chừa 1 ô lề cho sprite cao/nhãn tên).
func _on_screen(local_pos: Vector2) -> bool:
	var c := center()
	var s := c + (local_pos - c) * zoom
	var m := TILE * zoom * 2.0
	return s.x > -m and s.y > -m and s.x < full_size.x + m and s.y < full_size.y + m

func _draw_actor(pid: String, p: Vector2):
	var font = UiSkin.font("world")
	var is_me = pid == player_id
	if invisible.get(pid, false) and not is_me:
		return   # tàng hình: người khác/quái không thấy
	var nm: String = str(names.get(pid, pid))
	var flash_on = anim < float(flash.get(pid, -9.0))
	if invisible.get(pid, false) and is_me:
		_draw_invisible_tag(p)
	var step = 1 if _walking(pid) else 0
	var leg = sin(anim * 14.0) * 4.0 * step
	if kinds.get(pid) == "creature":
		_draw_creature_placeholder(pid, nm, p, flash_on, leg)
		if hps.has(pid):
			var hp: int = hps[pid][0]
			var mx: int = maxi(1, hps[pid][1])
			var frac = clampf(float(hp) / float(mx), 0.0, 1.0)
			draw_rect(Rect2(p + Vector2(0, -7), Vector2(TILE * frac, 4)), Color(0.2, 0.8, 0.2))
			draw_rect(Rect2(p + Vector2(0, -7), Vector2(TILE, 4)), Color(0, 0, 0, 0.7), false, 1.0)
			draw_string(font, p + Vector2(0, -9), "%s %d" % [nm, hp],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.85, 0.4))
	elif kinds.get(pid) == "npc":
		_draw_npc(pid, nm, p)
	elif VocSprite.has(int(vocations.get(pid, 0))):
		_draw_harmony_orbs(pid, p, false)   # cầu phía sau đầu (vẽ trước sprite)
		_draw_knight(pid, p, is_me, flash_on, font)
		_draw_harmony_orbs(pid, p, true)    # cầu phía trước đầu (vẽ sau sprite)
	else:
		var shirt = Color(0.15, 0.3, 0.85) if is_me else Color(0.15, 0.65, 0.3)
		draw_line(p + Vector2(9, 16), p + Vector2(9 + leg, 23), Color(0.3, 0.2, 0.15), 3.0)  # chân
		draw_line(p + Vector2(15, 16), p + Vector2(15 - leg, 23), Color(0.3, 0.2, 0.15), 3.0)
		draw_rect(Rect2(p + Vector2(7, 8), Vector2(10, 9)), shirt)  # áo
		draw_circle(p + Vector2(12, 5), 4.0, Color(0.95, 0.8, 0.65))  # đầu
		if flash_on:
			draw_rect(Rect2(p, Vector2(TILE, TILE)), Color(1, 1, 1, 0.6))
		if is_me or pid == target:
			draw_rect(Rect2(p, Vector2(TILE, TILE)), Color.WHITE, false, 2.0)
		if not is_me:
			draw_string(font, p + Vector2(0, -4), pid, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 1, 0.7))

func set_harmony(pid: String, n: int, v: int) -> void:
	harmony[pid] = clampi(n, 0, ORB_SLOTS)
	virtue[pid] = clampi(v, 0, 3)
	queue_redraw()

## Monk: tối đa 5 linh cầu sáng nhỏ xoay quanh đầu (như Champion Ragnarok). Mỗi điểm Harmony = 1 cầu, cầu giữ nguyên vị trí
## khi tích thêm. `front` = nửa quỹ đạo gần người xem (lớn, sáng, vẽ SAU sprite); nửa xa vẽ TRƯỚC sprite (nhỏ, mờ).
func _draw_harmony_orbs(pid: String, p: Vector2, front: bool) -> void:
	var n: int = int(harmony.get(pid, 0))
	if n <= 0:
		return   # (người tàng hình đã bị loại ở _draw_entity trước khi tới đây)
	var col: Color = ORB_COLORS[clampi(int(virtue.get(pid, 0)), 0, 3)]
	var center := p + Vector2(TILE * 0.5, TILE * 0.02)
	var rx := TILE * 0.52
	var ry := TILE * 0.14
	for i in n:
		var a := anim * 2.4 + float(i) * TAU / float(ORB_SLOTS)
		var depth := sin(a)   # > 0: nửa gần người xem
		if (depth > 0.0) != front:
			continue
		var pos := center + Vector2(cos(a) * rx, depth * ry)
		var pulse := 1.0 + 0.12 * sin(anim * 5.0 + float(i) * 1.7)
		var r := (2.1 + 0.7 * depth) * pulse
		var alpha := 0.7 + 0.3 * depth
		draw_circle(pos, r + 3.2, Color(col.r, col.g, col.b, 0.14 * alpha))   # quầng sáng
		draw_circle(pos, r + 1.4, Color(col.r, col.g, col.b, 0.32 * alpha))
		draw_circle(pos, r, Color(col.r, col.g, col.b, alpha))                # lõi
		draw_circle(pos + Vector2(-0.5, -0.6) * r, r * 0.45, Color(1, 1, 1, 0.85 * alpha))   # điểm sáng

func _draw_invisible_tag(p: Vector2) -> void:
	draw_arc(p + Vector2(TILE * 0.5, TILE * 0.5), TILE * 0.55, 0.0, TAU, 20, Color(0.7, 0.85, 1.0, 0.8), 1.5)
	draw_string(UiSkin.font("world"), p + Vector2(0, TILE + 10), "invisible", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.85, 1.0))

## NPC (làn E): hình người đứng yên, màu áo theo `looks[pid].color` (Main gán theo tên NPC), tên màu xanh ngọc phía trên.
## Chỗ để thay bằng sprite thật: giữ chữ ký hàm.
func _draw_npc(pid: String, nm: String, p: Vector2) -> void:
	var font = UiSkin.font("world")
	if str(npc_types.get(pid, "")) == "depot":
		_draw_chest(nm, p)
		return
	if str(npc_types.get(pid, "")) == "house":
		_draw_house_npc(nm, p)
		return
	var look: Dictionary = looks.get(pid, {})
	var col: Color = look.get("color", Color(0.6, 0.6, 0.7))
	draw_rect(Rect2(p + Vector2(5, 9), Vector2(14, 13)), col)
	draw_rect(Rect2(p + Vector2(5, 9), Vector2(14, 13)), col.darkened(0.5), false, 1.0)
	draw_circle(p + Vector2(12, 6), 4.5, Color(0.95, 0.8, 0.65))
	draw_rect(Rect2(p + Vector2(7, 1), Vector2(10, 3)), col.darkened(0.3))
	draw_string(font, p + Vector2(-8, -4), nm, HORIZONTAL_ALIGNMENT_CENTER, TILE + 16, 11, Color(0.5, 0.9, 1.0))

## Hòm đồ (NPC type depot): cái rương gỗ có đai + khóa vàng. Chỗ để thay bằng sprite thật: giữ chữ ký hàm.
func _draw_chest(nm: String, p: Vector2) -> void:
	var font = UiSkin.font("world")
	var wood := Color(0.55, 0.36, 0.16)
	draw_rect(Rect2(p + Vector2(3, 10), Vector2(18, 12)), wood)
	draw_rect(Rect2(p + Vector2(3, 6), Vector2(18, 6)), wood.lightened(0.15))
	draw_rect(Rect2(p + Vector2(3, 6), Vector2(18, 16)), wood.darkened(0.55), false, 1.0)
	draw_rect(Rect2(p + Vector2(3, 12), Vector2(18, 2)), Color(0.85, 0.7, 0.2))
	draw_rect(Rect2(p + Vector2(10, 12), Vector2(4, 5)), Color(0.95, 0.82, 0.3))
	draw_string(font, p + Vector2(-8, -4), nm, HORIZONTAL_ALIGNMENT_CENTER, TILE + 16, 11, Color(0.5, 0.9, 1.0))

## Cờ party: tấm khiên nhỏ trên đầu — vàng = leader, xanh lá = thành viên; kèm vòng sáng dưới chân người cùng party với mình.
func _draw_party_flag(pid: String, p: Vector2) -> void:
	var lead: bool = bool(party_leader.get(pid, false))
	var col := Color(1.0, 0.85, 0.2) if lead else Color(0.35, 0.9, 0.45)
	var c := p + Vector2(TILE * 0.5, -34.0)
	var pts := PackedVector2Array([c + Vector2(-5, -5), c + Vector2(5, -5), c + Vector2(5, 1), c + Vector2(0, 6), c + Vector2(-5, 1)])
	draw_colored_polygon(pts, col)
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_polyline(outline, Color(0, 0, 0, 0.8), 1.0)
	draw_arc(p + Vector2(TILE * 0.5, TILE - 3.0), TILE * 0.42, 0.0, TAU, 20, Color(col.r, col.g, col.b, 0.55), 1.5)

## Đang ngủ: phủ xanh tối lên ô + chữ Z bay lên (chỗ để thay bằng sprite nằm: giữ chữ ký hàm).
func _draw_sleep_overlay(p: Vector2) -> void:
	var font = UiSkin.font("world")
	draw_rect(Rect2(p, Vector2(TILE, TILE)), Color(0.1, 0.15, 0.4, 0.4))
	for i in 3:
		var t := fmod(anim * 0.6 + float(i) / 3.0, 1.0)   # 0..1: mỗi chữ Z bay lên rồi mờ dần
		draw_string(font, p + Vector2(14 + i * 5, -2 - t * 16.0), "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, 9 + i * 2, Color(0.85, 0.9, 1.0, 1.0 - t))

## NPC Nhà (type house): ngôi nhà nhỏ mái đỏ. Chỗ để thay bằng sprite thật: giữ chữ ký hàm.
func _draw_house_npc(nm: String, p: Vector2) -> void:
	var font = UiSkin.font("world")
	draw_rect(Rect2(p + Vector2(4, 12), Vector2(16, 10)), Color(0.9, 0.82, 0.62))
	draw_rect(Rect2(p + Vector2(4, 12), Vector2(16, 10)), Color(0.3, 0.2, 0.1), false, 1.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(1, 12), p + Vector2(12, 3), p + Vector2(23, 12)]), Color(0.75, 0.2, 0.18))
	draw_rect(Rect2(p + Vector2(10, 16), Vector2(5, 6)), Color(0.4, 0.25, 0.1))
	draw_string(font, p + Vector2(-8, -4), nm, HORIZONTAL_ALIGNMENT_CENTER, TILE + 16, 11, Color(0.5, 0.9, 1.0))

## Nhà (Bước 3D): vẽ chồng lên nền (tường nhà đã nằm trong `walls` nên nền vẽ như đá): sàn gỗ, tường gạch đỏ, cửa, giường, bảng hiệu.
## Chỉ là hình; ai vào được do server quyết định (cửa chỉ mở cho chủ nhà). Nhà của mình: cửa vẽ mở + bảng hiệu vàng.
func _draw_houses() -> void:
	if houses.is_empty():
		return
	var font = UiSkin.font("world")
	var ts := Vector2(TILE, TILE)
	var vr := _visible_tiles()
	for h in houses:
		var rc: Array = h.get("rect", [])
		var dr: Array = h.get("door", [])
		if rc.size() < 4 or dr.size() < 2:
			continue
		var x0 := int(rc[0])
		var y0 := int(rc[1])
		var x1 := int(rc[2])
		var y1 := int(rc[3])
		if x1 < vr.position.x or x0 >= vr.end.x or y1 < vr.position.y or y0 >= vr.end.y:
			continue
		var door := Vector2i(int(dr[0]), int(dr[1]))
		var ow = h.get("owner")
		var taken: bool = ow != null
		var mine: bool = taken and my_name != "" and str(ow) == my_name
		var wall_col := Color(0.62, 0.3, 0.24) if not taken else (Color(0.5, 0.36, 0.2) if mine else Color(0.42, 0.34, 0.3))
		var floor_col := Color(0.66, 0.5, 0.3)
		for ty in range(y0, y1 + 1):
			for tx in range(x0, x1 + 1):
				var cell := Vector2i(tx, ty)
				var pos := tile_to_screen(cell)
				if not _on_screen(pos):
					continue
				var edge := tx == x0 or tx == x1 or ty == y0 or ty == y1
				if cell == door:
					draw_rect(Rect2(pos, ts), floor_col)
					var is_open := mine
					var dw := 8.0 if is_open else 20.0
					draw_rect(Rect2(pos + Vector2((TILE - dw) / 2.0, 3), Vector2(dw, TILE - 6)), Color(0.3, 0.18, 0.08) if not is_open else Color(0.45, 0.3, 0.14))
					draw_rect(Rect2(pos + Vector2(3, 1), Vector2(TILE - 6, TILE - 2)), Color(0.2, 0.12, 0.05), false, 2.0)
					if not is_open:
						draw_circle(pos + Vector2(TILE / 2.0 + 5, TILE / 2.0), 1.8, Color(0.95, 0.82, 0.3))
				elif edge:
					draw_rect(Rect2(pos, ts), wall_col)
					draw_rect(Rect2(pos, Vector2(TILE, 4)), wall_col.lightened(0.18))   # mép trên sáng
					draw_rect(Rect2(pos + Vector2(0, TILE - 5), Vector2(TILE, 5)), wall_col.darkened(0.3))   # chân tối
					draw_line(pos + Vector2(0, TILE / 2.0), pos + Vector2(TILE, TILE / 2.0), wall_col.darkened(0.2), 1.0)   # mạch gạch
				else:
					draw_rect(Rect2(pos, ts), floor_col if (tx + ty) % 2 == 0 else floor_col.darkened(0.06))
					draw_line(pos + Vector2(0, TILE / 2.0), pos + Vector2(TILE, TILE / 2.0), floor_col.darkened(0.2), 1.0)   # ván gỗ
		for b in h.get("beds", []):
			var hd: Array = b.get("head", [])
			var ft: Array = b.get("foot", [])
			if hd.size() < 2 or ft.size() < 2:
				continue
			var ph := tile_to_screen(Vector2i(int(hd[0]), int(hd[1])))
			var pf := tile_to_screen(Vector2i(int(ft[0]), int(ft[1])))
			var tl := Vector2(minf(ph.x, pf.x), minf(ph.y, pf.y)) + Vector2(3, 3)
			var sz := Vector2(absf(ph.x - pf.x) + TILE, absf(ph.y - pf.y) + TILE) - Vector2(6, 6)
			draw_rect(Rect2(tl, sz), Color(0.78, 0.2, 0.22))                       # chăn
			draw_rect(Rect2(tl, sz), Color(0.3, 0.08, 0.08), false, 1.0)
			draw_rect(Rect2(ph + Vector2(6, 6), Vector2(TILE - 12, TILE - 12)), Color(0.95, 0.95, 0.9))   # gối ở ô đầu giường
		var top_left := tile_to_screen(Vector2i(x0, y0))
		var label := str(h.get("name", ""))
		var lcol := Color(0.6, 0.95, 0.6)
		if mine:
			label += " · Nhà của bạn"
			lcol = Color(1.0, 0.85, 0.4)
		elif taken:
			label += " · " + str(ow)
			lcol = Color(0.75, 0.75, 0.78)
		else:
			label += " · %s gp" % UiKit.fmt_int(int(h.get("price", 0)))
		var wpx := float(x1 - x0 + 1) * TILE
		if _on_screen(top_left) or _on_screen(top_left + Vector2(wpx, 0)):
			draw_string(font, top_left + Vector2(0, -3), label, HORIZONTAL_ALIGNMENT_CENTER, wpx, 10, lcol)

## D2 — hình tạm của quái, suy ra từ THÔNG SỐ chứ không theo tên:
##  - kích thước: theo log10(max_hp)  (≈10 máu -> nhỏ 55% ô, ≥10.000 máu -> kín ô)
##  - màu: theo bậc max_hp (xanh lá -> vàng -> đỏ), lệch nhẹ theo hash tên để phân biệt quái cùng bậc máu
##  - bậc cao (>= 0.65) thêm sừng
## Server có gửi `spawn.color` / `spawn.size` (xem PROTOCOL §Làn D) thì dùng đúng giá trị đó.
## Chỗ để thay bằng sprite thật: giữ nguyên chữ ký hàm, vẽ AnimatedSprite2D thay cho các lệnh draw_* bên dưới.
## [VFX] Thông số hình tạm của quái (màu / tỉ lệ cỡ / bậc máu). Dùng chung cho _draw_creature_placeholder và
## VfxGhost (bóng quái chết bốc hơi) để hai nơi luôn vẽ giống nhau. Trả {col: Color, frac: float, tier: float}.
func creature_look(pid: String, nm := "") -> Dictionary:
	if nm == "":
		nm = str(names.get(pid, pid))
	var mx := 1
	if hps.has(pid):
		mx = maxi(1, int(hps[pid][1]))
	var tier := clampf(log(float(mx)) / log(10.0) / 4.0, 0.0, 1.0)
	var look: Dictionary = looks.get(pid, {})
	var frac: float = float(look.get("size", 0.55 + 0.45 * tier))
	var col: Color
	if look.has("color"):
		col = look["color"]
	else:
		var hue := fposmod(lerpf(0.33, 0.0, tier) + (float(nm.hash() % 1000) / 1000.0 - 0.5) * 0.12, 1.0)
		col = Color.from_hsv(hue, 0.65, 0.85)
	return {"col": col, "frac": frac, "tier": tier}

func _draw_creature_placeholder(pid: String, nm: String, p: Vector2, flash_on: bool, leg: float) -> void:
	var lk := creature_look(pid, nm)   # [VFX] tách ra để VfxGhost dùng chung
	var tier: float = lk["tier"]
	var frac: float = lk["frac"]
	var col: Color = lk["col"]
	var r := TILE * frac * 0.5
	var c := p + Vector2(TILE / 2.0, TILE - r - absf(leg) * 0.4)  # đáy chạm đáy ô, nảy nhẹ khi đi
	if tier >= 0.65:
		for sgn in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([c + Vector2(sgn * r * 0.7, -r * 0.4),
				c + Vector2(sgn * r * 0.4, -r * 1.2), c + Vector2(sgn * r * 0.05, -r * 0.8)]), col.darkened(0.35))
	draw_circle(c, r, col)
	draw_arc(c, r, 0.0, TAU, 20, col.darkened(0.5), 1.5)
	for sgn in [-1.0, 1.0]:
		var ec := c + Vector2(sgn * r * 0.38, -r * 0.15)
		draw_circle(ec, maxf(1.6, r * 0.2), Color.WHITE)
		draw_circle(ec + Vector2(0.5, 0.5), maxf(0.8, r * 0.1), Color.BLACK)
	if flash_on:
		draw_circle(c, r, Color(1, 1, 1, 0.75))

## Nhân vật có sprite (VocSprite.SPECS). Ưu tiên trạng thái: gục > đánh > thi pháp > đi > đứng.
func _draw_knight(pid: String, p: Vector2, is_me: bool, flash_on: bool, font: Font) -> void:
	var voc := int(vocations.get(pid, 4))
	var dir: int = facing.get(pid, VocSprite.Dir.S)
	var state := VocSprite.State.IDLE
	var t := anim
	var since_swing := anim - float(swing_at.get(pid, -9.0))
	var since_cast := anim - float(cast_at.get(pid, -9.0))
	if anim < float(dead_until.get(pid, -9.0)):
		state = VocSprite.State.DEAD
	elif since_swing < VocSprite.attack_time(voc):
		state = VocSprite.State.ATTACK
		t = since_swing
	elif since_cast < VocSprite.cast_time(voc):
		state = VocSprite.State.CAST
		t = since_cast
	elif _walking(pid):
		state = VocSprite.State.WALK
		t = anim - float(walk_start.get(pid, moved_at.get(pid, 0.0)))
	var tint := Color(2.2, 2.2, 2.2) if flash_on else Color.WHITE   # trúng đòn: sáng lên
	VocSprite.draw(self, voc, p, TILE, state, dir, t, tint)
	if is_me or pid == target:
		draw_rect(Rect2(p, Vector2(TILE, TILE)), Color.WHITE, false, 1.0)
	if not is_me:
		draw_string(font, p + Vector2(0, -26), str(names.get(pid, pid)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 1, 0.7))

# ---------- nền / tường đá / nước / cây / props (MapArt.gd) ----------

## Dải ô nhìn thấy (bao gồm lề 2 ô) theo anchor + view + zoom.
func _visible_tiles() -> Rect2i:
	var c := center()
	var up := int(ceil(c.y / zoom / TILE)) + 2                    # số ô phía trên hero
	var down := int(ceil((full_size.y - c.y) / zoom / TILE)) + 2   # số ô phía dưới hero (đến tận đáy màn hình, dưới cả khung chat)
	var side := int(ceil(full_size.x / zoom / TILE / 2.0)) + 2
	return Rect2i(anchor.x - side, anchor.y - up, side * 2 + 1, up + down + 1)

func _draw_ground(c: Vector2) -> void:
	if not MapArt.ready():   # chưa có asset -> nền màu phẳng như cũ
		draw_rect(Rect2(Vector2.ZERO, full_size), bg)
		for wc in walls:
			if _on_screen(tile_to_screen(wc)):
				draw_rect(Rect2(tile_to_screen(wc), Vector2(TILE, TILE)), Color(0.32, 0.32, 0.37))
		return
	# nền / tường / ngoài map theo theme (MapArt.draw_ground; base = góc trái-trên ô (0,0) trên màn hình)
	MapArt.draw_ground(self, _visible_tiles(), tile_to_screen(Vector2i.ZERO), float(TILE), map_w, map_h,
		wall_set, MapArt.theme_def(map_theme), anim)

func _draw_props() -> void:
	if not MapArt.ready():
		return
	var tint: Color = MapArt.theme_def(map_theme)["prop_tint"]
	for d in decor:
		if d["k"] != "prop":
			continue
		var pos := tile_to_screen(Vector2i(int(d["x"]), int(d["y"])))
		if not _on_screen(pos):
			continue
		MapArt.draw_sprite(self, str(d["f"]), pos, float(TILE), tint)

## Cây vẽ SAU quái, TRƯỚC hero. Có thực thể nào (hero hay quái) đứng trong vùng tán (rộng theo sprite, cao ~80% sprite phía trên gốc)
## thì cây mờ dần xuống TREE_FADE_ALPHA, rời đi thì rõ lại.
func _draw_trees() -> void:
	if not MapArt.ready():
		return
	var occupied := {}
	for pid in tiles:
		occupied[tiles[pid]] = true
	for i in decor.size():
		var d: Dictionary = decor[i]
		if d["k"] != "tree":
			continue
		var key := str(d["f"])
		var m: Array = MapArt.meta(key)
		var cell := Vector2i(int(d["x"]), int(d["y"]))
		var pos := tile_to_screen(cell)
		var sprite_h: float = float(m[1]) * MapArt.SCALE
		if not _on_screen(pos - Vector2(0, sprite_h)):
			continue
		var half_w := maxi(1, int(ceil(float(m[0]) * MapArt.SCALE / TILE / 2.0 - 0.01)))   # nửa bề ngang tán (ô)
		var up := clampi(int(ceil(sprite_h * 0.8 / TILE)), 2, 4)                            # chiều cao tán (ô)
		var under := false
		for oy in range(-up, 1):
			for ox in range(-half_w, half_w + 1):
				if occupied.has(cell + Vector2i(ox, oy)):
					under = true
		var a: float = tree_alpha.get(i, 1.0)
		a = move_toward(a, TREE_FADE_ALPHA if under else 1.0, _dt * 5.0)
		tree_alpha[i] = a
		var sway := 1.0 + 0.012 * sin(anim * 1.3 + float(d["ph"]))   # lắc nhẹ (co giãn dọc ~1%) vì sprite cây mới là ảnh tĩnh
		MapArt.draw_sprite(self, key, pos, float(TILE), Color(1, 1, 1, a), sway)