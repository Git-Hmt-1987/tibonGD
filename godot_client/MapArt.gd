class_name MapArt
extends RefCounted
## Đồ họa map từ bộ sprite mới (Outdoor / Cave / beach). Thay hoàn toàn bản Tiny Swords ("Tibon").
## Mọi thứ chỉ là hình (không va chạm) - va chạm/tường do server quyết định (WALLS).
## Dữ liệu theme nằm ở MapArtThemes.gd, kích thước/điểm chạm đất của sprite ở MapArtMeta.gd (cả hai sinh tự động).
## Decor sinh theo map_id (cùng map -> cùng bố cục), sau này thay bằng dữ liệu map thật chỉ cần thay gen_decor().

const ASSET_ROOT := "res://sprites/map/"
const SCALE := 0.5          # sprite gốc 64px -> 32px (WorldView.TILE) => cây/props 96-128px chiếm 1.5-2 ô

static var _tex := {}
static var _defs := {}

## Theme (server gửi map.theme): grass / mine / hell / desert / sky. Theme lạ -> grass. Có cache.
static func theme_def(name: String) -> Dictionary:
	if not _defs.has(name):
		_defs[name] = MapArtThemes.get_def(name)
	return _defs[name]

static func tex(key: String) -> Texture2D:
	if _tex.has(key):
		return _tex[key]
	var path := ASSET_ROOT + key + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	else:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			t = ImageTexture.create_from_image(img)
	_tex[key] = t
	return t

## [rộng, cao, gốc_x, gốc_y, viền_cắt] của sprite (px gốc)
static func meta(key: String) -> Array:
	return MapArtMeta.M.get(key, [64, 64, 32, 63, 0])

static func ready() -> bool:
	var th := theme_def("grass")
	return tex(String(th["floor"][0])) != null

static func _hash(x: int, y: int, salt: int) -> int:
	return ((x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)) & 0x7FFFFFFF

static func _pick(keys: Array, x: int, y: int, salt: int) -> String:
	return String(keys[_hash(x, y, salt) % keys.size()])

## Vẽ 1 ô nền: bỏ viền lởm chởm (meta[4] px), kéo ra đúng 1 ô + 1px chồng mép để không lộ khe.
static func blit(ci: CanvasItem, key: String, pos: Vector2, ts: Vector2, tint: Color) -> void:
	var t := tex(key)
	if t == null:
		return
	var m: Array = meta(key)
	var ins := float(m[4])
	var sz := Vector2(float(m[0]), float(m[1]))
	ci.draw_texture_rect_region(t, Rect2(pos, ts + Vector2(1, 1)), Rect2(Vector2(ins, ins), sz - Vector2(ins, ins) * 2.0), tint)

## Ô sàn của theme tại cell (dùng cho cổng/đền để cùng màu nền).
static func draw_floor(ci: CanvasItem, th: Dictionary, pos: Vector2, ts: Vector2, cell: Vector2i) -> void:
	blit(ci, _pick(th["floor"], cell.x, cell.y, 1), pos, ts, th["floor_tint"])
	var wash: Color = th["floor_wash"]
	if wash.a > 0.0:
		ci.draw_rect(Rect2(pos, ts), wash)

