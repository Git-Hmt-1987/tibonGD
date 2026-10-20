@echo off
cd /d "%~dp0"
set TIBIA_HOST=127.0.0.1
set TIBIA_ORIGINS=https://git-hmt-1987.github.io
start "tibia server" /D "%~dp0" cmd /k python -m tibia_py.server
timeout /t 5 >nul
echo === Tim dong https://xxxx.trycloudflare.com ben duoi ===
"%~dp0cloudflared.exe" tunnel --url http://localhost:7172
pause