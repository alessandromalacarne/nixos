#!/usr/bin/env bash
# Executable checks for docs/contracts/notify-broker.feature.
#
# Runs the broker with fake notify-send/paplay binaries, so it works inside
# ai-jail and asserts the observable behavior instead of requiring a desktop
# session. Every scenario name in the output maps back to the feature file.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BROKER="$REPO/user/alsoasnerd/notify-broker.py"
HOOK="$REPO/user/alsoasnerd/dotfiles/commandcode/session-end-notify.sh"
ROOT="${NOTIFY_BROKER_TEST_ROOT:-${XDG_CACHE_HOME:-$HOME/.cache}/notify-broker-test}"
SOCK="$ROOT/notify.sock"
NOTIFY_LOG="$ROOT/notify.log"
SOUND_LOG="$ROOT/sound.log"
FAKE_NOTIFY="$ROOT/fake-notify-send"
FAKE_PLAY="$ROOT/fake-paplay"

rm -rf "$ROOT"
mkdir -p "$ROOT/bin"
: >"$NOTIFY_LOG"
: >"$SOUND_LOG"

cat >"$FAKE_NOTIFY" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$NOTIFY_LOG"
exit "${FAKE_NOTIFY_EXIT:-0}"
EOF
cat >"$FAKE_PLAY" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$SOUND_LOG"
exit 0
EOF
chmod +x "$FAKE_NOTIFY" "$FAKE_PLAY"
ln -sf "$FAKE_NOTIFY" "$ROOT/bin/notify-send"
ln -sf "$FAKE_PLAY" "$ROOT/bin/paplay"

pass=0
fail=0
check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf 'ok   %s\n' "$name"
    pass=$((pass + 1))
  else
    printf 'FAIL %s (expected %q, got %q)\n' "$name" "$expected" "$actual"
    fail=$((fail + 1))
  fi
}

start_broker() {
  : >"$ROOT/broker.log"
  NOTIFY_BROKER_SOCKET="$SOCK" \
  NOTIFY_BROKER_NOTIFY_SEND="$FAKE_NOTIFY" \
  NOTIFY_BROKER_PA_PLAY="$FAKE_PLAY" \
  NOTIFY_BROKER_SOUND_FILE="$BROKER" \
  NOTIFY_LOG="$NOTIFY_LOG" SOUND_LOG="$SOUND_LOG" \
  python3 "$BROKER" >>"$ROOT/broker.log" 2>&1 &
  BROKER_PID=$!
  for _ in $(seq 1 100); do
    grep -q 'notify-broker: listening' "$ROOT/broker.log" && return 0
    kill -0 "$BROKER_PID" 2>/dev/null || break
    sleep 0.05
  done
  echo "broker did not start" >&2
  cat "$ROOT/broker.log" >&2
  exit 1
}

stop_broker() {
  kill "$BROKER_PID" 2>/dev/null
  wait "$BROKER_PID" 2>/dev/null
}

post() {
  curl -sS --max-time 2 -o /dev/null -w '%{http_code}' \
    --unix-socket "$SOCK" -H 'Content-Type: application/json' \
    --data-binary "$1" http://localhost/notify 2>/dev/null
}

start_broker

check "socket mode 0600" "600" "$(stat -c %a "$SOCK")"
check "valid request -> 204" "204" "$(post '{"title":"Command Code","body":"Session finished","urgency":"normal","sound":true}')"
check "notify-send got title+body" "1" "$(grep -c 'Command Code Session finished' "$NOTIFY_LOG")"
check "sound played once" "1" "$(wc -l <"$SOUND_LOG" | tr -d ' ')"
check "urgency forwarded" "204" "$(post '{"title":"T","body":"B","urgency":"critical","sound":false}')"
check "critical in argv" "1" "$(grep -c -- '--urgency critical' "$NOTIFY_LOG")"
check "sound=false skips paplay" "1" "$(wc -l <"$SOUND_LOG" | tr -d ' ')"
check "empty body -> 400" "400" "$(post '')"
check "invalid json -> 400" "400" "$(post 'not json')"
check "missing title -> 400" "400" "$(post '{"body":"B"}')"
check "missing body -> 400" "400" "$(post '{"title":"T"}')"
check "GET -> 405" "405" "$(curl -sS --max-time 2 -o /dev/null -w '%{http_code}' --unix-socket "$SOCK" http://localhost/notify 2>/dev/null)"
check "oversized body -> 413" "413" "$(python3 - "$SOCK" <<'PY'
import http.client, socket, sys
class U(http.client.HTTPConnection):
    def __init__(self, path):
        super().__init__("localhost")
        self._path = path
    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(self._path)
