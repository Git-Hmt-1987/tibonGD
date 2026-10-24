class_name ActionDock
extends PanelContainer
## Panel icon góc phải-dưới (thiết kế lại): 1 hàng [Gold | nút tròn bật/tắt AUTO nhỏ],
## lưới 5x2 ô icon có chữ phím tắt. Chỉ lo giao diện: bấm ô -> phát `action(id)`, TibiaUI/Main xử lý.
## Thay hình: thả PNG vào assets/icons/buttons/ (btn_char.png ...) — thiếu thì dùng icon vector (DockIcons.gd).

signal action(id: String)

const CELL := Vector2(36, 36)
const TOP_H := 28   # chiều cao hàng Gold = đường kính nút AUTO
const GAP := 4
const COLS := 5
const GRID_W := 5 * 36 + 4 * 4   # bề ngang lưới icon
## [id, tên icon PNG, phím tắt hiển thị, tooltip]. id rỗng = ô trống dự phòng.
const LAYOUT := [
	["char", "btn_char", "C", "Nhân vật & trang bị (C)"],
	["skills", "btn_skills", "K", "Skills (K)"],
	["battle", "btn_battle", "B", "Battle list (B)"],
	["map", "btn_map", "M", "Bản đồ thế giới (M)"],
	["party", "btn_party", "P", "Party (P)"],
	["vip", "btn_vip", "V", "Online / VIP (V)"],
	["status", "btn_status", "U", "Trạng thái (U)"],
	["spell", "btn_spell", "O", "Spells (O)"],
	["autocfg", "btn_autocfg", "Y", "Cấu hình Auto (Y)"],
	["logout", "btn_logout", "", "Logout"],
]

var auto_btn: DockCell      # nút tròn AUTO (toggle_mode; TibiaUI nối signal toggled)
var logout_cell: DockCell
var cells := {}             # id -> DockCell
var gold_lab: Label


func _init() -> void:
	add_theme_stylebox_override("panel", UiSkin.panel("dock"))   # nền sáng + viền xanh theo UiTheme (đổi ở UiTheme.ACCENT)
	UiKit.block_world(self)   # chuột trên panel không lọt xuống bản đồ
	# neo góc phải-dưới, phình lên/sang trái theo kích thước nội dung
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_right = -8
	offset_left = -9
	offset_bottom = -8
	offset_top = -9
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN


func build() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)

	# --- 1 dòng: Gold (giãn) + nút tròn AUTO nhỏ (cao bằng ô Gold)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	v.add_child(row)
	var gp := _gold_pill()
	gp.size_flags_horizontal = SIZE_SHRINK_BEGIN
	gp.custom_minimum_size = Vector2(roundf(GRID_W * 0.7), TOP_H)   # ô Gold = 70% bề ngang panel
	row.add_child(gp)
	var sp := Control.new()
	sp.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(sp)
	auto_btn = DockCell.new()
	auto_btn.round_btn = true
	auto_btn.toggle_mode = true
	auto_btn.setup("auto", "btn_auto", "T", "Bật/tắt Auto săn theo vùng (T)", Vector2(TOP_H, TOP_H))
	row.add_child(auto_btn)

	# --- lưới 5x2
	var g := GridContainer.new()
	g.columns = COLS
	g.add_theme_constant_override("h_separation", GAP)
	g.add_theme_constant_override("v_separation", GAP)
	v.add_child(g)
	for d in LAYOUT:
		var cell := DockCell.new()
		cell.empty_slot = (d[0] == "")
		cell.setup(str(d[0]), str(d[1]), str(d[2]), str(d[3]), CELL)
		var cid := str(d[0])
		if cid != "":
			cell.pressed.connect(func(): action.emit(cid))
			cells[cid] = cell
		g.add_child(cell)
	logout_cell = cells["logout"]


func _gold_pill() -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, TOP_H)
	var sb := DockCell._box(UiTheme.body().lightened(0.55), UiTheme.accent_dark(), 2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 4
	sb.content_margin_right = 10
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.tooltip_text = "Gold trong túi"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	p.add_child(h)
	var coin := DockGlyph.new()
	coin.glyph = "coin"
	coin.custom_minimum_size = Vector2(20, 20)
	coin.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(coin)
	gold_lab = Label.new()
	gold_lab.text = "0"
	gold_lab.size_flags_horizontal = SIZE_EXPAND_FILL
	gold_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_lab.add_theme_font_size_override("font_size", 13)
	gold_lab.add_theme_font_override("font", UiKit.bold_font())
	gold_lab.add_theme_color_override("font_color", Color(0.72, 0.45, 0.05))
	h.add_child(gold_lab)
	return p


func set_gold(g: int) -> void:
	if gold_lab != null:
		gold_lab.text = UiKit.fmt_int(g)


## Bật/tắt viền vàng cho một ô (ô "đang mở"). id lạ = bỏ qua.
func set_lit(id: String, on: bool) -> void:
	if cells.has(id):
		(cells[id] as DockCell).lit = on


func set_online(on: bool) -> void:
	logout_cell.icon_id = "logout" if on else "login"
	logout_cell.tooltip_text = "Logout" if on else "Login"
	logout_cell.queue_redraw()


## Control nhỏ chỉ vẽ một icon vector (coin cho pill Gold).
class DockGlyph extends Control:
	var glyph := ""

	func _draw() -> void:
		DockIcons.draw(self, glyph, size / 2.0, minf(size.x, size.y) * 0.45)