## Nền + tường + ngoài map cho dải ô nhìn thấy vr. base = tọa độ màn hình góc trái-trên của ô (0,0); t = thời gian anim (s).
static func draw_ground(ci: CanvasItem, vr: Rect2i, base: Vector2, tile: float, map_w: int, map_h: int,
		wall_set: Dictionary, th: Dictionary, t: float) -> void:
	var ts := Vector2(tile, tile)
	var floors: Array = th["floor"]
	var walls: Array = th["wall"]
	var outs: Array = th["out"]
	var ftint: Color = th["floor_tint"]
	var wtint: Color = th["wall_tint"]
	var otint: Color = th["out_tint"]
	var pulse: bool = th["out_pulse"]
	var wash: Color = th["floor_wash"]   # lớp phủ màu nhạt lên sàn (sky: biến nền be thành trắng xanh như mây); alpha 0 = không phủ
	for ty in range(vr.position.y, vr.end.y):
		for tx in range(vr.position.x, vr.end.x):
			var pos := base + Vector2(tx, ty) * tile
			if tx < 0 or ty < 0 or tx >= map_w or ty >= map_h:
				var f := 0.94 + 0.06 * float(_hash(tx, ty, 3) % 100) / 100.0   # nhiễu nhẹ cho đỡ đều
				if pulse:
					f *= 0.9 + 0.1 * sin(t * 1.6 + float(tx + ty) * 0.35)      # nước lăn tăn / dung nham nhấp nháy
				blit(ci, _pick(outs, tx, ty, 2), pos, ts, otint * Color(f, f, f, 1.0))
				continue
			var cell := Vector2i(tx, ty)
			if wall_set.has(cell):
				blit(ci, _pick(walls, tx, ty, 4), pos, ts, wtint)
				if not wall_set.has(Vector2i(tx, ty - 1)):
					ci.draw_rect(Rect2(pos, Vector2(tile, 2.0)), Color(1, 1, 1, 0.2))      # mép sáng phía bắc
				if not wall_set.has(Vector2i(tx, ty + 1)):                                   # phía nam lộ mặt đứng: tối + viền
					ci.draw_rect(Rect2(pos.x, pos.y + tile - 10.0, tile, 10.0), Color(0, 0, 0, 0.38))
					ci.draw_rect(Rect2(pos.x, pos.y + tile - 10.0, tile, 1.0), Color(0, 0, 0, 0.6))
			else:
				blit(ci, _pick(floors, tx, ty, 1), pos, ts, ftint)
				if wash.a > 0.0:
					ci.draw_rect(Rect2(pos, ts), wash)

## Vẽ sprite đặt gốc (điểm chạm đất) vào giữa-đáy ô tại pos. sy = co giãn dọc quanh gốc (cây lắc nhẹ).
static func draw_sprite(ci: CanvasItem, key: String, pos: Vector2, tile: float, tint: Color = Color.WHITE, sy: float = 1.0) -> void:
	var t := tex(key)
	if t == null:
		return
	var m: Array = meta(key)
	var sz := Vector2(float(m[0]), float(m[1])) * SCALE
	var feet := Vector2(float(m[2]), float(m[3])) * SCALE
	sz.y *= sy
	feet.y *= sy
	ci.draw_texture_rect(t, Rect2(pos + Vector2(tile / 2.0, tile - 1.0) - feet, sz), false, tint)

static func _wpick(groups: Array, rng: RandomNumberGenerator) -> Array:
	var total := 0
	for g in groups:
		total += int(g["w"])
	var pick := rng.randi() % total
	for g in groups:
		if pick < int(g["w"]):
			return g["f"]
		pick -= int(g["w"])
	return groups[0]["f"]

## Sinh decor: Array of {k: "tree"|"prop", x, y, f: key sprite, ph: pha}.
## Tránh viền map, tường, cổng, đền (cách >=4 ô với cây, >=2 ô với props) và chồng lên nhau (chiếm chỗ theo bề ngang sprite).
static func gen_decor(map_id: String, w: int, h: int, walls: Dictionary, gates: Array, temple: Vector2i, theme: String = "grass") -> Array:
	var out: Array = []
	if w <= 4 or h <= 4:
		return out
	var th := theme_def(theme)
	var tree_d: float = th["tree_density"]
	var prop_d: float = th["prop_density"]
	var trees: Array = th["trees"]
	var props: Array = th["props"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(map_id) & 0x7FFFFFFF
	var taken := {}
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var c := Vector2i(x, y)
			if walls.has(c) or taken.has(c):
				continue
			var near_key := _dist_to_keys(c, gates, temple)
			var r := rng.randf()
			var is_tree := r < tree_d and not trees.is_empty() and near_key >= 4
			var is_prop := r >= tree_d and r < tree_d + prop_d and not props.is_empty() and near_key >= 2
			if not (is_tree or is_prop):
				continue
			var keys: Array = _wpick(trees if is_tree else props, rng)
			var key := String(keys[rng.randi() % keys.size()])
			var rad := int(float(meta(key)[0]) * SCALE / 32.0 * 0.5)   # sprite rộng 2 ô -> chiếm 3x3
			for dy in range(-rad, rad + 1):
				for dx in range(-rad, rad + 1):
					taken[Vector2i(x + dx, y + dy)] = true
			out.append({"k": "tree" if is_tree else "prop", "x": x, "y": y, "f": key, "ph": rng.randi() % 8})
	return out

static func _dist_to_keys(c: Vector2i, gates: Array, temple: Vector2i) -> int:
	var d := maxi(absi(c.x - temple.x), absi(c.y - temple.y))
	for g in gates:
		d = mini(d, maxi(absi(c.x - g.x), absi(c.y - g.y)))
	return d
