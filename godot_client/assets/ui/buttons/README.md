# ui/buttons — nền nút (9-slice)
Tên file: `<tên>_<trạng thái>.png`, trạng thái = `normal` `hover` `pressed` `disabled`.
**Chỉ cần `_normal`** — thiếu trạng thái nào game tự làm sáng/tối từ `_normal`.

| Tên | Dùng cho |
|---|---|
| `button` | nút mặc định toàn game (mọi Button chưa tự đặt style: NPC, Depot, House, Auto...) |
| `icon` | nút icon góc phải-dưới (Character/Skills/Battle/VIP/Status/AUTO/Spell/Logout) |
| `fight` | 3 nút Attack / Balanced / Defense (`pressed` = đang bật) |

Lề 9-slice: `[button.<tên>]` `margin=` trong `skin.cfg` (mặc định 6). Kích thước nút icon hiện tại 34x34; nút fight 34x28.
