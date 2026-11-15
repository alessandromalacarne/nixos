#!/usr/bin/env python3
"""Host-side notification broker for agent hooks running inside ai-jail.

The sandbox has no session D-Bus bus, no audio socket and no display, so a
hook cannot call notify-send or paplay itself. This broker runs as a systemd
user service on the host, owns a Unix socket inside the jail's rw-mapped
~/.commandcode directory, and runs the real tools on the hook's behalf.

Wire protocol: HTTP over the Unix socket.

    POST /notify
    {"title": "...", "body": "...", "urgency": "low|normal|critical", "sound": true}

Responses:
    204  notification accepted
    400  malformed request (empty body, invalid JSON, missing title/body)
    404  unknown path
    405  method other than POST
    413  body larger than MAX_BODY
    503  notify-send is missing or could not reach the session bus

Every path and binary is taken from the environment so the Nix module can
pin them to store paths and this file stays runnable in a test harness.
"""

import json
import os
import shutil
import signal
import stat
import subprocess
import sys
import time
from http.server import BaseHTTPRequestHandler
from socketserver import ThreadingMixIn, UnixStreamServer

MAX_BODY = 64 * 1024
DEFAULT_SOCKET = "~/.commandcode/notify.sock"
DEFAULT_SOUND = "/run/current-system/sw/share/sounds/freedesktop/stereo/message-new-instant.oga"

SOCKET_PATH = os.path.expanduser(
    os.environ.get("NOTIFY_BROKER_SOCKET") or DEFAULT_SOCKET
)
NOTIFY_SEND = os.environ.get("NOTIFY_BROKER_NOTIFY_SEND") or shutil.which("notify-send")
PA_PLAY = os.environ.get("NOTIFY_BROKER_PA_PLAY") or shutil.which("paplay")
SOUND_FILE = os.path.expanduser(
    os.environ.get("NOTIFY_BROKER_SOUND_FILE") or DEFAULT_SOUND
)
URGENCIES = {"low", "normal", "critical"}


def log(event, **fields):
    """Write one structured line per event to stderr (captured by the journal)."""
    extra = " ".join(f"{key}={value!r}" for key, value in fields.items())
    print(f"notify-broker: {event} {extra}".rstrip(), file=sys.stderr, flush=True)


class Handler(BaseHTTPRequestHandler):
    server_version = "notify-broker/1"
    sys_version = ""

    # BaseHTTPRequestHandler logs every request to stderr through this hook;
    # route it through our formatter instead of its default text format.
    def log_message(self, fmt, *args):
        log("http", message=fmt % args)

    def do_GET(self):
        self._reject(405, "method not allowed")

    def do_PUT(self):
        self._reject(405, "method not allowed")

    def do_DELETE(self):
        self._reject(405, "method not allowed")

    def do_POST(self):
        started = time.monotonic()
        if self.path != "/notify":
            self._reject(404, "not found", started=started)
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0

        if length <= 0:
            self._reject(400, "empty body", started=started)
            return
        if length > MAX_BODY:
            # Do not read the body: HTTP/1.0 closes the connection after the
            # error response, so there is nothing to drain.
            self._reject(413, "payload too large", started=started)
            return

        raw = self.rfile.read(length)
        try:
            payload = json.loads(raw)
        except (UnicodeDecodeError, ValueError):
            self._reject(400, "invalid json", started=started)
            return

        if not isinstance(payload, dict):
            self._reject(400, "invalid json", started=started)
            return

        title = payload.get("title")
        body = payload.get("body")
        if not isinstance(title, str) or not title:
            self._reject(400, "missing title", started=started)
            return
        if not isinstance(body, str):
            self._reject(400, "missing body", started=started)
            return

        urgency = payload.get("urgency", "normal")
        if urgency not in URGENCIES:
            urgency = "normal"
        sound = payload.get("sound") is True

        if not NOTIFY_SEND:
            self._reject(503, "notify-send unavailable", started=started)
            return

        try:
            result = subprocess.run(
                [
                    NOTIFY_SEND,
                    "--urgency",
                    urgency,
                    "--app-name",
                    "Command Code",
                    "--",
                    title,
                    body,
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
                timeout=5,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            log("notify_failed", error=str(exc))
            self._reject(503, "notify-send failed", started=started)
            return

        if result.returncode != 0:
            detail = result.stderr.decode("utf-8", "replace").strip()
            log("notify_failed", code=result.returncode, detail=detail)
            self._reject(503, "notify-send failed", started=started)
            return

        if sound and PA_PLAY and SOUND_FILE and os.path.isfile(SOUND_FILE):
            try:
                # Playback must not delay the response: the hook has a hard
                # timeout and the notification is already delivered.
                subprocess.Popen(
                    [PA_PLAY, SOUND_FILE],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True,
                )
            except OSError as exc:
                log("sound_failed", error=str(exc))

        self._respond(204, None)
        log(
            "ok",
            urgency=urgency,
            sound=sound,
            ms=round((time.monotonic() - started) * 1000, 1),
        )

    def _reject(self, status, message, started=None):
        self._respond(status, message)
        fields = {"reason": message, "status": status}
        if started is not None:
            fields["ms"] = round((time.monotonic() - started) * 1000, 1)
        log("reject", **fields)

    def _respond(self, status, message):
        payload = b"" if message is None else (message + "\n").encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if payload:
            self.wfile.write(payload)


class ThreadingUnixServer(ThreadingMixIn, UnixStreamServer):
    daemon_threads = True
    # A burst of turn-completion hooks must not be refused by the listen
    # backlog (the contract exercises five at once).
    request_queue_size = 32


def prepare_socket(path):
    """Remove a stale socket left by a crash; refuse to clobber real files."""
    try:
        info = os.lstat(path)
    except FileNotFoundError:
        return
    if not stat.S_ISSOCK(info.st_mode):
        raise SystemExit(f"notify-broker: refusing to replace non-socket {path}")
    os.unlink(path)


def remove_socket(path):
    try:
        if stat.S_ISSOCK(os.lstat(path).st_mode):
            os.unlink(path)
    except FileNotFoundError:
        pass


def main():
    directory = os.path.dirname(SOCKET_PATH)
    os.makedirs(directory, mode=0o700, exist_ok=True)
    prepare_socket(SOCKET_PATH)

    # The socket is the only authentication boundary, so create it private.
    os.umask(0o077)
    server = ThreadingUnixServer(SOCKET_PATH, Handler)
    os.chmod(SOCKET_PATH, 0o600)

    def stop(_signum, _frame):
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    log(
        "listening",
        socket=SOCKET_PATH,
        notify_send=NOTIFY_SEND or "",
        pa_play=PA_PLAY or "",
    )
    try:
        server.serve_forever()
    except SystemExit:
        pass
    finally:
        server.server_close()
        remove_socket(SOCKET_PATH)
        log("stopped")


if __name__ == "__main__":
    main()
