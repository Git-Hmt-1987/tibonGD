class_name WorldMapPanel
extends PanelContainer
## Bản đồ thế giới (phím M / nút M): trái = sơ đồ các map (mỗi map là một ô có NỀN cắt từ chính theme/decor của map đó),
## phải = thẻ thông tin map đang chọn (tên, level khuyến nghị, loại map, quái trong map).
## Dữ liệu tĩnh từ gói `world_map` (server worldmap.py): maps[{id,name,kind,theme,w,h,x,y,rec,visited, monsters?}], links[[a,b]].
##   `monsters` (tùy chọn): mảng tên quái hoặc {name, level?, hp?} — chưa có thì thẻ phải báo "server chưa gửi".
## Điều khiển: cuộn chuột = phóng/thu quanh con trỏ · giữ chuột trái kéo = di chuyển · bấm một ô = xem thông tin · nút + − ⌖ ▣ góc phải.
## Viền ô: xanh lá = hợp level, đỏ = khó (level bạn thấp hơn khuyến nghị), xám = dễ (bạn cao hơn), vàng = thành phố.

signal need_data()

const PANEL_W := 1000.0
const PANEL_H := 640.0
const SIDE_K := 0.16   # cạnh ô vuông của map trên sơ đồ = w * SIDE_K (mirror server worldmap.SIDE_K)
const ZOOM_MIN := 0.35
const ZOOM_MAX := 9.0
const NODE_W := 2.0        # ô map hình chữ nhật: rộng = cạnh * NODE_W, cao = cạnh * NODE_H (cạnh = w * SIDE_K)
const NODE_H := 1.0
const THUMB_TX := 12       # ảnh nền mỗi map: 12x6 ô gốc (32px) -> tỉ lệ 2:1
const THUMB_TY := 6
const THUMB_PX := 384
const THUMB_PY := 192
const THEME_COL := {"grass": Color(0.30, 0.55, 0.30), "mine": Color(0.50, 0.45, 0.40),
	"hell": Color(0.78, 0.25, 0.15), "desert": Color(0.86, 0.72, 0.40), "sky": Color(0.62, 0.80, 0.96)}
const THEME_NAMES := {"grass": "Đồng cỏ", "mine": "Hầm mỏ", "hell": "Địa ngục", "desert": "Sa mạc", "sky": "Bầu trời"}
const NODE_RADIUS := 4.0   # bo góc ô map (nhỏ)
const C_GOOD := Color("#6fcf6f")
const C_HARD := Color("#e06060")
const C_EASY := Color("#a9adb8")
const C_CITY := Color("#e0b84f")
const CARD_BG := Color("#0f1a33")

var maps := {}            # id -> dict từ server
var links: Array = []
var hero_map := ""
var hero_pos := Vector2i.ZERO
var hero_level := 1
var canvas: Control
var info_lab: Label
var pulse := 0.0
var sc := 1.5                     # px / đơn vị sơ đồ
var view_c := Vector2.ZERO        # điểm sơ đồ nằm giữa canvas
var user_moved := false           # người chơi đã tự phóng/kéo -> không tự vừa khung nữa
var dragging := false
var press_pos := Vector2.ZERO
var moved_px := 0.0
var selected := ""                # map đang xem ở thẻ phải ("" = map hero đang đứng)
var tab := "all"                  # "all" hoặc theme: ô thuộc theme khác bị làm mờ
var tab_btns := {}
var tabs_box: HBoxContainer
var card_box: VBoxContainer
var _thumbs := {}                 # id -> ImageTexture
var _queue: Array = []
var _busy := false
var _tv: SubViewport
var _tdraw: Control
var _job := ""
var _job_origin := Vector2i.ZERO

