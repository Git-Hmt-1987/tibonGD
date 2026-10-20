# Icon thay thế (client Godot)

Mọi icon hiện đang là **chữ tạm**. Muốn dùng ảnh thật: thả file PNG **đúng tên** dưới đây vào thư mục này
(`godot_client/icons/`), mở lại Godot cho nó import — code tự nhận, không cần sửa gì.
Kích thước gợi ý: nút = 32×32 (Attack/Balance/Defense 34×28), ô hotbar = 32×32.

| Tên file (không phân biệt dùng ở đâu) | Dùng cho |
|---|---|
| `fight_attack.png` `fight_balanced.png` `fight_defense.png` | 3 icon chế độ chiến đấu (bật = sáng, tắt = xám; app tự làm tối ảnh khi tắt) |
| `status_premium.png` | icon Premium cạnh Attack/Balance/Defense, căn phải (sáng = có Premium, xám = không) |
| `btn_char.png` `btn_skills.png` `btn_battle.png` `btn_vip.png` `btn_status.png` `btn_auto.png` `btn_spell.png` `btn_logout.png` | hàng icon góc phải-dưới |
| `item_<id>.png` (vd `item_238.png`) | ô hotbar gán item/pot/rune theo **id item** |
| `spell_<id>.png` (vd `spell_ultimate_healing.png`) | ô hotbar gán spell theo **id spell** (xem `tibia_py/spell_data/spells.json`, trường `id`) |