c = U(sys.argv[1])
c.request("POST", "/notify", body=b"x" * (70 * 1024), headers={"Content-Type": "application/json"})
print(c.getresponse().status)
PY
)"

before=$(wc -l <"$NOTIFY_LOG" | tr -d ' ')
pids=()
for i in 1 2 3 4 5; do
  post '{"title":"C","body":"B","sound":false}' &
  pids+=($!)
done
wait "${pids[@]}"
after=$(wc -l <"$NOTIFY_LOG" | tr -d ' ')
check "5 concurrent requests notified" "5" "$((after - before))"

check "unicode preserved" "204" "$(post '{"title":"Olá 🚀","body":"linha 1\nlinha 2","sound":false}')"
check "unicode bytes intact" "1" "$(grep -c 'Olá 🚀' "$NOTIFY_LOG")"
post '{"title":"$(touch '"$ROOT"'/pwned) `id`; rm -rf /","body":"B","sound":false}' >/dev/null
check "shell metacharacters stay literal" "1" "$(grep -cF '$(touch' "$NOTIFY_LOG")"
check "shell metacharacters not executed" "no" "$([ -e "$ROOT/pwned" ] && echo yes || echo no)"

latencies=()
for i in $(seq 1 100); do
  latencies+=("$(curl -sS -o /dev/null -w '%{time_total}' --unix-socket "$SOCK" \
    -H 'Content-Type: application/json' --data-binary '{"title":"L","body":"B","sound":false}' \
    http://localhost/notify)")
done
check "p95 <= 100ms" "yes" "$(printf '%s\n' "${latencies[@]}" | python3 -c 'import sys; v=sorted(float(x) for x in sys.stdin); print("yes" if v[int(len(v)*0.95)-1] <= 0.1 else "no")')"

stop_broker
check "socket removed on stop" "no" "$([ -e "$SOCK" ] && echo yes || echo no)"

python3 - "$SOCK" <<'PY'
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.bind(sys.argv[1])
s.close()
PY
start_broker
check "stale socket replaced" "204" "$(post '{"title":"T","body":"B","sound":false}')"
stop_broker

: >"$ROOT/broker.log"
NOTIFY_BROKER_SOCKET="$SOCK" \
NOTIFY_BROKER_NOTIFY_SEND="$FAKE_NOTIFY" \
NOTIFY_BROKER_PA_PLAY="$FAKE_PLAY" \
NOTIFY_LOG="$NOTIFY_LOG" SOUND_LOG="$SOUND_LOG" \
FAKE_NOTIFY_EXIT=1 \
python3 "$BROKER" >>"$ROOT/broker.log" 2>&1 &
BROKER_PID=$!
for _ in $(seq 1 100); do
  grep -q 'notify-broker: listening' "$ROOT/broker.log" && break
  sleep 0.05
done
check "notify-send failure -> 503" "503" "$(post '{"title":"T","body":"B","sound":false}')"
stop_broker

: >"$NOTIFY_LOG"
: >"$SOUND_LOG"
start_broker
NOTIFY_BROKER_SOCKET="$SOCK" PATH="$ROOT/bin:$PATH" NOTIFY_LOG="$NOTIFY_LOG" SOUND_LOG="$SOUND_LOG" bash "$HOOK" </dev/null
check "hook exit 0 with broker" "0" "$?"
check "hook used broker once" "1" "$(grep -c 'Command Code Session finished' "$NOTIFY_LOG")"
check "hook did not duplicate sound" "1" "$(wc -l <"$SOUND_LOG" | tr -d ' ')"
stop_broker

: >"$NOTIFY_LOG"
NOTIFY_BROKER_SOCKET="$SOCK" PATH="$ROOT/bin:$PATH" NOTIFY_LOG="$NOTIFY_LOG" SOUND_LOG="$SOUND_LOG" bash "$HOOK" </dev/null
check "hook exit 0 without broker" "0" "$?"
sleep 1
check "hook fell back to notify-send" "1" "$(grep -c 'Command Code Session finished' "$NOTIFY_LOG")"

start_ns=$(date +%s%N)
NOTIFY_BROKER_SOCKET="$SOCK" PATH="$ROOT/bin:$PATH" NOTIFY_LOG="$NOTIFY_LOG" SOUND_LOG="$SOUND_LOG" bash "$HOOK" </dev/null
end_ns=$(date +%s%N)
elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
check "hook under 2s without broker" "yes" "$([ "$elapsed_ms" -lt 2000 ] && echo yes || echo no)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
