class_name VfxBridge
extends Node
## CẦU NỐI giao thức server -> hiệu ứng vfx_kit. Đây là chỗ DUY NHẤT biết cả gói tin của server lẫn WorldView.
## Main.gd chỉ gọi vài hàm on_* bên dưới (các dòng đánh dấu `# [VFX]`); logic nằm hết ở đây.
##
## Cách hoạt động
##  - Tạo 1 lớp `VfxLayer` (Node2D) làm con của WorldView. Mỗi khung hình lớp này được đặt vị trí/scale để khớp phép
##    biến đổi trong WorldView._draw (camera bám hero + zoom). Hiệu ứng nằm trong lớp này nên TỰ cuộn và zoom theo thế giới.
##  - Tọa độ trong lớp = "px thiết kế" của vfx_kit: 1 ô = CELL (64) px, tâm ô (x,y) = Vector2(x,y) * CELL.
##  - Thứ tự ưu tiên hiển thị: PNG skin (assets/fx, FxLib) > vfx_kit (file này) > khối màu tạm cũ của WorldView.
##    Có PNG skin cho spell/đạn/hit nào thì cầu nối tự nhường cho skin đó.
##
## Gói tin xử lý (xem PROTOCOL.md):
##  - effect{kind:hit, from}  -> on_hit: hiệu ứng đánh thường (trúng đòn). Hoãn DEFER_S giây để biết có phải đòn của spell không.
##  - fx{me, ani, tiles}      -> on_fx: 1 ô = spell ĐƠN MỤC TIÊU (đạn/tia + nổ); nhiều ô = spell VÙNG (AOE): hiệu ứng nhẹ trên từng ô,
##                               lan dần ra (sóng/chùm tia/vòng quanh người) hoặc nổ từ tâm (quả cầu, rune). 0 ô (tự buff): trả false.
##  - area_fx{effect, tiles}  -> on_area_fx: vùng của chiêu quái / rune (chỉ khi hằng nằm trong VfxMap.ME_KIND); luôn loại trùng với on_hit.
##  - creature_dead           -> on_creature_dead: quái chết bốc hơi.
## Chưa làm (thêm ở đây khi cần): heal/buff, đạn của chiêu quái (shoot_fx), mana shield.

const CELL := 64.0                 # px thiết kế mỗi ô của vfx_kit
const DEFER_S := 0.06              # chờ trước khi vẽ hiệu ứng đánh thường (để spell kịp "nhận" đòn đó)
const IMPACT_DEDUPE_S := 1.0       # bỏ hiệu ứng trúng thứ 2 trên cùng ô trong khoảng này (rune gửi 2 gói fx)
const Manager := preload("res://vfx_kit/vfx_manager.gd")
const VfxDefs := preload("res://vfx_kit/vfx_defs.gd")
const BALL_MARGIN := 1.0           # vùng là "quả cầu rơi xa người cast" khi tâm vùng cách người cast > bán kính vùng + chừng này ô
const AREA_CENTER_MAX_CELLS := 9   # area_fx của quái: chỉ vẽ hiệu ứng tâm lớn khi vùng nhỏ hơn chừng này ô

var world: WorldView
var layer: Node2D                  # lớp hiệu ứng (con của world)
var fx: Node                       # vfx_manager
var enabled := true                # tắt = mọi hàm on_* không làm gì (Main quay về hiệu ứng cũ)

var _pending := {}                 # "src>dst" -> {src, dst, cell, pos, dir, kind}: đòn đánh thường đang chờ vẽ
var _recent_impact := {}           # Vector2i -> giây: ô vừa có hiệu ứng trúng


func _init(w: WorldView = null) -> void:
	world = w


func _ready() -> void:
	if world == null:
		return
	layer = Node2D.new()
	layer.name = "VfxLayer"
	world.add_child(layer)
	fx = Manager.new()
	add_child(fx)
	_sync_layer()


