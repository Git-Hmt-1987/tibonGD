extends Node
## Test tích hợp VFX trên client THẬT (Main.tscn) bằng gói tin server GIẢ LẬP đi qua Main._handle.
## Chạy (cần màn hình, vd Windows/Linux có GPU hoặc xvfb):
##     godot --path godot_client res://vfx/test/VfxIntegrationTest.tscn
## Chạy không màn hình (CI), vẫn kiểm được lỗi script nhưng không có ảnh:
##     godot --headless --path godot_client res://vfx/test/VfxIntegrationTest.tscn
## Ảnh chụp lưu ở user://vfx_it/ (đường dẫn thật in ra ở cuối). Thoát bằng mã 1 nếu có kiểm tra FAIL.
## Kịch bản: spell đơn lửa/sét/băng/death/đất/thánh, đánh thường knight, spell vũ khí,
## spell VÙNG (sóng, chùm tia, vòng quanh người, vòng lớn 61 ô, rune cầu 2 gói fx, area_fx của quái, hằng không phải đòn rơi về hiệu ứng cũ),
## quái chết bốc hơi, zoom x2, rồi kiểm tra không còn node hiệu ứng nào rò rỉ.


# Ô thật do server tính (tibia_py/spellcast.area_cells), người cast tại (10,10) hướng đông; rune cầu lửa thả vào (15,10).
const AOE_ENERGY_WAVE := [[15,9],[15,10],[15,11],[14,9],[14,10],[14,11],[13,9],[13,10],[13,11],[12,10],[11,10]]
const AOE_ENERGY_BEAM := [[15,10],[14,10],[13,10],[12,10],[11,10]]
const AOE_BERSERK := [[9,9],[10,9],[11,9],[9,10],[10,10],[11,10],[9,11],[10,11],[11,11]]
const AOE_ETERNAL_WINTER := [[10,5],[9,6],[10,6],[11,6],[8,7],[9,7],[10,7],[11,7],[12,7],[7,8],[8,8],[9,8],[10,8],[11,8],[12,8],[13,8],[6,9],[7,9],[8,9],[9,9],[10,9],[11,9],[12,9],[13,9],[14,9],[5,10],[6,10],[7,10],[8,10],[9,10],[10,10],[11,10],[12,10],[13,10],[14,10],[15,10],[6,11],[7,11],[8,11],[9,11],[10,11],[11,11],[12,11],[13,11],[14,11],[7,12],[8,12],[9,12],[10,12],[11,12],[12,12],[13,12],[8,13],[9,13],[10,13],[11,13],[12,13],[9,14],[10,14],[11,14],[10,15]]
const AOE_FIRE_WAVE := [[14,8],[14,9],[14,10],[14,11],[14,12],[13,9],[13,10],[13,11],[12,9],[12,10],[12,11],[11,10]]
const AOE_GREAT_FIREBALL := [[18,9],[18,10],[18,11],[17,8],[17,9],[17,10],[17,11],[17,12],[16,7],[16,8],[16,9],[16,10],[16,11],[16,12],[16,13],[15,7],[15,8],[15,9],[15,10],[15,11],[15,12],[15,13],[14,7],[14,8],[14,9],[14,10],[14,11],[14,12],[14,13],[13,8],[13,9],[13,10],[13,11],[13,12],[12,9],[12,10],[12,11]]

