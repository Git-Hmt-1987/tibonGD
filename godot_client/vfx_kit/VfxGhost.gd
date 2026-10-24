class_name VfxGhost
extends Node2D
## "Bóng" của quái vừa chết: vẽ lại hình tạm (khối màu) của quái để vfx_manager.evaporate_ghost làm nó bốc hơi.
## Hình vẽ khớp WorldView._draw_creature_placeholder (cùng màu / cỡ / sừng, lấy từ WorldView.creature_look).
##
## KHI CÓ SPRITE QUÁI THẬT: sửa VfxBridge._make_ghost() để trả về Sprite2D/AnimatedSprite2D (đóng băng khung cuối)
## thay cho lớp này. Không phải sửa gì ở vfx_kit hay Main.

const DESIGN_PER_PIXEL := 2.0   # px thiết kế của vfx_kit (ô 64) / px thật của WorldView (ô 32)

var col := Color.WHITE
var radius := 8.0     # bán kính thân (px thật)
var horns := false    # quái bậc cao có sừng


func setup(look: Dictionary) -> void:
	col = look.get("col", Color.WHITE)
	radius = WorldView.TILE * float(look.get("frac", 0.7)) * 0.5
	horns = float(look.get("tier", 0.0)) >= 0.65
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(DESIGN_PER_PIXEL, DESIGN_PER_PIXEL))
	var r := radius
	var c := Vector2(0.0, WorldView.TILE / 2.0 - r)   # gốc node = tâm ô; đáy thân chạm đáy ô
	if horns:
		for sgn in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([c + Vector2(sgn * r * 0.7, -r * 0.4),
				c + Vector2(sgn * r * 0.4, -r * 1.2), c + Vector2(sgn * r * 0.05, -r * 0.8)]), col.darkened(0.35))
	draw_circle(c, r, col)
	draw_arc(c, r, 0.0, TAU, 20, col.darkened(0.5), 1.5)
	for sgn in [-1.0, 1.0]:
		var ec := c + Vector2(sgn * r * 0.38, -r * 0.15)
		draw_circle(ec, maxf(1.6, r * 0.2), Color.WHITE)
		draw_circle(ec + Vector2(0.5, 0.5), maxf(0.8, r * 0.1), Color.BLACK)
