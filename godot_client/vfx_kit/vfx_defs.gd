extends RefCounted
## Dữ liệu hiệu ứng (chỉ là const, không có logic). Kích thước tính theo "px thiết kế" (1 ô = 64px).
## Muốn chỉnh màu / kích thước / tốc độ một spell: sửa ở KINDS bên dưới.
## Muốn thêm spell mới: thêm 1 khóa vào KINDS (copy một kind có sẵn rồi đổi).

const ROOT := "res://vfx_kit/"

# Sprite sheet đã đóng gói lại: số frame, số cột, kích thước 1 frame (px), fps.
const SHEETS := {
	"fire_point":     {"count": 30, "cols": 6, "size": 128, "fps": 30.0},
	"explosion":      {"count": 26, "cols": 6, "size": 128, "fps": 30.0},
	"electric_ring":  {"count": 30, "cols": 6, "size": 128, "fps": 36.0},
	"impact_white":   {"count": 14, "cols": 6, "size": 128, "fps": 36.0},
	"big_hit":        {"count": 11, "cols": 6, "size": 128, "fps": 30.0},
	"blood_impact":   {"count": 24, "cols": 6, "size": 64,  "fps": 36.0},
	"wavy_blue":      {"count": 30, "cols": 6, "size": 128, "fps": 30.0},
	"wavy_purple":    {"count": 30, "cols": 6, "size": 128, "fps": 30.0},
	"star_explosion": {"count": 29, "cols": 6, "size": 128, "fps": 36.0},
}