func _process(_dt: float) -> void:
	_sync_layer()


## Khớp lớp hiệu ứng với phép biến đổi của WorldView._draw: zoom quanh center(), camera = anchor + cam_off.
func _sync_layer() -> void:
	if world == null or layer == null:
		return
	var z := world.zoom
	layer.scale = Vector2.ONE * (WorldView.TILE / CELL) * z
	layer.position = world.center() - z * (Vector2(world.anchor) + world.cam_off) * WorldView.TILE


# ====================================================================== API cho Main.gd

## effect{kind:hit}: đòn đánh thường (hoặc đòn của quái). Main chỉ gọi khi có `from` hợp lệ (cùng điều kiện với world.swing).
## dmg <= 0 (trượt / bị chặn hết) -> không có hiệu ứng trúng.
func on_hit(target_id: String, src_id: String, dmg: int) -> void:
	if not _ok() or dmg <= 0:
		return
	if not FxLib.for_hit("hit").is_empty():
		return   # đã có PNG skin assets/fx/hit/hit.png -> Main._hit_fx lo
	if not world.tiles.has(target_id) or not world.tiles.has(src_id):
		return
	var cell: Vector2i = world.tiles[target_id]
	var dirv := Vector2(cell - Vector2i(world.tiles[src_id]))
	var key := src_id + ">" + target_id
	_pending[key] = {
		"src": src_id, "dst": target_id, "cell": cell, "pos": _pos_of(target_id), "dir": dirv.normalized(),
		"kind": VfxMap.basic_kind(str(world.kinds.get(src_id, "")), int(world.vocations.get(src_id, 0))),
	}
	get_tree().create_timer(DEFER_S).timeout.connect(_flush_hit.bind(key))


## fx{id,from,me?,ani?,tiles?}: spell/rune của `id`. element/spell chỉ có khi là spell do CHÍNH MÌNH vừa cast.
## Trả true = đã vẽ (Main bỏ qua world.add_fx); false = không xử lý (Main vẽ như cũ: skin hoặc khối màu).
func on_fx(msg: Dictionary, element := "", spell := "") -> bool:
	if not _ok():
		return false
	var caster := str(msg.get("id", ""))
	var cells := _cells(msg.get("tiles", []))
	_consume_pending(caster, cells)   # đòn này là của spell, không vẽ thêm hiệu ứng đánh thường
	if cells.is_empty():
		return false                  # không có ô (tự buff...): không phải đòn tấn công
	var ani := str(msg.get("ani", ""))
	var me := str(msg.get("me", ""))
	if not FxLib.for_cell(me, spell, element).is_empty() or not FxLib.for_shot(ani, spell, element).is_empty():
		return false                  # đã có PNG skin cho spell này
	var kind := VfxMap.kind_for(spell, element, ani, me)
	if kind == "":
		return false
	if cells.size() > 1:
		return _area(kind, _caster_pos(caster, msg), cells, ani)
	var cell: Vector2i = cells[0]
	var tpos := cell_pos(cell)
	var from_pos := _caster_pos(caster, msg)
	if ani == "":
		# chỉ có hiệu ứng ô (vd rune gửi `me` ở gói thứ 2 sau gói đạn): bỏ nếu vừa có hiệu ứng trúng ở ô này
		if _now() - float(_recent_impact.get(cell, -99.0)) < IMPACT_DEDUPE_S:
			return true
		_mark_impact(cell, 0.0)
		fx.impact_at(kind, tpos, {"parent": layer, "dir": (tpos - from_pos).normalized()})
		return true
	var target: Variant = tpos
	var tid := _creature_at(cell)
	if tid != "":
		target = _follow.bind(tid, tpos)   # đạn bám theo quái đang di chuyển
	_mark_impact(cell, 0.4)
	fx.cast_single(kind, from_pos, target, {"parent": layer})
	return true


