#!/usr/bin/env bash
# Command Code Stop hook: notify the desktop when a turn finishes.
#
# The agent runs inside ai-jail, where the session D-Bus bus, the audio
# socket and the display are all absent, so notify-send and paplay cannot
# work here. Ask the host-side notify-broker over its Unix socket first; if
# it is missing or fails, fall back to calling the tools directly so the same
# hook still works outside the sandbox.
set -u

# Command Code sends the hook payload on stdin; it is not needed here.
cat >/dev/null

SOCKET="${NOTIFY_BROKER_SOCKET:-$HOME/.commandcode/notify.sock}"
PAYLOAD='{"title":"Command Code","body":"Session finished","urgency":"normal","sound":true}'
SOUND="/run/current-system/sw/share/sounds/freedesktop/stereo/message-new-instant.oga"
[ -f "$SOUND" ] || SOUND=""

play_sound() {
  if [ -n "$SOUND" ]; then
    if command -v paplay >/dev/null 2>&1; then
      setsid paplay "$SOUND" >/dev/null 2>&1 &
      return
    fi
    if command -v aplay >/dev/null 2>&1; then
      setsid aplay -q "$SOUND" >/dev/null 2>&1 &
      return
    fi
  fi
  printf '\a' >/dev/tty 2>/dev/null || true
}

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    setsid notify-send "Command Code" "Session finished" >/dev/null 2>&1 &
    return
  fi
  if command -v dunstify >/dev/null 2>&1; then
    setsid dunstify "Command Code" "Session finished" >/dev/null 2>&1 &
    return
  fi
}

# 2xx from the broker means it owns both the notification and the sound.
if [ -S "$SOCKET" ] && command -v curl >/dev/null 2>&1; then
  status=$(curl -sS --max-time 1 -o /dev/null -w '%{http_code}' \
    --unix-socket "$SOCKET" \
    -H 'Content-Type: application/json' \
    --data-binary "$PAYLOAD" \
    http://localhost/notify 2>/dev/null) || status="000"
  case "$status" in
    2??) exit 0 ;;
  esac
fi

play_sound
notify
exit 0
