# vfx_kit – hiệu ứng spell đơn mục tiêu (Godot 4.x)

Làm lại từ Brackeys VFX Bundle (CC0). Toàn bộ dựng bằng code, không cần scene, không phụ thuộc code game của bạn.
Đã chạy thử trên Godot 4.6 (headless + render thật), chưa thử trên 4.7 nhưng chỉ dùng API cơ bản của Godot 4.

> Trong dự án này `vfx_kit` được nối vào game qua `godot_client/vfx/` (không dùng Autoload). Xem `HUONG_DAN_VFX.md` ở gốc dự án.
> Thay đổi so với bản đầu: toạ độ là **cục bộ của node `parent`** (không còn global), `target` nhận thêm `Callable`,
> có `evaporate_ghost()` cho quái tự vẽ bằng `_draw`, thêm kiểu `earth` và `holy`.

## Cài đặt (2 phút)
1. Copy cả thư mục `vfx_kit/` vào gốc project Godot (thành `res://vfx_kit/`). Mở editor để nó import ảnh.
2. Thử riêng: mở `res://vfx_kit/demo/vfx_demo.tscn` rồi bấm F6.
   - Phím 1–8 chọn spell, click chuột để bắn, K giết quái (bốc hơi), R hồi sinh.
3. Dùng trong game: Project Settings > Globals > Autoload, thêm `res://vfx_kit/vfx_manager.gd` với tên `VFX`.

## Gọi hiệu ứng
```gdscript
VFX.cast_single("fire", caster.global_position, monster_node)        # cầu lửa bay + nổ
VFX.cast_single("energy", from_pos, monster_node)                    # sét tức thời
VFX.cast_single("ice", from_pos, monster_node)
VFX.cast_single("death", from_pos, monster_node)
VFX.cast_single("slash", from_pos, monster_node)                     # chém
VFX.cast_single("physical", from_pos, monster_node)                  # đánh thường
VFX.impact_at("physical", hit_pos)                                   # chỉ hiệu ứng trúng đòn
VFX.death_evaporate(monster_sprite, {"free_original": true})         # quái chết bốc hơi (sao chép node sprite)
VFX.cast_area("fire", origin, positions, {"mode": "wave"})            # spell VÙNG: hiệu ứng nhẹ trên từng ô, lan dần (xem AREAS trong vfx_defs.gd)
VFX.evaporate_ghost(ghost_node)                                      # như trên, nhưng bạn tự dựng "bóng" (Node2D) rồi giao vào
```
Toạ độ truyền vào là toạ độ **cục bộ của `parent`**; `target` là `Vector2` | `Node2D` | `Callable() -> Vector2` (hai loại sau là bám theo).
Tùy chọn của `cast_single` (tham số thứ 4):
- `offset`: lệch điểm trúng (vd `Vector2(0, -20)` nếu gốc toạ độ quái nằm ở chân)
- `on_hit`: Callable gọi đúng lúc đạn chạm (hiện số damage, trừ HP... cho khớp hình)
- `parent`: node nhận hiệu ứng (mặc định current_scene; nếu arena nằm trong SubViewport thì truyền node trong đó)
- `blood`: true/false bật tắt máu văng

Kiểu có sẵn: `fire energy ice death earth holy physical slash`.

`death_evaporate`: truyền node sprite của quái (Sprite2D/AnimatedSprite2D), không nên truyền cả node quái kèm thanh HP. Hàm tạo bản sao rồi cho tan thành hơi, nên có thể free quái gốc ngay.

## Chỉnh hiệu ứng
Mọi thông số (màu, kích thước, tốc độ, loại hạt) nằm trong `vfx_defs.gd` > `KINDS`. Thêm spell mới: copy một kind rồi đổi tên/màu.

## Cấu trúc
- `vfx_manager.gd` – logic (autoload `VFX`)
- `vfx_defs.gd` – dữ liệu từng loại spell
- `sheets/` – 9 sprite sheet đã resize (khung 128px, 64px cho máu)
- `tex/` – 19 texture hạt trắng (tô màu bằng code)
- `demo/` – scene thử độc lập
- Cả bộ ~2.6 MB (gói gốc 75 MB)

## Chưa làm (làm tiếp sau)
Spell AOE/vòng/sóng, hiệu ứng cast trên người chơi, buff/heal, đạn tên/giáo cho đánh xa, thiên nhiên (earth/holy), âm thanh, nối vào server (map spell id -> kind).
