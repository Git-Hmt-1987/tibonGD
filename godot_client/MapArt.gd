class_name MapArt
extends RefCounted
## Đồ họa map từ bộ "Tibon Assets" (Tiny Swords): thảm cỏ, tường đá viền map, nước ngoài map, cây, props.
## Mọi thứ chỉ là hình (không có va chạm) — va chạm/tường do server quyết định (WALLS).
## Muốn đặt asset ở chỗ khác: sửa ASSET_ROOT. Decor sinh tự động theo map_id (cùng map -> cùng bố cục),
## sau này thay bằng dữ liệu map thật chỉ cần thay hàm gen_decor().

const ASSET_ROOT := "res://sprites/tibon/"
const SRC_TILE := 64.0                     # ô gốc 64px; vẽ ra TILE (WorldView.TILE=32) => tỉ lệ 0.5

# Vị trí ô trong atlas (đơn vị px gốc)
const GRASS := Rect2(64, 64, 64, 64)       # Tilemap_Flat: ô giữa của khối cỏ (liền mạch)
const SAND := Rect2(384, 64, 64, 64)       # Tilemap_Flat: ô giữa khối cát (dùng cho cổng/đền)
const STONE_TOP := Rect2(64, 64, 64, 64)   # Tilemap_Elevation: mặt đá
const STONE_FACE := Rect2(64, 192, 64, 64) # Tilemap_Elevation: mặt tường gạch (cạnh hướng nam)

# Cây: Tree.png khung 192x192; hàng 0 = 4 khung lắc lư, hàng 1 = 2 khung (cây nhỏ hơn)
const TREE_CELL := 192.0
const TREE_FEET := Vector2(98, 172)        # gốc cây trong khung
const TREE_SCALE := 0.40                   # 192px -> ~77px (≈ 2.4 ô cao)

# Props (deco/NN.png, 64x64 -> 32px = 1 ô). Nhóm theo loại, chọn theo trọng số.
const PROP_GROUPS := [
	{"w": 4, "ids": [7, 8, 9]},            # bụi cây
	{"w": 3, "ids": [4, 5, 6]},            # đá
	{"w": 3, "ids": [1, 2, 3]},            # nấm
	{"w": 3, "ids": [10, 11]},             # cỏ/cây nhỏ
	{"w": 1, "ids": [12, 13]},             # bí ngô
	{"w": 1, "ids": [14, 15]},             # xương
	{"w": 1, "ids": [16, 17]},             # biển chỉ (64x128)
]
const TREE_DENSITY := 0.035                # tỉ lệ ô có cây
const PROP_DENSITY := 0.06                 # tỉ lệ ô có props

static var _tex := {}

## Giao diện theo map (server gửi `map.theme`): nền, màu tường, mật độ cây/props. Chỉ là hình, không ảnh hưởng va chạm.
## "grass" = Dream Land + các map săn cũ; "mine" = hầm mỏ (Ironhollow, Quarry Pass); "hell" = địa ngục (Infernum, Ashen Bridge);
## "desert" = sa mạc (Dune Haven, Dust Road). Thêm theme mới: thêm một nhánh vào theme_def().
static func theme_def(name: String) -> Dictionary:
	match name:
		"mine":
			return {"floor": GRASS, "tint": Color(0.52, 0.48, 0.44), "wall_tint": Color(0.62, 0.58, 0.55),
				"water_tint": Color(0.35, 0.36, 0.42), "tree_density": 0.0, "prop_density": 0.07,
				"groups": [{"w": 6, "ids": [4, 5, 6]}, {"w": 1, "ids": [14, 15]}]}
		"hell":
			return {"floor": GRASS, "tint": Color(0.72, 0.26, 0.2), "wall_tint": Color(0.5, 0.25, 0.25),
				"water_tint": Color(1.0, 0.4, 0.15), "tree_density": 0.0, "prop_density": 0.07,
				"groups": [{"w": 4, "ids": [14, 15]}, {"w": 3, "ids": [4, 5, 6]}]}
		"sky":   # thành phố trên mây: nền xanh nhạt như mây, ngoài map là bầu trời sáng
			return {"floor": GRASS, "tint": Color(0.86, 0.93, 1.0), "wall_tint": Color(0.93, 0.96, 1.0),
				"water_tint": Color(0.78, 0.9, 1.0), "tree_density": 0.0, "prop_density": 0.04,
				"groups": [{"w": 3, "ids": [4, 5, 6]}, {"w": 1, "ids": [10, 11]}]}
		"desert":
			return {"floor": SAND, "tint": Color(1.0, 0.94, 0.78), "wall_tint": Color(1.0, 0.88, 0.68),
				"water_tint": Color(0.85, 0.8, 0.55), "tree_density": 0.0, "prop_density": 0.05,
				"groups": [{"w": 3, "ids": [4, 5, 6]}, {"w": 2, "ids": [14, 15]}, {"w": 2, "ids": [10, 11]}]}
	return {"floor": GRASS, "tint": Color(1, 1, 1), "wall_tint": Color(1, 1, 1), "water_tint": Color(1, 1, 1),
		"tree_density": TREE_DENSITY, "prop_density": PROP_DENSITY, "groups": PROP_GROUPS}

static func tex(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var path := ASSET_ROOT + name
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	else:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			t = ImageTexture.create_from_image(img)
	_tex[name] = t
	return t

static func ready() -> bool:
	return tex("Tilemap_Flat.png") != null and tex("Tilemap_Elevation.png") != null

## Sinh decor cho map: Array of {k: "tree"|"prop", x, y, v (biến thể/ id), ph (pha animation)}.
## Tránh: viền map, tường, cổng, đền (bán kính 3 với cây, 1 với props).
static func gen_decor(map_id: String, w: int, h: int, walls: Dictionary, gates: Array, temple: Vector2i, theme: String = "grass") -> Array:
	var out: Array = []
	var th := theme_def(theme)
	var tree_d: float = th["tree_density"]
	var prop_d: float = th["prop_density"]
	var groups: Array = th["groups"]
	if w <= 4 or h <= 4:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(map_id) & 0x7FFFFFFF
	var weights := 0
	for g in groups:
		weights += int(g["w"])
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var c := Vector2i(x, y)
			if walls.has(c):
				continue
			var near_key := _dist_to_keys(c, gates, temple)
			var r := rng.randf()
			if r < tree_d:
				if near_key >= 4:
					out.append({"k": "tree", "x": x, "y": y, "v": rng.randi() % 3, "ph": rng.randi() % 4})
			elif r < tree_d + prop_d:
				if near_key >= 2:
					var pick := rng.randi() % weights
					var ids: Array = groups[0]["ids"]
					for g in groups:
						if pick < int(g["w"]):
							ids = g["ids"]
							break
						pick -= int(g["w"])
					out.append({"k": "prop", "x": x, "y": y, "v": int(ids[rng.randi() % ids.size()]), "ph": 0})
	return out

static func _dist_to_keys(c: Vector2i, gates: Array, temple: Vector2i) -> int:
	var d := maxi(absi(c.x - temple.x), absi(c.y - temple.y))
	for g in gates:
		d = mini(d, maxi(absi(c.x - g.x), absi(c.y - g.y)))
	return d
