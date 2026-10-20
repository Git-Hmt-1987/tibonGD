# Chơi bản web: client trên web, server chạy máy bạn qua Cloudflare Tunnel

```
Bạn bè (trình duyệt) -> https://TEN-BAN.github.io/TEN-REPO/?server=xxxx.trycloudflare.com
                          |  (wss://)
                      Cloudflare -> cloudflared (máy bạn) -> python server (127.0.0.1:7172)
```
Máy bạn không cần IP public, không cần mở router. Máy phải bật và `chay_online` đang chạy thì mọi người mới vào được.

## A. Chuẩn bị một lần
1. Cài **cloudflared** (Windows: tải `cloudflared-windows-amd64.exe`, đổi tên `cloudflared.exe`, bỏ vào PATH). Bản quick tunnel không cần tài khoản.
2. Sửa `TEN-BAN` trong `chay_online.bat` thành tên GitHub của bạn (đây là Origin được phép nối vào server).

## B. Đưa client lên web (chọn 1)
**B1. GitHub Pages tự build (Actions)** — file `.github/workflows/web.yml`
- Tạo repo, push toàn bộ dự án (có `.gitignore` đã loại `save.db`).
- Repo Settings -> Pages -> Source: **GitHub Actions**. Mỗi lần push vào `main` nó tự export Godot Web và đăng.
- Lưu ý: repo **private** muốn dùng Pages cần gói GitHub trả phí. Repo **public** thì mọi người tải được cả sprite/map -> xem cảnh báo bản quyền bên dưới.
- Nếu bước tải Godot báo 404: sửa `GODOT_VERSION` trong workflow cho đúng bản có trên github.com/godotengine/godot-builds/releases.

**B2. Xuất tay rồi tải lên chỗ chứa web tĩnh** (nếu không dùng Pages)
- Godot: Project -> Export -> **Web** (preset có sẵn trong `godot_client/export_presets.cfg`, đã tắt thread nên không cần header đặc biệt) -> xuất ra `web_export/index.html`.
- Tải thư mục `web_export` lên Cloudflare Pages / Netlify / Vercel (kéo-thả) — nơi chứa web tĩnh, miễn phí. (Vercel chỉ dùng để chứa client, không chạy được server.)
- Nhớ đổi `TIBIA_ORIGINS` trong `chay_online.bat` thành địa chỉ trang đó.

## C. Mỗi lần chơi
1. Chạy `chay_online.bat` (hoặc `./chay_online.sh`). Cửa sổ cloudflared in ra `https://xxxx.trycloudflare.com`.
2. Gửi bạn bè link: `https://TRANG-WEB/?server=xxxx.trycloudflare.com` (tham số `server` tự điền ô Máy chủ; hoặc họ tự gõ vào ô đó).
3. Địa chỉ quick tunnel **đổi mỗi lần chạy** -> gửi lại link mới. Muốn địa chỉ cố định phải có tài khoản Cloudflare + tên miền (named tunnel).

## Bảo mật / bản quyền
- Trang https buộc dùng `wss://` (tunnel đã lo). Mật khẩu được mã hóa trên đường truyền; nhưng vẫn **đừng dùng mật khẩu thật** ở nơi khác.
- `TIBIA_ORIGINS` chặn trang web lạ nối vào server của bạn (chỉ chặn trình duyệt, không phải rào chắn tuyệt đối).
- `save.db` chứa tài khoản: đã ở `.gitignore`, đừng gỡ ra.
- Sprite/map/icon Tibia là tài sản CipSoft: repo/trang public có thể bị yêu cầu gỡ. Khuyên để repo private và hạn chế người truy cập.
- Chưa thử được trên Godot thật (môi trường mình không có Godot): bản web có thể cần chỉnh nhỏ (font, âm thanh, hiệu năng).

## File mới/đổi
`.gitignore`, `.github/workflows/web.yml`, `chay_online.bat`, `chay_online.sh`, `godot_client/export_presets.cfg`, `godot_client/LoginScreen.gd`, `godot_client/Main.gd`, `tibia_py/config.py`, `tibia_py/server.py`, `tibia_py/test_netguard.py`.
