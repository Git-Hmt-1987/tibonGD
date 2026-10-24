# ui/bars — thanh chỉ số
Mỗi thanh có 2 file: `<tên>_bg.png` (nền/khung) và `<tên>_fill.png` (phần đầy, giãn theo %).

| Tên | Dùng cho | Cao hiện tại |
|---|---|---|
| `hp` | máu bản thân (VitalsBlock) | 14 px |
| `mana` | mana | 14 px |
| `stamina` | stamina — **vẽ `_fill` màu trắng/xám**, game tô xanh/cam/đỏ theo mức | 14 px |
| `exp` | thanh EXP đáy màn hình + trong Status | 12 px |
| `target` | máu quái đang nhắm | 16 px |

Chỉ có `_bg` hoặc chỉ có `_fill` cũng được (phần còn lại dùng màu tạm). Lề 9-slice: `[bar.<tên>]` `margin=` (mặc định 2).
