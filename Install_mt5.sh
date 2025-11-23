#!/bin/bash
set -e
export WINEPREFIX=/home/mt5/.wine
export WINEARCH=win64
export DISPLAY=:99

# initialize wine
wineboot -u || true
sleep 2

# Install necessary winetricks components for MT5
# These are commonly used by MT5 (fonts, vcrun, corefonts). May take some time.
winetricks -q corefonts vcrun2015 dotnet48 || true

# Run MT5 installer silently if available
if [ -f "./mt5_setup.exe" ]; then
  echo "[install_mt5] Running MT5 installer..."
  wine mt5_setup.exe /S || true
  sleep 6
else
  echo "[install_mt5] MT5 installer not found. Please upload Exness MT5 installer as mt5_setup.exe to container or change Dockerfile."
fi

# Ensure directory paths
mkdir -p /home/mt5/.wine/drive_c/Program\ Files/MetaTrader\ 5