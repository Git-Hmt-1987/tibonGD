# fonts — font chữ
Vai trò → tên file (đuôi `.ttf` / `.otf` / `.woff2`):
| File | Dùng cho |
|---|---|
| `ui.ttf` | font mặc định toàn UI (Label, Button, chat...) |
| `ui_bold.ttf` | chữ đậm (title card, tab). Thiếu thì game tự làm đậm từ `ui` |
| `title.ttf` | (dành cho sau) tiêu đề lớn, màn đăng nhập |
| `damage.ttf` | số sát thương/hồi máu bay trên đầu |
| `world.ttf` | tên nhân vật/quái/NPC vẽ trong thế giới |

Cỡ chữ mặc định chỉnh ở `skin.cfg` mục `[fonts]` `size=`. Font có tiếng Việt: kiểm tra có đủ dấu (ă â ê ô ơ ư đ + thanh điệu).
Pixel font: Import → tắt **Antialiasing** + **Hinting = None** nếu bị nhoè.