func build() -> void:
	visible = false
	add_theme_stylebox_override("panel", UiKit.panel_style())
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	get_viewport().size_changed.connect(_center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	v.add_child(head)
	UiKit.head_sep(head)
	var title := UiKit.title("Bản đồ thế giới", 17)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(hide_map)
	head.add_child(close_btn)
	tabs_box = HBoxContainer.new()
	tabs_box.add_theme_constant_override("separation", 6)
	v.add_child(tabs_box)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	canvas = Control.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_draw_canvas)
	canvas.gui_input.connect(_canvas_input)
	body.add_child(canvas)
	# chip vàng góc trái-trên: bạn đang ở đâu / level
	info_lab = Label.new()
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color("#e9b94a")
	isb.set_corner_radius_all(4)
	isb.border_color = Color("#b98a2a")
	isb.set_border_width_all(2)
	isb.content_margin_left = 8
	isb.content_margin_right = 8
	isb.content_margin_top = 1
	isb.content_margin_bottom = 1
	info_lab.add_theme_stylebox_override("normal", isb)
	info_lab.add_theme_font_size_override("font_size", 13)
	info_lab.add_theme_font_override("font", UiKit.bold_font())
	info_lab.add_theme_color_override("font_color", Color("#3a2a08"))
	canvas.add_child(info_lab)
	info_lab.position = Vector2(8, 8)
	# nút phóng/thu góc phải-trên
	var zb := VBoxContainer.new()
	zb.add_theme_constant_override("separation", 4)
	canvas.add_child(zb)
	zb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	zb.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	zb.offset_right = -8
	zb.offset_top = 8
	for spec in [["+", "Phóng to"], ["−", "Thu nhỏ"], ["⌖", "Về vị trí của bạn"], ["▣", "Vừa khung (xem tất cả map)"]]:
		var b := Button.new()
		b.text = spec[0]
		b.tooltip_text = spec[1]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(30, 30)
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_stylebox_override("normal", CharPanel._box(Color("#f3ecd8"), Color("#8c7f5a"), 2, 5))
		b.add_theme_stylebox_override("hover", CharPanel._box(Color("#ffffff"), UiTheme.accent(), 2, 5))
		b.add_theme_stylebox_override("pressed", CharPanel._box(Color("#d8cfb4"), UiTheme.accent_dark(), 2, 5))
		for cn in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(cn, Color("#2a2a30"))
		match str(spec[0]):
			"+": b.pressed.connect(func(): _zoom_at(canvas.size / 2.0, 1.4))
			"−": b.pressed.connect(func(): _zoom_at(canvas.size / 2.0, 1.0 / 1.4))
			"⌖": b.pressed.connect(center_on_hero)
			_: b.pressed.connect(fit_view)
		zb.add_child(b)
	# thẻ thông tin bên phải
	var right := PanelContainer.new()
	var rsb := CharPanel._box(CARD_BG, UiTheme.accent_dark(), 3, 6)
	rsb.set_content_margin_all(10)
	right.add_theme_stylebox_override("panel", rsb)
	right.custom_minimum_size = Vector2(290, 0)
	body.add_child(right)
	card_box = VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 8)
	right.add_child(card_box)
	# bộ dựng ảnh nền map (SubViewport vẽ 1 lần / map rồi lưu thành texture)
	_tv = SubViewport.new()
	_tv.size = Vector2i(THUMB_PX, THUMB_PY)
	_tv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_tv.transparent_bg = false
	add_child(_tv)
	_tdraw = Control.new()
	_tdraw.size = Vector2(THUMB_PX, THUMB_PY)
	_tdraw.draw.connect(_draw_thumb)
	_tv.add_child(_tdraw)

func _tab(text: String, key: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = key == tab
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 32)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_font_override("font", UiKit.bold_font())
	b.add_theme_stylebox_override("normal", CharPanel._box(Color("#e8dcc0"), Color("#c9b98f"), 2, 5))
	b.add_theme_stylebox_override("hover", CharPanel._box(Color("#f1e7cc"), UiTheme.accent(), 2, 5))
	b.add_theme_stylebox_override("pressed", CharPanel._box(UiTheme.accent(), UiTheme.accent_dark(), 2, 5))
	b.add_theme_stylebox_override("hover_pressed", CharPanel._box(UiTheme.accent(), UiTheme.accent_dark(), 2, 5))
	for cn in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(cn, Color.WHITE)
	b.pressed.connect(func():
		tab = key
		for k in tab_btns:
			tab_btns[k].button_pressed = (k == key)
		_go_tab(key))
	return b

## Bấm tab = chuyển khung nhìn: "Tất cả" -> map bạn đang đứng; tab theo theme -> thành phố của theme đó (giữa màn hình).
func _go_tab(key: String) -> void:
	var target := ""
	if key == "all":
		target = hero_map
	else:
		for id in maps:
			var m: Dictionary = maps[id]
			if str(m.get("theme", "")) == key and str(m.get("kind", "hunt")) == "city":
				target = str(id)
				break
		if target == "":   # theme không có thành phố: lấy map đầu tiên của theme
			for id in maps:
				if str(maps[id].get("theme", "")) == key:
					target = str(id)
					break
	if target == "" or not maps.has(target):
		return
	user_moved = true
	selected = target
	_fill_card()
	var dest := _node_center(maps[target])
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "view_c", dest, 0.3)

