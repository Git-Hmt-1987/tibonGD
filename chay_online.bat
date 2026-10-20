@echo off
REM Chạy server game + đường hầm Cloudflare (không cần IP public). Cần cloudflared.exe trong PATH (https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/).
REM Server chỉ nghe localhost; chỉ cho trang web của bạn nối vào (sửa ORIGINS cho đúng, nhiều giá trị ngăn bằng dấu phẩy).
set TIBIA_HOST=127.0.0.1
set TIBIA_ORIGINS=https://TEN-BAN.github.io
start "tibia server" cmd /k python -m tibia_py.server
timeout /t 3 >nul
echo === Tìm dòng https://xxxx.trycloudflare.com bên dưới, gửi bạn bè: https://TEN-BAN.github.io/TEN-REPO/?server=xxxx.trycloudflare.com ===
cloudflared tunnel --url http://localhost:7172
