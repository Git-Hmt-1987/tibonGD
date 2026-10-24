extends Node2D
## Scene thử hiệu ứng, độc lập với game: mở demo/vfx_demo.tscn rồi bấm F6 (Run Current Scene).
##   Phím 1-8: chọn spell (lửa, sét, băng, death, đất, thánh, đánh thường, chém)
##   Click chuột: bắn vào con quái đang đi qua đi lại
##   A: spell VÙNG (lan từ người bắn, mode "wave"); S: spell vùng dạng quả cầu nổ quanh quái (mode "ball")
##   K: giết quái (bốc hơi)     R: hồi sinh quái

const Mgr := preload("res://vfx_kit/vfx_manager.gd")
const KINDS := ["fire", "energy", "ice", "death", "earth", "holy", "physical", "slash"]
const NAMES := ["1 Lửa", "2 Sét", "3 Băng", "4 Death", "5 Đất", "6 Thánh", "7 Đánh thường", "8 Chém"]

var fx: Node
var caster: Sprite2D
var monster: Sprite2D
var kind_idx := 0
var alive := true
var label: Label
var t := 0.0


func _ready() -> void:
	fx = Mgr.new()  # trong game thật thì dùng Autoload "VFX" thay cho dòng này
	add_child(fx)
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.16, 0.13)
	bg.size = Vector2(2400, 1400)
	bg.z_index = -10
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	caster = _make_blob(Color(0.3, 0.5, 1.0))
	caster.position = Vector2(220, 340)
	add_child(caster)
	_spawn_monster()
	label = Label.new()
	label.position = Vector2(16, 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_update_label()
	if "--autotest" in OS.get_cmdline_user_args():
		_autotest()


func _make_blob(c: Color) -> Sprite2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var dx := x - 32.0
			var dy := y - 34.0
			if dx * dx / 900.0 + dy * dy / 760.0 < 1.0:
				img.set_pixel(x, y, c)
	for ex in [24, 40]:
		for oy in 3:
			for ox in 3:
				img.set_pixel(ex + ox, 27 + oy, Color.WHITE)
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	return s


func _spawn_monster() -> void:
	monster = _make_blob(Color(0.35, 0.75, 0.3))
	monster.position = Vector2(760, 340)
	add_child(monster)
	alive = true


func _update_label() -> void:
	label.text = "Spell: %s   |   Click = bắn   A/S = vùng   K = giết quái   R = hồi sinh\n[%s]" % [
		NAMES[kind_idx], "  ".join(NAMES)]


func _process(delta: float) -> void:
	t += delta
	if alive and is_instance_valid(monster):
		monster.position = Vector2(760 + sin(t * 1.3) * 110.0, 340 + cos(t * 0.9) * 60.0)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k := (ev as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_8:
			kind_idx = k - KEY_1
			_update_label()
		elif k == KEY_A or k == KEY_S:
			var pts: Array = []
			var c := monster.position if alive else get_global_mouse_position()
			for ix in range(-2, 3):
				for iy in range(-2, 3):
					pts.append(c + Vector2(ix, iy) * 64.0)
			fx.cast_area(KINDS[kind_idx], caster.position, pts, {"mode": "ball" if k == KEY_S else "wave"})
		elif k == KEY_K and alive:
			fx.death_evaporate(monster, {"free_original": true})
			alive = false
		elif k == KEY_R and not alive:
			_spawn_monster()
	elif ev is InputEventMouseButton and ev.pressed:
		var tgt: Variant = monster if alive else get_global_mouse_position()
		var kind: String = KINDS[kind_idx]
		fx.cast_single(kind, caster.global_position + Vector2(26, -6), tgt,
			{"on_hit": func(): print("trúng đòn: ", kind)})


func _autotest() -> void:
	await get_tree().create_timer(0.3).timeout
	for k in KINDS:
		var kk: String = k
		fx.cast_single(kk, caster.global_position, monster, {"on_hit": func(): print("HIT ", kk)})
		await get_tree().create_timer(0.9).timeout
	fx.impact_at("physical", Vector2(500, 300))
	fx.death_evaporate(monster, {"free_original": true})
	await get_tree().create_timer(1.3).timeout
	print("AUTOTEST DONE")
	get_tree().quit()
