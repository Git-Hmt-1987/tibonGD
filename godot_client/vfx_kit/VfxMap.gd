class_name VfxMap
extends RefCounted
## BẢNG ÁNH XẠ (chỉ dữ liệu + vài hàm tra cứu) từ thông tin server gửi -> tên kiểu hiệu ứng trong vfx_kit/vfx_defs.gd.
## Đây là NƠI DUY NHẤT cần sửa khi muốn đổi "spell nào dùng hiệu ứng nào".
##
## Kiểu hiệu ứng hợp lệ = khóa của VfxDefs.KINDS: fire energy ice death earth holy physical slash.
## Thêm kiểu mới: thêm vào vfx_kit/vfx_defs.gd rồi trỏ tới nó ở các bảng dưới.
##
## Thứ tự ưu tiên khi chọn kiểu (kind_for): SPELL_KIND > ANI_KIND > ME_KIND > ELEMENT_KIND > từ khóa trong tên hằng.
## (area_fx dùng kind_for_me: chỉ ME_KIND, không đoán từ khóa.)
## Không tra ra -> "" (VfxBridge trả false, Main quay về hiệu ứng cũ: sprite skin hoặc khối màu tạm).

## Ghi đè theo id spell (id spell trong gói `spells`, vd "exori flam"). Để trống = chỉ dựa vào hằng/element.
const SPELL_KIND := {
}

## Đạn bay (gói fx.ani / shoot_fx.effect). Dữ liệu thật của 50 spell đơn mục tiêu chỉ dùng các hằng dưới đây.
const ANI_KIND := {
	"CONST_ANI_FIRE": "fire",
	"CONST_ANI_EXPLOSION": "fire",
	"CONST_ANI_ENERGY": "energy",
	"CONST_ANI_ENERGYBALL": "energy",
	"CONST_ANI_ICE": "ice",
	"CONST_ANI_SMALLICE": "ice",
	"CONST_ANI_DEATH": "death",
	"CONST_ANI_SUDDENDEATH": "death",
	"CONST_ANI_EARTH": "earth",
	"CONST_ANI_SMALLEARTH": "earth",
	"CONST_ANI_POISON": "earth",
	"CONST_ANI_HOLY": "holy",
	"CONST_ANI_SMALLHOLY": "holy",
	"CONST_ANI_WEAPONTYPE": "slash",       # spell đánh bằng vũ khí (Brutal Strike...): vệt chém tại mục tiêu
	"CONST_ANI_ETHEREALSPEAR": "physical",
}

## Hiệu ứng trên ô (gói fx.me / area_fx.effect), dùng khi spell không có đạn hoặc đạn lạ.
const ME_KIND := {
	"CONST_ME_FIREATTACK": "fire", "CONST_ME_HITBYFIRE": "fire", "CONST_ME_FIREAREA": "fire", "CONST_ME_EXPLOSIONAREA": "fire",
	"CONST_ME_ENERGYAREA": "energy", "CONST_ME_ENERGYHIT": "energy",
	"CONST_ME_ICEATTACK": "ice", "CONST_ME_ICEAREA": "ice",
	"CONST_ME_MORTAREA": "death", "CONST_ME_SMALLCLOUDS": "death",
	"CONST_ME_CARNIPHILA": "earth", "CONST_ME_SMALLPLANTS": "earth", "CONST_ME_GREEN_RINGS": "earth", "CONST_ME_STONES": "earth",
	"CONST_ME_HOLYDAMAGE": "holy", "CONST_ME_HOLYAREA": "holy",
	"CONST_ME_HITAREA": "physical", "CONST_ME_DRAWBLOOD": "physical", "CONST_ME_GROUNDSHAKER": "physical",
	"CONST_ME_ICETORNADO": "ice", "CONST_ME_BIGCLOUDS": "death",
}

## Element của spell (trường `element` trong gói `spells`; chỉ biết với spell do CHÍNH MÌNH cast).
const ELEMENT_KIND := {
	"COMBAT_FIREDAMAGE": "fire",
	"COMBAT_ENERGYDAMAGE": "energy",
	"COMBAT_ICEDAMAGE": "ice",
	"COMBAT_DEATHDAMAGE": "death",
	"COMBAT_EARTHDAMAGE": "earth",
	"COMBAT_HOLYDAMAGE": "holy",
	"COMBAT_PHYSICALDAMAGE": "physical",
}

## Dự phòng theo từ khóa trong tên hằng lạ (giống Main._const_fx_color). Thứ tự quan trọng (khớp đầu tiên thắng).
const KEYWORD_KIND := [
	[["ICE", "FREEZ", "SNOW"], "ice"],
	[["ENERGY", "ELECTR", "THUNDER"], "energy"],
	[["HOLY", "DIVINE"], "holy"],
	[["DEATH", "MORT"], "death"],
	[["EARTH", "POISON", "PLANT", "GREEN"], "earth"],
	[["FIRE", "FLAM", "EXPLOSION"], "fire"],
]

## Đánh thường (effect hit có `from`): kiểu theo nghề người đánh. Quái đánh = "physical".
## Khóa = id nghề (xem Main.VOC_NAMES: 1 Sorc, 2 Druid, 3 Paladin, 4 Knight, 9 Monk).
const BASIC_KIND_DEFAULT := "physical"
const BASIC_KIND_BY_VOC := {
	4: "slash",
}


static func kind_for(spell: String, element: String, ani: String, me: String) -> String:
	if spell != "" and SPELL_KIND.has(spell):
		return str(SPELL_KIND[spell])
	if ani != "" and ANI_KIND.has(ani):
		return str(ANI_KIND[ani])
	if me != "" and ME_KIND.has(me):
		return str(ME_KIND[me])
	if element != "" and ELEMENT_KIND.has(element):
		return str(ELEMENT_KIND[element])
	var names := [ani.to_upper(), me.to_upper()]
	for nm in names:
		if nm == "" or nm.ends_with("_NONE"):
			continue
		for kv in KEYWORD_KIND:
			for kw in kv[0]:
				if nm.contains(kw):
					return str(kv[1])
	return ""


## Tra CHẶT cho gói area_fx (chiêu quái, rune): chỉ khớp bảng ME_KIND, KHÔNG đoán theo từ khóa, vì area_fx còn chở cả
## hiệu ứng không phải đòn đánh (CONST_ME_MAGIC_GREEN hồi máu, TELEPORT...) mà không được vẽ thành đòn tấn công.
static func kind_for_me(me: String) -> String:
	return str(ME_KIND.get(me, ""))


## attacker_kind: "player" | "creature" (kinds[...] của Main); voc: id nghề (0 nếu không biết)
static func basic_kind(attacker_kind: String, voc: int) -> String:
	if attacker_kind == "player" and BASIC_KIND_BY_VOC.has(voc):
		return str(BASIC_KIND_BY_VOC[voc])
	return BASIC_KIND_DEFAULT