func _rebuild_tabs() -> void:
	var seen := {}
	for id in maps:
		seen[str(maps[id].get("theme", "grass"))] = true
	for c in tabs_box.get_children():
		tabs_box.remove_child(c)
		c.queue_free()
	tab_btns.clear()
	var keys := ["all"]
	for t in THEME_NAMES:
		if seen.has(t):
			keys.append(t)
	if not (tab in keys):
		tab = "all"
	for k in keys:
		var b := _tab("Tất cả" if k == "all" else str(THEME_NAMES[k]), k)
		tab_btns[k] = b
		tabs_box.add_child(b)

func toggle() -> void:
	if visible:
		hide_map()
		return
	visible = true
	_center()
	need_data.emit()   # luôn xin lại (nhẹ, tĩnh) để map mới của server hiện ngay
	_refresh_info()
	if not user_moved:
		fit_view()
	canvas.queue_redraw()

func hide_map() -> void:
	visible = false
	dragging = false

func set_data(msg: Dictionary) -> void:
	maps = {}
	for m in msg.get("maps", []):
		maps[str(m.get("id", ""))] = m
	links = msg.get("links", [])
	_rebuild_tabs()
	for id in maps:
		if not _thumbs.has(id) and not (id in _queue):
			_queue.append(id)
	_run_queue()
	_refresh_info()
	if not user_moved:
		fit_view()
	canvas.queue_redraw()

func set_hero(map_id: String, pos: Vector2i, level: int = 1) -> void:
	var changed := map_id != hero_map
	hero_map = map_id
	hero_pos = pos
	hero_level = level
	if visible and changed:
		_refresh_info()

func _refresh_info() -> void:
	if info_lab == null:
		return
	var m: Dictionary = maps.get(hero_map, {})
	info_lab.text = "%s · Level của bạn: %d" % [str(m.get("name", hero_map)), hero_level]
	_fill_card()

# ---------- ảnh nền từng map (cắt từ theme + decor của chính map) ----------

func _run_queue() -> void:
	if _busy:
		return
	_busy = true
	while not _queue.is_empty():
		_job = str(_queue.pop_front())
		if not maps.has(_job) or _thumbs.has(_job) or not MapArt.ready():
			continue
		_job_origin = _pick_window(_job)
		_tdraw.queue_redraw()
		_tv.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var img := _tv.get_texture().get_image()
		if img != null and not img.is_empty():
			_thumbs[_job] = ImageTexture.create_from_image(img)
			if visible:
				canvas.queue_redraw()
				_fill_card()
	_busy = false

func _decor_of(id: String) -> Array:
	var m: Dictionary = maps[id]
	return MapArt.gen_decor(id, int(m.get("w", 64)), int(m.get("h", 64)), {}, [], Vector2i(-99, -99), str(m.get("theme", "grass")))

## Chọn cửa sổ 8x8 ô có nhiều cây/đồ trang trí nhất để ảnh nền trông "đã" như map thật.
func _pick_window(id: String) -> Vector2i:
	var m: Dictionary = maps[id]
	var w := int(m.get("w", 64))
	var h := int(m.get("h", 64))
	var best := Vector2i(maxi(0, (w - THUMB_TX) / 2), maxi(0, (h - THUMB_TY) / 2))
	var best_n := -1
	var dec := _decor_of(id)
	for oy in range(2, maxi(3, h - THUMB_TY - 1), 3):
		for ox in range(1, maxi(2, w - THUMB_TX), 3):
			var n := 0
			for d in dec:
				if int(d["x"]) >= ox and int(d["x"]) < ox + THUMB_TX and int(d["y"]) >= oy and int(d["y"]) < oy + THUMB_TY:
					n += 2 if d["k"] == "tree" else 1
			if n > best_n:
				best_n = n
				best = Vector2i(ox, oy)
	return best

