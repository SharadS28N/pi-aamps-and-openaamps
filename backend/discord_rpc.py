import json
import logging
import os
import struct
import sys
import threading
import time
from typing import Optional, Dict, Any

logger = logging.getLogger("discord_rpc")

# Default OpenAamps application client ID and Public Key
DEFAULT_CLIENT_ID = os.environ.get("DISCORD_CLIENT_ID", "1552567371615440896")
PUBLIC_KEY = os.environ.get("DISCORD_PUBLIC_KEY", "82d9fd585caa22bef8d40fdbf6ad6b70d60c58fae786beb623ab04d408d87438")

class DiscordRPC:
    def __init__(self, client_id: str = DEFAULT_CLIENT_ID):
        self.client_id = client_id
        self._pipe = None
        self._connected = False
        self._current_presence: Dict[str, Any] = {}
        self._lock = threading.Lock()

    def _get_pipe_path(self) -> Optional[str]:
        if sys.platform == "win32":
            for i in range(10):
                path = rf"\\.\pipe\discord-ipc-{i}"
                if os.path.exists(path):
                    return path
            return rf"\\.\pipe\discord-ipc-0"
        else:
            env_paths = [
                os.environ.get("XDG_RUNTIME_DIR"),
                os.environ.get("TMPDIR"),
                os.environ.get("TMP"),
                os.environ.get("TEMP"),
                "/tmp",
            ]
            for env in env_paths:
                if not env:
                    continue
                for i in range(10):
                    path = os.path.join(env, f"discord-ipc-{i}")
                    if os.path.exists(path):
                        return path
            return None

    def connect(self) -> bool:
        with self._lock:
            if self._connected:
                return True
            pipe_path = self._get_pipe_path()
            if not pipe_path:
                return False

            try:
                if sys.platform == "win32":
                    self._pipe = open(pipe_path, "w+b")
                else:
                    import socket
                    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                    sock.connect(pipe_path)
                    self._pipe = sock

                # Send Handshake (Opcode 0)
                handshake = json.dumps({"v": 1, "client_id": self.client_id})
                self._send(0, handshake)
                opcode, response = self._read()
                if opcode == 1:
                    self._connected = True
                    logger.info("Connected to Discord RPC IPC successfully")
                    return True
            except Exception as e:
                logger.debug(f"Discord IPC connect failed: {e}")
                self._disconnect()
            return False

    def _disconnect(self):
        self._connected = False
        if self._pipe:
            try:
                self._pipe.close()
            except Exception:
                pass
            self._pipe = None

    def _send(self, opcode: int, payload: str):
        data = payload.encode("utf-8")
        header = struct.pack("<II", opcode, len(data))
        if sys.platform == "win32":
            self._pipe.write(header + data)
            self._pipe.flush()
        else:
            self._pipe.sendall(header + data)

    def _read(self):
        if sys.platform == "win32":
            header = self._pipe.read(8)
            if len(header) < 8:
                raise ConnectionError("Short read on header")
            opcode, length = struct.unpack("<II", header)
            payload = self._pipe.read(length).decode("utf-8")
        else:
            header = self._pipe.recv(8)
            if len(header) < 8:
                raise ConnectionError("Short recv on header")
            opcode, length = struct.unpack("<II", header)
            payload = self._pipe.recv(length).decode("utf-8")
        return opcode, json.loads(payload)

    def update_presence(
        self,
        title: str,
        artist: str,
        album: str = "",
        artwork_url: str = "",
        duration_ms: int = 0,
        is_playing: bool = True,
    ) -> bool:
        self._current_presence = {
            "title": title,
            "artist": artist,
            "album": album,
            "artwork_url": artwork_url,
            "duration_ms": duration_ms,
            "is_playing": is_playing,
            "updated_at": time.time(),
        }

        if not self._connected:
            if not self.connect():
                return False

        try:
            now = int(time.time())
            state_text = f"{artist}" if artist else "Playing Music"
            details_text = f"{title}" if title else "Its not just Music"

            activity = {
                "details": details_text,
                "state": state_text,
                "assets": {
                    "large_image": artwork_url if artwork_url else "openaamps",
                    "large_text": album if album else "OpenAamps",
                    "small_image": "play" if is_playing else "pause",
                    "small_text": "Rogue - Level 100",
                },
                "party": {
                    "id": "ae488379-351d-4a4f-ad32-2b9b01c91657",
                    "size": [1, 5],
                },
                "secrets": {
                    "join": "MTI4NzM0OjFpMmhuZToxMjMxMjM= ",
                },
                "timestamps": {
                    "start": now,
                },
                "instance": True,
            }
            if is_playing and duration_ms > 0:
                activity["timestamps"]["end"] = now + int(duration_ms / 1000)

            payload = {
                "cmd": "SET_ACTIVITY",
                "args": {
                    "pid": os.getpid(),
                    "activity": activity,
                },
                "nonce": str(time.time()),
            }

            self._send(1, json.dumps(payload))
            return True
        except Exception as e:
            logger.debug(f"Discord RPC send failed: {e}")
            self._disconnect()
            return False

    def clear_presence(self):
        self._current_presence.clear()
        if not self._connected:
            return
        try:
            payload = {
                "cmd": "SET_ACTIVITY",
                "args": {
                    "pid": os.getpid(),
                    "activity": None,
                },
                "nonce": str(time.time()),
            }
            self._send(1, json.dumps(payload))
        except Exception:
            self._disconnect()

    def get_status(self) -> Dict[str, Any]:
        return {
            "connected": self._connected,
            "client_id": self.client_id,
            "presence": self._current_presence,
        }

# Global singleton instance
discord_client = DiscordRPC()
