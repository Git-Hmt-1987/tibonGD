extends Node
## Quản lý hiệu ứng spell đơn mục tiêu + quái chết bốc hơi.
##
## Cách dùng (tạo 1 instance rồi add_child, hoặc đăng ký Autoload tên "VFX"):
##   fx.cast_single("fire", from_pos, monster_node)
##   fx.cast_single("energy", from_pos, monster_node, {"on_hit": func(): show_damage()})
##   fx.cast_single("slash", from_pos, monster_node)             # đánh cận chiến
##   fx.impact_at("physical", hit_pos)                           # chỉ hiện hiệu ứng trúng đòn
##   fx.death_evaporate(monster_sprite)                          # quái chết bốc hơi (sao chép node sprite)
##   fx.evaporate_ghost(ghost_node)                              # như trên nhưng bạn tự dựng "bóng" (quái tự vẽ bằng _draw)
##
## TỌA ĐỘ: mọi Vector2 truyền vào là tọa độ CỤC BỘ của node `parent` (opts.parent, mặc định current_scene).
## Kích thước trong vfx_defs.gd tính theo "px thiết kế" (1 ô = 64px). Muốn đổi tỉ lệ / zoom: đặt scale cho `parent`
## (xem vfx/VfxBridge.gd: lớp hiệu ứng có scale = 0,5 x zoom để khớp ô 32px của WorldView).
## `target` của cast_single: Vector2 (đứng yên) | Node2D (bám theo) | Callable trả Vector2 cục bộ (bám theo, dùng cho
## thực thể không phải node).
## Mọi hiệu ứng được dựng bằng code, không cần scene.

const Defs := preload("res://vfx_kit/vfx_defs.gd")

const Z := 60  # z_index của hiệu ứng (nằm trên quái / tile)
const MAX_AREA_TILES := 150  # cast_area chỉ vẽ tối đa chừng này ô

var _frames_cache: Dictionary = {}
var _tex_cache: Dictionary = {}
var _add_mat: CanvasItemMaterial
var _fade_ramp: Gradient
var _shrink_curve: Curve
var _grow_curve: Curve


func _init() -> void:
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fade_ramp = Gradient.new()
	_fade_ramp.set_color(0, Color(1, 1, 1, 1))
	_fade_ramp.set_color(1, Color(1, 1, 1, 0))
	_shrink_curve = Curve.new()
	_shrink_curve.add_point(Vector2(0.0, 1.0))
	_shrink_curve.add_point(Vector2(1.0, 0.25))
	_grow_curve = Curve.new()
	_grow_curve.add_point(Vector2(0.0, 0.5))
	_grow_curve.add_point(Vector2(1.0, 1.4))


# =====================================================================
#  API CHÍNH
# =====================================================================

