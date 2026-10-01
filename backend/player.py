import socket
import json
import sys
import os
import time
import subprocess
from typing import Dict, Optional
from config import MPV_SOCKET, AUTO_START_MPV, MPV_COMMAND
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Audio Equalizer Filter Presets for MPV
EQ_PRESETS = {
    "normal": "",
    "bass": "lavfi=[equalizer=f=60:width_type=h:width=50:g=7,equalizer=f=150:width_type=h:width=100:g=4]",
    "bass_boost": "lavfi=[equalizer=f=60:width_type=h:width=50:g=7,equalizer=f=150:width_type=h:width=100:g=4]",
    "vocal": "lavfi=[highpass=f=80,lowpass=f=12000,equalizer=f=1000:width_type=h:width=500:g=4]",
    "treble": "lavfi=[equalizer=f=8000:width_type=h:width=2000:g=6,equalizer=f=12000:width_type=h:width=3000:g=4]",
    "party": "lavfi=[equalizer=f=60:width_type=h:width=50:g=6,equalizer=f=10000:width_type=h:width=3000:g=5]",
    "pop": "lavfi=[equalizer=f=120:width_type=h:width=60:g=4,equalizer=f=1000:width_type=h:width=500:g=3,equalizer=f=8000:width_type=h:width=2000:g=4]",
    "rock": "lavfi=[equalizer=f=60:width_type=h:width=40:g=5,equalizer=f=250:width_type=h:width=150:g=3,equalizer=f=4000:width_type=h:width=1000:g=4,equalizer=f=12000:width_type=h:width=3000:g=5]",
    "jazz": "lavfi=[equalizer=f=100:width_type=h:width=50:g=3,equalizer=f=500:width_type=h:width=250:g=-2,equalizer=f=3000:width_type=h:width=1000:g=3,equalizer=f=10000:width_type=h:width=3000:g=4]",
    "electronic": "lavfi=[equalizer=f=50:width_type=h:width=30:g=8,equalizer=f=120:width_type=h:width=60:g=5,equalizer=f=8000:width_type=h:width=2000:g=6]",
    "acoustic": "lavfi=[equalizer=f=120:width_type=h:width=60:g=3,equalizer=f=1000:width_type=h:width=500:g=3,equalizer=f=6000:width_type=h:width=1500:g=4]"
}



def build_10band_eq_filter(bands: Dict[str, float]) -> str:
    """Build MPV lavfi equalizer string for 10 frequency bands (31Hz, 62Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz)."""
    freq_map = {
        "31": (31, 20),
        "62": (62, 40),
        "125": (125, 80),
        "250": (250, 150),
        "500": (500, 300),
        "1000": (1000, 500),
        "2000": (2000, 1000),
        "4000": (4000, 2000),
        "8000": (8000, 3000),
        "16000": (16000, 4000)
    }
    eq_parts = []
    for key, (freq, width) in freq_map.items():
        gain = float(bands.get(key, 0.0))
        if gain != 0.0:
            eq_parts.append(f"equalizer=f={freq}:width_type=h:width={width}:g={gain}")
    if not eq_parts:
        return ""
    return f"lavfi=[{','.join(eq_parts)}]"



