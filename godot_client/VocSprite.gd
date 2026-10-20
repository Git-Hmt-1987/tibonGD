class_name VocSprite
extends RefCounted
## Animation 4 vocation từ sprite sheet (thay KnightSprite.gd). Mỗi vocation có 1 sheet lưới 4 cột; cấu hình ở SPECS.
## Trạng thái: IDLE / WALK / ATTACK (đánh thường, effect `hit` có `from`) / CAST (spell, gói `fx`) / DEAD.
## Mọi chỗ "đoán" hướng/hàng nằm trong SPECS — hình nhìn sai hướng hay sai hàng thì chỉ sửa ở đó.
##
## Khóa tùy chọn trong SPECS (có mặc định, các vocation cũ không cần khai báo):
##   flip (true)            : false = sheet có đủ 4 hướng riêng -> KHÔNG lật ngang (Paladin mới).
##   idle_n/idle_fps        : số khung + tốc độ idle (mặc định 4 khung, IDLE_FPS).
##   walk_n/walk_fps        : số khung + tốc độ đi (mặc định 4 khung, WALK_FPS). Chu kỳ chạy liên tục, không reset mỗi bước.
##   attack_first           : khung bắt đầu của lần đánh (bỏ phần giương cung, vì server báo đòn đã trúng/bắn ngay).
##   attack_time/cast_time  : giây cho 1 lần đánh / thi pháp (mặc định ATTACK_TIME / CAST_TIME).
##   attack_path/attack_cell/attack_feet : đòn đánh nằm ở atlas RIÊNG với kích thước ô khác (Druid: 192px, vì có hiệu ứng rộng);
##                            không khai báo thì dùng chung atlas/ô/chân với các trạng thái khác. Hàng `attack` tính theo atlas riêng đó.
##   dead_fallback          : không có asset gục -> xoay khung idle xuống 90° nằm ngang (tạo 1 lần khi nạp texture).
##
## Paladin + Druid (atlas 64px, đóng gói bằng tools/pack_frames.py): hàng 0-3 idle, 4-7 đi, 8-11 đánh (13 khung; Paladin thả tên ở khung 9,
##   Druid phóng lao rời tay ở khung 10), 12-15 thi pháp (7 khung); mỗi nhóm 4 hàng theo thứ tự xuống, lên, trái, phải.
##
## Layout chung (Knight/Sorcerer/Druid, ô 88px): hàng 0/1/2 idle xuống/lên/ngang, 3/4/5 đi xuống/lên/ngang,
##   6 đánh ngang, 7 đánh quay lưng, 8 thi pháp (4 khung), 9/10/11 ngồi/gục/quỳ (1 khung).

enum Dir { S, N, W, E }
enum State { IDLE, WALK, ATTACK, CAST, DEAD }

const IDLE_FPS := 4.0
const WALK_FPS := 10.0
const ATTACK_TIME := 0.30    # giây cho 1 lần đánh
const CAST_TIME := 0.45      # giây cho 1 lần thi pháp

