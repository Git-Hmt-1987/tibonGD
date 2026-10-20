class_name Minimap
extends Control
## Minimap kiểu Tibia: nền đen, chấm trắng = mình, xanh = player khác,
## đỏ = quái, xám = tường.

var tiles := {}
var kinds := {}
var anchor := Vector2i(20, 20)
var walls: Array = []
var gates: Array = []
var player_id := "local"

func refresh(t: Dictionary, k: Dictionary, a: Vector2i, w: Array, pid: String, g: Array = []):
	tiles = t
	kinds = k
	anchor = a
	walls = w
	gates = g
	player_id = pid
	queue_redraw()

func _draw():
	var r = Rect2(Vector2.ZERO, size)
	draw_rect(r, Color.BLACK)
	var R := 12
	var s: float = min(size.x, size.y) / float(R * 2 + 1)
	var c = size / 2.0
	for w in walls:
		var d: Vector2i = w - anchor
		if abs(d.x) <= R and abs(d.y) <= R:
			draw_rect(Rect2(c + Vector2(d) * s - Vector2(s, s) / 2, Vector2(s, s)), Color(0.4, 0.4, 0.45))
	for g in gates:
		var gd: Vector2i = g - anchor
		if abs(gd.x) <= R and abs(gd.y) <= R:
			draw_circle(c + Vector2(gd) * s, s * 0.9, Color(0.2, 0.8, 0.9))
	for pid in tiles:
		var d: Vector2i = tiles[pid] - anchor
		if abs(d.x) > R or abs(d.y) > R:
			continue
		var col = Color.WHITE if pid == player_id else (Color.RED if kinds.get(pid) == "creature" else Color.GREEN)
		var rad = s * 0.9 if pid == player_id else s * 0.6
		draw_circle(c + Vector2(d) * s, rad, col)
	draw_rect(r, Color(0.35, 0.35, 0.35), false, 2.0)