class MPVPlayer:
    def __init__(self):
        self.socket_path = MPV_SOCKET
        self.sock = None
        self.pipe_file = None
        self.process = None
        self.current_audio_device = "alsa/sysdefault:CARD=Headphones" if sys.platform.startswith("linux") else "alsa/plughw:CARD=Headphones,DEV=0"
        self.sim_paused = True
        self.sim_position = 0.0
        self.sim_duration = 0.0
        self.sim_volume = 60
        self.sim_last_update = time.time()
        self.current_eq = "normal"
        self.req_counter = 1
        self._buf = ""
        self.ytdl_stream_proc: Optional[subprocess.Popen] = None

        self._connect()


    def _spawn_mpv(self):
        if self.process and self.process.poll() is None:
            return

        try:
            venv_bin = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "venv", "bin", "yt-dlp")
            ytdl_path = venv_bin if os.path.exists(venv_bin) else "/home/aamps/pi-aamps/venv/bin/yt-dlp"
            cmd = [

                MPV_COMMAND,
                "--idle=yes",
                "--terminal=no",
                "--ytdl=yes",
                "--ytdl-format=bestaudio/best",
                "--cache=yes",
                "--demuxer-max-bytes=8M",
                "--demuxer-readahead-secs=8",
                "--network-timeout=5",
                f"--input-ipc-server={self.socket_path}",
                '--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                "--ytdl-raw-options=extractor-args=youtube:player_client=visionos,remote-components=ejs:github",
                "--no-video"
            ]


            if os.path.exists(ytdl_path):
                cmd.append(f"--script-opts=ytdl_hook-ytdl_path={ytdl_path}")


            logger.info(f"Auto-starting mpv process: {' '.join(cmd)}")
            creationflags = 0
            start_new_session = False
            if sys.platform == "win32":
                creationflags = subprocess.CREATE_NO_WINDOW
            else:
                start_new_session = True

            env = os.environ.copy()
            if sys.platform.startswith("linux"):
                env["XDG_RUNTIME_DIR"] = "/run/user/1000"
                if os.path.exists("/run/user/1000/pulse/native"):
                    env["PULSE_SERVER"] = "unix:/run/user/1000/pulse/native"

            self.process = subprocess.Popen(
                cmd,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                creationflags=creationflags,
                start_new_session=start_new_session,
                env=env
            )

            time.sleep(1.2)
        except Exception as e:
            logger.warning(f"Could not spawn mpv binary ({e}). Using integrated software player state.")


    def _connect(self):
        if self.sock or self.pipe_file:
            return

        attempts = 5 if AUTO_START_MPV else 1
        for attempt in range(attempts):
            try:
                if sys.platform == "win32":
                    if os.path.exists(self.socket_path) or self.socket_path.startswith("\\\\"):
                        self.pipe_file = open(self.socket_path, "r+b", buffering=0)
                        logger.info("Connected to mpv IPC named pipe (Windows)")
                        return
                else:
                    if os.path.exists(self.socket_path):
                        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                        self.sock.connect(self.socket_path)
                        self.sock.settimeout(3.0)
                        logger.info(f"Connected to mpv IPC socket at {self.socket_path}")
                        return
            except Exception as e:
                logger.debug(f"Connect attempt {attempt + 1} failed: {e}")

            if attempt == 0 and AUTO_START_MPV:
                self._spawn_mpv()
            else:
                time.sleep(0.5)


    def _send_command(self, command: list) -> Optional[Dict]:
        self._connect()
        if not self.sock and not self.pipe_file:
            return None

        self.req_counter += 1
        req_id = self.req_counter

        msg = json.dumps({"command": command, "request_id": req_id}) + "\n"
        data_bytes = msg.encode("utf-8")

        try:
            if sys.platform == "win32" and self.pipe_file:
                self.pipe_file.write(data_bytes)
                response = self.pipe_file.readline()
                if response:
                    return json.loads(response.decode("utf-8").strip())
            elif self.sock:
                self.sock.sendall(data_bytes)
                start_time = time.time()
                while time.time() - start_time < 3.0:
                    try:
                        chunk = self.sock.recv(4096).decode("utf-8", errors="ignore")
                        if not chunk:
                            break
                        self._buf += chunk
                        lines = self._buf.split("\n")
                        self._buf = lines[-1]
                        for line in lines[:-1]:
                            if not line.strip():
                                continue
                            try:
                                parsed = json.loads(line)
                                if parsed.get("request_id") == req_id:
                                    return parsed
                            except Exception:
                                pass
                    except socket.timeout:
                        break
        except Exception as e:
            logger.error(f"Error sending command {command} to mpv: {e}")
            self.sock = None
            self.pipe_file = None
            return None

        return None


    def play(self, url: str, duration: Optional[int] = None):
        logger.info(f"Playing media stream: {url}")
        self.sim_paused = False
        self.sim_position = 0.0
        if duration and duration > 0:
            self.sim_duration = float(duration)
        self.sim_last_update = time.time()

        # Stop previous stream process if running
        if hasattr(self, 'ytdl_stream_proc') and self.ytdl_stream_proc:
            try:
                self.ytdl_stream_proc.kill()
                self.ytdl_stream_proc.wait(timeout=1)
            except Exception:
                pass
            self.ytdl_stream_proc = None

        target_url = url
        if sys.platform.startswith("linux") and ("youtube.com" in url or "youtu.be" in url or "googlevideo.com" in url):
            venv_bin = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "venv", "bin", "yt-dlp")
            ytdl_bin = venv_bin if os.path.exists(venv_bin) else "/home/aamps/pi-aamps/venv/bin/yt-dlp"
            
            fifo = "/tmp/pi-aamps-stream.fifo"
            if os.path.exists(fifo):
                try:
                    os.remove(fifo)
                except Exception:
                    pass
            try:
                os.mkfifo(fifo)
            except Exception:
                pass

            logger.info(f"Spawning yt-dlp FIFO stream process for {url}")
            self.ytdl_stream_proc = subprocess.Popen(
                [ytdl_bin, "-f", "bestaudio/best", "-o", fifo, url],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            target_url = fifo

        res = self._send_command(["loadfile", target_url, "replace"])
        self._send_command(["set_property", "pause", False])
        return res or {"status": "ok"}



    def pause(self):
        self._update_sim_pos()
        self.sim_paused = True
        res = self._send_command(["set_property", "pause", True])
        return res or {"status": "ok"}

    def resume(self):
        self.sim_paused = False
        self.sim_last_update = time.time()
        res = self._send_command(["set_property", "pause", False])
        return res or {"status": "ok"}

    def toggle_pause(self):
        if self.sim_paused:
            return self.resume()
        else:
            return self.pause()

    def stop(self):
        self.sim_paused = True
        self.sim_position = 0.0
        res = self._send_command(["stop"])
        return res or {"status": "ok"}

    def seek(self, seconds: float):
        self.sim_position = max(0.0, seconds)
        self.sim_last_update = time.time()
        return self._send_command(["seek", seconds, "absolute"])

    def set_position(self, seconds: float):
        return self.seek(seconds)

    def set_volume(self, volume: int):
        volume = max(0, min(100, volume))
        self.sim_volume = volume
        return self._send_command(["set_property", "volume", volume])



    def get_volume(self) -> int:
        resp = self._send_command(["get_property", "volume"])
        if resp and "data" in resp and resp["data"] is not None:
            self.sim_volume = int(resp["data"])
            return self.sim_volume
        return self.sim_volume

    def set_audio_device(self, device_name: str):
        logger.info(f"Setting mpv audio output device to: {device_name}")
        self.current_audio_device = device_name
        return self._send_command(["set_property", "audio-device", device_name])

    def set_equalizer(self, preset_name: str) -> str:
        if preset_name not in EQ_PRESETS:
            preset_name = "normal"
        self.current_eq = preset_name
        filter_str = EQ_PRESETS[preset_name]
        logger.info(f"Applying Equalizer Preset: {preset_name}")
        self._send_command(["set_property", "af", filter_str])
        return self.current_eq

    def set_custom_equalizer(self, bands: Dict[str, float]) -> str:
        self.current_eq = "custom"
        filter_str = build_10band_eq_filter(bands)
        logger.info(f"Applying 10-Band Custom Equalizer: {filter_str}")
        self._send_command(["set_property", "af", filter_str])
        return "custom"

    def set_loudness_norm(self, enabled: bool):
        self.loudness_norm = enabled
        logger.info(f"Setting MPV Loudness Normalization: {enabled}")
        if enabled:
            self._send_command(["af", "add", "lavfi=[dynaudnorm=f=500:g=31:m=10.0:r=0.9:b=1]"])
        else:
            self._send_command(["af", "del", "lavfi=[dynaudnorm=f=500:g=31:m=10.0:r=0.9:b=1]"])


    def _update_sim_pos(self):
        if not (self.sock or self.pipe_file) and not self.sim_paused:
            now = time.time()
            elapsed = now - self.sim_last_update
            self.sim_last_update = now
            self.sim_position += elapsed
            if self.sim_duration > 0 and self.sim_position >= self.sim_duration:
                self.sim_position = self.sim_duration
                self.sim_paused = True

    def get_status(self) -> Dict:
        status = {
            "paused": self.sim_paused,
            "position": round(self.sim_position, 1),
            "duration": round(self.sim_duration, 1),
            "volume": self.sim_volume,
            "audio_device": self.current_audio_device,
            "equalizer": self.current_eq,
            "loudness_normalization": getattr(self, "loudness_norm", False),
            "connected": bool(self.sock or self.pipe_file)
        }

        if self.sock or self.pipe_file:
            paused_resp = self._send_command(["get_property", "pause"])
            if paused_resp and "data" in paused_resp and isinstance(paused_resp["data"], bool):
                status["paused"] = paused_resp["data"]
                self.sim_paused = paused_resp["data"]

            pos_resp = self._send_command(["get_property", "time-pos"])
            if pos_resp and "data" in pos_resp and pos_resp["data"] is not None and not isinstance(pos_resp["data"], bool):
                try:
                    val = float(pos_resp["data"])
                    if val >= 0:
                        status["position"] = round(val, 1)
                        self.sim_position = status["position"]
                except (ValueError, TypeError):
                    pass
            elif pos_resp and pos_resp.get("data") is None and not status.get("paused"):
                # MPV is connected but not actively playing audio stream
                idle_resp = self._send_command(["get_property", "idle-active"])
                if idle_resp and idle_resp.get("data") is True:
                    status["paused"] = True
                    self.sim_paused = True

            dur_resp = self._send_command(["get_property", "duration"])
            if dur_resp and "data" in dur_resp and dur_resp["data"] is not None and not isinstance(dur_resp["data"], bool):
                try:
                    val = float(dur_resp["data"])
                    if val > 0:
                        status["duration"] = round(val, 1)
                        self.sim_duration = status["duration"]
                except (ValueError, TypeError):
                    pass
        else:
            self._update_sim_pos()

        return status



player = MPVPlayer()
