class_name ItemDB
extends RefCounted
## Bảng ánh xạ item_id Tibia -> atlas coords trong TileSet Godot.
## Bản stub: chia đều theo grid 32 cột. Khi có items.json thật
## (từ appearances.dat + items.xml) thì thay bằng dict lookup.

static func atlas_for(item_id: int) -> Vector2i:
	return Vector2i(item_id % 32, item_id / 32)