## area_fx{effect,tiles}: hiệu ứng vùng của chiêu quái / rune. Luôn loại đòn đánh thường trùng vùng.
## Trả true = đã vẽ (Main bỏ qua world.add_area_fx); false = Main vẽ khối màu / PNG skin như cũ.
## Chỉ vẽ khi hằng nằm trong VfxMap.ME_KIND (hằng buff/hồi máu/teleport vẫn do Main vẽ).
func on_area_fx(msg: Dictionary) -> bool:
	if not _ok():
		return false
	var cells := _cells(msg.get("tiles", []))
	_consume_pending("", cells)
	if cells.is_empty():
		return false
	var me := str(msg.get("effect", ""))
	if not FxLib.for_cell(me, "", "").is_empty():
		return false                  # đã có PNG skin
	var kind := VfxMap.kind_for_me(me)
	if kind == "":
		return false
	if cells.size() == 1:
		var c: Vector2i = cells[0]
		if _now() - float(_recent_impact.get(c, -99.0)) >= IMPACT_DEDUPE_S:
			_mark_impact(c, 0.0)
			fx.impact_at(kind, cell_pos(c), {"parent": layer})
		return true
	# không biết người cast: coi như nổ từ tâm vùng (vùng lớn thì bỏ hiệu ứng tâm cho nhẹ)
	var cen := _centroid(cells)
	return _area(kind, cen * CELL, cells, "", true, cells.size() > AREA_CENTER_MAX_CELLS)


## creature_dead (gọi TRƯỚC Main._remove, khi tiles/looks/hps còn nguyên): quái chết bốc hơi.
func on_creature_dead(pid: String) -> void:
	if not _ok():
		return
	if str(world.kinds.get(pid, "")) != "creature" or not world.tiles.has(pid):
		return
	if bool(world.invisible.get(pid, false)):
		return
	var ghost := _make_ghost(pid)
	if ghost == null:
		return
	layer.add_child(ghost)
	ghost.position = _pos_of(pid)
	fx.evaporate_ghost(ghost)


## Đổi map / đăng xuất: dọn hiệu ứng đang chạy.
func clear() -> void:
	_pending.clear()
	_recent_impact.clear()
	if layer != null:
		for c in layer.get_children():
			c.queue_free()


## Dùng khi cần gọi tay (debug, hotbar sau này): bắn `kind` từ thực thể from_id tới to_id.
func play(kind: String, from_id: String, to_id: String) -> void:
	if not _ok() or not world.tiles.has(from_id) or not world.tiles.has(to_id):
		return
	fx.cast_single(kind, _pos_of(from_id), _follow.bind(to_id, _pos_of(to_id)), {"parent": layer})


# ====================================================================== nội bộ

func _ok() -> bool:
	return enabled and world != null and layer != null and fx != null


static func cell_pos(c: Vector2i) -> Vector2:
	return Vector2(c) * CELL


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Tâm hiển thị (đã gồm phần trượt mượt) của thực thể, tọa độ lớp hiệu ứng.
func _pos_of(id: String) -> Vector2:
	var cell: Vector2i = world.tiles.get(id, Vector2i.ZERO)
	return Vector2(world.vis.get(id, Vector2(cell))) * CELL


## Callable cho vfx_manager: vị trí hiện tại của thực thể `id` (đã chết/rời đi thì dùng `fallback`).
func _follow(id: String, fallback: Vector2) -> Vector2:
	if world.tiles.has(id):
		return _pos_of(id)
	return fallback


func _caster_pos(caster: String, msg: Dictionary) -> Vector2:
	if world.tiles.has(caster):
		return _pos_of(caster)
	var fr: Variant = msg.get("from", [])
	if fr is Array and fr.size() >= 2:
		return cell_pos(Vector2i(int(fr[0]), int(fr[1])))
	return Vector2.ZERO


func _creature_at(cell: Vector2i) -> String:
	for id in world.tiles:
		if world.tiles[id] == cell and str(world.kinds.get(id, "")) == "creature":
			return str(id)
	return ""


