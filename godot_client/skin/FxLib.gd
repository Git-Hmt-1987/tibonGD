class_name FxLib
extends RefCounted
## Hiệu ứng spell / đạn / trúng đòn dạng "dải khung" (sprite strip) đọc từ assets/fx/.
## Dán PNG đúng tên là chạy; không có PNG thì WorldView vẽ khối màu tạm như cũ.
##
## Thứ tự tìm (đầu tiên có file thì dùng):
##   ô bị ảnh hưởng : spell/<id>        -> me/<const_me>       -> element/<hệ>
##   đạn bay        : spell/<id>_shot   -> shoot/<const_ani>   -> element/<hệ>_shot
##   trên người cast: spell/<id>_cast   -> element/<hệ>_cast
##   trúng đòn      : hit/<hit|heal|death|mana>
##   đạn đánh thường: basic/<bolt|stone|arrow>
## Định dạng PNG: các khung xếp trái->phải, trên->dưới; khung vuông = chiều cao ảnh (khác thì khai báo trong skin.cfg
## mục [fx.<thư mục>.<tên>]: frame_w, frame_h, frames, fps, loop, size, offset_y).

const DIR := "fx/"
const DEFAULT_FPS := 14.0

static var _cache := {}   # rel -> Dictionary (rỗng = không có file)


## "CONST_ME_MAGIC_BLUE" + prefix "const_me_" -> "magic_blue"
static func const_key(const_name: String, prefix: String) -> String:
	var s := const_name.strip_edges().to_lower()
	if s.begins_with(prefix):
		s = s.substr(prefix.length())
	return s


## "COMBAT_FIREDAMAGE" -> "fire", "COMBAT_HEALING" -> "healing", "COMBAT_PHYSICALDAMAGE" -> "physical"
static func element_key(element: String) -> String:
	var s := element.strip_edges().to_lower()
	if s.begins_with("combat_"):
		s = s.substr(7)
	if s.ends_with("damage"):
		s = s.substr(0, s.length() - 6)
	return s


## Nạp một dải khung. rel không có đuôi, vd "element/fire" hoặc "me/magic_blue". Rỗng {} nếu không có file.
static func load_def(rel: String) -> Dictionary:
	if _cache.has(rel):
		return _cache[rel]
	var d := {}
	var t := UiAssets.tex(DIR + rel + ".png")
	if t != null:
		var sec := "fx." + rel.replace("/", ".")
		var w := t.get_width()
		var h := t.get_height()
		var fh := maxi(1, int(UiAssets.cfg_get(sec, "frame_h", h)))
		var fw := maxi(1, int(UiAssets.cfg_get(sec, "frame_w", fh)))
		var cols := maxi(1, floori(float(w) / float(fw)))
		var rows := maxi(1, floori(float(h) / float(fh)))
		var is_shot := rel.begins_with("shoot/") or rel.begins_with("basic/") or rel.ends_with("_shot")
		d = {
			"tex": t, "fw": fw, "fh": fh, "cols": cols,
			"frames": maxi(1, int(UiAssets.cfg_get(sec, "frames", cols * rows))),
			"fps": maxf(1.0, float(UiAssets.cfg_get(sec, "fps", DEFAULT_FPS))),
			"loop": bool(UiAssets.cfg_get(sec, "loop", is_shot)),   # đạn mặc định lặp khung; hiệu ứng ô chạy 1 lần
			"size": float(UiAssets.cfg_get(sec, "size", 1.0)),      # chiều cao khung vẽ ra, tính theo số ô
			"offset_y": float(UiAssets.cfg_get(sec, "offset_y", 0.0)),   # dịch dọc, tính theo ô (âm = lên)
		}
	_cache[rel] = d
	return d


static func _first(rels: Array) -> Dictionary:
	for r in rels:
		var d := load_def(str(r))
		if not d.is_empty():
			return d
	return {}


static func for_cell(me: String, spell: String, element: String) -> Dictionary:
	var rels: Array = []
	if spell != "":
		rels.append("spell/" + spell)
	if me != "":
		rels.append("me/" + const_key(me, "const_me_"))
	if element != "":
		rels.append("element/" + element_key(element))
	return _first(rels)


static func for_shot(ani: String, spell: String, element: String) -> Dictionary:
	var rels: Array = []
	if spell != "":
		rels.append("spell/%s_shot" % spell)
	if ani != "":
		rels.append("shoot/" + const_key(ani, "const_ani_"))
	if element != "":
		rels.append("element/%s_shot" % element_key(element))
	return _first(rels)


static func for_cast(spell: String, element: String) -> Dictionary:
	var rels: Array = []
	if spell != "":
		rels.append("spell/%s_cast" % spell)
	if element != "":
		rels.append("element/%s_cast" % element_key(element))
	return _first(rels)


## kind: "hit" | "heal" | "death" | "mana"
static func for_hit(kind: String) -> Dictionary:
	return load_def("hit/" + kind) if kind != "" else {}


## style: "bolt" | "stone" | "arrow" (đạn đánh thường theo nghề)
static func for_basic(style: String) -> Dictionary:
	return load_def("basic/" + style) if style != "" else {}


## Thời lượng chạy hết dải khung (giây), tối thiểu 0.2s.
static func duration(d: Dictionary) -> float:
	return maxf(0.2, float(d["frames"]) / float(d["fps"]))


static func frame_index(d: Dictionary, age: float) -> int:
	var n: int = d["frames"]
	var i := maxi(0, int(age * float(d["fps"])))
	if bool(d["loop"]):
		return i % n
	return mini(i, n - 1)


## Vẽ khung hiện tại, căn GIỮA tại `center` (tọa độ của `ci`). tile = cạnh 1 ô (px). age = giây kể từ lúc bắt đầu.
static func draw_at(ci: CanvasItem, d: Dictionary, center: Vector2, tile: float, age: float, mod := Color.WHITE) -> void:
	var fw: int = d["fw"]
	var fh: int = d["fh"]
	var cols: int = d["cols"]
	var idx := frame_index(d, age)
	var src := Rect2(float((idx % cols) * fw), float(floori(float(idx) / float(cols)) * fh), float(fw), float(fh))
	var dh := tile * float(d["size"])
	var dw := dh * float(fw) / float(fh)
	var pos := center + Vector2(-dw * 0.5, -dh * 0.5 + tile * float(d["offset_y"]))
	ci.draw_texture_rect_region(d["tex"], Rect2(pos, Vector2(dw, dh)), src, mod)