var main: Control
var fails := 0
var shots := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://vfx_it")
	main = load("res://Main.tscn").instantiate()
	add_child(main)
	await _wait(0.6)
	_h({"op": "hello", "id": "p1", "name": "Hero", "vocation": 4, "x": 10, "y": 10, "level": 50, "hp": 500, "max_hp": 500,
		"mana": 100, "max_mana": 100})
	_h({"op": "map", "id": "city", "name": "Test", "w": 30, "h": 30, "walls": [], "gates": [], "temple": [10, 10], "theme": "grass"})
	_h({"op": "spawn", "id": "m1", "kind": "creature", "name": "Rat", "x": 15, "y": 10, "hp": 100, "max_hp": 100})
	_h({"op": "spawn", "id": "m2", "kind": "creature", "name": "Rotworm", "x": 15, "y": 13, "hp": 300, "max_hp": 300})
	_h({"op": "spawn", "id": "m3", "kind": "creature", "name": "Troll", "x": 13, "y": 7, "hp": 2000, "max_hp": 2000})
	await _wait(0.6)

	# Spell đơn mục tiêu: server gửi effect hit TRƯỚC rồi mới tới fx (đúng thứ tự thật) -> không được vẽ thêm hiệu ứng đánh thường
	for case in [
		["fire", "CONST_ME_FIREATTACK", "CONST_ANI_FIRE"], ["energy", "CONST_ME_ENERGYAREA", "CONST_ANI_ENERGY"],
		["ice", "CONST_ME_ICEATTACK", "CONST_ANI_SMALLICE"], ["death", "CONST_ME_MORTAREA", "CONST_ANI_DEATH"],
		["earth", "CONST_ME_STONES", "CONST_ANI_EARTH"], ["holy", "CONST_ME_HOLYDAMAGE", "CONST_ANI_SMALLHOLY"]]:
		_h({"op": "effect", "kind": "hit", "id": "m1", "dmg": 30, "from": "p1"})
		_h({"op": "fx", "id": "p1", "from": [10, 10], "me": case[1], "ani": case[2], "tiles": [[15, 10]]})
		_check(main.vfx._pending.is_empty(), "%s: đòn của spell phải được loại khỏi hiệu ứng đánh thường" % case[0])
		await _wait(0.25)
		await _snap(case[0] + "_fly")
		await _wait(0.45)
		await _snap(case[0] + "_hit")
		await _wait(0.6)

	# Đánh thường knight (slash) và spell vũ khí
	_h({"op": "effect", "kind": "hit", "id": "m1", "dmg": 25, "from": "p1"})
	_check(main.vfx._pending.size() == 1, "đánh thường phải xếp hàng chờ (DEFER_S)")
	await _wait(0.15)
	_check(main.vfx._pending.is_empty(), "đánh thường phải được vẽ sau DEFER_S")
	await _snap("basic_slash")
	await _wait(0.6)
	_h({"op": "fx", "id": "p1", "from": [10, 10], "me": "CONST_ME_HITAREA", "ani": "CONST_ANI_WEAPONTYPE", "tiles": [[15, 13]]})
	await _wait(0.12)
	await _snap("weapon_spell")
	await _wait(0.6)

	# ---- Spell VÙNG (AOE) ----
	var peak := 0
	await _aoe("energy_wave", {"op": "fx", "id": "p1", "from": [10, 10], "me": "CONST_ME_ENERGYAREA", "ani": "CONST_ANI_ENERGY", "tiles": AOE_ENERGY_WAVE})
	await _aoe("energy_beam", {"op": "fx", "id": "p1", "from": [10, 10], "me": "CONST_ME_ENERGYHIT", "tiles": AOE_ENERGY_BEAM})
	await _aoe("fire_wave", {"op": "fx", "id": "p1", "from": [10, 10], "me": "CONST_ME_HITBYFIRE", "tiles": AOE_FIRE_WAVE})
	await _aoe("berserk", {"op": "fx", "id": "p1", "from": [10, 10], "me": "CONST_ME_HITAREA", "tiles": AOE_BERSERK})
	var ew := {"op": "fx", "id": "p1", "from": [10, 10], "me": "CONST_ME_ICETORNADO", "tiles": AOE_ETERNAL_WINTER}
	_check(main.vfx.on_fx(ew), "Eternal Winter (61 ô) phải do vfx_kit vẽ")
	await _wait(0.25)
	peak = main.vfx.layer.get_child_count()
	await _snap("aoe_eternal_winter_1")
	await _wait(0.3)
	await _snap("aoe_eternal_winter_2")
	_check(peak > 20 and peak < 400, "Eternal Winter: số node hiệu ứng bất thường (%d)" % peak)
	await _wait(1.2)
	# Rune cầu lửa: server gửi 2 gói (đạn tới tâm, rồi `me` trên cả vùng). Tâm chỉ được nổ MỘT lần.
	_h({"op": "fx", "id": "p1", "from": [10, 10], "ani": "CONST_ANI_FIRE", "tiles": [[15, 10]]})
	await _wait(0.1)
	_h({"op": "fx", "id": "p1", "from": [10, 10], "me": "CONST_ME_FIREAREA", "tiles": AOE_GREAT_FIREBALL})
	await _wait(0.45)
	await _snap("aoe_rune_ball_1")
	await _wait(0.3)
	await _snap("aoe_rune_ball_2")
	await _wait(0.9)
	# area_fx của chiêu quái: hằng tấn công -> vfx_kit; hằng không phải đòn (buff/hồi máu) -> rơi về khối màu cũ
	_check(main.vfx.on_area_fx({"op": "area_fx", "effect": "CONST_ME_FIREAREA", "tiles": [[12, 10], [12, 11], [13, 10], [13, 11]]}),
		"area_fx tấn công phải do vfx_kit vẽ")
	_check(not main.vfx.on_area_fx({"op": "area_fx", "effect": "CONST_ME_MAGIC_BLUE", "tiles": [[12, 10], [13, 10]]}),
		"area_fx buff phải rơi về hiệu ứng cũ")
	_check(not main.vfx.on_fx({"op": "fx", "id": "p1", "from": [10, 10], "me": "CONST_ME_MAGIC_BLUE", "tiles": [[12, 10], [13, 10]]}),
		"fx vùng không phải đòn tấn công phải rơi về hiệu ứng cũ")
	_h({"op": "area_fx", "effect": "CONST_ME_MAGIC_BLUE", "tiles": [[12, 10], [13, 10]]})
	await _wait(0.2)
	await _snap("aoe_fallback_blue")
	await _wait(1.0)

	# Quái chết
	var before: int = main.vfx.layer.get_child_count()
	_h({"op": "creature_dead", "id": "m1"})
	_h({"op": "creature_dead", "id": "m3"})
	_check(main.vfx.layer.get_child_count() > before, "quái chết phải sinh bóng bốc hơi")
	await _wait(0.3)
	await _snap("die_1")
	await _wait(0.5)
	await _snap("die_2")

	# Zoom x2 + camera dịch
	main.world.zoom_step(1)
	_h({"op": "move", "id": "p1", "x": 11, "y": 10})
	_h({"op": "fx", "id": "p1", "from": [11, 10], "me": "CONST_ME_FIREATTACK", "ani": "CONST_ANI_FIRE", "tiles": [[15, 13]]})
	await _wait(0.6)
	await _snap("zoom2_hit")

	# Không rò rỉ
	await _wait(3.0)
	_check(main.vfx.layer.get_child_count() == 0, "không được còn node hiệu ứng sau khi chạy xong (còn %d)" % main.vfx.layer.get_child_count())
	_check(main.vfx._pending.is_empty(), "không được còn đòn đánh thường chờ")
	print("VFX IT: %s (%d ảnh trong %s)" % ["OK" if fails == 0 else "FAIL x%d" % fails, shots, ProjectSettings.globalize_path("user://vfx_it")])
	get_tree().quit(1 if fails > 0 else 0)


func _aoe(name: String, msg: Dictionary) -> void:
	_check(main.vfx.on_fx(msg), "%s: spell vùng phải do vfx_kit vẽ" % name)
	await _wait(0.12)
	await _snap("aoe_%s_1" % name)
	await _wait(0.2)
	await _snap("aoe_%s_2" % name)
	await _wait(0.9)


func _h(m: Dictionary) -> void:
	main._handle(m)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _snap(n: String) -> void:
	if DisplayServer.get_name() == "headless":
		return   # không có renderer: bỏ qua chụp ảnh (frame_post_draw sẽ không bao giờ phát)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("user://vfx_it/%s.png" % n)
		shots += 1