func _cells(tiles_in: Variant) -> Array:
	var out: Array = []
	if tiles_in is Array:
		for t in tiles_in:
			if t is Array and t.size() >= 2:
				out.append(Vector2i(int(t[0]), int(t[1])))
	return out


func _consume_pending(caster: String, cells: Array) -> void:
	if _pending.is_empty() or cells.is_empty():
		return
	for key in _pending.keys():
		var e: Dictionary = _pending[key]
		if (caster == "" or e["src"] == caster) and cells.has(e["cell"]):
			_pending.erase(key)


func _centroid(cells: Array) -> Vector2:
	var sum := Vector2.ZERO
	for c in cells:
		sum += Vector2(c)
	return sum / float(cells.size())


## Spell VÙNG (từ >= 2 ô). origin: điểm lan ra (người cast, tọa độ lớp). Trả true khi kiểu có công thức AREAS.
##  - Vùng nằm sát người cast (sóng, chùm tia, vòng quanh người): lan từ người cast ra ngoài ("wave").
##  - Vùng là quả cầu rơi xa người cast (rune, spell cầu): nổ lan từ tâm ("ball"); nếu gói có đạn thì đạn bay tới trước.
##  - Ô vừa có hiệu ứng (vd rune gửi đạn + nổ tâm ở gói trước) được bỏ qua để không chồng hai lần.
func _area(kind: String, origin: Vector2, cells: Array, ani: String, force_ball := false, skip_center := false) -> bool:
	if not VfxDefs.AREAS.has(kind):
		return false
	var now := _now()
	var positions: Array = []
	var skip: Array = []
	for c in cells:
		var cp := cell_pos(c)
		positions.append(cp)
		if now - float(_recent_impact.get(c, -99.0)) < IMPACT_DEDUPE_S:
			skip.append(cp)
	var cen := _centroid(cells)
	var radius := 0.0
	for c in cells:
		radius = maxf(radius, cen.distance_to(Vector2(c)))
	var ball := force_ball or cen.distance_to(origin / CELL) > radius + BALL_MARGIN
	var cen_cell := Vector2i(roundi(cen.x), roundi(cen.y))
	var opts := {
		"parent": layer, "mode": "ball" if ball else "wave", "skip": skip,
		"skip_center": skip_center or skip.has(cell_pos(cen_cell)),
	}
	for c in cells:
		_mark_impact(c, 0.0)
	if ball and ani != "":
		fx.cast_single(kind, origin, cen * CELL, {"parent": layer, "no_impact": true,
			"on_hit": _land_area.bind(kind, origin, positions, opts)})
	else:
		fx.cast_area(kind, origin, positions, opts)
	return true


func _land_area(kind: String, origin: Vector2, positions: Array, opts: Dictionary) -> void:
	if _ok():
		fx.cast_area(kind, origin, positions, opts)


func _flush_hit(key: String) -> void:
	if not _pending.has(key) or not _ok():
		return
	var e: Dictionary = _pending[key]
	_pending.erase(key)
	_mark_impact(e["cell"], 0.0)
	fx.impact_at(str(e["kind"]), e["pos"], {"parent": layer, "dir": e["dir"]})


func _mark_impact(cell: Vector2i, ahead_s: float) -> void:
	if _recent_impact.size() > 32:
		var now := _now()
		for k in _recent_impact.keys():
			if now - float(_recent_impact[k]) > 5.0:
				_recent_impact.erase(k)
	_recent_impact[cell] = _now() + ahead_s


## Dựng "bóng" cho quái chết. KHI CÓ SPRITE QUÁI THẬT: đổi hàm này để trả Sprite2D/AnimatedSprite2D (xem VfxGhost.gd).
func _make_ghost(pid: String) -> Node2D:
	var g := VfxGhost.new()
	g.setup(world.creature_look(pid))
	return g