# faces_left: hàng "ngang" trong sheet nhìn TRÁI? (true -> hướng Đông phải lật ngang)
# attack_faces_left: hàng đánh nhìn TRÁI?
const SPECS := {
	4: {  # Knight
		"path": "res://sprites/knight/knight_sheet.png",
		"cell": Vector2(88, 88), "feet": Vector2(44, 75), "scale": 0.5,
		"faces_left": true, "attack_faces_left": false,
		"idle": {Dir.S: 0, Dir.N: 1, Dir.W: 2, Dir.E: 2},
		"walk": {Dir.S: 3, Dir.N: 4, Dir.W: 5, Dir.E: 5},
		"attack": {Dir.S: 6, Dir.N: 7, Dir.W: 6, Dir.E: 6}, "attack_frames": 3,
		"cast": {Dir.S: 8, Dir.N: 8, Dir.W: 8, Dir.E: 8}, "cast_frames": 4,
		"dead_row": 10,
	},
	1: {  # Sorcerer
		"path": "res://sprites/sorcerer/sorcerer_sheet.png",
		"cell": Vector2(88, 88), "feet": Vector2(44, 75), "scale": 0.5,
		"faces_left": true, "attack_faces_left": false,
		"idle": {Dir.S: 0, Dir.N: 1, Dir.W: 2, Dir.E: 2},
		"walk": {Dir.S: 3, Dir.N: 4, Dir.W: 5, Dir.E: 5},
		"attack": {Dir.S: 6, Dir.N: 7, Dir.W: 6, Dir.E: 6}, "attack_frames": 4,
		"cast": {Dir.S: 8, Dir.N: 7, Dir.W: 8, Dir.E: 8}, "cast_frames": 4,
		"dead_row": 10,
	},
	2: {  # Druid (atlas chính 64px: idle/walk/cast; đòn đánh là atlas riêng 192px; đủ 4 hướng riêng nên không lật)
		"path": "res://sprites/druid/druid_atlas.png",
		"cell": Vector2(64, 64), "feet": Vector2(32, 62), "scale": 0.55,
		"flip": false, "faces_left": false, "attack_faces_left": false,
		"idle": {Dir.S: 0, Dir.N: 1, Dir.W: 2, Dir.E: 3}, "idle_n": 2, "idle_fps": 2.0,
		"walk": {Dir.S: 4, Dir.N: 5, Dir.W: 6, Dir.E: 7}, "walk_n": 9, "walk_fps": 14.0,
		"attack_path": "res://sprites/druid/druid_attack_atlas.png",
		"attack_cell": Vector2(192, 192), "attack_feet": Vector2(97, 126),
		"attack": {Dir.S: 0, Dir.N: 1, Dir.W: 2, Dir.E: 3}, "attack_frames": 8, "attack_first": 1, "attack_time": 0.4,
		"cast": {Dir.S: 8, Dir.N: 9, Dir.W: 10, Dir.E: 11}, "cast_frames": 7, "cast_time": 0.5,
		"dead_fallback": true,
	},
	3: {  # Paladin (atlas 64px do tools/pack_frames.py tạo; đủ 4 hướng riêng nên không lật)
		"path": "res://sprites/paladin/paladin_atlas.png",
		"cell": Vector2(64, 64), "feet": Vector2(32, 62), "scale": 0.63,
		"flip": false, "faces_left": false, "attack_faces_left": false,
		"idle": {Dir.S: 0, Dir.N: 1, Dir.W: 2, Dir.E: 3}, "idle_n": 2, "idle_fps": 2.0,
		"walk": {Dir.S: 4, Dir.N: 5, Dir.W: 6, Dir.E: 7}, "walk_n": 9, "walk_fps": 14.0,
		"attack": {Dir.S: 8, Dir.N: 9, Dir.W: 10, Dir.E: 11}, "attack_frames": 13, "attack_first": 6, "attack_time": 0.35,
		"cast": {Dir.S: 12, Dir.N: 13, Dir.W: 14, Dir.E: 15}, "cast_frames": 7, "cast_time": 0.5,
		"dead_fallback": true,
	},
}

static var _tex := {}      # voc (hoặc "voc:atk") -> Texture2D
static var _tried := {}    # cùng khóa -> bool
static var _lie := {}      # voc -> {tex, size, feet}: khung idle xoay 90° làm tư thế gục (chỉ vocation có dead_fallback)

static func attack_time(voc: int) -> float:
	return float(SPECS[voc].get("attack_time", ATTACK_TIME)) if SPECS.has(voc) else ATTACK_TIME

static func cast_time(voc: int) -> float:
	return float(SPECS[voc].get("cast_time", CAST_TIME)) if SPECS.has(voc) else CAST_TIME

## Tư thế gục dự phòng: cắt khung idle hướng xuống, xoay 90° theo chiều kim đồng hồ (đầu về bên phải), neo ở đáy-giữa thân.
static func _lie_info(voc: int) -> Dictionary:
	if _lie.has(voc):
		return _lie[voc]
	_lie[voc] = {}
	var tex := texture(voc)
	if tex == null:
		return _lie[voc]
	var sp: Dictionary = SPECS[voc]
	var cell: Vector2 = sp["cell"]
	var img := tex.get_image()
	if img == null:
		return _lie[voc]
	if img.is_compressed():
		img.decompress()
	var row: int = sp["idle"][Dir.S]
	var part := img.get_region(Rect2i(0, row * int(cell.y), int(cell.x), int(cell.y)))
	part.rotate_90(CLOCKWISE)
	var used := part.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return _lie[voc]
	_lie[voc] = {"tex": ImageTexture.create_from_image(part), "size": Vector2(part.get_size()),
		"feet": Vector2(used.position.x + used.size.x / 2.0, used.position.y + used.size.y)}
	return _lie[voc]

static func has(voc: int) -> bool:
	return SPECS.has(voc) and texture(voc) != null

## Texture chính của vocation. `atk = true` -> atlas riêng của đòn đánh (nếu spec có `attack_path`), không có thì trả texture chính.
static func texture(voc: int, atk := false) -> Texture2D:
	if not SPECS.has(voc):
		return null
	var key = voc
	var path: String = SPECS[voc]["path"]
	if atk and SPECS[voc].has("attack_path"):
		key = "%d:atk" % voc
		path = SPECS[voc]["attack_path"]
	if not _tex.has(key) and not _tried.get(key, false):
		_tried[key] = true
		if ResourceLoader.exists(path):
			_tex[key] = load(path)
		else:
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img:
				_tex[key] = ImageTexture.create_from_image(img)
	return _tex.get(key, null)

