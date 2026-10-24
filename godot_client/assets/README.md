# assets/ — nơi dán PNG / font cho giao diện

**Dán file đúng tên vào đúng thư mục → mở Godot editor 1 lần (tự import) → chạy game. Không cần sửa code.**
Thiếu file nào thì game dùng hình tạm hiện tại (khối màu / chữ), nên dán dần từng cái cũng được.

## Cây thư mục
```
assets/
  skin.cfg            cấu hình tùy chọn: lề 9-slice, màu, cỡ chữ, fps hiệu ứng (xem file, có chú thích)
  ui/
    panels/           nền panel / card / khung đăng nhập / tooltip
    buttons/          nền nút (normal / hover / pressed / disabled)
    bars/             thanh HP / Mana / Stamina / EXP / máu mục tiêu
    slots/            ô hotbar
    misc/             nền màn đăng nhập, logo...
  icons/
    buttons/          icon nút góc phải-dưới (btn_*.png)
    fight/            Attack / Balanced / Defense
    status/           Premium (sau này: icon condition)
    items/            item_<id>.png
    spells/           spell_<id>.png
    skills/           (dành cho sau: icon skill)
  fonts/              ui / ui_bold / title / damage / world  (.ttf .otf .woff2)
  fx/
    spell/            riêng từng spell: <spell_id>.png, <spell_id>_shot.png, <spell_id>_cast.png
    me/               hiệu ứng CONST_ME_* (server gửi tên)  -> magic_blue.png ...
    shoot/            đạn CONST_ANI_*                        -> fire.png ...
    element/          mặc định theo hệ: fire / ice / energy / earth / holy / death / physical / healing
    hit/              hiệu ứng trúng đòn: hit / heal / death / mana
    basic/            đạn đánh thường theo nghề: bolt (Sorc) / stone (Druid) / arrow (Paladin)
  anim/
    characters/       (dành cho sau) khung nhân vật — hiện vẫn ở godot_client/sprites/
    creatures/        (dành cho sau) khung quái
    ui/               (dành cho sau) animation UI (lên level, loading...)
```
Thư mục cũ `godot_client/icons/` và `godot_client/sprites/` **vẫn chạy như cũ** (icon cũ vẫn được đọc). Gộp vào đây sau, khi chốt bản client mới nhất.

## Quy ước chung
- Tên file **chữ thường, không dấu, không dấu cách**, đuôi `.png` (font: `.ttf/.otf/.woff2`).
- Mọi thứ đều **tùy chọn**. Chỉ cần đủ file tối thiểu của từng loại (ghi trong README của thư mục đó).
- Nền trong suốt dùng được. Ảnh khung giãn (panel/nút/thanh) dùng **9-slice**: góc giữ nguyên, lề khai báo trong `skin.cfg`.
- Pixel-art: chọn PNG trong Godot → tab **Import** → preset **2D Pixel** (tắt Filter) → **Reimport**. (Ảnh mịn/vector thì để mặc định.)
- Sau khi dán file mới lúc game đang chạy: tắt rồi chạy lại (ảnh được cache trong phiên).

## Kiểm tra đã nhận chưa
Chạy bằng F5 từ editor, xem cửa sổ **Output**: dòng `[skin] N/M asset đã nhận` + danh sách file đã nhận
(danh sách đầy đủ file mong đợi nằm ở `skin/UiAssets.gd` → `MANIFEST`).

## Hiệu ứng (fx/) — dải khung
PNG xếp các khung **từ trái sang phải, trên xuống dưới**, mỗi khung vuông = chiều cao ảnh (vd 64x64 x 8 khung = ảnh 512x64).
Khác chuẩn thì khai báo trong `skin.cfg` mục `[fx.<thư mục>.<tên>]` (frame_w, frame_h, frames, fps, loop, size).
Đạn bay (shoot/, *_shot, basic/): vẽ khung **hướng sang phải →**, game tự xoay theo hướng bay.
