#!/bin/sh
# Server game + Cloudflare quick tunnel (không cần IP public). Cần: cloudflared trong PATH.
export TIBIA_HOST=127.0.0.1
export TIBIA_ORIGINS="${TIBIA_ORIGINS:-https://TEN-BAN.github.io}"
python3 -m tibia_py.server &
sleep 3
echo "=== Lấy https://xxxx.trycloudflare.com bên dưới; link cho bạn bè: https://TEN-BAN.github.io/TEN-REPO/?server=xxxx.trycloudflare.com ==="
cloudflared tunnel --url http://localhost:7172
