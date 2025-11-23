# Dockerfile for MT5 + Wine + Auto-run EA on Linux (Koyeb)
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV WINEPREFIX=/home/mt5/.wine
ENV WINEARCH=win64
ENV MT5_DIR="/home/mt5/mt5"
ENV DISPLAY=:99

RUN apt-get update && apt-get install -y \
    wget ca-certificates gnupg2 software-properties-common \
    xvfb x11vnc xdotool unzip p7zip-full \
    wine64 wine32 winbind cabextract winetricks \
    xterm sudo python3 python3-pip

# create user
RUN useradd -ms /bin/bash mt5 && echo "mt5 ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER mt5
WORKDIR /home/mt5

# Download Exness MT5 installer (may change; if link breaks, upload installer instead)
RUN wget -O mt5_setup.exe "https://www.exness.com/mt5/ExnessTerminal5Setup.exe" || true

# helper scripts will handle installation using wine
COPY install_mt5.sh /home/mt5/install_mt5.sh
COPY start.sh /home/mt5/start.sh
COPY compile_ea.sh /home/mt5/compile_ea.sh
COPY ultra_safe_smc.mq5 /home/mt5/EA/UltraSafeSMC.mq5

RUN chmod +x /home/mt5/install_mt5.sh /home/mt5/start.sh /home/mt5/compile_ea.sh

# install mt5 and prepare
RUN /home/mt5/install_mt5.sh

EXPOSE 5900

# start script will run Xvfb, start MT5, compile the EA and attempt to autologin & open charts
ENTRYPOINT ["/home/mt5/start.sh"]