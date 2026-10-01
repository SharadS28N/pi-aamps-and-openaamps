# Deploying pi-aamps on Raspberry Pi

## System Requirements
- **Raspberry Pi**: 3B, 3B+, 4, 5, or Zero 2 W
- **OS**: Raspberry Pi OS (Debian 12 Bookworm / 13 Trixie)
- **Audio Hardware**: 3.5mm Headphone Jack, HDMI, USB DAC, or HAT DAC (HiFiBerry, Allo, IQaudio)

## Quick Deployment Steps
1. SSH into your Raspberry Pi:
   ```bash
   ssh aamps@192.168.18.159
   ```
2. Clone repository or copy package:
   ```bash
   git clone https://github.com/SharadS28N/pi-aamps-and-openaamps.git pi-aamps
   cd pi-aamps
   ```
3. Run installer:
   ```bash
   sudo bash install.sh
   ```
4. Access Web OS:
   `http://192.168.18.159:8000`
