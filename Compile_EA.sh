#!/bin/bash
# compile_ea.sh
# Attempts to compile the .mq5 file using MetaEditor (if available)
export WINEPREFIX=/home/mt5/.wine
export WINEARCH=win64
export DISPLAY=:99

EA_SRC="/home/mt5/EA/UltraSafeSMC.mq5"
EA_DST_WIN="C:\\Users\\$(whoami)\\AppData\\Roaming\\MetaQuotes\\Terminal\\MQL5\\Experts\\UltraSafeSMC\\UltraSafeSMC.mq5"

# try to copy EA into MT5 MQL5 folder - multiple possible terminal paths; we'll copy into common places
mkdir -p "/home/mt5/mt5_data/MQL5/Experts/UltraSafeSMC" || true
cp "$EA_SRC" "/home/mt5/mt5_data/MQL5/Experts/UltraSafeSMC/UltraSafeSMC.mq5" || true

# If metaeditor exists, try to compile
METAEDITOR_PATH="$(winepath -w '/home/mt5/.wine/drive_c/Program Files/MetaTrader 5/metaeditor64.exe' 2>/dev/null || true)"

if [ -x "/home/mt5/.wine/drive_c/Program Files/MetaTrader 5/metaeditor64.exe" ] || [ -n "$METAEDITOR_PATH" ]; then
  echo "[compile_ea] Attempting to compile with MetaEditor..."
  # Try several likely paths
  wine "/home/mt5/.wine/drive_c/Program Files/MetaTrader 5/metaeditor64.exe" /compile:"C:\\Users\\mt5\\mt5_data\\MQL5\\Experts\\UltraSafeSMC\\UltraSafeSMC.mq5" || \
  wine "/home/mt5/.wine/drive_c/Program Files (x86)/MetaTrader 5/metaeditor.exe" /compile:"C:\\Users\\mt5\\mt5_data\\MQL5\\Experts\\UltraSafeSMC\\UltraSafeSMC.mq5" || true
else
  echo "[compile_ea] MetaEditor not found - compilation will be attempted when terminal first runs."
fi