func _draw_thumb() -> void:
	if _job == "" or not maps.has(_job):
		return
	var m: Dictionary = maps[_job]
	var th := MapArt.theme_def(str(m.get("theme", "grass")))
	var ts := float(THUMB_PX) / THUMB_TX
	for ty in THUMB_TY:
		for tx in THUMB_TX:
			MapArt.draw_floor(_tdraw, th, Vector2(tx, ty) * ts, Vector2(ts, ts), Vector2i(_job_origin.x + tx, _job_origin.y + ty))
	var dec := _decor_of(_job)
	dec.sort_custom(func(a, b): return int(a["y"]) < int(b["y"]))
	var tint: Color = th["prop_tint"]
	for d in dec:
		var x := int(d["x"]) - _job_origin.x
		var y := int(d["y"]) - _job_origin.y
		if x < -1 or y < 0 or x > THUMB_TX or y >= THUMB_TY + 1:
			continue
		MapArt.draw_sprite(_tdraw, str(d["f"]), Vector2(x, y) * ts, ts, tint)

# ---------- thẻ thông tin bên phải ----------

func _sel_id() -> String:
	return selected if maps.has(selected) else hero_map

func _fill_card() -> void:
	if card_box == null:
		return
	for c in card_box.get_children():
		card_box.remove_child(c)
		c.queue_free()
	var id := _sel_id()
	if not maps.has(id):
		card_box.add_child(UiKit.lab_raw("Chọn một map để xem thông tin", 13, Color(0.8, 0.85, 0.95)))
		return
	var m: Dictionary = maps[id]
	# ảnh map
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(0, 150)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.texture = _thumbs.get(id, null)
	pic.clip_contents = true
	card_box.add_child(pic)
	var nm := UiKit.lab_raw(str(m.get("name", id)), 20, Color.WHITE)
	nm.add_theme_font_override("font", UiKit.bold_font())
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_box.add_child(nm)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 4)
	chips.add_theme_constant_override("v_separation", 4)
	card_box.add_child(chips)
	var is_city := str(m.get("kind", "hunt")) == "city"
	chips.add_child(_chip("Thành phố" if is_city else "Khu săn", Color("#3d86d6")))
	chips.add_child(_chip(str(THEME_NAMES.get(str(m.get("theme", "grass")), "Map")), Color("#5a6a8a")))
	if id == hero_map:
		chips.add_child(_chip("Bạn đang ở đây", Color("#c28a2c")))
	var rec = m.get("rec", [])
	var rows := []
	if rec is Array and rec.size() == 2:
		rows.append(["Level khuyến nghị", "%d – %d" % [int(rec[0]), int(rec[1])], _lv_color(rec, 1.0)])
	rows.append(["Kích thước", "%d × %d ô" % [int(m.get("w", 0)), int(m.get("h", 0))], Color.WHITE])
	var tbl := VBoxContainer.new()
	tbl.add_theme_constant_override("separation", 0)
	card_box.add_child(tbl)
	for i in rows.size():
		tbl.add_child(_stat_row(str(rows[i][0]), str(rows[i][1]), rows[i][2], i % 2 == 1))
	var mh := UiKit.lab_raw("Quái trong map", 14, Color(0.75, 0.88, 1.0))
	mh.add_theme_font_override("font", UiKit.bold_font())
	card_box.add_child(mh)
	var mons = m.get("monsters", null)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_box.add_child(list)
	if mons is Array and not mons.is_empty():
		var shown := 0
		for e in mons:
			if shown >= 10:
				list.add_child(UiKit.lab_raw("… và %d loại khác" % (mons.size() - shown), 12, Color(0.65, 0.72, 0.85)))
				break
			var t := str(e.get("name", "?")) if e is Dictionary else str(e)
			if e is Dictionary and e.has("level"):
				t += "  ·  Lv %d" % int(e["level"])
			if e is Dictionary and int(e.get("count", 0)) > 0:
				t += "  ×%d" % int(e["count"])
			list.add_child(UiKit.lab_raw("•  " + t, 13, Color.WHITE))
			shown += 1
	else:
		var none := UiKit.lab_raw("Thành phố: không có quái" if is_city else "(Server chưa gửi danh sách quái của map này)", 12, Color(0.65, 0.72, 0.85))
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(none)

