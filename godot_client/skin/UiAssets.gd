class_name UiAssets
extends RefCounted
## Tìm + cache asset (PNG / font / skin.cfg) trong res://assets/.
## Thiếu file = trả null để nơi gọi tự dùng hình tạm cũ. KHÔNG bao giờ crash vì thiếu asset.
## Quy ước thư mục + tên file: assets/README.md và README.md trong từng thư mục con.

const ROOT := "res://assets/"
const LEGACY_ICON_DIR := "res://icons/"   # chỗ cũ của icon: vẫn đọc để không mất icon đã thả
const ICON_GROUPS := ["buttons", "fight", "status", "items", "spells", "skills", "classes"]
const FONT_EXTS := ["ttf", "otf", "woff2", "woff"]
const CFG_PATH := "res://assets/skin.cfg"

## Danh sách asset "mong đợi" (chỉ dùng để in báo cáo [skin] lúc chạy từ editor). Mục "fonts/<tên>" = không cần đuôi.
const MANIFEST := [
	"ui/panels/panel.png", "ui/panels/login.png", "ui/panels/tooltip.png",
	"ui/buttons/button_normal.png", "ui/buttons/button_hover.png", "ui/buttons/button_pressed.png", "ui/buttons/button_disabled.png",
	"ui/buttons/icon_normal.png", "ui/buttons/icon_hover.png", "ui/buttons/icon_pressed.png",
	"ui/buttons/fight_normal.png", "ui/buttons/fight_hover.png", "ui/buttons/fight_pressed.png",
	"ui/bars/hp_bg.png", "ui/bars/hp_fill.png", "ui/bars/mana_bg.png", "ui/bars/mana_fill.png",
	"ui/bars/stamina_bg.png", "ui/bars/stamina_fill.png", "ui/bars/exp_bg.png", "ui/bars/exp_fill.png",
	"ui/bars/target_bg.png", "ui/bars/target_fill.png",
	"ui/slots/slot_normal.png", "ui/slots/slot_hover.png", "ui/slots/slot_pressed.png",
	"ui/slots/slot_item_normal.png", "ui/slots/slot_spell_normal.png", "ui/slots/slot_empty_normal.png",
	"ui/misc/login_bg.png",
	"icons/fight/fight_attack.png", "icons/fight/fight_balanced.png", "icons/fight/fight_defense.png",
	"icons/status/status_premium.png",
	"icons/buttons/btn_char.png", "icons/buttons/btn_skills.png", "icons/buttons/btn_battle.png", "icons/buttons/btn_vip.png",
	"icons/buttons/btn_status.png", "icons/buttons/btn_auto.png", "icons/buttons/btn_spell.png", "icons/buttons/btn_logout.png",
	"fonts/ui", "fonts/ui_bold", "fonts/title", "fonts/damage", "fonts/world",
	"fx/element/fire.png", "fx/element/ice.png", "fx/element/energy.png", "fx/element/earth.png",
	"fx/element/holy.png", "fx/element/death.png", "fx/element/physical.png", "fx/element/healing.png",
	"fx/element/fire_shot.png", "fx/element/ice_shot.png", "fx/element/energy_shot.png", "fx/element/earth_shot.png",
	"fx/hit/hit.png", "fx/hit/heal.png", "fx/hit/death.png", "fx/hit/mana.png",
	"fx/basic/bolt.png", "fx/basic/stone.png", "fx/basic/arrow.png",
]

static var _tex_cache := {}
static var _font_cache := {}
static var _cfg: ConfigFile = null


## Ảnh trong assets/ theo đường dẫn tương đối ("ui/panels/panel.png"). Không có = null.
static func tex(rel: String) -> Texture2D:
	if _tex_cache.has(rel):
		return _tex_cache[rel]
	var t: Texture2D = null
	var path := ROOT + rel
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_tex_cache[rel] = t
	return t


## Ảnh đầu tiên có thật trong danh sách đường dẫn tương đối.
static func first(rels: Array) -> Texture2D:
	for r in rels:
		var t := tex(str(r))
		if t != null:
			return t
	return null


## Icon theo id ("btn_char", "item_238", "spell_ultimate_healing"...): tìm trong assets/icons/<nhóm>/, assets/icons/, rồi thư mục cũ res://icons/.
static func icon(icon_id: String) -> Texture2D:
	if icon_id == "":
		return null
	for g in ICON_GROUPS:
		var t := tex("icons/%s/%s.png" % [g, icon_id])
		if t != null:
			return t
	var t2 := tex("icons/%s.png" % icon_id)
	if t2 != null:
		return t2
	var key := "legacy:" + icon_id
	if _tex_cache.has(key):
		return _tex_cache[key]
	var lt: Texture2D = null
	var lp := LEGACY_ICON_DIR + icon_id + ".png"
	if ResourceLoader.exists(lp):
		lt = load(lp) as Texture2D
	_tex_cache[key] = lt
	return lt


## Font trong assets/fonts/<tên>.(ttf|otf|woff2|woff). Không có = null.
static func font(font_name: String) -> Font:
	if _font_cache.has(font_name):
		return _font_cache[font_name]
	var f: Font = null
	for ext in FONT_EXTS:
		var p := "%sfonts/%s.%s" % [ROOT, font_name, ext]
		if ResourceLoader.exists(p):
			f = load(p) as Font
			if f != null:
				break
	_font_cache[font_name] = f
	return f


static func cfg() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(CFG_PATH)   # thiếu/hỏng file = rỗng -> mọi giá trị lấy mặc định trong code
	return _cfg


static func cfg_get(section: String, key: String, def_val: Variant) -> Variant:
	var c := cfg()
	if not c.has_section_key(section, key):   # kiểm tra trước: truyền def_val = null vào get_value() sẽ báo lỗi "no default was given"
		return def_val
	return c.get_value(section, key, def_val)


## Ảnh theo nghề: kind = "icon" (<nghề>_icon.png, avatar tròn) | "class" (<nghề>_class.png, hero đứng). Đặt trong assets/icons/classes/.
## voc_name: "Knight" / "Paladin" / "Druid" / "Sorcerer" (không phân biệt hoa thường; chấp nhận cả tên file viết sai chính tả).
static func class_tex(voc_name: String, kind: String) -> Texture2D:
	var v := voc_name.strip_edges().to_lower()
	if v == "":
		return null
	var names := [v]
	if v == "sorcerer":
		names += ["socerer", "socrcer", "sorceror", "sorcer"]
	for nm in names:
		var t := icon("%s_%s" % [nm, kind])
		if t != null:
			return t
	return null


## Xóa cache (gọi nếu muốn nạp lại asset trong lúc chạy).
static func reload() -> void:
	_tex_cache.clear()
	_font_cache.clear()
	_cfg = null


static func _has(rel: String) -> bool:
	if rel.begins_with("fonts/"):
		return font(rel.substr(6)) != null
	return tex(rel) != null


## In báo cáo asset đã nhận (gọi từ Main._ready khi chạy bằng editor). verbose = in cả file còn thiếu.
static func print_report(verbose := false) -> void:
	var have: Array = []
	var miss: Array = []
	for rel in MANIFEST:
		if _has(str(rel)):
			have.append(rel)
		else:
			miss.append(rel)
	var cfg_note := "" if FileAccess.file_exists(CFG_PATH) else " (chưa có skin.cfg -> dùng mặc định)"
	print("[skin] %d/%d asset đã nhận%s" % [have.size(), MANIFEST.size(), cfg_note])
	for r in have:
		print("[skin]   + ", r)
	if verbose:
		for r in miss:
			print("[skin]   - ", r)
