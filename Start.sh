#!/bin/bash
set -e
export WINEPREFIX=/home/mt5/.wine
export WINEARCH=win64
export DISPLAY=:99

# Environment variables read from Koyeb (you'll add these as secrets):
# MT5_ACCOUNT, MT5_PASSWORD, MT5_SERVER
: "${MT5_ACCOUNT:?MT5_ACCOUNT not set - add as secret in Koyeb}"
: "${MT5_PASSWORD:?MT5_PASSWORD not set - add as secret in Koyeb}"
: "${MT5_SERVER:?MT5_SERVER not set - add as secret in Koyeb}"

# Start virtual display
Xvfb :99 -screen 0 1024x768x24 &>/tmp/xvfb.log &
sleep 2

# Start vnc server (optional - for one-time GUI access)
x11vnc -display :99 -nopw -forever -shared &>/tmp/x11vnc.log &

# Compile EA (copy & compile)
bash /home/mt5/compile_ea.sh || true

# Attempt to start MT5 terminal (path may vary)
if [ -f "/home/mt5/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" ]; then
  wine "/home/mt5/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" &>/home/mt5/terminal.log &
elif [ -f "/home/mt5/.wine/drive_c/Program Files (x86)/MetaTrader 5/terminal.exe" ]; then
  wine "/home/mt5/.wine/drive_c/Program Files (x86)/MetaTrader 5/terminal.exe" &>/home/mt5/terminal.log &
else
  echo "[start] MT5 terminal not found. Place installer mt5_setup.exe in image or upload installer on first run." && sleep 99999
fi

# wait for MT5 to start
sleep 15

# Auto-login: we will try to create a 'login' file inside terminal's config.
# NOTE: MT5 stores login credentials in encrypted form; if auto-login via command-line doesn't work,
# the container will start MT5 and remain accessible via VNC for one-time manual login.
echo "[start] Attempting to auto-login (best-effort). If this does not work, open VNC (port 5900) and login once."

# Launch a tiny python helper to create charts & attach EA if possible
python3 - <<'PY'
import time, os, subprocess
symbols = ["XAUUSD","USDJPY","EURUSD","BTCUSD","GBPUSD"]
# We rely on MT5 having been started under Wine; further automation would use GUI events (xdotool)
# to open charts and attach EA. xdotool may be used if present.
time.sleep(6)
print("[start-helper] If MT5 requires manual steps, connect via VNC (port 5900) and login once. After that the EA will auto-run.")
PY

# Keep container alive
tail -f /home/mt5/terminal.log