func _chip(t: String, bg: Color) -> Label:
	var l := UiKit.lab_raw(t, 12, Color.WHITE)
	l.add_theme_font_override("font", UiKit.bold_font())
	var sb := CharPanel._box(bg, bg.darkened(0.3), 2, 5)
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	l.add_theme_stylebox_override("normal", sb)
	return l

func _stat_row(a: String, b: String, vcol: Color, odd: bool) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.09) if odd else Color(1, 1, 1, 0.03)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	p.add_child(h)
	var la := UiKit.lab_raw(a, 13, Color(0.75, 0.88, 1.0))
	la.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(la)
	var lb := UiKit.lab_raw(b, 13, vcol)
	lb.add_theme_font_override("font", UiKit.bold_font())
	h.add_child(lb)
	return p

func _center() -> void:
	if not visible:
		return
	var vp := get_viewport_rect().size
	var sz := Vector2(minf(PANEL_W, vp.x - 16.0), minf(PANEL_H, vp.y - 16.0))
	custom_minimum_size = sz
	size = sz
	global_position = ((vp - sz) / 2.0).floor()
	z_index = 100
	if get_parent() != null:
		get_parent().move_child(self, -1)

func _process(delta: float) -> void:
	if visible:
		pulse += delta
		canvas.queue_redraw()

func _node_rect(m: Dictionary) -> Rect2:
	var side := float(m.get("w", 64)) * SIDE_K * sc
	var c := _to_screen(_node_center(m))
	var sz := Vector2(side * NODE_W, side * NODE_H)
	return Rect2(c - sz / 2.0, sz)

func _pick_at(p: Vector2) -> void:
	var hit := ""
	for id in maps:
		if _node_rect(maps[id]).has_point(p):
			hit = str(id)
	if hit != "":
		selected = hit
		_fill_card()
		canvas.queue_redraw()

# ---------- khung nhìn ----------

func _node_center(m: Dictionary) -> Vector2:
	return Vector2(float(m.get("x", 0)), float(m.get("y", 0)))

func _to_screen(p: Vector2) -> Vector2:
	return canvas.size / 2.0 + (p - view_c) * sc

## Vừa khung: thu phóng + căn giữa để thấy mọi map đang hiện.
func fit_view() -> void:
	user_moved = false
	if maps.is_empty() or canvas == null:
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for id in maps:
		var m: Dictionary = maps[id]
		var c := _node_center(m)
		var half := Vector2(NODE_W, NODE_H) * float(m.get("w", 64)) * SIDE_K / 2.0 + Vector2(4.0, 4.0)   # tên + level nằm TRONG ô nên chỉ chừa lề nhỏ
		lo = Vector2(minf(lo.x, c.x - half.x), minf(lo.y, c.y - half.y))
		hi = Vector2(maxf(hi.x, c.x + half.x), maxf(hi.y, c.y + half.y))
	var span := hi - lo
	var cs := canvas.size if canvas.size.x > 10.0 else Vector2(PANEL_W - 24.0, PANEL_H - 120.0)
	sc = clampf(minf(cs.x / maxf(span.x, 1.0), cs.y / maxf(span.y, 1.0)), ZOOM_MIN, 4.0)
	view_c = (lo + hi) / 2.0
	canvas.queue_redraw()

func center_on_hero() -> void:
	var m: Dictionary = maps.get(hero_map, {})
	if m.is_empty():
		return
	user_moved = true
	var side := float(m.get("w", 64))
	var fx := float(hero_pos.x) / maxf(1.0, side)
	var fy := float(hero_pos.y) / maxf(1.0, float(m.get("h", 64)))
	var half := Vector2(NODE_W, NODE_H) * side * SIDE_K / 2.0
	view_c = _node_center(m) + Vector2((fx - 0.5) * 2.0 * half.x, (fy - 0.5) * 2.0 * half.y)
	sc = maxf(sc, 3.0)
	canvas.queue_redraw()

func _zoom_at(screen_pt: Vector2, factor: float) -> void:
	user_moved = true
	var before := view_c + (screen_pt - canvas.size / 2.0) / sc     # điểm sơ đồ dưới con trỏ
	sc = clampf(sc * factor, ZOOM_MIN, ZOOM_MAX)
	view_c = before - (screen_pt - canvas.size / 2.0) / sc          # giữ điểm đó đứng yên dưới con trỏ
	canvas.queue_redraw()