## Bắn một spell đơn mục tiêu.
##   kind:   "fire" | "energy" | "ice" | "death" | "physical" | "slash" (xem vfx_defs.gd)
##   from:   vị trí caster (tọa độ cục bộ của parent)
##   target: Vector2 cố định | Node2D (đạn bám theo) | Callable() -> Vector2 (đạn bám theo)
##   opts:   parent (Node nhận hiệu ứng, mặc định current_scene),
##           offset (Vector2 lệch điểm trúng, vd lên giữa thân quái),
##           on_hit (Callable gọi đúng lúc trúng đòn: hiện số damage, giảm HP...),
##           blood (bool bật/tắt máu văng),
##           no_impact (bool: chỉ bay tới nơi, không nổ; dùng trước cast_area cho spell vùng dạng quả cầu)
func cast_single(kind: String, from: Vector2, target: Variant, opts: Dictionary = {}) -> void:
	if not Defs.KINDS.has(kind):
		push_warning("VFX: không có kind '%s'" % kind)
		return
	var d: Dictionary = Defs.KINDS[kind]
	var parent: Node = _get_parent(opts)
	var offset: Vector2 = opts.get("offset", Vector2.ZERO)
	var end_pos: Vector2 = _target_pos(target, from, parent) + offset
	var dir: Vector2 = (end_pos - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var on_hit: Callable = opts.get("on_hit", Callable())

	var no_impact: bool = opts.get("no_impact", false)   # chỉ bay tới nơi, không nổ (spell vùng tự lo phần nổ)
	var arrive := func(pos: Vector2) -> void:
		if not no_impact:
			_do_impact(d, parent, pos, dir, opts)
		if on_hit.is_valid():
			on_hit.call()

	if d.has("projectile"):
		_fly(d["projectile"], parent, from, target, offset, arrive)
	elif d.has("bolt"):
		_bolt(d["bolt"], parent, from, end_pos)
		get_tree().create_timer(0.05).timeout.connect(arrive.bind(end_pos))
	else:
		arrive.call(end_pos)


## Spell VÙNG (AOE): hiệu ứng nhẹ trên từng ô, lan dần ra như sóng (xem AREAS trong vfx_defs.gd).
##   origin:    điểm bắt đầu lan (thường là người cast), tọa độ cục bộ của parent
##   positions: Array[Vector2] tâm các ô của vùng (cùng hệ tọa độ)
##   opts: parent,
##         mode "wave" (mặc định: lan từ origin ra ngoài; hợp sóng/chùm tia/vòng quanh người) |
##              "ball" (lan từ tâm vùng + lớp "center" lớn; hợp quả cầu rơi xa người cast),
##         skip (Array[Vector2] ô đã có hiệu ứng khác, bỏ qua), skip_center (bool bỏ lớp "center"),
##         delay (giây hoãn cả vùng)
## Quá MAX_AREA_TILES ô thì chỉ vẽ một phần đều đặn, và vùng nhiều ô thì mỗi ô mờ hơn (vùng lớn kiểu Eternal Winter vẫn nhẹ, không che màn hình).
func cast_area(kind: String, origin: Vector2, positions: Array, opts: Dictionary = {}) -> void:
	if not Defs.AREAS.has(kind) or positions.is_empty():
		return
	var a: Dictionary = Defs.AREAS[kind]
	var parent: Node = _get_parent(opts)
	var ball: bool = String(opts.get("mode", "wave")) == "ball"
	var step: float = a.get("step", 0.045)
	var base_delay: float = opts.get("delay", 0.0)
	var skip: Array = opts.get("skip", [])
	var stride := maxi(1, ceili(float(positions.size()) / float(MAX_AREA_TILES)))
	var centroid := Vector2.ZERO
	for p in positions:
		centroid += p
	centroid /= float(positions.size())
	var start := centroid if ball else origin
	# vùng càng nhiều ô thì mỗi ô càng mờ (61 ô đậm hết cỡ sẽ che kín màn hình): 16 ô trở xuống giữ nguyên
	var density := clampf(sqrt(16.0 / float(positions.size())), 0.4, 1.0)
	var tile_layers: Array = []
	for layer in a.get("tile", []):
		var l: Dictionary = layer.duplicate()
		l["color"] = (l.get("color", Color.WHITE) as Color) * Color(1, 1, 1, density)
		tile_layers.append(l)
	for i in range(0, positions.size(), stride):
		var p: Vector2 = positions[i]
		if skip.has(p):
			continue
		var dv := p - start
		var dist_cells := dv.length() / 64.0   # đo theo ô (px thiết kế 64)
		var delay := base_delay + minf(dist_cells * step, 0.6) + randf() * 0.03
		var dir := dv.normalized() if dv != Vector2.ZERO else Vector2.RIGHT
		for layer in tile_layers:
			_spawn_layer_at(layer, parent, p, dir, delay)
	if ball and not opts.get("skip_center", false):
		for layer in a.get("center", []):
			_spawn_layer_at(layer, parent, centroid, Vector2.RIGHT, base_delay)


## Chỉ hiện hiệu ứng trúng đòn tại một điểm (khi server báo "trúng" mà không cần đạn bay).
func impact_at(kind: String, pos: Vector2, opts: Dictionary = {}) -> void:
	if not Defs.KINDS.has(kind):
		push_warning("VFX: không có kind '%s'" % kind)
		return
	var dir: Vector2 = opts.get("dir", Vector2.RIGHT)
	_do_impact(Defs.KINDS[kind], _get_parent(opts), pos, dir, opts)


## Quái chết bốc hơi, kiểu 1: sao chép một node sprite có sẵn (Sprite2D / AnimatedSprite2D...).
## Nên truyền node sprite chứ không phải cả node quái kèm thanh HP. Bóng được tạo từ bản sao nên bạn
## có thể queue_free quái gốc ngay sau khi gọi (hoặc opts.free_original = true).
## Xem evaporate_ghost() cho các tùy chọn (rise, duration, steam_extents, steam_offset).
func death_evaporate(visual: CanvasItem, opts: Dictionary = {}) -> void:
	if visual == null or not is_instance_valid(visual) or not (visual is Node2D):
		return
	var src := visual as Node2D
	var parent: Node = _get_parent(opts)
	var ghost: Node2D = src.duplicate(0) as Node2D  # 0 = chỉ chép thuộc tính, không chép script
	if ghost == null:
		return
	parent.add_child(ghost)
	if parent is CanvasItem:
		ghost.transform = (parent as CanvasItem).get_global_transform().affine_inverse() * src.global_transform
	else:
		ghost.global_transform = src.global_transform
	if ghost is AnimatedSprite2D:
		(ghost as AnimatedSprite2D).stop()
	evaporate_ghost(ghost, opts)
	if opts.get("free_original", false):
		src.queue_free()


## Quái chết bốc hơi, kiểu 2: bạn tự dựng "bóng" (Node2D) rồi giao cho hàm này. Dùng khi quái được vẽ
## bằng _draw (không có node sprite). Điều kiện: ghost đã là con của node parent và đã đặt `position`.
## Hàm làm bóng sáng lên, bay lên, tan dần rồi tự queue_free; kèm hơi nước và đốm sáng.
##   opts: rise (px bay lên, mặc định 36), duration (giây, mặc định 0.75),
##         steam_extents (Vector2 nửa kích thước vùng phát hơi, mặc định (22, 18)),
##         steam_offset (Vector2 lệch tâm phát hơi)
func evaporate_ghost(ghost: Node2D, opts: Dictionary = {}) -> void:
	if ghost == null or not is_instance_valid(ghost) or not ghost.is_inside_tree():
		return
	var parent: Node = ghost.get_parent()
	var rise: float = opts.get("rise", 36.0)
	var dur: float = opts.get("duration", 0.75)
	var base_scale: Vector2 = ghost.scale
	var start_y: float = ghost.position.y

	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate", Color(2.2, 2.2, 2.4, 1.0), 0.12)
	tw.chain().tween_property(ghost, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(ghost, "position:y", start_y - rise, dur).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ghost, "scale", Vector2(base_scale.x * 0.8, base_scale.y * 1.25), dur)
	tw.finished.connect(ghost.queue_free)

	var center: Vector2 = ghost.position + (opts.get("steam_offset", Vector2.ZERO) as Vector2)
	var extents: Vector2 = opts.get("steam_extents", Vector2(22, 18))

	# hơi nước
	var steam := _make_particles("smoke_05", 18, dur + 0.2, 42.0, Color(0.93, 0.97, 1.0, 0.55), false)
	steam.scale_amount_curve = _grow_curve
	steam.one_shot = true
	steam.explosiveness = 0.25
	steam.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	steam.emission_rect_extents = extents
	steam.direction = Vector2.UP
	steam.spread = 22.0
	steam.initial_velocity_min = 25.0
	steam.initial_velocity_max = 60.0
	steam.gravity = Vector2(0, -18)
	parent.add_child(steam)
	steam.position = center
	steam.emitting = true
	steam.finished.connect(steam.queue_free)

	# đốm sáng bay lên
	var glints := _make_particles("star_04", 8, dur + 0.1, 16.0, Color(0.8, 0.95, 1.0, 1.0), true)
	glints.one_shot = true
	glints.explosiveness = 0.0
	glints.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	glints.emission_rect_extents = extents
	glints.direction = Vector2.UP
	glints.spread = 35.0
	glints.initial_velocity_min = 20.0
	glints.initial_velocity_max = 50.0
	glints.gravity = Vector2(0, -30)
	parent.add_child(glints)
	glints.position = center
	glints.emitting = true
	glints.finished.connect(glints.queue_free)


# =====================================================================
#  NỘI BỘ
# =====================================================================

func _get_parent(opts: Dictionary) -> Node:
	var p: Variant = opts.get("parent", null)
	if p is Node and is_instance_valid(p):
		return p as Node
	var cs := get_tree().current_scene
	return cs if cs != null else get_tree().root


func _target_pos(target: Variant, fallback: Vector2, parent: Node) -> Vector2:
	if typeof(target) == TYPE_VECTOR2:
		return target
	if typeof(target) == TYPE_CALLABLE:
		var c: Callable = target
		if c.is_valid():
			var r: Variant = c.call()
			if typeof(r) == TYPE_VECTOR2:
				return r
		return fallback
	if is_instance_valid(target) and target is Node2D:
		var g := (target as Node2D).global_position
		return (parent as CanvasItem).get_global_transform().affine_inverse() * g if parent is CanvasItem else g
	return fallback


func _tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		_tex_cache[name] = load(Defs.ROOT + "tex/%s.png" % name)
	return _tex_cache[name]


func _frames(sheet: String, loop: bool) -> SpriteFrames:
	var key := "%s|%s" % [sheet, loop]
	if _frames_cache.has(key):
		return _frames_cache[key]
	var info: Dictionary = Defs.SHEETS[sheet]
	var cols: int = info["cols"]
	var count: int = info["count"]
	var fsize: int = info["size"]
	var atlas: Texture2D = load(Defs.ROOT + "sheets/%s.png" % sheet)
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", info["fps"])
	sf.set_animation_loop("default", loop)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = atlas
		at.region = Rect2((i % cols) * fsize, floori(float(i) / float(cols)) * fsize, fsize, fsize)
		sf.add_frame("default", at)
	_frames_cache[key] = sf
	return sf


func _make_particles(tex_name: String, amount: int, life: float, size_px: float,
		col: Color, add: bool) -> CPUParticles2D:
	var cp := CPUParticles2D.new()
	cp.texture = _tex(tex_name)
	cp.amount = amount
	cp.lifetime = life
	var s := size_px / 128.0
	cp.scale_amount_min = s * 0.6
	cp.scale_amount_max = s
	cp.scale_amount_curve = _shrink_curve
	cp.color = col
	cp.color_ramp = _fade_ramp
	cp.z_index = Z
	if add:
		cp.material = _add_mat
	return cp


# ---------------- đạn bay ----------------

func _fly(p: Dictionary, parent: Node, from: Vector2, target: Variant,
		offset: Vector2, arrive: Callable) -> void:
	var root := Node2D.new()
	root.z_index = Z
	parent.add_child(root)
	root.position = from

	var size: float = p.get("size", 40.0)
	var col: Color = p.get("color", Color.WHITE)
	var visual: Node2D
	if p.get("type", "orb") == "sheet":
		var sheet: String = p["sheet"]
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = _frames(sheet, true)
		var fsize: int = Defs.SHEETS[sheet]["size"]
		anim.scale = Vector2.ONE * (size / float(fsize))
		anim.modulate = col
		visual = anim
		root.add_child(visual)
		anim.play("default")
	else:
		var spr := Sprite2D.new()
		spr.texture = _tex(p["tex"])
		spr.scale = Vector2.ONE * (size / 128.0)
		spr.modulate = col
		visual = spr
		root.add_child(visual)
	if p.get("additive", true):
		visual.material = _add_mat

	var trail: CPUParticles2D = null
	if p.has("trail"):
		var t: Dictionary = p["trail"]
		trail = _make_particles(t["tex"], t.get("amount", 14), t.get("life", 0.35),
			t.get("size", 24.0), t.get("color", Color.WHITE), t.get("additive", true))
		trail.local_coords = false
		trail.direction = Vector2.ZERO
		trail.spread = 180.0
		trail.gravity = Vector2.ZERO
		trail.initial_velocity_min = 5.0
		trail.initial_velocity_max = 22.0
		root.add_child(trail)
		trail.emitting = true

	var st := {"end": _target_pos(target, from, parent) + offset}
	var first_end: Vector2 = st["end"]
	var dur := clampf(from.distance_to(first_end) / float(p.get("speed", 500.0)), 0.08, 1.2)

	var step := func(t: float) -> void:
		if not is_instance_valid(root):
			return
		var cur: Vector2 = st["end"]
		cur = _target_pos(target, cur - offset, parent) + offset
		st["end"] = cur
		var prev := root.position
		root.position = from.lerp(cur, t)
		var moved := root.position - prev
		if moved.length_squared() > 0.0001:
			root.rotation = moved.angle()

	var land := func() -> void:
		var final_pos: Vector2 = st["end"]
		visual.visible = false
		if trail != null:
			trail.emitting = false
		arrive.call(final_pos)

	var tw := root.create_tween()
	tw.tween_method(step, 0.0, 1.0, dur)
	tw.tween_callback(land)
	tw.tween_interval(0.6)  # chờ đuôi tan hết
	tw.tween_callback(root.queue_free)


# ---------------- tia sét ----------------

func _bolt(b: Dictionary, parent: Node, from: Vector2, to: Vector2) -> void:
	var col: Color = b.get("color", Color(0.6, 0.85, 1.0))
	var w: float = b.get("width", 5.0)
	var dur: float = b.get("duration", 0.24)
	var segs: int = b.get("segments", 9)
	var jit: float = b.get("jitter", 16.0)

	var lines: Array[Line2D] = []
	var specs := [
		[w * 3.5, Color(col.r, col.g, col.b, 0.3)],
		[w * 1.6, col],
		[w * 0.7, Color(1, 1, 1, 1)],
	]
	for spec in specs:
		var ln := Line2D.new()
		ln.width = spec[0]
		ln.default_color = spec[1]
		ln.joint_mode = Line2D.LINE_JOINT_ROUND
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.end_cap_mode = Line2D.LINE_CAP_ROUND
		ln.material = _add_mat
		ln.z_index = Z
		parent.add_child(ln)
		lines.append(ln)

	var rejit := func() -> void:
		var pts := _jagged(from, to, segs, jit)
		for ln in lines:
			if is_instance_valid(ln):
				ln.points = pts
	rejit.call()

	var cleanup := func() -> void:
		for ln in lines:
			if is_instance_valid(ln):
				ln.queue_free()

	var steps := 4
	var tw := lines[0].create_tween()
	for i in steps:
		tw.tween_interval(dur / float(steps))
		tw.tween_callback(rejit)
	tw.tween_callback(cleanup)
	for ln in lines:
		ln.create_tween().tween_property(ln, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN)

	# lóe sáng ở tay caster
	_spawn_tex(parent, "spotlight_03", from, 70.0, col, true, 0.0, 0.2, 0.0, Vector2.RIGHT)


func _jagged(a: Vector2, b: Vector2, segs: int, jit: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(a)
	var nrm := (b - a).normalized().orthogonal()
	for i in range(1, segs):
		var t := float(i) / float(segs)
		pts.append(a.lerp(b, t) + nrm * randf_range(-jit, jit) * sin(PI * t))
	pts.append(b)
	return pts


# ---------------- hiệu ứng khi trúng ----------------

func _do_impact(d: Dictionary, parent: Node, pos: Vector2, dir: Vector2, opts: Dictionary) -> void:
	var layers: Array = d.get("impact", [])
	for layer in layers:
		var delay: float = layer.get("delay", 0.0)
		if delay > 0.0:
			get_tree().create_timer(delay).timeout.connect(
				_spawn_layer.bind(layer, parent, pos, dir))
		else:
			_spawn_layer(layer, parent, pos, dir)
	if opts.get("blood", d.get("blood", false)):
		_spawn_layer({"sheet": "blood_impact", "size": 64.0, "rot_rand": true}, parent, pos, dir)


func _spawn_layer_at(layer: Dictionary, parent: Node, pos: Vector2, dir: Vector2, delay: float) -> void:
	if delay <= 0.0:
		_spawn_layer(layer, parent, pos, dir)
	else:
		get_tree().create_timer(delay).timeout.connect(_spawn_layer.bind(layer, parent, pos, dir))


func _spawn_layer(layer: Dictionary, parent: Node, pos: Vector2, dir: Vector2) -> void:
	if not is_instance_valid(parent):
		return
	var size: float = layer.get("size", 64.0)
	var col: Color = layer.get("color", Color.WHITE)
	var add: bool = layer.get("additive", false)
	var rot := 0.0
	if layer.get("rot_rand", false):
		rot = randf() * TAU
	if layer.get("face_dir", false):
		rot = dir.angle()
	if layer.has("sheet"):
		_spawn_sheet(parent, layer["sheet"], pos, size, col, add, rot)
	elif layer.has("tex"):
		_spawn_tex(parent, layer["tex"], pos, size, col, add, rot,
			layer.get("life", 0.25), layer.get("sweep", 0.0), dir)
	elif layer.has("burst"):
		_burst(parent, layer, pos)


func _spawn_sheet(parent: Node, sheet: String, pos: Vector2, size: float,
		col: Color, add: bool, rot: float) -> void:
	var sp := AnimatedSprite2D.new()
	sp.sprite_frames = _frames(sheet, false)
	var fsize: int = Defs.SHEETS[sheet]["size"]
	sp.scale = Vector2.ONE * (size / float(fsize))
	sp.modulate = col
	sp.rotation = rot
	sp.z_index = Z
	if add:
		sp.material = _add_mat
	parent.add_child(sp)
	sp.position = pos
	sp.animation_finished.connect(sp.queue_free)
	sp.play("default")


func _spawn_tex(parent: Node, tex_name: String, pos: Vector2, size: float, col: Color,
		add: bool, rot: float, life: float, sweep: float, dir: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = _tex(tex_name)
	var base := size / 128.0
	s.scale = Vector2.ONE * base * 0.5
	s.modulate = col
	s.rotation = rot
	s.z_index = Z
	if add:
		s.material = _add_mat
	parent.add_child(s)
	s.position = pos - dir * sweep * 0.5
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * base, life) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, life * 0.65).set_delay(life * 0.35)
	if sweep != 0.0:
		tw.tween_property(s, "position", pos + dir * sweep * 0.5, life)
	tw.chain().tween_callback(s.queue_free)


func _burst(parent: Node, layer: Dictionary, pos: Vector2) -> void:
	var cp := _make_particles(layer["burst"], layer.get("amount", 8), layer.get("life", 0.4),
		layer.get("size", 20.0), layer.get("color", Color.WHITE), layer.get("additive", false))
	var spd: float = layer.get("speed", 80.0)
	cp.one_shot = true
	cp.explosiveness = 1.0
	cp.direction = Vector2.UP
	cp.spread = 180.0
	cp.gravity = Vector2.ZERO
	cp.initial_velocity_min = spd * 0.4
	cp.initial_velocity_max = spd
	cp.damping_min = spd
	cp.damping_max = spd * 1.6
	parent.add_child(cp)
	cp.position = pos
	cp.emitting = true
	cp.finished.connect(cp.queue_free)
