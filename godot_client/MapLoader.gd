extends TileMapLayer
## Import map.json (xuất từ tibia_py/otbm.py) vào TileMapLayer.
## Cách dùng (khi đã có map.json + TileSet 32x32 từ sprites):
## 1. Tạo TileMapLayer node trong scene, gắn script này.
## 2. Gán tile_set trong editor, rồi gọi build_from_json("res://map.json").
## Hiện tại chưa có map.json nên script không tự chạy — không ảnh hưởng F5.

func build_from_json(path: String) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null or not data.has("tiles"):
		push_error("MapLoader: bad map.json")
		return
	for t in data["tiles"]:
		var items: Array = t.get("items", [])
		var atlas := Vector2i(0, 0)
		if items.size() > 0:
			atlas = ItemDB.atlas_for(int(items[0].get("id", 0)))
		set_cell(Vector2i(int(t["x"]), int(t["y"])), 0, atlas)