## dx,dy = bước di chuyển cuối cùng (Tibia: y-1 = lên/Bắc).
static func dir_from_delta(dx: int, dy: int, fallback: int = Dir.S) -> int:
	if dx == 0 and dy == 0:
		return fallback
	if absi(dx) > absi(dy):
		return Dir.E if dx > 0 else Dir.W
	return Dir.S if dy > 0 else Dir.N

## Khung hình hiện tại: {src: Rect2, flip: bool, feet: Vector2 (neo trong sheet)}. t = giây kể từ lúc bắt đầu trạng thái
## (IDLE: đồng hồ chung).
static func frame(voc: int, state: int, dir: int, t: float) -> Dictionary:
	var sp: Dictionary = SPECS[voc]
	var cell: Vector2 = sp["cell"]
	var row := 0
	var col := 0
	var faces_left: bool = sp["faces_left"]
	match state:
		State.WALK:
			row = sp["walk"][dir]
			col = int(t * float(sp.get("walk_fps", WALK_FPS))) % int(sp.get("walk_n", 4))
		State.ATTACK:
			row = sp["attack"][dir]
			var n: int = sp["attack_frames"]
			var first: int = sp.get("attack_first", 0)
			var span := maxi(1, n - first)
			col = first + clampi(int(t / float(sp.get("attack_time", ATTACK_TIME)) * span), 0, span - 1)
			faces_left = sp["attack_faces_left"]
			if sp.has("attack_path"):   # atlas riêng: ô và chân riêng, flip theo spec như cũ
				var acell: Vector2 = sp["attack_cell"]
				var aflip := false
				if sp.get("flip", true):
					aflip = (faces_left if dir == Dir.E else (not faces_left if dir == Dir.W else false))
				return {"src": Rect2(col * acell.x, row * acell.y, acell.x, acell.y), "flip": aflip, "feet": sp["attack_feet"], "atk": true}
		State.CAST:
			row = sp["cast"][dir]
			var n2: int = sp["cast_frames"]
			col = clampi(int(t / float(sp.get("cast_time", CAST_TIME)) * n2), 0, n2 - 1)
		State.DEAD:
			if sp.has("dead_rect"):
				var r: Rect2 = sp["dead_rect"]
				return {"src": r, "flip": false, "feet": Vector2(r.size.x / 2.0, r.size.y)}
			if sp.get("dead_fallback", false):
				var li := _lie_info(voc)
				if not li.is_empty():
					return {"src": Rect2(Vector2.ZERO, li["size"]), "flip": false, "feet": li["feet"], "lie": true}
				row = sp["idle"][Dir.S]   # chưa tạo được khung xoay -> đứng yên tạm
			else:
				row = sp["dead_row"]
		_:
			row = sp["idle"][dir]
			col = int(t * float(sp.get("idle_fps", IDLE_FPS))) % int(sp.get("idle_n", 4))
	var flip := false
	if state != State.DEAD and sp.get("flip", true):
		if dir == Dir.E:
			flip = faces_left
		elif dir == Dir.W:
			flip = not faces_left
	return {"src": Rect2(col * cell.x, row * cell.y, cell.x, cell.y), "flip": flip, "feet": sp["feet"]}

## Vẽ lên CanvasItem `ci` (gọi trong _draw): chân ở giữa-đáy ô `tile_pos` (góc trái-trên ô, cạnh `tile`).
const HERO_SCALE := 1.5   # phóng to nhân vật 1.5 lần (chân giữ nguyên vị trí, cao lên phía trên)

static func draw(ci: CanvasItem, voc: int, tile_pos: Vector2, tile: float, state: int, dir: int, t: float, tint := Color.WHITE) -> void:
	var tex := texture(voc)
	if tex == null:
		return
	var sp: Dictionary = SPECS[voc]
	var sc: float = float(sp["scale"]) * HERO_SCALE
	var f := frame(voc, state, dir, t)
	var src: Rect2 = f["src"]
	var feet: Vector2 = f["feet"]
	if f.get("atk", false):
		tex = texture(voc, true)   # atlas riêng của đòn đánh
		if tex == null:
			return
	if f.get("lie", false):
		tex = _lie_info(voc)["tex"] as Texture2D   # khung đã xoay nằm ngang, ghi đè texture chính
		tint = tint * Color(0.72, 0.72, 0.8)   # tối đi cho ra vẻ đã gục
	var feet_screen := tile_pos + Vector2(tile / 2.0, tile - 1.0)
	var size := src.size * sc
	var rect := Rect2(feet_screen - feet * sc, size)
	if f["flip"]:
		# lật quanh trục dọc qua chân (không phải giữa ô) để chân không bị lệch
		rect.position.x = feet_screen.x - (src.size.x - feet.x) * sc
		rect.size.x = -size.x
	ci.draw_texture_rect_region(tex, rect, src, tint)
