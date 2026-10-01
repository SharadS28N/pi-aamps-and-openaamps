#!/usr/bin/env bash
# One-line installer script for pi-aamps (Pi Advanced Audio & Music Player System)
set -e

echo "========================================================="
echo "   pi-aamps — Automated Raspberry Pi Installer"
echo "========================================================="

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or using sudo: sudo bash install.sh"
  exit 1
fi

echo "[+] Updating apt repositories..."
apt-get update -y

echo "[+] Installing system dependencies (git, nodejs, MPV, FFmpeg, BlueZ, ALSA, Python3)..."
apt-get install -y git nodejs python3 python3-pip python3-venv mpv ffmpeg alsa-utils bluez pulseaudio shairport-sync gmediarender


TMP_REPO="/tmp/pi-aamps-install-repo"
if [ ! -f "run.py" ]; then
  echo "[+] Downloading latest release from GitHub..."
  rm -rf "$TMP_REPO"
  git clone https://github.com/SharadS28N/pi-aamps-and-openaamps.git "$TMP_REPO"
  cd "$TMP_REPO"
fi

INSTALL_DIR="/home/aamps/pi-aamps"
if [ ! -d "/home/aamps" ]; then
  INSTALL_DIR="/opt/pi-aamps"
fi

echo "[+] Deploying pi-aamps files to ${INSTALL_DIR}..."
mkdir -p "$INSTALL_DIR"
cp -rf backend frontend run.py requirements.txt LICENSE README.md "$INSTALL_DIR/"

RUN_USER="aamps"
if ! id "$RUN_USER" &>/dev/null; then
  RUN_USER="root"
fi

chown -R "${RUN_USER}:${RUN_USER}" "$INSTALL_DIR"

echo "[+] Setting up Python virtual environment..."

if [ ! -d "$INSTALL_DIR/venv" ]; then
  python3 -m venv "$INSTALL_DIR/venv"
fi
"$INSTALL_DIR/venv/bin/pip" install --upgrade pip
"$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt"

# Ensure yt-dlp is up to date inside venv
"$INSTALL_DIR/venv/bin/pip" install --upgrade yt-dlp

chown -R "${RUN_USER}:${RUN_USER}" "$INSTALL_DIR"

echo "[+] Configuring ALSA audio volume levels..."

amixer sset Master 60% unmute || true
amixer sset Headphones 60% unmute || true
amixer sset PCM 60% unmute || true

echo "[+] Creating systemd service..."
RUN_USER="aamps"
if ! id "$RUN_USER" &>/dev/null; then
  RUN_USER="root"
fi

cat <<EOF > /etc/systemd/system/pi-aamps.service
[Unit]
Description=pi-aamps - Pi Advanced Audio & Music Player System
After=network.target sound.target bluetooth.target

[Service]
Type=simple
User=${RUN_USER}
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/venv/bin/python ${INSTALL_DIR}/run.py
Restart=always
RestartSec=3
Environment=PORT=8000
Environment=XDG_RUNTIME_DIR=/run/user/1000
Environment=PULSE_SERVER=unix:/run/user/1000/pulse/native
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable pi-aamps.service
systemctl restart pi-aamps.service

IP=$(hostname -I | awk '{print $1}')
echo "========================================================="
echo "  🎉 pi-aamps installed & started successfully!"
echo "  Access Web OS interface at: http://${IP}:8000"
echo "========================================================="