# Công thức từng loại spell đơn mục tiêu.
#
# Mỗi kind có thể có:
#   "projectile": đạn bay từ caster tới mục tiêu
#       type "sheet": đạn là sprite sheet lặp (key "sheet")
#       type "orb":   đạn là 1 texture tô màu (key "tex")
#       "size" (px), "speed" (px/giây), "color", "additive"
#       "trail": {tex, color, amount, life, size}  (vệt đuôi)
#   "bolt": tia sét tức thời (Line2D răng cưa)
#   "impact": danh sách lớp hiệu ứng khi chạm quái. Mỗi lớp là một trong:
#       {"sheet": tên, ...}   chạy sprite sheet 1 lần
#       {"tex": tên, ...}     texture "bật lên rồi tan"
#       {"burst": tên, ...}   hạt bắn tung tóe
#     key chung: size (px), color, additive, delay (giây),
#                rot_rand (xoay ngẫu nhiên), face_dir (xoay theo hướng đánh)
#   "blood": true nếu muốn có máu văng (có thể tắt từng lần gọi bằng opts)
const KINDS := {
	# ---------- LỬA: quả cầu lửa bay + nổ ----------
	"fire": {
		"projectile": {
			"type": "sheet", "sheet": "fire_point", "size": 54.0, "speed": 560.0,
			"additive": true, "color": Color(1, 1, 1, 1),
			"trail": {"tex": "flame_01", "color": Color(1.0, 0.55, 0.15, 0.9),
				"amount": 16, "life": 0.35, "size": 30.0},
		},
		"impact": [
			{"sheet": "explosion", "size": 96.0, "rot_rand": true},
			{"tex": "spotlight_03", "size": 120.0, "color": Color(1, 0.7, 0.3, 0.9), "additive": true, "life": 0.25},
			{"burst": "flame_01", "amount": 8, "speed": 70.0, "life": 0.45, "size": 22.0,
				"color": Color(1.0, 0.6, 0.2, 0.9), "additive": true},
		],
	},
	# ---------- SÉT / ENERGY: tia tức thời + vòng điện ----------
	"energy": {
		"bolt": {"color": Color(0.55, 0.85, 1.0, 1.0), "width": 5.0, "duration": 0.24,
			"segments": 9, "jitter": 16.0},
		"impact": [
			{"sheet": "electric_ring", "size": 96.0, "additive": true, "rot_rand": true},
			{"tex": "spark_05", "size": 90.0, "color": Color(0.7, 0.9, 1.0, 1.0), "additive": true, "life": 0.22, "rot_rand": true},
			{"burst": "star_04", "amount": 7, "speed": 110.0, "life": 0.35, "size": 18.0,
				"color": Color(0.7, 0.9, 1.0, 1.0), "additive": true},
		],
	},
	# ---------- BĂNG: cầu xanh + hơi lạnh ----------
	"ice": {
		"projectile": {
			"type": "orb", "tex": "circle_05", "size": 52.0, "speed": 500.0,
			"additive": true, "color": Color(0.55, 0.85, 1.0, 1.0),
			"trail": {"tex": "star_04", "color": Color(0.7, 0.92, 1.0, 0.9),
				"amount": 14, "life": 0.35, "size": 20.0},
		},
		"impact": [
			{"sheet": "wavy_blue", "size": 88.0, "additive": true},
			{"tex": "star_08", "size": 90.0, "color": Color(0.75, 0.95, 1.0, 1.0), "additive": true, "life": 0.3, "rot_rand": true},
			{"burst": "star_04", "amount": 8, "speed": 90.0, "life": 0.5, "size": 16.0,
				"color": Color(0.8, 0.95, 1.0, 1.0), "additive": true},
		],
	},
	# ---------- DEATH: cầu tím + khói ----------
	"death": {
		"projectile": {
			"type": "orb", "tex": "circle_05", "size": 52.0, "speed": 460.0,
			"additive": true, "color": Color(0.75, 0.3, 1.0, 1.0),
			"trail": {"tex": "smoke_03", "color": Color(0.45, 0.15, 0.65, 0.8),
				"amount": 14, "life": 0.4, "size": 34.0},
		},
		"impact": [
			{"sheet": "wavy_purple", "size": 92.0, "additive": true},
			{"tex": "magic_03", "size": 80.0, "color": Color(0.85, 0.5, 1.0, 1.0), "additive": true, "life": 0.3},
			{"burst": "smoke_03", "amount": 8, "speed": 50.0, "life": 0.6, "size": 30.0,
				"color": Color(0.4, 0.15, 0.55, 0.8), "additive": false},
		],
	},
	# ---------- ĐẤT / ĐỘC: cầu xanh lá + vòng độc + đất bắn ----------
	"earth": {
		"projectile": {
			"type": "orb", "tex": "circle_05", "size": 48.0, "speed": 480.0,
			"additive": true, "color": Color(0.45, 1.0, 0.3, 1.0),
			"trail": {"tex": "smoke_03", "color": Color(0.35, 0.75, 0.2, 0.85),
				"amount": 14, "life": 0.4, "size": 30.0, "additive": false},
		},
		"impact": [
			{"sheet": "electric_ring", "size": 90.0, "additive": true, "rot_rand": true,
				"color": Color(0.5, 1.0, 0.3, 1.0)},
			{"tex": "circle_05", "size": 80.0, "color": Color(0.55, 1.0, 0.35, 0.9), "additive": true, "life": 0.25},
			{"burst": "dirt_01", "amount": 8, "speed": 90.0, "life": 0.5, "size": 22.0,
				"color": Color(0.5, 0.75, 0.3, 1.0), "additive": false},
		],
	},
	# ---------- THÁNH: cầu vàng + sao lóe ----------
	"holy": {
		"projectile": {
			"type": "orb", "tex": "circle_05", "size": 48.0, "speed": 520.0,
			"additive": true, "color": Color(1.0, 0.9, 0.45, 1.0),
			"trail": {"tex": "star_04", "color": Color(1.0, 0.95, 0.6, 0.95),
				"amount": 14, "life": 0.35, "size": 20.0},
		},
		"impact": [
			{"sheet": "impact_white", "size": 84.0, "additive": true, "rot_rand": true,
				"color": Color(1.0, 0.9, 0.5, 1.0)},
			{"tex": "magic_03", "size": 96.0, "color": Color(1.0, 0.92, 0.55, 1.0), "additive": true, "life": 0.35},
			{"burst": "star_04", "amount": 8, "speed": 95.0, "life": 0.5, "size": 16.0,
				"color": Color(1.0, 0.95, 0.65, 1.0), "additive": true},
		],
	},
	# ---------- ĐÁNH THƯỜNG (va chạm vật lý) ----------
	"physical": {
		"impact": [
			{"sheet": "impact_white", "size": 70.0, "additive": true, "rot_rand": true,
				"color": Color(1.0, 0.95, 0.8, 1.0)},
			{"burst": "star_04", "amount": 5, "speed": 100.0, "life": 0.28, "size": 14.0,
				"color": Color(1.0, 0.9, 0.6, 1.0), "additive": true},
		],
		"blood": true,
	},
	# ---------- CHÉM: vệt cong theo hướng đánh ----------
	"slash": {
		"impact": [
			{"tex": "slash_03", "size": 116.0, "color": Color(1, 1, 1, 1), "additive": true,
				"life": 0.22, "face_dir": true, "sweep": 14.0},
			{"tex": "slash_03", "size": 90.0, "color": Color(1.0, 0.85, 0.5, 0.8), "additive": true,
				"life": 0.26, "face_dir": true, "sweep": 22.0, "delay": 0.04},
			{"sheet": "impact_white", "size": 60.0, "additive": true, "rot_rand": true,
				"color": Color(1.0, 0.95, 0.8, 1.0)},
		],
		"blood": true,
	},
}