func _canvas_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			_zoom_at(e.position, 1.2)
			canvas.accept_event()
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			_zoom_at(e.position, 1.0 / 1.2)
			canvas.accept_event()
		elif e.button_index == MOUSE_BUTTON_LEFT:
			dragging = e.pressed
			if e.pressed:
				press_pos = e.position
				moved_px = 0.0
			elif moved_px < 5.0:   # bấm (không kéo) = chọn map dưới con trỏ
				_pick_at(e.position)
			canvas.accept_event()
	elif e is InputEventMouseMotion and dragging:
		user_moved = true
		moved_px += e.relative.length()
		view_c -= e.relative / sc
		canvas.accept_event()
		canvas.queue_redraw()

# ---------- vẽ ----------

func _text_w(txt: String, fs: int) -> float:
	return UiKit.bold_font().get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

## Đa giác hình chữ nhật bo góc (để cắt ảnh nền theo góc bo).
func _round_poly(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	rad = minf(rad, minf(r.size.x, r.size.y) / 2.0)
	var corners := [[r.end, 0.0], [Vector2(r.position.x, r.end.y), 90.0], [r.position, 180.0], [Vector2(r.end.x, r.position.y), 270.0]]
	for c in corners:
		var cen: Vector2 = c[0] + Vector2(-rad if c[0].x == r.end.x else rad, -rad if c[0].y == r.end.y else rad)
		for i in 5:
			var a := deg_to_rad(float(c[1]) + 90.0 * i / 4.0)
			pts.append(cen + Vector2(cos(a), sin(a)) * rad)
	return pts

func _frame(r: Rect2, col: Color, w: float, rad: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(int(w))
	sb.border_color = col
	sb.set_corner_radius_all(int(rad))
	canvas.draw_style_box(sb, r)

## Nhãn map NẰM TRONG ô, mỗi dòng là một label riêng nhỏ gọn ở đáy ảnh: tên = nền ĐEN chữ trắng; level / "Thành Phố" = nền XANH chữ trắng.
## Ô thấp: chỉ còn nhãn tên; ô quá nhỏ: không ghi (zoom vào sẽ hiện).
func _pill(txt: String, cx: float, bottom: float, fs: int, bg: Color, max_w: float) -> float:
	var font := UiKit.bold_font()
	while _text_w(txt, fs) + 10.0 > max_w and txt.length() > 3:   # quá dài: cắt bớt + "…"
		txt = txt.left(txt.length() - 2).strip_edges() + "…"
	var w := _text_w(txt, fs) + 10.0
	var h := float(fs) + 5.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(3)
	var rc := Rect2(cx - w / 2.0, bottom - h, w, h)
	canvas.draw_style_box(sb, rc)
	canvas.draw_string(font, Vector2(rc.position.x + 5.0, rc.end.y - 3.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	return h

func _name_tag(name_txt: String, lv_txt: String, r: Rect2, al: float) -> void:
	if r.size.x < 46.0 or r.size.y < 22.0:
		return
	var fs := clampi(roundi(r.size.y * 0.2), 9, 16)
	var fl := maxi(8, fs - 2)
	var cx := r.position.x + r.size.x / 2.0
	var maxw := r.size.x - 8.0
	var bottom := r.end.y - 4.0
	var black := Color(0, 0, 0, 0.88 * al)
	var blue := Color(UiTheme.accent(), 0.95 * al)
	if lv_txt != "" and r.size.y >= 44.0:
		var h2 := _pill(lv_txt, cx, bottom, fl, blue, maxw)
		_pill(name_txt, cx, bottom - h2 - 3.0, fs, black, maxw)
	else:
		_pill(name_txt, cx, bottom, fs, black, maxw)

func _lv_color(rec: Array, a: float) -> Color:
	if hero_level < int(rec[0]):
		return Color(C_HARD, a)     # còn yếu so với khuyến nghị
	if hero_level > int(rec[1]):
		return Color(C_EASY, a)     # vượt level khu này
	return Color(C_GOOD, a)         # hợp level

func _draw_canvas() -> void:
	var sz := canvas.size
	canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color("#10131c"))
	if maps.is_empty():
		canvas.draw_string(UiKit.bold_font(), Vector2(sz.x / 2.0 - 60.0, sz.y / 2.0), "Đang tải bản đồ...", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.8, 0.8))
		return
	for l in links:   # đường nối (cổng) vẽ trước, node đè lên
		var a: Dictionary = maps.get(str(l[0]), {})
		var b: Dictionary = maps.get(str(l[1]), {})
		if a.is_empty() or b.is_empty():
			continue
		canvas.draw_line(_to_screen(_node_center(a)), _to_screen(_node_center(b)), Color(0.55, 0.58, 0.68, 0.7), maxf(1.5, sc * 0.5))
	var hero_rect := Rect2()
	var tags := []   # nhãn vẽ SAU cùng để không bị ô khác đè
	var sel := _sel_id()
	for id in maps:
		var m: Dictionary = maps[id]
		var r := _node_rect(m)
		if r.end.x < -80.0 or r.position.x > sz.x + 80.0 or r.end.y < -80.0 or r.position.y > sz.y + 80.0:
			continue
		var seen := bool(m.get("visited", true))
		var al := 1.0 if seen else 0.4          # map chưa đến: vẽ mờ
		var thumb: Texture2D = _thumbs.get(id, null)
		var poly := _round_poly(r, NODE_RADIUS)
		if thumb != null:
			var uvs := PackedVector2Array()
			for pt in poly:
				uvs.append((pt - r.position) / r.size)
			canvas.draw_colored_polygon(poly, Color(1, 1, 1, al), uvs, thumb)
		else:
			var col: Color = THEME_COL.get(str(m.get("theme", "grass")), Color(0.4, 0.5, 0.4))
			col.a = al
			canvas.draw_colored_polygon(poly, col)
		var is_city := str(m.get("kind", "hunt")) == "city"
		var rec = m.get("rec", [])
		var edge := C_CITY
		if not is_city and rec is Array and rec.size() == 2:
			edge = _lv_color(rec, 1.0)
		edge.a = al
		_frame(r, edge, 3.0, NODE_RADIUS)
		if id == sel:
			_frame(r.grow(3.0), Color(1, 1, 1, 0.95), 2.0, NODE_RADIUS + 3.0)
		if id == hero_map:
			hero_rect = r
		var lv_txt := ""
		if is_city:
			lv_txt = "Thành Phố"                 # thành phố: ghi "Thành Phố", không ghi level
		elif rec is Array and rec.size() == 2:   # mức level khuyến nghị dưới tên map
			lv_txt = "Lv %d-%d" % [int(rec[0]), int(rec[1])]
		tags.append([str(m.get("name", id)), lv_txt, r, al])
	for t in tags:
		_name_tag(t[0], t[1], t[2], t[3])
	if hero_rect.size.x > 0.0 and maps.has(hero_map):   # chấm hero đúng vị trí tương đối trong map
		var hm: Dictionary = maps[hero_map]
		var fx := clampf(float(hero_pos.x) / maxf(1.0, float(hm.get("w", 1))), 0.0, 1.0)
		var fy := clampf(float(hero_pos.y) / maxf(1.0, float(hm.get("h", 1))), 0.0, 1.0)
		var p := hero_rect.position + Vector2(fx, fy) * hero_rect.size
		canvas.draw_circle(p, 6.0 + 2.0 * sin(pulse * 5.0), Color(1, 0.85, 0.2, 0.5))
		canvas.draw_circle(p, 4.0, Color(1, 0.85, 0.2))
		canvas.draw_circle(p, 2.0, Color.WHITE)
	_draw_legend(sz)

func _draw_legend(sz: Vector2) -> void:
	var font := UiKit.bold_font()
	var items := [[C_GOOD, "Tốt"], [C_HARD, "Khó"], [C_EASY, "Dễ"], [C_CITY, "Thành phố"]]
	var w := 14.0
	for it in items:
		w += 18.0 + _text_w(str(it[1]), 12) + 10.0
	var r := Rect2(sz.x - w - 8.0, sz.y - 32.0, w, 26.0)
	var sb := CharPanel._box(Color("#f3ecd8"), Color("#8c7f5a"), 2, 13)   # viên thuốc bo tròn
	canvas.draw_style_box(sb, r)
	var x := r.position.x + 12.0
	for it in items:
		canvas.draw_circle(Vector2(x + 5.0, r.position.y + 13.0), 5.5, it[0])   # chấm màu hình tròn
		canvas.draw_string(font, Vector2(x + 15.0, r.position.y + 18.0), str(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#2a2a30"))
		x += 18.0 + _text_w(str(it[1]), 12) + 10.0