# Spell VÙNG (AOE): hiệu ứng NHẸ trên TỪNG Ô của vùng, lan dần ra (sóng) thay vì một hiệu ứng nặng.
#   "tile":   danh sách lớp vẽ trên mỗi ô (cùng cú pháp lớp như "impact" ở trên; nên chỉ dùng sheet/tex, KHÔNG dùng burst vì có thể ~100 ô)
#   "center": lớp bổ sung ở TÂM vùng, chỉ dùng khi vùng là quả cầu rơi xa người cast (mode "ball")
#   "step":   giây trễ cho mỗi ô khoảng cách tính từ điểm bắt đầu lan (0 = nổ cùng lúc)
# Kiểu nào không có trong AREAS thì spell vùng của kiểu đó rơi về hiệu ứng cũ (khối màu tạm).
const _PHYS_AREA := {
	"step": 0.04,
	"tile": [
		{"sheet": "impact_white", "size": 70.0, "additive": true, "rot_rand": true, "color": Color(1.0, 0.95, 0.8, 1.0)},
	],
	"center": [
		{"sheet": "big_hit", "size": 140.0, "additive": true, "color": Color(1.0, 0.95, 0.8, 1.0)},
	],
}

const AREAS := {
	"fire": {
		"step": 0.045,
		"tile": [
			{"sheet": "fire_point", "size": 80.0, "additive": true, "rot_rand": true, "color": Color(1.0, 0.62, 0.28, 1.0)},
		],
		"center": [
			{"sheet": "explosion", "size": 170.0, "rot_rand": true},
			{"tex": "spotlight_03", "size": 220.0, "color": Color(1, 0.7, 0.3, 0.9), "additive": true, "life": 0.3},
		],
	},
	"energy": {
		"step": 0.04,
		"tile": [
			{"sheet": "electric_ring", "size": 74.0, "additive": true, "rot_rand": true},
			{"tex": "spark_05", "size": 84.0, "color": Color(0.7, 0.9, 1.0, 1.0), "additive": true, "life": 0.2, "rot_rand": true},
		],
		"center": [
			{"sheet": "electric_ring", "size": 170.0, "additive": true, "rot_rand": true},
			{"tex": "spark_06", "size": 150.0, "color": Color(0.7, 0.9, 1.0, 1.0), "additive": true, "life": 0.25, "rot_rand": true},
		],
	},
	"ice": {
		"step": 0.05,
		"tile": [
			{"sheet": "wavy_blue", "size": 86.0, "additive": true, "color": Color(0.6, 0.85, 1.0, 1.0)},
		],
		"center": [
			{"tex": "star_08", "size": 150.0, "color": Color(0.75, 0.95, 1.0, 1.0), "additive": true, "life": 0.35, "rot_rand": true},
			{"sheet": "wavy_blue", "size": 130.0, "additive": true},
		],
	},
	"death": {
		"step": 0.05,
		"tile": [
			{"sheet": "wavy_purple", "size": 86.0, "additive": true},
		],
		"center": [
			{"tex": "magic_03", "size": 130.0, "color": Color(0.85, 0.5, 1.0, 1.0), "additive": true, "life": 0.35},
			{"sheet": "wavy_purple", "size": 130.0, "additive": true},
		],
	},
	"earth": {
		"step": 0.05,
		"tile": [
			{"sheet": "electric_ring", "size": 70.0, "additive": true, "rot_rand": true, "color": Color(0.5, 1.0, 0.3, 1.0)},
			{"tex": "dirt_01", "size": 64.0, "color": Color(0.5, 0.75, 0.3, 1.0), "life": 0.4, "rot_rand": true},
		],
		"center": [
			{"sheet": "electric_ring", "size": 160.0, "additive": true, "rot_rand": true, "color": Color(0.5, 1.0, 0.3, 1.0)},
			{"tex": "circle_05", "size": 150.0, "color": Color(0.55, 1.0, 0.35, 0.9), "additive": true, "life": 0.3},
		],
	},
	"holy": {
		"step": 0.045,
		"tile": [
			{"sheet": "impact_white", "size": 78.0, "additive": true, "rot_rand": true, "color": Color(1.0, 0.9, 0.5, 1.0)},
			{"tex": "magic_03", "size": 70.0, "color": Color(1.0, 0.92, 0.55, 1.0), "additive": true, "life": 0.3},
		],
		"center": [
			{"tex": "magic_03", "size": 160.0, "color": Color(1.0, 0.92, 0.55, 1.0), "additive": true, "life": 0.4},
			{"sheet": "impact_white", "size": 150.0, "additive": true, "color": Color(1.0, 0.9, 0.5, 1.0)},
		],
	},
	"physical": _PHYS_AREA,
	"slash": _PHYS_AREA,
}
